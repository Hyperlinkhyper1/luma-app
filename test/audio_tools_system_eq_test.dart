import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/audio_tools/audio_tools_page.dart';
import 'package:luma/features/plugins/installed/audio_tools/audio_tools_repository.dart';
import 'package:luma/features/plugins/installed/audio_tools/audio_tools_scope.dart';
import 'package:luma/features/plugins/installed/audio_tools/audio_types.dart';
import 'package:luma/features/plugins/installed/audio_tools/eq.dart';
import 'package:luma/features/plugins/installed/audio_tools/system_eq.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:luma/theme/theme_style.dart';

const _micId = '{0.0.1.00000000}.{78047f01-3c0e-4893-b7e8-150482cd3d14}';
const _mic = AudioDevice(id: _micId, name: 'Microfoon (MICUSB1)');
const _speakers = AudioDevice(id: 'spk', name: 'Speakers');
const _devices = AudioDevices(
  inputs: [_mic],
  outputs: [_speakers],
  defaultInputId: _micId,
  defaultOutputId: 'spk',
);

/// Stands in for luma_apo_setup.exe: no process, no UAC, no registry.
class _FakeSystemEq extends SystemEq {
  _FakeSystemEq({this.result = SystemEqResult.ok});

  SystemEqResult result;
  bool current = true;
  final endpoints = <String>{};
  final installs = <String>[];
  final writes = <Uint8List>[];

  @override
  bool get available => true;

  @override
  Future<SystemEqStatus> status() async => SystemEqStatus(
    installed: endpoints.isNotEmpty,
    current: current,
    endpoints: {...endpoints},
  );

  @override
  Future<SystemEqResult> install(String deviceId) async {
    installs.add(deviceId);
    if (result.succeeded) {
      endpoints.add(deviceId.toLowerCase());
      current = true;
    }
    return result;
  }

  @override
  Future<SystemEqResult> uninstall(String deviceId) async {
    endpoints.remove(deviceId.toLowerCase());
    return result;
  }

  @override
  Future<void> writeConfig(Uint8List bytes) async => writes.add(bytes);

  bool get lastWriteEnabled =>
      ByteData.sublistView(writes.last).getUint32(8, Endian.little) == 1;
}

Widget _wrap(AudioToolsRepository repo) => MaterialApp(
  theme: LumaTheme.from(Brightness.dark, null, LumaThemeStyle.standard),
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  home: Scaffold(
    body: AudioToolsScope(repository: repo, child: const AudioToolsPage()),
  ),
);

void main() {
  group('SystemEqConfig.encode', () {
    test('lays bytes out exactly as eq_config.h parses them', () {
      final eq = EqPreset.radio.settings;
      final bytes = SystemEqConfig.encode(eq, enabled: true);
      expect(bytes.length, 340);
      final d = ByteData.sublistView(bytes);
      expect(d.getUint32(0, Endian.little), 0x4F50414C);
      expect(d.getUint32(4, Endian.little), 1);
      expect(d.getUint32(8, Endian.little), 1);
      expect(d.getFloat32(12, Endian.little), eq.preampDb);
      expect(d.getUint32(16, Endian.little), eq.bands.length);
      for (var i = 0; i < eq.bands.length; i++) {
        final b = eq.bands[i];
        final o = 20 + i * 20;
        expect(d.getUint32(o, Endian.little), b.type.index);
        expect(d.getUint32(o + 4, Endian.little), b.enabled ? 1 : 0);
        expect(d.getFloat32(o + 8, Endian.little), closeTo(b.frequency, 1e-3));
        expect(d.getFloat32(o + 12, Endian.little), closeTo(b.gainDb, 1e-6));
        expect(d.getFloat32(o + 16, Endian.little), closeTo(b.q, 1e-6));
      }
      expect(
        bytes.sublist(20 + eq.bands.length * 20).every((b) => b == 0),
        isTrue,
      );
    });

    test('band type indices match the C++ enum', () {
      expect(EqBandType.values.map((t) => t.name), [
        'highPass',
        'lowShelf',
        'peak',
        'highShelf',
        'lowPass',
      ]);
    });

    test('never writes more bands than the APO reads', () {
      final many = EqSettings(
        bands: List.filled(
          20,
          const EqBand(type: EqBandType.peak, frequency: 1000),
        ),
      );
      final d = ByteData.sublistView(
        SystemEqConfig.encode(many, enabled: false),
      );
      expect(d.getUint32(16, Endian.little), 16);
      expect(d.getUint32(8, Endian.little), 0);
    });
  });

  test('helper exit codes and status json', () {
    expect(SystemEqResult.fromExitCode(0), SystemEqResult.ok);
    expect(SystemEqResult.fromExitCode(3), SystemEqResult.cancelled);
    expect(SystemEqResult.fromExitCode(5), SystemEqResult.restartNeeded);
    expect(SystemEqResult.fromExitCode(6), SystemEqResult.noDevice);
    expect(SystemEqResult.fromExitCode(7), SystemEqResult.incompatible);
    expect(SystemEqResult.fromExitCode(8), SystemEqResult.micNotRecording);
    expect(SystemEqResult.fromExitCode(-1), SystemEqResult.failed);
    final s = SystemEqStatus.fromJson({
      'installed': true,
      'current': false,
      'endpoints': ['{0.0.1.00000000}.{ABC}'],
    });
    expect(s.installed, isTrue);
    expect(s.current, isFalse);
    expect(s.endpoints, {'{0.0.1.00000000}.{abc}'});
  });

  group('repository', () {
    test(
      'installs on the default mic and keeps the curve file in sync',
      () async {
        final fake = _FakeSystemEq();
        final repo = AudioToolsRepository(devices: _devices, systemEq: fake);
        expect(repo.systemEqAvailable, isTrue);
        expect(repo.systemEqOnInput, isFalse);

        await repo.enableSystemEq();
        expect(fake.installs, [_micId]);
        expect(repo.systemEqOnInput, isTrue);
        expect(repo.systemEqResult, isNull);
        expect(fake.lastWriteEnabled, isTrue);

        final before = fake.writes.length;
        repo.applyPreset(EqPreset.deep);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(fake.writes.length, before + 1);
        expect(
          fake.writes.last,
          SystemEqConfig.encode(EqPreset.deep.settings, enabled: true),
        );

        repo.setSystemEqPaused(true);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(fake.lastWriteEnabled, isFalse);

        repo.setSystemEqPaused(false);
        repo.setBypass(true);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(
          fake.lastWriteEnabled,
          isFalse,
          reason: 'bypass reaches Windows too',
        );

        await repo.disableSystemEq();
        expect(repo.systemEqOnInput, isFalse);
        final settled = fake.writes.length;
        repo.applyPreset(EqPreset.clear);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(
          fake.writes.length,
          settled,
          reason: 'nothing to feed once removed',
        );
      },
    );

    test('a declined UAC prompt changes nothing and says so', () async {
      final fake = _FakeSystemEq(result: SystemEqResult.cancelled);
      final repo = AudioToolsRepository(devices: _devices, systemEq: fake);
      await repo.enableSystemEq();
      expect(repo.systemEqOnInput, isFalse);
      expect(repo.systemEqResult, SystemEqResult.cancelled);
      expect(fake.writes, isEmpty);
    });

    test('restart-needed still counts as installed', () async {
      final fake = _FakeSystemEq(result: SystemEqResult.restartNeeded);
      final repo = AudioToolsRepository(devices: _devices, systemEq: fake);
      await repo.enableSystemEq();
      expect(repo.systemEqOnInput, isTrue);
      expect(repo.systemEqResult, SystemEqResult.restartNeeded);
    });
  });

  testWidgets('the card turns the mic EQ on and offers pause and restore', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = _FakeSystemEq();
    final repo = AudioToolsRepository(devices: _devices, systemEq: fake);
    await tester.pumpWidget(_wrap(repo));
    expect(tester.takeException(), isNull);
    expect(find.text('Get VB-CABLE'), findsNothing);
    expect(find.textContaining('MICUSB1'), findsWidgets);

    await tester.tap(find.text('Turn on for this mic'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.installs, [_micId]);
    expect(find.text('EQ in every app'), findsOneWidget);
    expect(find.text('On for ${_mic.name}'), findsOneWidget);
    expect(find.text('Turn off and restore'), findsOneWidget);

    fake.current = false;
    await repo.refreshSystemEq();
    await tester.pump();
    expect(find.text('Update'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });
}
