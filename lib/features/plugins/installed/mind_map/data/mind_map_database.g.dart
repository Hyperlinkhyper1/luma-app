// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mind_map_database.dart';

// ignore_for_file: type=lint
class $MindMapsTable extends MindMaps with TableInfo<$MindMapsTable, MindMap> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MindMapsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<int> direction = GeneratedColumn<int>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    title,
    direction,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mind_maps';
  @override
  VerificationContext validateIntegrity(
    Insertable<MindMap> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
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
  MindMap map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MindMap(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}direction'],
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
  $MindMapsTable createAlias(String alias) {
    return $MindMapsTable(attachedDatabase, alias);
  }
}

class MindMap extends DataClass implements Insertable<MindMap> {
  final int id;
  final String title;

  /// Index into `MindMapDirection.values`.
  final int direction;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MindMap({
    required this.id,
    required this.title,
    required this.direction,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['direction'] = Variable<int>(direction);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MindMapsCompanion toCompanion(bool nullToAbsent) {
    return MindMapsCompanion(
      id: Value(id),
      title: Value(title),
      direction: Value(direction),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MindMap.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MindMap(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      direction: serializer.fromJson<int>(json['direction']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'direction': serializer.toJson<int>(direction),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MindMap copyWith({
    int? id,
    String? title,
    int? direction,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MindMap(
    id: id ?? this.id,
    title: title ?? this.title,
    direction: direction ?? this.direction,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MindMap copyWithCompanion(MindMapsCompanion data) {
    return MindMap(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      direction: data.direction.present ? data.direction.value : this.direction,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MindMap(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('direction: $direction, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, direction, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MindMap &&
          other.id == this.id &&
          other.title == this.title &&
          other.direction == this.direction &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MindMapsCompanion extends UpdateCompanion<MindMap> {
  final Value<int> id;
  final Value<String> title;
  final Value<int> direction;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const MindMapsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.direction = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  MindMapsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.direction = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : title = Value(title);
  static Insertable<MindMap> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<int>? direction,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (direction != null) 'direction': direction,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  MindMapsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<int>? direction,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return MindMapsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      direction: direction ?? this.direction,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (direction.present) {
      map['direction'] = Variable<int>(direction.value);
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
    return (StringBuffer('MindMapsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('direction: $direction, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MindMapNodesTable extends MindMapNodes
    with TableInfo<$MindMapNodesTable, MindMapNode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MindMapNodesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _mapIdMeta = const VerificationMeta('mapId');
  @override
  late final GeneratedColumn<int> mapId = GeneratedColumn<int>(
    'map_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mind_maps (id)',
    ),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkMeta = const VerificationMeta('link');
  @override
  late final GeneratedColumn<String> link = GeneratedColumn<String>(
    'link',
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
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _collapsedMeta = const VerificationMeta(
    'collapsed',
  );
  @override
  late final GeneratedColumn<bool> collapsed = GeneratedColumn<bool>(
    'collapsed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("collapsed" IN (0, 1))',
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
    mapId,
    parentId,
    label,
    note,
    link,
    color,
    sortIndex,
    collapsed,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mind_map_nodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<MindMapNode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('map_id')) {
      context.handle(
        _mapIdMeta,
        mapId.isAcceptableOrUnknown(data['map_id']!, _mapIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mapIdMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('link')) {
      context.handle(
        _linkMeta,
        link.isAcceptableOrUnknown(data['link']!, _linkMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    if (data.containsKey('collapsed')) {
      context.handle(
        _collapsedMeta,
        collapsed.isAcceptableOrUnknown(data['collapsed']!, _collapsedMeta),
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
  MindMapNode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MindMapNode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mapId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}map_id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_id'],
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      link: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      collapsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}collapsed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MindMapNodesTable createAlias(String alias) {
    return $MindMapNodesTable(attachedDatabase, alias);
  }
}

class MindMapNode extends DataClass implements Insertable<MindMapNode> {
  final int id;
  final int mapId;
  final int? parentId;
  final String label;
  final String? note;
  final String? link;

  /// Null means "inherit the branch colour from the nearest coloured
  /// ancestor", so recolouring a branch is a single edit.
  final int? color;
  final int sortIndex;
  final bool collapsed;
  final DateTime createdAt;
  const MindMapNode({
    required this.id,
    required this.mapId,
    this.parentId,
    required this.label,
    this.note,
    this.link,
    this.color,
    required this.sortIndex,
    required this.collapsed,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['map_id'] = Variable<int>(mapId);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || link != null) {
      map['link'] = Variable<String>(link);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    map['collapsed'] = Variable<bool>(collapsed);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MindMapNodesCompanion toCompanion(bool nullToAbsent) {
    return MindMapNodesCompanion(
      id: Value(id),
      mapId: Value(mapId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      label: Value(label),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      link: link == null && nullToAbsent ? const Value.absent() : Value(link),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      sortIndex: Value(sortIndex),
      collapsed: Value(collapsed),
      createdAt: Value(createdAt),
    );
  }

  factory MindMapNode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MindMapNode(
      id: serializer.fromJson<int>(json['id']),
      mapId: serializer.fromJson<int>(json['mapId']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      label: serializer.fromJson<String>(json['label']),
      note: serializer.fromJson<String?>(json['note']),
      link: serializer.fromJson<String?>(json['link']),
      color: serializer.fromJson<int?>(json['color']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      collapsed: serializer.fromJson<bool>(json['collapsed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mapId': serializer.toJson<int>(mapId),
      'parentId': serializer.toJson<int?>(parentId),
      'label': serializer.toJson<String>(label),
      'note': serializer.toJson<String?>(note),
      'link': serializer.toJson<String?>(link),
      'color': serializer.toJson<int?>(color),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'collapsed': serializer.toJson<bool>(collapsed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MindMapNode copyWith({
    int? id,
    int? mapId,
    Value<int?> parentId = const Value.absent(),
    String? label,
    Value<String?> note = const Value.absent(),
    Value<String?> link = const Value.absent(),
    Value<int?> color = const Value.absent(),
    int? sortIndex,
    bool? collapsed,
    DateTime? createdAt,
  }) => MindMapNode(
    id: id ?? this.id,
    mapId: mapId ?? this.mapId,
    parentId: parentId.present ? parentId.value : this.parentId,
    label: label ?? this.label,
    note: note.present ? note.value : this.note,
    link: link.present ? link.value : this.link,
    color: color.present ? color.value : this.color,
    sortIndex: sortIndex ?? this.sortIndex,
    collapsed: collapsed ?? this.collapsed,
    createdAt: createdAt ?? this.createdAt,
  );
  MindMapNode copyWithCompanion(MindMapNodesCompanion data) {
    return MindMapNode(
      id: data.id.present ? data.id.value : this.id,
      mapId: data.mapId.present ? data.mapId.value : this.mapId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      label: data.label.present ? data.label.value : this.label,
      note: data.note.present ? data.note.value : this.note,
      link: data.link.present ? data.link.value : this.link,
      color: data.color.present ? data.color.value : this.color,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      collapsed: data.collapsed.present ? data.collapsed.value : this.collapsed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MindMapNode(')
          ..write('id: $id, ')
          ..write('mapId: $mapId, ')
          ..write('parentId: $parentId, ')
          ..write('label: $label, ')
          ..write('note: $note, ')
          ..write('link: $link, ')
          ..write('color: $color, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('collapsed: $collapsed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mapId,
    parentId,
    label,
    note,
    link,
    color,
    sortIndex,
    collapsed,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MindMapNode &&
          other.id == this.id &&
          other.mapId == this.mapId &&
          other.parentId == this.parentId &&
          other.label == this.label &&
          other.note == this.note &&
          other.link == this.link &&
          other.color == this.color &&
          other.sortIndex == this.sortIndex &&
          other.collapsed == this.collapsed &&
          other.createdAt == this.createdAt);
}

class MindMapNodesCompanion extends UpdateCompanion<MindMapNode> {
  final Value<int> id;
  final Value<int> mapId;
  final Value<int?> parentId;
  final Value<String> label;
  final Value<String?> note;
  final Value<String?> link;
  final Value<int?> color;
  final Value<int> sortIndex;
  final Value<bool> collapsed;
  final Value<DateTime> createdAt;
  const MindMapNodesCompanion({
    this.id = const Value.absent(),
    this.mapId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.label = const Value.absent(),
    this.note = const Value.absent(),
    this.link = const Value.absent(),
    this.color = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.collapsed = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MindMapNodesCompanion.insert({
    this.id = const Value.absent(),
    required int mapId,
    this.parentId = const Value.absent(),
    required String label,
    this.note = const Value.absent(),
    this.link = const Value.absent(),
    this.color = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.collapsed = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : mapId = Value(mapId),
       label = Value(label);
  static Insertable<MindMapNode> custom({
    Expression<int>? id,
    Expression<int>? mapId,
    Expression<int>? parentId,
    Expression<String>? label,
    Expression<String>? note,
    Expression<String>? link,
    Expression<int>? color,
    Expression<int>? sortIndex,
    Expression<bool>? collapsed,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mapId != null) 'map_id': mapId,
      if (parentId != null) 'parent_id': parentId,
      if (label != null) 'label': label,
      if (note != null) 'note': note,
      if (link != null) 'link': link,
      if (color != null) 'color': color,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (collapsed != null) 'collapsed': collapsed,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MindMapNodesCompanion copyWith({
    Value<int>? id,
    Value<int>? mapId,
    Value<int?>? parentId,
    Value<String>? label,
    Value<String?>? note,
    Value<String?>? link,
    Value<int?>? color,
    Value<int>? sortIndex,
    Value<bool>? collapsed,
    Value<DateTime>? createdAt,
  }) {
    return MindMapNodesCompanion(
      id: id ?? this.id,
      mapId: mapId ?? this.mapId,
      parentId: parentId ?? this.parentId,
      label: label ?? this.label,
      note: note ?? this.note,
      link: link ?? this.link,
      color: color ?? this.color,
      sortIndex: sortIndex ?? this.sortIndex,
      collapsed: collapsed ?? this.collapsed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mapId.present) {
      map['map_id'] = Variable<int>(mapId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (link.present) {
      map['link'] = Variable<String>(link.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (collapsed.present) {
      map['collapsed'] = Variable<bool>(collapsed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MindMapNodesCompanion(')
          ..write('id: $id, ')
          ..write('mapId: $mapId, ')
          ..write('parentId: $parentId, ')
          ..write('label: $label, ')
          ..write('note: $note, ')
          ..write('link: $link, ')
          ..write('color: $color, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('collapsed: $collapsed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MindMapMetaTable extends MindMapMeta
    with TableInfo<$MindMapMetaTable, MindMapMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MindMapMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mind_map_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MindMapMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MindMapMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MindMapMetaData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MindMapMetaTable createAlias(String alias) {
    return $MindMapMetaTable(attachedDatabase, alias);
  }
}

class MindMapMetaData extends DataClass implements Insertable<MindMapMetaData> {
  final String key;
  final String value;
  const MindMapMetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MindMapMetaCompanion toCompanion(bool nullToAbsent) {
    return MindMapMetaCompanion(key: Value(key), value: Value(value));
  }

  factory MindMapMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MindMapMetaData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MindMapMetaData copyWith({String? key, String? value}) =>
      MindMapMetaData(key: key ?? this.key, value: value ?? this.value);
  MindMapMetaData copyWithCompanion(MindMapMetaCompanion data) {
    return MindMapMetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MindMapMetaData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MindMapMetaData &&
          other.key == this.key &&
          other.value == this.value);
}

class MindMapMetaCompanion extends UpdateCompanion<MindMapMetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MindMapMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MindMapMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MindMapMetaData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MindMapMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MindMapMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MindMapMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$MindMapDatabase extends GeneratedDatabase {
  _$MindMapDatabase(QueryExecutor e) : super(e);
  $MindMapDatabaseManager get managers => $MindMapDatabaseManager(this);
  late final $MindMapsTable mindMaps = $MindMapsTable(this);
  late final $MindMapNodesTable mindMapNodes = $MindMapNodesTable(this);
  late final $MindMapMetaTable mindMapMeta = $MindMapMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mindMaps,
    mindMapNodes,
    mindMapMeta,
  ];
}

typedef $$MindMapsTableCreateCompanionBuilder =
    MindMapsCompanion Function({
      Value<int> id,
      required String title,
      Value<int> direction,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$MindMapsTableUpdateCompanionBuilder =
    MindMapsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<int> direction,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$MindMapsTableReferences
    extends BaseReferences<_$MindMapDatabase, $MindMapsTable, MindMap> {
  $$MindMapsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MindMapNodesTable, List<MindMapNode>>
  _mindMapNodesRefsTable(_$MindMapDatabase db) => MultiTypedResultKey.fromTable(
    db.mindMapNodes,
    aliasName: 'mind_maps__id__mind_map_nodes__map_id',
  );

  $$MindMapNodesTableProcessedTableManager get mindMapNodesRefs {
    final manager = $$MindMapNodesTableTableManager(
      $_db,
      $_db.mindMapNodes,
    ).filter((f) => f.mapId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mindMapNodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MindMapsTableFilterComposer
    extends Composer<_$MindMapDatabase, $MindMapsTable> {
  $$MindMapsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get direction => $composableBuilder(
    column: $table.direction,
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

  Expression<bool> mindMapNodesRefs(
    Expression<bool> Function($$MindMapNodesTableFilterComposer f) f,
  ) {
    final $$MindMapNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mindMapNodes,
      getReferencedColumn: (t) => t.mapId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MindMapNodesTableFilterComposer(
            $db: $db,
            $table: $db.mindMapNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MindMapsTableOrderingComposer
    extends Composer<_$MindMapDatabase, $MindMapsTable> {
  $$MindMapsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get direction => $composableBuilder(
    column: $table.direction,
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

class $$MindMapsTableAnnotationComposer
    extends Composer<_$MindMapDatabase, $MindMapsTable> {
  $$MindMapsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> mindMapNodesRefs<T extends Object>(
    Expression<T> Function($$MindMapNodesTableAnnotationComposer a) f,
  ) {
    final $$MindMapNodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mindMapNodes,
      getReferencedColumn: (t) => t.mapId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MindMapNodesTableAnnotationComposer(
            $db: $db,
            $table: $db.mindMapNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MindMapsTableTableManager
    extends
        RootTableManager<
          _$MindMapDatabase,
          $MindMapsTable,
          MindMap,
          $$MindMapsTableFilterComposer,
          $$MindMapsTableOrderingComposer,
          $$MindMapsTableAnnotationComposer,
          $$MindMapsTableCreateCompanionBuilder,
          $$MindMapsTableUpdateCompanionBuilder,
          (MindMap, $$MindMapsTableReferences),
          MindMap,
          PrefetchHooks Function({bool mindMapNodesRefs})
        > {
  $$MindMapsTableTableManager(_$MindMapDatabase db, $MindMapsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MindMapsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MindMapsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MindMapsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> direction = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => MindMapsCompanion(
                id: id,
                title: title,
                direction: direction,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<int> direction = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => MindMapsCompanion.insert(
                id: id,
                title: title,
                direction: direction,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MindMapsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mindMapNodesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (mindMapNodesRefs) db.mindMapNodes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mindMapNodesRefs)
                    await $_getPrefetchedData<
                      MindMap,
                      $MindMapsTable,
                      MindMapNode
                    >(
                      currentTable: table,
                      referencedTable: $$MindMapsTableReferences
                          ._mindMapNodesRefsTable(db),
                      managerFromTypedResult: (p0) => $$MindMapsTableReferences(
                        db,
                        table,
                        p0,
                      ).mindMapNodesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.mapId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MindMapsTableProcessedTableManager =
    ProcessedTableManager<
      _$MindMapDatabase,
      $MindMapsTable,
      MindMap,
      $$MindMapsTableFilterComposer,
      $$MindMapsTableOrderingComposer,
      $$MindMapsTableAnnotationComposer,
      $$MindMapsTableCreateCompanionBuilder,
      $$MindMapsTableUpdateCompanionBuilder,
      (MindMap, $$MindMapsTableReferences),
      MindMap,
      PrefetchHooks Function({bool mindMapNodesRefs})
    >;
typedef $$MindMapNodesTableCreateCompanionBuilder =
    MindMapNodesCompanion Function({
      Value<int> id,
      required int mapId,
      Value<int?> parentId,
      required String label,
      Value<String?> note,
      Value<String?> link,
      Value<int?> color,
      Value<int> sortIndex,
      Value<bool> collapsed,
      Value<DateTime> createdAt,
    });
typedef $$MindMapNodesTableUpdateCompanionBuilder =
    MindMapNodesCompanion Function({
      Value<int> id,
      Value<int> mapId,
      Value<int?> parentId,
      Value<String> label,
      Value<String?> note,
      Value<String?> link,
      Value<int?> color,
      Value<int> sortIndex,
      Value<bool> collapsed,
      Value<DateTime> createdAt,
    });

final class $$MindMapNodesTableReferences
    extends BaseReferences<_$MindMapDatabase, $MindMapNodesTable, MindMapNode> {
  $$MindMapNodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MindMapsTable _mapIdTable(_$MindMapDatabase db) =>
      db.mindMaps.createAlias('mind_map_nodes__map_id__mind_maps__id');

  $$MindMapsTableProcessedTableManager get mapId {
    final $_column = $_itemColumn<int>('map_id')!;

    final manager = $$MindMapsTableTableManager(
      $_db,
      $_db.mindMaps,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mapIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MindMapNodesTableFilterComposer
    extends Composer<_$MindMapDatabase, $MindMapNodesTable> {
  $$MindMapNodesTableFilterComposer({
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

  ColumnFilters<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get collapsed => $composableBuilder(
    column: $table.collapsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MindMapsTableFilterComposer get mapId {
    final $$MindMapsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mapId,
      referencedTable: $db.mindMaps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MindMapsTableFilterComposer(
            $db: $db,
            $table: $db.mindMaps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MindMapNodesTableOrderingComposer
    extends Composer<_$MindMapDatabase, $MindMapNodesTable> {
  $$MindMapNodesTableOrderingComposer({
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

  ColumnOrderings<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get collapsed => $composableBuilder(
    column: $table.collapsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MindMapsTableOrderingComposer get mapId {
    final $$MindMapsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mapId,
      referencedTable: $db.mindMaps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MindMapsTableOrderingComposer(
            $db: $db,
            $table: $db.mindMaps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MindMapNodesTableAnnotationComposer
    extends Composer<_$MindMapDatabase, $MindMapNodesTable> {
  $$MindMapNodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get link =>
      $composableBuilder(column: $table.link, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<bool> get collapsed =>
      $composableBuilder(column: $table.collapsed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MindMapsTableAnnotationComposer get mapId {
    final $$MindMapsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mapId,
      referencedTable: $db.mindMaps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MindMapsTableAnnotationComposer(
            $db: $db,
            $table: $db.mindMaps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MindMapNodesTableTableManager
    extends
        RootTableManager<
          _$MindMapDatabase,
          $MindMapNodesTable,
          MindMapNode,
          $$MindMapNodesTableFilterComposer,
          $$MindMapNodesTableOrderingComposer,
          $$MindMapNodesTableAnnotationComposer,
          $$MindMapNodesTableCreateCompanionBuilder,
          $$MindMapNodesTableUpdateCompanionBuilder,
          (MindMapNode, $$MindMapNodesTableReferences),
          MindMapNode,
          PrefetchHooks Function({bool mapId})
        > {
  $$MindMapNodesTableTableManager(
    _$MindMapDatabase db,
    $MindMapNodesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MindMapNodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MindMapNodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MindMapNodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mapId = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> link = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> collapsed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MindMapNodesCompanion(
                id: id,
                mapId: mapId,
                parentId: parentId,
                label: label,
                note: note,
                link: link,
                color: color,
                sortIndex: sortIndex,
                collapsed: collapsed,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mapId,
                Value<int?> parentId = const Value.absent(),
                required String label,
                Value<String?> note = const Value.absent(),
                Value<String?> link = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> collapsed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MindMapNodesCompanion.insert(
                id: id,
                mapId: mapId,
                parentId: parentId,
                label: label,
                note: note,
                link: link,
                color: color,
                sortIndex: sortIndex,
                collapsed: collapsed,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MindMapNodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mapId = false}) {
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
                    if (mapId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mapId,
                                referencedTable: $$MindMapNodesTableReferences
                                    ._mapIdTable(db),
                                referencedColumn: $$MindMapNodesTableReferences
                                    ._mapIdTable(db)
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

typedef $$MindMapNodesTableProcessedTableManager =
    ProcessedTableManager<
      _$MindMapDatabase,
      $MindMapNodesTable,
      MindMapNode,
      $$MindMapNodesTableFilterComposer,
      $$MindMapNodesTableOrderingComposer,
      $$MindMapNodesTableAnnotationComposer,
      $$MindMapNodesTableCreateCompanionBuilder,
      $$MindMapNodesTableUpdateCompanionBuilder,
      (MindMapNode, $$MindMapNodesTableReferences),
      MindMapNode,
      PrefetchHooks Function({bool mapId})
    >;
typedef $$MindMapMetaTableCreateCompanionBuilder =
    MindMapMetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MindMapMetaTableUpdateCompanionBuilder =
    MindMapMetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MindMapMetaTableFilterComposer
    extends Composer<_$MindMapDatabase, $MindMapMetaTable> {
  $$MindMapMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MindMapMetaTableOrderingComposer
    extends Composer<_$MindMapDatabase, $MindMapMetaTable> {
  $$MindMapMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MindMapMetaTableAnnotationComposer
    extends Composer<_$MindMapDatabase, $MindMapMetaTable> {
  $$MindMapMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MindMapMetaTableTableManager
    extends
        RootTableManager<
          _$MindMapDatabase,
          $MindMapMetaTable,
          MindMapMetaData,
          $$MindMapMetaTableFilterComposer,
          $$MindMapMetaTableOrderingComposer,
          $$MindMapMetaTableAnnotationComposer,
          $$MindMapMetaTableCreateCompanionBuilder,
          $$MindMapMetaTableUpdateCompanionBuilder,
          (
            MindMapMetaData,
            BaseReferences<
              _$MindMapDatabase,
              $MindMapMetaTable,
              MindMapMetaData
            >,
          ),
          MindMapMetaData,
          PrefetchHooks Function()
        > {
  $$MindMapMetaTableTableManager(_$MindMapDatabase db, $MindMapMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MindMapMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MindMapMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MindMapMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MindMapMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MindMapMetaCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MindMapMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$MindMapDatabase,
      $MindMapMetaTable,
      MindMapMetaData,
      $$MindMapMetaTableFilterComposer,
      $$MindMapMetaTableOrderingComposer,
      $$MindMapMetaTableAnnotationComposer,
      $$MindMapMetaTableCreateCompanionBuilder,
      $$MindMapMetaTableUpdateCompanionBuilder,
      (
        MindMapMetaData,
        BaseReferences<_$MindMapDatabase, $MindMapMetaTable, MindMapMetaData>,
      ),
      MindMapMetaData,
      PrefetchHooks Function()
    >;

class $MindMapDatabaseManager {
  final _$MindMapDatabase _db;
  $MindMapDatabaseManager(this._db);
  $$MindMapsTableTableManager get mindMaps =>
      $$MindMapsTableTableManager(_db, _db.mindMaps);
  $$MindMapNodesTableTableManager get mindMapNodes =>
      $$MindMapNodesTableTableManager(_db, _db.mindMapNodes);
  $$MindMapMetaTableTableManager get mindMapMeta =>
      $$MindMapMetaTableTableManager(_db, _db.mindMapMeta);
}
