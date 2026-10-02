import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'peer_crypto.dart';
import 'peer_debug_log.dart';
import 'peer_protocol.dart';
import 'peer_share.dart';

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

/// Called when a peer advertises the contents of its shared folder.
typedef PeerShareIndexHandler = void Function(List<SharedFileEntry> entries);

/// Called when a peer asks for the bytes of one shared file.
typedef PeerShareRequestHandler = void Function(String path, int from);

/// Called for each chunk of a shared file arriving from a peer.
typedef PeerShareChunkHandler = Future<void> Function(
    SharedChunkHeader header, Uint8List bytes);

/// Called when a peer can't serve a file it advertised (deleted since,
/// unreadable) so the requester stops waiting for it.
typedef PeerShareErrorHandler = void Function(String path, String reason);

/// The raw payload the next record carries, as announced by the `blob` or
/// `share-chunk` message just before it. Both a sealed collection snapshot
/// and a shared-file chunk arrive this way, and differ only in where they
/// are delivered.
class _ExpectedPayload {
  const _ExpectedPayload.snapshot(this.collection, this.savedAtMs, this.length)
      : chunk = null;

  _ExpectedPayload.shareChunk(SharedChunkHeader this.chunk)
      : collection = null,
        savedAtMs = 0,
        length = chunk.length;

  final String? collection;
  final int savedAtMs;
  final SharedChunkHeader? chunk;
  final int length;
}

/// One end of a connected peer link. Owns the socket, performs the same-
/// account handshake (peer_crypto.dart), then exchanges sealed control
/// messages, snapshots and shared-file chunks.
///
/// The link is transport-only: it does NOT decide what to sync. The
/// controller wires up [onSnapshot] / [provideSnapshot] and the link calls
/// them as messages arrive. Likewise the controller learns about the peer's
/// advertised state via [onReady] and may then drive exchanges by calling
/// [requestCollection] / [sendCollection].
class PeerLink implements PeerShareChannel {
  PeerLink({
    required this.socket,
    required this.localHello,
    required this.handshakeKey,
    required this.isInitiator,
    required this.onReady,
    required this.onSnapshot,
    required this.provideSnapshot,
    required this.onClose,
    this.onShareIndex,
    this.onShareRequest,
    this.onShareChunk,
    this.onShareError,
  }) {
    logP2pDebug('PeerLink: connecting to ${socket.remoteAddress.address}:'
        '${socket.remotePort} (local device ${localHello.deviceId})');
    _subscription = socket.listen(
      _onData,
      onError: (Object e) {
        logP2pDebug('PeerLink: connection error: $e');
        _fail('Connection error: $e');
      },
      onDone: () {
        logP2pDebug('PeerLink: connection closed by peer '
            '(state=$_state, peer=${peer?.deviceId ?? "pre-handshake"})');
        _fail(null);
      },
      cancelOnError: true,
    );
    // Every incoming frame waits behind this, so none is looked at before
    // our own hello — and the key pair the peer's is answered with — exists.
    _inbound = _sendHello();
  }

  final Socket socket;
  final PeerHello localHello;

  /// The same-account secret both sides prove they hold. Never sent; it only
  /// feeds the key schedule in [derivePeerSession].
  final String handshakeKey;

  /// Whether this side opened the connection. Part of what each proof
  /// covers, so the two directions' proofs can never be swapped.
  final bool isInitiator;

  /// Invoked once, after the peer's proof verifies. Hands over the peer's
  /// identity + advertised collection state.
  final void Function(PeerHello peer) onReady;

  /// Invoked when the peer sends us a sealed snapshot. Return true if applied
  /// (so we `ack`), false if declined (so we `nack`).
  final PeerSnapshotHandler onSnapshot;

  /// Invoked when the peer asks us for a snapshot.
  final PeerSnapshotProvider provideSnapshot;

  /// Invoked when the link ends for any reason (clean close, error, failed
  /// handshake). Always fires exactly once.
  final void Function(String? error) onClose;

  /// Shared-folder callbacks. Null until the share repository registers
  /// itself, which is why every handler below is checked before use — a
  /// device with the SFTP plugin uninstalled still syncs collections
  /// normally, it just ignores share traffic.
  final PeerShareIndexHandler? onShareIndex;
  final PeerShareRequestHandler? onShareRequest;
  final PeerShareChunkHandler? onShareChunk;
  final PeerShareErrorHandler? onShareError;

  PeerLinkState _state = PeerLinkState.connecting;
  PeerLinkState get state => _state;

  /// The peer, once it has proved it holds [handshakeKey]. Null until then.
  PeerHello? peer;

  /// The peer's hello while its proof is still outstanding.
  PeerHello? _claimedPeer;
  bool _closed = false;

  PeerKeyPair? _keyPair;
  Uint8List? _ownHelloBytes;

  /// Keys and expected proof, from the moment the peer's hello is answered.
  PeerSession? _session;

  /// Set once the peer's proof verifies. From then on every frame either way
  /// is sealed with it.
  PeerSecureChannel? _channel;

  late final StreamSubscription<Uint8List> _subscription;
  // Bytes received but not yet consumed by a complete frame.
  final BytesBuilder _pending = BytesBuilder(copy: false);

  /// Incoming frames, handled one at a time and in arrival order: opening a
  /// record is asynchronous, and the counter in its nonce means record N+1
  /// must not be opened before record N.
  late Future<void> _inbound;

  /// Received but not yet handled. Reading pauses while this is high, so a
  /// fast sender cannot pile up records faster than they can be opened.
  int _queuedBytes = 0;
  bool _pausedForBackpressure = false;
  static const int _maxQueuedBytes = 3 * kMaxWireFrameBytes;

  _ExpectedPayload? _expecting;

  // ---- Outgoing ------------------------------------------------------------

  Future<void> _sendHello() async {
    _state = PeerLinkState.handshaking;
    try {
      final keyPair = await PeerKeyPair.generate();
      if (_closed) return;
      _keyPair = keyPair;
      final bytes = Uint8List.fromList(utf8.encode(
          jsonEncode(localHello.withPublicKey(keyPair.publicKey).helloJson())));
      _ownHelloBytes = bytes;
      _writePlain(encodeRawFrame(bytes));
    } catch (e) {
      _fail('Could not start the handshake: $e');
    }
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
    await _writeSealed([
      _jsonBytes({
        'type': 'blob',
        'collection': collectionId,
        'savedAtMs': snap.savedAtMs,
        'length': snap.sealed.length,
      }),
      snap.sealed,
    ], flush: true);
  }

  /// Advertise the whole contents of our shared folder, tombstones included.
  /// Both sides send one on connect and again whenever their folder changes;
  /// each side then pulls whatever it is behind on, so a file only ever
  /// crosses the wire once and in one direction.
  @override
  void sendShareIndex(List<SharedFileEntry> entries) {
    if (_state != PeerLinkState.ready) return;
    _writeJson({
      'type': 'share-index',
      'entries': [for (final e in entries) e.toJson()],
    });
  }

  /// Ask the peer for the bytes of one shared file, starting at [from] —
  /// non-zero when picking up a transfer that was interrupted, so a large
  /// file doesn't start over every time the network drops.
  @override
  void requestShareFile(String path, {int from = 0}) {
    if (_state != PeerLinkState.ready) return;
    _writeJson({'type': 'share-request', 'path': path, 'from': from});
  }

  /// Tell the requester we can't serve a file after all.
  @override
  void sendShareUnavailable(String path, String reason) {
    if (_state != PeerLinkState.ready) return;
    _writeJson({'type': 'share-error', 'path': path, 'reason': reason});
  }

  /// Push one chunk of a shared file: its header, then the raw bytes, each
  /// sealed as its own record.
  ///
  /// Awaits the socket flush, so a fast disk can't outrun a slow network —
  /// the returned future is the sender's backpressure.
  @override
  Future<void> sendShareChunk(SharedChunkHeader header, Uint8List bytes) async {
    if (_state != PeerLinkState.ready) return;
    await _writeSealed([
      _jsonBytes(header.toJson()),
      // An empty file is the header alone; the receiver expects no record.
      if (header.length > 0) bytes,
    ], flush: true);
  }

  /// Politely close the link.
  Future<void> close() async => _fail(null);

  void _writeJson(Map<String, Object?> message) {
    unawaited(_writeSealed([_jsonBytes(message)]).catchError((Object e) {
      _fail('Could not send to the other device: $e');
    }));
  }

  /// Seals [payloads] and puts them on the wire back to back.
  ///
  /// They are sealed here, synchronously in call order, which is what fixes
  /// each record's nonce; the write queue then puts them on the wire in that
  /// same order however long each seal takes.
  Future<void> _writeSealed(List<List<int>> payloads, {bool flush = false}) {
    final channel = _channel;
    if (channel == null || _closed) return Future.value();
    final sealed = [for (final p in payloads) channel.seal(p)];
    for (final record in sealed) {
      record.ignore();
    }
    return _enqueueWrite(() async {
      for (final record in sealed) {
        socket.add(encodeRawFrame(await record));
      }
      if (flush) await socket.flush();
    });
  }

  /// The two handshake frames, which go out before there is a key to seal
  /// them with.
  void _writePlain(Uint8List frame) {
    unawaited(_enqueueWrite(() => socket.add(frame)).catchError((Object e) {
      _fail('Could not send to the other device: $e');
    }));
  }

  static List<int> _jsonBytes(Map<String, Object?> message) =>
      utf8.encode(jsonEncode(message));

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
    if (_closed) return;
    _pending.add(chunk);
    var remaining = _pending.takeBytes();
    while (true) {
      ({Uint8List payload, int consumed})? frame;
      try {
        frame = decodeFrame(remaining);
      } on PeerProtocolException catch (e) {
        // A synchronous throw here would escape the socket's onData
        // callback entirely (Stream.listen's onError only covers errors from
        // the source stream), so the link would never run onClose. Fail it
        // cleanly instead.
        final msg = 'PeerLink: $e (${remaining.length} bytes pending, '
            'state=$_state, peer=${peer?.deviceId ?? "pre-handshake"})';
        debugPrint(msg);
        logP2pDebug(msg);
        _fail('Invalid frame: $e');
        return;
      }
      if (frame == null) break;
      _enqueueInbound(frame.payload);
      remaining = Uint8List.sublistView(remaining, frame.consumed);
    }
    // Stash the unconsumed tail for the next chunk.
    if (remaining.isNotEmpty) _pending.add(remaining);
  }

  void _enqueueInbound(Uint8List payload) {
    _queuedBytes += payload.length;
    if (_queuedBytes > _maxQueuedBytes && !_pausedForBackpressure) {
      _pausedForBackpressure = true;
      _subscription.pause();
    }
    _inbound = _inbound.then((_) async {
      try {
        if (!_closed) await _handleFrame(payload);
      } catch (e) {
        logP2pDebug('PeerLink: handling a frame failed: $e');
        _fail('Connection error: $e');
      } finally {
        _queuedBytes -= payload.length;
        if (_pausedForBackpressure &&
            !_closed &&
            _queuedBytes <= _maxQueuedBytes ~/ 2) {
          _pausedForBackpressure = false;
          _subscription.resume();
        }
      }
    });
  }

  Future<void> _handleFrame(Uint8List payload) async {
    final channel = _channel;
    if (channel == null) return _handleHandshakeFrame(payload);

    final Uint8List clear;
    try {
      clear = await channel.open(payload);
    } catch (_) {
      logP2pDebug('PeerLink: a record failed to open (${payload.length} B)');
      _fail('A frame failed its authenticity check; the connection was '
          'closed.');
      return;
    }
    if (_closed) return;

    final expecting = _expecting;
    if (expecting != null) {
      _expecting = null;
      _deliverPayload(expecting, clear);
      return;
    }
    final j = _decodeControl(clear);
    if (j == null) return;
    if (peer == null) {
      _onPeerState(j);
    } else {
      _handleControl(j);
    }
  }

  /// Before the peer has proved itself it gets the handshake and nothing
  /// else. Anything more — above all a `blob`, whose sealed bytes would
  /// otherwise be applied — ends the link.
  Future<void> _handleHandshakeFrame(Uint8List payload) async {
    final j = _decodeControl(payload);
    if (j == null) return;
    switch (j['type']) {
      case 'hello':
        await _onPeerHello(j, payload);
      case 'proof':
        _onPeerProof(j);
      case 'bye':
        _fail(null);
      default:
        logP2pDebug('PeerLink: "${j['type']}" before the handshake finished');
        _fail('Handshake failed: unexpected message.');
    }
  }

  void _handleControl(Map<String, dynamic> j) {
    final type = j['type'] as String?;
    logP2pDebug('PeerLink: "$type" from ${peer?.deviceId}');
    switch (type) {
      case 'hello':
      case 'proof':
      case 'state':
        _fail('Handshake failed: unexpected message.');
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
        _expecting = _ExpectedPayload.snapshot(c, savedAt, len);
      case 'share-index':
        final handler = onShareIndex;
        if (handler == null) break;
        final raw = j['entries'];
        final entries = <SharedFileEntry>[];
        if (raw is List) {
          for (final item in raw) {
            final entry = SharedFileEntry.fromJson(item);
            if (entry != null) entries.add(entry);
          }
        }
        handler(entries);
      case 'share-request':
        final path = j['path'] as String?;
        if (path != null && path.isNotEmpty) {
          onShareRequest?.call(path, (j['from'] as num?)?.toInt() ?? 0);
        }
      case 'share-error':
        final path = j['path'] as String?;
        if (path != null && path.isNotEmpty) {
          onShareError?.call(path, j['reason'] as String? ?? 'unavailable');
        }
      case 'share-chunk':
        final header = SharedChunkHeader.fromJson(j);
        if (header == null) {
          _fail('Malformed share chunk header.');
          return;
        }
        if (header.length == 0) {
          // An empty file: no record follows the header, so deliver it here.
          unawaited(_deliverShareChunk(header, Uint8List(0)));
          break;
        }
        _expecting = _ExpectedPayload.shareChunk(header);
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

  void _deliverPayload(_ExpectedPayload expected, Uint8List bytes) {
    if (bytes.length != expected.length) {
      _fail('Payload length did not match its header.');
      return;
    }
    // Applied / written off the read loop, so a slow database or disk never
    // holds up the frames queued behind this one.
    final chunk = expected.chunk;
    if (chunk != null) {
      unawaited(_deliverShareChunk(chunk, bytes));
    } else {
      unawaited(_deliverBlob(expected.collection!, bytes, expected.savedAtMs));
    }
  }

  Future<void> _deliverShareChunk(
      SharedChunkHeader header, Uint8List bytes) async {
    final handler = onShareChunk;
    if (handler == null) return;
    try {
      await handler(header, bytes);
    } catch (e) {
      logP2pDebug('PeerLink: share chunk failed: $e');
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

  Map<String, dynamic>? _decodeControl(Uint8List payload) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(payload));
    } catch (e) {
      _debugDumpMalformed(payload, e);
      _fail('Malformed control message.');
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      _debugDumpMalformed(
          payload, 'decoded to ${decoded.runtimeType}, not a Map');
      _fail('Malformed control message.');
      return null;
    }
    return decoded;
  }

  // ---- Handshake -----------------------------------------------------------

  /// The peer's half of the handshake: who it says it is, its nonce and its
  /// one-time key. Answered with our proof; the peer is not trusted until its
  /// own proof arrives in [_onPeerProof].
  Future<void> _onPeerHello(Map<String, dynamic> j, Uint8List raw) async {
    if (handshakeKey.isEmpty) {
      // No account key yet, and an empty one is a key everybody holds.
      _fail('Handshake failed: this device is not signed in.');
      return;
    }
    if (_claimedPeer != null) {
      _fail('Handshake failed: unexpected message.');
      return;
    }
    if (j['v'] != kPeerProtocolVersion) {
      logP2pDebug('PeerLink: peer speaks protocol ${j['v']}');
      _fail('Handshake failed: update luma on both devices.');
      return;
    }
    final hello = PeerHello.fromHelloJson(j);
    logP2pDebug('PeerLink: received hello from ${hello.deviceId}');
    final peerPublicKey = decodePeerPublicKey(hello.publicKey);
    final ownHello = _ownHelloBytes;
    final keyPair = _keyPair;
    if (peerPublicKey == null ||
        ownHello == null ||
        keyPair == null ||
        !isValidPeerNonce(hello.nonce) ||
        hello.nonce == localHello.nonce ||
        hello.deviceId.isEmpty ||
        hello.deviceId == localHello.deviceId) {
      // Our own id coming back is what a reflection looks like: someone
      // relaying this device's handshake to itself to borrow its proof.
      _fail('Handshake failed: invalid hello.');
      return;
    }
    _claimedPeer = hello;

    final PeerSession session;
    try {
      session = await derivePeerSession(
        key: handshakeKey,
        isInitiator: isInitiator,
        ownKeyPair: keyPair,
        peerPublicKey: peerPublicKey,
        initiatorHello: isInitiator ? ownHello : raw,
        responderHello: isInitiator ? raw : ownHello,
      );
    } catch (e) {
      logP2pDebug('PeerLink: key exchange failed: $e');
      _fail('Handshake failed: invalid hello.');
      return;
    }
    if (_closed) return;
    _session = session;
    _writePlain(encodeFrame({'type': 'proof', 'mac': session.ownProof}));
  }

  /// The peer proved it holds the account key. From here on everything is
  /// sealed, starting with our own `state`.
  void _onPeerProof(Map<String, dynamic> j) {
    final claimed = _claimedPeer;
    final session = _session;
    final mac = j['mac'];
    if (claimed == null ||
        session == null ||
        _channel != null ||
        mac is! String) {
      _fail('Handshake failed: unexpected message.');
      return;
    }
    if (!constantTimeStringEquals(mac, session.expectedPeerProof)) {
      logP2pDebug('PeerLink: proof mismatch from ${claimed.deviceId}');
      _fail('Handshake failed: not the same account.');
      return;
    }
    _channel = session.channel;
    logP2pDebug('PeerLink: verified ${claimed.deviceId}');
    _writeJson(localHello.stateJson());
  }

  /// The peer's first sealed message, completing its identity. Only now is
  /// the link handed to the controller.
  void _onPeerState(Map<String, dynamic> j) {
    final claimed = _claimedPeer;
    if (claimed == null || j['type'] != 'state') {
      _fail('Handshake failed: unexpected message.');
      return;
    }
    final ready = claimed.withState(j);
    peer = ready;
    _state = PeerLinkState.ready;
    logP2pDebug('PeerLink: ready with ${ready.deviceId} '
        '(${ready.collections.length} collections advertised)');
    onReady(ready);
  }

  void _fail(String? error) {
    if (_closed) return;
    _closed = true;
    _state = PeerLinkState.closed;
    _expecting = null;
    _subscription.cancel().catchError((_) {});
    socket.destroy();
    onClose(error);
  }

  /// Logs forensic detail for a control-message parse failure: the payload
  /// length and a hex preview of its start. Printed rather than shown in the
  /// UI so it doesn't clutter the error message, but visible in
  /// `flutter run`/`adb logcat` output if this needs diagnosing again.
  void _debugDumpMalformed(Uint8List payload, Object error) {
    final preview = payload
        .take(64)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    final msg = 'PeerLink: malformed control message ($error). '
        'state=$_state peer=${peer?.deviceId ?? "pre-handshake"} '
        'payloadLength=${payload.length} bytes=[$preview]';
    debugPrint(msg);
    logP2pDebug(msg);
  }
}
