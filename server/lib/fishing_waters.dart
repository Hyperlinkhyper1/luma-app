import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import 'util.dart';

/// One HTTP call to a Roblox web API: status code and body bytes. Tests
/// substitute one that answers without the network.
typedef RobloxFetch = Future<(int, List<int>)> Function(String method, Uri url,
    {Object? json});

/// The bridge between the Roblox game Fishing Waters and the admin
/// dashboard's Fishing Waters project.
///
/// Roblox game servers can't be called into, so every live server posts a
/// heartbeat here (`POST /api/v1/fishing-waters/heartbeat`, authenticated by
/// LUMA_FISHING_WATERS_KEY) with its players, weather and gamepass catalogue,
/// and the response carries back what the operator decided on the dashboard:
/// the weather override and the gamepass grants for the players in that
/// server. Live servers are memory-only and drop out when they stop
/// reporting; the override, grants and last-known catalogue persist in
/// `fishing_waters.json`.
class FishingWaters {
  FishingWaters(this.dataDir,
      {this.gameKey, RobloxFetch? fetch, DateTime Function()? clock})
      : _fetch = fetch ?? _httpFetch,
        _clock = clock ?? DateTime.now;

  final String dataDir;

  /// LUMA_FISHING_WATERS_KEY. Without it the game endpoint answers 404 and
  /// the dashboard shows setup steps instead of live data.
  final String? gameKey;
  final RobloxFetch _fetch;
  final DateTime Function() _clock;

  bool get configured => gameKey != null && gameKey!.isNotEmpty;

  /// How often the game is told to report. A server that misses three
  /// heartbeats in a row is treated as shut down.
  static const heartbeatSeconds = 15;
  static const _serverTtl = Duration(seconds: heartbeatSeconds * 3);
  static const _maxBody = 64 * 1024;

  /// Shown before any game server has reported its own catalogue, so the
  /// Products tab works from day one. The first heartbeat replaces them.
  static const _defaultPasses = [
    {'key': 'AutoStore', 'name': 'Auto Store', 'id': 3722004182},
  ];
  static const _defaultKinds = ['Clear', 'LightRain', 'Rain', 'Storm'];

  final Map<String, Map<String, dynamic>> _servers = {};
  final Map<int, (int, List<int>)> _avatars = {};
  bool _loaded = false;
  String? _override;
  int _overrideAt = 0;
  List<Map<String, dynamic>> _grants = [];
  List<Map<String, dynamic>> _passes =
      _defaultPasses.map((p) => Map<String, dynamic>.from(p)).toList();
  List<Map<String, dynamic>> _schedule = [];
  List<String> _kinds = List.of(_defaultKinds);

  File get _file => File('$dataDir/fishing_waters.json');
  int get _nowMs => _clock().millisecondsSinceEpoch;

  void _load() {
    if (_loaded) return;
    _loaded = true;
    try {
      if (!_file.existsSync()) return;
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is! Map) return;
      _override = decoded['override'] as String?;
      _overrideAt = (decoded['overrideAt'] as num?)?.toInt() ?? 0;
      _grants = _maps(decoded['grants']);
      final passes = _maps(decoded['passes']);
      if (passes.isNotEmpty) _passes = passes;
      _schedule = _maps(decoded['schedule']);
      final kinds = decoded['kinds'];
      if (kinds is List && kinds.isNotEmpty) {
        _kinds = kinds.whereType<String>().toList();
      }
    } catch (_) {
      // A damaged optional file must not stop the server starting; the
      // dashboard simply starts from defaults.
    }
  }

  static List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : [];

  Future<void> _save() => atomicWriteString(
      _file.path,
      jsonEncode({
        'override': _override,
        'overrideAt': _overrideAt,
        'grants': _grants,
        'passes': _passes,
        'schedule': _schedule,
        'kinds': _kinds,
      }));

  void _expireServers() {
    final cutoff = _nowMs - _serverTtl.inMilliseconds;
    _servers.removeWhere((_, s) => (s['seenAt'] as int) < cutoff);
  }

  // ---- Game endpoint -----------------------------------------------------

  Future<Response> heartbeat(Request request) async {
    if (!configured) {
      return errorResponse(404, 'not_found', 'Not found.');
    }
    final provided = request.headers['x-fishing-waters-key'] ?? '';
    if (!constantTimeEquals(utf8.encode(provided), utf8.encode(gameKey!))) {
      return errorResponse(401, 'unauthorized', 'Invalid game key.');
    }
    final body = await _readJson(request);
    if (body == null) {
      return errorResponse(400, 'bad_request', 'Expected a JSON object.');
    }
    _load();
    final jobId = _str(body['jobId'], 64);
    if (jobId.isEmpty) {
      return errorResponse(400, 'bad_request', 'jobId is required.');
    }
    if (body['closing'] == true) {
      _servers.remove(jobId);
      return jsonResponse(200, {'ok': true});
    }

    final players = <Map<String, dynamic>>[];
    for (final raw in _maps(body['players']).take(200)) {
      final userId = _int(raw['userId']);
      if (userId == null || userId <= 0) continue;
      players.add({
        'userId': userId,
        'name': _str(raw['name'], 40),
        'displayName': _str(raw['displayName'], 40),
        'joinedAt': _int(raw['joinedAt']),
        if (_num(raw['x']) case final x?) 'x': x,
        if (_num(raw['z']) case final z?) 'z': z,
      });
    }
    final weather = body['weather'] is Map
        ? Map<String, dynamic>.from(body['weather'] as Map)
        : const <String, dynamic>{};

    var changed = false;
    final passes = _maps(body['passes'])
        .take(50)
        .map((p) => {
              'key': _str(p['key'], 40),
              'name': _str(p['name'], 60),
              'id': _int(p['id']) ?? 0,
            })
        .where((p) => (p['key'] as String).isNotEmpty)
        .toList();
    if (passes.isNotEmpty && jsonEncode(passes) != jsonEncode(_passes)) {
      _passes = passes;
      changed = true;
    }
    final schedule = _maps(body['schedule'])
        .take(30)
        .map((s) => {
              'kind': _str(s['kind'], 24),
              'duration': _num(s['duration']) ?? 0,
            })
        .toList();
    if (schedule.isNotEmpty && jsonEncode(schedule) != jsonEncode(_schedule)) {
      _schedule = schedule;
      changed = true;
    }
    final kinds = body['kinds'] is List
        ? (body['kinds'] as List)
            .whereType<String>()
            .take(20)
            .map((k) => _str(k, 24))
            .toList()
        : <String>[];
    if (kinds.isNotEmpty && jsonEncode(kinds) != jsonEncode(_kinds)) {
      _kinds = kinds;
      changed = true;
    }
    if (changed) await _save();

    final now = _nowMs;
    _servers[jobId] = {
      'jobId': jobId,
      'placeVersion': _int(body['placeVersion']),
      'privateServer': body['privateServer'] == true,
      'studio': body['studio'] == true,
      'startedAt': _int(body['startedAt']),
      'seenAt': now,
      'players': players,
      'weather': {
        'kind': _str(weather['kind'], 24),
        'override': weather['override'] is String
            ? _str(weather['override'], 24)
            : null,
        'rain': _num(weather['rain']) ?? 0,
        'storm': _num(weather['storm']) ?? 0,
        'cloudCover': _num(weather['cloudCover']) ?? 0,
        'windSpeed': _num(weather['windSpeed']) ?? 0,
        'windAngle': _num(weather['windAngle']) ?? 0,
        'waveAmplitude': _num(weather['waveAmplitude']) ?? 0,
        'seed': _int(weather['seed']) ?? 1,
        'cycleElapsed': _num(weather['cycleElapsed']) ?? 0,
      },
    };
    _expireServers();

    final present = {for (final p in players) p['userId'] as int};
    final grants = <String, List<int>>{};
    for (final g in _grants) {
      final userId = g['userId'] as int;
      if (present.contains(userId)) {
        (grants[g['pass'] as String] ??= []).add(userId);
      }
    }
    return jsonResponse(200, {
      'intervalSeconds': heartbeatSeconds,
      'weatherOverride': _override,
      'weatherVersion': _overrideAt,
      'grants': grants,
    });
  }

  // ---- Admin endpoints ---------------------------------------------------

  Map<String, dynamic> stateJson() {
    _load();
    _expireServers();
    final servers = _servers.values.toList()
      ..sort((a, b) => (b['players'] as List)
          .length
          .compareTo((a['players'] as List).length));
    final grants = List.of(_grants)
      ..sort(
          (a, b) => (b['grantedAt'] as int).compareTo(a['grantedAt'] as int));
    return {
      'configured': configured,
      'now': _nowMs,
      'intervalSeconds': heartbeatSeconds,
      'servers': servers,
      'weather': {
        'override': _override,
        'setAt': _overrideAt == 0 ? null : _overrideAt,
        'kinds': _kinds,
        'schedule': _schedule,
      },
      'passes': _passes,
      'grants': grants,
    };
  }

  Future<Response> state(Request request) async =>
      jsonResponse(200, stateJson());

  Future<Response> setWeather(Request request) async {
    final body = await _readJson(request);
    if (body == null) {
      return errorResponse(400, 'bad_request', 'Expected a JSON object.');
    }
    _load();
    final raw = body['kind'];
    final kind = raw is String && raw.isNotEmpty && raw != 'Auto' ? raw : null;
    if (kind != null && !_kinds.contains(kind)) {
      return errorResponse(400, 'unknown_weather',
          'Unknown weather type. Pick one of ${_kinds.join(', ')}.');
    }
    _override = kind;
    _overrideAt = _nowMs;
    await _save();
    return jsonResponse(200, stateJson());
  }

  Future<Response> grant(Request request) async {
    final body = await _readJson(request);
    if (body == null) {
      return errorResponse(400, 'bad_request', 'Expected a JSON object.');
    }
    _load();
    final passKey = _str(body['pass'], 40);
    if (!_passes.any((p) => p['key'] == passKey)) {
      return errorResponse(400, 'unknown_pass', 'Pick a gamepass to grant.');
    }
    final query = _str(body['user'], 40).replaceFirst(RegExp(r'^@'), '');
    if (query.isEmpty) {
      return errorResponse(
          400, 'missing_user', 'Enter a Roblox username or user ID.');
    }
    final (user, error) = await _resolveUser(query);
    if (user == null) {
      return errorResponse(404, 'user_not_found', error!);
    }
    final userId = user['userId'] as int;
    if (_grants.any((g) => g['userId'] == userId && g['pass'] == passKey)) {
      return errorResponse(
          409, 'already_granted', '${user['name']} already has this gamepass.');
    }
    _grants.add({...user, 'pass': passKey, 'grantedAt': _nowMs});
    await _save();
    return jsonResponse(200, stateJson());
  }

  Future<Response> revoke(Request request) async {
    final body = await _readJson(request);
    if (body == null) {
      return errorResponse(400, 'bad_request', 'Expected a JSON object.');
    }
    _load();
    final userId = _int(body['userId']);
    final passKey = _str(body['pass'], 40);
    final before = _grants.length;
    _grants.removeWhere((g) => g['userId'] == userId && g['pass'] == passKey);
    if (_grants.length == before) {
      return errorResponse(404, 'not_found', 'That grant no longer exists.');
    }
    await _save();
    return jsonResponse(200, stateJson());
  }

  /// Roblox avatar headshots, proxied because the dashboard's CSP only loads
  /// same-origin images.
  Future<Response> avatar(Request request, String id) async {
    final userId = int.tryParse(id);
    if (userId == null || userId <= 0) {
      return errorResponse(400, 'bad_request', 'Invalid user id.');
    }
    final cached = _avatars[userId];
    if (cached != null &&
        _nowMs - cached.$1 < const Duration(hours: 6).inMilliseconds) {
      return _png(cached.$2);
    }
    try {
      final (status, body) = await _fetch(
          'GET',
          Uri.https('thumbnails.roblox.com', '/v1/users/avatar-headshot', {
            'userIds': '$userId',
            'size': '48x48',
            'format': 'Png',
          }));
      if (status != 200) throw const FormatException();
      final data = (jsonDecode(utf8.decode(body)) as Map)['data'] as List;
      final url = Uri.parse((data.first as Map)['imageUrl'] as String);
      if (url.scheme != 'https' || !url.host.endsWith('.rbxcdn.com')) {
        throw const FormatException();
      }
      final (imageStatus, image) = await _fetch('GET', url);
      if (imageStatus != 200 || image.length > 256 * 1024) {
        throw const FormatException();
      }
      if (_avatars.length > 500) _avatars.clear();
      _avatars[userId] = (_nowMs, image);
      return _png(image);
    } catch (_) {
      return errorResponse(404, 'not_found', 'No avatar.');
    }
  }

  static Response _png(List<int> bytes) =>
      Response(200, body: bytes, headers: {'Content-Type': 'image/png'});

  /// A username or numeric id → {userId, name, displayName}. Players in a
  /// live server resolve without a Roblox round trip.
  Future<(Map<String, dynamic>?, String?)> _resolveUser(String query) async {
    final id = int.tryParse(query);
    for (final server in _servers.values) {
      for (final p in server['players'] as List) {
        final player = p as Map<String, dynamic>;
        if (player['userId'] == id ||
            (player['name'] as String).toLowerCase() == query.toLowerCase()) {
          return (
            {
              'userId': player['userId'],
              'name': player['name'],
              'displayName': player['displayName'],
            },
            null
          );
        }
      }
    }
    try {
      if (id != null) {
        final (status, body) =
            await _fetch('GET', Uri.https('users.roblox.com', '/v1/users/$id'));
        if (status == 404 || status == 400) {
          return (null, 'No Roblox account has user ID $id.');
        }
        if (status != 200) throw const FormatException();
        final user = jsonDecode(utf8.decode(body)) as Map;
        return (
          {
            'userId': id,
            'name': user['name'] as String,
            'displayName': user['displayName'] as String? ?? user['name'],
          },
          null
        );
      }
      if (!RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(query)) {
        return (
          null,
          'Roblox usernames are 3–20 letters, digits or underscores.'
        );
      }
      final (status, body) = await _fetch(
          'POST', Uri.https('users.roblox.com', '/v1/usernames/users'),
          json: {
            'usernames': [query],
            'excludeBannedUsers': false,
          });
      if (status != 200) throw const FormatException();
      final data = (jsonDecode(utf8.decode(body)) as Map)['data'] as List;
      if (data.isEmpty) return (null, 'No Roblox account is called $query.');
      final user = data.first as Map;
      return (
        {
          'userId': (user['id'] as num).toInt(),
          'name': user['name'] as String,
          'displayName': user['displayName'] as String? ?? user['name'],
        },
        null
      );
    } catch (_) {
      return (
        null,
        'Roblox didn\'t answer the user lookup. Try again, or use the user ID.'
      );
    }
  }

  static Future<(int, List<int>)> _httpFetch(String method, Uri url,
      {Object? json}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.openUrl(method, url);
      request.headers.set('Accept', 'application/json');
      if (json != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(json));
      }
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 8))) {
        builder.add(chunk);
        if (builder.length > 512 * 1024) break;
      }
      return (response.statusCode, builder.takeBytes() as List<int>);
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>?> _readJson(Request request) async {
    if ((request.contentLength ?? 0) > _maxBody) return null;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request.read()) {
      builder.add(chunk);
      if (builder.length > _maxBody) return null;
    }
    try {
      final decoded = jsonDecode(utf8.decode(builder.takeBytes()));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static String _str(Object? value, int max) {
    if (value is! String) return '';
    final trimmed = value.trim();
    return trimmed.length > max ? trimmed.substring(0, max) : trimmed;
  }

  static int? _int(Object? value) =>
      value is num && value.isFinite ? value.toInt() : null;

  static num? _num(Object? value) =>
      value is num && value.isFinite ? value : null;
}
