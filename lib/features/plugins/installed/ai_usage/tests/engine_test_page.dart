import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/windows_webview.dart';
import 'ai_benchmark.dart';
import 'ai_benchmark_scope.dart';
import 'model_search_field.dart';
import 'pagoda_test_page.dart' show ModelButton;

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
  final _searchController = TextEditingController();
  String _query = '';
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AiBenchmarkScope.of(context).load();
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
        final benchmarks = repo.benchmarksOfKind('engine');
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
        title: const Text('Engine Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Benchmark Scene',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cutaway V8 — a real-time 3D cross-plane engine benchmark with '
              'crank-driven pistons, half-speed camshafts, synchronized '
              'valves, combustion effects and a 30-second FPS benchmark.',
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ModelSearchField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 20),
            Text(
              'Select a Model',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
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
                icon: Icons.cloud_download_outlined,
                title: 'No benchmarks yet',
                subtitle: repo.canRefresh
                    ? 'The benchmark list could not be loaded. Try again, or '
                        'ask the server operator to add scenes.'
                    : 'Benchmarks download from the luma server. Sign in to '
                        'an approved account to fetch them.',
                action: LumaGhostButton(
                  label: repo.refreshing ? 'Refreshing…' : 'Retry',
                  icon: Icons.refresh_rounded,
                  onTap: repo.refreshing || !repo.canRefresh
                      ? null
                      : () => repo.refreshFromServer(force: true),
                ),
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

    if (!Platform.isWindows) {
      return Scaffold(
        backgroundColor: luma.background,
        appBar: AppBar(
          backgroundColor: luma.background,
          elevation: 0,
          title: const Text('Engine Test'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => setState(() => _selectedId = null),
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: LumaEmptyState(
            icon: Icons.computer_rounded,
            title: 'Not available on this platform',
            subtitle: 'The Engine Test requires a Windows desktop. '
                'Mobile and Linux support are coming soon.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: const Text('Engine Test'),
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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(luma.accent),
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
          return _EngineSceneWebview(path: snapshot.data!.path);
        },
      ),
    );
  }
}

/// The embedded scene, remounted per file so going back and opening another
/// model never shows the previous scene.
class _EngineSceneWebview extends StatefulWidget {
  const _EngineSceneWebview({required this.path});

  final String path;

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
