import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/power_console.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// The host side (deploy-watcher.sh) can't run here; what can be checked is
/// what the dashboard's buttons leave for it, and what they refuse to do.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_power_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  PowerConsole console() => PowerConsole(
        dataDir: dir.path,
        repoPath: '/home/op/luma-app',
        startedAt: DateTime.now(),
      );

  Request post(Map<String, dynamic> body) =>
      Request('POST', Uri.parse('http://x/'), body: jsonEncode(body));

  Future<Map<String, dynamic>> json(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  File file(String name) => File('${dir.path}/$name');
  Future<void> watcherAlive() => file('deploy.watcher').writeAsString('');

  test('shutting down luma needs no watcher and survives a restart', () async {
    final r = await console().shutdown(post({
      'targets': ['luma']
    }));
    expect(r.statusCode, 200);
    expect(await file('luma.stopped').exists(), isTrue);
    expect(console().lumaStopped, isTrue);

    final s = await console().start(post({
      'targets': ['luma']
    }));
    expect(s.statusCode, 200);
    expect(console().lumaStopped, isFalse);
  });

  test('the admin panel is not shut down without confirmation', () async {
    await watcherAlive();
    final r = await console().shutdown(post({
      'targets': ['admin']
    }));
    expect(r.statusCode, 400);
    expect((await json(r))['error'], 'confirm_required');
    expect(await file('power.request').exists(), isFalse);
  });

  test('a confirmed admin shutdown files the request and returns commands',
      () async {
    await watcherAlive();
    await file('wiki.start-cmd')
        .writeAsString('cd /home/op/luma-app/wiki && docker compose up -d\n');
    final c = console();
    await c.setLumaStopped(true);

    final r = await c.shutdown(post({
      'targets': ['admin', 'luma'],
      'confirm': 'admin'
    }));
    expect(r.statusCode, 200);
    expect(await file('power.request').readAsString(), 'shutdown all\n');
    expect((await json(r))['commands'], [
      'cd /home/op/luma-app/server && docker compose up -d',
      'cd /home/op/luma-app/wiki && docker compose up -d',
    ]);
    // The commands are meant to bring everything back, luma included.
    expect(c.lumaStopped, isFalse);
  });

  test('wiki and restart requests need a live watcher', () async {
    final stop = await console().shutdown(post({
      'targets': ['wiki']
    }));
    expect(stop.statusCode, 409);
    expect((await console().restart(post({}))).statusCode, 409);

    await watcherAlive();
    final c = console();
    await c.setLumaStopped(true);
    expect((await c.restart(post({}))).statusCode, 200);
    expect(await file('power.request').readAsString(), 'restart all\n');
    expect(c.lumaStopped, isFalse);

    // One request at a time.
    final again = await c.start(post({
      'targets': ['wiki']
    }));
    expect(again.statusCode, 409);
  });

  test('wiki state is unknown once the watcher goes quiet', () async {
    await file('wiki.state').writeAsString('stopped\n');
    var s = await json(
        await console().status(Request('GET', Uri.parse('http://x/'))));
    expect(s['wiki'], 'unknown');

    await watcherAlive();
    s = await json(
        await console().status(Request('GET', Uri.parse('http://x/'))));
    expect(s['wiki'], 'stopped');
  });
}
