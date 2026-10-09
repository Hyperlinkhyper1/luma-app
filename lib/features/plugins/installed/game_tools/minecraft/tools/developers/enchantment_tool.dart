import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/mc_registries_data.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_files.dart';
import '../../ui/mc_style.dart';

const _itemTags = [
  'armor', 'head_armor', 'chest_armor', 'leg_armor', 'foot_armor', 'equippable',
  'weapon', 'melee_weapon', 'sharp_weapon', 'sweeping', 'fire_aspect', 'mace',
  'lunge', 'trident', 'bow', 'crossbow', 'mining', 'mining_loot', 'fishing',
  'durability', 'vanishing',
];

const _exclusiveSets = ['', 'armor', 'boots', 'bow', 'crossbow', 'damage', 'mining', 'riptide'];

const _slots = ['mainhand', 'offhand', 'hand', 'head', 'chest', 'legs', 'feet', 'armor', 'body', 'any'];

enum _EffectKind {
  damage('minecraft:damage'),
  protection('minecraft:damage_protection'),
  attribute('minecraft:attributes'),
  mobEffect('minecraft:post_attack'),
  ignite('minecraft:post_attack'),
  knockback('minecraft:knockback'),
  experience('minecraft:mob_experience'),
  armorPierce('minecraft:armor_effectiveness');

  const _EffectKind(this.component);
  final String component;

  String label(L t) => switch (this) {
    damage => t.mcEnchGenDamage,
    protection => t.mcEnchGenProtection,
    attribute => t.mcEnchGenAttribute,
    mobEffect => t.mcEnchGenMobEffect,
    ignite => t.mcEnchGenIgnite,
    knockback => t.mcEnchGenKnockback,
    experience => t.mcEnchGenExperience,
    armorPierce => t.mcEnchGenPierce,
  };
}

class _Effect {
  _Effect(this.kind);
  _EffectKind kind;
  double base = 1;
  double perLevel = 1;
  String attribute = 'movement_speed';
  String operation = 'add_multiplied_base';
  String mobEffect = 'slowness';
  int amplifier = 0;
  bool directOnly = true;
}

/// Writes data-driven enchantments: costs, what they go on, what they clash
/// with and a set of common effects.
class EnchantmentTool extends StatefulWidget {
  const EnchantmentTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<EnchantmentTool> createState() => _EnchantmentToolState();
}

class _EnchantmentToolState extends State<EnchantmentTool> {
  bool _v263 = true;
  String _name = 'Lifesteal';
  String _supported = 'melee_weapon';
  String _primary = 'melee_weapon';
  String _exclusive = '';
  int _maxLevel = 3;
  int _weight = 2;
  int _anvil = 4;
  int _minBase = 10, _minPer = 10, _maxBase = 50, _maxPer = 10;
  final Set<String> _slotsOn = {'mainhand'};
  final List<_Effect> _effects = [
    _Effect(_EffectKind.mobEffect)
      ..mobEffect = 'weakness'
      ..base = 2
      ..perLevel = 1,
  ];

  String get _slug => mcSlug(_name, fallback: 'custom_enchantment');

  Map<String, Object> _linear(double base, double per) => {
    'type': 'minecraft:linear',
    'base': base,
    'per_level_above_first': per,
  };

  Map<String, Object> _req(String type, Map<String, Object> args) =>
      {_v263 ? 'type' : 'condition': 'minecraft:$type', ...args};

  Map<String, List<Object>> get _effectJson {
    final out = <String, List<Object>>{};
    for (final e in _effects) {
      final Object value;
      switch (e.kind) {
        case _EffectKind.damage:
        case _EffectKind.knockback:
        case _EffectKind.experience:
          value = {'effect': {'type': 'minecraft:add', 'value': _linear(e.base, e.perLevel)}};
        case _EffectKind.armorPierce:
          value = {'effect': {'type': 'minecraft:add', 'value': _linear(-e.base / 10, -e.perLevel / 10)}};
        case _EffectKind.protection:
          value = {
            'effect': {'type': 'minecraft:add', 'value': _linear(e.base, e.perLevel)},
            'requirements': _req('damage_source_properties', {
              'predicate': {
                'tags': [
                  {'expected': false, 'id': '#minecraft:bypasses_invulnerability'},
                ],
              },
            }),
          };
        case _EffectKind.attribute:
          value = {
            'amount': _linear(e.base / 10, e.perLevel / 10),
            'attribute': 'minecraft:${e.attribute}',
            'id': 'luma:enchantment.$_slug',
            'operation': e.operation,
          };
        case _EffectKind.mobEffect:
          value = {
            'affected': 'victim',
            'effect': {
              'type': 'minecraft:apply_mob_effect',
              'max_amplifier': e.amplifier.toDouble(),
              'max_duration': _linear(e.base, e.perLevel),
              'min_amplifier': e.amplifier.toDouble(),
              'min_duration': _linear(e.base, e.perLevel),
              'to_apply': 'minecraft:${e.mobEffect}',
            },
            'enchanted': 'attacker',
            if (e.directOnly)
              'requirements': _req('damage_source_properties', {'predicate': {'is_direct': true}}),
          };
        case _EffectKind.ignite:
          value = {
            'affected': 'victim',
            'effect': {'type': 'minecraft:ignite', 'duration': _linear(e.base, e.perLevel)},
            'enchanted': 'attacker',
            if (e.directOnly)
              'requirements': _req('damage_source_properties', {'predicate': {'is_direct': true}}),
          };
      }
      out.putIfAbsent(e.kind.component, () => []).add(value);
    }
    return out;
  }

  Map<String, Object> get _json => {
    'anvil_cost': _anvil,
    'description': _name,
    'effects': _effectJson,
    if (_exclusive.isNotEmpty) 'exclusive_set': '#minecraft:exclusive_set/$_exclusive',
    'max_cost': {'base': _maxBase, 'per_level_above_first': _maxPer},
    'max_level': _maxLevel,
    'min_cost': {'base': _minBase, 'per_level_above_first': _minPer},
    if (_primary.isNotEmpty) 'primary_items': '#minecraft:enchantable/$_primary',
    'slots': _slotsOn.toList(),
    'supported_items': '#minecraft:enchantable/$_supported',
    'weight': _weight,
  };

  String get _path => 'data/luma/enchantment/$_slug.json';

  Widget _num(String label, int value, ValueChanged<int> set, {int min = 0, int max = 255}) => Row(
    children: [
      Expanded(child: Text(label, style: TextStyle(color: context.luma.textSecondary, fontSize: 12.5))),
      McStepper(value: value, min: min, max: max, onChanged: (v) => setState(() => set(v))),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final json = const JsonEncoder.withIndent('  ').convert(_json);
    final tags = {
      'data/minecraft/tags/enchantment/in_enchanting_table.json': const JsonEncoder.withIndent('  ').convert({'values': ['luma:$_slug']}),
      'data/minecraft/tags/enchantment/on_random_loot.json': const JsonEncoder.withIndent('  ').convert({'values': ['luma:$_slug']}),
    };
    return widget.host.frame(
      context,
      child: McSplit(
        controlsWidth: 460,
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcEnchGenTitle,
              icon: Icons.auto_awesome_rounded,
              child: McFormColumn(
                gap: 10,
                children: [
                  McChoice<bool>(
                    values: const [true, false],
                    selected: _v263,
                    label: (v) => v ? t.mcVersionAndNewer('26.3') : '26.1 – 26.2',
                    onSelect: (v) => setState(() => _v263 = v),
                  ),
                  McField(label: t.mcEnchGenName, child: McTextField(initialValue: _name, onChanged: (v) => setState(() => _name = v))),
                  McField(
                    label: t.mcEnchGenGoesOn,
                    child: McDropdown<String>(values: _itemTags, value: _supported, label: mcPretty, onChanged: (v) => setState(() => _supported = v)),
                  ),
                  McField(
                    label: t.mcEnchGenTable,
                    child: McDropdown<String>(
                      values: ['', ..._itemTags],
                      value: _primary,
                      label: (v) => v.isEmpty ? t.mcEnchGenSame : mcPretty(v),
                      onChanged: (v) => setState(() => _primary = v),
                    ),
                  ),
                  McField(
                    label: t.mcEnchGenExclusive,
                    child: McDropdown<String>(
                      values: _exclusiveSets,
                      value: _exclusive,
                      label: (v) => v.isEmpty ? t.mcEnchGenAnything : t.mcEnchGenSetName(mcPretty(v)),
                      onChanged: (v) => setState(() => _exclusive = v),
                    ),
                  ),
                  McField(
                    label: t.mcEnchGenSlots,
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final s in _slots)
                          FilterChip(
                            label: Text(mcPretty(s)),
                            selected: _slotsOn.contains(s),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _slotsOn.add(s);
                              } else if (_slotsOn.length > 1) {
                                _slotsOn.remove(s);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            McPanel(
              title: t.mcEnchGenLevels,
              icon: Icons.tune_rounded,
              child: McFormColumn(
                gap: 8,
                children: [
                  _num(t.mcEnchGenMaxLevel, _maxLevel, (v) => _maxLevel = v, min: 1),
                  _num(t.mcEnchGenWeight, _weight, (v) => _weight = v, min: 1, max: 1024),
                  _num(t.mcEnchGenAnvil, _anvil, (v) => _anvil = v, min: 1, max: 64),
                  _num(t.mcEnchGenMin, _minBase, (v) => _minBase = v),
                  _num(t.mcEnchGenPerLevel, _minPer, (v) => _minPer = v),
                  _num(t.mcEnchGenMax, _maxBase, (v) => _maxBase = v),
                  _num(t.mcEnchGenPerLevel, _maxPer, (v) => _maxPer = v),
                ],
              ),
            ),
            McPanel(
              title: t.mcEnchGenEffects,
              icon: Icons.bolt_rounded,
              trailing: PopupMenuButton<_EffectKind>(
                tooltip: t.mcEnchGenAddEffect,
                icon: Icon(Icons.add_rounded, color: luma.accent),
                onSelected: (k) => setState(() => _effects.add(_Effect(k))),
                itemBuilder: (_) => [for (final k in _EffectKind.values) PopupMenuItem(value: k, child: Text(k.label(t)))],
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _effects.length; i++)
                    _EffectEditor(
                      key: ObjectKey(_effects[i]),
                      effect: _effects[i],
                      onChanged: () => setState(() {}),
                      onRemove: () => setState(() => _effects.removeAt(i)),
                    ),
                  if (_effects.isEmpty)
                    Text(t.mcEnchGenNoEffects, style: TextStyle(color: luma.textMuted, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
        result: McFormColumn(
          children: [
            McCodeBox(
              code: json,
              title: _path,
              maxHeight: 520,
              onSave: () => mcSaveText(context, json, fileName: '$_slug.json'),
            ),
            McButton(
              label: t.mcSaveDatapack,
              icon: Icons.folder_zip_rounded,
              primary: false,
              onTap: () => mcSaveBytes(
                context,
                mcDatapackZip(t.mcEnchGenDatapackDesc(_name), {_path: json, ...tags}),
                fileName: 'luma_enchantment_$_slug.zip',
                mimeType: 'application/zip',
              ),
            ),
            Text(
              t.mcEnchGenNote('/enchant @s luma:$_slug ${_maxLevel > 1 ? _maxLevel : 1}'),
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _EffectEditor extends StatelessWidget {
  const _EffectEditor({super.key, required this.effect, required this.onChanged, required this.onRemove});

  final _Effect effect;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final e = effect;
    void set(VoidCallback f) {
      f();
      onChanged();
    }

    final unit = switch (e.kind) {
      _EffectKind.damage => t.mcEnchGenUnitDamage,
      _EffectKind.protection => t.mcEnchGenUnitProtection,
      _EffectKind.attribute => '× 0.1',
      _EffectKind.mobEffect || _EffectKind.ignite => t.mcEnchGenUnitSeconds,
      _EffectKind.knockback => t.mcEnchGenUnitKnockback,
      _EffectKind.experience => 'xp',
      _EffectKind.armorPierce => t.mcEnchGenUnitPierce,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: luma.surfaceHover, borderRadius: BorderRadius.circular(10)),
      child: McFormColumn(
        gap: 8,
        children: [
          Row(
            children: [
              Expanded(child: Text(e.kind.label(t), style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
              McIconButton(icon: Icons.close_rounded, tooltip: t.mcEnchGenRemoveEffect, onTap: onRemove),
            ],
          ),
          if (e.kind == _EffectKind.attribute) ...[
            McDropdown<String>(values: kMcAttributes, value: e.attribute, label: mcPretty, onChanged: (v) => set(() => e.attribute = v)),
            McChoice<String>(
              values: const ['add_value', 'add_multiplied_base', 'add_multiplied_total'],
              selected: e.operation,
              label: (v) => switch (v) {
                'add_value' => t.mcEnchGenOpAdd,
                'add_multiplied_base' => t.mcEnchGenOpBase,
                _ => t.mcEnchGenOpTotal,
              },
              onSelect: (v) => set(() => e.operation = v),
            ),
          ],
          if (e.kind == _EffectKind.mobEffect) ...[
            McDropdown<String>(values: kMcEffects, value: e.mobEffect, label: mcPretty, onChanged: (v) => set(() => e.mobEffect = v)),
            Row(
              children: [
                Expanded(child: Text(t.mcEnchGenEffectLevel, style: TextStyle(color: luma.textSecondary, fontSize: 12.5))),
                McStepper(value: e.amplifier + 1, min: 1, max: 10, onChanged: (v) => set(() => e.amplifier = v - 1)),
              ],
            ),
          ],
          McSlider(
            label: t.mcEnchGenAtLevel1(unit),
            value: e.base,
            min: 0,
            max: 20,
            divisions: 80,
            format: (v) => v.toStringAsFixed(2),
            onChanged: (v) => set(() => e.base = v),
          ),
          McSlider(
            label: t.mcEnchGenEachLevel,
            value: e.perLevel,
            min: 0,
            max: 20,
            divisions: 80,
            format: (v) => '+${v.toStringAsFixed(2)}',
            onChanged: (v) => set(() => e.perLevel = v),
          ),
          if (e.kind == _EffectKind.mobEffect || e.kind == _EffectKind.ignite)
            McSwitch(
              label: t.mcEnchGenDirect,
              detail: t.mcEnchGenDirectDetail,
              value: e.directOnly,
              onChanged: (v) => set(() => e.directOnly = v),
            ),
        ],
      ),
    );
  }
}
