import 'package:intl/intl.dart';

/// Shared minutes-from-midnight <-> "9:00 AM" helpers for the timetable.
String formatMinutesOfDay(int minutes) {
  final h24 = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return DateFormat.jm().format(DateTime(2024, 1, 1, h24, m));
}

/// Localised weekday name for ISO-style [dayOfWeek] (1 = Monday ... 7 = Sunday).
String weekdayName(int dayOfWeek) {
  final day = (dayOfWeek - 1).clamp(0, 6);
  // 1 January 2024 was a Monday, so day 1..7 of January maps to Monday..Sunday.
  return DateFormat.EEEE().format(DateTime(2024, 1, 1 + day));
}
