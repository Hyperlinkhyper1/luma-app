import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
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
    final t = L.of(context);

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
      title: t.deviceHealthCardBatteryTitle,
      status: status,
      loading: state.loading,
      error: state.error,
      onCheck: () => repo.refreshAmbient(),
      child: info == null
          ? Text(t.deviceHealthCardNotCheckedYet, style: TextStyle(color: luma.textMuted, fontSize: 13))
          : !info.present
              ? Text(
                  t.deviceHealthCardNoBattery,
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
                          ? t.deviceHealthCardBatteryHealth((100 - info.wearPercent!).round())
                          : t.deviceHealthCardBatteryNoWearData,
                      style: TextStyle(color: luma.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
    );
  }
}
