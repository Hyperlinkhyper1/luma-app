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

/// The **Keyboard Test** page: each entry is an HTML scene of a keyboard,
/// shown in an embedded WebView.
///
/// Entries live on the luma server like the other tests (see
/// [AiBenchmarkScope]); each downloads on first open and is cached on disk.
class KeyboardTestPage extends StatefulWidget {
  const KeyboardTestPage({super.key});

  @override
  State<KeyboardTestPage> createState() => _KeyboardTestPageState();
}

class _KeyboardTestPageState extends State<KeyboardTestPage> {
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
    TestViewPrefs.loadBannerView('keyboard').then((banners) {
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
        final benchmarks = repo.benchmarksOfKind('keyboard');
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
        title: Text(t.aiTestsKeyboardTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.aiTestsBenchmarkModelHeading,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t.aiTestsKeyboardIntro,
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
                  t.aiTestsSelectModel,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                LumaSegmentedTabs(
                  tabs: [t.aiTestsListView, t.aiTestsBannersView],
                  selectedIndex: _bannerView ? 1 : 0,
                  onSelect: (i) {
                    final banners = i == 1;
                    setState(() => _bannerView = banners);
                    TestViewPrefs.saveBannerView('keyboard', banners);
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
                title: t.aiTestsNoModelsMatch(_query.trim()),
                subtitle: t.aiTestsTryShorterSearch,
              )
            else if (filtered.isEmpty)
              LumaEmptyState(
                icon: Icons.keyboard_rounded,
                title: t.aiTestsKeyboardNoEntries,
                subtitle: repo.canRefresh
                    ? t.aiTestsKeyboardNoScenes
                    : t.aiTestsScenesSignInHint,
                action: LumaGhostButton(
                  label: repo.refreshing ? t.aiTestsRefreshing : t.commonRefresh,
                  icon: Icons.refresh_rounded,
                  onTap: repo.refreshing || !repo.canRefresh
                      ? null
                      : () => repo.refreshFromServer(force: true),
                ),
              )
            else if (_bannerView)
              ModelBannerGrid(
                models: filtered,
                fallbackIcon: Icons.keyboard_rounded,
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
          title: Text(t.aiTestsKeyboardTitle),
          leading: back,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: LumaEmptyState(
            icon: Icons.computer_rounded,
            title: t.aiTestsNotAvailableOnPlatform,
            subtitle: t.aiTestsNeedsWindowsDesktop(t.aiTestsKeyboardTitle),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: Text(t.aiTestsKeyboardTitle),
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
