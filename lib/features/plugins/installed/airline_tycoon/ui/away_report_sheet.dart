import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../airline_game_state.dart';
import 'money.dart';

/// "While you were away" — shown once when the app reopens after the sim has
/// caught up on the days that passed.
class AwayReportSheet extends StatelessWidget {
  const AwayReportSheet({
    super.key,
    required this.report,
    required this.onDismiss,
  });

  final AwayReport report;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final profitable = report.netProfitEur >= 0;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        // Capped and scrollable: with a capped absence and a list of events
        // this sheet grows past a short screen, and without this the only
        // button on it ends up below the bottom edge where it cannot be
        // tapped at all.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: luma.surface,
          borderRadius: context.lumaDecor.cardBorderRadius,
          border: Border.all(color: luma.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Row(
              children: [
                LumaIconBadge(
                  icon: Icons.nightlight_round,
                  color: luma.accent,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'While you were away',
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${fmtDuration(report.awayFor)} away · '
                        '${report.daysSimulated} day'
                        '${report.daysSimulated == 1 ? '' : 's'} flown',
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              fmtSignedMoney(report.netProfitEur),
              style: TextStyle(
                color: profitable ? luma.success : luma.danger,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              profitable ? 'earned' : 'lost',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _Stat(label: 'Income', value: fmtMoney(report.incomeEur)),
                _Stat(label: 'Costs', value: fmtMoney(report.costEur)),
                _Stat(
                  label: 'Passengers',
                  value: fmtCount(report.passengers),
                ),
                _Stat(
                  label: 'Offline rate',
                  value: '${(report.rate * 100).round()}%',
                ),
              ],
            ),
            if (report.capped) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.hourglass_bottom_rounded,
                      size: 15, color: luma.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${report.daysElapsed} days went by, but an absence pays '
                      'for at most ${AirlineGameState.maxOfflineDays}. The rest '
                      'were not flown.',
                      style: TextStyle(color: luma.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (report.events.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final event in report.events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 5, color: luma.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event,
                          style: TextStyle(
                            color: luma.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Pinned outside the scroll view so the way out of the sheet is
            // always on screen, however long the report runs.
            LumaPrimaryButton(
              label: 'Back to work',
              expand: true,
              onTap: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: luma.textMuted)),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: luma.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
