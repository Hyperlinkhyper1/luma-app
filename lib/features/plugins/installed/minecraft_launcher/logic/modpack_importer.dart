import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import '../minecraft_launcher_repository.dart';
import 'download_manager.dart';
import 'mc_paths.dart';
import 'safe_path.dart';

class ModpackImportException implements Exception {
  ModpackImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Imports a `.mrpack` file: creates a new instance from its declared
/// Minecraft version + loader, downloads every file `modrinth.index.json`
/// lists (via [DownloadManager], same as any other batch of game files),
/// then extracts the `overrides/`/`client-overrides/` folders on top.
class ModpackImporter {
  const ModpackImporter._();

  static Future<String> importMrpack({
    required MinecraftLauncherRepository repository,
    required File mrpackFile,
    void Function(String status, double? fraction)? onStatus,
  }) async {
    onStatus?.call('Reading modpack…', null);
    final archive = ZipDecoder().decodeBytes(await mrpackFile.readAsBytes());
    final indexEntry = archive.files.where((f) => f.name == 'modrinth.index.json').firstOrNull;
    if (indexEntry == null) {
      throw ModpackImportException('Not a valid .mrpack file (missing modrinth.index.json).');
    }
    final index = jsonDecode(utf8.decode(indexEntry.content as List<int>)) as Map<String, dynamic>;

    final dependencies = (index['dependencies'] as Map<String, dynamic>?) ?? const {};
    final mcVersion = dependencies['minecraft'] as String?;
    if (mcVersion == null) {
      throw ModpackImportException('This modpack does not declare a Minecraft version.');
    }

    var loader = 'vanilla';
    String? loaderVersion;
    for (final entry in dependencies.entries) {
      switch (entry.key) {
        case 'fabric-loader':
          loader = 'fabric';
          loaderVersion = entry.value as String;
        case 'forge':
          loader = 'forge';
          loaderVersion = entry.value as String;
        case 'neoforge':
          loader = 'neoforge';
          loaderVersion = entry.value as String;
        case 'quilt-loader':
          loader = 'quilt';
          loaderVersion = entry.value as String;
      }
    }

    final name = index['name'] as String? ?? 'Imported modpack';
    final instanceId = await repository.createInstance(
      name: name,
      versionId: mcVersion,
      loader: loader,
      loaderVersion: loaderVersion,
    );
    final instanceDir = await McPaths.instanceDir(instanceId);

    final files = (index['files'] as List?) ?? const [];
    final downloadItems = <DownloadItem>[];
    final toRecord = <(String relPath, String? sha1)>[];

    for (final entry in files) {
      final map = entry as Map<String, dynamic>;
      final relPath = map['path'] as String;
      final downloads = (map['downloads'] as List).cast<String>();
      if (downloads.isEmpty) continue;
      final destPath = safeJoin(instanceDir.path, relPath);
      if (destPath == null) continue; // refuse to write outside the instance folder
      final sha1 = (map['hashes'] as Map<String, dynamic>?)?['sha1'] as String?;
      final size = (map['fileSize'] as num?)?.toInt();
      downloadItems.add(DownloadItem(
        url: downloads.first,
        destPath: destPath,
        sha1: sha1,
        size: size,
        label: relPath.split('/').last,
      ));
      toRecord.add((relPath, sha1));
    }

    if (downloadItems.isNotEmpty) {
      onStatus?.call('Downloading modpack files…', 0);
      await DownloadManager.instance.downloadAll(
        downloadItems,
        onProgress: (p) => onStatus?.call(
          'Downloading modpack files (${p.filesDone}/${p.filesTotal})…',
          p.fraction,
        ),
      );
    }

    onStatus?.call('Extracting overrides…', null);
    const overridePrefixes = ['overrides/', 'client-overrides/'];
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      String? relative;
      for (final prefix in overridePrefixes) {
        if (entry.name.startsWith(prefix)) {
          relative = entry.name.substring(prefix.length);
          break;
        }
      }
      if (relative == null || relative.isEmpty) continue;
      final resolved = safeJoin(instanceDir.path, relative);
      if (resolved == null) continue; // refuse to write outside the instance folder
      final outFile = File(resolved);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(entry.content as List<int>);
    }

    onStatus?.call('Recording installed content…', null);
    for (final (relPath, sha1) in toRecord) {
      final segments = relPath.split('/');
      final kind = _kindForFolder(segments.first);
      if (kind == null) continue; // not under a recognized content folder
      await repository.recordInstalledContent(
        instanceId: instanceId,
        fileName: segments.last,
        sha1: sha1,
        kind: kind,
      );
    }

    onStatus?.call('Done', 1);
    return instanceId;
  }

  static String? _kindForFolder(String folder) => switch (folder) {
        'mods' => 'mod',
        'resourcepacks' => 'resourcepack',
        'shaderpacks' => 'shader',
        'datapacks' => 'datapack',
        _ => null,
      };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
