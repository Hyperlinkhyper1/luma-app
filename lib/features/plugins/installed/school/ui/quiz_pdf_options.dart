import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../logic/quiz_bank.dart';
import '../logic/quiz_export.dart';
import '../logic/quiz_pdf.dart';
import '../logic/quiz_pdf_saver.dart';

class QuizPdfOptions extends StatefulWidget {
  const QuizPdfOptions({super.key, this.save = saveQuizPdf});
  final Future<String?> Function(Uint8List) save;
  @override
  State<QuizPdfOptions> createState() => _QuizPdfOptionsState();
}

class _QuizPdfOptionsState extends State<QuizPdfOptions> {
  final _selected = {'rekenen', 'taalverzorging', 'lezen'};
  final _counts = {for (final s in QuizBank.subjects) s.id: '10'};
  final _title = TextEditingController(text: 'Oefentoets groep 8');
  String _total = '30';
  bool _custom = false;
  bool _mixed = false;
  bool _answers = false;
  bool _explanations = true;
  bool _writing = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Map<String, int> allocation() {
    final subjects = QuizBank.subjects
        .where((s) => _selected.contains(s.id))
        .toList();
    if (!_custom) {
      return distributeQuizQuestions(subjects, int.tryParse(_total) ?? 0);
    }
    if (subjects.isEmpty) throw ArgumentError('Kies minstens één vak.');
    final counts = <String, int>{};
    for (final s in subjects) {
      final n = int.tryParse(_counts[s.id] ?? '') ?? 0;
      if (n < 1 || n > s.questions.length) {
        throw ArgumentError(
          'Kies voor ${s.name} tussen 1 en ${s.questions.length} vragen.',
        );
      }
      counts[s.id] = n;
    }
    if (counts.values.fold(0, (sum, n) => sum + n) > maxQuizExportQuestions) {
      throw ArgumentError(
        'Kies maximaal $maxQuizExportQuestions vragen per PDF.',
      );
    }
    return counts;
  }

  Future<void> exportPdf() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final request = prepareQuizExport(
        counts: allocation(),
        title: _title.text,
        mixed: _mixed,
        answers: _answers,
        explanations: _explanations,
        writingSpace: _writing,
      );
      final bytes = await compute(renderQuizPdf, request);
      if (!mounted) return;
      final path = await widget.save(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path == null ? 'Opslaan geannuleerd.' : 'PDF opgeslagen: $path',
          ),
          action: path == null
              ? null
              : SnackBarAction(
                  label: 'Openen',
                  onPressed: () => OpenFile.open(path),
                ),
        ),
      );
    } catch (error, stack) {
      debugPrint('PDF export failed: $error\n$stack');
      if (mounted) {
        setState(
          () => _error = error is ArgumentError
              ? '${error.message}'
              : 'De PDF kon niet worden opgeslagen. Probeer het opnieuw.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    Map<String, int>? counts;
    String? validation;
    try {
      counts = allocation();
    } on ArgumentError catch (e) {
      validation = '${e.message}';
    }
    final total = counts?.values.fold<int>(0, (sum, n) => sum + n) ?? 0;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Oefentoets als PDF')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LumaCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LumaIconBadge(
                          icon: Icons.picture_as_pdf_rounded,
                          color: luma.accent,
                          size: 44,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stel je oefentoets samen',
                                style: TextStyle(
                                  color: luma.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kies één of meer vakken. De PDF bevat een '
                                'nieuwe selectie zonder dubbele vragen, op '
                                'A4-formaat.',
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
                  const SizedBox(height: 16),
                  LumaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('Titel & indeling'),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _title,
                          enabled: !_busy,
                          maxLength: 80,
                          style: TextStyle(color: luma.textPrimary),
                          decoration: _pdfFieldDecoration(
                            luma,
                            label: 'Titel op de PDF',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _PillChoice(
                              label: 'Totaal verdelen',
                              selected: !_custom,
                              onTap: _busy
                                  ? null
                                  : () => setState(() => _custom = false),
                            ),
                            _PillChoice(
                              label: 'Aantal per vak',
                              selected: _custom,
                              onTap: _busy
                                  ? null
                                  : () => setState(() => _custom = true),
                            ),
                          ],
                        ),
                        if (!_custom) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            initialValue: _total,
                            enabled: !_busy,
                            key: const ValueKey('pdf-total'),
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: luma.textPrimary),
                            decoration: _pdfFieldDecoration(
                              luma,
                              label: 'Totaal aantal vragen',
                              hint:
                                  'Maximaal 500; zo gelijk mogelijk verdeeld.',
                            ),
                            onChanged: (value) =>
                                setState(() => _total = value),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final group in [
                    QuizBank.doorstroomSubjects,
                    QuizBank.extraSubjects,
                  ]) ...[
                    LumaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(
                            group.first.isDoorstroom
                                ? 'Doorstroomtoets'
                                : 'Andere vakken · extra oefening',
                          ),
                          const SizedBox(height: 6),
                          for (var i = 0; i < group.length; i++) ...[
                            if (i > 0)
                              Divider(color: luma.border, height: 12),
                            _SubjectRow(
                              subject: group[i],
                              selected: _selected.contains(group[i].id),
                              busy: _busy,
                              onToggle: () => setState(() {
                                if (_selected.contains(group[i].id)) {
                                  _selected.remove(group[i].id);
                                } else {
                                  _selected.add(group[i].id);
                                }
                              }),
                              showCountField:
                                  _custom && _selected.contains(group[i].id),
                              countText: _counts[group[i].id] ?? '',
                              onCountChanged: (value) => setState(
                                () => _counts[group[i].id] = value,
                              ),
                              countInPdf:
                                  counts == null ||
                                      !_selected.contains(group[i].id)
                                  ? null
                                  : counts[group[i].id],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  LumaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('Volgorde'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _PillChoice(
                              label: 'Per vak',
                              selected: !_mixed,
                              onTap: _busy
                                  ? null
                                  : () => setState(() => _mixed = false),
                            ),
                            _PillChoice(
                              label: 'Gemengd',
                              selected: _mixed,
                              onTap: _busy
                                  ? null
                                  : () => setState(() => _mixed = true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Vragen bij dezelfde leestekst blijven bij elkaar. '
                          'Bij "Per vak" begint ieder volgend vak op een '
                          'nieuwe pagina.',
                          style: TextStyle(
                            color: luma.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Divider(color: luma.border, height: 28),
                        _ToggleRow(
                          title: 'Extra schrijfruimte',
                          value: _writing,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _writing = v),
                        ),
                        Divider(color: luma.border, height: 24),
                        _ToggleRow(
                          title: 'Antwoordblad toevoegen',
                          subtitle:
                              'Begint op een nieuwe pagina achter de opgaven.',
                          value: _answers,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _answers = v),
                        ),
                        if (_answers) ...[
                          Divider(color: luma.border, height: 24),
                          _ToggleRow(
                            title: 'Uitleg bij de antwoorden',
                            value: _explanations,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _explanations = v),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (counts != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: luma.accentSubtle,
                        borderRadius: decor.pillBorderRadius,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.summarize_rounded,
                            size: 16,
                            color: luma.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$total vragen · ${counts.length} vakken · '
                              '${_mixed ? 'gemengd' : 'per vak'}',
                              style: TextStyle(
                                color: luma.accent,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (validation != null || _error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: luma.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            decor.cardRadius / 1.6,
                          ),
                          border: Border.all(
                            color: luma.danger.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: luma.danger,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                validation ?? _error!,
                                style: TextStyle(
                                  color: luma.danger,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: luma.accent,
                      foregroundColor: luma.onAccent,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: decor.buttonBorderRadius,
                      ),
                    ),
                    onPressed: _busy || validation != null ? null : exportPdf,
                    icon: _busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                luma.onAccent,
                              ),
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(_busy ? 'PDF maken…' : 'PDF maken en opslaan'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _pdfFieldDecoration(
  LumaPalette luma, {
  String? label,
  String? hint,
}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    isDense: true,
    labelText: label,
    labelStyle: TextStyle(color: luma.textSecondary),
    helperText: hint,
    helperMaxLines: 2,
    filled: true,
    fillColor: luma.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: border(luma.border),
    focusedBorder: border(luma.accent),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.luma.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Pill-shaped choice used for the mode/order toggles.
class _PillChoice extends StatelessWidget {
  const _PillChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    return MouseRegion(
      cursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : luma.surface,
            borderRadius: decor.pillBorderRadius,
            border: Border.all(
              color: selected ? luma.accent : luma.border,
              width: decor.borderWidth,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? luma.accent : luma.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Title + description with a trailing switch, matching Settings' toggle rows.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: luma.onAccent,
          activeTrackColor: luma.accent,
          inactiveThumbColor: luma.textSecondary,
          inactiveTrackColor: luma.surfaceHover,
        ),
      ],
    );
  }
}

/// One selectable subject: icon badge in the subject's color, name, how many
/// questions are available/allocated, and a checkbox-style indicator. Shows
/// an inline count field underneath when the export uses "Aantal per vak".
class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.selected,
    required this.busy,
    required this.onToggle,
    required this.showCountField,
    required this.countText,
    required this.onCountChanged,
    required this.countInPdf,
  });

  final QuizSubject subject;
  final bool selected;
  final bool busy;
  final VoidCallback onToggle;
  final bool showCountField;
  final String countText;
  final ValueChanged<String> onCountChanged;
  final int? countInPdf;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final onBadge = subject.color.computeLuminance() > 0.55
        ? const Color(0xFF1A1526)
        : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: busy ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: GestureDetector(
            onTap: busy ? null : onToggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  LumaIconBadge(
                    icon: subject.icon,
                    color: subject.color,
                    size: 38,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${subject.questions.length} beschikbaar'
                          '${countInPdf == null ? '' : ' · $countInPdf in de PDF'}',
                          style: TextStyle(
                            color: luma.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? subject.color : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: selected ? subject.color : luma.border,
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? Icon(Icons.check_rounded, size: 16, color: onBadge)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showCountField)
          Padding(
            padding: const EdgeInsets.only(left: 50, bottom: 10),
            child: SizedBox(
              width: 140,
              child: TextFormField(
                key: ValueKey('pdf-count-${subject.id}'),
                initialValue: countText,
                enabled: !busy,
                keyboardType: TextInputType.number,
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
                decoration: _pdfFieldDecoration(
                  luma,
                  label: 'Aantal vragen ${subject.name}',
                ),
                onChanged: onCountChanged,
              ),
            ),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }
}
