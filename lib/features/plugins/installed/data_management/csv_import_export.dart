import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'data_management_repository.dart';

/// CSV import / export helpers for datasets.
class CsvHelper {
  /// Import a CSV file into a list of row value maps.
  /// Uses the first row as column headers. Returns (columnDefs, rows).
  static Future<(List<DataColumnDef>, List<Map<String, String>>)?> importCsv() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return null;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) return null;

    // Parse header
    final headers = _parseLine(lines.first);
    final columns = headers.map((h) {
      // Try to guess type from first data row
      String type = 'text';
      if (lines.length > 1) {
        final firstData = _parseLine(lines[1]);
        final idx = headers.indexOf(h);
        if (idx >= 0 && idx < firstData.length) {
          if (double.tryParse(firstData[idx].replaceAll(',', '.')) != null) {
            type = 'number';
          }
        }
      }
      return DataColumnDef(name: h, type: type);
    }).toList();

    final rows = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      final values = _parseLine(lines[i]);
      if (values.isEmpty || values.every((v) => v.trim().isEmpty)) continue;
      final row = <String, String>{};
      for (var j = 0; j < columns.length && j < values.length; j++) {
        row[j.toString()] = values[j];
      }
      rows.add(row);
    }

    return (columns, rows);
  }

  /// Export a dataset to a CSV file. Prompts user for save location.
  static Future<bool> exportCsv(DatasetRecord dataset, List<DataRowRecord> rows) async {
    final buffer = StringBuffer();
    // Header
    buffer.writeln(dataset.columns.map((c) => _escape(c.name)).join(','));
    // Rows
    for (final row in rows) {
      final values = [
        for (var i = 0; i < dataset.columns.length; i++)
          _escape(row.valueAt(i)),
      ];
      buffer.writeln(values.join(','));
    }

    final outputPath = await FilePicker.saveFile(
      dialogTitle: 'Save CSV',
      fileName: '${dataset.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (outputPath == null) return false;

    final file = File(outputPath);
    await file.writeAsString(buffer.toString());
    return true;
  }

  // Simple CSV line parser (handles commas, not quotes for simplicity)
  static List<String> _parseLine(String line) {
    return line.split(',');
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('\n') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
