import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/mc_registries_data.dart';
import '../../data/mc_text.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_files.dart';
import '../../ui/mc_span_editor.dart';
import '../../ui/mc_style.dart';

/// The three shapes predicates took across 26.x: 26.1 keyed conditions by
/// `condition` and entity types by `type`; 26.2 switched entity types to
/// `minecraft:entity_type`; 26.3 keys conditions by `type` and no longer
/// wraps a single one in a list.
enum _Version {
  v263('26.3+'),
  v262('26.2'),
  v261('26.1');

  const _Version(this.label);
  final String label;
}

enum _Trigger {
  obtain('minecraft:inventory_changed', 'item'),
  eat('minecraft:consume_item', 'item'),
  place('minecraft:placed_block', 'block'),
  kill('minecraft:player_killed_entity', 'entity'),
  travel('minecraft:changed_dimension', 'dimension'),
  craft('minecraft:recipe_crafted', 'recipe'),
  manual('minecraft:impossible', '');

  const _Trigger(this.id, this.needs);

  String label(L t) => switch (this) {
    obtain => t.mcAdvObtain,
    eat => t.mcAdvEat,
    place => t.mcAdvPlace,
    kill => t.mcAdvKill,
    travel => t.mcAdvTravel,
    craft => t.mcAdvCraft,
    manual => t.mcAdvManual,
  };

  final String id;
  final String needs;
}

class _Criterion {
  _Criterion(this.trigger, this.value);
  _Trigger trigger;
  String value;
}

/// Advancements: what to do, how it looks in the tree and what it rewards.
class AdvancementTool extends StatefulWidget {
  const AdvancementTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<AdvancementTool> createState() => _AdvancementToolState();
}

class _AdvancementToolState extends State<AdvancementTool> {
  _Version _version = _Version.v263;
  String _name = 'diamond_hunter';
  final List<McTextSpan> _title = [McTextSpan(text: 'Diamond Hunter', color: 'aqua')];
  final List<McTextSpan> _description = [McTextSpan(text: 'Find your first diamond')];
  String _icon = 'diamond';
  String _frame = 'task';
  bool _root = false;
  String _parent = 'minecraft:story/mine_diamond';
  String _background = 'minecraft:gui/advancements/backgrounds/stone';
  bool _toast = true;
  bool _chat = true;
  bool _hidden = false;
  bool _anyOf = false;
  final List<_Criterion> _criteria = [_Criterion(_Trigger.obtain, 'diamond')];
  int _xp = 50;
  String _rewardRecipe = '';
  String _rewardLoot = '';
  String _rewardFunction = '';

  String get _slug => mcSlug(_name, fallback: 'advancement');

  String _ns(String v) => v.contains(':') ? v : 'minecraft:$v';

  Map<String, Object> _conditions(_Criterion c) {
    final v = _ns(c.value.trim().isEmpty ? 'stone' : c.value.trim());
    switch (c.trigger) {
      case _Trigger.obtain:
        return {'items': [{'items': v}]};
      case _Trigger.eat:
        return {'item': {'items': v}};
      case _Trigger.place:
        return _version == _Version.v263
            ? {'location': {'type': 'minecraft:match_block', 'blocks': v}}
            : {'location': [{'block': v, 'condition': 'minecraft:block_state_property'}]};
      case _Trigger.kill:
        final predicate = _version == _Version.v261 ? {'type': v} : {'minecraft:entity_type': v};
        final cond = <String, Object>{
          _version == _Version.v263 ? 'type' : 'condition': 'minecraft:entity_properties',
          'entity': 'this',
          'predicate': predicate,
        };
        return {'entity': _version == _Version.v263 ? cond : [cond]};
      case _Trigger.travel:
        return {'to': v};
      case _Trigger.craft:
        return {'recipe_id': v};
      case _Trigger.manual:
        return const {};
    }
  }

  Map<String, Object> get _json {
    final criteria = <String, Object>{};
    final names = <String>[];
    for (var i = 0; i < _criteria.length; i++) {
      final c = _criteria[i];
      final name = '${c.trigger.name}_$i';
      names.add(name);
      final conds = _conditions(c);
      criteria[name] = {if (conds.isNotEmpty) 'conditions': conds, 'trigger': c.trigger.id};
    }
    final rewards = <String, Object>{
      if (_xp > 0) 'experience': _xp,
      if (_rewardRecipe.trim().isNotEmpty) 'recipes': [_ns(_rewardRecipe.trim())],
      if (_rewardLoot.trim().isNotEmpty) 'loot': [_ns(_rewardLoot.trim())],
      if (_rewardFunction.trim().isNotEmpty) 'function': _ns(_rewardFunction.trim()),
    };
    return {
      if (!_root && _parent.trim().isNotEmpty) 'parent': _ns(_parent.trim()),
      'criteria': criteria,
      'display': {
        'announce_to_chat': _chat,
        if (_root) 'background': _background,
        'description': jsonDecode(mcComponentJson(_description)),
        'frame': _frame,
        'hidden': _hidden,
        'icon': {'id': _ns(_icon)},
        'show_toast': _toast,
        'title': jsonDecode(mcComponentJson(_title)),
      },
      'requirements': _anyOf ? [names] : [for (final n in names) [n]],
      if (rewards.isNotEmpty) 'rewards': rewards,
    };
  }

  String get _path => 'data/luma/advancement/$_slug.json';

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final json = const JsonEncoder.withIndent('  ').convert(_json);
    final frameColor = switch (_frame) {
      'challenge' => McHue.violet.color,
      'goal' => McHue.sky.color,
      _ => McHue.amber.color,
    };
    return widget.host.frame(
      context,
      child: McSplit(
        controlsWidth: 470,
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcAdvAdvancement,
              icon: Icons.emoji_events_rounded,
              child: McFormColumn(
                gap: 10,
                children: [
                  McChoice<_Version>(
                    values: _Version.values,
                    selected: _version,
                    label: (v) => v.label,
                    onSelect: (v) => setState(() => _version = v),
                  ),
                  McField(label: t.mcAdvFileName, child: McTextField(initialValue: _name, monospace: true, onChanged: (v) => setState(() => _name = v))),
                  McField(label: t.mcAdvTitle, child: McSpanEditor(spans: _title, onChanged: () => setState(() {}), maxSpans: 3)),
                  McField(label: t.mcAdvDescription, child: McSpanEditor(spans: _description, onChanged: () => setState(() {}), maxSpans: 3)),
                  McField(
                    label: t.mcAdvIcon,
                    child: McIdField(options: kMcItems, value: _icon, onChanged: (v) => setState(() => _icon = v.replaceFirst('minecraft:', ''))),
                  ),
                  McField(
                    label: t.mcAdvFrame,
                    child: McChoice<String>(
                      values: const ['task', 'goal', 'challenge'],
                      selected: _frame,
                      label: mcPretty,
                      onSelect: (v) => setState(() => _frame = v),
                    ),
                  ),
                  McSwitch(label: t.mcAdvRoot, value: _root, onChanged: (v) => setState(() => _root = v)),
                  if (_root)
                    McField(
                      label: t.mcAdvBackground,
                      child: McDropdown<String>(
                        values: const [
                          'minecraft:gui/advancements/backgrounds/stone',
                          'minecraft:gui/advancements/backgrounds/adventure',
                          'minecraft:gui/advancements/backgrounds/husbandry',
                          'minecraft:gui/advancements/backgrounds/nether',
                          'minecraft:gui/advancements/backgrounds/end',
                        ],
                        value: _background,
                        label: (v) => mcPretty(v.split('/').last),
                        onChanged: (v) => setState(() => _background = v),
                      ),
                    )
                  else
                    McField(
                      label: t.mcAdvParent,
                      child: McTextField(initialValue: _parent, monospace: true, hint: 'minecraft:story/root', onChanged: (v) => setState(() => _parent = v)),
                    ),
                  McSwitch(label: t.mcAdvToast, value: _toast, onChanged: (v) => setState(() => _toast = v)),
                  McSwitch(label: t.mcAdvChat, value: _chat, onChanged: (v) => setState(() => _chat = v)),
                  McSwitch(label: t.mcAdvHidden, value: _hidden, onChanged: (v) => setState(() => _hidden = v)),
                ],
              ),
            ),
            McPanel(
              title: t.mcAdvCriteria,
              icon: Icons.checklist_rounded,
              trailing: TextButton.icon(
                onPressed: () => setState(() => _criteria.add(_Criterion(_Trigger.obtain, 'emerald'))),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(t.mcAdd),
              ),
              child: McFormColumn(
                gap: 10,
                children: [
                  for (var i = 0; i < _criteria.length; i++)
                    Container(
                      key: ObjectKey(_criteria[i]),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: luma.surfaceHover, borderRadius: BorderRadius.circular(10)),
                      child: McFormColumn(
                        gap: 8,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: McDropdown<_Trigger>(
                                  values: _Trigger.values,
                                  value: _criteria[i].trigger,
                                  label: (trigger) => trigger.label(t),
                                  onChanged: (t) => setState(() {
                                    _criteria[i].trigger = t;
                                    _criteria[i].value = switch (t.needs) {
                                      'entity' => 'zombie',
                                      'block' => 'oak_sapling',
                                      'dimension' => 'the_nether',
                                      'recipe' => 'crafting_table',
                                      '' => '',
                                      _ => 'diamond',
                                    };
                                  }),
                                ),
                              ),
                              if (_criteria.length > 1)
                                McIconButton(icon: Icons.close_rounded, tooltip: t.mcRemove, onTap: () => setState(() => _criteria.removeAt(i))),
                            ],
                          ),
                          if (_criteria[i].trigger.needs == 'dimension')
                            McChoice<String>(
                              values: const ['the_nether', 'the_end', 'overworld'],
                              selected: _criteria[i].value,
                              label: mcPretty,
                              onSelect: (v) => setState(() => _criteria[i].value = v),
                            )
                          else if (_criteria[i].trigger.needs.isNotEmpty)
                            McIdField(
                              key: ValueKey('${_criteria[i].trigger}-$i'),
                              options: switch (_criteria[i].trigger.needs) {
                                'entity' => kMcEntities,
                                'block' => kMcBlocks,
                                _ => kMcItems,
                              },
                              value: _criteria[i].value,
                              onChanged: (v) => setState(() => _criteria[i].value = v),
                            ),
                        ],
                      ),
                    ),
                  if (_criteria.length > 1)
                    McChoice<bool>(
                      values: const [false, true],
                      selected: _anyOf,
                      label: (v) => v ? t.mcAdvAnyOne : t.mcAdvAllOf,
                      onSelect: (v) => setState(() => _anyOf = v),
                    ),
                ],
              ),
            ),
            McPanel(
              title: t.mcAdvRewards,
              icon: Icons.redeem_rounded,
              child: McFormColumn(
                gap: 8,
                children: [
                  McSlider(label: t.mcAdvXp, value: _xp.toDouble(), min: 0, max: 1000, onChanged: (v) => setState(() => _xp = v.round())),
                  McTextField(initialValue: _rewardRecipe, monospace: true, hint: t.mcAdvRecipeHint, onChanged: (v) => setState(() => _rewardRecipe = v)),
                  McTextField(initialValue: _rewardLoot, monospace: true, hint: t.mcAdvLootHint, onChanged: (v) => setState(() => _rewardLoot = v)),
                  McTextField(initialValue: _rewardFunction, monospace: true, hint: t.mcAdvFunctionHint, onChanged: (v) => setState(() => _rewardFunction = v)),
                ],
              ),
            ),
          ],
        ),
        result: McFormColumn(
          children: [
            McGameBackdrop(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: frameColor.withValues(alpha: 0.25),
                      border: Border.all(color: frameColor, width: 3),
                      borderRadius: BorderRadius.circular(_frame == 'goal' ? 26 : 6),
                    ),
                    child: const Icon(Icons.diamond_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        McTextPreview(
                          spans: [
                            McTextSpan(
                              text: switch (_frame) {
                                'challenge' => t.mcAdvChallenge,
                                'goal' => t.mcAdvGoal,
                                _ => t.mcAdvMade,
                              },
                              color: _frame == 'challenge' ? 'light_purple' : 'yellow',
                            ),
                          ],
                          fontSize: 13,
                        ),
                        McTextPreview(spans: _title, fontSize: 15),
                        McTextPreview(spans: _description, fontSize: 12, fallback: const Color(0xFFAAAAAA)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                mcDatapackZip(t.mcAdvDatapackDesc, {_path: json}),
                fileName: 'luma_advancement_$_slug.zip',
                mimeType: 'application/zip',
              ),
            ),
            Text(
              t.mcAdvGrant('/advancement grant @s only luma:$_slug'),
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
