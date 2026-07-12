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
  const ProductSearchPage({super.key, required this.listId});

  final int listId;

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

    return Scaffold(
      backgroundColor: luma.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: luma.textPrimary),
                    tooltip: 'Back to list',
                    onPressed: () => Navigator.of(context).pop(),
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
        ),
      ),
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
            childAspectRatio: 0.72,
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.justAdded,
    required this.onAdd,
  });

  final RemoteProduct product;
  final bool justAdded;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final marketColor = colorForMarket(product.market.slug, luma);

    return LumaCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.imageUrl == null
                  ? Container(
                      color: luma.background,
                      child: Icon(Icons.image_not_supported_outlined,
                          color: luma.textMuted),
                    )
                  : Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: luma.background,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: luma.textMuted),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
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
                child: Text(
                  product.price == null ? '—' : '€${product.price!.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: justAdded ? luma.success : luma.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      justAdded ? Icons.check_rounded : Icons.add_rounded,
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
    );
  }
}
