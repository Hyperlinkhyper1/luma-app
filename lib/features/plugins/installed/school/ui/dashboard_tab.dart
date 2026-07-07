import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/school_database.dart';
import '../school_scope.dart';
import 'subject_dialog.dart';
import 'time_format.dart';

/// Landing view for the School plugin: today's classes, what's due soon, and
/// a few quick stats pulled from the other sections.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = SchoolScope.of(context);
    final luma = context.luma;
    final today = DateTime.now();

    return StreamData<List<SchoolSubject>>(
      stream: repo.watchSubjects(),
      builder: (context, subjects) {
        final subjectById = {for (final s in subjects) s.id: s};
        return StreamData<List<TimetableEntry>>(
          stream: repo.watchTimetable(),
          builder: (context, timetable) {
            final todays = timetable
                .where((t) => t.dayOfWeek == today.weekday)
                .toList()
              ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
            return StreamData<List<Assignment>>(
              stream: repo.watchAssignments(includeCompleted: false),
              builder: (context, assignments) {
                final dueSoon = assignments
                    .where((a) =>
                        a.dueDate.difference(today).inDays <= 7 &&
                        a.dueDate.isAfter(today.subtract(const Duration(days: 1))))
                    .toList()
                  ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
                final overdue = assignments
                    .where((a) => a.dueDate.isBefore(
                        DateTime(today.year, today.month, today.day)))
                    .length;

                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Row(
                      children: [
                        _StatCard(
                          label: 'Subjects',
                          value: '${subjects.length}',
                          icon: Icons.menu_book_rounded,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'Due this week',
                          value: '${dueSoon.length}',
                          icon: Icons.assignment_rounded,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: 'Overdue',
                          value: '$overdue',
                          icon: Icons.warning_amber_rounded,
                          color: overdue > 0 ? luma.danger : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text('Subjects',
                            style: TextStyle(
                                color: luma.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        LumaGhostButton(
                          label: 'Add subject',
                          icon: Icons.add_rounded,
                          onTap: () => showSubjectDialog(context, repo),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (subjects.isEmpty)
                      LumaCard(
                        child: Text('No subjects yet. Add one to get started.',
                            style: TextStyle(color: luma.textMuted)),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final s in subjects)
                            GestureDetector(
                              onTap: () => showSubjectDialog(context, repo, existing: s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: luma.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: luma.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Color(s.color),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(s.name, style: TextStyle(color: luma.textPrimary, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    Text('Today', style: TextStyle(color: luma.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if (todays.isEmpty)
                      LumaCard(
                        child: Text('No classes scheduled today.',
                            style: TextStyle(color: luma.textMuted)),
                      )
                    else
                      LumaCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < todays.length; i++) ...[
                              if (i > 0) Divider(color: luma.border, height: 20),
                              _ClassRow(
                                entry: todays[i],
                                subject: subjectById[todays[i].subjectId],
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text('Due soon', style: TextStyle(color: luma.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if (dueSoon.isEmpty)
                      LumaCard(
                        child: Text('Nothing due in the next 7 days.',
                            style: TextStyle(color: luma.textMuted)),
                      )
                    else
                      LumaCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < dueSoon.length; i++) ...[
                              if (i > 0) Divider(color: luma.border, height: 20),
                              _AssignmentRow(
                                assignment: dueSoon[i],
                                subject: subjectById[dueSoon[i].subjectId],
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Expanded(
      child: LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color ?? luma.accent, size: 22),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(color: luma.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: luma.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.entry, required this.subject});
  final TimetableEntry entry;
  final SchoolSubject? subject;

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
              if (entry.location != null && entry.location!.isNotEmpty)
                Text(entry.location!, style: TextStyle(color: luma.textMuted, fontSize: 12)),
            ],
          ),
        ),
        Text('${formatMinutesOfDay(entry.startMinutes)} - ${formatMinutesOfDay(entry.endMinutes)}',
            style: TextStyle(color: luma.textSecondary, fontSize: 13)),
      ],
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({required this.assignment, required this.subject});
  final Assignment assignment;
  final SchoolSubject? subject;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final today = DateTime.now();
    final isOverdue = assignment.dueDate
        .isBefore(DateTime(today.year, today.month, today.day));
    return Row(
      children: [
        LumaIconBadge(
          icon: Icons.assignment_rounded,
          color: Color(subject?.color ?? 0xFF7C5AD9),
          size: 36,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(assignment.title,
                  style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600)),
              if (subject != null)
                Text(subject!.name, style: TextStyle(color: luma.textMuted, fontSize: 12)),
            ],
          ),
        ),
        Text(
          '${assignment.dueDate.month}/${assignment.dueDate.day}',
          style: TextStyle(
            color: isOverdue ? luma.danger : luma.textSecondary,
            fontSize: 13,
            fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
