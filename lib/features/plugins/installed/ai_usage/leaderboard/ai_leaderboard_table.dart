
import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import 'ai_catalog_repository.dart';
import 'ai_catalog_scope.dart';
import 'ai_leaderboard_format.dart';
import 'ai_leaderboard_sort.dart';
import 'ai_model.dart';
import 'ai_model_detail_page.dart';

/// The Leaderboard's **Table** view: every model the luma server knows
/// about, ranked, with the ratings and the running costs side by side.
///
/// Works with no account: a snapshot ships in the app bundle, and devices with
/// an approved account quietly swap in a fresher copy from the server (see
/// [AiCatalogRepository]).
class AiLeaderboardTableView extends StatefulWidget {
  const AiLeaderboardTableView({super.key});

  @override
  State<AiLeaderboardTableView> createState() => _AiLeaderboardTableViewState();
}

class _AiLeaderboardTableViewState extends State<AiLeaderboardTableView> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();

  AiLeaderboardColumn _sortBy = AiLeaderboardColumn.llmStats;
  bool _descending = true;
  bool _openOnly = false;
  String? _vendor;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The scope isn't reachable from initState, and the first load has to wait
    // for it. Only ever kicked off once per tab lifetime.
    if (_started) return;
    _started = true;
    AiCatalogScope.of(context).load();
  }

  @override
  void dispose() {
    _search.dispose();
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  void _sort(AiLeaderboardColumn column) {
    setState(() {
      if (_sortBy == column) {
        _descending = !_descending;
      } else {
        _sortBy = column;
        // Ratings read best-first, names read A–Z: default each column to the
        // direction someone actually wants when they first click it.
        _descending = column.defaultDescending;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = AiCatalogScope.of(context);

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (repo.loading) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }

        if (repo.catalog.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: LumaEmptyState(
              icon: Icons.leaderboard_outlined,
              title: 'No model data yet',
              subtitle: repo.canRefresh
                  ? 'The leaderboard could not be loaded. Try again, or ask '
                      'the server operator to refresh the model catalogue.'
                  : 'The bundled model list could not be read. Signing in to '
                      'an approved luma account lets the app download a fresh '
                      'copy instead.',
              action: LumaGhostButton(
                label: repo.refreshing ? 'Refreshing…' : 'Retry',
                icon: Icons.refresh_rounded,
                onTap: repo.refreshing
                    ? null
                    : () => repo.refreshFromServer(force: true),
              ),
            ),
          );
        }

        final rows = filterAndSortModels(
          repo.catalog.models,
          query: _search.text,
          vendor: _vendor,
          openWeightsOnly: _openOnly,
          sortBy: _sortBy,
          descending: _descending,
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterBar(
                search: _search,
                onSearchChanged: (_) => setState(() {}),
                vendors: vendorsOf(repo.catalog.models),
                vendor: _vendor,
                onVendor: (v) => setState(() => _vendor = v),
                openOnly: _openOnly,
                onOpenOnly: (v) => setState(() => _openOnly = v),
                shown: rows.length,
                total: repo.catalog.models.length,
                repo: repo,
              ),
              const SizedBox(height: 14),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          'No model matches those filters.',
                          style: TextStyle(color: context.luma.textMuted),
                        ),
                      )
                    : _LeaderboardTable(
                        rows: rows,
                        sortBy: _sortBy,
                        descending: _descending,
                        onSort: _sort,
                        vertical: _vertical,
                        horizontal: _horizontal,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Filter bar ─────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.search,
    required this.onSearchChanged,
    required this.vendors,
    required this.vendor,
    required this.onVendor,
    required this.openOnly,
    required this.onOpenOnly,
    required this.shown,
    required this.total,
    required this.repo,
  });

  final TextEditingController search;
  final ValueChanged<String> onSearchChanged;
  final List<({String key, String name})> vendors;
  final String? vendor;
  final ValueChanged<String?> onVendor;
  final bool openOnly;
  final ValueChanged<bool> onOpenOnly;
  final int shown;
  final int total;
  final AiCatalogRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // Wrap, not Row: the controls flow onto a second line on a narrow window
    // rather than overflowing off the right edge.
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            // Never wider than the pane it sits in.
            width: constraints.maxWidth.isFinite && constraints.maxWidth < 240
                ? constraints.maxWidth
                : 240,
            height: 38,
            child: TextField(
            controller: search,
            onChanged: onSearchChanged,
            style: TextStyle(color: luma.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search models',
              hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
              prefixIcon:
                  Icon(Icons.search_rounded, size: 18, color: luma.textMuted),
              filled: true,
              fillColor: luma.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: luma.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: luma.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: luma.accent),
              ),
            ),
          ),
          ),
          _VendorMenu(vendors: vendors, selected: vendor, onSelect: onVendor),
          _OpenWeightsToggle(value: openOnly, onChanged: onOpenOnly),
          Text(
            shown == total ? '$total models' : '$shown of $total models',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          // Refreshing is an operator action (the admin dashboard's
          // Maintenance tab), not something every client re-triggers — this
          // just states how current the data already is.
          _FreshnessLabel(repo: repo),
        ],
      ),
    );
  }
}

/// Says how old the numbers are and where they came from — a leaderboard that
/// doesn't date itself invites people to trust a stale price.
class _FreshnessLabel extends StatelessWidget {
  const _FreshnessLabel({required this.repo});

  final AiCatalogRepository repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final origin = switch (repo.source) {
      AiCatalogSource.bundled => 'shipped with this version',
      AiCatalogSource.cached => 'from your last sync',
      AiCatalogSource.server => 'from the luma server',
    };
    final at = repo.refreshedAt;
    final text = at == null ? origin : '${relativeDay(at)} · $origin';
    return Tooltip(
      message: repo.error ?? 'Model data $text',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (repo.error != null) ...[
            Icon(Icons.cloud_off_rounded, size: 14, color: luma.textMuted),
            const SizedBox(width: 5),
          ],
          Text(text, style: TextStyle(color: luma.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _VendorMenu extends StatelessWidget {
  const _VendorMenu({
    required this.vendors,
    required this.selected,
    required this.onSelect,
  });

  final List<({String key, String name})> vendors;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final label = selected == null
        ? 'All providers'
        : vendors.firstWhere((v) => v.key == selected).name;
    return PopupMenuButton<String?>(
      tooltip: 'Filter by provider',
      onSelected: (v) => onSelect(v == '' ? null : v),
      color: luma.surface,
      itemBuilder: (context) => [
        const PopupMenuItem(value: '', child: Text('All providers')),
        for (final v in vendors)
          PopupMenuItem(value: v.key, child: Text(v.name)),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: luma.surface,
          border: Border.all(color: luma.border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(color: luma.textPrimary, fontSize: 13)),
            const SizedBox(width: 6),
            Icon(Icons.expand_more_rounded, size: 18, color: luma.textMuted),
          ],
        ),
      ),
    );
  }
}

class _OpenWeightsToggle extends StatelessWidget {
  const _OpenWeightsToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: 'Show only models whose weights you can download',
      child: Material(
        color: value ? luma.accentSubtle : luma.surface,
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: value ? luma.accent : luma.border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_open_rounded,
                    size: 16, color: value ? luma.accent : luma.textMuted),
                const SizedBox(width: 7),
                Text(
                  'Open weights',
                  style: TextStyle(
                    color: value ? luma.textPrimary : luma.textSecondary,
                    fontSize: 13,
                    fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Table ──────────────────────────────────────────────────────────────────

/// Column widths, in the order the table renders them. Fixed rather than
/// flexible so the header and every row line up while the whole table scrolls
/// sideways on a narrow window. Each is sized to its own header *label*, not
/// just its data — "CODE ARENA" and "LLM STATS" are the longest words in the
/// row and set the floor other columns don't need.
///
/// These are the *minimums*; on a wide pane [_ColumnWidths.forWidth] grows
/// them — see there for how the extra space is split.
const double _wRank = 58;
const double _wModel = 220;
const double _wScore = 100;
const double _wArena = 104;
const double _wParams = 80;
const double _wContext = 90;
const double _wPrice = 96;
const double _wLicense = 78;
const double _tableWidth = _wRank +
    _wModel +
    _wScore * 3 +
    _wArena +
    _wParams +
    _wContext +
    _wPrice +
    _wLicense;

/// How much wider than its minimum the model name column is allowed to grow.
/// Long names still get a little more room on a wide pane, but the column
/// isn't the thing that should soak up most of the window — the data
/// columns are, so they stay legible instead of pinned at their minimum.
const double _wModelMaxGrowth = 140;

/// The widths actually used for one layout pass: the minimums above on a
/// narrow window, grown to fill a wide one. The model column takes a capped
/// share of the extra space ([_wModelMaxGrowth]); everything past that is
/// split across the data columns in proportion to their own minimum width,
/// so a wide pane reads more comfortably everywhere rather than just growing
/// the name column into empty space.
class _ColumnWidths {
  const _ColumnWidths({
    required this.model,
    required this.score,
    required this.arena,
    required this.params,
    required this.context,
    required this.price,
  });

  factory _ColumnWidths.forWidth(double maxWidth) {
    final slack = maxWidth - _tableWidth;
    if (slack <= 0) {
      return const _ColumnWidths(
        model: _wModel,
        score: _wScore,
        arena: _wArena,
        params: _wParams,
        context: _wContext,
        price: _wPrice,
      );
    }
    final modelGrowth = slack < _wModelMaxGrowth ? slack : _wModelMaxGrowth;
    final remaining = slack - modelGrowth;
    const flexBase = _wScore * 3 + _wArena + _wParams + _wContext + _wPrice;
    final scale = 1 + remaining / flexBase;
    return _ColumnWidths(
      model: _wModel + modelGrowth,
      score: _wScore * scale,
      arena: _wArena * scale,
      params: _wParams * scale,
      context: _wContext * scale,
      price: _wPrice * scale,
    );
  }

  final double model;
  final double score;
  final double arena;
  final double params;
  final double context;
  final double price;
}

class _LeaderboardTable extends StatelessWidget {
  const _LeaderboardTable({
    required this.rows,
    required this.sortBy,
    required this.descending,
    required this.onSort,
    required this.vertical,
    required this.horizontal,
  });

  final List<AiModel> rows;
  final AiLeaderboardColumn sortBy;
  final bool descending;
  final ValueChanged<AiLeaderboardColumn> onSort;
  final ScrollController vertical;
  final ScrollController horizontal;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LayoutBuilder(
      builder: (context, constraints) {
        // On a window wider than the table's minimum width, the columns grow
        // to fill the pane instead of leaving a blank strip of card
        // background past the License column. On a narrower window
        // everything stays at its minimum and the table scrolls sideways as
        // usual — nothing here changes that.
        final fills = constraints.maxWidth > _tableWidth;
        final widths = _ColumnWidths.forWidth(constraints.maxWidth);
        final contentWidth = fills ? constraints.maxWidth : _tableWidth;

        return Container(
          decoration: BoxDecoration(
            color: luma.surface,
            border: Border.all(color: luma.border),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Scrollbar(
            controller: horizontal,
            // Nothing to scroll once the columns have absorbed the slack — a
            // full-width thumb representing 100% coverage would just be
            // visual noise.
            thumbVisibility: !fills,
            child: SingleChildScrollView(
              controller: horizontal,
              scrollDirection: Axis.horizontal,
              physics: fills ? const NeverScrollableScrollPhysics() : null,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderRow(
                      sortBy: sortBy,
                      descending: descending,
                      onSort: onSort,
                      widths: widths,
                    ),
                    Container(height: 1, color: luma.border),
                    Expanded(
                      child: Scrollbar(
                        controller: vertical,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: vertical,
                          // 324 rows today and growing with every model
                          // release — built lazily so scrolling stays smooth.
                          itemCount: rows.length,
                          itemExtent: 52,
                          itemBuilder: (context, i) => _ModelRow(
                            model: rows[i],
                            rank: i + 1,
                            widths: widths,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.sortBy,
    required this.descending,
    required this.onSort,
    required this.widths,
  });

  final AiLeaderboardColumn sortBy;
  final bool descending;
  final ValueChanged<AiLeaderboardColumn> onSort;
  final _ColumnWidths widths;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 44,
      color: luma.rail,
      child: Row(
        children: [
          _HeaderCell(
              column: AiLeaderboardColumn.rank,
              width: _wRank,
              sortBy: sortBy,
              descending: descending,
              onSort: onSort),
          _HeaderCell(
              column: AiLeaderboardColumn.name,
              width: widths.model,
              align: TextAlign.left,
              sortBy: sortBy,
              descending: descending,
              onSort: onSort),
          for (final column in const [
            AiLeaderboardColumn.llmStats,
            AiLeaderboardColumn.coding,
            AiLeaderboardColumn.agent,
          ])
            _HeaderCell(
                column: column,
                width: widths.score,
                sortBy: sortBy,
                descending: descending,
                onSort: onSort),
          _HeaderCell(
              column: AiLeaderboardColumn.codeArena,
              width: widths.arena,
              sortBy: sortBy,
              descending: descending,
              onSort: onSort),
          _HeaderCell(
              column: AiLeaderboardColumn.params,
              width: widths.params,
              sortBy: sortBy,
              descending: descending,
              onSort: onSort),
          _HeaderCell(
              column: AiLeaderboardColumn.context,
              width: widths.context,
              sortBy: sortBy,
              descending: descending,
              onSort: onSort),
          _HeaderCell(
              column: AiLeaderboardColumn.price,
              width: widths.price,
              sortBy: sortBy,
              descending: descending,
              onSort: onSort),
          _HeaderCell(
              column: AiLeaderboardColumn.license,
              width: _wLicense,
              sortBy: sortBy,
              descending: descending,
              onSort: onSort),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.width,
    required this.sortBy,
    required this.descending,
    required this.onSort,
    this.align = TextAlign.right,
  });

  final AiLeaderboardColumn column;
  final double width;
  final AiLeaderboardColumn sortBy;
  final bool descending;
  final ValueChanged<AiLeaderboardColumn> onSort;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final active = sortBy == column;
    return SizedBox(
      width: width,
      child: Tooltip(
        message: column.help,
        waitDuration: const Duration(milliseconds: 300),
        child: Semantics(
          // The sort state has to be announced, not just drawn as an arrow.
          label: active
              ? '${column.label}, sorted '
                  '${descending ? "descending" : "ascending"}'
              : '${column.label}, not sorted',
          button: true,
          child: InkWell(
            onTap: () => onSort(column),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: align == TextAlign.left
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      column.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? luma.textPrimary : luma.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 2),
                    Icon(
                      descending
                          ? Icons.arrow_drop_down_rounded
                          : Icons.arrow_drop_up_rounded,
                      size: 16,
                      color: luma.accent,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.rank,
    required this.widths,
  });

  final AiModel model;
  final int rank;
  final _ColumnWidths widths;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AiModelDetailPage(modelId: model.id),
      )),
      child: Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: luma.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _wRank,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '$rank',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          SizedBox(
            width: widths.model,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    model.vendorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          _ScoreCell(value: model.llmStatsIndex, width: widths.score),
          _ScoreCell(value: model.codingIndex, width: widths.score),
          _ScoreCell(value: model.agentIndex, width: widths.score),
          _NumberCell(
            width: widths.arena,
            text: model.codeArena?.round().toString(),
          ),
          _NumberCell(width: widths.params, text: formatParams(model.parametersB)),
          _NumberCell(width: widths.context, text: formatTokens(model.contextTokens)),
          _NumberCell(width: widths.price, text: formatPrice(model.avgPricePerM)),
          _LicenseCell(model: model),
        ],
      ),
      ),
    );
  }
}

/// One of the four rating columns. The number is always spelled out; the tint
/// behind it is a secondary cue, never the only one.
class _ScoreCell extends StatelessWidget {
  const _ScoreCell({required this.value, required this.width});

  final double? value;
  final double width;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (value == null) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('–',
              textAlign: TextAlign.right,
              style: TextStyle(color: luma.textMuted, fontSize: 13)),
        ),
      );
    }
    // Indices run 0–100 in practice but cluster in the upper half, so the
    // tint is stretched over 30–80 to make the top of the board legible.
    final t = ((value! - 30) / 50).clamp(0.0, 1.0);
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: luma.accent.withValues(alpha: 0.10 + 0.22 * t),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value!.toStringAsFixed(1),
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberCell extends StatelessWidget {
  const _NumberCell({required this.width, required this.text});

  final double width;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          text ?? '–',
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: text == null ? luma.textMuted : luma.textSecondary,
            fontSize: 12.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Open padlock = the weights are downloadable. Icon plus a tooltip naming
/// the licence, so the meaning never rests on the glyph alone.
class _LicenseCell extends StatelessWidget {
  const _LicenseCell({required this.model});

  final AiModel model;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final open = model.openWeights;
    final label = open
        ? 'Open weights${model.licenseName == null ? "" : " · ${model.licenseName}"}'
        : 'Proprietary — API access only';
    return SizedBox(
      width: _wLicense,
      child: Center(
        child: Tooltip(
          message: label,
          child: Semantics(
            label: label,
            child: Icon(
              open ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 17,
              color: open ? luma.success : luma.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
