import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

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
                label: 'Add entry',
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
            subtitle: 'Log your mood to start tracking your patterns.',
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
              padding: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _MoodJournalPageState._openEditor(
                  context,
                  repo,
                  date: entry.date,
                  existing: entry,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                            if (entry.images.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 80,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: entry.images.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                                  itemBuilder: (context, idx) => ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(entry.images[idx]),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (entry.tags.isNotEmpty) ...[
                              const SizedBox(height: 10),
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
    return StreamData<Map<String, List<MoodEntryRecord>>>(
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
                  final dayEntries = entries[key] ?? [];
                  
                  Color bg = luma.surface;
                  if (dayEntries.isNotEmpty) {
                    final avgMood = dayEntries.map((e) => e.mood).reduce((a, b) => a + b) / dayEntries.length;
                    final moodInfo = _kMoods[avgMood.round()]!;
                    bg = moodInfo.colorOf(luma).withValues(alpha: 0.24);
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showDayOptions(context, key, dayEntries),
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
                          if (dayEntries.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var j = 0; j < dayEntries.length.clamp(0, 3); j++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 1),
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: _kMoods[dayEntries[j].mood]!.colorOf(luma),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                if (dayEntries.length > 3)
                                   Text('+', style: TextStyle(color: luma.textMuted, fontSize: 8)),
                              ],
                            ),
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

  void _showDayOptions(BuildContext context, String date, List<MoodEntryRecord> dayEntries) {
    final luma = context.luma;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, d MMM').format(DateTime.parse(date)),
                        style: TextStyle(color: luma.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              if (dayEntries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('No entries for this day'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: dayEntries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = dayEntries[i];
                      final mood = _kMoods[e.mood]!;
                      return LumaCard(
                        padding: const EdgeInsets.all(12),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _MoodJournalPageState._openEditor(context, widget.repo, date: date, existing: e);
                          },
                          child: Row(
                            children: [
                              Text(mood.emoji, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  e.note ?? mood.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: luma.textPrimary, fontSize: 13),
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: luma.textMuted, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: LumaPrimaryButton(
                  label: 'Add new entry',
                  expand: true,
                  onTap: () {
                    Navigator.pop(context);
                    _MoodJournalPageState._openEditor(context, widget.repo, date: date);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
  late final List<String> _images = [...(widget.existing?.images ?? const [])];
  late final TextEditingController _tagInput = TextEditingController();
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _note.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _images.add(result.files.single.path!));
    }
  }

  void _addTag() {
    final tag = _tagInput.text.trim();
    if (tag.isNotEmpty) {
      setState(() {
        _tags.add(tag);
        _tagInput.clear();
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.repo.save(
      id: widget.existing?.id,
      date: widget.date,
      mood: _mood,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      tags: _tags.toList(),
      images: _images,
    );
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
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
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
                    _label(luma, 'How are you feeling?'),
                    const SizedBox(height: 12),
                    _moodRow(luma),
                    const SizedBox(height: 24),
                    _label(luma, 'Journal entry'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _note,
                      maxLines: 4,
                      style: TextStyle(color: luma.textPrimary, fontSize: 14),
                      decoration: _decoration(luma, hint: 'What\'s on your mind?'),
                    ),
                    const SizedBox(height: 24),
                    _label(luma, 'Photos'),
                    const SizedBox(height: 12),
                    _imageGrid(luma),
                    const SizedBox(height: 24),
                    _label(luma, 'Tags'),
                    const SizedBox(height: 12),
                    _tagsSection(luma),
                    const SizedBox(height: 16),
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
              _isEditing ? 'Edit entry' : 'New entry',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 17,
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

  Widget _imageGrid(LumaPalette luma) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _images.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(_images[i]),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: () => setState(() => _images.removeAt(i)),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
        InkWell(
          onTap: _pickImage,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: luma.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: luma.border, style: BorderStyle.solid),
            ),
            child: Icon(Icons.add_photo_alternate_outlined, color: luma.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _tagsSection(LumaPalette luma) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in _kMoodTags)
              _TagChip(
                label: tag,
                selected: _tags.contains(tag),
                onTap: () => setState(() => _tags.contains(tag) ? _tags.remove(tag) : _tags.add(tag)),
                luma: luma,
              ),
            for (final tag in _tags.where((t) => !_kMoodTags.contains(t)))
              _TagChip(
                label: tag,
                selected: true,
                onTap: () => setState(() => _tags.remove(tag)),
                luma: luma,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagInput,
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
                decoration: _decoration(luma, hint: 'Add custom tag...'),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            LumaGhostButton(
              label: 'Add',
              onTap: _addTag,
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(LumaPalette luma, String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: luma.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _decoration(LumaPalette luma, {String? hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 18, color: luma.textMuted) : null,
      hintStyle: TextStyle(color: luma.textMuted, fontSize: 14),
      filled: true,
      fillColor: luma.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: luma.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: luma.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: luma.accent)),
    );
  }

  Widget _footer(LumaPalette luma) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: luma.danger),
              onPressed: () async {
                await widget.repo.delete(widget.existing!.id);
                if (mounted) Navigator.pop(context);
              },
            ),
          const Spacer(),
          LumaGhostButton(
            label: 'Cancel',
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          LumaPrimaryButton(
            label: _isEditing ? 'Save changes' : 'Save entry',
            loading: _saving,
            onTap: _save,
          ),
        ],
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.transparent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: selected ? color : Colors.transparent, fontSize: 10, fontWeight: FontWeight.bold)),
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
    required this.luma,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? luma.accent : luma.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? luma.accent : luma.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? luma.onAccent : luma.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
