import 'dart:convert';
import 'dart:io';

import 'package:cs2_dataset/cs2_dataset.dart';

import 'util.dart';

/// World units per heatmap cell. CS2 maps span a few thousand units, so a
/// map comes out at roughly 60–120 cells a side.
const cs2HeatCellSize = 64;
const cs2HeatMaxSamples = 200000;
const _worldLimit = 65536;

/// Player positions sampled every 5 seconds of live round time, binned into
/// [cs2HeatCellSize] cells. Each cell counts T and CT samples separately.
class Cs2Heatmap {
  Cs2Heatmap({this.replays = 0, this.samples = 0, Map<int, List<int>>? cells})
      : cells = cells ?? {};

  /// Reads the parser's `heat` list of `[x, y, team]` samples (team 2 = T,
  /// 3 = CT).
  factory Cs2Heatmap.fromSamples(Object? raw) {
    if (raw is! List || raw.length > cs2HeatMaxSamples) {
      throw const FormatException('Invalid replay positions.');
    }
    final heatmap = Cs2Heatmap(replays: 1);
    for (final sample in raw) {
      if (sample is! List || sample.length != 3) {
        throw const FormatException('Invalid replay position.');
      }
      final [x, y, team] = sample;
      if (x is! int ||
          y is! int ||
          x.abs() > _worldLimit ||
          y.abs() > _worldLimit ||
          (team != 2 && team != 3)) {
        throw const FormatException('Invalid replay position.');
      }
      heatmap._count(_cellOf(x), _cellOf(y), team == 2 ? 0 : 1, 1);
    }
    return heatmap;
  }

  factory Cs2Heatmap.fromJson(Map<String, dynamic> json) {
    final heatmap = Cs2Heatmap(
      replays: json['replays'] as int,
      samples: json['samples'] as int,
    );
    for (final cell in json['cells'] as List) {
      final [cx, cy, t, ct] = (cell as List).cast<int>();
      heatmap.cells[_key(cx, cy)] = [t, ct];
    }
    return heatmap;
  }

  int replays;
  int samples;

  /// Keyed by [_key]; values are `[t, ct]` sample counts.
  final Map<int, List<int>> cells;

  void add(Cs2Heatmap other) {
    replays += other.replays;
    for (final MapEntry(:key, :value) in other.cells.entries) {
      final (cx, cy) = _unkey(key);
      _count(cx, cy, 0, value[0]);
      _count(cx, cy, 1, value[1]);
    }
  }

  void _count(int cx, int cy, int side, int amount) {
    if (amount == 0) return;
    (cells[_key(cx, cy)] ??= [0, 0])[side] += amount;
    samples += amount;
  }

  Map<String, Object> toJson() => {
        'cell': cs2HeatCellSize,
        'replays': replays,
        'samples': samples,
        'cells': [
          for (final MapEntry(:key, :value) in cells.entries)
            [..._unkeyList(key), value[0], value[1]],
        ],
      };

  static int _cellOf(int coordinate) =>
      (coordinate / cs2HeatCellSize).floor();

  static const _offset = 1 << 12;
  static int _key(int cx, int cy) => (cx + _offset) << 13 | (cy + _offset);
  static (int, int) _unkey(int key) =>
      ((key >> 13) - _offset, (key & 0x1fff) - _offset);
  static List<int> _unkeyList(int key) {
    final (cx, cy) = _unkey(key);
    return [cx, cy];
  }
}

/// Per-map heatmaps accumulated from every replay the admin stages.
class Cs2HeatmapStore {
  Cs2HeatmapStore(String root) : _file = File('$root/cs2-heatmaps.json') {
    if (!_file.existsSync()) return;
    final json = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
    if (json['version'] != 1 || json['cell'] != cs2HeatCellSize) return;
    for (final MapEntry(:key, :value)
        in (json['maps'] as Map<String, dynamic>).entries) {
      _maps[key] = Cs2Heatmap.fromJson(value as Map<String, dynamic>);
    }
  }

  final File _file;
  final _lock = AsyncLock();
  final _maps = <String, Cs2Heatmap>{};

  Cs2Heatmap? operator [](String map) => _maps[map];

  /// `map id → sample count`, for the dashboard's map picker.
  Map<String, int> get samplesByMap =>
      {for (final MapEntry(:key, :value) in _maps.entries) key: value.samples};

  Future<void> add(String map, Cs2Heatmap heatmap) =>
      _lock.synchronized(() async {
        if (heatmap.samples == 0) return;
        final merged = Cs2Heatmap()..add(_maps[map] ?? Cs2Heatmap());
        merged.add(heatmap);
        final next = {..._maps, map: merged};
        await atomicWriteString(
            _file.path,
            jsonEncode({
              'version': 1,
              'cell': cs2HeatCellSize,
              'maps': next.map((id, value) => MapEntry(id, value.toJson())),
            }));
        _maps[map] = merged;
      });

  Map<String, Object?> describe(String map) => {
        'map': map,
        'name': cs2MapName(map),
        ...(_maps[map] ?? Cs2Heatmap()).toJson(),
      };
}
