/// Reading and rewriting one Fishing Waters species module
/// (`src/shared/Fish/<Id>.luau` in the game repo, format documented in the
/// game's Shared.FishSpecies). The files are machine-maintained: every data
/// field sits on its own line one tab in, so the admin panel's quick edits are
/// plain line rewrites and never go through an AI.
library;

/// Shared.CatchConditions keys a species can require, split the way the
/// editor shows them. Weather keys are alternatives (any one of them will
/// do); every other key must hold.
const kFishWeather = ['Rain', 'Clear', 'Storm', 'Supercell', 'BlackHole'];
const kFishTime = ['Day', 'Night'];
const kFishPlace = ['Beach'];
const kFishConditions = [...kFishWeather, ...kFishTime, ...kFishPlace];
const kFishSeasons = ['Spring', 'Summer', 'Autumn', 'Winter'];
const kFishRarities = [
  'Junk',
  'Common',
  'Uncommon',
  'Rare',
  'Epic',
  'Legendary',
  'Mythical',
  'Exotic',
  'Divine',
  // Bites only while switched on in the dashboard, at the chance set there.
  'Limited',
  // The rarest tier by far (1 in a million and up): "WRONG WATER" fish.
  'Admin'
];

/// Data fields in the order they appear in a module; a missing field is
/// inserted after the nearest one before it.
const _fieldOrder = [
  'Name',
  'Rarity',
  'RarityDenominator',
  'MinKg',
  'AverageKg',
  'MaxKg',
  'BaseValue',
  'Fight',
  'Pools',
  'Seasons',
  'Requires',
  'DropOnly',
  'Shapes',
];
const _numberFields = {
  'RarityDenominator',
  'MinKg',
  'AverageKg',
  'MaxKg',
  'BaseValue',
  'Fight'
};
const _listFields = {'Pools', 'Seasons', 'Requires'};

/// Identifiers a species module never needs. Its Build only draws with the
/// Builder it is handed, and the game requires these files on its server, so
/// anything that reaches outside (require, game, loadstring…) is refused
/// before a commit or a preview run.
const _forbidden = {
  'require',
  'getfenv',
  'setfenv',
  'loadstring',
  'load',
  'game',
  'workspace',
  'script',
  'shared',
  '_G',
  '_ENV',
  'Instance',
  'task',
  'spawn',
  'delay',
  'wait',
  'debug',
  'rawget',
  'rawset',
  'rawequal',
  'coroutine',
  'newproxy',
  'collectgarbage',
  'plugin',
  'settings',
  'UserSettings',
  'HttpService',
  'os',
  'io',
};

final _idPattern = RegExp(r'^[A-Z][A-Za-z0-9]{1,47}$');

bool isFishId(String id) => _idPattern.hasMatch(id);

/// "Sea Lettuce" → "SeaLettuce"; null when nothing usable is left.
String? fishIdFromName(String name) {
  final words = name
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1));
  final id = words.join();
  return isFishId(id) ? id : null;
}

/// "SeaLettuce" → "sea-lettuce", the slug the wiki uses for model files.
String fishSlug(String id) => id
    .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}-${m[2]}')
    .toLowerCase();

/// One parsed species module.
class FishSpeciesFile {
  FishSpeciesFile(this.id, this.source);

  final String id;
  final String source;

  static final _line = RegExp(r'^\t(\w+) = (.*),\r?$', multiLine: true);

  Map<String, String> get _raw {
    final out = <String, String>{};
    for (final m in _line.allMatches(source)) {
      out.putIfAbsent(m[1]!, () => m[2]!);
    }
    return out;
  }

  String? get name {
    final raw = _raw['Name'];
    final m = raw == null ? null : RegExp(r'^"(.*)"$').firstMatch(raw);
    return m?[1];
  }

  String? get rarity {
    final raw = _raw['Rarity'];
    final m = raw == null ? null : RegExp(r'^"(\w+)"$').firstMatch(raw);
    return m?[1];
  }

  num? number(String field) => evalNumber(_raw[field]);

  List<String> list(String field) {
    final raw = _raw[field];
    if (raw == null) return const [];
    if (RegExp(r'^"(\w+)"$').hasMatch(raw)) return [raw.replaceAll('"', '')];
    return RegExp(r'"(\w+)"').allMatches(raw).map((m) => m[1]!).toList();
  }

  bool get dropOnly => _raw['DropOnly'] == 'true';
  bool get hasBuild =>
      RegExp(r'^\tBuild = function', multiLine: true).hasMatch(source);

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': fishSlug(id),
        'name': name ?? id,
        'rarity': rarity,
        'odds': number('RarityDenominator'),
        'minKg': number('MinKg'),
        'averageKg': number('AverageKg'),
        'maxKg': number('MaxKg'),
        'value': number('BaseValue'),
        'fight': number('Fight') ?? 0,
        'pools': list('Pools'),
        'seasons': list('Seasons'),
        'requires': list('Requires'),
        'dropOnly': dropOnly,
        'hasBuild': hasBuild,
      };

  /// What is wrong with this module for the game, or null when it loads.
  /// [pools] are the AnglerCatalog pool ids a species may name.
  String? problem(Set<String> pools) {
    if (!source.trimLeft().startsWith('return {')) {
      return 'The module must return one table: `return { ... }`.';
    }
    final unsafe = forbiddenIdentifier(source);
    if (unsafe != null) {
      return 'Species modules may not use `$unsafe`; Build only draws with '
          'the Builder it is handed.';
    }
    if (name == null || name!.trim().isEmpty) return 'Name is missing.';
    if (!kFishRarities.contains(rarity)) {
      return 'Rarity must be one of ${kFishRarities.join(', ')}.';
    }
    for (final field in ['RarityDenominator', 'MinKg', 'AverageKg', 'MaxKg']) {
      final value = number(field);
      if (value == null || value <= 0) return '$field must be a positive number.';
    }
    final value = number('BaseValue');
    if (value == null || value < 0) return 'BaseValue must be a number.';
    final min = number('MinKg')!, average = number('AverageKg')!;
    final max = number('MaxKg')!;
    if (!(min <= average && average <= max)) {
      return 'Weights must satisfy MinKg ≤ AverageKg ≤ MaxKg.';
    }
    final fight = number('Fight') ?? 0;
    if (fight < 0 || fight > 0.3) return 'Fight must be between 0 and 0.3.';
    for (final pool in list('Pools')) {
      if (!pools.contains(pool)) return 'Unknown pool $pool.';
    }
    final seasons = list('Seasons');
    if (seasons.any((s) => !kFishSeasons.contains(s))) {
      return 'Seasons must be Spring, Summer, Autumn or Winter.';
    }
    final conflict = conditionConflict(list('Requires'));
    if (conflict != null) return conflict;
    if (!RegExp(r'^\tShapes = \{', multiLine: true).hasMatch(source)) {
      return 'Shapes (the cargo footprint per size) is missing.';
    }
    return null;
  }

  /// This module with [changes] applied: field name → new value (String,
  /// num, List<String>, or null/empty to remove an optional field).
  FishSpeciesFile withFields(Map<String, Object?> changes) {
    final crlf = source.contains('\r\n');
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    int indexOf(String field) =>
        lines.indexWhere((l) => l.startsWith('\t$field = '));
    for (final entry in changes.entries) {
      final field = entry.key;
      final value = entry.value;
      final remove = value == null ||
          (value is List && value.isEmpty) ||
          (field == 'DropOnly' && value == false);
      final at = indexOf(field);
      if (remove) {
        if (at >= 0) lines.removeAt(at);
        continue;
      }
      final line = '\t$field = ${_luau(field, value)},';
      if (at >= 0) {
        lines[at] = line;
        continue;
      }
      var insertAt = 1;
      for (final before in _fieldOrder.take(_fieldOrder.indexOf(field))) {
        final i = indexOf(before);
        if (i >= 0) insertAt = i + 1;
      }
      lines.insert(insertAt, line);
    }
    final text = lines.join('\n');
    return FishSpeciesFile(id, crlf ? text.replaceAll('\n', '\r\n') : text);
  }

  static String _luau(String field, Object? value) {
    if (_listFields.contains(field)) {
      final items = (value as List).map((v) => '"$v"').join(', ');
      return '{ $items }';
    }
    if (_numberFields.contains(field)) return formatNumber(value as num);
    if (field == 'DropOnly') return 'true';
    return '"${(value as String).replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }
}

String formatNumber(num value) {
  if (value == value.roundToDouble() && value.abs() < 1e12) {
    return value.toInt().toString();
  }
  var text = value.toStringAsFixed(6);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
}

/// A number literal or a simple `a / b` (shark drops are written as
/// `1 / 0.60`, one over their drop chance).
num? evalNumber(String? raw) {
  if (raw == null) return null;
  final text = raw.trim();
  final plain = num.tryParse(text);
  if (plain != null) return plain;
  final m = RegExp(r'^([\d.]+)\s*/\s*([\d.]+)$').firstMatch(text);
  if (m == null) return null;
  final a = num.tryParse(m[1]!), b = num.tryParse(m[2]!);
  return a == null || b == null || b == 0 ? null : a / b;
}

/// Why these Requires keys can never all hold at once, or null.
String? conditionConflict(List<String> requires) {
  for (final key in requires) {
    if (!kFishConditions.contains(key)) {
      return 'Unknown condition $key; use ${kFishConditions.join(', ')}.';
    }
  }
  bool has(String key) => requires.contains(key);
  if (has('Day') && has('Night')) return 'A species cannot need both day and night.';
  return null;
}

/// The first forbidden identifier used in [source] outside strings and
/// comments, or null. Method calls (`b:wait`) and fields (`p.task`) are fine.
String? forbiddenIdentifier(String source) {
  final code = source
      .replaceAll(RegExp(r'--\[(=*)\[[\s\S]*?\]\1\]'), ' ')
      .replaceAll(RegExp(r'--[^\n]*'), ' ')
      .replaceAll(RegExp(r'\[(=*)\[[\s\S]*?\]\1\]'), '""')
      .replaceAll(RegExp(r'"(?:[^"\\\n]|\\.)*"'), '""')
      .replaceAll(RegExp(r"'(?:[^'\\\n]|\\.)*'"), '""')
      .replaceAll(RegExp(r'`(?:[^`\\]|\\.)*`'), '""');
  for (final m in RegExp(r'[A-Za-z_][A-Za-z0-9_]*').allMatches(code)) {
    final word = m[0]!;
    if (!_forbidden.contains(word)) continue;
    final before = m.start > 0 ? code[m.start - 1] : '';
    if (before == '.' || before == ':') continue;
    return word;
  }
  return null;
}
