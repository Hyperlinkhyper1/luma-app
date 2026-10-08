import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;

import '../../../../../l10n/current_l.dart';
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
    final assetUrl = await _resolveDownloadUrl(majorVersion);

    onProgress?.call(currentL.mcJavaDownloading('$majorVersion'), 0);
    final client = http.Client();
    final bytes = <int>[];
    try {
      final req = http.Request('GET', Uri.parse(assetUrl));
      final res = await client.send(req);
      if (res.statusCode != 200) {
        throw JavaRuntimeException(currentL.mcJavaDownloadFailed('${res.statusCode}'));
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      await for (final chunk in res.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call(currentL.mcJavaDownloading('$majorVersion'), received / total);
        }
      }
    } catch (e) {
      if (e is JavaRuntimeException) rethrow;
      throw JavaRuntimeException(currentL.mcJavaCouldNotDownload('$majorVersion'));
    } finally {
      client.close();
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

  Future<String> _resolveDownloadUrl(int majorVersion) async {
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
    final binary = (list.first as Map<String, dynamic>)['binary'] as Map<String, dynamic>;
    final package = binary['package'] as Map<String, dynamic>;
    return package['link'] as String;
  }
}
