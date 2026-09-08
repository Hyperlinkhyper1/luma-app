import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/windows_webview.dart';

/// The **Pagoda Test** page loads an interactive Three.js voxel garden
/// benchmark — a procedurally generated Japanese garden with a 5-story pagoda.
///
/// The scene demonstrates voxel rendering, animation, interaction, and dynamic
/// day/night cycles. It runs in an embedded WebView on Windows and Android.
class PagodaTestPage extends StatefulWidget {
  const PagodaTestPage({super.key});

  @override
  State<PagodaTestPage> createState() => _PagodaTestPageState();
}

/// Maps each benchmarked model to its own independent scene asset.
///
/// Each model has a completely separate implementation of the Pagoda
/// benchmark — do not point two models at the same file.
const Map<String, String> _pagodaModelAssets = {
  'Haiku 4.5': 'assets/tests/pagoda_haiku45.html',
  'Sonnet 5 (Low)': 'assets/tests/pagoda_sonnet5_low.html',
  'Sonnet 5 (Ultracode)': 'assets/tests/pagoda_sonnet5_ultracode.html',
  'Opus 5 (low)': 'assets/tests/pagoda_opus5_low.html',
  'Opus 5 (Xhigh)': 'assets/tests/pagoda_opus5_xhigh.html',
  'Muse Spark 1.3 (Low)': 'assets/tests/pagoda_musespark13_low.html',
  'Muse Spark 1.3 (Xhigh)': 'assets/tests/pagoda_musespark13_xhigh.html',
  'Opus 4.6': 'assets/tests/pagoda_opus46.html',
  'Nemotron 3 Ultra': 'assets/tests/pagoda_nemotron3_ultra.html',
  'Nemotron 3.5 Lightning': 'assets/tests/pagoda_nemotron35_lightning.html',
  'GPT 5.4 mini': 'assets/tests/pagoda_gpt54_mini.html',
  'GPT 5 Mini': 'assets/tests/pagoda_gpt5_mini.html',
  'Big Pickle': 'assets/tests/pagoda_bigpickle.html',
  'Mistral Medium 3.5': 'assets/tests/pagoda_mistralmedium35.html',
  'Sonnet 4.6 (Max)': 'assets/tests/pagoda_sonnet46_max.html',
  'Sonnet 4.6 (Low)': 'assets/tests/pagoda_sonnet46_low.html',
  'GPT 4.1': 'assets/tests/pagoda_gpt41.html',
  'GPT 4.1 Nano': 'assets/tests/pagoda_gpt41_nano.html',
  'GPT 6 Astra (Low)': 'assets/tests/pagoda_gpt6_astra_low.html',
  'MiMo V2.5': 'assets/tests/pagoda_mimo_v25.html',
  'Mai Code 1.1 Flash (Github Copilot)':
      'assets/tests/pagoda_maicode11flash.html',
  'GPT 5.6 Luna (Low)': 'assets/tests/pagoda_gpt56_luna_low.html',
  'GPT 5.6 Luna (High)': 'assets/tests/pagoda_gpt56_luna_high.html',
  'Grok 4.6 (Medium)': 'assets/tests/pagoda_grok46_medium.html',
  'Grok 4.5': 'assets/tests/pagoda_grok45.html',
  'Gemma 4 (31B)': 'assets/tests/pagoda_gemma_4_31b.html',
    'GPT OSS 120B': 'assets/tests/pagoda_gpt_oss_120b.html',
};

class _PagodaTestPageState extends State<PagodaTestPage> {
  bool _loading = true;
  String? _selectedModel;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    // Show model selection UI if no model is selected
    if (_selectedModel == null) {
      return Scaffold(
        backgroundColor: luma.background,
        appBar: AppBar(
          backgroundColor: luma.background,
          elevation: 0,
          title: const Text('Pagoda Test'),
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
                'Spring Festival at the Five-Story Pagoda — an interactive voxel '
                'garden benchmark with procedural terrain, animated elements, and '
                'dynamic lighting.',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Select a Model',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Haiku 4.5',
                description: 'Fast vision model for the benchmark',
                onTap: () => setState(() => _selectedModel = 'Haiku 4.5'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Sonnet 5 (Low)',
                description: 'Balanced reasoning model for the benchmark',
                onTap: () => setState(() => _selectedModel = 'Sonnet 5 (Low)'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Sonnet 5 (Ultracode)',
                description: 'Frontier reasoning model for the benchmark',
                onTap: () =>
                    setState(() => _selectedModel = 'Sonnet 5 (Ultracode)'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Opus 5 (low)',
                description: 'Frontier model at low reasoning effort',
                onTap: () => setState(() => _selectedModel = 'Opus 5 (low)'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Opus 5 (Xhigh)',
                description: 'Frontier model at extra-high reasoning effort',
                onTap: () =>
                    setState(() => _selectedModel = 'Opus 5 (Xhigh)'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Muse Spark 1.3 (Low)',
                description: 'Meta Muse Spark at low reasoning effort',
                onTap: () =>
                    setState(() => _selectedModel = 'Muse Spark 1.3 (Low)'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Muse Spark 1.3 (Xhigh)',
                description: 'Meta Muse Spark at extra-high reasoning effort',
                onTap: () =>
                    setState(() => _selectedModel = 'Muse Spark 1.3 (Xhigh)'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Opus 4.6',
                description: 'Anthropic Opus 4.6 thinking model',
                onTap: () =>
                    setState(() => _selectedModel = 'Opus 4.6'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Nemotron 3 Ultra',
                description: 'NVIDIA Nemotron 3 Ultra benchmark',
                onTap: () =>
                    setState(() => _selectedModel = 'Nemotron 3 Ultra'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Nemotron 3.5 Lightning',
                description: 'NVIDIA Nemotron 3.5 Lightning voxel garden benchmark',
                onTap: () =>
                    setState(() => _selectedModel = 'Nemotron 3.5 Lightning'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'GPT 5.4 mini',
                description: 'OpenAI GPT 5.4 mini spring-festival scene',
                onTap: () =>
                    setState(() => _selectedModel = 'GPT 5.4 mini'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'GPT 5 Mini',
                description: 'GPT 5 Mini — native pagoda benchmark',
                onTap: () => setState(() => _selectedModel = 'GPT 5 Mini'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Big Pickle',
                description: 'Big Pickle independent voxel garden benchmark',
                onTap: () =>
                    setState(() => _selectedModel = 'Big Pickle'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Mistral Medium 3.5',
                description: 'Mistral Medium 3.5 voxel garden benchmark',
                onTap: () =>
                    setState(() => _selectedModel = 'Mistral Medium 3.5'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Sonnet 4.6 (Max)',
                description: 'Anthropic Sonnet 4.6 at max reasoning effort',
                onTap: () =>
                    setState(() => _selectedModel = 'Sonnet 4.6 (Max)'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Sonnet 4.6 (Low)',
                description: 'Anthropic Sonnet 4.6 at low reasoning effort',
                onTap: () =>
                    setState(() => _selectedModel = 'Sonnet 4.6 (Low)'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'GPT 4.1',
                description: 'OpenAI GPT 4.1 independent voxel garden benchmark',
                onTap: () => setState(() => _selectedModel = 'GPT 4.1'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'GPT 4.1 Nano',
                description: 'OpenAI GPT 4.1 Nano voxel garden benchmark',
                onTap: () => setState(() => _selectedModel = 'GPT 4.1 Nano'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'GPT 6 Astra (Low)',
                description: 'GPT 6 Astra Low voxel garden benchmark',
                onTap: () =>
                    setState(() => _selectedModel = 'GPT 6 Astra (Low)'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'MiMo V2.5',
                description: 'Xiaomi MiMo V2.5 voxel garden benchmark',
                onTap: () =>
                    setState(() => _selectedModel = 'MiMo V2.5'),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Mai Code 1.1 Flash (Github Copilot)',
                description: 'Independent GitHub Copilot benchmark scene',
                onTap: () => setState(
                  () => _selectedModel = 'Mai Code 1.1 Flash (Github Copilot)',
                ),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'GPT 5.6 Luna (Low)',
                description: 'OpenAI GPT 5.6 Luna at low reasoning effort',
                onTap: () => setState(
                  () => _selectedModel = 'GPT 5.6 Luna (Low)',
                ),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'GPT 5.6 Luna (High)',
                description: 'OpenAI GPT 5.6 Luna at high reasoning effort',
                onTap: () => setState(
                  () => _selectedModel = 'GPT 5.6 Luna (High)',
                ),
                isSelected: false,
              ),
              const SizedBox(height: 12),
              ModelButton(
                model: 'Grok 4.6 (Medium)',
                description: 'xAI Grok 4.6 at medium reasoning effort',
                onTap: () => setState(
                  () => _selectedModel = 'Grok 4.6 (Medium)',
                ),
                isSelected: false,
              ),
              const SizedBox(height: 12),
               ModelButton(
                 model: 'Grok 4.5',
                 description: 'xAI Grok 4.5 independent voxel garden benchmark',
                 onTap: () => setState(
                   () => _selectedModel = 'Grok 4.5',
                 ),
                 isSelected: false,
               ),
               const SizedBox(height: 12),
                ModelButton(
                  model: 'GPT OSS 120B',
                  description: 'GPT OSS 120B voxel garden benchmark',
                  onTap: () => setState(() => _selectedModel = 'GPT OSS 120B'),
                  isSelected: false,
                ),
                const SizedBox(height: 12),
             ],

          ),
        ),
      );
    }

    // Show benchmark scene
    if (Platform.isWindows) {
      // Each model must open its own scene. A model whose scene has not been
      // built yet says so — falling back to another model's file would show
      // one contestant's result under a different contestant's name.
      final assetPath = _pagodaModelAssets[_selectedModel];
      final scenePath =
          assetPath == null ? null : windowsAssetPath(assetPath);
      if (scenePath == null || !File(scenePath).existsSync()) {
        return Scaffold(
          backgroundColor: luma.background,
          appBar: AppBar(
            backgroundColor: luma.background,
            elevation: 0,
            title: const Text('Pagoda Test'),
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
          title: const Text('Pagoda Test'),
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

    // Fallback for non-Windows platforms
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: const Text('Pagoda Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: LumaEmptyState(
          icon: Icons.computer_rounded,
          title: 'Not available on this platform',
          subtitle: 'The Pagoda Test requires a Windows desktop. '
              'Mobile and Linux support are coming soon.',
        ),
      ),
    );
  }
}

/// A button to select and start a model benchmark.
class ModelButton extends StatefulWidget {
  const ModelButton({
    super.key,
    required this.model,
    required this.description,
    required this.onTap,
    required this.isSelected,
  });

  final String model;
  final String description;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  State<ModelButton> createState() => _ModelButtonState();
}

class _ModelButtonState extends State<ModelButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _hovered ? luma.surfaceHover : luma.surface,
          border: Border.all(
            color: _hovered ? luma.accent : luma.border,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.model,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          style: TextStyle(
                            color: luma.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 160),
                    offset: Offset(_hovered ? 0.2 : 0, 0),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: luma.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
