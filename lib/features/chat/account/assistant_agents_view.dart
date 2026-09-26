import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';
import '../../plugins/installed/ai_usage/ai_workbench_models.dart';
import '../../plugins/installed/ai_usage/ai_workbench_scope.dart';
import 'assistant_panels.dart';

/// Every agent built in the AI Usage plugin's agent builder. Read-only for
/// now: running an agent from the assistant comes later.
class AssistantAgentsView extends StatelessWidget {
  const AssistantAgentsView({super.key, required this.onOpenPlugin});

  final ValueChanged<String> onOpenPlugin;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final agents =
        AiWorkbenchScope.maybeOf(context)?.agents ??
        const <AiAgentDefinition>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 32),
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 36),
          child: AssistantPanelTitle(
            t.assistantMenuAgents,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: luma.accentSubtle,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                t.assistantAgentsComingSoon,
                style: TextStyle(
                  color: luma.accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t.assistantAgentsSubtitle,
          style: TextStyle(color: luma.textMuted, fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 20),
        if (agents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: LumaEmptyState(
              icon: Icons.smart_toy_outlined,
              title: t.assistantAgentsEmpty,
              subtitle: t.assistantAgentsEmptyHint,
              action: LumaGhostButton(
                label: t.assistantAgentsOpenBuilder,
                icon: Icons.open_in_new_rounded,
                onTap: () => onOpenPlugin('ai-usage'),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700
                  ? 3
                  : constraints.maxWidth >= 440
                  ? 2
                  : 1;
              const gap = 12.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final agent in agents)
                    SizedBox(
                      width: width,
                      child: _AgentCard(agent: agent),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent});

  final AiAgentDefinition agent;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: luma.accentSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 17,
                  color: luma.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  agent.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              agent.description.isEmpty
                  ? t.assistantAgentsNoDescription
                  : agent.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: agent.description.isEmpty
                    ? luma.textMuted
                    : luma.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          Row(
            children: [
              if (agent.preferredModel.isNotEmpty) ...[
                Flexible(
                  child: Text(
                    agent.preferredModel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ),
                Text(
                  ' · ',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
              Text(
                t.assistantMemoryUpdated(
                  DateFormat.MMMd(locale).format(agent.updatedAt),
                ),
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
