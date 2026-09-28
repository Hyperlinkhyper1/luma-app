import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../text_library_models.dart';
import '../text_library_scope.dart';
import 'format_toolbar.dart';
import 'text_editor_view.dart';

/// Subjects on the left, their texts on the right, the editor in place of
/// the texts while one is open. On a phone the three are separate steps.
class ClassicLibraryView extends StatefulWidget {
  const ClassicLibraryView({super.key});

  @override
  State<ClassicLibraryView> createState() => _ClassicLibraryViewState();
}

/// What the right-hand side shows.
sealed class _Pane {
  const _Pane();
}

class _TextsPane extends _Pane {
  const _TextsPane();
}

class _EditorPane extends _Pane {
  const _EditorPane(this.text);

  /// Null for a new text.
  final LibraryText? text;
}

class _ClassicLibraryViewState extends State<ClassicLibraryView> {
  int? _subjectId;
  _Pane _pane = const _TextsPane();
  int _editorGeneration = 0;

  void _openSubject(int id) => setState(() {
    _subjectId = id;
    _pane = const _TextsPane();
  });

  void _openText(LibraryText? text) => setState(() {
    _editorGeneration++;
    _pane = _EditorPane(text);
  });

  void _closeEditor() => setState(() => _pane = const _TextsPane());

  Future<void> _newSubject() async {
    final result = await showDialog<_SubjectDraft>(
      context: context,
      builder: (_) => const _SubjectDialog(),
    );
    if (result == null || !mounted) return;
    final id = await TextLibraryScope.of(
      context,
    ).createSubject(result.name, color: result.color);
    if (mounted) _openSubject(id);
  }

  Future<void> _editSubject(LibrarySubject subject) async {
    final repository = TextLibraryScope.of(context);
    final result = await showDialog<_SubjectDraft>(
      context: context,
      builder: (_) => _SubjectDialog(initial: subject),
    );
    if (result == null) return;
    await repository.renameSubject(subject.id, result.name);
    await repository.setSubjectColor(subject.id, result.color);
  }

  Future<void> _deleteSubject(LibrarySubject subject, int count) async {
    final t = L.of(context);
    final repository = TextLibraryScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.textLibraryDeleteSubjectTitle(subject.name)),
        content: Text(t.textLibraryDeleteSubjectBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.textLibraryCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.luma.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.textLibraryDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await repository.deleteSubject(subject.id);
    if (mounted && _subjectId == subject.id) {
      setState(() {
        _subjectId = null;
        _pane = const _TextsPane();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = TextLibraryScope.of(context);
    final narrow = context.isPhoneWidth;
    final t = L.of(context);

    return StreamData<List<LibrarySubject>>(
      stream: repository.watchSubjects(),
      builder: (context, subjects) {
        return StreamData<Map<int, int>>(
          stream: repository.watchCounts(),
          builder: (context, counts) {
            if (subjects.isEmpty) {
              return LumaEmptyState(
                icon: Icons.auto_stories_rounded,
                title: t.textLibraryNoSubjects,
                subtitle: t.textLibraryNoSubjectsSub,
                action: LumaPrimaryButton(
                  label: t.textLibraryNewSubject,
                  icon: Icons.add_rounded,
                  onTap: _newSubject,
                ),
              );
            }
            final selected = subjects
                .where((s) => s.id == _subjectId)
                .firstOrNull;
            final subjectList = _SubjectList(
              subjects: subjects,
              counts: counts,
              selectedId: narrow ? null : (selected ?? subjects.first).id,
              onOpen: _openSubject,
              onNew: _newSubject,
              onEdit: _editSubject,
              onDelete: (s) => _deleteSubject(s, counts[s.id] ?? 0),
            );

            if (narrow) {
              if (selected == null) return subjectList;
              return _rightPane(selected, showBack: true);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 280, child: subjectList),
                VerticalDivider(width: 1, color: context.luma.border),
                Expanded(
                  child: _rightPane(
                    selected ?? subjects.first,
                    showBack: false,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _rightPane(LibrarySubject subject, {required bool showBack}) {
    final pane = _pane;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (pane) {
        _EditorPane(:final text) => TextEditorView(
          key: ValueKey('editor-$_editorGeneration'),
          subjectId: subject.id,
          text: text,
          onClose: _closeEditor,
        ),
        _TextsPane() => _TextsList(
          key: ValueKey('texts-${subject.id}'),
          subject: subject,
          onBack: showBack ? () => setState(() => _subjectId = null) : null,
          onOpen: _openText,
        ),
      },
    );
  }
}

class _SubjectList extends StatelessWidget {
  const _SubjectList({
    required this.subjects,
    required this.counts,
    required this.selectedId,
    required this.onOpen,
    required this.onNew,
    required this.onEdit,
    required this.onDelete,
  });

  final List<LibrarySubject> subjects;
  final Map<int, int> counts;
  final int? selectedId;
  final ValueChanged<int> onOpen;
  final VoidCallback onNew;
  final ValueChanged<LibrarySubject> onEdit;
  final ValueChanged<LibrarySubject> onDelete;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.textLibrarySubjects,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: t.textLibraryNewSubject,
                onPressed: onNew,
                icon: Icon(Icons.add_rounded, color: luma.accent),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              final selected = subject.id == selectedId;
              final count = counts[subject.id] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: selected ? luma.accentSubtle : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onOpen(subject.id),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                        child: Row(
                          children: [
                            _SpineMark(color: subject.color.color),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    subject.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: luma.textPrimary,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    t.textLibraryTextCount(count),
                                    style: TextStyle(
                                      color: luma.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: '',
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                color: luma.textMuted,
                              ),
                              onSelected: (value) => value == 'edit'
                                  ? onEdit(subject)
                                  : onDelete(subject),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(t.textLibraryRename),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    t.textLibraryDelete,
                                    style: TextStyle(color: luma.danger),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TextsList extends StatefulWidget {
  const _TextsList({
    super.key,
    required this.subject,
    required this.onBack,
    required this.onOpen,
  });

  final LibrarySubject subject;
  final VoidCallback? onBack;
  final ValueChanged<LibraryText?> onOpen;

  @override
  State<_TextsList> createState() => _TextsListState();
}

class _TextsListState extends State<_TextsList> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final narrow = context.isPhoneWidth;
    final repository = TextLibraryScope.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 12 : 24, 12, narrow ? 12 : 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.onBack != null)
                IconButton(
                  tooltip: t.textLibraryBack,
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              _SpineMark(color: widget.subject.color.color, height: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              LumaPrimaryButton(
                label: t.textLibraryNewText,
                icon: Icons.edit_note_rounded,
                onTap: () => widget.onOpen(null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              isDense: true,
              hintText: t.textLibrarySearchHint,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamData<List<LibraryText>>(
              stream: repository.watchTexts(widget.subject.id),
              builder: (context, texts) {
                if (texts.isEmpty) {
                  return LumaEmptyState(
                    icon: Icons.edit_note_rounded,
                    title: t.textLibraryNoTexts,
                    subtitle: t.textLibraryNoTextsSub,
                  );
                }
                final query = _query.toLowerCase();
                final shown = query.isEmpty
                    ? texts
                    : texts
                          .where(
                            (text) =>
                                text.title.toLowerCase().contains(query) ||
                                text.body.plainText.toLowerCase().contains(
                                  query,
                                ),
                          )
                          .toList();
                if (shown.isEmpty) {
                  return LumaEmptyState(
                    icon: Icons.search_off_rounded,
                    title: t.textLibraryNoMatches(_query),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 172,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (context, index) => _TextCard(
                    text: shown[index],
                    onTap: () => widget.onOpen(shown[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TextCard extends StatefulWidget {
  const _TextCard({required this.text, required this.onTap});

  final LibraryText text;
  final VoidCallback onTap;

  @override
  State<_TextCard> createState() => _TextCardState();
}

class _TextCardState extends State<_TextCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final text = widget.text;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: true,
        label: text.title,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: _hover ? luma.surfaceHover : luma.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: luma.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 8, color: text.cover.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text.rich(
                            _previewSpan(text.body, luma.textSecondary),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: luma.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat.yMMMd(locale).format(text.updatedAt),
                          style: TextStyle(color: luma.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The body's first few hundred characters with their styling, flattened
  /// onto one paragraph.
  static TextSpan _previewSpan(RichDoc body, Color ink) {
    const limit = 280;
    var used = 0;
    final base = TextStyle(color: ink);
    final children = <TextSpan>[];
    for (final span in body.spans) {
      if (used >= limit) break;
      var piece = span.text.replaceAll(RegExp(r'\s+'), ' ');
      if (used + piece.length > limit) piece = piece.substring(0, limit - used);
      used += piece.length;
      children.add(TextSpan(text: piece, style: span.style.toTextStyle(base)));
    }
    return TextSpan(children: children);
  }
}

/// A thin book-spine swatch in a subject's colour.
class _SpineMark extends StatelessWidget {
  const _SpineMark({required this.color, this.height = 32});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: context.luma.border),
    ),
  );
}

class _SubjectDraft {
  const _SubjectDraft(this.name, this.color);

  final String name;
  final DyeColor color;
}

class _SubjectDialog extends StatefulWidget {
  const _SubjectDialog({this.initial});

  final LibrarySubject? initial;

  @override
  State<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<_SubjectDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late DyeColor _color = widget.initial?.color ?? DyeColor.red;
  bool _showError = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context, _SubjectDraft(name, _color));
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(
        editing ? t.textLibraryRenameSubject : t.textLibraryNewSubject,
      ),
      content: SizedBox(
        width: lumaDialogWidth(context, 4 * 40 + 3 * 6 + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 48,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_showError) setState(() => _showError = false);
              },
              decoration: InputDecoration(
                labelText: t.textLibrarySubjectNameHint,
                errorText: _showError ? t.textLibrarySubjectNameRequired : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(t.textLibraryColor),
            const SizedBox(height: 8),
            DyePicker(
              value: _color,
              onChanged: (dye) => setState(() => _color = dye),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.textLibraryCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(editing ? t.textLibrarySave : t.textLibraryCreate),
        ),
      ],
    );
  }
}
