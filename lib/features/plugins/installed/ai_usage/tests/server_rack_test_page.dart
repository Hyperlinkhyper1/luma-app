import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/windows_webview.dart'
    show WindowsWebview, windowsAssetPath;
import 'pagoda_test_page.dart' show ModelButton;
import 'ai_benchmark_scope.dart';

class _BundledRackTest {
  const _BundledRackTest({
    required this.model,
    required this.description,
    required this.asset,
  });

  final String model;
  final String description;
  final String asset;
}

const _bundledRackTests = <_BundledRackTest>[
  _BundledRackTest(
    model: 'Sonnet 5.5 (Low)',
    description: 'Full 42U rack plus single-slice server inspection by '
        'Sonnet 5.5 Low.',
    asset: 'assets/ai_usage/server_rack_tests/sonnet_5_5_low.html',
  ),
  _BundledRackTest(
    model: 'Sonnet 5.5 (Xhigh)',
    description: 'A 42U rack of nine inspectable servers; each one slides '
        'out on its rails into an open single-slice view with exploded, '
        'cutaway and airflow modes.',
    asset: 'assets/ai_usage/server_rack_tests/sonnet_5_5_xhigh.html',
  ),
  _BundledRackTest(
    model: 'Sonnet 5.5 (High)',
    description: 'A 42U rack with labelled units that opens into a '
        'per-server detail view with airflow simulation.',
    asset: 'assets/ai_usage/server_rack_tests/sonnet_5_5_high.html',
  ),
  _BundledRackTest(
    model: 'Opus 5.5 (Low)',
    description: 'A cabled 42U rack of nine servers across five archetypes; '
        'each slides out into an open-chassis slice with exploded, '
        'cutaway and obstacle-aware airflow views.',
    asset: 'assets/ai_usage/server_rack_tests/opus_5_5_low.html',
  ),
  _BundledRackTest(
    model: 'Opus 5.5 (XHigh)',
    description: 'A cabled, power-budgeted 42U rack of nine servers with '
        'nine different layouts; each unlatches, slides out on its rails '
        'and opens into a hoverable slice with exploded, cutaway and '
        'solved-airflow views.',
    asset: 'assets/ai_usage/server_rack_tests/opus_5_5_xhigh.html',
  ),
  _BundledRackTest(
    model: 'Muse Spark 1.3 (Max)',
    description: 'RACKSCOPE·42U: a cabled rack with a unit browser and '
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
                    fileUrl:
                        Uri.file(windowsAssetPath(selected.asset)).toString(),
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
            Text(
              'Select a Model',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in uploads) ...[
              ModelButton(
                model: entry.model,
                vendor: entry.vendor,
                description: entry.description,
                onTap: () => setState(() {
                  _uploadedModel = entry.model;
                  _uploadedScene = repo.sceneFile(entry.id);
                }),
                isSelected: false,
              ),
              const SizedBox(height: 12),
            ],
            for (final entry in _bundledRackTests) ...[
              ModelButton(
                model: entry.model,
                description: entry.description,
                onTap: () => setState(() => _selected = entry),
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
