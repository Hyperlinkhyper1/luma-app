// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_library_database.dart';

// ignore_for_file: type=lint
class $LibrarySubjectsTable extends LibrarySubjects
    with TableInfo<$LibrarySubjectsTable, LibrarySubjectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibrarySubjectsTable(this.attachedDatabase, [this._alias]);
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
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
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
  @override
  List<GeneratedColumn> get $columns => [id, name, color, sortOrder, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_subjects';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibrarySubjectRow> instance, {
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
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
  LibrarySubjectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibrarySubjectRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LibrarySubjectsTable createAlias(String alias) {
    return $LibrarySubjectsTable(attachedDatabase, alias);
  }
}

class LibrarySubjectRow extends DataClass
    implements Insertable<LibrarySubjectRow> {
  final int id;
  final String name;

  /// Index into `DyeColor`.
  final int color;
  final int sortOrder;
  final DateTime createdAt;
  const LibrarySubjectRow({
    required this.id,
    required this.name,
    required this.color,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LibrarySubjectsCompanion toCompanion(bool nullToAbsent) {
    return LibrarySubjectsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory LibrarySubjectRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibrarySubjectRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LibrarySubjectRow copyWith({
    int? id,
    String? name,
    int? color,
    int? sortOrder,
    DateTime? createdAt,
  }) => LibrarySubjectRow(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  LibrarySubjectRow copyWithCompanion(LibrarySubjectsCompanion data) {
    return LibrarySubjectRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibrarySubjectRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibrarySubjectRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class LibrarySubjectsCompanion extends UpdateCompanion<LibrarySubjectRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> color;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const LibrarySubjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LibrarySubjectsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<LibrarySubjectRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LibrarySubjectsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? color,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return LibrarySubjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibrarySubjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LibraryTextsTable extends LibraryTexts
    with TableInfo<$LibraryTextsTable, LibraryTextRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryTextsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spineMeta = const VerificationMeta('spine');
  @override
  late final GeneratedColumn<String> spine = GeneratedColumn<String>(
    'spine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<int> cover = GeneratedColumn<int>(
    'cover',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(12),
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
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
    subjectId,
    title,
    spine,
    body,
    cover,
    slot,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_texts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryTextRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('spine')) {
      context.handle(
        _spineMeta,
        spine.isAcceptableOrUnknown(data['spine']!, _spineMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
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
  LibraryTextRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryTextRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      spine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spine'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cover'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
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
  $LibraryTextsTable createAlias(String alias) {
    return $LibraryTextsTable(attachedDatabase, alias);
  }
}

class LibraryTextRow extends DataClass implements Insertable<LibraryTextRow> {
  final int id;

  /// The owning subject. Not a foreign key: a synced import can bring texts
  /// in before their subject, and the repository deletes a subject's texts
  /// itself.
  final int subjectId;
  final String title;
  final String spine;

  /// A `RichDoc` as JSON.
  final String body;

  /// Index into `DyeColor`; 12 is brown leather.
  final int cover;
  final int slot;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LibraryTextRow({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.spine,
    required this.body,
    required this.cover,
    required this.slot,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_id'] = Variable<int>(subjectId);
    map['title'] = Variable<String>(title);
    map['spine'] = Variable<String>(spine);
    map['body'] = Variable<String>(body);
    map['cover'] = Variable<int>(cover);
    map['slot'] = Variable<int>(slot);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LibraryTextsCompanion toCompanion(bool nullToAbsent) {
    return LibraryTextsCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      title: Value(title),
      spine: Value(spine),
      body: Value(body),
      cover: Value(cover),
      slot: Value(slot),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LibraryTextRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryTextRow(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      title: serializer.fromJson<String>(json['title']),
      spine: serializer.fromJson<String>(json['spine']),
      body: serializer.fromJson<String>(json['body']),
      cover: serializer.fromJson<int>(json['cover']),
      slot: serializer.fromJson<int>(json['slot']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int>(subjectId),
      'title': serializer.toJson<String>(title),
      'spine': serializer.toJson<String>(spine),
      'body': serializer.toJson<String>(body),
      'cover': serializer.toJson<int>(cover),
      'slot': serializer.toJson<int>(slot),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LibraryTextRow copyWith({
    int? id,
    int? subjectId,
    String? title,
    String? spine,
    String? body,
    int? cover,
    int? slot,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LibraryTextRow(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    title: title ?? this.title,
    spine: spine ?? this.spine,
    body: body ?? this.body,
    cover: cover ?? this.cover,
    slot: slot ?? this.slot,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LibraryTextRow copyWithCompanion(LibraryTextsCompanion data) {
    return LibraryTextRow(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      title: data.title.present ? data.title.value : this.title,
      spine: data.spine.present ? data.spine.value : this.spine,
      body: data.body.present ? data.body.value : this.body,
      cover: data.cover.present ? data.cover.value : this.cover,
      slot: data.slot.present ? data.slot.value : this.slot,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryTextRow(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('title: $title, ')
          ..write('spine: $spine, ')
          ..write('body: $body, ')
          ..write('cover: $cover, ')
          ..write('slot: $slot, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subjectId,
    title,
    spine,
    body,
    cover,
    slot,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryTextRow &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.title == this.title &&
          other.spine == this.spine &&
          other.body == this.body &&
          other.cover == this.cover &&
          other.slot == this.slot &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LibraryTextsCompanion extends UpdateCompanion<LibraryTextRow> {
  final Value<int> id;
  final Value<int> subjectId;
  final Value<String> title;
  final Value<String> spine;
  final Value<String> body;
  final Value<int> cover;
  final Value<int> slot;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const LibraryTextsCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.title = const Value.absent(),
    this.spine = const Value.absent(),
    this.body = const Value.absent(),
    this.cover = const Value.absent(),
    this.slot = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LibraryTextsCompanion.insert({
    this.id = const Value.absent(),
    required int subjectId,
    required String title,
    this.spine = const Value.absent(),
    this.body = const Value.absent(),
    this.cover = const Value.absent(),
    this.slot = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : subjectId = Value(subjectId),
       title = Value(title);
  static Insertable<LibraryTextRow> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<String>? title,
    Expression<String>? spine,
    Expression<String>? body,
    Expression<int>? cover,
    Expression<int>? slot,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (title != null) 'title': title,
      if (spine != null) 'spine': spine,
      if (body != null) 'body': body,
      if (cover != null) 'cover': cover,
      if (slot != null) 'slot': slot,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LibraryTextsCompanion copyWith({
    Value<int>? id,
    Value<int>? subjectId,
    Value<String>? title,
    Value<String>? spine,
    Value<String>? body,
    Value<int>? cover,
    Value<int>? slot,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return LibraryTextsCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      spine: spine ?? this.spine,
      body: body ?? this.body,
      cover: cover ?? this.cover,
      slot: slot ?? this.slot,
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
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (spine.present) {
      map['spine'] = Variable<String>(spine.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (cover.present) {
      map['cover'] = Variable<int>(cover.value);
    }
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
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
    return (StringBuffer('LibraryTextsCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('title: $title, ')
          ..write('spine: $spine, ')
          ..write('body: $body, ')
          ..write('cover: $cover, ')
          ..write('slot: $slot, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$TextLibraryDatabase extends GeneratedDatabase {
  _$TextLibraryDatabase(QueryExecutor e) : super(e);
  $TextLibraryDatabaseManager get managers => $TextLibraryDatabaseManager(this);
  late final $LibrarySubjectsTable librarySubjects = $LibrarySubjectsTable(
    this,
  );
  late final $LibraryTextsTable libraryTexts = $LibraryTextsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    librarySubjects,
    libraryTexts,
  ];
}

typedef $$LibrarySubjectsTableCreateCompanionBuilder =
    LibrarySubjectsCompanion Function({
      Value<int> id,
      required String name,
      Value<int> color,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });
typedef $$LibrarySubjectsTableUpdateCompanionBuilder =
    LibrarySubjectsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> color,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });

class $$LibrarySubjectsTableFilterComposer
    extends Composer<_$TextLibraryDatabase, $LibrarySubjectsTable> {
  $$LibrarySubjectsTableFilterComposer({
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

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibrarySubjectsTableOrderingComposer
    extends Composer<_$TextLibraryDatabase, $LibrarySubjectsTable> {
  $$LibrarySubjectsTableOrderingComposer({
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

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibrarySubjectsTableAnnotationComposer
    extends Composer<_$TextLibraryDatabase, $LibrarySubjectsTable> {
  $$LibrarySubjectsTableAnnotationComposer({
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

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LibrarySubjectsTableTableManager
    extends
        RootTableManager<
          _$TextLibraryDatabase,
          $LibrarySubjectsTable,
          LibrarySubjectRow,
          $$LibrarySubjectsTableFilterComposer,
          $$LibrarySubjectsTableOrderingComposer,
          $$LibrarySubjectsTableAnnotationComposer,
          $$LibrarySubjectsTableCreateCompanionBuilder,
          $$LibrarySubjectsTableUpdateCompanionBuilder,
          (
            LibrarySubjectRow,
            BaseReferences<
              _$TextLibraryDatabase,
              $LibrarySubjectsTable,
              LibrarySubjectRow
            >,
          ),
          LibrarySubjectRow,
          PrefetchHooks Function()
        > {
  $$LibrarySubjectsTableTableManager(
    _$TextLibraryDatabase db,
    $LibrarySubjectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibrarySubjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibrarySubjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibrarySubjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LibrarySubjectsCompanion(
                id: id,
                name: name,
                color: color,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LibrarySubjectsCompanion.insert(
                id: id,
                name: name,
                color: color,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibrarySubjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$TextLibraryDatabase,
      $LibrarySubjectsTable,
      LibrarySubjectRow,
      $$LibrarySubjectsTableFilterComposer,
      $$LibrarySubjectsTableOrderingComposer,
      $$LibrarySubjectsTableAnnotationComposer,
      $$LibrarySubjectsTableCreateCompanionBuilder,
      $$LibrarySubjectsTableUpdateCompanionBuilder,
      (
        LibrarySubjectRow,
        BaseReferences<
          _$TextLibraryDatabase,
          $LibrarySubjectsTable,
          LibrarySubjectRow
        >,
      ),
      LibrarySubjectRow,
      PrefetchHooks Function()
    >;
typedef $$LibraryTextsTableCreateCompanionBuilder =
    LibraryTextsCompanion Function({
      Value<int> id,
      required int subjectId,
      required String title,
      Value<String> spine,
      Value<String> body,
      Value<int> cover,
      Value<int> slot,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$LibraryTextsTableUpdateCompanionBuilder =
    LibraryTextsCompanion Function({
      Value<int> id,
      Value<int> subjectId,
      Value<String> title,
      Value<String> spine,
      Value<String> body,
      Value<int> cover,
      Value<int> slot,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$LibraryTextsTableFilterComposer
    extends Composer<_$TextLibraryDatabase, $LibraryTextsTable> {
  $$LibraryTextsTableFilterComposer({
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

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spine => $composableBuilder(
    column: $table.spine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get slot => $composableBuilder(
    column: $table.slot,
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

class $$LibraryTextsTableOrderingComposer
    extends Composer<_$TextLibraryDatabase, $LibraryTextsTable> {
  $$LibraryTextsTableOrderingComposer({
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

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spine => $composableBuilder(
    column: $table.spine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get slot => $composableBuilder(
    column: $table.slot,
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

class $$LibraryTextsTableAnnotationComposer
    extends Composer<_$TextLibraryDatabase, $LibraryTextsTable> {
  $$LibraryTextsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get spine =>
      $composableBuilder(column: $table.spine, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<int> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LibraryTextsTableTableManager
    extends
        RootTableManager<
          _$TextLibraryDatabase,
          $LibraryTextsTable,
          LibraryTextRow,
          $$LibraryTextsTableFilterComposer,
          $$LibraryTextsTableOrderingComposer,
          $$LibraryTextsTableAnnotationComposer,
          $$LibraryTextsTableCreateCompanionBuilder,
          $$LibraryTextsTableUpdateCompanionBuilder,
          (
            LibraryTextRow,
            BaseReferences<
              _$TextLibraryDatabase,
              $LibraryTextsTable,
              LibraryTextRow
            >,
          ),
          LibraryTextRow,
          PrefetchHooks Function()
        > {
  $$LibraryTextsTableTableManager(
    _$TextLibraryDatabase db,
    $LibraryTextsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryTextsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryTextsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryTextsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> spine = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> cover = const Value.absent(),
                Value<int> slot = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LibraryTextsCompanion(
                id: id,
                subjectId: subjectId,
                title: title,
                spine: spine,
                body: body,
                cover: cover,
                slot: slot,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subjectId,
                required String title,
                Value<String> spine = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> cover = const Value.absent(),
                Value<int> slot = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LibraryTextsCompanion.insert(
                id: id,
                subjectId: subjectId,
                title: title,
                spine: spine,
                body: body,
                cover: cover,
                slot: slot,
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

typedef $$LibraryTextsTableProcessedTableManager =
    ProcessedTableManager<
      _$TextLibraryDatabase,
      $LibraryTextsTable,
      LibraryTextRow,
      $$LibraryTextsTableFilterComposer,
      $$LibraryTextsTableOrderingComposer,
      $$LibraryTextsTableAnnotationComposer,
      $$LibraryTextsTableCreateCompanionBuilder,
      $$LibraryTextsTableUpdateCompanionBuilder,
      (
        LibraryTextRow,
        BaseReferences<
          _$TextLibraryDatabase,
          $LibraryTextsTable,
          LibraryTextRow
        >,
      ),
      LibraryTextRow,
      PrefetchHooks Function()
    >;

class $TextLibraryDatabaseManager {
  final _$TextLibraryDatabase _db;
  $TextLibraryDatabaseManager(this._db);
  $$LibrarySubjectsTableTableManager get librarySubjects =>
      $$LibrarySubjectsTableTableManager(_db, _db.librarySubjects);
  $$LibraryTextsTableTableManager get libraryTexts =>
      $$LibraryTextsTableTableManager(_db, _db.libraryTexts);
}
