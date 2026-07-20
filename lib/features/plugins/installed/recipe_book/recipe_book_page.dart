import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'recipe_book_repository.dart';
import 'recipe_book_scope.dart';

const _kCategories = [
  'All',
  'Breakfast',
  'Lunch',
  'Dinner',
  'Dessert',
  'Snack',
  'Drink',
  'Other',
];

const _kUnits = [
  '',
  'g',
  'kg',
  'ml',
  'l',
  'tsp',
  'tbsp',
  'cup',
  'oz',
  'lb',
  'piece',
  'slice',
  'pinch',
  'to taste',
];

Color _categoryColor(String category, LumaPalette luma) => switch (category) {
      'Breakfast' => const Color(0xFFE8A33D),
      'Lunch' => const Color(0xFF3DAE8A),
      'Dinner' => const Color(0xFF5B6CE0),
      'Dessert' => const Color(0xFFE05BA0),
      'Snack' => const Color(0xFFE07A3D),
      'Drink' => const Color(0xFF3DB8E0),
      _ => luma.textMuted,
    };

String _formatTime(int minutes) {
  if (minutes <= 0) return '';
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

class RecipeBookPage extends StatefulWidget {
  const RecipeBookPage({super.key});

  @override
  State<RecipeBookPage> createState() => _RecipeBookPageState();
}

class _RecipeBookPageState extends State<RecipeBookPage> {
  String _selectedCategory = 'All';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final repo = RecipeBookScope.of(context);
    final luma = context.luma;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SearchBar(
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 12),
              LumaPrimaryButton(
                label: 'Add recipe',
                icon: Icons.add_rounded,
                onTap: () => _openEditor(context, repo),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in _kCategories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _CategoryChip(
                      label: cat,
                      selected: _selectedCategory == cat,
                      color: cat == 'All' ? luma.accent : _categoryColor(cat, luma),
                      onTap: () => setState(() => _selectedCategory = cat),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamData<List<RecipeRecord>>(
              stream: repo.watchAll(),
              builder: (context, recipes) {
                final filtered = recipes.where((r) {
                  final matchCat =
                      _selectedCategory == 'All' || r.category == _selectedCategory;
                  final q = _search.trim().toLowerCase();
                  final matchSearch = q.isEmpty ||
                      r.title.toLowerCase().contains(q) ||
                      (r.description?.toLowerCase().contains(q) ?? false) ||
                      r.tags.any((t) => t.toLowerCase().contains(q));
                  return matchCat && matchSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return LumaEmptyState(
                    icon: Icons.menu_book_rounded,
                    title: recipes.isEmpty
                        ? 'No recipes yet'
                        : 'No recipes found',
                    subtitle: recipes.isEmpty
                        ? 'Tap "Add recipe" to save your first recipe.'
                        : 'Try a different search or category.',
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossCount =
                        (constraints.maxWidth / 280).floor().clamp(1, 4);
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => _RecipeCard(
                        recipe: filtered[i],
                        repo: repo,
                        onTap: () => _openDetail(context, filtered[i], repo),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static void _openEditor(
    BuildContext context,
    RecipeBookRepository repo, {
    RecipeRecord? existing,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _RecipeEditorDialog(repo: repo, existing: existing),
    );
  }

  static void _openDetail(
    BuildContext context,
    RecipeRecord recipe,
    RecipeBookRepository repo,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _RecipeDetailDialog(recipe: recipe, repo: repo),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search_rounded, size: 18, color: luma.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onChanged,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search recipes…',
                hintStyle: TextStyle(color: luma.textMuted, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                widget.onChanged('');
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.close_rounded, size: 16, color: luma.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.color.withValues(alpha: 0.18)
                : (_hovering ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected ? widget.color : luma.border,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.selected ? widget.color : luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeCard extends StatefulWidget {
  const _RecipeCard({
    required this.recipe,
    required this.repo,
    required this.onTap,
  });
  final RecipeRecord recipe;
  final RecipeBookRepository repo;
  final VoidCallback onTap;

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final recipe = widget.recipe;
    final catColor = _categoryColor(recipe.category, luma);
    final timeStr = _formatTime(recipe.totalMinutes);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovering ? luma.surfaceHover : luma.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: luma.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      recipe.category,
                      style: TextStyle(
                        color: catColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _CardMenu(recipe: recipe, repo: widget.repo),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (recipe.description != null &&
                  recipe.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  recipe.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 14, color: luma.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${recipe.servings}',
                    style: TextStyle(color: luma.textSecondary, fontSize: 12),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.schedule_rounded,
                        size: 14, color: luma.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style:
                          TextStyle(color: luma.textSecondary, fontSize: 12),
                    ),
                  ],
                  if (recipe.ingredients.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.format_list_bulleted_rounded,
                        size: 14, color: luma.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${recipe.ingredients.length}',
                      style:
                          TextStyle(color: luma.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.recipe, required this.repo});
  final RecipeRecord recipe;
  final RecipeBookRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return PopupMenuButton<_MenuAction>(
      icon: Icon(Icons.more_horiz_rounded, size: 18, color: luma.textMuted),
      color: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: luma.border),
      ),
      onSelected: (action) async {
        switch (action) {
          case _MenuAction.edit:
            if (context.mounted) {
              showDialog<void>(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.5),
                builder: (_) =>
                    _RecipeEditorDialog(repo: repo, existing: recipe),
              );
            }
          case _MenuAction.delete:
            if (context.mounted) {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => _ConfirmDeleteDialog(title: recipe.title),
              );
              if (confirmed == true) await repo.delete(recipe.id);
            }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _MenuAction.edit,
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 16, color: luma.textSecondary),
              const SizedBox(width: 10),
              Text('Edit', style: TextStyle(color: luma.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 16, color: luma.danger),
              const SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: luma.danger)),
            ],
          ),
        ),
      ],
    );
  }
}

enum _MenuAction { edit, delete }

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: luma.border),
      ),
      title: Text('Delete recipe?',
          style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700)),
      content: Text(
        '"$title" will be permanently deleted.',
        style: TextStyle(color: luma.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Delete', style: TextStyle(color: luma.danger)),
        ),
      ],
    );
  }
}

class _RecipeDetailDialog extends StatefulWidget {
  const _RecipeDetailDialog({required this.recipe, required this.repo});
  final RecipeRecord recipe;
  final RecipeBookRepository repo;

  @override
  State<_RecipeDetailDialog> createState() => _RecipeDetailDialogState();
}

class _RecipeDetailDialogState extends State<_RecipeDetailDialog> {
  late int _servings;

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.servings;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final recipe = widget.recipe;
    final scale = _servings / recipe.servings;
    final catColor = _categoryColor(recipe.category, luma);
    final prepStr = _formatTime(recipe.prepMinutes);
    final cookStr = _formatTime(recipe.cookMinutes);

    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: luma.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            recipe.category,
                            style: TextStyle(
                              color: catColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          recipe.title,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (recipe.description != null &&
                            recipe.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            recipe.description!,
                            style: TextStyle(
                                color: luma.textSecondary, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: luma.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _StatChip(
                    icon: Icons.people_outline_rounded,
                    label: '$_servings serving${_servings == 1 ? '' : 's'}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SmallIconButton(
                          icon: Icons.remove_rounded,
                          onTap: _servings > 1
                              ? () => setState(() => _servings--)
                              : null,
                          luma: luma,
                        ),
                        const SizedBox(width: 4),
                        _SmallIconButton(
                          icon: Icons.add_rounded,
                          onTap: () => setState(() => _servings++),
                          luma: luma,
                        ),
                      ],
                    ),
                    luma: luma,
                  ),
                  if (prepStr.isNotEmpty)
                    _StatChip(
                      icon: Icons.timer_outlined,
                      label: 'Prep: $prepStr',
                      luma: luma,
                    ),
                  if (cookStr.isNotEmpty)
                    _StatChip(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Cook: $cookStr',
                      luma: luma,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recipe.ingredients.isNotEmpty) ...[
                      _SectionHeader(
                          label: 'Ingredients', icon: Icons.format_list_bulleted_rounded, luma: luma),
                      const SizedBox(height: 10),
                      ...recipe.ingredients.map(
                        (ing) => _IngredientRow(
                            ingredient: ing, scale: scale, luma: luma),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (recipe.steps.isNotEmpty) ...[
                      _SectionHeader(
                          label: 'Instructions', icon: Icons.format_list_numbered_rounded, luma: luma),
                      const SizedBox(height: 10),
                      ...recipe.steps.asMap().entries.map(
                            (e) => _StepRow(
                                number: e.key + 1, text: e.value, luma: luma),
                          ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  LumaGhostButton(
                    label: 'Edit',
                    icon: Icons.edit_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      showDialog<void>(
                        context: context,
                        barrierColor: Colors.black.withValues(alpha: 0.5),
                        builder: (_) => _RecipeEditorDialog(
                          repo: widget.repo,
                          existing: recipe,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.luma,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final LumaPalette luma;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: luma.textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(color: luma.textSecondary, fontSize: 13)),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.icon,
    required this.onTap,
    required this.luma,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: onTap != null
              ? luma.accentSubtle
              : luma.border.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 14,
          color: onTap != null ? luma.accent : luma.textMuted,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.luma,
  });
  final String label;
  final IconData icon;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: luma.accent),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.ingredient,
    required this.scale,
    required this.luma,
  });
  final RecipeIngredient ingredient;
  final double scale;
  final LumaPalette luma;

  String _scaledAmount() {
    if (ingredient.amount.isEmpty) return '';
    final n = double.tryParse(ingredient.amount);
    if (n == null) return ingredient.amount;
    final scaled = n * scale;
    if (scaled == scaled.truncateToDouble()) {
      return scaled.toStringAsFixed(0);
    }
    return scaled.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final amt = _scaledAmount();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: luma.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ingredient.name,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
            ),
          ),
          if (amt.isNotEmpty || ingredient.unit.isNotEmpty)
            Text(
              '${amt.isNotEmpty ? amt : ''}${ingredient.unit.isNotEmpty ? ' ${ingredient.unit}' : ''}'.trim(),
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.text,
    required this.luma,
  });
  final int number;
  final String text;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: luma.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: TextStyle(color: luma.textPrimary, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeEditorDialog extends StatefulWidget {
  const _RecipeEditorDialog({required this.repo, this.existing});
  final RecipeBookRepository repo;
  final RecipeRecord? existing;

  @override
  State<_RecipeEditorDialog> createState() => _RecipeEditorDialogState();
}

class _RecipeEditorDialogState extends State<_RecipeEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _prepCtrl;
  late final TextEditingController _cookCtrl;
  late final TextEditingController _servingsCtrl;
  late String _category;
  late List<_IngredientField> _ingredients;
  late List<TextEditingController> _stepCtrls;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _prepCtrl =
        TextEditingController(text: e?.prepMinutes != 0 ? '${e?.prepMinutes}' : '');
    _cookCtrl =
        TextEditingController(text: e?.cookMinutes != 0 ? '${e?.cookMinutes}' : '');
    _servingsCtrl =
        TextEditingController(text: e != null ? '${e.servings}' : '2');
    _category = e?.category ?? 'Other';
    _ingredients = e?.ingredients
            .map((i) => _IngredientField(
                  name: TextEditingController(text: i.name),
                  amount: TextEditingController(text: i.amount),
                  unit: i.unit,
                ))
            .toList() ??
        [_IngredientField.empty()];
    _stepCtrls = e?.steps
            .map((s) => TextEditingController(text: s))
            .toList() ??
        [TextEditingController()];
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final ingredients = _ingredients
          .where((f) => f.name.text.trim().isNotEmpty)
          .map(
            (f) => RecipeIngredient(
              name: f.name.text.trim(),
              amount: f.amount.text.trim(),
              unit: f.unit,
            ),
          )
          .toList();
      final steps = _stepCtrls
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await widget.repo.save(
        id: widget.existing?.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        category: _category,
        servings: int.tryParse(_servingsCtrl.text) ?? 2,
        prepMinutes: int.tryParse(_prepCtrl.text) ?? 0,
        cookMinutes: int.tryParse(_cookCtrl.text) ?? 0,
        ingredients: ingredients,
        steps: steps,
        tags: const [],
      );

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final isEdit = widget.existing != null;

    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: luma.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
                child: Row(
                  children: [
                    Text(
                      isEdit ? 'Edit recipe' : 'New recipe',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: luma.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FieldLabel(label: 'Title', luma: luma),
                      const SizedBox(height: 6),
                      _LumaTextField(
                        controller: _titleCtrl,
                        hint: 'e.g. Spaghetti Carbonara',
                        luma: luma,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel(label: 'Description (optional)', luma: luma),
                      const SizedBox(height: 6),
                      _LumaTextField(
                        controller: _descCtrl,
                        hint: 'A brief note about this recipe…',
                        luma: luma,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(label: 'Category', luma: luma),
                                const SizedBox(height: 6),
                                _LumaCategoryDropdown(
                                  value: _category,
                                  luma: luma,
                                  onChanged: (v) =>
                                      setState(() => _category = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(label: 'Servings', luma: luma),
                                const SizedBox(height: 6),
                                _LumaTextField(
                                  controller: _servingsCtrl,
                                  hint: '2',
                                  luma: luma,
                                  inputType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
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
                                _FieldLabel(
                                    label: 'Prep time (min)', luma: luma),
                                const SizedBox(height: 6),
                                _LumaTextField(
                                  controller: _prepCtrl,
                                  hint: '15',
                                  luma: luma,
                                  inputType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(
                                    label: 'Cook time (min)', luma: luma),
                                const SizedBox(height: 6),
                                _LumaTextField(
                                  controller: _cookCtrl,
                                  hint: '20',
                                  luma: luma,
                                  inputType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.format_list_bulleted_rounded,
                              size: 16, color: luma.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Ingredients',
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._ingredients.asMap().entries.map(
                            (e) => _IngredientRowEditor(
                              field: e.value,
                              luma: luma,
                              onRemove: _ingredients.length > 1
                                  ? () => setState(
                                      () => _ingredients.removeAt(e.key))
                                  : null,
                              onUnitChanged: (u) => setState(
                                  () => _ingredients[e.key].unit = u),
                            ),
                          ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(
                            () => _ingredients.add(_IngredientField.empty())),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded,
                                size: 16, color: luma.accent),
                            const SizedBox(width: 6),
                            Text('Add ingredient',
                                style: TextStyle(
                                    color: luma.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.format_list_numbered_rounded,
                              size: 16, color: luma.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Instructions',
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._stepCtrls.asMap().entries.map(
                            (e) => _StepRowEditor(
                              number: e.key + 1,
                              controller: e.value,
                              luma: luma,
                              onRemove: _stepCtrls.length > 1
                                  ? () =>
                                      setState(() => _stepCtrls.removeAt(e.key))
                                  : null,
                            ),
                          ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(
                            () => _stepCtrls.add(TextEditingController())),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded,
                                size: 16, color: luma.accent),
                            const SizedBox(width: 6),
                            Text('Add step',
                                style: TextStyle(
                                    color: luma.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    LumaGhostButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    LumaPrimaryButton(
                      label: isEdit ? 'Save changes' : 'Add recipe',
                      icon: isEdit ? Icons.check_rounded : Icons.add_rounded,
                      loading: _saving,
                      onTap: _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    required this.luma,
    required this.onUnitChanged,
    this.onRemove,
  });
  final _IngredientField field;
  final LumaPalette luma;
  final ValueChanged<String> onUnitChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _LumaTextField(
              controller: field.name,
              hint: 'Ingredient',
              luma: luma,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _LumaTextField(
              controller: field.amount,
              hint: 'Amt',
              luma: luma,
              inputType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _UnitDropdown(
              value: field.unit,
              luma: luma,
              onChanged: onUnitChanged,
            ),
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
  const _UnitDropdown({
    required this.value,
    required this.luma,
    required this.onChanged,
  });
  final String value;
  final LumaPalette luma;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
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
          value: _kUnits.contains(value) ? value : '',
          dropdownColor: luma.surface,
          iconEnabledColor: luma.textMuted,
          style: TextStyle(color: luma.textPrimary, fontSize: 13),
          isExpanded: true,
          items: _kUnits
              .map(
                (u) => DropdownMenuItem(
                  value: u,
                  child: Text(u.isEmpty ? 'Unit' : u,
                      style: TextStyle(
                          color: u.isEmpty ? luma.textMuted : luma.textPrimary,
                          fontSize: 13)),
                ),
              )
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
    required this.luma,
    this.onRemove,
  });
  final int number;
  final TextEditingController controller;
  final LumaPalette luma;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
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
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: luma.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _LumaTextField(
              controller: controller,
              hint: 'Describe this step…',
              luma: luma,
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

class _LumaCategoryDropdown extends StatelessWidget {
  const _LumaCategoryDropdown({
    required this.value,
    required this.luma,
    required this.onChanged,
  });
  final String value;
  final LumaPalette luma;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const cats = [
      'Breakfast',
      'Lunch',
      'Dinner',
      'Dessert',
      'Snack',
      'Drink',
      'Other'
    ];
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
          value: value,
          dropdownColor: luma.surface,
          iconEnabledColor: luma.textMuted,
          style: TextStyle(color: luma.textPrimary, fontSize: 14),
          isExpanded: true,
          items: cats
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c,
                      style: TextStyle(color: luma.textPrimary, fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: (v) => onChanged(v ?? 'Other'),
        ),
      ),
    );
  }
}

class _LumaTextField extends StatelessWidget {
  const _LumaTextField({
    required this.controller,
    required this.hint,
    required this.luma,
    this.maxLines = 1,
    this.inputType,
    this.inputFormatters,
    this.validator,
  });
  final TextEditingController controller;
  final String hint;
  final LumaPalette luma;
  final int maxLines;
  final TextInputType? inputType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: inputType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(color: luma.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: luma.textMuted, fontSize: 14),
        filled: true,
        fillColor: luma.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: luma.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: luma.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: luma.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: luma.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: luma.danger, width: 1.5),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.luma});
  final String label;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: luma.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
