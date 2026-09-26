import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';
import '../memory/assistant_memory_repository.dart';
import '../memory/assistant_memory_scope.dart';
import '../widgets/chat_markdown.dart';
import 'assistant_memory_editor.dart';
import 'assistant_panels.dart';

enum _Section { chat, memory, user }

/// The assistant's settings, laid out like the Claude app's: a side list of
/// sections — Chat, Memory, User — and the chosen section beside it. On a
/// phone the side list becomes a row of pills over the content.
class AssistantSettingsView extends StatefulWidget {
  const AssistantSettingsView({super.key});

  @override
  State<AssistantSettingsView> createState() => _AssistantSettingsViewState();
}

class _AssistantSettingsViewState extends State<AssistantSettingsView> {
  _Section _section = _Section.chat;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final repo = AssistantMemoryScope.of(context);
    final sections = [
      (
        _Section.chat,
        Icons.chat_bubble_outline_rounded,
        t.assistantSettingsChat,
      ),
      (_Section.memory, Icons.psychology_outlined, t.assistantSettingsMemory),
      (_Section.user, Icons.person_outline_rounded, t.assistantSettingsUser),
    ];
    final Widget content = switch (_section) {
      _Section.chat => _ChatSection(repo: repo),
      _Section.memory => _MemorySection(repo: repo),
      _Section.user => _UserSection(repo: repo),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 56, 12),
                child: AssistantPanelTitle(t.assistantMenuSettings),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LumaSegmentedTabs(
                  scrollable: true,
                  tabs: [for (final s in sections) s.$3],
                  selectedIndex: _section.index,
                  onSelect: (i) => setState(() => _section = sections[i].$1),
                ),
              ),
              Expanded(child: content),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 220,
              decoration: BoxDecoration(
                color: luma.rail,
                border: Border(right: BorderSide(color: luma.border)),
              ),
              padding: const EdgeInsets.fromLTRB(10, 22, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Text(
                      t.assistantMenuSettings,
                      style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                    ),
                  ),
                  for (final (section, icon, label) in sections)
                    _NavItem(
                      icon: icon,
                      label: label,
                      selected: section == _section,
                      onTap: () => setState(() => _section = section),
                    ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 38,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? luma.surfaceHover
                : _hovering
                ? luma.surfaceHover.withValues(alpha: 0.6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.selected ? luma.textPrimary : luma.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.selected
                      ? luma.textPrimary
                      : luma.textSecondary,
                  fontSize: 14,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The scrolling column every section sits in, with a heading.
class _SectionScaffold extends StatelessWidget {
  const _SectionScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 32),
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 36),
          child: AssistantPanelTitle(title),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

/// A setting: its name and explanation on the left, the control on the
/// right — or below, when there isn't room.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.description,
    required this.control,
  });

  final String title;
  final String description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(color: luma.textMuted, fontSize: 13, height: 1.4),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 520
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text, const SizedBox(height: 12), control],
              )
            : Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 24),
                  control,
                ],
              ),
      ),
    );
  }
}

/// A row of connected choice buttons, like the Claude app's font picker.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.values,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < values.length; i++)
            GestureDetector(
              onTap: () => onSelect(values[i]),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: values[i] == selected
                        ? luma.surfaceHover
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: values[i] == selected
                          ? luma.textPrimary
                          : luma.textSecondary,
                      fontSize: 13,
                      fontWeight: values[i] == selected
                          ? FontWeight.w600
                          : FontWeight.w400,
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

class _ChatSection extends StatelessWidget {
  const _ChatSection({required this.repo});

  final AssistantMemoryRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return _SectionScaffold(
      title: t.assistantSettingsChat,
      children: [
        _SettingRow(
          title: t.assistantSettingsLanguage,
          description: t.assistantSettingsLanguageHint,
          control: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: luma.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: luma.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: repo.languageCode,
                dropdownColor: luma.surface,
                borderRadius: BorderRadius.circular(10),
                style: TextStyle(color: luma.textPrimary, fontSize: 13.5),
                items: [
                  for (final language in kAssistantLanguages)
                    DropdownMenuItem(
                      value: language.code,
                      child: Text(
                        language.code == 'auto'
                            ? t.assistantSettingsLanguageAuto
                            : language.nativeName,
                      ),
                    ),
                ],
                onChanged: (code) {
                  if (code != null) repo.setLanguageCode(code);
                },
              ),
            ),
          ),
        ),
        _SettingRow(
          title: t.assistantSettingsFont,
          description: t.assistantSettingsFontHint,
          control: _Choice<ChatFont>(
            values: ChatFont.values,
            labels: [
              t.assistantFontSerif,
              t.assistantFontSans,
              t.assistantFontMono,
            ],
            selected: repo.font,
            onSelect: repo.setFont,
          ),
        ),
        _SettingRow(
          title: t.assistantSettingsTextSize,
          description: t.assistantSettingsTextSizeHint,
          control: _Choice<ChatTextSize>(
            values: ChatTextSize.values,
            labels: [
              t.assistantTextSmall,
              t.assistantTextMedium,
              t.assistantTextLarge,
            ],
            selected: repo.textSize,
            onSelect: repo.setTextSize,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          t.assistantSettingsPreview,
          style: TextStyle(color: luma.textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: luma.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: luma.border),
          ),
          child: ChatMarkdown(source: t.assistantSettingsPreviewText),
        ),
      ],
    );
  }
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({required this.repo});

  final AssistantMemoryRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final groups = [
      (MemorySection.you, t.assistantMemoryYou),
      (MemorySection.topics, t.assistantMemoryTopics),
      (MemorySection.areas, t.assistantMemoryAreas),
    ];
    return _SectionScaffold(
      title: t.assistantSettingsMemory,
      children: [
        _SettingRow(
          title: t.assistantMemoryUse,
          description: t.assistantMemoryUseHint,
          control: Switch(
            value: repo.memoryEnabled,
            onChanged: repo.setMemoryEnabled,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(Icons.cloud_outlined, size: 16, color: luma.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.assistantMemorySyncNote(
                    formatStorageBytes(repo.approximateBytes),
                  ),
                  style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                ),
              ),
              const SizedBox(width: 12),
              LumaGhostButton(
                label: t.assistantMemoryAdd,
                icon: Icons.add_rounded,
                onTap: () => showAssistantMemoryEditor(context, repo: repo),
              ),
            ],
          ),
        ),
        if (repo.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: LumaEmptyState(
              icon: Icons.psychology_outlined,
              title: t.assistantMemoryEmpty,
              subtitle: t.assistantMemoryEmptyHint,
            ),
          )
        else ...[
          for (final (section, label) in groups)
            if (repo.entriesIn(section).isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
                child: Text(
                  label,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Divider(height: 1, color: luma.border),
              for (final entry in repo.entriesIn(section))
                _MemoryRow(
                  entry: entry,
                  onTap: () => showAssistantMemoryEditor(
                    context,
                    repo: repo,
                    entry: entry,
                  ),
                ),
            ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _confirmClear(context),
              style: TextButton.styleFrom(foregroundColor: luma.danger),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text(t.assistantMemoryClear),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final luma = context.luma;
    final t = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
        title: Text(
          t.assistantMemoryClearTitle,
          style: TextStyle(color: luma.textPrimary),
        ),
        content: Text(
          t.assistantMemoryClearBody,
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
              style: TextStyle(color: luma.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              t.assistantMemoryClear,
              style: TextStyle(color: luma.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await repo.clearMemory();
  }
}

/// One memory page, laid out like the Claude app's list: title, summary,
/// "Updated Aug 24".
class _MemoryRow extends StatefulWidget {
  const _MemoryRow({required this.entry, required this.onTap});

  final AssistantMemoryEntry entry;
  final VoidCallback onTap;

  @override
  State<_MemoryRow> createState() => _MemoryRowState();
}

class _MemoryRowState extends State<_MemoryRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final entry = widget.entry;
    final updated = t.assistantMemoryUpdated(
      DateFormat.MMMd(locale).format(entry.updatedAt),
    );
    final description = entry.description.isNotEmpty
        ? entry.description
        : entry.body.split('\n').first;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
          decoration: BoxDecoration(
            color: _hovering
                ? luma.surfaceHover.withValues(alpha: 0.4)
                : Colors.transparent,
            border: Border(bottom: BorderSide(color: luma.border)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final title = Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: luma.textPrimary, fontSize: 14),
              );
              final summary = Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: luma.textSecondary, fontSize: 13.5),
              );
              final date = Text(
                updated,
                style: TextStyle(color: luma.textMuted, fontSize: 13),
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: title),
                        date,
                      ],
                    ),
                    const SizedBox(height: 3),
                    summary,
                  ],
                );
              }
              return Row(
                children: [
                  SizedBox(width: 170, child: title),
                  const SizedBox(width: 16),
                  Expanded(child: summary),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 130,
                    child: Align(alignment: Alignment.centerLeft, child: date),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UserSection extends StatefulWidget {
  const _UserSection({required this.repo});

  final AssistantMemoryRepository repo;

  @override
  State<_UserSection> createState() => _UserSectionState();
}

class _UserSectionState extends State<_UserSection> {
  late final _callMe = TextEditingController(text: widget.repo.profile.callMe);
  late final _occupation = TextEditingController(
    text: widget.repo.profile.occupation,
  );
  late final _summary = TextEditingController(
    text: widget.repo.profile.summary,
  );
  late final _instructions = TextEditingController(
    text: widget.repo.profile.instructions,
  );
  bool _saved = false;

  List<TextEditingController> get _all => [
    _callMe,
    _occupation,
    _summary,
    _instructions,
  ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _dirty {
    final p = widget.repo.profile;
    return _callMe.text != p.callMe ||
        _occupation.text != p.occupation ||
        _summary.text != p.summary ||
        _instructions.text != p.instructions;
  }

  Future<void> _save() async {
    await widget.repo.setProfile(
      AssistantUserProfile(
        callMe: _callMe.text.trim(),
        occupation: _occupation.text.trim(),
        summary: _summary.text.trim(),
        instructions: _instructions.text.trim(),
      ),
    );
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return _SectionScaffold(
      title: t.assistantSettingsUser,
      children: [
        const SizedBox(height: 8),
        _Field(
          label: t.assistantProfileCallMe,
          hint: t.assistantProfileCallMeHint,
          controller: _callMe,
          onChanged: () => setState(() => _saved = false),
        ),
        _Field(
          label: t.assistantProfileOccupation,
          hint: t.assistantProfileOccupationHint,
          controller: _occupation,
          onChanged: () => setState(() => _saved = false),
        ),
        _Field(
          label: t.assistantProfileSummary,
          hint: t.assistantProfileSummaryHint,
          controller: _summary,
          lines: 4,
          onChanged: () => setState(() => _saved = false),
        ),
        _Field(
          label: t.assistantProfileInstructions,
          hint: t.assistantProfileInstructionsHint,
          controller: _instructions,
          lines: 4,
          onChanged: () => setState(() => _saved = false),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Opacity(
              opacity: _dirty ? 1 : 0.5,
              child: LumaPrimaryButton(
                label: t.assistantProfileSave,
                icon: Icons.check_rounded,
                onTap: () {
                  if (_dirty) _save();
                },
              ),
            ),
            if (_saved && !_dirty) ...[
              const SizedBox(width: 12),
              Text(
                t.assistantProfileSaved,
                style: TextStyle(color: context.luma.success, fontSize: 13),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.lines = 1,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: lines,
            maxLines: lines == 1 ? 1 : lines + 4,
            onChanged: (_) => onChanged(),
            style: TextStyle(color: luma.textPrimary, fontSize: 14),
            cursorColor: luma.accent,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: luma.textMuted, fontSize: 14),
              filled: true,
              fillColor: luma.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: border(luma.border),
              enabledBorder: border(luma.border),
              focusedBorder: border(luma.accent),
            ),
          ),
        ],
      ),
    );
  }
}
