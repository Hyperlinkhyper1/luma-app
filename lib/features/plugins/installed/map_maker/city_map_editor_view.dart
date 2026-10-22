import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'city_map_models.dart';
import 'city_map_painter.dart';
import 'city_plan_controller.dart';
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
  Offset _dragOffset = Offset.zero;
  bool _showGrid = true;
  bool _centered = false;

  @override
  void initState() {
    super.initState();
    _plan = CityPlanController(
      save: widget.save,
      store: widget.store ?? MapMakerStore.instance,
    )..addListener(_changed);
    _title = TextEditingController(text: widget.save.title);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _plan.removeListener(_changed);
    _plan.endMove();
    _plan.rename(_title.text);
    unawaited(_plan.store.flush());
    _plan.dispose();
    _title.dispose();
    _transform.dispose();
    _canvasFocus.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _save({bool leave = false}) async {
    _plan.endMove();
    if (_plan.draftRoad.length >= 2) _plan.finishRoad();
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
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }

  void _fit() {
    if (_viewport.isEmpty) return;
    Rect? content;
    for (final building in _plan.map.buildings) {
      content = content?.expandToInclude(building.bounds) ?? building.bounds;
    }
    for (final road in _plan.map.roads) {
      for (final point in road.points) {
        final bounds = Rect.fromCircle(center: point, radius: road.kind.width);
        content = content?.expandToInclude(bounds) ?? bounds;
      }
    }
    if (content == null) {
      _viewAt(kCitySheetSize.center(Offset.zero), 1);
    } else {
      final bounds = content.inflate(96);
      final scaleX = _viewport.width / bounds.width;
      final scaleY = _viewport.height / bounds.height;
      _viewAt(
        bounds.center,
        (scaleX < scaleY ? scaleX : scaleY).clamp(.2, 1.5),
      );
    }
  }

  void _zoom(double factor) {
    final center = _transform.toScene(_viewport.center(Offset.zero));
    final scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      .2,
      3.0,
    );
    _viewAt(center, scale);
  }

  void _finishRoad() {
    if (!_plan.finishRoad()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).mapMakerCityRoadDraftHint)),
      );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_titleFocus.hasFocus || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final control =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (control && key == LogicalKeyboardKey.keyZ) {
      HardwareKeyboard.instance.isShiftPressed ? _plan.redo() : _plan.undo();
    } else if (control && key == LogicalKeyboardKey.keyY) {
      _plan.redo();
    } else if (control && key == LogicalKeyboardKey.keyS) {
      unawaited(_save());
    } else if (key == LogicalKeyboardKey.escape) {
      _plan.setTool(CityPlanTool.select);
    } else if (key == LogicalKeyboardKey.enter &&
        _plan.tool == CityPlanTool.road) {
      _finishRoad();
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _plan.deleteSelection();
    } else if (key == LogicalKeyboardKey.keyR) {
      _plan.rotate();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
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
      padding: EdgeInsets.only(right: compact ? 6 : 0, bottom: compact ? 0 : 4),
      child: Material(
        color: selected ? luma.accentSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey(id),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
          onTap: () => _plan.chooseRoad(kind),
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
          onTap: () => _plan.chooseBuilding(kind),
          compact: compact,
        ),
    ];
    if (compact) {
      return Container(
        color: context.luma.surface,
        height: 58,
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
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
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
      width: 212,
      color: context.luma.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
    );
  }

  Widget _toolbar() {
    final t = L.of(context);
    return Container(
      color: context.luma.surface,
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _action(
              'city-select',
              Icons.near_me_outlined,
              t.mapMakerCitySelect,
              () => _plan.setTool(CityPlanTool.select),
              selected: _plan.tool == CityPlanTool.select,
            ),
            _action(
              'city-pan',
              Icons.pan_tool_outlined,
              t.mapMakerCityPan,
              () => _plan.setTool(CityPlanTool.pan),
              selected: _plan.tool == CityPlanTool.pan,
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
              'city-delete',
              Icons.delete_outline_rounded,
              t.mapMakerCityDelete,
              () {
                if (_plan.selectedId != null) {
                  _plan.deleteSelection();
                } else {
                  _plan.setTool(CityPlanTool.delete);
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
          ],
        ),
      ),
    );
  }

  Widget _canvas() {
    final t = L.of(context);
    final hint = switch (_plan.tool) {
      CityPlanTool.road => t.mapMakerCityRoadHint,
      CityPlanTool.building => t.mapMakerCityPlaceHint,
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
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  alignment: Alignment.topLeft,
                  minScale: .2,
                  maxScale: 3,
                  boundaryMargin: const EdgeInsets.all(1600),
                  panEnabled: _plan.tool == CityPlanTool.pan,
                  child: MouseRegion(
                    cursor: _plan.tool == CityPlanTool.pan
                        ? SystemMouseCursors.grab
                        : SystemMouseCursors.precise,
                    onHover: (event) {
                      final point = _plan.map.snap(event.localPosition);
                      if (_hover != point) setState(() => _hover = point);
                    },
                    onExit: (_) => setState(() => _hover = null),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onTapUp: (details) {
                        _canvasFocus.requestFocus();
                        _plan.tap(details.localPosition);
                      },
                      onPanStart: _plan.tool != CityPlanTool.select
                          ? null
                          : (details) {
                              _canvasFocus.requestFocus();
                              _plan.beginMove(details.localPosition);
                              _dragOffset =
                                  (_plan.selectedBuilding?.position ??
                                      details.localPosition) -
                                  details.localPosition;
                            },
                      onPanUpdate: _plan.tool != CityPlanTool.select
                          ? null
                          : (details) => _plan.moveTo(
                              details.localPosition + _dragOffset,
                            ),
                      onPanEnd: _plan.tool != CityPlanTool.select
                          ? null
                          : (_) => _plan.endMove(),
                      onPanCancel: _plan.tool != CityPlanTool.select
                          ? null
                          : _plan.endMove,
                      child: CustomPaint(
                        key: const ValueKey('city-canvas'),
                        size: kCitySheetSize,
                        painter: CityMapPainter(
                          map: _plan.map,
                          selectedId: _plan.selectedId,
                          showGrid: _showGrid,
                          roadKind: _plan.roadKind,
                          textDirection: Directionality.of(context),
                          draftRoad: [
                            ..._plan.draftRoad,
                            if (_plan.tool == CityPlanTool.road &&
                                _plan.draftRoad.isNotEmpty &&
                                _hover != null &&
                                _hover != _plan.draftRoad.last)
                              _hover!,
                          ],
                          previewBuilding:
                              _plan.tool == CityPlanTool.building &&
                                  _hover != null
                              ? _plan.previewBuilding(_hover!)
                              : null,
                        ),
                      ),
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
                          onPressed: _plan.draftRoad.length >= 2
                              ? _finishRoad
                              : null,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(t.mapMakerCityFinishRoad),
                        ),
                      ],
                    ),
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
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: context.luma.surface.withValues(alpha: .95),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.luma.border),
                  ),
                  child: Text(
                    hint,
                    style: TextStyle(
                      color: context.luma.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return Focus(
      focusNode: _canvasFocus,
      onKeyEvent: _onKey,
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
                  _toolbar(),
                  if (compact) _palette(true),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!compact) _palette(false),
                        Expanded(child: _canvas()),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
