import 'dart:convert';
import 'dart:io';

/// A best-effort snapshot of host resource usage for the admin dashboard.
/// Every field is nullable — when a metric can't be read on this platform
/// it's simply omitted rather than faked.
class SystemMetrics {
  const SystemMetrics({
    required this.platformSupported,
    this.cpuPercent,
    this.ramUsedBytes,
    this.ramTotalBytes,
    this.netRxBytesPerSec,
    this.netTxBytesPerSec,
    this.diskReadBytesPerSec,
    this.diskWriteBytesPerSec,
  });

  /// False when this OS has no metrics support at all (nothing below is
  /// worth trusting in that case).
  final bool platformSupported;
  final double? cpuPercent;
  final int? ramUsedBytes;
  final int? ramTotalBytes;
  final double? netRxBytesPerSec;
  final double? netTxBytesPerSec;
  final double? diskReadBytesPerSec;
  final double? diskWriteBytesPerSec;

  Map<String, dynamic> toJson() => {
        'platformSupported': platformSupported,
        'cpuPercent': cpuPercent,
        'ramUsedBytes': ramUsedBytes,
        'ramTotalBytes': ramTotalBytes,
        'netRxBytesPerSec': netRxBytesPerSec,
        'netTxBytesPerSec': netTxBytesPerSec,
        'diskReadBytesPerSec': diskReadBytesPerSec,
        'diskWriteBytesPerSec': diskWriteBytesPerSec,
      };

  /// Takes ~[interval] to complete on platforms that need two samples to
  /// derive a rate (CPU %, network and disk throughput on Linux).
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
    final disk1 = _readDiskTotals();
    await Future.delayed(interval);
    final cpu2 = _readProcStatTotals();
    final net2 = await _readNetTotals();
    final disk2 = _readDiskTotals();

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
    final seconds = interval.inMicroseconds / 1e6;

    double? rxRate, txRate;
    if (net1 != null && net2 != null) {
      rxRate = (net2.rx - net1.rx) / seconds;
      txRate = (net2.tx - net1.tx) / seconds;
    }

    double? readRate, writeRate;
    if (disk1 != null && disk2 != null) {
      readRate = (disk2.readBytes - disk1.readBytes) / seconds;
      writeRate = (disk2.writeBytes - disk1.writeBytes) / seconds;
    }

    return SystemMetrics(
      platformSupported: true,
      cpuPercent: cpuPercent,
      ramUsedBytes: mem?.usedBytes,
      ramTotalBytes: mem?.totalBytes,
      netRxBytesPerSec: rxRate,
      netTxBytesPerSec: txRate,
      diskReadBytesPerSec: readRate,
      diskWriteBytesPerSec: writeRate,
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

  /// Sums sectors read/written across whole-disk devices from
  /// /proc/diskstats (fields 6 and 10, 1-indexed; sectors are always 512
  /// bytes regardless of the disk's real block size). Skips partitions
  /// (trailing digits after a letter device name, e.g. sda1) and virtual
  /// devices (loop/ram/dm/md) so a single physical write isn't double
  /// counted via both the disk and its partition.
  static ({int readBytes, int writeBytes})? _readDiskTotals() {
    try {
      final file = File('/proc/diskstats');
      if (!file.existsSync()) return null;
      var readSectors = 0, writeSectors = 0;
      final wholeDisk = RegExp(r'^(sd[a-z]+|vd[a-z]+|xvd[a-z]+|nvme\d+n\d+)$');
      for (final line in file.readAsLinesSync()) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 14) continue;
        final name = parts[2];
        if (!wholeDisk.hasMatch(name)) continue;
        readSectors += int.tryParse(parts[5]) ?? 0;
        writeSectors += int.tryParse(parts[9]) ?? 0;
      }
      return (readBytes: readSectors * 512, writeBytes: writeSectors * 512);
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
$disk = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk |
    Where-Object { $_.Name -eq '_Total' }
[PSCustomObject]@{
  cpu = $cpu
  totalKb = $os.TotalVisibleMemorySize
  freeKb = $os.FreePhysicalMemory
  rx = $rx
  tx = $tx
  diskRead = $disk.DiskReadBytesPersec
  diskWrite = $disk.DiskWriteBytesPersec
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
      diskReadBytesPerSec: asDouble(decoded['diskRead']),
      diskWriteBytesPerSec: asDouble(decoded['diskWrite']),
    );
  }
}
