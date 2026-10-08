import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../l10n/current_l.dart';
import '../../../../storage/storage_guard.dart';

class DownloadHistoryEntry {
  DownloadHistoryEntry({
    required this.title,
    required this.filePath,
    required this.mode,
    required this.detail,
    required this.completedAt,
    this.source = 'YouTube',
  });

  final String title;
  final String filePath;
  final String mode; // 'Video' or 'Audio'
  final String detail; // e.g. "1080p Â· 192 kbps" or "MP3 Â· 320 kbps"
  final DateTime completedAt;
  final String source; // 'YouTube' or 'Spotify'

  Map<String, dynamic> toJson() => {
        'title': title,
        'filePath': filePath,
        'mode': mode,
        'detail': detail,
        'completedAt': completedAt.toIso8601String(),
        'source': source,
      };

  factory DownloadHistoryEntry.fromJson(Map<String, dynamic> json) =>
      DownloadHistoryEntry(
        title: json['title']?.toString() ?? '',
        filePath: json['filePath']?.toString() ?? '',
        mode: json['mode']?.toString() ?? 'Video',
        detail: json['detail']?.toString() ?? '',
        completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? '') ??
            DateTime.now(),
        // Older entries predate Spotify support and were always YouTube.
        source: json['source']?.toString() ?? 'YouTube',
      );
}

/// Flat-file (JSON) history of completed downloads. Kept deliberately simple
/// rather than a full drift table since this is a small, append-mostly list.
class DownloadHistoryStore {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    // Filename predates Spotify support and stays as-is so existing users'
    // history isn't orphaned by a purely cosmetic rename.
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
    revision.value++;
  }

  /// Bumped on every write; drives sync, since the store has no instance
  /// that outlives the page.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  Future<Object?> exportData() async =>
      (await load()).map((e) => e.toJson()).toList();

  /// Merges by file path: each device downloaded its own files, so another
  /// device's history adds to this one rather than replacing it.
  Future<void> importData(Object? data) async {
    if (data is! List) {
      throw FormatException(currentL.mediaDlHistoryInvalidSnapshot);
    }
    final entries = await load();
    final known = entries.map((e) => e.filePath).toSet();
    for (final raw in data) {
      if (raw is! Map<String, dynamic>) continue;
      final entry = DownloadHistoryEntry.fromJson(raw);
      if (known.add(entry.filePath)) entries.add(entry);
    }
    entries.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    await _save(entries);
  }
}
