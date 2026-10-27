import 'dart:convert';
import 'dart:io';

/// What sits behind each admin metrics tile: per-process CPU / RAM / disk,
/// per-interface network and per-disk throughput, plus the CPU time split.
///
/// In Docker, the container's own `/proc` only lists the luma-sync
/// container's processes while `/proc/stat` is host-wide, so a 90% CPU tile
/// would have no visible culprit. docker-compose mounts the host's `/proc`
/// read-only at `/host/proc` (`LUMA_HOST_PROC`) so the breakdown covers the
/// whole machine.
class ProcessBreakdown {
  const ProcessBreakdown({
    required this.platformSupported,
    this.scope = 'host',
    this.sampleSeconds = 0,
    this.cpuStates = const [],
    this.processes = const [],
    this.processIoAvailable = false,
    this.interfaces = const [],
    this.disks = const [],
    this.ramTotalBytes,
  });

  final bool platformSupported;

  /// 'host' when every process on the machine is visible, 'container' when
  /// only this container's are.
  final String scope;
  final double sampleSeconds;
  final List<CpuState> cpuStates;
  final List<ProcessUsage> processes;

  /// Per-process disk counters need ptrace-level access to other users'
  /// processes, which a confined container usually lacks.
  final bool processIoAvailable;
  final List<ThroughputRow> interfaces;
  final List<ThroughputRow> disks;
  final int? ramTotalBytes;

  Map<String, dynamic> toJson() => {
        'platformSupported': platformSupported,
        'scope': scope,
        'sampleSeconds': sampleSeconds,
        'cpuStates': [for (final s in cpuStates) s.toJson()],
        'processes': [for (final p in processes) p.toJson()],
        'processIoAvailable': processIoAvailable,
        'interfaces': [for (final i in interfaces) i.toJson()],
        'disks': [for (final d in disks) d.toJson()],
        'ramTotalBytes': ramTotalBytes,
      };

  static Future<ProcessBreakdown> sample({
    Duration window = const Duration(seconds: 1),
  }) async {
    try {
      if (Platform.isLinux) return await _sampleLinux(window);
      if (Platform.isWindows) return await _sampleWindows();
    } catch (_) {
      // Fall through to "unsupported" below.
    }
    return const ProcessBreakdown(platformSupported: false);
  }

  static Future<ProcessBreakdown> _sampleLinux(Duration window) async {
    final hostProc = Platform.environment['LUMA_HOST_PROC'] ?? '/host/proc';
    final useHost = File('$hostProc/stat').existsSync();
    final root = useHost ? hostProc : '/proc';
    final inContainer = !useHost && File('/.dockerenv').existsSync();
    final clock = Stopwatch()..start();
    final before = ProcSnapshot.read(root, elapsedUs: 0);
    await Future<void>.delayed(window);
    final after =
        ProcSnapshot.read(root, elapsedUs: clock.elapsedMicroseconds);
    return compare(before, after, scope: inContainer ? 'container' : 'host');
  }

  /// Turns two snapshots of cumulative counters into rates and shares.
  static ProcessBreakdown compare(
    ProcSnapshot before,
    ProcSnapshot after, {
    String scope = 'host',
  }) {
    final seconds = (after.elapsedUs - before.elapsedUs) / 1000000;
    double? rate(int? a, int? b) {
      if (a == null || b == null || b < a || seconds <= 0) return null;
      return (b - a) / seconds;
    }

    final cpuDeltas = <int>[
      for (var i = 0;
          i < after.cpuFields.length && i < before.cpuFields.length;
          i++)
        after.cpuFields[i] - before.cpuFields[i],
    ];
    final totalTicks = cpuDeltas.take(8).fold<int>(0, (a, b) => a + b);
    const stateNames = [
      'User',
      'Nice',
      'System',
      'Idle',
      'I/O wait',
      'IRQ',
      'Soft IRQ',
      'Steal',
    ];
    final cpuStates = <CpuState>[
      if (totalTicks > 0)
        for (var i = 0; i < cpuDeltas.length && i < stateNames.length; i++)
          CpuState(stateNames[i], cpuDeltas[i] / totalTicks * 100),
    ];

    var ioReadable = 0;
    final processes = <ProcessUsage>[];
    for (final p in after.processes.values) {
      final prev = before.processes[p.pid];
      final ticks = prev == null || p.cpuTicks < prev.cpuTicks
          ? null
          : p.cpuTicks - prev.cpuTicks;
      if (p.readBytes != null) ioReadable++;
      processes.add(ProcessUsage(
        pid: p.pid,
        name: p.name,
        command: p.command,
        parentName: after.processes[p.ppid]?.name,
        container: p.container,
        description: describeProcess(p.name, p.command, p.uid),
        cpuPercent: ticks == null || totalTicks <= 0
            ? null
            : (ticks / totalTicks * 100).clamp(0, 100).toDouble(),
        ramBytes: p.rssBytes,
        readBytesPerSec: rate(prev?.readBytes, p.readBytes),
        writeBytesPerSec: rate(prev?.writeBytes, p.writeBytes),
      ));
    }

    List<ThroughputRow> rows(
      Map<String, (int, int)> a,
      Map<String, (int, int)> b,
    ) =>
        [
          for (final e in b.entries)
            if (a[e.key] != null)
              ThroughputRow(
                e.key,
                rate(a[e.key]!.$1, e.value.$1),
                rate(a[e.key]!.$2, e.value.$2),
              ),
        ];

    return ProcessBreakdown(
      platformSupported: true,
      scope: scope,
      sampleSeconds: seconds,
      cpuStates: cpuStates,
      processes: processes,
      processIoAvailable:
          ioReadable > after.processes.length / 2 && ioReadable > 0,
      interfaces: rows(before.interfaces, after.interfaces),
      disks: rows(before.disks, after.disks),
      ramTotalBytes: after.ramTotalBytes,
    );
  }

  // ---- Windows: the PerfProc counters already report rates ----

  static Future<ProcessBreakdown> _sampleWindows() async {
    const script = r'''
$ErrorActionPreference = 'SilentlyContinue'
$cores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$cmd = @{}; $parent = @{}
Get-CimInstance Win32_Process | ForEach-Object {
  $cmd[[int]$_.ProcessId] = $_.CommandLine
  $parent[[int]$_.ProcessId] = [int]$_.ParentProcessId
}
$raw = @(Get-CimInstance Win32_PerfFormattedData_PerfProc_Process |
  Where-Object { $_.Name -ne '_Total' -and $_.Name -ne 'Idle' })
$names = @{}
foreach ($r in $raw) { $names[[int]$r.IDProcess] = ($r.Name -replace '#\d+$', '') }
$procs = $raw | ForEach-Object {
    $id = [int]$_.IDProcess
    [PSCustomObject]@{
      pid = $id
      name = ($_.Name -replace '#\d+$', '')
      command = $cmd[$id]
      parent = $names[$parent[$id]]
      cpu = [double]$_.PercentProcessorTime / [Math]::Max(1, $cores)
      ram = [long]$_.WorkingSetPrivate
      read = [double]$_.IOReadBytesPersec
      write = [double]$_.IOWriteBytesPersec
    }
  }
$cpu = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor |
  Where-Object { $_.Name -eq '_Total' }
$net = Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface |
  Where-Object { $_.Name -notmatch 'Loopback|isatap|Teredo' } |
  ForEach-Object { [PSCustomObject]@{ name = $_.Name; a = [double]$_.BytesReceivedPersec; b = [double]$_.BytesSentPersec } }
$disk = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk |
  Where-Object { $_.Name -ne '_Total' } |
  ForEach-Object { [PSCustomObject]@{ name = $_.Name; a = [double]$_.DiskReadBytesPersec; b = [double]$_.DiskWriteBytesPersec } }
$os = Get-CimInstance Win32_OperatingSystem
[PSCustomObject]@{
  processes = @($procs)
  user = $cpu.PercentUserTime
  system = $cpu.PercentPrivilegedTime
  irq = $cpu.PercentInterruptTime
  idle = $cpu.PercentIdleTime
  net = @($net)
  disk = @($disk)
  totalKb = $os.TotalVisibleMemorySize
} | ConvertTo-Json -Compress -Depth 4
''';
    final result = await Process.run(
        'powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
    final stdout = result.stdout as String;
    if (result.exitCode != 0 || stdout.trim().isEmpty) {
      return const ProcessBreakdown(platformSupported: false);
    }
    final decoded = jsonDecode(stdout) as Map<String, dynamic>;
    double? d(Object? v) => v is num ? v.toDouble() : null;
    List<Map<String, dynamic>> list(Object? v) => [
          if (v is List)
            for (final e in v)
              if (e is Map<String, dynamic>) e,
        ];
    List<ThroughputRow> rows(Object? v) => [
          for (final r in list(v))
            ThroughputRow('${r['name']}', d(r['a']), d(r['b'])),
        ];
    final totalKb = d(decoded['totalKb']);
    return ProcessBreakdown(
      platformSupported: true,
      cpuStates: [
        CpuState('User', d(decoded['user']) ?? 0),
        CpuState('System', d(decoded['system']) ?? 0),
        CpuState('IRQ', d(decoded['irq']) ?? 0),
        CpuState('Idle', d(decoded['idle']) ?? 0),
      ],
      processes: [
        for (final p in list(decoded['processes']))
          ProcessUsage(
            pid: (p['pid'] as num).toInt(),
            name: '${p['name']}',
            command: p['command'] as String?,
            parentName: p['parent'] as String?,
            description: describeProcess(
                '${p['name']}', p['command'] as String?, null),
            cpuPercent: d(p['cpu'])?.clamp(0, 100).toDouble(),
            ramBytes: (p['ram'] as num?)?.toInt(),
            readBytesPerSec: d(p['read']),
            writeBytesPerSec: d(p['write']),
          ),
      ],
      processIoAvailable: true,
      interfaces: rows(decoded['net']),
      disks: rows(decoded['disk']),
      ramTotalBytes: totalKb == null ? null : (totalKb * 1024).toInt(),
    );
  }
}

class CpuState {
  const CpuState(this.label, this.percent);
  final String label;
  final double percent;
  Map<String, dynamic> toJson() => {'label': label, 'percent': percent};
}

class ProcessUsage {
  const ProcessUsage({
    required this.pid,
    required this.name,
    this.command,
    this.parentName,
    this.container,
    this.description,
    this.cpuPercent,
    this.ramBytes,
    this.readBytesPerSec,
    this.writeBytesPerSec,
  });

  final int pid;
  final String name;
  final String? command;
  final String? parentName;

  /// Short Docker container id, when the process runs in one.
  final String? container;

  /// A plain-language note on what this process is, for the ones luma's
  /// own stack runs (see [describeProcess]).
  final String? description;

  /// Share of the whole machine (all cores), like the CPU tile.
  final double? cpuPercent;
  final int? ramBytes;
  final double? readBytesPerSec;
  final double? writeBytesPerSec;

  Map<String, dynamic> toJson() => {
        'pid': pid,
        'name': name,
        'command': command,
        'parent': parentName,
        'container': container,
        'description': description,
        'cpuPercent': cpuPercent,
        'ramBytes': ramBytes,
        'readBytesPerSec': readBytesPerSec,
        'writeBytesPerSec': writeBytesPerSec,
      };
}

class ThroughputRow {
  const ThroughputRow(this.name, this.inPerSec, this.outPerSec);
  final String name;

  /// Received for an interface, read for a disk.
  final double? inPerSec;

  /// Sent for an interface, written for a disk.
  final double? outPerSec;

  Map<String, dynamic> toJson() =>
      {'name': name, 'in': inPerSec, 'out': outPerSec};
}

/// The renderer image runs as this uid (see Renderer.Dockerfile).
const kRendererUid = 10001;

/// Names the parts of luma's own stack, so "chromium at 90%" reads as
/// "the benchmark renderer" rather than a mystery browser on a server.
String? describeProcess(String name, String? command, int? uid) {
  final n = name.toLowerCase();
  final cmd = (command ?? '').toLowerCase();
  if (n.contains('chrom') || n == 'headless_shell') {
    if (uid == kRendererUid || cmd.contains('/tmp/chromium')) {
      return 'luma renderer container: headless Chromium that screenshots '
          'AI benchmark scenes and previews';
    }
    return 'Chromium browser';
  }
  if (n == 'node' && cmd.contains('renderer_service')) {
    return 'luma renderer container: the service that drives Chromium';
  }
  if (n == 'node' && uid == kRendererUid) {
    return 'luma renderer container';
  }
  if (n.startsWith('luma_server')) return 'luma sync server (this server)';
  if (n == 'caddy') return 'Caddy reverse proxy (HTTPS in front of luma)';
  if (n == 'cloudflared') return 'Cloudflare Tunnel';
  if (cmd.contains('searx') || n == 'granian' || n == 'uwsgi') {
    return 'SearXNG web search container';
  }
  if (n == 'dockerd' || n.startsWith('containerd')) return 'Docker engine';
  if (n.startsWith('kworker') ||
      n.startsWith('ksoftirqd') ||
      n.startsWith('kswapd') ||
      n.startsWith('rcu_')) {
    return 'Linux kernel worker';
  }
  return null;
}

class ProcSample {
  const ProcSample({
    required this.pid,
    required this.ppid,
    required this.name,
    required this.cpuTicks,
    this.command,
    this.rssBytes,
    this.uid,
    this.container,
    this.readBytes,
    this.writeBytes,
  });

  final int pid;
  final int ppid;
  final String name;
  final int cpuTicks;
  final String? command;
  final int? rssBytes;
  final int? uid;
  final String? container;
  final int? readBytes;
  final int? writeBytes;
}

/// Cumulative counters read from one procfs at one moment.
class ProcSnapshot {
  const ProcSnapshot({
    required this.elapsedUs,
    required this.cpuFields,
    required this.processes,
    required this.interfaces,
    required this.disks,
    this.ramTotalBytes,
  });

  final int elapsedUs;

  /// The aggregate `cpu` line of /proc/stat: user nice system idle iowait
  /// irq softirq steal (guest time is already counted in user/nice).
  final List<int> cpuFields;
  final Map<int, ProcSample> processes;

  /// name → (rx bytes, tx bytes).
  final Map<String, (int, int)> interfaces;

  /// name → (read bytes, written bytes).
  final Map<String, (int, int)> disks;
  final int? ramTotalBytes;

  static const _pageSize = 4096;
  static final _wholeDisk =
      RegExp(r'^(sd[a-z]+|vd[a-z]+|xvd[a-z]+|nvme\d+n\d+|mmcblk\d+)$');
  static final _docker = RegExp(r'docker[-/]([0-9a-f]{12})');

  static ProcSnapshot read(String root, {required int elapsedUs}) {
    List<int> cpu = const [];
    try {
      final line = File('$root/stat').readAsLinesSync().first;
      cpu = line
          .trim()
          .split(RegExp(r'\s+'))
          .skip(1)
          .take(8)
          .map(int.parse)
          .toList(growable: false);
    } catch (_) {}

    final processes = <int, ProcSample>{};
    try {
      for (final entity in Directory(root).listSync(followLinks: false)) {
        final pid = int.tryParse(entity.uri.pathSegments
            .lastWhere((s) => s.isNotEmpty, orElse: () => ''));
        if (pid == null) continue;
        final sample = _readProcess(root, pid);
        if (sample != null) processes[pid] = sample;
      }
    } catch (_) {}

    // In the host procfs, pid 1 sits in the host's network namespace;
    // `net/dev` alone would resolve through `self` to this container's.
    var interfaces = _readNetDev('$root/1/net/dev');
    if (interfaces.isEmpty) interfaces = _readNetDev('$root/net/dev');

    final disks = <String, (int, int)>{};
    try {
      for (final line in File('$root/diskstats').readAsLinesSync()) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 14 || !_wholeDisk.hasMatch(parts[2])) continue;
        disks[parts[2]] = (
          (int.tryParse(parts[5]) ?? 0) * 512,
          (int.tryParse(parts[9]) ?? 0) * 512,
        );
      }
    } catch (_) {}

    int? ramTotal;
    try {
      for (final line in File('$root/meminfo').readAsLinesSync()) {
        if (line.startsWith('MemTotal:')) {
          ramTotal =
              int.parse(RegExp(r'\d+').firstMatch(line)!.group(0)!) * 1024;
          break;
        }
      }
    } catch (_) {}

    return ProcSnapshot(
      elapsedUs: elapsedUs,
      cpuFields: cpu,
      processes: processes,
      interfaces: interfaces,
      disks: disks,
      ramTotalBytes: ramTotal,
    );
  }

  static ProcSample? _readProcess(String root, int pid) {
    final dir = '$root/$pid';
    String stat;
    try {
      stat = File('$dir/stat').readAsStringSync();
    } catch (_) {
      return null;
    }
    // The name is in parentheses and may itself contain spaces or ')'.
    final open = stat.indexOf('(');
    final close = stat.lastIndexOf(')');
    if (open < 0 || close < open) return null;
    final name = stat.substring(open + 1, close);
    final f = stat.substring(close + 1).trim().split(' ');
    if (f.length < 22) return null;
    // f[0] is field 3 (state): ppid is field 4, utime/stime 14/15, rss 24.
    final ppid = int.tryParse(f[1]) ?? 0;
    final ticks = (int.tryParse(f[11]) ?? 0) + (int.tryParse(f[12]) ?? 0);
    final rssPages = int.tryParse(f[21]);

    String? command;
    try {
      final raw = File('$dir/cmdline').readAsBytesSync();
      if (raw.isNotEmpty) {
        command = redactCommandLine(utf8
            .decode(raw, allowMalformed: true)
            .replaceAll('\u0000', ' ')
            .trim());
        if (command.length > 400) command = command.substring(0, 400);
      }
    } catch (_) {}

    int? uid;
    try {
      for (final line in File('$dir/status').readAsLinesSync()) {
        if (line.startsWith('Uid:')) {
          uid = int.tryParse(line.split(RegExp(r'\s+'))[1]);
          break;
        }
      }
    } catch (_) {}

    String? container;
    try {
      container =
          _docker.firstMatch(File('$dir/cgroup').readAsStringSync())?.group(1);
    } catch (_) {}

    int? readBytes, writeBytes;
    try {
      for (final line in File('$dir/io').readAsLinesSync()) {
        if (line.startsWith('read_bytes:')) {
          readBytes = int.tryParse(line.substring(11).trim());
        } else if (line.startsWith('write_bytes:')) {
          writeBytes = int.tryParse(line.substring(12).trim());
        }
      }
    } catch (_) {}

    return ProcSample(
      pid: pid,
      ppid: ppid,
      name: name,
      cpuTicks: ticks,
      command: command,
      rssBytes: rssPages == null ? null : rssPages * _pageSize,
      uid: uid,
      container: container,
      readBytes: readBytes,
      writeBytes: writeBytes,
    );
  }

  static Map<String, (int, int)> _readNetDev(String path) {
    final out = <String, (int, int)>{};
    try {
      for (final line in File(path).readAsLinesSync().skip(2)) {
        final colon = line.indexOf(':');
        if (colon < 0) continue;
        final name = line.substring(0, colon).trim();
        if (name == 'lo') continue;
        final parts = line.substring(colon + 1).trim().split(RegExp(r'\s+'));
        if (parts.length < 9) continue;
        out[name] = (int.tryParse(parts[0]) ?? 0, int.tryParse(parts[8]) ?? 0);
      }
    } catch (_) {}
    return out;
  }
}

final _secretName = RegExp(
    r'(token|secret|passw(or)?d|passwd|pwd|api[_-]?key|access[_-]?key|'
    r'private[_-]?key|auth|credential|cookie|session)',
    caseSensitive: false);
final _flagWithValue = RegExp(r'^(--?[\w.-]+)=(.+)$');
final _envAssignment = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)=(.+)$');
final _urlCredentials =
    RegExp(r'([a-z][a-z0-9+.-]*://)[^/\s:@]+:[^/\s@]+@', caseSensitive: false);

/// Masks what looks like a secret in a host process's command line before
/// the admin Metrics tab shows it: `--token X`, `--api-key=X`, `PASSWORD=X`
/// and `scheme://user:pass@host`. Host processes pass secrets this way
/// (e.g. `cloudflared tunnel run --token ...`), and the dashboard is the last
/// place they should end up readable.
String redactCommandLine(String command) {
  final parts = command.split(' ');
  for (var i = 0; i < parts.length; i++) {
    final part =
        parts[i].replaceAllMapped(_urlCredentials, (m) => '${m[1]}***@');
    parts[i] = part;
    final flag = _flagWithValue.firstMatch(part);
    if (flag != null) {
      if (_secretName.hasMatch(flag[1]!)) parts[i] = '${flag[1]}=***';
      continue;
    }
    final env = _envAssignment.firstMatch(part);
    if (env != null) {
      if (_secretName.hasMatch(env[1]!)) parts[i] = '${env[1]}=***';
      continue;
    }
    if (part.startsWith('-') &&
        _secretName.hasMatch(part) &&
        i + 1 < parts.length &&
        !parts[i + 1].startsWith('-')) {
      parts[i + 1] = '***';
      i++;
    }
  }
  return parts.join(' ');
}
