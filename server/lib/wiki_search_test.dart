import 'dart:math' as math;

/// Parses OpenRouter embedding catalog prices, in USD per million input tokens.
List<Map<String, dynamic>> wikiCatalogModels(Object? data) {
  if (data is! List) throw const FormatException('Missing model catalog');
  final models = <Map<String, dynamic>>[];
  for (final m in data) {
    if (m is! Map || m['id'] is! String) continue;
    final pricing = m['pricing'];
    final prompt =
        pricing is Map ? double.tryParse(pricing['prompt'].toString()) : null;
    final price = prompt == null ? null : prompt * 1e6;
    models.add({
      'id': m['id'],
      'name': m['name'] is String ? m['name'] : m['id'],
      if (price != null && price.isFinite && price >= 0)
        'pricePerMillion': price,
    });
  }
  if (models.isEmpty) throw const FormatException('Empty model catalog');
  return models;
}

/// Adds available catalog prices without changing or dropping saved runs.
List<Map<String, dynamic>> wikiResultsWithPrices(
    List<Map<String, dynamic>> runs, List<Map<String, dynamic>>? catalog) {
  final prices = <String, double>{
    if (catalog != null)
      for (final model in catalog)
        if (model['pricePerMillion'] is double)
          model['id'] as String: model['pricePerMillion'] as double,
  };
  return [
    for (final run in runs)
      {
        ...run,
        if (prices[run['model']] case final price?) 'pricePerMillion': price,
      },
  ];
}

// Fictional reference passages in groups of four. Each group deliberately
// shares entities and vocabulary while changing relationships or conditions.
// Every question has one relevant passage in the full corpus.
const _cases = <({String passage, String query})>[
  (
    passage:
        'In the 2018 harbor agreement, Lydon supplied timber to Merrow in exchange for salt.',
    query:
        'Under the 2018 harbor agreement, which town received wood and paid for it with salt?'
  ),
  (
    passage:
        'In the 2018 harbor agreement, Merrow supplied timber to Lydon in exchange for iron.',
    query:
        'Under the 2018 harbor agreement, which town received wood and paid for it with iron?'
  ),
  (
    passage:
        'In the 2021 harbor agreement, Lydon supplied salt to Merrow in exchange for timber.',
    query:
        'Which agreement had Merrow send timber to Lydon as payment for salt?'
  ),
  (
    passage:
        'In the 2021 harbor agreement, Merrow supplied salt to Lydon in exchange for iron.',
    query:
        'Which agreement had Lydon obtain salt from Merrow in return for iron?'
  ),
  (
    passage:
        'The north library lends maps overnight to residents; visitors may consult them only inside.',
    query: 'Where can a local take maps home, although a visitor cannot?'
  ),
  (
    passage:
        'The south library lends maps overnight to visitors; residents may consult them only inside.',
    query:
        'Where may a visitor borrow maps for the night while locals must stay on site?'
  ),
  (
    passage:
        'The north library lends photographs overnight to visitors; residents may consult them only inside.',
    query:
        'Where may a visitor take photographs home, but a resident may only view them there?'
  ),
  (
    passage:
        'The south library lends photographs overnight to residents; visitors may consult them only inside.',
    query:
        'Where can a resident borrow photographs overnight, while visitors cannot?'
  ),
  (
    passage:
        'At Red Basin, spring floods deposit sand upstream of the bridge and gravel downstream.',
    query:
        'Which site leaves fine sediment above its bridge after a spring flood?'
  ),
  (
    passage:
        'At Blue Basin, spring floods deposit gravel upstream of the bridge and sand downstream.',
    query:
        'Which site leaves fine sediment below its bridge after a spring flood?'
  ),
  (
    passage:
        'At Red Basin, autumn floods deposit gravel upstream of the bridge and sand downstream.',
    query: 'Where do autumn floods leave coarse material above the bridge?'
  ),
  (
    passage:
        'At Blue Basin, autumn floods deposit sand upstream of the bridge and gravel downstream.',
    query: 'Where do autumn floods leave coarse material below the bridge?'
  ),
  (
    passage:
        'The Alder trial gave patients drug A before meals and drug B afterward.',
    query: 'Which trial administered B after eating and A beforehand?'
  ),
  (
    passage:
        'The Birch trial gave patients drug B before meals and drug A afterward.',
    query: 'Which trial administered A after eating and B beforehand?'
  ),
  (
    passage:
        'The Alder trial gave patients drug C before sleep and drug D afterward.',
    query: 'In which trial did D follow sleep and C precede it?'
  ),
  (
    passage:
        'The Birch trial gave patients drug D before sleep and drug C afterward.',
    query: 'In which trial did C follow sleep and D precede it?'
  ),
  (
    passage:
        'The 1994 archive lists Mara as editor and Niko as translator of the travel diary.',
    query: 'Who translated the diary edited by Mara in 1994?'
  ),
  (
    passage:
        'The 1994 archive lists Niko as editor and Mara as translator of the travel diary.',
    query: 'Who translated the diary edited by Niko in 1994?'
  ),
  (
    passage:
        'The 2004 archive lists Mara as editor and Niko as translator of the field journal.',
    query: 'Who translated the field journal edited by Mara in 2004?'
  ),
  (
    passage:
        'The 2004 archive lists Niko as editor and Mara as translator of the field journal.',
    query: 'Who translated the field journal edited by Niko in 2004?'
  ),
  (
    passage:
        'In dry weather, the west gate opens to cyclists but not delivery vans.',
    query:
        'Which entrance permits bicycles but excludes delivery vans when it is dry?'
  ),
  (
    passage:
        'In dry weather, the east gate opens to delivery vans but not cyclists.',
    query:
        'Which entrance permits delivery vans but excludes bicycles when it is dry?'
  ),
  (
    passage:
        'In wet weather, the west gate opens to delivery vans but not cyclists.',
    query: 'Which entrance permits delivery vans but excludes bicycles in rain?'
  ),
  (
    passage:
        'In wet weather, the east gate opens to cyclists but not delivery vans.',
    query: 'Which entrance permits bicycles but excludes delivery vans in rain?'
  ),
  (
    passage:
        'Aster station records a higher winter temperature than Bell station but a lower summer temperature.',
    query: 'Which station is warmer in winter yet cooler in summer than Bell?'
  ),
  (
    passage:
        'Bell station records a higher winter temperature than Aster station but a lower summer temperature.',
    query: 'Which station is warmer in winter yet cooler in summer than Aster?'
  ),
  (
    passage:
        'Aster station records more winter rain than Bell station but less summer rain.',
    query: 'Which station is wetter in winter yet drier in summer than Bell?'
  ),
  (
    passage:
        'Bell station records more winter rain than Aster station but less summer rain.',
    query: 'Which station is wetter in winter yet drier in summer than Aster?'
  ),
  (
    passage:
        'The copper valve stops water reaching tank A while allowing it to reach tank B.',
    query: 'Which valve keeps water out of A without blocking the supply to B?'
  ),
  (
    passage:
        'The silver valve stops water reaching tank B while allowing it to reach tank A.',
    query: 'Which valve keeps water out of B without blocking the supply to A?'
  ),
  (
    passage:
        'The copper valve stops air reaching tank B while allowing it to reach tank A.',
    query: 'Which valve keeps air out of B without blocking the supply to A?'
  ),
  (
    passage:
        'The silver valve stops air reaching tank A while allowing it to reach tank B.',
    query: 'Which valve keeps air out of A without blocking the supply to B?'
  ),
  (
    passage:
        'The 1972 survey placed the old mill east of the river and the new mill west of it.',
    query: 'In the 1972 survey, which mill stood on the eastern bank?'
  ),
  (
    passage:
        'The 1982 survey placed the new mill east of the river and the old mill west of it.',
    query: 'In the 1982 survey, which mill stood on the eastern bank?'
  ),
  (
    passage:
        'The 1972 survey placed the old tower north of the lake and the new tower south of it.',
    query: 'In the 1972 survey, which tower stood on the southern shore?'
  ),
  (
    passage:
        'The 1982 survey placed the new tower north of the lake and the old tower south of it.',
    query: 'In the 1982 survey, which tower stood on the southern shore?'
  ),
  (
    passage:
        'The amber plan refunds train tickets but excludes hotel reservations when a trip is cancelled.',
    query: 'Which plan covers rail fares but not lodging after a cancellation?'
  ),
  (
    passage:
        'The blue plan refunds hotel reservations but excludes train tickets when a trip is cancelled.',
    query: 'Which plan covers lodging but not rail fares after a cancellation?'
  ),
  (
    passage:
        'The amber plan refunds hotel reservations but excludes train tickets when a trip is delayed.',
    query: 'Which plan covers lodging but not rail fares after a delay?'
  ),
  (
    passage:
        'The blue plan refunds train tickets but excludes hotel reservations when a trip is delayed.',
    query: 'Which plan covers rail fares but not lodging after a delay?'
  ),
  (
    passage:
        'For mature trees, pruning in March increases fruit yield while pruning in June reduces it.',
    query:
        'When should established trees be pruned to increase fruit production?'
  ),
  (
    passage:
        'For young trees, pruning in June increases fruit yield while pruning in March reduces it.',
    query: 'When should young trees be pruned to increase fruit production?'
  ),
  (
    passage:
        'For mature trees, pruning in June increases leaf growth while pruning in March reduces it.',
    query: 'When should established trees be pruned to increase foliage?'
  ),
  (
    passage:
        'For young trees, pruning in March increases leaf growth while pruning in June reduces it.',
    query: 'When should young trees be pruned to increase foliage?'
  ),
  (
    passage:
        'In the morning, route P takes longer than route Q by bus but less time by bicycle.',
    query: 'Which morning route is slower by bus but faster by bicycle than Q?'
  ),
  (
    passage:
        'In the morning, route Q takes longer than route P by bus but less time by bicycle.',
    query: 'Which morning route is slower by bus but faster by bicycle than P?'
  ),
  (
    passage:
        'In the evening, route P takes longer than route Q by bicycle but less time by bus.',
    query: 'Which evening route is slower by bike but faster by bus than Q?'
  ),
  (
    passage:
        'In the evening, route Q takes longer than route P by bicycle but less time by bus.',
    query: 'Which evening route is slower by bike but faster by bus than P?'
  ),
];

final wikiPassages = List<String>.unmodifiable(_cases.map((c) => c.passage));
final wikiQueries = List<String>.unmodifiable(_cases.map((c) => c.query));
final wikiRelevantPassages =
    List<int>.unmodifiable(List.generate(_cases.length, (index) => index));

/// Mean reciprocal rank at ten. Exact ties share the average rank credit.
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
  if (norms.any((n) => n == 0 || !n.isFinite)) {
    throw const FormatException('Invalid embedding norm');
  }
  var total = 0.0;
  for (var q = 0; q < wikiQueries.length; q++) {
    final query = vectors[wikiPassages.length + q];
    final scores = <double>[];
    for (var d = 0; d < wikiPassages.length; d++) {
      var dot = 0.0;
      for (var i = 0; i < size; i++) {
        dot += query[i] * vectors[d][i];
      }
      scores.add(dot / (norms[wikiPassages.length + q] * norms[d]));
    }
    final relevantScore = scores[wikiRelevantPassages[q]];
    final higher = scores.where((score) => score > relevantScore).length;
    final tied = scores.where((score) => score == relevantScore).length;
    var credit = 0.0;
    for (var rank = higher + 1; rank <= math.min(higher + tied, 10); rank++) {
      credit += 1 / rank;
    }
    total += credit / tied;
  }
  return total * 100 / wikiQueries.length;
}
