import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/mood_journal/data/mood_journal_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test(
      'a version-1 database (no images column) upgrades cleanly instead of '
      'throwing "no such column: images"', () async {
    // Built by hand exactly as schemaVersion 1 left it, before `images`
    // existed — this is the file a real device is stuck on, not something
    // drift itself created, so opening it goes through onUpgrade rather
    // than onCreate.
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE mood_entries (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        mood INTEGER NOT NULL,
        note TEXT NULL,
        tags TEXT NULL,
        created_at INTEGER NOT NULL
      );
    ''');
    raw.execute('PRAGMA user_version = 1');

    final db = MoodJournalDatabase(NativeDatabase.opened(raw));

    // Forces the migration to actually run and validates the resulting
    // schema against every declared column, `images` included -- this
    // throws "no such column: images" without the migration fix.
    final entries = await db.select(db.moodEntries).get();
    expect(entries, isEmpty);

    await db.into(db.moodEntries).insert(MoodEntriesCompanion.insert(
          date: '2026-01-01',
          mood: 4,
          createdAt: Value(DateTime(2026, 1, 1)),
        ));
    final row = await db.select(db.moodEntries).getSingle();
    expect(row.images, isNull);

    await db.close();
  });
}
