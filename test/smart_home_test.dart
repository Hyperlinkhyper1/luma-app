import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nsd/nsd.dart';
import 'package:luma/features/plugins/installed/smart_home/dirigera_api.dart';
import 'package:luma/features/plugins/installed/smart_home/dirigera_discovery.dart';
import 'package:luma/features/plugins/installed/smart_home/smart_home_page.dart';
import 'package:luma/features/plugins/installed/smart_home/smart_home_repository.dart';
import 'package:luma/features/plugins/installed/smart_home/smart_home_preset.dart';
import 'package:luma/features/plugins/installed/smart_home/smart_home_scope.dart';
import 'package:luma/features/plugins/installed/smart_home/smart_light.dart';
import 'package:luma/theme/luma_theme.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class _FakeDiscovery implements DirigeraDiscovery {
  int searches = 0;
  List<DiscoveredDirigeraHub> hubs = const [
    DiscoveredDirigeraHub(name: 'DIRIGERA', host: '192.168.1.30'),
  ];

  @override
  Future<List<DiscoveredDirigeraHub>> findHubs() async {
    searches++;
    return hubs;
  }
}

class _MemoryCredentials implements SmartHomeCredentialStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;

  @override
  Future<void> delete() async => value = null;
}

class _MemoryPresets implements SmartHomePresetStore {
  List<SmartHomePreset> values = [];

  @override
  Future<List<SmartHomePreset>> load() async => [...values];

  @override
  Future<void> save(List<SmartHomePreset> presets) async =>
      values = [...presets];
}

class _FakeHub implements DirigeraApi {
  final calls = <Map<String, Object>>[];
  final lightIds = <String>[];
  bool failWrite = false;
  bool timeOutPairing = false;
  String? pairedHost;
  final failLightIds = <String>{};
  List<SmartLight> lights = [
    SmartLight.fromJson({
      'id': 'lamp-1',
      'type': 'light',
      'isReachable': true,
      'attributes': {
        'customName': 'Desk lamp',
        'isOn': false,
        'lightLevel': 35,
        'colorTemperature': 2700,
        'colorTemperatureMin': 4000,
        'colorTemperatureMax': 2200,
      },
      'capabilities': {
        'canReceive': ['isOn', 'lightLevel', 'colorTemperature'],
      },
    }),
  ];

  @override
  Future<HubPairingChallenge> beginPairing(String host) async {
    pairedHost = host;
    if (timeOutPairing) throw TimeoutException('Future not completed');
    return HubPairingChallenge(host, 'code', 'verifier', 'fingerprint');
  }

  @override
  Future<HubConnection> completePairing(HubPairingChallenge challenge) async =>
      HubConnection(
        challenge.host,
        'private-token',
        challenge.certificateFingerprint,
      );

  @override
  Future<List<SmartLight>> listLights(HubConnection connection) async => lights;

  @override
  Future<void> setAttributes(
    HubConnection connection,
    String lightId,
    Map<String, Object> attributes,
  ) async {
    if (failWrite) throw StateError('unreachable');
    if (failLightIds.contains(lightId)) throw StateError('unreachable');
    lightIds.add(lightId);
    calls.add(attributes);
  }
}

void main() {
  test('discovery accepts only private DIRIGERA service addresses', () {
    final hubs = NsdDirigeraDiscovery.hubsFromServices([
      Service(
        name: 'Living room hub',
        port: 8443,
        txt: {'type': Uint8List.fromList('DIRIGERA'.codeUnits)},
        addresses: [InternetAddress('192.168.1.30')],
      ),
      Service(
        name: 'Other device',
        port: 8443,
        txt: {'type': Uint8List.fromList('OTHER'.codeUnits)},
        addresses: [InternetAddress('192.168.1.31')],
      ),
      Service(
        name: 'Public address',
        port: 8443,
        addresses: [InternetAddress('8.8.8.8')],
      ),
    ]);
    expect(hubs.map((hub) => hub.name), ['Living room hub']);
    expect(hubs.single.host, '192.168.1.30');
  });

  test(
    'discovery supplies a selectable hub and hides technical timeouts',
    () async {
      final hub = _FakeHub()..timeOutPairing = true;
      final discovery = _FakeDiscovery();
      final repo = SmartHomeRepository(
        api: hub,
        discovery: discovery,
        credentials: _MemoryCredentials(),
        presetStore: _MemoryPresets(),
      );
      await Future<void>.delayed(Duration.zero);
      await repo.discoverHubs();
      expect(discovery.searches, 1);
      expect(repo.discoveredHubs.single.host, '192.168.1.30');
      await repo.beginPairing(repo.discoveredHubs.single.host);
      expect(hub.pairedHost, '192.168.1.30');
      expect(repo.error, contains('did not respond'));
      expect(repo.error, isNot(contains('TimeoutException')));
      repo.dispose();
    },
  );

  testWidgets('unpaired page finds a hub and pairs from the result', (
    tester,
  ) async {
    final hub = _FakeHub();
    final discovery = _FakeDiscovery();
    final repo = SmartHomeRepository(
      api: hub,
      discovery: discovery,
      credentials: _MemoryCredentials(),
      presetStore: _MemoryPresets(),
    );
    await tester.pumpWidget(
      SmartHomeScope(
        repository: repo,
        child: MaterialApp(
          theme: LumaTheme.from(Brightness.light),
          home: const Scaffold(body: SmartHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(discovery.searches, 1);
    await tester.tap(find.text('DIRIGERA'));
    await tester.pumpAndSettle();
    expect(hub.pairedHost, '192.168.1.30');
    expect(find.text('I pressed the button'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    repo.dispose();
  });

  test('preset JSON preserves each lamp’s brightness and color', () {
    const preset = SmartHomePreset(
      id: 'one',
      name: 'Evening',
      lights: [
        PresetLightSetting(
          lightId: 'lamp-1',
          brightness: 35,
          hue: 270,
          saturation: 0.6,
        ),
      ],
    );
    final restored = SmartHomePreset.fromJson(preset.toJson());
    expect(restored.name, 'Evening');
    expect(restored.lights.single.brightness, 35);
    expect(restored.lights.single.hue, 270);
    expect(restored.lights.single.saturation, 0.6);
  });

  test('shows IKEA lights only from a mixed DIRIGERA device list', () {
    final lights = parseDirigeraLights([
      {
        'id': 'other',
        'type': 'light',
        'attributes': {'manufacturer': 'Other', 'customName': 'Other bulb'},
      },
      {
        'id': 'ikea',
        'type': 'light',
        'attributes': {
          'manufacturer': 'IKEA of Sweden',
          'customName': 'IKEA bulb',
        },
      },
      {
        'id': 'switch',
        'type': 'outlet',
        'attributes': {'manufacturer': 'IKEA of Sweden'},
      },
    ]);
    expect(lights.map((light) => light.id), ['ikea']);
  });

  test('parses only supported lamp controls from hub capabilities', () {
    final light = SmartLight.fromJson({
      'id': 'one',
      'attributes': {'model': 'TRADFRI', 'isOn': true, 'lightLevel': 80},
      'capabilities': {
        'canReceive': ['isOn'],
      },
    });
    expect(light.name, 'TRADFRI');
    expect(light.canToggle, isTrue);
    expect(light.canDim, isFalse);
    expect(light.canSetTemperature, isFalse);
    expect(light.canSetColor, isFalse);
  });

  test(
    'pairing saves token securely and controls only supported attributes',
    () async {
      final hub = _FakeHub();
      final credentials = _MemoryCredentials();
      final repo = SmartHomeRepository(
        api: hub,
        credentials: credentials,
        presetStore: _MemoryPresets(),
      );
      await Future<void>.delayed(Duration.zero);

      await repo.beginPairing('192.168.1.20');
      expect(repo.pairingStarted, isTrue);
      await repo.completePairing();
      expect(repo.paired, isTrue);
      expect(repo.lights.single.name, 'Desk lamp');
      expect(credentials.value, contains('private-token'));

      await repo.setOn(repo.lights.single, true);
      await repo.setBrightness(repo.lights.single, 50);
      await repo.setBrightness(repo.lights.single, 0);
      await repo.setTemperature(repo.lights.single, 2800);
      await repo.setColor(repo.lights.single, 240, 1);
      expect(hub.calls, [
        {'isOn': true},
        {'lightLevel': 50},
        {'colorTemperature': 2800},
      ]);

      await repo.disconnect();
      expect(repo.paired, isFalse);
      expect(credentials.value, isNull);
      repo.dispose();
    },
  );

  test(
    'failed lamp command reports an error and keeps the hub paired',
    () async {
      final hub = _FakeHub();
      final repo = SmartHomeRepository(
        api: hub,
        credentials: _MemoryCredentials(),
        presetStore: _MemoryPresets(),
      );
      await Future<void>.delayed(Duration.zero);
      await repo.beginPairing('192.168.1.20');
      await repo.completePairing();
      hub.failWrite = true;

      await repo.setOn(repo.lights.single, true);
      expect(repo.paired, isTrue);
      expect(repo.error, contains('Could not reach'));
      expect(repo.isBusy('lamp-1'), isFalse);
      repo.dispose();
    },
  );

  test(
    'presets persist and turn on selected lamps with saved settings',
    () async {
      final hub = _FakeHub();
      hub.lights.add(
        SmartLight.fromJson({
          'id': 'lamp-2',
          'attributes': {
            'customName': 'Bedside lamp',
            'isOn': false,
            'lightLevel': 60,
          },
          'capabilities': {
            'canReceive': ['isOn', 'lightLevel'],
          },
        }),
      );
      hub.lights[0] = SmartLight.fromJson({
        'id': 'lamp-1',
        'attributes': {
          'customName': 'Desk lamp',
          'isOn': false,
          'lightLevel': 35,
          'colorHue': 10,
          'colorSaturation': 0.8,
        },
        'capabilities': {
          'canReceive': ['isOn', 'lightLevel', 'colorHue', 'colorSaturation'],
        },
      });
      final credentials = _MemoryCredentials();
      final presets = _MemoryPresets();
      final repo = SmartHomeRepository(
        api: hub,
        credentials: credentials,
        presetStore: presets,
      );
      await Future<void>.delayed(Duration.zero);
      await repo.beginPairing('192.168.1.20');
      await repo.completePairing();

      final saved = await repo.savePreset(
        name: 'Evening',
        lights: const [
          PresetLightSetting(
            lightId: 'lamp-1',
            brightness: 25,
            hue: 260,
            saturation: 0.7,
          ),
          PresetLightSetting(lightId: 'lamp-2', brightness: 55),
        ],
      );
      expect(saved, isTrue);
      expect(presets.values.single.name, 'Evening');
      await repo.activatePreset(repo.presets.single);
      expect(repo.error, isNull);
      expect(hub.lightIds, ['lamp-1', 'lamp-1', 'lamp-1', 'lamp-2', 'lamp-2']);
      expect(hub.calls, [
        {'isOn': true},
        {'lightLevel': 25},
        {'colorHue': 260, 'colorSaturation': 0.7},
        {'isOn': true},
        {'lightLevel': 55},
      ]);
      repo.dispose();

      final restored = SmartHomeRepository(
        api: hub,
        credentials: credentials,
        presetStore: presets,
      );
      await Future<void>.delayed(Duration.zero);
      expect(restored.presets.single.name, 'Evening');
      expect(restored.presets.single.lights.length, 2);
      restored.dispose();
    },
  );

  test('preset activation continues after one lamp fails', () async {
    final hub = _FakeHub();
    hub.lights.add(
      SmartLight.fromJson({
        'id': 'lamp-2',
        'attributes': {'customName': 'Bedside lamp', 'isOn': false},
        'capabilities': {
          'canReceive': ['isOn'],
        },
      }),
    );
    final repo = SmartHomeRepository(
      api: hub,
      credentials: _MemoryCredentials(),
      presetStore: _MemoryPresets(),
    );
    await Future<void>.delayed(Duration.zero);
    await repo.beginPairing('192.168.1.20');
    await repo.completePairing();
    await repo.savePreset(
      name: 'All on',
      lights: const [
        PresetLightSetting(lightId: 'lamp-1', brightness: 30),
        PresetLightSetting(lightId: 'lamp-2'),
      ],
    );
    hub.failLightIds.add('lamp-1');

    await repo.activatePreset(repo.presets.single);
    expect(hub.lightIds, ['lamp-2']);
    expect(hub.calls, [
      {'isOn': true},
    ]);
    expect(repo.error, contains('Desk lamp'));
    expect(repo.busy, isFalse);
    repo.dispose();
  });

  test('presets can be edited and deleted without changing lamps', () async {
    final hub = _FakeHub();
    final presets = _MemoryPresets();
    final repo = SmartHomeRepository(
      api: hub,
      credentials: _MemoryCredentials(),
      presetStore: presets,
    );
    await Future<void>.delayed(Duration.zero);
    await repo.beginPairing('192.168.1.20');
    await repo.completePairing();
    expect(
      await repo.savePreset(
        name: 'Bright',
        lights: const [PresetLightSetting(lightId: 'lamp-1', brightness: 90)],
      ),
      isTrue,
    );
    final id = repo.presets.single.id;

    expect(
      await repo.savePreset(
        id: id,
        name: 'Dim',
        lights: const [PresetLightSetting(lightId: 'lamp-1', brightness: 20)],
      ),
      isTrue,
    );
    expect(repo.presets.single.id, id);
    expect(repo.presets.single.name, 'Dim');
    expect(repo.presets.single.lights.single.brightness, 20);
    expect(presets.values.single.name, 'Dim');
    expect(hub.calls, isEmpty);

    expect(await repo.deletePreset(id), isTrue);
    expect(repo.presets, isEmpty);
    expect(presets.values, isEmpty);
    repo.dispose();
  });

  testWidgets('creates a preset and activates it from the top of the page', (
    tester,
  ) async {
    final hub = _FakeHub();
    final credentials = _MemoryCredentials()
      ..value = jsonEncode(
        const HubConnection('192.168.1.20', 'token', 'pin').toJson(),
      );
    final presets = _MemoryPresets();
    final repo = SmartHomeRepository(
      api: hub,
      credentials: credentials,
      presetStore: presets,
    );
    await tester.pumpWidget(
      SmartHomeScope(
        repository: repo,
        child: MaterialApp(
          theme: LumaTheme.from(Brightness.light),
          home: const Scaffold(body: SmartHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New preset'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Preset name'),
      'Reading',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save preset'));
    await tester.pumpAndSettle();
    expect(presets.values.single.name, 'Reading');

    await tester.tap(find.text('Reading'));
    await tester.pumpAndSettle();
    expect(hub.calls, [
      {'isOn': true},
      {'lightLevel': 35},
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
    repo.dispose();
  });
}
