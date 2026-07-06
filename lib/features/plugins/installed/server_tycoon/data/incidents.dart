// Mid-day incidents — random events that interrupt the calm 30s day timer.

enum IncidentType { routerDdos, rigOverheatSpike, driveFailure, coolingLeak, viralDemandSpike }

class IncidentDef {
  final IncidentType type;
  final String name;
  final String description;
  final String targetKind; // 'rig' | 'router'
  final String actionLabel;
  final bool isPositive;

  const IncidentDef({
    required this.type,
    required this.name,
    required this.description,
    required this.targetKind,
    required this.actionLabel,
    this.isPositive = false,
  });
}

final Map<IncidentType, IncidentDef> incidentDefsByType = {
  IncidentType.routerDdos: const IncidentDef(
    type: IncidentType.routerDdos,
    name: 'DDoS Attack',
    description: 'A flood of junk traffic is choking this router\'s bandwidth.',
    targetKind: 'router',
    actionLabel: 'Mitigate',
  ),
  IncidentType.rigOverheatSpike: const IncidentDef(
    type: IncidentType.rigOverheatSpike,
    name: 'Overheat Spike',
    description: 'A sudden thermal spike is throttling this rig.',
    targetKind: 'rig',
    actionLabel: 'Emergency Cooldown',
  ),
  IncidentType.driveFailure: const IncidentDef(
    type: IncidentType.driveFailure,
    name: 'Drive Failure',
    description: 'A drive in this rig just died. Replace it to restore full service.',
    targetKind: 'rig',
    actionLabel: 'Replace Drive',
  ),
  IncidentType.coolingLeak: const IncidentDef(
    type: IncidentType.coolingLeak,
    name: 'Cooling Leak',
    description: 'The water cooling loop on this rig is leaking, reducing its cooling capacity.',
    targetKind: 'rig',
    actionLabel: 'Repair',
  ),
  IncidentType.viralDemandSpike: const IncidentDef(
    type: IncidentType.viralDemandSpike,
    name: 'Viral Demand Spike',
    description: 'One of your services just went viral! Extra income for the rest of the day.',
    targetKind: 'rig',
    actionLabel: 'Nice!',
    isPositive: true,
  ),
};
