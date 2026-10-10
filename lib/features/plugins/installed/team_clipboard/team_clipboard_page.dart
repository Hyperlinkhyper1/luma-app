import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'team_clipboard_controller.dart';
import 'team_clipboard_models.dart';
import 'team_clipboard_scope.dart';
import 'ui/team_clipboard_style.dart';
import 'ui/team_entry_detail.dart';
import 'ui/team_entry_editor.dart';

/// The Team Clipboard: every bug, suggestion and model the team is working
/// on, on one screen. Work still to do sits on top; done, added and closed
/// entries sink to the bottom on a darker surface. On a wide window the
/// open entry and its chat sit beside the list; on a phone the entry opens
/// as a page of its own.
class TeamClipboardPage extends StatefulWidget {
  const TeamClipboardPage({super.key});

  @override
  State<TeamClipboardPage> createState() => _TeamClipboardPageState();
}

enum _KindFilter { all, bug, suggestion, model }

class _TeamClipboardPageState extends State<TeamClipboardPage> {
  TeamClipboardController? _controller;
  _KindFilter _filter = _KindFilter.all;
  String _query = '';
  bool _showFinished = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = TeamClipboardScope.read(context);
    if (!identical(controller, _controller)) {
      _controller?.detach();
      _controller = controller..attach();
    }
  }

  @override
  void dispose() {
    _controller?.detach();
    super.dispose();
  }

  bool _matches(TeamEntry e) {
    final kindOk = switch (_filter) {
      _KindFilter.all => true,
      _KindFilter.bug => e.kind == TeamEntryKind.bug,
      _KindFilter.suggestion => e.kind == TeamEntryKind.suggestion,
      _KindFilter.model => e.kind == TeamEntryKind.model,
    };
    if (!kindOk) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return e.title.toLowerCase().contains(q) ||
        e.brief.toLowerCase().contains(q) ||
        e.author.toLowerCase().contains(q) ||
        e.files.any((f) => f.name.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final controller = TeamClipboardScope.of(context);
    final t = L.of(context);
    if (controller.access == TeamAccess.unknown) {
      if (controller.error != null) {
        return LumaEmptyState(
          icon: Icons.cloud_off_rounded,
          title: t.teamClipboardErrorTitle,
          subtitle: controller.error,
          action: LumaPrimaryButton(
            label: t.commonRetry,
            icon: Icons.refresh_rounded,
            onTap: controller.refresh,
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.access == TeamAccess.outside) {
      return _AccessGate(controller: controller);
    }
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1240;
        final split = box.maxWidth >= 820;
        final list = _BoardList(
          controller: controller,
          filter: _filter,
          query: _query,
          showFinished: _showFinished,
          matches: _matches,
          onFilter: (f) => setState(() => _filter = f),
          onQuery: (q) => setState(() => _query = q),
          onToggleFinished: () =>
              setState(() => _showFinished = !_showFinished),
          onOpen: (entry) {
            controller.select(entry.id);
            if (!split) _openOnPhone(context, entry.id);
          },
          highlightSelection: split,
        );
        if (!split) return list;
        final luma = context.luma;
        final selected = controller.selected;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: wide ? 380 : 340, child: list),
            VerticalDivider(width: 1, color: luma.border),
            Expanded(
              child: selected == null
                  ? LumaEmptyState(
                      icon: Icons.touch_app_rounded,
                      title: t.teamClipboardSelectHint,
                    )
                  : TeamEntryDetail(
                      key: ValueKey(selected.id),
                      entry: selected,
                      withThread: !wide,
                    ),
            ),
            if (wide && selected != null) ...[
              VerticalDivider(width: 1, color: luma.border),
              SizedBox(
                width: 380,
                child: ColoredBox(
                  color: luma.surface,
                  child: TeamThreadPanel(entry: selected),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _openOnPhone(BuildContext context, String id) {
    final controller = TeamClipboardScope.read(context);
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (context) => _PhoneEntryPage(id: id),
          ),
        )
        .then((_) {
          if (controller.selectedId == id) controller.select(null);
        });
  }
}

class _PhoneEntryPage extends StatelessWidget {
  const _PhoneEntryPage({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final controller = TeamClipboardScope.of(context);
    final luma = context.luma;
    final entry = controller.selected;
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        surfaceTintColor: Colors.transparent,
        title: Text(L.of(context).pluginNameTeamClipboard),
      ),
      body: entry == null || entry.id != id
          ? const Center(child: CircularProgressIndicator())
          : TeamEntryDetail(entry: entry),
    );
  }
}

/// Shown to a signed-in account the admin hasn't added to the team yet.
class _AccessGate extends StatelessWidget {
  const _AccessGate({required this.controller});

  final TeamClipboardController controller;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final email = controller.outsideEmail;
    return LumaEmptyState(
      icon: Icons.group_add_rounded,
      title: t.teamClipboardGateTitle,
      subtitle: email == null || email.isEmpty
          ? t.teamClipboardGateBodyNoEmail
          : t.teamClipboardGateBody(email),
      action: LumaPrimaryButton(
        label: t.teamClipboardGateCheckAgain,
        icon: Icons.refresh_rounded,
        loading: controller.loading,
        onTap: controller.loading ? null : controller.refresh,
      ),
    );
  }
}

class _BoardList extends StatelessWidget {
  const _BoardList({
    required this.controller,
    required this.filter,
    required this.query,
    required this.showFinished,
    required this.matches,
    required this.onFilter,
    required this.onQuery,
    required this.onToggleFinished,
    required this.onOpen,
    required this.highlightSelection,
  });

  final TeamClipboardController controller;
  final _KindFilter filter;
  final String query;
  final bool showFinished;
  final bool Function(TeamEntry) matches;
  final ValueChanged<_KindFilter> onFilter;
  final ValueChanged<String> onQuery;
  final VoidCallback onToggleFinished;
  final ValueChanged<TeamEntry> onOpen;
  final bool highlightSelection;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final all = controller.entries;
    final shown = all.where(matches).toList();
    final todo = shown.where((e) => !e.finished).toList();
    final finished = shown.where((e) => e.finished).toList();
    final openCount = all.where((e) => !e.finished).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            t.pluginNameTeamClipboard,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TeamPill(
                          label: controller.isLead
                              ? t.teamClipboardRoleLead
                              : t.teamClipboardRoleMember,
                          color: controller.isLead
                              ? luma.accent
                              : luma.textSecondary,
                          icon: controller.isLead
                              ? Icons.star_rounded
                              : Icons.person_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.teamClipboardSubtitle(
                        openCount,
                        all.length - openCount,
                      ),
                      style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t.teamClipboardRefresh,
                onPressed: controller.loading ? null : controller.refresh,
                icon: controller.loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                color: luma.textSecondary,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: LumaPrimaryButton(
            label: t.teamClipboardNewEntry,
            icon: Icons.add_rounded,
            expand: true,
            onTap: () => showTeamEntryEditor(context, controller),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: _SearchField(query: query, onChanged: onQuery),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
            children: [
              for (final f in _KindFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterChip(
                    label: switch (f) {
                      _KindFilter.all => t.commonAll,
                      _KindFilter.bug => t.teamClipboardFilterBugs,
                      _KindFilter.suggestion =>
                        t.teamClipboardFilterSuggestions,
                      _KindFilter.model => t.teamClipboardFilterModels,
                    },
                    icon: switch (f) {
                      _KindFilter.all => null,
                      _KindFilter.bug => teamKindIcon(TeamEntryKind.bug),
                      _KindFilter.suggestion => teamKindIcon(
                        TeamEntryKind.suggestion,
                      ),
                      _KindFilter.model => teamKindIcon(TeamEntryKind.model),
                    },
                    selected: f == filter,
                    onTap: () => onFilter(f),
                  ),
                ),
            ],
          ),
        ),
        if (controller.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
            child: Text(
              controller.error!,
              style: TextStyle(color: luma.danger, fontSize: 12.5),
            ),
          ),
        Expanded(
          child: all.isEmpty
              ? LumaEmptyState(
                  icon: Icons.content_paste_rounded,
                  title: t.teamClipboardEmptyTitle,
                  subtitle: t.teamClipboardEmptySubtitle,
                )
              : shown.isEmpty
              ? LumaEmptyState(
                  icon: Icons.search_off_rounded,
                  title: t.commonNoResults,
                )
              : RefreshIndicator(
                  onRefresh: controller.refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    children: [
                      _SectionHeader(
                        label: t.teamClipboardSectionToDo,
                        count: todo.length,
                      ),
                      for (final e in todo)
                        _EntryCard(
                          key: ValueKey(e.id),
                          entry: e,
                          selected:
                              highlightSelection &&
                              e.id == controller.selectedId,
                          news: controller.hasNews(e),
                          onTap: () => onOpen(e),
                        ),
                      if (finished.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _SectionHeader(
                          label: t.teamClipboardSectionFinished,
                          count: finished.length,
                          expanded: showFinished,
                          onToggle: onToggleFinished,
                        ),
                        if (showFinished)
                          for (final e in finished)
                            _EntryCard(
                              key: ValueKey(e.id),
                              entry: e,
                              selected:
                                  highlightSelection &&
                                  e.id == controller.selectedId,
                              news: controller.hasNews(e),
                              onTap: () => onOpen(e),
                            ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.query, required this.onChanged});

  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _text = TextEditingController(text: widget.query);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return TextField(
      controller: _text,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: t.teamClipboardSearchHint,
        isDense: true,
        prefixIcon: Icon(Icons.search_rounded, color: luma.textMuted, size: 20),
        suffixIcon: widget.query.isEmpty
            ? null
            : IconButton(
                tooltip: t.commonClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _text.clear();
                  widget.onChanged('');
                },
              ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? luma.accent : luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? luma.accent : luma.textSecondary,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? luma.textPrimary : luma.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
    this.expanded = true,
    this.onToggle,
  });

  final String label;
  final int count;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(color: luma.textMuted, fontSize: 11.5),
          ),
          const Spacer(),
          if (onToggle != null)
            AnimatedRotation(
              turns: expanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: luma.textMuted,
              ),
            ),
        ],
      ),
    );
    if (onToggle == null) return row;
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: row,
      ),
    );
  }
}

/// One entry on the board. Finished entries sit on a darker surface with
/// muted text, so what still needs doing reads first.
class _EntryCard extends StatefulWidget {
  const _EntryCard({
    super.key,
    required this.entry,
    required this.selected,
    required this.news,
    required this.onTap,
  });

  final TeamEntry entry;
  final bool selected;
  final bool news;
  final VoidCallback onTap;

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final e = widget.entry;
    final finished = e.finished;
    final kindColor = finished ? luma.textMuted : teamKindColor(e.kind, luma);
    final stageColor = e.closed
        ? luma.textMuted
        : teamStageColor(e.stage, luma);
    final base = finished ? teamFinishedSurface(context) : luma.surface;
    final background = widget.selected
        ? Color.lerp(base, luma.accent, 0.12)!
        : _hover
        ? Color.lerp(base, luma.surfaceHover, 0.7)!
        : base;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: widget.selected,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.selected
                      ? luma.accent.withValues(alpha: 0.7)
                      : finished
                      ? Colors.transparent
                      : luma.border,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: kindColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      teamKindIcon(e.kind),
                      size: 19,
                      color: kindColor,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                e.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: finished
                                      ? luma.textSecondary
                                      : luma.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                  decoration: e.closed
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: luma.textMuted,
                                ),
                              ),
                            ),
                            if (widget.news)
                              Tooltip(
                                message: t.teamClipboardNews,
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    left: 6,
                                    top: 4,
                                  ),
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: luma.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TeamPill(
                              label: e.closed
                                  ? t.teamClipboardClosed
                                  : e.stage == TeamEntryStage.claimed &&
                                        e.claimedBy != null
                                  ? t.teamClipboardClaimedBy(
                                      e.claimedByMe
                                          ? t.teamClipboardYou
                                          : teamPerson(t, e.claimedBy!),
                                    )
                                  : teamStageLabel(t, e.stage, e.kind),
                              color: stageColor,
                              icon: e.closed
                                  ? Icons.lock_rounded
                                  : teamStageIcon(e.stage),
                              filled: e.stage == TeamEntryStage.added,
                            ),
                            if (e.files.isNotEmpty)
                              _Meta(
                                icon: Icons.attach_file_rounded,
                                text: '${e.files.length}',
                              ),
                            if (e.messageCount > 0)
                              _Meta(
                                icon: Icons.chat_bubble_outline_rounded,
                                text: '${e.messageCount}',
                              ),
                            _Meta(
                              text:
                                  '${teamPerson(t, e.author)} · ${teamRelativeTime(context, e.updatedAt)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: luma.textMuted),
          const SizedBox(width: 3),
        ],
        Text(text, style: TextStyle(color: luma.textMuted, fontSize: 12)),
      ],
    );
  }
}
