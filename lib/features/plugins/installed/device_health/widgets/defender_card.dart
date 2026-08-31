import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../device_health_models.dart';
import '../device_health_scope.dart';
import 'category_card.dart';

/// The "virus check" category. This is a window onto Windows Defender's own
/// status — luma never scans a file itself. "Run quick scan" starts
/// Defender's own scan and returns immediately; progress lives in Windows
/// Security from that point on.
class DefenderCard extends StatelessWidget {
  const DefenderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = DeviceHealthScope.of(context);
    final state = repo.defender;
    final def = state.data;
    final luma = context.luma;

    HealthStatus? status;
    if (def != null) {
      status = (!def.antivirusEnabled || !def.realTimeProtectionEnabled)
          ? HealthStatus.bad
          : (def.signatureLastUpdated == null ||
                  DateTime.now().difference(def.signatureLastUpdated!).inDays > 7 ||
                  def.lastScan == null ||
                  DateTime.now().difference(def.lastScan!).inDays > 30)
              ? HealthStatus.warning
              : HealthStatus.good;
    }

    return CategoryCard(
      icon: Icons.shield_rounded,
      title: 'Virus & Threat Protection',
      status: status,
      loading: state.loading,
      onCheck: () => repo.refreshAmbient(),
      child: def == null
          ? Text(
              state.error ?? 'Not checked yet.',
              style: TextStyle(color: luma.textMuted, fontSize: 13),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  def.antivirusEnabled && def.realTimeProtectionEnabled
                      ? 'Real-time protection is on.'
                      : 'Real-time protection is OFF.',
                  style: TextStyle(
                    color: def.antivirusEnabled && def.realTimeProtectionEnabled
                        ? luma.textPrimary
                        : luma.danger,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Definitions: ${_relative(def.signatureLastUpdated)} · '
                  'Last scan: ${_relative(def.lastScan)}',
                  style: TextStyle(color: luma.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    LumaGhostButton(
                      label: 'Run quick scan',
                      icon: Icons.search_rounded,
                      onTap: () => repo.triggerDefenderScan(),
                    ),
                    LumaGhostButton(
                      label: 'Open Windows Security',
                      icon: Icons.open_in_new_rounded,
                      onTap: () => repo.openWindowsSecurity(),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

String _relative(DateTime? dt) {
  if (dt == null) return 'never';
  final days = DateTime.now().difference(dt).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  return '$days days ago';
}
