import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../../../l10n/current_l.dart';
import '../../../../../sync/server_access.dart';
import '../team_clipboard_models.dart';

class TeamClipboardApiException implements Exception {
  const TeamClipboardApiException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  /// The operator took this account off the team.
  bool get accessRemoved => code == 'team_access_required';

  @override
  String toString() => message;
}

/// What `GET /team-board` answered: out, unchanged since the revision asked
/// about, or the whole board.
class TeamBoardSnapshot {
  const TeamBoardSnapshot({
    required this.access,
    required this.revision,
    this.email,
    this.me,
    this.entries,
  });

  final TeamAccess access;
  final int revision;

  /// The account's email when it isn't on the team, so the page can say
  /// which account to add.
  final String? email;
  final String? me;

  /// Null when nothing changed since the revision asked about.
  final List<TeamEntry>? entries;
}

/// HTTP client for the Team Clipboard's shared board. Like the recipe
/// catalogue the board is plain shared content, not end-to-end encrypted,
/// and every request goes through [GatedServerClient].
class TeamClipboardApi {
  TeamClipboardApi(String baseUrl, {this.token, http.Client? client})
    : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
      _client = GatedServerClient(inner: client);

  final String baseUrl;
  final String? token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 30);
  static const _fileTimeout = Duration(seconds: 120);

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
    '$baseUrl/api/v1/team-board$path',
  ).replace(queryParameters: query);

  Map<String, String> get _auth => {
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<TeamBoardSnapshot> board({int? since}) async {
    final response = await _client
        .get(
          _uri('', since == null ? null : {'since': '$since'}),
          headers: _auth,
        )
        .timeout(_timeout);
    final body = _decodeOrThrow(response);
    if (body['member'] != true) {
      return TeamBoardSnapshot(
        access: TeamAccess.outside,
        revision: 0,
        email: body['email'] as String?,
      );
    }
    return TeamBoardSnapshot(
      access: body['lead'] == true ? TeamAccess.lead : TeamAccess.member,
      revision: body['revision'] as int? ?? 0,
      me: body['me'] as String?,
      entries: body['unchanged'] == true
          ? null
          : [
              for (final e in body['entries'] as List? ?? const [])
                TeamEntry.fromJson(e as Map<String, dynamic>),
            ],
    );
  }

  Future<TeamEntry> entry(String id) async {
    final response = await _client
        .get(_uri('/entries/$id'), headers: _auth)
        .timeout(_timeout);
    return TeamEntry.fromJson(_decodeOrThrow(response));
  }

  Future<TeamEntry> create({
    required TeamEntryKind kind,
    required String title,
    required String brief,
  }) async => TeamEntry.fromJson(
    await _send('POST', '/entries', {
      'kind': kind.name,
      'title': title,
      'brief': brief,
    }),
  );

  Future<TeamEntry> update(
    String id, {
    required TeamEntryKind kind,
    required String title,
    required String brief,
  }) async => TeamEntry.fromJson(
    await _send('PUT', '/entries/$id', {
      'kind': kind.name,
      'title': title,
      'brief': brief,
    }),
  );

  Future<TeamEntry> setStage(String id, TeamEntryStage stage) async =>
      TeamEntry.fromJson(
        await _send('POST', '/entries/$id/stage', {'stage': stage.name}),
      );

  Future<TeamEntry> setClosed(String id, bool closed) async =>
      TeamEntry.fromJson(
        await _send('POST', '/entries/$id/close', {'closed': closed}),
      );

  Future<void> delete(String id) async {
    final response = await _client
        .delete(_uri('/entries/$id'), headers: _auth)
        .timeout(_timeout);
    _decodeOrThrow(response);
  }

  Future<TeamEntry> post(String id, String text) async => TeamEntry.fromJson(
    await _send('POST', '/entries/$id/messages', {'text': text}),
  );

  Future<TeamEntry> upload(String id, String name, Uint8List bytes) async {
    final response = await _client
        .post(
          _uri('/entries/$id/files', {'name': name}),
          headers: {..._auth, 'Content-Type': 'application/octet-stream'},
          body: bytes,
        )
        .timeout(_fileTimeout);
    return TeamEntry.fromJson(_decodeOrThrow(response));
  }

  Future<TeamEntry> removeFile(String id, String fileId) async {
    final response = await _client
        .delete(_uri('/entries/$id/files/$fileId'), headers: _auth)
        .timeout(_timeout);
    return TeamEntry.fromJson(_decodeOrThrow(response));
  }

  Future<Uint8List> download(String fileId) async {
    final response = await _client
        .get(_uri('/files/$fileId'), headers: _auth)
        .timeout(_fileTimeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    _decodeOrThrow(response);
    throw TeamClipboardApiException(
      response.statusCode,
      'http_${response.statusCode}',
      currentL.teamClipboardServerError(response.statusCode),
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final request = http.Request(method, _uri(path))
      ..headers.addAll({..._auth, 'Content-Type': 'application/json'})
      ..body = jsonEncode(body);
    final streamed = await _client.send(request).timeout(_timeout);
    return _decodeOrThrow(await http.Response.fromStream(streamed));
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(utf8.decode(response.bodyBytes));
      if (raw is Map<String, dynamic>) decoded = raw;
    } catch (_) {}
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? const {};
    }
    throw TeamClipboardApiException(
      response.statusCode,
      decoded?['error'] as String? ?? 'http_${response.statusCode}',
      decoded?['message'] as String? ??
          currentL.teamClipboardServerError(response.statusCode),
    );
  }

  void close() => _client.close();
}
