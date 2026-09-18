import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// OS-protected credential storage. An unavailable keyring is an error;
/// callers must never fall back to writing plaintext secrets.
class SecureSecretStore {
  SecureSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static final instance = SecureSecretStore();
  final FlutterSecureStorage _storage;
  final Map<String, Future<Uint8List>> _pendingKeys = {};

  Future<String?> read(String name) => _storage.read(key: 'luma.$name');

  Future<void> write(String name, String value) async {
    await _storage.write(key: 'luma.$name', value: value);
    if (await read(name) != value) {
      throw StateError('Secure storage verification failed.');
    }
  }

  Future<void> delete(String name) => _storage.delete(key: 'luma.$name');

  /// Transfers the existing key unchanged, verifies storage, then removes
  /// the old file. Failure preserves the only recoverable legacy key.
  Future<Uint8List> loadKey(
    String name,
    File legacyFile, {
    required bool encryptedDataExists,
  }) {
    return _pendingKeys.putIfAbsent(name, () async {
      try {
        final saved = await read(name);
        final legacy = await legacyFile.exists()
            ? (await legacyFile.readAsString()).trim()
            : null;
        if (saved != null && legacy != null && saved != legacy) {
          throw StateError(
            'Conflicting encryption keys; restore requires review.',
          );
        }
        var encoded = saved ?? legacy;
        if (encoded == null) {
          if (encryptedDataExists) {
            throw StateError(
              'Encryption key is missing. Restore the original key.',
            );
          }
          final random = Random.secure();
          encoded = base64Encode(List.generate(32, (_) => random.nextInt(256)));
        }
        final key = base64Decode(encoded);
        if (key.length != 32) {
          throw const FormatException('Invalid stored encryption key.');
        }
        await write(name, encoded);
        if (legacy != null) await legacyFile.delete();
        return key;
      } finally {
        _pendingKeys.remove(name);
      }
    });
  }
}
