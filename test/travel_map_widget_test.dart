import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/account/travel/fullscreen_map_page.dart';
import 'package:luma/account/travel/world_map_data.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/settings/settings_scope.dart';
import 'package:luma/theme/luma_theme.dart';

/// Two square countries — enough geometry to lay the map out without paying
/// for the real outline.
const _square = '''
{"q":1,"countries":[
  {"c":"SQ","n":"Square","r":"Nowhere","p":[[10,0,20,0,20,10,10,10]]},
  {"c":"IN","n":"Inner","r":"Nowhere","p":[[14,4,16,4,16,6,14,6]]}
]}
''';

/// Loading settings touches real async I/O, so it runs outside the widget
/// tester's fake clock; there is no path_provider on the host, so the
/// controller stays in memory.
Future<SettingsController> _settings(WidgetTester tester) async {
  late SettingsController controller;
  await tester.runAsync(() async {
    controller = await SettingsController.load();
  });
  controller.setVisitedCountries(const []);
  return controller;
}

Widget _app(SettingsController settings, WorldMap map) => MaterialApp(
      theme: LumaTheme.dark,
      home: SettingsScope(
        controller: settings,
        child: FullscreenMapPage(map: map),
      ),
    );

/// The map's drawing surface: the [InteractiveViewer] is laid out at exactly
/// the size the world is painted at.
Size _mapSize(WidgetTester tester) =>
    tester.getSize(find.byType(InteractiveViewer));

void main() {
  testWidgets('the fullscreen map fills a landscape screen', (tester) async {
    tester.view.physicalSize = const Size(1784, 824);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final settings = await _settings(tester);
    await tester.pumpWidget(_app(settings, WorldMap.parse(_square)));
    await tester.pumpAndSettle();

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final size = _mapSize(tester);
    // Landscape is taller-limited: the world is drawn as tall as the screen
    // allows, and as wide as that height's aspect ratio gives.
    expect(size.height, greaterThan(screen.height * 0.9));
    expect(size.width, greaterThan(screen.width * 0.85));
    expect(size.width / size.height,
        closeTo(MillerProjection.aspectRatio, 0.01));
  });

  testWidgets('the fullscreen map fills a portrait screen', (tester) async {
    tester.view.physicalSize = const Size(824, 1784);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final settings = await _settings(tester);
    await tester.pumpWidget(_app(settings, WorldMap.parse(_square)));
    await tester.pumpAndSettle();

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final size = _mapSize(tester);
    // Portrait is width-limited, so the map spans the full width.
    expect(size.width, closeTo(screen.width, 1));
    expect(size.height, closeTo(screen.width / MillerProjection.aspectRatio, 1));
  });

  testWidgets('tapping the same country twice adds it then removes it',
      (tester) async {
    tester.view.physicalSize = const Size(1784, 824);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final settings = await _settings(tester);
    final map = WorldMap.parse(_square);
    await tester.pumpWidget(_app(settings, map));
    await tester.pumpAndSettle();

    // Centre of the big square, in screen coordinates.
    final viewer = tester.getRect(find.byType(InteractiveViewer));
    final unit = MillerProjection.project(12, 2);
    final point = Offset(
      viewer.left + unit.dx * viewer.width,
      viewer.top + unit.dy * viewer.height,
    );

    await tester.tapAt(point);
    await tester.pumpAndSettle();
    expect(settings.visitedCountries, ['SQ']);

    await tester.tapAt(point);
    await tester.pumpAndSettle();
    expect(settings.visitedCountries, isEmpty);
  });
}
