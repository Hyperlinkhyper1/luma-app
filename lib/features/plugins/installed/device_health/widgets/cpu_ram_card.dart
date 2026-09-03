import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../device_health_models.dart';
import '../device_health_scope.dart';
import 'category_card.dart';

class CpuRamCard extends StatelessWidget {
  const CpuRamCard({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = DeviceHealthScope.of(context);
    final state = repo.systemUsage;
    final usage = state.data;
    final status = usage == null
        ? null
        : (usage.cpuPercent > 90 || usage.ramUsedPercent > 90)
            ? HealthStatus.bad
            : (usage.cpuPercent > 70 || usage.ramUsedPercent > 75)
                ? HealthStatus.warning
                : HealthStatus.good;

    return CategoryCard(
      icon: Icons.memory_rounded,
      title: 'CPU & RAM',
      status: status,
      loading: state.loading,
      error: state.error,
      onCheck: () => repo.refreshAmbient(),
      child: usage == null
          ? Text(
              'Not checked yet.',
              style: TextStyle(color: context.luma.textMuted, fontSize: 13),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Meter(
                  label: 'CPU',
                  value: usage.cpuPercent,
                  caption: '${usage.cpuPercent.round()}%',
                ),
                const SizedBox(height: 12),
                _Meter(
                  label: 'RAM',
                  value: usage.ramUsedPercent,
                  caption:
                      '${usage.ramUsedGb.toStringAsFixed(1)} / '
                      '${usage.ramTotalGb.toStringAsFixed(1)} GB',
                ),
              ],
            ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, required this.caption});
  final String label;
  final double value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = value > 90 ? luma.danger : value > 75 ? luma.warning : luma.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(color: luma.textSecondary, fontSize: 13)),
            const Spacer(),
            Text(caption, style: TextStyle(color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0, 1),
            minHeight: 8,
            backgroundColor: luma.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
