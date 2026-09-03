import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/widgets.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/theme/coffee_ornaments.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:luma/theme/theme_style.dart';

/// WCAG relative-contrast ratio between two opaque colors.
/// [Color.computeLuminance] is already WCAG relative luminance.
double _contrast(Color fg, Color bg) {
  final a = fg.computeLuminance();
  final b = bg.computeLuminance();
  final hi = math.max(a, b);
  final lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

/// Loading settings does real async I/O, so it runs outside the widget
/// tester's fake clock; with no path_provider on the host the controller
/// stays in memory and never touches disk.
Future<SettingsController> _settings(WidgetTester tester, String plan) async {
  late SettingsController controller;
  await tester.runAsync(() async {
    controller = await SettingsController.load();
  });
  controller.setAdminPlan(plan);
  return controller;
}

void main() {
  group('plan gating', () {
    testWidgets('Core cannot pour Coffee', (tester) async {
      final settings = await _settings(tester, 'core');

      expect(settings.canUseThemeStyle(LumaThemeStyle.coffee), isFalse);
      expect(settings.setThemeStyle(LumaThemeStyle.coffee), isFalse);
      expect(settings.themeStyle, LumaThemeStyle.standard);
    });

    testWidgets('Orbit and Nova both unlock it', (tester) async {
      for (final plan in ['orbit', 'nova']) {
        final settings = await _settings(tester, plan);

        expect(settings.canUseThemeStyle(LumaThemeStyle.coffee), isTrue,
            reason: '$plan should unlock Coffee');
        expect(settings.setThemeStyle(LumaThemeStyle.coffee), isTrue);
        expect(settings.themeStyle, LumaThemeStyle.coffee);
      }
    });

    testWidgets('the default style is always free', (tester) async {
      final settings = await _settings(tester, 'core');
      expect(settings.canUseThemeStyle(LumaThemeStyle.standard), isTrue);
    });

    testWidgets('a lapsed plan pauses Coffee without forgetting it',
        (tester) async {
      final settings = await _settings(tester, 'nova');
      settings.setThemeStyle(LumaThemeStyle.coffee);

      settings.setAdminPlan('core');
      expect(settings.themeStyle, LumaThemeStyle.standard,
          reason: 'Core must not render a paid style');
      expect(settings.preferredThemeStyle, LumaThemeStyle.coffee,
          reason: 'the choice is paused, not erased');

      settings.setAdminPlan('orbit');
      expect(settings.themeStyle, LumaThemeStyle.coffee,
          reason: 'resubscribing brings it back on its own');
    });

    test('unlock rules are tier-based, not an exact plan match', () {
      expect(themeStyleUnlocked(LumaThemeStyle.coffee, 'core'), isFalse);
      expect(themeStyleUnlocked(LumaThemeStyle.coffee, 'orbit'), isTrue);
      expect(themeStyleUnlocked(LumaThemeStyle.coffee, 'nova'), isTrue);
      expect(themeStyleUnlocked(LumaThemeStyle.standard, 'core'), isTrue);
    });
  });

  group('persistence', () {
    test('an unknown style id falls back to the default', () {
      expect(themeStyleFromId('coffee'), LumaThemeStyle.coffee);
      expect(themeStyleFromId('standard'), LumaThemeStyle.standard);
      expect(themeStyleFromId('espresso-deluxe'), LumaThemeStyle.standard);
      expect(themeStyleFromId(null), LumaThemeStyle.standard);
      expect(themeStyleFromId(7), LumaThemeStyle.standard);
    });

    testWidgets('the style survives an export/import round trip',
        (tester) async {
      final source = await _settings(tester, 'nova');
      source.setThemeStyle(LumaThemeStyle.coffee);

      final target = await _settings(tester, 'nova');
      await target.importData(source.exportData());

      expect(target.themeStyle, LumaThemeStyle.coffee);
    });
  });

  group('coffee palettes', () {
    // The checklist bar: 4.5:1 for body text, 3:1 for the muted/secondary
    // tier and for large accent-on-background elements.
    for (final (name, p) in [
      ('espresso', LumaPalette.coffeeDark),
      ('latte', LumaPalette.coffeeLight),
    ]) {
      test('$name clears WCAG AA on its own surfaces', () {
        for (final (label, bg) in [
          ('background', p.background),
          ('surface', p.surface),
          ('rail', p.rail),
        ]) {
          expect(_contrast(p.textPrimary, bg), greaterThanOrEqualTo(4.5),
              reason: '$name textPrimary on $label');
          expect(_contrast(p.textSecondary, bg), greaterThanOrEqualTo(4.5),
              reason: '$name textSecondary on $label');
          expect(_contrast(p.textMuted, bg), greaterThanOrEqualTo(3.0),
              reason: '$name textMuted on $label');
          expect(_contrast(p.accent, bg), greaterThanOrEqualTo(3.0),
              reason: '$name accent on $label');
        }
      });

      test('$name keeps button labels legible', () {
        expect(_contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5),
            reason: '$name onAccent on accent');
        expect(_contrast(p.onAccent, p.accentHover), greaterThanOrEqualTo(4.5),
            reason: '$name onAccent on accentHover');
      });

      test('$name states stay distinguishable from their surface', () {
        expect(_contrast(p.danger, p.surface), greaterThanOrEqualTo(3.0),
            reason: '$name danger on surface');
        expect(_contrast(p.success, p.surface), greaterThanOrEqualTo(3.0),
            reason: '$name success on surface');
        expect(p.surfaceHover, isNot(p.surface));
        expect(p.border, isNot(p.surface));
      });
    }
  });

  group('theme assembly', () {
    test('Coffee carries its own palette and decor', () {
      final theme = LumaTheme.from(
          Brightness.dark, null, LumaThemeStyle.coffee);

      expect(theme.extension<LumaPalette>(), LumaPalette.coffeeDark);
      expect(theme.extension<LumaDecor>(), LumaDecor.coffee);
      expect(theme.extension<LumaDecor>()!.ornament, LumaOrnament.coffeeBeans);
    });

    test('Coffee ignores the accent seed, the default style honours it', () {
      const teal = Color(0xFF1FB6A6);

      final coffee =
          LumaTheme.from(Brightness.dark, teal, LumaThemeStyle.coffee);
      expect(coffee.extension<LumaPalette>()!.accent,
          LumaPalette.coffeeDark.accent,
          reason: 'a complete style owns its palette');

      final standard =
          LumaTheme.from(Brightness.dark, teal, LumaThemeStyle.standard);
      expect(standard.extension<LumaPalette>()!.accent,
          isNot(LumaPalette.dark.accent),
          reason: 'the default style still re-hues to the seed');
    });

    test('the default style is unchanged by the feature existing', () {
      final theme = LumaTheme.from(Brightness.dark);

      expect(theme.extension<LumaPalette>(), LumaPalette.dark);
      final decor = theme.extension<LumaDecor>()!;
      // The values the shared widgets used to hardcode.
      expect(decor.cardRadius, 16);
      expect(decor.buttonRadius, 12);
      expect(decor.pillRadius, 10);
      expect(decor.badgeRadiusFactor, 0.3);
      expect(decor.borderWidth, 1);
      expect(decor.cardShadow, isEmpty);
      expect(decor.displayFontFamily, isNull);
      expect(decor.ornament, LumaOrnament.none);
    });

    test('Coffee reshapes the surfaces and takes a serif display face', () {
      final decor = LumaDecor.coffee;

      expect(decor.cardRadius, greaterThan(LumaDecor.standard.cardRadius));
      expect(decor.borderWidth, greaterThan(LumaDecor.standard.borderWidth));
      expect(decor.cardShadow, isNotEmpty);
      // Half the 44px button height or more reads as a stadium.
      expect(decor.buttonRadius, greaterThanOrEqualTo(22));
      // 0.5 of the box is a circle.
      expect(decor.badgeRadiusFactor, 0.5);
      expect(decor.displayFontFamily, isNotNull);
      expect(decor.displayFontFallback, contains('serif'),
          reason: 'Android maps the generic family; CJK needs the fallback');
    });

    test('body copy keeps the platform font, titles take the display face',
        () {
      final theme = LumaTheme.from(
          Brightness.dark, null, LumaThemeStyle.coffee);

      expect(theme.textTheme.titleLarge?.fontFamily, 'Georgia');
      expect(theme.textTheme.headlineMedium?.fontFamily, 'Georgia');
      expect(theme.textTheme.bodyMedium?.fontFamily, isNot('Georgia'),
          reason: 'long text stays as legible as it was');
    });

    test('decor lerps its numbers and snaps its discrete fields', () {
      final mid = LumaDecor.standard.lerp(LumaDecor.coffee, 0.5) as LumaDecor;
      expect(mid.cardRadius, (16 + 24) / 2);

      final early =
          LumaDecor.standard.lerp(LumaDecor.coffee, 0.2) as LumaDecor;
      expect(early.ornament, LumaOrnament.none);

      final late =
          LumaDecor.standard.lerp(LumaDecor.coffee, 0.8) as LumaDecor;
      expect(late.ornament, LumaOrnament.coffeeBeans);
      expect(late.displayFontFamily, 'Georgia');
    });

    test('accentFor resolves without building a whole theme', () {
      expect(
        LumaTheme.accentFor(Brightness.dark, null, LumaThemeStyle.coffee),
        LumaPalette.coffeeDark.accent,
      );
      expect(
        LumaTheme.accentFor(Brightness.light, null, LumaThemeStyle.coffee),
        LumaPalette.coffeeLight.accent,
      );
      expect(
        LumaTheme.accentFor(Brightness.dark, null),
        LumaPalette.dark.accent,
      );
    });
  });

  group('widgets follow the shape tokens', () {
    Future<BoxDecoration> cardDecoration(
      WidgetTester tester,
      LumaThemeStyle style,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.from(Brightness.dark, null, style),
          home: const Scaffold(body: LumaCard(child: Text('flat white'))),
        ),
      );
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('flat white'),
          matching: find.byType(Container),
        ).first,
      );
      return container.decoration! as BoxDecoration;
    }

    testWidgets('a card is 16px round by default', (tester) async {
      final d = await cardDecoration(tester, LumaThemeStyle.standard);
      expect(d.borderRadius, BorderRadius.circular(16));
      expect(d.boxShadow, isEmpty);
    });

    testWidgets('a card rounds and lifts under Coffee', (tester) async {
      final d = await cardDecoration(tester, LumaThemeStyle.coffee);
      expect(d.borderRadius, BorderRadius.circular(24));
      expect(d.boxShadow, isNotEmpty);
      expect(d.color, LumaPalette.coffeeDark.surface);
    });

    testWidgets('a widget built without the extension still has shapes',
        (tester) async {
      // Some widget tests pump a bare ThemeData; LumaDecor must not be a
      // null-assertion crash there.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [LumaPalette.dark],
          ),
          home: const Scaffold(body: LumaCard(child: Text('bare'))),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('backdrop', () {
    testWidgets('the default style pays nothing for the ornament',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.from(Brightness.dark, null, LumaThemeStyle.standard),
          home: const Scaffold(
            body: StyleBackdrop(child: Text('plain')),
          ),
        ),
      );

      expect(find.text('plain'), findsOneWidget);
      expect(find.byType(CustomPaint).evaluate().where((e) {
        final w = e.widget as CustomPaint;
        return w.painter.runtimeType.toString().contains('Bean');
      }), isEmpty);
    });

    testWidgets('Coffee paints beans behind the content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.from(Brightness.dark, null, LumaThemeStyle.coffee),
          home: const Scaffold(
            body: StyleBackdrop(child: Text('brewed')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('brewed'), findsOneWidget);
      expect(
        find.byType(CustomPaint).evaluate().where((e) {
          final w = e.widget as CustomPaint;
          return w.painter.runtimeType.toString().contains('Bean');
        }),
        isNotEmpty,
      );

      // The drift must not leak a ticker when the theme is switched away.
      await tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.from(Brightness.dark, null, LumaThemeStyle.standard),
          home: const Scaffold(body: StyleBackdrop(child: Text('brewed'))),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion holds the beans still', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: LumaTheme.from(Brightness.dark, null, LumaThemeStyle.coffee),
            home: const Scaffold(
              body: StyleBackdrop(child: Text('still')),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('still'), findsOneWidget);
      // A live ticker would make pumpAndSettle time out.
      await tester.pumpAndSettle();
    });
  });
}
