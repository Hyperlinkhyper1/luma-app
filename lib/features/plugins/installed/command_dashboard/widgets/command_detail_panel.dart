import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../command_dashboard_page.dart';
import '../command_dashboard_scope.dart';
import '../command_icons.dart';
import '../command_models.dart';
import '../command_run.dart';
import 'host_connection_card.dart';

/// The selected command: its status, a host's connection, and its output.
class CommandDetailPanel extends StatelessWidget {
  const CommandDetailPanel({
    super.key,
    required this.command,
    required this.fill,
  });

  final DashCommand command;

  /// Stretch the output console to the panel's height (side-panel layout)
  /// instead of giving it a fixed height (stacked layout).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final repo = CommandDashboardScope.of(context);
    final run = repo.runOf(command.id);
    final started = run.startedAt;

    final console = _OutputConsole(command: command, run: run);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LumaIconBadge(
                    icon: commandIcon(command.icon),
                    color: command.runAsAdmin ? luma.warning : luma.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          command.name,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        RunStatusLabel(run: run),
                      ],
                    ),
                  ),
                  RunStopButton(command: command),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                command.command,
                style: monoStyle.copyWith(
                  color: luma.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              if (started != null) ...[
                const SizedBox(height: 6),
                Text(
                  t.cmdDashStartedAt(
                    MaterialLocalizations.of(context)
                        .formatTimeOfDay(TimeOfDay.fromDateTime(started)),
                  ),
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
              if (run.error != null) ...[
                const SizedBox(height: 10),
                _Notice(
                  icon: Icons.error_outline_rounded,
                  color: luma.danger,
                  text: run.error!,
                ),
              ],
              if (command.runAsAdmin) ...[
                const SizedBox(height: 10),
                _Notice(
                  icon: Icons.admin_panel_settings_rounded,
                  color: luma.warning,
                  text: t.cmdDashAdminNote,
                ),
              ],
            ],
          ),
        ),
        if (command.keepsRunning) ...[
          const SizedBox(height: 12),
          HostConnectionCard(run: run),
        ],
        const SizedBox(height: 12),
        if (fill) Expanded(child: console) else SizedBox(height: 320, child: console),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: context.luma.textPrimary, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputConsole extends StatefulWidget {
  const _OutputConsole({required this.command, required this.run});
  final DashCommand command;
  final CommandRun run;

  @override
  State<_OutputConsole> createState() => _OutputConsoleState();
}

class _OutputConsoleState extends State<_OutputConsole> {
  final _scroll = ScrollController();
  bool _followTail = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final atEnd =
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 24;
      _followTail = atEnd;
    });
  }

  @override
  void didUpdateWidget(covariant _OutputConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.command.id != widget.command.id) _followTail = true;
    if (!_followTail) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final t = L.of(context);
    final lines = widget.run.lines;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final consoleBg = isDark
        ? Color.lerp(luma.background, Colors.black, 0.35)!
        : const Color(0xFF1E1F26);
    const consoleText = Color(0xFFE6E6EA);

    final String? placeholder = widget.command.ownWindow
        ? t.cmdDashOwnWindowOutput
        : lines.isEmpty
            ? t.cmdDashNoOutput
            : null;

    return Container(
      decoration: BoxDecoration(
        color: consoleBg,
        borderRadius: decor.cardBorderRadius,
        border: Border.all(color: luma.border, width: decor.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 16, color: consoleText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.cmdDashOutput,
                    style: const TextStyle(
                      color: consoleText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t.cmdDashCopyOutput,
                  onPressed: lines.isEmpty
                      ? null
                      : () => Clipboard.setData(
                            ClipboardData(text: lines.join('\n')),
                          ),
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  color: consoleText,
                ),
                IconButton(
                  tooltip: t.cmdDashClearOutput,
                  onPressed: lines.isEmpty
                      ? null
                      : () => CommandDashboardScope.of(context)
                          .clearOutput(widget.command.id),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  color: consoleText,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
            child: placeholder != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        placeholder,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: consoleText.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : SelectionArea(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      itemCount: lines.length,
                      itemBuilder: (context, i) => Text(
                        lines[i],
                        style: monoStyle.copyWith(
                          color: consoleText,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
