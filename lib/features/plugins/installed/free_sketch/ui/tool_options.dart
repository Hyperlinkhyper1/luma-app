import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../model/sketch_tool.dart';
import 'studio_controller.dart';
import 'studio_widgets.dart';

/// The strip along the top of the canvas with the active tool's options.
class ToolOptionsBar extends StatelessWidget {
  const ToolOptionsBar({super.key, required this.controller, required this.onOpenBrushes});

  final StudioController controller;
  final VoidCallback onOpenBrushes;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final children = _options(context);
        if (children.isEmpty) return const SizedBox.shrink();
        return Material(
          color: luma.surface.withValues(alpha: 0.96),
          shape: StadiumBorder(side: BorderSide(color: luma.border)),
          elevation: 3,
          shadowColor: const Color(0x44000000),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        );
      },
    );
  }

  List<Widget> _options(BuildContext context) {
    final c = controller;
    final luma = context.luma;
    Widget label(String text) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(text, style: TextStyle(color: luma.textMuted, fontSize: 12)),
        );
    Widget gap() => Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 6), color: luma.border);
    Widget icon(IconData i, String tip, VoidCallback? onTap, {bool selected = false}) =>
        StudioIconButton(icon: i, tooltip: tip, onTap: onTap, selected: selected, size: 34);
    Widget text(String t, VoidCallback? onTap) => TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10)),
          child: Text(t, style: const TextStyle(fontSize: 12.5)),
        );
    Widget toggle(String a, String b, bool first, ValueChanged<bool> onChanged) => SegmentedButton<bool>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(value: true, label: Text(a, style: const TextStyle(fontSize: 12))),
            ButtonSegment(value: false, label: Text(b, style: const TextStyle(fontSize: 12))),
          ],
          selected: {first},
          onSelectionChanged: (s) => onChanged(s.first),
        );

    switch (c.tool) {
      case SketchTool.brush:
      case SketchTool.eraser:
      case SketchTool.smudge:
        final brush = c.brush;
        return [
          Icon(c.tool.icon, size: 16, color: luma.accent),
          text(brush.name, onOpenBrushes),
          label('${brush.size < 10 ? brush.size.toStringAsFixed(1) : brush.size.round()} px'),
          label('${(brush.opacity * 100).round()}%'),
          if (c.symmetry.enabled) ...[
            gap(),
            Icon(Icons.flip_rounded, size: 16, color: luma.accent),
            label(c.symmetry.mode.label),
          ],
          if (c.state.selection != null) ...[
            gap(),
            label('Painting inside selection'),
            text('Deselect', c.deselect),
          ],
        ];
      case SketchTool.fill:
        return [
          label('Tolerance'),
          SizedBox(
            width: 130,
            child: Slider(
              value: c.fillTolerance,
              onChanged: (v) {
                c.fillTolerance = v;
                c.touch();
              },
            ),
          ),
          label('${(c.fillTolerance * 100).round()}%'),
          gap(),
          toggle('All layers', 'This layer', c.fillAllLayers, (v) {
            c.fillAllLayers = v;
            c.touch();
          }),
          gap(),
          label('Grow'),
          icon(Icons.remove_rounded, 'Shrink fill edge', c.fillGrow > 0 ? () {
            c.fillGrow--;
            c.touch();
          } : null),
          label('${c.fillGrow} px'),
          icon(Icons.add_rounded, 'Grow fill edge under line art', c.fillGrow < 6 ? () {
            c.fillGrow++;
            c.touch();
          } : null),
        ];
      case SketchTool.gradient:
        return [
          toggle('Linear', 'Radial', c.gradientKind == GradientKind.linear, (v) {
            c.gradientKind = v ? GradientKind.linear : GradientKind.radial;
            c.touch();
          }),
          gap(),
          toggle('To transparent', 'To secondary', !c.gradientToSecondary, (v) {
            c.gradientToSecondary = !v;
            c.touch();
          }),
          label('Drag across the canvas'),
        ];
      case SketchTool.shape:
        return [
          for (final kind in ShapeKind.values)
            icon(kind.icon, kind.label, () {
              c.shapeKind = kind;
              c.touch();
            }, selected: c.shapeKind == kind),
          if (c.shapeKind == ShapeKind.polygon) ...[
            icon(Icons.remove_rounded, 'Fewer sides', c.polygonSides > 3 ? () {
              c.polygonSides--;
              c.touch();
            } : null),
            label('${c.polygonSides} sides'),
            icon(Icons.add_rounded, 'More sides', c.polygonSides < 12 ? () {
              c.polygonSides++;
              c.touch();
            } : null),
          ],
          gap(),
          toggle('Stroke', 'Fill', !c.shapeFill, (v) {
            c.shapeFill = !v;
            c.touch();
          }),
          label('Shift keeps it straight/square'),
        ];
      case SketchTool.select:
        return [
          for (final shape in SelectionShape.values)
            icon(shape.icon, shape.label, () {
              c.selectionShape = shape;
              c.touch();
            }, selected: c.selectionShape == shape),
          gap(),
          for (final combine in SelectionCombine.values)
            icon(combine.icon, '${combine.label} selection', () {
              c.selectionCombine = combine;
              c.touch();
            }, selected: c.selectionCombine == combine),
          gap(),
          text('All', c.selectAll),
          text('Invert', c.invertSelection),
          text('Deselect', c.state.selection == null ? null : c.deselect),
          gap(),
          icon(Icons.content_copy_rounded, 'Copy (Ctrl+C)', c.copy),
          icon(Icons.content_cut_rounded, 'Cut (Ctrl+X)', c.cut),
          icon(Icons.content_paste_rounded, 'Paste as new layer (Ctrl+V)', c.hasClipboard ? c.paste : null),
          icon(Icons.delete_outline_rounded, 'Clear selection (Delete)', c.state.selection == null ? null : c.clearLayer),
        ];
      case SketchTool.transform:
        final t = c.transform;
        if (t == null) return [label('Select a layer with something on it')];
        return [
          icon(Icons.flip_rounded, 'Flip horizontally', () {
            t.flipX = !t.flipX;
            c.transformChanged();
          }),
          RotatedBox(
            quarterTurns: 1,
            child: icon(Icons.flip_rounded, 'Flip vertically', () {
              t.flipY = !t.flipY;
              c.transformChanged();
            }),
          ),
          icon(Icons.rotate_90_degrees_cw_rounded, 'Rotate 90°', () {
            t.rotation += math.pi / 2;
            c.transformChanged();
          }),
          icon(Icons.aspect_ratio_rounded, c.uniformScale ? 'Uniform scale (Shift for free)' : 'Free scale (Shift for uniform)', () {
            c.uniformScale = !c.uniformScale;
            c.touch();
          }, selected: c.uniformScale),
          text('Reset', () {
            t.reset();
            c.transformChanged();
          }),
          gap(),
          label('${(t.scaleX.abs() * 100).round()}% × ${(t.scaleY.abs() * 100).round()}%'),
          label('${(t.rotation * 180 / math.pi).round() % 360}°'),
          gap(),
          text('Cancel', c.cancelTransform),
          FilledButton(
            onPressed: c.finishTransform,
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Apply'),
          ),
        ];
      case SketchTool.eyedropper:
        return [
          toggle('All layers', 'This layer', c.eyedropperAllLayers, (v) {
            c.eyedropperAllLayers = v;
            c.touch();
          }),
          label('Tip: hold Alt with any tool to pick a colour'),
        ];
    }
  }
}
