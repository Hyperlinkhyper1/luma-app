import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/sftp/host/host_crypto.dart';
import 'package:luma/features/plugins/installed/sftp/host/host_protocol.dart';

/// The record layer after it went parallel: records may be sealed and opened
/// concurrently on the cipher pool, but their nonces are fixed in call order,
/// so the wire order is still the only order that opens — and tampering is
/// still caught.
void main() {
  /// A real handshake over an in-memory pipe, so the test gets the same two
  /// channel halves a host and a client would.
  Future<({HostSecureChannel host, HostSecureChannel client})> pair() async {
    final toHost = StreamController<Map<String, dynamic>>();
    final toClient = StreamController<Map<String, dynamic>>();
    final hostInbox = StreamIterator(toHost.stream);
    final clientInbox = StreamIterator(toClient.stream);
    Future<Map<String, dynamic>> read(StreamIterator<Map<String, dynamic>> it) async {
      await it.moveNext();
      return it.current;
    }

    final seed = secureRandomBytes(32);
    final hello = HostHello(
      version: kHostProtocolVersion,
      hostName: 'host',
      salt: secureRandomBytes(16),
      publicKey: await publicKeyForSeed(seed),
      rootName: 'Shared',
      readOnly: false,
    );
    final host = HostHandshake.acceptAsHost(
      password: 'correct horse battery',
      hello: hello,
      hostPrivateSeed: seed,
      readControl: () => read(hostInbox),
      writeControl: (m) async => toClient.add(m),
    );
    final client = HostHandshake.connectAsClient(
      password: 'correct horse battery',
      deviceName: 'client',
      readControl: () => read(clientInbox),
      writeControl: (m) async => toHost.add(m),
    );
    return (host: (await host).channel, client: (await client).channel);
  }

  Uint8List chunk(int seed, [int length = kHostChunkBytes]) =>
      Uint8List.fromList(List.generate(length, (i) => (i * 7 + seed) & 0xff));

  test('records sealed concurrently open in call order, byte for byte',
      () async {
    final channels = await pair();
    // Mixed sizes: big ones go to the worker pool, small ones are done in
    // place, so completion order differs from call order.
    final plains = [
      for (var i = 0; i < 24; i++) chunk(i, i.isEven ? kHostChunkBytes : 40),
    ];
    final sealed = await Future.wait(plains.map(channels.host.seal));

    // Opened concurrently too, as the receiver now does.
    final opened = await Future.wait(sealed.map(channels.client.open));
    for (var i = 0; i < plains.length; i++) {
      expect(opened[i], plains[i], reason: 'record $i');
    }
  });

  test('a record opened out of turn fails', () async {
    final channels = await pair();
    final first = await channels.host.seal(chunk(1));
    final second = await channels.host.seal(chunk(2));
    await expectLater(
      channels.client.open(second),
      throwsA(isA<HostProtocolException>()),
    );
    // And the one that was really next is now out of turn as well: after a
    // failure the connection is dropped, never resynchronised.
    await expectLater(
      channels.client.open(first),
      throwsA(isA<HostProtocolException>()),
    );
  });

  test('a flipped byte in a pooled record is caught', () async {
    final channels = await pair();
    final sealed = await channels.host.seal(chunk(3));
    sealed[sealed.length ~/ 2] ^= 0x01;
    await expectLater(
      channels.client.open(sealed),
      throwsA(isA<HostProtocolException>()),
    );
  });

  test('each direction has its own keys', () async {
    final channels = await pair();
    final fromClient = await channels.client.seal(chunk(4));
    // The client cannot open its own record: it is keyed for the host.
    await expectLater(
      channels.client.open(fromClient),
      throwsA(isA<HostProtocolException>()),
    );
    expect(await channels.host.open(fromClient), chunk(4));
  });
}
