import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../../../app/window_controls.dart';
import '../../../../../sync/server_access.dart';
import '../../../../../sync/sync_service.dart';
import 'cs2_translator_service.dart';
import 'cs2_voice_protocol.dart';

class Cs2VoiceInputDevice {
  const Cs2VoiceInputDevice(this.id, this.name);
  final int id;
  final String name;
}

/// Captures an explicitly selected Windows recording source. The source may
/// contain more than game voice, so it must be routed by the user.
class Cs2TeammateVoiceService extends ChangeNotifier {
  Cs2TeammateVoiceService._() {
    Cs2TranslatorService.instance.addListener(_translatorChanged);
    _closeSubscription = windowCloseEvents.listen((_) => stop());
  }

  static final instance = Cs2TeammateVoiceService._();
  final _queue = <Uint8List>[];
  SyncService? _sync;
  StreamSubscription<void>? _closeSubscription;
  Process? _process;
  Directory? _directory;
  http.Client? _client;
  int _generation = 0;
  bool _running = false;
  bool _processing = false;
  String? _account;
  String _language = 'en';
  String? _error;
  bool get running => _running;
  String? get error => _error;

  void configure(SyncService? sync) {
    if (identical(sync, _sync)) return;
    _sync?.removeListener(_accountChanged);
    stop();
    _sync = sync;
    sync?.addListener(_accountChanged);
  }

  String _identity(SyncService sync) => '${sync.serverUrl}|${sync.authToken}';
  void _accountChanged() {
    final sync = _sync;
    if (_running &&
        (sync == null || !sync.serverReady || _account != _identity(sync))) {
      stop();
    }
  }

  void _translatorChanged() {
    if (_running && !Cs2TranslatorService.instance.running) stop();
  }

  Future<File> _writeScript(Directory dir) async {
    final script = await rootBundle.loadString(
      'assets/cs2_translator/cs2-voice-recorder.ps1',
    );
    return File('${dir.path}/recorder.ps1').writeAsString(script, flush: true);
  }

  List<String> _args(File script) => [
    '-NoProfile',
    '-NonInteractive',
    '-ExecutionPolicy',
    'Bypass',
    '-WindowStyle',
    'Hidden',
    '-File',
    script.path,
  ];

  Future<List<Cs2VoiceInputDevice>> listDevices() async {
    final dir = await Directory.systemTemp.createTemp('luma-cs2-inputs-');
    try {
      final script = await _writeScript(dir);
      final result = await Process.run('powershell.exe', [
        ..._args(script),
        '-ListDevices',
      ]).timeout(const Duration(seconds: 20));
      if (result.exitCode != 0) {
        throw StateError(
          'Could not list Windows recording devices: ${result.stderr}',
        );
      }
      final list = jsonDecode(result.stdout as String) as List<dynamic>;
      return [
        for (final item in list)
          Cs2VoiceInputDevice(item['id'] as int, item['name'] as String),
      ];
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> start(int deviceId, String language) async {
    if (_running) return;
    final sync = _sync;
    if (sync == null || !sync.serverReady) {
      _error =
          'Sign in to an approved Luma account to use voice transcription.';
      notifyListeners();
      return;
    }
    if (!Cs2TranslatorService.instance.running) {
      _error = 'Start the chat translator first.';
      notifyListeners();
      return;
    }
    final generation = ++_generation;
    _running = true;
    _error = null;
    _account = _identity(sync);
    _language = language.trim().isEmpty ? 'en' : language.trim();
    notifyListeners();
    Directory? dir;
    try {
      dir = await Directory.systemTemp.createTemp('luma-cs2-listen-');
      if (generation != _generation) return;
      _directory = dir;
      final script = await _writeScript(dir);
      if (generation != _generation) return;
      final commands = Directory('${dir.path}/commands');
      await commands.create();
      final process = await Process.start('powershell.exe', [
        ..._args(script),
        '-CommandDirectory',
        commands.path,
        '-DeviceId',
        '$deviceId',
        '-Continuous',
      ]);
      if (generation != _generation) {
        process.kill();
        return;
      }
      _process = process;
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (generation != _generation) return;
              try {
                final event = jsonDecode(line) as Map<String, dynamic>;
                if (event['event'] == 'error') {
                  _fail('Audio capture failed: ${event['message']}');
                } else if (event['event'] == 'audio') {
                  if (_queue.length >= 4) {
                    _fail(
                      'Transcription cannot keep up with the audio. Listening stopped.',
                    );
                    return;
                  }
                  _queue.add(base64Decode(event['data'] as String));
                  unawaited(_drain(generation));
                }
              } catch (error) {
                _fail('Audio capture failed: $error');
              }
            },
            onError: (Object error) {
              if (generation == _generation) {
                _fail('Audio capture failed: $error');
              }
            },
          );
      process.stderr.drain<void>();
      unawaited(
        process.exitCode.then((_) {
          if (generation == _generation) {
            _fail('The audio capture stopped unexpectedly.');
          }
        }),
      );
    } catch (error) {
      if (generation == _generation) {
        _fail('Could not start audio capture: $error');
      }
    } finally {
      if (dir != null && generation != _generation) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<void> _drain(int generation) async {
    if (_processing) return;
    _processing = true;
    try {
      while (_queue.isNotEmpty && generation == _generation) {
        final audio = _queue.removeAt(0);
        final result = await _request(audio);
        if (generation != _generation) return;
        if (result == null) continue;
        await Cs2TranslatorService.instance.showVoiceLine(
          result.transcript,
          result.translation,
        );
      }
    } catch (error) {
      if (generation == _generation) _fail('Voice translation stopped: $error');
    } finally {
      _processing = false;
      if (_queue.isNotEmpty && _running) unawaited(_drain(_generation));
    }
  }

  Future<Cs2VoiceTranslation?> _request(Uint8List audio) async {
    final sync = _sync;
    if (sync == null || !sync.serverReady || _identity(sync) != _account) {
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
    final client = _client = GatedServerClient();
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
              'targetLanguage': _language,
              'allowEmptyTranscript': true,
            }),
          )
          .timeout(const Duration(seconds: 90));
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200) {
        throw StateError(
          body is Map
              ? '${body['message'] ?? body['error'] ?? response.statusCode}'
              : 'Server error ${response.statusCode}',
        );
      }
      if (body is Map &&
          body['transcript'] == '' &&
          body['translation'] == '') {
        return null;
      }
      return Cs2VoiceTranslation.fromJson(
        Map<String, dynamic>.from(body as Map),
      );
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
      if (identical(_sync, sync) &&
          sync.serverReady &&
          sync.authToken == token) {
        sync.notifyAiUsageChanged();
      }
    }
  }

  void _fail(String message) {
    stop();
    _error = message;
    notifyListeners();
  }

  void stop() {
    _generation++;
    _running = false;
    _queue.clear();
    _client?.close();
    _client = null;
    _process?.kill();
    _process = null;
    final dir = _directory;
    _directory = null;
    if (dir != null) unawaited(_removeDirectory(dir));
    notifyListeners();
  }

  Future<void> _removeDirectory(Directory dir) async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _closeSubscription?.cancel();
    _sync?.removeListener(_accountChanged);
    Cs2TranslatorService.instance.removeListener(_translatorChanged);
    stop();
    super.dispose();
  }
}
