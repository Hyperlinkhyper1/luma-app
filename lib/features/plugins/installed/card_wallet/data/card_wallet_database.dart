import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'card_wallet_database.g.dart';

/// A saved wallet card: a loyalty/membership pass reduced to the one thing you
/// present at the till — a barcode value (with its symbology) or an NFC tag
/// payload. Not secret data like the password vault, so it's stored as plain
/// text with no PIN gate.
class WalletCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();

  /// The value presented: a barcode number for barcode formats, or the raw
  /// tag payload for [format] == 'nfc'.
  TextColumn get code => text().withLength(min: 0, max: 4096)();

  /// A [CardFormat] enum name — see card_formats.dart.
  TextColumn get format => text().withDefault(const Constant('code128'))();

  /// Optional grouping label (e.g. "Loyalty", "Membership", "Transit").
  TextColumn get category => text().nullable()();

  /// ARGB accent color for the card tile.
  IntColumn get color => integer().withDefault(const Constant(0xFF7C5AD9))();

  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [WalletCards])
class CardWalletDatabase extends _$CardWalletDatabase {
  CardWalletDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_card_wallet',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 1;
}
