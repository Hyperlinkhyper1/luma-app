import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../../l10n/current_l.dart';
import '../../../../../sync/server_access.dart';

/// Why the classroom couldn't do something, with the server's code
/// (`plan_required`, `no_country`, `country_locked`, `usage_limit`, …) when
/// there is one, so the page can say the right thing.
class ClassroomException implements Exception {
  const ClassroomException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// The Text Library classroom's side of the luma server: the account's
/// country (set once) and the tutor model the operator picked, which hands
/// out questions about a paragraph and checks the answers. Like everything
/// that talks to a luma server it goes through [GatedServerClient].
class ClassroomApi {
  ClassroomApi(String baseUrl, {this.token, http.Client? client})
    : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _client = GatedServerClient(inner: client);

  final String baseUrl;
  final String? token;
  final http.Client _client;

  /// `{allowed, country}`.
  Future<Map<String, dynamic>> state() =>
      _call('GET', '/api/v1/classroom', null, const Duration(seconds: 20));

  /// Sets the account's country; refused with `country_locked` once set.
  Future<Map<String, dynamic>> setCountry(String country) => _call(
    'POST',
    '/api/v1/classroom/country',
    {'country': country},
    const Duration(seconds: 20),
  );

  /// `{question, choices}`.
  Future<Map<String, dynamic>> question(Map<String, Object?> body) => _call(
    'POST',
    '/api/v1/classroom/question',
    body,
    const Duration(seconds: 90),
  );

  /// `{results: [{result, feedback, answer} | null, …]}`, one per item.
  Future<Map<String, dynamic>> review(Map<String, Object?> body) => _call(
    'POST',
    '/api/v1/classroom/review',
    body,
    const Duration(minutes: 4),
  );

  Future<Map<String, dynamic>> _call(
    String method,
    String path,
    Object? body,
    Duration timeout,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'Content-Type': 'application/json',
      if (token case final value?) 'Authorization': 'Bearer $value',
    };
    final http.Response response;
    try {
      response =
          await (method == 'GET'
                  ? _client.get(uri, headers: headers)
                  : _client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(timeout);
    } on ServerAccessDeniedException {
      throw ClassroomException(
        currentL.textLibraryClassroomSignIn,
        code: 'signin',
      );
    } catch (_) {
      throw ClassroomException(
        currentL.textLibraryClassroomOffline,
        code: 'offline',
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode != 200) {
      final message = decoded is Map ? decoded['message'] : null;
      final code = decoded is Map ? decoded['error'] : null;
      throw ClassroomException(
        message is String && message.isNotEmpty
            ? message
            : currentL.textLibraryClassroomFailed(response.statusCode),
        code: code is String ? code : null,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ClassroomException(currentL.textLibraryClassroomMalformed);
    }
    return decoded;
  }

  void close() => _client.close();
}
