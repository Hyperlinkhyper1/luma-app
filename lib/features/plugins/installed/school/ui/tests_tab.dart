import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../logic/quiz_bank.dart';
import 'quiz_pdf_options.dart';

/// Practice tests: pick a subject, draw a test from the built-in question
/// bank, answer it, and walk back through every question with the right
/// answer shown.
class TestsTab extends StatefulWidget {
  const TestsTab({super.key});

  @override
  State<TestsTab> createState() => _TestsTabState();
}

enum _Phase { setup, running, review }

class _TestsTabState extends State<TestsTab> {
  _Phase _phase = _Phase.setup;

  QuizSubject? _subject;
  int _length = 20;

  List<QuizQuestion> _questions = const [];
  List<int?> _answers = const [];
  int _index = 0;
  Map<int, String> _typed = {};
  Map<int, Set<int>> _multiple = {};
  DateTime? _startedAt;
  QuizResult? _result;

  void _start(QuizSubject subject, int length) {
    final questions = buildTest(subject, count: length);
    setState(() {
      _subject = subject;
      _length = length;
      _questions = questions;
      _answers = List<int?>.filled(questions.length, null);
      _index = 0;
      _typed = {};
      _multiple = {};
      _startedAt = DateTime.now();
      _result = null;
      _phase = _Phase.running;
    });
  }

  void _answer(int option) {
    setState(
      () => _answers = [
        for (var i = 0; i < _answers.length; i++)
          i == _index ? option : _answers[i],
      ],
    );
  }

  void _finish() {
    setState(() {
      _result = QuizResult(
        subject: _subject!,
        questions: _questions,
        answers: _answers,
        typedAnswers: Map.of(_typed),
        multipleAnswers: {
          for (final e in _multiple.entries) e.key: Set.of(e.value),
        },
        duration: DateTime.now().difference(_startedAt ?? DateTime.now()),
      );
      _phase = _Phase.review;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (_phase) {
        _Phase.setup => _SetupView(
          key: const ValueKey('setup'),
          initialSubject: _subject,
          initialLength: _length,
          onStart: _start,
        ),
        _Phase.running => _RunnerView(
          key: ValueKey('run-${_subject!.id}-${_questions.length}'),
          subject: _subject!,
          questions: _questions,
          answers: _answers,
          index: _index,
          startedAt: _startedAt!,
          typed: _typed,
          multiple: _multiple,
          onType: (value) => setState(() => _typed[_index] = value),
          onSelectOption: (option) {
            if (_questions[_index].input != QuizInput.multiple) {
              _answer(option);
              return;
            }
            setState(() {
              final selected = _multiple.putIfAbsent(_index, () => <int>{});
              if (!selected.remove(option)) selected.add(option);
            });
          },
          onGoTo: (i) => setState(() => _index = i),
          onFinish: _finish,
          onAbort: () => setState(() => _phase = _Phase.setup),
        ),
        _Phase.review => _ReviewView(
          key: const ValueKey('review'),
          result: _result!,
          onRetry: () => _start(_result!.subject, _result!.questions.length),
          onPickOther: () => setState(() => _phase = _Phase.setup),
        ),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

class _SetupView extends StatefulWidget {
  const _SetupView({
    super.key,
    required this.initialSubject,
    required this.initialLength,
    required this.onStart,
  });

  final QuizSubject? initialSubject;
  final int initialLength;
  final void Function(QuizSubject subject, int length) onStart;

  @override
  State<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<_SetupView> {
  QuizSubject? _selected;
  late int _length = widget.initialLength;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSubject;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final selected = _selected;
    final maxForSubject = selected?.questions.length ?? 0;

    return SingleChildScrollView(
      padding: context.isPhoneWidth
          ? const EdgeInsets.fromLTRB(14, 4, 14, 24)
          : const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LumaCard(
            child: Row(
              children: [
                LumaIconBadge(
                  icon: Icons.fact_check_rounded,
                  color: luma.accent,
                  size: 44,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.schoolTestsTitle,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.schoolTestsIntro(
                          QuizBank.level,
                          QuizBank.totalQuestions,
                        ),
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _PdfExportBanner(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const QuizPdfOptions()),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t.schoolTestsChooseSubject,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 940
                  ? 3
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in [
                    QuizBank.doorstroomSubjects,
                    QuizBank.extraSubjects,
                  ]) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        group.first.isDoorstroom
                            ? t.schoolTestsGroupPractice
                            : t.schoolSubjectGroupOther,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 138,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: group.length,
                      itemBuilder: (context, i) {
                        final s = group[i];
                        return _SubjectCard(
                          subject: s,
                          selected: s.id == _selected?.id,
                          onTap: () => setState(() => _selected = s),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Text(
            t.schoolTestsHowMany,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in QuizBank.lengths)
                _LengthChip(
                  label: t.schoolQuestionCount(n),
                  selected: _length == n,
                  enabled: selected == null || maxForSubject >= n,
                  onTap: () => setState(() => _length = n),
                ),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 22),
            LumaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.schoolTestsWhatYouGet,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.schoolTestsWhatYouGetBody,
                    style: TextStyle(color: luma.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in selected.topics)
                        _TopicPill(label: t, color: selected.color),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Flexible(
                child: LumaPrimaryButton(
                  label: selected == null
                      ? t.schoolTestsChooseFirst
                      : t.schoolTestsStartTest(selected.name.toLowerCase()),
                  icon: Icons.play_arrow_rounded,
                  onTap: selected == null
                      ? null
                      : () => widget.onStart(
                          selected,
                          _length > maxForSubject ? maxForSubject : _length,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tappable entry point into [QuizPdfOptions], styled as a primary CTA card
/// rather than a generic outlined button so it reads as a feature of its own.
class _PdfExportBanner extends StatefulWidget {
  const _PdfExportBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PdfExportBanner> createState() => _PdfExportBannerState();
}

class _PdfExportBannerState extends State<_PdfExportBanner> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final t = L.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovering ? luma.accentSubtle : luma.surface,
            borderRadius: BorderRadius.circular(decor.cardRadius),
            border: Border.all(
              color: luma.accent.withValues(alpha: _hovering ? 0.8 : 0.4),
              width: decor.borderWidth,
            ),
          ),
          child: Row(
            children: [
              LumaIconBadge(
                icon: Icons.picture_as_pdf_rounded,
                color: luma.accent,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.schoolPdfAsPdf,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.schoolTestsPdfBannerSub,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: luma.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectCard extends StatefulWidget {
  const _SubjectCard({
    required this.subject,
    required this.selected,
    required this.onTap,
  });

  final QuizSubject subject;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final t = L.of(context);
    final s = widget.subject;
    final active = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: active
                ? s.color.withValues(alpha: 0.10)
                : _hovering
                ? luma.surfaceHover
                : luma.surface,
            borderRadius: BorderRadius.circular(decor.cardRadius),
            border: Border.all(
              color: active ? s.color : luma.border,
              width: active ? 1.6 : decor.borderWidth,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LumaIconBadge(icon: s.icon, color: s.color, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.name,
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (active)
                          Icon(
                            Icons.check_circle_rounded,
                            color: s.color,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.blurb,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      t.schoolTestsSubjectMeta(s.questions.length, s.topics.length),
                      style: TextStyle(color: luma.textMuted, fontSize: 11),
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

class _LengthChip extends StatelessWidget {
  const _LengthChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : luma.surface,
            borderRadius: BorderRadius.circular(decor.pillRadius),
            border: Border.all(
              color: selected ? luma.accent : luma.border,
              width: decor.borderWidth,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? luma.accent : luma.textSecondary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicPill extends StatelessWidget {
  const _TopicPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(context.lumaDecor.pillRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Running the test
// ---------------------------------------------------------------------------

class _RunnerView extends StatefulWidget {
  const _RunnerView({
    super.key,
    required this.subject,
    required this.questions,
    required this.answers,
    required this.index,
    required this.startedAt,
    required this.onSelectOption,
    required this.typed,
    required this.multiple,
    required this.onType,
    required this.onGoTo,
    required this.onFinish,
    required this.onAbort,
  });

  final QuizSubject subject;
  final List<QuizQuestion> questions;
  final List<int?> answers;
  final int index;

  /// When this attempt started, so the header can count up from it.
  final DateTime startedAt;
  final ValueChanged<int> onSelectOption;
  final Map<int, String> typed;
  final Map<int, Set<int>> multiple;
  final ValueChanged<String> onType;
  final ValueChanged<int> onGoTo;
  final VoidCallback onFinish;
  final VoidCallback onAbort;

  @override
  State<_RunnerView> createState() => _RunnerViewState();
}

class _RunnerViewState extends State<_RunnerView> {
  /// Focus for the open-answer field, watched so the phone layout knows the
  /// soft keyboard is up.
  ///
  /// The keyboard itself can't be asked: `Scaffold` subtracts the bottom view
  /// inset from its body before handing it over, so `MediaQuery.viewInsetsOf`
  /// reads zero all the way down. Focus on the field is the same event seen
  /// from the other end, and it is the thing this layout actually cares about.
  final FocusNode _answerFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _answerFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _answerFocus.removeListener(_onFocusChanged);
    _answerFocus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final subject = widget.subject;
    final questions = widget.questions;
    final answers = widget.answers;
    final index = widget.index;
    final typed = widget.typed;
    final multiple = widget.multiple;
    final onGoTo = widget.onGoTo;
    final onFinish = widget.onFinish;

    final q = questions[index];
    final completed = [
      for (var i = 0; i < questions.length; i++)
        questions[i].isOpen
            ? (typed[i]?.trim().isNotEmpty ?? false)
            : questions[i].input == QuizInput.multiple
            ? (multiple[i]?.isNotEmpty ?? false)
            : answers[i] != null,
    ];
    final answered = completed.where((a) => a).length;
    final isLast = index == questions.length - 1;
    final narrow = context.isPhoneWidth;
    // The keyboard takes roughly a third of a phone screen, and the shell's
    // bottom nav sits above it too. With the subject header, the progress bar
    // and the "nakijken" link all pinned as well, the question is left a
    // sliver to scroll in. So on a phone, while an answer is being typed, the
    // header shrinks to the one line that still matters — which question you
    // are on — and the rest steps aside until the keyboard does.
    final typing = narrow && _answerFocus.hasFocus;
    final counter = t.schoolTestsProgress(
      index + 1,
      questions.length,
      answered,
    );

    return Padding(
      padding: narrow
          ? const EdgeInsets.fromLTRB(14, 4, 14, 10)
          : const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (typing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      counter,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onAbort,
                    child: Text(
                      t.commonStop,
                      style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                LumaIconBadge(
                  icon: subject.icon,
                  color: subject.color,
                  size: narrow ? 28 : 34,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        counter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                _ElapsedTimer(
                    startedAt: widget.startedAt, color: subject.color),
                const SizedBox(width: 8),
                // A labelled button costs about 90px the phone header hasn't
                // got; the icon alone still says "stop", with a tooltip.
                if (narrow)
                  IconButton(
                    onPressed: widget.onAbort,
                    tooltip: t.commonStop,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded,
                        size: 20, color: luma.textMuted),
                  )
                else
                  LumaGhostButton(
                    label: t.commonStop,
                    icon: Icons.close_rounded,
                    onTap: widget.onAbort,
                  ),
              ],
            ),
            SizedBox(height: narrow ? 8 : 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: questions.isEmpty ? 0 : (index + 1) / questions.length,
                minHeight: 6,
                backgroundColor: luma.border,
                valueColor: AlwaysStoppedAnimation(subject.color),
              ),
            ),
            SizedBox(height: narrow ? 12 : 16),
          ],
          Expanded(
            // Keyed, and so is the button row below: folding the header away
            // when the keyboard appears shifts every child of this Column up
            // by three slots, and Flutter matches unkeyed children by
            // position. Without the keys the question subtree would be
            // rebuilt from scratch on the first keystroke — losing the focus
            // and the half-typed answer with it.
            key: const ValueKey('runner-body'),
            child: SingleChildScrollView(
              // Dragging the question away puts the keyboard down, which is
              // how you get back to the whole screen without hunting for a
              // dismiss key.
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              // Breathing room so the answer field never ends up flush
              // against the pinned Vorige/Volgende row.
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LumaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TopicPill(label: q.topic, color: subject.color),
                        const SizedBox(height: 12),
                        if (q.passage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: luma.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: luma.border),
                            ),
                            child: Text(
                              q.passage!,
                              style: TextStyle(
                                color: luma.textSecondary,
                                fontSize: 13,
                                height: 1.55,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Text(
                          q.prompt,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _QuestionData(question: q),
                        if (q.isOpen)
                          TextFormField(
                            key: ValueKey(q.id),
                            focusNode: _answerFocus,
                            initialValue: typed[index] ?? '',
                            onChanged: widget.onType,
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: q.input == QuizInput.number
                                ? const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  )
                                : TextInputType.text,
                            decoration: InputDecoration(
                              helperMaxLines: 3,
                              labelText: t.schoolTestsYourAnswer,
                              suffixText: q.unit,
                              helperText: q.input == QuizInput.number
                                  ? t.schoolTestsHelperNumber
                                  : t.schoolTestsHelperWord,
                            ),
                          ),
                        for (var i = 0; i < q.options.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _OptionTile(
                            letter: String.fromCharCode(65 + i),
                            text:
                                '${q.options[i]}${q.unit == null ? '' : ' ${q.unit}'}',
                            state:
                                (q.input == QuizInput.multiple
                                    ? (multiple[index]?.contains(i) ?? false)
                                    : answers[index] == i)
                                ? _OptionState.selected
                                : _OptionState.plain,
                            accent: subject.color,
                            onTap: () => widget.onSelectOption(i),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _QuestionStrip(
                    total: questions.length,
                    current: index,
                    answers: [for (final done in completed) done ? 0 : null],
                    accent: subject.color,
                    onGoTo: onGoTo,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: narrow ? 8 : 12),
          // Stays pinned even while typing: it is what you reach for once the
          // answer is in, and it is small enough to afford above the keyboard.
          Row(
            key: const ValueKey('runner-nav'),
            children: [
              LumaGhostButton(
                label: t.commonPrevious,
                icon: Icons.chevron_left_rounded,
                onTap: index == 0 ? null : () => onGoTo(index - 1),
              ),
              const Spacer(),
              if (!isLast)
                LumaPrimaryButton(
                  label: t.commonNext,
                  icon: Icons.chevron_right_rounded,
                  onTap: () => onGoTo(index + 1),
                )
              else
                LumaPrimaryButton(
                  label: t.schoolTestsCheck,
                  icon: Icons.done_all_rounded,
                  onTap: onFinish,
                ),
            ],
          ),
          if (!isLast && !typing) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onFinish,
                child: Text(
                  t.schoolTestsCheckNow,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionData extends StatelessWidget {
  const _QuestionData({required this.question});
  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final table = question.table;
    final bars = question.bars;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (table != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                for (final header in table.headers)
                  DataColumn(label: Text(header)),
              ],
              rows: [
                for (final row in table.rows)
                  DataRow(
                    cells: [for (final cell in row) DataCell(Text(cell))],
                  ),
              ],
            ),
          ),
        if (bars != null) ...[
          Text('${bars.title} (${bars.unit})'),
          const SizedBox(height: 8),
          for (var i = 0; i < bars.values.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 85, child: Text(bars.labels[i])),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor:
                            bars.values[i] /
                            bars.values.reduce((a, b) => a > b ? a : b),
                        child: Container(
                          height: 22,
                          color: context.luma.accent,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${bars.values[i]}',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (table != null || bars != null) const SizedBox(height: 16),
      ],
    );
  }
}

class _QuestionStrip extends StatelessWidget {
  const _QuestionStrip({
    required this.total,
    required this.current,
    required this.answers,
    required this.accent,
    required this.onGoTo,
  });

  final int total;
  final int current;
  final List<int?> answers;
  final Color accent;
  final ValueChanged<int> onGoTo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < total; i++)
          GestureDetector(
            onTap: () => onGoTo(i),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == current
                    ? accent
                    : answers[i] != null
                    ? accent.withValues(alpha: 0.16)
                    : luma.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: i == current ? accent : luma.border),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  color: i == current
                      ? luma.onAccent
                      : answers[i] != null
                      ? accent
                      : luma.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum _OptionState { plain, selected, correct, wrong }

class _OptionTile extends StatefulWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.state,
    required this.accent,
    this.onTap,
  });

  final String letter;
  final String text;
  final _OptionState state;
  final Color accent;
  final VoidCallback? onTap;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;

    final (Color border, Color fill, Color fg) = switch (widget.state) {
      _OptionState.plain => (
        luma.border,
        _hovering && widget.onTap != null ? luma.surfaceHover : luma.surface,
        luma.textPrimary,
      ),
      _OptionState.selected => (
        widget.accent,
        widget.accent.withValues(alpha: 0.12),
        luma.textPrimary,
      ),
      _OptionState.correct => (
        luma.success,
        luma.success.withValues(alpha: 0.14),
        luma.textPrimary,
      ),
      _OptionState.wrong => (
        luma.danger,
        luma.danger.withValues(alpha: 0.14),
        luma.textPrimary,
      ),
    };

    final trailing = switch (widget.state) {
      _OptionState.correct => Icon(
        Icons.check_rounded,
        color: luma.success,
        size: 18,
      ),
      _OptionState.wrong => Icon(
        Icons.close_rounded,
        color: luma.danger,
        size: 18,
      ),
      _ => null,
    };

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(decor.buttonRadius),
            border: Border.all(color: border, width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: border.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  widget.letter,
                  style: TextStyle(
                    color: border,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(color: fg, fontSize: 13.5, height: 1.35),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Review
// ---------------------------------------------------------------------------

class _ReviewView extends StatefulWidget {
  const _ReviewView({
    super.key,
    required this.result,
    required this.onRetry,
    required this.onPickOther,
  });

  final QuizResult result;
  final VoidCallback onRetry;
  final VoidCallback onPickOther;

  @override
  State<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<_ReviewView> {
  bool _onlyMistakes = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final r = widget.result;
    final tone = r.subject.color;

    final indices = [
      for (var i = 0; i < r.questions.length; i++)
        if (!_onlyMistakes || !r.isCorrect(i)) i,
    ];

    final narrow = context.isPhoneWidth;

    return SingleChildScrollView(
      padding: narrow
          ? const EdgeInsets.fromLTRB(14, 4, 14, 24)
          : const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LumaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(color: tone, width: 2),
                      ),
                      child: Text(
                        '${(r.fraction * 100).round()}%',
                        style: TextStyle(
                          color: tone,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.schoolTestsCorrectOf(r.correct, r.questions.length),
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.schoolTestsResultMeta(
                              r.subject.name,
                              _formatDuration(t, r.duration),
                              _perQuestion(t, r),
                              r.skipped,
                            ),
                            style: TextStyle(
                              color: luma.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  t.schoolTestsPerTopic,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                for (final entry in r.byTopic.entries) ...[
                  _TopicBar(
                    label: entry.key,
                    correct: entry.value.correct,
                    total: entry.value.total,
                    color: r.subject.color,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Wrap, not Row: the two labels are long, and on a narrow
          // phone they would run off the right edge side by side.
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              LumaPrimaryButton(
                label: t.schoolTestsNewTest,
                icon: Icons.refresh_rounded,
                onTap: widget.onRetry,
              ),
              LumaGhostButton(
                label: t.schoolTestsOtherSubject,
                icon: Icons.grid_view_rounded,
                onTap: widget.onPickOther,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.schoolTestsAnswers,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _LengthChip(
                label: _onlyMistakes
                    ? t.schoolTestsOnlyMistakes
                    : t.schoolTestsAllQuestions,
                selected: _onlyMistakes,
                enabled: true,
                onTap: () => setState(() => _onlyMistakes = !_onlyMistakes),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (indices.isEmpty)
            LumaEmptyState(
              icon: Icons.emoji_events_rounded,
              title: t.schoolTestsAllCorrect,
              subtitle: t.schoolTestsNoMistakes,
            )
          else
            for (final i in indices) ...[
              _ReviewCard(
                number: i + 1,
                question: r.questions[i],
                t: t,
                given: r.isAnswered(i) ? r.givenAnswer(i) : null,
                selected: r.questions[i].input == QuizInput.multiple
                    ? (r.multipleAnswers[i] ?? {})
                    : {if (r.answers[i] != null) r.answers[i]!},
                correct: r.isCorrect(i),
                accent: r.subject.color,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _TopicBar extends StatelessWidget {
  const _TopicBar({
    required this.label,
    required this.correct,
    required this.total,
    required this.color,
  });

  final String label;
  final int correct;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        SizedBox(
          width: 170,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: luma.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : correct / total,
              minHeight: 8,
              backgroundColor: luma.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            '$correct/$total',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.number,
    required this.question,
    required this.t,
    required this.given,
    required this.selected,
    required this.correct,
    required this.accent,
  });

  final int number;
  final QuizQuestion question;
  final L t;
  final String? given;
  final Set<int> selected;
  final bool correct;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final tone = correct ? luma.success : luma.danger;

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  correct ? Icons.check_rounded : Icons.close_rounded,
                  color: tone,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                t.schoolTestsQuestionNumber(number),
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _TopicPill(label: question.topic, color: accent),
            ],
          ),
          const SizedBox(height: 12),
          if (question.passage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: luma.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: luma.border),
              ),
              child: Text(
                question.passage!,
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            question.prompt,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _QuestionData(question: question),
          for (var i = 0; i < question.options.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            _OptionTile(
              letter: String.fromCharCode(65 + i),
              text: question.options[i],
              state:
                  (question.input == QuizInput.multiple
                      ? question.correctIndices.contains(i)
                      : i == question.answerIndex)
                  ? _OptionState.correct
                  : selected.contains(i)
                  ? _OptionState.wrong
                  : _OptionState.plain,
              accent: accent,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  given == null
                      ? t.schoolTestsSkippedThis
                      : correct
                      ? t.schoolTestsAnsweredCorrectly
                      : t.schoolTestsYourAnswerValue(given!),
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.schoolTestsCorrectAnswerValue(
                    '${question.answer}${question.unit == null ? '' : ' ${question.unit}'}',
                  ),
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (question.explanation != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    question.explanation!,
                    style: TextStyle(
                      color: luma.textSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The running clock in the test header.
///
/// It counts up from the moment the test was started and keeps ticking while
/// you page back and forth; the same span ends up on the result screen.
class _ElapsedTimer extends StatefulWidget {
  const _ElapsedTimer({required this.startedAt, required this.color});

  final DateTime startedAt;
  final Color color;

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  Timer? _ticker;
  late Duration _elapsed = DateTime.now().difference(widget.startedAt);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(widget.startedAt));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: widget.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: widget.color),
          const SizedBox(width: 6),
          Text(
            _formatClock(_elapsed),
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// `mm:ss`, or `h:mm:ss` once the hour is full.
String _formatClock(Duration d) {
  final seconds = d.inSeconds.clamp(0, 359999);
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h == 0 ? '$mm:$ss' : '$h:$mm:$ss';
}

/// Average time spent per question, for the line under the mark.
String _perQuestion(L t, QuizResult r) {
  if (r.questions.isEmpty) return t.schoolTestsDurationSec(0);
  final seconds = (r.duration.inSeconds / r.questions.length).round();
  return seconds >= 60
      ? t.schoolTestsDurationMinSec(seconds ~/ 60, seconds % 60)
      : t.schoolTestsDurationSec(seconds);
}

String _formatDuration(L t, Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  if (minutes == 0) return t.schoolTestsDurationSec(seconds);
  return t.schoolTestsDurationMinSec(minutes, seconds);
}
