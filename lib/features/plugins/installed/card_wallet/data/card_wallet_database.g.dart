// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_wallet_database.dart';

// ignore_for_file: type=lint
class $WalletCardsTable extends WalletCards
    with TableInfo<$WalletCardsTable, WalletCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletCardsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 0,
      maxTextLength: 4096,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('code128'),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF7C5AD9),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    code,
    format,
    category,
    color,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletCard> instance, {
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
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
  WalletCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletCard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WalletCardsTable createAlias(String alias) {
    return $WalletCardsTable(attachedDatabase, alias);
  }
}

class WalletCard extends DataClass implements Insertable<WalletCard> {
  final int id;
  final String name;

  /// The value presented: a barcode number for barcode formats, or the raw
  /// tag payload for [format] == 'nfc'.
  final String code;

  /// A [CardFormat] enum name — see card_formats.dart.
  final String format;

  /// Optional grouping label (e.g. "Loyalty", "Membership", "Transit").
  final String? category;

  /// ARGB accent color for the card tile.
  final int color;
  final String? notes;
  final DateTime createdAt;
  const WalletCard({
    required this.id,
    required this.name,
    required this.code,
    required this.format,
    this.category,
    required this.color,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['code'] = Variable<String>(code);
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['color'] = Variable<int>(color);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WalletCardsCompanion toCompanion(bool nullToAbsent) {
    return WalletCardsCompanion(
      id: Value(id),
      name: Value(name),
      code: Value(code),
      format: Value(format),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      color: Value(color),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory WalletCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletCard(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String>(json['code']),
      format: serializer.fromJson<String>(json['format']),
      category: serializer.fromJson<String?>(json['category']),
      color: serializer.fromJson<int>(json['color']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String>(code),
      'format': serializer.toJson<String>(format),
      'category': serializer.toJson<String?>(category),
      'color': serializer.toJson<int>(color),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WalletCard copyWith({
    int? id,
    String? name,
    String? code,
    String? format,
    Value<String?> category = const Value.absent(),
    int? color,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => WalletCard(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code ?? this.code,
    format: format ?? this.format,
    category: category.present ? category.value : this.category,
    color: color ?? this.color,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  WalletCard copyWithCompanion(WalletCardsCompanion data) {
    return WalletCard(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      format: data.format.present ? data.format.value : this.format,
      category: data.category.present ? data.category.value : this.category,
      color: data.color.present ? data.color.value : this.color,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletCard(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('format: $format, ')
          ..write('category: $category, ')
          ..write('color: $color, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, code, format, category, color, notes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletCard &&
          other.id == this.id &&
          other.name == this.name &&
          other.code == this.code &&
          other.format == this.format &&
          other.category == this.category &&
          other.color == this.color &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class WalletCardsCompanion extends UpdateCompanion<WalletCard> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> code;
  final Value<String> format;
  final Value<String?> category;
  final Value<int> color;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const WalletCardsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.format = const Value.absent(),
    this.category = const Value.absent(),
    this.color = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WalletCardsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String code,
    this.format = const Value.absent(),
    this.category = const Value.absent(),
    this.color = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       code = Value(code);
  static Insertable<WalletCard> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? code,
    Expression<String>? format,
    Expression<String>? category,
    Expression<int>? color,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (format != null) 'format': format,
      if (category != null) 'category': category,
      if (color != null) 'color': color,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WalletCardsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? code,
    Value<String>? format,
    Value<String?>? category,
    Value<int>? color,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
  }) {
    return WalletCardsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      format: format ?? this.format,
      category: category ?? this.category,
      color: color ?? this.color,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
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
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletCardsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('format: $format, ')
          ..write('category: $category, ')
          ..write('color: $color, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$CardWalletDatabase extends GeneratedDatabase {
  _$CardWalletDatabase(QueryExecutor e) : super(e);
  $CardWalletDatabaseManager get managers => $CardWalletDatabaseManager(this);
  late final $WalletCardsTable walletCards = $WalletCardsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [walletCards];
}

typedef $$WalletCardsTableCreateCompanionBuilder =
    WalletCardsCompanion Function({
      Value<int> id,
      required String name,
      required String code,
      Value<String> format,
      Value<String?> category,
      Value<int> color,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });
typedef $$WalletCardsTableUpdateCompanionBuilder =
    WalletCardsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> code,
      Value<String> format,
      Value<String?> category,
      Value<int> color,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });

class $$WalletCardsTableFilterComposer
    extends Composer<_$CardWalletDatabase, $WalletCardsTable> {
  $$WalletCardsTableFilterComposer({
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

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletCardsTableOrderingComposer
    extends Composer<_$CardWalletDatabase, $WalletCardsTable> {
  $$WalletCardsTableOrderingComposer({
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

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletCardsTableAnnotationComposer
    extends Composer<_$CardWalletDatabase, $WalletCardsTable> {
  $$WalletCardsTableAnnotationComposer({
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

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WalletCardsTableTableManager
    extends
        RootTableManager<
          _$CardWalletDatabase,
          $WalletCardsTable,
          WalletCard,
          $$WalletCardsTableFilterComposer,
          $$WalletCardsTableOrderingComposer,
          $$WalletCardsTableAnnotationComposer,
          $$WalletCardsTableCreateCompanionBuilder,
          $$WalletCardsTableUpdateCompanionBuilder,
          (
            WalletCard,
            BaseReferences<_$CardWalletDatabase, $WalletCardsTable, WalletCard>,
          ),
          WalletCard,
          PrefetchHooks Function()
        > {
  $$WalletCardsTableTableManager(
    _$CardWalletDatabase db,
    $WalletCardsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => WalletCardsCompanion(
                id: id,
                name: name,
                code: code,
                format: format,
                category: category,
                color: color,
                notes: notes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String code,
                Value<String> format = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => WalletCardsCompanion.insert(
                id: id,
                name: name,
                code: code,
                format: format,
                category: category,
                color: color,
                notes: notes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$CardWalletDatabase,
      $WalletCardsTable,
      WalletCard,
      $$WalletCardsTableFilterComposer,
      $$WalletCardsTableOrderingComposer,
      $$WalletCardsTableAnnotationComposer,
      $$WalletCardsTableCreateCompanionBuilder,
      $$WalletCardsTableUpdateCompanionBuilder,
      (
        WalletCard,
        BaseReferences<_$CardWalletDatabase, $WalletCardsTable, WalletCard>,
      ),
      WalletCard,
      PrefetchHooks Function()
    >;

class $CardWalletDatabaseManager {
  final _$CardWalletDatabase _db;
  $CardWalletDatabaseManager(this._db);
  $$WalletCardsTableTableManager get walletCards =>
      $$WalletCardsTableTableManager(_db, _db.walletCards);
}
