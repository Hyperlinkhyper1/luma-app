import 'package:drift/drift.dart';

import '../../../../storage/storage_guard.dart';
import 'card_formats.dart';
import 'data/card_wallet_database.dart';

/// A saved wallet card, ready for display.
class WalletCardRecord {
  const WalletCardRecord({
    required this.id,
    required this.name,
    required this.code,
    required this.format,
    required this.color,
    required this.createdAt,
    this.category,
    this.notes,
  });

  final int id;
  final String name;
  final String code;
  final CardFormat format;
  final int color;
  final DateTime createdAt;
  final String? category;
  final String? notes;
}

/// CRUD over the local card wallet, backed by [CardWalletDatabase].
class CardWalletRepository {
  CardWalletRepository(this._db);

  final CardWalletDatabase _db;

  /// Streams all saved cards, alphabetically by name.
  Stream<List<WalletCardRecord>> watchAll() {
    final query = _db.select(_db.walletCards)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch().map(
          (rows) => rows.map(_toRecord).toList(growable: false),
        );
  }

  Future<void> add({
    required String name,
    required String code,
    required CardFormat format,
    required int color,
    String? category,
    String? notes,
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    await _db.into(_db.walletCards).insert(
          WalletCardsCompanion.insert(
            name: name,
            code: code,
            format: Value(format.name),
            color: Value(color),
            category: Value(category),
            notes: Value(notes),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> update(
    int id, {
    required String name,
    required String code,
    required CardFormat format,
    required int color,
    String? category,
    String? notes,
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    await (_db.update(_db.walletCards)..where((t) => t.id.equals(id))).write(
      WalletCardsCompanion(
        name: Value(name),
        code: Value(code),
        format: Value(format.name),
        color: Value(color),
        category: Value(category),
        notes: Value(notes),
      ),
    );
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.walletCards)..where((t) => t.id.equals(id))).go();
  }

  WalletCardRecord _toRecord(WalletCard row) => WalletCardRecord(
        id: row.id,
        name: row.name,
        code: row.code,
        format: cardFormatFromKey(row.format),
        color: row.color,
        createdAt: row.createdAt,
        category: row.category,
        notes: row.notes,
      );
}
