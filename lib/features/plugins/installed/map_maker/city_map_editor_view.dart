import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'city_map_models.dart';
import 'city_map_overlays.dart';
import 'city_map_painter.dart';
import 'city_plan_controller.dart';
import 'city_plan_inspector.dart';
import 'map_maker_models.dart';
import 'map_maker_store.dart';

class CityMapEditorView extends StatefulWidget {
  const CityMapEditorView({
    super.key,
    required this.save,
    required this.onBack,
    this.store,
  });

  final MapMakerSave save;
  final VoidCallback onBack;
  final MapMakerStore? store;

  @override
  State<CityMapEditorView> createState() => _CityMapEditorViewState();
}

class _CityMapEditorViewState extends State<CityMapEditorView> {
  final _transform = TransformationController();
  final _canvasFocus = FocusNode();
  final _titleFocus = FocusNode();
  late final CityPlanController _plan;
  late final TextEditingController _title;
  Size _viewport = Size.zero;
  Offset? _hover;
  Offset? _hoverViewport;
  Offset _dragOffset = Offset.zero;
  Offset _gestureAnchor = Offset.zero;
  double _gestureScale = 1;
  bool _gesturePanning = false;
  bool _pinching = false;
  bool _spacePanning = false;
  bool _middlePanning = false;
  bool _measuring = false;
  Offset? _measureStart;
  Offset? _measureEnd;
  bool _showGrid = true;
  bool _showRoads = true;
  bool _showBuildings = true;
  bool _showParcels = true;
  bool _showConnections = true;
  bool _showJunctions = false;
  bool _showLabels = true;
  bool _centered = false;

  @override
  void initState() {
    super.initState();
    _plan = CityPlanController(
      save: widget.save,
      store: widget.store ?? MapMakerStore.instance,
    )..addListener(_changed);
    _title = TextEditingController(text: widget.save.title);
    _transform.addListener(_onTransform);
  }

  void _onTransform() {
    _plan.viewScale = _transform.value.getMaxScaleOnAxis();
    _hover = _hoverViewport == null
        ? null
        : _transform.toScene(_hoverViewport!);
    _plan.updateHover(_hover);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _plan.removeListener(_changed);
    _plan.commitFeatureNames(notify: false);
    _plan.endMove();
    _plan.rename(_title.text);
    unawaited(_plan.store.flush());
    _plan.dispose();
    _title.dispose();
    _transform.removeListener(_onTransform);
    _transform.dispose();
    _canvasFocus.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _save({bool leave = false}) async {
    _plan.commitFeatureNames();
    _plan.endMove();
    if (_plan.draftRoad.isNotEmpty && !_plan.finishRoad()) {
      _roadError();
      return;
    }
    _plan.rename(_title.text);
    await _plan.store.flush();
    if (!mounted) return;
    if (leave) {
      widget.onBack();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).mapMakerCitySaved)));
    }
  }

  void _viewAt(Offset center, double scale) {
    _transform.value = Matrix4.identity()
      ..translateByDouble(_viewport.width / 2, _viewport.height / 2, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }

  void _fit() {
    if (_viewport.isEmpty) return;
    final content = _plan.map.contentBounds;
    if (content == null) {
      _viewAt(Offset.zero, 1);
    } else {
      _fitBounds(content);
    }
  }

  void _fitBounds(Rect bounds) {
    final available = Size(
      math.max(100, _viewport.width - 128),
      math.max(100, _viewport.height - 160),
    );
    final scale = math.min(
      available.width / math.max(bounds.width, 96),
      available.height / math.max(bounds.height, 96),
    );
    _viewAt(bounds.center, scale.clamp(.000001, 1.5));
  }

  Rect get _visibleWorldBounds => Rect.fromPoints(
    _transform.toScene(Offset.zero),
    _transform.toScene(Offset(_viewport.width, _viewport.height)),
  );

  void _zoom(double factor) {
    _zoomAt(factor, _viewport.center(Offset.zero));
  }

  void _zoomAt(double factor, Offset focalPoint) {
    final anchor = _transform.toScene(focalPoint);
    final scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      .000001,
      6.0,
    );
    _setCamera(focalPoint - anchor * scale, scale);
  }

  void _setCamera(Offset translation, double scale) {
    _transform.value = Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _panBy(Offset delta) {
    final matrix = _transform.value;
    _setCamera(
      Offset(matrix.storage[12], matrix.storage[13]) + delta,
      matrix.getMaxScaleOnAxis(),
    );
  }

  bool get _panning => _spacePanning || _plan.tool == CityPlanTool.pan;

  void _startGesture(ScaleStartDetails details) {
    _canvasFocus.requestFocus();
    _gestureScale = _plan.viewScale;
    _gestureAnchor = _transform.toScene(details.localFocalPoint);
    _gesturePanning = _panning;
    _pinching = details.pointerCount > 1;
    if (!_gesturePanning &&
        !_pinching &&
        !_measuring &&
        _plan.tool == CityPlanTool.select) {
      _plan.beginMove(_gestureAnchor);
      _dragOffset = _plan.movingRoadVertex
          ? Offset.zero
          : (_plan.selectedBuilding?.position ?? _gestureAnchor) -
                _gestureAnchor;
    }
  }

  void _updateGesture(ScaleUpdateDetails details) {
    if (details.pointerCount > 1 ||
        details.scale != 1 ||
        details.pointerCount == 0) {
      if (!_pinching) _plan.endMove();
      _pinching = true;
      final scale = (_gestureScale * details.scale).clamp(.000001, 6.0);
      _setCamera(details.localFocalPoint - _gestureAnchor * scale, scale);
    } else if (_gesturePanning) {
      _panBy(details.focalPointDelta);
    } else if (!_pinching && !_measuring && _plan.tool == CityPlanTool.select) {
      _plan.moveTo(_transform.toScene(details.localFocalPoint) + _dragOffset);
    }
  }

  void _chooseTool(CityPlanTool tool) {
    setState(() => _measuring = false);
    _plan.setTool(tool);
  }

  void _toggleMeasure() {
    _plan.setTool(CityPlanTool.select);
    setState(() {
      _measuring = !_measuring;
      _measureStart = null;
      _measureEnd = null;
    });
  }

  void _duplicate() {
    if (!_plan.duplicateSelection()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).mapMakerCityDuplicateFailed)),
      );
    }
  }

  void _finishRoad() {
    if (!_plan.finishRoad()) {
      _roadError();
    }
  }

  void _roadError() {
    final t = L.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _plan.curvedRoad
              ? t.mapMakerCityCurveHint
              : t.mapMakerCityRoadDraftHint,
        ),
      ),
    );
  }

  void _tapCanvas(Offset position) {
    _canvasFocus.requestFocus();
    if (_panning) return;
    if (_measuring) {
      setState(() {
        final point = _plan.snappedPoint(position);
        if (_measureStart == null || _measureEnd != null) {
          _measureStart = point;
          _measureEnd = null;
        } else {
          _measureEnd = point;
        }
      });
      return;
    }
    if (_plan.tool == CityPlanTool.building &&
        !_plan.previewPlacement(position).valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).mapMakerCityInvalidPlacement)),
      );
    }
    _plan.tap(position);
  }

  Future<void> _openInspector() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: CityPlanInspector(plan: _plan),
        ),
      ),
    );
    if (mounted) _plan.commitFeatureNames();
  }

  Widget _layers({VoidCallback? refresh}) {
    final t = L.of(context);
    final colors = context.luma;
    Widget layer(
      String key,
      IconData icon,
      String label,
      bool value,
      ValueChanged<bool> change,
    ) => SizedBox(
      height: 30,
      child: Row(
        children: [
          Checkbox(
            key: ValueKey(key),
            value: value,
            visualDensity: VisualDensity.compact,
            onChanged: (next) {
              setState(() => change(next ?? false));
              refresh?.call();
            },
          ),
          Icon(icon, size: 15, color: colors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(
            t.mapMakerCityLayers,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        layer(
          'city-layer-buildings',
          Icons.square_outlined,
          t.mapMakerCityBuildings,
          _showBuildings,
          (value) {
            _showBuildings = value;
            _plan.buildingsVisible = value;
            if (!value && _plan.selectedBuilding != null) {
              _plan.selectedId = null;
            }
          },
        ),
        layer(
          'city-layer-parcels',
          Icons.grid_on_rounded,
          t.mapMakerCityParcels,
          _showParcels,
          (value) => _showParcels = value,
        ),
        layer(
          'city-layer-roads',
          Icons.route_outlined,
          t.mapMakerCityRoads,
          _showRoads,
          (value) {
            _showRoads = value;
            _plan.roadsVisible = value;
            if (!value && _plan.selectedRoad != null) _plan.selectedId = null;
          },
        ),
        layer(
          'city-layer-access',
          Icons.link_rounded,
          t.mapMakerCityConnections,
          _showConnections,
          (value) => _showConnections = value,
        ),
        layer(
          'city-layer-junctions',
          Icons.control_point_rounded,
          t.mapMakerCityJunctions,
          _showJunctions,
          (value) => _showJunctions = value,
        ),
        layer(
          'city-layer-grid',
          Icons.grid_4x4_rounded,
          t.mapMakerCityGrid,
          _showGrid,
          (value) => _showGrid = value,
        ),
      ],
    );
  }

  void _openLayers() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .8,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 18),
              child: _layers(refresh: () => refresh(() {})),
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyUpEvent && key == LogicalKeyboardKey.space) {
      if (_spacePanning) setState(() => _spacePanning = false);
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final control =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (control && key == LogicalKeyboardKey.keyS) {
      unawaited(_save());
      return KeyEventResult.handled;
    }
    if (_titleFocus.hasFocus ||
        FocusManager.instance.primaryFocus?.context
                ?.findAncestorStateOfType<EditableTextState>() !=
            null) {
      return KeyEventResult.ignored;
    }
    if (control && key == LogicalKeyboardKey.keyZ) {
      HardwareKeyboard.instance.isShiftPressed ? _plan.redo() : _plan.undo();
    } else if (control && key == LogicalKeyboardKey.keyY) {
      _plan.redo();
    } else if (key == LogicalKeyboardKey.escape) {
      setState(() {
        _measuring = false;
        _measureStart = null;
        _measureEnd = null;
      });
      _plan.setTool(CityPlanTool.select);
    } else if (key == LogicalKeyboardKey.enter &&
        _plan.tool == CityPlanTool.road) {
      _finishRoad();
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _plan.deleteSelection();
    } else if (key == LogicalKeyboardKey.keyR) {
      _plan.rotate();
    } else if (control && key == LogicalKeyboardKey.keyD) {
      if (_plan.canDuplicateSelection) _duplicate();
    } else if (key == LogicalKeyboardKey.space) {
      setState(() => _spacePanning = true);
    } else if (key == LogicalKeyboardKey.keyV) {
      _chooseTool(CityPlanTool.select);
    } else if (key == LogicalKeyboardKey.keyH) {
      _chooseTool(CityPlanTool.pan);
    } else if (key == LogicalKeyboardKey.keyM) {
      _toggleMeasure();
    } else if (key == LogicalKeyboardKey.keyF) {
      final selection = HardwareKeyboard.instance.isShiftPressed
          ? _plan.selectionBounds
          : null;
      selection == null ? _fit() : _fitBounds(selection);
    } else if (key == LogicalKeyboardKey.keyG) {
      setState(() => _showGrid = !_showGrid);
    } else if (key == LogicalKeyboardKey.home) {
      _viewAt(Offset.zero, 1);
    } else if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add) {
      _zoom(1.25);
    } else if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      _zoom(1 / 1.25);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _showShortcuts() {
    final t = L.of(context);
    final rows = <(String, String)>[
      (t.mapMakerCitySelect, 'V'),
      (t.mapMakerCityPan, 'H / Space'),
      (t.mapMakerCityMeasure, 'M'),
      (t.mapMakerCityResetView, 'F'),
      (t.mapMakerCityFitSelection, 'Shift + F'),
      (t.mapMakerCityOrigin, 'Home'),
      (t.mapMakerCityGrid, 'G'),
      (t.mapMakerCityDuplicate, 'Ctrl / ⌘ + D'),
      (t.mapMakerCityRotate, 'R'),
      (t.mapMakerCityDelete, 'Delete'),
      (t.mapMakerCityUndo, 'Ctrl / ⌘ + Z'),
      (t.mapMakerCityRedo, 'Ctrl / ⌘ + Shift + Z'),
      (t.mapMakerCityFinishRoad, 'Enter'),
      (t.mapMakerCityCancelRoad, 'Esc'),
      (t.mapMakerCitySave, 'Ctrl / ⌘ + S'),
    ];
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.mapMakerCityShortcuts),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(child: Text(row.$1)),
                        const SizedBox(width: 16),
                        Text(
                          row.$2,
                          style: TextStyle(
                            color: context.luma.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.commonClose),
          ),
        ],
      ),
    );
  }

  IconData _roadIcon(CityRoadKind kind) => switch (kind) {
    CityRoadKind.street => Icons.add_road_rounded,
    CityRoadKind.avenue => Icons.signpost_rounded,
    CityRoadKind.highway => Icons.edit_road_rounded,
    CityRoadKind.pedestrian => Icons.directions_walk_rounded,
  };

  IconData _buildingIcon(CityBuildingKind kind) => switch (kind) {
    CityBuildingKind.house => Icons.cottage_rounded,
    CityBuildingKind.apartment => Icons.apartment_rounded,
    CityBuildingKind.shop => Icons.storefront_rounded,
    CityBuildingKind.office => Icons.business_rounded,
    CityBuildingKind.school => Icons.school_rounded,
    CityBuildingKind.hospital => Icons.local_hospital_rounded,
    CityBuildingKind.park => Icons.park_rounded,
    CityBuildingKind.tree => Icons.forest_rounded,
  };

  Widget _piece({
    required String id,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool compact,
  }) {
    final luma = context.luma;
    return Padding(
      padding: EdgeInsets.only(right: compact ? 4 : 0, bottom: 0),
      child: Material(
        color: selected ? luma.accentSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey(id),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? luma.accent : luma.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? luma.accent : luma.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _palette(bool compact) {
    final t = L.of(context);
    final roads = [
      for (final kind in CityRoadKind.values)
        _piece(
          id: 'city-road-${kind.name}',
          icon: _roadIcon(kind),
          label: t.mapMakerCityRoadType(kind.name),
          selected: _plan.tool == CityPlanTool.road && _plan.roadKind == kind,
          onTap: () {
            setState(() => _measuring = false);
            _plan.chooseRoad(kind);
          },
          compact: compact,
        ),
    ];
    final buildings = [
      for (final kind in CityBuildingKind.values)
        _piece(
          id: 'city-building-${kind.name}',
          icon: _buildingIcon(kind),
          label: t.mapMakerCityBuildingType(kind.name),
          selected:
              _plan.tool == CityPlanTool.building && _plan.buildingKind == kind,
          onTap: () {
            setState(() => _measuring = false);
            _plan.chooseBuilding(kind);
          },
          compact: compact,
        ),
    ];
    if (compact) {
      return Container(
        color: context.luma.surface,
        height: 48,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              ...roads,
              const VerticalDivider(indent: 12, endIndent: 12),
              ...buildings,
            ],
          ),
        ),
      );
    }
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
      child: Text(
        text,
        style: TextStyle(
          color: context.luma.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: context.luma.surface,
        border: Border(right: BorderSide(color: context.luma.border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _layers(),
            const Divider(height: 20),
            heading(t.mapMakerCityRoads),
            ...roads,
            const Divider(),
            heading(t.mapMakerCityBuildings),
            ...buildings,
          ],
        ),
      ),
    );
  }

  Widget _action(
    String key,
    IconData icon,
    String label,
    VoidCallback? onPressed, {
    bool selected = false,
  }) {
    return IconButton(
      key: ValueKey(key),
      tooltip: label,
      onPressed: onPressed,
      isSelected: selected,
      selectedIcon: Icon(icon, color: context.luma.accent),
      icon: Icon(icon),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: selected ? context.luma.accentSubtle : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _moreTools() {
    final t = L.of(context);
    PopupMenuItem<VoidCallback> item(
      String id,
      IconData icon,
      String label,
      VoidCallback? action,
    ) => PopupMenuItem(
      key: ValueKey('city-more-$id'),
      value: action,
      enabled: action != null,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
    return PopupMenuButton<VoidCallback>(
      key: const ValueKey('city-more'),
      tooltip: t.commonMore,
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        item(
          'properties',
          Icons.tune_rounded,
          t.mapMakerCityProperties,
          _openInspector,
        ),
        item(
          'layers',
          Icons.layers_outlined,
          t.mapMakerCityLayers,
          _openLayers,
        ),
        const PopupMenuDivider(),
        item(
          'measure',
          Icons.straighten_rounded,
          t.mapMakerCityMeasure,
          _toggleMeasure,
        ),
        item(
          'duplicate',
          Icons.content_copy_rounded,
          t.mapMakerCityDuplicate,
          _plan.canDuplicateSelection ? _duplicate : null,
        ),
        item(
          'fit',
          Icons.center_focus_strong_rounded,
          t.mapMakerCityResetView,
          _fit,
        ),
        item(
          'fit-selection',
          Icons.filter_center_focus_rounded,
          t.mapMakerCityFitSelection,
          _plan.selectionBounds == null
              ? null
              : () => _fitBounds(_plan.selectionBounds!),
        ),
        item(
          'origin',
          Icons.my_location_rounded,
          t.mapMakerCityOrigin,
          () => _viewAt(Offset.zero, 1),
        ),
        const PopupMenuDivider(),
        item(
          'labels',
          Icons.label_outline_rounded,
          t.mapMakerCityLabels,
          () => setState(() => _showLabels = !_showLabels),
        ),
        item(
          'shortcuts',
          Icons.keyboard_outlined,
          t.mapMakerCityShortcuts,
          _showShortcuts,
        ),
      ],
    );
  }

  Widget _toolbar(bool compact) {
    final t = L.of(context);
    final tools = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _action(
            'city-select',
            Icons.near_me_outlined,
            t.mapMakerCitySelect,
            () => _chooseTool(CityPlanTool.select),
            selected: !_measuring && _plan.tool == CityPlanTool.select,
          ),
          _action(
            'city-pan',
            Icons.pan_tool_outlined,
            t.mapMakerCityPan,
            () => _chooseTool(CityPlanTool.pan),
            selected: !_measuring && _plan.tool == CityPlanTool.pan,
          ),
          const VerticalDivider(indent: 10, endIndent: 10),
          TextButton.icon(
            key: const ValueKey('city-straight'),
            onPressed: () => _plan.setCurvedRoad(false),
            icon: Icon(
              Icons.straight_rounded,
              size: 18,
              color: !_plan.curvedRoad
                  ? context.luma.accent
                  : context.luma.textMuted,
            ),
            label: Text(
              t.mapMakerCityStraight,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton.icon(
            key: const ValueKey('city-curve'),
            onPressed: () => _plan.setCurvedRoad(true),
            icon: Icon(
              Icons.gesture_rounded,
              size: 18,
              color: _plan.curvedRoad
                  ? context.luma.accent
                  : context.luma.textMuted,
            ),
            label: Text(
              t.mapMakerCityCurved,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          _action(
            'city-snap',
            Icons.settings_input_composite_rounded,
            t.mapMakerCitySnap,
            () => _plan.setSnapping(enabled: !_plan.snapEnabled),
            selected: _plan.snapEnabled,
          ),
          _action(
            'city-frontage',
            Icons.add_home_work_outlined,
            t.mapMakerCityAutoConnect,
            () => _plan.setConnectHousing(!_plan.connectHousing),
            selected: _plan.connectHousing,
          ),
          const VerticalDivider(indent: 10, endIndent: 10),
          _action(
            'city-undo',
            Icons.undo_rounded,
            t.mapMakerCityUndo,
            _plan.canUndo ? _plan.undo : null,
          ),
          _action(
            'city-redo',
            Icons.redo_rounded,
            t.mapMakerCityRedo,
            _plan.canRedo ? _plan.redo : null,
          ),
          _action(
            'city-rotate',
            Icons.rotate_right_rounded,
            t.mapMakerCityRotate,
            _plan.tool == CityPlanTool.building ||
                    _plan.selectedBuilding != null
                ? _plan.rotate
                : null,
          ),
          _action(
            'city-duplicate',
            Icons.content_copy_rounded,
            t.mapMakerCityDuplicate,
            _plan.canDuplicateSelection ? _duplicate : null,
          ),
          _action(
            'city-delete',
            Icons.delete_outline_rounded,
            t.mapMakerCityDelete,
            () {
              if (_plan.selectedId != null) {
                _plan.deleteSelection();
              } else {
                _chooseTool(CityPlanTool.delete);
              }
            },
            selected: _plan.tool == CityPlanTool.delete,
          ),
          const VerticalDivider(indent: 10, endIndent: 10),
          _action(
            'city-grid',
            Icons.grid_4x4_rounded,
            t.mapMakerCityGrid,
            () => setState(() => _showGrid = !_showGrid),
            selected: _showGrid,
          ),
          _action(
            'city-zoom-out',
            Icons.remove_rounded,
            t.mapMakerCityZoomOut,
            () => _zoom(1 / 1.25),
          ),
          _action(
            'city-zoom-in',
            Icons.add_rounded,
            t.mapMakerCityZoomIn,
            () => _zoom(1.25),
          ),
          _action(
            'city-fit',
            Icons.center_focus_strong_rounded,
            t.mapMakerCityResetView,
            _fit,
          ),
          _action(
            'city-fit-selection',
            Icons.filter_center_focus_rounded,
            t.mapMakerCityFitSelection,
            _plan.selectionBounds == null
                ? null
                : () => _fitBounds(_plan.selectionBounds!),
          ),
          _action(
            'city-origin',
            Icons.my_location_rounded,
            t.mapMakerCityOrigin,
            () => _viewAt(Offset.zero, 1),
          ),
          _action(
            'city-measure',
            Icons.straighten_rounded,
            t.mapMakerCityMeasure,
            _toggleMeasure,
            selected: _measuring,
          ),
          const VerticalDivider(indent: 10, endIndent: 10),
          _action(
            'city-layers',
            Icons.layers_outlined,
            t.mapMakerCityLayers,
            _openLayers,
          ),
          _action(
            'city-properties',
            Icons.tune_rounded,
            t.mapMakerCityProperties,
            _openInspector,
          ),
          _action(
            'city-labels',
            Icons.label_outline_rounded,
            t.mapMakerCityLabels,
            () => setState(() => _showLabels = !_showLabels),
            selected: _showLabels,
          ),
          _action(
            'city-shortcuts',
            Icons.keyboard_outlined,
            t.mapMakerCityShortcuts,
            _showShortcuts,
          ),
        ],
      ),
    );
    return Container(
      color: context.luma.surface,
      height: 48,
      child: Row(
        children: [
          Expanded(child: tools),
          if (compact) _moreTools(),
        ],
      ),
    );
  }

  Widget _canvas() {
    final t = L.of(context);
    final placement =
        !_measuring && _plan.tool == CityPlanTool.building && _hover != null
        ? _plan.previewPlacement(_hover!)
        : null;
    final hint = _measuring
        ? t.mapMakerCityMeasureHint
        : switch (_plan.tool) {
            CityPlanTool.road =>
              _plan.curvedRoad
                  ? t.mapMakerCityCurveHint
                  : t.mapMakerCityRoadHint,
            CityPlanTool.building =>
              placement != null && !placement.valid
                  ? t.mapMakerCityInvalidPlacement
                  : t.mapMakerCityAutoConnectHint,
            CityPlanTool.pan => t.mapMakerCityPanHint,
            CityPlanTool.delete => t.mapMakerCityDelete,
            CityPlanTool.select => t.mapMakerCitySelectHint,
          };
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        if (!_centered && !_viewport.isEmpty) {
          _centered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fit();
          });
        }
        final measureEnd =
            _measureEnd ?? _plan.hoverSnap?.position ?? _hover ?? _measureStart;
        return Stack(
          children: [
            Positioned.fill(
              child: MouseRegion(
                cursor: _middlePanning || (_panning && _gesturePanning)
                    ? SystemMouseCursors.grabbing
                    : _panning
                    ? SystemMouseCursors.grab
                    : _measuring ||
                          _plan.tool == CityPlanTool.road ||
                          _plan.tool == CityPlanTool.building
                    ? SystemMouseCursors.precise
                    : SystemMouseCursors.basic,
                onHover: (event) {
                  _hoverViewport = event.localPosition;
                  _hover = _transform.toScene(event.localPosition);
                  _plan.updateHover(_hover);
                },
                onExit: (_) {
                  _hoverViewport = null;
                  _hover = null;
                  _plan.updateHover(null);
                },
                child: Listener(
                  onPointerDown: (event) {
                    _canvasFocus.requestFocus();
                    if (event.buttons == kMiddleMouseButton) {
                      setState(() => _middlePanning = true);
                    }
                  },
                  onPointerMove: (event) {
                    if (_middlePanning) _panBy(event.delta);
                  },
                  onPointerUp: (_) {
                    if (_middlePanning) setState(() => _middlePanning = false);
                  },
                  onPointerCancel: (_) {
                    if (_middlePanning) setState(() => _middlePanning = false);
                    _plan.endMove();
                  },
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      GestureBinding.instance.pointerSignalResolver.register(
                        event,
                        (_) {
                          if (HardwareKeyboard.instance.isShiftPressed) {
                            _panBy(
                              Offset(
                                -event.scrollDelta.dy,
                                -event.scrollDelta.dx,
                              ),
                            );
                          } else {
                            _zoomAt(
                              math.exp(-event.scrollDelta.dy / 260),
                              event.localPosition,
                            );
                            if (event.scrollDelta.dx != 0) {
                              _panBy(Offset(-event.scrollDelta.dx, 0));
                            }
                          }
                        },
                      );
                    }
                  },
                  child: GestureDetector(
                    key: const ValueKey('city-viewport'),
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onTapUp: (details) =>
                        _tapCanvas(_transform.toScene(details.localPosition)),
                    onSecondaryTapUp: (_) {
                      if (_measuring) {
                        setState(() {
                          _measureStart = null;
                          _measureEnd = null;
                        });
                      } else if (_plan.tool == CityPlanTool.road &&
                          _plan.draftRoad.isNotEmpty) {
                        _finishRoad();
                      }
                    },
                    onScaleStart: _startGesture,
                    onScaleUpdate: _updateGesture,
                    onScaleEnd: (_) {
                      _plan.endMove();
                      setState(() {
                        _gesturePanning = false;
                        _pinching = false;
                      });
                    },
                    child: CustomPaint(
                      key: const ValueKey('city-canvas'),
                      size: _viewport,
                      painter: CityMapPainter(
                        map: _plan.map,
                        worldTransform: _transform.value.clone(),
                        visibleWorldBounds: _visibleWorldBounds,
                        selectedId: _plan.selectedId,
                        showGrid: _showGrid,
                        showLabels: _showLabels,
                        showRoads: _showRoads,
                        showBuildings: _showBuildings,
                        showParcels: _showParcels,
                        showConnections: _showConnections,
                        showJunctions: _showJunctions,
                        viewScale: _plan.viewScale,
                        snapResult: _plan.snapEnabled ? _plan.hoverSnap : null,
                        draftCurved: _plan.curvedRoad,
                        validPlacement: placement?.valid ?? true,
                        roadKind: _plan.roadKind,
                        textDirection: Directionality.of(context),
                        fontFamily: Theme.of(
                          context,
                        ).textTheme.bodySmall?.fontFamily,
                        draftRoad: [
                          ..._plan.draftRoad,
                          if (_plan.tool == CityPlanTool.road &&
                              _plan.draftRoad.isNotEmpty &&
                              _hover != null &&
                              _hover != _plan.draftRoad.last)
                            _plan.hoverSnap?.position ?? _hover!,
                        ],
                        previewBuilding: placement?.building,
                      ),
                      foregroundPainter:
                          _measuring &&
                              _measureStart != null &&
                              measureEnd != null
                          ? CityMeasurePainter(
                              start: _measureStart!,
                              end: measureEnd,
                              transform: _transform.value.clone(),
                              label: t.mapMakerCityMeasuredDistance(
                                ((_measureStart! - measureEnd).distance *
                                        kCityMetersPerUnit)
                                    .toStringAsFixed(1),
                              ),
                              textDirection: Directionality.of(context),
                              fontFamily: Theme.of(
                                context,
                              ).textTheme.bodySmall?.fontFamily,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            if (_plan.map.roads.isEmpty &&
                _plan.map.buildings.isEmpty &&
                _plan.tool == CityPlanTool.select &&
                !_measuring)
              Positioned(
                top: 24,
                left: 24,
                right: 24,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 370),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: context.luma.surface.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.luma.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.all_inclusive_rounded,
                                color: context.luma.accent,
                                size: 28,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.mapMakerCityInfiniteCanvas,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t.mapMakerCityInfiniteHint,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
                                        color: context.luma.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            key: const ValueKey('city-start-road'),
                            onPressed: () =>
                                _plan.chooseRoad(CityRoadKind.street),
                            icon: const Icon(Icons.add_road_rounded, size: 18),
                            label: Text(t.mapMakerCityStartRoad),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_plan.tool == CityPlanTool.road)
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: context.luma.surface,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _action(
                          'city-cancel-road',
                          Icons.close_rounded,
                          t.mapMakerCityCancelRoad,
                          _plan.draftRoad.isNotEmpty ? _plan.cancelRoad : null,
                        ),
                        FilledButton.icon(
                          key: const ValueKey('city-finish-road'),
                          onPressed: _plan.canFinishRoad ? _finishRoad : null,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(t.mapMakerCityFinishRoad),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 16,
              bottom: 72,
              child: IgnorePointer(child: _scaleBar()),
            ),
            if (_viewport.width >= 540 && _plan.map.contentBounds != null)
              Positioned(
                right: 16,
                bottom: 72,
                child: Tooltip(
                  message: t.mapMakerCityNavigator,
                  child: CityMapNavigator(
                    key: const ValueKey('city-navigator'),
                    map: _plan.map,
                    viewport: _visibleWorldBounds,
                    showRoads: _showRoads,
                    showBuildings: _showBuildings,
                    onNavigate: (point) => _viewAt(point, _plan.viewScale),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.luma.surface.withValues(alpha: .95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.luma.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _measuring
                            ? Icons.straighten_rounded
                            : Icons.info_outline_rounded,
                        size: 16,
                        color: context.luma.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.luma.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _scaleBar() {
    final scale = _plan.viewScale;
    final target = 100 / scale * kCityMetersPerUnit;
    final magnitude = math
        .pow(10, (math.log(target) / math.ln10).floor())
        .toDouble();
    final metres =
        [1, 2, 5].lastWhere((value) => value * magnitude <= target) * magnitude;
    final width = metres / kCityMetersPerUnit * scale;
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        border: Border.all(color: const Color(0xFFC9CDCD)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metres >= 1000
                ? '${(metres / 1000).toStringAsFixed(0)} km'
                : '${metres.toStringAsFixed(metres < 1 ? 1 : 0)} m',
            style: const TextStyle(color: Color(0xFF3E464B), fontSize: 10),
          ),
          const SizedBox(height: 2),
          Container(
            width: width,
            height: 6,
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFF3E464B)),
                bottom: BorderSide(color: Color(0xFF3E464B), width: 2),
                right: BorderSide(color: Color(0xFF3E464B)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBar(bool compact) {
    final t = L.of(context);
    final colors = context.luma;
    final cursor = _plan.hoverSnap?.position ?? _hover;
    final parcels = _plan.map.buildings.where((building) => building.hasParcel);
    final connected = parcels.where((building) => building.connected).length;
    final segments = <String>[
      if (!compact) t.mapMakerCityLocalPlan,
      if (cursor != null)
        t.mapMakerCityCoordinates(
          (cursor.dx * kCityMetersPerUnit).toStringAsFixed(1),
          (cursor.dy * kCityMetersPerUnit).toStringAsFixed(1),
        ),
      t.mapMakerCitySnapStatus(_plan.hoverSnap?.kind.name ?? 'none'),
      _plan.viewScale < .01
          ? '${(_plan.viewScale * 100).toStringAsFixed(3)}%'
          : '${(_plan.viewScale * 100).round()}%',
      if (!compact) t.mapMakerCityConnectedCount(connected, parcels.length),
      if (!compact) t.mapMakerCityNavigationHint,
    ];
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (final text in segments)
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Text(
                  text,
                  style: TextStyle(fontSize: 10, color: colors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return Focus(
      focusNode: _canvasFocus,
      onKeyEvent: _onKey,
      onFocusChange: (focused) {
        if (!focused && _spacePanning) setState(() => _spacePanning = false);
      },
      child: Scaffold(
        backgroundColor: luma.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: luma.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          key: const ValueKey('city-back'),
                          tooltip: t.mapMakerCityMenu,
                          onPressed: () => _save(leave: true),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('city-title'),
                            controller: _title,
                            focusNode: _titleFocus,
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              labelText: t.mapMakerCityPlanner,
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 5,
                              ),
                            ),
                            onChanged: _plan.rename,
                            onSubmitted: (_) => _canvasFocus.requestFocus(),
                            onTapOutside: (_) => _titleFocus.unfocus(),
                          ),
                        ),
                        if (!compact)
                          Tooltip(
                            message: t.mapMakerCityInfiniteHint,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: luma.accentSubtle,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.all_inclusive_rounded,
                                    size: 16,
                                    color: luma.accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    t.mapMakerCityInfiniteCanvas,
                                    style: TextStyle(
                                      color: luma.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!compact)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              t.mapMakerCityStats(
                                _plan.map.roads.length,
                                _plan.map.buildings.length,
                              ),
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        _action(
                          'city-save',
                          Icons.save_outlined,
                          t.mapMakerCitySave,
                          () => _save(),
                        ),
                      ],
                    ),
                  ),
                  _toolbar(compact),
                  if (compact) _palette(true),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!compact) _palette(false),
                        Expanded(child: _canvas()),
                        if (constraints.maxWidth >= 1240)
                          Container(
                            width: 252,
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: luma.border),
                              ),
                            ),
                            child: CityPlanInspector(plan: _plan),
                          ),
                      ],
                    ),
                  ),
                  _statusBar(compact),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
