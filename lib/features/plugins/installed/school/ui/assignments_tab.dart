import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/school_database.dart';
import '../school_repository.dart';
import '../school_scope.dart';
import 'subject_dialog.dart';

const _priorityLabels = ['Low', 'Medium', 'High'];

/// Homework / assignment tracker: a due-dated task list per subject, with
/// priority, completion, and an optional grade once it's returned.
class AssignmentsTab extends StatefulWidget {
  const AssignmentsTab({super.key});

  @override
  State<AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<AssignmentsTab> {
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final repo = SchoolScope.of(context);
    return StreamData<List<SchoolSubject>>(
      stream: repo.watchSubjects(),
      builder: (context, subjects) {
        final subjectById = {for (final s in subjects) s.id: s};
        return StreamData<List<Assignment>>(
          stream: repo.watchAssignments(includeCompleted: _showCompleted),
          builder: (context, assignments) {
            final sorted = [...assignments]
              ..sort((a, b) {
                if (a.completed != b.completed) return a.completed ? 1 : -1;
                return a.dueDate.compareTo(b.dueDate);
              });
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      FilterChip(
                        label: const Text('Show completed'),
                        selected: _showCompleted,
                        onSelected: (v) => setState(() => _showCompleted = v),
                      ),
                      const Spacer(),
                      LumaPrimaryButton(
                        label: 'Add assignment',
                        icon: Icons.add_rounded,
                        onTap: () => subjects.isEmpty
                            ? showSubjectDialog(context, repo)
                            : _openEditor(context, repo, subjects),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: sorted.isEmpty
                        ? const LumaEmptyState(
                            icon: Icons.assignment_turned_in_rounded,
                            title: 'No assignments',
                            subtitle: 'Add homework or a tracked assignment to see it here.',
                          )
                        : ListView.separated(
                            itemCount: sorted.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final a = sorted[i];
                              return LumaCard(
                                child: _AssignmentTile(
                                  assignment: a,
                                  subject: subjectById[a.subjectId],
                                  onToggle: (v) => repo.toggleAssignmentComplete(a.id, v),
                                  onTap: () =>
                                      _openEditor(context, repo, subjects, existing: a),
                                  onDelete: () => repo.deleteAssignment(a.id),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    SchoolRepository repo,
    List<SchoolSubject> subjects, {
    Assignment? existing,
  }) {
    return showDialog(
      context: context,
      builder: (_) => _AssignmentDialog(repo: repo, subjects: subjects, existing: existing),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.assignment,
    required this.subject,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });
  final Assignment assignment;
  final SchoolSubject? subject;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final priorityColor = switch (assignment.priority) {
      2 => luma.danger,
      1 => const Color(0xFFFFB020),
      _ => luma.textMuted,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Checkbox(value: assignment.completed, onChanged: (v) => onToggle(v ?? false)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.title,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontWeight: FontWeight.w600,
                    decoration: assignment.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (subject != null) subject!.name,
                    'Due ${assignment.dueDate.month}/${assignment.dueDate.day}/${assignment.dueDate.year}',
                    if (assignment.gradeEarned != null && assignment.gradeTotal != null)
                      '${assignment.gradeEarned!.toStringAsFixed(1)}/${assignment.gradeTotal!.toStringAsFixed(0)}',
                  ].join(' · '),
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: luma.textMuted, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({required this.repo, required this.subjects, this.existing});
  final SchoolRepository repo;
  final List<SchoolSubject> subjects;
  final Assignment? existing;

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  late final _notesController = TextEditingController(text: widget.existing?.notes ?? '');
  late int? _subjectId = widget.existing?.subjectId ??
      (widget.subjects.isEmpty ? null : widget.subjects.first.id);
  late DateTime _dueDate = widget.existing?.dueDate ?? DateTime.now();
  late int _priority = widget.existing?.priority ?? 1;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    if (widget.existing == null) {
      await widget.repo.createAssignment(
        subjectId: _subjectId,
        title: title,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
      );
    } else {
      await widget.repo.updateAssignment(
        widget.existing!.id,
        subjectId: _subjectId,
        title: title,
        notes: _notesController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add assignment' : 'Edit assignment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            if (widget.subjects.isNotEmpty)
              DropdownButtonFormField<int?>(
                initialValue: _subjectId,
                decoration: const InputDecoration(labelText: 'Subject (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  for (final s in widget.subjects)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _subjectId = v),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _dueDate = d);
              },
              child: Text('Due ${_dueDate.month}/${_dueDate.day}/${_dueDate.year}'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: [
                for (var i = 0; i < _priorityLabels.length; i++)
                  DropdownMenuItem(value: i, child: Text(_priorityLabels[i])),
              ],
              onChanged: (v) => setState(() => _priority = v!),
            ),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
