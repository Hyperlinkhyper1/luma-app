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
    this.images = const [],
    required this.createdAt,
  });

  final int id;
  final String date; // YYYY-MM-DD
  final int mood; // 1–5
  final String? note;
  final List<String> tags;
  final List<String> images;
  final DateTime createdAt;

  MoodEntryRecord copyWith({
    int? mood,
    String? note,
    List<String>? tags,
    List<String>? images,
  }) =>
      MoodEntryRecord(
        id: id,
        date: date,
        mood: mood ?? this.mood,
        note: note ?? this.note,
        tags: tags ?? this.tags,
        images: images ?? this.images,
        createdAt: createdAt,
      );
}

class MoodJournalRepository {
  MoodJournalRepository(this._db);

  final MoodJournalDatabase _db;

  Stream<List<MoodEntryRecord>> watchAll() {
    final query = _db.select(_db.moodEntries)
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    return query.watch().map(
          (rows) => rows.map(_toRecord).toList(growable: false),
        );
  }

  Stream<Map<String, List<MoodEntryRecord>>> watchByMonth(int year, int month) {
    final prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final query = _db.select(_db.moodEntries)
      ..where((t) => t.date.like('$prefix%'))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    
    return query.watch().map((rows) {
      final map = <String, List<MoodEntryRecord>>{};
      for (final r in rows.map(_toRecord)) {
        map.putIfAbsent(r.date, () => []).add(r);
      }
      return map;
    });
  }

  Future<List<MoodEntryRecord>> getByDate(String date) async {
    final query = _db.select(_db.moodEntries)
      ..where((t) => t.date.equals(date))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_toRecord).toList();
  }

  Future<void> save({
    int? id,
    required String date,
    required int mood,
    String? note,
    List<String> tags = const [],
    List<String> images = const [],
  }) async {
    final companion = MoodEntriesCompanion(
      date: Value(date),
      mood: Value(mood),
      note: Value(note),
      tags: Value(tags.isEmpty ? null : jsonEncode(tags)),
      images: Value(images.isEmpty ? null : jsonEncode(images)),
    );

    if (id != null) {
      await (_db.update(_db.moodEntries)..where((t) => t.id.equals(id)))
          .write(companion);
    } else {
      await _db.into(_db.moodEntries).insert(companion);
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
    List<String> images = [];
    if (row.images != null) {
      try {
        final decoded = jsonDecode(row.images!) as List<dynamic>;
        images = decoded.cast<String>();
      } catch (_) {}
    }
    return MoodEntryRecord(
      id: row.id,
      date: row.date,
      mood: row.mood,
      note: row.note,
      tags: tags,
      images: images,
      createdAt: row.createdAt,
    );
  }
}
