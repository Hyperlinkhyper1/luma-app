import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../mc_content_scope.dart';
import '../mc_history.dart';
import '../mc_models.dart';
import 'account_shared.dart';
import 'mc_charts.dart';
import 'mc_setup_dialog.dart';
import 'pmc_webview_fetcher.dart';

/// The inner sections of MC Content.
///
/// One sidebar entry as asked, with the areas inside it on a segmented strip
/// rather than a single endless scroll — a hundred projects and four charts
/// on one page is a worse answer than three named views.
enum _McView {
  overview('Overview'),
  projects('Projects'),
  trends('Trends');

  const _McView(this.label);
  final String label;
}

/// CurseForge, Modrinth and Planet Minecraft in one place.
///
/// The two mod platforms are combined into a single library and a single set
/// of totals. Planet Minecraft sits under its own header throughout: it
/// publishes skins, blogs and builds alongside mods, counts views rather than
/// downloads, and reports rounded figures — folding it into the same numbers
/// would quietly corrupt them.
class McContentTab extends StatefulWidget {
  const McContentTab({super.key});

  @override
  State<McContentTab> createState() => _McContentTabState();
}

class _McContentTabState extends State<McContentTab> {
  _McView _view = _McView.overview;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    McContentScope.of(context).load();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = McContentScope.of(context);

    if (!repository.loaded) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: luma.accent),
        ),
      );
    }

    return Stack(
      children: [
        if (!repository.configured)
          const _McSetupPrompt()
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _McToolbar(
                view: _view,
                onView: (v) => setState(() => _view = v),
              ),
              if (repository.refreshing) _McRefreshBar(stage: repository.stage),
              if (repository.error case final message?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: AccountNotice(
                    message: message,
                    icon: Icons.error_outline_rounded,
                    tone: luma.danger,
                    onDismiss: repository.clearError,
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _view.index,
                  children: const [
                    _McOverviewView(),
                    _McProjectsView(),
                    _McTrendsView(),
                  ],
                ),
              ),
            ],
          ),
        // The PMC scraper's engine, one pixel in the corner. Mounted only
        // when a PMC username exists, so nobody pays for a browser they
        // never asked for.
        if (repository.credentials.hasPmc)
          Positioned(
            left: 0,
            bottom: 0,
            child: PmcWebViewFetcher(
              member: repository.credentials.pmcUsername!,
              onReady: repository.attachPmcFetcher,
            ),
          ),
      ],
    );
  }
}

class _McToolbar extends StatelessWidget {
  const _McToolbar({required this.view, required this.onView});

  final _McView view;
  final ValueChanged<_McView> onView;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = McContentScope.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 12),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: LumaSegmentedTabs(
              tabs: [for (final v in _McView.values) v.label],
              selectedIndex: view.index,
              onSelect: (i) => onView(_McView.values[i]),
              scrollable: true,
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: repository.refreshing ? 'Refreshing…' : 'Refresh',
            onPressed: repository.refreshing ? null : repository.unawaitedRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 19),
            color: luma.textSecondary,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          IconButton(
            tooltip: 'Platform settings',
            onPressed: () => showMcSetupDialog(context),
            icon: const Icon(Icons.settings_outlined, size: 18),
            color: luma.textSecondary,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }
}

class _McRefreshBar extends StatelessWidget {
  const _McRefreshBar({required this.stage});

  final McPlatform? stage;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      color: luma.accentSubtle,
      child: Row(
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: luma.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stage == null
                  ? 'Refreshing…'
                  : 'Reading ${stage!.label}…',
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (stage == McPlatform.planetMinecraft)
            Text(
              'via embedded browser',
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

// ---- overview ---------------------------------------------------------------

class _McOverviewView extends StatelessWidget {
  const _McOverviewView();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = McContentScope.of(context);
    final snapshot = repository.snapshot;
    final history = repository.history;

    final combinedKeys = [
      for (final p in McSnapshot.combinedPlatforms) p.id,
    ];
    final gained30 = combinedKeys.fold(
      0,
      (sum, key) => sum + history.gainedInLast(key, 30),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text(
          'Combined library',
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'CurseForge and Modrinth, added together.',
          style: TextStyle(color: luma.textMuted, fontSize: 11.5),
        ),
        const SizedBox(height: 14),
        _CombinedStats(snapshot: snapshot, gained30: gained30),
        const SizedBox(height: 16),
        for (final platform in McSnapshot.combinedPlatforms) ...[
          _PlatformCard(result: snapshot.resultFor(platform)),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 10),
        AccountPanel(
          title: 'Downloads over time',
          icon: Icons.show_chart_rounded,
          subtitle: 'CurseForge and Modrinth combined',
          child: SizedBox(
            height: 200,
            child: McTrendChart(
              points: history.combined(combinedKeys),
              range: McRange.month,
            ),
          ),
        ),
        const SizedBox(height: 26),
        const _PmcSection(),
      ],
    );
  }
}

class _CombinedStats extends StatelessWidget {
  const _CombinedStats({required this.snapshot, required this.gained30});

  final McSnapshot snapshot;
  final int gained30;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final projects = snapshot.combinedProjects;

    final tiles = [
      AccountStatTile(
        icon: Icons.download_rounded,
        label: 'Total downloads',
        value: formatCompact(snapshot.combinedDownloads),
        caption: 'across both platforms',
        tint: luma.accent,
      ),
      AccountStatTile(
        icon: Icons.trending_up_rounded,
        label: 'Last 30 days',
        value: gained30 > 0 ? '+${formatCompact(gained30)}' : '—',
        caption: gained30 > 0 ? 'downloads gained' : 'still collecting',
        tint: gained30 > 0 ? luma.success : null,
      ),
      AccountStatTile(
        icon: Icons.favorite_outline_rounded,
        label: 'Followers',
        value: formatCompact(snapshot.combinedFollowers),
        caption: 'followers and thumbs-up',
        tint: luma.warning,
      ),
      AccountStatTile(
        icon: Icons.widgets_outlined,
        label: 'Projects',
        value: formatCount(projects.length),
        caption: '${snapshot.resultFor(McPlatform.curseforge).projects.length} '
            'CF · ${snapshot.resultFor(McPlatform.modrinth).projects.length} MR',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 190).floor().clamp(2, 4);
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

/// One platform's headline row, including why it has nothing when it does not.
class _PlatformCard extends StatelessWidget {
  const _PlatformCard({required this.result});

  final McPlatformResult result;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final (icon, tone) = switch (result.state) {
      McPlatformState.ok => (Icons.check_circle_rounded, luma.success),
      McPlatformState.failed => (Icons.error_outline_rounded, luma.danger),
      McPlatformState.notConfigured => (
          Icons.radio_button_unchecked_rounded,
          luma.textMuted
        ),
    };

    return AccountPanel(
      title: result.platform.label,
      icon: Icons.extension_outlined,
      subtitle: result.creator?.handle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 6),
          Text(
            result.state.label,
            style: TextStyle(
              color: tone,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      child: result.state == McPlatformState.ok
          ? Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                AccountMetaCount(
                  icon: Icons.download_outlined,
                  value: formatCount(result.downloads),
                  semanticLabel: '${result.downloads} downloads',
                ),
                AccountMetaCount(
                  icon: Icons.favorite_outline_rounded,
                  value: formatCount(result.followers),
                  semanticLabel: '${result.followers} followers',
                ),
                AccountMetaCount(
                  icon: Icons.widgets_outlined,
                  value: '${result.projects.length} projects',
                  semanticLabel: '${result.projects.length} projects',
                ),
                if (result.fetchedAt != null)
                  Text(
                    'updated ${formatRelative(result.fetchedAt)}',
                    style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                  ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    result.message ?? 'Nothing to show yet.',
                    style: TextStyle(
                      color: luma.textSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
                AccountLinkButton(
                  label: 'Set up',
                  onTap: () => showMcSetupDialog(context),
                ),
              ],
            ),
    );
  }
}

/// Planet Minecraft, under its own header as asked.
class _PmcSection extends StatelessWidget {
  const _PmcSection();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = McContentScope.of(context);
    final result = repository.snapshot.resultFor(McPlatform.planetMinecraft);
    final history = repository.history;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: luma.accentSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.public_rounded, size: 16, color: luma.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Planet Minecraft',
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Kept separate — PMC counts views, and its skins, blogs '
                    'and builds are not mods.',
                    style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (result.state != McPlatformState.ok)
          AccountNotice(
            icon: result.state == McPlatformState.failed
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded,
            tone: result.state == McPlatformState.failed ? luma.danger : null,
            message: result.message ??
                'Add your Planet Minecraft username to include it.',
            action: AccountLinkButton(
              label: 'Set up',
              onTap: () => showMcSetupDialog(context),
            ),
          )
        else ...[
          _PmcStats(result: result),
          const SizedBox(height: 12),
          if (result.approximate)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AccountNotice(
                message: 'Planet Minecraft rounds views and downloads above a '
                    'thousand on listing pages ("1.1k"), so these totals are '
                    'approximate. Diamonds and favourites are exact.',
              ),
            ),
          AccountPanel(
            title: 'Views and downloads over time',
            icon: Icons.show_chart_rounded,
            subtitle: 'Recorded by luma, one point per day',
            child: SizedBox(
              height: 200,
              child: McTrendChart(
                points: history.platformSeries(McPlatform.planetMinecraft),
                range: McRange.month,
                metric: McMetric.views,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PmcStats extends StatelessWidget {
  const _PmcStats({required this.result});

  final McPlatformResult result;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final diamonds = result.projects.fold(0, (sum, p) => sum + p.followers);
    final favourites = result.projects.fold(0, (sum, p) => sum + p.favourites);

    final tiles = [
      AccountStatTile(
        icon: Icons.visibility_outlined,
        label: 'Views',
        value: formatCompact(result.views),
        caption: result.approximate ? 'approximate' : 'across submissions',
        tint: luma.success,
      ),
      AccountStatTile(
        icon: Icons.download_rounded,
        label: 'Downloads',
        value: formatCompact(result.downloads),
        caption: result.approximate ? 'approximate' : 'across submissions',
        tint: luma.accent,
      ),
      AccountStatTile(
        icon: Icons.diamond_outlined,
        label: 'Diamonds',
        value: formatCompact(diamonds),
        caption: 'exact',
        tint: luma.warning,
      ),
      AccountStatTile(
        icon: Icons.star_outline_rounded,
        label: 'Favourites',
        value: formatCompact(favourites),
        caption: '${result.projects.length} submissions',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 190).floor().clamp(2, 4);
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

// ---- projects ---------------------------------------------------------------

class _McProjectsView extends StatefulWidget {
  const _McProjectsView();

  @override
  State<_McProjectsView> createState() => _McProjectsViewState();
}

class _McProjectsViewState extends State<_McProjectsView> {
  final _controller = TextEditingController();
  String _query = '';

  /// null means "every platform".
  McPlatform? _platform;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final snapshot = McContentScope.of(context).snapshot;

    final all = [
      for (final platform in McPlatform.values)
        ...snapshot.resultFor(platform).projects,
    ];
    final query = _query.trim().toLowerCase();
    final visible = all.where((p) {
      if (_platform != null && p.platform != _platform) return false;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          (p.summary?.toLowerCase().contains(query) ?? false) ||
          (p.kind?.toLowerCase().contains(query) ?? false);
    }).toList()
      ..sort((a, b) => b.downloads != a.downloads
          ? b.downloads.compareTo(a.downloads)
          : b.views.compareTo(a.views));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: TextField(
                  controller: _controller,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(color: luma.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Find a project',
                    hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 18, color: luma.textMuted),
                    filled: true,
                    fillColor: luma.surface,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: luma.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: luma.accent, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: LumaSegmentedTabs(
                  tabs: [
                    'All',
                    for (final p in McPlatform.values) p.label,
                  ],
                  selectedIndex:
                      _platform == null ? 0 : _platform!.index + 1,
                  onSelect: (i) => setState(
                    () => _platform = i == 0 ? null : McPlatform.values[i - 1],
                  ),
                  scrollable: true,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? LumaEmptyState(
                  icon: Icons.widgets_outlined,
                  title: all.isEmpty
                      ? 'No projects yet'
                      : 'Nothing matches this filter',
                  subtitle: all.isEmpty
                      ? 'Set up a platform and refresh to pull your projects in.'
                      : 'Try a different platform or a shorter search.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  itemCount: visible.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProjectCard(project: visible[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final McProject project;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;

    return Material(
      color: luma.surface,
      borderRadius: decor.cardBorderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openExternal(project.url),
        hoverColor: luma.surfaceHover,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: decor.cardBorderRadius,
            border: Border.all(color: luma.border, width: decor.borderWidth),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProjectIcon(project: project),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          project.name,
                          style: TextStyle(
                            color: luma.accent,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AccountBadge(label: project.platform.label),
                        if (project.kind != null)
                          AccountBadge(label: project.kind!),
                        if (project.approximate)
                          AccountBadge(
                            label: 'rounded',
                            color: luma.warning,
                            icon: Icons.info_outline_rounded,
                          ),
                      ],
                    ),
                    if (project.summary != null &&
                        project.summary!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        project.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        if (project.downloads > 0)
                          AccountMetaCount(
                            icon: Icons.download_outlined,
                            value: formatCompact(project.downloads),
                            semanticLabel:
                                '${project.downloads} downloads',
                          ),
                        if (project.views > 0)
                          AccountMetaCount(
                            icon: Icons.visibility_outlined,
                            value: formatCompact(project.views),
                            semanticLabel: '${project.views} views',
                          ),
                        if (project.followers > 0)
                          AccountMetaCount(
                            icon: project.platform ==
                                    McPlatform.planetMinecraft
                                ? Icons.diamond_outlined
                                : Icons.favorite_outline_rounded,
                            value: formatCompact(project.followers),
                            semanticLabel:
                                '${project.followers} followers',
                          ),
                        if (project.favourites > 0)
                          AccountMetaCount(
                            icon: Icons.star_outline_rounded,
                            value: formatCompact(project.favourites),
                            semanticLabel:
                                '${project.favourites} favourites',
                          ),
                        if (project.updatedAt != null)
                          Text(
                            'updated ${formatRelative(project.updatedAt)}',
                            style: TextStyle(
                              color: luma.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new_rounded, size: 14, color: luma.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The project's own icon, falling back to its initial — an offline launch
/// should not leave a row of broken images.
class _ProjectIcon extends StatelessWidget {
  const _ProjectIcon({required this.project});

  final McProject project;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final fallback = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        project.name.isEmpty ? '?' : project.name[0].toUpperCase(),
        style: TextStyle(
          color: luma.accent,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final url = project.iconUrl;
    if (url == null || url.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.network(
        url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}

// ---- trends -----------------------------------------------------------------

class _McTrendsView extends StatefulWidget {
  const _McTrendsView();

  @override
  State<_McTrendsView> createState() => _McTrendsViewState();
}

class _McTrendsViewState extends State<_McTrendsView> {
  McRange _range = McRange.month;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = McContentScope.of(context);
    final history = repository.history;
    final combinedKeys = [for (final p in McSnapshot.combinedPlatforms) p.id];
    final combined = history.combined(combinedKeys);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: LumaSegmentedTabs(
            tabs: [for (final r in McRange.values) r.label],
            selectedIndex: _range.index,
            onSelect: (i) => setState(() => _range = McRange.values[i]),
            scrollable: true,
          ),
        ),
        const SizedBox(height: 16),
        AccountPanel(
          title: 'Total downloads',
          icon: Icons.show_chart_rounded,
          subtitle: 'CurseForge and Modrinth combined',
          trailing: _HistoryAge(history: history, seriesKey: combinedKeys.first),
          child: SizedBox(
            height: 220,
            child: McTrendChart(points: combined, range: _range),
          ),
        ),
        const SizedBox(height: 16),
        AccountPanel(
          title: 'Downloads gained per day',
          icon: Icons.bar_chart_rounded,
          subtitle: 'The difference between consecutive daily totals',
          child: SizedBox(
            height: 200,
            child: McDailyGainChart(
              deltas: _combinedDeltas(history, combinedKeys),
              range: _range,
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final platform in McSnapshot.combinedPlatforms) ...[
          AccountPanel(
            title: '${platform.label} downloads',
            icon: Icons.timeline_rounded,
            child: SizedBox(
              height: 180,
              child: McTrendChart(
                points: history.platformSeries(platform),
                range: _range,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.public_rounded, size: 16, color: luma.accent),
            const SizedBox(width: 8),
            Text(
              'Planet Minecraft',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AccountPanel(
          title: 'PMC views',
          icon: Icons.visibility_outlined,
          subtitle: 'Approximate — PMC rounds figures above a thousand',
          child: SizedBox(
            height: 180,
            child: McTrendChart(
              points: history.platformSeries(McPlatform.planetMinecraft),
              range: _range,
              metric: McMetric.views,
            ),
          ),
        ),
        const SizedBox(height: 16),
        AccountPanel(
          title: 'PMC downloads',
          icon: Icons.download_outlined,
          child: SizedBox(
            height: 180,
            child: McTrendChart(
              points: history.platformSeries(McPlatform.planetMinecraft),
              range: _range,
            ),
          ),
        ),
      ],
    );
  }

  /// Per-day gains for the combined series, derived the same way the store
  /// derives a single platform's.
  List<McDelta> _combinedDeltas(McHistoryStore history, List<String> keys) {
    final points = history.combined(keys);
    if (points.length < 2) return const [];
    final out = <McDelta>[];
    for (var i = 1; i < points.length; i++) {
      final gained = points[i].downloads - points[i - 1].downloads;
      out.add(McDelta(day: points[i].day, gained: gained < 0 ? 0 : gained));
    }
    return out;
  }
}

/// Says how long luma has been recording, so a two-day line is not mistaken
/// for two days of flat growth.
class _HistoryAge extends StatelessWidget {
  const _HistoryAge({required this.history, required this.seriesKey});

  final McHistoryStore history;
  final String seriesKey;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final first = history.firstDay(seriesKey);
    if (first == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        'since ${formatDate(first)}',
        style: TextStyle(color: luma.textMuted, fontSize: 11),
      ),
    );
  }
}

// ---- setup prompt -----------------------------------------------------------

class _McSetupPrompt extends StatelessWidget {
  const _McSetupPrompt();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LumaEmptyState(
                icon: Icons.widgets_rounded,
                title: 'Track your Minecraft content',
                subtitle: 'Pull CurseForge, Modrinth and Planet Minecraft into '
                    'one dashboard — downloads, followers, views and trends '
                    'over time.',
                action: LumaPrimaryButton(
                  label: 'Set up platforms',
                  icon: Icons.link_rounded,
                  onTap: () => showMcSetupDialog(context),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: luma.surface,
                  borderRadius: context.lumaDecor.cardBorderRadius,
                  border: Border.all(color: luma.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _requirement(
                      context,
                      icon: Icons.check_circle_outline_rounded,
                      tone: luma.success,
                      title: 'Modrinth — username only',
                      body: 'Totals are public. A token is optional and only '
                          'unlocks real download history.',
                    ),
                    const SizedBox(height: 12),
                    _requirement(
                      context,
                      icon: Icons.key_outlined,
                      tone: luma.warning,
                      title: 'CurseForge — API key required',
                      body: 'CurseForge serves nothing anonymously. Add a key '
                          'plus either your numeric author id or individual '
                          'project links.',
                    ),
                    const SizedBox(height: 12),
                    _requirement(
                      context,
                      icon: Icons.public_rounded,
                      tone: luma.accent,
                      title: 'Planet Minecraft — username only',
                      body: 'PMC has no API, so luma reads your public profile '
                          'in an embedded browser. Windows and Android only.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requirement(
    BuildContext context, {
    required IconData icon,
    required Color tone,
    required String title,
    required String body,
  }) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: tone),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
