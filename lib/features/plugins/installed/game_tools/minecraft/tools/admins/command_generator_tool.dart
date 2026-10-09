import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/enchant_optimizer.dart';
import '../../data/mc_registries_data.dart';
import '../../data/mc_text.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_span_editor.dart';
import '../../ui/mc_style.dart';

enum _Command {
  give('/give', Icons.card_giftcard_rounded),
  summon('/summon', Icons.pets_rounded),
  effect('/effect', Icons.auto_awesome_rounded),
  teleport('/tp', Icons.place_rounded),
  fill('/fill & /setblock', Icons.format_paint_rounded),
  gamerule('/gamerule', Icons.rule_rounded),
  xp('/xp', Icons.trending_up_rounded),
  world('/time & /weather', Icons.wb_sunny_rounded);

  const _Command(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _intRules = {
  'fire_spread_radius_around_player', 'max_block_modifications', 'max_command_forks',
  'max_command_sequence_length', 'max_entity_cramming', 'max_minecart_speed',
  'max_snow_accumulation_height', 'players_nether_portal_creative_delay',
  'players_nether_portal_default_delay', 'players_sleeping_percentage',
  'random_tick_speed', 'respawn_radius',
};

/// MCStacker-style command builder: pick a command, fill in the form, copy
/// the result. Written for Java Edition 26.x component syntax.
class CommandGeneratorTool extends StatefulWidget {
  const CommandGeneratorTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<CommandGeneratorTool> createState() => _CommandGeneratorToolState();
}

class _CommandGeneratorToolState extends State<CommandGeneratorTool> {
  _Command _command = _Command.give;
  String _target = '@p';

  // give
  String _item = 'diamond_sword';
  int _count = 1;
  bool _named = false;
  final List<McTextSpan> _name = [McTextSpan(text: 'Excalibur', color: 'gold', bold: true)];
  final List<String> _lore = [];
  final Map<String, int> _enchants = {'sharpness': 5};
  bool _unbreakable = false;
  bool _glint = false;

  // summon
  String _entity = 'zombie';
  String _pos = '~ ~ ~';
  String _entityName = '';
  bool _nameVisible = false;
  bool _noAi = false;
  bool _silent = false;
  bool _invulnerable = false;
  bool _glowing = false;
  bool _persistent = false;
  bool _noGravity = false;
  bool _baby = false;

  // effect
  bool _clear = false;
  String _effect = 'speed';
  int _effectSeconds = 30;
  bool _effectInfinite = false;
  int _effectLevel = 1;
  bool _hideParticles = false;

  // teleport
  String _x = '0', _y = '64', _z = '0';
  String _yaw = '', _pitch = '';

  // fill
  bool _single = false;
  String _block = 'stone';
  String _from = '~ ~ ~';
  String _to = '~10 ~5 ~10';
  String _fillMode = 'replace';

  // gamerule
  String _rule = 'keep_inventory';
  String _ruleValue = 'true';

  // xp
  bool _xpSet = false;
  int _xpAmount = 30;
  bool _levels = true;

  // world
  String _time = 'day';
  String _weather = 'clear';
  int _weatherSeconds = 0;

  String get _output => switch (_command) {
    _Command.give => _give(),
    _Command.summon => _summon(),
    _Command.effect => _clear
        ? '/effect clear $_target minecraft:$_effect'
        : '/effect give $_target minecraft:$_effect ${_effectInfinite ? 'infinite' : _effectSeconds} ${_effectLevel - 1}${_hideParticles ? ' true' : ''}',
    _Command.teleport => '/tp $_target $_x $_y $_z${_yaw.isNotEmpty && _pitch.isNotEmpty ? ' $_yaw $_pitch' : ''}',
    _Command.fill => _single
        ? '/setblock $_from minecraft:$_block${_fillMode == 'replace' ? '' : ' ${_fillMode == 'hollow' || _fillMode == 'outline' ? 'replace' : _fillMode}'}'
        : '/fill $_from $_to minecraft:$_block $_fillMode',
    _Command.gamerule => '/gamerule $_rule $_ruleValue',
    _Command.xp => '/xp ${_xpSet ? 'set' : 'add'} $_target $_xpAmount ${_levels ? 'levels' : 'points'}',
    _Command.world => '/time set $_time\n/weather $_weather${_weatherSeconds > 0 ? ' ${_weatherSeconds}s' : ''}',
  };

  String _give() {
    final components = <String>[
      if (_named && _name.any((s) => s.text.isNotEmpty)) 'custom_name=${mcComponentJson(_name, explicitItalic: true)}',
      if (_lore.any((l) => l.isNotEmpty))
        'lore=[${_lore.where((l) => l.isNotEmpty).map((l) => mcComponentJson([McTextSpan(text: l, color: 'gray')], explicitItalic: true)).join(',')}]',
      if (_enchants.isNotEmpty) 'enchantments={${_enchants.entries.map((e) => '${e.key}:${e.value}').join(',')}}',
      if (_unbreakable) 'unbreakable={}',
      if (_glint) 'enchantment_glint_override=true',
    ];
    return '/give $_target $_item${components.isEmpty ? '' : '[${components.join(',')}]'} $_count';
  }

  String _summon() {
    final nbt = <String>[
      if (_entityName.isNotEmpty) 'CustomName:${mcComponentJson([McTextSpan(text: _entityName)])}',
      if (_nameVisible) 'CustomNameVisible:1b',
      if (_noAi) 'NoAI:1b',
      if (_silent) 'Silent:1b',
      if (_invulnerable) 'Invulnerable:1b',
      if (_glowing) 'Glowing:1b',
      if (_persistent) 'PersistenceRequired:1b',
      if (_noGravity) 'NoGravity:1b',
      if (_baby) 'IsBaby:1b',
    ];
    return '/summon minecraft:$_entity $_pos${nbt.isEmpty ? '' : ' {${nbt.join(',')}}'}';
  }

  Widget _row(String label, Widget child) => Row(
    children: [
      SizedBox(
        width: 110,
        child: Text(label, style: TextStyle(color: context.luma.textSecondary, fontSize: 12.5)),
      ),
      Expanded(child: child),
    ],
  );

  Widget _text(String value, ValueChanged<String> set, {String? hint}) => McTextField(
    key: ValueKey('$_command-$hint'),
    initialValue: value,
    monospace: true,
    hint: hint,
    onChanged: (v) => setState(() => set(v.trim())),
  );

  Widget _form() {
    final t = L.of(context);
    switch (_command) {
      case _Command.give:
        return McFormColumn(
          gap: 10,
          children: [
            _row(t.mcCmdItem, McIdField(options: kMcItems, value: _item, onChanged: (v) => setState(() => _item = v.replaceFirst('minecraft:', '')))),
            _row(t.mcCmdCount, Align(alignment: Alignment.centerLeft, child: McStepper(value: _count, min: 1, max: 99, onChanged: (v) => setState(() => _count = v)))),
            McSwitch(label: t.mcCmdCustomName, value: _named, onChanged: (v) => setState(() => _named = v)),
            if (_named) McSpanEditor(spans: _name, onChanged: () => setState(() {}), maxSpans: 4),
            McField(
              label: t.mcCmdEnchantments,
              child: Column(
                children: [
                  for (final e in _enchants.entries.toList())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: McDropdown<String>(
                              values: kMcEnchantments,
                              value: e.key,
                              label: mcPretty,
                              onChanged: (v) => setState(() {
                                final level = _enchants.remove(e.key)!;
                                _enchants[v] = level;
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          McStepper(value: e.value, min: 1, max: 255, onChanged: (v) => setState(() => _enchants[e.key] = v)),
                          McIconButton(icon: Icons.close_rounded, tooltip: t.mcRemove, onTap: () => setState(() => _enchants.remove(e.key))),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        final next = kMcEnchantments.firstWhere((e) => !_enchants.containsKey(e), orElse: () => 'unbreaking');
                        _enchants[next] = 1;
                      }),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(t.mcCmdAddEnchantment),
                    ),
                  ),
                ],
              ),
            ),
            McField(
              label: t.mcCmdLore,
              child: Column(
                children: [
                  for (var i = 0; i < _lore.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: McTextField(
                              key: ValueKey('lore-$i-${_lore.length}'),
                              initialValue: _lore[i],
                              onChanged: (v) => setState(() => _lore[i] = v),
                            ),
                          ),
                          McIconButton(icon: Icons.close_rounded, tooltip: t.mcCmdRemoveLine, onTap: () => setState(() => _lore.removeAt(i))),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _lore.add('')),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(t.mcCmdAddLore),
                    ),
                  ),
                ],
              ),
            ),
            McSwitch(label: t.mcCmdUnbreakable, value: _unbreakable, onChanged: (v) => setState(() => _unbreakable = v)),
            McSwitch(label: t.mcCmdGlint, value: _glint, onChanged: (v) => setState(() => _glint = v)),
          ],
        );
      case _Command.summon:
        return McFormColumn(
          gap: 10,
          children: [
            _row(t.mcCmdEntity, McIdField(options: kMcEntities, value: _entity, onChanged: (v) => setState(() => _entity = v.replaceFirst('minecraft:', '')))),
            _row(t.mcCmdPosition, _text(_pos, (v) => _pos = v.isEmpty ? '~ ~ ~' : v, hint: '~ ~ ~')),
            _row(t.mcCmdName, _text(_entityName, (v) => _entityName = v, hint: t.mcCmdOptional)),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final (label, value, set) in [
                  (t.mcCmdNameVisible, _nameVisible, (bool v) => _nameVisible = v),
                  (t.mcCmdNoAi, _noAi, (bool v) => _noAi = v),
                  (t.mcCmdSilent, _silent, (bool v) => _silent = v),
                  (t.mcCmdInvulnerable, _invulnerable, (bool v) => _invulnerable = v),
                  (t.mcCmdGlowing, _glowing, (bool v) => _glowing = v),
                  (t.mcCmdPersistent, _persistent, (bool v) => _persistent = v),
                  (t.mcCmdNoGravity, _noGravity, (bool v) => _noGravity = v),
                  (t.mcCmdBaby, _baby, (bool v) => _baby = v),
                ])
                  FilterChip(label: Text(label), selected: value, onSelected: (v) => setState(() => set(v))),
              ],
            ),
          ],
        );
      case _Command.effect:
        return McFormColumn(
          gap: 10,
          children: [
            McChoice<bool>(values: const [false, true], selected: _clear, label: (v) => v ? t.mcCmdClear : t.mcCmdGive, onSelect: (v) => setState(() => _clear = v)),
            _row(t.mcCmdEffect, McDropdown<String>(values: kMcEffects, value: _effect, label: mcPretty, onChanged: (v) => setState(() => _effect = v))),
            if (!_clear) ...[
              _row(t.mcCmdLevel, Align(alignment: Alignment.centerLeft, child: McStepper(value: _effectLevel, min: 1, max: 256, onChanged: (v) => setState(() => _effectLevel = v)))),
              McSwitch(label: t.mcPotInfinite, value: _effectInfinite, onChanged: (v) => setState(() => _effectInfinite = v)),
              if (!_effectInfinite)
                McSlider(
                  label: t.mcCmdSeconds,
                  value: _effectSeconds.toDouble(),
                  min: 1,
                  max: 1000,
                  onChanged: (v) => setState(() => _effectSeconds = v.round()),
                ),
              McSwitch(label: t.mcCmdHideParticles, value: _hideParticles, onChanged: (v) => setState(() => _hideParticles = v)),
            ],
          ],
        );
      case _Command.teleport:
        return McFormColumn(
          gap: 10,
          children: [
            _row('X', _text(_x, (v) => _x = v.isEmpty ? '~' : v, hint: 'x')),
            _row('Y', _text(_y, (v) => _y = v.isEmpty ? '~' : v, hint: 'y')),
            _row('Z', _text(_z, (v) => _z = v.isEmpty ? '~' : v, hint: 'z')),
            _row(t.mcCmdYaw, _text(_yaw, (v) => _yaw = v, hint: t.mcCmdYawHint)),
            _row(t.mcCmdPitch, _text(_pitch, (v) => _pitch = v, hint: t.mcCmdPitchHint)),
            Text(t.mcCmdCoordsHelp, style: TextStyle(color: context.luma.textMuted, fontSize: 12)),
          ],
        );
      case _Command.fill:
        return McFormColumn(
          gap: 10,
          children: [
            McChoice<bool>(values: const [false, true], selected: _single, label: (v) => v ? t.mcCmdOneBlock : t.mcCmdArea, onSelect: (v) => setState(() => _single = v)),
            _row(t.mcCmdBlock, McIdField(options: kMcBlocks, value: _block, onChanged: (v) => setState(() => _block = v.replaceFirst('minecraft:', '')))),
            _row(_single ? t.mcCmdAt : t.mcCmdFrom, _text(_from, (v) => _from = v.isEmpty ? '~ ~ ~' : v, hint: '~ ~ ~')),
            if (!_single) _row(t.mcCmdTo, _text(_to, (v) => _to = v.isEmpty ? '~ ~ ~' : v, hint: '~10 ~5 ~10')),
            McChoice<String>(
              values: _single ? const ['replace', 'destroy', 'keep'] : const ['replace', 'destroy', 'hollow', 'outline', 'keep'],
              selected: _fillMode,
              label: mcPretty,
              onSelect: (v) => setState(() => _fillMode = v),
            ),
            Text(t.mcCmdFillLimit, style: TextStyle(color: context.luma.textMuted, fontSize: 12)),
          ],
        );
      case _Command.gamerule:
        final isInt = _intRules.contains(_rule);
        return McFormColumn(
          gap: 10,
          children: [
            _row(t.mcCmdRule, McDropdown<String>(values: kMcGameRules, value: _rule, label: mcPretty, onChanged: (v) => setState(() {
              _rule = v;
              _ruleValue = _intRules.contains(v) ? '3' : 'true';
            }))),
            if (isInt)
              _row(t.mcCmdValue, _text(_ruleValue, (v) => _ruleValue = v.isEmpty ? '0' : v, hint: t.mcCmdNumber))
            else
              McChoice<String>(values: const ['true', 'false'], selected: _ruleValue, label: (v) => v, onSelect: (v) => setState(() => _ruleValue = v)),
            Text(t.mcCmdRuleNote, style: TextStyle(color: context.luma.textMuted, fontSize: 12)),
          ],
        );
      case _Command.xp:
        return McFormColumn(
          gap: 10,
          children: [
            McChoice<bool>(values: const [false, true], selected: _xpSet, label: (v) => v ? t.mcCmdSet : t.mcCmdAddXp, onSelect: (v) => setState(() => _xpSet = v)),
            McChoice<bool>(values: const [true, false], selected: _levels, label: (v) => v ? t.mcCmdLevels : t.mcCmdPoints, onSelect: (v) => setState(() => _levels = v)),
            McSlider(label: t.mcCmdAmount, value: _xpAmount.toDouble(), min: _xpSet ? 0 : -100, max: 1000, onChanged: (v) => setState(() => _xpAmount = v.round())),
            if (_levels) Text(t.mcCmdXpNote(mcXpForLevel(_xpAmount.abs()), _xpAmount.abs()), style: TextStyle(color: context.luma.textMuted, fontSize: 12)),
          ],
        );
      case _Command.world:
        return McFormColumn(
          gap: 10,
          children: [
            McField(label: t.mcCmdTime, child: McChoice<String>(values: const ['day', 'noon', 'night', 'midnight', '0', '6000', '13000', '18000'], selected: _time, label: mcPretty, onSelect: (v) => setState(() => _time = v))),
            McField(label: t.mcCmdWeather, child: McChoice<String>(values: const ['clear', 'rain', 'thunder'], selected: _weather, label: mcPretty, onSelect: (v) => setState(() => _weather = v))),
            McSlider(
              label: t.mcCmdWeatherLasts,
              value: _weatherSeconds.toDouble(),
              min: 0,
              max: 3600,
              format: (v) => v == 0 ? t.mcCmdRandom : '${v.round()} s',
              onChanged: (v) => setState(() => _weatherSeconds = v.round()),
            ),
          ],
        );
    }
  }

  bool get _usesTarget => switch (_command) {
    _Command.give || _Command.effect || _Command.teleport || _Command.xp => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return widget.host.frame(
      context,
      child: McFormColumn(
        children: [
          McPanel(
            padding: const EdgeInsets.all(10),
            child: McChoice<_Command>(
              values: _Command.values,
              selected: _command,
              label: (c) => c.label,
              icon: (c) => c.icon,
              onSelect: (c) => setState(() => _command = c),
            ),
          ),
          McSplit(
            controlsWidth: 480,
            controls: McPanel(
              title: _command.label,
              icon: _command.icon,
              child: McFormColumn(
                gap: 12,
                children: [
                  if (_usesTarget)
                    McField(
                      label: t.mcCmdTarget,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final s in const ['@p', '@a', '@s', '@r', '@e'])
                            ChoiceChip(label: Text(s), selected: _target == s, onSelected: (_) => setState(() => _target = s)),
                          SizedBox(
                            width: 160,
                            child: McTextField(
                              hint: t.mcCmdPlayerName,
                              onChanged: (v) => setState(() => _target = v.trim().isEmpty ? '@p' : v.trim()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _form(),
                ],
              ),
            ),
            result: McFormColumn(
              children: [
                McCodeBox(code: _output, title: t.mcCommand),
                Text(
                  t.mcCmdLength(_output.length),
                  style: TextStyle(color: _output.length > 256 ? luma.warning : luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
