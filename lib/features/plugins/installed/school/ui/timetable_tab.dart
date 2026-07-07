import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/school_database.dart';
import '../school_repository.dart';
import '../school_scope.dart';
import 'subject_dialog.dart';
import 'time_format.dart';

/// The weekly class schedule: one section per day with its class blocks.
class TimetableTab extends StatelessWidget {
  const TimetableTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = SchoolScope.of(context);
    return StreamData<List<SchoolSubject>>(
      stream: repo.watchSubjects(),
      builder: (context, subjects) {
        return StreamData<List<TimetableEntry>>(
          stream: repo.watchTimetable(),
          builder: (context, entries) {
            final subjectById = {for (final s in subjects) s.id: s};
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('Weekly schedule',
                          style: TextStyle(color: context.luma.textSecondary, fontSize: 13)),
                      const Spacer(),
                      LumaPrimaryButton(
                        label: 'Add class',
                        icon: Icons.add_rounded,
                        onTap: () => subjects.isEmpty
                            ? showSubjectDialog(context, repo)
                            : _openEditor(context, repo, subjects),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: entries.isEmpty
                        ? LumaEmptyState(
                            icon: Icons.calendar_view_week_rounded,
                            title: 'No classes scheduled',
                            subtitle: subjects.isEmpty
                                ? 'Add a subject first, then add its class times.'
                                : 'Tap "Add class" to build your weekly schedule.',
                          )
                        : ListView(
                            padding: const EdgeInsets.only(bottom: 24),
                            children: [
                              for (var day = 1; day <= 7; day++) ...[
                                Builder(builder: (context) {
                                  final dayEntries = entries
                                      .where((e) => e.dayOfWeek == day)
                                      .toList()
                                    ..sort((a, b) =>
                                        a.startMinutes.compareTo(b.startMinutes));
                                  if (dayEntries.isEmpty) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(weekdayName(day),
                                            style: TextStyle(
                                                color: context.luma.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 8),
                                        LumaCard(
                                          child: Column(
                                            children: [
                                              for (var i = 0; i < dayEntries.length; i++) ...[
                                                if (i > 0)
                                                  Divider(color: context.luma.border, height: 20),
                                                _EntryRow(
                                                  entry: dayEntries[i],
                                                  subject: subjectById[dayEntries[i].subjectId],
                                                  onDelete: () =>
                                                      repo.deleteTimetableEntry(dayEntries[i].id),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
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
      BuildContext context, SchoolRepository repo, List<SchoolSubject> subjects) {
    return showDialog(
      context: context,
      builder: (_) => _TimetableEditorDialog(repo: repo, subjects: subjects),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.subject, required this.onDelete});
  final TimetableEntry entry;
  final SchoolSubject? subject;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        LumaIconBadge(
          icon: Icons.school_rounded,
          color: Color(subject?.color ?? 0xFF7C5AD9),
          size: 36,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subject?.name ?? 'Class',
                  style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600)),
              Text(
                [
                  '${formatMinutesOfDay(entry.startMinutes)} - ${formatMinutesOfDay(entry.endMinutes)}',
                  if (entry.location != null && entry.location!.isNotEmpty) entry.location!,
                  if (entry.instructor != null && entry.instructor!.isNotEmpty) entry.instructor!,
                ].join(' · '),
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: luma.textMuted, size: 20),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _TimetableEditorDialog extends StatefulWidget {
  const _TimetableEditorDialog({required this.repo, required this.subjects});
  final SchoolRepository repo;
  final List<SchoolSubject> subjects;

  @override
  State<_TimetableEditorDialog> createState() => _TimetableEditorDialogState();
}

class _TimetableEditorDialogState extends State<_TimetableEditorDialog> {
  late int _subjectId = widget.subjects.first.id;
  int _dayOfWeek = 1;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  final _locationController = TextEditingController();
  final _instructorController = TextEditingController();

  @override
  void dispose() {
    _locationController.dispose();
    _instructorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add class'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _subjectId,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: [
                for (final s in widget.subjects)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _subjectId = v!),
            ),
            DropdownButtonFormField<int>(
              initialValue: _dayOfWeek,
              decoration: const InputDecoration(labelText: 'Day'),
              items: [
                for (var d = 1; d <= 7; d++)
                  DropdownMenuItem(value: d, child: Text(weekdayName(d))),
              ],
              onChanged: (v) => setState(() => _dayOfWeek = v!),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _start);
                      if (t != null) setState(() => _start = t);
                    },
                    child: Text('Start: ${_start.format(context)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _end);
                      if (t != null) setState(() => _end = t);
                    },
                    child: Text('End: ${_end.format(context)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location (optional)'),
            ),
            TextField(
              controller: _instructorController,
              decoration: const InputDecoration(labelText: 'Instructor (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await widget.repo.createTimetableEntry(
              subjectId: _subjectId,
              dayOfWeek: _dayOfWeek,
              startMinutes: _start.hour * 60 + _start.minute,
              endMinutes: _end.hour * 60 + _end.minute,
              location: _locationController.text.trim().isEmpty
                  ? null
                  : _locationController.text.trim(),
              instructor: _instructorController.text.trim().isEmpty
                  ? null
                  : _instructorController.text.trim(),
            );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
