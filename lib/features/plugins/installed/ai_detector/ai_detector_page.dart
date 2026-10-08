import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../sync/sync_scope.dart';
import '../../../../sync/sync_service.dart';
import '../../../../theme/luma_theme.dart';
import 'ai_detector_engine.dart';
import 'ai_review_api.dart';

/// The AI Detector plugin: paste text, run a purely statistical style
/// analysis over it, and get a score plus the list of signals that fired —
/// each with the exact evidence from the text, and every flagged stretch
/// painted back onto the source. The statistics never leave the device.
///
/// When signed in to an approved account, Review also sends the text to the
/// luma server, where the model and instructions picked in the admin
/// dashboard judge where and how it reads AI-generated — see [AiReviewApi].
/// That verdict leads the report; the statistics stay as the fallback and as
/// supporting evidence.
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
  String? _localeTag;

  AiReview? _aiReview;
  String? _aiError;
  bool _aiBusy = false;
  AiServerStatus? _status;

  /// Bumped whenever the reviewed text changes, so a deep check that comes
  /// back after a new Review or Clear is dropped instead of shown.
  int _aiRun = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatus());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    if (_localeTag != null && _localeTag != localeTag && _analysed != null) {
      // Engine output contains localized labels and explanations, so rebuild
      // the cached report when Settings changes the app locale.
      _report = AiDetectorEngine.analyze(_analysed!);
    }
    _localeTag = localeTag;
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
    final t = L.of(context);
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      setState(() => _error = t.aiDetectorClipboardEmpty);
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
      _resetDeepCheck();
    });
    _reviewIfIncluded();
  }

  /// Runs the AI model review on its own while the plan still has an
  /// included check this week. Once those are gone a review costs a share of
  /// the weekly limit, so it waits for an explicit tap on the card instead.
  Future<void> _reviewIfIncluded() async {
    final run = _aiRun;
    final status = await _loadStatus();
    if (!mounted || run != _aiRun) return;
    if (status != null && status.aiCheckRemaining > 0) _deepCheck();
  }

  Future<AiServerStatus?> _loadStatus() async {
    final sync = SyncScope.maybeOf(context);
    if (sync == null || !sync.serverReady) return null;
    final status = await sync.aiStatus();
    if (mounted) setState(() => _status = status);
    return status;
  }

  void _clear() {
    setState(() {
      _controller.clear();
      _report = null;
      _analysed = null;
      _error = null;
      _tab = 0;
      _resetDeepCheck();
    });
  }

  void _resetDeepCheck() {
    _aiRun++;
    _aiReview = null;
    _aiError = null;
    _aiBusy = false;
  }

  Future<void> _deepCheck() async {
    final text = _analysed;
    final sync = SyncScope.maybeOf(context);
    final baseUrl = sync?.serverUrl;
    if (text == null || _aiBusy) return;
    if (sync == null || !sync.serverReady || baseUrl == null) return;
    final run = ++_aiRun;
    setState(() {
      _aiBusy = true;
      _aiError = null;
    });
    final api = AiReviewApi(baseUrl, token: sync.authToken);
    AiReview? review;
    String? error;
    try {
      review = await api.review(text);
    } on AiReviewException catch (e) {
      error = e.message;
    } finally {
      api.close();
    }
    if (!mounted || run != _aiRun) return;
    setState(() {
      _aiBusy = false;
      _aiReview = review;
      _aiError = error;
    });
    _loadStatus();
  }

  static int _countWords(String text) => RegExp(r'\S+').allMatches(text).length;

  Widget _deepCheckCard() {
    final sync = SyncScope.maybeOf(context);
    Widget card() => _DeepCheckCard(
          text: _analysed!,
          available: sync?.serverReady ?? false,
          busy: _aiBusy,
          review: _aiReview,
          error: _aiError,
          status: _status,
          onRun: _deepCheck,
        );
    if (sync == null) return card();
    return ListenableBuilder(listenable: sync, builder: (_, _) => card());
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
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
                  status: _status,
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
                        _deepCheckCard(),
                        const SizedBox(height: 16),
                        _VerdictCard(report: report),
                        const SizedBox(height: 16),
                        LumaSegmentedTabs(
                          tabs: [
                            t.aiDetectorTabHighlights(report.highlights.length),
                            t.aiDetectorTabSignals(
                                report.triggers.where((s) => s.fired).length),
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
                  t.aiDetectorDisclaimer,
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
    required this.status,
    required this.onPaste,
    required this.onClear,
    required this.onAnalyze,
  });

  final TextEditingController controller;
  final int words;
  final int minWords;
  final String? error;
  final AiServerStatus? status;
  final VoidCallback onPaste;
  final VoidCallback onClear;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
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
                      t.aiDetectorInputTitle,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.aiDetectorInputSubtitle,
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Chip(
                    icon: Icons.lock_outline_rounded,
                    label: t.aiDetectorOnDevice,
                    color: luma.success,
                  ),
                  if (status case final status?) ...[
                    const SizedBox(height: 6),
                    _Chip(
                      icon: Icons.bolt_rounded,
                      label: status.aiCheckRemaining > 0
                          ? t.aiDetectorReviewsLeft(
                              status.aiCheckRemaining, status.aiCheckLimit)
                          : t.aiDetectorReviewsCost(status.aiCheckExchangePct),
                      color: status.aiCheckRemaining > 0
                          ? luma.accent
                          : luma.warning,
                    ),
                  ],
                ],
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
              hintText: t.aiDetectorHint,
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
                          ? t.aiDetectorWordsShort(words, minWords)
                          : t.aiDetectorWordsReady(words)),
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
                label: t.commonPaste,
                icon: Icons.content_paste_rounded,
                onTap: onPaste,
              ),
              LumaGhostButton(
                label: t.commonClear,
                icon: Icons.backspace_outlined,
                onTap: onClear,
              ),
              LumaPrimaryButton(
                label: t.aiDetectorReview,
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
    final t = L.of(context);
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
                _Stat(label: t.aiDetectorStatWords, value: '${report.wordCount}'),
                _Divider(color: luma.border),
                _Stat(label: t.aiDetectorStatSentences, value: '${report.sentenceCount}'),
                _Divider(color: luma.border),
                _Stat(
                  label: t.aiDetectorStatAvgWords,
                  value: report.avgSentenceWords.toStringAsFixed(1),
                ),
                _Divider(color: luma.border),
                _Stat(
                  label: t.aiDetectorStatFlagged,
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
    final t = L.of(context);
    final luma = context.luma;
    final target = report.score / 100;
    return Semantics(
      label: t.aiDetectorGaugeSemantic(report.score.round(), report.verdict),
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
                    t.aiDetectorAiLikelihood,
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
    final t = L.of(context);
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (report.claudeSigned) ...[
          _Chip(
            icon: Icons.verified_rounded,
            label: t.aiDetectorWatermarkMatch,
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
              ? t.aiDetectorSummarySigned
              : report.reliable
                  ? t.aiDetectorSummaryBased(
                      report.wordCount, report.sentenceCount)
                  : t.aiDetectorSummaryShort,
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

// ---- deep check -------------------------------------------------------------

/// The server-side model review, started by Review when signed in and shown
/// as a score, a summary and the passages the model pointed at — each
/// painted onto the text with its reason.
class _DeepCheckCard extends StatelessWidget {
  const _DeepCheckCard({
    required this.text,
    required this.available,
    required this.busy,
    required this.review,
    required this.error,
    required this.status,
    required this.onRun,
  });

  final String text;
  final bool available;
  final bool busy;
  final AiReview? review;
  final String? error;
  final AiServerStatus? status;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final review = this.review;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LumaIconBadge(
                icon: Icons.psychology_alt_rounded,
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
                      t.aiDetectorDeepCheckTitle,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !available
                          ? t.aiDetectorDeepCheckSignIn
                          : busy
                              ? t.aiDetectorDeepCheckReading
                              : review != null
                                  ? _chargeNote(t, review.charge)
                                  : status != null &&
                                          status!.aiCheckRemaining <= 0
                                      ? t.aiDetectorDeepCheckExhausted(
                                          status!.aiCheckExchangePct)
                                      : t.aiDetectorDeepCheckIntro,
                      style: TextStyle(
                        color: luma.textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else if (available && error != null)
                LumaGhostButton(
                  label: t.commonTryAgain,
                  icon: Icons.refresh_rounded,
                  onTap: onRun,
                )
              else if (available && review == null && status != null)
                LumaPrimaryButton(
                  label: status!.aiCheckRemaining > 0
                      ? t.aiDetectorRunReview
                      : t.aiDetectorExchangeWeekly(status!.aiCheckExchangePct),
                  icon: Icons.psychology_alt_rounded,
                  onTap: onRun,
                ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 15, color: luma.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error!,
                    style: TextStyle(color: luma.danger, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          if (review != null) ...[
            const SizedBox(height: 16),
            _DeepCheckResult(text: text, review: review),
          ],
        ],
      ),
    );
  }
}

String _chargeNote(L t, AiReviewCharge? charge) {
  if (charge == null) return t.aiDetectorDeepCheckIntro;
  if (charge.exchanged) {
    return t.aiDetectorChargeExchanged(charge.exchangePct);
  }
  return t.aiDetectorChargeUsed(charge.used, charge.included);
}

Color _likelihoodColor(BuildContext context, int likelihood) {
  final luma = context.luma;
  if (likelihood < 38) return luma.success;
  if (likelihood < 58) return luma.warning;
  return luma.danger;
}

class _DeepCheckResult extends StatelessWidget {
  const _DeepCheckResult({required this.text, required this.review});

  final String text;
  final AiReview review;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = _likelihoodColor(context, review.score);
    final located = review.passages
        .where((p) => p.located && p.end! <= text.length)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${review.score}',
              style: TextStyle(
                color: color,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.verdict,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (review.summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      review.summary,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (located.isNotEmpty) ...[
          const SizedBox(height: 14),
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
                children: _spans(context, located),
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13.5,
                  height: 1.7,
                ),
              ),
            ),
          ),
        ],
        for (final (i, p) in review.passages.indexed) ...[
          SizedBox(height: i == 0 ? 14 : 10),
          _PassageTile(passage: p),
        ],
      ],
    );
  }

  List<TextSpan> _spans(BuildContext context, List<AiReviewPassage> passages) {
    final t = L.of(context);
    final luma = context.luma;
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final p in passages) {
      final start = math.max(p.start!, cursor);
      if (start >= p.end!) continue;
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start)));
      }
      final color = _likelihoodColor(context, p.likelihood);
      spans.add(TextSpan(
        text: text.substring(start, p.end!),
        style: TextStyle(
          color: luma.textPrimary,
          backgroundColor: color.withValues(alpha: 0.2),
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
        semanticsLabel: t.aiDetectorPassageSemantic(
            p.likelihood, text.substring(start, p.end!)),
      ));
      cursor = p.end!;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return spans;
  }
}

class _PassageTile extends StatelessWidget {
  const _PassageTile({required this.passage});

  final AiReviewPassage passage;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = _likelihoodColor(context, passage.likelihood);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '“${passage.quote}”',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _Chip(
                icon: Icons.smart_toy_outlined,
                label: '${passage.likelihood}%',
                color: color,
              ),
            ],
          ),
          if (passage.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              passage.reason,
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
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
    final t = L.of(context);
    final luma = context.luma;
    if (report.highlights.isEmpty) {
      return LumaCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: LumaEmptyState(
            icon: Icons.verified_outlined,
            title: t.aiDetectorNothingFlagged,
            subtitle: t.aiDetectorNothingFlaggedBody,
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
            t.aiDetectorHighlightsTitle,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.aiDetectorHighlightsLegend,
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
              t.aiDetectorTruncated(_highlightTextLimit),
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
    final t = L.of(context);
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
        semanticsLabel:
            t.aiDetectorHighlightSemantic(h.note, text.substring(h.start, end)),
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
    final t = L.of(context);
    final luma = context.luma;
    final fired = report.triggers.where((c) => c.fired).toList();
    final quiet = report.triggers.where((c) => !c.fired).toList();
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
                    t.aiDetectorSignalsNothing,
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
              title: t.aiDetectorQuietChecks,
              subtitle: quiet.any((c) => c.oneWay)
                  ? t.aiDetectorQuietOneWay(quiet.length)
                  : t.aiDetectorQuietNothing(quiet.length),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in quiet)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Icon(
                              // A tick would claim the text passed something.
                              // A one-way check that found nothing has not
                              // cleared the text; it simply has no opinion.
                              c.oneWay
                                  ? Icons.remove_rounded
                                  : Icons.check_rounded,
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
                                  c.title,
                                  style: TextStyle(
                                    color: luma.textSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  c.detail,
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
    final t = L.of(context);
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
                      ? t.aiDetectorMatch
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
