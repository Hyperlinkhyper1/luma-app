import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/ai_detector/ai_detector_engine.dart';

/// Deliberately human-ish: wildly varied sentence lengths, contractions, a
/// typo-level informality, no stock phrases.
const _humanText =
    'Honestly? I did not expect any of this. The market moved overnight '
    "and by morning half our orders were wrong \u2014 wrong item, wrong address, "
    'wrong everything. We fixed what we could. Rita stayed late re-picking '
    'the worst ones, which helped more than any plan I wrote. Some customers '
    'wrote back angry; a few sent photos of the mangled boxes, which somehow '
    "made it funnier. It's fine now, mostly. Don't ask about the refund queue "
    "though. That's still a mess, and honestly I think it will stay one until "
    'Friday at the earliest, maybe longer if the warehouse keeps losing '
    "pallets the way it has been all week. Anyway. We're getting there. Sam "
    "swears it's the courier's fault, and maybe it is, but chasing them about "
    'it costs more than the boxes are worth.';

/// Deliberately AI-ish: uniform sentences, connective openers, buzzwords,
/// zero contractions, tidy paragraphs.
const _aiText = '''
In today's fast-paced world, effective communication plays a crucial role in
achieving organizational success. Furthermore, it is important to note that
teams must navigate the complexities of modern collaboration seamlessly.
Moreover, a holistic approach to productivity can unlock the potential of
every member of the workforce.

Additionally, leaders should harness the power of technology to streamline
processes across the ever-evolving landscape of business. Consequently,
organizations that leverage robust frameworks will remain competitive in the
market. Ultimately, embracing innovation paves the way for sustainable growth.

In conclusion, fostering a culture of collaboration serves as a testament to
an organization's commitment to excellence. Furthermore, meticulous attention
to detail underscores the importance of continuous improvement in the realm
of professional development.
''';

void main() {
  group('AiDetectorEngine', () {
    test('AI-styled text scores clearly above human-styled text', () {
      final aiScore = AiDetectorEngine.analyze(_aiText).score;
      final humanScore = AiDetectorEngine.analyze(_humanText).score;
      expect(aiScore, greaterThan(55));
      expect(humanScore, lessThan(35));
      expect(aiScore - humanScore, greaterThan(30));
    });

    test('the phrase check cites its exact matches as evidence', () {
      final report = AiDetectorEngine.analyze(_aiText);
      final phrases = report.triggers.firstWhere((t) => t.id == 'phrases');
      expect(phrases.fired, isTrue);
      expect(
        phrases.evidence.any((e) => e.contains('plays a crucial role')),
        isTrue,
      );
    });

    test('human text fires no strong signals', () {
      final report = AiDetectorEngine.analyze(_humanText);
      expect(report.triggers.where((t) => t.fired), isEmpty);
      expect(report.verdict, contains('human'));
    });

    test('empty input produces a clean zero report', () {
      final report = AiDetectorEngine.analyze('');
      expect(report.score, 0);
      expect(report.wordCount, 0);
      expect(report.triggers, isEmpty);
      expect(report.reliable, isFalse);
    });

    test('very short text is flagged unreliable but still analysed', () {
      final report = AiDetectorEngine.analyze(
          'Just a tiny sample here, barely enough words for anything.');
      expect(report.wordCount, lessThan(60));
      expect(report.reliable, isFalse);
      // Checks without enough data must not fire.
      for (final t in report.triggers) {
        if (t.detail.startsWith('Needs')) expect(t.strength, 0);
      }
    });

    test('score stays within bounds regardless of input', () {
      for (final text in [_aiText * 3, _humanText * 2, '!!!', '123 456']) {
        final score = AiDetectorEngine.analyze(text).score;
        expect(score, inInclusiveRange(0, 100));
      }
    });

    test('contractions are counted', () {
      final report = AiDetectorEngine.analyze(_humanText);
      final trigger = report.triggers.firstWhere((t) => t.id == 'contractions');
      expect(
        trigger.evidence.single,
        matches(RegExp(r'^\d+ contractions? in \d+ words$')),
      );
      expect(trigger.evidence.single, isNot(startsWith('0 contraction')));
    });

    test('repeated openers are detected and named', () {
      const text =
          'Teams adopt tools quickly. Teams then forget why they adopted '
          'them. Teams rarely revisit old decisions. Teams also resist '
          'audits of their own workflow. Managers notice this pattern too '
          'late. Managers blame the tooling instead. Managers move on, and '
          'nothing changes. Everyone loses eventually.';
      final report = AiDetectorEngine.analyze(text);
      final trigger =
          report.triggers.firstWhere((t) => t.id == 'repeated-openers');
      expect(trigger.fired, isTrue);
      expect(trigger.evidence.single, contains('"teams"'));
    });

    test('a hidden zero-width run is read as the Claude watermark', () {
      // Three zero-width joiners smuggled between words: invisible on screen,
      // impossible to type, and exactly the carrier a watermark needs.
      const marked = 'The​quarterly report​ covers three regions and '
          'the​ margin held steady across all of them.';
      final report = AiDetectorEngine.analyze(marked);
      expect(report.claudeSigned, isTrue);
      expect(report.author, AiAuthor.claude);
      expect(report.verdict, 'Generated by Claude');
      expect(report.score, greaterThanOrEqualTo(90));
      final trigger = report.triggers.firstWhere((t) => t.id == 'claude');
      expect(trigger.fired, isTrue);
      expect(trigger.evidence.any((e) => e.contains('zero-width space')),
          isTrue);
    });

    test('a single stray zero-width space is not a watermark', () {
      final report = AiDetectorEngine.analyze(
          'A pasted​line from a web page, nothing more than that.');
      expect(report.claudeSigned, isFalse);
      expect(report.verdict, isNot('Generated by Claude'));
    });

    test('one Unicode tag character is conclusive on its own', () {
      final report = AiDetectorEngine.analyze(
          'Perfectly ordinary looking sentence\u{E0041} with nothing odd '
          'about it at all.');
      expect(report.claudeSigned, isTrue);
      expect(report.verdict, 'Generated by Claude');
    });

    test('naming Claude in a product context attributes the text', () {
      final report = AiDetectorEngine.analyze(
          'This summary was drafted with Claude 3.5 and then edited by hand '
          'before it went out to the team on Monday morning.');
      expect(report.claudeSigned, isTrue);
      expect(report.verdict, 'Generated by Claude');
      final trigger = report.triggers.firstWhere((t) => t.id == 'claude');
      expect(trigger.evidence.any((e) => e.startsWith('Claude model id')),
          isTrue);
    });

    test('a person called Claude is not an attribution', () {
      final report = AiDetectorEngine.analyze(
          'Claude phoned about the fence again. He wants it moved back a '
          'metre, which is not happening before spring.');
      expect(report.claudeSigned, isFalse);
      expect(report.author, AiAuthor.unknown);
    });

    test('assistant boilerplate raises the score without naming an author',
        () {
      final report = AiDetectorEngine.analyze(
          'As an AI language model, I cannot browse the internet for you. '
          'I hope this helps. Let me know if you need anything further on '
          'this topic.');
      expect(report.claudeSigned, isFalse);
      final trigger = report.triggers.firstWhere((t) => t.id == 'claude');
      expect(trigger.fired, isTrue);
      expect(trigger.strength, lessThan(1));
    });

    test('a quiet watermark scan does not drag the AI score down', () {
      // _aiText carries no signature at all. Adding the scan must not dilute
      // the style verdict, because a missing watermark is not evidence.
      final report = AiDetectorEngine.analyze(_aiText);
      expect(report.claudeSigned, isFalse);
      expect(report.score, greaterThan(55));
    });

    test('highlights point at the exact matched text', () {
      final report = AiDetectorEngine.analyze(_aiText);
      expect(report.highlights, isNotEmpty);
      final phrase = report.highlights.firstWhere(
        (h) => h.kind == AiHighlightKind.phrase,
      );
      expect(_aiText.substring(phrase.start, phrase.end).trim(), isNotEmpty);
      // Every span must be in range, ordered, and non-overlapping.
      var previousEnd = -1;
      for (final h in report.highlights) {
        expect(h.start, greaterThanOrEqualTo(previousEnd));
        expect(h.end, greaterThan(h.start));
        expect(h.end, lessThanOrEqualTo(_aiText.length));
        previousEnd = h.end;
      }
    });

    test('a transition opener is highlighted at the start of its sentence',
        () {
      final report = AiDetectorEngine.analyze(_aiText);
      final openers = report.highlights.where(
        (h) => h.kind == AiHighlightKind.opener,
      );
      expect(openers, isNotEmpty);
      for (final h in openers) {
        expect(
          _aiText.substring(h.start, h.end).toLowerCase(),
          isIn(const [
            'however', 'moreover', 'furthermore', 'additionally',
            'consequently', 'nevertheless', 'ultimately', 'overall',
            'indeed', 'thus', 'therefore', 'hence', 'meanwhile',
            'subsequently',
          ]),
        );
      }
    });

    test('a hidden character is highlighted over the word it hides in', () {
      const marked = 'The margin​held steady across every region we '
          'looked at, quarter after quarter.';
      final report = AiDetectorEngine.analyze(marked);
      final mark = report.highlights.firstWhere(
        (h) => h.kind == AiHighlightKind.watermark,
      );
      // Zero-width characters have no width, so the span has to cover
      // something visible or the reader sees no mark at all.
      expect(
        marked.substring(mark.start, mark.end).replaceAll('​', '').trim(),
        isNotEmpty,
      );
    });

    test('human text produces no highlights above a mild tell', () {
      final report = AiDetectorEngine.analyze(_humanText);
      expect(
        report.highlights.any((h) => h.kind.severity >= 2),
        isFalse,
      );
    });

    test('verdict bands map monotonically to score', () {
      const bands = [
        'Very likely human-written',
        'Likely human-written',
        'Mixed signals',
        'Likely AI-generated',
        'Very likely AI-generated',
      ];
      String band(double score) => AiDetectorReport(
            score: score,
            wordCount: 100,
            sentenceCount: 5,
            avgSentenceWords: 20,
            triggers: const [],
          ).verdict;
      var lastIndex = -1;
      for (final score in [0.0, 25.0, 45.0, 65.0, 95.0]) {
        final index = bands.indexOf(band(score));
        expect(index, greaterThan(lastIndex));
        lastIndex = index;
      }
    });
  });
}
