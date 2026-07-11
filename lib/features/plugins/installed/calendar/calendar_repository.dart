import 'package:drift/drift.dart';

import '../../../../family/family_api.dart';
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

/// Marks an [EventRecord] as a family-shared calendar entry rather than a
/// personal, local-only one. Present only on events that came from
/// [FamilyRepository.sharedEvents] — see calendar_page.dart's merge and
/// event_editor.dart's share controls. Deliberately NOT a Drift column: this
/// data lives server-side in the (server-readable) family channel, never in
/// the local, zero-knowledge-synced `CalendarEvents` table.
class FamilyShareInfo {
  const FamilyShareInfo({
    required this.familyId,
    required this.remoteEventId,
    required this.authorUserId,
    required this.sharedWithWholeFamily,
    required this.visibleMemberUserIds,
  });

  final String familyId;
  final String remoteEventId;
  final String authorUserId;
  final bool sharedWithWholeFamily;
  final List<String> visibleMemberUserIds;
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
    this.familyShare,
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

  /// Null for a personal, local-only event; set for one shared via a family.
  final FamilyShareInfo? familyShare;

  Duration get duration => end.difference(start);
}

/// Maps a server-side shared event into the same [EventRecord] shape the
/// Calendar UI already knows how to render, so calendar_page.dart can merge
/// personal and shared events into one list with no further branching.
EventRecord familyShareEventToRecord(RemoteSharedEvent e) => EventRecord(
      // Shared events are identified by [familyShare.remoteEventId] wherever
      // it matters (edits/deletes); this int id only needs to be a stable,
      // likely-unique value for widget keys/list diffing.
      id: e.id.hashCode,
      title: e.title,
      description: e.description,
      location: e.location,
      start: DateTime.fromMillisecondsSinceEpoch(e.startMs),
      end: DateTime.fromMillisecondsSinceEpoch(e.endMs),
      allDay: e.allDay,
      color: e.color,
      recurrence: RecurrenceLabel.parse(e.recurrence),
      recurrenceEnd: e.recurrenceEndMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(e.recurrenceEndMs!),
      reminderMinutes: e.reminderMinutes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(e.createdAtMs),
      familyShare: FamilyShareInfo(
        familyId: e.familyId,
        remoteEventId: e.id,
        authorUserId: e.authorUserId,
        sharedWithWholeFamily: e.visibility == 'all',
        visibleMemberUserIds: e.visibleMemberUserIds,
      ),
    );

/// The dinner planned for one day: a title, its ingredients and (optional)
/// instructions.
class DinnerPlanRecord {
  const DinnerPlanRecord({
    required this.id,
    required this.date,
    required this.title,
    required this.ingredients,
    required this.instructions,
    required this.servings,
    required this.minutes,
    required this.createdAt,
  });

  final int id;
  final DateTime date;
  final String title;
  final List<String> ingredients;
  final String? instructions;
  final int? servings;
  final int? minutes;
  final DateTime createdAt;
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

  // ── Dinner plans ─────────────────────────────────────────────────────

  /// Streams every planned dinner, one row per day.
  Stream<List<DinnerPlanRecord>> watchDinners() {
    final query = _db.select(_db.dinnerPlans)
      ..orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.watch().map(
          (rows) => rows.map(_toDinnerRecord).toList(growable: false),
        );
  }

  /// Sets (or replaces) the dinner planned for [day]. There is at most one
  /// dinner per day, so this overwrites any existing plan for that date.
  Future<void> setDinner({
    required DateTime day,
    required String title,
    List<String> ingredients = const [],
    String? instructions,
    int? servings,
    int? minutes,
  }) async {
    StorageGuard.instance.ensureWithinLimit();
    final date = DateTime(day.year, day.month, day.day);
    final ingredientsText = ingredients.join('\n');
    final existing = await (_db.select(_db.dinnerPlans)
          ..where((t) => t.date.equals(date)))
        .getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.dinnerPlans)..where((t) => t.id.equals(existing.id)))
          .write(
        DinnerPlansCompanion(
          title: Value(title),
          ingredients: Value(ingredientsText),
          instructions: Value(instructions),
          servings: Value(servings),
          minutes: Value(minutes),
        ),
      );
    } else {
      await _db.into(_db.dinnerPlans).insert(
            DinnerPlansCompanion.insert(
              date: date,
              title: title,
              ingredients: Value(ingredientsText),
              instructions: Value(instructions),
              servings: Value(servings),
              minutes: Value(minutes),
            ),
          );
    }
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> deleteDinner(int id) {
    return (_db.delete(_db.dinnerPlans)..where((t) => t.id.equals(id))).go();
  }

  DinnerPlanRecord _toDinnerRecord(DinnerPlan row) => DinnerPlanRecord(
        id: row.id,
        date: row.date,
        title: row.title,
        ingredients: row.ingredients
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(growable: false),
        instructions: row.instructions,
        servings: row.servings,
        minutes: row.minutes,
        createdAt: row.createdAt,
      );
}
