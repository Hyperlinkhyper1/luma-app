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
import '../chat_usage.dart';
import '../memory/assistant_memory_scope.dart';
import '../providers/ai_modes.dart';
import '../providers/ai_usage.dart';
import 'assistant_panels.dart';

const _aiUsagePluginId = 'ai-usage';

/// "Your usage", after the Claude app: the plan, a one-line verdict, the
/// Luma AI 5-hour and weekly budgets from the sync server, then web search
/// and the user's own API keys as plain rows,
/// and finally messages per model and the storage memory takes up.
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
    return FutureBuilder<AiServerStatus?>(
      future: _status,
      builder: (context, snap) {
        final status = snap.data;
        final loading = snap.connectionState != ConnectionState.done;
        final fractions = [
          if (status != null) ...[
            for (final usage in status.modes.values) ...[
              usage.fiveHourPct / 100,
              usage.weeklyPct / 100,
            ],
            if (status.modes.isEmpty) ...[
              status.fiveHourPct / 100,
              status.weeklyPct / 100,
            ],
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
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
          children: [
            AssistantPanelTitle(
              t.assistantYourUsage,
              trailing: Text(
                plan.name,
                style: TextStyle(color: luma.textMuted, fontSize: 14),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              headline,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            StreamBuilder<List<InstalledPluginRecord>>(
              stream: PluginScope.of(context).watchInstalled(),
              builder: (context, installed) {
                final hasPlugin = (installed.data ?? const []).any(
                  (p) => p.pluginId == _aiUsagePluginId,
                );
                if (!hasPlugin) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 18),
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
            const SizedBox(height: 20),
            Divider(height: 1, color: luma.border),
            const SizedBox(height: 8),
            if (loading)
              const _Loading()
            else if (status == null)
              _Note(t.assistantUsageUnavailable)
            else
              for (final mode in AiMode.values.where(
                (mode) => mode.availableForPlan(plan.id),
              ))
                _Section(
                  title:
                      'Luma ${mode.displayNameFor(status.modeVersions[mode.name])}',
                  child: Column(
                    children: [
                      _UsageRow(
                        label: t.assistantUsageCurrentSession,
                        caption: t.assistantUsageRollingFiveHours,
                        fraction: status.usageFor(mode.name).fiveHourPct / 100,
                        trailing: _tokenUsageLabel(
                          status.usageFor(mode.name).fiveHourUsed,
                          status.usageFor(mode.name).fiveHourLimit,
                          status.usageFor(mode.name).fiveHourPct,
                        ),
                      ),
                      _UsageRow(
                        label: t.assistantUsageThisWeek,
                        caption: t.assistantUsageRollingWeek,
                        fraction: status.usageFor(mode.name).weeklyPct / 100,
                        trailing: _tokenUsageLabel(
                          status.usageFor(mode.name).weeklyUsed,
                          status.usageFor(mode.name).weeklyLimit,
                          status.usageFor(mode.name).weeklyPct,
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 20),
            Divider(height: 1, color: luma.border),
            const SizedBox(height: 8),
            if (status != null && status.webSearchLimit > 0)
              _UsageRow(
                label: t.assistantUsageWebSearch,
                caption: t.assistantUsageRollingWeek,
                help: t.assistantUsageLumaAssistantSubtitle,
                fraction: status.webSearchUsed / status.webSearchLimit,
                trailing: t.assistantUsageCountOf(
                  status.webSearchUsed,
                  status.webSearchLimit,
                ),
              ),
            _UsageRow(
              label: t.assistantUsageApiKeys,
              caption: t.assistantUsageApiKeysSubtitle,
              fraction: 0,
              trailing: t.assistantUsageUnlimited,
            ),
            _Section(
              title: t.assistantUsageByModel,
              subtitle: t.assistantUsageByModelSubtitle,
              child: _ModelBreakdown(
                usage: settings.modelUsage,
                modeVersions: status?.modeVersions ?? const {},
              ),
            ),
            _Section(
              title: t.assistantUsageStorage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
            ),
          ],
        );
      },
    );
  }
}

String _tokenUsageLabel(int used, int limit, int percent) => limit > 0
    ? '${compactTokens(used)} / ${compactTokens(limit)} · $percent%'
    : '$percent%';

/// A secondary block below the limits: a title, an optional muted line of
/// explanation, then its content, set apart by whitespace rather than boxes.
class _Section extends StatelessWidget {
  const _Section({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// One limit, after Claude's: its name and reset rule on the left, a thin
/// bar in the middle and "30% used" on the right — stacked on narrow screens.
/// [help] adds a "?" whose tooltip says what the limit covers.
class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.label,
    required this.caption,
    required this.fraction,
    required this.trailing,
    this.help,
  });

  final String label;
  final String caption;
  final double fraction;
  final String trailing;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final value = fraction.clamp(0.0, 1.0);
    final color = value >= 0.9
        ? luma.danger
        : value >= 0.75
        ? luma.warning
        : luma.accent;
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 4,
        backgroundColor: value == 0
            ? luma.border
            : color.withValues(alpha: 0.16),
        color: color,
      ),
    );
    final labels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (help != null) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: help!,
                child: Icon(
                  Icons.help_outline_rounded,
                  size: 15,
                  color: luma.textMuted,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(caption, style: TextStyle(color: luma.textMuted, fontSize: 13)),
      ],
    );
    final trailingText = Text(
      trailing,
      textAlign: TextAlign.right,
      style: TextStyle(
        color: value >= 0.9 ? luma.danger : luma.textSecondary,
        fontSize: 14,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: labels),
                    const SizedBox(width: 12),
                    trailingText,
                  ],
                ),
                const SizedBox(height: 10),
                bar,
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 260, child: labels),
              const SizedBox(width: 24),
              Expanded(child: bar),
              const SizedBox(width: 24),
              SizedBox(width: 140, child: trailingText),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: TextStyle(color: luma.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lifetime messages per model in one outlined card, heaviest first, with a
/// small "×5" tag on the models that cost more of the budget.
class _ModelBreakdown extends StatelessWidget {
  const _ModelBreakdown({required this.usage, required this.modeVersions});

  final Map<String, int> usage;
  final Map<String, String> modeVersions;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final used = [
      for (final e in kModelUsageEntries)
        if ((usage[e.key] ?? 0) > 0) (e, usage[e.key]!),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    if (used.isEmpty) return _Note(t.assistantUsageNoMessages);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: luma.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final (i, (entry, count)) in used.indexed) ...[
            if (i > 0) Divider(height: 1, color: luma.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.labelFor(modeVersions),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textPrimary, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    t.assistantUsageMessageCount(count),
                    style: TextStyle(
                      color: luma.textSecondary,
                      fontSize: 13.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      text,
      style: TextStyle(color: context.luma.textMuted, fontSize: 13.5),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
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
