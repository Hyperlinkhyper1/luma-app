import 'package:test/test.dart';
import '../lib/wiki_search_test.dart';

void main() {
  test('perfect retrieval scores 100 and lower ranks receive partial credit', () {
    final n = wikiPassages.length;
    final documents = List.generate(n, (i) => List.generate(n, (j) => i == j ? 1.0 : 0.0));
    final queries = documents.map((v) => List<double>.from(v)).toList();
    expect(wikiScore([...documents, ...queries]), closeTo(100, 0.00001));
    queries[0] = List<double>.from(documents[1]);
    expect(wikiScore([...documents, ...queries]), lessThan(100));
  });

  test('rejects incomplete and invalid embeddings', () {
    expect(() => wikiScore([]), throwsFormatException);
    final vectors = List.generate(wikiPassages.length + wikiQueries.length, (_) => [0.0]);
    expect(() => wikiScore(vectors), throwsFormatException);
  });
}
