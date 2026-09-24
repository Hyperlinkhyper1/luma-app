import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/windows_webview.dart';
import 'ai_benchmark.dart';
import 'ai_benchmark_repository.dart';
import 'ai_benchmark_scope.dart';
import 'model_banner.dart';
import 'model_search_field.dart';
import 'pagoda_test_page.dart' show ModelButton;
import 'test_view_prefs.dart';

/// The **Cathedral Test** page: each entry is a `.glb` model of a cathedral,
/// shown in an embedded WebView with orbit controls.
///
/// Entries live on the luma server like the other tests (see
/// [AiBenchmarkScope]); each downloads on first open and is cached on disk.
/// There are none yet, so the page shows its empty state until some are added.
class CathedralTestPage extends StatefulWidget {
  const CathedralTestPage({super.key});

  @override
  State<CathedralTestPage> createState() => _CathedralTestPageState();
}

class _CathedralTestPageState extends State<CathedralTestPage> {
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
    TestViewPrefs.loadBannerView('cathedral').then((banners) {
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
        final benchmarks = repo.benchmarksOfKind('cathedral');
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
        title: const Text('Cathedral Test'),
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
              'A cathedral modelled as a 3D .glb file, one per model. Orbit, '
              'zoom and pan to inspect it.',
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
                    TestViewPrefs.saveBannerView('cathedral', banners);
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
                icon: Icons.church_rounded,
                title: 'No entries yet',
                subtitle: repo.canRefresh
                    ? 'No cathedral models have been added yet.'
                    : 'Models download from the luma server. Sign in to an '
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
                fallbackIcon: Icons.church_rounded,
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
          title: const Text('Cathedral Test'),
          leading: back,
        ),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: LumaEmptyState(
            icon: Icons.computer_rounded,
            title: 'Not available on this platform',
            subtitle: 'The Cathedral Test requires a Windows desktop. Mobile '
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
        title: const Text('Cathedral Test'),
        leading: back,
      ),
      body: FutureBuilder<File>(
        future: _viewerFile(repo, benchmark),
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
                subtitle: '${snapshot.error ?? 'The download failed.'} '
                    'Models are cached after the first download, so a retry '
                    'is usually all it takes.',
                action: LumaGhostButton(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  onTap: () => setState(() {}),
                ),
              ),
            );
          }
          return _GlbWebview(path: snapshot.data!.path);
        },
      ),
    );
  }

  /// The downloaded `.glb`, wrapped in a page that renders it. The model is
  /// inlined as base64 because a `file://` page cannot fetch a sibling file.
  Future<File> _viewerFile(
    AiBenchmarkRepository repo,
    AiBenchmark benchmark,
  ) async {
    final glb = await repo.sceneFile(benchmark.id, extension: 'glb');
    final viewer = File('${glb.path}.viewer.html');
    if (await viewer.exists() &&
        await viewer.lastModified().then((t) => !t.isBefore(glb.lastModifiedSync()))) {
      return viewer;
    }
    final data = base64Encode(await glb.readAsBytes());
    await viewer.writeAsString(_viewerHtml(data), flush: true);
    return viewer;
  }
}

String _viewerHtml(String base64Glb) => '''<!doctype html>
<html><head><meta charset="utf-8">
<style>html,body{margin:0;height:100%;background:#0d0d12}
model-viewer{width:100%;height:100%;--poster-color:transparent}</style>
<script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer@3.5.0/dist/model-viewer.min.js"></script>
</head><body>
<model-viewer id="m" camera-controls auto-rotate shadow-intensity="1"
  environment-image="neutral" exposure="1"></model-viewer>
<script>
const b=atob("$base64Glb"),a=new Uint8Array(b.length);
for(let i=0;i<b.length;i++)a[i]=b.charCodeAt(i);
document.getElementById('m').src=URL.createObjectURL(new Blob([a],{type:'model/gltf-binary'}));
</script></body></html>''';

class _GlbWebview extends StatefulWidget {
  const _GlbWebview({required this.path});

  final String path;

  @override
  State<_GlbWebview> createState() => _GlbWebviewState();
}

class _GlbWebviewState extends State<_GlbWebview> {
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
