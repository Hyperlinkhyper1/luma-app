import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'private_directory.dart';

/// Normalized, transactional server account persistence. Values are always
/// bound parameters; table/column names come only from this implementation.
class AccountDatabase {
  AccountDatabase._(this.path);
  final String path;
  static const userColumns = [
    'id',
    'email',
    'authHash',
    'authSalt',
    'kdfSalt',
    'kdfIterations',
    'quotaBytes',
    'createdAtMs',
    'status',
    'verificationTokenHash',
    'verificationExpiresAtMs',
    'lastLoginAtMs',
    'planId',
    'passwordResetRequiredAtMs',
    'accessRevokedAtMs',
    'accessRevokedReason',
  ];
  static const sessionColumns = [
    'tokenHash',
    'userId',
    'createdAtMs',
    'expiresAtMs',
    'deviceLabel'
  ];

  static Future<AccountDatabase> open(String root) async {
    final directory = Directory('$root/accounts');
    await restrictAccountDirectory(directory);
    final result = AccountDatabase._('${directory.path}/accounts.sqlite');
    if (await FileSystemEntity.type(result.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw StateError('Account database must not be a link.');
    }
    result._use((db) {
      final version =
          db.select('PRAGMA user_version').single.values.single as int;
      if (version > 1)
        throw StateError('Account database requires a newer server.');
      db.execute('''
CREATE TABLE IF NOT EXISTS users (
 id TEXT PRIMARY KEY NOT NULL CHECK(length(id) BETWEEN 1 AND 128),
 email TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(length(email) BETWEEN 3 AND 254),
 authHash TEXT NOT NULL, authSalt TEXT NOT NULL, kdfSalt TEXT NOT NULL,
 kdfIterations INTEGER NOT NULL CHECK(kdfIterations BETWEEN 50000 AND 5000000),
 quotaBytes INTEGER NOT NULL CHECK(quotaBytes >= 0),
 createdAtMs INTEGER NOT NULL CHECK(createdAtMs >= 0),
 status TEXT NOT NULL CHECK(status IN ('active', 'pending')),
 verificationTokenHash TEXT, verificationExpiresAtMs INTEGER,
 lastLoginAtMs INTEGER, planId TEXT NOT NULL CHECK(planId IN ('core', 'orbit', 'nova')),
 passwordResetRequiredAtMs INTEGER, accessRevokedAtMs INTEGER,
 accessRevokedReason TEXT CHECK(length(accessRevokedReason) <= 2000)
);
CREATE TABLE IF NOT EXISTS oauth_identities (
 userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 provider TEXT NOT NULL CHECK(provider IN ('google', 'github')),
 subject TEXT NOT NULL CHECK(length(subject) BETWEEN 1 AND 512),
 PRIMARY KEY(userId, provider), UNIQUE(provider, subject)
);
CREATE TABLE IF NOT EXISTS user_recent_ips (
 userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 position INTEGER NOT NULL CHECK(position BETWEEN 0 AND 7),
 ip TEXT NOT NULL CHECK(length(ip) BETWEEN 1 AND 64), PRIMARY KEY(userId, position)
);
CREATE TABLE IF NOT EXISTS sessions (
 tokenHash TEXT PRIMARY KEY NOT NULL CHECK(length(tokenHash) = 64),
 userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 createdAtMs INTEGER NOT NULL CHECK(createdAtMs >= 0),
 expiresAtMs INTEGER NOT NULL CHECK(expiresAtMs >= createdAtMs),
 deviceLabel TEXT CHECK(length(deviceLabel) <= 60)
);
CREATE TABLE IF NOT EXISTS migration_state (source TEXT PRIMARY KEY, digest TEXT NOT NULL);
PRAGMA user_version = 1;
''');
    });
    return result;
  }

  T _use<T>(T Function(Database) action) {
    final db = sqlite3.open(path);
    try {
      db.execute(
          'PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000; PRAGMA synchronous = FULL; PRAGMA trusted_schema = OFF;');
      return action(db);
    } finally {
      db.dispose();
    }
  }

  T _transaction<T>(Database db, T Function() action) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  bool get migrated => _use((db) => db
      .select("SELECT 1 FROM migration_state WHERE source = 'complete'")
      .isNotEmpty);

  /// Commit and read back the complete replacement before removing any JSON.
  /// A crash after commit resumes cleanup using hashes captured at migration.
  Future<void> migrate(String root, List<Map<String, dynamic>> users,
      List<Map<String, dynamic>> sessions) async {
    final files = {
      for (final name in ['users.json', 'sessions.json'])
        name: File('$root/$name')
    };
    final digests = <String, String>{};
    for (final entry in files.entries) {
      if (await entry.value.exists())
        digests[entry.key] =
            sha256.convert(await entry.value.readAsBytes()).toString();
    }
    if (!migrated) {
      _use((db) => _transaction(db, () {
            _writeUsers(db, users);
            _writeSessions(db, sessions);
            if (jsonEncode(_readUsers(db)) != jsonEncode(_sortedUsers(users)) ||
                jsonEncode(_readSessions(db)) !=
                    jsonEncode(_sortedSessions(sessions))) {
              throw StateError(
                  'Account database migration verification failed.');
            }
            for (final entry in digests.entries) {
              db.execute('INSERT INTO migration_state VALUES (?, ?)',
                  [entry.key, entry.value]);
            }
            db.execute("INSERT INTO migration_state VALUES ('complete', '1')");
          }));
    }
    for (final entry in digests.entries) {
      final expected = _use((db) => db.select(
          'SELECT digest FROM migration_state WHERE source = ?', [entry.key]));
      if (expected.isEmpty ||
          expected.single['digest'] != entry.value ||
          sha256.convert(await files[entry.key]!.readAsBytes()).toString() !=
              entry.value) {
        throw StateError(
            'Legacy account files changed. Preserve them for manual reconciliation.');
      }
      await files[entry.key]!.delete();
    }
  }

  List<Map<String, dynamic>> readUsers() => _use(_readUsers);
  List<Map<String, dynamic>> readSessions() => _use(_readSessions);
  void saveUsers(List<Map<String, dynamic>> users) =>
      _use((db) => _transaction(db, () => _writeUsers(db, users)));
  void saveSessions(List<Map<String, dynamic>> sessions) =>
      _use((db) => _transaction(db, () => _writeSessions(db, sessions)));

  static List<Map<String, dynamic>> _readUsers(Database db) => [
        for (final row in db.select('SELECT * FROM users ORDER BY id'))
          {
            ...row,
            'oauthSubjects': {
              for (final identity in db.select(
                  'SELECT provider, subject FROM oauth_identities WHERE userId = ? ORDER BY provider',
                  [row['id']]))
                identity['provider'] as String: identity['subject']
            },
            'recentIps': [
              for (final ip in db.select(
                  'SELECT ip FROM user_recent_ips WHERE userId = ? ORDER BY position',
                  [row['id']]))
                ip['ip']
            ],
          }
      ];
  static List<Map<String, dynamic>> _readSessions(Database db) => [
        for (final row
            in db.select('SELECT * FROM sessions ORDER BY tokenHash'))
          Map<String, dynamic>.from(row)
      ];

  static List<Map<String, dynamic>> _sortedUsers(
      List<Map<String, dynamic>> users) {
    final result = [
      for (final u in users)
        {
          for (final c in userColumns) c: u[c],
          'oauthSubjects': {
            for (final key
                in (u['oauthSubjects'] as Map<String, String>).keys.toList()
                  ..sort())
              key: u['oauthSubjects'][key]
          },
          'recentIps': u['recentIps'],
        }
    ];
    result.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return result;
  }

  static List<Map<String, dynamic>> _sortedSessions(
      List<Map<String, dynamic>> sessions) {
    final result = [
      for (final s in sessions) {for (final c in sessionColumns) c: s[c]}
    ];
    result.sort((a, b) =>
        (a['tokenHash'] as String).compareTo(b['tokenHash'] as String));
    return result;
  }

  static void _writeUsers(Database db, List<Map<String, dynamic>> users) {
    db.execute('CREATE TEMP TABLE incoming_users (id TEXT PRIMARY KEY)');
    final insert = db.prepare(
        'INSERT INTO users (${userColumns.join(',')}) VALUES (${List.filled(userColumns.length, '?').join(',')}) ON CONFLICT(id) DO UPDATE SET ${userColumns.skip(1).map((c) => '$c=excluded.$c').join(',')}');
    try {
      for (final user in users) {
        _validateUser(user);
        db.execute('INSERT INTO incoming_users VALUES (?)', [user['id']]);
        insert.execute([for (final c in userColumns) user[c]]);
      }
      db.execute(
          'DELETE FROM users WHERE id NOT IN (SELECT id FROM incoming_users)');
      db.execute('DELETE FROM oauth_identities; DELETE FROM user_recent_ips;');
      for (final user in users) {
        for (final entry
            in (user['oauthSubjects'] as Map<String, String>).entries) {
          db.execute('INSERT INTO oauth_identities VALUES (?, ?, ?)',
              [user['id'], entry.key, entry.value]);
        }
        final ips = user['recentIps'] as List<String>;
        for (var i = 0; i < ips.length; i++) {
          db.execute('INSERT INTO user_recent_ips VALUES (?, ?, ?)',
              [user['id'], i, ips[i]]);
        }
      }
    } finally {
      insert.dispose();
    }
  }

  static void _writeSessions(Database db, List<Map<String, dynamic>> sessions) {
    db.execute('DELETE FROM sessions');
    for (final session in sessions) {
      if (session['tokenHash'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(session['tokenHash'] as String)) {
        throw const FormatException('Invalid session hash.');
      }
      db.execute(
          'INSERT INTO sessions (${sessionColumns.join(',')}) VALUES (?, ?, ?, ?, ?)',
          [for (final c in sessionColumns) session[c]]);
    }
  }

  static void _validateUser(Map<String, dynamic> user) {
    if (user['id'] is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(user['id'] as String)) {
      throw const FormatException('Invalid account identifier.');
    }
    for (final field in ['authHash', 'authSalt', 'kdfSalt']) {
      final value = user[field];
      if (value is! String || value.length > 128)
        throw const FormatException(
            'Invalid account cryptographic parameters.');
      final size = base64Decode(value).length;
      if (size < 16 || size > 64)
        throw const FormatException(
            'Invalid account cryptographic parameters.');
    }
  }
}
