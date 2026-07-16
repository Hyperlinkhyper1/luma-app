import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'groceries_api.dart';
import 'groceries_scope.dart';
import 'market_style.dart';

// Lidl has no real product feed yet (LidlSync is a stub — see
// supermarket-db/src/supermarkets/lidl/sync.js), so its filter tab would
// always show zero results. Left out until that catalog actually exists.
const _marketFilters = <String?>[null, 'jumbo', 'ah'];
const _marketFilterLabels = ['All stores', 'Jumbo', 'Albert Heijn'];
const _sortOptions = [ProductSort.relevance, ProductSort.priceAsc, ProductSort.priceDesc];
const _sortLabels = ['Relevance', 'Price ↑', 'Price ↓'];

/// Search Jumbo/Albert Heijn products (via the supermarket-db API), filter by
/// store, sort by price, and add results straight onto [listId].
class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({super.key, required this.listId, required this.onBack});

  final int listId;
  final VoidCallback onBack;

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

const _pageSize = 40;

class _ProductSearchPageState extends State<ProductSearchPage> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  int _marketIndex = 0;
  int _sortIndex = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  List<RemoteProduct> _results = const [];
  final Set<String> _justAdded = {};

  List<ProductCategory> _categories = const [];
  String? _categoryFilter;
  bool _onlyDeals = false;

  @override
  void initState() {
    super.initState();
    _runSearch();
    _fetchCategories();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  void _onScroll() {
    if (!_hasMore || _loading || _loadingMore) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 600) {
      return;
    }
    _loadMore();
  }

  Future<void> _runSearch() async {
    final api = GroceriesApiScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final results = await api.search(
        query: _queryController.text,
        marketSlugs: _marketFilters[_marketIndex] == null
            ? null
            : [_marketFilters[_marketIndex]!],
        category: _categoryFilter,
        onlyDeals: _onlyDeals,
        sort: _sortOptions[_sortIndex],
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _hasMore = results.length >= _pageSize;
      });
    } on GroceriesApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Fetches the next page and appends it, for infinite scroll. Uses the
  /// same filters as the last [_runSearch] — [_results].length is the
  /// correct next offset since pages are fetched strictly in order.
  Future<void> _loadMore() async {
    final api = GroceriesApiScope.of(context);
    setState(() => _loadingMore = true);
    try {
      final more = await api.search(
        query: _queryController.text,
        marketSlugs: _marketFilters[_marketIndex] == null
            ? null
            : [_marketFilters[_marketIndex]!],
        category: _categoryFilter,
        onlyDeals: _onlyDeals,
        sort: _sortOptions[_sortIndex],
        limit: _pageSize,
        offset: _results.length,
      );
      if (!mounted) return;
      setState(() {
        _results = [..._results, ...more];
        _hasMore = more.length >= _pageSize;
      });
    } on GroceriesApiException {
      // Leave already-loaded results up; just stop trying to page further.
      if (mounted) setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Sidebar departments, scoped to the current store filter. A failure here
  /// shouldn't block the product grid itself, so it just leaves the sidebar
  /// list as-is instead of surfacing an error.
  Future<void> _fetchCategories() async {
    final api = GroceriesApiScope.of(context);
    try {
      final categories = await api.fetchCategories(
        marketSlugs: _marketFilters[_marketIndex] == null
            ? null
            : [_marketFilters[_marketIndex]!],
      );
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (_categoryFilter != null &&
            !categories.any((c) => c.name == _categoryFilter)) {
          _categoryFilter = null;
        }
      });
    } on GroceriesApiException {
      // Keep whatever categories were already loaded.
    }
  }

  void _onCategorySelected(String? category) {
    setState(() => _categoryFilter = category);
    _runSearch();
  }

  void _onToggleOnlyDeals(bool value) {
    setState(() => _onlyDeals = value);
    _runSearch();
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
                    _fetchCategories();
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
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Below this, a permanent 180px sidebar leaves the grid too
              // narrow to be usable (phones, narrow split-screen). Collapse
              // categories into a sheet instead of reserving space for them.
              if (constraints.maxWidth < 700) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: _CompactFiltersBar(
                        categories: _categories,
                        selected: _categoryFilter,
                        onlyDeals: _onlyDeals,
                        onSelect: _onCategorySelected,
                        onToggleDeals: _onToggleOnlyDeals,
                      ),
                    ),
                    Expanded(child: _buildBody(context)),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(width: 24),
                  _CategorySidebar(
                    categories: _categories,
                    selected: _categoryFilter,
                    onlyDeals: _onlyDeals,
                    onSelect: _onCategorySelected,
                    onToggleDeals: _onToggleOnlyDeals,
                  ),
                  Expanded(child: _buildBody(context)),
                ],
              );
            },
          ),
        ),
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
          subtitle: 'Try a different search term, store or category filter.',
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 24, 12),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              // 5 columns is the normal/wide-window case (matches the AH
              // reference); narrower windows step down so cards don't get
              // crushed — down to 2 on a phone.
              final columns = constraints.crossAxisExtent >= 1000
                  ? 5
                  : (constraints.crossAxisExtent >= 800
                      ? 4
                      : (constraints.crossAxisExtent >= 600
                          ? 3
                          : (constraints.crossAxisExtent >= 300 ? 2 : 1)));
              const spacing = 8.0;
              final columnWidth =
                  (constraints.crossAxisExtent - spacing * (columns - 1)) / columns;
              // The card's text block (name/price/quantity/button) is a
              // roughly fixed height regardless of column width, so a
              // single fixed aspect ratio either overflows on narrow phone
              // columns or leaves a dead gap on wide desktop ones. Solve
              // for the ratio that keeps a small, constant margin instead
              // — 90 is the card's real (measured, not just computed)
              // fixed overhead below the image.
              final aspect = (columnWidth / (columnWidth + 90)).clamp(0.45, 0.82);
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: aspect,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final product = _results[i];
                    return _ProductCard(
                      product: product,
                      justAdded: _justAdded.contains(product.id),
                      onAdd: () => _addToList(product),
                    );
                  },
                  childCount: _results.length,
                ),
              );
            },
          ),
        ),
        if (_loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            ),
          ),
      ],
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

/// Narrow-width stand-in for [_CategorySidebar]: a compact bar that opens
/// the same category list in a bottom sheet instead of reserving a
/// permanent 180px column, so the grid keeps enough room for 2 columns on
/// a phone.
class _CompactFiltersBar extends StatelessWidget {
  const _CompactFiltersBar({
    required this.categories,
    required this.selected,
    required this.onlyDeals,
    required this.onSelect,
    required this.onToggleDeals,
  });

  final List<ProductCategory> categories;
  final String? selected;
  final bool onlyDeals;
  final ValueChanged<String?> onSelect;
  final ValueChanged<bool> onToggleDeals;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _openCategorySheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: luma.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: luma.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.category_outlined, size: 16, color: luma.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selected ?? 'All products',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, size: 18, color: luma.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 132, child: _DealsToggleRow(value: onlyDeals, onChanged: onToggleDeals)),
      ],
    );
  }

  void _openCategorySheet(BuildContext context) {
    final luma = context.luma;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: luma.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categories',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _CategoryRow(
                          label: 'All products',
                          selected: selected == null,
                          onTap: () {
                            onSelect(null);
                            Navigator.pop(sheetContext);
                          },
                        ),
                        for (final category in categories)
                          _CategoryRow(
                            label: category.name,
                            count: category.count,
                            selected: selected == category.name,
                            onTap: () {
                              onSelect(category.name);
                              Navigator.pop(sheetContext);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Left-hand department filter + "only deals" toggle, AH-style. Stays
/// visible across loading/error/empty states of the grid next to it, since
/// switching filters is how you'd typically get out of an empty result.
class _CategorySidebar extends StatelessWidget {
  const _CategorySidebar({
    required this.categories,
    required this.selected,
    required this.onlyDeals,
    required this.onSelect,
    required this.onToggleDeals,
  });

  final List<ProductCategory> categories;
  final String? selected;
  final bool onlyDeals;
  final ValueChanged<String?> onSelect;
  final ValueChanged<bool> onToggleDeals;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SizedBox(
      width: 180,
      child: ListView(
        padding: const EdgeInsets.only(right: 12, top: 2),
        children: [
          _DealsToggleRow(value: onlyDeals, onChanged: onToggleDeals),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 6),
            child: Text(
              'CATEGORIES',
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          _CategoryRow(
            label: 'All products',
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final category in categories)
            _CategoryRow(
              label: category.name,
              count: category.count,
              selected: selected == category.name,
              onTap: () => onSelect(category.name),
            ),
        ],
      ),
    );
  }
}

class _DealsToggleRow extends StatelessWidget {
  const _DealsToggleRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: value ? _saleBadgeColor.withValues(alpha: 0.14) : luma.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: value ? _saleBadgeColor : luma.border),
          ),
          child: Row(
            children: [
              Icon(Icons.sell_rounded,
                  size: 15, color: value ? _saleBadgeColor : luma.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Only deals',
                  style: TextStyle(
                    color: value ? _saleBadgeColor : luma.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _MiniSwitch(value: value),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 30,
      height: 17,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? _saleBadgeColor : luma.border,
        borderRadius: BorderRadius.circular(9),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 13,
          height: 13,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? luma.accentSubtle
                : (_hovering ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? luma.accent : luma.textSecondary,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '${widget.count}',
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: luma.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovering ? luma.accent.withValues(alpha: 0.55) : luma.border,
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
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
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: _photoTileColor,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(8),
                        child: product.imageUrl == null
                            ? const Icon(Icons.image_not_supported_outlined,
                                color: _photoTileIconColor, size: 22)
                            : Image.network(
                                product.imageUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: _photoTileIconColor,
                                  size: 22,
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
                      left: 5,
                      top: 5,
                      right: 5,
                      child: Row(
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: _saleBadgeColor,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _discountLabel(product),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
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
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: marketColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    product.market.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.textMuted, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
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
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (product.isDiscounted && product.oldPrice != null) ...[
                            const SizedBox(width: 5),
                            Text(
                              '€${product.oldPrice!.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: luma.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (product.quantity != null && product.quantity!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          product.quantity!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: luma.textMuted, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onAdd,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: widget.justAdded ? luma.success : luma.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.justAdded ? Icons.check_rounded : Icons.add_rounded,
                        color: luma.onAccent,
                        size: 15,
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
