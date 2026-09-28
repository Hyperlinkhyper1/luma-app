import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'text_library_database.g.dart';

@DataClassName('LibrarySubjectRow')
class LibrarySubjects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Index into `DyeColor`.
  IntColumn get color => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('LibraryTextRow')
class LibraryTexts extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The owning subject. Not a foreign key: a synced import can bring texts
  /// in before their subject, and the repository deletes a subject's texts
  /// itself.
  IntColumn get subjectId => integer()();
  TextColumn get title => text()();
  TextColumn get spine => text().withDefault(const Constant(''))();

  /// A `RichDoc` as JSON.
  TextColumn get body => text().withDefault(const Constant(''))();

  /// Index into `DyeColor`; 12 is brown leather.
  IntColumn get cover => integer().withDefault(const Constant(12))();
  IntColumn get slot => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [LibrarySubjects, LibraryTexts])
class TextLibraryDatabase extends _$TextLibraryDatabase {
  TextLibraryDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'luma_text_library',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}
