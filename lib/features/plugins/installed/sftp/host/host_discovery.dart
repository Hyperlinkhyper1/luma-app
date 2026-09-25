import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart';

import 'host_protocol.dart';

/// The mDNS service type a hosting luma device advertises under. Separate
/// from the peer-sync type (`_luma-sync._tcp`): that one is for devices on the
/// same account, this one is for anyone on the network with the pairing
/// password.
const String kLumaHostServiceType = '_luma-host._tcp';

/// A luma device on this network that is hosting right now.
///
/// Discovery only saves typing the address. It proves nothing: whoever
/// answers still has to complete the handshake with the pairing password, so
/// a device pretending to be a host on the LAN gets no further than a wrong
/// guess would.
@immutable
class DiscoveredHost {
  const DiscoveredHost({
    required this.id,
    required this.deviceName,
    required this.address,
    required this.port,
    required this.version,
  });

  /// The mDNS instance name — unique per advertisement.
  final String id;

  /// What the host calls itself, from its TXT record.
  final String deviceName;

  /// An IPv4 address when the platform resolved one, else the host name the
  /// record carried.
  final String address;
  final int port;

  /// The host's protocol version, so a mismatch can be flagged before anyone
  /// types a password into it.
  final int version;

  bool get compatible => version == kHostProtocolVersion;

  /// Reads a resolved nsd record. Returns null for one that is not usable yet
  /// (no port or address) or does not carry this protocol's TXT keys.
  static DiscoveredHost? fromService(Service service) {
    final id = service.name ?? '';
    final port = service.port ?? 0;
    if (id.isEmpty || port <= 0 || port > 65535) return null;

    String? address;
    for (final candidate in service.addresses ?? const <InternetAddress>[]) {
      if (candidate.type == InternetAddressType.IPv4 &&
          !candidate.isLoopback &&
          !candidate.isLinkLocal) {
        address = candidate.address;
        break;
      }
    }
    address ??= _stripTrailingDot(service.host ?? '');
    if (address.isEmpty) return null;

    final txt = service.txt ?? const <String, Uint8List?>{};
    final name = _txt(txt, 'n');
    final version = int.tryParse(_txt(txt, 'v') ?? '') ?? 0;
    return DiscoveredHost(
      id: id,
      deviceName: (name == null || name.trim().isEmpty) ? address : name.trim(),
      address: address,
      port: port,
      version: version,
    );
  }

  static String? _txt(Map<String, Uint8List?> txt, String key) {
    final raw = txt[key];
    return raw == null ? null : utf8.decode(raw, allowMalformed: true);
  }

  static String _stripTrailingDot(String host) =>
      host.endsWith('.') ? host.substring(0, host.length - 1) : host;
}

/// Announces one running [SftpHostServer] on the local network.
///
/// Best effort throughout: where mDNS is unavailable (Linux has no nsd
/// backend, a firewall may block it) hosting still works and the other device
/// types the address by hand, exactly as before.
class HostAdvertiser {
  Registration? _registration;
  final Set<String> _names = {};

  /// Bumped by every start and stop, so a registration that completes after
  /// hosting already stopped is withdrawn instead of left on the network.
  int _generation = 0;

  /// Instance names this app is advertising, so its own browser can leave
  /// them out — a device should not offer to connect to itself.
  static final Set<String> ownInstanceNames = {};

  Future<void> start({required int port, required String deviceName}) async {
    await stop();
    final generation = ++_generation;
    final instance = '${_clean(deviceName)}-${_suffix()}';
    _own(instance);
    try {
      final registration = await register(
        Service(
          name: instance,
          type: kLumaHostServiceType,
          port: port,
          txt: {
            'n': Uint8List.fromList(utf8.encode(deviceName)),
            'v': Uint8List.fromList(utf8.encode('$kHostProtocolVersion')),
          },
        ),
      );
      // The platform may rename the instance to avoid a clash; the browser
      // has to recognise that name as this device's too.
      final registered = registration.service.name;
      if (registered != null) _own(registered);
      if (generation != _generation) {
        await _withdraw(registration);
        return;
      }
      _registration = registration;
    } catch (e) {
      if (generation == _generation) _disown();
      debugPrint('luma host: not advertised on the network: $e');
    }
  }

  Future<void> stop() async {
    _generation++;
    final registration = _registration;
    _registration = null;
    if (registration != null) await _withdraw(registration);
    _disown();
  }

  Future<void> _withdraw(Registration registration) async {
    try {
      await unregister(registration);
    } catch (_) {
      // Already gone with the network or the platform service.
    }
  }

  void _own(String name) {
    _names.add(name);
    ownInstanceNames.add(name);
  }

  void _disown() {
    ownInstanceNames.removeAll(_names);
    _names.clear();
  }

  /// mDNS instance names are limited to 63 bytes and read best as plain
  /// text, so the host name is trimmed to something safe.
  static String _clean(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    final base = cleaned.isEmpty ? 'luma' : cleaned;
    return base.length <= 40 ? base : base.substring(0, 40);
  }

  static String _suffix() {
    final random = Random.secure();
    return List.generate(4, (_) => random.nextInt(36).toRadixString(36)).join();
  }
}

/// Lists the luma hosts on this network while something is looking.
class HostBrowser extends ChangeNotifier {
  Discovery? _discovery;
  bool _starting = false;
  bool _disposed = false;

  final Map<String, DiscoveredHost> _hosts = {};

  /// False when the platform has no working mDNS, so the UI can stay quiet
  /// instead of promising devices that will never appear.
  bool get available => _available;
  bool _available = true;

  bool get searching => _discovery != null;

  List<DiscoveredHost> get hosts {
    final list = _hosts.values
        .where((h) => !HostAdvertiser.ownInstanceNames.contains(h.id))
        .toList()
      ..sort(
        (a, b) =>
            a.deviceName.toLowerCase().compareTo(b.deviceName.toLowerCase()),
      );
    return List.unmodifiable(list);
  }

  Future<void> start() async {
    if (_discovery != null || _starting || _disposed) return;
    _starting = true;
    try {
      final discovery = await startDiscovery(
        kLumaHostServiceType,
        ipLookupType: IpLookupType.v4,
      );
      if (_disposed) {
        unawaited(stopDiscovery(discovery).catchError((_) {}));
        return;
      }
      _discovery = discovery;
      discovery.addServiceListener(_onService);
      _available = true;
    } catch (e) {
      _available = false;
      debugPrint('luma host: network discovery unavailable: $e');
    } finally {
      _starting = false;
      _notify();
    }
  }

  void _onService(Service service, ServiceStatus status) {
    final id = service.name;
    if (id == null) return;
    switch (status) {
      case ServiceStatus.found:
        final host = DiscoveredHost.fromService(service);
        if (host == null) return;
        _hosts[id] = host;
      case ServiceStatus.lost:
        _hosts.remove(id);
    }
    _notify();
  }

  Future<void> stop() async {
    final discovery = _discovery;
    _discovery = null;
    _hosts.clear();
    if (discovery != null) {
      try {
        await stopDiscovery(discovery);
      } catch (_) {
        // The platform already dropped it.
      }
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final discovery = _discovery;
    _discovery = null;
    if (discovery != null) {
      unawaited(stopDiscovery(discovery).catchError((_) {}));
    }
    super.dispose();
  }
}
