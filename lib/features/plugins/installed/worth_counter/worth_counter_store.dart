import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../storage/storage_guard.dart';

/// A counted product: a name, what one of them is worth, and how many have
/// been tallied so far.
class WorthProduct {
  WorthProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.count,
    required this.color,
  });

  final String id;
  String name;
  double price;
  int count;
  int color;

  /// What this row contributes to the grand total.
  double get total => price * count;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'count': count,
        'color': color,
      };

  factory WorthProduct.fromJson(Map<String, dynamic> json) => WorthProduct(
        id: json['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: json['name']?.toString() ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        count: (json['count'] as num?)?.toInt() ?? 0,
        color: (json['color'] as num?)?.toInt() ?? 0xFF7C5AD9,
      );
}

/// Flat-file (JSON) store for the Worth Counter plugin. Counting is a rapid,
/// tap-heavy interaction, so writes are debounced: the in-memory list updates
/// (and notifies) immediately, the file catches up shortly after.
class WorthCounterStore extends ChangeNotifier {
  factory WorthCounterStore() => instance;

  static final WorthCounterStore instance = WorthCounterStore._();

  WorthCounterStore._() {
    _load();
  }

  static const _persistDelay = Duration(milliseconds: 400);

  List<WorthProduct> _products = [];
  List<WorthProduct> get products => List.unmodifiable(_products);

  bool _loaded = false;
  bool get loaded => _loaded;

  File? _file;
  Timer? _persistTimer;

  /// Sum of every product's price times its count.
  double get grandTotal =>
      _products.fold<double>(0, (sum, p) => sum + p.total);

  /// How many taps have been counted across all products.
  int get totalCount => _products.fold<int>(0, (sum, p) => sum + p.count);

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}luma_worth_counter.json');
    return _file!;
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
        _products = raw
            .map((e) => WorthProduct.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      _products = [];
    }
    _loaded = true;
    notifyListeners();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDelay, _persist);
  }

  Future<void> _persist() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    try {
      final file = await _getFile();
      await file.writeAsString(
        jsonEncode(_products.map((p) => p.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> add({
    required String name,
    required double price,
    required int color,
    int count = 0,
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    _products.add(
      WorthProduct(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        price: price,
        count: count,
        color: color,
      ),
    );
    notifyListeners();
    await _persist();
    StorageGuard.instance.scheduleRefresh();
  }

  void edit(String id, {String? name, double? price, int? color}) {
    final product = _find(id);
    if (product == null) return;
    if (name != null) product.name = name;
    if (price != null) product.price = price;
    if (color != null) product.color = color;
    notifyListeners();
    _schedulePersist();
  }

  void increment(String id, [int by = 1]) {
    final product = _find(id);
    if (product == null) return;
    product.count += by;
    if (product.count < 0) product.count = 0;
    notifyListeners();
    _schedulePersist();
  }

  void decrement(String id, [int by = 1]) => increment(id, -by);

  /// Sets a product's tally back to zero, leaving the product itself in place.
  void resetCount(String id) {
    final product = _find(id);
    if (product == null || product.count == 0) return;
    product.count = 0;
    notifyListeners();
    _schedulePersist();
  }

  /// Zeroes every tally — a fresh count without re-adding the products.
  void resetAllCounts() {
    if (_products.every((p) => p.count == 0)) return;
    for (final product in _products) {
      product.count = 0;
    }
    notifyListeners();
    _schedulePersist();
  }

  Future<void> delete(String id) async {
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
    await _persist();
  }

  /// Writes any pending debounced change out now — called when the plugin
  /// page goes away so a burst of taps is never left unsaved.
  Future<void> flush() async {
    if (_persistTimer == null) return;
    await _persist();
  }

  WorthProduct? _find(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }
}
