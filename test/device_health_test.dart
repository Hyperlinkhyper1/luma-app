import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/device_health/device_health_models.dart';
import 'package:luma/features/plugins/installed/device_health/device_health_repository.dart';
import 'package:luma/features/plugins/installed/device_health/services/battery_report_service.dart';
import 'package:luma/features/plugins/installed/device_health/services/bloatware_catalog.dart';
import 'package:luma/features/plugins/installed/device_health/services/powershell_runner.dart';
import 'package:luma/features/plugins/installed/device_health/services/process_service.dart';
import 'package:luma/features/plugins/installed/device_health/services/system_stats_service.dart';
import 'package:luma/features/plugins/installed/device_health/services/winget_service.dart';

void main() {
  group('parseCimDate', () {
    test('parses a WCF/JSON.NET date', () {
      final dt = parseCimDate(r'/Date(1777507200000)/');
      expect(dt, DateTime.fromMillisecondsSinceEpoch(1777507200000, isUtc: true).toLocal());
    });

    test('returns null for null or unrecognized input', () {
      expect(parseCimDate(null), isNull);
      expect(parseCimDate('not a date'), isNull);
    });
  });

  group('SystemStatsService.parse', () {
    // Captured verbatim (values only, reshaped into the combined-script
    // schema) from `Get-CimInstance` on a real Windows 11 desktop with no
    // battery installed and Windows Defender active.
    const json = r'''
{
  "cpuPercent": 19,
  "ramTotalKb": 15847724,
  "ramFreeKb": 1903056,
  "gpus": [
    {"Name":"AMD Radeon RX 9060 XT","DriverVersion":"32.0.22042.14002","DriverDate":"\/Date(1777507200000)\/","AdapterRAM":4293918720},
    {"Name":"AMD Radeon(TM) Graphics","DriverVersion":"32.0.21042.62","DriverDate":"\/Date(1776384000000)\/","AdapterRAM":536870912}
  ],
  "battery": [],
  "defender": {"AntivirusEnabled":true,"RealTimeProtectionEnabled":true,"AntivirusSignatureLastUpdated":"\/Date(1788098627000)\/","QuickScanEndTime":"\/Date(1787910089607)\/","FullScanEndTime":null}
}
''';

    test('parses CPU/RAM into GB', () {
      final snapshot = SystemStatsService.parse(json);
      expect(snapshot.usage!.cpuPercent, 19);
      expect(snapshot.usage!.ramTotalGb, closeTo(15.11, 0.01));
      expect(snapshot.usage!.ramUsedGb, closeTo(13.30, 0.01));
    });

    test('parses both GPUs with vendor guess and driver date', () {
      final snapshot = SystemStatsService.parse(json);
      expect(snapshot.gpus, hasLength(2));
      expect(snapshot.gpus[0].name, 'AMD Radeon RX 9060 XT');
      expect(snapshot.gpus[0].vendor, 'AMD');
      expect(snapshot.gpus[0].driverDate,
          DateTime.fromMillisecondsSinceEpoch(1777507200000, isUtc: true).toLocal());
      expect(snapshot.gpus[0].vramBytes, 4293918720);
    });

    test('an empty Win32_Battery array means no battery present', () {
      expect(SystemStatsService.parse(json).battery.present, isFalse);
    });

    test('parses Defender status and derives lastScan from the newer of the two', () {
      final def = SystemStatsService.parse(json).defender!;
      expect(def.antivirusEnabled, isTrue);
      expect(def.realTimeProtectionEnabled, isTrue);
      expect(def.signatureLastUpdated,
          DateTime.fromMillisecondsSinceEpoch(1788098627000, isUtc: true).toLocal());
      expect(def.lastFullScan, isNull);
      expect(def.lastScan, def.lastQuickScan);
    });

    test('a present battery is parsed with charge and a friendly status label', () {
      // Synthetic — the machine this was captured on has no battery, but the
      // field names (EstimatedChargeRemaining/BatteryStatus) are the same
      // Win32_Battery properties queried live above.
      const withBattery = r'''
{"cpuPercent":5,"ramTotalKb":100,"ramFreeKb":50,"gpus":[],
 "battery":[{"EstimatedChargeRemaining":76,"BatteryStatus":6}],"defender":null}
''';
      final battery = SystemStatsService.parse(withBattery).battery;
      expect(battery.present, isTrue);
      expect(battery.chargePercent, 76);
      expect(battery.statusLabel, 'Charging');
    });

    test('a missing/disabled Defender module comes back as null, not an error', () {
      const noDefender = r'''
{"cpuPercent":1,"ramTotalKb":100,"ramFreeKb":50,"gpus":[],"battery":[],"defender":null}
''';
      expect(SystemStatsService.parse(noDefender).defender, isNull);
    });
  });

  group('ProcessService.parse', () {
    test('sorts by memory and attaches a bloatware match by process name', () {
      const json = r'''
[
  {"pid":17076,"name":"Discord","workingSet":611631104,"cpuPercent":2.4,"path":"C:\\Discord.exe"},
  {"pid":1,"name":"hpwuschd2","workingSet":10000000,"cpuPercent":0,"path":null},
  {"pid":18468,"name":"SignalRgb","workingSet":125599744,"cpuPercent":0.2,"path":"C:\\SignalRgb.exe"}
]
''';
      final catalog = BloatwareCatalog.parse(jsonEncode({
        'entries': [
          {'processName': 'hpwuschd2', 'label': 'HP Software Update', 'reason': 'Optional.'},
        ],
      }));
      final list = ProcessService.parse(json, catalog);
      expect(list.map((p) => p.name), ['Discord', 'SignalRgb', 'hpwuschd2']);
      expect(list.last.bloatware?.label, 'HP Software Update');
      expect(list.first.bloatware, isNull);
    });

    test('a null bloatware catalog just means no suggestions, not a crash', () {
      const json = r'[{"pid":1,"name":"anything","workingSet":1,"cpuPercent":0,"path":null}]';
      expect(ProcessService.parse(json, null).single.bloatware, isNull);
    });
  });

  group('WingetService.parseUpgradeList', () {
    // Captured verbatim from `winget upgrade --accept-source-agreements` on a
    // real machine — real package names, ids and the fixed-width column
    // layout this parser depends on.
    const stdout = 'Name                                              Id                                    Version        Available      Source\n'
        '-----------------------------------------------------------------------------------------------------------------------------\n'
        'Antigravity 2.8.1                                 Google.Antigravity                    2.8.1          2.11.0         winget\n'
        'App Installer                                     Microsoft.AppInstaller                1.29.289.0     1.29.290       winget\n'
        'Canva                                             XP8K17RNMM8MTN                        1.122.0        1.124.0        msstore\n'
        'cloudflared                                       Cloudflare.cloudflared                2026.7.1       2026.8.2       winget\n'
        'Git                                               Git.Git                               2.45.1         2.55.0.3       winget\n';

    test('parses every row with the right columns', () {
      final list = WingetService.parseUpgradeList(stdout);
      expect(list, hasLength(5));
      final antigravity = list[0];
      expect(antigravity.name, 'Antigravity 2.8.1');
      expect(antigravity.id, 'Google.Antigravity');
      expect(antigravity.currentVersion, '2.8.1');
      expect(antigravity.availableVersion, '2.11.0');
      expect(antigravity.source, UpdateSource.winget);
      expect(antigravity.silentEligible, isTrue);
    });

    test('an msstore-sourced package is not silent-eligible', () {
      final canva = WingetService.parseUpgradeList(stdout).firstWhere((a) => a.id == 'XP8K17RNMM8MTN');
      expect(canva.source, UpdateSource.msstore);
      expect(canva.silentEligible, isFalse);
    });

    test('output with no recognizable header parses as empty, not an error', () {
      expect(WingetService.parseUpgradeList('No applicable update found.\n'), isEmpty);
    });
  });

  group('BatteryReportService.parse', () {
    test('recognizes the real "no batteries" report text', () {
      // Captured verbatim from `powercfg /batteryreport` on a desktop.
      const html = '<div style="margin-top:1.5em;">'
          '<span class="nobatts">No batteries are currently installed</span></div>';
      expect(BatteryReportService.parse(html).present, isFalse);
    });

    test('extracts design and full-charge capacity in mWh', () {
      // Representative structure (no battery-equipped machine was available
      // to capture from) — the parser only depends on labels preceding their
      // mWh values in reading order, true of every powercfg layout.
      const html = '<h2>Installed batteries</h2><table>'
          '<tr><th>DESIGN CAPACITY</th><td>52,000 mWh</td></tr>'
          '<tr><th>FULL CHARGE CAPACITY</th><td>41,500 mWh</td></tr></table>';
      final wear = BatteryReportService.parse(html);
      expect(wear.present, isTrue);
      expect(wear.designCapacity, 52000);
      expect(wear.fullChargeCapacity, 41500);
    });
  });

  group('BatteryInfo.wearPercent', () {
    test('is the percentage of design capacity lost', () {
      const info = BatteryInfo(present: true, designCapacity: 52000, fullChargeCapacity: 41600);
      expect(info.wearPercent, closeTo(20, 0.01));
    });

    test('is null when either capacity figure is missing', () {
      const info = BatteryInfo(present: true, designCapacity: 52000);
      expect(info.wearPercent, isNull);
    });
  });

  group('BloatwareCatalog (real bundled asset)', () {
    final catalog = BloatwareCatalog.parse(
      File('assets/device_health/bloatware_processes.json').readAsStringSync(),
    );

    test('matches a known entry case-insensitively', () {
      expect(catalog.match('HPWUSCHD2')?.label, 'HP Software Update Scheduler');
    });

    test('does not match an unrelated process', () {
      expect(catalog.match('chrome'), isNull);
    });
  });

  group('PowerShellRunner on a non-Windows platform', () {
    test('run() reports unsupported rather than throwing', () async {
      // This suite runs on whatever host CI/dev uses; on Windows this simply
      // exercises the real `run` path (still safe — it runs a harmless
      // `Write-Output` — nothing under test here reaches the network or
      // modifies anything).
      final result = await PowerShellRunner.run('Write-Output "ok"');
      expect(result.exitCode, anyOf(0, -1));
    });
  });

  group('DeviceHealthRepository.computeScore', () {
    test('is unknown with a full 100 when nothing has been checked', () {
      final score = DeviceHealthRepository().computeScore();
      expect(score.status, HealthStatus.unknown);
      expect(score.checkedCategories, 0);
      expect(score.score, 100);
    });

    test('Defender being off is a severe, specifically-named deduction', () {
      final repo = DeviceHealthRepository()
        ..defender = HealthCategoryState(
          data: const DefenderStatus(antivirusEnabled: false, realTimeProtectionEnabled: false),
          checkedAt: DateTime.now(),
        );
      final score = repo.computeScore();
      expect(score.status, HealthStatus.bad);
      expect(score.issues, contains('Windows Defender protection is off.'));
      expect(score.score, 55); // 100 - 45
    });

    test('a desktop with no battery is neutral, not penalized', () {
      final repo = DeviceHealthRepository()
        ..battery = HealthCategoryState(
          data: const BatteryInfo(present: false),
          checkedAt: DateTime.now(),
        );
      final score = repo.computeScore();
      expect(score.checkedCategories, 1);
      expect(score.score, 100);
      expect(score.status, HealthStatus.good);
    });

    test('flagged bloatware and pending app updates both surface as issues', () {
      final repo = DeviceHealthRepository()
        ..processes = HealthCategoryState(
          data: const [
            ProcessInfo(pid: 1, name: 'a', workingSetBytes: 1, cpuPercent: 0,
                bloatware: BloatwareMatch(label: 'x', reason: 'y')),
            ProcessInfo(pid: 2, name: 'b', workingSetBytes: 1, cpuPercent: 0),
          ],
          checkedAt: DateTime.now(),
        )
        ..appUpdates = HealthCategoryState(
          data: const [
            AppUpdateInfo(id: 'a', name: 'A', currentVersion: '1', availableVersion: '2', source: UpdateSource.winget),
          ],
          checkedAt: DateTime.now(),
        );
      final score = repo.computeScore();
      expect(score.issues, contains('1 background app commonly flagged as unnecessary.'));
      expect(score.issues, contains('1 app update available.'));
    });
  });
}
