import 'package:drift/drift.dart';

import 'data/password_database.dart';
import 'password_crypto.dart';

/// A credential with its password already decrypted, ready for display.
class PasswordRecord {
  const PasswordRecord({
    required this.id,
    required this.service,
    required this.email,
    required this.password,
    this.username,
    this.phone,
    this.info,
    this.icon,
    required this.updatedAt,
  });

  final int id;
  final String service;
  final String email;
  final String password;
  final String? username;
  final String? phone;
  final String? info;
  final String? icon;
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
  });

  final String service;
  final String email;
  final String password;
  final String? username;
  final String? phone;
  final String? info;
  final String? icon;
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

  Future<void> add(PasswordDraft draft) {
    return _db.into(_db.passwordEntries).insert(
          PasswordEntriesCompanion.insert(
            service: draft.service,
            email: draft.email,
            passwordCipher: _crypto.encrypt(draft.password),
            username: Value(_clean(draft.username)),
            phone: Value(_clean(draft.phone)),
            info: Value(_clean(draft.info)),
            icon: Value(_clean(draft.icon)),
          ),
        );
  }

  Future<void> update(int id, PasswordDraft draft) {
    return (_db.update(_db.passwordEntries)..where((t) => t.id.equals(id)))
        .write(
      PasswordEntriesCompanion(
        service: Value(draft.service),
        email: Value(draft.email),
        passwordCipher: Value(_crypto.encrypt(draft.password)),
        username: Value(_clean(draft.username)),
        phone: Value(_clean(draft.phone)),
        info: Value(_clean(draft.info)),
        icon: Value(_clean(draft.icon)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.passwordEntries)..where((t) => t.id.equals(id)))
        .go();
  }

  PasswordRecord _toRecord(PasswordEntry row) => PasswordRecord(
        id: row.id,
        service: row.service,
        email: row.email,
        password: _crypto.decrypt(row.passwordCipher),
        username: row.username,
        phone: row.phone,
        info: row.info,
        icon: row.icon,
        updatedAt: row.updatedAt,
      );

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
