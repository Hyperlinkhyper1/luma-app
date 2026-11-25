import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'cs2_dataset_view.dart';

class DatasetsTab extends StatelessWidget {
  const DatasetsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final inset = context.isPhoneWidth ? 16.0 : 28.0;

    return ListView(
      primary: false,
      padding: EdgeInsets.fromLTRB(inset, 24, inset, 28),
      children: [
        Text(
          t.aiUsageSectionDatasets,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: luma.surface,
                foregroundColor: luma.textPrimary,
                side: BorderSide(color: luma.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const Cs2DatasetView(),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.sports_esports_outlined, color: luma.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CS2'),
                        const SizedBox(height: 4),
                        Text(
                          t.cs2DatasetSubtitle,
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
            ),
          ),
        ),
      ],
    );
  }
}
