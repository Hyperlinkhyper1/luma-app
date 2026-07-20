import 'dart:io';

import '../data/minecraft_launcher_database.dart';
import '../minecraft_launcher_repository.dart';
import 'download_manager.dart';
import 'mc_paths.dart';
import 'modrinth_api_client.dart';
import 'safe_path.dart';

/// Content kinds this launcher can browse/install from Modrinth. Datapacks
/// aren't a distinct Modrinth `project_type` (they're normally distributed
/// as regular mods or bundled in modpacks), so they're intentionally not a
/// browse option here — the `McInstalledMods.kind` column still accepts
/// `'datapack'` for anything installed by other means later.
const modrinthProjectTypes = {
  'mod': 'Mods',
  'resourcepack': 'Resource Packs',
  'shader': 'Shader Packs',
};

String contentFolderFor(String kind) => switch (kind) {
      'mod' => 'mods',
      'resourcepack' => 'resourcepacks',
      'shader' => 'shaderpacks',
      'datapack' => 'datapacks',
      _ => 'mods',
    };

/// Downloads a Modrinth version's primary file into the right per-instance
/// content folder and records it in the local `McInstalledMods` table.
class ModInstaller {
  const ModInstaller._();

  static Future<void> installVersion({
    required MinecraftLauncherRepository repository,
    required McInstance instance,
    required ModrinthProject project,
    required ModrinthVersion version,
    required String kind,
  }) async {
    final destDir = await McPaths.instanceSubDir(instance.id, contentFolderFor(kind));
    final file = version.primaryFile;
    // The filename comes from Modrinth's API response — treat it as
    // untrusted and refuse separators/traversal rather than trusting the
    // service (or a spoofed response) to be well-behaved.
    final destPath = safeJoin(destDir.path, file.filename);
    if (destPath == null || file.filename.contains('/') || file.filename.contains('\\')) {
      throw ModrinthApiException('Refusing to install "${file.filename}": unsafe file name.');
    }

    await DownloadManager.instance.downloadAll([
      DownloadItem(
        url: file.url,
        destPath: destPath,
        sha1: file.sha1.isEmpty ? null : file.sha1,
        size: file.size,
        label: file.filename,
      ),
    ]);

    await repository.recordInstalledContent(
      instanceId: instance.id,
      projectId: project.id,
      versionId: version.id,
      projectName: project.title,
      projectIconUrl: project.iconUrl,
      fileName: file.filename,
      sha1: file.sha1.isEmpty ? null : file.sha1,
      kind: kind,
    );
  }

  /// Replaces an installed item with a newer version: removes the old file
  /// + record, then installs the new one — a plain delete-then-install
  /// rather than an in-place rewrite, since the new version may ship under a
  /// different file name.
  static Future<void> updateToVersion({
    required MinecraftLauncherRepository repository,
    required McInstance instance,
    required McInstalledMod current,
    required ModrinthProject project,
    required ModrinthVersion newVersion,
  }) async {
    await deleteInstalled(repository: repository, instanceId: instance.id, content: current);
    await installVersion(
      repository: repository,
      instance: instance,
      project: project,
      version: newVersion,
      kind: current.kind,
    );
  }

  static Future<void> deleteInstalled({
    required MinecraftLauncherRepository repository,
    required String instanceId,
    required McInstalledMod content,
  }) async {
    final dir = await McPaths.instanceSubDir(instanceId, contentFolderFor(content.kind));
    final path = safeJoin(dir.path, content.fileName);
    if (path != null && !content.fileName.contains('/') && !content.fileName.contains('\\')) {
      final file = File(path);
      final disabledFile = File('$path.disabled');
      if (await file.exists()) await file.delete();
      if (await disabledFile.exists()) await disabledFile.delete();
    }
    await repository.deleteInstalledContent(content.id);
  }

  /// Toggling "enabled" renames the file with/without a `.disabled` suffix —
  /// the same convention the wider Minecraft modding ecosystem (and
  /// Modrinth's own app) uses, so loaders just skip disabled files outright.
  static Future<void> setEnabled({
    required MinecraftLauncherRepository repository,
    required String instanceId,
    required McInstalledMod content,
    required bool enabled,
  }) async {
    final dir = await McPaths.instanceSubDir(instanceId, contentFolderFor(content.kind));
    final base = safeJoin(dir.path, content.fileName);
    if (base == null || content.fileName.contains('/') || content.fileName.contains('\\')) {
      return;
    }
    final enabledFile = File(base);
    final disabledFile = File('$base.disabled');
    if (enabled && await disabledFile.exists()) {
      await disabledFile.rename(base);
    } else if (!enabled && await enabledFile.exists()) {
      await enabledFile.rename('$base.disabled');
    }
    await repository.setContentEnabled(content.id, enabled);
  }
}
