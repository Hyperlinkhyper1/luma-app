import 'package:drift/drift.dart';

import '../../storage/storage_guard.dart';
import 'data/password_database.dart';
import 'password_crypto.dart';

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
      final id = await _db.into(_db.passwordEntries).insert(
            PasswordEntriesCompanion.insert(
              service: draft.service,
              email: draft.email,
              passwordCipher: '',
              username: Value(_clean(draft.username)),
              phone: Value(_clean(draft.phone)),
              info: Value(_clean(draft.info)),
              icon: Value(_clean(draft.icon)),
            ),
          );
      await (_db.update(_db.passwordEntries)..where((t) => t.id.equals(id)))
          .write(
        PasswordEntriesCompanion(
          passwordCipher: Value(
              _crypto.encrypt(draft.password, entryId: id, field: 'password')),
          totpSecretCipher: Value(_encryptTotp(draft.totpSecret, id)),
        ),
      );
    });
    StorageGuard.instance.scheduleRefresh();
  }

  Future<void> update(int id, PasswordDraft draft) {
    return (_db.update(_db.passwordEntries)..where((t) => t.id.equals(id)))
        .write(
      PasswordEntriesCompanion(
        service: Value(draft.service),
        email: Value(draft.email),
        passwordCipher: Value(
            _crypto.encrypt(draft.password, entryId: id, field: 'password')),
        username: Value(_clean(draft.username)),
        phone: Value(_clean(draft.phone)),
        info: Value(_clean(draft.info)),
        icon: Value(_clean(draft.icon)),
        totpSecretCipher: Value(_encryptTotp(draft.totpSecret, id)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.passwordEntries)..where((t) => t.id.equals(id)))
        .go();
  }

  PasswordRecord _toRecord(PasswordEntry row) {
    final password =
        _crypto.decrypt(row.passwordCipher, entryId: row.id, field: 'password');
    return PasswordRecord(
      id: row.id,
      service: row.service,
      email: row.email,
      password: password ?? '',
      decryptFailed: password == null,
      username: row.username,
      phone: row.phone,
      info: row.info,
      icon: row.icon,
      totpSecret: row.totpSecretCipher == null
          ? null
          : _crypto.decrypt(row.totpSecretCipher!, entryId: row.id, field: 'totp'),
      updatedAt: row.updatedAt,
    );
  }

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
    final rows = await _db.select(_db.passwordEntries).get();
    for (final row in rows) {
      final legacyPassword = _crypto.isLegacyFormat(row.passwordCipher);
      final legacyTotp = row.totpSecretCipher != null &&
          _crypto.isLegacyFormat(row.totpSecretCipher!);
      if (!legacyPassword && !legacyTotp) continue;

      final password = _crypto.decrypt(row.passwordCipher,
          entryId: row.id, field: 'password');
      if (password == null) continue;
      final totpPlain = row.totpSecretCipher == null
          ? null
          : _crypto.decrypt(row.totpSecretCipher!,
              entryId: row.id, field: 'totp');

      await (_db.update(_db.passwordEntries)..where((t) => t.id.equals(row.id)))
          .write(PasswordEntriesCompanion(
        passwordCipher: Value(
            _crypto.encrypt(password, entryId: row.id, field: 'password')),
        totpSecretCipher: Value(totpPlain == null
            ? null
            : _crypto.encrypt(totpPlain, entryId: row.id, field: 'totp')),
      ));
    }
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
