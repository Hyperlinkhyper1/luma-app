import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/windows_webview.dart'
    show WindowsWebview, windowsAssetPath;
import 'ai_benchmark.dart';
import 'ai_benchmark_scope.dart';
import 'model_banner.dart';
import 'model_search_field.dart';
import 'pagoda_test_page.dart' show ModelButton;
import 'test_view_prefs.dart';

const _bundledEngineTests = <_BundledEngineTest>[
  _BundledEngineTest(
    id: 'gpt-6-1-sol-low',
    model: 'GPT 6.1 Sol (Low)',
    kind: _EngineDescriptionKind.procedural,
    asset: 'assets/ai_usage/engine_tests/gpt_6_1_sol_low.html',
    serverId: 'engine_gpt61_sol_low',
  ),
  _BundledEngineTest(
    id: 'gpt-6-1-sol-xhigh',
    model: 'GPT 6.1 Sol (Xhigh)',
    kind: _EngineDescriptionKind.procedural,
    asset: 'server/benchmarks/scenes/engine_gpt61_sol_xhigh/index.html',
    serverId: 'engine_gpt61_sol_xhigh',
  ),
  _BundledEngineTest(
    id: 'gpt-sol-6-max',
    model: 'GPT Sol 6 (Max)',
    kind: _EngineDescriptionKind.study,
    asset: 'assets/ai_usage/engine_tests/gpt_sol_6_max.html',
    serverId: 'engine_gpt_sol_6_max',
  ),
  _BundledEngineTest(
    id: 'opus-5-high',
    model: 'Opus 5 (High)',
    kind: _EngineDescriptionKind.study,
    asset: 'assets/ai_usage/engine_tests/opus_5_high.html',
    serverId: 'engine_opus_5_high',
  ),
  _BundledEngineTest(
    id: 'glm-5-3-flash',
    model: 'GLM 5.3 Flash',
    kind: _EngineDescriptionKind.study,
    asset: 'assets/ai_usage/engine_tests/glm_5_3_flash.html',
    serverId: 'engine_glm_5_3_flash',
  ),
  _BundledEngineTest(
    id: 'grok-4-6-medium',
    model: 'Grok 4.6 Medium',
    kind: _EngineDescriptionKind.study,
    asset: 'assets/ai_usage/engine_tests/grok_4_6_medium.html',
    serverId: 'engine_grok_4_6_medium',
  ),
  _BundledEngineTest(
    id: 'sonnet-5-5-low',
    model: 'Sonnet 5.5 (Low)',
    kind: _EngineDescriptionKind.study,
    asset: 'assets/ai_usage/engine_tests/sonnet_5_5_low.html',
    serverId: 'engine_sonnet_5_5_low',
  ),
];

enum _EngineDescriptionKind { procedural, study }

class _BundledEngineTest {
  const _BundledEngineTest({
    required this.id,
    required this.model,
    required this.kind,
    required this.asset,
    this.serverId,
  });

  final String id;
  final String model;
  final _EngineDescriptionKind kind;
  final String asset;
  final String? serverId;

  String describe(L t) => switch (kind) {
    _EngineDescriptionKind.procedural => t.aiTestsEngineDescProcedural(model),
    _EngineDescriptionKind.study => t.aiTestsEngineDescStudy(model),
  };
}

/// The **Engine Test** page loads an interactive Three.js V8 cutaway
/// benchmark — a mechanically driven cross-plane 90-degree V8 with a live
/// engineering dashboard and a 30-second benchmark mode.
///
/// Scenes used to ship inside the app bundle; they live on the luma server
/// now. The roster comes from [AiBenchmarkScope], each scene downloads on
/// first open and is cached on disk after that.
class EngineTestPage extends StatefulWidget {
  const EngineTestPage({super.key});

  @override
  State<EngineTestPage> createState() => _EngineTestPageState();
}

class _EngineTestPageState extends State<EngineTestPage> {
  String? _selectedId;
  bool _bannerView = false;
  final _searchController = TextEditingController();
  String _query = '';
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AiBenchmarkScope.of(context).load();
    TestViewPrefs.loadBannerView('engine').then((banners) {
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
        final t = L.of(context);
        final benchmarks = repo.benchmarksOfKind('engine');
        final query = _query.trim().toLowerCase();
        final bundled = [
          for (final test in _bundledEngineTests)
            if ((test.serverId == null || repo.byId(test.serverId!) == null) &&
                (query.isEmpty ||
                    test.model.toLowerCase().contains(query) ||
                    test.describe(t).toLowerCase().contains(query)))
              test,
        ];
        final filtered = query.isEmpty
            ? benchmarks
            : [
                for (final b in benchmarks)
                  if (b.model.toLowerCase().contains(query)) b,
              ];

        if (_selectedId != null) {
          final bundledId = _selectedId!.startsWith('bundled:')
              ? _selectedId!.substring('bundled:'.length)
              : null;
          if (bundledId != null) {
            final selected = _bundledEngineTests.firstWhere(
              (test) => test.id == bundledId,
            );
            return _bundledSceneView(context, selected);
          }
          final selected = repo.byId(_selectedId!);
          if (selected == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedId = null);
            });
          } else {
            return _sceneView(context, selected);
          }
        }

        return _listView(context, filtered, bundled);
      },
    );
  }

  Widget _listView(
    BuildContext context,
    List<AiBenchmark> filtered,
    List<_BundledEngineTest> bundled,
  ) {
    final luma = context.luma;
    final t = L.of(context);
    final repo = AiBenchmarkScope.of(context);
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: Text(t.aiTestsEngineTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.aiTestsBenchmarkSceneHeading,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t.aiTestsEngineIntro,
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ModelSearchField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 10,
                children: [
                  Text(
                    t.aiTestsSelectModel,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  LumaSegmentedTabs(
                    tabs: [t.aiTestsListView, t.aiTestsBannersView],
                    selectedIndex: _bannerView ? 1 : 0,
                    onSelect: (i) {
                      final banners = i == 1;
                      setState(() => _bannerView = banners);
                      TestViewPrefs.saveBannerView('engine', banners);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t.aiTestsEngineBundledHeading,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            if (bundled.isEmpty)
              Text(
                t.aiTestsEngineNoBundledMatch(_query.trim()),
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              )
            else
              for (final entry in bundled) ...[
                ModelButton(
                  model: entry.model,
                  description: entry.describe(t),
                  onTap: () =>
                      setState(() => _selectedId = 'bundled:${entry.id}'),
                  isSelected: false,
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 16),
            Text(
              t.aiTestsEngineOnlineHeading,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
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
            else if (filtered.isEmpty &&
                bundled.isEmpty &&
                _query.trim().isNotEmpty)
              LumaEmptyState(
                icon: Icons.search_off_rounded,
                title: t.aiTestsNoModelsMatch(_query.trim()),
                subtitle: t.aiTestsTryShorterSearch,
              )
            else if (filtered.isEmpty)
              LumaEmptyState(
                icon: Icons.cloud_download_outlined,
                title: t.aiTestsNoBenchmarksYet,
                subtitle: repo.canRefresh
                    ? t.aiTestsBenchmarkListFailed
                    : t.aiTestsBenchmarksSignInHint,
                action: LumaGhostButton(
                  label: repo.refreshing ? t.aiTestsRefreshing : t.commonRetry,
                  icon: Icons.refresh_rounded,
                  onTap: repo.refreshing || !repo.canRefresh
                      ? null
                      : () => repo.refreshFromServer(force: true),
                ),
              )
            else if (_bannerView)
              ModelBannerGrid(
                models: filtered,
                fallbackIcon: Icons.precision_manufacturing_rounded,
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

  Widget _bundledSceneView(BuildContext context, _BundledEngineTest test) {
    final luma = context.luma;
    final t = L.of(context);
    if (!Platform.isWindows) {
      return Scaffold(
        backgroundColor: luma.background,
        appBar: AppBar(
          backgroundColor: luma.background,
          elevation: 0,
          title: Text(test.model),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => setState(() => _selectedId = null),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: LumaEmptyState(
            icon: Icons.computer_rounded,
            title: t.aiTestsNotAvailableOnPlatform,
            subtitle: t.aiTestsNeedsWindowsDesktop(t.aiTestsEngineTitle),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: Text(test.model),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _selectedId = null),
        ),
      ),
      body: _EngineSceneWebview(assetPath: test.asset),
    );
  }

  Widget _sceneView(BuildContext context, AiBenchmark benchmark) {
    final luma = context.luma;
    final t = L.of(context);
    final repo = AiBenchmarkScope.of(context);

    if (!Platform.isWindows) {
      return Scaffold(
        backgroundColor: luma.background,
        appBar: AppBar(
          backgroundColor: luma.background,
          elevation: 0,
          title: Text(t.aiTestsEngineTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => setState(() => _selectedId = null),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: LumaEmptyState(
            icon: Icons.computer_rounded,
            title: t.aiTestsNotAvailableOnPlatform,
            subtitle: t.aiTestsNeedsWindowsDesktop(t.aiTestsEngineTitle),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: Text(t.aiTestsEngineTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _selectedId = null),
        ),
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
                    t.aiTestsDownloadingModel(benchmark.model),
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
                title: t.aiTestsCouldNotLoadModel(benchmark.model),
                subtitle: t.aiTestsSceneLoadFailedBody(
                  snapshot.error?.toString() ?? t.aiTestsDownloadFailed,
                ),
                action: LumaGhostButton(
                  label: t.commonRetry,
                  icon: Icons.refresh_rounded,
                  onTap: () => setState(() {}),
                ),
              ),
            );
          }
          return _EngineSceneWebview(path: snapshot.data!.path);
        },
      ),
    );
  }
}

/// The embedded scene, remounted per file so going back and opening another
/// model never shows the previous scene.
class _EngineSceneWebview extends StatefulWidget {
  const _EngineSceneWebview({this.path, this.assetPath});

  final String? path;
  final String? assetPath;

  @override
  State<_EngineSceneWebview> createState() => _EngineSceneWebviewState();
}

class _EngineSceneWebviewState extends State<_EngineSceneWebview> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Stack(
      children: [
        Positioned.fill(
          child: WindowsWebview(
            key: ValueKey(widget.assetPath ?? widget.path),
            fileUrl: Uri.file(
              widget.assetPath == null
                  ? widget.path!
                  : windowsAssetPath(widget.assetPath!),
            ).toString(),
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
