import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'chat_database.g.dart';

class ChatConversations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 0, max: 200)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
}

class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get conversationId =>
      integer().references(ChatConversations, #id)();

  /// 'user', 'assistant', or 'error'.
  TextColumn get role => text()();
  TextColumn get content => text()();

  /// Optional JSON blob for extra render hints on this message, e.g.
  /// `{"qrUrl": "..."}` when a tool call generated a QR code this turn.
  TextColumn get metadataJson => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [ChatConversations, ChatMessages])
class ChatDatabase extends _$ChatDatabase {
  ChatDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_chat',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(chatConversations, chatConversations.pinned);
          }
        },
      );
}
