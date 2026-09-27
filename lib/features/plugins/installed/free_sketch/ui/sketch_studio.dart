import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../theme/luma_theme.dart';
import '../engine/adjustments.dart';
import '../engine/symmetry.dart';
import '../io/sketch_export.dart';
import '../model/brush.dart';
import '../model/sketch_tool.dart';
import 'brush_panel.dart';
import 'color_panel.dart';
import 'layers_panel.dart';
import 'sketch_canvas.dart';
import 'studio_controller.dart';
import 'studio_widgets.dart';
import 'tool_options.dart';

enum _Panel { none, brushes, color, settings }

/// The painting screen: tool rail on the left, canvas in the middle, layers
/// on the right, with the brush and colour panels floating over the canvas
/// the way tablet painting apps lay them out.
class SketchStudio extends StatefulWidget {
  const SketchStudio({super.key, required this.controller, required this.onClose});

  final StudioController controller;
  final Future<void> Function() onClose;

  @override
  State<SketchStudio> createState() => _SketchStudioState();
}

class _SketchStudioState extends State<SketchStudio> {
  final _focus = FocusNode(debugLabel: 'free sketch studio');
  _Panel _panel = _Panel.none;
  bool? _layersExpanded;
  bool _hideUi = false;
  bool _exporting = false;

  StudioController get c => widget.controller;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    c.onMessage = _toast;
    // Autosave waits a few seconds after the last change; a phone that is
    // backgrounded may be killed before then, so save the moment it goes.
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
          unawaited(c.save());
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    c.onMessage = null;
    _focus.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }

  void _togglePanel(_Panel panel) => setState(() => _panel = _panel == panel ? _Panel.none : panel);

  void _selectTool(SketchTool tool) {
    if (tool == c.tool && tool.usesBrush) {
      _togglePanel(_Panel.brushes);
      return;
    }
    c.setTool(tool);
    if (_panel == _Panel.brushes && !tool.usesBrush) setState(() => _panel = _Panel.none);
  }

  // --------------------------------------------------------------- keyboard

  bool get _typing {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary == _focus) return false;
    return primary.context?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_typing) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // Space, Alt and R are held as modifiers by the canvas; swallow them so
    // a focused button is not "pressed" by the space bar.
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.altLeft || key == LogicalKeyboardKey.altRight) {
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final ctrl = keyboard.isControlPressed || keyboard.isMetaPressed;
    final shift = keyboard.isShiftPressed;
    final center = Offset(c.view.viewport.width / 2, c.view.viewport.height / 2);

    if (ctrl) {
      if (key == LogicalKeyboardKey.keyZ) {
        shift ? c.redo() : c.undo();
      } else if (key == LogicalKeyboardKey.keyY) {
        c.redo();
      } else if (key == LogicalKeyboardKey.keyS) {
        unawaited(c.save());
      } else if (key == LogicalKeyboardKey.keyA) {
        c.selectAll();
      } else if (key == LogicalKeyboardKey.keyD) {
        c.deselect();
      } else if (key == LogicalKeyboardKey.keyI && shift) {
        c.invertSelection();
      } else if (key == LogicalKeyboardKey.keyJ) {
        c.duplicateLayer();
      } else if (key == LogicalKeyboardKey.keyE) {
        c.mergeDown();
      } else if (key == LogicalKeyboardKey.keyC) {
        c.copy();
      } else if (key == LogicalKeyboardKey.keyX) {
        c.cut();
      } else if (key == LogicalKeyboardKey.keyV) {
        c.paste();
      } else if (key == LogicalKeyboardKey.keyN && shift) {
        c.addLayer();
      } else if (key == LogicalKeyboardKey.keyT) {
        c.setTool(SketchTool.transform);
      } else if (key == LogicalKeyboardKey.digit0) {
        c.view.fit();
      } else if (key == LogicalKeyboardKey.digit1) {
        c.view.actualPixels();
      } else if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add || key == LogicalKeyboardKey.numpadAdd) {
        c.view.zoomBy(1.25, center);
      } else if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
        c.view.zoomBy(0.8, center);
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.bracketLeft) {
      c.nudgeSize(-1);
    } else if (key == LogicalKeyboardKey.bracketRight) {
      c.nudgeSize(1);
    } else if (key == LogicalKeyboardKey.keyX) {
      c.swapColors();
    } else if (key == LogicalKeyboardKey.keyH) {
      c.view.toggleMirror();
    } else if (key == LogicalKeyboardKey.tab) {
      setState(() => _hideUi = !_hideUi);
    } else if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      c.clearLayer();
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (c.transform != null) c.finishTransform();
      if (c.adjustment != null) c.applyAdjustment();
    } else if (key == LogicalKeyboardKey.escape) {
      if (c.transform != null) {
        c.cancelTransform();
      } else if (c.adjustment != null) {
        c.cancelAdjustment();
      } else if (_panel != _Panel.none) {
        setState(() => _panel = _Panel.none);
      } else {
        c.deselect();
      }
    } else if (key == LogicalKeyboardKey.keyR) {
      // Held for rotate-drag in the canvas.
    } else {
      final label = key.keyLabel.toUpperCase();
      final tool = SketchTool.values.where((t) => t.shortcut == label).firstOrNull;
      if (tool == null) return KeyEventResult.ignored;
      _selectTool(tool);
    }
    return KeyEventResult.handled;
  }

  // ----------------------------------------------------------------- actions

  Future<void> _rename() async {
    final text = TextEditingController(text: c.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename artwork'),
        content: TextField(
          controller: text,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, text.text), child: const Text('Rename')),
        ],
      ),
    ).whenComplete(text.dispose);
    if (title != null) await c.rename(title);
    _focus.requestFocus();
  }

  Future<void> _export(SketchExportFormat format) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final result = await SketchExporter.saveAs(
        state: c.state,
        width: c.width,
        height: c.height,
        title: c.title,
        format: format,
      );
      if (result != null) _toast(result);
    } on Object catch (error) {
      _toast('Export failed: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
      _focus.requestFocus();
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    final name = file.name.contains('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;
    await c.importImage(bytes, name);
    _focus.requestFocus();
  }

  void _adjust(AdjustmentKind kind) {
    if (c.beginAdjustment(kind) && kind.params.isEmpty) c.applyAdjustment();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final layersExpanded = _layersExpanded ?? !narrow;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ColoredBox(
        color: luma.background,
        child: Column(
          children: [
            if (!_hideUi) _topBar(luma, narrow),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_hideUi) _ToolRail(controller: c, panel: _panel, onTool: _selectTool, onColor: () => _togglePanel(_Panel.color)),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Listener(
                            onPointerDown: (_) {
                              if (!_focus.hasFocus) _focus.requestFocus();
                              if (_panel != _Panel.none && narrow) setState(() => _panel = _Panel.none);
                            },
                            child: SketchCanvas(controller: c),
                          ),
                        ),
                        if (!_hideUi)
                          Positioned(
                            top: 10,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 820),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: ToolOptionsBar(
                                    controller: c,
                                    onOpenBrushes: () => _togglePanel(_Panel.brushes),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (!_hideUi && _panel == _Panel.brushes)
                          Positioned(
                            left: 8,
                            top: 8,
                            bottom: 8,
                            child: BrushPanel(controller: c, onClose: () => setState(() => _panel = _Panel.none)),
                          ),
                        if (!_hideUi && _panel == _Panel.color)
                          Positioned(
                            left: 8,
                            top: 8,
                            bottom: 8,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: SingleChildScrollView(
                                child: ListenableBuilder(
                                  listenable: c,
                                  builder: (context, _) => ColorPanel(
                                    controller: c,
                                    onClose: () => setState(() => _panel = _Panel.none),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (!_hideUi && _panel == _Panel.settings)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: _SettingsPanel(controller: c, onClose: () => setState(() => _panel = _Panel.none)),
                          ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: ListenableBuilder(
                            listenable: c,
                            builder: (context, _) {
                              final kind = c.adjustment;
                              if (kind == null || kind.params.isEmpty) return const SizedBox.shrink();
                              return _AdjustmentPanel(controller: c, kind: kind);
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: ListenableBuilder(
                            listenable: c,
                            builder: (context, _) => (c.busy || _exporting)
                                ? Center(
                                    child: Material(
                                      color: luma.surface,
                                      shape: const StadiumBorder(),
                                      elevation: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                            const SizedBox(width: 10),
                                            Text(_exporting ? 'Exporting…' : 'Filling…', style: TextStyle(color: luma.textPrimary)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                        if (_hideUi)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: StudioIconButton(
                              icon: Icons.fullscreen_exit_rounded,
                              tooltip: 'Show interface (Tab)',
                              onTap: () => setState(() => _hideUi = false),
                            ),
                          ),
                        if (!_hideUi && narrow && layersExpanded)
                          Positioned(
                            top: 0,
                            right: 0,
                            bottom: 0,
                            child: LayersPanel(
                              controller: c,
                              expanded: true,
                              onToggleExpanded: () => setState(() => _layersExpanded = false),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_hideUi && !narrow)
                    LayersPanel(
                      controller: c,
                      expanded: layersExpanded,
                      onToggleExpanded: () => setState(() => _layersExpanded = !layersExpanded),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(LumaPalette luma, bool narrow) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([c, c.view]),
        builder: (context, _) {
          final document = c.document;
          return Row(
            children: [
              StudioIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back to gallery',
                onTap: () => unawaited(widget.onClose()),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _rename,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        Text(
                          '${c.width} × ${c.height} · ${c.saving ? 'Saving…' : c.dirty ? 'Edited' : 'Saved'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: luma.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!narrow) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Fit to screen (Ctrl+0)',
                  child: ActionChip(
                    label: Text('${(c.view.zoom * 100).round()}%'),
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(fontSize: 12, color: luma.textSecondary),
                    onPressed: c.view.fit,
                  ),
                ),
              ],
              if (c.view.rotation != 0)
                StudioIconButton(
                  icon: Icons.screen_rotation_alt_rounded,
                  tooltip: 'Reset rotation (${(c.view.rotation * 180 / math.pi).round()}°)',
                  onTap: c.view.resetRotation,
                ),
              if (c.view.mirrored)
                StudioIconButton(
                  icon: Icons.flip_rounded,
                  tooltip: 'View is mirrored — tap to unflip (H)',
                  selected: true,
                  onTap: c.view.toggleMirror,
                ),
              const Spacer(),
              StudioIconButton(
                icon: Icons.undo_rounded,
                tooltip: document.undoLabel == null ? 'Undo (Ctrl+Z)' : 'Undo ${document.undoLabel} (Ctrl+Z)',
                onTap: document.canUndo || c.transform != null ? c.undo : null,
              ),
              StudioIconButton(
                icon: Icons.redo_rounded,
                tooltip: document.redoLabel == null ? 'Redo (Ctrl+Shift+Z)' : 'Redo ${document.redoLabel}',
                onTap: document.canRedo ? c.redo : null,
              ),
              if (!narrow) ...[
                Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 4), color: luma.border),
                _symmetryMenu(),
                _viewMenu(),
                _adjustMenu(),
                _canvasMenu(),
                _exportMenu(),
                StudioIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Pen & input settings',
                  selected: _panel == _Panel.settings,
                  onTap: () => _togglePanel(_Panel.settings),
                ),
              ] else ...[
                StudioIconButton(
                  icon: Icons.layers_rounded,
                  tooltip: 'Layers',
                  selected: _layersExpanded ?? false,
                  onTap: () => setState(() => _layersExpanded = !(_layersExpanded ?? false)),
                ),
                _phoneMenu(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _menu<T>({
    required IconData icon,
    required String tooltip,
    required List<PopupMenuEntry<T>> Function() items,
    required ValueChanged<T> onSelected,
    bool selected = false,
  }) {
    final luma = context.luma;
    return PopupMenuButton<T>(
      tooltip: tooltip,
      onSelected: (value) {
        onSelected(value);
        _focus.requestFocus();
      },
      onCanceled: _focus.requestFocus,
      itemBuilder: (_) => items(),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: 20, color: selected ? luma.accent : luma.textSecondary),
      ),
    );
  }

  Widget _symmetryMenu() {
    final s = c.symmetry;
    return _menu<String>(
      icon: Icons.flip_rounded,
      tooltip: 'Symmetry',
      selected: s.enabled,
      onSelected: (value) {
        if (value.startsWith('mode:')) {
          final mode = SymmetryMode.values.byName(value.substring(5));
          c.symmetry = s.copyWith(mode: mode);
        } else if (value.startsWith('segments:')) {
          c.symmetry = s.copyWith(mode: SymmetryMode.radial, segments: int.parse(value.substring(9)));
        } else if (value == 'mirror') {
          c.symmetry = s.copyWith(mirrorRadial: !s.mirrorRadial);
        } else if (value == 'center') {
          c.symmetry = s.copyWith(resetCenter: true);
        }
      },
      items: () => [
        for (final mode in SymmetryMode.values)
          CheckedPopupMenuItem(value: 'mode:${mode.name}', checked: s.mode == mode, child: Text(mode.label)),
        const PopupMenuDivider(),
        for (final n in const [3, 4, 6, 8, 12, 16])
          CheckedPopupMenuItem(
            value: 'segments:$n',
            checked: s.mode == SymmetryMode.radial && s.segments == n,
            child: Text('Radial × $n'),
          ),
        CheckedPopupMenuItem(value: 'mirror', checked: s.mirrorRadial, child: const Text('Mirror radial copies')),
      ],
    );
  }

  /// Everything the desktop top bar spreads over six buttons, in one menu —
  /// a phone has room for about five icons next to the title.
  Widget _phoneMenu() {
    final s = c.symmetry;
    return _menu<String>(
      icon: Icons.more_vert_rounded,
      tooltip: 'More',
      onSelected: (value) {
        final (group, name) = switch (value.split(':')) {
          [final g, final n] => (g, n),
          _ => (value, ''),
        };
        switch (group) {
          case 'view':
            switch (name) {
              case 'fit':
                c.view.fit();
              case 'mirror':
                c.view.toggleMirror();
              case 'rotation':
                c.view.resetRotation();
            }
          case 'sym':
            c.symmetry = s.copyWith(mode: SymmetryMode.values.byName(name));
          case 'adj':
            _adjust(AdjustmentKind.values.byName(name));
          case 'canvas':
            switch (name) {
              case 'import':
                unawaited(_import());
              case 'flipH':
                c.flipCanvas(horizontal: true);
              case 'flipV':
                c.flipCanvas(horizontal: false);
              case 'background':
                c.toggleBackground();
            }
          case 'export':
            unawaited(_export(SketchExportFormat.values.byName(name)));
          case 'settings':
            _togglePanel(_Panel.settings);
        }
      },
      items: () => [
        const PopupMenuItem(value: 'view:fit', child: Text('Fit to screen')),
        CheckedPopupMenuItem(value: 'view:mirror', checked: c.view.mirrored, child: const Text('Mirror view')),
        const PopupMenuItem(value: 'view:rotation', child: Text('Reset rotation')),
        const PopupMenuDivider(),
        for (final mode in SymmetryMode.values)
          CheckedPopupMenuItem(
            value: 'sym:${mode.name}',
            checked: s.mode == mode,
            child: Text('Symmetry: ${mode.label}'),
          ),
        const PopupMenuDivider(),
        for (final kind in AdjustmentKind.values) PopupMenuItem(value: 'adj:${kind.name}', child: Text(kind.label)),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'canvas:import', child: Text('Import image as layer…')),
        const PopupMenuItem(value: 'canvas:flipH', child: Text('Flip canvas horizontally')),
        const PopupMenuItem(value: 'canvas:flipV', child: Text('Flip canvas vertically')),
        CheckedPopupMenuItem(
          value: 'canvas:background',
          checked: !c.state.showBackground,
          child: const Text('Transparent background'),
        ),
        const PopupMenuDivider(),
        for (final format in SketchExportFormat.values)
          PopupMenuItem(value: 'export:${format.name}', child: Text('Export ${format.label} (.${format.extension})')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'settings', child: Text('Pen & input settings')),
      ],
    );
  }

  Widget _viewMenu() => _menu<String>(
        icon: Icons.visibility_outlined,
        tooltip: 'View',
        onSelected: (value) {
          switch (value) {
            case 'fit':
              c.view.fit();
            case 'actual':
              c.view.actualPixels();
            case 'mirror':
              c.view.toggleMirror();
            case 'rotation':
              c.view.resetRotation();
            case 'hide':
              setState(() => _hideUi = true);
          }
        },
        items: () => [
          const PopupMenuItem(value: 'fit', child: Text('Fit to screen   Ctrl+0')),
          const PopupMenuItem(value: 'actual', child: Text('Actual pixels   Ctrl+1')),
          CheckedPopupMenuItem(value: 'mirror', checked: c.view.mirrored, child: const Text('Mirror view   H')),
          const PopupMenuItem(value: 'rotation', child: Text('Reset rotation')),
          const PopupMenuItem(value: 'hide', child: Text('Hide interface   Tab')),
        ],
      );

  Widget _adjustMenu() => _menu<AdjustmentKind>(
        icon: Icons.auto_fix_high_rounded,
        tooltip: 'Adjustments',
        onSelected: _adjust,
        items: () => [
          for (final kind in AdjustmentKind.values) PopupMenuItem(value: kind, child: Text(kind.label)),
        ],
      );

  Widget _canvasMenu() => _menu<String>(
        icon: Icons.crop_rounded,
        tooltip: 'Canvas',
        onSelected: (value) {
          switch (value) {
            case 'import':
              unawaited(_import());
            case 'flipH':
              c.flipCanvas(horizontal: true);
            case 'flipV':
              c.flipCanvas(horizontal: false);
            case 'background':
              c.toggleBackground();
          }
        },
        items: () => [
          const PopupMenuItem(value: 'import', child: Text('Import image as layer…')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'flipH', child: Text('Flip canvas horizontally')),
          const PopupMenuItem(value: 'flipV', child: Text('Flip canvas vertically')),
          CheckedPopupMenuItem(
            value: 'background',
            checked: !c.state.showBackground,
            child: const Text('Transparent background'),
          ),
        ],
      );

  Widget _exportMenu() => _menu<SketchExportFormat>(
        icon: Icons.ios_share_rounded,
        tooltip: 'Export',
        onSelected: (format) => unawaited(_export(format)),
        items: () => [
          for (final format in SketchExportFormat.values)
            PopupMenuItem(
              value: format,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${format.label} (.${format.extension})'),
                subtitle: Text(format.note),
              ),
            ),
        ],
      );
}

class _ToolRail extends StatelessWidget {
  const _ToolRail({required this.controller, required this.panel, required this.onTool, required this.onColor});

  final StudioController controller;
  final _Panel panel;
  final ValueChanged<SketchTool> onTool;
  final VoidCallback onColor;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(right: BorderSide(color: luma.border)),
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          final brush = c.brush;
          return LayoutBuilder(
            builder: (context, constraints) {
              final roomy = constraints.maxHeight > 640;
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (final tool in SketchTool.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: StudioIconButton(
                          icon: tool.icon,
                          tooltip: tool.usesBrush && tool == c.tool ? '${tool.tooltip} — tap again for brushes' : tool.tooltip,
                          selected: c.tool == tool,
                          size: 42,
                          onTap: () => onTool(tool),
                        ),
                      ),
                    Divider(color: luma.border, height: 14, indent: 12, endIndent: 12),
                    Tooltip(
                      message: 'Colour',
                      child: GestureDetector(
                        onTap: onColor,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Stack(
                            children: [
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: GestureDetector(
                                  onTap: c.swapColors,
                                  child: ColorDot(color: c.secondary, size: 20),
                                ),
                              ),
                              Positioned(
                                left: 2,
                                top: 2,
                                child: ColorDot(color: c.color, size: 32, selected: panel == _Panel.color),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (c.tool.usesBrush) ...[
                      const SizedBox(height: 12),
                      VerticalSlider(
                        label: 'Brush size',
                        value: brush.size,
                        min: 1,
                        max: brush.maxSize,
                        curve: 2,
                        height: roomy ? 150 : 110,
                        format: (v) => BrushParam.size.format(v),
                        onChanged: (v) => c.setBrushParam(BrushParam.size, v),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        brush.size < 10 ? brush.size.toStringAsFixed(1) : '${brush.size.round()}',
                        style: TextStyle(color: luma.textMuted, fontSize: 10.5),
                      ),
                      const SizedBox(height: 12),
                      VerticalSlider(
                        label: 'Opacity',
                        value: brush.opacity,
                        min: 0.01,
                        max: 1,
                        height: roomy ? 150 : 110,
                        format: (v) => '${(v * 100).round()}%',
                        onChanged: (v) => c.setBrushParam(BrushParam.opacity, v),
                      ),
                      const SizedBox(height: 4),
                      Text('${(brush.opacity * 100).round()}%', style: TextStyle(color: luma.textMuted, fontSize: 10.5)),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdjustmentPanel extends StatelessWidget {
  const _AdjustmentPanel({required this.controller, required this.kind});

  final StudioController controller;
  final AdjustmentKind kind;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return StudioPanel(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(title: kind.label),
          for (final p in kind.params)
            LabeledSlider(
              label: p.label,
              value: c.adjustValues[p.key] ?? p.initial,
              min: p.min,
              max: p.max,
              display: '${(c.adjustValues[p.key] ?? p.initial).round()}${p.unit}',
              onChanged: (v) => c.setAdjustValue(p.key, v),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  for (final p in kind.params) {
                    c.setAdjustValue(p.key, p.initial);
                  }
                },
                child: const Text('Reset'),
              ),
              const Spacer(),
              TextButton(onPressed: c.cancelAdjustment, child: const Text('Cancel')),
              const SizedBox(width: 6),
              FilledButton(onPressed: c.applyAdjustment, child: const Text('Apply')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.controller, required this.onClose});

  final StudioController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return StudioPanel(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHeader(title: 'Pen & input', onClose: onClose),
              const SizedBox(height: 6),
              Text('Pressure curve', style: TextStyle(color: luma.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SizedBox(
                height: 90,
                child: CustomPaint(
                  painter: _CurvePainter(gamma: c.pressureGamma, line: luma.accent, grid: luma.border),
                ),
              ),
              LabeledSlider(
                label: c.pressureGamma < 0.95
                    ? 'Soft — light touch goes further'
                    : c.pressureGamma > 1.05
                        ? 'Firm — press harder for full strength'
                        : 'Linear',
                value: -math.log(c.pressureGamma) / math.ln2,
                min: -2,
                max: 2,
                display: c.pressureGamma.toStringAsFixed(2),
                onChanged: (v) => c.pressureGamma = math.pow(2, -v).toDouble(),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: c.stylusOnly,
                onChanged: (v) => c.stylusOnly = v,
                title: const Text('Draw with pen only'),
                subtitle: const Text('Once a stylus is used, fingers pan and zoom instead of painting — palm rejection.'),
              ),
              const SizedBox(height: 6),
              Text(
                'Shortcuts: B brush · E eraser · S smudge · G fill · D gradient · U shapes · L select · V transform · '
                'I eyedropper · [ ] size · X swap colours · H mirror view · Space-drag pan · R-drag rotate · '
                'Alt-click pick colour · Shift-click straight line · two-finger tap undo · three-finger tap redo.',
                style: TextStyle(color: luma.textMuted, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.gamma, required this.line, required this.grid});

  final double gamma;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..color = grid;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)), frame);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), frame);
    final path = Path();
    for (var i = 0; i <= 40; i++) {
      final t = i / 40;
      final y = math.pow(t, gamma).toDouble();
      final p = Offset(t * size.width, (1 - y) * size.height);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = line);
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.gamma != gamma || old.line != line;
}
