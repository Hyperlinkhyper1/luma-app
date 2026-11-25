import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';
import '../chat_turn_activity.dart';
import 'chat_markdown.dart';
import 'chat_moon.dart';

class ChatActivityTimeline extends StatelessWidget {
  const ChatActivityTimeline({super.key, required this.entries});

  final List<ChatTurnActivity> entries;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final entry in entries)
        switch (entry) {
          ChatCommentary(:final text) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: ChatMarkdown(source: text),
          ),
          ChatToolActivity() => _ToolRow(tool: entry),
        },
    ],
  );
}

class ChatThinkingRow extends StatelessWidget {
  const ChatThinkingRow({super.key});

  @override
  Widget build(BuildContext context) => _ActivityRow(
    icon: ChatMoon(
      size: 19,
      animating: !MediaQuery.disableAnimationsOf(context),
    ),
    label: L.of(context).assistantActivityThinking,
    live: true,
  );
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.tool});

  final ChatToolActivity tool;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final (label, icon) = switch (tool.name) {
      'web_search' => (t.assistantActivitySearchWeb, Icons.language_rounded),
      'search_notes' => (t.assistantActivitySearchNotes, Icons.search_rounded),
      'create_note' => (t.assistantActivityWriteNote, Icons.edit_note_rounded),
      'create_artifact' || 'create_office_file' => (
        t.assistantActivityCreateFile,
        Icons.note_add_outlined,
      ),
      'edit_office_file' => (t.assistantActivityEditFile, Icons.edit_outlined),
      'read_office_file' => (
        t.assistantActivityReadFile,
        Icons.description_outlined,
      ),
      'generate_qr_code' => (t.assistantSuggestQr, Icons.qr_code_rounded),
      'install_plugin' => (
        t.assistantActivityInstallPlugin,
        Icons.extension_outlined,
      ),
      final name => (_toolLabel(name, t), Icons.build_outlined),
    };
    final (status, statusIcon, color) = switch (tool.state) {
      ChatToolState.running => (null, null, luma.accent),
      ChatToolState.completed => (
        t.commonDone,
        Icons.check_rounded,
        luma.textMuted,
      ),
      ChatToolState.needsInfo => (
        t.assistantActivityNeedsInfo,
        Icons.info_outline,
        luma.textMuted,
      ),
      ChatToolState.unavailable => (
        t.assistantActivityUnavailable,
        Icons.block_rounded,
        luma.textMuted,
      ),
      ChatToolState.failed => (t.commonError, Icons.error_outline, luma.danger),
    };
    final running = tool.state == ChatToolState.running;
    return _ActivityRow(
      icon: Icon(icon, size: 16, color: running ? luma.accent : luma.textMuted),
      label: status == null || tool.state == ChatToolState.completed
          ? label
          : '$label · $status',
      live: running,
      trailing: statusIcon == null
          ? SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: color,
                value: MediaQuery.disableAnimationsOf(context) ? 0.75 : null,
              ),
            )
          : Tooltip(
              message: status!,
              child: Icon(statusIcon, size: 15, color: color),
            ),
    );
  }

  static final _toolName = RegExp(r'^[a-z][a-z0-9_]{0,79}$');

  String _toolLabel(String name, L t) => _toolName.hasMatch(name)
      ? name[0].toUpperCase() + name.substring(1).replaceAll('_', ' ')
      : t.assistantActivityTool;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.label,
    required this.live,
    this.trailing,
  });

  final Widget icon;
  final String label;
  final bool live;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: live,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 19, child: icon),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: context.luma.textSecondary, fontSize: 13),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    ),
  );
}
