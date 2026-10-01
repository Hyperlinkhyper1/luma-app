import 'curseforge_api_client.dart';
import 'modrinth_api_client.dart';

/// Where the launcher's browsable content comes from.
enum ContentSource {
  modrinth('Modrinth'),
  curseforge('CurseForge');

  const ContentSource(this.label);
  final String label;

  static ContentSource ofId(String projectOrVersionId) =>
      CurseForgeApiClient.isCurseForgeId(projectOrVersionId) ? curseforge : modrinth;
}

/// The one entry point the launcher uses to reach a content catalogue.
///
/// Searches go to the source the user picked; everything keyed by an id —
/// project pages, version lists, dependency walks, update checks — is
/// routed by the id itself, since CurseForge ids carry a `cf:` prefix. That
/// is what lets one install flow and one installed-content table serve
/// both catalogues.
class ContentApi {
  const ContentApi._();

  static Future<ModrinthSearchResult> search({
    required ContentSource source,
    String query = '',
    required String projectType,
    String? gameVersion,
    String? loader,
    String index = 'relevance',
    int limit = 20,
    int offset = 0,
  }) =>
      switch (source) {
        ContentSource.modrinth => ModrinthApiClient.instance.search(
            query: query,
            projectType: projectType,
            gameVersion: gameVersion,
            loader: loader,
            index: index,
            limit: limit,
            offset: offset,
          ),
        ContentSource.curseforge => CurseForgeApiClient.instance.search(
            query: query,
            projectType: projectType,
            gameVersion: gameVersion,
            loader: loader,
            index: index,
            limit: limit,
            offset: offset,
          ),
      };

  static Future<ModrinthProject> getProject(String id) =>
      CurseForgeApiClient.isCurseForgeId(id)
          ? CurseForgeApiClient.instance.getProject(id)
          : ModrinthApiClient.instance.getProject(id);

  static Future<List<ModrinthTeamMember>> getProjectMembers(String id) =>
      CurseForgeApiClient.isCurseForgeId(id)
          ? CurseForgeApiClient.instance.getProjectMembers(id)
          : ModrinthApiClient.instance.getProjectMembers(id);

  /// Newest first for both sources.
  static Future<List<ModrinthVersion>> getProjectVersions(
    String id, {
    String? gameVersion,
    String? loader,
  }) =>
      CurseForgeApiClient.isCurseForgeId(id)
          ? CurseForgeApiClient.instance
              .getProjectVersions(id, gameVersion: gameVersion, loader: loader)
          : ModrinthApiClient.instance
              .getProjectVersions(id, gameVersion: gameVersion, loader: loader);

  static Future<ModrinthVersion> getVersion(String versionId) =>
      CurseForgeApiClient.isCurseForgeId(versionId)
          ? CurseForgeApiClient.instance.getVersion(versionId)
          : ModrinthApiClient.instance.getVersion(versionId);

  static String projectPageUrl(ModrinthProject project) =>
      project.pageUrl ?? ModrinthApiClient.projectUrl(project.projectType, project.slug);
}
