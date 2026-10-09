import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/current_l.dart';
import 'chat_database.dart';

/// A saved conversation with the AI assistant.
class ChatConversationRecord {
  const ChatConversationRecord({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.pinned,
    this.projectId,
  });

  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pinned;
  final int? projectId;
}

class ChatProjectRecord {
  const ChatProjectRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.memory,
  });
  final int id;
  final String name;
  final String description;
  final String memory;
}

class ChatArtifactRecord {
  const ChatArtifactRecord({
    required this.id,
    required this.name,
    required this.path,
    required this.mimeType,
    required this.createdAt,
    this.conversationId,
  });
  final int id;
  final int? conversationId;
  final String name;
  final String path;
  final String mimeType;
  final DateTime createdAt;
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

  Stream<List<ChatConversationRecord>> watchConversations({String query = ''}) {
    final search = query.trim();
    final pattern =
        '%${search.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%';
    final messageMatches = _db.selectOnly(_db.chatMessages)
      ..addColumns([_db.chatMessages.conversationId])
      ..where(_db.chatMessages.content.like(pattern, escapeChar: '\\'));
    final conversations = _db.select(_db.chatConversations)
      ..where(
        (t) => search.isEmpty
            ? const Constant(true)
            : t.title.like(pattern, escapeChar: '\\') |
                  t.id.isInQuery(messageMatches),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.pinned),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    return conversations.watch().map(
      (rows) => rows.map(_toConversation).toList(growable: false),
    );
  }

  Stream<List<ChatProjectRecord>> watchProjects() =>
      (_db.select(_db.chatProjects)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch()
          .map((rows) => rows.map(_toProject).toList());

  ChatProjectRecord _toProject(ChatProject row) => ChatProjectRecord(
    id: row.id,
    name: row.name,
    description: row.description,
    memory: row.memory,
  );

  Future<ChatProjectRecord?> loadProject(int id) async {
    final row = await (_db.select(
      _db.chatProjects,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toProject(row);
  }

  Future<ChatProjectRecord?> projectForConversation(int id) async {
    final row = await (_db.select(
      _db.chatConversations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.projectId == null ? null : loadProject(row!.projectId!);
  }

  Future<int> createProject(String name, {String description = ''}) => _db
      .into(_db.chatProjects)
      .insert(
        ChatProjectsCompanion.insert(
          name: name.trim(),
          description: Value(description.trim()),
        ),
      );

  Future<void> updateProject(
    int id, {
    required String name,
    required String description,
    required String memory,
  }) => (_db.update(_db.chatProjects)..where((t) => t.id.equals(id))).write(
    ChatProjectsCompanion(
      name: Value(name.trim()),
      description: Value(description.trim()),
      memory: Value(memory.trim()),
    ),
  );

  Future<void> rememberProjectFact(int id, String fact) =>
      _db.transaction(() async {
        final project = await loadProject(id);
        if (project == null) throw StateError('Project no longer exists.');
        final lines = project.memory
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
        if (!lines.any(
          (line) => line.trim().toLowerCase() == fact.trim().toLowerCase(),
        )) {
          lines.add(fact.trim());
        }
        await updateProject(
          id,
          name: project.name,
          description: project.description,
          memory: lines.join('\n'),
        );
      });

  Future<void> moveConversation(int id, int? projectId) async {
    if (projectId != null && await loadProject(projectId) == null) {
      throw ArgumentError('Project does not exist.');
    }
    await (_db.update(_db.chatConversations)..where((t) => t.id.equals(id)))
        .write(ChatConversationsCompanion(projectId: Value(projectId)));
  }

  Future<void> deleteProject(int id) => _db.transaction(() async {
    await (_db.update(_db.chatConversations)
          ..where((t) => t.projectId.equals(id)))
        .write(const ChatConversationsCompanion(projectId: Value(null)));
    await (_db.delete(_db.chatProjects)..where((t) => t.id.equals(id))).go();
  });

  Future<int> addArtifact({
    int? conversationId,
    required String name,
    required String path,
    required String mimeType,
    DateTime? createdAt,
  }) => _db
      .into(_db.chatArtifacts)
      .insert(
        ChatArtifactsCompanion.insert(
          conversationId: Value(conversationId),
          name: name,
          path: path,
          mimeType: mimeType,
          createdAt: createdAt == null
              ? const Value.absent()
              : Value(createdAt),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  Stream<List<ChatArtifactRecord>> watchArtifacts() =>
      (_db.select(
        _db.chatArtifacts,
      )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch().map(
        (rows) => rows
            .map(
              (row) => ChatArtifactRecord(
                id: row.id,
                conversationId: row.conversationId,
                name: row.name,
                path: row.path,
                mimeType: row.mimeType,
                createdAt: row.createdAt,
              ),
            )
            .toList(),
      );

  /// Index pictures saved by earlier versions without moving the files.
  Future<void> indexExistingArtifacts() async {
    final messages = await (_db.select(
      _db.chatMessages,
    )..where((t) => t.role.equals('assistant'))).get();
    for (final message in messages) {
      try {
        final metadata = jsonDecode(message.metadataJson ?? '{}');
        final path = metadata is Map ? metadata['imagePath'] : null;
        if (path is String && path.isNotEmpty) {
          await addArtifact(
            conversationId: message.conversationId,
            name: p.basename(path),
            path: path,
            mimeType: switch (p.extension(path).toLowerCase()) {
              '.jpg' || '.jpeg' => 'image/jpeg',
              '.webp' => 'image/webp',
              _ => 'image/png',
            },
            createdAt: message.createdAt,
          );
        }
      } on FormatException {
        continue;
      }
    }
  }

  Future<int> createConversation({String? title, int? projectId}) async {
    if (projectId != null && await loadProject(projectId) == null) {
      throw ArgumentError('Project does not exist.');
    }
    return _db
        .into(_db.chatConversations)
        .insert(
          ChatConversationsCompanion.insert(
            title: title ?? currentL.assistantNewConversation,
            projectId: Value(projectId),
          ),
        );
  }

  Future<void> renameConversation(int id, String title) {
    return (_db.update(
      _db.chatConversations,
    )..where((t) => t.id.equals(id))).write(
      ChatConversationsCompanion(
        title: Value(title),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setPinned(int id, bool pinned) {
    return (_db.update(_db.chatConversations)..where((t) => t.id.equals(id)))
        .write(ChatConversationsCompanion(pinned: Value(pinned)));
  }

  Future<void> deleteConversation(int id) => _db.transaction(() async {
    await (_db.update(_db.chatArtifacts)
          ..where((t) => t.conversationId.equals(id)))
        .write(const ChatArtifactsCompanion(conversationId: Value(null)));
    await (_db.delete(
      _db.chatMessages,
    )..where((t) => t.conversationId.equals(id))).go();
    await (_db.delete(
      _db.chatConversations,
    )..where((t) => t.id.equals(id))).go();
  });

  /// Deletes every conversation that has no messages — i.e. ones that were
  /// created but never used. Called on app close so the list stays clean.
  Future<void> purgeEmptyConversations() async {
    final conversations = await (_db.select(_db.chatConversations)).get();
    for (final c in conversations) {
      final messages =
          await (_db.select(_db.chatMessages)
                ..where((t) => t.conversationId.equals(c.id))
                ..limit(1))
              .get();
      if (messages.isEmpty) {
        await (_db.delete(
          _db.chatConversations,
        )..where((t) => t.id.equals(c.id))).go();
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
    await _db
        .into(_db.chatMessages)
        .insert(
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
        projectId: row.projectId,
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
