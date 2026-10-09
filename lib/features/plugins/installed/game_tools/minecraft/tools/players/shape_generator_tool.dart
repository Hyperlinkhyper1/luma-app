import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../../../../../converter/schematic/block_colors.dart';
import '../../../../../../converter/schematic/schematic_model.dart';
import '../../data/mc_registries_data.dart';
import '../../data/shapes.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_block_grid.dart';
import '../../ui/mc_schematic_panel.dart';
import '../../ui/mc_style.dart';

enum _Mode {
  circle(Icons.circle_outlined),
  arch(Icons.architecture_rounded),
  solid(Icons.view_in_ar_rounded);

  const _Mode(this.icon);
  final IconData icon;

  String label(L t) => switch (this) {
    circle => t.mcShapeCircle,
    arch => t.mcShapeArch,
    solid => t.mcShape3d,
  };
}

/// Circles, arches and 3D solids, block by block: a plan you can count from,
/// a 3D look and a schematic to paste.
class ShapeGeneratorTool extends StatefulWidget {
  const ShapeGeneratorTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<ShapeGeneratorTool> createState() => _ShapeGeneratorToolState();
}

class _ShapeGeneratorToolState extends State<ShapeGeneratorTool> {
  _Mode _mode = _Mode.circle;

  int _width = 21;
  int _height = 21;
  int _depth = 21;
  bool _lock = true;
  bool _filled = false;
  bool _thick = false;
  int _thickness = 1;

  McArchStyle _arch = McArchStyle.round;
  int _archDepth = 1;

  McSolid _solid = McSolid.sphere;
  bool _hollow = true;
  int _tube = 4;

  String _block = 'stone';
  int _layer = 0;

  late _Built _built = _build();

  void _update(VoidCallback change) {
    setState(() {
      change();
      _built = _build();
      _layer = _layer.clamp(0, _built.layers - 1);
    });
  }

  _Built _build() {
    final state = BlockState('minecraft:${_block.isEmpty ? 'stone' : _block}');
    final voxels = McVoxels();
    switch (_mode) {
      case _Mode.circle:
        final cells = mcEllipse(
          _width,
          _lock ? _width : _height,
          filled: _filled,
          thickness: _thickness,
          thick: _thick,
        );
        for (final (x, z) in cells) {
          voxels.set(x, 0, z, state);
        }
        return _Built(
          voxels.build(name: 'circle'),
          plan: cells,
          planW: _width,
          planH: _lock ? _width : _height,
          runs: mcRunLengths(cells, _width, _lock ? _width : _height),
          layers: 1,
        );
      case _Mode.arch:
        final cells = mcArch(_width, _height, _arch, thickness: _thickness);
        for (final (x, y) in cells) {
          for (var z = 0; z < _archDepth; z++) {
            voxels.set(x, y, z, state);
          }
        }
        return _Built(
          voxels.build(name: 'arch'),
          plan: cells,
          planW: _width,
          planH: _height,
          flip: true,
          layers: 1,
        );
      case _Mode.solid:
        final w = _width;
        final h = _lock ? _width : _height;
        final d = _lock ? _width : _depth;
        final cells = mcSolid(
          _solid,
          width: w,
          height: _solid == McSolid.dome && _lock ? (w / 2).ceil() : h,
          depth: d,
          hollow: _hollow,
          thickness: _thickness,
          tube: _tube,
        );
        var top = 0;
        for (final (x, y, z) in cells) {
          voxels.set(x, y, z, state);
          if (y > top) top = y;
        }
        return _Built(
          voxels.build(name: _solid.name),
          solid: cells,
          planW: w,
          planH: d,
          layers: top + 1,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final built = _built;
    final color = BlockColors.of(BlockState('minecraft:$_block'));
    return widget.host.frame(
      context,
      child: McSplit(
        controls: McFormColumn(
          children: [
            McPanel(
              child: McChoice<_Mode>(
                values: _Mode.values,
                selected: _mode,
                label: (m) => m.label(t),
                icon: (m) => m.icon,
                onSelect: (m) => _update(() {
                  _mode = m;
                  if (m == _Mode.arch) {
                    _lock = false;
                    _height = (_width / 2).ceil() + 1;
                  }
                }),
              ),
            ),
            McPanel(
              title: t.mcShapeSize,
              icon: Icons.straighten_rounded,
              child: McFormColumn(
                gap: 4,
                children: [
                  if (_mode == _Mode.solid)
                    McChoice<McSolid>(
                      values: McSolid.values,
                      selected: _solid,
                      label: (s) => s.label(t),
                      onSelect: (s) => _update(() => _solid = s),
                    ),
                  if (_mode == _Mode.arch)
                    McChoice<McArchStyle>(
                      values: McArchStyle.values,
                      selected: _arch,
                      label: (s) => s.label(t),
                      onSelect: (s) => _update(() => _arch = s),
                    ),
                  const SizedBox(height: 6),
                  McSlider(
                    label: _mode == _Mode.arch ? t.mcShapeSpan : t.mcShapeWidth,
                    value: _width.toDouble(),
                    min: 3,
                    max: _mode == _Mode.solid ? 96 : 160,
                    divisions: (_mode == _Mode.solid ? 96 : 160) - 3,
                    onChanged: (v) => _update(() => _width = v.round()),
                  ),
                  if (_mode != _Mode.arch)
                    McSwitch(
                      label: _mode == _Mode.circle
                          ? t.mcShapePerfectCircle
                          : t.mcShapeSameSize,
                      value: _lock,
                      onChanged: (v) => _update(() => _lock = v),
                    ),
                  if (!_lock || _mode == _Mode.arch)
                    McSlider(
                      label: _mode == _Mode.arch
                          ? t.mcShapeRise
                          : _mode == _Mode.circle
                          ? t.mcShapeLength
                          : t.mcShapeHeight,
                      value: _height.toDouble(),
                      min: 2,
                      max: _mode == _Mode.solid ? 96 : 160,
                      divisions: (_mode == _Mode.solid ? 96 : 160) - 2,
                      onChanged: (v) => _update(() => _height = v.round()),
                    ),
                  if (_mode == _Mode.solid && !_lock)
                    McSlider(
                      label: t.mcShapeDepth,
                      value: _depth.toDouble(),
                      min: 3,
                      max: 96,
                      divisions: 93,
                      onChanged: (v) => _update(() => _depth = v.round()),
                    ),
                  if (_mode == _Mode.solid && _solid == McSolid.torus)
                    McSlider(
                      label: t.mcShapeTube,
                      value: _tube.toDouble(),
                      min: 1,
                      max: (_width / 4).floorToDouble().clamp(1, 24),
                      onChanged: (v) => _update(() => _tube = v.round()),
                    ),
                  if (_mode == _Mode.arch)
                    McSlider(
                      label: t.mcShapeArchDepth,
                      value: _archDepth.toDouble(),
                      min: 1,
                      max: 16,
                      divisions: 15,
                      onChanged: (v) => _update(() => _archDepth = v.round()),
                    ),
                ],
              ),
            ),
            McPanel(
              title: t.mcShapeStyle,
              icon: Icons.brush_rounded,
              child: McFormColumn(
                gap: 4,
                children: [
                  if (_mode == _Mode.circle)
                    McSwitch(
                      label: t.mcShapeFilled,
                      value: _filled,
                      onChanged: (v) => _update(() => _filled = v),
                    ),
                  if (_mode == _Mode.solid)
                    McSwitch(
                      label: t.mcShapeHollow,
                      detail: t.mcShapeHollowDetail,
                      value: _hollow,
                      onChanged: (v) => _update(() => _hollow = v),
                    ),
                  if ((_mode == _Mode.circle && !_filled) ||
                      (_mode == _Mode.solid && _hollow) ||
                      _mode == _Mode.arch)
                    McSlider(
                      label: t.mcShapeWall,
                      value: _thickness.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged: (v) => _update(() => _thickness = v.round()),
                    ),
                  if (_mode == _Mode.circle && !_filled && _thickness == 1)
                    McSwitch(
                      label: t.mcShapeThick,
                      detail: t.mcShapeThickDetail,
                      value: _thick,
                      onChanged: (v) => _update(() => _thick = v),
                    ),
                  const SizedBox(height: 8),
                  McField(
                    label: t.mcShapeBlock,
                    child: McIdField(
                      options: kMcBlocks,
                      value: _block,
                      hint: 'stone',
                      onChanged: (v) => _update(
                        () => _block = v.replaceFirst('minecraft:', ''),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        result: McFormColumn(
          children: [
            McPanel(
              title: _mode == _Mode.solid
                  ? t.mcShapeLayerOf(_layer + 1, built.layers)
                  : t.mcShapePlan,
              icon: Icons.grid_on_rounded,
              trailing: built.runs.isEmpty
                  ? null
                  : Text(
                      built.runs.join('-'),
                      style: mcMono(context, size: 12, color: luma.textMuted),
                    ),
              child: McFormColumn(
                gap: 10,
                children: [
                  if (_mode == _Mode.solid && built.layers > 1)
                    McSlider(
                      label: t.mcShapeLayer,
                      value: _layer.toDouble(),
                      min: 0,
                      max: (built.layers - 1).toDouble(),
                      divisions: built.layers - 1,
                      format: (v) => 'y = ${v.round()}',
                      onChanged: (v) => setState(() => _layer = v.round()),
                    ),
                  SizedBox(
                    height: 360,
                    child: _mode == _Mode.solid
                        ? McBlockGrid(
                            width: built.planW,
                            height: built.planH,
                            colorAt: (x, z) =>
                                built.solid.contains((x, _layer, z)) ? color : null,
                            ghostAt: (x, z) => _layer > 0 &&
                                    built.solid.contains((x, _layer - 1, z))
                                ? luma.textMuted.withValues(alpha: 0.35)
                                : null,
                          )
                        : McBlockGrid(
                            width: built.planW,
                            height: built.planH,
                            flipY: built.flip,
                            colorAt: (x, y) =>
                                built.plan.contains((x, y)) ? color : null,
                          ),
                  ),
                  if (_mode == _Mode.solid)
                    Text(
                      t.mcShapeGhost,
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  if (built.runs.isNotEmpty)
                    Text(
                      t.mcShapeRuns(built.runs.join(', ')),
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                ],
              ),
            ),
            McSchematicPanel(
              schematic: built.schematic,
              baseName: '${_mode == _Mode.solid ? _solid.name : _mode.name}_$_width',
            ),
          ],
        ),
      ),
    );
  }
}

class _Built {
  _Built(
    this.schematic, {
    this.plan = const {},
    this.solid = const {},
    required this.planW,
    required this.planH,
    this.flip = false,
    this.runs = const [],
    required this.layers,
  });

  final Schematic schematic;
  final Set<(int, int)> plan;
  final Set<(int, int, int)> solid;
  final int planW;
  final int planH;
  final bool flip;
  final List<int> runs;
  final int layers;
}
