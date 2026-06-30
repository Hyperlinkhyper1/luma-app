import 'package:drift/drift.dart';

import 'data/qr_code_database.dart';

/// A previously generated QR code, ready for display.
class QrCodeRecord {
  const QrCodeRecord({
    required this.id,
    required this.url,
    required this.createdAt,
  });

  final int id;
  final String url;
  final DateTime createdAt;
}

/// CRUD over the local QR code history.
class QrCodeRepository {
  QrCodeRepository(this._db);

  final QrCodeDatabase _db;

  /// Streams all generated codes, newest first.
  Stream<List<QrCodeRecord>> watchAll() {
    final query = _db.select(_db.qrCodeEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map(
          (rows) => rows.map(_toRecord).toList(growable: false),
        );
  }

  Future<void> add(String url) {
    return _db.into(_db.qrCodeEntries).insert(
          QrCodeEntriesCompanion.insert(url: url),
        );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.qrCodeEntries)..where((t) => t.id.equals(id))).go();
  }

  QrCodeRecord _toRecord(QrCodeEntry row) =>
      QrCodeRecord(id: row.id, url: row.url, createdAt: row.createdAt);
}
