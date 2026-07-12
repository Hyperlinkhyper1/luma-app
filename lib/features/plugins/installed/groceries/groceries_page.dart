import 'package:flutter/material.dart';

import '../../../../account/plan.dart';
import '../../../../account/plan_selection_page.dart';
import '../../../../app/widgets.dart';
import '../../../../settings/settings_scope.dart';
import '../../../../theme/luma_theme.dart';
import 'grocery_list_detail_page.dart';
import 'groceries_repository.dart';
import 'groceries_scope.dart';

/// Entry point for the Groceries List plugin — a Nova-exclusive feature.
/// Shows an upgrade prompt for other plans, otherwise the list overview.
class GroceriesPage extends StatelessWidget {
  const GroceriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);

    if (settings.selectedPlanId != 'nova') {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: LumaEmptyState(
          icon: Icons.auto_awesome_rounded,
          title: 'Groceries List is a Nova exclusive',
          subtitle:
              'Search Jumbo, Albert Heijn and Lidl prices side by side, '
              'and build shopping lists that split themselves by store '
              'and aisle with running totals — included free with Nova.',
          action: LumaPrimaryButton(
            label: 'Upgrade to ${planById('nova').name}',
            icon: Icons.auto_awesome_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PlanSelectionPage()),
            ),
          ),
        ),
      );
    }

    return const _GroceriesOverview();
  }
}

class _GroceriesOverview extends StatelessWidget {
  const _GroceriesOverview();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = GroceriesScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Groceries',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  LumaPrimaryButton(
                    label: 'New list',
                    icon: Icons.add_rounded,
                    onTap: () => _createList(context, repo),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Search products across Jumbo, Albert Heijn and Lidl, and '
                'build shopping lists split by store.',
                style: TextStyle(color: luma.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              StreamData<List<GroceryListRecord>>(
                stream: repo.watchLists(),
                builder: (context, lists) {
                  if (lists.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: LumaEmptyState(
                        icon: Icons.local_grocery_store_rounded,
                        title: 'No lists yet',
                        subtitle:
                            'Create a list, then search products to add to it.',
                        action: LumaPrimaryButton(
                          label: 'Create your first list',
                          icon: Icons.add_rounded,
                          onTap: () => _createList(context, repo),
                        ),
                      ),
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 760
                          ? 3
                          : (constraints.maxWidth >= 480 ? 2 : 1);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: lists.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.1,
                        ),
                        itemBuilder: (context, i) =>
                            _ListCard(list: lists[i], repo: repo),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createList(BuildContext context, GroceriesRepository repo) async {
    final name = await _promptForName(context, title: 'New list');
    if (name == null || name.trim().isEmpty) return;
    final id = await repo.createList(name.trim());
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroceryListDetailPage(listId: id)),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.list, required this.repo});

  final GroceryListRecord list;
  final GroceriesRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroceryListDetailPage(listId: list.id),
          ),
        ),
        child: LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      list.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded,
                        size: 18, color: luma.textMuted),
                    color: luma.surface,
                    onSelected: (v) {
                      switch (v) {
                        case 'rename':
                          _rename(context);
                        case 'delete':
                          _confirmDelete(context);
                      }
                    },
                    itemBuilder: (context) => [
                      _menuItem('rename', Icons.edit_rounded, 'Rename', luma),
                      _menuItem(
                        'delete',
                        Icons.delete_outline_rounded,
                        'Delete',
                        luma,
                        danger: true,
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${list.itemCount} item${list.itemCount == 1 ? '' : 's'}',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '€${list.total.toStringAsFixed(2)}',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final name =
        await _promptForName(context, title: 'Rename list', initial: list.name);
    if (name == null || name.trim().isEmpty) return;
    await repo.renameList(list.id, name.trim());
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final luma = context.luma;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text('Delete "${list.name}"?',
            style: TextStyle(color: luma.textPrimary)),
        content: Text(
          'This removes the list and everything on it. This can\'t be undone.',
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
      ),
    );
    if (ok == true) await repo.deleteList(list.id);
  }
}

PopupMenuItem<String> _menuItem(
    String value, IconData icon, String label, LumaPalette luma,
    {bool danger = false}) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18, color: danger ? luma.danger : luma.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: luma.textPrimary)),
      ],
    ),
  );
}

Future<String?> _promptForName(BuildContext context,
    {required String title, String? initial}) {
  final controller = TextEditingController(text: initial);
  final luma = context.luma;
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: luma.surface,
      title: Text(title, style: TextStyle(color: luma.textPrimary)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: luma.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'List name',
          hintStyle: TextStyle(color: luma.textMuted),
          filled: true,
          fillColor: luma.background,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: luma.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: luma.accent),
          ),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text('Save', style: TextStyle(color: luma.accent)),
        ),
      ],
    ),
  );
}
