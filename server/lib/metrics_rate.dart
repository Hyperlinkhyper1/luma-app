/// Cumulative host counters captured at a monotonic time.
class MetricsCounters {
  const MetricsCounters({
    required this.elapsedUs,
    this.cpuTotal,
    this.cpuIdle,
    this.rxBytes,
    this.txBytes,
    this.diskReadBytes,
    this.diskWriteBytes,
  });

  final int elapsedUs;
  final int? cpuTotal;
  final int? cpuIdle;
  final int? rxBytes;
  final int? txBytes;
  final int? diskReadBytes;
  final int? diskWriteBytes;
}

class MetricsRates {
  const MetricsRates({
    this.cpuPercent,
    this.rxBytesPerSec,
    this.txBytesPerSec,
    this.diskReadBytesPerSec,
    this.diskWriteBytesPerSec,
  });

  final double? cpuPercent;
  final double? rxBytesPerSec;
  final double? txBytesPerSec;
  final double? diskReadBytesPerSec;
  final double? diskWriteBytesPerSec;
}

/// Uses the entire interval between dashboard polls, rather than observing
/// only a short slice of each interval and amplifying intermittent activity.
class MetricsRateSampler {
  MetricsCounters? _previous;

  MetricsRates? add(MetricsCounters current) {
    final previous = _previous;
    if (previous == null) {
      _previous = current;
      return null;
    }
    final elapsedUs = current.elapsedUs - previous.elapsedUs;
    if (elapsedUs <= 0) return const MetricsRates();
    _previous = current;
    if (elapsedUs > 10000000) return const MetricsRates();

    double? rate(int? before, int? after) {
      if (before == null || after == null || after < before) return null;
      return (after - before) * 1000000 / elapsedUs;
    }

    double? cpu;
    final totalBefore = previous.cpuTotal;
    final totalAfter = current.cpuTotal;
    final idleBefore = previous.cpuIdle;
    final idleAfter = current.cpuIdle;
    if (totalBefore != null &&
        totalAfter != null &&
        idleBefore != null &&
        idleAfter != null) {
      final total = totalAfter - totalBefore;
      final idle = idleAfter - idleBefore;
      if (total > 0 && idle >= 0) {
        cpu = ((total - idle) / total * 100).clamp(0, 100).toDouble();
      }
    }

    return MetricsRates(
      cpuPercent: cpu,
      rxBytesPerSec: rate(previous.rxBytes, current.rxBytes),
      txBytesPerSec: rate(previous.txBytes, current.txBytes),
      diskReadBytesPerSec: rate(previous.diskReadBytes, current.diskReadBytes),
      diskWriteBytesPerSec:
          rate(previous.diskWriteBytes, current.diskWriteBytes),
    );
  }
}
