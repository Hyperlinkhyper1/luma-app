import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/home/home_layout.dart';
import 'package:luma/features/home/home_repository.dart';
import 'package:luma/sync/sync_state.dart';

HomeTile tile(String id, int x, int y, {int w = 4, int h = 4}) =>
    HomeTile(id: id, kind: 'clock', x: x, y: y, w: w, h: h);

void main() {
  test('original dashboard is editable default on both device formats', () {
    for (final family in ['desktop', 'phone']) {
      final layout = HomeLayout.defaults(family);
      expect(layout.tiles.map((t) => t.kind), [
        'income',
        'spending',
        'pots',
        'investments',
        'shortcut',
        'shortcut',
        'shortcut',
        'shortcut',
        'recent_activity',
      ]);
      expect(layout.heroMetric, 'netWorth');
      final edited = layout.place(layout.tiles.first.copyWith(y: 40));
      expect(edited.tiles.first.y, 40);
      for (final tile in layout.tiles) {
        expect(tile.x + tile.w, lessThanOrEqualTo(layout.columns));
        expect(
          layout.tiles.where((other) => other.id != tile.id).any(tile.overlaps),
          false,
        );
      }
    }
  });

  test('only untouched previous defaults migrate to original dashboard', () {
    final legacy = {
      'columns': 12,
      'tiles': [
        const HomeTile(
          id: 'clock',
          kind: 'clock',
          x: 0,
          y: 0,
          w: 6,
          h: 4,
        ).toJson(),
        const HomeTile(
          id: 'timer',
          kind: 'timer',
          x: 6,
          y: 0,
          w: 6,
          h: 4,
        ).toJson(),
        const HomeTile(
          id: 'finance',
          kind: 'finance',
          x: 0,
          y: 4,
          w: 6,
          h: 6,
        ).toJson(),
        const HomeTile(
          id: 'notes',
          kind: 'note',
          x: 6,
          y: 4,
          w: 6,
          h: 6,
        ).toJson(),
      ],
    };
    expect(HomeLayout.fromJson(legacy, columns: 12).tiles.first.kind, 'income');
    (legacy['tiles'] as List).removeLast();
    expect(HomeLayout.fromJson(legacy, columns: 12).tiles.first.kind, 'clock');
  });
  test('an untouched first grid layout follows the new tile sizes', () {
    Map<String, dynamic> saved({required bool phone}) {
      final columns = phone ? 4 : 12;
      const metrics = ['income', 'spending', 'pots', 'investments'];
      const shortcuts = [
        'assistant',
        'finance-shortcut',
        'converter',
        'settings',
      ];
      const destinations = [5, 2, 1, 7];
      return {
        'columns': columns,
        'heroMetric': 'cash',
        'heroLabel': '',
        'heroText': '',
        'tiles': [
          for (var i = 0; i < 4; i++)
            HomeTile(
              id: metrics[i],
              kind: metrics[i],
              x: phone ? 0 : (i % 2) * 6,
              y: phone ? i * 3 : (i ~/ 2) * 3,
              w: phone ? 4 : 6,
              h: 3,
            ).toJson(),
          for (var i = 0; i < 4; i++)
            HomeTile(
              id: shortcuts[i],
              kind: 'shortcut',
              x: phone ? 0 : i * 3,
              y: phone ? 13 + i * 4 : 7,
              w: phone ? 4 : 3,
              h: 4,
              config: {'destination': destinations[i]},
            ).toJson(),
          HomeTile(
            id: 'recent',
            kind: 'recent_activity',
            x: 0,
            y: phone ? 30 : 12,
            w: phone ? 4 : 12,
            h: 6,
          ).toJson(),
        ],
      };
    }

    for (final phone in [false, true]) {
      final columns = phone ? 4 : 12;
      final raw = saved(phone: phone);
      final migrated = HomeLayout.fromJson(raw, columns: columns);
      final fresh = HomeLayout.defaults(phone ? 'phone' : 'desktop');
      expect(
        migrated.tiles.map((t) => t.toJson()),
        fresh.tiles.map((t) => t.toJson()),
      );
      expect(migrated.heroMetric, 'cash');

      final moved = saved(phone: phone);
      (moved['tiles'] as List)[4] = {
        ...(moved['tiles'] as List)[4] as Map<String, dynamic>,
        'h': 5,
      };
      final kept = HomeLayout.fromJson(moved, columns: columns);
      expect(kept.tiles[4].h, 5);
      expect(kept.tiles[8].h, 6);
    }
  });

  test('greeting summary survives placement and snapshot round trips', () {
    final layout = HomeLayout(
      columns: 12,
      tiles: [],
      heroMetric: 'custom',
      heroLabel: 'Today',
      heroText: 'Build something lovely',
    );
    final moved = layout.place(tile('clock', 0, 0));
    final restored = HomeLayout.fromJson(moved.toJson(), columns: 12);
    expect(restored.heroMetric, 'custom');
    expect(restored.heroLabel, 'Today');
    expect(restored.heroText, 'Build something lovely');
    final legacy = HomeLayout.fromJson({
      'columns': 12,
      'tiles': [],
    }, columns: 12);
    expect(legacy.heroMetric, 'netWorth');
    expect(legacy.heroText, isEmpty);
  });
  test(
    'moving a tile preserves its target and cascades collisions downward',
    () {
      final original = HomeLayout(
        columns: 12,
        tiles: [
          tile('a', 0, 0),
          tile('b', 4, 0),
          tile('c', 4, 4),
          tile('d', 8, 0),
        ],
      );
      final moved = original.place(original.tiles.first.copyWith(x: 4));
      expect(moved.tiles.map((t) => t.y), [0, 4, 8, 0]);
      expect(moved.tiles.first.x, 4);
      expect(original.tiles.first.x, 0);
      for (final a in moved.tiles) {
        for (final b in moved.tiles.where((b) => b.id != a.id)) {
          expect(a.overlaps(b), false);
        }
      }
      expect(
        HomeLayout.fromJson(moved.toJson(), columns: 12).toJson(),
        moved.toJson(),
      );
    },
  );

  test('resize clamps to grid and pushes occupied tiles below', () {
    final original = HomeLayout(
      columns: 4,
      tiles: [tile('a', 0, 0, w: 2), tile('b', 2, 0, w: 2)],
    );
    final resized = original.place(original.tiles.first.copyWith(w: 20));
    expect(resized.tiles.first.w, 4);
    expect(resized.tiles.last.y, 4);
    final bounded = original.place(tile('c', -10, -100, w: 100));
    expect(bounded.tiles.last.x, 0);
    expect(bounded.tiles.last.y, 0);
  });

  test(
    'invalid layouts fail without accepting duplicated IDs or wrong format',
    () {
      expect(
        () => HomeLayout.fromJson({
          'columns': 12,
          'tiles': [tile('a', 0, 0).toJson(), tile('a', 4, 0).toJson()],
        }, columns: 12),
        throwsFormatException,
      );
      expect(
        () => HomeLayout.fromJson(
          HomeLayout.defaults('phone').toJson(),
          columns: 12,
        ),
        throwsFormatException,
      );
    },
  );

  test('device format depends on platform rather than window size', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(HomeRepository.deviceFamily, 'desktop');
    }
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(HomeRepository.deviceFamily, 'phone');
    }
    expect(isAutomaticSyncCollection('home_desktop'), true);
    expect(isAutomaticSyncCollection('home_phone'), true);
    expect(isAutomaticSyncCollection('notes'), false);
  });

  group('persisted home layouts', () {
    late Directory directory;
    final repositories = <HomeRepository>[];
    HomeRepository open(String name, String family) {
      final repo = HomeRepository(
        family: family,
        file: () async => File('${directory.path}/$name.json'),
      );
      repositories.add(repo);
      return repo;
    }

    setUp(
      () async =>
          directory = await Directory.systemTemp.createTemp('luma-home-test-'),
    );
    tearDown(() async {
      for (final repo in repositories) {
        repo.dispose();
      }
      repositories.clear();
      await directory.delete(recursive: true);
    });

    test(
      'save survives restart and same-format devices can import it',
      () async {
        final desktop = open('desktop', 'desktop');
        await desktop.ready;
        final custom = HomeLayout(columns: 12, tiles: [tile('favorite', 5, 7)]);
        await desktop.save(custom);
        final restarted = open('desktop', 'desktop');
        await restarted.ready;
        expect(restarted.layout.toJson(), custom.toJson());
        final laptop = open('laptop', 'desktop');
        await laptop.importData(await desktop.exportData());
        expect(laptop.layout.toJson(), custom.toJson());
        expect(laptop.collectionId, desktop.collectionId);
      },
    );

    test(
      'phone rejects desktop snapshots without modifying its own layout',
      () async {
        final desktop = open('desktop', 'desktop');
        final phone = open('phone', 'phone');
        await phone.ready;
        final before = phone.layout.toJson();
        await expectLater(
          phone.importData(await desktop.exportData()),
          throwsFormatException,
        );
        expect(phone.layout.toJson(), before);
        expect(phone.collectionId, isNot(desktop.collectionId));
      },
    );

    test(
      'empty layout persists and queued saves retain the latest edit',
      () async {
        final repo = open('desktop', 'desktop');
        await Future.wait([
          repo.save(HomeLayout(columns: 12, tiles: [tile('one', 1, 1)])),
          repo.save(HomeLayout(columns: 12, tiles: [])),
        ]);
        final restarted = open('desktop', 'desktop');
        await restarted.ready;
        expect(restarted.layout.tiles, isEmpty);
      },
    );

    test(
      'corrupt saved layouts are preserved and not silently synced as defaults',
      () async {
        final file = File('${directory.path}/corrupt.json');
        await file.writeAsString('{bad json');
        final repo = open('corrupt', 'desktop');
        await repo.ready;
        expect(repo.loadError, isNotNull);
        await expectLater(repo.exportData(), throwsStateError);
        expect(await file.readAsString(), '{bad json');
        await repo.save(HomeLayout(columns: 12, tiles: []));
        expect(repo.loadError, isNull);
        expect(jsonDecode(await file.readAsString())['family'], 'desktop');
      },
    );
  });
}
