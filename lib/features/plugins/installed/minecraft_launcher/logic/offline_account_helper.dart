import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Derives the deterministic "offline mode" UUID the vanilla launcher uses
/// for cracked/offline accounts: a version-3 (name-based, MD5) UUID over the
/// UTF-8 bytes of `"OfflinePlayer:<name>"`.
///
/// Kept as a pure function so it's trivially testable — same username always
/// yields the same UUID, matching vanilla's behavior (worlds/whitelists keyed
/// by UUID stay stable across relaunches).
String offlinePlayerUuid(String username) {
  final bytes = utf8.encode('OfflinePlayer:$username');
  final hash = md5.convert(bytes).bytes;
  final buf = Uint8List.fromList(hash);

  // RFC 4122 §4.3: set version (3) and variant (RFC 4122) bits.
  buf[6] = (buf[6] & 0x0F) | 0x30;
  buf[8] = (buf[8] & 0x3F) | 0x80;

  String hex(int start, int end) =>
      buf.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
