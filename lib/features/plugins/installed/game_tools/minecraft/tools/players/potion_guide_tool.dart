import 'package:flutter/material.dart';

import '../../../../../../../app/widgets.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/potions_data.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_style.dart';

String _description(L t, String id) => switch (id) {
  'swiftness' => t.mcPotionDescSwiftness,
  'leaping' => t.mcPotionDescLeaping,
  'strength' => t.mcPotionDescStrength,
  'healing' => t.mcPotionDescHealing,
  'regeneration' => t.mcPotionDescRegeneration,
  'poison' => t.mcPotionDescPoison,
  'fire_resistance' => t.mcPotionDescFireResistance,
  'water_breathing' => t.mcPotionDescWaterBreathing,
  'night_vision' => t.mcPotionDescNightVision,
  'slow_falling' => t.mcPotionDescSlowFalling,
  'turtle_master' => t.mcPotionDescTurtleMaster,
  'wind_charged' => t.mcPotionDescWindCharged,
  'weaving' => t.mcPotionDescWeaving,
  'oozing' => t.mcPotionDescOozing,
  'infested' => t.mcPotionDescInfested,
  'slowness' => t.mcPotionDescSlowness,
  'harming' => t.mcPotionDescHarming,
  'invisibility' => t.mcPotionDescInvisibility,
  'weakness' => t.mcPotionDescWeakness,
  _ => '',
};

/// Every brewable potion: what goes in, what comes out, how long it lasts and
/// what it upgrades or corrupts into.
class PotionGuideTool extends StatefulWidget {
  const PotionGuideTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<PotionGuideTool> createState() => _PotionGuideToolState();
}

class _PotionGuideToolState extends State<PotionGuideTool> {
  McPotion _potion = kMcPotionGuide.first;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final list = kMcPotionGuide
        .where(
          (p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.ingredient.replaceAll('_', ' ').contains(q) ||
              p.effect.replaceAll('_', ' ').contains(q),
        )
        .toList();
    final picker = McFormColumn(
      gap: 10,
      children: [
        McTextField(
          hint: L.of(context).mcPotionSearch,
          prefixIcon: Icons.search_rounded,
          onChanged: (v) => setState(() => _query = v),
        ),
        McPanel(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              for (final p in list)
                _PotionTile(
                  potion: p,
                  selected: p == _potion,
                  onTap: () => setState(() => _potion = p),
                ),
            ],
          ),
        ),
      ],
    );
    final detail = _PotionDetail(
      potion: _potion,
      onOpen: (id) {
        final next = kMcPotionGuide.where((p) => p.id == id).firstOrNull;
        if (next != null) setState(() => _potion = next);
      },
    );
    return widget.host.frame(
      context,
      child: context.isPhoneWidth
          ? McFormColumn(children: [detail, picker])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 280, child: picker),
                const SizedBox(width: 20),
                Expanded(child: detail),
              ],
            ),
    );
  }
}

class _PotionTile extends StatelessWidget {
  const _PotionTile({
    required this.potion,
    required this.selected,
    required this.onTap,
  });

  final McPotion potion;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: selected ? luma.accentSubtle : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 26,
                child: CustomPaint(painter: McBottlePainter(potion.color)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      potion.name,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    Text(
                      mcPretty(potion.ingredient),
                      style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (!potion.positive)
                Icon(Icons.remove_circle_outline_rounded, size: 14, color: luma.danger),
            ],
          ),
        ),
      ),
    );
  }
}

class _PotionDetail extends StatelessWidget {
  const _PotionDetail({required this.potion, required this.onOpen});

  final McPotion potion;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final p = potion;
    final chain = <(String, String?)>[
      ('Water Bottle', null),
      if (p.base == 'awkward') ...[
        ('Awkward Potion', 'nether_wart'),
        ('Potion of ${p.name}', p.ingredient),
      ] else if (p.base == 'water')
        ('Potion of ${p.name}', p.ingredient)
      else ...[
        ('Awkward Potion', 'nether_wart'),
        (
          'Potion of ${kMcPotionGuide.firstWhere((x) => x.id == p.base).name}',
          kMcPotionGuide.firstWhere((x) => x.id == p.base).ingredient,
        ),
        ('Potion of ${p.name}', p.ingredient),
      ],
    ];
    final rows = <(String, String, int?)>[
      ('Potion of ${p.name}', '', p.duration),
      if (p.extended != null) (t.mcPotionExtended, t.mcPotionRedstone, p.extended),
      if (p.strong != null) (t.mcPotionLevel2, t.mcPotionGlowstone, p.strongDuration),
    ];
    return McFormColumn(
      children: [
        McPanel(
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 76,
                child: CustomPaint(painter: McBottlePainter(p.color)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        McHeading('Potion of ${p.name}', size: 21),
                        McTag(
                          p.positive ? t.mcPotionBeneficial : t.mcPotionHarmful,
                          hue: p.positive ? McHue.green : McHue.rose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _description(t, p.id),
                      style: TextStyle(color: luma.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.mcPotionEffect(mcPretty(p.effect)),
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        McPanel(
          title: t.mcPotionBrewing,
          icon: Icons.science_rounded,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: [
              for (var i = 0; i < chain.length; i++) ...[
                if (chain[i].$2 != null) ...[
                  Icon(Icons.arrow_forward_rounded, size: 15, color: luma.textMuted),
                  McTag('+ ${mcPretty(chain[i].$2!)}', hue: McHue.violet),
                  Icon(Icons.arrow_forward_rounded, size: 15, color: luma.textMuted),
                ],
                _Step(label: chain[i].$1, last: i == chain.length - 1),
              ],
            ],
          ),
        ),
        McPanel(
          title: t.mcPotionDurations,
          icon: Icons.timer_outlined,
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.4),
              1: FlexColumnWidth(),
              2: FlexColumnWidth(),
              3: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  for (final h in ['', t.mcPotionDrinkSplash, t.mcPotionLingering, t.mcPotionArrow])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        h,
                        style: TextStyle(
                          color: luma.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              for (final (label, how, seconds) in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                          if (how.isNotEmpty)
                            Text(how, style: TextStyle(color: luma.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    _Cell(mcDuration(seconds ?? 0, instant: t.mcPotionInstant)),
                    _Cell(mcDuration((seconds ?? 0) ~/ 4, instant: t.mcPotionInstant)),
                    _Cell(mcDuration((seconds ?? 0) ~/ 8, instant: t.mcPotionInstant)),
                  ],
                ),
            ],
          ),
        ),
        McPanel(
          title: t.mcPotionVariants,
          icon: Icons.alt_route_rounded,
          child: McFormColumn(
            gap: 8,
            children: [
              _Variant(
                icon: Icons.sports_handball_rounded,
                text: t.mcPotionSplash,
              ),
              _Variant(
                icon: Icons.cloud_rounded,
                text: t.mcPotionLingeringNote,
              ),
              _Variant(
                icon: Icons.arrow_upward_rounded,
                text: t.mcPotionArrows,
              ),
              if (p.corruptsInto != null)
                InkWell(
                  onTap: () => onOpen(p.corruptsInto!),
                  child: _Variant(
                    icon: Icons.bug_report_rounded,
                    text: t.mcPotionCorrupts(kMcPotionGuide.firstWhere((x) => x.id == p.corruptsInto).name),
                  ),
                ),
            ],
          ),
        ),
        Text(
          t.mcPotionFuel,
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: mcMono(context, size: 12.5),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.last});

  final String label;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: last ? luma.accentSubtle : luma.surfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: last ? luma.accent : luma.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: last ? luma.accent : luma.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Variant extends StatelessWidget {
  const _Variant({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: luma.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

/// A round-bottomed bottle filled with [color].
class McBottlePainter extends CustomPainter {
  McBottlePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final neck = Rect.fromLTWH(w * 0.38, h * 0.04, w * 0.24, h * 0.26);
    final body = Rect.fromCircle(
      center: Offset(w / 2, h * 0.64),
      radius: w * 0.42,
    );
    final glass = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final outline = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05;
    canvas.drawRRect(RRect.fromRectAndRadius(neck, Radius.circular(w * 0.04)), glass);
    canvas.drawOval(body, glass);
    canvas.save();
    canvas.clipPath(Path()..addOval(body));
    canvas.drawRect(
      Rect.fromLTRB(body.left, body.top + body.height * 0.28, body.right, body.bottom),
      Paint()..color = color,
    );
    canvas.restore();
    canvas.drawOval(body, outline);
    canvas.drawRRect(RRect.fromRectAndRadius(neck, Radius.circular(w * 0.04)), outline);
    canvas.drawOval(
      Rect.fromLTWH(body.left + w * 0.16, body.top + h * 0.16, w * 0.14, h * 0.1),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.34, 0, w * 0.32, h * 0.07),
      Paint()..color = const Color(0xFF8B5A2B),
    );
  }

  @override
  bool shouldRepaint(McBottlePainter old) => old.color != color;
}
