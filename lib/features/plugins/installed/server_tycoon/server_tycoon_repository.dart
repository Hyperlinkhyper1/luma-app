// Auto-ported from Roblox Server Hosting Tycoon
// Game logic repository: day processing, all player actions, persistence.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'data/companies.dart';
import 'data/game_data.dart';
import 'data/research.dart';
import 'game_state.dart';
import 'sim/computer_sim.dart';
import 'sim/economy.dart';
import 'sim/service_sim.dart';

class ActionResult {
  final bool ok;
  final List<String>? errors;

  const ActionResult({required this.ok, this.errors});
}

class ServerTycoonRepository extends ChangeNotifier {
  static const String _saveFileName = 'server_tycoon_save.json';
  static const int _maxOffersPerDay = 3;

  GameState _state;
  List<ContractOffer> _contractOffers = [];
  final Set<String> _acceptedOfferIds = {};
  Timer? _dayTimer;
  DayReport? _lastDayReport;
  String? _lastNotification;

  GameState get state => _state;
  List<ContractOffer> get contractOffers => List.unmodifiable(_contractOffers);
  DayReport? get lastDayReport => _lastDayReport;
  String? get lastNotification => _lastNotification;

  ServerTycoonRepository() : _state = GameState.newDefault() {
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
        notifyListeners();
      }
    } catch (e) {
      // keep default state
    }
  }

  Future<void> _save() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_saveFileName');
      await file.writeAsString(jsonEncode(_state.toJson()));
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

  double get dayProgress {
    // In this Flutter port, we use a simpler model:
    // Each "End Day" button press advances the day.
    // But we also support auto-advance every 3 minutes if running.
    return 0; // Placeholder for UI
  }

  void _tick() {
    // Auto-advance could go here; for now we use manual End Day
  }

  // ── Day Processing ──

  DayReport? processDay() {
    final load = _calculateLoad();
    final effects = getResearchEffects(_state.research);

    var totalWatts = 0.0;
    for (final entry in _state.rigs.entries) {
      final rigLoad = load.rigs[entry.key];
      if (rigLoad != null) {
        totalWatts += getActualPowerDrawWatts(entry.value.build, rigLoad.cpuLoadFactor);
      }
    }

    final electricityPrice = Economy.getFluctuatedPrice(Economy.baseElectricityPricePerKWh, _state.dayCount);
    final electricityCost = Economy.calculateElectricityCost(totalWatts, pricePerKWh: electricityPrice) * (1 - effects.electricityDiscount);
    final internetCost = _getDailyInternetCost();
    final (contractIncome, contractEvents) = _processContracts(load);

    var income = load.totalIncomePerDay + contractIncome;
    final netProfit = income - electricityCost - internetCost;

    _state.money += netProfit;
    _state.dayCount++;
    _state.peakPowerDrawWatts = math.max(_state.peakPowerDrawWatts, totalWatts);

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

    _regenerateContractOffers();
    _save();

    _lastDayReport = DayReport(
      day: _state.dayCount,
      income: income,
      contractIncome: contractIncome,
      contractEvents: contractEvents,
      electricityCost: electricityCost,
      internetCost: internetCost,
      netProfit: netProfit,
      avgSatisfaction: avgSatisfaction,
      reputation: _state.reputation,
      money: _state.money,
      overloaded: load.overloaded,
    );
    notifyListeners();
    return _lastDayReport;
  }

  /// Dismisses the pending end-of-day report so the modal can close.
  void clearDayReport() {
    _lastDayReport = null;
    notifyListeners();
  }

  AccountLoadResult _calculateLoad() {
    final rigs = <String, RigInput>{};
    for (final entry in _state.rigs.entries) {
      rigs[entry.key] = RigInput(
        build: entry.value.build,
        services: entry.value.services,
        routerId: entry.value.routerId,
      );
    }
    final routers = <String, RouterInput>{};
    for (final entry in _state.routers.entries) {
      routers[entry.key] = RouterInput(internetPlanId: entry.value.internetPlanId);
    }
    return calculateAccountLoad(rigs, routers);
  }

  double _getDailyInternetCost() {
    var total = 0.0;
    for (final router in _state.routers.values) {
      final plan = internetPlansById[router.internetPlanId];
      if (plan != null) total += plan.monthlyPrice / 30;
    }
    return total;
  }

  (double income, List<String> events) _processContracts(AccountLoadResult load) {
    final servedByType = <String, double>{};
    for (final inst in load.instances) {
      servedByType[inst.serviceTypeId] = (servedByType[inst.serviceTypeId] ?? 0) + inst.capacity * inst.satisfaction;
    }

    var contractIncome = 0.0;
    final events = <String>[];

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
          events.add('$companyName contract completed: +\$${contract.completionBonus.toStringAsFixed(0)} bonus, +${contract.repBonus} rep');
          _state.contracts.removeAt(i);
        }
      } else {
        _state.reputation = (_state.reputation - contract.repPenalty).clamp(Economy.reputationMin, Economy.reputationMax);
        events.add('$companyName contract FAILED (needed ${contract.minCapacity} served capacity): -${contract.repPenalty} rep');
        _state.contracts.removeAt(i);
      }
    }

    return (contractIncome, events);
  }

  void _pushHistory(List<double> history, double value) {
    history.add(value);
    while (history.length > GameState.historyLength) history.removeAt(0);
  }

  // ── Contract Offers ──

  void _regenerateContractOffers() {
    final rng = math.Random(_state.dayCount * 31 + 7919);
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
    final count = math.min(_maxOffersPerDay, eligible.length);
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
    final effects = getResearchEffects(_state.research);
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
    final effects = getResearchEffects(_state.research);
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

  ActionResult buyResearch(String researchId) {
    final project = researchById[researchId];
    if (project == null) return const ActionResult(ok: false, errors: ['Unknown research project']);
    if (_state.research.contains(researchId)) return const ActionResult(ok: false, errors: ['Already researched']);
    for (final reqId in project.requires) {
      if (!_state.research.contains(reqId)) {
        final req = researchById[reqId];
        return ActionResult(ok: false, errors: ['Requires ${req?.name ?? reqId} first']);
      }
    }
    if (_state.reputation < project.minReputation) {
      return ActionResult(ok: false, errors: ['Requires ${project.minReputation} reputation']);
    }
    if (_state.money < project.cost) return const ActionResult(ok: false, errors: ['Not enough money']);

    _state.money -= project.cost;
    _state.research.add(researchId);
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

    final effects = getResearchEffects(_state.research);
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
    if (_state.money < price) return const ActionResult(ok: false, errors: ['Not enough money']);

    if (!gradeFits(slot, itemId, rig.kind)) {
      final grade = getComponentGrade(slot, itemId);
      return ActionResult(ok: false, errors: ['${(item as dynamic).name} is ${grade.name} hardware -- it does not fit a ${rig.kind.name} rig']);
    }

    final trialBuild = rig.build.copyWith();
    switch (buildKey) {
      case 'cpuId': trialBuild.cpuId = itemId; break;
      case 'motherboardId': trialBuild.motherboardId = itemId; break;
      case 'psuId': trialBuild.psuId = itemId; break;
      case 'coolingId': trialBuild.coolingId = itemId; break;
      case 'nicId': trialBuild.nicId = itemId; break;
    }

    final (errors, ok) = validateBuild(trialBuild, rigKind: rig.kind);
    if (!ok) return ActionResult(ok: false, errors: errors);

    _state.money -= price;
    rig.build = trialBuild;
    _save();
    notifyListeners();
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
    if (_state.money < stick.price) return const ActionResult(ok: false, errors: ['Not enough money']);
    if (!gradeFits('ram', itemId, rig.kind)) {
      return ActionResult(ok: false, errors: ['${stick.name} is ${getComponentGrade('ram', itemId).name} hardware -- it does not fit a ${rig.kind.name} rig']);
    }

    final trialBuild = rig.build.copyWith(ramIds: [...rig.build.ramIds, itemId]);
    final (errors, ok) = validateBuild(trialBuild, rigKind: rig.kind);
    if (!ok) return ActionResult(ok: false, errors: errors);

    _state.money -= stick.price;
    rig.build = trialBuild;
    _save();
    notifyListeners();
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
    if (_state.money < drive.price) return const ActionResult(ok: false, errors: ['Not enough money']);

    final trialBuild = rig.build.copyWith(storageIds: [...rig.build.storageIds, itemId]);
    final (errors, ok) = validateBuild(trialBuild, rigKind: rig.kind);
    if (!ok) return ActionResult(ok: false, errors: errors);

    _state.money -= drive.price;
    rig.build = trialBuild;
    _save();
    notifyListeners();
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

  void resetGame() {
    _state = GameState.newDefault();
    _contractOffers = [];
    _acceptedOfferIds.clear();
    _lastDayReport = null;
    _regenerateContractOffers();
    _save();
    notifyListeners();
  }
}
