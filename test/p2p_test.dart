import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
      bad.buffer.asByteData().setUint32(0, kMaxFrameBytes + 1, Endian.big);
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
            localHello: _hello('server', tokenA),
            expectedToken: tokenA,
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
        localHello: _hello('client', tokenB),
        expectedToken: tokenB,
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

    test('matching tokens complete the handshake and exchange a snapshot',
        () async {
      listener = PeerListener();
      const token = 'shared-account-token';
      final blob = Uint8List.fromList(List.generate(9000, (i) => i % 256));

      listener.factory = (socket) => PeerLink(
            socket: socket,
            localHello: _hello('server-device', token),
            expectedToken: token,
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
        localHello: _hello('client-device', token),
        expectedToken: token,
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
            localHello: _hello('server', token),
            expectedToken: token,
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
        localHello: _hello('client', token),
        expectedToken: token,
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
        localHello: _hello('client', token),
        expectedToken: token,
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

      serverSocket.add(encodeFrame(_hello('server', token).toJson()));
      await serverSocket.flush();
      await clientReady.future.timeout(const Duration(seconds: 5));

      // blobA immediately followed by blobB in a SINGLE write: guaranteed to
      // arrive as one chunk, exercising the "trailing bytes after a
      // completed blob" path deterministically.
      final combined = BytesBuilder()
        ..add(_blobFrame('a', 1, blobA))
        ..add(_blobFrame('b', 2, blobB));
      serverSocket.add(combined.takeBytes());
      await serverSocket.flush();

      // Give the client time to parse the chunk (and, if fixed, apply "b")
      // while "a" is stuck on the gate — before "c" arrives separately.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      serverSocket.add(_blobFrame('c', 3, blobC));
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
}

/// Raw bytes for a `blob` push: the control-frame header followed
/// immediately by the raw sealed body — exactly what [PeerLink.sendCollection]
/// writes to the wire.
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

PeerHello _hello(String deviceId, String token) => PeerHello(
      deviceId: deviceId,
      deviceName: deviceId,
      platform: 'test',
      token: token,
      collections: const {},
    );
