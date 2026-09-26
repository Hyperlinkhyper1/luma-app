import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';
import '../memory/assistant_memory_repository.dart';

/// Adds a memory page, or edits/deletes [entry].
Future<void> showAssistantMemoryEditor(
  BuildContext context, {
  required AssistantMemoryRepository repo,
  AssistantMemoryEntry? entry,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _MemoryEditor(repo: repo, entry: entry),
  );
}

class _MemoryEditor extends StatefulWidget {
  const _MemoryEditor({required this.repo, this.entry});

  final AssistantMemoryRepository repo;
  final AssistantMemoryEntry? entry;

  @override
  State<_MemoryEditor> createState() => _MemoryEditorState();
}

class _MemoryEditorState extends State<_MemoryEditor> {
  late final _title = TextEditingController(text: widget.entry?.title);
  late final _description = TextEditingController(
    text: widget.entry?.description,
  );
  late final _body = TextEditingController(text: widget.entry?.body);
  late MemorySection _section = widget.entry?.section ?? MemorySection.topics;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_valid) return;
    await widget.repo.saveEntry(
      id: widget.entry?.id,
      section: _section,
      title: _title.text,
      description: _description.text,
      body: _body.text,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await widget.repo.deleteEntry(widget.entry!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );
    InputDecoration decoration(String label, [String? hint]) => InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: luma.textSecondary, fontSize: 13.5),
      hintStyle: TextStyle(color: luma.textMuted, fontSize: 13.5),
      filled: true,
      fillColor: luma.background,
      isDense: true,
      alignLabelWithHint: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: border(luma.border),
      enabledBorder: border(luma.border),
      focusedBorder: border(luma.accent),
    );
    final text = TextStyle(color: luma.textPrimary, fontSize: 14);

    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: luma.border),
      ),
      title: Text(
        widget.entry == null ? t.assistantMemoryAdd : t.assistantMemoryEdit,
        style: TextStyle(color: luma.textPrimary),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<MemorySection>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: MemorySection.you,
                    label: Text(t.assistantMemoryYou),
                  ),
                  ButtonSegment(
                    value: MemorySection.topics,
                    label: Text(t.assistantMemoryTopics),
                  ),
                  ButtonSegment(
                    value: MemorySection.areas,
                    label: Text(t.assistantMemoryAreas),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (s) => setState(() => _section = s.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                autofocus: widget.entry == null,
                style: text,
                cursorColor: luma.accent,
                onChanged: (_) => setState(() {}),
                decoration: decoration(
                  t.assistantMemoryTitle,
                  t.assistantMemoryTitleHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                style: text,
                cursorColor: luma.accent,
                decoration: decoration(
                  t.assistantMemoryDescription,
                  t.assistantMemoryDescriptionHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 5,
                maxLines: 12,
                style: text,
                cursorColor: luma.accent,
                onChanged: (_) => setState(() {}),
                decoration: decoration(
                  t.assistantMemoryBody,
                  t.assistantMemoryBodyHint,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.entry != null)
          TextButton(
            onPressed: _delete,
            child: Text(
              t.assistantDelete,
              style: TextStyle(color: luma.danger),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            MaterialLocalizations.of(context).cancelButtonLabel,
            style: TextStyle(color: luma.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _valid ? _save : null,
          child: Text(
            t.assistantProfileSave,
            style: TextStyle(color: _valid ? luma.accent : luma.textMuted),
          ),
        ),
      ],
    );
  }
}
