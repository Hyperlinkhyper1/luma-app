import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/mc_registries_data.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_files.dart';
import '../../ui/mc_style.dart';

/// Which shape of loot table JSON to write. 26.3 renamed `functions` to
/// `modifier` and `conditions` to `condition`, keyed by `type`.
enum _Format {
  v263,
  v261;

  String label(L t) => switch (this) {
    v263 => t.mcVersionAndNewer('26.3'),
    v261 => '26.1 – 26.2',
  };
}

class _Entry {
  _Entry({this.item = 'diamond', this.weight = 1, this.min = 1, this.max = 1});
  String item;
  int weight;
  int min;
  int max;
  bool empty = false;
  bool enchantRandomly = false;
  bool enchantLevels = false;
  int levelMin = 5;
  int levelMax = 30;
  bool looting = false;
  bool smelt = false;
  bool decay = false;
  String name = '';
  double chance = 1;
}

class _Pool {
  _Pool() : entries = [_Entry(item: 'diamond', weight: 1), _Entry(item: 'iron_ingot', weight: 5, min: 1, max: 4)];
  int rollsMin = 1;
  int rollsMax = 3;
  bool playerKill = false;
  final List<_Entry> entries;
}

const _types = ['chest', 'entity', 'block', 'fishing', 'archaeology', 'gift', 'generic'];

/// Builds loot tables: pools, weighted entries, counts and the common
/// modifiers, written for the format the target version reads.
class LootTableTool extends StatefulWidget {
  const LootTableTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<LootTableTool> createState() => _LootTableToolState();
}

class _LootTableToolState extends State<LootTableTool> {
  _Format _format = _Format.v263;
  String _type = 'chest';
  String _path = 'chests/treasure';
  final List<_Pool> _pools = [_Pool()];

  Object _number(int min, int max) =>
      min == max ? min : {'type': 'minecraft:uniform', 'max': max, 'min': min};

  Map<String, Object> _fn(String id, [Map<String, Object> args = const {}]) => _format == _Format.v263
      ? {'type': 'minecraft:$id', ...args}
      : {'function': 'minecraft:$id', ...args};

  Map<String, Object> _cond(String id, [Map<String, Object> args = const {}]) => _format == _Format.v263
      ? {'type': 'minecraft:$id', ...args}
      : {'condition': 'minecraft:$id', ...args};

  void _attach(Map<String, Object> target, List<Map<String, Object>> functions, List<Map<String, Object>> conditions) {
    if (_format == _Format.v263) {
      if (functions.length == 1) target['modifier'] = functions.single;
      if (functions.length > 1) target['modifier'] = functions;
      if (conditions.length == 1) target['condition'] = conditions.single;
      if (conditions.length > 1) {
        target['condition'] = {'type': 'minecraft:all_of', 'terms': conditions};
      }
    } else {
      if (functions.isNotEmpty) target['functions'] = functions;
      if (conditions.isNotEmpty) target['conditions'] = conditions;
    }
  }

  Map<String, Object> _entryJson(_Entry e) {
    if (e.empty) return {'type': 'minecraft:empty', 'weight': e.weight};
    final functions = <Map<String, Object>>[
      if (e.min != 1 || e.max != 1)
        _fn('set_count', {
          'count': e.min == e.max ? e.min : {'type': 'minecraft:uniform', 'max': e.max, 'min': e.min},
        }),
      if (e.enchantRandomly) _fn('enchant_randomly'),
      if (e.enchantLevels)
        _fn('enchant_with_levels', {'levels': _number(e.levelMin, e.levelMax)}),
      if (e.looting)
        _fn('enchanted_count_increase', {
          'count': {'type': 'minecraft:uniform', 'max': 1.0, 'min': 0.0},
          'enchantment': 'minecraft:looting',
        }),
      if (e.smelt) _fn('furnace_smelt'),
      if (e.name.trim().isNotEmpty) _fn('set_name', {'name': e.name.trim()}),
      if (e.decay) _fn('explosion_decay'),
    ];
    final conditions = <Map<String, Object>>[
      if (e.chance < 1) _cond('random_chance', {'chance': double.parse(e.chance.toStringAsFixed(3))}),
    ];
    final out = <String, Object>{
      'type': 'minecraft:item',
      'name': 'minecraft:${e.item.replaceFirst('minecraft:', '')}',
      if (e.weight != 1) 'weight': e.weight,
    };
    _attach(out, functions, conditions);
    return out;
  }

  String get _json {
    final pools = [
      for (final p in _pools)
        () {
          final pool = <String, Object>{
            'entries': [for (final e in p.entries) _entryJson(e)],
            'rolls': _number(p.rollsMin, p.rollsMax),
          };
          _attach(pool, const [], [if (p.playerKill) _cond('killed_by_player')]);
          return pool;
        }(),
    ];
    return const JsonEncoder.withIndent('  ').convert({
      'type': 'minecraft:$_type',
      'pools': pools,
      'random_sequence': 'luma:${mcSlug(_path)}',
    });
  }

  String get _filePath => 'data/luma/loot_table/${mcSlug(_path)}.json';

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final json = _json;
    return widget.host.frame(
      context,
      child: McSplit(
        controlsWidth: 500,
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcLootTable,
              icon: Icons.inventory_2_rounded,
              child: McFormColumn(
                gap: 10,
                children: [
                  McField(
                    label: t.mcLootVersion,
                    child: McChoice<_Format>(
                      values: _Format.values,
                      selected: _format,
                      label: (f) => f.label(t),
                      onSelect: (f) => setState(() => _format = f),
                    ),
                  ),
                  McField(
                    label: t.mcLootUsedFor,
                    child: McChoice<String>(
                      values: _types,
                      selected: _type,
                      label: mcPretty,
                      onSelect: (v) => setState(() => _type = v),
                    ),
                  ),
                  McField(
                    label: t.mcLootPath,
                    child: McTextField(
                      initialValue: _path,
                      monospace: true,
                      onChanged: (v) => setState(() => _path = v),
                    ),
                  ),
                ],
              ),
            ),
            for (var pi = 0; pi < _pools.length; pi++)
              McPanel(
                title: t.mcLootPool(pi + 1),
                icon: Icons.casino_rounded,
                trailing: _pools.length > 1
                    ? McIconButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: t.mcLootRemovePool,
                        onTap: () => setState(() => _pools.removeAt(pi)),
                      )
                    : null,
                child: _PoolEditor(pool: _pools[pi], onChanged: () => setState(() {})),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _pools.add(_Pool())),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(t.mcLootAddPool),
              ),
            ),
          ],
        ),
        result: McFormColumn(
          children: [
            McCodeBox(
              code: json,
              title: _filePath,
              maxHeight: 620,
              onSave: () => mcSaveText(context, json, fileName: '${mcSlug(_path).split('/').last}.json'),
            ),
            McButton(
              label: t.mcSaveDatapack,
              icon: Icons.folder_zip_rounded,
              primary: false,
              onTap: () => mcSaveBytes(
                context,
                mcDatapackZip(t.mcLootDatapackDesc, {_filePath: json}),
                fileName: 'luma_loot_${mcSlug(_path).replaceAll('/', '_')}.zip',
                mimeType: 'application/zip',
              ),
            ),
            Text(
              t.mcLootUse(
                '/loot give @s loot luma:${mcSlug(_path)}',
                '/setblock ~ ~ ~ chest{LootTable:"luma:${mcSlug(_path)}"}',
              ),
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoolEditor extends StatelessWidget {
  const _PoolEditor({required this.pool, required this.onChanged});

  final _Pool pool;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final total = pool.entries.fold(0, (s, e) => s + e.weight);
    return McFormColumn(
      gap: 10,
      children: [
        Row(
          children: [
            Text(t.mcLootRolls, style: TextStyle(color: luma.textSecondary, fontSize: 12.5)),
            const Spacer(),
            McStepper(value: pool.rollsMin, min: 0, max: 64, onChanged: (v) {
              pool.rollsMin = v;
              if (pool.rollsMax < v) pool.rollsMax = v;
              onChanged();
            }),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(t.mcLootTo)),
            McStepper(value: pool.rollsMax, min: 0, max: 64, onChanged: (v) {
              pool.rollsMax = v;
              if (pool.rollsMin > v) pool.rollsMin = v;
              onChanged();
            }),
          ],
        ),
        McSwitch(
          label: t.mcLootPlayerKill,
          value: pool.playerKill,
          onChanged: (v) {
            pool.playerKill = v;
            onChanged();
          },
        ),
        for (var i = 0; i < pool.entries.length; i++)
          _EntryEditor(
            key: ObjectKey(pool.entries[i]),
            entry: pool.entries[i],
            share: total == 0 ? 0 : pool.entries[i].weight / total,
            onChanged: onChanged,
            onRemove: pool.entries.length > 1
                ? () {
                    pool.entries.removeAt(i);
                    onChanged();
                  }
                : null,
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              pool.entries.add(_Entry(item: 'emerald'));
              onChanged();
            },
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(t.mcLootAddEntry),
          ),
        ),
      ],
    );
  }
}

class _EntryEditor extends StatelessWidget {
  const _EntryEditor({
    super.key,
    required this.entry,
    required this.share,
    required this.onChanged,
    required this.onRemove,
  });

  final _Entry entry;
  final double share;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final e = entry;
    void set(VoidCallback f) {
      f();
      onChanged();
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: luma.surfaceHover, borderRadius: BorderRadius.circular(10)),
      child: McFormColumn(
        gap: 8,
        children: [
          Row(
            children: [
              Expanded(
                child: e.empty
                    ? Text(t.mcLootNothing, style: TextStyle(color: luma.textSecondary, fontSize: 13))
                    : McIdField(
                        options: kMcItems,
                        value: e.item,
                        onChanged: (v) => set(() => e.item = v),
                      ),
              ),
              const SizedBox(width: 6),
              McTag('${(share * 100).toStringAsFixed(share < 0.1 ? 1 : 0)}%', hue: McHue.amber),
              if (onRemove != null) McIconButton(icon: Icons.close_rounded, tooltip: t.mcLootRemoveEntry, onTap: onRemove),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(t.mcLootWeight, style: TextStyle(color: luma.textSecondary, fontSize: 12)),
              McStepper(value: e.weight, min: 1, max: 1000, onChanged: (v) => set(() => e.weight = v)),
              if (!e.empty) ...[
                Text(t.mcLootCount, style: TextStyle(color: luma.textSecondary, fontSize: 12)),
                McStepper(value: e.min, min: 1, max: 64, onChanged: (v) => set(() {
                  e.min = v;
                  if (e.max < v) e.max = v;
                })),
                McStepper(value: e.max, min: 1, max: 64, onChanged: (v) => set(() {
                  e.max = v;
                  if (e.min > v) e.min = v;
                })),
              ],
            ],
          ),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              FilterChip(label: Text(t.mcLootEmpty), selected: e.empty, onSelected: (v) => set(() => e.empty = v)),
              if (!e.empty) ...[
                FilterChip(label: Text(t.mcLootRandomEnchant), selected: e.enchantRandomly, onSelected: (v) => set(() => e.enchantRandomly = v)),
                FilterChip(label: Text(t.mcLootEnchantLevels), selected: e.enchantLevels, onSelected: (v) => set(() => e.enchantLevels = v)),
                FilterChip(label: Text(t.mcLootLooting), selected: e.looting, onSelected: (v) => set(() => e.looting = v)),
                FilterChip(label: Text(t.mcLootSmelt), selected: e.smelt, onSelected: (v) => set(() => e.smelt = v)),
                FilterChip(label: Text(t.mcLootDecay), selected: e.decay, onSelected: (v) => set(() => e.decay = v)),
              ],
            ],
          ),
          if (!e.empty && e.enchantLevels)
            Row(
              children: [
                Text(t.mcLootLevels, style: TextStyle(color: luma.textSecondary, fontSize: 12)),
                const Spacer(),
                McStepper(value: e.levelMin, min: 1, max: 60, onChanged: (v) => set(() => e.levelMin = v)),
                const SizedBox(width: 6),
                McStepper(value: e.levelMax, min: 1, max: 60, onChanged: (v) => set(() => e.levelMax = v)),
              ],
            ),
          if (!e.empty)
            McTextField(
              initialValue: e.name,
              hint: t.mcLootCustomName,
              onChanged: (v) => set(() => e.name = v),
            ),
          if (!e.empty)
            McSlider(
              label: t.mcLootChance,
              value: e.chance,
              min: 0.01,
              max: 1,
              format: (v) => '${(v * 100).round()}%',
              onChanged: (v) => set(() => e.chance = v),
            ),
        ],
      ),
    );
  }
}
