import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/sftp/sftp_file_pane.dart';
import 'package:luma/theme/luma_theme.dart';

/// Shift+click range selection in the file panes, Explorer style: the range
/// runs from the last plainly clicked row, replaces the selection, and adds
/// to it instead with Ctrl held.
void main() {
  final entries = [
    const PaneEntry(name: 'Holiday', path: '/Holiday', isDirectory: true),
    for (var i = 1; i <= 6; i++)
      PaneEntry(name: 'IMG_$i.jpg', path: '/IMG_$i.jpg', isDirectory: false),
  ];

  late Set<String> selection;
  late List<String> opened;

  Future<void> pump(WidgetTester tester, {String path = '/'}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SftpFilePane(
              side: PaneSide.remote,
              title: 'phone',
              path: path,
              crumbs: const [(label: '/', path: '/')],
              entries: entries,
              selection: selection,
              loading: false,
              error: null,
              canGoUp: false,
              onUp: () {},
              onRefresh: () {},
              onHome: () {},
              onNewFolder: () {},
              onNavigate: (_) {},
              onOpen: (entry) => opened.add(entry.name),
              onToggleSelect: (entry) => setState(() {
                if (!selection.remove(entry.path)) selection.add(entry.path);
              }),
              onSelectRange: (range, {required additive}) => setState(() {
                if (!additive) selection.clear();
                selection.addAll(range.map((e) => e.path));
              }),
              onContextMenu: (_, _) {},
              onDropped: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> click(
    WidgetTester tester,
    String name, {
    bool shift = false,
    bool control = false,
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text(name));
    await tester.pump();
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }

  setUp(() {
    selection = {};
    opened = [];
  });

  testWidgets('shift+click selects everything between the two rows',
      (tester) async {
    await pump(tester);
    await click(tester, 'IMG_2.jpg');
    await click(tester, 'IMG_5.jpg', shift: true);

    expect(selection, {'/IMG_2.jpg', '/IMG_3.jpg', '/IMG_4.jpg', '/IMG_5.jpg'});
  });

  testWidgets('works upwards, and a folder in the range is selected, not opened',
      (tester) async {
    await pump(tester);
    await click(tester, 'IMG_3.jpg');
    await click(tester, 'Holiday', shift: true);

    expect(opened, isEmpty);
    expect(selection, {'/Holiday', '/IMG_1.jpg', '/IMG_2.jpg', '/IMG_3.jpg'});
  });

  testWidgets('a second shift+click redraws the range from the same anchor',
      (tester) async {
    await pump(tester);
    await click(tester, 'IMG_3.jpg');
    await click(tester, 'IMG_6.jpg', shift: true);
    await click(tester, 'IMG_1.jpg', shift: true);

    expect(selection, {'/IMG_1.jpg', '/IMG_2.jpg', '/IMG_3.jpg'});
  });

  testWidgets('ctrl+shift+click adds the range to what was already selected',
      (tester) async {
    await pump(tester);
    await click(tester, 'IMG_1.jpg');
    await click(tester, 'IMG_4.jpg');
    await click(tester, 'IMG_6.jpg', shift: true, control: true);

    expect(selection, {'/IMG_1.jpg', '/IMG_4.jpg', '/IMG_5.jpg', '/IMG_6.jpg'});
  });

  testWidgets('plain clicks still toggle, and folders still open',
      (tester) async {
    await pump(tester);
    await click(tester, 'IMG_2.jpg');
    await click(tester, 'IMG_2.jpg');
    await click(tester, 'Holiday');

    expect(selection, isEmpty);
    expect(opened, ['Holiday']);
  });

  testWidgets('moving to another folder forgets the anchor', (tester) async {
    await pump(tester);
    await click(tester, 'IMG_2.jpg');
    await pump(tester, path: '/elsewhere');
    selection.clear();
    await click(tester, 'IMG_5.jpg', shift: true);

    // No anchor here yet, so it behaves like a plain click.
    expect(selection, {'/IMG_5.jpg'});
  });
}
