import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/command_dashboard/command_dashboard_repository.dart';
import 'package:luma/features/plugins/installed/command_dashboard/command_models.dart';

void main() {
  const rojo = DashCommand(
    id: 'r1',
    name: 'Rojo',
    kind: CommandKind.shell,
    command: 'rojo serve',
    workingDirectory: r'C:\games\my place',
    keepsRunning: true,
    port: 34872,
    icon: 'dns',
  );
  const script = DashCommand(
    id: 's1',
    name: 'Build',
    kind: CommandKind.script,
    command: r'C:\tools\build all.bat',
    runAsAdmin: true,
  );

  group('storage', () {
    test('commands round-trip through JSON', () {
      final decoded = decodeCommands(encodeCommands([rojo, script]));
      expect(decoded, hasLength(2));
      expect(decoded[0].toJson(), rojo.toJson());
      expect(decoded[1].toJson(), script.toJson());
    });

    test('a damaged file yields no commands instead of throwing', () {
      expect(decodeCommands('{not json'), isEmpty);
      expect(decodeCommands('{"commands": [{"id": 1}]}'), isEmpty);
    });

    test('duplicate keeps the settings under a new id and name', () {
      final copy = script.duplicate('s2', 'Build (copy)');
      expect(copy.id, 's2');
      expect(copy.name, 'Build (copy)');
      expect(copy.runAsAdmin, isTrue);
      expect(copy.command, script.command);
    });
  });

  group('working folder', () {
    test('a script runs in its own folder by default', () {
      expect(script.effectiveWorkingDirectory, r'C:\tools');
    });

    test('an explicit folder wins', () {
      expect(rojo.effectiveWorkingDirectory, r'C:\games\my place');
    });

    test('a plain command with no folder has none', () {
      const plain = DashCommand(
        id: 'p',
        name: 'p',
        kind: CommandKind.shell,
        command: 'ipconfig',
      );
      expect(plain.effectiveWorkingDirectory, isNull);
    });
  });

  group('wrapper batch', () {
    test('quotes the script path and changes into its folder', () {
      final bat = wrapperBatch(script);
      expect(bat, contains(r'cd /d "C:\tools"'));
      expect(bat, contains(r'call "C:\tools\build all.bat"'));
      expect(bat, contains('\r\n'));
      expect(bat, contains('exit /b %errorlevel%'));
    });

    test('runs .ps1 scripts through PowerShell', () {
      final ps = script.copyWith(command: r'C:\tools\setup.ps1');
      expect(commandLineFor(ps), contains('-File "C:\\tools\\setup.ps1"'));
    });

    test('passes a typed command through untouched', () {
      expect(wrapperBatch(rojo), contains('\r\nrojo serve\r\n'));
    });
  });

  group('launcher', () {
    test('an elevated run asks UAC and redirects into the log', () {
      final ps = launcherScript(
        batchPath: r'C:\Temp\luma_commands\s1.bat',
        admin: true,
        ownWindow: false,
        logPath: r'C:\Temp\luma_commands\s1.log',
      );
      expect(ps, contains('-Verb RunAs'));
      expect(ps, contains('-WindowStyle Hidden'));
      expect(ps, contains(r'> "C:\Temp\luma_commands\s1.log" 2>&1'));
      expect(ps, contains('LUMA_PID'));
      expect(ps, contains('WaitForExit'));
    });

    test('an own-window run keeps the window open and is not elevated', () {
      final ps = launcherScript(
        batchPath: r'C:\Temp\x.bat',
        admin: false,
        ownWindow: true,
      );
      expect(ps, isNot(contains('RunAs')));
      expect(ps, contains(r'/k "C:\Temp\x.bat"'));
      expect(ps, contains('-WindowStyle Normal'));
    });

    test("single quotes in a path are doubled for PowerShell", () {
      final ps = launcherScript(
        batchPath: r"C:\Users\o'neil\x.bat",
        admin: false,
        ownWindow: true,
      );
      expect(ps, contains(r"o''neil"));
    });

    test('the launcher reports its PID on a line of its own', () {
      expect(parseLauncherPid('LUMA_PID:4242'), 4242);
      expect(parseLauncherPid('  LUMA_PID:7 \r'), 7);
      expect(parseLauncherPid('something else'), isNull);
    });

    test('encoded commands are base64 UTF-16LE', () {
      final encoded = encodePowerShell('hé');
      final bytes = base64.decode(encoded);
      expect(bytes, [0x68, 0x00, 0xe9, 0x00]);
    });
  });

  group('host detection', () {
    test("reads rojo's announced port", () {
      expect(detectPort('Rojo server listening:'), isNull);
      expect(detectPort('  Address: localhost'), isNull);
      expect(detectPort('  Port:    34872'), 34872);
    });

    test('reads a dev server URL', () {
      expect(detectPort('  ➜  Local:   http://localhost:5173/'), 5173);
      expect(detectPort('Serving on http://127.0.0.1:8000'), 8000);
    });

    test('ignores numbers that are not ports', () {
      expect(detectPort('Compiled 120 files in 3.4s'), isNull);
      expect(detectPort('port 99999'), isNull);
    });

    test('counts only established connections into the port', () {
      const netstat = '''
Active Connections

  Proto  Local Address          Foreign Address        State           PID
  TCP    127.0.0.1:34872        0.0.0.0:0              LISTENING       1200
  TCP    127.0.0.1:34872        127.0.0.1:51234        ESTABLISHED     1200
  TCP    127.0.0.1:51234        127.0.0.1:34872        ESTABLISHED     8800
  TCP    127.0.0.1:34872        127.0.0.1:51300        TIME_WAIT       0
  TCP    [::1]:34872            [::1]:51400            ESTABLISHED     1200
  TCP    192.168.1.5:443        1.2.3.4:5555           ESTABLISHED     9
''';
      final clients = parseEstablished(netstat, 34872);
      expect(clients.map((c) => c.remoteAddress),
          ['127.0.0.1:51234', '[::1]:51400']);
      expect(clients.first.pid, 1200);
    });
  });

  group('repository', () {
    late Directory dir;
    late File store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('cmd_dash_test');
      store = File('${dir.path}${Platform.pathSeparator}commands.json');
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    CommandDashboardRepository repo() =>
        CommandDashboardRepository(storeFile: () async => store);

    test('adds, edits, reorders and removes, and persists each step',
        () async {
      final first = repo();
      await first.load();
      expect(first.commands, isEmpty);

      await first.upsert(rojo);
      await first.upsert(script);
      await first.upsert(rojo.copyWith(name: 'Rojo place'));
      expect(first.commands.map((c) => c.name), ['Rojo place', 'Build']);

      await first.reorder(1, 0);
      expect(first.commands.map((c) => c.id), ['s1', 'r1']);

      final second = repo();
      await second.load();
      expect(second.commands.map((c) => c.id), ['s1', 'r1']);
      expect(second.commands[1].name, 'Rojo place');

      await second.remove('s1');
      final third = repo();
      await third.load();
      expect(third.commands.map((c) => c.id), ['r1']);
    });

    test('a fresh command has never run', () async {
      final r = repo();
      await r.load();
      await r.upsert(rojo);
      expect(r.runOf('r1').isActive, isFalse);
      expect(r.activeCount, 0);
    });
  });
}
