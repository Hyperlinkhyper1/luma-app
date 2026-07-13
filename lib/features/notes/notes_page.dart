import 'package:flutter/material.dart';

import '../../storage/storage_guard.dart';
import '../../theme/luma_theme.dart';
import 'notes_repository.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

final _checklistRegex = RegExp(r'^\[( |x|X)\] (.*)$');

class _NotesPageState extends State<NotesPage> {
  late final NotesRepository _repo = NotesRepository();
  String? _selectedId;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _editing = false;

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
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onRepoChanged() {
    if (!mounted) return;
    setState(() {});
    final notes = _repo.notes;
    if (_selectedId != null && notes.every((n) => n.id != _selectedId)) {
      if (notes.isNotEmpty) {
        _selectNote(notes.first.id);
      } else {
        setState(() => _selectedId = null);
      }
    }
  }

  void _selectNote(String id) {
    final note = _repo.notes.firstWhere((n) => n.id == id);
    setState(() {
      _selectedId = id;
      _editing = false;
    });
    _titleController.text = note.title;
    _contentController.text = note.content;
  }

  Future<void> _newNote() async {
    final Note note;
    try {
      note = await _repo.create();
    } on StorageLimitExceededException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    _selectNote(note.id);
    setState(() => _editing = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) FocusScope.of(context).requestFocus(_titleFocus);
    });
  }

  Future<void> _saveEdits() async {
    if (_selectedId == null) return;
    await _repo.update(
      _selectedId!,
      title: _titleController.text,
      content: _contentController.text,
    );
    setState(() => _editing = false);
  }

  Future<void> _deleteNote(String id) async {
    await _repo.delete(id);
  }

  Future<void> _toggleChecklistLine(Note note, int lineIndex) async {
    final lines = note.content.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    final match = _checklistRegex.firstMatch(lines[lineIndex]);
    if (match == null) return;
    final checked = match.group(1)!.toLowerCase() == 'x';
    final text = match.group(2)!;
    lines[lineIndex] = '[${checked ? ' ' : 'x'}] $text';
    await _repo.update(note.id, content: lines.join('\n'));
  }

  void _insertChecklistItem() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final insertAt = selection.isValid ? selection.start : text.length;
    final needsNewline = insertAt > 0 && text[insertAt - 1] != '\n';
    final insertion = '${needsNewline ? '\n' : ''}[ ] ';
    final newText = text.replaceRange(insertAt, insertAt, insertion);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertAt + insertion.length),
    );
  }

  final _titleFocus = FocusNode();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final notes = _repo.notes;
    final selectedNote = _selectedId != null
        ? notes.where((n) => n.id == _selectedId).firstOrNull
        : null;

    // Below this width a fixed 240px sidebar next to the editor leaves too
    // little room for either pane, so phones get a single-pane master/detail
    // flow instead: the list fills the screen until a note is opened, then
    // the editor takes over with a back button to return to the list.
    final isNarrow = MediaQuery.sizeOf(context).width < 640;

    if (isNarrow) {
      return selectedNote == null
          ? _NotesList(
              notes: notes,
              selectedId: _selectedId,
              onSelect: _selectNote,
              onNew: _newNote,
              onDelete: _deleteNote,
            )
          : _NoteEditor(
              key: ValueKey(selectedNote.id),
              note: selectedNote,
              editing: _editing,
              titleController: _titleController,
              contentController: _contentController,
              titleFocus: _titleFocus,
              onBack: () => setState(() => _selectedId = null),
              onEdit: () => setState(() => _editing = true),
              onSave: _saveEdits,
              onCancel: () {
                setState(() => _editing = false);
                _titleController.text = selectedNote.title;
                _contentController.text = selectedNote.content;
              },
              onInsertChecklistItem: _insertChecklistItem,
              onToggleChecklistLine: (i) =>
                  _toggleChecklistLine(selectedNote, i),
            );
    }

    return Row(
      children: [
        _NotesList(
          notes: notes,
          selectedId: _selectedId,
          onSelect: _selectNote,
          onNew: _newNote,
          onDelete: _deleteNote,
          width: 240,
        ),
        Container(width: 1, color: luma.border),
        Expanded(
          child: selectedNote == null
              ? _EmptyState(onNew: _newNote)
              : _NoteEditor(
                  key: ValueKey(selectedNote.id),
                  note: selectedNote,
                  editing: _editing,
                  titleController: _titleController,
                  contentController: _contentController,
                  titleFocus: _titleFocus,
                  onEdit: () => setState(() => _editing = true),
                  onSave: _saveEdits,
                  onCancel: () {
                    setState(() => _editing = false);
                    _titleController.text = selectedNote.title;
                    _contentController.text = selectedNote.content;
                  },
                  onInsertChecklistItem: _insertChecklistItem,
                  onToggleChecklistLine: (i) =>
                      _toggleChecklistLine(selectedNote, i),
                ),
        ),
      ],
    );
  }
}

class _NotesList extends StatelessWidget {
  const _NotesList({
    required this.notes,
    required this.selectedId,
    required this.onSelect,
    required this.onNew,
    required this.onDelete,
    this.width,
  });

  final List<Note> notes;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNew;
  final ValueChanged<String> onDelete;

  /// Fixed sidebar width for the two-pane desktop/tablet layout; null when
  /// this list is shown full-width as its own screen on a phone.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Text(
                'Notes',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _IconBtn(
                icon: Icons.add_rounded,
                tooltip: 'New note',
                onTap: onNew,
              ),
            ],
          ),
        ),
        Container(height: 1, color: luma.border),
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: Text(
                    'No notes yet',
                    style: TextStyle(color: luma.textMuted, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: notes.length,
                  itemBuilder: (context, i) {
                    final note = notes[i];
                    final selected = note.id == selectedId;
                    return _NoteListTile(
                      note: note,
                      selected: selected,
                      onTap: () => onSelect(note.id),
                      onDelete: () => onDelete(note.id),
                    );
                  },
                ),
        ),
      ],
    );
    return width == null ? column : SizedBox(width: width, child: column);
  }
}

class _NoteListTile extends StatefulWidget {
  const _NoteListTile({
    required this.note,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_NoteListTile> createState() => _NoteListTileState();
}

class _NoteListTileState extends State<_NoteListTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final note = widget.note;
    final selected = widget.selected;

    final title = note.title.isEmpty ? 'Untitled' : note.title;
    final preview = note.content.replaceAll('\n', ' ');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          decoration: BoxDecoration(
            color: selected
                ? luma.accentSubtle
                : (_hovering ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? luma.accent : luma.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              if (_hovering || selected)
                _IconBtn(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete',
                  size: 16,
                  onTap: widget.onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteEditor extends StatelessWidget {
  const _NoteEditor({
    super.key,
    required this.note,
    required this.editing,
    required this.titleController,
    required this.contentController,
    required this.titleFocus,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
    required this.onInsertChecklistItem,
    required this.onToggleChecklistLine,
    this.onBack,
  });

  final Note note;
  final bool editing;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final FocusNode titleFocus;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onInsertChecklistItem;
  final ValueChanged<int> onToggleChecklistLine;

  /// Non-null on the phone single-pane layout, where the editor replaces
  /// the list instead of sitting next to it — lets the user return to it.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                _IconBtn(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back to notes',
                  onTap: onBack!,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: editing
                    ? TextField(
                        controller: titleController,
                        focusNode: titleFocus,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Title',
                          hintStyle: TextStyle(color: luma.textMuted),
                          border: InputBorder.none,
                        ),
                      )
                    : Text(
                        note.title.isEmpty ? 'Untitled' : note.title,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              if (editing) ...[
                _IconBtn(
                  icon: Icons.checklist_rounded,
                  tooltip: 'Add checklist item',
                  onTap: onInsertChecklistItem,
                ),
                const SizedBox(width: 4),
                _TextBtn(label: 'Cancel', onTap: onCancel),
                const SizedBox(width: 8),
                _TextBtn(label: 'Save', accent: true, onTap: onSave),
              ] else
                _TextBtn(label: 'Edit', onTap: onEdit),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatDate(note.updatedAt),
            style: TextStyle(color: luma.textMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: editing
                ? TextField(
                    controller: contentController,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14.5,
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Write something…',
                      hintStyle: TextStyle(color: luma.textMuted),
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                  )
                : SingleChildScrollView(
                    child: note.content.isEmpty
                        ? Text(
                            'Tap Edit to add content.',
                            style: TextStyle(
                              color: luma.textMuted,
                              fontSize: 14.5,
                              height: 1.6,
                            ),
                          )
                        : _ChecklistAwareContent(
                            content: note.content,
                            onToggleLine: onToggleChecklistLine,
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ChecklistAwareContent extends StatelessWidget {
  const _ChecklistAwareContent({
    required this.content,
    required this.onToggleLine,
  });

  final String content;
  final ValueChanged<int> onToggleLine;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          Builder(
            builder: (context) {
              final match = _checklistRegex.firstMatch(lines[i]);
              if (match == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    lines[i],
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14.5,
                      height: 1.6,
                    ),
                  ),
                );
              }
              final checked = match.group(1)!.toLowerCase() == 'x';
              final text = match.group(2)!;
              return GestureDetector(
                onTap: () => onToggleLine(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: checked,
                          onChanged: (_) => onToggleLine(i),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          activeColor: luma.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            text,
                            style: TextStyle(
                              color: checked
                                  ? luma.textMuted
                                  : luma.textPrimary,
                              fontSize: 14.5,
                              height: 1.6,
                              decoration: checked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sticky_note_2_outlined, size: 48, color: luma.textMuted),
          const SizedBox(height: 16),
          Text(
            'No note selected',
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new note to get started.',
            style: TextStyle(color: luma.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          _TextBtn(label: '+ New Note', accent: true, onTap: onNew),
        ],
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.tooltip = '',
    this.size = 18,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovering ? luma.surfaceHover : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: widget.size,
              color: luma.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TextBtn extends StatefulWidget {
  const _TextBtn({
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  State<_TextBtn> createState() => _TextBtnState();
}

class _TextBtnState extends State<_TextBtn> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = widget.accent ? luma.accent : luma.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.accent
                ? (_hovering
                      ? luma.accentHover.withValues(alpha: 0.15)
                      : luma.accentSubtle)
                : (_hovering ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
