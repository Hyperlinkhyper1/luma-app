import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/ai_usage/assets/asset_studio.dart';
import 'package:luma/features/plugins/installed/ai_usage/assets/assets_tab.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every catalogue entry has a model file that defines its function', () async {
    final assets = await loadStudioCatalog(rootBundle);
    expect(assets, hasLength(24));
    expect({for (final a in assets) a.id}, hasLength(assets.length));
    for (final a in assets) {
      final source = await rootBundle.loadString(
        'assets/asset_studio/models/${a.functionName}.js',
      );
      expect(source, contains('function ${a.functionName}(g,w,d)'), reason: a.id);
    }
  });

  test('the downloaded studio is one self-contained file', () async {
    final html = await buildAssetStudioHtml(rootBundle, assetId: 'jewelryStore');
    expect(html, isNot(contains('<!-- @')));
    expect(html, isNot(contains('<script src=')));
    expect(html, isNot(contains('<link rel="stylesheet"')));
    expect(
      RegExp('<script type="text/plain" data-model="').allMatches(html),
      hasLength(24),
    );

    final config = RegExp(r'window\.STUDIO = (.*);</script>').firstMatch(html)!;
    final json = jsonDecode(config.group(1)!.replaceAll(r'<\/', '</')) as Map;
    expect(json['asset'], 'jewelryStore');
    expect(json['embed'], isFalse);
  });

  test('the in-app copy is flagged as embedded and carries luma\'s theme', () async {
    final html = await buildAssetStudioHtml(
      rootBundle,
      assetId: 'ticketMachine',
      embed: true,
      theme: 'dark',
    );
    expect(
      html,
      contains('"asset":"ticketMachine","embed":true,"theme":"dark"'),
    );
    // A downloaded copy has no app around it, so it follows the browser.
    final saved = await buildAssetStudioHtml(rootBundle, assetId: 'ticketMachine');
    expect(saved, contains('"theme":"auto"'));
  });

  test('every model has a baked thumbnail', () async {
    for (final a in await loadStudioCatalog(rootBundle)) {
      final bytes = await rootBundle.load(a.thumbnail);
      expect(bytes.lengthInBytes, greaterThan(1000), reason: a.id);
    }
  });

  testWidgets('the gallery lays out every model, in both themes and widths', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Reading the catalogue needs real async time, and the loading spinner
    // never settles, so frames are pumped with real time in between until
    // what is being waited for shows up.
    Future<void> pumpUntil(Finder finder) async {
      for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(finder, findsOneWidget);
    }

    for (final theme in [LumaTheme.light, LumaTheme.dark]) {
      // Desktop grid, then a phone-width one column.
      for (final size in [const Size(1400, 1000), const Size(420, 900)]) {
        tester.view.physicalSize = size;
        // A fresh key, or the tab keeps the state from the pass before and
        // reopens on the studio instead of the gallery.
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(body: AssetsTab(key: UniqueKey())),
          ),
        );
        await pumpUntil(find.text('Jewelry Store'));
        expect(find.text('All  24'), findsOneWidget);

        // Scroll to the end and back, so every card in the grid is laid out
        // at this width — an overflowing one throws while it is built.
        final grid = find.byType(CustomScrollView);
        for (var i = 0; i < 12; i++) {
          await tester.drag(grid, const Offset(0, -450));
          await tester.pump();
        }
        expect(find.text('Ticket machine'), findsOneWidget);
        for (var i = 0; i < 14; i++) {
          await tester.drag(grid, const Offset(0, 450));
          await tester.pump();
        }

        // Opening one swaps the gallery for the studio, under its own header.
        await tester.tap(find.text('Jewelry Store'));
        await pumpUntil(find.textContaining('HTML'));
        // Cards must not overflow at either width: an overflow throws here.
        expect(tester.takeException(), isNull);
      }
    }
  });

  test('footprints print without a trailing .0', () {
    const a = StudioAsset(
      id: 'x', name: 'X', functionName: 'x', description: '', collectionCode: '',
      category: 'interior', keywords: '', width: 8, depth: 6.5, price: 1,
    );
    expect(a.footprint, '8 × 6.5 m');
  });
}
