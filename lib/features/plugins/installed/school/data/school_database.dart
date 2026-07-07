import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'school_database.g.dart';

/// A class/subject the student is taking (e.g. "Calculus II").
class SchoolSubjects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get color => integer().withDefault(const Constant(0xFF7C5AD9))();
  RealColumn get creditHours => real().withDefault(const Constant(3))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// A homework item or tracked assignment, optionally tied to a subject.
class Assignments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer().nullable().references(SchoolSubjects, #id)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get priority => integer().withDefault(const Constant(1))(); // 0 low, 1 medium, 2 high
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  RealColumn get gradeEarned => real().nullable()();
  RealColumn get gradeTotal => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One recurring weekly class block on the timetable.
class TimetableEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer().references(SchoolSubjects, #id)();
  IntColumn get dayOfWeek => integer()(); // 1 = Monday ... 7 = Sunday
  IntColumn get startMinutes => integer()(); // minutes from midnight
  IntColumn get endMinutes => integer()();
  TextColumn get location => text().nullable()();
  TextColumn get instructor => text().nullable()();
}

/// A named group of flashcards (e.g. "Spanish vocab ch.3").
class FlashcardDecks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get subjectId => integer().nullable().references(SchoolSubjects, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A single front/back flashcard with SM-2 spaced-repetition scheduling state.
class Flashcards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deckId => integer().references(FlashcardDecks, #id)();
  TextColumn get front => text()();
  TextColumn get back => text()();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextReviewDate =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();
}

/// A user-maintained formula reference entry (math, physics, etc).
class Formulas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text().withDefault(const Constant('Custom'))();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get expression => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A weighted grade component for a subject (e.g. "Midterm", 30%).
class GradeComponents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer().references(SchoolSubjects, #id)();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  RealColumn get weightPercent => real()();
  RealColumn get scoreEarned => real().nullable()();
  RealColumn get scoreTotal => real().withDefault(const Constant(100))();
}

/// A finished-term grade result for a subject, feeding the GPA calculator.
class GpaRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer().references(SchoolSubjects, #id)();
  TextColumn get termName => text().withLength(min: 1, max: 80)();
  RealColumn get creditHours => real()();
  RealColumn get gradePoints => real()(); // 0.0 - 4.0 scale
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

/// A generated citation, keeping both the raw fields and the formatted text.
class Citations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get style => text()(); // apa, mla, chicago
  TextColumn get sourceType => text()(); // book, website, journal, ...
  TextColumn get fieldsJson => text().withDefault(const Constant('{}'))();
  TextColumn get formattedText => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A named mind map (a canvas of connected nodes).
class MindMaps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// A single node on a mind map's canvas, optionally linked to a parent node.
class MindMapNodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mapId => integer().references(MindMaps, #id)();
  TextColumn get label => text()();
  RealColumn get x => real().withDefault(const Constant(0))();
  RealColumn get y => real().withDefault(const Constant(0))();
  IntColumn get color => integer().withDefault(const Constant(0xFF7C5AD9))();
  IntColumn get parentId => integer().nullable()();
}

/// A logged study session, optionally tied to a subject.
class StudySessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer().nullable().references(SchoolSubjects, #id)();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
}

@DriftDatabase(tables: [
  SchoolSubjects,
  Assignments,
  TimetableEntries,
  FlashcardDecks,
  Flashcards,
  Formulas,
  GradeComponents,
  GpaRecords,
  Citations,
  MindMaps,
  MindMapNodes,
  StudySessions,
])
class SchoolDatabase extends _$SchoolDatabase {
  SchoolDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'luma_school',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ));

  @override
  int get schemaVersion => 1;
}
