// Auto-ported from Roblox Server Hosting Tycoon
// Main game UI: canvas, inspector, shop, modals.

import 'dart:math' as math;

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

class _ServerTycoonPageState extends State<ServerTycoonPage> {
  // Node dimensions, kept in sync with _RigNode / _RouterNode so wires can
  // attach to tile edges and drags stay aligned under the pointer.
  static const Size _rigSize = Size(160, 74);
  static const Size _routerSize = Size(120, 58);

  String? _selectedRigId;
  String? _selectedRouterId;
  bool _showContracts = false;
  bool _showResearch = false;
  bool _showLicenses = false;
  bool _showDayReport = false;

  final TransformationController _canvasController = TransformationController();

  // Transient drag state — while a node is being dragged we render it (and its
  // wires) from this local position and only commit to the repo on drag end.
  String? _dragKind;
  String? _dragId;
  Offset? _dragPos;

  @override
  void dispose() {
    _canvasController.dispose();
    super.dispose();
  }

  Offset _effectivePos(String kind, String id, double x, double y) =>
      (_dragKind == kind && _dragId == id) ? _dragPos! : Offset(x, y);

  /// Intersection of the segment [rect.center → target] with rect's border,
  /// so wires start/end on the tile edge instead of its center.
  Offset _edgePoint(Rect rect, Offset target) {
    final c = rect.center;
    final dir = target - c;
    if (dir.dx == 0 && dir.dy == 0) return c;
    final sx = dir.dx != 0 ? (rect.width / 2) / dir.dx.abs() : double.infinity;
    final sy = dir.dy != 0 ? (rect.height / 2) / dir.dy.abs() : double.infinity;
    final s = math.min(sx, sy);
    return c + dir * s;
  }

  Widget _buildMain(BuildContext context) {
    final luma = context.luma;
    final repo = ServerTycoonScope.of(context);

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final state = repo.state;
        final load = _calculateLoad(state);
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
    final totalWatts = _getTotalWatts(state, load);
    final internetCost = _getDailyInternetCost(state);

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
          _topStat(context, Icons.attach_money_rounded, '\$${_fmt(state.money)}', Colors.green.shade400),
          _topStat(context, Icons.star_rounded, '${state.reputation.toStringAsFixed(1)} rep', Colors.amber.shade400),
          _topStat(context, Icons.calendar_today_rounded, 'Day ${state.dayCount}', luma.textMuted),
          _topStat(context, Icons.electrical_services_rounded, '${totalWatts.toStringAsFixed(0)}W', luma.textMuted),
          _topStat(context, Icons.wifi_rounded, '\$${_fmt(internetCost)}/day', luma.textMuted),
          _topStat(context, Icons.network_check_rounded, '${load.totalRequiredBandwidth.toStringAsFixed(0)} / ${load.totalBandwidthCapacity.toStringAsFixed(0)} Mbps', load.overloaded ? Colors.red.shade400 : Colors.green.shade400),
          const SizedBox(width: 12),
          _topStat(context, Icons.description_rounded, '${state.contracts.length} / ${effects.contractSlots} contracts', luma.textMuted),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () {
              final report = ServerTycoonScope.of(context).processDay();
              if (report != null) {
                setState(() => _showDayReport = true);
              }
            },
            icon: const Icon(Icons.skip_next_rounded, size: 16),
            label: const Text('End Day'),
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
                      from: _edgePoint(rigRect, routerRect.center),
                      to: _edgePoint(routerRect, rigRect.center),
                      color: load.rigs[rig.rigId]?.localFactor == 1 && load.routers[rig.routerId]?.bandwidthFactor == 1
                          ? Colors.green.shade400
                          : Colors.red.shade400,
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
          const Spacer(),
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
        // Each entry: (id, name, price). Component slots are filtered to hardware
        // that fits this rig's grade; add-on slots (ram/storage) list everything.
        final List<(String, String, int)> items;
        switch (slot) {
          case 'ram':
            items = ramList
                .where((r) => gradeFits('ram', r.id, rig.kind))
                .map((r) => (r.id, r.name, r.price))
                .toList();
            break;
          case 'storage':
            items = storageList.map((d) => (d.id, d.name, d.price)).toList();
            break;
          case 'cpu':
            items = cpuList.where((c) => gradeFits('cpu', c.id, rig.kind)).map((c) => (c.id, c.name, c.price)).toList();
            break;
          case 'motherboard':
            items = motherboardList.where((m) => gradeFits('motherboard', m.id, rig.kind)).map((m) => (m.id, m.name, m.price)).toList();
            break;
          case 'psu':
            items = psuList.where((p) => gradeFits('psu', p.id, rig.kind)).map((p) => (p.id, p.name, p.price)).toList();
            break;
          case 'cooling':
            items = coolingList.where((c) => gradeFits('cooling', c.id, rig.kind)).map((c) => (c.id, c.name, c.price)).toList();
            break;
          case 'nic':
            items = nicList.where((n) => gradeFits('nic', n.id, rig.kind)).map((n) => (n.id, n.name, n.price)).toList();
            break;
          default:
            items = const [];
        }

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
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final (itemId, name, price) = items[i];
                    final canAfford = repo.state.money >= price;

                    return ListTile(
                      dense: true,
                      title: Text(name, style: TextStyle(color: luma.textPrimary, fontSize: 13)),
                      subtitle: Text('\$$price', style: TextStyle(color: canAfford ? Colors.green.shade400 : Colors.red.shade400, fontSize: 12)),
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
                        child: Text(slot == 'ram' || slot == 'storage' ? 'Buy' : 'Swap', style: TextStyle(color: canAfford ? luma.accent : luma.textMuted, fontSize: 12)),
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
  final VoidCallback onTap;

  const _RigNode({required this.rig, this.loadResult, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final cpu = cpusById[rig.build.cpuId];
    final isHealthy = loadResult?.localFactor == 1.0;
    final statusColor = isHealthy ? Colors.green.shade400 : Colors.red.shade400;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? luma.accent.withOpacity(0.15) : luma.surface,
          border: Border.all(color: selected ? luma.accent : luma.border, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(rig.name, style: TextStyle(color: luma.textPrimary, fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: rig.kind == RigKind.server ? Colors.purple.shade900.withOpacity(0.3) : Colors.blue.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
                  child: Text(rig.kind == RigKind.server ? 'SERVER' : 'PC', style: TextStyle(color: rig.kind == RigKind.server ? Colors.purple.shade300 : Colors.blue.shade300, fontSize: 8, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(cpu?.name ?? rig.build.cpuId, style: TextStyle(color: luma.textMuted, fontSize: 10), overflow: TextOverflow.ellipsis, maxLines: 1),
            Text('${rig.services.length} services', style: TextStyle(color: luma.textMuted, fontSize: 10)),
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
  final VoidCallback onTap;

  const _RouterNode({required this.router, this.loadResult, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final plan = internetPlansById[router.internetPlanId];
    final isHealthy = loadResult == null || loadResult!.bandwidthFactor >= 1.0;
    final statusColor = isHealthy ? Colors.green.shade400 : Colors.red.shade400;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? luma.accent.withOpacity(0.15) : luma.surface,
          border: Border.all(color: selected ? luma.accent : luma.border, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(child: Text(router.name, style: TextStyle(color: luma.textPrimary, fontSize: 11, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 2),
            Text(plan?.name ?? router.internetPlanId, style: TextStyle(color: luma.textMuted, fontSize: 9), overflow: TextOverflow.ellipsis),
            Text('${loadResult?.rigCount ?? 0} rigs', style: TextStyle(color: luma.textMuted, fontSize: 9)),
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
  final Offset from;
  final Offset to;
  final Color color;
  _WirePainter({required this.from, required this.to, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 1.5;
    canvas.drawLine(from, to, paint);
  }

  @override
  bool shouldRepaint(covariant _WirePainter oldDelegate) =>
      from != oldDelegate.from || to != oldDelegate.to || color != oldDelegate.color;
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

AccountLoadResult _calculateLoad(GameState state) {
  final rigs = <String, RigInput>{};
  for (final entry in state.rigs.entries) {
    rigs[entry.key] = RigInput(build: entry.value.build, services: entry.value.services, routerId: entry.value.routerId);
  }
  final routers = <String, RouterInput>{};
  for (final entry in state.routers.entries) {
    routers[entry.key] = RouterInput(internetPlanId: entry.value.internetPlanId);
  }
  return calculateAccountLoad(rigs, routers);
}

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
