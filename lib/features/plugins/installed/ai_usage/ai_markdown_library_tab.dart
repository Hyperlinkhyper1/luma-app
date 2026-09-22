import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'ai_workbench_models.dart';
import 'ai_workbench_repository.dart';
import 'ai_workbench_scope.dart';

/// A local Markdown library used directly by agents and exportable as files.
class AiMarkdownLibraryTab extends StatefulWidget {
  const AiMarkdownLibraryTab({super.key});

  @override
  State<AiMarkdownLibraryTab> createState() => _AiMarkdownLibraryTabState();
}

class _AiMarkdownLibraryTabState extends State<AiMarkdownLibraryTab> {
  String? _selectedId;
  String? _editingId;
  bool _editorReady = false;
  bool _preview = false;
  bool _saving = false;
  late final TextEditingController _titleController;
  late final TextEditingController _tagsController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _tagsController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _select(AiMarkdownEntry? entry) {
    setState(() {
      _selectedId = entry?.id;
      _editingId = entry?.id;
      _titleController.text = entry?.title ?? '';
      _tagsController.text = entry?.tags.join(', ') ?? '';
      _bodyController.text = entry?.body ?? '';
      _editorReady = true;
      _preview = false;
    });
  }

  void _ensureSelection(AiWorkbenchRepository repo) {
    if (!repo.loaded || _editorReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _editorReady) return;
      final first = repo.markdownEntries.firstOrNull;
      if (first != null) {
        _select(first);
      } else {
        _select(null);
      }
    });
  }

  Future<void> _save(AiWorkbenchRepository repo) async {
    setState(() => _saving = true);
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    await repo.saveMarkdown(
      id: _editingId,
      title: _titleController.text,
      body: _bodyController.text,
      tags: tags,
    );
    if (!mounted) return;
    final saved = repo.markdownEntries
        .where((entry) => entry.id == (_editingId ?? ''))
        .firstOrNull;
    // A new note has a new id, so find it by the latest update when there was
    // no existing selection.
    final selected = saved ?? repo.markdownEntries.firstOrNull;
    setState(() {
      _saving = false;
      _selectedId = selected?.id;
      _editingId = selected?.id;
    });
    _toast('Markdown note saved');
  }

  void _newNote() => _select(null);

  Future<void> _import() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Import Markdown note',
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final body = file.bytes != null
        ? utf8.decode(file.bytes!, allowMalformed: true)
        : file.path == null
        ? null
        : await File(file.path!).readAsString();
    if (body == null) return;
    _select(null);
    _titleController.text = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    _bodyController.text = body;
    if (mounted)
      _toast('Imported ${file.name} — save it to add it to the library');
  }

  Future<void> _export(AiMarkdownEntry entry) async {
    final fileName = '${_safeFileName(entry.title)}.md';
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export Markdown note',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['md'],
      bytes: Uint8List.fromList(utf8.encode(entry.body)),
    );
    if (path == null) return;
    if (!Platform.isAndroid) {
      await File(path).writeAsString(entry.body, flush: true);
    }
    if (mounted) _toast('Exported $fileName');
  }

  Future<void> _delete(
    AiWorkbenchRepository repo,
    AiMarkdownEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Markdown note?'),
        content: Text('"${entry.title}" will be removed from the library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await repo.deleteMarkdown(entry.id);
    if (!mounted) return;
    final next = repo.markdownEntries.firstOrNull;
    _select(next);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final repo = AiWorkbenchScope.of(context);
    _ensureSelection(repo);
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (!repo.loaded) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2.4),
          );
        }
        final selected = _selectedId == null
            ? null
            : repo.markdownById(_selectedId!);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LibraryHeader(
                count: repo.markdownEntries.length,
                onNew: _newNote,
                onImport: _import,
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 760;
                    final list = _LibraryList(
                      entries: repo.markdownEntries,
                      selectedId: _selectedId,
                      onSelect: _select,
                      onNew: _newNote,
                    );
                    final editor = _MarkdownEditor(
                      entry: selected,
                      titleController: _titleController,
                      tagsController: _tagsController,
                      bodyController: _bodyController,
                      preview: _preview,
                      saving: _saving,
                      onPreviewChanged: (value) =>
                          setState(() => _preview = value),
                      onSave: () => _save(repo),
                      onExport: selected == null
                          ? null
                          : () => _export(selected),
                      onDelete: selected == null
                          ? null
                          : () => _delete(repo, selected),
                    );
                    if (narrow) {
                      return Column(
                        children: [
                          SizedBox(height: 210, child: list),
                          const SizedBox(height: 12),
                          Expanded(child: editor),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 260, child: list),
                        const SizedBox(width: 14),
                        Expanded(child: editor),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _safeFileName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9 _-]+'), '');
    return cleaned.isEmpty ? 'note' : cleaned.replaceAll(' ', '_');
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.count,
    required this.onNew,
    required this.onImport,
  });
  final int count;
  final VoidCallback onNew;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Markdown Library',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '$count ${count == 1 ? 'note' : 'notes'} · reusable context for your agents',
              style: TextStyle(color: context.luma.textSecondary),
            ),
          ],
        ),
      ),
      LumaGhostButton(
        label: 'Import',
        icon: Icons.file_open_rounded,
        onTap: onImport,
      ),
      const SizedBox(width: 10),
      LumaPrimaryButton(
        label: 'New note',
        icon: Icons.add_rounded,
        onTap: onNew,
      ),
    ],
  );
}

class _LibraryList extends StatelessWidget {
  const _LibraryList({
    required this.entries,
    required this.selectedId,
    required this.onSelect,
    required this.onNew,
  });
  final List<AiMarkdownEntry> entries;
  final String? selectedId;
  final ValueChanged<AiMarkdownEntry?> onSelect;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return LumaCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 32,
              color: context.luma.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              'Your library is empty',
              style: TextStyle(
                color: context.luma.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Save prompts, project context, and checklists here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.luma.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            LumaGhostButton(
              label: 'Create note',
              icon: Icons.add_rounded,
              onTap: onNew,
            ),
          ],
        ),
      );
    }
    return LumaCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: context.luma.border),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final selected = entry.id == selectedId;
          return ListTile(
            dense: true,
            selected: selected,
            selectedTileColor: context.luma.accentSubtle,
            leading: Icon(
              Icons.description_outlined,
              size: 19,
              color: selected ? context.luma.accent : context.luma.textMuted,
            ),
            title: Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              entry.tags.isEmpty ? 'Markdown note' : entry.tags.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelect(entry),
          );
        },
      ),
    );
  }
}

class _MarkdownEditor extends StatelessWidget {
  const _MarkdownEditor({
    required this.entry,
    required this.titleController,
    required this.tagsController,
    required this.bodyController,
    required this.preview,
    required this.saving,
    required this.onPreviewChanged,
    required this.onSave,
    required this.onExport,
    required this.onDelete,
  });
  final AiMarkdownEntry? entry;
  final TextEditingController titleController;
  final TextEditingController tagsController;
  final TextEditingController bodyController;
  final bool preview;
  final bool saving;
  final ValueChanged<bool> onPreviewChanged;
  final VoidCallback onSave;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry == null ? 'New Markdown note' : 'Edit note',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (entry != null) ...[
                IconButton(
                  tooltip: 'Export .md',
                  onPressed: onExport,
                  icon: const Icon(Icons.download_rounded),
                ),
                IconButton(
                  tooltip: 'Delete note',
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded, color: luma.danger),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Project conventions',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: tagsController,
            decoration: const InputDecoration(
              labelText: 'Tags',
              hintText: 'flutter, conventions, project',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Content',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Edit')),
                  ButtonSegment(value: true, label: Text('Preview')),
                ],
                selected: {preview},
                onSelectionChanged: (value) => onPreviewChanged(value.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: preview
                ? SingleChildScrollView(
                    child: SelectableText(
                      bodyController.text.isEmpty
                          ? 'Nothing written yet.'
                          : bodyController.text,
                      style: TextStyle(color: luma.textPrimary, height: 1.5),
                    ),
                  )
                : TextField(
                    controller: bodyController,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText:
                          '# Instructions\n\nWrite reusable context in Markdown…',
                      alignLabelWithHint: true,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: LumaPrimaryButton(
              label: saving ? 'Saving…' : 'Save note',
              icon: Icons.save_rounded,
              onTap: saving ? null : onSave,
            ),
          ),
        ],
      ),
    );
  }
}
