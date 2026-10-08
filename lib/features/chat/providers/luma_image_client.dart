import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../l10n/current_l.dart';
import '../../../sync/server_access.dart';
import 'ai_client.dart';

/// One picture from the luma server's picture mode.
class LumaImage {
  const LumaImage({required this.bytes, required this.mimeType, this.text});

  final Uint8List bytes;
  final String mimeType;

  /// Any caption the model wrote alongside the picture.
  final String? text;

  String get extension => switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/webp' => 'webp',
    _ => 'png',
  };
}

/// Asks the luma server (POST /api/v1/ai/image) to draw a picture with the
/// model the operator picked in the admin dashboard. The server charges a
/// flat share of the weekly limit of [mode] per picture.
class LumaImageClient {
  LumaImageClient({required this.serverUrl, this.httpClient});

  final String serverUrl;

  /// Replaces the gated server client, for tests.
  final http.Client? httpClient;

  Future<LumaImage> generate({
    required String authToken,
    required String prompt,
    required String mode,
  }) async {
    var base = serverUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final client = httpClient ?? GatedServerClient();
    final http.Response res;
    try {
      res = await client
          .post(
            Uri.parse('$base/api/v1/ai/image'),
            headers: {
              'Authorization': 'Bearer $authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'prompt': prompt, 'mode': mode}),
          )
          .timeout(const Duration(seconds: 150));
    } on ServerAccessDeniedException catch (e) {
      throw AiAuthError(e.message);
    } catch (e) {
      throw AiNetworkError(currentL.aiClientNoConnection('Luma AI'));
    } finally {
      if (httpClient == null) client.close();
    }

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {}
    final message = json?['error'] is Map
        ? (json!['error'] as Map)['message'] as String?
        : json?['message'] as String?;

    if (res.statusCode == 429) {
      throw AiRateLimitError(message ?? currentL.aiClientRateLimited);
    }
    if (res.statusCode == 401) {
      throw AiAuthError(message ?? currentL.aiClientLumaSignIn);
    }
    if (res.statusCode != 200 || json == null || json['image'] is! String) {
      throw AiApiError(
        message ?? currentL.aiClientLumaImageFailed(res.statusCode),
      );
    }
    final Uint8List bytes;
    try {
      bytes = base64Decode(json['image'] as String);
    } on FormatException {
      throw AiApiError(currentL.aiClientLumaBrokenImage);
    }
    final text = json['text'];
    return LumaImage(
      bytes: bytes,
      mimeType: json['mimeType'] as String? ?? 'image/png',
      text: text is String && text.trim().isNotEmpty ? text.trim() : null,
    );
  }
}
