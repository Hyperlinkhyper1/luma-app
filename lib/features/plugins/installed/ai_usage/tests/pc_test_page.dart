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

/// The **PC Test** page loads an interactive Three.js RGB rig benchmark — a
/// custom loop-glass tower with a staged power-on boot sequence, live
/// temperature readouts and a stress mode.
///
/// Bundled scenes are available immediately. Additional scenes come from
/// [AiBenchmarkScope], download on first open and stay cached on disk.
class PcTestPage extends StatefulWidget {
  const PcTestPage({super.key});

  @override
  State<PcTestPage> createState() => _PcTestPageState();
}

class _PcTestPageState extends State<PcTestPage> {
  static const _bundledId = 'pc_gpt61_sol_xhigh';
  static const _bundledAsset =
      'assets/ai_usage/pc_tests/gpt61_sol_xhigh/index.html';

  AiBenchmark _bundledBenchmark(L t) => AiBenchmark(
    id: _bundledId,
    kind: 'pc',
    model: 'GPT 6.1 Sol (Xhigh)',
    description: t.aiTestPcBundledDesc,
    sizeBytes: 0,
    sha256: '',
  );

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
    TestViewPrefs.loadBannerView('pc').then((banners) {
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
        final bundled = _bundledBenchmark(L.of(context));
        final benchmarks = [
          bundled,
          ...repo
              .benchmarksOfKind('pc')
              .where((entry) => entry.id != bundled.id),
        ];
        final query = _query.trim().toLowerCase();
        final filtered = query.isEmpty
            ? benchmarks
            : [
                for (final b in benchmarks)
                  if (b.model.toLowerCase().contains(query)) b,
              ];

        if (_selectedId != null) {
          if (_selectedId == bundled.id) {
            return _sceneView(context, bundled);
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
        title: Text(t.aiTestPcTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.aiTestBenchmarkScene,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t.aiTestPcBlurb,
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ModelSearchField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  t.aiTestSelectModel,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                LumaSegmentedTabs(
                  tabs: [t.aiTestViewList, t.aiTestViewBanners],
                  selectedIndex: _bannerView ? 1 : 0,
                  onSelect: (i) {
                    final banners = i == 1;
                    setState(() => _bannerView = banners);
                    TestViewPrefs.saveBannerView('pc', banners);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (repo.loading && filtered.isEmpty)
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
                icon: Icons.cloud_download_outlined,
                title: t.statsNoEntriesYet,
                subtitle: repo.canRefresh
                    ? t.aiTestPcEmptyCanRefresh
                    : t.aiTestEmptyNoAccount,
                action: LumaGhostButton(
                  label: repo.refreshing
                      ? t.accountOverviewRefreshing
                      : t.commonRetry,
                  icon: Icons.refresh_rounded,
                  onTap: repo.refreshing || !repo.canRefresh
                      ? null
                      : () => repo.refreshFromServer(force: true),
                ),
              )
            else if (_bannerView)
              ModelBannerGrid(
                models: filtered,
                fallbackIcon: Icons.computer_rounded,
                onPick: (b) => setState(() => _selectedId = b.id),
              )
            else
              for (final entry in filtered) ...[
                ModelButton(
                  model: entry.model,
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

    if (!Platform.isWindows) {
      return Scaffold(
        backgroundColor: luma.background,
        appBar: AppBar(
          backgroundColor: luma.background,
          elevation: 0,
          title: Text(t.aiTestPcTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => setState(() => _selectedId = null),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: LumaEmptyState(
            icon: Icons.computer_rounded,
            title: t.aiTestNotAvailablePlatform,
            subtitle: t.aiTestPcPlatformBody,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: Text(t.aiTestPcTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _selectedId = null),
        ),
      ),
      body: benchmark.id == _bundledId
          ? const _PcSceneWebview(assetPath: _bundledAsset)
          : FutureBuilder<File>(
              future: repo.sceneFile(benchmark.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            luma.accent,
                          ),
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
                return _PcSceneWebview(path: snapshot.data!.path);
              },
            ),
    );
  }
}

/// The embedded scene, remounted per file so going back and opening another
/// model never shows the previous scene.
class _PcSceneWebview extends StatefulWidget {
  const _PcSceneWebview({this.path, this.assetPath})
    : assert((path == null) != (assetPath == null));

  final String? path;
  final String? assetPath;

  @override
  State<_PcSceneWebview> createState() => _PcSceneWebviewState();
}

class _PcSceneWebviewState extends State<_PcSceneWebview> {
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
