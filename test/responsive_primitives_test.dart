import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/widgets.dart';
import 'package:luma/app/window_title_bar.dart';
import 'package:luma/features/converter/converter_widgets.dart';
import 'package:luma/features/plugins/installed/roblox_tools/roblox_tools_page.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  void phone(WidgetTester tester, {double width = 320, double height = 600}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget child) => MaterialApp(
        theme: LumaTheme.dark,
        home: Scaffold(body: child),
      );

  testWidgets('small phone title bar keeps the page name readable',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(app(Column(
      children: [
        WindowTitleBar(
          title: 'A long plugin name on a small phone',
          showWindowControls: false,
          trailing: const SizedBox(width: 96),
        ),
      ],
    )));

    expect(tester.takeException(), isNull);
    expect(find.text('A long plugin name on a small phone'), findsOneWidget);
    expect(find.text('luma'), findsNothing);
  });

  testWidgets('empty states scroll when text and actions exceed phone height',
      (tester) async {
    phone(tester, height: 220);
    await tester.pumpWidget(app(const LumaEmptyState(
      icon: Icons.info_outline,
      title: 'A long message that must fit on a narrow phone',
      subtitle: 'Several lines of explanation stay reachable even when '
          'the available height is very short.',
      action: Text('Try again'),
    )));

    expect(tester.takeException(), isNull);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
  });

  testWidgets('converter tiles become one readable column on a phone',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(app(SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConverterToolGrid(tiles: [
        ConverterToolTile(
          icon: Icons.image,
          title: 'Picture converter',
          subtitle: 'PNG · JPG · BMP · TIFF · SVG',
          badge: 'IMAGE',
          onTap: () {},
        ),
        ConverterToolTile(
          icon: Icons.movie,
          title: 'Video converter',
          subtitle: 'MP4 · MOV · WEBM · OGV',
          badge: 'VIDEO',
          onTap: () {},
        ),
      ]),
    )));

    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(find.text('Picture converter')).dy,
        lessThan(tester.getTopLeft(find.text('Video converter')).dy));
  });

  testWidgets('all plugin sections remain reachable in a narrow tab strip',
      (tester) async {
    phone(tester);
    var selected = -1;
    await tester.pumpWidget(app(Column(
      children: [
        LumaSegmentedTabs(
          tabs: const [
            'Usage',
            'Leaderboard',
            'Open Source',
            'Library',
            'Agents',
            'Tests',
            'Assets',
          ],
          selectedIndex: 0,
          scrollable: true,
          onSelect: (index) => selected = index,
        ),
      ],
    )));

    await tester.ensureVisible(find.text('Assets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assets'));

    expect(selected, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Roblox tools gives the content the full phone width',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(app(const RobloxToolsPage()));

    expect(tester.takeException(), isNull);
    expect(find.text('Mafia'), findsWidgets);
    expect(find.byTooltip('Collapse sidebar'), findsNothing);
  });
}
