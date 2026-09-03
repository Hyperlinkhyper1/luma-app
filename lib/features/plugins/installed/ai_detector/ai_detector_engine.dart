/// The AI Detector's brain: a set of statistical writing-style checks that
/// estimate how machine-generated a piece of text reads.
///
/// There is deliberately no model here — no network, no embeddings, no
/// inference. Every signal is arithmetic on the words themselves, in the same
/// spirit as stylometry: LLM output tends to be *uniform* (steady sentence
/// lengths, tidy paragraphs, formal register) and leans on a recognisable
/// vocabulary. Humans are burstier and sloppier.
///
/// Each check produces an [AiTrigger] with a 0..1 strength; the final score is
/// the active checks' weighted average scaled to 0..100. Checks whose sample
/// is too small to mean anything simply stay out of the average.
library;

import 'dart:math' as math;

/// One measured signal in the report.
class AiTrigger {
  const AiTrigger({
    required this.id,
    required this.title,
    required this.detail,
    required this.strength,
    this.evidence = const [],
  });

  /// Stable identifier, e.g. `burstiness`.
  final String id;

  /// Short headline shown in the report list.
  final String title;

  /// One or two sentences explaining what was measured and why it matters.
  final String detail;

  /// 0..1 — how strongly this check fired. Below ~0.15 it counts as quiet.
  final double strength;

  /// Concrete proof pulled from the text: matched phrases, measured ranges,
  /// rates. Shown as chips under the trigger so the verdict can be checked.
  final List<String> evidence;

  bool get fired => strength >= 0.15;
}

/// Everything the report page needs for one analysed text.
class AiDetectorReport {
  const AiDetectorReport({
    required this.score,
    required this.wordCount,
    required this.sentenceCount,
    required this.avgSentenceWords,
    required this.triggers,
  });

  /// 0..100 — higher reads more machine-like.
  final double score;
  final int wordCount;
  final int sentenceCount;
  final double avgSentenceWords;
  final List<AiTrigger> triggers;

  /// Short texts make every statistic meaningless; the UI shows a caution
  /// banner when this is false.
  bool get reliable => wordCount >= 60 && sentenceCount >= 4;

  String get verdict {
    if (score < 18) return 'Very likely human-written';
    if (score < 38) return 'Likely human-written';
    if (score < 58) return 'Mixed signals';
    if (score < 78) return 'Likely AI-generated';
    return 'Very likely AI-generated';
  }
}

class AiDetectorEngine {
  AiDetectorEngine._();

  /// Phrases that show up constantly in LLM prose and rarely in casual human
  /// writing. Matched case-insensitively on word boundaries.
  static const _phrases = [
    'delve into', 'delves into', 'delving into',
    'a testament to',
    'tapestry',
    "in today's fast-paced world",
    'ever-evolving landscape',
    'in the realm of',
    "it's important to note", 'it is important to note',
    "it's worth noting", 'it is worth noting',
    'navigate the complexities', 'navigating the complexities',
    'plays a crucial role', 'play a crucial role',
    'plays a vital role', 'play a vital role',
    'pivotal role',
    'myriad of', 'plethora of',
    'multifaceted',
    'holistic approach',
    'seamless', 'seamlessly',
    'harness the power',
    'unlock the potential',
    'unleash',
    'game-changer', 'game changer',
    'paradigm shift',
    'deep dive', 'dive into',
    'embark on',
    'beacon of',
    'underscores', 'underscoring',
    'sheds light on',
    'paves the way',
    'intricacies',
    'interplay between',
    'meticulous', 'meticulously',
    'not only', 'but also',
    'in conclusion', 'in summary', 'to summarize', 'to summarise',
  ];

  static final _phraseRes = <String, RegExp>{
    for (final p in _phrases)
      p: RegExp('\\b${RegExp.escape(p)}\\b', caseSensitive: false),
  };

  /// Sentence openers that suggest formulaic paragraph-by-paragraph flow.
  static const _connectives = [
    'however', 'moreover', 'furthermore', 'additionally', 'consequently',
    'nevertheless', 'ultimately', 'overall', 'indeed', 'thus', 'therefore',
    'hence', 'meanwhile', 'subsequently',
  ];

  /// First words too common to count as stylistic repetition when several
  /// sentences share them.
  static const _openerStopwords = {
    'the', 'a', 'an', 'i', 'it', 'this', 'that', 'these', 'those', 'there',
    'here', 'if', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'as', 'but',
    'and', 'or', 'so', 'he', 'she', 'we', 'they', 'you', 'my', 'his', 'her',
    'their', 'our', 'its', 'when', 'while', 'what', 'why', 'how', 'not',
  };

  static final _wordRe =
      RegExp(r"[A-Za-z0-9\u00C0-\u024F]+(?:['\u2019][A-Za-z]+)?");
  static final _sentenceSplitRe = RegExp(r'[.!?\u2026]+(?:\s|$)');
  static final _contractionRe = RegExp(r"\w+'(?:[A-Za-z]+)|\w+\u2019[A-Za-z]+");
  static final _passiveRe = RegExp(
    r'\b(is|are|was|were|be|been|being)\s+(?:\w+ly\s+)?'
    r'(\w+ed|made|given|taken|done|seen|held|known|shown|found|built|written|'
    r'driven|kept|used|based|designed|intended|considered|associated|involved|'
    r'created|developed|provided|required|allowed|caused|limited|prepared|'
    r'published|recognised|recognized|described|defined|established|drawn|grown)\b',
    caseSensitive: false,
  );

  /// Analyses [text] and returns the full report. Never throws; empty input
  /// yields a zero-score report with no triggers.
  static AiDetectorReport analyze(String text) {
    final wordCount = _wordRe.allMatches(text).length;
    if (wordCount == 0) {
      return const AiDetectorReport(
        score: 0,
        wordCount: 0,
        sentenceCount: 0,
        avgSentenceWords: 0,
        triggers: [],
      );
    }

    final sentences = _splitSentences(text);
    final sentenceWords =
        sentences.map(_countWords).where((n) => n > 0).toList();
    final lower = text.toLowerCase();
    final per1k = 1000 / wordCount;

    final triggers = <AiTrigger>[
      _burstiness(sentenceWords),
      _phraseCheck(lower, per1k),
      _openers(sentences),
      _contractions(text, per1k),
      _emDashes(text, wordCount),
      _passiveVoice(text, wordCount),
      _paragraphUniformity(text),
      _repeatedOpeners(sentences),
    ];

    // Weighted average over the checks that had enough data to judge. Weights
    // roughly follow how discriminating each signal is in practice.
    const weights = <String, double>{
      'burstiness': 20,
      'phrases': 25,
      'openers': 12,
      'contractions': 8,
      'em-dash': 7,
      'passive': 10,
      'paragraphs': 10,
      'repeated-openers': 8,
    };
    var weightSum = 0.0;
    var weighted = 0.0;
    for (final t in triggers) {
      final w = weights[t.id];
      if (w == null) continue;
      weightSum += w;
      weighted += w * t.strength;
    }
    final score = weightSum == 0 ? 0.0 : 100 * weighted / weightSum;

    return AiDetectorReport(
      score: score.clamp(0, 100),
      wordCount: wordCount,
      sentenceCount: sentenceWords.length,
      avgSentenceWords:
          sentenceWords.isEmpty ? 0 : wordCount / sentenceWords.length,
      triggers: triggers,
    );
  }

  // ---- individual checks ----------------------------------------------------

  /// Humans write in bursts — a five-word jab after a forty-word ramble.
  /// Models settle into a comfortable middle and stay there, so a low
  /// coefficient of variation in sentence length is the strongest style tell.
  static AiTrigger _burstiness(List<int> sentenceWords) {
    if (sentenceWords.length < 6) {
      return const AiTrigger(
        id: 'burstiness',
        title: 'Uniform sentence lengths',
        detail: 'Needs at least six sentences to measure.',
        strength: 0,
      );
    }
    final cv = _coefficientOfVariation(sentenceWords);
    final strength = ((0.55 - cv) / 0.40).clamp(0.0, 1.0);
    final min = sentenceWords.reduce((a, b) => a < b ? a : b);
    final max = sentenceWords.reduce((a, b) => a > b ? a : b);
    return AiTrigger(
      id: 'burstiness',
      title: strength >= 0.5
          ? 'Very uniform sentence lengths'
          : 'Sentence-length variety',
      detail: strength >= 0.15
          ? 'Every sentence hovers around the same length. Human writing '
              'usually swings between short punches and long rambles; steady '
              'lengths suggest one generator keeping a consistent rhythm.'
          : 'Sentence lengths vary naturally, which human writers do and '
              'models find hard to fake.',
      strength: strength,
      evidence: [
        'sentences range $min\u2013$max words',
        'variation index ${cv.toStringAsFixed(2)} (low = uniform)',
      ],
    );
  }

  /// Raw buzzword counting. One hit proves nothing — "not only" is perfectly
  /// human — but dense clusters of these are where generated text gives
  /// itself away most visibly.
  static AiTrigger _phraseCheck(String lower, double per1k) {
    final found = <String, int>{};
    _phraseRes.forEach((phrase, re) {
      final count = re.allMatches(lower).length;
      if (count > 0) found[phrase] = count;
    });
    final hits = found.values.fold(0, (a, b) => a + b);
    final rate = hits * per1k;
    final strength = (rate / 10).clamp(0.0, 1.0);
    final ranked = found.keys.toList()
      ..sort((a, b) => found[b]!.compareTo(found[a]!));
    return AiTrigger(
      id: 'phrases',
      title: strength >= 0.15
          ? 'AI-favourite phrases'
          : 'No AI-favourite phrasing',
      detail: strength >= 0.15
          ? 'These words and constructions appear far more often in '
              'model-generated prose than in everyday human writing. Each '
              'chip below is a literal match in your text.'
          : 'None of the stock phrases models lean on were found.',
      strength: strength,
      evidence: [
        for (final p in ranked.take(8)) '\u201C$p\u201D \u00D7${found[p]}',
        if (found.isEmpty) 'no matches',
      ],
    );
  }

  /// Models open paragraph after paragraph with a tidy connective. Humans do
  /// it too, just nowhere near as consistently.
  static AiTrigger _openers(List<String> sentences) {
    if (sentences.length < 6) {
      return const AiTrigger(
        id: 'openers',
        title: 'Transition-word openers',
        detail: 'Needs at least six sentences to measure.',
        strength: 0,
      );
    }
    final counts = <String, int>{};
    var used = 0;
    for (final s in sentences) {
      final firstWord = _wordRe.firstMatch(s.toLowerCase())?.group(0);
      if (firstWord != null && _connectives.contains(firstWord)) {
        used++;
        counts[firstWord] = (counts[firstWord] ?? 0) + 1;
      }
    }
    final ratio = used / sentences.length;
    final strength = ((ratio - 0.08) / 0.22).clamp(0.0, 1.0);
    final ranked = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return AiTrigger(
      id: 'openers',
      title: 'Transition-word openers',
      detail: ratio >= 0.08
          ? '$used of ${sentences.length} sentences start with a formal '
              'connective. Essay-bot structure opens sections with '
              '"Moreover," and "Furthermore," far more than people do.'
          : 'Sentences do not lean on formal connectives to start.',
      strength: strength,
      evidence: [
        for (final w in ranked.take(6))
          '$w \u00D7${counts[w]} at sentence start',
        if (ranked.isEmpty) 'none used',
      ],
    );
  }

  /// People contract. Models mostly don't — training rewards the spelled-out
  /// formal form. A long text without a single "don't" or "it's" is quietly
  /// suspicious (though formal human writing looks the same, hence the low
  /// weight).
  static AiTrigger _contractions(String text, double per1k) {
    final wordCount = _wordRe.allMatches(text).length;
    if (wordCount < 120) {
      return const AiTrigger(
        id: 'contractions',
        title: 'Missing contractions',
        detail: 'Needs at least 120 words to measure.',
        strength: 0,
      );
    }
    final contractions = _contractionRe.allMatches(text).length;
    final rate = contractions * per1k;
    final strength = ((1.5 - rate) / 1.5).clamp(0.0, 1.0);
    return AiTrigger(
      id: 'contractions',
      title: rate < 1.5 ? 'Missing contractions' : 'Natural contraction use',
      detail: rate < 1.5
          ? 'Almost no contracted forms ("don\u2019t", "it\u2019s"). Generated '
              'text defaults to the stiffer un-contracted register.'
          : 'Contractions appear at a natural human rate.',
      strength: strength,
      evidence: [
        '$contractions contraction${contractions == 1 ? '' : 's'} in $wordCount words',
      ],
    );
  }

  /// The em dash is the punctuation mark models reached for so often it
  /// became a meme. Rate matters more than presence, and the text has to be
  /// long enough that one dash doesn't inflate into a "rate".
  static AiTrigger _emDashes(String text, int wordCount) {
    final dashes = '\u2014'.allMatches(text).length + '--'.allMatches(text).length;
    if (wordCount < 150) {
      return const AiTrigger(
        id: 'em-dash',
        title: 'Em-dash overuse',
        detail: 'Needs at least 150 words to measure.',
        strength: 0,
      );
    }
    if (dashes == 0) {
      return const AiTrigger(
        id: 'em-dash',
        title: 'Em-dash overuse',
        detail: 'No em dashes present.',
        strength: 0,
      );
    }
    final rate = dashes * (1000 / wordCount);
    final strength = ((rate - 2.0) / 6.0).clamp(0.0, 1.0);
    return AiTrigger(
      id: 'em-dash',
      title: 'Em-dash overuse',
      detail: strength >= 0.15
          ? 'Em dashes pepper the text well past what typical human prose '
              'uses \u2014 a much-memed model habit.'
          : 'Em-dash use is within normal range.',
      strength: strength,
      evidence: [
        '$dashes em dashes (${rate.toStringAsFixed(1)} per 1000 words)',
      ],
    );
  }

  /// Formal, passive-heavy register is another trained-in habit. Weak signal
  /// on its own \u2014 legal and academic humans write this way too \u2014 but it
  /// corroborates the other checks.
  static AiTrigger _passiveVoice(String text, int wordCount) {
    if (wordCount < 100) {
      return const AiTrigger(
        id: 'passive',
        title: 'Passive-voice density',
        detail: 'Needs at least 100 words to measure.',
        strength: 0,
      );
    }
    final matches = _passiveRe.allMatches(text).length;
    final rate = 100 * matches / wordCount;
    final strength = ((rate - 6) / 14).clamp(0.0, 1.0);
    return AiTrigger(
      id: 'passive',
      title: 'Passive-voice density',
      detail: strength >= 0.15
          ? 'Heavy passive construction ("was designed to", "is considered") '
              'keeps agency out of sentences \u2014 common in generated prose.'
          : 'Passive voice stays at a normal level.',
      strength: strength,
      evidence: [
        '$matches passive constructions (${rate.toStringAsFixed(1)} per 100 words)',
      ],
    );
  }

  /// Generated essays come in near-equal blocks. Humans produce a two-line
  /// paragraph followed by a ten-line monster.
  static AiTrigger _paragraphUniformity(String text) {
    final paragraphs = text
        .split(RegExp(r'\r?\n\s*\r?\n'))
        .map(_countWords)
        .where((n) => n > 0)
        .toList();
    if (paragraphs.length < 3) {
      return const AiTrigger(
        id: 'paragraphs',
        title: 'Uniform paragraphs',
        detail: 'Needs at least three paragraphs to measure.',
        strength: 0,
      );
    }
    final cv = _coefficientOfVariation(paragraphs);
    final strength = ((0.50 - cv) / 0.35).clamp(0.0, 1.0);
    return AiTrigger(
      id: 'paragraphs',
      title: strength >= 0.15 ? 'Uniform paragraphs' : 'Varied paragraphs',
      detail: strength >= 0.15
          ? 'All paragraphs are nearly the same size, like content poured '
              'evenly into containers. Human drafts lurch between short and '
              'long.'
          : 'Paragraph sizes differ naturally.',
      strength: strength,
      evidence: [
        '${paragraphs.length} paragraphs: '
            '${paragraphs.map((p) => '${p}w').join(', ')}',
      ],
    );
  }

  /// Same opening word again and again (beyond ordinary stopwords) points at
  /// templated generation rather than a person reaching for variety.
  static AiTrigger _repeatedOpeners(List<String> sentences) {
    if (sentences.length < 8) {
      return const AiTrigger(
        id: 'repeated-openers',
        title: 'Repeated sentence openers',
        detail: 'Needs at least eight sentences to measure.',
        strength: 0,
      );
    }
    final counts = <String, int>{};
    for (final s in sentences) {
      final first = _wordRe.firstMatch(s.toLowerCase())?.group(0);
      if (first == null || _openerStopwords.contains(first)) continue;
      counts[first] = (counts[first] ?? 0) + 1;
    }
    String best = '';
    var bestCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    if (best.isEmpty) {
      return const AiTrigger(
        id: 'repeated-openers',
        title: 'Repeated sentence openers',
        detail: 'Not enough distinctive sentence starts to measure.',
        strength: 0,
      );
    }
    final share = bestCount / sentences.length;
    final strength = ((share - 0.28) / 0.35).clamp(0.0, 1.0);
    return AiTrigger(
      id: 'repeated-openers',
      title: 'Repeated sentence openers',
      detail: strength >= 0.15
          ? '"$best" opens $bestCount sentences. Real writers rarely hammer '
              'one opener; template-driven generation does.'
          : 'Sentence openers are varied.',
      strength: strength,
      evidence: ['"$best" starts $bestCount of ${sentences.length} sentences'],
    );
  }

  // ---- helpers --------------------------------------------------------------

  static List<String> _splitSentences(String text) => text
      .split(_sentenceSplitRe)
      .map((s) => s.trim())
      .where((s) => _countWords(s) > 0)
      .toList();

  static int _countWords(String text) => _wordRe.allMatches(text).length;

  static double _coefficientOfVariation(List<int> values) {
    final n = values.length;
    final mean = values.fold<int>(0, (a, b) => a + b) / n;
    if (mean == 0) return 0;
    final variance =
        values.fold<double>(0, (a, b) => a + (b - mean) * (b - mean)) / n;
    return variance <= 0 ? 0 : math.sqrt(variance) / mean;
  }
}
