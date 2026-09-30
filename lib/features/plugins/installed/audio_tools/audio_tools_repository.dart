import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_engine.dart';
import 'audio_types.dart';
import 'eq.dart';
import 'system_eq.dart';

/// Owns the Audio Tools settings and the running mic → EQ → output route.
/// Lives for the app's lifetime (see [main.dart]) rather than the page's, so
/// the voice changer keeps running during a call while luma is elsewhere.
class AudioToolsRepository extends ChangeNotifier {
  AudioToolsRepository({
    @visibleForTesting AudioDevices? devices,
    @visibleForTesting SystemEq? systemEq,
  }) : _devices = devices ?? AudioDevices.empty,
       _systemEq = systemEq ?? SystemEq();

  File? _file;
  bool _loaded = false;

  AudioDevices _devices;
  bool _refreshingDevices = false;
  String? _inputId;
  String? _outputId;
  bool _monitor = false;
  bool _bypass = false;
  bool _autoStart = false;
  EqSettings _eq = EqPreset.flat.settings;

  AudioEngine? _engine;
  bool _starting = false;
  AudioEngineError? _error;
  Timer? _saveTimer;

  final SystemEq _systemEq;
  SystemEqStatus _systemEqStatus = SystemEqStatus.none;
  bool _systemEqPaused = false;
  bool _systemEqBusy = false;
  SystemEqResult? _systemEqResult;
  Timer? _systemEqWriteTimer;

  /// Updated ~20 times a second while running; kept apart from
  /// [notifyListeners] so the meters don't rebuild the whole page.
  final ValueNotifier<AudioLevels> levels = ValueNotifier(AudioLevels.silent);

  bool get supported => AudioEngine.supported;
  bool get loaded => _loaded;
  AudioDevices get devices => _devices;
  bool get refreshingDevices => _refreshingDevices;

  /// Null means "follow the Windows default device".
  String? get inputId => _inputId;
  String? get outputId => _outputId;
  bool get monitor => _monitor;
  bool get bypass => _bypass;
  bool get autoStart => _autoStart;
  EqSettings get eq => _eq;

  bool get running => _engine != null;
  bool get starting => _starting;
  AudioEngineError? get error => _error;

  /// The preset the current curve matches exactly, if any.
  EqPreset? get activePreset {
    for (final p in EqPreset.values) {
      if (p.settings == _eq) return p;
    }
    return null;
  }

  /// The system-wide EQ: luma's curve applied to a microphone inside
  /// Windows, so Discord hears it with no virtual cable (see [SystemEq]).
  bool get systemEqAvailable => supported && _systemEq.available;
  SystemEqStatus get systemEqStatus => _systemEqStatus;
  bool get systemEqPaused => _systemEqPaused;
  bool get systemEqBusy => _systemEqBusy;

  /// The outcome of the last install/uninstall, while it's worth showing.
  SystemEqResult? get systemEqResult => _systemEqResult;

  /// The mic the routing uses: the chosen one, else the Windows default.
  String? get resolvedInputId => _inputId ?? _devices.defaultInputId;

  AudioDevice? get resolvedInput {
    final id = resolvedInputId;
    for (final d in _devices.inputs) {
      if (d.id == id) return d;
    }
    return null;
  }

  bool get systemEqOnInput {
    final id = resolvedInputId;
    return id != null && _systemEqStatus.endpoints.contains(id.toLowerCase());
  }

  /// Once Windows applies the curve to the mic itself, routing that mic
  /// through the engine as well would EQ the voice twice.
  bool get _engineBypass => _bypass || (systemEqOnInput && !_systemEqPaused);

  /// True when the chosen output is a real speaker/headset rather than a
  /// virtual cable, i.e. nothing else will pick the processed voice up.
  bool get outputIsVirtualCable {
    final id = _outputId ?? _devices.defaultOutputId;
    for (final d in _devices.outputs) {
      if (d.id == id) return d.isVirtualCable;
    }
    return false;
  }

  Future<void> init() async {
    await _load();
    if (!supported) return;
    await refreshDevices();
    await refreshSystemEq();
    if (_autoStart) await start();
  }

  Future<void> refreshSystemEq() async {
    if (!systemEqAvailable) return;
    _systemEqStatus = await _systemEq.status();
    if (_systemEqStatus.installed) await _writeSystemEqConfig();
    _engine?.setBypass(_engineBypass);
    notifyListeners();
  }

  Future<void> _writeSystemEqConfig() => _systemEq.writeConfig(
    SystemEqConfig.encode(_eq, enabled: !_bypass && !_systemEqPaused),
  );

  void _scheduleSystemEqWrite() {
    if (!_systemEqStatus.installed) return;
    _systemEqWriteTimer?.cancel();
    _systemEqWriteTimer = Timer(
      const Duration(milliseconds: 60),
      _writeSystemEqConfig,
    );
  }

  /// Puts the EQ on the routing's microphone. Raises a UAC prompt.
  Future<void> enableSystemEq() => _runSystemEq((id) async {
    final result = await _systemEq.install(id);
    if (result.succeeded) _systemEqPaused = false;
    return result;
  });

  /// Reinstalls on the same mic so Program Files gets this build's APO.
  Future<void> updateSystemEq() => _runSystemEq(_systemEq.install);

  /// Restores the routing's microphone exactly as it was. Raises a UAC
  /// prompt.
  Future<void> disableSystemEq() => _runSystemEq(_systemEq.uninstall);

  Future<void> _runSystemEq(
    Future<SystemEqResult> Function(String deviceId) action,
  ) async {
    final id = resolvedInputId;
    if (id == null || _systemEqBusy) return;
    _systemEqBusy = true;
    _systemEqResult = null;
    notifyListeners();
    // The helper restarts Windows audio, which would knock the engine's
    // streams over anyway; reopen them cleanly afterwards.
    final wasRunning = running;
    if (wasRunning) await stop();
    final result = await action(id);
    _systemEqStatus = await _systemEq.status();
    if (_systemEqStatus.installed) await _writeSystemEqConfig();
    _systemEqResult = result == SystemEqResult.ok ? null : result;
    _systemEqBusy = false;
    _scheduleSave();
    notifyListeners();
    if (wasRunning) await start();
  }

  void setSystemEqPaused(bool paused) {
    _systemEqPaused = paused;
    _engine?.setBypass(_engineBypass);
    _scheduleSystemEqWrite();
    _scheduleSave();
    notifyListeners();
  }

  void clearSystemEqResult() {
    _systemEqResult = null;
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/audio_tools_settings.json');
      if (await _file!.exists()) {
        final data =
            jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        _inputId = data['inputId'] as String?;
        _outputId = data['outputId'] as String?;
        _monitor = data['monitor'] as bool? ?? false;
        _bypass = data['bypass'] as bool? ?? false;
        _autoStart = data['autoStart'] as bool? ?? false;
        _systemEqPaused = data['systemEqPaused'] as bool? ?? false;
        final eq = data['eq'];
        if (eq is Map) _eq = EqSettings.fromJson(eq.cast<String, dynamic>());
      }
    } catch (_) {
      // Best-effort load; defaults stand if the file is missing or corrupt.
    }
    _loaded = true;
    notifyListeners();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(
        jsonEncode({
          'inputId': _inputId,
          'outputId': _outputId,
          'monitor': _monitor,
          'bypass': _bypass,
          'autoStart': _autoStart,
          'systemEqPaused': _systemEqPaused,
          'eq': _eq.toJson(),
        }),
      );
    } catch (_) {
      // Best-effort save; a failure here shouldn't crash the app.
    }
  }

  Future<void> refreshDevices() async {
    if (!supported || _refreshingDevices) return;
    _refreshingDevices = true;
    notifyListeners();
    try {
      _devices = await AudioEngine.listDevices();
    } catch (_) {
      _devices = AudioDevices.empty;
    }
    _refreshingDevices = false;
    notifyListeners();
  }

  Future<void> start() async {
    if (!supported || running || _starting) return;
    _starting = true;
    _error = null;
    notifyListeners();
    try {
      _engine = await AudioEngine.start(
        inputId: _inputId,
        outputId: _outputId,
        monitor: _monitor,
        eq: _eq,
        bypass: _engineBypass,
        onLevels: (l) => levels.value = l,
        onError: _onEngineError,
      );
    } on AudioEngineException catch (e) {
      _error = e.error;
    } catch (_) {
      _error = AudioEngineError.failed;
    }
    _starting = false;
    notifyListeners();
  }

  void _onEngineError(AudioEngineError error) {
    _engine = null;
    _error = error;
    levels.value = AudioLevels.silent;
    notifyListeners();
  }

  Future<void> stop() async {
    final engine = _engine;
    if (engine == null) return;
    _engine = null;
    levels.value = AudioLevels.silent;
    notifyListeners();
    await engine.stop();
  }

  Future<void> toggle() => running ? stop() : start();

  /// Device and monitor changes need the streams reopened.
  Future<void> _restartIfRunning() async {
    if (!running) return;
    await stop();
    await start();
  }

  Future<void> setInput(String? id) async {
    _inputId = id;
    _systemEqResult = null;
    _scheduleSave();
    notifyListeners();
    await _restartIfRunning();
  }

  Future<void> setOutput(String? id) async {
    _outputId = id;
    _scheduleSave();
    notifyListeners();
    await _restartIfRunning();
  }

  Future<void> setMonitor(bool value) async {
    _monitor = value;
    _scheduleSave();
    notifyListeners();
    await _restartIfRunning();
  }

  void setBypass(bool value) {
    _bypass = value;
    _engine?.setBypass(_engineBypass);
    _scheduleSystemEqWrite();
    _scheduleSave();
    notifyListeners();
  }

  void setAutoStart(bool value) {
    _autoStart = value;
    _scheduleSave();
    notifyListeners();
  }

  void setEq(EqSettings eq) {
    if (eq == _eq) return;
    _eq = eq;
    _engine?.updateEq(eq);
    _scheduleSystemEqWrite();
    _scheduleSave();
    notifyListeners();
  }

  void setBand(int index, EqBand band) => setEq(_eq.withBand(index, band));

  void setPreamp(double db) => setEq(_eq.copyWith(preampDb: db));

  void applyPreset(EqPreset preset) => setEq(preset.settings);

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_save());
    if (_systemEqWriteTimer?.isActive ?? false) {
      _systemEqWriteTimer!.cancel();
      unawaited(_writeSystemEqConfig());
    }
    unawaited(_engine?.stop());
    _engine = null;
    levels.dispose();
    super.dispose();
  }
}
