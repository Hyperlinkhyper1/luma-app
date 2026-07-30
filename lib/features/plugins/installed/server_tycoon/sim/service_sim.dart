// Auto-ported from Roblox Server Hosting Tycoon
// Two-tier load simulation.

import '../data/game_data.dart';
import 'computer_sim.dart';

class ServiceInstance {
  final String instanceId;
  final String serviceTypeId;
  int capacity;

  ServiceInstance({required this.instanceId, required this.serviceTypeId, required this.capacity});

  Map<String, dynamic> toJson() => {
    'instanceId': instanceId,
    'serviceTypeId': serviceTypeId,
    'capacity': capacity,
  };

  factory ServiceInstance.fromJson(Map<String, dynamic> json) => ServiceInstance(
    instanceId: json['instanceId'] as String,
    serviceTypeId: json['serviceTypeId'] as String,
    capacity: json['capacity'] as int,
  );
}

/// Account-wide multipliers folded in from research and active boosts. The sim
/// itself stays ignorant of where they came from — the repository composes
/// [ResearchEffects] and [BoostEffects] into one of these before calling in.
class SimModifiers {
  /// Scales usable CPU score (research cpuBoost × boost capacity).
  final double cpuCapacityMultiplier;

  /// Scales cooling headroom (research coolingEfficiency × boost cooling).
  final double coolingMultiplier;

  /// Fraction shaved off every service's storage requirement, 0–1.
  final double storageCompression;

  /// Fraction shaved off every service's bandwidth requirement, 0–1.
  final double bandwidthOverhead;

  /// Added to each instance's satisfaction before it is capped at 1.
  final double satisfactionBonus;

  /// Scales service income.
  final double incomeMultiplier;

  const SimModifiers({
    this.cpuCapacityMultiplier = 1.0,
    this.coolingMultiplier = 1.0,
    this.storageCompression = 0,
    this.bandwidthOverhead = 0,
    this.satisfactionBonus = 0,
    this.incomeMultiplier = 1.0,
  });

  static const none = SimModifiers();
}

class RigInput {
  final Build build;
  final List<ServiceInstance> services;
  final RigKind kind;
  String routerId;

  RigInput({required this.build, required this.services, required this.kind, required this.routerId});
}

class RouterInput {
  String internetPlanId;

  RouterInput({required this.internetPlanId});
}

class RequiredResources {
  final double cpu;
  final double ramGB;
  final double storageGB;
  final double bandwidthMbps;

  /// Sustained disk throughput the workload needs, in MB/s. Derived from how
  /// much data is parked on the rig and how hard it is being served — see
  /// [diskThroughputDemandMBs].
  final double diskMBs;

  const RequiredResources({
    required this.cpu,
    required this.ramGB,
    required this.storageGB,
    required this.bandwidthMbps,
    this.diskMBs = 0,
  });
}

/// How much disk throughput a workload of this size demands.
///
/// A large dataset costs IOPS even when idle (worse cache hit rates, more
/// seeking), and served traffic has to be read off the platter in the first
/// place. This is what makes a 4TB HDD and a 4TB NVMe behave differently
/// instead of being interchangeable buckets of gigabytes.
double diskThroughputDemandMBs({required double storageGB, required double bandwidthMbps}) =>
    storageGB * 0.12 + bandwidthMbps * 0.5;

class RigCapacity {
  final double cpu;
  final int ramGB;
  final int storageGB;
  final int nicMbps;
  final double diskMBs;

  const RigCapacity({
    required this.cpu,
    required this.ramGB,
    required this.storageGB,
    required this.nicMbps,
    this.diskMBs = 0,
  });
}

class Utilization {
  final double cpu;
  final double ramGB;
  final double storageGB;
  final double disk;

  const Utilization({
    required this.cpu,
    required this.ramGB,
    required this.storageGB,
    this.disk = 0,
  });
}

class RigLoadResult {
  final String rigId;
  final RequiredResources required;
  final RigCapacity capacity;
  final Utilization utilization;
  final double throttleFactor;
  final double tempRatio;
  final double cpuLoadFactor;
  final double nicCapFactor;
  final double localFactor;
  final String? localBottleneck;
  final bool incompatible;
  final List<String> incompatibilityReasons;

  const RigLoadResult({
    required this.rigId,
    required this.required,
    required this.capacity,
    required this.utilization,
    required this.throttleFactor,
    required this.tempRatio,
    required this.cpuLoadFactor,
    required this.nicCapFactor,
    required this.localFactor,
    this.localBottleneck,
    this.incompatible = false,
    this.incompatibilityReasons = const [],
  });
}

class RouterLoadResult {
  final String routerId;
  final String internetPlanId;
  double requiredBandwidth;
  final int bandwidthCapacity;
  double bandwidthFactor;
  final int latencyMs;
  int rigCount;

  RouterLoadResult({
    required this.routerId,
    required this.internetPlanId,
    required this.requiredBandwidth,
    required this.bandwidthCapacity,
    required this.bandwidthFactor,
    required this.latencyMs,
    required this.rigCount,
  });
}

class InstanceResult {
  final String instanceId;
  final String serviceTypeId;
  final String rigId;
  final int capacity;
  final double satisfaction;
  final double incomePerDay;
  final String? bottleneck;

  const InstanceResult({
    required this.instanceId,
    required this.serviceTypeId,
    required this.rigId,
    required this.capacity,
    required this.satisfaction,
    required this.incomePerDay,
    this.bottleneck,
  });
}

class AccountLoadResult {
  final Map<String, RigLoadResult> rigs;
  final Map<String, RouterLoadResult> routers;
  final double totalRequiredBandwidth;
  final double totalBandwidthCapacity;
  final double globalBandwidthFactor;
  final int maxLatencyMs;
  final List<InstanceResult> instances;
  final double totalIncomePerDay;
  final bool overloaded;

  const AccountLoadResult({
    required this.rigs,
    required this.routers,
    required this.totalRequiredBandwidth,
    required this.totalBandwidthCapacity,
    required this.globalBandwidthFactor,
    required this.maxLatencyMs,
    required this.instances,
    required this.totalIncomePerDay,
    required this.overloaded,
  });
}

RequiredResources _sumRequired(List<ServiceInstance> services, SimModifiers modifiers) {
  var cpu = 0.0, ramGB = 0.0, storageGB = 0.0, bandwidthMbps = 0.0;
  for (final inst in services) {
    final serviceType = servicesById[inst.serviceTypeId];
    if (serviceType == null) continue;
    cpu += serviceType.base.cpu + serviceType.perUnit.cpu * inst.capacity;
    ramGB += serviceType.base.ramGB + serviceType.perUnit.ramGB * inst.capacity;
    storageGB += serviceType.base.storageGB + serviceType.perUnit.storageGB * inst.capacity;
    bandwidthMbps += serviceType.base.bandwidthMbps + serviceType.perUnit.bandwidthMbps * inst.capacity;
  }
  // Disk demand follows the *effective* footprint, so compression and packet
  // shaping research relieve the drives too.
  final effectiveStorage = storageGB * (1 - modifiers.storageCompression);
  final effectiveBandwidth = bandwidthMbps * (1 - modifiers.bandwidthOverhead);

  return RequiredResources(
    cpu: cpu,
    ramGB: ramGB,
    storageGB: effectiveStorage,
    bandwidthMbps: effectiveBandwidth,
    diskMBs: diskThroughputDemandMBs(
      storageGB: effectiveStorage,
      bandwidthMbps: effectiveBandwidth,
    ),
  );
}

RigLoadResult calculateRigLoad(
  String rigId,
  Build build,
  List<ServiceInstance> services,
  RigKind kind, {
  double overheatThrottlePenalty = 0.0,
  double coolingCapacityReduction = 0.0,
  SimModifiers modifiers = SimModifiers.none,
}) {
  final req = _sumRequired(services, modifiers);
  final rawCapacity = getCapacity(build);
  final capacity = Capacity(
    cpuScore: rawCapacity.cpuScore * modifiers.cpuCapacityMultiplier,
    ramGB: rawCapacity.ramGB,
    storageGB: rawCapacity.storageGB,
    nicMbps: rawCapacity.nicMbps,
  );
  final (incompatibilityReasons, compatible) = validateBuild(build, rigKind: kind);
  final incompatible = !compatible;

  final double nominalCPULoadFactor = capacity.cpuScore > 0 ? (req.cpu / capacity.cpuScore).clamp(0, 1).toDouble() : 1.0;
  final (thermalThrottleFactor, tempRatio) = getThermals(
    build,
    nominalCPULoadFactor,
    coolingCapacityMultiplier: (1 - coolingCapacityReduction) * modifiers.coolingMultiplier,
  );
  final throttleFactor = thermalThrottleFactor * (1 - overheatThrottlePenalty);
  final effectiveCPUCapacity = capacity.cpuScore * throttleFactor;

  final diskCapacityMBs = getDiskThroughputMBs(build);

  final util = Utilization(
    cpu: effectiveCPUCapacity > 0 ? req.cpu / effectiveCPUCapacity : (req.cpu > 0 ? double.infinity : 0),
    ramGB: capacity.ramGB > 0 ? req.ramGB / capacity.ramGB : (req.ramGB > 0 ? double.infinity : 0),
    storageGB: capacity.storageGB > 0 ? req.storageGB / capacity.storageGB : (req.storageGB > 0 ? double.infinity : 0),
    disk: diskCapacityMBs > 0 ? req.diskMBs / diskCapacityMBs : (req.diskMBs > 0 ? double.infinity : 0),
  );

  final degradationCpu = util.cpu > 1 ? 1 / util.cpu : 1.0;
  final degradationRam = util.ramGB > 1 ? 1 / util.ramGB : 1.0;
  final degradationStorage = util.storageGB > 1 ? 1 / util.storageGB : 1.0;
  final degradationDisk = util.disk > 1 ? 1 / util.disk : 1.0;

  var nicCapFactor = 1.0;
  if (capacity.nicMbps > 0 && req.bandwidthMbps > capacity.nicMbps) {
    nicCapFactor = capacity.nicMbps / req.bandwidthMbps;
  } else if (capacity.nicMbps <= 0 && req.bandwidthMbps > 0) {
    nicCapFactor = 0;
  }

  final localFactorRaw = [degradationCpu, degradationRam, degradationStorage, degradationDisk, nicCapFactor]
      .reduce((a, b) => a < b ? a : b);
  final localFactor = incompatible ? 0.0 : localFactorRaw;
  String? bottleneck;
  if (incompatible) {
    bottleneck = 'incompatible';
  } else if (localFactor < 1) {
    if (degradationCpu == localFactor) bottleneck = 'cpu';
    else if (degradationRam == localFactor) bottleneck = 'ram';
    else if (degradationStorage == localFactor) bottleneck = 'storage';
    else if (degradationDisk == localFactor) bottleneck = 'disk';
    else bottleneck = 'nic';
  }

  return RigLoadResult(
    rigId: rigId,
    required: req,
    capacity: RigCapacity(
      cpu: effectiveCPUCapacity,
      ramGB: capacity.ramGB,
      storageGB: capacity.storageGB,
      nicMbps: capacity.nicMbps,
      diskMBs: diskCapacityMBs,
    ),
    utilization: util,
    throttleFactor: throttleFactor,
    tempRatio: tempRatio,
    cpuLoadFactor: nominalCPULoadFactor,
    nicCapFactor: nicCapFactor,
    localFactor: localFactor,
    localBottleneck: bottleneck,
    incompatible: incompatible,
    incompatibilityReasons: incompatibilityReasons,
  );
}

AccountLoadResult calculateAccountLoad(
  Map<String, RigInput> rigs,
  Map<String, RouterInput> routers, {
  Map<String, double> rigOverheatPenalties = const {},
  Map<String, double> rigCoolingReductions = const {},
  Map<String, double> routerBandwidthMultipliers = const {},
  Map<String, double> instanceIncomeMultipliers = const {},
  SimModifiers modifiers = SimModifiers.none,
}) {
  final rigResults = <String, RigLoadResult>{};
  final routerResults = <String, RouterLoadResult>{};

  for (final entry in routers.entries) {
    final plan = internetPlansById[entry.value.internetPlanId];
    final bandwidthMultiplier = routerBandwidthMultipliers[entry.key] ?? 1.0;
    routerResults[entry.key] = RouterLoadResult(
      routerId: entry.key,
      internetPlanId: entry.value.internetPlanId,
      requiredBandwidth: 0,
      bandwidthCapacity: ((plan?.upMbps ?? 0) * bandwidthMultiplier).round(),
      bandwidthFactor: 1.0,
      latencyMs: plan?.maxLatencyMs ?? 999,
      rigCount: 0,
    );
  }

  var totalRequiredBandwidth = 0.0;
  var totalBandwidthCapacity = 0.0;

  for (final entry in rigs.entries) {
    final result = calculateRigLoad(
      entry.key,
      entry.value.build,
      entry.value.services,
      entry.value.kind,
      overheatThrottlePenalty: rigOverheatPenalties[entry.key] ?? 0.0,
      coolingCapacityReduction: rigCoolingReductions[entry.key] ?? 0.0,
      modifiers: modifiers,
    );
    rigResults[entry.key] = result;
    totalRequiredBandwidth += result.required.bandwidthMbps;

    final routerResult = routerResults[entry.value.routerId];
    if (routerResult != null) {
      routerResult.requiredBandwidth += result.required.bandwidthMbps;
      routerResult.rigCount++;
    }
  }

  var globalBandwidthFactor = 1.0;
  var maxLatencyMs = 0;
  for (final routerResult in routerResults.values) {
    if (routerResult.requiredBandwidth > routerResult.bandwidthCapacity) {
      routerResult.bandwidthFactor = routerResult.bandwidthCapacity > 0
          ? routerResult.bandwidthCapacity / routerResult.requiredBandwidth
          : 0;
    }
    totalBandwidthCapacity += routerResult.bandwidthCapacity;
    globalBandwidthFactor = globalBandwidthFactor < routerResult.bandwidthFactor ? globalBandwidthFactor : routerResult.bandwidthFactor;
    if (routerResult.latencyMs > maxLatencyMs) maxLatencyMs = routerResult.latencyMs;
  }

  final instances = <InstanceResult>[];
  var totalIncome = 0.0;
  var overloaded = globalBandwidthFactor < 1;

  for (final entry in rigs.entries) {
    final rigResult = rigResults[entry.key]!;
    if (rigResult.localFactor < 1) overloaded = true;

    final routerResult = routerResults[entry.value.routerId];
    final routerFactor = routerResult?.bandwidthFactor ?? 0;
    final routerLatency = routerResult?.latencyMs ?? 999;

    for (final inst in entry.value.services) {
      final serviceType = servicesById[inst.serviceTypeId];
      if (serviceType == null) continue;

      var latencyFactor = 1.0;
      String? bottleneck = rigResult.localBottleneck;
      if (serviceType.maxLatencyMs != null && routerLatency > serviceType.maxLatencyMs!) {
        latencyFactor = (serviceType.maxLatencyMs! / routerLatency).clamp(0.2, 1.0);
      }

      final rawSatisfaction = rigResult.localFactor * routerFactor * latencyFactor;
      // The research bonus lifts a degraded service but can never take one
      // past fully satisfied, and never rescues incompatible hardware (0).
      final satisfaction = rawSatisfaction <= 0
          ? 0.0
          : (rawSatisfaction + modifiers.satisfactionBonus).clamp(0.0, 1.0).toDouble();
      if (routerFactor < rigResult.localFactor && routerFactor < latencyFactor) {
        bottleneck = 'bandwidth';
      } else if (latencyFactor < rigResult.localFactor && latencyFactor < routerFactor) {
        bottleneck = 'latency';
      }

      final incomeMultiplier = instanceIncomeMultipliers[inst.instanceId] ?? 1.0;
      final incomePerDay =
          serviceType.incomePerUnitPerDay * inst.capacity * satisfaction * incomeMultiplier * modifiers.incomeMultiplier;

      instances.add(InstanceResult(
        instanceId: inst.instanceId,
        serviceTypeId: inst.serviceTypeId,
        rigId: entry.key,
        capacity: inst.capacity,
        satisfaction: satisfaction,
        incomePerDay: incomePerDay,
        bottleneck: satisfaction < 1 ? bottleneck : null,
      ));
      totalIncome += incomePerDay;
    }
  }

  return AccountLoadResult(
    rigs: rigResults,
    routers: routerResults,
    totalRequiredBandwidth: totalRequiredBandwidth,
    totalBandwidthCapacity: totalBandwidthCapacity,
    globalBandwidthFactor: globalBandwidthFactor,
    maxLatencyMs: maxLatencyMs,
    instances: instances,
    totalIncomePerDay: totalIncome,
    overloaded: overloaded,
  );
}
