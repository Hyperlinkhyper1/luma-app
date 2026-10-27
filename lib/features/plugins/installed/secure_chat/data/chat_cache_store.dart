import 'dart:io';

import '../../../../../security/encrypted_json_cache.dart';
import '../../../../../security/secure_secret_store.dart';

/// Local, file-backed cache of already-decrypted conversations and
/// invites, so the plugin has something to show immediately on launch
/// before the first network refresh completes — mirrors
/// lib/family/family_cache_store.dart. Its complete payload is encrypted
/// with a device-protected key, including temporary writes.
class ChatCacheStore {
  ChatCacheStore._(this._cache);

  static const _fileName = 'luma_chat_cache.json';

  final EncryptedJsonCache _cache;

  List<dynamic> conversationsJson = const [];
  List<dynamic> invitesJson = const [];

  /// conversationId -> list of {id, senderUserId, createdAtMs, text}
  Map<String, List<dynamic>> messagesByConversation = {};

  /// peerUserId -> the chat public key this device trusts for them, pinned
  /// the first time it was seen (see ChatRepository.refresh).
  Map<String, String> pinnedKeys = {};

  static Future<ChatCacheStore> load({
    Directory? storageDir,
    SecureSecretStore? secretStore,
  }) async {
    final cache = await EncryptedJsonCache.load(
      _fileName,
      'secure-chat-cache',
      storageDir: storageDir,
      secretStore: secretStore,
    );
    final data = cache.data;
    final store = ChatCacheStore._(cache);
    try {
      store.conversationsJson = data['conversations'] as List? ?? const [];
      store.invitesJson = data['invites'] as List? ?? const [];
      final messages = data['messages'] as Map<String, dynamic>? ?? const {};
      store.messagesByConversation = {
        for (final entry in messages.entries)
          entry.key: (entry.value as List? ?? const []),
      };
      final pins = data['pinnedKeys'] as Map<String, dynamic>? ?? const {};
      store.pinnedKeys = {
        for (final entry in pins.entries)
          if (entry.value is String) entry.key: entry.value as String,
      };
    } catch (_) {
      // A corrupt cache file just means an empty cache until the next refresh.
    }
    return store;
  }

  Future<void> save() => _cache.save({
    'conversations': conversationsJson,
    'invites': invitesJson,
    'messages': messagesByConversation,
    'pinnedKeys': pinnedKeys,
  });
}
