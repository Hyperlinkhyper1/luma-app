import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/settings_controller.dart';
import '../../settings/settings_scope.dart';
import '../../sync/sync_scope.dart';
import '../../sync/sync_service.dart';
import '../../theme/luma_theme.dart';
import 'account/assistant_panels.dart';
import 'local_model_store.dart';
import 'providers/ai_providers.dart';
import 'providers/ai_usage.dart';

/// The "AI Assistant" settings block: choose a hosted provider or manage the
/// optional on-device model. Collapsed by default in [LumaCollapsibleSection].
class AiSettingsSection extends StatelessWidget {
  const AiSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProviderPicker(settings: settings),
          const SizedBox(height: 12),
          const _RetentionNotice(),
          const SizedBox(height: 12),
          // Re-mounts the key-management body whenever the provider changes,
          // so its per-provider loaded state (masked key, etc.) is fresh.
          if (settings.aiProviderId == AiProviderId.local.name &&
              LocalModelStore.supported)
            const _LocalModelBody()
          else if (settings.aiProviderId == AiProviderId.local.name)
            Text(
              L.of(context).aiSettingsLocalNotAvailableIos,
              style: TextStyle(color: context.luma.textMuted, fontSize: 12),
            )
          else
            const _ApiKeysPointer(),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(L.of(context).settingsTrackBackendAiUsage),
            subtitle: Text(L.of(context).settingsTrackBackendAiUsageSub),
            value: settings.trackBackendAiUsage,
            onChanged: settings.setTrackBackendAiUsage,
          ),
          _ModelUsageSection(usage: settings.modelUsage),
        ],
      ),
    );
  }
}

/// API keys are managed in one place, the assistant's own Settings → API;
/// this points there.
class _ApiKeysPointer extends StatelessWidget {
  const _ApiKeysPointer();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.key_rounded, size: 17, color: luma.accent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  t.aiSettingsApiKeysMoved,
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LumaGhostButton(
            label: t.assistantApiManage,
            icon: Icons.open_in_new_rounded,
            onTap: () => showAssistantPanel(context, AssistantPanel.api),
          ),
        ],
      ),
    );
  }
}

class _RetentionNotice extends StatelessWidget {
  const _RetentionNotice();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, size: 17, color: luma.accent),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              L.of(context).aiSettingsRetentionNotice,
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalModelBody extends StatefulWidget {
  const _LocalModelBody();

  @override
  State<_LocalModelBody> createState() => _LocalModelBodyState();
}

class _LocalModelBodyState extends State<_LocalModelBody> {
  final _store = LocalModelStore.instance;
  bool _installed = false;

  @override
  void initState() {
    super.initState();
    _refreshInstalled();
  }

  Future<void> _refreshInstalled() async {
    final installed = await _store.isInstalled;
    if (mounted) setState(() => _installed = installed);
  }

  Future<void> _download() async {
    await _store.download();
    await _refreshInstalled();
  }

  Future<void> _remove() async {
    await _store.remove();
    await _refreshInstalled();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) => LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android_rounded, size: 17, color: luma.accent),
                const SizedBox(width: 8),
                Text(
                  t.aiSettingsLocalModelTitle(LocalModelStore.modelDisplayName),
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.aiSettingsLocalModelBlurb(LocalModelStore.modelSizeLabel),
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
            if (_store.isDownloading) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(value: _store.progress),
              const SizedBox(height: 5),
              Text(
                _store.progress == null
                    ? t.aiSettingsDownloadingModel
                    : t.aiSettingsDownloadingModelPercent(
                        (_store.progress! * 100).toStringAsFixed(0),
                      ),
                style: TextStyle(color: luma.textMuted, fontSize: 11),
              ),
            ] else if (_store.error != null) ...[
              const SizedBox(height: 10),
              Text(
                t.aiSettingsDownloadFailed('${_store.error}'),
                style: TextStyle(color: luma.danger, fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 12),
            if (_installed)
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: luma.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.aiSettingsModelReady,
                      style: TextStyle(color: luma.textPrimary, fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _remove,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: Text(t.commonRemove),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: _store.isDownloading ? null : _download,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(t.aiSettingsDownloadModel),
              ),
          ],
        ),
      ),
    );
  }
}

/// Which model has been used the most, across every provider — a simple
/// lifetime successful-message count for each model.
class _ModelUsageSection extends StatefulWidget {
  const _ModelUsageSection({required this.usage});
  final Map<String, int> usage;

  @override
  State<_ModelUsageSection> createState() => _ModelUsageSectionState();
}

class _ModelUsageSectionState extends State<_ModelUsageSection> {
  SyncService? _sync;
  Map<String, String> _modeVersions = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = SyncScope.of(context);
    if (identical(sync, _sync)) return;
    _sync = sync;
    sync.aiStatus().then((status) {
      if (!mounted || !identical(sync, _sync)) return;
      setState(() => _modeVersions = status?.modeVersions ?? const {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);

    final rows =
        kModelUsageEntries
            .map((e) => (entry: e, count: widget.usage[e.key] ?? 0))
            .where((r) => r.count > 0)
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    final maxScore = rows.isEmpty
        ? 1
        : rows.map((r) => r.count).reduce((a, b) => a > b ? a : b);

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 16, color: luma.accent),
              const SizedBox(width: 8),
              Text(
                t.aiSettingsModelUsage,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.aiSettingsModelUsageSubtitle,
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            Text(
              t.aiSettingsNoMessagesYet,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in rows) ...[
                  _UsageRow(
                    label: r.entry.labelFor(_modeVersions),
                    count: r.count,
                    fraction: r.count / maxScore,
                    top: r == rows.first,
                  ),
                  if (r != rows.last) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.label,
    required this.count,
    required this.fraction,
    required this.top,
  });

  final String label;
  final int count;
  final double fraction;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final messages = L.of(context).assistantUsageMessageCount(count);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (top) ...[
              Icon(Icons.star_rounded, size: 13, color: luma.accent),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 12.5,
                fontWeight: top ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              messages,
              style: TextStyle(color: luma.textMuted, fontSize: 11.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.03, 1.0),
            minHeight: 6,
            backgroundColor: luma.border,
            valueColor: AlwaysStoppedAnimation(
              top ? luma.accent : luma.accent.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderPicker extends StatelessWidget {
  const _ProviderPicker({required this.settings});
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final provider in kAiProviders)
          if (provider.id != AiProviderId.mistral &&
              (provider.id != AiProviderId.local || LocalModelStore.supported))
            _ProviderChip(
              provider: provider,
              selected: provider.id.name == settings.aiProviderId,
              onTap: () => settings.setAiProviderId(provider.id.name),
              luma: luma,
            ),
      ],
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({
    required this.provider,
    required this.selected,
    required this.onTap,
    required this.luma,
  });

  final AiProviderInfo provider;
  final bool selected;
  final VoidCallback onTap;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? luma.accent : luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                provider.icon,
                size: 16,
                color: selected ? luma.accent : luma.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                provider.displayName,
                style: TextStyle(
                  color: selected ? luma.accent : luma.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
