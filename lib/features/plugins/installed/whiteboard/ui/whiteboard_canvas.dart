import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../theme/luma_theme.dart';
import '../data/whiteboard_database.dart';
import '../io/whiteboard_export.dart';
import '../model/whiteboard_element.dart';
import '../model/whiteboard_tool.dart';
import '../whiteboard_repository.dart';
import 'whiteboard_painter.dart';
import 'whiteboard_toolbar.dart';

/// How big the board is, in board units. Not infinite: a fixed sheet means
/// zoom-to-fit, the scrollable extent and the PNG export all have something
/// definite to work from, and it is far larger than anyone fills.
const Size kWhiteboardSize = Size(4000, 2800);

/// The drawing surface for one board.
///
/// Three painting layers sit on top of each other: the paper and its grid,
/// the committed elements, and the one stroke currently under the pointer.
/// Only the top layer repaints while drawing, which is what keeps a long pen
/// stroke smooth on a board that already holds hundreds of elements.
class WhiteboardCanvas extends StatefulWidget {
  const WhiteboardCanvas({
    super.key,
    required this.board,
    required this.repository,
    required this.onClose,
  });

  final Board board;
  final WhiteboardRepository repository;
  final VoidCallback onClose;

  @override
  State<WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends State<WhiteboardCanvas> {
  final _transform = TransformationController();
  final _viewerKey = GlobalKey();
  late final FocusNode _focus = FocusNode(debugLabel: 'whiteboard canvas');

  /// The in-flight stroke and the eraser ring. Held in a notifier rather than
  /// in `setState` so a pointer move repaints one layer instead of the tree.
  final _draft = ValueNotifier<_Draft>(const _Draft());

  StreamSubscription<List<WhiteboardElement>>? _subscription;
  List<WhiteboardElement> _elements = const [];

  WhiteboardTool _tool = WhiteboardTool.pen;
  int _ink = whiteboardInks.first.value;
  double _strokeWidth = whiteboardWidths[1].value;
  bool _showGrid = true;

  int? _selectedId;

  /// Elements the board layer must skip: the one being dragged (the draft
  /// layer draws it instead) or the ones the eraser has passed over but not
  /// yet committed.
  final _hidden = <int>{};

  final _undo = <_Op>[];
  final _redo = <_Op>[];

  int _pointerCount = 0;
  int? _activePointer;
  _Gesture _gesture = _Gesture.none;
  Offset _gestureStart = Offset.zero;
  WhiteboardElement? _gestureOriginal;
  bool _fitted = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(WhiteboardCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.board.id != widget.board.id) {
      _selectedId = null;
      _undo.clear();
      _redo.clear();
      _hidden.clear();
      _fitted = false;
      _listen();
    }
  }

  void _listen() {
    _subscription?.cancel();
    _subscription =
        widget.repository.watchElements(widget.board.id).listen((elements) {
      if (!mounted) return;
      setState(() {
        _elements = elements;
        if (_selectedId != null &&
            !elements.any((element) => element.id == _selectedId)) {
          _selectedId = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _transform.dispose();
    _draft.dispose();
    _focus.dispose();
    super.dispose();
  }

  double get _scale => _transform.value.getMaxScaleOnAxis();

  WhiteboardElement? get _selected =>
      _elements.where((element) => element.id == _selectedId).firstOrNull;

  // ---------------------------------------------------------------- history

  Future<void> _run(_Op op) async {
    await op.redo(widget.repository);
    _undo.add(op);
    _redo.clear();
    if (mounted) setState(() {});
  }

  Future<void> _undoLast() async {
    if (_undo.isEmpty || _busy) return;
    final op = _undo.removeLast();
    setState(() => _busy = true);
    try {
      await op.undo(widget.repository);
      _redo.add(op);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redoLast() async {
    if (_redo.isEmpty || _busy) return;
    final op = _redo.removeLast();
    setState(() => _busy = true);
    try {
      await op.redo(widget.repository);
      _undo.add(op);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------- pointer

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    _focus.requestFocus();
    if (_pointerCount > 1) {
      // A second finger means the user is pinching to zoom, not drawing.
      _abandonGesture();
      return;
    }
    if (_tool == WhiteboardTool.pan) return;
    _activePointer = event.pointer;
    _gestureStart = event.localPosition;

    switch (_tool) {
      case WhiteboardTool.select:
        _beginSelect(event.localPosition);
      case WhiteboardTool.eraser:
        _gesture = _Gesture.erasing;
        _eraseAt(event.localPosition);
      case WhiteboardTool.note:
      case WhiteboardTool.text:
        _gesture = _Gesture.none;
        unawaited(_placeTextual(event.localPosition));
      default:
        final kind = _tool.kind;
        if (kind == null) return;
        _gesture = _Gesture.drawing;
        _draft.value = _Draft(
          element: WhiteboardElement(
            kind: kind,
            points: [event.localPosition, event.localPosition],
            color: _ink,
            strokeWidth: _strokeWidth,
          ),
        );
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _pointerCount > 1) return;
    final position = event.localPosition;
    switch (_gesture) {
      case _Gesture.none:
        return;
      case _Gesture.drawing:
        final element = _draft.value.element;
        if (element == null) return;
        if (_tool.isDragShape) {
          _draft.value = _Draft(
            element: element.copyWith(points: [element.points.first, position]),
          );
        } else {
          // Sampling every event would store hundreds of points a second;
          // a 2-unit floor keeps the curve identical and the row small.
          final last = element.points.last;
          if ((position - last).distance < 2) return;
          _draft.value = _Draft(
            element: element.copyWith(points: [...element.points, position]),
          );
        }
      case _Gesture.moving:
        final original = _gestureOriginal;
        if (original == null) return;
        _draft.value =
            _Draft(element: original.translated(position - _gestureStart));
      case _Gesture.resizing:
        final original = _gestureOriginal;
        if (original == null) return;
        final box = original.bounds;
        final target = Rect.fromLTRB(
          box.left,
          box.top,
          math.max(box.left + 8, position.dx),
          math.max(box.top + 8, position.dy),
        );
        _draft.value = _Draft(element: original.resizedTo(target));
      case _Gesture.erasing:
        _eraseAt(position);
    }
  }

  void _onPointerUp(PointerEvent event) {
    _pointerCount = math.max(0, _pointerCount - 1);
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    final gesture = _gesture;
    final element = _draft.value.element;
    _gesture = _Gesture.none;
    _draft.value = const _Draft();

    switch (gesture) {
      case _Gesture.none:
        return;
      case _Gesture.drawing:
        if (element == null || !_isWorthKeeping(element)) return;
        unawaited(_run(_AddOp(widget.board.id, element)));
      case _Gesture.moving:
      case _Gesture.resizing:
        final original = _gestureOriginal;
        _gestureOriginal = null;
        setState(() => _hidden.clear());
        if (original == null || element == null) return;
        if (element.points.length == original.points.length &&
            element.bounds == original.bounds) {
          return;
        }
        unawaited(_run(_ChangeOp(before: original, after: element)));
      case _Gesture.erasing:
        final erased = _elements
            .where((candidate) => _hidden.contains(candidate.id))
            .toList(growable: false);
        setState(() => _hidden.clear());
        if (erased.isEmpty) return;
        unawaited(_run(_RemoveOp(widget.board.id, erased)));
    }
  }

  /// Drops the taps that were meant as "deselect", not as a dot or a shape of
  /// zero size — without this every stray click leaves a speck on the board.
  bool _isWorthKeeping(WhiteboardElement element) {
    if (element.kind.isFreehand) return true;
    final box = element.bounds;
    return box.width > 4 || box.height > 4;
  }

  void _abandonGesture() {
    _gesture = _Gesture.none;
    _activePointer = null;
    _gestureOriginal = null;
    _draft.value = const _Draft();
    if (_hidden.isNotEmpty) setState(() => _hidden.clear());
  }

  void _beginSelect(Offset position) {
    final selected = _selected;
    if (selected != null &&
        handleRect(selected.bounds, _scale).inflate(4 / _scale)
            .contains(position)) {
      _gesture = _Gesture.resizing;
      _gestureOriginal = selected;
      setState(() => _hidden.add(selected.id));
      _draft.value = _Draft(element: selected);
      return;
    }
    // Topmost first: what is drawn last is what the user sees and expects to
    // grab.
    final hit = _elements.reversed.where(
      (element) => element.hitTest(position, tolerance: 8 / _scale),
    ).firstOrNull;
    if (hit == null) {
      if (_selectedId != null) setState(() => _selectedId = null);
      return;
    }
    _gesture = _Gesture.moving;
    _gestureOriginal = hit;
    setState(() {
      _selectedId = hit.id;
      _hidden.add(hit.id);
    });
    _draft.value = _Draft(element: hit);
  }

  void _eraseAt(Offset position) {
    final radius = math.max(10.0, _strokeWidth * 3);
    _draft.value = _Draft(eraser: position, eraserRadius: radius);
    final touched = _elements.where(
      (element) =>
          !_hidden.contains(element.id) &&
          element.hitTest(position, tolerance: radius),
    );
    if (touched.isEmpty) return;
    setState(() => _hidden.addAll(touched.map((element) => element.id)));
  }

  // ------------------------------------------------------------ text & note

  Future<void> _placeTextual(Offset position) async {
    final isNote = _tool == WhiteboardTool.note;
    final text = await _promptForText(
      title: isNote ? 'New sticky note' : 'New text',
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    final element = WhiteboardElement(
      kind: isNote ? WhiteboardKind.note : WhiteboardKind.text,
      points: [position],
      color: isNote ? whiteboardNoteFill(_ink).toARGB32() : _ink,
      strokeWidth: _strokeWidth,
      text: text.trim(),
      size: isNote ? const Size(200, 150) : const Size(260, 18),
    );
    await _run(_AddOp(widget.board.id, element));
    if (mounted) setState(() => _tool = WhiteboardTool.select);
  }

  Future<void> _editSelectedText() async {
    final selected = _selected;
    if (selected == null || !selected.kind.isTextual) return;
    final text = await _promptForText(
      title: selected.kind == WhiteboardKind.note ? 'Edit note' : 'Edit text',
      initial: selected.text,
    );
    if (text == null || !mounted) return;
    if (text.trim() == selected.text) return;
    if (text.trim().isEmpty) {
      await _run(_RemoveOp(widget.board.id, [selected]));
      return;
    }
    await _run(
      _ChangeOp(before: selected, after: selected.copyWith(text: text.trim())),
    );
  }

  Future<String?> _promptForText({
    required String title,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Text',
            helperText: 'Shift+Enter for a new line',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Done'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  // ------------------------------------------------------------------ board

  Future<void> _deleteSelection() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() => _selectedId = null);
    await _run(_RemoveOp(widget.board.id, [selected]));
  }

  Future<void> _clear() async {
    if (_elements.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear the board?'),
        content: Text(
          'All ${_elements.length} things on "${widget.board.title}" will be '
          'removed. You can undo this straight afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.luma.danger,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;
    final all = List<WhiteboardElement>.from(_elements);
    setState(() => _selectedId = null);
    await _run(_RemoveOp(widget.board.id, all));
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final brightness = Theme.of(context).brightness;
    try {
      final summary = await WhiteboardExport.savePng(
        elements: _elements,
        title: widget.board.title,
        paper: whiteboardPaper(brightness),
      );
      if (summary != null) {
        messenger.showSnackBar(SnackBar(content: Text(summary)));
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not export the board: $error')),
      );
    }
  }

  // ------------------------------------------------------------------- view

  void _zoomBy(double factor) {
    final viewport = _viewerKey.currentContext?.size;
    if (viewport == null) return;
    final centre = Offset(viewport.width / 2, viewport.height / 2);
    final scene = _transform.toScene(centre);
    final next = (_scale * factor).clamp(0.15, 6.0);
    final applied = next / _scale;
    if (applied == 1) return;
    setState(() {
      _transform.value = _transform.value.clone()
        ..translateByDouble(scene.dx, scene.dy, 0, 1)
        ..scaleByDouble(applied, applied, 1, 1)
        ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
    });
  }

  /// Centres the board's content, or the middle of the sheet when it is empty.
  void _fit() {
    final viewport = _viewerKey.currentContext?.size;
    if (viewport == null) return;
    final content = _contentBounds();
    final scale = content == null
        ? 1.0
        : math
            .min(
              math.min(
                viewport.width / (content.width + 160),
                viewport.height / (content.height + 160),
              ),
              1.6,
            )
            .clamp(0.15, 6.0)
            .toDouble();
    final focus = content?.center ??
        Offset(kWhiteboardSize.width / 2, kWhiteboardSize.height / 2);
    setState(() {
      _transform.value = Matrix4.identity()
        ..translateByDouble(viewport.width / 2, viewport.height / 2, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1)
        ..translateByDouble(-focus.dx, -focus.dy, 0, 1);
    });
  }

  Rect? _contentBounds() {
    if (_elements.isEmpty) return null;
    var box = _elements.first.bounds;
    for (final element in _elements.skip(1)) {
      box = box.expandToInclude(element.bounds);
    }
    return box;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final control = keys.isControlPressed || keys.isMetaPressed;
    if (control) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyZ:
          if (keys.isShiftPressed) {
            unawaited(_redoLast());
          } else {
            unawaited(_undoLast());
          }
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyY:
          unawaited(_redoLast());
          return KeyEventResult.handled;
        case LogicalKeyboardKey.digit0:
          _fit();
          return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      unawaited(_deleteSelection());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_selectedId != null) {
        setState(() => _selectedId = null);
        return KeyEventResult.handled;
      }
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      unawaited(_editSelectedText());
      return KeyEventResult.handled;
    }
    final label = event.logicalKey.keyLabel.toUpperCase();
    for (final option in WhiteboardTool.values) {
      if (option.shortcut == label) {
        setState(() => _tool = option);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final brightness = Theme.of(context).brightness;
    final narrow = MediaQuery.sizeOf(context).width < 760;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Padding(
        padding: EdgeInsets.fromLTRB(narrow ? 8 : 16, 4, narrow ? 8 : 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              title: widget.board.title,
              count: _elements.length,
              narrow: narrow,
              onClose: widget.onClose,
              viewBar: ListenableBuilder(
                listenable: _transform,
                builder: (context, _) => WhiteboardViewBar(
                  zoom: _scale,
                  showGrid: _showGrid,
                  onZoom: _zoomBy,
                  onFit: _fit,
                  onToggleGrid: () => setState(() => _showGrid = !_showGrid),
                  onExport: () => unawaited(_export()),
                  onClear: () => unawaited(_clear()),
                ),
              ),
            ),
            const SizedBox(height: 6),
            WhiteboardToolbar(
              tool: _tool,
              ink: _ink,
              strokeWidth: _strokeWidth,
              canUndo: _undo.isNotEmpty && !_busy,
              canRedo: _redo.isNotEmpty && !_busy,
              hasSelection: _selectedId != null,
              onTool: (value) => setState(() => _tool = value),
              onInk: (value) => setState(() => _ink = value),
              onStrokeWidth: (value) => setState(() => _strokeWidth = value),
              onUndo: () => unawaited(_undoLast()),
              onRedo: () => unawaited(_redoLast()),
              onDeleteSelection: () => unawaited(_deleteSelection()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(context.lumaDecor.cardRadius),
                child: Container(
                  key: _viewerKey,
                  decoration: BoxDecoration(
                    border: Border.all(color: luma.border),
                    borderRadius:
                        BorderRadius.circular(context.lumaDecor.cardRadius),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (!_fitted && constraints.hasBoundedHeight) {
                        _fitted = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _fit();
                        });
                      }
                      return _buildViewer(brightness);
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: narrow ? 8 : 12),
          ],
        ),
      ),
    );
  }

  Widget _buildViewer(Brightness brightness) {
    return MouseRegion(
      cursor: switch (_tool) {
        WhiteboardTool.pan => SystemMouseCursors.grab,
        WhiteboardTool.select => SystemMouseCursors.basic,
        WhiteboardTool.eraser => SystemMouseCursors.cell,
        _ => SystemMouseCursors.precise,
      },
      child: InteractiveViewer(
        transformationController: _transform,
        // Panning is a tool, not a background behaviour: with a pen selected a
        // drag must draw, or every stroke would scroll the board away.
        panEnabled: _tool == WhiteboardTool.pan,
        scaleEnabled: true,
        minScale: 0.15,
        maxScale: 6,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(400),
        child: SizedBox(
          width: kWhiteboardSize.width,
          height: kWhiteboardSize.height,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: (event) {
              _pointerCount = math.max(0, _pointerCount - 1);
              _abandonGesture();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => unawaited(_editSelectedText()),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: WhiteboardBackgroundPainter(
                      surface: whiteboardPaper(brightness),
                      dot: whiteboardGrid(brightness),
                      showGrid: _showGrid,
                    ),
                  ),
                  ListenableBuilder(
                    listenable: _transform,
                    builder: (context, _) => CustomPaint(
                      painter: WhiteboardPainter(
                        elements: _hidden.isEmpty
                            ? _elements
                            : _elements
                                .where((e) => !_hidden.contains(e.id))
                                .toList(growable: false),
                        selectedId: _selectedId,
                        accent: context.luma.accent,
                        textScale: _scale,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<_Draft>(
                    valueListenable: _draft,
                    builder: (context, draft, _) => CustomPaint(
                      painter: WhiteboardDraftPainter(
                        draft: draft.element,
                        eraser: draft.eraser,
                        eraserRadius: draft.eraserRadius,
                        danger: context.luma.danger,
                      ),
                    ),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.count,
    required this.narrow,
    required this.onClose,
    required this.viewBar,
  });

  final String title;
  final int count;
  final bool narrow;
  final VoidCallback onClose;
  final Widget viewBar;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final heading = Row(
      children: [
        IconButton(
          tooltip: 'Back to boards  (Esc)',
          onPressed: onClose,
          icon: Icon(Icons.arrow_back_rounded, color: luma.textSecondary),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                count == 1 ? '1 item' : '$count items',
                style: TextStyle(color: luma.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
    // On a phone the view controls drop under the title rather than squeezing
    // it to nothing.
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [heading, viewBar],
      );
    }
    return Row(children: [Expanded(child: heading), viewBar]);
  }
}

enum _Gesture { none, drawing, moving, resizing, erasing }

/// What the top painting layer is showing right now.
class _Draft {
  const _Draft({this.element, this.eraser, this.eraserRadius = 12});

  final WhiteboardElement? element;
  final Offset? eraser;
  final double eraserRadius;
}

/// One undoable change.
///
/// Re-inserting a deleted row gives it a new id, so every op keeps the
/// element it is responsible for and replaces it with what the repository
/// hands back — otherwise a second undo would target a row that is gone.
abstract class _Op {
  Future<void> undo(WhiteboardRepository repository);
  Future<void> redo(WhiteboardRepository repository);
}

class _AddOp extends _Op {
  _AddOp(this.boardId, this.element);

  final int boardId;
  WhiteboardElement element;

  @override
  Future<void> redo(WhiteboardRepository repository) async {
    element = await repository.addElement(boardId, element);
  }

  @override
  Future<void> undo(WhiteboardRepository repository) =>
      repository.deleteElements(boardId, [element.id]);
}

class _RemoveOp extends _Op {
  _RemoveOp(this.boardId, this.elements);

  final int boardId;
  List<WhiteboardElement> elements;

  @override
  Future<void> redo(WhiteboardRepository repository) => repository
      .deleteElements(boardId, [for (final e in elements) e.id]);

  @override
  Future<void> undo(WhiteboardRepository repository) async {
    elements = await repository.addElements(boardId, elements);
  }
}

class _ChangeOp extends _Op {
  _ChangeOp({required this.before, required this.after});

  final WhiteboardElement before;
  final WhiteboardElement after;

  @override
  Future<void> redo(WhiteboardRepository repository) =>
      repository.updateElement(after);

  @override
  Future<void> undo(WhiteboardRepository repository) =>
      repository.updateElement(before);
}
