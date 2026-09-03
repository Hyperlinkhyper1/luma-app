import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import '../data/minecraft_launcher_database.dart';
import '../minecraft_launcher_repository.dart';
import 'mc_paths.dart';
import 'mod_installer.dart';
import 'modrinth_api_client.dart';

class ModpackExportException implements Exception {
  ModpackExportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Exports an instance to a `.mrpack` (Modrinth modpack format): a zip with
/// `modrinth.index.json` listing every Modrinth-sourced file as a remote
/// download (so the pack itself stays small), plus an `overrides/` folder
/// bundling anything that can't be re-downloaded — the instance's `config/`
/// and any manually-added (non-Modrinth) content.
class ModpackExporter {
  const ModpackExporter._();

  static Future<void> exportInstance({
    required MinecraftLauncherRepository repository,
    required McInstance instance,
    required String destPath,
  }) async {
    final content = await repository.watchInstalledContent(instance.id).first;
    final instanceDir = await McPaths.instanceDir(instance.id);

    final files = <Map<String, dynamic>>[];
    final overrideFileEntries = <McInstalledMod>[];

    for (final item in content) {
      if (item.projectId != null && item.versionId != null) {
        try {
          final version = await ModrinthApiClient.instance.getVersion(item.versionId!);
          final file = version.files.firstWhere(
            (f) => f.filename == item.fileName,
            orElse: () => version.primaryFile,
          );
          files.add({
            'path': '${contentFolderFor(item.kind)}/${item.fileName}',
            'hashes': {'sha1': file.sha1},
            'env': {'client': 'required', 'server': 'unsupported'},
            'downloads': [file.url],
            'fileSize': file.size,
          });
          continue;
        } catch (_) {
          // Refetch failed (removed from Modrinth, offline, etc) — fall back
          // to bundling the local file raw, same as a manually-added one.
        }
      }
      overrideFileEntries.add(item);
    }

    final loaderKey = _loaderDependencyKey(instance.loader);
    final index = {
      'formatVersion': 1,
      'game': 'minecraft',
      'versionId': '1.0.0',
      'name': instance.name,
      'files': files,
      'dependencies': {
        'minecraft': instance.versionId,
        if (loaderKey != null && instance.loaderVersion != null)
          loaderKey: instance.loaderVersion,
      },
    };

    final encoder = ZipFileEncoder();
    encoder.create(destPath);
    final indexBytes = utf8.encode(jsonEncode(index));
    encoder.addArchiveFile(ArchiveFile('modrinth.index.json', indexBytes.length, indexBytes));

    for (final item in overrideFileEntries) {
      final dir = await McPaths.instanceSubDir(instance.id, contentFolderFor(item.kind));
      final file = File('${dir.path}${Platform.pathSeparator}${item.fileName}');
      if (await file.exists()) {
        await encoder.addFile(file, 'overrides/${contentFolderFor(item.kind)}/${item.fileName}');
      }
    }

    final configDir = Directory('${instanceDir.path}${Platform.pathSeparator}config');
    if (await configDir.exists()) {
      await for (final entity in configDir.list(recursive: true)) {
        if (entity is! File) continue;
        final rel = entity.path
            .substring(instanceDir.path.length + 1)
            .replaceAll(Platform.pathSeparator, '/');
        await encoder.addFile(entity, 'overrides/$rel');
      }
    }

    await encoder.close();
  }

  static String? _loaderDependencyKey(String loader) => switch (loader) {
        'fabric' => 'fabric-loader',
        'forge' => 'forge',
        'neoforge' => 'neoforge',
        'quilt' => 'quilt-loader',
        _ => null,
      };
}
