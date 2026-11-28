import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
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
    final repo = GroceriesScope.of(context);
    final itemsStream = repo.watchItems(listId);

    return StreamBuilder<String?>(
      stream: repo.watchListName(listId),
      builder: (context, snapshot) => _buildContent(
        context,
        repo,
        itemsStream,
        snapshot.data ?? L.of(context).groceriesListFallbackTitle,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    GroceriesRepository repo,
    Stream<List<GroceryListItemRecord>> itemsStream,
    String name,
  ) {
    final luma = context.luma;
    final t = L.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: luma.textPrimary),
                tooltip: t.groceriesBackToLists,
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              LumaPrimaryButton(
                label: t.groceriesAddProducts,
                icon: Icons.search_rounded,
                onTap: onOpenSearch,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamData<List<GroceryListItemRecord>>(
            stream: itemsStream,
            builder: (context, items) {
              if (items.isEmpty) {
                return Center(
                  child: LumaEmptyState(
                    icon: Icons.shopping_basket_outlined,
                    title: t.groceriesNoItemsTitle,
                    subtitle: t.groceriesNoItemsSubtitle,
                    action: LumaPrimaryButton(
                      label: t.groceriesAddProducts,
                      icon: Icons.search_rounded,
                      onTap: onOpenSearch,
                    ),
                  ),
                );
              }

              final groups = _groupByMarket(items);
              final grandTotal = items.fold<double>(
                0,
                (sum, i) => sum + i.lineTotal,
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      icon: const Icon(Icons.share_outlined),
                      label: Text(t.groceriesShareOnWhatsApp),
                      onPressed: () => _shareOnWhatsApp(context, name, groups),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final group in groups) ...[
                    _MarketSection(
                      group: group,
                      repo: repo,
                      onShare: () => _shareOnWhatsApp(context, name, [group]),
                    ),
                    const SizedBox(height: 16),
                  ],
                  LumaCard(
                    child: Row(
                      children: [
                        Text(
                          t.commonTotal,
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
        .putIfAbsent(
          item.market,
          () => _MarketGroup(item.market, item.marketName, []),
        )
        .items
        .add(item);
  }
  final groups = map.values.toList()
    ..sort((a, b) => a.marketName.compareTo(b.marketName));
  return groups;
}

Future<void> _shareOnWhatsApp(
  BuildContext context,
  String listName,
  List<_MarketGroup> groups,
) async {
  final t = L.of(context);
  final message = [
    listName,
    for (final group in groups)
      [
        '*${group.marketName}*',
        for (final item in group.items) '- ${item.quantity} × ${item.name}',
      ].join('\n'),
  ].join('\n\n');
  final url = Uri(
    scheme: 'https',
    host: 'wa.me',
    path: '/',
    query: 'text=${Uri.encodeComponent(message)}',
  );
  try {
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(t.groceriesWhatsAppOpenFailed),
      action: SnackBarAction(
        label: t.commonCopy,
        onPressed: () => Clipboard.setData(ClipboardData(text: message)),
      ),
    ),
  );
}

Map<String, List<GroceryListItemRecord>> _groupByCategory(
  List<GroceryListItemRecord> items,
  String otherLabel,
) {
  final map = <String, List<GroceryListItemRecord>>{};
  for (final item in items) {
    final key = (item.category != null && item.category!.trim().isNotEmpty)
        ? item.category!.trim()
        : otherLabel;
    map.putIfAbsent(key, () => []).add(item);
  }
  return map;
}

class _MarketSection extends StatelessWidget {
  const _MarketSection({
    required this.group,
    required this.repo,
    required this.onShare,
  });

  final _MarketGroup group;
  final GroceriesRepository repo;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final color = colorForMarket(group.marketSlug, luma);
    final categories = _groupByCategory(group.items, t.commonOther);
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.marketName,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      t.groceriesItemCount(group.items.length),
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
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
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: t.groceriesShareMarketOnWhatsApp(group.marketName),
                onPressed: onShare,
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
    final t = L.of(context);
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
          tooltip: t.commonRemove,
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
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 16,
        color: luma.textMuted,
      ),
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
