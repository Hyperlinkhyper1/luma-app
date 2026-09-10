import 'dart:convert';

import 'password_crypto.dart';

/// Packs private metadata into the existing unbounded info column. This
/// avoids truncating ciphertext in the bounded legacy service/email columns.
class PasswordMetadata {
  static const prefix = 'pwm1:';
  static const placeholder = 'Encrypted';
  static const fields = [
    'service',
    'email',
    'username',
    'phone',
    'info',
    'icon',
  ];

  static bool isEncrypted(Map<String, Object?> row) =>
      row['info'] is String && (row['info'] as String).startsWith(prefix);

  static Map<String, Object?> open(
    Map<String, Object?> row,
    PasswordCrypto crypto,
    int id,
  ) {
    if (!isEncrypted(row)) {
      if (row['password_cipher'] is String &&
          (row['password_cipher'] as String).startsWith('pw3:')) {
        throw const FormatException('Missing authenticated vault metadata.');
      }
      return Map.of(row);
    }
    final clear = crypto.decrypt(
      (row['info'] as String).substring(prefix.length),
      entryId: id,
      field: 'metadata',
    );
    if (clear == null) {
      throw const FormatException('Vault metadata failed authentication.');
    }
    final metadata = jsonDecode(clear);
    if (metadata is! Map<String, dynamic> ||
        metadata['service'] is! String ||
        metadata['email'] is! String ||
        fields.any((f) => metadata[f] != null && metadata[f] is! String)) {
      throw const FormatException('Invalid vault metadata.');
    }
    return {...row, for (final field in fields) field: metadata[field]};
  }

  static Map<String, Object?> seal(
    Map<String, Object?> row,
    PasswordCrypto crypto,
    int id,
  ) {
    final metadata = {for (final field in fields) field: row[field]};
    if (metadata['service'] is! String ||
        metadata['email'] is! String ||
        fields.any((f) => metadata[f] != null && metadata[f] is! String)) {
      throw const FormatException('Invalid vault metadata.');
    }
    final token = crypto.encrypt(
      jsonEncode(metadata),
      entryId: id,
      field: 'metadata',
    );
    if (crypto.decrypt(token, entryId: id, field: 'metadata') !=
        jsonEncode(metadata)) {
      throw StateError('Vault metadata verification failed.');
    }
    return {
      ...row,
      'service': placeholder,
      'email': placeholder,
      'username': null,
      'phone': null,
      'icon': null,
      'info': '$prefix$token',
    };
  }
}
