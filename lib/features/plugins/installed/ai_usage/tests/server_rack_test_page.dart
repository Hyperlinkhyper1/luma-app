import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
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

List<_BundledRackTest> _bundledRackTests(L t) => [
  _BundledRackTest(
    model: 'Sonnet 5.5 (Low)',
    description: t.aiTestRackSonnetLowDesc,
    asset: 'assets/ai_usage/server_rack_tests/sonnet_5_5_low.html',
  ),
  _BundledRackTest(
    model: 'Sonnet 5.5 (Xhigh)',
    description: t.aiTestRackSonnetXhighDesc,
    asset: 'assets/ai_usage/server_rack_tests/sonnet_5_5_xhigh.html',
  ),
  _BundledRackTest(
    model: 'Sonnet 5.5 (High)',
    description: t.aiTestRackSonnetHighDesc,
    asset: 'assets/ai_usage/server_rack_tests/sonnet_5_5_high.html',
  ),
  _BundledRackTest(
    model: 'Opus 5.5 (Low)',
    description: t.aiTestRackOpusLowDesc,
    asset: 'assets/ai_usage/server_rack_tests/opus_5_5_low.html',
  ),
  _BundledRackTest(
    model: 'Opus 5.5 (XHigh)',
    description: t.aiTestRackOpusXhighDesc,
    asset: 'assets/ai_usage/server_rack_tests/opus_5_5_xhigh.html',
  ),
  _BundledRackTest(
    model: 'Muse Spark 1.3 (Max)',
    description: t.aiTestRackMuseDesc,
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
    final t = L.of(context);
    final bundled = _bundledRackTests(t);
    final uploads = repo.benchmarksOfKind('server_rack');
    final query = _query.trim().toLowerCase();
    final models = [
      ...uploads,
      for (final entry in bundled)
        if (repo.byId(entry.benchmark.id) == null) entry.benchmark,
    ].where((entry) => entry.model.toLowerCase().contains(query)).toList();
    void pick(AiBenchmark entry) {
      final picked = bundled
          .where((rack) => rack.benchmark.id == entry.id)
          .firstOrNull;
      setState(() {
        if (uploads.any((upload) => identical(upload, entry))) {
          _uploadedModel = entry.model;
          _uploadedScene = repo.sceneFile(entry.id);
        } else {
          _selected = picked;
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
                              title: t.aiTestCouldNotLoadModel(
                                _uploadedModel ?? '',
                              ),
                              subtitle:
                                  '${snapshot.error ?? t.aiTestDownloadFailed}',
                            ),
                          );
                        }
                        return WindowsWebview(
                          key: ValueKey(snapshot.data!.path),
                          fileUrl: Uri.file(snapshot.data!.path).toString(),
                        );
                      },
                    )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: LumaEmptyState(
                  icon: Icons.computer_rounded,
                  title: t.aiTestNotAvailablePlatform,
                  subtitle: t.aiTestRackPlatformBody,
                ),
              ),
      );
    }
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: Text(t.aiTestServerRackTitle),
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
              t.aiTestServerRackBlurb,
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
                title: t.aiTestNoMatch(_query.trim()),
                subtitle: t.aiTestTrySearchShorter,
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
