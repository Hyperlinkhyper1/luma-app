import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_cloud_sync.dart';
import 'package:luma/features/plugins/installed/ai_usage/ai_usage_source.dart';
import 'package:luma/features/plugins/installed/ai_usage/data/ai_usage_database.dart';

/// An in-memory stand-in for the sync server's per-user object store, shared
/// between the "devices" in a test the way one account's server would be.
class _FakeServer {
  final objects = <String, ({Object? data, int version})>{};
  int puts = 0;
}

class _FakeStore implements AiUsageCloudStore {
  _FakeStore(this.server);

  final _FakeServer server;
  bool on = true;

  @override
  bool get available => on;

  @override
  bool get enabled => on;

  @override
  Future<Map<String, int>> list(String prefix) async => {
    for (final e in server.objects.entries)
      if (e.key.startsWith(prefix)) e.key: e.value.version,
  };

  @override
  Future<({Object? data, int version})?> get(String name) async =>
      server.objects[name];

  @override
  Future<int> put(String name, Object payload, {required int baseVersion}) async {
    final current = server.objects[name]?.version ?? 0;
    if (current != baseVersion) throw StateError('conflict');
    server.puts++;
    // Round-trip through the same shape the real server hands back.
    server.objects[name] = (data: payload, version: current + 1);
    return current + 1;
  }
}

class _Device {
  _Device(this.name, _FakeServer server, this.directory)
    : db = AiUsageDatabase(NativeDatabase.memory()),
      store = _FakeStore(server);

  final String name;
  final Directory directory;
  final AiUsageDatabase db;
  final _FakeStore store;
  late final sync = AiUsageCloudSync(
    db: db,
    store: store,
    supportDirectoryProvider: () async => directory,
    deviceName: name,
  );

  Future<void> addTurn({required int input, required int output}) =>
      db.into(db.aiUsageTurns).insert(
        AiUsageTurnsCompanion.insert(
          sessionId: 'session-$name',
          timestamp: DateTime.utc(2026, 9, 1, 12),
          model: 'claude-sonnet-5',
          inputTokens: Value(input),
          outputTokens: Value(output),
          project: const Value('luma'),
          source: AiUsageSource.claudeCode,
          effort: const Value(AiEffort.high),
        ),
      );

  Future<int> totalInput() async =>
      (await db.select(db.aiUsageTurns).get()).fold<int>(
        0,
        (sum, t) => sum + t.inputTokens,
      );
}

void main() {
  // Two in-memory databases stand in for two devices on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late _FakeServer server;
  late Directory root;
  late _Device laptop;
  late _Device desktop;

  setUp(() async {
    server = _FakeServer();
    root = await Directory.systemTemp.createTemp('luma_ai_usage_sync_');
    laptop = _Device(
      'laptop',
      server,
      await Directory('${root.path}/laptop').create(),
    );
    desktop = _Device(
      'desktop',
      server,
      await Directory('${root.path}/desktop').create(),
    );
  });

  tearDown(() async {
    await laptop.db.close();
    await desktop.db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('sums usage across devices without re-uploading pulled turns', () async {
    await laptop.addTurn(input: 100, output: 10);
    await desktop.addTurn(input: 200, output: 20);
    await desktop.addTurn(input: 300, output: 30);

    await laptop.sync.syncOnOpen();
    await desktop.sync.syncOnOpen();
    await laptop.sync.syncOnOpen();

    expect(await laptop.totalInput(), 600);
    expect(await desktop.totalInput(), 600);

    final remote = await laptop.db.select(laptop.db.aiUsageRemoteDevices).get();
    expect(remote.single.name, 'desktop');
    expect(remote.single.turnCount, 2);

    // Each device's object holds only its own turns, so the sum never
    // double-counts no matter how many times the devices exchange.
    await desktop.sync.syncOnOpen();
    expect(await desktop.totalInput(), 600);
    expect(server.objects, hasLength(2));
  });

  test('pulled turns keep their usage details', () async {
    await desktop.addTurn(input: 42, output: 7);
    await desktop.sync.syncOnOpen();
    await laptop.sync.syncOnOpen();

    final turn = (await laptop.db.select(laptop.db.aiUsageTurns).get()).single;
    expect(turn.deviceId, isNotNull);
    expect(turn.model, 'claude-sonnet-5');
    expect(turn.project, 'luma');
    expect(turn.effort, AiEffort.high);
    expect(turn.outputTokens, 7);
    expect(turn.timestamp.isAtSameMomentAs(DateTime.utc(2026, 9, 1, 12)), isTrue);
  });

  test('closing only uploads when something new was scanned', () async {
    await laptop.addTurn(input: 1, output: 1);
    await laptop.sync.syncOnOpen();
    final afterOpen = server.puts;

    await laptop.sync.pushOnClose();
    expect(server.puts, afterOpen);

    await laptop.addTurn(input: 5, output: 5);
    await laptop.sync.pushOnClose();
    expect(server.puts, afterOpen + 1);

    await desktop.sync.syncOnOpen();
    expect(await desktop.totalInput(), 6);
  });

  test('turning sync off drops other devices\' usage', () async {
    await desktop.addTurn(input: 50, output: 5);
    await laptop.addTurn(input: 10, output: 1);
    await desktop.sync.syncOnOpen();
    await laptop.sync.syncOnOpen();
    expect(await laptop.totalInput(), 60);

    laptop.store.on = false;
    await laptop.sync.syncOnOpen();

    expect(await laptop.totalInput(), 10);
    expect(await laptop.db.select(laptop.db.aiUsageRemoteDevices).get(), isEmpty);
  });

  test('nothing is sent while sync is unavailable', () async {
    laptop.store.on = false;
    await laptop.addTurn(input: 1, output: 1);
    await laptop.sync.syncOnOpen();
    await laptop.sync.pushOnClose();
    expect(server.objects, isEmpty);
  });

  test('object names fit the server\'s collection name rule', () async {
    await laptop.addTurn(input: 1, output: 1);
    await laptop.sync.syncOnOpen();
    final name = server.objects.keys.single;
    expect(RegExp(r'^[a-z0-9_]{1,32}$').hasMatch(name), isTrue);
  });
}
