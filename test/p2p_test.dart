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
  });
}

PeerHello _hello(String deviceId, String token) => PeerHello(
      deviceId: deviceId,
      deviceName: deviceId,
      platform: 'test',
      token: token,
      collections: const {},
    );
