import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'errands_database.g.dart';

/// User-defined checklist groups (e.g. "Household", "Health", "Admin").
/// Errands reference a category by id; deleting a category leaves its
/// errands uncategorized rather than deleting them.
class ErrandCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// ARGB accent color for the category's dot / section header.
  IntColumn get color => integer().withDefault(const Constant(0xFF2F80ED))();

  /// Manual ordering in the checklist; lower comes first.
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A recurring errand. The schedule is `repeatEvery` × `repeatUnit`
/// ('days' | 'weeks' | 'months'); daily is days/1, weekly weeks/1, monthly
/// months/1, and custom intervals are days/N. Completing an errand stamps
/// [lastDone] and advances [nextDue] from today; snoozing just pushes
/// [nextDue] forward without touching the schedule.
class Errands extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// References [ErrandCategories.id]; null = uncategorized. Kept as a plain
  /// int (no FK constraint) so category deletion can simply null it out.
  IntColumn get categoryId => integer().nullable()();

  TextColumn get repeatUnit => text().withDefault(const Constant('days'))();
  IntColumn get repeatEvery => integer().withDefault(const Constant(1))();

  /// The next date this errand appears on the checklist (stored at local
  /// midnight; anything <= today counts as due).
  DateTimeColumn get nextDue => dateTime()();

  /// When it was last checked off; used to show it under "Done today" and
  /// allow unchecking.
  DateTimeColumn get lastDone => dateTime().nullable()();

  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [ErrandCategories, Errands])
class ErrandsDatabase extends _$ErrandsDatabase {
  ErrandsDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_errands',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 1;
}
