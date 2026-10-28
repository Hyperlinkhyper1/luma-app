import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_inventory_api.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_inventory_controller.dart';

const _id = '76561198012345678';
final _inventory = jsonEncode({
  'success': 1,
  'assets': [
    {'assetid': '1', 'classid': 'a', 'instanceid': '0'},
  ],
  'descriptions': [
    {
      'classid': 'a',
      'instanceid': '0',
      'market_hash_name': 'AK-47 | Redline (Field-Tested)',
      'tags': [
        {'category': 'Type', 'internal_name': 'CSGO_Type_Rifle'},
      ],
    },
  ],
});

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cs2_inventory_test');
    file = File('${directory.path}/profile.json');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('connect persists a resolved ID and imports the inventory', () async {
    final api = Cs2InventoryApi(client: MockClient((_) async => http.Response(_inventory, 200)));
    final imported = <Cs2InventoryItem>[];
    final controller = Cs2InventoryController(
      api: api,
      profileFile: () async => file,
      refreshInterval: Duration.zero,
      importInventory: (id, items) async {
        expect(id, _id);
        imported.addAll(items);
      },
    );
    expect(await controller.connect(_id), isTrue);
    expect(controller.steamId, _id);
    expect(imported.single.assetId, '1');
    expect(jsonDecode(await file.readAsString())['steamId'], _id);
    expect(await controller.disconnect(), isTrue);
    expect(controller.steamId, isNull);
    expect(await file.exists(), isFalse);
    expect(imported.single.assetId, '1');
    controller.dispose();
    api.close();
  });

  test('startup keeps profile and prior items if Steam returns an error', () async {
    await file.writeAsString(jsonEncode({'steamId': _id}));
    var imports = 0;
    final api = Cs2InventoryApi(client: MockClient((_) async => http.Response('', 429)));
    final controller = Cs2InventoryController(
      api: api,
      profileFile: () async => file,
      refreshInterval: Duration.zero,
      importInventory: (_, _) async { imports++; },
    );
    await controller.startup();
    expect(controller.steamId, _id);
    expect(controller.lastError, contains('rate limit'));
    expect(imports, 0);
    expect(jsonDecode(await file.readAsString())['steamId'], _id);
    controller.dispose();
    api.close();
  });

  test('rejects concurrent refresh and disconnect while connecting', () async {
    final pending = Completer<http.Response>();
    final api = Cs2InventoryApi(client: MockClient((_) => pending.future));
    var imports = 0;
    final controller = Cs2InventoryController(
      api: api,
      profileFile: () async => file,
      refreshInterval: Duration.zero,
      importInventory: (_, _) async { imports++; },
    );
    final connecting = controller.connect(_id);
    expect(controller.busy, isTrue);
    expect(await controller.disconnect(), isFalse);
    expect(await controller.refresh(), isFalse);
    pending.complete(http.Response(_inventory, 200));
    expect(await connecting, isTrue);
    expect(imports, 1);
    controller.dispose();
    api.close();
  });

  test('does not save a connection when import fails', () async {
    final api = Cs2InventoryApi(client: MockClient((_) async => http.Response(_inventory, 200)));
    final controller = Cs2InventoryController(
      api: api,
      profileFile: () async => file,
      refreshInterval: Duration.zero,
      importInventory: (_, _) async => throw StateError('storage failed'),
    );
    expect(await controller.connect(_id), isFalse);
    expect(controller.lastError, contains('storage failed'));
    expect(controller.steamId, isNull);
    expect(await file.exists(), isFalse);
    controller.dispose();
    api.close();
  });
}
