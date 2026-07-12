// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'groceries_database.dart';

// ignore_for_file: type=lint
class $GroceryListsTable extends GroceryLists
    with TableInfo<$GroceryListsTable, GroceryList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroceryListsTable(this.attachedDatabase, [this._alias]);
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
  List<GeneratedColumn> get $columns => [id, name, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'grocery_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroceryList> instance, {
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
  GroceryList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroceryList(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
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
  $GroceryListsTable createAlias(String alias) {
    return $GroceryListsTable(attachedDatabase, alias);
  }
}

class GroceryList extends DataClass implements Insertable<GroceryList> {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  const GroceryList({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GroceryListsCompanion toCompanion(bool nullToAbsent) {
    return GroceryListsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory GroceryList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroceryList(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
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
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GroceryList copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GroceryList(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GroceryList copyWithCompanion(GroceryListsCompanion data) {
    return GroceryList(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroceryList(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroceryList &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GroceryListsCompanion extends UpdateCompanion<GroceryList> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const GroceryListsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  GroceryListsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<GroceryList> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  GroceryListsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return GroceryListsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
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
    return (StringBuffer('GroceryListsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $GroceryListItemsTable extends GroceryListItems
    with TableInfo<$GroceryListItemsTable, GroceryListItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroceryListItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<int> listId = GeneratedColumn<int>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES grocery_lists (id)',
    ),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _marketMeta = const VerificationMeta('market');
  @override
  late final GeneratedColumn<String> market = GeneratedColumn<String>(
    'market',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _marketNameMeta = const VerificationMeta(
    'marketName',
  );
  @override
  late final GeneratedColumn<String> marketName = GeneratedColumn<String>(
    'market_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    listId,
    productId,
    market,
    marketName,
    name,
    brand,
    imageUrl,
    category,
    price,
    quantity,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'grocery_list_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroceryListItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    }
    if (data.containsKey('market')) {
      context.handle(
        _marketMeta,
        market.isAcceptableOrUnknown(data['market']!, _marketMeta),
      );
    } else if (isInserting) {
      context.missing(_marketMeta);
    }
    if (data.containsKey('market_name')) {
      context.handle(
        _marketNameMeta,
        marketName.isAcceptableOrUnknown(data['market_name']!, _marketNameMeta),
      );
    } else if (isInserting) {
      context.missing(_marketNameMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GroceryListItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroceryListItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}list_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      ),
      market: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}market'],
      )!,
      marketName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}market_name'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      ),
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $GroceryListItemsTable createAlias(String alias) {
    return $GroceryListItemsTable(attachedDatabase, alias);
  }
}

class GroceryListItem extends DataClass implements Insertable<GroceryListItem> {
  final int id;
  final int listId;

  /// The remote product id from the supermarket-db search API, if this item
  /// came from a search result (always true today, but kept nullable for
  /// manually-added items down the line).
  final String? productId;

  /// Supermarket slug: 'jumbo', 'ah', or 'lidl'.
  final String market;
  final String marketName;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String? category;
  final double? price;
  final int quantity;
  final DateTime addedAt;
  const GroceryListItem({
    required this.id,
    required this.listId,
    this.productId,
    required this.market,
    required this.marketName,
    required this.name,
    this.brand,
    this.imageUrl,
    this.category,
    this.price,
    required this.quantity,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['list_id'] = Variable<int>(listId);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    map['market'] = Variable<String>(market);
    map['market_name'] = Variable<String>(marketName);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<double>(price);
    }
    map['quantity'] = Variable<int>(quantity);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  GroceryListItemsCompanion toCompanion(bool nullToAbsent) {
    return GroceryListItemsCompanion(
      id: Value(id),
      listId: Value(listId),
      productId: productId == null && nullToAbsent
          ? const Value.absent()
          : Value(productId),
      market: Value(market),
      marketName: Value(marketName),
      name: Value(name),
      brand: brand == null && nullToAbsent
          ? const Value.absent()
          : Value(brand),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      price: price == null && nullToAbsent
          ? const Value.absent()
          : Value(price),
      quantity: Value(quantity),
      addedAt: Value(addedAt),
    );
  }

  factory GroceryListItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroceryListItem(
      id: serializer.fromJson<int>(json['id']),
      listId: serializer.fromJson<int>(json['listId']),
      productId: serializer.fromJson<String?>(json['productId']),
      market: serializer.fromJson<String>(json['market']),
      marketName: serializer.fromJson<String>(json['marketName']),
      name: serializer.fromJson<String>(json['name']),
      brand: serializer.fromJson<String?>(json['brand']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      category: serializer.fromJson<String?>(json['category']),
      price: serializer.fromJson<double?>(json['price']),
      quantity: serializer.fromJson<int>(json['quantity']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'listId': serializer.toJson<int>(listId),
      'productId': serializer.toJson<String?>(productId),
      'market': serializer.toJson<String>(market),
      'marketName': serializer.toJson<String>(marketName),
      'name': serializer.toJson<String>(name),
      'brand': serializer.toJson<String?>(brand),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'category': serializer.toJson<String?>(category),
      'price': serializer.toJson<double?>(price),
      'quantity': serializer.toJson<int>(quantity),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  GroceryListItem copyWith({
    int? id,
    int? listId,
    Value<String?> productId = const Value.absent(),
    String? market,
    String? marketName,
    String? name,
    Value<String?> brand = const Value.absent(),
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> category = const Value.absent(),
    Value<double?> price = const Value.absent(),
    int? quantity,
    DateTime? addedAt,
  }) => GroceryListItem(
    id: id ?? this.id,
    listId: listId ?? this.listId,
    productId: productId.present ? productId.value : this.productId,
    market: market ?? this.market,
    marketName: marketName ?? this.marketName,
    name: name ?? this.name,
    brand: brand.present ? brand.value : this.brand,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    category: category.present ? category.value : this.category,
    price: price.present ? price.value : this.price,
    quantity: quantity ?? this.quantity,
    addedAt: addedAt ?? this.addedAt,
  );
  GroceryListItem copyWithCompanion(GroceryListItemsCompanion data) {
    return GroceryListItem(
      id: data.id.present ? data.id.value : this.id,
      listId: data.listId.present ? data.listId.value : this.listId,
      productId: data.productId.present ? data.productId.value : this.productId,
      market: data.market.present ? data.market.value : this.market,
      marketName: data.marketName.present
          ? data.marketName.value
          : this.marketName,
      name: data.name.present ? data.name.value : this.name,
      brand: data.brand.present ? data.brand.value : this.brand,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      category: data.category.present ? data.category.value : this.category,
      price: data.price.present ? data.price.value : this.price,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroceryListItem(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('productId: $productId, ')
          ..write('market: $market, ')
          ..write('marketName: $marketName, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('category: $category, ')
          ..write('price: $price, ')
          ..write('quantity: $quantity, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    listId,
    productId,
    market,
    marketName,
    name,
    brand,
    imageUrl,
    category,
    price,
    quantity,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroceryListItem &&
          other.id == this.id &&
          other.listId == this.listId &&
          other.productId == this.productId &&
          other.market == this.market &&
          other.marketName == this.marketName &&
          other.name == this.name &&
          other.brand == this.brand &&
          other.imageUrl == this.imageUrl &&
          other.category == this.category &&
          other.price == this.price &&
          other.quantity == this.quantity &&
          other.addedAt == this.addedAt);
}

class GroceryListItemsCompanion extends UpdateCompanion<GroceryListItem> {
  final Value<int> id;
  final Value<int> listId;
  final Value<String?> productId;
  final Value<String> market;
  final Value<String> marketName;
  final Value<String> name;
  final Value<String?> brand;
  final Value<String?> imageUrl;
  final Value<String?> category;
  final Value<double?> price;
  final Value<int> quantity;
  final Value<DateTime> addedAt;
  const GroceryListItemsCompanion({
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    this.productId = const Value.absent(),
    this.market = const Value.absent(),
    this.marketName = const Value.absent(),
    this.name = const Value.absent(),
    this.brand = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.category = const Value.absent(),
    this.price = const Value.absent(),
    this.quantity = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  GroceryListItemsCompanion.insert({
    this.id = const Value.absent(),
    required int listId,
    this.productId = const Value.absent(),
    required String market,
    required String marketName,
    required String name,
    this.brand = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.category = const Value.absent(),
    this.price = const Value.absent(),
    this.quantity = const Value.absent(),
    this.addedAt = const Value.absent(),
  }) : listId = Value(listId),
       market = Value(market),
       marketName = Value(marketName),
       name = Value(name);
  static Insertable<GroceryListItem> custom({
    Expression<int>? id,
    Expression<int>? listId,
    Expression<String>? productId,
    Expression<String>? market,
    Expression<String>? marketName,
    Expression<String>? name,
    Expression<String>? brand,
    Expression<String>? imageUrl,
    Expression<String>? category,
    Expression<double>? price,
    Expression<int>? quantity,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (listId != null) 'list_id': listId,
      if (productId != null) 'product_id': productId,
      if (market != null) 'market': market,
      if (marketName != null) 'market_name': marketName,
      if (name != null) 'name': name,
      if (brand != null) 'brand': brand,
      if (imageUrl != null) 'image_url': imageUrl,
      if (category != null) 'category': category,
      if (price != null) 'price': price,
      if (quantity != null) 'quantity': quantity,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  GroceryListItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? listId,
    Value<String?>? productId,
    Value<String>? market,
    Value<String>? marketName,
    Value<String>? name,
    Value<String?>? brand,
    Value<String?>? imageUrl,
    Value<String?>? category,
    Value<double?>? price,
    Value<int>? quantity,
    Value<DateTime>? addedAt,
  }) {
    return GroceryListItemsCompanion(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      productId: productId ?? this.productId,
      market: market ?? this.market,
      marketName: marketName ?? this.marketName,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<int>(listId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (market.present) {
      map['market'] = Variable<String>(market.value);
    }
    if (marketName.present) {
      map['market_name'] = Variable<String>(marketName.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroceryListItemsCompanion(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('productId: $productId, ')
          ..write('market: $market, ')
          ..write('marketName: $marketName, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('category: $category, ')
          ..write('price: $price, ')
          ..write('quantity: $quantity, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$GroceriesDatabase extends GeneratedDatabase {
  _$GroceriesDatabase(QueryExecutor e) : super(e);
  $GroceriesDatabaseManager get managers => $GroceriesDatabaseManager(this);
  late final $GroceryListsTable groceryLists = $GroceryListsTable(this);
  late final $GroceryListItemsTable groceryListItems = $GroceryListItemsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    groceryLists,
    groceryListItems,
  ];
}

typedef $$GroceryListsTableCreateCompanionBuilder =
    GroceryListsCompanion Function({
      Value<int> id,
      required String name,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$GroceryListsTableUpdateCompanionBuilder =
    GroceryListsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$GroceryListsTableReferences
    extends
        BaseReferences<_$GroceriesDatabase, $GroceryListsTable, GroceryList> {
  $$GroceryListsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GroceryListItemsTable, List<GroceryListItem>>
  _groceryListItemsRefsTable(_$GroceriesDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.groceryListItems,
        aliasName: 'grocery_lists__id__grocery_list_items__list_id',
      );

  $$GroceryListItemsTableProcessedTableManager get groceryListItemsRefs {
    final manager = $$GroceryListItemsTableTableManager(
      $_db,
      $_db.groceryListItems,
    ).filter((f) => f.listId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _groceryListItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GroceryListsTableFilterComposer
    extends Composer<_$GroceriesDatabase, $GroceryListsTable> {
  $$GroceryListsTableFilterComposer({
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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> groceryListItemsRefs(
    Expression<bool> Function($$GroceryListItemsTableFilterComposer f) f,
  ) {
    final $$GroceryListItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groceryListItems,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroceryListItemsTableFilterComposer(
            $db: $db,
            $table: $db.groceryListItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GroceryListsTableOrderingComposer
    extends Composer<_$GroceriesDatabase, $GroceryListsTable> {
  $$GroceryListsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroceryListsTableAnnotationComposer
    extends Composer<_$GroceriesDatabase, $GroceryListsTable> {
  $$GroceryListsTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> groceryListItemsRefs<T extends Object>(
    Expression<T> Function($$GroceryListItemsTableAnnotationComposer a) f,
  ) {
    final $$GroceryListItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groceryListItems,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroceryListItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.groceryListItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GroceryListsTableTableManager
    extends
        RootTableManager<
          _$GroceriesDatabase,
          $GroceryListsTable,
          GroceryList,
          $$GroceryListsTableFilterComposer,
          $$GroceryListsTableOrderingComposer,
          $$GroceryListsTableAnnotationComposer,
          $$GroceryListsTableCreateCompanionBuilder,
          $$GroceryListsTableUpdateCompanionBuilder,
          (GroceryList, $$GroceryListsTableReferences),
          GroceryList,
          PrefetchHooks Function({bool groceryListItemsRefs})
        > {
  $$GroceryListsTableTableManager(
    _$GroceriesDatabase db,
    $GroceryListsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroceryListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroceryListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroceryListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => GroceryListsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => GroceryListsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GroceryListsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groceryListItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (groceryListItemsRefs) db.groceryListItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (groceryListItemsRefs)
                    await $_getPrefetchedData<
                      GroceryList,
                      $GroceryListsTable,
                      GroceryListItem
                    >(
                      currentTable: table,
                      referencedTable: $$GroceryListsTableReferences
                          ._groceryListItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$GroceryListsTableReferences(
                            db,
                            table,
                            p0,
                          ).groceryListItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.listId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$GroceryListsTableProcessedTableManager =
    ProcessedTableManager<
      _$GroceriesDatabase,
      $GroceryListsTable,
      GroceryList,
      $$GroceryListsTableFilterComposer,
      $$GroceryListsTableOrderingComposer,
      $$GroceryListsTableAnnotationComposer,
      $$GroceryListsTableCreateCompanionBuilder,
      $$GroceryListsTableUpdateCompanionBuilder,
      (GroceryList, $$GroceryListsTableReferences),
      GroceryList,
      PrefetchHooks Function({bool groceryListItemsRefs})
    >;
typedef $$GroceryListItemsTableCreateCompanionBuilder =
    GroceryListItemsCompanion Function({
      Value<int> id,
      required int listId,
      Value<String?> productId,
      required String market,
      required String marketName,
      required String name,
      Value<String?> brand,
      Value<String?> imageUrl,
      Value<String?> category,
      Value<double?> price,
      Value<int> quantity,
      Value<DateTime> addedAt,
    });
typedef $$GroceryListItemsTableUpdateCompanionBuilder =
    GroceryListItemsCompanion Function({
      Value<int> id,
      Value<int> listId,
      Value<String?> productId,
      Value<String> market,
      Value<String> marketName,
      Value<String> name,
      Value<String?> brand,
      Value<String?> imageUrl,
      Value<String?> category,
      Value<double?> price,
      Value<int> quantity,
      Value<DateTime> addedAt,
    });

final class $$GroceryListItemsTableReferences
    extends
        BaseReferences<
          _$GroceriesDatabase,
          $GroceryListItemsTable,
          GroceryListItem
        > {
  $$GroceryListItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GroceryListsTable _listIdTable(_$GroceriesDatabase db) => db
      .groceryLists
      .createAlias('grocery_list_items__list_id__grocery_lists__id');

  $$GroceryListsTableProcessedTableManager get listId {
    final $_column = $_itemColumn<int>('list_id')!;

    final manager = $$GroceryListsTableTableManager(
      $_db,
      $_db.groceryLists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_listIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GroceryListItemsTableFilterComposer
    extends Composer<_$GroceriesDatabase, $GroceryListItemsTable> {
  $$GroceryListItemsTableFilterComposer({
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

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get market => $composableBuilder(
    column: $table.market,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get marketName => $composableBuilder(
    column: $table.marketName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GroceryListsTableFilterComposer get listId {
    final $$GroceryListsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.groceryLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroceryListsTableFilterComposer(
            $db: $db,
            $table: $db.groceryLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroceryListItemsTableOrderingComposer
    extends Composer<_$GroceriesDatabase, $GroceryListItemsTable> {
  $$GroceryListItemsTableOrderingComposer({
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

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get market => $composableBuilder(
    column: $table.market,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get marketName => $composableBuilder(
    column: $table.marketName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroceryListsTableOrderingComposer get listId {
    final $$GroceryListsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.groceryLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroceryListsTableOrderingComposer(
            $db: $db,
            $table: $db.groceryLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroceryListItemsTableAnnotationComposer
    extends Composer<_$GroceriesDatabase, $GroceryListItemsTable> {
  $$GroceryListItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get market =>
      $composableBuilder(column: $table.market, builder: (column) => column);

  GeneratedColumn<String> get marketName => $composableBuilder(
    column: $table.marketName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$GroceryListsTableAnnotationComposer get listId {
    final $$GroceryListsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.groceryLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroceryListsTableAnnotationComposer(
            $db: $db,
            $table: $db.groceryLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroceryListItemsTableTableManager
    extends
        RootTableManager<
          _$GroceriesDatabase,
          $GroceryListItemsTable,
          GroceryListItem,
          $$GroceryListItemsTableFilterComposer,
          $$GroceryListItemsTableOrderingComposer,
          $$GroceryListItemsTableAnnotationComposer,
          $$GroceryListItemsTableCreateCompanionBuilder,
          $$GroceryListItemsTableUpdateCompanionBuilder,
          (GroceryListItem, $$GroceryListItemsTableReferences),
          GroceryListItem,
          PrefetchHooks Function({bool listId})
        > {
  $$GroceryListItemsTableTableManager(
    _$GroceriesDatabase db,
    $GroceryListItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroceryListItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroceryListItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroceryListItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> listId = const Value.absent(),
                Value<String?> productId = const Value.absent(),
                Value<String> market = const Value.absent(),
                Value<String> marketName = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<double?> price = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => GroceryListItemsCompanion(
                id: id,
                listId: listId,
                productId: productId,
                market: market,
                marketName: marketName,
                name: name,
                brand: brand,
                imageUrl: imageUrl,
                category: category,
                price: price,
                quantity: quantity,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int listId,
                Value<String?> productId = const Value.absent(),
                required String market,
                required String marketName,
                required String name,
                Value<String?> brand = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<double?> price = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => GroceryListItemsCompanion.insert(
                id: id,
                listId: listId,
                productId: productId,
                market: market,
                marketName: marketName,
                name: name,
                brand: brand,
                imageUrl: imageUrl,
                category: category,
                price: price,
                quantity: quantity,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GroceryListItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({listId = false}) {
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
                    if (listId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.listId,
                                referencedTable:
                                    $$GroceryListItemsTableReferences
                                        ._listIdTable(db),
                                referencedColumn:
                                    $$GroceryListItemsTableReferences
                                        ._listIdTable(db)
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

typedef $$GroceryListItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$GroceriesDatabase,
      $GroceryListItemsTable,
      GroceryListItem,
      $$GroceryListItemsTableFilterComposer,
      $$GroceryListItemsTableOrderingComposer,
      $$GroceryListItemsTableAnnotationComposer,
      $$GroceryListItemsTableCreateCompanionBuilder,
      $$GroceryListItemsTableUpdateCompanionBuilder,
      (GroceryListItem, $$GroceryListItemsTableReferences),
      GroceryListItem,
      PrefetchHooks Function({bool listId})
    >;

class $GroceriesDatabaseManager {
  final _$GroceriesDatabase _db;
  $GroceriesDatabaseManager(this._db);
  $$GroceryListsTableTableManager get groceryLists =>
      $$GroceryListsTableTableManager(_db, _db.groceryLists);
  $$GroceryListItemsTableTableManager get groceryListItems =>
      $$GroceryListItemsTableTableManager(_db, _db.groceryListItems);
}
