import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../sync/sync_service.dart';
import 'peer_debug_log.dart';
import 'peer_discovery.dart';
import 'peer_link.dart';
import 'peer_listener.dart';
import 'peer_protocol.dart';
import 'peer_state.dart';

/// A peer we have an active, handshaked link to. Plain DTO so the UI can
/// rebuild without holding the live socket.
class ConnectedPeer {
  const ConnectedPeer({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.collections,
    required this.address,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final Map<String, PeerCollectionState> collections;
  final String address;
}

/// Orchestrates P2P sync: owns the [PeerListener], [PeerDiscovery], and the
/// set of live [PeerLink]s. Wires each link's `onSnapshot` / `provideSnapshot`
/// callbacks to the [SyncService] seams, subscribes to local change streams
/// to drive auto-sync, and exposes a clean reactive view for the UI.
class PeerSyncController extends ChangeNotifier {
  PeerSyncController({required SyncService sync}) : _sync = sync {
    // Subscribe to per-collection change streams so auto-sync can push.
    for (final c in _sync.collections) {
      _changeSubs.add(c.changes.listen((_) => _onLocalChange(c.id)));
    }
  }

  final SyncService _sync;

  late final PeerSyncState _state;
  PeerSyncState get state => _state;

  late final PeerListener _listener =
      PeerListener(factory: (socket) => _newLink(socket, isOutgoing: false));
  final PeerDiscovery _discovery = PeerDiscovery();

  /// Links indexed two ways: pre-handshake by socket identity, post-handshake
  /// by peer device id. A link lives in exactly one of the two maps.
  final Map<Socket, PeerLink> _linksBySocket = {};
  final Map<String, PeerLink> _linksByDeviceId = {};
  final Map<String, ConnectedPeer> _connected = {};
  List<DiscoveredPeer> _discovered = const [];

  List<ConnectedPeer> get connected =>
      _connected.values.toList(growable: false);
  List<DiscoveredPeer> get discovered => _discovered;

  bool _running = false;
  bool get isRunning => _running;

  /// The local port other devices should connect to manually. 0 when not
  /// running.
  int get listenPort => _listener.port;

  /// This device's non-loopback IPv4 addresses, for troubleshooting when
  /// mDNS discovery doesn't find a peer — the first thing to check is
  /// whether both devices are even on the same subnet.
  Future<List<String>> localAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      return [
        for (final i in interfaces)
          for (final a in i.addresses) a.address,
      ];
    } catch (_) {
      return const [];
    }
  }

  String? _lastError;
  String? get lastError => _lastError;

  StreamSubscription<List<DiscoveredPeer>>? _discoverySub;
  final List<StreamSubscription<void>> _changeSubs = [];
  Timer? _autoDebounce;

  static const _autoDebounceDelay = Duration(seconds: 2);

  // ---- Lifecycle -----------------------------------------------------------

  /// Loads persisted state. Must be awaited before [start].
  Future<void> init() async {
    _state = await PeerSyncState.load();
    if (_state.discoveryEnabled) await start();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _changeSubs) {
      s.cancel();
    }
    _autoDebounce?.cancel();
    _discoverySub?.cancel();
    unawaited(stop());
    super.dispose();
  }

  /// Turns discovery + listening on. Idempotent.
  Future<void> start() async {
    if (_running) return;
    if (!_sync.p2pReady) {
      _lastError = 'Set up device sync first.';
      notifyListeners();
      return;
    }
    final token = _sync.peerHandshakeToken();
    if (token == null) {
      _lastError = 'Account not ready.';
      notifyListeners();
      return;
    }
    _running = true;
    _state.discoveryEnabled = true;
    await _state.save();

    try {
      final port = await _listener.start(_state.listenPort);
      if (port != _state.listenPort) {
        _state.listenPort = port;
        await _state.save();
      }
      await _discovery.start(
        instanceName: _state.deviceId,
        port: port,
        tokenPrefix: token.substring(0, 16),
      );
    } catch (e) {
      _lastError = 'Could not start discovery: $e';
    }

    _discoverySub ??= _discovery.peers.listen((peers) {
      _discovered = peers;
      _autoReconnectTrusted(peers);
      notifyListeners();
    });
    notifyListeners();
  }

  /// Devices we've connected to before (a trusted peer id, from a completed
  /// handshake) reconnect on their own as soon as they're seen on the network
  /// again — no need to press Connect a second time. Silent: a background
  /// reconnect attempt failing (peer briefly offline, still booting, etc.)
  /// shouldn't surface as a user-facing error.
  final Set<String> _autoReconnecting = {};

  void _autoReconnectTrusted(List<DiscoveredPeer> peers) {
    for (final peer in peers) {
      if (peer.host.isEmpty || peer.port == 0) continue;
      if (!_state.trustedPeerIds.contains(peer.name)) continue;
      if (_connected.containsKey(peer.name)) continue;
      if (!_autoReconnecting.add(peer.name)) continue; // already attempting
      unawaited(_connectTo(peer.host, peer.port, silent: true)
          .whenComplete(() => _autoReconnecting.remove(peer.name)));
    }
  }

  /// Turns discovery + listening off and drops all links.
  Future<void> stop() async {
    _running = false;
    _state.discoveryEnabled = false;
    await _state.save();
    await _discoverySub?.cancel();
    _discoverySub = null;
    await _discovery.stop();
    await _listener.stop();
    for (final link in [..._linksBySocket.values, ..._linksByDeviceId.values]) {
      await link.close();
    }
    _discovered = const [];
    _autoReconnecting.clear();
    notifyListeners();
  }

  Future<void> setAutoSync(bool value) async {
    _state.autoSync = value;
    await _state.save();
    notifyListeners();
  }

  Future<void> setDeviceName(String name) async {
    _state.deviceName = name.trim().isEmpty ? _state.deviceName : name.trim();
    await _state.save();
    notifyListeners();
  }

  // ---- Outgoing connections ------------------------------------------------

  /// Connect to a peer discovered via mDNS.
  Future<void> connectToDiscovered(DiscoveredPeer peer) async {
    if (peer.host.isEmpty || peer.port == 0) {
      _lastError = 'Could not resolve ${peer.name}.';
      notifyListeners();
      return;
    }
    await _connectTo(peer.host, peer.port);
  }

  /// Connect by host:port — the fallback when mDNS discovery is blocked.
  Future<void> connectManually(String host, int port) =>
      _connectTo(host, port);

  Future<void> _connectTo(String host, int port, {bool silent = false}) async {
    if (!_running) return;
    Socket socket;
    try {
      socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 5));
    } catch (e) {
      if (!silent) {
        _lastError = 'Could not connect to $host:$port ($e).';
        notifyListeners();
      }
      return;
    }
    _newLink(socket, isOutgoing: true);
  }

  Future<void> disconnect(String deviceId) async {
    final link = _linksByDeviceId.remove(deviceId);
    _connected.remove(deviceId);
    if (link != null) await link.close();
    notifyListeners();
  }

  /// Manually trigger a full exchange with [deviceId]: send every enabled
  /// collection we have that the peer is missing or older on, and request
  /// every one the peer advertises that we're older on.
  Future<void> syncNow(String deviceId) async {
    final link = _linksByDeviceId[deviceId];
    final peer = _connected[deviceId];
    if (link == null || peer == null) return;

    final localState = _sync.peerState();
    // Push collections where we're newer (or peer doesn't have them).
    for (final entry in localState.entries) {
      final theirs = peer.collections[entry.key];
      if (theirs == null || entry.value.savedAtMs > theirs.savedAtMs) {
        await link.sendCollection(entry.key);
      }
    }
    // Pull collections where the peer is newer.
    for (final entry in peer.collections.entries) {
      final ours = localState[entry.key];
      if (ours == null || entry.value.savedAtMs > ours.savedAtMs) {
        link.requestCollection(entry.key);
      }
    }
  }

  // ---- Link construction + callbacks ---------------------------------------

  PeerLink _newLink(Socket socket, {required bool isOutgoing}) {
    final token = _sync.peerHandshakeToken() ?? '';
    final localHello = PeerHello(
      deviceId: _state.deviceId,
      deviceName: _state.deviceName,
      platform: _platform(),
      token: token,
      collections: _sync
          .peerState()
          .map((k, v) => MapEntry(
              k,
              PeerCollectionState(
                cloudVersion: v.cloudVersion,
                savedAtMs: v.savedAtMs,
              ))),
    );
    final link = PeerLink(
      socket: socket,
      localHello: localHello,
      expectedToken: token,
      onReady: (peerHello) => _onLinkReady(socket, isOutgoing, peerHello),
      onSnapshot: (collectionId, sealed, savedAtMs) =>
          _onPeerSnapshot(socket, collectionId, sealed, savedAtMs),
      provideSnapshot: _sync.buildPeerSnapshot,
      onClose: (error) => _onLinkClosed(socket, error),
    );
    _linksBySocket[socket] = link;
    return link;
  }

  void _onLinkReady(
      Socket socket, bool isOutgoing, PeerHello peerHello) {
    // Move the link from socket-keyed to deviceId-keyed tracking.
    final link = _linksBySocket.remove(socket);
    if (link == null) {
      // Already closed during handshake.
      socket.destroy();
      return;
    }

    // Dedupe by device id: if both sides connected to each other at once,
    // there are two links for one peer pair. Both devices must agree which
    // one survives. Rule: the device with the SMALLER id keeps its OUTGOING
    // link and closes its INCOMING; the device with the LARGER id does the
    // opposite. Net effect: exactly one link survives per pair.
    final existing = _linksByDeviceId[peerHello.deviceId];
    if (existing != null) {
      final iKeep = _state.deviceId.compareTo(peerHello.deviceId) < 0
          ? isOutgoing
          : !isOutgoing;
      logP2pDebug('PeerSyncController: duplicate link to '
          '${peerHello.deviceId} (mutual dial) — isOutgoing=$isOutgoing, '
          'keeping this one=$iKeep');
      if (!iKeep) {
        socket.destroy();
        // Trigger the onClose path so bookkeeping stays consistent; the link
        // itself has no public force-close, so we let the socket destruction
        // propagate naturally.
        return;
      }
      // We keep this link; drop the existing one.
      existing.socket.destroy();
      _connected.remove(peerHello.deviceId);
    }

    _linksByDeviceId[peerHello.deviceId] = link;
    _state.trust(peerHello.deviceId);
    _state.markSeen(peerHello.deviceId);
    unawaited(_state.save());

    _connected[peerHello.deviceId] = ConnectedPeer(
      deviceId: peerHello.deviceId,
      deviceName: peerHello.deviceName,
      platform: peerHello.platform,
      collections: peerHello.collections,
      address: socket.remoteAddress.address,
    );
    notifyListeners();

    // Newly connected → kick off a full exchange immediately so data
    // converges as soon as the user connects.
    unawaited(syncNow(peerHello.deviceId));
  }

  void _onLinkClosed(Socket socket, String? error) {
    final preHandshake = _linksBySocket.remove(socket);
    String? removedId;
    if (preHandshake == null) {
      // Post-handshake: find which deviceId owned this socket.
      String? id;
      _linksByDeviceId.removeWhere((deviceId, link) {
        if (identical(link.socket, socket)) {
          id = deviceId;
          return true;
        }
        return false;
      });
      removedId = id;
    }
    if (removedId != null) {
      _connected.remove(removedId);
      _state.lastSeenMs.remove(removedId);
    }
    if (error != null) _lastError = error;
    notifyListeners();
  }

  Future<bool> _onPeerSnapshot(Socket sender, String collectionId,
      Uint8List sealed, int peerSavedAtMs) async {
    final applied =
        await _sync.applyPeerSnapshot(collectionId, sealed, peerSavedAtMs);
    // Fan out EVERY enabled collection (not just the one that just changed)
    // transitively to OTHER peers (don't echo back to the sender) — auto-sync
    // always converges every device on everything selected, not just the
    // single thing that happened to trigger this round.
    if (applied && _state.autoSync) {
      final ids = _sync.peerState().keys;
      for (final entry in _linksByDeviceId.entries) {
        if (!identical(entry.value.socket, sender)) {
          for (final id in ids) {
            unawaited(entry.value.sendCollection(id));
          }
        }
      }
    }
    return applied;
  }

  // ---- Local change → auto push -------------------------------------------

  /// Any enabled collection changing pushes ALL enabled collections to every
  /// connected peer — not just the one that changed. A single debounce timer
  /// (ignoring which collection fired it) still batches rapid successive
  /// edits across different collections into one round.
  void _onLocalChange(String collectionId) {
    if (!_running || !_state.autoSync) return;
    _autoDebounce?.cancel();
    _autoDebounce = Timer(_autoDebounceDelay, () {
      final ids = _sync.peerState().keys;
      for (final link in _linksByDeviceId.values) {
        for (final id in ids) {
          unawaited(link.sendCollection(id));
        }
      }
    });
  }

  String _platform() {
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'windows';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    if (defaultTargetPlatform == TargetPlatform.linux) return 'linux';
    return '';
  }
}
