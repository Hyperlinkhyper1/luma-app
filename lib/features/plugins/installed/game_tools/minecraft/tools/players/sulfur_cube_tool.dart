import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/mc_data_types.dart';
import '../../data/sulfur_cube_data.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_style.dart';

(String, String) _titles(L t, String id) => switch (id) {
  'regular' => (t.mcCubeRegular, t.mcCubeRegularBlocks),
  'bouncy' => (t.mcCubeBouncy, t.mcCubeBouncyBlocks),
  'slow_bouncy' => (t.mcCubeSlowBouncy, t.mcCubeSlowBouncyBlocks),
  'slow_flat' => (t.mcCubeSlowFlat, t.mcCubeSlowFlatBlocks),
  'fast_flat' => (t.mcCubeFastFlat, t.mcCubeFastFlatBlocks),
  'light' => (t.mcCubeLight, t.mcCubeLightBlocks),
  'fast_sliding' => (t.mcCubeFastSliding, t.mcCubeFastSlidingBlocks),
  'slow_sliding' => (t.mcCubeSlowSliding, t.mcCubeSlowSlidingBlocks),
  'high_resistance' => (t.mcCubeHighResistance, t.mcCubeHighResistanceBlocks),
  'sticky' => (t.mcCubeSticky, t.mcCubeStickyBlocks),
  'explosive' => (t.mcCubeExplosive, t.mcCubeExplosiveBlocks),
  'hot' => (t.mcCubeHot, t.mcCubeHotBlocks),
  _ => (mcPretty(id), ''),
};

const _hues = {
  'regular': McHue.indigo,
  'bouncy': McHue.orange,
  'slow_bouncy': McHue.violet,
  'slow_flat': McHue.sky,
  'fast_flat': McHue.green,
  'light': McHue.mint,
  'fast_sliding': McHue.sky,
  'slow_sliding': McHue.rose,
  'high_resistance': McHue.violet,
  'sticky': McHue.amber,
  'explosive': McHue.rose,
  'hot': McHue.orange,
};

String _damageLabel(L t, String id) => switch (id) {
  'arrow' => t.mcCubeDmgArrow,
  'cactus' => t.mcCubeDmgCactus,
  'dry_out' => t.mcCubeDmgDryOut,
  'fall' => t.mcCubeDmgFall,
  'falling_anvil' => t.mcCubeDmgFallingAnvil,
  'falling_block' => t.mcCubeDmgFallingBlock,
  'falling_stalactite' => t.mcCubeDmgFallingStalactite,
  'freeze' => t.mcCubeDmgFreeze,
  'mace_smash' => t.mcCubeDmgMaceSmash,
  'hot_floor' => t.mcCubeDmgHotFloor,
  'mob_attack' => t.mcCubeDmgMobAttack,
  'mob_attack_no_aggro' => t.mcCubeDmgMobAttackNoAggro,
  'mob_projectile' => t.mcCubeDmgMobProjectile,
  'player_attack' => t.mcCubeDmgPlayerAttack,
  'spear' => t.mcCubeDmgSpear,
  'spit' => t.mcCubeDmgSpit,
  'stalagmite' => t.mcCubeDmgStalagmite,
  'sting' => t.mcCubeDmgSting,
  'sulfur_cube_hot' => t.mcCubeDmgSulfurCubeHot,
  'sweet_berry_bush' => t.mcCubeDmgSweetBerryBush,
  'thrown' => t.mcCubeDmgThrown,
  'trident' => t.mcCubeDmgTrident,
  'wind_charge' => t.mcCubeDmgWindCharge,
  _ => mcPretty(id),
};

String _mobility(L t, double kr) => kr <= -1.5
    ? t.mcCubeVeryEasyShove
    : kr < 0
    ? t.mcCubeShovesEasily
    : kr < 0.6
    ? t.mcCubeResists
    : t.mcCubeHardToBudge;

String _bounce(L t, double b) => b >= 0.9
    ? t.mcCubeSuperBouncy
    : b >= 0.5
    ? t.mcCubeBouncyDesc
    : b >= 0.3
    ? t.mcCubeLittleBouncy
    : b > 0
    ? t.mcCubeBarely
    : t.mcCubeNoBounce;

String _grip(L t, double f) => f >= 0.5
    ? t.mcCubeSticks
    : f >= 0
    ? t.mcCubeGrippy
    : f > -0.9
    ? t.mcCubeSlidesBit
    : t.mcCubeSlidesIce;

String _drag(L t, double d) => d > 0
    ? t.mcCubeFloaty
    : d > -0.8
    ? t.mcCubeDamps
    : d > -0.95
    ? t.mcCubeHolds
    : t.mcCubeKeepsFlying;

/// The sulfur cube from the Sulfur Caves: a mob that swallows a block and
/// takes on its physics. Every number comes from the game's archetype data.
class SulfurCubeTool extends StatefulWidget {
  const SulfurCubeTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<SulfurCubeTool> createState() => _SulfurCubeToolState();
}

class _SulfurCubeToolState extends State<SulfurCubeTool> {
  McCubeArchetype _selected = kMcCubeArchetypes.first;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final q = _query.trim().toLowerCase().replaceAll(' ', '_');
    final hits = q.length < 2
        ? const <(String, McCubeArchetype)>[]
        : [
            for (final a in kMcCubeArchetypes)
              for (final b in a.blocks)
                if (b.contains(q)) (b, a),
          ];
    final total = kMcCubeArchetypes.fold(0, (s, a) => s + a.blocks.length);
    return widget.host.frame(
      context,
      child: McFormColumn(
        children: [
          McGrid(
            minTileWidth: 200,
            spacing: 10,
            children: [
              for (final a in kMcCubeArchetypes)
                _ArchetypeCard(
                  archetype: a,
                  selected: a == _selected,
                  onTap: () => setState(() => _selected = a),
                ),
            ],
          ),
          _Detail(archetype: _selected),
          McPanel(
            title: t.mcCubeEatsTitle,
            icon: Icons.search_rounded,
            child: McFormColumn(
              gap: 10,
              children: [
                McTextField(
                  hint: t.mcCubeSearchHint(total),
                  prefixIcon: Icons.search_rounded,
                  onChanged: (v) => setState(() => _query = v),
                ),
                if (hits.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (block, a) in hits.take(60))
                        ActionChip(
                          label: Text('${mcPretty(block)} → ${_titles(t, a.id).$1}'),
                          labelStyle: TextStyle(color: luma.textPrimary, fontSize: 12),
                          backgroundColor: _hues[a.id]!.color.withValues(alpha: 0.12),
                          side: BorderSide.none,
                          onPressed: () => setState(() => _selected = a),
                        ),
                    ],
                  )
                else if (q.length >= 2)
                  Text(
                    t.mcCubeNotSwallowable,
                    style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                  ),
              ],
            ),
          ),
          McGrid(
            minTileWidth: 320,
            children: [
              McPanel(
                title: t.mcCubeMeet,
                icon: Icons.pets_rounded,
                child: McFormColumn(
                  gap: 8,
                  children: [
                    _Fact(t.mcCubeSpawnsIn, t.mcCubeSpawnsInValue),
                    _Fact(t.mcCubeHealth, t.mcCubeHealthValue),
                    _Fact(t.mcCubeOnDeath, t.mcCubeOnDeathValue),
                    _Fact(t.mcCubeExperience, t.mcCubeExperienceValue),
                    _Fact(t.mcCubeFood, t.mcCubeFoodValue),
                    _Fact(t.mcCubeHome, t.mcCubeHomeValue),
                    _Fact(t.mcCubeChange, t.mcCubeChangeValue),
                    _Fact(t.mcCubeTempt, t.mcCubeTemptValue),
                  ],
                ),
              ),
              McPanel(
                title: t.mcCubeShrugs,
                icon: Icons.shield_outlined,
                child: McFormColumn(
                  gap: 10,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final d in kMcCubeImmunities)
                          McTag(_damageLabel(t, d), hue: McHue.mint),
                      ],
                    ),
                    Text(
                      t.mcCubeShrugsNote,
                      style: TextStyle(color: luma.textSecondary, fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          McPanel(
            title: t.mcCubeHow,
            icon: Icons.info_outline_rounded,
            child: Text(
              t.mcCubeHowBody,
              style: TextStyle(color: luma.textSecondary, fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchetypeCard extends StatelessWidget {
  const _ArchetypeCard({
    required this.archetype,
    required this.selected,
    required this.onTap,
  });

  final McCubeArchetype archetype;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final hue = _hues[archetype.id]!;
    final (title, subtitle) = _titles(t, archetype.id);
    final tags = <String>[
      if (archetype.explosionPower != null) t.mcCubeExplodes,
      if (archetype.contactDamage != null) t.mcCubeBurns,
      if (archetype.buoyant) t.mcCubeFloats,
      _bounce(t, archetype.bounciness),
    ];
    return Material(
      color: selected ? hue.color.withValues(alpha: 0.12) : luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? hue.color : luma.border, width: selected ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: hue.color,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(color: hue.color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${archetype.blocks.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tags.toSet().join(' · '),
                      style: TextStyle(color: hue.color, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.archetype});

  final McCubeArchetype archetype;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final a = archetype;
    final hue = _hues[a.id]!;
    final (title, _) = _titles(t, a.id);
    return McPanel(
      title: t.mcCubeBehaviour(title),
      icon: Icons.check_box_outline_blank_rounded,
      trailing: McTag(t.mcCubeBlockCount(a.blocks.length), hue: hue),
      child: McFormColumn(
        gap: 12,
        children: [
          McGrid(
            minTileWidth: 150,
            spacing: 10,
            children: [
              _Trait(t.mcCubeMobility, _mobility(t, a.knockbackResistance), t.mcCubeKbRes(_signed(a.knockbackResistance))),
              _Trait(t.mcCubeBounce, _bounce(t, a.bounciness), t.mcCubeBounciness('${a.bounciness}')),
              _Trait(t.mcCubeGrip, _grip(t, a.friction), t.mcCubeFriction(_percent(a.friction))),
              _Trait(t.mcCubeAirDrag, _drag(t, a.airDrag), t.mcCubeAirDragValue(_percent(a.airDrag))),
              _Trait(
                t.mcCubeKnockback,
                '${a.knockbackHorizontal.toStringAsFixed(2)} → · ${a.knockbackVertical.toStringAsFixed(2)} ↑',
                t.mcCubeKnockbackDetail,
              ),
              _Trait(t.mcCubePush, t.mcCubePushValue(_trim(a.pushCooldown)), t.mcCubePushDetail),
              if (a.explosionPower != null)
                _Trait(
                  t.mcCubeExplosion,
                  t.mcCubePower(_trim(a.explosionPower!)),
                  '${t.mcCubeFuse('${(a.explosionFuse ?? 0) / 20}')} · ${a.explosionFire ? t.mcCubeSetsFire : t.mcCubeNoFire}',
                ),
              if (a.contactDamage != null)
                _Trait(t.mcCubeContact, t.mcCubeBurnDamage(_trim(a.contactDamage!)), t.mcCubeWhenTouched),
              _Trait(t.mcCubeWater, a.buoyant ? t.mcCubeFloats : t.mcCubeSinks, a.buoyant ? t.mcCubeBuoyant : t.mcCubeNotBuoyant),
            ],
          ),
          if (a.groups.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final g in a.groups) McTag('#$g', hue: hue)],
            ),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final b in a.blocks)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: luma.surfaceHover,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(mcPretty(b), style: TextStyle(color: luma.textSecondary, fontSize: 11.5)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  static String _signed(double v) => v > 0 ? '+${_trim(v)}' : _trim(v);
  static String _percent(double v) =>
      '${v >= 0 ? '+' : ''}${(v * 100).round()}%';
}

class _Trait extends StatelessWidget {
  const _Trait(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: luma.surfaceHover,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(color: luma.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(detail, style: TextStyle(color: luma.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(color: luma.textMuted, fontSize: 12)),
        ),
        Expanded(
          child: Text(value, style: TextStyle(color: luma.textPrimary, fontSize: 12.5)),
        ),
      ],
    );
  }
}
