import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'calendar_repository.dart';

/// The palette offered for event colors. First entry is the lavender default.
const List<int> kEventColors = [
  0xFF7C5AD9, // lavender
  0xFF4C8DFF, // blue
  0xFF12A372, // green
  0xFFE8A33D, // amber
  0xFFE5484D, // red
  0xFF16A5A5, // teal
  0xFFE93D82, // pink
  0xFF8E4EC6, // purple
];

/// Reminder presets, in minutes-before-start. `null` value = no reminder.
const List<({String label, int? minutes})> _reminderOptions = [
  (label: 'No reminder', minutes: null),
  (label: 'At start time', minutes: 0),
  (label: '5 minutes before', minutes: 5),
  (label: '10 minutes before', minutes: 10),
  (label: '30 minutes before', minutes: 30),
  (label: '1 hour before', minutes: 60),
  (label: '1 day before', minutes: 1440),
];

/// Opens the create/edit sheet. Pass [existing] to edit, or [initialDate] to
/// pre-fill a new event on a specific day.
Future<void> showEventEditor(
  BuildContext context,
  CalendarRepository repo, {
  EventRecord? existing,
  DateTime? initialDate,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _EventEditorDialog(
      repo: repo,
      existing: existing,
      initialDate: initialDate,
    ),
  );
}

class _EventEditorDialog extends StatefulWidget {
  const _EventEditorDialog({
    required this.repo,
    this.existing,
    this.initialDate,
  });

  final CalendarRepository repo;
  final EventRecord? existing;
  final DateTime? initialDate;

  @override
  State<_EventEditorDialog> createState() => _EventEditorDialogState();
}

class _EventEditorDialogState extends State<_EventEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _notes;

  late DateTime _start;
  late DateTime _end;
  late bool _allDay;
  late int _color;
  late Recurrence _recurrence;
  DateTime? _recurrenceEnd;
  int? _reminderMinutes;
  String? _error;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final base = widget.initialDate ?? DateTime.now();
    final defaultStart = e?.start ??
        DateTime(base.year, base.month, base.day, _roundHour(base), 0);

    _title = TextEditingController(text: e?.title ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _notes = TextEditingController(text: e?.description ?? '');
    _start = defaultStart;
    _end = e?.end ?? defaultStart.add(const Duration(hours: 1));
    _allDay = e?.allDay ?? false;
    _color = e?.color ?? kEventColors.first;
    _recurrence = e?.recurrence ?? Recurrence.none;
    _recurrenceEnd = e?.recurrenceEnd;
    _reminderMinutes = e?.reminderMinutes;
  }

  static int _roundHour(DateTime now) => (now.hour + 1).clamp(0, 23);

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      final merged = DateTime(
          picked.year, picked.month, picked.day, current.hour, current.minute);
      if (isStart) {
        // Shift the end by the same amount so the event keeps its duration.
        final delta = merged.difference(_start);
        _start = merged;
        _end = _end.add(delta);
        if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 1));
      } else {
        _end = merged;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;
    setState(() {
      final merged = DateTime(
          current.year, current.month, current.day, picked.hour, picked.minute);
      if (isStart) {
        _start = merged;
        if (_end.isBefore(_start)) _end = _start.add(const Duration(hours: 1));
      } else {
        _end = merged;
      }
    });
  }

  Future<void> _pickRecurrenceEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEnd ?? _start.add(const Duration(days: 30)),
      firstDate: _start,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _recurrenceEnd = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the event a title.');
      return;
    }
    // Normalize: an all-day event spans whole days; a timed event can't end
    // before it starts.
    var start = _start;
    var end = _end;
    if (_allDay) {
      start = DateTime(start.year, start.month, start.day);
      end = DateTime(end.year, end.month, end.day, 23, 59);
      if (end.isBefore(start)) end = DateTime(start.year, start.month, start.day, 23, 59);
    } else if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final location = _location.text.trim().isEmpty ? null : _location.text.trim();
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    final recEnd = _recurrence == Recurrence.none ? null : _recurrenceEnd;

    if (_isEditing) {
      await widget.repo.update(
        id: widget.existing!.id,
        title: title,
        description: notes,
        location: location,
        start: start,
        end: end,
        allDay: _allDay,
        color: _color,
        recurrence: _recurrence,
        recurrenceEnd: recEnd,
        reminderMinutes: _reminderMinutes,
      );
    } else {
      await widget.repo.add(
        title: title,
        description: notes,
        location: location,
        start: start,
        end: end,
        allDay: _allDay,
        color: _color,
        recurrence: _recurrence,
        recurrenceEnd: recEnd,
        reminderMinutes: _reminderMinutes,
      );
    }
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
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
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
                    _titleField(luma),
                    const SizedBox(height: 16),
                    _allDayRow(luma),
                    const SizedBox(height: 12),
                    _whenSection(luma),
                    const SizedBox(height: 18),
                    _label(luma, 'Color'),
                    const SizedBox(height: 8),
                    _colorRow(luma),
                    const SizedBox(height: 18),
                    _label(luma, 'Repeat'),
                    const SizedBox(height: 8),
                    _recurrenceRow(luma),
                    if (_recurrence != Recurrence.none) ...[
                      const SizedBox(height: 10),
                      _recurrenceEndRow(luma),
                    ],
                    const SizedBox(height: 18),
                    _label(luma, 'Reminder'),
                    const SizedBox(height: 8),
                    _reminderRow(luma),
                    const SizedBox(height: 18),
                    _label(luma, 'Location'),
                    const SizedBox(height: 8),
                    _plainField(luma, _location,
                        hint: 'Add a place', icon: Icons.place_outlined),
                    const SizedBox(height: 16),
                    _label(luma, 'Notes'),
                    const SizedBox(height: 8),
                    _plainField(luma, _notes,
                        hint: 'Add details', maxLines: 3),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(color: luma.danger, fontSize: 13)),
                    ],
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
              _isEditing ? 'Edit event' : 'New event',
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

  Widget _titleField(LumaPalette luma) {
    return TextField(
      controller: _title,
      autofocus: !_isEditing,
      style: TextStyle(
          color: luma.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      decoration: _decoration(luma, hint: 'Event title'),
      onSubmitted: (_) => _save(),
    );
  }

  Widget _allDayRow(LumaPalette luma) {
    return Row(
      children: [
        Icon(Icons.wb_sunny_outlined, size: 18, color: luma.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text('All-day',
              style: TextStyle(color: luma.textPrimary, fontSize: 14)),
        ),
        Switch(
          value: _allDay,
          activeThumbColor: luma.accent,
          onChanged: (v) => setState(() => _allDay = v),
        ),
      ],
    );
  }

  Widget _whenSection(LumaPalette luma) {
    return Column(
      children: [
        _whenRow(luma, label: 'Starts', dt: _start, isStart: true),
        const SizedBox(height: 8),
        _whenRow(luma, label: 'Ends', dt: _end, isStart: false),
      ],
    );
  }

  Widget _whenRow(LumaPalette luma,
      {required String label, required DateTime dt, required bool isStart}) {
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(label,
              style: TextStyle(color: luma.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: _pickerChip(
            luma,
            icon: Icons.event_rounded,
            text: DateFormat('EEE, d MMM yyyy').format(dt),
            onTap: () => _pickDate(isStart: isStart),
          ),
        ),
        if (!_allDay) ...[
          const SizedBox(width: 8),
          _pickerChip(
            luma,
            icon: Icons.schedule_rounded,
            text: DateFormat('HH:mm').format(dt),
            onTap: () => _pickTime(isStart: isStart),
          ),
        ],
      ],
    );
  }

  Widget _pickerChip(LumaPalette luma,
      {required IconData icon,
      required String text,
      required VoidCallback onTap}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: luma.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: luma.textSecondary),
              const SizedBox(width: 8),
              Text(text,
                  style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorRow(LumaPalette luma) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in kEventColors)
          _ColorDot(
            color: Color(c),
            selected: _color == c,
            onTap: () => setState(() => _color = c),
          ),
      ],
    );
  }

  Widget _recurrenceRow(LumaPalette luma) {
    return _dropdownShell(
      luma,
      child: DropdownButton<Recurrence>(
        value: _recurrence,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(10),
        dropdownColor: luma.surface,
        icon: Icon(Icons.expand_more_rounded, color: luma.textSecondary),
        style: TextStyle(color: luma.textPrimary, fontSize: 14),
        items: [
          for (final r in Recurrence.values)
            DropdownMenuItem(value: r, child: Text(r.label)),
        ],
        onChanged: (v) => setState(() => _recurrence = v ?? Recurrence.none),
      ),
    );
  }

  Widget _recurrenceEndRow(LumaPalette luma) {
    return Row(
      children: [
        Icon(Icons.event_repeat_rounded, size: 16, color: luma.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _recurrenceEnd == null
                ? 'Repeats forever'
                : 'Until ${DateFormat('d MMM yyyy').format(_recurrenceEnd!)}',
            style: TextStyle(color: luma.textSecondary, fontSize: 13),
          ),
        ),
        if (_recurrenceEnd != null)
          IconButton(
            icon: Icon(Icons.clear_rounded, size: 16, color: luma.textMuted),
            tooltip: 'Clear end date',
            onPressed: () => setState(() => _recurrenceEnd = null),
          ),
        LumaGhostButton(
          label: _recurrenceEnd == null ? 'Set end' : 'Change',
          onTap: _pickRecurrenceEnd,
        ),
      ],
    );
  }

  Widget _reminderRow(LumaPalette luma) {
    return _dropdownShell(
      luma,
      child: DropdownButton<int?>(
        value: _reminderMinutes,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(10),
        dropdownColor: luma.surface,
        icon: Icon(Icons.expand_more_rounded, color: luma.textSecondary),
        style: TextStyle(color: luma.textPrimary, fontSize: 14),
        items: [
          for (final o in _reminderOptions)
            DropdownMenuItem(value: o.minutes, child: Text(o.label)),
        ],
        onChanged: (v) => setState(() => _reminderMinutes = v),
      ),
    );
  }

  Widget _dropdownShell(LumaPalette luma, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  Widget _plainField(LumaPalette luma, TextEditingController controller,
      {String? hint, IconData? icon, int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: luma.textPrimary, fontSize: 14),
      decoration: _decoration(luma, hint: hint, icon: icon),
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
              message: 'Delete event',
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
            label: _isEditing ? 'Save' : 'Add event',
            icon: Icons.check_rounded,
            loading: _saving,
            onTap: _save,
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(LumaPalette luma, {String? hint, IconData? icon}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c),
        );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(color: luma.textMuted, fontWeight: FontWeight.w400),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 18, color: luma.textSecondary),
      filled: true,
      fillColor: luma.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: border(luma.border),
      focusedBorder: border(luma.accent),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot(
      {required this.color, required this.selected, required this.onTap});
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? luma.textPrimary : Colors.transparent,
              width: 2,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
              : null,
        ),
      ),
    );
  }
}
