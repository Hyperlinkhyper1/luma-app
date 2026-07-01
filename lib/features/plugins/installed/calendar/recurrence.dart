import 'calendar_repository.dart';

/// One concrete, dated instance of an [EventRecord]. A non-recurring event
/// yields exactly one of these; a recurring event yields one per repetition
/// that falls inside the requested range.
class EventOccurrence {
  const EventOccurrence({
    required this.event,
    required this.start,
    required this.end,
  });

  final EventRecord event;
  final DateTime start;
  final DateTime end;

  int get color => event.color;
  bool get allDay => event.allDay;
  String get title => event.title;

  /// Whether this occurrence touches the given calendar day (start..end
  /// inclusive), so multi-day events show on every day they span.
  bool coversDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }
}

/// Safety cap so a daily event with no end date can't loop forever while
/// filling a bounded window.
const _maxRepetitions = 1500;

/// Expands [events] into concrete occurrences overlapping the half-open range
/// [rangeStart, rangeEnd), sorted by start time. All-day events sort ahead of
/// timed events on the same day.
List<EventOccurrence> expandOccurrences(
  List<EventRecord> events,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final result = <EventOccurrence>[];

  for (final e in events) {
    final duration = e.duration;

    if (e.recurrence == Recurrence.none) {
      if (e.end.isAfter(rangeStart) && e.start.isBefore(rangeEnd)) {
        result.add(EventOccurrence(event: e, start: e.start, end: e.end));
      }
      continue;
    }

    var occStart = e.start;
    final until = e.recurrenceEnd;
    for (var i = 0; i < _maxRepetitions; i++) {
      if (occStart.isAfter(rangeEnd)) break;
      if (until != null && _dateOnly(occStart).isAfter(_dateOnly(until))) break;

      final occEnd = occStart.add(duration);
      if (occEnd.isAfter(rangeStart)) {
        result.add(EventOccurrence(event: e, start: occStart, end: occEnd));
      }
      occStart = _advance(occStart, e.recurrence);
    }
  }

  result.sort((a, b) {
    final byDay = _dateOnly(a.start).compareTo(_dateOnly(b.start));
    if (byDay != 0) return byDay;
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    return a.start.compareTo(b.start);
  });
  return result;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Advances a datetime by one step of [rec], preserving wall-clock time and
/// clamping day-of-month overflow (e.g. monthly on the 31st → last day of
/// shorter months).
DateTime _advance(DateTime d, Recurrence rec) {
  switch (rec) {
    case Recurrence.daily:
      return DateTime(d.year, d.month, d.day + 1, d.hour, d.minute);
    case Recurrence.weekly:
      return DateTime(d.year, d.month, d.day + 7, d.hour, d.minute);
    case Recurrence.monthly:
      return _addMonths(d, 1);
    case Recurrence.yearly:
      return _addMonths(d, 12);
    case Recurrence.none:
      return DateTime(d.year, d.month, d.day + 1, d.hour, d.minute);
  }
}

DateTime _addMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final year = d.year + (total ~/ 12);
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day; // day 0 = last of prev
  final day = d.day <= lastDay ? d.day : lastDay;
  return DateTime(year, month, day, d.hour, d.minute);
}
