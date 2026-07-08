import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../../storage/storage_guard.dart';

class DownloadHistoryEntry {
  DownloadHistoryEntry({
    required this.title,
    required this.filePath,
    required this.mode,
    required this.detail,
    required this.completedAt,
  });

  final String title;
  final String filePath;
  final String mode; // 'Video' or 'Audio'
  final String detail; // e.g. "1080p · 192 kbps" or "MP3 · 320 kbps"
  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
        'title': title,
        'filePath': filePath,
        'mode': mode,
        'detail': detail,
        'completedAt': completedAt.toIso8601String(),
      };

  factory DownloadHistoryEntry.fromJson(Map<String, dynamic> json) =>
      DownloadHistoryEntry(
        title: json['title']?.toString() ?? '',
        filePath: json['filePath']?.toString() ?? '',
        mode: json['mode']?.toString() ?? 'Video',
        detail: json['detail']?.toString() ?? '',
        completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// Flat-file (JSON) history of completed downloads. Kept deliberately simple
/// rather than a full drift table since this is a small, append-mostly list.
class DownloadHistoryStore {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}youtube_downloads.json');
  }

  Future<List<DownloadHistoryEntry>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    try {
      final raw = jsonDecode(await file.readAsString()) as List;
      return raw
          .map((e) => DownloadHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> add(DownloadHistoryEntry entry) async {
    StorageGuard.instance.ensureWithinLimit();
    final entries = await load();
    entries.insert(0, entry);
    await _save(entries);
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> remove(DownloadHistoryEntry entry) async {
    final entries = await load();
    entries.removeWhere((e) => e.filePath == entry.filePath);
    await _save(entries);
  }

  Future<void> _save(List<DownloadHistoryEntry> entries) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(entries.map((e) => e.toJson()).toList()));
  }
}
