import 'package:flutter/material.dart';

import '../../../../account/plan.dart';
import '../../../../account/plan_selection_page.dart';
import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../settings/settings_scope.dart';
import '../../../../theme/luma_theme.dart';
import 'grocery_list_detail_page.dart';
import 'groceries_repository.dart';
import 'groceries_scope.dart';
import 'product_search_page.dart';

/// Entry point for the Groceries List plugin — an Orbit-and-up feature.
/// Shows an upgrade prompt for other plans, otherwise the list overview.
class GroceriesPage extends StatefulWidget {
  const GroceriesPage({super.key});

  @override
  State<GroceriesPage> createState() => _GroceriesPageState();
}

class _GroceriesPageState extends State<GroceriesPage> {
  int? _activeListId;
  bool _showSearch = false;

  void _openList(int id) => setState(() {
        _activeListId = id;
        _showSearch = false;
      });

  void _backToLists() => setState(() {
        _activeListId = null;
        _showSearch = false;
      });

  void _openSearch() => setState(() => _showSearch = true);

  void _backToDetail() => setState(() => _showSearch = false);

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final t = L.of(context);

    if (!planAtLeast(settings.selectedPlanId, 'orbit')) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: LumaEmptyState(
          icon: Icons.auto_awesome_rounded,
          title: t.groceriesGateTitle,
          subtitle: t.groceriesGateSubtitle,
          action: LumaPrimaryButton(
            label: t.groceriesUpgradeTo(planById('orbit').name),
            icon: Icons.auto_awesome_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PlanSelectionPage()),
            ),
          ),
        ),
      );
    }

    if (_showSearch && _activeListId != null) {
      return ProductSearchPage(
        listId: _activeListId!,
        onBack: _backToDetail,
      );
    }

    if (_activeListId != null) {
      return GroceryListDetailPage(
        listId: _activeListId!,
        onBack: _backToLists,
        onOpenSearch: _openSearch,
      );
    }

    return _GroceriesOverview(onOpenList: _openList);
  }
}

class _GroceriesOverview extends StatelessWidget {
  const _GroceriesOverview({required this.onOpenList});

  final ValueChanged<int> onOpenList;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
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
                      t.groceriesTitle,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  LumaPrimaryButton(
                    label: t.groceriesNewList,
                    icon: Icons.add_rounded,
                    onTap: () => _createList(context, repo),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                t.groceriesOverviewSubtitle,
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
                        title: t.groceriesNoListsTitle,
                        subtitle: t.groceriesNoListsSubtitle,
                        action: LumaPrimaryButton(
                          label: t.groceriesCreateFirstList,
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
                            _ListCard(list: lists[i], repo: repo, onOpenList: onOpenList),
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
    final name = await _promptForName(
      context,
      title: L.of(context).groceriesNewList,
    );
    if (name == null || name.trim().isEmpty) return;
    final id = await repo.createList(name.trim());
    if (!context.mounted) return;
    onOpenList(id);
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.list, required this.repo, required this.onOpenList});

  final GroceryListRecord list;
  final GroceriesRepository repo;
  final ValueChanged<int> onOpenList;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onOpenList(list.id),
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
                      _menuItem(
                        'rename',
                        Icons.edit_rounded,
                        t.commonRename,
                        luma,
                      ),
                      _menuItem(
                        'delete',
                        Icons.delete_outline_rounded,
                        t.commonDelete,
                        luma,
                        danger: true,
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(
                t.groceriesItemCount(list.itemCount),
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
    final name = await _promptForName(
      context,
      title: L.of(context).groceriesRenameList,
      initial: list.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await repo.renameList(list.id, name.trim());
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final luma = context.luma;
    final t = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text(t.groceriesDeleteListTitle(list.name),
            style: TextStyle(color: luma.textPrimary)),
        content: Text(
          t.groceriesDeleteListBody,
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.commonCancel, style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.commonDelete, style: TextStyle(color: luma.danger)),
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
  final t = L.of(context);
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
          hintText: t.groceriesListNameHint,
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
          child: Text(t.commonCancel, style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(t.commonSave, style: TextStyle(color: luma.accent)),
        ),
      ],
    ),
  );
}
