import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
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
    Map<String, int>? counts;
    String? validation;
    try {
      counts = allocation();
    } on ArgumentError catch (e) {
      validation = '${e.message}';
    }
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Oefentoets als PDF')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Stel je oefentoets samen',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kies één of meer vakken. De PDF bevat een nieuwe selectie zonder dubbele vragen, op A4-formaat.',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _title,
                    enabled: !_busy,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Titel op de PDF',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Totaal verdelen'),
                        selected: !_custom,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _custom = false),
                      ),
                      ChoiceChip(
                        label: const Text('Aantal per vak'),
                        selected: _custom,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _custom = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_custom)
                    TextFormField(
                      initialValue: _total,
                      enabled: !_busy,
                      key: const ValueKey('pdf-total'),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Totaal aantal vragen',
                        helperText:
                            'Maximaal 500; zo gelijk mogelijk verdeeld.',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() => _total = value),
                    ),
                  const SizedBox(height: 20),
                  for (final group in [
                    QuizBank.doorstroomSubjects,
                    QuizBank.extraSubjects,
                  ]) ...[
                    Text(
                      group.first.isDoorstroom
                          ? 'Doorstroomtoets'
                          : 'Andere vakken (extra oefening)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final s in group)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(s.name),
                              subtitle: Text(
                                '${s.questions.length} beschikbaar${counts == null || !_selected.contains(s.id) ? '' : ' · ${counts[s.id]} in de PDF'}',
                              ),
                              value: _selected.contains(s.id),
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(() {
                                      if (value == true) {
                                        _selected.add(s.id);
                                      } else {
                                        _selected.remove(s.id);
                                      }
                                    }),
                            ),
                            if (_custom && _selected.contains(s.id))
                              TextFormField(
                                key: ValueKey('pdf-count-${s.id}'),
                                initialValue: _counts[s.id],
                                enabled: !_busy,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Aantal vragen ${s.name}',
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (value) =>
                                    setState(() => _counts[s.id] = value),
                              ),
                          ],
                        ),
                      ),
                  ],
                  const Divider(height: 32),
                  const Text(
                    'Volgorde',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Per vak'),
                        selected: !_mixed,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _mixed = false),
                      ),
                      ChoiceChip(
                        label: const Text('Gemengd'),
                        selected: _mixed,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _mixed = true),
                      ),
                    ],
                  ),
                  const Text(
                    'Vragen bij dezelfde leestekst blijven bij elkaar. Bij “Per vak” begint ieder volgend vak op een nieuwe pagina.',
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Extra schrijfruimte'),
                    value: _writing,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _writing = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Antwoordblad toevoegen'),
                    subtitle: const Text(
                      'Begint op een nieuwe pagina achter de opgaven.',
                    ),
                    value: _answers,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _answers = v),
                  ),
                  if (_answers)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Uitleg bij de antwoorden'),
                      value: _explanations,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _explanations = v),
                    ),
                  const SizedBox(height: 16),
                  if (counts != null)
                    Text(
                      '${counts.values.fold(0, (sum, n) => sum + n)} vragen · ${counts.length} vakken · ${_mixed ? 'gemengd' : 'per vak'}',
                    ),
                  if (validation != null || _error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        validation ?? _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy || validation != null ? null : exportPdf,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
