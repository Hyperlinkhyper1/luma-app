import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/school_database.dart';
import '../logic/gpa_calculator.dart';
import '../school_repository.dart';
import '../school_scope.dart';
import 'subject_dialog.dart';

/// GPA tracking (term-by-term records + trend) and a per-subject "what do I
/// need on the rest of my grades" projection calculator.
class GpaTab extends StatefulWidget {
  const GpaTab({super.key});

  @override
  State<GpaTab> createState() => _GpaTabState();
}

class _GpaTabState extends State<GpaTab> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LumaSegmentedTabs(
            tabs: const ['GPA', 'Grade calculator'],
            selectedIndex: _section,
            onSelect: (i) => setState(() => _section = i),
          ),
          const SizedBox(height: 16),
          Expanded(child: _section == 0 ? const _GpaSection() : const _GradeCalculatorSection()),
        ],
      ),
    );
  }
}

// ─── GPA records + trend ─────────────────────────────────────────────────

class _GpaSection extends StatelessWidget {
  const _GpaSection();

  @override
  Widget build(BuildContext context) {
    final repo = SchoolScope.of(context);
    final luma = context.luma;
    return StreamData<List<SchoolSubject>>(
      stream: repo.watchSubjects(),
      builder: (context, subjects) {
        final subjectById = {for (final s in subjects) s.id: s};
        return StreamData<List<GpaRecord>>(
          stream: repo.watchGpaRecords(),
          builder: (context, records) {
            final gpa = computeGpa([
              for (final r in records)
                GpaWeighting(creditHours: r.creditHours, gradePoints: r.gradePoints),
            ]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LumaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Overall GPA', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                            Text(gpa?.toStringAsFixed(2) ?? '--',
                                style: TextStyle(
                                    color: luma.textPrimary, fontSize: 32, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            LumaPrimaryButton(
                              label: 'Add record',
                              icon: Icons.add_rounded,
                              expand: true,
                              onTap: () => subjects.isEmpty
                                  ? showSubjectDialog(context, repo)
                                  : _openEditor(context, repo, subjects),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (records.length >= 2) ...[
                        Text('Trend',
                            style: TextStyle(
                                color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        LumaCard(
                          child: SizedBox(
                            height: 180,
                            child: LineChart(
                              LineChartData(
                                minY: 0,
                                maxY: 4,
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                titlesData: const FlTitlesData(
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    isCurved: true,
                                    color: luma.accent,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: false),
                                    spots: [
                                      for (var i = 0; i < records.length; i++)
                                        FlSpot(
                                          i.toDouble(),
                                          computeGpa([
                                                for (var j = 0; j <= i; j++)
                                                  GpaWeighting(
                                                      creditHours: records[j].creditHours,
                                                      gradePoints: records[j].gradePoints),
                                              ]) ??
                                              0,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: records.isEmpty
                      ? const LumaEmptyState(
                          icon: Icons.school_rounded,
                          title: 'No GPA records yet',
                          subtitle: 'Log a finished term\'s grade to start tracking your GPA.',
                        )
                      : ListView.separated(
                          itemCount: records.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final r = records[records.length - 1 - i];
                            return LumaCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(subjectById[r.subjectId]?.name ?? 'Subject',
                                            style: TextStyle(
                                                color: luma.textPrimary, fontWeight: FontWeight.w600)),
                                        Text(
                                          '${r.termName} · ${r.creditHours.toStringAsFixed(1)} credits · ${r.gradePoints.toStringAsFixed(2)} pts',
                                          style: TextStyle(color: luma.textMuted, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded,
                                        color: luma.textMuted, size: 20),
                                    onPressed: () => repo.deleteGpaRecord(r.id),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
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
      builder: (_) => _GpaRecordDialog(repo: repo, subjects: subjects),
    );
  }
}

class _GpaRecordDialog extends StatefulWidget {
  const _GpaRecordDialog({required this.repo, required this.subjects});
  final SchoolRepository repo;
  final List<SchoolSubject> subjects;

  @override
  State<_GpaRecordDialog> createState() => _GpaRecordDialogState();
}

class _GpaRecordDialogState extends State<_GpaRecordDialog> {
  late int _subjectId = widget.subjects.first.id;
  final _termController = TextEditingController();
  final _creditsController = TextEditingController(text: '3');
  final _percentController = TextEditingController();

  @override
  void dispose() {
    _termController.dispose();
    _creditsController.dispose();
    _percentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = double.tryParse(_percentController.text.trim());
    final points = percent == null ? null : percentTo4Point(percent);
    return AlertDialog(
      title: const Text('Add GPA record'),
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
            TextField(
              controller: _termController,
              decoration: const InputDecoration(labelText: 'Term (e.g. Fall 2026)'),
            ),
            TextField(
              controller: _creditsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Credit hours'),
            ),
            TextField(
              controller: _percentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Final percentage grade',
                helperText: points == null ? null : '= ${points.toStringAsFixed(2)} GPA points',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: points == null || _termController.text.trim().isEmpty
              ? null
              : () async {
                  await widget.repo.createGpaRecord(
                    subjectId: _subjectId,
                    termName: _termController.text.trim(),
                    creditHours: double.tryParse(_creditsController.text.trim()) ?? 3,
                    gradePoints: points,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ─── Grade projection calculator ─────────────────────────────────────────

class _GradeCalculatorSection extends StatefulWidget {
  const _GradeCalculatorSection();

  @override
  State<_GradeCalculatorSection> createState() => _GradeCalculatorSectionState();
}

class _GradeCalculatorSectionState extends State<_GradeCalculatorSection> {
  int? _subjectId;
  final _targetController = TextEditingController(text: '90');

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = SchoolScope.of(context);
    final luma = context.luma;
    return StreamData<List<SchoolSubject>>(
      stream: repo.watchSubjects(),
      builder: (context, subjects) {
        if (subjects.isEmpty) {
          return LumaEmptyState(
            icon: Icons.calculate_rounded,
            title: 'No subjects yet',
            subtitle: 'Add a subject to start weighting its grade components.',
            action: LumaPrimaryButton(
              label: 'Add subject',
              icon: Icons.add_rounded,
              onTap: () => showSubjectDialog(context, repo),
            ),
          );
        }
        _subjectId ??= subjects.first.id;
        final subjectId = subjects.any((s) => s.id == _subjectId) ? _subjectId! : subjects.first.id;

        return StreamData<List<GradeComponent>>(
          stream: repo.watchGradeComponents(subjectId),
          builder: (context, components) {
            final inputs = [
              for (final c in components)
                GradeComponentInput(
                    weightPercent: c.weightPercent, scoreTotal: c.scoreTotal, scoreEarned: c.scoreEarned),
            ];
            final current = currentGrade(inputs);
            final target = double.tryParse(_targetController.text.trim());
            final needed = target == null ? null : neededAverageOnRemaining(inputs, target);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: subjectId,
                        decoration: const InputDecoration(labelText: 'Subject'),
                        items: [
                          for (final s in subjects) DropdownMenuItem(value: s.id, child: Text(s.name)),
                        ],
                        onChanged: (v) => setState(() => _subjectId = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    LumaPrimaryButton(
                      label: 'Add component',
                      icon: Icons.add_rounded,
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => _GradeComponentDialog(repo: repo, subjectId: subjectId),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: LumaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current grade', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                            Text(
                              current.currentPercent == null
                                  ? '--'
                                  : '${current.currentPercent!.toStringAsFixed(1)}%',
                              style: TextStyle(
                                  color: luma.textPrimary, fontSize: 26, fontWeight: FontWeight.w700),
                            ),
                            Text('${current.gradedWeightPercent.toStringAsFixed(0)}% of weight graded',
                                style: TextStyle(color: luma.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LumaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Target grade %', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                            TextField(
                              controller: _targetController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                              style: TextStyle(
                                  color: luma.textPrimary, fontSize: 26, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              needed == null
                                  ? 'Add ungraded components to project'
                                  : 'Need ${needed.toStringAsFixed(1)}% on the rest',
                              style: TextStyle(color: luma.accent, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: components.isEmpty
                      ? const LumaEmptyState(
                          icon: Icons.pie_chart_outline_rounded,
                          title: 'No grade components yet',
                          subtitle: 'Add weighted components like "Midterm" or "Final".',
                        )
                      : ListView.separated(
                          itemCount: components.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final c = components[i];
                            return LumaCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name,
                                            style: TextStyle(
                                                color: luma.textPrimary, fontWeight: FontWeight.w600)),
                                        Text(
                                          '${c.weightPercent.toStringAsFixed(0)}% weight'
                                          '${c.scoreEarned != null ? ' · ${c.scoreEarned!.toStringAsFixed(1)}/${c.scoreTotal.toStringAsFixed(0)}' : ' · not graded yet'}',
                                          style: TextStyle(color: luma.textMuted, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (_) => _GradeComponentDialog(
                                          repo: repo, subjectId: subjectId, existing: c),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded,
                                        color: luma.textMuted, size: 20),
                                    onPressed: () => repo.deleteGradeComponent(c.id),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _GradeComponentDialog extends StatefulWidget {
  const _GradeComponentDialog({required this.repo, required this.subjectId, this.existing});
  final SchoolRepository repo;
  final int subjectId;
  final GradeComponent? existing;

  @override
  State<_GradeComponentDialog> createState() => _GradeComponentDialogState();
}

class _GradeComponentDialogState extends State<_GradeComponentDialog> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _weightController =
      TextEditingController(text: (widget.existing?.weightPercent ?? 10).toString());
  late final _scoreTotalController =
      TextEditingController(text: (widget.existing?.scoreTotal ?? 100).toString());
  late final _scoreEarnedController =
      TextEditingController(text: widget.existing?.scoreEarned?.toString() ?? '');

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _scoreTotalController.dispose();
    _scoreEarnedController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final weight = double.tryParse(_weightController.text.trim());
    if (name.isEmpty || weight == null) return;
    final scoreTotal = double.tryParse(_scoreTotalController.text.trim()) ?? 100;
    final scoreEarned = double.tryParse(_scoreEarnedController.text.trim());
    if (widget.existing == null) {
      await widget.repo.createGradeComponent(
        subjectId: widget.subjectId,
        name: name,
        weightPercent: weight,
        scoreTotal: scoreTotal,
        scoreEarned: scoreEarned,
      );
    } else {
      await widget.repo.updateGradeComponent(
        widget.existing!.id,
        name: name,
        weightPercent: weight,
        scoreTotal: scoreTotal,
        scoreEarned: scoreEarned,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add component' : 'Edit component'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name (e.g. Midterm)'),
            ),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Weight (%)'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _scoreEarnedController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Score earned (optional)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _scoreTotalController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Out of'),
                  ),
                ),
              ],
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
