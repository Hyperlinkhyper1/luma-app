import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../team_clipboard_models.dart';
import 'team_clipboard_style.dart';

/// The table's column widths for a row [width] wide. At their narrowest
/// the columns hug the right edge; on a wide screen they grow (up to 1.8×)
/// so names and labels stop truncating and the columns move left, while
/// the title keeps at least 40% of the row.
class _TaskColumns {
  factory _TaskColumns(double width) {
    final scale = ((width - _add - width * 0.4) / _base).clamp(1.0, 1.8);
    return _TaskColumns._(scale);
  }

  const _TaskColumns._(this.scale);

  final double scale;

  static const _add = 30.0;
  static const _base = 122.0 + 80 + 104 + 112 + 90 + 74;

  double get assignee => 122 * scale;
  double get subtasks => 80 * scale;
  double get type => 104 * scale;
  double get status => 112 * scale;
  double get updated => 90 * scale;
  double get activity => 74 * scale;
}

class TeamTaskHeader extends StatelessWidget {
  const TeamTaskHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    Widget label(String text) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: luma.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 10),
      child: LayoutBuilder(
        builder: (context, box) {
          final c = _TaskColumns(box.maxWidth);
          return Row(
            children: [
              Expanded(child: label(t.teamClipboardTaskTitle)),
              SizedBox(
                width: c.assignee,
                child: label(t.teamClipboardAssignee),
              ),
              SizedBox(
                width: c.subtasks,
                child: label(t.teamClipboardSubEntries),
              ),
              SizedBox(width: c.type, child: label(t.teamClipboardEditorKind)),
              SizedBox(width: c.status, child: label(t.teamClipboardStatus)),
              SizedBox(width: c.updated, child: label(t.teamClipboardUpdated)),
              SizedBox(
                width: c.activity,
                child: label(t.teamClipboardActivity),
              ),
              const SizedBox(width: _TaskColumns._add),
            ],
          );
        },
      ),
    );
  }
}

class TeamTaskRow extends StatelessWidget {
  const TeamTaskRow({
    super.key,
    required this.entry,
    required this.table,
    required this.child,
    required this.compact,
    required this.selected,
    required this.news,
    required this.subTotal,
    required this.subDone,
    required this.onTap,
    this.onAddSubEntry,
  });

  final TeamEntry entry;
  final bool table;
  final bool child;
  final bool compact;
  final bool selected;
  final bool news;
  final int subTotal;
  final int subDone;
  final VoidCallback onTap;
  final VoidCallback? onAddSubEntry;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final kindColor = teamKindColor(entry.kind, luma);
    final stageColor = entry.closed
        ? luma.textMuted
        : teamStageColor(entry.stage, luma);
    final status = entry.closed
        ? t.teamClipboardClosed
        : teamStageLabel(t, entry.stage, entry.kind);
    final name = entry.claimedBy;
    final assignee = name == null
        ? t.teamClipboardUnassigned
        : entry.claimedByMe
        ? t.teamClipboardYou
        : teamPerson(t, name);
    final title = Row(
      children: [
        if (child) ...[
          const SizedBox(width: 16),
          Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: 15,
            color: luma.textMuted,
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            entry.title,
            maxLines: table ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: entry.finished ? luma.textSecondary : luma.textPrimary,
              fontSize: 13,
              fontWeight: child ? FontWeight.w400 : FontWeight.w600,
              height: 1.35,
              decoration: entry.closed ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        if (entry.discord case final discord?) ...[
          const SizedBox(width: 6),
          if (teamDiscordMissingLabel(t, discord.missing) case final missing?)
            Tooltip(
              message: missing,
              child: Icon(
                Icons.warning_amber_rounded,
                size: 15,
                color: luma.warning,
              ),
            )
          else
            Tooltip(
              message: t.teamClipboardFromDiscord(
                teamPerson(t, discord.author),
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 14,
                color: luma.textMuted,
              ),
            ),
        ],
        if (news)
          Tooltip(
            message: t.teamClipboardNews,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 7),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: luma.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
    final typeLabel = _TaskLabel(
      label: teamKindLabel(t, entry.kind),
      color: kindColor,
      icon: teamKindIcon(entry.kind),
    );
    final statusLabel = _TaskLabel(
      label: table || name == null || entry.stage != TeamEntryStage.claimed
          ? status
          : t.teamClipboardClaimedBy(assignee),
      color: stageColor,
      icon: entry.closed
          ? Icons.lock_outline_rounded
          : teamStageIcon(entry.stage),
    );
    final progress = subTotal == 0
        ? Text('—', style: TextStyle(color: luma.textMuted, fontSize: 12))
        : Tooltip(
            message: t.teamClipboardSubProgress(subDone, subTotal),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  size: 14,
                  color: luma.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  '$subDone/$subTotal',
                  style: TextStyle(color: luma.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
    final activity = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TaskMetric(icon: Icons.attach_file_rounded, value: entry.files.length),
        const SizedBox(width: 9),
        _TaskMetric(
          icon: Icons.chat_bubble_outline_rounded,
          value: entry.messageCount,
        ),
      ],
    );
    final add = onAddSubEntry == null
        ? const SizedBox(width: 30)
        : SizedBox(
            width: 30,
            height: 32,
            child: IconButton(
              tooltip: t.teamClipboardAddSubEntry,
              onPressed: onAddSubEntry,
              padding: EdgeInsets.zero,
              icon: Icon(Icons.add_rounded, size: 17, color: luma.textMuted),
            ),
          );
    final Widget content = table
        ? LayoutBuilder(
            builder: (context, box) {
              final c = _TaskColumns(box.maxWidth);
              return Row(
                children: [
                  Expanded(child: title),
                  SizedBox(
                    width: c.assignee,
                    child: _Assignee(name: name, label: assignee),
                  ),
                  SizedBox(width: c.subtasks, child: progress),
                  SizedBox(
                    width: c.type,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: typeLabel,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: c.status,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: statusLabel,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: c.updated,
                    child: Text(
                      teamRelativeTime(context, entry.updatedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                    ),
                  ),
                  SizedBox(width: c.activity, child: activity),
                  add,
                ],
              );
            },
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: title),
                  add,
                ],
              ),
              const SizedBox(height: 7),
              Padding(
                padding: EdgeInsets.only(left: child ? 37 : 0),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    typeLabel,
                    statusLabel,
                    if (subTotal > 0) progress,
                    if (entry.files.isNotEmpty || entry.messageCount > 0)
                      activity,
                    if (!compact)
                      Text(
                        '${teamPerson(t, entry.author)} · ${teamRelativeTime(context, entry.updatedAt)}',
                        style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                      ),
                  ],
                ),
              ),
            ],
          );
    final base = Color.lerp(
      luma.surface,
      luma.background,
      child || entry.finished ? 0.55 : 0.24,
    )!;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? Color.lerp(base, luma.accent, 0.10) : base,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: table ? 46 : 78),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: selected ? luma.accent : kindColor,
                  width: 3,
                ),
                bottom: BorderSide(color: luma.border.withValues(alpha: 0.65)),
              ),
            ),
            padding: EdgeInsets.fromLTRB(11, table ? 6 : 10, 8, table ? 6 : 10),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _TaskLabel extends StatelessWidget {
  const _TaskLabel({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Assignee extends StatelessWidget {
  const _Assignee({required this.name, required this.label});

  final String? name;
  final String label;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final initials = name
        ?.trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s.characters.first.toUpperCase())
        .join();
    return Tooltip(
      message: label,
      child: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: name == null
                  ? luma.background
                  : luma.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: luma.border),
            ),
            child: name == null
                ? Icon(
                    Icons.person_outline_rounded,
                    size: 15,
                    color: luma.textMuted,
                  )
                : Text(
                    initials?.isEmpty == false ? initials! : '?',
                    style: TextStyle(
                      color: luma.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: luma.textSecondary, fontSize: 11),
            ),
          ),
          const SizedBox(width: 7),
        ],
      ),
    );
  }
}

class _TaskMetric extends StatelessWidget {
  const _TaskMetric({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: luma.textMuted),
        const SizedBox(width: 3),
        Text('$value', style: TextStyle(color: luma.textMuted, fontSize: 10.5)),
      ],
    );
  }
}
