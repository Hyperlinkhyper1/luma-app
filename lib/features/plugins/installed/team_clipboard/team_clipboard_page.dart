import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'data/team_clipboard_api.dart';
import 'team_clipboard_controller.dart';
import 'team_clipboard_models.dart';
import 'team_clipboard_scope.dart';
import 'ui/team_clipboard_style.dart';
import 'ui/team_discord_page.dart';
import 'ui/team_entry_detail.dart';
import 'ui/team_entry_editor.dart';
import 'ui/team_library_page.dart';
import 'ui/team_settings_page.dart';
import 'ui/team_task_row.dart';

/// The Team Clipboard: every bug, suggestion and model the team is working
/// on, on one screen. Work still to do sits on top; done, added and closed
/// entries sink to the bottom. The full board uses aligned task rows;
/// opening an entry folds it into a side list beside the entry and its chat.
/// On a phone the entry opens as a page of its own.
class TeamClipboardPage extends StatefulWidget {
  const TeamClipboardPage({super.key});

  @override
  State<TeamClipboardPage> createState() => _TeamClipboardPageState();
}

enum _KindFilter { all, bug, suggestion, model }

enum _WorkspacePage { tasks, library, discordBot, settings }

class _TeamClipboardPageState extends State<TeamClipboardPage> {
  TeamClipboardController? _controller;
  _KindFilter _filter = _KindFilter.all;
  String _query = '';
  _WorkspacePage _page = _WorkspacePage.tasks;
  bool _showTodo = true;
  bool _showFinished = true;

  /// The open entry's tab, kept while moving between entries.
  TeamDetailTab _tab = TeamDetailTab.overview;

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
    // A lead who was made a member again loses the tab while on it.
    final page = _page == _WorkspacePage.settings && !controller.isLead
        ? _WorkspacePage.tasks
        : _page;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WorkspaceHeader(
          controller: controller,
          page: page,
          onPage: (page) => setState(() => _page = page),
        ),
        Expanded(
          child: page == _WorkspacePage.settings
              ? TeamSettingsPage(controller: controller)
              : page == _WorkspacePage.discordBot
              ? TeamDiscordPage(controller: controller)
              : page == _WorkspacePage.library
              ? TeamLibraryPage(controller: controller)
              : LayoutBuilder(
                  builder: (context, box) {
                    final split = box.maxWidth >= 820;
                    final selected = controller.selected;
                    final open = split && selected != null;
                    final list = _BoardList(
                      controller: controller,
                      filter: _filter,
                      query: _query,
                      showTodo: _showTodo,
                      showFinished: _showFinished,
                      matches: _matches,
                      onFilter: (f) => setState(() => _filter = f),
                      onQuery: (q) => setState(() => _query = q),
                      onToggleFinished: () =>
                          setState(() => _showFinished = !_showFinished),
                      onToggleTodo: () =>
                          setState(() => _showTodo = !_showTodo),
                      onOpen: (entry) {
                        controller.select(entry.id);
                        if (!split) _openOnPhone(context, entry.id);
                      },
                      highlightSelection: split,
                      compact: open,
                    );
                    if (!open) return list;
                    final luma = context.luma;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: box.maxWidth >= 1240 ? 340 : 300,
                          child: list,
                        ),
                        VerticalDivider(width: 1, color: luma.border),
                        Expanded(
                          child: TeamEntryDetail(
                            key: ValueKey(selected.id),
                            entry: selected,
                            tab: _tab,
                            onTab: (tab) => setState(() => _tab = tab),
                            onClose: () => controller.select(null),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
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
        .then((_) => controller.select(null));
  }
}

/// An entry opened on a phone. Moving between a main thread and its
/// sub-entries swaps what this page shows rather than stacking pages.
class _PhoneEntryPage extends StatelessWidget {
  const _PhoneEntryPage({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final controller = TeamClipboardScope.of(context);
    final luma = context.luma;
    final entry = controller.selected;
    final id = controller.selectedId ?? this.id;
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        surfaceTintColor: Colors.transparent,
        title: Text(L.of(context).pluginNameTeamClipboard),
      ),
      body: entry == null || entry.id != id
          ? const Center(child: CircularProgressIndicator())
          : TeamEntryDetail(key: ValueKey(entry.id), entry: entry),
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

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.controller,
    required this.page,
    required this.onPage,
  });

  final TeamClipboardController controller;
  final _WorkspacePage page;
  final ValueChanged<_WorkspacePage> onPage;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final openCount = controller.entries.where((e) => !e.finished).length;
    final identity = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TeamPill(
          label: controller.isLead
              ? t.teamClipboardRoleLead
              : t.teamClipboardRoleMember,
          color: controller.isLead ? luma.accent : luma.textSecondary,
          icon: controller.isLead ? Icons.star_rounded : Icons.person_rounded,
        ),
        for (final tag in controller.myTags.take(2)) ...[
          const SizedBox(width: 6),
          Flexible(
            child: TeamTagChip(name: tag.name, color: tag.color),
          ),
        ],
        const SizedBox(width: 8),
        Flexible(child: _NameChip(controller: controller)),
      ],
    );
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.pluginNameTeamClipboard,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.teamClipboardSubtitle(
            openCount,
            controller.entries.length - openCount,
          ),
          style: TextStyle(color: luma.textMuted, fontSize: 12.5),
        ),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: LayoutBuilder(
              builder: (context, box) => box.maxWidth >= 600
                  ? Row(
                      children: [
                        Expanded(child: heading),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: box.maxWidth * 0.42,
                          ),
                          child: identity,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [heading, const SizedBox(height: 10), identity],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 4,
              children: [
                _WorkspaceTab(
                  key: const ValueKey('team-clipboard-tasks-tab'),
                  label: t.teamClipboardTasks,
                  icon: Icons.checklist_rounded,
                  selected: page == _WorkspacePage.tasks,
                  onTap: () => onPage(_WorkspacePage.tasks),
                ),
                _WorkspaceTab(
                  key: const ValueKey('team-clipboard-library-tab'),
                  label: t.teamClipboardLibrary,
                  icon: Icons.inventory_2_outlined,
                  selected: page == _WorkspacePage.library,
                  onTap: () => onPage(_WorkspacePage.library),
                ),
                _WorkspaceTab(
                  key: const ValueKey('team-clipboard-discord-tab'),
                  label: t.teamClipboardDiscordBot,
                  icon: Icons.smart_toy_outlined,
                  selected: page == _WorkspacePage.discordBot,
                  onTap: () => onPage(_WorkspacePage.discordBot),
                ),
                if (controller.isLead)
                  _WorkspaceTab(
                    key: const ValueKey('team-clipboard-settings-tab'),
                    label: t.teamClipboardSettings,
                    icon: Icons.tune_rounded,
                    selected: page == _WorkspacePage.settings,
                    onTap: () => onPage(_WorkspacePage.settings),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceTab extends StatelessWidget {
  const _WorkspaceTab({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      selected: selected,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? luma.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: selected ? luma.accent : luma.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: Icon(icon, size: 17),
          label: Text(label),
        ),
      ),
    );
  }
}

class _BoardList extends StatelessWidget {
  const _BoardList({
    required this.controller,
    required this.filter,
    required this.query,
    required this.showTodo,
    required this.showFinished,
    required this.matches,
    required this.onFilter,
    required this.onQuery,
    required this.onToggleTodo,
    required this.onToggleFinished,
    required this.onOpen,
    required this.highlightSelection,
    this.compact = false,
  });

  final TeamClipboardController controller;
  final _KindFilter filter;
  final String query;
  final bool showTodo;
  final bool showFinished;
  final bool Function(TeamEntry) matches;
  final ValueChanged<_KindFilter> onFilter;
  final ValueChanged<String> onQuery;
  final VoidCallback onToggleTodo;
  final VoidCallback onToggleFinished;
  final ValueChanged<TeamEntry> onOpen;
  final bool highlightSelection;
  final bool compact;

  Widget _rows(
    BuildContext context,
    List<TeamEntry> roots,
    List<TeamEntry> shown,
    bool table,
  ) {
    final shownChildren = <String, List<TeamEntry>>{};
    for (final entry in shown) {
      if (entry.parentId case final parent?) {
        (shownChildren[parent] ??= []).add(entry);
      }
    }
    Widget row(TeamEntry entry, {bool child = false}) {
      final children = controller.childrenOf(entry.id);
      return TeamTaskRow(
        key: ValueKey(entry.id),
        entry: entry,
        table: table,
        child: child,
        compact: compact,
        selected: highlightSelection && entry.id == controller.selectedId,
        news: controller.hasNews(entry),
        subTotal: children.length,
        subDone: children.where((e) => e.finished).length,
        onTap: () => onOpen(entry),
        onAddSubEntry: controller.canHoldChildren(entry) && !entry.closed
            ? () => showTeamEntryEditor(context, controller, parentId: entry.id)
            : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final root in roots) ...[
          row(root),
          for (final child in shownChildren[root.id] ?? <TeamEntry>[])
            row(child, child: true),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final all = controller.entries;
    final shown = all.where(matches).toList();
    final shownIds = {for (final e in shown) e.id};
    final roots = shown
        .where((e) => e.parentId == null || !shownIds.contains(e.parentId))
        .toList();
    final todo = roots.where((e) => !e.finished).toList();
    final finished = roots.where((e) => e.finished).toList();
    return LayoutBuilder(
      builder: (context, box) {
        final table = box.maxWidth >= 760;
        final side = compact ? 14.0 : 24.0;
        final search = _SearchField(query: query, onChanged: onQuery);
        final refresh = IconButton(
          tooltip: t.teamClipboardRefresh,
          onPressed: controller.loading ? null : controller.refresh,
          icon: controller.loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 20),
          color: luma.textSecondary,
        );
        final add = FilledButton.icon(
          onPressed: () => showTeamEntryEditor(context, controller),
          style: FilledButton.styleFrom(
            backgroundColor: luma.accent,
            foregroundColor: luma.onAccent,
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(t.teamClipboardNewEntry),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(side, 16, side - 8, 0),
              child: box.maxWidth >= 580
                  ? Row(
                      children: [
                        add,
                        const SizedBox(width: 14),
                        SizedBox(width: 280, child: search),
                        const Spacer(),
                        refresh,
                      ],
                    )
                  : Column(
                      children: [
                        Row(children: [add, const Spacer(), refresh]),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: search,
                        ),
                      ],
                    ),
            ),
            SizedBox(
              height: 49,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(side, 10, side, 5),
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
                          _KindFilter.model => teamKindIcon(
                            TeamEntryKind.model,
                          ),
                        },
                        selected: f == filter,
                        iconOnly: compact,
                        onTap: () => onFilter(f),
                      ),
                    ),
                ],
              ),
            ),
            if (controller.error != null)
              Padding(
                padding: EdgeInsets.fromLTRB(side, 6, side, 8),
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
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(side, 8, side, 24),
                        children: [
                          _SectionHeader(
                            label: t.teamClipboardSectionToDo,
                            count: todo.length,
                            expanded: showTodo,
                            onToggle: onToggleTodo,
                            color: luma.accent,
                          ),
                          if (showTodo && todo.isNotEmpty) ...[
                            if (table) const TeamTaskHeader(),
                            _rows(context, todo, shown, table),
                          ],
                          if (finished.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _SectionHeader(
                              label: t.teamClipboardSectionFinished,
                              count: finished.length,
                              expanded: showFinished,
                              onToggle: onToggleFinished,
                              color: luma.success,
                            ),
                            if (showFinished) ...[
                              if (table) const TeamTaskHeader(),
                              _rows(context, finished, shown, table),
                            ],
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// The name this account goes by on the board; tapping it opens a dialog
/// to change it.
class _NameChip extends StatelessWidget {
  const _NameChip({required this.controller});

  final TeamClipboardController controller;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final me = controller.me ?? '';
    return Tooltip(
      message: t.teamClipboardChangeName,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => _RenameDialog(controller: controller),
        ),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  me,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_rounded, size: 13, color: luma.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.controller});

  final TeamClipboardController controller;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.controller.me);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await widget.controller.rename(_name.text.trim());
      navigator.pop();
    } on TeamClipboardApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return AlertDialog(
      title: Text(t.teamClipboardChangeName),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.teamClipboardChangeNameBody,
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              maxLength: 32,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: t.teamClipboardNameHint,
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        LumaGhostButton(
          label: t.commonCancel,
          onTap: _saving ? null : () => Navigator.of(context).pop(),
        ),
        LumaPrimaryButton(
          label: t.commonSave,
          icon: Icons.check_rounded,
          loading: _saving,
          onTap: _saving ? null : _save,
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
    this.iconOnly = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  /// Shows just the icon, with the label as a tooltip, so every chip fits
  /// in the narrow list beside an open entry.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final bare = iconOnly && icon != null;
    final chip = Semantics(
      selected: selected,
      button: true,
      label: bare ? label : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: bare ? 10 : 12,
            vertical: 6,
          ),
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
                if (!bare) const SizedBox(width: 5),
              ],
              if (!bare)
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
    return bare ? Tooltip(message: label, child: chip) : chip;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
    this.expanded = true,
    this.onToggle,
  });

  final String label;
  final int count;
  final Color color;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        children: [
          Icon(
            expanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
            size: 18,
            color: luma.textMuted,
          ),
          const SizedBox(width: 7),
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
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
