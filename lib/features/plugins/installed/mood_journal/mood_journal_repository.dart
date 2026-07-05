import 'dart:convert';

import 'package:drift/drift.dart';

import 'data/mood_journal_database.dart';

class MoodEntryRecord {
  const MoodEntryRecord({
    required this.id,
    required this.date,
    required this.mood,
    this.note,
    this.tags = const [],
    required this.createdAt,
  });

  final int id;
  final String date; // YYYY-MM-DD
  final int mood; // 1–5
  final String? note;
  final List<String> tags;
  final DateTime createdAt;

  MoodEntryRecord copyWith({
    int? mood,
    String? note,
    List<String>? tags,
  }) =>
      MoodEntryRecord(
        id: id,
        date: date,
        mood: mood ?? this.mood,
        note: note ?? this.note,
        tags: tags ?? this.tags,
        createdAt: createdAt,
      );
}

class MoodJournalRepository {
  MoodJournalRepository(this._db);

  final MoodJournalDatabase _db;

  Stream<List<MoodEntryRecord>> watchAll() {
    final query = _db.select(_db.moodEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.watch().map(
          (rows) => rows.map(_toRecord).toList(growable: false),
        );
  }

  Stream<Map<String, MoodEntryRecord>> watchByMonth(int year, int month) {
    final prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final query = _db.select(_db.moodEntries)
      ..where((t) => t.date.like('$prefix%'));
    return query.watch().map((rows) {
      return {for (final r in rows.map(_toRecord)) r.date: r};
    });
  }

  Future<MoodEntryRecord?> getByDate(String date) async {
    final query = _db.select(_db.moodEntries)
      ..where((t) => t.date.equals(date))
      ..limit(1);
    final rows = await query.get();
    return rows.isEmpty ? null : _toRecord(rows.first);
  }

  Future<void> upsert({
    required String date,
    required int mood,
    String? note,
    List<String> tags = const [],
  }) async {
    final existing = await getByDate(date);
    if (existing != null) {
      await (_db.update(_db.moodEntries)
            ..where((t) => t.id.equals(existing.id)))
          .write(MoodEntriesCompanion(
        mood: Value(mood),
        note: Value(note),
        tags: Value(tags.isEmpty ? null : jsonEncode(tags)),
      ));
    } else {
      await _db.into(_db.moodEntries).insert(MoodEntriesCompanion.insert(
            date: date,
            mood: mood,
            note: Value(note),
            tags: Value(tags.isEmpty ? null : jsonEncode(tags)),
          ));
    }
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.moodEntries)..where((t) => t.id.equals(id))).go();
  }

  MoodEntryRecord _toRecord(MoodEntry row) {
    List<String> tags = [];
    if (row.tags != null) {
      try {
        final decoded = jsonDecode(row.tags!) as List<dynamic>;
        tags = decoded.cast<String>();
      } catch (_) {}
    }
    return MoodEntryRecord(
      id: row.id,
      date: row.date,
      mood: row.mood,
      note: row.note,
      tags: tags,
      createdAt: row.createdAt,
    );
  }
}
