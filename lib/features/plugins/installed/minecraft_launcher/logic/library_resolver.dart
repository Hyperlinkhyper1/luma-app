import 'piston_meta_client.dart';
import 'rules_evaluator.dart';

/// One file that needs to end up on disk before launch: either a regular
/// classpath jar, or a native-classifier jar that gets unzipped into the
/// instance's `natives/` folder instead of added to the classpath.
class ResolvedLibrary {
  ResolvedLibrary({
    required this.mavenPath,
    required this.url,
    required this.sha1,
    required this.size,
    required this.isNative,
    this.extractExclude = const [],
  });

  final String mavenPath; // relative path under minecraft/libraries/
  final String url;
  final String sha1;
  final int size;
  final bool isNative;
  final List<String> extractExclude;
}

/// Filters a version's `libraries[]` down to the ones that apply on this
/// platform (via [evaluateRules]) and flattens each into the classpath jar
/// and/or native jar it contributes. De-duplicates by [mavenPath] since
/// multiple loader/base-game library lists can reference the same artifact.
List<ResolvedLibrary> resolveLibraries(VersionDetail detail) {
  final seen = <String>{};
  final result = <ResolvedLibrary>[];

  void add(ResolvedLibrary lib) {
    if (seen.add(lib.mavenPath)) result.add(lib);
  }

  for (final lib in detail.libraries) {
    if (!evaluateRules(lib.rules)) continue;

    if (lib.artifact != null && lib.artifactPath != null) {
      add(ResolvedLibrary(
        mavenPath: lib.artifactPath!,
        url: lib.artifact!.url,
        sha1: lib.artifact!.sha1,
        size: lib.artifact!.size,
        isNative: false,
      ));
    }

    final classifierKey = lib.natives?['windows'];
    if (classifierKey != null && lib.classifiers != null) {
      final classifier = lib.classifiers![classifierKey];
      if (classifier != null) {
        // Classifier downloads don't carry an explicit `path`; Mojang's own
        // convention derives it from the classifier's own artifact metadata,
        // which for classifiers matches `<mavenPath-without-ext>-<classifier>.jar`.
        // The manifest's classifiers map key IS that resolved path in modern
        // (post-1.19) manifests' `downloads.classifiers.<key>.path`; older
        // manifests omit it, so fall back to deriving it from the library name.
        add(ResolvedLibrary(
          mavenPath: _deriveNativePath(lib.name, classifierKey),
          url: classifier.url,
          sha1: classifier.sha1,
          size: classifier.size,
          isNative: true,
          extractExclude: lib.extractExclude,
        ));
      }
    }
  }

  return result;
}

/// Derives `<group>/<artifact>/<version>/<artifact>-<version>-<classifier>.jar`
/// from a Maven coordinate string `group:artifact:version`, matching how the
/// vanilla launcher lays out native jars under `libraries/`.
String _deriveNativePath(String mavenName, String classifier) {
  final parts = mavenName.split(':');
  if (parts.length < 3) return '$mavenName-$classifier.jar';
  final group = parts[0].replaceAll('.', '/');
  final artifact = parts[1];
  final version = parts[2];
  return '$group/$artifact/$version/$artifact-$version-$classifier.jar';
}
