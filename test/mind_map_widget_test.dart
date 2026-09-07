import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/mind_map/data/mind_map_database.dart';
import 'package:luma/features/plugins/installed/mind_map/mind_map_repository.dart';
import 'package:luma/features/plugins/installed/mind_map/mind_map_scope.dart';
import 'package:luma/features/plugins/installed/mind_map/ui/mind_map_canvas.dart';
import 'package:luma/features/plugins/installed/mind_map/ui/mind_map_node_card.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';

/// The canvas is meant to be driven entirely from the keyboard, so the flow
/// people will actually use — select, Tab, type, Enter, type — is exercised
/// here rather than left to a manual pass in the running app.
///
/// Two rules keep this file working against a real database. Every query goes
/// through [WidgetTester.runAsync], because drift's futures never complete in
/// the fake-async zone a widget test normally runs in. And frames are driven
/// by [_settle] rather than `pumpAndSettle`, because until the node stream
/// emits, `StreamData` shows a spinner that never stops animating.
void main() {
  late MindMapDatabase db;
  late MindMapRepository repo;

  setUp(() {
    db = MindMapDatabase(NativeDatabase.memory());
    repo = MindMapRepository(db);
    // Every write arms a three-second debounce that rescans the app's storage
    // directory. There is no path_provider here to answer it, so each test
    // gets its own guard and disposes it before the frame budget runs out.
    StorageGuardService.instance = StorageGuardService();
  });
  tearDown(() => db.close());

  /// Runs real asynchronous work (a database call) from inside a widget test.
  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async {
    final result = await tester.runAsync(body);
    return result as T;
  }

  /// Advances the fake clock and real time in turn.
  ///
  /// The order matters: pumping first lets any timer the widgets are waiting
  /// on fire, and only then does `runAsync` give the database a slice of real
  /// time to finish its work. Doing it the other way round can deadlock — a
  /// query queued behind a timer that only the fake clock can fire.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    // Let the node cards' implicit animations run out.
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<int> pumpMap(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
  }) async {
    final mapId = await real(tester, () => repo.createMap('Launch'));
    final map = await real(tester, () => repo.watchMap(mapId).first);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          theme: LumaTheme.dark,
          home: Scaffold(
            body: MindMapScope(
              repository: repo,
              child: MindMapCanvas(
                map: map!,
                repository: repo,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return mapId;
  }

  /// Finds text inside a node card, so the map's title in the toolbar is
  /// never mistaken for the node itself.
  Finder nodeLabelled(String label) => find.descendant(
        of: find.byType(MindMapNodeCard),
        matching: find.text(label),
      );

  Future<void> selectNode(WidgetTester tester, String label) async {
    await tester.tap(nodeLabelled(label));
    await settle(tester);
  }

  Future<void> pressKey(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await settle(tester);
  }

  Future<void> typeLabel(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await settle(tester);
  }

  /// A widget test that tears its own tree down before finishing.
  ///
  /// The binding asserts that no timer is pending once the tree is disposed,
  /// and this screen leaves several behind: drift closes its query stream on
  /// a zero-duration timer, and an undo snackbar sits on a six-second one.
  /// Unmounting here and then pumping past the longest of them lets each fire
  /// while there is still a frame to run.
  void mapTest(String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      StorageGuardService.instance.dispose();
      await tester.pump(const Duration(seconds: 8));
    });
  }

  mapTest('the map opens on its root with a hint about Tab', (tester) async {
    await pumpMap(tester);

    expect(nodeLabelled('Launch'), findsOneWidget);
    expect(
      find.textContaining('press Tab to add your first branch'),
      findsOneWidget,
    );
  });

  mapTest('Tab adds a child and drops straight into typing it',
      (tester) async {
    final mapId = await pumpMap(tester);
    await selectNode(tester, 'Launch');

    await pressKey(tester, LogicalKeyboardKey.tab);

    expect(find.byType(TextField), findsOneWidget,
        reason: 'the new node is edited in place, not through a dialog');

    await typeLabel(tester, 'Research');
    await pressKey(tester, LogicalKeyboardKey.escape);

    final nodes = await real(tester, () => repo.nodes(mapId));
    expect(nodes, hasLength(2));
    final root = nodes.firstWhere((n) => n.label == 'Launch');
    expect(nodes.firstWhere((n) => n.label == 'Research').parentId, root.id);
  });

  mapTest('Enter chains siblings so a list can be typed straight in',
      (tester) async {
    final mapId = await pumpMap(tester);
    await selectNode(tester, 'Launch');

    await pressKey(tester, LogicalKeyboardKey.tab);
    await typeLabel(tester, 'Research');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await typeLabel(tester, 'Design');
    await pressKey(tester, LogicalKeyboardKey.escape);

    final nodes = await real(tester, () => repo.nodes(mapId));
    final root = nodes.firstWhere((n) => n.label == 'Launch');
    final children = nodes.where((n) => n.parentId == root.id).toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    expect(children.map((n) => n.label), ['Research', 'Design']);
  });

  mapTest('a new node left blank is dropped rather than littering the map',
      (tester) async {
    final mapId = await pumpMap(tester);
    await selectNode(tester, 'Launch');

    await pressKey(tester, LogicalKeyboardKey.tab);
    await pressKey(tester, LogicalKeyboardKey.escape);

    expect(await real(tester, () => repo.nodes(mapId)), hasLength(1));
  });

  /// Builds Launch > Research > Competitors the way a user would, so the
  /// fixture never has to reach the database from outside the fake clock.
  Future<void> buildBranch(WidgetTester tester) async {
    await selectNode(tester, 'Launch');
    await pressKey(tester, LogicalKeyboardKey.tab);
    await typeLabel(tester, 'Research');
    await pressKey(tester, LogicalKeyboardKey.tab);
    await typeLabel(tester, 'Competitors');
    await pressKey(tester, LogicalKeyboardKey.escape);
  }

  mapTest('Delete removes the branch and offers an undo', (tester) async {
    await pumpMap(tester);
    await buildBranch(tester);

    await selectNode(tester, 'Research');
    await pressKey(tester, LogicalKeyboardKey.delete);

    // Checked through the canvas rather than the database: the snackbar holds
    // its own timer, and querying across it deadlocks the two clocks.
    expect(nodeLabelled('Research'), findsNothing);
    expect(nodeLabelled('Competitors'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);

    expect(nodeLabelled('Research'), findsOneWidget);
    expect(nodeLabelled('Competitors'), findsOneWidget,
        reason: 'the whole subtree comes back, not just the node');
  });

  mapTest('Space folds a branch away and the pill says what is hidden',
      (tester) async {
    await pumpMap(tester);
    await buildBranch(tester);

    expect(nodeLabelled('Competitors'), findsOneWidget);

    await selectNode(tester, 'Research');
    await pressKey(tester, LogicalKeyboardKey.space);

    expect(nodeLabelled('Competitors'), findsNothing);
    expect(nodeLabelled('1'), findsOneWidget,
        reason: 'the pill counts what it hid');
  });

  mapTest('arrow keys walk the tree by what is on screen', (tester) async {
    final mapId = await pumpMap(tester);
    await selectNode(tester, 'Launch');
    await pressKey(tester, LogicalKeyboardKey.tab);
    await typeLabel(tester, 'Research');
    await pressKey(tester, LogicalKeyboardKey.escape);

    // Back to the root, then rightwards onto the branch beside it.
    await selectNode(tester, 'Launch');
    await pressKey(tester, LogicalKeyboardKey.arrowRight);

    // With the child now selected, Tab must hang the next node off it.
    await pressKey(tester, LogicalKeyboardKey.tab);
    await typeLabel(tester, 'Competitors');
    await pressKey(tester, LogicalKeyboardKey.escape);

    final nodes = await real(tester, () => repo.nodes(mapId));
    final research = nodes.firstWhere((n) => n.label == 'Research');
    expect(
      nodes.firstWhere((n) => n.label == 'Competitors').parentId,
      research.id,
    );
  });

  mapTest('a phone-sized window swaps the key hints for a touch bar',
      (tester) async {
    await pumpMap(tester, size: const Size(400, 780));
    await selectNode(tester, 'Launch');

    expect(find.text('Child'), findsOneWidget);
    expect(find.text('Sibling'), findsOneWidget);
    expect(find.text('child'), findsNothing,
        reason: 'the keyboard hint strip is desktop-only');
  });
}
