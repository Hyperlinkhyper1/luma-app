import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/luma_theme.dart';
import 'notes_repository.dart';

final _checklistRegex = RegExp(r'^\[( |x|X)\] (.*)$');

const double _cardWidth = 240;
const double _gap = 16;
const double _cardRadius = 8;

/// Notes laid out like a sticky-note board: a "take a note" composer on top
/// and a masonry grid of cards below. Opening a card edits it in a dialog.
class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final NotesRepository _repo = NotesRepository();

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    // NotesRepository is a shared singleton (also used by the sync engine),
    // so the page must NOT dispose it — only detach its own listener.
    _repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _createFromComposer(String title, String content) async {
    if (title.trim().isEmpty && content.trim().isEmpty) return;
    await _repo.create(title: title, content: content);
  }

  Future<void> _toggleChecklistLine(Note note, int lineIndex) async {
    final content = _toggledContent(note.content, lineIndex);
    if (content != null) await _repo.update(note.id, content: content);
  }

  Future<void> _openNote(Note note) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _NoteDialog(
        note: note,
        onSave: (title, content) {
          final current =
              _repo.notes.where((n) => n.id == note.id).firstOrNull;
          if (current == null) return;
          if (current.title == title && current.content == content) return;
          _repo.update(note.id, title: title, content: content);
        },
        onDelete: () => _repo.delete(note.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = _repo.notes;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final narrow = width < 600;
        final sidePad = narrow ? 12.0 : 24.0;
        final available = width - sidePad * 2;

        final int columns;
        final double cardWidth;
        final double gap = narrow ? 10 : _gap;
        if (narrow) {
          columns = available >= 300 ? 2 : 1;
          cardWidth = (available - gap * (columns - 1)) / columns;
        } else {
          columns = ((available + gap) / (_cardWidth + gap)).floor().clamp(
            1,
            100,
          );
          cardWidth = _cardWidth;
        }

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(sidePad, 24, sidePad, 28),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: _Composer(onCreate: _createFromComposer),
                  ),
                ),
              ),
            ),
            if (notes.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(sidePad, 0, sidePad, 32),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: _MasonryGrid(
                      columns: columns,
                      cardWidth: cardWidth,
                      gap: gap,
                      notes: notes,
                      itemBuilder: (note) => _NoteCard(
                        key: ValueKey(note.id),
                        note: note,
                        onTap: () => _openNote(note),
                        onDelete: () => _repo.delete(note.id),
                        onToggleLine: (i) => _toggleChecklistLine(note, i),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String? _toggledContent(String content, int lineIndex) {
  final lines = content.split('\n');
  if (lineIndex < 0 || lineIndex >= lines.length) return null;
  final match = _checklistRegex.firstMatch(lines[lineIndex]);
  if (match == null) return null;
  final checked = match.group(1)!.toLowerCase() == 'x';
  lines[lineIndex] = '[${checked ? ' ' : 'x'}] ${match.group(2)!}';
  return lines.join('\n');
}

void _insertChecklistItem(TextEditingController controller) {
  final text = controller.text;
  final selection = controller.selection;
  final insertAt = selection.isValid ? selection.start : text.length;
  final needsNewline = insertAt > 0 && text[insertAt - 1] != '\n';
  final insertion = '${needsNewline ? '\n' : ''}[ ] ';
  controller.value = TextEditingValue(
    text: text.replaceRange(insertAt, insertAt, insertion),
    selection: TextSelection.collapsed(offset: insertAt + insertion.length),
  );
}

/// Places notes into columns left to right, each going under whichever
/// column is currently shortest, so the board fills evenly like masonry.
class _MasonryGrid extends StatelessWidget {
  const _MasonryGrid({
    required this.columns,
    required this.cardWidth,
    required this.gap,
    required this.notes,
    required this.itemBuilder,
  });

  final int columns;
  final double cardWidth;
  final double gap;
  final List<Note> notes;
  final Widget Function(Note note) itemBuilder;

  static double _estimateHeight(Note note, double width) {
    final charsPerLine = (width / 8.5).clamp(10, 80);
    double lines = 0;
    if (note.title.trim().isNotEmpty) {
      lines += (note.title.length / charsPerLine).ceil() * 1.3;
    }
    final contentLines = note.content.split('\n');
    var counted = 0.0;
    for (final l in contentLines) {
      counted += (l.length / charsPerLine).ceil().clamp(1, 100);
      if (counted >= _NoteCard.maxPreviewLines) break;
    }
    lines += counted.clamp(0, _NoteCard.maxPreviewLines.toDouble());
    return 72 + lines * 22;
  }

  @override
  Widget build(BuildContext context) {
    final buckets = List.generate(columns, (_) => <Note>[]);
    final heights = List.filled(columns, 0.0);
    for (final note in notes) {
      var target = 0;
      for (var c = 1; c < columns; c++) {
        if (heights[c] < heights[target] - 1) target = c;
      }
      buckets[target].add(note);
      heights[target] += _estimateHeight(note, cardWidth) + gap;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < columns; c++) ...[
          if (c > 0) SizedBox(width: gap),
          SizedBox(
            width: cardWidth,
            child: Column(
              children: [
                for (var i = 0; i < buckets[c].length; i++) ...[
                  if (i > 0) SizedBox(height: gap),
                  itemBuilder(buckets[c][i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The collapsed "Take a note…" bar that expands into an inline title +
/// body editor. Closing it (button, Esc, or clicking elsewhere) saves the
/// note if anything was typed.
class _Composer extends StatefulWidget {
  const _Composer({required this.onCreate});

  final Future<void> Function(String title, String content) onCreate;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _contentFocus = FocusNode();
  bool _expanded = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _expand({bool checklist = false}) {
    setState(() => _expanded = true);
    if (checklist && _content.text.isEmpty) {
      _insertChecklistItem(_content);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _contentFocus.requestFocus();
    });
  }

  void _close() {
    if (!_expanded) return;
    final title = _title.text;
    final content = _content.text.trimRight();
    _title.clear();
    _content.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _expanded = false);
    widget.onCreate(title, content == '[ ]' ? '' : content);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);

    final decoration = BoxDecoration(
      color: luma.surface,
      borderRadius: BorderRadius.circular(_cardRadius),
      border: Border.all(color: luma.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.14),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );

    if (!_expanded) {
      return MouseRegion(
        cursor: SystemMouseCursors.text,
        child: GestureDetector(
          onTap: _expand,
          child: Container(
            height: 48,
            padding: const EdgeInsets.only(left: 16, right: 8),
            decoration: decoration,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.notesTakeANote,
                    style: TextStyle(
                      color: luma.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _IconBtn(
                  icon: Icons.check_box_outlined,
                  tooltip: t.notesNewListTooltip,
                  onTap: () => _expand(checklist: true),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return TapRegion(
      onTapOutside: (_) => _close(),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          decoration: decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _bareDecoration(t.commonTitle, luma),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _contentFocus.requestFocus(),
              ),
              TextField(
                controller: _content,
                focusNode: _contentFocus,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14.5,
                  height: 1.45,
                ),
                decoration: _bareDecoration(t.notesTakeANote, luma),
                minLines: 1,
                maxLines: 14,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _IconBtn(
                    icon: Icons.check_box_outlined,
                    tooltip: t.notesAddChecklistTooltip,
                    onTap: () => _insertChecklistItem(_content),
                  ),
                  const Spacer(),
                  _TextBtn(label: t.commonClose, onTap: _close),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _bareDecoration(String hint, LumaPalette luma) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: luma.textMuted, fontWeight: FontWeight.w500),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
    );

class _NoteCard extends StatefulWidget {
  const _NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onToggleLine,
  });

  static const int maxPreviewLines = 14;

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<int> onToggleLine;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final note = widget.note;
    final hasTitle = note.title.trim().isNotEmpty;
    final content = note.content.trimRight();

    // A short note with no title reads as a big sticky line, like the
    // one-liners on a real board.
    final bigText =
        !hasTitle &&
        content.length <= 40 &&
        !content.contains('\n') &&
        !_checklistRegex.hasMatch(content);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(
              color: _hovering ? luma.textMuted.withValues(alpha: 0.5) : luma.border,
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasTitle) ...[
                      Text(
                        note.title,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      if (content.isNotEmpty) const SizedBox(height: 8),
                    ],
                    if (content.isNotEmpty)
                      bigText
                          ? Text(
                              content,
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 22,
                                height: 1.3,
                              ),
                            )
                          : _ChecklistAwareContent(
                              content: content,
                              maxLines: _NoteCard.maxPreviewLines,
                              compact: true,
                              onToggleLine: widget.onToggleLine,
                            ),
                    if (!hasTitle && content.isEmpty)
                      Text(
                        t.commonUntitled,
                        style: TextStyle(
                          color: luma.textMuted,
                          fontSize: 14.5,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: _hovering ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_hovering,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const Spacer(),
                          _IconBtn(
                            icon: Icons.delete_outline_rounded,
                            tooltip: t.commonDelete,
                            onTap: widget.onDelete,
                          ),
                        ],
                      ),
                    ),
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

/// A note opened from the board. Edits are live in the fields and saved
/// when the dialog closes, however it closes.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.note,
    required this.onSave,
    required this.onDelete,
  });

  final Note note;
  final void Function(String title, String content) onSave;
  final VoidCallback onDelete;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _title = TextEditingController(text: widget.note.title);
  late final _content = TextEditingController(text: widget.note.content);
  bool _deleted = false;

  @override
  void dispose() {
    if (!_deleted) widget.onSave(_title.text, _content.text.trimRight());
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: luma.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width < 600 ? 12 : 40,
        vertical: 32,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
        side: BorderSide(color: luma.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _bareDecoration(t.commonTitle, luma),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: TextField(
                    controller: _content,
                    autofocus: widget.note.title.isNotEmpty,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    decoration: _bareDecoration(t.notesJotHint, luma),
                    minLines: 3,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _IconBtn(
                    icon: Icons.check_box_outlined,
                    tooltip: t.notesAddChecklistTooltip,
                    onTap: () => _insertChecklistItem(_content),
                  ),
                  const SizedBox(width: 4),
                  _IconBtn(
                    icon: Icons.delete_outline_rounded,
                    tooltip: t.commonDelete,
                    onTap: () {
                      _deleted = true;
                      widget.onDelete();
                      Navigator.of(context).pop();
                    },
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(t, widget.note.updatedAt),
                    style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                  ),
                  const SizedBox(width: 12),
                  _TextBtn(
                    label: t.commonClose,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(L t, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return t.commonJustNow;
    if (diff.inMinutes < 60) return t.commonMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return t.commonHoursAgo(diff.inHours);
    if (diff.inDays < 7) return t.commonDaysAgo(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ChecklistAwareContent extends StatelessWidget {
  const _ChecklistAwareContent({
    required this.content,
    required this.onToggleLine,
    this.maxLines,
    this.compact = false,
  });

  final String content;
  final ValueChanged<int> onToggleLine;
  final int? maxLines;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final fontSize = compact ? 14.5 : 15.0;
    final allLines = content.split('\n');
    final truncated = maxLines != null && allLines.length > maxLines!;
    final lines = truncated ? allLines.sublist(0, maxLines) : allLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          Builder(
            builder: (context) {
              final match = _checklistRegex.firstMatch(lines[i]);
              if (match == null) {
                return Text(
                  lines[i],
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: fontSize,
                    height: 1.45,
                  ),
                );
              }
              final checked = match.group(1)!.toLowerCase() == 'x';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onToggleLine(i),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2, right: 8),
                          child: Icon(
                            checked
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 18,
                            color: checked ? luma.textMuted : luma.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        match.group(2)!,
                        style: TextStyle(
                          color: checked ? luma.textMuted : luma.textPrimary,
                          fontSize: fontSize,
                          height: 1.45,
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        if (truncated)
          Text(
            '…',
            style: TextStyle(color: luma.textMuted, fontSize: fontSize),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 96,
              color: luma.textMuted.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 18),
            Text(
              t.notesEmptyHint,
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.tooltip = '',
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _hovering ? luma.surfaceHover : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, size: 19, color: luma.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _TextBtn extends StatefulWidget {
  const _TextBtn({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_TextBtn> createState() => _TextBtnState();
}

class _TextBtnState extends State<_TextBtn> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: _hovering ? luma.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
