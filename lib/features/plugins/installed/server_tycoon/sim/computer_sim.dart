// Auto-ported from Roblox Server Hosting Tycoon
// Pure functions over a "build" (a set of component ids).

import 'dart:math' as math;

import '../data/game_data.dart';

class Build {
  String cpuId;
  String motherboardId;
  List<String> ramIds;
  List<String> storageIds;
  String psuId;
  String coolingId;
  String nicId;

  Build({
    required this.cpuId,
    required this.motherboardId,
    required this.ramIds,
    required this.storageIds,
    required this.psuId,
    required this.coolingId,
    required this.nicId,
  });

  Build copyWith({
    String? cpuId,
    String? motherboardId,
    List<String>? ramIds,
    List<String>? storageIds,
    String? psuId,
    String? coolingId,
    String? nicId,
  }) => Build(
    cpuId: cpuId ?? this.cpuId,
    motherboardId: motherboardId ?? this.motherboardId,
    ramIds: ramIds ?? List.from(this.ramIds),
    storageIds: storageIds ?? List.from(this.storageIds),
    psuId: psuId ?? this.psuId,
    coolingId: coolingId ?? this.coolingId,
    nicId: nicId ?? this.nicId,
  );

  Map<String, dynamic> toJson() => {
    'cpuId': cpuId,
    'motherboardId': motherboardId,
    'ramIds': ramIds,
    'storageIds': storageIds,
    'psuId': psuId,
    'coolingId': coolingId,
    'nicId': nicId,
  };

  factory Build.fromJson(Map<String, dynamic> json) => Build(
    cpuId: json['cpuId'] as String,
    motherboardId: json['motherboardId'] as String,
    ramIds: (json['ramIds'] as List).cast<String>(),
    storageIds: (json['storageIds'] as List).cast<String>(),
    psuId: json['psuId'] as String,
    coolingId: json['coolingId'] as String,
    nicId: json['nicId'] as String,
  );
}

enum RigKind { pc, server }
enum ComponentGrade { pc, server, any }

class Capacity {
  final double cpuScore;
  final int ramGB;
  final int storageGB;
  final int nicMbps;

  const Capacity({required this.cpuScore, required this.ramGB, required this.storageGB, required this.nicMbps});
}

final Set<Socket> _serverSockets = {
  Socket.lga2011v3, Socket.lga4677, Socket.sp3, Socket.sp5,
};

final Set<String> _serverPsuIds = {
  'SERVER_PSU_1200_REDUNDANT', 'SERVER_PSU_2000_REDUNDANT', 'SERVER_PSU_3000_TITANIUM', 'HYPERSCALE_PSU_5000',
};

final Set<String> _serverCoolerIds = {
  'DYNATRON_2U_SERVER', 'SERVER_4U_ACTIVE', 'SERVER_RACK_COOLING',
  'REAR_DOOR_HEAT_EXCHANGER', 'IMMERSION_TANK', 'INDUSTRIAL_CHILLER',
};

ComponentGrade getComponentGrade(String slot, String itemId) {
  if (slot == 'storage') return ComponentGrade.any;
  if (slot == 'cpu') {
    final cpu = cpusById[itemId];
    return cpu != null ? (_serverSockets.contains(cpu.socket) ? ComponentGrade.server : ComponentGrade.pc) : ComponentGrade.any;
  }
  if (slot == 'motherboard') {
    final mobo = motherboardsById[itemId];
    return mobo != null ? (_serverSockets.contains(mobo.socket) ? ComponentGrade.server : ComponentGrade.pc) : ComponentGrade.any;
  }
  if (slot == 'ram') {
    final stick = ramById[itemId];
    return stick != null ? (stick.ecc ? ComponentGrade.server : ComponentGrade.pc) : ComponentGrade.any;
  }
  if (slot == 'psu') {
    return _serverPsuIds.contains(itemId) ? ComponentGrade.server : ComponentGrade.pc;
  }
  if (slot == 'cooling') {
    return _serverCoolerIds.contains(itemId) ? ComponentGrade.server : ComponentGrade.pc;
  }
  if (slot == 'nic') {
    final nic = nicsById[itemId];
    return nic != null ? (nic.throughputMbps >= 20000 ? ComponentGrade.server : ComponentGrade.pc) : ComponentGrade.any;
  }
  return ComponentGrade.any;
}

bool gradeFits(String slot, String itemId, RigKind rigKind) {
  final grade = getComponentGrade(slot, itemId);
  return grade == ComponentGrade.any || grade.name == rigKind.name;
}

(List<String> errors, bool ok) validateBuild(Build build, {RigKind? rigKind}) {
  final errors = <String>[];

  if (rigKind != null) {
    void checkGrade(String slot, String itemId) {
      if (!gradeFits(slot, itemId, rigKind)) {
        final grade = getComponentGrade(slot, itemId);
        errors.add('$itemId is ${grade.name} hardware and does not fit a ${rigKind.name} rig');
      }
    }
    checkGrade('cpu', build.cpuId);
    checkGrade('motherboard', build.motherboardId);
    checkGrade('psu', build.psuId);
    checkGrade('cooling', build.coolingId);
    checkGrade('nic', build.nicId);
    for (final ramId in build.ramIds) checkGrade('ram', ramId);
  }

  final cpu = cpusById[build.cpuId];
  final mobo = motherboardsById[build.motherboardId];
  final psu = psusById[build.psuId];

  if (cpu == null) errors.add('Unknown CPU: ${build.cpuId}');
  if (mobo == null) errors.add('Unknown motherboard: ${build.motherboardId}');
  if (cpu != null && mobo != null && cpu.socket != mobo.socket) {
    errors.add('${cpu.name} (socket ${cpu.socket.name}) does not fit ${mobo.name} (socket ${mobo.socket.name})');
  }

  if (mobo != null) {
    if (build.ramIds.length > mobo.ramSlots) {
      errors.add('${mobo.name} only has ${mobo.ramSlots} RAM slots, ${build.ramIds.length} sticks installed');
    }

    var totalRAM = 0;
    for (final ramId in build.ramIds) {
      final stick = ramById[ramId];
      if (stick == null) {
        errors.add('Unknown RAM stick: $ramId');
        continue;
      }
      if (stick.ramType != mobo.ramType) {
        errors.add('${stick.name} is ${stick.ramType.name}, ${mobo.name} requires ${mobo.ramType.name}');
      }
      if (stick.registered && !mobo.supportsECC) {
        errors.add('${mobo.name} does not support registered/ECC memory (${stick.name})');
      }
      totalRAM += stick.capacityGB;
    }
    if (totalRAM > mobo.maxRAMGB) {
      errors.add('${mobo.name} supports up to ${mobo.maxRAMGB}GB RAM, ${totalRAM}GB installed');
    }

    var sataUsed = 0, m2Used = 0;
    for (final driveId in build.storageIds) {
      final drive = storageById[driveId];
      if (drive == null) {
        errors.add('Unknown drive: $driveId');
        continue;
      }
      if (drive.interfaceType == StorageInterface.nvme) {
        m2Used++;
      } else {
        sataUsed++;
      }
    }
    if (sataUsed > mobo.sataPorts) {
      errors.add('${mobo.name} only has ${mobo.sataPorts} SATA ports, $sataUsed drives need one');
    }
    if (m2Used > mobo.m2Slots) {
      errors.add('${mobo.name} only has ${mobo.m2Slots} M.2 slots, $m2Used NVMe drives installed');
    }
  }

  if (cpu != null && psu != null) {
    final maxDraw = getMaxPowerDrawWatts(build);
    if (maxDraw > psu.wattage) {
      errors.add('Estimated max draw ${maxDraw}W exceeds ${psu.name}\'s ${psu.wattage}W rating');
    }
  }

  return (errors, errors.isEmpty);
}

int getTotalRAMGB(Build build) {
  var total = 0;
  for (final ramId in build.ramIds) {
    final stick = ramById[ramId];
    if (stick != null) total += stick.capacityGB;
  }
  return total;
}

int getTotalStorageGB(Build build) {
  var total = 0;
  for (final driveId in build.storageIds) {
    final drive = storageById[driveId];
    if (drive != null) total += drive.capacityGB;
  }
  return total;
}

int getNICThroughputMbps(Build build) {
  final nic = nicsById[build.nicId];
  return nic?.throughputMbps ?? 0;
}

int getMaxPowerDrawWatts(Build build) {
  final cpu = cpusById[build.cpuId];
  final cooling = coolingById[build.coolingId];
  final nic = nicsById[build.nicId];

  var watts = 0;
  if (cpu != null) watts += cpu.tdpWatts;
  if (cooling != null) watts += cooling.powerDrawWatts;
  if (nic != null) watts += nic.powerDrawWatts;
  for (final driveId in build.storageIds) {
    final drive = storageById[driveId];
    if (drive != null) watts += drive.powerDrawWatts;
  }
  watts += 25; // motherboard, RAM, fans baseline overhead
  return watts;
}

double getActualPowerDrawWatts(Build build, double loadFactor) {
  final cpu = cpusById[build.cpuId];
  final psu = psusById[build.psuId];
  final cooling = coolingById[build.coolingId];
  final nic = nicsById[build.nicId];
  if (cpu == null || psu == null) return 0;

  loadFactor = loadFactor.clamp(0, 1);
  var componentDraw = cpu.tdpWatts * (0.25 + 0.75 * loadFactor);
  if (cooling != null) componentDraw += cooling.powerDrawWatts;
  if (nic != null) componentDraw += nic.powerDrawWatts;
  for (final driveId in build.storageIds) {
    final drive = storageById[driveId];
    if (drive != null) componentDraw += drive.powerDrawWatts;
  }
  componentDraw += 15; // baseline overhead

  return componentDraw / psu.efficiencyPercent;
}

(double throttleFactor, double tempRatio) getThermals(Build build, double loadFactor, {double coolingCapacityMultiplier = 1.0}) {
  final cpu = cpusById[build.cpuId];
  final cooling = coolingById[build.coolingId];
  if (cpu == null || cooling == null) return (1.0, 0.0);

  loadFactor = loadFactor.clamp(0, 1);
  final heatWatts = cpu.tdpWatts * loadFactor;
  final effectiveCoolingCapacity = cooling.coolingCapacityWatts * coolingCapacityMultiplier;
  final tempRatio = heatWatts / effectiveCoolingCapacity;

  var throttleFactor = 1.0;
  if (tempRatio > 1) {
    throttleFactor = (effectiveCoolingCapacity / math.max(heatWatts, 1)).clamp(0.3, 1.0);
  }

  return (throttleFactor, tempRatio);
}

double getEffectiveCPUScore(Build build, double loadFactor) {
  final cpu = cpusById[build.cpuId];
  if (cpu == null) return 0;
  final (throttleFactor, _) = getThermals(build, loadFactor);
  return cpu.mcScore * throttleFactor;
}

Capacity getCapacity(Build build) {
  final cpu = cpusById[build.cpuId];
  return Capacity(
    cpuScore: cpu?.mcScore.toDouble() ?? 0,
    ramGB: getTotalRAMGB(build),
    storageGB: getTotalStorageGB(build),
    nicMbps: getNICThroughputMbps(build),
  );
}

Build newStarterBuild() => Build(
  cpuId: 'I3_4130',
  motherboardId: 'ASUS_H81M_K',
  ramIds: const ['DDR3_8GB'],
  storageIds: const ['HDD_500GB'],
  psuId: 'CORSAIR_VS350',
  coolingId: 'STOCK_COOLER',
  nicId: 'REALTEK_ONBOARD',
);

Build newRigBuild() => newStarterBuild();

Build newServerBuild() => Build(
  cpuId: 'XEON_E5_2680_V4',
  motherboardId: 'SUPERMICRO_X10SRL',
  ramIds: const ['DDR4_32GB_RDIMM'],
  storageIds: const ['HDD_500GB'],
  psuId: 'SERVER_PSU_2000_REDUNDANT',
  coolingId: 'DYNATRON_2U_SERVER',
  nicId: 'INTEL_X520',
);
