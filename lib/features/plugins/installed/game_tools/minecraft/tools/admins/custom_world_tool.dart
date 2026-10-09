import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/mc_registries_data.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_files.dart';
import '../../ui/mc_style.dart';

enum _Terrain {
  normal('overworld', {}),
  amplified('overworld_amplified', {
    'chunk_surface_level', 'depth', 'final_density', 'preliminary_surface_level',
  }),
  largeBiomes('overworld_large_biomes', {
    'chunk_surface_level', 'continents', 'depth', 'erosion', 'final_density',
    'preliminary_surface_level', 'temperature', 'vegetation',
  });

  const _Terrain(this.prefix, this.own);
  final String prefix;

  String label(L t) => switch (this) {
    normal => t.mcWorldNormalTerrain,
    amplified => t.mcWorldAmplified,
    largeBiomes => t.mcWorldLargeBiomes,
  };

  /// The density functions this variant has its own copy of; everything
  /// else comes from the plain overworld.
  final Set<String> own;

  String fn(String name) =>
      own.contains(name) ? 'minecraft:$prefix/$name' : 'minecraft:overworld/$name';
}

enum _Biomes {
  normal,
  single,
  checkerboard;

  String label(L t) => switch (this) {
    normal => t.mcWorldEveryBiome,
    single => t.mcWorldOneBiome,
    checkerboard => t.mcWorldCheckerboard,
  };
}

enum _Height {
  standard(-64, 384),
  tall(-64, 512),
  deep(-128, 448),
  short(0, 256);

  const _Height(this.minY, this.height);

  String label(L t) => switch (this) {
    standard => t.mcWorldHeightStandard,
    tall => t.mcWorldHeightTall,
    deep => t.mcWorldHeightDeep,
    short => t.mcWorldHeightShort,
  };
  final int minY;
  final int height;
}

/// A customised overworld as a datapack: sea level, the stone and fluid the
/// terrain is made of, world height, terrain shape and biome layout, all
/// packed as a world preset for the Create World screen or a server.
class CustomWorldTool extends StatefulWidget {
  const CustomWorldTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<CustomWorldTool> createState() => _CustomWorldToolState();
}

class _CustomWorldToolState extends State<CustomWorldTool> {
  String _name = 'my_world';
  int _seaLevel = 63;
  String _block = 'stone';
  String _fluid = 'water';
  _Terrain _terrain = _Terrain.normal;
  _Height _height = _Height.standard;
  _Biomes _biomes = _Biomes.normal;
  String _biome = 'plains';
  final List<String> _checker = ['plains', 'desert', 'snowy_plains', 'jungle'];
  int _checkerScale = 3;
  bool _mobs = true;

  String get _slug => mcSlug(_name, fallback: 'custom_world');
  bool get _customDimension => _height != _Height.standard;

  Map<String, Object> get _noiseSettings {
    final t = _terrain;
    Map<String, Object> range(String key, double lo, double hi) => {key: [lo, hi]};
    Map<String, Object> spawn(double ridgesLo, double ridgesHi) => {
      ...range(t.fn('continents'), -0.11, 1.0),
      ...range(t.fn('erosion'), -1.0, 1.0),
      ...range(t.fn('ridges'), ridgesLo, ridgesHi),
      ...range(t.fn('temperature'), -1.0, 1.0),
      ...range(t.fn('vegetation'), -1.0, 1.0),
    };
    return {
      'aquifers': {
        'barrier': {'type': 'minecraft:noise', 'noise': 'minecraft:aquifer_barrier', 'xz_scale': 1.0, 'y_scale': 0.5},
        'exclusion': {
          'type': 'minecraft:min',
          'left': {'type': 'minecraft:sub', 'left': -0.225, 'right': t.fn('erosion')},
          'right': {
            'type': 'minecraft:max',
            'left': {'type': 'minecraft:sub', 'left': t.fn('depth'), 'right': 0.9},
            'right': 0.0,
          },
        },
        'fluid_level_floodedness': {
          'type': 'minecraft:noise',
          'noise': 'minecraft:aquifer_fluid_level_floodedness',
          'xz_scale': 1.0,
          'y_scale': 0.67,
        },
        'fluid_level_spread': {
          'type': 'minecraft:noise',
          'noise': 'minecraft:aquifer_fluid_level_spread',
          'xz_scale': 1.0,
          'y_scale': 0.7142857142857143,
        },
        'lava': {'type': 'minecraft:noise', 'noise': 'minecraft:aquifer_lava', 'xz_scale': 1.0, 'y_scale': 1.0},
        'surface_level': t.fn('preliminary_surface_level'),
      },
      'default_block': 'minecraft:$_block',
      'default_fluid': 'minecraft:$_fluid',
      'disable_mob_generation': !_mobs,
      'legacy_random_source': false,
      'material_rule': 'minecraft:overworld',
      'noise': {'height': _height.height, 'min_y': _height.minY},
      'noise_router': {
        'chunk_surface_level': t.fn('chunk_surface_level'),
        'continents': t.fn('continents'),
        'depth': t.fn('depth'),
        'erosion': t.fn('erosion'),
        'final_density': t.fn('final_density'),
        'ridges': t.fn('ridges'),
        'temperature': t.fn('temperature'),
        'vegetation': t.fn('vegetation'),
      },
      'sea_level': _seaLevel,
      'spawn_target': [spawn(-1.0, -0.16), spawn(0.16, 1.0)],
    };
  }

  Map<String, Object> get _biomeSource => switch (_biomes) {
    _Biomes.normal => {'type': 'minecraft:multi_noise', 'preset': 'minecraft:overworld'},
    _Biomes.single => {'type': 'minecraft:fixed', 'biome': 'minecraft:$_biome'},
    _Biomes.checkerboard => {
      'type': 'minecraft:checkerboard',
      'biomes': [for (final b in _checker) 'minecraft:$b'],
      'scale': _checkerScale,
    },
  };

  Map<String, Object> get _worldPreset => {
    'dimensions': {
      'minecraft:overworld': {
        'type': _customDimension ? 'luma:$_slug' : 'minecraft:overworld',
        'generator': {
          'type': 'minecraft:noise',
          'biome_source': _biomeSource,
          'settings': 'luma:$_slug',
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
      'minecraft:the_nether': {
        'type': 'minecraft:the_nether',
        'generator': {
          'type': 'minecraft:noise',
          'biome_source': {'type': 'minecraft:multi_noise', 'preset': 'minecraft:nether'},
          'settings': 'minecraft:nether',
        },
      },
    },
  };

  /// The overworld's dimension type with a different build height.
  Map<String, Object> get _dimensionType => {
    'ambient_light': 0.0,
    'coordinate_scale': 1.0,
    'default_clock': 'minecraft:overworld',
    'has_ceiling': false,
    'has_ender_dragon_fight': false,
    'has_skylight': true,
    'height': _height.height,
    'infiniburn': '#minecraft:infiniburn_overworld',
    'logical_height': _height.height,
    'min_y': _height.minY,
    'monster_spawn_block_light_limit': 0,
    'monster_spawn_light_level': {'type': 'minecraft:uniform', 'max_inclusive': 7, 'min_inclusive': 0},
    'timelines': '#minecraft:in_overworld',
  };

  static const _pretty = JsonEncoder.withIndent('  ');

  Map<String, String> get _files => {
    'data/luma/worldgen/world_preset/$_slug.json': _pretty.convert(_worldPreset),
    'data/luma/worldgen/noise_settings/$_slug.json': _pretty.convert(_noiseSettings),
    if (_customDimension) 'data/luma/dimension_type/$_slug.json': _pretty.convert(_dimensionType),
    'data/minecraft/tags/worldgen/world_preset/normal.json': _pretty.convert({'values': ['luma:$_slug']}),
  };

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final files = _files;
    return widget.host.frame(
      context,
      actions: [
        McButton(
          label: t.mcSaveDatapackShort,
          icon: Icons.save_alt_rounded,
          onTap: () => mcSaveBytes(
            context,
            mcDatapackZip(t.mcWorldDatapackDesc(_slug), files),
            fileName: '$_slug.zip',
            mimeType: 'application/zip',
          ),
        ),
      ],
      child: McSplit(
        controlsWidth: 400,
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcWorldPreset,
              icon: Icons.badge_rounded,
              child: McTextField(
                initialValue: _name,
                monospace: true,
                hint: 'my_world',
                onChanged: (v) => setState(() => _name = v),
              ),
            ),
            McPanel(
              title: t.mcWorldTerrain,
              icon: Icons.terrain_rounded,
              child: McFormColumn(
                gap: 8,
                children: [
                  McChoice<_Terrain>(
                    values: _Terrain.values,
                    selected: _terrain,
                    label: (terrain) => terrain.label(t),
                    onSelect: (terrain) => setState(() => _terrain = terrain),
                  ),
                  McSlider(
                    label: t.mcWorldSeaLevel,
                    value: _seaLevel.toDouble(),
                    min: (_height.minY).toDouble(),
                    max: (_height.minY + _height.height - 1).toDouble(),
                    divisions: _height.height - 1,
                    format: (v) => 'Y ${v.round()}',
                    onChanged: (v) => setState(() => _seaLevel = v.round()),
                  ),
                  McField(
                    label: t.mcWorldBuildHeight,
                    child: McDropdown<_Height>(
                      values: _Height.values,
                      value: _height,
                      label: (h) => h.label(t),
                      onChanged: (h) => setState(() {
                        _height = h;
                        _seaLevel = _seaLevel.clamp(h.minY, h.minY + h.height - 1);
                      }),
                    ),
                  ),
                  McField(
                    label: t.mcWorldTerrainBlock,
                    child: McIdField(
                      options: kMcBlocks,
                      value: _block,
                      onChanged: (v) => setState(() => _block = v.replaceFirst('minecraft:', '')),
                    ),
                  ),
                  McField(
                    label: t.mcWorldFluid,
                    child: McChoice<String>(
                      values: const ['water', 'lava', 'air'],
                      selected: _fluid,
                      label: mcPretty,
                      onSelect: (v) => setState(() => _fluid = v),
                    ),
                  ),
                  McSwitch(
                    label: t.mcWorldAnimals,
                    value: _mobs,
                    onChanged: (v) => setState(() => _mobs = v),
                  ),
                ],
              ),
            ),
            McPanel(
              title: t.mcWorldBiomes,
              icon: Icons.forest_rounded,
              child: McFormColumn(
                gap: 8,
                children: [
                  McChoice<_Biomes>(
                    values: _Biomes.values,
                    selected: _biomes,
                    label: (b) => b.label(t),
                    onSelect: (b) => setState(() => _biomes = b),
                  ),
                  if (_biomes == _Biomes.single)
                    McDropdown<String>(
                      values: kMcBiomes,
                      value: _biome,
                      label: mcPretty,
                      onChanged: (v) => setState(() => _biome = v),
                    ),
                  if (_biomes == _Biomes.checkerboard) ...[
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final b in kMcBiomes)
                          FilterChip(
                            label: Text(mcPretty(b)),
                            selected: _checker.contains(b),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _checker.add(b);
                              } else if (_checker.length > 1) {
                                _checker.remove(b);
                              }
                            }),
                          ),
                      ],
                    ),
                    McSlider(
                      label: t.mcWorldSquare,
                      value: _checkerScale.toDouble(),
                      min: 0,
                      max: 62,
                      divisions: 62,
                      format: (v) => t.mcWorldSquareBlocks(1 << (v.round() + 2).clamp(0, 30)),
                      onChanged: (v) => setState(() => _checkerScale = v.round()),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        result: McFormColumn(
          children: [
            McPanel(
              title: t.mcWorldUsing,
              icon: Icons.info_outline_rounded,
              child: Text(
                t.mcWorldUsingBody(_slug, kMcDataVersion),
                style: TextStyle(color: luma.textSecondary, fontSize: 12.5, height: 1.45),
              ),
            ),
            for (final e in files.entries)
              McCodeBox(code: e.value, title: e.key, maxHeight: 260),
          ],
        ),
      ),
    );
  }
}
