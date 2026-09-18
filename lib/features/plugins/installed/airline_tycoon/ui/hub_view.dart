import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../airline_tycoon_repository.dart';
import '../data/buildings.dart';
import '../sim/hub.dart';
import '../sim/iso.dart';
import 'hub_painter.dart';
import 'money.dart';

/// The isometric hub builder.
class HubView extends StatefulWidget {
  const HubView({super.key, required this.repository});

  final AirlineTycoonRepository repository;

  @override
  State<HubView> createState() => _HubViewState();
}

class _HubViewState extends State<HubView> {
  final _controller = TransformationController();
  final _geometry = HubGeometry();

  /// Pointer position lives in a notifier rather than State, so moving the
  /// mouse repaints the canvas without rebuilding the page around it.
  final _hover = ValueNotifier<({int x, int y})?>(null);

  BuildingKind? _placing;
  bool _demolishing = false;
  int _rotation = 0;
  PlacedBuilding? _selected;

  int _builtRevision = -1;
  int _builtGrid = -1;
  HubPalette? _builtPalette;
  Offset _origin = Offset.zero;
  Size _canvasSize = Size.zero;

  @override
  void dispose() {
    _controller.dispose();
    _hover.dispose();
    super.dispose();
  }

  HubPalette _paletteOf(LumaPalette luma) => HubPalette(
        ground: Color.alphaBlend(luma.accentSubtle, luma.surface),
        groundEdge: luma.surfaceHover,
        asphalt: luma.border,
        concrete: luma.textMuted,
        glass: luma.accent,
        metal: luma.textSecondary,
        grid: luma.border,
      );

  void _rebuildIfNeeded(HubPalette palette) {
    final state = widget.repository.state;
    if (_builtRevision == state.hubRevision &&
        _builtGrid == state.gridSize &&
        _builtPalette == palette) {
      return;
    }

    final layout = IsoCamera.layout(state.gridSize);
    _origin = layout.origin;
    _canvasSize = layout.size;
    _geometry.rebuild(
      gridSize: state.gridSize,
      buildings: state.buildings,
      camera: IsoCamera(origin: _origin),
      palette: palette,
    );
    _builtRevision = state.hubRevision;
    _builtGrid = state.gridSize;
    _builtPalette = palette;
  }

  PlacedBuilding? _ghostAt(({int x, int y})? tile) {
    final kind = _placing;
    if (kind == null || tile == null) return null;
    return PlacedBuilding(
      kind: kind,
      x: tile.x,
      y: tile.y,
      rotation: _rotation,
    );
  }

  void _onTapTile(({int x, int y})? tile) {
    if (tile == null) return;
    final repo = widget.repository;

    if (_demolishing) {
      _report(repo.demolishAt(tile.x, tile.y));
      return;
    }

    final kind = _placing;
    if (kind != null) {
      final result =
          repo.placeBuilding(kind, tile.x, tile.y, rotation: _rotation);
      _report(result);
      return;
    }

    setState(() {
      _selected = HubGrid.at(tile, repo.state.buildings);
    });
  }

  void _report(ActionResult result) {
    if (result.success || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'That did not work.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final palette = _paletteOf(luma);
    _rebuildIfNeeded(palette);

    final phone = context.isPhoneWidth;
    final canvas = _buildCanvas(luma, palette);

    return Column(
      children: [
        _CapacityStrip(repository: widget.repository),
        Expanded(
          child: phone
              ? canvas
              : Row(
                  children: [
                    Expanded(child: canvas),
                    SizedBox(width: 196, child: _buildPalette(luma, false)),
                  ],
                ),
        ),
        if (phone) SizedBox(height: 92, child: _buildPalette(luma, true)),
      ],
    );
  }

  Widget _buildCanvas(LumaPalette luma, HubPalette palette) {
    final camera = IsoCamera(origin: _origin);
    final gridSize = widget.repository.state.gridSize;

    return ClipRect(
      child: InteractiveViewer(
        transformationController: _controller,
        boundaryMargin: const EdgeInsets.all(400),
        minScale: 0.35,
        maxScale: 2.5,
        constrained: false,
        child: SizedBox(
          width: _canvasSize.width,
          height: _canvasSize.height,
          child: MouseRegion(
            // localPosition is already canvas space inside the viewer's
            // child, so no matrix inversion is needed here.
            onHover: (event) =>
                _hover.value = camera.tileAt(event.localPosition, gridSize),
            onExit: (_) => _hover.value = null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final tile = camera.tileAt(details.localPosition, gridSize);
                _hover.value = tile;
                _onTapTile(tile);
              },
              child: ValueListenableBuilder<({int x, int y})?>(
                valueListenable: _hover,
                builder: (context, hover, _) {
                  final ghost = _ghostAt(hover);
                  final valid = ghost == null ||
                      HubGrid.check(
                            ghost,
                            gridSize,
                            widget.repository.state.buildings,
                          ) ==
                          null;
                  return RepaintBoundary(
                    child: CustomPaint(
                      isComplex: true,
                      willChange: true,
                      size: _canvasSize,
                      painter: HubPainter(
                        geometry: _geometry,
                        generation: _geometry.generation,
                        camera: camera,
                        gridSize: gridSize,
                        hoverTile: hover,
                        ghost: ghost,
                        ghostValid: valid,
                        ghostColor: luma.accent,
                        blockedColor: luma.danger,
                        hoverColor: luma.accentHover,
                        selection: _selected,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPalette(LumaPalette luma, bool horizontal) {
    final repo = widget.repository;
    final tiles = <Widget>[
      for (final def in kBuildingCatalog)
        _PaletteTile(
          def: def,
          horizontal: horizontal,
          selected: _placing == def.kind,
          affordable: repo.state.cashEur >= def.costEur,
          onTap: () => setState(() {
            _demolishing = false;
            _selected = null;
            _placing = _placing == def.kind ? null : def.kind;
            _rotation = 0;
          }),
        ),
    ];

    final tools = <Widget>[
      _ToolButton(
        icon: Icons.rotate_90_degrees_cw_rounded,
        label: 'Rotate',
        horizontal: horizontal,
        active: _rotation != 0,
        enabled: _placing != null && buildingDef(_placing!).rotatable,
        onTap: () => setState(() => _rotation = _rotation == 0 ? 1 : 0),
      ),
      _ToolButton(
        icon: Icons.delete_outline_rounded,
        label: 'Demolish',
        horizontal: horizontal,
        active: _demolishing,
        enabled: true,
        onTap: () => setState(() {
          _placing = null;
          _selected = null;
          _demolishing = !_demolishing;
        }),
      ),
    ];

    if (horizontal) {
      return Container(
        decoration: BoxDecoration(
          color: luma.surface,
          border: Border(top: BorderSide(color: luma.border)),
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            ...tools,
            const SizedBox(width: 8),
            ...tiles,
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(left: BorderSide(color: luma.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          Row(children: [for (final tool in tools) Expanded(child: tool)]),
          const SizedBox(height: 10),
          ...tiles,
        ],
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.def,
    required this.horizontal,
    required this.selected,
    required this.affordable,
    required this.onTap,
  });

  final BuildingDef def;
  final bool horizontal;
  final bool selected;
  final bool affordable;
  final VoidCallback onTap;

  static IconData iconFor(BuildingKind kind) => switch (kind) {
        BuildingKind.apron => Icons.grid_on_rounded,
        BuildingKind.gate => Icons.airline_seat_recline_normal_rounded,
        BuildingKind.terminal => Icons.business_rounded,
        BuildingKind.runwayShort ||
        BuildingKind.runwayMedium ||
        BuildingKind.runwayLong =>
          Icons.horizontal_rule_rounded,
        BuildingKind.hangar => Icons.home_work_rounded,
        BuildingKind.fuelDepot => Icons.local_gas_station_rounded,
        BuildingKind.cargo => Icons.inventory_2_rounded,
        BuildingKind.lounge => Icons.weekend_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final label = Text(
      def.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: affordable ? luma.textPrimary : luma.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
    final price = Text(
      fmtMoney(def.costEur),
      style: TextStyle(
        // Unaffordable is said in words as well as colour, so the state
        // survives a colour-blind reader and a greyscale screenshot.
        color: affordable ? luma.textSecondary : luma.danger,
        fontSize: 11,
      ),
    );

    final content = horizontal
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconFor(def.kind),
                  size: 20, color: selected ? luma.onAccent : luma.accent),
              const SizedBox(height: 4),
              label,
              price,
            ],
          )
        : Row(
            children: [
              Icon(iconFor(def.kind),
                  size: 18, color: selected ? luma.onAccent : luma.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, price],
                ),
              ),
            ],
          );

    return Tooltip(
      message: '${def.name} — ${def.blurb}',
      child: Semantics(
        button: true,
        selected: selected,
        label: '${def.name}, ${fmtExactMoney(def.costEur)}'
            '${affordable ? '' : ', too expensive'}',
        child: InkWell(
          onTap: onTap,
          borderRadius: decor.cardBorderRadius,
          child: Container(
            // A minimum rather than a fixed height: the tile still clears the
            // 44px touch target, but can grow instead of overflowing when the
            // label wraps or the reader has scaled their text up.
            width: horizontal ? 96 : null,
            constraints: const BoxConstraints(minHeight: 52),
            margin: horizontal
                ? const EdgeInsets.only(right: 8)
                : const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? luma.accent : luma.surfaceHover,
              borderRadius: decor.cardBorderRadius,
              border: Border.all(
                color: selected ? luma.accent : luma.border,
                width: decor.borderWidth,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.horizontal,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool horizontal;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final colour = !enabled
        ? luma.textMuted
        : active
            ? luma.onAccent
            : luma.textSecondary;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: active,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: decor.buttonBorderRadius,
          child: Container(
            width: horizontal ? 60 : null,
            // Minimum, not fixed — an icon stacked over a label is too tight
            // to pin to exactly 44px once text metrics and scaling are in.
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(vertical: 4),
            margin: horizontal
                ? const EdgeInsets.only(right: 8)
                : const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: active ? luma.accent : luma.surfaceHover,
              borderRadius: decor.buttonBorderRadius,
              border: Border.all(color: luma.border, width: decor.borderWidth),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: colour),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: colour),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the field can currently do, above the canvas.
class _CapacityStrip extends StatelessWidget {
  const _CapacityStrip({required this.repository});

  final AirlineTycoonRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final effects = repository.hubEffects;
    final used = repository.activeRouteCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Stat(
              icon: Icons.airline_seat_recline_normal_rounded,
              label: 'Gates',
              value: '$used / ${effects.activeGates}',
            ),
            if (effects.inactiveGates > 0)
              _Stat(
                icon: Icons.warning_amber_rounded,
                label: 'Not on a terminal',
                value: '${effects.inactiveGates}',
                tone: luma.warning,
              ),
            _Stat(
              icon: Icons.straighten_rounded,
              label: 'Runway',
              value: effects.maxRunwayM == 0
                  ? 'none'
                  : '${fmtCount(effects.maxRunwayM)} m',
            ),
            _Stat(
              icon: Icons.build_rounded,
              label: 'Maintenance',
              value: '${((1 - effects.maintenanceMultiplier) * 100).round()}%',
            ),
            _Stat(
              icon: Icons.local_gas_station_rounded,
              label: 'Fuel',
              value: '${((1 - effects.fuelMultiplier) * 100).round()}%',
            ),
            _Stat(
              icon: Icons.receipt_long_rounded,
              label: 'Upkeep',
              value: '${fmtMoney(effects.upkeepPerDayEur)}/day',
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final colour = tone ?? luma.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Row(
        children: [
          Icon(icon, size: 15, color: colour),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: luma.textMuted)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tone ?? luma.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
