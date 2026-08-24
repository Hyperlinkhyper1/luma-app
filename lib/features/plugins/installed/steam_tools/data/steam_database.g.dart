// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'steam_database.dart';

// ignore_for_file: type=lint
class $SteamGamesTable extends SteamGames
    with TableInfo<$SteamGamesTable, SteamGame> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SteamGamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _appIdMeta = const VerificationMeta('appId');
  @override
  late final GeneratedColumn<int> appId = GeneratedColumn<int>(
    'app_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _playtimeMinutesMeta = const VerificationMeta(
    'playtimeMinutes',
  );
  @override
  late final GeneratedColumn<int> playtimeMinutes = GeneratedColumn<int>(
    'playtime_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _shortDescriptionMeta = const VerificationMeta(
    'shortDescription',
  );
  @override
  late final GeneratedColumn<String> shortDescription = GeneratedColumn<String>(
    'short_description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headerImageMeta = const VerificationMeta(
    'headerImage',
  );
  @override
  late final GeneratedColumn<String> headerImage = GeneratedColumn<String>(
    'header_image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backgroundImageMeta = const VerificationMeta(
    'backgroundImage',
  );
  @override
  late final GeneratedColumn<String> backgroundImage = GeneratedColumn<String>(
    'background_image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requirementsMeta = const VerificationMeta(
    'requirements',
  );
  @override
  late final GeneratedColumn<String> requirements = GeneratedColumn<String>(
    'requirements',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _developersMeta = const VerificationMeta(
    'developers',
  );
  @override
  late final GeneratedColumn<String> developers = GeneratedColumn<String>(
    'developers',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishersMeta = const VerificationMeta(
    'publishers',
  );
  @override
  late final GeneratedColumn<String> publishers = GeneratedColumn<String>(
    'publishers',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseDateMeta = const VerificationMeta(
    'releaseDate',
  );
  @override
  late final GeneratedColumn<String> releaseDate = GeneratedColumn<String>(
    'release_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metacriticMeta = const VerificationMeta(
    'metacritic',
  );
  @override
  late final GeneratedColumn<int> metacritic = GeneratedColumn<int>(
    'metacritic',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFreeMeta = const VerificationMeta('isFree');
  @override
  late final GeneratedColumn<bool> isFree = GeneratedColumn<bool>(
    'is_free',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_free" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onWindowsMeta = const VerificationMeta(
    'onWindows',
  );
  @override
  late final GeneratedColumn<bool> onWindows = GeneratedColumn<bool>(
    'on_windows',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("on_windows" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _onMacMeta = const VerificationMeta('onMac');
  @override
  late final GeneratedColumn<bool> onMac = GeneratedColumn<bool>(
    'on_mac',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("on_mac" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onLinuxMeta = const VerificationMeta(
    'onLinux',
  );
  @override
  late final GeneratedColumn<bool> onLinux = GeneratedColumn<bool>(
    'on_linux',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("on_linux" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _lastInitialCentsMeta = const VerificationMeta(
    'lastInitialCents',
  );
  @override
  late final GeneratedColumn<int> lastInitialCents = GeneratedColumn<int>(
    'last_initial_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastDiscountPercentMeta =
      const VerificationMeta('lastDiscountPercent');
  @override
  late final GeneratedColumn<int> lastDiscountPercent = GeneratedColumn<int>(
    'last_discount_percent',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailsFetchedAtMeta = const VerificationMeta(
    'detailsFetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> detailsFetchedAt =
      GeneratedColumn<DateTime>(
        'details_fetched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    appId,
    name,
    playtimeMinutes,
    shortDescription,
    headerImage,
    backgroundImage,
    tags,
    requirements,
    developers,
    publishers,
    releaseDate,
    metacritic,
    isFree,
    onWindows,
    onMac,
    onLinux,
    lastPriceCents,
    lastInitialCents,
    lastDiscountPercent,
    currency,
    detailsFetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'steam_games';
  @override
  VerificationContext validateIntegrity(
    Insertable<SteamGame> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('app_id')) {
      context.handle(
        _appIdMeta,
        appId.isAcceptableOrUnknown(data['app_id']!, _appIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('playtime_minutes')) {
      context.handle(
        _playtimeMinutesMeta,
        playtimeMinutes.isAcceptableOrUnknown(
          data['playtime_minutes']!,
          _playtimeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('short_description')) {
      context.handle(
        _shortDescriptionMeta,
        shortDescription.isAcceptableOrUnknown(
          data['short_description']!,
          _shortDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('header_image')) {
      context.handle(
        _headerImageMeta,
        headerImage.isAcceptableOrUnknown(
          data['header_image']!,
          _headerImageMeta,
        ),
      );
    }
    if (data.containsKey('background_image')) {
      context.handle(
        _backgroundImageMeta,
        backgroundImage.isAcceptableOrUnknown(
          data['background_image']!,
          _backgroundImageMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('requirements')) {
      context.handle(
        _requirementsMeta,
        requirements.isAcceptableOrUnknown(
          data['requirements']!,
          _requirementsMeta,
        ),
      );
    }
    if (data.containsKey('developers')) {
      context.handle(
        _developersMeta,
        developers.isAcceptableOrUnknown(data['developers']!, _developersMeta),
      );
    }
    if (data.containsKey('publishers')) {
      context.handle(
        _publishersMeta,
        publishers.isAcceptableOrUnknown(data['publishers']!, _publishersMeta),
      );
    }
    if (data.containsKey('release_date')) {
      context.handle(
        _releaseDateMeta,
        releaseDate.isAcceptableOrUnknown(
          data['release_date']!,
          _releaseDateMeta,
        ),
      );
    }
    if (data.containsKey('metacritic')) {
      context.handle(
        _metacriticMeta,
        metacritic.isAcceptableOrUnknown(data['metacritic']!, _metacriticMeta),
      );
    }
    if (data.containsKey('is_free')) {
      context.handle(
        _isFreeMeta,
        isFree.isAcceptableOrUnknown(data['is_free']!, _isFreeMeta),
      );
    }
    if (data.containsKey('on_windows')) {
      context.handle(
        _onWindowsMeta,
        onWindows.isAcceptableOrUnknown(data['on_windows']!, _onWindowsMeta),
      );
    }
    if (data.containsKey('on_mac')) {
      context.handle(
        _onMacMeta,
        onMac.isAcceptableOrUnknown(data['on_mac']!, _onMacMeta),
      );
    }
    if (data.containsKey('on_linux')) {
      context.handle(
        _onLinuxMeta,
        onLinux.isAcceptableOrUnknown(data['on_linux']!, _onLinuxMeta),
      );
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
    if (data.containsKey('last_initial_cents')) {
      context.handle(
        _lastInitialCentsMeta,
        lastInitialCents.isAcceptableOrUnknown(
          data['last_initial_cents']!,
          _lastInitialCentsMeta,
        ),
      );
    }
    if (data.containsKey('last_discount_percent')) {
      context.handle(
        _lastDiscountPercentMeta,
        lastDiscountPercent.isAcceptableOrUnknown(
          data['last_discount_percent']!,
          _lastDiscountPercentMeta,
        ),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('details_fetched_at')) {
      context.handle(
        _detailsFetchedAtMeta,
        detailsFetchedAt.isAcceptableOrUnknown(
          data['details_fetched_at']!,
          _detailsFetchedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {appId};
  @override
  SteamGame map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SteamGame(
      appId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}app_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      playtimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playtime_minutes'],
      )!,
      shortDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}short_description'],
      ),
      headerImage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}header_image'],
      ),
      backgroundImage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background_image'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      requirements: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}requirements'],
      ),
      developers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}developers'],
      ),
      publishers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publishers'],
      ),
      releaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}release_date'],
      ),
      metacritic: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}metacritic'],
      ),
      isFree: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_free'],
      )!,
      onWindows: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}on_windows'],
      )!,
      onMac: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}on_mac'],
      )!,
      onLinux: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}on_linux'],
      )!,
      lastPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_price_cents'],
      ),
      lastInitialCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_initial_cents'],
      ),
      lastDiscountPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_discount_percent'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      ),
      detailsFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}details_fetched_at'],
      ),
    );
  }

  @override
  $SteamGamesTable createAlias(String alias) {
    return $SteamGamesTable(attachedDatabase, alias);
  }
}

class SteamGame extends DataClass implements Insertable<SteamGame> {
  final int appId;
  final String name;
  final int playtimeMinutes;
  final String? shortDescription;
  final String? headerImage;
  final String? backgroundImage;

  /// Genres and store categories, newline separated.
  final String? tags;

  /// The parsed requirements blocks, as JSON — see `SteamRequirements`.
  final String? requirements;
  final String? developers;
  final String? publishers;
  final String? releaseDate;
  final int? metacritic;
  final bool isFree;
  final bool onWindows;
  final bool onMac;
  final bool onLinux;

  /// The most recent price seen, mirrored here so the library grid can show
  /// a price without reading the history table once per tile.
  final int? lastPriceCents;
  final int? lastInitialCents;
  final int? lastDiscountPercent;
  final String? currency;

  /// When the store page was last read. Null means "never".
  final DateTime? detailsFetchedAt;
  const SteamGame({
    required this.appId,
    required this.name,
    required this.playtimeMinutes,
    this.shortDescription,
    this.headerImage,
    this.backgroundImage,
    this.tags,
    this.requirements,
    this.developers,
    this.publishers,
    this.releaseDate,
    this.metacritic,
    required this.isFree,
    required this.onWindows,
    required this.onMac,
    required this.onLinux,
    this.lastPriceCents,
    this.lastInitialCents,
    this.lastDiscountPercent,
    this.currency,
    this.detailsFetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['app_id'] = Variable<int>(appId);
    map['name'] = Variable<String>(name);
    map['playtime_minutes'] = Variable<int>(playtimeMinutes);
    if (!nullToAbsent || shortDescription != null) {
      map['short_description'] = Variable<String>(shortDescription);
    }
    if (!nullToAbsent || headerImage != null) {
      map['header_image'] = Variable<String>(headerImage);
    }
    if (!nullToAbsent || backgroundImage != null) {
      map['background_image'] = Variable<String>(backgroundImage);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    if (!nullToAbsent || requirements != null) {
      map['requirements'] = Variable<String>(requirements);
    }
    if (!nullToAbsent || developers != null) {
      map['developers'] = Variable<String>(developers);
    }
    if (!nullToAbsent || publishers != null) {
      map['publishers'] = Variable<String>(publishers);
    }
    if (!nullToAbsent || releaseDate != null) {
      map['release_date'] = Variable<String>(releaseDate);
    }
    if (!nullToAbsent || metacritic != null) {
      map['metacritic'] = Variable<int>(metacritic);
    }
    map['is_free'] = Variable<bool>(isFree);
    map['on_windows'] = Variable<bool>(onWindows);
    map['on_mac'] = Variable<bool>(onMac);
    map['on_linux'] = Variable<bool>(onLinux);
    if (!nullToAbsent || lastPriceCents != null) {
      map['last_price_cents'] = Variable<int>(lastPriceCents);
    }
    if (!nullToAbsent || lastInitialCents != null) {
      map['last_initial_cents'] = Variable<int>(lastInitialCents);
    }
    if (!nullToAbsent || lastDiscountPercent != null) {
      map['last_discount_percent'] = Variable<int>(lastDiscountPercent);
    }
    if (!nullToAbsent || currency != null) {
      map['currency'] = Variable<String>(currency);
    }
    if (!nullToAbsent || detailsFetchedAt != null) {
      map['details_fetched_at'] = Variable<DateTime>(detailsFetchedAt);
    }
    return map;
  }

  SteamGamesCompanion toCompanion(bool nullToAbsent) {
    return SteamGamesCompanion(
      appId: Value(appId),
      name: Value(name),
      playtimeMinutes: Value(playtimeMinutes),
      shortDescription: shortDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(shortDescription),
      headerImage: headerImage == null && nullToAbsent
          ? const Value.absent()
          : Value(headerImage),
      backgroundImage: backgroundImage == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundImage),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      requirements: requirements == null && nullToAbsent
          ? const Value.absent()
          : Value(requirements),
      developers: developers == null && nullToAbsent
          ? const Value.absent()
          : Value(developers),
      publishers: publishers == null && nullToAbsent
          ? const Value.absent()
          : Value(publishers),
      releaseDate: releaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseDate),
      metacritic: metacritic == null && nullToAbsent
          ? const Value.absent()
          : Value(metacritic),
      isFree: Value(isFree),
      onWindows: Value(onWindows),
      onMac: Value(onMac),
      onLinux: Value(onLinux),
      lastPriceCents: lastPriceCents == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPriceCents),
      lastInitialCents: lastInitialCents == null && nullToAbsent
          ? const Value.absent()
          : Value(lastInitialCents),
      lastDiscountPercent: lastDiscountPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDiscountPercent),
      currency: currency == null && nullToAbsent
          ? const Value.absent()
          : Value(currency),
      detailsFetchedAt: detailsFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(detailsFetchedAt),
    );
  }

  factory SteamGame.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SteamGame(
      appId: serializer.fromJson<int>(json['appId']),
      name: serializer.fromJson<String>(json['name']),
      playtimeMinutes: serializer.fromJson<int>(json['playtimeMinutes']),
      shortDescription: serializer.fromJson<String?>(json['shortDescription']),
      headerImage: serializer.fromJson<String?>(json['headerImage']),
      backgroundImage: serializer.fromJson<String?>(json['backgroundImage']),
      tags: serializer.fromJson<String?>(json['tags']),
      requirements: serializer.fromJson<String?>(json['requirements']),
      developers: serializer.fromJson<String?>(json['developers']),
      publishers: serializer.fromJson<String?>(json['publishers']),
      releaseDate: serializer.fromJson<String?>(json['releaseDate']),
      metacritic: serializer.fromJson<int?>(json['metacritic']),
      isFree: serializer.fromJson<bool>(json['isFree']),
      onWindows: serializer.fromJson<bool>(json['onWindows']),
      onMac: serializer.fromJson<bool>(json['onMac']),
      onLinux: serializer.fromJson<bool>(json['onLinux']),
      lastPriceCents: serializer.fromJson<int?>(json['lastPriceCents']),
      lastInitialCents: serializer.fromJson<int?>(json['lastInitialCents']),
      lastDiscountPercent: serializer.fromJson<int?>(
        json['lastDiscountPercent'],
      ),
      currency: serializer.fromJson<String?>(json['currency']),
      detailsFetchedAt: serializer.fromJson<DateTime?>(
        json['detailsFetchedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'appId': serializer.toJson<int>(appId),
      'name': serializer.toJson<String>(name),
      'playtimeMinutes': serializer.toJson<int>(playtimeMinutes),
      'shortDescription': serializer.toJson<String?>(shortDescription),
      'headerImage': serializer.toJson<String?>(headerImage),
      'backgroundImage': serializer.toJson<String?>(backgroundImage),
      'tags': serializer.toJson<String?>(tags),
      'requirements': serializer.toJson<String?>(requirements),
      'developers': serializer.toJson<String?>(developers),
      'publishers': serializer.toJson<String?>(publishers),
      'releaseDate': serializer.toJson<String?>(releaseDate),
      'metacritic': serializer.toJson<int?>(metacritic),
      'isFree': serializer.toJson<bool>(isFree),
      'onWindows': serializer.toJson<bool>(onWindows),
      'onMac': serializer.toJson<bool>(onMac),
      'onLinux': serializer.toJson<bool>(onLinux),
      'lastPriceCents': serializer.toJson<int?>(lastPriceCents),
      'lastInitialCents': serializer.toJson<int?>(lastInitialCents),
      'lastDiscountPercent': serializer.toJson<int?>(lastDiscountPercent),
      'currency': serializer.toJson<String?>(currency),
      'detailsFetchedAt': serializer.toJson<DateTime?>(detailsFetchedAt),
    };
  }

  SteamGame copyWith({
    int? appId,
    String? name,
    int? playtimeMinutes,
    Value<String?> shortDescription = const Value.absent(),
    Value<String?> headerImage = const Value.absent(),
    Value<String?> backgroundImage = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    Value<String?> requirements = const Value.absent(),
    Value<String?> developers = const Value.absent(),
    Value<String?> publishers = const Value.absent(),
    Value<String?> releaseDate = const Value.absent(),
    Value<int?> metacritic = const Value.absent(),
    bool? isFree,
    bool? onWindows,
    bool? onMac,
    bool? onLinux,
    Value<int?> lastPriceCents = const Value.absent(),
    Value<int?> lastInitialCents = const Value.absent(),
    Value<int?> lastDiscountPercent = const Value.absent(),
    Value<String?> currency = const Value.absent(),
    Value<DateTime?> detailsFetchedAt = const Value.absent(),
  }) => SteamGame(
    appId: appId ?? this.appId,
    name: name ?? this.name,
    playtimeMinutes: playtimeMinutes ?? this.playtimeMinutes,
    shortDescription: shortDescription.present
        ? shortDescription.value
        : this.shortDescription,
    headerImage: headerImage.present ? headerImage.value : this.headerImage,
    backgroundImage: backgroundImage.present
        ? backgroundImage.value
        : this.backgroundImage,
    tags: tags.present ? tags.value : this.tags,
    requirements: requirements.present ? requirements.value : this.requirements,
    developers: developers.present ? developers.value : this.developers,
    publishers: publishers.present ? publishers.value : this.publishers,
    releaseDate: releaseDate.present ? releaseDate.value : this.releaseDate,
    metacritic: metacritic.present ? metacritic.value : this.metacritic,
    isFree: isFree ?? this.isFree,
    onWindows: onWindows ?? this.onWindows,
    onMac: onMac ?? this.onMac,
    onLinux: onLinux ?? this.onLinux,
    lastPriceCents: lastPriceCents.present
        ? lastPriceCents.value
        : this.lastPriceCents,
    lastInitialCents: lastInitialCents.present
        ? lastInitialCents.value
        : this.lastInitialCents,
    lastDiscountPercent: lastDiscountPercent.present
        ? lastDiscountPercent.value
        : this.lastDiscountPercent,
    currency: currency.present ? currency.value : this.currency,
    detailsFetchedAt: detailsFetchedAt.present
        ? detailsFetchedAt.value
        : this.detailsFetchedAt,
  );
  SteamGame copyWithCompanion(SteamGamesCompanion data) {
    return SteamGame(
      appId: data.appId.present ? data.appId.value : this.appId,
      name: data.name.present ? data.name.value : this.name,
      playtimeMinutes: data.playtimeMinutes.present
          ? data.playtimeMinutes.value
          : this.playtimeMinutes,
      shortDescription: data.shortDescription.present
          ? data.shortDescription.value
          : this.shortDescription,
      headerImage: data.headerImage.present
          ? data.headerImage.value
          : this.headerImage,
      backgroundImage: data.backgroundImage.present
          ? data.backgroundImage.value
          : this.backgroundImage,
      tags: data.tags.present ? data.tags.value : this.tags,
      requirements: data.requirements.present
          ? data.requirements.value
          : this.requirements,
      developers: data.developers.present
          ? data.developers.value
          : this.developers,
      publishers: data.publishers.present
          ? data.publishers.value
          : this.publishers,
      releaseDate: data.releaseDate.present
          ? data.releaseDate.value
          : this.releaseDate,
      metacritic: data.metacritic.present
          ? data.metacritic.value
          : this.metacritic,
      isFree: data.isFree.present ? data.isFree.value : this.isFree,
      onWindows: data.onWindows.present ? data.onWindows.value : this.onWindows,
      onMac: data.onMac.present ? data.onMac.value : this.onMac,
      onLinux: data.onLinux.present ? data.onLinux.value : this.onLinux,
      lastPriceCents: data.lastPriceCents.present
          ? data.lastPriceCents.value
          : this.lastPriceCents,
      lastInitialCents: data.lastInitialCents.present
          ? data.lastInitialCents.value
          : this.lastInitialCents,
      lastDiscountPercent: data.lastDiscountPercent.present
          ? data.lastDiscountPercent.value
          : this.lastDiscountPercent,
      currency: data.currency.present ? data.currency.value : this.currency,
      detailsFetchedAt: data.detailsFetchedAt.present
          ? data.detailsFetchedAt.value
          : this.detailsFetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SteamGame(')
          ..write('appId: $appId, ')
          ..write('name: $name, ')
          ..write('playtimeMinutes: $playtimeMinutes, ')
          ..write('shortDescription: $shortDescription, ')
          ..write('headerImage: $headerImage, ')
          ..write('backgroundImage: $backgroundImage, ')
          ..write('tags: $tags, ')
          ..write('requirements: $requirements, ')
          ..write('developers: $developers, ')
          ..write('publishers: $publishers, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('metacritic: $metacritic, ')
          ..write('isFree: $isFree, ')
          ..write('onWindows: $onWindows, ')
          ..write('onMac: $onMac, ')
          ..write('onLinux: $onLinux, ')
          ..write('lastPriceCents: $lastPriceCents, ')
          ..write('lastInitialCents: $lastInitialCents, ')
          ..write('lastDiscountPercent: $lastDiscountPercent, ')
          ..write('currency: $currency, ')
          ..write('detailsFetchedAt: $detailsFetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    appId,
    name,
    playtimeMinutes,
    shortDescription,
    headerImage,
    backgroundImage,
    tags,
    requirements,
    developers,
    publishers,
    releaseDate,
    metacritic,
    isFree,
    onWindows,
    onMac,
    onLinux,
    lastPriceCents,
    lastInitialCents,
    lastDiscountPercent,
    currency,
    detailsFetchedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SteamGame &&
          other.appId == this.appId &&
          other.name == this.name &&
          other.playtimeMinutes == this.playtimeMinutes &&
          other.shortDescription == this.shortDescription &&
          other.headerImage == this.headerImage &&
          other.backgroundImage == this.backgroundImage &&
          other.tags == this.tags &&
          other.requirements == this.requirements &&
          other.developers == this.developers &&
          other.publishers == this.publishers &&
          other.releaseDate == this.releaseDate &&
          other.metacritic == this.metacritic &&
          other.isFree == this.isFree &&
          other.onWindows == this.onWindows &&
          other.onMac == this.onMac &&
          other.onLinux == this.onLinux &&
          other.lastPriceCents == this.lastPriceCents &&
          other.lastInitialCents == this.lastInitialCents &&
          other.lastDiscountPercent == this.lastDiscountPercent &&
          other.currency == this.currency &&
          other.detailsFetchedAt == this.detailsFetchedAt);
}

class SteamGamesCompanion extends UpdateCompanion<SteamGame> {
  final Value<int> appId;
  final Value<String> name;
  final Value<int> playtimeMinutes;
  final Value<String?> shortDescription;
  final Value<String?> headerImage;
  final Value<String?> backgroundImage;
  final Value<String?> tags;
  final Value<String?> requirements;
  final Value<String?> developers;
  final Value<String?> publishers;
  final Value<String?> releaseDate;
  final Value<int?> metacritic;
  final Value<bool> isFree;
  final Value<bool> onWindows;
  final Value<bool> onMac;
  final Value<bool> onLinux;
  final Value<int?> lastPriceCents;
  final Value<int?> lastInitialCents;
  final Value<int?> lastDiscountPercent;
  final Value<String?> currency;
  final Value<DateTime?> detailsFetchedAt;
  const SteamGamesCompanion({
    this.appId = const Value.absent(),
    this.name = const Value.absent(),
    this.playtimeMinutes = const Value.absent(),
    this.shortDescription = const Value.absent(),
    this.headerImage = const Value.absent(),
    this.backgroundImage = const Value.absent(),
    this.tags = const Value.absent(),
    this.requirements = const Value.absent(),
    this.developers = const Value.absent(),
    this.publishers = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.metacritic = const Value.absent(),
    this.isFree = const Value.absent(),
    this.onWindows = const Value.absent(),
    this.onMac = const Value.absent(),
    this.onLinux = const Value.absent(),
    this.lastPriceCents = const Value.absent(),
    this.lastInitialCents = const Value.absent(),
    this.lastDiscountPercent = const Value.absent(),
    this.currency = const Value.absent(),
    this.detailsFetchedAt = const Value.absent(),
  });
  SteamGamesCompanion.insert({
    this.appId = const Value.absent(),
    required String name,
    this.playtimeMinutes = const Value.absent(),
    this.shortDescription = const Value.absent(),
    this.headerImage = const Value.absent(),
    this.backgroundImage = const Value.absent(),
    this.tags = const Value.absent(),
    this.requirements = const Value.absent(),
    this.developers = const Value.absent(),
    this.publishers = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.metacritic = const Value.absent(),
    this.isFree = const Value.absent(),
    this.onWindows = const Value.absent(),
    this.onMac = const Value.absent(),
    this.onLinux = const Value.absent(),
    this.lastPriceCents = const Value.absent(),
    this.lastInitialCents = const Value.absent(),
    this.lastDiscountPercent = const Value.absent(),
    this.currency = const Value.absent(),
    this.detailsFetchedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<SteamGame> custom({
    Expression<int>? appId,
    Expression<String>? name,
    Expression<int>? playtimeMinutes,
    Expression<String>? shortDescription,
    Expression<String>? headerImage,
    Expression<String>? backgroundImage,
    Expression<String>? tags,
    Expression<String>? requirements,
    Expression<String>? developers,
    Expression<String>? publishers,
    Expression<String>? releaseDate,
    Expression<int>? metacritic,
    Expression<bool>? isFree,
    Expression<bool>? onWindows,
    Expression<bool>? onMac,
    Expression<bool>? onLinux,
    Expression<int>? lastPriceCents,
    Expression<int>? lastInitialCents,
    Expression<int>? lastDiscountPercent,
    Expression<String>? currency,
    Expression<DateTime>? detailsFetchedAt,
  }) {
    return RawValuesInsertable({
      if (appId != null) 'app_id': appId,
      if (name != null) 'name': name,
      if (playtimeMinutes != null) 'playtime_minutes': playtimeMinutes,
      if (shortDescription != null) 'short_description': shortDescription,
      if (headerImage != null) 'header_image': headerImage,
      if (backgroundImage != null) 'background_image': backgroundImage,
      if (tags != null) 'tags': tags,
      if (requirements != null) 'requirements': requirements,
      if (developers != null) 'developers': developers,
      if (publishers != null) 'publishers': publishers,
      if (releaseDate != null) 'release_date': releaseDate,
      if (metacritic != null) 'metacritic': metacritic,
      if (isFree != null) 'is_free': isFree,
      if (onWindows != null) 'on_windows': onWindows,
      if (onMac != null) 'on_mac': onMac,
      if (onLinux != null) 'on_linux': onLinux,
      if (lastPriceCents != null) 'last_price_cents': lastPriceCents,
      if (lastInitialCents != null) 'last_initial_cents': lastInitialCents,
      if (lastDiscountPercent != null)
        'last_discount_percent': lastDiscountPercent,
      if (currency != null) 'currency': currency,
      if (detailsFetchedAt != null) 'details_fetched_at': detailsFetchedAt,
    });
  }

  SteamGamesCompanion copyWith({
    Value<int>? appId,
    Value<String>? name,
    Value<int>? playtimeMinutes,
    Value<String?>? shortDescription,
    Value<String?>? headerImage,
    Value<String?>? backgroundImage,
    Value<String?>? tags,
    Value<String?>? requirements,
    Value<String?>? developers,
    Value<String?>? publishers,
    Value<String?>? releaseDate,
    Value<int?>? metacritic,
    Value<bool>? isFree,
    Value<bool>? onWindows,
    Value<bool>? onMac,
    Value<bool>? onLinux,
    Value<int?>? lastPriceCents,
    Value<int?>? lastInitialCents,
    Value<int?>? lastDiscountPercent,
    Value<String?>? currency,
    Value<DateTime?>? detailsFetchedAt,
  }) {
    return SteamGamesCompanion(
      appId: appId ?? this.appId,
      name: name ?? this.name,
      playtimeMinutes: playtimeMinutes ?? this.playtimeMinutes,
      shortDescription: shortDescription ?? this.shortDescription,
      headerImage: headerImage ?? this.headerImage,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      tags: tags ?? this.tags,
      requirements: requirements ?? this.requirements,
      developers: developers ?? this.developers,
      publishers: publishers ?? this.publishers,
      releaseDate: releaseDate ?? this.releaseDate,
      metacritic: metacritic ?? this.metacritic,
      isFree: isFree ?? this.isFree,
      onWindows: onWindows ?? this.onWindows,
      onMac: onMac ?? this.onMac,
      onLinux: onLinux ?? this.onLinux,
      lastPriceCents: lastPriceCents ?? this.lastPriceCents,
      lastInitialCents: lastInitialCents ?? this.lastInitialCents,
      lastDiscountPercent: lastDiscountPercent ?? this.lastDiscountPercent,
      currency: currency ?? this.currency,
      detailsFetchedAt: detailsFetchedAt ?? this.detailsFetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (appId.present) {
      map['app_id'] = Variable<int>(appId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (playtimeMinutes.present) {
      map['playtime_minutes'] = Variable<int>(playtimeMinutes.value);
    }
    if (shortDescription.present) {
      map['short_description'] = Variable<String>(shortDescription.value);
    }
    if (headerImage.present) {
      map['header_image'] = Variable<String>(headerImage.value);
    }
    if (backgroundImage.present) {
      map['background_image'] = Variable<String>(backgroundImage.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (requirements.present) {
      map['requirements'] = Variable<String>(requirements.value);
    }
    if (developers.present) {
      map['developers'] = Variable<String>(developers.value);
    }
    if (publishers.present) {
      map['publishers'] = Variable<String>(publishers.value);
    }
    if (releaseDate.present) {
      map['release_date'] = Variable<String>(releaseDate.value);
    }
    if (metacritic.present) {
      map['metacritic'] = Variable<int>(metacritic.value);
    }
    if (isFree.present) {
      map['is_free'] = Variable<bool>(isFree.value);
    }
    if (onWindows.present) {
      map['on_windows'] = Variable<bool>(onWindows.value);
    }
    if (onMac.present) {
      map['on_mac'] = Variable<bool>(onMac.value);
    }
    if (onLinux.present) {
      map['on_linux'] = Variable<bool>(onLinux.value);
    }
    if (lastPriceCents.present) {
      map['last_price_cents'] = Variable<int>(lastPriceCents.value);
    }
    if (lastInitialCents.present) {
      map['last_initial_cents'] = Variable<int>(lastInitialCents.value);
    }
    if (lastDiscountPercent.present) {
      map['last_discount_percent'] = Variable<int>(lastDiscountPercent.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (detailsFetchedAt.present) {
      map['details_fetched_at'] = Variable<DateTime>(detailsFetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SteamGamesCompanion(')
          ..write('appId: $appId, ')
          ..write('name: $name, ')
          ..write('playtimeMinutes: $playtimeMinutes, ')
          ..write('shortDescription: $shortDescription, ')
          ..write('headerImage: $headerImage, ')
          ..write('backgroundImage: $backgroundImage, ')
          ..write('tags: $tags, ')
          ..write('requirements: $requirements, ')
          ..write('developers: $developers, ')
          ..write('publishers: $publishers, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('metacritic: $metacritic, ')
          ..write('isFree: $isFree, ')
          ..write('onWindows: $onWindows, ')
          ..write('onMac: $onMac, ')
          ..write('onLinux: $onLinux, ')
          ..write('lastPriceCents: $lastPriceCents, ')
          ..write('lastInitialCents: $lastInitialCents, ')
          ..write('lastDiscountPercent: $lastDiscountPercent, ')
          ..write('currency: $currency, ')
          ..write('detailsFetchedAt: $detailsFetchedAt')
          ..write(')'))
        .toString();
  }
}

class $SteamPricePointsTable extends SteamPricePoints
    with TableInfo<$SteamPricePointsTable, SteamPricePoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SteamPricePointsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _appIdMeta = const VerificationMeta('appId');
  @override
  late final GeneratedColumn<int> appId = GeneratedColumn<int>(
    'app_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _observedAtMeta = const VerificationMeta(
    'observedAt',
  );
  @override
  late final GeneratedColumn<DateTime> observedAt = GeneratedColumn<DateTime>(
    'observed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finalCentsMeta = const VerificationMeta(
    'finalCents',
  );
  @override
  late final GeneratedColumn<int> finalCents = GeneratedColumn<int>(
    'final_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _initialCentsMeta = const VerificationMeta(
    'initialCents',
  );
  @override
  late final GeneratedColumn<int> initialCents = GeneratedColumn<int>(
    'initial_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _discountPercentMeta = const VerificationMeta(
    'discountPercent',
  );
  @override
  late final GeneratedColumn<int> discountPercent = GeneratedColumn<int>(
    'discount_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    appId,
    observedAt,
    finalCents,
    initialCents,
    discountPercent,
    currency,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'steam_price_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<SteamPricePoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('app_id')) {
      context.handle(
        _appIdMeta,
        appId.isAcceptableOrUnknown(data['app_id']!, _appIdMeta),
      );
    } else if (isInserting) {
      context.missing(_appIdMeta);
    }
    if (data.containsKey('observed_at')) {
      context.handle(
        _observedAtMeta,
        observedAt.isAcceptableOrUnknown(data['observed_at']!, _observedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_observedAtMeta);
    }
    if (data.containsKey('final_cents')) {
      context.handle(
        _finalCentsMeta,
        finalCents.isAcceptableOrUnknown(data['final_cents']!, _finalCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_finalCentsMeta);
    }
    if (data.containsKey('initial_cents')) {
      context.handle(
        _initialCentsMeta,
        initialCents.isAcceptableOrUnknown(
          data['initial_cents']!,
          _initialCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_initialCentsMeta);
    }
    if (data.containsKey('discount_percent')) {
      context.handle(
        _discountPercentMeta,
        discountPercent.isAcceptableOrUnknown(
          data['discount_percent']!,
          _discountPercentMeta,
        ),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SteamPricePoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SteamPricePoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      appId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}app_id'],
      )!,
      observedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}observed_at'],
      )!,
      finalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}final_cents'],
      )!,
      initialCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}initial_cents'],
      )!,
      discountPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount_percent'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
    );
  }

  @override
  $SteamPricePointsTable createAlias(String alias) {
    return $SteamPricePointsTable(attachedDatabase, alias);
  }
}

class SteamPricePoint extends DataClass implements Insertable<SteamPricePoint> {
  final int id;
  final int appId;
  final DateTime observedAt;
  final int finalCents;
  final int initialCents;
  final int discountPercent;
  final String currency;
  const SteamPricePoint({
    required this.id,
    required this.appId,
    required this.observedAt,
    required this.finalCents,
    required this.initialCents,
    required this.discountPercent,
    required this.currency,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['app_id'] = Variable<int>(appId);
    map['observed_at'] = Variable<DateTime>(observedAt);
    map['final_cents'] = Variable<int>(finalCents);
    map['initial_cents'] = Variable<int>(initialCents);
    map['discount_percent'] = Variable<int>(discountPercent);
    map['currency'] = Variable<String>(currency);
    return map;
  }

  SteamPricePointsCompanion toCompanion(bool nullToAbsent) {
    return SteamPricePointsCompanion(
      id: Value(id),
      appId: Value(appId),
      observedAt: Value(observedAt),
      finalCents: Value(finalCents),
      initialCents: Value(initialCents),
      discountPercent: Value(discountPercent),
      currency: Value(currency),
    );
  }

  factory SteamPricePoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SteamPricePoint(
      id: serializer.fromJson<int>(json['id']),
      appId: serializer.fromJson<int>(json['appId']),
      observedAt: serializer.fromJson<DateTime>(json['observedAt']),
      finalCents: serializer.fromJson<int>(json['finalCents']),
      initialCents: serializer.fromJson<int>(json['initialCents']),
      discountPercent: serializer.fromJson<int>(json['discountPercent']),
      currency: serializer.fromJson<String>(json['currency']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'appId': serializer.toJson<int>(appId),
      'observedAt': serializer.toJson<DateTime>(observedAt),
      'finalCents': serializer.toJson<int>(finalCents),
      'initialCents': serializer.toJson<int>(initialCents),
      'discountPercent': serializer.toJson<int>(discountPercent),
      'currency': serializer.toJson<String>(currency),
    };
  }

  SteamPricePoint copyWith({
    int? id,
    int? appId,
    DateTime? observedAt,
    int? finalCents,
    int? initialCents,
    int? discountPercent,
    String? currency,
  }) => SteamPricePoint(
    id: id ?? this.id,
    appId: appId ?? this.appId,
    observedAt: observedAt ?? this.observedAt,
    finalCents: finalCents ?? this.finalCents,
    initialCents: initialCents ?? this.initialCents,
    discountPercent: discountPercent ?? this.discountPercent,
    currency: currency ?? this.currency,
  );
  SteamPricePoint copyWithCompanion(SteamPricePointsCompanion data) {
    return SteamPricePoint(
      id: data.id.present ? data.id.value : this.id,
      appId: data.appId.present ? data.appId.value : this.appId,
      observedAt: data.observedAt.present
          ? data.observedAt.value
          : this.observedAt,
      finalCents: data.finalCents.present
          ? data.finalCents.value
          : this.finalCents,
      initialCents: data.initialCents.present
          ? data.initialCents.value
          : this.initialCents,
      discountPercent: data.discountPercent.present
          ? data.discountPercent.value
          : this.discountPercent,
      currency: data.currency.present ? data.currency.value : this.currency,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SteamPricePoint(')
          ..write('id: $id, ')
          ..write('appId: $appId, ')
          ..write('observedAt: $observedAt, ')
          ..write('finalCents: $finalCents, ')
          ..write('initialCents: $initialCents, ')
          ..write('discountPercent: $discountPercent, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    appId,
    observedAt,
    finalCents,
    initialCents,
    discountPercent,
    currency,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SteamPricePoint &&
          other.id == this.id &&
          other.appId == this.appId &&
          other.observedAt == this.observedAt &&
          other.finalCents == this.finalCents &&
          other.initialCents == this.initialCents &&
          other.discountPercent == this.discountPercent &&
          other.currency == this.currency);
}

class SteamPricePointsCompanion extends UpdateCompanion<SteamPricePoint> {
  final Value<int> id;
  final Value<int> appId;
  final Value<DateTime> observedAt;
  final Value<int> finalCents;
  final Value<int> initialCents;
  final Value<int> discountPercent;
  final Value<String> currency;
  const SteamPricePointsCompanion({
    this.id = const Value.absent(),
    this.appId = const Value.absent(),
    this.observedAt = const Value.absent(),
    this.finalCents = const Value.absent(),
    this.initialCents = const Value.absent(),
    this.discountPercent = const Value.absent(),
    this.currency = const Value.absent(),
  });
  SteamPricePointsCompanion.insert({
    this.id = const Value.absent(),
    required int appId,
    required DateTime observedAt,
    required int finalCents,
    required int initialCents,
    this.discountPercent = const Value.absent(),
    required String currency,
  }) : appId = Value(appId),
       observedAt = Value(observedAt),
       finalCents = Value(finalCents),
       initialCents = Value(initialCents),
       currency = Value(currency);
  static Insertable<SteamPricePoint> custom({
    Expression<int>? id,
    Expression<int>? appId,
    Expression<DateTime>? observedAt,
    Expression<int>? finalCents,
    Expression<int>? initialCents,
    Expression<int>? discountPercent,
    Expression<String>? currency,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (appId != null) 'app_id': appId,
      if (observedAt != null) 'observed_at': observedAt,
      if (finalCents != null) 'final_cents': finalCents,
      if (initialCents != null) 'initial_cents': initialCents,
      if (discountPercent != null) 'discount_percent': discountPercent,
      if (currency != null) 'currency': currency,
    });
  }

  SteamPricePointsCompanion copyWith({
    Value<int>? id,
    Value<int>? appId,
    Value<DateTime>? observedAt,
    Value<int>? finalCents,
    Value<int>? initialCents,
    Value<int>? discountPercent,
    Value<String>? currency,
  }) {
    return SteamPricePointsCompanion(
      id: id ?? this.id,
      appId: appId ?? this.appId,
      observedAt: observedAt ?? this.observedAt,
      finalCents: finalCents ?? this.finalCents,
      initialCents: initialCents ?? this.initialCents,
      discountPercent: discountPercent ?? this.discountPercent,
      currency: currency ?? this.currency,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (appId.present) {
      map['app_id'] = Variable<int>(appId.value);
    }
    if (observedAt.present) {
      map['observed_at'] = Variable<DateTime>(observedAt.value);
    }
    if (finalCents.present) {
      map['final_cents'] = Variable<int>(finalCents.value);
    }
    if (initialCents.present) {
      map['initial_cents'] = Variable<int>(initialCents.value);
    }
    if (discountPercent.present) {
      map['discount_percent'] = Variable<int>(discountPercent.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SteamPricePointsCompanion(')
          ..write('id: $id, ')
          ..write('appId: $appId, ')
          ..write('observedAt: $observedAt, ')
          ..write('finalCents: $finalCents, ')
          ..write('initialCents: $initialCents, ')
          ..write('discountPercent: $discountPercent, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }
}

abstract class _$SteamDatabase extends GeneratedDatabase {
  _$SteamDatabase(QueryExecutor e) : super(e);
  $SteamDatabaseManager get managers => $SteamDatabaseManager(this);
  late final $SteamGamesTable steamGames = $SteamGamesTable(this);
  late final $SteamPricePointsTable steamPricePoints = $SteamPricePointsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    steamGames,
    steamPricePoints,
  ];
}

typedef $$SteamGamesTableCreateCompanionBuilder =
    SteamGamesCompanion Function({
      Value<int> appId,
      required String name,
      Value<int> playtimeMinutes,
      Value<String?> shortDescription,
      Value<String?> headerImage,
      Value<String?> backgroundImage,
      Value<String?> tags,
      Value<String?> requirements,
      Value<String?> developers,
      Value<String?> publishers,
      Value<String?> releaseDate,
      Value<int?> metacritic,
      Value<bool> isFree,
      Value<bool> onWindows,
      Value<bool> onMac,
      Value<bool> onLinux,
      Value<int?> lastPriceCents,
      Value<int?> lastInitialCents,
      Value<int?> lastDiscountPercent,
      Value<String?> currency,
      Value<DateTime?> detailsFetchedAt,
    });
typedef $$SteamGamesTableUpdateCompanionBuilder =
    SteamGamesCompanion Function({
      Value<int> appId,
      Value<String> name,
      Value<int> playtimeMinutes,
      Value<String?> shortDescription,
      Value<String?> headerImage,
      Value<String?> backgroundImage,
      Value<String?> tags,
      Value<String?> requirements,
      Value<String?> developers,
      Value<String?> publishers,
      Value<String?> releaseDate,
      Value<int?> metacritic,
      Value<bool> isFree,
      Value<bool> onWindows,
      Value<bool> onMac,
      Value<bool> onLinux,
      Value<int?> lastPriceCents,
      Value<int?> lastInitialCents,
      Value<int?> lastDiscountPercent,
      Value<String?> currency,
      Value<DateTime?> detailsFetchedAt,
    });

class $$SteamGamesTableFilterComposer
    extends Composer<_$SteamDatabase, $SteamGamesTable> {
  $$SteamGamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playtimeMinutes => $composableBuilder(
    column: $table.playtimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shortDescription => $composableBuilder(
    column: $table.shortDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headerImage => $composableBuilder(
    column: $table.headerImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backgroundImage => $composableBuilder(
    column: $table.backgroundImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requirements => $composableBuilder(
    column: $table.requirements,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get developers => $composableBuilder(
    column: $table.developers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publishers => $composableBuilder(
    column: $table.publishers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get metacritic => $composableBuilder(
    column: $table.metacritic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFree => $composableBuilder(
    column: $table.isFree,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onWindows => $composableBuilder(
    column: $table.onWindows,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onMac => $composableBuilder(
    column: $table.onMac,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onLinux => $composableBuilder(
    column: $table.onLinux,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPriceCents => $composableBuilder(
    column: $table.lastPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastInitialCents => $composableBuilder(
    column: $table.lastInitialCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastDiscountPercent => $composableBuilder(
    column: $table.lastDiscountPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get detailsFetchedAt => $composableBuilder(
    column: $table.detailsFetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SteamGamesTableOrderingComposer
    extends Composer<_$SteamDatabase, $SteamGamesTable> {
  $$SteamGamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playtimeMinutes => $composableBuilder(
    column: $table.playtimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shortDescription => $composableBuilder(
    column: $table.shortDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headerImage => $composableBuilder(
    column: $table.headerImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backgroundImage => $composableBuilder(
    column: $table.backgroundImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requirements => $composableBuilder(
    column: $table.requirements,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get developers => $composableBuilder(
    column: $table.developers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publishers => $composableBuilder(
    column: $table.publishers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get metacritic => $composableBuilder(
    column: $table.metacritic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFree => $composableBuilder(
    column: $table.isFree,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onWindows => $composableBuilder(
    column: $table.onWindows,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onMac => $composableBuilder(
    column: $table.onMac,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onLinux => $composableBuilder(
    column: $table.onLinux,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPriceCents => $composableBuilder(
    column: $table.lastPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastInitialCents => $composableBuilder(
    column: $table.lastInitialCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastDiscountPercent => $composableBuilder(
    column: $table.lastDiscountPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get detailsFetchedAt => $composableBuilder(
    column: $table.detailsFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SteamGamesTableAnnotationComposer
    extends Composer<_$SteamDatabase, $SteamGamesTable> {
  $$SteamGamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get appId =>
      $composableBuilder(column: $table.appId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get playtimeMinutes => $composableBuilder(
    column: $table.playtimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shortDescription => $composableBuilder(
    column: $table.shortDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get headerImage => $composableBuilder(
    column: $table.headerImage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backgroundImage => $composableBuilder(
    column: $table.backgroundImage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get requirements => $composableBuilder(
    column: $table.requirements,
    builder: (column) => column,
  );

  GeneratedColumn<String> get developers => $composableBuilder(
    column: $table.developers,
    builder: (column) => column,
  );

  GeneratedColumn<String> get publishers => $composableBuilder(
    column: $table.publishers,
    builder: (column) => column,
  );

  GeneratedColumn<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get metacritic => $composableBuilder(
    column: $table.metacritic,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFree =>
      $composableBuilder(column: $table.isFree, builder: (column) => column);

  GeneratedColumn<bool> get onWindows =>
      $composableBuilder(column: $table.onWindows, builder: (column) => column);

  GeneratedColumn<bool> get onMac =>
      $composableBuilder(column: $table.onMac, builder: (column) => column);

  GeneratedColumn<bool> get onLinux =>
      $composableBuilder(column: $table.onLinux, builder: (column) => column);

  GeneratedColumn<int> get lastPriceCents => $composableBuilder(
    column: $table.lastPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastInitialCents => $composableBuilder(
    column: $table.lastInitialCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastDiscountPercent => $composableBuilder(
    column: $table.lastDiscountPercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get detailsFetchedAt => $composableBuilder(
    column: $table.detailsFetchedAt,
    builder: (column) => column,
  );
}

class $$SteamGamesTableTableManager
    extends
        RootTableManager<
          _$SteamDatabase,
          $SteamGamesTable,
          SteamGame,
          $$SteamGamesTableFilterComposer,
          $$SteamGamesTableOrderingComposer,
          $$SteamGamesTableAnnotationComposer,
          $$SteamGamesTableCreateCompanionBuilder,
          $$SteamGamesTableUpdateCompanionBuilder,
          (
            SteamGame,
            BaseReferences<_$SteamDatabase, $SteamGamesTable, SteamGame>,
          ),
          SteamGame,
          PrefetchHooks Function()
        > {
  $$SteamGamesTableTableManager(_$SteamDatabase db, $SteamGamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SteamGamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SteamGamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SteamGamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> appId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> playtimeMinutes = const Value.absent(),
                Value<String?> shortDescription = const Value.absent(),
                Value<String?> headerImage = const Value.absent(),
                Value<String?> backgroundImage = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> requirements = const Value.absent(),
                Value<String?> developers = const Value.absent(),
                Value<String?> publishers = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<int?> metacritic = const Value.absent(),
                Value<bool> isFree = const Value.absent(),
                Value<bool> onWindows = const Value.absent(),
                Value<bool> onMac = const Value.absent(),
                Value<bool> onLinux = const Value.absent(),
                Value<int?> lastPriceCents = const Value.absent(),
                Value<int?> lastInitialCents = const Value.absent(),
                Value<int?> lastDiscountPercent = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<DateTime?> detailsFetchedAt = const Value.absent(),
              }) => SteamGamesCompanion(
                appId: appId,
                name: name,
                playtimeMinutes: playtimeMinutes,
                shortDescription: shortDescription,
                headerImage: headerImage,
                backgroundImage: backgroundImage,
                tags: tags,
                requirements: requirements,
                developers: developers,
                publishers: publishers,
                releaseDate: releaseDate,
                metacritic: metacritic,
                isFree: isFree,
                onWindows: onWindows,
                onMac: onMac,
                onLinux: onLinux,
                lastPriceCents: lastPriceCents,
                lastInitialCents: lastInitialCents,
                lastDiscountPercent: lastDiscountPercent,
                currency: currency,
                detailsFetchedAt: detailsFetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> appId = const Value.absent(),
                required String name,
                Value<int> playtimeMinutes = const Value.absent(),
                Value<String?> shortDescription = const Value.absent(),
                Value<String?> headerImage = const Value.absent(),
                Value<String?> backgroundImage = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> requirements = const Value.absent(),
                Value<String?> developers = const Value.absent(),
                Value<String?> publishers = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<int?> metacritic = const Value.absent(),
                Value<bool> isFree = const Value.absent(),
                Value<bool> onWindows = const Value.absent(),
                Value<bool> onMac = const Value.absent(),
                Value<bool> onLinux = const Value.absent(),
                Value<int?> lastPriceCents = const Value.absent(),
                Value<int?> lastInitialCents = const Value.absent(),
                Value<int?> lastDiscountPercent = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<DateTime?> detailsFetchedAt = const Value.absent(),
              }) => SteamGamesCompanion.insert(
                appId: appId,
                name: name,
                playtimeMinutes: playtimeMinutes,
                shortDescription: shortDescription,
                headerImage: headerImage,
                backgroundImage: backgroundImage,
                tags: tags,
                requirements: requirements,
                developers: developers,
                publishers: publishers,
                releaseDate: releaseDate,
                metacritic: metacritic,
                isFree: isFree,
                onWindows: onWindows,
                onMac: onMac,
                onLinux: onLinux,
                lastPriceCents: lastPriceCents,
                lastInitialCents: lastInitialCents,
                lastDiscountPercent: lastDiscountPercent,
                currency: currency,
                detailsFetchedAt: detailsFetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SteamGamesTableProcessedTableManager =
    ProcessedTableManager<
      _$SteamDatabase,
      $SteamGamesTable,
      SteamGame,
      $$SteamGamesTableFilterComposer,
      $$SteamGamesTableOrderingComposer,
      $$SteamGamesTableAnnotationComposer,
      $$SteamGamesTableCreateCompanionBuilder,
      $$SteamGamesTableUpdateCompanionBuilder,
      (SteamGame, BaseReferences<_$SteamDatabase, $SteamGamesTable, SteamGame>),
      SteamGame,
      PrefetchHooks Function()
    >;
typedef $$SteamPricePointsTableCreateCompanionBuilder =
    SteamPricePointsCompanion Function({
      Value<int> id,
      required int appId,
      required DateTime observedAt,
      required int finalCents,
      required int initialCents,
      Value<int> discountPercent,
      required String currency,
    });
typedef $$SteamPricePointsTableUpdateCompanionBuilder =
    SteamPricePointsCompanion Function({
      Value<int> id,
      Value<int> appId,
      Value<DateTime> observedAt,
      Value<int> finalCents,
      Value<int> initialCents,
      Value<int> discountPercent,
      Value<String> currency,
    });

class $$SteamPricePointsTableFilterComposer
    extends Composer<_$SteamDatabase, $SteamPricePointsTable> {
  $$SteamPricePointsTableFilterComposer({
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

  ColumnFilters<int> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finalCents => $composableBuilder(
    column: $table.finalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get initialCents => $composableBuilder(
    column: $table.initialCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discountPercent => $composableBuilder(
    column: $table.discountPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SteamPricePointsTableOrderingComposer
    extends Composer<_$SteamDatabase, $SteamPricePointsTable> {
  $$SteamPricePointsTableOrderingComposer({
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

  ColumnOrderings<int> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finalCents => $composableBuilder(
    column: $table.finalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get initialCents => $composableBuilder(
    column: $table.initialCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discountPercent => $composableBuilder(
    column: $table.discountPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SteamPricePointsTableAnnotationComposer
    extends Composer<_$SteamDatabase, $SteamPricePointsTable> {
  $$SteamPricePointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get appId =>
      $composableBuilder(column: $table.appId, builder: (column) => column);

  GeneratedColumn<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get finalCents => $composableBuilder(
    column: $table.finalCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get initialCents => $composableBuilder(
    column: $table.initialCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discountPercent => $composableBuilder(
    column: $table.discountPercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);
}

class $$SteamPricePointsTableTableManager
    extends
        RootTableManager<
          _$SteamDatabase,
          $SteamPricePointsTable,
          SteamPricePoint,
          $$SteamPricePointsTableFilterComposer,
          $$SteamPricePointsTableOrderingComposer,
          $$SteamPricePointsTableAnnotationComposer,
          $$SteamPricePointsTableCreateCompanionBuilder,
          $$SteamPricePointsTableUpdateCompanionBuilder,
          (
            SteamPricePoint,
            BaseReferences<
              _$SteamDatabase,
              $SteamPricePointsTable,
              SteamPricePoint
            >,
          ),
          SteamPricePoint,
          PrefetchHooks Function()
        > {
  $$SteamPricePointsTableTableManager(
    _$SteamDatabase db,
    $SteamPricePointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SteamPricePointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SteamPricePointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SteamPricePointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> appId = const Value.absent(),
                Value<DateTime> observedAt = const Value.absent(),
                Value<int> finalCents = const Value.absent(),
                Value<int> initialCents = const Value.absent(),
                Value<int> discountPercent = const Value.absent(),
                Value<String> currency = const Value.absent(),
              }) => SteamPricePointsCompanion(
                id: id,
                appId: appId,
                observedAt: observedAt,
                finalCents: finalCents,
                initialCents: initialCents,
                discountPercent: discountPercent,
                currency: currency,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int appId,
                required DateTime observedAt,
                required int finalCents,
                required int initialCents,
                Value<int> discountPercent = const Value.absent(),
                required String currency,
              }) => SteamPricePointsCompanion.insert(
                id: id,
                appId: appId,
                observedAt: observedAt,
                finalCents: finalCents,
                initialCents: initialCents,
                discountPercent: discountPercent,
                currency: currency,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SteamPricePointsTableProcessedTableManager =
    ProcessedTableManager<
      _$SteamDatabase,
      $SteamPricePointsTable,
      SteamPricePoint,
      $$SteamPricePointsTableFilterComposer,
      $$SteamPricePointsTableOrderingComposer,
      $$SteamPricePointsTableAnnotationComposer,
      $$SteamPricePointsTableCreateCompanionBuilder,
      $$SteamPricePointsTableUpdateCompanionBuilder,
      (
        SteamPricePoint,
        BaseReferences<
          _$SteamDatabase,
          $SteamPricePointsTable,
          SteamPricePoint
        >,
      ),
      SteamPricePoint,
      PrefetchHooks Function()
    >;

class $SteamDatabaseManager {
  final _$SteamDatabase _db;
  $SteamDatabaseManager(this._db);
  $$SteamGamesTableTableManager get steamGames =>
      $$SteamGamesTableTableManager(_db, _db.steamGames);
  $$SteamPricePointsTableTableManager get steamPricePoints =>
      $$SteamPricePointsTableTableManager(_db, _db.steamPricePoints);
}
