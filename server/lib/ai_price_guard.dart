import 'dart:convert';
import 'dart:io';

import 'ai_mode_routing.dart';
import 'ai_model_catalog.dart';
import 'ai_model_sources.dart';
import 'util.dart';

/// Per-million-token price of the model behind a mode, in USD.
class AiPrice {
  const AiPrice(this.input, this.output, [this.image]);

  AiPrice.ofEndpoint(AiEndpointPrice e) : this(e.input, e.output, e.imageOutput);

  final double? input;
  final double? output;

  /// Per 1M generated image tokens — what a picture model mostly bills on.
  final double? image;

  bool get known => input != null || output != null || image != null;

  /// True when any side costs more than [base] (ignoring float noise).
  bool risesAbove(AiPrice base) =>
      _higher(input, base.input) ||
      _higher(output, base.output) ||
      _higher(image, base.image);

  static bool _higher(double? now, double? before) =>
      now != null && before != null && now > before * 1.000001 + 1e-12;

  /// Whether an OpenRouter endpoint charges no more than this on either side.
  bool admits(AiEndpointPrice e) =>
      !_higher(e.input, input) &&
      !_higher(e.output, output) &&
      !_higher(e.imageOutput, image);

  Map<String, dynamic> toJson() =>
      {'input': input, 'output': output, if (image != null) 'image': image};

  static AiPrice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final price = AiPrice((raw['input'] as num?)?.toDouble(),
        (raw['output'] as num?)?.toDouble(), (raw['image'] as num?)?.toDouble());
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
  final exact = catalog.routingModelById('$vendorPrefix$id');
  if (exact != null) return exact;
  if (route.upstream == AiUpstream.openrouter) return null;
  if (!id.endsWith('-latest')) return null;
  final stem = '$vendorPrefix${id.substring(0, id.length - '-latest'.length)}';
  AiModel? best;
  for (final m in catalog.routingModels) {
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

/// Every model selector on the Assistant tab the price guard watches: the
/// three chat modes, the AI Detector and the picture model.
final kAiGuardedSelectors =
    List<String>.unmodifiable([...kAiModeNames.keys, 'detector', 'picture']);

/// The cheapest endpoint OpenRouter currently reports as up.
AiEndpointPrice? cheapestEndpoint(List<AiEndpointPrice> endpoints) {
  AiEndpointPrice? best;
  for (final e in endpoints) {
    if (!e.up) continue;
    if (best == null || e.input + e.output < best.input + best.output) best = e;
  }
  return best;
}

class AiPriceGuardEntry {
  AiPriceGuardEntry({
    this.autoDisable = true,
    this.modelKey,
    this.baseline,
    this.latest,
    this.disabled = false,
    this.disabledAtMs = 0,
    this.source,
    this.paid,
    this.paidProvider,
    this.cheapestProvider,
  });

  /// `endpoints` when the baseline is an actually charged OpenRouter
  /// provider price, `list` when it is a catalogue list price. A list-price
  /// baseline says nothing about provider discounts, so it is discarded the
  /// first time the mode is priced by its endpoints.
  String? source;

  /// Price of the provider that served the most recent request.
  AiPrice? paid;
  String? paidProvider;
  String? cheapestProvider;

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
        if (source != null) 'source': source,
        if (paid != null) 'paid': paid!.toJson(),
        if (paidProvider != null) 'paidProvider': paidProvider,
        if (cheapestProvider != null) 'cheapestProvider': cheapestProvider,
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
      source: raw['source'] as String?,
      paid: AiPrice.fromJson(raw['paid']),
      paidProvider: raw['paidProvider'] as String?,
      cheapestProvider: raw['cheapestProvider'] as String?,
    );
  }
}

/// Watches what each Luma AI mode's model costs and, when guarding is on,
/// switches the mode off the moment that price rises above what the operator
/// last accepted. It stays off until the operator accepts the new price,
/// picks another model, or turns the guard off. Kept in `ai_price_guard.json`.
class AiPriceGuardStore {
  AiPriceGuardStore(String dataDir)
      : _file = File('$dataDir/ai_price_guard.json') {
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
        if (mode is String && kAiGuardedSelectors.contains(mode)) {
          _entries[mode] = AiPriceGuardEntry.fromJson(raw);
        }
      });
    } catch (e) {
      stderr.writeln('[luma] could not read ${_file.path}: $e');
    }
  }

  AiPriceGuardEntry entry(String mode) => _entries[mode] ?? AiPriceGuardEntry();

  bool isDisabled(String mode) => _entries[mode]?.disabled ?? false;

  /// Compares [price] to the mode's baseline and returns whether the mode is
  /// now switched off.
  Future<bool> evaluate(String mode, AiModeRoute route, AiPrice? price) async {
    final before = jsonEncode(_entries[mode]?.toJson());
    final e = _entryFor(mode, route, 'list');
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

  /// The entry for [mode], reset when the operator has picked another model
  /// or when its baseline came from a different kind of price than [source].
  AiPriceGuardEntry _entryFor(String mode, AiModeRoute route, String source) {
    final e = _entries.putIfAbsent(mode, AiPriceGuardEntry.new);
    final key = '${route.upstream.name}:${route.model}';
    if (e.modelKey != key) {
      e
        ..modelKey = key
        ..baseline = null
        ..paid = null
        ..paidProvider = null
        ..disabled = false;
    }
    if (e.source != source) {
      e
        ..source = source
        ..baseline = null;
    }
    return e;
  }

  /// Checks an OpenRouter mode against the provider endpoints it can be
  /// routed to. The mode is switched off once no endpoint that is up still
  /// charges the accepted price or less — which is what a provider discount
  /// ending looks like, since the model's list price never moves.
  Future<bool> evaluateEndpoints(
      String mode, AiModeRoute route, List<AiEndpointPrice> endpoints) async {
    final before = jsonEncode(_entries[mode]?.toJson());
    final e = _entryFor(mode, route, 'endpoints');
    final cheapest = cheapestEndpoint(endpoints);
    if (cheapest != null) {
      e
        ..latest = AiPrice.ofEndpoint(cheapest)
        ..cheapestProvider = cheapest.provider;
      final base = e.baseline;
      if (e.autoDisable &&
          !e.disabled &&
          base != null &&
          !endpoints.any((x) => x.up && base.admits(x))) {
        _disable(e);
      }
    }
    if (jsonEncode(e.toJson()) != before) await _save();
    return e.disabled;
  }

  /// Records what the provider that served a request charged for it. The
  /// first charged price becomes the baseline; a later one above it switches
  /// the mode off.
  Future<bool> recordPaid(
      String mode, AiModeRoute route, String provider, AiPrice price) async {
    final e = _entryFor(mode, route, 'endpoints');
    e
      ..paid = price
      ..paidProvider = provider;
    e.baseline ??= price;
    if (e.autoDisable && !e.disabled && price.risesAbove(e.baseline!)) {
      _disable(e);
    }
    await _save();
    return e.disabled;
  }

  void _disable(AiPriceGuardEntry e) => e
    ..disabled = true
    ..disabledAtMs = DateTime.now().millisecondsSinceEpoch;

  /// The most OpenRouter may charge [mode] per 1M tokens, sent with every
  /// request as `provider.max_price` so OpenRouter itself refuses to route
  /// above it. Null when the guard is off or no price is accepted yet.
  AiPrice? maxPrice(String mode, AiModeRoute route) {
    final e = _entries[mode];
    if (e == null || !e.autoDisable || e.source != 'endpoints') return null;
    if (e.modelKey != '${route.upstream.name}:${route.model}') return null;
    return e.baseline;
  }

  /// Accepts the current price as the new baseline and turns the mode back on.
  Future<void> accept(String mode, AiModeRoute route, AiPrice? price,
      {String source = 'list'}) async {
    final e = _entries.putIfAbsent(mode, AiPriceGuardEntry.new);
    e
      ..modelKey = '${route.upstream.name}:${route.model}'
      ..source = source
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
