import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../device_health_models.dart';
import '../device_health_scope.dart';
import 'category_card.dart';

class BatteryCard extends StatelessWidget {
  const BatteryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = DeviceHealthScope.of(context);
    final state = repo.battery;
    final info = state.data;
    final luma = context.luma;

    HealthStatus? status;
    if (info != null && info.present) {
      final wear = info.wearPercent;
      status = wear == null
          ? HealthStatus.good
          : wear > 35
              ? HealthStatus.bad
              : wear > 20
                  ? HealthStatus.warning
                  : HealthStatus.good;
    } else if (info != null) {
      status = HealthStatus.unknown;
    }

    return CategoryCard(
      icon: Icons.battery_std_rounded,
      title: 'Battery',
      status: status,
      loading: state.loading,
      error: state.error,
      onCheck: () => repo.refreshAmbient(),
      child: info == null
          ? Text('Not checked yet.', style: TextStyle(color: luma.textMuted, fontSize: 13))
          : !info.present
              ? Text(
                  'No battery detected — this looks like a desktop.',
                  style: TextStyle(color: luma.textMuted, fontSize: 13),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${info.chargePercent ?? '—'}%'
                      '${info.statusLabel != null ? ' · ${info.statusLabel}' : ''}',
                      style: TextStyle(color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      info.wearPercent != null
                          ? 'Battery health: ${(100 - info.wearPercent!).round()}% of design capacity remains.'
                          : "This battery doesn't report design/full-charge capacity, so wear can't be estimated.",
                      style: TextStyle(color: luma.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
    );
  }
}
