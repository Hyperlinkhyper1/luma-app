import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:path_provider/path_provider.dart';

import '../../../../storage/storage_guard.dart';
import 'airline_game_state.dart';
import 'data/aircraft.dart';
import 'data/airport_catalog.dart';
import 'data/buildings.dart';
import 'sim/economy.dart';
import 'sim/geo.dart';
import 'sim/hub.dart';

/// The outcome of a player action: either it happened, or it did not and
/// there is a sentence explaining why.
class ActionResult {
  const ActionResult.ok()
      : success = true,
        message = null;
  const ActionResult.failed(this.message) : success = false;

  final bool success;
  final String? message;
}

/// Owns the whole game: the day clock, every player action, and persistence.
///
/// Shaped after `server_tycoon_repository.dart`, which is the house pattern
/// for a simulation plugin here — a `ChangeNotifier` over a plain mutable
/// state object, saved to a JSON file in the documents directory.
class AirlineTycoonRepository extends ChangeNotifier {
  AirlineTycoonRepository({AirlineGameState? initialState, bool autoStart = true})
      : _state = initialState ?? AirlineGameState(airlineName: '', hubIata: '') {
    if (initialState != null) _loaded = true;
    if (autoStart) unawaited(_boot());
  }

  static const String saveFileName = 'airline_tycoon_save.json';

  /// Real seconds one in-game day takes at 1x speed.
  static const int dayLengthSeconds = 24;

  /// Wall-clock a closed app trades for one simulated day. Far slower than
  /// the live day on purpose: checking back a couple of times a day should be
  /// worth something without making actually playing pointless.
  static const int offlineMsPerDay = 10 * 60 * 1000;

  /// Block hours between heavy checks, and how long one grounds an aircraft.
  static const double checkIntervalHours = 3000;
  static const int checkGroundDays = 3;

  AirlineGameState _state;
  AirportCatalog? _catalog;
  Timer? _dayTimer;
  DayReport? _lastDayReport;
  AwayReport? _lastAwayReport;
  HubEffects? _cachedEffects;
  int _effectsRevision = -1;
  double _secondsElapsed = 0;
  bool _loaded = false;
  bool _userPaused = false;

  AirlineGameState get state => _state;
  AirportCatalog? get catalog => _catalog;
  bool get isLoaded => _loaded;
  bool get isPaused => _userPaused;
  DayReport? get lastDayReport => _lastDayReport;
  AwayReport? get lastAwayReport => _lastAwayReport;

  /// True once a hub has been picked — before that the page shows setup.
  bool get hasGame => _state.hubIata.isNotEmpty;

  /// Fraction of the current day elapsed, for the progress ring.
  double get dayProgress =>
      (_secondsElapsed / dayLengthSeconds).clamp(0.0, 1.0).toDouble();

  Airport? get hubAirport => _catalog?.byIata(_state.hubIata);

  /// Hub effects, recomputed only when the layout actually changes.
  HubEffects get hubEffects {
    if (_cachedEffects == null || _effectsRevision != _state.hubRevision) {
      _cachedEffects = HubGrid.resolve(_state.buildings);
      _effectsRevision = _state.hubRevision;
    }
    return _cachedEffects!;
  }

  /// The share of a normal day's business an offline day pays out.
  double get offlineRate => AirlineGameState.baseOfflineRate;

  // ── Lifecycle ───────────────────────────────────────────────────────

  Future<void> _boot() async {
    _catalog = await AirportCatalog.load();
    await _load();
    _loaded = true;
    if (hasGame) {
      catchUpOnAwayTime();
      _startDayTimer();
    }
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$saveFileName');
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map<String, Object?>) {
        _state = AirlineGameState.fromJson(raw);
        _effectsRevision = -1;
      }
    } catch (_) {
      // A corrupt or unreadable save must not take the plugin down with it;
      // the player starts fresh instead.
    }
  }

  Future<void> _save() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$saveFileName');
      await file.writeAsString(jsonEncode(_state.toJson()));
      StorageGuard.instance.scheduleRefresh();
    } catch (_) {
      // Ignore save failures: losing a day is better than crashing mid-play.
    }
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    super.dispose();
  }

  // ── Day clock ───────────────────────────────────────────────────────

  void _startDayTimer() {
    _dayTimer?.cancel();
    _dayTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Stops the clock. Tests call this so days cannot roll mid-assertion.
  void pause() {
    _userPaused = true;
    _dayTimer?.cancel();
    _dayTimer = null;
    notifyListeners();
  }

  void resume() {
    _userPaused = false;
    if (hasGame) _startDayTimer();
    notifyListeners();
  }

  void setSpeed(int speed) {
    if (!AirlineGameState.gameSpeeds.contains(speed)) return;
    _state.gameSpeed = speed;
    unawaited(_save());
    notifyListeners();
  }

  void _tick() {
    if (_userPaused || !hasGame) return;
    _secondsElapsed += _state.gameSpeed;
    if (_secondsElapsed >= dayLengthSeconds) {
      _secondsElapsed = 0;
      processDay();
    }
    notifyListeners();
  }

  /// Simulates the days that passed while the app was closed, capped at
  /// [AirlineGameState.maxOfflineDays], and stashes an [AwayReport] for the
  /// UI. Public only so tests can drive it without a real save file.
  @visibleForTesting
  void catchUpOnAwayTime() {
    final lastSeen = _state.lastSeenEpochMs;
    _state.lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch;
    // First run: there is no "away" to pay for, only a stamp to set.
    if (lastSeen <= 0) return;

    final elapsedMs = _state.lastSeenEpochMs - lastSeen;
    // A clock that moved backwards (timezone change, manual set) must never
    // pay out; treat it as no time having passed.
    if (elapsedMs <= 0) return;

    final elapsedDays = elapsedMs ~/ offlineMsPerDay;
    if (elapsedDays <= 0) return;

    final daysToRun = math.min(elapsedDays, AirlineGameState.maxOfflineDays);
    final cashBefore = _state.cashEur;
    var income = 0;
    var cost = 0;
    var passengers = 0;
    final events = <String>[];

    for (var i = 0; i < daysToRun; i++) {
      final report = processDay(offline: true);
      if (report == null) break;
      income += report.incomeEur;
      cost += report.costEur;
      passengers += report.passengers;
      events.addAll(report.events);
    }

    _lastAwayReport = AwayReport(
      daysSimulated: daysToRun,
      daysElapsed: elapsedDays,
      awayFor: Duration(milliseconds: elapsedMs),
      incomeEur: income,
      costEur: cost,
      netProfitEur: _state.cashEur - cashBefore,
      passengers: passengers,
      rate: offlineRate,
      events: events.take(6).toList(),
    );
  }

  void clearAwayReport() {
    _lastAwayReport = null;
    notifyListeners();
  }

  void clearDayReport() {
    _lastDayReport = null;
    notifyListeners();
  }

  // ── The day itself ──────────────────────────────────────────────────

  /// Trades one day and returns the books, or null if the game is not ready.
  ///
  /// An offline day is a fraction of a day's trading *including costs*, so a
  /// thin-margin airline can never be bankrupted faster while away than it
  /// would have been while being played.
  DayReport? processDay({bool offline = false}) {
    final catalog = _catalog;
    final hub = hubAirport;
    if (catalog == null || hub == null) return null;

    final rate = offline ? offlineRate : 1.0;
    final effects = hubEffects;
    final fuelIndex = _state.fuelPriceIndex;
    final events = <String>[];

    var revenue = 0.0;
    var cargo = 0.0;
    var fuel = 0.0;
    var crew = 0.0;
    var landing = 0.0;
    var maintenance = 0.0;
    var passengers = 0;
    var flights = 0;

    // A gate is what lets a route run at all, so if gates were demolished
    // the newest routes stop flying rather than the whole schedule breaking.
    final flying = _state.routes.where((r) => r.active).toList()
      ..sort((a, b) => a.openedDay.compareTo(b.openedDay));
    final operating = flying.take(math.max(0, effects.activeGates)).toList();

    for (final route in operating) {
      final dest = catalog.byIata(route.destIata);
      if (dest == null) continue;
      final distance = hub.distanceToKm(dest);
      var remainingDemand = Economy.demandPerDay(
        catchmentA: hub.catchment,
        catchmentB: dest.catchment,
        distanceKm: distance,
        rivalRoutes: 0,
      );

      var routeProfit = 0.0;

      for (final aircraft in _state.aircraftOnRoute(route.id)) {
        if (aircraft.isGrounded(_state.day)) continue;
        final model = aircraftModelById(aircraft.modelId);
        if (model == null) continue;
        if (Economy.blocker(
              model: model,
              distanceKm: distance,
              hub: effects,
            ) !=
            null) {
          continue;
        }

        final blockHours = Geo.blockHours(distance, model.cruiseKmh);
        final rotations = Economy.rotationsPerDay(blockHours);
        if (rotations == 0) continue;

        // A worn cabin sells less well; the factor never quite reaches zero.
        final conditionPenalty = aircraft.condition < 0.6
            ? 1 - (0.6 - aircraft.condition) * 0.5
            : 1.0;

        final legs = rotations * 2;
        for (var leg = 0; leg < legs; leg++) {
          final result = Economy.flight(
            model: model,
            distanceKm: distance,
            fareEur: route.fareEur.toDouble(),
            availableDemand: remainingDemand * conditionPenalty,
            fuelPriceIndex: fuelIndex,
            hub: effects,
          );
          remainingDemand -= result.passengers;
          if (remainingDemand < 0) remainingDemand = 0;

          revenue += result.revenueEur * rate;
          cargo += result.cargoEur * rate;
          fuel += result.fuelEur * rate;
          crew += result.crewEur * rate;
          landing += result.landingEur * rate;
          maintenance += result.maintenanceEur * rate;
          passengers += (result.passengers * rate).round();
          routeProfit += result.profitEur * rate;
          flights++;
        }

        final flownHours = blockHours * legs * rate;
        final before = aircraft.blockHours;
        aircraft.blockHours = before + flownHours;
        aircraft.condition =
            (aircraft.condition - flownHours * 0.000025).clamp(0.0, 1.0);

        // Heavy check falls due on crossing a multiple of the interval. It
        // grounds the aircraft rather than deleting anything, so the route
        // survives an absence that happened to span one.
        final checksBefore = (before / checkIntervalHours).floor();
        final checksAfter = (aircraft.blockHours / checkIntervalHours).floor();
        if (checksAfter > checksBefore) {
          aircraft.groundedUntilDay = _state.day + checkGroundDays;
          aircraft.condition = math.min(1, aircraft.condition + 0.35);
          final checkCost = model.maintPerHourEur * 260;
          maintenance += checkCost;
          events.add(
            '${aircraft.registration} went in for a heavy check '
            '($checkGroundDays days).',
          );
        }
      }

      route.recordProfit(routeProfit.round());
    }

    final upkeep = effects.upkeepPerDayEur * rate;
    var lease = 0.0;
    for (final aircraft in _state.fleet) {
      if (!aircraft.leased) continue;
      final model = aircraftModelById(aircraft.modelId);
      if (model != null) lease += model.leasePerDayEur * rate;
    }

    final report = DayReport(
      day: _state.day,
      revenueEur: revenue.round(),
      cargoEur: cargo.round(),
      fuelEur: fuel.round(),
      crewEur: crew.round(),
      landingEur: landing.round(),
      maintenanceEur: maintenance.round(),
      upkeepEur: upkeep.round(),
      leaseEur: lease.round(),
      passengers: passengers,
      flights: flights,
      offline: offline,
      events: events,
    );

    _state.cashEur += report.profitEur;
    _state.flightsFlownEver += flights;
    _state.passengersCarriedEver += passengers;
    _state.day++;
    _state.lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch;
    _state.recordDay(DayRecord(
      day: report.day,
      revenueEur: report.incomeEur,
      costEur: report.costEur,
      cashEur: _state.cashEur,
    ));

    // An offline catch-up day must not leave a modal queued behind the ones
    // the player is about to see on screen.
    if (!offline) _lastDayReport = report;

    unawaited(_save());
    notifyListeners();
    return report;
  }

  // ── Starting a game ─────────────────────────────────────────────────

  /// The hubs offered at setup: big enough to be worth flying from, small
  /// enough that the first route is not free money.
  List<Airport> starterHubs() => _catalog?.starterHubs() ?? const [];

  void startGame({required String airlineName, required String hubIata}) {
    final name = airlineName.trim().isEmpty ? 'luma air' : airlineName.trim();
    _state = AirlineGameState(airlineName: name, hubIata: hubIata);
    _effectsRevision = -1;

    // A starter field: one terminal with two gates that already touch it, an
    // apron, and a runway long enough for the free turboprop. Everything the
    // player adds from here is their own doing.
    _state.buildings.addAll(const [
      PlacedBuilding(kind: BuildingKind.terminal, x: 5, y: 5),
      PlacedBuilding(kind: BuildingKind.gate, x: 4, y: 5),
      PlacedBuilding(kind: BuildingKind.gate, x: 4, y: 6),
      PlacedBuilding(kind: BuildingKind.apron, x: 7, y: 5),
      PlacedBuilding(kind: BuildingKind.apron, x: 7, y: 6),
      PlacedBuilding(kind: BuildingKind.runwayShort, x: 9, y: 3),
    ]);
    _state.hubRevision++;

    _state.fleet.add(OwnedAircraft(
      id: _state.takeId('ac'),
      registration: _registration(_state.nextId),
      modelId: 'atr72',
      purchasedDay: 1,
    ));

    _state.lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch;
    _userPaused = false;
    _secondsElapsed = 0;
    _startDayTimer();
    unawaited(_save());
    notifyListeners();
  }

  static String _registration(int seed) {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    final a = letters[(seed * 7) % letters.length];
    final b = letters[(seed * 13) % letters.length];
    final c = letters[(seed * 23) % letters.length];
    return 'PH-$a$b$c';
  }

  // ── Fleet actions ───────────────────────────────────────────────────

  ActionResult acquireAircraft(AircraftModel model, {required bool lease}) {
    if (!lease && _state.cashEur < model.priceEur) {
      return const ActionResult.failed('Not enough cash for that aircraft.');
    }
    if (lease && _state.cashEur < model.leasePerDayEur * 7) {
      return const ActionResult.failed(
        'You need at least a week of lease payments in the bank first.',
      );
    }
    if (!lease) _state.cashEur -= model.priceEur;

    _state.fleet.add(OwnedAircraft(
      id: _state.takeId('ac'),
      registration: _registration(_state.nextId),
      modelId: model.id,
      purchasedDay: _state.day,
      leased: lease,
    ));
    unawaited(_save());
    notifyListeners();
    return const ActionResult.ok();
  }

  ActionResult releaseAircraft(String aircraftId) {
    final aircraft = _state.aircraftById(aircraftId);
    if (aircraft == null) return const ActionResult.failed('No such aircraft.');
    final model = aircraftModelById(aircraft.modelId);
    if (!aircraft.leased && model != null) {
      _state.cashEur += model.resaleValueEur(aircraft.blockHours);
    }
    _state.fleet.removeWhere((a) => a.id == aircraftId);
    unawaited(_save());
    notifyListeners();
    return const ActionResult.ok();
  }

  ActionResult assignAircraft(String aircraftId, String? routeId) {
    final aircraft = _state.aircraftById(aircraftId);
    if (aircraft == null) return const ActionResult.failed('No such aircraft.');
    if (routeId == null) {
      aircraft.routeId = null;
      unawaited(_save());
      notifyListeners();
      return const ActionResult.ok();
    }

    final route = _state.routeById(routeId);
    final dest = _catalog?.byIata(route?.destIata);
    final hub = hubAirport;
    final model = aircraftModelById(aircraft.modelId);
    if (route == null || dest == null || hub == null || model == null) {
      return const ActionResult.failed('That route is not available.');
    }

    final distance = hub.distanceToKm(dest);
    final blocker =
        Economy.blocker(model: model, distanceKm: distance, hub: hubEffects);
    if (blocker == RouteBlocker.outOfRange) {
      return ActionResult.failed(
        '${model.name} cannot reach ${dest.city} — '
        '${distance.round()} km against ${model.rangeKm} km of range.',
      );
    }
    if (blocker == RouteBlocker.runwayTooShort) {
      return ActionResult.failed(
        '${model.name} needs ${model.minRunwayM} m of runway; your longest '
        'is ${hubEffects.maxRunwayM} m.',
      );
    }

    aircraft.routeId = routeId;
    unawaited(_save());
    notifyListeners();
    return const ActionResult.ok();
  }

  // ── Route actions ───────────────────────────────────────────────────

  int get activeRouteCount =>
      _state.routes.where((r) => r.active).length;

  ActionResult openRoute(String destIata) {
    final hub = hubAirport;
    final dest = _catalog?.byIata(destIata);
    if (hub == null || dest == null) {
      return const ActionResult.failed('Unknown destination.');
    }
    if (dest.iata == hub.iata) {
      return const ActionResult.failed('That is your own hub.');
    }
    if (_state.routes.any((r) => r.destIata == dest.iata && r.active)) {
      return ActionResult.failed('You already fly to ${dest.city}.');
    }

    final effects = hubEffects;
    if (activeRouteCount >= effects.activeGates) {
      return ActionResult.failed(
        effects.inactiveGates > 0
            ? 'Every usable gate is taken. You have '
                '${effects.inactiveGates} gate(s) not touching a terminal — '
                'move them next to one to put them to work.'
            : 'You need another gate next to a terminal to add a route.',
      );
    }

    final distance = hub.distanceToKm(dest);
    final launchCost = (45000 + 12 * distance).round();
    if (_state.cashEur < launchCost) {
      return const ActionResult.failed('Not enough cash to launch the route.');
    }
    _state.cashEur -= launchCost;

    _state.routes.add(AirlineRoute(
      id: _state.takeId('rt'),
      destIata: dest.iata,
      fareEur: Economy.fairFareEur(distance).round(),
      openedDay: _state.day,
    ));
    unawaited(_save());
    notifyListeners();
    return const ActionResult.ok();
  }

  void closeRoute(String routeId) {
    _state.routes.removeWhere((r) => r.id == routeId);
    for (final aircraft in _state.fleet) {
      if (aircraft.routeId == routeId) aircraft.routeId = null;
    }
    unawaited(_save());
    notifyListeners();
  }

  void setFare(String routeId, int fareEur) {
    final route = _state.routeById(routeId);
    if (route == null) return;
    route.fareEur = fareEur.clamp(10, 100000);
    unawaited(_save());
    notifyListeners();
  }

  // ── Hub actions ─────────────────────────────────────────────────────

  ActionResult placeBuilding(BuildingKind kind, int x, int y, {int rotation = 0}) {
    final def = buildingDef(kind);
    final candidate =
        PlacedBuilding(kind: kind, x: x, y: y, rotation: rotation);
    final error =
        HubGrid.check(candidate, _state.gridSize, _state.buildings);
    if (error == PlacementError.outOfBounds) {
      return const ActionResult.failed('That does not fit on the field.');
    }
    if (error == PlacementError.overlaps) {
      return const ActionResult.failed('Something is already built there.');
    }
    if (_state.cashEur < def.costEur) {
      return ActionResult.failed('A ${def.name.toLowerCase()} costs more '
          'than you have.');
    }

    _state.cashEur -= def.costEur;
    _state.buildings.add(candidate);
    _state.hubRevision++;
    unawaited(_save());
    notifyListeners();
    return const ActionResult.ok();
  }

  /// Demolishes whatever covers [x], [y]. Half the build cost comes back.
  ActionResult demolishAt(int x, int y) {
    final building = HubGrid.at((x: x, y: y), _state.buildings);
    if (building == null) {
      return const ActionResult.failed('Nothing to demolish there.');
    }
    _state.buildings.remove(building);
    _state.cashEur += (building.def.costEur * 0.5).round();
    _state.hubRevision++;
    unawaited(_save());
    notifyListeners();
    return const ActionResult.ok();
  }

  int get expansionCostEur {
    final next = _state.gridSize + 2;
    if (next > AirlineGameState.maxGridSize) return 0;
    return (1200000 * math.pow(next - 10, 1.6)).round();
  }

  ActionResult expandField() {
    if (_state.gridSize >= AirlineGameState.maxGridSize) {
      return const ActionResult.failed('The field is already at its limit.');
    }
    final cost = expansionCostEur;
    if (_state.cashEur < cost) {
      return const ActionResult.failed('Not enough cash to buy more land.');
    }
    _state.cashEur -= cost;
    _state.gridSize += 2;
    _state.hubRevision++;
    unawaited(_save());
    notifyListeners();
    return const ActionResult.ok();
  }

  // ── Sync ────────────────────────────────────────────────────────────

  /// Snapshot for the sync service.
  Future<Object?> exportData() async => _state.toJson();

  /// Restores a snapshot from another device.
  ///
  /// The day clock runs independently on every device, so a plain
  /// last-write-wins would let a stale snapshot roll the airline backwards.
  /// A snapshot is only taken when it is *newer* than what is here; otherwise
  /// this device keeps its own state and wins the next push.
  Future<void> importData(Object? data) async {
    if (data is! Map) return;
    final incoming =
        AirlineGameState.fromJson(Map<String, Object?>.from(data));
    if (incoming.lastSeenEpochMs <= _state.lastSeenEpochMs) return;

    final wasRunning = _dayTimer != null;
    _dayTimer?.cancel();
    _dayTimer = null;
    _state = incoming;
    _effectsRevision = -1;
    _secondsElapsed = 0;
    await _save();
    if (wasRunning && hasGame && !_userPaused) _startDayTimer();
    notifyListeners();
  }

  /// Test seam: swaps the catalog in without touching `rootBundle`.
  @visibleForTesting
  void setCatalogForTest(AirportCatalog catalog) {
    _catalog = catalog;
    _loaded = true;
  }
}
