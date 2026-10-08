import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/windows_webview.dart';
import 'ai_benchmark.dart';
import 'ai_benchmark_scope.dart';
import 'model_banner.dart';
import 'model_search_field.dart';
import 'pagoda_test_page.dart' show ModelButton;
import 'test_view_prefs.dart';

/// One of the server-only scene tests: every entry is a model's own HTML
/// page, generated from the admin dashboard's "Add benchmark" (prompts in
/// `server/lib/benchmark_prompts.dart`) and downloaded on first open.
class SceneTest {
  const SceneTest({
    required this.kind,
    required this.title,
    required this.blurb,
    required this.icon,
  });

  /// The roster's test kind, as in the server's `AiBenchmarkStore.kinds`.
  final String kind;
  final String title;

  /// One line under "Benchmark Model" saying what each entry is.
  final String blurb;
  final IconData icon;
}

/// The scene tests that share [SceneTestPage], in the order the Tests tab
/// shows their tiles.
List<SceneTest> sceneTestsOf(L t) => [
  SceneTest(
    kind: 'website_landing_page',
    title: t.aiTestWebsiteLandingTitle,
    blurb: t.aiTestWebsiteLandingBlurb,
    icon: Icons.web_rounded,
  ),
  SceneTest(
    kind: 'sports_car',
    title: t.aiTestSportsCarTitle,
    blurb: t.aiTestSportsCarBlurb,
    icon: Icons.directions_car_filled_rounded,
  ),
  SceneTest(
    kind: 'train_world',
    title: t.aiTestTrainWorldTitle,
    blurb: t.aiTestTrainWorldBlurb,
    icon: Icons.train_rounded,
  ),
  SceneTest(
    kind: 'world_timeline',
    title: t.aiTestWorldTimelineTitle,
    blurb: t.aiTestWorldTimelineBlurb,
    icon: Icons.timeline_rounded,
  ),
  SceneTest(
    kind: 'fluid_sim',
    title: t.aiTestFluidSimTitle,
    blurb: t.aiTestFluidSimBlurb,
    icon: Icons.water_drop_rounded,
  ),
  SceneTest(
    kind: 'galaxy',
    title: t.aiTestGalaxyTitle,
    blurb: t.aiTestGalaxyBlurb,
    icon: Icons.rocket_launch_rounded,
  ),
  SceneTest(
    kind: 'cruise_port',
    title: t.aiTestCruisePortTitle,
    blurb: t.aiTestCruisePortBlurb,
    icon: Icons.anchor_rounded,
  ),
];

/// A scene test's page: the searchable list (or banners) of contestants,
/// and the picked one's scene in an embedded WebView.
class SceneTestPage extends StatefulWidget {
  const SceneTestPage({super.key, required this.test});

  final SceneTest test;

  @override
  State<SceneTestPage> createState() => _SceneTestPageState();
}

class _SceneTestPageState extends State<SceneTestPage> {
  String? _selectedId;
  bool _bannerView = false;
  final _searchController = TextEditingController();
  String _query = '';
  bool _started = false;

  SceneTest get _test => widget.test;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AiBenchmarkScope.of(context).load();
    TestViewPrefs.loadBannerView(_test.kind).then((banners) {
      if (mounted && banners != _bannerView) {
        setState(() => _bannerView = banners);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = AiBenchmarkScope.of(context);
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final benchmarks = repo.benchmarksOfKind(_test.kind);
        final query = _query.trim().toLowerCase();
        final filtered = query.isEmpty
            ? benchmarks
            : [
                for (final b in benchmarks)
                  if (b.model.toLowerCase().contains(query)) b,
              ];

        if (_selectedId != null) {
          final selected = repo.byId(_selectedId!);
          if (selected == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedId = null);
            });
          } else {
            return _sceneView(context, selected);
          }
        }

        return _listView(context, filtered);
      },
    );
  }

  Widget _listView(BuildContext context, List<AiBenchmark> filtered) {
    final luma = context.luma;
    final t = L.of(context);
    final repo = AiBenchmarkScope.of(context);
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: Text(_test.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.aiTestBenchmarkModel,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _test.blurb,
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ModelSearchField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  t.aiTestSelectModel,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                LumaSegmentedTabs(
                  tabs: [t.aiTestViewList, t.aiTestViewBanners],
                  selectedIndex: _bannerView ? 1 : 0,
                  onSelect: (i) {
                    final banners = i == 1;
                    setState(() => _bannerView = banners);
                    TestViewPrefs.saveBannerView(_test.kind, banners);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (repo.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              )
            else if (filtered.isEmpty && _query.trim().isNotEmpty)
              LumaEmptyState(
                icon: Icons.search_off_rounded,
                title: t.aiTestNoMatch(_query.trim()),
                subtitle: t.aiTestTrySearchShorter,
              )
            else if (filtered.isEmpty)
              LumaEmptyState(
                icon: _test.icon,
                title: t.statsNoEntriesYet,
                subtitle: repo.canRefresh
                    ? t.aiTestNoScenesYet
                    : t.aiTestScenesDownloadNoAccount,
                action: LumaGhostButton(
                  label: repo.refreshing
                      ? t.accountOverviewRefreshing
                      : t.commonRefresh,
                  icon: Icons.refresh_rounded,
                  onTap: repo.refreshing || !repo.canRefresh
                      ? null
                      : () => repo.refreshFromServer(force: true),
                ),
              )
            else if (_bannerView)
              ModelBannerGrid(
                models: filtered,
                fallbackIcon: _test.icon,
                onPick: (b) => setState(() => _selectedId = b.id),
              )
            else
              for (final entry in filtered) ...[
                ModelButton(
                  model: entry.model,
                  vendor: entry.vendor,
                  description: entry.description,
                  onTap: () => setState(() => _selectedId = entry.id),
                  isSelected: false,
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _sceneView(BuildContext context, AiBenchmark benchmark) {
    final luma = context.luma;
    final t = L.of(context);
    final repo = AiBenchmarkScope.of(context);
    final back = IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => setState(() => _selectedId = null),
    );

    if (!Platform.isWindows) {
      return Scaffold(
        backgroundColor: luma.background,
        appBar: AppBar(
          backgroundColor: luma.background,
          elevation: 0,
          title: Text(_test.title),
          leading: back,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: LumaEmptyState(
            icon: Icons.computer_rounded,
            title: t.aiTestNotAvailablePlatform,
            subtitle: t.aiTestScenePlatformBody(_test.title),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: Text(_test.title),
        leading: back,
      ),
      body: FutureBuilder<File>(
        future: repo.sceneFile(benchmark.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(luma.accent),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.aiTestDownloadingModel(benchmark.model),
                    style: TextStyle(color: luma.textMuted, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: LumaEmptyState(
                icon: Icons.cloud_off_rounded,
                title: t.aiTestCouldNotLoadModel(benchmark.model),
                subtitle: t.aiTestLoadFailedBody(
                  '${snapshot.error ?? t.aiTestDownloadFailed}',
                ),
                action: LumaGhostButton(
                  label: t.commonRetry,
                  icon: Icons.refresh_rounded,
                  onTap: () => setState(() {}),
                ),
              ),
            );
          }
          return _SceneWebview(path: snapshot.data!.path);
        },
      ),
    );
  }
}

class _SceneWebview extends StatefulWidget {
  const _SceneWebview({required this.path});

  final String path;

  @override
  State<_SceneWebview> createState() => _SceneWebviewState();
}

class _SceneWebviewState extends State<_SceneWebview> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Stack(
      children: [
        Positioned.fill(
          child: WindowsWebview(
            key: ValueKey(widget.path),
            fileUrl: Uri.file(widget.path).toString(),
            onLoaded: () {
              if (mounted) setState(() => _loading = false);
            },
          ),
        ),
        if (_loading)
          Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(luma.accent),
            ),
          ),
      ],
    );
  }
}
