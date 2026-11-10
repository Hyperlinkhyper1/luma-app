import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../../../l10n/current_l.dart';
import '../../../../../security/guarded_download.dart';
import 'forge_style_profile_merger.dart';
import 'mc_paths.dart';
import 'piston_meta_client.dart';

class ForgeInstallerException implements Exception {
  ForgeInstallerException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Unlike Fabric/Quilt, Forge has no manifest API that hands back a ready
/// launch profile: you download its installer jar and run it, and it does
/// its own thing (in modern versions: writes a version JSON + libraries,
/// possibly with a small number of "processor" steps like re-obfuscating or
/// binary-patching the client jar for older versions). This shells out to
/// the installer's official headless client-install mode rather than
/// reimplementing its processor pipeline — simpler and far less fragile than
/// hand-rolling install_profile.json processor execution, at the cost of
/// requiring a working `java` on the resolved runtime.
class ForgeInstaller {
  const ForgeInstaller._();

  static const _mavenBase = 'https://maven.minecraftforge.net/net/minecraftforge/forge';

  /// Recommended/latest Forge build per Minecraft version, from Forge's own
  /// promotions feed (`<mcVersion>-recommended` / `<mcVersion>-latest` keys).
  static Future<Map<String, String>> fetchPromotions() async {
    final res = await http
        .get(Uri.parse('https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw ForgeInstallerException(currentL.mcForgeVersionListUnreachable);
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['promos'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
  }

  /// Downloads the installer for [mcVersion]/[forgeVersion] and runs it in
  /// client-install mode against luma's own `minecraft/` root (which mirrors
  /// the vanilla launcher's directory layout closely enough for Forge's
  /// installer to find the vanilla client jar and write its own
  /// `versions/<id>/<id>.json` + libraries into the same tree), then merges
  /// that profile onto [vanilla].
  static Future<VersionDetail> installAndMerge({
    required String mcVersion,
    required String forgeVersion,
    required VersionDetail vanilla,
    required String javawPath,
    void Function(String status, double? fraction)? onStatus,
  }) async {
    final root = await McPaths.root();
    final before = await _listVersionDirs(root);

    onStatus?.call(currentL.mcForgeDownloadingInstaller, null);
    final installerJar = await _downloadInstaller(mcVersion, forgeVersion);

    onStatus?.call(currentL.mcForgeRunningInstaller, null);
    final javaExe = javawPath.toLowerCase().endsWith('javaw.exe')
        ? '${javawPath.substring(0, javawPath.length - 10)}java.exe'
        : javawPath;
    final result = await Process.run(
      javaExe,
      ['-jar', installerJar.path, '--installClient', root.path],
      workingDirectory: root.path,
    );
    if (result.exitCode != 0) {
      throw ForgeInstallerException(
        currentL.mcForgeInstallerFailed('${result.stdout}\n${result.stderr}'.trim()),
      );
    }

    final after = await _listVersionDirs(root);
    final newDirs = after.difference(before);
    final versionId = newDirs.isNotEmpty
        ? newDirs.first
        : after.where((d) => d.toLowerCase().contains('forge')).lastOrNull;
    if (versionId == null) {
      throw ForgeInstallerException(currentL.mcForgeInstallerNoNewProfile);
    }

    final profileFile =
        File('${root.path}${Platform.pathSeparator}versions${Platform.pathSeparator}$versionId${Platform.pathSeparator}$versionId.json');
    if (!await profileFile.exists()) {
      throw ForgeInstallerException(currentL.mcForgeInstallerNoProfile(versionId));
    }
    final profile = jsonDecode(await profileFile.readAsString()) as Map<String, dynamic>;
    return mergeForgeStyleProfile(vanilla, profile);
  }

  static Future<File> _downloadInstaller(String mcVersion, String forgeVersion) async {
    final coord = '$mcVersion-$forgeVersion';
    if (!_coordinate.hasMatch(coord)) {
      throw ForgeInstallerException(currentL.mcForgeInstallerDownloadFailed(forgeVersion));
    }
    final url = '$_mavenBase/$coord/forge-$coord-installer.jar';
    final dir = await McPaths.versionDir('forge-$coord');
    final file = File('${dir.path}${Platform.pathSeparator}installer.jar');
    if (await file.exists()) return file;

    final Uint8List bytes;
    try {
      bytes = await guardedDownload(Uri.parse(url), maxBytes: _maxInstallerBytes)
          .timeout(const Duration(minutes: 3));
    } catch (_) {
      throw ForgeInstallerException(currentL.mcForgeInstallerDownloadFailed(forgeVersion));
    }
    final part = File('${file.path}.part');
    await part.writeAsBytes(bytes, flush: true);
    await part.rename(file.path);
    return file;
  }

  /// The version pair ends up in a URL and a folder name, and it comes from
  /// a feed on the network, so it may only look like a version.
  static final _coordinate = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]*$');

  static const _maxInstallerBytes = 128 * 1024 * 1024;

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
