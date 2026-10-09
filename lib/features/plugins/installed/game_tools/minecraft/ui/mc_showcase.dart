import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../theme/luma_theme.dart';
import '../mc_shots.dart';
import '../mc_tool_catalog.dart';
import 'mc_style.dart';

/// The hub's moving parts, after Pugtools: every tool shown by a screenshot
/// of itself in the user's own background, a spotlight that turns over on
/// its own, and cards that rise into place.

/// Motion tokens shared by the hub, so everything moves with one rhythm.
abstract final class McMotion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slide = Duration(milliseconds: 420);

  /// How long the spotlight dwells on a tool before moving on.
  static const dwell = Duration(seconds: 6);

  static const enter = Curves.easeOutCubic;

  /// True when the platform asks for less motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// A tool's screenshot, in the set that matches the current background.
/// Falls back to a drawn card when the image is missing, so a tool added
/// before its screenshots were rendered still gets a picture.
class McShot extends StatelessWidget {
  const McShot({super.key, required this.tool, this.zoom = 1});

  final McTool tool;

  /// Scale about the top-left corner, for hover and the spotlight's drift.
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final variant = McShotVariant.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decode at the size it is drawn, not the 960px it is stored at.
        final cache = constraints.maxWidth.isFinite
            ? math.min(960, (constraints.maxWidth * dpr * 1.1).ceil())
            : null;
        return ClipRect(
          child: Transform.scale(
            scale: zoom,
            alignment: Alignment.topLeft,
            child: Image.asset(
              mcShotAsset(tool, variant),
              key: ValueKey(variant),
              fit: BoxFit.cover,
              alignment: Alignment.topLeft,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: cache,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              frameBuilder: (context, child, frame, sync) {
                if (sync) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: McMotion.medium,
                  curve: McMotion.enter,
                  child: child,
                );
              },
              errorBuilder: (context, error, stack) => McToolArt(tool: tool),
            ),
          ),
        );
      },
    );
  }
}

/// Fades and lifts its child into place, [delay] after it first builds.
/// One controller and an [Interval] — no timers left behind.
class McReveal extends StatefulWidget {
  const McReveal({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<McReveal> createState() => _McRevealState();
}

class _McRevealState extends State<McReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: McMotion.slide + widget.delay,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds / _controller.duration!.inMicroseconds,
      1,
      curve: McMotion.enter,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (McMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Hover state for a card, with the lift and screenshot zoom it drives.
mixin _Hoverable<T extends StatefulWidget> on State<T> {
  bool hover = false;

  Widget hoverRegion({required VoidCallback onTap, required Widget child}) =>
      MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: GestureDetector(onTap: onTap, child: child),
      );
}

/// One tool on the hub: its screenshot as the banner, the name in bold and a
/// line of what it does — the card Pugtools lists every tool with.
class McToolCard extends StatefulWidget {
  const McToolCard({
    super.key,
    required this.tool,
    required this.onTap,
    this.showAudience = false,
  });

  final McTool tool;
  final VoidCallback onTap;
  final bool showAudience;

  @override
  State<McToolCard> createState() => _McToolCardState();
}

class _McToolCardState extends State<McToolCard> with _Hoverable {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final tool = widget.tool;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lit = hover || _focused;
    return Semantics(
      button: true,
      label: '${tool.title(t)}. ${tool.blurb(t)}',
      excludeSemantics: true,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: hoverRegion(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: McMotion.fast,
            curve: McMotion.enter,
            transform: Matrix4.translationValues(0, lit ? -4 : 0, 0),
            decoration: BoxDecoration(
              color: luma.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focused
                    ? luma.accent
                    : hover
                    ? tool.hue.color.withValues(alpha: 0.55)
                    : luma.border,
                width: _focused ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (lit ? tool.hue.color : Colors.black).withValues(
                    alpha: lit ? 0.18 : (dark ? 0.14 : 0.045),
                  ),
                  blurRadius: lit ? 26 : 12,
                  offset: Offset(0, lit ? 10 : 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(end: lit ? 1.06 : 1),
                            duration: McMotion.medium,
                            curve: McMotion.enter,
                            builder: (context, zoom, _) =>
                                McShot(tool: tool, zoom: zoom),
                          ),
                          // A hairline inside the frame, so a light
                          // screenshot does not bleed into a light card.
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: luma.border.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            top: 8,
                            child: McTag(tool.tagLabel(t), hue: tool.hue, solid: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tool.title(t),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.25,
                              ),
                            ),
                          ),
                          AnimatedSlide(
                            duration: McMotion.fast,
                            curve: McMotion.enter,
                            offset: Offset(lit ? 0 : -0.4, 0),
                            child: AnimatedOpacity(
                              duration: McMotion.fast,
                              opacity: lit ? 1 : 0,
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 17,
                                color: tool.hue.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tool.blurb(t),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                      if (widget.showAudience) ...[
                        const SizedBox(height: 8),
                        Text(
                          tool.group.audience.label(t),
                          style: TextStyle(
                            color: luma.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pugtools' headline carousel: one tool large, the next two stacked beside
/// it, arrows at the edges and a bar underneath that fills while the
/// spotlight dwells and slides to the next tool when it moves on.
///
/// Turns over by itself every [McMotion.dwell], pausing under the pointer
/// and not at all when the platform asks for reduced motion.
class McSpotlight extends StatefulWidget {
  const McSpotlight({super.key, required this.tools, required this.onOpen});

  final List<McTool> tools;
  final ValueChanged<McTool> onOpen;

  @override
  State<McSpotlight> createState() => _McSpotlightState();
}

class _McSpotlightState extends State<McSpotlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dwell = AnimationController(
    vsync: this,
    duration: McMotion.dwell,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) _go(1);
    });

  int _index = 0;
  int _direction = 1;
  bool _paused = false;
  bool _reduced = false;

  int get _count => widget.tools.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = McMotion.reduced(context);
    _resume();
  }

  @override
  void didUpdateWidget(McSpotlight old) {
    super.didUpdateWidget(old);
    // The catalogue hands out a fresh list each build; only a different set
    // of tools (another sub-tab) starts the spotlight over.
    if (!listEquals(old.tools, widget.tools)) {
      _index = 0;
      _dwell.value = 0;
      _resume();
    }
  }

  @override
  void dispose() {
    _dwell.dispose();
    super.dispose();
  }

  void _resume() {
    if (_reduced || _paused || _count < 2) {
      _dwell.stop();
    } else {
      _dwell.forward();
    }
  }

  void _go(int step) {
    if (_count == 0) return;
    setState(() {
      _direction = step >= 0 ? 1 : -1;
      _index = (_index + step) % _count;
      if (_index < 0) _index += _count;
    });
    _dwell.value = 0;
    _resume();
  }

  void _pause(bool paused) {
    _paused = paused;
    _resume();
  }

  McTool _at(int offset) => widget.tools[(_index + offset) % _count];

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    final luma = context.luma;
    final t = L.of(context);
    final material = MaterialLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 760 && _count >= 3;
        const gap = 16.0;
        final bigWidth = wide ? (width - gap) * 0.64 : width;
        // A 16:9 screenshot plus the caption under it.
        final height = bigWidth * 9 / 16 + 74;

        Widget slide(int index) {
          final big = _SpotCard(
            key: ValueKey('big$index'),
            tool: widget.tools[index],
            large: true,
            dwell: _reduced ? null : _dwell,
            onTap: () => widget.onOpen(widget.tools[index]),
          );
          if (!wide) return big;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: bigWidth, child: big),
              const SizedBox(width: gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final offset in [1, 2]) ...[
                      if (offset == 2) const SizedBox(height: gap),
                      Expanded(
                        child: _SpotCard(
                          tool: _at(offset),
                          onTap: () => widget.onOpen(_at(offset)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }

        final carousel = SizedBox(
          height: height,
          child: AnimatedSwitcher(
            duration: _reduced ? Duration.zero : McMotion.slide,
            switchInCurve: McMotion.enter,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) {
              final incoming = child.key == ValueKey(_index);
              final dx = 0.06 * _direction * (incoming ? 1 : -1);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(dx, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(key: ValueKey(_index), child: slide(_index)),
          ),
        );

        return MouseRegion(
          onEnter: (_) => _pause(true),
          onExit: (_) => _pause(false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  carousel,
                  if (_count > 1) ...[
                    Positioned(
                      left: wide ? -18 : 8,
                      top: height / 2 - 22,
                      child: _Arrow(
                        icon: Icons.chevron_left_rounded,
                        tooltip: material.previousPageTooltip,
                        onTap: () => _go(-1),
                      ),
                    ),
                    Positioned(
                      right: wide ? -18 : 8,
                      top: height / 2 - 22,
                      child: _Arrow(
                        icon: Icons.chevron_right_rounded,
                        tooltip: material.nextPageTooltip,
                        onTap: () => _go(1),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Semantics(
                label: '${_index + 1} / $_count, ${_at(0).title(t)}',
                child: _Progress(
                  index: _index,
                  count: _count,
                  dwell: _reduced ? null : _dwell,
                  color: luma.accent,
                  track: luma.border,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A screenshot card in the spotlight: the picture fills the card and the
/// caption sits under it, as on Pugtools' front page.
class _SpotCard extends StatefulWidget {
  const _SpotCard({
    super.key,
    required this.tool,
    required this.onTap,
    this.large = false,
    this.dwell,
  });

  final McTool tool;
  final VoidCallback onTap;
  final bool large;

  /// Drives a slow drift across the big card's screenshot while it is up.
  final Animation<double>? dwell;

  @override
  State<_SpotCard> createState() => _SpotCardState();
}

class _SpotCardState extends State<_SpotCard> with _Hoverable {
  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final tool = widget.tool;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dwell = widget.dwell;

    final shot = TweenAnimationBuilder<double>(
      tween: Tween(end: hover ? 1.05 : 1),
      duration: McMotion.medium,
      curve: McMotion.enter,
      builder: (context, zoom, _) => dwell == null
          ? McShot(tool: tool, zoom: zoom)
          // Ken Burns: the large picture creeps in while the bar fills.
          : AnimatedBuilder(
              animation: dwell,
              builder: (context, _) => McShot(
                tool: tool,
                zoom: zoom + 0.045 * Curves.easeInOut.transform(dwell.value),
              ),
            ),
    );

    return Semantics(
      button: true,
      label: '${tool.title(t)}. ${tool.blurb(t)}',
      excludeSemantics: true,
      child: hoverRegion(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: McMotion.fast,
          curve: McMotion.enter,
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hover ? tool.hue.color.withValues(alpha: 0.6) : luma.border,
            ),
            boxShadow: [
              BoxShadow(
                color: (hover ? tool.hue.color : Colors.black).withValues(
                  alpha: hover ? 0.18 : (dark ? 0.16 : 0.05),
                ),
                blurRadius: hover ? 28 : 16,
                offset: Offset(0, hover ? 10 : 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    shot,
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(height: 1, color: luma.border),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, widget.large ? 12 : 9, 16, widget.large ? 14 : 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title(t),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: widget.large ? 18 : 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.blurb(t),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: widget.large ? 13.5 : 12,
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
  }
}

/// A round arrow at the carousel's edge, half over the cards.
class _Arrow extends StatefulWidget {
  const _Arrow({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_Arrow> createState() => _ArrowState();
}

class _ArrowState extends State<_Arrow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: widget.tooltip,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: McMotion.fast,
        child: Material(
          color: luma.surface,
          shape: CircleBorder(side: BorderSide(color: luma.border)),
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _down = v),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(widget.icon, color: luma.textPrimary, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar under the spotlight: a segment per tool that slides to the
/// current one, filling as the spotlight dwells.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.index,
    required this.count,
    required this.dwell,
    required this.color,
    required this.track,
  });

  final int index;
  final int count;
  final Animation<double>? dwell;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segment = constraints.maxWidth / count;
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: track,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: McMotion.slide,
                curve: McMotion.enter,
                left: segment * index,
                top: 0,
                bottom: 0,
                width: segment,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: dwell == null
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                      : AnimatedBuilder(
                          animation: dwell!,
                          builder: (context, _) => FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: dwell!.value,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The drawn stand-in for a tool without a screenshot: a wash in the tool's
/// hue, a scatter of little blocks and its icon on a raised tile.
class McToolArt extends StatelessWidget {
  const McToolArt({super.key, required this.tool});

  final McTool tool;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hue = tool.hue.color;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(luma.surface, hue, dark ? 0.16 : 0.10)!,
                Color.lerp(luma.surface, hue, dark ? 0.32 : 0.24)!,
              ],
            ),
          ),
        ),
        CustomPaint(
          painter: _CubeScatterPainter(
            colors: [hue, Color.lerp(hue, Colors.white, 0.35)!],
            seed: tool.index * 31 + 3,
            opacity: dark ? 0.55 : 0.7,
          ),
        ),
        Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: dark ? luma.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: hue.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(tool.icon, color: hue, size: 30),
          ),
        ),
      ],
    );
  }
}

/// A loose scatter of little isometric blocks, clear of the centre tile.
class _CubeScatterPainter extends CustomPainter {
  _CubeScatterPainter({
    required this.colors,
    required this.seed,
    required this.opacity,
  });

  final List<Color> colors;
  final int seed;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    for (var i = 0; i < 6; i++) {
      final s = 9 + rnd.nextDouble() * 12;
      var x = rnd.nextDouble() * size.width;
      if ((x - size.width / 2).abs() < 50) x += x < size.width / 2 ? -60 : 60;
      var y = 10 + rnd.nextDouble() * (size.height - 20);
      if (x < 110 && y < 44) y += 44;
      _cube(canvas, Offset(x, y), s, colors[i % colors.length]);
    }
  }

  void _cube(Canvas canvas, Offset top, double s, Color color) {
    final w = s * 0.87;
    final h = s * 0.5;
    Path face(List<Offset> points) => Path()..addPolygon(points, true);
    Paint fill(Color c) => Paint()..color = c.withValues(alpha: opacity);
    canvas.drawPath(
      face([top, top + Offset(w, h), top + Offset(0, 2 * h), top + Offset(-w, h)]),
      fill(Color.lerp(color, Colors.white, 0.25)!),
    );
    canvas.drawPath(
      face([top + Offset(-w, h), top + Offset(0, 2 * h), top + Offset(0, 2 * h + s), top + Offset(-w, h + s)]),
      fill(color),
    );
    canvas.drawPath(
      face([top + Offset(w, h), top + Offset(0, 2 * h), top + Offset(0, 2 * h + s), top + Offset(w, h + s)]),
      fill(Color.lerp(color, Colors.black, 0.22)!),
    );
  }

  @override
  bool shouldRepaint(_CubeScatterPainter old) =>
      old.seed != seed || old.colors != colors || old.opacity != opacity;
}
