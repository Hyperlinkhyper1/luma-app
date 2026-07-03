import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Cryptographically secure random bytes.
Uint8List randomBytes(int length) {
  final rng = Random.secure();
  return Uint8List.fromList(List<int>.generate(length, (_) => rng.nextInt(256)));
}

/// PBKDF2-HMAC-SHA256 (RFC 2898). Used to hash the client's already-derived
/// auth key before storing it, using only the `crypto` package.
Uint8List pbkdf2Sha256(
    List<int> password, List<int> salt, int iterations, int dkLen) {
  final hmac = Hmac(sha256, password);
  final out = BytesBuilder();
  var block = 1;
  while (out.length < dkLen) {
    final counter = ByteData(4)..setUint32(0, block, Endian.big);
    var u = Uint8List.fromList(
        hmac.convert([...salt, ...counter.buffer.asUint8List()]).bytes);
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.add(t);
    block++;
  }
  return Uint8List.fromList(out.takeBytes().sublist(0, dkLen));
}

/// Compares two byte lists without leaking where they differ.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Writes [bytes] to [path] atomically: write a temp file, then rename over
/// the target so readers never observe a half-written file.
Future<void> atomicWriteBytes(String path, List<int> bytes) async {
  final tmp = File('$path.tmp');
  await tmp.writeAsBytes(bytes, flush: true);
  await tmp.rename(path);
}

Future<void> atomicWriteString(String path, String content) =>
    atomicWriteBytes(path, utf8.encode(content));

/// Loose but effective email shape check; the client is trusted to have the
/// user's real address, the server only needs a stable identifier.
final RegExp emailPattern =
    RegExp(r'^[^@\s]{1,64}@[^@\s]{1,255}\.[^@\s.]{2,24}$');

/// Collection names are chosen by the client but must stay filesystem-safe.
final RegExp collectionPattern = RegExp(r'^[a-z0-9_]{1,32}$');

/// Serializes async mutations so two requests never interleave writes.
class AsyncLock {
  Future<void> _tail = Future.value();

  Future<T> synchronized<T>(Future<T> Function() action) {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }
}
