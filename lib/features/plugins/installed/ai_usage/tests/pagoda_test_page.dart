import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../../_shared/windows_webview.dart';
import '../leaderboard/ai_vendor_style.dart';
import '../leaderboard/vendor_logos.dart';
import 'ai_benchmark.dart';
import 'ai_benchmark_scope.dart';
import 'model_search_field.dart';
import 'pagoda_view_prefs.dart';

/// The **Pagoda Test** page loads an interactive Three.js voxel garden
/// benchmark — a procedurally generated Japanese garden with a 5-story pagoda.
///
/// The scene demonstrates voxel rendering, animation, interaction, and dynamic
/// day/night cycles. It runs in an embedded WebView on Windows.
///
/// Scenes used to ship inside the app bundle; they live on the luma server
/// now. The roster comes from [AiBenchmarkScope], each scene downloads on
/// first open and is cached on disk after that.
class PagodaTestPage extends StatefulWidget {
  const PagodaTestPage({super.key});

  @override
  State<PagodaTestPage> createState() => _PagodaTestPageState();
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

class _PagodaTestPageState extends State<PagodaTestPage> {
  String? _selectedId;
  bool _bannerView = false;
  final _searchController = TextEditingController();
  String _query = '';
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AiBenchmarkScope.of(context).load();
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
    final repo = AiBenchmarkScope.of(context);
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final benchmarks = repo.benchmarksOfKind('pagoda');
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
            // The roster moved under us (rare) — back to the list.
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
            else if (_bannerView)
              _ModelBannerGrid(
                models: filtered,
                onPick: (b) => setState(() => _selectedId = b.id),
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
          title: const Text('Pagoda Test'),
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
            subtitle: 'The Pagoda Test requires a Windows desktop. '
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
        title: const Text('Pagoda Test'),
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
          return _SceneWebview(path: snapshot.data!.path);
        },
      ),
    );
  }
}

/// The embedded scene, remounted per file so going back and opening another
/// model never shows the previous scene.
class _SceneWebview extends StatefulWidget {
  const _SceneWebview({required this.path});

  final String path;

  @override
  State<_SceneWebview> createState() => _SceneWebviewState();
}

class _SceneWebviewState extends State<_SceneWebview> {
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

/// Banner-style model card: the scene's preview image on top with the model
/// name and vendor below, Modrinth-tile style. Alternative to [ModelButton].
///
/// The preview is the server-cached PNG when it has downloaded, otherwise the
/// test's generic artwork, otherwise the temple icon — a card whose artwork is
/// still downloading looks intentional rather than broken.
class ModelBanner extends StatefulWidget {
  const ModelBanner(
      {super.key, required this.benchmark, required this.onTap});

  final AiBenchmark benchmark;
  final VoidCallback onTap;

  @override
  State<ModelBanner> createState() => _ModelBannerState();
}

class _ModelBannerState extends State<ModelBanner> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = AiBenchmarkScope.of(context);
    final vendor = pagodaVendorName(widget.benchmark.model);
    final brand = widget.benchmark.model.contains('Mistral')
        ? const Color(0xFFFF8205)
        : pagodaBrandStops(widget.benchmark.model).first;
    final preview = repo.previewFile(widget.benchmark.id) ??
        repo.fallbackFile(widget.benchmark.kind);

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
                  child: preview == null
                      ? Container(
                          color: luma.surfaceHover,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.temple_buddhist_rounded,
                            size: 48,
                            color: luma.textMuted,
                          ),
                        )
                      : Image.file(
                          preview,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
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
                      vendor: pagodaVendorKey(widget.benchmark.model) ?? '',
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
                            widget.benchmark.model,
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

  final List<AiBenchmark> models;
  final ValueChanged<AiBenchmark> onPick;

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
                  benchmark: model,
                  onTap: () => onPick(model),
                ),
              ),
          ],
        );
      },
    );
  }
}
