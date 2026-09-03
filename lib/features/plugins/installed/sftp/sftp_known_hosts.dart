import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// What checking a server's host key against the trusted list produced.
enum KnownHostVerdict {
  /// The key matches what was trusted for this host before.
  trusted,

  /// This host has never been seen — the user has to decide.
  unknown,

  /// A key is on file for this host and it is a *different* one. Either the
  /// server was rebuilt or something is sitting in the middle; never connect
  /// silently.
  mismatch,
}

/// The host keys the user has agreed to trust, kept on this device only.
///
/// Without this, an SFTP client will happily hand a password to whatever
/// answers on port 22 — the fingerprint check is the only thing standing
/// between the user and a machine-in-the-middle. Modelled on OpenSSH's
/// `known_hosts`: first sight asks, a changed key refuses.
class SftpKnownHosts {
  SftpKnownHosts._();

  static final SftpKnownHosts instance = SftpKnownHosts._();

  static const _fileName = 'luma_sftp_known_hosts.json';

  Map<String, Map<String, String>>? _entries;
  File? _file;

  static String hostKeyOf(String host, int port) =>
      '${host.trim().toLowerCase()}:$port';

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}$_fileName');
    return _file!;
  }

  Future<Map<String, Map<String, String>>> _load() async {
    if (_entries != null) return _entries!;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _entries = raw.map(
          (key, value) => MapEntry(
            key,
            (value as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v.toString()),
            ),
          ),
        );
      }
    } catch (_) {
      _entries = {};
    }
    return _entries ??= {};
  }

  Future<void> _persist() async {
    final file = await _getFile();
    await file.writeAsString(jsonEncode(_entries ?? {}), flush: true);
  }

  /// Compares the key [type]/[fingerprint] the server presented against what
  /// is on file for [host]:[port].
  Future<KnownHostVerdict> check(
    String host,
    int port,
    String type,
    String fingerprint,
  ) async {
    final entries = await _load();
    final known = entries[hostKeyOf(host, port)];
    if (known == null) return KnownHostVerdict.unknown;
    if (known['fingerprint'] == fingerprint && known['type'] == type) {
      return KnownHostVerdict.trusted;
    }
    return KnownHostVerdict.mismatch;
  }

  /// The fingerprint currently trusted for [host]:[port], for the "the key
  /// changed" dialog to show alongside the new one.
  Future<String?> trustedFingerprint(String host, int port) async {
    final entries = await _load();
    return entries[hostKeyOf(host, port)]?['fingerprint'];
  }

  Future<void> trust(
    String host,
    int port,
    String type,
    String fingerprint,
  ) async {
    final entries = await _load();
    entries[hostKeyOf(host, port)] = {
      'type': type,
      'fingerprint': fingerprint,
      'trustedAt': DateTime.now().toIso8601String(),
    };
    await _persist();
  }

  Future<void> forget(String host, int port) async {
    final entries = await _load();
    entries.remove(hostKeyOf(host, port));
    await _persist();
  }
}
