import 'package:drift/drift.dart';

import '../../../../storage/storage_guard.dart';
import 'data/errands_database.dart';

/// How often an errand repeats. [every] is the multiplier: daily is
/// (days, 1), weekly (weeks, 1), monthly (months, 1) and custom intervals
/// are (days, N).
enum RepeatUnit { days, weeks, months }

RepeatUnit repeatUnitFromKey(String key) => switch (key) {
      'weeks' => RepeatUnit.weeks,
      'months' => RepeatUnit.months,
      _ => RepeatUnit.days,
    };

/// Truncates [d] to local midnight so due-date comparisons are date-only.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The next occurrence [every] × [unit] after [from] (date-only). Months are
/// calendar months with the day clamped (Jan 31 + 1 month = Feb 28/29).
DateTime advanceSchedule(DateTime from, RepeatUnit unit, int every) {
  final base = dateOnly(from);
  switch (unit) {
    case RepeatUnit.days:
      return base.add(Duration(days: every));
    case RepeatUnit.weeks:
      return base.add(Duration(days: 7 * every));
    case RepeatUnit.months:
      final months = base.month - 1 + every;
      final year = base.year + months ~/ 12;
      final month = months % 12 + 1;
      final lastDay = DateTime(year, month + 1, 0).day;
      return DateTime(year, month, base.day > lastDay ? lastDay : base.day);
  }
}

/// A category, ready for display.
class ErrandCategoryRecord {
  const ErrandCategoryRecord({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
  });

  final int id;
  final String name;
  final int color;
  final int position;
}

/// An errand, ready for display.
class ErrandRecord {
  const ErrandRecord({
    required this.id,
    required this.name,
    required this.repeatUnit,
    required this.repeatEvery,
    required this.nextDue,
    this.categoryId,
    this.lastDone,
    this.notes,
  });

  final int id;
  final String name;
  final int? categoryId;
  final RepeatUnit repeatUnit;
  final int repeatEvery;
  final DateTime nextDue;
  final DateTime? lastDone;
  final String? notes;

  bool isDueOn(DateTime day) => !dateOnly(nextDue).isAfter(dateOnly(day));

  bool wasDoneOn(DateTime day) =>
      lastDone != null && dateOnly(lastDone!) == dateOnly(day);

  /// Days overdue relative to [day]; 0 when due today or later.
  int overdueDays(DateTime day) {
    final diff = dateOnly(day).difference(dateOnly(nextDue)).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Human label for the schedule ("Daily", "Every 2 weeks", "Every 10 days").
  String get repeatLabel {
    final n = repeatEvery;
    return switch (repeatUnit) {
      RepeatUnit.days => n == 1 ? 'Daily' : 'Every $n days',
      RepeatUnit.weeks => n == 1 ? 'Weekly' : 'Every $n weeks',
      RepeatUnit.months => n == 1 ? 'Monthly' : 'Every $n months',
    };
  }
}

/// CRUD + scheduling over the local errands store, backed by
/// [ErrandsDatabase].
class ErrandsRepository {
  ErrandsRepository(this._db);

  final ErrandsDatabase _db;

  // ---- Categories ----------------------------------------------------------

  Stream<List<ErrandCategoryRecord>> watchCategories() {
    final query = _db.select(_db.errandCategories)
      ..orderBy([
        (t) => OrderingTerm.asc(t.position),
        (t) => OrderingTerm.asc(t.name),
      ]);
    return query.watch().map(
          (rows) => rows
              .map((r) => ErrandCategoryRecord(
                    id: r.id,
                    name: r.name,
                    color: r.color,
                    position: r.position,
                  ))
              .toList(growable: false),
        );
  }

  Future<void> addCategory({required String name, required int color}) async {
    StorageGuard.instance.ensureWithinLimit();
    final existing = await _db.select(_db.errandCategories).get();
    final nextPos = existing.isEmpty
        ? 0
        : existing.map((c) => c.position).reduce((a, b) => a > b ? a : b) + 1;
    await _db.into(_db.errandCategories).insert(
          ErrandCategoriesCompanion.insert(
            name: name,
            color: Value(color),
            position: Value(nextPos),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> updateCategory(int id,
      {required String name, required int color}) async {
    StorageGuard.instance.ensureWithinLimit();
    await (_db.update(_db.errandCategories)..where((t) => t.id.equals(id)))
        .write(ErrandCategoriesCompanion(
      name: Value(name),
      color: Value(color),
    ));
    StorageGuard.instance.scheduleRefresh();
  }

  /// Deletes the category; its errands become uncategorized.
  Future<void> deleteCategory(int id) async {
    await (_db.update(_db.errands)..where((t) => t.categoryId.equals(id)))
        .write(const ErrandsCompanion(categoryId: Value(null)));
    await (_db.delete(_db.errandCategories)..where((t) => t.id.equals(id)))
        .go();
  }

  // ---- Errands -------------------------------------------------------------

  Stream<List<ErrandRecord>> watchErrands() {
    final query = _db.select(_db.errands)
      ..orderBy([
        (t) => OrderingTerm.asc(t.nextDue),
        (t) => OrderingTerm.asc(t.name),
      ]);
    return query.watch().map(
          (rows) => rows.map(_toRecord).toList(growable: false),
        );
  }

  Future<void> addErrand({
    required String name,
    required RepeatUnit repeatUnit,
    required int repeatEvery,
    required DateTime firstDue,
    int? categoryId,
    String? notes,
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    await _db.into(_db.errands).insert(
          ErrandsCompanion.insert(
            name: name,
            nextDue: dateOnly(firstDue),
            categoryId: Value(categoryId),
            repeatUnit: Value(repeatUnit.name),
            repeatEvery: Value(repeatEvery),
            notes: Value(notes),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> updateErrand(
    int id, {
    required String name,
    required RepeatUnit repeatUnit,
    required int repeatEvery,
    required DateTime nextDue,
    int? categoryId,
    String? notes,
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    await (_db.update(_db.errands)..where((t) => t.id.equals(id))).write(
      ErrandsCompanion(
        name: Value(name),
        categoryId: Value(categoryId),
        repeatUnit: Value(repeatUnit.name),
        repeatEvery: Value(repeatEvery),
        nextDue: Value(dateOnly(nextDue)),
        notes: Value(notes),
      ),
    );
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> deleteErrand(int id) {
    return (_db.delete(_db.errands)..where((t) => t.id.equals(id))).go();
  }

  /// Checks the errand off: remembers when, and schedules the next
  /// occurrence counting from today (so a chore done two days late doesn't
  /// come back two days early).
  Future<void> complete(ErrandRecord errand, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    await (_db.update(_db.errands)..where((t) => t.id.equals(errand.id)))
        .write(ErrandsCompanion(
      lastDone: Value(at),
      nextDue: Value(
        advanceSchedule(at, errand.repeatUnit, errand.repeatEvery),
      ),
    ));
  }

  /// Reverts a same-day check-off: the errand is due today again.
  Future<void> uncomplete(ErrandRecord errand, {DateTime? now}) async {
    await (_db.update(_db.errands)..where((t) => t.id.equals(errand.id)))
        .write(ErrandsCompanion(
      lastDone: const Value(null),
      nextDue: Value(dateOnly(now ?? DateTime.now())),
    ));
  }

  /// Pushes the errand [days] forward — from today when it's already due,
  /// or from its scheduled date when it's still upcoming.
  Future<void> snooze(ErrandRecord errand, int days, {DateTime? now}) async {
    final today = dateOnly(now ?? DateTime.now());
    final base = errand.nextDue.isAfter(today) ? dateOnly(errand.nextDue) : today;
    await (_db.update(_db.errands)..where((t) => t.id.equals(errand.id)))
        .write(ErrandsCompanion(
      nextDue: Value(base.add(Duration(days: days))),
    ));
  }

  ErrandRecord _toRecord(Errand row) => ErrandRecord(
        id: row.id,
        name: row.name,
        categoryId: row.categoryId,
        repeatUnit: repeatUnitFromKey(row.repeatUnit),
        repeatEvery: row.repeatEvery,
        nextDue: row.nextDue,
        lastDone: row.lastDone,
        notes: row.notes,
      );
}
