import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/luma_theme.dart';
import 'window_controls.dart';

/// A single, unified title bar spanning the full width of the window — the
/// brand mark and active section title on the left, the OS window controls on
/// the right. Replaces the stacked "native title bar + section header" so the
/// top reads as one clean strip (Modrinth / Discord style).
///
/// The whole strip (except the caption buttons) is a drag handle for moving the
/// window; double-clicking it toggles maximize.
class WindowTitleBar extends StatefulWidget {
  WindowTitleBar({
    super.key,
    required this.title,
    bool? showWindowControls,
  }) : showWindowControls = showWindowControls ?? hasCustomTitleBar;

  /// The active section name shown next to the brand.
  final String title;

  /// Whether to render the minimize/maximize/close buttons and enable window
  /// dragging. Defaults to whether this platform has an OS window we own.
  final bool showWindowControls;

  /// Fixed height of the bar; exposed so callers can reserve matching space.
  static const double height = 46;

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> {
  bool _maximized = false;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    if (widget.showWindowControls) {
      windowIsMaximized().then(_setMaximized);
      _sub = windowEvents.listen((_) => windowIsMaximized().then(_setMaximized));
    }
  }

  void _setMaximized(bool value) {
    if (mounted && value != _maximized) setState(() => _maximized = value);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    final content = Row(
      children: [
        const SizedBox(width: 16),
        const _BrandBadge(),
        const SizedBox(width: 11),
        Text(
          'luma',
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 16),
        Container(width: 1, height: 18, color: luma.border),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    return Container(
      height: WindowTitleBar.height,
      decoration: BoxDecoration(
        color: luma.background,
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: widget.showWindowControls
                ? _DragRegion(child: content)
                : content,
          ),
          if (widget.showWindowControls) ...[
            _CaptionButton(
              icon: Icons.remove_rounded,
              tooltip: 'Minimize',
              onPressed: windowMinimize,
            ),
            _CaptionButton(
              icon: _maximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              iconSize: _maximized ? 13 : 15,
              tooltip: _maximized ? 'Restore' : 'Maximize',
              onPressed: windowToggleMaximize,
            ),
            _CaptionButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              danger: true,
              onPressed: windowClose,
            ),
          ] else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Makes its [child] draggable-to-move, with double-click to toggle maximize.
class _DragRegion extends StatelessWidget {
  const _DragRegion({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kPrimaryButton) windowStartDrag();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: windowToggleMaximize,
        child: child,
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/icon.png',
        width: 26,
        height: 26,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// A single Windows-style caption button (minimize / maximize / close) with a
/// full-height hover fill; the close button flushes to red like the platform.
class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 16,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double iconSize;
  final bool danger;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final Color bg = _hovering
        ? (widget.danger ? const Color(0xFFE81123) : luma.surfaceHover)
        : Colors.transparent;
    final Color fg = _hovering && widget.danger
        ? Colors.white
        : (_hovering ? luma.textPrimary : luma.textSecondary);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 46,
            height: WindowTitleBar.height,
            color: bg,
            alignment: Alignment.center,
            child: Icon(widget.icon, size: widget.iconSize, color: fg),
          ),
        ),
      ),
    );
  }
}
