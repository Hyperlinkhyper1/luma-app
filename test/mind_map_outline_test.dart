import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/mind_map/io/mind_map_outline.dart';

/// Pasting an outline is the fastest way into a map, so the parser has to
/// cope with however the text was indented wherever it came from.
void main() {
  group('parse', () {
    test('two-space indentation nests children', () {
      final roots = MindMapOutline.parse('''
Launch
  Research
    Competitors
  Design
''');

      expect(roots, hasLength(1));
      expect(roots.first.label, 'Launch');
      expect(roots.first.children.map((c) => c.label), ['Research', 'Design']);
      expect(roots.first.children.first.children.single.label, 'Competitors');
    });

    test('tabs are treated the same as spaces', () {
      final roots = MindMapOutline.parse('Root\n\tChild\n\t\tGrandchild');

      expect(roots.single.children.single.label, 'Child');
      expect(roots.single.children.single.children.single.label, 'Grandchild');
    });

    test('four-space indentation infers its own unit', () {
      final roots = MindMapOutline.parse('Root\n    Child\n        Grandchild');

      expect(roots.single.children.single.label, 'Child');
      expect(roots.single.children.single.children.single.label, 'Grandchild');
    });

    test('bullets and numbering are stripped from labels', () {
      final roots = MindMapOutline.parse('- Root\n  * Child\n  1. Other');

      expect(roots.single.label, 'Root');
      expect(roots.single.children.map((c) => c.label), ['Child', 'Other']);
    });

    test('markdown headings nest by hash count', () {
      final roots = MindMapOutline.parse('# Title\n## Section\n### Detail\n## Other');

      expect(roots.single.label, 'Title');
      expect(roots.single.children.map((c) => c.label), ['Section', 'Other']);
      expect(roots.single.children.first.children.single.label, 'Detail');
    });

    test('a quoted line becomes the note on the node above it', () {
      final roots = MindMapOutline.parse('Root\n  Child\n  > worth remembering');

      expect(roots.single.children.single.note, 'worth remembering');
    });

    test('a markdown link splits into label and link', () {
      final roots = MindMapOutline.parse('- [Flutter](https://flutter.dev)');

      expect(roots.single.label, 'Flutter');
      expect(roots.single.link, 'https://flutter.dev');
    });

    test('blank lines are ignored and empty input yields nothing', () {
      expect(MindMapOutline.parse('\n\n   \n'), isEmpty);
      expect(MindMapOutline.parse('A\n\n  B').single.children, hasLength(1));
    });

    test('a child indented past its parent still attaches to it', () {
      final roots = MindMapOutline.parse('Root\n      Deep\n  Shallow');

      expect(roots, hasLength(1));
      expect(roots.single.children.map((c) => c.label), ['Deep', 'Shallow']);
    });
  });

  group('render', () {
    test('markdown survives a round trip', () {
      const source = 'Launch\n  Research\n    Competitors\n  Design\n';
      final once = MindMapOutline.toMarkdown(MindMapOutline.parse(source));
      final twice = MindMapOutline.toMarkdown(MindMapOutline.parse(once));

      expect(twice, once);
      expect(once, contains('- Launch'));
      expect(once, contains('    - Competitors'));
    });

    test('notes and links survive a round trip', () {
      final roots = [
        OutlineNode(
          label: 'Flutter',
          link: 'https://flutter.dev',
          note: 'the toolkit',
          children: [OutlineNode(label: 'Widgets')],
        ),
      ];

      final reparsed = MindMapOutline.parse(MindMapOutline.toMarkdown(roots));

      expect(reparsed.single.label, 'Flutter');
      expect(reparsed.single.link, 'https://flutter.dev');
      expect(reparsed.single.note, 'the toolkit');
      expect(reparsed.single.children.single.label, 'Widgets');
    });

    test('opml nests outlines and escapes markup in labels', () {
      final opml = MindMapOutline.toOpml(
        [
          OutlineNode(
            label: 'Tools & <toys>',
            children: [OutlineNode(label: 'Hammer')],
          ),
        ],
        title: 'Shed',
      );

      expect(opml, contains('<title>Shed</title>'));
      expect(opml, contains('text="Tools &amp; &lt;toys&gt;"'));
      expect(opml, contains('<outline text="Hammer"/>'));
    });

    test('descendantCount counts the whole subtree', () {
      final roots = MindMapOutline.parse('A\n  B\n    C\n  D');
      expect(roots.single.descendantCount, 3);
    });
  });
}
