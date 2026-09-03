import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';

enum NetworkKind { wifi, cellular, ethernet, vpn, offline, unknown }

NetworkKind networkKindFromId(String? id) {
  switch (id) {
    case 'wifi':
      return NetworkKind.wifi;
    case 'cellular':
      return NetworkKind.cellular;
    case 'ethernet':
      return NetworkKind.ethernet;
    case 'vpn':
      return NetworkKind.vpn;
    case 'offline':
      return NetworkKind.offline;
    default:
      return NetworkKind.unknown;
  }
}

String networkLabel({
  NetworkKind kind = NetworkKind.unknown,
  String? name,
  String? generation,
}) {
  final hasName = name != null && name.isNotEmpty;
  final hasGeneration = generation != null && generation.isNotEmpty;

  switch (kind) {
    case NetworkKind.wifi:
      return hasName ? 'Wi-Fi · $name' : 'Wi-Fi';
    case NetworkKind.cellular:
      final network =
          hasGeneration ? 'Mobile data · $generation' : 'Mobile data';
      return hasName ? '$network · $name' : network;
    case NetworkKind.ethernet:
      return hasName ? 'Ethernet · $name' : 'Ethernet';
    case NetworkKind.vpn:
      return 'VPN';
    case NetworkKind.offline:
      return 'No connection';
    case NetworkKind.unknown:
      return hasName ? name : 'Unknown network';
  }
}

class NetworkDetails {
  const NetworkDetails({
    this.kind = NetworkKind.unknown,
    this.name,
    this.generation,
    this.detailsAllowed = true,
  });

  final NetworkKind kind;
  final String? name;
  final String? generation;
  final bool detailsAllowed;

  String get label =>
      networkLabel(kind: kind, name: name, generation: generation);

  bool get isNamed => name != null && name!.isNotEmpty;

  bool get needsPermission {
    if (detailsAllowed) return false;
    switch (kind) {
      case NetworkKind.wifi:
        return !isNamed;
      case NetworkKind.cellular:
        return generation == null || generation!.isEmpty;
      default:
        return false;
    }
  }

  factory NetworkDetails.fromChannel(Map<String, Object?> raw) =>
      NetworkDetails(
        kind: networkKindFromId(raw['transport'] as String?),
        name: NetworkProbe.cleanName(raw['ssid'] as String?),
        generation: raw['generation'] as String?,
        detailsAllowed: raw['granted'] as bool? ?? true,
      );
}

class NetworkProbe {
  const NetworkProbe._();

  static const MethodChannel channel = MethodChannel('luma/network_details');

  static Future<NetworkDetails> describe() async {
    if (Platform.isAndroid) {
      try {
        final raw = await channel.invokeMapMethod<String, Object?>('describe');
        if (raw != null) return NetworkDetails.fromChannel(raw);
      } catch (_) {}
    }
    return _describeWithoutChannel();
  }

  static Future<bool> requestDetailsPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await channel.invokeMethod<bool>('requestPermissions') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<NetworkDetails> _describeWithoutChannel() async {
    String? ssid;
    try {
      ssid = cleanName(await NetworkInfo().getWifiName());
    } catch (_) {}
    if (ssid != null) {
      return NetworkDetails(kind: NetworkKind.wifi, name: ssid);
    }
    return NetworkDetails(kind: await _kindFromInterfaces());
  }

  static Future<NetworkKind> _kindFromInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final found = interfaces
          .map((i) => kindForInterfaceName(i.name))
          .where((k) => k != NetworkKind.unknown)
          .toSet();
      for (final kind in [
        NetworkKind.cellular,
        NetworkKind.wifi,
        NetworkKind.ethernet,
      ]) {
        if (found.contains(kind)) return kind;
      }
    } catch (_) {}
    return NetworkKind.unknown;
  }

  @visibleForTesting
  static NetworkKind kindForInterfaceName(String name) {
    final n = name.toLowerCase();
    if (n.startsWith('rmnet') ||
        n.startsWith('ccmni') ||
        n.startsWith('pdp_ip') ||
        n.startsWith('wwan') ||
        n.contains('cellular') ||
        n.contains('mobile')) {
      return NetworkKind.cellular;
    }
    if (n.startsWith('wl') ||
        n.contains('wi-fi') ||
        n.contains('wifi') ||
        n.contains('wireless')) {
      return NetworkKind.wifi;
    }
    if (n.startsWith('eth') ||
        n.startsWith('en') ||
        n.startsWith('em') ||
        n.contains('ethernet') ||
        n.contains('local area connection')) {
      return NetworkKind.ethernet;
    }
    return NetworkKind.unknown;
  }

  @visibleForTesting
  static String? cleanName(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.isEmpty) return null;
    final lower = s.toLowerCase();
    if (lower == '<unknown ssid>' ||
        lower == 'unknown ssid' ||
        lower == '0x' ||
        lower == 'null') {
      return null;
    }
    return s;
  }
}
