import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
      throw const FfmpegInstallException(
        'Automatic install is only available on Windows. Please add '
        'ffmpeg to your PATH manually.',
      );
    }

    final client = http.Client();
    try {
      final response =
          await client.send(http.Request('GET', Uri.parse(_windowsUrl)));
      if (response.statusCode != 200) {
        throw FfmpegInstallException(
          'Download failed (HTTP ${response.statusCode}). Check your '
          'connection and try again.',
        );
      }

      final total = response.contentLength;
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response.stream) {
        builder.add(chunk);
        received += chunk.length;
        onProgress((total == null || total == 0) ? null : received / total);
      }

      // Extraction phase — size unknown to the progress bar.
      onProgress(null);
      final archive = ZipDecoder().decodeBytes(builder.takeBytes());
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
        throw const FfmpegInstallException(
          'The downloaded archive did not contain ffmpeg.exe.',
        );
      }

      final path = await binaryPath();
      await File(path).writeAsBytes(exe.content as List<int>, flush: true);

      // Point the resolver straight at the freshly installed binary.
      Ffmpeg.useBinary(path);
    } on FfmpegInstallException {
      rethrow;
    } catch (e) {
      throw FfmpegInstallException('Install failed: $e');
    } finally {
      client.close();
    }
  }
}
