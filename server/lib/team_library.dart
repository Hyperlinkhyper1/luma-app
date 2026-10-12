import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;

import 'team_board.dart';
import 'util.dart';

/// The Team Clipboard's assets library: the mods a team lead picked from
/// Modrinth, unpacked so the whole team can browse their textures, models,
/// blockstates, lang files and data JSON without each of them downloading
/// the jar.
///
/// The server keeps it current on its own. Every [kTeamLibraryCheckEvery]
/// it asks Modrinth for each mod's newest version (within the loader and
/// game version the lead chose) and, when one has dropped, downloads that
/// jar and unpacks it again. The old assets stay up until the new ones are
/// in, so the library never goes empty mid-update.
///
/// Only the resource files are kept: `assets/**` and `data/**` with a
/// .png, .json or .mcmeta extension, each one passing the same
/// [teamBoardFileProblem] check an upload to the board does. Class files,
/// sounds and anything else in the jar are never written to disk. Files are
/// stored by their SHA-1 with no extension, so two versions share what they
/// have in common and no path from inside a jar ever reaches the disk.

/// How many mods the library tracks at once.
const kTeamLibraryMaxMods = 50;

/// The biggest jar the server will download.
const kTeamLibraryMaxJarBytes = 200 * 1024 * 1024;

/// What one mod's kept assets may add up to, and how many there may be.
const kTeamLibraryMaxModBytes = 256 * 1024 * 1024;
const kTeamLibraryMaxModFiles = 40000;

/// Every mod's assets together, counted per mod (shared files twice). The
/// server is a home machine.
const kTeamLibraryMaxTotalBytes = 2 * 1024 * 1024 * 1024;

/// What one batch of assets may hold: how many files, and how many bytes
/// before the rest are left for the next request.
const kTeamLibraryBatchFiles = 200;
const kTeamLibraryBatchBytes = 8 * 1024 * 1024;

/// How often the server looks for new versions.
const kTeamLibraryCheckEvery = Duration(minutes: 30);

/// Versions a mod remembers having been unpacked at.
const kTeamLibraryHistory = 10;

/// The project types the library takes: both ship an `assets/` folder.
const kTeamLibraryProjectTypes = ['mod', 'resourcepack'];

final RegExp _projectIdPattern = RegExp(r'^[A-Za-z0-9]{8}$');
final RegExp _sha1Pattern = RegExp(r'^[a-f0-9]{40}$');
final RegExp _filterPattern = RegExp(r'^[A-Za-z0-9_.\-]{1,32}$');

/// A resource location the way the game spells one, as a path inside the
/// jar: `assets/<namespace>/...` or `data/<namespace>/...`.
final RegExp _assetPathPattern = RegExp(
    r'^(assets|data)/[a-z0-9_.\-]+/[A-Za-z0-9_.\-/]+\.(png|json|mcmeta)$');

bool isTeamLibraryProjectId(String id) => _projectIdPattern.hasMatch(id);
bool isTeamLibraryBlobId(String id) => _sha1Pattern.hasMatch(id);

/// A loader or game-version filter: null for "any", or a short token.
/// Returns false when [raw] is neither.
(bool, String?) cleanTeamLibraryFilter(Object? raw) {
  if (raw == null || raw == '') return (true, null);
  if (raw is! String || !_filterPattern.hasMatch(raw)) return (false, null);
  return (true, raw);
}

class TeamLibraryException implements Exception {
  TeamLibraryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One version of a mod the library has unpacked.
class TeamLibraryVersion {
  TeamLibraryVersion({
    required this.id,
    required this.number,
    required this.name,
    required this.fileName,
    required this.publishedAtMs,
    this.loaders = const [],
    this.gameVersions = const [],
  });

  final String id;
  final String number;
  final String name;
  final String fileName;
  final int publishedAtMs;
  final List<String> loaders;
  final List<String> gameVersions;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'name': name,
        'fileName': fileName,
        'publishedAtMs': publishedAtMs,
        'loaders': loaders,
        'gameVersions': gameVersions,
      };

  static TeamLibraryVersion? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String) return null;
    return TeamLibraryVersion(
      id: raw['id'] as String,
      number: raw['number'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      fileName: raw['fileName'] as String? ?? '',
      publishedAtMs: raw['publishedAtMs'] as int? ?? 0,
      loaders: _strings(raw['loaders']),
      gameVersions: _strings(raw['gameVersions']),
    );
  }
}

/// A mod in the library. [state] is `queued` or `loading` while the server
/// works on it, then `ready` or `failed`. A ready mod can still carry an
/// [error] from its last check; its assets are then the last good ones.
class TeamLibraryMod {
  TeamLibraryMod({
    required this.projectId,
    required this.slug,
    required this.title,
    required this.projectType,
    required this.addedById,
    required this.addedByEmail,
    required this.addedAtMs,
    this.iconUrl,
    this.description = '',
    this.loader,
    this.gameVersion,
    this.state = 'queued',
    this.error,
    this.version,
    this.loadedAtMs = 0,
    this.checkedAtMs = 0,
    this.fileCount = 0,
    this.bytes = 0,
    this.skipped = 0,
    List<String>? namespaces,
    List<Map<String, dynamic>>? history,
    List<String>? loaders,
    List<String>? gameVersions,
  })  : namespaces = namespaces ?? [],
        history = history ?? [],
        loaders = loaders ?? [],
        gameVersions = gameVersions ?? [];

  final String projectId;
  String slug;
  String title;
  String projectType;
  String? iconUrl;
  String description;
  final String addedById;
  String addedByEmail;
  final int addedAtMs;

  /// What the project is published for, newest game version first, so a
  /// lead can narrow [loader] and [gameVersion] down to one of them.
  List<String> loaders;
  List<String> gameVersions;

  /// Which versions count: null takes any loader or game version.
  String? loader;
  String? gameVersion;

  String state;
  String? error;
  TeamLibraryVersion? version;

  /// When the assets were last unpacked, and when Modrinth was last asked.
  int loadedAtMs;
  int checkedAtMs;
  int fileCount;
  int bytes;

  /// Asset files the jar had but the library left out: unreadable, too big
  /// or not what their extension says.
  int skipped;
  List<String> namespaces;

  /// The versions unpacked before, newest first: `{number, id, loadedAtMs}`.
  List<Map<String, dynamic>> history;

  bool get working => state == 'queued' || state == 'loading';

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'slug': slug,
        'title': title,
        'projectType': projectType,
        'iconUrl': iconUrl,
        'description': description,
        'addedById': addedById,
        'addedByEmail': addedByEmail,
        'addedAtMs': addedAtMs,
        'loaders': loaders,
        'gameVersions': gameVersions,
        'loader': loader,
        'gameVersion': gameVersion,
        'state': state,
        'error': error,
        'version': version?.toJson(),
        'loadedAtMs': loadedAtMs,
        'checkedAtMs': checkedAtMs,
        'fileCount': fileCount,
        'bytes': bytes,
        'skipped': skipped,
        'namespaces': namespaces,
        'history': history,
      };

  static TeamLibraryMod? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['projectId'];
    if (id is! String || !isTeamLibraryProjectId(id)) return null;
    return TeamLibraryMod(
      projectId: id,
      slug: raw['slug'] as String? ?? id,
      title: raw['title'] as String? ?? id,
      projectType: raw['projectType'] as String? ?? 'mod',
      iconUrl: raw['iconUrl'] as String?,
      description: raw['description'] as String? ?? '',
      addedById: raw['addedById'] as String? ?? '',
      addedByEmail: raw['addedByEmail'] as String? ?? '',
      addedAtMs: raw['addedAtMs'] as int? ?? 0,
      loaders: _strings(raw['loaders']),
      gameVersions: _strings(raw['gameVersions']),
      loader: raw['loader'] as String?,
      gameVersion: raw['gameVersion'] as String?,
      state: raw['state'] as String? ?? 'queued',
      error: raw['error'] as String?,
      version: TeamLibraryVersion.fromJson(raw['version']),
      loadedAtMs: raw['loadedAtMs'] as int? ?? 0,
      checkedAtMs: raw['checkedAtMs'] as int? ?? 0,
      fileCount: raw['fileCount'] as int? ?? 0,
      bytes: raw['bytes'] as int? ?? 0,
      skipped: raw['skipped'] as int? ?? 0,
      namespaces: _strings(raw['namespaces']),
      history: [
        for (final h in raw['history'] as List? ?? const [])
          if (h is Map) Map<String, dynamic>.from(h),
      ],
    );
  }
}

/// A project as Modrinth's search lists it, for the lead's "add a mod"
/// picker.
class TeamLibrarySearchHit {
  TeamLibrarySearchHit(this.json);
  final Map<String, dynamic> json;

  static TeamLibrarySearchHit? fromModrinth(Object? raw) {
    if (raw is! Map || raw['project_id'] is! String) return null;
    final type = raw['project_type'] as String? ?? 'mod';
    if (!kTeamLibraryProjectTypes.contains(type)) return null;
    final categories = _strings(raw['categories']);
    return TeamLibrarySearchHit({
      'id': raw['project_id'],
      'slug': raw['slug'] as String? ?? raw['project_id'],
      'title': raw['title'] as String? ?? '',
      'description': raw['description'] as String? ?? '',
      'iconUrl': _httpsUrl(raw['icon_url']),
      'author': raw['author'] as String? ?? '',
      'downloads': (raw['downloads'] as num?)?.toInt() ?? 0,
      'projectType': type,
      'loaders': [
        for (final c in categories)
          if (_knownLoaders.contains(c)) c,
      ],
      'gameVersions': _strings(raw['versions']).reversed.toList(),
    });
  }
}

const _knownLoaders = {
  'fabric',
  'forge',
  'neoforge',
  'quilt',
  'liteloader',
  'rift',
  'minecraft',
};

/// Where the library reads Modrinth from. Tests swap in a fake.
abstract class TeamLibrarySource {
  /// `GET https://api.modrinth.com/v2<path>` decoded, or null on a 404.
  /// Anything else that goes wrong throws a [TeamLibraryException].
  Future<Object?> getJson(String path, [Map<String, String>? query]);

  /// The file at [url], or null when it is gone or bigger than [maxBytes].
  Future<Uint8List?> download(Uri url, int maxBytes);
}

/// Modrinth's public API. Downloads only ever come from its CDN over
/// HTTPS: the URL comes out of an API answer, so the server never fetches
/// anything else on its say-so.
class ModrinthLibrarySource implements TeamLibrarySource {
  static const _api = 'https://api.modrinth.com/v2';
  static const _userAgent =
      'luma-server/team-library (github.com/Hyperlinkhyper1/luma-app)';

  @override
  Future<Object?> getJson(String path, [Map<String, String>? query]) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = Uri.parse('$_api$path').replace(queryParameters: query);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', _userAgent);
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw TeamLibraryException(
            'Modrinth answered HTTP ${response.statusCode}.');
      }
      return jsonDecode(text);
    } on TeamLibraryException {
      rethrow;
    } catch (_) {
      throw TeamLibraryException('Modrinth could not be reached.');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Uint8List?> download(Uri url, int maxBytes) async {
    if (!isModrinthCdn(url)) return null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(url);
      request.headers.set('User-Agent', _userAgent);
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final bytes = BytesBuilder(copy: false);
      await for (final chunk
          in response.timeout(const Duration(seconds: 120))) {
        bytes.add(chunk);
        if (bytes.length > maxBytes) return null;
      }
      return bytes.takeBytes();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

bool isModrinthCdn(Uri url) =>
    url.scheme == 'https' && url.host == 'cdn.modrinth.com';

/// Picks the version the library should hold out of Modrinth's list for a
/// project: the newest one published that has a file to unpack.
Map<String, dynamic>? pickTeamLibraryVersion(List<dynamic> versions) {
  Map<String, dynamic>? best;
  var bestAt = '';
  for (final v in versions) {
    if (v is! Map<String, dynamic> || v['id'] is! String) continue;
    if (teamLibraryVersionFile(v) == null) continue;
    final at = v['date_published'] as String? ?? '';
    if (best == null || at.compareTo(bestAt) > 0) {
      best = v;
      bestAt = at;
    }
  }
  return best;
}

/// A version's file to unpack: its primary .jar or .zip, else its first.
Map<String, dynamic>? teamLibraryVersionFile(Map<String, dynamic> version) {
  final files = [
    for (final f in version['files'] as List? ?? const [])
      if (f is Map<String, dynamic> &&
          f['url'] is String &&
          RegExp(r'\.(jar|zip)$', caseSensitive: false)
              .hasMatch(f['filename'] as String? ?? ''))
        f,
  ];
  if (files.isEmpty) return null;
  return files.where((f) => f['primary'] == true).firstOrNull ?? files.first;
}

/// What [scanTeamLibraryJar] kept and what it left out.
class TeamLibraryScan {
  int kept = 0;
  int skipped = 0;
  int bytes = 0;
}

/// Walks a jar (a zip) and hands each asset the library keeps to [onAsset].
///
/// Only the central directory is trusted for where entries are; each
/// entry is inflated with a cap, so a zip that lies about its sizes stops
/// at [kTeamBoardMaxFileBytes] rather than filling memory. Stored and
/// deflated entries are read; encrypted ones, zip64 archives and other
/// compression methods are not. Throws a [TeamLibraryException] when the
/// file isn't a zip or holds more than one mod's worth of assets.
TeamLibraryScan scanTeamLibraryJar(
  Uint8List jar,
  void Function(String path, Uint8List bytes) onAsset, {
  int maxFiles = kTeamLibraryMaxModFiles,
  int maxBytes = kTeamLibraryMaxModBytes,
}) {
  final data = ByteData.sublistView(jar);
  final notZip = TeamLibraryException('The download is not a jar.');
  var eocd = -1;
  for (var i = jar.length - 22; i >= math.max(0, jar.length - 65557); i--) {
    if (data.getUint32(i, Endian.little) == 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw notZip;
  final count = data.getUint16(eocd + 10, Endian.little);
  final cdOffset = data.getUint32(eocd + 16, Endian.little);
  if (cdOffset == 0xFFFFFFFF || count == 0xFFFF) {
    throw TeamLibraryException('The jar is too big to unpack.');
  }
  final scan = TeamLibraryScan();
  final seen = <String>{};
  var at = cdOffset;
  for (var n = 0; n < count; n++) {
    if (at + 46 > jar.length || data.getUint32(at, Endian.little) != 0x02014b50) {
      throw notZip;
    }
    final flags = data.getUint16(at + 8, Endian.little);
    final method = data.getUint16(at + 10, Endian.little);
    final packed = data.getUint32(at + 20, Endian.little);
    final size = data.getUint32(at + 24, Endian.little);
    final nameLength = data.getUint16(at + 28, Endian.little);
    final extraLength = data.getUint16(at + 30, Endian.little);
    final commentLength = data.getUint16(at + 32, Endian.little);
    final local = data.getUint32(at + 42, Endian.little);
    if (at + 46 + nameLength > jar.length) throw notZip;
    final rawName = jar.sublist(at + 46, at + 46 + nameLength);
    at += 46 + nameLength + extraLength + commentLength;

    String name;
    try {
      name = utf8.decode(rawName);
    } on FormatException {
      continue;
    }
    if (!isTeamLibraryAssetPath(name) || !seen.add(name)) continue;
    if (scan.kept >= maxFiles) {
      throw TeamLibraryException(
          'The jar holds more than $maxFiles assets; the library takes '
          'at most that many from one mod.');
    }
    if ((flags & 1) != 0 ||
        (method != 0 && method != 8) ||
        size > kTeamBoardMaxFileBytes ||
        local + 30 > jar.length ||
        data.getUint32(local, Endian.little) != 0x04034b50) {
      scan.skipped++;
      continue;
    }
    final start = local +
        30 +
        data.getUint16(local + 26, Endian.little) +
        data.getUint16(local + 28, Endian.little);
    if (start + packed > jar.length) {
      scan.skipped++;
      continue;
    }
    final body = Uint8List.sublistView(jar, start, start + packed);
    final bytes = method == 0
        ? (packed <= kTeamBoardMaxFileBytes ? Uint8List.fromList(body) : null)
        : _inflate(body, kTeamBoardMaxFileBytes);
    final slash = name.lastIndexOf('/');
    if (bytes == null ||
        teamBoardFileProblem(name.substring(slash + 1), bytes) != null) {
      scan.skipped++;
      continue;
    }
    if (scan.bytes + bytes.length > maxBytes) {
      throw TeamLibraryException(
          'The mod\'s assets add up to more than '
          '${maxBytes ~/ (1024 * 1024)} MB.');
    }
    scan
      ..kept += 1
      ..bytes += bytes.length;
    onAsset(name, bytes);
  }
  return scan;
}

/// Whether [path] (inside a jar) is an asset the library keeps.
bool isTeamLibraryAssetPath(String path) {
  if (path.length > 256 || !_assetPathPattern.hasMatch(path)) return false;
  for (final part in path.split('/')) {
    if (part.isEmpty || part == '.' || part == '..') return false;
  }
  return true;
}

class _TooBig implements Exception {}

class _CappedSink implements Sink<List<int>> {
  _CappedSink(this.max);
  final int max;
  final BytesBuilder out = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (out.length + chunk.length > max) throw _TooBig();
    out.add(chunk);
  }

  @override
  void close() {}
}

/// Inflates a raw deflate stream, giving up past [max] bytes.
Uint8List? _inflate(Uint8List packed, int max) {
  final sink = _CappedSink(max);
  try {
    final input = ZLibDecoder(raw: true).startChunkedConversion(sink);
    for (var i = 0; i < packed.length; i += 16384) {
      input.add(Uint8List.sublistView(
          packed, i, math.min(i + 16384, packed.length)));
    }
    input.close();
  } catch (_) {
    return null;
  }
  return sink.out.takeBytes();
}

/// The library on disk, under `team_board/library/`: `library.json` with
/// every mod and the [revision] the app polls on, `index/<projectId>.json`
/// with each mod's file list, and `blobs/<sha1>` with the files themselves.
class TeamLibraryStore {
  TeamLibraryStore(String dataDir, {TeamLibrarySource? source})
      : _dir = '$dataDir/team_board/library',
        source = source ?? ModrinthLibrarySource() {
    try {
      final file = File(_libraryPath);
      if (file.existsSync()) {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map) {
          revision = decoded['revision'] as int? ?? 0;
          for (final raw in decoded['mods'] as List? ?? const []) {
            final mod = TeamLibraryMod.fromJson(raw);
            if (mod != null) _mods[mod.projectId] = mod;
          }
        }
      }
    } catch (_) {}
  }

  final String _dir;
  TeamLibrarySource source;

  final AsyncLock _lock = AsyncLock();
  final Map<String, TeamLibraryMod> _mods = {};
  int revision = 0;

  final Set<String> _queue = {};
  final Set<String> _forced = {};
  bool _working = false;
  bool _gcWanted = false;
  Completer<void>? _idle;
  Timer? _timer;
  Timer? _firstCheck;

  String get _libraryPath => '$_dir/library.json';
  String _indexPath(String projectId) => '$_dir/index/$projectId.json';
  String _blobPath(String sha1) => '$_dir/blobs/$sha1';

  List<TeamLibraryMod> get mods => _mods.values.toList();
  TeamLibraryMod? mod(String projectId) => _mods[projectId];

  /// Whether the server is checking or unpacking anything right now.
  bool get busy => _working || _queue.isNotEmpty;

  /// Looks for new versions every [kTeamLibraryCheckEvery], starting a
  /// minute after the server comes up. A mod the server was unpacking when
  /// it stopped is picked up again.
  void start() {
    for (final mod in _mods.values) {
      if (mod.working) _enqueue(mod.projectId, force: true);
    }
    _firstCheck = Timer(const Duration(minutes: 1), checkAll);
    _timer = Timer.periodic(kTeamLibraryCheckEvery, (_) => checkAll());
  }

  void stop() {
    _firstCheck?.cancel();
    _timer?.cancel();
  }

  /// Runs [change] alone, then bumps [revision] and saves the library.
  Future<T> mutate<T>(T Function() change) => _lock.synchronized(() async {
        final result = change();
        revision++;
        await _save();
        return result;
      });

  Future<void> _save() async {
    await Directory(_dir).create(recursive: true);
    await atomicWriteString(
        _libraryPath,
        jsonEncode({
          'revision': revision,
          'mods': _mods.values.map((m) => m.toJson()).toList(),
        }));
  }

  /// Searches Modrinth for mods and resource packs to add.
  Future<List<TeamLibrarySearchHit>> search(String query) async {
    final facets = jsonEncode([
      ['project_type:mod', 'project_type:resourcepack'],
    ]);
    final body = await source.getJson('/search', {
      'query': query,
      'limit': '20',
      'index': query.trim().isEmpty ? 'downloads' : 'relevance',
      'facets': facets,
    });
    final hits = body is Map ? body['hits'] : null;
    return [
      for (final h in hits is List ? hits : const [])
        if (TeamLibrarySearchHit.fromModrinth(h) case final hit?) hit,
    ];
  }

  /// Adds a Modrinth project and starts unpacking it.
  Future<TeamLibraryMod> add({
    required String projectId,
    required String? loader,
    required String? gameVersion,
    required String userId,
    required String email,
  }) async {
    if (_mods.length >= kTeamLibraryMaxMods) {
      throw TeamLibraryException(
          'The library holds at most $kTeamLibraryMaxMods mods.');
    }
    final project = await source.getJson('/project/$projectId');
    if (project is! Map || project['id'] is! String) {
      throw TeamLibraryException('Modrinth has no such project.');
    }
    final id = project['id'] as String;
    final type = project['project_type'] as String? ?? '';
    if (!isTeamLibraryProjectId(id)) {
      throw TeamLibraryException('Modrinth has no such project.');
    }
    if (!kTeamLibraryProjectTypes.contains(type)) {
      throw TeamLibraryException('Only mods and resource packs have assets.');
    }
    final mod = TeamLibraryMod(
      projectId: id,
      slug: id,
      title: id,
      projectType: type,
      addedById: userId,
      addedByEmail: email,
      addedAtMs: DateTime.now().millisecondsSinceEpoch,
      loader: loader,
      gameVersion: gameVersion,
    );
    _applyProject(mod, project);
    final added = await mutate(() {
      if (_mods.containsKey(id)) return false;
      _mods[id] = mod;
      return true;
    });
    if (!added) {
      throw TeamLibraryException('That mod is already in the library.');
    }
    _enqueue(id, force: true);
    return mod;
  }

  /// Changes which versions count for [projectId] and checks it again.
  Future<void> setFilters(
      String projectId, String? loader, String? gameVersion) async {
    final mod = _mods[projectId];
    if (mod == null) return;
    final changed = mod.loader != loader || mod.gameVersion != gameVersion;
    await mutate(() {
      mod
        ..loader = loader
        ..gameVersion = gameVersion;
    });
    if (changed) _enqueue(projectId);
  }

  /// Drops [projectId] and, once nothing else uses them, its files.
  Future<bool> remove(String projectId) async {
    final removed =
        await mutate(() => _mods.remove(projectId) != null);
    if (!removed) return false;
    _queue.remove(projectId);
    try {
      final index = File(_indexPath(projectId));
      if (await index.exists()) await index.delete();
    } catch (_) {}
    _gcWanted = true;
    _kick();
    return true;
  }

  /// Asks Modrinth about [projectId] (or every mod) now, rather than at the
  /// next scheduled check.
  void check([String? projectId]) {
    if (projectId != null) {
      if (_mods.containsKey(projectId)) _enqueue(projectId);
      return;
    }
    checkAll();
  }

  void checkAll() {
    for (final id in _mods.keys) {
      _enqueue(id);
    }
  }

  void _enqueue(String projectId, {bool force = false}) {
    if (force) _forced.add(projectId);
    _queue.add(projectId);
    _kick();
  }

  /// Resolves once nothing is queued or running. For tests.
  Future<void> settle() {
    if (!busy && !_gcWanted) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }

  void _kick() {
    if (_working) return;
    _working = true;
    unawaited(_work());
  }

  Future<void> _work() async {
    try {
      while (_queue.isNotEmpty || _gcWanted) {
        if (_queue.isNotEmpty) {
          final id = _queue.first;
          _queue.remove(id);
          final force = _forced.remove(id);
          try {
            await _refresh(id, force: force);
          } catch (e) {
            final mod = _mods[id];
            if (mod != null) {
              await mutate(() => _fail(mod, '$e'));
            }
          }
        } else {
          _gcWanted = false;
          await _collectGarbage();
        }
      }
    } finally {
      _working = false;
      final idle = _idle;
      _idle = null;
      idle?.complete();
    }
  }

  /// Marks a check as failed. A mod with assets keeps them and shows the
  /// error beside them.
  void _fail(TeamLibraryMod mod, String message) {
    mod
      ..state = mod.version == null ? 'failed' : 'ready'
      ..error = message
      ..checkedAtMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// Takes the project's current name, icon and what it is published for.
  static void _applyProject(TeamLibraryMod mod, Map<dynamic, dynamic> project) {
    mod
      ..slug = project['slug'] as String? ?? mod.slug
      ..title = project['title'] as String? ?? mod.title
      ..iconUrl = _httpsUrl(project['icon_url'])
      ..description = project['description'] as String? ?? mod.description
      ..loaders = _strings(project['loaders'])
      ..gameVersions = _strings(project['game_versions']).reversed.toList();
  }

  Future<void> _refresh(String projectId, {required bool force}) async {
    final mod = _mods[projectId];
    if (mod == null) return;
    final project = await source.getJson('/project/$projectId');
    if (project is! Map) {
      await mutate(() => _fail(mod, 'The mod is gone from Modrinth.'));
      return;
    }
    await mutate(() => _applyProject(mod, project));
    final query = <String, String>{
      if (mod.loader != null) 'loaders': jsonEncode([mod.loader]),
      if (mod.gameVersion != null)
        'game_versions': jsonEncode([mod.gameVersion]),
    };
    final versions =
        await source.getJson('/project/$projectId/version', query);
    if (versions == null) {
      await mutate(() => _fail(mod, 'The mod is gone from Modrinth.'));
      return;
    }
    final picked = pickTeamLibraryVersion(versions is List ? versions : []);
    if (picked == null) {
      await mutate(() => _fail(
          mod,
          'Modrinth has no version for '
          '${[mod.loader ?? 'any loader', mod.gameVersion ?? 'any game version'].join(' on ')}.'));
      return;
    }
    final versionId = picked['id'] as String;
    if (!force &&
        mod.version?.id == versionId &&
        await File(_indexPath(projectId)).exists()) {
      await mutate(() {
        mod
          ..state = 'ready'
          ..error = null
          ..checkedAtMs = DateTime.now().millisecondsSinceEpoch;
      });
      return;
    }

    await mutate(() => mod.state = 'loading');
    final file = teamLibraryVersionFile(picked)!;
    final url = Uri.tryParse(file['url'] as String);
    if (url == null || !isModrinthCdn(url)) {
      await mutate(() => _fail(mod, 'Modrinth listed a download elsewhere.'));
      return;
    }
    final size = (file['size'] as num?)?.toInt() ?? 0;
    if (size > kTeamLibraryMaxJarBytes) {
      await mutate(() => _fail(mod,
          'The jar is over ${kTeamLibraryMaxJarBytes ~/ (1024 * 1024)} MB.'));
      return;
    }
    final jar = await source.download(url, kTeamLibraryMaxJarBytes);
    if (jar == null) {
      await mutate(() => _fail(mod, 'The jar could not be downloaded.'));
      return;
    }
    final hashes = file['hashes'];
    final expected = hashes is Map ? hashes['sha1'] : null;
    if (expected is String &&
        expected.toLowerCase() != c.sha1.convert(jar).toString()) {
      await mutate(() => _fail(mod, 'The download was damaged.'));
      return;
    }

    final files = <List<Object>>[];
    final namespaces = <String>{};
    await Directory('$_dir/blobs').create(recursive: true);
    final blobs = <String, Uint8List>{};
    final scan = scanTeamLibraryJar(jar, (path, bytes) {
      final sha = c.sha1.convert(bytes).toString();
      blobs[sha] = bytes;
      files.add([path, sha, bytes.length]);
      namespaces.add(path.split('/')[1]);
    });
    if (files.isEmpty) {
      await mutate(() => _fail(mod, 'The jar has no textures or models.'));
      return;
    }
    final others = _mods.values
        .where((m) => m.projectId != projectId)
        .fold<int>(0, (sum, m) => sum + m.bytes);
    if (others + scan.bytes > kTeamLibraryMaxTotalBytes) {
      await mutate(() => _fail(mod, 'The library is full.'));
      return;
    }
    for (final blob in blobs.entries) {
      final target = File(_blobPath(blob.key));
      if (!await target.exists()) {
        await atomicWriteBytes(target.path, blob.value);
      }
    }
    files.sort((a, b) => (a[0] as String).compareTo(b[0] as String));
    await Directory('$_dir/index').create(recursive: true);
    await atomicWriteString(_indexPath(projectId),
        jsonEncode({'versionId': versionId, 'files': files}));

    final now = DateTime.now().millisecondsSinceEpoch;
    final kept = await mutate(() {
      if (!_mods.containsKey(projectId)) return false;
      final before = mod.version;
      if (before != null && before.id != versionId) {
        mod.history.insert(0, {
          'id': before.id,
          'number': before.number,
          'loadedAtMs': mod.loadedAtMs,
        });
        if (mod.history.length > kTeamLibraryHistory) {
          mod.history.removeRange(kTeamLibraryHistory, mod.history.length);
        }
      }
      mod
        ..version = TeamLibraryVersion(
          id: versionId,
          number: picked['version_number'] as String? ?? '',
          name: picked['name'] as String? ?? '',
          fileName: file['filename'] as String? ?? '',
          publishedAtMs: DateTime.tryParse(
                      picked['date_published'] as String? ?? '')
                  ?.millisecondsSinceEpoch ??
              0,
          loaders: _strings(picked['loaders']),
          gameVersions: _strings(picked['game_versions']),
        )
        ..state = 'ready'
        ..error = null
        ..loadedAtMs = now
        ..checkedAtMs = now
        ..fileCount = files.length
        ..bytes = scan.bytes
        ..skipped = scan.skipped
        ..namespaces = (namespaces.toList()..sort());
      return true;
    });
    if (!kept) {
      try {
        await File(_indexPath(projectId)).delete();
      } catch (_) {}
    }
    _gcWanted = true;
  }

  /// Deletes every blob no mod's index lists any more.
  Future<void> _collectGarbage() async {
    final live = <String>{};
    for (final id in _mods.keys.toList()) {
      final index = await _readIndex(id);
      for (final f in index?['files'] as List? ?? const []) {
        if (f is List && f.length >= 2 && f[1] is String) live.add(f[1]);
      }
    }
    final dir = Directory('$_dir/blobs');
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is File && !live.contains(name)) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  Future<Map<String, dynamic>?> _readIndex(String projectId) async {
    try {
      final file = File(_indexPath(projectId));
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// [projectId]'s file list as stored: `{versionId, files: [[path, sha1,
  /// size], ...]}`, or null before it was first unpacked.
  Future<String?> readIndex(String projectId) async {
    if (!isTeamLibraryProjectId(projectId)) return null;
    final file = File(_indexPath(projectId));
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  Future<Uint8List?> readBlob(String sha1) async {
    if (!isTeamLibraryBlobId(sha1)) return null;
    final file = File(_blobPath(sha1));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// A deleted account's email leaves the library; the mods it added stay.
  Future<void> forgetUser(String userId) => mutate(() {
        for (final mod in _mods.values) {
          if (mod.addedById == userId) mod.addedByEmail = '';
        }
      });
}

List<String> _strings(Object? raw) => [
      for (final s in raw is List ? raw : const [])
        if (s is String) s,
    ];

String? _httpsUrl(Object? raw) {
  if (raw is! String) return null;
  final uri = Uri.tryParse(raw);
  return uri != null && uri.scheme == 'https' ? raw : null;
}
