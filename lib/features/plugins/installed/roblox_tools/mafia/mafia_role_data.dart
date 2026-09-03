/// Which faction a Mafia role belongs to, and the faction's win condition —
/// shown as a subtitle wherever roles are grouped by faction.
enum MafiaFaction {
  town('Town', 'Wins by eliminating the Mafia'),
  neutral('Neutral', 'Has its own win condition'),
  mafia('Mafia', 'Wins at numerical parity with the Town'),
  veil('Veil', 'Wins by reaching 100% corruption');

  const MafiaFaction(this.label, this.winCondition);
  final String label;
  final String winCondition;
}

class MafiaRole {
  const MafiaRole(this.name, this.faction, this.counts);

  final String name;
  final MafiaFaction faction;

  /// Starting role count for lobby sizes 2..20, index 0 = 2 players.
  final List<int> counts;

  int countFor(int players) => counts[players - kMinMafiaPlayers];
}

const int kMinMafiaPlayers = 2;
const int kMaxMafiaPlayers = 20;

/// Role counts by starting lobby size, sourced from the Roles page of the
/// official Roblox MAFIA wiki (wiki.toplinestudios.gg/wiki/Roles). The wiki
/// itself notes its data below 7 players may be inaccurate.
const List<MafiaRole> kMafiaRoles = [
  MafiaRole('Civilian', MafiaFaction.town,
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 1, 2]),
  MafiaRole('Detective', MafiaFaction.town,
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]),
  MafiaRole('Doctor', MafiaFaction.town,
      [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2]),
  MafiaRole('Detainer', MafiaFaction.town,
      [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]),
  MafiaRole('Judge', MafiaFaction.town,
      [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]),
  MafiaRole('Suppressor', MafiaFaction.town,
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1]),
  MafiaRole('Janitor', MafiaFaction.town,
      [0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1]),
  MafiaRole('Vigilante', MafiaFaction.town,
      [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]),
  MafiaRole('Bodyguard', MafiaFaction.neutral,
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1]),
  MafiaRole('Jester', MafiaFaction.neutral,
      [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1]),
  MafiaRole('Mafia', MafiaFaction.mafia,
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3]),
  MafiaRole('Witch', MafiaFaction.mafia,
      [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]),
  MafiaRole('Harbinger', MafiaFaction.veil,
      [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]),
  MafiaRole('Poisoner', MafiaFaction.veil,
      [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]),
  MafiaRole('Saboteur', MafiaFaction.veil,
      [0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1]),
  MafiaRole('Mirage', MafiaFaction.veil,
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1]),
];

/// Roles with a nonzero count for [players], grouped by faction in the order
/// Town, Neutral, Mafia, Veil.
Map<MafiaFaction, List<MapEntry<MafiaRole, int>>> rolesForPlayerCount(
    int players) {
  final result = <MafiaFaction, List<MapEntry<MafiaRole, int>>>{};
  for (final faction in MafiaFaction.values) {
    final roles = [
      for (final role in kMafiaRoles)
        if (role.faction == faction && role.countFor(players) > 0)
          MapEntry(role, role.countFor(players)),
    ];
    if (roles.isNotEmpty) result[faction] = roles;
  }
  return result;
}
