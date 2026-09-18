import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as legacy;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:flutter/foundation.dart';

/// App-lock verifier, not a vault encryption key. The fixed version selects
/// reviewed KDF costs; untrusted stored values cannot increase resource use.
class PasswordHash {
  static const _version = 'argon2id-v1';

  static Future<String> create(String password) async {
    final random = Random.secure();
    final salt = List.generate(16, (_) => random.nextInt(256));
    final hash = await compute(_derive, (password, salt));
    return '$_version:${base64Encode(salt)}:${base64Encode(hash)}';
  }

  static Future<bool> verify(String password, String stored) async {
    if (RegExp(r'^[0-9a-f]{64}$').hasMatch(stored)) {
      return constantTimeBytesEquality.equals(
        utf8.encode(legacy.sha256.convert(utf8.encode(password)).toString()),
        utf8.encode(stored),
      );
    }
    try {
      final parts = stored.split(':');
      if (parts.length != 3 || parts[0] != _version || stored.length > 150) {
        return false;
      }
      final salt = base64Decode(parts[1]);
      final expected = base64Decode(parts[2]);
      if (salt.length != 16 || expected.length != 32) return false;
      final actual = await compute(_derive, (password, salt));
      return constantTimeBytesEquality.equals(actual, expected);
    } catch (_) {
      return false;
    }
  }

  static bool needsUpgrade(String stored) => !stored.startsWith('$_version:');

  static Future<List<int>> _derive((String, List<int>) input) async {
    final key = await Argon2id(
      memory: 19456,
      iterations: 2,
      parallelism: 1,
      hashLength: 32,
    ).deriveKey(secretKey: SecretKey(utf8.encode(input.$1)), nonce: input.$2);
    return key.extractBytes();
  }
}
