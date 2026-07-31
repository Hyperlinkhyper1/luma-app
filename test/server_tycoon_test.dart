import 'package:flutter_test/flutter_test.dart';
import 'dart:math' as math;

import 'package:luma/features/plugins/installed/server_tycoon/data/boosts.dart';
import 'package:luma/features/plugins/installed/server_tycoon/data/game_data.dart';
import 'package:luma/features/plugins/installed/server_tycoon/data/missions.dart';
import 'package:luma/features/plugins/installed/server_tycoon/game_state.dart';
import 'package:luma/features/plugins/installed/server_tycoon/server_tycoon_repository.dart';
import 'package:luma/features/plugins/installed/server_tycoon/sim/computer_sim.dart';
import 'package:luma/features/plugins/installed/server_tycoon/sim/service_sim.dart';
import 'package:luma/storage/storage_guard.dart';

/// A rig with one service on it, so load and income are non-zero.
ServiceInstance _instance({int capacity = 4}) => ServiceInstance(
      instanceId: 'i1',
      serviceTypeId: 'STATIC_WEBSITE',
      capacity: capacity,
    );

void main() {
  setUpAll(() {
    // The repository reaches for path_provider on construction; without a
    // binding that call throws before its own try/catch can swallow it.
    TestWidgetsFlutterBinding.ensureInitialized();
    // Every repository write consults the app-wide storage cap; outside of
    // main.dart's real startup this static is never set.
    StorageGuardService.instance = StorageGuardService();
  });

  group('research effects', () {
    test('a single owned project contributes its own bonus', () {
      final effects = getResearchEffects({'POWER_TUNING'});
      expect(effects.electricityDiscount, closeTo(0.10, 1e-9));
      expect(effects.cpuBoost, 0);
    });

    test('bonuses of the same kind add up across the tree', () {
      final effects = getResearchEffects({'KERNEL_TUNING', 'HYPERVISOR_OPTIMIZATION'});
      expect(effects.cpuBoost, closeTo(0.20, 1e-9));
    });

    test('a project with a downside applies it too', () {
      // Overclock Profiles buys CPU capacity at the cost of cooling headroom.
      final effects = getResearchEffects({'OVERCLOCK_PROFILES'});
      expect(effects.cpuBoost, closeTo(0.15, 1e-9));
      expect(effects.coolingEfficiency, closeTo(-0.10, 1e-9));
    });

    test('repeatable projects stack by level, not by presence', () {
      final once = getResearchEffects({}, levels: {'CONTINUOUS_OPTIMIZATION': 1});
      final thrice = getResearchEffects({}, levels: {'CONTINUOUS_OPTIMIZATION': 3});
      expect(once.incomeBonus, closeTo(0.02, 1e-9));
      expect(thrice.incomeBonus, closeTo(0.06, 1e-9));
    });

    test('a repeatable project in the owned set is not double-counted', () {
      final effects = getResearchEffects(
        {'CONTINUOUS_OPTIMIZATION'},
        levels: {'CONTINUOUS_OPTIMIZATION': 2},
      );
      expect(effects.incomeBonus, closeTo(0.04, 1e-9));
    });

    test('discounts are clamped so the power bill never goes negative', () {
      final everything = researchList.map((p) => p.id).toSet();
      final effects = getResearchEffects(everything);
      expect(effects.electricityDiscount, lessThanOrEqualTo(0.6));
      expect(effects.rigCostDiscount, lessThanOrEqualTo(0.5));
      expect(effects.satisfactionBonus, lessThanOrEqualTo(0.3));
    });

    test('the lab branch is what raises the queue slot count', () {
      expect(getResearchEffects({}).queueSlots, 1);
      expect(getResearchEffects({'HOME_LAB', 'RESEARCH_WING'}).queueSlots, 2);
      expect(getResearchEffects({'HOME_LAB', 'RESEARCH_WING', 'RND_DIVISION'}).queueSlots, 3);
    });

    test('every prerequisite refers to a project that exists', () {
      for (final project in researchList) {
        for (final requirement in project.requires) {
          expect(researchById.containsKey(requirement), isTrue,
              reason: '${project.id} requires unknown $requirement');
        }
      }
    });

    test('a prerequisite always sits at a lower tier than its dependant', () {
      for (final project in researchList) {
        for (final requirement in project.requires) {
          expect(researchById[requirement]!.tier, lessThan(project.tier),
              reason: '${project.id} requires a same-or-higher tier project');
        }
      }
    });
  });

  group('research point rate', () {
    test('is non-zero even with nothing built, so tier 1 is reachable', () {
      final rate = researchPointsPerDay(rigsServingTraffic: 0, rpPerDayBonus: 0, prestigeLevel: 0);
      expect(rate, greaterThan(0));
    });

    test('rises with rigs actually serving traffic', () {
      final idle = researchPointsPerDay(rigsServingTraffic: 0, rpPerDayBonus: 0, prestigeLevel: 0);
      final busy = researchPointsPerDay(rigsServingTraffic: 4, rpPerDayBonus: 0, prestigeLevel: 0);
      expect(busy, greaterThan(idle));
    });

    test('prestige scales the whole rate', () {
      final base = researchPointsPerDay(rigsServingTraffic: 2, rpPerDayBonus: 1, prestigeLevel: 0);
      final prestiged = researchPointsPerDay(rigsServingTraffic: 2, rpPerDayBonus: 1, prestigeLevel: 2);
      expect(prestiged, closeTo(base * 1.3, 1e-9));
    });
  });

  group('repeatable project pricing', () {
    final project = researchById['CONTINUOUS_OPTIMIZATION']!;

    test('level 0 costs the base price', () {
      expect(project.costAtLevel(0), project.cost);
    });

    test('each level costs more than the last', () {
      expect(project.costAtLevel(1), greaterThan(project.costAtLevel(0)));
      expect(project.costAtLevel(4), greaterThan(project.costAtLevel(3)));
      expect(project.rpCostAtLevel(2), greaterThan(project.rpCostAtLevel(1)));
    });

    test('a one-off project ignores the level entirely', () {
      final oneOff = researchById['POWER_TUNING']!;
      expect(oneOff.costAtLevel(5), oneOff.cost);
    });
  });

  group('boost effects', () {
    test('nothing running is a no-op', () {
      const none = BoostEffects.none;
      expect(none.incomeMultiplier, 1.0);
      expect(none.extraContractOffers, 0);
    });

    test('an expired boost contributes nothing', () {
      final effects = getBoostEffects([ActiveBoost(defId: 'SURGE_PRICING', daysRemaining: 0)]);
      expect(effects.incomeMultiplier, 1.0);
    });

    test('overclock trades power for capacity', () {
      final effects = getBoostEffects([ActiveBoost(defId: 'OVERCLOCK', daysRemaining: 3)]);
      expect(effects.capacityMultiplier, greaterThan(1));
      expect(effects.powerMultiplier, greaterThan(1));
      expect(effects.coolingMultiplier, lessThan(1));
    });

    test('multipliers of the same kind compound', () {
      final effects = getBoostEffects([
        ActiveBoost(defId: 'SURGE_PRICING', daysRemaining: 2),
        ActiveBoost(defId: 'OVERCLOCK', daysRemaining: 1),
      ]);
      final surge = boostDefsById['SURGE_PRICING']!.incomeMultiplier;
      expect(effects.incomeMultiplier, closeTo(surge, 1e-9));
      expect(effects.capacityMultiplier, closeTo(boostDefsById['OVERCLOCK']!.capacityMultiplier, 1e-9));
    });

    test('stacked incident resistance approaches but never reaches certainty', () {
      final effects = getBoostEffects([
        ActiveBoost(defId: 'COLD_SNAP', daysRemaining: 3),
        ActiveBoost(defId: 'COLD_SNAP', daysRemaining: 3),
      ]);
      expect(effects.incidentResistance, greaterThan(0.25));
      expect(effects.incidentResistance, lessThan(1.0));
    });
  });

  group('missions', () {
    test('only objectives unlocked by the current day are rolled', () {
      final missions = rollMissions(0, math.Random(1), count: 9);
      for (final mission in missions) {
        expect(mission.def!.minDay, lessThanOrEqualTo(0));
      }
    });

    test('later days unlock more of the pool', () {
      final earlyPool = missionDefList.where((m) => m.minDay <= 0).length;
      final latePool = missionDefList.where((m) => m.minDay <= 30).length;
      expect(latePool, greaterThan(earlyPool));
    });

    test('a board holds distinct objectives', () {
      final missions = rollMissions(40, math.Random(7));
      expect(missions.map((m) => m.defId).toSet().length, missions.length);
    });

    test('scaling targets grow with the day count, flat ones do not', () {
      final scaling = missionDefsById['PROFITABLE_DAY']!;
      expect(scaling.targetForDay(30), greaterThan(scaling.targetForDay(0)));

      final flat = missionDefsById['EXPAND_SERVICES']!;
      expect(flat.targetForDay(30), flat.targetForDay(0));
    });

    test('rewards grow with the day count', () {
      final def = missionDefsById['EXPAND_SERVICES']!;
      expect(def.rewardForDay(50), greaterThan(def.rewardForDay(0)));
    });

    test('completion is measured against the target', () {
      final mission = Mission(defId: 'EXPAND_SERVICES', target: 2, rewardCash: 100, rewardRep: 1);
      expect(mission.complete, isFalse);
      mission.progress = 2;
      expect(mission.complete, isTrue);
      expect(mission.fraction, 1.0);
    });

    test('round-trips through JSON', () {
      final mission = Mission(
        defId: 'CLEAN_RUN',
        target: 1,
        rewardCash: 220,
        rewardRep: 1.5,
        progress: 1,
        rewarded: true,
      );
      final restored = Mission.fromJson(mission.toJson());
      expect(restored.defId, 'CLEAN_RUN');
      expect(restored.target, 1);
      expect(restored.rewardCash, 220);
      expect(restored.rewardRep, 1.5);
      expect(restored.progress, 1);
      expect(restored.rewarded, isTrue);
    });
  });

  group('sim modifiers', () {
    Build build() => newStarterBuild();

    test('storage compression lowers what a service needs on disk', () {
      final plain = calculateRigLoad('r', build(), [_instance()], RigKind.pc);
      final compressed = calculateRigLoad(
        'r',
        build(),
        [_instance()],
        RigKind.pc,
        modifiers: const SimModifiers(storageCompression: 0.5),
      );
      expect(compressed.required.storageGB, closeTo(plain.required.storageGB * 0.5, 1e-9));
    });

    test('bandwidth overhead research lowers required Mbps', () {
      final plain = calculateRigLoad('r', build(), [_instance()], RigKind.pc);
      final trimmed = calculateRigLoad(
        'r',
        build(),
        [_instance()],
        RigKind.pc,
        modifiers: const SimModifiers(bandwidthOverhead: 0.25),
      );
      expect(trimmed.required.bandwidthMbps, closeTo(plain.required.bandwidthMbps * 0.75, 1e-9));
    });

    test('a CPU multiplier raises usable capacity', () {
      final plain = calculateRigLoad('r', build(), [_instance()], RigKind.pc);
      final boosted = calculateRigLoad(
        'r',
        build(),
        [_instance()],
        RigKind.pc,
        modifiers: const SimModifiers(cpuCapacityMultiplier: 1.5),
      );
      expect(boosted.capacity.cpu, greaterThan(plain.capacity.cpu));
    });

    test('defaults leave the sim exactly as it was', () {
      final plain = calculateRigLoad('r', build(), [_instance()], RigKind.pc);
      final explicit = calculateRigLoad(
        'r',
        build(),
        [_instance()],
        RigKind.pc,
        modifiers: SimModifiers.none,
      );
      expect(explicit.required.storageGB, plain.required.storageGB);
      expect(explicit.capacity.cpu, plain.capacity.cpu);
      expect(explicit.localFactor, plain.localFactor);
    });
  });

  group('storage speed', () {
    Build withDrive(String driveId) => newStarterBuild().copyWith(storageIds: [driveId]);

    // Cloud storage is the disk-heavy workload: ~50GB per customer but almost
    // no RAM, so throughput binds before anything else does.
    List<ServiceInstance> heavyLoad() => [
          ServiceInstance(instanceId: 'i1', serviceTypeId: 'CLOUD_STORAGE', capacity: 30),
        ];

    test('an NVMe drive moves more data than a hard disk', () {
      final hdd = getDiskThroughputMBs(withDrive('WD_RED_4TB'));
      final nvme = getDiskThroughputMBs(withDrive('SAMSUNG_990_PRO_4TB'));
      expect(nvme, greaterThan(hdd * 10));
    });

    test('two drives supply more throughput than one', () {
      final one = getDiskThroughputMBs(withDrive('WD_RED_4TB'));
      final two = getDiskThroughputMBs(
        newStarterBuild().copyWith(storageIds: ['WD_RED_4TB', 'WD_RED_4TB']),
      );
      expect(two, closeTo(one * 2, 1e-9));
    });

    test('demand rises with both dataset size and traffic', () {
      final small = diskThroughputDemandMBs(storageGB: 10, bandwidthMbps: 1);
      final bigger = diskThroughputDemandMBs(storageGB: 1000, bandwidthMbps: 1);
      final busier = diskThroughputDemandMBs(storageGB: 10, bandwidthMbps: 50);
      expect(bigger, greaterThan(small));
      expect(busier, greaterThan(small));
    });

    test('two same-size drives are no longer interchangeable', () {
      // Both hold 4TB and both fit the starter board; only the speed differs.
      // Before this change the sim could not tell them apart at all.
      final onHdd = calculateRigLoad('r', withDrive('WD_RED_4TB'), heavyLoad(), RigKind.pc);
      final onSsd = calculateRigLoad('r', withDrive('SAMSUNG_870_EVO_4TB'), heavyLoad(), RigKind.pc);

      expect(onHdd.incompatible, isFalse);
      expect(onSsd.incompatible, isFalse);
      expect(onHdd.capacity.storageGB, onSsd.capacity.storageGB);
      expect(onHdd.utilization.disk, greaterThan(onSsd.utilization.disk));
      expect(onHdd.localFactor, lessThan(onSsd.localFactor));
    });

    test('a saturated disk is reported as the bottleneck', () {
      final result = calculateRigLoad('r', withDrive('WD_RED_4TB'), heavyLoad(), RigKind.pc);
      expect(result.utilization.disk, greaterThan(1));
      expect(result.localBottleneck, 'disk');
    });

    test('a light workload is not disk-bound on any drive', () {
      final result = calculateRigLoad(
        'r',
        withDrive('WD_RED_4TB'),
        [_instance(capacity: 4)],
        RigKind.pc,
      );
      expect(result.utilization.disk, lessThan(1));
      expect(result.localBottleneck, isNot('disk'));
    });

    test('compression research relieves the drives too', () {
      final plain = calculateRigLoad('r', withDrive('WD_RED_4TB'), heavyLoad(), RigKind.pc);
      final compressed = calculateRigLoad(
        'r',
        withDrive('WD_RED_4TB'),
        heavyLoad(),
        RigKind.pc,
        modifiers: const SimModifiers(storageCompression: 0.5),
      );
      expect(compressed.utilization.disk, lessThan(plain.utilization.disk));
    });

    test('a rig with no drives at all has no throughput', () {
      final build = newStarterBuild().copyWith(storageIds: <String>[]);
      expect(getDiskThroughputMBs(build), 0);
    });
  });

  group('satisfaction bonus', () {
    Map<String, RigInput> rigs({required List<ServiceInstance> services}) => {
          '1': RigInput(
            build: newStarterBuild(),
            services: services,
            kind: RigKind.pc,
            routerId: '1',
          ),
        };
    final routers = {'1': RouterInput(internetPlanId: 'HOME_25')};

    test('never pushes a happy customer past fully satisfied', () {
      final load = calculateAccountLoad(
        rigs(services: [_instance(capacity: 1)]),
        routers,
        modifiers: const SimModifiers(satisfactionBonus: 0.5),
      );
      for (final instance in load.instances) {
        expect(instance.satisfaction, lessThanOrEqualTo(1.0));
      }
    });

    test('cannot rescue a rig earning nothing at all', () {
      // An enormous service on a starter box drives satisfaction to zero via
      // the bandwidth cap; a flat bonus must not resurrect it.
      final load = calculateAccountLoad(
        rigs(services: [ServiceInstance(instanceId: 'i', serviceTypeId: 'STATIC_WEBSITE', capacity: 100000)]),
        {'1': RouterInput(internetPlanId: 'HOME_25')},
        modifiers: const SimModifiers(satisfactionBonus: 0.3),
      );
      for (final instance in load.instances) {
        expect(instance.satisfaction, greaterThanOrEqualTo(0.0));
        expect(instance.satisfaction, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('GameState persistence', () {
    test('round-trips every new field', () {
      final state = GameState.newDefault()
        ..researchPoints = 12.5
        ..researchQueue = ['KERNEL_TUNING']
        ..researchLevels = {'CONTINUOUS_OPTIMIZATION': 3}
        ..researchCompletedCount = 7
        ..activeResearch = ResearchProgress(projectId: 'HOME_LAB', rpNeeded: 4, rpAccrued: 1.5)
        ..activeBoosts = [ActiveBoost(defId: 'OVERCLOCK', daysRemaining: 2)]
        ..missions = [Mission(defId: 'CLEAN_RUN', target: 1, rewardCash: 200, rewardRep: 1)]
        ..missionsRolledForDay = 4
        ..autoConfirmDay = true
        ..gameSpeed = 4
        ..lastSeenEpochMs = 1700000000000;

      final restored = GameState.fromJson(state.toJson());

      expect(restored.researchPoints, 12.5);
      expect(restored.researchQueue, ['KERNEL_TUNING']);
      expect(restored.researchLevels, {'CONTINUOUS_OPTIMIZATION': 3});
      expect(restored.researchCompletedCount, 7);
      expect(restored.activeResearch?.projectId, 'HOME_LAB');
      expect(restored.activeResearch?.rpAccrued, 1.5);
      expect(restored.activeBoosts.single.defId, 'OVERCLOCK');
      expect(restored.missions.single.defId, 'CLEAN_RUN');
      expect(restored.missionsRolledForDay, 4);
      expect(restored.autoConfirmDay, isTrue);
      expect(restored.gameSpeed, 4);
      expect(restored.lastSeenEpochMs, 1700000000000);
    });

    test('a save written before this update still loads', () {
      // Exactly the fields the old GameState.toJson emitted.
      final legacy = <String, dynamic>{
        'money': 1234.5,
        'reputation': 12.0,
        'dayCount': 9,
        'rigs': <String, dynamic>{},
        'routers': <String, dynamic>{},
        'nextRigId': 2,
        'nextRouterId': 2,
        'nextInstanceId': 1,
        'nextContractId': 1,
        'licenses': ['GAME_HOSTING'],
        'research': ['POWER_TUNING'],
        'contracts': <dynamic>[],
        'peakPowerDrawWatts': 90.0,
        'powerHistory': <dynamic>[],
        'incomeHistory': <dynamic>[],
      };

      final state = GameState.fromJson(legacy);

      expect(state.money, 1234.5);
      expect(state.research, {'POWER_TUNING'});
      // New machinery defaults rather than throwing.
      expect(state.researchPoints, 0);
      expect(state.activeResearch, isNull);
      expect(state.researchQueue, isEmpty);
      expect(state.activeBoosts, isEmpty);
      expect(state.missions, isEmpty);
      expect(state.gameSpeed, 1);
      expect(state.autoConfirmDay, isFalse);
      expect(state.lastSeenEpochMs, 0);
    });

    test('services nested inside rigs are hoisted onto the canvas', () {
      // How saves looked before services became nodes.
      final legacy = <String, dynamic>{
        'money': 500.0,
        'reputation': 0.0,
        'dayCount': 3,
        'rigs': {
          '1': {
            'rigId': '1',
            'name': 'Rig 1',
            'kind': 'pc',
            'build': newStarterBuild().toJson(),
            'services': [
              {'instanceId': '7', 'serviceTypeId': 'STATIC_WEBSITE', 'capacity': 28},
              {'instanceId': '8', 'serviceTypeId': 'DISCORD_BOT', 'capacity': 1},
            ],
            'routerId': '1',
            'pos': {'x': 380.0, 'y': 60.0},
          },
        },
        'routers': {
          '1': {'routerId': '1', 'name': 'Router 1', 'internetPlanId': 'HOME_25', 'pos': {'x': 60.0, 'y': 60.0}},
        },
        'nextRigId': 2,
        'nextRouterId': 2,
        'nextInstanceId': 9,
        'nextContractId': 1,
        'licenses': <String>[],
        'research': <String>[],
        'contracts': <dynamic>[],
        'peakPowerDrawWatts': 0.0,
        'powerHistory': <dynamic>[],
        'incomeHistory': <dynamic>[],
      };

      final state = GameState.fromJson(legacy);

      expect(state.services.length, 2);
      expect(state.services['7']!.serviceTypeId, 'STATIC_WEBSITE');
      expect(state.services['7']!.capacity, 28);
      // Still wired to the rig they were running on, so nothing goes offline.
      expect(state.services['7']!.rigId, '1');
      expect(state.services['8']!.rigId, '1');
      // And they get distinct spots rather than stacking at the origin.
      expect(state.services['7']!.pos.y, isNot(state.services['8']!.pos.y));
      expect(state.rigs['1']!.routerId, '1');
    });

    test('a rig saved without a router loads as unwired', () {
      final json = GameState.newDefault().toJson();
      (json['rigs'] as Map)['1']['routerId'] = null;
      expect(GameState.fromJson(json).rigs['1']!.routerId, isNull);
    });

    test('service nodes round-trip', () {
      final state = GameState.newDefault();
      state.services['7'] = ServiceNode(
        instanceId: '7',
        serviceTypeId: 'STATIC_WEBSITE',
        capacity: 12,
        rigId: '1',
        pos: NodePos(x: 80, y: 140),
      );

      final restored = GameState.fromJson(state.toJson());
      final service = restored.services['7']!;
      expect(service.serviceTypeId, 'STATIC_WEBSITE');
      expect(service.capacity, 12);
      expect(service.rigId, '1');
      expect(service.pos.x, 80);
      expect(service.pos.y, 140);
    });

    test('a nonsense game speed falls back to 1x rather than stalling the clock', () {
      final state = GameState.fromJson({
        ...GameState.newDefault().toJson(),
        'gameSpeed': 0,
      });
      expect(state.gameSpeed, 1);
    });
  });

  group('ServerTycoonRepository', () {
    late ServerTycoonRepository repo;

    setUp(() {
      repo = ServerTycoonRepository();
      // The 1s day timer would otherwise process days underneath the tests.
      repo.pause();
      repo.state.money = 100000;
    });

    tearDown(() => repo.dispose());

    String firstRigId() => repo.state.rigs.keys.first;

    group('research queue', () {
      test('queueing charges cash up front and starts the project', () {
        final before = repo.state.money;
        final project = researchById['KERNEL_TUNING']!;

        final result = repo.queueResearch('KERNEL_TUNING');

        expect(result.ok, isTrue);
        expect(repo.state.money, closeTo(before - project.cost, 1e-9));
        expect(repo.state.activeResearch?.projectId, 'KERNEL_TUNING');
        // Cash alone does not grant the effect — it has to be researched.
        expect(repo.state.research.contains('KERNEL_TUNING'), isFalse);
      });

      test('the project completes once enough days have passed', () {
        repo.queueResearch('KERNEL_TUNING');
        final needed = repo.state.activeResearch!.rpNeeded;
        final perDay = repo.researchPointsPerDayNow;
        final days = (needed / perDay).ceil();

        for (var i = 0; i < days; i++) {
          repo.processDay();
        }

        expect(repo.state.research.contains('KERNEL_TUNING'), isTrue);
        expect(repo.state.activeResearch, isNull);
        expect(repo.effects.cpuBoost, greaterThan(0));
      });

      test('a single day is not enough for a real project', () {
        repo.queueResearch('KERNEL_TUNING');
        repo.processDay();
        expect(repo.state.research.contains('KERNEL_TUNING'), isFalse);
        expect(repo.state.activeResearch, isNotNull);
      });

      test('the queue is limited to the slots the lab branch has unlocked', () {
        expect(repo.effects.queueSlots, 1);
        expect(repo.queueResearch('KERNEL_TUNING').ok, isTrue);
        // Both of these are reputation-free tier 1 projects, so the only
        // thing that can refuse the second one is the slot count.
        expect(repo.queueResearch('MESH_NETWORKING').ok, isFalse);
      });

      test('a second slot lets a project wait behind the active one', () {
        repo.state.research.addAll({'HOME_LAB', 'RESEARCH_WING'});
        expect(repo.effects.queueSlots, 2);

        expect(repo.queueResearch('KERNEL_TUNING').ok, isTrue);
        expect(repo.queueResearch('MESH_NETWORKING').ok, isTrue);
        expect(repo.state.activeResearch?.projectId, 'KERNEL_TUNING');
        expect(repo.state.researchQueue, ['MESH_NETWORKING']);
      });

      test('locked prerequisites are refused', () {
        final result = repo.queueResearch('HYPERVISOR_OPTIMIZATION');
        expect(result.ok, isFalse);
        expect(repo.state.activeResearch, isNull);
      });

      test('a project already owned cannot be queued again', () {
        repo.state.research.add('POWER_TUNING');
        expect(repo.queueResearch('POWER_TUNING').ok, isFalse);
      });

      test('too little cash is refused without touching the queue', () {
        repo.state.money = 1;
        expect(repo.queueResearch('KERNEL_TUNING').ok, isFalse);
        expect(repo.state.activeResearch, isNull);
      });

      test('a repeatable project raises its level instead of joining the owned set', () {
        repo.state.research.addAll({'HOME_LAB', 'RESEARCH_WING', 'RND_DIVISION'});
        repo.state.reputation = 60;

        expect(repo.queueResearch('CONTINUOUS_OPTIMIZATION').ok, isTrue);
        for (var i = 0; i < 200 && repo.state.activeResearch != null; i++) {
          repo.processDay();
        }

        expect(repo.state.researchLevels['CONTINUOUS_OPTIMIZATION'], 1);
        expect(repo.state.research.contains('CONTINUOUS_OPTIMIZATION'), isFalse);
        expect(repo.effects.incomeBonus, closeTo(0.02, 1e-9));
      });

      test('the second level of a repeatable costs more than the first', () {
        repo.state.research.addAll({'HOME_LAB', 'RESEARCH_WING', 'RND_DIVISION'});
        repo.state.reputation = 60;
        repo.state.researchLevels['CONTINUOUS_OPTIMIZATION'] = 1;

        final project = researchById['CONTINUOUS_OPTIMIZATION']!;
        final before = repo.state.money;
        repo.queueResearch('CONTINUOUS_OPTIMIZATION');

        expect(before - repo.state.money, greaterThan(project.cost));
      });

      test('cancelling refunds half the cash and clears the slot', () {
        final project = researchById['KERNEL_TUNING']!;
        final before = repo.state.money;
        repo.queueResearch('KERNEL_TUNING');

        expect(repo.cancelResearch('KERNEL_TUNING').ok, isTrue);
        expect(repo.state.activeResearch, isNull);
        expect(repo.state.money, closeTo(before - project.cost * 0.5, 1e-9));
      });

      test('cancelling something that was never queued fails', () {
        expect(repo.cancelResearch('KERNEL_TUNING').ok, isFalse);
      });
    });

    group('boosts', () {
      test('buying charges the price and starts the clock', () {
        final def = boostDefsById['SURGE_PRICING']!;
        final before = repo.state.money;

        expect(repo.buyBoost('SURGE_PRICING').ok, isTrue);
        expect(repo.state.money, closeTo(before - def.cost, 1e-9));
        expect(repo.state.activeBoosts.single.daysRemaining, def.durationDays);
      });

      test('it wears off after its duration', () {
        final def = boostDefsById['SURGE_PRICING']!;
        repo.buyBoost('SURGE_PRICING');

        for (var i = 0; i < def.durationDays; i++) {
          repo.processDay();
        }

        expect(repo.state.activeBoosts, isEmpty);
        expect(repo.boostEffects.incomeMultiplier, 1.0);
      });

      test('re-buying tops the clock up instead of stacking a second copy', () {
        final def = boostDefsById['SURGE_PRICING']!;
        repo.buyBoost('SURGE_PRICING');
        repo.processDay();
        expect(repo.state.activeBoosts.single.daysRemaining, def.durationDays - 1);

        repo.buyBoost('SURGE_PRICING');
        expect(repo.state.activeBoosts.length, 1);
        expect(repo.state.activeBoosts.single.daysRemaining, def.durationDays);
      });

      test('an unaffordable boost is refused', () {
        repo.state.money = 1;
        expect(repo.buyBoost('SURGE_PRICING').ok, isFalse);
        expect(repo.state.activeBoosts, isEmpty);
      });
    });

    group('daily goals', () {
      test('a board is rolled for the current day', () {
        expect(repo.state.missions, isNotEmpty);
        expect(repo.state.missionsRolledForDay, repo.state.dayCount);
      });

      test('installing services advances the matching goal and pays out', () {
        repo.state.missions = [
          Mission(defId: 'EXPAND_SERVICES', target: 2, rewardCash: 200, rewardRep: 1),
        ];
        final before = repo.state.money;
        final rigId = firstRigId();

        repo.installService(rigId, 'STATIC_WEBSITE', 1);
        expect(repo.state.missions.single.progress, 1);
        expect(repo.state.missions.single.rewarded, isFalse);

        repo.installService(rigId, 'STATIC_WEBSITE', 1);
        expect(repo.state.missions.single.rewarded, isTrue);
        expect(repo.state.money, closeTo(before + 200, 1e-9));
      });

      test('a goal pays out only once', () {
        repo.state.missions = [
          Mission(defId: 'EXPAND_SERVICES', target: 1, rewardCash: 200, rewardRep: 1),
        ];
        final rigId = firstRigId();

        repo.installService(rigId, 'STATIC_WEBSITE', 1);
        final afterFirst = repo.state.money;
        repo.installService(rigId, 'STATIC_WEBSITE', 1);

        expect(repo.state.money, closeTo(afterFirst, 1e-9));
      });

      test('the board is replaced at the day rollover', () {
        final dayBefore = repo.state.dayCount;
        repo.processDay();
        expect(repo.state.missionsRolledForDay, repo.state.dayCount);
        expect(repo.state.dayCount, dayBefore + 1);
      });
    });

    group('away earnings', () {
      void goOffline(int days) {
        repo.state.lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch -
            days * ServerTycoonRepository.offlineMsPerDay;
      }

      test('a short absence pays nothing', () {
        repo.state.lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch - 1000;
        repo.catchUpOnAwayTime();
        expect(repo.lastAwayReport, isNull);
      });

      test('a first run with no recorded timestamp pays nothing', () {
        repo.state.lastSeenEpochMs = 0;
        repo.catchUpOnAwayTime();
        expect(repo.lastAwayReport, isNull);
      });

      test('a clock that jumped backwards pays nothing', () {
        repo.state.lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch + 86400000;
        final before = repo.state.money;

        repo.catchUpOnAwayTime();

        expect(repo.lastAwayReport, isNull);
        expect(repo.state.money, closeTo(before, 1e-9));
      });

      test('days away are simulated and reported', () {
        final dayBefore = repo.state.dayCount;
        goOffline(3);

        repo.catchUpOnAwayTime();

        final report = repo.lastAwayReport;
        expect(report, isNotNull);
        expect(report!.daysSimulated, 3);
        expect(repo.state.dayCount, dayBefore + 3);
        expect(report.capped, isFalse);
      });

      test('catch-up is capped, and the report says so', () {
        goOffline(500);

        repo.catchUpOnAwayTime();

        final report = repo.lastAwayReport!;
        expect(report.daysSimulated, GameState.maxOfflineDays);
        expect(report.daysElapsed, greaterThan(GameState.maxOfflineDays));
        expect(report.capped, isTrue);
      });

      test('offline days pay less than played days', () {
        repo.installService(firstRigId(), 'STATIC_WEBSITE', 2);

        final online = ServerTycoonRepository()
          ..pause()
          ..state.money = 100000;
        online.installService(online.state.rigs.keys.first, 'STATIC_WEBSITE', 2);
        final onlineReport = online.processDay()!;
        expect(onlineReport.income, greaterThan(0),
            reason: 'the comparison is meaningless if nothing is earning');

        goOffline(1);
        repo.catchUpOnAwayTime();
        final awayReport = repo.lastAwayReport!;

        expect(awayReport.rate, lessThan(1.0));
        expect(awayReport.income, lessThan(onlineReport.income));
        online.dispose();
      });

      test('lab research raises the away rate', () {
        final base = repo.offlineRate;
        repo.state.research.add('AUTOMATED_TELEMETRY');
        expect(repo.offlineRate, greaterThan(base));
      });

      test('the away rate can never exceed a full day', () {
        repo.state.research.addAll({'AUTOMATED_TELEMETRY', 'LIGHTS_OUT_OPERATIONS'});
        expect(repo.offlineRate, lessThanOrEqualTo(1.0));
      });

      test('an offline day leaves no day report queued behind the Next Day gate', () {
        goOffline(2);
        repo.catchUpOnAwayTime();
        expect(repo.lastDayReport, isNull);
      });

      test('research still accrues while away', () {
        repo.queueResearch('KERNEL_TUNING');
        final before = repo.state.activeResearch!.rpAccrued;

        goOffline(2);
        repo.catchUpOnAwayTime();

        final active = repo.state.activeResearch;
        // Either it made progress or it finished outright.
        final progressed = active == null || active.rpAccrued > before;
        expect(progressed, isTrue);
        expect(repo.lastAwayReport!.researchPointsEarned, greaterThan(0));
      });
    });

    group('quick actions', () {
      test('clone copies the build but not the services', () {
        final rigId = firstRigId();
        repo.installService(rigId, 'STATIC_WEBSITE', 2);
        final source = repo.state.rigs[rigId]!;

        expect(repo.cloneRig(rigId).ok, isTrue);

        final clone = repo.state.rigs.values.firstWhere((r) => r.rigId != rigId);
        expect(clone.build.cpuId, source.build.cpuId);
        expect(clone.build.ramIds, source.build.ramIds);
        expect(clone.routerId, source.routerId);
        // Services are their own nodes, so a clone starts unplugged.
        expect(repo.state.services.values.where((s) => s.rigId == clone.rigId), isEmpty);
      });

      test('cloning is refused when it cannot be paid for', () {
        repo.state.money = 0;
        expect(repo.cloneRig(firstRigId()).ok, isFalse);
        expect(repo.state.rigs.length, 1);
      });

      test('an unloaded rig has no bottleneck to fix', () {
        expect(repo.bottleneckFixFor(firstRigId()), isNull);
        expect(repo.fixBottleneck(firstRigId()).ok, isFalse);
      });

      test('a loaded rig gets a concrete part suggested and installed', () {
        final rigId = firstRigId();
        // Enough load to bottleneck a starter box somewhere.
        repo.installService(rigId, 'STATIC_WEBSITE', 400);

        expect(repo.calculateLoad().rigs[rigId]!.localBottleneck, isNotNull,
            reason: '400 units on a starter box has to bottleneck somewhere');
        expect(repo.bottleneckFixFor(rigId), isNotNull,
            reason: 'an affordable upgrade exists for every starter bottleneck');

        final before = repo.state.rigs[rigId]!.build;
        expect(repo.fixBottleneck(rigId).ok, isTrue);

        final after = repo.state.rigs[rigId]!.build;
        final changed = after.cpuId != before.cpuId ||
            after.nicId != before.nicId ||
            after.ramIds.length != before.ramIds.length ||
            after.storageIds.length != before.storageIds.length;
        expect(changed, isTrue, reason: 'the suggested part should end up on the rig');
      });

      test('a fix that costs money is charged for', () {
        final rigId = firstRigId();
        repo.installService(rigId, 'STATIC_WEBSITE', 400);

        final fix = repo.bottleneckFixFor(rigId)!;
        final before = repo.state.money;
        expect(repo.fixBottleneck(rigId).ok, isTrue);

        // The starter RAM stick is deliberately free, so only assert a charge
        // when the suggested part actually has a price.
        if (fix.$4 > 0) {
          expect(repo.state.money, closeTo(before - fix.$4, 1e-9));
        } else {
          expect(repo.state.money, closeTo(before, 1e-9));
        }
      });

      test('upgrading a router moves it to a faster plan', () {
        final routerId = repo.state.routers.keys.first;
        final before = internetPlansById[repo.state.routers[routerId]!.internetPlanId]!.upMbps;

        expect(repo.upgradeRouterPlan(routerId).ok, isTrue);

        final after = internetPlansById[repo.state.routers[routerId]!.internetPlanId]!.upMbps;
        expect(after, greaterThan(before));
      });

      test('auto-arrange lines rigs up beside their router', () {
        repo.cloneRig(firstRigId());
        repo.cloneRig(firstRigId());

        expect(repo.autoArrange().ok, isTrue);

        final router = repo.state.routers.values.first;
        for (final rig in repo.state.rigs.values) {
          expect(rig.pos.x, greaterThan(router.pos.x));
          expect(rig.pos.x, lessThanOrEqualTo(GameState.canvasMaxX));
          expect(rig.pos.y, lessThanOrEqualTo(GameState.canvasMaxY));
        }
      });

      test('no two nodes end up stacked on the same spot', () {
        repo.cloneRig(firstRigId());
        repo.cloneRig(firstRigId());
        repo.autoArrange();

        final positions = <String>{};
        for (final rig in repo.state.rigs.values) {
          expect(positions.add('${rig.pos.x},${rig.pos.y}'), isTrue);
        }
      });
    });

    group('node wiring', () {
      test('a service dropped on the canvas is unplugged and earns nothing', () {
        expect(repo.installService(null, 'STATIC_WEBSITE', 4).ok, isTrue);

        final service = repo.state.services.values.single;
        expect(service.rigId, isNull);
        expect(repo.servicesByRig(), isEmpty);
        expect(repo.calculateLoad().totalIncomePerDay, 0);
      });

      test('wiring it to a rig brings it online', () {
        repo.installService(null, 'STATIC_WEBSITE', 4);
        final instanceId = repo.state.services.keys.first;

        expect(repo.connectNodes('service', instanceId, 'rig', firstRigId()).ok, isTrue);
        expect(repo.state.services[instanceId]!.rigId, firstRigId());
        expect(repo.calculateLoad().totalIncomePerDay, greaterThan(0));
      });

      test('dragging the link the other way round means the same thing', () {
        repo.installService(null, 'STATIC_WEBSITE', 4);
        final instanceId = repo.state.services.keys.first;

        expect(repo.connectNodes('rig', firstRigId(), 'service', instanceId).ok, isTrue);
        expect(repo.state.services[instanceId]!.rigId, firstRigId());
      });

      test('unplugging a service stops it earning without deleting it', () {
        repo.installService(firstRigId(), 'STATIC_WEBSITE', 4);
        final instanceId = repo.state.services.keys.first;
        expect(repo.calculateLoad().totalIncomePerDay, greaterThan(0));

        expect(repo.disconnectNode('service', instanceId).ok, isTrue);
        expect(repo.state.services.containsKey(instanceId), isTrue);
        expect(repo.calculateLoad().totalIncomePerDay, 0);
      });

      test('an unwired rig serves nothing even with services attached', () {
        repo.installService(firstRigId(), 'STATIC_WEBSITE', 4);
        expect(repo.calculateLoad().totalIncomePerDay, greaterThan(0));

        expect(repo.disconnectNode('rig', firstRigId()).ok, isTrue);
        expect(repo.state.rigs[firstRigId()]!.routerId, isNull);
        expect(repo.calculateLoad().totalIncomePerDay, 0);
      });

      test('a rig can be rewired to a router', () {
        repo.disconnectNode('rig', firstRigId());
        final routerId = repo.state.routers.keys.first;

        expect(repo.connectNodes('rig', firstRigId(), 'router', routerId).ok, isTrue);
        expect(repo.state.rigs[firstRigId()]!.routerId, routerId);
      });

      test('nonsense connections are refused', () {
        final routerId = repo.state.routers.keys.first;
        repo.installService(null, 'STATIC_WEBSITE', 1);
        final instanceId = repo.state.services.keys.first;

        expect(repo.connectNodes('service', instanceId, 'router', routerId).ok, isFalse);
        expect(repo.connectNodes('rig', firstRigId(), 'rig', firstRigId()).ok, isFalse);
        expect(repo.connectNodes('service', instanceId, 'rig', 'nope').ok, isFalse);
      });

      test('deleting a rig leaves its services orphaned rather than earning', () {
        repo.installService(firstRigId(), 'STATIC_WEBSITE', 4);
        repo.state.rigs.remove(firstRigId());

        expect(repo.servicesByRig(), isEmpty);
        expect(repo.calculateLoad().totalIncomePerDay, 0);
      });

      test('new service nodes do not land on top of each other', () {
        for (var i = 0; i < 5; i++) {
          repo.installService(null, 'STATIC_WEBSITE', 1);
        }
        final spots = repo.state.services.values.map((s) => '${s.pos.x},${s.pos.y}').toSet();
        expect(spots.length, repo.state.services.length);
      });

      test('every kind of node can be dragged to a new spot', () {
        repo.installService(null, 'STATIC_WEBSITE', 1);
        final instanceId = repo.state.services.keys.first;
        final routerId = repo.state.routers.keys.first;

        expect(repo.moveNode('rig', firstRigId(), 500, 250).ok, isTrue);
        expect(repo.moveNode('router', routerId, 120, 300).ok, isTrue);
        // Services were left out of moveNode when they became nodes, so they
        // rendered mid-drag and then snapped straight back on release.
        expect(repo.moveNode('service', instanceId, 900, 400).ok, isTrue);

        expect(repo.state.rigs[firstRigId()]!.pos.x, 500);
        expect(repo.state.routers[routerId]!.pos.y, 300);
        expect(repo.state.services[instanceId]!.pos.x, 900);
        expect(repo.state.services[instanceId]!.pos.y, 400);
      });

      test('a moved service keeps its position across a save round-trip', () {
        repo.installService(null, 'STATIC_WEBSITE', 1);
        final instanceId = repo.state.services.keys.first;
        repo.moveNode('service', instanceId, 640, 220);

        final restored = GameState.fromJson(repo.state.toJson());
        expect(restored.services[instanceId]!.pos.x, 640);
        expect(restored.services[instanceId]!.pos.y, 220);
      });

      test('dragging an unknown node is refused rather than silently ignored', () {
        expect(repo.moveNode('service', 'nope', 10, 10).ok, isFalse);
        expect(repo.moveNode('gizmo', '1', 10, 10).ok, isFalse);
      });

      test('nodes are kept inside the canvas bounds', () {
        repo.installService(null, 'STATIC_WEBSITE', 1);
        final instanceId = repo.state.services.keys.first;

        repo.moveNode('service', instanceId, -500, 99999);
        expect(repo.state.services[instanceId]!.pos.x, 0);
        expect(repo.state.services[instanceId]!.pos.y, GameState.canvasMaxY);
      });

      test('auto-arrange places services beside the rig they feed', () {
        repo.installService(firstRigId(), 'STATIC_WEBSITE', 1);
        repo.installService(firstRigId(), 'DISCORD_BOT', 1);

        expect(repo.autoArrange().ok, isTrue);

        final rig = repo.state.rigs[firstRigId()]!;
        final router = repo.state.routers.values.first;
        for (final service in repo.state.services.values) {
          expect(service.pos.x, greaterThan(rig.pos.x));
        }
        expect(rig.pos.x, greaterThan(router.pos.x));
      });
    });

    group('day speed', () {
      test('only the offered speeds are accepted', () {
        repo.setGameSpeed(4);
        expect(repo.state.gameSpeed, 4);

        repo.setGameSpeed(7);
        expect(repo.state.gameSpeed, 4);
      });

      test('a faster clock shortens the wait for the next day', () {
        repo.setGameSpeed(1);
        final slow = repo.secondsRemaining;
        repo.setGameSpeed(4);
        expect(repo.secondsRemaining, lessThan(slow));
      });
    });
  });
}
