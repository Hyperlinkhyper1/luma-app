import 'dart:convert';
import 'dart:io';

import 'metrics.dart';
import 'util.dart';

/// One recorded (or averaged) metrics sample at a point in time.
class MetricsPoint {
  MetricsPoint({
    required this.tsMs,
    this.cpuPercent,
    this.ramUsedBytes,
    this.ramTotalBytes,
    this.netRxBytesPerSec,
    this.netTxBytesPerSec,
    this.diskReadBytesPerSec,
    this.diskWriteBytesPerSec,
  });

  final int tsMs;
  final double? cpuPercent;
  final double? ramUsedBytes;
  final double? ramTotalBytes;
  final double? netRxBytesPerSec;
  final double? netTxBytesPerSec;
  final double? diskReadBytesPerSec;
  final double? diskWriteBytesPerSec;

  factory MetricsPoint.fromSample(int tsMs, SystemMetrics m) => MetricsPoint(
        tsMs: tsMs,
        cpuPercent: m.cpuPercent,
        ramUsedBytes: m.ramUsedBytes?.toDouble(),
        ramTotalBytes: m.ramTotalBytes?.toDouble(),
        netRxBytesPerSec: m.netRxBytesPerSec,
        netTxBytesPerSec: m.netTxBytesPerSec,
        diskReadBytesPerSec: m.diskReadBytesPerSec,
        diskWriteBytesPerSec: m.diskWriteBytesPerSec,
      );

  /// Averages every non-null value for each field across [points], used to
  /// collapse a run of raw samples into one bucket (minute or hour).
  factory MetricsPoint.average(int bucketTsMs, List<MetricsPoint> points) {
    double? avg(Iterable<double?> values) {
      final present = values.whereType<double>().toList();
      if (present.isEmpty) return null;
      return present.reduce((a, b) => a + b) / present.length;
    }

    return MetricsPoint(
      tsMs: bucketTsMs,
      cpuPercent: avg(points.map((p) => p.cpuPercent)),
      ramUsedBytes: avg(points.map((p) => p.ramUsedBytes)),
      ramTotalBytes: avg(points.map((p) => p.ramTotalBytes)),
      netRxBytesPerSec: avg(points.map((p) => p.netRxBytesPerSec)),
      netTxBytesPerSec: avg(points.map((p) => p.netTxBytesPerSec)),
      diskReadBytesPerSec: avg(points.map((p) => p.diskReadBytesPerSec)),
      diskWriteBytesPerSec: avg(points.map((p) => p.diskWriteBytesPerSec)),
    );
  }

  Map<String, dynamic> toJson() => {
        'tsMs': tsMs,
        'cpuPercent': cpuPercent,
        'ramUsedBytes': ramUsedBytes,
        'ramTotalBytes': ramTotalBytes,
        'netRxBytesPerSec': netRxBytesPerSec,
        'netTxBytesPerSec': netTxBytesPerSec,
        'diskReadBytesPerSec': diskReadBytesPerSec,
        'diskWriteBytesPerSec': diskWriteBytesPerSec,
      };

  factory MetricsPoint.fromJson(Map<String, dynamic> j) => MetricsPoint(
        tsMs: j['tsMs'] as int,
        cpuPercent: (j['cpuPercent'] as num?)?.toDouble(),
        ramUsedBytes: (j['ramUsedBytes'] as num?)?.toDouble(),
        ramTotalBytes: (j['ramTotalBytes'] as num?)?.toDouble(),
        netRxBytesPerSec: (j['netRxBytesPerSec'] as num?)?.toDouble(),
        netTxBytesPerSec: (j['netTxBytesPerSec'] as num?)?.toDouble(),
        diskReadBytesPerSec: (j['diskReadBytesPerSec'] as num?)?.toDouble(),
        diskWriteBytesPerSec: (j['diskWriteBytesPerSec'] as num?)?.toDouble(),
      );
}

/// Persisted, downsampled history of [SystemMetrics] samples backing the
/// admin dashboard's graph range selector (1 minute / 1 hour / 24 hours /
/// 1 week). Every call to /admin/metrics feeds one raw sample in via
/// [addSample]; raw samples are cascaded into coarser 1-minute and 1-hour
/// buckets so a week of history stays a few hundred points instead of
/// hundreds of thousands. State is written through to disk on every sample
/// (mirroring Store's activity feed) so a page reload — or a server
/// restart — doesn't lose the graphs.
class MetricsHistory {
  MetricsHistory._(this._filePath);

  final String _filePath;

  /// Raw samples, one per /admin/metrics poll (~every 2s while the
  /// dashboard is open). Capped to comfortably cover the "1 minute" range.
  final List<MetricsPoint> _raw = [];
  static const _rawCap = 45;

  /// One point per minute, covering the "1 hour" range.
  final List<MetricsPoint> _minutes = [];
  static const _minuteCap = 90;

  /// One point per hour, covering the "24 hours" and "1 week" ranges.
  final List<MetricsPoint> _hours = [];
  static const _hourCap = 24 * 8;

  int? _pendingMinuteKey;
  final List<MetricsPoint> _pendingMinuteSamples = [];
  int? _pendingHourKey;
  final List<MetricsPoint> _pendingHourSamples = [];

  static Future<MetricsHistory> open(String rootPath) async {
    final history = MetricsHistory._('$rootPath/metrics_history.json');
    await history._load();
    return history;
  }

  Future<void> _load() async {
    final file = File(_filePath);
    if (!await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      void fill(String key, List<MetricsPoint> target) {
        final list = decoded[key];
        if (list is! List) return;
        for (final item in list) {
          target.add(MetricsPoint.fromJson(item as Map<String, dynamic>));
        }
      }

      fill('raw', _raw);
      fill('minutes', _minutes);
      fill('hours', _hours);
    } catch (_) {
      // Corrupt/unreadable history file — start fresh rather than crash.
    }
  }

  Future<void> _save() => atomicWriteString(
        _filePath,
        jsonEncode({
          'raw': _raw.map((p) => p.toJson()).toList(),
          'minutes': _minutes.map((p) => p.toJson()).toList(),
          'hours': _hours.map((p) => p.toJson()).toList(),
        }),
      );

  /// Records one live sample and cascades completed minute/hour buckets.
  /// No-ops (and doesn't persist) for unsupported platforms, matching how
  /// the live /admin/metrics response already omits everything in that case.
  Future<void> addSample(SystemMetrics m) async {
    if (!m.platformSupported) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final point = MetricsPoint.fromSample(now, m);

    _raw.add(point);
    if (_raw.length > _rawCap) _raw.removeAt(0);

    final minuteKey = now ~/ 60000;
    _pendingMinuteKey ??= minuteKey;
    if (minuteKey != _pendingMinuteKey) {
      _flushMinute(_pendingMinuteKey!);
      _pendingMinuteKey = minuteKey;
    }
    _pendingMinuteSamples.add(point);

    await _save();
  }

  void _flushMinute(int minuteKey) {
    if (_pendingMinuteSamples.isEmpty) return;
    final bucketTs = minuteKey * 60000;
    final avg = MetricsPoint.average(bucketTs, _pendingMinuteSamples);
    _minutes.add(avg);
    if (_minutes.length > _minuteCap) _minutes.removeAt(0);
    _pendingMinuteSamples.clear();

    final hourKey = bucketTs ~/ 3600000;
    _pendingHourKey ??= hourKey;
    if (hourKey != _pendingHourKey) {
      _flushHour(_pendingHourKey!);
      _pendingHourKey = hourKey;
    }
    _pendingHourSamples.add(avg);
  }

  void _flushHour(int hourKey) {
    if (_pendingHourSamples.isEmpty) return;
    final bucketTs = hourKey * 3600000;
    final avg = MetricsPoint.average(bucketTs, _pendingHourSamples);
    _hours.add(avg);
    if (_hours.length > _hourCap) _hours.removeAt(0);
    _pendingHourSamples.clear();
  }

  static List<T> _lastN<T>(List<T> list, int n) =>
      list.length > n ? list.sublist(list.length - n) : list;

  /// Points for one of 'minute' / 'hour' / 'day' / 'week', oldest first.
  List<MetricsPoint> pointsForRange(String range) {
    switch (range) {
      case 'hour':
        return _lastN(_minutes, 60);
      case 'day':
        return _lastN(_hours, 24);
      case 'week':
        return _lastN(_hours, 24 * 7);
      case 'minute':
      default:
        return List.of(_raw);
    }
  }
}
