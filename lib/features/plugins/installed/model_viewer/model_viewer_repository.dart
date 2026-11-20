import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../../l10n/current_l.dart';
import '../../../../security/secure_secret_store.dart';

enum RepositoryModelFormat {
  glb,
  gltf,
  fbx,
  obj,
  stl,
  ply;

  static RepositoryModelFormat? fromPath(String path) =>
      values.where((format) => format.name == fileExtension(path)).firstOrNull;
}

String fileExtension(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  return dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
}

class RepositoryModel {
  const RepositoryModel(this.path, this.format);

  final String path;
  final RepositoryModelFormat format;

  String get name => path.split('/').last;
}

class ModelViewerException implements Exception {
  const ModelViewerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ModelCatalogue {
  ModelCatalogue._(this.slug, this.ref, this._files, this._read)
    : models = List.unmodifiable(
        _files.keys
            .map((path) {
              final format = RepositoryModelFormat.fromPath(path);
              return format == null ? null : RepositoryModel(path, format);
            })
            .nonNulls
            .toList()
          ..sort(
            (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
          ),
      );

  final String slug;
  final String ref;
  final List<RepositoryModel> models;
  final Map<String, _GitBlob> _files;
  final Future<Uint8List> Function(_GitBlob blob, Future<void>? abort) _read;

  int? sizeOf(String path) => _files[path]?.size;

  Future<Uint8List> read(String path, {Future<void>? abort}) {
    final blob = _files[path];
    if (blob == null) {
      throw ModelViewerException(currentL.modelViewerMissingFile);
    }
    return _read(blob, abort);
  }
}

typedef _GitBlob = ({String sha, int size});

class GithubDeviceAuthorization {
  const GithubDeviceAuthorization._(
    this.userCode,
    this._deviceCode,
    this._expiresAt,
    this._interval,
  );

  final String userCode;
  final String _deviceCode;
  final DateTime _expiresAt;
  final Duration _interval;
}

class ModelViewerRepository {
  ModelViewerRepository({http.Client? client, SecureSecretStore? secrets})
    : _client = client ?? http.Client(),
      _secrets = secrets ?? SecureSecretStore.instance;

  static const _credentialKey = 'model-viewer.github';
  static const _deviceClientId = String.fromEnvironment(
    'MODEL_VIEWER_GITHUB_CLIENT_ID',
  );
  static const maxFileBytes = 100 * 1024 * 1024;
  static const _requestTimeout = Duration(seconds: 30);
  static final _repoPart = RegExp(r'^[A-Za-z0-9_.-]+$');
  static final _sha = RegExp(r'^[a-f0-9]{40}$');

  final http.Client _client;
  final SecureSecretStore _secrets;
  String? _token;
  String? githubLogin;
  Future<void>? _restoring;

  static bool get deviceSignInAvailable => _deviceClientId.isNotEmpty;

  void dispose() => _client.close();

  Future<void> restoreConnection() => _restoring ??= _restore();

  Future<void> _restore() async {
    try {
      final saved = await _secrets.read(_credentialKey);
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        final token = data['token'] as String;
        final login = data['login'] as String;
        if (token.isEmpty || login.isEmpty) return;
        _token = token;
        githubLogin = login;
      }
    } catch (_) {
      // Public repositories are available even if the device keyring is locked.
    }
  }

  Future<void> connect(String input) async {
    await restoreConnection();
    final token = input.trim();
    if (token.isEmpty) {
      throw ModelViewerException(currentL.accountOverviewPasteTokenFirst);
    }
    final profile = await _json(['user'], token: token);
    final login = profile['login'] as String;
    await _secrets.write(
      _credentialKey,
      jsonEncode({'token': token, 'login': login}),
    );
    _token = token;
    githubLogin = login;
  }

  Future<void> disconnect() async {
    await restoreConnection();
    await _secrets.delete(_credentialKey);
    _token = null;
    githubLogin = null;
  }

  Future<GithubDeviceAuthorization> beginDeviceSignIn() async {
    final data = await _devicePost(
      ['login', 'device', 'code'],
      {'client_id': _deviceClientId},
    );
    final userCode = data['user_code'];
    final deviceCode = data['device_code'];
    if (userCode is! String || deviceCode is! String) {
      throw ModelViewerException(currentL.modelViewerSignInFailed);
    }
    return GithubDeviceAuthorization._(
      userCode,
      deviceCode,
      DateTime.now().add(Duration(seconds: data['expires_in'] as int)),
      Duration(seconds: data['interval'] as int? ?? 5),
    );
  }

  Future<String?> pollDeviceSignIn(
    GithubDeviceAuthorization authorization, {
    required bool Function() cancelled,
  }) async {
    var interval = authorization._interval;
    while (!cancelled() && DateTime.now().isBefore(authorization._expiresAt)) {
      await Future<void>.delayed(interval);
      if (cancelled()) return null;
      if (!DateTime.now().isBefore(authorization._expiresAt)) break;
      final data = await _devicePost(
        ['login', 'oauth', 'access_token'],
        {
          'client_id': _deviceClientId,
          'device_code': authorization._deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        },
      );
      if (cancelled()) return null;
      if (data['access_token'] case final String token) return token;
      switch (data['error']) {
        case 'authorization_pending':
          continue;
        case 'slow_down':
          interval += const Duration(seconds: 5);
        case 'expired_token':
          throw ModelViewerException(currentL.modelViewerCodeExpired);
        default:
          throw ModelViewerException(currentL.modelViewerSignInFailed);
      }
    }
    if (cancelled()) return null;
    throw ModelViewerException(currentL.modelViewerCodeExpired);
  }

  Future<Map<String, dynamic>> _devicePost(
    List<String> path,
    Map<String, String> fields,
  ) async {
    final request =
        http.Request(
            'POST',
            Uri(scheme: 'https', host: 'github.com', pathSegments: path),
          )
          ..followRedirects = false
          ..headers['Accept'] = 'application/json'
          ..bodyFields = fields;
    final response = await _client.send(request).timeout(_requestTimeout);
    final body = await response.stream.bytesToString().timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw ModelViewerException(currentL.modelViewerSignInFailed);
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<ModelCatalogue> scan(String input, {String ref = ''}) async {
    final slug = _parseSlug(input);
    await restoreConnection();
    final token = _token;
    final base = ['repos', ...slug.split('/')];
    final info = await _json(base, token: token);
    final branch = ref.trim().isEmpty
        ? info['default_branch'] as String
        : ref.trim();
    final files = <String, _GitBlob>{};
    Future<Uint8List> read(_GitBlob blob, Future<void>? abort) =>
        _readBlob(base, blob, token, abort);

    final commit = await _json(
      [...base, 'commits', branch],
      token: token,
      allowEmpty: ref.trim().isEmpty,
    );
    if (commit.isEmpty) return ModelCatalogue._(slug, branch, files, read);
    final treeSha = commit['commit']['tree']['sha'] as String;
    final trees = [...base, 'git', 'trees'];
    final fullTree = await _json(
      [...trees, treeSha],
      token: token,
      query: {'recursive': '1'},
    );

    void addFiles(List<dynamic> entries, String prefix) {
      for (final entry in entries) {
        final mode = entry['mode'];
        if (entry['type'] != 'blob' || (mode != '100644' && mode != '100755')) {
          continue;
        }
        final sha = entry['sha'] as String;
        final size = entry['size'] as int;
        if (!_sha.hasMatch(sha) || size < 0) continue;
        files['$prefix${entry['path']}'] = (sha: sha, size: size);
      }
    }

    if (fullTree['truncated'] == true) {
      final pending = [(sha: treeSha, prefix: '')];
      final loaded = <String, List<dynamic>>{};
      while (pending.isNotEmpty) {
        final tree = pending.removeLast();
        final entries = loaded[tree.sha] ??= await _readTree(
          trees,
          tree.sha,
          token,
        );
        addFiles(entries, tree.prefix);
        for (final entry in entries) {
          if (entry['type'] == 'tree') {
            pending.add((
              sha: entry['sha'] as String,
              prefix: '${tree.prefix}${entry['path']}/',
            ));
          }
        }
      }
    } else {
      addFiles(fullTree['tree'] as List, '');
    }
    return ModelCatalogue._(slug, branch, files, read);
  }

  Future<List<dynamic>> _readTree(
    List<String> path,
    String sha,
    String? token,
  ) async {
    final tree = await _json([...path, sha], token: token);
    if (tree['truncated'] == true) {
      throw ModelViewerException(currentL.modelViewerTreeTooLarge);
    }
    return tree['tree'] as List;
  }

  static String _parseSlug(String input) {
    final value = input.trim();
    final uri = Uri.tryParse(value);
    List<String> parts = [];
    if (uri != null && !uri.hasQuery && !uri.hasFragment) {
      if ((!uri.hasScheme && !uri.hasAuthority) ||
          (uri.scheme == 'https' &&
              uri.host == 'github.com' &&
              uri.userInfo.isEmpty &&
              uri.port == 443)) {
        parts = uri.pathSegments.toList();
        if (parts.lastOrNull == '') parts.removeLast();
      }
    }
    if (parts.length == 2) {
      final repo = parts.last.replaceFirst(RegExp(r'\.git$'), '');
      if ([parts.first, repo].every(
        (part) => _repoPart.hasMatch(part) && part != '.' && part != '..',
      )) {
        return '${parts.first}/$repo';
      }
    }
    throw ModelViewerException(currentL.modelViewerInvalidRepo);
  }

  Future<Map<String, dynamic>> _json(
    List<String> path, {
    required String? token,
    Map<String, String>? query,
    bool allowEmpty = false,
  }) async {
    final response = await _get(path, token: token, query: query);
    if (response.statusCode == 409 && allowEmpty) {
      await response.stream.drain<void>().timeout(_requestTimeout);
      return {};
    }
    await _checkResponse(response, token);
    final body = await response.stream.bytesToString().timeout(_requestTimeout);
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<Uint8List> _readBlob(
    List<String> base,
    _GitBlob blob,
    String? token,
    Future<void>? abort,
  ) async {
    if (blob.size > maxFileBytes) {
      throw ModelViewerException(currentL.modelViewerAssetTooLarge);
    }
    final response = await _get(
      [...base, 'git', 'blobs', blob.sha],
      token: token,
      accept: 'application/vnd.github.raw+json',
      abort: abort,
    );
    await _checkResponse(response, token);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(_requestTimeout)) {
      if (bytes.length + chunk.length > blob.size) {
        throw ModelViewerException(currentL.modelViewerInvalidBlob);
      }
      bytes.add(chunk);
    }
    if (bytes.length != blob.size) {
      throw ModelViewerException(currentL.modelViewerInvalidBlob);
    }
    final data = bytes.takeBytes();
    if (data.length < 1024 &&
        utf8
            .decode(data, allowMalformed: true)
            .startsWith('version https://git-lfs.github.com/spec/v1\n')) {
      throw ModelViewerException(currentL.modelViewerLfsPointer);
    }
    return data;
  }

  Future<http.StreamedResponse> _get(
    List<String> path, {
    required String? token,
    Map<String, String>? query,
    String accept = 'application/vnd.github+json',
    Future<void>? abort,
  }) {
    final uri = Uri(
      scheme: 'https',
      host: 'api.github.com',
      pathSegments: path,
      queryParameters: query,
    );
    final request = http.AbortableRequest('GET', uri, abortTrigger: abort)
      ..followRedirects = false
      ..headers.addAll({
        'Accept': accept,
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'luma-model-viewer',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    return _client.send(request).timeout(_requestTimeout);
  }

  Future<void> _checkResponse(
    http.StreamedResponse response,
    String? token,
  ) async {
    final status = response.statusCode;
    if (status == 200) return;
    await response.stream.drain<void>().timeout(_requestTimeout);
    final t = currentL;
    throw ModelViewerException(switch (status) {
      429 => t.accountOverviewGithubRateLimited,
      403 when response.headers['x-ratelimit-remaining'] == '0' =>
        t.accountOverviewGithubRateLimited,
      401 => t.accountOverviewGithubTokenRejected,
      403 || 404 when token == null => t.modelViewerRepoSignInRequired,
      403 || 404 || 422 => t.modelViewerRepoUnavailable,
      _ => t.modelViewerGithubError(status),
    });
  }
}
