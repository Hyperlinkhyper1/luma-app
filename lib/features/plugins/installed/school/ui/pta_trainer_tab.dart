import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../logic/pta/pta_binas.dart';
import '../logic/pta/pta_chemistry.dart';
import '../logic/pta/pta_lab.dart';
import '../logic/pta/pta_scenarios.dart';
import 'pta/pta_lab_view.dart';
import 'pta/pta_result_view.dart';

/// PTA trainer: practise the school exam "practicum kwalitatieve analyse" —
/// one jar, four candidate substances, a virtual lab to find out which.
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
  PtaSet? _set;
  PtaLab? _lab;
  Substance? _choice;

  Future<void> _start() async {
    final setup = await showDialog<(Level, bool)>(
      context: context,
      builder: (context) => const _SetupDialog(),
    );
    if (!mounted || setup == null) return;

    final (level, exam) = setup;
    final set = randomSet(level, _rng);
    final candidates = set.candidates;
    setState(() {
      _exam = exam;
      _set = set;
      _lab = PtaLab(candidates[_rng.nextInt(candidates.length)]);
      _choice = null;
      _phase = _Phase.lab;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (_phase) {
        _Phase.intro => _IntroView(onStart: _start),
        _Phase.lab => PtaLabView(
          key: ValueKey(_lab),
          lab: _lab!,
          set: _set!,
          exam: _exam,
          onHandIn: (c) => setState(() {
            _choice = c;
            _phase = _Phase.result;
          }),
          onQuit: () => setState(() => _phase = _Phase.intro),
        ),
        _Phase.result => PtaResultView(
          key: ValueKey('result-${_lab.hashCode}'),
          lab: _lab!,
          set: _set!,
          choice: _choice!,
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
  Level? _level;
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
                    onSelected: (_) => setState(() => _level = option),
                  ),
              ],
            ),
            const SizedBox(height: 12),
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
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.schoolPtaModeExam),
                  subtitle: Text(t.schoolPtaModeExamHint),
                  value: _exam,
                  onChanged: (exam) => setState(() => _exam = exam),
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
          onPressed: level == null
              ? null
              : () => Navigator.pop(context, (level, _exam)),
          child: Text(t.schoolPtaStart),
        ),
      ],
    );
  }
}
