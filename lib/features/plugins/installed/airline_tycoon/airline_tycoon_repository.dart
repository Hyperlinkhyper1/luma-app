import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show WidgetsBindingObserver, WidgetsBinding, AppLifecycleState;

import 'package:path_provider/path_provider.dart';

import '../../../../storage/storage_guard.dart';
import 'airline_game_state.dart';
import 'data/aircraft.dart';
import 'data/airport_catalog.dart';
import 'data/buildings.dart';
import 'sim/economy.dart';
import 'sim/geo.dart';
import 'sim/hub.dart';
import 'sim/airport_world.dart';

/// The outcome of a player action: either it happened, or it did not and
/// there is a sentence explaining why.
class ActionResult {
  const ActionResult.ok() : success = true, message = null;
  const ActionResult.failed(this.message) : success = false;

  final bool success;
  final String? message;
}

/// Owns the whole game: the day clock, every player action, and persistence.
///
/// Shaped after `server_tycoon_repository.dart`, which is the house pattern
/// for a simulation plugin here — a `ChangeNotifier` over a plain mutable
/// state object, saved to a JSON file in the documents directory.
class AirlineTycoonRepository extends ChangeNotifier
    with WidgetsBindingObserver {
  AirlineTycoonRepository({
    AirlineGameState? initialState,
    bool autoStart = true,
    this.airportMode = false,
  }) : _state = initialState ?? AirlineGameState(airlineName: '', hubIata: '') {
    if (initialState != null) _loaded = true;
    if (airportMode) WidgetsBinding.instance.addObserver(this);
    if (autoStart) unawaited(_boot());
  }

  static const String saveFileName = 'airline_tycoon_save.json';
  static const String airportSaveFileName = 'airline_tycoon_airport_v2.json';
  final bool airportMode;
  AirportWorld? _airportWorld;
  AirportWorld? get airportWorld => _airportWorld;
  Future<void> _pendingSave = Future.value();
  int _lastCheckpointMs = 0;
  String? airportSaveError;
  bool _airportSuspended = false;

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
  bool get isPaused =>
      airportMode ? (_airportWorld?.paused ?? true) : _userPaused;
  DayReport? get lastDayReport => _lastDayReport;
  AwayReport? get lastAwayReport => _lastAwayReport;

  /// True once a hub has been picked — before that the page shows setup.
  bool get hasGame => _state.hubIata.isNotEmpty;

  /// Fraction of the current day elapsed, for the progress ring.
  double get dayProgress => airportMode
      ? ((_airportWorld?.time ?? 0) % 1440) / 1440
      : (_secondsElapsed / dayLengthSeconds).clamp(0.0, 1.0).toDouble();

  Airport? get hubAirport => _catalog?.byIata(_state.hubIata);

  /// Hub effects, recomputed only when the layout actually changes.
  HubEffects get hubEffects {
    if (airportMode && _airportWorld != null) return _airportWorld!.effects;
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
    if (airportMode) {
      await _loadAirport();
      _loaded = true;
      if (hasGame && _airportWorld != null) {
        _catchUpAirport();
        if (!isPaused) _startDayTimer();
      }
      notifyListeners();
      return;
    }
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
    if (airportMode) return flushAirport();
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
    if (airportMode) {
      WidgetsBinding.instance.removeObserver(this);
      unawaited(flushAirport());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!airportMode) return;
    if (state == AppLifecycleState.resumed) {
      if (!_airportSuspended) return;
      _airportSuspended = false;
      _catchUpAirport();
      if (hasGame && !isPaused) _startDayTimer();
      notifyListeners();
    } else if (!_airportSuspended) {
      _airportSuspended = true;
      _dayTimer?.cancel();
      _dayTimer = null;
      unawaited(flushAirport());
    }
  }

  // ── Day clock ───────────────────────────────────────────────────────

  void _startDayTimer() {
    _dayTimer?.cancel();
    _dayTimer = Timer.periodic(
      Duration(milliseconds: airportMode ? 200 : 1000),
      (_) => _tick(),
    );
  }

  /// Stops the clock. Tests call this so days cannot roll mid-assertion.
  void pause() {
    _userPaused = true;
    if (airportMode && _airportWorld != null) {
      _airportWorld!.paused = true;
      unawaited(flushAirport());
    }
    _dayTimer?.cancel();
    _dayTimer = null;
    notifyListeners();
  }

  void resume() {
    _userPaused = false;
    if (airportMode && _airportWorld != null) {
      _airportWorld!.paused = false;
      unawaited(flushAirport());
    }
    if (hasGame) _startDayTimer();
    notifyListeners();
  }

  void setSpeed(int speed) {
    if (airportMode) {
      if (![1, 4, 12].contains(speed) || _airportWorld == null) return;
      _airportWorld!.speed = speed;
      _state.gameSpeed = speed;
      unawaited(flushAirport());
      notifyListeners();
      return;
    }
    if (!AirlineGameState.gameSpeeds.contains(speed)) return;
    _state.gameSpeed = speed;
    unawaited(_save());
    notifyListeners();
  }

  void _tick() {
    if (airportMode) {
      final world = _airportWorld;
      if (world == null || world.paused || _catalog == null) return;
      world.advance(.2 * world.speed, _state, _catalog!);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastCheckpointMs >= 10000) {
        _lastCheckpointMs = now;
        unawaited(flushAirport());
      }
      notifyListeners();
      return;
    }
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
    if (airportMode) {
      _catchUpAirport();
      return;
    }
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
    if (airportMode) {
      if (_airportWorld != null && _catalog != null) {
        _airportWorld!.advance(1440, _state, _catalog!);
        unawaited(flushAirport());
        notifyListeners();
      }
      return null;
    }
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
        if (Economy.blocker(model: model, distanceKm: distance, hub: effects) !=
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
        aircraft.condition = (aircraft.condition - flownHours * 0.000025).clamp(
          0.0,
          1.0,
        );

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
    _state.recordDay(
      DayRecord(
        day: report.day,
        revenueEur: report.incomeEur,
        costEur: report.costEur,
        cashEur: _state.cashEur,
      ),
    );

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

    if (airportMode) {
      _dayTimer?.cancel();
      _dayTimer = null;
      _airportWorld = AirportWorld.starter();
      _state.fleet.add(
        OwnedAircraft(
          id: _state.takeId('ac'),
          registration: _registration(_state.nextId),
          modelId: 'atr72',
          purchasedDay: 1,
        ),
      );
      _userPaused = true;
      unawaited(flushAirport());
      notifyListeners();
      return;
    }

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

    _state.fleet.add(
      OwnedAircraft(
        id: _state.takeId('ac'),
        registration: _registration(_state.nextId),
        modelId: 'atr72',
        purchasedDay: 1,
      ),
    );

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
    if (airportMode && _state.cashEur < 0) {
      return const ActionResult.failed(
        'Restore a positive balance before acquiring aircraft.',
      );
    }
    if (!lease && _state.cashEur < model.priceEur) {
      return const ActionResult.failed('Not enough cash for that aircraft.');
    }
    if (lease && _state.cashEur < model.leasePerDayEur * 7) {
      return const ActionResult.failed(
        'You need at least a week of lease payments in the bank first.',
      );
    }
    if (!lease) {
      if (airportMode && _airportWorld != null) {
        _airportWorld!.recordTransaction(
          _state,
          'fleet',
          -model.priceEur,
          'Purchased ${model.name}',
        );
      } else {
        _state.cashEur -= model.priceEur;
      }
    }

    _state.fleet.add(
      OwnedAircraft(
        id: _state.takeId('ac'),
        registration: _registration(_state.nextId),
        modelId: model.id,
        purchasedDay: _state.day,
        leased: lease,
      ),
    );
    unawaited(_save());
    notifyListeners();
    return const ActionResult.ok();
  }

  ActionResult releaseAircraft(String aircraftId) {
    if (airportMode &&
        (_airportWorld?.flights.any(
              (f) => f.aircraftId == aircraftId && !f.finished,
            ) ??
            false)) {
      return const ActionResult.failed(
        'Cancel scheduled flights and wait for this aircraft to return before releasing it.',
      );
    }
    final aircraft = _state.aircraftById(aircraftId);
    if (aircraft == null) return const ActionResult.failed('No such aircraft.');
    final model = aircraftModelById(aircraft.modelId);
    if (!aircraft.leased && model != null) {
      final price = model.resaleValueEur(aircraft.blockHours);
      if (airportMode && _airportWorld != null) {
        _airportWorld!.recordTransaction(
          _state,
          'fleet',
          price,
          'Sold ${aircraft.registration}',
        );
      } else {
        _state.cashEur += price;
      }
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
    final blocker = Economy.blocker(
      model: model,
      distanceKm: distance,
      hub: hubEffects,
    );
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

  int get activeRouteCount => _state.routes.where((r) => r.active).length;

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
    if (!airportMode && activeRouteCount >= effects.activeGates) {
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
    if (airportMode && _airportWorld != null) {
      _airportWorld!.recordTransaction(
        _state,
        'routes',
        -launchCost,
        'Opened route to ${dest.iata}',
      );
    } else {
      _state.cashEur -= launchCost;
    }

    _state.routes.add(
      AirlineRoute(
        id: _state.takeId('rt'),
        destIata: dest.iata,
        fareEur: Economy.fairFareEur(distance).round(),
        openedDay: _state.day,
      ),
    );
    unawaited(_save());
    notifyListeners();
    return const ActionResult.ok();
  }

  void closeRoute(String routeId) {
    if (airportMode &&
        (_airportWorld?.flights.any(
              (f) =>
                  f.routeId == routeId && !f.finished && f.stage != 'scheduled',
            ) ??
            false)) {
      return;
    }
    if (airportMode && _airportWorld != null) {
      for (final f
          in _airportWorld!.flights
              .where((f) => f.routeId == routeId && f.stage == 'scheduled')
              .toList()) {
        _airportWorld!.cancelFlight(_state, f.id);
      }
    }
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

  ActionResult placeBuilding(
    BuildingKind kind,
    int x,
    int y, {
    int rotation = 0,
  }) {
    final def = buildingDef(kind);
    final candidate = PlacedBuilding(
      kind: kind,
      x: x,
      y: y,
      rotation: rotation,
    );
    final error = HubGrid.check(candidate, _state.gridSize, _state.buildings);
    if (error == PlacementError.outOfBounds) {
      return const ActionResult.failed('That does not fit on the field.');
    }
    if (error == PlacementError.overlaps) {
      return const ActionResult.failed('Something is already built there.');
    }
    if (_state.cashEur < def.costEur) {
      return ActionResult.failed(
        'A ${def.name.toLowerCase()} costs more '
        'than you have.',
      );
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

  Future<void> _loadAirport() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$airportSaveFileName');
      if (!await file.exists()) return;
      for (final candidate in [file, File('${file.path}.bak')]) {
        try {
          final json = jsonDecode(await candidate.readAsString()) as Map;
          if (json['format'] != 2) {
            throw const FormatException('Unknown save version');
          }
          final state = AirlineGameState.fromJson(
            Map<String, Object?>.from(json['airline'] as Map),
          );
          final world = AirportWorld.fromJson(
            Map<String, Object?>.from(json['airport'] as Map),
          );
          _state = state;
          _airportWorld = world;
          _userPaused = world.paused;
          return;
        } catch (_) {
          airportSaveError =
              'Could not read the airport save. The original file has been preserved.';
        }
      }
    } catch (_) {
      airportSaveError = 'Airport save storage is unavailable.';
    }
  }

  /// Serialized, atomic replacement, with one recovery copy. The legacy save
  /// has a different filename and is never opened for writing in airport mode.
  Future<void> flushAirport() {
    if (!airportMode || _airportWorld == null) return Future.value();
    final now = DateTime.now().millisecondsSinceEpoch;
    _state.lastSeenEpochMs = now;
    _airportWorld!.lastSeenEpochMs = now;
    final encoded = jsonEncode({
      'format': 2,
      'airline': _state.toJson(),
      'airport': _airportWorld!.toJson(),
    });
    _pendingSave = _pendingSave.then((_) async {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$airportSaveFileName');
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(encoded, flush: true);
        if (await file.exists()) await file.copy('${file.path}.bak');
        await temporary.rename(file.path);
        airportSaveError = null;
        StorageGuard.instance.scheduleRefresh();
      } catch (_) {
        airportSaveError =
            'Could not save this airport. Progress is still in memory; check available storage.';
      }
    });
    return _pendingSave;
  }

  void _catchUpAirport() {
    final world = _airportWorld, catalog = _catalog;
    if (world == null || catalog == null) return;
    final elapsedMs =
        DateTime.now().millisecondsSinceEpoch - world.lastSeenEpochMs;
    if (world.paused || world.lastSeenEpochMs <= 0 || elapsedMs <= 0) return;
    final elapsedMinutes = elapsedMs / 1000 * world.speed;
    final minutes = math.min(
      elapsedMinutes,
      AirlineGameState.maxOfflineDays * 1440.0,
    );
    final cash = _state.cashEur, pax = _state.passengersCarriedEver;
    world.advance(minutes, _state, catalog);
    final profit = _state.cashEur - cash;
    _lastAwayReport = AwayReport(
      daysSimulated: (minutes / 1440).floor(),
      daysElapsed: (elapsedMinutes / 1440).floor(),
      awayFor: Duration(milliseconds: elapsedMs),
      incomeEur: math.max(0, profit),
      costEur: math.max(0, -profit),
      netProfitEur: profit,
      passengers: _state.passengersCarriedEver - pax,
      rate: 1,
      events: ['Airport operations advanced ${minutes.round()} game minutes.'],
    );
    unawaited(flushAirport());
  }

  Map<String, Object?> airportSnapshot() {
    final world = _airportWorld;
    if (world == null) return {};
    final idleAircraft = <Map<String, Object?>>[];
    final parking = world.ofKind('hangar');
    for (final aircraft in _state.fleet) {
      if (world.flights.any(
        (f) =>
            f.aircraftId == aircraft.id &&
            !f.finished &&
            f.stage != 'scheduled',
      )) {
        continue;
      }
      if (parking.isEmpty) continue;
      final hangar = parking[idleAircraft.length % parking.length];
      idleAircraft.add({
        'id': 'parked-${aircraft.id}',
        'carrier': _state.airlineName,
        'modelId': aircraft.modelId,
        'stage': 'parked',
        'x': hangar.x - 5,
        'y': hangar.y - 25 - (idleAircraft.length ~/ parking.length) * 35,
        'z': 0,
        'heading': 0,
        'passengers': 0,
        'boarded': 0,
      });
    }
    return {
      ...world.toJson(),
      'facilities': [
        for (final f in world.facilities)
          {
            ...f.toJson(),
            'protected': world.protected(f),
            'upgradeCost': world.upgradeCost(f),
            'upgradeCosts': {
              for (final u in facilityUpgrades(f.kind))
                u.id: world.upgradeCost(f, u.id),
            },
            if (standKinds.contains(f.kind)) ...{
              'nose': world.standNose(f),
              'lane': world.standLane(f),
              'gateDoor': _door(world.boardingDoor(f)),
              'walk': world.boardingWalk(f),
            },
            if (f.kind == 'entrance' || f.kind == 'checkOut')
              'door': _door(world.entranceDoor(f)),
          },
      ],
      'idleAircraft': idleAircraft,
      'contracts': [
        for (final c in world.contracts)
          {
            ...c.toJson(),
            'cancelCost':
                (world.flights
                        .where(
                          (f) => f.contractId == c.id && f.stage == 'scheduled',
                        )
                        .length +
                    c.remaining) *
                c.offer.penalty,
            'scheduled': world.flights
                .where((f) => f.contractId == c.id && f.stage == 'scheduled')
                .length,
          },
      ],
      'cash': _state.cashEur,
      'day': world.day,
      'airlineName': _state.airlineName,
      'hubIata': _state.hubIata,
      'saveError': airportSaveError,
      'awayReport': _lastAwayReport == null
          ? null
          : {
              'minutes': _lastAwayReport!.events.isEmpty
                  ? ''
                  : _lastAwayReport!.events.first,
              'profit': _lastAwayReport!.netProfitEur,
              'passengers': _lastAwayReport!.passengers,
            },
      'offers': [
        for (final o in world.offers)
          {...o.toJson(), 'blockedReason': world.contractBlocker(o.id)},
      ],
      'rules': {
        'slots': {
          for (final e in airportSlots.entries) e.key: [e.value.$1, e.value.$2],
        },
        'haulMinutes': haulMinutes,
        'exitMinutes': slotExitMinutes,
        'horizonDays': planningHorizonDays,
      },
      'catalog': airportFacilities.map((d) => d.toJson()).toList(),
      'vehicleCosts': {
        for (final k in ['fuel', 'baggage', 'bus', 'pushback']) k: 120000,
      },
      'fleet': _state.fleet
          .map(
            (a) => {
              'id': a.id,
              'registration': a.registration,
              'modelId': a.modelId,
              'routeId': a.routeId,
            },
          )
          .toList(),
      'routes': _state.routes
          .map(
            (r) => {'id': r.id, 'destIata': r.destIata, 'fareEur': r.fareEur},
          )
          .toList(),
      'stats': {
        'activeFlights': world.flights
            .where((f) => !f.finished && f.stage != 'scheduled')
            .length,
        'passengers': _state.passengersCarriedEver,
        'flights': _state.flightsFlownEver,
        'connectedStands': world.stands.where((s) => s.connected).length,
        'upkeep': world.effects.upkeepPerDayEur,
      },
    };
  }

  static Map<String, Object?>? _door(
    ({List<double> door, List<double> kerb})? door,
  ) => door == null ? null : {'door': door.door, 'kerb': door.kerb};

  ActionResult airportCommand(String action, Map<String, Object?> args) {
    final world = _airportWorld;
    if (!airportMode || world == null) {
      return const ActionResult.failed('Start an airport first.');
    }
    String? error;
    String string(String name) =>
        args[name] is String ? args[name] as String : '';
    double number(String name) =>
        args[name] is num ? (args[name] as num).toDouble() : double.nan;
    try {
      switch (action) {
        case 'place':
          error = world.build(
            _state,
            string('kind'),
            number('x'),
            number('y'),
            args['rotation'] is num ? (args['rotation'] as num).toInt() : 0,
          );
        case 'move':
          final f = world.facility(string('facilityId'));
          if (f == null) {
            error = 'Select a building first.';
            break;
          }
          error = world.build(
            _state,
            f.kind,
            number('x'),
            number('y'),
            args['rotation'] is num
                ? (args['rotation'] as num).toInt()
                : f.rotation,
            moving: f.id,
          );
        case 'demolish':
          error = world.demolish(_state, string('facilityId'));
        case 'paintZone':
          error = world.paintZone(
            string('zone'),
            number('x'),
            number('y'),
            number('width'),
            number('depth'),
          );
        case 'upgrade':
          error = world.upgrade(
            _state,
            string('facilityId'),
            attribute: string('attribute'),
          );
        case 'buyVehicle':
          final depotArg = args['depotId'] is String
              ? args['depotId'] as String
              : args['facilityId'] is String
              ? args['facilityId'] as String
              : null;
          error = world.buyVehicle(_state, string('kind'), depotId: depotArg);
        case 'acceptContract':
          error = world.acceptContract(_state, string('offerId'));
        case 'cancelContract':
          error = world.cancelContract(_state, string('contractId'));
        case 'cancelFlight':
          error = world.cancelFlight(_state, string('flightId'));
        case 'reassignFlight':
          error = world.reassignFlight(string('flightId'), string('standId'));
        case 'moveFlight':
          error = world.moveFlight(
            string('flightId'),
            string('standId'),
            number('arrival'),
          );
        case 'unscheduleFlight':
          error = world.unscheduleFlight(string('flightId'));
        case 'placeContract':
          error = world.placeContract(
            string('contractId'),
            string('standId'),
            number('arrival'),
          );
        case 'schedule':
          if (_catalog == null) {
            return const ActionResult.failed('Airport catalog is unavailable.');
          }
          error = world.schedule(
            _state,
            _catalog!,
            aircraftId: string('aircraftId'),
            routeId: string('routeId'),
            departure: number('departure'),
            standId: string('standId'),
          );
        case 'speed':
          if (![1, 4, 12].contains(args['speed'])) {
            return const ActionResult.failed('Choose 1×, 4× or 12×.');
          }
          setSpeed((args['speed'] as num).toInt());
          return const ActionResult.ok();
        case 'pause':
          pause();
          return const ActionResult.ok();
        case 'resume':
          resume();
          return const ActionResult.ok();
        case 'dismissAway':
          clearAwayReport();
          return const ActionResult.ok();
        default:
          return const ActionResult.failed('Unknown airport command.');
      }
    } on ArgumentError {
      return const ActionResult.failed('Invalid airport command.');
    }
    if (error != null) return ActionResult.failed(error);
    unawaited(flushAirport());
    notifyListeners();
    return const ActionResult.ok();
  }

  /// Snapshot for the sync service.
  Future<Object?> exportData() async => airportMode
      ? {
          'format': 2,
          'airline': _state.toJson(),
          'airport': _airportWorld?.toJson(),
          'lastSeen': _state.lastSeenEpochMs,
        }
      : _state.toJson();

  /// Restores a snapshot from another device.
  ///
  /// The day clock runs independently on every device, so a plain
  /// last-write-wins would let a stale snapshot roll the airline backwards.
  /// A snapshot is only taken when it is *newer* than what is here; otherwise
  /// this device keeps its own state and wins the next push.
  Future<void> importData(Object? data) async {
    if (data is! Map) return;
    if (airportMode) {
      if (data['format'] != 2 ||
          data['airport'] is! Map ||
          data['airline'] is! Map) {
        return;
      }
      final incoming = AirlineGameState.fromJson(
        Map<String, Object?>.from(data['airline'] as Map),
      );
      if (incoming.lastSeenEpochMs <= _state.lastSeenEpochMs) return;
      final world = AirportWorld.fromJson(
        Map<String, Object?>.from(data['airport'] as Map),
      );
      _dayTimer?.cancel();
      _state = incoming;
      _airportWorld = world;
      _userPaused = world.paused;
      await flushAirport();
      if (!world.paused) _startDayTimer();
      notifyListeners();
      return;
    }
    if (data['format'] == 2) return;
    final incoming = AirlineGameState.fromJson(Map<String, Object?>.from(data));
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
