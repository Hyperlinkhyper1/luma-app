import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'ui/creature_lab_tab.dart';

/// The Machine Learning plugin: small learning experiments you can watch
/// happen, all of them running on this device and nothing leaving it.
///
/// The first one is the Creature Lab — draw a shape and a genetic algorithm
/// breeds it a way of walking 50 metres.
class MachineLearningPage extends StatefulWidget {
  const MachineLearningPage({super.key});

  @override
  State<MachineLearningPage> createState() => _MachineLearningPageState();
}

class _MachineLearningPageState extends State<MachineLearningPage> {
  static const _tabs = ['Creature Lab', 'How it works'];
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    LumaIconBadge(
                      icon: Icons.psychology_rounded,
                      color: luma.accent,
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Machine Learning',
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Draw a body, let evolution find the movement.',
                            style: TextStyle(
                              color: luma.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LumaSegmentedTabs(
                  tabs: _tabs,
                  selectedIndex: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
              ],
            ),
          ),
          // The lab keeps its drawing and its run while the other tab is up,
          // but a hidden viewport does not need stepping — [TickerMode] parks
          // the replay without touching the evolution behind it.
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                TickerMode(enabled: _tab == 0, child: const CreatureLabTab()),
                const _HowItWorksTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the lab is actually doing, in the order it does it. Worth its own tab:
/// the whole point of the plugin is that the mechanism is visible, and the
/// viewport alone does not explain why a creature suddenly gets better.
class _HowItWorksTab extends StatelessWidget {
  const _HowItWorksTab();

  static const _steps = <({IconData icon, String title, String body})>[
    (
      icon: Icons.gesture_rounded,
      title: 'Your drawing becomes a body',
      body: 'Every stroke is stamped down with a thickness and merged with the '
          'others wherever they touch. That is thinned to its centre line, '
          'which becomes a graph of bones sitting exactly on what was drawn — '
          'a ring stays a ring, a stick figure stays a stick figure. Short '
          'spikes thrown off by wobbles are pruned, bends keep a joint and '
          'straight runs do not, and the result is capped at eighteen bones so '
          'the search stays small enough to finish.',
    ),
    (
      icon: Icons.settings_rounded,
      title: 'The bones get motors',
      body: 'Bones are rigid and held together by distance constraints. Where '
          'two bones meet there is a joint, and every joint is a spring-damper '
          'chasing a target angle that swings as a sine wave: '
          'rest + centre + amplitude x sin(2 pi f t + phase). A joint has a '
          'strength limit, the ground has ordinary Coulomb friction, and '
          'nothing a creature does to itself can shift its own centre of mass. '
          'Forward motion has to be pushed for.',
    ),
    (
      icon: Icons.dns_rounded,
      title: 'The gait is the genome',
      body: 'One gene sets the frequency the whole body steps at, then each '
          'joint gets three: how far it swings, where in the cycle it swings, '
          'and which angle it swings around. That handful of numbers is the '
          'entire nervous system — there is no brain reacting to the world, '
          'only a rhythm, which is why a good gait looks stubborn.',
    ),
    (
      icon: Icons.hub_rounded,
      title: 'Sixty of them run every generation',
      body: 'Each creature gets a twenty-five second trial, scored on metres '
          'travelled, docked for time spent with its head on the floor, with a '
          'bonus for every second saved once it crosses 50 m. The best four '
          'survive untouched, five fresh random genomes join each round to keep '
          'the population from getting stuck, and the rest are bred by '
          'tournament selection, uniform crossover and gaussian mutation.',
    ),
    (
      icon: Icons.timeline_rounded,
      title: 'And it climbs',
      body: 'The best line climbs fast and then flattens, because the search '
          'has found a local trick and is polishing it. The average line stays '
          'jagged and far below — that is mutation still throwing away most of '
          'its guesses. Restarting rolls new dice, and the same body often '
          'learns a completely different walk.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final step in _steps) ...[
                LumaCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(step.icon, color: luma.accent, size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              step.body,
                              style: TextStyle(
                                color: luma.textSecondary,
                                fontSize: 13,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Everything runs on this device. The population is evaluated in '
                'background isolates, so the walk you are watching stays smooth '
                'while the next generation is being scored.',
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
