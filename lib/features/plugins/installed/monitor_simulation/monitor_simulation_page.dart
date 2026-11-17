import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';
import 'monitor_capture_view.dart';

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
            'Monitor Simulation',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'View another computer through an HDMI capture device.',
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
          'How to connect',
          style: TextStyle(color: colors.textPrimary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: [
          Text(
            '1. Connect the PC’s HDMI output to a USB HDMI capture device.\n'
            '2. Plug the capture device into this laptop, then select it below.\n'
            '3. Start the preview. If there is no picture, check that the PC is on and sending a supported signal.\n\n'
            'Most laptop HDMI ports are outputs and cannot receive the PC’s video directly. '
            'Use a keyboard and mouse connected to the PC to control it.',
            style: TextStyle(color: colors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
