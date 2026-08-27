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
  static const VerificationMeta _ownedMeta = const VerificationMeta('owned');
  @override
  late final GeneratedColumn<bool> owned = GeneratedColumn<bool>(
    'owned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("owned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _itadIdMeta = const VerificationMeta('itadId');
  @override
  late final GeneratedColumn<String> itadId = GeneratedColumn<String>(
    'itad_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itadUnknownMeta = const VerificationMeta(
    'itadUnknown',
  );
  @override
  late final GeneratedColumn<bool> itadUnknown = GeneratedColumn<bool>(
    'itad_unknown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("itad_unknown" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lowestEverCentsMeta = const VerificationMeta(
    'lowestEverCents',
  );
  @override
  late final GeneratedColumn<int> lowestEverCents = GeneratedColumn<int>(
    'lowest_ever_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lowestEverAtMeta = const VerificationMeta(
    'lowestEverAt',
  );
  @override
  late final GeneratedColumn<DateTime> lowestEverAt = GeneratedColumn<DateTime>(
    'lowest_ever_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _historyFetchedAtMeta = const VerificationMeta(
    'historyFetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> historyFetchedAt =
      GeneratedColumn<DateTime>(
        'history_fetched_at',
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
    owned,
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
    itadId,
    itadUnknown,
    lowestEverCents,
    lowestEverAt,
    historyFetchedAt,
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
    if (data.containsKey('owned')) {
      context.handle(
        _ownedMeta,
        owned.isAcceptableOrUnknown(data['owned']!, _ownedMeta),
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
    if (data.containsKey('itad_id')) {
      context.handle(
        _itadIdMeta,
        itadId.isAcceptableOrUnknown(data['itad_id']!, _itadIdMeta),
      );
    }
    if (data.containsKey('itad_unknown')) {
      context.handle(
        _itadUnknownMeta,
        itadUnknown.isAcceptableOrUnknown(
          data['itad_unknown']!,
          _itadUnknownMeta,
        ),
      );
    }
    if (data.containsKey('lowest_ever_cents')) {
      context.handle(
        _lowestEverCentsMeta,
        lowestEverCents.isAcceptableOrUnknown(
          data['lowest_ever_cents']!,
          _lowestEverCentsMeta,
        ),
      );
    }
    if (data.containsKey('lowest_ever_at')) {
      context.handle(
        _lowestEverAtMeta,
        lowestEverAt.isAcceptableOrUnknown(
          data['lowest_ever_at']!,
          _lowestEverAtMeta,
        ),
      );
    }
    if (data.containsKey('history_fetched_at')) {
      context.handle(
        _historyFetchedAtMeta,
        historyFetchedAt.isAcceptableOrUnknown(
          data['history_fetched_at']!,
          _historyFetchedAtMeta,
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
      owned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}owned'],
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
      itadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}itad_id'],
      ),
      itadUnknown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}itad_unknown'],
      )!,
      lowestEverCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lowest_ever_cents'],
      ),
      lowestEverAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lowest_ever_at'],
      ),
      historyFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}history_fetched_at'],
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

  /// Whether the last Steam library sync confirmed this account owns it.
  /// False for anything added by search, and for a game that used to be
  /// owned but dropped out of a later sync (refunded, account changed) —
  /// the row itself is left alone either way; only tracking removes it.
  final bool owned;
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

  /// The most recent price seen, mirrored here so the tracked-games grid can
  /// show a price without reading the history table once per tile.
  final int? lastPriceCents;
  final int? lastInitialCents;
  final int? lastDiscountPercent;
  final String? currency;

  /// When the store page was last read. Null means "never".
  final DateTime? detailsFetchedAt;

  /// IsThereAnyDeal's own UUID for this game, resolved once from the Steam
  /// app id and then reused — the lookup is a whole extra round trip.
  /// Null means "not looked up"; [itadUnknown] distinguishes that from
  /// "looked up, and ITAD does not carry it".
  final String? itadId;
  final bool itadUnknown;

  /// The all-time low ITAD has on record, and when it happened.
  final int? lowestEverCents;
  final DateTime? lowestEverAt;

  /// When the price history was last pulled from ITAD.
  final DateTime? historyFetchedAt;
  const SteamGame({
    required this.appId,
    required this.name,
    required this.playtimeMinutes,
    required this.owned,
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
    this.itadId,
    required this.itadUnknown,
    this.lowestEverCents,
    this.lowestEverAt,
    this.historyFetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['app_id'] = Variable<int>(appId);
    map['name'] = Variable<String>(name);
    map['playtime_minutes'] = Variable<int>(playtimeMinutes);
    map['owned'] = Variable<bool>(owned);
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
    if (!nullToAbsent || itadId != null) {
      map['itad_id'] = Variable<String>(itadId);
    }
    map['itad_unknown'] = Variable<bool>(itadUnknown);
    if (!nullToAbsent || lowestEverCents != null) {
      map['lowest_ever_cents'] = Variable<int>(lowestEverCents);
    }
    if (!nullToAbsent || lowestEverAt != null) {
      map['lowest_ever_at'] = Variable<DateTime>(lowestEverAt);
    }
    if (!nullToAbsent || historyFetchedAt != null) {
      map['history_fetched_at'] = Variable<DateTime>(historyFetchedAt);
    }
    return map;
  }

  SteamGamesCompanion toCompanion(bool nullToAbsent) {
    return SteamGamesCompanion(
      appId: Value(appId),
      name: Value(name),
      playtimeMinutes: Value(playtimeMinutes),
      owned: Value(owned),
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
      itadId: itadId == null && nullToAbsent
          ? const Value.absent()
          : Value(itadId),
      itadUnknown: Value(itadUnknown),
      lowestEverCents: lowestEverCents == null && nullToAbsent
          ? const Value.absent()
          : Value(lowestEverCents),
      lowestEverAt: lowestEverAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lowestEverAt),
      historyFetchedAt: historyFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(historyFetchedAt),
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
      owned: serializer.fromJson<bool>(json['owned']),
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
      itadId: serializer.fromJson<String?>(json['itadId']),
      itadUnknown: serializer.fromJson<bool>(json['itadUnknown']),
      lowestEverCents: serializer.fromJson<int?>(json['lowestEverCents']),
      lowestEverAt: serializer.fromJson<DateTime?>(json['lowestEverAt']),
      historyFetchedAt: serializer.fromJson<DateTime?>(
        json['historyFetchedAt'],
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
      'owned': serializer.toJson<bool>(owned),
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
      'itadId': serializer.toJson<String?>(itadId),
      'itadUnknown': serializer.toJson<bool>(itadUnknown),
      'lowestEverCents': serializer.toJson<int?>(lowestEverCents),
      'lowestEverAt': serializer.toJson<DateTime?>(lowestEverAt),
      'historyFetchedAt': serializer.toJson<DateTime?>(historyFetchedAt),
    };
  }

  SteamGame copyWith({
    int? appId,
    String? name,
    int? playtimeMinutes,
    bool? owned,
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
    Value<String?> itadId = const Value.absent(),
    bool? itadUnknown,
    Value<int?> lowestEverCents = const Value.absent(),
    Value<DateTime?> lowestEverAt = const Value.absent(),
    Value<DateTime?> historyFetchedAt = const Value.absent(),
  }) => SteamGame(
    appId: appId ?? this.appId,
    name: name ?? this.name,
    playtimeMinutes: playtimeMinutes ?? this.playtimeMinutes,
    owned: owned ?? this.owned,
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
    itadId: itadId.present ? itadId.value : this.itadId,
    itadUnknown: itadUnknown ?? this.itadUnknown,
    lowestEverCents: lowestEverCents.present
        ? lowestEverCents.value
        : this.lowestEverCents,
    lowestEverAt: lowestEverAt.present ? lowestEverAt.value : this.lowestEverAt,
    historyFetchedAt: historyFetchedAt.present
        ? historyFetchedAt.value
        : this.historyFetchedAt,
  );
  SteamGame copyWithCompanion(SteamGamesCompanion data) {
    return SteamGame(
      appId: data.appId.present ? data.appId.value : this.appId,
      name: data.name.present ? data.name.value : this.name,
      playtimeMinutes: data.playtimeMinutes.present
          ? data.playtimeMinutes.value
          : this.playtimeMinutes,
      owned: data.owned.present ? data.owned.value : this.owned,
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
      itadId: data.itadId.present ? data.itadId.value : this.itadId,
      itadUnknown: data.itadUnknown.present
          ? data.itadUnknown.value
          : this.itadUnknown,
      lowestEverCents: data.lowestEverCents.present
          ? data.lowestEverCents.value
          : this.lowestEverCents,
      lowestEverAt: data.lowestEverAt.present
          ? data.lowestEverAt.value
          : this.lowestEverAt,
      historyFetchedAt: data.historyFetchedAt.present
          ? data.historyFetchedAt.value
          : this.historyFetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SteamGame(')
          ..write('appId: $appId, ')
          ..write('name: $name, ')
          ..write('playtimeMinutes: $playtimeMinutes, ')
          ..write('owned: $owned, ')
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
          ..write('detailsFetchedAt: $detailsFetchedAt, ')
          ..write('itadId: $itadId, ')
          ..write('itadUnknown: $itadUnknown, ')
          ..write('lowestEverCents: $lowestEverCents, ')
          ..write('lowestEverAt: $lowestEverAt, ')
          ..write('historyFetchedAt: $historyFetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    appId,
    name,
    playtimeMinutes,
    owned,
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
    itadId,
    itadUnknown,
    lowestEverCents,
    lowestEverAt,
    historyFetchedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SteamGame &&
          other.appId == this.appId &&
          other.name == this.name &&
          other.playtimeMinutes == this.playtimeMinutes &&
          other.owned == this.owned &&
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
          other.detailsFetchedAt == this.detailsFetchedAt &&
          other.itadId == this.itadId &&
          other.itadUnknown == this.itadUnknown &&
          other.lowestEverCents == this.lowestEverCents &&
          other.lowestEverAt == this.lowestEverAt &&
          other.historyFetchedAt == this.historyFetchedAt);
}

class SteamGamesCompanion extends UpdateCompanion<SteamGame> {
  final Value<int> appId;
  final Value<String> name;
  final Value<int> playtimeMinutes;
  final Value<bool> owned;
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
  final Value<String?> itadId;
  final Value<bool> itadUnknown;
  final Value<int?> lowestEverCents;
  final Value<DateTime?> lowestEverAt;
  final Value<DateTime?> historyFetchedAt;
  const SteamGamesCompanion({
    this.appId = const Value.absent(),
    this.name = const Value.absent(),
    this.playtimeMinutes = const Value.absent(),
    this.owned = const Value.absent(),
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
    this.itadId = const Value.absent(),
    this.itadUnknown = const Value.absent(),
    this.lowestEverCents = const Value.absent(),
    this.lowestEverAt = const Value.absent(),
    this.historyFetchedAt = const Value.absent(),
  });
  SteamGamesCompanion.insert({
    this.appId = const Value.absent(),
    required String name,
    this.playtimeMinutes = const Value.absent(),
    this.owned = const Value.absent(),
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
    this.itadId = const Value.absent(),
    this.itadUnknown = const Value.absent(),
    this.lowestEverCents = const Value.absent(),
    this.lowestEverAt = const Value.absent(),
    this.historyFetchedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<SteamGame> custom({
    Expression<int>? appId,
    Expression<String>? name,
    Expression<int>? playtimeMinutes,
    Expression<bool>? owned,
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
    Expression<String>? itadId,
    Expression<bool>? itadUnknown,
    Expression<int>? lowestEverCents,
    Expression<DateTime>? lowestEverAt,
    Expression<DateTime>? historyFetchedAt,
  }) {
    return RawValuesInsertable({
      if (appId != null) 'app_id': appId,
      if (name != null) 'name': name,
      if (playtimeMinutes != null) 'playtime_minutes': playtimeMinutes,
      if (owned != null) 'owned': owned,
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
      if (itadId != null) 'itad_id': itadId,
      if (itadUnknown != null) 'itad_unknown': itadUnknown,
      if (lowestEverCents != null) 'lowest_ever_cents': lowestEverCents,
      if (lowestEverAt != null) 'lowest_ever_at': lowestEverAt,
      if (historyFetchedAt != null) 'history_fetched_at': historyFetchedAt,
    });
  }

  SteamGamesCompanion copyWith({
    Value<int>? appId,
    Value<String>? name,
    Value<int>? playtimeMinutes,
    Value<bool>? owned,
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
    Value<String?>? itadId,
    Value<bool>? itadUnknown,
    Value<int?>? lowestEverCents,
    Value<DateTime?>? lowestEverAt,
    Value<DateTime?>? historyFetchedAt,
  }) {
    return SteamGamesCompanion(
      appId: appId ?? this.appId,
      name: name ?? this.name,
      playtimeMinutes: playtimeMinutes ?? this.playtimeMinutes,
      owned: owned ?? this.owned,
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
      itadId: itadId ?? this.itadId,
      itadUnknown: itadUnknown ?? this.itadUnknown,
      lowestEverCents: lowestEverCents ?? this.lowestEverCents,
      lowestEverAt: lowestEverAt ?? this.lowestEverAt,
      historyFetchedAt: historyFetchedAt ?? this.historyFetchedAt,
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
    if (owned.present) {
      map['owned'] = Variable<bool>(owned.value);
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
    if (itadId.present) {
      map['itad_id'] = Variable<String>(itadId.value);
    }
    if (itadUnknown.present) {
      map['itad_unknown'] = Variable<bool>(itadUnknown.value);
    }
    if (lowestEverCents.present) {
      map['lowest_ever_cents'] = Variable<int>(lowestEverCents.value);
    }
    if (lowestEverAt.present) {
      map['lowest_ever_at'] = Variable<DateTime>(lowestEverAt.value);
    }
    if (historyFetchedAt.present) {
      map['history_fetched_at'] = Variable<DateTime>(historyFetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SteamGamesCompanion(')
          ..write('appId: $appId, ')
          ..write('name: $name, ')
          ..write('playtimeMinutes: $playtimeMinutes, ')
          ..write('owned: $owned, ')
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
          ..write('detailsFetchedAt: $detailsFetchedAt, ')
          ..write('itadId: $itadId, ')
          ..write('itadUnknown: $itadUnknown, ')
          ..write('lowestEverCents: $lowestEverCents, ')
          ..write('lowestEverAt: $lowestEverAt, ')
          ..write('historyFetchedAt: $historyFetchedAt')
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

class $Cs2MarketItemsTable extends Cs2MarketItems
    with TableInfo<$Cs2MarketItemsTable, Cs2MarketItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $Cs2MarketItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _marketHashNameMeta = const VerificationMeta(
    'marketHashName',
  );
  @override
  late final GeneratedColumn<String> marketHashName = GeneratedColumn<String>(
    'market_hash_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skinIdMeta = const VerificationMeta('skinId');
  @override
  late final GeneratedColumn<String> skinId = GeneratedColumn<String>(
    'skin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weaponNameMeta = const VerificationMeta(
    'weaponName',
  );
  @override
  late final GeneratedColumn<String> weaponName = GeneratedColumn<String>(
    'weapon_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rarityNameMeta = const VerificationMeta(
    'rarityName',
  );
  @override
  late final GeneratedColumn<String> rarityName = GeneratedColumn<String>(
    'rarity_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rarityColorMeta = const VerificationMeta(
    'rarityColor',
  );
  @override
  late final GeneratedColumn<String> rarityColor = GeneratedColumn<String>(
    'rarity_color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caseNameMeta = const VerificationMeta(
    'caseName',
  );
  @override
  late final GeneratedColumn<String> caseName = GeneratedColumn<String>(
    'case_name',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wearMeta = const VerificationMeta('wear');
  @override
  late final GeneratedColumn<String> wear = GeneratedColumn<String>(
    'wear',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statTrakMeta = const VerificationMeta(
    'statTrak',
  );
  @override
  late final GeneratedColumn<bool> statTrak = GeneratedColumn<bool>(
    'stat_trak',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("stat_trak" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastLowestCentsMeta = const VerificationMeta(
    'lastLowestCents',
  );
  @override
  late final GeneratedColumn<int> lastLowestCents = GeneratedColumn<int>(
    'last_lowest_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMedianCentsMeta = const VerificationMeta(
    'lastMedianCents',
  );
  @override
  late final GeneratedColumn<int> lastMedianCents = GeneratedColumn<int>(
    'last_median_cents',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('USD'),
  );
  static const VerificationMeta _priceFetchedAtMeta = const VerificationMeta(
    'priceFetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> priceFetchedAt =
      GeneratedColumn<DateTime>(
        'price_fetched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _trackedAtMeta = const VerificationMeta(
    'trackedAt',
  );
  @override
  late final GeneratedColumn<DateTime> trackedAt = GeneratedColumn<DateTime>(
    'tracked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    marketHashName,
    skinId,
    displayName,
    weaponName,
    rarityName,
    rarityColor,
    caseName,
    imageUrl,
    wear,
    statTrak,
    lastLowestCents,
    lastMedianCents,
    currency,
    priceFetchedAt,
    trackedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cs2_market_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cs2MarketItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('market_hash_name')) {
      context.handle(
        _marketHashNameMeta,
        marketHashName.isAcceptableOrUnknown(
          data['market_hash_name']!,
          _marketHashNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_marketHashNameMeta);
    }
    if (data.containsKey('skin_id')) {
      context.handle(
        _skinIdMeta,
        skinId.isAcceptableOrUnknown(data['skin_id']!, _skinIdMeta),
      );
    } else if (isInserting) {
      context.missing(_skinIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('weapon_name')) {
      context.handle(
        _weaponNameMeta,
        weaponName.isAcceptableOrUnknown(data['weapon_name']!, _weaponNameMeta),
      );
    } else if (isInserting) {
      context.missing(_weaponNameMeta);
    }
    if (data.containsKey('rarity_name')) {
      context.handle(
        _rarityNameMeta,
        rarityName.isAcceptableOrUnknown(data['rarity_name']!, _rarityNameMeta),
      );
    } else if (isInserting) {
      context.missing(_rarityNameMeta);
    }
    if (data.containsKey('rarity_color')) {
      context.handle(
        _rarityColorMeta,
        rarityColor.isAcceptableOrUnknown(
          data['rarity_color']!,
          _rarityColorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rarityColorMeta);
    }
    if (data.containsKey('case_name')) {
      context.handle(
        _caseNameMeta,
        caseName.isAcceptableOrUnknown(data['case_name']!, _caseNameMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_imageUrlMeta);
    }
    if (data.containsKey('wear')) {
      context.handle(
        _wearMeta,
        wear.isAcceptableOrUnknown(data['wear']!, _wearMeta),
      );
    }
    if (data.containsKey('stat_trak')) {
      context.handle(
        _statTrakMeta,
        statTrak.isAcceptableOrUnknown(data['stat_trak']!, _statTrakMeta),
      );
    }
    if (data.containsKey('last_lowest_cents')) {
      context.handle(
        _lastLowestCentsMeta,
        lastLowestCents.isAcceptableOrUnknown(
          data['last_lowest_cents']!,
          _lastLowestCentsMeta,
        ),
      );
    }
    if (data.containsKey('last_median_cents')) {
      context.handle(
        _lastMedianCentsMeta,
        lastMedianCents.isAcceptableOrUnknown(
          data['last_median_cents']!,
          _lastMedianCentsMeta,
        ),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('price_fetched_at')) {
      context.handle(
        _priceFetchedAtMeta,
        priceFetchedAt.isAcceptableOrUnknown(
          data['price_fetched_at']!,
          _priceFetchedAtMeta,
        ),
      );
    }
    if (data.containsKey('tracked_at')) {
      context.handle(
        _trackedAtMeta,
        trackedAt.isAcceptableOrUnknown(data['tracked_at']!, _trackedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {marketHashName};
  @override
  Cs2MarketItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cs2MarketItem(
      marketHashName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}market_hash_name'],
      )!,
      skinId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skin_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      weaponName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weapon_name'],
      )!,
      rarityName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rarity_name'],
      )!,
      rarityColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rarity_color'],
      )!,
      caseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_name'],
      ),
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      )!,
      wear: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wear'],
      ),
      statTrak: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}stat_trak'],
      )!,
      lastLowestCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_lowest_cents'],
      ),
      lastMedianCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_median_cents'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      priceFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}price_fetched_at'],
      ),
      trackedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}tracked_at'],
      )!,
    );
  }

  @override
  $Cs2MarketItemsTable createAlias(String alias) {
    return $Cs2MarketItemsTable(attachedDatabase, alias);
  }
}

class Cs2MarketItem extends DataClass implements Insertable<Cs2MarketItem> {
  final String marketHashName;

  /// The dataset id of the underlying finish, so a row can be re-associated
  /// with its catalog entry (image, rarity, case) after a catalog refresh.
  final String skinId;
  final String displayName;
  final String weaponName;
  final String rarityName;
  final String rarityColor;
  final String? caseName;
  final String imageUrl;
  final String? wear;
  final bool statTrak;

  /// The most recent read, mirrored here so the browse grid can show a price
  /// without a join into the history table per tile.
  final int? lastLowestCents;
  final int? lastMedianCents;
  final String currency;
  final DateTime? priceFetchedAt;
  final DateTime trackedAt;
  const Cs2MarketItem({
    required this.marketHashName,
    required this.skinId,
    required this.displayName,
    required this.weaponName,
    required this.rarityName,
    required this.rarityColor,
    this.caseName,
    required this.imageUrl,
    this.wear,
    required this.statTrak,
    this.lastLowestCents,
    this.lastMedianCents,
    required this.currency,
    this.priceFetchedAt,
    required this.trackedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['market_hash_name'] = Variable<String>(marketHashName);
    map['skin_id'] = Variable<String>(skinId);
    map['display_name'] = Variable<String>(displayName);
    map['weapon_name'] = Variable<String>(weaponName);
    map['rarity_name'] = Variable<String>(rarityName);
    map['rarity_color'] = Variable<String>(rarityColor);
    if (!nullToAbsent || caseName != null) {
      map['case_name'] = Variable<String>(caseName);
    }
    map['image_url'] = Variable<String>(imageUrl);
    if (!nullToAbsent || wear != null) {
      map['wear'] = Variable<String>(wear);
    }
    map['stat_trak'] = Variable<bool>(statTrak);
    if (!nullToAbsent || lastLowestCents != null) {
      map['last_lowest_cents'] = Variable<int>(lastLowestCents);
    }
    if (!nullToAbsent || lastMedianCents != null) {
      map['last_median_cents'] = Variable<int>(lastMedianCents);
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || priceFetchedAt != null) {
      map['price_fetched_at'] = Variable<DateTime>(priceFetchedAt);
    }
    map['tracked_at'] = Variable<DateTime>(trackedAt);
    return map;
  }

  Cs2MarketItemsCompanion toCompanion(bool nullToAbsent) {
    return Cs2MarketItemsCompanion(
      marketHashName: Value(marketHashName),
      skinId: Value(skinId),
      displayName: Value(displayName),
      weaponName: Value(weaponName),
      rarityName: Value(rarityName),
      rarityColor: Value(rarityColor),
      caseName: caseName == null && nullToAbsent
          ? const Value.absent()
          : Value(caseName),
      imageUrl: Value(imageUrl),
      wear: wear == null && nullToAbsent ? const Value.absent() : Value(wear),
      statTrak: Value(statTrak),
      lastLowestCents: lastLowestCents == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLowestCents),
      lastMedianCents: lastMedianCents == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMedianCents),
      currency: Value(currency),
      priceFetchedAt: priceFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(priceFetchedAt),
      trackedAt: Value(trackedAt),
    );
  }

  factory Cs2MarketItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cs2MarketItem(
      marketHashName: serializer.fromJson<String>(json['marketHashName']),
      skinId: serializer.fromJson<String>(json['skinId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      weaponName: serializer.fromJson<String>(json['weaponName']),
      rarityName: serializer.fromJson<String>(json['rarityName']),
      rarityColor: serializer.fromJson<String>(json['rarityColor']),
      caseName: serializer.fromJson<String?>(json['caseName']),
      imageUrl: serializer.fromJson<String>(json['imageUrl']),
      wear: serializer.fromJson<String?>(json['wear']),
      statTrak: serializer.fromJson<bool>(json['statTrak']),
      lastLowestCents: serializer.fromJson<int?>(json['lastLowestCents']),
      lastMedianCents: serializer.fromJson<int?>(json['lastMedianCents']),
      currency: serializer.fromJson<String>(json['currency']),
      priceFetchedAt: serializer.fromJson<DateTime?>(json['priceFetchedAt']),
      trackedAt: serializer.fromJson<DateTime>(json['trackedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'marketHashName': serializer.toJson<String>(marketHashName),
      'skinId': serializer.toJson<String>(skinId),
      'displayName': serializer.toJson<String>(displayName),
      'weaponName': serializer.toJson<String>(weaponName),
      'rarityName': serializer.toJson<String>(rarityName),
      'rarityColor': serializer.toJson<String>(rarityColor),
      'caseName': serializer.toJson<String?>(caseName),
      'imageUrl': serializer.toJson<String>(imageUrl),
      'wear': serializer.toJson<String?>(wear),
      'statTrak': serializer.toJson<bool>(statTrak),
      'lastLowestCents': serializer.toJson<int?>(lastLowestCents),
      'lastMedianCents': serializer.toJson<int?>(lastMedianCents),
      'currency': serializer.toJson<String>(currency),
      'priceFetchedAt': serializer.toJson<DateTime?>(priceFetchedAt),
      'trackedAt': serializer.toJson<DateTime>(trackedAt),
    };
  }

  Cs2MarketItem copyWith({
    String? marketHashName,
    String? skinId,
    String? displayName,
    String? weaponName,
    String? rarityName,
    String? rarityColor,
    Value<String?> caseName = const Value.absent(),
    String? imageUrl,
    Value<String?> wear = const Value.absent(),
    bool? statTrak,
    Value<int?> lastLowestCents = const Value.absent(),
    Value<int?> lastMedianCents = const Value.absent(),
    String? currency,
    Value<DateTime?> priceFetchedAt = const Value.absent(),
    DateTime? trackedAt,
  }) => Cs2MarketItem(
    marketHashName: marketHashName ?? this.marketHashName,
    skinId: skinId ?? this.skinId,
    displayName: displayName ?? this.displayName,
    weaponName: weaponName ?? this.weaponName,
    rarityName: rarityName ?? this.rarityName,
    rarityColor: rarityColor ?? this.rarityColor,
    caseName: caseName.present ? caseName.value : this.caseName,
    imageUrl: imageUrl ?? this.imageUrl,
    wear: wear.present ? wear.value : this.wear,
    statTrak: statTrak ?? this.statTrak,
    lastLowestCents: lastLowestCents.present
        ? lastLowestCents.value
        : this.lastLowestCents,
    lastMedianCents: lastMedianCents.present
        ? lastMedianCents.value
        : this.lastMedianCents,
    currency: currency ?? this.currency,
    priceFetchedAt: priceFetchedAt.present
        ? priceFetchedAt.value
        : this.priceFetchedAt,
    trackedAt: trackedAt ?? this.trackedAt,
  );
  Cs2MarketItem copyWithCompanion(Cs2MarketItemsCompanion data) {
    return Cs2MarketItem(
      marketHashName: data.marketHashName.present
          ? data.marketHashName.value
          : this.marketHashName,
      skinId: data.skinId.present ? data.skinId.value : this.skinId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      weaponName: data.weaponName.present
          ? data.weaponName.value
          : this.weaponName,
      rarityName: data.rarityName.present
          ? data.rarityName.value
          : this.rarityName,
      rarityColor: data.rarityColor.present
          ? data.rarityColor.value
          : this.rarityColor,
      caseName: data.caseName.present ? data.caseName.value : this.caseName,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      wear: data.wear.present ? data.wear.value : this.wear,
      statTrak: data.statTrak.present ? data.statTrak.value : this.statTrak,
      lastLowestCents: data.lastLowestCents.present
          ? data.lastLowestCents.value
          : this.lastLowestCents,
      lastMedianCents: data.lastMedianCents.present
          ? data.lastMedianCents.value
          : this.lastMedianCents,
      currency: data.currency.present ? data.currency.value : this.currency,
      priceFetchedAt: data.priceFetchedAt.present
          ? data.priceFetchedAt.value
          : this.priceFetchedAt,
      trackedAt: data.trackedAt.present ? data.trackedAt.value : this.trackedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cs2MarketItem(')
          ..write('marketHashName: $marketHashName, ')
          ..write('skinId: $skinId, ')
          ..write('displayName: $displayName, ')
          ..write('weaponName: $weaponName, ')
          ..write('rarityName: $rarityName, ')
          ..write('rarityColor: $rarityColor, ')
          ..write('caseName: $caseName, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('wear: $wear, ')
          ..write('statTrak: $statTrak, ')
          ..write('lastLowestCents: $lastLowestCents, ')
          ..write('lastMedianCents: $lastMedianCents, ')
          ..write('currency: $currency, ')
          ..write('priceFetchedAt: $priceFetchedAt, ')
          ..write('trackedAt: $trackedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    marketHashName,
    skinId,
    displayName,
    weaponName,
    rarityName,
    rarityColor,
    caseName,
    imageUrl,
    wear,
    statTrak,
    lastLowestCents,
    lastMedianCents,
    currency,
    priceFetchedAt,
    trackedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cs2MarketItem &&
          other.marketHashName == this.marketHashName &&
          other.skinId == this.skinId &&
          other.displayName == this.displayName &&
          other.weaponName == this.weaponName &&
          other.rarityName == this.rarityName &&
          other.rarityColor == this.rarityColor &&
          other.caseName == this.caseName &&
          other.imageUrl == this.imageUrl &&
          other.wear == this.wear &&
          other.statTrak == this.statTrak &&
          other.lastLowestCents == this.lastLowestCents &&
          other.lastMedianCents == this.lastMedianCents &&
          other.currency == this.currency &&
          other.priceFetchedAt == this.priceFetchedAt &&
          other.trackedAt == this.trackedAt);
}

class Cs2MarketItemsCompanion extends UpdateCompanion<Cs2MarketItem> {
  final Value<String> marketHashName;
  final Value<String> skinId;
  final Value<String> displayName;
  final Value<String> weaponName;
  final Value<String> rarityName;
  final Value<String> rarityColor;
  final Value<String?> caseName;
  final Value<String> imageUrl;
  final Value<String?> wear;
  final Value<bool> statTrak;
  final Value<int?> lastLowestCents;
  final Value<int?> lastMedianCents;
  final Value<String> currency;
  final Value<DateTime?> priceFetchedAt;
  final Value<DateTime> trackedAt;
  final Value<int> rowid;
  const Cs2MarketItemsCompanion({
    this.marketHashName = const Value.absent(),
    this.skinId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.weaponName = const Value.absent(),
    this.rarityName = const Value.absent(),
    this.rarityColor = const Value.absent(),
    this.caseName = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.wear = const Value.absent(),
    this.statTrak = const Value.absent(),
    this.lastLowestCents = const Value.absent(),
    this.lastMedianCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.priceFetchedAt = const Value.absent(),
    this.trackedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  Cs2MarketItemsCompanion.insert({
    required String marketHashName,
    required String skinId,
    required String displayName,
    required String weaponName,
    required String rarityName,
    required String rarityColor,
    this.caseName = const Value.absent(),
    required String imageUrl,
    this.wear = const Value.absent(),
    this.statTrak = const Value.absent(),
    this.lastLowestCents = const Value.absent(),
    this.lastMedianCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.priceFetchedAt = const Value.absent(),
    this.trackedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : marketHashName = Value(marketHashName),
       skinId = Value(skinId),
       displayName = Value(displayName),
       weaponName = Value(weaponName),
       rarityName = Value(rarityName),
       rarityColor = Value(rarityColor),
       imageUrl = Value(imageUrl);
  static Insertable<Cs2MarketItem> custom({
    Expression<String>? marketHashName,
    Expression<String>? skinId,
    Expression<String>? displayName,
    Expression<String>? weaponName,
    Expression<String>? rarityName,
    Expression<String>? rarityColor,
    Expression<String>? caseName,
    Expression<String>? imageUrl,
    Expression<String>? wear,
    Expression<bool>? statTrak,
    Expression<int>? lastLowestCents,
    Expression<int>? lastMedianCents,
    Expression<String>? currency,
    Expression<DateTime>? priceFetchedAt,
    Expression<DateTime>? trackedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (marketHashName != null) 'market_hash_name': marketHashName,
      if (skinId != null) 'skin_id': skinId,
      if (displayName != null) 'display_name': displayName,
      if (weaponName != null) 'weapon_name': weaponName,
      if (rarityName != null) 'rarity_name': rarityName,
      if (rarityColor != null) 'rarity_color': rarityColor,
      if (caseName != null) 'case_name': caseName,
      if (imageUrl != null) 'image_url': imageUrl,
      if (wear != null) 'wear': wear,
      if (statTrak != null) 'stat_trak': statTrak,
      if (lastLowestCents != null) 'last_lowest_cents': lastLowestCents,
      if (lastMedianCents != null) 'last_median_cents': lastMedianCents,
      if (currency != null) 'currency': currency,
      if (priceFetchedAt != null) 'price_fetched_at': priceFetchedAt,
      if (trackedAt != null) 'tracked_at': trackedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  Cs2MarketItemsCompanion copyWith({
    Value<String>? marketHashName,
    Value<String>? skinId,
    Value<String>? displayName,
    Value<String>? weaponName,
    Value<String>? rarityName,
    Value<String>? rarityColor,
    Value<String?>? caseName,
    Value<String>? imageUrl,
    Value<String?>? wear,
    Value<bool>? statTrak,
    Value<int?>? lastLowestCents,
    Value<int?>? lastMedianCents,
    Value<String>? currency,
    Value<DateTime?>? priceFetchedAt,
    Value<DateTime>? trackedAt,
    Value<int>? rowid,
  }) {
    return Cs2MarketItemsCompanion(
      marketHashName: marketHashName ?? this.marketHashName,
      skinId: skinId ?? this.skinId,
      displayName: displayName ?? this.displayName,
      weaponName: weaponName ?? this.weaponName,
      rarityName: rarityName ?? this.rarityName,
      rarityColor: rarityColor ?? this.rarityColor,
      caseName: caseName ?? this.caseName,
      imageUrl: imageUrl ?? this.imageUrl,
      wear: wear ?? this.wear,
      statTrak: statTrak ?? this.statTrak,
      lastLowestCents: lastLowestCents ?? this.lastLowestCents,
      lastMedianCents: lastMedianCents ?? this.lastMedianCents,
      currency: currency ?? this.currency,
      priceFetchedAt: priceFetchedAt ?? this.priceFetchedAt,
      trackedAt: trackedAt ?? this.trackedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (marketHashName.present) {
      map['market_hash_name'] = Variable<String>(marketHashName.value);
    }
    if (skinId.present) {
      map['skin_id'] = Variable<String>(skinId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (weaponName.present) {
      map['weapon_name'] = Variable<String>(weaponName.value);
    }
    if (rarityName.present) {
      map['rarity_name'] = Variable<String>(rarityName.value);
    }
    if (rarityColor.present) {
      map['rarity_color'] = Variable<String>(rarityColor.value);
    }
    if (caseName.present) {
      map['case_name'] = Variable<String>(caseName.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (wear.present) {
      map['wear'] = Variable<String>(wear.value);
    }
    if (statTrak.present) {
      map['stat_trak'] = Variable<bool>(statTrak.value);
    }
    if (lastLowestCents.present) {
      map['last_lowest_cents'] = Variable<int>(lastLowestCents.value);
    }
    if (lastMedianCents.present) {
      map['last_median_cents'] = Variable<int>(lastMedianCents.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (priceFetchedAt.present) {
      map['price_fetched_at'] = Variable<DateTime>(priceFetchedAt.value);
    }
    if (trackedAt.present) {
      map['tracked_at'] = Variable<DateTime>(trackedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('Cs2MarketItemsCompanion(')
          ..write('marketHashName: $marketHashName, ')
          ..write('skinId: $skinId, ')
          ..write('displayName: $displayName, ')
          ..write('weaponName: $weaponName, ')
          ..write('rarityName: $rarityName, ')
          ..write('rarityColor: $rarityColor, ')
          ..write('caseName: $caseName, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('wear: $wear, ')
          ..write('statTrak: $statTrak, ')
          ..write('lastLowestCents: $lastLowestCents, ')
          ..write('lastMedianCents: $lastMedianCents, ')
          ..write('currency: $currency, ')
          ..write('priceFetchedAt: $priceFetchedAt, ')
          ..write('trackedAt: $trackedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $Cs2MarketPricePointsTable extends Cs2MarketPricePoints
    with TableInfo<$Cs2MarketPricePointsTable, Cs2MarketPricePoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $Cs2MarketPricePointsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _marketHashNameMeta = const VerificationMeta(
    'marketHashName',
  );
  @override
  late final GeneratedColumn<String> marketHashName = GeneratedColumn<String>(
    'market_hash_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _lowestCentsMeta = const VerificationMeta(
    'lowestCents',
  );
  @override
  late final GeneratedColumn<int> lowestCents = GeneratedColumn<int>(
    'lowest_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _medianCentsMeta = const VerificationMeta(
    'medianCents',
  );
  @override
  late final GeneratedColumn<int> medianCents = GeneratedColumn<int>(
    'median_cents',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    marketHashName,
    observedAt,
    lowestCents,
    medianCents,
    currency,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cs2_market_price_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cs2MarketPricePoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('market_hash_name')) {
      context.handle(
        _marketHashNameMeta,
        marketHashName.isAcceptableOrUnknown(
          data['market_hash_name']!,
          _marketHashNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_marketHashNameMeta);
    }
    if (data.containsKey('observed_at')) {
      context.handle(
        _observedAtMeta,
        observedAt.isAcceptableOrUnknown(data['observed_at']!, _observedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_observedAtMeta);
    }
    if (data.containsKey('lowest_cents')) {
      context.handle(
        _lowestCentsMeta,
        lowestCents.isAcceptableOrUnknown(
          data['lowest_cents']!,
          _lowestCentsMeta,
        ),
      );
    }
    if (data.containsKey('median_cents')) {
      context.handle(
        _medianCentsMeta,
        medianCents.isAcceptableOrUnknown(
          data['median_cents']!,
          _medianCentsMeta,
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
  Cs2MarketPricePoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cs2MarketPricePoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      marketHashName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}market_hash_name'],
      )!,
      observedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}observed_at'],
      )!,
      lowestCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lowest_cents'],
      ),
      medianCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}median_cents'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
    );
  }

  @override
  $Cs2MarketPricePointsTable createAlias(String alias) {
    return $Cs2MarketPricePointsTable(attachedDatabase, alias);
  }
}

class Cs2MarketPricePoint extends DataClass
    implements Insertable<Cs2MarketPricePoint> {
  final int id;
  final String marketHashName;
  final DateTime observedAt;
  final int? lowestCents;
  final int? medianCents;
  final String currency;
  const Cs2MarketPricePoint({
    required this.id,
    required this.marketHashName,
    required this.observedAt,
    this.lowestCents,
    this.medianCents,
    required this.currency,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['market_hash_name'] = Variable<String>(marketHashName);
    map['observed_at'] = Variable<DateTime>(observedAt);
    if (!nullToAbsent || lowestCents != null) {
      map['lowest_cents'] = Variable<int>(lowestCents);
    }
    if (!nullToAbsent || medianCents != null) {
      map['median_cents'] = Variable<int>(medianCents);
    }
    map['currency'] = Variable<String>(currency);
    return map;
  }

  Cs2MarketPricePointsCompanion toCompanion(bool nullToAbsent) {
    return Cs2MarketPricePointsCompanion(
      id: Value(id),
      marketHashName: Value(marketHashName),
      observedAt: Value(observedAt),
      lowestCents: lowestCents == null && nullToAbsent
          ? const Value.absent()
          : Value(lowestCents),
      medianCents: medianCents == null && nullToAbsent
          ? const Value.absent()
          : Value(medianCents),
      currency: Value(currency),
    );
  }

  factory Cs2MarketPricePoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cs2MarketPricePoint(
      id: serializer.fromJson<int>(json['id']),
      marketHashName: serializer.fromJson<String>(json['marketHashName']),
      observedAt: serializer.fromJson<DateTime>(json['observedAt']),
      lowestCents: serializer.fromJson<int?>(json['lowestCents']),
      medianCents: serializer.fromJson<int?>(json['medianCents']),
      currency: serializer.fromJson<String>(json['currency']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'marketHashName': serializer.toJson<String>(marketHashName),
      'observedAt': serializer.toJson<DateTime>(observedAt),
      'lowestCents': serializer.toJson<int?>(lowestCents),
      'medianCents': serializer.toJson<int?>(medianCents),
      'currency': serializer.toJson<String>(currency),
    };
  }

  Cs2MarketPricePoint copyWith({
    int? id,
    String? marketHashName,
    DateTime? observedAt,
    Value<int?> lowestCents = const Value.absent(),
    Value<int?> medianCents = const Value.absent(),
    String? currency,
  }) => Cs2MarketPricePoint(
    id: id ?? this.id,
    marketHashName: marketHashName ?? this.marketHashName,
    observedAt: observedAt ?? this.observedAt,
    lowestCents: lowestCents.present ? lowestCents.value : this.lowestCents,
    medianCents: medianCents.present ? medianCents.value : this.medianCents,
    currency: currency ?? this.currency,
  );
  Cs2MarketPricePoint copyWithCompanion(Cs2MarketPricePointsCompanion data) {
    return Cs2MarketPricePoint(
      id: data.id.present ? data.id.value : this.id,
      marketHashName: data.marketHashName.present
          ? data.marketHashName.value
          : this.marketHashName,
      observedAt: data.observedAt.present
          ? data.observedAt.value
          : this.observedAt,
      lowestCents: data.lowestCents.present
          ? data.lowestCents.value
          : this.lowestCents,
      medianCents: data.medianCents.present
          ? data.medianCents.value
          : this.medianCents,
      currency: data.currency.present ? data.currency.value : this.currency,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cs2MarketPricePoint(')
          ..write('id: $id, ')
          ..write('marketHashName: $marketHashName, ')
          ..write('observedAt: $observedAt, ')
          ..write('lowestCents: $lowestCents, ')
          ..write('medianCents: $medianCents, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    marketHashName,
    observedAt,
    lowestCents,
    medianCents,
    currency,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cs2MarketPricePoint &&
          other.id == this.id &&
          other.marketHashName == this.marketHashName &&
          other.observedAt == this.observedAt &&
          other.lowestCents == this.lowestCents &&
          other.medianCents == this.medianCents &&
          other.currency == this.currency);
}

class Cs2MarketPricePointsCompanion
    extends UpdateCompanion<Cs2MarketPricePoint> {
  final Value<int> id;
  final Value<String> marketHashName;
  final Value<DateTime> observedAt;
  final Value<int?> lowestCents;
  final Value<int?> medianCents;
  final Value<String> currency;
  const Cs2MarketPricePointsCompanion({
    this.id = const Value.absent(),
    this.marketHashName = const Value.absent(),
    this.observedAt = const Value.absent(),
    this.lowestCents = const Value.absent(),
    this.medianCents = const Value.absent(),
    this.currency = const Value.absent(),
  });
  Cs2MarketPricePointsCompanion.insert({
    this.id = const Value.absent(),
    required String marketHashName,
    required DateTime observedAt,
    this.lowestCents = const Value.absent(),
    this.medianCents = const Value.absent(),
    required String currency,
  }) : marketHashName = Value(marketHashName),
       observedAt = Value(observedAt),
       currency = Value(currency);
  static Insertable<Cs2MarketPricePoint> custom({
    Expression<int>? id,
    Expression<String>? marketHashName,
    Expression<DateTime>? observedAt,
    Expression<int>? lowestCents,
    Expression<int>? medianCents,
    Expression<String>? currency,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (marketHashName != null) 'market_hash_name': marketHashName,
      if (observedAt != null) 'observed_at': observedAt,
      if (lowestCents != null) 'lowest_cents': lowestCents,
      if (medianCents != null) 'median_cents': medianCents,
      if (currency != null) 'currency': currency,
    });
  }

  Cs2MarketPricePointsCompanion copyWith({
    Value<int>? id,
    Value<String>? marketHashName,
    Value<DateTime>? observedAt,
    Value<int?>? lowestCents,
    Value<int?>? medianCents,
    Value<String>? currency,
  }) {
    return Cs2MarketPricePointsCompanion(
      id: id ?? this.id,
      marketHashName: marketHashName ?? this.marketHashName,
      observedAt: observedAt ?? this.observedAt,
      lowestCents: lowestCents ?? this.lowestCents,
      medianCents: medianCents ?? this.medianCents,
      currency: currency ?? this.currency,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (marketHashName.present) {
      map['market_hash_name'] = Variable<String>(marketHashName.value);
    }
    if (observedAt.present) {
      map['observed_at'] = Variable<DateTime>(observedAt.value);
    }
    if (lowestCents.present) {
      map['lowest_cents'] = Variable<int>(lowestCents.value);
    }
    if (medianCents.present) {
      map['median_cents'] = Variable<int>(medianCents.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('Cs2MarketPricePointsCompanion(')
          ..write('id: $id, ')
          ..write('marketHashName: $marketHashName, ')
          ..write('observedAt: $observedAt, ')
          ..write('lowestCents: $lowestCents, ')
          ..write('medianCents: $medianCents, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }
}

class $Cs2PinnedSkinsTable extends Cs2PinnedSkins
    with TableInfo<$Cs2PinnedSkinsTable, Cs2PinnedSkin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $Cs2PinnedSkinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _skinIdMeta = const VerificationMeta('skinId');
  @override
  late final GeneratedColumn<String> skinId = GeneratedColumn<String>(
    'skin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedAtMeta = const VerificationMeta(
    'pinnedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pinnedAt = GeneratedColumn<DateTime>(
    'pinned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [skinId, pinnedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cs2_pinned_skins';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cs2PinnedSkin> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('skin_id')) {
      context.handle(
        _skinIdMeta,
        skinId.isAcceptableOrUnknown(data['skin_id']!, _skinIdMeta),
      );
    } else if (isInserting) {
      context.missing(_skinIdMeta);
    }
    if (data.containsKey('pinned_at')) {
      context.handle(
        _pinnedAtMeta,
        pinnedAt.isAcceptableOrUnknown(data['pinned_at']!, _pinnedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {skinId};
  @override
  Cs2PinnedSkin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cs2PinnedSkin(
      skinId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skin_id'],
      )!,
      pinnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}pinned_at'],
      )!,
    );
  }

  @override
  $Cs2PinnedSkinsTable createAlias(String alias) {
    return $Cs2PinnedSkinsTable(attachedDatabase, alias);
  }
}

class Cs2PinnedSkin extends DataClass implements Insertable<Cs2PinnedSkin> {
  final String skinId;
  final DateTime pinnedAt;
  const Cs2PinnedSkin({required this.skinId, required this.pinnedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['skin_id'] = Variable<String>(skinId);
    map['pinned_at'] = Variable<DateTime>(pinnedAt);
    return map;
  }

  Cs2PinnedSkinsCompanion toCompanion(bool nullToAbsent) {
    return Cs2PinnedSkinsCompanion(
      skinId: Value(skinId),
      pinnedAt: Value(pinnedAt),
    );
  }

  factory Cs2PinnedSkin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cs2PinnedSkin(
      skinId: serializer.fromJson<String>(json['skinId']),
      pinnedAt: serializer.fromJson<DateTime>(json['pinnedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'skinId': serializer.toJson<String>(skinId),
      'pinnedAt': serializer.toJson<DateTime>(pinnedAt),
    };
  }

  Cs2PinnedSkin copyWith({String? skinId, DateTime? pinnedAt}) => Cs2PinnedSkin(
    skinId: skinId ?? this.skinId,
    pinnedAt: pinnedAt ?? this.pinnedAt,
  );
  Cs2PinnedSkin copyWithCompanion(Cs2PinnedSkinsCompanion data) {
    return Cs2PinnedSkin(
      skinId: data.skinId.present ? data.skinId.value : this.skinId,
      pinnedAt: data.pinnedAt.present ? data.pinnedAt.value : this.pinnedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cs2PinnedSkin(')
          ..write('skinId: $skinId, ')
          ..write('pinnedAt: $pinnedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(skinId, pinnedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cs2PinnedSkin &&
          other.skinId == this.skinId &&
          other.pinnedAt == this.pinnedAt);
}

class Cs2PinnedSkinsCompanion extends UpdateCompanion<Cs2PinnedSkin> {
  final Value<String> skinId;
  final Value<DateTime> pinnedAt;
  final Value<int> rowid;
  const Cs2PinnedSkinsCompanion({
    this.skinId = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  Cs2PinnedSkinsCompanion.insert({
    required String skinId,
    this.pinnedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : skinId = Value(skinId);
  static Insertable<Cs2PinnedSkin> custom({
    Expression<String>? skinId,
    Expression<DateTime>? pinnedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (skinId != null) 'skin_id': skinId,
      if (pinnedAt != null) 'pinned_at': pinnedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  Cs2PinnedSkinsCompanion copyWith({
    Value<String>? skinId,
    Value<DateTime>? pinnedAt,
    Value<int>? rowid,
  }) {
    return Cs2PinnedSkinsCompanion(
      skinId: skinId ?? this.skinId,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (skinId.present) {
      map['skin_id'] = Variable<String>(skinId.value);
    }
    if (pinnedAt.present) {
      map['pinned_at'] = Variable<DateTime>(pinnedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('Cs2PinnedSkinsCompanion(')
          ..write('skinId: $skinId, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('rowid: $rowid')
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
  late final $Cs2MarketItemsTable cs2MarketItems = $Cs2MarketItemsTable(this);
  late final $Cs2MarketPricePointsTable cs2MarketPricePoints =
      $Cs2MarketPricePointsTable(this);
  late final $Cs2PinnedSkinsTable cs2PinnedSkins = $Cs2PinnedSkinsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    steamGames,
    steamPricePoints,
    cs2MarketItems,
    cs2MarketPricePoints,
    cs2PinnedSkins,
  ];
}

typedef $$SteamGamesTableCreateCompanionBuilder =
    SteamGamesCompanion Function({
      Value<int> appId,
      required String name,
      Value<int> playtimeMinutes,
      Value<bool> owned,
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
      Value<String?> itadId,
      Value<bool> itadUnknown,
      Value<int?> lowestEverCents,
      Value<DateTime?> lowestEverAt,
      Value<DateTime?> historyFetchedAt,
    });
typedef $$SteamGamesTableUpdateCompanionBuilder =
    SteamGamesCompanion Function({
      Value<int> appId,
      Value<String> name,
      Value<int> playtimeMinutes,
      Value<bool> owned,
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
      Value<String?> itadId,
      Value<bool> itadUnknown,
      Value<int?> lowestEverCents,
      Value<DateTime?> lowestEverAt,
      Value<DateTime?> historyFetchedAt,
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

  ColumnFilters<bool> get owned => $composableBuilder(
    column: $table.owned,
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

  ColumnFilters<String> get itadId => $composableBuilder(
    column: $table.itadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get itadUnknown => $composableBuilder(
    column: $table.itadUnknown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lowestEverCents => $composableBuilder(
    column: $table.lowestEverCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lowestEverAt => $composableBuilder(
    column: $table.lowestEverAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get historyFetchedAt => $composableBuilder(
    column: $table.historyFetchedAt,
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

  ColumnOrderings<bool> get owned => $composableBuilder(
    column: $table.owned,
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

  ColumnOrderings<String> get itadId => $composableBuilder(
    column: $table.itadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get itadUnknown => $composableBuilder(
    column: $table.itadUnknown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lowestEverCents => $composableBuilder(
    column: $table.lowestEverCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lowestEverAt => $composableBuilder(
    column: $table.lowestEverAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get historyFetchedAt => $composableBuilder(
    column: $table.historyFetchedAt,
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

  GeneratedColumn<bool> get owned =>
      $composableBuilder(column: $table.owned, builder: (column) => column);

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

  GeneratedColumn<String> get itadId =>
      $composableBuilder(column: $table.itadId, builder: (column) => column);

  GeneratedColumn<bool> get itadUnknown => $composableBuilder(
    column: $table.itadUnknown,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lowestEverCents => $composableBuilder(
    column: $table.lowestEverCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lowestEverAt => $composableBuilder(
    column: $table.lowestEverAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get historyFetchedAt => $composableBuilder(
    column: $table.historyFetchedAt,
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
                Value<bool> owned = const Value.absent(),
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
                Value<String?> itadId = const Value.absent(),
                Value<bool> itadUnknown = const Value.absent(),
                Value<int?> lowestEverCents = const Value.absent(),
                Value<DateTime?> lowestEverAt = const Value.absent(),
                Value<DateTime?> historyFetchedAt = const Value.absent(),
              }) => SteamGamesCompanion(
                appId: appId,
                name: name,
                playtimeMinutes: playtimeMinutes,
                owned: owned,
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
                itadId: itadId,
                itadUnknown: itadUnknown,
                lowestEverCents: lowestEverCents,
                lowestEverAt: lowestEverAt,
                historyFetchedAt: historyFetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> appId = const Value.absent(),
                required String name,
                Value<int> playtimeMinutes = const Value.absent(),
                Value<bool> owned = const Value.absent(),
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
                Value<String?> itadId = const Value.absent(),
                Value<bool> itadUnknown = const Value.absent(),
                Value<int?> lowestEverCents = const Value.absent(),
                Value<DateTime?> lowestEverAt = const Value.absent(),
                Value<DateTime?> historyFetchedAt = const Value.absent(),
              }) => SteamGamesCompanion.insert(
                appId: appId,
                name: name,
                playtimeMinutes: playtimeMinutes,
                owned: owned,
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
                itadId: itadId,
                itadUnknown: itadUnknown,
                lowestEverCents: lowestEverCents,
                lowestEverAt: lowestEverAt,
                historyFetchedAt: historyFetchedAt,
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
typedef $$Cs2MarketItemsTableCreateCompanionBuilder =
    Cs2MarketItemsCompanion Function({
      required String marketHashName,
      required String skinId,
      required String displayName,
      required String weaponName,
      required String rarityName,
      required String rarityColor,
      Value<String?> caseName,
      required String imageUrl,
      Value<String?> wear,
      Value<bool> statTrak,
      Value<int?> lastLowestCents,
      Value<int?> lastMedianCents,
      Value<String> currency,
      Value<DateTime?> priceFetchedAt,
      Value<DateTime> trackedAt,
      Value<int> rowid,
    });
typedef $$Cs2MarketItemsTableUpdateCompanionBuilder =
    Cs2MarketItemsCompanion Function({
      Value<String> marketHashName,
      Value<String> skinId,
      Value<String> displayName,
      Value<String> weaponName,
      Value<String> rarityName,
      Value<String> rarityColor,
      Value<String?> caseName,
      Value<String> imageUrl,
      Value<String?> wear,
      Value<bool> statTrak,
      Value<int?> lastLowestCents,
      Value<int?> lastMedianCents,
      Value<String> currency,
      Value<DateTime?> priceFetchedAt,
      Value<DateTime> trackedAt,
      Value<int> rowid,
    });

class $$Cs2MarketItemsTableFilterComposer
    extends Composer<_$SteamDatabase, $Cs2MarketItemsTable> {
  $$Cs2MarketItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get marketHashName => $composableBuilder(
    column: $table.marketHashName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skinId => $composableBuilder(
    column: $table.skinId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weaponName => $composableBuilder(
    column: $table.weaponName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rarityName => $composableBuilder(
    column: $table.rarityName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rarityColor => $composableBuilder(
    column: $table.rarityColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseName => $composableBuilder(
    column: $table.caseName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wear => $composableBuilder(
    column: $table.wear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get statTrak => $composableBuilder(
    column: $table.statTrak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastLowestCents => $composableBuilder(
    column: $table.lastLowestCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMedianCents => $composableBuilder(
    column: $table.lastMedianCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get priceFetchedAt => $composableBuilder(
    column: $table.priceFetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get trackedAt => $composableBuilder(
    column: $table.trackedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$Cs2MarketItemsTableOrderingComposer
    extends Composer<_$SteamDatabase, $Cs2MarketItemsTable> {
  $$Cs2MarketItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get marketHashName => $composableBuilder(
    column: $table.marketHashName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skinId => $composableBuilder(
    column: $table.skinId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weaponName => $composableBuilder(
    column: $table.weaponName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rarityName => $composableBuilder(
    column: $table.rarityName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rarityColor => $composableBuilder(
    column: $table.rarityColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseName => $composableBuilder(
    column: $table.caseName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wear => $composableBuilder(
    column: $table.wear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get statTrak => $composableBuilder(
    column: $table.statTrak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastLowestCents => $composableBuilder(
    column: $table.lastLowestCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMedianCents => $composableBuilder(
    column: $table.lastMedianCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get priceFetchedAt => $composableBuilder(
    column: $table.priceFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get trackedAt => $composableBuilder(
    column: $table.trackedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$Cs2MarketItemsTableAnnotationComposer
    extends Composer<_$SteamDatabase, $Cs2MarketItemsTable> {
  $$Cs2MarketItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get marketHashName => $composableBuilder(
    column: $table.marketHashName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get skinId =>
      $composableBuilder(column: $table.skinId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weaponName => $composableBuilder(
    column: $table.weaponName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rarityName => $composableBuilder(
    column: $table.rarityName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rarityColor => $composableBuilder(
    column: $table.rarityColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get caseName =>
      $composableBuilder(column: $table.caseName, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get wear =>
      $composableBuilder(column: $table.wear, builder: (column) => column);

  GeneratedColumn<bool> get statTrak =>
      $composableBuilder(column: $table.statTrak, builder: (column) => column);

  GeneratedColumn<int> get lastLowestCents => $composableBuilder(
    column: $table.lastLowestCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastMedianCents => $composableBuilder(
    column: $table.lastMedianCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get priceFetchedAt => $composableBuilder(
    column: $table.priceFetchedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get trackedAt =>
      $composableBuilder(column: $table.trackedAt, builder: (column) => column);
}

class $$Cs2MarketItemsTableTableManager
    extends
        RootTableManager<
          _$SteamDatabase,
          $Cs2MarketItemsTable,
          Cs2MarketItem,
          $$Cs2MarketItemsTableFilterComposer,
          $$Cs2MarketItemsTableOrderingComposer,
          $$Cs2MarketItemsTableAnnotationComposer,
          $$Cs2MarketItemsTableCreateCompanionBuilder,
          $$Cs2MarketItemsTableUpdateCompanionBuilder,
          (
            Cs2MarketItem,
            BaseReferences<
              _$SteamDatabase,
              $Cs2MarketItemsTable,
              Cs2MarketItem
            >,
          ),
          Cs2MarketItem,
          PrefetchHooks Function()
        > {
  $$Cs2MarketItemsTableTableManager(
    _$SteamDatabase db,
    $Cs2MarketItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$Cs2MarketItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$Cs2MarketItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$Cs2MarketItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> marketHashName = const Value.absent(),
                Value<String> skinId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> weaponName = const Value.absent(),
                Value<String> rarityName = const Value.absent(),
                Value<String> rarityColor = const Value.absent(),
                Value<String?> caseName = const Value.absent(),
                Value<String> imageUrl = const Value.absent(),
                Value<String?> wear = const Value.absent(),
                Value<bool> statTrak = const Value.absent(),
                Value<int?> lastLowestCents = const Value.absent(),
                Value<int?> lastMedianCents = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<DateTime?> priceFetchedAt = const Value.absent(),
                Value<DateTime> trackedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => Cs2MarketItemsCompanion(
                marketHashName: marketHashName,
                skinId: skinId,
                displayName: displayName,
                weaponName: weaponName,
                rarityName: rarityName,
                rarityColor: rarityColor,
                caseName: caseName,
                imageUrl: imageUrl,
                wear: wear,
                statTrak: statTrak,
                lastLowestCents: lastLowestCents,
                lastMedianCents: lastMedianCents,
                currency: currency,
                priceFetchedAt: priceFetchedAt,
                trackedAt: trackedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String marketHashName,
                required String skinId,
                required String displayName,
                required String weaponName,
                required String rarityName,
                required String rarityColor,
                Value<String?> caseName = const Value.absent(),
                required String imageUrl,
                Value<String?> wear = const Value.absent(),
                Value<bool> statTrak = const Value.absent(),
                Value<int?> lastLowestCents = const Value.absent(),
                Value<int?> lastMedianCents = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<DateTime?> priceFetchedAt = const Value.absent(),
                Value<DateTime> trackedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => Cs2MarketItemsCompanion.insert(
                marketHashName: marketHashName,
                skinId: skinId,
                displayName: displayName,
                weaponName: weaponName,
                rarityName: rarityName,
                rarityColor: rarityColor,
                caseName: caseName,
                imageUrl: imageUrl,
                wear: wear,
                statTrak: statTrak,
                lastLowestCents: lastLowestCents,
                lastMedianCents: lastMedianCents,
                currency: currency,
                priceFetchedAt: priceFetchedAt,
                trackedAt: trackedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$Cs2MarketItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$SteamDatabase,
      $Cs2MarketItemsTable,
      Cs2MarketItem,
      $$Cs2MarketItemsTableFilterComposer,
      $$Cs2MarketItemsTableOrderingComposer,
      $$Cs2MarketItemsTableAnnotationComposer,
      $$Cs2MarketItemsTableCreateCompanionBuilder,
      $$Cs2MarketItemsTableUpdateCompanionBuilder,
      (
        Cs2MarketItem,
        BaseReferences<_$SteamDatabase, $Cs2MarketItemsTable, Cs2MarketItem>,
      ),
      Cs2MarketItem,
      PrefetchHooks Function()
    >;
typedef $$Cs2MarketPricePointsTableCreateCompanionBuilder =
    Cs2MarketPricePointsCompanion Function({
      Value<int> id,
      required String marketHashName,
      required DateTime observedAt,
      Value<int?> lowestCents,
      Value<int?> medianCents,
      required String currency,
    });
typedef $$Cs2MarketPricePointsTableUpdateCompanionBuilder =
    Cs2MarketPricePointsCompanion Function({
      Value<int> id,
      Value<String> marketHashName,
      Value<DateTime> observedAt,
      Value<int?> lowestCents,
      Value<int?> medianCents,
      Value<String> currency,
    });

class $$Cs2MarketPricePointsTableFilterComposer
    extends Composer<_$SteamDatabase, $Cs2MarketPricePointsTable> {
  $$Cs2MarketPricePointsTableFilterComposer({
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

  ColumnFilters<String> get marketHashName => $composableBuilder(
    column: $table.marketHashName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lowestCents => $composableBuilder(
    column: $table.lowestCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get medianCents => $composableBuilder(
    column: $table.medianCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );
}

class $$Cs2MarketPricePointsTableOrderingComposer
    extends Composer<_$SteamDatabase, $Cs2MarketPricePointsTable> {
  $$Cs2MarketPricePointsTableOrderingComposer({
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

  ColumnOrderings<String> get marketHashName => $composableBuilder(
    column: $table.marketHashName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lowestCents => $composableBuilder(
    column: $table.lowestCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get medianCents => $composableBuilder(
    column: $table.medianCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$Cs2MarketPricePointsTableAnnotationComposer
    extends Composer<_$SteamDatabase, $Cs2MarketPricePointsTable> {
  $$Cs2MarketPricePointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get marketHashName => $composableBuilder(
    column: $table.marketHashName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lowestCents => $composableBuilder(
    column: $table.lowestCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get medianCents => $composableBuilder(
    column: $table.medianCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);
}

class $$Cs2MarketPricePointsTableTableManager
    extends
        RootTableManager<
          _$SteamDatabase,
          $Cs2MarketPricePointsTable,
          Cs2MarketPricePoint,
          $$Cs2MarketPricePointsTableFilterComposer,
          $$Cs2MarketPricePointsTableOrderingComposer,
          $$Cs2MarketPricePointsTableAnnotationComposer,
          $$Cs2MarketPricePointsTableCreateCompanionBuilder,
          $$Cs2MarketPricePointsTableUpdateCompanionBuilder,
          (
            Cs2MarketPricePoint,
            BaseReferences<
              _$SteamDatabase,
              $Cs2MarketPricePointsTable,
              Cs2MarketPricePoint
            >,
          ),
          Cs2MarketPricePoint,
          PrefetchHooks Function()
        > {
  $$Cs2MarketPricePointsTableTableManager(
    _$SteamDatabase db,
    $Cs2MarketPricePointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$Cs2MarketPricePointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$Cs2MarketPricePointsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$Cs2MarketPricePointsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> marketHashName = const Value.absent(),
                Value<DateTime> observedAt = const Value.absent(),
                Value<int?> lowestCents = const Value.absent(),
                Value<int?> medianCents = const Value.absent(),
                Value<String> currency = const Value.absent(),
              }) => Cs2MarketPricePointsCompanion(
                id: id,
                marketHashName: marketHashName,
                observedAt: observedAt,
                lowestCents: lowestCents,
                medianCents: medianCents,
                currency: currency,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String marketHashName,
                required DateTime observedAt,
                Value<int?> lowestCents = const Value.absent(),
                Value<int?> medianCents = const Value.absent(),
                required String currency,
              }) => Cs2MarketPricePointsCompanion.insert(
                id: id,
                marketHashName: marketHashName,
                observedAt: observedAt,
                lowestCents: lowestCents,
                medianCents: medianCents,
                currency: currency,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$Cs2MarketPricePointsTableProcessedTableManager =
    ProcessedTableManager<
      _$SteamDatabase,
      $Cs2MarketPricePointsTable,
      Cs2MarketPricePoint,
      $$Cs2MarketPricePointsTableFilterComposer,
      $$Cs2MarketPricePointsTableOrderingComposer,
      $$Cs2MarketPricePointsTableAnnotationComposer,
      $$Cs2MarketPricePointsTableCreateCompanionBuilder,
      $$Cs2MarketPricePointsTableUpdateCompanionBuilder,
      (
        Cs2MarketPricePoint,
        BaseReferences<
          _$SteamDatabase,
          $Cs2MarketPricePointsTable,
          Cs2MarketPricePoint
        >,
      ),
      Cs2MarketPricePoint,
      PrefetchHooks Function()
    >;
typedef $$Cs2PinnedSkinsTableCreateCompanionBuilder =
    Cs2PinnedSkinsCompanion Function({
      required String skinId,
      Value<DateTime> pinnedAt,
      Value<int> rowid,
    });
typedef $$Cs2PinnedSkinsTableUpdateCompanionBuilder =
    Cs2PinnedSkinsCompanion Function({
      Value<String> skinId,
      Value<DateTime> pinnedAt,
      Value<int> rowid,
    });

class $$Cs2PinnedSkinsTableFilterComposer
    extends Composer<_$SteamDatabase, $Cs2PinnedSkinsTable> {
  $$Cs2PinnedSkinsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get skinId => $composableBuilder(
    column: $table.skinId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$Cs2PinnedSkinsTableOrderingComposer
    extends Composer<_$SteamDatabase, $Cs2PinnedSkinsTable> {
  $$Cs2PinnedSkinsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get skinId => $composableBuilder(
    column: $table.skinId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$Cs2PinnedSkinsTableAnnotationComposer
    extends Composer<_$SteamDatabase, $Cs2PinnedSkinsTable> {
  $$Cs2PinnedSkinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get skinId =>
      $composableBuilder(column: $table.skinId, builder: (column) => column);

  GeneratedColumn<DateTime> get pinnedAt =>
      $composableBuilder(column: $table.pinnedAt, builder: (column) => column);
}

class $$Cs2PinnedSkinsTableTableManager
    extends
        RootTableManager<
          _$SteamDatabase,
          $Cs2PinnedSkinsTable,
          Cs2PinnedSkin,
          $$Cs2PinnedSkinsTableFilterComposer,
          $$Cs2PinnedSkinsTableOrderingComposer,
          $$Cs2PinnedSkinsTableAnnotationComposer,
          $$Cs2PinnedSkinsTableCreateCompanionBuilder,
          $$Cs2PinnedSkinsTableUpdateCompanionBuilder,
          (
            Cs2PinnedSkin,
            BaseReferences<
              _$SteamDatabase,
              $Cs2PinnedSkinsTable,
              Cs2PinnedSkin
            >,
          ),
          Cs2PinnedSkin,
          PrefetchHooks Function()
        > {
  $$Cs2PinnedSkinsTableTableManager(
    _$SteamDatabase db,
    $Cs2PinnedSkinsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$Cs2PinnedSkinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$Cs2PinnedSkinsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$Cs2PinnedSkinsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> skinId = const Value.absent(),
                Value<DateTime> pinnedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => Cs2PinnedSkinsCompanion(
                skinId: skinId,
                pinnedAt: pinnedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String skinId,
                Value<DateTime> pinnedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => Cs2PinnedSkinsCompanion.insert(
                skinId: skinId,
                pinnedAt: pinnedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$Cs2PinnedSkinsTableProcessedTableManager =
    ProcessedTableManager<
      _$SteamDatabase,
      $Cs2PinnedSkinsTable,
      Cs2PinnedSkin,
      $$Cs2PinnedSkinsTableFilterComposer,
      $$Cs2PinnedSkinsTableOrderingComposer,
      $$Cs2PinnedSkinsTableAnnotationComposer,
      $$Cs2PinnedSkinsTableCreateCompanionBuilder,
      $$Cs2PinnedSkinsTableUpdateCompanionBuilder,
      (
        Cs2PinnedSkin,
        BaseReferences<_$SteamDatabase, $Cs2PinnedSkinsTable, Cs2PinnedSkin>,
      ),
      Cs2PinnedSkin,
      PrefetchHooks Function()
    >;

class $SteamDatabaseManager {
  final _$SteamDatabase _db;
  $SteamDatabaseManager(this._db);
  $$SteamGamesTableTableManager get steamGames =>
      $$SteamGamesTableTableManager(_db, _db.steamGames);
  $$SteamPricePointsTableTableManager get steamPricePoints =>
      $$SteamPricePointsTableTableManager(_db, _db.steamPricePoints);
  $$Cs2MarketItemsTableTableManager get cs2MarketItems =>
      $$Cs2MarketItemsTableTableManager(_db, _db.cs2MarketItems);
  $$Cs2MarketPricePointsTableTableManager get cs2MarketPricePoints =>
      $$Cs2MarketPricePointsTableTableManager(_db, _db.cs2MarketPricePoints);
  $$Cs2PinnedSkinsTableTableManager get cs2PinnedSkins =>
      $$Cs2PinnedSkinsTableTableManager(_db, _db.cs2PinnedSkins);
}
