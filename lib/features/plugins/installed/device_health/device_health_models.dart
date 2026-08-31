/// Data model for the Device Health plugin.
///
/// Every reading here is windows-only and gathered on demand (see
/// `services/`) — nothing is cached to disk and nothing syncs, since a
/// snapshot of live hardware/process state is stale the moment it's taken.
library;

/// Traffic-light status for a category or the overall score.
enum HealthStatus { unknown, good, warning, bad }

/// Wraps a category's latest result with its in-flight/error state, so a
/// widget can show "loading" or "last known value, refresh failed" instead of
/// just flipping between null and a value.
class HealthCategoryState<T> {
  const HealthCategoryState({
    this.data,
    this.loading = false,
    this.error,
    this.checkedAt,
  });

  final T? data;
  final bool loading;
  final String? error;
  final DateTime? checkedAt;

  bool get hasData => data != null;

  HealthCategoryState<T> copyWith({
    T? data,
    bool? loading,
    String? error,
    DateTime? checkedAt,
    bool clearError = false,
  }) {
    return HealthCategoryState<T>(
      data: data ?? this.data,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }
}

class SystemUsage {
  const SystemUsage({
    required this.cpuPercent,
    required this.ramUsedGb,
    required this.ramTotalGb,
  });

  final double cpuPercent;
  final double ramUsedGb;
  final double ramTotalGb;

  double get ramUsedPercent =>
      ramTotalGb <= 0 ? 0 : (ramUsedGb / ramTotalGb) * 100;
}

class GpuInfo {
  const GpuInfo({
    required this.name,
    required this.driverVersion,
    this.driverDate,
    this.vramBytes,
  });

  final String name;
  final String driverVersion;
  final DateTime? driverDate;
  final int? vramBytes;

  /// Best-effort vendor guess from the adapter name, used to pick which
  /// vendor tool "Update driver" deep-links to. Never treated as exact.
  String get vendor {
    final n = name.toLowerCase();
    if (n.contains('nvidia') || n.contains('geforce') || n.contains('rtx') || n.contains('gtx')) {
      return 'NVIDIA';
    }
    if (n.contains('amd') || n.contains('radeon')) return 'AMD';
    if (n.contains('intel')) return 'Intel';
    return 'Unknown';
  }
}

class BatteryInfo {
  const BatteryInfo({
    required this.present,
    this.chargePercent,
    this.statusLabel,
    this.designCapacity,
    this.fullChargeCapacity,
  });

  final bool present;
  final int? chargePercent;
  final String? statusLabel;

  /// Both in mWh, parsed from `powercfg /batteryreport`. Null when the report
  /// didn't carry them (common on some OEM batteries).
  final int? designCapacity;
  final int? fullChargeCapacity;

  /// 0-100, where 0 means the battery still holds its full design capacity.
  /// Null when either capacity figure is unavailable.
  double? get wearPercent {
    final design = designCapacity;
    final full = fullChargeCapacity;
    if (design == null || full == null || design <= 0) return null;
    final wear = 100 - (full / design * 100);
    return wear < 0 ? 0 : wear;
  }
}

class BloatwareMatch {
  const BloatwareMatch({required this.label, required this.reason});
  final String label;
  final String reason;
}

class ProcessInfo {
  const ProcessInfo({
    required this.pid,
    required this.name,
    required this.workingSetBytes,
    required this.cpuPercent,
    this.path,
    this.bloatware,
  });

  final int pid;
  final String name;
  final String? path;
  final int workingSetBytes;
  final double cpuPercent;
  final BloatwareMatch? bloatware;
}

enum UpdateSource { winget, msstore, other }

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.id,
    required this.name,
    required this.currentVersion,
    required this.availableVersion,
    required this.source,
  });

  final String id;
  final String name;
  final String currentVersion;
  final String availableVersion;
  final UpdateSource source;

  /// Only plain `winget` packages can be silently upgraded end to end;
  /// msstore-sourced entries route through the Store instead.
  bool get silentEligible => source == UpdateSource.winget;
}

enum AppUpdateJobState { idle, running, done, failed, needsElevationOrManual }

class AppUpdateJob {
  const AppUpdateJob({
    required this.info,
    this.state = AppUpdateJobState.idle,
    this.message,
  });

  final AppUpdateInfo info;
  final AppUpdateJobState state;
  final String? message;

  AppUpdateJob copyWith({AppUpdateJobState? state, String? message}) =>
      AppUpdateJob(
        info: info,
        state: state ?? this.state,
        message: message ?? this.message,
      );
}

class DefenderStatus {
  const DefenderStatus({
    required this.antivirusEnabled,
    required this.realTimeProtectionEnabled,
    this.signatureLastUpdated,
    this.lastQuickScan,
    this.lastFullScan,
  });

  final bool antivirusEnabled;
  final bool realTimeProtectionEnabled;
  final DateTime? signatureLastUpdated;
  final DateTime? lastQuickScan;
  final DateTime? lastFullScan;

  DateTime? get lastScan {
    final q = lastQuickScan;
    final f = lastFullScan;
    if (q == null) return f;
    if (f == null) return q;
    return q.isAfter(f) ? q : f;
  }
}

/// Overall Device Health score. Only categories that have actually been
/// checked contribute deductions — an un-run category is neutral, never
/// treated as a failure.
class HealthScore {
  const HealthScore({
    required this.score,
    required this.status,
    required this.issues,
    required this.checkedCategories,
    required this.totalCategories,
  });

  final int score;
  final HealthStatus status;
  final List<String> issues;
  final int checkedCategories;
  final int totalCategories;
}
