import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../../../l10n/current_l.dart';
import '../../../security/guarded_download.dart';
import 'ffmpeg_service.dart';

/// Raised when the in-app ffmpeg install fails or isn't supported.
class FfmpegInstallException implements Exception {
  const FfmpegInstallException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Downloads a prebuilt ffmpeg binary and unpacks it into the app's writable
/// support directory, then points [Ffmpeg] at it.
///
/// Windows only for now — it fetches the BtbN "win64-gpl" build, which bundles
/// the codecs luma's converters rely on (x264/x265, libvpx, libmp3lame,
/// libvorbis, libtheora, libopus, libwebp).
class FfmpegInstaller {
  const FfmpegInstaller._();

  static const _windowsUrl =
      'https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-win64-gpl.zip';

  static const _maxArchiveBytes = 1024 * 1024 * 1024;

  /// Only Windows ships a binary we know how to fetch and unpack here.
  static bool get supported => Platform.isWindows;

  static String get sourceLabel => 'BtbN FFmpeg build (~120 MB)';

  /// The path the downloaded `ffmpeg.exe` is written to (and that
  /// [Ffmpeg.resolve] looks for on startup).
  static Future<String> binaryPath() async {
    final support = await getApplicationSupportDirectory();
    final sep = Platform.pathSeparator;
    final dir = Directory('${support.path}${sep}ffmpeg');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return '${dir.path}${sep}ffmpeg.exe';
  }

  /// Downloads and installs ffmpeg.
  ///
  /// [onProgress] reports the download fraction (0..1), or null while the size
  /// is unknown or during extraction.
  static Future<void> install({
    required void Function(double? progress) onProgress,
  }) async {
    if (!supported) {
      throw FfmpegInstallException(currentL.ffmpegInstallDesktopOnly);
    }

    try {
      final zipBytes = await guardedDownload(
        Uri.parse(_windowsUrl),
        maxBytes: _maxArchiveBytes,
        onProgress: (received, total) =>
            onProgress((total == null || total == 0) ? null : received / total),
      );

      // Extraction phase — size unknown to the progress bar.
      onProgress(null);
      final archive = ZipDecoder().decodeBytes(zipBytes);
      ArchiveFile? exe;
      for (final f in archive.files) {
        if (f.isFile &&
            f.name.replaceAll('\\', '/').toLowerCase().endsWith(
                  'bin/ffmpeg.exe',
                )) {
          exe = f;
          break;
        }
      }
      if (exe == null) {
        throw FfmpegInstallException(currentL.ffmpegArchiveMissingExe);
      }

      final path = await binaryPath();
      final part = File('$path.part');
      await part.writeAsBytes(exe.content as List<int>, flush: true);
      await part.rename(path);

      // Point the resolver straight at the freshly installed binary.
      Ffmpeg.useBinary(path);
    } on FfmpegInstallException {
      rethrow;
    } on GuardedDownloadException catch (e) {
      final status = e.statusCode;
      throw FfmpegInstallException(
        status != null
            ? currentL.ffmpegDownloadFailed(status)
            : currentL.ffmpegInstallFailed('$e'),
      );
    } catch (e) {
      throw FfmpegInstallException(currentL.ffmpegInstallFailed('$e'));
    }
  }
}
