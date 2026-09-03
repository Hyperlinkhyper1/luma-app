import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../app/update/app_version.dart';
import '../../../../app/update/update_service.dart';
import 'device_health_models.dart';
import 'services/battery_report_service.dart';
import 'services/bloatware_catalog.dart';
import 'services/defender_service.dart';
import 'services/driver_service.dart';
import 'services/process_service.dart';
import 'services/system_stats_service.dart';
import 'services/winget_service.dart';

/// Orchestrates every Device Health category. State is naturally
/// stream-unfriendly here — a CPU reading or a process list is a one-shot
/// snapshot, not something a database watches — so this is a
/// [ChangeNotifier] rather than the plain-repository/drift-stream shape used
/// by plugins with real persisted data (see AGENTS.md's repository
/// guidance): every category is "whatever we last asked Windows for", and
/// widgets rebuild when that changes.
///
/// Nothing here is Windows-only-gated at the class level — [isSupported]
/// tells the page whether to show the dashboard at all, and every method
/// simply returns null/no-ops if called anyway.
class DeviceHealthRepository extends ChangeNotifier {
  DeviceHealthRepository({
    SystemStatsService? statsService,
    BatteryReportService? batteryReportService,
    ProcessService? processService,
    WingetService? wingetService,
    DefenderService? defenderService,
    DriverService? driverService,
    UpdateService? selfUpdateService,
  })  : _stats = statsService ?? const SystemStatsService(),
        _batteryReport = batteryReportService ?? const BatteryReportService(),
        _processes = processService ?? const ProcessService(),
        _winget = wingetService ?? const WingetService(),
        _defenderService = defenderService ?? const DefenderService(),
        _driverService = driverService ?? const DriverService(),
        _selfUpdate = selfUpdateService ?? UpdateService();

  final SystemStatsService _stats;
  final BatteryReportService _batteryReport;
  final ProcessService _processes;
  final WingetService _winget;
  final DefenderService _defenderService;
  final DriverService _driverService;
  final UpdateService _selfUpdate;

  BloatwareCatalog? _bloatware;

  static bool get isSupported => Platform.isWindows;

  HealthCategoryState<SystemUsage> systemUsage = const HealthCategoryState();
  HealthCategoryState<List<GpuInfo>> gpus = const HealthCategoryState();
  HealthCategoryState<BatteryInfo> battery = const HealthCategoryState();
  HealthCategoryState<DefenderStatus> defender = const HealthCategoryState();
  HealthCategoryState<List<ProcessInfo>> processes = const HealthCategoryState();
  HealthCategoryState<List<AppUpdateInfo>> appUpdates = const HealthCategoryState();

  UpdateInfo? lumaUpdate;
  bool lumaUpdateLoading = false;
  bool lumaUpdateChecked = false;
  bool lumaUpdateApplying = false;

  final Map<String, AppUpdateJob> jobs = {};
  static const lumaJobKey = '__luma__';

  bool _checkingEverything = false;
  bool get checkingEverything => _checkingEverything;

  DriverService get driverService => _driverService;

  /// The cheap ambient snapshot: CPU/RAM, GPU identification, battery
  /// (charge + wear) and Defender status. Auto-run when the page opens.
  Future<void> refreshAmbient() async {
    systemUsage = systemUsage.copyWith(loading: true);
    gpus = gpus.copyWith(loading: true);
    battery = battery.copyWith(loading: true);
    defender = defender.copyWith(loading: true);
    notifyListeners();

    final results = await Future.wait([
      _stats.fetch(),
      _batteryReport.fetchWear(),
    ]);
    final snapshot = results[0] as AmbientSnapshot?;
    final wear = results[1] as BatteryWear?;
    final now = DateTime.now();

    if (snapshot == null) {
      const err = 'Could not read system status.';
      systemUsage = systemUsage.copyWith(loading: false, error: err);
      gpus = gpus.copyWith(loading: false, error: err);
      battery = battery.copyWith(loading: false, error: err);
      defender = defender.copyWith(loading: false, error: err);
      notifyListeners();
      return;
    }

    systemUsage = HealthCategoryState(
      data: snapshot.usage,
      checkedAt: now,
      error: snapshot.usage == null ? 'CPU/RAM reading unavailable.' : null,
    );
    gpus = HealthCategoryState(data: snapshot.gpus, checkedAt: now);

    final quickBattery = snapshot.battery;
    final mergedBattery = quickBattery.present
        ? BatteryInfo(
            present: true,
            chargePercent: quickBattery.chargePercent,
            statusLabel: quickBattery.statusLabel,
            designCapacity: wear?.designCapacity,
            fullChargeCapacity: wear?.fullChargeCapacity,
          )
        : BatteryInfo(present: wear?.present ?? false);
    battery = HealthCategoryState(data: mergedBattery, checkedAt: now);

    defender = HealthCategoryState(
      data: snapshot.defender,
      checkedAt: now,
      error: snapshot.defender == null
          ? "Couldn't read Windows Defender's status — another antivirus "
              'may be active, or the Defender service is disabled.'
          : null,
    );
    notifyListeners();
  }

  Future<void> refreshProcesses() async {
    processes = processes.copyWith(loading: true);
    notifyListeners();
    _bloatware ??= await BloatwareCatalog.load();
    final list = await _processes.list(bloatware: _bloatware);
    processes = list == null
        ? processes.copyWith(loading: false, error: 'Could not list processes.')
        : HealthCategoryState(data: list, checkedAt: DateTime.now());
    notifyListeners();
  }

  Future<void> endProcess(int pid) async {
    _processes.end(pid);
    // Give the OS a moment to actually tear the process down before
    // re-listing, so the entry doesn't just reappear.
    await Future.delayed(const Duration(milliseconds: 400));
    await refreshProcesses();
  }

  Future<void> refreshAppUpdates() async {
    appUpdates = appUpdates.copyWith(loading: true);
    lumaUpdateLoading = true;
    notifyListeners();

    final results = await Future.wait([
      _winget.listUpgrades(),
      _selfUpdate.checkForUpdate(),
    ]);
    final list = results[0] as List<AppUpdateInfo>?;
    lumaUpdate = results[1] as UpdateInfo?;
    lumaUpdateChecked = true;
    lumaUpdateLoading = false;

    appUpdates = list == null
        ? appUpdates.copyWith(
            loading: false,
            error: 'winget is not available on this system.',
          )
        : HealthCategoryState(data: list, checkedAt: DateTime.now());
    notifyListeners();
  }

  Future<void> updateApp(AppUpdateInfo info) async {
    jobs[info.id] = AppUpdateJob(info: info, state: AppUpdateJobState.running);
    notifyListeners();
    final state = await _winget.upgrade(info);
    jobs[info.id] = AppUpdateJob(
      info: info,
      state: state,
      message: state == AppUpdateJobState.needsElevationOrManual
          ? 'Needs a manual update — winget could not finish silently.'
          : null,
    );
    notifyListeners();
    if (state == AppUpdateJobState.done) await refreshAppUpdates();
  }

  Future<void> updateLuma() async {
    final info = lumaUpdate;
    if (info == null) return;
    lumaUpdateApplying = true;
    jobs[lumaJobKey] = AppUpdateJob(
      info: AppUpdateInfo(
        id: lumaJobKey,
        name: 'luma',
        currentVersion: AppVersion.current,
        availableVersion: info.version,
        source: UpdateSource.other,
      ),
      state: AppUpdateJobState.running,
    );
    notifyListeners();
    // On success this calls exit(0) and never returns — the installer
    // relaunches luma itself (see UpdateService.applyUpdate).
    final ok = await _selfUpdate.applyUpdate(info);
    lumaUpdateApplying = false;
    jobs[lumaJobKey] = jobs[lumaJobKey]!.copyWith(
      state: ok ? AppUpdateJobState.done : AppUpdateJobState.failed,
      message: ok ? null : _selfUpdate.lastError,
    );
    notifyListeners();
  }

  /// Runs the update for every outdated app sequentially — one winget call
  /// at a time keeps any UAC prompt attributable to a single, visible item
  /// rather than a stack of simultaneous ones.
  Future<void> updateAllApps() async {
    final list = appUpdates.data;
    if (list != null) {
      for (final info in list) {
        await updateApp(info);
      }
    }
    if (lumaUpdate != null) await updateLuma();
  }

  Future<void> triggerDefenderScan() => _defenderService.startQuickScan();
  Future<bool> openWindowsSecurity() => _defenderService.openWindowsSecurity();
  Future<bool> openDriverTool(String vendor) => _driverService.openFor(vendor);
  Future<bool> openWindowsUpdate() => _driverService.openWindowsUpdate();

  /// Runs the ambient snapshot plus every heavier check — the "Check
  /// Everything" sweep.
  Future<void> checkEverything() async {
    _checkingEverything = true;
    notifyListeners();
    await Future.wait([
      refreshAmbient(),
      refreshProcesses(),
      refreshAppUpdates(),
    ]);
    _checkingEverything = false;
    notifyListeners();
  }

  static const _staleSignatureAfter = Duration(days: 7);
  static const _staleScanAfter = Duration(days: 30);

  HealthScore computeScore() {
    var score = 100;
    final issues = <String>[];
    var checked = 0;
    const total = 5; // CPU/RAM, battery, defender, processes, app updates.
    final now = DateTime.now();

    final usage = systemUsage.data;
    if (systemUsage.checkedAt != null && usage != null) {
      checked++;
      if (usage.ramUsedPercent > 90) {
        score -= 8;
        issues.add('RAM usage is very high (${usage.ramUsedPercent.round()}%).');
      } else if (usage.ramUsedPercent > 75) {
        score -= 4;
      }
      if (usage.cpuPercent > 90) {
        score -= 5;
        issues.add('CPU usage is very high (${usage.cpuPercent.round()}%).');
      }
    }

    final batt = battery.data;
    if (battery.checkedAt != null && batt != null && batt.present) {
      checked++;
      final wear = batt.wearPercent;
      if (wear != null && wear > 35) {
        score -= 15;
        issues.add('Battery health is significantly degraded '
            '(${wear.round()}% capacity lost).');
      } else if (wear != null && wear > 20) {
        score -= 8;
        issues.add('Battery health is fading (${wear.round()}% capacity lost).');
      }
    } else if (battery.checkedAt != null && batt != null && !batt.present) {
      // A desktop with no battery is neither good nor bad — don't count it
      // either way, but it has still been "checked".
      checked++;
    }

    final def = defender.data;
    if (defender.checkedAt != null && def != null) {
      checked++;
      if (!def.antivirusEnabled || !def.realTimeProtectionEnabled) {
        // Weighted hard enough that this alone always drops the status to
        // "Poor" — protection being off must never read as merely a warning.
        score -= 45;
        issues.add('Windows Defender protection is off.');
      } else {
        final sig = def.signatureLastUpdated;
        if (sig == null || now.difference(sig) > _staleSignatureAfter) {
          score -= 10;
          issues.add('Antivirus definitions are out of date.');
        }
        final scan = def.lastScan;
        if (scan == null || now.difference(scan) > _staleScanAfter) {
          score -= 10;
          issues.add('No virus scan in the last 30 days.');
        }
      }
    }

    final procs = processes.data;
    if (processes.checkedAt != null && procs != null) {
      checked++;
      final flagged = procs.where((p) => p.bloatware != null).length;
      if (flagged > 0) {
        score -= flagged * 2 > 10 ? 10 : flagged * 2;
        issues.add('$flagged background app${flagged == 1 ? '' : 's'} commonly '
            'flagged as unnecessary.');
      }
    }

    final updates = appUpdates.data;
    if (appUpdates.checkedAt != null && updates != null) {
      checked++;
      var count = updates.length;
      if (lumaUpdateChecked && lumaUpdate != null) count += 1;
      if (count > 0) {
        score -= count * 3 > 15 ? 15 : count * 3;
        issues.add('$count app update${count == 1 ? '' : 's'} available.');
      }
    }

    score = score.clamp(0, 100);
    final status = checked == 0
        ? HealthStatus.unknown
        : score >= 85
            ? HealthStatus.good
            : score >= 60
                ? HealthStatus.warning
                : HealthStatus.bad;

    return HealthScore(
      score: score,
      status: status,
      issues: issues,
      checkedCategories: checked,
      totalCategories: total,
    );
  }
}
