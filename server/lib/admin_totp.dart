import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;

import 'util.dart';

/// RFC 4648 base32 without padding — the alphabet authenticator apps expect
/// for a TOTP setup key.
const _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

String base32Encode(List<int> bytes) {
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      out.write(_base32Alphabet[(buffer >> (bits - 5)) & 31]);
      bits -= 5;
    }
  }
  if (bits > 0) out.write(_base32Alphabet[(buffer << (5 - bits)) & 31]);
  return out.toString();
}

/// Null for anything that isn't base32. Spaces, dashes and `=` padding are
/// ignored, and case doesn't matter, so a key copied out of an authenticator
/// app's export decodes as-is.
Uint8List? base32Decode(String input) {
  final clean = input.toUpperCase().replaceAll(RegExp(r'[\s=-]'), '');
  if (clean.isEmpty) return null;
  final out = BytesBuilder();
  var buffer = 0;
  var bits = 0;
  for (final ch in clean.split('')) {
    final v = _base32Alphabet.indexOf(ch);
    if (v < 0) return null;
    buffer = ((buffer << 5) | v) & 0xFFFF;
    bits += 5;
    if (bits >= 8) {
      out.addByte((buffer >> (bits - 8)) & 0xFF);
      bits -= 8;
    }
  }
  return out.takeBytes();
}

/// The 6-digit RFC 6238 code for [secret] at 30-second time step [step]
/// (HMAC-SHA1, the default every authenticator app implements).
String totpCode(List<int> secret, int step) {
  final counter = ByteData(8)..setUint64(0, step, Endian.big);
  final mac = c.Hmac(c.sha1, secret).convert(counter.buffer.asUint8List()).bytes;
  final offset = mac[mac.length - 1] & 0x0f;
  final binary = ((mac[offset] & 0x7f) << 24) |
      (mac[offset + 1] << 16) |
      (mac[offset + 2] << 8) |
      mac[offset + 3];
  return (binary % 1000000).toString().padLeft(6, '0');
}

int totpStep(int nowMs) => nowMs ~/ 30000;

/// The admin dashboard's second factor: a TOTP secret shared with the
/// operator's authenticator app, so the admin key alone no longer unlocks
/// deploys, reboots and every account.
///
/// The secret comes from LUMA_ADMIN_TOTP_SECRET when that is set. Otherwise
/// the operator enrolls once from /admin/login — after the admin key, the
/// page hands out a fresh secret and only keeps it once a code from it has
/// been typed back — and it is stored in `admin_totp.json` in the data
/// directory. Deleting that file on the host is how an operator who lost
/// their phone re-enrolls; nothing reachable over HTTP can reset it.
class AdminTotp {
  AdminTotp(this.dataDir, {String? envSecret})
      : _envSecret = envSecret == null || envSecret.trim().isEmpty
            ? null
            : base32Decode(envSecret) {
    if (envSecret != null && envSecret.trim().isNotEmpty) {
      final decoded = _envSecret;
      if (decoded == null || decoded.length < 10) {
        misconfigured = true;
        stderr.writeln('[luma] LUMA_ADMIN_TOTP_SECRET is not a base32 key of '
            'at least 16 characters — the admin dashboard stays locked until '
            'it is fixed or removed.');
      }
    }
    _load();
  }

  final String dataDir;
  final Uint8List? _envSecret;
  Uint8List? _fileSecret;

  /// Whether a broken LUMA_ADMIN_TOTP_SECRET is locking the dashboard. It
  /// fails closed: falling back to enrollment would let whoever reaches the
  /// login page first pick the second factor.
  bool misconfigured = false;

  /// The last time step a login was accepted for. A code is good for one
  /// sign-in only, so a code read over the operator's shoulder (or out of
  /// a proxy log) can't be replayed inside its 30-second window.
  int _lastStep = -1;

  File get _file => File('$dataDir/admin_totp.json');

  Uint8List? get secret => misconfigured ? null : (_envSecret ?? _fileSecret);
  bool get enrolled => secret != null;

  void _load() {
    try {
      if (!_file.existsSync()) return;
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is! Map) return;
      final raw = decoded['secret'];
      if (raw is String) _fileSecret = base32Decode(raw);
      final last = decoded['lastStep'];
      if (last is int) _lastStep = last;
    } catch (e) {
      stderr.writeln('[luma] could not read ${_file.path}: $e');
    }
  }

  void _save() {
    try {
      _file.writeAsStringSync(jsonEncode({
        if (_fileSecret != null) 'secret': base32Encode(_fileSecret!),
        'lastStep': _lastStep,
      }));
    } catch (e) {
      stderr.writeln('[luma] could not save ${_file.path}: $e');
    }
  }

  /// A new random 160-bit secret, the size RFC 4226 recommends.
  static Uint8List newSecret() => randomBytes(20);

  /// Checks [code] against [against] (the enrolled secret by default),
  /// allowing one step of clock drift either way. Returns the matching step,
  /// or null.
  int? _match(String code, List<int> against, int nowMs) {
    final digits = code.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(digits)) return null;
    final now = totpStep(nowMs);
    int? hit;
    for (final step in [now - 1, now, now + 1]) {
      if (constantTimeEquals(
          utf8.encode(totpCode(against, step)), utf8.encode(digits))) {
        hit = step;
      }
    }
    return hit;
  }

  /// Verifies a code for a sign-in and burns its time step, so the same code
  /// (or an older one) never works twice.
  bool verifyLogin(String code, {int? nowMs}) {
    final s = secret;
    if (s == null) return false;
    final step = _match(code, s, nowMs ?? DateTime.now().millisecondsSinceEpoch);
    if (step == null || step <= _lastStep) return false;
    _lastStep = step;
    _save();
    return true;
  }

  /// Verifies a code without burning it — for the `X-Admin-Totp` header,
  /// where one script makes several calls inside the same 30 seconds.
  bool verifyHeader(String code, {int? nowMs}) {
    final s = secret;
    if (s == null) return false;
    return _match(code, s, nowMs ?? DateTime.now().millisecondsSinceEpoch) !=
        null;
  }

  /// Keeps [candidate] as the enrolled secret if [code] came from it. Fails
  /// once anything is enrolled, so a second person holding the admin key
  /// can't swap the operator's authenticator for their own.
  bool completeEnrollment(Uint8List candidate, String code, {int? nowMs}) {
    if (enrolled || misconfigured) return false;
    final step =
        _match(code, candidate, nowMs ?? DateTime.now().millisecondsSinceEpoch);
    if (step == null) return false;
    _fileSecret = candidate;
    _lastStep = step;
    _save();
    return true;
  }

  /// `otpauth://` link for [secret]; opening it on a phone adds the account
  /// to the authenticator app directly.
  static String otpauthUri(Uint8List secret, {String account = 'admin'}) =>
      'otpauth://totp/${Uri.encodeComponent('luma:$account')}'
      '?secret=${base32Encode(secret)}&issuer=luma&algorithm=SHA1'
      '&digits=6&period=30';
}
