import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'calendar_database.g.dart';

/// A single calendar event. Like the other productivity plugins this is not
/// secret data, so it's stored as plain rows with no PIN gate.
///
/// [start]/[end] are stored as local wall-clock datetimes. For all-day events
/// the time component is ignored and only the date matters. Recurring events
/// store a single "template" row here; concrete occurrences are expanded on
/// the fly for whatever range the UI is showing (see `recurrence.dart`).
class CalendarEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();

  /// ARGB color of the event's chip/dot.
  IntColumn get color => integer().withDefault(const Constant(0xFF7C5AD9))();

  /// One of: none, daily, weekly, monthly, yearly.
  TextColumn get recurrence =>
      text().withDefault(const Constant('none'))();

  /// Optional inclusive date after which a recurring event stops repeating.
  DateTimeColumn get recurrenceEnd => dateTime().nullable()();

  /// Minutes before the start to surface a reminder label (null = none).
  IntColumn get reminderMinutes => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// The dinner planned for a given day. At most one row per [date]; setting a
/// new dinner for a day that already has one overwrites it (see
/// `CalendarRepository.setDinner`).
class DinnerPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get title => text().withLength(min: 1, max: 200)();

  /// One ingredient per line.
  TextColumn get ingredients => text().withDefault(const Constant(''))();
  TextColumn get instructions => text().nullable()();
  IntColumn get servings => integer().nullable()();

  /// Total prep + cook time, in minutes.
  IntColumn get minutes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [CalendarEvents, DinnerPlans])
class CalendarDatabase extends _$CalendarDatabase {
  CalendarDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_calendar',
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
            await m.createTable(dinnerPlans);
          }
        },
      );
}
