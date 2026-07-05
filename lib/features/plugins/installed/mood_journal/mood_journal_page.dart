import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'mood_journal_repository.dart';
import 'mood_journal_scope.dart';

const _kMoodTags = ['Work', 'Sleep', 'Exercise', 'Social', 'Health', 'Other'];

class _MoodInfo {
  const _MoodInfo(this.emoji, this.label, this.colorOf);
  final String emoji;
  final String label;
  final Color Function(LumaPalette luma) colorOf;
}

const Map<int, _MoodInfo> _kMoods = {
  1: _MoodInfo('😞', 'Terrible', _dangerColor),
  2: _MoodInfo('🙁', 'Bad', _orangeColor),
  3: _MoodInfo('😐', 'Okay', _amberColor),
  4: _MoodInfo('🙂', 'Good', _successColor),
  5: _MoodInfo('😄', 'Great', _accentColor),
};

Color _dangerColor(LumaPalette luma) => luma.danger;
Color _orangeColor(LumaPalette luma) => const Color(0xFFE8A33D);
Color _amberColor(LumaPalette luma) => const Color(0xFFE8D23D);
Color _successColor(LumaPalette luma) => luma.success;
Color _accentColor(LumaPalette luma) => luma.accent;

class MoodJournalPage extends StatefulWidget {
  const MoodJournalPage({super.key});

  @override
  State<MoodJournalPage> createState() => _MoodJournalPageState();
}

class _MoodJournalPageState extends State<MoodJournalPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final repo = MoodJournalScope.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LumaSegmentedTabs(
                tabs: const ['Journal', 'Calendar'],
                selectedIndex: _tab,
                onSelect: (i) => setState(() => _tab = i),
              ),
              const Spacer(),
              LumaPrimaryButton(
                label: 'Log today',
                icon: Icons.add_rounded,
                onTap: () => _openEditor(context, repo),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _tab == 0
                ? _JournalList(repo: repo)
                : _CalendarHeatmap(repo: repo),
          ),
        ],
      ),
    );
  }

  static void _openEditor(BuildContext context, MoodJournalRepository repo,
      {String? date, MoodEntryRecord? existing}) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _MoodEditorDialog(
        repo: repo,
        date: date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
        existing: existing,
      ),
    );
  }
}

class _JournalList extends StatelessWidget {
  const _JournalList({required this.repo});
  final MoodJournalRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return StreamData<List<MoodEntryRecord>>(
      stream: repo.watchAll(),
      builder: (context, entries) {
        if (entries.isEmpty) {
          return const LumaEmptyState(
            icon: Icons.mood_rounded,
            title: 'No entries yet',
            subtitle: 'Log today\'s mood to start tracking your patterns.',
          );
        }
        return ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final entry = entries[i];
            final mood = _kMoods[entry.mood]!;
            final color = mood.colorOf(luma);
            return LumaCard(
              child: InkWell(
                onTap: () => _MoodJournalPageState._openEditor(
                  context,
                  repo,
                  date: entry.date,
                  existing: entry,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(mood.emoji, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                DateFormat('EEEE, d MMMM yyyy')
                                    .format(DateTime.parse(entry.date)),
                                style: TextStyle(
                                  color: luma.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                mood.label,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (entry.note != null && entry.note!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              entry.note!,
                              style: TextStyle(
                                  color: luma.textSecondary, fontSize: 13),
                            ),
                          ],
                          if (entry.tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final tag in entry.tags)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: luma.accentSubtle,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        color: luma.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          color: luma.textMuted, size: 18),
                      onPressed: () => repo.delete(entry.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CalendarHeatmap extends StatefulWidget {
  const _CalendarHeatmap({required this.repo});
  final MoodJournalRepository repo;

  @override
  State<_CalendarHeatmap> createState() => _CalendarHeatmapState();
}

class _CalendarHeatmapState extends State<_CalendarHeatmap> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return StreamData<Map<String, MoodEntryRecord>>(
      stream: widget.repo.watchByMonth(_month.year, _month.month),
      builder: (context, entries) {
        final firstOfMonth = DateTime(_month.year, _month.month, 1);
        final daysInMonth =
            DateTime(_month.year, _month.month + 1, 0).day;
        final leadingBlanks = firstOfMonth.weekday % 7;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded, color: luma.textSecondary),
                  onPressed: () => _shift(-1),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_month),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded, color: luma.textSecondary),
                  onPressed: () => _shift(1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                            color: luma.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: leadingBlanks + daysInMonth,
                itemBuilder: (context, i) {
                  if (i < leadingBlanks) return const SizedBox.shrink();
                  final day = i - leadingBlanks + 1;
                  final date = DateTime(_month.year, _month.month, day);
                  final key = DateFormat('yyyy-MM-dd').format(date);
                  final entry = entries[key];
                  final mood = entry == null ? null : _kMoods[entry.mood];
                  final bg = mood == null
                      ? luma.surface
                      : mood.colorOf(luma).withValues(alpha: 0.24);
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _MoodJournalPageState._openEditor(
                      context,
                      widget.repo,
                      date: key,
                      existing: entry,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: luma.border),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$day',
                              style: TextStyle(
                                  color: luma.textSecondary, fontSize: 11)),
                          if (mood != null)
                            Text(mood.emoji,
                                style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MoodEditorDialog extends StatefulWidget {
  const _MoodEditorDialog({
    required this.repo,
    required this.date,
    this.existing,
  });

  final MoodJournalRepository repo;
  final String date;
  final MoodEntryRecord? existing;

  @override
  State<_MoodEditorDialog> createState() => _MoodEditorDialogState();
}

class _MoodEditorDialogState extends State<_MoodEditorDialog> {
  late int _mood = widget.existing?.mood ?? 3;
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');
  late final Set<String> _tags = {...(widget.existing?.tags ?? const [])};
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.repo.upsert(
      date: widget.date,
      mood: _mood,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      tags: _tags.toList(),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await widget.repo.delete(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Dialog(
      backgroundColor: luma.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(luma),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(luma, 'Mood'),
                    const SizedBox(height: 8),
                    _moodRow(luma),
                    const SizedBox(height: 18),
                    _label(luma, 'Tags'),
                    const SizedBox(height: 8),
                    _tagsRow(luma),
                    const SizedBox(height: 18),
                    _label(luma, 'Journal entry'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _note,
                      maxLines: 5,
                      style: TextStyle(color: luma.textPrimary, fontSize: 14),
                      decoration: _decoration(luma, hint: 'How was your day?'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _footer(luma),
          ],
        ),
      ),
    );
  }

  Widget _header(LumaPalette luma) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('EEEE, d MMMM yyyy').format(DateTime.parse(widget.date)),
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: luma.textMuted, size: 20),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _moodRow(LumaPalette luma) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final entry in _kMoods.entries)
          _MoodDot(
            emoji: entry.value.emoji,
            label: entry.value.label,
            color: entry.value.colorOf(luma),
            selected: _mood == entry.key,
            onTap: () => setState(() => _mood = entry.key),
          ),
      ],
    );
  }

  Widget _tagsRow(LumaPalette luma) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in _kMoodTags)
          _TagChip(
            label: tag,
            selected: _tags.contains(tag),
            onTap: () => setState(
              () => _tags.contains(tag) ? _tags.remove(tag) : _tags.add(tag),
            ),
          ),
      ],
    );
  }

  Widget _footer(LumaPalette luma) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: luma.border)),
      ),
      child: Row(
        children: [
          if (_isEditing)
            Tooltip(
              message: 'Delete entry',
              child: IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: luma.danger),
                onPressed: _delete,
              ),
            ),
          const Spacer(),
          LumaGhostButton(
            label: 'Cancel',
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          LumaPrimaryButton(
            label: _isEditing ? 'Save' : 'Add entry',
            icon: Icons.check_rounded,
            loading: _saving,
            onTap: _save,
          ),
        ],
      ),
    );
  }

  Widget _label(LumaPalette luma, String text) => Text(
        text,
        style: TextStyle(
            color: luma.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2),
      );

  InputDecoration _decoration(LumaPalette luma, {String? hint}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c),
        );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(color: luma.textMuted, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: luma.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: border(luma.border),
      focusedBorder: border(luma.accent),
    );
  }
}

class _MoodDot extends StatelessWidget {
  const _MoodDot({
    required this.emoji,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.24) : luma.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : luma.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : luma.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : luma.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? luma.accent : luma.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? luma.accent : luma.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
