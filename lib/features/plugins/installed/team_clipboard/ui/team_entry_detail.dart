import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/team_clipboard_api.dart';
import '../team_clipboard_controller.dart';
import '../team_clipboard_models.dart';
import '../team_clipboard_scope.dart';
import 'team_clipboard_style.dart';
import 'team_entry_editor.dart';
import 'team_files.dart';
import 'team_model_view.dart';

/// Runs [action] and shows what went wrong, if anything, as a snack bar.
Future<void> _attempt(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await action();
  } on TeamClipboardApiException catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('$e')));
  }
}

/// The three views of an open entry.
enum TeamDetailTab { overview, files, chat }

/// Everything about one entry, under a fixed header: its stage, brief and
/// sub-entries on [TeamDetailTab.overview], its files with a big texture
/// and 3D model viewer on [TeamDetailTab.files], and its chat on
/// [TeamDetailTab.chat]. Pass [tab] and [onTab] to keep the tab as the user
/// moves between entries; otherwise it's kept here. With [onClose] the
/// header carries a close button that goes back to the board.
class TeamEntryDetail extends StatefulWidget {
  const TeamEntryDetail({
    super.key,
    required this.entry,
    this.onClose,
    this.tab,
    this.onTab,
  });

  final TeamEntry entry;
  final VoidCallback? onClose;
  final TeamDetailTab? tab;
  final ValueChanged<TeamDetailTab>? onTab;

  @override
  State<TeamEntryDetail> createState() => _TeamEntryDetailState();
}

class _TeamEntryDetailState extends State<TeamEntryDetail> {
  TeamDetailTab _tab = TeamDetailTab.overview;
  String? _viewing;

  TeamDetailTab get _current => widget.tab ?? _tab;

  void _setTab(TeamDetailTab tab) {
    setState(() => _tab = tab);
    widget.onTab?.call(tab);
  }

  @override
  void didUpdateWidget(TeamEntryDetail old) {
    super.didUpdateWidget(old);
    if (old.entry.id != widget.entry.id) _viewing = null;
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final entry = widget.entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (entry.parentId != null) ...[
                _ParentLink(parentId: entry.parentId!),
                const SizedBox(height: 8),
              ],
              _Header(entry: entry, onClose: widget.onClose),
              const SizedBox(height: 10),
              _Tabs(
                current: _current,
                onTab: _setTab,
                labels: {
                  TeamDetailTab.overview: (t.teamClipboardTabOverview, 0),
                  TeamDetailTab.files: (
                    t.teamClipboardFiles,
                    entry.files.length,
                  ),
                  TeamDetailTab.chat: (t.teamClipboardChat, entry.messageCount),
                },
              ),
            ],
          ),
        ),
        Divider(height: 1, color: luma.border),
        Expanded(
          child: switch (_current) {
            TeamDetailTab.overview => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (entry.closed) ...[
                    _ClosedBanner(entry: entry),
                    const SizedBox(height: 14),
                  ],
                  if (entry.discord != null) ...[
                    _DiscordBanner(discord: entry.discord!),
                    const SizedBox(height: 14),
                  ],
                  _StageTrack(entry: entry),
                  const SizedBox(height: 22),
                  _Brief(entry: entry),
                  if (entry.parentId == null) ...[
                    const SizedBox(height: 24),
                    _SubEntries(entry: entry),
                  ],
                ],
              ),
            ),
            TeamDetailTab.files => _Files(
              entry: entry,
              viewing: _viewing,
              onView: (id) => setState(() => _viewing = id),
            ),
            TeamDetailTab.chat => _Chat(entry: entry),
          },
        ),
      ],
    );
  }
}

/// Overview · Files 3 · Chat 12, underlined under the one on show.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.current,
    required this.onTab,
    required this.labels,
  });

  final TeamDetailTab current;
  final ValueChanged<TeamDetailTab> onTab;
  final Map<TeamDetailTab, (String, int)> labels;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in TeamDetailTab.values)
            _TabButton(
              label: labels[tab]!.$1,
              count: labels[tab]!.$2,
              selected: tab == current,
              onTap: () => onTab(tab),
              luma: luma,
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.luma,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 9),
          margin: const EdgeInsets.only(right: 18),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? luma.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? luma.textPrimary : luma.textSecondary,
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? luma.accentSubtle : luma.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? luma.accent : luma.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The chat: newest at the bottom, the composer under it.
class _Chat extends StatelessWidget {
  const _Chat({required this.entry});

  final TeamEntry entry;

  @override
  Widget build(BuildContext context) {
    final messages = entry.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: messages == null
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
              ? Center(child: _NoMessages(closed: entry.closed))
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final index = messages.length - 1 - i;
                    return _Bubble(
                      message: messages[index],
                      showAuthor:
                          index == 0 ||
                          messages[index - 1].author != messages[index].author,
                    );
                  },
                ),
        ),
        TeamComposer(entry: entry),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.entry, this.onClose});

  final TeamEntry entry;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final controller = TeamClipboardScope.of(context);
    final kindColor = teamKindColor(entry.kind, luma);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LumaIconBadge(icon: teamKindIcon(entry.kind), color: kindColor),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                entry.title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TeamPill(
                    label: teamKindLabel(t, entry.kind),
                    color: kindColor,
                    icon: teamKindIcon(entry.kind),
                  ),
                  TeamPill(
                    label: entry.closed
                        ? t.teamClipboardClosed
                        : teamStageLabel(t, entry.stage, entry.kind),
                    color: entry.closed
                        ? luma.textMuted
                        : teamStageColor(entry.stage, luma),
                    icon: entry.closed
                        ? Icons.lock_rounded
                        : teamStageIcon(entry.stage),
                    filled: entry.stage == TeamEntryStage.added,
                  ),
                  Text(
                    '${t.teamClipboardByAuthor(teamPerson(t, entry.author))}'
                    ' · ${teamRelativeTime(context, entry.createdAt)}',
                    style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (entry.canEdit || entry.canClose || entry.canDelete)
          PopupMenuButton<String>(
            tooltip: t.commonMore,
            icon: Icon(Icons.more_horiz_rounded, color: luma.textSecondary),
            onSelected: (value) => switch (value) {
              'edit' => showTeamEntryEditor(
                context,
                controller,
                existing: entry,
              ),
              'close' => _attempt(
                context,
                () => controller.setClosed(entry.id, !entry.closed),
              ),
              'delete' => _confirmDelete(context, controller),
              _ => null,
            },
            itemBuilder: (context) => [
              if (entry.canEdit)
                PopupMenuItem(
                  value: 'edit',
                  child: _MenuRow(
                    icon: Icons.edit_rounded,
                    label: t.teamClipboardEditEntry,
                  ),
                ),
              if (entry.canClose)
                PopupMenuItem(
                  value: 'close',
                  child: _MenuRow(
                    icon: entry.closed
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded,
                    label: entry.closed
                        ? t.teamClipboardReopen
                        : t.teamClipboardCloseThread,
                  ),
                ),
              if (entry.canDelete) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: _MenuRow(
                    icon: Icons.delete_outline_rounded,
                    label: t.teamClipboardDeleteEntry,
                    color: luma.danger,
                  ),
                ),
              ],
            ],
          ),
        if (onClose != null)
          IconButton(
            tooltip: t.commonClose,
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: luma.textSecondary),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TeamClipboardController controller,
  ) async {
    final t = L.of(context);
    final luma = context.luma;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.teamClipboardDeleteConfirmTitle),
        content: Text(t.teamClipboardDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: luma.danger),
            child: Text(t.commonDelete),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final navigator = Navigator.of(context);
      final pushed = navigator.canPop();
      await _attempt(context, () => controller.delete(entry.id));
      if (pushed && controller.selectedId == null) navigator.maybePop();
    }
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.luma.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: c)),
      ],
    );
  }
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({required this.entry});

  final TeamEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: teamFinishedSurface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: 18, color: luma.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.teamClipboardThreadClosed,
              style: TextStyle(color: luma.textSecondary),
            ),
          ),
          if (entry.canClose)
            TextButton.icon(
              onPressed: () => _attempt(
                context,
                () =>
                    TeamClipboardScope.read(context).setClosed(entry.id, false),
              ),
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(t.teamClipboardReopen),
            ),
        ],
      ),
    );
  }
}

Future<void> _openDiscord(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Where an entry the bot made came from: who posted it, a link back to
/// the thread, what it still misses, and the attachments only Discord has.
class _DiscordBanner extends StatelessWidget {
  const _DiscordBanner({required this.discord});

  final TeamEntryDiscord discord;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final missing = teamDiscordMissingLabel(t, discord.missing);
    return Container(
      key: const ValueKey('team-entry-discord'),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: luma.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.forum_rounded, size: 18, color: luma.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.teamClipboardFromDiscord(teamPerson(t, discord.author)),
                  style: TextStyle(color: luma.textSecondary),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openDiscord(discord.url),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(t.teamClipboardOpenInDiscord),
              ),
            ],
          ),
          if (missing != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: luma.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      missing,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (discord.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              t.teamClipboardDiscordOnly,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in discord.attachments)
                  ActionChip(
                    avatar: Icon(
                      Icons.attach_file_rounded,
                      size: 16,
                      color: luma.textSecondary,
                    ),
                    label: Text(a.name),
                    tooltip: t.teamClipboardOpenInDiscord,
                    onPressed: () => _openDiscord(a.url),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Idea → claimed → done → added as four steps, any of which can be
/// picked, plus the one obvious next step as a button.
class _StageTrack extends StatefulWidget {
  const _StageTrack({required this.entry});

  final TeamEntry entry;

  @override
  State<_StageTrack> createState() => _StageTrackState();
}

class _StageTrackState extends State<_StageTrack> {
  bool _busy = false;

  Future<void> _move(TeamEntryStage stage) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _attempt(
      context,
      () => TeamClipboardScope.read(context).setStage(widget.entry.id, stage),
    );
    if (mounted) setState(() => _busy = false);
  }

  bool _allowed(TeamEntryStage stage, bool lead) {
    final entry = widget.entry;
    if (entry.closed || stage == entry.stage) return false;
    if (stage == TeamEntryStage.added || entry.stage == TeamEntryStage.added) {
      return lead;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final controller = TeamClipboardScope.of(context);
    final lead = controller.isLead;
    final entry = widget.entry;
    final bug = entry.kind == TeamEntryKind.bug;

    final (String label, IconData icon, VoidCallback onTap)? next = entry.closed
        ? null
        : switch (entry.stage) {
            TeamEntryStage.idea => (
              t.teamClipboardClaim,
              Icons.pan_tool_alt_rounded,
              () => _move(TeamEntryStage.claimed),
            ),
            TeamEntryStage.claimed when entry.claimedByMe => (
              t.teamClipboardMarkDone,
              Icons.check_rounded,
              () => _move(TeamEntryStage.done),
            ),
            TeamEntryStage.done when lead => (
              bug ? t.teamClipboardMarkFixed : t.teamClipboardMarkAdded,
              Icons.verified_rounded,
              () => _move(TeamEntryStage.added),
            ),
            TeamEntryStage.added when entry.canClose => (
              t.teamClipboardCloseThread,
              Icons.lock_rounded,
              () =>
                  _attempt(context, () => controller.setClosed(entry.id, true)),
            ),
            _ => null,
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final stage in TeamEntryStage.values) ...[
              if (stage.index > 0) const SizedBox(width: 6),
              Expanded(
                child: _StageStep(
                  label: teamStageLabel(t, stage, entry.kind),
                  icon: teamStageIcon(stage),
                  color: teamStageColor(stage, luma),
                  current: stage == entry.stage,
                  passed: stage.index < entry.stage.index,
                  dim: entry.closed,
                  tooltip:
                      !entry.closed &&
                          !lead &&
                          stage == TeamEntryStage.added &&
                          stage != entry.stage
                      ? t.teamClipboardLeadOnlyAdded
                      : null,
                  onTap: _busy || !_allowed(stage, lead)
                      ? null
                      : () => _move(stage),
                ),
              ),
            ],
          ],
        ),
        if (entry.claimedBy != null || next != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (entry.claimedBy != null)
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: luma.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          t.teamClipboardClaimedBy(
                            entry.claimedByMe
                                ? t.teamClipboardYou
                                : teamPerson(t, entry.claimedBy!),
                          ),
                          style: TextStyle(
                            color: luma.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),
              if (entry.stage == TeamEntryStage.claimed &&
                  entry.claimedByMe &&
                  !entry.closed) ...[
                TextButton(
                  onPressed: _busy ? null : () => _move(TeamEntryStage.idea),
                  child: Text(t.teamClipboardUnclaim),
                ),
                const SizedBox(width: 6),
              ],
              if (next != null)
                LumaPrimaryButton(
                  label: next.$1,
                  icon: next.$2,
                  loading: _busy,
                  onTap: _busy ? null : next.$3,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StageStep extends StatelessWidget {
  const _StageStep({
    required this.label,
    required this.icon,
    required this.color,
    required this.current,
    required this.passed,
    required this.dim,
    required this.onTap,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool current;
  final bool passed;
  final bool dim;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final active = current || passed;
    final fg = dim
        ? luma.textMuted
        : current
        ? color
        : passed
        ? color.withValues(alpha: 0.75)
        : luma.textSecondary;
    final step = Semantics(
      button: onTap != null,
      selected: current,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: current && !dim
                  ? color.withValues(alpha: 0.16)
                  : luma.background,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                bottom: BorderSide(
                  color: active && !dim ? color : luma.border,
                  width: current ? 3 : 2,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(passed ? Icons.check_rounded : icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: current && !dim ? luma.textPrimary : fg,
                      fontSize: 13,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? step : Tooltip(message: tooltip, child: step);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label, this.trailing});

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: luma.textSecondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        ?trailing,
      ],
    );
  }
}

class _Brief extends StatelessWidget {
  const _Brief({required this.entry});

  final TeamEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(icon: Icons.notes_rounded, label: t.teamClipboardBrief),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: luma.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.border),
          ),
          child: entry.brief.isEmpty
              ? Text(
                  t.teamClipboardNoBrief,
                  style: TextStyle(
                    color: luma.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : SelectableText(
                  entry.brief,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14.5,
                    height: 1.55,
                  ),
                ),
        ),
      ],
    );
  }
}

/// "Part of <main thread>" above a sub-entry's header; tapping it opens the
/// main thread.
class _ParentLink extends StatelessWidget {
  const _ParentLink({required this.parentId});

  final String parentId;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final controller = TeamClipboardScope.of(context);
    final parent = controller.entryById(parentId);
    if (parent == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => controller.select(parent.id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_tree_rounded, size: 15, color: luma.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  t.teamClipboardPartOf(parent.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The smaller entries a main thread is broken into, each with its own
/// stage, and a button to add another.
class _SubEntries extends StatelessWidget {
  const _SubEntries({required this.entry});

  final TeamEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final controller = TeamClipboardScope.of(context);
    final children = controller.childrenOf(entry.id);
    final finished = children.where((e) => e.finished).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          icon: Icons.account_tree_rounded,
          label: t.teamClipboardSubEntries,
          trailing: entry.closed
              ? null
              : TextButton.icon(
                  onPressed: () => showTeamEntryEditor(
                    context,
                    controller,
                    parentId: entry.id,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(t.teamClipboardAddSubEntry),
                ),
        ),
        const SizedBox(height: 10),
        if (children.isEmpty)
          Text(
            t.teamClipboardNoSubEntries,
            style: TextStyle(color: luma.textMuted, fontSize: 13),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: finished / children.length,
                    minHeight: 6,
                    backgroundColor: luma.border,
                    color: luma.success,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                t.teamClipboardSubProgress(finished, children.length),
                style: TextStyle(color: luma.textMuted, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final child in children)
            TeamSubEntryRow(
              entry: child,
              news: controller.hasNews(child),
              onTap: () => controller.select(child.id),
            ),
        ],
      ],
    );
  }
}

/// One sub-entry as a compact row: its kind, title and stage.
class TeamSubEntryRow extends StatelessWidget {
  const TeamSubEntryRow({
    super.key,
    required this.entry,
    required this.onTap,
    this.news = false,
    this.selected = false,
  });

  final TeamEntry entry;
  final VoidCallback onTap;
  final bool news;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final finished = entry.finished;
    final base = finished ? teamFinishedSurface(context) : luma.background;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? Color.lerp(base, luma.accent, 0.12) : base,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? luma.accent.withValues(alpha: 0.7)
                    : finished
                    ? Colors.transparent
                    : luma.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  teamKindIcon(entry.kind),
                  size: 16,
                  color: finished
                      ? luma.textMuted
                      : teamKindColor(entry.kind, luma),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: finished ? luma.textSecondary : luma.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      decoration: entry.closed
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: luma.textMuted,
                    ),
                  ),
                ),
                if (news) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: luma.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                TeamPill(
                  label: entry.closed
                      ? t.teamClipboardClosed
                      : teamStageLabel(t, entry.stage, entry.kind),
                  color: entry.closed
                      ? luma.textMuted
                      : teamStageColor(entry.stage, luma),
                  icon: entry.closed
                      ? Icons.lock_rounded
                      : teamStageIcon(entry.stage),
                  filled: entry.stage == TeamEntryStage.added,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Files tab: the viewer on top when there's a texture or model to
/// show, every file below it, and the add / save-all actions.
class _Files extends StatefulWidget {
  const _Files({
    required this.entry,
    required this.viewing,
    required this.onView,
  });

  final TeamEntry entry;
  final String? viewing;
  final ValueChanged<String> onView;

  @override
  State<_Files> createState() => _FilesState();
}

class _FilesState extends State<_Files> {
  int _uploading = 0;

  Future<void> _add() async {
    final t = L.of(context);
    final controller = TeamClipboardScope.read(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final picked = await pickTeamFiles(t);
    if (picked == null || !mounted) return;
    if (picked.rejected.isNotEmpty) {
      messenger?.showSnackBar(
        SnackBar(content: Text(picked.rejected.join('\n'))),
      );
    }
    setState(() => _uploading += picked.files.length);
    final failed = <String>[];
    for (final file in picked.files) {
      try {
        await controller.upload(widget.entry.id, file);
      } on TeamClipboardApiException catch (e) {
        failed.add('${file.name} (${e.message})');
      } catch (_) {
        failed.add(file.name);
      }
      if (mounted) setState(() => _uploading--);
    }
    if (failed.isNotEmpty) {
      messenger?.showSnackBar(
        SnackBar(content: Text(t.teamClipboardUploadFailed(failed.join(', ')))),
      );
    }
  }

  Future<void> _saveAll() async {
    final t = L.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final result = await saveAllTeamFiles(
        TeamClipboardScope.read(context),
        widget.entry,
      );
      if (result != null) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(t.teamClipboardSavedFiles(result.$2, result.$1)),
          ),
        );
      }
    } catch (_) {
      messenger?.showSnackBar(
        SnackBar(content: Text(t.teamClipboardCouldNotLoad)),
      );
    }
  }

  Future<void> _remove(TeamFile file) async {
    final t = L.of(context);
    final luma = context.luma;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.teamClipboardRemoveFile),
        content: Text(t.teamClipboardRemoveFileConfirm(file.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: luma.danger),
            child: Text(t.commonDelete),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _attempt(
        context,
        () => TeamClipboardScope.read(
          context,
        ).removeFile(widget.entry.id, file.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final entry = widget.entry;
    final viewable = entry.files.where(teamViewable).toList();
    final shown = viewable.where((f) => f.id == widget.viewing).firstOrNull?.id;
    final actions = [
      if (entry.files.length > 1 && teamCanSaveAll)
        TextButton.icon(
          onPressed: _saveAll,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(t.teamClipboardDownloadAll),
        ),
      if (!entry.closed)
        TextButton.icon(
          onPressed: _uploading > 0 ? null : _add,
          icon: _uploading > 0
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.attach_file_rounded, size: 18),
          label: Text(t.teamClipboardAddFiles),
        ),
    ];

    final grid = entry.files.isEmpty
        ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: luma.border),
            ),
            child: Row(
              children: [
                Icon(Icons.upload_file_rounded, color: luma.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.teamClipboardNoFiles,
                    style: TextStyle(color: luma.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        : Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final file in entry.files)
                TeamFileTile(
                  key: ValueKey(file.id),
                  entry: entry,
                  file: file,
                  selected: viewable.length > 1 && file.id == shown,
                  onTap: teamViewable(file)
                      ? () => widget.onView(file.id)
                      : null,
                  onRemove: file.canRemove ? () => _remove(file) : null,
                ),
            ],
          );

    final toolbar = actions.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: actions,
            ),
          );

    return LayoutBuilder(
      builder: (context, box) {
        const pad = EdgeInsets.fromLTRB(22, 14, 22, 24);
        if (viewable.isEmpty) {
          return SingleChildScrollView(
            padding: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [?toolbar, grid],
            ),
          );
        }
        final viewer = TeamFileViewer(
          entry: entry,
          subjectId: shown,
          onSubject: widget.onView,
        );
        // With room to spare the viewer stays put and only the files
        // scroll, so a vertical drag on a touch screen turns the model
        // rather than the page.
        if (box.maxHeight >= 520) {
          return Padding(
            padding: pad.copyWith(bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: (box.maxHeight * 0.58).clamp(280.0, 520.0),
                  child: viewer,
                ),
                const SizedBox(height: 12),
                ?toolbar,
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: grid,
                  ),
                ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 240, child: viewer),
              const SizedBox(height: 12),
              ?toolbar,
              grid,
            ],
          ),
        );
      },
    );
  }
}

class _NoMessages extends StatelessWidget {
  const _NoMessages({required this.closed});

  final bool closed;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, color: luma.textMuted),
          const SizedBox(height: 8),
          Text(
            closed
                ? L.of(context).teamClipboardThreadClosed
                : L.of(context).teamClipboardNoMessages,
            textAlign: TextAlign.center,
            style: TextStyle(color: luma.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.showAuthor});

  final TeamMessage message;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final mine = message.mine;
    return Padding(
      padding: EdgeInsets.only(top: showAuthor ? 10 : 3),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showAuthor)
            Padding(
              padding: const EdgeInsets.only(bottom: 3, left: 4, right: 4),
              child: Text(
                [
                  mine ? t.teamClipboardMe : teamPerson(t, message.author),
                  if (message.fromDiscord) t.teamClipboardViaDiscord,
                  teamRelativeTime(context, message.createdAt),
                ].join(' · '),
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Tooltip(
              message: MaterialLocalizations.of(
                context,
              ).formatFullDate(message.createdAt),
              waitDuration: const Duration(milliseconds: 600),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: mine ? luma.accentSubtle : luma.background,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(mine ? 14 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 14),
                  ),
                  border: Border.all(
                    color: mine
                        ? luma.accent.withValues(alpha: 0.25)
                        : luma.border,
                  ),
                ),
                child: SelectableText(
                  message.text,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
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

/// Where a message is written. Enter sends, Shift+Enter starts a new line.
class TeamComposer extends StatefulWidget {
  const TeamComposer({super.key, required this.entry, this.onSent});

  final TeamEntry entry;
  final VoidCallback? onSent;

  @override
  State<TeamComposer> createState() => _TeamComposerState();
}

class _TeamComposerState extends State<TeamComposer> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;

  @override
  void didUpdateWidget(TeamComposer old) {
    super.didUpdateWidget(old);
    if (old.entry.id != widget.entry.id) _text.clear();
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await TeamClipboardScope.read(context).post(widget.entry.id, text);
      _text.clear();
      widget.onSent?.call();
    } on TeamClipboardApiException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _focus.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    if (widget.entry.closed) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(top: BorderSide(color: luma.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter &&
                      !HardwareKeyboard.instance.isShiftPressed) {
                    _send();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  enabled: !_sending,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: t.teamClipboardMessageHint,
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: t.teamClipboardSend,
              onPressed: _sending ? null : _send,
              style: IconButton.styleFrom(
                backgroundColor: luma.accent,
                foregroundColor: luma.onAccent,
                minimumSize: const Size(44, 44),
              ),
              icon: _sending
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: luma.onAccent,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
