import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/widgets.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/theme/autumn_ornaments.dart';
import 'package:luma/theme/coffee_ornaments.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:luma/theme/theme_style.dart';

/// WCAG relative-contrast ratio between two opaque colors.
double _contrast(Color fg, Color bg) {
  final a = fg.computeLuminance();
  final b = bg.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

Future<SettingsController> _settings(WidgetTester tester, String plan) async {
  late SettingsController controller;
  await tester.runAsync(() async {
    controller = await SettingsController.load();
  });
  controller.setAdminPlan(plan);
  return controller;
}

bool _isLeafPainter(Element e) {
  final painter = (e.widget as CustomPaint).painter;
  return painter.runtimeType.toString().contains('Leaf');
}

void main() {
  group('plan gating', () {
    testWidgets('Core cannot turn on Autumn', (tester) async {
      final settings = await _settings(tester, 'core');

      expect(settings.canUseThemeStyle(LumaThemeStyle.autumn), isFalse);
      expect(settings.setThemeStyle(LumaThemeStyle.autumn), isFalse);
      expect(settings.themeStyle, LumaThemeStyle.standard);
    });

    testWidgets('Orbit and Nova both unlock it', (tester) async {
      for (final plan in ['orbit', 'nova']) {
        final settings = await _settings(tester, plan);

        expect(settings.setThemeStyle(LumaThemeStyle.autumn), isTrue,
            reason: '$plan should unlock Autumn');
        expect(settings.themeStyle, LumaThemeStyle.autumn);
      }
    });

    testWidgets('a lapsed plan pauses Autumn without forgetting it',
        (tester) async {
      final settings = await _settings(tester, 'orbit');
      settings.setThemeStyle(LumaThemeStyle.autumn);

      settings.setAdminPlan('core');
      expect(settings.themeStyle, LumaThemeStyle.standard);
      expect(settings.preferredThemeStyle, LumaThemeStyle.autumn);

      settings.setAdminPlan('nova');
      expect(settings.themeStyle, LumaThemeStyle.autumn);
    });

    test('it sits in the picker as a paid Orbit style', () {
      final option = themeStyleOption(LumaThemeStyle.autumn);
      expect(option.minPlanId, 'orbit');
      expect(kThemeStyles.map((o) => o.style), contains(LumaThemeStyle.autumn));
      expect(themeStyleFromId('autumn'), LumaThemeStyle.autumn);
    });

    testWidgets('the style survives an export/import round trip',
        (tester) async {
      final source = await _settings(tester, 'nova');
      source.setThemeStyle(LumaThemeStyle.autumn);

      final target = await _settings(tester, 'nova');
      await target.importData(source.exportData());

      expect(target.themeStyle, LumaThemeStyle.autumn);
    });
  });

  group('autumn palettes', () {
    for (final (name, p) in [
      ('harvest night', LumaPalette.autumnDark),
      ('harvest paper', LumaPalette.autumnLight),
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
        expect(_contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5));
        expect(_contrast(p.onAccent, p.accentHover), greaterThanOrEqualTo(4.5));
      });

      test('$name states stay distinguishable from their surface', () {
        expect(_contrast(p.danger, p.surface), greaterThanOrEqualTo(3.0));
        expect(_contrast(p.success, p.surface), greaterThanOrEqualTo(3.0));
        expect(p.danger, isNot(p.accent),
            reason: 'an error must not look like a call to action');
      });
    }
  });

  group('shape tokens', () {
    test('Autumn is notched, heavier and sits on a ledge', () {
      const decor = LumaDecor.autumn;
      expect(decor.notched, isTrue);
      expect(decor.borderWidth, greaterThan(LumaDecor.standard.borderWidth));
      expect(decor.blockDepth, greaterThan(0));
      expect(decor.displayLabels, isTrue);
      expect(decor.displayFontFamily, 'LumaPixel');
      expect(decor.ornament, LumaOrnament.fallingLeaves);
    });

    test('the other styles keep round corners and no ledge', () {
      for (final decor in [LumaDecor.standard, LumaDecor.coffee]) {
        expect(decor.notched, isFalse);
        expect(decor.blockDepth, 0);
        expect(decor.displayLabels, isFalse);
        expect(decor.cardShape(), isA<RoundedRectangleBorder>());
        expect(decor.blockShadow(LumaPalette.dark), isEmpty);
      }
    });

    test('notched shapes are bevels with the token as the cut', () {
      final shape = LumaDecor.autumn.buttonShape();
      expect(shape, isA<BeveledRectangleBorder>());
      expect(
        (shape as BeveledRectangleBorder).borderRadius,
        BorderRadius.circular(LumaDecor.autumn.buttonRadius),
      );
    });

    test('the ledge is a hard shadow straight down', () {
      final shadow = LumaDecor.autumn.blockShadow(LumaPalette.autumnDark).single;
      expect(shadow.blurRadius, 0);
      expect(shadow.offset, Offset(0, LumaDecor.autumn.blockDepth));
    });

    test('labels go to capitals only under displayLabels', () {
      expect(LumaDecor.autumn.labelText('Save'), 'SAVE');
      expect(LumaDecor.standard.labelText('Save'), 'Save');
      const base = TextStyle(fontSize: 14);
      expect(LumaDecor.standard.labelStyle(base), base);
      expect(LumaDecor.autumn.labelStyle(base).fontFamily, 'LumaPixel');
    });

    test('decor snaps its corner style at the crossfade midpoint', () {
      final early =
          LumaDecor.coffee.lerp(LumaDecor.autumn, 0.2);
      expect(early.corners, LumaCorners.rounded);
      final late = LumaDecor.coffee.lerp(LumaDecor.autumn, 0.8);
      expect(late.corners, LumaCorners.notched);
      expect(late.ornament, LumaOrnament.fallingLeaves);
    });
  });

  group('theme assembly', () {
    test('Autumn carries its own palette and ignores the accent seed', () {
      const teal = Color(0xFF1FB6A6);
      final theme = LumaTheme.from(Brightness.dark, teal, LumaThemeStyle.autumn);

      expect(theme.extension<LumaPalette>(), LumaPalette.autumnDark);
      expect(theme.extension<LumaDecor>(), LumaDecor.autumn);
      expect(
        LumaTheme.accentFor(Brightness.light, teal, LumaThemeStyle.autumn),
        LumaPalette.autumnLight.accent,
      );
    });

    test('Material components take the notched shapes', () {
      final theme = LumaTheme.from(Brightness.dark, null, LumaThemeStyle.autumn);

      expect(theme.cardTheme.shape, isA<BeveledRectangleBorder>());
      expect(theme.dialogTheme.shape, isA<BeveledRectangleBorder>());
      expect(
        theme.filledButtonTheme.style!.shape!.resolve({}),
        isA<BeveledRectangleBorder>(),
      );
      expect(
        theme.filledButtonTheme.style!.textStyle!.resolve({})!.fontFamily,
        'LumaPixel',
      );
    });

    test('titles take the pixel face, body copy keeps the platform font', () {
      final theme = LumaTheme.from(Brightness.dark, null, LumaThemeStyle.autumn);

      expect(theme.textTheme.titleLarge?.fontFamily, 'LumaPixel');
      expect(theme.textTheme.headlineSmall?.fontFamily, 'LumaPixel');
      expect(theme.textTheme.bodyMedium?.fontFamily, isNot('LumaPixel'));
    });

    test('Coffee is unchanged by Autumn sharing its code path', () {
      final theme = LumaTheme.from(Brightness.dark, null, LumaThemeStyle.coffee);

      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(
        (theme.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(24),
      );
      expect(theme.filledButtonTheme.style!.textStyle, isNull);
    });

    test('the pixel face is bundled and declared', () {
      for (final file in [
        'assets/fonts/LumaPixel-Regular.ttf',
        'assets/fonts/LumaPixel-Bold.ttf',
      ]) {
        final bytes = File(file).readAsBytesSync();
        // sfnt version 1.0: a TrueType outline font.
        expect(bytes.sublist(0, 4), [0, 1, 0, 0], reason: file);
      }
      expect(File('pubspec.yaml').readAsStringSync(), contains('LumaPixel'));
    });
  });

  group('widgets follow the shape tokens', () {
    Future<void> pump(WidgetTester tester, Widget child) {
      return tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.from(Brightness.dark, null, LumaThemeStyle.autumn),
          home: Scaffold(body: Center(child: child)),
        ),
      );
    }

    testWidgets('a card is a notched block on a ledge', (tester) async {
      await pump(tester, const LumaCard(child: Text('harvest')));
      final container = tester.widget<Container>(
        find.ancestor(of: find.text('harvest'), matching: find.byType(Container))
            .first,
      );
      final d = container.decoration! as ShapeDecoration;
      expect(d.shape, isA<BeveledRectangleBorder>());
      expect(d.color, LumaPalette.autumnDark.surface);
      expect(d.shadows, isNotEmpty);
    });

    testWidgets('the primary button shouts in pixels and sinks when pressed',
        (tester) async {
      var taps = 0;
      await pump(
        tester,
        LumaPrimaryButton(label: 'Rake', onTap: () => taps++),
      );
      expect(find.text('RAKE'), findsOneWidget);

      Matrix4? transform() => tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .transform;

      expect(transform(), Matrix4.identity());
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('RAKE')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(transform()!.getTranslation().y, greaterThan(0),
          reason: 'the key face sinks onto its ledge');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(transform(), Matrix4.identity());
    });

    testWidgets('the selected tab is a solid block', (tester) async {
      await pump(
        tester,
        LumaSegmentedTabs(
          tabs: const ['Leaves', 'Acorns'],
          selectedIndex: 0,
          onSelect: (_) {},
        ),
      );
      final selected = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.text('LEAVES'), matching: find.byType(AnimatedContainer)),
      );
      final d = selected.decoration! as ShapeDecoration;
      expect(d.color, LumaPalette.autumnDark.accent);
    });

    testWidgets('a pressed-then-dragged-off button springs back up',
        (tester) async {
      await pump(tester, LumaPrimaryButton(label: 'Rake', onTap: () {}));
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('RAKE')));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).transform,
        Matrix4.identity(),
      );
    });
  });

  group('backdrop', () {
    testWidgets('Autumn drops leaves behind the content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.from(Brightness.dark, null, LumaThemeStyle.autumn),
          home: const Scaffold(body: StyleBackdrop(child: Text('fall'))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('fall'), findsOneWidget);
      expect(find.byType(AutumnBackdrop), findsOneWidget);
      expect(find.byType(CustomPaint).evaluate().where(_isLeafPainter),
          isNotEmpty);

      // Switching away must not leak the falling-leaves ticker.
      await tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.from(Brightness.dark, null, LumaThemeStyle.standard),
          home: const Scaffold(body: StyleBackdrop(child: Text('fall'))),
        ),
      );
      // MaterialApp crossfades themes; the ornament flips at the midpoint.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AutumnBackdrop), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion holds the leaves still', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: LumaTheme.from(Brightness.light, null, LumaThemeStyle.autumn),
            home: const Scaffold(body: StyleBackdrop(child: Text('still'))),
          ),
        ),
      );
      // A live ticker would make pumpAndSettle time out.
      await tester.pumpAndSettle();
      expect(find.text('still'), findsOneWidget);
    });

    testWidgets('the leaf icon paints at any size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: MapleLeafIcon(color: Color(0xFFC84C22), size: 48)),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
