import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../l10n/current_l.dart';
import '../../../../sync/server_access.dart';

/// One passage the server's reviewer model flagged.
class AiReviewPassage {
  const AiReviewPassage({
    required this.quote,
    required this.likelihood,
    required this.reason,
    this.start,
    this.end,
  });

  final String quote;

  /// 0..100 — how AI-generated this passage reads to the model.
  final int likelihood;
  final String reason;

  /// UTF-16 offsets into the reviewed text, or null when the model's quote
  /// could not be found in it.
  final int? start;
  final int? end;

  bool get located => start != null && end != null;

  static AiReviewPassage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final quote = raw['quote'];
    if (quote is! String) return null;
    final start = raw['start'];
    final end = raw['end'];
    return AiReviewPassage(
      quote: quote,
      likelihood: (raw['likelihood'] as num?)?.round().clamp(0, 100) ?? 0,
      reason: raw['reason'] is String ? raw['reason'] as String : '',
      start: start is int ? start : null,
      end: end is int ? end : null,
    );
  }
}

/// How a review was paid for: one of the plan's weekly included checks, or
/// an exchange for a share of the weekly Luma AI limit.
class AiReviewCharge {
  const AiReviewCharge({
    required this.included,
    required this.used,
    required this.exchanged,
    required this.exchangePct,
  });

  final int included;
  final int used;
  final bool exchanged;
  final int exchangePct;

  static AiReviewCharge? fromJson(Object? raw) {
    if (raw is! Map) return null;
    int value(String key) => raw[key] is num ? (raw[key] as num).toInt() : 0;
    return AiReviewCharge(
      included: value('included'),
      used: value('used'),
      exchanged: raw['exchanged'] == true,
      exchangePct: value('exchangePct'),
    );
  }
}

/// The reviewer model's judgement of a whole text.
class AiReview {
  const AiReview({
    required this.score,
    required this.verdict,
    required this.summary,
    required this.passages,
    this.charge,
  });

  /// What this review cost; null when the server did not say.
  final AiReviewCharge? charge;

  /// 0..100 — higher reads more AI-generated.
  final int score;
  final String verdict;
  final String summary;

  /// Sorted by position; unlocated passages come last.
  final List<AiReviewPassage> passages;

  static AiReview fromJson(Map<String, dynamic> json) => AiReview(
        score: (json['score'] as num?)?.round().clamp(0, 100) ?? 0,
        verdict: json['verdict'] is String ? json['verdict'] as String : '',
        summary: json['summary'] is String ? json['summary'] as String : '',
        charge: AiReviewCharge.fromJson(json['checks']),
        passages: [
          if (json['passages'] case final List list)
            for (final p in list) ?AiReviewPassage.fromJson(p),
        ],
      );
}

class AiReviewException implements Exception {
  const AiReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The AI Detector's "Deep check": sends the text to the luma server, where
/// the model and instructions the operator picked in the admin dashboard
/// review it. Unlike the on-device statistics this does leave the device, so
/// the page only offers it as an explicit extra step, and — like everything
/// that talks to a luma server — only through [GatedServerClient].
class AiReviewApi {
  AiReviewApi(String baseUrl, {this.token, http.Client? client})
      : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = GatedServerClient(inner: client);

  final String baseUrl;
  final String? token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 90);

  Future<AiReview> review(String text) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/ai/detect'),
            headers: {
              'Content-Type': 'application/json',
              if (token case final value?) 'Authorization': 'Bearer $value',
            },
            body: jsonEncode({'text': text}),
          )
          .timeout(_timeout);
    } on ServerAccessDeniedException {
      throw AiReviewException(currentL.aiReviewSignInRequired);
    } catch (_) {
      throw AiReviewException(currentL.aiReviewUnreachable);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode != 200) {
      // Server-side error text may use the host's language; show the local
      // status message so this page follows the recipient's Settings locale.
      throw AiReviewException(
        currentL.aiReviewFailedStatus(response.statusCode),
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw AiReviewException(currentL.aiReviewMalformed);
    }
    return AiReview.fromJson(decoded);
  }

  void close() => _client.close();
}
