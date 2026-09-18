import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/whiteboard/data/whiteboard_database.dart';
import 'package:luma/features/plugins/installed/whiteboard/model/whiteboard_element.dart';
import 'package:luma/features/plugins/installed/whiteboard/ui/whiteboard_canvas.dart';
import 'package:luma/features/plugins/installed/whiteboard/whiteboard_repository.dart';
import 'package:luma/features/plugins/installed/whiteboard/whiteboard_scope.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';

/// Drawing is the whole product here, so the gestures people will actually
/// make — drag to draw, press a letter to switch tool, Ctrl+Z to take it
/// back, sweep the eraser — are exercised against a real database rather than
/// left to a manual pass in the running app.
///
/// Two rules keep this working: every query goes through
/// [WidgetTester.runAsync] because drift's futures never complete in the
/// fake-async zone, and frames are driven by `settle` rather than
/// `pumpAndSettle`, which would hang on `StreamData`'s spinner.
void main() {
  late WhiteboardDatabase db;
  late WhiteboardRepository repo;

  setUp(() {
    db = WhiteboardDatabase(NativeDatabase.memory());
    repo = WhiteboardRepository(db);
    // Every write arms a three-second debounce that rescans the app's storage
    // directory, and there is no path_provider here to answer it.
    StorageGuardService.instance = StorageGuardService();
  });
  tearDown(() => db.close());

  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async {
    final result = await tester.runAsync(body);
    return result as T;
  }

  /// Advances the fake clock and real time in turn. Pumping first lets the
  /// widgets' timers fire; only then does `runAsync` give the database a
  /// slice of real time.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<int> pumpBoard(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
  }) async {
    final boardId = await real(tester, () => repo.createBoard('Sprint'));
    final board = await real(tester, () => repo.watchBoard(boardId).first);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          theme: LumaTheme.dark,
          home: Scaffold(
            body: WhiteboardScope(
              repository: repo,
              child: WhiteboardCanvas(
                board: board!,
                repository: repo,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return boardId;
  }

  /// Unmounts the tree so drift's stream-close timer fires inside the test
  /// rather than tripping the binding's pending-timer assert.
  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  }

  /// Drags across the paper, well clear of the toolbar.
  Future<void> drawStroke(
    WidgetTester tester, {
    Offset from = const Offset(400, 500),
    int steps = 6,
  }) async {
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= steps; i++) {
      await gesture.moveBy(const Offset(14, 9));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
  }

  Future<void> pressKey(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  testWidgets('every tool is reachable and named for assistive tech',
      (tester) async {
    await pumpBoard(tester);

    // Icon-only controls: the tooltip is what carries the name, so its absence
    // would leave the toolbar unusable with a screen reader.
    for (final label in [
      'Select  (V)',
      'Pen  (P)',
      'Highlighter  (M)',
      'Eraser  (E)',
      'Rectangle  (R)',
      'Sticky note  (N)',
      'Text  (T)',
    ]) {
      expect(
        find.byTooltip(label),
        findsOneWidget,
        reason: '$label has no tooltip to announce it',
      );
    }
    expect(find.byTooltip('Undo  (Ctrl+Z)'), findsOneWidget);
    expect(find.byTooltip('Export as PNG'), findsOneWidget);

    await teardownTree(tester);
  });

  testWidgets('a drag with the pen becomes a saved stroke', (tester) async {
    final boardId = await pumpBoard(tester);
    expect(find.text('0 items'), findsOneWidget);

    await drawStroke(tester);

    final elements = await real(tester, () => repo.elementsOf(boardId));
    expect(elements, hasLength(1));
    expect(elements.single.kind, WhiteboardKind.pen);
    expect(elements.single.points.length, greaterThan(2));
    expect(find.text('1 item'), findsOneWidget);

    await teardownTree(tester);
  });

  testWidgets('a stray click does not leave a speck behind', (tester) async {
    final boardId = await pumpBoard(tester);

    // Tap with a shape tool: nothing was dragged out, so nothing is drawn.
    await pressKey(tester, LogicalKeyboardKey.keyR);
    final gesture = await tester.startGesture(const Offset(400, 500));
    await gesture.up();
    await settle(tester);

    expect(await real(tester, () => repo.elementsOf(boardId)), isEmpty);

    await teardownTree(tester);
  });

  testWidgets('a letter switches tool, and the next drag draws that shape',
      (tester) async {
    final boardId = await pumpBoard(tester);

    await pressKey(tester, LogicalKeyboardKey.keyR);
    await drawStroke(tester);

    final elements = await real(tester, () => repo.elementsOf(boardId));
    expect(elements, hasLength(1));
    expect(elements.single.kind, WhiteboardKind.rect);
    // A dragged shape is exactly its two corners, however many moves it took.
    expect(elements.single.points, hasLength(2));

    await teardownTree(tester);
  });

  testWidgets('Ctrl+Z takes a stroke back and Ctrl+Shift+Z returns it',
      (tester) async {
    final boardId = await pumpBoard(tester);
    await drawStroke(tester);
    expect(await real(tester, () => repo.elementsOf(boardId)), hasLength(1));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await pressKey(tester, LogicalKeyboardKey.keyZ);
    await settle(tester);
    expect(await real(tester, () => repo.elementsOf(boardId)), isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await pressKey(tester, LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(await real(tester, () => repo.elementsOf(boardId)), hasLength(1));

    await teardownTree(tester);
  });

  testWidgets('the eraser takes out a whole stroke in one sweep',
      (tester) async {
    final boardId = await pumpBoard(tester);
    await drawStroke(tester);
    expect(await real(tester, () => repo.elementsOf(boardId)), hasLength(1));

    await pressKey(tester, LogicalKeyboardKey.keyE);
    await drawStroke(tester);

    expect(await real(tester, () => repo.elementsOf(boardId)), isEmpty);

    // And erasing is undoable like everything else.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await pressKey(tester, LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(await real(tester, () => repo.elementsOf(boardId)), hasLength(1));

    await teardownTree(tester);
  });

  testWidgets('select picks up a stroke, and Delete removes it',
      (tester) async {
    final boardId = await pumpBoard(tester);
    await drawStroke(tester);

    await pressKey(tester, LogicalKeyboardKey.keyV);
    // Land on the stroke itself, not just inside its bounding box.
    await tester.tapAt(const Offset(400, 500));
    await settle(tester);

    await pressKey(tester, LogicalKeyboardKey.delete);
    await settle(tester);

    expect(await real(tester, () => repo.elementsOf(boardId)), isEmpty);

    await teardownTree(tester);
  });

  testWidgets('the toolbar wraps instead of overflowing on a phone',
      (tester) async {
    await pumpBoard(tester, size: const Size(390, 780));
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Pen  (P)'), findsOneWidget);

    await teardownTree(tester);
  });
}
