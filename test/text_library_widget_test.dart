import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/text_library/data/text_library_database.dart';
import 'package:luma/features/plugins/installed/text_library/minecraft/scene_protocol.dart';
import 'package:luma/features/plugins/installed/text_library/text_library_models.dart';
import 'package:luma/features/plugins/installed/text_library/text_library_repository.dart';
import 'package:luma/features/plugins/installed/text_library/text_library_scope.dart';
import 'package:luma/features/plugins/installed/text_library/ui/classic_library_view.dart';
import 'package:luma/features/plugins/installed/text_library/ui/rich_text_controller.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/storage/storage_guard.dart';
import 'package:luma/theme/luma_theme.dart';

void main() {
  group('RichTextController', () {
    TextEditingValue at(String text, int caret) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );

    test('typing after a format toggle uses that format', () {
      final c = RichTextController();
      c.value = at('', 0);
      c.toggleBold();
      c.value = at('H', 1);
      c.value = at('Hi', 2);
      expect(c.doc.spans, [const RichSpan('Hi', RichStyle(bold: true))]);
    });

    test('new text inherits the style before the caret', () {
      final c = RichTextController(
        RichDoc([const RichSpan('ab', RichStyle(color: McColor.gold))]),
      );
      c.value = at('abc', 3);
      expect(c.doc.spans.single, const RichSpan('abc', RichStyle(color: McColor.gold)));
    });

    test('formatting a selection toggles it on, then off', () {
      final c = RichTextController(RichDoc.plain('hello world'));
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      c.toggleItalic();
      expect(c.doc.spans.first, const RichSpan('hello', RichStyle(italic: true)));
      expect(c.activeStyle.italic, isTrue);
      c.toggleItalic();
      expect(c.doc.spans.single, const RichSpan('hello world'));
    });

    test('colour and clear formatting apply to the selection only', () {
      final c = RichTextController(RichDoc.plain('one two'));
      c.selection = const TextSelection(baseOffset: 4, extentOffset: 7);
      c.setColor(McColor.darkAqua);
      c.toggleUnderline();
      expect(c.doc.spans.last, const RichSpan('two', RichStyle(underline: true, color: McColor.darkAqua)));
      c.clearFormatting();
      expect(c.doc.spans.single, const RichSpan('one two'));
    });

    test('deleting keeps every character matched to its style', () {
      final c = RichTextController(
        RichDoc([
          const RichSpan('ab'),
          const RichSpan('CD', RichStyle(bold: true)),
          const RichSpan('ef'),
        ]),
      );
      // Remove "bC".
      c.value = at('aDef', 1);
      expect(c.doc.spans, [
        const RichSpan('a'),
        const RichSpan('D', RichStyle(bold: true)),
        const RichSpan('ef'),
      ]);
    });
  });

  group('scene protocol', () {
    test('libraryMessage lists subjects with their books', () {
      final now = DateTime(2026, 9, 28);
      final message = libraryMessage(
        LibrarySnapshot(
          subjects: [
            LibrarySubject(id: 1, name: 'History', color: DyeColor.red, sortOrder: 0, createdAt: now),
          ],
          texts: [
            LibraryText(
              id: 7,
              subjectId: 1,
              title: 'Rome',
              spine: '',
              body: RichDoc.plain('SPQR'),
              cover: DyeColor.blue,
              slot: 3,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );
      final subject = (message['subjects'] as List).single as Map;
      expect(subject['name'], 'History');
      expect(subject['color'], DyeColor.red.index);
      final book = (subject['books'] as List).single as Map;
      expect(book['id'], 7);
      expect(book['slot'], 3);
      expect(book['cover'], DyeColor.blue.index);
      expect(RichDoc.decode(book['body'] as String).plainText, 'SPQR');
    });

    test('every scene string is filled in, placeholders kept for the page', () async {
      final t = await L.delegate.load(const Locale('en'));
      final strings = sceneStrings(t);
      expect(strings.values.every((v) => v.trim().isNotEmpty), isTrue);
      expect(strings['page'], contains('{0}'));
      expect(strings['page'], contains('{1}'));
    });
  });

  group('classic view', () {
    late TextLibraryDatabase db;
    late TextLibraryRepository repo;

    setUp(() {
      db = TextLibraryDatabase(NativeDatabase.memory());
      repo = TextLibraryRepository(db);
      StorageGuardService.instance = StorageGuardService();
    });
    tearDown(() => db.close());

    // Drift's futures only complete in real time, so every frame is followed
    // by a slice of it.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> pumpLibrary(WidgetTester tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: MaterialApp(
            theme: LumaTheme.dark,
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: Scaffold(
              body: TextLibraryScope(
                repository: repo,
                child: const ClassicLibraryView(),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester);
      StorageGuardService.instance.dispose();
      await tester.pump(const Duration(seconds: 4));
    }

    testWidgets('starts empty and builds a subject from the dialog', (tester) async {
      await pumpLibrary(tester);
      expect(find.text('No subjects yet'), findsOneWidget);

      await tester.tap(find.text('New subject'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Biology');
      await tester.tap(find.text('Create'));
      await settle(tester);

      expect(find.text('Biology'), findsWidgets);
      expect(find.text('No texts yet'), findsOneWidget);
      final subjects = await tester.runAsync(() => repo.loadLibrary());
      expect(subjects!.subjects.single.name, 'Biology');
      await finish(tester);
    });

    testWidgets('writing a new text saves it with its formatting', (tester) async {
      await tester.runAsync(() => repo.createSubject('Physics'));
      await pumpLibrary(tester);

      await tester.tap(find.text('New text'));
      await settle(tester);
      final body = find.byWidgetPredicate(
        (w) => w is TextField && w.controller is RichTextController,
      );
      expect(body, findsOneWidget);
      final controller = tester.widget<TextField>(body).controller! as RichTextController;
      controller.toggleBold();
      await tester.enterText(body, 'Newton');
      await tester.pump(const Duration(milliseconds: 800));
      await settle(tester);

      final library = await tester.runAsync(() => repo.loadLibrary());
      final text = library!.texts.single;
      expect(text.title, 'Newton');
      expect(text.body.spans.single, const RichSpan('Newton', RichStyle(bold: true)));
      await finish(tester);
    });
  });
}
