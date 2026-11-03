import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import 'ai_mode_routing.dart';
import 'benchmark_github.dart' show GithubTransport;
import 'fish_species_file.dart';
import 'util.dart';

/// One Luau run in the isolated renderer: exit code and output.
typedef LuauRunner = Future<({int code, String stdout, String stderr})>
    Function(String source);

/// One chat-completion POST to an AI provider.
typedef AiTransport = Future<({int status, String body})> Function(
    Uri url, Map<String, String> headers, String body);

/// The admin dashboard's Fishing Waters fish library and editor.
///
/// The game keeps one module per species in `src/shared/Fish/<Id>.luau`
/// (data plus its 3D builder). This reads them straight from the game's
/// GitHub repository and writes edits back as commits on its branch, through
/// the Git Data API — the server has no checkout. Because every species is
/// its own file, edits to different fish never touch the same file and can
/// run side by side; a commit only fails when someone changed the very file
/// it edits since the edit started.
///
/// * Quick edits (rarity, odds, weights, value, seasons, conditions, pools)
///   rewrite the module's data lines and commit at once.
/// * AI edits and new species go through a job: the chosen provider writes
///   the whole module, the isolated renderer runs it under lute to build the
///   in-game model, and the operator approves the preview before it is
///   committed. A module that fails to load goes back to the model with the
///   error, twice at most.
///
/// After a commit the wiki's "Refresh fish library" flag is dropped so the
/// public wiki follows, and the approved preview is kept so the library shows
/// the new model straight away.
///
/// Needs `LUMA_FISHING_WATERS_GITHUB_TOKEN`, a fine-grained token with
/// Contents read/write on just the game repository. Reading works without
/// one for a public repository, at GitHub's anonymous rate limit.
class FishLibrary {
  FishLibrary({
    required this.dataDir,
    this.wikiDir,
    Map<String, String>? environment,
    GithubTransport? github,
    AiTransport? ai,
    LuauRunner? luau,
    this.aiKey,
    this.publicUrl = '',
    DateTime Function()? clock,
  })  : _environment = environment ?? Platform.environment,
        _github = github ?? _ioTransport,
        _ai = ai ?? _ioAi,
        _luauOverride = luau,
        _clock = clock ?? DateTime.now;

  final String dataDir;
  final String? wikiDir;
  final Map<String, String> _environment;
  final GithubTransport _github;
  final AiTransport _ai;
  final LuauRunner? _luauOverride;
  final DateTime Function() _clock;
  final String publicUrl;

  /// The operator's key for an AI provider, or null when it has none.
  final String? Function(AiUpstream upstream)? aiKey;

  static const _api = 'https://api.github.com';

  /// GitHub failures answer 424, not 502: the proxy in front of the server
  /// swaps a 502's body for its own error page, which hid the reason.
  static const _githubStatus = 424;
  static const fishDir = 'src/shared/Fish';
  static const _maxBody = 12 * 1024 * 1024;
  static const _maxImage = 8 * 1024 * 1024;
  static const _repairs = 2;

  String _env(String key, String fallback) {
    final value = _environment[key]?.trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String get _token => _env('LUMA_FISHING_WATERS_GITHUB_TOKEN', '');
  String get repo =>
      _env('LUMA_FISHING_WATERS_GITHUB_REPO', 'Hyperlinkhyper1/Roblox-Fishing-Waters');
  String get branch => _env('LUMA_FISHING_WATERS_GITHUB_BRANCH', 'master');
  bool get canCommit => _token.isNotEmpty;

  // ---- GitHub ------------------------------------------------------------

  Future<dynamic> _call(String method, String path, [Object? body]) async {
    final result = await _github(
        method,
        Uri.parse('$_api/repos/$repo$path'),
        {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'luma-fish-library',
          if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
          if (body != null) 'Content-Type': 'application/json',
        },
        body == null ? null : jsonEncode(body));
    if (result.status < 200 || result.status >= 300) {
      String message = '';
      try {
        message = (jsonDecode(result.body) as Map)['message']?.toString() ?? '';
      } catch (_) {}
      throw _GithubError(result.status, message);
    }
    return result.body.isEmpty ? null : jsonDecode(result.body);
  }

  /// Blob texts by blob SHA. Content-addressed, so entries never go stale.
  final Map<String, String> _blobs = {};
  ({String commit, Map<String, String> files, DateTime at})? _head;

  /// The branch head: its commit and every file's blob SHA. Cached briefly
  /// so the library's polling doesn't spend the rate limit.
  Future<({String commit, Map<String, String> files})> _tree(
      {bool fresh = false}) async {
    final cached = _head;
    if (!fresh &&
        cached != null &&
        _clock().difference(cached.at) < const Duration(seconds: 20)) {
      return (commit: cached.commit, files: cached.files);
    }
    final ref = await _call('GET', '/git/ref/heads/$branch') as Map;
    final commit = (ref['object'] as Map)['sha'] as String;
    final tree =
        await _call('GET', '/git/trees/$commit?recursive=1') as Map;
    final files = <String, String>{
      for (final item in (tree['tree'] as List).whereType<Map>())
        if (item['type'] == 'blob') item['path'] as String: item['sha'] as String,
    };
    _commitOf[files] = commit;
    _head = (commit: commit, files: files, at: _clock());
    return (commit: commit, files: files);
  }

  /// Which commit a [_tree] file map belongs to, for raw downloads.
  final Expando<String> _commitOf = Expando();

  /// One file's text, cached by blob SHA. Without a token it comes from
  /// raw.githubusercontent.com, which doesn't count against the anonymous
  /// API limit of 60 calls an hour — and one library load reads every species.
  Future<String> _blob(Map<String, String> files, String path) async {
    final sha = files[path]!;
    final cached = _blobs[sha];
    if (cached != null) return cached;
    final commit = _commitOf[files];
    final String text;
    if (_token.isEmpty && commit != null) {
      final result = await _github(
          'GET',
          Uri.parse('https://raw.githubusercontent.com/$repo/$commit/'
              '${path.split('/').map(Uri.encodeComponent).join('/')}'),
          {'User-Agent': 'luma-fish-library'},
          null);
      if (result.status != 200) throw _GithubError(result.status, '');
      text = result.body;
    } else {
      final blob = await _call('GET', '/git/blobs/$sha') as Map;
      text = utf8.decode(
          base64.decode((blob['content'] as String).replaceAll('\n', '')));
    }
    if (_blobs.length > 2000) _blobs.clear();
    return _blobs[sha] = text;
  }

  Future<String?> _file(Map<String, String> files, String path) async =>
      files.containsKey(path) ? _blob(files, path) : null;

  final AsyncLock _commitLock = AsyncLock();

  /// Commits [changes] (path → new text) on the branch as one commit.
  /// [expected] holds each path's blob SHA when the edit started (null: the
  /// file must not exist yet); a path changed since then is a conflict.
  /// Other files may have moved on — the commit is rebuilt on the new head.
  Future<({String sha, String url})> _commit(Map<String, String> changes,
      Map<String, String?> expected, String message) {
    return _commitLock.synchronized(() async {
      for (var attempt = 0;; attempt++) {
        final head = await _tree(fresh: true);
        for (final path in changes.keys) {
          if (head.files[path] != expected[path]) {
            throw _Conflict(path, created: expected[path] == null);
          }
        }
        final commit = await _call('GET', '/git/commits/${head.commit}') as Map;
        final baseTree = (commit['tree'] as Map)['sha'] as String;
        final entries = <Map<String, dynamic>>[];
        for (final change in changes.entries) {
          final blob = await _call('POST', '/git/blobs',
              {'content': change.value, 'encoding': 'utf-8'}) as Map;
          entries.add({
            'path': change.key,
            'mode': '100644',
            'type': 'blob',
            'sha': blob['sha'],
          });
        }
        final tree = await _call(
            'POST', '/git/trees', {'base_tree': baseTree, 'tree': entries}) as Map;
        final created = await _call('POST', '/git/commits', {
          'message': message,
          'tree': tree['sha'],
          'parents': [head.commit],
        }) as Map;
        try {
          await _call('PATCH', '/git/refs/heads/$branch',
              {'sha': created['sha'], 'force': false});
        } on _GithubError catch (e) {
          // Someone pushed in between: rebuild on the new head.
          if (e.status == 422 && attempt < 3) continue;
          rethrow;
        }
        _head = null;
        for (final change in changes.entries) {
          final sha = (entries.firstWhere((e) => e['path'] == change.key))['sha'];
          _blobs[sha as String] = change.value;
        }
        return (
          sha: created['sha'] as String,
          url: 'https://github.com/$repo/commit/${created['sha']}',
        );
      }
    });
  }

  // ---- Library -----------------------------------------------------------

  static final _poolLine = RegExp(
      r'^\t(\w+) = \{ Name = "([^"]+)", Area = "(\w+)"(, Inherits = "(\w+)")?',
      multiLine: true);

  /// AnglerCatalog's pools: id, name, area and what it inherits.
  Future<List<Map<String, dynamic>>> _pools(Map<String, String> files) async {
    final catalog = await _file(files, 'src/shared/AnglerCatalog.luau') ?? '';
    return [
      for (final m in _poolLine.allMatches(catalog))
        {
          'id': m[1],
          'name': m[2],
          'area': m[3],
          if (m[5] != null) 'inherits': m[5],
        },
    ];
  }

  Future<Map<String, FishSpeciesFile>> _species(
      Map<String, String> files) async {
    final paths = files.keys
        .where((p) => p.startsWith('$fishDir/') && p.endsWith('.luau'))
        .toList()
      ..sort();
    final texts = await Future.wait(paths.map((p) => _blob(files, p)));
    return {
      for (var i = 0; i < paths.length; i++)
        paths[i].substring(fishDir.length + 1, paths[i].length - 5):
            FishSpeciesFile(
                paths[i].substring(fishDir.length + 1, paths[i].length - 5),
                texts[i]),
    };
  }

  File _overrideModel(String slug) => File('$dataDir/fish_models/$slug.json');
  File? _wikiModel(String slug) => wikiDir == null
      ? null
      : File('$wikiDir/source/public/models/fish/$slug.json');

  Map<String, Map<String, dynamic>> _wikiPalettes() {
    final file = wikiDir == null
        ? null
        : File('$wikiDir/source/src/data/fish-catalog.json');
    if (file == null || !file.existsSync()) return {};
    try {
      final decoded = jsonDecode(file.readAsStringSync()) as Map;
      return {
        for (final s in (decoded['species'] as List).whereType<Map>())
          if (s['palette'] is Map)
            s['id'] as String: Map<String, dynamic>.from(s['palette'] as Map),
      };
    } catch (_) {
      return {};
    }
  }

  Future<Response> library(Request request) async {
    try {
      final head = await _tree(
          fresh: request.url.queryParameters['fresh'] == '1');
      final pools = await _pools(head.files);
      if (!head.files.keys.any((p) => p.startsWith('$fishDir/'))) {
        return jsonResponse(200, {
          ..._meta(head.commit),
          'pools': pools,
          'fish': <Object>[],
          'problem': 'The game on $branch still keeps every species inside '
              'AnglerCatalog.luau. Push the commit that moves them into '
              '$fishDir/ first.',
        });
      }
      final species = await _species(head.files);
      final palettes = _wikiPalettes();
      return jsonResponse(200, {
        ..._meta(head.commit),
        'pools': pools,
        'fish': [
          for (final fish in species.values)
            {
              ...fish.toJson(),
              'model': _overrideModel(fishSlug(fish.id)).existsSync() ||
                  (_wikiModel(fishSlug(fish.id))?.existsSync() ?? false),
              if (palettes[fish.id] != null) 'palette': palettes[fish.id],
            },
        ],
      });
    } on _GithubError catch (e) {
      return errorResponse(_githubStatus, 'github', e.describe(repo));
    } on SocketException {
      return errorResponse(_githubStatus, 'github', 'GitHub could not be reached.');
    }
  }

  Map<String, dynamic> _meta(String commit) => {
        'repo': repo,
        'branch': branch,
        'commit': commit,
        'canCommit': canCommit,
        'canPreview': _luauOverride != null || _rendererUrl != null,
        'conditions': {
          'weather': kFishWeather,
          'time': kFishTime,
          'place': kFishPlace,
        },
        'seasons': kFishSeasons,
        'rarities': kFishRarities,
      };

  /// The model the library shows: the last approved preview, else the
  /// wiki's export.
  Future<Response> model(Request request, String slug) async {
    if (!RegExp(r'^[a-z0-9-]{1,64}$').hasMatch(slug)) {
      return errorResponse(404, 'not_found', 'No such fish.');
    }
    for (final file in [_overrideModel(slug), _wikiModel(slug)]) {
      if (file != null && await file.exists()) {
        return Response.ok(await file.readAsBytes(), headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-store',
        });
      }
    }
    return errorResponse(404, 'not_found', 'No model exported for $slug yet.');
  }

  Future<Response> source(Request request, String id) async {
    if (!isFishId(id)) return errorResponse(404, 'not_found', 'No such fish.');
    try {
      final head = await _tree();
      final text = await _file(head.files, '$fishDir/$id.luau');
      if (text == null) return errorResponse(404, 'not_found', 'No such fish.');
      return jsonResponse(200, {'id': id, 'source': text, 'commit': head.commit});
    } on _GithubError catch (e) {
      return errorResponse(_githubStatus, 'github', e.describe(repo));
    }
  }

  // ---- Quick edits -------------------------------------------------------

  /// Rewrites data fields of one species and commits straight away.
  Future<Response> quickEdit(Request request, String id) async {
    if (!isFishId(id)) return errorResponse(404, 'not_found', 'No such fish.');
    if (!canCommit) return _noToken();
    final body = await _readJson(request);
    final raw = body?['changes'];
    if (raw is! Map || raw.isEmpty) {
      return errorResponse(400, 'bad_request', 'Send the changed fields.');
    }
    final changes = _quickChanges(Map<String, dynamic>.from(raw));
    if (changes is String) return errorResponse(400, 'invalid', changes);
    try {
      final head = await _tree(fresh: true);
      final path = '$fishDir/$id.luau';
      final text = await _file(head.files, path);
      if (text == null) return errorResponse(404, 'not_found', 'No such fish.');
      final before = FishSpeciesFile(id, text);
      final after = before.withFields(changes as Map<String, Object?>);
      final problem = after.problem(
          (await _pools(head.files)).map((p) => p['id'] as String).toSet());
      if (problem != null) return errorResponse(400, 'invalid', problem);
      if (after.source == before.source) {
        return jsonResponse(200, {'fish': after.toJson(), 'unchanged': true});
      }
      final commit = await _commit({path: after.source}, {path: head.files[path]},
          'Fish library: ${_describeChanges(before, changes)}');
      _requestWikiRefresh();
      return jsonResponse(200, {'fish': after.toJson(), 'commit': commit.url});
    } on _Conflict catch (e) {
      return errorResponse(409, 'conflict', e.describe());
    } on _GithubError catch (e) {
      return errorResponse(_githubStatus, 'github', e.describe(repo));
    }
  }

  static const _quickFields = {
    'name': 'Name',
    'rarity': 'Rarity',
    'odds': 'RarityDenominator',
    'minKg': 'MinKg',
    'averageKg': 'AverageKg',
    'maxKg': 'MaxKg',
    'value': 'BaseValue',
    'fight': 'Fight',
    'pools': 'Pools',
    'seasons': 'Seasons',
    'requires': 'Requires',
  };

  /// Field changes in module terms, or a message saying what's wrong.
  static Object _quickChanges(Map<String, dynamic> raw) {
    final out = <String, Object?>{};
    for (final entry in raw.entries) {
      final field = _quickFields[entry.key];
      if (field == null) return 'Unknown field ${entry.key}.';
      final value = entry.value;
      switch (field) {
        case 'Name':
          if (value is! String || value.trim().isEmpty || value.length > 60) {
            return 'Name must be 1–60 characters.';
          }
          out[field] = value.trim();
        case 'Rarity':
          if (value is! String || !kFishRarities.contains(value)) {
            return 'Rarity must be one of ${kFishRarities.join(', ')}.';
          }
          out[field] = value;
        case 'Pools' || 'Seasons' || 'Requires':
          if (value is! List || value.any((v) => v is! String)) {
            return '${entry.key} must be a list of names.';
          }
          final list = value.cast<String>().toSet().toList();
          if (field == 'Seasons') {
            list.sort((a, b) =>
                kFishSeasons.indexOf(a).compareTo(kFishSeasons.indexOf(b)));
            // Every season is the same as no list: all year.
            out[field] = list.length == kFishSeasons.length ? <String>[] : list;
          } else {
            out[field] = list;
          }
        default:
          if (value is! num || !value.isFinite) {
            return '${entry.key} must be a number.';
          }
          out[field] = value;
      }
    }
    return out;
  }

  static String _describeChanges(
      FishSpeciesFile before, Map<String, Object?> changes) {
    final name = before.name ?? before.id;
    final parts = changes.entries.map((e) {
      final value = e.value;
      final text = value == null || (value is List && value.isEmpty)
          ? (e.key == 'Seasons' ? 'all year' : 'none')
          : value is List
              ? value.join('+')
              : value is num
                  ? formatNumber(value)
                  : '$value';
      return '${e.key} $text';
    });
    return '$name — ${parts.join(', ')}';
  }

  Response _noToken() => errorResponse(503, 'no_token',
      'Committing needs LUMA_FISHING_WATERS_GITHUB_TOKEN in the server\'s .env: '
      'a fine-grained GitHub token with Contents read/write on $repo only.');

  void _requestWikiRefresh() {
    final dir = wikiDir;
    if (dir == null || !Directory(dir).existsSync()) return;
    try {
      File('$dir/.fish-refresh-request')
          .writeAsStringSync(_clock().toIso8601String());
    } catch (_) {}
  }

  // ---- AI jobs -----------------------------------------------------------

  final Map<String, FishJob> _jobs = {};
  bool _jobsLoaded = false;
  File get _jobsFile => File('$dataDir/fish_jobs.json');
  File _previewFile(String id) => File('$dataDir/fish_previews/$id.json');

  void _loadJobs() {
    if (_jobsLoaded) return;
    _jobsLoaded = true;
    try {
      if (!_jobsFile.existsSync()) return;
      for (final raw in (jsonDecode(_jobsFile.readAsStringSync()) as List)
          .whereType<Map>()) {
        final job = FishJob.fromJson(Map<String, dynamic>.from(raw));
        if (job.busy) {
          job.status = 'failed';
          job.error = 'The server restarted while this job was running.';
        }
        _jobs[job.id] = job;
      }
    } catch (_) {
      // A damaged job list only loses history; the library still works.
    }
  }

  Future<void> _saveJobs() async {
    final recent = _jobs.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final old in recent.skip(60)) {
      _jobs.remove(old.id);
      try {
        await _previewFile(old.id).delete();
      } catch (_) {}
    }
    await atomicWriteString(_jobsFile.path,
        jsonEncode(_jobs.values.map((j) => j.toJson()).toList()));
  }

  Future<Response> jobs(Request request) async {
    _loadJobs();
    final list = _jobs.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return jsonResponse(200, {'jobs': list.map((j) => j.summary()).toList()});
  }

  Future<Response> job(Request request, String id) async {
    _loadJobs();
    final job = _jobs[id];
    if (job == null) return errorResponse(404, 'not_found', 'No such job.');
    return jsonResponse(200, job.detail());
  }

  Future<Response> preview(Request request, String id) async {
    _loadJobs();
    final file = _previewFile(id);
    if (!_jobs.containsKey(id) || !await file.exists()) {
      return errorResponse(404, 'not_found', 'No preview for this job.');
    }
    return Response.ok(await file.readAsBytes(), headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    });
  }

  /// Starts an AI edit of an existing species or a brand new one.
  Future<Response> createJob(Request request) async {
    _loadJobs();
    if (!canCommit) return _noToken();
    final body = await _readJson(request);
    if (body == null) return errorResponse(400, 'bad_request', 'Expected JSON.');
    final mode = body['mode'];
    final upstream = AiUpstream.parse(body['provider'] as String?);
    final model = (body['model'] as String? ?? '').trim();
    final effort = (body['effort'] as String? ?? '').trim();
    final prompt = (body['prompt'] as String? ?? '').trim();
    if (mode != 'edit' && mode != 'new') {
      return errorResponse(400, 'bad_request', 'mode must be edit or new.');
    }
    if (upstream == null || (aiKey?.call(upstream) ?? '').isEmpty) {
      return errorResponse(400, 'no_provider',
          'Pick a provider the server has a key for.');
    }
    if (!RegExp(r'^[A-Za-z0-9._:/@+-]{1,200}$').hasMatch(model)) {
      return errorResponse(400, 'bad_request', 'Pick a model.');
    }
    if (!kAiReasoningEfforts.contains(effort) && effort != 'minimal' &&
        effort != 'xhigh') {
      return errorResponse(400, 'bad_request', 'Unknown effort level.');
    }
    final host = (body['host'] as String? ?? '').trim();
    if (host.isNotEmpty &&
        (upstream != AiUpstream.openrouter ||
            !RegExp(r'^[a-z0-9][a-z0-9._/-]{0,99}$').hasMatch(host))) {
      return errorResponse(400, 'bad_request', 'Unknown host.');
    }
    if (prompt.length > 8000) {
      return errorResponse(400, 'bad_request', 'The prompt is too long.');
    }
    final image = body['image'];
    if (image != null &&
        (image is! String ||
            !RegExp(r'^data:image/(png|jpeg|webp|gif);base64,[A-Za-z0-9+/=]+$')
                .hasMatch(image) ||
            image.length > _maxImage * 4 / 3 + 64)) {
      return errorResponse(400, 'bad_image',
          'The image must be a PNG, JPEG, WebP or GIF under 8 MB.');
    }

    String fishId;
    Map<String, Object?> fields = {};
    if (mode == 'edit') {
      fishId = body['fishId'] as String? ?? '';
      if (!isFishId(fishId)) return errorResponse(400, 'bad_request', 'Pick a fish.');
      if (prompt.isEmpty && image == null) {
        return errorResponse(400, 'bad_request', 'Say what to change.');
      }
    } else {
      final raw = body['fields'];
      if (raw is! Map) return errorResponse(400, 'bad_request', 'Fill in the new fish.');
      final name = (raw['name'] as String? ?? '').trim();
      final id = fishIdFromName(name);
      if (name.isEmpty || name.length > 60 || id == null) {
        return errorResponse(400, 'invalid', 'Give the fish a name (letters and digits).');
      }
      fishId = id;
      final changes = _quickChanges({
        'name': name,
        if (raw['rarity'] != null) 'rarity': raw['rarity'],
        'seasons': raw['seasons'] ?? <String>[],
        'requires': raw['requires'] ?? <String>[],
        'pools': raw['pools'] ?? <String>[],
      });
      if (changes is String) return errorResponse(400, 'invalid', changes);
      fields = changes as Map<String, Object?>;
      final conflict = conditionConflict((fields['Requires'] as List).cast());
      if (conflict != null) return errorResponse(400, 'invalid', conflict);
      if ((fields['Pools'] as List).isEmpty) {
        return errorResponse(400, 'invalid', 'Pick at least one place it bites.');
      }
    }

    final active = _jobs.values.where((j) => j.busy).length;
    if (active >= 4) {
      return errorResponse(429, 'busy', 'Four fish jobs are already running.');
    }
    final job = FishJob(
      id: _newId(),
      mode: mode as String,
      fishId: fishId,
      prompt: prompt,
      provider: upstream.name,
      model: model,
      effort: effort,
      host: host,
      fields: fields.map((k, v) => MapEntry(k, v)),
      hasImage: image != null,
      createdAt: _clock().millisecondsSinceEpoch,
    );
    if (mode == 'new' && _jobs.values.any((j) =>
        j.mode == 'new' && j.fishId == fishId && (j.busy || j.status == 'ready'))) {
      return errorResponse(409, 'duplicate',
          'A new $fishId is already being made; finish or discard that one.');
    }
    _jobs[job.id] = job;
    await _saveJobs();
    unawaited(_run(job, image as String?));
    return jsonResponse(201, job.detail());
  }

  /// Asks for changes to a job's result: the model gets its own file back
  /// with the feedback.
  Future<Response> reviseJob(Request request, String id) async {
    _loadJobs();
    final job = _jobs[id];
    if (job == null) return errorResponse(404, 'not_found', 'No such job.');
    if (job.status != 'ready' && job.status != 'failed') {
      return errorResponse(409, 'busy', 'This job is ${job.status}.');
    }
    final body = await _readJson(request);
    final feedback = (body?['prompt'] as String? ?? '').trim();
    if (feedback.isEmpty || feedback.length > 8000) {
      return errorResponse(400, 'bad_request', 'Say what to change.');
    }
    job.revisions.add(feedback);
    job.status = 'queued';
    job.error = null;
    await _saveJobs();
    unawaited(_run(job, null));
    return jsonResponse(200, job.detail());
  }

  Future<Response> discardJob(Request request, String id) async {
    _loadJobs();
    final job = _jobs[id];
    if (job == null) return errorResponse(404, 'not_found', 'No such job.');
    if (job.status == 'committed') {
      return errorResponse(409, 'committed', 'This edit is already committed.');
    }
    job.status = 'discarded';
    job.cancelled = true;
    await _saveJobs();
    return jsonResponse(200, job.detail());
  }

  /// Commits a job's previewed module to the game branch.
  Future<Response> approveJob(Request request, String id) async {
    _loadJobs();
    final job = _jobs[id];
    if (job == null) return errorResponse(404, 'not_found', 'No such job.');
    if (job.status != 'ready') {
      return errorResponse(409, 'not_ready', 'Only a finished preview can be approved.');
    }
    final path = '$fishDir/${job.fishId}.luau';
    final text = job.result;
    if (text == null) return errorResponse(409, 'not_ready', 'Nothing to commit.');
    job.status = 'committing';
    try {
      final name = FishSpeciesFile(job.fishId, text).name ?? job.fishId;
      final summary = job.prompt.isEmpty
          ? ''
          : '\n\n${job.prompt.length > 400 ? '${job.prompt.substring(0, 400)}…' : job.prompt}';
      final commit = await _commit({path: text}, {path: job.baseSha},
          '${job.mode == 'new' ? 'Add' : 'Edit'} $name (fish editor, ${job.model})$summary');
      job.status = 'committed';
      job.commitUrl = commit.url;
      final preview = _previewFile(job.id);
      if (await preview.exists()) {
        final target = _overrideModel(fishSlug(job.fishId));
        await target.parent.create(recursive: true);
        await preview.copy(target.path);
      }
      _requestWikiRefresh();
      await _saveJobs();
      return jsonResponse(200, job.detail());
    } on _Conflict catch (e) {
      job.status = 'ready';
      return errorResponse(409, 'conflict', e.describe());
    } on _GithubError catch (e) {
      job.status = 'ready';
      return errorResponse(_githubStatus, 'github', e.describe(repo));
    }
  }

  String _newId() {
    final random = Random.secure();
    return List.generate(12, (_) => random.nextInt(36).toRadixString(36)).join();
  }

  Future<void> _run(FishJob job, String? image) async {
    Future<void> stage(String status, String text) async {
      if (job.cancelled) throw const _Cancelled();
      job.status = status;
      job.stage = text;
      job.updatedAt = _clock().millisecondsSinceEpoch;
    }

    try {
      await stage('generating', 'Reading the game from GitHub…');
      final head = await _tree(fresh: true);
      final path = '$fishDir/${job.fishId}.luau';
      final current = await _file(head.files, path);
      final pools = await _pools(head.files);
      final poolIds = pools.map((p) => p['id'] as String).toSet();
      if (job.revisions.isEmpty) {
        job.baseSha = head.files[path];
        job.original = current;
      }
      if (job.mode == 'edit' && current == null) {
        throw _JobError('${job.fishId} is not in the game.');
      }
      if (job.mode == 'new' && current != null && job.revisions.isEmpty) {
        throw _JobError('${job.fishId} already exists; edit it instead.');
      }
      final context = await _context(head.files, job, pools);
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': context},
        {'role': 'user', 'content': _firstRequest(job, image)},
        if (job.result != null && job.revisions.isNotEmpty) ...[
          {'role': 'assistant', 'content': '```lua\n${job.result}\n```'},
          {'role': 'user', 'content': 'Revise it: ${job.revisions.last}'},
        ],
      ];

      for (var attempt = 0;; attempt++) {
        await stage('generating',
            attempt == 0 ? 'Writing the species module…' : 'Fixing: ${job.error ?? ''}');
        final reply = await _chat(job, messages);
        var file = FishSpeciesFile(job.fishId, _luauBlock(reply));
        if (job.fields.isNotEmpty) file = file.withFields(job.fields);
        final problem = file.problem(poolIds) ??
            (file.hasBuild ? null : 'Build is missing; every new fish needs a model.');
        String? failure = problem;
        String? previewJson;
        if (failure == null) {
          await stage('previewing', 'Building the model in the sandbox…');
          final built = await _buildPreview(head.files, file);
          failure = built.error;
          previewJson = built.json;
        }
        if (failure == null) {
          job.result = file.source;
          job.notes = _notes(reply);
          job.error = null;
          if (previewJson != null) {
            final out = _previewFile(job.id);
            await out.parent.create(recursive: true);
            await out.writeAsString(previewJson);
            job.hasPreview = true;
          }
          job.status = 'ready';
          job.stage = '';
          break;
        }
        job.error = failure;
        if (attempt >= _repairs) throw _JobError(failure);
        messages
          ..add({'role': 'assistant', 'content': reply})
          ..add({
            'role': 'user',
            'content': 'That module does not work yet:\n$failure\n\n'
                'Send the corrected complete module in one ```lua block.',
          });
      }
    } on _Cancelled {
      return;
    } on _JobError catch (e) {
      job.status = 'failed';
      job.error = e.message;
    } on _GithubError catch (e) {
      job.status = 'failed';
      job.error = e.describe(repo);
    } catch (e) {
      job.status = 'failed';
      job.error = 'Unexpected error: $e';
    }
    job.updatedAt = _clock().millisecondsSinceEpoch;
    if (job.cancelled) job.status = 'discarded';
    await _saveJobs();
  }

  Future<String> _chat(FishJob job, List<Map<String, dynamic>> messages) async {
    final upstream = AiUpstream.parse(job.provider)!;
    final key = aiKey?.call(upstream) ?? '';
    final body = <String, dynamic>{
      'model': job.model,
      'messages': messages,
      'max_tokens': 32000,
    };
    if (job.effort.isNotEmpty) {
      if (upstream == AiUpstream.openrouter) {
        body['reasoning'] =
            job.effort == 'none' ? {'enabled': false} : {'effort': job.effort};
      } else if (upstream == AiUpstream.google) {
        body['reasoning_effort'] = job.effort;
      } else if (job.effort != 'none') {
        body['reasoning_effort'] = job.effort == 'minimal' ? 'low' : job.effort;
      }
    }
    // A picked host is pinned: OpenRouter fails the call rather than
    // quietly answering from a pricier or differently quantised endpoint.
    if (upstream == AiUpstream.openrouter && job.host.isNotEmpty) {
      body['provider'] = {
        'order': [job.host],
        'allow_fallbacks': false,
      };
    }
    final result = await _ai(
        Uri.parse(upstream.endpoint),
        {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
          if (upstream == AiUpstream.openrouter) ...{
            'HTTP-Referer': publicUrl,
            'X-Title': 'luma fish editor',
          },
        },
        jsonEncode(body));
    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(result.body) as Map<String, dynamic>;
    } catch (_) {}
    if (result.status != 200 || decoded == null) {
      final error = decoded?['error'];
      final message = error is Map ? error['message'] : error;
      throw _JobError('${upstream.label} answered ${result.status}'
          '${message != null ? ': $message' : ''}.');
    }
    final usage = decoded['usage'];
    if (usage is Map) {
      job.promptTokens += (usage['prompt_tokens'] as num?)?.toInt() ?? 0;
      job.completionTokens += (usage['completion_tokens'] as num?)?.toInt() ?? 0;
      final cost = usage['cost'];
      if (cost is num) job.cost += cost.toDouble();
    }
    final choices = decoded['choices'];
    final message = choices is List && choices.isNotEmpty
        ? (choices.first as Map)['message']
        : null;
    final content = message is Map ? message['content'] : null;
    final text = content is String
        ? content
        : content is List
            ? content
                .whereType<Map>()
                .map((p) => p['text'] ?? '')
                .join()
            : '';
    if (text.trim().isEmpty) {
      throw _JobError('${upstream.label} sent back an empty answer.');
    }
    return text;
  }

  /// The module from a reply: its last ```lua block, else the whole reply
  /// when that already is a module.
  static String _luauBlock(String reply) {
    final blocks = RegExp(r'```(?:lua|luau)?[ \t]*\r?\n([\s\S]*?)```')
        .allMatches(reply)
        .map((m) => m[1]!)
        .where((b) => b.contains('return {'))
        .toList();
    final text = blocks.isNotEmpty ? blocks.last : reply;
    final start = text.indexOf('return {');
    final body = start >= 0 ? text.substring(start) : text;
    return '${body.trimRight()}\n';
  }

  /// What the model said outside its code block, for the review screen.
  static String _notes(String reply) {
    final text = reply.replaceAll(RegExp(r'```[\s\S]*?```'), '').trim();
    return text.length > 1500 ? '${text.substring(0, 1500)}…' : text;
  }

  Object _firstRequest(FishJob job, String? image) {
    final lines = <String>[];
    if (job.mode == 'edit') {
      lines.add('Edit the species module src/shared/Fish/${job.fishId}.luau '
          '(shown above as the file to edit).');
      if (job.prompt.isNotEmpty) lines.add('Change request: ${job.prompt}');
    } else {
      final f = job.fields;
      lines
        ..add('Create a new species module src/shared/Fish/${job.fishId}.luau.')
        ..add('Name: ${f['Name']}')
        ..add('Rarity: ${f['Rarity'] ?? 'your choice, balanced against the other species'}')
        ..add('Pools: ${(f['Pools'] as List).join(', ')}')
        ..add('Seasons: ${(f['Seasons'] as List).isEmpty ? 'all year (omit Seasons)' : (f['Seasons'] as List).join(', ')}')
        ..add('Requires: ${(f['Requires'] as List).isEmpty ? 'nothing (omit Requires)' : (f['Requires'] as List).join(', ')}')
        ..add('Choose RarityDenominator, weights, BaseValue, Fight and Shapes '
            'in line with existing species of the same rarity and pools, and '
            'write a detailed Build for its 3D model.')
        ..add('Rarity tiers, commonest first: '
            '${kFishRarities.where((r) => r != 'Junk' && r != 'Limited').join(', ')}. '
            'Limited is a special tier: it bites only while the dashboard has '
            'it switched on, at the chance set there, so its RarityDenominator '
            'only counts for the rarest-catch record; give it a high one.');
      if (job.prompt.isNotEmpty) lines.add('Notes from the designer: ${job.prompt}');
    }
    if (image != null) {
      lines.add('The attached image is a reference for how it should look.');
    }
    lines.add('Reply with the complete module in one ```lua block, then a '
        'short note on what you did.');
    final text = lines.join('\n');
    if (image == null) return text;
    return [
      {'type': 'text', 'text': text},
      {
        'type': 'image_url',
        'image_url': {'url': image},
      },
    ];
  }

  /// The system prompt: the module format, the Builder API, reference
  /// species and the catalogue's numbers.
  Future<String> _context(Map<String, String> files, FishJob job,
      List<Map<String, dynamic>> pools) async {
    final species = await _species(files);
    final models = await _file(files, 'src/shared/FishModels.luau') ?? '';
    final format = await _file(files, 'src/shared/FishSpecies.luau') ?? '';
    final builderStart = models.indexOf('local Builder = {}');
    final builderEnd = models.indexOf('local kit = {');
    final kitEnd = builderEnd < 0 ? -1 : models.indexOf('}\n', builderEnd);
    final builder = builderStart >= 0 && kitEnd > builderStart
        ? models.substring(builderStart, kitEnd + 2)
        : models;

    // Reference species: the one being edited, plus a few of the same rarity
    // and a plain one, so the model sees several Build styles.
    final target = species[job.fishId];
    final rarity = target?.rarity ?? job.fields['Rarity'] as String?;
    final picks = <String>{
      'Trout',
      ...species.values
          .where((s) => s.rarity == rarity && s.id != job.fishId && s.hasBuild)
          .map((s) => s.id)
          .take(2),
      'Pufferfish',
    }..removeWhere((id) => !species.containsKey(id) || id == job.fishId);

    final table = StringBuffer(
        'id | rarity | odds 1-in | min/avg/max kg | value | fight | pools | seasons | requires\n');
    for (final s in species.values) {
      final j = s.toJson();
      table.writeln('${s.id} | ${j['rarity']} | ${j['odds'] is num ? formatNumber(j['odds'] as num) : '?'} | '
          '${j['minKg']}/${j['averageKg']}/${j['maxKg']} | ${j['value']} | ${j['fight']} | '
          '${(j['pools'] as List).join('+')} | ${(j['seasons'] as List).join('+')} | '
          '${(j['requires'] as List).join('+')}');
    }

    return '''
You write species modules for the Roblox game Fishing Waters. Each species is
one Luau ModuleScript in src/shared/Fish/<Id>.luau returning a table with its
catch data and a Build function that draws its 3D model from simple parts.

## Module format (from Shared.FishSpecies)
$format

## Rules
- Reply with the COMPLETE module in a single ```lua block. Keep one data field
  per line, one tab in, exactly like the examples.
- The file may not use require, game, workspace, script, Instance, task,
  loadstring, getfenv or any other global outside: Vector3, CFrame, Color3,
  math, table, string, ipairs, pairs. Build draws only through `b` (the
  Builder below) and `kit` (rgb, v2, SCALE, FIN and the body-family helpers
  carp, eel, flatfish, sturgeon, trout, mussel, algaBlade, crab).
- Builders work in fish lengths: snout at X = +0.5, tail at X = -0.5, back
  towards +Y, sides along Z. b.random(lo, hi) is a seeded random.
- Pools may only name: ${pools.map((p) => '${p['id']} (${p['name']}${p['inherits'] != null ? ', also bites every ${p['inherits']} species' : ''})').join('; ')}.
- Requires keys: Rain, Clear, Storm, Supercell, BlackHole (weather; any one
  listed will do), Day, Night (time), Beach (sandy shallows). Every non-weather
  key must hold. Never Day with Night.
- Keep MinKg ≤ AverageKg ≤ MaxKg. Shapes lists Normal, Big and Huge cargo
  footprints ("#" fills a cell); bigger fish take more cells.
- Prefer a model with real detail (countershaded body, fins, eyes, markings)
  matching the species, like the examples.

## The Builder (from Shared.FishModels)
```lua
$builder
```

## Reference species
${picks.map((id) => '### $id\n```lua\n${species[id]!.source.trimRight()}\n```').join('\n\n')}
${target != null ? '\n## The file to edit: src/shared/Fish/${job.fishId}.luau\n```lua\n${target.source.trimRight()}\n```\n' : ''}
## Every species now in the game
$table''';
  }

  // ---- Previews ----------------------------------------------------------

  String? get _rendererUrl {
    final url = _environment['LUMA_RENDERER_URL']?.trim() ?? '';
    return url.isEmpty ? null : url.replaceAll(RegExp(r'/+$'), '');
  }

  Future<({int code, String stdout, String stderr})> _runLuau(String source) {
    final runner = _luauOverride;
    if (runner != null) return runner(source);
    final url = _rendererUrl;
    if (url == null) {
      throw _JobError('Previews need the isolated renderer (LUMA_RENDERER_URL).');
    }
    return _postRenderer('$url/luau', source);
  }

  static Future<({int code, String stdout, String stderr})> _postRenderer(
      String url, String source) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(url));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'source': source}));
      final response = await request.close().timeout(const Duration(minutes: 3));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw _JobError('The renderer answered ${response.statusCode}.');
      }
      final decoded = jsonDecode(body) as Map;
      return (
        code: (decoded['code'] as num).toInt(),
        stdout: decoded['stdout'] as String? ?? '',
        stderr: decoded['stderr'] as String? ?? '',
      );
    } on SocketException {
      throw _JobError('The renderer could not be reached.');
    } on TimeoutException {
      throw _JobError('Building the model took too long.');
    } finally {
      client.close(force: true);
    }
  }

  /// Runs [file] through the game's own AnglerCatalog and FishModels in the
  /// sandbox and returns the model in the wiki's file format, or what broke.
  Future<({String? json, String? error})> _buildPreview(
      Map<String, String> files, FishSpeciesFile file) async {
    final mockDir = wikiDir == null ? null : '$wikiDir/source/scripts/fish-models';
    final mock = mockDir == null ? null : File('$mockDir/roblox-mock.luau');
    final export = mockDir == null ? null : File('$mockDir/export.luau');
    if (mock == null || !mock.existsSync() || !export!.existsSync()) {
      throw _JobError('Previews need the wiki source (its Roblox mock and model '
          'exporter in scripts/fish-models).');
    }
    String read(String? text) => (text ?? '').replaceAll('\r\n', '\n');
    String withSpecies(String text) =>
        text.replaceFirst('require(script.Parent.FishSpecies)', 'FishSpecies');
    final mutations = read(await _file(files, 'src/shared/FishMutations.luau'));
    final models = withSpecies(read(await _file(files, 'src/shared/FishModels.luau')))
        .replaceFirst('require(script.Parent.FishMutations)', 'FishMutations');
    final catalog = withSpecies(read(await _file(files, 'src/shared/AnglerCatalog.luau')));
    final id = file.id;
    final bundle = [
      read(await mock.readAsString()),
      'local FishSpecies = { ["$id"] = (function()\n${read(file.source)}\nend)() }',
      'local FishMutations = (function()\n$mutations\nend)()',
      'local FishModels = (function()\n$models\nend)()',
      'local Catalog = (function()\n$catalog\nend)()',
      'assert(Catalog.Fish["$id"], "AnglerCatalog did not load $id")',
      'FISH_IDS = if FishModels.has("$id") then { "$id" } else {}',
      'print("FISHCHECK " .. #FISH_IDS)',
      read(await export.readAsString()),
    ].join('\n');
    final run = await _runLuau(bundle);
    if (run.code != 0) {
      final detail = (run.stderr.isNotEmpty ? run.stderr : run.stdout)
          .replaceAll(RegExp(r'\[string "[^"]*"\]'), 'bundle');
      return (json: null, error: 'Running the module failed:\n'
          '${detail.length > 3000 ? detail.substring(detail.length - 3000) : detail}');
    }
    final line = run.stdout.split('\n').firstWhere(
        (l) => l.startsWith('{"id":"$id"'), orElse: () => '');
    if (line.isEmpty) {
      return (json: null, error: 'The model built nothing (no Build output).');
    }
    try {
      return (json: packModel(jsonDecode(line) as Map<String, dynamic>), error: null);
    } on FormatException catch (e) {
      return (json: null, error: e.message);
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

  static Future<({int status, String body})> _ioTransport(String method,
      Uri url, Map<String, String> headers, String? body) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, url);
      headers.forEach(request.headers.set);
      if (body != null) request.write(body);
      final response = await request.close().timeout(const Duration(seconds: 30));
      return (
        status: response.statusCode,
        body: await response.transform(utf8.decoder).join(),
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<({int status, String body})> _ioAi(
      Uri url, Map<String, String> headers, String body) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(url);
      headers.forEach(request.headers.set);
      request.add(utf8.encode(body));
      // Reasoning models can think for minutes over a whole module.
      final response = await request.close().timeout(const Duration(minutes: 12));
      return (
        status: response.statusCode,
        body: await response.transform(utf8.decoder).join(),
      );
    } on TimeoutException {
      return (status: 504, body: '{"error":"The model took too long."}');
    } finally {
      client.close(force: true);
    }
  }
}

/// The exporter's raw model line in the wiki's model file format (see the
/// wiki's scripts/sync-fish-library.mjs, which this mirrors): packed base
/// parts, and per mutation only the parts it repaints or adds.
String packModel(Map<String, dynamic> fish) {
  const shapes = {'block': 0, 'sphere': 1, 'wedge': 2, 'cylinder': 3};
  num round(num v) => (v * 10000).round() / 10000;
  List<Object> pack(Map part) {
    final out = <Object>[
      shapes[part['s']] ?? 0,
      ...(part['z'] as List).cast<num>().map(round),
      ...(part['p'] as List).cast<num>().map(round),
      for (final axis in (part['r'] as List)) ...(axis as List).cast<num>().map(round),
      part['c'] as String,
      part['m'] as String,
      round((part['t'] as num?) ?? 0),
    ];
    if (part['h'] is List) out.add((part['h'] as List).cast<num>().map(round).toList());
    return out;
  }

  bool sameGeometry(Map a, Map b) =>
      a['s'] == b['s'] &&
      a['n'] == b['n'] &&
      jsonEncode([a['z'], a['p'], a['r']]) == jsonEncode([b['z'], b['p'], b['r']]);

  final variants = Map<String, dynamic>.from(fish['variants'] as Map);
  final base = variants['Normal'] as Map;
  final baseParts = (base['parts'] as List).cast<Map>();
  final out = <String, dynamic>{};
  for (final entry in variants.entries) {
    if (entry.key == 'Normal') continue;
    final model = entry.value as Map;
    final parts = (model['parts'] as List).cast<Map>();
    final paint = <List<Object>>[];
    for (var i = 0; i < baseParts.length; i++) {
      final part = baseParts[i];
      final next = i < parts.length ? parts[i] : null;
      if (next == null || !sameGeometry(part, next)) {
        throw FormatException(
            '${fish['id']} ${entry.key}: part $i moved; mutations may only repaint or add parts.');
      }
      if (next['c'] != part['c'] ||
          next['m'] != part['m'] ||
          (next['t'] ?? 0) != (part['t'] ?? 0) ||
          next['h'] != null) {
        paint.add([
          i,
          next['c'] as String,
          next['m'] as String,
          round((next['t'] as num?) ?? 0),
          if (next['h'] is List) (next['h'] as List).cast<num>().map(round).toList(),
        ]);
      }
    }
    out[entry.key] = {
      'paint': paint,
      'add': parts.skip(baseParts.length).map(pack).toList(),
      'effects': model['effects'],
      'boundsCenter': model['boundsCenter'],
      'boundsSize': model['boundsSize'],
    };
  }
  return jsonEncode({
    'id': fish['id'],
    'view': fish['view'],
    'boundsCenter': base['boundsCenter'],
    'boundsSize': base['boundsSize'],
    'parts': baseParts.map(pack).toList(),
    'variants': out,
  });
}

/// One AI edit or new species, from the request to the commit.
class FishJob {
  FishJob({
    required this.id,
    required this.mode,
    required this.fishId,
    required this.prompt,
    required this.provider,
    required this.model,
    required this.effort,
    required this.fields,
    required this.createdAt,
    this.host = '',
    this.hasImage = false,
  }) : updatedAt = createdAt;

  final String id;
  final String mode;
  final String fishId;
  final String prompt;
  final String provider;
  final String model;
  final String effort;

  /// OpenRouter endpoint tag the job is pinned to; empty lets OpenRouter pick.
  final String host;
  final Map<String, Object?> fields;
  final bool hasImage;
  final int createdAt;
  int updatedAt;
  String status = 'queued';
  String stage = '';
  String? error;
  String? notes;
  String? original;
  String? baseSha;
  String? result;
  bool hasPreview = false;
  String? commitUrl;
  List<String> revisions = [];
  int promptTokens = 0;
  int completionTokens = 0;
  double cost = 0;
  bool cancelled = false;

  bool get busy => const {'queued', 'generating', 'previewing', 'committing'}
      .contains(status);

  Map<String, dynamic> summary() => {
        'id': id,
        'mode': mode,
        'fishId': fishId,
        'name': fields['Name'] ?? fishId,
        'status': status,
        'stage': stage,
        'error': error,
        'provider': provider,
        'model': model,
        'effort': effort,
        if (host.isNotEmpty) 'host': host,
        'prompt': prompt,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'hasPreview': hasPreview,
        'commitUrl': commitUrl,
        'revisions': revisions,
        'tokens': promptTokens + completionTokens,
        if (cost > 0) 'cost': cost,
      };

  Map<String, dynamic> detail() => {
        ...summary(),
        'notes': notes,
        'original': original,
        'result': result,
        'fields': fields,
        'hasImage': hasImage,
      };

  Map<String, dynamic> toJson() => {
        ...detail(),
        'baseSha': baseSha,
        'promptTokens': promptTokens,
        'completionTokens': completionTokens,
      };

  factory FishJob.fromJson(Map<String, dynamic> j) => FishJob(
        id: j['id'] as String,
        mode: j['mode'] as String,
        fishId: j['fishId'] as String,
        prompt: j['prompt'] as String? ?? '',
        provider: j['provider'] as String,
        model: j['model'] as String,
        effort: j['effort'] as String? ?? '',
        host: j['host'] as String? ?? '',
        fields: Map<String, Object?>.from(j['fields'] as Map? ?? {}),
        createdAt: (j['createdAt'] as num).toInt(),
        hasImage: j['hasImage'] == true,
      )
        ..updatedAt = (j['updatedAt'] as num?)?.toInt() ?? 0
        ..status = j['status'] as String? ?? 'failed'
        ..stage = j['stage'] as String? ?? ''
        ..error = j['error'] as String?
        ..notes = j['notes'] as String?
        ..original = j['original'] as String?
        ..baseSha = j['baseSha'] as String?
        ..result = j['result'] as String?
        ..hasPreview = j['hasPreview'] == true
        ..commitUrl = j['commitUrl'] as String?
        ..revisions = (j['revisions'] as List? ?? []).cast<String>().toList()
        ..promptTokens = (j['promptTokens'] as num?)?.toInt() ?? 0
        ..completionTokens = (j['completionTokens'] as num?)?.toInt() ?? 0
        ..cost = (j['cost'] as num?)?.toDouble() ?? 0;
}

class _GithubError implements Exception {
  _GithubError(this.status, this.message);
  final int status;
  final String message;

  String describe(String repo) => switch (status) {
        401 => 'GitHub refused the token (LUMA_FISHING_WATERS_GITHUB_TOKEN).',
        403 => message.contains('rate limit')
            ? 'GitHub\'s rate limit is used up; set LUMA_FISHING_WATERS_GITHUB_TOKEN.'
            : 'The token may not write to $repo (it needs Contents read/write).',
        404 => 'GitHub has no $repo, or the token cannot see it.',
        _ => 'GitHub answered $status${message.isEmpty ? '' : ': $message'}.',
      };
}

class _Conflict implements Exception {
  _Conflict(this.path, {required this.created});
  final String path;
  final bool created;

  String describe() => created
      ? '$path was created by someone else meanwhile. Reload and start again.'
      : '$path changed on GitHub since this edit started. Reload the fish and '
          'try again so nothing is overwritten.';
}

class _JobError implements Exception {
  _JobError(this.message);
  final String message;
}

class _Cancelled implements Exception {
  const _Cancelled();
}
