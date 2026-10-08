import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
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
                            t.pluginNameMachineLearning,
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            t.mlSubtitle,
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
                  tabs: [t.mlTabCreatureLab, t.mlTabHowItWorks],
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

  static List<({IconData icon, String title, String body})> _steps(L t) => [
        (
          icon: Icons.gesture_rounded,
          title: t.mlHowStep1Title,
          body: t.mlHowStep1Body,
        ),
        (
          icon: Icons.settings_rounded,
          title: t.mlHowStep2Title,
          body: t.mlHowStep2Body,
        ),
        (
          icon: Icons.dns_rounded,
          title: t.mlHowStep3Title,
          body: t.mlHowStep3Body,
        ),
        (
          icon: Icons.hub_rounded,
          title: t.mlHowStep4Title,
          body: t.mlHowStep4Body,
        ),
        (
          icon: Icons.timeline_rounded,
          title: t.mlHowStep5Title,
          body: t.mlHowStep5Body,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final step in _steps(t)) ...[
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
                t.mlHowFooter,
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
