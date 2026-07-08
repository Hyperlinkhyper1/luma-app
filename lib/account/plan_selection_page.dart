import 'package:flutter/material.dart';

import '../app/widgets.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_scope.dart';
import '../theme/luma_theme.dart';
import 'plan.dart';

/// Per-plan tier icon to give each card its own identity.
const _planIcons = <String, IconData>{
  'core': Icons.hexagon_outlined,
  'orbit': Icons.rocket_launch_rounded,
  'nova': Icons.auto_awesome_rounded,
};

/// Full-screen plan picker navigated to from the account page's "Change plan"
/// button.
class PlanSelectionPage extends StatelessWidget {
  const PlanSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Scaffold(
      backgroundColor: luma.background,
      body: Stack(
        children: [
          // ---- Decorative background glow ----------------------------------
          Positioned(
            top: -120,
            left: 0,
            right: 0,
            height: 400,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      luma.accent.withValues(alpha: 0.10),
                      luma.accent.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ---- Main content ------------------------------------------------
          SafeArea(
            child: Column(
              children: [
                // ---- Top bar ------------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded,
                            color: luma.textPrimary),
                        tooltip: 'Back to account',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // ---- Hero header --------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: luma.accentSubtle,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.workspace_premium_rounded,
                            color: luma.accent, size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Choose your plan',
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select the plan that works best for you.',
                        style: TextStyle(color: luma.textMuted, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ---- Plan cards ---------------------------------------------
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: const _PlanGrid(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PlanGrid extends StatelessWidget {
  const _PlanGrid();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final selectedId = settings.selectedPlanId;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final cards = [
              for (final plan in kPlans)
                _PlanCard(
                  plan: plan,
                  selected: plan.id == selectedId,
                  onTap: () => _selectPlan(context, settings, plan),
                ),
            ];
            if (!wide) {
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    cards[i],
                  ],
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    Expanded(child: cards[i]),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _selectPlan(
      BuildContext context, SettingsController settings, Plan plan) {
    settings.setSelectedPlanId(plan.id);
    Navigator.of(context).pop();
  }
}

// ---------------------------------------------------------------------------

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final plan = widget.plan;
    final selected = widget.selected;
    final icon = _planIcons[plan.id] ?? Icons.star_rounded;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hovering ? luma.surfaceHover : luma.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? luma.accent : luma.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: luma.accent.withValues(alpha: 0.18),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, 12),
                ),
              if (_hovering && !selected)
                BoxShadow(
                  color: luma.accent.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Header area ------------------------------------------------
              Container(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          colors: [
                            luma.accent.withValues(alpha: 0.14),
                            luma.accent.withValues(alpha: 0.02),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(23)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon + badge row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selected
                                ? luma.accent.withValues(alpha: 0.18)
                                : luma.accentSubtle,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, size: 22, color: luma.accent),
                        ),
                        const Spacer(),
                        if (selected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: luma.accent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Current',
                              style: TextStyle(
                                color: luma.onAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Name
                    Text(
                      plan.name,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Price
                    Text(
                      plan.priceLabel,
                      style: TextStyle(
                        color: luma.accent,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan.blurb,
                      style: TextStyle(
                        color: luma.textMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // ---- Divider ----------------------------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Divider(color: luma.border, height: 1),
              ),

              // ---- Feature list -----------------------------------------------
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WHAT YOU GET',
                        style: TextStyle(
                          color: luma.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final feature in plan.features)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 1),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: luma.accentSubtle,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.check_rounded,
                                    size: 14, color: luma.accent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    color: luma.textSecondary,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ---- Action button -----------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: selected
                    ? Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: luma.accentSubtle,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: luma.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 16, color: luma.accent),
                            const SizedBox(width: 8),
                            Text(
                              'Your current plan',
                              style: TextStyle(
                                color: luma.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : LumaPrimaryButton(
                        label: 'Select ${plan.name}',
                        onTap: widget.onTap,
                        expand: true,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
