import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'ai_detector_engine.dart';

/// The AI Detector plugin: paste text, run a purely statistical style
/// analysis over it, and get a score plus the list of signals that fired —
/// each with the exact evidence from the text. Nothing leaves the device.
class AiDetectorPage extends StatefulWidget {
  const AiDetectorPage({super.key});

  @override
  State<AiDetectorPage> createState() => _AiDetectorPageState();
}

class _AiDetectorPageState extends State<AiDetectorPage> {
  final _controller = TextEditingController();
  AiDetectorReport? _report;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    if (_countWords(text) < 25) {
      setState(
        () => _error =
            'Paste at least 25 words \u2014 style statistics need some text to work on.',
      );
      return;
    }
    setState(() {
      _report = AiDetectorEngine.analyze(text);
      _error = null;
    });
  }

  static int _countWords(String text) =>
      RegExp(r"\S+").allMatches(text).length;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InputCard(
                  controller: _controller,
                  error: _error,
                  onPaste: _paste,
                  onClear: () => setState(() {
                    _controller.clear();
                    _report = null;
                    _error = null;
                  }),
                  onAnalyze: _analyze,
                ),
                if (_report case final report?) ...[
                  const SizedBox(height: 20),
                  _ScoreCard(report: report),
                  const SizedBox(height: 12),
                  if (report.triggers.any((t) => t.fired))
                    for (final trigger
                        in report.triggers.where((t) => t.fired)) ...[
                      const SizedBox(height: 12),
                      _TriggerCard(trigger: trigger),
                    ]
                  else
                    LumaCard(
                      child: Row(
                        children: [
                          Icon(Icons.verified_outlined,
                              color: luma.success, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Nothing suspicious fired \u2014 varied lengths, '
                              'no stock phrases. Reads like human writing.',
                              style: TextStyle(
                                color: luma.textSecondary,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Heuristic style analysis \u2014 arithmetic on sentence '
                  'lengths and word choices, not proof of anything. Formal '
                  'human writing can look machine-like; edited machine output '
                  'can look human. Your text never leaves this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- input ------------------------------------------------------------------

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.controller,
    required this.error,
    required this.onPaste,
    required this.onClear,
    required this.onAnalyze,
  });

  final TextEditingController controller;
  final String? error;
  final VoidCallback onPaste;
  final VoidCallback onClear;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c),
        );
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            minLines: 6,
            maxLines: 14,
            style: TextStyle(color: luma.textPrimary, fontSize: 13.5, height: 1.45),
            decoration: InputDecoration(
              hintText:
                  'Paste the text you want checked \u2014 an essay, an email, '
                  'a product review\u2026',
              hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
              filled: true,
              fillColor: luma.background,
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: border(luma.border),
              focusedBorder: border(luma.accent),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: TextStyle(color: luma.danger, fontSize: 12.5)),
          ],
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
                label: 'Analyze',
                icon: Icons.search_rounded,
                onTap: onAnalyze,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- score gauge ------------------------------------------------------------

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.report});

  final AiDetectorReport report;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = _scoreColor(context, report.score);
    return LumaCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 128,
                height: 128,
                child: CustomPaint(
                  painter: _GaugePainter(
                    score: report.score / 100,
                    track: luma.border,
                    color: color,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          report.score.round().toString(),
                          style: TextStyle(
                            color: color,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        Text(
                          'AI-likelihood',
                          style:
                              TextStyle(color: luma.textMuted, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      report.verdict,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.reliable
                          ? 'Based on ${report.wordCount} words in '
                              '${report.sentenceCount} sentences.'
                          : 'Short sample \u2014 treat every signal below as a '
                              'hint rather than a measurement.',
                      style: TextStyle(
                        color: report.reliable
                            ? luma.textMuted
                            : luma.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    if (!report.reliable)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Icon(Icons.info_outline_rounded,
                            size: 18, color: luma.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(label: 'words', value: '${report.wordCount}'),
              _Stat(
                label: 'sentences',
                value: '${report.sentenceCount}',
              ),
              _Stat(
                label: 'avg words/sentence',
                value: report.avgSentenceWords.toStringAsFixed(1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _scoreColor(BuildContext context, double score) {
    final luma = context.luma;
    if (score < 38) return luma.success;
    if (score < 58) return luma.accent;
    return luma.danger;
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
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: luma.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
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
    final rect = Offset.zero & size;
    rect.deflate(7);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep, false, paint..color = track);
    if (score > 0.005) {
      canvas.drawArc(rect, _start, _sweep * score.clamp(0, 1), false,
          paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.score != score || old.color != color || old.track != track;
}

// ---- triggers ---------------------------------------------------------------

class _TriggerCard extends StatelessWidget {
  const _TriggerCard({required this.trigger});

  final AiTrigger trigger;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final strong = trigger.strength >= 0.6;
    final dotColor = strong ? luma.danger : luma.accent;
    return LumaCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  trigger.title,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(trigger.strength * 100).round()}%',
                style: TextStyle(
                  color: dotColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            trigger.detail,
            style: TextStyle(color: luma.textSecondary, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: trigger.strength,
              minHeight: 5,
              backgroundColor: luma.background,
              valueColor: AlwaysStoppedAnimation(dotColor),
            ),
          ),
          if (trigger.evidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in trigger.evidence)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
