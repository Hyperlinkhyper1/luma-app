import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../leaderboard/vendor_logos.dart';
import 'ai_benchmark.dart';
import 'ai_benchmark_scope.dart';
import 'pagoda_test_page.dart'
    show pagodaBrandStops, pagodaVendorKey, pagodaVendorName;

/// Banner-style model card: the scene's preview image on top with the model
/// name and vendor below, Modrinth-tile style. The alternative to the list's
/// `ModelButton`, shared by every test page.
///
/// The preview is the server-cached PNG when it has downloaded, otherwise the
/// test's generic artwork, otherwise [fallbackIcon] — a card whose artwork is
/// still downloading looks intentional rather than broken.
class ModelBanner extends StatefulWidget {
  const ModelBanner({
    super.key,
    required this.benchmark,
    required this.onTap,
    this.fallbackIcon = Icons.image_outlined,
  });

  final AiBenchmark benchmark;
  final VoidCallback onTap;

  /// Shown in place of artwork that has not downloaded. Each test passes its
  /// own mark, the same one its hero tile uses.
  final IconData fallbackIcon;

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

    Widget placeholder() => Container(
          color: luma.surfaceHover,
          alignment: Alignment.center,
          child: Icon(
            widget.fallbackIcon,
            size: 48,
            color: luma.textMuted,
          ),
        );

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
                      ? placeholder()
                      : Image.file(
                          preview,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              placeholder(),
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
class ModelBannerGrid extends StatelessWidget {
  const ModelBannerGrid({
    super.key,
    required this.models,
    required this.onPick,
    this.fallbackIcon = Icons.image_outlined,
  });

  final List<AiBenchmark> models;
  final ValueChanged<AiBenchmark> onPick;
  final IconData fallbackIcon;

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
                  fallbackIcon: fallbackIcon,
                  onTap: () => onPick(model),
                ),
              ),
          ],
        );
      },
    );
  }
}
