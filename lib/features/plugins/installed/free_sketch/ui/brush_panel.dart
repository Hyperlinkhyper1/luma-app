import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../model/brush.dart';
import '../model/sketch_tool.dart';
import 'studio_controller.dart';
import 'studio_widgets.dart';

/// The brush library for the active brush tool, and the settings of the
/// brush it has selected. Each brush is shown as a real stroke drawn by the
/// same engine the canvas uses, so what you see in the list is what you get.
class BrushPanel extends StatefulWidget {
  const BrushPanel({super.key, required this.controller, this.onClose});

  final StudioController controller;
  final VoidCallback? onClose;

  @override
  State<BrushPanel> createState() => _BrushPanelState();
}

class _BrushPanelState extends State<BrushPanel> {
  late BrushCategory _category = widget.controller.brush.category;
  bool _settings = false;

  StudioController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final brush = c.brush;
        return StudioPanel(
          width: 320,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHeader(
                title: c.brushTool == SketchTool.brush ? 'Brushes' : '${c.brushTool.label} brushes',
                onClose: widget.onClose,
              ),
              const SizedBox(height: 6),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: false, label: Text('Library'), icon: Icon(Icons.brush_rounded, size: 16)),
                  ButtonSegment(value: true, label: Text('Settings'), icon: Icon(Icons.tune_rounded, size: 16)),
                ],
                selected: {_settings},
                onSelectionChanged: (s) => setState(() => _settings = s.first),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: _settings ? _settingsView(brush, luma) : _library(brush, luma),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _library(BrushPreset current, LumaPalette luma) {
    final brushes = BrushLibrary.inCategory(_category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final category in BrushCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(category.label),
                    selected: category == _category,
                    visualDensity: VisualDensity.compact,
                    labelStyle: const TextStyle(fontSize: 12),
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: brushes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final preset = brushes[index];
              final effective = c.effectiveBrush(preset.id);
              final selected = preset.id == current.id;
              return Material(
                color: selected ? luma.accentSubtle : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => c.selectBrush(preset.id),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                preset.name,
                                style: TextStyle(
                                  color: selected ? luma.accent : luma.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (c.hasOverrides(preset.id))
                              Tooltip(
                                message: 'Customised',
                                child: Icon(Icons.tune_rounded, size: 13, color: luma.textMuted),
                              ),
                          ],
                        ),
                        SizedBox(
                          height: 44,
                          child: CustomPaint(
                            painter: _ImagePainter(c.brushPreview(effective, luma.textPrimary)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _settingsView(BrushPreset brush, LumaPalette luma) {
    final base = BrushLibrary.byId(brush.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                brush.name,
                style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            TextButton.icon(
              onPressed: c.hasOverrides(brush.id) ? c.resetBrush : null,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset'),
            ),
          ],
        ),
        Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: luma.background,
            border: Border.all(color: luma.border),
          ),
          child: CustomPaint(
            painter: _ImagePainter(c.brushPreview(brush, luma.textPrimary, width: 290, height: 64)),
          ),
        ),
        const SizedBox(height: 6),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final param in brush.adjustable)
                _paramSlider(param, brush, base),
              const SizedBox(height: 4),
              Text(
                _describe(brush),
                style: TextStyle(color: luma.textMuted, fontSize: 11, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paramSlider(BrushParam param, BrushPreset brush, BrushPreset base) {
    final value = brush.get(param);
    final changed = (value - base.get(param)).abs() > 1e-6;
    if (param == BrushParam.size) {
      // Squared mapping: most of the travel goes to small sizes.
      final max = brush.maxSize;
      final t = math.sqrt(((value - param.min) / (max - param.min)).clamp(0.0, 1.0));
      return LabeledSlider(
        label: param.label,
        value: t,
        min: 0,
        max: 1,
        display: param.format(value),
        highlighted: changed,
        onChanged: (t) => c.setBrushParam(param, param.min + (max - param.min) * t * t),
      );
    }
    return LabeledSlider(
      label: param.label,
      value: value,
      min: param.min,
      max: param.max,
      display: param.format(value),
      highlighted: changed,
      onChanged: (v) => c.setBrushParam(param, v),
    );
  }

  static String _describe(BrushPreset brush) {
    final parts = <String>[
      switch (brush.engine) {
        BrushEngine.paint => 'Paints',
        BrushEngine.smudge => 'Smudges the colour under it',
        BrushEngine.blur => 'Blurs what is under it',
      },
      if (brush.strokeBlend == StrokeBlend.multiply) 'glazes like a marker — overlaps darken',
      if (brush.strokeBlend == StrokeBlend.glow) 'adds light',
      if (brush.grain != BrushGrain.none) 'with ${brush.grain.name} grain',
      if (brush.airbrush) 'builds up while you hold still',
    ];
    return '${parts.join(', ')}. Pressure changes '
        '${brush.sizePressure > 0 && brush.flowPressure > 0 ? 'size and opacity' : brush.sizePressure > 0 ? 'size' : brush.flowPressure > 0 ? 'opacity' : 'nothing'}.';
  }
}

class _ImagePainter extends CustomPainter {
  _ImagePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final scale = math.min(size.width / src.width, size.height / src.height);
    final w = src.width * scale;
    final h = src.height * scale;
    final dst = Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_ImagePainter old) => old.image != image;
}
