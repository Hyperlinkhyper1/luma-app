// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bulletin_board_database.dart';

// ignore_for_file: type=lint
class $BoardItemsTable extends BoardItems
    with TableInfo<$BoardItemsTable, BoardItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoardItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFFFFFFFF),
  );
  static const VerificationMeta _posXMeta = const VerificationMeta('posX');
  @override
  late final GeneratedColumn<double> posX = GeneratedColumn<double>(
    'pos_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _posYMeta = const VerificationMeta('posY');
  @override
  late final GeneratedColumn<double> posY = GeneratedColumn<double>(
    'pos_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(200.0),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(200.0),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
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
    title,
    content,
    color,
    posX,
    posY,
    width,
    height,
    pinned,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'board_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoardItem> instance, {
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
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('pos_x')) {
      context.handle(
        _posXMeta,
        posX.isAcceptableOrUnknown(data['pos_x']!, _posXMeta),
      );
    }
    if (data.containsKey('pos_y')) {
      context.handle(
        _posYMeta,
        posY.isAcceptableOrUnknown(data['pos_y']!, _posYMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
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
  BoardItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoardItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      posX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pos_x'],
      )!,
      posY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pos_y'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BoardItemsTable createAlias(String alias) {
    return $BoardItemsTable(attachedDatabase, alias);
  }
}

class BoardItem extends DataClass implements Insertable<BoardItem> {
  final int id;
  final String type;
  final String? title;
  final String content;
  final int color;
  final double posX;
  final double posY;
  final double width;
  final double height;
  final bool pinned;
  final DateTime createdAt;
  const BoardItem({
    required this.id,
    required this.type,
    this.title,
    required this.content,
    required this.color,
    required this.posX,
    required this.posY,
    required this.width,
    required this.height,
    required this.pinned,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['content'] = Variable<String>(content);
    map['color'] = Variable<int>(color);
    map['pos_x'] = Variable<double>(posX);
    map['pos_y'] = Variable<double>(posY);
    map['width'] = Variable<double>(width);
    map['height'] = Variable<double>(height);
    map['pinned'] = Variable<bool>(pinned);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BoardItemsCompanion toCompanion(bool nullToAbsent) {
    return BoardItemsCompanion(
      id: Value(id),
      type: Value(type),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      content: Value(content),
      color: Value(color),
      posX: Value(posX),
      posY: Value(posY),
      width: Value(width),
      height: Value(height),
      pinned: Value(pinned),
      createdAt: Value(createdAt),
    );
  }

  factory BoardItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoardItem(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String?>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      color: serializer.fromJson<int>(json['color']),
      posX: serializer.fromJson<double>(json['posX']),
      posY: serializer.fromJson<double>(json['posY']),
      width: serializer.fromJson<double>(json['width']),
      height: serializer.fromJson<double>(json['height']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String?>(title),
      'content': serializer.toJson<String>(content),
      'color': serializer.toJson<int>(color),
      'posX': serializer.toJson<double>(posX),
      'posY': serializer.toJson<double>(posY),
      'width': serializer.toJson<double>(width),
      'height': serializer.toJson<double>(height),
      'pinned': serializer.toJson<bool>(pinned),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BoardItem copyWith({
    int? id,
    String? type,
    Value<String?> title = const Value.absent(),
    String? content,
    int? color,
    double? posX,
    double? posY,
    double? width,
    double? height,
    bool? pinned,
    DateTime? createdAt,
  }) => BoardItem(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title.present ? title.value : this.title,
    content: content ?? this.content,
    color: color ?? this.color,
    posX: posX ?? this.posX,
    posY: posY ?? this.posY,
    width: width ?? this.width,
    height: height ?? this.height,
    pinned: pinned ?? this.pinned,
    createdAt: createdAt ?? this.createdAt,
  );
  BoardItem copyWithCompanion(BoardItemsCompanion data) {
    return BoardItem(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      color: data.color.present ? data.color.value : this.color,
      posX: data.posX.present ? data.posX.value : this.posX,
      posY: data.posY.present ? data.posY.value : this.posY,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoardItem(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('color: $color, ')
          ..write('posX: $posX, ')
          ..write('posY: $posY, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('pinned: $pinned, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    content,
    color,
    posX,
    posY,
    width,
    height,
    pinned,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoardItem &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.content == this.content &&
          other.color == this.color &&
          other.posX == this.posX &&
          other.posY == this.posY &&
          other.width == this.width &&
          other.height == this.height &&
          other.pinned == this.pinned &&
          other.createdAt == this.createdAt);
}

class BoardItemsCompanion extends UpdateCompanion<BoardItem> {
  final Value<int> id;
  final Value<String> type;
  final Value<String?> title;
  final Value<String> content;
  final Value<int> color;
  final Value<double> posX;
  final Value<double> posY;
  final Value<double> width;
  final Value<double> height;
  final Value<bool> pinned;
  final Value<DateTime> createdAt;
  const BoardItemsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.color = const Value.absent(),
    this.posX = const Value.absent(),
    this.posY = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.pinned = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BoardItemsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    this.title = const Value.absent(),
    required String content,
    this.color = const Value.absent(),
    this.posX = const Value.absent(),
    this.posY = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.pinned = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : type = Value(type),
       content = Value(content);
  static Insertable<BoardItem> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? content,
    Expression<int>? color,
    Expression<double>? posX,
    Expression<double>? posY,
    Expression<double>? width,
    Expression<double>? height,
    Expression<bool>? pinned,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (color != null) 'color': color,
      if (posX != null) 'pos_x': posX,
      if (posY != null) 'pos_y': posY,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (pinned != null) 'pinned': pinned,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BoardItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<String?>? title,
    Value<String>? content,
    Value<int>? color,
    Value<double>? posX,
    Value<double>? posY,
    Value<double>? width,
    Value<double>? height,
    Value<bool>? pinned,
    Value<DateTime>? createdAt,
  }) {
    return BoardItemsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      color: color ?? this.color,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      width: width ?? this.width,
      height: height ?? this.height,
      pinned: pinned ?? this.pinned,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (posX.present) {
      map['pos_x'] = Variable<double>(posX.value);
    }
    if (posY.present) {
      map['pos_y'] = Variable<double>(posY.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoardItemsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('color: $color, ')
          ..write('posX: $posX, ')
          ..write('posY: $posY, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('pinned: $pinned, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$BulletinBoardDatabase extends GeneratedDatabase {
  _$BulletinBoardDatabase(QueryExecutor e) : super(e);
  $BulletinBoardDatabaseManager get managers =>
      $BulletinBoardDatabaseManager(this);
  late final $BoardItemsTable boardItems = $BoardItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [boardItems];
}

typedef $$BoardItemsTableCreateCompanionBuilder =
    BoardItemsCompanion Function({
      Value<int> id,
      required String type,
      Value<String?> title,
      required String content,
      Value<int> color,
      Value<double> posX,
      Value<double> posY,
      Value<double> width,
      Value<double> height,
      Value<bool> pinned,
      Value<DateTime> createdAt,
    });
typedef $$BoardItemsTableUpdateCompanionBuilder =
    BoardItemsCompanion Function({
      Value<int> id,
      Value<String> type,
      Value<String?> title,
      Value<String> content,
      Value<int> color,
      Value<double> posX,
      Value<double> posY,
      Value<double> width,
      Value<double> height,
      Value<bool> pinned,
      Value<DateTime> createdAt,
    });

class $$BoardItemsTableFilterComposer
    extends Composer<_$BulletinBoardDatabase, $BoardItemsTable> {
  $$BoardItemsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get posX => $composableBuilder(
    column: $table.posX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get posY => $composableBuilder(
    column: $table.posY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BoardItemsTableOrderingComposer
    extends Composer<_$BulletinBoardDatabase, $BoardItemsTable> {
  $$BoardItemsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get posX => $composableBuilder(
    column: $table.posX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get posY => $composableBuilder(
    column: $table.posY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BoardItemsTableAnnotationComposer
    extends Composer<_$BulletinBoardDatabase, $BoardItemsTable> {
  $$BoardItemsTableAnnotationComposer({
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

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<double> get posX =>
      $composableBuilder(column: $table.posX, builder: (column) => column);

  GeneratedColumn<double> get posY =>
      $composableBuilder(column: $table.posY, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BoardItemsTableTableManager
    extends
        RootTableManager<
          _$BulletinBoardDatabase,
          $BoardItemsTable,
          BoardItem,
          $$BoardItemsTableFilterComposer,
          $$BoardItemsTableOrderingComposer,
          $$BoardItemsTableAnnotationComposer,
          $$BoardItemsTableCreateCompanionBuilder,
          $$BoardItemsTableUpdateCompanionBuilder,
          (
            BoardItem,
            BaseReferences<
              _$BulletinBoardDatabase,
              $BoardItemsTable,
              BoardItem
            >,
          ),
          BoardItem,
          PrefetchHooks Function()
        > {
  $$BoardItemsTableTableManager(
    _$BulletinBoardDatabase db,
    $BoardItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoardItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoardItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoardItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<double> posX = const Value.absent(),
                Value<double> posY = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BoardItemsCompanion(
                id: id,
                type: type,
                title: title,
                content: content,
                color: color,
                posX: posX,
                posY: posY,
                width: width,
                height: height,
                pinned: pinned,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                Value<String?> title = const Value.absent(),
                required String content,
                Value<int> color = const Value.absent(),
                Value<double> posX = const Value.absent(),
                Value<double> posY = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BoardItemsCompanion.insert(
                id: id,
                type: type,
                title: title,
                content: content,
                color: color,
                posX: posX,
                posY: posY,
                width: width,
                height: height,
                pinned: pinned,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BoardItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$BulletinBoardDatabase,
      $BoardItemsTable,
      BoardItem,
      $$BoardItemsTableFilterComposer,
      $$BoardItemsTableOrderingComposer,
      $$BoardItemsTableAnnotationComposer,
      $$BoardItemsTableCreateCompanionBuilder,
      $$BoardItemsTableUpdateCompanionBuilder,
      (
        BoardItem,
        BaseReferences<_$BulletinBoardDatabase, $BoardItemsTable, BoardItem>,
      ),
      BoardItem,
      PrefetchHooks Function()
    >;

class $BulletinBoardDatabaseManager {
  final _$BulletinBoardDatabase _db;
  $BulletinBoardDatabaseManager(this._db);
  $$BoardItemsTableTableManager get boardItems =>
      $$BoardItemsTableTableManager(_db, _db.boardItems);
}
