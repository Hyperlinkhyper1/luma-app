import 'data/usage_database.dart';

/// Total tracked time for one app within a queried range.
class AppUsageTotal {
  const AppUsageTotal({
    required this.processName,
    required this.appName,
    required this.seconds,
  });

  final String processName;
  final String appName;
  final int seconds;
}

/// One local calendar day's worth of per-app totals, for the stacked bar
/// chart. [day] is local midnight.
class DayUsageBucket {
  const DayUsageBucket({required this.day, required this.secondsByApp});

  final DateTime day;
  final Map<String, int> secondsByApp; // keyed by processName

  int get totalSeconds => secondsByApp.values.fold(0, (a, b) => a + b);
}

/// Quick time-range presets shown in the page's filter bar.
enum UsageRangePreset {
  today('Today'),
  yesterday('Yesterday'),
  last7Days('Last week'),
  thisMonth('This month'),
  last30Days('Last month'),
  custom('Custom…');

  const UsageRangePreset(this.label);
  final String label;
}

/// Resolves [preset] to a concrete `[start, end)` local-time window, anchored
/// at [now]. Not meaningful for [UsageRangePreset.custom] — callers must
/// supply their own picked range in that case.
(DateTime, DateTime) resolveUsageRange(UsageRangePreset preset, DateTime now) {
  final todayStart = DateTime(now.year, now.month, now.day);
  switch (preset) {
    case UsageRangePreset.today:
      return (todayStart, now);
    case UsageRangePreset.yesterday:
      return (todayStart.subtract(const Duration(days: 1)), todayStart);
    case UsageRangePreset.last7Days:
      return (now.subtract(const Duration(days: 7)), now);
    case UsageRangePreset.thisMonth:
      return (DateTime(now.year, now.month, 1), now);
    case UsageRangePreset.last30Days:
      return (now.subtract(const Duration(days: 30)), now);
    case UsageRangePreset.custom:
      return (todayStart, now);
  }
}

/// Clips [session] (stored in UTC) to its overlap with the local-time
/// `[start, end)` window and returns the overlap in seconds, or 0 if the
/// session doesn't intersect the window at all.
int _overlapSeconds(UsageSession session, DateTime start, DateTime end) {
  final sessionStart = session.startedAt.toLocal();
  final sessionEnd = session.endedAt.toLocal();
  final clippedStart = sessionStart.isBefore(start) ? start : sessionStart;
  final clippedEnd = sessionEnd.isAfter(end) ? end : sessionEnd;
  final seconds = clippedEnd.difference(clippedStart).inSeconds;
  return seconds > 0 ? seconds : 0;
}

/// Process names (as stored, lowercase) whose display name is fixed
/// regardless of what was recorded when the session started — lets a rename
/// (e.g. javaw.exe → "Minecraft") apply to sessions tracked before the
/// rename too, not just new ones.
const Map<String, String> _appNameOverrides = {
  'javaw.exe': 'Minecraft',
};

/// Totals tracked time per app across [sessions], clipped to `[start, end)`,
/// sorted by descending time.
List<AppUsageTotal> aggregateByApp(
  Iterable<UsageSession> sessions, {
  required DateTime start,
  required DateTime end,
}) {
  final secondsByProcess = <String, int>{};
  final nameByProcess = <String, String>{};
  for (final session in sessions) {
    final overlap = _overlapSeconds(session, start, end);
    if (overlap <= 0) continue;
    secondsByProcess.update(
      session.processName,
      (v) => v + overlap,
      ifAbsent: () => overlap,
    );
    nameByProcess[session.processName] = session.appName;
  }

  final totals = [
    for (final entry in secondsByProcess.entries)
      AppUsageTotal(
        processName: entry.key,
        appName: _appNameOverrides[entry.key] ??
            nameByProcess[entry.key] ??
            entry.key,
        seconds: entry.value,
      ),
  ];
  totals.sort((a, b) => b.seconds.compareTo(a.seconds));
  return totals;
}

/// Splits each session's time across the local calendar days it touches
/// within `[start, end)`, for a per-day stacked breakdown. Days with no
/// tracked time are omitted. Buckets are keyed by [UsageSession.processName]
/// — pair with [aggregateByApp] on the same sessions/range for display names.
List<DayUsageBucket> aggregateByDay(
  Iterable<UsageSession> sessions, {
  required DateTime start,
  required DateTime end,
}) {
  final byDay = <DateTime, Map<String, int>>{};

  for (final session in sessions) {
    var cursor = session.startedAt.toLocal();
    final sessionEnd = session.endedAt.toLocal();
    if (cursor.isBefore(start)) cursor = start;
    final clippedEnd = sessionEnd.isAfter(end) ? end : sessionEnd;
    if (!cursor.isBefore(clippedEnd)) continue;

    while (cursor.isBefore(clippedEnd)) {
      final day = DateTime(cursor.year, cursor.month, cursor.day);
      final nextDay = DateTime(day.year, day.month, day.day + 1);
      final sliceEnd = clippedEnd.isBefore(nextDay) ? clippedEnd : nextDay;
      final seconds = sliceEnd.difference(cursor).inSeconds;
      if (seconds > 0) {
        final dayMap = byDay.putIfAbsent(day, () => <String, int>{});
        dayMap.update(
          session.processName,
          (v) => v + seconds,
          ifAbsent: () => seconds,
        );
      }
      cursor = sliceEnd;
    }
  }

  final buckets = [
    for (final entry in byDay.entries)
      DayUsageBucket(day: entry.key, secondsByApp: entry.value),
  ];
  buckets.sort((a, b) => a.day.compareTo(b.day));
  return buckets;
}

/// Formats a duration in seconds as e.g. "1h 23m", "45m", or "32s" — used
/// wherever tracked time is shown compactly (list rows, chart tooltips).
String formatUsageDuration(int totalSeconds) {
  if (totalSeconds < 60) return '${totalSeconds}s';
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours <= 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}
