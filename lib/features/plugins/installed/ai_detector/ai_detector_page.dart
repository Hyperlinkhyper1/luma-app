import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'ai_detector_engine.dart';

/// The AI Detector plugin: paste text, run a purely statistical style
/// analysis over it, and get a score plus the list of signals that fired —
/// each with the exact evidence from the text, and every flagged stretch
/// painted back onto the source. Nothing leaves the device.
class AiDetectorPage extends StatefulWidget {
  const AiDetectorPage({super.key});

  @override
  State<AiDetectorPage> createState() => _AiDetectorPageState();
}

class _AiDetectorPageState extends State<AiDetectorPage> {
  static const _minWords = 25;

  final _controller = TextEditingController();
  AiDetectorReport? _report;
  String? _analysed;
  String? _error;
  int _tab = 0;
  int _words = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final words = _countWords(_controller.text);
    if (words == _words) return;
    setState(() {
      _words = words;
      if (_error != null) _error = null;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      setState(() => _error = 'Your clipboard is empty.');
      return;
    }
    setState(() {
      _controller.text = text;
      _error = null;
    });
  }

  void _analyze() {
    final text = _controller.text.trim();
    if (_countWords(text) < _minWords) return;
    setState(() {
      _analysed = text;
      _report = AiDetectorEngine.analyze(text);
      _tab = 0;
      _error = null;
    });
  }

  void _clear() {
    setState(() {
      _controller.clear();
      _report = null;
      _analysed = null;
      _error = null;
      _tab = 0;
    });
  }

  static int _countWords(String text) => RegExp(r'\S+').allMatches(text).length;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final report = _report;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InputCard(
                  controller: _controller,
                  words: _words,
                  minWords: _minWords,
                  error: _error,
                  onPaste: _paste,
                  onClear: _clear,
                  onAnalyze: _words >= _minWords ? _analyze : null,
                ),
                if (report != null && _analysed != null) ...[
                  const SizedBox(height: 16),
                  _RevealOnce(
                    // A fresh key restarts the reveal for each new run, so the
                    // result reads as an answer arriving rather than a panel
                    // that silently swapped its contents.
                    key: ValueKey(report),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _VerdictCard(report: report),
                        const SizedBox(height: 16),
                        LumaSegmentedTabs(
                          tabs: [
                            'Highlights  ${report.highlights.length}',
                            'Signals  ${report.triggers.where((t) => t.fired).length}',
                          ],
                          selectedIndex: _tab,
                          onSelect: (i) => setState(() => _tab = i),
                        ),
                        const SizedBox(height: 12),
                        if (_tab == 0)
                          _HighlightsView(
                            text: _analysed!,
                            report: report,
                          )
                        else
                          _SignalsView(report: report),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Heuristic style analysis — arithmetic on sentence lengths '
                  'and word choices, not proof of anything. Formal human '
                  'writing can look machine-like; edited machine output can '
                  'look human. A named verdict rests on a signature the text '
                  'carries itself, and a signature can be stripped or forged. '
                  'Your text never leaves this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: luma.textMuted,
                    fontSize: 11.5,
                    height: 1.5,
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

/// Fades and lifts its child in once, and not at all when the platform asks
/// for reduced motion.
class _RevealOnce extends StatefulWidget {
  const _RevealOnce({super.key, required this.child});

  final Widget child;

  @override
  State<_RevealOnce> createState() => _RevealOnceState();
}

class _RevealOnceState extends State<_RevealOnce> {
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: widget.child,
    );
  }
}

// ---- input ------------------------------------------------------------------

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.controller,
    required this.words,
    required this.minWords,
    required this.error,
    required this.onPaste,
    required this.onClear,
    required this.onAnalyze,
  });

  final TextEditingController controller;
  final int words;
  final int minWords;
  final String? error;
  final VoidCallback onPaste;
  final VoidCallback onClear;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final short = words < minWords;
    // On a phone a sixteen-line field pushes Review most of a screen below
    // the fold, so the box starts and stops smaller there.
    final compact = MediaQuery.sizeOf(context).height < 820;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LumaIconBadge(
                icon: Icons.fact_check_rounded,
                color: luma.accent,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Review a piece of writing',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Style statistics plus a Claude watermark scan.',
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Chip(
                icon: Icons.lock_outline_rounded,
                label: 'On device',
                color: luma.success,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            minLines: compact ? 5 : 7,
            maxLines: compact ? 10 : 16,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13.5,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Paste the text you want checked — an essay, an '
                  'email, a product review…',
              hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
              filled: true,
              fillColor: luma.background,
              contentPadding: const EdgeInsets.all(16),
              enabledBorder: border(luma.border),
              focusedBorder: border(luma.accent, 1.6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                error != null
                    ? Icons.error_outline_rounded
                    : short
                        ? Icons.short_text_rounded
                        : Icons.check_circle_outline_rounded,
                size: 15,
                color: error != null
                    ? luma.danger
                    : short
                        ? luma.textMuted
                        : luma.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  error ??
                      (short
                          ? '$words of $minWords words — style statistics need '
                              'a bit more to work on.'
                          : '$words words ready to review.'),
                  style: TextStyle(
                    color: error != null ? luma.danger : luma.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 8,
            children: [
              LumaGhostButton(
                label: 'Paste',
                icon: Icons.content_paste_rounded,
                onTap: onPaste,
              ),
              LumaGhostButton(
                label: 'Clear',
                icon: Icons.backspace_outlined,
                onTap: onClear,
              ),
              LumaPrimaryButton(
                label: 'Review',
                icon: Icons.auto_awesome_motion_rounded,
                onTap: onAnalyze,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- verdict ----------------------------------------------------------------

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.report});

  final AiDetectorReport report;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = _scoreColor(context, report);
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final gauge = _Gauge(report: report, color: color);
              final summary = _Summary(report: report, color: color);
              // Below ~420px the two sit on top of each other rather than
              // squeezing the headline into a two-word-per-line column.
              if (constraints.maxWidth < 420) {
                return Column(
                  children: [
                    gauge,
                    const SizedBox(height: 16),
                    summary,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  gauge,
                  const SizedBox(width: 22),
                  Expanded(child: summary),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: luma.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: luma.border),
            ),
            child: Row(
              children: [
                _Stat(label: 'words', value: '${report.wordCount}'),
                _Divider(color: luma.border),
                _Stat(label: 'sentences', value: '${report.sentenceCount}'),
                _Divider(color: luma.border),
                _Stat(
                  label: 'avg words/sentence',
                  value: report.avgSentenceWords.toStringAsFixed(1),
                ),
                _Divider(color: luma.border),
                _Stat(
                  label: 'flagged spans',
                  value: '${report.highlights.length}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _scoreColor(BuildContext context, AiDetectorReport report) {
    final luma = context.luma;
    if (report.claudeSigned) return luma.danger;
    if (report.score < 38) return luma.success;
    if (report.score < 58) return luma.warning;
    return luma.danger;
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.report, required this.color});

  final AiDetectorReport report;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final target = report.score / 100;
    return Semantics(
      label: 'AI likelihood ${report.score.round()} out of 100. '
          '${report.verdict}.',
      excludeSemantics: true,
      child: SizedBox(
        width: 132,
        height: 132,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => CustomPaint(
            painter: _GaugePainter(
              score: value,
              track: luma.border,
              color: color,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (value * 100).round().toString(),
                    style: TextStyle(
                      color: color,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AI-likelihood',
                    style: TextStyle(color: luma.textMuted, fontSize: 10.5),
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

class _Summary extends StatelessWidget {
  const _Summary({required this.report, required this.color});

  final AiDetectorReport report;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (report.claudeSigned) ...[
          _Chip(
            icon: Icons.verified_rounded,
            label: 'Watermark match',
            color: color,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          report.verdict,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          report.claudeSigned
              ? 'The text signs itself — the scan found the hidden marks a '
                  'Claude watermark is carried in, so this is an attribution '
                  'rather than a guess about style.'
              : report.reliable
                  ? 'Based on ${report.wordCount} words across '
                      '${report.sentenceCount} sentences.'
                  : 'Short sample — treat every signal as a hint rather than '
                      'a measurement.',
          style: TextStyle(
            color: report.reliable || report.claudeSigned
                ? luma.textSecondary
                : luma.warning,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: luma.textMuted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 26, child: VerticalDivider(width: 1, color: color));
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.score,
    required this.track,
    required this.color,
  });

  final double score;
  final Color track;
  final Color color;

  static const _start = -math.pi * 0.75; // start lower-left
  static const _sweep = math.pi * 1.5; // 270 degrees total

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(7);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep, false, paint..color = track);
    if (score > 0.005) {
      canvas.drawArc(
        rect,
        _start,
        _sweep * score.clamp(0, 1),
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.score != score || old.color != color || old.track != track;
}

// ---- highlights -------------------------------------------------------------

/// How much of the source is painted. Past this the spans stop being readable
/// evidence and start being a rendering cost, so the tail is summarised.
const _highlightTextLimit = 14000;

class _HighlightsView extends StatelessWidget {
  const _HighlightsView({required this.text, required this.report});

  final String text;
  final AiDetectorReport report;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (report.highlights.isEmpty) {
      return LumaCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: LumaEmptyState(
            icon: Icons.verified_outlined,
            title: 'Nothing flagged',
            subtitle: 'No stock phrases, no hidden characters, no formulaic '
                'openers. Every stretch of this text reads as written by '
                'hand.',
          ),
        ),
      );
    }

    final truncated = text.length > _highlightTextLimit;
    final shown = truncated ? text.substring(0, _highlightTextLimit) : text;
    final counts = report.highlightCounts;
    final kinds = counts.keys.toList()
      ..sort((a, b) => b.severity != a.severity
          ? b.severity.compareTo(a.severity)
          : counts[b]!.compareTo(counts[a]!));

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Everything the checks matched, marked in place',
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Each mark is styled by how strongly it counts, not only by '
            'colour: wavy for a signature, solid for a strong tell, dotted '
            'for a mild one.',
            style: TextStyle(color: luma.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in kinds)
                _LegendChip(kind: kind, count: counts[kind]!),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: luma.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: luma.border),
            ),
            child: SelectableText.rich(
              TextSpan(
                children: _spans(context, shown, report.highlights),
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13.5,
                  height: 1.7,
                ),
              ),
            ),
          ),
          if (truncated) ...[
            const SizedBox(height: 10),
            Text(
              'Showing the first $_highlightTextLimit characters. The score '
              'and the signals below cover the whole text.',
              style: TextStyle(color: luma.textMuted, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  /// Walks the merged highlights in order, emitting the plain text between
  /// them and a styled span for each one.
  static List<TextSpan> _spans(
    BuildContext context,
    String text,
    List<AiHighlight> highlights,
  ) {
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final h in highlights) {
      if (h.start >= text.length) break;
      final end = math.min(h.end, text.length);
      if (h.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, h.start)));
      }
      spans.add(TextSpan(
        text: text.substring(h.start, end),
        style: _styleFor(context, h.kind),
        semanticsLabel: '${h.note}: ${text.substring(h.start, end)}',
      ));
      cursor = end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  static TextStyle _styleFor(BuildContext context, AiHighlightKind kind) {
    final luma = context.luma;
    final color = _kindColor(context, kind);
    return switch (kind.severity) {
      2 => TextStyle(
          color: luma.textPrimary,
          backgroundColor: color.withValues(alpha: 0.26),
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.wavy,
          decorationColor: color,
          decorationThickness: 1.6,
        ),
      1 => TextStyle(
          color: luma.textPrimary,
          backgroundColor: color.withValues(alpha: 0.22),
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: color,
          decorationThickness: 1.4,
        ),
      _ => TextStyle(
          color: luma.textPrimary,
          backgroundColor: color.withValues(alpha: 0.14),
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationColor: color,
        ),
    };
  }
}

Color _kindColor(BuildContext context, AiHighlightKind kind) {
  final luma = context.luma;
  return switch (kind.severity) {
    2 => luma.danger,
    1 => luma.warning,
    _ => luma.accent,
  };
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.kind, required this.count});

  final AiHighlightKind kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = _kindColor(context, kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Aa',
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: color,
              decorationStyle: switch (kind.severity) {
                2 => TextDecorationStyle.wavy,
                1 => TextDecorationStyle.solid,
                _ => TextDecorationStyle.dotted,
              },
            ),
          ),
          const SizedBox(width: 7),
          Text(
            kind.label,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- signals ----------------------------------------------------------------

class _SignalsView extends StatelessWidget {
  const _SignalsView({required this.report});

  final AiDetectorReport report;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final fired = report.triggers.where((t) => t.fired).toList();
    final quiet = report.triggers.where((t) => !t.fired).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fired.isEmpty)
          LumaCard(
            child: Row(
              children: [
                Icon(Icons.verified_outlined, color: luma.success, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nothing suspicious fired — varied lengths, no stock '
                    'phrases, no watermark. Reads like human writing.',
                    style: TextStyle(
                      color: luma.textSecondary,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (var i = 0; i < fired.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _TriggerCard(trigger: fired[i]),
          ],
        if (quiet.isNotEmpty) ...[
          const SizedBox(height: 12),
          LumaCard(
            child: LumaCollapsibleSection(
              icon: Icons.remove_circle_outline_rounded,
              title: 'Quiet checks',
              subtitle: '${quiet.length} checks found nothing worth flagging',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final t in quiet)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: luma.textMuted,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  style: TextStyle(
                                    color: luma.textSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.detail,
                                  style: TextStyle(
                                    color: luma.textMuted,
                                    fontSize: 11.5,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TriggerCard extends StatelessWidget {
  const _TriggerCard({required this.trigger});

  final AiTrigger trigger;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // The watermark scan is the only check that can name an author, so it
    // gets the loudest treatment regardless of how the others landed.
    final signature = trigger.id == 'claude' && trigger.strength >= 0.9;
    final color = signature || trigger.strength >= 0.6
        ? luma.danger
        : trigger.strength >= 0.35
            ? luma.warning
            : luma.accent;
    return LumaCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                signature
                    ? Icons.fingerprint_rounded
                    : Icons.radio_button_checked_rounded,
                size: 17,
                color: color,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  trigger.title,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  signature
                      ? 'match'
                      : '${(trigger.strength * 100).round()}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            trigger.detail,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: trigger.strength,
              minHeight: 5,
              backgroundColor: luma.background,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (trigger.evidence.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in trigger.evidence)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: luma.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: luma.border),
                    ),
                    child: Text(
                      e,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---- shared -----------------------------------------------------------------

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
