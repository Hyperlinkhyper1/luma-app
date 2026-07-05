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

class RigInput {
  final Build build;
  final List<ServiceInstance> services;
  String routerId;

  RigInput({required this.build, required this.services, required this.routerId});
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

  const RequiredResources({required this.cpu, required this.ramGB, required this.storageGB, required this.bandwidthMbps});
}

class RigCapacity {
  final double cpu;
  final int ramGB;
  final int storageGB;
  final int nicMbps;

  const RigCapacity({required this.cpu, required this.ramGB, required this.storageGB, required this.nicMbps});
}

class Utilization {
  final double cpu;
  final double ramGB;
  final double storageGB;

  const Utilization({required this.cpu, required this.ramGB, required this.storageGB});
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

RequiredResources _sumRequired(List<ServiceInstance> services) {
  var cpu = 0.0, ramGB = 0.0, storageGB = 0.0, bandwidthMbps = 0.0;
  for (final inst in services) {
    final serviceType = servicesById[inst.serviceTypeId];
    if (serviceType == null) continue;
    cpu += serviceType.base.cpu + serviceType.perUnit.cpu * inst.capacity;
    ramGB += serviceType.base.ramGB + serviceType.perUnit.ramGB * inst.capacity;
    storageGB += serviceType.base.storageGB + serviceType.perUnit.storageGB * inst.capacity;
    bandwidthMbps += serviceType.base.bandwidthMbps + serviceType.perUnit.bandwidthMbps * inst.capacity;
  }
  return RequiredResources(cpu: cpu, ramGB: ramGB, storageGB: storageGB, bandwidthMbps: bandwidthMbps);
}

RigLoadResult calculateRigLoad(String rigId, Build build, List<ServiceInstance> services) {
  final req = _sumRequired(services);
  final capacity = getCapacity(build);

  final double nominalCPULoadFactor = capacity.cpuScore > 0 ? (req.cpu / capacity.cpuScore).clamp(0, 1).toDouble() : 1.0;
  final (throttleFactor, tempRatio) = getThermals(build, nominalCPULoadFactor);
  final effectiveCPUCapacity = capacity.cpuScore * throttleFactor;

  final util = Utilization(
    cpu: effectiveCPUCapacity > 0 ? req.cpu / effectiveCPUCapacity : (req.cpu > 0 ? double.infinity : 0),
    ramGB: capacity.ramGB > 0 ? req.ramGB / capacity.ramGB : (req.ramGB > 0 ? double.infinity : 0),
    storageGB: capacity.storageGB > 0 ? req.storageGB / capacity.storageGB : (req.storageGB > 0 ? double.infinity : 0),
  );

  final degradationCpu = util.cpu > 1 ? 1 / util.cpu : 1.0;
  final degradationRam = util.ramGB > 1 ? 1 / util.ramGB : 1.0;
  final degradationStorage = util.storageGB > 1 ? 1 / util.storageGB : 1.0;

  var nicCapFactor = 1.0;
  if (capacity.nicMbps > 0 && req.bandwidthMbps > capacity.nicMbps) {
    nicCapFactor = capacity.nicMbps / req.bandwidthMbps;
  } else if (capacity.nicMbps <= 0 && req.bandwidthMbps > 0) {
    nicCapFactor = 0;
  }

  final localFactor = [degradationCpu, degradationRam, degradationStorage, nicCapFactor].reduce((a, b) => a < b ? a : b);
  String? bottleneck;
  if (localFactor < 1) {
    if (degradationCpu == localFactor) bottleneck = 'cpu';
    else if (degradationRam == localFactor) bottleneck = 'ram';
    else if (degradationStorage == localFactor) bottleneck = 'storage';
    else bottleneck = 'nic';
  }

  return RigLoadResult(
    rigId: rigId,
    required: req,
    capacity: RigCapacity(cpu: effectiveCPUCapacity, ramGB: capacity.ramGB, storageGB: capacity.storageGB, nicMbps: capacity.nicMbps),
    utilization: util,
    throttleFactor: throttleFactor,
    tempRatio: tempRatio,
    cpuLoadFactor: nominalCPULoadFactor,
    nicCapFactor: nicCapFactor,
    localFactor: localFactor,
    localBottleneck: bottleneck,
  );
}

AccountLoadResult calculateAccountLoad(Map<String, RigInput> rigs, Map<String, RouterInput> routers) {
  final rigResults = <String, RigLoadResult>{};
  final routerResults = <String, RouterLoadResult>{};

  for (final entry in routers.entries) {
    final plan = internetPlansById[entry.value.internetPlanId];
    routerResults[entry.key] = RouterLoadResult(
      routerId: entry.key,
      internetPlanId: entry.value.internetPlanId,
      requiredBandwidth: 0,
      bandwidthCapacity: plan?.upMbps ?? 0,
      bandwidthFactor: 1.0,
      latencyMs: plan?.maxLatencyMs ?? 999,
      rigCount: 0,
    );
  }

  var totalRequiredBandwidth = 0.0;
  var totalBandwidthCapacity = 0.0;

  for (final entry in rigs.entries) {
    final result = calculateRigLoad(entry.key, entry.value.build, entry.value.services);
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

      final satisfaction = rigResult.localFactor * routerFactor * latencyFactor;
      if (routerFactor < rigResult.localFactor && routerFactor < latencyFactor) {
        bottleneck = 'bandwidth';
      } else if (latencyFactor < rigResult.localFactor && latencyFactor < routerFactor) {
        bottleneck = 'latency';
      }

      final incomePerDay = serviceType.incomePerUnitPerDay * inst.capacity * satisfaction;

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
