import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';

import '../../data/roofs.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_schematic_panel.dart';
import '../../ui/mc_style.dart';

/// Designs a roof over a footprint and exports it as a schematic.
class RoofTool extends StatefulWidget {
  const RoofTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<RoofTool> createState() => _RoofToolState();
}

class _RoofToolState extends State<RoofTool> {
  McRoofStyle _style = McRoofStyle.gable;
  int _width = 13;
  int _depth = 9;
  int _overhang = 1;
  McRoofMaterial _material = kMcRoofMaterials.first;
  bool _fillGables = true;
  String _gableBlock = 'spruce_planks';
  bool _ridgeCap = true;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final roof = mcGenerateRoof(
      style: _style,
      width: _width,
      depth: _depth,
      material: _material,
      overhang: _overhang,
      gableFill: _fillGables ? _gableBlock : null,
      ridgeCap: _ridgeCap,
    );
    final voxels = McVoxels();
    for (final e in roof.blocks.entries) {
      final (x, y, z) = e.key;
      voxels.set(x, y, z, e.value);
    }
    final schematic = voxels.build(name: '${_style.name}_roof');
    return widget.host.frame(
      context,
      child: McSplit(
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcShapeStyle,
              icon: Icons.roofing_rounded,
              child: McChoice<McRoofStyle>(
                values: McRoofStyle.values,
                selected: _style,
                label: (s) => s.label(t),
                onSelect: (s) => setState(() => _style = s),
              ),
            ),
            McPanel(
              title: t.mcRoofFootprint,
              icon: Icons.crop_square_rounded,
              child: McFormColumn(
                gap: 4,
                children: [
                  McSlider(
                    label: t.mcRoofWidthX,
                    value: _width.toDouble(),
                    min: 3,
                    max: 63,
                    divisions: 60,
                    onChanged: (v) => setState(() => _width = v.round()),
                  ),
                  McSlider(
                    label: t.mcRoofDepthZ,
                    value: _depth.toDouble(),
                    min: 3,
                    max: 63,
                    divisions: 60,
                    onChanged: (v) => setState(() => _depth = v.round()),
                  ),
                  McSlider(
                    label: t.mcRoofOverhang,
                    value: _overhang.toDouble(),
                    min: 0,
                    max: 3,
                    divisions: 3,
                    onChanged: (v) => setState(() => _overhang = v.round()),
                  ),
                  Text(
                    t.mcRoofSizeNote,
                    style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            McPanel(
              title: t.mcMaterials,
              icon: Icons.texture_rounded,
              child: McFormColumn(
                gap: 8,
                children: [
                  McField(
                    label: t.mcRoofRoof,
                    child: McDropdown<McRoofMaterial>(
                      values: kMcRoofMaterials,
                      value: _material,
                      label: (m) => m.label,
                      onChanged: (m) => setState(() => _material = m),
                    ),
                  ),
                  McSwitch(
                    label: t.mcRoofRidge,
                    detail: t.mcRoofRidgeDetail,
                    value: _ridgeCap,
                    onChanged: (v) => setState(() => _ridgeCap = v),
                  ),
                  if (!_style.hipped) ...[
                    McSwitch(
                      label: t.mcRoofFillGables,
                      value: _fillGables,
                      onChanged: (v) => setState(() => _fillGables = v),
                    ),
                    if (_fillGables)
                      McDropdown<String>(
                        values: const [
                          'spruce_planks', 'oak_planks', 'dark_oak_planks', 'birch_planks',
                          'white_concrete', 'stone_bricks', 'bricks', 'cobblestone',
                          'stripped_spruce_log', 'white_terracotta', 'mud_bricks',
                        ],
                        value: _gableBlock,
                        label: mcPretty,
                        onChanged: (v) => setState(() => _gableBlock = v),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
        result: McSchematicPanel(
          schematic: schematic,
          baseName: '${_style.name}_roof_${_width}x$_depth',
          extraStats: [
            McStat(value: '${roof.stairs}', label: t.mcRoofStairs, hue: McHue.rose),
            McStat(value: '${roof.slabs}', label: t.mcRoofSlabs, hue: McHue.amber),
          ],
        ),
      ),
    );
  }
}
