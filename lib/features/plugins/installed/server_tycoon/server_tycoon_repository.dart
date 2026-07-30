// Auto-ported from Roblox Server Hosting Tycoon
// Game logic repository: day processing, all player actions, persistence.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../storage/storage_guard.dart';
import 'data/boosts.dart';
import 'data/companies.dart';
import 'data/game_data.dart';
import 'data/missions.dart';
import 'data/research.dart';
import 'game_state.dart';
import 'sim/computer_sim.dart';
import 'sim/economy.dart';
import 'sim/service_sim.dart';

class ActionResult {
  final bool ok;
  final List<String>? errors;
  final String? warning;

  const ActionResult({required this.ok, this.errors, this.warning});
}

class ServerTycoonRepository extends ChangeNotifier {
  static const String _saveFileName = 'server_tycoon_save.json';
  static const int _maxOffersPerDay = 3;

  /// Real seconds in one in-game day at 1× speed.
  static const int dayLengthSeconds = 30;

  /// Wall-clock a closed app trades for one simulated day. Deliberately far
  /// slower than the live 30s day: checking back in a couple of times a day
  /// should be worth something without making play itself pointless.
  static const int offlineMsPerDay = 10 * 60 * 1000;

  GameState _state;
  List<ContractOffer> _contractOffers = [];
  final Set<String> _acceptedOfferIds = {};
  Timer? _dayTimer;
  DayReport? _lastDayReport;
  AwayReport? _lastAwayReport;
  String? _lastNotification;
  int _secondsElapsed = 0;
  bool _awaitingConfirmation = false;
  bool _userPaused = false;

  /// Per-day tallies backing the mission board. Reset at every rollover, and
  /// deliberately not persisted — a mission you were part-way through when you
  /// closed the app keeps the progress already written onto the Mission.
  final Map<MissionMetric, double> _todayCounters = {};

  // Live incidents -- session-only, not persisted (see ActiveIncident docs).
  final List<ActiveIncident> _activeIncidents = [];
  int _cooldownsUsedToday = 0;
  final math.Random _incidentRng = math.Random();
  static const double _incidentChancePerSecond = 0.03;
  static const int _maxConcurrentIncidents = 2;
  static const int _maxEmergencyCooldownsPerDay = 2;

  GameState get state => _state;
  List<ContractOffer> get contractOffers => List.unmodifiable(_contractOffers);
  DayReport? get lastDayReport => _lastDayReport;
  AwayReport? get lastAwayReport => _lastAwayReport;
  String? get lastNotification => _lastNotification;
  double get dayProgress => _secondsElapsed / dayLengthSeconds;
  int get secondsRemaining =>
      ((dayLengthSeconds - _secondsElapsed) / _state.gameSpeed).ceil();
  bool get awaitingConfirmation => _awaitingConfirmation;
  bool get isPaused => _userPaused;
  List<ActiveIncident> get activeIncidents => List.unmodifiable(_activeIncidents);

  /// Everything owned research currently grants, repeatable levels included.
  ResearchEffects get effects => getResearchEffects(
        _state.research,
        levels: _state.researchLevels,
      );

  BoostEffects get boostEffects => getBoostEffects(_state.activeBoosts);

  /// Research and boosts folded into the multipliers the sim understands.
  SimModifiers get simModifiers {
    final r = effects;
    final b = boostEffects;
    return SimModifiers(
      cpuCapacityMultiplier: (1 + r.cpuBoost) * b.capacityMultiplier,
      coolingMultiplier: (1 + r.coolingEfficiency) * b.coolingMultiplier,
      storageCompression: r.storageCompression,
      bandwidthOverhead: r.bandwidthOverhead,
      satisfactionBonus: r.satisfactionBonus,
      incomeMultiplier: (1 + r.incomeBonus) * b.incomeMultiplier,
    );
  }

  /// Research points earned at each day rollover.
  double get researchPointsPerDayNow {
    var serving = 0;
    for (final rig in _state.rigs.values) {
      if (rig.services.isNotEmpty) serving++;
    }
    return researchPointsPerDay(
      rigsServingTraffic: serving,
      rpPerDayBonus: effects.rpPerDayBonus,
      prestigeLevel: _state.prestigeLevel,
    );
  }

  /// The share of a normal day's business an offline day pays out.
  double get offlineRate =>
      (GameState.baseOfflineRate + effects.offlineRateBonus).clamp(0.0, 1.0).toDouble();

  ServerTycoonRepository() : _state = GameState.newDefault() {
    _ensureMissionBoard();
    _load();
    _startDayTimer();
  }

  void dispose() {
    _dayTimer?.cancel();
    super.dispose();
  }

  // ── Persistence ──

  Future<void> _load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_saveFileName');
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _state = GameState.fromJson(json);
        _regenerateContractOffers();
        catchUpOnAwayTime();
        _ensureMissionBoard();
        notifyListeners();
      }
    } catch (e) {
      // keep default state
    }
  }

  // ── Away earnings ──

  /// Simulates the days that passed while the app was closed, capped at
  /// [GameState.maxOfflineDays], and stashes an [AwayReport] for the UI.
  /// Public only so tests can drive it without a real save file.
  @visibleForTesting
  void catchUpOnAwayTime() {
    final lastSeen = _state.lastSeenEpochMs;
    _state.lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch;
    if (lastSeen <= 0) return;

    final elapsedMs = _state.lastSeenEpochMs - lastSeen;
    // A clock that moved backwards (timezone change, manual set) must never
    // pay out; treat it as no time having passed.
    if (elapsedMs <= 0) return;

    final elapsedDays = elapsedMs ~/ offlineMsPerDay;
    if (elapsedDays <= 0) return;

    final daysToRun = math.min(elapsedDays, GameState.maxOfflineDays);
    final rate = offlineRate;
    final moneyBefore = _state.money;
    var income = 0.0;
    var expenses = 0.0;
    var rpEarned = 0.0;
    final events = <String>[];

    for (var i = 0; i < daysToRun; i++) {
      final report = processDay(offline: true);
      if (report == null) break;
      income += report.income + report.contractIncome;
      expenses += report.electricityCost + report.internetCost + report.staffSalaryCost;
      rpEarned += report.researchPointsEarned;
      events.addAll(report.contractEvents);
      events.addAll(report.researchEvents);
    }

    _lastAwayReport = AwayReport(
      daysSimulated: daysToRun,
      daysElapsed: elapsedDays,
      awayFor: Duration(milliseconds: elapsedMs),
      income: income,
      expenses: expenses,
      netProfit: _state.money - moneyBefore,
      rate: rate,
      researchPointsEarned: rpEarned,
      events: events.take(6).toList(),
    );
  }

  void clearAwayReport() {
    _lastAwayReport = null;
    notifyListeners();
  }

  Future<void> _save() async {
    // Whole-state rewrite is the only persistence choke point this game has
    // (every action calls _save()) — over the cap, skip writing rather than
    // let an unawaited exception escape every fire-and-forget call site.
    if (StorageGuard.instance.isOverLimit) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_saveFileName');
      await file.writeAsString(jsonEncode(_state.toJson()));
      StorageGuard.instance.scheduleRefresh();
    } catch (e) {
      // ignore save errors
    }
  }

  // ── Day Timer ──

  void _startDayTimer() {
    _dayTimer?.cancel();
    _dayTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() => _dayTimer?.cancel();
  void resume() => _startDayTimer();

  /// The player-facing pause, distinct from [pause] — that one is the app
  /// lifecycle stopping the timer, this one survives until they press play.
  void setPaused(bool paused) {
    _userPaused = paused;
    notifyListeners();
  }

  void setGameSpeed(int speed) {
    if (!GameState.gameSpeeds.contains(speed)) return;
    _state.gameSpeed = speed;
    _save();
    notifyListeners();
  }

  void setAutoConfirmDay(bool value) {
    _state.autoConfirmDay = value;
    _save();
    notifyListeners();
  }

  void _tick() {
    if (_userPaused) return;
    if (_awaitingConfirmation) {
      // With auto-advance on, the day report is informational — roll straight
      // into the next day instead of waiting on a tap. Clearing it as we go
      // also means switching auto-advance off never surfaces a stale report.
      if (_state.autoConfirmDay) {
        _lastDayReport = null;
        confirmNextDay();
      }
      return;
    }
    _secondsElapsed += _state.gameSpeed;
    _maybeRollIncident();
    if (_secondsElapsed >= dayLengthSeconds) {
      _secondsElapsed = dayLengthSeconds;
      _awaitingConfirmation = true;
      processDay();
    } else {
      notifyListeners();
    }
  }

  void confirmNextDay() {
    _secondsElapsed = 0;
    _awaitingConfirmation = false;
    notifyListeners();
  }

  // ── Day Processing ──

  DayReport? processDay({bool offline = false}) {
    final load = calculateLoad();
    final effects = this.effects;
    final boosts = boostEffects;
    final staffEffects = getStaffEffects(_state.hiredStaffIds);

    // An offline day is a fraction of a day's trading, costs included, so a
    // thin-margin account can never be bankrupted faster while away than it
    // would have been while being played.
    final rate = offline ? offlineRate : 1.0;

    var totalWatts = 0.0;
    for (final entry in _state.rigs.entries) {
      final rigLoad = load.rigs[entry.key];
      if (rigLoad != null) {
        totalWatts += getActualPowerDrawWatts(entry.value.build, rigLoad.cpuLoadFactor);
      }
    }
    totalWatts *= boosts.powerMultiplier;

    final electricityPrice = Economy.getFluctuatedPrice(Economy.baseElectricityPricePerKWh, _state.dayCount);
    final totalElectricityDiscount = (effects.electricityDiscount + staffEffects.electricityDiscount).clamp(0, 1);
    final electricityCost =
        Economy.calculateElectricityCost(totalWatts, pricePerKWh: electricityPrice) * (1 - totalElectricityDiscount) * rate;
    final internetCost = _getDailyInternetCost() * rate;
    final (rawContractIncome, contractEvents, anyContractFailed) =
        _processContracts(load, offline: offline);
    final contractIncome =
        rawContractIncome * boosts.contractPayoutMultiplier * _state.incomeMultiplier * rate;

    var staffSalaryCost = 0.0;
    for (final id in _state.hiredStaffIds) {
      staffSalaryCost += staffDefsById[id]?.dailySalary ?? 0;
    }
    staffSalaryCost *= rate;

    var income = load.totalIncomePerDay * _state.incomeMultiplier * rate;
    final netProfit = income + contractIncome - electricityCost - internetCost - staffSalaryCost;

    _state.money += netProfit;
    _state.dayCount++;
    _state.peakPowerDrawWatts = math.max(_state.peakPowerDrawWatts, totalWatts);
    _state.totalMoneyEverEarned += income + contractIncome;
    _state.peakBandwidthServed = math.max(_state.peakBandwidthServed, load.totalRequiredBandwidth);
    _state.uptimeStreakDays = (!load.overloaded && !anyContractFailed) ? _state.uptimeStreakDays + 1 : 0;

    _pushHistory(_state.powerHistory, totalWatts);
    _pushHistory(_state.incomeHistory, netProfit);

    var avgSatisfaction = 0.0;
    if (load.instances.isNotEmpty) {
      var total = 0.0;
      for (final inst in load.instances) total += inst.satisfaction;
      avgSatisfaction = total / load.instances.length;
    } else {
      avgSatisfaction = Economy.reputationSatisfactionBaseline;
    }
    final repDelta = Economy.calculateReputationDelta(avgSatisfaction);
    _state.reputation = (_state.reputation + repDelta).clamp(Economy.reputationMin, Economy.reputationMax);

    // Incidents are for "the rest of the day" -- clear everything at rollover
    // except unresolved drive failures, which are a real hardware loss that
    // persists (via the Build mutation already made) until actually repaired.
    _activeIncidents.removeWhere((i) => i.type != IncidentType.driveFailure);
    _cooldownsUsedToday = 0;

    final rpEarned = researchPointsPerDayNow;
    final researchEvents = _advanceResearch(rpEarned);
    if (researchEvents.isNotEmpty) {
      _todayCounters[MissionMetric.researchCompleted] =
          (_todayCounters[MissionMetric.researchCompleted] ?? 0) + researchEvents.length;
    }
    final boostEvents = _tickBoosts();

    // Missions are scored against the day that just finished, then a fresh
    // board is rolled for the new one.
    final (missionEvents, missionRewardCash) = _settleMissions(
      netProfit: netProfit,
      bandwidthServed: load.totalRequiredBandwidth,
      overloaded: load.overloaded,
      offline: offline,
    );

    _state.lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch;
    _regenerateContractOffers();
    _checkAchievements();
    _save();

    final report = DayReport(
      day: _state.dayCount,
      income: income,
      contractIncome: contractIncome,
      contractEvents: contractEvents,
      electricityCost: electricityCost,
      internetCost: internetCost,
      staffSalaryCost: staffSalaryCost,
      netProfit: netProfit,
      avgSatisfaction: avgSatisfaction,
      reputation: _state.reputation,
      money: _state.money,
      overloaded: load.overloaded,
      researchEvents: researchEvents,
      missionEvents: missionEvents,
      boostEvents: boostEvents,
      researchPointsEarned: rpEarned,
      missionRewardCash: missionRewardCash,
    );
    _recentDays.add(report);
    while (_recentDays.length > GameState.historyLength) {
      _recentDays.removeAt(0);
    }
    // An offline catch-up day must not leave a report queued behind the
    // "Next Day" gate — the away summary covers the whole stretch instead.
    if (!offline) _lastDayReport = report;
    notifyListeners();
    return report;
  }

  /// Rolling log of finished days, for the stats sheet. Session-only: the
  /// persisted power/income histories are the durable record.
  final List<DayReport> _recentDays = [];
  List<DayReport> get recentDays => List.unmodifiable(_recentDays);

  /// Dismisses the pending end-of-day report so the modal can close.
  void clearDayReport() {
    _lastDayReport = null;
    notifyListeners();
  }

  // ── Research pipeline ──

  /// Banks the day's research points and pushes the queue along, spilling any
  /// surplus into the next project so a big rate never goes to waste.
  List<String> _advanceResearch(double rpEarned) {
    _state.researchPoints += rpEarned;
    final events = <String>[];
    _startNextQueuedResearch();

    // Bounded so a huge point balance can't spin here indefinitely.
    var guard = 0;
    while (_state.activeResearch != null && guard++ < 16) {
      final active = _state.activeResearch!;
      final remaining = active.rpNeeded - active.rpAccrued;
      if (_state.researchPoints < remaining) {
        active.rpAccrued += _state.researchPoints;
        _state.researchPoints = 0;
        break;
      }

      _state.researchPoints -= remaining;
      active.rpAccrued = active.rpNeeded;
      final project = researchById[active.projectId];
      if (project != null) {
        if (project.repeatable) {
          _state.researchLevels[project.id] = active.level + 1;
          events.add('Research complete: ${project.name} (level ${active.level + 1})');
        } else {
          _state.research.add(project.id);
          events.add('Research complete: ${project.name}');
        }
        _state.researchCompletedCount++;
      }
      _state.activeResearch = null;
      _startNextQueuedResearch();
    }
    return events;
  }

  void _startNextQueuedResearch() {
    if (_state.activeResearch != null) return;
    while (_state.researchQueue.isNotEmpty) {
      final id = _state.researchQueue.removeAt(0);
      final project = researchById[id];
      if (project == null) continue;
      final level = _state.researchLevels[id] ?? 0;
      _state.activeResearch = ResearchProgress(
        projectId: id,
        level: level,
        rpNeeded: project.rpCostAtLevel(level),
      );
      return;
    }
  }

  /// Level a project would be bought at right now, counting anything already
  /// in flight, so queueing two levels of a repeatable charges both prices.
  int pendingLevelFor(String projectId) {
    var level = _state.researchLevels[projectId] ?? 0;
    if (_state.activeResearch?.projectId == projectId) level++;
    for (final queued in _state.researchQueue) {
      if (queued == projectId) level++;
    }
    return level;
  }

  bool isResearchPending(String projectId) =>
      _state.activeResearch?.projectId == projectId || _state.researchQueue.contains(projectId);

  /// Days left on the active project at the current point rate.
  int get activeResearchDaysRemaining {
    final active = _state.activeResearch;
    if (active == null) return 0;
    final rate = researchPointsPerDayNow;
    if (rate <= 0) return 999;
    final remaining = (active.rpNeeded - active.rpAccrued - _state.researchPoints).clamp(0, double.infinity);
    return (remaining / rate).ceil();
  }

  int estimatedResearchDays(ResearchProject project) {
    final rate = researchPointsPerDayNow;
    if (rate <= 0) return 999;
    return (project.rpCostAtLevel(pendingLevelFor(project.id)) / rate).ceil();
  }

  /// Pays the cash cost and puts a project on the queue. It completes over the
  /// following days as research points accrue.
  ActionResult queueResearch(String researchId) {
    final project = researchById[researchId];
    if (project == null) return const ActionResult(ok: false, errors: ['Unknown research project']);

    final level = pendingLevelFor(researchId);
    if (!project.repeatable) {
      if (_state.research.contains(researchId)) {
        return const ActionResult(ok: false, errors: ['Already researched']);
      }
      if (isResearchPending(researchId)) {
        return const ActionResult(ok: false, errors: ['Already queued']);
      }
    } else if (level >= project.maxLevel) {
      return const ActionResult(ok: false, errors: ['Already at maximum level']);
    }

    for (final reqId in project.requires) {
      if (!_state.research.contains(reqId)) {
        final req = researchById[reqId];
        return ActionResult(ok: false, errors: ['Requires ${req?.name ?? reqId} first']);
      }
    }
    if (_state.reputation < project.minReputation) {
      return ActionResult(ok: false, errors: ['Requires ${project.minReputation} reputation']);
    }

    final queueSlots = effects.queueSlots;
    final inFlight = (_state.activeResearch == null ? 0 : 1) + _state.researchQueue.length;
    if (inFlight >= queueSlots) {
      return ActionResult(ok: false, errors: [
        queueSlots == 1
            ? 'Only one project at a time — build the R&D Lab branch for more queue slots'
            : 'All $queueSlots research slots are busy',
      ]);
    }

    final cost = project.costAtLevel(level);
    if (_state.money < cost) return ActionResult(ok: false, errors: ['Not enough money (needs \$$cost)']);

    _state.money -= cost;
    _state.researchQueue.add(researchId);
    _startNextQueuedResearch();
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  /// Cancels a queued or active project, refunding half the cash. Points
  /// already accrued are lost.
  ActionResult cancelResearch(String researchId) {
    final project = researchById[researchId];
    if (project == null) return const ActionResult(ok: false, errors: ['Unknown research project']);

    final queueIndex = _state.researchQueue.lastIndexOf(researchId);
    if (queueIndex >= 0) {
      _state.researchQueue.removeAt(queueIndex);
    } else if (_state.activeResearch?.projectId == researchId) {
      _state.activeResearch = null;
      _startNextQueuedResearch();
    } else {
      return const ActionResult(ok: false, errors: ['That project is not in progress']);
    }

    final refundLevel = _state.researchLevels[researchId] ?? 0;
    _state.money += project.costAtLevel(refundLevel) * 0.5;
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  // ── Boosts ──

  List<String> _tickBoosts() {
    final events = <String>[];
    for (var i = _state.activeBoosts.length - 1; i >= 0; i--) {
      final boost = _state.activeBoosts[i];
      boost.daysRemaining--;
      if (boost.daysRemaining <= 0) {
        events.add('${boost.def?.name ?? boost.defId} wore off');
        _state.activeBoosts.removeAt(i);
      }
    }
    return events;
  }

  ActionResult buyBoost(String boostId) {
    final def = boostDefsById[boostId];
    if (def == null) return const ActionResult(ok: false, errors: ['Unknown boost']);
    if (_state.money < def.cost) {
      return ActionResult(ok: false, errors: ['Not enough money (needs \$${def.cost})']);
    }

    _state.money -= def.cost;
    // Re-buying something already running tops its clock back up rather than
    // stacking a second copy of the same multiplier.
    final existing = _state.activeBoosts.where((b) => b.defId == boostId).firstOrNull;
    if (existing != null) {
      existing.daysRemaining = math.max(existing.daysRemaining, def.durationDays);
    } else {
      _state.activeBoosts.add(ActiveBoost(defId: boostId, daysRemaining: def.durationDays));
    }
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  // ── Daily missions ──

  void _rollMissionBoard() {
    _state.missions = rollMissions(_state.dayCount, math.Random(_state.dayCount * 7919 + 13));
    _state.missionsRolledForDay = _state.dayCount;
  }

  void _ensureMissionBoard() {
    if (_state.missions.isEmpty || _state.missionsRolledForDay != _state.dayCount) {
      _rollMissionBoard();
    }
  }

  /// Records progress against any live objective tracking [metric].
  void _bumpMission(MissionMetric metric, double amount) {
    _todayCounters[metric] = (_todayCounters[metric] ?? 0) + amount;
    var touched = false;
    for (final mission in _state.missions) {
      if (mission.rewarded || mission.def?.metric != metric) continue;
      mission.progress = _todayCounters[metric]!;
      touched = true;
    }
    if (!touched) return;
    if (_claimCompletedMissions().isEmpty) notifyListeners();
  }

  /// Pays out every objective that is complete but unrewarded.
  List<String> _claimCompletedMissions() {
    final events = <String>[];
    for (final mission in _state.missions) {
      if (mission.rewarded || !mission.complete) continue;
      final def = mission.def;
      if (def == null) continue;
      mission.rewarded = true;
      _state.money += mission.rewardCash;
      _state.reputation =
          (_state.reputation + mission.rewardRep).clamp(Economy.reputationMin, Economy.reputationMax);
      events.add('${def.name}: +\$${mission.rewardCash}, +${mission.rewardRep.toStringAsFixed(1)} rep');
    }
    if (events.isNotEmpty) {
      _save();
      notifyListeners();
    }
    return events;
  }

  (List<String>, double) _settleMissions({
    required double netProfit,
    required double bandwidthServed,
    required bool overloaded,
    required bool offline,
  }) {
    // Day-end snapshots, as opposed to the counters bumped during play.
    _todayCounters[MissionMetric.dailyNetProfit] = netProfit;
    _todayCounters[MissionMetric.bandwidthServed] = bandwidthServed;
    _todayCounters[MissionMetric.cleanDay] = overloaded ? 0 : 1;

    for (final mission in _state.missions) {
      if (mission.rewarded) continue;
      final def = mission.def;
      if (def == null) continue;
      final counter = _todayCounters[def.metric] ?? 0;
      if (counter > mission.progress) mission.progress = counter;
    }

    final events = _claimCompletedMissions();
    var rewardCash = 0.0;
    for (final mission in _state.missions) {
      if (mission.rewarded) rewardCash += mission.rewardCash;
    }

    _todayCounters.clear();
    _rollMissionBoard();
    return (events, offline ? 0.0 : rewardCash);
  }

  AccountLoadResult calculateLoad() {
    final rigs = <String, RigInput>{};
    for (final entry in _state.rigs.entries) {
      rigs[entry.key] = RigInput(
        build: entry.value.build,
        services: entry.value.services,
        kind: entry.value.kind,
        routerId: entry.value.routerId,
      );
    }
    final routers = <String, RouterInput>{};
    for (final entry in _state.routers.entries) {
      routers[entry.key] = RouterInput(internetPlanId: entry.value.internetPlanId);
    }

    final rigOverheatPenalties = <String, double>{};
    final rigCoolingReductions = <String, double>{};
    final routerBandwidthMultipliers = <String, double>{};
    final instanceIncomeMultipliers = <String, double>{};
    for (final incident in _activeIncidents) {
      switch (incident.type) {
        case IncidentType.rigOverheatSpike:
          rigOverheatPenalties[incident.targetId] = incident.severity;
          break;
        case IncidentType.coolingLeak:
          rigCoolingReductions[incident.targetId] = incident.severity;
          break;
        case IncidentType.routerDdos:
          routerBandwidthMultipliers[incident.targetId] = 1 - incident.severity;
          break;
        case IncidentType.viralDemandSpike:
          if (incident.affectedInstanceId != null) {
            instanceIncomeMultipliers[incident.affectedInstanceId!] = 1 + incident.severity;
          }
          break;
        case IncidentType.driveFailure:
          break;
      }
    }

    return calculateAccountLoad(
      rigs,
      routers,
      rigOverheatPenalties: rigOverheatPenalties,
      rigCoolingReductions: rigCoolingReductions,
      routerBandwidthMultipliers: routerBandwidthMultipliers,
      instanceIncomeMultipliers: instanceIncomeMultipliers,
      modifiers: simModifiers,
    );
  }

  double _getDailyInternetCost() {
    var total = 0.0;
    for (final router in _state.routers.values) {
      final plan = internetPlansById[router.internetPlanId];
      if (plan != null) total += plan.monthlyPrice / 30;
    }
    return total;
  }

  (double income, List<String> events, bool anyFailed) _processContracts(
    AccountLoadResult load, {
    bool offline = false,
  }) {
    final servedByType = <String, double>{};
    for (final inst in load.instances) {
      servedByType[inst.serviceTypeId] = (servedByType[inst.serviceTypeId] ?? 0) + inst.capacity * inst.satisfaction;
    }

    var contractIncome = 0.0;
    final events = <String>[];
    var anyFailed = false;

    for (var i = _state.contracts.length - 1; i >= 0; i--) {
      final contract = _state.contracts[i];
      final company = companiesById[contract.companyId];
      final companyName = company?.name ?? contract.companyId;
      final served = servedByType[contract.serviceTypeId] ?? 0;

      if (served + 1e-6 >= contract.minCapacity) {
        contractIncome += contract.payoutPerDay;
        contract.daysRemaining--;
        if (contract.daysRemaining <= 0) {
          contractIncome += contract.completionBonus;
          _state.reputation = (_state.reputation + contract.repBonus).clamp(Economy.reputationMin, Economy.reputationMax);
          _state.contractsCompletedCount++;
          events.add('$companyName contract completed: +\$${contract.completionBonus.toStringAsFixed(0)} bonus, +${contract.repBonus} rep');
          _state.contracts.removeAt(i);
          _bumpMission(MissionMetric.contractsCompleted, 1);
        }
      } else if (offline) {
        // Nothing was tended while the app was closed, so an under-served
        // contract simply doesn't pay today rather than being torn up with a
        // reputation hit the player had no chance to prevent.
        continue;
      } else {
        anyFailed = true;
        _state.reputation = (_state.reputation - contract.repPenalty).clamp(Economy.reputationMin, Economy.reputationMax);
        events.add('$companyName contract FAILED (needed ${contract.minCapacity} served capacity): -${contract.repPenalty} rep');
        _state.contracts.removeAt(i);
      }
    }

    return (contractIncome, events, anyFailed);
  }

  // ── Achievements ──

  final List<String> _pendingAchievementUnlocks = [];
  List<String> get pendingAchievementUnlocks => List.unmodifiable(_pendingAchievementUnlocks);

  void clearAchievementUnlock(String id) {
    _pendingAchievementUnlocks.remove(id);
    notifyListeners();
  }

  double metricValueFor(AchievementMetric metric) => switch (metric) {
    AchievementMetric.totalMoneyEarned => _state.totalMoneyEverEarned,
    AchievementMetric.reputation => _state.reputation,
    AchievementMetric.dayCount => _state.dayCount.toDouble(),
    AchievementMetric.peakBandwidthServed => _state.peakBandwidthServed,
    AchievementMetric.contractsCompleted => _state.contractsCompletedCount.toDouble(),
    AchievementMetric.uptimeStreakDays => _state.uptimeStreakDays.toDouble(),
    AchievementMetric.rigCount => _state.rigs.length.toDouble(),
    AchievementMetric.prestigeLevel => _state.prestigeLevel.toDouble(),
  };

  void _checkAchievements() {
    for (final def in achievementDefList) {
      if (_state.unlockedAchievements.contains(def.id)) continue;
      if (metricValueFor(def.metric) >= def.threshold) {
        _state.unlockedAchievements.add(def.id);
        _pendingAchievementUnlocks.add(def.id);
      }
    }
  }

  // ── Incidents ──

  void _maybeRollIncident() {
    if (_activeIncidents.length >= _maxConcurrentIncidents) return;
    // Research and cooling boosts both buy down how often anything goes wrong.
    final resistance =
        (1 - (1 - effects.incidentResistance) * (1 - boostEffects.incidentResistance)).clamp(0.0, 0.95);
    // A faster clock covers more in-game time per tick, so the per-tick chance
    // scales with it — otherwise 4× speed quietly makes the game safer.
    final chance = _incidentChancePerSecond * (1 - resistance) * _state.gameSpeed;
    if (_incidentRng.nextDouble() >= chance) return;
    _spawnIncident();
  }

  String _weightedDriveFailureTarget(List<Rig> candidates) {
    final weights = <double>[];
    var totalWeight = 0.0;
    for (final rig in candidates) {
      var w = 0.0;
      for (final driveId in rig.build.storageIds) {
        w += storageById[driveId]?.failureRatePerYear ?? 0.01;
      }
      if (w <= 0) w = 0.01;
      weights.add(w);
      totalWeight += w;
    }
    var roll = _incidentRng.nextDouble() * totalWeight;
    for (var i = 0; i < candidates.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return candidates[i].rigId;
    }
    return candidates.last.rigId;
  }

  void _spawnIncident() {
    final eligible = <IncidentType>[];
    if (_state.routers.isNotEmpty) eligible.add(IncidentType.routerDdos);
    if (_state.rigs.isNotEmpty) eligible.add(IncidentType.rigOverheatSpike);

    final rigsWithStorage = _state.rigs.values.where((r) => r.build.storageIds.isNotEmpty).toList();
    if (rigsWithStorage.isNotEmpty) eligible.add(IncidentType.driveFailure);

    final waterCooledRigs = _state.rigs.values.where((r) {
      final cooler = coolingById[r.build.coolingId];
      return cooler != null && cooler.requiresWater;
    }).toList();
    if (waterCooledRigs.isNotEmpty) eligible.add(IncidentType.coolingLeak);

    final load = calculateLoad();
    final slackInstances = load.instances.where((i) => i.satisfaction >= 0.98).toList();
    if (slackInstances.isNotEmpty) eligible.add(IncidentType.viralDemandSpike);

    if (eligible.isEmpty) return;
    final type = eligible[_incidentRng.nextInt(eligible.length)];

    late String targetKind;
    late String targetId;
    late double severity;
    String? affectedInstanceId;

    switch (type) {
      case IncidentType.routerDdos:
        targetKind = 'router';
        targetId = _state.routers.keys.elementAt(_incidentRng.nextInt(_state.routers.length));
        severity = 0.5;
        break;
      case IncidentType.rigOverheatSpike:
        targetKind = 'rig';
        targetId = _state.rigs.keys.elementAt(_incidentRng.nextInt(_state.rigs.length));
        severity = 0.3 + _incidentRng.nextDouble() * 0.2;
        break;
      case IncidentType.driveFailure:
        targetKind = 'rig';
        targetId = _weightedDriveFailureTarget(rigsWithStorage);
        severity = 1.0;
        break;
      case IncidentType.coolingLeak:
        targetKind = 'rig';
        targetId = waterCooledRigs[_incidentRng.nextInt(waterCooledRigs.length)].rigId;
        severity = 0.4;
        break;
      case IncidentType.viralDemandSpike:
        targetKind = 'rig';
        final inst = slackInstances[_incidentRng.nextInt(slackInstances.length)];
        targetId = inst.rigId;
        affectedInstanceId = inst.instanceId;
        severity = 0.5 + _incidentRng.nextDouble();
        break;
    }

    // A drive failure permanently destroys a real, persisted storage slot --
    // the existing incompatibility/bottleneck machinery in service_sim then
    // organically reflects the loss, no separate sim parameter needed.
    if (type == IncidentType.driveFailure) {
      final rig = _state.rigs[targetId];
      if (rig == null || rig.build.storageIds.isEmpty) return;
      final removeIdx = _incidentRng.nextInt(rig.build.storageIds.length);
      rig.build = rig.build.copyWith(storageIds: [...rig.build.storageIds]..removeAt(removeIdx));
      _save();
    }

    // A hired Sysadmin may silently auto-resolve minor (non-drive, non-positive) incidents.
    if (type != IncidentType.driveFailure && type != IncidentType.viralDemandSpike) {
      final staffEffects = getStaffEffects(_state.hiredStaffIds);
      if (_incidentRng.nextDouble() < staffEffects.sysadminAutoResolveChance) {
        notifyListeners();
        return;
      }
    }

    _activeIncidents.add(ActiveIncident(
      incidentId: '${_state.dayCount}_${_secondsElapsed}_${_incidentRng.nextInt(999999)}',
      type: type,
      targetKind: targetKind,
      targetId: targetId,
      spawnedAtSecond: _secondsElapsed,
      severity: severity,
      affectedInstanceId: affectedInstanceId,
    ));
    notifyListeners();
  }

  ActionResult mitigateIncident(String incidentId) {
    final incident = _activeIncidents.where((i) => i.incidentId == incidentId).firstOrNull;
    if (incident == null) return const ActionResult(ok: false, errors: ['Incident not found']);
    if (incident.type != IncidentType.routerDdos) return const ActionResult(ok: false, errors: ['This incident cannot be mitigated']);

    final router = _state.routers[incident.targetId];
    final plan = router != null ? internetPlansById[router.internetPlanId] : null;
    final cost = 50 + (plan?.upMbps ?? 0) * 0.05;
    if (_state.money < cost) return ActionResult(ok: false, errors: ['Not enough money (needs \$${cost.toStringAsFixed(0)})']);

    _state.money -= cost;
    _activeIncidents.remove(incident);
    _bumpMission(MissionMetric.incidentsResolved, 1);
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult emergencyCooldown(String incidentId) {
    final incident = _activeIncidents.where((i) => i.incidentId == incidentId).firstOrNull;
    if (incident == null) return const ActionResult(ok: false, errors: ['Incident not found']);
    if (incident.type != IncidentType.rigOverheatSpike) return const ActionResult(ok: false, errors: ['This incident cannot be cooled down']);
    if (_cooldownsUsedToday >= _maxEmergencyCooldownsPerDay) {
      return const ActionResult(ok: false, errors: ['Emergency cooldown already used twice today']);
    }

    _cooldownsUsedToday++;
    _activeIncidents.remove(incident);
    _bumpMission(MissionMetric.incidentsResolved, 1);
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult repairIncident(String incidentId) {
    final incident = _activeIncidents.where((i) => i.incidentId == incidentId).firstOrNull;
    if (incident == null) return const ActionResult(ok: false, errors: ['Incident not found']);
    if (incident.type != IncidentType.coolingLeak) return const ActionResult(ok: false, errors: ['This incident cannot be repaired']);

    final rig = _state.rigs[incident.targetId];
    final cooler = rig != null ? coolingById[rig.build.coolingId] : null;
    final cost = (cooler?.maintenanceCostPerWeek ?? 20) * 2.0;
    if (_state.money < cost) return ActionResult(ok: false, errors: ['Not enough money (needs \$${cost.toStringAsFixed(0)})']);

    _state.money -= cost;
    _activeIncidents.remove(incident);
    _bumpMission(MissionMetric.incidentsResolved, 1);
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult ignoreIncident(String incidentId) {
    final incident = _activeIncidents.where((i) => i.incidentId == incidentId).firstOrNull;
    if (incident == null) return const ActionResult(ok: false, errors: ['Incident not found']);
    incident.acknowledged = true;
    notifyListeners();
    return const ActionResult(ok: true);
  }

  void _reconcileIncidents(String rigId) {
    final rig = _state.rigs[rigId];
    if (rig == null || rig.build.storageIds.isEmpty) return;
    _activeIncidents.removeWhere((i) => i.type == IncidentType.driveFailure && i.targetId == rigId);
  }

  void _pushHistory(List<double> history, double value) {
    history.add(value);
    while (history.length > GameState.historyLength) history.removeAt(0);
  }

  // ── Contract Offers ──

  void _regenerateContractOffers() {
    final rng = math.Random(_state.dayCount * 31 + 7919);
    final staffEffects = getStaffEffects(_state.hiredStaffIds);
    final maxOffers =
        _maxOffersPerDay + staffEffects.offerSlotBonus + boostEffects.extraContractOffers;
    final eligible = <Company>[];
    for (final company in companyList) {
      if (_state.reputation < company.minReputation) continue;
      for (final serviceTypeId in company.serviceTypeIds) {
        final serviceType = servicesById[serviceTypeId];
        if (serviceType != null && (serviceType.requiredLicense == null || _state.licenses.contains(serviceType.requiredLicense))) {
          eligible.add(company);
          break;
        }
      }
    }

    final offers = <ContractOffer>[];
    final count = math.min(maxOffers, eligible.length);
    for (var i = 0; i < count; i++) {
      final idx = rng.nextInt(eligible.length);
      final company = eligible.removeAt(idx);

      final unlockedServices = <ServiceType>[];
      for (final serviceTypeId in company.serviceTypeIds) {
        final serviceType = servicesById[serviceTypeId];
        if (serviceType != null && (serviceType.requiredLicense == null || _state.licenses.contains(serviceType.requiredLicense))) {
          unlockedServices.add(serviceType);
        }
      }
      if (unlockedServices.isEmpty) continue;
      final serviceType = unlockedServices[rng.nextInt(unlockedServices.length)];

      final minCapacity = company.capacityMin + rng.nextInt(company.capacityMax - company.capacityMin + 1);
      final durationDays = company.minDurationDays + rng.nextInt(company.maxDurationDays - company.minDurationDays + 1);
      var payoutPerDay = serviceType.incomePerUnitPerDay * minCapacity * (company.payoutMultiplier - 1);
      payoutPerDay *= (1 + staffEffects.payoutBonusMultiplier);
      payoutPerDay = (payoutPerDay * 100).round() / 100;
      final completionBonus = (payoutPerDay * durationDays * 0.5).round();

      offers.add(ContractOffer(
        offerId: '${_state.dayCount}_$i',
        companyId: company.id,
        serviceTypeId: serviceType.id,
        minCapacity: minCapacity,
        durationDays: durationDays,
        payoutPerDay: payoutPerDay,
        completionBonus: completionBonus.toDouble(),
        repBonus: math.max(1, (durationDays / 2).floor()),
        repPenalty: math.max(2, (durationDays * 0.75).floor()),
      ));
    }

    _contractOffers = offers;
    _acceptedOfferIds.clear();
  }

  // ── Actions ──

  ActionResult addRig({bool server = false}) {
    final kind = server ? RigKind.server : RigKind.pc;
    final effects = this.effects;
    final baseCost = server ? GameState.newServerRigCost : GameState.newRigCost;
    final cost = (baseCost * (1 - effects.rigCostDiscount)).round();

    if (_state.money < cost) {
      return ActionResult(ok: false, errors: ['Not enough money (needs \$$cost)']);
    }

    Router? bestRouter;
    var bestCount = 999999;
    final rigCounts = <String, int>{};
    for (final rig in _state.rigs.values) {
      rigCounts[rig.routerId] = (rigCounts[rig.routerId] ?? 0) + 1;
    }
    for (final router in _state.routers.values) {
      final count = rigCounts[router.routerId] ?? 0;
      if (count < bestCount) {
        bestCount = count;
        bestRouter = router;
      }
    }
    if (bestRouter == null) {
      return const ActionResult(ok: false, errors: ['You need at least one router first']);
    }

    final rigId = '${_state.nextRigId}';
    _state.nextRigId++;
    _state.money -= cost;
    _state.rigs[rigId] = Rig(
      rigId: rigId,
      name: server ? 'Server $rigId' : 'Rig $rigId',
      kind: kind,
      build: server ? newServerBuild() : newRigBuild(),
      services: [],
      routerId: bestRouter.routerId,
      pos: NodePos(
        x: (bestRouter.pos.x + 320).clamp(0, GameState.canvasMaxX),
        y: (bestRouter.pos.y + bestCount * 160).clamp(0, GameState.canvasMaxY),
      ),
    );
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult addRouter() {
    final effects = this.effects;
    var count = 0;
    var lastPos = NodePos(x: 60, y: 60);
    for (final router in _state.routers.values) {
      count++;
      lastPos = router.pos;
    }
    if (count >= effects.maxRouters) {
      return const ActionResult(ok: false, errors: ['Research more networking tech to run additional routers']);
    }
    if (_state.money < GameState.newRouterCost) {
      return ActionResult(ok: false, errors: ['Not enough money (needs \$${GameState.newRouterCost})']);
    }

    final routerId = '${_state.nextRouterId}';
    _state.nextRouterId++;
    _state.money -= GameState.newRouterCost;
    _state.routers[routerId] = Router(
      routerId: routerId,
      name: 'Router $routerId',
      internetPlanId: 'HOME_25',
      pos: NodePos(
        x: lastPos.x.clamp(0, GameState.canvasMaxX),
        y: (lastPos.y + 220).clamp(0, GameState.canvasMaxY),
      ),
    );
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult moveNode(String kind, String id, double x, double y) {
    x = x.clamp(0, GameState.canvasMaxX);
    y = y.clamp(0, GameState.canvasMaxY);

    if (kind == 'rig') {
      final rig = _state.rigs[id];
      if (rig == null) return const ActionResult(ok: false, errors: ['Unknown rig']);
      rig.pos = NodePos(x: x, y: y);
    } else if (kind == 'router') {
      final router = _state.routers[id];
      if (router == null) return const ActionResult(ok: false, errors: ['Unknown router']);
      router.pos = NodePos(x: x, y: y);
    } else {
      return const ActionResult(ok: false, errors: ['Unknown node kind']);
    }
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult assignRigRouter(String rigId, String routerId) {
    final rig = _state.rigs[rigId];
    if (rig == null) return const ActionResult(ok: false, errors: ['Unknown rig']);
    if (!_state.routers.containsKey(routerId)) return const ActionResult(ok: false, errors: ['Unknown router']);
    rig.routerId = routerId;
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult installService(String rigId, String serviceTypeId, int capacity) {
    final rig = _state.rigs[rigId];
    if (rig == null) return const ActionResult(ok: false, errors: ['Unknown rig']);
    final serviceType = servicesById[serviceTypeId];
    if (serviceType == null) return const ActionResult(ok: false, errors: ['Unknown service type']);
    if (serviceType.requiredLicense != null && !_state.licenses.contains(serviceType.requiredLicense)) {
      return ActionResult(ok: false, errors: ['Requires the ${serviceType.requiredLicense} license']);
    }
    if (capacity < 1) capacity = 1;

    final instanceId = '${_state.nextInstanceId}';
    _state.nextInstanceId++;
    rig.services.add(ServiceInstance(instanceId: instanceId, serviceTypeId: serviceTypeId, capacity: capacity));
    _bumpMission(MissionMetric.servicesInstalled, 1);
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult uninstallService(String rigId, String instanceId) {
    final rig = _state.rigs[rigId];
    if (rig == null) return const ActionResult(ok: false, errors: ['Unknown rig']);
    final idx = rig.services.indexWhere((s) => s.instanceId == instanceId);
    if (idx < 0) return const ActionResult(ok: false, errors: ['Service instance not found']);
    rig.services.removeAt(idx);
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult setServiceCapacity(String rigId, String instanceId, int capacity) {
    final rig = _state.rigs[rigId];
    if (rig == null) return const ActionResult(ok: false, errors: ['Unknown rig']);
    if (capacity < 1) capacity = 1;
    for (final inst in rig.services) {
      if (inst.instanceId == instanceId) {
        inst.capacity = capacity;
        _save();
        notifyListeners();
        return const ActionResult(ok: true);
      }
    }
    return const ActionResult(ok: false, errors: ['Service instance not found']);
  }

  ActionResult buyLicense(String licenseId) {
    final license = licensesById[licenseId];
    if (license == null) return const ActionResult(ok: false, errors: ['Unknown license']);
    if (_state.licenses.contains(licenseId)) return const ActionResult(ok: false, errors: ['Already owned']);
    for (final reqId in license.requires) {
      if (!_state.licenses.contains(reqId)) {
        return ActionResult(ok: false, errors: ['Requires the $reqId license first']);
      }
    }
    if (_state.reputation < license.minReputation) {
      return ActionResult(ok: false, errors: ['Requires ${license.minReputation} reputation']);
    }
    if (_state.money < license.cost) return const ActionResult(ok: false, errors: ['Not enough money']);

    _state.money -= license.cost;
    _state.licenses.add(licenseId);
    _regenerateContractOffers();
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult hireStaff(String staffId) {
    final def = staffDefsById[staffId];
    if (def == null) return const ActionResult(ok: false, errors: ['Unknown staff member']);
    if (_state.hiredStaffIds.contains(staffId)) return const ActionResult(ok: false, errors: ['Already hired']);
    if (_state.reputation < def.minReputation) {
      return ActionResult(ok: false, errors: ['Requires ${def.minReputation} reputation']);
    }
    if (def.requiresLicense != null && !_state.licenses.contains(def.requiresLicense)) {
      return ActionResult(ok: false, errors: ['Requires the ${def.requiresLicense} license']);
    }
    if (def.requiresResearch != null && !_state.research.contains(def.requiresResearch)) {
      return ActionResult(ok: false, errors: ['Requires the ${def.requiresResearch} research']);
    }
    if (_state.money < def.cost) return const ActionResult(ok: false, errors: ['Not enough money']);

    _state.money -= def.cost;
    _state.hiredStaffIds.add(staffId);
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult fireStaff(String staffId) {
    if (!_state.hiredStaffIds.contains(staffId)) return const ActionResult(ok: false, errors: ['Not currently hired']);
    _state.hiredStaffIds.remove(staffId);
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult acceptContract(String offerId) {
    if (_acceptedOfferIds.contains(offerId)) {
      return const ActionResult(ok: false, errors: ['Offer already accepted']);
    }
    final offer = _contractOffers.where((o) => o.offerId == offerId).firstOrNull;
    if (offer == null) return const ActionResult(ok: false, errors: ['That offer has expired']);

    final effects = this.effects;
    if (_state.contracts.length >= effects.contractSlots) {
      return ActionResult(ok: false, errors: ['You can only run ${effects.contractSlots} contracts at once (research Sales Team for more)']);
    }

    final contractId = '${_state.nextContractId}';
    _state.nextContractId++;
    _acceptedOfferIds.add(offerId);
    _state.contracts.add(Contract(
      contractId: contractId,
      companyId: offer.companyId,
      serviceTypeId: offer.serviceTypeId,
      minCapacity: offer.minCapacity,
      daysRemaining: offer.durationDays,
      totalDays: offer.durationDays,
      payoutPerDay: offer.payoutPerDay,
      completionBonus: offer.completionBonus,
      repBonus: offer.repBonus,
      repPenalty: offer.repPenalty,
    ));
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  Map<String, Map<String, dynamic>> _allCatalogs() => <String, Map<String, dynamic>>{
    'cpu': cpusById as Map<String, dynamic>,
    'motherboard': motherboardsById as Map<String, dynamic>,
    'psu': psusById as Map<String, dynamic>,
    'cooling': coolingById as Map<String, dynamic>,
    'nic': nicsById as Map<String, dynamic>,
    'ram': ramById as Map<String, dynamic>,
    'storage': storageById as Map<String, dynamic>,
  };

  int inventoryCount(String itemId) => _state.inventory[itemId] ?? 0;

  void _consumeInventory(String itemId) {
    final count = _state.inventory[itemId] ?? 0;
    if (count <= 1) {
      _state.inventory.remove(itemId);
    } else {
      _state.inventory[itemId] = count - 1;
    }
  }

  ActionResult buyToInventory(String slot, String itemId) {
    final catalog = _allCatalogs()[slot];
    if (catalog == null) return const ActionResult(ok: false, errors: ['Unknown item category']);
    final item = catalog[itemId];
    if (item == null) return const ActionResult(ok: false, errors: ['Unknown item']);
    final price = (item as dynamic).price as int;
    if (_state.money < price) return const ActionResult(ok: false, errors: ['Not enough money']);

    _state.money -= price;
    _state.inventory[itemId] = (_state.inventory[itemId] ?? 0) + 1;
    _bumpMission(MissionMetric.componentsBought, 1);
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult buyComponent(String rigId, String slot, String itemId) {
    final rig = _state.rigs[rigId];
    if (rig == null) return const ActionResult(ok: false, errors: ['Unknown rig']);

    final catalogs = <String, Map<String, dynamic>>{
      'cpu': cpusById as Map<String, dynamic>,
      'motherboard': motherboardsById as Map<String, dynamic>,
      'psu': psusById as Map<String, dynamic>,
      'cooling': coolingById as Map<String, dynamic>,
      'nic': nicsById as Map<String, dynamic>,
    };
    final buildKeys = <String, String>{
      'cpu': 'cpuId',
      'motherboard': 'motherboardId',
      'psu': 'psuId',
      'cooling': 'coolingId',
      'nic': 'nicId',
    };

    final catalog = catalogs[slot];
    final buildKey = buildKeys[slot];
    if (catalog == null || buildKey == null) {
      return const ActionResult(ok: false, errors: ['Unknown component slot']);
    }
    final item = catalog[itemId];
    if (item == null) return const ActionResult(ok: false, errors: ['Unknown item']);
    final price = (item as dynamic).price as int;
    final fromInventory = (_state.inventory[itemId] ?? 0) > 0;
    if (!fromInventory && _state.money < price) return const ActionResult(ok: false, errors: ['Not enough money']);

    final trialBuild = rig.build.copyWith();
    switch (buildKey) {
      case 'cpuId': trialBuild.cpuId = itemId; break;
      case 'motherboardId': trialBuild.motherboardId = itemId; break;
      case 'psuId': trialBuild.psuId = itemId; break;
      case 'coolingId': trialBuild.coolingId = itemId; break;
      case 'nicId': trialBuild.nicId = itemId; break;
    }

    // Incompatible parts are still allowed to be installed -- the rig just
    // won't generate income until the build is fixed (see calculateRigLoad).
    final (errors, ok) = validateBuild(trialBuild, rigKind: rig.kind);

    if (fromInventory) {
      _consumeInventory(itemId);
    } else {
      _state.money -= price;
      _bumpMission(MissionMetric.componentsBought, 1);
    }
    rig.build = trialBuild;
    _save();
    notifyListeners();

    if (!ok) {
      final msg = '${(item as dynamic).name} installed, but it doesn\'t work: ${errors.join('; ')}. This rig will not generate income until fixed.';
      _lastNotification = msg;
      return ActionResult(ok: true, warning: msg);
    }
    return const ActionResult(ok: true);
  }

  ActionResult buyInternetPlan(String routerId, String planId) {
    final router = _state.routers[routerId];
    if (router == null) return const ActionResult(ok: false, errors: ['Unknown router']);
    if (!internetPlansById.containsKey(planId)) return const ActionResult(ok: false, errors: ['Unknown plan']);
    router.internetPlanId = planId;
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult addRAM(String rigId, String itemId) {
    final rig = _state.rigs[rigId];
    if (rig == null) return const ActionResult(ok: false, errors: ['Unknown rig']);
    final stick = ramById[itemId];
    if (stick == null) return const ActionResult(ok: false, errors: ['Unknown RAM stick']);
    final fromInventory = (_state.inventory[itemId] ?? 0) > 0;
    if (!fromInventory && _state.money < stick.price) return const ActionResult(ok: false, errors: ['Not enough money']);

    final trialBuild = rig.build.copyWith(ramIds: [...rig.build.ramIds, itemId]);
    final (errors, ok) = validateBuild(trialBuild, rigKind: rig.kind);

    if (fromInventory) {
      _consumeInventory(itemId);
    } else {
      _state.money -= stick.price;
      _bumpMission(MissionMetric.componentsBought, 1);
    }
    rig.build = trialBuild;
    _save();
    notifyListeners();

    if (!ok) {
      final msg = '${stick.name} installed, but it doesn\'t work: ${errors.join('; ')}. This rig will not generate income until fixed.';
      _lastNotification = msg;
      return ActionResult(ok: true, warning: msg);
    }
    return const ActionResult(ok: true);
  }

  ActionResult removeRAM(String rigId, int index) {
    final rig = _state.rigs[rigId];
    if (rig == null) return const ActionResult(ok: false, errors: ['Unknown rig']);
    if (index < 0 || index >= rig.build.ramIds.length) {
      return const ActionResult(ok: false, errors: ['No RAM stick at that slot']);
    }
    final trialBuild = rig.build.copyWith(ramIds: [...rig.build.ramIds]..removeAt(index));
    rig.build = trialBuild;
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  ActionResult addStorage(String rigId, String itemId) {
    final rig = _state.rigs[rigId];
    if (rig == null) return const ActionResult(ok: false, errors: ['Unknown rig']);
    final drive = storageById[itemId];
    if (drive == null) return const ActionResult(ok: false, errors: ['Unknown drive']);
    final fromInventory = (_state.inventory[itemId] ?? 0) > 0;
    if (!fromInventory && _state.money < drive.price) return const ActionResult(ok: false, errors: ['Not enough money']);

    final trialBuild = rig.build.copyWith(storageIds: [...rig.build.storageIds, itemId]);
    final (errors, ok) = validateBuild(trialBuild, rigKind: rig.kind);

    if (fromInventory) {
      _consumeInventory(itemId);
    } else {
      _state.money -= drive.price;
      _bumpMission(MissionMetric.componentsBought, 1);
    }
    rig.build = trialBuild;
    _reconcileIncidents(rigId);
    _save();
    notifyListeners();

    if (!ok) {
      final msg = '${drive.name} installed, but it doesn\'t work: ${errors.join('; ')}. This rig will not generate income until fixed.';
      _lastNotification = msg;
      return ActionResult(ok: true, warning: msg);
    }
    return const ActionResult(ok: true);
  }

  ActionResult removeStorage(String rigId, int index) {
    final rig = _state.rigs[rigId];
    if (rig == null) return const ActionResult(ok: false, errors: ['Unknown rig']);
    if (index < 0 || index >= rig.build.storageIds.length) {
      return const ActionResult(ok: false, errors: ['No drive at that slot']);
    }
    final trialBuild = rig.build.copyWith(storageIds: [...rig.build.storageIds]..removeAt(index));
    rig.build = trialBuild;
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  // ── Quick actions ──

  /// What [fixBottleneck] would do to this rig, or null if there's nothing
  /// obvious to buy. Lets the UI label the button with the actual part.
  (String slot, String itemId, String name, int price)? bottleneckFixFor(String rigId) {
    final rig = _state.rigs[rigId];
    if (rig == null) return null;
    final load = calculateLoad();
    final rigLoad = load.rigs[rigId];
    if (rigLoad == null || rigLoad.incompatible) return null;

    // Router bandwidth is a property of the link, not the rig, so it is
    // handled by upgradeRouterPlan instead.
    final bottleneck = rigLoad.localBottleneck;
    if (bottleneck == null) return null;

    // Something already sitting in inventory costs nothing to fit.
    bool affordable(String itemId, int price) =>
        (_state.inventory[itemId] ?? 0) > 0 || _state.money >= price;

    switch (bottleneck) {
      case 'cpu':
        final current = cpusById[rig.build.cpuId];
        final currentScore = current?.mcScore ?? 0;
        final candidates = cpuList.where((c) => c.mcScore > currentScore).toList()
          ..sort((a, b) => a.price.compareTo(b.price));
        for (final cpu in candidates) {
          if (!affordable(cpu.id, cpu.price)) continue;
          final trial = rig.build.copyWith()..cpuId = cpu.id;
          final (_, ok) = validateBuild(trial, rigKind: rig.kind);
          if (ok) return ('cpu', cpu.id, cpu.name, cpu.price);
        }
        return null;
      case 'nic':
        final current = nicsById[rig.build.nicId];
        final currentThroughput = current?.throughputMbps ?? 0;
        final candidates = nicList.where((n) => n.throughputMbps > currentThroughput).toList()
          ..sort((a, b) => a.price.compareTo(b.price));
        for (final nic in candidates) {
          if (!affordable(nic.id, nic.price)) continue;
          final trial = rig.build.copyWith()..nicId = nic.id;
          final (_, ok) = validateBuild(trial, rigKind: rig.kind);
          if (ok) return ('nic', nic.id, nic.name, nic.price);
        }
        return null;
      case 'ram':
        final candidates = ramList.toList()..sort((a, b) => a.price.compareTo(b.price));
        for (final stick in candidates) {
          if (!affordable(stick.id, stick.price)) continue;
          final trial = rig.build.copyWith(ramIds: [...rig.build.ramIds, stick.id]);
          final (_, ok) = validateBuild(trial, rigKind: rig.kind);
          if (ok) return ('ram', stick.id, stick.name, stick.price);
        }
        return null;
      case 'storage':
        final candidates = storageList.toList()..sort((a, b) => a.price.compareTo(b.price));
        for (final drive in candidates) {
          if (!affordable(drive.id, drive.price)) continue;
          final trial = rig.build.copyWith(storageIds: [...rig.build.storageIds, drive.id]);
          final (_, ok) = validateBuild(trial, rigKind: rig.kind);
          if (ok) return ('storage', drive.id, drive.name, drive.price);
        }
        return null;
      default:
        return null;
    }
  }

  /// Buys and installs the cheapest part that relieves this rig's current
  /// bottleneck — the five-sheet upgrade path collapsed into one tap.
  ActionResult fixBottleneck(String rigId) {
    final fix = bottleneckFixFor(rigId);
    if (fix == null) {
      final rigLoad = calculateLoad().rigs[rigId];
      if (rigLoad == null) return const ActionResult(ok: false, errors: ['Unknown rig']);
      if (rigLoad.incompatible) {
        return const ActionResult(ok: false, errors: ['Fix the incompatible parts first']);
      }
      if (rigLoad.localBottleneck == null) {
        return const ActionResult(ok: false, errors: ['Nothing is holding this rig back']);
      }
      return const ActionResult(ok: false, errors: ['No affordable upgrade for that bottleneck']);
    }

    final (slot, itemId, _, _) = fix;
    return switch (slot) {
      'ram' => addRAM(rigId, itemId),
      'storage' => addStorage(rigId, itemId),
      _ => buyComponent(rigId, slot, itemId),
    };
  }

  /// Upgrades a router to the cheapest faster plan it can afford.
  ActionResult upgradeRouterPlan(String routerId) {
    final router = _state.routers[routerId];
    if (router == null) return const ActionResult(ok: false, errors: ['Unknown router']);
    final current = internetPlansById[router.internetPlanId];
    final currentUp = current?.upMbps ?? 0;

    final candidates = internetPlanList.where((p) => p.upMbps > currentUp).toList()
      ..sort((a, b) => a.monthlyPrice.compareTo(b.monthlyPrice));
    if (candidates.isEmpty) {
      return const ActionResult(ok: false, errors: ['Already on the fastest plan']);
    }
    return buyInternetPlan(routerId, candidates.first.id);
  }

  /// Buys a fresh rig with the same build as an existing one.
  ActionResult cloneRig(String rigId) {
    final source = _state.rigs[rigId];
    if (source == null) return const ActionResult(ok: false, errors: ['Unknown rig']);

    final baseCost = source.kind == RigKind.server ? GameState.newServerRigCost : GameState.newRigCost;
    var partsCost = 0;
    partsCost += cpusById[source.build.cpuId]?.price ?? 0;
    partsCost += motherboardsById[source.build.motherboardId]?.price ?? 0;
    partsCost += psusById[source.build.psuId]?.price ?? 0;
    partsCost += coolingById[source.build.coolingId]?.price ?? 0;
    partsCost += nicsById[source.build.nicId]?.price ?? 0;
    for (final id in source.build.ramIds) {
      partsCost += ramById[id]?.price ?? 0;
    }
    for (final id in source.build.storageIds) {
      partsCost += storageById[id]?.price ?? 0;
    }

    final cost = ((baseCost + partsCost) * (1 - effects.rigCostDiscount)).round();
    if (_state.money < cost) {
      return ActionResult(ok: false, errors: ['Not enough money (needs \$$cost)']);
    }

    final newId = '${_state.nextRigId}';
    _state.nextRigId++;
    _state.money -= cost;
    _state.rigs[newId] = Rig(
      rigId: newId,
      name: source.kind == RigKind.server ? 'Server $newId' : 'Rig $newId',
      kind: source.kind,
      // Services are not copied — they're the part that costs nothing and
      // that the player should choose deliberately.
      build: source.build.copyWith(
        ramIds: [...source.build.ramIds],
        storageIds: [...source.build.storageIds],
      ),
      services: [],
      routerId: source.routerId,
      pos: NodePos(
        x: (source.pos.x + 260).clamp(0, GameState.canvasMaxX),
        y: (source.pos.y + 40).clamp(0, GameState.canvasMaxY),
      ),
    );
    _bumpMission(MissionMetric.componentsBought, 1);
    _save();
    notifyListeners();
    return ActionResult(ok: true, warning: 'Cloned for \$$cost — install services on it to start earning');
  }

  /// Lays every node out in tidy columns: routers down the left, their rigs in
  /// a grid beside them. Dragging tiles into place is miserable on a phone.
  ActionResult autoArrange() {
    if (_state.routers.isEmpty) return const ActionResult(ok: false, errors: ['Nothing to arrange']);

    const routerX = 60.0;
    const rigStartX = 380.0;
    const columnWidth = 260.0;
    const rowHeight = 120.0;
    const groupGap = 60.0;
    const rigsPerRow = 3;

    var y = 60.0;
    final routerIds = _state.routers.keys.toList()..sort();
    for (final routerId in routerIds) {
      final router = _state.routers[routerId]!;
      final rigs = _state.rigs.values.where((r) => r.routerId == routerId).toList()
        ..sort((a, b) => a.rigId.compareTo(b.rigId));

      router.pos = NodePos(x: routerX, y: y);
      for (var i = 0; i < rigs.length; i++) {
        rigs[i].pos = NodePos(
          x: rigStartX + (i % rigsPerRow) * columnWidth,
          y: y + (i ~/ rigsPerRow) * rowHeight,
        );
      }

      final rows = rigs.isEmpty ? 1 : ((rigs.length - 1) ~/ rigsPerRow) + 1;
      y += rows * rowHeight + groupGap;
    }

    // Rigs pointing at a router that no longer exists would otherwise be left
    // wherever they were dropped.
    var orphanY = y;
    for (final rig in _state.rigs.values) {
      if (_state.routers.containsKey(rig.routerId)) continue;
      rig.pos = NodePos(x: rigStartX, y: orphanY);
      orphanY += rowHeight;
    }

    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }

  void resetGame() {
    // prestigeLevel/incomeMultiplier/unlockedAchievements/totalMoneyEverEarned
    // survive an ordinary reset — see rebirth() below for the distinct,
    // opt-in "Scale Up" action that also carries these forward.
    _state = GameState.newDefault(
      prestigeLevel: _state.prestigeLevel,
      incomeMultiplier: _state.incomeMultiplier,
      unlockedAchievements: _state.unlockedAchievements,
      totalMoneyEverEarned: _state.totalMoneyEverEarned,
    );
    _contractOffers = [];
    _acceptedOfferIds.clear();
    _lastDayReport = null;
    _lastAwayReport = null;
    _activeIncidents.clear();
    _cooldownsUsedToday = 0;
    _todayCounters.clear();
    _recentDays.clear();
    _state.lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch;
    _regenerateContractOffers();
    _ensureMissionBoard();
    _save();
    notifyListeners();
  }

  // ── Prestige / Rebirth ──

  double get rebirthThreshold => 50000 * math.pow(2.2, _state.prestigeLevel).toDouble();
  bool get canRebirth => _state.money >= rebirthThreshold;

  ActionResult rebirth() {
    if (!canRebirth) {
      return ActionResult(ok: false, errors: ['Need \$${rebirthThreshold.toStringAsFixed(0)} net worth to scale up']);
    }
    final newLevel = _state.prestigeLevel + 1;
    final newMultiplier = 1 + 2 * (1 - math.exp(-0.3 * newLevel));
    _state = GameState.newDefault(
      prestigeLevel: newLevel,
      incomeMultiplier: newMultiplier,
      unlockedAchievements: _state.unlockedAchievements,
      totalMoneyEverEarned: _state.totalMoneyEverEarned,
    );
    _contractOffers = [];
    _acceptedOfferIds.clear();
    _lastDayReport = null;
    _lastAwayReport = null;
    _activeIncidents.clear();
    _cooldownsUsedToday = 0;
    _todayCounters.clear();
    _recentDays.clear();
    _state.lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch;
    _regenerateContractOffers();
    _ensureMissionBoard();
    _save();
    notifyListeners();
    return const ActionResult(ok: true);
  }
}
