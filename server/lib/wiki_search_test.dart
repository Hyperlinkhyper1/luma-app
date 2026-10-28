import 'dart:math' as math;

// Related distractors make retrieval depend on the distinction in each query.
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
  'In 1655 Christiaan Huygens discovered Titan, the largest moon of Saturn.',
  'In 1610 Galileo published observations of mountains on the Moon and moons of Jupiter.',
  'A binary search requires sorted data and repeatedly halves the remaining range.',
  'A linear search examines entries one by one and does not require sorted data.',
  'Venus orbits the Sun in about 225 days and has a dense atmosphere.',
  'Galinstan is a liquid metal alloy used in some modern thermometers.',
  'Bali is an Indonesian island east of Java and a popular tourist destination.',
  'JavaScript is a programming language commonly used in web browsers.',
  'A new moon occurs when the Moon lies between Earth and the Sun.',
  'A transit occurs when a planet passes across the face of a star.',
  'Apoptosis is a controlled process that removes unwanted or damaged cells.',
  'Fertilization combines reproductive cells to form a new organism.',
  'The Nile River flows north through Egypt and empties into the Mediterranean Sea.',
  'The Congo rainforest covers a large part of central Africa.',
  'An icicle hangs downward when dripping water freezes.',
  'A geyser erupts when underground water is heated and forced to the surface.',
  'The Treaty of Paris ended the American Revolutionary War in 1783.',
  'The Congress of Berlin revised arrangements in southeastern Europe in 1878.',
  'A right angle measures exactly 90 degrees.',
  'A reflex angle measures more than 180 but less than 360 degrees.',
  'An autobiography recounts a person’s own life, written by that person.',
  'A bibliography lists sources consulted or cited in a work.',
  'Plant roots absorb water and dissolved minerals from the soil.',
  'Photosynthesis uses light to produce sugars from water and carbon dioxide.',
  'Giovanni Cassini discovered four moons of Saturn and a gap in its rings.',
  'Johannes Kepler published laws describing the motion of planets around the Sun.',
  'A hash table uses a key to locate an entry without sorting the entire collection.',
  'A breadth-first search explores a graph layer by layer.',
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
  'Who discovered Saturn’s largest moon?',
  'When did Galileo publish his telescopic discoveries?',
  'How can I find an item quickly by repeatedly dividing a sorted list?',
  'How can I find an item in an unsorted list by checking each entry?',
  'Which planet completes an orbit in under three months?',
  'Which liquid element was used in older glass fever thermometers?',
  'On which island would you find Jakarta?',
  'Which language compiles to instructions for a virtual machine?',
  'Which eclipse happens when our planet casts a shadow on its satellite?',
  'Which eclipse can be seen when the Moon hides the Sun?',
  'Which kind of cell division makes matching cells for tissue repair?',
  'Which division reduces chromosomes when making gametes?',
  'Name the river that reaches the Atlantic from northern South America.',
  'Name the tropical forest found across much of the Amazon basin.',
  'Which mineral deposit grows from a cavern ceiling?',
  'Which mineral deposit builds up from a cavern floor?',
  'Which 1919 peace settlement involved Germany and the Allies?',
  'Which meeting redrew the map of Europe in 1815?',
  'What type of angle is smaller than 90 degrees?',
  'What type of angle lies between a right angle and a straight angle?',
  'What is an original firsthand record of an event called?',
  'What is a work that analyzes firsthand evidence called?',
  'What transports water and minerals through a plant?',
  'What transports sugars around a plant?',
  'Which astronomer found Titan in 1655?',
  'Who published telescopic observations of Jupiter’s moons in 1610?',
  'Which search algorithm halves a sorted range at each step?',
  'Which search method checks items sequentially without sorting?',
];

// Each query has one intended relevant passage; distractors are not answers.
final wikiRelevantPassages = List<int>.unmodifiable([
  for (var i = 0; i < 24; i++) i,
  for (var i = 0; i < 24; i++) i,
]);

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
    final rank =
        scores.indexWhere((s) => s.index == wikiRelevantPassages[q]) + 1;
    if (rank <= 10) total += 1 / rank;
  }
  return total * 100 / wikiQueries.length;
}
