import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../../../../l10n/current_l.dart';
import '../../../../../security/guarded_download.dart';
import 'mc_paths.dart';

class JavaRuntimeException implements Exception {
  JavaRuntimeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Resolves, downloads and extracts the Eclipse Temurin (Adoptium) JRE build
/// matching a version's required Java major version, caching each major
/// version's extracted JRE once under `minecraft/runtimes/<majorVersion>/`.
class JavaRuntimeManager {
  JavaRuntimeManager._();
  static final JavaRuntimeManager instance = JavaRuntimeManager._();

  Future<Directory> _runtimeDir(int majorVersion) async {
    final runtimes = await McPaths.runtimes();
    final dir = Directory('${runtimes.path}${Platform.pathSeparator}$majorVersion');
    return dir;
  }

  Future<String?> _findJavawIn(Directory dir) async {
    if (!await dir.exists()) return null;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File &&
          entity.path.toLowerCase().endsWith('${Platform.pathSeparator}javaw.exe')) {
        return entity.path;
      }
    }
    return null;
  }

  /// Returns the path to `javaw.exe` for [majorVersion], downloading and
  /// extracting it first if it isn't cached yet.
  Future<String> ensureRuntime(
    int majorVersion, {
    void Function(String status, double? fraction)? onProgress,
  }) async {
    final dir = await _runtimeDir(majorVersion);
    final existing = await _findJavawIn(dir);
    if (existing != null) return existing;

    onProgress?.call(currentL.mcJavaLookingUp('$majorVersion'), null);
    final asset = await _resolveDownload(majorVersion);

    onProgress?.call(currentL.mcJavaDownloading('$majorVersion'), 0);
    final Uint8List bytes;
    try {
      bytes = await guardedDownload(
        asset.link,
        maxBytes: _maxRuntimeBytes,
        onProgress: (received, total) {
          if (total != null && total > 0) {
            onProgress?.call(currentL.mcJavaDownloading('$majorVersion'), received / total);
          }
        },
      );
    } on GuardedDownloadException catch (e) {
      final status = e.statusCode;
      throw JavaRuntimeException(
        status != null
            ? currentL.mcJavaDownloadFailed('$status')
            : currentL.mcJavaCouldNotDownload('$majorVersion'),
      );
    } catch (_) {
      throw JavaRuntimeException(currentL.mcJavaCouldNotDownload('$majorVersion'));
    }
    if (sha256.convert(bytes).toString() != asset.sha256) {
      throw JavaRuntimeException(currentL.mcJavaCouldNotDownload('$majorVersion'));
    }

    onProgress?.call(currentL.mcJavaExtracting('$majorVersion'), null);
    await dir.create(recursive: true);
    final archive = ZipDecoder().decodeBytes(bytes);
    extractArchiveToDisk(archive, dir.path);

    final javaw = await _findJavawIn(dir);
    if (javaw == null) {
      throw JavaRuntimeException(currentL.mcJavaMissingJavaw('$majorVersion'));
    }
    onProgress?.call(currentL.mcJavaReady, 1);
    return javaw;
  }

  static const _maxRuntimeBytes = 512 * 1024 * 1024;

  /// Where the runtime is and the SHA-256 Adoptium's API publishes for it.
  /// The archive itself comes from a different host, and it is unpacked and
  /// run, so the two have to agree before anything is extracted.
  Future<({Uri link, String sha256})> _resolveDownload(int majorVersion) async {
    final url = 'https://api.adoptium.net/v3/assets/latest/$majorVersion/hotspot'
        '?os=windows&architecture=x64&image_type=jre';
    final http.Response res;
    try {
      res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw JavaRuntimeException(currentL.mcJavaProviderUnreachable);
    }
    if (res.statusCode != 200) {
      throw JavaRuntimeException(
        currentL.mcJavaNoBuildFound('$majorVersion', '${res.statusCode}'),
      );
    }
    final list = jsonDecode(res.body) as List;
    if (list.isEmpty) {
      throw JavaRuntimeException(currentL.mcJavaNoBuildForWindows('$majorVersion'));
    }
    final first = list.first;
    final binary = first is Map ? first['binary'] : null;
    final package = binary is Map ? binary['package'] : null;
    final link = package is Map ? package['link'] : null;
    final checksum = package is Map ? package['checksum'] : null;
    final uri = link is String ? Uri.tryParse(link) : null;
    if (uri == null ||
        checksum is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(checksum.toLowerCase())) {
      throw JavaRuntimeException(currentL.mcJavaNoBuildForWindows('$majorVersion'));
    }
    return (link: uri, sha256: checksum.toLowerCase());
  }
}
