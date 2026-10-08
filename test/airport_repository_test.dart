import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_game_state.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/airline_tycoon_repository.dart';
import 'package:luma/features/plugins/installed/airline_tycoon/data/airport_catalog.dart';
import 'package:luma/storage/storage_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalog = AirportCatalog.parse(
    File('assets/airline_tycoon/airports.json').readAsStringSync(),
  );
  late Directory dir;
  late Directory documents;
  final repositories = <AirlineTycoonRepository>[];
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma-airport-test-');
    documents = await Directory('${dir.path}/documents').create();
    StorageGuardService.instance = StorageGuardService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'getApplicationDocumentsDirectory'
              ? documents.path
              : dir.path,
        );
  });
  tearDown(() async {
    for (final repo in repositories) {
      repo.dispose();
      await repo.flushAirport();
    }
    repositories.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    final resolved = await dir.resolveSymbolicLinks();
    final parent = await Directory.systemTemp.resolveSymbolicLinks();
    expect(
      resolved.startsWith('$parent${Platform.pathSeparator}luma-airport-test-'),
      isTrue,
    );
    await dir.delete(recursive: true);
  });
  AirlineTycoonRepository make({bool airport = true}) {
    final repo = AirlineTycoonRepository(autoStart: false, airportMode: airport)
      ..setCatalogForTest(catalog);
    repositories.add(repo);
    return repo;
  }

  Future<AirlineTycoonRepository> boot() async {
    final repo = AirlineTycoonRepository(airportMode: true);
    repositories.add(repo);
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!repo.isLoaded) {
      if (DateTime.now().isAfter(deadline)) fail('Airport boot did not finish');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return repo;
  }

  test('app resume does not run an unopened airport', () async {
    final repo = make()..startGame(airlineName: 'Closed', hubIata: 'AMS');
    repo.resume();
    repo.didChangeAppLifecycleState(AppLifecycleState.hidden);
    repo.didChangeAppLifecycleState(AppLifecycleState.resumed);
    final before = repo.airportWorld!.time;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(repo.airportWorld!.time, before);
  });

  test('unchanged airport does not rewrite the save or backup', () async {
    final repo = make()..startGame(airlineName: 'Idle', hubIata: 'AMS');
    await repo.flushAirport();
    repo.setSpeed(4);
    await repo.flushAirport();
    final file = File(
      '${dir.path}/${AirlineTycoonRepository.airportSaveFileName}',
    );
    final before = await file.readAsString();
    final modified = await file.lastModified();
    final backup = File('${file.path}.bak');
    final backupBefore = await backup.exists()
        ? await backup.readAsString()
        : null;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await repo.flushAirport();
    expect(await file.readAsString(), before);
    expect(await file.lastModified(), modified);
    expect(
      await backup.exists() ? await backup.readAsString() : null,
      backupBefore,
    );
  });

  for (final source in ['save', 'backup', 'corrupt save']) {
    test(
      'migrates Documents $source without rewriting or losing offline time',
      () async {
        final original = make()
          ..startGame(airlineName: 'Migrated Air', hubIata: 'AMS');
        original.airportWorld!.paused = false;
        original.airportWorld!.time = 777;
        original.airportWorld!.lastSeenEpochMs =
            DateTime.now().millisecondsSinceEpoch - 60000;
        original.state.lastSeenEpochMs = original.airportWorld!.lastSeenEpochMs;
        await original.flushAirport(checkpoint: false);
        final local = File(
          '${dir.path}/${AirlineTycoonRepository.airportSaveFileName}',
        );
        final saved = await local.readAsString();
        await local.delete();
        final localBackup = File('${local.path}.bak');
        if (await localBackup.exists()) await localBackup.delete();
        final old = File(
          '${documents.path}/${AirlineTycoonRepository.airportSaveFileName}',
        );
        if (source == 'save') {
          await old.writeAsString(saved);
        } else {
          await File('${old.path}.bak').writeAsString(saved);
          if (source == 'corrupt save') await old.writeAsString('broken');
        }
        final loaded = await boot();
        expect(loaded.airportSaveError, isNull);
        expect(loaded.state.airlineName, 'Migrated Air');
        expect(loaded.airportWorld!.time, 777);
        expect(
          loaded.airportWorld!.lastSeenEpochMs,
          original.airportWorld!.lastSeenEpochMs,
        );
        final migrated = await local.readAsString();
        expect(jsonDecode(migrated), {
          'format': 2,
          'airline': loaded.state.toJson(),
          'airport': loaded.airportWorld!.toJson(),
        });
        expect(await localBackup.readAsString(), migrated);
        expect(await old.exists(), source != 'backup');
        if (await old.exists()) {
          expect(
            await old.readAsString(),
            source == 'corrupt save' ? 'broken' : saved,
          );
        }
        loaded.setAirportPageVisible(Object(), true);
        expect(loaded.airportWorld!.time, greaterThan(830));
        loaded.pause();
        await loaded.flushAirport();
      },
    );
  }

  test('loading local save leaves idle files unchanged', () async {
    final original = make()
      ..startGame(airlineName: 'Local Air', hubIata: 'AMS');
    original.airportWorld!.paused = false;
    await original.flushAirport();
    final local = File(
      '${dir.path}/${AirlineTycoonRepository.airportSaveFileName}',
    );
    final saved = await local.readAsString();
    final modified = await local.lastModified();
    await File(
      '${documents.path}/${AirlineTycoonRepository.airportSaveFileName}',
    ).writeAsString('broken');
    final loaded = await boot();
    expect(loaded.state.airlineName, 'Local Air');
    final before = loaded.airportWorld!.time;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(loaded.airportWorld!.time, before);
    await loaded.flushAirport();
    expect(await local.readAsString(), saved);
    expect(await local.lastModified(), modified);
  });

  test('sync import does not start a hidden airport', () async {
    final repo = make()..startGame(airlineName: 'Before', hubIata: 'AMS');
    final incoming = make()..startGame(airlineName: 'Synced', hubIata: 'AMS');
    incoming.airportWorld!.paused = false;
    incoming.state.lastSeenEpochMs =
        DateTime.now().millisecondsSinceEpoch + 10000;
    await repo.importData(await incoming.exportData());
    expect(repo.state.airlineName, 'Synced');
    final before = repo.airportWorld!.time;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(repo.airportWorld!.time, before);
  });

  test('visible pages and lifecycle jointly control the clock', () async {
    final repo = make()..startGame(airlineName: 'Tabs', hubIata: 'AMS');
    final first = Object(), second = Object();
    repo.setAirportPageVisible(first, true);
    repo.setAirportPageVisible(second, true);
    repo.resume();
    repo.setAirportPageVisible(first, false);
    var before = repo.airportWorld!.time;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(repo.airportWorld!.time, greaterThan(before));
    repo.didChangeAppLifecycleState(AppLifecycleState.hidden);
    before = repo.airportWorld!.time;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(repo.airportWorld!.time, before);
    repo.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(repo.airportWorld!.time, greaterThan(before));
    repo.setAirportPageVisible(second, false);
    before = repo.airportWorld!.time;
    await repo.flushAirport();
    final file = File(
      '${dir.path}/${AirlineTycoonRepository.airportSaveFileName}',
    );
    final saved = await file.readAsString();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(repo.airportWorld!.time, before);
    expect(await file.readAsString(), saved);
    repo.setAirportPageVisible(first, true);
    expect(repo.airportWorld!.time, greaterThan(before));
    repo.pause();
  });

  test('new save is atomic and leaves legacy file unchanged', () async {
    final legacy = File(
      '${documents.path}/${AirlineTycoonRepository.saveFileName}',
    );
    await legacy.writeAsString('legacy sentinel');
    final repo = make()..startGame(airlineName: 'Airport Air', hubIata: 'AMS');
    await repo.flushAirport();
    repo.setSpeed(4);
    await repo.flushAirport();
    expect(repo.airportSaveError, isNull);
    expect(await legacy.readAsString(), 'legacy sentinel');
    final file = File(
      '${dir.path}/${AirlineTycoonRepository.airportSaveFileName}',
    );
    final data = jsonDecode(await file.readAsString()) as Map;
    expect(data['format'], 2);
    expect((data['airport'] as Map)['paused'], isTrue);
    expect(await File('${file.path}.tmp').exists(), isFalse);
    expect(await File('${file.path}.bak').exists(), isTrue);
  });

  test('legacy and new snapshots cannot overwrite each other', () async {
    final modern = make()..startGame(airlineName: 'Modern', hubIata: 'AMS');
    final legacy = make(airport: false)
      ..startGame(airlineName: 'Legacy', hubIata: 'AMS');
    legacy.pause();
    final old = AirlineGameState(
      airlineName: 'Wrong',
      hubIata: 'LHR',
      lastSeenEpochMs: DateTime.now().millisecondsSinceEpoch + 999999,
    ).toJson();
    await modern.importData(old);
    expect(modern.state.airlineName, 'Modern');
    await legacy.importData(await modern.exportData());
    expect(legacy.state.airlineName, 'Legacy');
  });

  test(
    'pause freezes offline accrual and resume retains the chosen speed',
    () async {
      final repo = make()..startGame(airlineName: 'Paused', hubIata: 'AMS');
      repo.airportWorld!.lastSeenEpochMs =
          DateTime.now().millisecondsSinceEpoch - 60000;
      final before = repo.airportWorld!.time;
      repo.catchUpOnAwayTime();
      expect(repo.airportWorld!.time, before);
      expect(repo.airportCommand('speed', {'speed': 12}).success, isTrue);
      expect(repo.isPaused, isTrue);
      repo.resume();
      repo.airportWorld!.lastSeenEpochMs =
          DateTime.now().millisecondsSinceEpoch - 10000;
      repo.catchUpOnAwayTime();
      repo.pause();
      expect(repo.airportWorld!.time, closeTo(before + 120, 2));
      expect(repo.airportWorld!.speed, 12);
    },
  );

  test(
    'snapshot exposes real parked starter aircraft and rejects malformed construction',
    () {
      final repo = make()..startGame(airlineName: 'Safe', hubIata: 'AMS');
      expect(repo.airportSnapshot()['idleAircraft'], hasLength(1));
      final cash = repo.state.cashEur;
      expect(
        repo.airportCommand('place', {
          'kind': 'stand',
          'x': double.nan,
          'y': 0,
        }).success,
        isFalse,
      );
      expect(
        repo.airportCommand('place', {
          'kind': 'invented',
          'x': 0,
          'y': 0,
        }).success,
        isFalse,
      );
      expect(repo.state.cashEur, cash);
    },
  );
}
