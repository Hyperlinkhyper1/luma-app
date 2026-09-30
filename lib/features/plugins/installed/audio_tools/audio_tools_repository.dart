import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_engine.dart';
import 'audio_types.dart';
import 'eq.dart';

/// Owns the Audio Tools settings and the running mic → EQ → output route.
/// Lives for the app's lifetime (see [main.dart]) rather than the page's, so
/// the voice changer keeps running during a call while luma is elsewhere.
class AudioToolsRepository extends ChangeNotifier {
  AudioToolsRepository({@visibleForTesting AudioDevices? devices})
    : _devices = devices ?? AudioDevices.empty;

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
    if (_autoStart) await start();
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
        bypass: _bypass,
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
    _engine?.setBypass(value);
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
    unawaited(_engine?.stop());
    _engine = null;
    levels.dispose();
    super.dispose();
  }
}
