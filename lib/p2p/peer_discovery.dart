import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nsd/nsd.dart';

import 'peer_protocol.dart';

/// One peer visible on the local network via mDNS. [service] is the live
/// `Service` record; host + port are populated once the platform resolves the
/// record (happens automatically with `autoResolve: true`).
class DiscoveredPeer {
  DiscoveredPeer({
    required this.name,
    required this.service,
    required this.tokenPrefix,
  });

  /// The mDNS service name (instance name).
  final String name;

  /// The resolved service record reported by nsd.
  final Service service;

  /// First 16 hex chars of the peer's handshake token, from the TXT record.
  /// Used by the UI to surface only same-account peers.
  final String tokenPrefix;

  String get host => service.host ?? '';
  int get port => service.port ?? 0;
}

/// Wraps `nsd` to (a) advertise this device as a luma-sync service on the
/// local network and (b) browse for other luma-sync services.
///
/// Discovery is best-effort: on platforms where mDNS is restricted (e.g. an
/// unconfigured Windows firewall, or Android battery saver), browse simply
/// returns fewer/no results and the user falls back to manual host:port.
class PeerDiscovery {
  PeerDiscovery();

  Registration? _registration;
  Discovery? _discovery;
  bool _started = false;

  final StreamController<List<DiscoveredPeer>> _peers =
      StreamController<List<DiscoveredPeer>>.broadcast();
  Stream<List<DiscoveredPeer>> get peers => _peers.stream;

  final Map<String, DiscoveredPeer> _byName = {};

  /// Advertise [port] under service name [instanceName]. The TXT record
  /// carries [tokenPrefix] so other devices can see this is a same-account
  /// peer without leaking the email.
  Future<void> start({
    required String instanceName,
    required int port,
    required String tokenPrefix,
  }) async {
    if (_started) await stop();
    _started = true;

    // ---- Register ----------------------------------------------------------
    try {
      _registration = await register(Service(
        name: instanceName,
        type: kLumaPeerServiceType,
        port: port,
        txt: {'t': Uint8List.fromList(utf8.encode(tokenPrefix))},
      ));
    } catch (_) {
      // Registration failing is non-fatal: we can still browse.
    }

    // ---- Browse ------------------------------------------------------------
    try {
      _discovery = await startDiscovery(kLumaPeerServiceType);
      _discovery!.addServiceListener((service, status) {
        final name = service.name ?? '';
        if (name.isEmpty || name == instanceName) return;
        final txt = service.txt ?? const {};
        final raw = txt['t'];
        final t = raw == null
            ? ''
            : utf8.decode(raw, allowMalformed: true);
        switch (status) {
          case ServiceStatus.found:
            _byName[name] = DiscoveredPeer(
              name: name,
              service: service,
              tokenPrefix: t,
            );
          case ServiceStatus.lost:
            _byName.remove(name);
        }
        _peers.add(_byName.values.toList());
      });
    } catch (_) {
      // Browse failing is non-fatal too.
    }
  }

  Future<void> stop() async {
    _started = false;
    _byName.clear();
    if (_discovery != null) {
      try {
        await stopDiscovery(_discovery!);
      } catch (_) {}
      _discovery = null;
    }
    if (_registration != null) {
      try {
        await unregister(_registration!);
      } catch (_) {}
      _registration = null;
    }
  }
}
