import 'dart:typed_data';

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

/// Web/stub implementation: ffmpeg is never available.
class Ffmpeg {
  const Ffmpeg._();

  static Future<String?> resolve() async => null;

  static Future<bool> available() async => false;

  static void invalidate() {}

  static void useBinary(String path) {}

  static Future<Uint8List> transcode({
    required Uint8List input,
    required String inputExtension,
    required String outputExtension,
    required List<String> args,
  }) {
    throw const FfmpegException(
      'Audio and video conversion is only available in the desktop app.',
    );
  }

  static Future<VideoInfo> probeVideo(String inputPath) async =>
      VideoInfo.unavailable;

  static Future<int> sampleSize({
    required String inputPath,
    required List<String> args,
    required String outputExtension,
    required double startSeconds,
    required double sampleSeconds,
  }) {
    throw const FfmpegException(
      'Video conversion is only available in the desktop app.',
    );
  }

  static Future<Uint8List> transcodePath({
    required String inputPath,
    required List<String> args,
    required String outputExtension,
  }) {
    throw const FfmpegException(
      'Video conversion is only available in the desktop app.',
    );
  }
}
