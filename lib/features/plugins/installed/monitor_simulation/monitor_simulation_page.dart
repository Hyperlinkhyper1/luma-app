import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';
import 'monitor_capture_view.dart';
import 'package:luma/l10n/app_localizations.dart';

class MonitorSimulationPage extends StatelessWidget {
  const MonitorSimulationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.luma;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L.of(context).monitorSimTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            L.of(context).monitorSimSubtitle,
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          const _SetupInstructions(),
          const SizedBox(height: 12),
          const Expanded(child: MonitorCaptureView()),
        ],
      ),
    );
  }
}

class _SetupInstructions extends StatelessWidget {
  const _SetupInstructions();

  @override
  Widget build(BuildContext context) {
    final colors = context.luma;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Icon(Icons.cable_rounded, color: colors.accent),
        title: Text(
          L.of(context).monitorSimHowToConnect,
          style: TextStyle(color: colors.textPrimary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: [
          Text(
            L.of(context).monitorSimSteps,
            style: TextStyle(color: colors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
