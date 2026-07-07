/// Shared minutes-from-midnight <-> "9:00 AM" helpers for the timetable.
String formatMinutesOfDay(int minutes) {
  final h24 = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  final period = h24 >= 12 ? 'PM' : 'AM';
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}

const kWeekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String weekdayName(int dayOfWeek) => kWeekdayNames[(dayOfWeek - 1).clamp(0, 6)];
