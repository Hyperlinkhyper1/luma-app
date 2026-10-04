import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
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
const kSceneTests = <SceneTest>[
  SceneTest(
    kind: 'sports_car',
    title: 'Sports Car Test',
    blurb: 'An original sports car: studio configurator and test drive.',
    icon: Icons.directions_car_filled_rounded,
  ),
  SceneTest(
    kind: 'train_world',
    title: 'Train World Test',
    blurb: 'A miniature railway with three trains kept apart by signals.',
    icon: Icons.train_rounded,
  ),
  SceneTest(
    kind: 'world_timeline',
    title: 'World Timeline Test',
    blurb: 'An SVG animation of the world from its formation to today.',
    icon: Icons.timeline_rounded,
  ),
  SceneTest(
    kind: 'fluid_sim',
    title: 'Fluid Simulation Test',
    blurb: 'Real-time 3D water in a glass tank you can stir and tilt.',
    icon: Icons.water_drop_rounded,
  ),
  SceneTest(
    kind: 'galaxy',
    title: 'Galaxy Test',
    blurb: 'A spaceship voyage across a procedural spiral galaxy.',
    icon: Icons.rocket_launch_rounded,
  ),
  SceneTest(
    kind: 'cruise_port',
    title: 'Cruise Port Test',
    blurb: 'A cruise ship docked in Lisbon, below Alfama.',
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
              'Benchmark Model',
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
            Row(
              children: [
                Text(
                  'Select a Model',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                LumaSegmentedTabs(
                  tabs: const ['List', 'Banners'],
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
                title: 'No models match "${_query.trim()}"',
                subtitle: 'Try a shorter search.',
              )
            else if (filtered.isEmpty)
              LumaEmptyState(
                icon: _test.icon,
                title: 'No entries yet',
                subtitle: repo.canRefresh
                    ? 'No scenes have been added to this test yet.'
                    : 'Scenes download from the luma server. Sign in to an '
                          'approved account to fetch them.',
                action: LumaGhostButton(
                  label: repo.refreshing ? 'Refreshing…' : 'Refresh',
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
            title: 'Not available on this platform',
            subtitle:
                'The ${_test.title} requires a Windows desktop. Mobile '
                'and Linux support are coming soon.',
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
                    'Downloading ${benchmark.model}…',
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
                title: 'Could not load ${benchmark.model}',
                subtitle:
                    '${snapshot.error ?? 'The download failed.'} '
                    'Scenes are cached after the first download, so a retry '
                    'is usually all it takes.',
                action: LumaGhostButton(
                  label: 'Retry',
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
