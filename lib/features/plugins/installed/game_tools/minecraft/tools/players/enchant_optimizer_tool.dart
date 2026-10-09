import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/enchant_optimizer.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_style.dart';

/// Picks an item and the enchantments wanted on it, then searches every
/// anvil order for the cheapest one that never hits "Too Expensive!".
class EnchantOptimizerTool extends StatefulWidget {
  const EnchantOptimizerTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<EnchantOptimizerTool> createState() => _EnchantOptimizerToolState();
}

class _EnchantOptimizerToolState extends State<EnchantOptimizerTool> {
  McEnchantable _item = kMcEnchantables.first;
  final Map<String, int> _chosen = {};
  int _priorWork = 0;
  bool _survival = true;

  McAnvilPlan? _plan;
  String? _problem;

  void _pickItem(McEnchantable item) {
    setState(() {
      _item = item;
      _chosen.removeWhere((id, _) => !item.enchants.contains(id));
      _solve();
    });
  }

  void _toggle(McEnchant e, int level) {
    setState(() {
      if (_chosen[e.id] == level) {
        _chosen.remove(e.id);
      } else {
        _chosen.removeWhere(
          (id, _) => kMcEnchants[id]!.conflictsWith(e) && id != e.id,
        );
        _chosen[e.id] = level;
      }
      _solve();
    });
  }

  void _maxAll() {
    setState(() {
      for (final id in _item.enchants) {
        final e = kMcEnchants[id]!;
        if (e.curse || _chosen.containsKey(id)) continue;
        if (_chosen.keys.any((c) => kMcEnchants[c]!.conflictsWith(e))) {
          continue;
        }
        _chosen[id] = e.maxLevel;
      }
      _solve();
    });
  }

  void _solve() {
    final t = L.of(context);
    _problem = null;
    _plan = null;
    final books = [
      for (final entry in _chosen.entries)
        McBook(kMcEnchants[entry.key]!, entry.value),
    ];
    if (books.isEmpty) return;
    if (books.length == 1 && _item.id == 'enchanted_book') {
      _problem = t.mcEnchNeedTwo;
      return;
    }
    _plan = mcOptimizeAnvil(
      books,
      itemPriorWork: _priorWork,
      limit: _survival ? 39 : null,
      targetIsBook: _item.id == 'enchanted_book',
    );
    if (_plan == null) {
      _problem = t.mcEnchTooExpensive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return widget.host.frame(
      context,
      child: McSplit(
        controlsWidth: 420,
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcEnchItem,
              icon: Icons.handyman_rounded,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in kMcEnchantables)
                    _ItemChip(
                      item: item,
                      selected: item == _item,
                      onTap: () => _pickItem(item),
                    ),
                ],
              ),
            ),
            McPanel(
              title: t.mcEnchEnchantments,
              icon: Icons.auto_fix_high_rounded,
              trailing: TextButton(
                onPressed: _maxAll,
                child: Text(t.mcEnchMaxAll),
              ),
              child: Column(
                children: [
                  for (final id in _item.enchants)
                    _EnchantRow(
                      enchant: kMcEnchants[id]!,
                      level: _chosen[id],
                      blockedBy: _chosen.keys
                          .where(
                            (c) =>
                                c != id &&
                                kMcEnchants[c]!.conflictsWith(kMcEnchants[id]!),
                          )
                          .firstOrNull,
                      onLevel: (level) => _toggle(kMcEnchants[id]!, level),
                    ),
                ],
              ),
            ),
            McPanel(
              title: t.mcEnchAnvilSettings,
              icon: Icons.tune_rounded,
              child: McFormColumn(
                gap: 8,
                children: [
                  if (_item.id != 'enchanted_book')
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.mcEnchPriorUses,
                            style: TextStyle(
                              color: context.luma.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        McStepper(
                          value: _priorWork,
                          max: 6,
                          onChanged: (v) => setState(() {
                            _priorWork = v;
                            _solve();
                          }),
                        ),
                      ],
                    ),
                  McSwitch(
                    label: t.mcEnchSurvivalLimit,
                    detail: t.mcEnchSurvivalLimitDetail,
                    value: _survival,
                    onChanged: (v) => setState(() {
                      _survival = v;
                      _solve();
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
        result: _Result(
          plan: _plan,
          problem: _problem,
          itemLabel: _item.localLabel(t),
          bookTarget: _item.id == 'enchanted_book',
        ),
      ),
    );
  }
}

class _ItemChip extends StatelessWidget {
  const _ItemChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final McEnchantable item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: selected ? luma.accentSubtle : luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: selected ? luma.accent : luma.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _iconFor(item.id),
                size: 15,
                color: selected ? luma.accent : luma.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                item.localLabel(L.of(context)),
                style: TextStyle(
                  color: selected ? luma.accent : luma.textPrimary,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String id) {
    if (id.contains('sword') || id.contains('spear')) {
      return Icons.colorize_rounded;
    }
    if (id.contains('axe') || id.contains('hoe') || id.contains('shovel')) {
      return Icons.carpenter_rounded;
    }
    if (id.contains('helmet') ||
        id.contains('chestplate') ||
        id.contains('leggings') ||
        id.contains('boots')) {
      return Icons.shield_moon_rounded;
    }
    return switch (id) {
      'bow' || 'crossbow' => Icons.architecture_rounded,
      'trident' || 'mace' => Icons.gavel_rounded,
      'fishing_rod' || 'carrot_on_a_stick' => Icons.phishing_rounded,
      'elytra' => Icons.paragliding_rounded,
      'shield' => Icons.shield_rounded,
      'enchanted_book' => Icons.menu_book_rounded,
      _ => Icons.build_rounded,
    };
  }
}

class _EnchantRow extends StatelessWidget {
  const _EnchantRow({
    required this.enchant,
    required this.level,
    required this.blockedBy,
    required this.onLevel,
  });

  final McEnchant enchant;
  final int? level;
  final String? blockedBy;
  final ValueChanged<int> onLevel;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final blocked = blockedBy != null && level == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mcPretty(enchant.id),
                  style: TextStyle(
                    color: enchant.curse
                        ? luma.danger
                        : blocked
                        ? luma.textMuted
                        : luma.textPrimary,
                    fontSize: 13,
                    fontWeight: level != null ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (blocked)
                  Text(
                    L.of(context).mcEnchConflicts(mcPretty(blockedBy!)),
                    style: TextStyle(color: luma.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          for (var l = 1; l <= enchant.maxLevel; l++)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _LevelButton(
                label: mcRoman(l),
                selected: level == l,
                dim: blocked,
                onTap: () => onLevel(l),
              ),
            ),
        ],
      ),
    );
  }
}

class _LevelButton extends StatelessWidget {
  const _LevelButton({
    required this.label,
    required this.selected,
    required this.dim,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? luma.accent : luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: BorderSide(color: selected ? luma.accent : luma.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 28,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? luma.onAccent
                      : dim
                      ? luma.textMuted
                      : luma.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.plan,
    required this.problem,
    required this.itemLabel,
    required this.bookTarget,
  });

  final McAnvilPlan? plan;
  final String? problem;
  final String itemLabel;
  final bool bookTarget;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final plan = this.plan;
    if (problem != null) {
      return McPanel(
        child: McHint(
          icon: Icons.warning_amber_rounded,
          title: t.mcEnchNoOrder,
          body: problem,
        ),
      );
    }
    if (plan == null) {
      return McPanel(
        child: McHint(
          icon: Icons.auto_fix_high_rounded,
          title: t.mcEnchPickSome,
          body: t.mcEnchPickSomeBody,
        ),
      );
    }
    return McFormColumn(
      children: [
        McStatRow(
          stats: [
            McStat(
              value: '${plan.totalLevels}',
              label: t.mcEnchLevelsTotal,
              hue: McHue.violet,
            ),
            McStat(
              value: '${plan.steps.length}',
              label: t.mcEnchAnvilUses(plan.steps.length),
              hue: McHue.indigo,
            ),
            McStat(
              value: '${plan.maxStep}',
              label: t.mcEnchMostExpensive,
              hue: plan.maxStep > 39 ? McHue.rose : McHue.mint,
            ),
            McStat(
              value: '${plan.totalXp}',
              label: t.mcEnchXpPoints,
              hue: McHue.green,
            ),
          ],
        ),
        McPanel(
          title: t.mcEnchSteps,
          icon: Icons.format_list_numbered_rounded,
          child: Column(
            children: [
              for (var i = 0; i < plan.steps.length; i++)
                _StepRow(
                  index: i + 1,
                  step: plan.steps[i],
                  itemLabel: itemLabel,
                  bookTarget: bookTarget,
                ),
            ],
          ),
        ),
        Text(
          t.mcEnchFootnote(plan.finalPenalty, mcPenaltyCost(plan.finalPenalty)),
          style: TextStyle(color: luma.textMuted, fontSize: 12, height: 1.45),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.step,
    required this.itemLabel,
    required this.bookTarget,
  });

  final int index;
  final McAnvilStep step;
  final String itemLabel;
  final bool bookTarget;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: TextStyle(
                color: luma.accent,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                _NodeChip(node: step.target, itemLabel: itemLabel, bookTarget: bookTarget),
                Icon(Icons.add_rounded, size: 16, color: luma.textMuted),
                _NodeChip(node: step.sacrifice, itemLabel: itemLabel, bookTarget: bookTarget),
              ],
            ),
          ),
          const SizedBox(width: 8),
          McTag(
            L.of(context).mcEnchLevelsShort(step.cost),
            hue: step.cost > 39 ? McHue.rose : McHue.green,
          ),
        ],
      ),
    );
  }
}

class _NodeChip extends StatelessWidget {
  const _NodeChip({
    required this.node,
    required this.itemLabel,
    required this.bookTarget,
  });

  final McAnvilNode node;
  final String itemLabel;
  final bool bookTarget;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final hasItem = _containsItem(node);
    final enchants = node.books
        .map((b) => '${mcPretty(b.enchant.id)} ${mcRoman(b.level)}')
        .join(', ');
    final label = hasItem
        ? (enchants.isEmpty ? itemLabel : '$itemLabel ($enchants)')
        : L.of(context).mcEnchBook(enchants);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: hasItem ? McHue.violet.color.withValues(alpha: 0.12) : luma.surfaceHover,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasItem ? Icons.construction_rounded : Icons.menu_book_rounded,
            size: 14,
            color: hasItem ? McHue.violet.color : luma.textSecondary,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: luma.textPrimary, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  static bool _containsItem(McAnvilNode node) => switch (node) {
    McItemLeaf() => true,
    McBookLeaf() => false,
    McMerge(:final target, :final sacrifice) =>
      _containsItem(target) || _containsItem(sacrifice),
  };
}
