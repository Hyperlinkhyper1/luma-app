import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../../../text_library/minecraft/player_skin.dart';
import '../../data/mc_dyes.dart';
import '../../data/skin_model.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_files.dart';
import '../../ui/mc_style.dart';

enum _Tool {
  pencil(Icons.edit_rounded),
  eraser(Icons.auto_fix_normal_rounded),
  fill(Icons.format_color_fill_rounded),
  picker(Icons.colorize_rounded);

  const _Tool(this.icon);
  final IconData icon;

  String label(L t) => switch (this) {
    pencil => t.mcSkinPencil,
    eraser => t.mcSkinEraser,
    fill => t.mcSkinFill,
    picker => t.mcSkinPicker,
  };
}

const _palette = [
  0xFFE0AC8A, 0xFFC98F6E, 0xFF8D5A3B, 0xFF5C3A24, 0xFFF3D5C0, 0xFF3B2A20,
  0xFFB8860B, 0xFFE8D27A, 0xFF7C5AD9, 0xFF3A6EA5, 0xFF2E3A5C, 0xFF5DB862,
  0xFFB02E26, 0xFFF9801D, 0xFFFFFFFF, 0xFF9D9D97, 0xFF474F52, 0xFF1D1D21,
];

/// Paints a skin on a live 3D model or on the flat texture, with undo,
/// classic and slim arms, and PNG import and export.
class SkinEditorTool extends StatefulWidget {
  const SkinEditorTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<SkinEditorTool> createState() => _SkinEditorToolState();
}

class _SkinEditorToolState extends State<SkinEditorTool> {
  McSkin _skin = mcDefaultSkin();
  final List<McSkin> _undo = [];
  final List<McSkin> _redo = [];
  bool _slim = false;
  bool _overlayVisible = true;
  bool _paintOverlay = false;
  _Tool _tool = _Tool.pencil;
  int _color = 0xFF7C5AD9;
  final List<int> _recent = [];
  double _yaw = 0.5;
  double _pitch = 0.18;
  int _revision = 0;
  bool _strokeOpen = false;

  void _beginStroke() {
    if (_strokeOpen) return;
    _strokeOpen = true;
    _undo.add(_skin.copy());
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
  }

  void _endStroke() => _strokeOpen = false;

  void _apply(int x, int y) {
    if (x < 0 || y < 0 || x >= 64 || y >= 64) return;
    switch (_tool) {
      case _Tool.picker:
        final c = _skin.at(x, y);
        if ((c >> 24) == 0) return;
        setState(() {
          _color = c;
          _tool = _Tool.pencil;
        });
        return;
      case _Tool.pencil:
        _beginStroke();
        _skin.put(x, y, _color);
        _remember(_color);
      case _Tool.eraser:
        _beginStroke();
        _skin.put(x, y, 0);
      case _Tool.fill:
        _beginStroke();
        _skin.flood(x, y, _color);
        _remember(_color);
        _endStroke();
    }
    setState(() => _revision++);
  }

  void _remember(int c) {
    if (_recent.isNotEmpty && _recent.first == c) return;
    _recent
      ..remove(c)
      ..insert(0, c);
    if (_recent.length > 10) _recent.removeLast();
  }

  void _undoOnce() {
    if (_undo.isEmpty) return;
    setState(() {
      _redo.add(_skin);
      _skin = _undo.removeLast();
      _revision++;
    });
  }

  void _redoOnce() {
    if (_redo.isEmpty) return;
    setState(() {
      _undo.add(_skin);
      _skin = _redo.removeLast();
      _revision++;
    });
  }

  void _replace(McSkin skin, {bool? slim}) {
    setState(() {
      _undo.add(_skin);
      _redo.clear();
      _skin = skin;
      if (slim != null) _slim = slim;
      _revision++;
    });
  }

  Future<void> _import() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png'],
      withData: true,
    );
    final bytes = picked?.files.firstOrNull?.bytes;
    if (bytes == null) return;
    final skin = McSkin.fromPng(bytes);
    if (skin == null) {
      if (mounted) mcToast(context, L.of(context).mcSkinNotSkin);
      return;
    }
    _replace(skin);
  }

  Future<void> _importUser() async {
    final t = L.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.mcSkinLoadTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.mcSkinLoadBody),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: t.mcSkinUsername),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.mcCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(t.mcSkinLoad)),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      final player = await fetchSkinByName(name.trim());
      final skin = McSkin.fromPng(player.png);
      if (!mounted) return;
      if (skin == null) {
        mcToast(context, t.mcSkinUnsupported);
        return;
      }
      _replace(skin, slim: player.model == 'slim');
    } on Object catch (e) {
      if (mounted) mcToast(context, t.mcSkinLoadError('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final toolbar = McPanel(
      padding: const EdgeInsets.all(10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final tool in _Tool.values)
            Tooltip(
              message: tool.label(t),
              child: IconButton.filledTonal(
                isSelected: _tool == tool,
                onPressed: () => setState(() => _tool = tool),
                icon: Icon(tool.icon, size: 18),
              ),
            ),
          const SizedBox(width: 6),
          McIconButton(icon: Icons.undo_rounded, tooltip: t.mcSkinUndo, onTap: _undo.isEmpty ? null : _undoOnce),
          McIconButton(icon: Icons.redo_rounded, tooltip: t.mcSkinRedo, onTap: _redo.isEmpty ? null : _redoOnce),
          const SizedBox(width: 6),
          FilterChip(
            label: Text(t.mcSkinPaintOuter),
            selected: _paintOverlay,
            onSelected: (v) => setState(() {
              _paintOverlay = v;
              if (v) _overlayVisible = true;
            }),
          ),
          FilterChip(
            label: Text(t.mcSkinShowOuter),
            selected: _overlayVisible,
            onSelected: (v) => setState(() => _overlayVisible = v),
          ),
          FilterChip(
            label: Text(t.mcSkinSlim),
            selected: _slim,
            onSelected: (v) => setState(() => _slim = v),
          ),
        ],
      ),
    );

    final colors = McPanel(
      title: t.mcSkinColour,
      icon: Icons.palette_rounded,
      child: McFormColumn(
        gap: 10,
        children: [
          Row(
            children: [
              McSwatch(color: Color(_color), onTap: () {}, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: McTextField(
                  key: ValueKey(_color),
                  initialValue: mcHex(Color(_color)),
                  monospace: true,
                  onSubmitted: (v) {
                    final c = mcParseHex(v);
                    if (c != null) setState(() => _color = c.toARGB32());
                  },
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final c in _palette)
                McSwatch(
                  color: Color(c),
                  size: 24,
                  selected: c == _color,
                  onTap: () => setState(() => _color = c),
                ),
            ],
          ),
          if (_recent.isNotEmpty) ...[
            Text(t.mcSkinRecent, style: TextStyle(color: luma.textMuted, fontSize: 11.5)),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final c in _recent)
                  McSwatch(color: Color(c), size: 22, onTap: () => setState(() => _color = c)),
              ],
            ),
          ],
          McSlider(
            label: t.mcSkinLightness,
            value: HSLColor.fromColor(Color(_color)).lightness,
            min: 0,
            max: 1,
            format: (v) => '${(v * 100).round()}%',
            onChanged: (v) => setState(
              () => _color = HSLColor.fromColor(Color(_color)).withLightness(v).toColor().toARGB32(),
            ),
          ),
        ],
      ),
    );

    final model = McPanel(
      title: t.mcSkinModel,
      icon: Icons.accessibility_new_rounded,
      trailing: McIconButton(
        icon: Icons.restart_alt_rounded,
        tooltip: t.mcSkinResetView,
        onTap: () => setState(() {
          _yaw = 0.5;
          _pitch = 0.18;
        }),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 420,
            child: _ModelView(
          skin: _skin,
          revision: _revision,
          slim: _slim,
          overlay: _overlayVisible,
          paintOverlay: _paintOverlay,
          yaw: _yaw,
          pitch: _pitch,
          background: luma.surfaceHover,
          onOrbit: (dx, dy) => setState(() {
            _yaw += dx * 0.012;
            _pitch = (_pitch + dy * 0.012).clamp(-1.2, 1.2);
          }),
          onPaint: _apply,
          onStrokeEnd: _endStroke,
            ),
          ),
          McSlider(
            label: t.mcSkinTurn,
            value: ((_yaw + math.pi) % (2 * math.pi)) - math.pi,
            min: -math.pi,
            max: math.pi,
            format: (v) => '${(v * 180 / math.pi).round()}°',
            onChanged: (v) => setState(() => _yaw = v),
          ),
        ],
      ),
    );

    final flat = McPanel(
      title: t.mcSkinTexture,
      icon: Icons.grid_4x4_rounded,
      child: AspectRatio(
        aspectRatio: 1,
        child: _FlatView(
          skin: _skin,
          revision: _revision,
          slim: _slim,
          onPaint: _apply,
          onStrokeEnd: _endStroke,
        ),
      ),
    );

    return widget.host.frame(
      context,
      actions: [
        McButton(label: t.mcSkinOpenPng, icon: Icons.folder_open_rounded, primary: false, onTap: _import),
        McButton(label: t.mcSkinFromUser, icon: Icons.person_search_rounded, primary: false, onTap: _importUser),
        McButton(
          label: t.mcMapSavePng,
          icon: Icons.save_alt_rounded,
          onTap: () => mcSaveBytes(context, _skin.toPng(), fileName: 'skin.png', mimeType: 'image/png'),
        ),
      ],
      child: McFormColumn(
        children: [
          toolbar,
          McSplit(
            controlsWidth: 300,
            controls: McFormColumn(children: [colors, flat]),
            result: McFormColumn(
              children: [
                model,
                Text(
                  t.mcSkinHelp,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The model, drawn face by face from the texture, every texel a quad.
class _ModelView extends StatefulWidget {
  const _ModelView({
    required this.skin,
    required this.revision,
    required this.slim,
    required this.overlay,
    required this.paintOverlay,
    required this.yaw,
    required this.pitch,
    required this.background,
    required this.onOrbit,
    required this.onPaint,
    required this.onStrokeEnd,
  });

  final McSkin skin;
  final int revision;
  final bool slim;
  final bool overlay;
  final bool paintOverlay;
  final double yaw;
  final double pitch;
  final Color background;
  final void Function(double dx, double dy) onOrbit;
  final void Function(int x, int y) onPaint;
  final VoidCallback onStrokeEnd;

  @override
  State<_ModelView> createState() => _ModelViewState();
}

class _ModelViewState extends State<_ModelView> {
  bool _orbiting = false;
  Size _size = Size.zero;

  /// Where on the texture the pointer is, by projecting every face the way
  /// the painter does and taking the nearest one under the point.
  (int, int)? _hit(Offset p) {
    final cam = McSkinCamera(widget.yaw, widget.pitch);
    final scale = _size.height / 40;
    final centre = Offset(_size.width / 2, _size.height / 2);
    Offset project(Vec3 v) {
      final r = cam.apply(v - const Vec3(0, 16, 0));
      return centre + Offset(r.x * scale, -r.y * scale);
    }

    (int, int)? best;
    var bestDepth = -double.infinity;
    for (final box in mcSkinBoxes(slim: widget.slim)) {
      if (box.overlay != widget.paintOverlay) continue;
      for (final f in mcSkinFaces(box)) {
        final n = cam.apply(f.normal);
        if (n.z <= 0) continue;
        final o = project(f.origin);
        final a = project(f.origin + f.across) - o;
        final b = project(f.origin + f.down) - o;
        final det = a.dx * b.dy - a.dy * b.dx;
        if (det.abs() < 1e-6) continue;
        final q = p - o;
        final s = (q.dx * b.dy - q.dy * b.dx) / det;
        final t = (a.dx * q.dy - a.dy * q.dx) / det;
        if (s < 0 || s >= 1 || t < 0 || t >= 1) continue;
        final centreDepth = cam.apply(f.origin + f.across * 0.5 + f.down * 0.5).z;
        if (centreDepth > bestDepth) {
          bestDepth = centreDepth;
          best = (f.u + (s * f.tw).floor(), f.v + (t * f.th).floor());
        }
      }
    }
    return best;
  }

  void _paintAt(Offset p) {
    final hit = _hit(p);
    if (hit != null) widget.onPaint(hit.$1, hit.$2);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return Listener(
          onPointerDown: (e) {
            _orbiting = e.buttons == 2;
            if (!_orbiting) _paintAt(e.localPosition);
          },
          onPointerMove: (e) {
            if (_orbiting || e.buttons == 2) {
              widget.onOrbit(e.delta.dx, e.delta.dy);
            } else {
              _paintAt(e.localPosition);
            }
          },
          onPointerUp: (_) {
            _orbiting = false;
            widget.onStrokeEnd();
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: CustomPaint(
              size: Size.infinite,
              painter: _ModelPainter(
                skin: widget.skin,
                revision: widget.revision,
                slim: widget.slim,
                overlay: widget.overlay,
                yaw: widget.yaw,
                pitch: widget.pitch,
                background: widget.background,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModelPainter extends CustomPainter {
  _ModelPainter({
    required this.skin,
    required this.revision,
    required this.slim,
    required this.overlay,
    required this.yaw,
    required this.pitch,
    required this.background,
  });

  final McSkin skin;
  final int revision;
  final bool slim;
  final bool overlay;
  final double yaw;
  final double pitch;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(background, Colors.white, 0.08)!, background],
        ).createShader(Offset.zero & size),
    );
    final cam = McSkinCamera(yaw, pitch);
    final scale = size.height / 40;
    final centre = Offset(size.width / 2, size.height / 2);
    Offset project(Vec3 v) {
      final r = cam.apply(v - const Vec3(0, 16, 0));
      return centre + Offset(r.x * scale, -r.y * scale);
    }

    final faces = <(double, McSkinFace)>[];
    for (final box in mcSkinBoxes(slim: slim)) {
      if (box.overlay && !overlay) continue;
      for (final f in mcSkinFaces(box)) {
        if (cam.apply(f.normal).z <= 0) continue;
        final depth = cam.apply(f.origin + f.across * 0.5 + f.down * 0.5).z +
            (box.overlay ? 0.01 : 0);
        faces.add((depth, f));
      }
    }
    faces.sort((a, b) => a.$1.compareTo(b.$1));

    final positions = <Offset>[];
    final colors = <Color>[];
    for (final (_, f) in faces) {
      final light = 0.62 + 0.38 * math.max(0, cam.apply(f.normal).z);
      final o = project(f.origin);
      final a = (project(f.origin + f.across) - o) / f.tw.toDouble();
      final b = (project(f.origin + f.down) - o) / f.th.toDouble();
      for (var j = 0; j < f.th; j++) {
        for (var i = 0; i < f.tw; i++) {
          final argb = skin.at(f.u + i, f.v + j);
          final alpha = argb >> 24 & 0xFF;
          if (f.box.overlay && alpha < 128) continue;
          final r = ((argb >> 16 & 0xFF) * light).round();
          final g = ((argb >> 8 & 0xFF) * light).round();
          final bl = ((argb & 0xFF) * light).round();
          final c = Color.fromARGB(255, r, g, bl);
          final p0 = o + a * i.toDouble() + b * j.toDouble();
          final p1 = p0 + a;
          final p2 = p0 + a + b;
          final p3 = p0 + b;
          positions..add(p0)..add(p1)..add(p2)..add(p0)..add(p2)..add(p3);
          for (var k = 0; k < 6; k++) {
            colors.add(c);
          }
        }
      }
    }
    if (positions.isEmpty) return;
    canvas.drawVertices(
      ui.Vertices(VertexMode.triangles, positions, colors: colors),
      // Modulating against opaque white passes the vertex colours through.
      BlendMode.modulate,
      Paint()
        ..color = Colors.white
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_ModelPainter old) =>
      old.revision != revision ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.slim != slim ||
      old.overlay != overlay ||
      !identical(old.skin, skin);
}

/// The flat 64 × 64 texture, with each part's region outlined.
class _FlatView extends StatelessWidget {
  const _FlatView({
    required this.skin,
    required this.revision,
    required this.slim,
    required this.onPaint,
    required this.onStrokeEnd,
  });

  final McSkin skin;
  final int revision;
  final bool slim;
  final void Function(int x, int y) onPaint;
  final VoidCallback onStrokeEnd;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = constraints.maxWidth / 64;
        void at(Offset p) => onPaint((p.dx / cell).floor(), (p.dy / cell).floor());
        return Listener(
          onPointerDown: (e) => at(e.localPosition),
          onPointerMove: (e) => at(e.localPosition),
          onPointerUp: (_) => onStrokeEnd(),
          child: CustomPaint(
            size: Size.infinite,
            painter: _FlatPainter(
              skin: skin,
              revision: revision,
              slim: slim,
              checker: luma.surfaceHover,
              line: luma.accent,
            ),
          ),
        );
      },
    );
  }
}

class _FlatPainter extends CustomPainter {
  _FlatPainter({
    required this.skin,
    required this.revision,
    required this.slim,
    required this.checker,
    required this.line,
  });

  final McSkin skin;
  final int revision;
  final bool slim;
  final Color checker;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 64;
    final dark = Paint()..color = checker;
    final light = Paint()..color = Color.lerp(checker, Colors.white, 0.35)!;
    final px = Paint();
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        final r = Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5);
        final c = skin.at(x, y);
        if ((c >> 24) == 0) {
          canvas.drawRect(r, (x + y).isEven ? dark : light);
        } else {
          px.color = Color(c);
          canvas.drawRect(r, px);
        }
      }
    }
    final outline = Paint()
      ..color = line.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final b in mcSkinBoxes(slim: slim)) {
      canvas.drawRect(
        Rect.fromLTWH((b.u + b.d) * cell, b.v * cell, b.w * 2 * cell, b.d * cell),
        outline,
      );
      canvas.drawRect(
        Rect.fromLTWH(b.u * cell, (b.v + b.d) * cell, 2 * (b.w + b.d) * cell, b.h * cell),
        outline,
      );
    }
  }

  @override
  bool shouldRepaint(_FlatPainter old) =>
      old.revision != revision || old.slim != slim || !identical(old.skin, skin);
}
