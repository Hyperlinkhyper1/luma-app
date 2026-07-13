import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'groceries_repository.dart';
import 'groceries_scope.dart';
import 'market_style.dart';

/// One shopping list: items auto-grouped by supermarket, then by
/// category/aisle within each, with per-market and grand totals.
class GroceryListDetailPage extends StatelessWidget {
  const GroceryListDetailPage({
    super.key,
    required this.listId,
    required this.onBack,
    required this.onOpenSearch,
  });

  final int listId;
  final VoidCallback onBack;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = GroceriesScope.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: luma.textPrimary),
                tooltip: 'Back to lists',
                onPressed: onBack,
              ),
              Expanded(
                child: StreamData<String?>(
                  stream: repo.watchListName(listId),
                  builder: (context, name) => Text(
                    name ?? 'List',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              LumaPrimaryButton(
                label: 'Add products',
                icon: Icons.search_rounded,
                onTap: onOpenSearch,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamData<List<GroceryListItemRecord>>(
            stream: repo.watchItems(listId),
            builder: (context, items) {
              if (items.isEmpty) {
                return Center(
                  child: LumaEmptyState(
                    icon: Icons.shopping_basket_outlined,
                    title: 'No items yet',
                    subtitle:
                        'Search products to add them to this list.',
                    action: LumaPrimaryButton(
                      label: 'Add products',
                      icon: Icons.search_rounded,
                      onTap: onOpenSearch,
                    ),
                  ),
                );
              }

              final groups = _groupByMarket(items);
              final grandTotal =
                  items.fold<double>(0, (sum, i) => sum + i.lineTotal);

              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                children: [
                  for (final group in groups) ...[
                    _MarketSection(group: group, repo: repo),
                    const SizedBox(height: 16),
                  ],
                  LumaCard(
                    child: Row(
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '€${grandTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MarketGroup {
  _MarketGroup(this.marketSlug, this.marketName, this.items);
  final String marketSlug;
  final String marketName;
  final List<GroceryListItemRecord> items;
  double get subtotal => items.fold(0, (sum, i) => sum + i.lineTotal);
}

List<_MarketGroup> _groupByMarket(List<GroceryListItemRecord> items) {
  final map = <String, _MarketGroup>{};
  for (final item in items) {
    map
        .putIfAbsent(item.market, () => _MarketGroup(item.market, item.marketName, []))
        .items
        .add(item);
  }
  final groups = map.values.toList()
    ..sort((a, b) => a.marketName.compareTo(b.marketName));
  return groups;
}

Map<String, List<GroceryListItemRecord>> _groupByCategory(
    List<GroceryListItemRecord> items) {
  final map = <String, List<GroceryListItemRecord>>{};
  for (final item in items) {
    final key = (item.category != null && item.category!.trim().isNotEmpty)
        ? item.category!.trim()
        : 'Other';
    map.putIfAbsent(key, () => []).add(item);
  }
  return map;
}

class _MarketSection extends StatelessWidget {
  const _MarketSection({required this.group, required this.repo});

  final _MarketGroup group;
  final GroceriesRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = colorForMarket(group.marketSlug, luma);
    final categories = _groupByCategory(group.items);
    final categoryKeys = categories.keys.toList()..sort();

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.marketName,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${group.items.length} item${group.items.length == 1 ? '' : 's'}',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
              const SizedBox(width: 10),
              Text(
                '€${group.subtotal.toStringAsFixed(2)}',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          for (final category in categoryKeys) ...[
            const SizedBox(height: 14),
            Text(
              category.toUpperCase(),
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in categories[category]!) ...[
              _ItemRow(item: item, repo: repo),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.repo});

  final GroceryListItemRecord item;
  final GroceriesRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 40,
            height: 40,
            child: item.imageUrl == null
                ? _ImageFallback(luma: luma)
                : Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _ImageFallback(luma: luma),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item.brand != null)
                Text(
                  item.brand!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                ),
            ],
          ),
        ),
        _QuantityStepper(item: item, repo: repo),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: Text(
            item.price == null ? '—' : '€${item.lineTotal.toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 18, color: luma.textMuted),
          tooltip: 'Remove',
          onPressed: () => repo.removeItem(item),
        ),
      ],
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.luma});
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: luma.background,
      child: Icon(Icons.image_not_supported_outlined,
          size: 16, color: luma.textMuted),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.item, required this.repo});

  final GroceryListItemRecord item;
  final GroceriesRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove_rounded,
          onTap: () => repo.setQuantity(item, item.quantity - 1),
          luma: luma,
        ),
        SizedBox(
          width: 24,
          child: Text(
            '${item.quantity}',
            textAlign: TextAlign.center,
            style: TextStyle(color: luma.textPrimary, fontSize: 13),
          ),
        ),
        _StepperButton(
          icon: Icons.add_rounded,
          onTap: () => repo.setQuantity(item, item.quantity + 1),
          luma: luma,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.luma,
  });

  final IconData icon;
  final VoidCallback onTap;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: luma.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: luma.border),
          ),
          child: Icon(icon, size: 14, color: luma.textSecondary),
        ),
      ),
    );
  }
}
