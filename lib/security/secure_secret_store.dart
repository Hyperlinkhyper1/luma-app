import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// OS-protected credential storage. An unavailable keyring is an error;
/// callers must never fall back to writing plaintext secrets.
///
/// On Windows every secret lives in one DPAPI-protected file that the plugin
/// rewrites in place and deletes outright the moment a read sees it
/// half-written. Two luma processes starting together were enough to lose
/// every key at once, so this store only writes when a value actually
/// changes and keeps a DPAPI-protected copy of that file (same protection,
/// same folder) to restore from.
class SecureSecretStore {
  SecureSecretStore({FlutterSecureStorage? storage, Directory? storageDir})
    : _storage = storage ?? const FlutterSecureStorage(),
      _storageDir = storageDir;

  static final instance = SecureSecretStore();

  static const _windowsFileName = 'flutter_secure_storage.dat';

  final FlutterSecureStorage _storage;
  final Directory? _storageDir;
  final Map<String, Future<Uint8List>> _pendingKeys = {};
  Future<void>? _restored;

  /// Keys that were missing while data encrypted under them still existed.
  /// That data was moved aside and a fresh key created; see [loadKey].
  final Set<String> lostKeys = {};

  Future<File?> _windowsFile() async {
    if (!Platform.isWindows && _storageDir == null) return null;
    try {
      final dir = _storageDir ?? await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}$_windowsFileName');
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreIfMissing() => _restored ??= () async {
    final file = await _windowsFile();
    if (file == null) return;
    final backup = File('${file.path}.bak');
    if (!await file.exists() && await backup.exists()) {
      await backup.copy(file.path);
    }
  }();

  Future<void> _backUp() async {
    final file = await _windowsFile();
    if (file == null || !await file.exists()) return;
    final tmp = File('${file.path}.bak.tmp');
    await file.copy(tmp.path);
    await tmp.rename('${file.path}.bak');
  }

  Future<String?> read(String name) async {
    await _restoreIfMissing();
    try {
      return await _storage.read(key: 'luma.$name');
    } catch (_) {
      _restored = null;
      await _restoreIfMissing();
      return _storage.read(key: 'luma.$name');
    }
  }

  Future<void> write(String name, String value) async {
    if (await read(name) == value) return;
    await _storage.write(key: 'luma.$name', value: value);
    if (await read(name) != value) {
      throw StateError('Secure storage verification failed.');
    }
    await _backUp();
  }

  Future<void> delete(String name) async {
    await _restoreIfMissing();
    await _storage.delete(key: 'luma.$name');
    await _backUp();
  }

  /// Transfers the existing key unchanged, verifies storage, then removes
  /// the old file. Failure preserves the only recoverable legacy key.
  ///
  /// When no key exists but [encryptedData] does, that data can never be
  /// decrypted again. It is renamed to `<name>.lost-key-<timestamp>` rather
  /// than deleted, [name] is recorded in [lostKeys], and a fresh key is
  /// created so the app keeps starting.
  Future<Uint8List> loadKey(
    String name,
    File legacyFile, {
    required List<File> encryptedData,
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
          await _quarantine(name, encryptedData);
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

  Future<void> _quarantine(String name, List<File> files) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    var moved = false;
    for (final file in files) {
      if (!await file.exists()) continue;
      await file.rename('${file.path}.lost-key-$stamp');
      moved = true;
    }
    if (moved) {
      lostKeys.add(name);
      debugPrint('Encryption key "$name" was missing; its data was moved aside.');
    }
  }
}
