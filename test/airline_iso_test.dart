import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/airline_tycoon/sim/iso.dart';

void main() {
  const camera = IsoCamera(origin: Offset(400, 80));

  group('projection round-trip', () {
    test('every ground point survives project then unproject', () {
      // This is the property that guarantees what the player taps is what the
      // painter drew. If it ever fails, picking and drawing have drifted
      // apart and every placement lands on the wrong tile.
      for (var x = 0; x <= 24; x++) {
        for (var y = 0; y <= 24; y++) {
          final gx = x + 0.5;
          final gy = y + 0.5;
          final back = camera.screenToGround(camera.project(gx, gy));
          expect(back.x, closeTo(gx, 1e-9), reason: 'x at ($gx, $gy)');
          expect(back.y, closeTo(gy, 1e-9), reason: 'y at ($gx, $gy)');
        }
      }
    });

    test('the round trip holds for a camera at the origin too', () {
      const plain = IsoCamera();
      final back = plain.screenToGround(plain.project(3.25, 7.75));
      expect(back.x, closeTo(3.25, 1e-9));
      expect(back.y, closeTo(7.75, 1e-9));
    });

    test('elevation moves a point straight up the screen', () {
      final ground = camera.project(4, 4);
      final raised = camera.project(4, 4, 2);
      expect(raised.dx, closeTo(ground.dx, 1e-9));
      expect(raised.dy, closeTo(ground.dy - 2 * camera.levelHeight, 1e-9));
    });

    test('the grid is drawn as a diamond, not a square', () {
      // Tile (0,0) and tile (1,1) differ only in screen y; (1,0) and (0,1)
      // differ only in screen x. That is what makes it read as isometric.
      final a = camera.project(0, 0);
      final b = camera.project(1, 1);
      expect(a.dx, closeTo(b.dx, 1e-9));
      expect(b.dy, greaterThan(a.dy));

      final c = camera.project(1, 0);
      final d = camera.project(0, 1);
      expect(c.dy, closeTo(d.dy, 1e-9));
      expect(c.dx, greaterThan(d.dx));
    });
  });

  group('tile picking', () {
    test('the centre of every tile picks that tile', () {
      const gridSize = 12;
      for (var x = 0; x < gridSize; x++) {
        for (var y = 0; y < gridSize; y++) {
          final centre = camera.project(x + 0.5, y + 0.5);
          expect(camera.tileAt(centre, gridSize), (x: x, y: y));
        }
      }
    });

    test('a point just inside a tile edge still picks it', () {
      final nearEdge = camera.project(3.01, 5.99);
      expect(camera.tileAt(nearEdge, 12), (x: 3, y: 5));
    });

    test('a point outside the grid picks nothing rather than the wrong tile',
        () {
      expect(camera.tileAt(camera.project(-0.5, 5), 12), isNull);
      expect(camera.tileAt(camera.project(5, -0.5), 12), isNull);
      expect(camera.tileAt(camera.project(12.5, 5), 12), isNull);
      expect(camera.tileAt(camera.project(5, 12.5), 12), isNull);
    });

    test('a grid that grew accepts points the smaller one refused', () {
      final beyond = camera.project(15.5, 15.5);
      expect(camera.tileAt(beyond, 12), isNull);
      expect(camera.tileAt(beyond, 24), (x: 15, y: 15));
    });
  });

  group('tile diamond', () {
    test('has four corners in clockwise order from the top', () {
      final corners = camera.tileDiamond(4, 4);
      expect(corners.length, 4);
      // North corner is the highest on screen; south is the lowest.
      final ys = corners.map((c) => c.dy).toList();
      expect(ys.first, lessThan(ys[1]));
      expect(ys.first, lessThan(ys[3]));
      expect(ys[2], greaterThan(ys.first));
    });

    test('adjacent tiles share an edge exactly', () {
      final left = camera.tileDiamond(3, 4);
      final right = camera.tileDiamond(4, 4);
      // Tile (3,4)'s east corner is tile (4,4)'s north corner.
      expect((left[1] - right[0]).distance, closeTo(0, 1e-9));
    });
  });

  group('layout', () {
    test('the canvas holds the whole grid plus headroom', () {
      final layout = IsoCamera.layout(12);
      final fitted = IsoCamera(origin: layout.origin);

      for (final corner in [
        fitted.project(0, 0),
        fitted.project(12, 0),
        fitted.project(0, 12),
        fitted.project(12, 12),
      ]) {
        expect(corner.dx, inInclusiveRange(0, layout.size.width));
        expect(corner.dy, inInclusiveRange(0, layout.size.height));
      }
    });

    test('the tallest building still fits above the grid', () {
      final layout = IsoCamera.layout(12, maxLevels: 4);
      final fitted = IsoCamera(origin: layout.origin);
      expect(fitted.project(0, 0, 4).dy, greaterThanOrEqualTo(0));
    });

    test('a bigger grid needs a bigger canvas', () {
      expect(
        IsoCamera.layout(24).size.width,
        greaterThan(IsoCamera.layout(12).size.width),
      );
    });
  });

  group('draw order', () {
    test('depth grows away from the camera', () {
      // Painter's algorithm: smaller key drawn first, so (0,0) is behind
      // (5,5) and must be emitted before it.
      expect(IsoCamera.depthKey(0, 0), lessThan(IsoCamera.depthKey(5, 5)));
      expect(IsoCamera.depthKey(3, 1), IsoCamera.depthKey(1, 3));
    });

    test('sorting by depth key never puts a near tile behind a far one', () {
      final tiles = [
        for (var x = 0; x < 6; x++)
          for (var y = 0; y < 6; y++) (x: x, y: y),
      ]..sort((a, b) =>
          IsoCamera.depthKey(a.x, a.y).compareTo(IsoCamera.depthKey(b.x, b.y)));

      var previous = -1;
      for (final tile in tiles) {
        final key = IsoCamera.depthKey(tile.x, tile.y);
        expect(key, greaterThanOrEqualTo(previous));
        previous = key;
      }
    });
  });
}
