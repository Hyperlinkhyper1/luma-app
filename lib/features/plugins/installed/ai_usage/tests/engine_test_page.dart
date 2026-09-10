import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/windows_webview.dart';
import 'model_search_field.dart';
import 'pagoda_test_page.dart' show ModelButton;

/// The **Engine Test** page loads an interactive Three.js V8 cutaway
/// benchmark — a mechanically driven cross-plane 90-degree V8 with a live
/// engineering dashboard and a 30-second benchmark mode.
///
/// Each benchmarked model gets its own independent scene asset. Each model
/// has a completely separate implementation of the Engine benchmark — do not
/// point two models at the same file.
const Map<String, String> _engineModelAssets = {
  'Muse Spark 1.3 (Xhigh)': 'assets/tests/engine_musespark13_xhigh.html',
  'Sonnet 5 (XHigh)': 'assets/tests/engine_sonnet5_xhigh.html',
  'GPT 6 Astra (Max)': 'assets/tests/engine_gpt6_astra_max.html',
  'DeepSeek V4 Pro': 'assets/tests/engine_deepseekv4_pro.html',
};

/// Model name + button description, in display order. Drives both the list
/// view's [ModelButton]s and the search filter — kept as one list of pairs
/// (rather than a loop over [_engineModelAssets]) because the description
/// text isn't derivable from the model name.
const List<({String model, String description})> _engineModelDescriptions = [
  (
    model: 'Muse Spark 1.3 (Xhigh)',
    description: 'Real-time cutaway V8: crank-driven pistons, half-speed cams, synced valves and combustion',
  ),
  (
    model: 'Sonnet 5 (XHigh)',
    description: 'Anthropic Sonnet 5 at extra-high reasoning effort',
  ),
  (
    model: 'GPT 6 Astra (Max)',
    description: 'GPT 6 Astra Max independent cutaway V8 benchmark',
  ),
  (
    model: 'DeepSeek V4 Pro',
    description: 'DeepSeek V4 Pro independent cutaway V8 benchmark',
  ),
];

class EngineTestPage extends StatefulWidget {
  const EngineTestPage({super.key});

  @override
  State<EngineTestPage> createState() => _EngineTestPageState();
}

class _EngineTestPageState extends State<EngineTestPage> {
  bool _loading = true;
  String? _selectedModel;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final query = _query.trim().toLowerCase();
    final filteredModels = query.isEmpty
        ? _engineModelDescriptions
        : [
            for (final entry in _engineModelDescriptions)
              if (entry.model.toLowerCase().contains(query)) entry,
          ];

    if (_selectedModel == null) {
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
              if (filteredModels.isEmpty)
                LumaEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No models match "${_query.trim()}"',
                  subtitle: 'Try a shorter search.',
                )
              else
                for (final entry in filteredModels) ...[
                  ModelButton(
                    model: entry.model,
                    description: entry.description,
                    onTap: () => setState(() => _selectedModel = entry.model),
                    isSelected: false,
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      );
    }

    if (Platform.isWindows) {
      // Each model must open its own scene. A model whose scene has not been
      // built yet says so — falling back to another model's file would show
      // one contestant's result under a different contestant's name.
      final assetPath = _engineModelAssets[_selectedModel];
      final scenePath =
          assetPath == null ? null : windowsAssetPath(assetPath);
      if (scenePath == null || !File(scenePath).existsSync()) {
        return Scaffold(
          backgroundColor: luma.background,
          appBar: AppBar(
            backgroundColor: luma.background,
            elevation: 0,
            title: const Text('Engine Test'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _selectedModel = null),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: LumaEmptyState(
              icon: Icons.hourglass_empty_rounded,
              title: 'No scene for $_selectedModel yet',
              subtitle: 'This benchmark run has not produced a scene file. '
                  'Pick another model, or add '
                  '${assetPath ?? 'its entry to the model list'}.',
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
            onPressed: () => setState(() => _selectedModel = null),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: WindowsWebview(
                fileUrl: Uri.file(scenePath).toString(),
                onLoaded: () {
                  if (mounted) setState(() => _loading = false);
                },
              ),
            ),
            if (_loading)
              Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(luma.accent),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: const Text('Engine Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: LumaEmptyState(
          icon: Icons.computer_rounded,
          title: 'Not available on this platform',
          subtitle: 'The Engine Test requires a Windows desktop. '
              'Mobile and Linux support are coming soon.',
        ),
      ),
    );
  }
}
