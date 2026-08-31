import 'dart:convert';

import '../device_health_models.dart';
import 'powershell_runner.dart';

/// The cheap, ambient snapshot Device Health auto-runs when the page opens:
/// CPU/RAM utilization, static GPU info, a quick battery read (charge only —
/// wear needs `powercfg`, see [BatteryReportService]) and Defender's status.
/// One PowerShell process for all of it, since spawning five separate ones on
/// every page open would be needlessly slow.
class AmbientSnapshot {
  const AmbientSnapshot({
    required this.usage,
    required this.gpus,
    required this.battery,
    required this.defender,
  });

  final SystemUsage? usage;
  final List<GpuInfo> gpus;
  final BatteryInfo battery;
  final DefenderStatus? defender;
}

class SystemStatsService {
  const SystemStatsService();

  static const _script = r'''
$cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
$os = Get-CimInstance Win32_OperatingSystem
$gpus = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,DriverDate,AdapterRAM)
$battery = @(Get-CimInstance Win32_Battery | Select-Object EstimatedChargeRemaining,BatteryStatus)
$defender = $null
try {
  $defender = Get-MpComputerStatus -ErrorAction Stop |
    Select-Object AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated,QuickScanEndTime,FullScanEndTime
} catch {}

[ordered]@{
  cpuPercent = $cpu
  ramTotalKb = $os.TotalVisibleMemorySize
  ramFreeKb = $os.FreePhysicalMemory
  gpus = $gpus
  battery = $battery
  defender = $defender
} | ConvertTo-Json -Depth 5 -Compress
''';

  Future<AmbientSnapshot?> fetch() async {
    final result = await PowerShellRunner.run(_script);
    if (!result.ok || result.stdout.trim().isEmpty) return null;
    try {
      return parse(result.stdout);
    } catch (_) {
      return null;
    }
  }

  /// Pure parse of the script's JSON output — split out so it can be tested
  /// against captured real output without spawning PowerShell.
  static AmbientSnapshot parse(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;

    SystemUsage? usage;
    final cpu = map['cpuPercent'];
    final totalKb = map['ramTotalKb'];
    final freeKb = map['ramFreeKb'];
    if (cpu != null && totalKb != null && freeKb != null) {
      final totalGb = (totalKb as num) / 1048576;
      final freeGb = (freeKb as num) / 1048576;
      usage = SystemUsage(
        cpuPercent: (cpu as num).toDouble(),
        ramUsedGb: totalGb - freeGb,
        ramTotalGb: totalGb,
      );
    }

    final gpuList = (map['gpus'] as List?) ?? const [];
    final gpus = gpuList.whereType<Map<String, dynamic>>().map((g) {
      return GpuInfo(
        name: (g['Name'] as String?)?.trim() ?? 'Unknown GPU',
        driverVersion: (g['DriverVersion'] as String?)?.trim() ?? 'Unknown',
        driverDate: parseCimDate(g['DriverDate']),
        vramBytes: (g['AdapterRAM'] as num?)?.toInt(),
      );
    }).toList();

    final batteryList = (map['battery'] as List?) ?? const [];
    final battery = batteryList.isEmpty
        ? const BatteryInfo(present: false)
        : () {
            final b = batteryList.first as Map<String, dynamic>;
            return BatteryInfo(
              present: true,
              chargePercent: (b['EstimatedChargeRemaining'] as num?)?.toInt(),
              statusLabel: _batteryStatusLabel(
                (b['BatteryStatus'] as num?)?.toInt(),
              ),
            );
          }();

    DefenderStatus? defender;
    final defenderMap = map['defender'];
    if (defenderMap is Map<String, dynamic>) {
      defender = DefenderStatus(
        antivirusEnabled: defenderMap['AntivirusEnabled'] == true,
        realTimeProtectionEnabled:
            defenderMap['RealTimeProtectionEnabled'] == true,
        signatureLastUpdated:
            parseCimDate(defenderMap['AntivirusSignatureLastUpdated']),
        lastQuickScan: parseCimDate(defenderMap['QuickScanEndTime']),
        lastFullScan: parseCimDate(defenderMap['FullScanEndTime']),
      );
    }

    return AmbientSnapshot(
      usage: usage,
      gpus: gpus,
      battery: battery,
      defender: defender,
    );
  }

  static String? _batteryStatusLabel(int? code) => switch (code) {
        1 => 'Discharging',
        2 => 'On AC power',
        3 => 'Fully charged',
        4 => 'Low',
        5 => 'Critical',
        6 || 7 || 8 || 9 => 'Charging',
        11 => 'Partially charged',
        _ => null,
      };
}
