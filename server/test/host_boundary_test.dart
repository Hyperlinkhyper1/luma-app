import 'dart:io';

import 'package:luma_sync_server/store.dart';
import 'package:test/test.dart';

/// What keeps a compromised server container from reaching the host it runs
/// on. These are deploy files, not Dart, so nothing else would notice them
/// drifting back: the wiki mount was writable, and the watcher ran
/// `docker compose up` in that same folder, so code execution in luma-sync
/// could plant a compose file and start a privileged container.
void main() {
  /// [file]'s lines without comments or blank lines.
  List<String> code(String file) => File(file)
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList();

  group('docker-compose.yml', () {
    final compose = code('docker-compose.yml');

    test('mounts the wiki read-only, apart from the folders the editor writes',
        () {
      final wikiMounts =
          compose.where((line) => line.startsWith('- ../wiki')).toList();
      expect(wikiMounts, contains('- ../wiki:/wiki:ro'));
      final writable = wikiMounts.where((line) => !line.endsWith(':ro'));
      expect(writable.toSet(), {
        '- ../wiki/source/src/content:/wiki/source/src/content',
        '- ../wiki/source/public/images/uploads:/wiki/source/public/images/uploads',
      });
    });

    test('hands no container the Docker socket or the host itself', () {
      for (final line in compose) {
        expect(line, isNot(contains('docker.sock')));
        expect(line, isNot(matches(RegExp(r'^privileged:\s*true'))));
        expect(line, isNot(matches(RegExp(r'^pid:\s*"?host'))));
        expect(line, isNot(matches(RegExp(r'^network_mode:\s*"?host'))));
      }
    });

    test('mounts the host /proc only when the operator opts in', () {
      expect(compose.where((line) => line.startsWith('- /proc')), isEmpty);
      expect(compose,
          contains(r'- ${LUMA_HOST_PROC_MOUNT:-/dev/null}:/host/proc:ro'));
    });

    test('lets Caddy be bound to loopback behind a tunnel', () {
      expect(compose, contains(r'- "${LUMA_HTTP_LISTEN:-80}:80"'));
      expect(compose, contains(r'- "${LUMA_HTTPS_LISTEN:-443}:443"'));
    });
  });

  group('deploy-watcher.sh', () {
    final watcher = code('deploy-watcher.sh').join('\n');

    test('never runs docker compose from the shared wiki folder', () {
      expect(watcher, isNot(matches(RegExp(r'cd\s+"?\$WIKI_'))));
      expect(watcher,
          isNot(matches(RegExp(r'compose\s+(up|start|restart|stop)[^\n]*WIKI'))));
      expect(watcher,
          contains('label=com.docker.compose.project.working_dir='));
    });

    test('relays wiki requests without following planted symlinks', () {
      expect(watcher, contains(r'write_to "$WIKI_CHECKOUT/$flag" date -Is'));
      expect(RegExp(r'^\s*relay_wiki_requests$', multiLine: true)
          .hasMatch(watcher), isTrue);
    });
  });

  test('harden-ssh.sh allows keys only, and refuses to lock the owner out',
      () {
    final script = File('harden-ssh.sh').readAsStringSync();
    for (final setting in [
      'PasswordAuthentication no',
      'KbdInteractiveAuthentication no',
      'AuthenticationMethods publickey',
      'PermitRootLogin no',
      r'AllowUsers $user',
    ]) {
      expect(script, contains('\n$setting\n'));
    }
    expect(script, contains('has no SSH key in it'));
    expect(script, contains(r'if ! "$SSHD" -t; then'));
  });

  test('the data directory and secret key are closed to other accounts',
      () async {
    final dir = await Directory.systemTemp.createTemp('luma_host_boundary_');
    addTearDown(() => dir.delete(recursive: true));
    await Store.open(dir.path);

    expect((await dir.stat()).mode & 0x1ff, 0x1c0);
    expect((await File('${dir.path}/secret.key').stat()).mode & 0x1ff, 0x180);
  }, skip: Platform.isWindows ? 'POSIX permissions' : false);
}
