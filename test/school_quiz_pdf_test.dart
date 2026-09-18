import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:luma/features/plugins/installed/school/logic/quiz_bank.dart';
import 'package:luma/features/plugins/installed/school/logic/quiz_export.dart';
import 'package:luma/features/plugins/installed/school/logic/quiz_pdf.dart';

void main() {
  test('PDF renderer runs in an isolate', () async {
    final export = prepareQuizExport(
      counts: {'rekenen': 1, 'lezen': 1, 'taalverzorging': 1},
    );
    final bytes = await compute(
      renderQuizPdf,
      export,
    ).timeout(const Duration(seconds: 10));
    expect(bytes, isNotEmpty);
  });
  test(
    'total distribution uses all requested questions and respects capacity',
    () {
      final subjects = [QuizBank.byId('lezen')!, QuizBank.byId('rekenen')!];
      expect(distributeQuizQuestions(subjects, 31), {
        'lezen': 16,
        'rekenen': 15,
      });
      expect(distributeQuizQuestions(subjects, 200), {
        'lezen': 65,
        'rekenen': 135,
      });
      expect(() => distributeQuizQuestions([], 10), throwsArgumentError);
      expect(() => distributeQuizQuestions(subjects, 1), throwsArgumentError);
      expect(() => distributeQuizQuestions(subjects, 500), throwsArgumentError);
    },
  );
  test(
    'custom allocation is exact, unique and keeps reading blocks intact',
    () {
      for (final mixed in [true, false]) {
        final export = prepareQuizExport(
          counts: {'rekenen': 17, 'lezen': 12, 'taalverzorging': 9},
          mixed: mixed,
          seed: 19,
        );
        expect(export.count, 38);
        final seen = <String>{};
        final passages = <String>{};
        final counts = <String, int>{};
        for (final block in export.blocks) {
          counts.update(
            block.subject.id,
            (n) => n + block.questions.length,
            ifAbsent: () => block.questions.length,
          );
          for (final q in block.questions) {
            expect(seen.add(q.id), isTrue);
          }
          if (block.questions.first.passage != null) {
            expect(passages.add(block.questions.first.passage!), isTrue);
            expect(block.questions.map((q) => q.passage).toSet(), hasLength(1));
          }
        }
        expect(counts, {'rekenen': 17, 'lezen': 12, 'taalverzorging': 9});
      }
      expect(
        () => prepareQuizExport(counts: {'lezen': 66}),
        throwsArgumentError,
      );
      expect(
        () => prepareQuizExport(counts: {'rekenen': 0}),
        throwsArgumentError,
      );
      expect(
        () => prepareQuizExport(counts: {'unknown': 1}),
        throwsArgumentError,
      );
    },
  );
  test(
    'PDF includes all question types and a separate answer section',
    () async {
      final math = QuizBank.byId('rekenen')!;
      final language = QuizBank.byId('taalverzorging')!;
      final reading = QuizBank.byId('lezen')!;
      final export = QuizExport(
        title: 'Oefentoets groep 8',
        mixed: false,
        answers: true,
        explanations: true,
        writingSpace: true,
        blocks: [
          QuizExportBlock(math, [
            math.questions.firstWhere((q) => q.table != null),
            math.questions.firstWhere((q) => q.bars != null),
            math.questions.firstWhere((q) => q.id.startsWith('iep-r-schaal-')),
            math.questions.firstWhere((q) => q.id.startsWith('iep-r-doos-')),
          ]),
          QuizExportBlock(language, language.questions.take(3).toList()),
          QuizExportBlock(
            reading,
            reading.questions
                .where((q) => q.passage == reading.questions.last.passage)
                .toList(),
          ),
        ],
      );
      final bytes = await renderQuizPdf(export);
      final pdf = PdfDocument(inputBytes: bytes);
      final content = PdfTextExtractor(pdf).extractText();
      expect(content, contains('Vraag 16'));
      expect(content, contains('Antwoorden'));
      expect(content, contains('Bezoekers van het zwembad'));
      expect(content, contains('Tekst 1'));
      expect(content, contains('maandag'));
      expect(content, contains('A + B.'));
      var answerPage = -1;
      for (var i = 0; i < pdf.pages.count; i++) {
        final page = PdfTextExtractor(
          pdf,
        ).extractText(startPageIndex: i, endPageIndex: i);
        if (page.contains('Antwoordblad')) {
          answerPage = i;
          break;
        }
      }
      expect(answerPage, greaterThan(0));
      pdf.dispose();
      const sample = String.fromEnvironment('QUIZ_PDF_SAMPLE');
      if (sample.isNotEmpty) {
        final file = File(sample);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
      }
    },
  );
  test(
    'student PDF never includes explanations or correct answer labels',
    () async {
      final export = prepareQuizExport(
        counts: {'taalverzorging': 3},
        answers: false,
        seed: 4,
      );
      final pdf = PdfDocument(inputBytes: await renderQuizPdf(export));
      final content = PdfTextExtractor(pdf).extractText();
      expect(content, isNot(contains('Antwoordblad')));
      for (final b in export.blocks) {
        for (final q in b.questions) {
          expect(content, isNot(contains(q.explanation!)));
        }
      }
      pdf.dispose();
    },
  );
}
