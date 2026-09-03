import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/wifi_speed_test/network_details.dart';
import 'package:luma/features/plugins/installed/wifi_speed_test/wifi_speed_test_repository.dart';

SpeedTestResult _result({
  String? networkKind,
  String? networkName,
  String? networkGeneration,
}) =>
    SpeedTestResult(
      id: 'r1',
      testedAt: DateTime(2026, 7, 21, 22, 50),
      downloadMbps: 9.8,
      uploadMbps: 12.8,
      latencyMs: 135,
      networkKind: networkKind,
      networkName: networkName,
      networkGeneration: networkGeneration,
    );

void main() {
  group('SpeedTestResult network fields', () {
    test('round-trips a Wi-Fi result through JSON', () {
      final json = _result(networkKind: 'wifi', networkName: 'Nebula').toJson();
      final restored = SpeedTestResult.fromJson(json);

      expect(restored.network, NetworkKind.wifi);
      expect(restored.networkName, 'Nebula');
      expect(restored.networkLabelText, 'Wi-Fi · Nebula');
    });

    test('round-trips a mobile result with its generation', () {
      final json =
          _result(networkKind: 'cellular', networkGeneration: '5G').toJson();
      final restored = SpeedTestResult.fromJson(json);

      expect(restored.network, NetworkKind.cellular);
      expect(restored.networkGeneration, '5G');
      expect(restored.networkLabelText, 'Mobile data · 5G');
    });

    test('reads results saved before the network fields existed', () {
      final legacy = <String, dynamic>{
        'id': 'old',
        'testedAt': DateTime(2026, 7, 20, 14, 40).toIso8601String(),
        'downloadMbps': 14.3,
        'uploadMbps': 4.1,
        'latencyMs': 152,
      };

      final restored = SpeedTestResult.fromJson(legacy);

      expect(restored.hasNetwork, isFalse);
      expect(restored.downloadMbps, 14.3);
      expect(restored.network, NetworkKind.unknown);
    });

    test('omits network keys entirely when nothing was detected', () {
      expect(_result().toJson().containsKey('networkKind'), isFalse);
      expect(_result().toJson().containsKey('networkName'), isFalse);
      expect(_result().toJson().containsKey('networkGeneration'), isFalse);
    });
  });

  group('networkLabel', () {
    test('falls back to the bare transport when the name is missing', () {
      expect(networkLabel(kind: NetworkKind.wifi), 'Wi-Fi');
      expect(networkLabel(kind: NetworkKind.cellular), 'Mobile data');
      expect(networkLabel(kind: NetworkKind.ethernet), 'Ethernet');
      expect(networkLabel(kind: NetworkKind.offline), 'No connection');
      expect(networkLabel(), 'Unknown network');
    });

    test('keeps the generation out of the Wi-Fi label', () {
      expect(
        networkLabel(kind: NetworkKind.wifi, name: 'Home', generation: '5G'),
        'Wi-Fi · Home',
      );
    });

    test('appends the carrier name after the generation', () {
      expect(
        networkLabel(
          kind: NetworkKind.cellular,
          name: 'Odido',
          generation: '4G',
        ),
        'Mobile data · 4G · Odido',
      );
    });
  });

  group('networkKindFromId', () {
    test('maps every stored id back to its kind', () {
      expect(networkKindFromId('wifi'), NetworkKind.wifi);
      expect(networkKindFromId('cellular'), NetworkKind.cellular);
      expect(networkKindFromId('ethernet'), NetworkKind.ethernet);
      expect(networkKindFromId('vpn'), NetworkKind.vpn);
      expect(networkKindFromId('offline'), NetworkKind.offline);
      expect(networkKindFromId(null), NetworkKind.unknown);
      expect(networkKindFromId('carrier-pigeon'), NetworkKind.unknown);
    });

    test('enum names survive the round trip used when saving', () {
      for (final kind in NetworkKind.values) {
        expect(networkKindFromId(kind.name), kind);
      }
    });
  });

  group('NetworkProbe.cleanName', () {
    test('strips the quotes Android wraps around an SSID', () {
      expect(NetworkProbe.cleanName('"Nebula 5G"'), 'Nebula 5G');
    });

    test('treats a redacted SSID as no name at all', () {
      expect(NetworkProbe.cleanName('<unknown ssid>'), isNull);
      expect(NetworkProbe.cleanName('"<unknown ssid>"'), isNull);
      expect(NetworkProbe.cleanName('0x'), isNull);
      expect(NetworkProbe.cleanName('  '), isNull);
      expect(NetworkProbe.cleanName(null), isNull);
    });

    test('leaves an ordinary name untouched', () {
      expect(NetworkProbe.cleanName('KPN-8A21F3'), 'KPN-8A21F3');
    });
  });

  group('NetworkProbe.kindForInterfaceName', () {
    test('recognises the usual interface names', () {
      expect(NetworkProbe.kindForInterfaceName('wlan0'), NetworkKind.wifi);
      expect(NetworkProbe.kindForInterfaceName('Wi-Fi'), NetworkKind.wifi);
      expect(
        NetworkProbe.kindForInterfaceName('rmnet_data0'),
        NetworkKind.cellular,
      );
      expect(NetworkProbe.kindForInterfaceName('eth0'), NetworkKind.ethernet);
      expect(NetworkProbe.kindForInterfaceName('Ethernet'), NetworkKind.ethernet);
      expect(NetworkProbe.kindForInterfaceName('tun0'), NetworkKind.unknown);
    });
  });

  group('NetworkDetails', () {
    test('reads the map the Android channel sends back', () {
      final details = NetworkDetails.fromChannel(const {
        'transport': 'wifi',
        'ssid': '"Nebula"',
        'generation': null,
        'granted': true,
      });

      expect(details.kind, NetworkKind.wifi);
      expect(details.name, 'Nebula');
      expect(details.label, 'Wi-Fi · Nebula');
      expect(details.needsPermission, isFalse);
    });

    test('asks for permission when the name was withheld', () {
      final details = NetworkDetails.fromChannel(const {
        'transport': 'wifi',
        'ssid': '<unknown ssid>',
        'generation': null,
        'granted': false,
      });

      expect(details.isNamed, isFalse);
      expect(details.label, 'Wi-Fi');
      expect(details.needsPermission, isTrue);
    });

    test('never asks for permission off Wi-Fi and mobile', () {
      const details = NetworkDetails(
        kind: NetworkKind.ethernet,
        detailsAllowed: false,
      );

      expect(details.needsPermission, isFalse);
    });
  });
}
