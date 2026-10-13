import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'authenticated_cipher.dart';
import 'secure_secret_store.dart';

/// Encrypted credential persistence with an atomic, recoverable legacy migration.
class EncryptedCredentialFile {
  EncryptedCredentialFile._(
    this._file,
    this._key,
    this._context,
    this._pendingLegacyFile,
  );

  static const _prefix = 'enc:v1:';
  final File _file;
  final Uint8List _key;
  final String _context;
  File? _pendingLegacyFile;
  Future<void> _writes = Future.value();

  static Future<EncryptedCredentialFile> load({
    required Directory directory,
    required String keyName,
    required String fileName,
    required String context,
    SecureSecretStore? secretStore,
    bool recoverCorruptLegacy = false,
  }) async {
    await directory.create(recursive: true);
    final file = File('${directory.path}/$fileName');
    final legacyFile = File('${directory.path}/$keyName');
    final store = secretStore ?? SecureSecretStore.instance;
    final legacyExists = await legacyFile.exists();
    String? legacyPayload;
    var corruptLegacy = false;
    if (legacyExists && await file.exists()) {
      try {
        final token = utf8.decode(await file.readAsBytes()).trim();
        if (token.isNotEmpty && !token.startsWith(_prefix)) {
          final encodedKey = utf8.decode(await legacyFile.readAsBytes()).trim();
          legacyPayload = _decryptLegacy(token, base64Decode(encodedKey));
        }
      } on FormatException {
        if (!recoverCorruptLegacy) rethrow;
        corruptLegacy = true;
      }
    }
    final key = await store.loadKey(
      keyName,
      encryptedData: legacyExists ? [] : [file, File('${file.path}.tmp')],
    );
    final result = EncryptedCredentialFile._(
      file,
      key,
      context,
      legacyExists ? legacyFile : null,
    );
    if (legacyPayload != null) {
      await result.write(legacyPayload);
    } else if (!corruptLegacy && legacyExists && await file.exists()) {
      final bytes = await file.readAsBytes();
      try {
        final token = utf8.decode(bytes).trim();
        if (token.isNotEmpty) {
          result._decrypt(token);
        }
      } catch (_) {
        if (!recoverCorruptLegacy) rethrow;
        corruptLegacy = true;
      }
    }
    if (!corruptLegacy) await result._discardLegacyKey();
    return result;
  }

  Future<String?> read() async {
    await _writes;
    if (!await _file.exists()) return null;
    try {
      return _decrypt((await _file.readAsString()).trim());
    } catch (_) {
      return null;
    }
  }

  String _decrypt(String token) {
    if (!token.startsWith(_prefix)) {
      throw const FormatException('Unsupported credential envelope');
    }
    return utf8.decode(
      AuthenticatedCipher.open(
        base64Decode(token.substring(_prefix.length)),
        _key,
        _context,
      ),
    );
  }

  Future<void> write(String payload) {
    final next = _writes.then((_) async {
      final encrypted =
          '$_prefix${base64Encode(AuthenticatedCipher.seal(utf8.encode(payload), _key, _context))}';
      final temporary = File('${_file.path}.tmp');
      await temporary.writeAsString(encrypted, flush: true);
      await temporary.rename(_file.path);
      await _discardLegacyKey();
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> clear() {
    final next = _writes.then((_) async {
      for (final file in [_file, File('${_file.path}.tmp')]) {
        if (await file.exists()) await file.delete();
      }
      await _discardLegacyKey();
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> _discardLegacyKey() async {
    final legacyFile = _pendingLegacyFile;
    if (legacyFile != null && await legacyFile.exists()) {
      await legacyFile.delete();
    }
    _pendingLegacyFile = null;
  }

  static String _decryptLegacy(String token, List<int> key) {
    if (key.length != 32) {
      throw const FormatException('Invalid legacy credential key');
    }
    final raw = base64Decode(token);
    if (raw.length < 28) {
      throw const FormatException('Invalid legacy credential envelope');
    }
    final nonce = raw.sublist(0, 12);
    final cipher = raw.sublist(12, raw.length - 16);
    final tag = raw.sublist(raw.length - 16);
    final hmac = Hmac(sha256, key);
    final expected = hmac.convert([...nonce, ...cipher]).bytes;
    var difference = 0;
    for (var i = 0; i < tag.length; i++) {
      difference |= tag[i] ^ expected[i];
    }
    if (difference != 0) {
      throw const FormatException('Legacy credential authentication failed');
    }
    final clear = Uint8List(cipher.length);
    var offset = 0;
    var counter = 0;
    while (offset < cipher.length) {
      final bytes = (ByteData(
        4,
      )..setUint32(0, counter++, Endian.big)).buffer.asUint8List();
      final block = hmac.convert([...nonce, ...bytes]).bytes;
      for (
        var i = 0;
        i < block.length && offset < cipher.length;
        i++, offset++
      ) {
        clear[offset] = cipher[offset] ^ block[i];
      }
    }
    return utf8.decode(clear);
  }
}
