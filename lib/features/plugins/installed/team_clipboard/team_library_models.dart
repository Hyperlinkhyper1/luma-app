import 'dart:convert';
import 'dart:typed_data';

import 'team_clipboard_models.dart';

/// Where a library mod is: waiting or being unpacked on the server, ready
/// to browse, or failed before anything could be unpacked.
enum TeamLibraryModState {
  queued,
  loading,
  ready,
  failed;

  static TeamLibraryModState parse(Object? raw) =>
      values.asNameMap()[raw] ?? queued;
}

/// The version of a mod the library holds.
class TeamLibraryVersion {
  const TeamLibraryVersion({
    required this.id,
    required this.number,
    required this.name,
    required this.fileName,
    required this.publishedAt,
    this.loaders = const [],
    this.gameVersions = const [],
  });

  final String id;
  final String number;
  final String name;
  final String fileName;
  final DateTime publishedAt;
  final List<String> loaders;
  final List<String> gameVersions;

  static TeamLibraryVersion? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String) return null;
    return TeamLibraryVersion(
      id: raw['id'] as String,
      number: raw['number'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      fileName: raw['fileName'] as String? ?? '',
      publishedAt: DateTime.fromMillisecondsSinceEpoch(
        raw['publishedAtMs'] as int? ?? 0,
      ),
      loaders: _strings(raw['loaders']),
      gameVersions: _strings(raw['gameVersions']),
    );
  }
}

/// A Modrinth mod (or resource pack) a lead put in the library.
class TeamLibraryMod {
  const TeamLibraryMod({
    required this.id,
    required this.slug,
    required this.title,
    required this.projectType,
    required this.url,
    required this.addedBy,
    required this.state,
    this.iconUrl,
    this.description = '',
    this.loaders = const [],
    this.gameVersions = const [],
    this.loader,
    this.gameVersion,
    this.error,
    this.version,
    this.loadedAt,
    this.checkedAt,
    this.fileCount = 0,
    this.bytes = 0,
    this.skipped = 0,
    this.namespaces = const [],
    this.history = const [],
  });

  final String id;
  final String slug;
  final String title;
  final String projectType;
  final String url;
  final String? iconUrl;
  final String description;
  final String addedBy;

  /// What the project is published for, newest game version first.
  final List<String> loaders;
  final List<String> gameVersions;

  /// Which versions the library follows; null follows any.
  final String? loader;
  final String? gameVersion;

  final TeamLibraryModState state;

  /// Why the last check went wrong. A ready mod keeps its last good
  /// assets beside it.
  final String? error;
  final TeamLibraryVersion? version;
  final DateTime? loadedAt;
  final DateTime? checkedAt;
  final int fileCount;
  final int bytes;
  final int skipped;
  final List<String> namespaces;

  /// Versions unpacked before this one, newest first.
  final List<({String number, DateTime loadedAt})> history;

  bool get working =>
      state == TeamLibraryModState.queued ||
      state == TeamLibraryModState.loading;

  bool get hasAssets => version != null && fileCount > 0;

  factory TeamLibraryMod.fromJson(Map<String, dynamic> j) {
    DateTime? at(Object? ms) =>
        ms is int && ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
    return TeamLibraryMod(
      id: j['id'] as String,
      slug: j['slug'] as String? ?? '',
      title: j['title'] as String? ?? '',
      projectType: j['projectType'] as String? ?? 'mod',
      url: j['url'] as String? ?? '',
      iconUrl: j['iconUrl'] as String?,
      description: j['description'] as String? ?? '',
      addedBy: j['addedBy'] as String? ?? '',
      loaders: _strings(j['loaders']),
      gameVersions: _strings(j['gameVersions']),
      loader: j['loader'] as String?,
      gameVersion: j['gameVersion'] as String?,
      state: TeamLibraryModState.parse(j['state']),
      error: j['error'] as String?,
      version: TeamLibraryVersion.fromJson(j['version']),
      loadedAt: at(j['loadedAtMs']),
      checkedAt: at(j['checkedAtMs']),
      fileCount: j['fileCount'] as int? ?? 0,
      bytes: j['bytes'] as int? ?? 0,
      skipped: j['skipped'] as int? ?? 0,
      namespaces: _strings(j['namespaces']),
      history: [
        for (final h in j['history'] as List? ?? const [])
          if (h is Map && h['number'] is String)
            (
              number: h['number'] as String,
              loadedAt: DateTime.fromMillisecondsSinceEpoch(
                h['loadedAtMs'] as int? ?? 0,
              ),
            ),
      ],
    );
  }
}

/// What `GET /team-board/library` answered. [mods] is null when nothing
/// changed since the revision asked about.
class TeamLibraryState {
  const TeamLibraryState({
    required this.revision,
    required this.canManage,
    required this.busy,
    required this.mods,
  });

  final int revision;

  /// A lead: may add, change and remove mods.
  final bool canManage;

  /// The server is checking or unpacking something right now.
  final bool busy;
  final List<TeamLibraryMod>? mods;

  factory TeamLibraryState.fromJson(Map<String, dynamic> j) => TeamLibraryState(
    revision: j['revision'] as int? ?? 0,
    canManage: j['canManage'] == true,
    busy: j['busy'] == true,
    mods: j['unchanged'] == true
        ? null
        : [
            for (final m in j['mods'] as List? ?? const [])
              TeamLibraryMod.fromJson(m as Map<String, dynamic>),
          ],
  );
}

/// A Modrinth search result in the lead's "add a mod" picker.
class TeamLibraryHit {
  const TeamLibraryHit({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    required this.downloads,
    required this.projectType,
    this.iconUrl,
    this.loaders = const [],
    this.gameVersions = const [],
  });

  final String id;
  final String title;
  final String description;
  final String author;
  final int downloads;
  final String projectType;
  final String? iconUrl;
  final List<String> loaders;

  /// Newest first.
  final List<String> gameVersions;

  factory TeamLibraryHit.fromJson(Map<String, dynamic> j) => TeamLibraryHit(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    author: j['author'] as String? ?? '',
    downloads: j['downloads'] as int? ?? 0,
    projectType: j['projectType'] as String? ?? 'mod',
    iconUrl: j['iconUrl'] as String?,
    loaders: _strings(j['loaders']),
    gameVersions: _strings(j['gameVersions']),
  );
}

/// What kind of file an asset is, by where it sits in the jar.
enum TeamAssetCategory { textures, models, blockstates, lang, data, other }

/// One file the library unpacked from a mod.
class TeamLibraryAsset {
  TeamLibraryAsset(this.path, this.sha1, this.size, {DateTime? loadedAt})
    : loadedAt = loadedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Where it sits in the jar: `assets/ruby/textures/block/ruby.png`.
  final String path;
  final String sha1;
  final int size;
  final DateTime loadedAt;

  /// The id the controller fetches it by, beside the board's own files.
  String get fileId => '$kTeamLibraryFilePrefix$sha1';

  String get name => path.substring(path.lastIndexOf('/') + 1);

  String get namespace => path.split('/')[1];

  /// The folder within its namespace: `textures/block`.
  String get folder {
    final parts = path.split('/');
    return parts.length > 3 ? parts.sublist(2, parts.length - 1).join('/') : '';
  }

  bool get isImage => path.endsWith('.png');
  bool get isJson => path.endsWith('.json');

  TeamAssetCategory get category {
    final parts = path.split('/');
    if (parts.first == 'data') return TeamAssetCategory.data;
    return switch (parts.length > 2 ? parts[2] : '') {
      'textures' when isImage => TeamAssetCategory.textures,
      'models' => TeamAssetCategory.models,
      'blockstates' => TeamAssetCategory.blockstates,
      'lang' => TeamAssetCategory.lang,
      _ => TeamAssetCategory.other,
    };
  }

  /// The file as the board's viewer and preview dialogs take one.
  TeamFile toTeamFile() => TeamFile(
    id: fileId,
    name: name,
    sizeBytes: size,
    uploader: '',
    mine: false,
    canRemove: false,
    createdAt: loadedAt,
  );
}

/// The prefix that marks a controller file id as a library asset.
const kTeamLibraryFilePrefix = 'lib:';

/// How many library files one request asks for; the server takes at most
/// this many.
const kTeamLibraryBatchFiles = 200;

/// What a batch of library files came back as. Ids in neither [files] nor
/// [missing] didn't fit in the answer and are asked for again; a
/// [retryAfter] means the server wants the whole batch asked again later.
class TeamLibraryBlobs {
  const TeamLibraryBlobs({
    this.files = const {},
    this.missing = const {},
    this.retryAfter,
  });

  const TeamLibraryBlobs.wait(Duration this.retryAfter)
    : files = const {},
      missing = const {};

  final Map<String, Uint8List> files;
  final Set<String> missing;
  final Duration? retryAfter;

  factory TeamLibraryBlobs.fromJson(Map<String, dynamic> j) {
    final files = <String, Uint8List>{};
    final raw = j['files'];
    if (raw is Map) {
      raw.forEach((id, data) {
        if (id is! String || data is! String) return;
        try {
          files[id] = base64Decode(data);
        } on FormatException {
          return;
        }
      });
    }
    return TeamLibraryBlobs(
      files: files,
      missing: {
        for (final id in j['missing'] as List? ?? const [])
          if (id is String) id,
      },
    );
  }
}

/// A mod's file list, for the version the library holds.
class TeamLibraryIndex {
  TeamLibraryIndex(this.versionId, this.assets)
    : _byPath = {for (final a in assets) a.path: a};

  final String versionId;
  final List<TeamLibraryAsset> assets;
  final Map<String, TeamLibraryAsset> _byPath;

  TeamLibraryAsset? operator [](String path) => _byPath[path];

  factory TeamLibraryIndex.fromJson(
    Map<String, dynamic> j, {
    DateTime? loadedAt,
  }) => TeamLibraryIndex(j['versionId'] as String? ?? '', [
    for (final f in j['files'] as List? ?? const [])
      if (f is List && f.length >= 3 && f[0] is String && f[1] is String)
        TeamLibraryAsset(
          f[0] as String,
          f[1] as String,
          (f[2] as num?)?.toInt() ?? 0,
          loadedAt: loadedAt,
        ),
  ]);

  /// The model file a `parent` or blockstate `model` reference points at,
  /// in this mod. Vanilla models aren't in a mod's jar and come back null.
  TeamLibraryAsset? model(String ref) =>
      this[_location(ref, 'models', '.json')];

  /// The texture a model's texture reference points at, in this mod.
  TeamLibraryAsset? texture(String ref) =>
      this[_location(ref, 'textures', '.png')];

  static String _location(String ref, String folder, String extension) {
    var s = ref.trim();
    var namespace = 'minecraft';
    final colon = s.indexOf(':');
    if (colon >= 0) {
      namespace = s.substring(0, colon);
      s = s.substring(colon + 1);
    }
    if (!s.endsWith(extension)) s = '$s$extension';
    return 'assets/$namespace/$folder/$s';
  }
}

/// The model a blockstate or 1.21.4 item definition shows first, or null
/// when [json] is neither.
String? teamFirstModelRef(Map<String, dynamic> json) {
  String? fromApply(Object? apply) {
    if (apply is Map && apply['model'] is String) {
      return apply['model'] as String;
    }
    if (apply is List && apply.isNotEmpty) return fromApply(apply.first);
    return null;
  }

  final variants = json['variants'];
  if (variants is Map && variants.isNotEmpty) {
    return fromApply(variants.values.first);
  }
  final multipart = json['multipart'];
  if (multipart is List) {
    for (final part in multipart) {
      final ref = part is Map ? fromApply(part['apply']) : null;
      if (ref != null) return ref;
    }
  }
  final item = json['model'];
  if (item is Map && item['model'] is String) return item['model'] as String;
  return null;
}

List<String> _strings(Object? raw) => [
  for (final s in raw is List ? raw : const [])
    if (s is String) s,
];
