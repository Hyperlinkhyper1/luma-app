import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'forge_style_profile_merger.dart';
import 'mc_paths.dart';
import 'piston_meta_client.dart';

class NeoForgeInstallerException implements Exception {
  NeoForgeInstallerException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// NeoForge is a Forge fork that kept the same installer-jar approach (see
/// `forge_installer.dart` for why this shells out rather than reimplementing
/// the processor pipeline), just hosted on its own Maven and versioned
/// independently of Forge's `<mcVersion>-<forgeVersion>` scheme — NeoForge
/// versions look like `21.1.63` and only indirectly imply a Minecraft
/// version (the first two components), so version listing is filtered by
/// prefix rather than looked up by exact key.
class NeoForgeInstaller {
  const NeoForgeInstaller._();

  static const _mavenBase = 'https://maven.neoforged.net/releases/net/neoforged/neoforge';

  /// All published NeoForge versions whose `<major>.<minor>` prefix matches
  /// [mcVersion]'s `<minor>.<patch>` (NeoForge drops the leading "1."), e.g.
  /// Minecraft 1.21.1 → NeoForge versions starting with "21.1.".
  static Future<List<String>> fetchVersions(String mcVersion) async {
    final res = await http
        .get(Uri.parse('https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw NeoForgeInstallerException('Could not reach the NeoForge version list.');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final all = (json['versions'] as List).cast<String>();
    final prefix = _neoForgePrefix(mcVersion);
    final matching = all.where((v) => v.startsWith(prefix)).toList()..sort();
    return matching.reversed.toList();
  }

  static String _neoForgePrefix(String mcVersion) {
    final parts = mcVersion.split('.');
    if (parts.length < 2) return mcVersion;
    return parts.length >= 3 ? '${parts[1]}.${parts[2]}.' : '${parts[1]}.0.';
  }

  static Future<VersionDetail> installAndMerge({
    required String neoForgeVersion,
    required VersionDetail vanilla,
    required String javawPath,
    void Function(String status, double? fraction)? onStatus,
  }) async {
    final root = await McPaths.root();
    final before = await _listVersionDirs(root);

    onStatus?.call('Downloading NeoForge installer…', null);
    final installerJar = await _downloadInstaller(neoForgeVersion);

    onStatus?.call('Running NeoForge installer…', null);
    final javaExe = javawPath.toLowerCase().endsWith('javaw.exe')
        ? '${javawPath.substring(0, javawPath.length - 10)}java.exe'
        : javawPath;
    final result = await Process.run(
      javaExe,
      ['-jar', installerJar.path, '--installClient', root.path],
      workingDirectory: root.path,
    );
    if (result.exitCode != 0) {
      throw NeoForgeInstallerException(
        'The NeoForge installer failed:\n${result.stdout}\n${result.stderr}'.trim(),
      );
    }

    final after = await _listVersionDirs(root);
    final newDirs = after.difference(before);
    final versionId = newDirs.isNotEmpty
        ? newDirs.first
        : after.where((d) => d.toLowerCase().contains('neoforge')).lastOrNull;
    if (versionId == null) {
      throw NeoForgeInstallerException(
          'The NeoForge installer ran but no new version profile was found.');
    }

    final profileFile =
        File('${root.path}${Platform.pathSeparator}versions${Platform.pathSeparator}$versionId${Platform.pathSeparator}$versionId.json');
    if (!await profileFile.exists()) {
      throw NeoForgeInstallerException('NeoForge installer did not produce $versionId.json.');
    }
    final profile = jsonDecode(await profileFile.readAsString()) as Map<String, dynamic>;
    return mergeForgeStyleProfile(vanilla, profile);
  }

  static Future<File> _downloadInstaller(String neoForgeVersion) async {
    final url = '$_mavenBase/$neoForgeVersion/neoforge-$neoForgeVersion-installer.jar';
    final dir = await McPaths.versionDir('neoforge-$neoForgeVersion');
    final file = File('${dir.path}${Platform.pathSeparator}installer.jar');
    if (await file.exists()) return file;

    final res = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 3));
    if (res.statusCode != 200) {
      throw NeoForgeInstallerException('Could not download the NeoForge $neoForgeVersion installer.');
    }
    await file.writeAsBytes(res.bodyBytes);
    return file;
  }

  static Future<Set<String>> _listVersionDirs(Directory root) async {
    final versionsDir = Directory('${root.path}${Platform.pathSeparator}versions');
    if (!await versionsDir.exists()) return {};
    return {
      await for (final entity in versionsDir.list())
        if (entity is Directory) entity.path.split(Platform.pathSeparator).last,
    };
  }
}

extension _LastOrNull<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
