import 'package:test/test.dart';
import '../lib/wiki_search_test.dart';

void main() {
  test('expanded retrieval suite has explicit answers and hard distractors',
      () {
    expect(wikiQueries.length, greaterThanOrEqualTo(48));
    expect(wikiPassages.length, greaterThan(wikiQueries.length ~/ 2));
    expect(wikiRelevantPassages.length, wikiQueries.length);
    expect(wikiRelevantPassages.toSet().length, greaterThanOrEqualTo(24));
    expect(
      wikiRelevantPassages.every((i) => i >= 0 && i < wikiPassages.length),
      isTrue,
    );
  });

  test('perfect retrieval scores 100 and lower ranks receive partial credit',
      () {
    final n = wikiPassages.length;
    final documents =
        List.generate(n, (i) => List.generate(n, (j) => i == j ? 1.0 : 0.0));
    final queries = wikiRelevantPassages
        .map((i) => List<double>.from(documents[i]))
        .toList();
    expect(wikiScore([...documents, ...queries]), closeTo(100, 0.00001));
    queries[0] = List<double>.from(documents[1]);
    expect(wikiScore([...documents, ...queries]),
        closeTo(100 * (47.5 / 48), 0.00001));
  });

  test('rejects incomplete and invalid embeddings', () {
    expect(() => wikiScore([]), throwsFormatException);
    final vectors =
        List.generate(wikiPassages.length + wikiQueries.length, (_) => [0.0]);
    expect(() => wikiScore(vectors), throwsFormatException);
  });
}
