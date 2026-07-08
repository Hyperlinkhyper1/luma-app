import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../../storage/storage_guard.dart';
import 'data/school_database.dart';
import 'logic/citation_formatter.dart';
import 'logic/gpa_calculator.dart';
import 'logic/spaced_repetition.dart';

class SchoolRepository {
  SchoolRepository(this._db);
  final SchoolDatabase _db;

  // ── Subjects ────────────────────────────────────────────────────────────

  Stream<List<SchoolSubject>> watchSubjects({bool includeArchived = false}) {
    final query = _db.select(_db.schoolSubjects)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (!includeArchived) {
      query.where((t) => t.archived.equals(false));
    }
    return query.watch();
  }

  Future<int> createSubject(String name, {int? color, double creditHours = 3}) {
    StorageGuard.instance.ensureWithinLimit();
    final future = _db.into(_db.schoolSubjects).insert(
          SchoolSubjectsCompanion.insert(
            name: name,
            color: color == null ? const Value.absent() : Value(color),
            creditHours: Value(creditHours),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> updateSubject(int id,
      {String? name, int? color, double? creditHours, bool? archived}) {
    return (_db.update(_db.schoolSubjects)..where((t) => t.id.equals(id)))
        .write(SchoolSubjectsCompanion(
      name: name == null ? const Value.absent() : Value(name),
      color: color == null ? const Value.absent() : Value(color),
      creditHours:
          creditHours == null ? const Value.absent() : Value(creditHours),
      archived: archived == null ? const Value.absent() : Value(archived),
    ));
  }

  Future<void> deleteSubject(int id) =>
      (_db.delete(_db.schoolSubjects)..where((t) => t.id.equals(id))).go();

  // ── Assignments ─────────────────────────────────────────────────────────

  Stream<List<Assignment>> watchAssignments(
      {int? subjectId, bool includeCompleted = true}) {
    final query = _db.select(_db.assignments)
      ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]);
    if (subjectId != null) query.where((t) => t.subjectId.equals(subjectId));
    if (!includeCompleted) query.where((t) => t.completed.equals(false));
    return query.watch();
  }

  Future<int> createAssignment({
    int? subjectId,
    required String title,
    String? notes,
    required DateTime dueDate,
    int priority = 1,
  }) {
    StorageGuard.instance.ensureWithinLimit();
    final future = _db.into(_db.assignments).insert(
          AssignmentsCompanion.insert(
            subjectId: Value(subjectId),
            title: title,
            notes: Value(notes),
            dueDate: dueDate,
            priority: Value(priority),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> updateAssignment(
    int id, {
    int? subjectId,
    String? title,
    String? notes,
    DateTime? dueDate,
    int? priority,
    double? gradeEarned,
    double? gradeTotal,
  }) {
    return (_db.update(_db.assignments)..where((t) => t.id.equals(id))).write(
      AssignmentsCompanion(
        subjectId: subjectId == null ? const Value.absent() : Value(subjectId),
        title: title == null ? const Value.absent() : Value(title),
        notes: notes == null ? const Value.absent() : Value(notes),
        dueDate: dueDate == null ? const Value.absent() : Value(dueDate),
        priority: priority == null ? const Value.absent() : Value(priority),
        gradeEarned:
            gradeEarned == null ? const Value.absent() : Value(gradeEarned),
        gradeTotal:
            gradeTotal == null ? const Value.absent() : Value(gradeTotal),
      ),
    );
  }

  Future<void> toggleAssignmentComplete(int id, bool completed) {
    return (_db.update(_db.assignments)..where((t) => t.id.equals(id))).write(
      AssignmentsCompanion(
        completed: Value(completed),
        completedAt: Value(completed ? DateTime.now() : null),
      ),
    );
  }

  Future<void> deleteAssignment(int id) =>
      (_db.delete(_db.assignments)..where((t) => t.id.equals(id))).go();

  // ── Timetable ───────────────────────────────────────────────────────────

  Stream<List<TimetableEntry>> watchTimetable() {
    final query = _db.select(_db.timetableEntries)
      ..orderBy([
        (t) => OrderingTerm.asc(t.dayOfWeek),
        (t) => OrderingTerm.asc(t.startMinutes),
      ]);
    return query.watch();
  }

  Future<int> createTimetableEntry({
    required int subjectId,
    required int dayOfWeek,
    required int startMinutes,
    required int endMinutes,
    String? location,
    String? instructor,
  }) {
    StorageGuard.instance.ensureWithinLimit();
    final future = _db.into(_db.timetableEntries).insert(
          TimetableEntriesCompanion.insert(
            subjectId: subjectId,
            dayOfWeek: dayOfWeek,
            startMinutes: startMinutes,
            endMinutes: endMinutes,
            location: Value(location),
            instructor: Value(instructor),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> deleteTimetableEntry(int id) =>
      (_db.delete(_db.timetableEntries)..where((t) => t.id.equals(id))).go();

  // ── Flashcard decks & cards ─────────────────────────────────────────────

  Stream<List<FlashcardDeck>> watchDecks() {
    final query = _db.select(_db.flashcardDecks)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }

  Future<int> createDeck(String name, {int? subjectId}) {
    StorageGuard.instance.ensureWithinLimit();
    final future = _db.into(_db.flashcardDecks).insert(
          FlashcardDecksCompanion.insert(
            name: name,
            subjectId: Value(subjectId),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> deleteDeck(int id) async {
    await (_db.delete(_db.flashcards)..where((t) => t.deckId.equals(id))).go();
    await (_db.delete(_db.flashcardDecks)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Flashcard>> watchCards(int deckId) {
    final query = _db.select(_db.flashcards)
      ..where((t) => t.deckId.equals(deckId));
    return query.watch();
  }

  Stream<List<Flashcard>> watchDueCards(int deckId) {
    final query = _db.select(_db.flashcards)
      ..where((t) =>
          t.deckId.equals(deckId) & t.nextReviewDate.isSmallerOrEqualValue(DateTime.now()));
    return query.watch();
  }

  Future<int> createCard(int deckId, String front, String back) {
    StorageGuard.instance.ensureWithinLimit();
    final future = _db.into(_db.flashcards).insert(
          FlashcardsCompanion.insert(deckId: deckId, front: front, back: back),
        );
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> updateCard(int id, {String? front, String? back}) {
    return (_db.update(_db.flashcards)..where((t) => t.id.equals(id))).write(
      FlashcardsCompanion(
        front: front == null ? const Value.absent() : Value(front),
        back: back == null ? const Value.absent() : Value(back),
      ),
    );
  }

  Future<void> deleteCard(int id) =>
      (_db.delete(_db.flashcards)..where((t) => t.id.equals(id))).go();

  /// Applies an SM-2 review rating to [card] and persists the new schedule.
  Future<void> reviewCard(Flashcard card, ReviewRating rating) {
    final result = computeNextReview(
      easeFactor: card.easeFactor,
      intervalDays: card.intervalDays,
      repetitions: card.repetitions,
      rating: rating,
    );
    return (_db.update(_db.flashcards)..where((t) => t.id.equals(card.id))).write(
      FlashcardsCompanion(
        easeFactor: Value(result.easeFactor),
        intervalDays: Value(result.intervalDays),
        repetitions: Value(result.repetitions),
        nextReviewDate: Value(result.nextReviewDate),
        lastReviewedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── Formulas ────────────────────────────────────────────────────────────

  Stream<List<Formula>> watchFormulas({String? category}) {
    final query = _db.select(_db.formulas)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (category != null) query.where((t) => t.category.equals(category));
    return query.watch();
  }

  Future<int> createFormula({
    required String name,
    required String expression,
    String category = 'Custom',
    String? description,
  }) {
    StorageGuard.instance.ensureWithinLimit();
    final future = _db.into(_db.formulas).insert(
          FormulasCompanion.insert(
            name: name,
            expression: expression,
            category: Value(category),
            description: Value(description),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> updateFormula(int id,
      {String? name, String? expression, String? category, String? description}) {
    return (_db.update(_db.formulas)..where((t) => t.id.equals(id))).write(
      FormulasCompanion(
        name: name == null ? const Value.absent() : Value(name),
        expression: expression == null ? const Value.absent() : Value(expression),
        category: category == null ? const Value.absent() : Value(category),
        description: description == null ? const Value.absent() : Value(description),
      ),
    );
  }

  Future<void> deleteFormula(int id) =>
      (_db.delete(_db.formulas)..where((t) => t.id.equals(id))).go();

  // ── Grade components (per-subject weighting) ───────────────────────────

  Stream<List<GradeComponent>> watchGradeComponents(int subjectId) {
    final query = _db.select(_db.gradeComponents)
      ..where((t) => t.subjectId.equals(subjectId));
    return query.watch();
  }

  Future<int> createGradeComponent({
    required int subjectId,
    required String name,
    required double weightPercent,
    double scoreTotal = 100,
    double? scoreEarned,
  }) {
    StorageGuard.instance.ensureWithinLimit();
    final future = _db.into(_db.gradeComponents).insert(
          GradeComponentsCompanion.insert(
            subjectId: subjectId,
            name: name,
            weightPercent: weightPercent,
            scoreTotal: Value(scoreTotal),
            scoreEarned: Value(scoreEarned),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> updateGradeComponent(
    int id, {
    String? name,
    double? weightPercent,
    double? scoreTotal,
    double? scoreEarned,
  }) {
    return (_db.update(_db.gradeComponents)..where((t) => t.id.equals(id))).write(
      GradeComponentsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        weightPercent:
            weightPercent == null ? const Value.absent() : Value(weightPercent),
        scoreTotal: scoreTotal == null ? const Value.absent() : Value(scoreTotal),
        scoreEarned: scoreEarned == null ? const Value.absent() : Value(scoreEarned),
      ),
    );
  }

  Future<void> deleteGradeComponent(int id) =>
      (_db.delete(_db.gradeComponents)..where((t) => t.id.equals(id))).go();

  Future<CurrentGradeResult> currentGradeForSubject(int subjectId) async {
    final rows = await (_db.select(_db.gradeComponents)
          ..where((t) => t.subjectId.equals(subjectId)))
        .get();
    return currentGrade([
      for (final r in rows)
        GradeComponentInput(
          weightPercent: r.weightPercent,
          scoreTotal: r.scoreTotal,
          scoreEarned: r.scoreEarned,
        ),
    ]);
  }

  Future<double?> neededScoreForSubject(int subjectId, double targetPercent) async {
    final rows = await (_db.select(_db.gradeComponents)
          ..where((t) => t.subjectId.equals(subjectId)))
        .get();
    return neededAverageOnRemaining([
      for (final r in rows)
        GradeComponentInput(
          weightPercent: r.weightPercent,
          scoreTotal: r.scoreTotal,
          scoreEarned: r.scoreEarned,
        ),
    ], targetPercent);
  }

  // ── GPA records ─────────────────────────────────────────────────────────

  Stream<List<GpaRecord>> watchGpaRecords() {
    final query = _db.select(_db.gpaRecords)
      ..orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.watch();
  }

  Future<int> createGpaRecord({
    required int subjectId,
    required String termName,
    required double creditHours,
    required double gradePoints,
    DateTime? date,
  }) {
    StorageGuard.instance.ensureWithinLimit();
    final future = _db.into(_db.gpaRecords).insert(
          GpaRecordsCompanion.insert(
            subjectId: subjectId,
            termName: termName,
            creditHours: creditHours,
            gradePoints: gradePoints,
            date: date == null ? const Value.absent() : Value(date),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> deleteGpaRecord(int id) =>
      (_db.delete(_db.gpaRecords)..where((t) => t.id.equals(id))).go();

  Stream<double?> watchOverallGpa() {
    return watchGpaRecords().map((records) => computeGpa([
          for (final r in records)
            GpaWeighting(creditHours: r.creditHours, gradePoints: r.gradePoints),
        ]));
  }

  // ── Citations ───────────────────────────────────────────────────────────

  Stream<List<Citation>> watchCitations() {
    final query = _db.select(_db.citations)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }

  Future<int> createCitation(
      CitationStyle style, SourceType sourceType, CitationFields fields) {
    StorageGuard.instance.ensureWithinLimit();
    final formatted = formatCitation(style, sourceType, fields);
    final future = _db.into(_db.citations).insert(
          CitationsCompanion.insert(
            style: style.name,
            sourceType: sourceType.name,
            fieldsJson: Value(jsonEncode(fields.toJson())),
            formattedText: formatted,
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> deleteCitation(int id) =>
      (_db.delete(_db.citations)..where((t) => t.id.equals(id))).go();

  // ── Study sessions ──────────────────────────────────────────────────────

  Stream<List<StudySession>> watchStudySessions({int? subjectId}) {
    final query = _db.select(_db.studySessions)
      ..orderBy([(t) => OrderingTerm.desc(t.startTime)]);
    if (subjectId != null) query.where((t) => t.subjectId.equals(subjectId));
    return query.watch();
  }

  Future<int> startSession({int? subjectId}) {
    StorageGuard.instance.ensureWithinLimit();
    final future = _db.into(_db.studySessions).insert(
          StudySessionsCompanion.insert(
            subjectId: Value(subjectId),
            startTime: DateTime.now(),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> stopSession(int id, {String? notes}) async {
    final row = await (_db.select(_db.studySessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    final end = DateTime.now();
    final minutes = end.difference(row.startTime).inMinutes;
    await (_db.update(_db.studySessions)..where((t) => t.id.equals(id))).write(
      StudySessionsCompanion(
        endTime: Value(end),
        durationMinutes: Value(minutes < 0 ? 0 : minutes),
        notes: notes == null ? const Value.absent() : Value(notes),
      ),
    );
  }

  Future<void> deleteSession(int id) =>
      (_db.delete(_db.studySessions)..where((t) => t.id.equals(id))).go();

  /// Total studied minutes per subject (null key = no subject assigned).
  Stream<Map<int?, int>> watchStudyTotalsBySubject() {
    return watchStudySessions().map((sessions) {
      final totals = <int?, int>{};
      for (final s in sessions) {
        totals[s.subjectId] = (totals[s.subjectId] ?? 0) + s.durationMinutes;
      }
      return totals;
    });
  }

  // ── Mind maps ───────────────────────────────────────────────────────────

  Stream<List<MindMap>> watchMindMaps() {
    final query = _db.select(_db.mindMaps)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch();
  }

  Future<int> createMindMap(String title) {
    StorageGuard.instance.ensureWithinLimit();
    final future =
        _db.into(_db.mindMaps).insert(MindMapsCompanion.insert(title: title));
    StorageGuard.instance.scheduleRefresh();
    return future;
  }

  Future<void> deleteMindMap(int id) async {
    await (_db.delete(_db.mindMapNodes)..where((t) => t.mapId.equals(id))).go();
    await (_db.delete(_db.mindMaps)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<MindMapNode>> watchNodes(int mapId) {
    final query = _db.select(_db.mindMapNodes)..where((t) => t.mapId.equals(mapId));
    return query.watch();
  }

  Future<int> createNode(
    int mapId,
    String label, {
    double x = 0,
    double y = 0,
    int? color,
    int? parentId,
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    final id = await _db.into(_db.mindMapNodes).insert(
          MindMapNodesCompanion.insert(
            mapId: mapId,
            label: label,
            x: Value(x),
            y: Value(y),
            color: color == null ? const Value.absent() : Value(color),
            parentId: Value(parentId),
          ),
        );
    await _touchMindMap(mapId);
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> updateNodePosition(int id, double x, double y) async {
    await (_db.update(_db.mindMapNodes)..where((t) => t.id.equals(id)))
        .write(MindMapNodesCompanion(x: Value(x), y: Value(y)));
  }

  Future<void> updateNodeLabel(int id, String label) async {
    await (_db.update(_db.mindMapNodes)..where((t) => t.id.equals(id)))
        .write(MindMapNodesCompanion(label: Value(label)));
  }

  Future<void> deleteNode(int id) async {
    // Orphan any children rather than cascading, so the map doesn't lose data.
    await (_db.update(_db.mindMapNodes)..where((t) => t.parentId.equals(id)))
        .write(const MindMapNodesCompanion(parentId: Value(null)));
    await (_db.delete(_db.mindMapNodes)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _touchMindMap(int mapId) {
    return (_db.update(_db.mindMaps)..where((t) => t.id.equals(mapId)))
        .write(MindMapsCompanion(updatedAt: Value(DateTime.now())));
  }
}
