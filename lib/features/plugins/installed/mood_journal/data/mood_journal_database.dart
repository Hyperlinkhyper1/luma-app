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
  int get schemaVersion => 1;
}
