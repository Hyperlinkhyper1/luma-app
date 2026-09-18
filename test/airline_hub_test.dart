import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/data/buildings.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/sim/hub.dart';

PlacedBuilding b(BuildingKind kind, int x, int y, [int rotation = 0]) =>
    PlacedBuilding(kind: kind, x: x, y: y, rotation: rotation);

void main() {
  group('footprints', () {
    test('a 2x2 terminal covers four tiles', () {
      final terminal = b(BuildingKind.terminal, 3, 4);
      expect(terminal.tiles.toSet(), {
        (x: 3, y: 4),
        (x: 4, y: 4),
        (x: 3, y: 5),
        (x: 4, y: 5),
      });
    });

    test('rotating an oblong runway swaps its width and depth', () {
      final upright = b(BuildingKind.runwayShort, 0, 0);
      final turned = b(BuildingKind.runwayShort, 0, 0, 1);
      expect(upright.size, (width: 1, depth: 5));
      expect(turned.size, (width: 5, depth: 1));
      expect(upright.tiles.length, turned.tiles.length);
    });

    test('the border touches edges but not corners', () {
      final gate = b(BuildingKind.gate, 5, 5);
      final border = gate.border.toSet();
      expect(border, contains((x: 4, y: 5)));
      expect(border, contains((x: 6, y: 5)));
      expect(border, contains((x: 5, y: 4)));
      expect(border, contains((x: 5, y: 6)));
      // Diagonals are deliberately excluded so adjacency is legible.
      expect(border, isNot(contains((x: 4, y: 4))));
      expect(border, isNot(contains((x: 6, y: 6))));
    });
  });

  group('placement', () {
    test('a building inside an empty grid is allowed', () {
      expect(HubGrid.check(b(BuildingKind.gate, 5, 5), 12, const []), isNull);
    });

    test('a building hanging off the edge is refused', () {
      expect(
        HubGrid.check(b(BuildingKind.terminal, 11, 11), 12, const []),
        PlacementError.outOfBounds,
      );
    });

    test('negative coordinates are refused', () {
      expect(
        HubGrid.check(b(BuildingKind.gate, -1, 3), 12, const []),
        PlacementError.outOfBounds,
      );
    });

    test('overlapping an existing building is refused', () {
      final existing = [b(BuildingKind.terminal, 5, 5)];
      expect(
        HubGrid.check(b(BuildingKind.gate, 6, 6), 12, existing),
        PlacementError.overlaps,
      );
    });

    test('touching an existing building is fine', () {
      final existing = [b(BuildingKind.terminal, 5, 5)];
      expect(HubGrid.check(b(BuildingKind.gate, 4, 5), 12, existing), isNull);
    });

    test('a rotated runway is bounds-checked along its rotated axis', () {
      // 1x5 upright fits at x=11; turned 5x1 it would run off the edge.
      expect(HubGrid.check(b(BuildingKind.runwayShort, 11, 0), 12, const []),
          isNull);
      expect(
        HubGrid.check(b(BuildingKind.runwayShort, 11, 0, 1), 12, const []),
        PlacementError.outOfBounds,
      );
    });

    test('lookup finds the building covering any of its tiles', () {
      final buildings = [b(BuildingKind.terminal, 5, 5)];
      expect(HubGrid.at((x: 6, y: 6), buildings), isNotNull);
      expect(HubGrid.at((x: 7, y: 7), buildings), isNull);
    });
  });

  group('gates and terminals', () {
    test('an empty field has no capacity at all', () {
      expect(HubGrid.resolve(const []).activeGates, 0);
      expect(HubGrid.resolve(const []).maxRunwayM, 0);
    });

    test('a gate touching a terminal is active', () {
      final effects = HubGrid.resolve([
        b(BuildingKind.terminal, 5, 5),
        b(BuildingKind.gate, 4, 5),
      ]);
      expect(effects.activeGates, 1);
      expect(effects.inactiveGates, 0);
    });

    test('a gate on its own is built, paid for, and useless', () {
      // The rule the whole builder teaches in its first thirty seconds.
      final effects = HubGrid.resolve([
        b(BuildingKind.terminal, 0, 0),
        b(BuildingKind.gate, 9, 9),
      ]);
      expect(effects.activeGates, 0);
      expect(effects.inactiveGates, 1);
    });

    test('a gate touching only a corner of a terminal does not count', () {
      final effects = HubGrid.resolve([
        b(BuildingKind.terminal, 5, 5),
        b(BuildingKind.gate, 4, 4),
      ]);
      expect(effects.activeGates, 0);
      expect(effects.inactiveGates, 1);
    });

    test('gates count up as they are added along a terminal', () {
      final effects = HubGrid.resolve([
        b(BuildingKind.terminal, 5, 5),
        b(BuildingKind.gate, 4, 5),
        b(BuildingKind.gate, 4, 6),
        b(BuildingKind.gate, 7, 5),
      ]);
      expect(effects.activeGates, 3);
    });
  });

  group('runways', () {
    test('the longest runway on the field is what counts', () {
      final effects = HubGrid.resolve([
        b(BuildingKind.runwayShort, 0, 0),
        b(BuildingKind.runwayLong, 2, 0),
        b(BuildingKind.runwayMedium, 4, 0),
      ]);
      expect(effects.maxRunwayM, 3400);
    });

    test('runway length is unaffected by rotation', () {
      expect(HubGrid.resolve([b(BuildingKind.runwayLong, 0, 0, 1)]).maxRunwayM,
          3400);
    });
  });

  group('adjacency bonuses', () {
    test('a hangar cuts maintenance', () {
      final effects = HubGrid.resolve([b(BuildingKind.hangar, 5, 5)]);
      expect(effects.maintenanceMultiplier, closeTo(0.92, 1e-9));
    });

    test('a hangar opening onto an apron cuts it further', () {
      final plain = HubGrid.resolve([b(BuildingKind.hangar, 5, 5)]);
      final withApron = HubGrid.resolve([
        b(BuildingKind.hangar, 5, 5),
        b(BuildingKind.apron, 4, 5),
      ]);
      expect(
        withApron.maintenanceMultiplier,
        lessThan(plain.maintenanceMultiplier),
      );
    });

    test('maintenance savings stop at the floor', () {
      final many = [
        for (var i = 0; i < 12; i++) b(BuildingKind.hangar, i * 2, 0),
      ];
      expect(HubGrid.resolve(many).maintenanceMultiplier, 0.65);
    });

    test('a fuel depot cuts fuel, and stops at its own floor', () {
      expect(
        HubGrid.resolve([b(BuildingKind.fuelDepot, 3, 3)]).fuelMultiplier,
        closeTo(0.94, 1e-9),
      );
      final many = [
        for (var i = 0; i < 10; i++) b(BuildingKind.fuelDepot, i, 0),
      ];
      expect(HubGrid.resolve(many).fuelMultiplier, 0.80);
    });

    test('a lounge only pays off when it touches a terminal', () {
      final stranded = HubGrid.resolve([
        b(BuildingKind.terminal, 0, 0),
        b(BuildingKind.lounge, 9, 9),
      ]);
      final attached = HubGrid.resolve([
        b(BuildingKind.terminal, 5, 5),
        b(BuildingKind.lounge, 4, 5),
      ]);
      expect(stranded.premiumMultiplier, 1);
      expect(attached.premiumMultiplier, closeTo(1.04, 1e-9));
    });

    test('the lounge premium is capped', () {
      final buildings = <PlacedBuilding>[b(BuildingKind.terminal, 5, 5)];
      for (var i = 0; i < 10; i++) {
        buildings.add(b(BuildingKind.lounge, 4, i));
      }
      expect(HubGrid.resolve(buildings).premiumMultiplier, lessThanOrEqualTo(1.20));
    });

    test('a cargo terminal switches belly freight on', () {
      expect(HubGrid.resolve(const []).hasCargo, isFalse);
      expect(HubGrid.resolve([b(BuildingKind.cargo, 2, 2)]).hasCargo, isTrue);
    });

    test('upkeep is the sum of everything built', () {
      final effects = HubGrid.resolve([
        b(BuildingKind.terminal, 5, 5),
        b(BuildingKind.gate, 4, 5),
      ]);
      expect(
        effects.upkeepPerDayEur,
        buildingDef(BuildingKind.terminal).upkeepPerDayEur +
            buildingDef(BuildingKind.gate).upkeepPerDayEur,
      );
    });
  });

  group('serialisation', () {
    test('a placed building round-trips through JSON', () {
      final original = b(BuildingKind.runwayMedium, 7, 2, 1);
      final restored = PlacedBuilding.fromJson(original.toJson())!;
      expect(restored.kind, original.kind);
      expect(restored.x, original.x);
      expect(restored.y, original.y);
      expect(restored.rotation, original.rotation);
    });

    test('an unknown building kind is dropped rather than thrown on', () {
      expect(
        PlacedBuilding.fromJson(const {'kind': 'monorail', 'x': 1, 'y': 1}),
        isNull,
      );
    });

    test('a row missing coordinates is dropped', () {
      expect(PlacedBuilding.fromJson(const {'kind': 'gate'}), isNull);
    });
  });
}
