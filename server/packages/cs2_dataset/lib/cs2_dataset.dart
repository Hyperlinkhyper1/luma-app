enum Cs2Outcome { a, b, other }

const cs2Maps = {
  'ar_baggage': 'Baggage',
  'ar_pool_day': 'Pool Day',
  'ar_shoots': 'Shoots',
  'ar_shoots_night': 'Shoots (Night)',
  'cs_agency': 'Agency',
  'cs_assembly': 'Assembly',
  'cs_italy': 'Italy',
  'cs_office': 'Office',
  'de_ancient': 'Ancient',
  'de_ancient_night': 'Ancient (Night)',
  'de_anubis': 'Anubis',
  'de_basalt': 'Basalt',
  'de_boulder': 'Boulder',
  'de_brewery': 'Brewery',
  'de_cache': 'Cache',
  'de_cbble': 'Cobblestone',
  'de_debris': 'Debris',
  'de_dogtown': 'Dogtown',
  'de_dust2': 'Dust II',
  'de_edin': 'Edin',
  'de_eldorado': 'El Dorado',
  'de_fachwerk': 'Fachwerk',
  'de_grail': 'Grail',
  'de_inferno': 'Inferno',
  'de_jura': 'Jura',
  'de_memento': 'Memento',
  'de_mills': 'Mills',
  'de_mirage': 'Mirage',
  'de_nuke': 'Nuke',
  'de_overpass': 'Overpass',
  'de_palais': 'Palais',
  'de_poseidon': 'Poseidon',
  'de_sanctum': 'Sanctum',
  'de_shelter': 'Shelter',
  'de_thera': 'Thera',
  'de_train': 'Train',
  'de_transit': 'Transit',
  'de_vertigo': 'Vertigo',
  'de_whistle': 'Whistle',
  'rush_001': 'Warehouse',
};

const cs2MaxManualRounds = 500;
const cs2MaxReplayBytes = 95 * 1024 * 1024;
final _mapId = RegExp(r'^de_[a-z0-9_]{1,60}$');

String? cs2BombMapId(String raw) {
  final id = raw.trim().toLowerCase().split('/').last;
  if (!_mapId.hasMatch(id)) return null;
  return id == 'de_cobblestone' ? 'de_cbble' : id;
}

String cs2MapName(String id) =>
    cs2Maps[id] ??
    id
        .substring(3)
        .split('_')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');

/// Consecutive rounds are grouped by match and uninterrupted T-side stint.
class Cs2Match {
  Cs2Match(this.map, Iterable<Iterable<Cs2Outcome>> blocks)
      : blocks = List.unmodifiable(blocks.map(List<Cs2Outcome>.unmodifiable));

  factory Cs2Match.fromJson(Map<String, dynamic> json) {
    final map = cs2BombMapId(json['map'] as String);
    final blocks = (json['blocks'] as List)
        .map((block) => (block as String).split('').map(_readOutcome))
        .map((block) => block.toList())
        .toList();
    if (map == null ||
        blocks.isEmpty ||
        blocks.any((block) => block.isEmpty) ||
        blocks.fold(0, (int sum, block) => sum + block.length) >
            cs2MaxManualRounds) {
      throw const FormatException('Invalid CS2 round data.');
    }
    return Cs2Match(map, blocks);
  }

  final String map;
  final List<List<Cs2Outcome>> blocks;

  int get roundCount => blocks.fold(0, (sum, block) => sum + block.length);

  Map<String, Object> toJson() => {
        'map': map,
        'blocks': blocks
            .map((block) => block.map((outcome) => 'abo'[outcome.index]).join())
            .toList(),
      };
}

Cs2Outcome _readOutcome(String value) => switch (value) {
      'a' => Cs2Outcome.a,
      'b' => Cs2Outcome.b,
      'o' => Cs2Outcome.other,
      _ => throw const FormatException('Invalid CS2 outcome.'),
    };

class Cs2Prediction {
  Cs2Prediction(List<int> counts, {required this.conditioned})
      : counts = List.unmodifiable(counts);

  final List<int> counts;
  final bool conditioned;

  int get sampleSize => counts.fold(0, (sum, count) => sum + count);

  List<Cs2Outcome> get ranking => [...Cs2Outcome.values]..sort((a, b) {
      final byCount = counts[b.index].compareTo(counts[a.index]);
      return byCount == 0 ? a.index.compareTo(b.index) : byCount;
    });
}

/// Four rows per map: overall, then the next outcome after A, B and Other.
class Cs2Dataset {
  Cs2Dataset._(this._maps);

  factory Cs2Dataset.empty() => Cs2Dataset._({});

  factory Cs2Dataset.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported CS2 dataset version.');
    }
    final maps = <String, List<int>>{};
    for (final entry in (json['maps'] as Map<String, dynamic>).entries) {
      final counts = (entry.value as List).cast<int>().toList();
      if (cs2BombMapId(entry.key) != entry.key ||
          counts.length != 12 ||
          counts.any((count) => count < 0)) {
        throw const FormatException('Invalid CS2 dataset counts.');
      }
      maps[entry.key] = counts;
    }
    return Cs2Dataset._(maps);
  }

  final Map<String, List<int>> _maps;

  Iterable<String> get maps => _maps.keys;

  int get roundCount => _maps.values
      .fold(0, (sum, counts) => sum + counts[0] + counts[1] + counts[2]);

  void add(Cs2Match match, {int skip = 0}) {
    final counts = _maps.putIfAbsent(match.map, () => List.filled(12, 0));
    for (final block in match.blocks) {
      Cs2Outcome? previous;
      for (final outcome in block.skip(skip)) {
        counts[outcome.index]++;
        if (previous != null) {
          counts[(previous.index + 1) * 3 + outcome.index]++;
        }
        previous = outcome;
      }
      skip = skip > block.length ? skip - block.length : 0;
    }
  }

  Cs2Prediction predict(String map, [Cs2Outcome? previous]) {
    final counts = _maps[map];
    if (counts == null) {
      return Cs2Prediction(const [0, 0, 0], conditioned: false);
    }
    if (previous != null) {
      final offset = (previous.index + 1) * 3;
      final row = counts.sublist(offset, offset + 3);
      if (row.any((count) => count > 0)) {
        return Cs2Prediction(row, conditioned: true);
      }
    }
    return Cs2Prediction(counts.sublist(0, 3), conditioned: false);
  }

  Map<String, Object> toJson() => {
        'version': 1,
        'maps': _maps.map((id, counts) => MapEntry(id, List<int>.of(counts))),
      };
}
