import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
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
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search formulas',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  LumaPrimaryButton(
                    label: 'Add formula',
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
                      label: const Text('All'),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                    for (final c in categories)
                      ChoiceChip(
                        label: Text(c),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? const LumaEmptyState(
                        icon: Icons.functions_rounded,
                        title: 'No formulas yet',
                        subtitle: 'Add your own formulas to build a personal reference library.',
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
                                              child: Text(f.category,
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
      TextEditingController(text: widget.existing?.category ?? 'Custom');
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
    final category = _categoryController.text.trim().isEmpty
        ? 'Custom'
        : _categoryController.text.trim();
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
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add formula' : 'Edit formula'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _expressionController,
              decoration: const InputDecoration(labelText: 'Expression'),
            ),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
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
