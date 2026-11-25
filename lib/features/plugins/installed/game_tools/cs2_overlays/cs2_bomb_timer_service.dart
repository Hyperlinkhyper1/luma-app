import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'cs2_translator_service.dart';

/// How long CS2's C4 burns in competitive and premier (`mp_c4timer`).
const kCs2DefaultFuseSeconds = 40;

/// The loopback port CS2 posts game state to. Fixed, because it is written
/// into the game's config file once and the game reads it at launch.
const kCs2GsiPort = 47821;

/// The file CS2 picks up from `game/csgo/cfg/` at launch. The
/// `gamestate_integration_` prefix is what makes the game load it.
const kCs2GsiConfigFile = 'gamestate_integration_luma.cfg';

/// What happened to the bomb, as far as one game-state update can tell.
enum Cs2BombEvent { planted, defused, exploded, cleared }

/// How much time is left, in the terms a defuser cares about: a defuse takes
/// 10 seconds without a kit and 5 with one.
enum Cs2BombUrgency { anyone, kitOnly, tooLate }

Cs2BombUrgency cs2BombUrgency(Duration left) {
  if (left >= const Duration(seconds: 10)) return Cs2BombUrgency.anyone;
  if (left >= const Duration(seconds: 5)) return Cs2BombUrgency.kitOnly;
  return Cs2BombUrgency.tooLate;
}

/// The Game State Integration config luma installs. Only the `round`
/// component is asked for — it carries `bomb` for every player, which is the
/// one thing the timer needs. Buffer and throttle are zero so the plant
/// arrives as soon as the game knows about it.
String cs2GsiConfig({required String token, int port = kCs2GsiPort}) =>
    '"luma bomb timer"\n'
    '{\n'
    '\t"uri"\t\t"http://127.0.0.1:$port"\n'
    '\t"timeout"\t"1.0"\n'
    '\t"buffer"\t"0.0"\n'
    '\t"throttle"\t"0.0"\n'
    '\t"heartbeat"\t"30.0"\n'
    '\t"auth"\n'
    '\t{\n'
    '\t\t"token"\t"$token"\n'
    '\t}\n'
    '\t"data"\n'
    '\t{\n'
    '\t\t"provider"\t"1"\n'
    '\t\t"round"\t\t"1"\n'
    '\t}\n'
    '}\n';

/// Follows `round.bomb` across game-state updates and reports each change.
///
/// A plant only counts when luma saw it happen: if the very first update
/// already says "planted", the plant time is unknown and a countdown from 40
/// would be wrong, so it is skipped unless the update itself marks the bomb
/// as just added or just changed.
class Cs2BombTracker {
  String? _bomb;
  bool _seen = false;

  Cs2BombEvent? update(Map<String, dynamic> state) {
    final round = state['round'];
    final bomb = round is Map && round['bomb'] is String
        ? round['bomb'] as String
        : null;
    final previous = _bomb;
    final first = !_seen;
    _seen = true;
    _bomb = bomb;
    if (bomb == previous) return null;
    return switch (bomb) {
      'planted' => first && !_justChanged(state) ? null : Cs2BombEvent.planted,
      'defused' => Cs2BombEvent.defused,
      'exploded' => Cs2BombEvent.exploded,
      _ => previous == null ? null : Cs2BombEvent.cleared,
    };
  }

  static bool _justChanged(Map<String, dynamic> state) {
    final added = state['added'];
    final previously = state['previously'];
    return (added is Map &&
            added['round'] is Map &&
            (added['round'] as Map)['bomb'] == true) ||
        (previously is Map &&
            previously['round'] is Map &&
            (previously['round'] as Map).containsKey('bomb'));
  }

  void reset() {
    _bomb = null;
    _seen = false;
  }
}

/// Receives CS2's game-state posts on loopback and turns them into bomb
/// events. Posts without the installed token are ignored, so nothing else on
/// the machine can start a countdown.
class Cs2GsiListener {
  Cs2GsiListener({required this.token, this.port = kCs2GsiPort, this.onUpdate});

  final String token;
  final int port;

  /// Called on every authenticated post, heartbeats included.
  final VoidCallback? onUpdate;
  final _tracker = Cs2BombTracker();
  final _events = StreamController<Cs2BombEvent>.broadcast();
  HttpServer? _server;
  DateTime? _lastUpdate;

  Stream<Cs2BombEvent> get events => _events.stream;

  /// When the game last posted anything, heartbeats included.
  DateTime? get lastUpdate => _lastUpdate;

  int? get boundPort => _server?.port;

  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    server.listen(_handle, onError: (_) {});
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (request.method == 'POST') {
        final body = await utf8
            .decodeStream(request)
            .timeout(const Duration(seconds: 5));
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) handle(decoded);
      }
      request.response.statusCode = HttpStatus.ok;
    } catch (_) {
      request.response.statusCode = HttpStatus.badRequest;
    }
    try {
      await request.response.close();
    } catch (_) {}
  }

  /// One decoded game-state update. Public so tests can feed it directly.
  @visibleForTesting
  void handle(Map<String, dynamic> state) {
    final auth = state['auth'];
    if (auth is! Map || auth['token'] != token) return;
    _lastUpdate = DateTime.now();
    onUpdate?.call();
    final event = _tracker.update(state);
    if (event != null && !_events.isClosed) _events.add(event);
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _tracker.reset();
    _lastUpdate = null;
    await server?.close(force: true);
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
  }
}

@immutable
class Cs2BombTimerOptions {
  const Cs2BombTimerOptions({
    required this.token,
    this.fuseSeconds = kCs2DefaultFuseSeconds,
    this.overlayX,
    this.overlayY,
  });

  /// Shared secret between the installed config and the listener.
  final String token;
  final int fuseSeconds;

  /// Null places the overlay automatically, centred under CS2's round timer.
  final int? overlayX;
  final int? overlayY;

  Cs2BombTimerOptions copyWith({
    int? fuseSeconds,
    int? Function()? overlayX,
    int? Function()? overlayY,
  }) => Cs2BombTimerOptions(
    token: token,
    fuseSeconds: fuseSeconds ?? this.fuseSeconds,
    overlayX: overlayX != null ? overlayX() : this.overlayX,
    overlayY: overlayY != null ? overlayY() : this.overlayY,
  );

  Map<String, Object?> toJson() => {
    'token': token,
    'fuseSeconds': fuseSeconds,
    'overlayX': overlayX,
    'overlayY': overlayY,
  };

  static Cs2BombTimerOptions fromJson(Map<String, Object?> json) {
    final token = json['token'];
    return Cs2BombTimerOptions(
      token: token is String && token.length >= 16 ? token : newCs2GsiToken(),
      fuseSeconds:
          ((json['fuseSeconds'] as num?)?.toInt() ?? kCs2DefaultFuseSeconds)
              .clamp(10, 120),
      overlayX: (json['overlayX'] as num?)?.toInt(),
      overlayY: (json['overlayY'] as num?)?.toInt(),
    );
  }
}

String newCs2GsiToken() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// Labels the overlay draws, passed in so it speaks the app's language.
class Cs2BombOverlayLabels {
  const Cs2BombOverlayLabels({
    required this.kitOnly,
    required this.tooLate,
    required this.defused,
    required this.exploded,
    required this.preview,
    required this.move,
  });

  final String kitOnly;
  final String tooLate;
  final String defused;
  final String exploded;
  final String preview;
  final String move;
}

/// The bomb timer overlay: listens to CS2's Game State Integration and,
/// when the bomb is planted, counts the fuse down in a small transparent
/// window on top of the game (`assets/cs2_overlays/cs2-bomb-timer.ps1`).
///
/// GSI is Valve's own feature for overlays and broadcasters — the game posts
/// its state to a local address named in a config file — so nothing reads
/// the game's memory, and it is VAC-safe. One instance for the whole app, so
/// the timer keeps running while the user is elsewhere in luma.
class Cs2BombTimerService extends ChangeNotifier {
  Cs2BombTimerService._();

  static final instance = Cs2BombTimerService._();

  static const _assetPath = 'assets/cs2_overlays/cs2-bomb-timer.ps1';

  Cs2BombTimerOptions? _options;
  Cs2GsiListener? _listener;
  StreamSubscription<Cs2BombEvent>? _subscription;
  Process? _overlay;
  ServerSocket? _commandServer;
  Socket? _commandSocket;
  final List<String> _pendingCommands = [];
  Timer? _ticker;
  DateTime? _plantedAt;
  Cs2BombEvent? _lastEvent;
  bool _starting = false;
  bool _wasConnected = false;

  static bool get supported => Platform.isWindows;

  bool get running => _listener != null;
  bool get starting => _starting;
  Cs2BombTimerOptions? get options => _options;
  Cs2BombEvent? get lastEvent => _lastEvent;

  /// Whether CS2 has posted in the last minute. The config asks for a
  /// heartbeat every 30 seconds, so silence past that means the game is
  /// closed or was started before the config was installed.
  bool get gameConnected {
    final last = _listener?.lastUpdate;
    return last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 1);
  }

  /// Time left on the fuse, or null while no bomb is ticking.
  Duration? get remaining {
    final planted = _plantedAt;
    final options = _options;
    if (planted == null || options == null) return null;
    final left =
        Duration(seconds: options.fuseSeconds) -
        DateTime.now().difference(planted);
    return left.isNegative ? Duration.zero : left;
  }

  Future<File> _optionsFile() async => File(
    '${(await Cs2TranslatorService.instance.dataDir()).path}'
    '${Platform.pathSeparator}bomb_timer.json',
  );

  Future<Cs2BombTimerOptions> loadOptions() async {
    if (_options case final options?) return options;
    Cs2BombTimerOptions options;
    try {
      final file = await _optionsFile();
      options = await file.exists()
          ? Cs2BombTimerOptions.fromJson(
              jsonDecode(await file.readAsString()) as Map<String, Object?>,
            )
          : Cs2BombTimerOptions(token: newCs2GsiToken());
    } catch (_) {
      options = Cs2BombTimerOptions(token: newCs2GsiToken());
    }
    _options = options;
    await _saveOptions(options);
    return options;
  }

  Future<void> _saveOptions(Cs2BombTimerOptions options) async {
    try {
      await (await _optionsFile()).writeAsString(jsonEncode(options.toJson()));
    } catch (_) {}
  }

  Future<void> updateOptions(Cs2BombTimerOptions options) async {
    _options = options;
    notifyListeners();
    await _saveOptions(options);
  }

  Future<File?> _configFile() async {
    final log = await Cs2TranslatorService.instance.findConsoleLog();
    if (log == null) return null;
    final cfg = Directory(
      '${File(log).parent.path}${Platform.pathSeparator}cfg',
    );
    if (!await cfg.exists()) return null;
    return File('${cfg.path}${Platform.pathSeparator}$kCs2GsiConfigFile');
  }

  /// Whether the game folder already holds the config with this device's
  /// token. Null when CS2 itself could not be found.
  Future<bool?> configInstalled() async {
    final file = await _configFile();
    if (file == null) return null;
    final options = await loadOptions();
    try {
      return await file.exists() &&
          (await file.readAsString()).contains(options.token);
    } catch (_) {
      return false;
    }
  }

  /// Writes the config into CS2's cfg folder. Returns an error, or null.
  Future<String?> installConfig() async {
    final file = await _configFile();
    if (file == null) return 'not_found';
    final options = await loadOptions();
    try {
      await file.writeAsString(cs2GsiConfig(token: options.token), flush: true);
      return null;
    } catch (e) {
      return '$e';
    }
  }

  /// Starts listening and opens the overlay. Returns an error, or null.
  Future<String?> start(Cs2BombOverlayLabels labels) async {
    if (!supported || running || _starting) return null;
    _starting = true;
    notifyListeners();
    final options = await loadOptions();
    final listener = Cs2GsiListener(
      token: options.token,
      onUpdate: () {
        if (_wasConnected) return;
        _wasConnected = true;
        notifyListeners();
      },
    );
    try {
      await listener.start();
    } on SocketException {
      _starting = false;
      notifyListeners();
      return 'port_in_use';
    }
    _listener = listener;
    _subscription = listener.events.listen(_onEvent);
    final error = await _openOverlay(options, labels);
    _starting = false;
    if (error != null) {
      await _stopListening();
    } else {
      _send('PREVIEW');
    }
    notifyListeners();
    return error;
  }

  Future<String?> _openOverlay(
    Cs2BombTimerOptions options,
    Cs2BombOverlayLabels labels,
  ) async {
    try {
      final dir = await Cs2TranslatorService.instance.dataDir();
      final script = File(
        '${dir.path}${Platform.pathSeparator}cs2-bomb-timer.ps1',
      );
      final data = await rootBundle.load(_assetPath);
      await script.writeAsBytes(data.buffer.asUint8List(), flush: true);
      final commands = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _commandServer = commands;
      commands.listen((socket) {
        if (_commandSocket != null) {
          socket.destroy();
          return;
        }
        _commandSocket = socket;
        socket.done.catchError((_) {}).ignore();
        for (final command in _pendingCommands) {
          socket.writeln(command);
        }
        _pendingCommands.clear();
        if (remaining case final left?) {
          socket.writeln('PLANT ${left.inMilliseconds}');
        }
      });
      final process = await Process.start('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        script.path,
        '-CommandPort',
        '${commands.port}',
        '-OverlayX',
        '${options.overlayX ?? -1}',
        '-OverlayY',
        '${options.overlayY ?? -1}',
        '-FuseSeconds',
        '${options.fuseSeconds}',
        '-LabelKit',
        labels.kitOnly,
        '-LabelLate',
        labels.tooLate,
        '-LabelDefused',
        labels.defused,
        '-LabelExploded',
        labels.exploded,
        '-LabelPreview',
        labels.preview,
        '-LabelMove',
        labels.move,
      ]);
      _overlay = process;
      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(_onOverlayLine);
      process.stderr.drain<void>().ignore();
      unawaited(
        process.exitCode.then((_) {
          if (identical(_overlay, process)) {
            _overlay = null;
            unawaited(stop());
          }
        }),
      );
      return null;
    } catch (e) {
      await _closeCommands();
      return '$e';
    }
  }

  Future<void> _closeCommands() async {
    _pendingCommands.clear();
    final socket = _commandSocket;
    _commandSocket = null;
    final server = _commandServer;
    _commandServer = null;
    socket?.destroy();
    await server?.close();
  }

  void _onOverlayLine(String line) {
    final match = RegExp(r'^POS (-?\d+) (-?\d+)$').firstMatch(line.trim());
    final options = _options;
    if (match == null || options == null) return;
    unawaited(
      updateOptions(
        options.copyWith(
          overlayX: () => int.parse(match.group(1)!),
          overlayY: () => int.parse(match.group(2)!),
        ),
      ),
    );
  }

  /// Sends a command to the overlay, or holds it until the overlay has
  /// connected. A plant is never held: its time left would be stale by then,
  /// so the connect handler sends the countdown as it stands instead.
  void _send(String command) {
    final socket = _commandSocket;
    if (socket == null) {
      if (_overlay != null && !command.startsWith('PLANT')) {
        _pendingCommands.add(command);
      }
      return;
    }
    try {
      socket.writeln(command);
    } catch (_) {}
  }

  void _onEvent(Cs2BombEvent event) {
    _lastEvent = event;
    switch (event) {
      case Cs2BombEvent.planted:
        _plantedAt = DateTime.now();
        _send('PLANT ${remaining!.inMilliseconds}');
        _ticker?.cancel();
        _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
          if (remaining == Duration.zero) _clearCountdown();
          notifyListeners();
        });
      case Cs2BombEvent.defused:
        _clearCountdown();
        _send('DEFUSED');
      case Cs2BombEvent.exploded:
        _clearCountdown();
        _send('EXPLODED');
      case Cs2BombEvent.cleared:
        _clearCountdown();
        _send('CLEAR');
    }
    notifyListeners();
  }

  void _clearCountdown() {
    _ticker?.cancel();
    _ticker = null;
    _plantedAt = null;
  }

  /// Plays a plant through the overlay without the game, to check where it
  /// sits and how it reads.
  void simulatePlant() {
    if (running) _onEvent(Cs2BombEvent.planted);
  }

  /// Shows the placeholder again so the overlay can be dragged.
  void showPreview() => _send('PREVIEW');

  Future<void> _stopListening() async {
    _wasConnected = false;
    await _subscription?.cancel();
    _subscription = null;
    final listener = _listener;
    _listener = null;
    await listener?.dispose();
  }

  Future<void> stop() async {
    _clearCountdown();
    _lastEvent = null;
    final overlay = _overlay;
    _overlay = null;
    await _closeCommands();
    overlay?.kill();
    await _stopListening();
    notifyListeners();
  }
}
