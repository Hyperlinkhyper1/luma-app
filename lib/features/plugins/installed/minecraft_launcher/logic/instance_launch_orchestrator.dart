import 'dart:io';

import '../data/minecraft_launcher_database.dart';
import 'asset_resolver.dart';
import 'download_manager.dart';
import 'fabric_installer.dart';
import 'forge_installer.dart';
import 'game_process_manager.dart';
import 'java_runtime_manager.dart';
import 'launch_command_builder.dart';
import 'library_resolver.dart';
import 'mc_paths.dart';
import 'native_library_extractor.dart';
import 'neoforge_installer.dart';
import 'piston_meta_client.dart';
import 'quilt_installer.dart';
import 'safe_path.dart';

class LaunchOrchestratorException implements Exception {
  LaunchOrchestratorException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Ties together every launch-time piece into the single flow a "Play"
/// button needs: resolve the vanilla version, download whatever's missing
/// (client jar, base libraries, assets, Java runtime), run the instance's
/// mod loader installer if it has one, download any loader-added libraries,
/// extract natives, build the launch command, and start the process.
/// [onStatus] is called throughout with a short status line and an optional
/// 0..1 fraction (null = indeterminate).
class InstanceLaunchOrchestrator {
  const InstanceLaunchOrchestrator._();

  static Future<GameProcessHandle> prepareAndLaunch({
    required McInstance instance,
    required McAccount account,
    required void Function(String status, double? fraction) onStatus,
  }) async {
    onStatus('Checking for updates…', null);
    final manifest = await PistonMetaClient.instance.fetchManifest();
    final entry = manifest.versions.where((v) => v.id == instance.versionId).firstOrNull;
    if (entry == null) {
      throw LaunchOrchestratorException(
          'Minecraft ${instance.versionId} is no longer listed by Mojang.');
    }
    final vanillaDetail = await PistonMetaClient.instance.fetchVersionDetail(entry);

    final librariesDir = await McPaths.libraries();
    final assetsObjects = await McPaths.assetsObjects();
    final clientJarPath = await clientJarPathFor(vanillaDetail.id);

    onStatus('Resolving base game files…', null);
    final vanillaLibraries = resolveLibraries(vanillaDetail);
    final assets = await AssetResolver.instance.resolveAssets(vanillaDetail);

    final baseDownloadItems = <DownloadItem>[
      DownloadItem(
        url: vanillaDetail.clientDownload.url,
        destPath: clientJarPath,
        sha1: vanillaDetail.clientDownload.sha1,
        size: vanillaDetail.clientDownload.size,
        label: '${vanillaDetail.id}.jar',
      ),
      for (final lib in vanillaLibraries) _libraryDownloadItem(librariesDir, lib),
      for (final asset in assets)
        DownloadItem(
          url: asset.downloadUrl,
          destPath:
              '${assetsObjects.path}${Platform.pathSeparator}${asset.relativePath.replaceAll('/', Platform.pathSeparator)}',
          sha1: asset.hash,
          size: asset.size,
          label: 'asset',
        ),
    ];

    onStatus('Downloading game files…', 0);
    await DownloadManager.instance.downloadAll(
      baseDownloadItems,
      onProgress: (p) => onStatus(
        'Downloading game files (${p.filesDone}/${p.filesTotal})…',
        p.fraction,
      ),
    );

    final javaPath = instance.javaPath ??
        await JavaRuntimeManager.instance.ensureRuntime(
          vanillaDetail.javaMajorVersion,
          onProgress: onStatus,
        );

    var detail = vanillaDetail;
    if (instance.loader != 'vanilla') {
      final loaderVersion = instance.loaderVersion;
      if (loaderVersion == null || loaderVersion.isEmpty) {
        throw LaunchOrchestratorException(
            'This instance has no ${instance.loader} version selected.');
      }
      onStatus('Setting up ${_loaderDisplayName(instance.loader)}…', null);
      detail = await _mergeLoader(
        loader: instance.loader,
        mcVersion: instance.versionId,
        loaderVersion: loaderVersion,
        vanilla: vanillaDetail,
        javawPath: javaPath,
        onStatus: onStatus,
      );

      final mergedLibraries = resolveLibraries(detail);
      final vanillaPaths = vanillaLibraries.map((l) => l.mavenPath).toSet();
      final extraItems = [
        for (final lib in mergedLibraries)
          if (!vanillaPaths.contains(lib.mavenPath)) _libraryDownloadItem(librariesDir, lib),
      ];
      if (extraItems.isNotEmpty) {
        onStatus('Downloading ${_loaderDisplayName(instance.loader)} libraries…', 0);
        await DownloadManager.instance.downloadAll(
          extraItems,
          onProgress: (p) => onStatus(
            'Downloading ${_loaderDisplayName(instance.loader)} libraries '
            '(${p.filesDone}/${p.filesTotal})…',
            p.fraction,
          ),
        );
      }
    }

    onStatus('Extracting natives…', null);
    final libraries = resolveLibraries(detail);
    final nativesDir = await NativeLibraryExtractor.extractAll(instance.id, libraries);

    final instanceDir = await McPaths.instanceDir(instance.id);
    final assetsRoot = await McPaths.assetsRoot();
    // Ensure the per-instance content folders exist even before anything's
    // installed into them, so the instance detail page has somewhere to point.
    for (final sub in const ['mods', 'resourcepacks', 'shaderpacks', 'saves', 'screenshots', 'config']) {
      await McPaths.instanceSubDir(instance.id, sub);
    }

    final ctx = LaunchContext(
      javaPath: javaPath,
      instanceDir: instanceDir,
      nativesDir: nativesDir,
      assetsRoot: assetsRoot,
      librariesDir: librariesDir,
      clientJarPath: clientJarPath,
      libraries: libraries,
      accountUsername: account.username,
      accountUuid: account.uuid,
      accountAccessToken: account.accessToken ?? '0',
      accountIsMicrosoft: account.type == 'microsoft',
    );

    final args = buildLaunchCommand(detail, instance, ctx);

    onStatus('Launching…', null);
    return GameProcessManager.launch(
      instanceId: instance.id,
      javaPath: javaPath,
      args: args,
      workingDirectory: instanceDir.path,
    );
  }

  static Future<VersionDetail> _mergeLoader({
    required String loader,
    required String mcVersion,
    required String loaderVersion,
    required VersionDetail vanilla,
    required String javawPath,
    required void Function(String status, double? fraction) onStatus,
  }) {
    switch (loader) {
      case 'fabric':
        return FabricInstaller.mergedVersionDetail(
          mcVersion: mcVersion,
          loaderVersion: loaderVersion,
          vanilla: vanilla,
        );
      case 'quilt':
        return QuiltInstaller.mergedVersionDetail(
          mcVersion: mcVersion,
          loaderVersion: loaderVersion,
          vanilla: vanilla,
        );
      case 'forge':
        return ForgeInstaller.installAndMerge(
          mcVersion: mcVersion,
          forgeVersion: loaderVersion,
          vanilla: vanilla,
          javawPath: javawPath,
          onStatus: onStatus,
        );
      case 'neoforge':
        return NeoForgeInstaller.installAndMerge(
          neoForgeVersion: loaderVersion,
          vanilla: vanilla,
          javawPath: javawPath,
          onStatus: onStatus,
        );
      default:
        throw LaunchOrchestratorException('Unknown mod loader "$loader".');
    }
  }

  static DownloadItem _libraryDownloadItem(Directory librariesDir, ResolvedLibrary lib) {
    // mavenPath is derived from manifest/loader-profile data fetched over the
    // network — validate it stays inside libraries/ before using it as a
    // write destination.
    final destPath = safeJoin(librariesDir.path, lib.mavenPath);
    if (destPath == null) {
      throw LaunchOrchestratorException(
          'Refusing to download library with unsafe path "${lib.mavenPath}".');
    }
    return DownloadItem(
      url: lib.url,
      destPath: destPath,
      sha1: lib.sha1,
      size: lib.size,
      label: lib.mavenPath.split('/').last,
    );
  }

  static String _loaderDisplayName(String loader) => switch (loader) {
        'fabric' => 'Fabric',
        'forge' => 'Forge',
        'neoforge' => 'NeoForge',
        'quilt' => 'Quilt',
        _ => loader,
      };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
