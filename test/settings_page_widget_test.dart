import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/settings/settings_page.dart';
import 'package:luma/settings/settings_scope.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:luma/theme/theme_style.dart';

/// Loading settings does real async I/O, so it runs outside the widget
/// tester's fake clock; with no path_provider on the host the controller
/// stays in memory.
Future<SettingsController> _settings(WidgetTester tester, String plan) async {
  late SettingsController controller;
  await tester.runAsync(() async {
    controller = await SettingsController.load();
  });
  controller.setAdminPlan(plan);
  return controller;
}

Future<SettingsController> _pump(
  WidgetTester tester, {
  required String plan,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final settings = await _settings(tester, plan);
  await tester.pumpWidget(
    MaterialApp(
      theme: LumaTheme.dark,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: SettingsScope(
        controller: settings,
        child: const Scaffold(body: SettingsPage()),
      ),
    ),
  );
  await tester.pump();
  return settings;
}

void main() {
  // The Appearance section's style picker lays two cards side by side inside
  // the page's scroll view. A Row that stretches its children needs a bounded
  // height to do that — without one the whole page fails to lay out, taking
  // every section below it down with it.
  group('layout', () {
    testWidgets('the page lays out on a desktop window', (tester) async {
      await _pump(tester, plan: 'nova', size: const Size(1400, 1000));
      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('the page lays out narrow enough to stack the picker',
        (tester) async {
      // 460 leaves the picker ~372px to work with, so it takes its stacked
      // branch rather than going two-up. It isn't narrower because the About
      // card's version row overflows below ~418px — a pre-existing bug that
      // has nothing to do with the style picker.
      await _pump(tester, plan: 'nova', size: const Size(460, 900));
      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('the page lays out for a Core account', (tester) async {
      // Core renders the extra "locked" chip, which changes the card height.
      await _pump(tester, plan: 'core', size: const Size(1400, 1000));
      expect(tester.takeException(), isNull);
    });
  });

  group('theme style picker', () {
    testWidgets('Core sees Coffee locked', (tester) async {
      final settings =
          await _pump(tester, plan: 'core', size: const Size(1400, 1000));

      expect(find.text('Coffee'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(settings.themeStyle, LumaThemeStyle.standard);
    });

    testWidgets('Nova can pour it, and the page survives the switch',
        (tester) async {
      final settings =
          await _pump(tester, plan: 'nova', size: const Size(1400, 1000));

      expect(find.byIcon(Icons.lock_rounded), findsNothing);

      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();

      expect(settings.themeStyle, LumaThemeStyle.coffee);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a locked Coffee offers the upgrade instead',
        (tester) async {
      final settings =
          await _pump(tester, plan: 'core', size: const Size(1400, 1000));

      await tester.tap(find.text('Coffee'));
      await tester.pump();

      expect(settings.themeStyle, LumaThemeStyle.standard);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
