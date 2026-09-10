import 'package:drift/drift.dart';

import '../../storage/storage_guard.dart';
import 'data/password_database.dart';
import 'password_crypto.dart';
import 'password_metadata.dart';

/// A credential with its password already decrypted, ready for display.
class PasswordRecord {
  const PasswordRecord({
    required this.id,
    required this.service,
    required this.email,
    required this.password,
    this.decryptFailed = false,
    this.username,
    this.phone,
    this.info,
    this.icon,
    this.totpSecret,
    required this.updatedAt,
  });

  final int id;
  final String service;
  final String email;
  final String password;

  /// True when [password] could not be decrypted (corrupt data or a
  /// missing/replaced key file) — the UI must show an error state instead of
  /// presenting the empty string as if it were the real password.
  final bool decryptFailed;
  final String? username;
  final String? phone;
  final String? info;
  final String? icon;

  /// Decrypted base32 TOTP secret, or null if this entry has no 2FA code.
  final String? totpSecret;
  final DateTime updatedAt;
}

/// The values captured by the add/edit form.
class PasswordDraft {
  const PasswordDraft({
    required this.service,
    required this.email,
    required this.password,
    this.username,
    this.phone,
    this.info,
    this.icon,
    this.totpSecret,
  });

  final String service;
  final String email;
  final String password;
  final String? username;
  final String? phone;
  final String? info;
  final String? icon;
  final String? totpSecret;
}

/// CRUD over the encrypted password vault. Decrypts on read and encrypts on
/// write so callers only ever deal with plaintext.
class PasswordRepository {
  PasswordRepository(this._db, this._crypto);

  final PasswordDatabase _db;
  final PasswordCrypto _crypto;

  /// Streams all entries (newest-updated first), decrypted.
  Stream<List<PasswordRecord>> watchAll() {
    final query = _db.select(_db.passwordEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map(
      (rows) => rows.map(_toRecord).toList(growable: false),
    );
  }

  /// Inserts the row first (so the ciphertext's MAC can be bound to the
  /// generated row id — see [PasswordCrypto.encrypt]), then immediately fills
  /// in the real ciphertexts. Both writes happen in one transaction so
  /// watchers never observe the empty placeholder row.
  Future<void> add(PasswordDraft draft) async {
    StorageGuard.instance.ensureWithinLimit();
    await _db.transaction(() async {
      final id = await _db
          .into(_db.passwordEntries)
          .insert(
            PasswordEntriesCompanion.insert(
              service: PasswordMetadata.placeholder,
              email: PasswordMetadata.placeholder,
              passwordCipher: '',
            ),
          );
      await (_db.update(
        _db.passwordEntries,
      )..where((t) => t.id.equals(id))).write(
        PasswordEntriesCompanion(
          passwordCipher: Value(
            _crypto.encrypt(draft.password, entryId: id, field: 'password'),
          ),
          totpSecretCipher: Value(_encryptTotp(draft.totpSecret, id)),
          info: Value(_sealDraft(draft, id)),
        ),
      );
    });
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> update(int id, PasswordDraft draft) {
    return (_db.update(
      _db.passwordEntries,
    )..where((t) => t.id.equals(id))).write(
      PasswordEntriesCompanion(
        service: const Value(PasswordMetadata.placeholder),
        email: const Value(PasswordMetadata.placeholder),
        passwordCipher: Value(
          _crypto.encrypt(draft.password, entryId: id, field: 'password'),
        ),
        username: const Value(null),
        phone: const Value(null),
        info: Value(_sealDraft(draft, id)),
        icon: const Value(null),
        totpSecretCipher: Value(_encryptTotp(draft.totpSecret, id)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(
      _db.passwordEntries,
    )..where((t) => t.id.equals(id))).go();
  }

  PasswordRecord _toRecord(PasswordEntry row) {
    final password = _crypto.decrypt(
      row.passwordCipher,
      entryId: row.id,
      field: 'password',
    );
    final totp = row.totpSecretCipher == null
        ? null
        : _crypto.decrypt(
            row.totpSecretCipher!,
            entryId: row.id,
            field: 'totp',
          );
    Map<String, Object?> metadata;
    var metadataFailed = false;
    try {
      metadata = PasswordMetadata.open(_rowMetadata(row), _crypto, row.id);
    } catch (_) {
      metadataFailed = true;
      metadata = {'service': 'Unreadable credential', 'email': ''};
    }
    return PasswordRecord(
      id: row.id,
      service: metadata['service'] as String,
      email: metadata['email'] as String,
      password: password ?? '',
      decryptFailed:
          metadataFailed ||
          password == null ||
          (row.totpSecretCipher != null && totp == null),
      username: metadata['username'] as String?,
      phone: metadata['phone'] as String?,
      info: metadata['info'] as String?,
      icon: metadata['icon'] as String?,
      totpSecret: totp,
      updatedAt: row.updatedAt,
    );
  }

  Map<String, Object?> _rowMetadata(PasswordEntry row) => {
    'service': row.service,
    'email': row.email,
    'username': row.username,
    'phone': row.phone,
    'info': row.info,
    'icon': row.icon,
    'password_cipher': row.passwordCipher,
  };

  String _sealDraft(PasswordDraft draft, int id) =>
      PasswordMetadata.seal(
            {
              'service': draft.service,
              'email': draft.email,
              'username': _clean(draft.username),
              'phone': _clean(draft.phone),
              'info': _clean(draft.info),
              'icon': _clean(draft.icon),
            },
            _crypto,
            id,
          )['info']
          as String;

  String? _encryptTotp(String? secret, int entryId) {
    final cleaned = _clean(secret)?.replaceAll(RegExp(r'\s'), '');
    return cleaned == null
        ? null
        : _crypto.encrypt(cleaned, entryId: entryId, field: 'totp');
  }

  /// One-time upgrade for vaults created before ciphertexts were bound to
  /// their row id/field (see [PasswordCrypto]): re-encrypts any entry still
  /// in the legacy format with the same plaintext, now MAC-bound to its row.
  /// Idempotent — already-migrated entries are skipped — so it's safe to call
  /// on every app startup. Entries that fail to decrypt (corrupt data, wrong
  /// key) are left untouched; the UI already flags those via [decryptFailed].
  Future<void> migrateLegacyCiphertexts() async {
    await _db.transaction(() async {
      final rows = await _db.select(_db.passwordEntries).get();
      for (final row in rows) {
        final legacyPassword = _crypto.isLegacyFormat(row.passwordCipher);
        final legacyTotp =
            row.totpSecretCipher != null &&
            _crypto.isLegacyFormat(row.totpSecretCipher!);
        final legacyMetadata = !PasswordMetadata.isEncrypted(_rowMetadata(row));
        if (!legacyPassword && !legacyTotp && !legacyMetadata) continue;

        final password = _crypto.decrypt(
          row.passwordCipher,
          entryId: row.id,
          field: 'password',
        );
        if (password == null) continue;
        final totpPlain = row.totpSecretCipher == null
            ? null
            : _crypto.decrypt(
                row.totpSecretCipher!,
                entryId: row.id,
                field: 'totp',
              );
        if (row.totpSecretCipher != null && totpPlain == null) continue;

        Map<String, Object?> metadata;
        try {
          metadata = PasswordMetadata.open(_rowMetadata(row), _crypto, row.id);
        } catch (_) {
          continue;
        }
        final nextMetadata = PasswordMetadata.seal(metadata, _crypto, row.id);

        final nextPassword = _crypto.encrypt(
          password,
          entryId: row.id,
          field: 'password',
        );
        final nextTotp = totpPlain == null
            ? null
            : _crypto.encrypt(totpPlain, entryId: row.id, field: 'totp');
        if (_crypto.decrypt(nextPassword, entryId: row.id, field: 'password') !=
                password ||
            (nextTotp != null &&
                _crypto.decrypt(nextTotp, entryId: row.id, field: 'totp') !=
                    totpPlain)) {
          throw StateError('Vault migration verification failed.');
        }

        await (_db.update(
          _db.passwordEntries,
        )..where((t) => t.id.equals(row.id))).write(
          PasswordEntriesCompanion(
            passwordCipher: Value(nextPassword),
            totpSecretCipher: Value(nextTotp),
            service: const Value(PasswordMetadata.placeholder),
            email: const Value(PasswordMetadata.placeholder),
            username: const Value(null),
            phone: const Value(null),
            icon: const Value(null),
            info: Value(nextMetadata['info'] as String),
          ),
        );
      }
    });
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
