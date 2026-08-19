import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';

// ---------------------------------------------------------------------------
// Resize handles
// ---------------------------------------------------------------------------

class _HandleSpec {
  const _HandleSpec(
    this.alignment, {
    this.affectsLeft = false,
    this.affectsTop = false,
    this.affectsRight = false,
    this.affectsBottom = false,
    required this.cursor,
  });
  final Alignment alignment;
  final bool affectsLeft;
  final bool affectsTop;
  final bool affectsRight;
  final bool affectsBottom;
  final MouseCursor cursor;
}

const List<_HandleSpec> _kHandles = [
  _HandleSpec(Alignment.topLeft,
      affectsLeft: true,
      affectsTop: true,
      cursor: SystemMouseCursors.resizeUpLeftDownRight),
  _HandleSpec(Alignment.topCenter,
      affectsTop: true, cursor: SystemMouseCursors.resizeUpDown),
  _HandleSpec(Alignment.topRight,
      affectsRight: true,
      affectsTop: true,
      cursor: SystemMouseCursors.resizeUpRightDownLeft),
  _HandleSpec(Alignment.centerRight,
      affectsRight: true, cursor: SystemMouseCursors.resizeLeftRight),
  _HandleSpec(Alignment.bottomRight,
      affectsRight: true,
      affectsBottom: true,
      cursor: SystemMouseCursors.resizeUpLeftDownRight),
  _HandleSpec(Alignment.bottomCenter,
      affectsBottom: true, cursor: SystemMouseCursors.resizeUpDown),
  _HandleSpec(Alignment.bottomLeft,
      affectsLeft: true,
      affectsBottom: true,
      cursor: SystemMouseCursors.resizeUpRightDownLeft),
  _HandleSpec(Alignment.centerLeft,
      affectsLeft: true, cursor: SystemMouseCursors.resizeLeftRight),
];

// ---------------------------------------------------------------------------
// Main editor
// ---------------------------------------------------------------------------

/// A freeform editor for building a custom collage layout: add, drag, resize,
/// split and delete rectangular frames on a normalized 0..1 canvas, then save
/// the result as a named [CollageTemplate]-compatible slot list.
class CollageShapeEditor extends StatefulWidget {
  const CollageShapeEditor({
    super.key,
    required this.initialSlots,
    required this.initialName,
    required this.onCancel,
    required this.onSave,
  });

  final List<Rect> initialSlots;
  final String initialName;
  final VoidCallback onCancel;
  final void Function(String name, List<Rect> slots) onSave;

  @override
  State<CollageShapeEditor> createState() => _CollageShapeEditorState();
}

class _CollageShapeEditorState extends State<CollageShapeEditor> {
  static const double _minSize = 0.08;
  static const double _snapStep = 0.05;

  late List<Rect> _slots;
  int? _selected;
  bool _snap = true;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _slots = List.of(widget.initialSlots);
    _selected = _slots.isEmpty ? null : 0;
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  double _snapVal(double v) =>
      _snap ? ((v / _snapStep).round() * _snapStep) : v;

  void _addRect() {
    setState(() {
      final n = _slots.length;
      final offset = (n % 5) * 0.04;
      final l = (0.15 + offset).clamp(0.0, 0.55);
      final t = (0.15 + offset).clamp(0.0, 0.55);
      _slots.add(Rect.fromLTWH(l, t, 0.35, 0.35));
      _selected = _slots.length - 1;
    });
  }

  void _deleteSelected() {
    final i = _selected;
    if (i == null) return;
    setState(() {
      _slots.removeAt(i);
      _selected = _slots.isEmpty ? null : i.clamp(0, _slots.length - 1);
    });
  }

  void _splitSelected(Axis axis) {
    final i = _selected;
    if (i == null) return;
    final r = _slots[i];
    setState(() {
      if (axis == Axis.horizontal) {
        final midX = (r.left + r.right) / 2;
        _slots
          ..removeAt(i)
          ..insertAll(i, [
            Rect.fromLTRB(r.left, r.top, midX, r.bottom),
            Rect.fromLTRB(midX, r.top, r.right, r.bottom),
          ]);
      } else {
        final midY = (r.top + r.bottom) / 2;
        _slots
          ..removeAt(i)
          ..insertAll(i, [
            Rect.fromLTRB(r.left, r.top, r.right, midY),
            Rect.fromLTRB(r.left, midY, r.right, r.bottom),
          ]);
      }
      _selected = i + 1;
    });
  }

  void _clearAll() => setState(() {
        _slots.clear();
        _selected = null;
      });

  void _moveSelected(Offset deltaNorm) {
    final i = _selected;
    if (i == null) return;
    setState(() {
      final r = _slots[i];
      final w = r.width, h = r.height;
      final dx = deltaNorm.dx.clamp(-r.left, 1 - r.right);
      final dy = deltaNorm.dy.clamp(-r.top, 1 - r.bottom);
      var left = r.left + dx;
      var top = r.top + dy;
      if (_snap) {
        left = _snapVal(left).clamp(0.0, 1 - w);
        top = _snapVal(top).clamp(0.0, 1 - h);
      }
      _slots[i] = Rect.fromLTWH(left, top, w, h);
    });
  }

  void _resizeSelected(_HandleSpec handle, Offset deltaNorm) {
    final i = _selected;
    if (i == null) return;
    setState(() {
      final r = _slots[i];
      var left = r.left, top = r.top, right = r.right, bottom = r.bottom;
      if (handle.affectsLeft) {
        left = (left + deltaNorm.dx).clamp(0.0, right - _minSize);
        if (_snap) left = _snapVal(left).clamp(0.0, right - _minSize);
      }
      if (handle.affectsTop) {
        top = (top + deltaNorm.dy).clamp(0.0, bottom - _minSize);
        if (_snap) top = _snapVal(top).clamp(0.0, bottom - _minSize);
      }
      if (handle.affectsRight) {
        right = (right + deltaNorm.dx).clamp(left + _minSize, 1.0);
        if (_snap) right = _snapVal(right).clamp(left + _minSize, 1.0);
      }
      if (handle.affectsBottom) {
        bottom = (bottom + deltaNorm.dy).clamp(top + _minSize, 1.0);
        if (_snap) bottom = _snapVal(bottom).clamp(top + _minSize, 1.0);
      }
      _slots[i] = Rect.fromLTRB(left, top, right, bottom);
    });
  }

  bool get _canSave => _slots.isNotEmpty && _nameController.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    widget.onSave(_nameController.text.trim(), List.of(_slots));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ToolScaffold(
      icon: Icons.crop_rounded,
      title: 'Design your layout',
      subtitle: 'Add, drag and resize frames to build your own shape',
      onBack: widget.onCancel,
      children: [
        _EditorToolbar(
          canModify: _selected != null,
          canClear: _slots.isNotEmpty,
          snap: _snap,
          onAdd: _addRect,
          onSplitH: () => _splitSelected(Axis.horizontal),
          onSplitV: () => _splitSelected(Axis.vertical),
          onDelete: _deleteSelected,
          onClear: _clearAll,
          onSnapChanged: (v) => setState(() => _snap = v),
        ),
        const SizedBox(height: 16),
        ConverterCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.crop_free_rounded, color: luma.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Layout',
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_slots.length} frame${_slots.length == 1 ? '' : 's'}',
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: luma.surfaceHover,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _slots.isEmpty
                        ? _EmptyEditorHint(onAdd: _addRect)
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.maxWidth;
                              final h = constraints.maxHeight;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  for (int i = 0; i < _slots.length; i++)
                                    _buildEditableSlot(i, w, h, luma),
                                ],
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ConverterCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Name',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: luma.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. My layout',
                  hintStyle: TextStyle(color: luma.textMuted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: luma.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: luma.accent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ConverterPrimaryButton(
                label: 'Save shape',
                icon: Icons.check_rounded,
                loading: false,
                onTap: _canSave ? _save : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ConverterPrimaryButton(
                label: 'Cancel',
                icon: Icons.close_rounded,
                loading: false,
                onTap: widget.onCancel,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditableSlot(
      int i, double canvasW, double canvasH, LumaPalette luma) {
    final r = _slots[i];
    final left = r.left * canvasW;
    final top = r.top * canvasH;
    final width = r.width * canvasW;
    final height = r.height * canvasH;
    final selected = _selected == i;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onPanStart: (_) => setState(() => _selected = i),
            onPanUpdate: (details) => _moveSelected(
              Offset(details.delta.dx / canvasW, details.delta.dy / canvasH),
            ),
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: selected
                      ? luma.accentSubtle
                      : luma.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? luma.accent : luma.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: selected ? luma.accent : luma.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (selected)
            for (final handle in _kHandles)
              Align(
                alignment: handle.alignment,
                child: _ResizeHandleDot(
                  cursor: handle.cursor,
                  color: luma.accent,
                  onPanUpdate: (details) => _resizeSelected(
                    handle,
                    Offset(
                      details.delta.dx / canvasW,
                      details.delta.dy / canvasH,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toolbar
// ---------------------------------------------------------------------------

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.canModify,
    required this.canClear,
    required this.snap,
    required this.onAdd,
    required this.onSplitH,
    required this.onSplitV,
    required this.onDelete,
    required this.onClear,
    required this.onSnapChanged,
  });
  final bool canModify;
  final bool canClear;
  final bool snap;
  final VoidCallback onAdd;
  final VoidCallback onSplitH;
  final VoidCallback onSplitV;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final ValueChanged<bool> onSnapChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ConverterCard(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _ToolbarButton(
            icon: Icons.add_box_rounded,
            label: 'Add frame',
            onTap: onAdd,
          ),
          _ToolbarButton(
            icon: Icons.vertical_split_rounded,
            label: 'Split ↔',
            onTap: canModify ? onSplitH : null,
          ),
          _ToolbarButton(
            icon: Icons.horizontal_split_rounded,
            label: 'Split ↕',
            onTap: canModify ? onSplitV : null,
          ),
          _ToolbarButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            danger: true,
            onTap: canModify ? onDelete : null,
          ),
          _ToolbarButton(
            icon: Icons.layers_clear_rounded,
            label: 'Clear all',
            danger: true,
            onTap: canClear ? onClear : null,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => onSnapChanged(!snap),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    snap
                        ? Icons.grid_on_rounded
                        : Icons.grid_off_rounded,
                    size: 16,
                    color: snap ? luma.accent : luma.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Snap to grid',
                    style: TextStyle(
                      color: snap ? luma.accent : luma.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  const _ToolbarButton({
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
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final enabled = widget.onTap != null;
    final fg = !enabled
        ? luma.textMuted.withValues(alpha: 0.4)
        : (widget.danger ? luma.danger : luma.textPrimary);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: enabled && _hovering ? luma.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resize handle dot
// ---------------------------------------------------------------------------

class _ResizeHandleDot extends StatelessWidget {
  const _ResizeHandleDot({
    required this.cursor,
    required this.color,
    required this.onPanUpdate,
  });
  final MouseCursor cursor;
  final Color color;
  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        onPanUpdate: onPanUpdate,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyEditorHint extends StatelessWidget {
  const _EmptyEditorHint({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.crop_free_rounded, color: luma.textMuted, size: 32),
          const SizedBox(height: 10),
          Text(
            'Tap "Add frame" to start building your shape',
            style: TextStyle(color: luma.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          ConverterTextButton(label: 'Add frame', onTap: onAdd),
        ],
      ),
    );
  }
}
