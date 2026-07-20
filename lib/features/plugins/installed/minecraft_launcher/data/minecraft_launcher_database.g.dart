// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'minecraft_launcher_database.dart';

// ignore_for_file: type=lint
class $McAccountsTable extends McAccounts
    with TableInfo<$McAccountsTable, McAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $McAccountsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accessTokenMeta = const VerificationMeta(
    'accessToken',
  );
  @override
  late final GeneratedColumn<String> accessToken = GeneratedColumn<String>(
    'access_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refreshTokenMeta = const VerificationMeta(
    'refreshToken',
  );
  @override
  late final GeneratedColumn<String> refreshToken = GeneratedColumn<String>(
    'refresh_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accessTokenExpiresAtMeta =
      const VerificationMeta('accessTokenExpiresAt');
  @override
  late final GeneratedColumn<DateTime> accessTokenExpiresAt =
      GeneratedColumn<DateTime>(
        'access_token_expires_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    username,
    uuid,
    accessToken,
    refreshToken,
    accessTokenExpiresAt,
    avatarUrl,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mc_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<McAccount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('access_token')) {
      context.handle(
        _accessTokenMeta,
        accessToken.isAcceptableOrUnknown(
          data['access_token']!,
          _accessTokenMeta,
        ),
      );
    }
    if (data.containsKey('refresh_token')) {
      context.handle(
        _refreshTokenMeta,
        refreshToken.isAcceptableOrUnknown(
          data['refresh_token']!,
          _refreshTokenMeta,
        ),
      );
    }
    if (data.containsKey('access_token_expires_at')) {
      context.handle(
        _accessTokenExpiresAtMeta,
        accessTokenExpiresAt.isAcceptableOrUnknown(
          data['access_token_expires_at']!,
          _accessTokenExpiresAtMeta,
        ),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  McAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return McAccount(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      accessToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}access_token'],
      ),
      refreshToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}refresh_token'],
      ),
      accessTokenExpiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}access_token_expires_at'],
      ),
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $McAccountsTable createAlias(String alias) {
    return $McAccountsTable(attachedDatabase, alias);
  }
}

class McAccount extends DataClass implements Insertable<McAccount> {
  final int id;
  final String type;
  final String username;
  final String uuid;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? accessTokenExpiresAt;
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;
  const McAccount({
    required this.id,
    required this.type,
    required this.username,
    required this.uuid,
    this.accessToken,
    this.refreshToken,
    this.accessTokenExpiresAt,
    this.avatarUrl,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    map['username'] = Variable<String>(username);
    map['uuid'] = Variable<String>(uuid);
    if (!nullToAbsent || accessToken != null) {
      map['access_token'] = Variable<String>(accessToken);
    }
    if (!nullToAbsent || refreshToken != null) {
      map['refresh_token'] = Variable<String>(refreshToken);
    }
    if (!nullToAbsent || accessTokenExpiresAt != null) {
      map['access_token_expires_at'] = Variable<DateTime>(accessTokenExpiresAt);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  McAccountsCompanion toCompanion(bool nullToAbsent) {
    return McAccountsCompanion(
      id: Value(id),
      type: Value(type),
      username: Value(username),
      uuid: Value(uuid),
      accessToken: accessToken == null && nullToAbsent
          ? const Value.absent()
          : Value(accessToken),
      refreshToken: refreshToken == null && nullToAbsent
          ? const Value.absent()
          : Value(refreshToken),
      accessTokenExpiresAt: accessTokenExpiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(accessTokenExpiresAt),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory McAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return McAccount(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      username: serializer.fromJson<String>(json['username']),
      uuid: serializer.fromJson<String>(json['uuid']),
      accessToken: serializer.fromJson<String?>(json['accessToken']),
      refreshToken: serializer.fromJson<String?>(json['refreshToken']),
      accessTokenExpiresAt: serializer.fromJson<DateTime?>(
        json['accessTokenExpiresAt'],
      ),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'username': serializer.toJson<String>(username),
      'uuid': serializer.toJson<String>(uuid),
      'accessToken': serializer.toJson<String?>(accessToken),
      'refreshToken': serializer.toJson<String?>(refreshToken),
      'accessTokenExpiresAt': serializer.toJson<DateTime?>(
        accessTokenExpiresAt,
      ),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  McAccount copyWith({
    int? id,
    String? type,
    String? username,
    String? uuid,
    Value<String?> accessToken = const Value.absent(),
    Value<String?> refreshToken = const Value.absent(),
    Value<DateTime?> accessTokenExpiresAt = const Value.absent(),
    Value<String?> avatarUrl = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
  }) => McAccount(
    id: id ?? this.id,
    type: type ?? this.type,
    username: username ?? this.username,
    uuid: uuid ?? this.uuid,
    accessToken: accessToken.present ? accessToken.value : this.accessToken,
    refreshToken: refreshToken.present ? refreshToken.value : this.refreshToken,
    accessTokenExpiresAt: accessTokenExpiresAt.present
        ? accessTokenExpiresAt.value
        : this.accessTokenExpiresAt,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  McAccount copyWithCompanion(McAccountsCompanion data) {
    return McAccount(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      username: data.username.present ? data.username.value : this.username,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      accessToken: data.accessToken.present
          ? data.accessToken.value
          : this.accessToken,
      refreshToken: data.refreshToken.present
          ? data.refreshToken.value
          : this.refreshToken,
      accessTokenExpiresAt: data.accessTokenExpiresAt.present
          ? data.accessTokenExpiresAt.value
          : this.accessTokenExpiresAt,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('McAccount(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('username: $username, ')
          ..write('uuid: $uuid, ')
          ..write('accessToken: $accessToken, ')
          ..write('refreshToken: $refreshToken, ')
          ..write('accessTokenExpiresAt: $accessTokenExpiresAt, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    username,
    uuid,
    accessToken,
    refreshToken,
    accessTokenExpiresAt,
    avatarUrl,
    isActive,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McAccount &&
          other.id == this.id &&
          other.type == this.type &&
          other.username == this.username &&
          other.uuid == this.uuid &&
          other.accessToken == this.accessToken &&
          other.refreshToken == this.refreshToken &&
          other.accessTokenExpiresAt == this.accessTokenExpiresAt &&
          other.avatarUrl == this.avatarUrl &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class McAccountsCompanion extends UpdateCompanion<McAccount> {
  final Value<int> id;
  final Value<String> type;
  final Value<String> username;
  final Value<String> uuid;
  final Value<String?> accessToken;
  final Value<String?> refreshToken;
  final Value<DateTime?> accessTokenExpiresAt;
  final Value<String?> avatarUrl;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  const McAccountsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.username = const Value.absent(),
    this.uuid = const Value.absent(),
    this.accessToken = const Value.absent(),
    this.refreshToken = const Value.absent(),
    this.accessTokenExpiresAt = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  McAccountsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    required String username,
    required String uuid,
    this.accessToken = const Value.absent(),
    this.refreshToken = const Value.absent(),
    this.accessTokenExpiresAt = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : type = Value(type),
       username = Value(username),
       uuid = Value(uuid);
  static Insertable<McAccount> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? username,
    Expression<String>? uuid,
    Expression<String>? accessToken,
    Expression<String>? refreshToken,
    Expression<DateTime>? accessTokenExpiresAt,
    Expression<String>? avatarUrl,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (username != null) 'username': username,
      if (uuid != null) 'uuid': uuid,
      if (accessToken != null) 'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (accessTokenExpiresAt != null)
        'access_token_expires_at': accessTokenExpiresAt,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  McAccountsCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<String>? username,
    Value<String>? uuid,
    Value<String?>? accessToken,
    Value<String?>? refreshToken,
    Value<DateTime?>? accessTokenExpiresAt,
    Value<String?>? avatarUrl,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
  }) {
    return McAccountsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      username: username ?? this.username,
      uuid: uuid ?? this.uuid,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (accessToken.present) {
      map['access_token'] = Variable<String>(accessToken.value);
    }
    if (refreshToken.present) {
      map['refresh_token'] = Variable<String>(refreshToken.value);
    }
    if (accessTokenExpiresAt.present) {
      map['access_token_expires_at'] = Variable<DateTime>(
        accessTokenExpiresAt.value,
      );
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('McAccountsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('username: $username, ')
          ..write('uuid: $uuid, ')
          ..write('accessToken: $accessToken, ')
          ..write('refreshToken: $refreshToken, ')
          ..write('accessTokenExpiresAt: $accessTokenExpiresAt, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $McInstancesTable extends McInstances
    with TableInfo<$McInstancesTable, McInstance> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $McInstancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
    'version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loaderMeta = const VerificationMeta('loader');
  @override
  late final GeneratedColumn<String> loader = GeneratedColumn<String>(
    'loader',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('vanilla'),
  );
  static const VerificationMeta _loaderVersionMeta = const VerificationMeta(
    'loaderVersion',
  );
  @override
  late final GeneratedColumn<String> loaderVersion = GeneratedColumn<String>(
    'loader_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconPathMeta = const VerificationMeta(
    'iconPath',
  );
  @override
  late final GeneratedColumn<String> iconPath = GeneratedColumn<String>(
    'icon_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minMemoryMbMeta = const VerificationMeta(
    'minMemoryMb',
  );
  @override
  late final GeneratedColumn<int> minMemoryMb = GeneratedColumn<int>(
    'min_memory_mb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1024),
  );
  static const VerificationMeta _maxMemoryMbMeta = const VerificationMeta(
    'maxMemoryMb',
  );
  @override
  late final GeneratedColumn<int> maxMemoryMb = GeneratedColumn<int>(
    'max_memory_mb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4096),
  );
  static const VerificationMeta _jvmArgsMeta = const VerificationMeta(
    'jvmArgs',
  );
  @override
  late final GeneratedColumn<String> jvmArgs = GeneratedColumn<String>(
    'jvm_args',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _javaPathMeta = const VerificationMeta(
    'javaPath',
  );
  @override
  late final GeneratedColumn<String> javaPath = GeneratedColumn<String>(
    'java_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolutionWidthMeta = const VerificationMeta(
    'resolutionWidth',
  );
  @override
  late final GeneratedColumn<int> resolutionWidth = GeneratedColumn<int>(
    'resolution_width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(854),
  );
  static const VerificationMeta _resolutionHeightMeta = const VerificationMeta(
    'resolutionHeight',
  );
  @override
  late final GeneratedColumn<int> resolutionHeight = GeneratedColumn<int>(
    'resolution_height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(480),
  );
  static const VerificationMeta _fullscreenMeta = const VerificationMeta(
    'fullscreen',
  );
  @override
  late final GeneratedColumn<bool> fullscreen = GeneratedColumn<bool>(
    'fullscreen',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fullscreen" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalPlayTimeSecondsMeta =
      const VerificationMeta('totalPlayTimeSeconds');
  @override
  late final GeneratedColumn<int> totalPlayTimeSeconds = GeneratedColumn<int>(
    'total_play_time_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    versionId,
    loader,
    loaderVersion,
    iconPath,
    minMemoryMb,
    maxMemoryMb,
    jvmArgs,
    javaPath,
    resolutionWidth,
    resolutionHeight,
    fullscreen,
    createdAt,
    lastPlayedAt,
    totalPlayTimeSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mc_instances';
  @override
  VerificationContext validateIntegrity(
    Insertable<McInstance> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('loader')) {
      context.handle(
        _loaderMeta,
        loader.isAcceptableOrUnknown(data['loader']!, _loaderMeta),
      );
    }
    if (data.containsKey('loader_version')) {
      context.handle(
        _loaderVersionMeta,
        loaderVersion.isAcceptableOrUnknown(
          data['loader_version']!,
          _loaderVersionMeta,
        ),
      );
    }
    if (data.containsKey('icon_path')) {
      context.handle(
        _iconPathMeta,
        iconPath.isAcceptableOrUnknown(data['icon_path']!, _iconPathMeta),
      );
    }
    if (data.containsKey('min_memory_mb')) {
      context.handle(
        _minMemoryMbMeta,
        minMemoryMb.isAcceptableOrUnknown(
          data['min_memory_mb']!,
          _minMemoryMbMeta,
        ),
      );
    }
    if (data.containsKey('max_memory_mb')) {
      context.handle(
        _maxMemoryMbMeta,
        maxMemoryMb.isAcceptableOrUnknown(
          data['max_memory_mb']!,
          _maxMemoryMbMeta,
        ),
      );
    }
    if (data.containsKey('jvm_args')) {
      context.handle(
        _jvmArgsMeta,
        jvmArgs.isAcceptableOrUnknown(data['jvm_args']!, _jvmArgsMeta),
      );
    }
    if (data.containsKey('java_path')) {
      context.handle(
        _javaPathMeta,
        javaPath.isAcceptableOrUnknown(data['java_path']!, _javaPathMeta),
      );
    }
    if (data.containsKey('resolution_width')) {
      context.handle(
        _resolutionWidthMeta,
        resolutionWidth.isAcceptableOrUnknown(
          data['resolution_width']!,
          _resolutionWidthMeta,
        ),
      );
    }
    if (data.containsKey('resolution_height')) {
      context.handle(
        _resolutionHeightMeta,
        resolutionHeight.isAcceptableOrUnknown(
          data['resolution_height']!,
          _resolutionHeightMeta,
        ),
      );
    }
    if (data.containsKey('fullscreen')) {
      context.handle(
        _fullscreenMeta,
        fullscreen.isAcceptableOrUnknown(data['fullscreen']!, _fullscreenMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    if (data.containsKey('total_play_time_seconds')) {
      context.handle(
        _totalPlayTimeSecondsMeta,
        totalPlayTimeSeconds.isAcceptableOrUnknown(
          data['total_play_time_seconds']!,
          _totalPlayTimeSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  McInstance map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return McInstance(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_id'],
      )!,
      loader: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loader'],
      )!,
      loaderVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loader_version'],
      ),
      iconPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_path'],
      ),
      minMemoryMb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_memory_mb'],
      )!,
      maxMemoryMb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_memory_mb'],
      )!,
      jvmArgs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jvm_args'],
      ),
      javaPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}java_path'],
      ),
      resolutionWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolution_width'],
      )!,
      resolutionHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolution_height'],
      )!,
      fullscreen: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fullscreen'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      ),
      totalPlayTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_play_time_seconds'],
      )!,
    );
  }

  @override
  $McInstancesTable createAlias(String alias) {
    return $McInstancesTable(attachedDatabase, alias);
  }
}

class McInstance extends DataClass implements Insertable<McInstance> {
  final String id;
  final String name;
  final String versionId;
  final String loader;
  final String? loaderVersion;
  final String? iconPath;
  final int minMemoryMb;
  final int maxMemoryMb;
  final String? jvmArgs;
  final String? javaPath;
  final int resolutionWidth;
  final int resolutionHeight;
  final bool fullscreen;
  final DateTime createdAt;
  final DateTime? lastPlayedAt;
  final int totalPlayTimeSeconds;
  const McInstance({
    required this.id,
    required this.name,
    required this.versionId,
    required this.loader,
    this.loaderVersion,
    this.iconPath,
    required this.minMemoryMb,
    required this.maxMemoryMb,
    this.jvmArgs,
    this.javaPath,
    required this.resolutionWidth,
    required this.resolutionHeight,
    required this.fullscreen,
    required this.createdAt,
    this.lastPlayedAt,
    required this.totalPlayTimeSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['version_id'] = Variable<String>(versionId);
    map['loader'] = Variable<String>(loader);
    if (!nullToAbsent || loaderVersion != null) {
      map['loader_version'] = Variable<String>(loaderVersion);
    }
    if (!nullToAbsent || iconPath != null) {
      map['icon_path'] = Variable<String>(iconPath);
    }
    map['min_memory_mb'] = Variable<int>(minMemoryMb);
    map['max_memory_mb'] = Variable<int>(maxMemoryMb);
    if (!nullToAbsent || jvmArgs != null) {
      map['jvm_args'] = Variable<String>(jvmArgs);
    }
    if (!nullToAbsent || javaPath != null) {
      map['java_path'] = Variable<String>(javaPath);
    }
    map['resolution_width'] = Variable<int>(resolutionWidth);
    map['resolution_height'] = Variable<int>(resolutionHeight);
    map['fullscreen'] = Variable<bool>(fullscreen);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    }
    map['total_play_time_seconds'] = Variable<int>(totalPlayTimeSeconds);
    return map;
  }

  McInstancesCompanion toCompanion(bool nullToAbsent) {
    return McInstancesCompanion(
      id: Value(id),
      name: Value(name),
      versionId: Value(versionId),
      loader: Value(loader),
      loaderVersion: loaderVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(loaderVersion),
      iconPath: iconPath == null && nullToAbsent
          ? const Value.absent()
          : Value(iconPath),
      minMemoryMb: Value(minMemoryMb),
      maxMemoryMb: Value(maxMemoryMb),
      jvmArgs: jvmArgs == null && nullToAbsent
          ? const Value.absent()
          : Value(jvmArgs),
      javaPath: javaPath == null && nullToAbsent
          ? const Value.absent()
          : Value(javaPath),
      resolutionWidth: Value(resolutionWidth),
      resolutionHeight: Value(resolutionHeight),
      fullscreen: Value(fullscreen),
      createdAt: Value(createdAt),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
      totalPlayTimeSeconds: Value(totalPlayTimeSeconds),
    );
  }

  factory McInstance.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return McInstance(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      versionId: serializer.fromJson<String>(json['versionId']),
      loader: serializer.fromJson<String>(json['loader']),
      loaderVersion: serializer.fromJson<String?>(json['loaderVersion']),
      iconPath: serializer.fromJson<String?>(json['iconPath']),
      minMemoryMb: serializer.fromJson<int>(json['minMemoryMb']),
      maxMemoryMb: serializer.fromJson<int>(json['maxMemoryMb']),
      jvmArgs: serializer.fromJson<String?>(json['jvmArgs']),
      javaPath: serializer.fromJson<String?>(json['javaPath']),
      resolutionWidth: serializer.fromJson<int>(json['resolutionWidth']),
      resolutionHeight: serializer.fromJson<int>(json['resolutionHeight']),
      fullscreen: serializer.fromJson<bool>(json['fullscreen']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
      totalPlayTimeSeconds: serializer.fromJson<int>(
        json['totalPlayTimeSeconds'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'versionId': serializer.toJson<String>(versionId),
      'loader': serializer.toJson<String>(loader),
      'loaderVersion': serializer.toJson<String?>(loaderVersion),
      'iconPath': serializer.toJson<String?>(iconPath),
      'minMemoryMb': serializer.toJson<int>(minMemoryMb),
      'maxMemoryMb': serializer.toJson<int>(maxMemoryMb),
      'jvmArgs': serializer.toJson<String?>(jvmArgs),
      'javaPath': serializer.toJson<String?>(javaPath),
      'resolutionWidth': serializer.toJson<int>(resolutionWidth),
      'resolutionHeight': serializer.toJson<int>(resolutionHeight),
      'fullscreen': serializer.toJson<bool>(fullscreen),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
      'totalPlayTimeSeconds': serializer.toJson<int>(totalPlayTimeSeconds),
    };
  }

  McInstance copyWith({
    String? id,
    String? name,
    String? versionId,
    String? loader,
    Value<String?> loaderVersion = const Value.absent(),
    Value<String?> iconPath = const Value.absent(),
    int? minMemoryMb,
    int? maxMemoryMb,
    Value<String?> jvmArgs = const Value.absent(),
    Value<String?> javaPath = const Value.absent(),
    int? resolutionWidth,
    int? resolutionHeight,
    bool? fullscreen,
    DateTime? createdAt,
    Value<DateTime?> lastPlayedAt = const Value.absent(),
    int? totalPlayTimeSeconds,
  }) => McInstance(
    id: id ?? this.id,
    name: name ?? this.name,
    versionId: versionId ?? this.versionId,
    loader: loader ?? this.loader,
    loaderVersion: loaderVersion.present
        ? loaderVersion.value
        : this.loaderVersion,
    iconPath: iconPath.present ? iconPath.value : this.iconPath,
    minMemoryMb: minMemoryMb ?? this.minMemoryMb,
    maxMemoryMb: maxMemoryMb ?? this.maxMemoryMb,
    jvmArgs: jvmArgs.present ? jvmArgs.value : this.jvmArgs,
    javaPath: javaPath.present ? javaPath.value : this.javaPath,
    resolutionWidth: resolutionWidth ?? this.resolutionWidth,
    resolutionHeight: resolutionHeight ?? this.resolutionHeight,
    fullscreen: fullscreen ?? this.fullscreen,
    createdAt: createdAt ?? this.createdAt,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
    totalPlayTimeSeconds: totalPlayTimeSeconds ?? this.totalPlayTimeSeconds,
  );
  McInstance copyWithCompanion(McInstancesCompanion data) {
    return McInstance(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      loader: data.loader.present ? data.loader.value : this.loader,
      loaderVersion: data.loaderVersion.present
          ? data.loaderVersion.value
          : this.loaderVersion,
      iconPath: data.iconPath.present ? data.iconPath.value : this.iconPath,
      minMemoryMb: data.minMemoryMb.present
          ? data.minMemoryMb.value
          : this.minMemoryMb,
      maxMemoryMb: data.maxMemoryMb.present
          ? data.maxMemoryMb.value
          : this.maxMemoryMb,
      jvmArgs: data.jvmArgs.present ? data.jvmArgs.value : this.jvmArgs,
      javaPath: data.javaPath.present ? data.javaPath.value : this.javaPath,
      resolutionWidth: data.resolutionWidth.present
          ? data.resolutionWidth.value
          : this.resolutionWidth,
      resolutionHeight: data.resolutionHeight.present
          ? data.resolutionHeight.value
          : this.resolutionHeight,
      fullscreen: data.fullscreen.present
          ? data.fullscreen.value
          : this.fullscreen,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      totalPlayTimeSeconds: data.totalPlayTimeSeconds.present
          ? data.totalPlayTimeSeconds.value
          : this.totalPlayTimeSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('McInstance(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('versionId: $versionId, ')
          ..write('loader: $loader, ')
          ..write('loaderVersion: $loaderVersion, ')
          ..write('iconPath: $iconPath, ')
          ..write('minMemoryMb: $minMemoryMb, ')
          ..write('maxMemoryMb: $maxMemoryMb, ')
          ..write('jvmArgs: $jvmArgs, ')
          ..write('javaPath: $javaPath, ')
          ..write('resolutionWidth: $resolutionWidth, ')
          ..write('resolutionHeight: $resolutionHeight, ')
          ..write('fullscreen: $fullscreen, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('totalPlayTimeSeconds: $totalPlayTimeSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    versionId,
    loader,
    loaderVersion,
    iconPath,
    minMemoryMb,
    maxMemoryMb,
    jvmArgs,
    javaPath,
    resolutionWidth,
    resolutionHeight,
    fullscreen,
    createdAt,
    lastPlayedAt,
    totalPlayTimeSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McInstance &&
          other.id == this.id &&
          other.name == this.name &&
          other.versionId == this.versionId &&
          other.loader == this.loader &&
          other.loaderVersion == this.loaderVersion &&
          other.iconPath == this.iconPath &&
          other.minMemoryMb == this.minMemoryMb &&
          other.maxMemoryMb == this.maxMemoryMb &&
          other.jvmArgs == this.jvmArgs &&
          other.javaPath == this.javaPath &&
          other.resolutionWidth == this.resolutionWidth &&
          other.resolutionHeight == this.resolutionHeight &&
          other.fullscreen == this.fullscreen &&
          other.createdAt == this.createdAt &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.totalPlayTimeSeconds == this.totalPlayTimeSeconds);
}

class McInstancesCompanion extends UpdateCompanion<McInstance> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> versionId;
  final Value<String> loader;
  final Value<String?> loaderVersion;
  final Value<String?> iconPath;
  final Value<int> minMemoryMb;
  final Value<int> maxMemoryMb;
  final Value<String?> jvmArgs;
  final Value<String?> javaPath;
  final Value<int> resolutionWidth;
  final Value<int> resolutionHeight;
  final Value<bool> fullscreen;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastPlayedAt;
  final Value<int> totalPlayTimeSeconds;
  final Value<int> rowid;
  const McInstancesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.versionId = const Value.absent(),
    this.loader = const Value.absent(),
    this.loaderVersion = const Value.absent(),
    this.iconPath = const Value.absent(),
    this.minMemoryMb = const Value.absent(),
    this.maxMemoryMb = const Value.absent(),
    this.jvmArgs = const Value.absent(),
    this.javaPath = const Value.absent(),
    this.resolutionWidth = const Value.absent(),
    this.resolutionHeight = const Value.absent(),
    this.fullscreen = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.totalPlayTimeSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  McInstancesCompanion.insert({
    required String id,
    required String name,
    required String versionId,
    this.loader = const Value.absent(),
    this.loaderVersion = const Value.absent(),
    this.iconPath = const Value.absent(),
    this.minMemoryMb = const Value.absent(),
    this.maxMemoryMb = const Value.absent(),
    this.jvmArgs = const Value.absent(),
    this.javaPath = const Value.absent(),
    this.resolutionWidth = const Value.absent(),
    this.resolutionHeight = const Value.absent(),
    this.fullscreen = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.totalPlayTimeSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       versionId = Value(versionId);
  static Insertable<McInstance> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? versionId,
    Expression<String>? loader,
    Expression<String>? loaderVersion,
    Expression<String>? iconPath,
    Expression<int>? minMemoryMb,
    Expression<int>? maxMemoryMb,
    Expression<String>? jvmArgs,
    Expression<String>? javaPath,
    Expression<int>? resolutionWidth,
    Expression<int>? resolutionHeight,
    Expression<bool>? fullscreen,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastPlayedAt,
    Expression<int>? totalPlayTimeSeconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (versionId != null) 'version_id': versionId,
      if (loader != null) 'loader': loader,
      if (loaderVersion != null) 'loader_version': loaderVersion,
      if (iconPath != null) 'icon_path': iconPath,
      if (minMemoryMb != null) 'min_memory_mb': minMemoryMb,
      if (maxMemoryMb != null) 'max_memory_mb': maxMemoryMb,
      if (jvmArgs != null) 'jvm_args': jvmArgs,
      if (javaPath != null) 'java_path': javaPath,
      if (resolutionWidth != null) 'resolution_width': resolutionWidth,
      if (resolutionHeight != null) 'resolution_height': resolutionHeight,
      if (fullscreen != null) 'fullscreen': fullscreen,
      if (createdAt != null) 'created_at': createdAt,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (totalPlayTimeSeconds != null)
        'total_play_time_seconds': totalPlayTimeSeconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  McInstancesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? versionId,
    Value<String>? loader,
    Value<String?>? loaderVersion,
    Value<String?>? iconPath,
    Value<int>? minMemoryMb,
    Value<int>? maxMemoryMb,
    Value<String?>? jvmArgs,
    Value<String?>? javaPath,
    Value<int>? resolutionWidth,
    Value<int>? resolutionHeight,
    Value<bool>? fullscreen,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastPlayedAt,
    Value<int>? totalPlayTimeSeconds,
    Value<int>? rowid,
  }) {
    return McInstancesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      versionId: versionId ?? this.versionId,
      loader: loader ?? this.loader,
      loaderVersion: loaderVersion ?? this.loaderVersion,
      iconPath: iconPath ?? this.iconPath,
      minMemoryMb: minMemoryMb ?? this.minMemoryMb,
      maxMemoryMb: maxMemoryMb ?? this.maxMemoryMb,
      jvmArgs: jvmArgs ?? this.jvmArgs,
      javaPath: javaPath ?? this.javaPath,
      resolutionWidth: resolutionWidth ?? this.resolutionWidth,
      resolutionHeight: resolutionHeight ?? this.resolutionHeight,
      fullscreen: fullscreen ?? this.fullscreen,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      totalPlayTimeSeconds: totalPlayTimeSeconds ?? this.totalPlayTimeSeconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (loader.present) {
      map['loader'] = Variable<String>(loader.value);
    }
    if (loaderVersion.present) {
      map['loader_version'] = Variable<String>(loaderVersion.value);
    }
    if (iconPath.present) {
      map['icon_path'] = Variable<String>(iconPath.value);
    }
    if (minMemoryMb.present) {
      map['min_memory_mb'] = Variable<int>(minMemoryMb.value);
    }
    if (maxMemoryMb.present) {
      map['max_memory_mb'] = Variable<int>(maxMemoryMb.value);
    }
    if (jvmArgs.present) {
      map['jvm_args'] = Variable<String>(jvmArgs.value);
    }
    if (javaPath.present) {
      map['java_path'] = Variable<String>(javaPath.value);
    }
    if (resolutionWidth.present) {
      map['resolution_width'] = Variable<int>(resolutionWidth.value);
    }
    if (resolutionHeight.present) {
      map['resolution_height'] = Variable<int>(resolutionHeight.value);
    }
    if (fullscreen.present) {
      map['fullscreen'] = Variable<bool>(fullscreen.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (totalPlayTimeSeconds.present) {
      map['total_play_time_seconds'] = Variable<int>(
        totalPlayTimeSeconds.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('McInstancesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('versionId: $versionId, ')
          ..write('loader: $loader, ')
          ..write('loaderVersion: $loaderVersion, ')
          ..write('iconPath: $iconPath, ')
          ..write('minMemoryMb: $minMemoryMb, ')
          ..write('maxMemoryMb: $maxMemoryMb, ')
          ..write('jvmArgs: $jvmArgs, ')
          ..write('javaPath: $javaPath, ')
          ..write('resolutionWidth: $resolutionWidth, ')
          ..write('resolutionHeight: $resolutionHeight, ')
          ..write('fullscreen: $fullscreen, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('totalPlayTimeSeconds: $totalPlayTimeSeconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $McLaunchHistoryTable extends McLaunchHistory
    with TableInfo<$McLaunchHistoryTable, McLaunchHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $McLaunchHistoryTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _instanceIdMeta = const VerificationMeta(
    'instanceId',
  );
  @override
  late final GeneratedColumn<String> instanceId = GeneratedColumn<String>(
    'instance_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mc_instances (id)',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exitCodeMeta = const VerificationMeta(
    'exitCode',
  );
  @override
  late final GeneratedColumn<int> exitCode = GeneratedColumn<int>(
    'exit_code',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logFilePathMeta = const VerificationMeta(
    'logFilePath',
  );
  @override
  late final GeneratedColumn<String> logFilePath = GeneratedColumn<String>(
    'log_file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    instanceId,
    startedAt,
    endedAt,
    exitCode,
    logFilePath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mc_launch_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<McLaunchHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('instance_id')) {
      context.handle(
        _instanceIdMeta,
        instanceId.isAcceptableOrUnknown(data['instance_id']!, _instanceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_instanceIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('exit_code')) {
      context.handle(
        _exitCodeMeta,
        exitCode.isAcceptableOrUnknown(data['exit_code']!, _exitCodeMeta),
      );
    }
    if (data.containsKey('log_file_path')) {
      context.handle(
        _logFilePathMeta,
        logFilePath.isAcceptableOrUnknown(
          data['log_file_path']!,
          _logFilePathMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  McLaunchHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return McLaunchHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      instanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instance_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      exitCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exit_code'],
      ),
      logFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}log_file_path'],
      ),
    );
  }

  @override
  $McLaunchHistoryTable createAlias(String alias) {
    return $McLaunchHistoryTable(attachedDatabase, alias);
  }
}

class McLaunchHistoryData extends DataClass
    implements Insertable<McLaunchHistoryData> {
  final int id;
  final String instanceId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? exitCode;
  final String? logFilePath;
  const McLaunchHistoryData({
    required this.id,
    required this.instanceId,
    required this.startedAt,
    this.endedAt,
    this.exitCode,
    this.logFilePath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['instance_id'] = Variable<String>(instanceId);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || exitCode != null) {
      map['exit_code'] = Variable<int>(exitCode);
    }
    if (!nullToAbsent || logFilePath != null) {
      map['log_file_path'] = Variable<String>(logFilePath);
    }
    return map;
  }

  McLaunchHistoryCompanion toCompanion(bool nullToAbsent) {
    return McLaunchHistoryCompanion(
      id: Value(id),
      instanceId: Value(instanceId),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      exitCode: exitCode == null && nullToAbsent
          ? const Value.absent()
          : Value(exitCode),
      logFilePath: logFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(logFilePath),
    );
  }

  factory McLaunchHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return McLaunchHistoryData(
      id: serializer.fromJson<int>(json['id']),
      instanceId: serializer.fromJson<String>(json['instanceId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      exitCode: serializer.fromJson<int?>(json['exitCode']),
      logFilePath: serializer.fromJson<String?>(json['logFilePath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'instanceId': serializer.toJson<String>(instanceId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'exitCode': serializer.toJson<int?>(exitCode),
      'logFilePath': serializer.toJson<String?>(logFilePath),
    };
  }

  McLaunchHistoryData copyWith({
    int? id,
    String? instanceId,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<int?> exitCode = const Value.absent(),
    Value<String?> logFilePath = const Value.absent(),
  }) => McLaunchHistoryData(
    id: id ?? this.id,
    instanceId: instanceId ?? this.instanceId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    exitCode: exitCode.present ? exitCode.value : this.exitCode,
    logFilePath: logFilePath.present ? logFilePath.value : this.logFilePath,
  );
  McLaunchHistoryData copyWithCompanion(McLaunchHistoryCompanion data) {
    return McLaunchHistoryData(
      id: data.id.present ? data.id.value : this.id,
      instanceId: data.instanceId.present
          ? data.instanceId.value
          : this.instanceId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      exitCode: data.exitCode.present ? data.exitCode.value : this.exitCode,
      logFilePath: data.logFilePath.present
          ? data.logFilePath.value
          : this.logFilePath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('McLaunchHistoryData(')
          ..write('id: $id, ')
          ..write('instanceId: $instanceId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('exitCode: $exitCode, ')
          ..write('logFilePath: $logFilePath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, instanceId, startedAt, endedAt, exitCode, logFilePath);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McLaunchHistoryData &&
          other.id == this.id &&
          other.instanceId == this.instanceId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.exitCode == this.exitCode &&
          other.logFilePath == this.logFilePath);
}

class McLaunchHistoryCompanion extends UpdateCompanion<McLaunchHistoryData> {
  final Value<int> id;
  final Value<String> instanceId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int?> exitCode;
  final Value<String?> logFilePath;
  const McLaunchHistoryCompanion({
    this.id = const Value.absent(),
    this.instanceId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.exitCode = const Value.absent(),
    this.logFilePath = const Value.absent(),
  });
  McLaunchHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String instanceId,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.exitCode = const Value.absent(),
    this.logFilePath = const Value.absent(),
  }) : instanceId = Value(instanceId),
       startedAt = Value(startedAt);
  static Insertable<McLaunchHistoryData> custom({
    Expression<int>? id,
    Expression<String>? instanceId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? exitCode,
    Expression<String>? logFilePath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (instanceId != null) 'instance_id': instanceId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (exitCode != null) 'exit_code': exitCode,
      if (logFilePath != null) 'log_file_path': logFilePath,
    });
  }

  McLaunchHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? instanceId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int?>? exitCode,
    Value<String?>? logFilePath,
  }) {
    return McLaunchHistoryCompanion(
      id: id ?? this.id,
      instanceId: instanceId ?? this.instanceId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      exitCode: exitCode ?? this.exitCode,
      logFilePath: logFilePath ?? this.logFilePath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (instanceId.present) {
      map['instance_id'] = Variable<String>(instanceId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (exitCode.present) {
      map['exit_code'] = Variable<int>(exitCode.value);
    }
    if (logFilePath.present) {
      map['log_file_path'] = Variable<String>(logFilePath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('McLaunchHistoryCompanion(')
          ..write('id: $id, ')
          ..write('instanceId: $instanceId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('exitCode: $exitCode, ')
          ..write('logFilePath: $logFilePath')
          ..write(')'))
        .toString();
  }
}

class $McInstalledModsTable extends McInstalledMods
    with TableInfo<$McInstalledModsTable, McInstalledMod> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $McInstalledModsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _instanceIdMeta = const VerificationMeta(
    'instanceId',
  );
  @override
  late final GeneratedColumn<String> instanceId = GeneratedColumn<String>(
    'instance_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mc_instances (id)',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
    'version_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectNameMeta = const VerificationMeta(
    'projectName',
  );
  @override
  late final GeneratedColumn<String> projectName = GeneratedColumn<String>(
    'project_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectIconUrlMeta = const VerificationMeta(
    'projectIconUrl',
  );
  @override
  late final GeneratedColumn<String> projectIconUrl = GeneratedColumn<String>(
    'project_icon_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha1Meta = const VerificationMeta('sha1');
  @override
  late final GeneratedColumn<String> sha1 = GeneratedColumn<String>(
    'sha1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('mod'),
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    instanceId,
    projectId,
    versionId,
    projectName,
    projectIconUrl,
    fileName,
    sha1,
    enabled,
    kind,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mc_installed_mods';
  @override
  VerificationContext validateIntegrity(
    Insertable<McInstalledMod> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('instance_id')) {
      context.handle(
        _instanceIdMeta,
        instanceId.isAcceptableOrUnknown(data['instance_id']!, _instanceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_instanceIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    }
    if (data.containsKey('project_name')) {
      context.handle(
        _projectNameMeta,
        projectName.isAcceptableOrUnknown(
          data['project_name']!,
          _projectNameMeta,
        ),
      );
    }
    if (data.containsKey('project_icon_url')) {
      context.handle(
        _projectIconUrlMeta,
        projectIconUrl.isAcceptableOrUnknown(
          data['project_icon_url']!,
          _projectIconUrlMeta,
        ),
      );
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('sha1')) {
      context.handle(
        _sha1Meta,
        sha1.isAcceptableOrUnknown(data['sha1']!, _sha1Meta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  McInstalledMod map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return McInstalledMod(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      instanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instance_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_id'],
      ),
      projectName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_name'],
      ),
      projectIconUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_icon_url'],
      ),
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      sha1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha1'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
    );
  }

  @override
  $McInstalledModsTable createAlias(String alias) {
    return $McInstalledModsTable(attachedDatabase, alias);
  }
}

class McInstalledMod extends DataClass implements Insertable<McInstalledMod> {
  final int id;
  final String instanceId;
  final String? projectId;
  final String? versionId;
  final String? projectName;
  final String? projectIconUrl;
  final String fileName;
  final String? sha1;
  final bool enabled;
  final String kind;
  final DateTime installedAt;
  const McInstalledMod({
    required this.id,
    required this.instanceId,
    this.projectId,
    this.versionId,
    this.projectName,
    this.projectIconUrl,
    required this.fileName,
    this.sha1,
    required this.enabled,
    required this.kind,
    required this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['instance_id'] = Variable<String>(instanceId);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    if (!nullToAbsent || versionId != null) {
      map['version_id'] = Variable<String>(versionId);
    }
    if (!nullToAbsent || projectName != null) {
      map['project_name'] = Variable<String>(projectName);
    }
    if (!nullToAbsent || projectIconUrl != null) {
      map['project_icon_url'] = Variable<String>(projectIconUrl);
    }
    map['file_name'] = Variable<String>(fileName);
    if (!nullToAbsent || sha1 != null) {
      map['sha1'] = Variable<String>(sha1);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['kind'] = Variable<String>(kind);
    map['installed_at'] = Variable<DateTime>(installedAt);
    return map;
  }

  McInstalledModsCompanion toCompanion(bool nullToAbsent) {
    return McInstalledModsCompanion(
      id: Value(id),
      instanceId: Value(instanceId),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      versionId: versionId == null && nullToAbsent
          ? const Value.absent()
          : Value(versionId),
      projectName: projectName == null && nullToAbsent
          ? const Value.absent()
          : Value(projectName),
      projectIconUrl: projectIconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(projectIconUrl),
      fileName: Value(fileName),
      sha1: sha1 == null && nullToAbsent ? const Value.absent() : Value(sha1),
      enabled: Value(enabled),
      kind: Value(kind),
      installedAt: Value(installedAt),
    );
  }

  factory McInstalledMod.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return McInstalledMod(
      id: serializer.fromJson<int>(json['id']),
      instanceId: serializer.fromJson<String>(json['instanceId']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      versionId: serializer.fromJson<String?>(json['versionId']),
      projectName: serializer.fromJson<String?>(json['projectName']),
      projectIconUrl: serializer.fromJson<String?>(json['projectIconUrl']),
      fileName: serializer.fromJson<String>(json['fileName']),
      sha1: serializer.fromJson<String?>(json['sha1']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      kind: serializer.fromJson<String>(json['kind']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'instanceId': serializer.toJson<String>(instanceId),
      'projectId': serializer.toJson<String?>(projectId),
      'versionId': serializer.toJson<String?>(versionId),
      'projectName': serializer.toJson<String?>(projectName),
      'projectIconUrl': serializer.toJson<String?>(projectIconUrl),
      'fileName': serializer.toJson<String>(fileName),
      'sha1': serializer.toJson<String?>(sha1),
      'enabled': serializer.toJson<bool>(enabled),
      'kind': serializer.toJson<String>(kind),
      'installedAt': serializer.toJson<DateTime>(installedAt),
    };
  }

  McInstalledMod copyWith({
    int? id,
    String? instanceId,
    Value<String?> projectId = const Value.absent(),
    Value<String?> versionId = const Value.absent(),
    Value<String?> projectName = const Value.absent(),
    Value<String?> projectIconUrl = const Value.absent(),
    String? fileName,
    Value<String?> sha1 = const Value.absent(),
    bool? enabled,
    String? kind,
    DateTime? installedAt,
  }) => McInstalledMod(
    id: id ?? this.id,
    instanceId: instanceId ?? this.instanceId,
    projectId: projectId.present ? projectId.value : this.projectId,
    versionId: versionId.present ? versionId.value : this.versionId,
    projectName: projectName.present ? projectName.value : this.projectName,
    projectIconUrl: projectIconUrl.present
        ? projectIconUrl.value
        : this.projectIconUrl,
    fileName: fileName ?? this.fileName,
    sha1: sha1.present ? sha1.value : this.sha1,
    enabled: enabled ?? this.enabled,
    kind: kind ?? this.kind,
    installedAt: installedAt ?? this.installedAt,
  );
  McInstalledMod copyWithCompanion(McInstalledModsCompanion data) {
    return McInstalledMod(
      id: data.id.present ? data.id.value : this.id,
      instanceId: data.instanceId.present
          ? data.instanceId.value
          : this.instanceId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      projectName: data.projectName.present
          ? data.projectName.value
          : this.projectName,
      projectIconUrl: data.projectIconUrl.present
          ? data.projectIconUrl.value
          : this.projectIconUrl,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      sha1: data.sha1.present ? data.sha1.value : this.sha1,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      kind: data.kind.present ? data.kind.value : this.kind,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('McInstalledMod(')
          ..write('id: $id, ')
          ..write('instanceId: $instanceId, ')
          ..write('projectId: $projectId, ')
          ..write('versionId: $versionId, ')
          ..write('projectName: $projectName, ')
          ..write('projectIconUrl: $projectIconUrl, ')
          ..write('fileName: $fileName, ')
          ..write('sha1: $sha1, ')
          ..write('enabled: $enabled, ')
          ..write('kind: $kind, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    instanceId,
    projectId,
    versionId,
    projectName,
    projectIconUrl,
    fileName,
    sha1,
    enabled,
    kind,
    installedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McInstalledMod &&
          other.id == this.id &&
          other.instanceId == this.instanceId &&
          other.projectId == this.projectId &&
          other.versionId == this.versionId &&
          other.projectName == this.projectName &&
          other.projectIconUrl == this.projectIconUrl &&
          other.fileName == this.fileName &&
          other.sha1 == this.sha1 &&
          other.enabled == this.enabled &&
          other.kind == this.kind &&
          other.installedAt == this.installedAt);
}

class McInstalledModsCompanion extends UpdateCompanion<McInstalledMod> {
  final Value<int> id;
  final Value<String> instanceId;
  final Value<String?> projectId;
  final Value<String?> versionId;
  final Value<String?> projectName;
  final Value<String?> projectIconUrl;
  final Value<String> fileName;
  final Value<String?> sha1;
  final Value<bool> enabled;
  final Value<String> kind;
  final Value<DateTime> installedAt;
  const McInstalledModsCompanion({
    this.id = const Value.absent(),
    this.instanceId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.versionId = const Value.absent(),
    this.projectName = const Value.absent(),
    this.projectIconUrl = const Value.absent(),
    this.fileName = const Value.absent(),
    this.sha1 = const Value.absent(),
    this.enabled = const Value.absent(),
    this.kind = const Value.absent(),
    this.installedAt = const Value.absent(),
  });
  McInstalledModsCompanion.insert({
    this.id = const Value.absent(),
    required String instanceId,
    this.projectId = const Value.absent(),
    this.versionId = const Value.absent(),
    this.projectName = const Value.absent(),
    this.projectIconUrl = const Value.absent(),
    required String fileName,
    this.sha1 = const Value.absent(),
    this.enabled = const Value.absent(),
    this.kind = const Value.absent(),
    this.installedAt = const Value.absent(),
  }) : instanceId = Value(instanceId),
       fileName = Value(fileName);
  static Insertable<McInstalledMod> custom({
    Expression<int>? id,
    Expression<String>? instanceId,
    Expression<String>? projectId,
    Expression<String>? versionId,
    Expression<String>? projectName,
    Expression<String>? projectIconUrl,
    Expression<String>? fileName,
    Expression<String>? sha1,
    Expression<bool>? enabled,
    Expression<String>? kind,
    Expression<DateTime>? installedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (instanceId != null) 'instance_id': instanceId,
      if (projectId != null) 'project_id': projectId,
      if (versionId != null) 'version_id': versionId,
      if (projectName != null) 'project_name': projectName,
      if (projectIconUrl != null) 'project_icon_url': projectIconUrl,
      if (fileName != null) 'file_name': fileName,
      if (sha1 != null) 'sha1': sha1,
      if (enabled != null) 'enabled': enabled,
      if (kind != null) 'kind': kind,
      if (installedAt != null) 'installed_at': installedAt,
    });
  }

  McInstalledModsCompanion copyWith({
    Value<int>? id,
    Value<String>? instanceId,
    Value<String?>? projectId,
    Value<String?>? versionId,
    Value<String?>? projectName,
    Value<String?>? projectIconUrl,
    Value<String>? fileName,
    Value<String?>? sha1,
    Value<bool>? enabled,
    Value<String>? kind,
    Value<DateTime>? installedAt,
  }) {
    return McInstalledModsCompanion(
      id: id ?? this.id,
      instanceId: instanceId ?? this.instanceId,
      projectId: projectId ?? this.projectId,
      versionId: versionId ?? this.versionId,
      projectName: projectName ?? this.projectName,
      projectIconUrl: projectIconUrl ?? this.projectIconUrl,
      fileName: fileName ?? this.fileName,
      sha1: sha1 ?? this.sha1,
      enabled: enabled ?? this.enabled,
      kind: kind ?? this.kind,
      installedAt: installedAt ?? this.installedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (instanceId.present) {
      map['instance_id'] = Variable<String>(instanceId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (projectName.present) {
      map['project_name'] = Variable<String>(projectName.value);
    }
    if (projectIconUrl.present) {
      map['project_icon_url'] = Variable<String>(projectIconUrl.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (sha1.present) {
      map['sha1'] = Variable<String>(sha1.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('McInstalledModsCompanion(')
          ..write('id: $id, ')
          ..write('instanceId: $instanceId, ')
          ..write('projectId: $projectId, ')
          ..write('versionId: $versionId, ')
          ..write('projectName: $projectName, ')
          ..write('projectIconUrl: $projectIconUrl, ')
          ..write('fileName: $fileName, ')
          ..write('sha1: $sha1, ')
          ..write('enabled: $enabled, ')
          ..write('kind: $kind, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$MinecraftLauncherDatabase extends GeneratedDatabase {
  _$MinecraftLauncherDatabase(QueryExecutor e) : super(e);
  $MinecraftLauncherDatabaseManager get managers =>
      $MinecraftLauncherDatabaseManager(this);
  late final $McAccountsTable mcAccounts = $McAccountsTable(this);
  late final $McInstancesTable mcInstances = $McInstancesTable(this);
  late final $McLaunchHistoryTable mcLaunchHistory = $McLaunchHistoryTable(
    this,
  );
  late final $McInstalledModsTable mcInstalledMods = $McInstalledModsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mcAccounts,
    mcInstances,
    mcLaunchHistory,
    mcInstalledMods,
  ];
}

typedef $$McAccountsTableCreateCompanionBuilder =
    McAccountsCompanion Function({
      Value<int> id,
      required String type,
      required String username,
      required String uuid,
      Value<String?> accessToken,
      Value<String?> refreshToken,
      Value<DateTime?> accessTokenExpiresAt,
      Value<String?> avatarUrl,
      Value<bool> isActive,
      Value<DateTime> createdAt,
    });
typedef $$McAccountsTableUpdateCompanionBuilder =
    McAccountsCompanion Function({
      Value<int> id,
      Value<String> type,
      Value<String> username,
      Value<String> uuid,
      Value<String?> accessToken,
      Value<String?> refreshToken,
      Value<DateTime?> accessTokenExpiresAt,
      Value<String?> avatarUrl,
      Value<bool> isActive,
      Value<DateTime> createdAt,
    });

class $$McAccountsTableFilterComposer
    extends Composer<_$MinecraftLauncherDatabase, $McAccountsTable> {
  $$McAccountsTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accessToken => $composableBuilder(
    column: $table.accessToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refreshToken => $composableBuilder(
    column: $table.refreshToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get accessTokenExpiresAt => $composableBuilder(
    column: $table.accessTokenExpiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$McAccountsTableOrderingComposer
    extends Composer<_$MinecraftLauncherDatabase, $McAccountsTable> {
  $$McAccountsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accessToken => $composableBuilder(
    column: $table.accessToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refreshToken => $composableBuilder(
    column: $table.refreshToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get accessTokenExpiresAt => $composableBuilder(
    column: $table.accessTokenExpiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$McAccountsTableAnnotationComposer
    extends Composer<_$MinecraftLauncherDatabase, $McAccountsTable> {
  $$McAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get accessToken => $composableBuilder(
    column: $table.accessToken,
    builder: (column) => column,
  );

  GeneratedColumn<String> get refreshToken => $composableBuilder(
    column: $table.refreshToken,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get accessTokenExpiresAt => $composableBuilder(
    column: $table.accessTokenExpiresAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$McAccountsTableTableManager
    extends
        RootTableManager<
          _$MinecraftLauncherDatabase,
          $McAccountsTable,
          McAccount,
          $$McAccountsTableFilterComposer,
          $$McAccountsTableOrderingComposer,
          $$McAccountsTableAnnotationComposer,
          $$McAccountsTableCreateCompanionBuilder,
          $$McAccountsTableUpdateCompanionBuilder,
          (
            McAccount,
            BaseReferences<
              _$MinecraftLauncherDatabase,
              $McAccountsTable,
              McAccount
            >,
          ),
          McAccount,
          PrefetchHooks Function()
        > {
  $$McAccountsTableTableManager(
    _$MinecraftLauncherDatabase db,
    $McAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$McAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$McAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$McAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String?> accessToken = const Value.absent(),
                Value<String?> refreshToken = const Value.absent(),
                Value<DateTime?> accessTokenExpiresAt = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => McAccountsCompanion(
                id: id,
                type: type,
                username: username,
                uuid: uuid,
                accessToken: accessToken,
                refreshToken: refreshToken,
                accessTokenExpiresAt: accessTokenExpiresAt,
                avatarUrl: avatarUrl,
                isActive: isActive,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                required String username,
                required String uuid,
                Value<String?> accessToken = const Value.absent(),
                Value<String?> refreshToken = const Value.absent(),
                Value<DateTime?> accessTokenExpiresAt = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => McAccountsCompanion.insert(
                id: id,
                type: type,
                username: username,
                uuid: uuid,
                accessToken: accessToken,
                refreshToken: refreshToken,
                accessTokenExpiresAt: accessTokenExpiresAt,
                avatarUrl: avatarUrl,
                isActive: isActive,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$McAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$MinecraftLauncherDatabase,
      $McAccountsTable,
      McAccount,
      $$McAccountsTableFilterComposer,
      $$McAccountsTableOrderingComposer,
      $$McAccountsTableAnnotationComposer,
      $$McAccountsTableCreateCompanionBuilder,
      $$McAccountsTableUpdateCompanionBuilder,
      (
        McAccount,
        BaseReferences<
          _$MinecraftLauncherDatabase,
          $McAccountsTable,
          McAccount
        >,
      ),
      McAccount,
      PrefetchHooks Function()
    >;
typedef $$McInstancesTableCreateCompanionBuilder =
    McInstancesCompanion Function({
      required String id,
      required String name,
      required String versionId,
      Value<String> loader,
      Value<String?> loaderVersion,
      Value<String?> iconPath,
      Value<int> minMemoryMb,
      Value<int> maxMemoryMb,
      Value<String?> jvmArgs,
      Value<String?> javaPath,
      Value<int> resolutionWidth,
      Value<int> resolutionHeight,
      Value<bool> fullscreen,
      Value<DateTime> createdAt,
      Value<DateTime?> lastPlayedAt,
      Value<int> totalPlayTimeSeconds,
      Value<int> rowid,
    });
typedef $$McInstancesTableUpdateCompanionBuilder =
    McInstancesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> versionId,
      Value<String> loader,
      Value<String?> loaderVersion,
      Value<String?> iconPath,
      Value<int> minMemoryMb,
      Value<int> maxMemoryMb,
      Value<String?> jvmArgs,
      Value<String?> javaPath,
      Value<int> resolutionWidth,
      Value<int> resolutionHeight,
      Value<bool> fullscreen,
      Value<DateTime> createdAt,
      Value<DateTime?> lastPlayedAt,
      Value<int> totalPlayTimeSeconds,
      Value<int> rowid,
    });

final class $$McInstancesTableReferences
    extends
        BaseReferences<
          _$MinecraftLauncherDatabase,
          $McInstancesTable,
          McInstance
        > {
  $$McInstancesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$McLaunchHistoryTable, List<McLaunchHistoryData>>
  _mcLaunchHistoryRefsTable(_$MinecraftLauncherDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.mcLaunchHistory,
        aliasName: 'mc_instances__id__mc_launch_history__instance_id',
      );

  $$McLaunchHistoryTableProcessedTableManager get mcLaunchHistoryRefs {
    final manager = $$McLaunchHistoryTableTableManager(
      $_db,
      $_db.mcLaunchHistory,
    ).filter((f) => f.instanceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _mcLaunchHistoryRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$McInstalledModsTable, List<McInstalledMod>>
  _mcInstalledModsRefsTable(_$MinecraftLauncherDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.mcInstalledMods,
        aliasName: 'mc_instances__id__mc_installed_mods__instance_id',
      );

  $$McInstalledModsTableProcessedTableManager get mcInstalledModsRefs {
    final manager = $$McInstalledModsTableTableManager(
      $_db,
      $_db.mcInstalledMods,
    ).filter((f) => f.instanceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _mcInstalledModsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$McInstancesTableFilterComposer
    extends Composer<_$MinecraftLauncherDatabase, $McInstancesTable> {
  $$McInstancesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loader => $composableBuilder(
    column: $table.loader,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loaderVersion => $composableBuilder(
    column: $table.loaderVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconPath => $composableBuilder(
    column: $table.iconPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minMemoryMb => $composableBuilder(
    column: $table.minMemoryMb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxMemoryMb => $composableBuilder(
    column: $table.maxMemoryMb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jvmArgs => $composableBuilder(
    column: $table.jvmArgs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get javaPath => $composableBuilder(
    column: $table.javaPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolutionWidth => $composableBuilder(
    column: $table.resolutionWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolutionHeight => $composableBuilder(
    column: $table.resolutionHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fullscreen => $composableBuilder(
    column: $table.fullscreen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPlayTimeSeconds => $composableBuilder(
    column: $table.totalPlayTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mcLaunchHistoryRefs(
    Expression<bool> Function($$McLaunchHistoryTableFilterComposer f) f,
  ) {
    final $$McLaunchHistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mcLaunchHistory,
      getReferencedColumn: (t) => t.instanceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McLaunchHistoryTableFilterComposer(
            $db: $db,
            $table: $db.mcLaunchHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> mcInstalledModsRefs(
    Expression<bool> Function($$McInstalledModsTableFilterComposer f) f,
  ) {
    final $$McInstalledModsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mcInstalledMods,
      getReferencedColumn: (t) => t.instanceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McInstalledModsTableFilterComposer(
            $db: $db,
            $table: $db.mcInstalledMods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$McInstancesTableOrderingComposer
    extends Composer<_$MinecraftLauncherDatabase, $McInstancesTable> {
  $$McInstancesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loader => $composableBuilder(
    column: $table.loader,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loaderVersion => $composableBuilder(
    column: $table.loaderVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconPath => $composableBuilder(
    column: $table.iconPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minMemoryMb => $composableBuilder(
    column: $table.minMemoryMb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxMemoryMb => $composableBuilder(
    column: $table.maxMemoryMb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jvmArgs => $composableBuilder(
    column: $table.jvmArgs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get javaPath => $composableBuilder(
    column: $table.javaPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolutionWidth => $composableBuilder(
    column: $table.resolutionWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolutionHeight => $composableBuilder(
    column: $table.resolutionHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fullscreen => $composableBuilder(
    column: $table.fullscreen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPlayTimeSeconds => $composableBuilder(
    column: $table.totalPlayTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$McInstancesTableAnnotationComposer
    extends Composer<_$MinecraftLauncherDatabase, $McInstancesTable> {
  $$McInstancesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<String> get loader =>
      $composableBuilder(column: $table.loader, builder: (column) => column);

  GeneratedColumn<String> get loaderVersion => $composableBuilder(
    column: $table.loaderVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconPath =>
      $composableBuilder(column: $table.iconPath, builder: (column) => column);

  GeneratedColumn<int> get minMemoryMb => $composableBuilder(
    column: $table.minMemoryMb,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxMemoryMb => $composableBuilder(
    column: $table.maxMemoryMb,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jvmArgs =>
      $composableBuilder(column: $table.jvmArgs, builder: (column) => column);

  GeneratedColumn<String> get javaPath =>
      $composableBuilder(column: $table.javaPath, builder: (column) => column);

  GeneratedColumn<int> get resolutionWidth => $composableBuilder(
    column: $table.resolutionWidth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resolutionHeight => $composableBuilder(
    column: $table.resolutionHeight,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get fullscreen => $composableBuilder(
    column: $table.fullscreen,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPlayTimeSeconds => $composableBuilder(
    column: $table.totalPlayTimeSeconds,
    builder: (column) => column,
  );

  Expression<T> mcLaunchHistoryRefs<T extends Object>(
    Expression<T> Function($$McLaunchHistoryTableAnnotationComposer a) f,
  ) {
    final $$McLaunchHistoryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mcLaunchHistory,
      getReferencedColumn: (t) => t.instanceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McLaunchHistoryTableAnnotationComposer(
            $db: $db,
            $table: $db.mcLaunchHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> mcInstalledModsRefs<T extends Object>(
    Expression<T> Function($$McInstalledModsTableAnnotationComposer a) f,
  ) {
    final $$McInstalledModsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mcInstalledMods,
      getReferencedColumn: (t) => t.instanceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McInstalledModsTableAnnotationComposer(
            $db: $db,
            $table: $db.mcInstalledMods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$McInstancesTableTableManager
    extends
        RootTableManager<
          _$MinecraftLauncherDatabase,
          $McInstancesTable,
          McInstance,
          $$McInstancesTableFilterComposer,
          $$McInstancesTableOrderingComposer,
          $$McInstancesTableAnnotationComposer,
          $$McInstancesTableCreateCompanionBuilder,
          $$McInstancesTableUpdateCompanionBuilder,
          (McInstance, $$McInstancesTableReferences),
          McInstance,
          PrefetchHooks Function({
            bool mcLaunchHistoryRefs,
            bool mcInstalledModsRefs,
          })
        > {
  $$McInstancesTableTableManager(
    _$MinecraftLauncherDatabase db,
    $McInstancesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$McInstancesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$McInstancesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$McInstancesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> versionId = const Value.absent(),
                Value<String> loader = const Value.absent(),
                Value<String?> loaderVersion = const Value.absent(),
                Value<String?> iconPath = const Value.absent(),
                Value<int> minMemoryMb = const Value.absent(),
                Value<int> maxMemoryMb = const Value.absent(),
                Value<String?> jvmArgs = const Value.absent(),
                Value<String?> javaPath = const Value.absent(),
                Value<int> resolutionWidth = const Value.absent(),
                Value<int> resolutionHeight = const Value.absent(),
                Value<bool> fullscreen = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> totalPlayTimeSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => McInstancesCompanion(
                id: id,
                name: name,
                versionId: versionId,
                loader: loader,
                loaderVersion: loaderVersion,
                iconPath: iconPath,
                minMemoryMb: minMemoryMb,
                maxMemoryMb: maxMemoryMb,
                jvmArgs: jvmArgs,
                javaPath: javaPath,
                resolutionWidth: resolutionWidth,
                resolutionHeight: resolutionHeight,
                fullscreen: fullscreen,
                createdAt: createdAt,
                lastPlayedAt: lastPlayedAt,
                totalPlayTimeSeconds: totalPlayTimeSeconds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String versionId,
                Value<String> loader = const Value.absent(),
                Value<String?> loaderVersion = const Value.absent(),
                Value<String?> iconPath = const Value.absent(),
                Value<int> minMemoryMb = const Value.absent(),
                Value<int> maxMemoryMb = const Value.absent(),
                Value<String?> jvmArgs = const Value.absent(),
                Value<String?> javaPath = const Value.absent(),
                Value<int> resolutionWidth = const Value.absent(),
                Value<int> resolutionHeight = const Value.absent(),
                Value<bool> fullscreen = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> totalPlayTimeSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => McInstancesCompanion.insert(
                id: id,
                name: name,
                versionId: versionId,
                loader: loader,
                loaderVersion: loaderVersion,
                iconPath: iconPath,
                minMemoryMb: minMemoryMb,
                maxMemoryMb: maxMemoryMb,
                jvmArgs: jvmArgs,
                javaPath: javaPath,
                resolutionWidth: resolutionWidth,
                resolutionHeight: resolutionHeight,
                fullscreen: fullscreen,
                createdAt: createdAt,
                lastPlayedAt: lastPlayedAt,
                totalPlayTimeSeconds: totalPlayTimeSeconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$McInstancesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({mcLaunchHistoryRefs = false, mcInstalledModsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mcLaunchHistoryRefs) db.mcLaunchHistory,
                    if (mcInstalledModsRefs) db.mcInstalledMods,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mcLaunchHistoryRefs)
                        await $_getPrefetchedData<
                          McInstance,
                          $McInstancesTable,
                          McLaunchHistoryData
                        >(
                          currentTable: table,
                          referencedTable: $$McInstancesTableReferences
                              ._mcLaunchHistoryRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$McInstancesTableReferences(
                                db,
                                table,
                                p0,
                              ).mcLaunchHistoryRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.instanceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (mcInstalledModsRefs)
                        await $_getPrefetchedData<
                          McInstance,
                          $McInstancesTable,
                          McInstalledMod
                        >(
                          currentTable: table,
                          referencedTable: $$McInstancesTableReferences
                              ._mcInstalledModsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$McInstancesTableReferences(
                                db,
                                table,
                                p0,
                              ).mcInstalledModsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.instanceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$McInstancesTableProcessedTableManager =
    ProcessedTableManager<
      _$MinecraftLauncherDatabase,
      $McInstancesTable,
      McInstance,
      $$McInstancesTableFilterComposer,
      $$McInstancesTableOrderingComposer,
      $$McInstancesTableAnnotationComposer,
      $$McInstancesTableCreateCompanionBuilder,
      $$McInstancesTableUpdateCompanionBuilder,
      (McInstance, $$McInstancesTableReferences),
      McInstance,
      PrefetchHooks Function({
        bool mcLaunchHistoryRefs,
        bool mcInstalledModsRefs,
      })
    >;
typedef $$McLaunchHistoryTableCreateCompanionBuilder =
    McLaunchHistoryCompanion Function({
      Value<int> id,
      required String instanceId,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<int?> exitCode,
      Value<String?> logFilePath,
    });
typedef $$McLaunchHistoryTableUpdateCompanionBuilder =
    McLaunchHistoryCompanion Function({
      Value<int> id,
      Value<String> instanceId,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int?> exitCode,
      Value<String?> logFilePath,
    });

final class $$McLaunchHistoryTableReferences
    extends
        BaseReferences<
          _$MinecraftLauncherDatabase,
          $McLaunchHistoryTable,
          McLaunchHistoryData
        > {
  $$McLaunchHistoryTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $McInstancesTable _instanceIdTable(_$MinecraftLauncherDatabase db) =>
      db.mcInstances.createAlias(
        'mc_launch_history__instance_id__mc_instances__id',
      );

  $$McInstancesTableProcessedTableManager get instanceId {
    final $_column = $_itemColumn<String>('instance_id')!;

    final manager = $$McInstancesTableTableManager(
      $_db,
      $_db.mcInstances,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_instanceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$McLaunchHistoryTableFilterComposer
    extends Composer<_$MinecraftLauncherDatabase, $McLaunchHistoryTable> {
  $$McLaunchHistoryTableFilterComposer({
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

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exitCode => $composableBuilder(
    column: $table.exitCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logFilePath => $composableBuilder(
    column: $table.logFilePath,
    builder: (column) => ColumnFilters(column),
  );

  $$McInstancesTableFilterComposer get instanceId {
    final $$McInstancesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.mcInstances,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McInstancesTableFilterComposer(
            $db: $db,
            $table: $db.mcInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$McLaunchHistoryTableOrderingComposer
    extends Composer<_$MinecraftLauncherDatabase, $McLaunchHistoryTable> {
  $$McLaunchHistoryTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exitCode => $composableBuilder(
    column: $table.exitCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logFilePath => $composableBuilder(
    column: $table.logFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  $$McInstancesTableOrderingComposer get instanceId {
    final $$McInstancesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.mcInstances,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McInstancesTableOrderingComposer(
            $db: $db,
            $table: $db.mcInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$McLaunchHistoryTableAnnotationComposer
    extends Composer<_$MinecraftLauncherDatabase, $McLaunchHistoryTable> {
  $$McLaunchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get exitCode =>
      $composableBuilder(column: $table.exitCode, builder: (column) => column);

  GeneratedColumn<String> get logFilePath => $composableBuilder(
    column: $table.logFilePath,
    builder: (column) => column,
  );

  $$McInstancesTableAnnotationComposer get instanceId {
    final $$McInstancesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.mcInstances,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McInstancesTableAnnotationComposer(
            $db: $db,
            $table: $db.mcInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$McLaunchHistoryTableTableManager
    extends
        RootTableManager<
          _$MinecraftLauncherDatabase,
          $McLaunchHistoryTable,
          McLaunchHistoryData,
          $$McLaunchHistoryTableFilterComposer,
          $$McLaunchHistoryTableOrderingComposer,
          $$McLaunchHistoryTableAnnotationComposer,
          $$McLaunchHistoryTableCreateCompanionBuilder,
          $$McLaunchHistoryTableUpdateCompanionBuilder,
          (McLaunchHistoryData, $$McLaunchHistoryTableReferences),
          McLaunchHistoryData,
          PrefetchHooks Function({bool instanceId})
        > {
  $$McLaunchHistoryTableTableManager(
    _$MinecraftLauncherDatabase db,
    $McLaunchHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$McLaunchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$McLaunchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$McLaunchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> instanceId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int?> exitCode = const Value.absent(),
                Value<String?> logFilePath = const Value.absent(),
              }) => McLaunchHistoryCompanion(
                id: id,
                instanceId: instanceId,
                startedAt: startedAt,
                endedAt: endedAt,
                exitCode: exitCode,
                logFilePath: logFilePath,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String instanceId,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int?> exitCode = const Value.absent(),
                Value<String?> logFilePath = const Value.absent(),
              }) => McLaunchHistoryCompanion.insert(
                id: id,
                instanceId: instanceId,
                startedAt: startedAt,
                endedAt: endedAt,
                exitCode: exitCode,
                logFilePath: logFilePath,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$McLaunchHistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({instanceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (instanceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.instanceId,
                                referencedTable:
                                    $$McLaunchHistoryTableReferences
                                        ._instanceIdTable(db),
                                referencedColumn:
                                    $$McLaunchHistoryTableReferences
                                        ._instanceIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$McLaunchHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$MinecraftLauncherDatabase,
      $McLaunchHistoryTable,
      McLaunchHistoryData,
      $$McLaunchHistoryTableFilterComposer,
      $$McLaunchHistoryTableOrderingComposer,
      $$McLaunchHistoryTableAnnotationComposer,
      $$McLaunchHistoryTableCreateCompanionBuilder,
      $$McLaunchHistoryTableUpdateCompanionBuilder,
      (McLaunchHistoryData, $$McLaunchHistoryTableReferences),
      McLaunchHistoryData,
      PrefetchHooks Function({bool instanceId})
    >;
typedef $$McInstalledModsTableCreateCompanionBuilder =
    McInstalledModsCompanion Function({
      Value<int> id,
      required String instanceId,
      Value<String?> projectId,
      Value<String?> versionId,
      Value<String?> projectName,
      Value<String?> projectIconUrl,
      required String fileName,
      Value<String?> sha1,
      Value<bool> enabled,
      Value<String> kind,
      Value<DateTime> installedAt,
    });
typedef $$McInstalledModsTableUpdateCompanionBuilder =
    McInstalledModsCompanion Function({
      Value<int> id,
      Value<String> instanceId,
      Value<String?> projectId,
      Value<String?> versionId,
      Value<String?> projectName,
      Value<String?> projectIconUrl,
      Value<String> fileName,
      Value<String?> sha1,
      Value<bool> enabled,
      Value<String> kind,
      Value<DateTime> installedAt,
    });

final class $$McInstalledModsTableReferences
    extends
        BaseReferences<
          _$MinecraftLauncherDatabase,
          $McInstalledModsTable,
          McInstalledMod
        > {
  $$McInstalledModsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $McInstancesTable _instanceIdTable(_$MinecraftLauncherDatabase db) =>
      db.mcInstances.createAlias(
        'mc_installed_mods__instance_id__mc_instances__id',
      );

  $$McInstancesTableProcessedTableManager get instanceId {
    final $_column = $_itemColumn<String>('instance_id')!;

    final manager = $$McInstancesTableTableManager(
      $_db,
      $_db.mcInstances,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_instanceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$McInstalledModsTableFilterComposer
    extends Composer<_$MinecraftLauncherDatabase, $McInstalledModsTable> {
  $$McInstalledModsTableFilterComposer({
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

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectName => $composableBuilder(
    column: $table.projectName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectIconUrl => $composableBuilder(
    column: $table.projectIconUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha1 => $composableBuilder(
    column: $table.sha1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$McInstancesTableFilterComposer get instanceId {
    final $$McInstancesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.mcInstances,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McInstancesTableFilterComposer(
            $db: $db,
            $table: $db.mcInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$McInstalledModsTableOrderingComposer
    extends Composer<_$MinecraftLauncherDatabase, $McInstalledModsTable> {
  $$McInstalledModsTableOrderingComposer({
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

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectName => $composableBuilder(
    column: $table.projectName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectIconUrl => $composableBuilder(
    column: $table.projectIconUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha1 => $composableBuilder(
    column: $table.sha1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$McInstancesTableOrderingComposer get instanceId {
    final $$McInstancesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.mcInstances,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McInstancesTableOrderingComposer(
            $db: $db,
            $table: $db.mcInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$McInstalledModsTableAnnotationComposer
    extends Composer<_$MinecraftLauncherDatabase, $McInstalledModsTable> {
  $$McInstalledModsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<String> get projectName => $composableBuilder(
    column: $table.projectName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get projectIconUrl => $composableBuilder(
    column: $table.projectIconUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get sha1 =>
      $composableBuilder(column: $table.sha1, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );

  $$McInstancesTableAnnotationComposer get instanceId {
    final $$McInstancesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.instanceId,
      referencedTable: $db.mcInstances,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$McInstancesTableAnnotationComposer(
            $db: $db,
            $table: $db.mcInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$McInstalledModsTableTableManager
    extends
        RootTableManager<
          _$MinecraftLauncherDatabase,
          $McInstalledModsTable,
          McInstalledMod,
          $$McInstalledModsTableFilterComposer,
          $$McInstalledModsTableOrderingComposer,
          $$McInstalledModsTableAnnotationComposer,
          $$McInstalledModsTableCreateCompanionBuilder,
          $$McInstalledModsTableUpdateCompanionBuilder,
          (McInstalledMod, $$McInstalledModsTableReferences),
          McInstalledMod,
          PrefetchHooks Function({bool instanceId})
        > {
  $$McInstalledModsTableTableManager(
    _$MinecraftLauncherDatabase db,
    $McInstalledModsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$McInstalledModsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$McInstalledModsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$McInstalledModsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> instanceId = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<String?> versionId = const Value.absent(),
                Value<String?> projectName = const Value.absent(),
                Value<String?> projectIconUrl = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String?> sha1 = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
              }) => McInstalledModsCompanion(
                id: id,
                instanceId: instanceId,
                projectId: projectId,
                versionId: versionId,
                projectName: projectName,
                projectIconUrl: projectIconUrl,
                fileName: fileName,
                sha1: sha1,
                enabled: enabled,
                kind: kind,
                installedAt: installedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String instanceId,
                Value<String?> projectId = const Value.absent(),
                Value<String?> versionId = const Value.absent(),
                Value<String?> projectName = const Value.absent(),
                Value<String?> projectIconUrl = const Value.absent(),
                required String fileName,
                Value<String?> sha1 = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
              }) => McInstalledModsCompanion.insert(
                id: id,
                instanceId: instanceId,
                projectId: projectId,
                versionId: versionId,
                projectName: projectName,
                projectIconUrl: projectIconUrl,
                fileName: fileName,
                sha1: sha1,
                enabled: enabled,
                kind: kind,
                installedAt: installedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$McInstalledModsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({instanceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (instanceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.instanceId,
                                referencedTable:
                                    $$McInstalledModsTableReferences
                                        ._instanceIdTable(db),
                                referencedColumn:
                                    $$McInstalledModsTableReferences
                                        ._instanceIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$McInstalledModsTableProcessedTableManager =
    ProcessedTableManager<
      _$MinecraftLauncherDatabase,
      $McInstalledModsTable,
      McInstalledMod,
      $$McInstalledModsTableFilterComposer,
      $$McInstalledModsTableOrderingComposer,
      $$McInstalledModsTableAnnotationComposer,
      $$McInstalledModsTableCreateCompanionBuilder,
      $$McInstalledModsTableUpdateCompanionBuilder,
      (McInstalledMod, $$McInstalledModsTableReferences),
      McInstalledMod,
      PrefetchHooks Function({bool instanceId})
    >;

class $MinecraftLauncherDatabaseManager {
  final _$MinecraftLauncherDatabase _db;
  $MinecraftLauncherDatabaseManager(this._db);
  $$McAccountsTableTableManager get mcAccounts =>
      $$McAccountsTableTableManager(_db, _db.mcAccounts);
  $$McInstancesTableTableManager get mcInstances =>
      $$McInstancesTableTableManager(_db, _db.mcInstances);
  $$McLaunchHistoryTableTableManager get mcLaunchHistory =>
      $$McLaunchHistoryTableTableManager(_db, _db.mcLaunchHistory);
  $$McInstalledModsTableTableManager get mcInstalledMods =>
      $$McInstalledModsTableTableManager(_db, _db.mcInstalledMods);
}
