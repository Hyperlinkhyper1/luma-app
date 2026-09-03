import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';
import 'ai_usage_format.dart';
import 'ai_usage_source.dart';
import 'ai_usage_stats.dart';

/// "low" -> "Low", "xhigh" -> "Extra high" — the tiers Claude Code itself
/// uses, title-cased for display. Exhaustive over [AiEffort], so there is no
/// fallback arm: an unrecognised log value never becomes an [AiEffort] in the
/// first place (see `effortFromLog`), it becomes null and reads as
/// "Unspecified".
String effortLabel(AiEffort? effort) => switch (effort) {
      null => 'Unspecified',
      AiEffort.minimal => 'Minimal',
      AiEffort.low => 'Low',
      AiEffort.medium => 'Medium',
      AiEffort.high => 'High',
      AiEffort.xhigh => 'Extra high',
      AiEffort.max => 'Max',
    };

/// Claude-only: every model actually used, broken down by the reasoning-effort
/// tier Claude Code ran it at. Other sources don't record an effort tier at
/// all, so this section says nothing about Codex/Antigravity usage.
///
/// Takes the already-aggregated [tiers] rather than the raw turns: the caller
/// needs to know whether there is anything to show before deciding to build
/// this at all, and aggregating is a full pass over every turn in range.
class EffortBreakdownSection extends StatelessWidget {
  const EffortBreakdownSection({super.key, required this.tiers});

  final List<ModelEffortUsageTotal> tiers;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final byModel = <String, List<ModelEffortUsageTotal>>{};
    for (final t in tiers) {
      byModel.putIfAbsent(t.model, () => []).add(t);
    }
    // Models ordered by their own total tokens, most-used first — matches
    // the ordering convention of the model table above.
    final models = byModel.keys.toList()
      ..sort((a, b) {
        final aTokens = byModel[a]!.fold<int>(0, (s, e) => s + e.totalTokens);
        final bTokens = byModel[b]!.fold<int>(0, (s, e) => s + e.totalTokens);
        return bTokens.compareTo(aTokens);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Claude Effort Breakdown',
          style: TextStyle(
              color: luma.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'How hard each Claude model was asked to think, by turns and tokens spent.',
          style: TextStyle(color: luma.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < models.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _EffortModelGroup(model: models[i], tiers: byModel[models[i]]!),
        ],
      ],
    );
  }
}

class _EffortModelGroup extends StatelessWidget {
  const _EffortModelGroup({required this.model, required this.tiers});

  final String model;
  final List<ModelEffortUsageTotal> tiers;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final maxTokens =
        tiers.fold<int>(0, (a, t) => t.totalTokens > a ? t.totalTokens : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName(AiUsageSource.claudeCode, model),
          style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < tiers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _EffortTierRow(tier: tiers[i], maxTokens: maxTokens),
        ],
      ],
    );
  }
}

class _EffortTierRow extends StatelessWidget {
  const _EffortTierRow({required this.tier, required this.maxTokens});

  final ModelEffortUsageTotal tier;
  final int maxTokens;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final fraction = maxTokens == 0 ? 0.0 : tier.totalTokens / maxTokens;
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  effortLabel(tier.effort),
                  style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
                ),
              ),
              Text(
                '${tier.turnCount} turns',
                style: TextStyle(color: luma.textMuted, fontSize: 11.5),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 60,
                child: Text(
                  formatTokens(tier.totalTokens),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: luma.textSecondary, fontSize: 11.5),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 64,
                child: Text(
                  formatCost(tier.cost),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: luma.success,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 6, color: luma.border),
                  Container(
                    height: 6,
                    width: constraints.maxWidth * fraction,
                    color: luma.accent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
