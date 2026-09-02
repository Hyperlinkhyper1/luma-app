import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'mc_models.dart';

/// One day's totals for one series.
class McDailyPoint {
  const McDailyPoint({
    required this.day,
    required this.downloads,
    this.followers = 0,
    this.views = 0,
  });

  /// Midnight local time. Points are keyed by day, so refreshing five times
  /// in an afternoon updates one point instead of making five.
  final DateTime day;
  final int downloads;
  final int followers;
  final int views;

  Map<String, dynamic> toJson() => {
        'day': day.toIso8601String(),
        'downloads': downloads,
        if (followers != 0) 'followers': followers,
        if (views != 0) 'views': views,
      };

  factory McDailyPoint.fromJson(Map<String, dynamic> j) => McDailyPoint(
        day: DateTime.parse(j['day'] as String),
        downloads: (j['downloads'] as num?)?.toInt() ?? 0,
        followers: (j['followers'] as num?)?.toInt() ?? 0,
        views: (j['views'] as num?)?.toInt() ?? 0,
      );
}

/// A day and the amount gained on it, derived from consecutive totals.
class McDelta {
  const McDelta({required this.day, required this.gained});

  final DateTime day;
  final int gained;
}

/// The local trend store.
///
/// CurseForge and Planet Minecraft publish a running total and nothing else —
/// no API on either side will say what yesterday's number was. So luma keeps
/// its own: one point per day per series, written on every refresh. A graph
/// therefore starts empty on a fresh install and fills in as the app is used,
/// which is a real limitation and one the UI states rather than hides.
///
/// Modrinth is the exception — its analytics endpoint serves real history, so
/// [backfill] can seed that series with days from before luma was installed.
class McHistoryStore {
  McHistoryStore._(this._file, this._series);

  final File? _file;
  final Map<String, List<McDailyPoint>> _series;

  /// Two years is far more than any trend view needs and keeps the file
  /// small even with a few hundred projects tracked.
  static const _maxDaysPerSeries = 730;

  static Future<McHistoryStore> load() async {
    File? file;
    final series = <String, List<McDailyPoint>>{};
    try {
      final dir = await getApplicationSupportDirectory();
      file = File('${dir.path}${Platform.pathSeparator}luma_mc_history.json');
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          for (final entry in json.entries) {
            series[entry.key] = [
              for (final point in (entry.value as List<dynamic>))
                McDailyPoint.fromJson(point as Map<String, dynamic>),
            ];
          }
        }
      }
    } catch (_) {
      // A corrupt or unreachable history file loses trends, not the app.
    }
    return McHistoryStore._(file, series);
  }

  /// An in-memory store, for tests and for the case where the app support
  /// directory is unavailable.
  static McHistoryStore inMemory([Map<String, List<McDailyPoint>>? seed]) =>
      McHistoryStore._(null, seed ?? {});

  List<String> get seriesKeys => _series.keys.toList();

  /// The stored points for a series, oldest first.
  List<McDailyPoint> seriesFor(String key) =>
      List.unmodifiable(_series[key] ?? const []);

  List<McDailyPoint> platformSeries(McPlatform platform) =>
      seriesFor(platform.id);

  /// Records today's totals, replacing today's point if one already exists.
  void record(
    String key, {
    required int downloads,
    int followers = 0,
    int views = 0,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final points = _series.putIfAbsent(key, () => []);

    final existing = points.indexWhere((p) => _sameDay(p.day, day));
    final point = McDailyPoint(
      day: day,
      downloads: downloads,
      followers: followers,
      views: views,
    );
    if (existing >= 0) {
      points[existing] = point;
    } else {
      points.add(point);
      points.sort((a, b) => a.day.compareTo(b.day));
    }
    if (points.length > _maxDaysPerSeries) {
      points.removeRange(0, points.length - _maxDaysPerSeries);
    }
  }

  /// Seeds a series with history from elsewhere — Modrinth's analytics
  /// endpoint, which reports per-day *gains*.
  ///
  /// The store holds cumulative totals, so the gains are integrated backwards
  /// from [currentTotal]: the newest day equals the total, and each earlier
  /// day is the one after it minus that day's gain. Days luma already
  /// recorded itself win, since those were observed rather than inferred.
  void backfillFromGains(
    String key,
    Map<DateTime, int> gainsByDay, {
    required int currentTotal,
  }) {
    if (gainsByDay.isEmpty) return;

    final days = gainsByDay.keys
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort();

    final totals = <DateTime, int>{};
    var running = currentTotal;
    for (var i = days.length - 1; i >= 0; i--) {
      final day = days[i];
      totals[day] = running;
      running -= gainsByDay[day] ?? 0;
      if (running < 0) running = 0;
    }

    final points = _series.putIfAbsent(key, () => []);
    for (final entry in totals.entries) {
      if (points.any((p) => _sameDay(p.day, entry.key))) continue;
      points.add(McDailyPoint(day: entry.key, downloads: entry.value));
    }
    points.sort((a, b) => a.day.compareTo(b.day));
    if (points.length > _maxDaysPerSeries) {
      points.removeRange(0, points.length - _maxDaysPerSeries);
    }
  }

  /// Per-day gains derived from consecutive totals.
  ///
  /// A negative step is dropped rather than charted: totals can go down when
  /// a project is deleted or a platform restates a figure, and a negative
  /// "downloads gained" bar is never the truth about a day.
  List<McDelta> deltasFor(String key) {
    final points = _series[key] ?? const [];
    if (points.length < 2) return const [];
    final out = <McDelta>[];
    for (var i = 1; i < points.length; i++) {
      final gained = points[i].downloads - points[i - 1].downloads;
      out.add(McDelta(day: points[i].day, gained: gained < 0 ? 0 : gained));
    }
    return out;
  }

  /// Per-day gains for several series added together, day by day.
  ///
  /// Deliberately *not* `deltasFor(combined(keys))`: diffing the summed
  /// totals would count a series' entire existing total as one giant "gain"
  /// on the day it first appears (a platform that already has 100k downloads
  /// does not gain 100k the day luma starts tracking it). Diffing each
  /// series on its own first — which already requires two of its own points
  /// before it produces anything — and summing the diffs afterwards avoids
  /// that: a series contributes nothing until it has real day-over-day
  /// change of its own to report.
  List<McDelta> combinedDeltas(List<String> keys) {
    final byDay = <DateTime, int>{};
    for (final key in keys) {
      for (final delta in deltasFor(key)) {
        byDay[delta.day] = (byDay[delta.day] ?? 0) + delta.gained;
      }
    }
    final days = byDay.keys.toList()..sort();
    return [for (final day in days) McDelta(day: day, gained: byDay[day]!)];
  }

  /// Total gained across the last [days] days of a series.
  int gainedInLast(String key, int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return deltasFor(key)
        .where((d) => d.day.isAfter(cutoff))
        .fold(0, (sum, d) => sum + d.gained);
  }

  /// How many days of history a series holds — what the UI needs to say
  /// "collecting since…" honestly.
  int daySpan(String key) {
    final points = _series[key] ?? const [];
    if (points.length < 2) return points.length;
    return points.last.day.difference(points.first.day).inDays + 1;
  }

  DateTime? firstDay(String key) {
    final points = _series[key] ?? const [];
    return points.isEmpty ? null : points.first.day;
  }

  /// Adds up several series into one, aligning them by day.
  ///
  /// Series that do not cover a day contribute their most recent earlier
  /// value, so a project added later does not make the combined line dip on
  /// the day it joined.
  List<McDailyPoint> combined(List<String> keys) {
    final days = <DateTime>{};
    for (final key in keys) {
      for (final point in _series[key] ?? const <McDailyPoint>[]) {
        days.add(point.day);
      }
    }
    if (days.isEmpty) return const [];

    final ordered = days.toList()..sort();
    final out = <McDailyPoint>[];
    for (final day in ordered) {
      var downloads = 0;
      var followers = 0;
      var views = 0;
      for (final key in keys) {
        final point = _mostRecentAtOrBefore(key, day);
        if (point == null) continue;
        downloads += point.downloads;
        followers += point.followers;
        views += point.views;
      }
      out.add(McDailyPoint(
        day: day,
        downloads: downloads,
        followers: followers,
        views: views,
      ));
    }
    return out;
  }

  McDailyPoint? _mostRecentAtOrBefore(String key, DateTime day) {
    final points = _series[key] ?? const <McDailyPoint>[];
    McDailyPoint? best;
    for (final point in points) {
      if (point.day.isAfter(day)) break;
      best = point;
    }
    return best;
  }

  /// Forgets a series — used when a platform is disconnected, so stale
  /// numbers cannot reappear in a combined chart later.
  void forget(String key) => _series.remove(key);

  void forgetWithPrefix(String prefix) =>
      _series.removeWhere((key, _) => key.startsWith(prefix));

  Future<void> persist() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(
        jsonEncode({
          for (final entry in _series.entries)
            entry.key: [for (final point in entry.value) point.toJson()],
        }),
        flush: true,
      );
    } catch (_) {}
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
