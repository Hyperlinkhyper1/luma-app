part of 'team_discord.dart';

/// How often the meter takes a sample, and how many it keeps: ten minutes.
const kDiscordMeterEvery = Duration(seconds: 10);
const kDiscordMeterSamples = 60;

const _meterKey = #lumaDiscordMeter;

/// The meter of the bot whose zone this runs in, if any.
DiscordBotMeter? get _currentMeter =>
    Zone.current[_meterKey] as DiscordBotMeter?;

/// What the bot itself costs the machine.
///
/// The bot shares the luma server's process, so the process's own numbers
/// would also count sync, the dashboard and everything else the server
/// does. Instead every piece of bot work runs in [zone], and the meter only
/// counts what happens there:
///
///  * CPU: the time the event loop spends running the bot's callbacks.
///    Dart runs one callback at a time, so that time is the bot's alone.
///  * Memory: what the bot holds (its caches, log, rules and any
///    attachment it is downloading), estimated from their sizes. The
///    runtime the server shares with it isn't counted.
///  * Disk: its settings file and the attachments it copied onto the
///    board, plus every byte it writes, including the board saves its
///    forum posts set off.
///  * Network: the bytes of its gateway connection, its REST calls and its
///    attachment downloads. TLS and TCP framing come on top.
class DiscordBotMeter {
  DiscordBotMeter();

  final Stopwatch _clock = Stopwatch()..start();
  final int sinceMs = DateTime.now().millisecondsSinceEpoch;
  int _depth = 0;

  int cpuMicros = 0;
  int netInBytes = 0;
  int netOutBytes = 0;
  int diskWrittenBytes = 0;

  /// Attachment bytes downloaded and not yet handed to the board.
  int inFlightBytes = 0;

  /// The zone bot work runs in. Forked on first use, so errors still go
  /// where they went before: the zone that started the bot.
  late final Zone zone = Zone.current.fork(
    specification: ZoneSpecification(
      run: <R>(Zone self, ZoneDelegate parent, Zone zone, R Function() f) =>
          _timed(() => parent.run(zone, f)),
      runUnary: <R, T>(Zone self, ZoneDelegate parent, Zone zone,
              R Function(T) f, T arg) =>
          _timed(() => parent.runUnary(zone, f, arg)),
      runBinary: <R, T1, T2>(Zone self, ZoneDelegate parent, Zone zone,
              R Function(T1, T2) f, T1 a1, T2 a2) =>
          _timed(() => parent.runBinary(zone, f, a1, a2)),
    ),
    zoneValues: {
      _meterKey: this,
      kDiskWriteMeterKey: (int bytes) => diskWrittenBytes += bytes,
    },
  );

  /// Runs [f] as bot work.
  R runSync<R>(R Function() f) => zone.run(f);

  /// Runs [f] as bot work. A future that completes runs its listeners
  /// right away, inside the callback that completed it, so the caller
  /// hears back a microtask later instead: otherwise whatever it does after
  /// the await would be timed as the bot's.
  Future<T> run<T>(Future<T> Function() f) {
    final caller = Zone.current;
    final done = Completer<T>.sync();
    zone.run(f).then(
        (value) => caller.scheduleMicrotask(() => done.complete(value)),
        onError: (Object e, StackTrace s) =>
            caller.scheduleMicrotask(() => done.completeError(e, s)));
    return done.future;
  }

  R _timed<R>(R Function() f) {
    if (_depth++ > 0) {
      try {
        return f();
      } finally {
        _depth--;
      }
    }
    final began = _clock.elapsedMicroseconds;
    try {
      return f();
    } finally {
      _depth--;
      cpuMicros += _clock.elapsedMicroseconds - began;
    }
  }

  final List<DiscordMeterSample> samples = [];
  int _lastAtMicros = 0;
  int _lastCpu = 0;
  int _lastIn = 0;
  int _lastOut = 0;
  int _lastWritten = 0;

  /// Closes the current window: CPU and rates since the last sample, and
  /// [memoryBytes] and [storageBytes] as they are now.
  DiscordMeterSample sample(
      {required int memoryBytes, required int storageBytes}) {
    final at = _clock.elapsedMicroseconds;
    final seconds = max(at - _lastAtMicros, 1) / 1e6;
    final s = DiscordMeterSample(
      atMs: DateTime.now().millisecondsSinceEpoch,
      cpuPercent: (cpuMicros - _lastCpu) /
          1e6 /
          seconds /
          Platform.numberOfProcessors *
          100,
      memoryBytes: memoryBytes,
      storageBytes: storageBytes,
      diskWritePerSecond: ((diskWrittenBytes - _lastWritten) / seconds).round(),
      netInPerSecond: ((netInBytes - _lastIn) / seconds).round(),
      netOutPerSecond: ((netOutBytes - _lastOut) / seconds).round(),
    );
    _lastAtMicros = at;
    _lastCpu = cpuMicros;
    _lastIn = netInBytes;
    _lastOut = netOutBytes;
    _lastWritten = diskWrittenBytes;
    samples.add(s);
    if (samples.length > kDiscordMeterSamples) samples.removeAt(0);
    return s;
  }
}

/// One window of the bot's usage.
class DiscordMeterSample {
  const DiscordMeterSample({
    required this.atMs,
    required this.cpuPercent,
    required this.memoryBytes,
    required this.storageBytes,
    required this.diskWritePerSecond,
    required this.netInPerSecond,
    required this.netOutPerSecond,
  });

  final int atMs;

  /// Share of the whole machine, all cores together, the way a task
  /// manager shows it.
  final double cpuPercent;
  final int memoryBytes;
  final int storageBytes;
  final int diskWritePerSecond;
  final int netInPerSecond;
  final int netOutPerSecond;
}

/// [text]'s length in UTF-8, without encoding it.
int discordUtf8Length(String text) {
  var n = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    n += c < 0x80
        ? 1
        : c < 0x800 || (c >= 0xD800 && c < 0xE000)
            ? 2
            : 3;
  }
  return n;
}

/// A websocket frame carrying [payload] bytes: the header, plus the mask
/// a client adds to what it sends.
int discordWsFrameBytes(int payload, {required bool masked}) =>
    payload +
    (payload < 126
        ? 2
        : payload < 65536
            ? 4
            : 10) +
    (masked ? 4 : 0);

/// A rough count of the memory [value] takes: string contents plus the
/// headers and slots of the maps and lists around them.
int discordApproxBytes(Object? value) => switch (value) {
      String s => 16 + s.length * (s.codeUnits.any((c) => c > 0xFF) ? 2 : 1),
      Map m => 64 +
          24 * m.length +
          m.entries.fold(
              0,
              (sum, e) =>
                  sum +
                  discordApproxBytes(e.key) +
                  discordApproxBytes(e.value)),
      Iterable l =>
        32 + 8 * l.length + l.fold(0, (sum, v) => sum + discordApproxBytes(v)),
      _ => 16,
    };
