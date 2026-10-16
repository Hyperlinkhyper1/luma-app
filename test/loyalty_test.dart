import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/account/loyalty.dart';
import 'package:luma/account/loyalty_card.dart';
import 'package:luma/account/plan.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/settings/settings_scope.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:luma/theme/theme_style.dart';

/// Loading settings does real async I/O, so it runs outside the widget
/// tester's fake clock; with no path_provider on the host the controller
/// stays in memory and never touches disk.
Future<SettingsController> _settings(WidgetTester tester) async {
  late SettingsController controller;
  await tester.runAsync(() async {
    controller = await SettingsController.load();
  });
  return controller;
}

/// Puts [settings] on Nova (code-redeemed, not yet expired) with a paid
/// streak that began [daysAgo] days ago.
Future<void> _novaFor(
  WidgetTester tester,
  SettingsController settings,
  int daysAgo,
) async {
  final now = DateTime.now();
  await tester.runAsync(
    () => settings.importData({
      'selectedPlanId': 'nova',
      'planExpiresAt': now.add(const Duration(days: 20)).toIso8601String(),
      'paidSince': now.subtract(Duration(days: daysAgo)).toIso8601String(),
    }),
  );
}

Widget _host(SettingsController settings) => SettingsScope(
      controller: settings,
      child: MaterialApp(
        theme: LumaTheme.from(Brightness.dark, null, LumaThemeStyle.standard),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: LoyaltyCard()),
        ),
      ),
    );

void main() {
  final start = DateTime(2026, 1, 1);
  LoyaltyStatus at(int days) =>
      LoyaltyStatus(paidSince: start, now: start.add(Duration(days: days)));

  group('LoyaltyStatus', () {
    test('no streak means no rank and no discount', () {
      final status = LoyaltyStatus(paidSince: null, now: start);
      expect(status.active, isFalse);
      expect(status.discountUnlocked, isFalse);
      expect(status.yearProgress, 0);
    });

    test('ranks climb on their day thresholds', () {
      expect(at(0).rank.id, 'stardust');
      expect(at(89).rank.id, 'stardust');
      expect(at(90).rank.id, 'comet');
      expect(at(180).rank.id, 'star');
      expect(at(270).rank.id, 'constellation');
      expect(at(364).rank.id, 'constellation');
      expect(at(365).rank.id, 'galaxy');
      expect(at(900).rank.id, 'galaxy');
    });

    test('counts down to the next rank and the discount', () {
      final status = at(100);
      expect(status.nextRank?.id, 'star');
      expect(status.daysToNextRank, 80);
      expect(status.daysToDiscount, 265);
      expect(status.yearProgress, closeTo(100 / 365, 1e-9));
      expect(at(400).nextRank, isNull);
      expect(at(400).yearProgress, 1);
    });

    test('the discount unlocks after exactly one year', () {
      expect(at(364).discountUnlocked, isFalse);
      expect(at(365).discountUnlocked, isTrue);
      expect(at(365).daysToDiscount, 0);
    });

    test('a streak dated in the future counts as zero days', () {
      final status = LoyaltyStatus(
        paidSince: start.add(const Duration(days: 3)),
        now: start,
      );
      expect(status.daysSubscribed, 0);
    });
  });

  group('plan pricing', () {
    test('loyal paid plans are a dollar cheaper', () {
      expect(planById('orbit').priceCentsFor(loyal: false), 400);
      expect(planById('orbit').priceCentsFor(loyal: true), 300);
      expect(planById('nova').priceCentsFor(loyal: true), 700);
    });

    test('Core stays free either way', () {
      expect(planById('core').priceCentsFor(loyal: true), 0);
    });

    test('cents format as whole dollars or two decimals', () {
      expect(formatPlanCents(700), '7');
      expect(formatPlanCents(350), '3.50');
    });
  });

  group('paid streak tracking', () {
    testWidgets('Core has no streak', (tester) async {
      final settings = await _settings(tester);
      expect(settings.paidSince, isNull);
    });

    testWidgets('turning paid starts it, lapsing to Core ends it',
        (tester) async {
      final settings = await _settings(tester);
      settings.setAdminPlan('orbit');
      final since = settings.paidSince;
      expect(since, isNotNull);
      expect(DateTime.now().difference(since!).inMinutes, 0);

      settings.setAdminPlan('nova');
      expect(settings.paidSince, since,
          reason: 'moving between paid plans keeps the streak');

      settings.setAdminPlan('core');
      expect(settings.paidSince, isNull);
    });

    testWidgets('a synced snapshot never shortens the streak', (tester) async {
      final settings = await _settings(tester);
      await _novaFor(tester, settings, 400);
      final old = settings.paidSince!;

      await tester.runAsync(
        () => settings.importData({
          ...settings.exportData(),
          'paidSince': DateTime.now().toIso8601String(),
        }),
      );
      expect(settings.paidSince, old);
    });

    testWidgets('an expired code ends the streak', (tester) async {
      final settings = await _settings(tester);
      final now = DateTime.now();
      await tester.runAsync(
        () => settings.importData({
          'selectedPlanId': 'nova',
          'planExpiresAt':
              now.subtract(const Duration(days: 1)).toIso8601String(),
          'paidSince': now.subtract(const Duration(days: 40)).toIso8601String(),
        }),
      );
      expect(settings.paidSince, isNull);
      expect(loyaltyStatusOf(settings).active, isFalse);
    });
  });

  group('LoyaltyCard', () {
    testWidgets('Core shows the locked ladder and a way to the plans',
        (tester) async {
      final settings = await _settings(tester);
      await tester.pumpWidget(_host(settings));
      await tester.pumpAndSettle();

      expect(find.text('Earn a loyalty rank'), findsOneWidget);
      expect(find.text('View plans'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('12 mo'), findsOneWidget);
    });

    testWidgets('a 100-day streak shows Comet and the countdowns',
        (tester) async {
      final settings = await _settings(tester);
      await _novaFor(tester, settings, 100);
      await tester.pumpWidget(_host(settings));
      await tester.pumpAndSettle();

      expect(find.text('Comet'), findsOneWidget);
      expect(find.text('80 days to Star'), findsOneWidget);
      expect(
        find.text('265 days until your plan is \$1 cheaper'),
        findsOneWidget,
      );
      expect(find.text('\$1 off'), findsNothing);
    });

    testWidgets('a year in shows Galaxy and the discounted price',
        (tester) async {
      final settings = await _settings(tester);
      await _novaFor(tester, settings, 370);
      await tester.pumpWidget(_host(settings));
      await tester.pumpAndSettle();

      expect(find.text('Galaxy'), findsOneWidget);
      expect(find.text('\$1 off'), findsOneWidget);
      expect(
        find.text('Loyalty discount unlocked: \$1 off every month'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Nova · \$7 / month', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('fits a phone-width screen without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final settings = await _settings(tester);
      await _novaFor(tester, settings, 200);
      await tester.pumpWidget(_host(settings));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Star'), findsOneWidget);
    });
  });
}
