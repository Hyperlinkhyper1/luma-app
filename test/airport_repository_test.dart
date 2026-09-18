import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
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
  final repositories = <AirlineTycoonRepository>[];
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma-airport-test-');
    StorageGuardService.instance = StorageGuardService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => dir.path);
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

  test('new save is atomic and leaves legacy file unchanged', () async {
    final legacy = File('${dir.path}/${AirlineTycoonRepository.saveFileName}');
    await legacy.writeAsString('legacy sentinel');
    final repo = make()..startGame(airlineName: 'Airport Air', hubIata: 'AMS');
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
