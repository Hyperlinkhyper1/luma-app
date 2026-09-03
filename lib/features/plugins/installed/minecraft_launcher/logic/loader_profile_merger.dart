import 'piston_meta_client.dart';

/// Fabric's and Quilt's "profile json" endpoints both return a launcher
/// profile shaped like `{id, inheritsFrom, mainClass, arguments?, libraries}`
/// that layers on top of the vanilla version it inherits from, rather than a
/// full standalone version JSON. This merges one of those profiles onto an
/// already-resolved vanilla [VersionDetail], producing a synthetic
/// [VersionDetail] the existing library resolver / launch command builder
/// can consume unmodified.
VersionDetail mergeLoaderProfile(VersionDetail vanilla, Map<String, dynamic> profile) {
  final mainClass = profile['mainClass'] as String? ?? vanilla.mainClass;

  final loaderLibraries = ((profile['libraries'] as List?) ?? const [])
      .map((e) => _loaderLibraryToVersionLibrary(e as Map<String, dynamic>))
      .toList();

  final arguments = profile['arguments'] as Map<String, dynamic>?;
  final extraGameArgs = (arguments?['game'] as List?) ?? const [];
  final extraJvmArgs = (arguments?['jvm'] as List?) ?? const [];

  return VersionDetail(
    id: profile['id'] as String? ?? vanilla.id,
    mainClass: mainClass,
    assetIndexId: vanilla.assetIndexId,
    assetIndexUrl: vanilla.assetIndexUrl,
    clientDownload: vanilla.clientDownload,
    // Loader libraries first so a loader-pinned version of a shared
    // dependency (e.g. a newer ASM) resolves before the vanilla copy, since
    // resolveLibraries() de-dupes by path and keeps the first occurrence.
    libraries: [...loaderLibraries, ...vanilla.libraries],
    javaMajorVersion: vanilla.javaMajorVersion,
    gameArguments: [...extraGameArgs, ...vanilla.gameArguments],
    jvmArguments: [...extraJvmArgs, ...vanilla.jvmArguments],
    legacyMinecraftArguments: vanilla.legacyMinecraftArguments,
  );
}

/// Fabric/Quilt libraries are flat `{"name": "group:artifact:version", "url":
/// "https://maven.example/"}` entries (no `downloads.artifact.sha1/size`
/// like Mojang's own manifest), so this derives the same Maven-layout path
/// vanilla libraries use and builds the download URL by hand. No checksum is
/// available from this API, so downloads are only validated by presence.
VersionLibrary _loaderLibraryToVersionLibrary(Map<String, dynamic> json) {
  final name = json['name'] as String;
  final baseUrl = (json['url'] as String? ?? 'https://maven.fabricmc.net/').trimRight();
  final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
  final path = _mavenPath(name);
  return VersionLibrary(
    name: name,
    rules: const [],
    artifact: DownloadRef(url: '$normalizedBase$path', sha1: '', size: 0),
    artifactPath: path,
  );
}

String _mavenPath(String mavenName) {
  final parts = mavenName.split(':');
  final group = parts[0].replaceAll('.', '/');
  final artifact = parts[1];
  final version = parts[2];
  return '$group/$artifact/$version/$artifact-$version.jar';
}
