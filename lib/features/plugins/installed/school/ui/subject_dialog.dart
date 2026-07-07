import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../data/school_database.dart';
import '../school_repository.dart';

const kSubjectColorChoices = [
  Color(0xFFB49DF5), // lavender
  Color(0xFF57D9A3), // mint
  Color(0xFFFF6B81), // coral
  Color(0xFFFFD166), // gold
  Color(0xFF6ECBF5), // sky
  Color(0xFFBC96E6), // purple
  Color(0xFF85E0C3), // seafoam
  Color(0xFFFF9E6D), // peach
];

/// Opens a create/edit dialog for a subject. Pass [existing] to edit it
/// (with a delete option), or leave it null to create a new one.
Future<void> showSubjectDialog(
  BuildContext context,
  SchoolRepository repo, {
  SchoolSubject? existing,
}) {
  return showDialog(
    context: context,
    builder: (_) => _SubjectDialog(repo: repo, existing: existing),
  );
}

class _SubjectDialog extends StatefulWidget {
  const _SubjectDialog({required this.repo, this.existing});
  final SchoolRepository repo;
  final SchoolSubject? existing;

  @override
  State<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<_SubjectDialog> {
  late final _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _creditsController = TextEditingController(
      text: (widget.existing?.creditHours ?? 3).toString());
  late int _color = widget.existing?.color ?? kSubjectColorChoices.first.toARGB32();

  @override
  void dispose() {
    _nameController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final credits = double.tryParse(_creditsController.text.trim()) ?? 3;
    if (widget.existing == null) {
      await widget.repo.createSubject(name, color: _color, creditHours: credits);
    } else {
      await widget.repo.updateSubject(widget.existing!.id,
          name: name, color: _color, creditHours: credits);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add subject' : 'Edit subject'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _creditsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Credit hours'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in kSubjectColorChoices)
                  GestureDetector(
                    onTap: () => setState(() => _color = c.toARGB32()),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c.toARGB32() ? luma.textPrimary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              await widget.repo.deleteSubject(widget.existing!.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: luma.danger)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
