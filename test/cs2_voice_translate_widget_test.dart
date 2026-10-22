import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:luma/app/widgets.dart';
import 'package:luma/features/plugins/installed/game_tools/cs2_translator/cs2_chat_translator_tab.dart';
import 'package:luma/features/plugins/installed/game_tools/cs2_translator/cs2_voice_translate_service.dart';
import 'package:luma/features/plugins/installed/game_tools/cs2_translator/cs2_voice_translate_tab.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.directory);

  final Directory directory;

  @override
  Future<String> getApplicationSupportPath() async => directory.path;
}

Widget _app() => MaterialApp(
  theme: LumaTheme.dark,
  locale: const Locale('en'),
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  home: const Scaffold(body: Cs2VoiceTranslateTab()),
);

Future<void> _waitForSave(
  WidgetTester tester,
  Directory directory,
  Finder keybindButton,
  bool Function(Map<String, dynamic>) matches,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump();
    final saved = await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      try {
        final file = File('${directory.path}/cs2_voice_translate.json');
        return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } on FormatException {
        return null;
      } on FileSystemException {
        return null;
      }
    });
    await tester.pump();
    final button = tester.widget<LumaGhostButton>(
      find.ancestor(of: keybindButton, matching: find.byType(LumaGhostButton)),
    );
    if (saved != null && matches(saved) && button.onTap != null) return;
  }
  fail('Voice settings must be saved before closing the view.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = Cs2VoiceTranslateService.instance;
  late Directory directory;
  late PathProviderPlatform previousPaths;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('luma-cs2-voice-widget-');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory);
    await service.load();
  });

  setUp(() async {
    await service.setTargetLanguage('English');
  });

  tearDownAll(() async {
    PathProviderPlatform.instance = previousPaths;
    final temp = await Directory.systemTemp.resolveSymbolicLinks();
    final resolved = await directory.resolveSymbolicLinks();
    expect(
      resolved.startsWith(
        '$temp${Platform.pathSeparator}luma-cs2-voice-widget-',
      ),
      isTrue,
    );
    await directory.delete(recursive: true);
  });

  for (final size in [const Size(320, 600), const Size(1280, 900)]) {
    testWidgets(
      'voice settings remain reachable without microphone capture at ${size.width.toInt()}px',
      (tester) async {
        final physicalKey = size.width == 320
            ? PhysicalKeyboardKey.f9
            : PhysicalKeyboardKey.f10;
        final logicalKey = size.width == 320
            ? LogicalKeyboardKey.f9
            : LogicalKeyboardKey.f10;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app());
        await tester.runAsync(() async {
          await service.load();
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('CS2 Voice translate'), findsOneWidget);
        expect(find.text(Cs2ChatTranslatorTab.launchOptions), findsOneWidget);
        expect(service.enabled, isFalse);
        expect(service.recording, isFalse);

        final changeShortcut = find.text('Set keybind');
        await tester.ensureVisible(changeShortcut);
        await tester.pumpAndSettle();
        final shortcutButton = tester.widget<LumaGhostButton>(
          find.ancestor(
            of: changeShortcut,
            matching: find.byType(LumaGhostButton),
          ),
        );
        expect(
          shortcutButton.onTap,
          isNotNull,
          reason:
              'status=${service.status}; busy=${service.busy}; error=${service.error}',
        );
        await tester.tap(changeShortcut);
        await tester.pumpAndSettle();
        expect(find.byType(HotKeyRecorder), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(logicalKey);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextButton),
              )
              .last,
        );
        await tester.pumpAndSettle();
        await _waitForSave(tester, directory, changeShortcut, (saved) {
          final key = HotKey.fromJson(
            Map<String, dynamic>.from(saved['hotKey'] as Map),
          );
          return key.key == physicalKey &&
              key.modifiers!.contains(HotKeyModifier.control) &&
              key.modifiers!.contains(HotKeyModifier.alt);
        });
        expect(service.hotKey.key, physicalKey);
        expect(
          service.hotKey.modifiers,
          unorderedEquals([HotKeyModifier.control, HotKeyModifier.alt]),
        );

        final language = find.byType(DropdownButtonFormField<String>);
        await tester.ensureVisible(language);
        await tester.pumpAndSettle();
        await tester.tap(language);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nederlands').last);
        await tester.pumpAndSettle();

        await _waitForSave(
          tester,
          directory,
          changeShortcut,
          (saved) => saved['targetLanguage'] == 'Dutch',
        );
        await tester.pumpAndSettle();
        expect(service.targetLanguage, 'Dutch');
        expect(service.enabled, isFalse);
        expect(service.recording, isFalse);
        expect(service.busy, isFalse);

        await tester.ensureVisible(find.text('Translated message'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Your latest translated message will appear here.'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !Platform.isWindows,
    );
  }
}
