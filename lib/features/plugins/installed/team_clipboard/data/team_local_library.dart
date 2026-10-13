import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../team_clipboard_models.dart';
import '../team_file_check.dart';
import '../team_library_models.dart';

/// The assets library's "on this device" half: mods any team member picks
/// for themselves. They are downloaded from Modrinth and unpacked on this
/// device, kept under `<app support>/team_clipboard/library/`, and never
/// sent to the luma server or shown to anyone else. The team's shared
/// library, which only a lead fills, is a separate list on the server.
///
/// It works the way the server's library does (`server/lib/team_library.dart`):
/// only `assets/**` and `data/**` .png/.json/.mcmeta files are kept, each one
/// passing the board's upload check, stored by SHA-1 with no extension. With
/// no server to watch Modrinth, a mod is checked for a new version when the
/// tab opens and every [checkEvery] while it stays open.

/// How many mods one device keeps.
const kTeamLocalMaxMods = 50;

/// The biggest jar this device downloads.
const kTeamLocalMaxJarBytes = 200 * 1024 * 1024;

/// What one mod's kept assets may add up to, and how many there may be.
const kTeamLocalMaxModBytes = 256 * 1024 * 1024;
const kTeamLocalMaxModFiles = 40000;

/// Versions a mod remembers having been unpacked at.
const kTeamLocalHistory = 10;

const _projectTypes = ['mod', 'resourcepack'];
const _knownLoaders = {
  'fabric',
  'forge',
  'neoforge',
  'quilt',
  'liteloader',
  'rift',
  'minecraft',
};

final RegExp _projectIdPattern = RegExp(r'^[A-Za-z0-9]{8}$');
final RegExp _sha1Pattern = RegExp(r'^[a-f0-9]{40}$');
final RegExp _assetPathPattern = RegExp(
  r'^(assets|data)/[a-z0-9_.\-]+/[A-Za-z0-9_.\-/]+\.(png|json|mcmeta)$',
);

class TeamLocalLibraryException implements Exception {
  TeamLocalLibraryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Where the local library reads Modrinth from. Tests swap in a fake.
abstract class TeamLocalLibrarySource {
  /// `GET https://api.modrinth.com/v2<path>` decoded, or null on a 404.
  Future<Object?> getJson(String path, [Map<String, String>? query]);

  /// Writes the file at [url] to [to]. False when it is gone or bigger
  /// than [maxBytes].
  Future<bool> download(Uri url, File to, int maxBytes);
}

/// Modrinth's public API, straight from this device. Downloads only come
/// from its CDN over HTTPS.
class ModrinthLocalLibrarySource implements TeamLocalLibrarySource {
  ModrinthLocalLibrarySource({http.Client? client}) : _injected = client;

  final http.Client? _injected;
  late final http.Client _client = _injected ?? http.Client();

  static const _api = 'https://api.modrinth.com/v2';
  static const _headers = {
    'User-Agent': 'luma/team-library (github.com/Hyperlinkhyper1/luma-app)',
  };

  @override
  Future<Object?> getJson(String path, [Map<String, String>? query]) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('$_api$path').replace(queryParameters: query),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw TeamLocalLibraryException('Modrinth could not be reached.');
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw TeamLocalLibraryException(
        'Modrinth answered HTTP ${response.statusCode}.',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  @override
  Future<bool> download(Uri url, File to, int maxBytes) async {
    if (!_isModrinthCdn(url)) return false;
    IOSink? sink;
    try {
      final request = http.Request('GET', url)..headers.addAll(_headers);
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return false;
      sink = to.openWrite();
      var total = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 120),
      )) {
        total += chunk.length;
        if (total > maxBytes) return false;
        sink.add(chunk);
      }
      await sink.flush();
      return true;
    } catch (_) {
      return false;
    } finally {
      await sink?.close();
    }
  }
}

bool _isModrinthCdn(Uri url) =>
    url.scheme == 'https' && url.host == 'cdn.modrinth.com';

class TeamLocalLibrary {
  TeamLocalLibrary({
    Future<Directory?> Function()? directory,
    TeamLocalLibrarySource? source,
    this.checkEvery = const Duration(minutes: 30),
  }) : _directory = directory ?? _defaultDirectory,
       source = source ?? ModrinthLocalLibrarySource();

  final Future<Directory?> Function() _directory;
  TeamLocalLibrarySource source;
  final Duration checkEvery;

  static Future<Directory?> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/team_clipboard/library');
  }

  /// Mods in the order they were added, in the shape the server's library
  /// answers with, so the tab reads both the same way.
  final List<Map<String, dynamic>> _mods = [];
  int _revision = 0;
  String? _dir;
  Future<void>? _opening;

  final Set<String> _queue = {};
  final Set<String> _forced = {};
  bool _working = false;
  bool _gcWanted = false;
  Completer<void>? _idle;

  bool get busy => _working || _queue.isNotEmpty;

  String get _libraryPath => '$_dir/library.json';
  String _indexPath(String id) => '$_dir/index/$id.json';
  String _blobPath(String sha1) => '$_dir/blobs/$sha1';

  Future<void> _open() => _opening ??= () async {
    Directory? dir;
    try {
      dir = await _directory();
    } catch (_) {
      dir = null;
    }
    if (dir == null) {
      throw TeamLocalLibraryException('This device has nowhere to keep mods.');
    }
    _dir = dir.path;
    try {
      final file = File(_libraryPath);
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _revision = decoded['revision'] as int? ?? 0;
          for (final raw in decoded['mods'] as List? ?? const []) {
            if (raw is Map<String, dynamic> &&
                raw['id'] is String &&
                _projectIdPattern.hasMatch(raw['id'] as String)) {
              _mods.add(raw);
            }
          }
        }
      }
    } catch (_) {}
    for (final mod in _mods) {
      if (mod['state'] == 'queued' || mod['state'] == 'loading') {
        _enqueue(mod['id'] as String, force: true);
      }
    }
  }();

  Map<String, dynamic>? _mod(String id) =>
      _mods.where((m) => m['id'] == id).firstOrNull;

  TeamLibraryState _state({int? since}) => TeamLibraryState.fromJson({
    'revision': _revision,
    'canManage': true,
    'busy': busy,
    if (since == _revision)
      'unchanged': true
    else
      'mods': [for (final m in _mods) Map<String, dynamic>.of(m)],
  });

  Future<void> _changed() async {
    _revision++;
    try {
      await Directory(_dir!).create(recursive: true);
      await _writeString(
        _libraryPath,
        jsonEncode({'revision': _revision, 'mods': _mods}),
      );
    } catch (_) {}
  }

  /// The mods on this device, or [TeamLibraryState.mods] null when nothing
  /// changed since [since].
  Future<TeamLibraryState> state({int? since}) async {
    await _open();
    return _state(since: since);
  }

  /// Checks every mod not checked within [checkEvery].
  Future<void> checkStale() async {
    await _open();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final mod in _mods) {
      final at = mod['checkedAtMs'] as int? ?? 0;
      if (now - at >= checkEvery.inMilliseconds) _enqueue(mod['id'] as String);
    }
  }

  Future<List<TeamLibraryHit>> search(String query) async {
    final body = await source.getJson('/search', {
      'query': query,
      'limit': '20',
      'index': query.trim().isEmpty ? 'downloads' : 'relevance',
      'facets': jsonEncode([
        ['project_type:mod', 'project_type:resourcepack'],
      ]),
    });
    final hits = body is Map ? body['hits'] : null;
    return [
      for (final raw in hits is List ? hits : const [])
        if (raw is Map &&
            raw['project_id'] is String &&
            _projectTypes.contains(raw['project_type'] ?? 'mod'))
          TeamLibraryHit.fromJson({
            'id': raw['project_id'],
            'title': raw['title'] as String? ?? '',
            'description': raw['description'] as String? ?? '',
            'iconUrl': _httpsUrl(raw['icon_url']),
            'author': raw['author'] as String? ?? '',
            'downloads': (raw['downloads'] as num?)?.toInt() ?? 0,
            'projectType': raw['project_type'] ?? 'mod',
            'loaders': [
              for (final c in _strings(raw['categories']))
                if (_knownLoaders.contains(c)) c,
            ],
            'gameVersions': _strings(raw['versions']).reversed.toList(),
          }),
    ];
  }

  /// Adds a Modrinth project to this device and starts unpacking it.
  Future<TeamLibraryState> add(
    String projectId, {
    String? loader,
    String? gameVersion,
  }) async {
    await _open();
    if (_mods.length >= kTeamLocalMaxMods) {
      throw TeamLocalLibraryException(
        'This device holds at most $kTeamLocalMaxMods mods.',
      );
    }
    final project = await source.getJson('/project/$projectId');
    final id = project is Map ? project['id'] : null;
    if (id is! String || !_projectIdPattern.hasMatch(id)) {
      throw TeamLocalLibraryException('Modrinth has no such project.');
    }
    if (!_projectTypes.contains((project as Map)['project_type'])) {
      throw TeamLocalLibraryException(
        'Only mods and resource packs have assets.',
      );
    }
    if (_mod(id) != null) {
      throw TeamLocalLibraryException('That mod is already on this device.');
    }
    final mod = <String, dynamic>{
      'id': id,
      'addedBy': '',
      'loader': loader,
      'gameVersion': gameVersion,
      'state': 'queued',
      'history': <Object>[],
    };
    _applyProject(mod, project);
    _mods.add(mod);
    await _changed();
    _enqueue(id, force: true);
    return _state();
  }

  /// Changes which versions count for [projectId] and checks it again.
  Future<TeamLibraryState> setFilters(
    String projectId, {
    String? loader,
    String? gameVersion,
  }) async {
    await _open();
    final mod = _mod(projectId);
    if (mod != null &&
        (mod['loader'] != loader || mod['gameVersion'] != gameVersion)) {
      mod
        ..['loader'] = loader
        ..['gameVersion'] = gameVersion;
      await _changed();
      _enqueue(projectId);
    }
    return _state();
  }

  /// Drops [projectId] and, once nothing else uses them, its files.
  Future<TeamLibraryState> remove(String projectId) async {
    await _open();
    final mod = _mod(projectId);
    if (mod != null) {
      _mods.remove(mod);
      _queue.remove(projectId);
      await _changed();
      try {
        final index = File(_indexPath(projectId));
        if (await index.exists()) await index.delete();
      } catch (_) {}
      _gcWanted = true;
      _kick();
    }
    return _state();
  }

  /// Asks Modrinth about [projectId] (or every mod) now.
  Future<TeamLibraryState> check([String? projectId]) async {
    await _open();
    for (final mod in _mods) {
      if (projectId == null || mod['id'] == projectId) {
        _enqueue(mod['id'] as String);
      }
    }
    return _state();
  }

  /// [projectId]'s file list for the version this device holds.
  Future<TeamLibraryIndex> files(String projectId, {DateTime? loadedAt}) async {
    await _open();
    final file = File(_indexPath(projectId));
    if (!_projectIdPattern.hasMatch(projectId) || !await file.exists()) {
      throw TeamLocalLibraryException('This mod has not been unpacked yet.');
    }
    final decoded = jsonDecode(await file.readAsString());
    return TeamLibraryIndex.fromJson(
      decoded as Map<String, dynamic>,
      loadedAt: loadedAt,
      local: true,
    );
  }

  /// A file this device unpacked, by its SHA-1.
  Future<Uint8List?> blob(String sha1) async {
    if (!_sha1Pattern.hasMatch(sha1)) return null;
    try {
      await _open();
      final file = File(_blobPath(sha1));
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Resolves once nothing is queued or running. For tests.
  Future<void> settle() {
    if (!busy && !_gcWanted) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }

  void _enqueue(String id, {bool force = false}) {
    if (force) _forced.add(id);
    _queue.add(id);
    _kick();
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
            final mod = _mod(id);
            if (mod != null) await _fail(mod, '$e');
          }
        } else {
          _gcWanted = false;
          await _collectGarbage();
        }
      }
    } finally {
      _working = false;
      // The tab polls by revision; moving it on lets it see "busy" end.
      _revision++;
      final idle = _idle;
      _idle = null;
      idle?.complete();
    }
  }

  Future<void> _fail(Map<String, dynamic> mod, String message) async {
    mod
      ..['state'] = mod['version'] == null ? 'failed' : 'ready'
      ..['error'] = message
      ..['checkedAtMs'] = DateTime.now().millisecondsSinceEpoch;
    await _changed();
  }

  static void _applyProject(Map<String, dynamic> mod, Map project) {
    final type = project['project_type'] as String? ?? 'mod';
    final slug = project['slug'] as String? ?? mod['id'] as String;
    mod
      ..['slug'] = slug
      ..['title'] = project['title'] as String? ?? slug
      ..['projectType'] = type
      ..['url'] = 'https://modrinth.com/$type/$slug'
      ..['iconUrl'] = _httpsUrl(project['icon_url'])
      ..['description'] = project['description'] as String? ?? ''
      ..['loaders'] = _strings(project['loaders'])
      ..['gameVersions'] = _strings(project['game_versions']).reversed.toList();
  }

  Future<void> _refresh(String id, {required bool force}) async {
    final mod = _mod(id);
    if (mod == null) return;
    final project = await source.getJson('/project/$id');
    if (project is! Map) return _fail(mod, 'The mod is gone from Modrinth.');
    _applyProject(mod, project);
    final loader = mod['loader'] as String?;
    final gameVersion = mod['gameVersion'] as String?;
    final versions = await source.getJson('/project/$id/version', {
      if (loader != null) 'loaders': jsonEncode([loader]),
      if (gameVersion != null) 'game_versions': jsonEncode([gameVersion]),
    });
    if (versions == null) return _fail(mod, 'The mod is gone from Modrinth.');
    final picked = _pickVersion(versions is List ? versions : const []);
    if (picked == null) {
      return _fail(
        mod,
        'Modrinth has no version for '
        '${loader ?? 'any loader'} on ${gameVersion ?? 'any game version'}.',
      );
    }
    final versionId = picked['id'] as String;
    final held = mod['version'];
    if (!force &&
        held is Map &&
        held['id'] == versionId &&
        await File(_indexPath(id)).exists()) {
      mod
        ..['state'] = 'ready'
        ..['error'] = null
        ..['checkedAtMs'] = DateTime.now().millisecondsSinceEpoch;
      return _changed();
    }

    mod['state'] = 'loading';
    await _changed();
    final file = _versionFile(picked)!;
    final url = Uri.tryParse(file['url'] as String);
    if (url == null || !_isModrinthCdn(url)) {
      return _fail(mod, 'Modrinth listed a download elsewhere.');
    }
    if (((file['size'] as num?)?.toInt() ?? 0) > kTeamLocalMaxJarBytes) {
      return _fail(
        mod,
        'The jar is over ${kTeamLocalMaxJarBytes ~/ (1024 * 1024)} MB.',
      );
    }
    final tmp = Directory('$_dir/tmp');
    await tmp.create(recursive: true);
    final jar = File('${tmp.path}/$id.jar');
    try {
      if (!await source.download(url, jar, kTeamLocalMaxJarBytes)) {
        return _fail(mod, 'The jar could not be downloaded.');
      }
      final hashes = file['hashes'];
      final expected = hashes is Map ? hashes['sha1'] : null;
      final blobDir = '$_dir/blobs';
      final jarPath = jar.path;
      final result = await _unpackInIsolate(
        jarPath,
        blobDir,
        expected is String ? expected.toLowerCase() : null,
      );
      if (result.error != null) return _fail(mod, result.error!);
      if (result.files.isEmpty) {
        return _fail(mod, 'The jar has no textures or models.');
      }
      await Directory('$_dir/index').create(recursive: true);
      await _writeString(
        _indexPath(id),
        jsonEncode({'versionId': versionId, 'files': result.files}),
      );
      if (_mod(id) == null) {
        try {
          await File(_indexPath(id)).delete();
        } catch (_) {}
        _gcWanted = true;
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      if (held is Map && held['id'] != versionId) {
        final history = (mod['history'] as List? ?? [])
          ..insert(0, {
            'id': held['id'],
            'number': held['number'],
            'loadedAtMs': mod['loadedAtMs'] ?? 0,
          });
        if (history.length > kTeamLocalHistory) {
          history.removeRange(kTeamLocalHistory, history.length);
        }
        mod['history'] = history;
      }
      mod
        ..['version'] = {
          'id': versionId,
          'number': picked['version_number'] as String? ?? '',
          'name': picked['name'] as String? ?? '',
          'fileName': file['filename'] as String? ?? '',
          'publishedAtMs':
              DateTime.tryParse(
                picked['date_published'] as String? ?? '',
              )?.millisecondsSinceEpoch ??
              0,
          'loaders': _strings(picked['loaders']),
          'gameVersions': _strings(picked['game_versions']),
        }
        ..['state'] = 'ready'
        ..['error'] = null
        ..['loadedAtMs'] = now
        ..['checkedAtMs'] = now
        ..['fileCount'] = result.files.length
        ..['bytes'] = result.bytes
        ..['skipped'] = result.skipped
        ..['namespaces'] = result.namespaces;
      await _changed();
      _gcWanted = true;
    } finally {
      try {
        if (await jar.exists()) await jar.delete();
      } catch (_) {}
    }
  }

  /// Deletes every blob no mod's index lists any more.
  Future<void> _collectGarbage() async {
    final live = <String>{};
    for (final mod in List.of(_mods)) {
      try {
        final file = File(_indexPath(mod['id'] as String));
        if (!await file.exists()) continue;
        final decoded = jsonDecode(await file.readAsString());
        for (final f in decoded is Map ? decoded['files'] as List : const []) {
          if (f is List && f.length >= 2 && f[1] is String) live.add(f[1]);
        }
      } catch (_) {
        return;
      }
    }
    final dir = Directory('$_dir/blobs');
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File && !live.contains(entity.uri.pathSegments.last)) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }
}

/// The newest version published that has a file to unpack.
Map<String, dynamic>? _pickVersion(List<dynamic> versions) {
  Map<String, dynamic>? best;
  var bestAt = '';
  for (final v in versions) {
    if (v is! Map<String, dynamic> || v['id'] is! String) continue;
    if (_versionFile(v) == null) continue;
    final at = v['date_published'] as String? ?? '';
    if (best == null || at.compareTo(bestAt) > 0) {
      best = v;
      bestAt = at;
    }
  }
  return best;
}

/// A version's file to unpack: its primary .jar or .zip, else its first.
Map<String, dynamic>? _versionFile(Map<String, dynamic> version) {
  final files = [
    for (final f in version['files'] as List? ?? const [])
      if (f is Map<String, dynamic> &&
          f['url'] is String &&
          RegExp(
            r'\.(jar|zip)$',
            caseSensitive: false,
          ).hasMatch(f['filename'] as String? ?? ''))
        f,
  ];
  if (files.isEmpty) return null;
  return files.where((f) => f['primary'] == true).firstOrNull ?? files.first;
}

typedef _Unpacked = ({
  String? error,
  List<List<Object>> files,
  int bytes,
  int skipped,
  List<String> namespaces,
});

/// Top-level so the isolate's closure carries nothing but its arguments.
Future<_Unpacked> _unpackInIsolate(
  String jarPath,
  String blobDir,
  String? sha1,
) => Isolate.run(() => _unpack(jarPath, blobDir, sha1));

/// Checks the jar at [jarPath] against [sha1], then writes each asset it
/// keeps to [blobDir] by its SHA-1. Runs in an isolate.
Future<_Unpacked> _unpack(String jarPath, String blobDir, String? sha1) async {
  _Unpacked failed(String error) => (
    error: error,
    files: const [],
    bytes: 0,
    skipped: 0,
    namespaces: const [],
  );
  final jar = await File(jarPath).readAsBytes();
  if (sha1 != null && sha1 != c.sha1.convert(jar).toString()) {
    return failed('The download was damaged.');
  }
  final files = <List<Object>>[];
  final namespaces = <String>{};
  final blobs = <String, Uint8List>{};
  final TeamLocalJarScan scan;
  try {
    scan = scanTeamLocalJar(jar, (path, bytes) {
      final sha = c.sha1.convert(bytes).toString();
      blobs[sha] = bytes;
      files.add([path, sha, bytes.length]);
      namespaces.add(path.split('/')[1]);
    });
  } on TeamLocalLibraryException catch (e) {
    return failed(e.message);
  }
  await Directory(blobDir).create(recursive: true);
  for (final blob in blobs.entries) {
    final target = File('$blobDir/${blob.key}');
    if (!await target.exists()) await _writeBytes(target.path, blob.value);
  }
  files.sort((a, b) => (a[0] as String).compareTo(b[0] as String));
  return (
    error: null,
    files: files,
    bytes: scan.bytes,
    skipped: scan.skipped,
    namespaces: namespaces.toList()..sort(),
  );
}

/// What [scanTeamLocalJar] kept and what it left out.
class TeamLocalJarScan {
  int kept = 0;
  int skipped = 0;
  int bytes = 0;
}

/// Walks a jar (a zip) and hands each asset the library keeps to [onAsset].
/// The same reader as the server's: only the central directory is trusted,
/// and each entry is inflated with a cap so a zip that lies about its sizes
/// stops at [kTeamMaxFileBytes].
TeamLocalJarScan scanTeamLocalJar(
  Uint8List jar,
  void Function(String path, Uint8List bytes) onAsset, {
  int maxFiles = kTeamLocalMaxModFiles,
  int maxBytes = kTeamLocalMaxModBytes,
}) {
  final data = ByteData.sublistView(jar);
  final notZip = TeamLocalLibraryException('The download is not a jar.');
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
    throw TeamLocalLibraryException('The jar is too big to unpack.');
  }
  final scan = TeamLocalJarScan();
  final seen = <String>{};
  var at = cdOffset;
  for (var n = 0; n < count; n++) {
    if (at + 46 > jar.length ||
        data.getUint32(at, Endian.little) != 0x02014b50) {
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
    if (!isTeamLocalAssetPath(name) || !seen.add(name)) continue;
    if (scan.kept >= maxFiles) {
      throw TeamLocalLibraryException(
        'The jar holds more than $maxFiles assets.',
      );
    }
    if ((flags & 1) != 0 ||
        (method != 0 && method != 8) ||
        size > kTeamMaxFileBytes ||
        local + 30 > jar.length ||
        data.getUint32(local, Endian.little) != 0x04034b50) {
      scan.skipped++;
      continue;
    }
    final start =
        local +
        30 +
        data.getUint16(local + 26, Endian.little) +
        data.getUint16(local + 28, Endian.little);
    if (start + packed > jar.length) {
      scan.skipped++;
      continue;
    }
    final body = Uint8List.sublistView(jar, start, start + packed);
    final bytes = method == 0
        ? (packed <= kTeamMaxFileBytes ? Uint8List.fromList(body) : null)
        : _inflate(body, kTeamMaxFileBytes);
    if (bytes == null ||
        teamFileStructureProblem(
              name.substring(name.lastIndexOf('/') + 1),
              bytes,
            ) !=
            null) {
      scan.skipped++;
      continue;
    }
    if (scan.bytes + bytes.length > maxBytes) {
      throw TeamLocalLibraryException(
        'The mod\'s assets add up to more than '
        '${maxBytes ~/ (1024 * 1024)} MB.',
      );
    }
    scan
      ..kept += 1
      ..bytes += bytes.length;
    onAsset(name, bytes);
  }
  return scan;
}

/// Whether [path] (inside a jar) is an asset the library keeps.
bool isTeamLocalAssetPath(String path) {
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

Uint8List? _inflate(Uint8List packed, int max) {
  final sink = _CappedSink(max);
  try {
    final input = ZLibDecoder(raw: true).startChunkedConversion(sink);
    for (var i = 0; i < packed.length; i += 16384) {
      input.add(
        Uint8List.sublistView(packed, i, math.min(i + 16384, packed.length)),
      );
    }
    input.close();
  } catch (_) {
    return null;
  }
  return sink.out.takeBytes();
}

Future<void> _writeString(String path, String text) =>
    _writeBytes(path, utf8.encode(text));

/// Writes beside [path] and renames over it, so a crash mid-write never
/// leaves half a file.
Future<void> _writeBytes(String path, List<int> bytes) async {
  final tmp = File('$path.tmp');
  await tmp.writeAsBytes(bytes, flush: true);
  await tmp.rename(path);
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
