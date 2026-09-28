import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/text_library/data/text_library_database.dart';
import 'package:luma/features/plugins/installed/text_library/text_library_models.dart';
import 'package:luma/features/plugins/installed/text_library/text_library_repository.dart';
import 'package:luma/storage/storage_guard.dart';

void main() {
  setUpAll(() => StorageGuardService.instance = StorageGuardService());

  group('RichDoc', () {
    test('round-trips styled spans through JSON', () {
      final doc = RichDoc([
        const RichSpan('Hello '),
        const RichSpan('bold gold', RichStyle(bold: true, color: McColor.gold)),
        const RichSpan('\nnext line', RichStyle(italic: true, strike: true)),
      ]);
      final decoded = RichDoc.decode(doc.encode());
      expect(decoded, doc);
      expect(decoded.plainText, 'Hello bold gold\nnext line');
    });

    test(
      'merges neighbouring runs that share a style and drops empty ones',
      () {
        final doc = RichDoc([
          const RichSpan('a', RichStyle(bold: true)),
          const RichSpan(''),
          const RichSpan('b', RichStyle(bold: true)),
          const RichSpan('c'),
        ]);
        expect(doc.spans, [
          const RichSpan('ab', RichStyle(bold: true)),
          const RichSpan('c'),
        ]);
      },
    );

    test('reads a body that is not JSON as plain text', () {
      expect(RichDoc.decode('just words').plainText, 'just words');
      expect(RichDoc.decode('{broken').plainText, '{broken');
      expect(RichDoc.decode(null).isBlank, isTrue);
    });

    test('ignores unknown colours instead of failing', () {
      final doc = RichDoc.decode('{"v":1,"spans":[{"t":"x","c":"rainbow"}]}');
      expect(doc.spans.single.style, RichStyle.plain);
    });

    test('styles and fromStyles are inverses', () {
      final doc = RichDoc([
        const RichSpan('ab', RichStyle(underline: true)),
        const RichSpan('cd', RichStyle(color: McColor.darkAqua)),
      ]);
      expect(RichDoc.fromStyles(doc.plainText, doc.styles), doc);
    });

    test('preview flattens whitespace and truncates', () {
      final doc = RichDoc.plain('one\n\ntwo   three');
      expect(doc.preview(), 'one two three');
      expect(RichDoc.plain('x' * 50).preview(10), '${'x' * 9}…');
    });
  });

  test('firstFreeSlot skips taken slots from the preferred one', () {
    expect(firstFreeSlot(const []), 0);
    expect(firstFreeSlot(const [0, 1, 3]), 2);
    expect(firstFreeSlot(const [5, 6], preferred: 5), 7);
    expect(firstFreeSlot(const [0], preferred: -3), 1);
  });

  group('TextLibraryRepository', () {
    late TextLibraryDatabase db;
    late TextLibraryRepository repo;

    setUp(() {
      db = TextLibraryDatabase(NativeDatabase.memory());
      repo = TextLibraryRepository(db);
    });

    tearDown(() => db.close());

    test('new subjects get distinct colours and increasing order', () async {
      final a = await repo.createSubject('History');
      final b = await repo.createSubject('  Physics  ');
      final subjects = (await repo.loadLibrary()).subjects;
      expect(subjects.map((s) => s.id), [a, b]);
      expect(subjects[1].name, 'Physics');
      expect(subjects[0].color, isNot(subjects[1].color));
    });

    test('a new text takes the requested slot or the next free one', () async {
      final subject = await repo.createSubject('Biology');
      final first = await repo.saveText(
        subjectId: subject,
        title: 'Cells',
        body: RichDoc.plain('Mitochondria'),
        slot: 4,
      );
      final second = await repo.saveText(
        subjectId: subject,
        title: 'Plants',
        body: RichDoc.plain('Photosynthesis'),
        slot: 4,
      );
      expect((await repo.getText(first))!.slot, 4);
      expect((await repo.getText(second))!.slot, 5);
    });

    test('an empty title falls back to the first line of the body', () async {
      final subject = await repo.createSubject('Notes');
      final id = await repo.saveText(
        subjectId: subject,
        title: '   ',
        body: RichDoc.plain('\n  The first real line\nsecond'),
      );
      expect((await repo.getText(id))!.title, 'The first real line');
    });

    test('moving onto an occupied slot swaps the two books', () async {
      final subject = await repo.createSubject('Art');
      final a = await repo.saveText(
        subjectId: subject,
        title: 'A',
        body: RichDoc.empty,
        slot: 0,
      );
      final b = await repo.saveText(
        subjectId: subject,
        title: 'B',
        body: RichDoc.empty,
        slot: 1,
      );
      await repo.moveText(a, subjectId: subject, slot: 1);
      expect((await repo.getText(a))!.slot, 1);
      expect((await repo.getText(b))!.slot, 0);
    });

    test('moving into another case displaces the occupant to a gap', () async {
      final left = await repo.createSubject('Left');
      final right = await repo.createSubject('Right');
      final mover = await repo.saveText(
        subjectId: left,
        title: 'Mover',
        body: RichDoc.empty,
        slot: 3,
      );
      final sitter = await repo.saveText(
        subjectId: right,
        title: 'Sitter',
        body: RichDoc.empty,
        slot: 0,
      );
      await repo.moveText(mover, subjectId: right, slot: 0);
      final moved = (await repo.getText(mover))!;
      final displaced = (await repo.getText(sitter))!;
      expect(moved.subjectId, right);
      expect(moved.slot, 0);
      expect(displaced.subjectId, right);
      expect(displaced.slot, 1);
    });

    test(
      'saving an existing text keeps its slot unless one is given',
      () async {
        final subject = await repo.createSubject('Maths');
        final id = await repo.saveText(
          subjectId: subject,
          title: 'Algebra',
          body: RichDoc.plain('x'),
          slot: 7,
        );
        await repo.saveText(
          id: id,
          subjectId: subject,
          title: 'Algebra II',
          spine: 'ALG',
          body: RichDoc.plain('y'),
          cover: DyeColor.blue,
        );
        final text = (await repo.getText(id))!;
        expect(text.slot, 7);
        expect(text.title, 'Algebra II');
        expect(text.spineLabel, 'ALG');
        expect(text.cover, DyeColor.blue);
        expect(text.body.plainText, 'y');
      },
    );

    test('deleting a subject removes its texts', () async {
      final keep = await repo.createSubject('Keep');
      final drop = await repo.createSubject('Drop');
      await repo.saveText(subjectId: keep, title: 'k', body: RichDoc.empty);
      await repo.saveText(subjectId: drop, title: 'd', body: RichDoc.empty);
      await repo.deleteSubject(drop);
      final library = await repo.loadLibrary();
      expect(library.subjects.map((s) => s.id), [keep]);
      expect(library.texts.map((t) => t.subjectId), [keep]);
    });

    test('watchLibrary emits again after a write', () async {
      final events = <LibrarySnapshot>[];
      final sub = repo.watchLibrary().listen(events.add);
      await pumpEventQueue();
      await repo.createSubject('Live');
      await pumpEventQueue();
      await sub.cancel();
      expect(events.first.subjects, isEmpty);
      expect(events.last.subjects.single.name, 'Live');
    });

    test('reorderSubjects stores the given order', () async {
      final a = await repo.createSubject('A');
      final b = await repo.createSubject('B');
      final c = await repo.createSubject('C');
      await repo.reorderSubjects([c, a, b]);
      final order = (await repo.loadLibrary()).subjects.map((s) => s.id);
      expect(order, [c, a, b]);
    });
  });
}
