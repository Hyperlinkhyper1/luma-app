import 'dart:async';
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

const cruiseShipBenchmark = AiBenchmark(
  id: 'cruise_ship_gpt6_astra_ultra',
  kind: 'cruise_ship',
  model: 'GPT 6 Astra (Ultra)',
  vendor: 'openai',
  description:
      'MSC Virtuosa at sea: walk the exterior decks and Deck 7 '
      'lifeboat promenade, with a day/night cycle, weather and tender views.',
  sizeBytes: 0,
  sha256: '',
);

const cruiseShipAsset =
    'server/benchmarks/scenes/cruise_ship_gpt6_astra_ultra/index.html';

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

  @override
  Widget build(BuildContext context) {
    final repo = AiBenchmarkScope.of(context);
    final luma = context.luma;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final serverEntries = repo.benchmarksOfKind('cruise_ship');
        final benchmarks = [
          if (!serverEntries.any((entry) => entry.id == cruiseShipBenchmark.id))
            cruiseShipBenchmark,
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
            title: const Text('Cruise Ship Test'),
            leading: selected == null
                ? null
                : IconButton(
                    tooltip: 'Back to models',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() => _selectedId = null),
                  ),
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
                        'Explore an empty cruise ship at human scale, from '
                        'the lifeboat promenade to the open upper decks.',
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
                          title: 'No models match "${_query.trim()}"',
                          subtitle: 'Try a shorter search.',
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
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: LumaEmptyState(
                    icon: Icons.desktop_windows_rounded,
                    title: 'Windows desktop required',
                    subtitle:
                        'Cruise Ship Test uses keyboard and mouse '
                        'controls in the Windows desktop app.',
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

  Future<String> _load() async {
    final bundled = widget.benchmark.id == cruiseShipBenchmark.id;
    if (bundled && widget.benchmark.sha256.isEmpty) {
      return windowsAssetPath(cruiseShipAsset);
    }
    try {
      return (await widget.repository.sceneFile(widget.benchmark.id)).path;
    } catch (_) {
      if (bundled) return windowsAssetPath(cruiseShipAsset);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _path,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return LumaEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load this cruise ship',
          subtitle: snapshot.error.toString(),
          action: LumaGhostButton(
            label: 'Retry',
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

class _CruiseSceneWebview extends StatefulWidget {
  const _CruiseSceneWebview({super.key, required this.path});

  final String path;

  @override
  State<_CruiseSceneWebview> createState() => _CruiseSceneWebviewState();
}

class _CruiseSceneWebviewState extends State<_CruiseSceneWebview> {
  StreamSubscription<dynamic>? _messages;
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
      setState(() => _error = 'The ship did not finish loading. Try again.');
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
            : 'The cruise ship renderer could not start.';
      });
    }
  }

  void _retry() {
    _timeout?.cancel();
    _messages?.cancel();
    _messages = null;
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
    _messages?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attempt = _attempt;
    return Stack(
      children: [
        Positioned.fill(
          child: WindowsWebview(
            key: ValueKey('${widget.path}:$_attempt'),
            fileUrl: Uri.file(widget.path).toString(),
            onController: (controller) {
              if (!mounted || attempt != _attempt) return;
              _messages = controller.webMessage.listen((message) {
                if (mounted && attempt == _attempt) _receive(message);
              });
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
                  title: 'Could not start the cruise ship',
                  subtitle: _error!,
                  action: LumaGhostButton(
                    label: 'Retry',
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
