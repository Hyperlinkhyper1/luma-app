import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../theme/luma_theme.dart';
import 'dashboard_tiles.dart';
import 'home_layout.dart';

class HomeGrid extends StatefulWidget {
  const HomeGrid({
    super.key,
    this.header,
    required this.layout,
    required this.editing,
    required this.onChanged,
    required this.onAdd,
    required this.onNavigate,
    required this.onPlugin,
  });
  final Widget? header;
  final HomeLayout layout;
  final bool editing;
  final ValueChanged<HomeLayout> onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onNavigate;
  final ValueChanged<String> onPlugin;

  @override
  State<HomeGrid> createState() => _HomeGridState();
}

class _HomeGridState extends State<HomeGrid> {
  static const _gap = 16.0;
  static const _row = 50.0;
  HomeTile? _gestureTile;
  HomeLayout? _gestureLayout;
  Offset _delta = Offset.zero;
  String? _active;
  int? _pointer;

  void _start(HomeTile tile) {
    _gestureTile = tile;
    _gestureLayout = widget.layout;
    _delta = Offset.zero;
    setState(() => _active = tile.id);
  }

  void _update(DragUpdateDetails event, double step, {required bool resize}) {
    final tile = _gestureTile;
    if (tile == null) return;
    _delta += event.delta;
    final dx = (_delta.dx / step).round();
    final dy = (_delta.dy / _row).round();
    final changed = resize
        ? tile.copyWith(
            w: (tile.w + dx).clamp(
              math.min(2, widget.layout.columns - tile.x),
              widget.layout.columns - tile.x,
            ),
            h: (tile.h + dy).clamp(2, 40),
          )
        : tile.copyWith(
            x: (tile.x + dx).clamp(0, widget.layout.columns - tile.w),
            y: math.max(0, tile.y + dy),
          );
    widget.onChanged((_gestureLayout ?? widget.layout).place(changed));
  }

  void _end() {
    _gestureTile = null;
    _gestureLayout = null;
    _pointer = null;
    setState(() => _active = null);
  }

  Future<void> _configure(HomeTile tile) async {
    final value = await configureDashboardTile(context, tile);
    if (value != null && mounted) widget.onChanged(widget.layout.place(value));
  }

  Future<void> _position(HomeTile tile) async {
    final result = await showDialog<HomeTile>(
      context: context,
      builder: (_) =>
          _PositionDialog(tile: tile, columns: widget.layout.columns),
    );
    if (result != null && mounted) {
      widget.onChanged(widget.layout.place(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.luma;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          constraints.maxWidth - 40,
          widget.layout.columns > 4 ? 840.0 : 280.0,
        );
        final step = (width + _gap) / widget.layout.columns;
        final rows = widget.layout.tiles.fold<int>(
          0,
          (end, tile) => math.max(end, tile.y + tile.h),
        );
        final height = math.max(
          constraints.maxHeight - 40,
          (rows + (widget.editing ? 4 : 0)) * _row,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width + 40,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.header != null) widget.header!,
                  SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      children: [
                        if (widget.editing)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _GridPainter(step, _row, palette.border),
                            ),
                          ),
                        if (widget.layout.tiles.isEmpty)
                          Positioned.fill(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.dashboard_customize_rounded,
                                    size: 44,
                                    color: palette.accent,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'A space for your everyday',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Add notes, shortcuts, charts and little helpers.',
                                  ),
                                  if (widget.editing)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: FilledButton.icon(
                                        onPressed: widget.onAdd,
                                        icon: const Icon(Icons.add),
                                        label: const Text(
                                          'Add your first tile',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        for (final section in _sections())
                          Positioned(
                            left: 0,
                            right: 0,
                            top: section.$1 * _row + 13,
                            child: Text(
                              section.$2,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.3,
                              ),
                            ),
                          ),
                        for (final tile in widget.layout.tiles)
                          Positioned(
                            key: ValueKey(tile.id),
                            left: tile.x * step,
                            top: tile.y * _row,
                            width: tile.w * step - _gap,
                            height: tile.h * _row - _gap,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color.alphaBlend(
                                      _color(tile).withValues(
                                        alpha: _classic(tile.kind)
                                            ? 0
                                            : tile.kind == 'note' ||
                                                  tile.kind == 'minecraft'
                                            ? .13
                                            : .055,
                                      ),
                                      palette.surface,
                                    ),
                                    palette.surface,
                                  ],
                                ),
                                borderRadius:
                                    context.lumaDecor.cardBorderRadius,
                                border: Border.all(
                                  color: _active == tile.id
                                      ? palette.accent
                                      : _classic(tile.kind)
                                      ? palette.border
                                      : Color.lerp(
                                          palette.border,
                                          _color(tile),
                                          .15,
                                        )!,
                                  width: _active == tile.id ? 2 : 1,
                                ),
                                boxShadow: context.lumaDecor.cardShadow,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (_chrome(tile))
                                          _toolbar(tile, step),
                                        Expanded(
                                          child: Padding(
                                            padding: _chrome(tile)
                                                ? const EdgeInsets.fromLTRB(
                                                    14,
                                                    4,
                                                    14,
                                                    14,
                                                  )
                                                : tile.kind == 'shortcut'
                                                ? EdgeInsets.zero
                                                : const EdgeInsets.all(16),
                                            child: IgnorePointer(
                                              ignoring: widget.editing,
                                              child: DashboardTileContent(
                                                tile: tile,
                                                onNavigate: widget.onNavigate,
                                                onPlugin: widget.onPlugin,
                                                editing: widget.editing,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.editing)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Semantics(
                                        label:
                                            'Resize tile. Use tile menu for precise size.',
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors
                                              .resizeDownRight,
                                          child: _handle(
                                            tile,
                                            step,
                                            resize: true,
                                            child: SizedBox(
                                              width: 36,
                                              height: 36,
                                              child: Align(
                                                alignment:
                                                    Alignment.bottomRight,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    5,
                                                  ),
                                                  child: Icon(
                                                    Icons.south_east_rounded,
                                                    size: 18,
                                                    color: palette.accent,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _handle(
    HomeTile tile,
    double step, {
    required bool resize,
    required Widget child,
  }) {
    if (!widget.editing) return child;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        EagerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              EagerGestureRecognizer.new,
              (_) {},
            ),
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_pointer == null && event.buttons == kPrimaryButton) {
            _pointer = event.pointer;
            _start(tile);
          }
        },
        onPointerMove: (event) {
          if (_gestureTile?.id == tile.id) {
            _update(
              DragUpdateDetails(
                delta: event.delta,
                globalPosition: event.position,
              ),
              step,
              resize: resize,
            );
          }
        },
        onPointerUp: (event) {
          if (_pointer == event.pointer) _end();
        },
        onPointerCancel: (event) {
          if (_pointer == event.pointer) _end();
        },
        child: child,
      ),
    );
  }

  /// The tiles the dashboard shipped with before it became a grid. They draw
  /// themselves the way the old home page drew its cards: a flat surface, no
  /// colour wash, and their own badge and label rather than the grid's header.
  static bool _classic(String kind) => const {
    'income',
    'spending',
    'pots',
    'investments',
    'shortcut',
    'recent_activity',
  }.contains(kind);

  /// Whether the tile needs the grid's own header. A classic tile goes without
  /// until the layout is being edited, when the header is also the drag handle.
  bool _chrome(HomeTile tile) => widget.editing || !_classic(tile.kind);

  List<(int, String)> _sections() {
    final result = <(int, String)>[];
    for (final entry in {
      'shortcut': 'Pick up where you left off',
      'recent_activity': "What you've been up to",
    }.entries) {
      final matching = widget.layout.tiles.where(
        (tile) => tile.kind == entry.key,
      );
      if (matching.isEmpty) continue;
      final row = matching.map((tile) => tile.y).reduce(math.min) - 1;
      if (row < 0 ||
          widget.layout.tiles.any(
            (tile) => tile.y <= row && tile.y + tile.h > row,
          )) {
        continue;
      }
      result.add((row, entry.value));
    }
    return result;
  }

  Color _color(HomeTile tile) {
    final palette = context.luma;
    return switch (tile.kind) {
      'income' || 'stocks' || 'github_graph' || 'minecraft' => palette.success,
      'spending' => palette.danger,
      'note' || 'timer' => palette.warning,
      'errands' || 'clock' => Color.lerp(palette.accent, palette.success, .65)!,
      _ => palette.accent,
    };
  }

  Widget _toolbar(HomeTile tile, double step) {
    final definitions = dashboardTileDefinitions.where(
      (definition) => definition.kind == tile.kind,
    );
    final title = definitions.isEmpty ? tile.kind : definitions.first.title;
    final icon = tile.kind == 'shortcut'
        ? switch (tile.config['destination']) {
            5 => Icons.smart_toy_rounded,
            2 => Icons.account_balance_wallet_rounded,
            1 => Icons.swap_horiz_rounded,
            7 => Icons.settings_rounded,
            _ => Icons.arrow_forward_rounded,
          }
        : definitions.isEmpty
        ? Icons.widgets_outlined
        : definitions.first.icon;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: MouseRegion(
              cursor: widget.editing
                  ? SystemMouseCursors.grab
                  : MouseCursor.defer,
              child: _handle(
                tile,
                step,
                resize: false,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _color(tile).withValues(alpha: .17),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          widget.editing ? Icons.drag_indicator_rounded : icon,
                          size: 19,
                          color: _color(tile),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tile.kind == 'shortcut' && !widget.editing
                              ? ''
                              : title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.editing)
            PopupMenuButton<String>(
              tooltip: 'Edit $title',
              icon: const Icon(Icons.more_horiz_rounded, size: 20),
              onSelected: (action) {
                switch (action) {
                  case 'configure':
                    _configure(tile);
                  case 'position':
                    _position(tile);
                  case 'remove':
                    widget.onChanged(
                      widget.layout.copyWith(
                        tiles: widget.layout.tiles
                            .where((item) => item.id != tile.id)
                            .toList(),
                      ),
                    );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'configure', child: Text('Configure')),
                PopupMenuItem(
                  value: 'position',
                  child: Text('Position & size'),
                ),
                PopupMenuItem(value: 'remove', child: Text('Remove tile')),
              ],
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.column, this.row, this.color);
  final double column;
  final double row;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: .65);
    for (double x = 0; x < size.width; x += column) {
      for (double y = 0; y < size.height; y += row) {
        canvas.drawCircle(Offset(x + 2, y + 2), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      column != oldDelegate.column ||
      row != oldDelegate.row ||
      color != oldDelegate.color;
}

class _PositionDialog extends StatefulWidget {
  const _PositionDialog({required this.tile, required this.columns});
  final HomeTile tile;
  final int columns;
  @override
  State<_PositionDialog> createState() => _PositionDialogState();
}

class _PositionDialogState extends State<_PositionDialog> {
  late final controllers = [
    for (final value in [
      widget.tile.x + 1,
      widget.tile.y + 1,
      widget.tile.w,
      widget.tile.h,
    ])
      TextEditingController(text: '$value'),
  ];
  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Position & size'),
    content: SizedBox(
      width: 340,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < controllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controllers[i],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: [
                      'Column',
                      'Row',
                      'Width in columns',
                      'Height in rows',
                    ][i],
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            const Text(
              'Positions start at 1. Tiles snap to the grid and make room automatically.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final values = controllers
              .map((c) => int.tryParse(c.text) ?? 1)
              .toList();
          final width = values[2].clamp(2, widget.columns);
          Navigator.pop(
            context,
            widget.tile.copyWith(
              x: (values[0] - 1).clamp(0, widget.columns - width),
              y: (values[1] - 1).clamp(0, 1000),
              w: width,
              h: values[3].clamp(2, 40),
            ),
          );
        },
        child: const Text('Apply'),
      ),
    ],
  );
}
