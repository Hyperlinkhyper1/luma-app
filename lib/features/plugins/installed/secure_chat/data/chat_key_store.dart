import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

/// Persists this device's long-term X25519 chat identity keypair. The
/// private key is generated once on-device and NEVER leaves it — only the
/// public key is ever sent to the server (see chat_repository.dart). If the
/// user installs the plugin on a second device, that device gets its own
/// identity and its own copy of past messages re-derived from the server's
/// per-recipient blob (see ChatMessage.blobForSender/blobForRecipient on the
/// server) is not retroactively readable there — this mirrors how most
/// simple E2EE chat implementations (without a separate key-backup scheme)
/// behave: a new device starts a fresh identity and sees new messages only.
class ChatKeyStore {
  ChatKeyStore._(this._file);

  static const _fileName = 'luma_chat_identity.json';

  final File? _file;

  static Future<ChatKeyStore> load() async {
    File? file;
    try {
      final dir = await getApplicationSupportDirectory();
      file = File('${dir.path}${Platform.pathSeparator}$_fileName');
    } catch (_) {
      file = null;
    }
    return ChatKeyStore._(file);
  }

  /// Loads the existing identity keypair, or null if none has been created
  /// on this device yet.
  Future<SimpleKeyPair?> loadIdentity() async {
    final file = _file;
    if (file == null || !await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final privateBytes = base64Decode(decoded['privateKey'] as String);
      final publicBytes = base64Decode(decoded['publicKey'] as String);
      return SimpleKeyPairData(
        privateBytes,
        publicKey: SimplePublicKey(publicBytes, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveIdentity(SimpleKeyPair keyPair) async {
    final file = _file;
    if (file == null) return;
    final data = await keyPair.extract();
    final public = await keyPair.extractPublicKey();
    final payload = jsonEncode({
      'privateKey': base64Encode(data.bytes),
      'publicKey': base64Encode(public.bytes),
    });
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(payload, flush: true);
    if (await file.exists()) await file.delete();
    await tmp.rename(file.path);
  }
}
