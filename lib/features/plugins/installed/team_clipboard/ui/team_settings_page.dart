import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/team_clipboard_api.dart';
import '../team_clipboard_controller.dart';
import '../team_clipboard_models.dart';
import '../team_settings_models.dart';
import 'team_clipboard_style.dart';

/// The lead-only Settings tab: what each member may do beyond the basics,
/// given to them directly or through a tag everyone wearing it shares.
/// Every change is saved on the spot; the server is the only copy.
class TeamSettingsPage extends StatefulWidget {
  const TeamSettingsPage({super.key, required this.controller});

  final TeamClipboardController controller;

  @override
  State<TeamSettingsPage> createState() => _TeamSettingsPageState();
}

class _TeamSettingsPageState extends State<TeamSettingsPage> {
  TeamSettings? _settings;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await widget.controller.settings(
        (api) => api.settings(),
      );
      if (mounted) setState(() => _settings = settings);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _message(Object e) =>
      e is TeamClipboardApiException ? e.message : '$e';

  /// Runs [call] and takes the settings it answers with. Returns why it
  /// failed, or null when it worked.
  Future<String?> _save(
    Future<TeamSettings> Function(TeamClipboardApi api) call,
  ) async {
    try {
      final settings = await widget.controller.settings(call);
      if (mounted) setState(() => _settings = settings);
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  Future<String?> _saveMember(
    TeamMemberAccess member,
    Set<TeamPermission> permissions,
    List<String> tags,
  ) => _save(
    (api) => api.saveSettings(
      members: [(id: member.id, permissions: permissions, tags: tags)],
    ),
  );

  /// Saves [edited] in place of [original] (or as a new tag), then puts it
  /// on exactly the members in [wearers].
  Future<String?> _saveTag(
    TeamTag? original,
    TeamTag edited,
    Set<String> wearers,
  ) => _save((api) async {
    final current = _settings!;
    final tags = original == null
        ? [...current.tags, edited]
        : [for (final t in current.tags) t.id == original.id ? edited : t];
    var next = await api.saveSettings(tags: tags);
    final id =
        original?.id ??
        next.tags
            .firstWhere(
              (t) => t.name.toLowerCase() == edited.name.toLowerCase(),
            )
            .id!;
    final changes = [
      for (final m in next.members)
        if (!m.lead && m.tags.contains(id) != wearers.contains(m.id))
          (
            id: m.id,
            permissions: null,
            tags: wearers.contains(m.id)
                ? [...m.tags, id]
                : [
                    for (final t in m.tags)
                      if (t != id) t,
                  ],
          ),
    ];
    if (changes.isNotEmpty) next = await api.saveSettings(members: changes);
    return next;
  });

  Future<String?> _deleteTag(TeamTag tag) => _save(
    (api) => api.saveSettings(
      tags: [
        for (final t in _settings!.tags)
          if (t.id != tag.id) t,
      ],
    ),
  );

  /// Saves [edited] in place of [original], or as a new entry tag.
  Future<String?> _saveEntryTag(TeamEntryTag? original, TeamEntryTag edited) =>
      _save(
        (api) => api.saveSettings(
          entryTags: original == null
              ? [..._settings!.entryTags, edited]
              : [
                  for (final t in _settings!.entryTags)
                    t.id == original.id ? edited : t,
                ],
        ),
      );

  Future<String?> _deleteEntryTag(TeamEntryTag tag) => _save(
    (api) => api.saveSettings(
      entryTags: [
        for (final t in _settings!.entryTags)
          if (t.id != tag.id) t,
      ],
    ),
  );

  Future<void> _editEntryTag([TeamEntryTag? tag]) => showDialog<void>(
    context: context,
    builder: (context) => _EntryTagDialog(
      tag: tag,
      count: _settings!.entryTags.length,
      onSave: (edited) => _saveEntryTag(tag, edited),
      onDelete: tag == null ? null : () => _deleteEntryTag(tag),
    ),
  );

  Future<void> _editMember(TeamMemberAccess member) => showDialog<void>(
    context: context,
    builder: (context) => _MemberDialog(
      member: member,
      tags: _settings!.tags,
      onSave: (permissions, tags) => _saveMember(member, permissions, tags),
    ),
  );

  Future<void> _editTag([TeamTag? tag]) => showDialog<void>(
    context: context,
    builder: (context) => _TagDialog(
      tag: tag,
      settings: _settings!,
      onSave: (edited, wearers) => _saveTag(tag, edited, wearers),
      onDelete: tag == null ? null : () => _deleteTag(tag),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final settings = _settings;
    if (settings == null) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return LumaEmptyState(
        icon: Icons.cloud_off_rounded,
        title: t.teamClipboardErrorTitle,
        subtitle: _error,
        action: LumaPrimaryButton(
          label: t.commonRetry,
          icon: Icons.refresh_rounded,
          onTap: _load,
        ),
      );
    }
    final members = _MembersCard(settings: settings, onEdit: _editMember);
    final tags = _TagsCard(
      settings: settings,
      onNew: () => _editTag(),
      onEdit: _editTag,
    );
    final entryTags = _EntryTagsCard(
      tags: settings.entryTags,
      entries: widget.controller.entries,
      onNew: () => _editEntryTag(),
      onEdit: _editEntryTag,
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 980;
          final side = box.maxWidth >= 600 ? 24.0 : 14.0;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(side, 20, side, 32),
            children: [
              Text(
                t.teamSettingsTitle,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t.teamSettingsSubtitle,
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: members),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [tags, const SizedBox(height: 16), entryTags],
                      ),
                    ),
                  ],
                )
              else ...[
                members,
                const SizedBox(height: 16),
                tags,
                const SizedBox(height: 16),
                entryTags,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    this.count,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Icon(icon, size: 18, color: luma.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.settings, required this.onEdit});

  final TeamSettings settings;
  final ValueChanged<TeamMemberAccess> onEdit;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return LumaCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: Icons.group_rounded,
            title: t.teamSettingsMembers,
            count: settings.members.length,
          ),
          const SizedBox(height: 8),
          if (settings.members.every((m) => m.lead))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                t.teamSettingsNoMembers,
                style: TextStyle(color: luma.textMuted, fontSize: 12.5),
              ),
            ),
          for (final (i, member) in settings.members.indexed) ...[
            if (i > 0) Divider(height: 1, color: luma.border),
            _MemberRow(
              key: ValueKey('team-settings-member-${member.id}'),
              member: member,
              tags: [for (final id in member.tags) ?settings.tag(id)],
              onTap: member.lead ? null : () => onEdit(member),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.member,
    required this.tags,
    required this.onTap,
  });

  final TeamMemberAccess member;
  final List<TeamTag> tags;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final name = member.name.isEmpty ? member.email : member.name;
    final summary = member.lead
        ? TeamPill(
            label: t.teamSettingsLeadEverything,
            color: luma.accent,
            icon: Icons.star_rounded,
          )
        : Text(
            t.teamSettingsPermissionCount(
              member.effective.length,
              TeamPermission.values.length,
            ),
            style: TextStyle(
              color: member.effective.isEmpty
                  ? luma.textMuted
                  : luma.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: LayoutBuilder(
          builder: (context, box) {
            final narrow = box.maxWidth < 420;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (member.email.isNotEmpty && member.email != name)
                  Text(
                    member.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                if (tags.isNotEmpty || narrow) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final tag in tags)
                        TeamTagChip(name: tag.name, color: tag.color),
                      if (narrow) summary,
                    ],
                  ),
                ],
              ],
            );
            return Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: luma.accentSubtle,
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: luma.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: details),
                if (!narrow) ...[const SizedBox(width: 10), summary],
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: luma.textMuted,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TagsCard extends StatelessWidget {
  const _TagsCard({
    required this.settings,
    required this.onNew,
    required this.onEdit,
  });

  final TeamSettings settings;
  final VoidCallback onNew;
  final ValueChanged<TeamTag> onEdit;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return LumaCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: Icons.sell_outlined,
            title: t.teamSettingsTags,
            count: settings.tags.length,
            trailing: TextButton.icon(
              key: const ValueKey('team-settings-new-tag'),
              onPressed: onNew,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(t.teamSettingsNewTag),
            ),
          ),
          const SizedBox(height: 4),
          if (settings.tags.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 4, 12),
              child: Text(
                t.teamSettingsNoTags,
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          for (final (i, tag) in settings.tags.indexed) ...[
            if (i > 0) Divider(height: 1, color: luma.border),
            InkWell(
              key: ValueKey('team-settings-tag-${tag.id}'),
              onTap: () => onEdit(tag),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: TeamTagChip(name: tag.name, color: tag.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${t.teamSettingsTagMembers(settings.wearing(tag.id!))}'
                        ' · '
                        '${t.teamSettingsTagPermissionCount(tag.permissions.length)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: luma.textMuted, fontSize: 12),
                      ),
                    ),
                    Icon(Icons.edit_rounded, size: 16, color: luma.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The tags entries can carry. Anyone picks them when making an entry and
/// filters the board by them; only a lead makes them here.
class _EntryTagsCard extends StatelessWidget {
  const _EntryTagsCard({
    required this.tags,
    required this.entries,
    required this.onNew,
    required this.onEdit,
  });

  final List<TeamEntryTag> tags;
  final List<TeamEntry> entries;
  final VoidCallback onNew;
  final ValueChanged<TeamEntryTag> onEdit;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return LumaCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: Icons.label_outline_rounded,
            title: t.teamSettingsEntryTags,
            count: tags.length,
            trailing: TextButton.icon(
              key: const ValueKey('team-settings-new-entry-tag'),
              onPressed: onNew,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(t.teamSettingsNewTag),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 4, 6),
            child: Text(
              t.teamSettingsEntryTagsHint,
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          for (final (i, tag) in tags.indexed) ...[
            if (i > 0) Divider(height: 1, color: luma.border),
            InkWell(
              key: ValueKey('team-settings-entry-tag-${tag.id}'),
              onTap: () => onEdit(tag),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: TeamTagChip(name: tag.name, color: tag.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.teamSettingsEntryTagCount(
                          entries.where((e) => e.tags.contains(tag.id)).length,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: luma.textMuted, fontSize: 12),
                      ),
                    ),
                    Icon(Icons.edit_rounded, size: 16, color: luma.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every permission, grouped by the part of the clipboard it is about,
/// as a list of checkboxes. A permission in [inherited] comes from a tag:
/// it shows ticked, says which tag gives it, and can't be unticked here.
class _PermissionList extends StatelessWidget {
  const _PermissionList({
    required this.selected,
    required this.onChanged,
    this.inherited = const {},
    this.enabled = true,
  });

  final Set<TeamPermission> selected;
  final Map<TeamPermission, String> inherited;
  final ValueChanged<Set<TeamPermission>> onChanged;
  final bool enabled;

  static (String, String) _text(L t, TeamPermission p) => switch (p) {
    TeamPermission.markAdded => (t.teamPermMarkAdded, t.teamPermMarkAddedBody),
    TeamPermission.editAny => (t.teamPermEditAny, t.teamPermEditAnyBody),
    TeamPermission.closeAny => (t.teamPermCloseAny, t.teamPermCloseAnyBody),
    TeamPermission.removeAny => (t.teamPermRemoveAny, t.teamPermRemoveAnyBody),
    TeamPermission.library => (t.teamPermLibrary, t.teamPermLibraryBody),
    TeamPermission.botSettings => (
      t.teamPermBotSettings,
      t.teamPermBotSettingsBody,
    ),
    TeamPermission.botToken => (t.teamPermBotToken, t.teamPermBotTokenBody),
  };

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final groups = [
      (
        t.teamSettingsGroupBoard,
        Icons.checklist_rounded,
        [
          TeamPermission.markAdded,
          TeamPermission.editAny,
          TeamPermission.closeAny,
          TeamPermission.removeAny,
        ],
      ),
      (
        t.teamSettingsGroupLibrary,
        Icons.inventory_2_outlined,
        [TeamPermission.library],
      ),
      (
        t.teamSettingsGroupBot,
        Icons.smart_toy_outlined,
        [TeamPermission.botSettings, TeamPermission.botToken],
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, icon, permissions) in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
            child: Row(
              children: [
                Icon(icon, size: 14, color: luma.textMuted),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: luma.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          for (final p in permissions)
            Builder(
              builder: (context) {
                final (title, body) = _text(t, p);
                final from = inherited[p];
                final on = selected.contains(p) || from != null;
                final canToggle = enabled && from == null;
                return InkWell(
                  key: ValueKey('team-settings-perm-${p.name}'),
                  onTap: canToggle
                      ? () => onChanged(
                          on ? ({...selected}..remove(p)) : {...selected, p},
                        )
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: on,
                          onChanged: canToggle
                              ? (v) => onChanged(
                                  v == true
                                      ? {...selected, p}
                                      : ({...selected}..remove(p)),
                                )
                              : null,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 9, bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: luma.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  from == null
                                      ? body
                                      : '$body ${t.teamSettingsFromTag(from)}',
                                  style: TextStyle(
                                    color: luma.textMuted,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hint != null)
            Text(hint!, style: TextStyle(color: luma.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

/// A tag the member can be given or have taken off, as a toggle chip.
class _TagToggle extends StatelessWidget {
  const _TagToggle({
    super.key,
    required this.tag,
    required this.on,
    required this.onTap,
  });

  final TeamTag tag;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final c = teamTagColor(tag.color, luma);
    return Semantics(
      selected: on,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: on ? c.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? c : luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.check_rounded : Icons.add_rounded,
                size: 14,
                color: on ? c : luma.textMuted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  tag.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: on ? c : luma.textSecondary,
                    fontSize: 12.5,
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

class _MemberDialog extends StatefulWidget {
  const _MemberDialog({
    required this.member,
    required this.tags,
    required this.onSave,
  });

  final TeamMemberAccess member;
  final List<TeamTag> tags;
  final Future<String?> Function(
    Set<TeamPermission> permissions,
    List<String> tags,
  )
  onSave;

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  late Set<TeamPermission> _permissions = {...widget.member.permissions};
  late final Set<String> _tags = {...widget.member.tags};
  bool _saving = false;
  String? _error;

  /// What the picked tags give, with the first tag giving each.
  Map<TeamPermission, String> get _inherited => {
    for (final tag in widget.tags.reversed)
      if (_tags.contains(tag.id))
        for (final p in tag.permissions) p: tag.name,
  };

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final inherited = _inherited;
    final error = await widget.onSave(
      {
        for (final p in _permissions)
          if (!inherited.containsKey(p)) p,
      },
      [
        for (final tag in widget.tags)
          if (_tags.contains(tag.id)) tag.id!,
      ],
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final member = widget.member;
    return AlertDialog(
      title: Text(
        t.teamSettingsEditMember(
          member.name.isEmpty ? member.email : member.name,
        ),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (member.email.isNotEmpty)
                Text(
                  member.email,
                  style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                ),
              _SectionLabel(
                t.teamSettingsTags,
                hint: widget.tags.isEmpty
                    ? t.teamSettingsNoTags
                    : t.teamSettingsMemberTagsHint,
              ),
              if (widget.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in widget.tags)
                      _TagToggle(
                        key: ValueKey('team-settings-wear-${tag.id}'),
                        tag: tag,
                        on: _tags.contains(tag.id),
                        onTap: _saving
                            ? null
                            : () => setState(() {
                                if (!_tags.remove(tag.id)) _tags.add(tag.id!);
                              }),
                      ),
                  ],
                ),
              _SectionLabel(t.teamSettingsOwnPermissions),
              _PermissionList(
                selected: _permissions,
                inherited: _inherited,
                enabled: !_saving,
                onChanged: (next) => setState(() => _permissions = next),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: luma.danger, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        LumaGhostButton(
          label: t.commonCancel,
          onTap: _saving ? null : () => Navigator.of(context).pop(),
        ),
        LumaPrimaryButton(
          key: const ValueKey('team-settings-save'),
          label: t.commonSave,
          icon: Icons.check_rounded,
          loading: _saving,
          onTap: _saving ? null : _save,
        ),
      ],
    );
  }
}

class _TagDialog extends StatefulWidget {
  const _TagDialog({
    required this.tag,
    required this.settings,
    required this.onSave,
    this.onDelete,
  });

  /// Null for a new tag.
  final TeamTag? tag;
  final TeamSettings settings;
  final Future<String?> Function(TeamTag tag, Set<String> wearers) onSave;
  final Future<String?> Function()? onDelete;

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  late final _name = TextEditingController(text: widget.tag?.name ?? '');
  late int _color =
      widget.tag?.color ?? widget.settings.tags.length % _paletteSize;
  late Set<TeamPermission> _permissions = {...?widget.tag?.permissions};
  late final Set<String> _wearers = {
    for (final m in widget.settings.members)
      if (widget.tag != null && m.tags.contains(widget.tag!.id)) m.id,
  };
  bool _saving = false;
  String? _error;

  static const _paletteSize = 8;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await _run(
      () => widget.onSave(
        TeamTag(
          id: widget.tag?.id,
          name: name,
          color: _color,
          permissions: _permissions,
        ),
        _wearers,
      ),
    );
  }

  L get t => L.of(context);

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.teamSettingsDeleteTag),
        content: Text(t.teamSettingsDeleteTagConfirm(widget.tag!.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              t.commonDelete,
              style: TextStyle(color: context.luma.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await _run(widget.onDelete!);
  }

  Future<void> _run(Future<String?> Function() call) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await call();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final palette = teamTagPalette(luma);
    final members = widget.settings.members.where((m) => !m.lead).toList();
    return AlertDialog(
      title: Text(
        widget.tag == null ? t.teamSettingsNewTag : t.teamSettingsEditTag,
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('team-settings-tag-name'),
                controller: _name,
                autofocus: widget.tag == null,
                enabled: !_saving,
                maxLength: 24,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t.teamSettingsTagName,
                  hintText: t.teamSettingsTagNameHint,
                ),
              ),
              _SectionLabel(t.teamSettingsTagColor),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _paletteSize; i++)
                    Semantics(
                      selected: i == _color,
                      button: true,
                      child: InkWell(
                        onTap: _saving
                            ? null
                            : () => setState(() => _color = i),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: palette[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == _color
                                  ? luma.textPrimary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: i == _color
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: luma.onAccent,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              if (_name.text.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TeamTagChip(name: _name.text.trim(), color: _color),
                ),
              ],
              _SectionLabel(t.teamSettingsTagPermissions),
              _PermissionList(
                selected: _permissions,
                enabled: !_saving,
                onChanged: (next) => setState(() => _permissions = next),
              ),
              _SectionLabel(t.teamSettingsTagWearers),
              if (members.isEmpty)
                Text(
                  t.teamSettingsNoMembers,
                  style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                ),
              for (final m in members)
                CheckboxListTile(
                  key: ValueKey('team-settings-wearer-${m.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _wearers.contains(m.id),
                  onChanged: _saving
                      ? null
                      : (v) => setState(() {
                          if (v == true) {
                            _wearers.add(m.id);
                          } else {
                            _wearers.remove(m.id);
                          }
                        }),
                  title: Text(
                    m.name.isEmpty ? m.email : m.name,
                    style: TextStyle(color: luma.textPrimary, fontSize: 13.5),
                  ),
                  subtitle: m.email.isEmpty || m.email == m.name
                      ? null
                      : Text(
                          m.email,
                          style: TextStyle(color: luma.textMuted, fontSize: 12),
                        ),
                ),
              if (widget.onDelete != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('team-settings-delete-tag'),
                    onPressed: _saving ? null : _delete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: luma.danger,
                    ),
                    label: Text(
                      t.teamSettingsDeleteTag,
                      style: TextStyle(color: luma.danger),
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: luma.danger, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        LumaGhostButton(
          label: t.commonCancel,
          onTap: _saving ? null : () => Navigator.of(context).pop(),
        ),
        LumaPrimaryButton(
          key: const ValueKey('team-settings-save'),
          label: t.commonSave,
          icon: Icons.check_rounded,
          loading: _saving,
          onTap: _saving || _name.text.trim().isEmpty ? null : _save,
        ),
      ],
    );
  }
}

/// Makes or edits an entry tag: just a name and a colour, since entry tags
/// carry no permissions.
class _EntryTagDialog extends StatefulWidget {
  const _EntryTagDialog({
    required this.tag,
    required this.count,
    required this.onSave,
    this.onDelete,
  });

  /// Null for a new tag.
  final TeamEntryTag? tag;

  /// How many entry tags the team has, so a new one starts on the next
  /// colour.
  final int count;
  final Future<String?> Function(TeamEntryTag tag) onSave;
  final Future<String?> Function()? onDelete;

  @override
  State<_EntryTagDialog> createState() => _EntryTagDialogState();
}

class _EntryTagDialogState extends State<_EntryTagDialog> {
  late final _name = TextEditingController(text: widget.tag?.name ?? '');
  late int _color = widget.tag?.color ?? widget.count % _paletteSize;
  bool _saving = false;
  String? _error;

  static const _paletteSize = 8;

  L get t => L.of(context);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await _run(
      () => widget.onSave(
        TeamEntryTag(id: widget.tag?.id, name: name, color: _color),
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.teamSettingsDeleteTag),
        content: Text(t.teamSettingsDeleteEntryTagConfirm(widget.tag!.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              t.commonDelete,
              style: TextStyle(color: context.luma.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await _run(widget.onDelete!);
  }

  Future<void> _run(Future<String?> Function() call) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await call();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final palette = teamTagPalette(luma);
    return AlertDialog(
      title: Text(
        widget.tag == null ? t.teamSettingsNewTag : t.teamSettingsEditTag,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('team-settings-entry-tag-name'),
                controller: _name,
                autofocus: widget.tag == null,
                enabled: !_saving,
                maxLength: 24,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _saving ? null : _save(),
                decoration: InputDecoration(
                  labelText: t.teamSettingsTagName,
                  hintText: t.teamSettingsEntryTagNameHint,
                ),
              ),
              _SectionLabel(t.teamSettingsTagColor),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _paletteSize; i++)
                    Semantics(
                      selected: i == _color,
                      button: true,
                      child: InkWell(
                        onTap: _saving
                            ? null
                            : () => setState(() => _color = i),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: palette[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == _color
                                  ? luma.textPrimary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: i == _color
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: luma.onAccent,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              if (_name.text.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TeamTagChip(name: _name.text.trim(), color: _color),
                ),
              ],
              if (widget.onDelete != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('team-settings-delete-entry-tag'),
                    onPressed: _saving ? null : _delete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: luma.danger,
                    ),
                    label: Text(
                      t.teamSettingsDeleteTag,
                      style: TextStyle(color: luma.danger),
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: luma.danger, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        LumaGhostButton(
          label: t.commonCancel,
          onTap: _saving ? null : () => Navigator.of(context).pop(),
        ),
        LumaPrimaryButton(
          key: const ValueKey('team-settings-entry-tag-save'),
          label: t.commonSave,
          icon: Icons.check_rounded,
          loading: _saving,
          onTap: _saving || _name.text.trim().isEmpty ? null : _save,
        ),
      ],
    );
  }
}
