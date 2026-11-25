import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cs2_dataset/cs2_dataset.dart';
import 'package:shelf/shelf.dart';

import 'util.dart';

class Cs2ReplayImporter {
  Cs2ReplayImporter(this.executable);

  final String executable;
  static final _digestPattern = RegExp(r'^[a-f0-9]{64}$');
  var _busy = false;

  Future<Response> import(
    Request request,
    FutureOr<Response> Function(Cs2Match match, String digest) accept,
  ) async {
    final name = request.url.queryParameters['name']?.toLowerCase() ?? '';
    if (request.headers['content-type'] != 'application/octet-stream' ||
        (!name.endsWith('.dem') && !name.endsWith('.dem.bz2'))) {
      return errorResponse(
          415, 'replay_type', 'Choose a .dem or .dem.bz2 file.');
    }
    if ((request.contentLength ?? 0) > cs2MaxReplayBytes) return _tooLarge();
    if (_busy) {
      return errorResponse(429, 'replay_busy',
          'A replay is already being processed. Try again shortly.');
    }

    _busy = true;
    Directory? scratch;
    try {
      scratch = await Directory.systemTemp.createTemp('luma-cs2-');
      final file = File('${scratch.path}/replay');
      final sink = await file.open(mode: FileMode.writeOnly);
      var length = 0;
      final stopwatch = Stopwatch()..start();
      try {
        await for (final chunk
            in request.read().timeout(const Duration(seconds: 30))) {
          length += chunk.length;
          if (length > cs2MaxReplayBytes) return _tooLarge();
          if (stopwatch.elapsed > const Duration(minutes: 2)) {
            throw TimeoutException('Replay upload timed out.');
          }
          await sink.writeFrom(chunk);
        }
      } finally {
        await sink.close();
      }
      if (length < 8) {
        return errorResponse(
            400, 'replay_invalid', 'The replay is empty or incomplete.');
      }

      final process = await Process.start(
        executable,
        [file.path],
        workingDirectory: scratch.path,
        includeParentEnvironment: false,
        environment: {'GOMAXPROCS': '2', 'GOMEMLIMIT': '256MiB'},
      );
      final output = utf8.decoder.bind(process.stdout).join();
      final errors = process.stderr.drain<void>();
      try {
        final exit =
            await process.exitCode.timeout(const Duration(seconds: 35));
        if (exit != 0) return _unreadable();
        final decoded = jsonDecode(await output) as Map<String, dynamic>;
        final match = Cs2Match.fromJson(decoded);
        final digest = decoded['digest'];
        if (digest is! String || !_digestPattern.hasMatch(digest)) {
          throw const FormatException('Invalid replay digest.');
        }
        return await accept(match, digest);
      } on FormatException {
        return _unreadable();
      } on TypeError {
        return _unreadable();
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
        return errorResponse(
            422, 'replay_timeout', 'This replay took too long to analyze.');
      } finally {
        await output;
        await errors;
      }
    } on TimeoutException {
      return errorResponse(
          408, 'replay_upload_timeout', 'Replay upload timed out.');
    } on ProcessException {
      return errorResponse(503, 'replay_unavailable',
          'Replay processing is unavailable on this server.');
    } finally {
      try {
        await scratch?.delete(recursive: true);
      } finally {
        _busy = false;
      }
    }
  }

  Response _tooLarge() => errorResponse(413, 'replay_too_large',
      'Replay files must be 95 MiB or smaller. Try the .dem.bz2 version.');

  Response _unreadable() => errorResponse(422, 'replay_unreadable',
      'No supported CS2 bomb-defusal rounds could be read from this replay.');
}
