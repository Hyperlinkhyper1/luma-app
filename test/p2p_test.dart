import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/p2p/peer_crypto.dart';
import 'package:luma/p2p/peer_link.dart';
import 'package:luma/p2p/peer_listener.dart';
import 'package:luma/p2p/peer_protocol.dart';

void main() {
  group('peer protocol framing', () {
    test('encodeFrame/decodeFrame roundtrip', () {
      final msg = {'type': 'hello', 'x': 1};
      final framed = encodeFrame(msg);
      final decoded = decodeFrame(framed);
      expect(decoded, isNotNull);
      expect(decoded!.consumed, framed.length);
      expect(jsonDecode(utf8.decode(decoded.payload)), msg);
    });

    test('decodeFrame returns null on an incomplete buffer', () {
      final framed = encodeFrame({'type': 'hello'});
      final partial = Uint8List.sublistView(framed, 0, framed.length - 1);
      expect(decodeFrame(partial), isNull);
    });

    test('decodeFrame rejects an oversize frame', () {
      final bad = Uint8List(4);
      bad.buffer.asByteData().setUint32(0, kMaxWireFrameBytes + 1, Endian.big);
      expect(() => decodeFrame(bad), throwsA(isA<PeerProtocolException>()));
    });

    test(
        'decodeFrame reads the correct length for a SECOND, DIFFERENT-length '
        'frame sliced from the same buffer', () {
      // Reproduces the real bug: PeerLink._absorbControl decodes multiple
      // frames from one chunk by re-slicing `remaining` with
      // Uint8List.sublistView after each frame — so the second frame's
      // buffer is a VIEW with a nonzero offsetInBytes, not a fresh buffer.
      // `pending.buffer.asByteData()` reads from the absolute start of the
      // underlying (shared) buffer, ignoring that offset — so if the two
      // frames differ in length, the second one's length silently comes out
      // as the FIRST frame's length instead of its own. Frames of the SAME
      // length mask this completely (the wrong read coincidentally matches
      // the right answer), which is why the length here must differ.
      final short = encodeFrame({'type': 'request', 'collection': 'finance'});
      final long =
          encodeFrame({'type': 'request', 'collection': 'passwords'});
      expect(short.length, isNot(long.length)); // guard against a future
      // change making these equal-length and silently un-covering the bug.

      final combined = Uint8List(short.length + long.length);
      combined.setRange(0, short.length, short);
      combined.setRange(short.length, combined.length, long);

      final first = decodeFrame(combined);
      expect(jsonDecode(utf8.decode(first!.payload))['collection'], 'finance');

      final remaining = Uint8List.sublistView(combined, first.consumed);
      final second = decodeFrame(remaining);
      expect(second, isNotNull);
      expect(jsonDecode(utf8.decode(second!.payload))['collection'],
          'passwords');
    });
  });

  group('PeerLink over real TCP loopback', () {
    late PeerListener listener;

    tearDown(() async {
      await listener.stop();
    });

    test('mismatched account tokens fail the handshake on both sides',
        () async {
      listener = PeerListener();
      const tokenA = 'account-A-token';
      const tokenB = 'account-B-token';

      final serverClosed = Completer<String?>();
      listener.factory = (socket) => PeerLink(
            socket: socket,
            localHello: _hello('server'),
            handshakeKey: tokenA,
            isInitiator: false,
            onReady: (_) => fail('server should not have accepted a peer '
                'presenting a different account\'s token'),
            onSnapshot: (_, __, ___) async => false,
            provideSnapshot: (_) async => null,
            onClose: (err) => serverClosed.complete(err),
          );
      final port = await listener.start();

      final socket = await Socket.connect('127.0.0.1', port);
      final clientClosed = Completer<String?>();
      PeerLink(
        socket: socket,
        localHello: _hello('client'),
        handshakeKey: tokenB,
        isInitiator: true,
        onReady: (_) => fail('client should not have accepted a peer '
            'presenting a different account\'s token'),
        onSnapshot: (_, __, ___) async => false,
        provideSnapshot: (_) async => null,
        onClose: (err) => clientClosed.complete(err),
      );

      final serverErr =
          await serverClosed.future.timeout(const Duration(seconds: 5));
      final clientErr =
          await clientClosed.future.timeout(const Duration(seconds: 5));
      expect(serverErr, contains('same account'));
      expect(clientErr, contains('same account'));
    });

    group('against someone on the same network without the key', () {
      const key = 'the-real-account-handshake-key';
      late Completer<String?> serverClosed;
      late bool serverReady;
      late List<String> applied;

      Future<_FrameReader> connectRaw() async {
        listener = PeerListener();
        serverClosed = Completer<String?>();
        serverReady = false;
        applied = [];
        listener.factory = (socket) => PeerLink(
              socket: socket,
              localHello: _hello('server',
                  name: 'Office laptop', collections: {'passwords'}),
              handshakeKey: key,
              isInitiator: false,
              onReady: (_) => serverReady = true,
              onSnapshot: (collectionId, _, _) async {
                applied.add(collectionId);
                return true;
              },
              provideSnapshot: (_) async => null,
              onClose: (err) {
                if (!serverClosed.isCompleted) serverClosed.complete(err);
              },
            );
        final port = await listener.start();
        return _FrameReader(await Socket.connect('127.0.0.1', port));
      }

      test('just connecting reveals nothing that can be presented later',
          () async {
        final attacker = await connectRaw();
        final hello = await attacker.next();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // The handshake essentials and nothing else: no token, and not even
        // the device's name or which collections it syncs.
        expect(hello.keys.toSet(), {'type', 'v', 'deviceId', 'nonce', 'epk'});
        expect(isValidPeerNonce(hello['nonce'] as String), isTrue);
        expect(decodePeerPublicKey(hello['epk'] as String), isNotNull);
        final wire = latin1.decode(attacker.raw);
        expect(wire, isNot(contains(key)));
        expect(wire, isNot(contains('Office laptop')));
        expect(wire, isNot(contains('passwords')));
      });

      test('cannot finish the handshake, even by echoing our proof back',
          () async {
        final attacker = await connectRaw();
        final serverHello = PeerHello.fromHelloJson(await attacker.next());
        final socket = attacker._socket;
        socket.add(await _helloFrame(_hello('intruder')));
        await socket.flush();
        final serverProof = await attacker.next();
        expect(serverProof['type'], 'proof');

        socket.add(encodeFrame({'type': 'proof', 'mac': serverProof['mac']}));
        await socket.flush();

        final err =
            await serverClosed.future.timeout(const Duration(seconds: 5));
        expect(err, contains('same account'));
        expect(serverReady, isFalse);
        expect(serverHello.deviceId, 'server');
      });

      test('a snapshot pushed before the handshake is never applied',
          () async {
        final attacker = await connectRaw();
        await attacker.next();
        attacker._socket.add(_blobFrame('passwords', 1 << 50,
            Uint8List.fromList(List.generate(32, (i) => i))));
        await attacker._socket.flush();

        final err =
            await serverClosed.future.timeout(const Duration(seconds: 5));
        expect(err, contains('Handshake failed'));
        expect(applied, isEmpty);
        expect(serverReady, isFalse);
      });

      test('a peer claiming to be this very device is refused', () async {
        final attacker = await connectRaw();
        await attacker.next();
        attacker._socket.add(await _helloFrame(_hello('server')));
        await attacker._socket.flush();

        final err =
            await serverClosed.future.timeout(const Duration(seconds: 5));
        expect(err, contains('invalid hello'));
        expect(serverReady, isFalse);
      });
    });

    test('matching tokens complete the handshake and exchange a snapshot',
        () async {
      listener = PeerListener();
      const token = 'shared-account-token';
      final blob = Uint8List.fromList(List.generate(9000, (i) => i % 256));

      listener.factory = (socket) => PeerLink(
            socket: socket,
            localHello: _hello('server-device'),
            handshakeKey: token,
            isInitiator: false,
            onReady: (_) {},
            onSnapshot: (_, __, ___) async => false,
            provideSnapshot: (collectionId) async => collectionId == 'notes'
                ? (sealed: blob, savedAtMs: 111)
                : null,
            onClose: (_) {},
          );
      final port = await listener.start();

      final clientSocket = await Socket.connect('127.0.0.1', port);
      final receivedBlob = Completer<Uint8List>();
      var receivedSavedAt = 0;
      final clientReady = Completer<PeerHello>();
      final clientLink = PeerLink(
        socket: clientSocket,
        localHello: _hello('client-device'),
        handshakeKey: token,
        isInitiator: true,
        onReady: (hello) => clientReady.complete(hello),
        onSnapshot: (collectionId, sealed, savedAtMs) async {
          receivedSavedAt = savedAtMs;
          receivedBlob.complete(sealed);
          return true;
        },
        provideSnapshot: (_) async => null,
        onClose: (_) {},
      );

      final clientHello =
          await clientReady.future.timeout(const Duration(seconds: 5));
      expect(clientHello.deviceId, 'server-device');

      clientLink.requestCollection('notes');
      final received =
          await receivedBlob.future.timeout(const Duration(seconds: 5));
      expect(received, blob);
      expect(receivedSavedAt, 111);

      await clientLink.close();
    });

    test('two blobs pipelined back-to-back are both delivered intact',
        () async {
      listener = PeerListener();
      const token = 'shared-account-token-2';
      final blobA = Uint8List.fromList(List.generate(37, (i) => i));
      final blobB = Uint8List.fromList(List.generate(129, (i) => 255 - i));

      listener.factory = (socket) => PeerLink(
            socket: socket,
            localHello: _hello('server'),
            handshakeKey: token,
            isInitiator: false,
            onReady: (_) {},
            onSnapshot: (_, __, ___) async => false,
            provideSnapshot: (collectionId) async {
              if (collectionId == 'a') return (sealed: blobA, savedAtMs: 1);
              if (collectionId == 'b') return (sealed: blobB, savedAtMs: 2);
              return null;
            },
            onClose: (_) {},
          );
      final port = await listener.start();

      final received = <String, Uint8List>{};
      final done = Completer<void>();
      final clientSocket = await Socket.connect('127.0.0.1', port);
      late PeerLink clientLink;
      clientLink = PeerLink(
        socket: clientSocket,
        localHello: _hello('client'),
        handshakeKey: token,
        isInitiator: true,
        onReady: (_) {
          // Fire both requests without awaiting in between so the replies
          // are pipelined and likely land in the same socket read, exercising
          // the "trailing bytes start the next frame" path in PeerLink.
          clientLink.requestCollection('a');
          clientLink.requestCollection('b');
        },
        onSnapshot: (collectionId, sealed, savedAtMs) async {
          received[collectionId] = sealed;
          if (received.length == 2 && !done.isCompleted) done.complete();
          return true;
        },
        provideSnapshot: (_) async => null,
        onClose: (_) {},
      );

      await done.future.timeout(const Duration(seconds: 5));
      expect(received['a'], blobA);
      expect(received['b'], blobB);
    });

    test(
        'a slow onSnapshot apply does not corrupt a trailing frame that '
        'arrived in the same chunk', () async {
      // Uses a raw socket on the "server" side (not PeerLink) so the test
      // controls exact chunk boundaries instead of hoping two writes happen
      // to coalesce — the earlier pipelined-request version of this test
      // passed even against the bug, because the request/response round
      // trip didn't reliably land "a" and "b" in the same read.
      listener = PeerListener(); // unused; keeps tearDown's listener.stop() happy.
      const token = 'shared-account-token-3';
      final blobA = Uint8List.fromList(List.generate(20, (i) => i));
      final blobB = Uint8List.fromList(List.generate(20, (i) => 200 - i));
      final blobC = Uint8List.fromList(List.generate(20, (i) => i * 2));

      final rawServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final acceptedSocket = Completer<Socket>();
      rawServer.listen((s) => acceptedSocket.complete(s));

      final clientSocket =
          await Socket.connect('127.0.0.1', rawServer.port);
      final serverSocket =
          await acceptedSocket.future.timeout(const Duration(seconds: 5));
      final serverFrames = _FrameReader(serverSocket);

      final order = <String>[];
      final received = <String, Uint8List>{};
      final done = Completer<void>();
      final clientReady = Completer<void>();
      // Gate collection "a"'s apply so it's still pending when "c" arrives
      // as a later, distinct chunk — reproducing the race where a trailing
      // frame ("b", pipelined in the same chunk as "a") must still be
      // parsed immediately, not deferred behind "a"'s in-flight apply.
      final gateA = Completer<void>();

      final clientLink = PeerLink(
        socket: clientSocket,
        localHello: _hello('client'),
        handshakeKey: token,
        isInitiator: true,
        onReady: (_) => clientReady.complete(),
        onSnapshot: (collectionId, sealed, savedAtMs) async {
          if (collectionId == 'a') await gateA.future;
          order.add(collectionId);
          received[collectionId] = sealed;
          if (received.length == 3 && !done.isCompleted) done.complete();
          return true;
        },
        provideSnapshot: (_) async => null,
        onClose: (_) {},
      );

      // Play the responder's half of the handshake by hand.
      final clientHelloRaw = await serverFrames.nextRaw();
      final clientHello = PeerHello.fromHelloJson(
          jsonDecode(utf8.decode(clientHelloRaw)) as Map<String, dynamic>);
      final serverKeys = await PeerKeyPair.generate();
      final serverHello = _hello('server');
      final serverHelloRaw = _helloBytes(serverHello, serverKeys);
      final session = await derivePeerSession(
        key: token,
        isInitiator: false,
        ownKeyPair: serverKeys,
        peerPublicKey: decodePeerPublicKey(clientHello.publicKey)!,
        initiatorHello: clientHelloRaw,
        responderHello: serverHelloRaw,
      );
      serverSocket.add(encodeRawFrame(serverHelloRaw));
      serverSocket.add(encodeFrame({'type': 'proof', 'mac': session.ownProof}));
      serverSocket.add(await _sealedFrame(session, serverHello.stateJson()));
      await serverSocket.flush();
      await clientReady.future.timeout(const Duration(seconds: 5));

      // blobA immediately followed by blobB in a SINGLE write: guaranteed to
      // arrive as one chunk, exercising the "trailing bytes after a
      // completed blob" path deterministically.
      final combined = BytesBuilder()
        ..add(await _sealedBlob(session, 'a', 1, blobA))
        ..add(await _sealedBlob(session, 'b', 2, blobB));
      serverSocket.add(combined.takeBytes());
      await serverSocket.flush();

      // Give the client time to parse the chunk (and, if fixed, apply "b")
      // while "a" is stuck on the gate — before "c" arrives separately.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      serverSocket.add(await _sealedBlob(session, 'c', 3, blobC));
      await serverSocket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      gateA.complete();

      await done.future.timeout(const Duration(seconds: 5));
      expect(received['a'], blobA);
      expect(received['b'], blobB);
      expect(received['c'], blobC);
      // "b" arrived on the wire before "c" and must be parsed (and applied,
      // since it has no gate) before "c" is — regardless of "a" still being
      // stuck mid-apply.
      expect(order.indexOf('b'), lessThan(order.indexOf('c')));

      await clientLink.close();
      await rawServer.close();
    });
  });

  group('after the handshake, through a relay that sees every byte', () {
    late PeerListener listener;
    late _Relay relay;

    tearDown(() async {
      await relay.close();
      await listener.stop();
    });

    const key = 'shared-account-handshake-key';
    const marker = 'SECRET-SNAPSHOT-MARKER';
    final snapshot = Uint8List.fromList(utf8.encode(marker * 400));
    final fileBytes = Uint8List.fromList(utf8.encode('the plan: $marker'));
    const filePath = 'diary/secret-plan.txt';

    /// A server link behind [relay], and a client connected through it that
    /// asks for the `notes` snapshot as soon as it is ready.
    Future<
        ({
          PeerLink server,
          PeerLink client,
          Future<Uint8List?> snapshot,
          Future<String?> clientClosed,
          List<Uint8List> chunks,
        })> connectThroughRelay({_Tamper? tamperToClient}) async {
      listener = PeerListener();
      final serverLink = Completer<PeerLink>();
      listener.factory = (socket) {
        final link = PeerLink(
          socket: socket,
          localHello: _hello('server',
              name: 'Office laptop', collections: {'passwords'}),
          handshakeKey: key,
          isInitiator: false,
          onReady: (_) {},
          onSnapshot: (_, _, _) async => false,
          provideSnapshot: (id) async =>
              id == 'notes' ? (sealed: snapshot, savedAtMs: 7) : null,
          onClose: (_) {},
        );
        serverLink.complete(link);
        return link;
      };
      final port = await listener.start();
      relay = await _Relay.start(port, tamperToClient: tamperToClient);

      final received = Completer<Uint8List?>();
      final closed = Completer<String?>();
      final chunks = <Uint8List>[];
      late PeerLink client;
      client = PeerLink(
        socket: await Socket.connect('127.0.0.1', relay.port),
        localHello: _hello('client'),
        handshakeKey: key,
        isInitiator: true,
        onReady: (_) => client.requestCollection('notes'),
        onSnapshot: (_, sealed, _) async {
          if (!received.isCompleted) received.complete(sealed);
          return true;
        },
        provideSnapshot: (_) async => null,
        onShareChunk: (_, bytes) async => chunks.add(bytes),
        onClose: (err) {
          if (!received.isCompleted) received.complete(null);
          if (!closed.isCompleted) closed.complete(err);
        },
      );
      return (
        server: await serverLink.future.timeout(const Duration(seconds: 5)),
        client: client,
        snapshot: received.future.timeout(const Duration(seconds: 5)),
        clientClosed: closed.future.timeout(const Duration(seconds: 5)),
        chunks: chunks,
      );
    }

    test('snapshots, shared files and metadata cross it unreadable', () async {
      final link = await connectThroughRelay();
      expect(await link.snapshot, snapshot);

      await link.server.sendShareChunk(
        SharedChunkHeader(
          path: filePath,
          offset: 0,
          length: fileBytes.length,
          totalSize: fileBytes.length,
          modifiedMs: 1,
          hash: 'h',
          isLast: true,
        ),
        fileBytes,
      );
      for (var i = 0; i < 50 && link.chunks.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(link.chunks.single, fileBytes);

      final wire = latin1.decode(relay.seen);
      for (final secret in [
        key,
        marker,
        filePath,
        'Office laptop',
        'passwords',
        'notes',
        'share-chunk',
      ]) {
        expect(wire, isNot(contains(secret)), reason: secret);
      }
      await link.client.close();
    });

    test('an altered frame ends the link instead of being delivered',
        () async {
      // Frame 5 server→client is the snapshot's body: after the hello, the
      // proof, the state and the blob header.
      final link = await connectThroughRelay(
          tamperToClient: (index, frame) => index == 5
              ? [Uint8List.fromList(frame)..[frame.length - 1] ^= 1]
              : [frame]);
      expect(await link.snapshot, isNull);
      expect(await link.clientClosed, contains('authenticity'));
    });

    test('a replayed frame ends the link instead of being delivered',
        () async {
      // The blob header, sent twice: the same bytes, but the copy arrives
      // where the next counter is expected.
      final link = await connectThroughRelay(
          tamperToClient: (index, frame) =>
              index == 4 ? [frame, frame] : [frame]);
      expect(await link.snapshot, isNull);
      expect(await link.clientClosed, contains('authenticity'));
    });
  });
}

/// Raw bytes for a `blob` push sent in the clear — only ever legitimate
/// before there was encryption, which is what the tests using it check.
Uint8List _blobFrame(String collection, int savedAtMs, Uint8List body) {
  final header = encodeFrame({
    'type': 'blob',
    'collection': collection,
    'savedAtMs': savedAtMs,
    'length': body.length,
  });
  final out = Uint8List(header.length + body.length);
  out.setRange(0, header.length, header);
  out.setRange(header.length, header.length + body.length, body);
  return out;
}

PeerHello _hello(String deviceId,
        {String? name, Set<String> collections = const {}}) =>
    PeerHello(
      deviceId: deviceId,
      deviceName: name ?? deviceId,
      platform: 'test',
      nonce: newPeerNonce(),
      collections: {
        for (final c in collections)
          c: const PeerCollectionState(cloudVersion: 1, savedAtMs: 1),
      },
    );

/// [hello]'s handshake payload, carrying [keys]' public half.
Uint8List _helloBytes(PeerHello hello, PeerKeyPair keys) => Uint8List.fromList(
    utf8.encode(jsonEncode(hello.withPublicKey(keys.publicKey).helloJson())));

/// A framed hello with a fresh one-time key, for a hand-played peer that
/// never gets as far as using it.
Future<Uint8List> _helloFrame(PeerHello hello) async =>
    encodeRawFrame(_helloBytes(hello, await PeerKeyPair.generate()));

Future<Uint8List> _sealedFrame(
        PeerSession session, Map<String, Object?> message) async =>
    encodeRawFrame(
        await session.channel.seal(utf8.encode(jsonEncode(message))));

/// A `blob` push exactly as [PeerLink.sendCollection] writes it: the sealed
/// header, then the sealed body, each its own frame.
Future<Uint8List> _sealedBlob(PeerSession session, String collection,
    int savedAtMs, Uint8List body) async {
  final header = await _sealedFrame(session, {
    'type': 'blob',
    'collection': collection,
    'savedAtMs': savedAtMs,
    'length': body.length,
  });
  final sealedBody = encodeRawFrame(await session.channel.seal(body));
  return Uint8List.fromList([...header, ...sealedBody]);
}

/// The frames arriving on a raw socket, one at a time — for tests that play
/// one side of the protocol by hand.
class _FrameReader {
  _FrameReader(this._socket) {
    _socket.listen((chunk) {
      _raw.add(chunk);
      _pending.add(chunk);
      var buffer = _pending.takeBytes();
      while (true) {
        final frame = decodeFrame(buffer);
        if (frame == null) break;
        _frames.add(Uint8List.fromList(frame.payload));
        buffer = Uint8List.sublistView(buffer, frame.consumed);
      }
      _pending.add(buffer);
    }, onError: (_) {});
  }

  final Socket _socket;
  final _pending = BytesBuilder();
  final _raw = BytesBuilder(copy: true);
  final _frames = StreamController<Uint8List>();
  late final _iterator = StreamIterator(_frames.stream);

  /// Every byte received so far, frames or not.
  Uint8List get raw => _raw.toBytes();

  /// The next frame's payload, exactly as received.
  Future<Uint8List> nextRaw() async {
    if (!await _iterator.moveNext().timeout(const Duration(seconds: 5))) {
      throw StateError('socket closed before the next frame');
    }
    return _iterator.current;
  }

  /// The next frame, decoded as a JSON control message.
  Future<Map<String, dynamic>> next() async =>
      jsonDecode(utf8.decode(await nextRaw())) as Map<String, dynamic>;
}

/// What a relay does to the [index]th frame (from 1) it forwards to the
/// client: the frames to send in its place.
typedef _Tamper = List<Uint8List> Function(int index, Uint8List frame);

/// A man in the middle on loopback: forwards one connection to a listener,
/// records every byte both ways, and can rewrite server→client frames.
class _Relay {
  _Relay._(this._server);

  final ServerSocket _server;
  final _seen = BytesBuilder(copy: true);
  final List<Socket> _sockets = [];

  int get port => _server.port;
  Uint8List get seen => _seen.toBytes();

  static Future<_Relay> start(int targetPort, {_Tamper? tamperToClient}) async {
    final relay =
        _Relay._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));
    relay._server.listen((client) async {
      final upstream = await Socket.connect('127.0.0.1', targetPort);
      relay._sockets.addAll([client, upstream]);
      client.listen((bytes) {
        relay._seen.add(bytes);
        upstream.add(bytes);
      }, onDone: upstream.destroy, onError: (_) => upstream.destroy());

      final pending = BytesBuilder();
      var index = 0;
      upstream.listen((bytes) {
        relay._seen.add(bytes);
        if (tamperToClient == null) {
          client.add(bytes);
          return;
        }
        pending.add(bytes);
        var buffer = pending.takeBytes();
        while (true) {
          final frame = decodeFrame(buffer);
          if (frame == null) break;
          for (final out
              in tamperToClient(++index, Uint8List.fromList(frame.payload))) {
            client.add(encodeRawFrame(out));
          }
          buffer = Uint8List.sublistView(buffer, frame.consumed);
        }
        pending.add(buffer);
      }, onDone: client.destroy, onError: (_) => client.destroy());
    });
    return relay;
  }

  Future<void> close() async {
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _server.close();
  }
}
