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
  // Landscape: alp, cliff, coral reef, geyser, lakeside, promontory,
  // sandbar, seashore, valley, volcano.
  _Run(970, 980, 'Nature'),
  // Flowers, trees and fungi.
  _Run(984, 998, 'Nature'),
];

const _singles = <int, String>{
  // Vehicles, scattered through the object classes.
  404: 'Vehicles', // airliner
  405: 'Vehicles', // airship
  407: 'Vehicles', // ambulance
  408: 'Vehicles', // amphibious vehicle
  417: 'Vehicles', // balloon
  436: 'Vehicles', // beach wagon
  444: 'Vehicles', // tandem bicycle
  466: 'Vehicles', // bullet train
  468: 'Vehicles', // cab
  472: 'Vehicles', // canoe
  484: 'Vehicles', // catamaran
  510: 'Vehicles', // container ship
  511: 'Vehicles', // convertible
  547: 'Vehicles', // electric locomotive
  554: 'Vehicles', // fireboat
  555: 'Vehicles', // fire engine
  565: 'Vehicles', // freight car
  569: 'Vehicles', // garbage truck
  576: 'Vehicles', // gondola
  581: 'Vehicles', // grille
  609: 'Vehicles', // jeep
  625: 'Vehicles', // lifeboat
  627: 'Vehicles', // limousine
  628: 'Vehicles', // liner
  654: 'Vehicles', // minibus
  656: 'Vehicles', // minivan
  661: 'Vehicles', // Model T
  665: 'Vehicles', // moped
  670: 'Vehicles', // motor scooter
  671: 'Vehicles', // mountain bike
  675: 'Vehicles', // moving van
  705: 'Vehicles', // passenger car
  717: 'Vehicles', // pickup
  751: 'Vehicles', // racer
  779: 'Vehicles', // school bus
  780: 'Vehicles', // schooner
  803: 'Vehicles', // snowplough
  814: 'Vehicles', // speedboat
  817: 'Vehicles', // sports car
  820: 'Vehicles', // steam locomotive
  864: 'Vehicles', // tow truck
  867: 'Vehicles', // trailer truck
  871: 'Vehicles', // trimaran
  874: 'Vehicles', // trolleybus
  895: 'Vehicles', // warplane
  914: 'Vehicles', // yawl

  // Buildings and streets.
  415: 'City', // bakery
  424: 'City', // barbershop
  425: 'City', // barn
  437: 'City', // beacon
  449: 'City', // boathouse
  454: 'City', // bookshop
  467: 'City', // butcher shop
  483: 'City', // castle
  497: 'City', // church
  498: 'City', // cinema
  509: 'City', // confectionery
  538: 'City', // dome
  580: 'City', // greenhouse
  582: 'City', // grocery store
  624: 'City', // library
  634: 'City', // lumbermill
  649: 'City', // megalith
  663: 'City', // monastery
  668: 'City', // mosque
  682: 'City', // obelisk
  698: 'City', // palace
  718: 'City', // pier
  727: 'City', // planetarium
  743: 'City', // prison
  762: 'City', // restaurant
  788: 'City', // shoe shop
  821: 'City', // steel arch bridge
  832: 'City', // stupa
  839: 'City', // suspension bridge
  860: 'City', // tobacco shop
  865: 'City', // toyshop
  873: 'City', // triumphal arch
  888: 'City', // viaduct
  900: 'City', // water tower

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
