import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import 'mafia_disguise_names.dart';
import 'mafia_role_data.dart';

Color _factionColor(LumaPalette luma, MafiaFaction faction) => switch (faction) {
      MafiaFaction.town => luma.success,
      MafiaFaction.neutral => luma.textMuted,
      MafiaFaction.mafia => luma.danger,
      MafiaFaction.veil => luma.accent,
    };

/// One claimed-role slot: whether it's been claimed, and who claimed it
/// (their disguise name, optional). Keyed by "$roleName#$instanceIndex" so
/// each copy of a multi-count role (e.g. the second of two Mafia) tracks its
/// own claim independently.
class _Claim {
  bool claimed = false;
  final TextEditingController nameController = TextEditingController();
  final FocusNode nameFocusNode = FocusNode();

  void dispose() {
    nameController.dispose();
    nameFocusNode.dispose();
  }
}

/// Role Counting: pick a lobby size and see exactly which roles are in play
/// and how many of each, sourced from the wiki's per-player-count chart. Each
/// role instance can be checked off as claimed during the round, optionally
/// with the disguise name of whoever claimed it.
class MafiaRoleCounterTab extends StatefulWidget {
  const MafiaRoleCounterTab({super.key});

  @override
  State<MafiaRoleCounterTab> createState() => _MafiaRoleCounterTabState();
}

class _MafiaRoleCounterTabState extends State<MafiaRoleCounterTab> {
  int _players = 10;

  // Kept across player-count changes and rebuilds; only Reset clears it.
  // Extra entries for instances that no longer exist at the current player
  // count are simply not shown — harmless to keep around.
  final Map<String, _Claim> _claims = {};

  @override
  void dispose() {
    for (final claim in _claims.values) {
      claim.dispose();
    }
    super.dispose();
  }

  _Claim _claimFor(String key) => _claims.putIfAbsent(key, () => _Claim());

  void _reset() {
    setState(() {
      for (final claim in _claims.values) {
        claim.dispose();
      }
      _claims.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final byFaction = rolesForPlayerCount(_players);
    final instanceKeys = <String>[
      for (final entries in byFaction.values)
        for (final entry in entries)
          for (var i = 0; i < entry.value; i++) '${entry.key.name}#$i',
    ];
    final totalRoles = instanceKeys.length;
    final claimedCount =
        instanceKeys.where((k) => _claims[k]?.claimed ?? false).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                      'Pick how many players are in the lobby, then check off '
                      'roles as they get claimed.',
                      style: TextStyle(color: luma.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: claimedCount == 0 ? null : _reset,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: luma.textSecondary,
                  side: BorderSide(color: luma.border),
                ),
              ),
            ],
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
                if (totalRoles > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: claimedCount / totalRoles,
                            minHeight: 6,
                            backgroundColor: luma.background,
                            valueColor: AlwaysStoppedAnimation(luma.accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$claimedCount / $totalRoles claimed',
                        style: TextStyle(color: luma.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
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
                  claimFor: _claimFor,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 16),
              ],
        ],
      ),
    );
  }
}

class _FactionSection extends StatelessWidget {
  const _FactionSection({
    required this.faction,
    required this.entries,
    required this.claimFor,
    required this.onChanged,
  });

  final MafiaFaction faction;
  final List<MapEntry<MafiaRole, int>> entries;
  final _Claim Function(String key) claimFor;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = _factionColor(luma, faction);
    final count = entries.fold<int>(0, (a, e) => a + e.value);
    final claimedInSection = entries
        .expand((e) => List.generate(e.value, (i) => '${e.key.name}#$i'))
        .where((k) => claimFor(k).claimed)
        .length;

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
                  '$claimedInSection/$count',
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
          for (final entry in entries) ...[
            for (var i = 0; i < entry.value; i++) ...[
              if (entry != entries.first || i > 0) const SizedBox(height: 8),
              _RoleClaimRow(
                instanceLabel: entry.value > 1
                    ? '${entry.key.name} #${i + 1}'
                    : entry.key.name,
                claim: claimFor('${entry.key.name}#$i'),
                color: color,
                onChanged: onChanged,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RoleClaimRow extends StatelessWidget {
  const _RoleClaimRow({
    required this.instanceLabel,
    required this.claim,
    required this.color,
    required this.onChanged,
  });

  final String instanceLabel;
  final _Claim claim;
  final Color color;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: claim.claimed,
                onChanged: (v) {
                  claim.claimed = v ?? false;
                  onChanged();
                },
                activeColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                instanceLabel,
                style: TextStyle(
                  color: claim.claimed ? luma.textMuted : luma.textPrimary,
                  fontSize: 13,
                  decoration:
                      claim.claimed ? TextDecoration.lineThrough : null,
                  decorationColor: luma.textMuted,
                ),
              ),
            ),
            if (claim.claimed)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 12, color: color),
                    const SizedBox(width: 3),
                    Text(
                      'Claimed',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: claim.claimed
              ? Padding(
                  padding: const EdgeInsets.only(left: 32, top: 6, bottom: 2),
                  child: _NameField(claim: claim, color: color),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// The optional "who claimed this" field: free text, autocompleted against
/// the wiki's disguise-name list — but never forced to match it, since new
/// disguises ship regularly and this list is a snapshot.
class _NameField extends StatelessWidget {
  const _NameField({required this.claim, required this.color});

  final _Claim claim;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return RawAutocomplete<String>(
      textEditingController: claim.nameController,
      focusNode: claim.nameFocusNode,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return kMafiaDisguiseNames
            .where((name) => name.toLowerCase().contains(query))
            .take(8);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onSubmitted: (_) => onSubmit(),
          style: TextStyle(color: luma.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Claimed by… (disguise name)',
            hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
            prefixIcon: Icon(Icons.person_search_rounded,
                size: 16, color: luma.textMuted),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: luma.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: luma.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: luma.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: color),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            color: luma.surface,
            child: Container(
              width: 240,
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: luma.border),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    hoverColor: luma.surfaceHover,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Text(
                        option,
                        style:
                            TextStyle(color: luma.textPrimary, fontSize: 13),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
