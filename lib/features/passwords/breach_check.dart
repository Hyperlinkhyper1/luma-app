import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Flags passwords that appear on a bundled, offline list of extremely
/// common / previously breached passwords (SHA-1 hashed, same idea as
/// HaveIBeenPwned's k-anonymity range files but fully local — no network
/// call, the plaintext password never leaves this device).
class BreachChecker {
  BreachChecker._(this._hashes);

  final Set<String> _hashes;
  static BreachChecker? _instance;
  static const _assetPath = 'assets/security/common_password_hashes.txt';

  /// Loads (and caches) the bundled hash list.
  static Future<BreachChecker> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(_assetPath);
    final hashes = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet();
    return _instance = BreachChecker._(hashes);
  }

  /// True if [password] matches a known common/breached password.
  bool isCommon(String password) {
    final hash = sha1.convert(utf8.encode(password)).toString().toUpperCase();
    return _hashes.contains(hash);
  }
}
