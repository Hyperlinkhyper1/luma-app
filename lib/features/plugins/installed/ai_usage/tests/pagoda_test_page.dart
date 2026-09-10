import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/windows_webview.dart';
import '../leaderboard/ai_vendor_style.dart';
import '../leaderboard/vendor_logos.dart';
import 'model_search_field.dart';
import 'pagoda_view_prefs.dart';

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
  'Opus 5 (Max)': 'assets/tests/pagoda_opus5_max.html',
  'Muse Spark 1.3 (Low)': 'assets/tests/pagoda_musespark13_low.html',
  'Muse Spark 1.3 (Xhigh)': 'assets/tests/pagoda_musespark13_xhigh.html',
  'Opus 4.6': 'assets/tests/pagoda_opus46.html',
  'Nemotron 3 Ultra': 'assets/tests/pagoda_nemotron3_ultra.html',
  'Nemotron 3.5 Lightning': 'assets/tests/pagoda_nemotron35_lightning.html',
  'GPT 5.4 mini': 'assets/tests/pagoda_gpt54_mini.html',
  'GPT 5 Mini': 'assets/tests/pagoda_gpt5_mini.html',
  'GPT 5': 'assets/tests/pagoda_gpt5.html',
  'hy4': 'assets/tests/pagoda_hy4.html',
  'Big Pickle': 'assets/tests/pagoda_bigpickle.html',
  'Mistral Medium 3.5': 'assets/tests/pagoda_mistralmedium35.html',
  'Sonnet 4.6 (Max)': 'assets/tests/pagoda_sonnet46_max.html',
  'Sonnet 4.6 (Low)': 'assets/tests/pagoda_sonnet46_low.html',
  'GPT 4.1': 'assets/tests/pagoda_gpt41.html',
  'GPT 4.1 Nano': 'assets/tests/pagoda_gpt41_nano.html',
  'GPT 6 Astra (Low)': 'assets/tests/pagoda_gpt6_astra_low.html',
  'GPT 6 Astra (Max)': 'assets/tests/pagoda_gpt6_astra_max.html',
  'MiMo V2.5': 'assets/tests/pagoda_mimo_v25.html',
  'Mai Code 1.1 Flash (Github Copilot)':
      'assets/tests/pagoda_maicode11flash.html',
  'GPT 5.6 Luna (Low)': 'assets/tests/pagoda_gpt56_luna_low.html',
  'GPT 5.6 Luna (High)': 'assets/tests/pagoda_gpt56_luna_high.html',
  'GPT 5.6 Terra (XHigh)': 'assets/tests/pagoda_gpt56_terra_xhigh.html',
  'GPT 5.6 Sol (Xhigh)': 'assets/tests/pagoda_gpt56_sol_xhigh.html',
  'GPT 5.6 Sol (Medium)': 'assets/tests/pagoda_gpt56_sol_medium.html',
  'Seed 2.1 Pro': 'assets/tests/pagoda_seed21_pro.html',
  'Grok 4.6 (Medium)': 'assets/tests/pagoda_grok46_medium.html',
  'Grok 4.5': 'assets/tests/pagoda_grok45.html',
  'Gemma 4 (31B)': 'assets/tests/pagoda_gemma_4_31b.html',
    'GPT OSS 120B': 'assets/tests/pagoda_gpt_oss_120b.html',
  'Laguna XS 2.1': 'assets/tests/pagoda_laguna_xs21.html',
  'Fable 5.1 (High)': 'assets/tests/pagoda_fable51_high.html',
  'Fable 5.1 (Max)': 'assets/tests/pagoda_fable51_max.html',
  'Qwen 3.8 (27B)': 'assets/tests/pagoda_qwen_3_8_27b.html',
  'DeepSeek v4.1 Flash (Max)': 'assets/tests/pagoda_deepseek41_flash_max.html',
};

/// Scenes whose WebGL output can't be captured for a thumbnail in this
/// environment (software-renderer black screens / endless loaders) share
/// the generic preview instead of a black card.
const _pagodaPreviewFallbacks = {
  'pagoda_bigpickle.png',
  'pagoda_gemma_4_31b.png',
  'pagoda_gpt41_nano.png',
  'pagoda_gpt5.png',
  'pagoda_gpt_oss_120b.png',
};

/// Preview thumbnail for [model]'s own benchmark scene, captured from the
/// scene itself. Falls back to the shared pagoda render when the model has
/// no scene or its scene has no usable capture (see
/// [_pagodaPreviewFallbacks]).
String pagodaPreviewAsset(String model) {
  final scene = _pagodaModelAssets[model];
  if (scene == null) return 'assets/tests/pagoda-preview.png';
  final base = scene.split('/').last.replaceAll('.html', '.png');
  if (_pagodaPreviewFallbacks.contains(base)) {
    return 'assets/tests/pagoda-preview.png';
  }
  return 'assets/tests/previews/$base';
}

/// Vendor key for a pagoda benchmark [model], covering the shared vendors
/// plus the local brands (`xiaomi`, `github`, `pickle`, `laguna`).
/// Null only for a name nothing matches — those get the fallback cube.
String? pagodaVendorKey(String model) {
  final m = model;
  if (m.contains('Mistral')) return 'mistralai';
  if (m.contains('Nemotron')) return 'nvidia';
  if (m.contains('Haiku') ||
      m.contains('Sonnet') ||
      m.contains('Opus') ||
      m.contains('Claude')) {
    return 'anthropic';
  }
  if (m.contains('Muse Spark') || m.contains('Llama')) return 'meta';
  if (m.contains('Grok')) return 'x-ai';
  if (m.contains('Gemini') || m.contains('Gemma')) return 'google';
  if (m.contains('GPT') || m.contains('OpenAI')) return 'openai';
  if (m.contains('GLM') || m.contains('Zhipu')) return 'z-ai';
  if (m.contains('Qwen')) return 'qwen';
  if (m.contains('DeepSeek') || m.contains('Deepseek')) return 'deepseek';
  if (m.contains('Kimi') || m.contains('Moonshot')) return 'moonshotai';
  if (m.contains('MiniMax') || m.contains('Minimax')) return 'minimax';
  if (m.contains('MiMo') || m.contains('Xiaomi')) return 'xiaomi';
  if (m.contains('Mai Code') || m.contains('Copilot') || m.contains('Github')) {
    return 'github';
  }
  if (m.contains('Pickle')) return 'pickle';
  if (m.contains('Laguna')) return 'laguna';
  return null;
}

/// Display name of the vendor behind [model], for by-vendor lines and
/// logo tooltips.
String pagodaVendorName(String model) {
  final m = model;
  switch (pagodaVendorKey(model)) {
    case 'anthropic':
      return 'Anthropic';
    case 'meta':
      return 'Meta';
    case 'nvidia':
      return 'NVIDIA';
    case 'openai':
      return 'OpenAI';
    case 'z-ai':
      return 'Zhipu AI';
    case 'qwen':
      return 'Qwen';
    case 'deepseek':
      return 'DeepSeek';
    case 'moonshotai':
      return 'Moonshot AI';
    case 'minimax':
      return 'MiniMax';
    case 'mistralai':
      return 'Mistral AI';
    case 'x-ai':
      return 'xAI';
    case 'google':
      return 'Google';
    case 'xiaomi':
      return 'Xiaomi';
    case 'github':
      return 'GitHub Copilot';
    case 'pickle':
      return 'Big Pickle';
    case 'laguna':
      return 'Laguna';
    case _:
      return m;
  }
}

/// Company brand color(s) behind a model button, keyed off the shared vendor
/// palette ([vendorColor]) so every model — present or added later — gets
/// its provider's color. Vendors with no shared entry fall back to a local
/// constant. Mistral returns three colors (yellow/orange/red blocks).
List<Color> pagodaBrandStops(String model) {
  final m = model;
  if (m.contains('Mistral')) {
    return const [
      Color(0xFFFFD800),
      Color(0xFFFF8205),
      Color(0xFFE10500),
    ];
  }
  if (m.contains('Nemotron')) return [vendorColor('nvidia')];
  if (m.contains('Haiku') ||
      m.contains('Sonnet') ||
      m.contains('Opus') ||
      m.contains('Claude')) {
    return [vendorColor('anthropic')];
  }
  if (m.contains('Muse Spark') || m.contains('Llama')) {
    return [vendorColor('meta')];
  }
  if (m.contains('Grok')) return [vendorColor('x-ai')];
  if (m.contains('Gemini') || m.contains('Gemma')) {
    return [vendorColor('google')];
  }
  if (m.contains('GPT') || m.contains('OpenAI')) {
    return [vendorColor('openai')];
  }
  if (m.contains('GLM') || m.contains('Zhipu')) return [vendorColor('z-ai')];
  if (m.contains('Qwen')) return [vendorColor('qwen')];
  if (m.contains('DeepSeek') || m.contains('Deepseek')) {
    return [vendorColor('deepseek')];
  }
  if (m.contains('Kimi') || m.contains('Moonshot')) {
    return [vendorColor('moonshotai')];
  }
  if (m.contains('MiniMax') || m.contains('Minimax')) {
    return [vendorColor('minimax')];
  }
  if (m.contains('MiMo') || m.contains('Xiaomi')) {
    return const [Color(0xFFFF6900)];
  }
  if (m.contains('Mai Code') ||
      m.contains('Copilot') ||
      m.contains('Github')) {
    return const [Color(0xFF6E40C9)];
  }
  if (m.contains('Pickle')) return const [Color(0xFF6DBE45)];
  if (m.contains('Laguna')) return const [Color(0xFF22D3EE)];
  return const [kVendorColorFallback];
}

/// Model name + button description, in display order. Drives both the List
/// view's [ModelButton]s and the search filter — kept as one list of pairs
/// (rather than a loop over [_pagodaModelAssets]) because the description
/// text isn't derivable from the model name.
const List<({String model, String description})> _pagodaModelDescriptions = [
  (model: 'Haiku 4.5', description: 'Fast vision model for the benchmark'),
  (
    model: 'Sonnet 5 (Low)',
    description: 'Balanced reasoning model for the benchmark',
  ),
  (
    model: 'Sonnet 5 (Ultracode)',
    description: 'Frontier reasoning model for the benchmark',
  ),
  (
    model: 'Opus 5 (low)',
    description: 'Frontier model at low reasoning effort',
  ),
  (
    model: 'Opus 5 (Xhigh)',
    description: 'Frontier model at extra-high reasoning effort',
  ),
  (
    model: 'Opus 5 (Max)',
    description: 'Frontier model at max reasoning effort',
  ),
  (
    model: 'Muse Spark 1.3 (Low)',
    description: 'Meta Muse Spark at low reasoning effort',
  ),
  (
    model: 'Muse Spark 1.3 (Xhigh)',
    description: 'Meta Muse Spark at extra-high reasoning effort',
  ),
  (model: 'Opus 4.6', description: 'Anthropic Opus 4.6 thinking model'),
  (
    model: 'Nemotron 3 Ultra',
    description: 'NVIDIA Nemotron 3 Ultra benchmark',
  ),
  (
    model: 'Nemotron 3.5 Lightning',
    description: 'NVIDIA Nemotron 3.5 Lightning voxel garden benchmark',
  ),
  (
    model: 'GPT 5.4 mini',
    description: 'OpenAI GPT 5.4 mini spring-festival scene',
  ),
  (model: 'GPT 5 Mini', description: 'GPT 5 Mini — native pagoda benchmark'),
  (model: 'GPT 5', description: 'GPT 5 independent voxel garden benchmark'),
  (model: 'hy4', description: 'hy4 independent voxel garden benchmark'),
  (
    model: 'Big Pickle',
    description: 'Big Pickle independent voxel garden benchmark',
  ),
  (
    model: 'Mistral Medium 3.5',
    description: 'Mistral Medium 3.5 voxel garden benchmark',
  ),
  (
    model: 'Sonnet 4.6 (Max)',
    description: 'Anthropic Sonnet 4.6 at max reasoning effort',
  ),
  (
    model: 'Sonnet 4.6 (Low)',
    description: 'Anthropic Sonnet 4.6 at low reasoning effort',
  ),
  (
    model: 'GPT 4.1',
    description: 'OpenAI GPT 4.1 independent voxel garden benchmark',
  ),
  (
    model: 'GPT 4.1 Nano',
    description: 'OpenAI GPT 4.1 Nano voxel garden benchmark',
  ),
  (
    model: 'GPT 6 Astra (Low)',
    description: 'GPT 6 Astra Low voxel garden benchmark',
  ),
  (
    model: 'GPT 6 Astra (Max)',
    description: 'GPT 6 Astra Max voxel garden benchmark',
  ),
  (
    model: 'MiMo V2.5',
    description: 'Xiaomi MiMo V2.5 voxel garden benchmark',
  ),
  (
    model: 'Mai Code 1.1 Flash (Github Copilot)',
    description: 'Independent GitHub Copilot benchmark scene',
  ),
  (
    model: 'GPT 5.6 Luna (Low)',
    description: 'OpenAI GPT 5.6 Luna at low reasoning effort',
  ),
  (
    model: 'GPT 5.6 Luna (High)',
    description: 'OpenAI GPT 5.6 Luna at high reasoning effort',
  ),
  (
    model: 'GPT 5.6 Terra (XHigh)',
    description: 'OpenAI GPT 5.6 Terra at extra-high reasoning effort',
  ),
  (
    model: 'GPT 5.6 Sol (Xhigh)',
    description: 'OpenAI GPT 5.6 Sol at extra-high reasoning effort',
  ),
  (
    model: 'GPT 5.6 Sol (Medium)',
    description: 'OpenAI GPT 5.6 Sol at medium reasoning effort',
  ),
  (model: 'Seed 2.1 Pro', description: 'Seed 2.1 Pro voxel garden benchmark'),
  (
    model: 'Grok 4.6 (Medium)',
    description: 'xAI Grok 4.6 at medium reasoning effort',
  ),
  (
    model: 'Grok 4.5',
    description: 'xAI Grok 4.5 independent voxel garden benchmark',
  ),
  (
    model: 'Gemma 4 (31B)',
    description: 'Google Gemma 4 31B voxel garden benchmark',
  ),
  (
    model: 'GPT OSS 120B',
    description: 'GPT OSS 120B voxel garden benchmark',
  ),
  (
    model: 'Laguna XS 2.1',
    description: 'Laguna XS 2.1 floating-island voxel garden benchmark',
  ),
  (
    model: 'Fable 5.1 (High)',
    description: 'Fable 5.1 High voxel garden benchmark',
  ),
  (
    model: 'Fable 5.1 (Max)',
    description: 'Fable 5.1 Max voxel garden benchmark',
  ),
  (
    model: 'Qwen 3.8 (27B)',
    description: 'Qwen 3.8 27B voxel garden benchmark',
  ),
  (
    model: 'DeepSeek v4.1 Flash (Max)',
    description: 'DeepSeek v4.1 Flash at max reasoning effort',
  ),
];

class _PagodaTestPageState extends State<PagodaTestPage> {
  bool _loading = true;
  String? _selectedModel;
  bool _bannerView = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    PagodaViewPrefs.loadBannerView().then((banners) {
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
    final luma = context.luma;
    final query = _query.trim().toLowerCase();
    final filteredModels = query.isEmpty
        ? _pagodaModelDescriptions
        : [
            for (final entry in _pagodaModelDescriptions)
              if (entry.model.toLowerCase().contains(query)) entry,
          ];

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
                      PagodaViewPrefs.saveBannerView(banners);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_bannerView)
                filteredModels.isEmpty
                    ? LumaEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No models match "${_query.trim()}"',
                        subtitle: 'Try a shorter search.',
                      )
                    : _ModelBannerGrid(
                        models: [for (final e in filteredModels) e.model],
                        onPick: (m) => setState(() => _selectedModel = m),
                      )
              else if (filteredModels.isEmpty)
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

  bool get _isMistral => widget.model.contains('Mistral');

  List<Color> _brandStops() => pagodaBrandStops(widget.model);

  String? _vendorKey() => pagodaVendorKey(widget.model);

  String _badgeLabel() => pagodaVendorName(widget.model);

  /// Company logo mark for the full-left of the button — the hand-drawn
  /// [VendorLogo], never an initial in a circle. Unknown models get the
  /// fallback voxel cube.
  Widget _logoBadge() {
    return VendorLogo(
      vendor: _vendorKey() ?? '',
      vendorName: _badgeLabel(),
      size: 32,
    );
  }

  /// Static background wash for the button: the company gradient for most
  /// models, Mistral's diagonal cube mosaic (see [_MistralCubesPainter]).
  Widget _brandUnderlay() {
    if (_isMistral) {
      return const CustomPaint(painter: _MistralCubesPainter());
    }
    return DecoratedBox(
      decoration: BoxDecoration(gradient: _buildGradient()),
      child: const SizedBox.expand(),
    );
  }

  /// Company gradient painted over the card base: it runs from the left edge
  /// and fades fully to transparent at the middle (`Alignment.center`), so
  /// the right half stays the plain surface.
  ///
  /// Deliberately a static per-model layer (see `build`): it is never part
  /// of the hover animation.
  Gradient _buildGradient() {
    final brand = _brandStops().first;
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.center,
      colors: [
        brand.withValues(alpha: 0.38),
        brand.withValues(alpha: 0.0),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final base = _hovered ? luma.surfaceHover : luma.surface;
    final brand = _isMistral ? const Color(0xFFFF8205) : _brandStops().first;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: base,
          border: Border.all(
            color: _hovered ? brand : luma.border,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        // Static gradient underlay: hover animates only the base color and
        // border above. Re-animating the gradient itself on every hover
        // frame — chiefly Mistral's hard-stop blocks — is what flickered.
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _brandUnderlay(),
              ),
            ),
            Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    _logoBadge(),
                    const SizedBox(width: 12),
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
                        color: brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

/// Mistral's button background: small voxel cubes tiling the left half,
/// shaded yellow → orange → red along the top-left to bottom-right diagonal.
class _MistralCubesPainter extends CustomPainter {
  const _MistralCubesPainter();

  static const _yellow = Color(0xFFFFD800);
  static const _orange = Color(0xFFFF8205);
  static const _red = Color(0xFFE10500);

  static Color _at(double t) => t < 0.5
      ? Color.lerp(_yellow, _orange, t * 2)!
      : Color.lerp(_orange, _red, (t - 0.5) * 2)!;

  @override
  void paint(Canvas canvas, Size size) {
    const cube = 9.0;
    const step = 12.0; // cube + gap
    final halfW = size.width / 2;
    final cols = (halfW / step).floor();
    if (cols < 1) return;
    final rows = (size.height / step).ceil().clamp(1, 1 << 20);
    final yOff = (size.height - (rows * step - (step - cube))) / 2;
    final denom = (cols + rows - 2).clamp(1, 1 << 20);
    final paint = Paint();
    for (var col = 0; col < cols; col++) {
      for (var row = 0; row < rows; row++) {
        final t = ((col + row) / denom).clamp(0.0, 1.0);
        paint.color = _at(t).withValues(alpha: 0.42);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(col * step, yOff + row * step, cube, cube),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Banner-style model card: the pagoda preview image on top with the model
/// name and vendor below, Modrinth-tile style. Alternative to [ModelButton].
class ModelBanner extends StatefulWidget {
  const ModelBanner({super.key, required this.model, required this.onTap});

  final String model;
  final VoidCallback onTap;

  @override
  State<ModelBanner> createState() => _ModelBannerState();
}

class _ModelBannerState extends State<ModelBanner> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final vendor = pagodaVendorName(widget.model);
    final brand = widget.model.contains('Mistral')
        ? const Color(0xFFFF8205)
        : pagodaBrandStops(widget.model).first;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: _hovered ? luma.surfaceHover : luma.surface,
            border: Border.all(
              color: _hovered ? brand : luma.border,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.asset(
                    pagodaPreviewAsset(widget.model),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: luma.surfaceHover,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.temple_buddhist_rounded,
                        size: 48,
                        color: luma.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    VendorLogo(
                      vendor: pagodaVendorKey(widget.model) ?? '',
                      vendorName: vendor,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.model,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'by $vendor',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: luma.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Responsive grid of [ModelBanner] cards: two columns on wide screens, one
/// below 560px. Renders whichever [models] the caller passes in — the full
/// roster, or a search-filtered subset.
class _ModelBannerGrid extends StatelessWidget {
  const _ModelBannerGrid({required this.models, required this.onPick});

  final List<String> models;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth > 560 ? 2 : 1;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final model in models)
              SizedBox(
                width: width,
                child: ModelBanner(
                  model: model,
                  onTap: () => onPick(model),
                ),
              ),
          ],
        );
      },
    );
  }
}
