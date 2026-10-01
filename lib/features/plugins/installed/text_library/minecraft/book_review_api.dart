import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../../sync/server_access.dart';

/// Why a book could not be reviewed, worded for the review desk's screen.
class BookReviewException implements Exception {
  const BookReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What came back to the [BookReviewApi]: the reviewer's score and the coins
/// the server says it earns, with what to say about it. Passed on to the
/// page as it is.
typedef BookReviewResult = Map<String, Object?>;

/// The Minecraft hall's review desk: sends one of the reader's books to the
/// luma server, where the model the operator picked in the admin dashboard
/// reads and scores it. Like everything that talks to a luma server, only
/// through [GatedServerClient].
class BookReviewApi {
  BookReviewApi(String baseUrl, {this.token, http.Client? client})
    : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _client = GatedServerClient(inner: client);

  final String baseUrl;
  final String? token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 120);

  /// Reviews [text] titled [title]. [signIn] and [unreachable] are the
  /// messages for no approved account and no connection.
  Future<BookReviewResult> review(
    String title,
    String text, {
    required String signIn,
    required String unreachable,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/ai/book-review'),
            headers: {
              'Content-Type': 'application/json',
              if (token case final value?) 'Authorization': 'Bearer $value',
            },
            body: jsonEncode({'title': title, 'text': text}),
          )
          .timeout(_timeout);
    } on ServerAccessDeniedException {
      throw BookReviewException(signIn);
    } catch (_) {
      throw BookReviewException(unreachable);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode != 200) {
      final message = decoded is Map ? decoded['message'] : null;
      throw BookReviewException(
        message is String && message.isNotEmpty
            ? message
            : 'HTTP ${response.statusCode}',
      );
    }
    if (decoded is! Map || decoded['score'] is! num) {
      throw BookReviewException(unreachable);
    }
    final tips = decoded['tips'];
    return {
      'score': (decoded['score'] as num).round().clamp(0, 100),
      'coins': switch (decoded['coins']) {
        final num n => n.round().clamp(0, 50),
        _ => 0,
      },
      'verdict': '${decoded['verdict'] ?? ''}',
      'praise': '${decoded['praise'] ?? ''}',
      'tips': [
        if (tips is List)
          for (final t in tips.take(4))
            if (t is String && t.trim().isNotEmpty) t.trim(),
      ],
    };
  }

  void close() => _client.close();
}
