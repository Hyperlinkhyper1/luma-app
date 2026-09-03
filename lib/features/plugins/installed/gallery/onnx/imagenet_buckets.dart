/// Maps ImageNet-1k class indices onto the gallery's smart albums.
///
/// The classifier answers with one of a thousand classes — "golden retriever",
/// "cheeseburger", "sports car" — which is far finer than anyone browses by.
/// ImageNet's ordering is WordNet's, so related classes sit in contiguous
/// runs, and the big ones can be expressed as ranges: every dog breed is
/// 151–268, every dish is 924–969.
///
/// Where a bucket has no run of its own — vehicles and buildings are
/// scattered through the object classes — the individual indices are listed.
/// The coverage is deliberately partial: a class that maps to nothing simply
/// doesn't put its photo in an album, which is no worse than not having
/// looked. Bucket names match the ones the ML Kit path produces, so both
/// platforms build the same albums.
library;

/// A run of class indices, inclusive at both ends.
class _Run {
  const _Run(this.from, this.to, this.bucket);
  final int from;
  final int to;
  final String bucket;
}

const _runs = <_Run>[
  // Fish and sharks.
  _Run(0, 6, 'Animals'),
  // Birds: the songbirds and raptors, then the fowl and parrots.
  _Run(7, 24, 'Animals'),
  _Run(80, 100, 'Animals'),
  _Run(127, 146, 'Animals'),
  // Amphibians, reptiles, snakes and spiders.
  _Run(25, 68, 'Animals'),
  _Run(69, 77, 'Animals'),
  // Every dog breed in the dataset.
  _Run(151, 268, 'Pets'),
  // Wolves, foxes and hyenas.
  _Run(269, 280, 'Animals'),
  // The domestic cats.
  _Run(281, 285, 'Pets'),
  // The big cats, then bears.
  _Run(286, 293, 'Animals'),
  _Run(294, 297, 'Animals'),
  // Insects and butterflies.
  _Run(300, 327, 'Animals'),
  // Rabbits, hamsters and guinea pigs are pets; the hoofed animals that
  // follow them in the ordering are not.
  _Run(330, 338, 'Pets'),
  _Run(339, 353, 'Animals'),
  // Primates and the remaining large mammals.
  _Run(354, 397, 'Animals'),
  // Every prepared dish, fruit and vegetable.
  _Run(924, 969, 'Food'),
  // The landscape run, 970–980, splits between land and water: alp (970),
  // cliff (972), geyser (974), valley (979) and volcano (980) are Nature;
  // coral reef, lakeside, promontory, sandbar and seashore are Ocean, and
  // are listed individually below. Bubble (971) belongs nowhere.
  _Run(970, 970, 'Nature'),
  _Run(972, 972, 'Nature'),
  _Run(974, 974, 'Nature'),
  _Run(979, 980, 'Nature'),
  _Run(973, 973, 'Ocean'),
  _Run(975, 978, 'Ocean'),
  // Flowers, trees and fungi.
  _Run(984, 998, 'Nature'),
];

const _singles = <int, String>{
  // Transport, scattered through the object classes.
  404: 'Transport', // airliner
  405: 'Transport', // airship
  407: 'Transport', // ambulance
  408: 'Transport', // amphibious vehicle
  417: 'Transport', // balloon
  436: 'Transport', // beach wagon
  444: 'Transport', // tandem bicycle
  466: 'Transport', // bullet train
  468: 'Transport', // cab
  472: 'Transport', // canoe
  484: 'Transport', // catamaran
  510: 'Transport', // container ship
  511: 'Transport', // convertible
  547: 'Transport', // electric locomotive
  554: 'Transport', // fireboat
  555: 'Transport', // fire engine
  565: 'Transport', // freight car
  569: 'Transport', // garbage truck
  576: 'Transport', // gondola
  581: 'Transport', // grille
  609: 'Transport', // jeep
  625: 'Transport', // lifeboat
  627: 'Transport', // limousine
  628: 'Transport', // liner
  654: 'Transport', // minibus
  656: 'Transport', // minivan
  661: 'Transport', // Model T
  665: 'Transport', // moped
  670: 'Transport', // motor scooter
  671: 'Transport', // mountain bike
  675: 'Transport', // moving van
  705: 'Transport', // passenger car
  717: 'Transport', // pickup
  751: 'Transport', // racer
  779: 'Transport', // school bus
  780: 'Transport', // schooner
  803: 'Transport', // snowplough
  814: 'Transport', // speedboat
  817: 'Transport', // sports car
  820: 'Transport', // steam locomotive
  864: 'Transport', // tow truck
  867: 'Transport', // trailer truck
  871: 'Transport', // trimaran
  874: 'Transport', // trolleybus
  895: 'Transport', // warplane
  914: 'Transport', // yawl

  // Buildings and streets.
  415: 'Architecture', // bakery
  424: 'Architecture', // barbershop
  425: 'Architecture', // barn
  437: 'Architecture', // beacon
  449: 'Architecture', // boathouse
  454: 'Architecture', // bookshop
  467: 'Architecture', // butcher shop
  483: 'Architecture', // castle
  497: 'Architecture', // church
  498: 'Architecture', // cinema
  509: 'Architecture', // confectionery
  538: 'Architecture', // dome
  580: 'Architecture', // greenhouse
  582: 'Architecture', // grocery store
  624: 'Architecture', // library
  634: 'Architecture', // lumbermill
  649: 'Architecture', // megalith
  663: 'Architecture', // monastery
  668: 'Architecture', // mosque
  682: 'Architecture', // obelisk
  698: 'Architecture', // palace
  718: 'Architecture', // pier
  727: 'Architecture', // planetarium
  743: 'Architecture', // prison
  762: 'Architecture', // restaurant
  788: 'Architecture', // shoe shop
  821: 'Architecture', // steel arch bridge
  832: 'Architecture', // stupa
  839: 'Architecture', // suspension bridge
  860: 'Architecture', // tobacco shop
  865: 'Architecture', // toyshop
  873: 'Architecture', // triumphal arch
  888: 'Architecture', // viaduct
  900: 'Architecture', // water tower

  // Waterside, where a photo of the sea usually lands.
  460: 'Ocean', // breakwater
  536: 'Ocean', // dock
  833: 'Ocean', // submarine
  913: 'Ocean', // wreck

  // Paper and screens.
  916: 'Documents', // web site
  917: 'Documents', // comic book
  918: 'Documents', // crossword puzzle
  921: 'Documents', // book jacket
  922: 'Documents', // menu

  // Things people photograph at events.
  429: 'Celebrations', // baseball
  981: 'Celebrations', // ballplayer
  982: 'Celebrations', // groom
};

/// The smart album an ImageNet class belongs to, or null for the many classes
/// nobody browses by.
String? bucketForImagenetClass(int index) {
  if (index < 0 || index > 999) return null;
  final single = _singles[index];
  if (single != null) return single;
  for (final run in _runs) {
    if (index >= run.from && index <= run.to) return run.bucket;
  }
  return null;
}

/// The bucket names this mapping can produce. Used by tests to keep them in
/// step with the ML Kit path's buckets.
Set<String> get imagenetBuckets => {
      for (final run in _runs) run.bucket,
      ..._singles.values,
    };
