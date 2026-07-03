import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;

import '../features/passwords/data/password_database.dart';
import '../features/passwords/password_crypto.dart';

/// One syncable unit of app data (a feature's storage). Adapters know how to
/// snapshot their feature to a JSON-encodable object and how to restore it.
abstract class SyncCollection {
  /// Stable server-side name: lowercase letters, digits, underscores.
  String get id;

  /// Human name shown next to the toggle in Settings.
  String get label;

  IconData get icon;

  /// Fires whenever the underlying data changes (drives auto-sync).
  Stream<void> get changes;

  /// Snapshots the current local data as a JSON-encodable object.
  Future<Object?> export();

  /// Replaces the local data with a previously exported snapshot.
  Future<void> import(Object? data);
}

/// Generic adapter for a Drift database: exports every table's raw rows and
/// restores them wholesale inside a transaction. Works for any schema, so
/// new features stay syncable without extra code.
class DriftSyncCollection extends SyncCollection {
  DriftSyncCollection({
    required this.id,
    required this.label,
    required this.icon,
    required this.db,
  });

  @override
  final String id;
  @override
  final String label;
  @override
  final IconData icon;

  final GeneratedDatabase db;

  @override
  Stream<void> get changes =>
      db.tableUpdates(TableUpdateQuery.any()).map((_) {});

  /// Hook for subclasses to rewrite a row on export (returns a new map).
  @protected
  Future<Map<String, Object?>> transformExportRow(
          String table, Map<String, Object?> row) async =>
      row;

  /// Hook for subclasses to rewrite a row on import.
  @protected
  Future<Map<String, Object?>> transformImportRow(
          String table, Map<String, Object?> row) async =>
      row;

  @override
  Future<Object?> export() async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in db.allTables) {
      final name = table.actualTableName;
      final rows = await db.customSelect('SELECT * FROM "$name"').get();
      final exported = <Map<String, Object?>>[];
      for (final row in rows) {
        exported.add(
            _encodeRow(await transformExportRow(name, Map.of(row.data))));
      }
      tables[name] = exported;
    }
    return {
      'format': 1,
      'schemaVersion': db.schemaVersion,
      'tables': tables,
    };
  }

  @override
  Future<void> import(Object? data) async {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid snapshot.');
    }
    final snapshotSchema = data['schemaVersion'] as int? ?? 0;
    if (snapshotSchema > db.schemaVersion) {
      throw StateError(
          'This snapshot came from a newer app version. Update the app on '
          'this device first.');
    }
    final tables = data['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const FormatException('Invalid snapshot.');
    }

    await db.transaction(() async {
      // References between rows are restored as a whole; don't check them
      // until the transaction commits.
      await db.customStatement('PRAGMA defer_foreign_keys = ON');

      // Children first on delete (declaration order lists parents first).
      for (final table in db.allTables.toList().reversed) {
        await db.delete(table).go();
      }
      for (final table in db.allTables) {
        final name = table.actualTableName;
        final rows = tables[name];
        if (rows is! List) continue;
        for (final raw in rows) {
          if (raw is! Map<String, dynamic>) continue;
          final row =
              await transformImportRow(name, _decodeRow(Map.of(raw)));
          final columns = [
            for (final key in row.keys)
              if (_isColumn(table, key)) key,
          ];
          if (columns.isEmpty) continue;
          await db.customInsert(
            'INSERT INTO "$name" '
            '(${columns.map((c) => '"$c"').join(', ')}) '
            'VALUES (${List.filled(columns.length, '?').join(', ')})',
            variables: [for (final c in columns) Variable(row[c])],
          );
        }
      }
    });
    db.markTablesUpdated(db.allTables);
  }

  static bool _isColumn(TableInfo table, String name) =>
      table.columnsByName.containsKey(name);

  /// SQLite values are int/double/String/blob/null; only blobs need special
  /// treatment to survive the JSON round trip.
  static Map<String, Object?> _encodeRow(Map<String, Object?> row) =>
      row.map((key, value) => MapEntry(
          key,
          value is Uint8List
              ? {'__bytes__': base64Encode(value)}
              : value));

  static Map<String, Object?> _decodeRow(Map<String, Object?> row) =>
      row.map((key, value) => MapEntry(
          key,
          value is Map<String, dynamic> && value['__bytes__'] is String
              ? Uint8List.fromList(base64Decode(value['__bytes__'] as String))
              : value));
}

/// The password vault. Password ciphers are bound to this device's local key
/// file, so on export they are decrypted (the snapshot itself is end-to-end
/// encrypted before upload) and on import re-encrypted with this device's key.
class PasswordVaultSyncCollection extends DriftSyncCollection {
  PasswordVaultSyncCollection({
    required PasswordDatabase db,
    required this.crypto,
  }) : super(
          id: 'passwords',
          label: 'Passwords',
          icon: Icons.password_rounded,
          db: db,
        );

  final PasswordCrypto crypto;

  @override
  Future<Map<String, Object?>> transformExportRow(
      String table, Map<String, Object?> row) async {
    if (table == 'password_entries') {
      final cipher = row.remove('password_cipher');
      row['password_plain'] = cipher is String ? crypto.decrypt(cipher) : '';
    }
    return row;
  }

  @override
  Future<Map<String, Object?>> transformImportRow(
      String table, Map<String, Object?> row) async {
    if (table == 'password_entries') {
      final plain = row.remove('password_plain');
      row['password_cipher'] = crypto.encrypt(plain is String ? plain : '');
    }
    return row;
  }
}

/// Adapter for the JSON-file-backed repositories (notes, price tracker).
class JsonStoreSyncCollection extends SyncCollection {
  JsonStoreSyncCollection({
    required this.id,
    required this.label,
    required this.icon,
    required Listenable listenable,
    required this.exporter,
    required this.importer,
  }) {
    listenable.addListener(_notify);
  }

  @override
  final String id;
  @override
  final String label;
  @override
  final IconData icon;

  final Future<Object?> Function() exporter;
  final Future<void> Function(Object? data) importer;
  final _controller = StreamController<void>.broadcast();

  void _notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  @override
  Stream<void> get changes => _controller.stream;

  @override
  Future<Object?> export() => exporter();

  @override
  Future<void> import(Object? data) => importer(data);
}
