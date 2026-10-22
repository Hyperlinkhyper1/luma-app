import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cs2_voice_protocol.dart';

abstract interface class Cs2VoiceRecorder {
  Future<void> start();
  Future<Uint8List> stop();
  Future<void> cancel();
}

class WindowsCs2VoiceRecorder implements Cs2VoiceRecorder {
  WindowsCs2VoiceRecorder()
    : _startProcess = Process.start,
      _loadScript = _loadBundledScript,
      _stopTimeout = const Duration(seconds: 10),
      _cleanupTimeout = const Duration(seconds: 2);

  @visibleForTesting
  factory WindowsCs2VoiceRecorder.forTesting({
    required Future<Process> Function(String, List<String>) startProcess,
    required Future<String> Function() loadScript,
    Duration stopTimeout = const Duration(seconds: 10),
    Duration cleanupTimeout = const Duration(seconds: 2),
  }) => WindowsCs2VoiceRecorder._withDependencies(
    startProcess,
    loadScript,
    stopTimeout,
    cleanupTimeout,
  );

  WindowsCs2VoiceRecorder._withDependencies(
    this._startProcess,
    this._loadScript,
    this._stopTimeout,
    this._cleanupTimeout,
  );

  static Future<String> _loadBundledScript() =>
      rootBundle.loadString('assets/cs2_translator/cs2-voice-recorder.ps1');

  final Future<Process> Function(String, List<String>) _startProcess;
  final Future<String> Function() _loadScript;
  final Duration _stopTimeout;
  final Duration _cleanupTimeout;
  Process? _process;
  Directory? _directory;
  Completer<Uint8List>? _audio;
  int _generation = 0;

  static String _commandPath(Directory directory) =>
      '${directory.path}${Platform.pathSeparator}command';

  // The helper polls for this file: a line written to its stdin through
  // Process.start never reaches Windows PowerShell's Console.In.
  static Future<void> _send(Directory directory, String command) async {
    final pending = File('${_commandPath(directory)}.tmp');
    await pending.writeAsString(command, flush: true);
    await pending.rename(_commandPath(directory));
  }

  @override
  Future<void> start() async {
    final generation = ++_generation;
    final script = await _loadScript();
    if (generation != _generation) throw const Cs2VoiceCancelled();
    final directory = await Directory.systemTemp.createTemp('luma-cs2-voice-');
    if (generation != _generation) {
      await directory.delete(recursive: true);
      throw const Cs2VoiceCancelled();
    }
    _directory = directory;
    try {
      final file = File('${directory.path}/recorder.ps1');
      await file.writeAsString(script, flush: true);
      if (generation != _generation) throw const Cs2VoiceCancelled();
      final process = await _startProcess('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        file.path,
        _commandPath(directory),
      ]);
      if (generation != _generation) {
        process.kill();
        throw const Cs2VoiceCancelled();
      }
      _process = process;
      final started = Completer<void>();
      final audio = _audio = Completer<Uint8List>();
      unawaited(audio.future.then<void>((_) {}, onError: (Object _) {}));
      void fail(Object error) {
        if (!started.isCompleted) started.completeError(error);
        if (!audio.isCompleted) audio.completeError(error);
      }

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              try {
                final event = jsonDecode(line) as Map<String, dynamic>;
                switch (event['event']) {
                  case 'recording':
                    if (!started.isCompleted) started.complete();
                  case 'audio':
                    if (!audio.isCompleted) {
                      audio.complete(base64Decode(event['data'] as String));
                    }
                  case 'error':
                    fail(StateError('Microphone: ${event['message']}'));
                }
              } catch (error) {
                fail(error);
              }
            },
            onError: fail,
            onDone: () {
              if (!audio.isCompleted) {
                fail(
                  StateError('The microphone recorder closed unexpectedly.'),
                );
              }
            },
          );
      process.stderr.listen((_) {}, onError: fail);
      await started.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      if (generation == _generation) await cancel();
      rethrow;
    }
  }

  @override
  Future<Uint8List> stop() async {
    final generation = _generation;
    final process = _process;
    final directory = _directory;
    final audio = _audio;
    if (process == null || directory == null || audio == null) {
      throw const Cs2VoiceCancelled();
    }
    try {
      await _send(directory, 'stop').timeout(_stopTimeout);
      final bytes = await audio.future.timeout(_stopTimeout);
      await process.exitCode.timeout(const Duration(seconds: 3));
      return bytes;
    } on TimeoutException {
      throw StateError(
        'The microphone did not finish recording. Try again or check your '
        'default Windows microphone and its privacy permissions.',
      );
    } finally {
      if (generation == _generation) await cancel();
    }
  }

  @override
  Future<void> cancel() async {
    _generation++;
    final process = _process;
    final directory = _directory;
    final audio = _audio;
    _process = null;
    _directory = null;
    _audio = null;
    if (audio != null && !audio.isCompleted) {
      audio.completeError(const Cs2VoiceCancelled());
    }
    if (process != null) {
      try {
        if (directory != null) {
          await _send(directory, 'cancel').timeout(_cleanupTimeout);
        }
        await process.exitCode.timeout(_cleanupTimeout);
      } catch (_) {
        process.kill();
        try {
          await process.exitCode.timeout(_cleanupTimeout);
        } catch (_) {}
      }
    }
    if (directory != null) {
      try {
        await directory.delete(recursive: true);
      } catch (_) {}
    }
  }
}
