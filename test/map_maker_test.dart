import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/map_maker/map_maker_geometry.dart';
import 'package:luma/features/plugins/installed/map_maker/map_maker_models.dart';
import 'package:luma/features/plugins/installed/map_maker/map_maker_store.dart';

void main() {
  group('Map Maker Geometry', () {
    test('snapToTransitGrid snaps coordinates', () {
      expect(snapToTransitGrid(const Offset(23, 25)), const Offset(24, 24));
      expect(snapToTransitGrid(const Offset(0, 0)), const Offset(0, 0));
      expect(snapToTransitGrid(const Offset(47, 49)), const Offset(48, 48));
    });

    test('octilinearPath handles horizontal, vertical and 45 degree runs', () {
      // Horizontal
      final h = octilinearPath(const Offset(0, 0), const Offset(100, 0));
      expect(h, [const Offset(0, 0), const Offset(100, 0)]);

      // Vertical
      final v = octilinearPath(const Offset(0, 0), const Offset(0, 100));
      expect(v, [const Offset(0, 0), const Offset(0, 100)]);

      // 45 degrees
      final diag = octilinearPath(const Offset(0, 0), const Offset(100, 100));
      expect(diag, [const Offset(0, 0), const Offset(100, 100)]);

      // Arbitrary run: bends octilinearly
      final bent = octilinearPath(const Offset(0, 0), const Offset(100, 40));
      expect(bent.length, 3);
      expect(bent.first, const Offset(0, 0));
      expect(bent.last, const Offset(100, 40));
    });
  });

  group('Map Maker Models', () {
    test('TransitStation serialization and properties', () {
      final st = TransitStation(
        id: 'st_1',
        name: 'Central Plaza',
        x: 120,
        y: 240,
        kind: TransitStationKind.transfer,
      );
      final json = st.toJson();
      final restored = TransitStation.fromJson(json);

      expect(restored.id, 'st_1');
      expect(restored.name, 'Central Plaza');
      expect(restored.position, const Offset(120, 240));
      expect(restored.kind, TransitStationKind.transfer);
    });

    test('TransitMap manages lines and stations', () {
      final map = TransitMap.empty(firstLineName: 'Red Line');
      expect(map.lines.length, 1);
      expect(map.lines.first.name, 'Red Line');

      final s1 = TransitStation(id: 's1', name: 'Stop A', x: 0, y: 0);
      final s2 = TransitStation(id: 's2', name: 'Stop B', x: 48, y: 0);
      map.addStation(s1);
      map.addStation(s2);

      map.appendStop(map.lines.first.id, s1.id);
      map.appendStop(map.lines.first.id, s2.id);

      expect(map.lines.first.stationIds, ['s1', 's2']);
      expect(map.linePolyline(map.lines.first), [
        const Offset(0, 0),
        const Offset(48, 0),
      ]);

      // Remove station also cleans up line references
      map.removeStation('s1');
      expect(map.stations.length, 1);
      expect(map.lines.first.stationIds, ['s2']);
    });

    test('MapMakerSave serialization round-trip', () {
      final save = MapMakerSave(
        id: 'save_123',
        title: 'Fantasy Metro',
        kind: MapMakerKind.transit,
        updatedAt: DateTime.now(),
      );
      final json = save.toJson();
      final restored = MapMakerSave.fromJson(json);

      expect(restored.id, 'save_123');
      expect(restored.title, 'Fantasy Metro');
      expect(restored.kind, MapMakerKind.transit);
      expect(restored.transit.lines.isNotEmpty, true);
    });
  });

  group('MapMakerStore in-memory', () {
    test('CRUD operations in store', () async {
      final store = MapMakerStore.memory();
      expect(store.saves.isEmpty, true);

      final save = await store.createTransit(title: 'Metropolis');
      expect(store.saves.length, 1);
      expect(store.byId(save.id)?.title, 'Metropolis');

      await store.rename(save.id, 'New Metropolis');
      expect(store.byId(save.id)?.title, 'New Metropolis');

      await store.delete(save.id);
      expect(store.saves.isEmpty, true);
    });
  });
}
