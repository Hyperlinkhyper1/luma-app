import 'dart:io';

import 'package:flutter/material.dart';

import '../../../account/plan.dart';
import '../../../l10n/app_localizations.dart';
import '../../../settings/settings_controller.dart';
import '../../../theme/luma_theme.dart';
import '../assistant_auto_router.dart';
import '../assistant_compose_mode.dart';
import '../chat_scope.dart';
import '../chat_usage.dart';
import '../data/chat_repository.dart';
import '../providers/ai_modes.dart';
import '../providers/ai_providers.dart';
import 'compose_mode_menu.dart';

const assistantDetailsPanelWidth = 288.0;

/// The model the open chat talks to, named the way the model picker does.
String assistantModelLabel(SettingsController settings) {
  final providerId = settings.aiProviderId;
  if (isApiKeyProvider(providerId)) {
    final provider = aiProviderById(providerId);
    return settings.aiModelFor(providerId) ??
        provider.defaultModel ??
        provider.displayName;
  }
  if (providerId == AiProviderId.local.name) return 'Luma Assistant';
  if (settings.aiMode == kAutoAiMode) return 'Luma Auto';
  final mode = AiMode.values.asNameMap()[settings.aiMode];
  return mode == null ? 'Luma' : 'Luma ${mode.displayNameFor(null)}';
}

/// The open chat's details down the right edge: what it runs on, how full
/// its context window is, and the files it has produced.
class AssistantDetailsPanel extends StatelessWidget {
  const AssistantDetailsPanel({
    super.key,
    required this.conversationId,
    required this.settings,
    required this.composeMode,
    required this.onClose,
    this.projectName,
  });

  final int conversationId;
  final SettingsController settings;
  final AssistantComposeMode composeMode;
  final String? projectName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final repo = ChatScope.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: luma.rail,
        border: Border(left: BorderSide(color: luma.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.assistantDetailsTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: luma.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: t.assistantDetailsHide,
                    onPressed: onClose,
                    iconSize: 18,
                    color: luma.textSecondary,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChatMessageRecord>>(
              stream: repo.watchMessages(conversationId),
              builder: (context, snap) {
                final messages = snap.data ?? const <ChatMessageRecord>[];
                return ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    _EnvironmentSection(
                      settings: settings,
                      composeMode: composeMode,
                      projectName: projectName,
                    ),
                    const _SectionDivider(),
                    _ContextSection(
                      messages: messages,
                      contextWindow: contextWindowFor(settings.aiProviderId),
                    ),
                    const _SectionDivider(),
                    _FilesSection(
                      conversationId: conversationId,
                      repository: repo,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Divider(height: 1, thickness: 1, color: context.luma.border),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {this.trailing});
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: luma.textSecondary,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(fontSize: 12.5, color: luma.textMuted),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.detail});
  final IconData icon;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: luma.textSecondary),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: luma.textPrimary),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '· $detail',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: luma.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: luma.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: luma.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentSection extends StatelessWidget {
  const _EnvironmentSection({
    required this.settings,
    required this.composeMode,
    this.projectName,
  });

  final SettingsController settings;
  final AssistantComposeMode composeMode;
  final String? projectName;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final provider = aiProviderById(settings.aiProviderId);
    final modeLabel = composeModeLabel(t, composeMode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(t.assistantDetailsEnvironment),
        _InfoRow(
          icon: Icons.auto_awesome_outlined,
          label: assistantModelLabel(settings),
          detail: isApiKeyProvider(settings.aiProviderId)
              ? provider.displayName
              : null,
        ),
        if (projectName != null)
          _InfoRow(icon: Icons.folder_outlined, label: projectName!),
        _InfoRow(
          icon: composeModeIcon(composeMode),
          label: modeLabel.isEmpty ? t.assistantDetailsChatMode : modeLabel,
        ),
        _InfoRow(
          icon: Icons.workspace_premium_outlined,
          label: planById(settings.selectedPlanId).name,
        ),
      ],
    );
  }
}

class _ContextSection extends StatelessWidget {
  const _ContextSection({required this.messages, required this.contextWindow});

  final List<ChatMessageRecord> messages;
  final int contextWindow;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final usage = ChatReplyUsage.latest(messages);
    final used = usage?.contextTokens ?? 0;
    final fraction = (used / contextWindow).clamp(0.0, 1.0);
    final percent = (fraction * 100).round();
    final mine = messages.where((m) => m.role == 'user').length;
    final replies = messages.where((m) => m.role == 'assistant').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(t.assistantDetailsContext),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.assistantDetailsContextUsed(percent),
                  style: TextStyle(fontSize: 14, color: luma.textPrimary),
                ),
              ),
              Text(
                '${compactTokens(used)} / ${compactTokens(contextWindow)}',
                style: TextStyle(fontSize: 12.5, color: luma.textMuted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              color: fraction >= 0.9 ? luma.danger : luma.accent,
              backgroundColor: luma.border,
            ),
          ),
        ),
        if (usage == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              t.assistantDetailsContextPending,
              style: TextStyle(fontSize: 12.5, color: luma.textMuted),
            ),
          )
        else ...[
          _StatRow(
            t.assistantDetailsInputTokens,
            compactTokens(usage.inputTokens),
          ),
          _StatRow(
            t.assistantDetailsOutputTokens,
            compactTokens(usage.outputTokens),
          ),
        ],
        _StatRow(t.assistantDetailsYourMessages, '$mine'),
        _StatRow(t.assistantDetailsReplies, '$replies'),
      ],
    );
  }
}

class _FilesSection extends StatelessWidget {
  const _FilesSection({required this.conversationId, required this.repository});

  final int conversationId;
  final ChatRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return StreamBuilder<List<ChatArtifactRecord>>(
      stream: repository.watchArtifacts(),
      builder: (context, snap) {
        final files = [
          for (final a in snap.data ?? const <ChatArtifactRecord>[])
            if (a.conversationId == conversationId) a,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              t.assistantDetailsFiles,
              trailing: files.isEmpty ? null : '${files.length}',
            ),
            if (files.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  t.assistantDetailsNoFiles,
                  style: TextStyle(fontSize: 12.5, color: luma.textMuted),
                ),
              )
            else
              for (final file in files.take(8))
                _InfoRow(
                  icon: file.mimeType.startsWith('image/')
                      ? Icons.image_outlined
                      : Icons.description_outlined,
                  label: file.name,
                  detail: File(file.path).existsSync()
                      ? null
                      : t.assistantDetailsFileMissing,
                ),
          ],
        );
      },
    );
  }
}
