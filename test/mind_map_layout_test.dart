import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/mind_map/layout/mind_map_layout.dart';

/// The layout engine is the whole reason nobody has to drag a node into
/// place, so its guarantees — no overlap, parents centred, folded branches
/// costing nothing — are pinned down here rather than eyeballed on screen.
void main() {
  const box = Size(120, 40);

  MindMapLayoutNode node(int id, int? parent, int sort, {bool collapsed = false}) =>
      MindMapLayoutNode(
        id: id,
        parentId: parent,
        sortIndex: sort,
        size: box,
        collapsed: collapsed,
      );

  test('a lone root sits inside the padded canvas', () {
    final result = MindMapLayout.compute(nodes: [node(1, null, 0)]);

    expect(result.positions, hasLength(1));
    final rect = result.positions[1]!;
    expect(rect.left, MindMapLayout.padding);
    expect(rect.top, MindMapLayout.padding);
    expect(result.canvasSize.width, box.width + MindMapLayout.padding * 2);
  });

  test('children are placed in their own column, ordered by sortIndex', () {
    final result = MindMapLayout.compute(nodes: [
      node(1, null, 0),
      node(2, 1, 1),
      node(3, 1, 0),
    ]);

    final root = result.positions[1]!;
    final first = result.positions[3]!;
    final second = result.positions[2]!;

    expect(first.left, greaterThan(root.right));
    expect(second.left, first.left, reason: 'siblings share a column');
    expect(first.top, lessThan(second.top),
        reason: 'sortIndex 0 is placed above sortIndex 1');
  });

  test('a parent is centred on the block its children occupy', () {
    final result = MindMapLayout.compute(nodes: [
      node(1, null, 0),
      node(2, 1, 0),
      node(3, 1, 1),
      node(4, 1, 2),
    ]);

    final root = result.positions[1]!;
    final top = result.positions[2]!;
    final bottom = result.positions[4]!;

    expect(root.center.dy, closeTo((top.center.dy + bottom.center.dy) / 2, 0.01));
  });

  test('no two visible nodes overlap, even with lopsided branches', () {
    final nodes = [
      node(1, null, 0),
      node(2, 1, 0),
      node(3, 1, 1),
      for (var i = 0; i < 5; i++) node(10 + i, 2, i),
      node(20, 3, 0),
      node(21, 20, 0),
      node(22, 21, 0),
    ];

    final result = MindMapLayout.compute(nodes: nodes);
    final rects = result.positions.values.toList();

    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          rects[i].overlaps(rects[j].deflate(0.5)),
          isFalse,
          reason: 'nodes $i and $j overlap: ${rects[i]} vs ${rects[j]}',
        );
      }
    }
  });

  test('a collapsed node hides its descendants and reclaims their space', () {
    final expanded = MindMapLayout.compute(nodes: [
      node(1, null, 0),
      node(2, 1, 0),
      node(3, 2, 0),
      node(4, 2, 1),
    ]);
    final collapsed = MindMapLayout.compute(nodes: [
      node(1, null, 0),
      node(2, 1, 0, collapsed: true),
      node(3, 2, 0),
      node(4, 2, 1),
    ]);

    expect(collapsed.positions.containsKey(3), isFalse);
    expect(collapsed.positions.containsKey(4), isFalse);
    expect(collapsed.canvasSize.width, lessThan(expanded.canvasSize.width));
  });

  test('a node whose parent no longer exists is laid out as a root', () {
    final result = MindMapLayout.compute(nodes: [
      node(1, null, 0),
      node(2, 99, 0),
    ]);

    expect(result.positions, hasLength(2));
    expect(result.positions[2]!.left, result.positions[1]!.left,
        reason: 'the orphan starts a column of its own at depth 0');
  });

  test('the downward layout swaps the axes', () {
    final result = MindMapLayout.compute(
      nodes: [node(1, null, 0), node(2, 1, 0)],
      direction: MindMapDirection.down,
    );

    final root = result.positions[1]!;
    final child = result.positions[2]!;
    expect(child.top, greaterThan(root.bottom));
    expect(child.center.dx, closeTo(root.center.dx, 0.01));
  });

  test('the both-sides layout splits branches around the root', () {
    final result = MindMapLayout.compute(
      nodes: [
        node(1, null, 0),
        node(2, 1, 0),
        node(3, 1, 1),
        node(4, 1, 2),
        node(5, 1, 3),
      ],
      direction: MindMapDirection.both,
    );

    final root = result.positions[1]!;
    final children = [2, 3, 4, 5].map((id) => result.positions[id]!).toList();
    final left = children.where((r) => r.right <= root.left).length;
    final right = children.where((r) => r.left >= root.right).length;

    expect(left, greaterThan(0), reason: 'some branches grow leftwards');
    expect(right, greaterThan(0), reason: 'some branches grow rightwards');
    expect(left + right, 4, reason: 'no child overlaps the root');
  });

  test('an empty map produces an empty result rather than throwing', () {
    final result = MindMapLayout.compute(nodes: const []);
    expect(result.isEmpty, isTrue);
    expect(result.canvasSize, Size.zero);
  });
}
