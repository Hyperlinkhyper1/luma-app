// Auto-ported from Roblox Server Hosting Tycoon
// Main game UI: canvas, inspector, shop, modals.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Router;
import 'package:flutter/services.dart';

import '../../../../theme/luma_theme.dart';
import 'data/game_data.dart';
import 'data/research.dart';
import 'game_state.dart';
import 'server_tycoon_repository.dart';
import 'server_tycoon_scope.dart';
import 'sim/computer_sim.dart';
import 'sim/service_sim.dart';

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

  String? _selectedRigId;
  String? _selectedRouterId;
  bool _showContracts = false;
  bool _showResearch = false;
  bool _showLicenses = false;
  bool _showDayReport = false;
  bool _showAchievements = false;
  bool _showStaff = false;

  final TransformationController _canvasController = TransformationController();

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

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final state = repo.state;
        final load = repo.calculateLoad();
        final effects = getResearchEffects(state.research);

        // Check for day report to auto-show
        if (repo.lastDayReport != null && !_showDayReport) {
          _showDayReport = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }

        return Scaffold(
          backgroundColor: luma.background,
          body: Column(
            children: [
              // Top Bar
              _buildTopBar(context, state, load, effects),
              // Main Content
              Expanded(
                child: Row(
                  children: [
                    // Canvas
                    Expanded(
                      child: _buildCanvas(context, state, load),
                    ),
                    // Inspector / Side Panel
                    if (_selectedRigId != null && state.rigs.containsKey(_selectedRigId))
                      SizedBox(
                        width: 340,
                        child: _buildInspector(context, state, load, _selectedRigId!),
                      ),
                    if (_selectedRouterId != null && state.routers.containsKey(_selectedRouterId))
                      SizedBox(
                        width: 300,
                        child: _buildRouterInspector(context, state, _selectedRouterId!),
                      ),
                  ],
                ),
              ),
              // Bottom Toolbar
              _buildToolbar(context, state, effects),
            ],
          ),
        );
      },
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

  Widget _buildCanvas(BuildContext context, GameState state, AccountLoadResult load) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final incidentsByTarget = <String, List<ActiveIncident>>{};
    for (final incident in repo.activeIncidents) {
      incidentsByTarget.putIfAbsent(incident.targetId, () => []).add(incident);
    }

    return InteractiveViewer(
      transformationController: _canvasController,
      boundaryMargin: const EdgeInsets.all(2000),
      minScale: 0.1,
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
              if (state.routers.containsKey(rig.routerId))
                Builder(builder: (_) {
                  final rigPos = _effectivePos('rig', rig.rigId, rig.pos.x, rig.pos.y);
                  final router = state.routers[rig.routerId]!;
                  final routerPos = _effectivePos('router', rig.routerId, router.pos.x, router.pos.y);
                  final rigRect = rigPos & _rigSize;
                  final routerRect = routerPos & _routerSize;
                  return CustomPaint(
                    size: const Size(4000, 3000),
                    painter: _WirePainter(
                      points: _wireRoute(rigRect, routerRect),
                      color: load.rigs[rig.rigId]?.localFactor == 1 && load.routers[rig.routerId]?.bandwidthFactor == 1
                          ? Colors.green.shade400
                          : Colors.red.shade400,
                      pulse: _pulseController,
                      utilization: 1 - (load.routers[rig.routerId]?.bandwidthFactor ?? 1.0),
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
                  onTap: () => setState(() {
                    _selectedRouterId = entry.key;
                    _selectedRigId = null;
                  }),
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
                  pulse: _pulseController,
                  onTap: () => setState(() {
                    _selectedRigId = entry.key;
                    _selectedRouterId = null;
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _draggableNode({
    required String kind,
    required String id,
    required double x,
    required double y,
    required Widget child,
  }) {
    final pos = _effectivePos(kind, id, x, y);
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onPanStart: (_) => setState(() {
          _dragKind = kind;
          _dragId = id;
          _dragPos = Offset(x, y);
        }),
        onPanUpdate: (details) {
          if (_dragPos == null) return;
          final scale = _canvasController.value.getMaxScaleOnAxis();
          setState(() => _dragPos = _dragPos! + details.delta / scale);
        },
        onPanEnd: (_) {
          final drop = _dragPos;
          if (drop != null) {
            ServerTycoonScope.of(context).moveNode(kind, id, drop.dx, drop.dy);
          }
          setState(() {
            _dragKind = null;
            _dragId = null;
            _dragPos = null;
          });
        },
        child: child,
      ),
    );
  }

  Widget _buildInspector(BuildContext context, GameState state, AccountLoadResult load, String rigId) {
    final luma = context.luma;
    final rig = state.rigs[rigId]!;
    final rigLoad = load.rigs[rigId];
    final cpu = cpusById[rig.build.cpuId];
    final mobo = motherboardsById[rig.build.motherboardId];

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
                  icon: Icon(Icons.close_rounded, color: luma.textMuted, size: 18),
                  onPressed: () => setState(() => _selectedRigId = null),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  // Services
                  Text('Services', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (rig.services.isEmpty)
                    Text('No services installed', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                  for (final inst in rig.services)
                    _serviceRow(context, rigId, inst, load.instances.where((i) => i.instanceId == inst.instanceId).firstOrNull),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showInstallServiceSheet(context, rigId),
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
                      for (final router in state.routers.values)
                        DropdownMenuItem(value: router.routerId, child: Text(router.name, style: TextStyle(color: luma.textPrimary, fontSize: 13))),
                    ],
                    onChanged: (value) {
                      if (value != null) ServerTycoonScope.of(context).assignRigRouter(rigId, value);
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

  Widget _buildRouterInspector(BuildContext context, GameState state, String routerId) {
    final luma = context.luma;
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
                  icon: Icon(Icons.close_rounded, color: luma.textMuted, size: 18),
                  onPressed: () => setState(() => _selectedRouterId = null),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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

  Widget _buildToolbar(BuildContext context, GameState state, ResearchEffects effects) {
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
          _toolButton(context, Icons.computer_rounded, 'PC Rig', () => _showResult(context, ServerTycoonScope.of(context).addRig())),
          _toolButton(context, Icons.storage_rounded, 'Server', () => _showResult(context, ServerTycoonScope.of(context).addRig(server: true))),
          _toolButton(context, Icons.router_rounded, 'Router', () => _showResult(context, ServerTycoonScope.of(context).addRouter())),
          VerticalDivider(color: luma.border, width: 24),
          _toolButton(context, Icons.science_rounded, 'Research', () => setState(() => _showResearch = true)),
          _toolButton(context, Icons.assignment_rounded, 'Contracts', () => setState(() => _showContracts = true)),
          _toolButton(context, Icons.verified_rounded, 'Licenses', () => setState(() => _showLicenses = true)),
          _toolButton(context, Icons.emoji_events_rounded, 'Achievements', () => setState(() => _showAchievements = true)),
          _toolButton(context, Icons.badge_rounded, 'Staff', () => setState(() => _showStaff = true)),
          VerticalDivider(color: luma.border, width: 24),
          _toolButton(context, Icons.shopping_cart_rounded, 'Shop', () => _showShopCatalog(context)),
          const Spacer(),
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

  Widget _serviceRow(BuildContext context, String rigId, ServiceInstance inst, InstanceResult? result) {
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
                onPressed: () => ServerTycoonScope.of(context).uninstallService(rigId, inst.instanceId),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          Row(
            children: [
              Text('Capacity: ', style: TextStyle(color: luma.textMuted, fontSize: 11)),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: TextEditingController(text: '${inst.capacity}'),
                  style: TextStyle(color: luma.textPrimary, fontSize: 11),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) {
                      ServerTycoonScope.of(context).setServiceCapacity(rigId, inst.instanceId, n);
                    }
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: luma.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: luma.border)),
                  ),
                ),
              ),
              Text(' ${serviceType?.capacityUnitLabel ?? ""}', style: TextStyle(color: luma.textMuted, fontSize: 11)),
              const Spacer(),
              Text('${(sat * 100).toStringAsFixed(0)}% sat', style: TextStyle(color: satColor, fontSize: 11)),
            ],
          ),
          if (result?.bottleneck != null)
            Text('Bottleneck: ${result!.bottleneck!.toUpperCase()}', style: TextStyle(color: Colors.red.shade400, fontSize: 10)),
        ],
      ),
    );
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

  void _showInstallServiceSheet(BuildContext context, String rigId) {
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
        // Achievement unlock toasts
        _AchievementToastStack(),
        // Live incident banners
        _IncidentBannerStack(
          onSelectRig: (id) => setState(() {
            _selectedRigId = id;
            _selectedRouterId = null;
          }),
          onSelectRouter: (id) => setState(() {
            _selectedRouterId = id;
            _selectedRigId = null;
          }),
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
  final Animation<double> pulse;
  final VoidCallback onTap;

  const _RigNode({
    required this.rig,
    this.loadResult,
    required this.selected,
    this.hasActiveIncident = false,
    this.incidentIsPositive = false,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final cpu = cpusById[rig.build.cpuId];
    final isHealthy = loadResult?.localFactor == 1.0;
    final statusColor = isHealthy ? Colors.green.shade400 : Colors.red.shade400;
    final incidentColor = incidentIsPositive ? Colors.amber.shade400 : Colors.red.shade400;
    final highLoad = (loadResult?.utilization.cpu ?? 0) > 0.7;

    return GestureDetector(
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
            Text('${rig.services.length} services', style: TextStyle(color: luma.textMuted, fontSize: 12)),
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

class _ContractsModal extends StatelessWidget {
  final VoidCallback onClose;
  const _ContractsModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final state = repo.state;
    final effects = getResearchEffects(state.research);

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 600,
          height: 500,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: luma.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: luma.border))),
                child: Row(
                  children: [
                    Text('Contracts', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    Text('${state.contracts.length} / ${effects.contractSlots} active', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                    IconButton(icon: Icon(Icons.close_rounded, color: luma.textMuted), onPressed: onClose),
                  ],
                ),
              ),
              // Active contracts
              if (state.contracts.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  alignment: Alignment.centerLeft,
                  child: Text('Active', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                for (final c in state.contracts)
                  _contractTile(context, c, active: true),
              ],
              // Offers
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                alignment: Alignment.centerLeft,
                child: Text('Today\'s Offers', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: repo.contractOffers.length,
                  itemBuilder: (ctx, i) {
                    final offer = repo.contractOffers[i];
                    final company = companiesById[offer.companyId];
                    final service = servicesById[offer.serviceTypeId];
                    final canAccept = state.contracts.length < effects.contractSlots;

                    return ListTile(
                      dense: true,
                      title: Text('${company?.name ?? offer.companyId} — ${service?.name ?? offer.serviceTypeId}', style: TextStyle(color: luma.textPrimary, fontSize: 13)),
                      subtitle: Text('${offer.minCapacity} ${service?.capacityUnitLabel ?? ""} • ${offer.durationDays} days • \$${offer.payoutPerDay.toStringAsFixed(2)}/day + \$${offer.completionBonus.toStringAsFixed(0)} bonus', style: TextStyle(color: luma.textMuted, fontSize: 11)),
                      trailing: canAccept
                          ? TextButton(
                              onPressed: () {
                                final result = repo.acceptContract(offer.offerId);
                                if (!result.ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(result.errors?.join('\n') ?? 'Error'),
                                    backgroundColor: luma.surface,
                                  ));
                                }
                              },
                              child: Text('Accept', style: TextStyle(color: luma.accent, fontSize: 12)),
                            )
                          : Text('Full', style: TextStyle(color: luma.textMuted, fontSize: 11)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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

class _ResearchModal extends StatelessWidget {
  final VoidCallback onClose;
  const _ResearchModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final state = repo.state;

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 500,
          height: 500,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: luma.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: luma.border))),
                child: Row(
                  children: [
                    Text('Research', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    IconButton(icon: Icon(Icons.close_rounded, color: luma.textMuted), onPressed: onClose),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: researchList.length,
                  itemBuilder: (ctx, i) {
                    final project = researchList[i];
                    final owned = state.research.contains(project.id);
                    final canAfford = state.money >= project.cost;
                    final repOk = state.reputation >= project.minReputation;
                    final reqsMet = project.requires.every((r) => state.research.contains(r));

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: owned ? luma.accent.withOpacity(0.1) : luma.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: owned ? luma.accent.withOpacity(0.3) : luma.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(project.name, style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                              if (owned)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
                                  child: Text('OWNED', style: TextStyle(color: Colors.green.shade400, fontSize: 9, fontWeight: FontWeight.w700)),
                                )
                              else
                                TextButton(
                                  onPressed: canAfford && repOk && reqsMet ? () => repo.buyResearch(project.id) : null,
                                  child: Text('\$${project.cost}', style: TextStyle(color: canAfford && repOk && reqsMet ? luma.accent : luma.textMuted, fontSize: 12)),
                                ),
                            ],
                          ),
                          Text(project.description, style: TextStyle(color: luma.textMuted, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text('Category: ${project.category} • Requires ${project.minReputation} rep', style: TextStyle(color: luma.textMuted, fontSize: 10)),
                          if (!reqsMet)
                            Text('Prerequisites not met', style: TextStyle(color: Colors.red.shade400, fontSize: 10)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LicensesModal extends StatelessWidget {
  final VoidCallback onClose;
  const _LicensesModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);
    final state = repo.state;

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 500,
          height: 500,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: luma.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: luma.border))),
                child: Row(
                  children: [
                    Text('Licenses', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    IconButton(icon: Icon(Icons.close_rounded, color: luma.textMuted), onPressed: onClose),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: licenseList.length,
                  itemBuilder: (ctx, i) {
                    final license = licenseList[i];
                    final owned = state.licenses.contains(license.id);
                    final canAfford = state.money >= license.cost;
                    final repOk = state.reputation >= license.minReputation;
                    final reqsMet = license.requires.every((r) => state.licenses.contains(r));

                    return ListTile(
                      dense: true,
                      title: Text(license.name, style: TextStyle(color: luma.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('${license.description}\nRequires ${license.minReputation} rep', style: TextStyle(color: luma.textMuted, fontSize: 11)),
                      trailing: owned
                          ? Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 20)
                          : TextButton(
                              onPressed: canAfford && repOk && reqsMet ? () => repo.buyLicense(license.id) : null,
                              child: Text('\$${license.cost}', style: TextStyle(color: canAfford && repOk && reqsMet ? luma.accent : luma.textMuted, fontSize: 12)),
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 500,
          height: 500,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: luma.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: luma.border))),
                child: Row(
                  children: [
                    Text('Staff', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    IconButton(icon: Icon(Icons.close_rounded, color: luma.textMuted), onPressed: onClose),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
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
                                    onPressed: () => repo.fireStaff(def.id),
                                    child: Text('Fire', style: TextStyle(color: luma.danger, fontSize: 12)),
                                  )
                                : TextButton(
                                    onPressed: canAfford && repOk && licenseOk && researchOk ? () => repo.hireStaff(def.id) : null,
                                    child: Text(
                                      'Hire \$${def.cost}',
                                      style: TextStyle(color: canAfford && repOk && licenseOk && researchOk ? luma.accent : luma.textMuted, fontSize: 12),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 500,
          height: 500,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: luma.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: luma.border))),
                child: Row(
                  children: [
                    Text('Achievements', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    Text('${state.unlockedAchievements.length} / ${achievementDefList.length}', style: TextStyle(color: luma.textMuted, fontSize: 12)),
                    IconButton(icon: Icon(Icons.close_rounded, color: luma.textMuted), onPressed: onClose),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncidentBannerStack extends StatelessWidget {
  final void Function(String rigId) onSelectRig;
  final void Function(String routerId) onSelectRouter;
  const _IncidentBannerStack({required this.onSelectRig, required this.onSelectRouter});

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
  const _IncidentCard({required this.incident, required this.onSelect});

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
          onPressed: onSelect,
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

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 400,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: luma.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Day ${report.day} Report', style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 16),
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
              FilledButton(
                onPressed: onClose,
                style: FilledButton.styleFrom(backgroundColor: luma.accent),
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

// ── Helpers ──

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
