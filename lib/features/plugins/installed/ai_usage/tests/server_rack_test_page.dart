import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/windows_webview.dart'
    show WindowsWebview, windowsAssetPath;
import 'pagoda_test_page.dart' show ModelButton;
import 'ai_benchmark_scope.dart';
import 'ai_benchmark.dart';
import 'model_banner.dart';
import 'model_search_field.dart';
import 'test_view_prefs.dart';

class _BundledRackTest {
  const _BundledRackTest({
    required this.model,
    required this.description,
    required this.asset,
  });

  final String model;
  final String description;
  final String asset;

  AiBenchmark get benchmark => AiBenchmark(
    id: 'server_rack_${asset.split('/').last.replaceFirst('.html', '')}',
    kind: 'server_rack',
    model: model,
    description: description,
    sizeBytes: 0,
    sha256: '',
  );
}

const _bundledRackTests = <_BundledRackTest>[
  _BundledRackTest(
    model: 'Sonnet 5.5 (Low)',
    description:
        'Full 42U rack plus single-slice server inspection by '
        'Sonnet 5.5 Low.',
    asset: 'assets/ai_usage/server_rack_tests/sonnet_5_5_low.html',
  ),
  _BundledRackTest(
    model: 'Sonnet 5.5 (Xhigh)',
    description:
        'A 42U rack of nine inspectable servers; each one slides '
        'out on its rails into an open single-slice view with exploded, '
        'cutaway and airflow modes.',
    asset: 'assets/ai_usage/server_rack_tests/sonnet_5_5_xhigh.html',
  ),
  _BundledRackTest(
    model: 'Sonnet 5.5 (High)',
    description:
        'A 42U rack with labelled units that opens into a '
        'per-server detail view with airflow simulation.',
    asset: 'assets/ai_usage/server_rack_tests/sonnet_5_5_high.html',
  ),
  _BundledRackTest(
    model: 'Opus 5.5 (Low)',
    description:
        'A cabled 42U rack of nine servers across five archetypes; '
        'each slides out into an open-chassis slice with exploded, '
        'cutaway and obstacle-aware airflow views.',
    asset: 'assets/ai_usage/server_rack_tests/opus_5_5_low.html',
  ),
  _BundledRackTest(
    model: 'Opus 5.5 (XHigh)',
    description:
        'A cabled, power-budgeted 42U rack of nine servers with '
        'nine different layouts; each unlatches, slides out on its rails '
        'and opens into a hoverable slice with exploded, cutaway and '
        'solved-airflow views.',
    asset: 'assets/ai_usage/server_rack_tests/opus_5_5_xhigh.html',
  ),
  _BundledRackTest(
    model: 'Muse Spark 1.3 (Max)',
    description:
        'RACKSCOPE·42U: a cabled rack with a unit browser and '
        'an inspectable single-slice server view.',
    asset: 'assets/ai_usage/server_rack_tests/muse_spark_1_3_max.html',
  ),
];

/// The **Server Rack Test** page: a 42U rack that opens into a single,
/// per-archetype server slice. Bundled scenes remain available alongside
/// uploaded server scenes, so the bundled entries work with
/// no server account.
class ServerRackTestPage extends StatefulWidget {
  const ServerRackTestPage({super.key});

  @override
  State<ServerRackTestPage> createState() => _ServerRackTestPageState();
}

class _ServerRackTestPageState extends State<ServerRackTestPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _bannerView = false;
  _BundledRackTest? _selected;
  String? _uploadedModel;
  Future<File>? _uploadedScene;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AiBenchmarkScope.of(context).load();
    TestViewPrefs.loadBannerView('server_rack').then((banners) {
      if (mounted) setState(() => _bannerView = banners);
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
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final repo = AiBenchmarkScope.of(context);
    final uploads = repo.benchmarksOfKind('server_rack');
    final query = _query.trim().toLowerCase();
    final models = [
      ...uploads,
      for (final entry in _bundledRackTests) entry.benchmark,
    ].where((entry) => entry.model.toLowerCase().contains(query)).toList();
    void pick(AiBenchmark entry) {
      final bundled = _bundledRackTests
          .where((rack) => rack.benchmark.id == entry.id)
          .firstOrNull;
      setState(() {
        if (uploads.any((upload) => identical(upload, entry))) {
          _uploadedModel = entry.model;
          _uploadedScene = repo.sceneFile(entry.id);
        } else {
          _selected = bundled;
        }
      });
    }

    final luma = context.luma;
    final selected = _selected;
    final back = IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => setState(() {
        _selected = null;
        _uploadedModel = null;
        _uploadedScene = null;
      }),
    );
    if (selected != null || _uploadedScene != null) {
      return Scaffold(
        backgroundColor: luma.background,
        appBar: AppBar(
          backgroundColor: luma.background,
          elevation: 0,
          title: Text(selected?.model ?? _uploadedModel!),
          leading: back,
        ),
        body: Platform.isWindows
            ? selected != null
                  ? WindowsWebview(
                      key: ValueKey(selected.asset),
                      fileUrl: Uri.file(
                        windowsAssetPath(selected.asset),
                      ).toString(),
                    )
                  : FutureBuilder<File>(
                      future: _uploadedScene,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: LumaEmptyState(
                              icon: Icons.cloud_off_rounded,
                              title: 'Could not load $_uploadedModel',
                              subtitle:
                                  '${snapshot.error ?? 'The download failed.'}',
                            ),
                          );
                        }
                        return WindowsWebview(
                          key: ValueKey(snapshot.data!.path),
                          fileUrl: Uri.file(snapshot.data!.path).toString(),
                        );
                      },
                    )
            : const Padding(
                padding: EdgeInsets.all(24),
                child: LumaEmptyState(
                  icon: Icons.computer_rounded,
                  title: 'Not available on this platform',
                  subtitle: 'The Server Rack Test requires Windows desktop.',
                ),
              ),
      );
    }
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: const Text('Server Rack Test'),
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
              'A full 42U rack and a single-server slice view: macro '
              'architecture of how machines fit a rack, and micro '
              'architecture of the hardware inside one chassis.',
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ModelSearchField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Select a Model',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                LumaSegmentedTabs(
                  tabs: const ['List', 'Banners'],
                  selectedIndex: _bannerView ? 1 : 0,
                  onSelect: (index) {
                    final banners = index == 1;
                    setState(() => _bannerView = banners);
                    TestViewPrefs.saveBannerView('server_rack', banners);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (models.isEmpty)
              LumaEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No models match "${_query.trim()}"',
                subtitle: 'Try a shorter search.',
              )
            else if (_bannerView)
              ModelBannerGrid(
                models: models,
                fallbackIcon: Icons.dns_rounded,
                onPick: pick,
              )
            else
              for (final entry in models) ...[
                ModelButton(
                  model: entry.model,
                  vendor: entry.vendor,
                  description: entry.description,
                  onTap: () => pick(entry),
                  isSelected: false,
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}
