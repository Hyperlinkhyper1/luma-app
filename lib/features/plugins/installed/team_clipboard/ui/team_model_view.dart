import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../team_clipboard_controller.dart';
import '../team_clipboard_models.dart';
import '../team_clipboard_scope.dart';
import '../team_model_mesh.dart';
import 'team_files.dart';

/// Whether the viewer can show [file]: a texture, or a .json that may turn
/// out to be a model once it's read.
bool teamViewable(TeamFile file) => file.isImage || file.extension == 'json';

/// The big preview at the top of an entry's files: a texture, flat or as
/// the game holds it, or a model in 3D wearing the entry's textures. Drag
/// turns it, scrolling or pinching zooms, a double tap puts it back.
class TeamFileViewer extends StatefulWidget {
  const TeamFileViewer({
    super.key,
    required this.entry,
    required this.subjectId,
    required this.onSubject,
  });

  final TeamEntry entry;

  /// The file on show; null lets the viewer pick, a model first.
  final String? subjectId;
  final ValueChanged<String> onSubject;

  @override
  State<TeamFileViewer> createState() => _TeamFileViewerState();
}

class _TeamFileViewerState extends State<TeamFileViewer> {
  TeamClipboardController? _controller;
  final _images = <String, ui.Image>{};
  final _sprites = <String, TeamSprite>{};
  final _json = <String, Map<String, dynamic>?>{};
  final _failed = <String>{};
  final _loading = <String>{};
  final _paints = <ui.Image, Paint>{};
  ui.Image? _missing;

  bool _textureIn3d = false;
  double _yaw = 0, _pitch = 0, _zoom = 1;
  double _zoomAtStart = 1;
  String? _viewFor;

  String? _meshFor;
  TeamModelMesh? _mesh;
  Duration _frameTime = const Duration(milliseconds: 50);
  String? _frameTimeFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      _controller = TeamClipboardScope.read(context);
      _sync();
      ui.decodeImageFromPixels(
        Uint8List.fromList([
          ...[248, 0, 248, 255, 0, 0, 0, 255],
          ...[0, 0, 0, 255, 248, 0, 248, 255],
        ]),
        2,
        2,
        ui.PixelFormat.rgba8888,
        (image) => mounted ? setState(() => _missing = image) : image.dispose(),
      );
    }
  }

  @override
  void didUpdateWidget(TeamFileViewer old) {
    super.didUpdateWidget(old);
    if (!identical(old.entry.files, widget.entry.files)) _sync();
  }

  @override
  void dispose() {
    for (final image in _images.values) {
      image.dispose();
    }
    _missing?.dispose();
    super.dispose();
  }

  List<TeamFile> get _files => widget.entry.files.where(teamViewable).toList();

  /// Loads what's new, forgets what was removed.
  void _sync() {
    final ids = {for (final f in _files) f.id};
    for (final id in _images.keys.where((id) => !ids.contains(id)).toList()) {
      _images.remove(id)?.dispose();
      _sprites.remove(id);
    }
    _json.removeWhere((id, _) => !ids.contains(id));
    _meshFor = null;
    for (final f in _files) {
      final known =
          _images.containsKey(f.id) ||
          _json.containsKey(f.id) ||
          _failed.contains(f.id) ||
          _loading.contains(f.id);
      if (!known) _load(f);
    }
  }

  Future<void> _load(TeamFile file) async {
    _loading.add(file.id);
    try {
      final bytes = await _controller!.file(file.id);
      if (bytes == null) throw StateError('no bytes');
      if (file.isImage) {
        final image = await decodeImageFromList(bytes);
        // Pixels are only needed to give a small item sprite its edges.
        final data = image.width * image.height <= 1 << 20
            ? await image.toByteData(format: ui.ImageByteFormat.rawRgba)
            : null;
        if (!mounted) return image.dispose();
        setState(() {
          _images.remove(file.id)?.dispose();
          _images[file.id] = image;
          _sprites[file.id] = TeamSprite(
            key: file.id,
            width: image.width,
            height: image.height,
            rgba: data?.buffer.asUint8List(),
          );
          _meshFor = null;
        });
      } else {
        final decoded = jsonDecode(utf8.decode(bytes));
        if (!mounted) return;
        setState(() {
          _json[file.id] =
              decoded is Map<String, dynamic> && teamLooksLikeModel(decoded)
              ? decoded
              : null;
          _meshFor = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed.add(file.id));
    } finally {
      _loading.remove(file.id);
    }
  }

  TeamFile? get _subject {
    final files = _files;
    if (files.isEmpty) return null;
    return files.where((f) => f.id == widget.subjectId).firstOrNull ??
        files.where((f) => _json[f.id] != null).firstOrNull ??
        files.where((f) => f.isImage).firstOrNull ??
        files.first;
  }

  bool _in3d(TeamFile subject) => !subject.isImage || _textureIn3d;

  /// Faces each new subject the way the game shows it in an inventory: a
  /// block from above one corner, an item nearly face-on.
  void _resetView(TeamFile subject) {
    final item = subject.isImage || (_mesh != null && _flat);
    _yaw = item ? -0.45 : -math.pi / 4;
    _pitch = item ? 0.2 : 0.52;
    _zoom = item ? 1.25 : 1;
  }

  /// A model whose faces all lie within the one-pixel slab an item sprite
  /// is extruded into.
  bool get _flat => _mesh!.quads.every(
    (q) => [2, 5, 8, 11].every((i) => q.points[i] >= 7.4 && q.points[i] <= 8.6),
  );

  TeamModelMesh? _meshOf(TeamFile subject) {
    final key = '${subject.id}/${subject.isImage}';
    if (_meshFor == key) return _mesh;
    TeamModelMesh? mesh;
    if (subject.isImage) {
      final sprite = _sprites[subject.id];
      if (sprite != null) mesh = teamItemMesh(sprite);
    } else if (_json[subject.id] case final model?) {
      final models = <String, Map<String, dynamic>>{};
      final sprites = <String, TeamSprite>{};
      for (final f in widget.entry.files) {
        final json = _json[f.id];
        if (json != null && f.id != subject.id) {
          models.putIfAbsent(teamRefName(f.name), () => json);
        }
        final sprite = _sprites[f.id];
        if (sprite != null) {
          sprites.putIfAbsent(teamRefName(f.name), () => sprite);
        }
      }
      mesh = buildTeamModelMesh(model, models: models, sprites: sprites);
    }
    _meshFor = mesh == null ? null : key;
    _mesh = mesh;
    return mesh;
  }

  Future<void> _loadFrameTime(TeamFile subject) async {
    _frameTimeFor = subject.id;
    _frameTime = const Duration(milliseconds: 50);
    final time = await teamFrameTime(_controller!, widget.entry, subject);
    if (time != null && mounted && _frameTimeFor == subject.id) {
      setState(() => _frameTime = time);
    }
  }

  Paint _paintFor(ui.Image image) => _paints[image] ??= Paint()
    ..filterQuality = FilterQuality.none
    ..shader = ui.ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
      filterQuality: FilterQuality.none,
    );

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final subject = _subject;
    if (subject == null) return const SizedBox.shrink();
    final mesh = _meshOf(subject);
    if (_viewFor != '${subject.id}/${mesh != null}') {
      _viewFor = '${subject.id}/${mesh != null}';
      _resetView(subject);
    }
    if (subject.isImage && _frameTimeFor != subject.id) {
      _loadFrameTime(subject);
    }
    final threeD = _in3d(subject);
    final failed = _failed.contains(subject.id);
    final loaded = subject.isImage
        ? _images.containsKey(subject.id)
        : _json.containsKey(subject.id);
    final notModel = loaded && !subject.isImage && _json[subject.id] == null;
    final missing = _loading.isEmpty && mesh != null && threeD
        ? mesh.missing
        : const <String>[];
    final dark = Theme.of(context).brightness == Brightness.dark;

    final Widget stage;
    if (failed) {
      stage = _Message(
        icon: Icons.broken_image_rounded,
        text: t.teamClipboardCouldNotLoad,
      );
    } else if (!loaded) {
      stage = const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (notModel) {
      stage = _Message(
        icon: Icons.data_object_rounded,
        text: t.teamClipboardViewerNotModel,
        action: TextButton(
          onPressed: () => showTeamFilePreview(context, widget.entry, subject),
          child: Text(t.teamClipboardViewerShowJson),
        ),
      );
    } else if (!threeD) {
      final sprite = _sprites[subject.id]!;
      stage = Padding(
        padding: const EdgeInsets.fromLTRB(20, 54, 20, 20),
        child: Center(
          child: AspectRatio(
            aspectRatio: sprite.width / sprite.frameHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TeamTexture(
                bytes: _controller!.cachedFile(subject.id)!,
                animate: true,
                frameTime: _frameTime,
                cell: 12,
              ),
            ),
          ),
        ),
      );
    } else if (mesh == null || mesh.isEmpty) {
      stage = _Message(
        icon: Icons.view_in_ar_rounded,
        text: t.teamClipboardViewerEmpty,
      );
    } else {
      final textures = <String, (ui.Image, int)>{
        for (final e in _sprites.entries)
          if (_images[e.key] case final image?)
            e.key: (image, e.value.frameHeight),
      };
      stage = Listener(
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          GestureBinding.instance.pointerSignalResolver.register(event, (e) {
            final dy = (e as PointerScrollEvent).scrollDelta.dy;
            setState(() => _zoom = (_zoom * math.exp(-dy / 500)).clamp(0.3, 8));
          });
        },
        child: GestureDetector(
          onDoubleTap: () => setState(() => _resetView(subject)),
          onScaleStart: (_) => _zoomAtStart = _zoom,
          onScaleUpdate: (d) => setState(() {
            if (d.pointerCount > 1) {
              _zoom = (_zoomAtStart * d.scale).clamp(0.3, 8);
            }
            _yaw += d.focalPointDelta.dx * 0.012;
            _pitch = (_pitch + d.focalPointDelta.dy * 0.012).clamp(
              -math.pi / 2,
              math.pi / 2,
            );
          }),
          child: CustomPaint(
            size: Size.infinite,
            painter: _ModelPainter(
              mesh: mesh,
              textures: textures,
              missing: _missing,
              paintFor: _paintFor,
              yaw: _yaw,
              pitch: _pitch,
              zoom: _zoom,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
        gradient: threeD && !failed
            ? RadialGradient(
                radius: 0.9,
                colors: dark
                    ? [const Color(0xFF2B2738), const Color(0xFF17151E)]
                    : [const Color(0xFFFFFFFF), const Color(0xFFE8E4F0)],
              )
            : null,
        color: threeD ? null : luma.background,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: stage),
          Positioned(
            left: 8,
            top: 8,
            right: 8,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SubjectMenu(
                      files: _files,
                      subject: subject,
                      isModel: (f) => _json[f.id] != null,
                      onPick: widget.onSubject,
                    ),
                  ),
                ),
                if (subject.isImage && loaded && !failed)
                  _Toggle(
                    left: t.teamClipboardViewer2d,
                    right: t.teamClipboardViewer3d,
                    rightOn: _textureIn3d,
                    onChanged: (on) => setState(() => _textureIn3d = on),
                  ),
                if (!subject.isImage && loaded && !notModel)
                  _OverlayButton(
                    icon: Icons.data_object_rounded,
                    tooltip: t.teamClipboardViewerShowJson,
                    onTap: () =>
                        showTeamFilePreview(context, widget.entry, subject),
                  ),
                if (threeD && mesh != null && !mesh.isEmpty)
                  _OverlayButton(
                    icon: Icons.center_focus_strong_rounded,
                    tooltip: t.teamClipboardViewerReset,
                    onTap: () => setState(() => _resetView(subject)),
                  ),
              ],
            ),
          ),
          if (missing.isNotEmpty || (threeD && mesh != null && !mesh.isEmpty))
            Positioned(
              left: 12,
              right: 12,
              bottom: 8,
              child: IgnorePointer(
                child: Text(
                  missing.isNotEmpty
                      ? t.teamClipboardViewerMissing(missing.join(', '))
                      : t.teamClipboardViewerHint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: missing.isNotEmpty ? luma.warning : luma.textMuted,
                    fontSize: 12,
                    fontWeight: missing.isNotEmpty
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: luma.textMuted, size: 28),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
            if (action != null) ...[const SizedBox(height: 6), action!],
          ],
        ),
      ),
    );
  }
}

/// The name of the file on show; tapping it lists the others.
class _SubjectMenu extends StatelessWidget {
  const _SubjectMenu({
    required this.files,
    required this.subject,
    required this.isModel,
    required this.onPick,
  });

  final List<TeamFile> files;
  final TeamFile subject;
  final bool Function(TeamFile) isModel;
  final ValueChanged<String> onPick;

  IconData _icon(TeamFile f) => f.isImage
      ? Icons.image_rounded
      : isModel(f)
      ? Icons.view_in_ar_rounded
      : Icons.data_object_rounded;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icon(subject), size: 16, color: luma.accent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            subject.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (files.length > 1) ...[
          const SizedBox(width: 2),
          Icon(Icons.expand_more_rounded, size: 18, color: luma.textSecondary),
        ],
      ],
    );
    final chip = Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: luma.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: luma.border),
      ),
      child: label,
    );
    if (files.length < 2) return chip;
    return PopupMenuButton<String>(
      tooltip: L.of(context).teamClipboardViewerPick,
      onSelected: onPick,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final f in files)
          PopupMenuItem(
            value: f.id,
            child: Row(
              children: [
                Icon(
                  _icon(f),
                  size: 18,
                  color: f.id == subject.id ? luma.accent : luma.textSecondary,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    f.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontWeight: f.id == subject.id
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: chip,
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.left,
    required this.right,
    required this.rightOn,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool rightOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    Widget side(String label, bool on, bool value) => Semantics(
      button: true,
      selected: on,
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: on ? luma.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? luma.onAccent : luma.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: luma.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [side(left, !rightOn, false), side(right, rightOn, true)],
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        color: luma.textSecondary,
        style: IconButton.styleFrom(
          backgroundColor: luma.surface.withValues(alpha: 0.88),
          side: BorderSide(color: luma.border),
          minimumSize: const Size(34, 34),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

/// Draws a [TeamModelMesh] with an orbiting orthographic camera. There's no
/// depth buffer, so faces turned away are dropped and the rest are drawn
/// far to near; neighbouring faces that share a texture go out in one
/// [Canvas.drawVertices] call.
class _ModelPainter extends CustomPainter {
  _ModelPainter({
    required this.mesh,
    required this.textures,
    required this.missing,
    required this.paintFor,
    required this.yaw,
    required this.pitch,
    required this.zoom,
  });

  final TeamModelMesh mesh;

  /// Image and frame height by [TeamModelQuad.texture].
  final Map<String, (ui.Image, int)> textures;

  /// The game's magenta-and-black stand-in for a texture that isn't there.
  final ui.Image? missing;
  final Paint Function(ui.Image) paintFor;
  final double yaw;
  final double pitch;
  final double zoom;

  static const _triangle = [0, 1, 2, 0, 2, 3];

  @override
  void paint(Canvas canvas, Size size) {
    if (mesh.isEmpty || size.isEmpty) return;
    final (cx, cy, cz, radius) = mesh.bounds;
    final scale =
        math.min(size.width, size.height) / (2 * radius) * 0.78 * zoom;
    final cosY = math.cos(yaw), sinY = math.sin(yaw);
    final cosP = math.cos(pitch), sinP = math.sin(pitch);
    final ox = size.width / 2, oy = size.height / 2;

    final quads = mesh.quads;
    final screen = Float32List(quads.length * 8);
    final depth = Float64List(quads.length);
    final order = <int>[];
    for (var i = 0; i < quads.length; i++) {
      final p = quads[i].points;
      var d = 0.0;
      for (var k = 0; k < 4; k++) {
        final x = p[k * 3] - cx;
        final y = p[k * 3 + 1] - cy;
        final z = p[k * 3 + 2] - cz;
        final x1 = x * cosY + z * sinY;
        final z1 = -x * sinY + z * cosY;
        screen[i * 8 + k * 2] = ox + x1 * scale;
        screen[i * 8 + k * 2 + 1] = oy - (y * cosP - z1 * sinP) * scale;
        d += y * sinP + z1 * cosP;
      }
      // Screen y runs down, so a face seen from its front winds with a
      // positive area; one seen from behind is turned away, as in game.
      var area = 0.0;
      for (var k = 0; k < 4; k++) {
        final j = (k + 1) % 4;
        area +=
            screen[i * 8 + k * 2] * screen[i * 8 + j * 2 + 1] -
            screen[i * 8 + j * 2] * screen[i * 8 + k * 2 + 1];
      }
      if (area <= 0) continue;
      depth[i] = d;
      order.add(i);
    }
    order.sort((a, b) {
      final c = depth[a].compareTo(depth[b]);
      return c != 0 ? c : a - b;
    });

    var start = 0;
    while (start < order.length) {
      final texture = quads[order[start]].texture;
      var end = start + 1;
      while (end < order.length && quads[order[end]].texture == texture) {
        end++;
      }
      _draw(canvas, order, start, end, texture, screen);
      start = end;
    }
  }

  void _draw(
    Canvas canvas,
    List<int> order,
    int start,
    int end,
    String? texture,
    Float32List screen,
  ) {
    final found = texture == null ? null : textures[texture];
    final image = found?.$1 ?? missing;
    if (image == null) return;
    final w = image.width.toDouble();
    final h = (found?.$2 ?? image.height).toDouble();
    final count = end - start;
    final positions = Float32List(count * 12);
    final uvs = Float32List(count * 12);
    final colors = Int32List(count * 6);
    var n = 0;
    for (var o = start; o < end; o++) {
      final i = order[o];
      final quad = mesh.quads[i];
      final g = (quad.shade * 255).round().clamp(0, 255);
      final color = 0xFF000000 | g << 16 | g << 8 | g;
      for (final k in _triangle) {
        positions[n * 2] = screen[i * 8 + k * 2];
        positions[n * 2 + 1] = screen[i * 8 + k * 2 + 1];
        uvs[n * 2] = quad.uvs[k * 2] * w;
        uvs[n * 2 + 1] = quad.uvs[k * 2 + 1] * h;
        colors[n] = color;
        n++;
      }
    }
    canvas.drawVertices(
      ui.Vertices.raw(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: uvs,
        colors: colors,
      ),
      BlendMode.modulate,
      paintFor(image),
    );
  }

  @override
  bool shouldRepaint(_ModelPainter old) =>
      old.mesh != mesh ||
      old.missing != missing ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.zoom != zoom ||
      old.textures.length != textures.length;
}
