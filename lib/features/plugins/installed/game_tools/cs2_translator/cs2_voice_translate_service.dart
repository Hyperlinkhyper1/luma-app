import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:win32/win32.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../../app/window_controls.dart';
import '../../../../../sync/server_access.dart';
import '../../../../../sync/sync_service.dart';
import 'cs2_voice_protocol.dart';
import 'cs2_voice_recorder.dart';

class Cs2VoiceTranslateService extends ChangeNotifier {
  Cs2VoiceTranslateService._()
    : _recorder = WindowsCs2VoiceRecorder(),
      _translateOverride = null,
      _send = sendCs2Chat,
      _readyOverride = null,
      _appIsOpen = windowManager.isVisible,
      _appCloseEvents = windowCloseEvents,
      _testing = false;

  @visibleForTesting
  factory Cs2VoiceTranslateService.forTesting({
    required Cs2VoiceRecorder recorder,
    required Future<Cs2VoiceTranslation> Function(Uint8List, String) translate,
    required Future<String> Function(String, bool Function()) send,
    bool Function()? serverReady,
    Future<bool> Function()? appIsOpen,
    Stream<void>? appCloseEvents,
  }) => Cs2VoiceTranslateService._withDependencies(
    recorder,
    translate,
    send,
    serverReady,
    appIsOpen ?? () async => true,
    appCloseEvents ?? const Stream<void>.empty(),
  );

  Cs2VoiceTranslateService._withDependencies(
    this._recorder,
    this._translateOverride,
    this._send,
    this._readyOverride,
    this._appIsOpen,
    this._appCloseEvents,
  ) : _testing = true;

  static final instance = Cs2VoiceTranslateService._();
  static bool get supported => !kIsWeb && Platform.isWindows;
  static const _hotKeyId = 'luma.cs2.voice.translate';

  final Cs2VoiceRecorder _recorder;
  final Future<Cs2VoiceTranslation> Function(Uint8List, String)?
  _translateOverride;
  final Future<String> Function(String, bool Function()) _send;
  final bool Function()? _readyOverride;
  final Future<bool> Function() _appIsOpen;
  final Stream<void> _appCloseEvents;
  StreamSubscription<void>? _appCloseSubscription;
  final bool _testing;
  SyncService? _sync;
  http.Client? _activeClient;
  Future<void>? _loadFuture;
  Future<void> _cleanup = Future.value();
  Future<void> _shortcutCleanup = Future.value();
  HotKey? _registeredHotKey;
  Timer? _recordingLimit;
  Timer? _keyReleaseTimer;
  bool _keyHeld = false;
  int _armGeneration = 0;
  String? _account;
  int _generation = 0;
  bool _arming = false;
  bool _enabled = false;
  bool _recording = false;
  bool _busy = false;
  bool _disposed = false;
  String _targetLanguage = 'English';
  String _status = 'Disabled';
  String? _error;
  String? _transcript;
  String? _translation;
  HotKey _hotKey = HotKey(
    identifier: _hotKeyId,
    key: PhysicalKeyboardKey.f8,
    modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  bool get enabled => _enabled;
  bool get recording => _recording;
  bool get busy => _busy || _arming;
  String get targetLanguage => _targetLanguage;
  String get status => _status;
  String? get error => _error;
  String? get transcript => _transcript;
  String? get translation => _translation;
  HotKey get hotKey => _hotKey;
  bool get _serverReady =>
      _readyOverride?.call() ?? _sync?.serverReady ?? false;
  String get _accountIdentity => '${_sync?.serverUrl}|${_sync?.authToken}';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void configure(SyncService sync) {
    if (identical(sync, _sync)) return;
    _sync?.removeListener(_onAccountChanged);
    if (_sync != null) unawaited(setEnabled(false));
    _sync = sync;
    _account = _accountIdentity;
    sync.addListener(_onAccountChanged);
  }

  void _onAccountChanged() {
    if (!_serverReady || _account != _accountIdentity) {
      _account = _accountIdentity;
      unawaited(setEnabled(false));
    }
  }

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    _appCloseSubscription ??= _appCloseEvents.listen((_) {
      unawaited(setEnabled(false));
    });
    if (_testing || !supported) return;
    try {
      final file = await _optionsFile();
      if (await file.exists()) {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final language = json['targetLanguage'];
        if (language is String &&
            language.trim().isNotEmpty &&
            language.length <= 80) {
          _targetLanguage = language.trim();
        }
        if (json['hotKey'] is Map) {
          final parsed = HotKey.fromJson(
            Map<String, dynamic>.from(json['hotKey'] as Map),
          );
          _hotKey = _normalizedHotKey(parsed);
        }
      }
    } catch (_) {
      _error = 'Could not load voice settings. Default settings are available.';
    }
    _notify();
  }

  Future<File> _optionsFile() async {
    final base = await getApplicationSupportDirectory();
    return File('${base.path}/cs2_voice_translate.json');
  }

  Future<void> _save() async {
    if (_testing) return;
    try {
      await (await _optionsFile()).writeAsString(
        jsonEncode({
          'targetLanguage': _targetLanguage,
          'hotKey': _hotKey.toJson(),
        }),
        flush: true,
      );
    } catch (_) {
      _error = 'Voice settings could not be saved.';
      _notify();
    }
  }

  HotKey _normalizedHotKey(HotKey key) => HotKey(
    identifier: _hotKeyId,
    key: key.key,
    modifiers: key.modifiers ?? const [],
    scope: HotKeyScope.system,
  );

  Future<void> setTargetLanguage(String value) async {
    final language = value.trim();
    if (busy || recording || language.isEmpty || language.length > 80) return;
    _targetLanguage = language;
    _notify();
    await _save();
  }

  Future<void> setHotKey(HotKey key) async {
    if (busy || recording) return;
    final reenable = enabled;
    await setEnabled(false);
    _hotKey = _normalizedHotKey(key);
    await _save();
    if (reenable) await setEnabled(true);
    _notify();
  }

  Future<void> setEnabled(bool value) async {
    if (!value) {
      _armGeneration++;
      _enabled = false;
      _keyReleaseTimer?.cancel();
      _keyHeld = false;
      cancel();
      if (!_testing) {
        if (_registeredHotKey != null) {
          _shortcutCleanup = Future.wait<void>([
            _shortcutCleanup,
            _unregisterHotKey(),
          ]).then((_) {});
        }
        await _shortcutCleanup;
      }
      if (!_enabled) _status = 'Disabled';
      _notify();
      return;
    }
    if (_enabled || _arming) return;
    final armGeneration = ++_armGeneration;
    _arming = true;
    _error = null;
    _notify();
    try {
      await load();
      if (armGeneration != _armGeneration) return;
      if (!supported && !_testing) {
        throw StateError('Voice translate requires Windows.');
      }
      if (!await _appIsOpen()) {
        throw StateError('Open luma to enable voice translation.');
      }
      if (armGeneration != _armGeneration) return;
      if (!_serverReady) throw const ServerAccessDeniedException();
      if (!_testing) {
        await _shortcutCleanup;
        if (_windowsKey(_hotKey) == null) {
          throw StateError(
            'Choose a letter, number, function key, or navigation key.',
          );
        }
        if (!_hotKeyAvailable()) {
          throw StateError(
            'This keybind is already in use. Choose another keybind.',
          );
        }
        if (armGeneration != _armGeneration) return;
        await hotKeyManager.register(
          _hotKey,
          keyDownHandler: (_) => _onHotKey(),
        );
        _registeredHotKey = _hotKey;
        if (armGeneration != _armGeneration) {
          await _unregisterHotKey();
          return;
        }
      }
      _enabled = true;
      _account = _accountIdentity;
      _status = 'Ready';
    } catch (error) {
      _error = '$error';
      _status = 'Disabled';
    } finally {
      _arming = false;
      _notify();
    }
  }

  Future<void> _unregisterHotKey() async {
    final registered = _registeredHotKey;
    _registeredHotKey = null;
    if (registered == null) return;
    try {
      await hotKeyManager.unregister(registered);
    } catch (_) {}
  }

  void _onHotKey() {
    if (_keyHeld || !enabled) return;
    _keyHeld = true;
    final virtualKey = _windowsKey(_hotKey)!;
    _keyReleaseTimer?.cancel();
    _keyReleaseTimer = Timer.periodic(const Duration(milliseconds: 40), (
      timer,
    ) {
      if ((GetAsyncKeyState(virtualKey) & 0x8000) == 0) {
        _keyHeld = false;
        timer.cancel();
      }
    });
    unawaited(toggleRecording());
  }

  bool _hotKeyAvailable() {
    var flags = 0;
    for (final modifier in _hotKey.modifiers ?? const <HotKeyModifier>[]) {
      flags |= switch (modifier) {
        HotKeyModifier.alt => MOD_ALT,
        HotKeyModifier.control => MOD_CONTROL,
        HotKeyModifier.shift => MOD_SHIFT,
        HotKeyModifier.meta => MOD_WIN,
        _ => throw StateError(
          'Use Ctrl, Shift, Alt or Win as keybind modifiers.',
        ),
      };
    }
    const probeId = 0x7108;
    if (RegisterHotKey(NULL, probeId, flags, _windowsKey(_hotKey)!) == 0) {
      return false;
    }
    UnregisterHotKey(NULL, probeId);
    return true;
  }

  int? _windowsKey(HotKey hotKey) {
    final key = hotKey.logicalKey;
    final label = key.keyLabel.toUpperCase();
    if (label.length == 1) {
      final code = label.codeUnitAt(0);
      if ((code >= 0x41 && code <= 0x5a) || (code >= 0x30 && code <= 0x39)) {
        return code;
      }
    }
    final function = RegExp(r'^F([1-9]|1[0-9]|2[0-4])$').firstMatch(label);
    if (function != null) return VK_F1 + int.parse(function.group(1)!) - 1;
    return {
      LogicalKeyboardKey.space: VK_SPACE,
      LogicalKeyboardKey.enter: VK_RETURN,
      LogicalKeyboardKey.tab: VK_TAB,
      LogicalKeyboardKey.escape: VK_ESCAPE,
      LogicalKeyboardKey.backspace: VK_BACK,
      LogicalKeyboardKey.delete: VK_DELETE,
      LogicalKeyboardKey.insert: VK_INSERT,
      LogicalKeyboardKey.home: VK_HOME,
      LogicalKeyboardKey.end: VK_END,
      LogicalKeyboardKey.pageUp: VK_PRIOR,
      LogicalKeyboardKey.pageDown: VK_NEXT,
      LogicalKeyboardKey.arrowLeft: VK_LEFT,
      LogicalKeyboardKey.arrowRight: VK_RIGHT,
      LogicalKeyboardKey.arrowUp: VK_UP,
      LogicalKeyboardKey.arrowDown: VK_DOWN,
    }[key];
  }

  Future<void> toggleRecording() async {
    if (!enabled || busy) return;
    if (!await _appIsOpen()) {
      await setEnabled(false);
      return;
    }
    if (!enabled || busy) return;
    if (_recording) {
      await _finishRecording();
      return;
    }
    final generation = ++_generation;
    _busy = true;
    _error = null;
    _transcript = null;
    _translation = null;
    _status = 'Opening microphone…';
    _notify();
    try {
      if (!_serverReady) throw const ServerAccessDeniedException();
      await _cleanup;
      if (generation != _generation) return;
      await _recorder.start();
      if (generation != _generation) return;
      _recording = true;
      _status = 'Recording — press the keybind again to translate and send';
      _recordingLimit = Timer(
        const Duration(seconds: 30),
        () => unawaited(_finishRecording()),
      );
    } catch (error) {
      if (generation == _generation) {
        _error = '$error';
        _status = 'Recording failed';
      }
    } finally {
      if (generation == _generation) {
        _busy = false;
        _notify();
      }
    }
  }

  Future<void> _finishRecording() async {
    if (!_recording || _busy) return;
    final generation = _generation;
    final account = _accountIdentity;
    final language = _targetLanguage;
    bool current() =>
        generation == _generation &&
        enabled &&
        _serverReady &&
        account == _accountIdentity;
    _recordingLimit?.cancel();
    _recording = false;
    _busy = true;
    _status = 'Transcribing and translating…';
    _notify();
    try {
      final audio = await _recorder.stop();
      if (!current()) return;
      final result =
          await (_translateOverride?.call(audio, language) ??
              _requestTranslation(audio, language));
      if (!current()) return;
      if (!await _appIsOpen()) {
        await setEnabled(false);
        return;
      }
      if (!current()) return;
      if (result.transcript.trim().isEmpty ||
          result.translation.trim().isEmpty) {
        throw const FormatException('No speech or translation was returned.');
      }
      _transcript = result.transcript;
      _translation = result.translation;
      _status = 'Sending to CS2 console…';
      _notify();
      final sent = await _send(result.translation, current);
      if (!current()) return;
      _translation = sent;
      _status = 'Sent to CS2 console';
    } on Cs2VoiceCancelled {
      return;
    } catch (error) {
      if (current()) {
        _error = error is SocketException
            ? 'Cannot connect to CS2 on port 2121. Launch CS2 with -condebug -netconport 2121.'
            : '$error';
        _status = 'Message was not sent';
      }
    } finally {
      if (generation == _generation) {
        _busy = false;
        _notify();
      }
    }
  }

  Future<Cs2VoiceTranslation> _requestTranslation(
    Uint8List audio,
    String language,
  ) async {
    final sync = _sync;
    if (sync == null || !sync.serverReady) {
      throw const ServerAccessDeniedException();
    }
    final token = sync.authToken;
    final base = Uri.parse(sync.serverUrl!);
    final endpoint = base.replace(
      path:
          '${base.path.replaceAll(RegExp(r'/+$'), '')}/api/v1/cs2/voice-translate',
      query: null,
      fragment: null,
    );
    final client = _activeClient = GatedServerClient();
    try {
      final response = await client
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'audioBase64': base64Encode(audio),
              'mimeType': 'audio/wav',
              'targetLanguage': language,
            }),
          )
          .timeout(const Duration(seconds: 90));
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200) {
        final message = body is Map ? body['message'] ?? body['error'] : null;
        throw StateError(
          message is String
              ? message
              : 'Voice translation failed (${response.statusCode}).',
        );
      }
      return Cs2VoiceTranslation.fromJson(
        Map<String, dynamic>.from(body as Map),
      );
    } finally {
      client.close();
      if (identical(_activeClient, client)) _activeClient = null;
      if (identical(_sync, sync) &&
          sync.serverReady &&
          sync.authToken == token) {
        sync.notifyAiUsageChanged();
      }
    }
  }

  void cancel() {
    _generation++;
    _recordingLimit?.cancel();
    _activeClient?.close();
    _activeClient = null;
    _cleanup = Future.wait<void>([_cleanup, _recorder.cancel()]).then((_) {});
    _recording = false;
    _busy = false;
    _status = enabled ? 'Cancelled — ready' : 'Disabled';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_appCloseSubscription?.cancel());
    _sync?.removeListener(_onAccountChanged);
    _keyReleaseTimer?.cancel();
    cancel();
    if (!_testing) unawaited(_unregisterHotKey());
    super.dispose();
  }
}
