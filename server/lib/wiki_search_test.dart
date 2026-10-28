import 'dart:math' as math;

// Each passage has one query. The passages are intentionally similar in pairs;
// the query often describes a distinction without repeating the passage words.
const wikiPassages = <String>[
  'Mercury is the smallest planet and circles the Sun in 88 days.',
  'Mercury is a silvery liquid metal used in old thermometers.',
  'Java is an Indonesian island containing Jakarta and many volcanoes.',
  'Java is a programming language whose programs run on a virtual machine.',
  'A lunar eclipse occurs when Earth blocks sunlight from reaching the Moon.',
  'A solar eclipse occurs when the Moon blocks the Sun from an observer on Earth.',
  'Mitosis produces two genetically similar cells for growth and repair.',
  'Meiosis produces reproductive cells with half the usual chromosome count.',
  'The Amazon River flows across South America into the Atlantic Ocean.',
  'The Amazon rainforest is a vast tropical forest spanning several South American countries.',
  'A stalactite hangs from the roof of a cave as minerals accumulate.',
  'A stalagmite grows upward from a cave floor as mineral-rich drops land.',
  'The Treaty of Versailles formally ended the war between Germany and the Allied powers in 1919.',
  'The Congress of Vienna redrew Europe after the defeat of Napoleon in 1815.',
  'An acute angle measures less than 90 degrees.',
  'An obtuse angle measures more than 90 but less than 180 degrees.',
  'A primary source is direct evidence created by someone present at an event.',
  'A secondary source interprets or analyzes evidence created by others.',
  'The xylem carries water and minerals upward through a plant.',
  'The phloem transports sugars from leaves to other parts of a plant.',
  'In 1609 Galileo observed Jupiter through a telescope and later reported four moons.',
  'In 1610 Galileo published observations of mountains on the Moon and moons of Jupiter.',
  'A binary search requires sorted data and repeatedly halves the remaining range.',
  'A linear search examines entries one by one and does not require sorted data.',
];

const wikiQueries = <String>[
  'Which world has the shortest year?',
  'What poisonous element was once used to measure fever?',
  'Where is the capital of Indonesia located?',
  'What runs bytecode on the JVM?',
  'Why does the full moon sometimes darken in Earth’s shadow?',
  'What causes daylight to disappear when the moon crosses the sun?',
  'How does the body replace damaged cells without changing chromosome number?',
  'How are sperm and egg cells made?',
  'Which South American waterway empties into the ocean?',
  'What is the huge wooded biome in northern South America?',
  'What cave formation points down from above?',
  'What cave formation rises beneath dripping water?',
  'What agreement followed the First World War?',
  'Who reorganized Europe after the Napoleonic wars?',
  'What do you call a corner narrower than a right angle?',
  'What do you call an angle wider than a right angle but not straight?',
  'Is an eyewitness diary original evidence?',
  'What kind of historical source explains other records?',
  'Which plant tissue brings moisture to the leaves?',
  'How does a plant distribute the food made by photosynthesis?',
  'When did Galileo first look at Jupiter with a telescope?',
  'When did Galileo publish his telescopic discoveries?',
  'How can I find an item quickly by repeatedly dividing a sorted list?',
  'How can I find an item in an unsorted list by checking each entry?',
];

/// Mean reciprocal rank, truncated at ten. Deterministic ties preserve corpus order.
double wikiScore(List<List<double>> vectors) {
  if (vectors.length != wikiPassages.length + wikiQueries.length) {
    throw const FormatException('Wrong number of embeddings');
  }
  final size = vectors.first.length;
  if (size == 0 ||
      vectors.any((v) => v.length != size || v.any((x) => !x.isFinite))) {
    throw const FormatException('Invalid embedding dimensions');
  }
  final norms = vectors
      .map((v) => math.sqrt(v.fold<double>(0, (a, b) => a + b * b)))
      .toList();
  if (norms.any((n) => n == 0 || !n.isFinite))
    throw const FormatException('Invalid embedding norm');
  var total = 0.0;
  for (var q = 0; q < wikiQueries.length; q++) {
    final query = vectors[wikiPassages.length + q];
    final scores = <({int index, double score})>[];
    for (var d = 0; d < wikiPassages.length; d++) {
      var dot = 0.0;
      for (var i = 0; i < size; i++) {
        dot += query[i] * vectors[d][i];
      }
      scores.add(
          (index: d, score: dot / (norms[wikiPassages.length + q] * norms[d])));
    }
    scores.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.index.compareTo(b.index);
    });
    final rank = scores.indexWhere((s) => s.index == q) + 1;
    if (rank <= 10) total += 1 / rank;
  }
  return total * 100 / wikiQueries.length;
}
