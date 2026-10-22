import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'map_maker_store.dart';

class MapMakerHubView extends StatelessWidget {
  const MapMakerHubView({
    super.key,
    required this.onOpenSaves,
    required this.onNewTransitMap,
    required this.onNewCityMap,
    this.store,
  });

  final VoidCallback onOpenSaves;
  final VoidCallback onNewTransitMap;
  final VoidCallback onNewCityMap;
  final MapMakerStore? store;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final isPhone = context.isPhoneWidth;
    final t = L.of(context);

    return Scaffold(
      backgroundColor: luma.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isPhone ? 16 : 32,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: ShapeDecoration(
                          color: luma.accentSubtle,
                          shape: context.lumaDecor.shape(
                            BorderRadius.circular(14),
                            side: BorderSide(
                              color: luma.accent.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        child: Icon(
                          Icons.map_rounded,
                          color: luma.accent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Map Maker',
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create custom fantasy metro transit systems, urban grids, and floorplans.',
                              style: TextStyle(
                                color: luma.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Main Button Layout: 1 bigger button on left, 3 smaller on right
                  if (!isPhone)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1 Bigger button on the left: Saves
                          Expanded(
                            flex: 5,
                            child: _BigSavesButton(
                              onTap: onOpenSaves,
                              store: store,
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Smaller buttons on the right
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                _PlannerActionTile(
                                  title: 'Transit Map',
                                  subtitle:
                                      'Design octilinear fantasy metro & rail diagrams with custom lines and rivers.',
                                  icon: Icons.alt_route_rounded,
                                  iconColor: const Color(0xFF0077C0),
                                  isAvailable: true,
                                  onTap: onNewTransitMap,
                                ),
                                const SizedBox(height: 12),
                                _PlannerActionTile(
                                  title: t.mapMakerCityPlanner,
                                  subtitle: t.mapMakerCityDescription,
                                  icon: Icons.location_city_rounded,
                                  iconColor: const Color(0xFFE6B422),
                                  isAvailable: true,
                                  onTap: onNewCityMap,
                                ),
                                const SizedBox(height: 12),
                                _PlannerActionTile(
                                  title: 'Home Planner',
                                  subtitle:
                                      'Architectural floorplans, interior rooms, and furniture layouts.',
                                  icon: Icons.home_work_rounded,
                                  iconColor: const Color(0xFF00A84F),
                                  isAvailable: false,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Home Planner is coming soon!',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        _BigSavesButton(onTap: onOpenSaves, store: store),
                        const SizedBox(height: 16),
                        _PlannerActionTile(
                          title: 'Transit Map',
                          subtitle:
                              'Design octilinear fantasy metro & rail diagrams with custom lines and rivers.',
                          icon: Icons.alt_route_rounded,
                          iconColor: const Color(0xFF0077C0),
                          isAvailable: true,
                          onTap: onNewTransitMap,
                        ),
                        const SizedBox(height: 12),
                        _PlannerActionTile(
                          title: t.mapMakerCityPlanner,
                          subtitle: t.mapMakerCityDescription,
                          icon: Icons.location_city_rounded,
                          iconColor: const Color(0xFFE6B422),
                          isAvailable: true,
                          onTap: onNewCityMap,
                        ),
                        const SizedBox(height: 12),
                        _PlannerActionTile(
                          title: 'Home Planner',
                          subtitle:
                              'Architectural floorplans, interior rooms, and furniture layouts.',
                          icon: Icons.home_work_rounded,
                          iconColor: const Color(0xFF00A84F),
                          isAvailable: false,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Home Planner is coming soon!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BigSavesButton extends StatefulWidget {
  const _BigSavesButton({required this.onTap, this.store});

  final VoidCallback onTap;
  final MapMakerStore? store;

  @override
  State<_BigSavesButton> createState() => _BigSavesButtonState();
}

class _BigSavesButtonState extends State<_BigSavesButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final store = widget.store ?? MapMakerStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final saveCount = store.saves.length;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _hovering ? luma.surfaceHover : luma.surface,
                borderRadius: decor.cardBorderRadius,
                border: Border.all(
                  color: _hovering
                      ? luma.accent
                      : Color.lerp(luma.border, luma.accent, 0.2)!,
                  width: _hovering ? 1.8 : decor.borderWidth,
                ),
                boxShadow: _hovering
                    ? [
                        BoxShadow(
                          color: luma.accent.withValues(alpha: 0.15),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : decor.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: luma.accentSubtle,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          color: luma.accent,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Saves',
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Browse, edit, and resume your saved maps, schematic routes, and blueprints.',
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: luma.surfaceHover,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: luma.border),
                        ),
                        child: Text(
                          '$saveCount ${saveCount == 1 ? 'save' : 'saves'}',
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'Open',
                            style: TextStyle(
                              color: luma.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: luma.accent,
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlannerActionTile extends StatefulWidget {
  const _PlannerActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.isAvailable,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isAvailable;
  final VoidCallback onTap;

  @override
  State<_PlannerActionTile> createState() => _PlannerActionTileState();
}

class _PlannerActionTileState extends State<_PlannerActionTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;

    return MouseRegion(
      cursor: widget.isAvailable
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: widget.isAvailable && _hovering
                ? luma.surfaceHover
                : luma.surface,
            borderRadius: decor.cardBorderRadius,
            border: Border.all(
              color: widget.isAvailable && _hovering
                  ? widget.iconColor.withValues(alpha: 0.6)
                  : luma.border,
              width: decor.borderWidth,
            ),
            boxShadow: widget.isAvailable && _hovering
                ? [
                    BoxShadow(
                      color: widget.iconColor.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : decor.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!widget.isAvailable) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: luma.border.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Coming soon',
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (widget.isAvailable)
                Icon(
                  Icons.chevron_right_rounded,
                  color: widget.iconColor,
                  size: 22,
                )
              else
                Icon(
                  Icons.lock_outline_rounded,
                  color: luma.textMuted.withValues(alpha: 0.5),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
