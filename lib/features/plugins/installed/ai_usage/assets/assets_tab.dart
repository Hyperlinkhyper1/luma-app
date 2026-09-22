import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import 'asset_studio.dart';
import 'asset_studio_view.dart';

/// The plugin's **Assets** section: every procedural model made for the
/// airport game, each opening in the asset studio (a live 3D preview with
/// its source, footprint checks and export) and downloadable as a
/// self-contained HTML file.
class AssetsTab extends StatefulWidget {
  const AssetsTab({super.key});

  @override
  State<AssetsTab> createState() => _AssetsTabState();
}

class _AssetsTabState extends State<AssetsTab> {
  late final Future<List<StudioAsset>> _catalog = loadStudioCatalog(
    rootBundle,
  );
  StudioAsset? _open;

  @override
  Widget build(BuildContext context) {
    final open = _open;
    if (open != null) {
      return _AssetDetail(
        key: ValueKey(open.id),
        asset: open,
        onBack: () => setState(() => _open = null),
      );
    }
    return FutureBuilder<List<StudioAsset>>(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return LumaEmptyState(
            icon: Icons.warning_amber_rounded,
            title: 'Could not load the assets',
            subtitle: '${snapshot.error}',
          );
        }
        final assets = snapshot.data;
        if (assets == null) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return _AssetGallery(
          assets: assets,
          onOpen: (a) => setState(() => _open = a),
        );
      },
    );
  }
}

// ── Gallery ───────────────────────────────────────────────────────────────

/// Look of each catalogue category: an icon and a tint for its tile.
({IconData icon, Color tint}) _categoryStyle(String category) =>
    switch (category) {
      'retail' => (icon: Icons.shopping_bag_outlined, tint: const Color(0xFFC6A15B)),
      'food' => (icon: Icons.local_cafe_outlined, tint: const Color(0xFFB9774E)),
      'entertainment' => (icon: Icons.sports_esports_outlined, tint: const Color(0xFF8C6BB1)),
      'security' => (icon: Icons.verified_user_outlined, tint: const Color(0xFF4F7FA8)),
      'passenger' => (icon: Icons.flight_takeoff_rounded, tint: const Color(0xFF3F8C86)),
      _ => (icon: Icons.chair_outlined, tint: const Color(0xFF6B8F5E)),
    };

String _categoryLabel(String c) => c[0].toUpperCase() + c.substring(1);

class _AssetGallery extends StatefulWidget {
  const _AssetGallery({required this.assets, required this.onOpen});

  final List<StudioAsset> assets;
  final ValueChanged<StudioAsset> onOpen;

  @override
  State<_AssetGallery> createState() => _AssetGalleryState();
}

class _AssetGalleryState extends State<_AssetGallery> {
  final _search = TextEditingController();
  String _category = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final seen = <String>{};
    return [
      for (final a in widget.assets)
        if (seen.add(a.category)) a.category,
    ];
  }

  List<StudioAsset> get _visible {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final a in widget.assets)
        if ((_category == 'all' || a.category == _category) &&
            (q.isEmpty ||
                a.name.toLowerCase().contains(q) ||
                a.keywords.toLowerCase().contains(q) ||
                a.description.toLowerCase().contains(q)))
          a,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final categories = _categories;
    final visible = _visible;
    final phone = context.isPhoneWidth;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(phone ? 16 : 28, 24, phone ? 16 : 28, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assets',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.assets.length} procedural models from the airport '
                  'game. Open one to inspect it in 3D, or download it as an '
                  'HTML file.',
                  style: TextStyle(color: luma.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search models',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CategoryChip(
                      label: 'All',
                      count: widget.assets.length,
                      selected: _category == 'all',
                      onTap: () => setState(() => _category = 'all'),
                    ),
                    for (final c in categories)
                      _CategoryChip(
                        label: _categoryLabel(c),
                        count: widget.assets.where((a) => a.category == c).length,
                        selected: _category == c,
                        onTap: () => setState(() => _category = c),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: LumaEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No models match',
              subtitle: 'Try another name or clear the filter.',
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(phone ? 16 : 28, 0, phone ? 16 : 28, 28),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                mainAxisExtent: 268,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: visible.length,
              itemBuilder: (context, i) => _AssetCard(
                asset: visible[i],
                onTap: () => widget.onOpen(visible[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? luma.accentSubtle : luma.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? luma.accent : luma.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: luma.surfaceHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              '$label  $count',
              style: TextStyle(
                color: selected ? luma.accent : luma.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssetCard extends StatefulWidget {
  const _AssetCard({required this.asset, required this.onTap});

  final StudioAsset asset;
  final VoidCallback onTap;

  @override
  State<_AssetCard> createState() => _AssetCardState();
}

class _AssetCardState extends State<_AssetCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final a = widget.asset;
    final style = _categoryStyle(a.category);
    return Semantics(
      button: true,
      label: 'Open ${a.name}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hover ? style.tint.withValues(alpha: .7) : luma.border,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Thumbnail(asset: a, tint: style.tint, icon: style.icon),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              a.keywords,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                          // Both halves can shrink: "14 × 10 m" next to
                          // "Entertainment" does not fit a narrow card.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.straighten_rounded,
                                      size: 14,
                                      color: luma.textMuted,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        a.footprint,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: luma.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _categoryLabel(a.category),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    color: style.tint,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The baked isometric render, on a soft wash of its category colour.
///
/// The image has a transparent background, so it sits on the card in both
/// themes; the icon stands in while it decodes or if it is ever missing.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.asset, required this.tint, required this.icon});

  final StudioAsset asset;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SizedBox(
      height: 132,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tint.withValues(alpha: .14),
                  tint.withValues(alpha: .04),
                ],
              ),
            ),
          ),
          Center(child: Icon(icon, size: 26, color: tint.withValues(alpha: .35))),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              asset.thumbnail,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              errorBuilder: (context, _, _) => const SizedBox.shrink(),
            ),
          ),
          Positioned(
            top: 8,
            right: 10,
            child: Text(
              asset.collectionCode,
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 10,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail ────────────────────────────────────────────────────────────────

class _AssetDetail extends StatefulWidget {
  const _AssetDetail({super.key, required this.asset, required this.onBack});

  final StudioAsset asset;
  final VoidCallback onBack;

  @override
  State<_AssetDetail> createState() => _AssetDetailState();
}

class _AssetDetailState extends State<_AssetDetail> {
  bool _saving = false;
  String? _status;
  Timer? _statusTimer;

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  /// The status sits in the header rather than a snackbar: on Windows the
  /// studio is a native window that would cover one.
  void _flash(String message) {
    _statusTimer?.cancel();
    setState(() => _status = message);
    _statusTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _status = null);
    });
  }

  Future<void> _download() async {
    setState(() => _saving = true);
    try {
      final html = await buildAssetStudioHtml(
        rootBundle,
        assetId: widget.asset.id,
      );
      final path = await saveStudioFile(
        widget.asset.htmlFileName,
        Uint8List.fromList(utf8.encode(html)),
      );
      if (mounted && path != null) _flash('Saved ${widget.asset.htmlFileName}');
    } catch (e) {
      if (mounted) _flash('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final a = widget.asset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to assets',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _status ??
                          '${_categoryLabel(a.category)} · ${a.collectionCode} · ${a.footprint}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _status != null ? luma.accent : luma.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'A single HTML file that opens this model offline in any browser',
                child: LumaPrimaryButton(
                  label: context.isPhoneWidth ? 'HTML' : 'Download HTML',
                  icon: Icons.download_rounded,
                  loading: _saving,
                  onTap: _saving ? null : _download,
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: luma.border),
        Expanded(child: AssetStudioView(asset: a)),
      ],
    );
  }
}
