import 'dart:async';

import 'package:drift/drift.dart';

import '../../../../storage/storage_guard.dart';
import 'data/text_library_database.dart';
import 'text_library_models.dart';

/// Every subject and every text, read together — what the Minecraft view
/// draws the whole hall from.
class LibrarySnapshot {
  const LibrarySnapshot({required this.subjects, required this.texts});

  final List<LibrarySubject> subjects;
  final List<LibraryText> texts;

  List<LibraryText> textsOf(int subjectId) =>
      texts.where((t) => t.subjectId == subjectId).toList(growable: false);
}

class TextLibraryRepository {
  TextLibraryRepository(this._db);

  final TextLibraryDatabase _db;

  // ─── Reading ──────────────────────────────────────────────────────────────

  Stream<List<LibrarySubject>> watchSubjects() {
    final query = _db.select(_db.librarySubjects)
      ..orderBy([
        (s) => OrderingTerm.asc(s.sortOrder),
        (s) => OrderingTerm.asc(s.id),
      ]);
    return query.watch().map((rows) => rows.map(_subject).toList());
  }

  Stream<List<LibraryText>> watchTexts(int subjectId) {
    final query = _db.select(_db.libraryTexts)
      ..where((t) => t.subjectId.equals(subjectId))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map((rows) => rows.map(_text).toList());
  }

  /// Subject id to the number of texts it holds.
  Stream<Map<int, int>> watchCounts() {
    final count = _db.libraryTexts.id.count();
    final query = _db.selectOnly(_db.libraryTexts)
      ..addColumns([_db.libraryTexts.subjectId, count])
      ..groupBy([_db.libraryTexts.subjectId]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.libraryTexts.subjectId)!: row.read(count) ?? 0,
      },
    );
  }

  Stream<LibrarySnapshot> watchLibrary() {
    late final StreamController<LibrarySnapshot> controller;
    StreamSubscription<void>? updates;
    var pending = Future<void>.value();
    // Reads are chained so a burst of writes can never deliver an older
    // snapshot after a newer one.
    void emit() {
      pending = pending.then((_) async {
        final snapshot = await loadLibrary();
        if (!controller.isClosed) controller.add(snapshot);
      });
    }

    controller = StreamController<LibrarySnapshot>(
      onListen: () {
        emit();
        updates = _db
            .tableUpdates(
              TableUpdateQuery.onAllTables([
                _db.librarySubjects,
                _db.libraryTexts,
              ]),
            )
            .listen((_) => emit());
      },
      onCancel: () async {
        await updates?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  Future<LibrarySnapshot> loadLibrary() async {
    final subjects =
        await (_db.select(_db.librarySubjects)..orderBy([
              (s) => OrderingTerm.asc(s.sortOrder),
              (s) => OrderingTerm.asc(s.id),
            ]))
            .get();
    final texts = await (_db.select(
      _db.libraryTexts,
    )..orderBy([(t) => OrderingTerm.asc(t.slot)])).get();
    return LibrarySnapshot(
      subjects: subjects.map(_subject).toList(growable: false),
      texts: texts.map(_text).toList(growable: false),
    );
  }

  Future<LibraryText?> getText(int id) async {
    final row = await (_db.select(
      _db.libraryTexts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _text(row);
  }

  // ─── Subjects ─────────────────────────────────────────────────────────────

  Future<int> createSubject(String name, {DyeColor? color}) async {
    final existing = await _db.select(_db.librarySubjects).get();
    final nextOrder = existing.fold<int>(
      0,
      (max, row) => row.sortOrder >= max ? row.sortOrder + 1 : max,
    );
    // Walk the dyes so a fresh hall does not start out all one colour.
    const cycle = [
      DyeColor.red,
      DyeColor.blue,
      DyeColor.green,
      DyeColor.orange,
      DyeColor.purple,
      DyeColor.cyan,
      DyeColor.yellow,
      DyeColor.magenta,
      DyeColor.lime,
      DyeColor.lightBlue,
      DyeColor.pink,
      DyeColor.brown,
    ];
    final id = await _db
        .into(_db.librarySubjects)
        .insert(
          LibrarySubjectsCompanion.insert(
            name: _clean(name, fallback: 'Subject'),
            color: Value(
              (color ?? cycle[existing.length % cycle.length]).index,
            ),
            sortOrder: Value(nextOrder),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> renameSubject(int id, String name) =>
      (_db.update(_db.librarySubjects)..where((s) => s.id.equals(id))).write(
        LibrarySubjectsCompanion(
          name: Value(_clean(name, fallback: 'Subject')),
        ),
      );

  Future<void> setSubjectColor(int id, DyeColor color) =>
      (_db.update(_db.librarySubjects)..where((s) => s.id.equals(id))).write(
        LibrarySubjectsCompanion(color: Value(color.index)),
      );

  /// Removes the subject and every text shelved under it.
  Future<void> deleteSubject(int id) => _db.transaction(() async {
    await (_db.delete(
      _db.libraryTexts,
    )..where((t) => t.subjectId.equals(id))).go();
    await (_db.delete(_db.librarySubjects)..where((s) => s.id.equals(id))).go();
  });

  /// Stores [ids] in that order.
  Future<void> reorderSubjects(List<int> ids) => _db.transaction(() async {
    for (var i = 0; i < ids.length; i++) {
      await (_db.update(_db.librarySubjects)..where((s) => s.id.equals(ids[i])))
          .write(LibrarySubjectsCompanion(sortOrder: Value(i)));
    }
  });

  // ─── Texts ────────────────────────────────────────────────────────────────

  /// Creates a text when [id] is null, otherwise updates it.
  ///
  /// A new text lands in [slot] when that slot is free and in the first free
  /// slot after it otherwise. An existing text only moves when [slot] is
  /// given, swapping with whatever book was there.
  Future<int> saveText({
    int? id,
    required int subjectId,
    required String title,
    String spine = '',
    required RichDoc body,
    DyeColor? cover,
    int? slot,
  }) => _db.transaction(() async {
    final now = DateTime.now();
    final cleanTitle = _clean(title, fallback: _titleFrom(body));
    if (id == null) {
      final taken = await _slotsOf(subjectId);
      final target = firstFreeSlot(taken, preferred: slot ?? 0);
      final newId = await _db
          .into(_db.libraryTexts)
          .insert(
            LibraryTextsCompanion.insert(
              subjectId: subjectId,
              title: cleanTitle,
              spine: Value(spine.trim()),
              body: Value(body.encode()),
              cover: Value((cover ?? DyeColor.brown).index),
              slot: Value(target),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      StorageGuard.instance.scheduleRefresh();
      return newId;
    }
    await (_db.update(_db.libraryTexts)..where((t) => t.id.equals(id))).write(
      LibraryTextsCompanion(
        title: Value(cleanTitle),
        spine: Value(spine.trim()),
        body: Value(body.encode()),
        cover: cover == null ? const Value.absent() : Value(cover.index),
        updatedAt: Value(now),
      ),
    );
    if (slot != null) await _place(id, subjectId, slot);
    return id;
  });

  /// Puts a text in [slot] of [subjectId]'s case, swapping with any book
  /// already there. Moving to another subject is allowed.
  Future<void> moveText(int id, {required int subjectId, required int slot}) =>
      _db.transaction(() => _place(id, subjectId, slot));

  Future<void> deleteText(int id) =>
      (_db.delete(_db.libraryTexts)..where((t) => t.id.equals(id))).go();

  Future<void> _place(int id, int subjectId, int slot) async {
    final moving = await (_db.select(
      _db.libraryTexts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (moving == null || slot < 0) return;
    if (moving.subjectId == subjectId && moving.slot == slot) return;
    final occupant =
        await (_db.select(_db.libraryTexts)..where(
              (t) =>
                  t.subjectId.equals(subjectId) &
                  t.slot.equals(slot) &
                  t.id.equals(id).not(),
            ))
            .getSingleOrNull();
    if (occupant != null) {
      // Same case: a straight swap. Across cases the displaced book moves to
      // the next gap in its own case, since the mover's old slot belongs to
      // a different case.
      final newSlot = moving.subjectId == subjectId
          ? moving.slot
          : firstFreeSlot(await _slotsOf(subjectId), preferred: slot);
      await (_db.update(_db.libraryTexts)
            ..where((t) => t.id.equals(occupant.id)))
          .write(LibraryTextsCompanion(slot: Value(newSlot)));
    }
    await (_db.update(_db.libraryTexts)..where((t) => t.id.equals(id))).write(
      LibraryTextsCompanion(subjectId: Value(subjectId), slot: Value(slot)),
    );
  }

  Future<List<int>> _slotsOf(int subjectId) async {
    final rows = await (_db.select(
      _db.libraryTexts,
    )..where((t) => t.subjectId.equals(subjectId))).get();
    return [for (final row in rows) row.slot];
  }

  static String _titleFrom(RichDoc body) {
    final firstLine = body.plainText
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) return 'Untitled';
    return firstLine.length <= 40 ? firstLine : firstLine.substring(0, 40);
  }

  static String _clean(String value, {required String fallback}) {
    final trimmed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  LibrarySubject _subject(LibrarySubjectRow row) => LibrarySubject(
    id: row.id,
    name: row.name,
    color: DyeColor.at(row.color),
    sortOrder: row.sortOrder,
    createdAt: row.createdAt,
  );

  LibraryText _text(LibraryTextRow row) => LibraryText(
    id: row.id,
    subjectId: row.subjectId,
    title: row.title,
    spine: row.spine,
    body: RichDoc.decode(row.body),
    cover: DyeColor.at(row.cover),
    slot: row.slot,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
