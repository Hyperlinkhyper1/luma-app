import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/map_maker/city_map_models.dart';
import 'package:luma/features/plugins/installed/map_maker/city_map_painter.dart';

class _Raster {
  _Raster(this.width, this.height, this.pixels, this.recordingBytes);

  final int width;
  final int height;
  final ByteData pixels;
  final int recordingBytes;

  int colorAt(int x, int y) {
    final index = (y * width + x) * 4;
    return pixels.getUint8(index + 3) << 24 |
        pixels.getUint8(index) << 16 |
        pixels.getUint8(index + 1) << 8 |
        pixels.getUint8(index + 2);
  }
}

Future<_Raster> _render(
  CityMapPainter painter, {
  int width = 200,
  int height = 120,
}) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Size(width.toDouble(), height.toDouble()));
  final picture = recorder.endRecording();
  final recordingBytes = picture.approximateBytesUsed;
  final image = picture.toImageSync(width, height);
  try {
    final pixels = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    return _Raster(width, height, pixels!, recordingBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

int _differentPixels(_Raster first, _Raster second, Rect region) {
  var count = 0;
  for (var y = region.top.toInt(); y < region.bottom; y++) {
    for (var x = region.left.toInt(); x < region.right; x++) {
      if (first.colorAt(x, y) != second.colorAt(x, y)) count++;
    }
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'negative world origins fill the viewport and place features correctly',
    () async {
      final map = CityMap(
        buildings: [
          CityBuilding(
            id: 'negative-house',
            kind: CityBuildingKind.house,
            x: -920,
            y: -640,
          ),
        ],
      );
      final raster = await _render(
        CityMapPainter(
          map: map,
          showGrid: false,
          showParcels: false,
          visibleWorldBounds: const Rect.fromLTWH(-1000, -700, 200, 120),
          worldTransform: Matrix4.identity()
            ..translateByDouble(1000, 700, 0, 1),
        ),
      );

      for (final point in const [(0, 0), (199, 0), (0, 119), (199, 119)]) {
        expect(raster.colorAt(point.$1, point.$2), kCityPaper.toARGB32());
      }
      expect(raster.colorAt(75, 66), const Color(0xFFDCD3BF).toARGB32());
    },
  );

  test('a very long crossing road renders only its visible marks', () async {
    final raster = await _render(
      CityMapPainter(
        map: CityMap(
          roads: [
            CityRoad(
              id: 'long-road',
              points: const [Offset(-1e12, -100), Offset(1e12, -100)],
            ),
          ],
        ),
        showGrid: false,
        visibleWorldBounds: const Rect.fromLTWH(-1000, -160, 200, 120),
        worldTransform: Matrix4.identity()..translateByDouble(1000, 160, 0, 1),
      ),
    );

    expect(raster.colorAt(1, 67), const Color(0xFFD3D8D5).toARGB32());
    expect(raster.colorAt(100, 67), const Color(0xFFD3D8D5).toARGB32());
    expect(raster.colorAt(198, 67), const Color(0xFFD3D8D5).toARGB32());
    expect(raster.colorAt(100, 110), kCityPaper.toARGB32());
    expect(raster.recordingBytes, lessThan(128 * 1024));
  });

  test('far world coordinates preserve local building detail', () async {
    final raster = await _render(
      CityMapPainter(
        map: CityMap(
          buildings: [
            CityBuilding(
              id: 'far-house',
              kind: CityBuildingKind.house,
              x: 1e9,
              y: -1e9,
            ),
          ],
        ),
        showGrid: false,
        showParcels: false,
        visibleWorldBounds: const Rect.fromLTWH(1e9 - 100, -1e9 - 60, 200, 120),
        worldTransform: Matrix4.identity()
          ..translateByDouble(-1e9 + 100, 1e9 + 60, 0, 1),
      ),
    );

    expect(raster.colorAt(0, 0), kCityPaper.toARGB32());
    expect(raster.colorAt(199, 119), kCityPaper.toARGB32());
    expect(raster.colorAt(95, 66), const Color(0xFFDCD3BF).toARGB32());
    expect(raster.colorAt(70, 66), kCityPaper.toARGB32());
    final nearby = await _render(
      CityMapPainter(
        map: CityMap(
          buildings: [
            CityBuilding(
              id: 'near-house',
              kind: CityBuildingKind.house,
              x: 100,
              y: 60,
            ),
          ],
        ),
        showGrid: false,
        showParcels: false,
      ),
    );
    expect(
      _differentPixels(raster, nearby, const Rect.fromLTWH(0, 0, 200, 120)),
      0,
    );
  });

  test('far zoom keeps a visible grid with bounded recording size', () async {
    final raster = await _render(
      CityMapPainter(
        map: CityMap(),
        viewScale: .000001,
        visibleWorldBounds: const Rect.fromLTWH(-1e8, -6e7, 2e8, 1.2e8),
        worldTransform: Matrix4.identity()
          ..translateByDouble(100, 60, 0, 1)
          ..scaleByDouble(.000001, .000001, .000001, 1),
      ),
    );
    var gridPixels = 0;
    for (var y = 0; y < raster.height; y++) {
      for (var x = 0; x < raster.width; x++) {
        final pixel = raster.colorAt(x, y);
        expect(pixel >> 24, 255);
        if (pixel != kCityPaper.toARGB32()) gridPixels++;
      }
    }

    expect(gridPixels, greaterThan(0));
    expect(gridPixels, lessThan(raster.width * raster.height ~/ 2));
    expect(raster.recordingBytes, lessThan(128 * 1024));
  });

  test(
    'the label layer toggles road and building names without hiding geometry',
    () async {
      final map = CityMap(
        roads: [
          CityRoad(
            id: 'named-road',
            name: 'Main Street',
            points: const [Offset(20, 36), Offset(220, 36)],
          ),
        ],
        buildings: [
          CityBuilding(
            id: 'named-house',
            kind: CityBuildingKind.house,
            name: 'Library',
            x: 120,
            y: 100,
          ),
        ],
      );
      Future<_Raster> renderLabels(bool showLabels) => _render(
        CityMapPainter(
          map: map,
          showGrid: false,
          showParcels: false,
          showLabels: showLabels,
        ),
        width: 240,
        height: 180,
      );
      final visible = await renderLabels(true);
      final hidden = await renderLabels(false);

      expect(
        _differentPixels(visible, hidden, const Rect.fromLTRB(30, 26, 210, 45)),
        greaterThan(0),
      );
      expect(
        _differentPixels(
          visible,
          hidden,
          const Rect.fromLTRB(50, 129, 190, 150),
        ),
        greaterThan(0),
      );
      expect(hidden.colorAt(30, 43), const Color(0xFFD3D8D5).toARGB32());
      expect(hidden.colorAt(115, 106), const Color(0xFFDCD3BF).toARGB32());
      expect(visible.colorAt(115, 106), hidden.colorAt(115, 106));
    },
  );

  test('crossing road names leave their junction clear', () async {
    final map = CityMap(
      roads: [
        CityRoad(
          id: 'horizontal',
          name: 'Market Avenue',
          points: const [Offset(20, 150), Offset(380, 150)],
        ),
        CityRoad(
          id: 'vertical',
          name: 'Oak Street',
          points: const [Offset(200, 20), Offset(200, 280)],
        ),
      ],
      junctions: [
        CityJunction(
          id: 'crossing',
          position: const Offset(200, 150),
          roadIds: ['horizontal', 'vertical'],
        ),
      ],
    );
    Future<_Raster> renderLabels(bool showLabels) => _render(
      CityMapPainter(map: map, showGrid: false, showLabels: showLabels),
      width: 400,
      height: 300,
    );
    final visible = await renderLabels(true);
    final hidden = await renderLabels(false);

    expect(
      _differentPixels(
        visible,
        hidden,
        const Rect.fromLTRB(180, 130, 220, 170),
      ),
      0,
    );
    expect(
      _differentPixels(visible, hidden, const Rect.fromLTRB(20, 140, 180, 160)),
      greaterThan(0),
    );
    expect(
      _differentPixels(visible, hidden, const Rect.fromLTRB(190, 20, 210, 130)),
      greaterThan(0),
    );
  });

  test('busy building labels hide until their building is selected', () async {
    final map = CityMap(
      buildings: [
        for (final y in [60.0, 120.0, 180.0])
          CityBuilding(
            id: 'house-$y',
            kind: CityBuildingKind.house,
            name: y == 120 ? 'Library' : '',
            x: 120,
            y: y,
          ),
      ],
    );
    Future<_Raster> renderLabels({
      bool showLabels = true,
      String? selectedId,
    }) => _render(
      CityMapPainter(
        map: map,
        showGrid: false,
        showParcels: false,
        showLabels: showLabels,
        selectedId: selectedId,
      ),
      width: 240,
      height: 240,
    );
    final hidden = await renderLabels(showLabels: false);
    final busy = await renderLabels();
    final selected = await renderLabels(selectedId: 'house-120.0');
    final selectedHidden = await renderLabels(
      showLabels: false,
      selectedId: 'house-120.0',
    );

    expect(
      _differentPixels(busy, hidden, const Rect.fromLTWH(0, 0, 240, 240)),
      0,
    );
    expect(
      _differentPixels(
        selected,
        selectedHidden,
        const Rect.fromLTRB(75, 110, 165, 130),
      ),
      greaterThan(0),
    );
  });
}
