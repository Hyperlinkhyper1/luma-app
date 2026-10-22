import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'cs2_voice_protocol.dart';

abstract interface class Cs2VoiceRecorder {
  Future<void> start();
  Future<Uint8List> stop();
  Future<void> cancel();
}

class WindowsCs2VoiceRecorder implements Cs2VoiceRecorder {
  Process? _process;
  Directory? _directory;
  Completer<Uint8List>? _audio;
  int _generation = 0;

  @override
  Future<void> start() async {
    final generation = ++_generation;
    final script = await rootBundle.loadString(
      'assets/cs2_translator/cs2-voice-recorder.ps1',
    );
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
      final process = await Process.start('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        file.path,
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
    final audio = _audio;
    if (process == null || audio == null) throw const Cs2VoiceCancelled();
    try {
      process.stdin.writeln('stop');
      await process.stdin.flush();
      final bytes = await audio.future.timeout(const Duration(seconds: 10));
      await process.exitCode.timeout(const Duration(seconds: 3));
      return bytes;
    } finally {
      if (generation == _generation) await cancel();
    }
  }

  @override
  Future<void> cancel() async {
    _generation++;
    final process = _process;
    final directory = _directory;
    _process = null;
    _directory = null;
    if (process != null) {
      try {
        process.stdin.writeln('cancel');
        await process.stdin.flush();
        await process.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        process.kill();
      }
    }
    if (directory != null) {
      try {
        await directory.delete(recursive: true);
      } catch (_) {}
    }
  }
}
