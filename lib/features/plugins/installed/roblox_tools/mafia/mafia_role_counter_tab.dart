import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import 'mafia_role_data.dart';

Color _factionColor(LumaPalette luma, MafiaFaction faction) => switch (faction) {
      MafiaFaction.town => luma.success,
      MafiaFaction.neutral => luma.textMuted,
      MafiaFaction.mafia => luma.danger,
      MafiaFaction.veil => luma.accent,
    };

/// Role Counting: pick a lobby size and see exactly which roles are in play
/// and how many of each, sourced from the wiki's per-player-count chart.
class MafiaRoleCounterTab extends StatefulWidget {
  const MafiaRoleCounterTab({super.key});

  @override
  State<MafiaRoleCounterTab> createState() => _MafiaRoleCounterTabState();
}

class _MafiaRoleCounterTabState extends State<MafiaRoleCounterTab> {
  int _players = 10;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final byFaction = rolesForPlayerCount(_players);
    final totalRoles = byFaction.values
        .expand((entries) => entries)
        .fold<int>(0, (a, e) => a + e.value);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Role Counting',
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick how many players are in the lobby to see which roles will '
            'be dealt out.',
            style: TextStyle(color: luma.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          LumaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Players in lobby',
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: luma.accentSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_players',
                        style: TextStyle(
                          color: luma.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Slider(
                  value: _players.toDouble(),
                  min: kMinMafiaPlayers.toDouble(),
                  max: kMaxMafiaPlayers.toDouble(),
                  divisions: kMaxMafiaPlayers - kMinMafiaPlayers,
                  activeColor: luma.accent,
                  label: '$_players',
                  onChanged: (v) => setState(() => _players = v.round()),
                ),
                if (_players < 7)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: luma.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "The wiki flags its data below 7 players as possibly "
                            "inaccurate — treat this count as a rough guide.",
                            style:
                                TextStyle(color: luma.textMuted, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (totalRoles == 0)
            const LumaEmptyState(
              icon: Icons.groups_outlined,
              title: 'No roles for this lobby size',
              subtitle: 'Try a different player count.',
            )
          else
            for (final faction in MafiaFaction.values)
              if (byFaction[faction] != null) ...[
                _FactionSection(
                  faction: faction,
                  entries: byFaction[faction]!,
                ),
                const SizedBox(height: 16),
              ],
        ],
      ),
    );
  }
}

class _FactionSection extends StatelessWidget {
  const _FactionSection({required this.faction, required this.entries});

  final MafiaFaction faction;
  final List<MapEntry<MafiaRole, int>> entries;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = _factionColor(luma, faction);
    final count = entries.fold<int>(0, (a, e) => a + e.value);

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                faction.label,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: luma.background,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: luma.border),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                      color: luma.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Text(
                faction.winCondition,
                style: TextStyle(color: luma.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    entries[i].key.name,
                    style: TextStyle(color: luma.textPrimary, fontSize: 13),
                  ),
                ),
                Container(
                  width: 28,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '×${entries[i].value}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
