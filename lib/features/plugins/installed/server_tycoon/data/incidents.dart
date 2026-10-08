// Mid-day incidents — random events that interrupt the calm 30s day timer.

import '../../../../../l10n/current_l.dart';

enum IncidentType { routerDdos, rigOverheatSpike, driveFailure, coolingLeak, viralDemandSpike }

class IncidentDef {
  final IncidentType type;
  final String targetKind; // 'rig' | 'router'
  final bool isPositive;

  const IncidentDef({
    required this.type,
    required this.targetKind,
    this.isPositive = false,
  });

  String get name => switch (type) {
        IncidentType.routerDdos => currentL.serverTycoonIncidentDdosName,
        IncidentType.rigOverheatSpike => currentL.serverTycoonIncidentOverheatName,
        IncidentType.driveFailure => currentL.serverTycoonIncidentDriveName,
        IncidentType.coolingLeak => currentL.serverTycoonIncidentLeakName,
        IncidentType.viralDemandSpike => currentL.serverTycoonIncidentViralName,
      };

  String get description => switch (type) {
        IncidentType.routerDdos => currentL.serverTycoonIncidentDdosDescription,
        IncidentType.rigOverheatSpike => currentL.serverTycoonIncidentOverheatDescription,
        IncidentType.driveFailure => currentL.serverTycoonIncidentDriveDescription,
        IncidentType.coolingLeak => currentL.serverTycoonIncidentLeakDescription,
        IncidentType.viralDemandSpike => currentL.serverTycoonIncidentViralDescription,
      };

  String get actionLabel => switch (type) {
        IncidentType.routerDdos => currentL.serverTycoonIncidentDdosAction,
        IncidentType.rigOverheatSpike => currentL.serverTycoonIncidentOverheatAction,
        IncidentType.driveFailure => currentL.serverTycoonIncidentDriveAction,
        IncidentType.coolingLeak => currentL.serverTycoonIncidentLeakAction,
        IncidentType.viralDemandSpike => currentL.serverTycoonIncidentViralAction,
      };
}

final Map<IncidentType, IncidentDef> incidentDefsByType = {
  IncidentType.routerDdos: const IncidentDef(
    type: IncidentType.routerDdos,
    targetKind: 'router',
  ),
  IncidentType.rigOverheatSpike: const IncidentDef(
    type: IncidentType.rigOverheatSpike,
    targetKind: 'rig',
  ),
  IncidentType.driveFailure: const IncidentDef(
    type: IncidentType.driveFailure,
    targetKind: 'rig',
  ),
  IncidentType.coolingLeak: const IncidentDef(
    type: IncidentType.coolingLeak,
    targetKind: 'rig',
  ),
  IncidentType.viralDemandSpike: const IncidentDef(
    type: IncidentType.viralDemandSpike,
    targetKind: 'rig',
    isPositive: true,
  ),
};
