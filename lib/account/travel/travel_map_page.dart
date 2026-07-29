import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../settings/settings_controller.dart';
import '../../settings/settings_scope.dart';
import '../../theme/luma_theme.dart';
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

  /// Below this the map and the country list stack instead of sitting
  /// side by side.
  static const _sideBySideBreakpoint = 900.0;

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
            icon: const Icon(Icons.zoom_out_map_rounded),
            onPressed: () => _view.value = Matrix4.identity(),
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _Summary(map: map, visited: known),
              const SizedBox(height: 16),
              mapPanel,
              const SizedBox(height: 16),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _regionCounts().entries)
                _RegionPill(
                  region: entry.key,
                  visited: entry.value.$1,
                  total: entry.value.$2,
                ),
            ],
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
  });

  final WorldMap map;
  final Set<String> visited;
  final ValueChanged<WorldCountry> onToggle;
  final TransformationController controller;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorldMapView(
            map: map,
            visited: visited,
            onToggle: onToggle,
            controller: controller,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.touch_app_rounded, size: 14, color: luma.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tap a country to mark it visited. Drag to pan, '
                  'pinch or scroll to zoom.',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
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
                  'Countries',
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
