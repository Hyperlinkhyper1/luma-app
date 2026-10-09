import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_style.dart';

const _minerals = [
  ('iron_block', 'Iron', Color(0xFFDCDCDC), 'iron_ingot'),
  ('gold_block', 'Gold', Color(0xFFF6D04D), 'gold_ingot'),
  ('emerald_block', 'Emerald', Color(0xFF41F384), 'emerald'),
  ('diamond_block', 'Diamond', Color(0xFF62DBD5), 'diamond'),
  ('netherite_block', 'Netherite', Color(0xFF4D494D), 'netherite_ingot'),
];

List<(int, String, String, IconData)> _effects(L t) => [
  (1, 'Speed', t.mcBeaconSpeed, Icons.directions_run_rounded),
  (1, 'Haste', t.mcBeaconHaste, Icons.hardware_rounded),
  (2, 'Resistance', t.mcBeaconResistance, Icons.shield_rounded),
  (2, 'Jump Boost', t.mcBeaconJump, Icons.height_rounded),
  (3, 'Strength', t.mcBeaconStrength, Icons.fitness_center_rounded),
  (4, 'Regeneration', t.mcBeaconRegen, Icons.favorite_rounded),
];

/// Beacon pyramids: blocks per tier, range, effects and what they cost.
class BeaconGuideTool extends StatefulWidget {
  const BeaconGuideTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<BeaconGuideTool> createState() => _BeaconGuideToolState();
}

class _BeaconGuideToolState extends State<BeaconGuideTool> {
  int _tier = 4;
  int _mineral = 0;

  static int blocksFor(int tier) {
    var total = 0;
    for (var t = 1; t <= tier; t++) {
      final side = 2 * t + 1;
      total += side * side;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final blocks = blocksFor(_tier);
    final range = 10 + 10 * _tier;
    final (id, mineralName, mineralColor, ingot) = _minerals[_mineral];
    final ingots = blocks * 9;
    return widget.host.frame(
      context,
      child: McSplit(
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcBeaconTier,
              icon: Icons.signal_cellular_alt_rounded,
              child: McChoice<int>(
                values: const [1, 2, 3, 4],
                selected: _tier,
                label: t.mcBeaconTierN,
                onSelect: (t) => setState(() => _tier = t),
              ),
            ),
            McPanel(
              title: t.mcBeaconBuildFrom,
              icon: Icons.view_module_rounded,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _minerals.length; i++)
                    ChoiceChip(
                      label: Text(_minerals[i].$2),
                      selected: i == _mineral,
                      avatar: CircleAvatar(backgroundColor: _minerals[i].$3, radius: 7),
                      onSelected: (_) => setState(() => _mineral = i),
                    ),
                ],
              ),
            ),
            McPanel(
              title: t.mcBeaconLayers,
              icon: Icons.layers_rounded,
              child: Column(
                children: [
                  for (var tier = _tier; tier >= 1; tier--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text(t.mcBeaconLayerN(tier), style: TextStyle(color: luma.textSecondary, fontSize: 12.5)),
                          const Spacer(),
                          Text(
                            '${2 * tier + 1} × ${2 * tier + 1} = ${(2 * tier + 1) * (2 * tier + 1)}',
                            style: mcMono(context),
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
            McStatRow(
              stats: [
                McStat(value: '$blocks', label: t.mcBeaconBlocksOf(mineralName), hue: McHue.violet),
                McStat(value: '$range', label: t.mcBeaconRange, hue: McHue.mint),
                McStat(value: '${9 + 2 * _tier} s', label: t.mcBeaconEffectLength, hue: McHue.indigo),
                McStat(value: '$ingots', label: mcPretty(ingot), hue: McHue.amber),
              ],
            ),
            McPanel(
              child: SizedBox(
                height: 230,
                child: CustomPaint(
                  painter: _PyramidPainter(tier: _tier, color: mineralColor, beam: luma.accent),
                  size: Size.infinite,
                ),
              ),
            ),
            McPanel(
              title: t.mcBeaconEffectsAt(_tier),
              icon: Icons.auto_awesome_rounded,
              child: Column(
                children: [
                  for (final (tier, name, text, icon) in _effects(t))
                    Opacity(
                      opacity: tier <= _tier ? 1 : 0.4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: tier <= _tier ? luma.accent : luma.textMuted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                                  Text(text, style: TextStyle(color: luma.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            McTag(tier <= _tier ? t.mcBeaconUnlocked : t.mcBeaconTierN(tier), hue: tier <= _tier ? McHue.green : McHue.indigo),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            McPanel(
              title: t.mcBeaconHow,
              icon: Icons.info_outline_rounded,
              child: Text(
                t.mcBeaconHowBody(range, 9 + 2 * _tier, mcPretty(id)),
                style: TextStyle(color: luma.textSecondary, fontSize: 13, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PyramidPainter extends CustomPainter {
  _PyramidPainter({required this.tier, required this.color, required this.beam});

  final int tier;
  final Color color;
  final Color beam;

  @override
  void paint(Canvas canvas, Size size) {
    final maxSide = 2 * 4 + 1;
    final cell = (size.width * 0.8 / maxSide).clamp(6.0, 26.0);
    final baseY = size.height - 8;
    final cx = size.width / 2;
    final fill = Paint();
    final edge = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke;
    for (var t = tier; t >= 1; t--) {
      final layer = tier - t;
      final side = 2 * t + 1;
      final y = baseY - (layer + 1) * cell;
      for (var i = 0; i < side; i++) {
        final x = cx - side * cell / 2 + i * cell;
        final r = Rect.fromLTWH(x, y, cell, cell);
        fill.color = Color.lerp(color, Colors.black, 0.08 * (i % 2))!;
        canvas.drawRect(r, fill);
        canvas.drawRect(r, edge);
      }
    }
    final top = baseY - (tier + 1) * cell;
    final beaconRect = Rect.fromLTWH(cx - cell / 2, top, cell, cell);
    canvas.drawRect(
      Rect.fromLTWH(cx - cell * 0.18, 0, cell * 0.36, top),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [beam.withValues(alpha: 0.85), beam.withValues(alpha: 0.05)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, top)),
    );
    canvas.drawRect(beaconRect, Paint()..color = const Color(0xFF7FE6F2));
    canvas.drawRect(beaconRect.deflate(cell * 0.25), Paint()..color = Colors.white);
    canvas.drawRect(beaconRect, edge);
  }

  @override
  bool shouldRepaint(_PyramidPainter old) =>
      old.tier != tier || old.color != color || old.beam != beam;
}
