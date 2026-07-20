import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'mc_paths.dart';

class PistonMetaException implements Exception {
  PistonMetaException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One entry from the version manifest's `versions` list.
class VersionManifestEntry {
  VersionManifestEntry({
    required this.id,
    required this.type,
    required this.url,
    required this.releaseTime,
    required this.sha1,
  });

  final String id;
  final String type; // release | snapshot | old_beta | old_alpha
  final String url;
  final DateTime releaseTime;
  final String sha1;

  bool get isRelease => type == 'release';

  factory VersionManifestEntry.fromJson(Map<String, dynamic> json) {
    return VersionManifestEntry(
      id: json['id'] as String,
      type: json['type'] as String,
      url: json['url'] as String,
      releaseTime: DateTime.tryParse(json['releaseTime'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sha1: json['sha1'] as String? ?? '',
    );
  }
}

class VersionManifest {
  VersionManifest({required this.latestRelease, required this.latestSnapshot, required this.versions});
  final String latestRelease;
  final String latestSnapshot;
  final List<VersionManifestEntry> versions;
}

class DownloadRef {
  DownloadRef({required this.url, required this.sha1, required this.size});
  final String url;
  final String sha1;
  final int size;

  factory DownloadRef.fromJson(Map<String, dynamic> json) => DownloadRef(
        url: json['url'] as String,
        sha1: json['sha1'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
      );
}

/// One entry from a version detail's `libraries` array — a jar (optionally
/// OS-gated) and/or a set of native-classifier jars.
class VersionLibrary {
  VersionLibrary({
    required this.name,
    required this.rules,
    this.artifact,
    this.artifactPath,
    this.natives,
    this.classifiers,
    this.extractExclude = const [],
  });

  final String name;
  final List<Map<String, dynamic>> rules;
  final DownloadRef? artifact;
  final String? artifactPath;
  final Map<String, String>? natives; // os name -> classifier key
  final Map<String, DownloadRef>? classifiers;

  /// Path prefixes (from the library's `extract.exclude`, e.g. `META-INF/`)
  /// to skip when unzipping a native jar into `natives/`.
  final List<String> extractExclude;

  factory VersionLibrary.fromJson(Map<String, dynamic> json) {
    final downloads = json['downloads'] as Map<String, dynamic>?;
    final artifactJson = downloads?['artifact'] as Map<String, dynamic>?;
    final classifiersJson = downloads?['classifiers'] as Map<String, dynamic>?;
    final nativesJson = json['natives'] as Map<String, dynamic>?;
    final extractJson = json['extract'] as Map<String, dynamic>?;
    return VersionLibrary(
      name: json['name'] as String? ?? '',
      rules: (json['rules'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
      artifact: artifactJson == null ? null : DownloadRef.fromJson(artifactJson),
      artifactPath: artifactJson?['path'] as String?,
      natives: nativesJson?.map((k, v) => MapEntry(k, v as String)),
      classifiers: classifiersJson?.map(
        (k, v) => MapEntry(k, DownloadRef.fromJson(v as Map<String, dynamic>)),
      ),
      extractExclude: (extractJson?['exclude'] as List?)?.cast<String>() ?? const [],
    );
  }
}

/// Parsed per-version detail JSON — everything needed to resolve libraries,
/// assets, the Java requirement and the final launch command.
class VersionDetail {
  VersionDetail({
    required this.id,
    required this.mainClass,
    required this.assetIndexId,
    required this.assetIndexUrl,
    required this.clientDownload,
    required this.libraries,
    required this.javaMajorVersion,
    required this.gameArguments,
    required this.jvmArguments,
    required this.legacyMinecraftArguments,
  });

  final String id;
  final String mainClass;
  final String assetIndexId;
  final String assetIndexUrl;
  final DownloadRef clientDownload;
  final List<VersionLibrary> libraries;
  final int javaMajorVersion;

  /// Raw `arguments.game`/`arguments.jvm` entries — each is either a plain
  /// string token or a `{rules, value}` conditional object.
  final List<dynamic> gameArguments;
  final List<dynamic> jvmArguments;

  /// Pre-1.13 versions only have a flat `minecraftArguments` string instead
  /// of the structured `arguments` object.
  final String? legacyMinecraftArguments;

  factory VersionDetail.fromJson(Map<String, dynamic> json) {
    final downloads = json['downloads'] as Map<String, dynamic>;
    final assetIndex = json['assetIndex'] as Map<String, dynamic>;
    final arguments = json['arguments'] as Map<String, dynamic>?;
    return VersionDetail(
      id: json['id'] as String,
      mainClass: json['mainClass'] as String,
      assetIndexId: assetIndex['id'] as String,
      assetIndexUrl: assetIndex['url'] as String,
      clientDownload: DownloadRef.fromJson(downloads['client'] as Map<String, dynamic>),
      libraries: (json['libraries'] as List)
          .map((e) => VersionLibrary.fromJson(e as Map<String, dynamic>))
          .toList(),
      javaMajorVersion:
          (json['javaVersion'] as Map<String, dynamic>?)?['majorVersion'] as int? ?? 8,
      gameArguments: (arguments?['game'] as List?) ?? const [],
      jvmArguments: (arguments?['jvm'] as List?) ?? const [],
      legacyMinecraftArguments: json['minecraftArguments'] as String?,
    );
  }
}

/// Fetches and locally caches Mojang's public version manifest and per-version
/// detail JSON — no auth required. Detail JSON is cached under
/// `minecraft/versions/<id>/<id>.json` so re-launching a version already
/// created doesn't re-hit the network.
class PistonMetaClient {
  PistonMetaClient._();
  static final PistonMetaClient instance = PistonMetaClient._();

  static const _manifestUrl =
      'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json';

  Future<VersionManifest> fetchManifest() async {
    final json = await _getJson(_manifestUrl);
    final latest = json['latest'] as Map<String, dynamic>;
    final versions = (json['versions'] as List)
        .map((e) => VersionManifestEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return VersionManifest(
      latestRelease: latest['release'] as String,
      latestSnapshot: latest['snapshot'] as String,
      versions: versions,
    );
  }

  Future<VersionDetail> fetchVersionDetail(VersionManifestEntry entry) async {
    final dir = await McPaths.versionDir(entry.id);
    final file = File('${dir.path}${Platform.pathSeparator}${entry.id}.json');
    Map<String, dynamic> json;
    if (await file.exists()) {
      json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } else {
      json = await _getJson(entry.url);
      await file.writeAsString(jsonEncode(json));
    }
    return VersionDetail.fromJson(json);
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final http.Response res;
    try {
      res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw PistonMetaException('Could not reach $url. Check your connection.');
    }
    if (res.statusCode != 200) {
      throw PistonMetaException('Request failed (${res.statusCode}) for $url.');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
