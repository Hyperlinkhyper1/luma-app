import 'dart:io';

import 'package:luma_sync_server/process_metrics.dart';
import 'package:test/test.dart';

void main() {
  group('redactCommandLine', () {
    test('masks secrets passed as flags, assignments and URLs', () {
      expect(redactCommandLine('cloudflared tunnel run --token eyJhIjoi'),
          'cloudflared tunnel run --token ***');
      expect(redactCommandLine('app --api-key=sk-123 --port=8080'),
          'app --api-key=*** --port=8080');
      expect(redactCommandLine('env DB_PASSWORD=hunter2 PATH=/bin node x.js'),
          'env DB_PASSWORD=*** PATH=/bin node x.js');
      expect(redactCommandLine('psql postgres://me:s3cret@db/app'),
          'psql postgres://***@db/app');
    });

    test('leaves ordinary command lines alone', () {
      const plain = '/usr/bin/dockerd -H fd:// --containerd=/run/c.sock';
      expect(redactCommandLine(plain), plain);
      expect(redactCommandLine('node --verbose -p 3000'),
          'node --verbose -p 3000');
    });
  });

  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('fake_proc'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String path, String content) {
    final f = File('${root.path}/$path');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  void writeProcess(
    int pid, {
    required String name,
    required int ppid,
    required int utime,
    required int stime,
    int rssPages = 0,
    String cmdline = '',
    int uid = 0,
    String cgroup = '0::/\n',
    int? readBytes,
    int? writeBytes,
  }) {
    final fields = List<String>.filled(22, '0');
    fields[0] = 'S';
    fields[1] = '$ppid';
    fields[11] = '$utime';
    fields[12] = '$stime';
    fields[21] = '$rssPages';
    write('$pid/stat', '$pid ($name) ${fields.join(' ')}\n');
    write('$pid/cmdline', cmdline.replaceAll(' ', '\u0000'));
    write('$pid/status', 'Name:\t$name\nUid:\t$uid\t$uid\t$uid\t$uid\n');
    write('$pid/cgroup', cgroup);
    if (readBytes != null) {
      write('$pid/io', 'rchar: 1\nread_bytes: $readBytes\n'
          'write_bytes: ${writeBytes ?? 0}\n');
    }
  }

  void writeHost({
    required String cpu,
    required int rx,
    required int tx,
    required int sectorsRead,
  }) {
    write('stat', 'cpu  $cpu 0 0\ncpu0 1 2 3\n');
    write('meminfo', 'MemTotal:       16000000 kB\nMemFree: 1 kB\n');
    write(
        '1/net/dev',
        'Inter-|   Receive\n face |bytes\n'
            '    lo: 999 0 0 0 0 0 0 0 999 0 0 0 0 0 0 0\n'
            'wlp1s0: $rx 0 0 0 0 0 0 0 $tx 0 0 0 0 0 0 0\n');
    write(
        'diskstats',
        ' 259 0 nvme0n1 1 0 $sectorsRead 0 1 0 0 0 0 0 0\n'
            ' 259 1 nvme0n1p1 1 0 99999 0 1 0 0 0 0 0 0\n');
  }

  test('attributes host CPU to the process that used it', () {
    writeHost(
        cpu: '1000 0 500 8000 100 0 0 0', rx: 1000, tx: 2000, sectorsRead: 0);
    writeProcess(1, name: 'systemd', ppid: 0, utime: 10, stime: 10);
    writeProcess(4200,
        name: 'node',
        ppid: 1,
        utime: 50,
        stime: 0,
        uid: kRendererUid,
        cmdline: 'node renderer_service.mjs',
        cgroup: '0::/system.slice/docker-0123456789abcdef0123.scope\n');
    writeProcess(4321,
        name: 'chromium',
        ppid: 4200,
        utime: 100,
        stime: 20,
        rssPages: 1000,
        uid: kRendererUid,
        cmdline: '/usr/lib/chromium/chromium --headless --type=gpu-process',
        cgroup: '0::/system.slice/docker-0123456789abcdef0123.scope\n',
        readBytes: 0,
        writeBytes: 0);
    final before = ProcSnapshot.read(root.path, elapsedUs: 0);

    // 400 ticks pass across all cores; chromium spends 300 of them.
    writeHost(
        cpu: '1300 0 550 8020 130 0 0 0',
        rx: 3000,
        tx: 2000,
        sectorsRead: 2048);
    writeProcess(4321,
        name: 'chromium',
        ppid: 4200,
        utime: 350,
        stime: 70,
        rssPages: 1000,
        uid: kRendererUid,
        cmdline: '/usr/lib/chromium/chromium --headless --type=gpu-process',
        cgroup: '0::/system.slice/docker-0123456789abcdef0123.scope\n',
        readBytes: 4096,
        writeBytes: 0);
    final after = ProcSnapshot.read(root.path, elapsedUs: 2000000);

    final b = ProcessBreakdown.compare(before, after);
    final chromium = b.processes.firstWhere((p) => p.pid == 4321);
    expect(chromium.cpuPercent, closeTo(75, 0.001));
    expect(chromium.ramBytes, 1000 * 4096);
    expect(chromium.parentName, 'node');
    expect(chromium.container, '0123456789ab');
    expect(chromium.command, contains('--headless'));
    expect(chromium.description, contains('renderer'));
    expect(chromium.readBytesPerSec, 2048);
    expect(b.processes.firstWhere((p) => p.pid == 4200).cpuPercent, 0);

    expect(b.cpuStates.firstWhere((s) => s.label == 'User').percent, 75);
    expect(b.cpuStates.firstWhere((s) => s.label == 'I/O wait').percent,
        closeTo(7.5, 0.001));
    expect(b.interfaces.single.name, 'wlp1s0');
    expect(b.interfaces.single.inPerSec, 1000);
    expect(b.disks.single.name, 'nvme0n1');
    expect(b.disks.single.inPerSec, 2048 * 512 / 2);
    expect(b.ramTotalBytes, 16000000 * 1024);
  });

  test('a process that starts mid-sample has no CPU share yet', () {
    writeHost(cpu: '100 0 0 100 0 0 0 0', rx: 0, tx: 0, sectorsRead: 0);
    final before = ProcSnapshot.read(root.path, elapsedUs: 0);
    writeHost(cpu: '200 0 0 200 0 0 0 0', rx: 0, tx: 0, sectorsRead: 0);
    writeProcess(77, name: 'sh (weird) name', ppid: 1, utime: 5, stime: 5);
    final after = ProcSnapshot.read(root.path, elapsedUs: 1000000);
    final p = ProcessBreakdown.compare(before, after).processes.single;
    expect(p.name, 'sh (weird) name');
    expect(p.cpuPercent, isNull);
  });

  test('names the luma stack, leaves unknown processes alone', () {
    expect(describeProcess('chromium', null, kRendererUid),
        contains('renderer'));
    expect(describeProcess('luma_server', null, 0), contains('luma'));
    expect(describeProcess('cloudflared', null, 0), contains('Tunnel'));
    expect(describeProcess('kworker/3:1', null, 0), contains('kernel'));
    expect(describeProcess('vim', 'vim notes.txt', 1000), isNull);
  });
}
