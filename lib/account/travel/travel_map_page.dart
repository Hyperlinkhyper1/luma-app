import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../settings/settings_controller.dart';
import '../../settings/settings_scope.dart';
import '../../theme/luma_theme.dart';
import 'fullscreen_map_page.dart';
import 'world_map_data.dart';
import 'world_map_view.dart';

/// Full-page travel map: tap countries on the world map (or tick them off
/// the list) to build up the places you've been.
class TravelMapPage extends StatefulWidget {
  const TravelMapPage({super.key});

  @override
  State<TravelMapPage> createState() => _TravelMapPageState();
}

class _TravelMapPageState extends State<TravelMapPage> {
  late final Future<WorldMap> _map = WorldMap.load();
  final _view = TransformationController();
  final _searchController = TextEditingController();
  String _search = '';

  /// The outline once it has loaded, so the app bar's fullscreen action can
  /// hand it straight to [FullscreenMapPage].
  WorldMap? _loaded;

  /// Below this the map and the country list stack instead of sitting
  /// side by side.
  static const _sideBySideBreakpoint = 900.0;

  @override
  void initState() {
    super.initState();
    _map.then(
      (map) {
        if (mounted) setState(() => _loaded = map);
      },
      // Errors are surfaced by the FutureBuilder below; this listener only
      // exists to keep the app bar action in sync.
      onError: (_) {},
    );
  }

  Future<void> _openFullscreen(WorldMap map) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FullscreenMapPage(map: map)),
    );
  }

  @override
  void dispose() {
    _view.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final settings = SettingsScope.of(context);

    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Travel map'),
        actions: [
          IconButton(
            tooltip: 'Reset zoom',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () => _view.value = Matrix4.identity(),
          ),
          IconButton(
            tooltip: 'Fullscreen',
            icon: const Icon(Icons.fullscreen_rounded),
            onPressed: _loaded == null ? null : () => _openFullscreen(_loaded!),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<WorldMap>(
        future: _map,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: LumaEmptyState(
                icon: Icons.public_off_rounded,
                title: 'The map could not be loaded',
                subtitle: '${snapshot.error}',
              ),
            );
          }
          final map = snapshot.data;
          if (map == null) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            );
          }
          return ListenableBuilder(
            listenable: settings,
            builder: (context, _) => _body(context, map, settings),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WorldMap map,
    SettingsController settings,
  ) {
    final visited = settings.visitedCountries.toSet();
    // Codes for countries that are no longer in the map data don't count
    // towards the total — the summary should never read "238 of 237".
    final known = visited.where((code) => map.byCode(code) != null).toSet();

    void toggle(WorldCountry country) =>
        settings.toggleVisitedCountry(country.code);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= _sideBySideBreakpoint;
        final mapPanel = _MapPanel(
          map: map,
          visited: known,
          onToggle: toggle,
          controller: _view,
          onFullscreen: () => _openFullscreen(map),
        );
        final listPanel = _CountryList(
          map: map,
          visited: known,
          onToggle: toggle,
          search: _search,
          searchController: _searchController,
          onSearch: (value) => setState(() => _search = value),
          onClearAll: known.isEmpty ? null : () => _confirmClear(settings),
        );

        if (!sideBySide) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
            children: [
              // Map first on a phone: it's what the page is for, and the
              // summary is a scroll away rather than in front of it.
              mapPanel,
              const SizedBox(height: 14),
              _Summary(map: map, visited: known),
              const SizedBox(height: 14),
              SizedBox(height: 460, child: listPanel),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Summary(map: map, visited: known),
                      const SizedBox(height: 16),
                      mapPanel,
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: listPanel),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClear(SettingsController settings) async {
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: luma.surface,
        title: const Text('Clear the map?'),
        content: const Text(
          'Every country you\'ve marked as visited will be unmarked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Clear', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) settings.setVisitedCountries(const []);
  }
}

// ---- Summary --------------------------------------------------------------

class _Summary extends StatelessWidget {
  const _Summary({required this.map, required this.visited});

  final WorldMap map;
  final Set<String> visited;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final total = map.countries.length;
    final percent = total == 0 ? 0.0 : visited.length / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            luma.accent.withValues(alpha: 0.22),
            luma.accent.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: luma.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                '${visited.length}',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  'of $total countries · ${(percent * 100).toStringAsFixed(0)}% '
                  'of the world',
                  style: TextStyle(color: luma.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final pills = [
                for (final entry in _regionCounts().entries)
                  _RegionPill(
                    region: entry.key,
                    visited: entry.value.$1,
                    total: entry.value.$2,
                  ),
              ];
              // Wrapping seven continents costs three rows on a phone; keep
              // them on one swipeable line there instead.
              if (constraints.maxWidth < 520) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < pills.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        pills[i],
                      ],
                    ],
                  ),
                );
              }
              return Wrap(spacing: 8, runSpacing: 8, children: pills);
            },
          ),
        ],
      ),
    );
  }

  /// (visited, total) per continent, most-visited first.
  Map<String, (int, int)> _regionCounts() {
    final counts = <String, (int, int)>{};
    for (final entry in map.byRegion.entries) {
      final seen =
          entry.value.where((c) => visited.contains(c.code)).length;
      counts[entry.key] = (seen, entry.value.length);
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byVisited = b.value.$1.compareTo(a.value.$1);
        return byVisited != 0 ? byVisited : a.key.compareTo(b.key);
      });
    return {for (final entry in sorted) entry.key: entry.value};
  }
}

class _RegionPill extends StatelessWidget {
  const _RegionPill({
    required this.region,
    required this.visited,
    required this.total,
  });

  final String region;
  final int visited;
  final int total;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final active = visited > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? luma.accentSubtle : luma.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? luma.accent.withValues(alpha: 0.4) : luma.border,
        ),
      ),
      child: Text(
        '$region $visited/$total',
        style: TextStyle(
          color: active ? luma.textPrimary : luma.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---- Map panel ------------------------------------------------------------

class _MapPanel extends StatelessWidget {
  const _MapPanel({
    required this.map,
    required this.visited,
    required this.onToggle,
    required this.controller,
    required this.onFullscreen,
  });

  final WorldMap map;
  final Set<String> visited;
  final ValueChanged<WorldCountry> onToggle;
  final TransformationController controller;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              WorldMapView(
                map: map,
                visited: visited,
                onToggle: onToggle,
                controller: controller,
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: _MapAction(
                  icon: Icons.fullscreen_rounded,
                  tooltip: 'Open fullscreen',
                  onTap: onFullscreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 14, color: luma.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tap a country to mark it visited, tap it again to remove '
                    'it. Pinch to zoom, or open the map fullscreen.',
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small round button floating over the map.
class _MapAction extends StatelessWidget {
  const _MapAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: luma.surface.withValues(alpha: 0.92),
        shape: CircleBorder(side: BorderSide(color: luma.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: luma.textPrimary),
          ),
        ),
      ),
    );
  }
}

// ---- Country list ---------------------------------------------------------

class _CountryList extends StatelessWidget {
  const _CountryList({
    required this.map,
    required this.visited,
    required this.onToggle,
    required this.search,
    required this.searchController,
    required this.onSearch,
    required this.onClearAll,
  });

  final WorldMap map;
  final Set<String> visited;
  final ValueChanged<WorldCountry> onToggle;
  final String search;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final query = search.trim().toLowerCase();
    final matches = query.isEmpty
        ? map.countries
        : map.countries
            .where((c) =>
                c.name.toLowerCase().contains(query) ||
                c.code.toLowerCase() == query)
            .toList();

    return LumaCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  visited.isEmpty ? 'Countries' : 'Countries · ${visited.length}',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onClearAll != null)
                TextButton(
                  onPressed: onClearAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Clear all',
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: searchController,
            onChanged: onSearch,
            style: TextStyle(color: luma.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search a country',
              hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, size: 18,
                  color: luma.textMuted),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 34, minHeight: 34),
              filled: true,
              fillColor: luma.surfaceHover,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (visited.isNotEmpty) ...[
            const SizedBox(height: 10),
            _VisitedChips(
              countries: [
                for (final country in map.countries)
                  if (visited.contains(country.code)) country,
              ],
              onRemove: onToggle,
            ),
          ],
          const SizedBox(height: 6),
          Expanded(
            child: matches.isEmpty
                ? Center(
                    child: Text(
                      'No country matches "$search".',
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final country = matches[index];
                      return _CountryRow(
                        country: country,
                        selected: visited.contains(country.code),
                        onTap: () => onToggle(country),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The countries already picked, as chips with an ✕ — the quickest way to
/// take one back off the map without hunting for it in the list.
class _VisitedChips extends StatelessWidget {
  const _VisitedChips({required this.countries, required this.onRemove});

  final List<WorldCountry> countries;
  final ValueChanged<WorldCountry> onRemove;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 108),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final country in countries)
              Material(
                color: luma.accentSubtle,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onRemove(country),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          country.name,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.close_rounded, size: 14, color: luma.accent),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.country,
    required this.selected,
    required this.onTap,
  });

  final WorldCountry country;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: selected ? luma.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: selected ? luma.accent : luma.border,
                  width: 1.4,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 13, color: luma.onAccent)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                country.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? luma.textPrimary : luma.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              country.region,
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
