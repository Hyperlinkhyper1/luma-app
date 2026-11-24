import 'package:flutter/material.dart';

import '../../../../../../app/widgets.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../theme/luma_theme.dart';
import '../../logic/pta/pta_attempt.dart';
import '../../logic/pta/pta_chemistry.dart';
import '../../logic/pta/pta_scenarios.dart';
import 'pta_worksheet.dart';

/// After handing in: right or wrong, what every candidate would have shown
/// in each standard test, and the reactions the student actually saw.
class PtaResultView extends StatefulWidget {
  const PtaResultView({super.key, required this.jars, required this.onNew});

  final List<PtaJarAttempt> jars;
  final VoidCallback onNew;

  @override
  State<PtaResultView> createState() => _PtaResultViewState();
}

class _PtaResultViewState extends State<PtaResultView> {
  int _selected = 0;
  final _tables = <PtaSet, List<(String, List<String>)>>{};

  List<(String, String)> _reactions(PtaJarAttempt jar) {
    final seen = <String>{};
    final out = <(String, String)>[];
    for (final e in jar.lab.log) {
      for (final (note, eq) in e.reactions) {
        if (seen.add(eq)) out.add((note, eq));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final jar = widget.jars[_selected];
    final unknown = jar.lab.unknown;
    final correct = jar.correct;
    final choice = jar.choice;
    final candidates = jar.set.candidates;
    final reactions = _reactions(jar);
    final table = _tables.putIfAbsent(jar.set, () => expectedTable(candidates));
    final score = widget.jars.where((jar) => jar.correct).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        if (widget.jars.length > 1) ...[
          Text(
            '$score / ${widget.jars.length} · ${t.schoolPtaCorrectJars}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (index, attempt) in widget.jars.indexed)
                ChoiceChip(
                  label: Text(attempt.label),
                  selected: index == _selected,
                  onSelected: (_) => setState(() => _selected = index),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        LumaCard(
          child: Row(
            children: [
              LumaIconBadge(
                icon: correct ? Icons.check_rounded : Icons.close_rounded,
                color: correct ? luma.success : luma.danger,
                size: 52,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${jar.label} · ${choice == null
                          ? t.schoolPtaNoAnswer
                          : correct
                          ? t.schoolPtaCorrect
                          : t.schoolPtaWrong}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (widget.jars.length > 1)
                      Text(
                        jar.set.title,
                        style: TextStyle(color: luma.textSecondary),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      t.schoolPtaItWas('${unknown.name} · ${unknown.notation}'),
                      style: TextStyle(color: luma.textPrimary),
                    ),
                    if (choice != null && !correct)
                      Text(
                        t.schoolPtaYouChose(
                          '${choice.name} · ${choice.notation}',
                        ),
                        style: TextStyle(color: luma.textSecondary),
                      ),
                    if (widget.jars.length == 1) ...[
                      const SizedBox(height: 4),
                      Text(
                        t.schoolPtaStats(jar.lab.actions, jar.lab.minutes),
                        style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            IntrinsicWidth(
              child: LumaPrimaryButton(
                label: t.schoolPtaNewPractical,
                icon: Icons.add_rounded,
                onTap: widget.onNew,
              ),
            ),
            LumaGhostButton(
              label: t.schoolPtaWorksheet,
              icon: Icons.edit_note_rounded,
              onTap: () => showPtaWorksheet(context, jar, review: true),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.schoolPtaExpected,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                t.schoolPtaExpectedHint,
                style: TextStyle(color: luma.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  columnWidths: {
                    0: const FixedColumnWidth(190),
                    for (var c = 1; c <= candidates.length; c++)
                      c: const FixedColumnWidth(250),
                  },
                  border: TableBorder.all(color: luma.border, width: 0.8),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: luma.surfaceHover),
                      children: [
                        _cell(t.schoolPtaTest, luma, header: true),
                        for (final c in candidates)
                          Container(
                            color: c.id == unknown.id
                                ? luma.accent.withValues(alpha: 0.16)
                                : null,
                            child: _cell(
                              '${c.name}\n${c.formula}',
                              luma,
                              header: true,
                            ),
                          ),
                      ],
                    ),
                    for (final (title, cells) in table)
                      _row(title, cells, candidates, unknown, luma),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.schoolPtaReactions,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              if (reactions.isEmpty)
                Text(
                  t.schoolPtaNoReactions,
                  style: TextStyle(color: luma.textMuted),
                )
              else
                for (final (note, eq) in reactions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eq,
                          style: TextStyle(
                            color: luma.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (note.isNotEmpty)
                          Text(
                            note,
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
        ),
      ],
    );
  }

  TableRow _row(
    String title,
    List<String> cells,
    List<Substance> candidates,
    Substance unknown,
    LumaPalette luma,
  ) {
    final distinct = cells.toSet().length > 1;
    return TableRow(
      children: [
        Container(
          decoration: BoxDecoration(
            border: distinct
                ? Border(left: BorderSide(color: luma.accent, width: 4))
                : null,
          ),
          child: _cell(title, luma, header: distinct),
        ),
        for (var c = 0; c < cells.length; c++)
          Container(
            color: candidates[c].id == unknown.id
                ? luma.accent.withValues(alpha: 0.07)
                : null,
            child: _cell(cells[c], luma),
          ),
      ],
    );
  }

  Widget _cell(String text, LumaPalette luma, {bool header = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    child: Text(
      text,
      style: TextStyle(
        color: header ? luma.textPrimary : luma.textSecondary,
        fontWeight: header ? FontWeight.w600 : FontWeight.w400,
        fontSize: 12.5,
        height: 1.3,
      ),
    ),
  );
}
