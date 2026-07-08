import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'peer_protocol.dart';

/// The lifecycle of one TCP connection to a peer.
enum PeerLinkState { connecting, handshaking, ready, closed }

/// A function the controller plugs in to handle an incoming sealed snapshot
/// from a peer. Returns true if applied, false if declined (peer is older).
typedef PeerSnapshotHandler = Future<bool> Function(
    String collectionId, Uint8List sealed, int peerSavedAtMs);

/// A function the controller plugs in to supply a sealed snapshot when the
/// peer requests one. Returns null if we have nothing to send (collection
/// disabled, etc.).
typedef PeerSnapshotProvider = Future<({Uint8List sealed, int savedAtMs})?>
    Function(String collectionId);

/// One end of a connected peer link. Owns the socket, performs the same-
/// account handshake, then exchanges control messages + sealed blobs.
///
/// The link is transport-only: it does NOT decide what to sync. The
/// controller wires up [onSnapshot] / [provideSnapshot] and the link calls
/// them as messages arrive. Likewise the controller learns about the peer's
/// advertised state via [onReady] and may then drive exchanges by calling
/// [requestCollection] / [sendCollection].
class PeerLink {
  PeerLink({
    required this.socket,
    required this.localHello,
    required this.expectedToken,
    required this.onReady,
    required this.onSnapshot,
    required this.provideSnapshot,
    required this.onClose,
  }) {
    _subscription = socket.listen(
      _onData,
      onError: (Object e) => _fail('Connection error: $e'),
      onDone: () => _fail(null),
      cancelOnError: true,
    );
    _sendHello();
  }

  final Socket socket;
  final PeerHello localHello;
  final String expectedToken;

  /// Invoked once, after the peer's `hello`/`welcome` verifies. Hands over
  /// the peer's identity + advertised collection state.
  final void Function(PeerHello peer) onReady;

  /// Invoked when the peer sends us a sealed snapshot. Return true if applied
  /// (so we `ack`), false if declined (so we `nack`).
  final PeerSnapshotHandler onSnapshot;

  /// Invoked when the peer asks us for a snapshot.
  final PeerSnapshotProvider provideSnapshot;

  /// Invoked when the link ends for any reason (clean close, error, token
  /// mismatch). Always fires exactly once.
  final void Function(String? error) onClose;

  PeerLinkState _state = PeerLinkState.connecting;
  PeerLinkState get state => _state;

  PeerHello? peer;
  bool _sentWelcome = false;
  bool _closed = false;

  late final StreamSubscription<Uint8List> _subscription;
  // Bytes received but not yet consumed by a complete frame.
  final BytesBuilder _pending = BytesBuilder(copy: false);

  // While reading a blob: how many bytes we still expect, and which
  // collection / savedAtMs they belong to.
  int _blobBytesRemaining = 0;
  String? _blobCollection;
  int _blobSavedAtMs = 0;
  final BytesBuilder _blobBuffer = BytesBuilder(copy: false);

  // ---- Outgoing ------------------------------------------------------------

  void _sendHello() {
    _state = PeerLinkState.handshaking;
    _writeJson(localHello.toJson());
  }

  /// Ask the peer for its snapshot of [collectionId]. The reply arrives
  /// asynchronously and is delivered to [onSnapshot].
  void requestCollection(String collectionId) {
    if (_state != PeerLinkState.ready) return;
    _writeJson({'type': 'request', 'collection': collectionId});
  }

  /// Push our snapshot of [collectionId] to the peer unsolicited (auto-sync
  /// on local change, or a manual "send everything").
  Future<void> sendCollection(String collectionId) async {
    if (_state != PeerLinkState.ready) return;
    final snap = await provideSnapshot(collectionId);
    if (snap == null) return;
    await _enqueueWrite(() async {
      socket.add(encodeFrame({
        'type': 'blob',
        'collection': collectionId,
        'savedAtMs': snap.savedAtMs,
        'length': snap.sealed.length,
      }));
      socket.add(snap.sealed);
      await socket.flush();
    });
  }

  /// Politely close the link.
  Future<void> close() async => _fail(null);

  void _writeJson(Map<String, Object?> message) {
    unawaited(_enqueueWrite(() => socket.add(encodeFrame(message))));
  }

  // All socket writes — control frames and the header+bytes+flush of a blob
  // push — go through this single FIFO queue. Without it, two overlapping
  // writers (e.g. two incoming `request`s handled back-to-back, each
  // triggering an async `sendCollection`) can call `socket.add`/`flush`
  // concurrently, which throws "Bad state: StreamSink is bound to a stream".
  Future<void> _writeQueue = Future.value();

  Future<T> _enqueueWrite<T>(FutureOr<T> Function() action) {
    final result = _writeQueue.then((_) => action());
    _writeQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  // ---- Incoming ------------------------------------------------------------

  void _onData(Uint8List chunk) {
    if (_blobBytesRemaining > 0) {
      // We are mid-blob: this chunk is raw sealed bytes, not a frame.
      _absorbBlob(chunk);
      return;
    }
    _absorbControl(chunk);
  }

  void _absorbControl(Uint8List chunk) {
    _pending.add(chunk);
    final assembled = _pending.takeBytes();
    var remaining = Uint8List.fromList(assembled);
    while (true) {
      final frame = decodeFrame(remaining);
      if (frame == null) {
        // Stash the unconsumed tail for the next chunk.
        if (remaining.isNotEmpty) {
          _pending.add(remaining);
        }
        return;
      }
      _handlePayload(frame.payload);
      if (_closed) return;
      remaining = Uint8List.sublistView(remaining, frame.consumed);
      if (_blobBytesRemaining > 0) {
        // Next byte stream is a blob, not a frame.
        if (remaining.isNotEmpty) _absorbBlob(remaining);
        return;
      }
    }
  }

  void _absorbBlob(Uint8List chunk) {
    final take = chunk.length <= _blobBytesRemaining
        ? chunk.length
        : _blobBytesRemaining;
    _blobBuffer.add(Uint8List.sublistView(chunk, 0, take));
    _blobBytesRemaining -= take;

    if (_blobBytesRemaining > 0) {
      // Any bytes beyond the blob are the start of the next control frame.
      if (take < chunk.length) {
        final tail = Uint8List.sublistView(chunk, take);
        _blobBytesRemaining = 0; // guard satisfied; re-enter control mode
        _absorbControl(tail);
      }
      return;
    }

    // Blob complete.
    final sealed = _blobBuffer.takeBytes();
    final collection = _blobCollection!;
    final savedAtMs = _blobSavedAtMs;
    _blobCollection = null;
    _blobSavedAtMs = 0;

    // Apply + ack asynchronously (this may await real DB I/O) without
    // blocking the read loop.
    unawaited(_deliverBlob(collection, sealed, savedAtMs));

    // Any trailing bytes from the same chunk start the next control frame.
    // This MUST happen synchronously, right now — not deferred behind the
    // async apply above. A later socket chunk can otherwise race ahead of
    // these already-received bytes (arriving via a fresh `_onData` call
    // while `_deliverBlob` is still awaiting), which desyncs the frame
    // boundary and corrupts every message after it ("Malformed control
    // message").
    if (take < chunk.length) {
      _absorbControl(Uint8List.sublistView(chunk, take));
    }
  }

  Future<void> _deliverBlob(
      String collection, Uint8List sealed, int savedAtMs) async {
    bool applied;
    try {
      applied = await onSnapshot(collection, sealed, savedAtMs);
    } catch (_) {
      applied = false;
    }
    if (!_closed && _state == PeerLinkState.ready) {
      _writeJson({
        'type': applied ? 'ack' : 'nack',
        'collection': collection,
      });
    }
  }

  void _handlePayload(Uint8List payload) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(payload));
    } catch (_) {
      _fail('Malformed control message.');
      return;
    }
    final j = decoded is Map<String, dynamic> ? decoded : null;
    if (j == null) {
      _fail('Malformed control message.');
      return;
    }
    final type = j['type'] as String?;
    switch (type) {
      case 'hello':
        _onPeerHello(j);
      case 'welcome':
        // Peer accepted us; if we haven't seen its hello yet, treat as one.
        _onPeerHello(j);
      case 'request':
        final c = j['collection'] as String?;
        if (c != null) unawaited(sendCollection(c));
      case 'blob':
        final c = j['collection'] as String?;
        final len = j['length'] as int?;
        final savedAt = j['savedAtMs'] as int? ?? 0;
        if (c == null || len == null || len <= 0 || len > kMaxFrameBytes) {
          _fail('Malformed blob header.');
          return;
        }
        _blobCollection = c;
        _blobSavedAtMs = savedAt;
        _blobBytesRemaining = len;
      case 'ack':
      case 'nack':
        // Outcome of a push; nothing to do at the link layer. The controller
        // can observe progress via [peer] state + the change streams.
        break;
      case 'bye':
        _fail(null);
      default:
        // Unknown control message: ignore for forward compatibility.
        break;
    }
  }

  void _onPeerHello(Map<String, dynamic> j) {
    if (peer != null) return; // Already saw the peer's hello.
    final hello = PeerHello.fromJson(j);
    if (hello.token != expectedToken) {
      _fail('Handshake failed: not the same account.');
      return;
    }
    peer = hello;

    if (!_sentWelcome) {
      _sentWelcome = true;
      // Reply with our own hello so the peer (which may be the "server" side
      // of the socket) gets our identity too.
      final welcome = Map<String, Object?>.from(localHello.toJson())
        ..['type'] = 'welcome';
      _writeJson(welcome);
    }

    _state = PeerLinkState.ready;
    onReady(hello);
  }

  void _fail(String? error) {
    if (_closed) return;
    _closed = true;
    _state = PeerLinkState.closed;
    _subscription.cancel().catchError((_) {});
    socket.destroy();
    onClose(error);
  }
}
