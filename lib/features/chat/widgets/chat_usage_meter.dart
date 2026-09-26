import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';
import '../chat_usage.dart';

/// One usage limit row in the meter's popover: "5-hour limit · 13%".
class ChatUsageLimit {
  const ChatUsageLimit({
    required this.label,
    required this.detail,
    required this.fraction,
  });

  final String label;
  final String detail;

  /// 0..1 of the limit used.
  final double fraction;
}

/// The Claude-style usage ring beside the model picker. The ring fills with
/// how much of the model's context window the conversation occupies; tapping
/// it opens a panel with the context window, the provider's usage limits,
/// and what the last reply cost.
class ChatUsageMeter extends StatelessWidget {
  const ChatUsageMeter({
    super.key,
    required this.contextWindow,
    required this.lastReply,
    required this.limits,
    required this.limitsTitle,
    this.limitsNote,
    this.onOpenBreakdown,
  });

  final int contextWindow;

  /// Null on a new chat, or before the first reply carrying usage.
  final ChatReplyUsage? lastReply;

  final List<ChatUsageLimit> limits;

  /// "Usage limits · Luma AI" — names the provider the limits belong to.
  final String limitsTitle;

  /// Shown instead of (or under) the limit rows, e.g. "no usage limits".
  final String? limitsNote;

  final VoidCallback? onOpenBreakdown;

  double get _contextFraction => lastReply == null
      ? 0
      : (lastReply!.contextTokens / contextWindow).clamp(0.0, 1.0);

  double get _worstLimit =>
      limits.fold(0.0, (worst, l) => math.max(worst, l.fraction));

  Future<void> _open(BuildContext context) async {
    final luma = context.luma;
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    await showMenu<void>(
      context: context,
      position: position,
      color: luma.surface,
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 340),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: luma.border),
      ),
      items: [
        _PanelEntry(
          child: _UsagePanel(
            contextWindow: contextWindow,
            contextFraction: _contextFraction,
            lastReply: lastReply,
            limits: limits,
            limitsTitle: limitsTitle,
            limitsNote: limitsNote,
            onOpenBreakdown: onOpenBreakdown,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final worst = _worstLimit;
    final color = worst >= 1
        ? luma.danger
        : worst >= 0.8
        ? luma.warning
        : luma.accent;
    return IconButton(
      tooltip: L.of(context).assistantUsage,
      onPressed: () => _open(context),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(32),
        maximumSize: const Size.square(32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: SizedBox.square(
        dimension: 16,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: _contextFraction,
            track: luma.border,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.track,
    required this.color,
  });

  final double fraction;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.shortestSide * 0.16;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final circle = rect.deflate(stroke / 2);
    canvas.drawArc(circle, 0, math.pi * 2, false, paint..color = track);
    if (fraction > 0) {
      canvas.drawArc(
        circle,
        -math.pi / 2,
        math.pi * 2 * math.max(fraction, 0.04),
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

/// Hosts the panel as a single non-selectable popup-menu entry.
class _PanelEntry extends PopupMenuEntry<void> {
  const _PanelEntry({required this.child});

  final Widget child;

  @override
  double get height => 0;

  @override
  bool represents(void value) => false;

  @override
  State<_PanelEntry> createState() => _PanelEntryState();
}

class _PanelEntryState extends State<_PanelEntry> {
  @override
  Widget build(BuildContext context) => widget.child;
}

class _UsagePanel extends StatelessWidget {
  const _UsagePanel({
    required this.contextWindow,
    required this.contextFraction,
    required this.lastReply,
    required this.limits,
    required this.limitsTitle,
    required this.limitsNote,
    required this.onOpenBreakdown,
  });

  final int contextWindow;
  final double contextFraction;
  final ChatReplyUsage? lastReply;
  final List<ChatUsageLimit> limits;
  final String limitsTitle;
  final String? limitsNote;
  final VoidCallback? onOpenBreakdown;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final used = lastReply?.contextTokens ?? 0;
    final percent = (contextFraction * 100).round();
    Widget divider() => Divider(height: 22, color: luma.border);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Row(
            label: t.assistantContextWindow,
            detail:
                '${compactTokens(used)} / ${compactTokens(contextWindow)} '
                '($percent%)',
            muted: true,
          ),
          const SizedBox(height: 8),
          _Bar(fraction: contextFraction, color: luma.accent),
          divider(),
          Text(
            limitsTitle,
            style: TextStyle(color: luma.textMuted, fontSize: 13),
          ),
          for (final limit in limits) ...[
            const SizedBox(height: 12),
            _Row(label: limit.label, detail: limit.detail),
            const SizedBox(height: 8),
            _Bar(
              fraction: limit.fraction,
              color: limit.fraction >= 1
                  ? luma.danger
                  : limit.fraction >= 0.8
                  ? luma.warning
                  : luma.accent,
            ),
          ],
          if (limitsNote != null) ...[
            const SizedBox(height: 8),
            Text(
              limitsNote!,
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
          ],
          divider(),
          _Row(
            label: t.assistantLastReply,
            detail: lastReply == null
                ? t.assistantNoRepliesYet
                : t.assistantTokensInOut(
                    compactTokens(lastReply!.inputTokens),
                    compactTokens(lastReply!.outputTokens),
                  ),
            muted: true,
          ),
          if (onOpenBreakdown != null) ...[
            divider(),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Navigator.of(context).pop();
                onOpenBreakdown!();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.assistantDetailedBreakdown,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: luma.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.detail, this.muted = false});

  final String label;
  final String detail;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: muted ? luma.textSecondary : luma.textPrimary,
              fontSize: 13.5,
              fontWeight: muted ? FontWeight.w400 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(detail, style: TextStyle(color: luma.textSecondary, fontSize: 13)),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: fraction.clamp(0.0, 1.0),
        minHeight: 5,
        color: color,
        backgroundColor: context.luma.border,
      ),
    );
  }
}
