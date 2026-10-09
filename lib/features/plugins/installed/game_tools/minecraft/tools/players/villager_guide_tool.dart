import 'package:flutter/material.dart';

import '../../../../../../../app/widgets.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/mc_data_types.dart';
import '../../data/mc_registries_data.dart';
import '../../data/villager_trades_data.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_style.dart';

const _workstations = {
  'armorer': 'blast_furnace',
  'butcher': 'smoker',
  'cartographer': 'cartography_table',
  'cleric': 'brewing_stand',
  'farmer': 'composter',
  'fisherman': 'barrel',
  'fletcher': 'fletching_table',
  'leatherworker': 'cauldron',
  'librarian': 'lectern',
  'mason': 'stonecutter',
  'shepherd': 'loom',
  'toolsmith': 'smithing_table',
  'weaponsmith': 'grindstone',
};

List<String> _levelNames(L t) => [t.mcVillNovice, t.mcVillApprentice, t.mcVillJourneyman, t.mcVillExpert, t.mcVillMaster];

/// A generated trade note, in the reader's language.
String _note(L t, String code) {
  final parts = code.split(':');
  return switch (parts.first) {
    'enchantLevels' => t.mcVillNoteEnchant(parts[1], parts[2]),
    'enchantRandom' => t.mcVillNoteRandomEnchant,
    'map' => t.mcVillNoteMap(mcPretty(parts[1].replaceAll(RegExp(r'^on_|_maps\$'), ''))),
    'explorerMap' => t.mcVillNoteExplorer,
    'dyes' => t.mcVillNoteDyes,
    'stew' => t.mcVillNoteStew,
    'randomPotion' => t.mcVillNoteRandomPotion,
    'potion' => t.mcVillNotePotion(mcPretty(parts[1])),
    'treasureDouble' => t.mcVillNoteTreasure,
    'variants' => t.mcVillNoteVariants(parts[1].split(',').map(mcPretty).join(', ')),
    'priceScales' => t.mcVillNotePrice,
    _ => code,
  };
}

/// Experience a villager needs to reach each level, from the one before.
const _levelXp = [0, 10, 70, 150, 250];

IconData _iconFor(String owner) => switch (owner) {
  'armorer' => Icons.shield_rounded,
  'butcher' => Icons.set_meal_rounded,
  'cartographer' => Icons.map_rounded,
  'cleric' => Icons.science_rounded,
  'farmer' => Icons.agriculture_rounded,
  'fisherman' => Icons.phishing_rounded,
  'fletcher' => Icons.architecture_rounded,
  'leatherworker' => Icons.checkroom_rounded,
  'librarian' => Icons.menu_book_rounded,
  'mason' => Icons.foundation_rounded,
  'shepherd' => Icons.texture_rounded,
  'toolsmith' => Icons.handyman_rounded,
  'weaponsmith' => Icons.colorize_rounded,
  'wandering_trader' => Icons.hiking_rounded,
  _ => Icons.person_rounded,
};

/// Every villager trade straight from the game's trade data: what each
/// profession buys and sells at each level, and the odds of each offer.
class VillagerGuideTool extends StatefulWidget {
  const VillagerGuideTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<VillagerGuideTool> createState() => _VillagerGuideToolState();
}

class _VillagerGuideToolState extends State<VillagerGuideTool> {
  McTradeOwner _owner = kMcVillagerTrades.firstWhere(
    (o) => o.id == 'librarian',
    orElse: () => kMcVillagerTrades.first,
  );
  String _query = '';

  bool _matches(McTrade t) {
    final q = _query.trim().toLowerCase().replaceAll(' ', '_');
    if (q.isEmpty) return true;
    return t.wants.contains(q) ||
        t.gives.contains(q) ||
        (t.extra?.contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhoneWidth;
    final searching = _query.trim().isNotEmpty;
    final list = _OwnerList(
      selected: searching ? null : _owner,
      horizontal: phone,
      onSelect: (o) => setState(() {
        _owner = o;
        _query = '';
      }),
    );
    final search = McTextField(
      hint: L.of(context).mcVillSearch,
      prefixIcon: Icons.search_rounded,
      onChanged: (v) => setState(() => _query = v),
    );
    final body = searching
        ? _SearchResults(matches: _matches)
        : _OwnerDetail(owner: _owner);
    return widget.host.frame(
      context,
      child: phone
          ? McFormColumn(children: [search, list, body])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 230, child: list),
                const SizedBox(width: 20),
                Expanded(child: McFormColumn(children: [search, body])),
              ],
            ),
    );
  }
}

class _OwnerList extends StatelessWidget {
  const _OwnerList({
    required this.selected,
    required this.onSelect,
    required this.horizontal,
  });

  final McTradeOwner? selected;
  final ValueChanged<McTradeOwner> onSelect;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final tiles = [
      for (final o in kMcVillagerTrades)
        Material(
          color: o == selected ? luma.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => onSelect(o),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: horizontal ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Icon(
                    _iconFor(o.id),
                    size: 17,
                    color: o == selected ? luma.accent : luma.textSecondary,
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      mcPretty(o.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: o == selected ? luma.accent : luma.textPrimary,
                        fontWeight: o == selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
    if (horizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: tiles),
      );
    }
    return McPanel(
      padding: const EdgeInsets.all(6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: tiles),
    );
  }
}

class _OwnerDetail extends StatelessWidget {
  const _OwnerDetail({required this.owner});

  final McTradeOwner owner;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final workstation = _workstations[owner.id];
    final trader = owner.id == 'wandering_trader';
    return McFormColumn(
      children: [
        McPanel(
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: McHue.green.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconFor(owner.id), color: McHue.green.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    McHeading(mcPretty(owner.id), size: 20),
                    const SizedBox(height: 3),
                    Text(
                      trader
                          ? t.mcVillTraderBody
                          : t.mcVillBody(mcPretty(workstation ?? 'none')),
                      style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final pool in owner.pools)
          McPanel(
            title: _poolTitle(t, pool),
            trailing: McTag(
              t.mcVillPicks(pool.picks, pool.trades.length),
              hue: McHue.green,
            ),
            child: Column(
              children: [
                for (final trade in pool.trades)
                  _TradeRow(trade: trade, chance: pool.chance),
              ],
            ),
          ),
      ],
    );
  }

  static String _poolTitle(L t, McTradePool pool) {
    final match = RegExp(r'level_(\d)').firstMatch(pool.id);
    if (match == null) return mcPretty(pool.id);
    final level = int.parse(match[1]!);
    final xp = _levelXp[level - 1];
    final title = t.mcVillLevelTitle(level, _levelNames(t)[level - 1]);
    return xp == 0 ? title : '$title  ${t.mcVillLevelXp(xp)}';
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.matches});

  final bool Function(McTrade) matches;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final groups = <Widget>[];
    for (final owner in kMcVillagerTrades) {
      for (final pool in owner.pools) {
        final hits = pool.trades.where(matches).toList();
        if (hits.isEmpty) continue;
        groups.add(
          McPanel(
            title: '${mcPretty(owner.id)} · ${_OwnerDetail._poolTitle(t, pool)}',
            icon: _iconFor(owner.id),
            child: Column(
              children: [
                for (final t in hits) _TradeRow(trade: t, chance: pool.chance),
              ],
            ),
          ),
        );
      }
    }
    if (groups.isEmpty) {
      return McPanel(
        child: McHint(
          icon: Icons.search_off_rounded,
          title: t.mcVillNoTrades,
          body: t.mcVillNoTradesBody,
        ),
      );
    }
    return McFormColumn(children: groups);
  }
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({required this.trade, required this.chance});

  final McTrade trade;
  final double chance;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final price = trade.wantsCount == 0 ? '5–64' : '${trade.wantsCount}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _ItemPill(count: price, item: trade.wants),
                    if (trade.extra != null) ...[
                      Icon(Icons.add_rounded, size: 14, color: luma.textMuted),
                      _ItemPill(count: '${trade.extraCount}', item: trade.extra!),
                    ],
                    Icon(Icons.arrow_forward_rounded, size: 15, color: luma.textMuted),
                    _ItemPill(
                      count: '${trade.givesCount}',
                      item: trade.gives,
                      highlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(chance * 100).round()}%',
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    [
                      if (trade.maxUses != null) t.mcVillUses(trade.maxUses!),
                      if (trade.xp != null) t.mcVillXp(trade.xp!),
                    ].join(' · '),
                    style: TextStyle(color: luma.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          if (trade.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                trade.notes.map((n) => _note(t, n)).join(' · '),
                style: TextStyle(color: luma.textMuted, fontSize: 11.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemPill extends StatelessWidget {
  const _ItemPill({
    required this.count,
    required this.item,
    this.highlight = false,
  });

  final String count;
  final String item;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final emerald = item == 'emerald';
    final color = emerald
        ? McHue.green.color
        : highlight
        ? luma.accent
        : luma.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$count× ',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
            TextSpan(
              text: mcPretty(item),
              style: TextStyle(color: luma.textPrimary),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 12.5),
      ),
    );
  }
}

/// Keeps the registry import used for validation in debug builds: every
/// traded item should be a real item id.
bool debugVillagerItemsKnown() {
  final items = kMcItems.toSet();
  for (final o in kMcVillagerTrades) {
    for (final p in o.pools) {
      for (final t in p.trades) {
        if (!items.contains(t.wants) || !items.contains(t.gives)) return false;
      }
    }
  }
  return true;
}
