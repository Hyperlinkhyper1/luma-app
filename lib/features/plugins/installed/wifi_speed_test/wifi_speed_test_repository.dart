import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../storage/storage_guard.dart';

class SpeedTestResult {
  SpeedTestResult({
    required this.id,
    required this.testedAt,
    required this.downloadMbps,
    required this.uploadMbps,
    required this.latencyMs,
  });

  final String id;
  final DateTime testedAt;
  final double downloadMbps;
  final double uploadMbps;
  final int latencyMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'testedAt': testedAt.toIso8601String(),
        'downloadMbps': downloadMbps,
        'uploadMbps': uploadMbps,
        'latencyMs': latencyMs,
      };

  factory SpeedTestResult.fromJson(Map<String, dynamic> j) => SpeedTestResult(
        id: j['id'] as String,
        testedAt: DateTime.parse(j['testedAt'] as String),
        downloadMbps: (j['downloadMbps'] as num).toDouble(),
        uploadMbps: (j['uploadMbps'] as num).toDouble(),
        latencyMs: j['latencyMs'] as int,
      );
}

class WifiSpeedTestRepository extends ChangeNotifier {
  WifiSpeedTestRepository() {
    _load();
  }

  List<SpeedTestResult> _results = [];
  List<SpeedTestResult> get results => List.unmodifiable(_results);

  File? _file;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/luma_wifi_speed_test.json');
    return _file!;
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        final list = jsonDecode(raw) as List<dynamic>;
        _results = list
            .map((e) => SpeedTestResult.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final file = await _getFile();
      await file
          .writeAsString(jsonEncode(_results.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> add(SpeedTestResult result) async {
    StorageGuard.instance.ensureWithinLimit();
    _results.add(result);
    notifyListeners();
    await _persist();
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> delete(String id) async {
    _results.removeWhere((r) => r.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> clearHistory() async {
    _results.clear();
    notifyListeners();
    await _persist();
  }

  Future<Object?> exportData() async =>
      _results.map((r) => r.toJson()).toList();

  Future<void> importData(Object? data) async {
    if (data is! List) {
      throw const FormatException('Invalid speed test snapshot.');
    }
    _results = data
        .map((e) => SpeedTestResult.fromJson(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
    await _persist();
  }
}
