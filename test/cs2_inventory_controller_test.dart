import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_inventory_api.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_inventory_controller.dart';
import 'package:luma/features/plugins/installed/steam_tools/cs2_steam_session.dart';

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

/// The owner's view: the visible rifle plus a sticker Steam still holds
/// under trade protection, which the public listing leaves out.
final _ownerInventory = jsonEncode({
  'success': 1,
  'total_inventory_count': 2,
  'assets': [
    {'assetid': '1', 'classid': 'a', 'instanceid': '0'},
    {'assetid': '2', 'classid': 'p', 'instanceid': '0'},
  ],
  'descriptions': [
    {
      'classid': 'a',
      'instanceid': '0',
      'market_hash_name': 'AK-47 | Redline (Field-Tested)',
      'tradable': 1,
      'marketable': 1,
      'tags': [
        {'category': 'Type', 'internal_name': 'CSGO_Type_Rifle'},
      ],
    },
    {
      'classid': 'p',
      'instanceid': '0',
      'market_hash_name': 'Sticker | Protected',
      'tradable': 0,
      'marketable': 0,
      'owner_descriptions': [
        {'type': 'html', 'value': 'Trade Protected'},
      ],
      'tags': [
        {'category': 'Type', 'internal_name': 'CSGO_Tool_Sticker'},
      ],
    },
  ],
});

/// The public view of the same inventory: one item listed, two counted.
final _publicInventory = jsonEncode({
  'success': 1,
  'total_inventory_count': 2,
  'assets': [
    {'assetid': '1', 'classid': 'a', 'instanceid': '0'},
  ],
  'descriptions': [
    {
      'classid': 'a',
      'instanceid': '0',
      'market_hash_name': 'AK-47 | Redline (Field-Tested)',
      'tradable': 1,
      'marketable': 1,
      'tags': [
        {'category': 'Type', 'internal_name': 'CSGO_Type_Rifle'},
      ],
    },
  ],
});

class _FakeSession implements Cs2SteamSession {
  String? who = _id;
  int loads = 0;
  bool signedOut = false;

  @override
  Future<String?> signedInSteamId() async => who;

  @override
  Future<Cs2InventoryPage> load(Uri uri) async {
    loads++;
    expect(uri.host, 'steamcommunity.com');
    return Cs2InventoryPage(200, _ownerInventory);
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    who = null;
  }
}

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

  group('Steam sign-in', () {
    late _FakeSession session;
    late Cs2InventoryApi api;
    late DateTime now;
    late List<List<String>> imports;
    late Cs2InventoryController controller;

    Cs2InventoryController build() => Cs2InventoryController(
      api: api,
      profileFile: () async => file,
      refreshInterval: Duration.zero,
      sessionWait: const Duration(milliseconds: 50),
      now: () => now,
      importInventory: (_, items) async {
        imports.add([for (final item in items) item.assetId]);
      },
    );

    setUp(() {
      session = _FakeSession();
      api = Cs2InventoryApi(
        client: MockClient((_) async => http.Response(_publicInventory, 200)),
      );
      now = DateTime.utc(2026, 11, 9);
      imports = [];
      controller = build()..attachSession(session);
    });

    tearDown(() {
      controller.dispose();
      api.close();
    });

    test('reads trade-protected items as the owner', () async {
      expect(await controller.signIn(_id), isTrue);
      expect(session.loads, 1);
      expect(imports.last, ['1', '2']);
      expect(controller.sessionStatus, Cs2SteamSessionStatus.active);
      expect(controller.hiddenCount, 0);
      final saved = jsonDecode(await file.readAsString()) as Map;
      expect(saved['steamSession'], isTrue);
      expect((saved['protected'] as List).single['assetId'], '2');
    });

    test('keeps protected items when the sign-in lapses, until protection ends', () async {
      expect(await controller.signIn(_id), isTrue);
      session.who = null;
      expect(await controller.refresh(), isTrue);
      expect(controller.sessionStatus, Cs2SteamSessionStatus.signedOut);
      expect(imports.last, ['1', '2']);
      expect(controller.hiddenCount, 0);

      now = now.add(const Duration(days: 9));
      expect(await controller.refresh(), isTrue);
      expect(imports.last, ['1']);
      expect(controller.hiddenCount, 1);
    });

    test('restores the sign-in and protected items after a restart', () async {
      expect(await controller.signIn(_id), isTrue);
      final restarted = build();
      await restarted.startup();
      expect(restarted.sessionEnabled, isTrue);
      expect(restarted.sessionStatus, Cs2SteamSessionStatus.failed);
      expect(imports.last, ['1', '2']);
      restarted.dispose();
    });

    test('falls back to the public listing for a different account', () async {
      expect(await controller.connect(_id), isTrue);
      session.who = '76561198000000001';
      expect(await controller.signIn(_id), isTrue);
      expect(controller.sessionStatus, Cs2SteamSessionStatus.otherAccount);
      expect(session.loads, 0);
      expect(imports.last, ['1']);
      expect(controller.hiddenCount, 1);
    });

    test('signing out ends the session and goes back to public reads', () async {
      expect(await controller.signIn(_id), isTrue);
      expect(await controller.signOut(), isTrue);
      expect(session.signedOut, isTrue);
      expect(controller.sessionEnabled, isFalse);
      expect(controller.sessionStatus, Cs2SteamSessionStatus.off);
      expect((jsonDecode(await file.readAsString()) as Map)['steamSession'], isNull);
    });
  });
}
