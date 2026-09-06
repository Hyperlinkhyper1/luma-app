import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/mind_map/data/mind_map_database.dart';
import 'package:luma/features/plugins/installed/mind_map/io/mind_map_outline.dart';
import 'package:luma/features/plugins/installed/mind_map/migration/school_mind_map_import.dart';
import 'package:luma/features/plugins/installed/mind_map/mind_map_repository.dart';
import 'package:luma/features/plugins/installed/school/data/school_database.dart' as school_db;
import 'package:luma/storage/storage_guard.dart';

void main() {
  // Every write consults the app-wide storage cap, which only main.dart sets.
  setUpAll(() => StorageGuardService.instance = StorageGuardService());

  late MindMapDatabase db;
  late MindMapRepository repo;

  setUp(() {
    db = MindMapDatabase(NativeDatabase.memory());
    repo = MindMapRepository(db);
  });
  tearDown(() => db.close());

  Future<MindMapNode> nodeNamed(int mapId, String label) async {
    final nodes = await repo.nodes(mapId);
    return nodes.firstWhere((n) => n.label == label);
  }

  test('a new map arrives with its root already on the canvas', () async {
    final mapId = await repo.createMap('Photosynthesis');

    final nodes = await repo.nodes(mapId);
    expect(nodes, hasLength(1));
    expect(nodes.single.label, 'Photosynthesis');
    expect(nodes.single.parentId, isNull);
  });

  test('children are appended in order', () async {
    final mapId = await repo.createMap('Root');
    final root = await nodeNamed(mapId, 'Root');

    final first = await repo.addChild(mapId: mapId, parentId: root.id, label: 'A');
    final second = await repo.addChild(mapId: mapId, parentId: root.id, label: 'B');

    final nodes = await repo.nodes(mapId);
    final a = nodes.firstWhere((n) => n.id == first);
    final b = nodes.firstWhere((n) => n.id == second);
    expect(a.sortIndex, lessThan(b.sortIndex));
  });

  test('a sibling lands directly after the node it was added from', () async {
    final mapId = await repo.createMap('Root');
    final root = await nodeNamed(mapId, 'Root');
    final a = await repo.addChild(mapId: mapId, parentId: root.id, label: 'A');
    await repo.addChild(mapId: mapId, parentId: root.id, label: 'C');

    final b = await repo.addSiblingAfter(mapId: mapId, afterId: a, label: 'B');

    final children = (await repo.nodes(mapId))
        .where((n) => n.parentId == root.id)
        .toList()
      ..sort((x, y) => x.sortIndex.compareTo(y.sortIndex));
    expect(children.map((n) => n.label), ['A', 'B', 'C']);
    expect(children[1].id, b);
  });

  test('move reorders a node among its siblings', () async {
    final mapId = await repo.createMap('Root');
    final root = await nodeNamed(mapId, 'Root');
    for (final label in ['A', 'B', 'C']) {
      await repo.addChild(mapId: mapId, parentId: root.id, label: label);
    }
    final c = await nodeNamed(mapId, 'C');

    await repo.move(c.id, -1);

    final children = (await repo.nodes(mapId))
        .where((n) => n.parentId == root.id)
        .toList()
      ..sort((x, y) => x.sortIndex.compareTo(y.sortIndex));
    expect(children.map((n) => n.label), ['A', 'C', 'B']);
  });

  test('move past either end is a no-op', () async {
    final mapId = await repo.createMap('Root');
    final root = await nodeNamed(mapId, 'Root');
    await repo.addChild(mapId: mapId, parentId: root.id, label: 'A');
    final a = await nodeNamed(mapId, 'A');

    await repo.move(a.id, -1);
    await repo.move(a.id, 5);

    expect((await nodeNamed(mapId, 'A')).parentId, root.id);
  });

  test('reparent refuses to move a node inside its own subtree', () async {
    final mapId = await repo.createMap('Root');
    final root = await nodeNamed(mapId, 'Root');
    final parent = await repo.addChild(mapId: mapId, parentId: root.id, label: 'P');
    final child = await repo.addChild(mapId: mapId, parentId: parent, label: 'C');

    expect(await repo.reparent(parent, child), isFalse);
    expect(await repo.reparent(parent, parent), isFalse);
    expect((await nodeNamed(mapId, 'P')).parentId, root.id);
  });

  test('reparent moves a branch onto a new parent', () async {
    final mapId = await repo.createMap('Root');
    final root = await nodeNamed(mapId, 'Root');
    final a = await repo.addChild(mapId: mapId, parentId: root.id, label: 'A');
    final b = await repo.addChild(mapId: mapId, parentId: root.id, label: 'B');
    final leaf = await repo.addChild(mapId: mapId, parentId: a, label: 'Leaf');

    expect(await repo.reparent(a, b), isTrue);

    expect((await nodeNamed(mapId, 'A')).parentId, b);
    expect((await nodeNamed(mapId, 'Leaf')).id, leaf);
    expect((await nodeNamed(mapId, 'Leaf')).parentId, a,
        reason: 'the branch travels with its parent');
  });

  test('deleting takes the whole subtree, and undo puts it back intact', () async {
    final mapId = await repo.createMap('Root');
    final root = await nodeNamed(mapId, 'Root');
    final branch = await repo.addChild(mapId: mapId, parentId: root.id, label: 'Branch');
    await repo.addChild(mapId: mapId, parentId: branch, label: 'Leaf');

    final deletion = await repo.deleteSubtree(branch);

    expect(deletion, isNotNull);
    expect(deletion!.rows, hasLength(2));
    expect(await repo.nodes(mapId), hasLength(1));

    await repo.restore(deletion);

    final restored = await repo.nodes(mapId);
    expect(restored, hasLength(3));
    expect(restored.firstWhere((n) => n.label == 'Leaf').parentId, branch,
        reason: 'ids are reused so the subtree reattaches where it was');
  });

  test('an outline is grafted under the chosen parent', () async {
    final mapId = await repo.createMap('Root');
    final root = await nodeNamed(mapId, 'Root');

    final added = await repo.insertOutline(
      mapId: mapId,
      parentId: root.id,
      roots: MindMapOutline.parse('Research\n  Competitors\n  Pricing\nDesign'),
    );

    expect(added, 4);
    final competitors = await nodeNamed(mapId, 'Competitors');
    final research = await nodeNamed(mapId, 'Research');
    expect(competitors.parentId, research.id);
    expect(research.parentId, root.id);
  });

  test('toOutline round-trips the tree back out', () async {
    final mapId = await repo.createMap('Launch');
    final root = await nodeNamed(mapId, 'Launch');
    await repo.insertOutline(
      mapId: mapId,
      parentId: root.id,
      roots: MindMapOutline.parse('Research\n  Competitors\nDesign'),
    );

    final markdown = MindMapOutline.toMarkdown(await repo.toOutline(mapId));

    expect(markdown, '- Launch\n  - Research\n    - Competitors\n  - Design\n');
  });

  test('node counts are reported per map', () async {
    final first = await repo.createMap('One');
    final second = await repo.createMap('Two');
    final root = await nodeNamed(first, 'One');
    await repo.addChild(mapId: first, parentId: root.id, label: 'Child');

    final counts = await repo.watchNodeCounts().first;

    expect(counts[first], 2);
    expect(counts[second], 1);
  });

  test('deleting a map takes its nodes with it', () async {
    final mapId = await repo.createMap('Doomed');
    final root = await nodeNamed(mapId, 'Doomed');
    await repo.addChild(mapId: mapId, parentId: root.id, label: 'Child');

    await repo.deleteMap(mapId);

    expect(await repo.watchMaps().first, isEmpty);
    expect(await repo.nodes(mapId), isEmpty);
  });

  group('import from the retired School tab', () {
    late school_db.SchoolDatabase school;

    setUp(() => school = school_db.SchoolDatabase(NativeDatabase.memory()));
    tearDown(() => school.close());

    Future<int> legacyMap(String title) => school.into(school.mindMaps).insert(
          school_db.MindMapsCompanion.insert(title: title),
        );

    Future<int> legacyNode(
      int mapId,
      String label, {
      int? parentId,
      double x = 0,
      double y = 0,
    }) =>
        school.into(school.mindMapNodes).insert(
              school_db.MindMapNodesCompanion.insert(
                mapId: mapId,
                label: label,
                parentId: Value(parentId),
                x: Value(x),
                y: Value(y),
              ),
            );

    test('maps and their structure come across', () async {
      final mapId = await legacyMap('Photosynthesis');
      final rootId = await legacyNode(mapId, 'Root');
      await legacyNode(mapId, 'Light', parentId: rootId, y: 10);
      await legacyNode(mapId, 'Water', parentId: rootId, y: 90);

      expect(await SchoolMindMapImport.run(school: school, target: repo), 1);

      final maps = await repo.watchMaps().first;
      expect(maps.single.title, 'Photosynthesis');
      final nodes = await repo.nodes(maps.single.id);
      expect(nodes, hasLength(3));

      final root = nodes.firstWhere((n) => n.label == 'Root');
      final light = nodes.firstWhere((n) => n.label == 'Light');
      final water = nodes.firstWhere((n) => n.label == 'Water');
      expect(light.parentId, root.id);
      expect(light.sortIndex, lessThan(water.sortIndex),
          reason: 'the old freeform y position becomes sibling order');
    });

    test('running twice does not duplicate anything', () async {
      final mapId = await legacyMap('Once');
      await legacyNode(mapId, 'Root');

      expect(await SchoolMindMapImport.run(school: school, target: repo), 1);
      expect(await SchoolMindMapImport.run(school: school, target: repo), 0);
      expect(await repo.watchMaps().first, hasLength(1));
    });

    test('a node in a parent loop is rescued as a root instead of vanishing',
        () async {
      final mapId = await legacyMap('Broken');
      final a = await legacyNode(mapId, 'A');
      final b = await legacyNode(mapId, 'B', parentId: a);
      await (school.update(school.mindMapNodes)
            ..where((t) => t.id.equals(a)))
          .write(school_db.MindMapNodesCompanion(parentId: Value(b)));
      await legacyNode(mapId, 'Orphan', parentId: 9999);

      await SchoolMindMapImport.run(school: school, target: repo);

      final maps = await repo.watchMaps().first;
      final nodes = await repo.nodes(maps.single.id);
      expect(nodes.map((n) => n.label), containsAll(['A', 'B', 'Orphan']));
      expect(nodes.firstWhere((n) => n.label == 'Orphan').parentId, isNull);
    });

    test('an empty School database still marks the check as done', () async {
      expect(await SchoolMindMapImport.run(school: school, target: repo), 0);
      expect(await repo.schoolMapsImported, isTrue);
    });
  });
}
