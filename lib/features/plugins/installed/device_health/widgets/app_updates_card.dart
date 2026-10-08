import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../app/update/app_version.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../device_health_models.dart';
import '../device_health_repository.dart';
import '../device_health_scope.dart';
import 'category_card.dart';

/// Real one-click updates via winget — Windows' own signed-package manager —
/// plus luma's own update, reusing the app's existing updater rather than a
/// second update path (see UpdateService).
class AppUpdatesCard extends StatelessWidget {
  const AppUpdatesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = DeviceHealthScope.of(context);
    final state = repo.appUpdates;
    final list = state.data;
    final luma = context.luma;
    final t = L.of(context);
    final checked = state.checkedAt != null && repo.lumaUpdateChecked;
    final totalOutdated = (list?.length ?? 0) + (repo.lumaUpdate != null ? 1 : 0);

    return CategoryCard(
      icon: Icons.system_update_alt_rounded,
      title: t.deviceHealthCardAppUpdatesTitle,
      status: checked
          ? (totalOutdated == 0 ? HealthStatus.good : HealthStatus.warning)
          : null,
      loading: state.loading || repo.lumaUpdateLoading,
      error: state.error,
      onCheck: () => repo.refreshAppUpdates(),
      checkLabel: checked ? t.deviceHealthCardRescan : t.deviceHealthCardScanForUpdates,
      child: !checked
          ? Text(
              t.deviceHealthCardAppUpdatesNotScanned,
              style: TextStyle(color: luma.textMuted, fontSize: 13),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (totalOutdated > 1) ...[
                  LumaPrimaryButton(
                    label: t.deviceHealthCardUpdateAll(totalOutdated),
                    icon: Icons.upgrade_rounded,
                    onTap: () => repo.updateAllApps(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (repo.lumaUpdate != null) ...[
                  _AppRow(
                    name: 'luma',
                    current: AppVersion.current,
                    available: repo.lumaUpdate!.version,
                    sourceLabel: null,
                    job: repo.jobs[DeviceHealthRepository.lumaJobKey],
                    onUpdate: () => repo.updateLuma(),
                  ),
                  if ((list?.isNotEmpty ?? false)) Divider(color: luma.border),
                ],
                if (list != null && list.isNotEmpty)
                  for (var i = 0; i < list.length; i++) ...[
                    _AppRow(
                      name: list[i].name,
                      current: list[i].currentVersion,
                      available: list[i].availableVersion,
                      sourceLabel: list[i].silentEligible ? null : list[i].source.name,
                      job: repo.jobs[list[i].id],
                      onUpdate: () => repo.updateApp(list[i]),
                    ),
                    if (i != list.length - 1) Divider(color: luma.border),
                  ],
                if (totalOutdated == 0)
                  Text(
                    t.deviceHealthCardAppsUpToDate,
                    style: TextStyle(color: luma.textSecondary, fontSize: 13),
                  ),
              ],
            ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.name,
    required this.current,
    required this.available,
    required this.sourceLabel,
    required this.job,
    required this.onUpdate,
  });

  final String name;
  final String current;
  final String available;
  final String? sourceLabel;
  final AppUpdateJob? job;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final state = job?.state ?? AppUpdateJobState.idle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '$current → $available'
                  '${sourceLabel != null ? ' · ${t.deviceHealthCardUpdateSourceMayPrompt(sourceLabel!)}' : ''}',
                  style: TextStyle(color: luma.textSecondary, fontSize: 12),
                ),
                if (state == AppUpdateJobState.needsElevationOrManual || state == AppUpdateJobState.failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      job?.message ?? t.deviceHealthCardUpdateFailedHint,
                      style: TextStyle(color: luma.danger, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ActionButton(state: state, onUpdate: onUpdate),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.state, required this.onUpdate});
  final AppUpdateJobState state;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return switch (state) {
      AppUpdateJobState.running => const SizedBox(
          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2),
        ),
      AppUpdateJobState.done => Icon(Icons.check_circle_rounded, color: luma.success, size: 22),
      _ => LumaGhostButton(label: t.commonUpdate, onTap: onUpdate),
    };
  }
}
