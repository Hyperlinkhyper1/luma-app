import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'groceries_api.dart';
import 'groceries_scope.dart';
import 'market_style.dart';

const _marketFilters = <String?>[null, 'jumbo', 'ah', 'lidl'];
const _marketFilterLabels = ['All stores', 'Jumbo', 'Albert Heijn', 'Lidl'];
const _sortOptions = [ProductSort.relevance, ProductSort.priceAsc, ProductSort.priceDesc];
const _sortLabels = ['Relevance', 'Price ↑', 'Price ↓'];

/// Search Jumbo/AH/Lidl products (via the supermarket-db API), filter by
/// store, sort by price, and add results straight onto [listId].
class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({super.key, required this.listId, required this.onBack});

  final int listId;
  final VoidCallback onBack;

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  final _queryController = TextEditingController();
  Timer? _debounce;

  int _marketIndex = 0;
  int _sortIndex = 0;
  bool _loading = false;
  String? _error;
  List<RemoteProduct> _results = const [];
  final Set<String> _justAdded = {};

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    final api = GroceriesApiScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await api.search(
        query: _queryController.text,
        marketSlugs: _marketFilters[_marketIndex] == null
            ? null
            : [_marketFilters[_marketIndex]!],
        sort: _sortOptions[_sortIndex],
      );
      if (!mounted) return;
      setState(() => _results = results);
    } on GroceriesApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToList(RemoteProduct product) async {
    final repo = GroceriesScope.of(context);
    await repo.addProduct(widget.listId, product);
    if (!mounted) return;
    setState(() => _justAdded.add(product.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${product.name}" to your list'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final items = await repo.watchItems(widget.listId).first;
            final match = items.where((i) => i.productId == product.id);
            if (match.isNotEmpty) await repo.removeItem(match.last);
            if (mounted) setState(() => _justAdded.remove(product.id));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: luma.textPrimary),
                tooltip: 'Back to list',
                onPressed: widget.onBack,
              ),
              Text(
                'Add products',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.settings_outlined, color: luma.textMuted, size: 20),
                tooltip: 'Groceries server address',
                onPressed: () => _editServerUrl(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: TextField(
            controller: _queryController,
            autofocus: true,
            style: TextStyle(color: luma.textPrimary),
            onChanged: _onQueryChanged,
            onSubmitted: (_) => _runSearch(),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search products…',
              hintStyle: TextStyle(color: luma.textMuted),
              prefixIcon: Icon(Icons.search_rounded, color: luma.textMuted, size: 20),
              filled: true,
              fillColor: luma.surface,
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
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LumaSegmentedTabs(
                  tabs: _marketFilterLabels,
                  selectedIndex: _marketIndex,
                  onSelect: (i) {
                    setState(() => _marketIndex = i);
                    _runSearch();
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Row(
            children: [
              Text('Sort', style: TextStyle(color: luma.textMuted, fontSize: 12)),
              const SizedBox(width: 10),
              LumaSegmentedTabs(
                tabs: _sortLabels,
                selectedIndex: _sortIndex,
                onSelect: (i) {
                  setState(() => _sortIndex = i);
                  _runSearch();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return Center(
        child: LumaEmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Could not load products',
          subtitle: _error,
          action: LumaGhostButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            onTap: _runSearch,
          ),
        ),
      );
    }

    if (_loading && _results.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: LumaEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No products found',
          subtitle: 'Try a different search term or store filter.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : (constraints.maxWidth >= 640 ? 3 : (constraints.maxWidth >= 400 ? 2 : 1));
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          itemCount: _results.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.6,
          ),
          itemBuilder: (context, i) {
            final product = _results[i];
            return _ProductCard(
              product: product,
              justAdded: _justAdded.contains(product.id),
              onAdd: () => _addToList(product),
            );
          },
        );
      },
    );
  }

  Future<void> _editServerUrl(BuildContext context) async {
    final api = GroceriesApiScope.of(context);
    final controller = TextEditingController(text: api.baseUrl);
    final luma = context.luma;
    String? error;
    final url = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: luma.surface,
            title: Text('Groceries server address',
                style: TextStyle(color: luma.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: luma.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'https://groceries.example.com',
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
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: TextStyle(color: luma.danger, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
              ),
              TextButton(
                onPressed: () {
                  final validationError =
                      GroceriesApi.validateServerUrl(controller.text);
                  if (validationError != null) {
                    setDialogState(() => error = validationError);
                    return;
                  }
                  Navigator.pop(context, controller.text);
                },
                child: Text('Save', style: TextStyle(color: luma.accent)),
              ),
            ],
          );
        },
      ),
    );
    if (url == null) return;
    await api.setBaseUrl(url);
    _runSearch();
  }
}

/// Light, near-white backdrop behind product photography (AH-style "photo
/// tile"). Fixed rather than theme-derived: almost all catalog photos are
/// shot on a white/light background, so this keeps them reading as an
/// intentional tile in both luma themes instead of a mismatched white box.
const _photoTileColor = Color(0xFFF3F0FA);
const _photoTileIconColor = Color(0xFF9791A8);

/// Also fixed rather than theme-derived, so the sale ribbon keeps enough
/// contrast for white text against both luma themes' `danger` hue.
const _saleBadgeColor = Color(0xFFE0374B);

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    required this.product,
    required this.justAdded,
    required this.onAdd,
  });

  final RemoteProduct product;
  final bool justAdded;
  final VoidCallback onAdd;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _hovering = false;

  String _discountLabel(RemoteProduct product) {
    final pct = product.discountPercentage;
    if (pct != null && pct > 0) return '-${pct.round()}%';
    final text = product.discountText?.trim();
    if (text != null && text.isNotEmpty) return text;
    return 'Sale';
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final product = widget.product;
    final marketColor = colorForMarket(product.market.slug, luma);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: luma.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovering ? luma.accent.withValues(alpha: 0.55) : luma.border,
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: _photoTileColor,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(12),
                        child: product.imageUrl == null
                            ? const Icon(Icons.image_not_supported_outlined,
                                color: _photoTileIconColor, size: 28)
                            : Image.network(
                                product.imageUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: _photoTileIconColor,
                                  size: 28,
                                ),
                              ),
                      ),
                    ),
                  ),
                  // Sale ribbon: the one real "relevance" signal this catalog
                  // has, so it doubles as the visual explanation for why a
                  // discounted item is sorted near the top.
                  if (product.isDiscounted)
                    Positioned(
                      left: 6,
                      top: 6,
                      right: 6,
                      child: Row(
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _saleBadgeColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _discountLabel(product),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: marketColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    product.market.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            product.price == null
                                ? '—'
                                : '€${product.price!.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (product.isDiscounted && product.oldPrice != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '€${product.oldPrice!.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: luma.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (product.quantity != null && product.quantity!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          product.quantity!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: luma.textMuted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onAdd,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: widget.justAdded ? luma.success : luma.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.justAdded ? Icons.check_rounded : Icons.add_rounded,
                        color: luma.onAccent,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
