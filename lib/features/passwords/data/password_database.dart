import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'password_database.g.dart';

/// A stored credential. The [passwordCipher] column holds the password
/// encrypted at rest (see [PasswordCrypto]); every other field is stored as
/// entered.
class PasswordEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// What the credential is for (the service name).
  TextColumn get service => text().withLength(min: 1, max: 120)();
  TextColumn get email => text().withLength(min: 1, max: 200)();

  /// The password, encrypted. Never store the plaintext here.
  TextColumn get passwordCipher => text()();

  TextColumn get username => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get info => text().nullable()();
  TextColumn get icon => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [PasswordEntries])
class PasswordDatabase extends _$PasswordDatabase {
  PasswordDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_passwords',
              // Keep the vault in the app's local support directory (not
              // Documents, which can be OneDrive-synced) so secrets stay local.
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(passwordEntries, passwordEntries.icon);
          }
        },
      );
}
