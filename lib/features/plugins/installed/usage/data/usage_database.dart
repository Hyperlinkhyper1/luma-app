import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'usage_database.g.dart';

/// One continuous window during which the foreground app stayed the same.
/// A session is created the first time we see an app, and closed the moment
/// a different app comes to the foreground (or tracking is paused / luma
/// shuts down). [startedAt] and [endedAt] are stored as UTC; the UI converts
/// to local time when rendering ranges.
class UsageSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get appName => text()();
  TextColumn get processName => text()();
  TextColumn get windowTitle => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get durationSeconds => integer()();
}

@DriftDatabase(tables: [UsageSessions])
class UsageDatabase extends _$UsageDatabase {
  UsageDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_usage',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 1;
}