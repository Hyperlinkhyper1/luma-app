import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../device_health_models.dart';

/// Loads the bundled starter list of process names commonly flagged as
/// toolbars/adware/upsell nagware (`assets/device_health/bloatware_processes.json`).
///
/// This is a suggestion list, not a verdict, and it is intentionally small —
/// see the asset's own `note` field. [match] is a pure lookup so it can be
/// unit tested without touching `rootBundle`.
class BloatwareCatalog {
  BloatwareCatalog._(this._byProcessName);

  final Map<String, BloatwareMatch> _byProcessName;

  static const _assetPath = 'assets/device_health/bloatware_processes.json';
  static BloatwareCatalog? _instance;

  static Future<BloatwareCatalog> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(_assetPath);
    final catalog = parse(raw);
    return _instance = catalog;
  }

  static BloatwareCatalog parse(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final entries = (decoded['entries'] as List?) ?? const [];
    final map = <String, BloatwareMatch>{};
    for (final e in entries) {
      if (e is! Map<String, dynamic>) continue;
      final name = (e['processName'] as String?)?.trim().toLowerCase();
      final label = e['label'] as String?;
      final reason = e['reason'] as String?;
      if (name == null || name.isEmpty || label == null || reason == null) {
        continue;
      }
      map[name] = BloatwareMatch(label: label, reason: reason);
    }
    return BloatwareCatalog._(map);
  }

  /// [processName] without the `.exe` suffix, matched case-insensitively.
  BloatwareMatch? match(String processName) =>
      _byProcessName[processName.trim().toLowerCase()];
}
