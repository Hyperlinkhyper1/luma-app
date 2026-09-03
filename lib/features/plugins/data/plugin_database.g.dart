// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_database.dart';

// ignore_for_file: type=lint
class $InstalledPluginsTable extends InstalledPlugins
    with TableInfo<$InstalledPluginsTable, InstalledPlugin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstalledPluginsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _pluginIdMeta = const VerificationMeta(
    'pluginId',
  );
  @override
  late final GeneratedColumn<String> pluginId = GeneratedColumn<String>(
    'plugin_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
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
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('extension'),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('1.0.0'),
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
  static const VerificationMeta _downloadCountMeta = const VerificationMeta(
    'downloadCount',
  );
  @override
  late final GeneratedColumn<int> downloadCount = GeneratedColumn<int>(
    'download_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pluginId,
    name,
    icon,
    version,
    installedAt,
    downloadCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'installed_plugins';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstalledPlugin> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('plugin_id')) {
      context.handle(
        _pluginIdMeta,
        pluginId.isAcceptableOrUnknown(data['plugin_id']!, _pluginIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pluginIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
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
    if (data.containsKey('download_count')) {
      context.handle(
        _downloadCountMeta,
        downloadCount.isAcceptableOrUnknown(
          data['download_count']!,
          _downloadCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstalledPlugin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstalledPlugin(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
      downloadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download_count'],
      )!,
    );
  }

  @override
  $InstalledPluginsTable createAlias(String alias) {
    return $InstalledPluginsTable(attachedDatabase, alias);
  }
}

class InstalledPlugin extends DataClass implements Insertable<InstalledPlugin> {
  final int id;
  final String pluginId;
  final String name;
  final String icon;
  final String version;
  final DateTime installedAt;
  final int downloadCount;
  const InstalledPlugin({
    required this.id,
    required this.pluginId,
    required this.name,
    required this.icon,
    required this.version,
    required this.installedAt,
    required this.downloadCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['plugin_id'] = Variable<String>(pluginId);
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['version'] = Variable<String>(version);
    map['installed_at'] = Variable<DateTime>(installedAt);
    map['download_count'] = Variable<int>(downloadCount);
    return map;
  }

  InstalledPluginsCompanion toCompanion(bool nullToAbsent) {
    return InstalledPluginsCompanion(
      id: Value(id),
      pluginId: Value(pluginId),
      name: Value(name),
      icon: Value(icon),
      version: Value(version),
      installedAt: Value(installedAt),
      downloadCount: Value(downloadCount),
    );
  }

  factory InstalledPlugin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstalledPlugin(
      id: serializer.fromJson<int>(json['id']),
      pluginId: serializer.fromJson<String>(json['pluginId']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      version: serializer.fromJson<String>(json['version']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
      downloadCount: serializer.fromJson<int>(json['downloadCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'pluginId': serializer.toJson<String>(pluginId),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'version': serializer.toJson<String>(version),
      'installedAt': serializer.toJson<DateTime>(installedAt),
      'downloadCount': serializer.toJson<int>(downloadCount),
    };
  }

  InstalledPlugin copyWith({
    int? id,
    String? pluginId,
    String? name,
    String? icon,
    String? version,
    DateTime? installedAt,
    int? downloadCount,
  }) => InstalledPlugin(
    id: id ?? this.id,
    pluginId: pluginId ?? this.pluginId,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    version: version ?? this.version,
    installedAt: installedAt ?? this.installedAt,
    downloadCount: downloadCount ?? this.downloadCount,
  );
  InstalledPlugin copyWithCompanion(InstalledPluginsCompanion data) {
    return InstalledPlugin(
      id: data.id.present ? data.id.value : this.id,
      pluginId: data.pluginId.present ? data.pluginId.value : this.pluginId,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      version: data.version.present ? data.version.value : this.version,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
      downloadCount: data.downloadCount.present
          ? data.downloadCount.value
          : this.downloadCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstalledPlugin(')
          ..write('id: $id, ')
          ..write('pluginId: $pluginId, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('version: $version, ')
          ..write('installedAt: $installedAt, ')
          ..write('downloadCount: $downloadCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    pluginId,
    name,
    icon,
    version,
    installedAt,
    downloadCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstalledPlugin &&
          other.id == this.id &&
          other.pluginId == this.pluginId &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.version == this.version &&
          other.installedAt == this.installedAt &&
          other.downloadCount == this.downloadCount);
}

class InstalledPluginsCompanion extends UpdateCompanion<InstalledPlugin> {
  final Value<int> id;
  final Value<String> pluginId;
  final Value<String> name;
  final Value<String> icon;
  final Value<String> version;
  final Value<DateTime> installedAt;
  final Value<int> downloadCount;
  const InstalledPluginsCompanion({
    this.id = const Value.absent(),
    this.pluginId = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.version = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.downloadCount = const Value.absent(),
  });
  InstalledPluginsCompanion.insert({
    this.id = const Value.absent(),
    required String pluginId,
    required String name,
    this.icon = const Value.absent(),
    this.version = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.downloadCount = const Value.absent(),
  }) : pluginId = Value(pluginId),
       name = Value(name);
  static Insertable<InstalledPlugin> custom({
    Expression<int>? id,
    Expression<String>? pluginId,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<String>? version,
    Expression<DateTime>? installedAt,
    Expression<int>? downloadCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pluginId != null) 'plugin_id': pluginId,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (version != null) 'version': version,
      if (installedAt != null) 'installed_at': installedAt,
      if (downloadCount != null) 'download_count': downloadCount,
    });
  }

  InstalledPluginsCompanion copyWith({
    Value<int>? id,
    Value<String>? pluginId,
    Value<String>? name,
    Value<String>? icon,
    Value<String>? version,
    Value<DateTime>? installedAt,
    Value<int>? downloadCount,
  }) {
    return InstalledPluginsCompanion(
      id: id ?? this.id,
      pluginId: pluginId ?? this.pluginId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      version: version ?? this.version,
      installedAt: installedAt ?? this.installedAt,
      downloadCount: downloadCount ?? this.downloadCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (downloadCount.present) {
      map['download_count'] = Variable<int>(downloadCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstalledPluginsCompanion(')
          ..write('id: $id, ')
          ..write('pluginId: $pluginId, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('version: $version, ')
          ..write('installedAt: $installedAt, ')
          ..write('downloadCount: $downloadCount')
          ..write(')'))
        .toString();
  }
}

abstract class _$PluginDatabase extends GeneratedDatabase {
  _$PluginDatabase(QueryExecutor e) : super(e);
  $PluginDatabaseManager get managers => $PluginDatabaseManager(this);
  late final $InstalledPluginsTable installedPlugins = $InstalledPluginsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [installedPlugins];
}

typedef $$InstalledPluginsTableCreateCompanionBuilder =
    InstalledPluginsCompanion Function({
      Value<int> id,
      required String pluginId,
      required String name,
      Value<String> icon,
      Value<String> version,
      Value<DateTime> installedAt,
      Value<int> downloadCount,
    });
typedef $$InstalledPluginsTableUpdateCompanionBuilder =
    InstalledPluginsCompanion Function({
      Value<int> id,
      Value<String> pluginId,
      Value<String> name,
      Value<String> icon,
      Value<String> version,
      Value<DateTime> installedAt,
      Value<int> downloadCount,
    });

class $$InstalledPluginsTableFilterComposer
    extends Composer<_$PluginDatabase, $InstalledPluginsTable> {
  $$InstalledPluginsTableFilterComposer({
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

  ColumnFilters<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadCount => $composableBuilder(
    column: $table.downloadCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InstalledPluginsTableOrderingComposer
    extends Composer<_$PluginDatabase, $InstalledPluginsTable> {
  $$InstalledPluginsTableOrderingComposer({
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

  ColumnOrderings<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadCount => $composableBuilder(
    column: $table.downloadCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstalledPluginsTableAnnotationComposer
    extends Composer<_$PluginDatabase, $InstalledPluginsTable> {
  $$InstalledPluginsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pluginId =>
      $composableBuilder(column: $table.pluginId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadCount => $composableBuilder(
    column: $table.downloadCount,
    builder: (column) => column,
  );
}

class $$InstalledPluginsTableTableManager
    extends
        RootTableManager<
          _$PluginDatabase,
          $InstalledPluginsTable,
          InstalledPlugin,
          $$InstalledPluginsTableFilterComposer,
          $$InstalledPluginsTableOrderingComposer,
          $$InstalledPluginsTableAnnotationComposer,
          $$InstalledPluginsTableCreateCompanionBuilder,
          $$InstalledPluginsTableUpdateCompanionBuilder,
          (
            InstalledPlugin,
            BaseReferences<
              _$PluginDatabase,
              $InstalledPluginsTable,
              InstalledPlugin
            >,
          ),
          InstalledPlugin,
          PrefetchHooks Function()
        > {
  $$InstalledPluginsTableTableManager(
    _$PluginDatabase db,
    $InstalledPluginsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstalledPluginsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InstalledPluginsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InstalledPluginsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> pluginId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> downloadCount = const Value.absent(),
              }) => InstalledPluginsCompanion(
                id: id,
                pluginId: pluginId,
                name: name,
                icon: icon,
                version: version,
                installedAt: installedAt,
                downloadCount: downloadCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String pluginId,
                required String name,
                Value<String> icon = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> downloadCount = const Value.absent(),
              }) => InstalledPluginsCompanion.insert(
                id: id,
                pluginId: pluginId,
                name: name,
                icon: icon,
                version: version,
                installedAt: installedAt,
                downloadCount: downloadCount,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InstalledPluginsTableProcessedTableManager =
    ProcessedTableManager<
      _$PluginDatabase,
      $InstalledPluginsTable,
      InstalledPlugin,
      $$InstalledPluginsTableFilterComposer,
      $$InstalledPluginsTableOrderingComposer,
      $$InstalledPluginsTableAnnotationComposer,
      $$InstalledPluginsTableCreateCompanionBuilder,
      $$InstalledPluginsTableUpdateCompanionBuilder,
      (
        InstalledPlugin,
        BaseReferences<
          _$PluginDatabase,
          $InstalledPluginsTable,
          InstalledPlugin
        >,
      ),
      InstalledPlugin,
      PrefetchHooks Function()
    >;

class $PluginDatabaseManager {
  final _$PluginDatabase _db;
  $PluginDatabaseManager(this._db);
  $$InstalledPluginsTableTableManager get installedPlugins =>
      $$InstalledPluginsTableTableManager(_db, _db.installedPlugins);
}
