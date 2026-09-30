import 'dart:convert';
import 'dart:io';

/// One HTTP exchange with the GitHub API, injectable so tests can fake it.
typedef GithubTransport = Future<({int status, String body})> Function(
    String method, Uri url, Map<String, String> headers, String? body);

/// Commits benchmark scenes uploaded from the admin dashboard to the repo,
/// so `server/benchmarks/` on GitHub stays the complete roster.
///
/// The server's container has no checkout and no git credentials (the host's
/// deploy watcher does the pulling), so this talks to the Git Data API
/// instead: the scene and the updated `manifest.json` land as one commit on
/// the branch, and the next "Update & restart server" pulls them back in as
/// seed files. Needs `LUMA_BENCHMARK_GITHUB_TOKEN`, a fine-grained token with
/// Contents read/write on just this repository; without it uploads still go
/// live on the server, they just aren't pushed.
class BenchmarkGithubPublisher {
  BenchmarkGithubPublisher({
    Map<String, String>? environment,
    GithubTransport? transport,
  })  : _environment = environment ?? Platform.environment,
        _transport = transport ?? _ioTransport;

  final Map<String, String> _environment;
  final GithubTransport _transport;

  static const _api = 'https://api.github.com';
  static const scenesPath = 'server/benchmarks/scenes';
  static const manifestPath = 'server/benchmarks/manifest.json';

  String _env(String key, String fallback) {
    final value = _environment[key]?.trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String get _token => _env('LUMA_BENCHMARK_GITHUB_TOKEN', '');

  String get repo =>
      _env('LUMA_BENCHMARK_GITHUB_REPO', 'Hyperlinkhyper1/luma-app');

  String get branch => _env('LUMA_BENCHMARK_GITHUB_BRANCH', 'master');

  bool get enabled => _token.isNotEmpty;

  /// Commits [bytes] as `scenes/<id>.<ext>` and upserts [entry] into the
  /// manifest. Returns the new commit's web URL. Retries when someone else
  /// moved the branch in between; throws [GithubPublishException] otherwise.
  Future<String> publish({
    required Map<String, dynamic> entry,
    required String fileName,
    required List<int> bytes,
  }) async {
    if (!enabled) {
      throw const GithubPublishException(
          'LUMA_BENCHMARK_GITHUB_TOKEN is not set on the server.');
    }
    final sceneBlob = await _post('/git/blobs', {
      'content': base64Encode(bytes),
      'encoding': 'base64',
    });
    for (var attempt = 0;; attempt++) {
      final head = await _get('/git/ref/heads/$branch');
      final headSha = (head['object'] as Map)['sha'] as String;
      final commit = await _get('/git/commits/$headSha');
      final baseTree = (commit['tree'] as Map)['sha'] as String;
      final manifest = await _raw('/contents/$manifestPath?ref=$headSha');
      final manifestBlob = await _post('/git/blobs', {
        'content': upsertManifest(manifest, entry),
        'encoding': 'utf-8',
      });
      final tree = await _post('/git/trees', {
        'base_tree': baseTree,
        'tree': [
          {
            'path': '$scenesPath/$fileName',
            'mode': '100644',
            'type': 'blob',
            'sha': sceneBlob['sha'],
          },
          {
            'path': manifestPath,
            'mode': '100644',
            'type': 'blob',
            'sha': manifestBlob['sha'],
          },
        ],
      });
      final created = await _post('/git/commits', {
        'message': 'benchmarks: add ${entry['model']} '
            '(${entry['id']}) from the admin dashboard [skip ci]',
        'tree': tree['sha'],
        'parents': [headSha],
      });
      final moved = await _send('PATCH', '/git/refs/heads/$branch', {
        'sha': created['sha'],
        'force': false,
      });
      if (moved.status == 200) {
        return 'https://github.com/$repo/commit/${created['sha']}';
      }
      if (moved.status != 422 || attempt >= 2) {
        throw GithubPublishException(_describe(moved));
      }
    }
  }

  /// [manifest] with [entry] replacing the stanza of the same id in place,
  /// or appended. Keeps the file's one-line layout and trailing newline so
  /// the diff on GitHub is just the stanza.
  static String upsertManifest(String manifest, Map<String, dynamic> entry) {
    final decoded = jsonDecode(manifest);
    if (decoded is! Map<String, dynamic>) {
      throw const GithubPublishException('manifest.json is not an object.');
    }
    final benchmarks = [...(decoded['benchmarks'] as List? ?? const [])];
    final stanza = {
      for (final key in (entry.keys.toList()..sort())) key: entry[key],
    };
    final index =
        benchmarks.indexWhere((e) => e is Map && e['id'] == entry['id']);
    if (index >= 0) {
      benchmarks[index] = stanza;
    } else {
      benchmarks.add(stanza);
    }
    decoded['benchmarks'] = benchmarks;
    return '${jsonEncode(decoded)}${manifest.endsWith('\n') ? '\n' : ''}';
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'luma-sync-server',
      };

  Future<({int status, String body})> _send(
          String method, String path, Object? body) =>
      _transport(method, Uri.parse('$_api/repos/$repo$path'), _headers,
          body == null ? null : jsonEncode(body));

  Future<Map<String, dynamic>> _json(
      String method, String path, Object? body) async {
    final response = await _send(method, path, body);
    if (response.status < 200 || response.status >= 300) {
      throw GithubPublishException(_describe(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _get(String path) => _json('GET', path, null);

  Future<Map<String, dynamic>> _post(String path, Object body) =>
      _json('POST', path, body);

  Future<String> _raw(String path) async {
    final response = await _transport(
        'GET',
        Uri.parse('$_api/repos/$repo$path'),
        {..._headers, 'Accept': 'application/vnd.github.raw+json'},
        null);
    if (response.status != 200) {
      throw GithubPublishException(_describe(response));
    }
    return response.body;
  }

  String _describe(({int status, String body}) response) {
    var message = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } catch (_) {
      // Not JSON; the status alone has to do.
    }
    return switch (response.status) {
      401 => 'GitHub rejected the token (401). $message',
      403 || 404 => 'The token cannot write to $repo (${response.status}). '
          'It needs Contents read/write on that repository. $message',
      _ => 'GitHub answered ${response.status}. $message',
    }
        .trim();
  }

  static Future<({int status, String body})> _ioTransport(
      String method, Uri url, Map<String, String> headers, String? body) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.openUrl(method, url);
      headers.forEach(request.headers.set);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(body));
      }
      final response =
          await request.close().timeout(const Duration(minutes: 5));
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(minutes: 5));
      return (status: response.statusCode, body: text);
    } finally {
      client.close(force: true);
    }
  }
}

class GithubPublishException implements Exception {
  const GithubPublishException(this.message);
  final String message;

  @override
  String toString() => message;
}
