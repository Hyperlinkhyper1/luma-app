import 'dart:async';
import 'dart:convert';

import 'package:luma_sync_server/util.dart';
import 'package:test/test.dart';

/// Login hashing runs off the event loop, so a burst of sign-ins can't
/// stall every other request.
void main() {
  test('matches the inline hash', () async {
    final password = utf8.encode('password');
    final salt = utf8.encode('salt');
    final inline = pbkdf2Sha256(password, salt, 4096, 32);
    expect(await pbkdf2Sha256Async(password, salt, 4096, 32), inline);
    // RFC 7914 §11 PBKDF2-HMAC-SHA256 vector (c = 1, dkLen = 64), first half.
    expect(
        base64Encode(pbkdf2Sha256(password, salt, 1, 32)),
        base64Encode([
          0x12, 0x0f, 0xb6, 0xcf, 0xfc, 0xf8, 0xb3, 0x2c, //
          0x43, 0xe7, 0x22, 0x52, 0x56, 0xc4, 0xf8, 0x37,
          0xa8, 0x65, 0x48, 0xc9, 0x2c, 0xcc, 0x35, 0x48,
          0x08, 0x05, 0x98, 0x7c, 0xb7, 0x0b, 0xe1, 0x7b,
        ]));
  });

  test('the event loop keeps running while a hash is in progress', () async {
    var ticks = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 5), (_) => ticks++);
    await pbkdf2Sha256Async(utf8.encode('k'), utf8.encode('s'), 300000, 32);
    timer.cancel();
    expect(ticks, greaterThan(3));
  });

  test('the semaphore never runs more than its permits at once', () async {
    final gate = AsyncSemaphore(2);
    var running = 0;
    var peak = 0;
    await Future.wait([
      for (var i = 0; i < 8; i++)
        gate.run(() async {
          running++;
          if (running > peak) peak = running;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          running--;
        }),
    ]);
    expect(peak, 2);
  });
}
