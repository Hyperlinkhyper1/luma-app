import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../storage/storage_guard.dart';
import 'nfc_record.dart';

/// Whether a history entry came from reading a tag or writing one.
enum NfcHistoryDirection { scanned, written }

/// One past scan or write: what the records were, which physical tag they
/// came from (best-effort — a UID isn't always readable), and when.
class NfcHistoryEntry {
  NfcHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.direction,
    required this.records,
    this.techLabel,
    this.uid,
    this.locked = false,
  });

  final String id;
  final DateTime timestamp;
  final NfcHistoryDirection direction;
  final List<EditableNdefRecord> records;
  final String? techLabel;
  final String? uid;
  final bool locked;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'direction': direction.name,
        'records': records.map((r) => r.toJson()).toList(),
        'techLabel': techLabel,
        'uid': uid,
        'locked': locked,
      };

  factory NfcHistoryEntry.fromJson(Map<String, dynamic> json) => NfcHistoryEntry(
        id: json['id']?.toString() ?? newNfcRecordId(),
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        direction: NfcHistoryDirection.values.firstWhere(
          (d) => d.name == json['direction'],
          orElse: () => NfcHistoryDirection.scanned,
        ),
        records: ((json['records'] as List?) ?? const [])
            .map((e) => EditableNdefRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
        techLabel: json['techLabel']?.toString(),
        uid: json['uid']?.toString(),
        locked: json['locked'] == true,
      );
}

/// A named, reusable set of records — save one from the editor once, then
/// write it to as many tags as you like without rebuilding it each time.
class NfcTagTemplate {
  NfcTagTemplate({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.records,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<EditableNdefRecord> records;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'records': records.map((r) => r.toJson()).toList(),
      };

  factory NfcTagTemplate.fromJson(Map<String, dynamic> json) => NfcTagTemplate(
        id: json['id']?.toString() ?? newNfcRecordId(),
        name: json['name']?.toString() ?? 'Template',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        records: ((json['records'] as List?) ?? const [])
            .map((e) => EditableNdefRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Flat-file (JSON) store for the NFC Tag Editor plugin: saved write
/// templates and a running history of every tag scanned or written.
class NfcTagStore extends ChangeNotifier {
  factory NfcTagStore() => instance;

  static final NfcTagStore instance = NfcTagStore._();

  NfcTagStore._() {
    _load();
  }

  /// Oldest entries fall off past this so the JSON file can't grow forever.
  static const _maxHistory = 300;

  List<NfcTagTemplate> _templates = [];
  List<NfcTagTemplate> get templates => List.unmodifiable(_templates);

  List<NfcHistoryEntry> _history = [];
  List<NfcHistoryEntry> get history => List.unmodifiable(_history);

  bool _loaded = false;
  bool get loaded => _loaded;

  File? _file;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file =
        File('${dir.path}${Platform.pathSeparator}luma_nfc_tag_editor.json');
    return _file!;
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _templates = ((raw['templates'] as List?) ?? const [])
            .map((e) => NfcTagTemplate.fromJson(e as Map<String, dynamic>))
            .toList();
        _history = ((raw['history'] as List?) ?? const [])
            .map((e) => NfcHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      _templates = [];
      _history = [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode({
        'templates': _templates.map((t) => t.toJson()).toList(),
        'history': _history.map((h) => h.toJson()).toList(),
      }));
    } catch (_) {}
  }

  Future<void> addHistory(NfcHistoryEntry entry) async {
    _history.insert(0, entry);
    if (_history.length > _maxHistory) {
      _history = _history.sublist(0, _maxHistory);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> removeHistory(String id) async {
    _history.removeWhere((h) => h.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> clearHistory() async {
    if (_history.isEmpty) return;
    _history = [];
    notifyListeners();
    await _persist();
  }

  Future<void> saveTemplate(String name, List<EditableNdefRecord> records) async {
    StorageGuard.instance.ensureWithinLimit();
    _templates.insert(
      0,
      NfcTagTemplate(
        id: newNfcRecordId(),
        name: name,
        createdAt: DateTime.now(),
        records: records.map((r) => r.copyWith()).toList(),
      ),
    );
    notifyListeners();
    await _persist();
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> deleteTemplate(String id) async {
    _templates.removeWhere((t) => t.id == id);
    notifyListeners();
    await _persist();
  }
}
