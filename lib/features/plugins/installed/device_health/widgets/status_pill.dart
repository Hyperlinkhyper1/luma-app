import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../device_health_models.dart';

Color statusColor(BuildContext context, HealthStatus status) {
  final luma = context.luma;
  return switch (status) {
    HealthStatus.good => luma.success,
    HealthStatus.warning => luma.warning,
    HealthStatus.bad => luma.danger,
    HealthStatus.unknown => luma.textMuted,
  };
}

String statusLabel(HealthStatus status) => switch (status) {
      HealthStatus.good => 'Good',
      HealthStatus.warning => 'Needs attention',
      HealthStatus.bad => 'Poor',
      HealthStatus.unknown => 'Not checked',
    };

/// Small rounded status badge used across every category card.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.label});

  final HealthStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: context.lumaDecor.pillBorderRadius,
      ),
      child: Text(
        label ?? statusLabel(status),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
