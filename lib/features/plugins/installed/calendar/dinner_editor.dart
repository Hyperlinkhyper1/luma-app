import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'calendar_repository.dart';

/// Opens the set/edit sheet for the dinner planned on [day]. Pass [existing]
/// to edit an already-planned dinner.
Future<void> showDinnerEditor(
  BuildContext context,
  CalendarRepository repo, {
  required DateTime day,
  DinnerPlanRecord? existing,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _DinnerEditorDialog(repo: repo, day: day, existing: existing),
  );
}

/// Opens a read-only view of the dinner planned on a day: the dish, its
/// ingredients (as a shopping checklist) and instructions.
Future<void> showDinnerDetail(
  BuildContext context,
  CalendarRepository repo,
  DinnerPlanRecord dinner,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _DinnerDetailDialog(repo: repo, dinner: dinner),
  );
}

// ── Editor ──────────────────────────────────────────────────────────────

class _DinnerEditorDialog extends StatefulWidget {
  const _DinnerEditorDialog(
      {required this.repo, required this.day, this.existing});

  final CalendarRepository repo;
  final DateTime day;
  final DinnerPlanRecord? existing;

  @override
  State<_DinnerEditorDialog> createState() => _DinnerEditorDialogState();
}

class _DinnerEditorDialogState extends State<_DinnerEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _instructions;
  late final TextEditingController _servings;
  late final TextEditingController _minutes;
  late final List<TextEditingController> _ingredients;

  String? _error;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _instructions = TextEditingController(text: e?.instructions ?? '');
    _servings = TextEditingController(text: e?.servings?.toString() ?? '');
    _minutes = TextEditingController(text: e?.minutes?.toString() ?? '');
    _ingredients = [
      for (final i in e?.ingredients ?? const <String>[])
        TextEditingController(text: i),
      TextEditingController(),
    ];
  }

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _servings.dispose();
    _minutes.dispose();
    for (final c in _ingredients) {
      c.dispose();
    }
    super.dispose();
  }

  void _addIngredientRow() {
    setState(() => _ingredients.add(TextEditingController()));
  }

  void _removeIngredientRow(int index) {
    setState(() {
      _ingredients[index].dispose();
      _ingredients.removeAt(index);
      if (_ingredients.isEmpty) _ingredients.add(TextEditingController());
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = L.of(context).calendarDinnerNameRequired);
      return;
    }
    final ingredients = _ingredients
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    final instructions = _instructions.text.trim();
    final servings = int.tryParse(_servings.text.trim());
    final minutes = int.tryParse(_minutes.text.trim());

    setState(() {
      _saving = true;
      _error = null;
    });

    await widget.repo.setDinner(
      day: widget.day,
      title: title,
      ingredients: ingredients,
      instructions: instructions.isEmpty ? null : instructions,
      servings: servings,
      minutes: minutes,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await widget.repo.deleteDinner(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return Dialog(
      backgroundColor: luma.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _numberField(luma, _servings,
                              hint: t.calendarServings,
                              icon: Icons.people_alt_outlined),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _numberField(luma, _minutes,
                              hint: t.calendarMinutes, icon: Icons.schedule_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _label(luma, t.calendarIngredients),
                    const SizedBox(height: 8),
                    _ingredientRows(luma),
                    const SizedBox(height: 6),
                    LumaGhostButton(
                      label: t.calendarAddIngredient,
                      icon: Icons.add_rounded,
                      onTap: _addIngredientRow,
                    ),
                    const SizedBox(height: 18),
                    _label(luma, t.calendarInstructions),
                    const SizedBox(height: 8),
                    _plainField(luma, _instructions,
                        hint: t.calendarInstructionsHint, maxLines: 5),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? L.of(context).calendarEditDinner : L.of(context).calendarSetDinner,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  DateFormat('EEEE, d MMMM').format(widget.day),
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: luma.textMuted, size: 20),
            tooltip: L.of(context).commonClose,
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
      decoration: _decoration(luma, hint: L.of(context).calendarDishNameHint),
      onSubmitted: (_) => _save(),
    );
  }

  Widget _ingredientRows(LumaPalette luma) {
    return Column(
      children: [
        for (var i = 0; i < _ingredients.length; i++) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ingredients[i],
                  style: TextStyle(color: luma.textPrimary, fontSize: 14),
                  decoration: _decoration(luma,
                      hint: L.of(context).calendarIngredientHint,
                      icon: Icons.circle_outlined),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 16, color: luma.textMuted),
                tooltip: L.of(context).commonRemove,
                onPressed: () => _removeIngredientRow(i),
              ),
            ],
          ),
          if (i != _ingredients.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _numberField(LumaPalette luma, TextEditingController controller,
      {required String hint, required IconData icon}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(color: luma.textPrimary, fontSize: 14),
      decoration: _decoration(luma, hint: hint, icon: icon),
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
              message: L.of(context).calendarRemoveDinner,
              child: IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: luma.danger),
                onPressed: _delete,
              ),
            ),
          const Spacer(),
          LumaGhostButton(
            label: L.of(context).commonCancel,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          LumaPrimaryButton(
            label: _isEditing ? L.of(context).commonSave : L.of(context).calendarSetDinner,
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

// ── Detail (recipe view) ──────────────────────────────────────────────────

class _DinnerDetailDialog extends StatefulWidget {
  const _DinnerDetailDialog({required this.repo, required this.dinner});
  final CalendarRepository repo;
  final DinnerPlanRecord dinner;

  @override
  State<_DinnerDetailDialog> createState() => _DinnerDetailDialogState();
}

class _DinnerDetailDialogState extends State<_DinnerDetailDialog> {
  late final Set<int> _checked = {};

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final d = widget.dinner;
    final t = L.of(context);
    return Dialog(
      backgroundColor: luma.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(luma, d),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (d.servings != null || d.minutes != null) ...[
                      _metaRow(luma, d),
                      const SizedBox(height: 18),
                    ],
                    if (d.ingredients.isNotEmpty) ...[
                      _label(luma, t.calendarWhatYouNeed),
                      const SizedBox(height: 8),
                      _ingredientList(luma, d),
                      const SizedBox(height: 18),
                    ],
                    if (d.instructions != null &&
                        d.instructions!.isNotEmpty) ...[
                      _label(luma, t.calendarInstructions),
                      const SizedBox(height: 8),
                      Text(
                        d.instructions!,
                        style: TextStyle(
                            color: luma.textPrimary, fontSize: 14, height: 1.5),
                      ),
                    ],
                    if (d.ingredients.isEmpty &&
                        (d.instructions == null || d.instructions!.isEmpty))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          t.calendarDinnerEmpty,
                          style: TextStyle(color: luma.textMuted, fontSize: 13),
                        ),
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

  Widget _header(LumaPalette luma, DinnerPlanRecord d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.dinner_dining_rounded,
                color: luma.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  DateFormat('EEEE, d MMMM').format(d.date),
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: luma.textMuted, size: 20),
            tooltip: L.of(context).commonClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(LumaPalette luma, DinnerPlanRecord d) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (d.servings != null)
          _MetaPill(
            icon: Icons.people_alt_outlined,
            label: L.of(context).calendarServingsCount(d.servings!),
          ),
        if (d.minutes != null)
          _MetaPill(
            icon: Icons.schedule_rounded,
            label: L.of(context).calendarMinutesShort(d.minutes!),
          ),
      ],
    );
  }

  Widget _ingredientList(LumaPalette luma, DinnerPlanRecord d) {
    return Column(
      children: [
        for (var i = 0; i < d.ingredients.length; i++)
          _IngredientRow(
            label: d.ingredients[i],
            checked: _checked.contains(i),
            onToggle: () => setState(() {
              if (!_checked.add(i)) _checked.remove(i);
            }),
          ),
      ],
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
          Tooltip(
            message: L.of(context).calendarRemoveDinner,
            child: IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: luma.danger),
              onPressed: () async {
                await widget.repo.deleteDinner(widget.dinner.id);
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ),
          const Spacer(),
          LumaGhostButton(
            label: L.of(context).commonClose,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          LumaPrimaryButton(
            label: L.of(context).commonEdit,
            icon: Icons.edit_rounded,
            onTap: () {
              Navigator.of(context).pop();
              showDinnerEditor(context, widget.repo,
                  day: widget.dinner.date, existing: widget.dinner);
            },
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: luma.textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow(
      {required this.label, required this.checked, required this.onToggle});
  final String label;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: checked ? luma.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: checked ? luma.accent : luma.border, width: 1.4),
                ),
                child: checked
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 13)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: checked ? luma.textMuted : luma.textPrimary,
                    fontSize: 14,
                    decoration:
                        checked ? TextDecoration.lineThrough : null,
                    decorationColor: luma.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
