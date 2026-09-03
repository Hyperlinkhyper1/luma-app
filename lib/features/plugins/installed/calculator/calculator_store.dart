import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../storage/storage_guard.dart';

/// One finished sum: what was typed and what it came to.
class CalcHistoryEntry {
  const CalcHistoryEntry({
    required this.expression,
    required this.result,
    required this.at,
  });

  final String expression;
  final String result;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'expression': expression,
        'result': result,
        'at': at.millisecondsSinceEpoch,
      };

  factory CalcHistoryEntry.fromJson(Map<String, dynamic> json) =>
      CalcHistoryEntry(
        expression: json['expression']?.toString() ?? '',
        result: json['result']?.toString() ?? '',
        at: DateTime.fromMillisecondsSinceEpoch(
          (json['at'] as num?)?.toInt() ?? 0,
        ),
      );
}

/// A curve on the graph: the expression in terms of `x`, the colour it's drawn
/// in, and whether it's currently shown.
class GraphFunction {
  GraphFunction({
    required this.id,
    required this.expression,
    required this.color,
    this.visible = true,
  });

  final String id;
  String expression;
  int color;
  bool visible;

  Map<String, dynamic> toJson() => {
        'id': id,
        'expression': expression,
        'color': color,
        'visible': visible,
      };

  factory GraphFunction.fromJson(Map<String, dynamic> json) => GraphFunction(
        id: json['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        expression: json['expression']?.toString() ?? '',
        color: (json['color'] as num?)?.toInt() ?? 0xFFB49DF5,
        visible: json['visible'] as bool? ?? true,
      );
}

/// Flat-file (JSON) store for the Calculator plugin: the answer history, the
/// plotted functions, and the degrees/radians choice. Typing is rapid, so
/// writes are debounced — memory updates and notifies at once, the file
/// catches up shortly after.
class CalculatorStore extends ChangeNotifier {
  factory CalculatorStore() => instance;

  static final CalculatorStore instance = CalculatorStore._();

  CalculatorStore._() {
    _load();
  }

  static const _persistDelay = Duration(milliseconds: 400);

  /// Older sums fall off the end rather than growing the file forever.
  static const historyLimit = 100;

  List<CalcHistoryEntry> _history = [];

  /// Newest first.
  List<CalcHistoryEntry> get history => List.unmodifiable(_history);

  List<GraphFunction> _functions = [];
  List<GraphFunction> get functions => List.unmodifiable(_functions);

  bool _degrees = true;

  /// Whether trig works in degrees (true) or radians (false).
  bool get degrees => _degrees;

  double _lastAnswer = 0;

  /// The value behind the `ANS` key.
  double get lastAnswer => _lastAnswer;

  bool _loaded = false;
  bool get loaded => _loaded;

  File? _file;
  Timer? _persistTimer;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}luma_calculator.json');
    return _file!;
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map<String, dynamic>) {
          _history = ((raw['history'] as List<dynamic>?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(CalcHistoryEntry.fromJson)
              .toList();
          _functions = ((raw['functions'] as List<dynamic>?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(GraphFunction.fromJson)
              .toList();
          _degrees = raw['degrees'] as bool? ?? true;
          _lastAnswer = (raw['lastAnswer'] as num?)?.toDouble() ?? 0;
        }
      }
    } catch (_) {
      _history = [];
      _functions = [];
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
        jsonEncode({
          'history': _history.map((e) => e.toJson()).toList(),
          'functions': _functions.map((f) => f.toJson()).toList(),
          'degrees': _degrees,
          'lastAnswer': _lastAnswer,
        }),
      );
    } catch (_) {}
  }

  /// Records a finished sum. Over the storage cap the answer still shows —
  /// only remembering it is refused, which is what [StorageGuard] is for.
  void remember(String expression, String result, double value) {
    _lastAnswer = value;
    try {
      StorageGuard.instance.ensureWithinLimit();
    } on StorageLimitExceededException {
      notifyListeners();
      return;
    }
    _history.insert(
      0,
      CalcHistoryEntry(
        expression: expression,
        result: result,
        at: DateTime.now(),
      ),
    );
    if (_history.length > historyLimit) {
      _history = _history.sublist(0, historyLimit);
    }
    notifyListeners();
    _schedulePersist();
  }

  void clearHistory() {
    if (_history.isEmpty) return;
    _history = [];
    notifyListeners();
    _schedulePersist();
  }

  void setDegrees(bool value) {
    if (_degrees == value) return;
    _degrees = value;
    notifyListeners();
    _schedulePersist();
  }

  /// Adds a curve and returns it, or returns null when the storage cap says no.
  GraphFunction? addFunction(String expression, int color) {
    try {
      StorageGuard.instance.ensureWithinLimit();
    } on StorageLimitExceededException {
      return null;
    }
    final function = GraphFunction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      expression: expression,
      color: color,
    );
    _functions.add(function);
    notifyListeners();
    _schedulePersist();
    StorageGuard.instance.scheduleRefresh();
    return function;
  }

  void editFunction(String id, {String? expression, int? color}) {
    final function = _find(id);
    if (function == null) return;
    if (expression != null) function.expression = expression;
    if (color != null) function.color = color;
    notifyListeners();
    _schedulePersist();
  }

  void toggleFunction(String id) {
    final function = _find(id);
    if (function == null) return;
    function.visible = !function.visible;
    notifyListeners();
    _schedulePersist();
  }

  void removeFunction(String id) {
    _functions.removeWhere((f) => f.id == id);
    notifyListeners();
    _schedulePersist();
  }

  /// Writes any pending debounced change out now — called when the plugin page
  /// goes away so the last sum is never left unsaved.
  Future<void> flush() async {
    if (_persistTimer == null) return;
    await _persist();
  }

  GraphFunction? _find(String id) {
    for (final function in _functions) {
      if (function.id == id) return function;
    }
    return null;
  }
}
