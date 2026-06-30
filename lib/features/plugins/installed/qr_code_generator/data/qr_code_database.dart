import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'qr_code_database.g.dart';

/// A generated QR code's source URL and when it was made. Unlike the
/// password vault, this is not secret data — stored as plain text, no PIN.
class QrCodeEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get url => text().withLength(min: 1, max: 2000)();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [QrCodeEntries])
class QrCodeDatabase extends _$QrCodeDatabase {
  QrCodeDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_qr_codes',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 1;
}
