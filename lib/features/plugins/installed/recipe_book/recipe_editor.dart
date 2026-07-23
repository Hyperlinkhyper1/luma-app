import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'recipe_models.dart';
import 'recipe_book_controller.dart';
import 'recipe_widgets.dart';

Future<void> showRecipeEditor(
  BuildContext context,
  RecipeBookController controller, {
  LocalRecipe? existing,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          _RecipeEditorScreen(controller: controller, existing: existing),
    ),
  );
}

class _RecipeEditorScreen extends StatefulWidget {
  const _RecipeEditorScreen({required this.controller, this.existing});

  final RecipeBookController controller;
  final LocalRecipe? existing;

  @override
  State<_RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<_RecipeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _prepCtrl;
  late final TextEditingController _cookCtrl;
  late final TextEditingController _servingsCtrl;
  late String _category;
  late List<_IngredientField> _ingredients;
  late List<TextEditingController> _stepCtrls;

  Uint8List? _pickedPhoto;
  bool _removePhoto = false;
  late bool _makePublic;
  bool _saving = false;
  int _section = 0; // 0 = Details, 1 = Ingredients, 2 = Steps

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _prepCtrl = TextEditingController(
        text: (e?.prepMinutes ?? 0) != 0 ? '${e?.prepMinutes}' : '');
    _cookCtrl = TextEditingController(
        text: (e?.cookMinutes ?? 0) != 0 ? '${e?.cookMinutes}' : '');
    _servingsCtrl = TextEditingController(text: e != null ? '${e.servings}' : '2');
    _category = e?.category ?? 'Dinner';
    _makePublic = e?.isPublished ?? false;
    _ingredients = e != null && e.ingredients.isNotEmpty
        ? e.ingredients
            .map((i) => _IngredientField(
                  name: TextEditingController(text: i.name),
                  amount: TextEditingController(text: i.amount),
                  unit: i.unit,
                ))
            .toList()
        : [_IngredientField.empty()];
    _stepCtrls = e != null && e.steps.isNotEmpty
        ? e.steps.map((s) => TextEditingController(text: s)).toList()
        : [TextEditingController()];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _prepCtrl.dispose();
    _cookCtrl.dispose();
    _servingsCtrl.dispose();
    for (final f in _ingredients) {
      f.name.dispose();
      f.amount.dispose();
    }
    for (final c in _stepCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      try {
        bytes = await File(file.path!).readAsBytes();
      } catch (_) {}
    }
    if (bytes == null) return;
    setState(() {
      _pickedPhoto = bytes;
      _removePhoto = false;
    });
  }

  Future<void> _save() async {
    // The title lives on the Details tab; if it's blank, jump there so the
    // requirement is visible rather than validating an off-screen field.
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _section = 0);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please give your recipe a title.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final ingredients = _ingredients
          .where((f) => f.name.text.trim().isNotEmpty)
          .map((f) => RecipeIngredient(
                name: f.name.text.trim(),
                amount: f.amount.text.trim(),
                unit: f.unit,
              ))
          .toList();
      final steps = _stepCtrls
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

      String? error;
      if (_isEdit) {
        error = await widget.controller.updateLocal(
          widget.existing!.id,
          title: _titleCtrl.text.trim(),
          description: desc,
          category: _category,
          servings: int.tryParse(_servingsCtrl.text) ?? 2,
          prepMinutes: int.tryParse(_prepCtrl.text) ?? 0,
          cookMinutes: int.tryParse(_cookCtrl.text) ?? 0,
          ingredients: ingredients,
          steps: steps,
          photoBytes: _pickedPhoto,
          removePhoto: _removePhoto,
          makePublic: _makePublic,
        );
      } else {
        error = await widget.controller.addLocal(
          title: _titleCtrl.text.trim(),
          description: desc,
          category: _category,
          servings: int.tryParse(_servingsCtrl.text) ?? 2,
          prepMinutes: int.tryParse(_prepCtrl.text) ?? 0,
          cookMinutes: int.tryParse(_cookCtrl.text) ?? 0,
          ingredients: ingredients,
          steps: steps,
          photoBytes: _pickedPhoto,
          makePublic: _makePublic,
        );
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        titleSpacing: 0,
        iconTheme: IconThemeData(color: luma.textSecondary),
        title: Text(
          _isEdit ? 'Edit recipe' : 'New recipe',
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: LumaSegmentedTabs(
                      tabs: const ['Details', 'Ingredients', 'Steps'],
                      selectedIndex: _section,
                      onSelect: (i) => setState(() => _section = i),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: switch (_section) {
                        1 => _ingredientsSection(luma),
                        2 => _stepsSection(luma),
                        _ => _detailsSection(luma),
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: LumaPrimaryButton(
                      label: _isEdit ? 'Save changes' : 'Add recipe',
                      icon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
                      loading: _saving,
                      expand: true,
                      onTap: _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Sections -----------------------------------------------------------

  Widget _detailsSection(LumaPalette luma) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _compactPhoto(luma),
        const SizedBox(height: 16),
        const RecipeFieldLabel('Title'),
        const SizedBox(height: 6),
        RecipeTextField(
          controller: _titleCtrl,
          hint: 'e.g. Spaghetti Carbonara',
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 14),
        const RecipeFieldLabel('Description (optional)'),
        const SizedBox(height: 6),
        RecipeTextField(
          controller: _descCtrl,
          hint: 'A short note about this recipe…',
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RecipeFieldLabel('Category'),
                  const SizedBox(height: 6),
                  _categoryDropdown(luma),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RecipeFieldLabel('Servings'),
                  const SizedBox(height: 6),
                  RecipeTextField(
                    controller: _servingsCtrl,
                    hint: '2',
                    inputType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RecipeFieldLabel('Prep time (min)'),
                  const SizedBox(height: 6),
                  RecipeTextField(
                    controller: _prepCtrl,
                    hint: '15',
                    inputType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RecipeFieldLabel('Cook time (min)'),
                  const SizedBox(height: 6),
                  RecipeTextField(
                    controller: _cookCtrl,
                    hint: '20',
                    inputType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _publicToggle(luma),
      ],
    );
  }

  Widget _ingredientsSection(LumaPalette luma) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(luma, 'Ingredients', Icons.format_list_bulleted_rounded),
        const SizedBox(height: 12),
        ..._ingredients.asMap().entries.map(
              (e) => _IngredientRowEditor(
                field: e.value,
                onRemove: _ingredients.length > 1
                    ? () => setState(() => _ingredients.removeAt(e.key))
                    : null,
                onUnitChanged: (u) =>
                    setState(() => _ingredients[e.key].unit = u),
              ),
            ),
        const SizedBox(height: 6),
        _addRowButton(luma, 'Add ingredient',
            () => setState(() => _ingredients.add(_IngredientField.empty()))),
      ],
    );
  }

  Widget _stepsSection(LumaPalette luma) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(luma, 'Instructions', Icons.format_list_numbered_rounded),
        const SizedBox(height: 12),
        ..._stepCtrls.asMap().entries.map(
              (e) => _StepRowEditor(
                number: e.key + 1,
                controller: e.value,
                onRemove: _stepCtrls.length > 1
                    ? () => setState(() => _stepCtrls.removeAt(e.key))
                    : null,
              ),
            ),
        const SizedBox(height: 6),
        _addRowButton(luma, 'Add step',
            () => setState(() => _stepCtrls.add(TextEditingController()))),
      ],
    );
  }

  Widget _compactPhoto(LumaPalette luma) {
    final hasNew = _pickedPhoto != null;
    final hasExisting =
        !_removePhoto && !hasNew && (widget.existing?.photoPath != null);
    final showsPhoto = hasNew || hasExisting;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 88,
            height: 88,
            child: hasNew
                ? Image.memory(_pickedPhoto!, fit: BoxFit.cover)
                : hasExisting
                    ? LocalRecipeImage(
                        path: widget.existing!.photoPath,
                        category: _category,
                        iconSize: 26)
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: luma.background,
                          border: Border.all(color: luma.border),
                        ),
                        child: Icon(Icons.add_a_photo_rounded,
                            color: luma.textMuted, size: 26),
                      ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RecipeFieldLabel('Photo (optional)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _photoChip(luma, Icons.image_outlined,
                      showsPhoto ? 'Replace' : 'Choose photo', _pickPhoto),
                  if (showsPhoto)
                    _photoChip(luma, Icons.delete_outline_rounded, 'Remove', () {
                      setState(() {
                        _pickedPhoto = null;
                        _removePhoto = true;
                      });
                    }),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _photoChip(
      LumaPalette luma, IconData icon, String label, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: luma.background,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: luma.textSecondary),
              const SizedBox(width: 6),
              Text(label,
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

  Widget _publicToggle(LumaPalette luma) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          Icon(Icons.public_rounded, size: 20, color: luma.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share to Public',
                    style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  widget.controller.signedIn
                      ? 'Publish so other luma users can find, rate and review it.'
                      : 'Sign in under Settings → Sync to publish recipes.',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _makePublic,
            activeThumbColor: luma.onAccent,
            activeTrackColor: luma.accent,
            onChanged: widget.controller.signedIn
                ? (v) => setState(() => _makePublic = v)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _categoryDropdown(LumaPalette luma) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: kRecipeCategories.contains(_category) ? _category : 'Other',
          dropdownColor: luma.surface,
          iconEnabledColor: luma.textMuted,
          style: TextStyle(color: luma.textPrimary, fontSize: 14),
          isExpanded: true,
          items: kRecipeCategories
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c,
                        style:
                            TextStyle(color: luma.textPrimary, fontSize: 14)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _category = v ?? 'Other'),
        ),
      ),
    );
  }

  Widget _sectionHeader(LumaPalette luma, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: luma.accent),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: luma.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _addRowButton(LumaPalette luma, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.add_circle_outline_rounded, size: 16, color: luma.accent),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: luma.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _IngredientField {
  _IngredientField({required this.name, required this.amount, required this.unit});
  factory _IngredientField.empty() => _IngredientField(
        name: TextEditingController(),
        amount: TextEditingController(),
        unit: '',
      );
  final TextEditingController name;
  final TextEditingController amount;
  String unit;
}

class _IngredientRowEditor extends StatelessWidget {
  const _IngredientRowEditor({
    required this.field,
    required this.onUnitChanged,
    this.onRemove,
  });
  final _IngredientField field;
  final ValueChanged<String> onUnitChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: RecipeTextField(controller: field.name, hint: 'Ingredient'),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: RecipeTextField(
              controller: field.amount,
              hint: 'Amt',
              inputType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _UnitDropdown(value: field.unit, onChanged: onUnitChanged),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close_rounded, size: 16, color: luma.textMuted),
            ),
          ] else
            const SizedBox(width: 22),
        ],
      ),
    );
  }
}

class _UnitDropdown extends StatelessWidget {
  const _UnitDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: kRecipeUnits.contains(value) ? value : '',
          dropdownColor: luma.surface,
          iconEnabledColor: luma.textMuted,
          style: TextStyle(color: luma.textPrimary, fontSize: 13),
          isExpanded: true,
          items: kRecipeUnits
              .map((u) => DropdownMenuItem(
                    value: u,
                    child: Text(u.isEmpty ? 'Unit' : u,
                        style: TextStyle(
                            color: u.isEmpty ? luma.textMuted : luma.textPrimary,
                            fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) => onChanged(v ?? ''),
        ),
      ),
    );
  }
}

class _StepRowEditor extends StatelessWidget {
  const _StepRowEditor({
    required this.number,
    required this.controller,
    this.onRemove,
  });
  final int number;
  final TextEditingController controller;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: luma.accentSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('$number',
                    style: TextStyle(
                        color: luma.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RecipeTextField(
              controller: controller,
              hint: 'Describe this step…',
              maxLines: 2,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: onRemove,
                child:
                    Icon(Icons.close_rounded, size: 16, color: luma.textMuted),
              ),
            ),
          ] else
            const SizedBox(width: 22),
        ],
      ),
    );
  }
}
