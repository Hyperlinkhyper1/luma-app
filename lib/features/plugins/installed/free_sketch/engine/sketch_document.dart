import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:ui' show Color, Path, Rect;

import 'package:flutter/foundation.dart';

import '../../../../../l10n/current_l.dart';
import '../model/sketch_blend.dart';

/// One layer. Immutable: every edit produces a new [SketchLayer], so a
/// snapshot of the whole document is just a list of references.
@immutable
class SketchLayer {
  const SketchLayer({
    required this.id,
    required this.name,
    this.image,
    this.opacity = 1,
    this.blend = SketchBlend.normal,
    this.visible = true,
    this.locked = false,
    this.alphaLocked = false,
    this.clipped = false,
  });

  final int id;
  final String name;

  /// Canvas-sized pixels, or null for a layer nothing has been drawn on yet —
  /// an empty layer costs no memory until it is painted.
  final ui.Image? image;
  final double opacity;
  final SketchBlend blend;
  final bool visible;

  /// Refuses every pixel edit.
  final bool locked;

  /// Paint only lands where the layer already has pixels.
  final bool alphaLocked;

  /// Clipping mask: shows only through the layer below it.
  final bool clipped;

  SketchLayer copyWith({
    String? name,
    ui.Image? image,
    bool clearImage = false,
    double? opacity,
    SketchBlend? blend,
    bool? visible,
    bool? locked,
    bool? alphaLocked,
    bool? clipped,
  }) => SketchLayer(
    id: id,
    name: name ?? this.name,
    image: clearImage ? null : (image ?? this.image),
    opacity: opacity ?? this.opacity,
    blend: blend ?? this.blend,
    visible: visible ?? this.visible,
    locked: locked ?? this.locked,
    alphaLocked: alphaLocked ?? this.alphaLocked,
    clipped: clipped ?? this.clipped,
  );
}

/// The whole document at one moment — what undo steps back to.
@immutable
class SketchSnapshot {
  const SketchSnapshot({
    required this.layers,
    required this.activeLayerId,
    required this.background,
    this.showBackground = true,
    this.selection,
  });

  /// Bottom to top.
  final List<SketchLayer> layers;
  final int activeLayerId;
  final Color background;

  /// Off exports a transparent PNG.
  final bool showBackground;

  /// Canvas-space selection. Painting, fills and transforms stay inside it.
  final Path? selection;

  int get activeIndex {
    final index = layers.indexWhere((layer) => layer.id == activeLayerId);
    return index < 0 ? layers.length - 1 : index;
  }

  SketchLayer get active => layers[activeIndex];

  SketchLayer? layerById(int id) {
    for (final layer in layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  SketchSnapshot copyWith({
    List<SketchLayer>? layers,
    int? activeLayerId,
    Color? background,
    bool? showBackground,
    Path? selection,
    bool clearSelection = false,
  }) => SketchSnapshot(
    layers: layers ?? this.layers,
    activeLayerId: activeLayerId ?? this.activeLayerId,
    background: background ?? this.background,
    showBackground: showBackground ?? this.showBackground,
    selection: clearSelection ? null : (selection ?? this.selection),
  );

  SketchSnapshot replaceLayer(SketchLayer layer) => copyWith(
    layers: [
      for (final existing in layers) existing.id == layer.id ? layer : existing,
    ],
  );

  Iterable<ui.Image> get images sync* {
    for (final layer in layers) {
      final image = layer.image;
      if (image != null) yield image;
    }
  }
}

class _Entry {
  const _Entry(this.snapshot, this.label);
  final SketchSnapshot snapshot;
  final String label;
}

/// A document open in the studio: its current [state] plus undo history.
///
/// History is a stack of whole snapshots. Because layers are immutable and
/// share their images, a step costs exactly the pixels it replaced — usually
/// one layer's worth. Old steps are dropped once the history holds more than
/// [memoryBudget] bytes of images the current state no longer uses, and an
/// image is disposed the moment no state can reach it any more.
///
/// With a [baker], every image that enters the document is re-rendered in
/// the background into a standalone image and swapped in for the original.
/// Edits produce their pixels with `toImageSync`, and on the Skia renderer
/// such an image keeps the recording it came from — including the previous
/// version of the layer — alive for as long as it exists. Without the swap
/// every stroke would pin every earlier version of its layer in GPU memory,
/// whatever history says, until the engine runs out and crashes.
class SketchDocument extends ChangeNotifier {
  SketchDocument({
    required this.width,
    required this.height,
    required SketchSnapshot initial,
    this.maxHistory = 100,
    int? memoryBudget,
    this.baker,
    this.onImageReplaced,
  }) : _state = initial,
       memoryBudget = memoryBudget ?? 900 * 1024 * 1024 {
    _known.addAll(initial.images);
    // Loaded layers come straight from a decoder and reference nothing.
    _flat.addAll(initial.images);
    for (final layer in initial.layers) {
      if (layer.id >= _nextLayerId) _nextLayerId = layer.id + 1;
    }
  }

  factory SketchDocument.blank({
    required int width,
    required int height,
    Color background = const Color(0xFFFFFFFF),
    String? firstLayerName,
  }) => SketchDocument(
    width: width,
    height: height,
    initial: SketchSnapshot(
      layers: [
        SketchLayer(
          id: 1,
          name: firstLayerName ?? currentL.freeSketchLayerNumber(1),
        ),
      ],
      activeLayerId: 1,
      background: background,
    ),
  );

  final int width;
  final int height;
  final int maxHistory;

  /// Bytes of history-only images kept before the oldest steps are dropped.
  final int memoryBudget;

  SketchSnapshot _state;
  final _undo = <_Entry>[];
  final _redo = <_Entry>[];
  final _known = HashSet<ui.Image>.identity();
  final _flat = HashSet<ui.Image>.identity();
  final _replaced = Expando<ui.Image>();
  bool _baking = false;
  int _revision = 0;
  int _nextLayerId = 1;
  bool _disposed = false;

  SketchSnapshot get state => _state;

  ui.Size get size => ui.Size(width.toDouble(), height.toDouble());

  Rect get bounds => Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

  /// Bumped on every change, for autosave.
  int get revision => _revision;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  String? get undoLabel => _undo.isEmpty ? null : _undo.last.label;
  String? get redoLabel => _redo.isEmpty ? null : _redo.last.label;
  int get undoDepth => _undo.length;

  int get bytesPerLayer => width * height * 4;

  /// Renders an image into a standalone copy; see the class comment.
  final Future<ui.Image> Function(ui.Image image)? baker;

  /// Told when a baked copy replaces an image, so identity-keyed caches
  /// (autosave's record of what it wrote) can follow along.
  void Function(ui.Image old, ui.Image fresh)? onImageReplaced;

  /// Completes when no background bake is running; for tests.
  Future<void> get settled async {
    while (_baking) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  int takeLayerId() => _nextLayerId++;

  /// Applies [next] as one undoable step.
  void commit(SketchSnapshot next, String label) {
    _undo.add(_Entry(_state, label));
    _redo.clear();
    _state = next;
    _changed();
  }

  /// Shows [next] without recording a step — for a slider being dragged.
  /// Pair with [commitFrom] when the drag ends.
  void preview(SketchSnapshot next) {
    _state = next;
    _changed();
  }

  /// Records one step from [before] to the current state, collapsing a run
  /// of [preview]s into a single undo.
  void commitFrom(SketchSnapshot before, String label) {
    if (identical(before, _state)) return;
    // [before] was captured by the caller before a drag began; a bake may
    // have swapped (and released) one of its images since.
    _undo.add(_Entry(_remap(before), label));
    _redo.clear();
    _changed();
  }

  /// Changes something that is not worth an undo step, like which layer is
  /// active.
  void setQuietly(SketchSnapshot next) {
    _state = next;
    _changed();
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    final entry = _undo.removeLast();
    _redo.add(_Entry(_state, entry.label));
    _state = entry.snapshot;
    _changed();
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    final entry = _redo.removeLast();
    _undo.add(_Entry(_state, entry.label));
    _state = entry.snapshot;
    _changed();
    return true;
  }

  void _changed() {
    _revision++;
    _collect();
    if (!_disposed) notifyListeners();
    _bakeNext();
  }

  SketchSnapshot _remap(SketchSnapshot snapshot) {
    ui.Image? follow(ui.Image? image) {
      var current = image;
      while (current != null) {
        final next = _replaced[current];
        if (next == null) break;
        current = next;
      }
      return current;
    }

    if (!snapshot.images.any((image) => _replaced[image] != null))
      return snapshot;
    return snapshot.copyWith(
      layers: [
        for (final layer in snapshot.layers)
          if (layer.image case final image? when _replaced[image] != null)
            layer.copyWith(image: follow(image))
          else
            layer,
      ],
    );
  }

  void _bakeNext() {
    final bake = baker;
    if (bake == null || _baking || _disposed) return;
    ui.Image? target;
    for (final snapshot in [
      _state,
      for (final e in _redo.reversed) e.snapshot,
      for (final e in _undo.reversed) e.snapshot,
    ]) {
      for (final image in snapshot.images) {
        if (!_flat.contains(image)) {
          target = image;
          break;
        }
      }
      if (target != null) break;
    }
    if (target == null) return;
    final source = target;
    _baking = true;
    bake(source).then(
      (fresh) {
        _baking = false;
        if (_disposed || !_known.contains(source)) {
          fresh.dispose();
        } else {
          _swap(source, fresh);
        }
        _bakeNext();
      },
      onError: (Object _) {
        // Leave it as it is; better an unflattened image than none.
        _baking = false;
        _flat.add(source);
        _bakeNext();
      },
    );
  }

  void _swap(ui.Image old, ui.Image fresh) {
    _replaced[old] = fresh;
    _state = _remap(_state);
    for (final list in [_undo, _redo]) {
      for (var i = 0; i < list.length; i++) {
        list[i] = _Entry(_remap(list[i].snapshot), list[i].label);
      }
    }
    _known
      ..remove(old)
      ..add(fresh);
    _flat.add(fresh);
    old.dispose();
    onImageReplaced?.call(old, fresh);
    // Same pixels, so no revision bump and no autosave; listeners still
    // rebuild so nothing keeps drawing the released handle.
    notifyListeners();
  }

  void _collect() {
    _known.addAll(_state.images);
    final live = HashSet<ui.Image>.identity()..addAll(_state.images);

    int historyBytes() {
      final held = HashSet<ui.Image>.identity();
      for (final entry in [..._undo, ..._redo]) {
        for (final image in entry.snapshot.images) {
          if (!live.contains(image)) held.add(image);
        }
      }
      return held.length * bytesPerLayer;
    }

    while (_undo.isNotEmpty &&
        (_undo.length + _redo.length > maxHistory ||
            historyBytes() > memoryBudget)) {
      _undo.removeAt(0);
    }

    final reachable = HashSet<ui.Image>.identity()..addAll(live);
    for (final entry in [..._undo, ..._redo]) {
      reachable.addAll(entry.snapshot.images);
    }
    final dead = _known.where((image) => !reachable.contains(image)).toList();
    for (final image in dead) {
      image.dispose();
      _known.remove(image);
      _flat.remove(image);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final image in _known) {
      image.dispose();
    }
    _known.clear();
    _undo.clear();
    _redo.clear();
    super.dispose();
  }
}
