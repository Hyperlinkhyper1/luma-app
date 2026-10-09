import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/enchant_optimizer.dart';
import '../../data/mc_dyes.dart';
import '../../data/mc_registries_data.dart';
import '../../data/mc_text.dart';
import '../../mc_tool_host.dart';
import '../../tools/players/potion_guide_tool.dart';
import '../../ui/mc_span_editor.dart';
import '../../ui/mc_style.dart';

class _Effect {
  _Effect(this.id, {this.level = 1, this.seconds = 60});
  String id;
  int level;
  int seconds;
  bool infinite = false;
  bool particles = true;
  bool icon = true;
  bool ambient = false;
}

const _kinds = ['potion', 'splash_potion', 'lingering_potion', 'tipped_arrow'];

/// Potions, splash and lingering potions and tipped arrows with any effects,
/// levels and lengths — the `/give` command for each.
class CustomPotionsTool extends StatefulWidget {
  const CustomPotionsTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<CustomPotionsTool> createState() => _CustomPotionsToolState();
}

class _CustomPotionsToolState extends State<CustomPotionsTool> {
  String _kind = 'potion';
  final List<McTextSpan> _name = [McTextSpan(text: 'Potion of the Miner', color: 'aqua')];
  bool _named = true;
  Color _color = const Color(0xFF3AB3DA);
  bool _customColor = true;
  final List<_Effect> _effects = [
    _Effect('haste', level: 3, seconds: 600),
    _Effect('night_vision', seconds: 600),
  ];
  int _count = 1;
  String _target = '@p';

  String get _command {
    final effects = _effects.map((e) {
      final parts = [
        'id:"minecraft:${e.id}"',
        if (e.level > 1) 'amplifier:${e.level - 1}',
        'duration:${e.infinite ? -1 : e.seconds * 20}',
        if (!e.particles) 'show_particles:false',
        if (!e.icon) 'show_icon:false',
        if (e.ambient) 'ambient:true',
      ];
      return '{${parts.join(',')}}';
    }).join(',');
    final contents = [
      if (_customColor) 'custom_color:${mcRgbInt(_color)}',
      if (_effects.isNotEmpty) 'custom_effects:[$effects]',
    ];
    final components = [
      'potion_contents={${contents.join(',')}}',
      if (_named && _name.any((s) => s.text.isNotEmpty))
        'custom_name=${mcComponentJson(_name, explicitItalic: true)}',
    ];
    return '/give $_target $_kind[${components.join(',')}] $_count';
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return widget.host.frame(
      context,
      child: McSplit(
        controlsWidth: 460,
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcPotItem,
              icon: Icons.local_drink_rounded,
              child: McFormColumn(
                gap: 10,
                children: [
                  McChoice<String>(
                    values: _kinds,
                    selected: _kind,
                    label: mcPretty,
                    onSelect: (v) => setState(() => _kind = v),
                  ),
                  McSwitch(label: t.mcPotCustomName, value: _named, onChanged: (v) => setState(() => _named = v)),
                  if (_named) McSpanEditor(spans: _name, onChanged: () => setState(() {}), maxSpans: 4),
                  McSwitch(label: t.mcPotCustomColour, value: _customColor, onChanged: (v) => setState(() => _customColor = v)),
                  if (_customColor)
                    Row(
                      children: [
                        McSwatch(color: _color, onTap: () {}, size: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: McTextField(
                            initialValue: mcHex(_color),
                            monospace: true,
                            onChanged: (v) {
                              final c = mcParseHex(v);
                              if (c != null) setState(() => _color = c);
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            McPanel(
              title: t.mcPotEffects,
              icon: Icons.auto_awesome_rounded,
              trailing: TextButton.icon(
                onPressed: () => setState(() => _effects.add(_Effect('speed'))),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(t.mcAdd),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _effects.length; i++)
                    Container(
                      key: ObjectKey(_effects[i]),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: luma.surfaceHover, borderRadius: BorderRadius.circular(10)),
                      child: McFormColumn(
                        gap: 8,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: McDropdown<String>(
                                  values: kMcEffects,
                                  value: _effects[i].id,
                                  label: mcPretty,
                                  onChanged: (v) => setState(() => _effects[i].id = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              McStepper(
                                value: _effects[i].level,
                                min: 1,
                                max: 255,
                                onChanged: (v) => setState(() => _effects[i].level = v),
                              ),
                              McIconButton(
                                icon: Icons.close_rounded,
                                tooltip: t.mcPotRemoveEffect,
                                onTap: () => setState(() => _effects.removeAt(i)),
                              ),
                            ],
                          ),
                          Text(
                            '${mcPretty(_effects[i].id)} ${mcRoman(_effects[i].level)}',
                            style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                          ),
                          if (!_effects[i].infinite)
                            McSlider(
                              label: t.mcPotDuration,
                              value: _effects[i].seconds.toDouble(),
                              min: 1,
                              max: 3600,
                              format: (v) => '${v.round() ~/ 60}:${(v.round() % 60).toString().padLeft(2, '0')}',
                              onChanged: (v) => setState(() => _effects[i].seconds = v.round()),
                            ),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              FilterChip(label: Text(t.mcPotInfinite), selected: _effects[i].infinite, onSelected: (v) => setState(() => _effects[i].infinite = v)),
                              FilterChip(label: Text(t.mcPotParticles), selected: _effects[i].particles, onSelected: (v) => setState(() => _effects[i].particles = v)),
                              FilterChip(label: Text(t.mcPotIcon), selected: _effects[i].icon, onSelected: (v) => setState(() => _effects[i].icon = v)),
                              FilterChip(label: Text(t.mcPotAmbient), selected: _effects[i].ambient, onSelected: (v) => setState(() => _effects[i].ambient = v)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (_effects.isEmpty)
                    Text(t.mcPotNoEffects, style: TextStyle(color: luma.textMuted, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
        result: McFormColumn(
          children: [
            McPanel(
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    height: 72,
                    child: CustomPaint(painter: McBottlePainter(_customColor ? _color : const Color(0xFF385DC6))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: McGameBackdrop(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          McTextPreview(
                            spans: _named ? _name : [McTextSpan(text: mcPretty(_kind))],
                            fontSize: 15,
                          ),
                          const SizedBox(height: 4),
                          for (final e in _effects)
                            McTextPreview(
                              spans: [
                                McTextSpan(
                                  text: '${mcPretty(e.id)}${e.level > 1 ? ' ${mcRoman(e.level)}' : ''}'
                                      ' (${e.infinite ? '∞' : '${e.seconds ~/ 60}:${(e.seconds % 60).toString().padLeft(2, '0')}'})',
                                  color: 'blue',
                                ),
                              ],
                              fontSize: 13,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 160,
                  child: McTextField(
                    initialValue: _target,
                    monospace: true,
                    onChanged: (v) => setState(() => _target = v.trim().isEmpty ? '@p' : v.trim()),
                  ),
                ),
                McStepper(value: _count, min: 1, max: 64, onChanged: (v) => setState(() => _count = v)),
              ],
            ),
            McCodeBox(code: _command, title: t.mcCommand),
            Text(
              t.mcPotDurationNote,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
