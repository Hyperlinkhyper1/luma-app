import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/team_clipboard_api.dart';
import '../team_clipboard_controller.dart';
import '../team_clipboard_models.dart';
import 'team_clipboard_style.dart';
import 'team_files.dart';

/// Opens the dialog for a new entry, or for editing [existing]. A new entry
/// can bring its files along straight away.
Future<void> showTeamEntryEditor(
  BuildContext context,
  TeamClipboardController controller, {
  TeamEntry? existing,
}) => showDialog<void>(
  context: context,
  builder: (context) =>
      _TeamEntryEditor(controller: controller, existing: existing),
);

class _TeamEntryEditor extends StatefulWidget {
  const _TeamEntryEditor({required this.controller, this.existing});

  final TeamClipboardController controller;
  final TeamEntry? existing;

  @override
  State<_TeamEntryEditor> createState() => _TeamEntryEditorState();
}

class _TeamEntryEditorState extends State<_TeamEntryEditor> {
  late TeamEntryKind _kind = widget.existing?.kind ?? TeamEntryKind.model;
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _brief = TextEditingController(text: widget.existing?.brief);
  final List<TeamPickedFile> _files = [];
  bool _saving = false;
  String? _error;
  bool _titleMissing = false;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _title.dispose();
    _brief.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final t = L.of(context);
    final picked = await pickTeamFiles(t);
    if (picked == null || !mounted) return;
    setState(() {
      for (final f in picked.files) {
        _files.removeWhere((x) => x.name == f.name);
        _files.add(f);
      }
      _error = picked.rejected.isEmpty ? null : picked.rejected.join('\n');
    });
  }

  Future<void> _save() async {
    final t = L.of(context);
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleMissing = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      if (_isNew) {
        final (_, failed) = await widget.controller.create(
          kind: _kind,
          title: title,
          brief: _brief.text,
          files: _files,
        );
        if (failed.isNotEmpty) {
          messenger?.showSnackBar(
            SnackBar(
              content: Text(t.teamClipboardUploadFailed(failed.join(', '))),
            ),
          );
        }
      } else {
        await widget.controller.edit(
          widget.existing!.id,
          kind: _kind,
          title: title,
          brief: _brief.text,
        );
      }
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
    return Dialog(
      backgroundColor: luma.surface,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isNew
                    ? t.teamClipboardEditorNewTitle
                    : t.teamClipboardEditEntry,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _Label(t.teamClipboardEditorKind),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in TeamEntryKind.values)
                    _KindChoice(
                      kind: kind,
                      selected: kind == _kind,
                      onTap: _saving
                          ? null
                          : () => setState(() => _kind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _Label(t.teamClipboardEditorTitleLabel),
              TextField(
                controller: _title,
                autofocus: _isNew,
                enabled: !_saving,
                maxLength: 140,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_titleMissing) setState(() => _titleMissing = false);
                },
                decoration: InputDecoration(
                  hintText: t.teamClipboardEditorTitleHint,
                  errorText: _titleMissing
                      ? t.teamClipboardEditorTitleRequired
                      : null,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              _Label(t.teamClipboardEditorBriefLabel),
              TextField(
                controller: _brief,
                enabled: !_saving,
                minLines: 4,
                maxLines: 10,
                maxLength: 4000,
                decoration: InputDecoration(
                  hintText: t.teamClipboardEditorBriefHint,
                  counterText: '',
                ),
              ),
              if (_isNew) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _Label(t.teamClipboardFiles)),
                    TextButton.icon(
                      onPressed: _saving ? null : _pick,
                      icon: const Icon(Icons.attach_file_rounded, size: 18),
                      label: Text(t.teamClipboardAddFiles),
                    ),
                  ],
                ),
                Text(
                  t.teamClipboardEditorFilesHint,
                  style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                ),
                if (_files.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in _files)
                        InputChip(
                          label: Text(
                            '${f.name} · ${teamFileSize(f.bytes.length)}',
                          ),
                          onDeleted: _saving
                              ? null
                              : () => setState(() => _files.remove(f)),
                        ),
                    ],
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: luma.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  LumaGhostButton(
                    label: t.commonCancel,
                    onTap: _saving ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  LumaPrimaryButton(
                    label: _isNew ? t.teamClipboardCreate : t.commonSave,
                    icon: _isNew ? Icons.add_rounded : Icons.check_rounded,
                    loading: _saving,
                    onTap: _saving ? null : _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        color: context.luma.textSecondary,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _KindChoice extends StatelessWidget {
  const _KindChoice({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final TeamEntryKind kind;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = teamKindColor(kind, luma);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.16) : luma.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : luma.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(teamKindIcon(kind), size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                teamKindLabel(L.of(context), kind),
                style: TextStyle(
                  color: selected ? luma.textPrimary : luma.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
