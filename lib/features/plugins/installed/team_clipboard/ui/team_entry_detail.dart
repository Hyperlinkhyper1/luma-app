import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Everything about one entry on one screen: what it is, where it stands,
/// its brief, its files and — unless [withThread] is off because the
/// thread has a column of its own — its chat. With [onClose] the header
/// carries a close button that goes back to the board.
class TeamEntryDetail extends StatefulWidget {
  const TeamEntryDetail({
    super.key,
    required this.entry,
    this.withThread = true,
    this.onClose,
  });

  final TeamEntry entry;
  final bool withThread;
  final VoidCallback? onClose;

  @override
  State<TeamEntryDetail> createState() => _TeamEntryDetailState();
}

class _TeamEntryDetailState extends State<TeamEntryDetail> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(TeamEntryDetail old) {
    super.didUpdateWidget(old);
    if (old.entry.id != widget.entry.id && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// After the user posts, follow the thread down to their message.
  void _followThread() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(entry: entry, onClose: widget.onClose),
                const SizedBox(height: 18),
                if (entry.closed) ...[
                  _ClosedBanner(entry: entry),
                  const SizedBox(height: 14),
                ],
                _StageTrack(entry: entry),
                const SizedBox(height: 22),
                _Brief(entry: entry),
                const SizedBox(height: 24),
                _Files(entry: entry),
                if (widget.withThread) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(
                    icon: Icons.forum_rounded,
                    label: L.of(context).teamClipboardChat,
                    count: entry.messageCount,
                  ),
                  const SizedBox(height: 10),
                  TeamMessages(entry: entry),
                ],
              ],
            ),
          ),
        ),
        if (widget.withThread)
          TeamComposer(entry: entry, onSent: _followThread),
      ],
    );
  }
}

/// The chat on its own, for the third column of a wide window.
class TeamThreadPanel extends StatelessWidget {
  const TeamThreadPanel({super.key, required this.entry});

  final TeamEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final messages = entry.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: _SectionTitle(
            icon: Icons.forum_rounded,
            label: t.teamClipboardChat,
            count: entry.messageCount,
          ),
        ),
        Divider(height: 1, color: luma.border),
        Expanded(
          child: messages == null
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
              ? _NoMessages(closed: entry.closed)
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
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
  const _SectionTitle({
    required this.icon,
    required this.label,
    this.count,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Icon(icon, size: 18, color: luma.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 8),
          Text('$count', style: TextStyle(color: luma.textMuted, fontSize: 13)),
        ],
        const Spacer(),
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

class _Files extends StatefulWidget {
  const _Files({required this.entry});

  final TeamEntry entry;

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
    final narrow = context.isPhoneWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          icon: Icons.folder_rounded,
          label: t.teamClipboardFiles,
          count: entry.files.length,
          trailing: Wrap(
            spacing: 4,
            children: [
              if (entry.files.length > 1 && teamCanSaveAll)
                narrow
                    ? IconButton(
                        tooltip: t.teamClipboardDownloadAll,
                        onPressed: _saveAll,
                        icon: const Icon(Icons.download_rounded, size: 20),
                      )
                    : TextButton.icon(
                        onPressed: _saveAll,
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(t.teamClipboardDownloadAll),
                      ),
              if (!entry.closed)
                narrow
                    ? IconButton(
                        tooltip: t.teamClipboardAddFiles,
                        onPressed: _uploading > 0 ? null : _add,
                        icon: const Icon(Icons.attach_file_rounded, size: 20),
                      )
                    : TextButton.icon(
                        onPressed: _uploading > 0 ? null : _add,
                        icon: _uploading > 0
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.attach_file_rounded, size: 18),
                        label: Text(t.teamClipboardAddFiles),
                      ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (entry.files.isEmpty)
          Container(
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
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final file in entry.files)
                TeamFileTile(
                  key: ValueKey(file.id),
                  entry: entry,
                  file: file,
                  onRemove: file.canRemove ? () => _remove(file) : null,
                ),
            ],
          ),
      ],
    );
  }
}

/// The thread as a plain column, for when it sits under the files.
class TeamMessages extends StatelessWidget {
  const TeamMessages({super.key, required this.entry});

  final TeamEntry entry;

  @override
  Widget build(BuildContext context) {
    final messages = entry.messages;
    if (messages == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (messages.isEmpty) return _NoMessages(closed: entry.closed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < messages.length; i++)
          _Bubble(
            message: messages[i],
            showAuthor: i == 0 || messages[i - 1].author != messages[i].author,
          ),
      ],
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
                '${mine ? t.teamClipboardMe : teamPerson(t, message.author)}'
                ' · ${teamRelativeTime(context, message.createdAt)}',
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
