import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/_shared/native_webview.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_repository.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/ai_benchmark_scope.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/cruise_ship_test_page.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/hero_tile.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/test_view_prefs.dart';
import 'package:luma/features/plugins/installed/ai_usage/tests/tests_tab.dart';
import 'package:luma/theme/luma_theme.dart';

Widget _app(AiBenchmarkRepository repository) => AiBenchmarkScope(
  repository: repository,
  child: MaterialApp(
    theme: LumaTheme.dark,
    home: const Scaffold(body: TestsTab()),
  ),
);

Future<AiBenchmarkRepository> _openCruiseTests(WidgetTester tester) async {
  await tester.runAsync(
    () => TestViewPrefs.saveBannerView('cruise_ship', false),
  );
  final repository = AiBenchmarkRepository.withManifest(
    AiBenchmarkManifest.empty,
  );
  addTearDown(repository.dispose);
  await tester.pumpWidget(_app(repository));
  final tile = find.widgetWithText(LumaHeroTile, 'Cruise Ship Test');
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
  expect(find.byType(CruiseShipTestPage), findsOneWidget);
  return repository;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Opus 5.5 (Ultracode) cruise scene is bundled and offline', () async {
    final scene = await rootBundle.loadString(cruiseShipOpusAsset);
    expect(scene.toLowerCase(), startsWith('<!doctype html>'));
    expect(scene, contains('Opus 5.5 (Ultracode)'));
    // A single file: WebView2 refuses module scripts and fetches over
    // file://, so nothing may be loaded from beside it or from the web.
    expect(scene, isNot(matches(RegExp(r'<script[^>]*\ssrc='))));
    expect(scene, isNot(contains('<link rel="stylesheet"')));
    expect(scene, isNot(contains('src="http')));
    expect(scene, isNot(contains('/__shot')));
    // Talks to the luma host.
    expect(scene, contains('cruise-ready'));
    expect(scene, contains('cruise-error'));
    // The views and settings the test asked for.
    for (final label in [
      'Step onto the deck',
      'Deck map',
      'Tender',
      'Drone',
      'Real time',
      'Day length',
      'Weather',
    ]) {
      expect(scene, contains(label), reason: label);
    }
  });

  testWidgets('Opus 5.5 (Ultracode) is listed without a server', (
    tester,
  ) async {
    await _openCruiseTests(tester);
    expect(find.text('Opus 5.5 (Ultracode)'), findsOneWidget);
    expect(find.text('GPT 6 Astra (Ultra)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ultracode');
    await tester.pumpAndSettle();
    expect(find.text('Opus 5.5 (Ultracode)'), findsOneWidget);
    expect(find.text('GPT 6 Astra (Ultra)'), findsNothing);
  });

  testWidgets(
    'Opus 5.5 (Ultracode) plays embedded with Open in browser',
    (tester) async {
      await _openCruiseTests(tester);
      await tester.tap(find.text('Opus 5.5 (Ultracode)'));
      await tester.pump();
      await tester.pump();
      final view = tester.widget<NativeWebview>(find.byType(NativeWebview));
      expect(view.fileUrl, endsWith('opus_5_5_ultracode.html'));
      expect(find.text('Open in browser'), findsOneWidget);
      view.onMessage('{"type":"cruise-ready","backend":"WebGPU"}');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !Platform.isWindows,
  );
}
