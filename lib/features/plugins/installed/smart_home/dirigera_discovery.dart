import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nsd/nsd.dart';

import 'dirigera_api.dart';

class DiscoveredDirigeraHub {
  const DiscoveredDirigeraHub({required this.name, required this.host});

  final String name;
  final String host;
}

abstract class DirigeraDiscovery {
  Future<List<DiscoveredDirigeraHub>> findHubs();
}

class NsdDirigeraDiscovery implements DirigeraDiscovery {
  const NsdDirigeraDiscovery();

  @override
  Future<List<DiscoveredDirigeraHub>> findHubs() async {
    final discovery = await startDiscovery(
      '_ihsp._tcp',
      ipLookupType: IpLookupType.v4,
    );
    try {
      await Future<void>.delayed(const Duration(seconds: 5));
      return hubsFromServices(discovery.services);
    } finally {
      await stopDiscovery(discovery);
    }
  }

  static List<DiscoveredDirigeraHub> hubsFromServices(
    Iterable<Service> services,
  ) {
    final hubs = <String, DiscoveredDirigeraHub>{};
    for (final service in services) {
      if (service.port != 8443) continue;
      final type = service.txt?['type'];
      if (type != null &&
          utf8.decode(type, allowMalformed: true) != 'DIRIGERA') {
        continue;
      }
      final addresses = service.addresses ?? const <InternetAddress>[];
      final host = addresses
          .where(LocalDirigeraApi.isPrivateIpv4)
          .map((address) => address.address)
          .firstOrNull;
      final fallback = InternetAddress.tryParse(service.host ?? '');
      final address =
          host ??
          (fallback != null && LocalDirigeraApi.isPrivateIpv4(fallback)
              ? fallback.address
              : null);
      if (address == null) continue;
      hubs[address] = DiscoveredDirigeraHub(
        name: service.name?.trim().isNotEmpty == true
            ? service.name!.trim()
            : 'DIRIGERA hub',
        host: address,
      );
    }
    return hubs.values.toList(growable: false);
  }
}
