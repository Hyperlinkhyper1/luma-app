import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Local, file-backed cache of already-decrypted conversations and
/// invites, so the plugin has something to show immediately on launch
/// before the first network refresh completes — mirrors
/// lib/family/family_cache_store.dart. Only ever holds *plaintext the user
/// has already decrypted on this device*; it never stores key material.
class ChatCacheStore {
  ChatCacheStore._(this._file);

  static const _fileName = 'luma_chat_cache.json';

  final File? _file;

  List<dynamic> conversationsJson = const [];
  List<dynamic> invitesJson = const [];

  /// conversationId -> list of {id, senderUserId, createdAtMs, text}
  Map<String, List<dynamic>> messagesByConversation = {};

  static Future<ChatCacheStore> load() async {
    File? file;
    Map<String, dynamic> data = const {};
    try {
      final dir = await getApplicationSupportDirectory();
      file = File('${dir.path}${Platform.pathSeparator}$_fileName');
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) data = decoded;
      }
    } catch (_) {
      file = null;
    }

    final store = ChatCacheStore._(file);
    try {
      store.conversationsJson = data['conversations'] as List? ?? const [];
      store.invitesJson = data['invites'] as List? ?? const [];
      final messages = data['messages'] as Map<String, dynamic>? ?? const {};
      store.messagesByConversation = {
        for (final entry in messages.entries)
          entry.key: (entry.value as List? ?? const []),
      };
    } catch (_) {
      // A corrupt cache file just means an empty cache until the next refresh.
    }
    return store;
  }

  Future<void> save() async {
    final file = _file;
    if (file == null) return;
    try {
      final payload = jsonEncode({
        'conversations': conversationsJson,
        'invites': invitesJson,
        'messages': messagesByConversation,
      });
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(payload, flush: true);
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    } catch (_) {
      // Best effort — the cache just won't survive a restart.
    }
  }
}
