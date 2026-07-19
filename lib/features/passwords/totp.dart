import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// RFC 6238 TOTP code generation (HMAC-SHA1, 30s step, 6 digits — the values
/// every mainstream authenticator app assumes when a service just gives you
/// a bare base32 secret).
class Totp {
  const Totp._();

  static const int periodSeconds = 30;
  static const int digits = 6;

  /// Generates the current code for [base32Secret] (spaces/hyphens and
  /// padding are ignored, case-insensitive — how most services present the
  /// "manual setup" key). Returns null if the secret doesn't decode to any
  /// bytes.
  static String? currentCode(String base32Secret, {DateTime? now}) {
    final key = _base32Decode(base32Secret);
    if (key == null || key.isEmpty) return null;
    final seconds = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/
        1000;
    final counter = seconds ~/ periodSeconds;
    return _hotp(key, counter);
  }

  /// Seconds remaining in the current 30s step, for a countdown indicator.
  static int secondsRemaining({DateTime? now}) {
    final seconds = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/
        1000;
    return periodSeconds - (seconds % periodSeconds);
  }

  static String _hotp(Uint8List key, int counter) {
    final counterBytes = ByteData(8)..setInt64(0, counter, Endian.big);
    final hash = Hmac(sha1, key).convert(counterBytes.buffer.asUint8List()).bytes;
    final offset = hash[hash.length - 1] & 0x0f;
    final binary = ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);
    final code = binary % _pow10(digits);
    return code.toString().padLeft(digits, '0');
  }

  static int _pow10(int n) {
    var result = 1;
    for (var i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }

  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static Uint8List? _base32Decode(String input) {
    final cleaned =
        input.toUpperCase().replaceAll(RegExp(r'[\s\-=]'), '');
    if (cleaned.isEmpty) return null;
    final out = <int>[];
    var buffer = 0;
    var bitsLeft = 0;
    for (final char in cleaned.split('')) {
      final value = _alphabet.indexOf(char);
      if (value < 0) return null; // not valid base32
      buffer = (buffer << 5) | value;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        out.add((buffer >> bitsLeft) & 0xff);
      }
    }
    return Uint8List.fromList(out);
  }
}
