import 'dart:convert';
import 'dart:io';

import 'ai_mode_routing.dart';
import 'ai_model_catalog.dart';
import 'util.dart';

/// Per-million-token price of the model behind a mode, in USD.
class AiPrice {
  const AiPrice(this.input, this.output);

  final double? input;
  final double? output;

  bool get known => input != null || output != null;

  /// True when either side costs more than [base] (ignoring float noise).
  bool risesAbove(AiPrice base) =>
      _higher(input, base.input) || _higher(output, base.output);

  static bool _higher(double? now, double? before) =>
      now != null && before != null && now > before * 1.000001 + 1e-12;

  Map<String, dynamic> toJson() => {'input': input, 'output': output};

  static AiPrice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final price = AiPrice((raw['input'] as num?)?.toDouble(),
        (raw['output'] as num?)?.toDouble());
    return price.known ? price : null;
  }
}

/// The catalogue entry that prices [route]. OpenRouter ids are used as-is;
/// Google and Mistral have no public price API, so their models are priced
/// by the same model on OpenRouter (`google/<id>`, `mistralai/<id>`), and a
/// rolling `-latest` alias by the newest catalogue model sharing its prefix.
AiModel? catalogModelFor(AiModelCatalogStore catalog, AiModeRoute route) {
  final id = route.model;
  final vendorPrefix = switch (route.upstream) {
    AiUpstream.openrouter => '',
    AiUpstream.google => 'google/',
    AiUpstream.mistral => 'mistralai/',
  };
  final exact = catalog.byId('$vendorPrefix$id');
  if (exact != null) return exact;
  if (route.upstream == AiUpstream.openrouter) return null;
  if (!id.endsWith('-latest')) return null;
  final stem = '$vendorPrefix${id.substring(0, id.length - '-latest'.length)}';
  AiModel? best;
  for (final m in catalog.models) {
    if (!m.id.startsWith(stem)) continue;
    if (m.inputPricePerM == null && m.outputPricePerM == null) continue;
    if (best == null || (m.releasedAtMs ?? 0) > (best.releasedAtMs ?? 0)) {
      best = m;
    }
  }
  return best;
}

AiPrice? priceFor(AiModelCatalogStore catalog, AiModeRoute route) {
  final model = catalogModelFor(catalog, route);
  if (model == null) return null;
  final price = AiPrice(model.inputPricePerM, model.outputPricePerM);
  return price.known ? price : null;
}

class AiPriceGuardEntry {
  AiPriceGuardEntry({
    this.autoDisable = true,
    this.modelKey,
    this.baseline,
    this.latest,
    this.disabled = false,
    this.disabledAtMs = 0,
  });

  /// Whether a price rise switches the mode off.
  bool autoDisable;

  /// `<upstream>:<model>` the baseline belongs to. Picking a different model
  /// starts a fresh baseline, since choosing it is the operator accepting it.
  String? modelKey;

  /// The price the operator last accepted.
  AiPrice? baseline;

  /// The most recent price seen, for display.
  AiPrice? latest;
  bool disabled;
  int disabledAtMs;

  Map<String, dynamic> toJson() => {
        'autoDisable': autoDisable,
        if (modelKey != null) 'modelKey': modelKey,
        if (baseline != null) 'baseline': baseline!.toJson(),
        if (latest != null) 'latest': latest!.toJson(),
        'disabled': disabled,
        'disabledAtMs': disabledAtMs,
      };

  static AiPriceGuardEntry fromJson(Object? raw) {
    if (raw is! Map) return AiPriceGuardEntry();
    return AiPriceGuardEntry(
      autoDisable: raw['autoDisable'] != false,
      modelKey: raw['modelKey'] as String?,
      baseline: AiPrice.fromJson(raw['baseline']),
      latest: AiPrice.fromJson(raw['latest']),
      disabled: raw['disabled'] == true,
      disabledAtMs: (raw['disabledAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Watches what each Luma AI mode's model costs and, when guarding is on,
/// switches the mode off the moment that price rises above what the operator
/// last accepted. It stays off until the operator accepts the new price,
/// picks another model, or turns the guard off. Kept in `ai_price_guard.json`.
class AiPriceGuardStore {
  AiPriceGuardStore(String dataDir) : _file = File('$dataDir/ai_price_guard.json') {
    _load();
  }

  final File _file;
  final Map<String, AiPriceGuardEntry> _entries = {};

  void _load() {
    try {
      if (!_file.existsSync()) return;
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is! Map) return;
      decoded.forEach((mode, raw) {
        if (mode is String && kAiModeNames.containsKey(mode)) {
          _entries[mode] = AiPriceGuardEntry.fromJson(raw);
        }
      });
    } catch (e) {
      stderr.writeln('[luma] could not read ${_file.path}: $e');
    }
  }

  AiPriceGuardEntry entry(String mode) =>
      _entries[mode] ?? AiPriceGuardEntry();

  bool isDisabled(String mode) => _entries[mode]?.disabled ?? false;

  /// Compares [price] to the mode's baseline and returns whether the mode is
  /// now switched off.
  Future<bool> evaluate(String mode, AiModeRoute route, AiPrice? price) async {
    final before = jsonEncode(_entries[mode]?.toJson());
    final e = _entries.putIfAbsent(mode, AiPriceGuardEntry.new);
    final key = '${route.upstream.name}:${route.model}';
    if (e.modelKey != key) {
      e
        ..modelKey = key
        ..baseline = price
        ..disabled = false;
    }
    if (price != null) {
      e.latest = price;
      e.baseline ??= price;
      if (e.autoDisable && !e.disabled && price.risesAbove(e.baseline!)) {
        e
          ..disabled = true
          ..disabledAtMs = DateTime.now().millisecondsSinceEpoch;
      }
    }
    if (jsonEncode(e.toJson()) != before) await _save();
    return e.disabled;
  }

  /// Accepts the current price as the new baseline and turns the mode back on.
  Future<void> accept(String mode, AiModeRoute route, AiPrice? price) async {
    final e = _entries.putIfAbsent(mode, AiPriceGuardEntry.new);
    e
      ..modelKey = '${route.upstream.name}:${route.model}'
      ..baseline = price
      ..latest = price
      ..disabled = false;
    await _save();
  }

  /// Turning the guard off also turns a guard-disabled mode back on.
  Future<void> setAutoDisable(String mode, bool on) async {
    final e = _entries.putIfAbsent(mode, AiPriceGuardEntry.new);
    e.autoDisable = on;
    if (!on) e.disabled = false;
    await _save();
  }

  Future<void> _save() => atomicWriteString(_file.path,
      jsonEncode({for (final e in _entries.entries) e.key: e.value.toJson()}));
}
