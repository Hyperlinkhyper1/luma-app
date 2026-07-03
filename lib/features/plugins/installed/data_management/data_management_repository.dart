import 'dart:convert';
import 'package:drift/drift.dart';

import 'data/data_management_database.dart';

// ─── Domain models ───────────────────────────────────────────────────────────

/// A parsed column definition.
class DataColumnDef {
  const DataColumnDef({required this.name, this.type = 'text'});
  final String name;
  final String type; // 'text', 'number', 'date'

  factory DataColumnDef.fromJson(Map<String, dynamic> json) => DataColumnDef(
        name: json['name'] as String,
        type: json['type'] as String? ?? 'text',
      );

  Map<String, dynamic> toJson() => {'name': name, 'type': type};
}

/// A single dataset with its column schema.
class DatasetRecord {
  const DatasetRecord({
    required this.id,
    required this.name,
    required this.columns,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final List<DataColumnDef> columns;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// One row in a dataset, with values keyed by column index.
class DataRowRecord {
  const DataRowRecord({
    required this.id,
    required this.datasetId,
    required this.values,
    required this.orderIndex,
  });

  final int id;
  final int datasetId;
  final Map<String, String> values; // column index string -> value
  final int orderIndex;

  String valueAt(int colIndex) => values[colIndex.toString()] ?? '';
}

// ─── Repository ──────────────────────────────────────────────────────────────

class DataManagementRepository {
  DataManagementRepository(this._db);
  final DataManagementDatabase _db;

  // ── Datasets ───────────────────────────────────────────────────────────────

  Stream<List<DatasetRecord>> watchDatasets() {
    final query = _db.select(_db.dataDatasets)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map((rows) => rows.map(_toDataset).toList(growable: false));
  }

  Future<DatasetRecord?> getDataset(int id) async {
    final row = await (_db.select(_db.dataDatasets)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDataset(row);
  }

  Future<int> createDataset(String name) async {
    return _db.into(_db.dataDatasets).insert(
          DataDatasetsCompanion.insert(name: name),
        );
  }

  Future<void> renameDataset(int id, String name) async {
    await (_db.update(_db.dataDatasets)..where((t) => t.id.equals(id)))
        .write(DataDatasetsCompanion(name: Value(name), updatedAt: Value(DateTime.now())));
  }

  Future<void> updateColumns(int id, List<DataColumnDef> columns) async {
    final json = jsonEncode(columns.map((c) => c.toJson()).toList());
    await (_db.update(_db.dataDatasets)..where((t) => t.id.equals(id)))
        .write(DataDatasetsCompanion(columnsJson: Value(json), updatedAt: Value(DateTime.now())));
  }

  Future<void> deleteDataset(int id) async {
    await (_db.delete(_db.dataRows)..where((t) => t.datasetId.equals(id))).go();
    await (_db.delete(_db.dataDatasets)..where((t) => t.id.equals(id))).go();
  }

  // ── Rows ───────────────────────────────────────────────────────────────────

  Stream<List<DataRowRecord>> watchRows(int datasetId) {
    final query = _db.select(_db.dataRows)
      ..where((t) => t.datasetId.equals(datasetId))
      ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]);
    return query.watch().map((rows) => rows.map(_toRow).toList(growable: false));
  }

  Future<List<DataRowRecord>> getRows(int datasetId) async {
    final query = _db.select(_db.dataRows)
      ..where((t) => t.datasetId.equals(datasetId))
      ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]);
    final rows = await query.get();
    return rows.map(_toRow).toList(growable: false);
  }

  Future<int> addRow(int datasetId, Map<String, String> values) async {
    final maxOrder = await _db.customSelect(
      'SELECT MAX(order_index) as max_order FROM data_rows WHERE dataset_id = ?',
      variables: [Variable.withInt(datasetId)],
    ).getSingleOrNull();
    final nextOrder = (maxOrder?.data['max_order'] as int?) ?? -1;
    return _db.into(_db.dataRows).insert(
          DataRowsCompanion.insert(
            datasetId: datasetId,
            valuesJson: Value(jsonEncode(values)),
            orderIndex: Value(nextOrder + 1),
          ),
        );
  }

  Future<void> updateRow(int id, Map<String, String> values) async {
    await (_db.update(_db.dataRows)..where((t) => t.id.equals(id)))
        .write(DataRowsCompanion(valuesJson: Value(jsonEncode(values))));
  }

  Future<void> deleteRow(int id) async {
    await (_db.delete(_db.dataRows)..where((t) => t.id.equals(id))).go();
  }

  Future<void> reorderRows(int datasetId, List<int> rowIdsInOrder) async {
    await _db.transaction(() async {
      for (var i = 0; i < rowIdsInOrder.length; i++) {
        await (_db.update(_db.dataRows)..where((t) => t.id.equals(rowIdsInOrder[i])))
            .write(DataRowsCompanion(orderIndex: Value(i)));
      }
    });
  }

  Future<void> importRows(int datasetId, List<Map<String, String>> rows) async {
    await _db.transaction(() async {
      for (final values in rows) {
        await _db.into(_db.dataRows).insert(
              DataRowsCompanion.insert(
                datasetId: datasetId,
                valuesJson: Value(jsonEncode(values)),
              ),
            );
      }
    });
  }

  Future<void> clearRows(int datasetId) async {
    await (_db.delete(_db.dataRows)..where((t) => t.datasetId.equals(datasetId))).go();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  DatasetRecord _toDataset(DataDataset row) {
    List<dynamic> cols = [];
    try {
      cols = jsonDecode(row.columnsJson) as List;
    } catch (_) {}
    return DatasetRecord(
      id: row.id,
      name: row.name,
      columns: cols.map((c) => DataColumnDef.fromJson(c as Map<String, dynamic>)).toList(),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  DataRowRecord _toRow(DataRow row) {
    Map<String, dynamic> vals = {};
    try {
      vals = jsonDecode(row.valuesJson) as Map<String, dynamic>;
    } catch (_) {}
    return DataRowRecord(
      id: row.id,
      datasetId: row.datasetId,
      values: vals.map((k, v) => MapEntry(k, v.toString())),
      orderIndex: row.orderIndex,
    );
  }

  // ── Sync export / import (for backup) ────────────────────────────────────────

  Future<Map<String, dynamic>> exportDataset(int datasetId) async {
    final dataset = await getDataset(datasetId);
    if (dataset == null) return {};
    final rows = await getRows(datasetId);
    return {
      'name': dataset.name,
      'columns': dataset.columns.map((c) => c.toJson()).toList(),
      'rows': rows.map((r) => r.values).toList(),
    };
  }

  Future<int> importDataset(Map<String, dynamic> data) async {
    final name = data['name'] as String? ?? 'Imported';
    final columns = (data['columns'] as List? ?? []).map((c) => DataColumnDef.fromJson(c as Map<String, dynamic>)).toList();
    final id = await createDataset(name);
    await updateColumns(id, columns);
    final rows = (data['rows'] as List? ?? []).cast<Map<String, dynamic>>();
    await importRows(id, rows.map((r) => r.map((k, v) => MapEntry(k, v.toString())).cast<String, String>()).toList());
    return id;
  }
}
