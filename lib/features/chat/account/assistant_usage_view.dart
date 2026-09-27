import 'package:flutter/material.dart';

import '../../../account/plan.dart';
import '../../../app/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../../settings/settings_scope.dart';
import '../../../sync/sync_scope.dart';
import '../../../sync/sync_service.dart';
import '../../../theme/luma_theme.dart';
import '../../plugins/plugin_repository.dart';
import '../../plugins/plugin_scope.dart';
import '../memory/assistant_memory_scope.dart';
import '../providers/ai_usage.dart';
import 'assistant_panels.dart';

const _aiUsagePluginId = 'ai-usage';

/// "Your usage", after the Claude app: the plan, a one-line verdict, and a
/// bar per limit — the Luma AI 5-hour and weekly budgets from the sync
/// server, Luma Support's daily messages, the daily cap on the user's own
/// API keys — then messages per model and the storage memory takes up.
class AssistantUsageView extends StatefulWidget {
  const AssistantUsageView({super.key, required this.onOpenPlugin});

  final ValueChanged<String> onOpenPlugin;

  @override
  State<AssistantUsageView> createState() => _AssistantUsageViewState();
}

class _AssistantUsageViewState extends State<AssistantUsageView> {
  Future<AiServerStatus?>? _status;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _status ??= SyncScope.of(context).aiStatus();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final settings = SettingsScope.of(context);
    final sync = SyncScope.of(context);
    final memory = AssistantMemoryScope.maybeOf(context);
    final plan = planById(settings.selectedPlanId);
    final keyLimit = settings.aiDailyCallLimit;
    final keyUsed = keyLimit - settings.aiCallsRemainingToday;

    return FutureBuilder<AiServerStatus?>(
      future: _status,
      builder: (context, snap) {
        final status = snap.data;
        final loading = snap.connectionState != ConnectionState.done;
        final fractions = [
          keyUsed / keyLimit,
          if (status != null) ...[
            status.fiveHourPct / 100,
            status.weeklyPct / 100,
            if (status.supportLimit > 0)
              status.supportUsed / status.supportLimit,
            if (status.webSearchLimit > 0)
              status.webSearchUsed / status.webSearchLimit,
          ],
        ];
        final peak = fractions.fold<double>(0, (a, b) => b > a ? b : a);
        final headline = peak >= 1
            ? t.assistantUsageHeadlineOut
            : peak >= 0.8
            ? t.assistantUsageHeadlineClose
            : peak >= 0.5
            ? t.assistantUsageHeadlineOnTrack
            : t.assistantUsageHeadlinePlenty;

        return ListView(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 32),
          children: [
            AssistantPanelTitle(
              t.assistantYourUsage,
              trailing: Text(
                plan.name,
                style: TextStyle(color: luma.textMuted, fontSize: 14),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              headline,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: luma.border),
            _Group(
              title: t.assistantUsageLumaAi,
              subtitle: t.assistantUsageLumaAiSubtitle,
              children: loading
                  ? const [_Loading()]
                  : status == null
                  ? [_Note(t.assistantUsageUnavailable)]
                  : [
                      _UsageRow(
                        label: t.assistantUsageCurrentSession,
                        caption: t.assistantUsageRollingFiveHours,
                        fraction: status.fiveHourPct / 100,
                        trailing: t.assistantUsagePercentUsed(
                          status.fiveHourPct,
                        ),
                      ),
                      _UsageRow(
                        label: t.assistantUsageThisWeek,
                        caption: t.assistantUsageRollingWeek,
                        fraction: status.weeklyPct / 100,
                        trailing: t.assistantUsagePercentUsed(status.weeklyPct),
                      ),
                    ],
            ),
            if (status != null && status.supportLimit > 0)
              _Group(
                title: t.assistantUsageLumaSupport,
                children: [
                  _UsageRow(
                    label: t.assistantDailyMessages,
                    caption: t.assistantUsageResetsDaily,
                    fraction: status.supportUsed / status.supportLimit,
                    trailing: t.assistantMessagesOf(
                      status.supportUsed,
                      status.supportLimit,
                    ),
                  ),
                ],
              ),
            if (status != null && status.webSearchLimit > 0)
              _Group(
                title: t.assistantUsageLumaAssistant,
                subtitle: t.assistantUsageLumaAssistantSubtitle,
                children: [
                  _UsageRow(
                    label: t.assistantUsageWebSearch,
                    caption: t.assistantUsageRollingWeek,
                    fraction: status.webSearchUsed / status.webSearchLimit,
                    trailing: t.assistantUsageCountOf(
                      status.webSearchUsed,
                      status.webSearchLimit,
                    ),
                  ),
                ],
              ),
            _Group(
              title: t.assistantUsageApiKeys,
              subtitle: t.assistantUsageApiKeysSubtitle,
              children: [
                _UsageRow(
                  label: t.assistantDailyMessages,
                  caption: t.assistantUsageResetsDaily,
                  fraction: keyUsed / keyLimit,
                  trailing: t.assistantMessagesOf(keyUsed, keyLimit),
                ),
              ],
            ),
            _Group(
              title: t.assistantUsageByModel,
              subtitle: t.assistantUsageByModelSubtitle,
              children: [_ModelBreakdown(usage: settings.modelUsage)],
            ),
            _Group(
              title: t.assistantUsageStorage,
              children: [
                _StorageRow(
                  label: t.assistantUsageMemoryStorage,
                  caption: t.assistantUsageMemoryStorageCaption,
                  value: formatStorageBytes(memory?.approximateBytes ?? 0),
                ),
                if (sync.account case final account?)
                  _UsageRow(
                    label: t.assistantUsageServerStorage,
                    caption: t.assistantUsageStorageOf(
                      formatStorageBytes(account.usedBytes),
                      formatStorageBytes(account.quotaBytes),
                    ),
                    fraction: account.quotaBytes == 0
                        ? 0
                        : account.usedBytes / account.quotaBytes,
                    trailing: t.assistantUsagePercentUsed(
                      account.quotaBytes == 0
                          ? 0
                          : (account.usedBytes * 100 / account.quotaBytes)
                                .round(),
                    ),
                  ),
              ],
            ),
            StreamBuilder<List<InstalledPluginRecord>>(
              stream: PluginScope.of(context).watchInstalled(),
              builder: (context, installed) {
                final hasPlugin = (installed.data ?? const []).any(
                  (p) => p.pluginId == _aiUsagePluginId,
                );
                if (!hasPlugin) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: LumaGhostButton(
                      label: t.assistantDetailedBreakdown,
                      icon: Icons.query_stats_rounded,
                      onTap: () => widget.onOpenPlugin(_aiUsagePluginId),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, this.subtitle, required this.children});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(color: luma.textMuted, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// One limit: its name and reset rule on the left, the bar in the middle
/// and "30% used" on the right — stacked on narrow screens.
class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.label,
    required this.caption,
    required this.fraction,
    required this.trailing,
  });

  final String label;
  final String caption;
  final double fraction;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final value = fraction.clamp(0.0, 1.0);
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        backgroundColor: luma.accentSubtle,
        color: value >= 1
            ? luma.danger
            : value >= 0.8
            ? luma.warning
            : luma.accent,
      ),
    );
    final labels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(caption, style: TextStyle(color: luma.textMuted, fontSize: 12.5)),
      ],
    );
    final trailingText = Text(
      trailing,
      textAlign: TextAlign.right,
      style: TextStyle(color: luma.textSecondary, fontSize: 13),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: labels),
                    trailingText,
                  ],
                ),
                const SizedBox(height: 8),
                bar,
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 240, child: labels),
              const SizedBox(width: 20),
              Expanded(child: bar),
              const SizedBox(width: 20),
              SizedBox(width: 130, child: trailingText),
            ],
          );
        },
      ),
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({
    required this.label,
    required this.caption,
    required this.value,
  });

  final String label;
  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  caption,
                  style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: TextStyle(color: luma.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Lifetime messages per model, with each model's relative cost weight.
class _ModelBreakdown extends StatelessWidget {
  const _ModelBreakdown({required this.usage});

  final Map<String, int> usage;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final used = [
      for (final e in kModelUsageEntries)
        if ((usage[e.key] ?? 0) > 0) (e, usage[e.key]!),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    if (used.isEmpty) return _Note(t.assistantUsageNoMessages);
    final max = used.first.$2;
    return Column(
      children: [
        for (final (entry, count) in used)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.textPrimary, fontSize: 13.5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: count / max,
                      minHeight: 6,
                      backgroundColor: luma.accentSubtle,
                      color: luma.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: Text(
                    entry.weight > 1
                        ? '${t.assistantUsageMessageCount(count)} · ×${entry.weight}'
                        : t.assistantUsageMessageCount(count),
                    textAlign: TextAlign.right,
                    style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: TextStyle(color: context.luma.textMuted, fontSize: 13),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}
