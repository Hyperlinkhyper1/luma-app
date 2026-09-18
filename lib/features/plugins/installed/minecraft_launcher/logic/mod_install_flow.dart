import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../data/minecraft_launcher_database.dart';
import '../minecraft_launcher_repository.dart';
import 'mod_dependency_resolver.dart';
import 'mod_installer.dart';
import 'modrinth_api_client.dart';

/// The one install path shared by every Modrinth surface in the launcher:
/// the quick "+" on a browse tile, the version list on a project page, and
/// the global search results. Keeping it here means the dependency prompt
/// and the "already installed" check behave identically wherever the user
/// starts from.
class ModInstallFlow {
  const ModInstallFlow._();

  /// Picks the version a one-tap install should use: newest first, and a
  /// full release in preference to a beta/alpha of the same age.
  static ModrinthVersion? bestVersion(List<ModrinthVersion> versions) {
    if (versions.isEmpty) return null;
    final sorted = [...versions]
      ..sort((a, b) => b.datePublished.compareTo(a.datePublished));
    return sorted.firstWhere(
      (v) => v.versionType == 'release',
      orElse: () => sorted.first,
    );
  }

  /// Loads the versions of [projectId] that fit [instance]. Resource packs
  /// and shaders aren't loader-specific, so the loader facet only applies to
  /// mods.
  static Future<List<ModrinthVersion>> compatibleVersions({
    required String projectId,
    required McInstance instance,
    required String kind,
  }) {
    final loaderFilter =
        kind == 'mod' && instance.loader != 'vanilla' ? instance.loader : null;
    return ModrinthApiClient.instance.getProjectVersions(
      projectId,
      gameVersion: instance.versionId,
      loader: loaderFilter,
    );
  }

  static Future<Set<String>> installedProjectIds(
    MinecraftLauncherRepository repository,
    String instanceId,
  ) async {
    final rows = await repository.watchInstalledContent(instanceId).first;
    return rows
        .map((r) => r.projectId)
        .whereType<String>()
        .toSet();
  }

  /// Downloads [version] plus anything it hard-depends on into [instance].
  /// Asks before pulling dependencies in; returns false if the user backed
  /// out or the install failed (the reason is shown as a snack bar).
  static Future<bool> install({
    required BuildContext context,
    required MinecraftLauncherRepository repository,
    required McInstance instance,
    required ModrinthProject project,
    required ModrinthVersion version,
    required String kind,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final alreadyInstalled =
          await installedProjectIds(repository, instance.id);
      final deps = await ModDependencyResolver.resolveRequired(
        rootVersion: version,
        gameVersion: instance.versionId,
        loader: instance.loader,
        alreadyInstalledProjectIds: alreadyInstalled,
      );

      if (deps.isNotEmpty) {
        if (!context.mounted) return false;
        final proceed = await _confirmDependencies(context, project, deps);
        if (proceed != true) return false;
      }

      await ModInstaller.installVersion(
        repository: repository,
        instance: instance,
        project: project,
        version: version,
        kind: kind,
      );
      for (final dep in deps) {
        await ModInstaller.installVersion(
          repository: repository,
          instance: instance,
          project: dep.project,
          version: dep.version,
          kind: kind,
        );
      }

      final extra = deps.isEmpty ? '' : ' + ${deps.length} dependencies';
      messenger.showSnackBar(
        SnackBar(content: Text('Installed ${project.title}$extra into ${instance.name}.')),
      );
      return true;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return false;
    }
  }

  /// One-tap install used by the browse tiles: resolve the best compatible
  /// version for the instance, then run the normal install.
  static Future<bool> installLatest({
    required BuildContext context,
    required MinecraftLauncherRepository repository,
    required McInstance instance,
    required String projectId,
    required String kind,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final ModrinthProject project;
    final ModrinthVersion? version;
    try {
      project = await ModrinthApiClient.instance.getProject(projectId);
      version = bestVersion(await compatibleVersions(
        projectId: projectId,
        instance: instance,
        kind: kind,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return false;
    }
    if (version == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No build of this for ${instance.versionId}'
            '${instance.loader == 'vanilla' ? '' : ' on ${instance.loader}'}.',
          ),
        ),
      );
      return false;
    }
    if (!context.mounted) return false;
    return install(
      context: context,
      repository: repository,
      instance: instance,
      project: project,
      version: version,
      kind: kind,
    );
  }

  static Future<bool?> _confirmDependencies(
    BuildContext context,
    ModrinthProject project,
    List<ResolvedDependency> deps,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Install required dependencies?'),
        content: SizedBox(
          width: lumaDialogWidth(context, 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${project.title} needs these to work:'),
              const SizedBox(height: 8),
              for (final d in deps) Text('• ${d.project.title}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Install all')),
        ],
      ),
    );
  }
}
