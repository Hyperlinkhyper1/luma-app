import 'package:drift/drift.dart';

import 'chat_database.dart';

/// A saved conversation with the AI assistant.
class ChatConversationRecord {
  const ChatConversationRecord({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.pinned,
  });

  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pinned;
}

/// A single message within a conversation.
class ChatMessageRecord {
  const ChatMessageRecord({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.metadataJson,
  });

  final int id;
  final int conversationId;
  final String role;
  final String content;
  final DateTime createdAt;
  final String? metadataJson;
}

/// CRUD over the local chat history.
class ChatRepository {
  ChatRepository(this._db);

  final ChatDatabase _db;

  Stream<List<ChatConversationRecord>> watchConversations() {
    final query = _db.select(_db.chatConversations)
      ..orderBy([
        (t) => OrderingTerm.desc(t.pinned),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    return query.watch().map(
          (rows) => rows.map(_toConversation).toList(growable: false),
        );
  }

  Future<int> createConversation({String title = 'New conversation'}) {
    return _db.into(_db.chatConversations).insert(
          ChatConversationsCompanion.insert(title: title),
        );
  }

  Future<void> renameConversation(int id, String title) {
    return (_db.update(_db.chatConversations)..where((t) => t.id.equals(id)))
        .write(ChatConversationsCompanion(
      title: Value(title),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> setPinned(int id, bool pinned) {
    return (_db.update(_db.chatConversations)..where((t) => t.id.equals(id)))
        .write(ChatConversationsCompanion(pinned: Value(pinned)));
  }

  Future<void> deleteConversation(int id) async {
    await (_db.delete(_db.chatMessages)
          ..where((t) => t.conversationId.equals(id)))
        .go();
    await (_db.delete(_db.chatConversations)..where((t) => t.id.equals(id)))
        .go();
  }

  /// Deletes every conversation that has no messages — i.e. ones that were
  /// created but never used. Called on app close so the list stays clean.
  Future<void> purgeEmptyConversations() async {
    final conversations = await (_db.select(_db.chatConversations)).get();
    for (final c in conversations) {
      final messages = await (_db.select(_db.chatMessages)
            ..where((t) => t.conversationId.equals(c.id))
            ..limit(1))
          .get();
      if (messages.isEmpty) {
        await (_db.delete(_db.chatConversations)
              ..where((t) => t.id.equals(c.id)))
            .go();
      }
    }
  }

  Stream<List<ChatMessageRecord>> watchMessages(int conversationId) {
    final query = _db.select(_db.chatMessages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map(
          (rows) => rows.map(_toMessage).toList(growable: false),
        );
  }

  Future<List<ChatMessageRecord>> loadMessages(int conversationId) async {
    final query = _db.select(_db.chatMessages)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_toMessage).toList(growable: false);
  }

  Future<void> addMessage(
    int conversationId,
    String role,
    String content, {
    String? metadataJson,
  }) async {
    await _db.into(_db.chatMessages).insert(
          ChatMessagesCompanion.insert(
            conversationId: conversationId,
            role: role,
            content: content,
            metadataJson: Value(metadataJson),
          ),
        );
    await (_db.update(_db.chatConversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(ChatConversationsCompanion(updatedAt: Value(DateTime.now())));
  }

  ChatConversationRecord _toConversation(ChatConversation row) =>
      ChatConversationRecord(
        id: row.id,
        title: row.title,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        pinned: row.pinned,
      );

  ChatMessageRecord _toMessage(ChatMessage row) => ChatMessageRecord(
        id: row.id,
        conversationId: row.conversationId,
        role: row.role,
        content: row.content,
        createdAt: row.createdAt,
        metadataJson: row.metadataJson,
      );
}
