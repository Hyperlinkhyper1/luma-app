import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../logic/pta/pta_attempt.dart';
import '../logic/pta/pta_binas.dart';
import '../logic/pta/pta_chemistry.dart';
import '../logic/pta/pta_scenarios.dart';
import 'pta/pta_lab_view.dart';
import 'pta/pta_result_view.dart';
import 'pta/pta_worksheet.dart';

/// The qualitative-analysis practicum from setup through submission.
class PtaTrainerTab extends StatefulWidget {
  const PtaTrainerTab({super.key, this.random});

  /// Seedable for tests.
  final math.Random? random;

  @override
  State<PtaTrainerTab> createState() => _PtaTrainerTabState();
}

enum _Phase { intro, lab, result }

class _PtaTrainerTabState extends State<PtaTrainerTab> {
  late final math.Random _rng = widget.random ?? math.Random();
  _Phase _phase = _Phase.intro;
  bool _exam = false;
  final _minutes = ValueNotifier(kExamMinutes);
  Timer? _timer;
  List<PtaJarAttempt> _jars = [];
  int _selected = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final setup = await showDialog<(Level, bool, PtaSet?)>(
      context: context,
      builder: (context) => const _SetupDialog(),
    );
    if (!mounted || setup == null) return;

    final (level, exam, selectedSet) = setup;
    final sets = exam
        ? examSets(level, _rng)
        : [
            selectedSet ??
                (level == Level.havo
                    ? havoBookletSets[_rng.nextInt(havoBookletSets.length)]
                    : randomSet(level, _rng)),
          ];
    _minutes.value = kExamMinutes;
    if (exam) {
      _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
        _minutes.value = math.max(0, kExamMinutes - timer.tick);
        if (_minutes.value == 0) timer.cancel();
      });
    }
    setState(() {
      _exam = exam;
      _jars = [
        for (final (index, set) in sets.indexed)
          PtaJarAttempt('A${index + 1}', set, _rng),
      ];
      _selected = 0;
      _phase = _Phase.lab;
    });
  }

  void _quit() {
    _timer?.cancel();
    setState(() => _phase = _Phase.intro);
  }

  Future<void> _openWorksheet(PtaJarAttempt jar) async {
    await showPtaWorksheet(context, jar, examMinutes: _exam ? _minutes : null);
    if (mounted) setState(() {});
  }

  Future<void> _handIn() async {
    if (!_exam && _jars.single.choice == null) {
      await _openWorksheet(_jars.single);
      if (!mounted || _jars.single.choice == null) return;
    }
    final t = L.of(context);
    final answered = _jars.where((jar) => jar.choice != null).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.schoolPtaHandIn),
        content: Text(
          '${t.schoolPtaHandInPrompt}\n\n$answered / ${_jars.length} · ${t.schoolPtaAnswered}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.schoolPtaConfirm),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    _timer?.cancel();
    setState(() => _phase = _Phase.result);
  }

  Widget _bench() {
    final jar = _jars[_selected];
    final t = L.of(context);
    return ValueListenableBuilder<int>(
      key: ObjectKey(_jars),
      valueListenable: _minutes,
      builder: (context, remaining, _) => PtaLabView(
        key: ObjectKey(jar),
        lab: jar.lab,
        set: jar.set,
        jarLabel: jar.label,
        examMinutes: _exam ? remaining : null,
        jars: _jars.length == 1
            ? const SizedBox.shrink()
            : Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final (index, attempt) in _jars.indexed)
                    ChoiceChip(
                      label: Text('${t.schoolPtaJar} ${attempt.label}'),
                      selected: index == _selected,
                      avatar: attempt.choice != null
                          ? const Icon(Icons.edit_note_rounded, size: 18)
                          : null,
                      onSelected: (_) => setState(() => _selected = index),
                    ),
                ],
              ),
        onWorksheet: () => _openWorksheet(jar),
        onHandIn: _handIn,
        onQuit: _quit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (_phase) {
        _Phase.intro => _IntroView(onStart: _start),
        _Phase.lab => _bench(),
        _Phase.result => PtaResultView(
          key: ObjectKey(_jars),
          jars: _jars,
          onNew: _start,
        ),
      },
    );
  }
}

class _IntroView extends StatelessWidget {
  const _IntroView({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        LumaCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LumaIconBadge(
                icon: Icons.science_rounded,
                color: luma.accent,
                size: 48,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.schoolPtaTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.schoolPtaIntro,
                      style: TextStyle(color: luma.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: IntrinsicWidth(
            child: LumaPrimaryButton(
              label: t.schoolPtaStart,
              icon: Icons.play_arrow_rounded,
              onTap: onStart,
            ),
          ),
        ),
      ],
    );
  }
}

class _SetupDialog extends StatefulWidget {
  const _SetupDialog();

  @override
  State<_SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<_SetupDialog> {
  late final _sheets = binasSheets();
  Level _level = Level.havo;
  PtaSet? _set;
  bool _exam = false;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final level = _level;
    return AlertDialog(
      title: Text(t.schoolPtaTitle),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.schoolPtaLevel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (option, label) in [
                  (Level.havo, t.schoolPtaHavo),
                  (Level.vwo, t.schoolPtaVwo),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: level == option,
                    onSelected: (_) => setState(() {
                      _level = option;
                      _set = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.schoolPtaModeExam),
              subtitle: Text(t.schoolPtaModeExamHint),
              value: _exam,
              onChanged: (exam) => setState(() => _exam = exam),
            ),
            if (!_exam && level == Level.havo)
              DropdownButtonFormField<PtaSet>(
                initialValue: _set,
                isExpanded: true,
                decoration: InputDecoration(labelText: t.schoolPtaSet),
                hint: Text(t.schoolPtaRandomSet),
                items: [
                  DropdownMenuItem(child: Text(t.schoolPtaRandomSet)),
                  for (final set in havoBookletSets)
                    DropdownMenuItem(value: set, child: Text(set.title)),
                ],
                onChanged: (set) => _set = set,
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(t.schoolPtaAdvancedSettings),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.schoolPtaBinas,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                for (final sheet in _sheets)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('${sheet.code} · ${sheet.title}'),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (level, _exam, _set)),
          child: Text(t.schoolPtaStart),
        ),
      ],
    );
  }
}
