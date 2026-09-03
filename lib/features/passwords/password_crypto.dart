import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Encrypts password secrets at rest so they are not readable in the raw
/// database file.
///
/// We deliberately avoid a heavyweight cipher dependency: this is an
/// encrypt-then-MAC stream cipher built on HMAC-SHA256 (used as a PRF in
/// counter mode), which the `crypto` package already provides. A random 32-byte
/// key is generated once and stored next to the database in the app's local
/// support directory. This protects secrets against anyone reading the SQLite
/// file directly without also holding the key file; it is not a substitute for
/// a master-password vault.
///
/// Each ciphertext's MAC is bound to the entry's row id and field name (see
/// [encrypt]/[decrypt]), so someone with write access to the raw database file
/// cannot swap one entry's ciphertext into another entry (or into a different
/// field) undetected — without that binding, a byte-for-byte copy would still
/// pass the integrity check.
class PasswordCrypto {
  PasswordCrypto._(this._key);

  final Uint8List _key;

  static const _keyFileName = 'luma_pw.key';
  static const _nonceLength = 12;
  static const _macLength = 16;

  /// Marks a token as using the entry/field-bound MAC. Tokens written before
  /// this scheme existed have no version byte — see the legacy fallback in
  /// [decrypt].
  static const _versionByte = 0x02;

  static PasswordCrypto? _instance;

  /// Loads the key from disk (creating it on first run) and returns a shared
  /// instance.
  static Future<PasswordCrypto> load() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$_keyFileName');

    Uint8List key;
    if (await file.exists()) {
      key = base64Decode((await file.readAsString()).trim());
    } else {
      key = _randomBytes(32);
      await file.writeAsString(base64Encode(key), flush: true);
    }
    return _instance = PasswordCrypto._(key);
  }

  /// Returns a base64 token of `version || nonce || ciphertext || mac`, with
  /// the MAC bound to [entryId]/[field] so this ciphertext cannot be silently
  /// swapped into a different row or column.
  String encrypt(String plaintext, {required int entryId, required String field}) {
    final nonce = _randomBytes(_nonceLength);
    final data = utf8.encode(plaintext);
    final cipher = _xorKeystream(data, nonce);
    final mac = _mac(_context(entryId, field), nonce, cipher);
    final out = Uint8List(1 + nonce.length + cipher.length + mac.length)
      ..[0] = _versionByte
      ..setAll(1, nonce)
      ..setAll(1 + nonce.length, cipher)
      ..setAll(1 + nonce.length + cipher.length, mac);
    return base64Encode(out);
  }

  /// Reverses [encrypt]. Returns null if the token is malformed or fails
  /// integrity verification (e.g. produced under a different key, or for a
  /// different entry/field) — callers must surface that distinctly rather
  /// than treating it as an empty value, so corruption or a swapped
  /// ciphertext can't masquerade as a blank password.
  ///
  /// Also accepts the pre-binding legacy format (no version byte, MAC not
  /// bound to [entryId]/[field]) so vaults created before this scheme existed
  /// keep decrypting; callers should re-[encrypt] and save such entries to
  /// upgrade them (see [isLegacyFormat]).
  String? decrypt(String token, {required int entryId, required String field}) {
    try {
      final raw = base64Decode(token);
      if (raw.isNotEmpty && raw[0] == _versionByte) {
        final body = raw.sublist(1);
        if (body.length >= _nonceLength + _macLength) {
          final nonce = body.sublist(0, _nonceLength);
          final cipher = body.sublist(_nonceLength, body.length - _macLength);
          final mac = body.sublist(body.length - _macLength);
          final expected = _mac(_context(entryId, field), nonce, cipher);
          if (_constantTimeEquals(mac, expected)) {
            return utf8.decode(_xorKeystream(cipher, nonce));
          }
        }
      }
      // Legacy format: no version byte, MAC computed over nonce||cipher only.
      if (raw.length >= _nonceLength + _macLength) {
        final nonce = raw.sublist(0, _nonceLength);
        final cipher = raw.sublist(_nonceLength, raw.length - _macLength);
        final mac = raw.sublist(raw.length - _macLength);
        final expected = _legacyMac(nonce, cipher);
        if (_constantTimeEquals(mac, expected)) {
          return utf8.decode(_xorKeystream(cipher, nonce));
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// True if [token] only decodes under the legacy (unbound) format — used by
  /// [PasswordRepository.migrateLegacyCiphertexts] to find entries that still
  /// need to be rewritten under the entry/field-bound scheme.
  bool isLegacyFormat(String token) {
    try {
      final raw = base64Decode(token);
      return raw.isEmpty || raw[0] != _versionByte;
    } catch (_) {
      return false;
    }
  }

  static Uint8List _context(int entryId, String field) =>
      Uint8List.fromList(utf8.encode('luma-pw-entry|id:$entryId|field:$field'));

  /// XORs [data] with a keystream derived from [nonce] in counter mode.
  Uint8List _xorKeystream(List<int> data, List<int> nonce) {
    final out = Uint8List(data.length);
    final hmac = Hmac(sha256, _key);
    var counter = 0;
    var offset = 0;
    while (offset < data.length) {
      final block = hmac.convert([...nonce, ..._counterBytes(counter)]).bytes;
      for (var i = 0; i < block.length && offset < data.length; i++, offset++) {
        out[offset] = data[offset] ^ block[i];
      }
      counter++;
    }
    return out;
  }

  Uint8List _mac(Uint8List context, List<int> nonce, List<int> cipher) {
    final tag =
        Hmac(sha256, _key).convert([...context, ...nonce, ...cipher]).bytes;
    return Uint8List.fromList(tag.sublist(0, _macLength));
  }

  Uint8List _legacyMac(List<int> nonce, List<int> cipher) {
    final tag = Hmac(sha256, _key).convert([...nonce, ...cipher]).bytes;
    return Uint8List.fromList(tag.sublist(0, _macLength));
  }

  static Uint8List _counterBytes(int counter) {
    final b = ByteData(4)..setUint32(0, counter, Endian.big);
    return b.buffer.asUint8List();
  }

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => rng.nextInt(256)));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
