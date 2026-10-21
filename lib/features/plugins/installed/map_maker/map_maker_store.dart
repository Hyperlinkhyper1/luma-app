import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../storage/storage_guard.dart';
import 'map_maker_models.dart';

/// Flat-file store for Map Maker saves. The open editor holds a working copy
/// and writes back through [put]; the hub and Saves list read from here.
class MapMakerStore extends ChangeNotifier {
  factory MapMakerStore() => instance;

  static final MapMakerStore instance = MapMakerStore._();

  MapMakerStore._() : _memory = false {
    _ready = _load();
  }

  @visibleForTesting
  MapMakerStore.memory() : _memory = true {
    _loaded = true;
    _ready = Future.value();
  }

  final bool _memory;

  late final Future<void> _ready;
  static const _persistDelay = Duration(milliseconds: 400);

  List<MapMakerSave> _saves = [];
  List<MapMakerSave> get saves => List.unmodifiable(_saves);

  bool _loaded = false;
  bool get loaded => _loaded;

  File? _file;
  Timer? _persistTimer;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}luma_map_maker.json');
    return _file!;
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        _saves = _parseList(raw);
      }
    } catch (_) {
      _saves = [];
    }
    _loaded = true;
    notifyListeners();
  }

  List<MapMakerSave> _parseList(Object? raw) {
    if (raw is! List) {
      throw const FormatException('Invalid Map Maker snapshot');
    }
    return raw
        .map((e) => MapMakerSave.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDelay, _persist);
  }

  Future<void> _persist() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    if (_memory) return;
    try {
      final file = await _getFile();
      await file.writeAsString(
        jsonEncode(_saves.map((s) => s.toJson()).toList()),
      );
    } catch (_) {}
  }

  int _lastId = 0;

  String _newId() {
    var id = DateTime.now().microsecondsSinceEpoch;
    for (final save in _saves) {
      final existing = int.tryParse(save.id);
      if (existing != null && existing > _lastId) _lastId = existing;
    }
    if (id <= _lastId) id = _lastId + 1;
    _lastId = id;
    return '$id';
  }

  MapMakerSave? byId(String id) {
    for (final save in _saves) {
      if (save.id == id) return save;
    }
    return null;
  }

  Future<MapMakerSave> createTransit({String? title}) async {
    await _ready;
    final save = MapMakerSave(
      id: _newId(),
      title: (title == null || title.trim().isEmpty)
          ? 'Untitled Transit Map'
          : title.trim(),
      kind: MapMakerKind.transit,
      updatedAt: DateTime.now(),
      transit: TransitMap.empty(
        firstLineName: 'Line 1',
      ),
    );
    _saves.insert(0, save);
    notifyListeners();
    await _persist();
    if (!_memory) {
      try {
        StorageGuard.instance.scheduleRefresh();
      } catch (_) {}
    }
    return save;
  }

  void put(MapMakerSave save) {
    final index = _saves.indexWhere((s) => s.id == save.id);
    save.updatedAt = DateTime.now();
    if (index < 0) {
      _saves.insert(0, save);
    } else {
      _saves[index] = save;
      _saves.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    notifyListeners();
    _schedulePersist();
  }

  Future<void> rename(String id, String title) async {
    final save = byId(id);
    if (save == null) return;
    final next = title.trim();
    if (next.isEmpty) return;
    save.title = next;
    save.updatedAt = DateTime.now();
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    _saves.removeWhere((s) => s.id == id);
    notifyListeners();
    await _persist();
    if (!_memory) {
      try {
        StorageGuard.instance.scheduleRefresh();
      } catch (_) {}
    }
  }

  Future<void> flush() async {
    if (_persistTimer == null) return;
    await _persist();
  }

  Future<Object?> exportData() async {
    await _ready;
    return _saves.map((s) => s.toJson()).toList();
  }

  Future<void> importData(Object? data) async {
    await _ready;
    _saves = _parseList(data);
    notifyListeners();
    await _persist();
  }
}
