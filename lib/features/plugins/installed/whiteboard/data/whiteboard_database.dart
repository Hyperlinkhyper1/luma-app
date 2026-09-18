import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'whiteboard_database.g.dart';

/// One board. Boards are just a title and a timestamp; everything drawn on
/// them lives in [BoardElements].
class Boards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// A single thing drawn on a board.
///
/// The geometry is kept as a JSON blob rather than as columns because the
/// eight element kinds carry very different shapes — a pen stroke is a list of
/// hundreds of points, a sticky note is an origin plus a box — and a row per
/// point would make a stroke hundreds of rows. [WhiteboardElement] owns the
/// encoding; the table only orders rows by [z].
class BoardElements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get boardId =>
      integer().references(Boards, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get data => text()();
  IntColumn get z => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Boards, BoardElements])
class WhiteboardDatabase extends _$WhiteboardDatabase {
  WhiteboardDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_whiteboard',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Without this the cascade on BoardElements.boardId is inert, and
          // deleting a board would leave its elements behind forever.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
