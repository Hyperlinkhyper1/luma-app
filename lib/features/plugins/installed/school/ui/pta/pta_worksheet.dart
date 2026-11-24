import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../logic/pta/pta_attempt.dart';
import '../../logic/pta/pta_chemistry.dart';

Future<void> showPtaWorksheet(
  BuildContext context,
  PtaJarAttempt jar, {
  ValueNotifier<int>? examMinutes,
  bool review = false,
}) => showDialog<void>(
  context: context,
  builder: (context) => examMinutes == null
      ? _Worksheet(jar: jar, readOnly: review, review: review)
      : ValueListenableBuilder<int>(
          valueListenable: examMinutes,
          builder: (context, minutes, _) =>
              _Worksheet(jar: jar, readOnly: minutes == 0, review: false),
        ),
);

class _Worksheet extends StatefulWidget {
  const _Worksheet({
    required this.jar,
    required this.readOnly,
    required this.review,
  });

  final PtaJarAttempt jar;
  final bool readOnly;
  final bool review;

  @override
  State<_Worksheet> createState() => _WorksheetState();
}

class _WorksheetState extends State<_Worksheet> {
  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final jar = widget.jar;
    final candidates = jar.set.candidates;
    final readOnly = widget.readOnly;
    return AlertDialog(
      title: Text('${t.schoolPtaWorksheet} · ${jar.label}'),
      scrollable: true,
      content: SizedBox(
        width: 660,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (readOnly && !widget.review) Text(t.schoolPtaTimeUp),
            Text(t.schoolPtaFormulaHint),
            const SizedBox(height: 8),
            for (final c in candidates)
              _field(
                c.name,
                jar.formulas[c.id],
                (value) => jar.formulas[c.id] = value,
                helper: widget.review ? c.notation : null,
              ),
            if (jar.lab.log.isNotEmpty && !widget.review)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(t.schoolPtaLog),
                children: [
                  for (final entry in jar.lab.log)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.action),
                      subtitle: Text(entry.observations.join('\n')),
                    ),
                ],
              ),
            for (final (index, step) in jar.steps.indexed)
              Padding(
                key: ObjectKey(step),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${t.schoolPtaTest} ${index + 1}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (!readOnly && jar.steps.length > 1)
                          IconButton(
                            tooltip: t.schoolPtaRemoveStep,
                            onPressed: () =>
                                setState(() => jar.steps.remove(step)),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                      ],
                    ),
                    _field(
                      t.schoolPtaAction,
                      step.action,
                      (v) => step.action = v,
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(t.schoolPtaPrediction),
                      initiallyExpanded: step.predictions.values.any(
                        (v) => v.isNotEmpty,
                      ),
                      children: [
                        for (final c in candidates)
                          _field(
                            c.name,
                            step.predictions[c.id],
                            (v) => step.predictions[c.id] = v,
                            lines: 2,
                          ),
                      ],
                    ),
                    _field(
                      t.schoolPtaObservation,
                      step.observation,
                      (v) => step.observation = v,
                      lines: 2,
                    ),
                    _field(
                      t.schoolPtaDeduction,
                      step.deduction,
                      (v) => step.deduction = v,
                      lines: 2,
                    ),
                    _field(
                      t.schoolPtaEquation,
                      step.equation,
                      (v) => step.equation = v,
                      lines: 2,
                    ),
                  ],
                ),
              ),
            if (!readOnly)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => jar.steps.add(PtaWorksheetStep())),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(t.schoolPtaAddStep),
                ),
              ),
            const Divider(),
            const SizedBox(height: 8),
            DropdownButtonFormField<Substance>(
              initialValue: jar.choice,
              isExpanded: true,
              decoration: InputDecoration(labelText: t.schoolPtaChooseTitle),
              disabledHint: Text(jar.choice?.name ?? t.schoolPtaNoAnswer),
              items: [
                for (final c in candidates)
                  DropdownMenuItem(value: c, child: Text(c.name)),
              ],
              onChanged: readOnly
                  ? null
                  : (choice) {
                      if (!widget.readOnly) jar.choice = choice;
                    },
            ),
            const SizedBox(height: 10),
            _field(
              t.schoolPtaConclusion,
              jar.conclusion,
              (v) => jar.conclusion = v,
              lines: 2,
            ),
            _field(
              t.schoolPtaConfirmTest,
              jar.confirmation,
              (v) => jar.confirmation = v,
              lines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    String? value,
    ValueChanged<String> onChanged, {
    String? helper,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      initialValue: value,
      readOnly: widget.readOnly,
      minLines: 1,
      maxLines: lines,
      decoration: InputDecoration(labelText: label, helperText: helper),
      onChanged: (value) {
        if (!widget.readOnly) onChanged(value);
      },
    ),
  );
}
