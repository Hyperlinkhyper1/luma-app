import 'dart:async';
import 'dart:io';

import 'peer_link.dart';

export 'peer_link.dart' show PeerLink;
export 'peer_protocol.dart' show kLumaPeerServiceType;

/// A factory the controller provides to wrap each accepted socket into a
/// [PeerLink]. Letting the controller build the link keeps the listener free
/// of any sync/account concerns.
typedef PeerLinkFactory = PeerLink Function(Socket socket);

/// Listens for incoming TCP connections from same-account peers on the local
/// network. Each accepted socket is handed to [factory]; the resulting link
/// performs the handshake, and only same-account links survive.
///
/// The port is chosen automatically (port 0 = OS-assigned) so multiple luma
/// instances on one machine don't collide, and so the advertised mDNS record
/// always points at the real listening port.
class PeerListener {
  PeerListener({PeerLinkFactory? factory}) : _factory = factory;

  /// Settable so the controller can rewire it once the handshake token is
  /// known (after sign-in). Throws if [start] is called before this is set.
  set factory(PeerLinkFactory value) => _factory = value;
  PeerLinkFactory get factory {
    final f = _factory;
    if (f == null) throw StateError('PeerListener.factory not set');
    return f;
  }

  PeerLinkFactory? _factory;

  ServerSocket? _server;
  int _port = 0;
  StreamSubscription<Socket>? _subscription;

  /// The port this listener is bound to (0 until [start] succeeds).
  int get port => _port;
  bool get isRunning => _server != null;

  /// Binds to [preferredPort] if provided and > 0. If that fails, or if it's 0,
  /// binds to an OS-assigned port. Returns the bound port.
  Future<int> start([int preferredPort = 0]) async {
    await stop();
    if (_factory == null) {
      throw StateError('PeerListener.factory not set before start()');
    }
    try {
      if (preferredPort > 0) {
        _server = await ServerSocket.bind(InternetAddress.anyIPv4, preferredPort);
      } else {
        _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      }
    } catch (_) {
      // If preferredPort was in use or unavailable, fallback to OS-assigned port.
      if (preferredPort > 0) {
        _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      } else {
        rethrow;
      }
    }
    _port = _server!.port;
    _subscription = _server!.listen(
      (socket) {
        // The link performs the handshake; mismatches self-close.
        _factory!(socket);
      },
      onError: (Object e) {
        // Listener-level errors are transient; the socket stays up.
      },
    );
    return _port;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _server?.close();
    _server = null;
    _port = 0;
  }
}
