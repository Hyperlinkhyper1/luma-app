import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/school_database.dart';
import '../school_repository.dart';
import '../school_scope.dart';

/// A simple stopwatch per subject, a log of past sessions, and a bar chart
/// of total studied minutes by subject.
class StudyTimerTab extends StatefulWidget {
  const StudyTimerTab({super.key});

  @override
  State<StudyTimerTab> createState() => _StudyTimerTabState();
}

class _StudyTimerTabState extends State<StudyTimerTab> {
  @override
  Widget build(BuildContext context) {
    final repo = SchoolScope.of(context);
    final luma = context.luma;
    return StreamData<List<SchoolSubject>>(
      stream: repo.watchSubjects(),
      builder: (context, subjects) {
        final subjectById = {for (final s in subjects) s.id: s};
        return StreamData<List<StudySession>>(
          stream: repo.watchStudySessions(),
          builder: (context, sessions) {
            final active = sessions.where((s) => s.endTime == null).toList();
            final activeSession = active.isEmpty ? null : active.first;

            final totals = <int?, int>{};
            for (final s in sessions) {
              totals[s.subjectId] = (totals[s.subjectId] ?? 0) + s.durationMinutes;
            }
            final totalEntries = totals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LumaCard(
                          child: activeSession == null
                              ? _StartForm(subjects: subjects, repo: repo)
                              : _ActiveTimer(
                                  session: activeSession,
                                  subject: subjectById[activeSession.subjectId],
                                  onStop: () => repo.stopSession(activeSession.id),
                                ),
                        ),
                        const SizedBox(height: 20),
                        Text('Time by subject',
                            style: TextStyle(
                                color: luma.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        if (totalEntries.isEmpty)
                          LumaCard(
                              child: Text('No study sessions logged yet.',
                                  style: TextStyle(color: luma.textMuted)))
                        else
                          LumaCard(
                            child: SizedBox(
                              height: 220,
                              child: BarChart(
                                BarChartData(
                                  maxY: (totalEntries.first.value * 1.2).clamp(10, double.infinity),
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                  titlesData: FlTitlesData(
                                    leftTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final i = value.toInt();
                                          if (i < 0 || i >= totalEntries.length) {
                                            return const SizedBox.shrink();
                                          }
                                          final subjectId = totalEntries[i].key;
                                          final label = subjectId == null
                                              ? 'None'
                                              : (subjectById[subjectId]?.name ?? '?');
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(label,
                                                style:
                                                    TextStyle(color: luma.textMuted, fontSize: 10)),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  barGroups: [
                                    for (var i = 0; i < totalEntries.length; i++)
                                      BarChartGroupData(
                                        x: i,
                                        barRods: [
                                          BarChartRodData(
                                            toY: totalEntries[i].value.toDouble(),
                                            color: totalEntries[i].key == null
                                                ? luma.textMuted
                                                : Color(subjectById[totalEntries[i].key]?.color ??
                                                    0xFF7C5AD9),
                                            width: 20,
                                            borderRadius: const BorderRadius.vertical(
                                                top: Radius.circular(6)),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recent sessions',
                            style: TextStyle(
                                color: luma.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Builder(builder: (context) {
                            final completed =
                                sessions.where((s) => s.endTime != null).toList();
                            if (completed.isEmpty) {
                              return const LumaEmptyState(
                                icon: Icons.timer_outlined,
                                title: 'No completed sessions',
                              );
                            }
                            return ListView.separated(
                                  itemCount: completed.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final s = completed[i];
                                    return LumaCard(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  subjectById[s.subjectId]?.name ?? 'No subject',
                                                  style: TextStyle(
                                                      color: luma.textPrimary,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13),
                                                ),
                                                Text(
                                                  '${s.startTime.month}/${s.startTime.day} · ${s.durationMinutes} min',
                                                  style:
                                                      TextStyle(color: luma.textMuted, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline_rounded,
                                                color: luma.textMuted, size: 18),
                                            onPressed: () => repo.deleteSession(s.id),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                          }),
                        ),
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
}

class _StartForm extends StatefulWidget {
  const _StartForm({required this.subjects, required this.repo});
  final List<SchoolSubject> subjects;
  final SchoolRepository repo;

  @override
  State<_StartForm> createState() => _StartFormState();
}

class _StartFormState extends State<_StartForm> {
  int? _subjectId;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Start studying',
            style: TextStyle(color: luma.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        LumaPrimaryButton(
          label: 'Start timer',
          icon: Icons.play_arrow_rounded,
          expand: true,
          onTap: () => widget.repo.startSession(subjectId: _subjectId),
        ),
      ],
    );
  }
}

/// Ticks its own display once a second. Owning the [Timer] here (rather than
/// in the always-mounted [StudyTimerTab]) means it only exists while a
/// session is actually running, so it can't outlive its usefulness.
class _ActiveTimer extends StatefulWidget {
  const _ActiveTimer({required this.session, required this.subject, required this.onStop});
  final StudySession session;
  final SchoolSubject? subject;
  final VoidCallback onStop;

  @override
  State<_ActiveTimer> createState() => _ActiveTimerState();
}

class _ActiveTimerState extends State<_ActiveTimer> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final session = widget.session;
    final subject = widget.subject;
    final onStop = widget.onStop;
    final elapsed = DateTime.now().difference(session.startTime);
    final h = elapsed.inHours.toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(subject?.name ?? 'Studying',
            style: TextStyle(color: luma.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Text('$h:$m:$s',
            style: TextStyle(
                color: luma.textPrimary,
                fontSize: 40,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(height: 12),
        LumaPrimaryButton(
          label: 'Stop',
          icon: Icons.stop_rounded,
          expand: true,
          onTap: onStop,
        ),
      ],
    );
  }
}
