import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../theme/luma_theme.dart';
import '../../../../../converter/file_saver.dart';
import '../../../../../converter/schematic/block_colors.dart';
import '../../../../../converter/schematic/schematic_model.dart';
import '../../../../../converter/schematic/schematic_service.dart';
import '../../../../../converter/tools/schematic_viewer.dart';
import 'mc_style.dart';

/// A sparse block volume the generators write into before it becomes a
/// [Schematic]. Coordinates may go negative; [build] shifts everything so the
/// smallest corner lands on 0,0,0.
class McVoxels {
  final Map<(int, int, int), BlockState> _blocks = {};

  void set(int x, int y, int z, BlockState state) {
    if (state.isAir) {
      _blocks.remove((x, y, z));
    } else {
      _blocks[(x, y, z)] = state;
    }
  }

  BlockState? at(int x, int y, int z) => _blocks[(x, y, z)];

  bool has(int x, int y, int z) => _blocks.containsKey((x, y, z));

  int get count => _blocks.length;

  bool get isEmpty => _blocks.isEmpty;

  Iterable<MapEntry<(int, int, int), BlockState>> get entries =>
      _blocks.entries;

  Schematic build({String? name}) {
    if (_blocks.isEmpty) {
      return Schematic(
        width: 1,
        height: 1,
        length: 1,
        palette: [BlockState.air],
        blocks: Uint16List(1),
        name: name,
      );
    }
    var minX = 1 << 30, minY = 1 << 30, minZ = 1 << 30;
    var maxX = -(1 << 30), maxY = -(1 << 30), maxZ = -(1 << 30);
    for (final (x, y, z) in _blocks.keys) {
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (z < minZ) minZ = z;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      if (z > maxZ) maxZ = z;
    }
    final w = maxX - minX + 1, h = maxY - minY + 1, l = maxZ - minZ + 1;
    guardVolume(w, h, l);
    final palette = PaletteBuilder();
    final data = Uint16List(w * h * l);
    for (final e in _blocks.entries) {
      final (x, y, z) = e.key;
      final index = (x - minX) + (z - minZ) * w + (y - minY) * w * l;
      data[index] = palette.add(e.value);
    }
    return Schematic(
      width: w,
      height: h,
      length: l,
      palette: palette.build(),
      blocks: data,
      name: name,
      author: 'luma',
      dataVersion: 5023,
    );
  }
}

/// Saves [schematic] as [format] through the platform save dialog.
Future<void> mcSaveSchematic(
  BuildContext context,
  Schematic schematic,
  SchematicFormat format,
  String baseName,
) async {
  try {
    final export = SchematicService.save(schematic, format);
    final result = await saveConvertedFile(
      bytes: export.bytes,
      suggestedName: '$baseName.${format.extension}',
      mimeType: 'application/octet-stream',
      extensions: [format.extension],
    );
    if (!context.mounted || !result.saved) return;
    mcToast(context, result.summary);
  } on Object catch (e) {
    if (context.mounted) mcToast(context, L.of(context).mcCouldNotSave('$e'));
  }
}

/// The 3D viewer, the export buttons and the material list for a generated
/// build — the right-hand side of every generator that makes blocks.
class McSchematicPanel extends StatefulWidget {
  const McSchematicPanel({
    super.key,
    required this.schematic,
    required this.baseName,
    this.extraStats = const [],
  });

  final Schematic schematic;
  final String baseName;
  final List<McStat> extraStats;

  @override
  State<McSchematicPanel> createState() => _McSchematicPanelState();
}

class _McSchematicPanelState extends State<McSchematicPanel> {
  SchematicFormat _format = SchematicFormat.litematic;
  bool _showAllMaterials = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final s = widget.schematic;
    final materials = s.materials();
    final shown = _showAllMaterials ? materials : materials.take(8).toList();
    return McFormColumn(
      children: [
        McStatRow(
          stats: [
            McStat(value: '${s.blockCount}', label: t.mcStatBlocks, hue: McHue.violet),
            McStat(
              value: '${s.width}×${s.length}',
              label: t.mcStatFootprint,
              hue: McHue.indigo,
            ),
            McStat(value: '${s.height}', label: t.mcStatTall, hue: McHue.mint),
            ...widget.extraStats,
          ],
        ),
        SchematicViewer(key: ObjectKey(s), schematic: s),
        McPanel(
          title: t.mcExport,
          icon: Icons.download_rounded,
          child: McFormColumn(
            gap: 10,
            children: [
              McChoice<SchematicFormat>(
                values: const [
                  SchematicFormat.litematic,
                  SchematicFormat.sponge,
                  SchematicFormat.axiom,
                  SchematicFormat.structure,
                  SchematicFormat.mcstructure,
                ],
                selected: _format,
                label: (f) => '.${f.extension}',
                onSelect: (f) => setState(() => _format = f),
              ),
              Text(
                _format.description,
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: McButton(
                  label: t.mcSaveExtension(_format.extension),
                  icon: Icons.save_alt_rounded,
                  onTap: s.blockCount == 0
                      ? null
                      : () => mcSaveSchematic(
                          context,
                          s,
                          _format,
                          widget.baseName,
                        ),
                ),
              ),
            ],
          ),
        ),
        if (materials.isNotEmpty)
          McPanel(
            title: t.mcMaterials,
            icon: Icons.inventory_2_rounded,
            trailing: IconButton(
              tooltip: t.mcCopyList,
              icon: Icon(Icons.copy_rounded, size: 17, color: luma.textMuted),
              onPressed: () => mcCopy(
                context,
                materials
                    .map((m) => '${m.count}× ${mcPretty(m.state.name)}')
                    .join('\n'),
                what: t.mcMaterialListCopied,
              ),
            ),
            child: Column(
              children: [
                for (final m in shown) McMaterialRow(material: m),
                if (materials.length > 8)
                  TextButton(
                    onPressed: () => setState(
                      () => _showAllMaterials = !_showAllMaterials,
                    ),
                    child: Text(
                      _showAllMaterials
                          ? t.mcShowFewer
                          : t.mcShowAllCount(materials.length),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One material: a colour chip, the block's name and its count in blocks,
/// stacks and shulker boxes.
class McMaterialRow extends StatelessWidget {
  const McMaterialRow({super.key, required this.material});

  final MaterialCount material;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final count = material.count;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: BlockColors.of(material.state),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mcPretty(material.state.name),
              style: TextStyle(color: luma.textPrimary, fontSize: 13),
            ),
          ),
          Text(
            mcStacks(count),
            style: TextStyle(color: luma.textMuted, fontSize: 11.5),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `1 SB + 3 st + 12` — a count in shulker boxes, stacks and leftovers.
String mcStacks(int count, {int stack = 64}) {
  final box = stack * 27;
  final boxes = count ~/ box;
  final stacks = (count % box) ~/ stack;
  final rest = count % stack;
  return [
    if (boxes > 0) '$boxes SB',
    if (stacks > 0) '$stacks st',
    if (rest > 0 || count == 0) '$rest',
  ].join(' + ');
}
