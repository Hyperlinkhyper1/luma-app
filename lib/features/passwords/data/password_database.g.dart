// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'password_database.dart';

// ignore_for_file: type=lint
class $PasswordEntriesTable extends PasswordEntries
    with TableInfo<$PasswordEntriesTable, PasswordEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PasswordEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _serviceMeta = const VerificationMeta(
    'service',
  );
  @override
  late final GeneratedColumn<String> service = GeneratedColumn<String>(
    'service',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passwordCipherMeta = const VerificationMeta(
    'passwordCipher',
  );
  @override
  late final GeneratedColumn<String> passwordCipher = GeneratedColumn<String>(
    'password_cipher',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _infoMeta = const VerificationMeta('info');
  @override
  late final GeneratedColumn<String> info = GeneratedColumn<String>(
    'info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totpSecretCipherMeta = const VerificationMeta(
    'totpSecretCipher',
  );
  @override
  late final GeneratedColumn<String> totpSecretCipher = GeneratedColumn<String>(
    'totp_secret_cipher',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    service,
    email,
    passwordCipher,
    username,
    phone,
    info,
    icon,
    totpSecretCipher,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'password_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PasswordEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('service')) {
      context.handle(
        _serviceMeta,
        service.isAcceptableOrUnknown(data['service']!, _serviceMeta),
      );
    } else if (isInserting) {
      context.missing(_serviceMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('password_cipher')) {
      context.handle(
        _passwordCipherMeta,
        passwordCipher.isAcceptableOrUnknown(
          data['password_cipher']!,
          _passwordCipherMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordCipherMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('info')) {
      context.handle(
        _infoMeta,
        info.isAcceptableOrUnknown(data['info']!, _infoMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('totp_secret_cipher')) {
      context.handle(
        _totpSecretCipherMeta,
        totpSecretCipher.isAcceptableOrUnknown(
          data['totp_secret_cipher']!,
          _totpSecretCipherMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PasswordEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PasswordEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      service: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      passwordCipher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_cipher'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      info: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}info'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      totpSecretCipher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}totp_secret_cipher'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PasswordEntriesTable createAlias(String alias) {
    return $PasswordEntriesTable(attachedDatabase, alias);
  }
}

class PasswordEntry extends DataClass implements Insertable<PasswordEntry> {
  final int id;

  /// What the credential is for (the service name).
  final String service;
  final String email;

  /// The password, encrypted. Never store the plaintext here.
  final String passwordCipher;
  final String? username;
  final String? phone;
  final String? info;
  final String? icon;

  /// Base32 TOTP/2FA secret, encrypted (same scheme as [passwordCipher]).
  /// Null when this entry has no 2FA code configured.
  final String? totpSecretCipher;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PasswordEntry({
    required this.id,
    required this.service,
    required this.email,
    required this.passwordCipher,
    this.username,
    this.phone,
    this.info,
    this.icon,
    this.totpSecretCipher,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['service'] = Variable<String>(service);
    map['email'] = Variable<String>(email);
    map['password_cipher'] = Variable<String>(passwordCipher);
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || info != null) {
      map['info'] = Variable<String>(info);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || totpSecretCipher != null) {
      map['totp_secret_cipher'] = Variable<String>(totpSecretCipher);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PasswordEntriesCompanion toCompanion(bool nullToAbsent) {
    return PasswordEntriesCompanion(
      id: Value(id),
      service: Value(service),
      email: Value(email),
      passwordCipher: Value(passwordCipher),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      info: info == null && nullToAbsent ? const Value.absent() : Value(info),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      totpSecretCipher: totpSecretCipher == null && nullToAbsent
          ? const Value.absent()
          : Value(totpSecretCipher),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PasswordEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PasswordEntry(
      id: serializer.fromJson<int>(json['id']),
      service: serializer.fromJson<String>(json['service']),
      email: serializer.fromJson<String>(json['email']),
      passwordCipher: serializer.fromJson<String>(json['passwordCipher']),
      username: serializer.fromJson<String?>(json['username']),
      phone: serializer.fromJson<String?>(json['phone']),
      info: serializer.fromJson<String?>(json['info']),
      icon: serializer.fromJson<String?>(json['icon']),
      totpSecretCipher: serializer.fromJson<String?>(json['totpSecretCipher']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'service': serializer.toJson<String>(service),
      'email': serializer.toJson<String>(email),
      'passwordCipher': serializer.toJson<String>(passwordCipher),
      'username': serializer.toJson<String?>(username),
      'phone': serializer.toJson<String?>(phone),
      'info': serializer.toJson<String?>(info),
      'icon': serializer.toJson<String?>(icon),
      'totpSecretCipher': serializer.toJson<String?>(totpSecretCipher),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PasswordEntry copyWith({
    int? id,
    String? service,
    String? email,
    String? passwordCipher,
    Value<String?> username = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> info = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    Value<String?> totpSecretCipher = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PasswordEntry(
    id: id ?? this.id,
    service: service ?? this.service,
    email: email ?? this.email,
    passwordCipher: passwordCipher ?? this.passwordCipher,
    username: username.present ? username.value : this.username,
    phone: phone.present ? phone.value : this.phone,
    info: info.present ? info.value : this.info,
    icon: icon.present ? icon.value : this.icon,
    totpSecretCipher: totpSecretCipher.present
        ? totpSecretCipher.value
        : this.totpSecretCipher,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PasswordEntry copyWithCompanion(PasswordEntriesCompanion data) {
    return PasswordEntry(
      id: data.id.present ? data.id.value : this.id,
      service: data.service.present ? data.service.value : this.service,
      email: data.email.present ? data.email.value : this.email,
      passwordCipher: data.passwordCipher.present
          ? data.passwordCipher.value
          : this.passwordCipher,
      username: data.username.present ? data.username.value : this.username,
      phone: data.phone.present ? data.phone.value : this.phone,
      info: data.info.present ? data.info.value : this.info,
      icon: data.icon.present ? data.icon.value : this.icon,
      totpSecretCipher: data.totpSecretCipher.present
          ? data.totpSecretCipher.value
          : this.totpSecretCipher,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PasswordEntry(')
          ..write('id: $id, ')
          ..write('service: $service, ')
          ..write('email: $email, ')
          ..write('passwordCipher: $passwordCipher, ')
          ..write('username: $username, ')
          ..write('phone: $phone, ')
          ..write('info: $info, ')
          ..write('icon: $icon, ')
          ..write('totpSecretCipher: $totpSecretCipher, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    service,
    email,
    passwordCipher,
    username,
    phone,
    info,
    icon,
    totpSecretCipher,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PasswordEntry &&
          other.id == this.id &&
          other.service == this.service &&
          other.email == this.email &&
          other.passwordCipher == this.passwordCipher &&
          other.username == this.username &&
          other.phone == this.phone &&
          other.info == this.info &&
          other.icon == this.icon &&
          other.totpSecretCipher == this.totpSecretCipher &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PasswordEntriesCompanion extends UpdateCompanion<PasswordEntry> {
  final Value<int> id;
  final Value<String> service;
  final Value<String> email;
  final Value<String> passwordCipher;
  final Value<String?> username;
  final Value<String?> phone;
  final Value<String?> info;
  final Value<String?> icon;
  final Value<String?> totpSecretCipher;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const PasswordEntriesCompanion({
    this.id = const Value.absent(),
    this.service = const Value.absent(),
    this.email = const Value.absent(),
    this.passwordCipher = const Value.absent(),
    this.username = const Value.absent(),
    this.phone = const Value.absent(),
    this.info = const Value.absent(),
    this.icon = const Value.absent(),
    this.totpSecretCipher = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PasswordEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String service,
    required String email,
    required String passwordCipher,
    this.username = const Value.absent(),
    this.phone = const Value.absent(),
    this.info = const Value.absent(),
    this.icon = const Value.absent(),
    this.totpSecretCipher = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : service = Value(service),
       email = Value(email),
       passwordCipher = Value(passwordCipher);
  static Insertable<PasswordEntry> custom({
    Expression<int>? id,
    Expression<String>? service,
    Expression<String>? email,
    Expression<String>? passwordCipher,
    Expression<String>? username,
    Expression<String>? phone,
    Expression<String>? info,
    Expression<String>? icon,
    Expression<String>? totpSecretCipher,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (service != null) 'service': service,
      if (email != null) 'email': email,
      if (passwordCipher != null) 'password_cipher': passwordCipher,
      if (username != null) 'username': username,
      if (phone != null) 'phone': phone,
      if (info != null) 'info': info,
      if (icon != null) 'icon': icon,
      if (totpSecretCipher != null) 'totp_secret_cipher': totpSecretCipher,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PasswordEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? service,
    Value<String>? email,
    Value<String>? passwordCipher,
    Value<String?>? username,
    Value<String?>? phone,
    Value<String?>? info,
    Value<String?>? icon,
    Value<String?>? totpSecretCipher,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return PasswordEntriesCompanion(
      id: id ?? this.id,
      service: service ?? this.service,
      email: email ?? this.email,
      passwordCipher: passwordCipher ?? this.passwordCipher,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      info: info ?? this.info,
      icon: icon ?? this.icon,
      totpSecretCipher: totpSecretCipher ?? this.totpSecretCipher,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (service.present) {
      map['service'] = Variable<String>(service.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (passwordCipher.present) {
      map['password_cipher'] = Variable<String>(passwordCipher.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (info.present) {
      map['info'] = Variable<String>(info.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (totpSecretCipher.present) {
      map['totp_secret_cipher'] = Variable<String>(totpSecretCipher.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PasswordEntriesCompanion(')
          ..write('id: $id, ')
          ..write('service: $service, ')
          ..write('email: $email, ')
          ..write('passwordCipher: $passwordCipher, ')
          ..write('username: $username, ')
          ..write('phone: $phone, ')
          ..write('info: $info, ')
          ..write('icon: $icon, ')
          ..write('totpSecretCipher: $totpSecretCipher, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$PasswordDatabase extends GeneratedDatabase {
  _$PasswordDatabase(QueryExecutor e) : super(e);
  $PasswordDatabaseManager get managers => $PasswordDatabaseManager(this);
  late final $PasswordEntriesTable passwordEntries = $PasswordEntriesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [passwordEntries];
}

typedef $$PasswordEntriesTableCreateCompanionBuilder =
    PasswordEntriesCompanion Function({
      Value<int> id,
      required String service,
      required String email,
      required String passwordCipher,
      Value<String?> username,
      Value<String?> phone,
      Value<String?> info,
      Value<String?> icon,
      Value<String?> totpSecretCipher,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$PasswordEntriesTableUpdateCompanionBuilder =
    PasswordEntriesCompanion Function({
      Value<int> id,
      Value<String> service,
      Value<String> email,
      Value<String> passwordCipher,
      Value<String?> username,
      Value<String?> phone,
      Value<String?> info,
      Value<String?> icon,
      Value<String?> totpSecretCipher,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$PasswordEntriesTableFilterComposer
    extends Composer<_$PasswordDatabase, $PasswordEntriesTable> {
  $$PasswordEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get service => $composableBuilder(
    column: $table.service,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordCipher => $composableBuilder(
    column: $table.passwordCipher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get info => $composableBuilder(
    column: $table.info,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get totpSecretCipher => $composableBuilder(
    column: $table.totpSecretCipher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PasswordEntriesTableOrderingComposer
    extends Composer<_$PasswordDatabase, $PasswordEntriesTable> {
  $$PasswordEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get service => $composableBuilder(
    column: $table.service,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordCipher => $composableBuilder(
    column: $table.passwordCipher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get info => $composableBuilder(
    column: $table.info,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get totpSecretCipher => $composableBuilder(
    column: $table.totpSecretCipher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PasswordEntriesTableAnnotationComposer
    extends Composer<_$PasswordDatabase, $PasswordEntriesTable> {
  $$PasswordEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get service =>
      $composableBuilder(column: $table.service, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get passwordCipher => $composableBuilder(
    column: $table.passwordCipher,
    builder: (column) => column,
  );

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get info =>
      $composableBuilder(column: $table.info, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get totpSecretCipher => $composableBuilder(
    column: $table.totpSecretCipher,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PasswordEntriesTableTableManager
    extends
        RootTableManager<
          _$PasswordDatabase,
          $PasswordEntriesTable,
          PasswordEntry,
          $$PasswordEntriesTableFilterComposer,
          $$PasswordEntriesTableOrderingComposer,
          $$PasswordEntriesTableAnnotationComposer,
          $$PasswordEntriesTableCreateCompanionBuilder,
          $$PasswordEntriesTableUpdateCompanionBuilder,
          (
            PasswordEntry,
            BaseReferences<
              _$PasswordDatabase,
              $PasswordEntriesTable,
              PasswordEntry
            >,
          ),
          PasswordEntry,
          PrefetchHooks Function()
        > {
  $$PasswordEntriesTableTableManager(
    _$PasswordDatabase db,
    $PasswordEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PasswordEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PasswordEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PasswordEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> service = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> passwordCipher = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> info = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> totpSecretCipher = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PasswordEntriesCompanion(
                id: id,
                service: service,
                email: email,
                passwordCipher: passwordCipher,
                username: username,
                phone: phone,
                info: info,
                icon: icon,
                totpSecretCipher: totpSecretCipher,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String service,
                required String email,
                required String passwordCipher,
                Value<String?> username = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> info = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> totpSecretCipher = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PasswordEntriesCompanion.insert(
                id: id,
                service: service,
                email: email,
                passwordCipher: passwordCipher,
                username: username,
                phone: phone,
                info: info,
                icon: icon,
                totpSecretCipher: totpSecretCipher,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PasswordEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$PasswordDatabase,
      $PasswordEntriesTable,
      PasswordEntry,
      $$PasswordEntriesTableFilterComposer,
      $$PasswordEntriesTableOrderingComposer,
      $$PasswordEntriesTableAnnotationComposer,
      $$PasswordEntriesTableCreateCompanionBuilder,
      $$PasswordEntriesTableUpdateCompanionBuilder,
      (
        PasswordEntry,
        BaseReferences<
          _$PasswordDatabase,
          $PasswordEntriesTable,
          PasswordEntry
        >,
      ),
      PasswordEntry,
      PrefetchHooks Function()
    >;

class $PasswordDatabaseManager {
  final _$PasswordDatabase _db;
  $PasswordDatabaseManager(this._db);
  $$PasswordEntriesTableTableManager get passwordEntries =>
      $$PasswordEntriesTableTableManager(_db, _db.passwordEntries);
}
