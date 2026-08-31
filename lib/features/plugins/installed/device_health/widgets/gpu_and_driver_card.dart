import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../device_health_scope.dart';
import 'category_card.dart';

/// GPU identification plus driver updates. Windows exposes no public API for
/// live GPU utilization/temperature (confirmed: nothing short of a vendor
/// SDK or a third-party tool like LibreHardwareMonitor can read that), so
/// this only ever shows static info — and driver updates are never
/// auto-installed, only handed off to the vendor's or Windows' own tool.
class GpuAndDriverCard extends StatelessWidget {
  const GpuAndDriverCard({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = DeviceHealthScope.of(context);
    final state = repo.gpus;
    final gpus = state.data;
    final luma = context.luma;
    final dateFormat = DateFormat.yMMMd();

    return CategoryCard(
      icon: Icons.videogame_asset_rounded,
      title: 'GPU & Drivers',
      loading: state.loading,
      error: state.error,
      onCheck: () => repo.refreshAmbient(),
      child: gpus == null
          ? Text('Not checked yet.', style: TextStyle(color: luma.textMuted, fontSize: 13))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final gpu in gpus) ...[
                  Text(gpu.name, style: TextStyle(color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    'Driver ${gpu.driverVersion}'
                    '${gpu.driverDate != null ? ' · ${dateFormat.format(gpu.driverDate!)}' : ''}',
                    style: TextStyle(color: luma.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      LumaGhostButton(
                        label: gpu.vendor == 'Unknown'
                            ? 'Open Windows Update'
                            : 'Open ${gpu.vendor} update tool',
                        icon: Icons.open_in_new_rounded,
                        onTap: () => repo.openDriverTool(gpu.vendor),
                      ),
                      if (gpu.vendor != 'Unknown')
                        LumaGhostButton(
                          label: 'Open Windows Update',
                          icon: Icons.system_update_rounded,
                          onTap: () => repo.openWindowsUpdate(),
                        ),
                    ],
                  ),
                  if (gpu != gpus.last) const SizedBox(height: 16),
                ],
                const SizedBox(height: 4),
                Text(
                  "Windows doesn't expose a way to check driver freshness "
                  'directly — these open the tool that actually knows. '
                  "Nothing is installed automatically.",
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
    );
  }
}
