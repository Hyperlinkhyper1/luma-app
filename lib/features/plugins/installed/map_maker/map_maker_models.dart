import 'dart:ui';

import 'map_maker_geometry.dart';

/// Colours that read like printed transit diagrams — red through teal, plus
/// a silver for a "grey line".
const kTransitLinePalette = <int>[
  0xFFE21836,
  0xFFF7901E,
  0xFFE6B422,
  0xFF00A84F,
  0xFF0077C0,
  0xFF919396,
  0xFF7C5AD9,
  0xFFE85AAA,
  0xFF8B5A2B,
  0xFF00B3A4,
];

enum MapMakerKind { transit, city, home }

enum TransitStationKind { stop, transfer, airport, terminus }

enum MapMakerTool { select, pan, station, connection, river, zone, delete }

class TransitStation {
  TransitStation({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.kind = TransitStationKind.stop,
    this.labelDx = 10,
    this.labelDy = -14,
  });

  final String id;
  String name;
  double x;
  double y;
  TransitStationKind kind;
  double labelDx;
  double labelDy;

  Offset get position => Offset(x, y);

  set position(Offset value) {
    x = value.dx;
    y = value.dy;
  }

  TransitStation clone() => TransitStation(
        id: id,
        name: name,
        x: x,
        y: y,
        kind: kind,
        labelDx: labelDx,
        labelDy: labelDy,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'x': x,
        'y': y,
        'kind': kind.name,
        'labelDx': labelDx,
        'labelDy': labelDy,
      };

  factory TransitStation.fromJson(Map<String, dynamic> json) => TransitStation(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        kind: TransitStationKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => TransitStationKind.stop,
        ),
        labelDx: (json['labelDx'] as num?)?.toDouble() ?? 10,
        labelDy: (json['labelDy'] as num?)?.toDouble() ?? -14,
      );
}

class TransitLine {
  TransitLine({
    required this.id,
    required this.name,
    required this.color,
    List<String>? stationIds,
  }) : stationIds = stationIds ?? [];

  final String id;
  String name;
  int color;
  final List<String> stationIds;

  TransitLine clone() => TransitLine(
        id: id,
        name: name,
        color: color,
        stationIds: List<String>.from(stationIds),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'stationIds': stationIds,
      };

  factory TransitLine.fromJson(Map<String, dynamic> json) => TransitLine(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        color: (json['color'] as num?)?.toInt() ?? kTransitLinePalette.first,
        stationIds: (json['stationIds'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class TransitRiver {
  TransitRiver({
    required this.id,
    List<Offset>? points,
    this.closed = false,
  }) : points = points ?? [];

  final String id;
  final List<Offset> points;
  bool closed;

  TransitRiver clone() => TransitRiver(
        id: id,
        points: List<Offset>.from(points),
        closed: closed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'closed': closed,
        'points': [
          for (final point in points) {'x': point.dx, 'y': point.dy},
        ],
      };

  factory TransitRiver.fromJson(Map<String, dynamic> json) => TransitRiver(
        id: json['id']?.toString() ?? '',
        closed: json['closed'] == true,
        points: (json['points'] as List<dynamic>? ?? [])
            .map((e) {
              final map = e as Map<String, dynamic>;
              return Offset(
                (map['x'] as num?)?.toDouble() ?? 0,
                (map['y'] as num?)?.toDouble() ?? 0,
              );
            })
            .toList(),
      );
}

/// One schematic network: stations, coloured lines that visit them, rivers.
class TransitMap {
  TransitMap({
    List<TransitStation>? stations,
    List<TransitLine>? lines,
    List<TransitRiver>? rivers,
  })  : stations = stations ?? [],
        lines = lines ?? [],
        rivers = rivers ?? [];

  final List<TransitStation> stations;
  final List<TransitLine> lines;
  final List<TransitRiver> rivers;

  factory TransitMap.empty({String firstLineName = 'Line 1'}) {
    return TransitMap(
      lines: [
        TransitLine(
          id: 'line-1',
          name: firstLineName,
          color: kTransitLinePalette[1],
        ),
      ],
    );
  }

  TransitMap clone() => TransitMap(
        stations: stations.map((s) => s.clone()).toList(),
        lines: lines.map((l) => l.clone()).toList(),
        rivers: rivers.map((r) => r.clone()).toList(),
      );

  TransitStation? stationById(String id) {
    for (final station in stations) {
      if (station.id == id) return station;
    }
    return null;
  }

  TransitLine? lineById(String id) {
    for (final line in lines) {
      if (line.id == id) return line;
    }
    return null;
  }

  int lineCountAt(String stationId) {
    var count = 0;
    for (final line in lines) {
      if (line.stationIds.contains(stationId)) count++;
    }
    return count;
  }

  bool isInterchange(TransitStation station) {
    if (station.kind == TransitStationKind.transfer) return true;
    return lineCountAt(station.id) >= 2;
  }

  List<Offset> linePolyline(TransitLine line) {
    final points = <Offset>[];
    for (final id in line.stationIds) {
      final station = stationById(id);
      if (station != null) points.add(station.position);
    }
    return octilinearPolyline(points);
  }

  TransitStation? hitStation(Offset canvas, {double radius = 16}) {
    TransitStation? best;
    var bestDistance = radius;
    for (final station in stations) {
      final distance = (station.position - canvas).distance;
      if (distance <= bestDistance) {
        best = station;
        bestDistance = distance;
      }
    }
    return best;
  }

  TransitLine? hitLine(Offset canvas, {double radius = 10}) {
    TransitLine? best;
    var bestDistance = radius;
    for (final line in lines) {
      final distance = distanceToPolyline(canvas, linePolyline(line));
      if (distance <= bestDistance) {
        best = line;
        bestDistance = distance;
      }
    }
    return best;
  }

  TransitRiver? hitRiver(Offset canvas, {double radius = 14}) {
    TransitRiver? best;
    var bestDistance = radius;
    for (final river in rivers) {
      final distance = distanceToPolyline(canvas, river.points);
      if (distance <= bestDistance) {
        best = river;
        bestDistance = distance;
      }
    }
    return best;
  }

  void addStation(TransitStation station) => stations.add(station);

  void removeStation(String id) {
    stations.removeWhere((s) => s.id == id);
    for (final line in lines) {
      line.stationIds.removeWhere((sid) => sid == id);
    }
  }

  void appendStop(String lineId, String stationId) {
    final line = lineById(lineId);
    if (line == null) return;
    if (line.stationIds.isNotEmpty && line.stationIds.last == stationId) {
      return;
    }
    line.stationIds.add(stationId);
  }

  void addLine(TransitLine line) => lines.add(line);

  void removeLine(String lineId) {
    lines.removeWhere((l) => l.id == lineId);
  }

  void addRiver(TransitRiver river) => rivers.add(river);

  void removeRiver(String riverId) {
    rivers.removeWhere((r) => r.id == riverId);
  }

  Map<String, dynamic> toJson() => {
        'stations': stations.map((s) => s.toJson()).toList(),
        'lines': lines.map((l) => l.toJson()).toList(),
        'rivers': rivers.map((r) => r.toJson()).toList(),
      };

  factory TransitMap.fromJson(Map<String, dynamic> json) => TransitMap(
        stations: (json['stations'] as List<dynamic>? ?? [])
            .map((e) => TransitStation.fromJson(e as Map<String, dynamic>))
            .toList(),
        lines: (json['lines'] as List<dynamic>? ?? [])
            .map((e) => TransitLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        rivers: (json['rivers'] as List<dynamic>? ?? [])
            .map((e) => TransitRiver.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MapMakerSave {
  MapMakerSave({
    required this.id,
    required this.title,
    required this.kind,
    required this.updatedAt,
    TransitMap? transit,
  }) : transit = transit ?? TransitMap.empty();

  final String id;
  String title;
  final MapMakerKind kind;
  DateTime updatedAt;
  TransitMap transit;

  MapMakerSave clone() => MapMakerSave(
        id: id,
        title: title,
        kind: kind,
        updatedAt: updatedAt,
        transit: transit.clone(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'updatedAt': updatedAt.toIso8601String(),
        'transit': transit.toJson(),
      };

  factory MapMakerSave.fromJson(Map<String, dynamic> json) => MapMakerSave(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        kind: MapMakerKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => MapMakerKind.transit,
        ),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        transit: json['transit'] is Map<String, dynamic>
            ? TransitMap.fromJson(json['transit'] as Map<String, dynamic>)
            : TransitMap.empty(),
      );
}
