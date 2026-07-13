import 'dart:convert';

import 'package:http/http.dart' as http;

/// A conversation the current user is part of, as seen from the server.
class RemoteConversation {
  const RemoteConversation({
    required this.id,
    required this.peerUserId,
    required this.peerEmail,
    required this.peerPublicKey,
    required this.createdAtMs,
  });

  final String id;
  final String peerUserId;
  final String peerEmail;

  /// The peer's base64 X25519 public key, or null if they haven't set up
  /// chat encryption on any device yet (messages can't be sent until they do).
  final String? peerPublicKey;
  final int createdAtMs;

  factory RemoteConversation.fromJson(Map<String, dynamic> j) =>
      RemoteConversation(
        id: j['id'] as String,
        peerUserId: j['peerUserId'] as String,
        peerEmail: j['peerEmail'] as String,
        peerPublicKey: j['peerPublicKey'] as String?,
        createdAtMs: j['createdAtMs'] as int,
      );
}

/// An invite addressed to the current user's own email — someone wants to
/// start a chat with them.
class RemoteChatInvite {
  const RemoteChatInvite({
    required this.id,
    required this.inviterEmail,
    required this.createdAtMs,
    required this.expiresAtMs,
  });

  final String id;
  final String inviterEmail;
  final int createdAtMs;
  final int expiresAtMs;

  factory RemoteChatInvite.fromJson(Map<String, dynamic> j) =>
      RemoteChatInvite(
        id: j['id'] as String,
        inviterEmail: j['inviterEmail'] as String,
        createdAtMs: j['createdAtMs'] as int,
        expiresAtMs: j['expiresAtMs'] as int,
      );
}

/// A message within a conversation. [blob] is the ciphertext relevant to the
/// requesting user (the server hands back whichever of the two sealed
/// copies — recipient's or sender's own — matches who's asking); see
/// chat_crypto.dart for how it's opened.
class RemoteChatMessage {
  const RemoteChatMessage({
    required this.id,
    required this.senderUserId,
    required this.createdAtMs,
    required this.blob,
  });

  final String id;
  final String senderUserId;
  final int createdAtMs;
  final String blob;

  factory RemoteChatMessage.fromJson(Map<String, dynamic> j) =>
      RemoteChatMessage(
        id: j['id'] as String,
        senderUserId: j['senderUserId'] as String,
        createdAtMs: j['createdAtMs'] as int,
        blob: j['blob'] as String,
      );
}

/// Raised for every non-successful server response, mirroring [FamilyApiException].
class ChatApiException implements Exception {
  const ChatApiException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  bool get isNotFound => status == 404;
  bool get needsKeySetup => code == 'no_key';
  bool get alreadyChatting => code == 'already_chatting';
  bool get invitePending => code == 'invite_pending';

  @override
  String toString() => message;
}

/// Thin typed HTTP client for the chat plugin's server endpoints. Bodies are
/// plain JSON containing only public keys and opaque ciphertext blobs —
/// never a private key, never plaintext. Deliberately separate from
/// [SyncApi]: like Families, this is a shared (cross-account) channel, not a
/// per-account zero-knowledge sync collection.
class ChatApi {
  ChatApi(String baseUrl, {this.token, http.Client? client})
      : baseUrl = _normalizeBaseUrl(baseUrl),
        _client = client ?? http.Client();

  final String baseUrl;
  String? token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 30);

  static String _normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Uri _uri(String path) => Uri.parse('$baseUrl/api/v1$path');

  Map<String, String> get _authHeaders =>
      {if (token != null) 'Authorization': 'Bearer $token'};

  Future<void> putPublicKey(String publicKeyBase64) async {
    final response = await _client
        .put(
          _uri('/chat/key'),
          headers: {..._authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({'publicKey': publicKeyBase64}),
        )
        .timeout(_timeout);
    _decodeOrThrow(response);
  }

  Future<void> sendInvite(String email) async {
    await _postJson('/chat/invite', {'email': email});
  }

  Future<List<RemoteChatInvite>> listMyInvites() async {
    final response = await _client
        .get(_uri('/chat/invites'), headers: _authHeaders)
        .timeout(_timeout);
    final body = _decodeOrThrow(response);
    return (body['invites'] as List? ?? const [])
        .map((i) => RemoteChatInvite.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<RemoteConversation> acceptInvite(String inviteId) async =>
      RemoteConversation.fromJson(
          await _postJson('/chat/invites/$inviteId/accept', const {}));

  Future<void> declineInvite(String inviteId) async {
    await _postJson('/chat/invites/$inviteId/decline', const {});
  }

  Future<List<RemoteConversation>> listConversations() async {
    final response = await _client
        .get(_uri('/chat/conversations'), headers: _authHeaders)
        .timeout(_timeout);
    final body = _decodeOrThrow(response);
    return (body['conversations'] as List? ?? const [])
        .map((c) => RemoteConversation.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<List<RemoteChatMessage>> listMessages(String conversationId,
      {int? sinceMs}) async {
    final uri = _uri('/chat/conversations/$conversationId/messages')
        .replace(queryParameters: {
      if (sinceMs != null) 'since': '$sinceMs',
    });
    final response = await _client.get(uri, headers: _authHeaders).timeout(_timeout);
    final body = _decodeOrThrow(response);
    return (body['messages'] as List? ?? const [])
        .map((m) => RemoteChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendMessage(
    String conversationId, {
    required String blobForRecipient,
    required String blobForSender,
  }) async {
    await _postJson('/chat/conversations/$conversationId/messages', {
      'blobForRecipient': blobForRecipient,
      'blobForSender': blobForSender,
    });
  }

  Future<Map<String, dynamic>> _postJson(
      String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          _uri(path),
          headers: {..._authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decodeOrThrow(response);
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
    throw ChatApiException(
      response.statusCode,
      decoded?['error'] as String? ?? 'http_${response.statusCode}',
      decoded?['message'] as String? ??
          'Server error (${response.statusCode}).',
    );
  }

  void close() => _client.close();
}
