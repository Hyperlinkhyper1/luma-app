import '../data/minecraft_launcher_database.dart';
import 'modrinth_api_client.dart';

class ModUpdateInfo {
  ModUpdateInfo({required this.installed, required this.latestVersion});
  final McInstalledMod installed;
  final ModrinthVersion latestVersion;
}

class ModConflict {
  ModConflict({required this.a, required this.b, required this.reason});
  final McInstalledMod a;
  final McInstalledMod b;
  final String reason;
}

/// Checks installed mods/resource packs/shader packs for newer compatible
/// Modrinth versions, and for declared incompatibilities between the mods
/// that are actually installed together. Both are best-effort: a project
/// that's been removed from Modrinth, or a network hiccup, just makes that
/// one item silently unreported rather than failing the whole check.
class ModUpdateChecker {
  const ModUpdateChecker._();

  static Future<List<ModUpdateInfo>> checkUpdates({
    required List<McInstalledMod> installed,
    required String gameVersion,
    required String loader,
  }) async {
    final results = <ModUpdateInfo>[];
    for (final item in installed) {
      final projectId = item.projectId;
      if (projectId == null) continue;
      try {
        final versions = await ModrinthApiClient.instance.getProjectVersions(
          projectId,
          gameVersion: gameVersion,
          loader: item.kind == 'mod' ? loader : null,
        );
        if (versions.isEmpty) continue;
        final latest = versions.first; // Modrinth returns newest-first
        if (latest.id != item.versionId) {
          results.add(ModUpdateInfo(installed: item, latestVersion: latest));
        }
      } catch (_) {
        // Skip this item — best-effort check.
      }
    }
    return results;
  }

  static Future<List<ModConflict>> checkConflicts({
    required List<McInstalledMod> installed,
  }) async {
    final byProject = <String, McInstalledMod>{
      for (final item in installed)
        if (item.projectId != null) item.projectId!: item,
    };
    final conflicts = <ModConflict>[];
    final seenPairs = <String>{};

    for (final item in installed) {
      final projectId = item.projectId;
      final versionId = item.versionId;
      if (projectId == null || versionId == null) continue;
      try {
        final version = await ModrinthApiClient.instance.getVersion(versionId);
        for (final dep in version.dependencies.where((d) => d.dependencyType == 'incompatible')) {
          final otherId = dep.projectId;
          final other = otherId == null ? null : byProject[otherId];
          if (other == null) continue;
          final pairKey = ([projectId, otherId].toList()..sort()).join('|');
          if (!seenPairs.add(pairKey)) continue;
          conflicts.add(ModConflict(
            a: item,
            b: other,
            reason:
                '${item.projectName ?? item.fileName} is marked incompatible with ${other.projectName ?? other.fileName}.',
          ));
        }
      } catch (_) {
        // Skip this item — best-effort check.
      }
    }
    return conflicts;
  }
}
