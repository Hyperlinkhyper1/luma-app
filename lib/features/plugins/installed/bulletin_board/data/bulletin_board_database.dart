import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'bulletin_board_database.g.dart';

/// A single item on the bulletin board (note, idea, checklist, image)
class BoardItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // "note", "idea", "checklist", "image"
  TextColumn get title => text().nullable()();
  TextColumn get content => text()(); // text content, or JSON for checklists, or path for images
  IntColumn get color => integer().withDefault(const Constant(0xFFFFFFFF))(); // Default white
  RealColumn get posX => real().withDefault(const Constant(0.0))();
  RealColumn get posY => real().withDefault(const Constant(0.0))();
  RealColumn get width => real().withDefault(const Constant(200.0))();
  RealColumn get height => real().withDefault(const Constant(200.0))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [BoardItems])
class BulletinBoardDatabase extends _$BulletinBoardDatabase {
  BulletinBoardDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_bulletin_board',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 1;
}
