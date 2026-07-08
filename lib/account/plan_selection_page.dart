import 'package:flutter/material.dart';

import '../app/widgets.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_scope.dart';
import '../theme/luma_theme.dart';
import 'plan.dart';

/// Full-screen plan picker navigated to from the account page's "Change plan"
/// button.  Every card is uniformly sized via [IntrinsicHeight] + [Expanded].
class PlanSelectionPage extends StatelessWidget {
  const PlanSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Scaffold(
      backgroundColor: luma.background,
      body: SafeArea(
        child: Column(
          children: [
            // ---- Top bar with back button -----------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: luma.textPrimary),
                    tooltip: 'Back to account',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose your plan',
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Preview what's coming — nothing can be purchased yet.",
                        style: TextStyle(color: luma.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---- Plan cards --------------------------------------------------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: _PlanGrid(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PlanGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final selectedId = settings.selectedPlanId;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 680;
            final cards = [
              for (final plan in kPlans)
                _PlanCard(
                  plan: plan,
                  selected: plan.id == selectedId,
                  recommended: plan.id == 'orbit',
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
            // All cards share the same intrinsic height so they visually match.
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Coming soon — billing isn't live yet.")),
    );
    Navigator.of(context).pop();
  }
}

// ---------------------------------------------------------------------------

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final Plan plan;
  final bool selected;
  final bool recommended;
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
    final recommended = widget.recommended && !selected;

    // Gradient accent stripe for the header area of the selected/recommended
    // card.
    final accentGradient = LinearGradient(
      colors: [
        luma.accent.withValues(alpha: 0.18),
        luma.accent.withValues(alpha: 0.04),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

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
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? luma.accent
                  : recommended
                      ? luma.accent.withValues(alpha: 0.5)
                      : luma.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected || _hovering
                ? [
                    BoxShadow(
                      color: luma.accent.withValues(alpha: selected ? 0.15 : 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Header gradient zone ------------------------------------
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: BoxDecoration(
                  gradient: (selected || recommended) ? accentGradient : null,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(19),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + badge
                    Row(
                      children: [
                        Text(
                          plan.name,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        if (selected) _Badge(label: 'Current', luma: luma),
                        if (recommended)
                          _Badge(label: 'Popular', luma: luma, outlined: true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Price
                    Text(
                      plan.priceLabel,
                      style: TextStyle(
                        color: luma.accent,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plan.blurb,
                      style: TextStyle(
                        color: luma.textMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // ---- Divider --------------------------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Divider(color: luma.border, height: 1),
              ),

              // ---- Feature list (expands to fill remaining space) ------------
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INCLUDES',
                        style: TextStyle(
                          color: luma.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final feature in plan.features)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: luma.accentSubtle,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.check_rounded,
                                    size: 12, color: luma.accent),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    color: luma.textSecondary,
                                    fontSize: 13,
                                    height: 1.4,
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

              // ---- Action button at the bottom --------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: selected
                    ? Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: luma.accentSubtle,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Your current plan',
                          style: TextStyle(
                            color: luma.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
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

// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.luma, this.outlined = false});
  final String label;
  final LumaPalette luma;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : luma.accentSubtle,
        borderRadius: BorderRadius.circular(20),
        border: outlined ? Border.all(color: luma.accent.withValues(alpha: 0.5)) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: luma.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
