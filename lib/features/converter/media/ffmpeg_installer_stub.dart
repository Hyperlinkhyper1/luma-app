/// Raised when the in-app ffmpeg install fails or isn't supported.
class FfmpegInstallException implements Exception {
  const FfmpegInstallException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Web/stub: automatic install is unavailable.
class FfmpegInstaller {
  const FfmpegInstaller._();

  static bool get supported => false;

  /// A human-readable hint for where the binary comes from.
  static String get sourceLabel => 'ffmpeg';

  static Future<void> install({
    required void Function(double? progress) onProgress,
  }) {
    throw const FfmpegInstallException(
      'Installing ffmpeg is only available in the desktop app.',
    );
  }
}
