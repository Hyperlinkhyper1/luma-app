import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/windows_webview.dart';
import 'ai_benchmark.dart';
import 'ai_benchmark_scope.dart';
import 'model_search_field.dart';
import 'pagoda_test_page.dart' show ModelButton;

/// The **PC Test** page loads an interactive Three.js RGB rig benchmark — a
/// custom loop-glass tower with a staged power-on boot sequence, live
/// temperature readouts and a stress mode.
///
/// Scenes live on the luma server (see [AiBenchmarkScope]); each downloads on
/// first open and is cached on disk after that.
class PcTestPage extends StatefulWidget {
  const PcTestPage({super.key});

  @override
  State<PcTestPage> createState() => _PcTestPageState();
}

class _PcTestPageState extends State<PcTestPage> {
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
        final benchmarks = repo.benchmarksOfKind('pc');
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
        title: const Text('PC Test'),
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
              'Nebula Forge — a real-time 3D RGB rig benchmark with a staged '
              'power-on boot sequence, live temperature readouts and a '
              'stress mode.',
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
                title: 'No entries yet',
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
          title: const Text('PC Test'),
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
            subtitle: 'The PC Test requires a Windows desktop. Mobile and '
                'Linux support are coming soon.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: const Text('PC Test'),
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
          return _PcSceneWebview(path: snapshot.data!.path);
        },
      ),
    );
  }
}

/// The embedded scene, remounted per file so going back and opening another
/// model never shows the previous scene.
class _PcSceneWebview extends StatefulWidget {
  const _PcSceneWebview({required this.path});

  final String path;

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
