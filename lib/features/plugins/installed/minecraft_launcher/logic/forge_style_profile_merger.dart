import 'piston_meta_client.dart';

/// Forge/NeoForge client installers write a version JSON (under
/// `versions/<id>/<id>.json` in the target Minecraft directory) shaped like
/// `{id, inheritsFrom, mainClass, arguments: {game, jvm}, libraries}` — unlike
/// Fabric/Quilt's flat-URL libraries, these already use the same nested
/// `downloads.artifact.{url,sha1,size}` shape as vanilla's own manifest, so
/// [VersionLibrary.fromJson] parses them directly. This merges that profile
/// onto the resolved vanilla [VersionDetail] it inherits from.
VersionDetail mergeForgeStyleProfile(VersionDetail vanilla, Map<String, dynamic> profile) {
  final mainClass = profile['mainClass'] as String? ?? vanilla.mainClass;

  final loaderLibraries = ((profile['libraries'] as List?) ?? const [])
      .map((e) => VersionLibrary.fromJson(e as Map<String, dynamic>))
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
    libraries: [...loaderLibraries, ...vanilla.libraries],
    javaMajorVersion: vanilla.javaMajorVersion,
    gameArguments: [...extraGameArgs, ...vanilla.gameArguments],
    jvmArguments: [...extraJvmArgs, ...vanilla.jvmArguments],
    legacyMinecraftArguments: vanilla.legacyMinecraftArguments,
  );
}
