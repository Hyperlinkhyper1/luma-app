import 'dart:convert';
import 'dart:io';

import '../device_health_models.dart';
import 'bloatware_catalog.dart';
import 'powershell_runner.dart';

/// Lists running processes and ends one by PID.
///
/// CPU% needs two time-spaced samples (a single `Get-Process` call only ever
/// gives cumulative CPU-seconds since the process started, not an
/// instantaneous rate) — this takes two snapshots ~500ms apart in one
/// PowerShell invocation and computes the delta itself, the same technique
/// Task Manager uses.
class ProcessService {
  const ProcessService();

  static const _script = r'''
$cores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
if (-not $cores -or $cores -lt 1) { $cores = 1 }

$s1 = Get-Process | Select-Object Id, ProcessName, CPU, WorkingSet, Path
Start-Sleep -Milliseconds 500
$s2 = Get-Process | Select-Object Id, ProcessName, CPU, WorkingSet, Path

$prevCpu = @{}
foreach ($p in $s1) { $prevCpu[$p.Id] = $p.CPU }

$out = foreach ($p in $s2) {
  $prev = $prevCpu[$p.Id]
  $cpuPct = 0
  if ($null -ne $prev -and $null -ne $p.CPU) {
    $delta = $p.CPU - $prev
    if ($delta -lt 0) { $delta = 0 }
    $cpuPct = [Math]::Round(($delta / 0.5) / $cores * 100, 1)
  }
  [ordered]@{
    pid = $p.Id
    name = $p.ProcessName
    workingSet = $p.WorkingSet
    cpuPercent = $cpuPct
    path = $p.Path
  }
}
@($out) | ConvertTo-Json -Depth 3 -Compress
''';

  Future<List<ProcessInfo>?> list({BloatwareCatalog? bloatware}) async {
    final result = await PowerShellRunner.run(
      _script,
      timeout: const Duration(seconds: 10),
    );
    if (!result.ok || result.stdout.trim().isEmpty) return null;
    try {
      return parse(result.stdout, bloatware);
    } catch (_) {
      return null;
    }
  }

  static List<ProcessInfo> parse(String json, BloatwareCatalog? bloatware) {
    final decoded = jsonDecode(json);
    final list = decoded is List ? decoded : const [];
    final processes = list.whereType<Map<String, dynamic>>().map((p) {
      final name = (p['name'] as String?)?.trim() ?? 'Unknown';
      return ProcessInfo(
        pid: (p['pid'] as num).toInt(),
        name: name,
        workingSetBytes: (p['workingSet'] as num?)?.toInt() ?? 0,
        cpuPercent: (p['cpuPercent'] as num?)?.toDouble() ?? 0,
        path: p['path'] as String?,
        bloatware: bloatware?.match(name),
      );
    }).toList();
    processes.sort((a, b) => b.workingSetBytes.compareTo(a.workingSetBytes));
    return processes;
  }

  /// Ends the process. `dart:io`'s [Process.killPid] maps to
  /// `TerminateProcess` on Windows regardless of the signal passed, so no
  /// native/FFI call is needed for this.
  bool end(int pid) {
    try {
      return Process.killPid(pid, ProcessSignal.sigterm);
    } catch (_) {
      return false;
    }
  }
}
