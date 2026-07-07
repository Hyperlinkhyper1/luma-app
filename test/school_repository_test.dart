import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/school/data/school_database.dart';
import 'package:luma/features/plugins/installed/school/logic/citation_formatter.dart';
import 'package:luma/features/plugins/installed/school/logic/gpa_calculator.dart';
import 'package:luma/features/plugins/installed/school/logic/spaced_repetition.dart';
import 'package:luma/features/plugins/installed/school/school_repository.dart';

void main() {
  late SchoolDatabase db;
  late SchoolRepository repo;

  setUp(() {
    db = SchoolDatabase(NativeDatabase.memory());
    repo = SchoolRepository(db);
  });
  tearDown(() => db.close());

  test('subjects: create, update, and watch', () async {
    final id = await repo.createSubject('Calculus II', creditHours: 4);
    final subjects = await repo.watchSubjects().first;
    expect(subjects, hasLength(1));
    expect(subjects.first.name, 'Calculus II');
    expect(subjects.first.creditHours, 4);

    await repo.updateSubject(id, name: 'Calc II (renamed)');
    final updated = await repo.watchSubjects().first;
    expect(updated.first.name, 'Calc II (renamed)');
  });

  test('assignments: create, complete, and filter', () async {
    final subjectId = await repo.createSubject('History');
    await repo.createAssignment(
      subjectId: subjectId,
      title: 'Essay',
      dueDate: DateTime(2026, 1, 10),
    );
    final all = await repo.watchAssignments().first;
    expect(all, hasLength(1));
    expect(all.first.completed, isFalse);

    await repo.toggleAssignmentComplete(all.first.id, true);
    final incomplete = await repo.watchAssignments(includeCompleted: false).first;
    expect(incomplete, isEmpty);
  });

  test('flashcards: reviewCard persists SM-2 scheduling', () async {
    final deckId = await repo.createDeck('Spanish');
    await repo.createCard(deckId, 'hola', 'hello');
    final card = (await repo.watchCards(deckId).first).first;

    await repo.reviewCard(card, ReviewRating.good);
    final reviewed = (await repo.watchCards(deckId).first).first;

    expect(reviewed.repetitions, 1);
    expect(reviewed.intervalDays, greaterThanOrEqualTo(1));
    expect(reviewed.nextReviewDate.isAfter(DateTime.now()), isTrue);
  });

  test('grade components: current grade and needed-score projection', () async {
    final subjectId = await repo.createSubject('Physics');
    await repo.createGradeComponent(
      subjectId: subjectId,
      name: 'Midterm',
      weightPercent: 40,
      scoreEarned: 80,
      scoreTotal: 100,
    );
    await repo.createGradeComponent(
      subjectId: subjectId,
      name: 'Final',
      weightPercent: 60,
      scoreTotal: 100,
    );

    final current = await repo.currentGradeForSubject(subjectId);
    expect(current.currentPercent, closeTo(80, 0.01));

    final needed = await repo.neededScoreForSubject(subjectId, 90);
    // (90 - 40*0.8) / 60 * 100 = 96.67...
    expect(needed, closeTo(96.67, 0.1));
  });

  test('GPA: computeGpa weights by credit hours', () {
    final gpa = computeGpa([
      GpaWeighting(creditHours: 3, gradePoints: 4.0),
      GpaWeighting(creditHours: 1, gradePoints: 2.0),
    ]);
    expect(gpa, closeTo(3.5, 0.001));
  });

  test('citations: createCitation stores the formatted text', () async {
    final id = await repo.createCitation(
      CitationStyle.apa,
      SourceType.website,
      const CitationFields(
        author: 'Doe, J.',
        title: 'On Testing',
        year: '2026',
        container: 'Example Site',
        url: 'https://example.com',
      ),
    );
    final citations = await repo.watchCitations().first;
    expect(citations, hasLength(1));
    expect(citations.first.id, id);
    expect(citations.first.formattedText, contains('On Testing'));
  });

  test('mind maps: nodes track parent/child links', () async {
    final mapId = await repo.createMindMap('Photosynthesis');
    final rootId = await repo.createNode(mapId, 'Root');
    await repo.createNode(mapId, 'Child', parentId: rootId);

    final nodes = await repo.watchNodes(mapId).first;
    expect(nodes, hasLength(2));
    expect(nodes.firstWhere((n) => n.label == 'Child').parentId, rootId);

    await repo.deleteNode(rootId);
    final afterDelete = await repo.watchNodes(mapId).first;
    expect(afterDelete, hasLength(1));
    expect(afterDelete.first.parentId, isNull); // orphaned, not cascade-deleted
  });

  test('study sessions: stopSession records duration', () async {
    final id = await repo.startSession();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await repo.stopSession(id);
    final sessions = await repo.watchStudySessions().first;
    expect(sessions.first.endTime, isNotNull);
  });
}
