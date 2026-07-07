import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'clicker_engine.dart';

/// Maximum random offset (ms) the user can configure. Keeps the input sane
/// even though the delay itself is always clamped to >= 1ms at scheduling.
const int kMaxRandomOffsetMs = 24 * 60 * 60 * 1000;

/// Whether clicking stops after a fixed number of clicks or keeps going
/// until the user (or the hotkey) stops it.
enum ClickRepeatMode { untilStopped, count }

/// Owns Auto Clicker's settings, the click timer, and the global start/stop
/// hotkey. Lives for the app's lifetime (see [main.dart]) rather than the
/// plugin page's, so clicking keeps running while the user works in another
/// window or navigates elsewhere in luma.
class AutoClickerRepository extends ChangeNotifier {
  File? _file;
  bool _loaded = false;

  int _intervalMs = 100;
  int _randomOffsetMs = 0;
  ClickButton _button = ClickButton.left;
  bool _doubleClick = false;
  bool _clickAtCursor = true;
  ClickPoint? _fixedPoint;
  ClickRepeatMode _repeatMode = ClickRepeatMode.untilStopped;
  int _repeatCount = 100;
  HotKey _hotKey = HotKey(
    key: PhysicalKeyboardKey.f6,
    modifiers: const [],
    scope: HotKeyScope.system,
  );

  bool _isRunning = false;
  int _clicksDone = 0;
  Timer? _timer;
  bool _hotKeyRegistered = false;
  String? _hotKeyError;
  final math.Random _random = math.Random();

  bool get loaded => _loaded;
  bool get supported => ClickerEngine.supported;

  int get intervalMs => _intervalMs;
  int get randomOffsetMs => _randomOffsetMs;
  ClickButton get button => _button;
  bool get doubleClick => _doubleClick;
  bool get clickAtCursor => _clickAtCursor;
  ClickPoint? get fixedPoint => _fixedPoint;
  ClickRepeatMode get repeatMode => _repeatMode;
  int get repeatCount => _repeatCount;
  HotKey get hotKey => _hotKey;
  bool get hotKeyRegistered => _hotKeyRegistered;
  String? get hotKeyError => _hotKeyError;

  bool get isRunning => _isRunning;
  int get clicksDone => _clicksDone;

  /// Loads persisted settings and registers the global hotkey. Call once,
  /// from the app root, before this repository is used by the UI.
  Future<void> init() async {
    await _load();
    await _registerHotKey();
  }

  Future<void> _load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/auto_clicker_settings.json');
      if (await _file!.exists()) {
        final data =
            jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        _intervalMs = (data['intervalMs'] as num?)?.toInt() ?? _intervalMs;
        _randomOffsetMs =
            (data['randomOffsetMs'] as num?)?.toInt() ?? _randomOffsetMs;
        _button = ClickButton.values.firstWhere(
          (b) => b.name == data['button'],
          orElse: () => ClickButton.left,
        );
        _doubleClick = data['doubleClick'] as bool? ?? false;
        _clickAtCursor = data['clickAtCursor'] as bool? ?? true;
        final fx = data['fixedX'] as num?;
        final fy = data['fixedY'] as num?;
        if (fx != null && fy != null) {
          _fixedPoint = ClickPoint(fx.toInt(), fy.toInt());
        }
        _repeatMode = ClickRepeatMode.values.firstWhere(
          (m) => m.name == data['repeatMode'],
          orElse: () => ClickRepeatMode.untilStopped,
        );
        _repeatCount = (data['repeatCount'] as num?)?.toInt() ?? _repeatCount;
        final hotKeyJson = data['hotKey'];
        if (hotKeyJson is Map) {
          try {
            final parsed = HotKey.fromJson(hotKeyJson.cast<String, dynamic>());
            // A null modifiers list crashes the native Windows plugin when
            // registering, so normalize it to empty (older settings files
            // saved before this was fixed can still have it as null).
            _hotKey = parsed.modifiers == null
                ? HotKey(
                    identifier: parsed.identifier,
                    key: parsed.key,
                    modifiers: const [],
                    scope: parsed.scope,
                  )
                : parsed;
          } catch (_) {
            // Keep the default F6 hotkey if the saved one can't be parsed.
          }
        }
      }
    } catch (_) {
      // Best-effort load; defaults stand if the file is missing or corrupt.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode({
        'intervalMs': _intervalMs,
        'randomOffsetMs': _randomOffsetMs,
        'button': _button.name,
        'doubleClick': _doubleClick,
        'clickAtCursor': _clickAtCursor,
        if (_fixedPoint != null) 'fixedX': _fixedPoint!.x,
        if (_fixedPoint != null) 'fixedY': _fixedPoint!.y,
        'repeatMode': _repeatMode.name,
        'repeatCount': _repeatCount,
        'hotKey': _hotKey.toJson(),
      }));
    } catch (_) {
      // Best-effort save; a failure here shouldn't crash the app.
    }
  }

  Future<void> _registerHotKey() async {
    try {
      await hotKeyManager.register(_hotKey, keyDownHandler: (_) => toggle());
      _hotKeyRegistered = true;
      _hotKeyError = null;
    } catch (_) {
      _hotKeyRegistered = false;
      _hotKeyError =
          'Could not register the global hotkey — another app may already be using it.';
    }
    notifyListeners();
  }

  /// Rebinds the start/stop hotkey, unregistering the previous one first.
  Future<void> setHotKey(HotKey newHotKey) async {
    if (_hotKeyRegistered) {
      try {
        await hotKeyManager.unregister(_hotKey);
      } catch (_) {}
    }
    _hotKey = newHotKey;
    await _registerHotKey();
    await _save();
  }

  void setIntervalMs(int ms) {
    _intervalMs = ms.clamp(1, const Duration(hours: 24).inMilliseconds);
    unawaited(_save());
    notifyListeners();
    if (_isRunning) _startTimer();
  }

  void setRandomOffsetMs(int ms) {
    _randomOffsetMs = ms.clamp(0, kMaxRandomOffsetMs);
    unawaited(_save());
    notifyListeners();
    if (_isRunning) _startTimer();
  }

  /// Returns the next click delay (ms), uniformly drawn from
  /// `[intervalMs - randomOffsetMs, intervalMs + randomOffsetMs]`, but always
  /// at least 1ms so the timer can never busy-loop.
  @visibleForTesting
  int nextDelayMs() {
    if (_randomOffsetMs <= 0) return _intervalMs;
    final low = _intervalMs - _randomOffsetMs;
    final high = _intervalMs + _randomOffsetMs;
    // Random.nextInt is exclusive on the upper bound, so add 1 to make `high`
    // inclusive — this matters when offset == 0 conceptually and interval == high.
    final span = high - low + 1;
    return (low + _random.nextInt(span)).clamp(1, kMaxRandomOffsetMs);
  }

  void setButton(ClickButton value) {
    _button = value;
    unawaited(_save());
    notifyListeners();
  }

  void setDoubleClick(bool value) {
    _doubleClick = value;
    unawaited(_save());
    notifyListeners();
  }

  void setClickAtCursor(bool value) {
    _clickAtCursor = value;
    unawaited(_save());
    notifyListeners();
  }

  void setFixedPoint(ClickPoint point) {
    _fixedPoint = point;
    _clickAtCursor = false;
    unawaited(_save());
    notifyListeners();
  }

  void setRepeatMode(ClickRepeatMode mode) {
    _repeatMode = mode;
    unawaited(_save());
    notifyListeners();
  }

  void setRepeatCount(int count) {
    _repeatCount = count.clamp(1, 1000000);
    unawaited(_save());
    notifyListeners();
  }

  void start() {
    if (_isRunning || !supported) return;
    if (_repeatMode == ClickRepeatMode.count && _repeatCount <= 0) return;
    if (!_clickAtCursor && _fixedPoint == null) return;

    _isRunning = true;
    _clicksDone = 0;
    _startTimer();
    notifyListeners();
  }

  void stop() {
    if (!_isRunning) return;
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    notifyListeners();
  }

  void toggle() => _isRunning ? stop() : start();

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(
      Duration(milliseconds: nextDelayMs()),
      _onTimerTick,
    );
  }

  void _onTimerTick() {
    if (!_isRunning) return;
    _performClick();
    if (!_isRunning) return;
    _timer = Timer(
      Duration(milliseconds: nextDelayMs()),
      _onTimerTick,
    );
  }

  void _performClick() {
    try {
      ClickerEngine.click(
        button: _button,
        doubleClick: _doubleClick,
        at: _clickAtCursor ? null : _fixedPoint,
      );
    } catch (_) {
      stop();
      return;
    }

    _clicksDone++;
    if (_repeatMode == ClickRepeatMode.count && _clicksDone >= _repeatCount) {
      stop();
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_hotKeyRegistered) {
      unawaited(hotKeyManager.unregister(_hotKey));
    }
    super.dispose();
  }
}
