import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cs2_dataset/cs2_dataset.dart';
import 'package:shelf/shelf.dart';

import 'cs2_heatmap.dart';
import 'util.dart';

/// Streams an uploaded replay to a private scratch folder, runs the parser on
/// it and hands back the extracted rounds and positions. The replay itself is
/// never kept: its folder is deleted as soon as the parser is done, whatever
/// the outcome, and anything a crash left behind is swept on startup.
class Cs2ReplayImporter {
  Cs2ReplayImporter(
    this.executable, {
    this.arguments = const [],
    Directory? scratchRoot,
  }) : scratchRoot = scratchRoot ??
            Directory('${Directory.systemTemp.path}/luma-cs2-replays') {
    _sweep();
  }

  final String executable;

  /// Placed before the replay path; lets tests run a script as the parser.
  final List<String> arguments;

  /// Holds one sub-folder per replay being processed, and nothing else.
  final Directory scratchRoot;

  static final _digestPattern = RegExp(r'^[a-f0-9]{64}$');
  var _busy = false;

  Future<Response> import(
    Request request,
    FutureOr<Response> Function(Cs2Match match, String digest, Cs2Heatmap heat)
        accept,
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
      await scratchRoot.create(recursive: true);
      scratch = await scratchRoot.createTemp('replay-');
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
        [...arguments, file.path],
        workingDirectory: scratch.path,
        includeParentEnvironment: false,
        environment: {
          'GOMAXPROCS': '2',
          'GOMEMLIMIT': '256MiB',
          if (Platform.isWindows)
            'SYSTEMROOT': Platform.environment['SYSTEMROOT'] ?? r'C:\Windows',
        },
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
        final heat = Cs2Heatmap.fromSamples(decoded['heat'] ?? const []);
        await _discard(scratch);
        scratch = null;
        return await accept(match, digest, heat);
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
        if (scratch != null) await _discard(scratch);
      } finally {
        _busy = false;
      }
    }
  }

  /// Deletes a replay folder. On Windows a just-killed parser can hold the
  /// file for a moment, so retry briefly; a failure must never replace the
  /// response, and the startup sweep catches anything still left.
  static Future<void> _discard(Directory folder) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (await folder.exists()) await folder.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(Duration(milliseconds: 100 << attempt));
      }
    }
  }

  void _sweep() {
    try {
      if (!scratchRoot.existsSync()) return;
      for (final entry in scratchRoot.listSync(followLinks: false)) {
        try {
          entry.deleteSync(recursive: true);
        } on FileSystemException {
          continue;
        }
      }
    } on FileSystemException {
      return;
    }
  }

  Response _tooLarge() => errorResponse(413, 'replay_too_large',
      'Replay files must be 95 MiB or smaller. Try the .dem.bz2 version.');

  Response _unreadable() => errorResponse(422, 'replay_unreadable',
      'No supported CS2 bomb-defusal rounds could be read from this replay.');
}
