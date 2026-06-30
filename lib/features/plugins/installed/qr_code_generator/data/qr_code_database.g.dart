// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_code_database.dart';

// ignore_for_file: type=lint
class $QrCodeEntriesTable extends QrCodeEntries
    with TableInfo<$QrCodeEntriesTable, QrCodeEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QrCodeEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 2000,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  List<GeneratedColumn> get $columns => [id, url, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'qr_code_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<QrCodeEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
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
  QrCodeEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QrCodeEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $QrCodeEntriesTable createAlias(String alias) {
    return $QrCodeEntriesTable(attachedDatabase, alias);
  }
}

class QrCodeEntry extends DataClass implements Insertable<QrCodeEntry> {
  final int id;
  final String url;
  final DateTime createdAt;
  const QrCodeEntry({
    required this.id,
    required this.url,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['url'] = Variable<String>(url);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  QrCodeEntriesCompanion toCompanion(bool nullToAbsent) {
    return QrCodeEntriesCompanion(
      id: Value(id),
      url: Value(url),
      createdAt: Value(createdAt),
    );
  }

  factory QrCodeEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QrCodeEntry(
      id: serializer.fromJson<int>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'url': serializer.toJson<String>(url),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  QrCodeEntry copyWith({int? id, String? url, DateTime? createdAt}) =>
      QrCodeEntry(
        id: id ?? this.id,
        url: url ?? this.url,
        createdAt: createdAt ?? this.createdAt,
      );
  QrCodeEntry copyWithCompanion(QrCodeEntriesCompanion data) {
    return QrCodeEntry(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QrCodeEntry(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, url, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QrCodeEntry &&
          other.id == this.id &&
          other.url == this.url &&
          other.createdAt == this.createdAt);
}

class QrCodeEntriesCompanion extends UpdateCompanion<QrCodeEntry> {
  final Value<int> id;
  final Value<String> url;
  final Value<DateTime> createdAt;
  const QrCodeEntriesCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  QrCodeEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String url,
    this.createdAt = const Value.absent(),
  }) : url = Value(url);
  static Insertable<QrCodeEntry> custom({
    Expression<int>? id,
    Expression<String>? url,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  QrCodeEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? url,
    Value<DateTime>? createdAt,
  }) {
    return QrCodeEntriesCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QrCodeEntriesCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$QrCodeDatabase extends GeneratedDatabase {
  _$QrCodeDatabase(QueryExecutor e) : super(e);
  $QrCodeDatabaseManager get managers => $QrCodeDatabaseManager(this);
  late final $QrCodeEntriesTable qrCodeEntries = $QrCodeEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [qrCodeEntries];
}

typedef $$QrCodeEntriesTableCreateCompanionBuilder =
    QrCodeEntriesCompanion Function({
      Value<int> id,
      required String url,
      Value<DateTime> createdAt,
    });
typedef $$QrCodeEntriesTableUpdateCompanionBuilder =
    QrCodeEntriesCompanion Function({
      Value<int> id,
      Value<String> url,
      Value<DateTime> createdAt,
    });

class $$QrCodeEntriesTableFilterComposer
    extends Composer<_$QrCodeDatabase, $QrCodeEntriesTable> {
  $$QrCodeEntriesTableFilterComposer({
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

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QrCodeEntriesTableOrderingComposer
    extends Composer<_$QrCodeDatabase, $QrCodeEntriesTable> {
  $$QrCodeEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QrCodeEntriesTableAnnotationComposer
    extends Composer<_$QrCodeDatabase, $QrCodeEntriesTable> {
  $$QrCodeEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$QrCodeEntriesTableTableManager
    extends
        RootTableManager<
          _$QrCodeDatabase,
          $QrCodeEntriesTable,
          QrCodeEntry,
          $$QrCodeEntriesTableFilterComposer,
          $$QrCodeEntriesTableOrderingComposer,
          $$QrCodeEntriesTableAnnotationComposer,
          $$QrCodeEntriesTableCreateCompanionBuilder,
          $$QrCodeEntriesTableUpdateCompanionBuilder,
          (
            QrCodeEntry,
            BaseReferences<_$QrCodeDatabase, $QrCodeEntriesTable, QrCodeEntry>,
          ),
          QrCodeEntry,
          PrefetchHooks Function()
        > {
  $$QrCodeEntriesTableTableManager(
    _$QrCodeDatabase db,
    $QrCodeEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QrCodeEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QrCodeEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QrCodeEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => QrCodeEntriesCompanion(
                id: id,
                url: url,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String url,
                Value<DateTime> createdAt = const Value.absent(),
              }) => QrCodeEntriesCompanion.insert(
                id: id,
                url: url,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QrCodeEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$QrCodeDatabase,
      $QrCodeEntriesTable,
      QrCodeEntry,
      $$QrCodeEntriesTableFilterComposer,
      $$QrCodeEntriesTableOrderingComposer,
      $$QrCodeEntriesTableAnnotationComposer,
      $$QrCodeEntriesTableCreateCompanionBuilder,
      $$QrCodeEntriesTableUpdateCompanionBuilder,
      (
        QrCodeEntry,
        BaseReferences<_$QrCodeDatabase, $QrCodeEntriesTable, QrCodeEntry>,
      ),
      QrCodeEntry,
      PrefetchHooks Function()
    >;

class $QrCodeDatabaseManager {
  final _$QrCodeDatabase _db;
  $QrCodeDatabaseManager(this._db);
  $$QrCodeEntriesTableTableManager get qrCodeEntries =>
      $$QrCodeEntriesTableTableManager(_db, _db.qrCodeEntries);
}
