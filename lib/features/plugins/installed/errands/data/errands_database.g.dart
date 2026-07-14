// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'errands_database.dart';

// ignore_for_file: type=lint
class $ErrandCategoriesTable extends ErrandCategories
    with TableInfo<$ErrandCategoriesTable, ErrandCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ErrandCategoriesTable(this.attachedDatabase, [this._alias]);
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
      maxTextLength: 80,
    ),
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
    defaultValue: const Constant(0xFF2F80ED),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
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
  List<GeneratedColumn> get $columns => [id, name, color, position, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'errand_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<ErrandCategory> instance, {
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
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
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
  ErrandCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ErrandCategory(
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
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ErrandCategoriesTable createAlias(String alias) {
    return $ErrandCategoriesTable(attachedDatabase, alias);
  }
}

class ErrandCategory extends DataClass implements Insertable<ErrandCategory> {
  final int id;
  final String name;

  /// ARGB accent color for the category's dot / section header.
  final int color;

  /// Manual ordering in the checklist; lower comes first.
  final int position;
  final DateTime createdAt;
  const ErrandCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    map['position'] = Variable<int>(position);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ErrandCategoriesCompanion toCompanion(bool nullToAbsent) {
    return ErrandCategoriesCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      position: Value(position),
      createdAt: Value(createdAt),
    );
  }

  factory ErrandCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ErrandCategory(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      position: serializer.fromJson<int>(json['position']),
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
      'position': serializer.toJson<int>(position),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ErrandCategory copyWith({
    int? id,
    String? name,
    int? color,
    int? position,
    DateTime? createdAt,
  }) => ErrandCategory(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    position: position ?? this.position,
    createdAt: createdAt ?? this.createdAt,
  );
  ErrandCategory copyWithCompanion(ErrandCategoriesCompanion data) {
    return ErrandCategory(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      position: data.position.present ? data.position.value : this.position,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ErrandCategory(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, position, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ErrandCategory &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.position == this.position &&
          other.createdAt == this.createdAt);
}

class ErrandCategoriesCompanion extends UpdateCompanion<ErrandCategory> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> color;
  final Value<int> position;
  final Value<DateTime> createdAt;
  const ErrandCategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ErrandCategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<ErrandCategory> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<int>? position,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (position != null) 'position': position,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ErrandCategoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? color,
    Value<int>? position,
    Value<DateTime>? createdAt,
  }) {
    return ErrandCategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      position: position ?? this.position,
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
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ErrandCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ErrandsTable extends Errands with TableInfo<$ErrandsTable, Errand> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ErrandsTable(this.attachedDatabase, [this._alias]);
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
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repeatUnitMeta = const VerificationMeta(
    'repeatUnit',
  );
  @override
  late final GeneratedColumn<String> repeatUnit = GeneratedColumn<String>(
    'repeat_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('days'),
  );
  static const VerificationMeta _repeatEveryMeta = const VerificationMeta(
    'repeatEvery',
  );
  @override
  late final GeneratedColumn<int> repeatEvery = GeneratedColumn<int>(
    'repeat_every',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _nextDueMeta = const VerificationMeta(
    'nextDue',
  );
  @override
  late final GeneratedColumn<DateTime> nextDue = GeneratedColumn<DateTime>(
    'next_due',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastDoneMeta = const VerificationMeta(
    'lastDone',
  );
  @override
  late final GeneratedColumn<DateTime> lastDone = GeneratedColumn<DateTime>(
    'last_done',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    categoryId,
    repeatUnit,
    repeatEvery,
    nextDue,
    lastDone,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'errands';
  @override
  VerificationContext validateIntegrity(
    Insertable<Errand> instance, {
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
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('repeat_unit')) {
      context.handle(
        _repeatUnitMeta,
        repeatUnit.isAcceptableOrUnknown(data['repeat_unit']!, _repeatUnitMeta),
      );
    }
    if (data.containsKey('repeat_every')) {
      context.handle(
        _repeatEveryMeta,
        repeatEvery.isAcceptableOrUnknown(
          data['repeat_every']!,
          _repeatEveryMeta,
        ),
      );
    }
    if (data.containsKey('next_due')) {
      context.handle(
        _nextDueMeta,
        nextDue.isAcceptableOrUnknown(data['next_due']!, _nextDueMeta),
      );
    } else if (isInserting) {
      context.missing(_nextDueMeta);
    }
    if (data.containsKey('last_done')) {
      context.handle(
        _lastDoneMeta,
        lastDone.isAcceptableOrUnknown(data['last_done']!, _lastDoneMeta),
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
  Errand map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Errand(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      repeatUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_unit'],
      )!,
      repeatEvery: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_every'],
      )!,
      nextDue: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_due'],
      )!,
      lastDone: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_done'],
      ),
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
  $ErrandsTable createAlias(String alias) {
    return $ErrandsTable(attachedDatabase, alias);
  }
}

class Errand extends DataClass implements Insertable<Errand> {
  final int id;
  final String name;

  /// References [ErrandCategories.id]; null = uncategorized. Kept as a plain
  /// int (no FK constraint) so category deletion can simply null it out.
  final int? categoryId;
  final String repeatUnit;
  final int repeatEvery;

  /// The next date this errand appears on the checklist (stored at local
  /// midnight; anything <= today counts as due).
  final DateTime nextDue;

  /// When it was last checked off; used to show it under "Done today" and
  /// allow unchecking.
  final DateTime? lastDone;
  final String? notes;
  final DateTime createdAt;
  const Errand({
    required this.id,
    required this.name,
    this.categoryId,
    required this.repeatUnit,
    required this.repeatEvery,
    required this.nextDue,
    this.lastDone,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['repeat_unit'] = Variable<String>(repeatUnit);
    map['repeat_every'] = Variable<int>(repeatEvery);
    map['next_due'] = Variable<DateTime>(nextDue);
    if (!nullToAbsent || lastDone != null) {
      map['last_done'] = Variable<DateTime>(lastDone);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ErrandsCompanion toCompanion(bool nullToAbsent) {
    return ErrandsCompanion(
      id: Value(id),
      name: Value(name),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      repeatUnit: Value(repeatUnit),
      repeatEvery: Value(repeatEvery),
      nextDue: Value(nextDue),
      lastDone: lastDone == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDone),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory Errand.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Errand(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      repeatUnit: serializer.fromJson<String>(json['repeatUnit']),
      repeatEvery: serializer.fromJson<int>(json['repeatEvery']),
      nextDue: serializer.fromJson<DateTime>(json['nextDue']),
      lastDone: serializer.fromJson<DateTime?>(json['lastDone']),
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
      'categoryId': serializer.toJson<int?>(categoryId),
      'repeatUnit': serializer.toJson<String>(repeatUnit),
      'repeatEvery': serializer.toJson<int>(repeatEvery),
      'nextDue': serializer.toJson<DateTime>(nextDue),
      'lastDone': serializer.toJson<DateTime?>(lastDone),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Errand copyWith({
    int? id,
    String? name,
    Value<int?> categoryId = const Value.absent(),
    String? repeatUnit,
    int? repeatEvery,
    DateTime? nextDue,
    Value<DateTime?> lastDone = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => Errand(
    id: id ?? this.id,
    name: name ?? this.name,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    repeatUnit: repeatUnit ?? this.repeatUnit,
    repeatEvery: repeatEvery ?? this.repeatEvery,
    nextDue: nextDue ?? this.nextDue,
    lastDone: lastDone.present ? lastDone.value : this.lastDone,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  Errand copyWithCompanion(ErrandsCompanion data) {
    return Errand(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      repeatUnit: data.repeatUnit.present
          ? data.repeatUnit.value
          : this.repeatUnit,
      repeatEvery: data.repeatEvery.present
          ? data.repeatEvery.value
          : this.repeatEvery,
      nextDue: data.nextDue.present ? data.nextDue.value : this.nextDue,
      lastDone: data.lastDone.present ? data.lastDone.value : this.lastDone,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Errand(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('repeatUnit: $repeatUnit, ')
          ..write('repeatEvery: $repeatEvery, ')
          ..write('nextDue: $nextDue, ')
          ..write('lastDone: $lastDone, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    categoryId,
    repeatUnit,
    repeatEvery,
    nextDue,
    lastDone,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Errand &&
          other.id == this.id &&
          other.name == this.name &&
          other.categoryId == this.categoryId &&
          other.repeatUnit == this.repeatUnit &&
          other.repeatEvery == this.repeatEvery &&
          other.nextDue == this.nextDue &&
          other.lastDone == this.lastDone &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class ErrandsCompanion extends UpdateCompanion<Errand> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> categoryId;
  final Value<String> repeatUnit;
  final Value<int> repeatEvery;
  final Value<DateTime> nextDue;
  final Value<DateTime?> lastDone;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const ErrandsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.repeatUnit = const Value.absent(),
    this.repeatEvery = const Value.absent(),
    this.nextDue = const Value.absent(),
    this.lastDone = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ErrandsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.categoryId = const Value.absent(),
    this.repeatUnit = const Value.absent(),
    this.repeatEvery = const Value.absent(),
    required DateTime nextDue,
    this.lastDone = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       nextDue = Value(nextDue);
  static Insertable<Errand> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? categoryId,
    Expression<String>? repeatUnit,
    Expression<int>? repeatEvery,
    Expression<DateTime>? nextDue,
    Expression<DateTime>? lastDone,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (categoryId != null) 'category_id': categoryId,
      if (repeatUnit != null) 'repeat_unit': repeatUnit,
      if (repeatEvery != null) 'repeat_every': repeatEvery,
      if (nextDue != null) 'next_due': nextDue,
      if (lastDone != null) 'last_done': lastDone,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ErrandsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? categoryId,
    Value<String>? repeatUnit,
    Value<int>? repeatEvery,
    Value<DateTime>? nextDue,
    Value<DateTime?>? lastDone,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
  }) {
    return ErrandsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      repeatUnit: repeatUnit ?? this.repeatUnit,
      repeatEvery: repeatEvery ?? this.repeatEvery,
      nextDue: nextDue ?? this.nextDue,
      lastDone: lastDone ?? this.lastDone,
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
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (repeatUnit.present) {
      map['repeat_unit'] = Variable<String>(repeatUnit.value);
    }
    if (repeatEvery.present) {
      map['repeat_every'] = Variable<int>(repeatEvery.value);
    }
    if (nextDue.present) {
      map['next_due'] = Variable<DateTime>(nextDue.value);
    }
    if (lastDone.present) {
      map['last_done'] = Variable<DateTime>(lastDone.value);
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
    return (StringBuffer('ErrandsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('repeatUnit: $repeatUnit, ')
          ..write('repeatEvery: $repeatEvery, ')
          ..write('nextDue: $nextDue, ')
          ..write('lastDone: $lastDone, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$ErrandsDatabase extends GeneratedDatabase {
  _$ErrandsDatabase(QueryExecutor e) : super(e);
  $ErrandsDatabaseManager get managers => $ErrandsDatabaseManager(this);
  late final $ErrandCategoriesTable errandCategories = $ErrandCategoriesTable(
    this,
  );
  late final $ErrandsTable errands = $ErrandsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    errandCategories,
    errands,
  ];
}

typedef $$ErrandCategoriesTableCreateCompanionBuilder =
    ErrandCategoriesCompanion Function({
      Value<int> id,
      required String name,
      Value<int> color,
      Value<int> position,
      Value<DateTime> createdAt,
    });
typedef $$ErrandCategoriesTableUpdateCompanionBuilder =
    ErrandCategoriesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> color,
      Value<int> position,
      Value<DateTime> createdAt,
    });

class $$ErrandCategoriesTableFilterComposer
    extends Composer<_$ErrandsDatabase, $ErrandCategoriesTable> {
  $$ErrandCategoriesTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ErrandCategoriesTableOrderingComposer
    extends Composer<_$ErrandsDatabase, $ErrandCategoriesTable> {
  $$ErrandCategoriesTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ErrandCategoriesTableAnnotationComposer
    extends Composer<_$ErrandsDatabase, $ErrandCategoriesTable> {
  $$ErrandCategoriesTableAnnotationComposer({
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

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ErrandCategoriesTableTableManager
    extends
        RootTableManager<
          _$ErrandsDatabase,
          $ErrandCategoriesTable,
          ErrandCategory,
          $$ErrandCategoriesTableFilterComposer,
          $$ErrandCategoriesTableOrderingComposer,
          $$ErrandCategoriesTableAnnotationComposer,
          $$ErrandCategoriesTableCreateCompanionBuilder,
          $$ErrandCategoriesTableUpdateCompanionBuilder,
          (
            ErrandCategory,
            BaseReferences<
              _$ErrandsDatabase,
              $ErrandCategoriesTable,
              ErrandCategory
            >,
          ),
          ErrandCategory,
          PrefetchHooks Function()
        > {
  $$ErrandCategoriesTableTableManager(
    _$ErrandsDatabase db,
    $ErrandCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ErrandCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ErrandCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ErrandCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ErrandCategoriesCompanion(
                id: id,
                name: name,
                color: color,
                position: position,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> color = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ErrandCategoriesCompanion.insert(
                id: id,
                name: name,
                color: color,
                position: position,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ErrandCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$ErrandsDatabase,
      $ErrandCategoriesTable,
      ErrandCategory,
      $$ErrandCategoriesTableFilterComposer,
      $$ErrandCategoriesTableOrderingComposer,
      $$ErrandCategoriesTableAnnotationComposer,
      $$ErrandCategoriesTableCreateCompanionBuilder,
      $$ErrandCategoriesTableUpdateCompanionBuilder,
      (
        ErrandCategory,
        BaseReferences<
          _$ErrandsDatabase,
          $ErrandCategoriesTable,
          ErrandCategory
        >,
      ),
      ErrandCategory,
      PrefetchHooks Function()
    >;
typedef $$ErrandsTableCreateCompanionBuilder =
    ErrandsCompanion Function({
      Value<int> id,
      required String name,
      Value<int?> categoryId,
      Value<String> repeatUnit,
      Value<int> repeatEvery,
      required DateTime nextDue,
      Value<DateTime?> lastDone,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });
typedef $$ErrandsTableUpdateCompanionBuilder =
    ErrandsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int?> categoryId,
      Value<String> repeatUnit,
      Value<int> repeatEvery,
      Value<DateTime> nextDue,
      Value<DateTime?> lastDone,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });

class $$ErrandsTableFilterComposer
    extends Composer<_$ErrandsDatabase, $ErrandsTable> {
  $$ErrandsTableFilterComposer({
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

  ColumnFilters<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatUnit => $composableBuilder(
    column: $table.repeatUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatEvery => $composableBuilder(
    column: $table.repeatEvery,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextDue => $composableBuilder(
    column: $table.nextDue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastDone => $composableBuilder(
    column: $table.lastDone,
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

class $$ErrandsTableOrderingComposer
    extends Composer<_$ErrandsDatabase, $ErrandsTable> {
  $$ErrandsTableOrderingComposer({
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

  ColumnOrderings<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatUnit => $composableBuilder(
    column: $table.repeatUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatEvery => $composableBuilder(
    column: $table.repeatEvery,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextDue => $composableBuilder(
    column: $table.nextDue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastDone => $composableBuilder(
    column: $table.lastDone,
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

class $$ErrandsTableAnnotationComposer
    extends Composer<_$ErrandsDatabase, $ErrandsTable> {
  $$ErrandsTableAnnotationComposer({
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

  GeneratedColumn<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repeatUnit => $composableBuilder(
    column: $table.repeatUnit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repeatEvery => $composableBuilder(
    column: $table.repeatEvery,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextDue =>
      $composableBuilder(column: $table.nextDue, builder: (column) => column);

  GeneratedColumn<DateTime> get lastDone =>
      $composableBuilder(column: $table.lastDone, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ErrandsTableTableManager
    extends
        RootTableManager<
          _$ErrandsDatabase,
          $ErrandsTable,
          Errand,
          $$ErrandsTableFilterComposer,
          $$ErrandsTableOrderingComposer,
          $$ErrandsTableAnnotationComposer,
          $$ErrandsTableCreateCompanionBuilder,
          $$ErrandsTableUpdateCompanionBuilder,
          (Errand, BaseReferences<_$ErrandsDatabase, $ErrandsTable, Errand>),
          Errand,
          PrefetchHooks Function()
        > {
  $$ErrandsTableTableManager(_$ErrandsDatabase db, $ErrandsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ErrandsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ErrandsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ErrandsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String> repeatUnit = const Value.absent(),
                Value<int> repeatEvery = const Value.absent(),
                Value<DateTime> nextDue = const Value.absent(),
                Value<DateTime?> lastDone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ErrandsCompanion(
                id: id,
                name: name,
                categoryId: categoryId,
                repeatUnit: repeatUnit,
                repeatEvery: repeatEvery,
                nextDue: nextDue,
                lastDone: lastDone,
                notes: notes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> categoryId = const Value.absent(),
                Value<String> repeatUnit = const Value.absent(),
                Value<int> repeatEvery = const Value.absent(),
                required DateTime nextDue,
                Value<DateTime?> lastDone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ErrandsCompanion.insert(
                id: id,
                name: name,
                categoryId: categoryId,
                repeatUnit: repeatUnit,
                repeatEvery: repeatEvery,
                nextDue: nextDue,
                lastDone: lastDone,
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

typedef $$ErrandsTableProcessedTableManager =
    ProcessedTableManager<
      _$ErrandsDatabase,
      $ErrandsTable,
      Errand,
      $$ErrandsTableFilterComposer,
      $$ErrandsTableOrderingComposer,
      $$ErrandsTableAnnotationComposer,
      $$ErrandsTableCreateCompanionBuilder,
      $$ErrandsTableUpdateCompanionBuilder,
      (Errand, BaseReferences<_$ErrandsDatabase, $ErrandsTable, Errand>),
      Errand,
      PrefetchHooks Function()
    >;

class $ErrandsDatabaseManager {
  final _$ErrandsDatabase _db;
  $ErrandsDatabaseManager(this._db);
  $$ErrandCategoriesTableTableManager get errandCategories =>
      $$ErrandCategoriesTableTableManager(_db, _db.errandCategories);
  $$ErrandsTableTableManager get errands =>
      $$ErrandsTableTableManager(_db, _db.errands);
}
