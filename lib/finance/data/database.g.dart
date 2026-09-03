// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
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
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconCodepointMeta = const VerificationMeta(
    'iconCodepoint',
  );
  @override
  late final GeneratedColumn<int> iconCodepoint = GeneratedColumn<int>(
    'icon_codepoint',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, colorValue, iconCodepoint];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
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
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('icon_codepoint')) {
      context.handle(
        _iconCodepointMeta,
        iconCodepoint.isAcceptableOrUnknown(
          data['icon_codepoint']!,
          _iconCodepointMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_iconCodepointMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      iconCodepoint: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}icon_codepoint'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;
  final int colorValue;
  final int iconCodepoint;
  const Category({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodepoint,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    map['icon_codepoint'] = Variable<int>(iconCodepoint);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      colorValue: Value(colorValue),
      iconCodepoint: Value(iconCodepoint),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      iconCodepoint: serializer.fromJson<int>(json['iconCodepoint']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'iconCodepoint': serializer.toJson<int>(iconCodepoint),
    };
  }

  Category copyWith({
    int? id,
    String? name,
    int? colorValue,
    int? iconCodepoint,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    iconCodepoint: iconCodepoint ?? this.iconCodepoint,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      iconCodepoint: data.iconCodepoint.present
          ? data.iconCodepoint.value
          : this.iconCodepoint,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconCodepoint: $iconCodepoint')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorValue, iconCodepoint);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.iconCodepoint == this.iconCodepoint);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<int> iconCodepoint;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.iconCodepoint = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int colorValue,
    required int iconCodepoint,
  }) : name = Value(name),
       colorValue = Value(colorValue),
       iconCodepoint = Value(iconCodepoint);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<int>? iconCodepoint,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (iconCodepoint != null) 'icon_codepoint': iconCodepoint,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? colorValue,
    Value<int>? iconCodepoint,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconCodepoint: iconCodepoint ?? this.iconCodepoint,
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
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (iconCodepoint.present) {
      map['icon_codepoint'] = Variable<int>(iconCodepoint.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconCodepoint: $iconCodepoint')
          ..write(')'))
        .toString();
  }
}

class $MerchantsTable extends Merchants
    with TableInfo<$MerchantsTable, Merchant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MerchantsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _defaultCategoryIdMeta = const VerificationMeta(
    'defaultCategoryId',
  );
  @override
  late final GeneratedColumn<int> defaultCategoryId = GeneratedColumn<int>(
    'default_category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, defaultCategoryId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'merchants';
  @override
  VerificationContext validateIntegrity(
    Insertable<Merchant> instance, {
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
    if (data.containsKey('default_category_id')) {
      context.handle(
        _defaultCategoryIdMeta,
        defaultCategoryId.isAcceptableOrUnknown(
          data['default_category_id']!,
          _defaultCategoryIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Merchant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Merchant(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      defaultCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_category_id'],
      ),
    );
  }

  @override
  $MerchantsTable createAlias(String alias) {
    return $MerchantsTable(attachedDatabase, alias);
  }
}

class Merchant extends DataClass implements Insertable<Merchant> {
  final int id;
  final String name;
  final int? defaultCategoryId;
  const Merchant({
    required this.id,
    required this.name,
    this.defaultCategoryId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || defaultCategoryId != null) {
      map['default_category_id'] = Variable<int>(defaultCategoryId);
    }
    return map;
  }

  MerchantsCompanion toCompanion(bool nullToAbsent) {
    return MerchantsCompanion(
      id: Value(id),
      name: Value(name),
      defaultCategoryId: defaultCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultCategoryId),
    );
  }

  factory Merchant.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Merchant(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      defaultCategoryId: serializer.fromJson<int?>(json['defaultCategoryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'defaultCategoryId': serializer.toJson<int?>(defaultCategoryId),
    };
  }

  Merchant copyWith({
    int? id,
    String? name,
    Value<int?> defaultCategoryId = const Value.absent(),
  }) => Merchant(
    id: id ?? this.id,
    name: name ?? this.name,
    defaultCategoryId: defaultCategoryId.present
        ? defaultCategoryId.value
        : this.defaultCategoryId,
  );
  Merchant copyWithCompanion(MerchantsCompanion data) {
    return Merchant(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      defaultCategoryId: data.defaultCategoryId.present
          ? data.defaultCategoryId.value
          : this.defaultCategoryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Merchant(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('defaultCategoryId: $defaultCategoryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, defaultCategoryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Merchant &&
          other.id == this.id &&
          other.name == this.name &&
          other.defaultCategoryId == this.defaultCategoryId);
}

class MerchantsCompanion extends UpdateCompanion<Merchant> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> defaultCategoryId;
  const MerchantsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.defaultCategoryId = const Value.absent(),
  });
  MerchantsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.defaultCategoryId = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Merchant> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? defaultCategoryId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (defaultCategoryId != null) 'default_category_id': defaultCategoryId,
    });
  }

  MerchantsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? defaultCategoryId,
  }) {
    return MerchantsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultCategoryId: defaultCategoryId ?? this.defaultCategoryId,
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
    if (defaultCategoryId.present) {
      map['default_category_id'] = Variable<int>(defaultCategoryId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MerchantsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('defaultCategoryId: $defaultCategoryId')
          ..write(')'))
        .toString();
  }
}

class $PotsTable extends Pots with TableInfo<$PotsTable, Pot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PotsTable(this.attachedDatabase, [this._alias]);
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
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconCodepointMeta = const VerificationMeta(
    'iconCodepoint',
  );
  @override
  late final GeneratedColumn<int> iconCodepoint = GeneratedColumn<int>(
    'icon_codepoint',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorValue,
    iconCodepoint,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pots';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pot> instance, {
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
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('icon_codepoint')) {
      context.handle(
        _iconCodepointMeta,
        iconCodepoint.isAcceptableOrUnknown(
          data['icon_codepoint']!,
          _iconCodepointMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_iconCodepointMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      iconCodepoint: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}icon_codepoint'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $PotsTable createAlias(String alias) {
    return $PotsTable(attachedDatabase, alias);
  }
}

class Pot extends DataClass implements Insertable<Pot> {
  final int id;
  final String name;
  final int colorValue;
  final int iconCodepoint;
  final int sortOrder;
  const Pot({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodepoint,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    map['icon_codepoint'] = Variable<int>(iconCodepoint);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  PotsCompanion toCompanion(bool nullToAbsent) {
    return PotsCompanion(
      id: Value(id),
      name: Value(name),
      colorValue: Value(colorValue),
      iconCodepoint: Value(iconCodepoint),
      sortOrder: Value(sortOrder),
    );
  }

  factory Pot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pot(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      iconCodepoint: serializer.fromJson<int>(json['iconCodepoint']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'iconCodepoint': serializer.toJson<int>(iconCodepoint),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Pot copyWith({
    int? id,
    String? name,
    int? colorValue,
    int? iconCodepoint,
    int? sortOrder,
  }) => Pot(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    iconCodepoint: iconCodepoint ?? this.iconCodepoint,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Pot copyWithCompanion(PotsCompanion data) {
    return Pot(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      iconCodepoint: data.iconCodepoint.present
          ? data.iconCodepoint.value
          : this.iconCodepoint,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pot(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconCodepoint: $iconCodepoint, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, colorValue, iconCodepoint, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pot &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.iconCodepoint == this.iconCodepoint &&
          other.sortOrder == this.sortOrder);
}

class PotsCompanion extends UpdateCompanion<Pot> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<int> iconCodepoint;
  final Value<int> sortOrder;
  const PotsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.iconCodepoint = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  PotsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int colorValue,
    required int iconCodepoint,
    this.sortOrder = const Value.absent(),
  }) : name = Value(name),
       colorValue = Value(colorValue),
       iconCodepoint = Value(iconCodepoint);
  static Insertable<Pot> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<int>? iconCodepoint,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (iconCodepoint != null) 'icon_codepoint': iconCodepoint,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  PotsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? colorValue,
    Value<int>? iconCodepoint,
    Value<int>? sortOrder,
  }) {
    return PotsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconCodepoint: iconCodepoint ?? this.iconCodepoint,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (iconCodepoint.present) {
      map['icon_codepoint'] = Variable<int>(iconCodepoint.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PotsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconCodepoint: $iconCodepoint, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $FinanceTransactionsTable extends FinanceTransactions
    with TableInfo<$FinanceTransactionsTable, FinanceTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FinanceTransactionsTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<TxnKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TxnKind>($FinanceTransactionsTable.$converterkind);
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  static const VerificationMeta _potIdMeta = const VerificationMeta('potId');
  @override
  late final GeneratedColumn<int> potId = GeneratedColumn<int>(
    'pot_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pots (id)',
    ),
  );
  static const VerificationMeta _merchantIdMeta = const VerificationMeta(
    'merchantId',
  );
  @override
  late final GeneratedColumn<int> merchantId = GeneratedColumn<int>(
    'merchant_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES merchants (id)',
    ),
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
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
    kind,
    amountCents,
    date,
    note,
    potId,
    merchantId,
    categoryId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'finance_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<FinanceTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('pot_id')) {
      context.handle(
        _potIdMeta,
        potId.isAcceptableOrUnknown(data['pot_id']!, _potIdMeta),
      );
    }
    if (data.containsKey('merchant_id')) {
      context.handle(
        _merchantIdMeta,
        merchantId.isAcceptableOrUnknown(data['merchant_id']!, _merchantIdMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
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
  FinanceTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FinanceTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: $FinanceTransactionsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      potId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pot_id'],
      ),
      merchantId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}merchant_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FinanceTransactionsTable createAlias(String alias) {
    return $FinanceTransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TxnKind, String, String> $converterkind =
      const EnumNameConverter<TxnKind>(TxnKind.values);
}

class FinanceTransaction extends DataClass
    implements Insertable<FinanceTransaction> {
  final int id;
  final TxnKind kind;
  final int amountCents;
  final DateTime date;
  final String? note;
  final int? potId;
  final int? merchantId;
  final int? categoryId;
  final DateTime createdAt;
  const FinanceTransaction({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.date,
    this.note,
    this.potId,
    this.merchantId,
    this.categoryId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['kind'] = Variable<String>(
        $FinanceTransactionsTable.$converterkind.toSql(kind),
      );
    }
    map['amount_cents'] = Variable<int>(amountCents);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || potId != null) {
      map['pot_id'] = Variable<int>(potId);
    }
    if (!nullToAbsent || merchantId != null) {
      map['merchant_id'] = Variable<int>(merchantId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FinanceTransactionsCompanion toCompanion(bool nullToAbsent) {
    return FinanceTransactionsCompanion(
      id: Value(id),
      kind: Value(kind),
      amountCents: Value(amountCents),
      date: Value(date),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      potId: potId == null && nullToAbsent
          ? const Value.absent()
          : Value(potId),
      merchantId: merchantId == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      createdAt: Value(createdAt),
    );
  }

  factory FinanceTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FinanceTransaction(
      id: serializer.fromJson<int>(json['id']),
      kind: $FinanceTransactionsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      date: serializer.fromJson<DateTime>(json['date']),
      note: serializer.fromJson<String?>(json['note']),
      potId: serializer.fromJson<int?>(json['potId']),
      merchantId: serializer.fromJson<int?>(json['merchantId']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(
        $FinanceTransactionsTable.$converterkind.toJson(kind),
      ),
      'amountCents': serializer.toJson<int>(amountCents),
      'date': serializer.toJson<DateTime>(date),
      'note': serializer.toJson<String?>(note),
      'potId': serializer.toJson<int?>(potId),
      'merchantId': serializer.toJson<int?>(merchantId),
      'categoryId': serializer.toJson<int?>(categoryId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FinanceTransaction copyWith({
    int? id,
    TxnKind? kind,
    int? amountCents,
    DateTime? date,
    Value<String?> note = const Value.absent(),
    Value<int?> potId = const Value.absent(),
    Value<int?> merchantId = const Value.absent(),
    Value<int?> categoryId = const Value.absent(),
    DateTime? createdAt,
  }) => FinanceTransaction(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    amountCents: amountCents ?? this.amountCents,
    date: date ?? this.date,
    note: note.present ? note.value : this.note,
    potId: potId.present ? potId.value : this.potId,
    merchantId: merchantId.present ? merchantId.value : this.merchantId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    createdAt: createdAt ?? this.createdAt,
  );
  FinanceTransaction copyWithCompanion(FinanceTransactionsCompanion data) {
    return FinanceTransaction(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      date: data.date.present ? data.date.value : this.date,
      note: data.note.present ? data.note.value : this.note,
      potId: data.potId.present ? data.potId.value : this.potId,
      merchantId: data.merchantId.present
          ? data.merchantId.value
          : this.merchantId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FinanceTransaction(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('amountCents: $amountCents, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('potId: $potId, ')
          ..write('merchantId: $merchantId, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    amountCents,
    date,
    note,
    potId,
    merchantId,
    categoryId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FinanceTransaction &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.amountCents == this.amountCents &&
          other.date == this.date &&
          other.note == this.note &&
          other.potId == this.potId &&
          other.merchantId == this.merchantId &&
          other.categoryId == this.categoryId &&
          other.createdAt == this.createdAt);
}

class FinanceTransactionsCompanion extends UpdateCompanion<FinanceTransaction> {
  final Value<int> id;
  final Value<TxnKind> kind;
  final Value<int> amountCents;
  final Value<DateTime> date;
  final Value<String?> note;
  final Value<int?> potId;
  final Value<int?> merchantId;
  final Value<int?> categoryId;
  final Value<DateTime> createdAt;
  const FinanceTransactionsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.date = const Value.absent(),
    this.note = const Value.absent(),
    this.potId = const Value.absent(),
    this.merchantId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FinanceTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required TxnKind kind,
    required int amountCents,
    required DateTime date,
    this.note = const Value.absent(),
    this.potId = const Value.absent(),
    this.merchantId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : kind = Value(kind),
       amountCents = Value(amountCents),
       date = Value(date);
  static Insertable<FinanceTransaction> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<int>? amountCents,
    Expression<DateTime>? date,
    Expression<String>? note,
    Expression<int>? potId,
    Expression<int>? merchantId,
    Expression<int>? categoryId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (amountCents != null) 'amount_cents': amountCents,
      if (date != null) 'date': date,
      if (note != null) 'note': note,
      if (potId != null) 'pot_id': potId,
      if (merchantId != null) 'merchant_id': merchantId,
      if (categoryId != null) 'category_id': categoryId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FinanceTransactionsCompanion copyWith({
    Value<int>? id,
    Value<TxnKind>? kind,
    Value<int>? amountCents,
    Value<DateTime>? date,
    Value<String?>? note,
    Value<int?>? potId,
    Value<int?>? merchantId,
    Value<int?>? categoryId,
    Value<DateTime>? createdAt,
  }) {
    return FinanceTransactionsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      amountCents: amountCents ?? this.amountCents,
      date: date ?? this.date,
      note: note ?? this.note,
      potId: potId ?? this.potId,
      merchantId: merchantId ?? this.merchantId,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $FinanceTransactionsTable.$converterkind.toSql(kind.value),
      );
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (potId.present) {
      map['pot_id'] = Variable<int>(potId.value);
    }
    if (merchantId.present) {
      map['merchant_id'] = Variable<int>(merchantId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FinanceTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('amountCents: $amountCents, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('potId: $potId, ')
          ..write('merchantId: $merchantId, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RecurringRulesTable extends RecurringRules
    with TableInfo<$RecurringRulesTable, RecurringRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringRulesTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<TxnKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TxnKind>($RecurringRulesTable.$converterkind);
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Cadence, String> cadence =
      GeneratedColumn<String>(
        'cadence',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Cadence>($RecurringRulesTable.$convertercadence);
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
  static const VerificationMeta _lastAppliedMeta = const VerificationMeta(
    'lastApplied',
  );
  @override
  late final GeneratedColumn<DateTime> lastApplied = GeneratedColumn<DateTime>(
    'last_applied',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _potIdMeta = const VerificationMeta('potId');
  @override
  late final GeneratedColumn<int> potId = GeneratedColumn<int>(
    'pot_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pots (id)',
    ),
  );
  static const VerificationMeta _merchantIdMeta = const VerificationMeta(
    'merchantId',
  );
  @override
  late final GeneratedColumn<int> merchantId = GeneratedColumn<int>(
    'merchant_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES merchants (id)',
    ),
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isBillMeta = const VerificationMeta('isBill');
  @override
  late final GeneratedColumn<bool> isBill = GeneratedColumn<bool>(
    'is_bill',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_bill" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    amountCents,
    cadence,
    nextDue,
    lastApplied,
    potId,
    merchantId,
    categoryId,
    active,
    isBill,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringRule> instance, {
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
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('next_due')) {
      context.handle(
        _nextDueMeta,
        nextDue.isAcceptableOrUnknown(data['next_due']!, _nextDueMeta),
      );
    } else if (isInserting) {
      context.missing(_nextDueMeta);
    }
    if (data.containsKey('last_applied')) {
      context.handle(
        _lastAppliedMeta,
        lastApplied.isAcceptableOrUnknown(
          data['last_applied']!,
          _lastAppliedMeta,
        ),
      );
    }
    if (data.containsKey('pot_id')) {
      context.handle(
        _potIdMeta,
        potId.isAcceptableOrUnknown(data['pot_id']!, _potIdMeta),
      );
    }
    if (data.containsKey('merchant_id')) {
      context.handle(
        _merchantIdMeta,
        merchantId.isAcceptableOrUnknown(data['merchant_id']!, _merchantIdMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('is_bill')) {
      context.handle(
        _isBillMeta,
        isBill.isAcceptableOrUnknown(data['is_bill']!, _isBillMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: $RecurringRulesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      cadence: $RecurringRulesTable.$convertercadence.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}cadence'],
        )!,
      ),
      nextDue: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_due'],
      )!,
      lastApplied: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_applied'],
      ),
      potId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pot_id'],
      ),
      merchantId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}merchant_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      isBill: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_bill'],
      )!,
    );
  }

  @override
  $RecurringRulesTable createAlias(String alias) {
    return $RecurringRulesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TxnKind, String, String> $converterkind =
      const EnumNameConverter<TxnKind>(TxnKind.values);
  static JsonTypeConverter2<Cadence, String, String> $convertercadence =
      const EnumNameConverter<Cadence>(Cadence.values);
}

class RecurringRule extends DataClass implements Insertable<RecurringRule> {
  final int id;
  final String name;
  final TxnKind kind;
  final int amountCents;
  final Cadence cadence;
  final DateTime nextDue;
  final DateTime? lastApplied;
  final int? potId;
  final int? merchantId;
  final int? categoryId;
  final bool active;

  /// Marks this as a bill/subscription (vs. an ordinary recurring expense or
  /// income) so it can be surfaced in the "due soon" reminder list. Only
  /// meaningful for expense-kind rules.
  final bool isBill;
  const RecurringRule({
    required this.id,
    required this.name,
    required this.kind,
    required this.amountCents,
    required this.cadence,
    required this.nextDue,
    this.lastApplied,
    this.potId,
    this.merchantId,
    this.categoryId,
    required this.active,
    required this.isBill,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['kind'] = Variable<String>(
        $RecurringRulesTable.$converterkind.toSql(kind),
      );
    }
    map['amount_cents'] = Variable<int>(amountCents);
    {
      map['cadence'] = Variable<String>(
        $RecurringRulesTable.$convertercadence.toSql(cadence),
      );
    }
    map['next_due'] = Variable<DateTime>(nextDue);
    if (!nullToAbsent || lastApplied != null) {
      map['last_applied'] = Variable<DateTime>(lastApplied);
    }
    if (!nullToAbsent || potId != null) {
      map['pot_id'] = Variable<int>(potId);
    }
    if (!nullToAbsent || merchantId != null) {
      map['merchant_id'] = Variable<int>(merchantId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['active'] = Variable<bool>(active);
    map['is_bill'] = Variable<bool>(isBill);
    return map;
  }

  RecurringRulesCompanion toCompanion(bool nullToAbsent) {
    return RecurringRulesCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      amountCents: Value(amountCents),
      cadence: Value(cadence),
      nextDue: Value(nextDue),
      lastApplied: lastApplied == null && nullToAbsent
          ? const Value.absent()
          : Value(lastApplied),
      potId: potId == null && nullToAbsent
          ? const Value.absent()
          : Value(potId),
      merchantId: merchantId == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      active: Value(active),
      isBill: Value(isBill),
    );
  }

  factory RecurringRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringRule(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: $RecurringRulesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      cadence: $RecurringRulesTable.$convertercadence.fromJson(
        serializer.fromJson<String>(json['cadence']),
      ),
      nextDue: serializer.fromJson<DateTime>(json['nextDue']),
      lastApplied: serializer.fromJson<DateTime?>(json['lastApplied']),
      potId: serializer.fromJson<int?>(json['potId']),
      merchantId: serializer.fromJson<int?>(json['merchantId']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      active: serializer.fromJson<bool>(json['active']),
      isBill: serializer.fromJson<bool>(json['isBill']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(
        $RecurringRulesTable.$converterkind.toJson(kind),
      ),
      'amountCents': serializer.toJson<int>(amountCents),
      'cadence': serializer.toJson<String>(
        $RecurringRulesTable.$convertercadence.toJson(cadence),
      ),
      'nextDue': serializer.toJson<DateTime>(nextDue),
      'lastApplied': serializer.toJson<DateTime?>(lastApplied),
      'potId': serializer.toJson<int?>(potId),
      'merchantId': serializer.toJson<int?>(merchantId),
      'categoryId': serializer.toJson<int?>(categoryId),
      'active': serializer.toJson<bool>(active),
      'isBill': serializer.toJson<bool>(isBill),
    };
  }

  RecurringRule copyWith({
    int? id,
    String? name,
    TxnKind? kind,
    int? amountCents,
    Cadence? cadence,
    DateTime? nextDue,
    Value<DateTime?> lastApplied = const Value.absent(),
    Value<int?> potId = const Value.absent(),
    Value<int?> merchantId = const Value.absent(),
    Value<int?> categoryId = const Value.absent(),
    bool? active,
    bool? isBill,
  }) => RecurringRule(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    amountCents: amountCents ?? this.amountCents,
    cadence: cadence ?? this.cadence,
    nextDue: nextDue ?? this.nextDue,
    lastApplied: lastApplied.present ? lastApplied.value : this.lastApplied,
    potId: potId.present ? potId.value : this.potId,
    merchantId: merchantId.present ? merchantId.value : this.merchantId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    active: active ?? this.active,
    isBill: isBill ?? this.isBill,
  );
  RecurringRule copyWithCompanion(RecurringRulesCompanion data) {
    return RecurringRule(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      cadence: data.cadence.present ? data.cadence.value : this.cadence,
      nextDue: data.nextDue.present ? data.nextDue.value : this.nextDue,
      lastApplied: data.lastApplied.present
          ? data.lastApplied.value
          : this.lastApplied,
      potId: data.potId.present ? data.potId.value : this.potId,
      merchantId: data.merchantId.present
          ? data.merchantId.value
          : this.merchantId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      active: data.active.present ? data.active.value : this.active,
      isBill: data.isBill.present ? data.isBill.value : this.isBill,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringRule(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('amountCents: $amountCents, ')
          ..write('cadence: $cadence, ')
          ..write('nextDue: $nextDue, ')
          ..write('lastApplied: $lastApplied, ')
          ..write('potId: $potId, ')
          ..write('merchantId: $merchantId, ')
          ..write('categoryId: $categoryId, ')
          ..write('active: $active, ')
          ..write('isBill: $isBill')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    amountCents,
    cadence,
    nextDue,
    lastApplied,
    potId,
    merchantId,
    categoryId,
    active,
    isBill,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringRule &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.amountCents == this.amountCents &&
          other.cadence == this.cadence &&
          other.nextDue == this.nextDue &&
          other.lastApplied == this.lastApplied &&
          other.potId == this.potId &&
          other.merchantId == this.merchantId &&
          other.categoryId == this.categoryId &&
          other.active == this.active &&
          other.isBill == this.isBill);
}

class RecurringRulesCompanion extends UpdateCompanion<RecurringRule> {
  final Value<int> id;
  final Value<String> name;
  final Value<TxnKind> kind;
  final Value<int> amountCents;
  final Value<Cadence> cadence;
  final Value<DateTime> nextDue;
  final Value<DateTime?> lastApplied;
  final Value<int?> potId;
  final Value<int?> merchantId;
  final Value<int?> categoryId;
  final Value<bool> active;
  final Value<bool> isBill;
  const RecurringRulesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.cadence = const Value.absent(),
    this.nextDue = const Value.absent(),
    this.lastApplied = const Value.absent(),
    this.potId = const Value.absent(),
    this.merchantId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.active = const Value.absent(),
    this.isBill = const Value.absent(),
  });
  RecurringRulesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required TxnKind kind,
    required int amountCents,
    required Cadence cadence,
    required DateTime nextDue,
    this.lastApplied = const Value.absent(),
    this.potId = const Value.absent(),
    this.merchantId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.active = const Value.absent(),
    this.isBill = const Value.absent(),
  }) : name = Value(name),
       kind = Value(kind),
       amountCents = Value(amountCents),
       cadence = Value(cadence),
       nextDue = Value(nextDue);
  static Insertable<RecurringRule> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<int>? amountCents,
    Expression<String>? cadence,
    Expression<DateTime>? nextDue,
    Expression<DateTime>? lastApplied,
    Expression<int>? potId,
    Expression<int>? merchantId,
    Expression<int>? categoryId,
    Expression<bool>? active,
    Expression<bool>? isBill,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (amountCents != null) 'amount_cents': amountCents,
      if (cadence != null) 'cadence': cadence,
      if (nextDue != null) 'next_due': nextDue,
      if (lastApplied != null) 'last_applied': lastApplied,
      if (potId != null) 'pot_id': potId,
      if (merchantId != null) 'merchant_id': merchantId,
      if (categoryId != null) 'category_id': categoryId,
      if (active != null) 'active': active,
      if (isBill != null) 'is_bill': isBill,
    });
  }

  RecurringRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<TxnKind>? kind,
    Value<int>? amountCents,
    Value<Cadence>? cadence,
    Value<DateTime>? nextDue,
    Value<DateTime?>? lastApplied,
    Value<int?>? potId,
    Value<int?>? merchantId,
    Value<int?>? categoryId,
    Value<bool>? active,
    Value<bool>? isBill,
  }) {
    return RecurringRulesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      amountCents: amountCents ?? this.amountCents,
      cadence: cadence ?? this.cadence,
      nextDue: nextDue ?? this.nextDue,
      lastApplied: lastApplied ?? this.lastApplied,
      potId: potId ?? this.potId,
      merchantId: merchantId ?? this.merchantId,
      categoryId: categoryId ?? this.categoryId,
      active: active ?? this.active,
      isBill: isBill ?? this.isBill,
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
    if (kind.present) {
      map['kind'] = Variable<String>(
        $RecurringRulesTable.$converterkind.toSql(kind.value),
      );
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (cadence.present) {
      map['cadence'] = Variable<String>(
        $RecurringRulesTable.$convertercadence.toSql(cadence.value),
      );
    }
    if (nextDue.present) {
      map['next_due'] = Variable<DateTime>(nextDue.value);
    }
    if (lastApplied.present) {
      map['last_applied'] = Variable<DateTime>(lastApplied.value);
    }
    if (potId.present) {
      map['pot_id'] = Variable<int>(potId.value);
    }
    if (merchantId.present) {
      map['merchant_id'] = Variable<int>(merchantId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (isBill.present) {
      map['is_bill'] = Variable<bool>(isBill.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringRulesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('amountCents: $amountCents, ')
          ..write('cadence: $cadence, ')
          ..write('nextDue: $nextDue, ')
          ..write('lastApplied: $lastApplied, ')
          ..write('potId: $potId, ')
          ..write('merchantId: $merchantId, ')
          ..write('categoryId: $categoryId, ')
          ..write('active: $active, ')
          ..write('isBill: $isBill')
          ..write(')'))
        .toString();
  }
}

class $AllocationRulesTable extends AllocationRules
    with TableInfo<$AllocationRulesTable, AllocationRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AllocationRulesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _potIdMeta = const VerificationMeta('potId');
  @override
  late final GeneratedColumn<int> potId = GeneratedColumn<int>(
    'pot_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pots (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<AllocMode, String> mode =
      GeneratedColumn<String>(
        'mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AllocMode>($AllocationRulesTable.$convertermode);
  static const VerificationMeta _valueCentsMeta = const VerificationMeta(
    'valueCents',
  );
  @override
  late final GeneratedColumn<int> valueCents = GeneratedColumn<int>(
    'value_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _percentBpsMeta = const VerificationMeta(
    'percentBps',
  );
  @override
  late final GeneratedColumn<int> percentBps = GeneratedColumn<int>(
    'percent_bps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Cadence, String> cadence =
      GeneratedColumn<String>(
        'cadence',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Cadence>($AllocationRulesTable.$convertercadence);
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
  static const VerificationMeta _lastAppliedMeta = const VerificationMeta(
    'lastApplied',
  );
  @override
  late final GeneratedColumn<DateTime> lastApplied = GeneratedColumn<DateTime>(
    'last_applied',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    potId,
    mode,
    valueCents,
    percentBps,
    cadence,
    nextDue,
    lastApplied,
    active,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'allocation_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<AllocationRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('pot_id')) {
      context.handle(
        _potIdMeta,
        potId.isAcceptableOrUnknown(data['pot_id']!, _potIdMeta),
      );
    } else if (isInserting) {
      context.missing(_potIdMeta);
    }
    if (data.containsKey('value_cents')) {
      context.handle(
        _valueCentsMeta,
        valueCents.isAcceptableOrUnknown(data['value_cents']!, _valueCentsMeta),
      );
    }
    if (data.containsKey('percent_bps')) {
      context.handle(
        _percentBpsMeta,
        percentBps.isAcceptableOrUnknown(data['percent_bps']!, _percentBpsMeta),
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
    if (data.containsKey('last_applied')) {
      context.handle(
        _lastAppliedMeta,
        lastApplied.isAcceptableOrUnknown(
          data['last_applied']!,
          _lastAppliedMeta,
        ),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AllocationRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AllocationRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      potId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pot_id'],
      )!,
      mode: $AllocationRulesTable.$convertermode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}mode'],
        )!,
      ),
      valueCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value_cents'],
      )!,
      percentBps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}percent_bps'],
      )!,
      cadence: $AllocationRulesTable.$convertercadence.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}cadence'],
        )!,
      ),
      nextDue: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_due'],
      )!,
      lastApplied: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_applied'],
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
    );
  }

  @override
  $AllocationRulesTable createAlias(String alias) {
    return $AllocationRulesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AllocMode, String, String> $convertermode =
      const EnumNameConverter<AllocMode>(AllocMode.values);
  static JsonTypeConverter2<Cadence, String, String> $convertercadence =
      const EnumNameConverter<Cadence>(Cadence.values);
}

class AllocationRule extends DataClass implements Insertable<AllocationRule> {
  final int id;
  final int potId;
  final AllocMode mode;
  final int valueCents;
  final int percentBps;
  final Cadence cadence;
  final DateTime nextDue;
  final DateTime? lastApplied;
  final bool active;
  const AllocationRule({
    required this.id,
    required this.potId,
    required this.mode,
    required this.valueCents,
    required this.percentBps,
    required this.cadence,
    required this.nextDue,
    this.lastApplied,
    required this.active,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['pot_id'] = Variable<int>(potId);
    {
      map['mode'] = Variable<String>(
        $AllocationRulesTable.$convertermode.toSql(mode),
      );
    }
    map['value_cents'] = Variable<int>(valueCents);
    map['percent_bps'] = Variable<int>(percentBps);
    {
      map['cadence'] = Variable<String>(
        $AllocationRulesTable.$convertercadence.toSql(cadence),
      );
    }
    map['next_due'] = Variable<DateTime>(nextDue);
    if (!nullToAbsent || lastApplied != null) {
      map['last_applied'] = Variable<DateTime>(lastApplied);
    }
    map['active'] = Variable<bool>(active);
    return map;
  }

  AllocationRulesCompanion toCompanion(bool nullToAbsent) {
    return AllocationRulesCompanion(
      id: Value(id),
      potId: Value(potId),
      mode: Value(mode),
      valueCents: Value(valueCents),
      percentBps: Value(percentBps),
      cadence: Value(cadence),
      nextDue: Value(nextDue),
      lastApplied: lastApplied == null && nullToAbsent
          ? const Value.absent()
          : Value(lastApplied),
      active: Value(active),
    );
  }

  factory AllocationRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AllocationRule(
      id: serializer.fromJson<int>(json['id']),
      potId: serializer.fromJson<int>(json['potId']),
      mode: $AllocationRulesTable.$convertermode.fromJson(
        serializer.fromJson<String>(json['mode']),
      ),
      valueCents: serializer.fromJson<int>(json['valueCents']),
      percentBps: serializer.fromJson<int>(json['percentBps']),
      cadence: $AllocationRulesTable.$convertercadence.fromJson(
        serializer.fromJson<String>(json['cadence']),
      ),
      nextDue: serializer.fromJson<DateTime>(json['nextDue']),
      lastApplied: serializer.fromJson<DateTime?>(json['lastApplied']),
      active: serializer.fromJson<bool>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'potId': serializer.toJson<int>(potId),
      'mode': serializer.toJson<String>(
        $AllocationRulesTable.$convertermode.toJson(mode),
      ),
      'valueCents': serializer.toJson<int>(valueCents),
      'percentBps': serializer.toJson<int>(percentBps),
      'cadence': serializer.toJson<String>(
        $AllocationRulesTable.$convertercadence.toJson(cadence),
      ),
      'nextDue': serializer.toJson<DateTime>(nextDue),
      'lastApplied': serializer.toJson<DateTime?>(lastApplied),
      'active': serializer.toJson<bool>(active),
    };
  }

  AllocationRule copyWith({
    int? id,
    int? potId,
    AllocMode? mode,
    int? valueCents,
    int? percentBps,
    Cadence? cadence,
    DateTime? nextDue,
    Value<DateTime?> lastApplied = const Value.absent(),
    bool? active,
  }) => AllocationRule(
    id: id ?? this.id,
    potId: potId ?? this.potId,
    mode: mode ?? this.mode,
    valueCents: valueCents ?? this.valueCents,
    percentBps: percentBps ?? this.percentBps,
    cadence: cadence ?? this.cadence,
    nextDue: nextDue ?? this.nextDue,
    lastApplied: lastApplied.present ? lastApplied.value : this.lastApplied,
    active: active ?? this.active,
  );
  AllocationRule copyWithCompanion(AllocationRulesCompanion data) {
    return AllocationRule(
      id: data.id.present ? data.id.value : this.id,
      potId: data.potId.present ? data.potId.value : this.potId,
      mode: data.mode.present ? data.mode.value : this.mode,
      valueCents: data.valueCents.present
          ? data.valueCents.value
          : this.valueCents,
      percentBps: data.percentBps.present
          ? data.percentBps.value
          : this.percentBps,
      cadence: data.cadence.present ? data.cadence.value : this.cadence,
      nextDue: data.nextDue.present ? data.nextDue.value : this.nextDue,
      lastApplied: data.lastApplied.present
          ? data.lastApplied.value
          : this.lastApplied,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AllocationRule(')
          ..write('id: $id, ')
          ..write('potId: $potId, ')
          ..write('mode: $mode, ')
          ..write('valueCents: $valueCents, ')
          ..write('percentBps: $percentBps, ')
          ..write('cadence: $cadence, ')
          ..write('nextDue: $nextDue, ')
          ..write('lastApplied: $lastApplied, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    potId,
    mode,
    valueCents,
    percentBps,
    cadence,
    nextDue,
    lastApplied,
    active,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AllocationRule &&
          other.id == this.id &&
          other.potId == this.potId &&
          other.mode == this.mode &&
          other.valueCents == this.valueCents &&
          other.percentBps == this.percentBps &&
          other.cadence == this.cadence &&
          other.nextDue == this.nextDue &&
          other.lastApplied == this.lastApplied &&
          other.active == this.active);
}

class AllocationRulesCompanion extends UpdateCompanion<AllocationRule> {
  final Value<int> id;
  final Value<int> potId;
  final Value<AllocMode> mode;
  final Value<int> valueCents;
  final Value<int> percentBps;
  final Value<Cadence> cadence;
  final Value<DateTime> nextDue;
  final Value<DateTime?> lastApplied;
  final Value<bool> active;
  const AllocationRulesCompanion({
    this.id = const Value.absent(),
    this.potId = const Value.absent(),
    this.mode = const Value.absent(),
    this.valueCents = const Value.absent(),
    this.percentBps = const Value.absent(),
    this.cadence = const Value.absent(),
    this.nextDue = const Value.absent(),
    this.lastApplied = const Value.absent(),
    this.active = const Value.absent(),
  });
  AllocationRulesCompanion.insert({
    this.id = const Value.absent(),
    required int potId,
    required AllocMode mode,
    this.valueCents = const Value.absent(),
    this.percentBps = const Value.absent(),
    required Cadence cadence,
    required DateTime nextDue,
    this.lastApplied = const Value.absent(),
    this.active = const Value.absent(),
  }) : potId = Value(potId),
       mode = Value(mode),
       cadence = Value(cadence),
       nextDue = Value(nextDue);
  static Insertable<AllocationRule> custom({
    Expression<int>? id,
    Expression<int>? potId,
    Expression<String>? mode,
    Expression<int>? valueCents,
    Expression<int>? percentBps,
    Expression<String>? cadence,
    Expression<DateTime>? nextDue,
    Expression<DateTime>? lastApplied,
    Expression<bool>? active,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (potId != null) 'pot_id': potId,
      if (mode != null) 'mode': mode,
      if (valueCents != null) 'value_cents': valueCents,
      if (percentBps != null) 'percent_bps': percentBps,
      if (cadence != null) 'cadence': cadence,
      if (nextDue != null) 'next_due': nextDue,
      if (lastApplied != null) 'last_applied': lastApplied,
      if (active != null) 'active': active,
    });
  }

  AllocationRulesCompanion copyWith({
    Value<int>? id,
    Value<int>? potId,
    Value<AllocMode>? mode,
    Value<int>? valueCents,
    Value<int>? percentBps,
    Value<Cadence>? cadence,
    Value<DateTime>? nextDue,
    Value<DateTime?>? lastApplied,
    Value<bool>? active,
  }) {
    return AllocationRulesCompanion(
      id: id ?? this.id,
      potId: potId ?? this.potId,
      mode: mode ?? this.mode,
      valueCents: valueCents ?? this.valueCents,
      percentBps: percentBps ?? this.percentBps,
      cadence: cadence ?? this.cadence,
      nextDue: nextDue ?? this.nextDue,
      lastApplied: lastApplied ?? this.lastApplied,
      active: active ?? this.active,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (potId.present) {
      map['pot_id'] = Variable<int>(potId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(
        $AllocationRulesTable.$convertermode.toSql(mode.value),
      );
    }
    if (valueCents.present) {
      map['value_cents'] = Variable<int>(valueCents.value);
    }
    if (percentBps.present) {
      map['percent_bps'] = Variable<int>(percentBps.value);
    }
    if (cadence.present) {
      map['cadence'] = Variable<String>(
        $AllocationRulesTable.$convertercadence.toSql(cadence.value),
      );
    }
    if (nextDue.present) {
      map['next_due'] = Variable<DateTime>(nextDue.value);
    }
    if (lastApplied.present) {
      map['last_applied'] = Variable<DateTime>(lastApplied.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AllocationRulesCompanion(')
          ..write('id: $id, ')
          ..write('potId: $potId, ')
          ..write('mode: $mode, ')
          ..write('valueCents: $valueCents, ')
          ..write('percentBps: $percentBps, ')
          ..write('cadence: $cadence, ')
          ..write('nextDue: $nextDue, ')
          ..write('lastApplied: $lastApplied, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }
}

class $HoldingsTable extends Holdings with TableInfo<$HoldingsTable, Holding> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HoldingsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _tickerMeta = const VerificationMeta('ticker');
  @override
  late final GeneratedColumn<String> ticker = GeneratedColumn<String>(
    'ticker',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
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
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sharesMeta = const VerificationMeta('shares');
  @override
  late final GeneratedColumn<double> shares = GeneratedColumn<double>(
    'shares',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avgCostCentsMeta = const VerificationMeta(
    'avgCostCents',
  );
  @override
  late final GeneratedColumn<int> avgCostCents = GeneratedColumn<int>(
    'avg_cost_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPriceCentsMeta = const VerificationMeta(
    'lastPriceCents',
  );
  @override
  late final GeneratedColumn<int> lastPriceCents = GeneratedColumn<int>(
    'last_price_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPriceAtMeta = const VerificationMeta(
    'lastPriceAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPriceAt = GeneratedColumn<DateTime>(
    'last_price_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ticker,
    name,
    shares,
    avgCostCents,
    lastPriceCents,
    lastPriceAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'holdings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Holding> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ticker')) {
      context.handle(
        _tickerMeta,
        ticker.isAcceptableOrUnknown(data['ticker']!, _tickerMeta),
      );
    } else if (isInserting) {
      context.missing(_tickerMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('shares')) {
      context.handle(
        _sharesMeta,
        shares.isAcceptableOrUnknown(data['shares']!, _sharesMeta),
      );
    } else if (isInserting) {
      context.missing(_sharesMeta);
    }
    if (data.containsKey('avg_cost_cents')) {
      context.handle(
        _avgCostCentsMeta,
        avgCostCents.isAcceptableOrUnknown(
          data['avg_cost_cents']!,
          _avgCostCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_avgCostCentsMeta);
    }
    if (data.containsKey('last_price_cents')) {
      context.handle(
        _lastPriceCentsMeta,
        lastPriceCents.isAcceptableOrUnknown(
          data['last_price_cents']!,
          _lastPriceCentsMeta,
        ),
      );
    }
    if (data.containsKey('last_price_at')) {
      context.handle(
        _lastPriceAtMeta,
        lastPriceAt.isAcceptableOrUnknown(
          data['last_price_at']!,
          _lastPriceAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Holding map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Holding(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ticker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ticker'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      shares: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}shares'],
      )!,
      avgCostCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avg_cost_cents'],
      )!,
      lastPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_price_cents'],
      ),
      lastPriceAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_price_at'],
      ),
    );
  }

  @override
  $HoldingsTable createAlias(String alias) {
    return $HoldingsTable(attachedDatabase, alias);
  }
}

class Holding extends DataClass implements Insertable<Holding> {
  final int id;
  final String ticker;
  final String name;
  final double shares;
  final int avgCostCents;
  final int? lastPriceCents;
  final DateTime? lastPriceAt;
  const Holding({
    required this.id,
    required this.ticker,
    required this.name,
    required this.shares,
    required this.avgCostCents,
    this.lastPriceCents,
    this.lastPriceAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ticker'] = Variable<String>(ticker);
    map['name'] = Variable<String>(name);
    map['shares'] = Variable<double>(shares);
    map['avg_cost_cents'] = Variable<int>(avgCostCents);
    if (!nullToAbsent || lastPriceCents != null) {
      map['last_price_cents'] = Variable<int>(lastPriceCents);
    }
    if (!nullToAbsent || lastPriceAt != null) {
      map['last_price_at'] = Variable<DateTime>(lastPriceAt);
    }
    return map;
  }

  HoldingsCompanion toCompanion(bool nullToAbsent) {
    return HoldingsCompanion(
      id: Value(id),
      ticker: Value(ticker),
      name: Value(name),
      shares: Value(shares),
      avgCostCents: Value(avgCostCents),
      lastPriceCents: lastPriceCents == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPriceCents),
      lastPriceAt: lastPriceAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPriceAt),
    );
  }

  factory Holding.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Holding(
      id: serializer.fromJson<int>(json['id']),
      ticker: serializer.fromJson<String>(json['ticker']),
      name: serializer.fromJson<String>(json['name']),
      shares: serializer.fromJson<double>(json['shares']),
      avgCostCents: serializer.fromJson<int>(json['avgCostCents']),
      lastPriceCents: serializer.fromJson<int?>(json['lastPriceCents']),
      lastPriceAt: serializer.fromJson<DateTime?>(json['lastPriceAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ticker': serializer.toJson<String>(ticker),
      'name': serializer.toJson<String>(name),
      'shares': serializer.toJson<double>(shares),
      'avgCostCents': serializer.toJson<int>(avgCostCents),
      'lastPriceCents': serializer.toJson<int?>(lastPriceCents),
      'lastPriceAt': serializer.toJson<DateTime?>(lastPriceAt),
    };
  }

  Holding copyWith({
    int? id,
    String? ticker,
    String? name,
    double? shares,
    int? avgCostCents,
    Value<int?> lastPriceCents = const Value.absent(),
    Value<DateTime?> lastPriceAt = const Value.absent(),
  }) => Holding(
    id: id ?? this.id,
    ticker: ticker ?? this.ticker,
    name: name ?? this.name,
    shares: shares ?? this.shares,
    avgCostCents: avgCostCents ?? this.avgCostCents,
    lastPriceCents: lastPriceCents.present
        ? lastPriceCents.value
        : this.lastPriceCents,
    lastPriceAt: lastPriceAt.present ? lastPriceAt.value : this.lastPriceAt,
  );
  Holding copyWithCompanion(HoldingsCompanion data) {
    return Holding(
      id: data.id.present ? data.id.value : this.id,
      ticker: data.ticker.present ? data.ticker.value : this.ticker,
      name: data.name.present ? data.name.value : this.name,
      shares: data.shares.present ? data.shares.value : this.shares,
      avgCostCents: data.avgCostCents.present
          ? data.avgCostCents.value
          : this.avgCostCents,
      lastPriceCents: data.lastPriceCents.present
          ? data.lastPriceCents.value
          : this.lastPriceCents,
      lastPriceAt: data.lastPriceAt.present
          ? data.lastPriceAt.value
          : this.lastPriceAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Holding(')
          ..write('id: $id, ')
          ..write('ticker: $ticker, ')
          ..write('name: $name, ')
          ..write('shares: $shares, ')
          ..write('avgCostCents: $avgCostCents, ')
          ..write('lastPriceCents: $lastPriceCents, ')
          ..write('lastPriceAt: $lastPriceAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ticker,
    name,
    shares,
    avgCostCents,
    lastPriceCents,
    lastPriceAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Holding &&
          other.id == this.id &&
          other.ticker == this.ticker &&
          other.name == this.name &&
          other.shares == this.shares &&
          other.avgCostCents == this.avgCostCents &&
          other.lastPriceCents == this.lastPriceCents &&
          other.lastPriceAt == this.lastPriceAt);
}

class HoldingsCompanion extends UpdateCompanion<Holding> {
  final Value<int> id;
  final Value<String> ticker;
  final Value<String> name;
  final Value<double> shares;
  final Value<int> avgCostCents;
  final Value<int?> lastPriceCents;
  final Value<DateTime?> lastPriceAt;
  const HoldingsCompanion({
    this.id = const Value.absent(),
    this.ticker = const Value.absent(),
    this.name = const Value.absent(),
    this.shares = const Value.absent(),
    this.avgCostCents = const Value.absent(),
    this.lastPriceCents = const Value.absent(),
    this.lastPriceAt = const Value.absent(),
  });
  HoldingsCompanion.insert({
    this.id = const Value.absent(),
    required String ticker,
    required String name,
    required double shares,
    required int avgCostCents,
    this.lastPriceCents = const Value.absent(),
    this.lastPriceAt = const Value.absent(),
  }) : ticker = Value(ticker),
       name = Value(name),
       shares = Value(shares),
       avgCostCents = Value(avgCostCents);
  static Insertable<Holding> custom({
    Expression<int>? id,
    Expression<String>? ticker,
    Expression<String>? name,
    Expression<double>? shares,
    Expression<int>? avgCostCents,
    Expression<int>? lastPriceCents,
    Expression<DateTime>? lastPriceAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ticker != null) 'ticker': ticker,
      if (name != null) 'name': name,
      if (shares != null) 'shares': shares,
      if (avgCostCents != null) 'avg_cost_cents': avgCostCents,
      if (lastPriceCents != null) 'last_price_cents': lastPriceCents,
      if (lastPriceAt != null) 'last_price_at': lastPriceAt,
    });
  }

  HoldingsCompanion copyWith({
    Value<int>? id,
    Value<String>? ticker,
    Value<String>? name,
    Value<double>? shares,
    Value<int>? avgCostCents,
    Value<int?>? lastPriceCents,
    Value<DateTime?>? lastPriceAt,
  }) {
    return HoldingsCompanion(
      id: id ?? this.id,
      ticker: ticker ?? this.ticker,
      name: name ?? this.name,
      shares: shares ?? this.shares,
      avgCostCents: avgCostCents ?? this.avgCostCents,
      lastPriceCents: lastPriceCents ?? this.lastPriceCents,
      lastPriceAt: lastPriceAt ?? this.lastPriceAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ticker.present) {
      map['ticker'] = Variable<String>(ticker.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (shares.present) {
      map['shares'] = Variable<double>(shares.value);
    }
    if (avgCostCents.present) {
      map['avg_cost_cents'] = Variable<int>(avgCostCents.value);
    }
    if (lastPriceCents.present) {
      map['last_price_cents'] = Variable<int>(lastPriceCents.value);
    }
    if (lastPriceAt.present) {
      map['last_price_at'] = Variable<DateTime>(lastPriceAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HoldingsCompanion(')
          ..write('id: $id, ')
          ..write('ticker: $ticker, ')
          ..write('name: $name, ')
          ..write('shares: $shares, ')
          ..write('avgCostCents: $avgCostCents, ')
          ..write('lastPriceCents: $lastPriceCents, ')
          ..write('lastPriceAt: $lastPriceAt')
          ..write(')'))
        .toString();
  }
}

class $MetaItemsTable extends MetaItems
    with TableInfo<$MetaItemsTable, MetaItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaItemsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'meta_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaItem> instance, {
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
  MetaItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaItem(
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
  $MetaItemsTable createAlias(String alias) {
    return $MetaItemsTable(attachedDatabase, alias);
  }
}

class MetaItem extends DataClass implements Insertable<MetaItem> {
  final String key;
  final String value;
  const MetaItem({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaItemsCompanion toCompanion(bool nullToAbsent) {
    return MetaItemsCompanion(key: Value(key), value: Value(value));
  }

  factory MetaItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaItem(
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

  MetaItem copyWith({String? key, String? value}) =>
      MetaItem(key: key ?? this.key, value: value ?? this.value);
  MetaItem copyWithCompanion(MetaItemsCompanion data) {
    return MetaItem(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaItem(')
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
      (other is MetaItem && other.key == this.key && other.value == this.value);
}

class MetaItemsCompanion extends UpdateCompanion<MetaItem> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaItemsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaItemsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaItem> custom({
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

  MetaItemsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaItemsCompanion(
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
    return (StringBuffer('MetaItemsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OverviewGraphsTable extends OverviewGraphs
    with TableInfo<$OverviewGraphsTable, OverviewGraph> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OverviewGraphsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _graphTypeMeta = const VerificationMeta(
    'graphType',
  );
  @override
  late final GeneratedColumn<String> graphType = GeneratedColumn<String>(
    'graph_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataSourceMeta = const VerificationMeta(
    'dataSource',
  );
  @override
  late final GeneratedColumn<String> dataSource = GeneratedColumn<String>(
    'data_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [id, graphType, dataSource, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'overview_graphs';
  @override
  VerificationContext validateIntegrity(
    Insertable<OverviewGraph> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('graph_type')) {
      context.handle(
        _graphTypeMeta,
        graphType.isAcceptableOrUnknown(data['graph_type']!, _graphTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_graphTypeMeta);
    }
    if (data.containsKey('data_source')) {
      context.handle(
        _dataSourceMeta,
        dataSource.isAcceptableOrUnknown(data['data_source']!, _dataSourceMeta),
      );
    } else if (isInserting) {
      context.missing(_dataSourceMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OverviewGraph map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OverviewGraph(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      graphType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}graph_type'],
      )!,
      dataSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_source'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $OverviewGraphsTable createAlias(String alias) {
    return $OverviewGraphsTable(attachedDatabase, alias);
  }
}

class OverviewGraph extends DataClass implements Insertable<OverviewGraph> {
  final int id;
  final String graphType;
  final String dataSource;
  final int sortOrder;
  const OverviewGraph({
    required this.id,
    required this.graphType,
    required this.dataSource,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['graph_type'] = Variable<String>(graphType);
    map['data_source'] = Variable<String>(dataSource);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  OverviewGraphsCompanion toCompanion(bool nullToAbsent) {
    return OverviewGraphsCompanion(
      id: Value(id),
      graphType: Value(graphType),
      dataSource: Value(dataSource),
      sortOrder: Value(sortOrder),
    );
  }

  factory OverviewGraph.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OverviewGraph(
      id: serializer.fromJson<int>(json['id']),
      graphType: serializer.fromJson<String>(json['graphType']),
      dataSource: serializer.fromJson<String>(json['dataSource']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'graphType': serializer.toJson<String>(graphType),
      'dataSource': serializer.toJson<String>(dataSource),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  OverviewGraph copyWith({
    int? id,
    String? graphType,
    String? dataSource,
    int? sortOrder,
  }) => OverviewGraph(
    id: id ?? this.id,
    graphType: graphType ?? this.graphType,
    dataSource: dataSource ?? this.dataSource,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  OverviewGraph copyWithCompanion(OverviewGraphsCompanion data) {
    return OverviewGraph(
      id: data.id.present ? data.id.value : this.id,
      graphType: data.graphType.present ? data.graphType.value : this.graphType,
      dataSource: data.dataSource.present
          ? data.dataSource.value
          : this.dataSource,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OverviewGraph(')
          ..write('id: $id, ')
          ..write('graphType: $graphType, ')
          ..write('dataSource: $dataSource, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, graphType, dataSource, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OverviewGraph &&
          other.id == this.id &&
          other.graphType == this.graphType &&
          other.dataSource == this.dataSource &&
          other.sortOrder == this.sortOrder);
}

class OverviewGraphsCompanion extends UpdateCompanion<OverviewGraph> {
  final Value<int> id;
  final Value<String> graphType;
  final Value<String> dataSource;
  final Value<int> sortOrder;
  const OverviewGraphsCompanion({
    this.id = const Value.absent(),
    this.graphType = const Value.absent(),
    this.dataSource = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  OverviewGraphsCompanion.insert({
    this.id = const Value.absent(),
    required String graphType,
    required String dataSource,
    this.sortOrder = const Value.absent(),
  }) : graphType = Value(graphType),
       dataSource = Value(dataSource);
  static Insertable<OverviewGraph> custom({
    Expression<int>? id,
    Expression<String>? graphType,
    Expression<String>? dataSource,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (graphType != null) 'graph_type': graphType,
      if (dataSource != null) 'data_source': dataSource,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  OverviewGraphsCompanion copyWith({
    Value<int>? id,
    Value<String>? graphType,
    Value<String>? dataSource,
    Value<int>? sortOrder,
  }) {
    return OverviewGraphsCompanion(
      id: id ?? this.id,
      graphType: graphType ?? this.graphType,
      dataSource: dataSource ?? this.dataSource,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (graphType.present) {
      map['graph_type'] = Variable<String>(graphType.value);
    }
    if (dataSource.present) {
      map['data_source'] = Variable<String>(dataSource.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OverviewGraphsCompanion(')
          ..write('id: $id, ')
          ..write('graphType: $graphType, ')
          ..write('dataSource: $dataSource, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $BalanceSnapshotsTable extends BalanceSnapshots
    with TableInfo<$BalanceSnapshotsTable, BalanceSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BalanceSnapshotsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalCentsMeta = const VerificationMeta(
    'totalCents',
  );
  @override
  late final GeneratedColumn<int> totalCents = GeneratedColumn<int>(
    'total_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, date, totalCents];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'balance_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<BalanceSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('total_cents')) {
      context.handle(
        _totalCentsMeta,
        totalCents.isAcceptableOrUnknown(data['total_cents']!, _totalCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_totalCentsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {date},
  ];
  @override
  BalanceSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BalanceSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      totalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_cents'],
      )!,
    );
  }

  @override
  $BalanceSnapshotsTable createAlias(String alias) {
    return $BalanceSnapshotsTable(attachedDatabase, alias);
  }
}

class BalanceSnapshot extends DataClass implements Insertable<BalanceSnapshot> {
  final int id;
  final DateTime date;
  final int totalCents;
  const BalanceSnapshot({
    required this.id,
    required this.date,
    required this.totalCents,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['total_cents'] = Variable<int>(totalCents);
    return map;
  }

  BalanceSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return BalanceSnapshotsCompanion(
      id: Value(id),
      date: Value(date),
      totalCents: Value(totalCents),
    );
  }

  factory BalanceSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BalanceSnapshot(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      totalCents: serializer.fromJson<int>(json['totalCents']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'totalCents': serializer.toJson<int>(totalCents),
    };
  }

  BalanceSnapshot copyWith({int? id, DateTime? date, int? totalCents}) =>
      BalanceSnapshot(
        id: id ?? this.id,
        date: date ?? this.date,
        totalCents: totalCents ?? this.totalCents,
      );
  BalanceSnapshot copyWithCompanion(BalanceSnapshotsCompanion data) {
    return BalanceSnapshot(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      totalCents: data.totalCents.present
          ? data.totalCents.value
          : this.totalCents,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BalanceSnapshot(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('totalCents: $totalCents')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, totalCents);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BalanceSnapshot &&
          other.id == this.id &&
          other.date == this.date &&
          other.totalCents == this.totalCents);
}

class BalanceSnapshotsCompanion extends UpdateCompanion<BalanceSnapshot> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<int> totalCents;
  const BalanceSnapshotsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.totalCents = const Value.absent(),
  });
  BalanceSnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required int totalCents,
  }) : date = Value(date),
       totalCents = Value(totalCents);
  static Insertable<BalanceSnapshot> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<int>? totalCents,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (totalCents != null) 'total_cents': totalCents,
    });
  }

  BalanceSnapshotsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<int>? totalCents,
  }) {
    return BalanceSnapshotsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      totalCents: totalCents ?? this.totalCents,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (totalCents.present) {
      map['total_cents'] = Variable<int>(totalCents.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BalanceSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('totalCents: $totalCents')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $MerchantsTable merchants = $MerchantsTable(this);
  late final $PotsTable pots = $PotsTable(this);
  late final $FinanceTransactionsTable financeTransactions =
      $FinanceTransactionsTable(this);
  late final $RecurringRulesTable recurringRules = $RecurringRulesTable(this);
  late final $AllocationRulesTable allocationRules = $AllocationRulesTable(
    this,
  );
  late final $HoldingsTable holdings = $HoldingsTable(this);
  late final $MetaItemsTable metaItems = $MetaItemsTable(this);
  late final $OverviewGraphsTable overviewGraphs = $OverviewGraphsTable(this);
  late final $BalanceSnapshotsTable balanceSnapshots = $BalanceSnapshotsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    merchants,
    pots,
    financeTransactions,
    recurringRules,
    allocationRules,
    holdings,
    metaItems,
    overviewGraphs,
    balanceSnapshots,
  ];
}

typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      required String name,
      required int colorValue,
      required int iconCodepoint,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> colorValue,
      Value<int> iconCodepoint,
    });

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MerchantsTable, List<Merchant>>
  _merchantsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.merchants,
    aliasName: 'categories__id__merchants__default_category_id',
  );

  $$MerchantsTableProcessedTableManager get merchantsRefs {
    final manager = $$MerchantsTableTableManager(
      $_db,
      $_db.merchants,
    ).filter((f) => f.defaultCategoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_merchantsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $FinanceTransactionsTable,
    List<FinanceTransaction>
  >
  _financeTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.financeTransactions,
        aliasName: 'categories__id__finance_transactions__category_id',
      );

  $$FinanceTransactionsTableProcessedTableManager get financeTransactionsRefs {
    final manager = $$FinanceTransactionsTableTableManager(
      $_db,
      $_db.financeTransactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _financeTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecurringRulesTable, List<RecurringRule>>
  _recurringRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recurringRules,
    aliasName: 'categories__id__recurring_rules__category_id',
  );

  $$RecurringRulesTableProcessedTableManager get recurringRulesRefs {
    final manager = $$RecurringRulesTableTableManager(
      $_db,
      $_db.recurringRules,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_recurringRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get iconCodepoint => $composableBuilder(
    column: $table.iconCodepoint,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> merchantsRefs(
    Expression<bool> Function($$MerchantsTableFilterComposer f) f,
  ) {
    final $$MerchantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.merchants,
      getReferencedColumn: (t) => t.defaultCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantsTableFilterComposer(
            $db: $db,
            $table: $db.merchants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> financeTransactionsRefs(
    Expression<bool> Function($$FinanceTransactionsTableFilterComposer f) f,
  ) {
    final $$FinanceTransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.financeTransactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FinanceTransactionsTableFilterComposer(
            $db: $db,
            $table: $db.financeTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recurringRulesRefs(
    Expression<bool> Function($$RecurringRulesTableFilterComposer f) f,
  ) {
    final $$RecurringRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableFilterComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get iconCodepoint => $composableBuilder(
    column: $table.iconCodepoint,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
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

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get iconCodepoint => $composableBuilder(
    column: $table.iconCodepoint,
    builder: (column) => column,
  );

  Expression<T> merchantsRefs<T extends Object>(
    Expression<T> Function($$MerchantsTableAnnotationComposer a) f,
  ) {
    final $$MerchantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.merchants,
      getReferencedColumn: (t) => t.defaultCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantsTableAnnotationComposer(
            $db: $db,
            $table: $db.merchants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> financeTransactionsRefs<T extends Object>(
    Expression<T> Function($$FinanceTransactionsTableAnnotationComposer a) f,
  ) {
    final $$FinanceTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.financeTransactions,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinanceTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.financeTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> recurringRulesRefs<T extends Object>(
    Expression<T> Function($$RecurringRulesTableAnnotationComposer a) f,
  ) {
    final $$RecurringRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({
            bool merchantsRefs,
            bool financeTransactionsRefs,
            bool recurringRulesRefs,
          })
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<int> iconCodepoint = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                colorValue: colorValue,
                iconCodepoint: iconCodepoint,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int colorValue,
                required int iconCodepoint,
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                colorValue: colorValue,
                iconCodepoint: iconCodepoint,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                merchantsRefs = false,
                financeTransactionsRefs = false,
                recurringRulesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (merchantsRefs) db.merchants,
                    if (financeTransactionsRefs) db.financeTransactions,
                    if (recurringRulesRefs) db.recurringRules,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (merchantsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          Merchant
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._merchantsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).merchantsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.defaultCategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (financeTransactionsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          FinanceTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._financeTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).financeTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recurringRulesRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          RecurringRule
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._recurringRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
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

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({
        bool merchantsRefs,
        bool financeTransactionsRefs,
        bool recurringRulesRefs,
      })
    >;
typedef $$MerchantsTableCreateCompanionBuilder =
    MerchantsCompanion Function({
      Value<int> id,
      required String name,
      Value<int?> defaultCategoryId,
    });
typedef $$MerchantsTableUpdateCompanionBuilder =
    MerchantsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int?> defaultCategoryId,
    });

final class $$MerchantsTableReferences
    extends BaseReferences<_$AppDatabase, $MerchantsTable, Merchant> {
  $$MerchantsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _defaultCategoryIdTable(_$AppDatabase db) => db
      .categories
      .createAlias('merchants__default_category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get defaultCategoryId {
    final $_column = $_itemColumn<int>('default_category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_defaultCategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $FinanceTransactionsTable,
    List<FinanceTransaction>
  >
  _financeTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.financeTransactions,
        aliasName: 'merchants__id__finance_transactions__merchant_id',
      );

  $$FinanceTransactionsTableProcessedTableManager get financeTransactionsRefs {
    final manager = $$FinanceTransactionsTableTableManager(
      $_db,
      $_db.financeTransactions,
    ).filter((f) => f.merchantId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _financeTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecurringRulesTable, List<RecurringRule>>
  _recurringRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recurringRules,
    aliasName: 'merchants__id__recurring_rules__merchant_id',
  );

  $$RecurringRulesTableProcessedTableManager get recurringRulesRefs {
    final manager = $$RecurringRulesTableTableManager(
      $_db,
      $_db.recurringRules,
    ).filter((f) => f.merchantId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_recurringRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MerchantsTableFilterComposer
    extends Composer<_$AppDatabase, $MerchantsTable> {
  $$MerchantsTableFilterComposer({
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

  $$CategoriesTableFilterComposer get defaultCategoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultCategoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> financeTransactionsRefs(
    Expression<bool> Function($$FinanceTransactionsTableFilterComposer f) f,
  ) {
    final $$FinanceTransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.financeTransactions,
      getReferencedColumn: (t) => t.merchantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FinanceTransactionsTableFilterComposer(
            $db: $db,
            $table: $db.financeTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recurringRulesRefs(
    Expression<bool> Function($$RecurringRulesTableFilterComposer f) f,
  ) {
    final $$RecurringRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.merchantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableFilterComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MerchantsTableOrderingComposer
    extends Composer<_$AppDatabase, $MerchantsTable> {
  $$MerchantsTableOrderingComposer({
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

  $$CategoriesTableOrderingComposer get defaultCategoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultCategoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MerchantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MerchantsTable> {
  $$MerchantsTableAnnotationComposer({
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

  $$CategoriesTableAnnotationComposer get defaultCategoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultCategoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> financeTransactionsRefs<T extends Object>(
    Expression<T> Function($$FinanceTransactionsTableAnnotationComposer a) f,
  ) {
    final $$FinanceTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.financeTransactions,
          getReferencedColumn: (t) => t.merchantId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinanceTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.financeTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> recurringRulesRefs<T extends Object>(
    Expression<T> Function($$RecurringRulesTableAnnotationComposer a) f,
  ) {
    final $$RecurringRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.merchantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MerchantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MerchantsTable,
          Merchant,
          $$MerchantsTableFilterComposer,
          $$MerchantsTableOrderingComposer,
          $$MerchantsTableAnnotationComposer,
          $$MerchantsTableCreateCompanionBuilder,
          $$MerchantsTableUpdateCompanionBuilder,
          (Merchant, $$MerchantsTableReferences),
          Merchant,
          PrefetchHooks Function({
            bool defaultCategoryId,
            bool financeTransactionsRefs,
            bool recurringRulesRefs,
          })
        > {
  $$MerchantsTableTableManager(_$AppDatabase db, $MerchantsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MerchantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MerchantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MerchantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> defaultCategoryId = const Value.absent(),
              }) => MerchantsCompanion(
                id: id,
                name: name,
                defaultCategoryId: defaultCategoryId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> defaultCategoryId = const Value.absent(),
              }) => MerchantsCompanion.insert(
                id: id,
                name: name,
                defaultCategoryId: defaultCategoryId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MerchantsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                defaultCategoryId = false,
                financeTransactionsRefs = false,
                recurringRulesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (financeTransactionsRefs) db.financeTransactions,
                    if (recurringRulesRefs) db.recurringRules,
                  ],
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
                        if (defaultCategoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.defaultCategoryId,
                                    referencedTable: $$MerchantsTableReferences
                                        ._defaultCategoryIdTable(db),
                                    referencedColumn: $$MerchantsTableReferences
                                        ._defaultCategoryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (financeTransactionsRefs)
                        await $_getPrefetchedData<
                          Merchant,
                          $MerchantsTable,
                          FinanceTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$MerchantsTableReferences
                              ._financeTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MerchantsTableReferences(
                                db,
                                table,
                                p0,
                              ).financeTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.merchantId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recurringRulesRefs)
                        await $_getPrefetchedData<
                          Merchant,
                          $MerchantsTable,
                          RecurringRule
                        >(
                          currentTable: table,
                          referencedTable: $$MerchantsTableReferences
                              ._recurringRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MerchantsTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.merchantId == item.id,
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

typedef $$MerchantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MerchantsTable,
      Merchant,
      $$MerchantsTableFilterComposer,
      $$MerchantsTableOrderingComposer,
      $$MerchantsTableAnnotationComposer,
      $$MerchantsTableCreateCompanionBuilder,
      $$MerchantsTableUpdateCompanionBuilder,
      (Merchant, $$MerchantsTableReferences),
      Merchant,
      PrefetchHooks Function({
        bool defaultCategoryId,
        bool financeTransactionsRefs,
        bool recurringRulesRefs,
      })
    >;
typedef $$PotsTableCreateCompanionBuilder =
    PotsCompanion Function({
      Value<int> id,
      required String name,
      required int colorValue,
      required int iconCodepoint,
      Value<int> sortOrder,
    });
typedef $$PotsTableUpdateCompanionBuilder =
    PotsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> colorValue,
      Value<int> iconCodepoint,
      Value<int> sortOrder,
    });

final class $$PotsTableReferences
    extends BaseReferences<_$AppDatabase, $PotsTable, Pot> {
  $$PotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $FinanceTransactionsTable,
    List<FinanceTransaction>
  >
  _financeTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.financeTransactions,
        aliasName: 'pots__id__finance_transactions__pot_id',
      );

  $$FinanceTransactionsTableProcessedTableManager get financeTransactionsRefs {
    final manager = $$FinanceTransactionsTableTableManager(
      $_db,
      $_db.financeTransactions,
    ).filter((f) => f.potId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _financeTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecurringRulesTable, List<RecurringRule>>
  _recurringRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recurringRules,
    aliasName: 'pots__id__recurring_rules__pot_id',
  );

  $$RecurringRulesTableProcessedTableManager get recurringRulesRefs {
    final manager = $$RecurringRulesTableTableManager(
      $_db,
      $_db.recurringRules,
    ).filter((f) => f.potId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_recurringRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AllocationRulesTable, List<AllocationRule>>
  _allocationRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.allocationRules,
    aliasName: 'pots__id__allocation_rules__pot_id',
  );

  $$AllocationRulesTableProcessedTableManager get allocationRulesRefs {
    final manager = $$AllocationRulesTableTableManager(
      $_db,
      $_db.allocationRules,
    ).filter((f) => f.potId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _allocationRulesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PotsTableFilterComposer extends Composer<_$AppDatabase, $PotsTable> {
  $$PotsTableFilterComposer({
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

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get iconCodepoint => $composableBuilder(
    column: $table.iconCodepoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> financeTransactionsRefs(
    Expression<bool> Function($$FinanceTransactionsTableFilterComposer f) f,
  ) {
    final $$FinanceTransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.financeTransactions,
      getReferencedColumn: (t) => t.potId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FinanceTransactionsTableFilterComposer(
            $db: $db,
            $table: $db.financeTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recurringRulesRefs(
    Expression<bool> Function($$RecurringRulesTableFilterComposer f) f,
  ) {
    final $$RecurringRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.potId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableFilterComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> allocationRulesRefs(
    Expression<bool> Function($$AllocationRulesTableFilterComposer f) f,
  ) {
    final $$AllocationRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.allocationRules,
      getReferencedColumn: (t) => t.potId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AllocationRulesTableFilterComposer(
            $db: $db,
            $table: $db.allocationRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PotsTableOrderingComposer extends Composer<_$AppDatabase, $PotsTable> {
  $$PotsTableOrderingComposer({
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

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get iconCodepoint => $composableBuilder(
    column: $table.iconCodepoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PotsTable> {
  $$PotsTableAnnotationComposer({
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

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get iconCodepoint => $composableBuilder(
    column: $table.iconCodepoint,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> financeTransactionsRefs<T extends Object>(
    Expression<T> Function($$FinanceTransactionsTableAnnotationComposer a) f,
  ) {
    final $$FinanceTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.financeTransactions,
          getReferencedColumn: (t) => t.potId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinanceTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.financeTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> recurringRulesRefs<T extends Object>(
    Expression<T> Function($$RecurringRulesTableAnnotationComposer a) f,
  ) {
    final $$RecurringRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.potId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> allocationRulesRefs<T extends Object>(
    Expression<T> Function($$AllocationRulesTableAnnotationComposer a) f,
  ) {
    final $$AllocationRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.allocationRules,
      getReferencedColumn: (t) => t.potId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AllocationRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.allocationRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PotsTable,
          Pot,
          $$PotsTableFilterComposer,
          $$PotsTableOrderingComposer,
          $$PotsTableAnnotationComposer,
          $$PotsTableCreateCompanionBuilder,
          $$PotsTableUpdateCompanionBuilder,
          (Pot, $$PotsTableReferences),
          Pot,
          PrefetchHooks Function({
            bool financeTransactionsRefs,
            bool recurringRulesRefs,
            bool allocationRulesRefs,
          })
        > {
  $$PotsTableTableManager(_$AppDatabase db, $PotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<int> iconCodepoint = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => PotsCompanion(
                id: id,
                name: name,
                colorValue: colorValue,
                iconCodepoint: iconCodepoint,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int colorValue,
                required int iconCodepoint,
                Value<int> sortOrder = const Value.absent(),
              }) => PotsCompanion.insert(
                id: id,
                name: name,
                colorValue: colorValue,
                iconCodepoint: iconCodepoint,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PotsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                financeTransactionsRefs = false,
                recurringRulesRefs = false,
                allocationRulesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (financeTransactionsRefs) db.financeTransactions,
                    if (recurringRulesRefs) db.recurringRules,
                    if (allocationRulesRefs) db.allocationRules,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (financeTransactionsRefs)
                        await $_getPrefetchedData<
                          Pot,
                          $PotsTable,
                          FinanceTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$PotsTableReferences
                              ._financeTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) => $$PotsTableReferences(
                            db,
                            table,
                            p0,
                          ).financeTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.potId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recurringRulesRefs)
                        await $_getPrefetchedData<
                          Pot,
                          $PotsTable,
                          RecurringRule
                        >(
                          currentTable: table,
                          referencedTable: $$PotsTableReferences
                              ._recurringRulesRefsTable(db),
                          managerFromTypedResult: (p0) => $$PotsTableReferences(
                            db,
                            table,
                            p0,
                          ).recurringRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.potId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (allocationRulesRefs)
                        await $_getPrefetchedData<
                          Pot,
                          $PotsTable,
                          AllocationRule
                        >(
                          currentTable: table,
                          referencedTable: $$PotsTableReferences
                              ._allocationRulesRefsTable(db),
                          managerFromTypedResult: (p0) => $$PotsTableReferences(
                            db,
                            table,
                            p0,
                          ).allocationRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.potId == item.id,
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

typedef $$PotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PotsTable,
      Pot,
      $$PotsTableFilterComposer,
      $$PotsTableOrderingComposer,
      $$PotsTableAnnotationComposer,
      $$PotsTableCreateCompanionBuilder,
      $$PotsTableUpdateCompanionBuilder,
      (Pot, $$PotsTableReferences),
      Pot,
      PrefetchHooks Function({
        bool financeTransactionsRefs,
        bool recurringRulesRefs,
        bool allocationRulesRefs,
      })
    >;
typedef $$FinanceTransactionsTableCreateCompanionBuilder =
    FinanceTransactionsCompanion Function({
      Value<int> id,
      required TxnKind kind,
      required int amountCents,
      required DateTime date,
      Value<String?> note,
      Value<int?> potId,
      Value<int?> merchantId,
      Value<int?> categoryId,
      Value<DateTime> createdAt,
    });
typedef $$FinanceTransactionsTableUpdateCompanionBuilder =
    FinanceTransactionsCompanion Function({
      Value<int> id,
      Value<TxnKind> kind,
      Value<int> amountCents,
      Value<DateTime> date,
      Value<String?> note,
      Value<int?> potId,
      Value<int?> merchantId,
      Value<int?> categoryId,
      Value<DateTime> createdAt,
    });

final class $$FinanceTransactionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FinanceTransactionsTable,
          FinanceTransaction
        > {
  $$FinanceTransactionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PotsTable _potIdTable(_$AppDatabase db) =>
      db.pots.createAlias('finance_transactions__pot_id__pots__id');

  $$PotsTableProcessedTableManager? get potId {
    final $_column = $_itemColumn<int>('pot_id');
    if ($_column == null) return null;
    final manager = $$PotsTableTableManager(
      $_db,
      $_db.pots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_potIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MerchantsTable _merchantIdTable(_$AppDatabase db) => db.merchants
      .createAlias('finance_transactions__merchant_id__merchants__id');

  $$MerchantsTableProcessedTableManager? get merchantId {
    final $_column = $_itemColumn<int>('merchant_id');
    if ($_column == null) return null;
    final manager = $$MerchantsTableTableManager(
      $_db,
      $_db.merchants,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_merchantIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) => db.categories
      .createAlias('finance_transactions__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<int>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FinanceTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $FinanceTransactionsTable> {
  $$FinanceTransactionsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<TxnKind, TxnKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PotsTableFilterComposer get potId {
    final $$PotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.potId,
      referencedTable: $db.pots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PotsTableFilterComposer(
            $db: $db,
            $table: $db.pots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MerchantsTableFilterComposer get merchantId {
    final $$MerchantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.merchantId,
      referencedTable: $db.merchants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantsTableFilterComposer(
            $db: $db,
            $table: $db.merchants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FinanceTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $FinanceTransactionsTable> {
  $$FinanceTransactionsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PotsTableOrderingComposer get potId {
    final $$PotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.potId,
      referencedTable: $db.pots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PotsTableOrderingComposer(
            $db: $db,
            $table: $db.pots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MerchantsTableOrderingComposer get merchantId {
    final $$MerchantsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.merchantId,
      referencedTable: $db.merchants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantsTableOrderingComposer(
            $db: $db,
            $table: $db.merchants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FinanceTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FinanceTransactionsTable> {
  $$FinanceTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxnKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PotsTableAnnotationComposer get potId {
    final $$PotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.potId,
      referencedTable: $db.pots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PotsTableAnnotationComposer(
            $db: $db,
            $table: $db.pots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MerchantsTableAnnotationComposer get merchantId {
    final $$MerchantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.merchantId,
      referencedTable: $db.merchants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantsTableAnnotationComposer(
            $db: $db,
            $table: $db.merchants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FinanceTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FinanceTransactionsTable,
          FinanceTransaction,
          $$FinanceTransactionsTableFilterComposer,
          $$FinanceTransactionsTableOrderingComposer,
          $$FinanceTransactionsTableAnnotationComposer,
          $$FinanceTransactionsTableCreateCompanionBuilder,
          $$FinanceTransactionsTableUpdateCompanionBuilder,
          (FinanceTransaction, $$FinanceTransactionsTableReferences),
          FinanceTransaction,
          PrefetchHooks Function({bool potId, bool merchantId, bool categoryId})
        > {
  $$FinanceTransactionsTableTableManager(
    _$AppDatabase db,
    $FinanceTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FinanceTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FinanceTransactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FinanceTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<TxnKind> kind = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> potId = const Value.absent(),
                Value<int?> merchantId = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FinanceTransactionsCompanion(
                id: id,
                kind: kind,
                amountCents: amountCents,
                date: date,
                note: note,
                potId: potId,
                merchantId: merchantId,
                categoryId: categoryId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required TxnKind kind,
                required int amountCents,
                required DateTime date,
                Value<String?> note = const Value.absent(),
                Value<int?> potId = const Value.absent(),
                Value<int?> merchantId = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FinanceTransactionsCompanion.insert(
                id: id,
                kind: kind,
                amountCents: amountCents,
                date: date,
                note: note,
                potId: potId,
                merchantId: merchantId,
                categoryId: categoryId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FinanceTransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({potId = false, merchantId = false, categoryId = false}) {
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
                        if (potId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.potId,
                                    referencedTable:
                                        $$FinanceTransactionsTableReferences
                                            ._potIdTable(db),
                                    referencedColumn:
                                        $$FinanceTransactionsTableReferences
                                            ._potIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (merchantId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.merchantId,
                                    referencedTable:
                                        $$FinanceTransactionsTableReferences
                                            ._merchantIdTable(db),
                                    referencedColumn:
                                        $$FinanceTransactionsTableReferences
                                            ._merchantIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (categoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryId,
                                    referencedTable:
                                        $$FinanceTransactionsTableReferences
                                            ._categoryIdTable(db),
                                    referencedColumn:
                                        $$FinanceTransactionsTableReferences
                                            ._categoryIdTable(db)
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

typedef $$FinanceTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FinanceTransactionsTable,
      FinanceTransaction,
      $$FinanceTransactionsTableFilterComposer,
      $$FinanceTransactionsTableOrderingComposer,
      $$FinanceTransactionsTableAnnotationComposer,
      $$FinanceTransactionsTableCreateCompanionBuilder,
      $$FinanceTransactionsTableUpdateCompanionBuilder,
      (FinanceTransaction, $$FinanceTransactionsTableReferences),
      FinanceTransaction,
      PrefetchHooks Function({bool potId, bool merchantId, bool categoryId})
    >;
typedef $$RecurringRulesTableCreateCompanionBuilder =
    RecurringRulesCompanion Function({
      Value<int> id,
      required String name,
      required TxnKind kind,
      required int amountCents,
      required Cadence cadence,
      required DateTime nextDue,
      Value<DateTime?> lastApplied,
      Value<int?> potId,
      Value<int?> merchantId,
      Value<int?> categoryId,
      Value<bool> active,
      Value<bool> isBill,
    });
typedef $$RecurringRulesTableUpdateCompanionBuilder =
    RecurringRulesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<TxnKind> kind,
      Value<int> amountCents,
      Value<Cadence> cadence,
      Value<DateTime> nextDue,
      Value<DateTime?> lastApplied,
      Value<int?> potId,
      Value<int?> merchantId,
      Value<int?> categoryId,
      Value<bool> active,
      Value<bool> isBill,
    });

final class $$RecurringRulesTableReferences
    extends BaseReferences<_$AppDatabase, $RecurringRulesTable, RecurringRule> {
  $$RecurringRulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PotsTable _potIdTable(_$AppDatabase db) =>
      db.pots.createAlias('recurring_rules__pot_id__pots__id');

  $$PotsTableProcessedTableManager? get potId {
    final $_column = $_itemColumn<int>('pot_id');
    if ($_column == null) return null;
    final manager = $$PotsTableTableManager(
      $_db,
      $_db.pots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_potIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MerchantsTable _merchantIdTable(_$AppDatabase db) =>
      db.merchants.createAlias('recurring_rules__merchant_id__merchants__id');

  $$MerchantsTableProcessedTableManager? get merchantId {
    final $_column = $_itemColumn<int>('merchant_id');
    if ($_column == null) return null;
    final manager = $$MerchantsTableTableManager(
      $_db,
      $_db.merchants,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_merchantIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('recurring_rules__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<int>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecurringRulesTableFilterComposer
    extends Composer<_$AppDatabase, $RecurringRulesTable> {
  $$RecurringRulesTableFilterComposer({
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

  ColumnWithTypeConverterFilters<TxnKind, TxnKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Cadence, Cadence, String> get cadence =>
      $composableBuilder(
        column: $table.cadence,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get nextDue => $composableBuilder(
    column: $table.nextDue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastApplied => $composableBuilder(
    column: $table.lastApplied,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBill => $composableBuilder(
    column: $table.isBill,
    builder: (column) => ColumnFilters(column),
  );

  $$PotsTableFilterComposer get potId {
    final $$PotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.potId,
      referencedTable: $db.pots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PotsTableFilterComposer(
            $db: $db,
            $table: $db.pots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MerchantsTableFilterComposer get merchantId {
    final $$MerchantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.merchantId,
      referencedTable: $db.merchants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantsTableFilterComposer(
            $db: $db,
            $table: $db.merchants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecurringRulesTable> {
  $$RecurringRulesTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cadence => $composableBuilder(
    column: $table.cadence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextDue => $composableBuilder(
    column: $table.nextDue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastApplied => $composableBuilder(
    column: $table.lastApplied,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBill => $composableBuilder(
    column: $table.isBill,
    builder: (column) => ColumnOrderings(column),
  );

  $$PotsTableOrderingComposer get potId {
    final $$PotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.potId,
      referencedTable: $db.pots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PotsTableOrderingComposer(
            $db: $db,
            $table: $db.pots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MerchantsTableOrderingComposer get merchantId {
    final $$MerchantsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.merchantId,
      referencedTable: $db.merchants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantsTableOrderingComposer(
            $db: $db,
            $table: $db.merchants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecurringRulesTable> {
  $$RecurringRulesTableAnnotationComposer({
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

  GeneratedColumnWithTypeConverter<TxnKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Cadence, String> get cadence =>
      $composableBuilder(column: $table.cadence, builder: (column) => column);

  GeneratedColumn<DateTime> get nextDue =>
      $composableBuilder(column: $table.nextDue, builder: (column) => column);

  GeneratedColumn<DateTime> get lastApplied => $composableBuilder(
    column: $table.lastApplied,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<bool> get isBill =>
      $composableBuilder(column: $table.isBill, builder: (column) => column);

  $$PotsTableAnnotationComposer get potId {
    final $$PotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.potId,
      referencedTable: $db.pots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PotsTableAnnotationComposer(
            $db: $db,
            $table: $db.pots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MerchantsTableAnnotationComposer get merchantId {
    final $$MerchantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.merchantId,
      referencedTable: $db.merchants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantsTableAnnotationComposer(
            $db: $db,
            $table: $db.merchants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecurringRulesTable,
          RecurringRule,
          $$RecurringRulesTableFilterComposer,
          $$RecurringRulesTableOrderingComposer,
          $$RecurringRulesTableAnnotationComposer,
          $$RecurringRulesTableCreateCompanionBuilder,
          $$RecurringRulesTableUpdateCompanionBuilder,
          (RecurringRule, $$RecurringRulesTableReferences),
          RecurringRule,
          PrefetchHooks Function({bool potId, bool merchantId, bool categoryId})
        > {
  $$RecurringRulesTableTableManager(
    _$AppDatabase db,
    $RecurringRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurringRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurringRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<TxnKind> kind = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<Cadence> cadence = const Value.absent(),
                Value<DateTime> nextDue = const Value.absent(),
                Value<DateTime?> lastApplied = const Value.absent(),
                Value<int?> potId = const Value.absent(),
                Value<int?> merchantId = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<bool> isBill = const Value.absent(),
              }) => RecurringRulesCompanion(
                id: id,
                name: name,
                kind: kind,
                amountCents: amountCents,
                cadence: cadence,
                nextDue: nextDue,
                lastApplied: lastApplied,
                potId: potId,
                merchantId: merchantId,
                categoryId: categoryId,
                active: active,
                isBill: isBill,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required TxnKind kind,
                required int amountCents,
                required Cadence cadence,
                required DateTime nextDue,
                Value<DateTime?> lastApplied = const Value.absent(),
                Value<int?> potId = const Value.absent(),
                Value<int?> merchantId = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<bool> isBill = const Value.absent(),
              }) => RecurringRulesCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                amountCents: amountCents,
                cadence: cadence,
                nextDue: nextDue,
                lastApplied: lastApplied,
                potId: potId,
                merchantId: merchantId,
                categoryId: categoryId,
                active: active,
                isBill: isBill,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecurringRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({potId = false, merchantId = false, categoryId = false}) {
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
                        if (potId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.potId,
                                    referencedTable:
                                        $$RecurringRulesTableReferences
                                            ._potIdTable(db),
                                    referencedColumn:
                                        $$RecurringRulesTableReferences
                                            ._potIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (merchantId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.merchantId,
                                    referencedTable:
                                        $$RecurringRulesTableReferences
                                            ._merchantIdTable(db),
                                    referencedColumn:
                                        $$RecurringRulesTableReferences
                                            ._merchantIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (categoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryId,
                                    referencedTable:
                                        $$RecurringRulesTableReferences
                                            ._categoryIdTable(db),
                                    referencedColumn:
                                        $$RecurringRulesTableReferences
                                            ._categoryIdTable(db)
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

typedef $$RecurringRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecurringRulesTable,
      RecurringRule,
      $$RecurringRulesTableFilterComposer,
      $$RecurringRulesTableOrderingComposer,
      $$RecurringRulesTableAnnotationComposer,
      $$RecurringRulesTableCreateCompanionBuilder,
      $$RecurringRulesTableUpdateCompanionBuilder,
      (RecurringRule, $$RecurringRulesTableReferences),
      RecurringRule,
      PrefetchHooks Function({bool potId, bool merchantId, bool categoryId})
    >;
typedef $$AllocationRulesTableCreateCompanionBuilder =
    AllocationRulesCompanion Function({
      Value<int> id,
      required int potId,
      required AllocMode mode,
      Value<int> valueCents,
      Value<int> percentBps,
      required Cadence cadence,
      required DateTime nextDue,
      Value<DateTime?> lastApplied,
      Value<bool> active,
    });
typedef $$AllocationRulesTableUpdateCompanionBuilder =
    AllocationRulesCompanion Function({
      Value<int> id,
      Value<int> potId,
      Value<AllocMode> mode,
      Value<int> valueCents,
      Value<int> percentBps,
      Value<Cadence> cadence,
      Value<DateTime> nextDue,
      Value<DateTime?> lastApplied,
      Value<bool> active,
    });

final class $$AllocationRulesTableReferences
    extends
        BaseReferences<_$AppDatabase, $AllocationRulesTable, AllocationRule> {
  $$AllocationRulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PotsTable _potIdTable(_$AppDatabase db) =>
      db.pots.createAlias('allocation_rules__pot_id__pots__id');

  $$PotsTableProcessedTableManager get potId {
    final $_column = $_itemColumn<int>('pot_id')!;

    final manager = $$PotsTableTableManager(
      $_db,
      $_db.pots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_potIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AllocationRulesTableFilterComposer
    extends Composer<_$AppDatabase, $AllocationRulesTable> {
  $$AllocationRulesTableFilterComposer({
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

  ColumnWithTypeConverterFilters<AllocMode, AllocMode, String> get mode =>
      $composableBuilder(
        column: $table.mode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get valueCents => $composableBuilder(
    column: $table.valueCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get percentBps => $composableBuilder(
    column: $table.percentBps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Cadence, Cadence, String> get cadence =>
      $composableBuilder(
        column: $table.cadence,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get nextDue => $composableBuilder(
    column: $table.nextDue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastApplied => $composableBuilder(
    column: $table.lastApplied,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  $$PotsTableFilterComposer get potId {
    final $$PotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.potId,
      referencedTable: $db.pots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PotsTableFilterComposer(
            $db: $db,
            $table: $db.pots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AllocationRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $AllocationRulesTable> {
  $$AllocationRulesTableOrderingComposer({
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

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get valueCents => $composableBuilder(
    column: $table.valueCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get percentBps => $composableBuilder(
    column: $table.percentBps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cadence => $composableBuilder(
    column: $table.cadence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextDue => $composableBuilder(
    column: $table.nextDue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastApplied => $composableBuilder(
    column: $table.lastApplied,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  $$PotsTableOrderingComposer get potId {
    final $$PotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.potId,
      referencedTable: $db.pots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PotsTableOrderingComposer(
            $db: $db,
            $table: $db.pots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AllocationRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AllocationRulesTable> {
  $$AllocationRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AllocMode, String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get valueCents => $composableBuilder(
    column: $table.valueCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get percentBps => $composableBuilder(
    column: $table.percentBps,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Cadence, String> get cadence =>
      $composableBuilder(column: $table.cadence, builder: (column) => column);

  GeneratedColumn<DateTime> get nextDue =>
      $composableBuilder(column: $table.nextDue, builder: (column) => column);

  GeneratedColumn<DateTime> get lastApplied => $composableBuilder(
    column: $table.lastApplied,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  $$PotsTableAnnotationComposer get potId {
    final $$PotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.potId,
      referencedTable: $db.pots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PotsTableAnnotationComposer(
            $db: $db,
            $table: $db.pots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AllocationRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AllocationRulesTable,
          AllocationRule,
          $$AllocationRulesTableFilterComposer,
          $$AllocationRulesTableOrderingComposer,
          $$AllocationRulesTableAnnotationComposer,
          $$AllocationRulesTableCreateCompanionBuilder,
          $$AllocationRulesTableUpdateCompanionBuilder,
          (AllocationRule, $$AllocationRulesTableReferences),
          AllocationRule,
          PrefetchHooks Function({bool potId})
        > {
  $$AllocationRulesTableTableManager(
    _$AppDatabase db,
    $AllocationRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AllocationRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AllocationRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AllocationRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> potId = const Value.absent(),
                Value<AllocMode> mode = const Value.absent(),
                Value<int> valueCents = const Value.absent(),
                Value<int> percentBps = const Value.absent(),
                Value<Cadence> cadence = const Value.absent(),
                Value<DateTime> nextDue = const Value.absent(),
                Value<DateTime?> lastApplied = const Value.absent(),
                Value<bool> active = const Value.absent(),
              }) => AllocationRulesCompanion(
                id: id,
                potId: potId,
                mode: mode,
                valueCents: valueCents,
                percentBps: percentBps,
                cadence: cadence,
                nextDue: nextDue,
                lastApplied: lastApplied,
                active: active,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int potId,
                required AllocMode mode,
                Value<int> valueCents = const Value.absent(),
                Value<int> percentBps = const Value.absent(),
                required Cadence cadence,
                required DateTime nextDue,
                Value<DateTime?> lastApplied = const Value.absent(),
                Value<bool> active = const Value.absent(),
              }) => AllocationRulesCompanion.insert(
                id: id,
                potId: potId,
                mode: mode,
                valueCents: valueCents,
                percentBps: percentBps,
                cadence: cadence,
                nextDue: nextDue,
                lastApplied: lastApplied,
                active: active,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AllocationRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({potId = false}) {
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
                    if (potId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.potId,
                                referencedTable:
                                    $$AllocationRulesTableReferences
                                        ._potIdTable(db),
                                referencedColumn:
                                    $$AllocationRulesTableReferences
                                        ._potIdTable(db)
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

typedef $$AllocationRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AllocationRulesTable,
      AllocationRule,
      $$AllocationRulesTableFilterComposer,
      $$AllocationRulesTableOrderingComposer,
      $$AllocationRulesTableAnnotationComposer,
      $$AllocationRulesTableCreateCompanionBuilder,
      $$AllocationRulesTableUpdateCompanionBuilder,
      (AllocationRule, $$AllocationRulesTableReferences),
      AllocationRule,
      PrefetchHooks Function({bool potId})
    >;
typedef $$HoldingsTableCreateCompanionBuilder =
    HoldingsCompanion Function({
      Value<int> id,
      required String ticker,
      required String name,
      required double shares,
      required int avgCostCents,
      Value<int?> lastPriceCents,
      Value<DateTime?> lastPriceAt,
    });
typedef $$HoldingsTableUpdateCompanionBuilder =
    HoldingsCompanion Function({
      Value<int> id,
      Value<String> ticker,
      Value<String> name,
      Value<double> shares,
      Value<int> avgCostCents,
      Value<int?> lastPriceCents,
      Value<DateTime?> lastPriceAt,
    });

class $$HoldingsTableFilterComposer
    extends Composer<_$AppDatabase, $HoldingsTable> {
  $$HoldingsTableFilterComposer({
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

  ColumnFilters<String> get ticker => $composableBuilder(
    column: $table.ticker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get shares => $composableBuilder(
    column: $table.shares,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avgCostCents => $composableBuilder(
    column: $table.avgCostCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPriceCents => $composableBuilder(
    column: $table.lastPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPriceAt => $composableBuilder(
    column: $table.lastPriceAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HoldingsTableOrderingComposer
    extends Composer<_$AppDatabase, $HoldingsTable> {
  $$HoldingsTableOrderingComposer({
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

  ColumnOrderings<String> get ticker => $composableBuilder(
    column: $table.ticker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get shares => $composableBuilder(
    column: $table.shares,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avgCostCents => $composableBuilder(
    column: $table.avgCostCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPriceCents => $composableBuilder(
    column: $table.lastPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPriceAt => $composableBuilder(
    column: $table.lastPriceAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HoldingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HoldingsTable> {
  $$HoldingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ticker =>
      $composableBuilder(column: $table.ticker, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get shares =>
      $composableBuilder(column: $table.shares, builder: (column) => column);

  GeneratedColumn<int> get avgCostCents => $composableBuilder(
    column: $table.avgCostCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPriceCents => $composableBuilder(
    column: $table.lastPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPriceAt => $composableBuilder(
    column: $table.lastPriceAt,
    builder: (column) => column,
  );
}

class $$HoldingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HoldingsTable,
          Holding,
          $$HoldingsTableFilterComposer,
          $$HoldingsTableOrderingComposer,
          $$HoldingsTableAnnotationComposer,
          $$HoldingsTableCreateCompanionBuilder,
          $$HoldingsTableUpdateCompanionBuilder,
          (Holding, BaseReferences<_$AppDatabase, $HoldingsTable, Holding>),
          Holding,
          PrefetchHooks Function()
        > {
  $$HoldingsTableTableManager(_$AppDatabase db, $HoldingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HoldingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HoldingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HoldingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> ticker = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> shares = const Value.absent(),
                Value<int> avgCostCents = const Value.absent(),
                Value<int?> lastPriceCents = const Value.absent(),
                Value<DateTime?> lastPriceAt = const Value.absent(),
              }) => HoldingsCompanion(
                id: id,
                ticker: ticker,
                name: name,
                shares: shares,
                avgCostCents: avgCostCents,
                lastPriceCents: lastPriceCents,
                lastPriceAt: lastPriceAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String ticker,
                required String name,
                required double shares,
                required int avgCostCents,
                Value<int?> lastPriceCents = const Value.absent(),
                Value<DateTime?> lastPriceAt = const Value.absent(),
              }) => HoldingsCompanion.insert(
                id: id,
                ticker: ticker,
                name: name,
                shares: shares,
                avgCostCents: avgCostCents,
                lastPriceCents: lastPriceCents,
                lastPriceAt: lastPriceAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HoldingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HoldingsTable,
      Holding,
      $$HoldingsTableFilterComposer,
      $$HoldingsTableOrderingComposer,
      $$HoldingsTableAnnotationComposer,
      $$HoldingsTableCreateCompanionBuilder,
      $$HoldingsTableUpdateCompanionBuilder,
      (Holding, BaseReferences<_$AppDatabase, $HoldingsTable, Holding>),
      Holding,
      PrefetchHooks Function()
    >;
typedef $$MetaItemsTableCreateCompanionBuilder =
    MetaItemsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MetaItemsTableUpdateCompanionBuilder =
    MetaItemsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MetaItemsTableFilterComposer
    extends Composer<_$AppDatabase, $MetaItemsTable> {
  $$MetaItemsTableFilterComposer({
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

class $$MetaItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $MetaItemsTable> {
  $$MetaItemsTableOrderingComposer({
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

class $$MetaItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaItemsTable> {
  $$MetaItemsTableAnnotationComposer({
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

class $$MetaItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaItemsTable,
          MetaItem,
          $$MetaItemsTableFilterComposer,
          $$MetaItemsTableOrderingComposer,
          $$MetaItemsTableAnnotationComposer,
          $$MetaItemsTableCreateCompanionBuilder,
          $$MetaItemsTableUpdateCompanionBuilder,
          (MetaItem, BaseReferences<_$AppDatabase, $MetaItemsTable, MetaItem>),
          MetaItem,
          PrefetchHooks Function()
        > {
  $$MetaItemsTableTableManager(_$AppDatabase db, $MetaItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaItemsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MetaItemsCompanion.insert(
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

typedef $$MetaItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaItemsTable,
      MetaItem,
      $$MetaItemsTableFilterComposer,
      $$MetaItemsTableOrderingComposer,
      $$MetaItemsTableAnnotationComposer,
      $$MetaItemsTableCreateCompanionBuilder,
      $$MetaItemsTableUpdateCompanionBuilder,
      (MetaItem, BaseReferences<_$AppDatabase, $MetaItemsTable, MetaItem>),
      MetaItem,
      PrefetchHooks Function()
    >;
typedef $$OverviewGraphsTableCreateCompanionBuilder =
    OverviewGraphsCompanion Function({
      Value<int> id,
      required String graphType,
      required String dataSource,
      Value<int> sortOrder,
    });
typedef $$OverviewGraphsTableUpdateCompanionBuilder =
    OverviewGraphsCompanion Function({
      Value<int> id,
      Value<String> graphType,
      Value<String> dataSource,
      Value<int> sortOrder,
    });

class $$OverviewGraphsTableFilterComposer
    extends Composer<_$AppDatabase, $OverviewGraphsTable> {
  $$OverviewGraphsTableFilterComposer({
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

  ColumnFilters<String> get graphType => $composableBuilder(
    column: $table.graphType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataSource => $composableBuilder(
    column: $table.dataSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OverviewGraphsTableOrderingComposer
    extends Composer<_$AppDatabase, $OverviewGraphsTable> {
  $$OverviewGraphsTableOrderingComposer({
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

  ColumnOrderings<String> get graphType => $composableBuilder(
    column: $table.graphType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataSource => $composableBuilder(
    column: $table.dataSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OverviewGraphsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OverviewGraphsTable> {
  $$OverviewGraphsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get graphType =>
      $composableBuilder(column: $table.graphType, builder: (column) => column);

  GeneratedColumn<String> get dataSource => $composableBuilder(
    column: $table.dataSource,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$OverviewGraphsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OverviewGraphsTable,
          OverviewGraph,
          $$OverviewGraphsTableFilterComposer,
          $$OverviewGraphsTableOrderingComposer,
          $$OverviewGraphsTableAnnotationComposer,
          $$OverviewGraphsTableCreateCompanionBuilder,
          $$OverviewGraphsTableUpdateCompanionBuilder,
          (
            OverviewGraph,
            BaseReferences<_$AppDatabase, $OverviewGraphsTable, OverviewGraph>,
          ),
          OverviewGraph,
          PrefetchHooks Function()
        > {
  $$OverviewGraphsTableTableManager(
    _$AppDatabase db,
    $OverviewGraphsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OverviewGraphsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OverviewGraphsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OverviewGraphsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> graphType = const Value.absent(),
                Value<String> dataSource = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => OverviewGraphsCompanion(
                id: id,
                graphType: graphType,
                dataSource: dataSource,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String graphType,
                required String dataSource,
                Value<int> sortOrder = const Value.absent(),
              }) => OverviewGraphsCompanion.insert(
                id: id,
                graphType: graphType,
                dataSource: dataSource,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OverviewGraphsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OverviewGraphsTable,
      OverviewGraph,
      $$OverviewGraphsTableFilterComposer,
      $$OverviewGraphsTableOrderingComposer,
      $$OverviewGraphsTableAnnotationComposer,
      $$OverviewGraphsTableCreateCompanionBuilder,
      $$OverviewGraphsTableUpdateCompanionBuilder,
      (
        OverviewGraph,
        BaseReferences<_$AppDatabase, $OverviewGraphsTable, OverviewGraph>,
      ),
      OverviewGraph,
      PrefetchHooks Function()
    >;
typedef $$BalanceSnapshotsTableCreateCompanionBuilder =
    BalanceSnapshotsCompanion Function({
      Value<int> id,
      required DateTime date,
      required int totalCents,
    });
typedef $$BalanceSnapshotsTableUpdateCompanionBuilder =
    BalanceSnapshotsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<int> totalCents,
    });

class $$BalanceSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $BalanceSnapshotsTable> {
  $$BalanceSnapshotsTableFilterComposer({
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

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BalanceSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $BalanceSnapshotsTable> {
  $$BalanceSnapshotsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BalanceSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BalanceSnapshotsTable> {
  $$BalanceSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => column,
  );
}

class $$BalanceSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BalanceSnapshotsTable,
          BalanceSnapshot,
          $$BalanceSnapshotsTableFilterComposer,
          $$BalanceSnapshotsTableOrderingComposer,
          $$BalanceSnapshotsTableAnnotationComposer,
          $$BalanceSnapshotsTableCreateCompanionBuilder,
          $$BalanceSnapshotsTableUpdateCompanionBuilder,
          (
            BalanceSnapshot,
            BaseReferences<
              _$AppDatabase,
              $BalanceSnapshotsTable,
              BalanceSnapshot
            >,
          ),
          BalanceSnapshot,
          PrefetchHooks Function()
        > {
  $$BalanceSnapshotsTableTableManager(
    _$AppDatabase db,
    $BalanceSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BalanceSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BalanceSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BalanceSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> totalCents = const Value.absent(),
              }) => BalanceSnapshotsCompanion(
                id: id,
                date: date,
                totalCents: totalCents,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required int totalCents,
              }) => BalanceSnapshotsCompanion.insert(
                id: id,
                date: date,
                totalCents: totalCents,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BalanceSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BalanceSnapshotsTable,
      BalanceSnapshot,
      $$BalanceSnapshotsTableFilterComposer,
      $$BalanceSnapshotsTableOrderingComposer,
      $$BalanceSnapshotsTableAnnotationComposer,
      $$BalanceSnapshotsTableCreateCompanionBuilder,
      $$BalanceSnapshotsTableUpdateCompanionBuilder,
      (
        BalanceSnapshot,
        BaseReferences<_$AppDatabase, $BalanceSnapshotsTable, BalanceSnapshot>,
      ),
      BalanceSnapshot,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$MerchantsTableTableManager get merchants =>
      $$MerchantsTableTableManager(_db, _db.merchants);
  $$PotsTableTableManager get pots => $$PotsTableTableManager(_db, _db.pots);
  $$FinanceTransactionsTableTableManager get financeTransactions =>
      $$FinanceTransactionsTableTableManager(_db, _db.financeTransactions);
  $$RecurringRulesTableTableManager get recurringRules =>
      $$RecurringRulesTableTableManager(_db, _db.recurringRules);
  $$AllocationRulesTableTableManager get allocationRules =>
      $$AllocationRulesTableTableManager(_db, _db.allocationRules);
  $$HoldingsTableTableManager get holdings =>
      $$HoldingsTableTableManager(_db, _db.holdings);
  $$MetaItemsTableTableManager get metaItems =>
      $$MetaItemsTableTableManager(_db, _db.metaItems);
  $$OverviewGraphsTableTableManager get overviewGraphs =>
      $$OverviewGraphsTableTableManager(_db, _db.overviewGraphs);
  $$BalanceSnapshotsTableTableManager get balanceSnapshots =>
      $$BalanceSnapshotsTableTableManager(_db, _db.balanceSnapshots);
}
