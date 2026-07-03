// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_management_database.dart';

// ignore_for_file: type=lint
class $DataDatasetsTable extends DataDatasets
    with TableInfo<$DataDatasetsTable, DataDataset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DataDatasetsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _columnsJsonMeta = const VerificationMeta(
    'columnsJson',
  );
  @override
  late final GeneratedColumn<String> columnsJson = GeneratedColumn<String>(
    'columns_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
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
    name,
    columnsJson,
    tagsJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'data_datasets';
  @override
  VerificationContext validateIntegrity(
    Insertable<DataDataset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('columns_json')) {
      context.handle(
        _columnsJsonMeta,
        columnsJson.isAcceptableOrUnknown(
          data['columns_json']!,
          _columnsJsonMeta,
        ),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
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
  DataDataset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DataDataset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      columnsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}columns_json'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
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
  $DataDatasetsTable createAlias(String alias) {
    return $DataDatasetsTable(attachedDatabase, alias);
  }
}

class DataDataset extends DataClass implements Insertable<DataDataset> {
  final int id;
  final String name;
  final String columnsJson;
  final String tagsJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DataDataset({
    required this.id,
    required this.name,
    required this.columnsJson,
    required this.tagsJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['columns_json'] = Variable<String>(columnsJson);
    map['tags_json'] = Variable<String>(tagsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DataDatasetsCompanion toCompanion(bool nullToAbsent) {
    return DataDatasetsCompanion(
      id: Value(id),
      name: Value(name),
      columnsJson: Value(columnsJson),
      tagsJson: Value(tagsJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DataDataset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DataDataset(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      columnsJson: serializer.fromJson<String>(json['columnsJson']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'columnsJson': serializer.toJson<String>(columnsJson),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DataDataset copyWith({
    int? id,
    String? name,
    String? columnsJson,
    String? tagsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DataDataset(
    id: id ?? this.id,
    name: name ?? this.name,
    columnsJson: columnsJson ?? this.columnsJson,
    tagsJson: tagsJson ?? this.tagsJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DataDataset copyWithCompanion(DataDatasetsCompanion data) {
    return DataDataset(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      columnsJson: data.columnsJson.present
          ? data.columnsJson.value
          : this.columnsJson,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DataDataset(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('columnsJson: $columnsJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, columnsJson, tagsJson, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DataDataset &&
          other.id == this.id &&
          other.name == this.name &&
          other.columnsJson == this.columnsJson &&
          other.tagsJson == this.tagsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DataDatasetsCompanion extends UpdateCompanion<DataDataset> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> columnsJson;
  final Value<String> tagsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const DataDatasetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.columnsJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DataDatasetsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.columnsJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<DataDataset> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? columnsJson,
    Expression<String>? tagsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (columnsJson != null) 'columns_json': columnsJson,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DataDatasetsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? columnsJson,
    Value<String>? tagsJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return DataDatasetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      columnsJson: columnsJson ?? this.columnsJson,
      tagsJson: tagsJson ?? this.tagsJson,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (columnsJson.present) {
      map['columns_json'] = Variable<String>(columnsJson.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
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
    return (StringBuffer('DataDatasetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('columnsJson: $columnsJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DataRowsTable extends DataRows with TableInfo<$DataRowsTable, DataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DataRowsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _datasetIdMeta = const VerificationMeta(
    'datasetId',
  );
  @override
  late final GeneratedColumn<int> datasetId = GeneratedColumn<int>(
    'dataset_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valuesJsonMeta = const VerificationMeta(
    'valuesJson',
  );
  @override
  late final GeneratedColumn<String> valuesJson = GeneratedColumn<String>(
    'values_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    datasetId,
    valuesJson,
    tagsJson,
    orderIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'data_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<DataRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('dataset_id')) {
      context.handle(
        _datasetIdMeta,
        datasetId.isAcceptableOrUnknown(data['dataset_id']!, _datasetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_datasetIdMeta);
    }
    if (data.containsKey('values_json')) {
      context.handle(
        _valuesJsonMeta,
        valuesJson.isAcceptableOrUnknown(data['values_json']!, _valuesJsonMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DataRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      datasetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dataset_id'],
      )!,
      valuesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}values_json'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
    );
  }

  @override
  $DataRowsTable createAlias(String alias) {
    return $DataRowsTable(attachedDatabase, alias);
  }
}

class DataRow extends DataClass implements Insertable<DataRow> {
  final int id;
  final int datasetId;
  final String valuesJson;
  final String tagsJson;
  final int orderIndex;
  const DataRow({
    required this.id,
    required this.datasetId,
    required this.valuesJson,
    required this.tagsJson,
    required this.orderIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['dataset_id'] = Variable<int>(datasetId);
    map['values_json'] = Variable<String>(valuesJson);
    map['tags_json'] = Variable<String>(tagsJson);
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  DataRowsCompanion toCompanion(bool nullToAbsent) {
    return DataRowsCompanion(
      id: Value(id),
      datasetId: Value(datasetId),
      valuesJson: Value(valuesJson),
      tagsJson: Value(tagsJson),
      orderIndex: Value(orderIndex),
    );
  }

  factory DataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DataRow(
      id: serializer.fromJson<int>(json['id']),
      datasetId: serializer.fromJson<int>(json['datasetId']),
      valuesJson: serializer.fromJson<String>(json['valuesJson']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'datasetId': serializer.toJson<int>(datasetId),
      'valuesJson': serializer.toJson<String>(valuesJson),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  DataRow copyWith({
    int? id,
    int? datasetId,
    String? valuesJson,
    String? tagsJson,
    int? orderIndex,
  }) => DataRow(
    id: id ?? this.id,
    datasetId: datasetId ?? this.datasetId,
    valuesJson: valuesJson ?? this.valuesJson,
    tagsJson: tagsJson ?? this.tagsJson,
    orderIndex: orderIndex ?? this.orderIndex,
  );
  DataRow copyWithCompanion(DataRowsCompanion data) {
    return DataRow(
      id: data.id.present ? data.id.value : this.id,
      datasetId: data.datasetId.present ? data.datasetId.value : this.datasetId,
      valuesJson: data.valuesJson.present
          ? data.valuesJson.value
          : this.valuesJson,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DataRow(')
          ..write('id: $id, ')
          ..write('datasetId: $datasetId, ')
          ..write('valuesJson: $valuesJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, datasetId, valuesJson, tagsJson, orderIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DataRow &&
          other.id == this.id &&
          other.datasetId == this.datasetId &&
          other.valuesJson == this.valuesJson &&
          other.tagsJson == this.tagsJson &&
          other.orderIndex == this.orderIndex);
}

class DataRowsCompanion extends UpdateCompanion<DataRow> {
  final Value<int> id;
  final Value<int> datasetId;
  final Value<String> valuesJson;
  final Value<String> tagsJson;
  final Value<int> orderIndex;
  const DataRowsCompanion({
    this.id = const Value.absent(),
    this.datasetId = const Value.absent(),
    this.valuesJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.orderIndex = const Value.absent(),
  });
  DataRowsCompanion.insert({
    this.id = const Value.absent(),
    required int datasetId,
    this.valuesJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.orderIndex = const Value.absent(),
  }) : datasetId = Value(datasetId);
  static Insertable<DataRow> custom({
    Expression<int>? id,
    Expression<int>? datasetId,
    Expression<String>? valuesJson,
    Expression<String>? tagsJson,
    Expression<int>? orderIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (datasetId != null) 'dataset_id': datasetId,
      if (valuesJson != null) 'values_json': valuesJson,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (orderIndex != null) 'order_index': orderIndex,
    });
  }

  DataRowsCompanion copyWith({
    Value<int>? id,
    Value<int>? datasetId,
    Value<String>? valuesJson,
    Value<String>? tagsJson,
    Value<int>? orderIndex,
  }) {
    return DataRowsCompanion(
      id: id ?? this.id,
      datasetId: datasetId ?? this.datasetId,
      valuesJson: valuesJson ?? this.valuesJson,
      tagsJson: tagsJson ?? this.tagsJson,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (datasetId.present) {
      map['dataset_id'] = Variable<int>(datasetId.value);
    }
    if (valuesJson.present) {
      map['values_json'] = Variable<String>(valuesJson.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DataRowsCompanion(')
          ..write('id: $id, ')
          ..write('datasetId: $datasetId, ')
          ..write('valuesJson: $valuesJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }
}

abstract class _$DataManagementDatabase extends GeneratedDatabase {
  _$DataManagementDatabase(QueryExecutor e) : super(e);
  $DataManagementDatabaseManager get managers =>
      $DataManagementDatabaseManager(this);
  late final $DataDatasetsTable dataDatasets = $DataDatasetsTable(this);
  late final $DataRowsTable dataRows = $DataRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [dataDatasets, dataRows];
}

typedef $$DataDatasetsTableCreateCompanionBuilder =
    DataDatasetsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> columnsJson,
      Value<String> tagsJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$DataDatasetsTableUpdateCompanionBuilder =
    DataDatasetsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> columnsJson,
      Value<String> tagsJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$DataDatasetsTableFilterComposer
    extends Composer<_$DataManagementDatabase, $DataDatasetsTable> {
  $$DataDatasetsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get columnsJson => $composableBuilder(
    column: $table.columnsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
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

class $$DataDatasetsTableOrderingComposer
    extends Composer<_$DataManagementDatabase, $DataDatasetsTable> {
  $$DataDatasetsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get columnsJson => $composableBuilder(
    column: $table.columnsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
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

class $$DataDatasetsTableAnnotationComposer
    extends Composer<_$DataManagementDatabase, $DataDatasetsTable> {
  $$DataDatasetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get columnsJson => $composableBuilder(
    column: $table.columnsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DataDatasetsTableTableManager
    extends
        RootTableManager<
          _$DataManagementDatabase,
          $DataDatasetsTable,
          DataDataset,
          $$DataDatasetsTableFilterComposer,
          $$DataDatasetsTableOrderingComposer,
          $$DataDatasetsTableAnnotationComposer,
          $$DataDatasetsTableCreateCompanionBuilder,
          $$DataDatasetsTableUpdateCompanionBuilder,
          (
            DataDataset,
            BaseReferences<
              _$DataManagementDatabase,
              $DataDatasetsTable,
              DataDataset
            >,
          ),
          DataDataset,
          PrefetchHooks Function()
        > {
  $$DataDatasetsTableTableManager(
    _$DataManagementDatabase db,
    $DataDatasetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DataDatasetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DataDatasetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DataDatasetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> columnsJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DataDatasetsCompanion(
                id: id,
                name: name,
                columnsJson: columnsJson,
                tagsJson: tagsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> columnsJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DataDatasetsCompanion.insert(
                id: id,
                name: name,
                columnsJson: columnsJson,
                tagsJson: tagsJson,
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

typedef $$DataDatasetsTableProcessedTableManager =
    ProcessedTableManager<
      _$DataManagementDatabase,
      $DataDatasetsTable,
      DataDataset,
      $$DataDatasetsTableFilterComposer,
      $$DataDatasetsTableOrderingComposer,
      $$DataDatasetsTableAnnotationComposer,
      $$DataDatasetsTableCreateCompanionBuilder,
      $$DataDatasetsTableUpdateCompanionBuilder,
      (
        DataDataset,
        BaseReferences<
          _$DataManagementDatabase,
          $DataDatasetsTable,
          DataDataset
        >,
      ),
      DataDataset,
      PrefetchHooks Function()
    >;
typedef $$DataRowsTableCreateCompanionBuilder =
    DataRowsCompanion Function({
      Value<int> id,
      required int datasetId,
      Value<String> valuesJson,
      Value<String> tagsJson,
      Value<int> orderIndex,
    });
typedef $$DataRowsTableUpdateCompanionBuilder =
    DataRowsCompanion Function({
      Value<int> id,
      Value<int> datasetId,
      Value<String> valuesJson,
      Value<String> tagsJson,
      Value<int> orderIndex,
    });

class $$DataRowsTableFilterComposer
    extends Composer<_$DataManagementDatabase, $DataRowsTable> {
  $$DataRowsTableFilterComposer({
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

  ColumnFilters<int> get datasetId => $composableBuilder(
    column: $table.datasetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valuesJson => $composableBuilder(
    column: $table.valuesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DataRowsTableOrderingComposer
    extends Composer<_$DataManagementDatabase, $DataRowsTable> {
  $$DataRowsTableOrderingComposer({
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

  ColumnOrderings<int> get datasetId => $composableBuilder(
    column: $table.datasetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valuesJson => $composableBuilder(
    column: $table.valuesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DataRowsTableAnnotationComposer
    extends Composer<_$DataManagementDatabase, $DataRowsTable> {
  $$DataRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get datasetId =>
      $composableBuilder(column: $table.datasetId, builder: (column) => column);

  GeneratedColumn<String> get valuesJson => $composableBuilder(
    column: $table.valuesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );
}

class $$DataRowsTableTableManager
    extends
        RootTableManager<
          _$DataManagementDatabase,
          $DataRowsTable,
          DataRow,
          $$DataRowsTableFilterComposer,
          $$DataRowsTableOrderingComposer,
          $$DataRowsTableAnnotationComposer,
          $$DataRowsTableCreateCompanionBuilder,
          $$DataRowsTableUpdateCompanionBuilder,
          (
            DataRow,
            BaseReferences<_$DataManagementDatabase, $DataRowsTable, DataRow>,
          ),
          DataRow,
          PrefetchHooks Function()
        > {
  $$DataRowsTableTableManager(_$DataManagementDatabase db, $DataRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DataRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DataRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DataRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> datasetId = const Value.absent(),
                Value<String> valuesJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
              }) => DataRowsCompanion(
                id: id,
                datasetId: datasetId,
                valuesJson: valuesJson,
                tagsJson: tagsJson,
                orderIndex: orderIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int datasetId,
                Value<String> valuesJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
              }) => DataRowsCompanion.insert(
                id: id,
                datasetId: datasetId,
                valuesJson: valuesJson,
                tagsJson: tagsJson,
                orderIndex: orderIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DataRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$DataManagementDatabase,
      $DataRowsTable,
      DataRow,
      $$DataRowsTableFilterComposer,
      $$DataRowsTableOrderingComposer,
      $$DataRowsTableAnnotationComposer,
      $$DataRowsTableCreateCompanionBuilder,
      $$DataRowsTableUpdateCompanionBuilder,
      (
        DataRow,
        BaseReferences<_$DataManagementDatabase, $DataRowsTable, DataRow>,
      ),
      DataRow,
      PrefetchHooks Function()
    >;

class $DataManagementDatabaseManager {
  final _$DataManagementDatabase _db;
  $DataManagementDatabaseManager(this._db);
  $$DataDatasetsTableTableManager get dataDatasets =>
      $$DataDatasetsTableTableManager(_db, _db.dataDatasets);
  $$DataRowsTableTableManager get dataRows =>
      $$DataRowsTableTableManager(_db, _db.dataRows);
}
