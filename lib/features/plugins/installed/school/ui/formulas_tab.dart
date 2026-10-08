import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/school_database.dart';
import '../school_repository.dart';
import '../school_scope.dart';

/// A searchable, user-extensible reference library of formulas.
class FormulasTab extends StatefulWidget {
  const FormulasTab({super.key});

  @override
  State<FormulasTab> createState() => _FormulasTabState();
}

class _FormulasTabState extends State<FormulasTab> {
  final _search = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = SchoolScope.of(context);
    final luma = context.luma;
    final t = L.of(context);
    return StreamData<List<Formula>>(
      stream: repo.watchFormulas(),
      builder: (context, formulas) {
        final categories = formulas.map((f) => f.category).toSet().toList()..sort();
        final query = _search.text.trim().toLowerCase();
        final filtered = formulas.where((f) {
          if (_category != null && f.category != _category) return false;
          if (query.isEmpty) return true;
          return f.name.toLowerCase().contains(query) ||
              f.expression.toLowerCase().contains(query);
        }).toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: t.schoolFormulasSearchHint,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  LumaPrimaryButton(
                    label: t.schoolFormulasAdd,
                    icon: Icons.add_rounded,
                    onTap: () => _openEditor(context, repo),
                  ),
                ],
              ),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(t.commonAll),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                    for (final c in categories)
                      ChoiceChip(
                        label: Text(c == 'Custom' ? t.schoolFormulaDefaultCategory : c),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? LumaEmptyState(
                        icon: Icons.functions_rounded,
                        title: t.schoolFormulasEmpty,
                        subtitle: t.schoolFormulasEmptySub,
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final f = filtered[i];
                          return LumaCard(
                            child: InkWell(
                              onTap: () => _openEditor(context, repo, existing: f),
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(f.name,
                                                style: TextStyle(
                                                    color: luma.textPrimary,
                                                    fontWeight: FontWeight.w600)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: luma.accentSubtle,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(f.category == 'Custom' ? t.schoolFormulaDefaultCategory : f.category,
                                                  style: TextStyle(
                                                      color: luma.accent, fontSize: 11)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(f.expression,
                                            style: TextStyle(
                                                color: luma.textSecondary,
                                                fontFamily: 'monospace',
                                                fontSize: 13)),
                                        if (f.description != null && f.description!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(f.description!,
                                              style: TextStyle(color: luma.textMuted, fontSize: 12)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded,
                                        color: luma.textMuted, size: 20),
                                    onPressed: () => repo.deleteFormula(f.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditor(BuildContext context, SchoolRepository repo, {Formula? existing}) {
    return showDialog(
      context: context,
      builder: (_) => _FormulaDialog(repo: repo, existing: existing),
    );
  }
}

class _FormulaDialog extends StatefulWidget {
  const _FormulaDialog({required this.repo, this.existing});
  final SchoolRepository repo;
  final Formula? existing;

  @override
  State<_FormulaDialog> createState() => _FormulaDialogState();
}

class _FormulaDialogState extends State<_FormulaDialog> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _expressionController =
      TextEditingController(text: widget.existing?.expression ?? '');
  late final _categoryController =
      TextEditingController(text: widget.existing?.category ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.existing?.description ?? '');

  @override
  void dispose() {
    _nameController.dispose();
    _expressionController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final expression = _expressionController.text.trim();
    if (name.isEmpty || expression.isEmpty) return;
    final enteredCategory = _categoryController.text.trim();
    final category = enteredCategory.isEmpty ||
            enteredCategory == L.of(context).schoolFormulaDefaultCategory
        ? 'Custom'
        : enteredCategory;
    final description = _descriptionController.text.trim();
    if (widget.existing == null) {
      await widget.repo.createFormula(
        name: name,
        expression: expression,
        category: category,
        description: description.isEmpty ? null : description,
      );
    } else {
      await widget.repo.updateFormula(
        widget.existing!.id,
        name: name,
        expression: expression,
        category: category,
        description: description,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? t.schoolFormulasAdd : t.schoolFormulasEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: t.commonName),
            ),
            TextField(
              controller: _expressionController,
              decoration: InputDecoration(labelText: t.schoolFormulaExpression),
            ),
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(
                  labelText: t.commonCategory,
                  hintText: t.schoolFormulaDefaultCategory,
                ),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: t.schoolFormulaDescriptionOptional),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.commonCancel)),
        FilledButton(onPressed: _save, child: Text(t.commonSave)),
      ],
    );
  }
}
