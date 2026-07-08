import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../../storage/storage_guard.dart';
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

/// A user-defined tag on a dataset: a name plus a display color.
class DataTagDef {
  const DataTagDef({required this.name, required this.colorValue});
  final String name;
  final int colorValue; // ARGB int

  factory DataTagDef.fromJson(Map<String, dynamic> json) => DataTagDef(
        name: json['name'] as String,
        colorValue: json['color'] as int? ?? 0xFFB49DF5,
      );

  Map<String, dynamic> toJson() => {'name': name, 'color': colorValue};
}

/// A single dataset with its column schema and tag definitions.
class DatasetRecord {
  const DatasetRecord({
    required this.id,
    required this.name,
    required this.columns,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final List<DataColumnDef> columns;
  final List<DataTagDef> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  DataTagDef? tagByName(String name) {
    for (final t in tags) {
      if (t.name == name) return t;
    }
    return null;
  }
}

/// One row in a dataset, with values keyed by column index.
class DataRowRecord {
  const DataRowRecord({
    required this.id,
    required this.datasetId,
    required this.values,
    required this.tags,
    required this.orderIndex,
  });

  final int id;
  final int datasetId;
  final Map<String, String> values; // column index string -> value
  final List<String> tags; // tag names from the dataset's tag list
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
    StorageGuard.instance.ensureWithinLimit();
    final id = await _db.into(_db.dataDatasets).insert(
          DataDatasetsCompanion.insert(name: name),
        );
    StorageGuard.instance.scheduleRefresh();
    return id;
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

  // ── Tags ───────────────────────────────────────────────────────────────────

  Future<void> updateTags(int id, List<DataTagDef> tags) async {
    final json = jsonEncode(tags.map((t) => t.toJson()).toList());
    await (_db.update(_db.dataDatasets)..where((t) => t.id.equals(id)))
        .write(DataDatasetsCompanion(tagsJson: Value(json), updatedAt: Value(DateTime.now())));
  }

  /// Renames a tag on the dataset and in every row that carries it.
  Future<void> renameTag(int datasetId, String oldName, DataTagDef updated) async {
    final dataset = await getDataset(datasetId);
    if (dataset == null) return;
    final tags = dataset.tags
        .map((t) => t.name == oldName ? updated : t)
        .toList(growable: false);
    await updateTags(datasetId, tags);
    if (oldName == updated.name) return;
    final rows = await getRows(datasetId);
    for (final row in rows) {
      if (!row.tags.contains(oldName)) continue;
      final newTags = row.tags.map((t) => t == oldName ? updated.name : t).toList();
      await setRowTags(row.id, newTags);
    }
  }

  /// Deletes a tag from the dataset and strips it from every row.
  Future<void> deleteTag(int datasetId, String name) async {
    final dataset = await getDataset(datasetId);
    if (dataset == null) return;
    await updateTags(
      datasetId,
      dataset.tags.where((t) => t.name != name).toList(growable: false),
    );
    final rows = await getRows(datasetId);
    for (final row in rows) {
      if (!row.tags.contains(name)) continue;
      await setRowTags(row.id, row.tags.where((t) => t != name).toList());
    }
  }

  Future<void> setRowTags(int rowId, List<String> tags) async {
    await (_db.update(_db.dataRows)..where((t) => t.id.equals(rowId)))
        .write(DataRowsCompanion(tagsJson: Value(jsonEncode(tags))));
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

  Future<int> addRow(int datasetId, Map<String, String> values,
      {List<String> tags = const []}) async {
    StorageGuard.instance.ensureWithinLimit();
    final maxOrder = await _db.customSelect(
      'SELECT MAX(order_index) as max_order FROM data_rows WHERE dataset_id = ?',
      variables: [Variable.withInt(datasetId)],
    ).getSingleOrNull();
    final nextOrder = (maxOrder?.data['max_order'] as int?) ?? -1;
    final id = await _db.into(_db.dataRows).insert(
          DataRowsCompanion.insert(
            datasetId: datasetId,
            valuesJson: Value(jsonEncode(values)),
            tagsJson: Value(jsonEncode(tags)),
            orderIndex: Value(nextOrder + 1),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  /// Inserts a copy of [row] directly after it (at the end order-wise).
  Future<int> duplicateRow(DataRowRecord row) =>
      addRow(row.datasetId, row.values, tags: row.tags);

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
    List<dynamic> tags = [];
    try {
      cols = jsonDecode(row.columnsJson) as List;
    } catch (_) {}
    try {
      tags = jsonDecode(row.tagsJson) as List;
    } catch (_) {}
    return DatasetRecord(
      id: row.id,
      name: row.name,
      columns: cols.map((c) => DataColumnDef.fromJson(c as Map<String, dynamic>)).toList(),
      tags: tags.map((t) => DataTagDef.fromJson(t as Map<String, dynamic>)).toList(),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  DataRowRecord _toRow(DataRow row) {
    Map<String, dynamic> vals = {};
    List<dynamic> tags = [];
    try {
      vals = jsonDecode(row.valuesJson) as Map<String, dynamic>;
    } catch (_) {}
    try {
      tags = jsonDecode(row.tagsJson) as List;
    } catch (_) {}
    return DataRowRecord(
      id: row.id,
      datasetId: row.datasetId,
      values: vals.map((k, v) => MapEntry(k, v.toString())),
      tags: tags.map((t) => t.toString()).toList(),
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
      'tags': dataset.tags.map((t) => t.toJson()).toList(),
      'rows': [
        for (final r in rows) {'values': r.values, 'tags': r.tags},
      ],
    };
  }

  Future<int> importDataset(Map<String, dynamic> data) async {
    final name = data['name'] as String? ?? 'Imported';
    final columns = (data['columns'] as List? ?? []).map((c) => DataColumnDef.fromJson(c as Map<String, dynamic>)).toList();
    final tags = (data['tags'] as List? ?? []).map((t) => DataTagDef.fromJson(t as Map<String, dynamic>)).toList();
    final id = await createDataset(name);
    await updateColumns(id, columns);
    await updateTags(id, tags);
    for (final entry in (data['rows'] as List? ?? [])) {
      final map = entry as Map<String, dynamic>;
      // Old exports were flat value maps; new ones wrap values + tags.
      final rawValues = (map['values'] as Map<String, dynamic>?) ??
          (map..remove('tags'));
      final rowTags =
          (map['tags'] as List? ?? []).map((t) => t.toString()).toList();
      await addRow(
        id,
        rawValues.map((k, v) => MapEntry(k, v.toString())),
        tags: rowTags,
      );
    }
    return id;
  }
}
