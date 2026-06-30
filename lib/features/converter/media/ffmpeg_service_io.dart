import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Raised when ffmpeg is missing or a transcode fails.
class FfmpegException implements Exception {
  const FfmpegException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What we learn about a video by probing it with ffmpeg.
class VideoInfo {
  const VideoInfo({
    required this.durationSec,
    required this.width,
    required this.height,
    required this.fps,
    required this.hasAudio,
    required this.ok,
  });

  final double durationSec;
  final int width;
  final int height;
  final double fps;
  final bool hasAudio;
  final bool ok;

  static const unavailable = VideoInfo(
    durationSec: 0,
    width: 0,
    height: 0,
    fps: 0,
    hasAudio: false,
    ok: false,
  );
}

/// Desktop implementation: locates an ffmpeg binary and shells out to it.
///
/// Resolution order:
///   1. An `ffmpeg(.exe)` sitting next to the app executable (bundled).
///   2. A `bin/ffmpeg(.exe)` folder next to the app executable.
///   3. `ffmpeg` on the system PATH.
class Ffmpeg {
  const Ffmpeg._();

  static String? _resolved;
  static bool _probed = false;

  static String get _exeName => Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';

  /// Returns the resolved ffmpeg path (cached), or null if none was found.
  static Future<String?> resolve() async {
    if (_probed) return _resolved;
    _probed = true;

    // 0. A binary installed via the in-app installer (writable app support dir).
    try {
      final support = await getApplicationSupportDirectory();
      final installed =
          '${support.path}${Platform.pathSeparator}ffmpeg${Platform.pathSeparator}$_exeName';
      if (File(installed).existsSync()) {
        _resolved = installed;
        return _resolved;
      }
    } catch (_) {
      // path_provider unavailable — fall through to the other candidates.
    }

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    final candidates = <String>[
      '$exeDir$sep$_exeName',
      '$exeDir${sep}bin$sep$_exeName',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) {
        _resolved = path;
        return _resolved;
      }
    }

    // Fall back to PATH: probe `ffmpeg -version`.
    if (await _runs('ffmpeg')) {
      _resolved = 'ffmpeg';
      return _resolved;
    }

    _resolved = null;
    return null;
  }

  static Future<bool> _runs(String exe) async {
    try {
      final result = await Process.run(exe, const ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Forces re-resolution on the next [resolve] call (used after the user
  /// installs ffmpeg without restarting).
  static void invalidate() {
    _probed = false;
    _resolved = null;
  }

  /// Pins the resolver to a specific binary (used right after the in-app
  /// installer writes one).
  static void useBinary(String path) {
    _resolved = path;
    _probed = true;
  }

  static Future<bool> available() async => (await resolve()) != null;

  /// Writes [input] to a temp file, runs ffmpeg with [args] inserted between
  /// the input and output flags, and returns the produced bytes.
  static Future<Uint8List> transcode({
    required Uint8List input,
    required String inputExtension,
    required String outputExtension,
    required List<String> args,
  }) async {
    final exe = await resolve();
    if (exe == null) {
      throw const FfmpegException(
        'ffmpeg was not found. Place ffmpeg(.exe) next to the app or on your '
        'system PATH, then try again.',
      );
    }

    final sep = Platform.pathSeparator;
    final dir = await Directory.systemTemp.createTemp('luma_ffmpeg_');
    final inPath = '${dir.path}${sep}in.$inputExtension';
    final outPath = '${dir.path}${sep}out.$outputExtension';
    try {
      await File(inPath).writeAsBytes(input, flush: true);

      final result = await Process.run(exe, [
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        '-i',
        inPath,
        ...args,
        outPath,
      ]);

      final outFile = File(outPath);
      if (result.exitCode != 0 || !outFile.existsSync()) {
        final stderr = (result.stderr ?? '').toString().trim();
        throw FfmpegException(
          stderr.isEmpty
              ? 'ffmpeg failed (exit code ${result.exitCode}).'
              : 'ffmpeg failed: ${_firstLine(stderr)}',
        );
      }
      return await outFile.readAsBytes();
    } finally {
      // Best-effort cleanup of the scratch directory.
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Probes a video file for duration, dimensions, frame rate and audio,
  /// parsed from ffmpeg's diagnostic output.
  static Future<VideoInfo> probeVideo(String inputPath) async {
    final exe = await resolve();
    if (exe == null) return VideoInfo.unavailable;
    final result = await Process.run(exe, ['-hide_banner', '-i', inputPath]);
    // `ffmpeg -i` with no output errors out but still prints stream metadata.
    final err = (result.stderr ?? '').toString();

    var duration = 0.0;
    final d = RegExp(r'Duration: (\d+):(\d+):(\d+(?:\.\d+)?)').firstMatch(err);
    if (d != null) {
      duration = int.parse(d[1]!) * 3600 +
          int.parse(d[2]!) * 60 +
          double.parse(d[3]!);
    }

    var w = 0, h = 0;
    var fps = 0.0;
    final videoLine =
        RegExp(r'Video:.*').firstMatch(err)?.group(0) ?? '';
    final dim = RegExp(r'(\d{2,5})x(\d{2,5})').firstMatch(videoLine);
    if (dim != null) {
      w = int.parse(dim[1]!);
      h = int.parse(dim[2]!);
    }
    final f = RegExp(r'(\d+(?:\.\d+)?) fps').firstMatch(videoLine);
    if (f != null) fps = double.parse(f[1]!);

    final hasAudio = RegExp(r'Stream #\d+:\d+.*: Audio:').hasMatch(err);

    return VideoInfo(
      durationSec: duration,
      width: w,
      height: h,
      fps: fps,
      hasAudio: hasAudio,
      ok: w > 0 && duration > 0,
    );
  }

  /// Encodes a short slice of [inputPath] with [args] and returns the byte
  /// length of the result — the basis for a sample-extrapolated estimate.
  static Future<int> sampleSize({
    required String inputPath,
    required List<String> args,
    required String outputExtension,
    required double startSeconds,
    required double sampleSeconds,
  }) async {
    final exe = await resolve();
    if (exe == null) {
      throw const FfmpegException('ffmpeg was not found.');
    }
    final sep = Platform.pathSeparator;
    final dir = await Directory.systemTemp.createTemp('luma_vsample_');
    final outPath = '${dir.path}${sep}out.$outputExtension';
    try {
      final result = await Process.run(exe, [
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        '-ss',
        startSeconds.toStringAsFixed(2),
        '-i',
        inputPath,
        '-t',
        sampleSeconds.toStringAsFixed(2),
        ...args,
        outPath,
      ]);
      final outFile = File(outPath);
      if (result.exitCode != 0 || !outFile.existsSync()) {
        final stderr = (result.stderr ?? '').toString().trim();
        throw FfmpegException(
          stderr.isEmpty
              ? 'ffmpeg failed (exit code ${result.exitCode}).'
              : 'ffmpeg failed: ${_firstLine(stderr)}',
        );
      }
      return await outFile.length();
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Transcodes a file at [inputPath] with [args] and returns the full output
  /// bytes (used for the final downscaled video).
  static Future<Uint8List> transcodePath({
    required String inputPath,
    required List<String> args,
    required String outputExtension,
  }) async {
    final exe = await resolve();
    if (exe == null) {
      throw const FfmpegException(
        'ffmpeg was not found. Place ffmpeg(.exe) next to the app or on your '
        'system PATH, then try again.',
      );
    }
    final sep = Platform.pathSeparator;
    final dir = await Directory.systemTemp.createTemp('luma_vconv_');
    final outPath = '${dir.path}${sep}out.$outputExtension';
    try {
      final result = await Process.run(exe, [
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        '-i',
        inputPath,
        ...args,
        outPath,
      ]);
      final outFile = File(outPath);
      if (result.exitCode != 0 || !outFile.existsSync()) {
        final stderr = (result.stderr ?? '').toString().trim();
        throw FfmpegException(
          stderr.isEmpty
              ? 'ffmpeg failed (exit code ${result.exitCode}).'
              : 'ffmpeg failed: ${_firstLine(stderr)}',
        );
      }
      return await outFile.readAsBytes();
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  static String _firstLine(String s) {
    final i = s.indexOf('\n');
    return i == -1 ? s : s.substring(0, i);
  }
}
