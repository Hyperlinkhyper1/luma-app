import 'package:flutter/foundation.dart';

import 'media/ffmpeg_service.dart';

/// The video-downscaler optimization knobs.
@immutable
class VideoParams {
  const VideoParams({
    this.resize = false,
    this.maxHeight = 720,
    this.quality = false,
    this.crf = 26,
    this.fps = false,
    this.targetFps = 30,
    this.h265 = false,
    this.reduceAudio = false,
    this.audioKbps = 128,
    this.removeAudio = false,
    this.stripMetadata = false,
    this.webm = false,
  });

  /// Cap the frame height (keeps aspect): 1080 / 720 / 480 / 360.
  final bool resize;
  final int maxHeight;

  /// Constant Rate Factor (18 = high quality/large … 32 = small).
  final bool quality;
  final int crf;

  /// Cap the frame rate: 30 / 24 / 15.
  final bool fps;
  final int targetFps;

  /// Re-encode video to H.265/HEVC instead of H.264.
  final bool h265;

  /// Re-encode audio at a lower bitrate (kbps).
  final bool reduceAudio;
  final int audioKbps;

  /// Drop the audio track entirely.
  final bool removeAudio;

  /// Strip container metadata / chapters.
  final bool stripMetadata;

  /// Output VP9/WebM instead of H.264/H.265 MP4.
  final bool webm;

  bool get anySelected =>
      resize ||
      quality ||
      fps ||
      h265 ||
      reduceAudio ||
      removeAudio ||
      stripMetadata ||
      webm;

  String get outputExtension => webm ? 'webm' : 'mp4';
  String get mimeType => webm ? 'video/webm' : 'video/mp4';

  VideoParams copyWith({
    bool? resize,
    int? maxHeight,
    bool? quality,
    int? crf,
    bool? fps,
    int? targetFps,
    bool? h265,
    bool? reduceAudio,
    int? audioKbps,
    bool? removeAudio,
    bool? stripMetadata,
    bool? webm,
  }) {
    return VideoParams(
      resize: resize ?? this.resize,
      maxHeight: maxHeight ?? this.maxHeight,
      quality: quality ?? this.quality,
      crf: crf ?? this.crf,
      fps: fps ?? this.fps,
      targetFps: targetFps ?? this.targetFps,
      h265: h265 ?? this.h265,
      reduceAudio: reduceAudio ?? this.reduceAudio,
      audioKbps: audioKbps ?? this.audioKbps,
      removeAudio: removeAudio ?? this.removeAudio,
      stripMetadata: stripMetadata ?? this.stripMetadata,
      webm: webm ?? this.webm,
    );
  }
}

class VideoDownscalerService {
  const VideoDownscalerService._();

  static const heightStops = [1080, 720, 480, 360];
  static const fpsStops = [30, 24, 15];
  static const audioStops = [128, 96, 64];

  /// Default CRF used when "quality" isn't explicitly chosen but the video is
  /// being re-encoded for another reason.
  static const _defaultCrf = 23;

  /// Builds the ffmpeg argument list (everything between input and output) for
  /// [p], using [info] to skip no-op resizes/fps changes.
  static List<String> buildArgs(VideoParams p, VideoInfo info) {
    final videoReencode = p.resize || p.quality || p.fps || p.h265 || p.webm;

    final filters = <String>[];
    if (p.resize && (info.height == 0 || info.height > p.maxHeight)) {
      filters.add('scale=-2:${p.maxHeight}');
    }
    if (p.fps && (info.fps == 0 || info.fps > p.targetFps + 0.5)) {
      filters.add('fps=${p.targetFps}');
    }

    final args = <String>[];
    if (filters.isNotEmpty) args.addAll(['-vf', filters.join(',')]);

    final crf = p.quality ? p.crf : _defaultCrf;
    if (!videoReencode) {
      args.addAll(['-c:v', 'copy']);
    } else if (p.webm) {
      args.addAll([
        '-c:v', 'libvpx-vp9', '-b:v', '0', '-crf', '$crf',
        '-row-mt', '1', '-deadline', 'good',
      ]);
    } else if (p.h265) {
      args.addAll([
        '-c:v', 'libx265', '-crf', '$crf', '-preset', 'medium', '-tag:v', 'hvc1',
      ]);
    } else {
      args.addAll([
        '-c:v', 'libx264', '-crf', '$crf', '-preset', 'medium',
        '-pix_fmt', 'yuv420p',
      ]);
    }

    if (p.removeAudio || !info.hasAudio) {
      args.add('-an');
    } else if (p.webm) {
      args.addAll([
        '-c:a', 'libopus', '-b:a', '${p.reduceAudio ? p.audioKbps : 128}k',
      ]);
    } else if (p.reduceAudio) {
      args.addAll(['-c:a', 'aac', '-b:a', '${p.audioKbps}k']);
    } else {
      args.addAll(['-c:a', 'copy']);
    }

    if (p.stripMetadata) args.addAll(['-map_metadata', '-1']);
    if (!p.webm) args.addAll(['-movflags', '+faststart']);

    return args;
  }
}
