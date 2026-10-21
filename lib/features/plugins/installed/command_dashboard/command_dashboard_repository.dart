import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'command_models.dart';
import 'command_run.dart';

/// Holds the dashboard's buttons and the live runs behind them. A
/// [ChangeNotifier] rather than a plain repository: a run's output and a
/// host's connections change by the second, and nothing about them is worth
/// persisting — only the command list is written to disk.
///
/// Every run goes through a generated wrapper .bat (see [wrapperBatch]).
/// Plain runs are piped straight into luma; elevated and own-window runs go
/// through a PowerShell launcher, and an elevated run's output is tailed
/// from a log file because UAC can't hand pipes back across the boundary.
///
/// Hosts talk only to 127.0.0.1 — nothing here touches a luma server.
class CommandDashboardRepository extends ChangeNotifier {
  CommandDashboardRepository({Future<File> Function()? storeFile})
      : _storeFile = storeFile ?? _defaultStoreFile;

  static bool get isSupported => Platform.isWindows;

  static const _hostPollInterval = Duration(seconds: 3);
  static const _logPollInterval = Duration(milliseconds: 500);

  final Future<File> Function() _storeFile;

  List<DashCommand> _commands = const [];
  List<DashCommand> get commands => _commands;

  final Map<String, CommandRun> _runs = {};
  final Map<String, Process> _processes = {};
  final Map<String, Timer> _logTails = {};
  Timer? _hostTimer;
  bool _polling = false;

  bool _loaded = false;
  bool get loaded => _loaded;
  Future<void>? _loading;

  static Future<File> _defaultStoreFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}command_dashboard.json');
  }

  CommandRun runOf(String id) => _runs.putIfAbsent(id, CommandRun.new);

  int get activeCount => _runs.values.where((r) => r.isActive).length;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final file = await _storeFile();
      if (await file.exists()) {
        _commands = decodeCommands(await file.readAsString());
      }
    } on FileSystemException {
      _commands = const [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final file = await _storeFile();
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(encodeCommands(_commands), flush: true);
    await tmp.rename(file.path);
  }

  static String newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Future<void> upsert(DashCommand command) async {
    final index = _commands.indexWhere((c) => c.id == command.id);
    _commands = [..._commands];
    if (index < 0) {
      _commands.add(command);
    } else {
      _commands[index] = command;
    }
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    if (runOf(id).isActive) await stop(id);
    _commands = [for (final c in _commands) if (c.id != id) c];
    _runs.remove(id);
    notifyListeners();
    await _save();
  }

  Future<void> reorder(int from, int to) async {
    final list = [..._commands];
    final item = list.removeAt(from);
    list.insert(to.clamp(0, list.length), item);
    _commands = list;
    notifyListeners();
    await _save();
  }

  void clearOutput(String id) {
    runOf(id).lines.clear();
    notifyListeners();
  }

  Future<Directory> _workDir() async {
    final dir = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}luma_commands');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> run(DashCommand command) async {
    final run = runOf(command.id);
    if (run.isActive) return;
    run.reset();
    run.detectedPort = command.port;
    notifyListeners();

    try {
      final dir = await _workDir();
      final sep = Platform.pathSeparator;
      final batch = File('${dir.path}$sep${command.id}.bat');
      await batch.writeAsString(wrapperBatch(command), flush: true);

      if (!command.runAsAdmin && !command.ownWindow) {
        await _startPiped(command, batch.path);
      } else {
        final log = command.runAsAdmin && !command.ownWindow
            ? File('${dir.path}$sep${command.id}.log')
            : null;
        if (log != null && await log.exists()) await log.delete();
        await _startLaunched(command, batch.path, log);
      }
    } catch (e) {
      run
        ..status = RunStatus.failed
        ..error = e.toString()
        ..endedAt = DateTime.now();
      notifyListeners();
      return;
    }
    if (command.keepsRunning) _ensureHostPolling();
  }

  Future<void> _startPiped(DashCommand command, String batchPath) async {
    final run = runOf(command.id);
    final process = await Process.start(
      'cmd.exe',
      ['/c', batchPath],
      workingDirectory: command.effectiveWorkingDirectory,
    );
    _processes[command.id] = process;
    run
      ..pid = process.pid
      ..status = RunStatus.running;
    notifyListeners();

    void onLine(String line) => _addOutput(command, line);
    final outDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(onLine)
        .asFuture<void>();
    final errDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(onLine)
        .asFuture<void>();

    unawaited(process.exitCode.then((code) async {
      await Future.wait([outDone, errDone]).catchError((_) => <void>[]);
      _processes.remove(command.id);
      _finish(command.id, code);
    }));
  }

  Future<void> _startLaunched(
    DashCommand command,
    String batchPath,
    File? log,
  ) async {
    final run = runOf(command.id)..elevated = command.runAsAdmin;
    final script = launcherScript(
      batchPath: batchPath,
      admin: command.runAsAdmin,
      ownWindow: command.ownWindow,
      logPath: log?.path,
    );
    final launcher = await Process.start('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-EncodedCommand',
      encodePowerShell(script),
    ]);
    _processes[command.id] = launcher;
    final errors = StringBuffer();

    final outDone = launcher.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
      final pid = parseLauncherPid(line);
      if (pid != null) {
        run
          ..pid = pid
          ..status = RunStatus.running;
        notifyListeners();
      }
    }).asFuture<void>();
    final errDone = launcher.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(errors.write)
        .asFuture<void>();

    if (log != null) _tailLog(command, log);

    unawaited(launcher.exitCode.then((code) async {
      await Future.wait([outDone, errDone]).catchError((_) => <void>[]);
      _processes.remove(command.id);
      if (log != null) {
        _logTails.remove(command.id)?.cancel();
        await _readLog(command, log);
      }
      if (run.pid == null && !run.stopped) {
        run.error = _firstPowerShellError(errors.toString());
      }
      _finish(command.id, code);
    }));
  }

  final Map<String, int> _logOffsets = {};
  final Map<String, String> _logRemainders = {};

  void _tailLog(DashCommand command, File log) {
    _logOffsets[command.id] = 0;
    _logRemainders[command.id] = '';
    _logTails[command.id]?.cancel();
    _logTails[command.id] =
        Timer.periodic(_logPollInterval, (_) => _readLog(command, log));
  }

  Future<void> _readLog(DashCommand command, File log) async {
    try {
      if (!await log.exists()) return;
      final offset = _logOffsets[command.id] ?? 0;
      final length = await log.length();
      if (length <= offset) return;
      final raf = await log.open();
      try {
        await raf.setPosition(offset);
        final bytes = await raf.read(length - offset);
        _logOffsets[command.id] = offset + bytes.length;
        final text = (_logRemainders[command.id] ?? '') +
            const Utf8Decoder(allowMalformed: true).convert(bytes);
        final parts = text.split(RegExp(r'\r?\n'));
        _logRemainders[command.id] = parts.removeLast();
        for (final line in parts) {
          _addOutput(command, line);
        }
      } finally {
        await raf.close();
      }
    } on FileSystemException {
      // The elevated cmd still holds the log open for writing; try next tick.
    }
  }

  static String? _firstPowerShellError(String stderr) {
    for (final line in const LineSplitter().convert(stderr)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('At line:')) continue;
      return trimmed;
    }
    return null;
  }

  void _addOutput(DashCommand command, String line) {
    final run = runOf(command.id);
    run.addLine(line);
    if (command.keepsRunning && run.detectedPort == null) {
      run.detectedPort = detectPort(line);
      if (run.detectedPort != null) unawaited(_pollHosts());
    }
    notifyListeners();
  }

  void _finish(String id, int code) {
    final run = runOf(id);
    final remainder = _logRemainders.remove(id);
    if (remainder != null && remainder.isNotEmpty) run.addLine(remainder);
    _logOffsets.remove(id);
    run
      ..exitCode = code
      ..endedAt = DateTime.now()
      ..status =
          run.stopped || code == 0 ? RunStatus.exited : RunStatus.failed
      ..host = null;
    notifyListeners();
  }

  Future<void> stop(String id) async {
    final run = runOf(id);
    if (!run.isActive) return;
    run.stopped = true;
    notifyListeners();
    final pid = run.pid;
    if (pid == null) {
      _processes[id]?.kill();
      return;
    }
    if (run.elevated) {
      // An unelevated luma can't kill an elevated tree, so the kill itself
      // goes through UAC too.
      await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        "Start-Process -FilePath 'taskkill.exe' -Verb RunAs -WindowStyle Hidden "
            "-ArgumentList '/PID $pid /T /F'",
      ]);
    } else {
      await Process.run('taskkill.exe', ['/PID', '$pid', '/T', '/F']);
    }
  }

  void _ensureHostPolling() {
    _hostTimer ??= Timer.periodic(_hostPollInterval, (_) => _pollHosts());
    unawaited(_pollHosts());
  }

  Future<void> _pollHosts() async {
    if (_polling) return;
    final hosts = [
      for (final c in _commands)
        if (c.keepsRunning &&
            runOf(c.id).status == RunStatus.running &&
            runOf(c.id).detectedPort != null)
          c,
    ];
    if (hosts.isEmpty) {
      if (!_commands.any((c) => c.keepsRunning && runOf(c.id).isActive)) {
        _hostTimer?.cancel();
        _hostTimer = null;
      }
      return;
    }
    _polling = true;
    try {
      final netstat = await _netstat();
      for (final command in hosts) {
        final run = runOf(command.id);
        final port = run.detectedPort!;
        final listening = await _isListening(port);
        final rojo = listening ? await _rojoInfo(port) : null;
        if (!run.isActive) continue;
        run.host = HostStatus(
          port: port,
          listening: listening,
          clients: parseEstablished(netstat, port),
          rojoProject: rojo?.$1,
          rojoVersion: rojo?.$2,
        );
      }
      notifyListeners();
    } finally {
      _polling = false;
    }
  }

  static Future<String> _netstat() async {
    try {
      final result = await Process.run('netstat', ['-ano', '-p', 'TCP']);
      return result.stdout is String ? result.stdout as String : '';
    } on ProcessException {
      return '';
    }
  }

  static Future<bool> _isListening(int port) async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 600),
      );
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    }
  }

  /// Rojo answers `GET /api/rojo` with its version and project name; any
  /// other host simply doesn't, and stays a generic host.
  static Future<(String?, String)?> _rojoInfo(int port) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 800);
    try {
      final request = await client
          .getUrl(Uri.parse('http://127.0.0.1:$port/api/rojo'))
          .timeout(const Duration(seconds: 1));
      final response =
          await request.close().timeout(const Duration(seconds: 1));
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 1));
      final json = jsonDecode(body);
      if (json is! Map || json['serverVersion'] is! String) return null;
      return (json['projectName'] as String?, json['serverVersion'] as String);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  @override
  void dispose() {
    _hostTimer?.cancel();
    for (final t in _logTails.values) {
      t.cancel();
    }
    super.dispose();
  }
}
