import 'dart:convert';
import 'dart:io';

/// A best-effort snapshot of host resource usage for the admin dashboard.
/// Every field is nullable — when a metric can't be read on this platform
/// (or at all, as with power draw on most machines) it's simply omitted
/// rather than faked.
class SystemMetrics {
  const SystemMetrics({
    required this.platformSupported,
    this.cpuPercent,
    this.ramUsedBytes,
    this.ramTotalBytes,
    this.netRxBytesPerSec,
    this.netTxBytesPerSec,
    this.powerWatts,
  });

  /// False when this OS has no metrics support at all (nothing below is
  /// worth trusting in that case).
  final bool platformSupported;
  final double? cpuPercent;
  final int? ramUsedBytes;
  final int? ramTotalBytes;
  final double? netRxBytesPerSec;
  final double? netTxBytesPerSec;
  final double? powerWatts;

  Map<String, dynamic> toJson() => {
        'platformSupported': platformSupported,
        'cpuPercent': cpuPercent,
        'ramUsedBytes': ramUsedBytes,
        'ramTotalBytes': ramTotalBytes,
        'netRxBytesPerSec': netRxBytesPerSec,
        'netTxBytesPerSec': netTxBytesPerSec,
        'powerWatts': powerWatts,
      };

  /// Takes ~[interval] to complete on platforms that need two samples to
  /// derive a rate (CPU %, network throughput, RAPL power on Linux).
  static Future<SystemMetrics> sample(
      {Duration interval = const Duration(milliseconds: 400)}) async {
    try {
      if (Platform.isLinux) return _sampleLinux(interval);
      if (Platform.isWindows) return _sampleWindows();
    } catch (_) {
      // Fall through to "unsupported" below.
    }
    return const SystemMetrics(platformSupported: false);
  }

  // ---- Linux: /proc and /sys are the standard, dependency-free source ----

  static Future<SystemMetrics> _sampleLinux(Duration interval) async {
    final cpu1 = _readProcStatTotals();
    final net1 = await _readNetTotals();
    await Future.delayed(interval);
    final cpu2 = _readProcStatTotals();
    final net2 = await _readNetTotals();
    final power = await _readRaplPower(interval);

    double? cpuPercent;
    if (cpu1 != null && cpu2 != null) {
      final totalDelta = cpu2.total - cpu1.total;
      final idleDelta = cpu2.idle - cpu1.idle;
      if (totalDelta > 0) {
        cpuPercent =
            ((totalDelta - idleDelta) / totalDelta * 100).clamp(0, 100);
      }
    }

    final mem = _readMemInfo();

    double? rxRate, txRate;
    if (net1 != null && net2 != null) {
      final seconds = interval.inMicroseconds / 1e6;
      rxRate = (net2.rx - net1.rx) / seconds;
      txRate = (net2.tx - net1.tx) / seconds;
    }

    return SystemMetrics(
      platformSupported: true,
      cpuPercent: cpuPercent,
      ramUsedBytes: mem?.usedBytes,
      ramTotalBytes: mem?.totalBytes,
      netRxBytesPerSec: rxRate,
      netTxBytesPerSec: txRate,
      powerWatts: power,
    );
  }

  static ({int total, int idle})? _readProcStatTotals() {
    try {
      final line = File('/proc/stat').readAsLinesSync().first;
      final parts = line
          .trim()
          .split(RegExp(r'\s+'))
          .skip(1)
          .map(int.parse)
          .toList(growable: false);
      // user nice system idle iowait irq softirq steal guest guest_nice
      final idle = parts[3] + (parts.length > 4 ? parts[4] : 0);
      final total = parts.fold<int>(0, (a, b) => a + b);
      return (total: total, idle: idle);
    } catch (_) {
      return null;
    }
  }

  static ({int usedBytes, int totalBytes})? _readMemInfo() {
    try {
      int? totalKb, availKb;
      for (final line in File('/proc/meminfo').readAsLinesSync()) {
        if (line.startsWith('MemTotal:')) {
          totalKb = int.parse(RegExp(r'\d+').firstMatch(line)!.group(0)!);
        } else if (line.startsWith('MemAvailable:')) {
          availKb = int.parse(RegExp(r'\d+').firstMatch(line)!.group(0)!);
        }
        if (totalKb != null && availKb != null) break;
      }
      if (totalKb == null || availKb == null) return null;
      return (
        usedBytes: (totalKb - availKb) * 1024,
        totalBytes: totalKb * 1024,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sums rx/tx across every non-loopback interface.
  static Future<({int rx, int tx})?> _readNetTotals() async {
    try {
      final dir = Directory('/sys/class/net');
      if (!await dir.exists()) return null;
      var rx = 0, tx = 0;
      await for (final entity in dir.list()) {
        final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        if (name == 'lo') continue;
        final rxFile = File('${entity.path}/statistics/rx_bytes');
        final txFile = File('${entity.path}/statistics/tx_bytes');
        if (await rxFile.exists() && await txFile.exists()) {
          rx += int.tryParse((await rxFile.readAsString()).trim()) ?? 0;
          tx += int.tryParse((await txFile.readAsString()).trim()) ?? 0;
        }
      }
      return (rx: rx, tx: tx);
    } catch (_) {
      return null;
    }
  }

  /// Intel RAPL energy counters, present on most bare-metal x86 hosts (not
  /// typically exposed inside a VPS/VM) — the only widely-available source
  /// of real power-draw data without extra hardware or root tools.
  static Future<double?> _readRaplPower(Duration interval) async {
    final file = File('/sys/class/powercap/intel-rapl:0/energy_uj');
    try {
      if (!await file.exists()) return null;
      final e1 = int.parse((await file.readAsString()).trim());
      await Future.delayed(interval);
      final e2 = int.parse((await file.readAsString()).trim());
      final deltaUj = e2 - e1;
      if (deltaUj < 0) return null; // counter wrapped around
      final seconds = interval.inMicroseconds / 1e6;
      return deltaUj / 1e6 / seconds;
    } catch (_) {
      return null;
    }
  }

  // ---- Windows: WMI/CIM class and property names are always English,
  // unlike `Get-Counter` paths (e.g. "% Processor Time"), which are
  // localized and silently fail to resolve on non-English Windows installs.
  // The `*FormattedData*` classes already report rates, so one shot suffices.

  static Future<SystemMetrics> _sampleWindows() async {
    const script = r'''
$ErrorActionPreference = 'SilentlyContinue'
$cpu = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor |
    Where-Object { $_.Name -eq '_Total' }).PercentProcessorTime
$os = Get-CimInstance Win32_OperatingSystem
$net = Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface |
    Where-Object { $_.Name -notmatch 'Loopback|isatap|Teredo' }
$rx = ($net | Measure-Object -Property BytesReceivedPersec -Sum).Sum
$tx = ($net | Measure-Object -Property BytesSentPersec -Sum).Sum
[PSCustomObject]@{
  cpu = $cpu
  totalKb = $os.TotalVisibleMemorySize
  freeKb = $os.FreePhysicalMemory
  rx = $rx
  tx = $tx
} | ConvertTo-Json -Compress
''';
    final result = await Process.run(
        'powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
    final stdout = result.stdout as String;
    if (result.exitCode != 0 || stdout.trim().isEmpty) {
      return const SystemMetrics(platformSupported: false);
    }
    final decoded = jsonDecode(stdout) as Map<String, dynamic>;

    double? asDouble(Object? v) => v == null ? null : (v as num).toDouble();
    int? asInt(Object? v) => v == null ? null : (v as num).toInt();

    final totalKb = asInt(decoded['totalKb']);
    final freeKb = asInt(decoded['freeKb']);

    return SystemMetrics(
      platformSupported: true,
      cpuPercent: asDouble(decoded['cpu'])?.clamp(0, 100),
      ramTotalBytes: totalKb == null ? null : totalKb * 1024,
      ramUsedBytes:
          (totalKb == null || freeKb == null) ? null : (totalKb - freeKb) * 1024,
      netRxBytesPerSec: asDouble(decoded['rx']),
      netTxBytesPerSec: asDouble(decoded['tx']),
      // No reliable cross-vendor watts sensor on Windows.
      powerWatts: null,
    );
  }
}
