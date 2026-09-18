import 'dart:math' as math;

/// Positions are logical grid cells, independent of window pixels.
class HomeTile {
  const HomeTile({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.config = const {},
  });

  final String id;
  final String kind;
  final int x, y, w, h;
  final Map<String, dynamic> config;

  HomeTile copyWith({
    String? id,
    String? kind,
    int? x,
    int? y,
    int? w,
    int? h,
    Map<String, dynamic>? config,
  }) => HomeTile(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    x: x ?? this.x,
    y: y ?? this.y,
    w: w ?? this.w,
    h: h ?? this.h,
    config: config ?? this.config,
  );

  bool overlaps(HomeTile other) =>
      x < other.x + other.w &&
      x + w > other.x &&
      y < other.y + other.h &&
      y + h > other.y;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'config': config,
  };

  factory HomeTile.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        json['kind'] is! String ||
        json['config'] is! Map ||
        ['x', 'y', 'w', 'h'].any((key) => json[key] is! int)) {
      throw const FormatException('Invalid home tile.');
    }
    return HomeTile(
      id: json['id'],
      kind: json['kind'],
      x: json['x'],
      y: json['y'],
      w: json['w'],
      h: json['h'],
      config: Map<String, dynamic>.unmodifiable(json['config'] as Map),
    );
  }
}

class HomeLayout {
  HomeLayout({
    required this.columns,
    required List<HomeTile> tiles,
    this.heroMetric = 'netWorth',
    this.heroLabel = '',
    this.heroText = '',
  }) : tiles = List.unmodifiable(tiles);

  final int columns;
  final List<HomeTile> tiles;
  final String heroMetric;
  final String heroLabel;
  final String heroText;

  static const heroMetrics = [
    'netWorth',
    'cash',
    'investments',
    'income',
    'spending',
    'custom',
  ];

  HomeLayout copyWith({
    int? columns,
    List<HomeTile>? tiles,
    String? heroMetric,
    String? heroLabel,
    String? heroText,
  }) => HomeLayout(
    columns: columns ?? this.columns,
    tiles: tiles ?? this.tiles,
    heroMetric: heroMetric ?? this.heroMetric,
    heroLabel: heroLabel ?? this.heroLabel,
    heroText: heroText ?? this.heroText,
  );

  /// The selected tile wins its position. Other tiles fall down to the first
  /// free row, retaining their horizontal alignment and stable ordering.
  HomeLayout place(HomeTile tile) {
    HomeTile clamp(HomeTile t) {
      final width = t.w.clamp(1, columns);
      return t.copyWith(
        x: t.x.clamp(0, columns - width),
        y: t.y.clamp(0, 10000),
        w: width,
        h: t.h.clamp(2, 40),
      );
    }

    final placed = <HomeTile>[clamp(tile)];
    final others = tiles.where((t) => t.id != tile.id).toList()
      ..sort((a, b) {
        final order = a.y.compareTo(b.y);
        return order != 0 ? order : a.x.compareTo(b.x);
      });
    for (final other in others) {
      var candidate = clamp(other);
      while (placed.any(candidate.overlaps)) {
        final bottom = placed
            .where(candidate.overlaps)
            .map((t) => t.y + t.h)
            .reduce(math.max);
        candidate = candidate.copyWith(y: bottom);
      }
      placed.add(candidate);
    }
    final byId = {for (final item in placed) item.id: item};
    return copyWith(
      tiles: [
        for (final item in tiles) byId[item.id]!,
        if (!tiles.any((t) => t.id == tile.id)) placed.first,
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'columns': columns,
    'heroMetric': heroMetric,
    'heroLabel': heroLabel,
    'heroText': heroText,
    'tiles': tiles.map((t) => t.toJson()).toList(),
  };

  factory HomeLayout.fromJson(Object? raw, {required int columns}) {
    if (raw is! Map ||
        raw['columns'] != columns ||
        raw['tiles'] is! List ||
        (raw['tiles'] as List).length > 100) {
      throw const FormatException('Invalid home layout.');
    }
    final metric = raw['heroMetric'];
    var result = HomeLayout(
      columns: columns,
      tiles: [],
      heroMetric: metric is String && heroMetrics.contains(metric)
          ? metric
          : 'netWorth',
      heroLabel: raw['heroLabel'] is String ? raw['heroLabel'] as String : '',
      heroText: raw['heroText'] is String ? raw['heroText'] as String : '',
    );
    final ids = <String>{};
    for (final value in raw['tiles'] as List) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid home tile.');
      }
      final tile = HomeTile.fromJson(value);
      if (!ids.add(tile.id)) {
        throw const FormatException('Duplicate home tile.');
      }
      result = result.place(tile);
    }
    if (!raw.containsKey('heroMetric') && result._isPreviousDefault) {
      return HomeLayout.defaults(columns == 4 ? 'phone' : 'desktop');
    }
    if (result._isFirstGridDefault) {
      return HomeLayout.defaults(columns == 4 ? 'phone' : 'desktop').copyWith(
        heroMetric: result.heroMetric,
        heroLabel: result.heroLabel,
        heroText: result.heroText,
      );
    }
    return result;
  }

  bool get _isPreviousDefault {
    if (tiles.length != 4) return false;
    final phone = columns == 4;
    const ids = ['clock', 'timer', 'finance', 'notes'];
    const kinds = ['clock', 'timer', 'finance', 'note'];
    for (var i = 0; i < 4; i++) {
      final tile = tiles[i];
      if (tile.id != ids[i] ||
          tile.kind != kinds[i] ||
          tile.config.isNotEmpty ||
          tile.w != (phone ? 4 : 6) ||
          tile.h != (i < 2 ? 4 : 6) ||
          tile.x != (phone ? 0 : (i % 2) * 6) ||
          tile.y != (phone ? [0, 4, 8, 14][i] : (i < 2 ? 0 : 4))) {
        return false;
      }
    }
    return true;
  }

  /// The grid's first set of default tiles, before they were resized to the
  /// proportions the home page had before it became a grid. A layout still
  /// sitting on them exactly was never arranged by hand, so it follows the new
  /// sizes instead of stranding tiles at twice the height of their content.
  /// Anything the user has moved, resized or added to is left alone.
  bool get _isFirstGridDefault {
    if (tiles.length != 9) return false;
    final phone = columns == 4;
    const metrics = ['income', 'spending', 'pots', 'investments'];
    for (var i = 0; i < 4; i++) {
      final tile = tiles[i];
      if (tile.id != metrics[i] ||
          tile.kind != metrics[i] ||
          tile.config.isNotEmpty ||
          tile.x != (phone ? 0 : (i % 2) * 6) ||
          tile.y != (phone ? i * 3 : (i ~/ 2) * 3) ||
          tile.w != (phone ? 4 : 6) ||
          tile.h != 3) {
        return false;
      }
    }
    const shortcuts = ['assistant', 'finance-shortcut', 'converter', 'settings'];
    const destinations = [5, 2, 1, 7];
    for (var i = 0; i < 4; i++) {
      final tile = tiles[4 + i];
      if (tile.id != shortcuts[i] ||
          tile.kind != 'shortcut' ||
          tile.config.length != 1 ||
          tile.config['destination'] != destinations[i] ||
          tile.x != (phone ? 0 : i * 3) ||
          tile.y != (phone ? 13 + i * 4 : 7) ||
          tile.w != (phone ? 4 : 3) ||
          tile.h != 4) {
        return false;
      }
    }
    final recent = tiles[8];
    return recent.id == 'recent' &&
        recent.kind == 'recent_activity' &&
        recent.config.isEmpty &&
        recent.x == 0 &&
        recent.y == (phone ? 30 : 12) &&
        recent.w == (phone ? 4 : 12) &&
        recent.h == 6;
  }

  factory HomeLayout.defaults(String family) {
    final phone = family == 'phone';
    return HomeLayout(
      columns: phone ? 4 : 12,
      tiles: [
        for (var i = 0; i < 4; i++)
          HomeTile(
            id: ['income', 'spending', 'pots', 'investments'][i],
            kind: ['income', 'spending', 'pots', 'investments'][i],
            x: phone ? 0 : (i % 2) * 6,
            y: phone ? i * 2 : (i ~/ 2) * 2,
            w: phone ? 4 : 6,
            h: 2,
          ),
        for (var i = 0; i < 4; i++)
          HomeTile(
            id: ['assistant', 'finance-shortcut', 'converter', 'settings'][i],
            kind: 'shortcut',
            x: phone ? 0 : i * 3,
            y: phone ? 9 + i * 3 : 5,
            w: phone ? 4 : 3,
            h: 3,
            config: {
              'destination': [5, 2, 1, 7][i],
            },
          ),
        HomeTile(
          id: 'recent',
          kind: 'recent_activity',
          x: 0,
          y: phone ? 22 : 9,
          w: phone ? 4 : 12,
          h: 5,
        ),
      ],
    );
  }
}
