// Auto-ported from Roblox Server Hosting Tycoon
// Main game UI: canvas, inspector, shop, modals.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Router;
import 'package:flutter/services.dart';

import '../../../../theme/luma_theme.dart';
import 'data/boosts.dart';
import 'data/game_data.dart';
import 'data/missions.dart';
import 'data/research.dart';
import 'game_state.dart';
import 'server_tycoon_repository.dart';
import 'server_tycoon_scope.dart';
import 'sim/computer_sim.dart';
import 'sim/service_sim.dart';

/// Below this shortest-side width the game switches to its phone layout:
/// stacked HUD, sheet inspectors, and a five-slot toolbar. Matches the app
/// shell's own breakpoint so the two agree about what counts as a phone.
const double _phoneBreakpoint = 700;

bool _isPhone(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide < _phoneBreakpoint;

class ServerTycoonPage extends StatefulWidget {
  const ServerTycoonPage({super.key});

  @override
  State<ServerTycoonPage> createState() => _ServerTycoonPageState();
}

class _ServerTycoonPageState extends State<ServerTycoonPage> with SingleTickerProviderStateMixin {
  // Node dimensions, kept in sync with _RigNode / _RouterNode so wires can
  // attach to tile edges and drags stay aligned under the pointer.
  static const Size _rigSize = Size(220, 88);
  static const Size _routerSize = Size(170, 76);
  static const Size _serviceSize = Size(200, 72);

  String? _selectedRigId;
  String? _selectedRouterId;
  String? _selectedServiceId;

  // Live port-drag: which node the wire is coming out of, and where the
  // finger currently is in canvas coordinates.
  String? _linkFromKind;
  String? _linkFromId;
  Offset? _linkCursor;
  bool _showContracts = false;
  bool _showResearch = false;
  bool _showLicenses = false;
  bool _showDayReport = false;
  bool _showAchievements = false;
  bool _showStaff = false;
  bool _showMissions = false;
  bool _showBoosts = false;
  bool _showStats = false;
  bool _showAwayReport = false;

  /// True once the canvas has been framed on the player's actual layout. The
  /// saved node positions live in a 4000×3000 space, so opening at the origin
  /// at 1× would otherwise show an empty grid.
  bool _didAutoFit = false;

  /// Set while a phone inspector sheet is up, so re-tapping the same node
  /// doesn't stack a second one.
  bool _inspectorSheetOpen = false;

  final TransformationController _canvasController = TransformationController();

  /// Identifies the InteractiveViewer's viewport, so a finger position can be
  /// mapped back into canvas space while wiring nodes together.
  final GlobalKey _canvasKey = GlobalKey();

  // Drives fan-spin/glow pulse on nodes and packet-flow on wires. Deliberately
  // NOT routed through setState/notifyListeners -- each node/wire scopes its
  // own AnimatedBuilder around this so a 60fps pulse doesn't cascade a
  // full-canvas rebuild the way the 1s repository tick does.
  late final AnimationController _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  // Transient drag state — while a node is being dragged we render it (and its
  // wires) from this local position and only commit to the repo on drag end.
  String? _dragKind;
  String? _dragId;
  Offset? _dragPos;

  @override
  void dispose() {
    _pulseController.dispose();
    _canvasController.dispose();
    super.dispose();
  }

  Offset _effectivePos(String kind, String id, double x, double y) =>
      (_dragKind == kind && _dragId == id) ? _dragPos! : Offset(x, y);

  /// Intersection of the segment [rect.center → target] with rect's border,
  /// so wires start/end on the tile edge instead of its center.
  // Orthogonal wire route between two node rects: exits a side, bends at
  // right angles, and only runs straight when the two ports already line up.
  List<Offset> _wireRoute(Rect a, Rect b) {
    const gap = 16.0;
    // Enough horizontal room: exit the facing left/right sides.
    if (b.left - a.right >= gap || a.left - b.right >= gap) {
      final toRight = b.center.dx >= a.center.dx;
      final start = Offset(toRight ? a.right : a.left, a.center.dy);
      final end = Offset(toRight ? b.left : b.right, b.center.dy);
      if ((start.dy - end.dy).abs() < 1) return [start, end];
      final midX = (start.dx + end.dx) / 2;
      return [start, Offset(midX, start.dy), Offset(midX, end.dy), end];
    }
    // Enough vertical room: exit the facing top/bottom sides.
    if (b.top - a.bottom >= gap || a.top - b.bottom >= gap) {
      final below = b.center.dy >= a.center.dy;
      final start = Offset(a.center.dx, below ? a.bottom : a.top);
      final end = Offset(b.center.dx, below ? b.top : b.bottom);
      if ((start.dx - end.dx).abs() < 1) return [start, end];
      final midY = (start.dy + end.dy) / 2;
      return [start, Offset(start.dx, midY), Offset(end.dx, midY), end];
    }
    // Rects overlap on both axes: loop around the outside with a U-shape.
    final toRight = b.center.dx >= a.center.dx;
    final start = Offset(toRight ? a.right : a.left, a.center.dy);
    final end = Offset(toRight ? b.right : b.left, b.center.dy);
    final outX = toRight ? math.max(start.dx, end.dx) + gap : math.min(start.dx, end.dx) - gap;
    return [start, Offset(outX, start.dy), Offset(outX, end.dy), end];
  }

  Widget _buildMain(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final phone = _isPhone(context);

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final state = repo.state;
        final load = repo.calculateLoad();
        final effects = repo.effects;

        // Check for day report to auto-show. Auto-advance deliberately skips
        // it — a modal every 30 seconds is the opposite of idling.
        if (repo.lastDayReport != null && !_showDayReport && !state.autoConfirmDay) {
          _showDayReport = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
        if (repo.lastAwayReport != null && !_showAwayReport) {
          _showAwayReport = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }

        return Scaffold(
          backgroundColor: luma.background,
          body: Column(
            children: [
              if (phone)
                _buildPhoneTopBar(context, state, load, effects)
              else
                _buildTopBar(context, state, load, effects),
              // Main Content
              Expanded(
                child: Row(
                  children: [
                    // Canvas
                    Expanded(
                      child: _buildCanvas(context, state, load),
                    ),
                    // Inspector side panels are desktop-only; on a phone the
                    // same content opens as a bottom sheet instead, because a
                    // 340px panel beside a 360px screen leaves no canvas.
                    if (!phone && _selectedRigId != null && state.rigs.containsKey(_selectedRigId))
                      SizedBox(
                        width: 340,
                        child: _buildInspector(
                          context,
                          state,
                          load,
                          _selectedRigId!,
                          onClose: () => setState(() => _selectedRigId = null),
                        ),
                      ),
                    if (!phone && _selectedServiceId != null && state.services.containsKey(_selectedServiceId))
                      SizedBox(
                        width: 320,
                        child: _buildServiceInspector(
                          context,
                          state,
                          load,
                          _selectedServiceId!,
                          onClose: () => setState(() => _selectedServiceId = null),
                        ),
                      ),
                    if (!phone && _selectedRouterId != null && state.routers.containsKey(_selectedRouterId))
                      SizedBox(
                        width: 300,
                        child: _buildRouterInspector(
                          context,
                          state,
                          _selectedRouterId!,
                          onClose: () => setState(() => _selectedRouterId = null),
                        ),
                      ),
                  ],
                ),
              ),
              if (phone)
                _buildPhoneToolbar(context, state)
              else
                _buildToolbar(context, state),
            ],
          ),
        );
      },
    );
  }

  // ── Phone HUD ──

  /// Two compact lines instead of the desktop bar's single row: the desktop
  /// version lays out nine stats plus a 140px timer and needs ~1100px, which
  /// overflows every phone in portrait.
  Widget _buildPhoneTopBar(BuildContext context, GameState state, AccountLoadResult load, ResearchEffects effects) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final totalWatts = _getTotalWatts(state, load);
    final activeMissions = state.missions.where((m) => !m.rewarded).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money_rounded, size: 18, color: Colors.green.shade400),
              Text(
                _fmt(state.money),
                style: TextStyle(color: Colors.green.shade400, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(width: 12),
              Icon(Icons.star_rounded, size: 15, color: Colors.amber.shade400),
              const SizedBox(width: 2),
              Text(
                state.reputation.toStringAsFixed(1),
                style: TextStyle(color: Colors.amber.shade400, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              _dayTimerPill(context),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 24,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (state.prestigeLevel > 0)
                  _topStat(context, Icons.military_tech_rounded, _prestigeTierName(state.prestigeLevel), luma.accent),
                _topStat(context, Icons.calendar_today_rounded, 'Day ${state.dayCount}', luma.textMuted),
                _topStat(
                  context,
                  Icons.network_check_rounded,
                  '${load.totalRequiredBandwidth.toStringAsFixed(0)}/${load.totalBandwidthCapacity.toStringAsFixed(0)} Mbps',
                  load.overloaded ? Colors.red.shade400 : Colors.green.shade400,
                ),
                _topStat(context, Icons.electrical_services_rounded, '${totalWatts.toStringAsFixed(0)}W', luma.textMuted),
                _topStat(context, Icons.description_rounded, '${state.contracts.length}/${effects.contractSlots}', luma.textMuted),
                if (activeMissions > 0)
                  _topStat(context, Icons.flag_rounded, '$activeMissions goals', luma.accent),
                if (state.activeResearch != null)
                  _topStat(
                    context,
                    Icons.science_rounded,
                    '${(state.activeResearch!.fraction * 100).toStringAsFixed(0)}%',
                    luma.accent,
                  ),
                for (final boost in state.activeBoosts)
                  _topStat(context, Icons.bolt_rounded, '${boost.def?.name ?? boost.defId} ${boost.daysRemaining}d', Colors.orange.shade400),
                if (state.hiredStaffIds.isNotEmpty)
                  _topStat(context, Icons.badge_rounded, '${state.hiredStaffIds.length} staff', luma.textMuted),
              ],
            ),
          ),
          if (repo.awaitingConfirmation && !state.autoConfirmDay) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: repo.lastDayReport != null ? null : repo.confirmNextDay,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Next Day'),
                style: FilledButton.styleFrom(
                  backgroundColor: luma.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Shared day clock: progress ring, seconds left, and the speed control.
  Widget _dayTimerPill(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final state = repo.state;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: repo.dayProgress,
                strokeWidth: 3,
                backgroundColor: luma.border,
                valueColor: AlwaysStoppedAnimation<Color>(luma.accent),
              ),
              Text(
                '${repo.secondsRemaining}',
                style: TextStyle(color: luma.textMuted, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: repo.isPaused ? 'Resume' : 'Pause',
          icon: Icon(
            repo.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            size: 20,
            color: repo.isPaused ? luma.accent : luma.textMuted,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            repo.setPaused(!repo.isPaused);
          },
        ),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            HapticFeedback.selectionClick();
            final speeds = GameState.gameSpeeds;
            final next = speeds[(speeds.indexOf(state.gameSpeed) + 1) % speeds.length];
            repo.setGameSpeed(next);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              '${state.gameSpeed}×',
              style: TextStyle(
                color: state.gameSpeed > 1 ? luma.accent : luma.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Five primary actions; everything else lives behind "More". The desktop
  /// toolbar puts eleven widgets in one un-scrollable Row.
  Widget _buildPhoneToolbar(BuildContext context, GameState state) {
    final luma = context.luma;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(top: BorderSide(color: luma.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _phoneToolButton(context, Icons.add_circle_outline_rounded, 'Build', () => _showBuildSheet(context)),
          _phoneToolButton(context, Icons.shopping_cart_rounded, 'Shop', () => _showShopCatalog(context)),
          _phoneToolButton(
            context,
            Icons.assignment_rounded,
            'Contracts',
            () => setState(() => _showContracts = true),
            badge: state.contracts.length,
          ),
          _phoneToolButton(
            context,
            Icons.science_rounded,
            'Research',
            () => setState(() => _showResearch = true),
            highlight: state.activeResearch != null,
          ),
          _phoneToolButton(context, Icons.more_horiz_rounded, 'More', () => _showMoreSheet(context)),
        ],
      ),
    );
  }

  Widget _phoneToolButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    int badge = 0,
    bool highlight = false,
  }) {
    final luma = context.luma;
    final color = highlight ? luma.accent : luma.textMuted;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        // 48px minimum so it's a real touch target, not a 12px text button.
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 21, color: color),
                  if (badge > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: luma.accent, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          '$badge',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, GameState state, AccountLoadResult load, ResearchEffects effects) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final totalWatts = _getTotalWatts(state, load);
    final internetCost = _getDailyInternetCost(state);
    final awaiting = repo.awaitingConfirmation;
    final secs = repo.secondsRemaining;
    final progress = repo.dayProgress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.dns_rounded, color: luma.accent, size: 20),
          const SizedBox(width: 8),
          Text('Server Hosting Tycoon', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          if (state.prestigeLevel > 0)
            _topStat(context, Icons.military_tech_rounded, _prestigeTierName(state.prestigeLevel), luma.accent),
          _topStat(context, Icons.attach_money_rounded, '\$${_fmt(state.money)}', Colors.green.shade400),
          _topStat(context, Icons.star_rounded, '${state.reputation.toStringAsFixed(1)} rep', Colors.amber.shade400),
          _topStat(context, Icons.calendar_today_rounded, 'Day ${state.dayCount}', luma.textMuted),
          _topStat(context, Icons.electrical_services_rounded, '${totalWatts.toStringAsFixed(0)}W', luma.textMuted),
          _topStat(context, Icons.wifi_rounded, '\$${_fmt(internetCost)}/day', luma.textMuted),
          _topStat(context, Icons.network_check_rounded, '${load.totalRequiredBandwidth.toStringAsFixed(0)} / ${load.totalBandwidthCapacity.toStringAsFixed(0)} Mbps', load.overloaded ? Colors.red.shade400 : Colors.green.shade400),
          const SizedBox(width: 12),
          _topStat(context, Icons.description_rounded, '${state.contracts.length} / ${effects.contractSlots} contracts', luma.textMuted),
          if (state.hiredStaffIds.isNotEmpty)
            _topStat(context, Icons.badge_rounded, '${state.hiredStaffIds.length} staff', luma.textMuted),
          const SizedBox(width: 12),
          if (!awaiting)
            SizedBox(
              width: 140,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Next day in ${secs}s', style: TextStyle(color: luma.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: luma.border,
                      valueColor: AlwaysStoppedAnimation<Color>(luma.accent),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            )
          else
            FilledButton.icon(
              onPressed: repo.lastDayReport != null
                  ? null
                  : () {
                      repo.confirmNextDay();
                    },
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Next Day'),
              style: FilledButton.styleFrom(
                backgroundColor: luma.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topStat(BuildContext context, IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Frames every node in the viewport. Node positions live anywhere in a
  /// 4000×3000 space, so without this the player opens onto empty grid.
  void _fitToContent(Size viewport, GameState state) {
    if (viewport.width <= 0 || viewport.height <= 0) return;

    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;

    void include(double x, double y, Size size) {
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x + size.width > maxX) maxX = x + size.width;
      if (y + size.height > maxY) maxY = y + size.height;
    }

    for (final rig in state.rigs.values) {
      include(rig.pos.x, rig.pos.y, _rigSize);
    }
    for (final router in state.routers.values) {
      include(router.pos.x, router.pos.y, _routerSize);
    }
    for (final service in state.services.values) {
      include(service.pos.x, service.pos.y, _serviceSize);
    }
    if (minX == double.infinity) return;

    const padding = 32.0;
    final contentWidth = (maxX - minX) + padding * 2;
    final contentHeight = (maxY - minY) + padding * 2;
    final scale = math.min(viewport.width / contentWidth, viewport.height / contentHeight).clamp(0.25, 1.2);

    // Centre whatever slack is left over after fitting.
    final tx = (viewport.width - contentWidth * scale) / 2 + (padding - minX) * scale;
    final ty = (viewport.height - contentHeight * scale) / 2 + (padding - minY) * scale;

    _canvasController.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  Widget _buildCanvas(BuildContext context, GameState state, AccountLoadResult load) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_didAutoFit && viewport.width > 0) {
          _didAutoFit = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fitToContent(viewport, state);
          });
        }

        return Stack(
          children: [
            Positioned.fill(child: _canvasViewer(context, state, load)),
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _canvasButton(context, Icons.center_focus_strong_rounded, 'Fit to view', () {
                    HapticFeedback.selectionClick();
                    _fitToContent(viewport, state);
                  }),
                  const SizedBox(height: 8),
                  _canvasButton(context, Icons.auto_awesome_mosaic_rounded, 'Auto-arrange', () {
                    HapticFeedback.selectionClick();
                    repo.autoArrange();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _fitToContent(viewport, repo.state);
                    });
                  }),
                ],
              ),
            ),
            if (_isPhone(context))
              Positioned(
                left: 12,
                bottom: 12,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: luma.surface.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Tap to inspect · hold to move',
                      style: TextStyle(color: luma.textMuted, fontSize: 10),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _canvasButton(BuildContext context, IconData icon, String tooltip, VoidCallback onTap) {
    final luma = context.luma;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: luma.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: luma.textMuted)),
        ),
      ),
    );
  }

  Widget _canvasViewer(BuildContext context, GameState state, AccountLoadResult load) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final incidentsByTarget = <String, List<ActiveIncident>>{};
    for (final incident in repo.activeIncidents) {
      incidentsByTarget.putIfAbsent(incident.targetId, () => []).add(incident);
    }

    return InteractiveViewer(
      key: _canvasKey,
      transformationController: _canvasController,
      boundaryMargin: const EdgeInsets.all(2000),
      minScale: 0.25,
      maxScale: 2.0,
      constrained: false,
      child: Container(
        width: 4000,
        height: 3000,
        color: luma.background,
        child: Stack(
          children: [
            // Grid background
            CustomPaint(size: const Size(4000, 3000), painter: _GridPainter(color: luma.border)),
            // Connection lines (drawn behind nodes, attached to tile edges)
            for (final rig in state.rigs.values)
              if (rig.routerId != null && state.routers.containsKey(rig.routerId))
                Builder(builder: (_) {
                  final routerId = rig.routerId!;
                  final rigPos = _effectivePos('rig', rig.rigId, rig.pos.x, rig.pos.y);
                  final router = state.routers[routerId]!;
                  final routerPos = _effectivePos('router', routerId, router.pos.x, router.pos.y);
                  final rigRect = rigPos & _rigSize;
                  final routerRect = routerPos & _routerSize;
                  return CustomPaint(
                    size: const Size(4000, 3000),
                    painter: _WirePainter(
                      points: _wireRoute(rigRect, routerRect),
                      color: load.rigs[rig.rigId]?.localFactor == 1 && load.routers[routerId]?.bandwidthFactor == 1
                          ? Colors.green.shade400
                          : Colors.red.shade400,
                      pulse: _pulseController,
                      utilization: 1 - (load.routers[routerId]?.bandwidthFactor ?? 1.0),
                    ),
                  );
                }),
            // Service → rig wires.
            for (final service in state.services.values)
              if (service.rigId != null && state.rigs.containsKey(service.rigId))
                Builder(builder: (_) {
                  final rigId = service.rigId!;
                  final servicePos =
                      _effectivePos('service', service.instanceId, service.pos.x, service.pos.y);
                  final rig = state.rigs[rigId]!;
                  final rigPos = _effectivePos('rig', rigId, rig.pos.x, rig.pos.y);
                  final result =
                      load.instances.where((i) => i.instanceId == service.instanceId).firstOrNull;
                  final satisfaction = result?.satisfaction ?? 1.0;
                  return CustomPaint(
                    size: const Size(4000, 3000),
                    painter: _WirePainter(
                      points: _wireRoute(servicePos & _serviceSize, rigPos & _rigSize),
                      color: satisfaction > 0.9 ? Colors.green.shade400 : Colors.orange.shade400,
                      pulse: _pulseController,
                      utilization: 1 - satisfaction,
                    ),
                  );
                }),
            // The wire being dragged out of a port right now.
            if (_linkFromKind != null && _linkCursor != null)
              Builder(builder: (_) {
                final origin = _linkOriginRect(state);
                if (origin == null) return const SizedBox.shrink();
                return CustomPaint(
                  size: const Size(4000, 3000),
                  painter: _PendingWirePainter(
                    from: origin.center,
                    to: _linkCursor!,
                    color: luma.accent,
                  ),
                );
              }),
            // Router nodes
            for (final entry in state.routers.entries)
              _draggableNode(
                kind: 'router',
                id: entry.key,
                x: entry.value.pos.x,
                y: entry.value.pos.y,
                child: _RouterNode(
                  router: entry.value,
                  loadResult: load.routers[entry.key],
                  selected: _selectedRouterId == entry.key,
                  hasActiveIncident: incidentsByTarget.containsKey(entry.key),
                  pulse: _pulseController,
                  onTap: () => _selectRouter(entry.key),
                ),
              ),
            // Service nodes
            for (final entry in state.services.entries)
              _draggableNode(
                kind: 'service',
                id: entry.key,
                x: entry.value.pos.x,
                y: entry.value.pos.y,
                child: _ServiceNodeTile(
                  service: entry.value,
                  result: load.instances.where((i) => i.instanceId == entry.key).firstOrNull,
                  connected: entry.value.rigId != null && state.rigs.containsKey(entry.value.rigId),
                  selected: _selectedServiceId == entry.key,
                  onTap: () => _selectService(entry.key),
                  onPortDragStart: (global) => _beginLink('service', entry.key, global),
                  onPortDragUpdate: _updateLink,
                  onPortDragEnd: _endLink,
                ),
              ),
            // Rig nodes
            for (final entry in state.rigs.entries)
              _draggableNode(
                kind: 'rig',
                id: entry.key,
                x: entry.value.pos.x,
                y: entry.value.pos.y,
                child: _RigNode(
                  rig: entry.value,
                  loadResult: load.rigs[entry.key],
                  selected: _selectedRigId == entry.key,
                  hasActiveIncident: incidentsByTarget.containsKey(entry.key),
                  incidentIsPositive: incidentsByTarget[entry.key]?.every((i) => incidentDefsByType[i.type]?.isPositive == true) ?? false,
                  serviceCount: state.services.values.where((s) => s.rigId == entry.key).length,
                  connected: entry.value.routerId != null &&
                      state.routers.containsKey(entry.value.routerId),
                  pulse: _pulseController,
                  onTap: () => _selectRig(entry.key),
                  onPortDragStart: (global) => _beginLink('rig', entry.key, global),
                  onPortDragUpdate: _updateLink,
                  onPortDragEnd: _endLink,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Nodes move on long-press-drag, not plain drag. A pan handler on the tile
  /// swallows the gesture before InteractiveViewer sees it, which on a touch
  /// screen means you cannot scroll the map with a finger on a node at all.
  Widget _draggableNode({
    required String kind,
    required String id,
    required double x,
    required double y,
    required Widget child,
  }) {
    final pos = _effectivePos(kind, id, x, y);

    void endDrag() {
      final drop = _dragPos;
      if (drop != null) {
        // Snap to the 20px grid so hand-placed tiles still line up.
        const grid = 20.0;
        ServerTycoonScope.of(context).moveNode(
          kind,
          id,
          (drop.dx / grid).round() * grid,
          (drop.dy / grid).round() * grid,
        );
      }
      setState(() {
        _dragKind = null;
        _dragId = null;
        _dragPos = null;
      });
    }

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onLongPressStart: (_) {
          HapticFeedback.mediumImpact();
          setState(() {
            _dragKind = kind;
            _dragId = id;
            _dragPos = Offset(x, y);
          });
        },
        onLongPressMoveUpdate: (details) {
          if (_dragPos == null) return;
          // Measured from the committed start position in global coordinates:
          // the tile's own local frame travels with it while dragging.
          final scale = _canvasController.value.getMaxScaleOnAxis();
          setState(() => _dragPos = Offset(x, y) + details.offsetFromOrigin / scale);
        },
        onLongPressEnd: (_) => endDrag(),
        onLongPressCancel: () => setState(() {
          _dragKind = null;
          _dragId = null;
          _dragPos = null;
        }),
        child: child,
      ),
    );
  }

  // ── Wiring by hand ──

  /// Converts a global (screen) point into canvas coordinates, undoing the
  /// InteractiveViewer transform.
  Offset _toCanvas(Offset global) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final local = box?.globalToLocal(global) ?? global;
    final inverse = Matrix4.tryInvert(_canvasController.value);
    if (inverse == null) return local;
    return MatrixUtils.transformPoint(inverse, local);
  }

  Rect? _nodeRect(GameState state, String kind, String id) {
    switch (kind) {
      case 'rig':
        final rig = state.rigs[id];
        if (rig == null) return null;
        return _effectivePos('rig', id, rig.pos.x, rig.pos.y) & _rigSize;
      case 'router':
        final router = state.routers[id];
        if (router == null) return null;
        return _effectivePos('router', id, router.pos.x, router.pos.y) & _routerSize;
      case 'service':
        final service = state.services[id];
        if (service == null) return null;
        return _effectivePos('service', id, service.pos.x, service.pos.y) & _serviceSize;
    }
    return null;
  }

  Rect? _linkOriginRect(GameState state) =>
      _linkFromKind == null ? null : _nodeRect(state, _linkFromKind!, _linkFromId!);

  void _beginLink(String kind, String id, Offset global) {
    HapticFeedback.selectionClick();
    setState(() {
      _linkFromKind = kind;
      _linkFromId = id;
      _linkCursor = _toCanvas(global);
    });
  }

  void _updateLink(Offset global) {
    if (_linkFromKind == null) return;
    setState(() => _linkCursor = _toCanvas(global));
  }

  void _endLink(Offset global) {
    final fromKind = _linkFromKind;
    final fromId = _linkFromId;
    final drop = _toCanvas(global);
    setState(() {
      _linkFromKind = null;
      _linkFromId = null;
      _linkCursor = null;
    });
    if (fromKind == null || fromId == null) return;

    final repo = ServerTycoonScope.of(context);
    final state = repo.state;

    // Whatever node the wire was released over wins.
    for (final kind in const ['rig', 'router', 'service']) {
      final ids = switch (kind) {
        'rig' => state.rigs.keys,
        'router' => state.routers.keys,
        _ => state.services.keys,
      };
      for (final id in ids) {
        if (kind == fromKind && id == fromId) continue;
        final rect = _nodeRect(state, kind, id);
        if (rect != null && rect.contains(drop)) {
          final result = repo.connectNodes(fromKind, fromId, kind, id);
          if (result.ok) HapticFeedback.mediumImpact();
          _showResult(context, result);
          return;
        }
      }
    }

    // Released over empty canvas: treat it as unplugging.
    _showResult(context, repo.disconnectNode(fromKind, fromId));
  }

  void _selectService(String instanceId) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedServiceId = instanceId;
      _selectedRigId = null;
      _selectedRouterId = null;
    });
    if (_isPhone(context)) _openInspectorSheet();
  }

  void _selectRig(String rigId) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedRigId = rigId;
      _selectedRouterId = null;
      _selectedServiceId = null;
    });
    if (_isPhone(context)) _openInspectorSheet();
  }

  void _selectRouter(String routerId) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedRouterId = routerId;
      _selectedRigId = null;
      _selectedServiceId = null;
    });
    if (_isPhone(context)) _openInspectorSheet();
  }

  /// The phone counterpart to the desktop side panel. Reads live from the
  /// repository so the sheet keeps updating as days tick past underneath it.
  void _openInspectorSheet() {
    if (_inspectorSheetOpen) return;
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    _inspectorSheetOpen = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: luma.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        builder: (_, scrollController) => ListenableBuilder(
          listenable: repo,
          builder: (context, _) {
            final state = repo.state;
            final rigId = _selectedRigId;
            final routerId = _selectedRouterId;
            void close() => Navigator.of(sheetContext).maybePop();

            if (rigId != null && state.rigs.containsKey(rigId)) {
              return _buildInspector(context, state, repo.calculateLoad(), rigId,
                  onClose: close, scrollController: scrollController);
            }
            if (routerId != null && state.routers.containsKey(routerId)) {
              return _buildRouterInspector(context, state, routerId,
                  onClose: close, scrollController: scrollController);
            }
            final serviceId = _selectedServiceId;
            if (serviceId != null && state.services.containsKey(serviceId)) {
              return _buildServiceInspector(context, state, repo.calculateLoad(), serviceId,
                  onClose: close, scrollController: scrollController);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    ).whenComplete(() {
      _inspectorSheetOpen = false;
      if (mounted) {
        setState(() {
          _selectedRigId = null;
          _selectedRouterId = null;
          _selectedServiceId = null;
        });
      }
    });
  }

  Widget _buildInspector(
    BuildContext context,
    GameState state,
    AccountLoadResult load,
    String rigId, {
    required VoidCallback onClose,
    ScrollController? scrollController,
  }) {
    final luma = context.luma;
    final rig = state.rigs[rigId]!;
    final rigLoad = load.rigs[rigId];
    final cpu = cpusById[rig.build.cpuId];
    final mobo = motherboardsById[rig.build.motherboardId];
    final wiredServices = state.services.values.where((s) => s.rigId == rigId).toList()
      ..sort((a, b) => a.instanceId.compareTo(b.instanceId));

    return Container(
      color: luma.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: luma.border))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rig.name, style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(rig.kind == RigKind.server ? 'Server Rig' : 'PC Rig', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: luma.textMuted, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _quickActionsRow(context, rigId),
                  // Status
                  if (rigLoad != null) ...[
                    if (rigLoad.incompatible)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.orange.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INCOMPATIBLE HARDWARE -- EARNING \$0/DAY', style: TextStyle(color: Colors.orange.shade300, fontSize: 11, fontWeight: FontWeight.w700)),
                            for (final reason in rigLoad.incompatibilityReasons)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('• $reason', style: TextStyle(color: Colors.orange.shade200, fontSize: 10)),
                              ),
                          ],
                        ),
                      ),
                    _statBar(context, 'CPU', rigLoad.utilization.cpu, rigLoad.localBottleneck == 'cpu'),
                    _statBar(context, 'RAM', rigLoad.utilization.ramGB, rigLoad.localBottleneck == 'ram'),
                    _statBar(context, 'Storage', rigLoad.utilization.storageGB, rigLoad.localBottleneck == 'storage'),
                    _statBar(
                      context,
                      'Disk speed (${rigLoad.capacity.diskMBs.toStringAsFixed(0)} MB/s)',
                      rigLoad.utilization.disk,
                      rigLoad.localBottleneck == 'disk',
                    ),
                    _statBar(context, 'NIC', 1 - rigLoad.nicCapFactor, rigLoad.localBottleneck == 'nic'),
                    if (rigLoad.tempRatio > 1)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                        child: Text('THERMAL THROTTLING: ${(rigLoad.tempRatio * 100).toStringAsFixed(0)}% capacity', style: TextStyle(color: Colors.red.shade300, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    const SizedBox(height: 16),
                  ],
                  // Hardware
                  Text('Hardware', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  _hardwareRow(context, 'CPU', cpu?.name ?? rig.build.cpuId, () => _showShopSheet(context, rig.rigId, 'cpu')),
                  _hardwareRow(context, 'Motherboard', mobo?.name ?? rig.build.motherboardId, () => _showShopSheet(context, rig.rigId, 'motherboard')),
                  _hardwareRow(context, 'PSU', psusById[rig.build.psuId]?.name ?? rig.build.psuId, () => _showShopSheet(context, rig.rigId, 'psu')),
                  _hardwareRow(context, 'Cooling', coolingById[rig.build.coolingId]?.name ?? rig.build.coolingId, () => _showShopSheet(context, rig.rigId, 'cooling')),
                  _hardwareRow(context, 'NIC', nicsById[rig.build.nicId]?.name ?? rig.build.nicId, () => _showShopSheet(context, rig.rigId, 'nic')),
                  const SizedBox(height: 12),
                  // RAM
                  Row(
                    children: [
                      Expanded(child: Text('RAM (${getTotalRAMGB(rig.build)}GB)', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600, fontSize: 12))),
                      TextButton(
                        onPressed: () => _showAddRAMSheet(context, rigId),
                        child: Text('+ Add', style: TextStyle(color: luma.accent, fontSize: 12)),
                      ),
                    ],
                  ),
                  for (var i = 0; i < rig.build.ramIds.length; i++)
                    _ramRow(context, rigId, i, rig.build.ramIds[i]),
                  const SizedBox(height: 12),
                  // Storage
                  Row(
                    children: [
                      Expanded(child: Text('Storage (${getTotalStorageGB(rig.build)}GB)', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600, fontSize: 12))),
                      TextButton(
                        onPressed: () => _showAddStorageSheet(context, rigId),
                        child: Text('+ Add', style: TextStyle(color: luma.accent, fontSize: 12)),
                      ),
                    ],
                  ),
                  for (var i = 0; i < rig.build.storageIds.length; i++)
                    _storageRow(context, rigId, i, rig.build.storageIds[i]),
                  const SizedBox(height: 16),
                  // Services wired into this rig. They live on the canvas as
                  // their own nodes now, so this is a view of what's plugged
                  // in rather than a list the rig owns.
                  Text('Services', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (wiredServices.isEmpty)
                    Text(
                      'Nothing plugged in — drag a service node onto this rig.',
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  for (final service in wiredServices)
                    _serviceRow(
                      context,
                      service,
                      load.instances.where((i) => i.instanceId == service.instanceId).firstOrNull,
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showInstallServiceSheet(context, rigId: rigId),
                    icon: Icon(Icons.add_rounded, size: 16, color: luma.accent),
                    label: Text('Install Service', style: TextStyle(color: luma.accent, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                  // Router assignment
                  Text('Network', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: rig.routerId,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: luma.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: luma.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    dropdownColor: luma.surface,
                    style: TextStyle(color: luma.textPrimary, fontSize: 13),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Not connected',
                            style: TextStyle(color: Colors.orange.shade300, fontSize: 13)),
                      ),
                      for (final router in state.routers.values)
                        DropdownMenuItem(value: router.routerId, child: Text(router.name, style: TextStyle(color: luma.textPrimary, fontSize: 13))),
                    ],
                    onChanged: (value) {
                      final repo = ServerTycoonScope.of(context);
                      if (value == null) {
                        repo.disconnectNode('rig', rigId);
                      } else {
                        repo.assignRigRouter(rigId, value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One-tap upgrades: buy whatever relieves this rig's actual bottleneck, or
  /// duplicate a build that's working. Both replace a five-sheet crawl.
  Widget _quickActionsRow(BuildContext context, String rigId) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final fix = repo.bottleneckFixFor(rigId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: fix == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      _showResult(context, repo.fixBottleneck(rigId));
                    },
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: Text(
                fix == null ? 'No fix needed' : 'Fix: ${fix.$3}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: luma.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              _showResult(context, repo.cloneRig(rigId));
            },
            icon: Icon(Icons.copy_rounded, size: 15, color: luma.textMuted),
            label: Text('Clone', style: TextStyle(color: luma.textMuted, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: luma.border),
              minimumSize: const Size(0, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceInspector(
    BuildContext context,
    GameState state,
    AccountLoadResult load,
    String instanceId, {
    required VoidCallback onClose,
    ScrollController? scrollController,
  }) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final service = state.services[instanceId]!;
    final def = servicesById[service.serviceTypeId];
    final result = load.instances.where((i) => i.instanceId == instanceId).firstOrNull;
    final rig = service.rigId == null ? null : state.rigs[service.rigId];

    return Container(
      color: luma.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: luma.border))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(def?.name ?? service.serviceTypeId,
                          style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('Service', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: luma.textMuted, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: rig == null
                          ? Colors.orange.shade900.withOpacity(0.25)
                          : luma.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          rig == null ? Icons.link_off_rounded : Icons.link_rounded,
                          size: 16,
                          color: rig == null ? Colors.orange.shade300 : Colors.green.shade400,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rig == null
                                ? 'Not plugged in — drag this node\'s port onto a rig.'
                                : 'Running on ${rig.name}',
                            style: TextStyle(
                              color: rig == null ? Colors.orange.shade200 : luma.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(def?.description ?? '', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('Capacity', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      const Spacer(),
                      _capacityStepper(context, service),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(def?.capacityUnitLabel ?? '', style: TextStyle(color: luma.textMuted, fontSize: 11)),
                  const SizedBox(height: 14),
                  _kvRow(context, 'Income', '\$${result?.incomePerDay.toStringAsFixed(2) ?? "0.00"}/day',
                      Colors.green.shade400),
                  _kvRow(
                    context,
                    'Satisfaction',
                    result == null ? '—' : '${(result.satisfaction * 100).toStringAsFixed(0)}%',
                    (result?.satisfaction ?? 0) > 0.9 ? Colors.green.shade400 : Colors.orange.shade400,
                  ),
                  if (result?.bottleneck != null)
                    _kvRow(context, 'Bottleneck', result!.bottleneck!.toUpperCase(), Colors.red.shade400),
                  const SizedBox(height: 18),
                  if (rig != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        repo.disconnectNode('service', instanceId);
                      },
                      icon: Icon(Icons.link_off_rounded, size: 16, color: luma.textMuted),
                      label: Text('Unplug', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: luma.border),
                        minimumSize: const Size.fromHeight(42),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      repo.uninstallService(instanceId);
                      onClose();
                    },
                    icon: Icon(Icons.delete_outline_rounded, size: 16, color: luma.danger),
                    label: Text('Delete service', style: TextStyle(color: luma.danger, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvRow(BuildContext context, String label, String value, Color color) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: luma.textMuted, fontSize: 12))),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRouterInspector(
    BuildContext context,
    GameState state,
    String routerId, {
    required VoidCallback onClose,
    ScrollController? scrollController,
  }) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final router = state.routers[routerId]!;
    final plan = internetPlansById[router.internetPlanId];

    return Container(
      color: luma.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: luma.border))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(router.name, style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('Router', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: luma.textMuted, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _showResult(context, repo.upgradeRouterPlan(routerId));
                      },
                      icon: const Icon(Icons.upgrade_rounded, size: 16),
                      label: const Text('Upgrade to next plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        backgroundColor: luma.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(40),
                      ),
                    ),
                  ),
                  Text('Internet Plan', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (plan != null) ...[
                    Text(plan.name, style: TextStyle(color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('↓ ${plan.downMbps} Mbps / ↑ ${plan.upMbps} Mbps', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                    Text('Latency: ${plan.maxLatencyMs}ms', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                    Text('Monthly: \$${plan.monthlyPrice}', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  Text('Upgrade Plan', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  for (final p in internetPlanList)
                    if (p.id != router.internetPlanId)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.name, style: TextStyle(color: luma.textPrimary, fontSize: 12)),
                        subtitle: Text('↑ ${p.upMbps} Mbps • \$${p.monthlyPrice}/mo', style: TextStyle(color: luma.textMuted, fontSize: 11)),
                        trailing: TextButton(
                          onPressed: () => ServerTycoonScope.of(context).buyInternetPlan(routerId, p.id),
                          child: Text('Select', style: TextStyle(color: luma.accent, fontSize: 12)),
                        ),
                      ),
                  const SizedBox(height: 16),
                  Text('Connected Rigs', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  for (final rig in state.rigs.values)
                    if (rig.routerId == routerId)
                      Text(rig.name, style: TextStyle(color: luma.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, GameState state) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(top: BorderSide(color: luma.border)),
      ),
      child: Row(
        children: [
          // Scrollable so a narrow desktop window degrades into a scroll
          // instead of a RenderFlex overflow.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _toolButton(context, Icons.computer_rounded, 'PC Rig', () => _showResult(context, ServerTycoonScope.of(context).addRig())),
                  _toolButton(context, Icons.storage_rounded, 'Server', () => _showResult(context, ServerTycoonScope.of(context).addRig(server: true))),
                  _toolButton(context, Icons.router_rounded, 'Router', () => _showResult(context, ServerTycoonScope.of(context).addRouter())),
                  _toolButton(context, Icons.apps_rounded, 'Service', () => _showInstallServiceSheet(context)),
                  VerticalDivider(color: luma.border, width: 24),
                  _toolButton(context, Icons.science_rounded, 'Research', () => setState(() => _showResearch = true)),
                  _toolButton(context, Icons.assignment_rounded, 'Contracts', () => setState(() => _showContracts = true)),
                  _toolButton(context, Icons.flag_rounded, 'Goals', () => setState(() => _showMissions = true)),
                  _toolButton(context, Icons.bolt_rounded, 'Boosts', () => setState(() => _showBoosts = true)),
                  _toolButton(context, Icons.verified_rounded, 'Licenses', () => setState(() => _showLicenses = true)),
                  _toolButton(context, Icons.emoji_events_rounded, 'Achievements', () => setState(() => _showAchievements = true)),
                  _toolButton(context, Icons.badge_rounded, 'Staff', () => setState(() => _showStaff = true)),
                  _toolButton(context, Icons.insights_rounded, 'Stats', () => setState(() => _showStats = true)),
                  VerticalDivider(color: luma.border, width: 24),
                  _toolButton(context, Icons.shopping_cart_rounded, 'Shop', () => _showShopCatalog(context)),
                ],
              ),
            ),
          ),
          Tooltip(
            message: 'Auto-advance days',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.fast_forward_rounded,
                size: 19,
                color: state.autoConfirmDay ? luma.accent : luma.textMuted,
              ),
              onPressed: () => repo.setAutoConfirmDay(!state.autoConfirmDay),
            ),
          ),
          _dayTimerPill(context),
          const SizedBox(width: 8),
          if (repo.canRebirth) ...[
            FilledButton.icon(
              onPressed: () => _confirmRebirth(context),
              icon: const Icon(Icons.trending_up_rounded, size: 16),
              label: const Text('Scale Up'),
              style: FilledButton.styleFrom(
                backgroundColor: luma.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
          ],
          TextButton.icon(
            onPressed: () => _confirmReset(context),
            icon: Icon(Icons.restart_alt_rounded, size: 14, color: luma.danger),
            label: Text('Reset', style: TextStyle(color: luma.danger, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _toolButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: luma.textMuted),
        label: Text(label, style: TextStyle(color: luma.textMuted, fontSize: 12)),
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
      ),
    );
  }

  Widget _statBar(BuildContext context, String label, double value, bool bottleneck) {
    final luma = context.luma;
    final double pct = value.isFinite ? value.clamp(0, 1).toDouble() : 1.0;
    final color = pct > 0.9 ? Colors.red.shade400 : pct > 0.7 ? Colors.orange.shade400 : Colors.green.shade400;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(color: luma.textMuted, fontSize: 11)),
              const Spacer(),
              Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(color: bottleneck ? Colors.red.shade400 : color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: luma.border,
            valueColor: AlwaysStoppedAnimation(bottleneck ? Colors.red.shade400 : color),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _hardwareRow(BuildContext context, String label, String value, VoidCallback onChange) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(color: luma.textMuted, fontSize: 11))),
          Expanded(child: Text(value, style: TextStyle(color: luma.textPrimary, fontSize: 12), overflow: TextOverflow.ellipsis)),
          TextButton(
            onPressed: onChange,
            child: Text('Change', style: TextStyle(color: luma.accent, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _ramRow(BuildContext context, String rigId, int index, String ramId) {
    final luma = context.luma;
    final stick = ramById[ramId];
    return Row(
      children: [
        Expanded(child: Text(stick?.name ?? ramId, style: TextStyle(color: luma.textPrimary, fontSize: 11), overflow: TextOverflow.ellipsis)),
        Text('${stick?.capacityGB ?? 0}GB', style: TextStyle(color: luma.textMuted, fontSize: 11)),
        IconButton(
          icon: Icon(Icons.remove_circle_outline_rounded, size: 16, color: luma.danger),
          onPressed: () => ServerTycoonScope.of(context).removeRAM(rigId, index),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }

  Widget _storageRow(BuildContext context, String rigId, int index, String driveId) {
    final luma = context.luma;
    final drive = storageById[driveId];
    return Row(
      children: [
        Expanded(child: Text(drive?.name ?? driveId, style: TextStyle(color: luma.textPrimary, fontSize: 11), overflow: TextOverflow.ellipsis)),
        Text('${drive?.capacityGB ?? 0}GB', style: TextStyle(color: luma.textMuted, fontSize: 11)),
        IconButton(
          icon: Icon(Icons.remove_circle_outline_rounded, size: 16, color: luma.danger),
          onPressed: () => ServerTycoonScope.of(context).removeStorage(rigId, index),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }

  Widget _serviceRow(BuildContext context, ServiceNode inst, InstanceResult? result) {
    final luma = context.luma;
    final serviceType = servicesById[inst.serviceTypeId];
    final sat = result?.satisfaction ?? 1.0;
    final satColor = sat > 0.9 ? Colors.green.shade400 : sat > 0.6 ? Colors.orange.shade400 : Colors.red.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: luma.background, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(serviceType?.name ?? inst.serviceTypeId, style: TextStyle(color: luma.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Text('\$${result?.incomePerDay.toStringAsFixed(2) ?? "0.00"}/day', style: TextStyle(color: Colors.green.shade400, fontSize: 11)),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 16, color: luma.danger),
                onPressed: () => ServerTycoonScope.of(context).uninstallService(inst.instanceId),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          Row(
            children: [
              // A stepper rather than a text field: the old one rebuilt its
              // controller every frame, so the 1s repository tick wiped
              // whatever you were part-way through typing.
              _capacityStepper(context, inst),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  serviceType?.capacityUnitLabel ?? '',
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${(sat * 100).toStringAsFixed(0)}% sat', style: TextStyle(color: satColor, fontSize: 11)),
            ],
          ),
          if (result?.bottleneck != null)
            Text('Bottleneck: ${result!.bottleneck!.toUpperCase()}', style: TextStyle(color: Colors.red.shade400, fontSize: 10)),
        ],
      ),
    );
  }

  /// −/+ stepper for a service's capacity. Holding either button repeats, and
  /// tapping the number opens a keypad for a big jump.
  Widget _capacityStepper(BuildContext context, ServiceNode inst) {
    final luma = context.luma;

    void setTo(int value) {
      if (value < 1) return;
      HapticFeedback.selectionClick();
      ServerTycoonScope.of(context).setServiceCapacity(inst.instanceId, value);
    }

    return Container(
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepperButton(
            context,
            Icons.remove_rounded,
            enabled: inst.capacity > 1,
            onTap: () => setTo(inst.capacity - 1),
            onLongPress: () => setTo(inst.capacity - 10),
          ),
          InkWell(
            onTap: () => _promptCapacity(context, inst),
            child: Container(
              constraints: const BoxConstraints(minWidth: 44),
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(
                '${inst.capacity}',
                style: TextStyle(color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          _stepperButton(
            context,
            Icons.add_rounded,
            enabled: true,
            onTap: () => setTo(inst.capacity + 1),
            onLongPress: () => setTo(inst.capacity + 10),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton(
    BuildContext context,
    IconData icon, {
    required bool enabled,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    final luma = context.luma;
    return InkWell(
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      borderRadius: BorderRadius.circular(7),
      // 36px square keeps this a usable touch target without making the
      // service card taller than the rest of the inspector rows.
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 17, color: enabled ? luma.accent : luma.textMuted),
      ),
    );
  }

  Future<void> _promptCapacity(BuildContext context, ServiceNode inst) async {
    final luma = context.luma;
    final controller = TextEditingController(text: '${inst.capacity}');
    final serviceType = servicesById[inst.serviceTypeId];

    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text(
          serviceType?.name ?? 'Capacity',
          style: TextStyle(color: luma.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(color: luma.textPrimary),
          decoration: InputDecoration(
            labelText: serviceType?.capacityUnitLabel,
            labelStyle: TextStyle(color: luma.textMuted),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: luma.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
            style: FilledButton.styleFrom(backgroundColor: luma.accent),
            child: const Text('Set'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (value != null && value > 0 && context.mounted) {
      ServerTycoonScope.of(context).setServiceCapacity(inst.instanceId, value);
    }
  }

  void _showResult(BuildContext context, ActionResult result) {
    if (!result.ok && result.errors != null) {
      _showToast(context, result.errors!.join('\n'));
    } else if (result.warning != null) {
      _showToast(context, '⚠ ${result.warning}');
    }
  }

  void _showToast(BuildContext context, String message) {
    final luma = context.luma;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: TextStyle(color: luma.textPrimary, fontSize: 13)),
      backgroundColor: luma.surface,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  void _confirmReset(BuildContext context) {
    final luma = context.luma;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text('Reset Game?', style: TextStyle(color: luma.textPrimary)),
        content: Text('All progress will be lost. This cannot be undone.', style: TextStyle(color: luma.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: luma.textMuted))),
          TextButton(
            onPressed: () {
              ServerTycoonScope.of(context).resetGame();
              Navigator.pop(ctx);
              setState(() {
                _selectedRigId = null;
                _selectedRouterId = null;
              });
            },
            child: Text('Reset', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
  }

  void _confirmRebirth(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final nextLevel = repo.state.prestigeLevel + 1;
    final nextMultiplier = 1 + 2 * (1 - math.exp(-0.3 * nextLevel));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text('Scale Up to ${_prestigeTierName(nextLevel)}?', style: TextStyle(color: luma.textPrimary)),
        content: Text(
          'You will keep: prestige tier, lifetime income multiplier (now ${nextMultiplier.toStringAsFixed(2)}x), '
          'achievements, and your lifetime earnings record.\n\n'
          'You will lose: all rigs, routers, staff, research, licenses, active contracts, inventory, '
          'current cash, reputation, and day count -- you restart from Day 0 with \$250.',
          style: TextStyle(color: luma.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: luma.textMuted))),
          FilledButton(
            onPressed: () {
              repo.rebirth();
              Navigator.pop(ctx);
              setState(() {
                _selectedRigId = null;
                _selectedRouterId = null;
              });
            },
            style: FilledButton.styleFrom(backgroundColor: luma.accent),
            child: const Text('Scale Up'),
          ),
        ],
      ),
    );
  }

  void _showAddRAMSheet(BuildContext context, String rigId) => _showShopSheet(context, rigId, 'ram');
  void _showAddStorageSheet(BuildContext context, String rigId) => _showShopSheet(context, rigId, 'storage');

  void _showShopSheet(BuildContext context, String rigId, String slot) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final rig = repo.state.rigs[rigId]!;

    showModalBottomSheet(
      context: context,
      backgroundColor: luma.surface,
      isScrollControlled: true,
      builder: (ctx) {
        // Each entry: (id, name, price, fitsGrade). Nothing is filtered out any
        // more -- any part can be bought for any rig, but items that don't fit
        // this rig's grade are flagged so the player knows the rig won't earn
        // money until the build is fixed (see buyComponent/addRAM/addStorage).
        final List<(String, String, int, bool)> items;
        switch (slot) {
          case 'ram':
            items = ramList.map((r) => (r.id, r.name, r.price, gradeFits('ram', r.id, rig.kind))).toList();
            break;
          case 'storage':
            items = storageList.map((d) => (d.id, d.name, d.price, true)).toList();
            break;
          case 'cpu':
            items = cpuList.map((c) => (c.id, c.name, c.price, gradeFits('cpu', c.id, rig.kind))).toList();
            break;
          case 'motherboard':
            items = motherboardList.map((m) => (m.id, m.name, m.price, gradeFits('motherboard', m.id, rig.kind))).toList();
            break;
          case 'psu':
            items = psuList.map((p) => (p.id, p.name, p.price, gradeFits('psu', p.id, rig.kind))).toList();
            break;
          case 'cooling':
            items = coolingList.map((c) => (c.id, c.name, c.price, gradeFits('cooling', c.id, rig.kind))).toList();
            break;
          case 'nic':
            items = nicList.map((n) => (n.id, n.name, n.price, gradeFits('nic', n.id, rig.kind))).toList();
            break;
          default:
            items = const [];
        }

        final sortedItems = [...items]..sort((a, b) {
          final ownedA = repo.inventoryCount(a.$1) > 0 ? 0 : 1;
          final ownedB = repo.inventoryCount(b.$1) > 0 ? 0 : 1;
          return ownedA.compareTo(ownedB);
        });

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (_, scrollController) => Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Text('${slot == 'ram' || slot == 'storage' ? 'Add' : 'Swap'} ${slot.toUpperCase()}', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: sortedItems.length,
                  itemBuilder: (ctx, i) {
                    final (itemId, name, price, fits) = sortedItems[i];
                    final owned = repo.inventoryCount(itemId);
                    final canAfford = owned > 0 || repo.state.money >= price;

                    return ListTile(
                      dense: true,
                      title: Text(name, style: TextStyle(color: luma.textPrimary, fontSize: 13)),
                      subtitle: Row(
                        children: [
                          if (owned > 0)
                            Text('In inventory x$owned', style: TextStyle(color: Colors.blue.shade300, fontSize: 12, fontWeight: FontWeight.w600))
                          else
                            Text('\$$price', style: TextStyle(color: canAfford ? Colors.green.shade400 : Colors.red.shade400, fontSize: 12)),
                          if (!fits) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange.shade400),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                'Incompatible with this ${rig.kind.name} rig -- won\'t earn money',
                                style: TextStyle(color: Colors.orange.shade400, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: TextButton(
                        onPressed: canAfford ? () {
                          switch (slot) {
                            case 'ram':
                              _showResult(context, repo.addRAM(rigId, itemId));
                              break;
                            case 'storage':
                              _showResult(context, repo.addStorage(rigId, itemId));
                              break;
                            default:
                              _showResult(context, repo.buyComponent(rigId, slot, itemId));
                          }
                          Navigator.pop(ctx);
                        } : null,
                        child: Text(
                          owned > 0 ? 'Install' : (slot == 'ram' || slot == 'storage' ? 'Buy' : 'Swap'),
                          style: TextStyle(color: canAfford ? luma.accent : luma.textMuted, fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Phone equivalent of the desktop toolbar's first three buttons.
  void _showBuildSheet(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final effects = repo.effects;

    showModalBottomSheet(
      context: context,
      backgroundColor: luma.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHeader(context, Icons.add_circle_outline_rounded, 'Build'),
            _sheetTile(
              context,
              Icons.computer_rounded,
              'PC Rig',
              '\$${(GameState.newRigCost * (1 - effects.rigCostDiscount)).round()} • a cheap box to start on',
              () {
                Navigator.pop(ctx);
                _showResult(context, repo.addRig());
              },
            ),
            _sheetTile(
              context,
              Icons.storage_rounded,
              'Server Rig',
              '\$${(GameState.newServerRigCost * (1 - effects.rigCostDiscount)).round()} • takes server-grade parts',
              () {
                Navigator.pop(ctx);
                _showResult(context, repo.addRig(server: true));
              },
            ),
            _sheetTile(
              context,
              Icons.router_rounded,
              'Router',
              '\$${GameState.newRouterCost} • ${repo.state.routers.length}/${effects.maxRouters} in use',
              () {
                Navigator.pop(ctx);
                _showResult(context, repo.addRouter());
              },
            ),
            _sheetTile(
              context,
              Icons.apps_rounded,
              'Service',
              'Drops a service node on the canvas for you to wire up',
              () {
                Navigator.pop(ctx);
                _showInstallServiceSheet(context);
              },
            ),
            const Divider(height: 1),
            _sheetTile(
              context,
              Icons.auto_awesome_mosaic_rounded,
              'Auto-arrange',
              'Lay the whole graph out: routers, rigs, then their services',
              () {
                Navigator.pop(ctx);
                repo.autoArrange();
                setState(() => _didAutoFit = false);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Everything that doesn't fit in five phone toolbar slots.
  void _showMoreSheet(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: luma.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: ListenableBuilder(
          listenable: repo,
          builder: (context, _) {
            final state = repo.state;
            final unclaimed = state.missions.where((m) => !m.rewarded).length;

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _sheetHeader(context, Icons.more_horiz_rounded, 'More'),
                  ListTile(
                    leading: Icon(Icons.fast_forward_rounded, color: luma.textMuted, size: 20),
                    title: Text(
                      'Auto-advance days',
                      style: TextStyle(color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Roll straight into the next day instead of tapping through the report',
                      style: TextStyle(color: luma.textMuted, fontSize: 11),
                    ),
                    trailing: Switch(
                      value: state.autoConfirmDay,
                      activeThumbColor: luma.onAccent,
                      activeTrackColor: luma.accent,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        repo.setAutoConfirmDay(value);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  _sheetTile(context, Icons.flag_rounded, 'Daily goals',
                      unclaimed > 0 ? '$unclaimed still open today' : 'All done for today', () {
                    Navigator.pop(ctx);
                    setState(() => _showMissions = true);
                  }),
                  _sheetTile(context, Icons.bolt_rounded, 'Boosts',
                      state.activeBoosts.isEmpty ? 'None running' : '${state.activeBoosts.length} running', () {
                    Navigator.pop(ctx);
                    setState(() => _showBoosts = true);
                  }),
                  _sheetTile(context, Icons.insights_rounded, 'Stats', 'Income and power history', () {
                    Navigator.pop(ctx);
                    setState(() => _showStats = true);
                  }),
                  _sheetTile(context, Icons.verified_rounded, 'Licenses', '${state.licenses.length} held', () {
                    Navigator.pop(ctx);
                    setState(() => _showLicenses = true);
                  }),
                  _sheetTile(context, Icons.badge_rounded, 'Staff', '${state.hiredStaffIds.length} hired', () {
                    Navigator.pop(ctx);
                    setState(() => _showStaff = true);
                  }),
                  _sheetTile(context, Icons.emoji_events_rounded, 'Achievements',
                      '${state.unlockedAchievements.length} unlocked', () {
                    Navigator.pop(ctx);
                    setState(() => _showAchievements = true);
                  }),
                  const Divider(height: 1),
                  if (repo.canRebirth)
                    _sheetTile(
                      context,
                      Icons.trending_up_rounded,
                      'Scale Up',
                      'Restart bigger with a permanent income multiplier',
                      () {
                        Navigator.pop(ctx);
                        _confirmRebirth(context);
                      },
                      color: luma.accent,
                    ),
                  _sheetTile(context, Icons.restart_alt_rounded, 'Reset game', 'Start over from day zero', () {
                    Navigator.pop(ctx);
                    _confirmReset(context);
                  }, color: luma.danger),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sheetHeader(BuildContext context, IconData icon, String title, {Widget? trailing}) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: luma.accent),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }

  Widget _sheetTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Color? color,
  }) {
    final luma = context.luma;
    return ListTile(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      leading: Icon(icon, color: color ?? luma.textMuted, size: 20),
      title: Text(title, style: TextStyle(color: color ?? luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: luma.textMuted, fontSize: 11)),
      minVerticalPadding: 10,
    );
  }

  void _showShopCatalog(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);

    const categories = <(String, String, IconData)>[
      ('cpu', 'CPUs', Icons.memory_rounded),
      ('motherboard', 'Motherboards', Icons.developer_board_rounded),
      ('psu', 'PSUs', Icons.bolt_rounded),
      ('cooling', 'Cooling', Icons.ac_unit_rounded),
      ('nic', 'NICs', Icons.settings_ethernet_rounded),
      ('ram', 'RAM', Icons.sd_card_rounded),
      ('storage', 'Storage', Icons.storage_rounded),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: luma.surface,
      isScrollControlled: true,
      builder: (ctx) {
        var selected = categories.first.$1;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            List<(String, String, int)> items;
            switch (selected) {
              case 'cpu':
                items = cpuList.map((c) => (c.id, c.name, c.price)).toList();
                break;
              case 'motherboard':
                items = motherboardList.map((m) => (m.id, m.name, m.price)).toList();
                break;
              case 'psu':
                items = psuList.map((p) => (p.id, p.name, p.price)).toList();
                break;
              case 'cooling':
                items = coolingList.map((c) => (c.id, c.name, c.price)).toList();
                break;
              case 'nic':
                items = nicList.map((n) => (n.id, n.name, n.price)).toList();
                break;
              case 'ram':
                items = ramList.map((r) => (r.id, r.name, r.price)).toList();
                break;
              case 'storage':
                items = storageList.map((d) => (d.id, d.name, d.price)).toList();
                break;
              default:
                items = const [];
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.9,
              builder: (_, scrollController) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.shopping_cart_rounded, size: 18, color: luma.accent),
                        const SizedBox(width: 8),
                        Text('Shop', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                        const Spacer(),
                        Text('\$${_fmt(repo.state.money)}', style: TextStyle(color: Colors.green.shade400, fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final cat in categories)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(cat.$2, style: const TextStyle(fontSize: 12)),
                              avatar: Icon(cat.$3, size: 14),
                              selected: selected == cat.$1,
                              onSelected: (_) => setSheetState(() => selected = cat.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final (itemId, name, price) = items[i];
                        final owned = repo.inventoryCount(itemId);
                        final canAfford = repo.state.money >= price;

                        return ListTile(
                          dense: true,
                          title: Text(name, style: TextStyle(color: luma.textPrimary, fontSize: 13)),
                          subtitle: Row(
                            children: [
                              Text('\$$price', style: TextStyle(color: canAfford ? Colors.green.shade400 : Colors.red.shade400, fontSize: 12)),
                              if (owned > 0) ...[
                                const SizedBox(width: 8),
                                Text('Owned x$owned', style: TextStyle(color: Colors.blue.shade300, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ],
                          ),
                          trailing: TextButton(
                            onPressed: canAfford
                                ? () {
                                    _showResult(context, repo.buyToInventory(selected, itemId));
                                    setSheetState(() {});
                                  }
                                : null,
                            child: Text('Buy', style: TextStyle(color: canAfford ? luma.accent : luma.textMuted, fontSize: 12)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showInstallServiceSheet(BuildContext context, {String? rigId}) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: luma.surface,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Text('Install Service', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: serviceList.length,
                itemBuilder: (ctx, i) {
                  final svc = serviceList[i];
                  final unlocked = svc.requiredLicense == null || repo.state.licenses.contains(svc.requiredLicense);

                  return ListTile(
                    dense: true,
                    title: Text(svc.name, style: TextStyle(color: luma.textPrimary, fontSize: 13)),
                    subtitle: Text(svc.description, style: TextStyle(color: luma.textMuted, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: unlocked
                        ? TextButton(
                            onPressed: () {
                              _showResult(context, repo.installService(rigId, svc.id, 1));
                              Navigator.pop(ctx);
                            },
                            child: Text('Install', style: TextStyle(color: luma.accent, fontSize: 12)),
                          )
                        : Text('Locked', style: TextStyle(color: luma.textMuted, fontSize: 11)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ServerTycoonScope.of(context);

    return Stack(
      children: [
        _buildMain(context),
        // Contracts Modal
        if (_showContracts)
          _ContractsModal(
            onClose: () => setState(() => _showContracts = false),
          ),
        // Research Modal
        if (_showResearch)
          _ResearchModal(
            onClose: () => setState(() => _showResearch = false),
          ),
        // Licenses Modal
        if (_showLicenses)
          _LicensesModal(
            onClose: () => setState(() => _showLicenses = false),
          ),
        // Achievements Modal
        if (_showAchievements)
          _AchievementsModal(
            onClose: () => setState(() => _showAchievements = false),
          ),
        // Staff Modal
        if (_showStaff)
          _StaffModal(
            onClose: () => setState(() => _showStaff = false),
          ),
        // Daily goals
        if (_showMissions)
          _MissionsModal(
            onClose: () => setState(() => _showMissions = false),
          ),
        // Boosts
        if (_showBoosts)
          _BoostsModal(
            onClose: () => setState(() => _showBoosts = false),
          ),
        // Stats
        if (_showStats)
          _StatsModal(
            onClose: () => setState(() => _showStats = false),
          ),
        // Achievement unlock toasts
        _AchievementToastStack(),
        // Live incident banners
        _IncidentBannerStack(
          onSelectRig: _selectRig,
          onSelectRouter: _selectRouter,
          onReplaceDrive: (rigId) => _showAddStorageSheet(context, rigId),
        ),
        // Day Report Modal
        if (_showDayReport && repo.lastDayReport != null)
          _DayReportModal(
            report: repo.lastDayReport!,
            onClose: () {
              repo.clearDayReport();
              setState(() => _showDayReport = false);
            },
          ),
        // "While you were away" — takes precedence, so it renders last.
        if (_showAwayReport && repo.lastAwayReport != null)
          _AwayReportModal(
            report: repo.lastAwayReport!,
            onClose: () {
              repo.clearAwayReport();
              setState(() => _showAwayReport = false);
            },
          ),
      ],
    );
  }
}

// ── Canvas Nodes ──

class _RigNode extends StatelessWidget {
  final Rig rig;
  final RigLoadResult? loadResult;
  final bool selected;
  final bool hasActiveIncident;
  final bool incidentIsPositive;
  final int serviceCount;
  final bool connected;
  final Animation<double> pulse;
  final VoidCallback onTap;
  final void Function(Offset global) onPortDragStart;
  final void Function(Offset global) onPortDragUpdate;
  final void Function(Offset global) onPortDragEnd;

  const _RigNode({
    required this.rig,
    this.loadResult,
    required this.selected,
    this.hasActiveIncident = false,
    this.incidentIsPositive = false,
    required this.serviceCount,
    required this.connected,
    required this.pulse,
    required this.onTap,
    required this.onPortDragStart,
    required this.onPortDragUpdate,
    required this.onPortDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final cpu = cpusById[rig.build.cpuId];
    final isHealthy = loadResult?.localFactor == 1.0;
    final statusColor = isHealthy ? Colors.green.shade400 : Colors.red.shade400;
    final incidentColor = incidentIsPositive ? Colors.amber.shade400 : Colors.red.shade400;
    final highLoad = (loadResult?.utilization.cpu ?? 0) > 0.7;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final t = math.sin(pulse.value * 2 * math.pi) * 0.5 + 0.5;
          return Container(
            width: 220,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? luma.accent.withOpacity(0.15) : luma.surface,
              border: Border.all(
                color: hasActiveIncident ? incidentColor : (selected ? luma.accent : luma.border),
                width: hasActiveIncident ? 2.5 : (selected ? 2 : 1),
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                if (hasActiveIncident) BoxShadow(color: incidentColor.withOpacity(0.35 + 0.35 * t), blurRadius: 8 + 8 * t, spreadRadius: 0.5 + t),
                if (!hasActiveIncident && highLoad) BoxShadow(color: Colors.orange.withOpacity(0.15 + 0.15 * t), blurRadius: 3 + 4 * t),
              ],
            ),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(rig.name, style: TextStyle(color: luma.textPrimary, fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: rig.kind == RigKind.server ? Colors.purple.shade900.withOpacity(0.3) : Colors.blue.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(5)),
                  child: Text(rig.kind == RigKind.server ? 'SERVER' : 'PC', style: TextStyle(color: rig.kind == RigKind.server ? Colors.purple.shade300 : Colors.blue.shade300, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(cpu?.name ?? rig.build.cpuId, style: TextStyle(color: luma.textMuted, fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1),
            Text(
              connected ? '$serviceCount services' : '$serviceCount services · no router',
              style: TextStyle(
                color: connected ? luma.textMuted : Colors.orange.shade300,
                fontSize: 12,
              ),
            ),
            if (loadResult?.incompatible == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange.shade400),
                    const SizedBox(width: 4),
                    Text('Incompatible', style: TextStyle(color: Colors.orange.shade400, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
        // Uplink port: drag from here onto a router to plug the rig in.
        Positioned(
          left: -9,
          top: 29,
          child: _NodePort(
            color: connected ? Colors.green.shade400 : Colors.orange.shade400,
            onDragStart: onPortDragStart,
            onDragUpdate: onPortDragUpdate,
            onDragEnd: onPortDragEnd,
          ),
        ),
      ],
    );
  }
}

class _RouterNode extends StatelessWidget {
  final Router router;
  final RouterLoadResult? loadResult;
  final bool selected;
  final bool hasActiveIncident;
  final Animation<double> pulse;
  final VoidCallback onTap;

  const _RouterNode({
    required this.router,
    this.loadResult,
    required this.selected,
    this.hasActiveIncident = false,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final plan = internetPlansById[router.internetPlanId];
    final isHealthy = loadResult == null || loadResult!.bandwidthFactor >= 1.0;
    final statusColor = isHealthy ? Colors.green.shade400 : Colors.red.shade400;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final t = math.sin(pulse.value * 2 * math.pi) * 0.5 + 0.5;
          return Container(
            width: 170,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? luma.accent.withOpacity(0.15) : luma.surface,
              border: Border.all(
                color: hasActiveIncident ? Colors.red.shade400 : (selected ? luma.accent : luma.border),
                width: hasActiveIncident ? 2.5 : (selected ? 2 : 1),
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                if (hasActiveIncident) BoxShadow(color: Colors.red.shade400.withOpacity(0.35 + 0.35 * t), blurRadius: 8 + 8 * t, spreadRadius: 0.5 + t),
              ],
            ),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(router.name, style: TextStyle(color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 4),
            Text(plan?.name ?? router.internetPlanId, style: TextStyle(color: luma.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis),
            Text('${loadResult?.rigCount ?? 0} rigs', style: TextStyle(color: luma.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Painters ──

/// A service sitting on the canvas. Drag its port onto a rig to plug it in.
class _ServiceNodeTile extends StatelessWidget {
  final ServiceNode service;
  final InstanceResult? result;
  final bool connected;
  final bool selected;
  final VoidCallback onTap;
  final void Function(Offset global) onPortDragStart;
  final void Function(Offset global) onPortDragUpdate;
  final void Function(Offset global) onPortDragEnd;

  const _ServiceNodeTile({
    required this.service,
    required this.result,
    required this.connected,
    required this.selected,
    required this.onTap,
    required this.onPortDragStart,
    required this.onPortDragUpdate,
    required this.onPortDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final def = servicesById[service.serviceTypeId];
    final satisfaction = result?.satisfaction ?? 0;
    final statusColor = !connected
        ? luma.textMuted
        : satisfaction > 0.9
            ? Colors.green.shade400
            : satisfaction > 0.6
                ? Colors.orange.shade400
                : Colors.red.shade400;

    return SizedBox(
      width: 200,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 200,
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: luma.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? luma.accent
                      : connected
                          ? luma.border
                          : Colors.orange.shade400.withOpacity(0.6),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          def?.name ?? service.serviceTypeId,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    connected
                        ? '${service.capacity} ${def?.capacityUnitLabel ?? ""} · \$${result?.incomePerDay.toStringAsFixed(2) ?? "0.00"}/day'
                        : 'Not plugged in',
                    style: TextStyle(
                      color: connected ? luma.textMuted : Colors.orange.shade300,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // Output port on the left edge, facing the rig it feeds. It owns
          // the pan gesture, so dragging from here draws a wire while
          // dragging the body pans the map and long-pressing it moves the node.
          Positioned(
            left: -9,
            top: 22,
            child: _NodePort(
              color: connected ? luma.accent : Colors.orange.shade400,
              onDragStart: onPortDragStart,
              onDragUpdate: onPortDragUpdate,
              onDragEnd: onPortDragEnd,
            ),
          ),
        ],
      ),
    );
  }
}

/// The little circle you drag a connection out of.
class _NodePort extends StatelessWidget {
  final Color color;
  final void Function(Offset global) onDragStart;
  final void Function(Offset global) onDragUpdate;
  final void Function(Offset global) onDragEnd;

  const _NodePort({
    required this.color,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => onDragStart(d.globalPosition),
      onPanUpdate: (d) => onDragUpdate(d.globalPosition),
      onPanEnd: (d) => onDragEnd(d.globalPosition),
      // Padded out to a 30px touch target around an 18px dot.
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: luma.surface,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
        ),
      ),
    );
  }
}

/// The rubber-band wire that follows your finger while connecting.
class _PendingWirePainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final Color color;

  _PendingWirePainter({required this.from, required this.to, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Dashed, to read as provisional rather than an existing link.
    const dash = 10.0;
    const gap = 7.0;
    final delta = to - from;
    final distance = delta.distance;
    if (distance < 1) return;
    final step = delta / distance;

    var travelled = 0.0;
    while (travelled < distance) {
      final end = math.min(travelled + dash, distance);
      canvas.drawLine(from + step * travelled, from + step * end, paint);
      travelled = end + gap;
    }

    canvas.drawCircle(to, 6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PendingWirePainter old) => old.from != from || old.to != to;
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 0.5;
    const spacing = 50.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WirePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final Animation<double> pulse;
  final double utilization;

  // repaint: pulse makes this painter re-run paint() on every animation tick
  // without rebuilding the surrounding widget tree.
  _WirePainter({
    required this.points,
    required this.color,
    required this.pulse,
    this.utilization = 0,
  }) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    // Soft neon glow under the wire, then a bright core line.
    final glowPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path, glowPaint);
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);

    // Animated "packet flow" dashes -- denser and faster the more loaded the
    // link is. Dashes walk the full polyline, wrapping around corners.
    var totalLength = 0.0;
    for (var i = 1; i < points.length; i++) {
      totalLength += (points[i] - points[i - 1]).distance;
    }
    if (totalLength <= 0) return;
    final u = utilization.clamp(0, 1).toDouble();
    const dashLength = 6.0;
    final gapLength = 14.0 - 8.0 * u;
    final period = dashLength + gapLength;
    final speed = 1.0 + 3.0 * u;
    final dashPaint = Paint()
      ..color = Color.lerp(color, Colors.white, 0.55)!
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    Offset pointAt(double d) {
      var remaining = d;
      for (var i = 1; i < points.length; i++) {
        final segLen = (points[i] - points[i - 1]).distance;
        if (remaining <= segLen || i == points.length - 1) {
          if (segLen == 0) return points[i];
          return points[i - 1] + (points[i] - points[i - 1]) * (remaining / segLen).clamp(0.0, 1.0);
        }
        remaining -= segLen;
      }
      return points.last;
    }

    final offset = (pulse.value * period * speed) % period;
    var pos = -offset;
    while (pos < totalLength) {
      final segStart = pos.clamp(0.0, totalLength);
      final segEnd = (pos + dashLength).clamp(0.0, totalLength);
      if (segEnd > segStart) {
        canvas.drawLine(pointAt(segStart), pointAt(segEnd), dashPaint);
      }
      pos += period;
    }
  }

  @override
  bool shouldRepaint(covariant _WirePainter oldDelegate) =>
      !listEquals(points, oldDelegate.points) || color != oldDelegate.color || utilization != oldDelegate.utilization;
}

// ── Modals ──

/// Shared frame for the game's full-screen modals. The originals hard-coded
/// `width: 600, height: 500` containers, which clip on anything narrower.
class _GameModal extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onClose;
  final Widget child;
  final Widget? headerTrailing;
  final double maxWidth;

  const _GameModal({
    required this.icon,
    required this.title,
    required this.onClose,
    required this.child,
    this.headerTrailing,
    this.maxWidth = 600,
  });

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final phone = _isPhone(context);
    final size = MediaQuery.sizeOf(context);

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Container(
            margin: EdgeInsets.all(phone ? 10 : 24),
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: size.height * (phone ? 0.92 : 0.85),
            ),
            decoration: BoxDecoration(color: luma.surface, borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: luma.border))),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: luma.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      ?headerTrailing,
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: luma.textMuted),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContractsModal extends StatelessWidget {
  final VoidCallback onClose;
  const _ContractsModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final state = repo.state;
    final effects = repo.effects;
    final canAccept = state.contracts.length < effects.contractSlots;

    return _GameModal(
      icon: Icons.assignment_rounded,
      title: 'Contracts',
      onClose: onClose,
      headerTrailing: Text(
        '${state.contracts.length} / ${effects.contractSlots}',
        style: TextStyle(color: luma.textMuted, fontSize: 12),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          if (state.contracts.isNotEmpty) ...[
            _sectionLabel(context, 'Active'),
            for (final c in state.contracts) _contractTile(context, c, active: true),
          ],
          _sectionLabel(context, "Today's Offers"),
          if (repo.contractOffers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No offers today — build reputation and buy licenses to attract companies.',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ),
          for (final offer in repo.contractOffers)
            Builder(builder: (ctx) {
              final company = companiesById[offer.companyId];
              final service = servicesById[offer.serviceTypeId];

              return ListTile(
                title: Text(
                  '${company?.name ?? offer.companyId} — ${service?.name ?? offer.serviceTypeId}',
                  style: TextStyle(color: luma.textPrimary, fontSize: 13),
                ),
                subtitle: Text(
                  '${offer.minCapacity} ${service?.capacityUnitLabel ?? ""} • ${offer.durationDays} days • \$${offer.payoutPerDay.toStringAsFixed(2)}/day + \$${offer.completionBonus.toStringAsFixed(0)} bonus',
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                ),
                trailing: canAccept
                    ? TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          final result = repo.acceptContract(offer.offerId);
                          if (!result.ok) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(result.errors?.join('\n') ?? 'Error'),
                              backgroundColor: luma.surface,
                            ));
                          }
                        },
                        child: Text('Accept', style: TextStyle(color: luma.accent, fontSize: 13)),
                      )
                    : Text('Full', style: TextStyle(color: luma.textMuted, fontSize: 11)),
              );
            }),
        ],
      ),
    );
  }

  Widget _contractTile(BuildContext context, Contract c, {required bool active}) {
    final luma = context.luma;
    final company = companiesById[c.companyId];
    final service = servicesById[c.serviceTypeId];
    final pct = 1 - (c.daysRemaining / c.totalDays);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: luma.background, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${company?.name ?? c.companyId} — ${service?.name ?? c.serviceTypeId}', style: TextStyle(color: luma.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
              Text('${c.daysRemaining}d left', style: TextStyle(color: luma.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: pct, backgroundColor: luma.border, valueColor: AlwaysStoppedAnimation(luma.accent), minHeight: 3, borderRadius: BorderRadius.circular(2)),
          const SizedBox(height: 2),
          Text('Needs ${c.minCapacity} ${service?.capacityUnitLabel ?? ""} served • \$${c.payoutPerDay.toStringAsFixed(2)}/day', style: TextStyle(color: luma.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _ResearchModal extends StatefulWidget {
  final VoidCallback onClose;
  const _ResearchModal({required this.onClose});

  @override
  State<_ResearchModal> createState() => _ResearchModalState();
}

class _ResearchModalState extends State<_ResearchModal> {
  ResearchBranch _branch = ResearchBranch.lab;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final state = repo.state;
        final projects = researchInBranch(_branch);
        final maxTier = researchMaxTier(_branch);

        return _GameModal(
          icon: Icons.science_rounded,
          title: 'Research',
          onClose: widget.onClose,
          maxWidth: 720,
          headerTrailing: Text(
            '${state.researchPoints.toStringAsFixed(1)} RP',
            style: TextStyle(color: luma.accent, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _activeBar(context, repo),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  children: [
                    for (final branch in ResearchBranch.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text(
                            researchBranchNames[branch] ?? branch.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: _branch == branch,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _branch = branch);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                  children: [
                    for (var tier = 1; tier <= maxTier; tier++)
                      _tierBlock(
                        context,
                        repo,
                        tier,
                        projects.where((p) => p.tier == tier).toList(),
                        isLast: tier == maxTier,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Progress on whatever is being researched right now, plus the point rate
  /// that decides how long everything else will take.
  Widget _activeBar(BuildContext context, ServerTycoonRepository repo) {
    final luma = context.luma;
    final state = repo.state;
    final active = state.activeResearch;
    final rate = repo.researchPointsPerDayNow;

    if (active == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        color: luma.background,
        child: Text(
          'Nothing in the lab — earning ${rate.toStringAsFixed(1)} RP/day',
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
      );
    }

    final project = researchById[active.projectId];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: luma.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Researching: ${project?.name ?? active.projectId}',
                  style: TextStyle(color: luma.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${repo.activeResearchDaysRemaining}d left',
                style: TextStyle(color: luma.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: active.fraction,
              backgroundColor: luma.border,
              valueColor: AlwaysStoppedAnimation<Color>(luma.accent),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${active.rpAccrued.toStringAsFixed(1)} / ${active.rpNeeded.toStringAsFixed(0)} RP · ${rate.toStringAsFixed(1)}/day',
                style: TextStyle(color: luma.textMuted, fontSize: 10),
              ),
              const Spacer(),
              if (state.researchQueue.isNotEmpty)
                Text('${state.researchQueue.length} queued', style: TextStyle(color: luma.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  /// One depth level of the branch: a rail on the left showing how far the
  /// player has climbed, and the tier's projects scrolling horizontally.
  Widget _tierBlock(
    BuildContext context,
    ServerTycoonRepository repo,
    int tier,
    List<ResearchProject> projects,
    {required bool isLast}) {
    final luma = context.luma;
    if (projects.isEmpty) return const SizedBox.shrink();

    final reached = projects.any((p) => _statusOf(repo, p) != _NodeStatus.locked);
    final railColor = reached ? luma.accent : luma.border;

    // Deliberately not IntrinsicHeight around a full-height rail: a
    // horizontally-scrolling viewport reports zero intrinsic height, which
    // would collapse the row. The rail is drawn as fixed segments instead.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 34,
              child: Center(
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: reached ? luma.accent : luma.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: railColor, width: 2),
                  ),
                ),
              ),
            ),
            Text(
              'Tier $tier',
              style: TextStyle(color: luma.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: luma.border)),
            const SizedBox(width: 12),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 34),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final project in projects)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _projectCard(context, repo, project),
                  ),
              ],
            ),
          ),
        ),
        if (!isLast)
          SizedBox(
            width: 34,
            child: Center(child: Container(width: 2, height: 16, color: luma.border)),
          ),
      ],
    );
  }

  _NodeStatus _statusOf(ServerTycoonRepository repo, ResearchProject project) {
    final state = repo.state;
    if (state.activeResearch?.projectId == project.id) return _NodeStatus.researching;
    if (state.researchQueue.contains(project.id)) return _NodeStatus.queued;

    if (project.repeatable) {
      final level = state.researchLevels[project.id] ?? 0;
      if (level >= project.maxLevel) return _NodeStatus.owned;
    } else if (state.research.contains(project.id)) {
      return _NodeStatus.owned;
    }

    final reqsMet = project.requires.every((r) => state.research.contains(r));
    if (!reqsMet || state.reputation < project.minReputation) return _NodeStatus.locked;
    return _NodeStatus.available;
  }

  Widget _projectCard(BuildContext context, ServerTycoonRepository repo, ResearchProject project) {
    final luma = context.luma;
    final state = repo.state;
    final status = _statusOf(repo, project);
    final level = repo.pendingLevelFor(project.id);
    final cost = project.costAtLevel(level);
    final canAfford = state.money >= cost;

    final (Color borderColor, Color tint) = switch (status) {
      _NodeStatus.owned => (Colors.green.shade400.withOpacity(0.4), Colors.green.shade900.withOpacity(0.12)),
      _NodeStatus.researching => (luma.accent, luma.accent.withOpacity(0.10)),
      _NodeStatus.queued => (luma.accent.withOpacity(0.5), luma.accent.withOpacity(0.05)),
      _NodeStatus.available => (luma.border, luma.background),
      _NodeStatus.locked => (luma.border, luma.background),
    };

    final locked = status == _NodeStatus.locked;

    return Container(
      width: 218,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  project.name,
                  style: TextStyle(
                    color: locked ? luma.textMuted : luma.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (status == _NodeStatus.owned)
                Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade400)
              else if (status == _NodeStatus.researching)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    value: state.activeResearch?.fraction ?? 0,
                    strokeWidth: 2.5,
                    backgroundColor: luma.border,
                    valueColor: AlwaysStoppedAnimation<Color>(luma.accent),
                  ),
                )
              else if (status == _NodeStatus.queued)
                Icon(Icons.hourglass_top_rounded, size: 15, color: luma.accent)
              else if (locked)
                Icon(Icons.lock_rounded, size: 14, color: luma.textMuted),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            project.description,
            style: TextStyle(color: luma.textMuted, fontSize: 11, height: 1.25),
          ),
          if (project.repeatable) ...[
            const SizedBox(height: 5),
            Text(
              'Level ${state.researchLevels[project.id] ?? 0} — repeatable',
              style: TextStyle(color: luma.accent, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 7),
          if (locked)
            Text(
              _lockReason(repo, project),
              style: TextStyle(color: Colors.orange.shade300, fontSize: 10),
            )
          else if (status == _NodeStatus.owned)
            Text('Researched', style: TextStyle(color: Colors.green.shade400, fontSize: 11, fontWeight: FontWeight.w600))
          else if (status == _NodeStatus.researching || status == _NodeStatus.queued)
            SizedBox(
              height: 30,
              child: TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  repo.cancelResearch(project.id);
                },
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  status == _NodeStatus.researching ? 'Cancel (50% back)' : 'Remove from queue',
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                ),
              ),
            )
          else
            SizedBox(
              height: 32,
              width: double.infinity,
              child: FilledButton(
                onPressed: canAfford
                    ? () {
                        HapticFeedback.selectionClick();
                        final result = repo.queueResearch(project.id);
                        if (!result.ok) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(result.errors?.join('\n') ?? 'Error'),
                            backgroundColor: luma.surface,
                          ));
                        }
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: luma.accent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                child: Text('\$$cost · ~${repo.estimatedResearchDays(project)}d'),
              ),
            ),
        ],
      ),
    );
  }

  String _lockReason(ServerTycoonRepository repo, ResearchProject project) {
    final state = repo.state;
    final missing = project.requires.where((r) => !state.research.contains(r)).toList();
    if (missing.isNotEmpty) {
      return 'Needs ${missing.map((id) => researchById[id]?.name ?? id).join(', ')}';
    }
    return 'Needs ${project.minReputation} reputation';
  }
}

enum _NodeStatus { locked, available, queued, researching, owned }

class _LicensesModal extends StatelessWidget {
  final VoidCallback onClose;
  const _LicensesModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final state = repo.state;

    return _GameModal(
      icon: Icons.verified_rounded,
      title: 'Licenses',
      onClose: onClose,
      maxWidth: 520,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: licenseList.length,
        itemBuilder: (ctx, i) {
final license = licenseList[i];
final owned = state.licenses.contains(license.id);
final canAfford = state.money >= license.cost;
final repOk = state.reputation >= license.minReputation;
final reqsMet = license.requires.every((r) => state.licenses.contains(r));

return ListTile(
  title: Text(license.name, style: TextStyle(color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
  subtitle: Text(
    '${license.description}\nRequires ${license.minReputation} rep',
    style: TextStyle(color: luma.textMuted, fontSize: 11),
  ),
  isThreeLine: true,
  trailing: owned
      ? Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 20)
      : TextButton(
          onPressed: canAfford && repOk && reqsMet
              ? () {
                  HapticFeedback.selectionClick();
                  repo.buyLicense(license.id);
                }
              : null,
          child: Text(
            '\$${license.cost}',
            style: TextStyle(color: canAfford && repOk && reqsMet ? luma.accent : luma.textMuted, fontSize: 13),
          ),
        ),
);
        },
      ),
    );
  }
}

class _StaffModal extends StatelessWidget {
  final VoidCallback onClose;
  const _StaffModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final state = repo.state;

    return _GameModal(
      icon: Icons.badge_rounded,
      title: 'Staff',
      onClose: onClose,
      maxWidth: 520,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        itemCount: staffDefList.length,
        itemBuilder: (ctx, i) {
          final def = staffDefList[i];
          final hired = state.hiredStaffIds.contains(def.id);
          final canAfford = state.money >= def.cost;
          final repOk = state.reputation >= def.minReputation;
          final licenseOk = def.requiresLicense == null || state.licenses.contains(def.requiresLicense);
          final researchOk = def.requiresResearch == null || state.research.contains(def.requiresResearch);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hired ? luma.accent.withOpacity(0.1) : luma.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: hired ? luma.accent.withOpacity(0.3) : luma.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(def.name, style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    if (hired)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
                        child: Text('HIRED', style: TextStyle(color: Colors.green.shade400, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                Text(def.description, style: TextStyle(color: luma.textMuted, fontSize: 11)),
                const SizedBox(height: 4),
                Text('Salary: \$${def.dailySalary.toStringAsFixed(0)}/day', style: TextStyle(color: luma.textMuted, fontSize: 10)),
                if (!hired && (!repOk || !licenseOk || !researchOk))
                  Text('Requirements not met', style: TextStyle(color: Colors.red.shade400, fontSize: 10)),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: hired
                      ? TextButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            repo.fireStaff(def.id);
                          },
                          child: Text('Fire', style: TextStyle(color: luma.danger, fontSize: 13)),
                        )
                      : TextButton(
                          onPressed: canAfford && repOk && licenseOk && researchOk
                              ? () {
                                  HapticFeedback.selectionClick();
                                  repo.hireStaff(def.id);
                                }
                              : null,
                          child: Text(
                            'Hire \$${def.cost}',
                            style: TextStyle(color: canAfford && repOk && licenseOk && researchOk ? luma.accent : luma.textMuted, fontSize: 13),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AchievementsModal extends StatelessWidget {
  final VoidCallback onClose;
  const _AchievementsModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final state = repo.state;

    return _GameModal(
      icon: Icons.emoji_events_rounded,
      title: 'Achievements',
      onClose: onClose,
      maxWidth: 520,
      headerTrailing: Text(
        '${state.unlockedAchievements.length} / ${achievementDefList.length}',
        style: TextStyle(color: luma.textMuted, fontSize: 12),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        itemCount: achievementDefList.length,
        itemBuilder: (ctx, i) {
          final def = achievementDefList[i];
          final unlocked = state.unlockedAchievements.contains(def.id);
          final progress = (repo.metricValueFor(def.metric) / def.threshold).clamp(0, 1).toDouble();

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: unlocked ? Colors.amber.withOpacity(0.1) : luma.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: unlocked ? Colors.amber.withOpacity(0.4) : luma.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(unlocked ? Icons.emoji_events_rounded : Icons.emoji_events_outlined, size: 16, color: unlocked ? Colors.amber.shade400 : luma.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(def.name, style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    if (unlocked)
                      Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(def.description, style: TextStyle(color: luma.textMuted, fontSize: 11)),
                if (!unlocked) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: luma.border,
                      valueColor: AlwaysStoppedAnimation(luma.accent),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IncidentBannerStack extends StatelessWidget {
  final void Function(String rigId) onSelectRig;
  final void Function(String routerId) onSelectRouter;
  final void Function(String rigId) onReplaceDrive;
  const _IncidentBannerStack({
    required this.onSelectRig,
    required this.onSelectRouter,
    required this.onReplaceDrive,
  });

  @override
  Widget build(BuildContext context) {
    final repo = ServerTycoonScope.of(context);

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final incidents = repo.activeIncidents;
        if (incidents.isEmpty) return const SizedBox.shrink();

        return Positioned(
          top: 60,
          left: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final incident in incidents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _IncidentCard(
                    incident: incident,
                    onSelect: () {
                      if (incident.targetKind == 'rig') {
                        onSelectRig(incident.targetId);
                      } else {
                        onSelectRouter(incident.targetId);
                      }
                    },
                    onReplaceDrive: () => onReplaceDrive(incident.targetId),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final ActiveIncident incident;
  final VoidCallback onSelect;
  final VoidCallback onReplaceDrive;
  const _IncidentCard({
    required this.incident,
    required this.onSelect,
    required this.onReplaceDrive,
  });

  void _showResult(BuildContext context, ActionResult result) {
    final luma = context.luma;
    if (!result.ok && result.errors != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.errors!.join('\n'), style: TextStyle(color: luma.textPrimary, fontSize: 13)),
        backgroundColor: luma.surface,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final def = incidentDefsByType[incident.type];
    final positive = def?.isPositive ?? false;
    final accentColor = positive ? Colors.amber.shade400 : Colors.red.shade400;

    Widget primaryButton;
    switch (incident.type) {
      case IncidentType.routerDdos:
        primaryButton = TextButton(
          onPressed: () => _showResult(context, repo.mitigateIncident(incident.incidentId)),
          child: Text(def?.actionLabel ?? 'Mitigate', style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w600)),
        );
        break;
      case IncidentType.rigOverheatSpike:
        primaryButton = TextButton(
          onPressed: () => _showResult(context, repo.emergencyCooldown(incident.incidentId)),
          child: Text(def?.actionLabel ?? 'Cooldown', style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w600)),
        );
        break;
      case IncidentType.coolingLeak:
        primaryButton = TextButton(
          onPressed: () => _showResult(context, repo.repairIncident(incident.incidentId)),
          child: Text(def?.actionLabel ?? 'Repair', style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w600)),
        );
        break;
      case IncidentType.driveFailure:
        primaryButton = TextButton(
          onPressed: onReplaceDrive,
          child: Text(def?.actionLabel ?? 'Replace Drive', style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w600)),
        );
        break;
      case IncidentType.viralDemandSpike:
        primaryButton = TextButton(
          onPressed: () => repo.ignoreIncident(incident.incidentId),
          child: Text(def?.actionLabel ?? 'Nice!', style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w600)),
        );
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onSelect,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withOpacity(0.5)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(positive ? Icons.trending_up_rounded : Icons.warning_amber_rounded, color: accentColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(def?.name ?? incident.type.name, style: TextStyle(color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w700))),
                ],
              ),
              const SizedBox(height: 4),
              Text(def?.description ?? '', style: TextStyle(color: luma.textMuted, fontSize: 11)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!positive)
                    TextButton(
                      onPressed: () => repo.ignoreIncident(incident.incidentId),
                      child: Text('Ignore', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                    ),
                  primaryButton,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementToastStack extends StatelessWidget {
  const _AchievementToastStack();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final pending = repo.pendingAchievementUnlocks;
        if (pending.isEmpty) return const SizedBox.shrink();

        return Positioned(
          top: 60,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final id in pending)
                Builder(builder: (context) {
                  final def = achievementDefsById[id];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => repo.clearAchievementUnlock(id),
                        child: Container(
                          width: 260,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: luma.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withOpacity(0.5)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.emoji_events_rounded, color: Colors.amber.shade400, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Achievement Unlocked', style: TextStyle(color: Colors.amber.shade400, fontSize: 10, fontWeight: FontWeight.w700)),
                                    Text(def?.name ?? id, style: TextStyle(color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _DayReportModal extends StatelessWidget {
  final DayReport report;
  final VoidCallback onClose;
  const _DayReportModal({required this.report, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return _GameModal(
      icon: Icons.assessment_rounded,
      title: 'Day ${report.day}',
      onClose: onClose,
      maxWidth: 440,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _reportRow('Income', '\$${report.income.toStringAsFixed(2)}', Colors.green.shade400),
              _reportRow('Contract Income', '\$${report.contractIncome.toStringAsFixed(2)}', Colors.green.shade400),
              _reportRow('Electricity', '-\$${report.electricityCost.toStringAsFixed(2)}', Colors.red.shade400),
              _reportRow('Internet', '-\$${report.internetCost.toStringAsFixed(2)}', Colors.red.shade400),
              if (report.staffSalaryCost > 0)
                _reportRow('Staff Salaries', '-\$${report.staffSalaryCost.toStringAsFixed(2)}', Colors.red.shade400),
              const Divider(),
              _reportRow('Net Profit', '\$${report.netProfit.toStringAsFixed(2)}', report.netProfit >= 0 ? Colors.green.shade400 : Colors.red.shade400, bold: true),
              const SizedBox(height: 8),
              _reportRow('Avg Satisfaction', '${(report.avgSatisfaction * 100).toStringAsFixed(0)}%', report.avgSatisfaction > 0.75 ? Colors.green.shade400 : Colors.orange.shade400),
              _reportRow('Reputation', '${report.reputation.toStringAsFixed(1)}', luma.textPrimary),
              const SizedBox(height: 16),
              if (report.contractEvents.isNotEmpty) ...[
                Text('Contract Events', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                for (final e in report.contractEvents)
                  Text(e, style: TextStyle(color: e.contains('FAILED') ? Colors.red.shade400 : Colors.green.shade400, fontSize: 11)),
                const SizedBox(height: 16),
              ],
              if (report.missionEvents.isNotEmpty) ...[
                Text('Goals Completed', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                for (final e in report.missionEvents)
                  Text(e, style: TextStyle(color: luma.accent, fontSize: 11)),
                const SizedBox(height: 16),
              ],
              if (report.researchEvents.isNotEmpty) ...[
                Text('Research', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                for (final e in report.researchEvents)
                  Text(e, style: TextStyle(color: Colors.green.shade400, fontSize: 11)),
                const SizedBox(height: 16),
              ],
              if (report.boostEvents.isNotEmpty) ...[
                for (final e in report.boostEvents)
                  Text(e, style: TextStyle(color: luma.textMuted, fontSize: 11)),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: onClose,
                style: FilledButton.styleFrom(
                  backgroundColor: luma.accent,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: bold ? FontWeight.w600 : FontWeight.normal))),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MissionsModal extends StatelessWidget {
  final VoidCallback onClose;
  const _MissionsModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final state = repo.state;

        return _GameModal(
          icon: Icons.flag_rounded,
          title: 'Daily Goals',
          onClose: onClose,
          maxWidth: 520,
          headerTrailing: Text('Day ${state.dayCount}', style: TextStyle(color: luma.textMuted, fontSize: 12)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              Text(
                'A fresh board is rolled every day. Rewards are paid the moment a goal is met.',
                style: TextStyle(color: luma.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              if (state.missions.isEmpty)
                Text('No goals today.', style: TextStyle(color: luma.textMuted, fontSize: 12)),
              for (final mission in state.missions)
                Builder(builder: (ctx) {
                  final def = mission.def;
                  if (def == null) return const SizedBox.shrink();
                  final done = mission.rewarded;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: done ? Colors.green.shade900.withOpacity(0.15) : luma.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: done ? Colors.green.shade400.withOpacity(0.4) : luma.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 17,
                              color: done ? Colors.green.shade400 : luma.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                def.name,
                                style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                            Text(
                              '+\$${mission.rewardCash}',
                              style: TextStyle(color: Colors.green.shade400, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(def.description, style: TextStyle(color: luma.textMuted, fontSize: 11)),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: mission.fraction,
                            backgroundColor: luma.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              done ? Colors.green.shade400 : luma.accent,
                            ),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_missionValue(def.metric, mission.progress)} / ${_missionValue(def.metric, mission.target)}'
                          ' · +${mission.rewardRep.toStringAsFixed(1)} rep',
                          style: TextStyle(color: luma.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  /// Money and bandwidth goals read better with their unit attached.
  String _missionValue(MissionMetric metric, double value) => switch (metric) {
        MissionMetric.dailyNetProfit => '\$${value.toStringAsFixed(0)}',
        MissionMetric.bandwidthServed => '${value.toStringAsFixed(0)} Mbps',
        _ => value.toStringAsFixed(0),
      };
}

class _BoostsModal extends StatelessWidget {
  final VoidCallback onClose;
  const _BoostsModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final state = repo.state;

        return _GameModal(
          icon: Icons.bolt_rounded,
          title: 'Boosts',
          onClose: onClose,
          maxWidth: 520,
          headerTrailing: Text(
            '\$${_fmt(state.money)}',
            style: TextStyle(color: Colors.green.shade400, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              for (final def in boostDefList)
                Builder(builder: (ctx) {
                  final active = state.activeBoosts.where((b) => b.defId == def.id).firstOrNull;
                  final canAfford = state.money >= def.cost;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: active != null ? luma.accent.withOpacity(0.10) : luma.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: active != null ? luma.accent.withOpacity(0.45) : luma.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 16, color: active != null ? luma.accent : luma.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                def.name,
                                style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                            if (active != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: luma.accent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '${active.daysRemaining}d left',
                                  style: TextStyle(color: luma.accent, fontSize: 10, fontWeight: FontWeight.w700),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(def.description, style: TextStyle(color: luma.textMuted, fontSize: 11, height: 1.25)),
                        const SizedBox(height: 9),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: FilledButton(
                            onPressed: canAfford
                                ? () {
                                    HapticFeedback.mediumImpact();
                                    ServerTycoonScope.of(context).buyBoost(def.id);
                                  }
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: luma.accent,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            child: Text(
                              active != null
                                  ? 'Extend — \$${def.cost} for ${def.durationDays} days'
                                  : 'Activate — \$${def.cost} for ${def.durationDays} days',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _StatsModal extends StatelessWidget {
  final VoidCallback onClose;
  const _StatsModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final state = repo.state;
    final recent = repo.recentDays;

    final best = recent.isEmpty
        ? null
        : recent.reduce((a, b) => a.netProfit >= b.netProfit ? a : b);
    final worst = recent.isEmpty
        ? null
        : recent.reduce((a, b) => a.netProfit <= b.netProfit ? a : b);

    // Income per service type, from the live load rather than the day log, so
    // it reflects what the fleet is earning right now.
    final byService = <String, double>{};
    for (final inst in repo.calculateLoad().instances) {
      byService[inst.serviceTypeId] = (byService[inst.serviceTypeId] ?? 0) + inst.incomePerDay;
    }
    final serviceRows = byService.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return _GameModal(
      icon: Icons.insights_rounded,
      title: 'Stats',
      onClose: onClose,
      maxWidth: 560,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          _statGrid(context, state, repo),
          const SizedBox(height: 18),
          _chartCard(
            context,
            'Net profit — last ${state.incomeHistory.length} days',
            state.incomeHistory,
            Colors.green.shade400,
            (v) => '\$${v.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 12),
          _chartCard(
            context,
            'Power draw — last ${state.powerHistory.length} days',
            state.powerHistory,
            Colors.orange.shade400,
            (v) => '${v.toStringAsFixed(0)}W',
          ),
          if (best != null && worst != null) ...[
            const SizedBox(height: 18),
            _label(context, 'Best & worst'),
            const SizedBox(height: 6),
            _kv(context, 'Best day', 'Day ${best.day} · \$${best.netProfit.toStringAsFixed(2)}', Colors.green.shade400),
            _kv(context, 'Worst day', 'Day ${worst.day} · \$${worst.netProfit.toStringAsFixed(2)}', Colors.red.shade400),
          ],
          if (serviceRows.isNotEmpty) ...[
            const SizedBox(height: 18),
            _label(context, 'Income by service'),
            const SizedBox(height: 6),
            for (final entry in serviceRows)
              _kv(
                context,
                servicesById[entry.key]?.name ?? entry.key,
                '\$${entry.value.toStringAsFixed(2)}/day',
                luma.textPrimary,
              ),
          ],
        ],
      ),
    );
  }

  Widget _statGrid(BuildContext context, GameState state, ServerTycoonRepository repo) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _statTile(context, 'Lifetime earned', '\$${_fmt(state.totalMoneyEverEarned)}'),
        _statTile(context, 'Days run', '${state.dayCount}'),
        _statTile(context, 'Uptime streak', '${state.uptimeStreakDays}d'),
        _statTile(context, 'Peak bandwidth', '${state.peakBandwidthServed.toStringAsFixed(0)} Mbps'),
        _statTile(context, 'Peak power', '${state.peakPowerDrawWatts.toStringAsFixed(0)}W'),
        _statTile(context, 'Contracts done', '${state.contractsCompletedCount}'),
        _statTile(context, 'Research done', '${state.researchCompletedCount}'),
        _statTile(context, 'Research rate', '${repo.researchPointsPerDayNow.toStringAsFixed(1)} RP/day'),
        _statTile(context, 'Rigs', '${state.rigs.length}'),
        _statTile(context, 'Away rate', '${(repo.offlineRate * 100).toStringAsFixed(0)}%'),
      ],
    );
  }

  Widget _statTile(BuildContext context, String label, String value) {
    final luma = context.luma;
    return Container(
      width: 148,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: luma.textMuted, fontSize: 10)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: luma.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _chartCard(
    BuildContext context,
    String title,
    List<double> values,
    Color color,
    String Function(double) format,
  ) {
    final luma = context.luma;
    final latest = values.isEmpty ? 0.0 : values.last;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: TextStyle(color: luma.textMuted, fontSize: 11)),
              ),
              Text(format(latest), style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            width: double.infinity,
            child: values.length < 2
                ? Center(
                    child: Text(
                      'Not enough days yet',
                      style: TextStyle(color: luma.textMuted, fontSize: 11),
                    ),
                  )
                : CustomPaint(painter: _SparklinePainter(values: values, color: color, baseline: luma.border)),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    final luma = context.luma;
    return Text(text, style: TextStyle(color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w700));
  }

  Widget _kv(BuildContext context, String label, String value, Color color) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: luma.textMuted, fontSize: 12))),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Simple filled line chart for the 30-day history lists. Handles negative
/// values by placing zero inside the band rather than clipping it away.
class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color baseline;

  _SparklinePainter({required this.values, required this.color, required this.baseline});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    var min = values.first, max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    if (min > 0) min = 0;
    if (max < 0) max = 0;
    final range = (max - min).abs() < 1e-9 ? 1.0 : max - min;

    double yFor(double v) => size.height - ((v - min) / range) * size.height;
    double xFor(int i) => (i / (values.length - 1)) * size.width;

    // Zero line, so a loss-making stretch is obvious at a glance.
    final zeroY = yFor(0);
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );

    final path = Path()..moveTo(xFor(0), yFor(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(xFor(i), yFor(values[i]));
    }

    final fill = Path.from(path)
      ..lineTo(size.width, zeroY)
      ..lineTo(0, zeroY)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withOpacity(0.16));

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}

class _AwayReportModal extends StatelessWidget {
  final AwayReport report;
  final VoidCallback onClose;
  const _AwayReportModal({required this.report, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final positive = report.netProfit >= 0;

    return _GameModal(
      icon: Icons.nightlight_round,
      title: 'While you were away',
      onClose: onClose,
      maxWidth: 440,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Away for ${_formatDuration(report.awayFor)} — ${report.daysSimulated} '
                '${report.daysSimulated == 1 ? "day" : "days"} simulated '
                'at ${(report.rate * 100).toStringAsFixed(0)}% rate.',
                style: TextStyle(color: luma.textMuted, fontSize: 12, height: 1.35),
              ),
              if (report.capped) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Capped at ${GameState.maxOfflineDays} days — ${report.daysElapsed} had passed. '
                    'Research the R&D Lab branch to earn more while away.',
                    style: TextStyle(color: Colors.orange.shade200, fontSize: 11, height: 1.3),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '${positive ? "+" : "-"}\$${report.netProfit.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    color: positive ? Colors.green.shade400 : Colors.red.shade400,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _row(context, 'Income', '\$${report.income.toStringAsFixed(2)}', Colors.green.shade400),
              _row(context, 'Running costs', '-\$${report.expenses.toStringAsFixed(2)}', Colors.red.shade400),
              _row(context, 'Research points', '+${report.researchPointsEarned.toStringAsFixed(1)} RP', luma.accent),
              if (report.events.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('What happened', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 5),
                for (final event in report.events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('• $event', style: TextStyle(color: luma.textMuted, fontSize: 11)),
                  ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onClose,
                style: FilledButton.styleFrom(
                  backgroundColor: luma.accent,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Back to work'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, Color color) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: luma.textMuted, fontSize: 13))),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }
}

// ── Helpers ──

/// Small section heading used inside the game's list modals.
Widget _sectionLabel(BuildContext context, String text) {
  final luma = context.luma;
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(
      text,
      style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}

String _fmt(double n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toStringAsFixed(0);
}

const List<String> _prestigeTierNames = [
  'Garage Startup',
  'Regional Host',
  'National Provider',
  'Global Data Empire',
  'Hyperscale Consortium',
];

String _prestigeTierName(int level) => _prestigeTierNames[level.clamp(0, _prestigeTierNames.length - 1)];

double _getTotalWatts(GameState state, AccountLoadResult load) {
  var total = 0.0;
  for (final entry in state.rigs.entries) {
    final rigLoad = load.rigs[entry.key];
    if (rigLoad != null) {
      total += getActualPowerDrawWatts(entry.value.build, rigLoad.cpuLoadFactor);
    }
  }
  return total;
}

double _getDailyInternetCost(GameState state) {
  var total = 0.0;
  for (final router in state.routers.values) {
    final plan = internetPlansById[router.internetPlanId];
    if (plan != null) total += plan.monthlyPrice / 30;
  }
  return total;
}
