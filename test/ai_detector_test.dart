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
      expect(report.author, AiAuthor.unknown);
      expect(report.verdict, isNot('Generated by Claude'));
      final trigger = report.triggers.firstWhere((t) => t.id == 'claude');
      expect(trigger.fired, isTrue);
      expect(trigger.title, 'Assistant boilerplate');
    });

    test('a single stock disclaimer counts for less than a transcript of them',
        () {
      double boilerplate(String text) => AiDetectorEngine.analyze(text)
          .triggers
          .firstWhere((t) => t.id == 'claude')
          .strength;
      final one = boilerplate(
          'I hope this helps with the report you are putting together.');
      final several = boilerplate(
          'As an AI language model, I cannot browse the internet. '
          'My knowledge cutoff limits what I can tell you here. '
          'I hope this helps.');
      expect(one, greaterThan(0));
      expect(several, greaterThan(one));
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

    // The bug this guards: a fully generated essay that maxed out every
    // rhythm check still came out at "Mixed signals", because the checks
    // that found nothing — no em dashes, no passive voice, no connective
    // openers — each cast a full-weight vote for "human". Not containing a
    // specific tic is not evidence of a human hand.
    test('a plain generated essay with no stock tics is still flagged', () {
      const essay = '''
Remote work has fundamentally reshaped the way modern organizations operate.
Over the past decade, advances in communication technology have made it
possible for teams to collaborate across continents without ever sharing a
physical office. This shift has brought both opportunities and challenges for
employers and employees alike.

One of the primary benefits of remote work is flexibility. Employees can
structure their days around personal commitments, which often leads to
improved work-life balance. Studies suggest that workers who control their own
schedules report higher levels of job satisfaction. Employers benefit as well,
since they can recruit talent from a much wider geographic pool.

However, remote work is not without drawbacks. Many employees report feelings
of isolation when they lack daily in-person interaction with colleagues.
Communication can become fragmented, and spontaneous collaboration is harder
to replicate over video calls. Managers may also struggle to evaluate
performance when they cannot directly observe their teams.

Organizations that succeed in remote environments tend to invest heavily in
clear processes. Written documentation replaces hallway conversations, and
regular check-ins provide structure. Companies also need to be intentional
about building culture, since shared rituals do not emerge naturally in
distributed teams.''';
      final report = AiDetectorEngine.analyze(essay);
      expect(report.score, greaterThan(70));
      expect(report.verdict, contains('AI-generated'));
      // It carries none of the tics, and that must cost it nothing.
      for (final id in ['em-dash', 'passive', 'repeated-openers']) {
        expect(report.triggers.firstWhere((t) => t.id == id).strength, 0);
      }
    });

    test('checks that find nothing never vote the score down', () {
      // Two texts with identical rhythm; the second simply also contains a
      // tic. Adding evidence may only raise the score, and its absence in
      // the first must not have lowered that one.
      const plain = 'The committee reviewed the proposal in full. The members '
          'agreed that the timeline required revision. The revised plan was '
          'circulated to all departments. Each department returned comments '
          'within the allotted period. The comments were collated by the '
          'secretary. The final document was approved in the autumn session.';
      final withTic = plain.replaceFirst(
          'The committee reviewed', 'Moreover, the committee reviewed');
      expect(
        AiDetectorEngine.analyze(withTic).score,
        greaterThanOrEqualTo(AiDetectorEngine.analyze(plain).score),
      );
    });

    test('one-way checks are marked as such and two-sided ones are not', () {
      final report = AiDetectorEngine.analyze(_aiText);
      const oneWay = {
        'claude', 'phrases', 'formatting', 'contrast', 'openers', 'em-dash',
        'repeated-openers', 'passive',
      };
      const twoSided = {
        'burstiness', 'extremes', 'paragraphs', 'contractions', 'voice',
      };
      for (final t in report.triggers) {
        if (oneWay.contains(t.id)) {
          expect(t.oneWay, isTrue, reason: '${t.id} should be one-way');
        } else if (twoSided.contains(t.id)) {
          expect(t.oneWay, isFalse, reason: '${t.id} should be two-sided');
        } else {
          fail('unclassified trigger "${t.id}"');
        }
      }
      expect(report.triggers.map((t) => t.id).toSet(),
          {...oneWay, ...twoSided});
    });

    test('a pasted chat answer is caught by its formatting alone', () {
      const answer = '''
Great question! Here is a breakdown of the main considerations.

## Key Factors

- **Cost**: Managed services carry a premium but reduce operational overhead.
- **Scalability**: Horizontal scaling is easier when storage is decoupled.
- **Maintenance**: Self-hosting means you own patching, backups and upgrades.

## Recommendation

For a team of your size a managed offering is usually the better choice.

Let me know if you need anything further on this topic.''';
      final report = AiDetectorEngine.analyze(answer);
      final formatting =
          report.triggers.firstWhere((t) => t.id == 'formatting');
      expect(formatting.fired, isTrue);
      expect(report.score, greaterThan(58));
    });

    test('the corrective-contrast habit is detected', () {
      const text =
          'It is not just about speed. It is about what the team can commit '
          'to. The real question is where the coupling sits, not how many '
          'warnings the linter prints. That is the whole point.';
      final report = AiDetectorEngine.analyze(text);
      final contrast = report.triggers.firstWhere((t) => t.id == 'contrast');
      expect(contrast.fired, isTrue);
      expect(contrast.oneWay, isTrue);
    });

    test('impersonal register is measured and a personal one is not flagged',
        () {
      const impersonal =
          'The procedure requires that each sample be weighed before the '
          'solution is added. The resulting mixture must then be held at a '
          'constant temperature for the duration of the reaction. Readings '
          'are recorded at five-minute intervals throughout. The apparatus '
          'should be calibrated before every run, since drift in the sensor '
          'introduces systematic error into the recorded values. Once the '
          'reaction has completed, the residue is filtered and retained for '
          'later analysis by the laboratory. The filtrate is discarded '
          'according to the standard disposal procedure for the compound in '
          'question. Records of each run are kept in the bound notebook '
          'assigned to the bench, and the notebook remains in the laboratory '
          'at all times. Deviations from the written method are noted in the '
          'margin beside the relevant reading.';
      const personal =
          'I weighed each sample before adding the solution, which honestly '
          'took me far longer than I expected it to. You have to hold the '
          'mixture at a steady temperature the whole way through, and my '
          'bench heater kept drifting. Did I recalibrate every run? I did '
          'not, and I probably should have. We kept the residue anyway, so '
          'maybe the lab can tell me what actually went wrong in there. '
          'My notes are a mess, which is basically always true by the end '
          'of a run. You would think I would have learned by now. I wrote '
          'the readings on my hand at one point, if you can believe that, '
          'and then I washed my hands. Anyway, we will redo it on Thursday '
          'and I will try to be less stupid about the whole thing.';
      double voice(String t) => AiDetectorEngine.analyze(t)
          .triggers
          .firstWhere((x) => x.id == 'voice')
          .strength;
      expect(voice(impersonal), greaterThan(0.5));
      expect(voice(personal), lessThan(0.2));
    });

    test('a clipped human voice is not punished for lacking long sentences',
        () {
      const clipped = 'The bread was great. Warm, too. I liked it. The pasta '
          'came out cold. I said nothing. I never do. Dana loved her fish. '
          'She kept pushing the plate at me. It was fine. Not forty dollars '
          'fine. Would I go back? Maybe.';
      final extremes = AiDetectorEngine.analyze(clipped)
          .triggers
          .firstWhere((t) => t.id == 'extremes');
      expect(extremes.strength, lessThan(0.15));
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
