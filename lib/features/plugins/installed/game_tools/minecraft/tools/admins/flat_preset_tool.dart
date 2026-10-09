import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../../../../../converter/schematic/block_colors.dart';
import '../../../../../../converter/schematic/schematic_model.dart';
import '../../data/flat_presets_data.dart';
import '../../data/mc_data_types.dart';
import '../../data/mc_registries_data.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_files.dart';
import '../../ui/mc_style.dart';

const _structureSets = [
  'villages', 'strongholds', 'mineshafts', 'pillager_outposts', 'ancient_cities',
  'trial_chambers', 'trail_ruins', 'desert_pyramids', 'jungle_temples', 'swamp_huts',
  'igloos', 'shipwrecks', 'ocean_monuments', 'ocean_ruins', 'ruined_portals',
  'buried_treasures', 'woodland_mansions', 'abandoned_camp',
];

class _Layer {
  _Layer(this.block, this.height);
  String block;
  int height;
}

/// Superflat worlds: stack layers, pick a biome and structures, and get the
/// preset string, the server.properties lines and a datapack world preset.
class FlatPresetTool extends StatefulWidget {
  const FlatPresetTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<FlatPresetTool> createState() => _FlatPresetToolState();
}

class _FlatPresetToolState extends State<FlatPresetTool> {
  final List<_Layer> _layers = [];
  String _biome = 'plains';
  bool _features = false;
  bool _lakes = false;
  final Set<String> _structures = {'villages'};
  String _presetName = 'my_flat_world';

  @override
  void initState() {
    super.initState();
    _load(kMcFlatPresets.first);
  }

  void _load(McFlatPreset p) {
    setState(() {
      _layers
        ..clear()
        ..addAll([for (final l in p.layers) _Layer(l.block, l.height)]);
      _biome = p.biome;
      _features = p.features;
      _lakes = p.lakes;
      _structures
        ..clear()
        ..addAll(p.structures);
    });
  }

  int get _total => _layers.fold(0, (s, l) => s + l.height);

  String get _presetString {
    final layers = _layers
        .map((l) => '${l.height > 1 ? '${l.height}*' : ''}minecraft:${l.block}')
        .join(',');
    return '$layers;minecraft:$_biome';
  }

  Map<String, Object> get _settings => {
    'biome': 'minecraft:$_biome',
    'features': _features,
    'lakes': _lakes,
    'layers': [
      for (final l in _layers) {'block': 'minecraft:${l.block}', 'height': l.height},
    ],
    'structure_overrides': [for (final s in _structures) 'minecraft:$s'],
  };

  String get _serverProperties {
    final settings = jsonEncode({
      'biome': 'minecraft:$_biome',
      'layers': [
        for (final l in _layers) {'block': 'minecraft:${l.block}', 'height': l.height},
      ],
      'features': _features,
      'lakes': _lakes,
      'structure_overrides': [for (final s in _structures) 'minecraft:$s'],
    });
    return 'level-type=minecraft\\:flat\ngenerator-settings=${settings.replaceAll(':', '\\:')}';
  }

  String get _worldPreset => const JsonEncoder.withIndent('  ').convert({
    'dimensions': {
      'minecraft:overworld': {
        'type': 'minecraft:overworld',
        'generator': {'type': 'minecraft:flat', 'settings': _settings},
      },
      'minecraft:the_nether': {
        'type': 'minecraft:the_nether',
        'generator': {
          'type': 'minecraft:noise',
          'biome_source': {'type': 'minecraft:multi_noise', 'preset': 'minecraft:nether'},
          'settings': 'minecraft:nether',
        },
      },
      'minecraft:the_end': {
        'type': 'minecraft:the_end',
        'generator': {
          'type': 'minecraft:noise',
          'biome_source': {'type': 'minecraft:the_end'},
          'settings': 'minecraft:end',
        },
      },
    },
  });

  void _saveDatapack() {
    final slug = mcSlug(_presetName, fallback: 'flat_world');
    final zip = mcDatapackZip(L.of(context).mcFlatDatapackDesc(slug), {
      'data/luma/worldgen/world_preset/$slug.json': _worldPreset,
      'data/minecraft/tags/worldgen/world_preset/normal.json':
          const JsonEncoder.withIndent('  ').convert({'values': ['luma:$slug']}),
    });
    mcSaveBytes(context, zip, fileName: '$slug.zip', mimeType: 'application/zip');
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return widget.host.frame(
      context,
      child: McSplit(
        controlsWidth: 420,
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcFlatStart,
              icon: Icons.bookmarks_rounded,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in kMcFlatPresets)
                    ActionChip(label: Text(mcPretty(p.id)), onPressed: () => _load(p)),
                ],
              ),
            ),
            McPanel(
              title: t.mcFlatLayers,
              icon: Icons.layers_rounded,
              trailing: Text(t.mcFlatTotal(_total), style: TextStyle(color: luma.textMuted, fontSize: 12)),
              child: Column(
                children: [
                  for (var i = _layers.length - 1; i >= 0; i--)
                    Padding(
                      key: ObjectKey(_layers[i]),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 30,
                            decoration: BoxDecoration(
                              color: BlockColors.of(BlockState('minecraft:${_layers[i].block}')),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: McIdField(
                              options: kMcBlocks,
                              value: _layers[i].block,
                              onChanged: (v) => setState(() => _layers[i].block = v.replaceFirst('minecraft:', '')),
                            ),
                          ),
                          const SizedBox(width: 6),
                          McStepper(
                            value: _layers[i].height,
                            min: 1,
                            max: 384,
                            onChanged: (v) => setState(() => _layers[i].height = v),
                          ),
                          Column(
                            children: [
                              InkWell(
                                onTap: i == _layers.length - 1
                                    ? null
                                    : () => setState(() => _layers.insert(i + 1, _layers.removeAt(i))),
                                child: Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: luma.textMuted),
                              ),
                              InkWell(
                                onTap: i == 0 ? null : () => setState(() => _layers.insert(i - 1, _layers.removeAt(i))),
                                child: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: luma.textMuted),
                              ),
                            ],
                          ),
                          McIconButton(
                            icon: Icons.close_rounded,
                            tooltip: t.mcFlatRemoveLayer,
                            onTap: () => setState(() => _layers.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _layers.add(_Layer('stone', 1))),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(t.mcFlatAddLayer),
                    ),
                  ),
                ],
              ),
            ),
            McPanel(
              title: t.mcFlatWorld,
              icon: Icons.public_rounded,
              child: McFormColumn(
                gap: 8,
                children: [
                  McField(
                    label: t.mcFlatBiome,
                    child: McDropdown<String>(
                      values: kMcBiomes,
                      value: _biome,
                      label: mcPretty,
                      onChanged: (v) => setState(() => _biome = v),
                    ),
                  ),
                  McSwitch(label: t.mcFlatDecorations, value: _features, onChanged: (v) => setState(() => _features = v)),
                  McSwitch(label: t.mcFlatLakes, value: _lakes, onChanged: (v) => setState(() => _lakes = v)),
                  McField(
                    label: t.mcFlatStructures,
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final s in _structureSets)
                          FilterChip(
                            label: Text(mcPretty(s)),
                            selected: _structures.contains(s),
                            onSelected: (v) => setState(() => v ? _structures.add(s) : _structures.remove(s)),
                          ),
                      ],
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
              title: t.mcFlatCrossSection,
              icon: Icons.view_agenda_rounded,
              child: SizedBox(
                height: 220,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _LayersPainter(_layers, luma.textMuted),
                ),
              ),
            ),
            McCodeBox(
              code: _presetString,
              title: t.mcFlatPresetString,
              note: t.mcFlatPresetNote,
            ),
            McCodeBox(
              code: _serverProperties,
              title: 'server.properties',
              note: t.mcFlatServerNote,
            ),
            McField(
              label: t.mcFlatPresetName,
              child: McTextField(
                initialValue: _presetName,
                monospace: true,
                onChanged: (v) => setState(() => _presetName = v),
              ),
            ),
            McCodeBox(
              code: _worldPreset,
              title: 'data/luma/worldgen/world_preset/${mcSlug(_presetName)}.json',
              onSave: _saveDatapack,
              note: t.mcFlatDatapackNote,
            ),
          ],
        ),
      ),
    );
  }
}

class _LayersPainter extends CustomPainter {
  _LayersPainter(this.layers, this.text);

  final List<_Layer> layers;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    final total = layers.fold(0, (s, l) => s + l.height);
    if (total == 0) return;
    final unit = (size.height / total).clamp(1.0, 24.0);
    var y = size.height;
    for (final l in layers) {
      final h = l.height * unit;
      final rect = Rect.fromLTWH(0, y - h, size.width * 0.7, h);
      canvas.drawRect(rect, Paint()..color = BlockColors.of(BlockState('minecraft:${l.block}')));
      canvas.drawLine(rect.topLeft, rect.topRight, Paint()..color = Colors.black.withValues(alpha: 0.2));
      if (h >= 11) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${l.height}× ${mcPretty(l.block)}',
            style: TextStyle(color: text, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: size.width * 0.3 - 8);
        tp.paint(canvas, Offset(size.width * 0.7 + 8, y - h / 2 - tp.height / 2));
      }
      y -= h;
    }
  }

  @override
  bool shouldRepaint(_LayersPainter old) => true;
}
