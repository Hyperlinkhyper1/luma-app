import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/native_webview.dart';
import '../../_shared/windows_webview.dart' show windowsAssetPath;
import 'ai_benchmark.dart';
import 'ai_benchmark_repository.dart';
import 'ai_benchmark_scope.dart';
import 'model_banner.dart';
import 'model_search_field.dart';
import 'pagoda_test_page.dart' show ModelButton;
import 'test_view_prefs.dart';

AiBenchmark cruiseShipBenchmark(L t) => AiBenchmark(
      id: 'cruise_ship_gpt6_astra_ultra',
      kind: 'cruise_ship',
      model: 'GPT 6 Astra (Ultra)',
      vendor: 'openai',
      description: t.aiCruiseGptDescription,
      sizeBytes: 0,
      sha256: '',
    );

const cruiseShipAsset =
    'server/benchmarks/scenes/cruise_ship_gpt6_astra_ultra/index.html';

AiBenchmark cruiseShipOpusBenchmark(L t) => AiBenchmark(
      id: 'cruise_ship_opus55_ultracode',
      kind: 'cruise_ship',
      model: 'Opus 5.5 (Ultracode)',
      vendor: 'anthropic',
      description: t.aiCruiseOpusDescription,
      sizeBytes: 0,
      sha256: '',
    );

const cruiseShipOpusAsset =
    'assets/ai_usage/cruise_ship_tests/opus_5_5_ultracode.html';

/// Contestants bundled with the app, so they work with no server. A server
/// entry with the same id replaces its fallback.
List<AiBenchmark> _bundledCruiseShips(L t) =>
    [cruiseShipBenchmark(t), cruiseShipOpusBenchmark(t)];

const _bundledCruiseScenes = {
  'cruise_ship_gpt6_astra_ultra': cruiseShipAsset,
  'cruise_ship_opus55_ultracode': cruiseShipOpusAsset,
};

/// Where a contestant's scene lives on disk: the bundled copy while the
/// server has no published file for it, otherwise the verified download.
Future<String> _cruiseScenePath(
  AiBenchmarkRepository repository,
  AiBenchmark benchmark,
) async {
  final bundled = _bundledCruiseScenes[benchmark.id];
  if (bundled != null && benchmark.sha256.isEmpty) {
    return windowsAssetPath(bundled);
  }
  try {
    return (await repository.sceneFile(benchmark.id)).path;
  } catch (_) {
    if (bundled != null) return windowsAssetPath(bundled);
    rethrow;
  }
}

class CruiseShipTestPage extends StatefulWidget {
  const CruiseShipTestPage({super.key});

  @override
  State<CruiseShipTestPage> createState() => _CruiseShipTestPageState();
}

class _CruiseShipTestPageState extends State<CruiseShipTestPage> {
  final _searchController = TextEditingController();
  String? _selectedId;
  String _query = '';
  bool _bannerView = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AiBenchmarkScope.of(context).load();
    TestViewPrefs.loadBannerView('cruise_ship').then((banners) {
      if (mounted) setState(() => _bannerView = banners);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Opens the scene in the default browser, outside the app window.
  Future<void> _openInBrowser(
    AiBenchmarkRepository repository,
    AiBenchmark benchmark,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = L.of(context);
    var opened = false;
    try {
      final path = await _cruiseScenePath(repository, benchmark);
      opened = await launchUrl(
        Uri.file(path),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(t.aiBenchmarkCouldNotOpenBrowser)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AiBenchmarkScope.of(context);
    final luma = context.luma;
    final t = L.of(context);
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final serverEntries = repo.benchmarksOfKind('cruise_ship');
        final benchmarks = [
          for (final fallback in _bundledCruiseShips(t))
            if (!serverEntries.any((entry) => entry.id == fallback.id))
              fallback,
          ...serverEntries,
        ];
        final selected = benchmarks
            .where((entry) => entry.id == _selectedId)
            .firstOrNull;
        final query = _query.trim().toLowerCase();
        final filtered = benchmarks
            .where((entry) => entry.model.toLowerCase().contains(query))
            .toList();
        return Scaffold(
          backgroundColor: luma.background,
          appBar: AppBar(
            backgroundColor: luma.background,
            title: Text(t.aiCruiseTitle),
            leading: selected == null
                ? null
                : IconButton(
                    tooltip: t.aiBenchmarkBackToModels,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() => _selectedId = null),
                  ),
            actions: [
              if (selected != null && Platform.isWindows)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(t.aiBenchmarkOpenInBrowser),
                    onPressed: () => _openInBrowser(repo, selected),
                  ),
                ),
            ],
          ),
          body: selected == null
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MSC Virtuosa',
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t.aiCruiseIntro,
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 13,
                        ),
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
                            t.aiBenchmarkSelectModel,
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          LumaSegmentedTabs(
                            tabs: [t.aiBenchmarkViewList, t.aiBenchmarkViewBanners],
                            selectedIndex: _bannerView ? 1 : 0,
                            onSelect: (index) {
                              final banners = index == 1;
                              setState(() => _bannerView = banners);
                              TestViewPrefs.saveBannerView(
                                'cruise_ship',
                                banners,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        LumaEmptyState(
                          icon: Icons.search_off_rounded,
                          title: t.aiBenchmarkNoMatch(_query.trim()),
                          subtitle: t.aiBenchmarkTryShorterSearch,
                        )
                      else if (_bannerView)
                        ModelBannerGrid(
                          models: filtered,
                          fallbackIcon: Icons.directions_boat_rounded,
                          onPick: (entry) =>
                              setState(() => _selectedId = entry.id),
                        )
                      else
                        for (final entry in filtered) ...[
                          ModelButton(
                            model: entry.model,
                            vendor: entry.vendor,
                            description: entry.description,
                            isSelected: false,
                            onTap: () => setState(() => _selectedId = entry.id),
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
                )
              : !Platform.isWindows
              ? Padding(
                  padding: EdgeInsets.all(24),
                  child: LumaEmptyState(
                    icon: Icons.desktop_windows_rounded,
                    title: t.aiCruiseWindowsOnlyTitle,
                    subtitle: t.aiCruiseWindowsOnlyBody,
                  ),
                )
              : _CruiseSceneLoader(
                  key: ValueKey('${selected.id}:${selected.sha256}'),
                  repository: repo,
                  benchmark: selected,
                ),
        );
      },
    );
  }
}

class _CruiseSceneLoader extends StatefulWidget {
  const _CruiseSceneLoader({
    super.key,
    required this.repository,
    required this.benchmark,
  });

  final AiBenchmarkRepository repository;
  final AiBenchmark benchmark;

  @override
  State<_CruiseSceneLoader> createState() => _CruiseSceneLoaderState();
}

class _CruiseSceneLoaderState extends State<_CruiseSceneLoader> {
  late Future<String> _path = _load();

  Future<String> _load() =>
      _cruiseScenePath(widget.repository, widget.benchmark);

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return FutureBuilder<String>(
      future: _path,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return LumaEmptyState(
            icon: Icons.cloud_off_rounded,
            title: t.aiCruiseCouldNotLoad,
            subtitle: snapshot.error.toString(),
            action: LumaGhostButton(
              label: t.commonRetry,
              icon: Icons.refresh_rounded,
              onTap: () => setState(() => _path = _load()),
            ),
          );
        }
        final path = snapshot.data;
        if (path == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _CruiseSceneWebview(key: ValueKey(path), path: path);
      },
    );
  }
}

class _CruiseSceneWebview extends StatefulWidget {
  const _CruiseSceneWebview({super.key, required this.path});

  final String path;

  @override
  State<_CruiseSceneWebview> createState() => _CruiseSceneWebviewState();
}

class _CruiseSceneWebviewState extends State<_CruiseSceneWebview> {
  Timer? _timeout;
  bool _ready = false;
  String? _error;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  void _startTimeout() {
    _timeout = Timer(const Duration(seconds: 45), () {
      if (!mounted || _ready) return;
      setState(() => _error = L.of(context).aiCruiseTimeout);
    });
  }

  void _receive(dynamic message) {
    if (message is String) {
      try {
        message = jsonDecode(message);
      } catch (_) {
        return;
      }
    }
    if (message is! Map || !mounted) return;
    if (message['type'] == 'cruise-ready') {
      _timeout?.cancel();
      setState(() {
        _ready = true;
        _error = null;
      });
    } else if (message['type'] == 'cruise-error') {
      _timeout?.cancel();
      setState(() {
        _ready = false;
        _error = message['message'] is String
            ? message['message'] as String
            : L.of(context).aiCruiseRendererFailed;
      });
    }
  }

  void _retry() {
    _timeout?.cancel();
    setState(() {
      _attempt++;
      _ready = false;
      _error = null;
    });
    _startTimeout();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attempt = _attempt;
    final t = L.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: NativeWebview(
            key: ValueKey('${widget.path}:$_attempt'),
            fileUrl: Uri.file(widget.path).toString(),
            visible: _error == null,
            background: context.luma.background,
            onMessage: (message) {
              if (mounted && attempt == _attempt) _receive(message);
            },
            onError: (message) {
              if (!mounted || attempt != _attempt) return;
              _receive({'type': 'cruise-error', 'message': message});
            },
          ),
        ),
        if (!_ready && _error == null)
          const IgnorePointer(
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          Positioned.fill(
            child: ColoredBox(
              color: context.luma.background,
              child: Center(
                child: LumaEmptyState(
                  icon: Icons.directions_boat_rounded,
                  title: t.aiCruiseCouldNotStart,
                  subtitle: _error!,
                  action: LumaGhostButton(
                    label: t.commonRetry,
                    icon: Icons.refresh_rounded,
                    onTap: _retry,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
