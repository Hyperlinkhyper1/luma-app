import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';

import 'mc_nbt_reader.dart';
import 'mc_paths.dart';
import 'safe_path.dart';

class McWorldInfo {
  McWorldInfo({
    required this.folderName,
    required this.name,
    this.seed,
    this.gameType,
    this.lastPlayed,
    this.versionName,
    required this.sizeBytes,
  });

  final String folderName;
  final String name;
  final int? seed;
  final int? gameType; // 0 survival, 1 creative, 2 adventure, 3 spectator
  final DateTime? lastPlayed;
  final String? versionName;
  final int sizeBytes;

  String get gameModeLabel => switch (gameType) {
        0 => 'Survival',
        1 => 'Creative',
        2 => 'Adventure',
        3 => 'Spectator',
        _ => 'Unknown',
      };
}

class WorldReaderException implements Exception {
  WorldReaderException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lists an instance's `saves/` folders, reading `level.dat` (gzip-compressed
/// NBT, see [NbtReader]) to surface world name/seed/gamemode/last-played
/// without needing the game itself. A world whose `level.dat` can't be
/// parsed is skipped rather than aborting the whole list — better to show
/// N-1 worlds than none.
class WorldReader {
  const WorldReader._();

  static Future<List<McWorldInfo>> listWorlds(String instanceId) async {
    final savesDir = await McPaths.instanceSubDir(instanceId, 'saves');
    if (!await savesDir.exists()) return [];

    final result = <McWorldInfo>[];
    await for (final entity in savesDir.list()) {
      if (entity is! Directory) continue;
      final levelDat = File('${entity.path}${Platform.pathSeparator}level.dat');
      if (!await levelDat.exists()) continue;
      try {
        result.add(await _parseWorld(entity, levelDat));
      } catch (_) {
        // Skip unreadable/corrupt worlds rather than failing the whole list.
      }
    }
    return result;
  }

  static Future<McWorldInfo> _parseWorld(Directory worldDir, File levelDat) async {
    final gzipped = await levelDat.readAsBytes();
    final raw = GZipDecoder().decodeBytes(gzipped);
    final root = NbtReader(Uint8List.fromList(raw)).parseRoot();
    final data = (root['Data'] as Map<String, dynamic>?) ?? root;

    final folderName = worldDir.path.split(Platform.pathSeparator).last;
    final name = data['LevelName'] as String? ?? folderName;

    int? seed;
    final worldGenSettings = data['WorldGenSettings'] as Map<String, dynamic>?;
    if (worldGenSettings != null && worldGenSettings['seed'] is int) {
      seed = worldGenSettings['seed'] as int;
    } else if (data['RandomSeed'] is int) {
      seed = data['RandomSeed'] as int;
    }

    final gameType = data['GameType'] as int?;
    final lastPlayedMillis = data['LastPlayed'] as int?;
    final versionMap = data['Version'] as Map<String, dynamic>?;
    final versionName = versionMap?['Name'] as String?;

    var sizeBytes = 0;
    await for (final entity in worldDir.list(recursive: true)) {
      if (entity is File) sizeBytes += await entity.length();
    }

    return McWorldInfo(
      folderName: folderName,
      name: name,
      seed: seed,
      gameType: gameType,
      lastPlayed: lastPlayedMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastPlayedMillis),
      versionName: versionName,
      sizeBytes: sizeBytes,
    );
  }

  static Future<void> deleteWorld(String instanceId, String folderName) async {
    final savesDir = await McPaths.instanceSubDir(instanceId, 'saves');
    final dir = Directory('${savesDir.path}${Platform.pathSeparator}$folderName');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  static Future<void> duplicateWorld(String instanceId, String folderName) async {
    final savesDir = await McPaths.instanceSubDir(instanceId, 'saves');
    final source = Directory('${savesDir.path}${Platform.pathSeparator}$folderName');
    if (!await source.exists()) {
      throw WorldReaderException('World "$folderName" no longer exists.');
    }
    var copyName = '$folderName (copy)';
    var target = Directory('${savesDir.path}${Platform.pathSeparator}$copyName');
    var suffix = 2;
    while (await target.exists()) {
      copyName = '$folderName (copy $suffix)';
      target = Directory('${savesDir.path}${Platform.pathSeparator}$copyName');
      suffix++;
    }
    await _copyDirectory(source, target);
  }

  /// Zips the world folder into `saves/<name>-backup-<timestamp>.zip`, next
  /// to the other saves so it's easy to find in the instance's file browser.
  static Future<File> backupWorld(String instanceId, String folderName) async {
    final savesDir = await McPaths.instanceSubDir(instanceId, 'saves');
    final source = Directory('${savesDir.path}${Platform.pathSeparator}$folderName');
    if (!await source.exists()) {
      throw WorldReaderException('World "$folderName" no longer exists.');
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipFile = File('${savesDir.path}${Platform.pathSeparator}$folderName-backup-$timestamp.zip');
    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);
    await encoder.addDirectory(source, includeDirName: true);
    encoder.close();
    return zipFile;
  }

  /// Imports a `.zip` world backup (or any zip whose top-level entries are a
  /// single world folder) into `saves/`.
  static Future<void> importWorldZip(String instanceId, File zipFile) async {
    final savesDir = await McPaths.instanceSubDir(instanceId, 'saves');
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final topLevelDirs = <String>{};
    for (final entry in archive) {
      final firstSegment = entry.name.split('/').first;
      if (firstSegment.isNotEmpty) topLevelDirs.add(firstSegment);
    }
    final worldName = topLevelDirs.length == 1 ? topLevelDirs.first : zipFile.uri.pathSegments.last.replaceAll('.zip', '');

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final relativePath = topLevelDirs.length == 1 ? entry.name : '$worldName/${entry.name}';
      final resolved = safeJoin(savesDir.path, relativePath);
      if (resolved == null) continue; // refuse to write outside saves/
      final outFile = File(resolved);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(entry.content as List<int>);
    }
  }

  static Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      final destPath = '${target.path}${Platform.pathSeparator}$name';
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(destPath));
      } else if (entity is File) {
        await entity.copy(destPath);
      }
    }
  }
}
