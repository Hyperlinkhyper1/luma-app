// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'usage_database.dart';

// ignore_for_file: type=lint
class $UsageSessionsTable extends UsageSessions
    with TableInfo<$UsageSessionsTable, UsageSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageSessionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _appNameMeta = const VerificationMeta(
    'appName',
  );
  @override
  late final GeneratedColumn<String> appName = GeneratedColumn<String>(
    'app_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _processNameMeta = const VerificationMeta(
    'processName',
  );
  @override
  late final GeneratedColumn<String> processName = GeneratedColumn<String>(
    'process_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _windowTitleMeta = const VerificationMeta(
    'windowTitle',
  );
  @override
  late final GeneratedColumn<String> windowTitle = GeneratedColumn<String>(
    'window_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    appName,
    processName,
    windowTitle,
    startedAt,
    endedAt,
    durationSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('app_name')) {
      context.handle(
        _appNameMeta,
        appName.isAcceptableOrUnknown(data['app_name']!, _appNameMeta),
      );
    } else if (isInserting) {
      context.missing(_appNameMeta);
    }
    if (data.containsKey('process_name')) {
      context.handle(
        _processNameMeta,
        processName.isAcceptableOrUnknown(
          data['process_name']!,
          _processNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_processNameMeta);
    }
    if (data.containsKey('window_title')) {
      context.handle(
        _windowTitleMeta,
        windowTitle.isAcceptableOrUnknown(
          data['window_title']!,
          _windowTitleMeta,
        ),
      );
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
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UsageSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      appName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_name'],
      )!,
      processName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}process_name'],
      )!,
      windowTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}window_title'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
    );
  }

  @override
  $UsageSessionsTable createAlias(String alias) {
    return $UsageSessionsTable(attachedDatabase, alias);
  }
}

class UsageSession extends DataClass implements Insertable<UsageSession> {
  final int id;
  final String appName;
  final String processName;
  final String? windowTitle;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  const UsageSession({
    required this.id,
    required this.appName,
    required this.processName,
    this.windowTitle,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['app_name'] = Variable<String>(appName);
    map['process_name'] = Variable<String>(processName);
    if (!nullToAbsent || windowTitle != null) {
      map['window_title'] = Variable<String>(windowTitle);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ended_at'] = Variable<DateTime>(endedAt);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    return map;
  }

  UsageSessionsCompanion toCompanion(bool nullToAbsent) {
    return UsageSessionsCompanion(
      id: Value(id),
      appName: Value(appName),
      processName: Value(processName),
      windowTitle: windowTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(windowTitle),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      durationSeconds: Value(durationSeconds),
    );
  }

  factory UsageSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageSession(
      id: serializer.fromJson<int>(json['id']),
      appName: serializer.fromJson<String>(json['appName']),
      processName: serializer.fromJson<String>(json['processName']),
      windowTitle: serializer.fromJson<String?>(json['windowTitle']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'appName': serializer.toJson<String>(appName),
      'processName': serializer.toJson<String>(processName),
      'windowTitle': serializer.toJson<String?>(windowTitle),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
    };
  }

  UsageSession copyWith({
    int? id,
    String? appName,
    String? processName,
    Value<String?> windowTitle = const Value.absent(),
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) => UsageSession(
    id: id ?? this.id,
    appName: appName ?? this.appName,
    processName: processName ?? this.processName,
    windowTitle: windowTitle.present ? windowTitle.value : this.windowTitle,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
  );
  UsageSession copyWithCompanion(UsageSessionsCompanion data) {
    return UsageSession(
      id: data.id.present ? data.id.value : this.id,
      appName: data.appName.present ? data.appName.value : this.appName,
      processName: data.processName.present
          ? data.processName.value
          : this.processName,
      windowTitle: data.windowTitle.present
          ? data.windowTitle.value
          : this.windowTitle,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageSession(')
          ..write('id: $id, ')
          ..write('appName: $appName, ')
          ..write('processName: $processName, ')
          ..write('windowTitle: $windowTitle, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    appName,
    processName,
    windowTitle,
    startedAt,
    endedAt,
    durationSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageSession &&
          other.id == this.id &&
          other.appName == this.appName &&
          other.processName == this.processName &&
          other.windowTitle == this.windowTitle &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.durationSeconds == this.durationSeconds);
}

class UsageSessionsCompanion extends UpdateCompanion<UsageSession> {
  final Value<int> id;
  final Value<String> appName;
  final Value<String> processName;
  final Value<String?> windowTitle;
  final Value<DateTime> startedAt;
  final Value<DateTime> endedAt;
  final Value<int> durationSeconds;
  const UsageSessionsCompanion({
    this.id = const Value.absent(),
    this.appName = const Value.absent(),
    this.processName = const Value.absent(),
    this.windowTitle = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
  });
  UsageSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String appName,
    required String processName,
    this.windowTitle = const Value.absent(),
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
  }) : appName = Value(appName),
       processName = Value(processName),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt),
       durationSeconds = Value(durationSeconds);
  static Insertable<UsageSession> custom({
    Expression<int>? id,
    Expression<String>? appName,
    Expression<String>? processName,
    Expression<String>? windowTitle,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? durationSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (appName != null) 'app_name': appName,
      if (processName != null) 'process_name': processName,
      if (windowTitle != null) 'window_title': windowTitle,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    });
  }

  UsageSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? appName,
    Value<String>? processName,
    Value<String?>? windowTitle,
    Value<DateTime>? startedAt,
    Value<DateTime>? endedAt,
    Value<int>? durationSeconds,
  }) {
    return UsageSessionsCompanion(
      id: id ?? this.id,
      appName: appName ?? this.appName,
      processName: processName ?? this.processName,
      windowTitle: windowTitle ?? this.windowTitle,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (appName.present) {
      map['app_name'] = Variable<String>(appName.value);
    }
    if (processName.present) {
      map['process_name'] = Variable<String>(processName.value);
    }
    if (windowTitle.present) {
      map['window_title'] = Variable<String>(windowTitle.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageSessionsCompanion(')
          ..write('id: $id, ')
          ..write('appName: $appName, ')
          ..write('processName: $processName, ')
          ..write('windowTitle: $windowTitle, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds')
          ..write(')'))
        .toString();
  }
}

abstract class _$UsageDatabase extends GeneratedDatabase {
  _$UsageDatabase(QueryExecutor e) : super(e);
  $UsageDatabaseManager get managers => $UsageDatabaseManager(this);
  late final $UsageSessionsTable usageSessions = $UsageSessionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [usageSessions];
}

typedef $$UsageSessionsTableCreateCompanionBuilder =
    UsageSessionsCompanion Function({
      Value<int> id,
      required String appName,
      required String processName,
      Value<String?> windowTitle,
      required DateTime startedAt,
      required DateTime endedAt,
      required int durationSeconds,
    });
typedef $$UsageSessionsTableUpdateCompanionBuilder =
    UsageSessionsCompanion Function({
      Value<int> id,
      Value<String> appName,
      Value<String> processName,
      Value<String?> windowTitle,
      Value<DateTime> startedAt,
      Value<DateTime> endedAt,
      Value<int> durationSeconds,
    });

class $$UsageSessionsTableFilterComposer
    extends Composer<_$UsageDatabase, $UsageSessionsTable> {
  $$UsageSessionsTableFilterComposer({
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

  ColumnFilters<String> get appName => $composableBuilder(
    column: $table.appName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processName => $composableBuilder(
    column: $table.processName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get windowTitle => $composableBuilder(
    column: $table.windowTitle,
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

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsageSessionsTableOrderingComposer
    extends Composer<_$UsageDatabase, $UsageSessionsTable> {
  $$UsageSessionsTableOrderingComposer({
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

  ColumnOrderings<String> get appName => $composableBuilder(
    column: $table.appName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processName => $composableBuilder(
    column: $table.processName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get windowTitle => $composableBuilder(
    column: $table.windowTitle,
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

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsageSessionsTableAnnotationComposer
    extends Composer<_$UsageDatabase, $UsageSessionsTable> {
  $$UsageSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get appName =>
      $composableBuilder(column: $table.appName, builder: (column) => column);

  GeneratedColumn<String> get processName => $composableBuilder(
    column: $table.processName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get windowTitle => $composableBuilder(
    column: $table.windowTitle,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );
}

class $$UsageSessionsTableTableManager
    extends
        RootTableManager<
          _$UsageDatabase,
          $UsageSessionsTable,
          UsageSession,
          $$UsageSessionsTableFilterComposer,
          $$UsageSessionsTableOrderingComposer,
          $$UsageSessionsTableAnnotationComposer,
          $$UsageSessionsTableCreateCompanionBuilder,
          $$UsageSessionsTableUpdateCompanionBuilder,
          (
            UsageSession,
            BaseReferences<_$UsageDatabase, $UsageSessionsTable, UsageSession>,
          ),
          UsageSession,
          PrefetchHooks Function()
        > {
  $$UsageSessionsTableTableManager(
    _$UsageDatabase db,
    $UsageSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsageSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsageSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> appName = const Value.absent(),
                Value<String> processName = const Value.absent(),
                Value<String?> windowTitle = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
              }) => UsageSessionsCompanion(
                id: id,
                appName: appName,
                processName: processName,
                windowTitle: windowTitle,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String appName,
                required String processName,
                Value<String?> windowTitle = const Value.absent(),
                required DateTime startedAt,
                required DateTime endedAt,
                required int durationSeconds,
              }) => UsageSessionsCompanion.insert(
                id: id,
                appName: appName,
                processName: processName,
                windowTitle: windowTitle,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsageSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$UsageDatabase,
      $UsageSessionsTable,
      UsageSession,
      $$UsageSessionsTableFilterComposer,
      $$UsageSessionsTableOrderingComposer,
      $$UsageSessionsTableAnnotationComposer,
      $$UsageSessionsTableCreateCompanionBuilder,
      $$UsageSessionsTableUpdateCompanionBuilder,
      (
        UsageSession,
        BaseReferences<_$UsageDatabase, $UsageSessionsTable, UsageSession>,
      ),
      UsageSession,
      PrefetchHooks Function()
    >;

class $UsageDatabaseManager {
  final _$UsageDatabase _db;
  $UsageDatabaseManager(this._db);
  $$UsageSessionsTableTableManager get usageSessions =>
      $$UsageSessionsTableTableManager(_db, _db.usageSessions);
}
