import 'dart:math' as math;

import 'sim/hub.dart';

/// One aircraft the airline owns or leases.
class OwnedAircraft {
  OwnedAircraft({
    required this.id,
    required this.registration,
    required this.modelId,
    required this.purchasedDay,
    this.leased = false,
    this.blockHours = 0,
    this.condition = 1,
    this.routeId,
    this.groundedUntilDay = 0,
  });

  final String id;
  final String registration;
  final String modelId;
  final int purchasedDay;

  /// Leased frames cost a daily fee instead of a purchase price, and cannot
  /// be sold — they are handed back.
  final bool leased;

  double blockHours;

  /// 1.0 is factory-fresh. Wear raises maintenance and, below 0.6, starts
  /// costing load factor.
  double condition;

  String? routeId;

  /// Day this aircraft returns from a heavy check. Zero means available.
  int groundedUntilDay;

  bool isGrounded(int day) => day < groundedUntilDay;

  Map<String, Object?> toJson() => {
        'id': id,
        'reg': registration,
        'model': modelId,
        'bought': purchasedDay,
        'leased': leased,
        'hours': blockHours,
        'condition': condition,
        'route': routeId,
        'grounded': groundedUntilDay,
      };

  static OwnedAircraft? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final model = json['model'];
    if (id is! String || model is! String) return null;
    return OwnedAircraft(
      id: id,
      registration: json['reg'] as String? ?? id,
      modelId: model,
      purchasedDay: (json['bought'] as num?)?.round() ?? 0,
      leased: json['leased'] as bool? ?? false,
      blockHours: (json['hours'] as num?)?.toDouble() ?? 0,
      condition: (json['condition'] as num?)?.toDouble() ?? 1,
      routeId: json['route'] as String?,
      groundedUntilDay: (json['grounded'] as num?)?.round() ?? 0,
    );
  }
}

/// A served destination. Every route runs out of the single home hub.
class AirlineRoute {
  AirlineRoute({
    required this.id,
    required this.destIata,
    required this.fareEur,
    required this.openedDay,
    this.active = true,
    List<int>? profitHistory,
  }) : profitHistory = profitHistory ?? <int>[];

  final String id;
  final String destIata;
  final int openedDay;

  /// One-way economy fare in euros. The only price lever in the game.
  int fareEur;

  bool active;

  /// Recent daily profit, newest last, capped at [historyLength].
  final List<int> profitHistory;

  static const int historyLength = 14;

  void recordProfit(int value) {
    profitHistory.add(value);
    if (profitHistory.length > historyLength) {
      profitHistory.removeRange(0, profitHistory.length - historyLength);
    }
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'dest': destIata,
        'fare': fareEur,
        'opened': openedDay,
        'active': active,
        'history': profitHistory,
      };

  static AirlineRoute? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final dest = json['dest'];
    if (id is! String || dest is! String) return null;
    return AirlineRoute(
      id: id,
      destIata: dest,
      fareEur: (json['fare'] as num?)?.round() ?? 100,
      openedDay: (json['opened'] as num?)?.round() ?? 0,
      active: json['active'] as bool? ?? true,
      profitHistory: [
        for (final v in (json['history'] as List? ?? const []))
          if (v is num) v.round(),
      ],
    );
  }
}

/// One day's books, kept for the finance chart.
class DayRecord {
  const DayRecord({
    required this.day,
    required this.revenueEur,
    required this.costEur,
    required this.cashEur,
  });

  final int day;
  final int revenueEur;
  final int costEur;
  final int cashEur;

  int get profitEur => revenueEur - costEur;

  Map<String, Object?> toJson() => {
        'd': day,
        'r': revenueEur,
        'c': costEur,
        'k': cashEur,
      };

  static DayRecord? fromJson(Map<String, Object?> json) {
    final day = json['d'];
    if (day is! num) return null;
    return DayRecord(
      day: day.round(),
      revenueEur: (json['r'] as num?)?.round() ?? 0,
      costEur: (json['c'] as num?)?.round() ?? 0,
      cashEur: (json['k'] as num?)?.round() ?? 0,
    );
  }
}

/// What happened on one simulated day. Session-only — never persisted.
class DayReport {
  const DayReport({
    required this.day,
    required this.revenueEur,
    required this.cargoEur,
    required this.fuelEur,
    required this.crewEur,
    required this.landingEur,
    required this.maintenanceEur,
    required this.upkeepEur,
    required this.leaseEur,
    required this.passengers,
    required this.flights,
    required this.offline,
    this.events = const [],
  });

  final int day;
  final int revenueEur;
  final int cargoEur;
  final int fuelEur;
  final int crewEur;
  final int landingEur;
  final int maintenanceEur;
  final int upkeepEur;
  final int leaseEur;
  final int passengers;
  final int flights;
  final bool offline;
  final List<String> events;

  int get incomeEur => revenueEur + cargoEur;

  int get costEur =>
      fuelEur + crewEur + landingEur + maintenanceEur + upkeepEur + leaseEur;

  int get profitEur => incomeEur - costEur;
}

/// Summary of the days that passed while the app was closed.
class AwayReport {
  const AwayReport({
    required this.daysSimulated,
    required this.daysElapsed,
    required this.awayFor,
    required this.incomeEur,
    required this.costEur,
    required this.netProfitEur,
    required this.passengers,
    required this.rate,
    this.events = const [],
  });

  final int daysSimulated;
  final int daysElapsed;
  final Duration awayFor;
  final int incomeEur;
  final int costEur;
  final int netProfitEur;
  final int passengers;

  /// The share of a full day's trading an offline day paid.
  final double rate;

  final List<String> events;

  /// Whether time was lost to the offline cap.
  bool get capped => daysElapsed > daysSimulated;
}

/// Everything that survives closing the app.
class AirlineGameState {
  AirlineGameState({
    required this.airlineName,
    required this.hubIata,
    this.cashEur = startingCashEur,
    this.day = 1,
    this.gridSize = minGridSize,
    this.gameSpeed = 1,
    this.autoConfirmDay = true,
    this.lastSeenEpochMs = 0,
    this.flightsFlownEver = 0,
    this.passengersCarriedEver = 0,
    this.nextId = 1,
    List<PlacedBuilding>? buildings,
    List<OwnedAircraft>? fleet,
    List<AirlineRoute>? routes,
    List<DayRecord>? history,
  })  : buildings = buildings ?? <PlacedBuilding>[],
        fleet = fleet ?? <OwnedAircraft>[],
        routes = routes ?? <AirlineRoute>[],
        history = history ?? <DayRecord>[];

  static const int startingCashEur = 25000000;
  static const int minGridSize = 12;
  static const int maxGridSize = 24;

  /// How many days of books the finance chart keeps. The save file is
  /// rewritten on every mutation, so this has to be bounded or it grows
  /// without limit.
  static const int historyLength = 90;

  /// Offline days pay this share of a full day's trading — costs included,
  /// so a loss-making airline is never rescued by being closed.
  static const double baseOfflineRate = 0.6;

  /// The most days a single absence can be worth.
  static const int maxOfflineDays = 12;

  static const List<int> gameSpeeds = [1, 2, 4];

  String airlineName;
  String hubIata;
  int cashEur;
  int day;
  int gridSize;
  int gameSpeed;
  bool autoConfirmDay;
  int lastSeenEpochMs;
  int flightsFlownEver;
  int passengersCarriedEver;

  /// Monotonic counter behind every generated aircraft and route id.
  int nextId;

  final List<PlacedBuilding> buildings;
  final List<OwnedAircraft> fleet;
  final List<AirlineRoute> routes;
  final List<DayRecord> history;

  /// Bumped on any change to [buildings], so the hub painter can decide
  /// whether to repaint without deep-comparing the list every frame.
  int hubRevision = 0;

  String takeId(String prefix) => '$prefix${nextId++}';

  void recordDay(DayRecord record) {
    history.add(record);
    if (history.length > historyLength) {
      history.removeRange(0, history.length - historyLength);
    }
  }

  /// Jet fuel price index for a given day, deterministic in [day].
  ///
  /// Deliberately a pure function of the day number rather than stored
  /// state: it keeps the whole day path reproducible, which is what lets the
  /// tests assert that two identical states simulate identically.
  static double fuelPriceIndexFor(int day) {
    final wobble = math.sin(day * 12.9898) * 43758.5453;
    final frac = wobble - wobble.floorToDouble();
    return 1 + (frac - 0.5) * 0.36;
  }

  double get fuelPriceIndex => fuelPriceIndexFor(day);

  AirlineRoute? routeById(String? id) {
    if (id == null) return null;
    for (final route in routes) {
      if (route.id == id) return route;
    }
    return null;
  }

  OwnedAircraft? aircraftById(String? id) {
    if (id == null) return null;
    for (final aircraft in fleet) {
      if (aircraft.id == id) return aircraft;
    }
    return null;
  }

  List<OwnedAircraft> aircraftOnRoute(String routeId) =>
      [for (final a in fleet) if (a.routeId == routeId) a];

  Map<String, Object?> toJson() => {
        'format': 1,
        'name': airlineName,
        'hub': hubIata,
        'cash': cashEur,
        'day': day,
        'grid': gridSize,
        'speed': gameSpeed,
        'autoConfirm': autoConfirmDay,
        'lastSeen': lastSeenEpochMs,
        'flightsEver': flightsFlownEver,
        'paxEver': passengersCarriedEver,
        'nextId': nextId,
        'buildings': [for (final b in buildings) b.toJson()],
        'fleet': [for (final a in fleet) a.toJson()],
        'routes': [for (final r in routes) r.toJson()],
        'history': [for (final h in history) h.toJson()],
      };

  /// Rebuilds a state from a save. Every optional field falls back, so a save
  /// written by an older build never throws — it just loses what it lacked.
  static AirlineGameState fromJson(Map<String, Object?> json) {
    List<T> listOf<T>(Object? raw, T? Function(Map<String, Object?>) parse) {
      if (raw is! List) return <T>[];
      final out = <T>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final parsed = parse(Map<String, Object?>.from(item));
        if (parsed != null) out.add(parsed);
      }
      return out;
    }

    return AirlineGameState(
      airlineName: json['name'] as String? ?? 'luma air',
      hubIata: json['hub'] as String? ?? '',
      cashEur: (json['cash'] as num?)?.round() ?? startingCashEur,
      day: (json['day'] as num?)?.round() ?? 1,
      gridSize: ((json['grid'] as num?)?.round() ?? minGridSize)
          .clamp(minGridSize, maxGridSize),
      gameSpeed: (json['speed'] as num?)?.round() ?? 1,
      autoConfirmDay: json['autoConfirm'] as bool? ?? true,
      lastSeenEpochMs: (json['lastSeen'] as num?)?.round() ?? 0,
      flightsFlownEver: (json['flightsEver'] as num?)?.round() ?? 0,
      passengersCarriedEver: (json['paxEver'] as num?)?.round() ?? 0,
      nextId: (json['nextId'] as num?)?.round() ?? 1,
      buildings: listOf(json['buildings'], PlacedBuilding.fromJson),
      fleet: listOf(json['fleet'], OwnedAircraft.fromJson),
      routes: listOf(json['routes'], AirlineRoute.fromJson),
      history: listOf(json['history'], DayRecord.fromJson),
    );
  }
}
