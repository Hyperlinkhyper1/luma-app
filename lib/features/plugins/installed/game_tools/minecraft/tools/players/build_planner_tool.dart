import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../../../../../converter/schematic/block_colors.dart';
import '../../../../../../converter/schematic/schematic_model.dart';
import '../../../../../../converter/schematic/schematic_service.dart';
import '../../../../../../converter/tools/schematic_viewer.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_block_grid.dart';
import '../../ui/mc_files.dart';
import '../../ui/mc_schematic_panel.dart';
import '../../ui/mc_style.dart';

/// Reads a schematic in any of the formats luma knows, off the UI thread.
///
/// A file that fails is read again on this isolate: the readers word their
/// errors through the app's localizations, which only the UI isolate has.
Future<Schematic> mcLoadSchematic(Uint8List bytes, String name) async {
  try {
    return await Isolate.run(() => SchematicService.load(bytes, name));
  } on Object {
    return SchematicService.load(bytes, name);
  }
}

/// Opens a build in 3D, walks it one layer at a time and lists what it
/// takes, with a checklist to tick off while gathering.
class BuildPlannerTool extends StatefulWidget {
  const BuildPlannerTool({super.key, required this.host, this.initial});

  final McToolHost host;
  final Schematic? initial;

  @override
  State<BuildPlannerTool> createState() => _BuildPlannerToolState();
}

class _BuildPlannerToolState extends State<BuildPlannerTool> {
  Schematic? _schematic;
  String _name = '';
  bool _loading = false;
  String? _error;
  int _layer = 0;
  bool _layerOnly = false;
  final Set<String> _gathered = {};

  @override
  void initState() {
    super.initState();
    _schematic = widget.initial;
    _name = widget.initial?.name ?? '';
  }

  Future<void> _open() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: SchematicFormat.allExtensions,
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await mcLoadSchematic(file.bytes!, file.name);
      if (!mounted) return;
      setState(() {
        _schematic = s;
        _name = file.name;
        _layer = 0;
        _gathered.clear();
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  List<MaterialCount> _layerMaterials(Schematic s, int y) {
    final counts = <int, int>{};
    final base = y * s.width * s.length;
    for (var i = 0; i < s.width * s.length; i++) {
      final p = s.blocks[base + i];
      if (s.palette[p].isAir) continue;
      counts[p] = (counts[p] ?? 0) + 1;
    }
    final out = [
      for (final e in counts.entries) MaterialCount(s.palette[e.key], e.value),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final s = _schematic;
    return widget.host.frame(
      context,
      actions: [
        McButton(
          label: s == null ? t.mcPlanOpen : t.mcPlanOpenAnother,
          icon: Icons.folder_open_rounded,
          busy: _loading,
          onTap: _open,
        ),
      ],
      child: s == null
          ? McPanel(
              child: McHint(
                icon: Icons.view_in_ar_rounded,
                title: _error == null ? t.mcPlanOpenTitle : t.mcPlanUnreadable,
                body: _error ?? t.mcPlanFormats,
                action: McButton(
                  label: t.mcPlanOpen,
                  icon: Icons.folder_open_rounded,
                  busy: _loading,
                  onTap: _open,
                ),
              ),
            )
          : _planner(context, s, luma),
    );
  }

  Widget _planner(BuildContext context, Schematic s, LumaPalette luma) {
    final t = L.of(context);
    final layer = _layer.clamp(0, s.height - 1);
    final materials = _layerOnly ? _layerMaterials(s, layer) : s.materials();
    final total = materials.fold(0, (a, m) => a + m.count);
    return McFormColumn(
      children: [
        McStatRow(
          stats: [
            McStat(value: _name, label: t.mcPlanFile, hue: McHue.indigo),
            McStat(value: '${s.width}×${s.height}×${s.length}', label: t.mcPlanSize, hue: McHue.violet),
            McStat(value: '${s.blockCount}', label: t.mcStatBlocks, hue: McHue.mint),
            McStat(value: '${s.materials().length}', label: t.mcPlanBlockTypes, hue: McHue.orange),
          ],
        ),
        if (s.notes.isNotEmpty)
          Text(s.notes.join('\n'), style: TextStyle(color: luma.warning, fontSize: 12)),
        SchematicViewer(key: ObjectKey(s), schematic: s),
        McSplit(
          controlsWidth: 440,
          breakpoint: 900,
          controls: McPanel(
            title: t.mcShapeLayerOf(layer + 1, s.height),
            icon: Icons.layers_rounded,
            child: McFormColumn(
              gap: 8,
              children: [
                McSlider(
                  label: t.mcShapeLayer,
                  value: layer.toDouble(),
                  min: 0,
                  max: (s.height - 1).toDouble().clamp(0, double.infinity),
                  divisions: s.height > 1 ? s.height - 1 : null,
                  format: (v) => 'y + ${v.round()}',
                  onChanged: (v) => setState(() => _layer = v.round()),
                ),
                SizedBox(
                  height: 380,
                  child: McBlockGrid(
                    width: s.width,
                    height: s.length,
                    colorAt: (x, z) {
                      final b = s.blockAt(x, layer, z);
                      return b.isAir ? null : BlockColors.of(b);
                    },
                    ghostAt: (x, z) => layer > 0 && !s.blockAt(x, layer - 1, z).isAir
                        ? luma.textMuted.withValues(alpha: 0.3)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          result: McPanel(
            title: _layerOnly ? t.mcPlanLayerMaterials : t.mcPlanShopping,
            icon: Icons.shopping_basket_rounded,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                McIconButton(
                  icon: Icons.copy_rounded,
                  tooltip: t.mcCopyList,
                  onTap: () => mcCopy(
                    context,
                    materials.map((m) => '${m.count}× ${mcPretty(m.state.name)} (${mcStacks(m.count)})').join('\n'),
                    what: t.mcPlanShoppingCopied,
                  ),
                ),
                McIconButton(
                  icon: Icons.table_view_rounded,
                  tooltip: t.mcPlanCsv,
                  onTap: () => mcSaveText(
                    context,
                    'block,count,stacks\n${materials.map((m) => '${m.state.name},${m.count},${mcStacks(m.count)}').join('\n')}\n',
                    fileName: '${_name.split('.').first}_materials.csv',
                    mimeType: 'text/csv',
                  ),
                ),
              ],
            ),
            child: McFormColumn(
              gap: 6,
              children: [
                McSwitch(
                  label: t.mcPlanLayerOnly,
                  value: _layerOnly,
                  onChanged: (v) => setState(() => _layerOnly = v),
                ),
                Text(
                  t.mcPlanGathered(total, _gathered.length, materials.length),
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
                for (final m in materials)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _gathered.contains(m.state.name),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _gathered.add(m.state.name);
                      } else {
                        _gathered.remove(m.state.name);
                      }
                    }),
                    title: Opacity(
                      opacity: _gathered.contains(m.state.name) ? 0.45 : 1,
                      child: McMaterialRow(material: m),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
