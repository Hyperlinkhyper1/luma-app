import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:luma_sync_server/ai_benchmark_store.dart';
import 'package:luma_sync_server/preview_render.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late HttpServer renderer;
  late AiBenchmarkStore store;
  const id = 'website_landing_page_isolated';
  const html = '<html><body>isolated scene</body></html>';
  const png = [137, 80, 78, 71, 13, 10, 26, 10, 1];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_renderer_test_');
    renderer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    store = await AiBenchmarkStore.open(dir.path);
    await store.saveUpload(
        kind: 'website_landing_page',
        id: id,
        model: 'test',
        vendor: 'test',
        description: '',
        bytes: utf8.encode(html));
  });
  tearDown(() async {
    await renderer.close(force: true);
    await dir.delete(recursive: true);
  });
  PreviewRenderService service() => PreviewRenderService(
      dataDir: dir.path,
      rendererUrl: 'http://127.0.0.1:${renderer.port}',
      startProcess: (exe, args) async =>
          throw StateError('Local browser must not start'),
      environment: const {});
  Future<void> done(PreviewRenderService s) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (s.status.running && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(s.status.running, false);
  }

  test('child processes receive only the runtime environment allowlist', () {
    expect(
        PreviewRenderService.childEnvironment({
          'PATH': 'runtime',
          'SystemRoot': 'windows',
          'LUMA_ADMIN_KEY': 'secret',
          'OPENAI_API_KEY': 'provider',
          'NODE_OPTIONS': '--require malicious.js',
        }),
        {'PATH': 'runtime', 'SystemRoot': 'windows'});
  });

  test(
      'remote renderer receives selected HTML/framing and writes its PNG atomically',
      () async {
    final pose = {
      'px': 1,
      'py': 2,
      'pz': 3,
      'qx': 0,
      'qy': 0,
      'qz': 0,
      'qw': 1
    };
    await store.writeFraming(id, pose);
    final received = Completer<Map<String, dynamic>>();
    renderer.listen((request) async {
      received.complete(jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>);
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.headers.set('x-renderer-backend', 'sandboxed');
      request.response.add(png);
      await request.response.close();
    });
    final s = service();
    expect(await s.start(PreviewRenderMode.all), isNull);
    final body = await received.future;
    expect(body['id'], id);
    expect(utf8.decode(base64Decode(body['scene'] as String)), html);
    expect(body['framing'], pose);
    expect(body.keys, unorderedEquals(['id', 'kind', 'scene', 'framing']));
    await done(s);
    expect(s.status.items.single.state, 'ok');
    expect((await store.readPreview(id))!.bytes, png);
    expect(s.status.renderer, 'sandboxed');
    expect(
        await File('${dir.path}/ai_benchmarks/previews/$id.png.tmp').exists(),
        false);
  });

  test('an invalid remote image keeps the previous banner and records failure',
      () async {
    final previous = File('${dir.path}/ai_benchmarks/previews/$id.png');
    await previous.parent.create(recursive: true);
    await previous.writeAsBytes(png);
    renderer.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.write('not an image');
      await request.response.close();
    });
    final s = service();
    expect(await s.start(PreviewRenderMode.all), isNull);
    await done(s);
    expect(s.status.items.single.state, 'failed');
    expect(s.failureFor(id), contains('Invalid renderer PNG'));
    expect(await previous.readAsBytes(), png);
  });

  test('stopping a remote render skips it and retains the previous banner',
      () async {
    final received = Completer<void>();
    renderer.listen((request) async {
      await request.drain<void>();
      received.complete();
    });
    final s = service();
    expect(await s.start(PreviewRenderMode.all), isNull);
    await received.future;
    expect(s.stop(), true);
    await done(s);
    expect(s.status.items.single.state, 'skipped');
    expect(await store.readPreview(id), isNull);
  });

  test('stopping during preparation never submits a remote scene', () async {
    var calls = 0;
    renderer.listen((request) {
      calls++;
      request.response.close();
    });
    final s = service();
    final pending = s.start(PreviewRenderMode.all);
    expect(s.stop(), true);
    expect(await pending, 'Banner render was stopped.');
    await done(s);
    expect(s.status.stopped, true);
    expect(s.status.items.single.state, 'skipped');
    expect(calls, 0);
  });

  test('stopping during local process startup kills the eventual process',
      () async {
    final started = Completer<void>();
    final startup = Completer<Process>();
    final s = PreviewRenderService(
        dataDir: dir.path,
        environment: const {},
        fileExists: (_) async => true,
        runProcess: (exe, args) async => ProcessResult(0, 0, 'v24', ''),
        startProcess: (exe, args) async {
          started.complete();
          return startup.future;
        });
    final pending = s.start(PreviewRenderMode.all);
    await started.future;
    expect(s.stop(), true);
    final child = _DelayedProcess();
    startup.complete(child);
    expect(await pending, isNull);
    await done(s);
    expect(child.killed, true);
    expect(s.status.items.single.state, 'skipped');
  });
}

class _DelayedProcess implements Process {
  final _exit = Completer<int>();
  bool killed = false;
  @override
  int get pid => 0;
  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  IOSink get stdin => throw UnimplementedError();
  @override
  Future<int> get exitCode => _exit.future;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exit.isCompleted) _exit.complete(-15);
    return true;
  }
}
