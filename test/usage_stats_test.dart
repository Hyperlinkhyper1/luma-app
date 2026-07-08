import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/usage/data/usage_database.dart';
import 'package:luma/features/plugins/installed/usage/usage_stats.dart';

UsageSession _session({
  int id = 0,
  String appName = 'Chrome',
  String processName = 'chrome.exe',
  required DateTime startedAt,
  required DateTime endedAt,
}) =>
    UsageSession(
      id: id,
      appName: appName,
      processName: processName,
      windowTitle: null,
      startedAt: startedAt.toUtc(),
      endedAt: endedAt.toUtc(),
      durationSeconds: endedAt.difference(startedAt).inSeconds,
    );

void main() {
  group('formatUsageDuration', () {
    test('sub-minute durations show seconds', () {
      expect(formatUsageDuration(45), '45s');
    });

    test('whole minutes show just minutes', () {
      expect(formatUsageDuration(600), '10m');
    });

    test('whole hours show just hours', () {
      expect(formatUsageDuration(7200), '2h');
    });

    test('hours and minutes both show', () {
      expect(formatUsageDuration(3723), '1h 2m');
    });
  });

  group('aggregateByApp', () {
    test('sums time per process and sorts descending', () {
      final day = DateTime(2026, 1, 1);
      final sessions = [
        _session(
            appName: 'Chrome',
            processName: 'chrome.exe',
            startedAt: day,
            endedAt: day.add(const Duration(minutes: 10))),
        _session(
            appName: 'Chrome',
            processName: 'chrome.exe',
            startedAt: day.add(const Duration(minutes: 20)),
            endedAt: day.add(const Duration(minutes: 25))),
        _session(
            appName: 'Spotify',
            processName: 'spotify.exe',
            startedAt: day.add(const Duration(minutes: 30)),
            endedAt: day.add(const Duration(minutes: 50))),
      ];

      final totals = aggregateByApp(sessions,
          start: day, end: day.add(const Duration(hours: 1)));

      expect(totals, hasLength(2));
      expect(totals.first.processName, 'spotify.exe');
      expect(totals.first.seconds, const Duration(minutes: 20).inSeconds);
      expect(totals.last.processName, 'chrome.exe');
      expect(totals.last.seconds, const Duration(minutes: 15).inSeconds);
    });

    test('clips sessions that only partially overlap the range', () {
      final day = DateTime(2026, 1, 1, 23);
      final sessions = [
        _session(
            startedAt: day,
            endedAt: day.add(const Duration(hours: 2))), // spans midnight
      ];

      // Only the first hour falls inside [day, midnight).
      final totals = aggregateByApp(sessions,
          start: day, end: DateTime(2026, 1, 2));

      expect(totals.single.seconds, const Duration(hours: 1).inSeconds);
    });

    test('ignores sessions entirely outside the range', () {
      final day = DateTime(2026, 1, 1);
      final sessions = [
        _session(
            startedAt: day.subtract(const Duration(hours: 2)),
            endedAt: day.subtract(const Duration(hours: 1))),
      ];

      final totals = aggregateByApp(sessions, start: day, end: day.add(const Duration(days: 1)));
      expect(totals, isEmpty);
    });
  });

  group('aggregateByDay', () {
    test('splits a session that spans midnight across two day buckets', () {
      final start = DateTime(2026, 1, 1, 23);
      final sessions = [
        _session(startedAt: start, endedAt: start.add(const Duration(hours: 2))),
      ];

      final buckets = aggregateByDay(
        sessions,
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 3),
      );

      expect(buckets, hasLength(2));
      expect(buckets[0].day, DateTime(2026, 1, 1));
      expect(buckets[0].secondsByApp['chrome.exe'], const Duration(hours: 1).inSeconds);
      expect(buckets[1].day, DateTime(2026, 1, 2));
      expect(buckets[1].secondsByApp['chrome.exe'], const Duration(hours: 1).inSeconds);
    });

    test('keeps separate apps separate within the same day', () {
      final day = DateTime(2026, 1, 1, 8);
      final sessions = [
        _session(
            processName: 'chrome.exe',
            startedAt: day,
            endedAt: day.add(const Duration(minutes: 30))),
        _session(
            processName: 'spotify.exe',
            startedAt: day.add(const Duration(minutes: 30)),
            endedAt: day.add(const Duration(hours: 1))),
      ];

      final buckets = aggregateByDay(
        sessions,
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 2),
      );

      expect(buckets, hasLength(1));
      expect(buckets.single.secondsByApp['chrome.exe'], const Duration(minutes: 30).inSeconds);
      expect(buckets.single.secondsByApp['spotify.exe'], const Duration(minutes: 30).inSeconds);
      expect(buckets.single.totalSeconds, const Duration(hours: 1).inSeconds);
    });
  });

  group('resolveUsageRange', () {
    test('today starts at local midnight and ends at now', () {
      final now = DateTime(2026, 3, 5, 14, 30);
      final (start, end) = resolveUsageRange(UsageRangePreset.today, now);
      expect(start, DateTime(2026, 3, 5));
      expect(end, now);
    });

    test('yesterday is the full previous calendar day', () {
      final now = DateTime(2026, 3, 5, 14, 30);
      final (start, end) = resolveUsageRange(UsageRangePreset.yesterday, now);
      expect(start, DateTime(2026, 3, 4));
      expect(end, DateTime(2026, 3, 5));
    });

    test('thisMonth starts on the 1st', () {
      final now = DateTime(2026, 3, 5, 14, 30);
      final (start, end) = resolveUsageRange(UsageRangePreset.thisMonth, now);
      expect(start, DateTime(2026, 3, 1));
      expect(end, now);
    });
  });
}
