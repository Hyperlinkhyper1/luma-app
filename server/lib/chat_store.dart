import 'dart:convert';
import 'dart:io';

import 'util.dart';

/// An invite to start an end-to-end encrypted chat with another user,
/// identified by email (mirrors [FamilyInvite] in family_store.dart). The
/// server only ever brokers the invite and, once accepted, relays opaque
/// ciphertext blobs — it never sees a plaintext message or either party's
/// private key.
class ChatInvite {
  ChatInvite({
    required this.id,
    required this.fromUserId,
    required this.toEmail,
    required this.createdAtMs,
    required this.expiresAtMs,
    this.status = 'pending',
    this.respondedAtMs,
  });

  final String id;
  final String fromUserId;
  final String toEmail; // lowercased
  String status; // 'pending' | 'accepted' | 'declined' | 'revoked'
  final int createdAtMs;
  final int expiresAtMs;
  int? respondedAtMs;

  bool isPendingAt(int nowMs) => status == 'pending' && expiresAtMs > nowMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUserId': fromUserId,
        'toEmail': toEmail,
        'status': status,
        'createdAtMs': createdAtMs,
        'expiresAtMs': expiresAtMs,
        'respondedAtMs': respondedAtMs,
      };

  factory ChatInvite.fromJson(Map<String, dynamic> j) => ChatInvite(
        id: j['id'] as String,
        fromUserId: j['fromUserId'] as String,
        toEmail: j['toEmail'] as String,
        status: j['status'] as String? ?? 'pending',
        createdAtMs: j['createdAtMs'] as int,
        expiresAtMs: j['expiresAtMs'] as int,
        respondedAtMs: j['respondedAtMs'] as int?,
      );
}

/// A 1:1 conversation between two users. Created the moment a [ChatInvite]
/// is accepted; there is at most one conversation per unordered pair.
class ChatConversation {
  ChatConversation({
    required this.id,
    required this.userAId,
    required this.userBId,
    required this.createdAtMs,
  });

  final String id;
  final String userAId;
  final String userBId;
  final int createdAtMs;

  bool hasUser(String userId) => userAId == userId || userBId == userId;

  String otherUser(String userId) => userAId == userId ? userBId : userAId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userAId': userAId,
        'userBId': userBId,
        'createdAtMs': createdAtMs,
      };

  factory ChatConversation.fromJson(Map<String, dynamic> j) =>
      ChatConversation(
        id: j['id'] as String,
        userAId: j['userAId'] as String,
        userBId: j['userBId'] as String,
        createdAtMs: j['createdAtMs'] as int,
      );
}

/// One message within a conversation. The server stores two opaque,
/// independently-encrypted blobs (base64) per message — one sealed to the
/// recipient's public key, one sealed to the sender's own public key so the
/// sender can also read back their own sent history — and hands back
/// whichever one matches the requesting user. Neither blob is decryptable
/// server-side; see lib/features/plugins/installed/secure_chat/data/chat_crypto.dart
/// on the client for the sealed-box scheme.
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.createdAtMs,
    required this.blobForRecipient,
    required this.blobForSender,
  });

  final String id;
  final String conversationId;
  final String senderUserId;
  final int createdAtMs;
  final String blobForRecipient;
  final String blobForSender;

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'senderUserId': senderUserId,
        'createdAtMs': createdAtMs,
        'blobForRecipient': blobForRecipient,
        'blobForSender': blobForSender,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        conversationId: j['conversationId'] as String,
        senderUserId: j['senderUserId'] as String,
        createdAtMs: j['createdAtMs'] as int,
        blobForRecipient: j['blobForRecipient'] as String,
        blobForSender: j['blobForSender'] as String,
      );
}

/// File-backed store for the chat subsystem (public keys, invites,
/// conversations, messages), mirroring [FamilyStore]'s persistence
/// conventions. Kept as its own file/lock namespace for the same reason
/// FamilyStore is separate from Store — a distinct subsystem with its own
/// access-control shape. Mutations should go through the shared
/// `Store.lock` at the call site (Api holds all stores) so writes never
/// interleave with account/session mutations for the same user.
class ChatStore {
  ChatStore._(this.rootPath);

  final String rootPath;

  /// Each user's X25519 public key (base64), uploaded once the chat plugin
  /// is set up on a device. Never a private key — those never leave the
  /// client.
  final Map<String, String> publicKeyByUserId = {};

  final Map<String, ChatInvite> invitesById = {};
  final Map<String, ChatConversation> conversationsById = {};
  final Map<String, List<ChatMessage>> messagesByConversationId = {};

  String get _keysFile => '$rootPath/chat_keys.json';
  String get _invitesFile => '$rootPath/chat_invites.json';
  String get _conversationsFile => '$rootPath/chat_conversations.json';
  String get _messagesFile => '$rootPath/chat_messages.json';

  static Future<ChatStore> open(String path) async {
    final store = ChatStore._(path);

    for (final k in await _readJsonList(store._keysFile)) {
      final m = k as Map<String, dynamic>;
      store.publicKeyByUserId[m['userId'] as String] = m['publicKey'] as String;
    }

    for (final i in await _readJsonList(store._invitesFile)) {
      final invite = ChatInvite.fromJson(i as Map<String, dynamic>);
      store.invitesById[invite.id] = invite;
    }

    for (final c in await _readJsonList(store._conversationsFile)) {
      final conv = ChatConversation.fromJson(c as Map<String, dynamic>);
      store.conversationsById[conv.id] = conv;
    }

    for (final m in await _readJsonList(store._messagesFile)) {
      final message = ChatMessage.fromJson(m as Map<String, dynamic>);
      store.messagesByConversationId
          .putIfAbsent(message.conversationId, () => [])
          .add(message);
    }
    for (final list in store.messagesByConversationId.values) {
      list.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    }

    return store;
  }

  static Future<List<dynamic>> _readJsonList(String path) async {
    final file = File(path);
    if (!await file.exists()) return const [];
    final decoded = jsonDecode(await file.readAsString());
    return decoded is List ? decoded : const [];
  }

  // ---- Persistence -------------------------------------------------------

  Future<void> saveKeys() => atomicWriteString(
      _keysFile,
      jsonEncode(publicKeyByUserId.entries
          .map((e) => {'userId': e.key, 'publicKey': e.value})
          .toList()));

  Future<void> saveInvites() => atomicWriteString(_invitesFile,
      jsonEncode(invitesById.values.map((i) => i.toJson()).toList()));

  Future<void> saveConversations() => atomicWriteString(_conversationsFile,
      jsonEncode(conversationsById.values.map((c) => c.toJson()).toList()));

  Future<void> saveMessages() => atomicWriteString(
      _messagesFile,
      jsonEncode(messagesByConversationId.values
          .expand((list) => list)
          .map((m) => m.toJson())
          .toList()));

  // ---- Queries -------------------------------------------------------------

  List<ChatConversation> conversationsForUser(String userId) =>
      conversationsById.values.where((c) => c.hasUser(userId)).toList();

  ChatConversation? conversationBetween(String userAId, String userBId) {
    for (final c in conversationsById.values) {
      if ((c.userAId == userAId && c.userBId == userBId) ||
          (c.userAId == userBId && c.userBId == userAId)) {
        return c;
      }
    }
    return null;
  }

  List<ChatInvite> pendingInvitesForEmail(String email, int nowMs) =>
      invitesById.values
          .where((i) => i.toEmail == email && i.isPendingAt(nowMs))
          .toList();

  List<ChatMessage> messagesFor(String conversationId, {int? sinceMs}) {
    final all = messagesByConversationId[conversationId] ?? const [];
    if (sinceMs == null) return List.of(all);
    return all.where((m) => m.createdAtMs > sinceMs).toList();
  }
}
