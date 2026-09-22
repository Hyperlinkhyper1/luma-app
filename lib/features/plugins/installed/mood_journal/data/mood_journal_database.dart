import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'mood_journal_database.g.dart';

class MoodEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get mood => integer()(); // 1 (terrible) – 5 (great)
  TextColumn get note => text().nullable()();
  TextColumn get tags => text().nullable()(); // JSON-encoded List<String>
  TextColumn get images => text().nullable()(); // JSON-encoded List<String> (paths)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [MoodEntries])
class MoodJournalDatabase extends _$MoodJournalDatabase {
  MoodJournalDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_mood_journal',
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
          // schemaVersion was bumped to 2 for this column, but the
          // migration to actually add it was never written — every device
          // still on a version-1 file has no `images` column at all, so any
          // query touching it (drift always selects every declared column)
          // fails with "no such column: images" the moment mood_journal is
          // opened.
          if (from < 2) {
            await m.addColumn(moodEntries, moodEntries.images);
          }
        },
      );
}
