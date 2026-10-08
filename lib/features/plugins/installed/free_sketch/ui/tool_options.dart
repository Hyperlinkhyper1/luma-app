import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
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
    final t = L.of(context);
    Widget label(String text) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(text, style: TextStyle(color: luma.textMuted, fontSize: 12)),
        );
    Widget gap() => Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 6), color: luma.border);
    Widget icon(IconData i, String tip, VoidCallback? onTap, {bool selected = false}) =>
        StudioIconButton(icon: i, tooltip: tip, onTap: onTap, selected: selected, size: 34);
    Widget text(String s, VoidCallback? onTap) => TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10)),
          child: Text(s, style: const TextStyle(fontSize: 12.5)),
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
            label(c.symmetry.mode.label(t)),
          ],
          if (c.state.selection != null) ...[
            gap(),
            label(t.freeSketchToolPaintInSelection),
            text(t.freeSketchDeselect, c.deselect),
          ],
        ];
      case SketchTool.fill:
        return [
          label(t.freeSketchFillTolerance),
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
          toggle(t.freeSketchAllLayers, t.freeSketchThisLayer, c.fillAllLayers, (v) {
            c.fillAllLayers = v;
            c.touch();
          }),
          gap(),
          label(t.freeSketchFillGrow),
          icon(Icons.remove_rounded, t.freeSketchFillShrinkTip, c.fillGrow > 0 ? () {
            c.fillGrow--;
            c.touch();
          } : null),
          label('${c.fillGrow} px'),
          icon(Icons.add_rounded, t.freeSketchFillGrowTip, c.fillGrow < 6 ? () {
            c.fillGrow++;
            c.touch();
          } : null),
        ];
      case SketchTool.gradient:
        return [
          toggle(t.freeSketchGradientLinear, t.freeSketchGradientRadial, c.gradientKind == GradientKind.linear, (v) {
            c.gradientKind = v ? GradientKind.linear : GradientKind.radial;
            c.touch();
          }),
          gap(),
          toggle(t.freeSketchGradientToTransparent, t.freeSketchGradientToSecondary, !c.gradientToSecondary, (v) {
            c.gradientToSecondary = !v;
            c.touch();
          }),
          label(t.freeSketchGradientDragHint),
        ];
      case SketchTool.shape:
        return [
          for (final kind in ShapeKind.values)
            icon(kind.icon, kind.label, () {
              c.shapeKind = kind;
              c.touch();
            }, selected: c.shapeKind == kind),
          if (c.shapeKind == ShapeKind.polygon) ...[
            icon(Icons.remove_rounded, t.freeSketchPolygonFewerSides, c.polygonSides > 3 ? () {
              c.polygonSides--;
              c.touch();
            } : null),
            label(t.freeSketchPolygonSides(c.polygonSides)),
            icon(Icons.add_rounded, t.freeSketchPolygonMoreSides, c.polygonSides < 12 ? () {
              c.polygonSides++;
              c.touch();
            } : null),
          ],
          gap(),
          toggle(t.freeSketchShapeStroke, t.freeSketchShapeFill, !c.shapeFill, (v) {
            c.shapeFill = !v;
            c.touch();
          }),
          label(t.freeSketchShapeShiftHint),
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
            icon(combine.icon, t.freeSketchSelectionCombineTip(combine.label), () {
              c.selectionCombine = combine;
              c.touch();
            }, selected: c.selectionCombine == combine),
          gap(),
          text(t.freeSketchSelectAll, c.selectAll),
          text(t.freeSketchSelectInvert, c.invertSelection),
          text(t.freeSketchDeselect, c.state.selection == null ? null : c.deselect),
          gap(),
          icon(Icons.content_copy_rounded, t.freeSketchCopyShortcut, c.copy),
          icon(Icons.content_cut_rounded, t.freeSketchCutShortcut, c.cut),
          icon(Icons.content_paste_rounded, t.freeSketchPasteAsNewLayerShortcut, c.hasClipboard ? c.paste : null),
          icon(Icons.delete_outline_rounded, t.freeSketchClearSelectionShortcut, c.state.selection == null ? null : c.clearLayer),
        ];
      case SketchTool.transform:
        final tf = c.transform;
        if (tf == null) return [label(t.freeSketchTransformSelectLayerHint)];
        return [
          icon(Icons.flip_rounded, t.freeSketchTransformFlipH, () {
            tf.flipX = !tf.flipX;
            c.transformChanged();
          }),
          RotatedBox(
            quarterTurns: 1,
            child: icon(Icons.flip_rounded, t.freeSketchTransformFlipV, () {
              tf.flipY = !tf.flipY;
              c.transformChanged();
            }),
          ),
          icon(Icons.rotate_90_degrees_cw_rounded, t.freeSketchTransformRotate90, () {
            tf.rotation += math.pi / 2;
            c.transformChanged();
          }),
          icon(
            Icons.aspect_ratio_rounded,
            c.uniformScale ? t.freeSketchTransformUniformScale : t.freeSketchTransformFreeScale,
            () {
              c.uniformScale = !c.uniformScale;
              c.touch();
            },
            selected: c.uniformScale,
          ),
          text(t.commonReset, () {
            tf.reset();
            c.transformChanged();
          }),
          gap(),
          label('${(tf.scaleX.abs() * 100).round()}% × ${(tf.scaleY.abs() * 100).round()}%'),
          label('${(tf.rotation * 180 / math.pi).round() % 360}°'),
          gap(),
          text(t.commonCancel, c.cancelTransform),
          FilledButton(
            onPressed: c.finishTransform,
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(t.commonApply),
          ),
        ];
      case SketchTool.eyedropper:
        return [
          toggle(t.freeSketchAllLayers, t.freeSketchThisLayer, c.eyedropperAllLayers, (v) {
            c.eyedropperAllLayers = v;
            c.touch();
          }),
          label(t.freeSketchEyedropperTip),
        ];
    }
  }
}
