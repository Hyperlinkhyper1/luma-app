import 'package:drift/drift.dart';

import '../../../../storage/storage_guard.dart';
import 'data/calendar_database.dart';

/// Supported recurrence rules. Stored as the lowercase [name] in the DB.
enum Recurrence { none, daily, weekly, monthly, yearly }

extension RecurrenceLabel on Recurrence {
  String get label => switch (this) {
        Recurrence.none => 'Does not repeat',
        Recurrence.daily => 'Every day',
        Recurrence.weekly => 'Every week',
        Recurrence.monthly => 'Every month',
        Recurrence.yearly => 'Every year',
      };

  static Recurrence parse(String raw) => Recurrence.values.firstWhere(
        (r) => r.name == raw,
        orElse: () => Recurrence.none,
      );
}

/// A stored event (the "template" for recurring events). Concrete dated
/// instances are produced by `expandOccurrences` in `recurrence.dart`.
class EventRecord {
  const EventRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.start,
    required this.end,
    required this.allDay,
    required this.color,
    required this.recurrence,
    required this.recurrenceEnd,
    required this.reminderMinutes,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String? description;
  final String? location;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final int color;
  final Recurrence recurrence;
  final DateTime? recurrenceEnd;
  final int? reminderMinutes;
  final DateTime createdAt;

  Duration get duration => end.difference(start);
}

/// CRUD over calendar events, backed by [CalendarDatabase].
class CalendarRepository {
  CalendarRepository(this._db);

  final CalendarDatabase _db;

  /// Streams every stored event, soonest-starting first. Occurrence expansion
  /// happens in the UI so recurring events stay a single row.
  Stream<List<EventRecord>> watchAll() {
    final query = _db.select(_db.calendarEvents)
      ..orderBy([(t) => OrderingTerm.asc(t.start)]);
    return query.watch().map(
          (rows) => rows.map(_toRecord).toList(growable: false),
        );
  }

  Future<int> add({
    required String title,
    String? description,
    String? location,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    int color = 0xFF7C5AD9,
    Recurrence recurrence = Recurrence.none,
    DateTime? recurrenceEnd,
    int? reminderMinutes,
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    final id = await _db.into(_db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            title: title,
            description: Value(description),
            location: Value(location),
            start: start,
            end: end,
            allDay: Value(allDay),
            color: Value(color),
            recurrence: Value(recurrence.name),
            recurrenceEnd: Value(recurrenceEnd),
            reminderMinutes: Value(reminderMinutes),
          ),
        );
    StorageGuard.instance.scheduleRefresh();
    return id;
  }

  Future<void> update({
    required int id,
    required String title,
    String? description,
    String? location,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    required int color,
    required Recurrence recurrence,
    DateTime? recurrenceEnd,
    int? reminderMinutes,
  }) {
    return (_db.update(_db.calendarEvents)..where((t) => t.id.equals(id))).write(
      CalendarEventsCompanion(
        title: Value(title),
        description: Value(description),
        location: Value(location),
        start: Value(start),
        end: Value(end),
        allDay: Value(allDay),
        color: Value(color),
        recurrence: Value(recurrence.name),
        recurrenceEnd: Value(recurrenceEnd),
        reminderMinutes: Value(reminderMinutes),
      ),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.calendarEvents)..where((t) => t.id.equals(id))).go();
  }

  EventRecord _toRecord(CalendarEvent row) => EventRecord(
        id: row.id,
        title: row.title,
        description: row.description,
        location: row.location,
        start: row.start,
        end: row.end,
        allDay: row.allDay,
        color: row.color,
        recurrence: RecurrenceLabel.parse(row.recurrence),
        recurrenceEnd: row.recurrenceEnd,
        reminderMinutes: row.reminderMinutes,
        createdAt: row.createdAt,
      );
}
