import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'command_dashboard_repository.dart';
import 'command_dashboard_scope.dart';
import 'command_editor_dialog.dart';
import 'command_icons.dart';
import 'command_models.dart';
import 'command_run.dart';
import 'widgets/command_detail_panel.dart';

class CommandDashboardPage extends StatefulWidget {
  const CommandDashboardPage({super.key});

  @override
  State<CommandDashboardPage> createState() => _CommandDashboardPageState();
}

class _CommandDashboardPageState extends State<CommandDashboardPage> {
  String? _selectedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CommandDashboardRepository.isSupported) {
      CommandDashboardScope.of(context).load();
    }
  }

  Future<void> _add() async {
    final repo = CommandDashboardScope.of(context);
    final created = await showCommandEditor(context);
    if (created == null) return;
    await repo.upsert(created);
    setState(() => _selectedId = created.id);
  }

  Future<void> _addScript() async {
    final repo = CommandDashboardScope.of(context);
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['bat', 'cmd', 'ps1'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;
    final name = fileName(path);
    final dot = name.lastIndexOf('.');
    final created = await showCommandEditor(
      context,
      initial: DashCommand(
        id: CommandDashboardRepository.newId(),
        name: dot > 0 ? name.substring(0, dot) : name,
        kind: CommandKind.script,
        command: path,
        icon: 'play',
      ),
      isNew: true,
    );
    if (created == null) return;
    await repo.upsert(created);
    setState(() => _selectedId = created.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    if (!CommandDashboardRepository.isSupported) {
      return LumaEmptyState(
        icon: Icons.desktop_windows_rounded,
        title: t.cmdDashWindowsOnlyTitle,
        subtitle: t.cmdDashWindowsOnlySubtitle,
      );
    }
    final repo = CommandDashboardScope.of(context);
    if (!repo.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final commands = repo.commands;
    final selected = commands.where((c) => c.id == _selectedId).firstOrNull ??
        commands.firstOrNull;

    final header = _Header(
      count: commands.length,
      running: repo.activeCount,
      onAdd: _add,
      onAddScript: _addScript,
    );

    if (commands.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(context.isPhoneWidth ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: LumaEmptyState(
                icon: Icons.terminal_rounded,
                title: t.cmdDashEmptyTitle,
                subtitle: t.cmdDashEmptySubtitle,
                action: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    LumaPrimaryButton(
                      label: t.cmdDashAddCommand,
                      icon: Icons.add_rounded,
                      onTap: _add,
                    ),
                    LumaGhostButton(
                      label: t.cmdDashAddScript,
                      icon: Icons.description_rounded,
                      onTap: _addScript,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final grid = _CommandGrid(
      commands: commands,
      selectedId: selected?.id,
      onSelect: (id) => setState(() => _selectedId = id),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = context.isPhoneWidth ? 12.0 : 24.0;
        if (constraints.maxWidth >= 1000) {
          return Padding(
            padding: EdgeInsets.all(pad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [header, const SizedBox(height: 16), grid],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 440,
                  child: selected == null
                      ? const SizedBox.shrink()
                      : CommandDetailPanel(command: selected, fill: true),
                ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 16),
              grid,
              if (selected != null) ...[
                const SizedBox(height: 16),
                CommandDetailPanel(command: selected, fill: false),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.running,
    required this.onAdd,
    required this.onAddScript,
  });

  final int count;
  final int running;
  final VoidCallback onAdd;
  final VoidCallback onAddScript;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          t.pluginNameCommandDashboard,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.cmdDashSummary(count, running),
          style: TextStyle(color: luma.textSecondary, fontSize: 13),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        LumaGhostButton(
          label: t.cmdDashAddScript,
          icon: Icons.description_rounded,
          onTap: onAddScript,
        ),
        LumaPrimaryButton(
          label: t.cmdDashAddCommand,
          icon: Icons.add_rounded,
          onTap: onAdd,
        ),
      ],
    );
    return LumaCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 14), actions],
            );
          }
          return Row(
            children: [
              LumaIconBadge(icon: Icons.terminal_rounded, color: luma.accent),
              const SizedBox(width: 14),
              Expanded(child: title),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _CommandGrid extends StatelessWidget {
  const _CommandGrid({
    required this.commands,
    required this.selectedId,
    required this.onSelect,
  });

  final List<DashCommand> commands;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columns = (constraints.maxWidth / 260).floor().clamp(1, 4);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final command in commands)
              SizedBox(
                width: width,
                child: CommandTile(
                  command: command,
                  selected: command.id == selectedId,
                  onSelect: () => onSelect(command.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One button on the dashboard: what it runs, how, and a one-click Run.
class CommandTile extends StatefulWidget {
  const CommandTile({
    super.key,
    required this.command,
    required this.selected,
    required this.onSelect,
  });

  final DashCommand command;
  final bool selected;
  final VoidCallback onSelect;

  @override
  State<CommandTile> createState() => _CommandTileState();
}

class _CommandTileState extends State<CommandTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final repo = CommandDashboardScope.of(context);
    final command = widget.command;
    final run = repo.runOf(command.id);
    final borderColor = widget.selected
        ? luma.accent
        : _hovering
            ? Color.lerp(luma.border, luma.accent, 0.4)!
            : luma.border;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: command.name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onSelect,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _hovering ? luma.surfaceHover : luma.surface,
              borderRadius: decor.cardBorderRadius,
              border: Border.all(
                color: borderColor,
                width: widget.selected ? 2 : decor.borderWidth,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    LumaIconBadge(
                      icon: commandIcon(command.icon),
                      color: command.runAsAdmin ? luma.warning : luma.accent,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        command.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    CommandMenuButton(command: command),
                  ],
                ),
                const SizedBox(height: 10),
                Tooltip(
                  message: command.command,
                  waitDuration: const Duration(milliseconds: 500),
                  child: Text(
                    command.isScript ? fileName(command.command) : command.command,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoStyle.copyWith(
                      color: luma.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                CommandBadges(command: command),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: RunStatusLabel(run: run)),
                    const SizedBox(width: 8),
                    RunStopButton(command: command, compact: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Admin / host / own-window tags, each with an icon so the meaning never
/// rests on colour alone.
class CommandBadges extends StatelessWidget {
  const CommandBadges({super.key, required this.command});
  final DashCommand command;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final badges = [
      if (command.isScript)
        (Icons.description_rounded, t.cmdDashKindScript, luma.textSecondary),
      if (command.runAsAdmin)
        (Icons.admin_panel_settings_rounded, t.cmdDashBadgeAdmin, luma.warning),
      if (command.keepsRunning)
        (Icons.cell_tower_rounded, t.cmdDashBadgeHost, luma.accent),
      if (command.ownWindow)
        (Icons.open_in_new_rounded, t.cmdDashBadgeWindow, luma.textSecondary),
    ];
    if (badges.isEmpty) return const SizedBox(height: 22);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (icon, label, color) in badges)
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A dot plus words: running, finished, failed with its exit code.
class RunStatusLabel extends StatelessWidget {
  const RunStatusLabel({super.key, required this.run});
  final CommandRun run;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final (label, color) = switch (run.status) {
      RunStatus.idle => (t.cmdDashStatusIdle, luma.textMuted),
      RunStatus.starting => (t.cmdDashStatusStarting, luma.warning),
      RunStatus.running => (t.cmdDashStatusRunning, luma.success),
      RunStatus.exited when run.stopped => (t.cmdDashStatusStopped, luma.textMuted),
      RunStatus.exited => (t.cmdDashStatusFinished, luma.textSecondary),
      RunStatus.failed => (
          run.exitCode == null
              ? t.cmdDashStatusFailedToStart
              : t.cmdDashStatusFailed(run.exitCode!),
          luma.danger,
        ),
    };
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: run.status == RunStatus.idle ? luma.textMuted : luma.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// The one-click Run, which turns into Stop while the command is up.
class RunStopButton extends StatelessWidget {
  const RunStopButton({super.key, required this.command, this.compact = false});
  final DashCommand command;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final repo = CommandDashboardScope.of(context);
    final run = repo.runOf(command.id);
    if (run.isActive) {
      return _StopButton(
        label: t.cmdDashStop,
        color: luma.danger,
        stopping: run.stopped,
        onTap: run.stopped ? null : () => repo.stop(command.id),
      );
    }
    return LumaPrimaryButton(
      label: t.cmdDashRun,
      icon: command.runAsAdmin
          ? Icons.admin_panel_settings_rounded
          : Icons.play_arrow_rounded,
      onTap: () => repo.run(command),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({
    required this.label,
    required this.color,
    required this.stopping,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool stopping;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: stopping
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : const Icon(Icons.stop_rounded, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

enum _MenuAction { edit, duplicate, delete }

/// Edit / duplicate / delete for one command.
class CommandMenuButton extends StatelessWidget {
  const CommandMenuButton({super.key, required this.command});
  final DashCommand command;

  Future<void> _onSelected(BuildContext context, _MenuAction action) async {
    final repo = CommandDashboardScope.of(context);
    final t = L.of(context);
    switch (action) {
      case _MenuAction.edit:
        final edited = await showCommandEditor(context, initial: command);
        if (edited != null) await repo.upsert(edited);
      case _MenuAction.duplicate:
        await repo.upsert(command.duplicate(
          CommandDashboardRepository.newId(),
          t.cmdDashCopyName(command.name),
        ));
      case _MenuAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t.cmdDashDeleteTitle(command.name)),
            content: Text(t.cmdDashDeleteBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t.cmdDashCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: context.luma.danger,
                ),
                child: Text(t.cmdDashDelete),
              ),
            ],
          ),
        );
        if (confirmed == true) await repo.remove(command.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return PopupMenuButton<_MenuAction>(
      tooltip: t.cmdDashMoreActions,
      icon: Icon(Icons.more_vert_rounded, color: luma.textSecondary),
      onSelected: (action) => _onSelected(context, action),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MenuAction.edit,
          child: _MenuRow(icon: Icons.edit_rounded, label: t.cmdDashEdit),
        ),
        PopupMenuItem(
          value: _MenuAction.duplicate,
          child: _MenuRow(icon: Icons.copy_rounded, label: t.cmdDashDuplicate),
        ),
        PopupMenuItem(
          value: _MenuAction.delete,
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            label: t.cmdDashDelete,
            color: luma.danger,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
