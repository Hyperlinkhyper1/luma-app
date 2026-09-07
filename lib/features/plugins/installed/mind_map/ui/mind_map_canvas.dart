import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/mind_map_database.dart';
import '../io/mind_map_export.dart';
import '../layout/mind_map_layout.dart';
import '../mind_map_repository.dart';
import 'mind_map_ai_sheet.dart';
import 'mind_map_connectors.dart';
import 'mind_map_import_sheet.dart';
import 'mind_map_inspector.dart';
import 'mind_map_node_card.dart';
import 'mind_map_style.dart';

/// The editing surface for a single map.
///
/// Nodes are never positioned by hand: every change re-runs
/// [MindMapLayout], so branches cannot overlap and the user's only job is
/// deciding what goes where in the tree. The keyboard drives everything —
/// Enter for a sibling, Tab for a child, typing straight into the node — with
/// a touch action bar standing in for those keys on a phone.
class MindMapCanvas extends StatefulWidget {
  const MindMapCanvas({
    super.key,
    required this.map,
    required this.repository,
    required this.onClose,
  });

  final MindMap map;
  final MindMapRepository repository;
  final VoidCallback onClose;

  @override
  State<MindMapCanvas> createState() => _MindMapCanvasState();
}

class _MindMapCanvasState extends State<MindMapCanvas> {
  final _transform = TransformationController();
  final _viewportKey = GlobalKey();
  final _exportKey = GlobalKey();
  final _editController = TextEditingController();

  late final FocusNode _canvasFocus = FocusNode(
    debugLabel: 'mind map canvas',
    onKeyEvent: _onCanvasKey,
  );
  late final FocusNode _editFocus = FocusNode(
    debugLabel: 'mind map node editor',
    onKeyEvent: _onEditKey,
  );

  late Stream<List<MindMapNode>> _nodeStream =
      widget.repository.watchNodes(widget.map.id);

  int? _selectedId;
  int? _editingId;
  bool _editingIsNew = false;

  int? _draggingId;
  int? _dropTargetId;

  /// Latest layout, kept so the key handlers and drag logic can reason about
  /// geometry without rebuilding it.
  _MapModel? _model;

  bool _needsInitialFit = true;
  bool _busy = false;

  @override
  void didUpdateWidget(MindMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.map.id != widget.map.id) {
      _nodeStream = widget.repository.watchNodes(widget.map.id);
      _selectedId = null;
      _editingId = null;
      _needsInitialFit = true;
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    _editController.dispose();
    _canvasFocus.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  MindMapDirection get _direction =>
      MindMapDirection.values[widget.map.direction.clamp(0, MindMapDirection.values.length - 1)];

  bool get _isVertical => _direction == MindMapDirection.down;

  // ------------------------------------------------------------- editing

  void _beginEdit(int id, {bool isNew = false}) {
    final node = _model?.byId[id];
    setState(() {
      _selectedId = id;
      _editingId = id;
      _editingIsNew = isNew;
      _editController.text = node?.label ?? '';
      _editController.selection =
          TextSelection(baseOffset: 0, extentOffset: _editController.text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingId == id) _editFocus.requestFocus();
    });
  }

  /// Writes the in-progress label back.
  ///
  /// A node that was created a moment ago and left blank is removed rather
  /// than left on the canvas — pressing Enter twice by reflex should not
  /// litter the map with empty boxes.
  Future<void> _commitEdit({bool keepFocus = true}) async {
    final id = _editingId;
    if (id == null) return;
    final text = _editController.text.trim();
    final wasNew = _editingIsNew;

    setState(() {
      _editingId = null;
      _editingIsNew = false;
    });

    if (text.isEmpty && wasNew) {
      await widget.repository.deleteSubtree(id);
      if (mounted && _selectedId == id) setState(() => _selectedId = null);
    } else if (text.isNotEmpty) {
      await widget.repository.updateNode(id, label: text);
    }
    if (keepFocus && mounted) _canvasFocus.requestFocus();
  }

  Future<void> _addChild(int parentId) async {
    await _commitEdit(keepFocus: false);
    final id = await widget.repository.addChild(
      mapId: widget.map.id,
      parentId: parentId,
    );
    // Adding to a folded branch would drop the new node out of sight.
    final parent = _model?.byId[parentId];
    if (parent != null && parent.collapsed) {
      await widget.repository.setCollapsed(parentId, false);
    }
    if (mounted) _beginEdit(id, isNew: true);
  }

  Future<void> _addSibling(int afterId) async {
    final node = _model?.byId[afterId];
    // A sibling of the root would be a second root, which is almost never
    // what someone means when they press Enter on the centre of the map.
    if (node == null || node.parentId == null) {
      await _addChild(afterId);
      return;
    }
    await _commitEdit(keepFocus: false);
    final id = await widget.repository.addSiblingAfter(
      mapId: widget.map.id,
      afterId: afterId,
    );
    if (mounted) _beginEdit(id, isNew: true);
  }

  Future<void> _outdent(int id) async {
    final model = _model;
    final node = model?.byId[id];
    if (model == null || node == null || node.parentId == null) return;
    final parent = model.byId[node.parentId!];
    if (parent == null) return;
    await _commitEdit(keepFocus: false);
    await widget.repository.reparent(id, parent.parentId);
    if (mounted) _canvasFocus.requestFocus();
  }

  Future<void> _delete(int id) async {
    final deletion = await widget.repository.deleteSubtree(id);
    if (!mounted || deletion == null) return;
    setState(() {
      if (_selectedId == id) _selectedId = null;
      if (_editingId == id) _editingId = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(deletion.description),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => widget.repository.restore(deletion),
        ),
      ),
    );
  }

  Future<void> _toggleCollapse(int id) async {
    final node = _model?.byId[id];
    if (node == null) return;
    await widget.repository.setCollapsed(id, !node.collapsed);
  }

  // ------------------------------------------------------------ keyboard

  KeyEventResult _onCanvasKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;

    if (keys.isControlPressed || keys.isMetaPressed) {
      if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
        _fitToScreen();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add) {
        _zoomBy(1.2);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.minus) {
        _zoomBy(1 / 1.2);
        return KeyEventResult.handled;
      }
    }

    final selected = _selectedId;

    // With nothing selected the only keys that make sense are the ones that
    // get the user back onto the map.
    if (selected == null) {
      final roots = _model?.roots ?? const <MindMapNode>[];
      if ((key == LogicalKeyboardKey.tab || key == LogicalKeyboardKey.enter) &&
          roots.isNotEmpty) {
        setState(() => _selectedId = roots.first.id);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.tab) {
      if (keys.isShiftPressed) {
        _outdent(selected);
      } else {
        _addChild(selected);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _addSibling(selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2) {
      _beginEdit(selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      _toggleCollapse(selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      _delete(selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _selectedId = null);
      return KeyEventResult.handled;
    }

    final direction = _arrowDirection(key);
    if (direction != null) {
      if (keys.isAltPressed) {
        // Alt reorders instead of navigating, following the axis siblings
        // are stacked along.
        final reorder = _isVertical
            ? (direction == AxisDirection.left ? -1 : direction == AxisDirection.right ? 1 : 0)
            : (direction == AxisDirection.up ? -1 : direction == AxisDirection.down ? 1 : 0);
        if (reorder != 0) widget.repository.move(selected, reorder);
      } else {
        _navigate(selected, direction);
      }
      return KeyEventResult.handled;
    }

    // Any other printable key starts editing, replacing the label — the
    // outliner habit of "select and just type".
    final character = event.character;
    if (character != null &&
        character.isNotEmpty &&
        character.trim().isNotEmpty &&
        !keys.isControlPressed &&
        !keys.isMetaPressed &&
        !keys.isAltPressed) {
      _beginEdit(selected);
      _editController.text = character;
      _editController.selection =
          TextSelection.collapsed(offset: character.length);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _onEditKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    final editing = _editingId;
    if (editing == null) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      // Shift+Enter falls through so a label can still hold a line break.
      if (keys.isShiftPressed) return KeyEventResult.ignored;
      _addSibling(editing);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      if (keys.isShiftPressed) {
        _outdent(editing);
      } else {
        _addChild(editing);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _commitEdit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  AxisDirection? _arrowDirection(LogicalKeyboardKey key) => switch (key) {
        LogicalKeyboardKey.arrowUp => AxisDirection.up,
        LogicalKeyboardKey.arrowDown => AxisDirection.down,
        LogicalKeyboardKey.arrowLeft => AxisDirection.left,
        LogicalKeyboardKey.arrowRight => AxisDirection.right,
        _ => null,
      };

  /// Moves the selection to whichever node actually lies that way on screen.
  ///
  /// Purely geometric, so the same four keys behave correctly on a rightward
  /// map, a downward one, and the left-hand half of a both-sides map without
  /// the user having to think about which is which.
  void _navigate(int fromId, AxisDirection direction) {
    final model = _model;
    if (model == null) return;
    final origin = model.positions[fromId];
    if (origin == null) return;

    int? best;
    var bestScore = double.infinity;
    for (final entry in model.positions.entries) {
      if (entry.key == fromId) continue;
      final delta = entry.value.center - origin.center;
      final along = switch (direction) {
        AxisDirection.up => -delta.dy,
        AxisDirection.down => delta.dy,
        AxisDirection.left => -delta.dx,
        AxisDirection.right => delta.dx,
      };
      if (along <= 1) continue;
      final across = switch (direction) {
        AxisDirection.up || AxisDirection.down => delta.dx.abs(),
        AxisDirection.left || AxisDirection.right => delta.dy.abs(),
      };
      // Weighting the off-axis distance keeps the selection from leaping to a
      // far-away branch that happens to be marginally closer in a line.
      final score = along + across * 2.5;
      if (score < bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }

    if (best == null) return;
    setState(() => _selectedId = best);
    final rect = model.positions[best];
    if (rect != null) _reveal(rect);
  }

  // ----------------------------------------------------------- viewport

  Size? get _viewportSize {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.hasSize == true ? box!.size : null;
  }

  void _fitToScreen() {
    final model = _model;
    final view = _viewportSize;
    if (model == null || view == null || model.canvasSize.isEmpty) return;
    final scale = math
        .min(view.width / model.canvasSize.width, view.height / model.canvasSize.height)
        .clamp(0.25, 1.0);
    final dx = (view.width - model.canvasSize.width * scale) / 2;
    final dy = (view.height - model.canvasSize.height * scale) / 2;
    _transform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoomBy(double factor) {
    final view = _viewportSize;
    if (view == null) return;
    final centre = Offset(view.width / 2, view.height / 2);
    final scene = _transform.toScene(centre);
    final current = _transform.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(0.2, 2.5);
    final applied = target / current;
    _transform.value = _transform.value.clone()
      ..translateByDouble(scene.dx, scene.dy, 0, 1)
      ..scaleByDouble(applied, applied, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
  }

  /// Nudges the viewport so [rect] is on screen, without recentring the map
  /// out from under the user when it already is.
  void _reveal(Rect rect) {
    final view = _viewportSize;
    if (view == null) return;
    final topLeft = _transform.toScene(Offset.zero);
    final bottomRight = _transform.toScene(Offset(view.width, view.height));
    final visible = Rect.fromPoints(topLeft, bottomRight).deflate(48);
    if (visible.width <= 0 || visible.height <= 0) return;

    var dx = 0.0;
    var dy = 0.0;
    if (rect.left < visible.left) {
      dx = visible.left - rect.left;
    } else if (rect.right > visible.right) {
      dx = visible.right - rect.right;
    }
    if (rect.top < visible.top) {
      dy = visible.top - rect.top;
    } else if (rect.bottom > visible.bottom) {
      dy = visible.bottom - rect.bottom;
    }
    if (dx == 0 && dy == 0) return;
    _transform.value =
        _transform.value.clone()..translateByDouble(dx, dy, 0, 1);
  }

  /// Converts a pointer position into canvas coordinates.
  ///
  /// Going through the transformation controller is what keeps dragging
  /// glued to the cursor at any zoom level.
  Offset? _toScene(Offset globalPosition) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return _transform.toScene(box.globalToLocal(globalPosition));
  }

  // --------------------------------------------------------------- drag

  void _onNodeDragUpdate(int id, Offset globalPosition) {
    final model = _model;
    final scene = _toScene(globalPosition);
    if (model == null || scene == null) return;

    int? target;
    for (final entry in model.positions.entries) {
      if (entry.key == id) continue;
      if (model.descendantsOf(id).contains(entry.key)) continue;
      if (entry.value.inflate(6).contains(scene)) {
        target = entry.key;
        break;
      }
    }
    if (target != _dropTargetId) setState(() => _dropTargetId = target);
  }

  Future<void> _onNodeDragEnd(int id) async {
    final target = _dropTargetId;
    setState(() {
      _draggingId = null;
      _dropTargetId = null;
    });
    if (target == null) return;
    final moved = await widget.repository.reparent(id, target);
    if (!moved && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('A node cannot be moved inside itself.')),
        );
    }
  }

  // ------------------------------------------------------------ actions

  Future<void> _openInspector(int id) async {
    final model = _model;
    final node = model?.byId[id];
    if (model == null || node == null) return;
    await MindMapInspector.show(
      context,
      node: node,
      repository: widget.repository,
      inheritedColor: model.colors[id] ?? context.luma.accent,
    );
    if (mounted) _canvasFocus.requestFocus();
  }

  Future<void> _openAiSheet(int id) async {
    final node = _model?.byId[id];
    if (node == null) return;
    final added = await MindMapAiSheet.show(
      context,
      repository: widget.repository,
      mapTitle: widget.map.title,
      mapId: widget.map.id,
      node: node,
      path: _model?.pathTo(id) ?? const [],
      existingChildren: _model?.childLabelsOf(id) ?? const [],
    );
    if (!mounted) return;
    if (added != null && added > 0) {
      await widget.repository.setCollapsed(id, false);
    }
    if (mounted) _canvasFocus.requestFocus();
  }

  Future<void> _openImportSheet() async {
    final added = await MindMapImportSheet.show(
      context,
      repository: widget.repository,
      mapId: widget.map.id,
      parentId: _selectedId,
      parentLabel: _selectedId == null ? null : _model?.byId[_selectedId!]?.label,
    );
    if (!mounted) return;
    if (added != null && added > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToScreen());
    }
    if (mounted) _canvasFocus.requestFocus();
  }

  Future<void> _export(MindMapExportFormat format) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final summary = await MindMapExport.run(
        format: format,
        repository: widget.repository,
        map: widget.map,
        boundaryKey: _exportKey,
      );
      if (mounted && summary != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(summary)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('Export failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cycleDirection() async {
    final next = MindMapDirection
        .values[(_direction.index + 1) % MindMapDirection.values.length];
    await widget.repository.setDirection(widget.map.id, next);
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToScreen());
    }
  }

  void _showNodeMenu(int id, Offset globalPosition) {
    final model = _model;
    final node = model?.byId[id];
    if (model == null || node == null) return;
    setState(() => _selectedId = id);

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlay.size,
    );
    final hasChildren = (model.childrenOf[id] ?? const []).isNotEmpty;

    showMenu<_NodeAction>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(
          value: _NodeAction.addChild,
          child: _MenuRow(icon: Icons.subdirectory_arrow_right_rounded, label: 'Add child', hint: 'Tab'),
        ),
        if (node.parentId != null)
          const PopupMenuItem(
            value: _NodeAction.addSibling,
            child: _MenuRow(icon: Icons.add_rounded, label: 'Add sibling', hint: 'Enter'),
          ),
        const PopupMenuItem(
          value: _NodeAction.rename,
          child: _MenuRow(icon: Icons.edit_rounded, label: 'Rename', hint: 'F2'),
        ),
        const PopupMenuItem(
          value: _NodeAction.details,
          child: _MenuRow(icon: Icons.notes_rounded, label: 'Note, link & colour'),
        ),
        const PopupMenuItem(
          value: _NodeAction.ai,
          child: _MenuRow(icon: Icons.auto_awesome_rounded, label: 'Expand with AI'),
        ),
        if (hasChildren)
          PopupMenuItem(
            value: _NodeAction.collapse,
            child: _MenuRow(
              icon: node.collapsed ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
              label: node.collapsed ? 'Expand branch' : 'Collapse branch',
              hint: 'Space',
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _NodeAction.delete,
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            label: 'Delete branch',
            hint: 'Del',
            danger: true,
          ),
        ),
      ],
    ).then((action) {
      if (!mounted || action == null) return;
      switch (action) {
        case _NodeAction.addChild:
          _addChild(id);
        case _NodeAction.addSibling:
          _addSibling(id);
        case _NodeAction.rename:
          _beginEdit(id);
        case _NodeAction.details:
          _openInspector(id);
        case _NodeAction.ai:
          _openAiSheet(id);
        case _NodeAction.collapse:
          _toggleCollapse(id);
        case _NodeAction.delete:
          _delete(id);
      }
    });
  }

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return StreamData<List<MindMapNode>>(
      stream: _nodeStream,
      builder: (context, nodes) {
        final model = _MapModel.build(
          nodes: nodes,
          direction: _direction,
          rootColor: context.luma.accent,
          textScaler: MediaQuery.textScalerOf(context),
          editingId: _editingId,
          draftLabel: _editController.text,
        );
        _model = model;

        if (_needsInitialFit && model.positions.isNotEmpty) {
          _needsInitialFit = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fitToScreen();
          });
        }

        final narrow = MediaQuery.sizeOf(context).width < 760;
        return Column(
          children: [
            _Toolbar(
              map: widget.map,
              direction: _direction,
              nodeCount: nodes.length,
              narrow: narrow,
              busy: _busy,
              onClose: widget.onClose,
              onFit: _fitToScreen,
              onCycleDirection: _cycleDirection,
              onImport: _openImportSheet,
              onExport: _export,
              onRename: () => _renameMap(context),
            ),
            Expanded(child: _buildCanvas(model, narrow)),
            if (narrow && _selectedId != null)
              _TouchActionBar(
                canAddSibling: model.byId[_selectedId!]?.parentId != null,
                onAddChild: () => _addChild(_selectedId!),
                onAddSibling: () => _addSibling(_selectedId!),
                onRename: () => _beginEdit(_selectedId!),
                onDetails: () => _openInspector(_selectedId!),
                onDelete: () => _delete(_selectedId!),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCanvas(_MapModel model, bool narrow) {
    final luma = context.luma;
    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 12 : 24, 0, narrow ? 12 : 24, narrow ? 12 : 16),
      child: Container(
        decoration: BoxDecoration(
          color: luma.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: luma.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Focus(
          focusNode: _canvasFocus,
          autofocus: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    _commitEdit();
                    setState(() => _selectedId = null);
                    _canvasFocus.requestFocus();
                  },
                  child: InteractiveViewer(
                    key: _viewportKey,
                    transformationController: _transform,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(600),
                    minScale: 0.2,
                    maxScale: 2.5,
                    child: RepaintBoundary(
                      key: _exportKey,
                      child: Container(
                        width: math.max(model.canvasSize.width, 1),
                        height: math.max(model.canvasSize.height, 1),
                        color: luma.background,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: MindMapConnectorPainter(
                                  connectors: model.connectors,
                                  vertical: _isVertical,
                                ),
                              ),
                            ),
                            for (final node in model.visible) _buildNode(model, node),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (model.visible.length <= 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(child: _FirstBranchHint(narrow: narrow)),
                ),
              Positioned(
                right: 12,
                bottom: 12,
                child: _ZoomControls(
                  onZoomIn: () => _zoomBy(1.2),
                  onZoomOut: () => _zoomBy(1 / 1.2),
                  onFit: _fitToScreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNode(_MapModel model, MindMapNode node) {
    final rect = model.positions[node.id];
    if (rect == null) return const SizedBox.shrink();
    final descendants = model.descendantCount(node.id);

    return Positioned(
      left: rect.left,
      top: rect.top,
      child: Semantics(
        selected: _selectedId == node.id,
        label: node.label.trim().isEmpty ? 'Empty node' : node.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_editingId != null && _editingId != node.id) _commitEdit(keepFocus: false);
              setState(() => _selectedId = node.id);
              _canvasFocus.requestFocus();
            },
            onDoubleTap: () => _beginEdit(node.id),
            onSecondaryTapDown: (d) => _showNodeMenu(node.id, d.globalPosition),
            onLongPressStart: (d) => _showNodeMenu(node.id, d.globalPosition),
            onPanStart: (_) {
              if (_editingId != null) _commitEdit(keepFocus: false);
              setState(() {
                _draggingId = node.id;
                _selectedId = node.id;
              });
            },
            onPanUpdate: (d) => _onNodeDragUpdate(node.id, d.globalPosition),
            onPanEnd: (_) => _onNodeDragEnd(node.id),
            onPanCancel: () => setState(() {
              _draggingId = null;
              _dropTargetId = null;
            }),
            child: MindMapNodeCard(
              node: node,
              size: rect.size,
              color: model.colors[node.id] ?? context.luma.accent,
              depth: model.depths[node.id] ?? 0,
              hiddenCount: descendants,
              selected: _selectedId == node.id,
              editing: _editingId == node.id,
              dropTarget: _dropTargetId == node.id,
              dragging: _draggingId == node.id,
              controller: _editController,
              focusNode: _editFocus,
              onEditingComplete: () => _addSibling(node.id),
              onToggleCollapse: () => _toggleCollapse(node.id),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _renameMap(BuildContext context) async {
    final controller = TextEditingController(text: widget.map.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename map'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title != null && title.isNotEmpty) {
      await widget.repository.renameMap(widget.map.id, title);
    }
  }
}

enum _NodeAction { addChild, addSibling, rename, details, ai, collapse, delete }

/// Everything the canvas needs to know about the current tree, derived once
/// per build: structure, colours, measured sizes and the resulting layout.
class _MapModel {
  _MapModel({
    required this.byId,
    required this.childrenOf,
    required this.roots,
    required this.visible,
    required this.depths,
    required this.colors,
    required this.positions,
    required this.canvasSize,
    required this.connectors,
  });

  final Map<int, MindMapNode> byId;
  final Map<int?, List<MindMapNode>> childrenOf;
  final List<MindMapNode> roots;
  final List<MindMapNode> visible;
  final Map<int, int> depths;
  final Map<int, Color> colors;
  final Map<int, Rect> positions;
  final Size canvasSize;
  final List<MindMapConnector> connectors;

  static _MapModel build({
    required List<MindMapNode> nodes,
    required MindMapDirection direction,
    required Color rootColor,
    required TextScaler textScaler,
    required int? editingId,
    required String draftLabel,
  }) {
    final byId = {for (final n in nodes) n.id: n};
    final childrenOf = <int?, List<MindMapNode>>{};
    for (final n in nodes) {
      final parent = n.parentId != null && byId.containsKey(n.parentId) ? n.parentId : null;
      childrenOf.putIfAbsent(parent, () => []).add(n);
    }
    for (final list in childrenOf.values) {
      list.sort((a, b) {
        final byIndex = a.sortIndex.compareTo(b.sortIndex);
        return byIndex != 0 ? byIndex : a.id.compareTo(b.id);
      });
    }

    final roots = childrenOf[null] ?? const <MindMapNode>[];
    final depths = MindMapStyle.resolveDepths(nodes);
    final colors = MindMapStyle.resolveColors(nodes: nodes, rootColor: rootColor);

    // Only what is actually on screen gets measured and laid out; a folded
    // branch costs nothing.
    final visible = <MindMapNode>[];
    void collect(List<MindMapNode> level) {
      for (final node in level) {
        visible.add(node);
        if (node.collapsed) continue;
        collect(childrenOf[node.id] ?? const []);
      }
    }

    collect(roots);

    final layoutNodes = <MindMapLayoutNode>[];
    for (final node in visible) {
      final depth = depths[node.id] ?? 0;
      final hasChildren = (childrenOf[node.id] ?? const []).isNotEmpty;
      var extras = 0.0;
      if (node.note != null && node.note!.trim().isNotEmpty) {
        extras += MindMapStyle.badgeWidth;
      }
      if (node.link != null && node.link!.trim().isNotEmpty) {
        extras += MindMapStyle.badgeWidth;
      }
      if (hasChildren) extras += MindMapStyle.collapsePillWidth + 4;

      // While a node is being typed into, measure the draft so the box grows
      // with the text instead of clipping it until the edit is committed.
      final label = node.id == editingId ? draftLabel : node.label;

      layoutNodes.add(MindMapLayoutNode(
        id: node.id,
        parentId: byId.containsKey(node.parentId) ? node.parentId : null,
        sortIndex: node.sortIndex,
        collapsed: node.collapsed,
        size: MindMapStyle.measure(
          label: label,
          isRoot: depth == 0,
          extrasWidth: extras,
          style: MindMapStyle.labelStyle(isRoot: depth == 0),
          textScaler: textScaler,
        ),
      ));
    }

    final layout = MindMapLayout.compute(nodes: layoutNodes, direction: direction);

    final connectors = <MindMapConnector>[];
    for (final node in visible) {
      final parentId = node.parentId;
      if (parentId == null) continue;
      final parentRect = layout.positions[parentId];
      final childRect = layout.positions[node.id];
      if (parentRect == null || childRect == null) continue;
      connectors.add(MindMapConnector(
        parent: parentRect,
        child: childRect,
        color: colors[node.id] ?? rootColor,
        depth: depths[node.id] ?? 1,
      ));
    }

    return _MapModel(
      byId: byId,
      childrenOf: childrenOf,
      roots: roots,
      visible: visible,
      depths: depths,
      colors: colors,
      positions: layout.positions,
      canvasSize: layout.canvasSize,
      connectors: connectors,
    );
  }

  int descendantCount(int id) {
    final kids = childrenOf[id] ?? const <MindMapNode>[];
    return kids.fold<int>(kids.length, (sum, k) => sum + descendantCount(k.id));
  }

  Set<int> descendantsOf(int id) {
    final result = <int>{};
    void walk(int current) {
      for (final child in childrenOf[current] ?? const <MindMapNode>[]) {
        if (result.add(child.id)) walk(child.id);
      }
    }

    walk(id);
    return result;
  }

  /// Root-to-node labels, used to tell the AI where in the map it is.
  List<String> pathTo(int id) {
    final path = <String>[];
    var cursor = byId[id];
    final seen = <int>{};
    while (cursor != null && seen.add(cursor.id)) {
      path.insert(0, cursor.label);
      cursor = cursor.parentId == null ? null : byId[cursor.parentId];
    }
    return path;
  }

  List<String> childLabelsOf(int id) =>
      [for (final c in childrenOf[id] ?? const <MindMapNode>[]) c.label];
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.map,
    required this.direction,
    required this.nodeCount,
    required this.narrow,
    required this.busy,
    required this.onClose,
    required this.onFit,
    required this.onCycleDirection,
    required this.onImport,
    required this.onExport,
    required this.onRename,
  });

  final MindMap map;
  final MindMapDirection direction;
  final int nodeCount;
  final bool narrow;
  final bool busy;
  final VoidCallback onClose;
  final VoidCallback onFit;
  final VoidCallback onCycleDirection;
  final VoidCallback onImport;
  final ValueChanged<MindMapExportFormat> onExport;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 12 : 24, 8, narrow ? 12 : 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'All maps',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onClose,
              ),
              Flexible(
                child: Tooltip(
                  message: 'Rename map',
                  child: InkWell(
                    onTap: onRename,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        map.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!narrow) ...[
                const SizedBox(width: 8),
                Text(
                  '$nodeCount ${nodeCount == 1 ? 'node' : 'nodes'}',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
              const Spacer(),
              IconButton(
                tooltip: 'Layout: ${direction.label}',
                icon: Icon(switch (direction) {
                  MindMapDirection.right => Icons.chevron_right_rounded,
                  MindMapDirection.both => Icons.unfold_more_rounded,
                  MindMapDirection.down => Icons.expand_more_rounded,
                }),
                onPressed: onCycleDirection,
              ),
              IconButton(
                tooltip: 'Fit to screen (Ctrl+0)',
                icon: const Icon(Icons.fit_screen_rounded),
                onPressed: onFit,
              ),
              IconButton(
                tooltip: 'Paste an outline',
                icon: const Icon(Icons.content_paste_go_rounded),
                onPressed: onImport,
              ),
              PopupMenuButton<MindMapExportFormat>(
                tooltip: 'Export',
                enabled: !busy,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded),
                onSelected: onExport,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: MindMapExportFormat.png,
                    child: _MenuRow(icon: Icons.image_rounded, label: 'Image (PNG)'),
                  ),
                  PopupMenuItem(
                    value: MindMapExportFormat.markdown,
                    child: _MenuRow(icon: Icons.notes_rounded, label: 'Outline (Markdown)'),
                  ),
                  PopupMenuItem(
                    value: MindMapExportFormat.opml,
                    child: _MenuRow(icon: Icons.account_tree_rounded, label: 'Outline (OPML)'),
                  ),
                ],
              ),
            ],
          ),
          if (!narrow) ...[
            const SizedBox(height: 4),
            const _ShortcutHints(),
          ],
        ],
      ),
    );
  }
}

/// A one-line reminder of the keys that drive the map.
///
/// A keyboard-first tool is only fast once you know the keys, so they are on
/// screen rather than hidden in a help page.
class _ShortcutHints extends StatelessWidget {
  const _ShortcutHints();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return DefaultTextStyle(
      style: TextStyle(color: luma.textMuted, fontSize: 11.5),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: const [
          _Hint(keys: 'Tab', action: 'child'),
          _Hint(keys: 'Enter', action: 'sibling'),
          _Hint(keys: 'F2', action: 'rename'),
          _Hint(keys: 'Space', action: 'fold'),
          _Hint(keys: 'Arrows', action: 'move around'),
          _Hint(keys: 'Alt+Arrows', action: 'reorder'),
          _Hint(keys: 'Del', action: 'delete'),
          _Hint(keys: 'Drag', action: 're-parent'),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.keys, required this.action});
  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: luma.surfaceHover,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: luma.border),
          ),
          child: Text(
            keys,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(action),
      ],
    );
  }
}

/// Stands in for Tab and Enter where there is no keyboard.
class _TouchActionBar extends StatelessWidget {
  const _TouchActionBar({
    required this.canAddSibling,
    required this.onAddChild,
    required this.onAddSibling,
    required this.onRename,
    required this.onDetails,
    required this.onDelete,
  });

  final bool canAddSibling;
  final VoidCallback onAddChild;
  final VoidCallback onAddSibling;
  final VoidCallback onRename;
  final VoidCallback onDetails;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: luma.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: luma.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _TouchAction(
              icon: Icons.subdirectory_arrow_right_rounded,
              label: 'Child',
              onTap: onAddChild,
            ),
            _TouchAction(
              icon: Icons.add_rounded,
              label: 'Sibling',
              onTap: canAddSibling ? onAddSibling : null,
            ),
            _TouchAction(icon: Icons.edit_rounded, label: 'Rename', onTap: onRename),
            _TouchAction(icon: Icons.notes_rounded, label: 'Details', onTap: onDetails),
            _TouchAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              onTap: onDelete,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TouchAction extends StatelessWidget {
  const _TouchAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final enabled = onTap != null;
    final color = !enabled
        ? luma.textMuted.withValues(alpha: 0.5)
        : danger
            ? luma.danger
            : luma.textPrimary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        // 56x48 clears the 44pt minimum with room for the caption underneath.
        child: SizedBox(
          width: 60,
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10.5, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      decoration: BoxDecoration(
        color: luma.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom in',
            iconSize: 18,
            icon: const Icon(Icons.add_rounded),
            onPressed: onZoomIn,
          ),
          IconButton(
            tooltip: 'Zoom out',
            iconSize: 18,
            icon: const Icon(Icons.remove_rounded),
            onPressed: onZoomOut,
          ),
          IconButton(
            tooltip: 'Fit to screen',
            iconSize: 18,
            icon: const Icon(Icons.fit_screen_rounded),
            onPressed: onFit,
          ),
        ],
      ),
    );
  }
}

/// Shown while a map is still just its root, because an empty canvas gives no
/// clue that Tab is the way in.
class _FirstBranchHint extends StatelessWidget {
  const _FirstBranchHint({required this.narrow});
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      // The hint floats over the canvas, so it has to stay clear of the zoom
      // controls in the corner and wrap rather than run off the edge.
      padding: const EdgeInsets.symmetric(horizontal: 72),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: luma.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: luma.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lightbulb_outline_rounded, size: 16, color: luma.accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                narrow
                    ? 'Tap the centre node, then Child'
                    : 'Select the centre node and press Tab to add your first branch',
                style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.hint,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = danger ? luma.danger : luma.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: color))),
        if (hint != null) ...[
          const SizedBox(width: 16),
          Text(hint!, style: TextStyle(color: luma.textMuted, fontSize: 11)),
        ],
      ],
    );
  }
}
