import 'modrinth_api_client.dart';

class ResolvedDependency {
  ResolvedDependency({required this.project, required this.version});
  final ModrinthProject project;
  final ModrinthVersion version;
}

/// Walks a chosen mod version's `required` dependencies (recursively, since
/// a dependency can itself depend on something else) and resolves each to
/// the newest version compatible with the target Minecraft version + loader.
/// Depth is capped so a bad/cyclical dependency graph can't hang; results
/// are de-duplicated by project so the caller gets one confirm-and-install
/// list rather than a raw tree.
class ModDependencyResolver {
  const ModDependencyResolver._();

  static Future<List<ResolvedDependency>> resolveRequired({
    required ModrinthVersion rootVersion,
    required String gameVersion,
    required String loader,
    Set<String> alreadyInstalledProjectIds = const {},
    int maxDepth = 4,
  }) async {
    final resolved = <String, ResolvedDependency>{};

    Future<void> visit(ModrinthVersion version, int depth) async {
      if (depth > maxDepth) return;
      for (final dep in version.dependencies.where((d) => d.dependencyType == 'required')) {
        var projectId = dep.projectId;
        ModrinthVersion? depVersion;

        if (dep.versionId != null) {
          try {
            depVersion = await ModrinthApiClient.instance.getVersion(dep.versionId!);
            projectId ??= depVersion.projectId;
          } catch (_) {
            // Fall through to resolving by project id below.
          }
        }

        if (projectId == null) continue;
        if (alreadyInstalledProjectIds.contains(projectId)) continue;
        if (resolved.containsKey(projectId)) continue;

        depVersion ??= await _bestVersion(projectId, gameVersion, loader);
        if (depVersion == null) continue;

        final project = await ModrinthApiClient.instance.getProject(projectId);
        resolved[projectId] = ResolvedDependency(project: project, version: depVersion);
        await visit(depVersion, depth + 1);
      }
    }

    await visit(rootVersion, 0);
    return resolved.values.toList();
  }

  static Future<ModrinthVersion?> _bestVersion(
    String projectId,
    String gameVersion,
    String loader,
  ) async {
    final versions = await ModrinthApiClient.instance.getProjectVersions(
      projectId,
      gameVersion: gameVersion,
      loader: loader,
    );
    // Modrinth returns versions newest-first.
    return versions.isEmpty ? null : versions.first;
  }
}
