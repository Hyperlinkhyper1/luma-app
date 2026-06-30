import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PriceSnapshot {
  PriceSnapshot({required this.price, required this.checkedAt});

  final double price;
  final DateTime checkedAt;

  Map<String, dynamic> toJson() => {
        'price': price,
        'checkedAt': checkedAt.toIso8601String(),
      };

  factory PriceSnapshot.fromJson(Map<String, dynamic> j) => PriceSnapshot(
        price: (j['price'] as num).toDouble(),
        checkedAt: DateTime.parse(j['checkedAt'] as String),
      );
}

class TrackedItem {
  TrackedItem({
    required this.id,
    required this.name,
    required this.url,
    required this.snapshots,
  });

  final String id;
  String name;
  String url;
  List<PriceSnapshot> snapshots;

  double? get latestPrice =>
      snapshots.isEmpty ? null : snapshots.last.price;

  double? get previousPrice =>
      snapshots.length < 2 ? null : snapshots[snapshots.length - 2].price;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'snapshots': snapshots.map((s) => s.toJson()).toList(),
      };

  factory TrackedItem.fromJson(Map<String, dynamic> j) => TrackedItem(
        id: j['id'] as String,
        name: j['name'] as String,
        url: j['url'] as String,
        snapshots: (j['snapshots'] as List<dynamic>)
            .map((s) => PriceSnapshot.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class PriceTrackerRepository extends ChangeNotifier {
  PriceTrackerRepository() {
    _load();
  }

  List<TrackedItem> _items = [];
  List<TrackedItem> get items => List.unmodifiable(_items);

  File? _file;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/luma_price_tracker.json');
    return _file!;
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        final list = jsonDecode(raw) as List<dynamic>;
        _items = list
            .map((e) => TrackedItem.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final file = await _getFile();
      await file
          .writeAsString(jsonEncode(_items.map((i) => i.toJson()).toList()));
    } catch (_) {}
  }

  Future<TrackedItem> add({required String name, required String url}) async {
    final item = TrackedItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      url: url,
      snapshots: [],
    );
    _items.add(item);
    notifyListeners();
    await _persist();
    return item;
  }

  Future<void> addSnapshot(String itemId, double price) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    _items[idx].snapshots.add(
          PriceSnapshot(price: price, checkedAt: DateTime.now()),
        );
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String itemId) async {
    _items.removeWhere((i) => i.id == itemId);
    notifyListeners();
    await _persist();
  }
}
