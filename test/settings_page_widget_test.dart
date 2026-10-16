import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/ai_settings_section.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/pet/pet_repository.dart';
import 'package:luma/pet/pet_scope.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/settings/settings_page.dart';
import 'package:luma/settings/settings_scope.dart';
import 'package:luma/sync/sync_scope.dart';
import 'package:luma/sync/sync_service.dart';
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
  LumaThemeStyle style = LumaThemeStyle.standard,
  Brightness brightness = Brightness.dark,
  double textScale = 1,
  VoidCallback? onEditHome,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final settings = await _settings(tester, plan);
  settings.setThemeStyle(style);
  settings.setThemeMode(
    brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  );
  final pet = PetRepository();
  final sync = SyncService(collections: const []);
  await tester.pumpWidget(
    ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        theme: LumaTheme.from(Brightness.light, null, settings.themeStyle),
        darkTheme: LumaTheme.from(Brightness.dark, null, settings.themeStyle),
        themeMode: settings.themeMode,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: SettingsScope(
          controller: settings,
          child: SyncScope(
            service: sync,
            // Uninitialised so no hotkey registration or real pet file is used.
            child: PetScope(
              repository: pet,
              child: Scaffold(body: SettingsPage(onEditHome: onEditHome)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return settings;
}

Future<void> _selectCategory(WidgetTester tester, String category) async {
  final sidebar = find.byKey(ValueKey('settings-nav-$category'));
  if (sidebar.evaluate().isNotEmpty) {
    await tester.tap(sidebar);
  } else {
    await tester.tap(find.byKey(const ValueKey('settings-category-picker')));
    await tester.pumpAndSettle();
    final label = switch (category) {
      'appearance' => 'Look & feel',
      'general' => 'General',
      'assistant' => 'AI Assistant',
      'pet' => 'luma pet',
      'about' => 'About',
      _ => throw ArgumentError.value(category, 'category'),
    };
    await tester.tap(find.text(label).last);
  }
  await tester.pumpAndSettle();
  expect(find.byKey(ValueKey('settings-content-$category')), findsOneWidget);
}

Future<void> _tapControl(WidgetTester tester, String key) async {
  final control = find.byKey(ValueKey(key));
  final toggle = find.descendant(of: control, matching: find.byType(Switch));
  final target = toggle.evaluate().isEmpty ? control : toggle;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  group('layout', () {
    testWidgets('the page lays out on a desktop window', (tester) async {
      await _pump(tester, plan: 'nova', size: const Size(1400, 1000));
      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('the page lays out narrow enough to stack the picker', (
      tester,
    ) async {
      await _pump(tester, plan: 'nova', size: const Size(460, 900));
      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('the page lays out for a Core account', (tester) async {
      // Core renders the extra "locked" chip, which changes the card height.
      await _pump(tester, plan: 'core', size: const Size(1400, 1000));
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets('all categories lay out in ${brightness.name} mode', (
        tester,
      ) async {
        await _pump(
          tester,
          plan: 'nova',
          size: const Size(1400, 1000),
          brightness: brightness,
        );
        for (final category in [
          'appearance',
          'general',
          'assistant',
          'pet',
          'about',
        ]) {
          await _selectCategory(tester, category);
          expect(tester.takeException(), isNull, reason: category);
        }
      });
    }

    testWidgets('360px layout supports larger text and About actions', (
      tester,
    ) async {
      await _pump(
        tester,
        plan: 'nova',
        size: const Size(360, 900),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      for (final category in ['general', 'pet', 'about']) {
        await _selectCategory(tester, category);
        expect(tester.takeException(), isNull, reason: category);
      }
      expect(
        find.byKey(const ValueKey('settings-check-updates')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('settings-licenses')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-reset')), findsOneWidget);
    });
  });

  group('category navigation', () {
    testWidgets(
      'existing controls remain reachable and Assistant opens lazily',
      (tester) async {
        await _pump(tester, plan: 'nova', size: const Size(1400, 1000));
        expect(
          find.byType(AiSettingsSection, skipOffstage: false),
          findsNothing,
        );
        for (final key in [
          'theme-mode-system',
          'theme-mode-light',
          'theme-mode-dark',
          'theme-style-standard',
          'theme-style-coffee',
          'theme-style-autumn',
          'settings-home-edit',
          for (var i = 0; i < 8; i++) 'accent-$i',
        ]) {
          expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
        }

        await _selectCategory(tester, 'general');
        for (final key in [
          'settings-language',
          'settings-start-screen',
          'settings-hide-amounts',
          'settings-lock-passwords',
          'settings-american-gpa',
        ]) {
          expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
        }

        await _selectCategory(tester, 'assistant');
        expect(find.byType(AiSettingsSection), findsOneWidget);
        expect(find.text('Anthropic Claude'), findsOneWidget);
        expect(find.text('OpenAI'), findsOneWidget);
        expect(find.text('Luma AI'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Test connection'), findsOneWidget);
        expect(find.text('Track backend AI usage'), findsOneWidget);
        expect(find.text('Model usage'), findsOneWidget);
        final tracking = find.widgetWithText(
          SwitchListTile,
          'Track backend AI usage',
        );
        await tester.ensureVisible(tracking);
        await tester.tap(tracking);
        await tester.pumpAndSettle();
        expect(
          SettingsScope.of(
            tester.element(find.byType(SettingsPage)),
          ).trackBackendAiUsage,
          isTrue,
        );

        await _selectCategory(tester, 'pet');
        expect(find.text('Open the pet now'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        if (PetRepository.supportsGlobalHotKey) {
          expect(find.text('Summon from anywhere'), findsOneWidget);
          expect(find.text('Change'), findsOneWidget);
        }

        await _selectCategory(tester, 'about');
        expect(
          find.byKey(const ValueKey('settings-check-updates')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('settings-licenses')), findsOneWidget);
        expect(find.byKey(const ValueKey('settings-reset')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'General controls update preferences and open the Home editor',
      (tester) async {
        var editedHome = 0;
        final settings = await _pump(
          tester,
          plan: 'nova',
          size: const Size(1400, 1000),
          onEditHome: () => editedHome++,
        );
        await _tapControl(tester, 'settings-home-edit');
        expect(editedHome, 1);

        await _selectCategory(tester, 'general');

        final startScreen = find.byKey(const ValueKey('settings-start-screen'));
        await tester.ensureVisible(startScreen);
        await tester.tap(startScreen);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Finance').last);
        await tester.pumpAndSettle();
        expect(settings.startScreen, StartScreen.finance);

        await _tapControl(tester, 'settings-hide-amounts');
        expect(settings.hideAmounts, isTrue);
        await _tapControl(tester, 'settings-american-gpa');
        expect(settings.useAmericanGpaScale, isTrue);

        await _tapControl(tester, 'settings-language');
        await tester.tap(find.text('Nederlands').last);
        await tester.pumpAndSettle();
        expect(settings.appLanguage, AppLanguage.dutch);
        expect(
          find.byKey(const ValueKey('settings-content-general')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('category selection survives preference and theme rebuilds', (
      tester,
    ) async {
      final settings = await _pump(
        tester,
        plan: 'nova',
        size: const Size(1400, 1000),
      );
      await _selectCategory(tester, 'general');
      settings.setThemeMode(ThemeMode.light);
      settings.setThemeStyle(LumaThemeStyle.coffee);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-content-general')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-content-appearance')),
        findsNothing,
      );
      expect(
        Theme.of(tester.element(find.byType(SettingsPage))).brightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('theme style picker', () {
    testWidgets('Core sees Coffee and Autumn locked', (tester) async {
      final settings = await _pump(
        tester,
        plan: 'core',
        size: const Size(1400, 1000),
      );

      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Autumn'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
      expect(settings.themeStyle, LumaThemeStyle.standard);
    });

    testWidgets('Nova can pour it, and the page survives the switch', (
      tester,
    ) async {
      final settings = await _pump(
        tester,
        plan: 'nova',
        size: const Size(1400, 1000),
      );

      expect(find.byIcon(Icons.lock_rounded), findsNothing);

      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();

      expect(settings.themeStyle, LumaThemeStyle.coffee);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a locked Coffee offers the upgrade instead', (
      tester,
    ) async {
      final settings = await _pump(
        tester,
        plan: 'core',
        size: const Size(1400, 1000),
      );

      await tester.tap(find.text('Coffee'));
      await tester.pump();

      expect(settings.themeStyle, LumaThemeStyle.standard);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Orbit can turn on Autumn', (tester) async {
      final settings = await _pump(
        tester,
        plan: 'orbit',
        size: const Size(1400, 1000),
      );

      await tester.tap(find.text('Autumn'));
      await tester.pumpAndSettle();

      expect(settings.themeStyle, LumaThemeStyle.autumn);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the page lays out dressed in Autumn, wide and narrow', (
      tester,
    ) async {
      // Notched shapes, the pixel display face and capitalised labels all
      // change sizes; neither layout may overflow under them.
      for (final size in const [Size(1400, 1000), Size(460, 900)]) {
        await _pump(
          tester,
          plan: 'nova',
          size: size,
          style: LumaThemeStyle.autumn,
        );
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });
  });
}
