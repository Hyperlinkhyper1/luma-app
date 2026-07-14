import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'errands_repository.dart';
import 'errands_scope.dart';

/// Accent colors offered for categories. Kept vivid so section headers stay
/// easy to scan at a glance.
const _categoryColors = <int>[
  0xFF2F80ED,
  0xFF7C5AD9,
  0xFF00B8A9,
  0xFF12A372,
  0xFFF5A623,
  0xFFE5484D,
  0xFFF25F9C,
  0xFF9B51E0,
  0xFF5D6470,
];

/// The Errand Manager plugin: recurring chores (daily / weekly / monthly /
/// every N days) rolled up into a single daily checklist, grouped by
/// user-defined categories, with snoozing for days you can't get to one.
class ErrandsPage extends StatelessWidget {
  const ErrandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ErrandsScope.of(context);
    return StreamData<List<ErrandCategoryRecord>>(
      stream: repo.watchCategories(),
      builder: (context, categories) {
        return StreamData<List<ErrandRecord>>(
          stream: repo.watchErrands(),
          builder: (context, errands) =>
              _ErrandsBody(categories: categories, errands: errands),
        );
      },
    );
  }
}

class _ErrandsBody extends StatelessWidget {
  const _ErrandsBody({required this.categories, required this.errands});
  final List<ErrandCategoryRecord> categories;
  final List<ErrandRecord> errands;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ErrandsScope.of(context);
    final today = DateTime.now();

    final doneToday =
        errands.where((e) => e.wasDoneOn(today)).toList(growable: false);
    final dueToday = errands
        .where((e) => e.isDueOn(today) && !e.wasDoneOn(today))
        .toList(growable: false);
    final upcoming = errands
        .where((e) => !e.isDueOn(today) && !e.wasDoneOn(today))
        .toList(growable: false);

    final totalToday = dueToday.length + doneToday.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderCard(
                today: today,
                done: doneToday.length,
                total: totalToday,
                onAdd: () => _showErrandEditor(context, repo, categories),
                onManageCategories: () =>
                    _showCategoryManager(context, repo, categories),
              ),
              const SizedBox(height: 24),
              if (errands.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: LumaEmptyState(
                    icon: Icons.checklist_rounded,
                    title: 'No errands yet',
                    subtitle:
                        'Add a recurring errand — daily, weekly, monthly or '
                        'every few days — and it shows up on your checklist '
                        'the day it\'s due.',
                    action: LumaPrimaryButton(
                      label: 'Add errand',
                      icon: Icons.add_rounded,
                      onTap: () => _showErrandEditor(context, repo, categories),
                    ),
                  ),
                )
              else ...[
                if (dueToday.isEmpty && doneToday.isNotEmpty)
                  LumaCard(
                    child: Row(
                      children: [
                        Icon(Icons.celebration_rounded,
                            color: luma.accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'All done for today — nice work.',
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (dueToday.isEmpty && doneToday.isEmpty)
                  LumaCard(
                    child: Row(
                      children: [
                        Icon(Icons.event_available_rounded,
                            color: luma.textMuted, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Nothing due today. Your next errands are listed '
                            'under Coming up.',
                            style: TextStyle(
                                color: luma.textSecondary, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ..._buildTodaySections(context, repo, dueToday),
                if (doneToday.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(
                    label: 'Done today',
                    count: doneToday.length,
                  ),
                  const SizedBox(height: 8),
                  LumaCard(
                    child: Column(
                      children: [
                        for (final e in doneToday)
                          _ErrandRow(
                            errand: e,
                            categories: categories,
                            checked: true,
                            onToggle: () => repo.uncomplete(e),
                            onTap: () => _showErrandEditor(
                                context, repo, categories, existing: e),
                          ),
                      ],
                    ),
                  ),
                ],
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(label: 'Coming up', count: upcoming.length),
                  const SizedBox(height: 8),
                  LumaCard(
                    child: Column(
                      children: [
                        for (final e in upcoming)
                          _ErrandRow(
                            errand: e,
                            categories: categories,
                            checked: false,
                            upcoming: true,
                            onToggle: () => repo.complete(e),
                            onSnooze: (days) => repo.snooze(e, days),
                            onTap: () => _showErrandEditor(
                                context, repo, categories, existing: e),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The due-today checklist, one card per category (uncategorized last).
  List<Widget> _buildTodaySections(
    BuildContext context,
    ErrandsRepository repo,
    List<ErrandRecord> dueToday,
  ) {
    if (dueToday.isEmpty) return const [];
    final byCategory = <int?, List<ErrandRecord>>{};
    for (final e in dueToday) {
      byCategory.putIfAbsent(e.categoryId, () => []).add(e);
    }
    final knownIds = categories.map((c) => c.id).toSet();

    final sections = <Widget>[];
    void addSection(String label, int? color, List<ErrandRecord> items) {
      sections.addAll([
        const SizedBox(height: 20),
        _SectionHeader(label: label, count: items.length, color: color),
        const SizedBox(height: 8),
        LumaCard(
          child: Column(
            children: [
              for (final e in items)
                _ErrandRow(
                  errand: e,
                  categories: categories,
                  checked: false,
                  onToggle: () => repo.complete(e),
                  onSnooze: (days) => repo.snooze(e, days),
                  onTap: () => _showErrandEditor(context, repo, categories,
                      existing: e),
                ),
            ],
          ),
        ),
      ]);
    }

    for (final cat in categories) {
      final items = byCategory[cat.id];
      if (items != null) addSection(cat.name, cat.color, items);
    }
    final uncategorized = [
      for (final entry in byCategory.entries)
        if (entry.key == null || !knownIds.contains(entry.key))
          ...entry.value,
    ];
    if (uncategorized.isNotEmpty) {
      addSection('Other', null, uncategorized);
    }
    return sections;
  }
}

/// "Today" header: date, progress bar, and the add / manage actions.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.today,
    required this.done,
    required this.total,
    required this.onAdd,
    required this.onManageCategories,
  });

  final DateTime today;
  final int done;
  final int total;
  final VoidCallback onAdd;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final progress = total == 0 ? 0.0 : done / total;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s errands',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatFullDate(today),
                      style: TextStyle(color: luma.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              LumaGhostButton(
                label: 'Categories',
                icon: Icons.category_rounded,
                onTap: onManageCategories,
              ),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: 'Add errand',
                icon: Icons.add_rounded,
                onTap: onAdd,
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: luma.background,
                      valueColor: AlwaysStoppedAnimation(luma.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$done of $total done',
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count, this.color});
  final String label;
  final int count;
  final int? color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: Color(color!), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(color: luma.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// One checklist line: check circle, name + schedule, overdue / due chip and
/// a snooze menu. [upcoming] rows show their due date instead of an overdue
/// warning.
class _ErrandRow extends StatelessWidget {
  const _ErrandRow({
    required this.errand,
    required this.categories,
    required this.checked,
    required this.onToggle,
    required this.onTap,
    this.onSnooze,
    this.upcoming = false,
  });

  final ErrandRecord errand;
  final List<ErrandCategoryRecord> categories;
  final bool checked;
  final bool upcoming;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final ValueChanged<int>? onSnooze;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final today = DateTime.now();
    final overdue = errand.overdueDays(today);

    final subtitleParts = <String>[
      errand.repeatLabel,
      if (upcoming) _formatDueIn(errand.nextDue, today),
      if (upcoming) _categoryName() ?? '',
    ]..removeWhere((s) => s.isEmpty);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            _CheckCircle(checked: checked, onTap: onToggle),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    errand.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: checked ? luma.textMuted : luma.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (!checked && !upcoming && overdue > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: luma.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  overdue == 1 ? '1 day late' : '$overdue days late',
                  style: TextStyle(
                    color: luma.danger,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (onSnooze != null) ...[
              const SizedBox(width: 4),
              _SnoozeButton(onSnooze: onSnooze!),
            ],
          ],
        ),
      ),
    );
  }

  String? _categoryName() {
    for (final c in categories) {
      if (c.id == errand.categoryId) return c.name;
    }
    return null;
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.checked, required this.onTap});
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: checked ? luma.accent : Colors.transparent,
            border: Border.all(
              color: checked ? luma.accent : luma.border,
              width: 2,
            ),
          ),
          child: checked
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// "Can't do it today" menu: push the errand forward by a preset number of
/// days or a custom amount.
class _SnoozeButton extends StatelessWidget {
  const _SnoozeButton({required this.onSnooze});
  final ValueChanged<int> onSnooze;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return PopupMenuButton<int>(
      tooltip: 'Delay',
      icon: Icon(Icons.snooze_rounded, size: 18, color: luma.textMuted),
      color: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (days) async {
        if (days == -1) {
          final custom = await _askCustomDays(context);
          if (custom != null && custom > 0) onSnooze(custom);
        } else {
          onSnooze(days);
        }
      },
      itemBuilder: (context) => [
        for (final (days, label) in const [
          (1, 'Tomorrow'),
          (2, 'In 2 days'),
          (3, 'In 3 days'),
          (7, 'In a week'),
          (-1, 'Custom…'),
        ])
          PopupMenuItem(
            value: days,
            height: 40,
            child: Text(label,
                style: TextStyle(color: luma.textPrimary, fontSize: 13.5)),
          ),
      ],
    );
  }
}

Future<int?> _askCustomDays(BuildContext context) {
  final luma = context.luma;
  final controller = TextEditingController();
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: luma.surface,
      title: Text('Delay by how many days?',
          style: TextStyle(color: luma.textPrimary, fontSize: 16)),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: TextStyle(color: luma.textPrimary),
        decoration: _dec(luma, hint: 'e.g. 5'),
        onSubmitted: (v) => Navigator.of(ctx).pop(int.tryParse(v.trim())),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(ctx).pop(int.tryParse(controller.text.trim())),
          child: Text('Delay', style: TextStyle(color: luma.accent)),
        ),
      ],
    ),
  );
}

// ---- Errand editor ---------------------------------------------------------

/// The four schedule presets offered in the editor; Custom exposes the
/// "every N days" field.
enum _RepeatChoice { daily, weekly, monthly, custom }

void _showErrandEditor(
  BuildContext context,
  ErrandsRepository repo,
  List<ErrandCategoryRecord> categories, {
  ErrandRecord? existing,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _ErrandEditorDialog(
      repo: repo,
      categories: categories,
      existing: existing,
    ),
  );
}

class _ErrandEditorDialog extends StatefulWidget {
  const _ErrandEditorDialog({
    required this.repo,
    required this.categories,
    this.existing,
  });

  final ErrandsRepository repo;
  final List<ErrandCategoryRecord> categories;
  final ErrandRecord? existing;

  @override
  State<_ErrandEditorDialog> createState() => _ErrandEditorDialogState();
}

class _ErrandEditorDialogState extends State<_ErrandEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late final TextEditingController _customDays;
  late _RepeatChoice _repeat;
  late DateTime _firstDue;
  int? _categoryId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _repeat = switch ((e?.repeatUnit, e?.repeatEvery)) {
      (null, _) => _RepeatChoice.daily,
      (RepeatUnit.days, 1) => _RepeatChoice.daily,
      (RepeatUnit.weeks, 1) => _RepeatChoice.weekly,
      (RepeatUnit.months, 1) => _RepeatChoice.monthly,
      _ => _RepeatChoice.custom,
    };
    // Custom repeats are stored as plain day counts; weeks/months custom
    // multiples round-trip through days for editing simplicity.
    final everyDays = switch (e?.repeatUnit) {
      RepeatUnit.weeks => (e?.repeatEvery ?? 1) * 7,
      RepeatUnit.months => (e?.repeatEvery ?? 1) * 30,
      _ => e?.repeatEvery ?? 2,
    };
    _customDays = TextEditingController(text: '$everyDays');
    _firstDue = e != null ? dateOnly(e.nextDue) : dateOnly(DateTime.now());
    // Guard against a category that was deleted since the errand was made.
    final catIds = widget.categories.map((c) => c.id).toSet();
    _categoryId =
        e?.categoryId != null && catIds.contains(e!.categoryId) ? e.categoryId : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _customDays.dispose();
    super.dispose();
  }

  (RepeatUnit, int)? _schedule() {
    switch (_repeat) {
      case _RepeatChoice.daily:
        return (RepeatUnit.days, 1);
      case _RepeatChoice.weekly:
        return (RepeatUnit.weeks, 1);
      case _RepeatChoice.monthly:
        return (RepeatUnit.months, 1);
      case _RepeatChoice.custom:
        final n = int.tryParse(_customDays.text.trim());
        if (n == null || n < 1 || n > 365) return null;
        return (RepeatUnit.days, n);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the errand a name.');
      return;
    }
    final schedule = _schedule();
    if (schedule == null) {
      setState(() => _error = 'Enter a repeat interval between 1 and 365 days.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final notes = _notes.text.trim();
    try {
      if (widget.existing == null) {
        await widget.repo.addErrand(
          name: name,
          repeatUnit: schedule.$1,
          repeatEvery: schedule.$2,
          firstDue: _firstDue,
          categoryId: _categoryId,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await widget.repo.updateErrand(
          widget.existing!.id,
          name: name,
          repeatUnit: schedule.$1,
          repeatEvery: schedule.$2,
          nextDue: _firstDue,
          categoryId: _categoryId,
          notes: notes.isEmpty ? null : notes,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the errand. ($e)';
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await _confirmDelete(context);
    if (!confirmed || !mounted) return;
    await widget.repo.deleteErrand(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickFirstDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDue,
      firstDate: dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _firstDue = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final editing = widget.existing != null;
    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editing ? 'Edit errand' : 'Add errand',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _label(luma, 'Name'),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                autofocus: !editing,
                style: TextStyle(color: luma.textPrimary),
                decoration: _dec(luma, hint: 'Water the plants'),
              ),
              const SizedBox(height: 14),
              _label(luma, 'Repeats'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (choice, label) in const [
                    (_RepeatChoice.daily, 'Daily'),
                    (_RepeatChoice.weekly, 'Weekly'),
                    (_RepeatChoice.monthly, 'Monthly'),
                    (_RepeatChoice.custom, 'Custom'),
                  ])
                    _ChoiceChip(
                      label: label,
                      selected: _repeat == choice,
                      onTap: () => setState(() {
                        _repeat = choice;
                        _error = null;
                      }),
                    ),
                ],
              ),
              if (_repeat == _RepeatChoice.custom) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Every',
                        style:
                            TextStyle(color: luma.textSecondary, fontSize: 13)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: _customDays,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: luma.textPrimary),
                        decoration: _dec(luma),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('days',
                        style:
                            TextStyle(color: luma.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              _label(luma, 'Category'),
              const SizedBox(height: 6),
              _CategoryDropdown(
                categories: widget.categories,
                value: _categoryId,
                onChanged: (id) => setState(() => _categoryId = id),
              ),
              const SizedBox(height: 14),
              _label(luma, editing ? 'Next due' : 'First due'),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickFirstDue,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: luma.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: luma.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_rounded,
                          size: 16, color: luma.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        _formatFullDate(_firstDue),
                        style:
                            TextStyle(color: luma.textPrimary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _label(luma, 'Notes (optional)'),
              const SizedBox(height: 6),
              TextField(
                controller: _notes,
                style: TextStyle(color: luma.textPrimary),
                maxLines: 2,
                decoration:
                    _dec(luma, hint: 'Which plants, which store, anything handy'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: luma.danger, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  if (editing)
                    IconButton(
                      tooltip: 'Delete',
                      icon: Icon(Icons.delete_outline_rounded,
                          color: luma.textMuted),
                      onPressed: _delete,
                    ),
                  const Spacer(),
                  LumaGhostButton(
                    label: 'Cancel',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  LumaPrimaryButton(
                    label: editing ? 'Save' : 'Add errand',
                    loading: _saving,
                    onTap: _save,
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

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? luma.accent.withValues(alpha: 0.15)
                : luma.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? luma.accent : luma.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? luma.accent : luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final List<ErrandCategoryRecord> categories;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          // Sentinel -1 = "no category"; DropdownButton can't use null as an
          // item value and also show a hint.
          value: value ?? -1,
          isExpanded: true,
          dropdownColor: luma.surface,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(Icons.expand_more_rounded, color: luma.textSecondary),
          style: TextStyle(color: luma.textPrimary, fontSize: 14),
          items: [
            DropdownMenuItem(
              value: -1,
              child: Text('No category',
                  style: TextStyle(color: luma.textMuted)),
            ),
            for (final c in categories)
              DropdownMenuItem(
                value: c.id,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: Color(c.color), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Text(c.name),
                  ],
                ),
              ),
          ],
          onChanged: (id) => onChanged(id == -1 ? null : id),
        ),
      ),
    );
  }
}

// ---- Category manager ------------------------------------------------------

void _showCategoryManager(
  BuildContext context,
  ErrandsRepository repo,
  List<ErrandCategoryRecord> categories,
) {
  showDialog<void>(
    context: context,
    builder: (_) => _CategoryManagerDialog(repo: repo),
  );
}

class _CategoryManagerDialog extends StatelessWidget {
  const _CategoryManagerDialog({required this.repo});
  final ErrandsRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Categories',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Group your checklist however you like — Household, Health, '
                'Admin… Deleting a category keeps its errands.',
                style: TextStyle(color: luma.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              StreamData<List<ErrandCategoryRecord>>(
                stream: repo.watchCategories(),
                builder: (context, categories) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (categories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No categories yet.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: luma.textMuted, fontSize: 13),
                        ),
                      ),
                    for (final c in categories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Color(c.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                c.name,
                                style: TextStyle(
                                    color: luma.textPrimary, fontSize: 14),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              icon: Icon(Icons.edit_rounded,
                                  size: 16, color: luma.textMuted),
                              onPressed: () =>
                                  _showCategoryEditor(context, repo,
                                      existing: c),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: Icon(Icons.delete_outline_rounded,
                                  size: 16, color: luma.textMuted),
                              onPressed: () async {
                                final confirmed =
                                    await _confirmDeleteCategory(context);
                                if (confirmed) await repo.deleteCategory(c.id);
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  LumaGhostButton(
                    label: 'New category',
                    icon: Icons.add_rounded,
                    onTap: () => _showCategoryEditor(context, repo),
                  ),
                  const Spacer(),
                  LumaPrimaryButton(
                    label: 'Done',
                    onTap: () => Navigator.of(context).pop(),
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

void _showCategoryEditor(
  BuildContext context,
  ErrandsRepository repo, {
  ErrandCategoryRecord? existing,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _CategoryEditorDialog(repo: repo, existing: existing),
  );
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({required this.repo, this.existing});
  final ErrandsRepository repo;
  final ErrandCategoryRecord? existing;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final TextEditingController _name;
  late int _color;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.existing?.color ?? _categoryColors.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the category a name.');
      return;
    }
    if (widget.existing == null) {
      await widget.repo.addCategory(name: name, color: _color);
    } else {
      await widget.repo
          .updateCategory(widget.existing!.id, name: name, color: _color);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final editing = widget.existing != null;
    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editing ? 'Edit category' : 'New category',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _label(luma, 'Name'),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                autofocus: true,
                style: TextStyle(color: luma.textPrimary),
                decoration: _dec(luma, hint: 'Household'),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 14),
              _label(luma, 'Color'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in _categoryColors)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c == _color
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: c == _color
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 16)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: luma.danger, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  LumaGhostButton(
                    label: 'Cancel',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  LumaPrimaryButton(
                    label: editing ? 'Save' : 'Add',
                    onTap: _save,
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

// ---- Shared bits -----------------------------------------------------------

Widget _label(LumaPalette luma, String text) => Text(
      text,
      style: TextStyle(
        color: luma.textSecondary,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );

InputDecoration _dec(LumaPalette luma, {String? hint}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
    filled: true,
    fillColor: luma.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: border(luma.border),
    focusedBorder: border(luma.accent),
  );
}

Future<bool> _confirmDelete(BuildContext context) async {
  final luma = context.luma;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: luma.surface,
      title:
          Text('Delete errand?', style: TextStyle(color: luma.textPrimary)),
      content: Text(
        'This removes the errand and its schedule from this device.',
        style: TextStyle(color: luma.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('Delete', style: TextStyle(color: luma.danger)),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> _confirmDeleteCategory(BuildContext context) async {
  final luma = context.luma;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: luma.surface,
      title: Text('Delete category?',
          style: TextStyle(color: luma.textPrimary)),
      content: Text(
        'Errands in this category are kept and become uncategorized.',
        style: TextStyle(color: luma.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('Delete', style: TextStyle(color: luma.danger)),
        ),
      ],
    ),
  );
  return result ?? false;
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _formatFullDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

/// "Due tomorrow", "Due in 3 days", or "Due Mon, 3 August" further out.
String _formatDueIn(DateTime due, DateTime today) {
  final days = dateOnly(due).difference(dateOnly(today)).inDays;
  if (days <= 1) return 'Due tomorrow';
  if (days <= 14) return 'Due in $days days';
  return 'Due ${_weekdays[due.weekday - 1]}, ${due.day} ${_months[due.month - 1]}';
}
