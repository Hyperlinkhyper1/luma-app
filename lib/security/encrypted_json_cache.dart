import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'authenticated_cipher.dart';
import 'secure_secret_store.dart';

/// Best-effort cache persistence with the same protection for final and
/// temporary files. Legacy plaintext caches are discarded and refreshed.
class EncryptedJsonCache {
  EncryptedJsonCache._(this._file, this._key, this._context, this.data);

  final File? _file;
  final Uint8List? _key;
  final String _context;
  final Map<String, dynamic> data;

  static Future<EncryptedJsonCache> load(
    String fileName,
    String keyName, {
    Directory? storageDir,
    SecureSecretStore? secretStore,
  }) async {
    File? file;
    Uint8List? key;
    Map<String, dynamic> data = const {};
    final context = 'luma.$keyName';
    try {
      final dir = storageDir ?? await getApplicationSupportDirectory();
      file = File('${dir.path}${Platform.pathSeparator}$fileName');
      final tmp = File('${file.path}.tmp');
      if (await tmp.exists()) await tmp.delete();

      List<int>? envelope;
      if (await file.exists()) {
        envelope = await file.readAsBytes();
        if (!_hasEncryptedHeader(envelope)) {
          await file.delete();
          envelope = null;
        }
      }
      key = await (secretStore ?? SecureSecretStore.instance).loadKey(
        keyName,
        encryptedData: envelope == null ? const [] : [file],
      );
      if (envelope != null) {
        final decoded = jsonDecode(
          utf8.decode(AuthenticatedCipher.open(envelope, key, context)),
        );
        if (decoded is Map<String, dynamic>) data = decoded;
      }
    } catch (_) {
      // A missing key or corrupt cache leaves the UI waiting for its refresh.
    }
    return EncryptedJsonCache._(file, key, context, data);
  }

  static bool _hasEncryptedHeader(List<int> bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0x4c &&
      bytes[1] == 0x41 &&
      bytes[2] == 0x01;

  Future<void> save(Map<String, dynamic> payload) async {
    final file = _file;
    final key = _key;
    if (file == null || key == null) return;
    try {
      final envelope = AuthenticatedCipher.seal(
        utf8.encode(jsonEncode(payload)),
        key,
        _context,
      );
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(envelope, flush: true);
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    } catch (_) {
      // Best effort — the cache just won't survive a restart.
    }
  }
}
