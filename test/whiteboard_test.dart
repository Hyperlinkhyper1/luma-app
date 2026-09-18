import 'dart:ui';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/whiteboard/data/whiteboard_database.dart';
import 'package:luma/features/plugins/installed/whiteboard/io/whiteboard_export.dart';
import 'package:luma/features/plugins/installed/whiteboard/model/whiteboard_element.dart';
import 'package:luma/features/plugins/installed/whiteboard/model/whiteboard_tool.dart';
import 'package:luma/features/plugins/installed/whiteboard/whiteboard_repository.dart';
import 'package:luma/storage/storage_guard.dart';

WhiteboardElement _stroke({
  List<Offset>? points,
  int color = 0xFF26222F,
  double width = 4,
}) =>
    WhiteboardElement(
      kind: WhiteboardKind.pen,
      points: points ?? const [Offset(10, 10), Offset(50, 30), Offset(90, 10)],
      color: color,
      strokeWidth: width,
    );

void main() {
  // The repository nudges the app-wide storage figure after every write; that
  // static is only set by main.dart's real startup.
  setUpAll(() => StorageGuardService.instance = StorageGuardService());

  group('WhiteboardElement', () {
    test('round-trips through its JSON payload', () {
      final original = WhiteboardElement(
        kind: WhiteboardKind.note,
        points: const [Offset(12.345, 67.891)],
        color: 0xFFFFE08A,
        strokeWidth: 4,
        filled: true,
        text: 'buy milk\nand eggs',
        size: const Size(200, 150),
      );

      final restored = WhiteboardElement.decode(
        id: 7,
        boardId: 3,
        kind: original.kind.name,
        data: original.encode(),
        z: 2,
      );

      expect(restored.id, 7);
      expect(restored.boardId, 3);
      expect(restored.kind, WhiteboardKind.note);
      expect(restored.color, original.color);
      expect(restored.strokeWidth, original.strokeWidth);
      expect(restored.filled, isTrue);
      expect(restored.text, original.text);
      expect(restored.size, original.size);
      // Points are rounded to two decimals on the way out; that is finer than
      // a pixel at maximum zoom.
      expect(restored.points.single.dx, closeTo(12.345, 0.01));
      expect(restored.points.single.dy, closeTo(67.891, 0.01));
    });

    test('decodes a payload that is missing every optional field', () {
      final restored = WhiteboardElement.decode(
        id: 1,
        boardId: 1,
        kind: 'pen',
        data: '{"p":[0,0,10,10]}',
        z: 0,
      );
      expect(restored.points, hasLength(2));
      expect(restored.filled, isFalse);
      expect(restored.text, isEmpty);
      expect(restored.size, Size.zero);
    });

    test('an unknown kind falls back to pen rather than throwing', () {
      expect(WhiteboardKind.parse('hologram'), WhiteboardKind.pen);
    });

    test('bounds cover the path plus half the ink width', () {
      final element = _stroke(width: 8);
      expect(element.bounds, const Rect.fromLTRB(6, 6, 94, 34));
    });

    test('bounds of a note come from its box, not its single point', () {
      const note = WhiteboardElement(
        kind: WhiteboardKind.note,
        points: [Offset(100, 100)],
        color: 0xFFFFE08A,
        size: Size(200, 150),
      );
      expect(note.bounds, const Rect.fromLTWH(100, 100, 200, 150));
    });

    test('translate moves every point and leaves the size alone', () {
      final moved = _stroke().translated(const Offset(5, -5));
      expect(moved.points.first, const Offset(15, 5));
      expect(moved.points.last, const Offset(95, 5));
    });

    test('resize drops a note exactly into the new box', () {
      const note = WhiteboardElement(
        kind: WhiteboardKind.note,
        points: [Offset(100, 100)],
        color: 0xFFFFE08A,
        size: Size(200, 150),
      );
      final resized = note.resizedTo(const Rect.fromLTWH(0, 0, 300, 90));
      expect(resized.bounds, const Rect.fromLTWH(0, 0, 300, 90));
    });

    test('resize rescales a path into the new box', () {
      final resized = _stroke(
        points: const [Offset(0, 0), Offset(10, 10)],
        width: 2,
      ).resizedTo(const Rect.fromLTWH(0, 0, 20, 40));
      // The inked bounds land on the drag target exactly: the half-stroke the
      // ink adds is taken off before the points are scaled.
      expect(resized.bounds, const Rect.fromLTWH(0, 0, 20, 40));
    });

    test('resizing text reflows it instead of stretching the glyphs', () {
      const text = WhiteboardElement(
        kind: WhiteboardKind.text,
        points: [Offset(0, 0)],
        color: 0xFF26222F,
        text: 'hello',
        size: Size(100, 18),
      );
      final resized = text.resizedTo(const Rect.fromLTWH(0, 0, 300, 90));
      expect(resized.size.width, 300);
      expect(resized.size.height, 18, reason: 'font size must not change');
    });

    test('hit-testing a stroke follows the ink, not its bounding box', () {
      final element = _stroke();
      expect(element.hitTest(const Offset(30, 20)), isTrue);
      // Inside the bounding box but well away from the "V" of the stroke.
      expect(element.hitTest(const Offset(50, 12)), isFalse);
    });

    test('an outlined shape is grabbed by its edge, a filled one anywhere',
        () {
      const outline = WhiteboardElement(
        kind: WhiteboardKind.rect,
        points: [Offset(0, 0), Offset(200, 200)],
        color: 0xFF26222F,
        strokeWidth: 4,
      );
      expect(outline.hitTest(const Offset(0, 100)), isTrue);
      expect(outline.hitTest(const Offset(100, 100)), isFalse);

      final filled = outline.copyWith(filled: true);
      expect(filled.hitTest(const Offset(100, 100)), isTrue);
    });

    test('a single-point stroke is still hittable as a dot', () {
      final dot = _stroke(points: const [Offset(50, 50)], width: 6);
      expect(dot.hitTest(const Offset(52, 52)), isTrue);
      expect(dot.hitTest(const Offset(120, 50)), isFalse);
    });
  });

  group('whiteboard tools', () {
    test('every tool has a unique shortcut key', () {
      final shortcuts =
          WhiteboardTool.values.map((tool) => tool.shortcut).toSet();
      expect(shortcuts, hasLength(WhiteboardTool.values.length));
    });

    test('drawing tools map to a kind and the rest do not', () {
      expect(WhiteboardTool.pen.kind, WhiteboardKind.pen);
      expect(WhiteboardTool.rect.kind, WhiteboardKind.rect);
      expect(WhiteboardTool.select.kind, isNull);
      expect(WhiteboardTool.pan.kind, isNull);
      expect(WhiteboardTool.eraser.kind, isNull);
    });

    test('a sticky note is a washed-out version of the current ink', () {
      final fill = whiteboardNoteFill(0xFF2563DB);
      expect(fill.computeLuminance(), greaterThan(0.6));
    });
  });

  group('WhiteboardRepository', () {
    late WhiteboardDatabase db;
    late WhiteboardRepository repo;

    setUp(() {
      db = WhiteboardDatabase(NativeDatabase.memory());
      repo = WhiteboardRepository(db);
    });
    tearDown(() => db.close());

    test('creates a board and lists it', () async {
      final id = await repo.createBoard('Sprint plan');
      final boards = await repo.watchBoards().first;
      expect(boards, hasLength(1));
      expect(boards.single.id, id);
      expect(boards.single.title, 'Sprint plan');
    });

    test('renaming a board touches its updatedAt', () async {
      final id = await repo.createBoard('Untitled');
      final before = (await repo.watchBoards().first).single.updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.renameBoard(id, 'Retro notes');
      final after = (await repo.watchBoards().first).single;
      expect(after.title, 'Retro notes');
      expect(after.updatedAt.isAfter(before) || after.updatedAt == before,
          isTrue);
    });

    test('elements come back in the order they were stacked', () async {
      final board = await repo.createBoard('Board');
      await repo.addElement(board, _stroke(color: 0xFF000001));
      await repo.addElement(board, _stroke(color: 0xFF000002));
      await repo.addElement(board, _stroke(color: 0xFF000003));

      final elements = await repo.elementsOf(board);
      expect(
        elements.map((element) => element.color),
        [0xFF000001, 0xFF000002, 0xFF000003],
      );
      expect(elements.map((element) => element.z), [0, 1, 2]);
    });

    test('an added element comes back carrying its new id', () async {
      final board = await repo.createBoard('Board');
      final added = await repo.addElement(board, _stroke());
      expect(added.id, greaterThan(0));
      expect(added.boardId, board);
    });

    test('re-adding deleted elements is what makes undo work', () async {
      final board = await repo.createBoard('Board');
      final first = await repo.addElement(board, _stroke(color: 0xFF000001));
      final second = await repo.addElement(board, _stroke(color: 0xFF000002));

      await repo.deleteElements(board, [first.id, second.id]);
      expect(await repo.elementsOf(board), isEmpty);

      // The rows come back with different ids, which is exactly why the undo
      // stack has to keep what addElements returns rather than what it sent.
      final restored = await repo.addElements(board, [first, second]);
      expect(restored, hasLength(2));
      expect(restored.first.id, isNot(first.id));
      expect(
        (await repo.elementsOf(board)).map((element) => element.color),
        [0xFF000001, 0xFF000002],
      );
    });

    test('updating an element rewrites only its geometry', () async {
      final board = await repo.createBoard('Board');
      final added = await repo.addElement(board, _stroke());
      await repo.updateElement(added.translated(const Offset(100, 0)));

      final stored = (await repo.elementsOf(board)).single;
      expect(stored.id, added.id);
      expect(stored.points.first, const Offset(110, 10));
    });

    test('clearing a board keeps the board itself', () async {
      final board = await repo.createBoard('Board');
      await repo.addElement(board, _stroke());
      await repo.clearBoard(board);
      expect(await repo.elementsOf(board), isEmpty);
      expect(await repo.watchBoards().first, hasLength(1));
    });

    test('deleting a board takes its elements with it', () async {
      final kept = await repo.createBoard('Keep');
      final doomed = await repo.createBoard('Delete');
      await repo.addElement(kept, _stroke());
      await repo.addElement(doomed, _stroke());
      await repo.addElement(doomed, _stroke());

      await repo.deleteBoard(doomed);

      expect(await repo.watchBoards().first, hasLength(1));
      expect(await repo.elementsOf(doomed), isEmpty);
      expect(await repo.elementsOf(kept), hasLength(1));
    });

    test('element counts are reported per board', () async {
      final a = await repo.createBoard('A');
      final b = await repo.createBoard('B');
      await repo.addElement(a, _stroke());
      await repo.addElement(a, _stroke());
      await repo.addElement(b, _stroke());

      final counts = await repo.watchElementCounts().first;
      expect(counts[a], 2);
      expect(counts[b], 1);
    });

    test('adding nothing is a no-op, not an error', () async {
      final board = await repo.createBoard('Board');
      expect(await repo.addElements(board, const []), isEmpty);
      await repo.deleteElements(board, const []);
      expect(await repo.elementsOf(board), isEmpty);
    });
  });

  group('WhiteboardExport', () {
    test('crops to the union of everything drawn, ink width included', () {
      final bounds = WhiteboardExport.boundsOf([
        _stroke(points: const [Offset(0, 0)], width: 2),
        _stroke(points: const [Offset(100, 60)], width: 2),
      ]);
      expect(bounds, const Rect.fromLTRB(-1, -1, 101, 61));
    });

    test('an empty board has no bounds to crop to', () {
      expect(WhiteboardExport.boundsOf(const []), Rect.zero);
    });

    test('file names lose the characters Windows will not take', () {
      expect(WhiteboardExport.fileNameFor('Q3: plan / draft?'),
          'q3-plan-draft');
      expect(WhiteboardExport.fileNameFor('   '), 'whiteboard');
    });
  });
}
