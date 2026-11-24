import 'dart:math' as math;

import 'pta_chemistry.dart';
import 'pta_lab.dart';

/// The candidate substances listed for one unknown jar.
class PtaSet {
  const PtaSet(this.id, this.title, this.level, this.ids, this.focus)
    : bookletNumber = null;

  const PtaSet.booklet(this.bookletNumber, this.ids)
    : id = 'booklet-$bookletNumber',
      title = 'Stof $bookletNumber',
      level = Level.havo,
      focus = '';

  final String id;
  final String title;
  final Level level;
  final List<String> ids;
  final int? bookletNumber;

  /// What the set trains, shown under its title.
  final String focus;

  List<Substance> get candidates => [for (final id in ids) substanceById(id)];
}

/// Candidate groups printed in the HAVO 5 preparation booklet.
const havoBookletSets = [
  PtaSet.booklet(1, ['metal-cu', 'metal-zn']),
  PtaSet.booklet(2, ['kcl', 'ki']),
  PtaSet.booklet(3, ['feso4', 'fe2so43']),
  PtaSet.booklet(4, ['br2', 'i2', 'feno33-aq']),
  PtaSet.booklet(5, ['metal-ca', 'metal-ag', 'metal-zn']),
  PtaSet.booklet(6, ['na2so4', 'na2so3', 'na2s']),
  PtaSet.booklet(7, ['feno32', 'feno33', 'znno32', 'bano3']),
  PtaSet.booklet(8, ['kno3', 'bano3', 'znno32', 'cuno32']),
  PtaSet.booklet(9, ['na2so4', 'na2so3', 'na3po4', 'na2s']),
  PtaSet.booklet(10, ['kcl', 'kbr', 'ki', 'kno3']),
  PtaSet.booklet(11, ['znoh2', 'baoh2', 'koh', 'h2o2']),
  PtaSet.booklet(12, ['metal-zn', 'metal-fe', 'metal-na', 'metal-cu']),
  PtaSet.booklet(13, ['bano3', 'baco3', 'bacl2', 'baso4']),
  PtaSet.booklet(14, ['al2so43', 'feno32', 'znno32', 'ki']),
  PtaSet.booklet(15, ['na3po4', 'na2so3', 'ca3po42', 'caso3']),
  PtaSet.booklet(16, ['agno3', 'bano3', 'znno32', 'pbno32']),
  PtaSet.booklet(17, ['baso4', 'na2so4', 'baso3', 'na2so3']),
  PtaSet.booklet(18, ['cl2', 'baryta', 'lye', 'water']),
  PtaSet.booklet(19, ['nacl', 'na2so4', 'naoh', 'na2co3']),
  PtaSet.booklet(20, ['hcl', 'lye', 'limewater', 'h2so4']),
  PtaSet.booklet(21, ['nh3', 'nh4cl', 'cao', 'nahco3']),
  PtaSet.booklet(23, ['na2o', 'baoh2', 'cuo', 'water']),
  PtaSet.booklet(24, ['na3po4', 'nai', 'na2co3', 'nacl']),
  PtaSet.booklet(25, ['bano3', 'baso4', 'baco3', 'bao']),
  PtaSet.booklet(26, ['hexane', 'ethane', 'ethanol', 'water']),
  PtaSet.booklet(27, ['agno3', 'pbno32', 'znno32', 'feno32']),
  PtaSet.booklet(28, ['hcl', 'h2so4', 'hno3', 'h2c2o4']),
  PtaSet.booklet(29, ['nh42so4', 'feso4', 'fe2so43', 'na2so4']),
  PtaSet.booklet(30, ['baso4', 'baco3', 'ba3po42', 'bano3']),
  PtaSet.booklet(31, ['nh3', 'lye', 'limewater', 'water']),
  PtaSet.booklet(32, ['water', 'ethanol', 'hac', 'nh4no3-aq']),
  PtaSet.booklet(33, ['metal-ca', 'metal-zn', 'metal-fe', 'metal-ag']),
  PtaSet.booklet(34, ['bacl2', 'baco3', 'baso4', 'starch']),
  PtaSet.booklet(35, ['na2so3', 'na2so4', 'na2co3', 'na2s']),
  PtaSet.booklet(36, ['cuno32', 'feno32', 'feno33', 'agno3']),
  PtaSet.booklet(37, ['h2o2', 'hcl', 'hi', 'water']),
  PtaSet.booklet(38, ['nano3', 'nacl', 'na2so4', 'na2co3']),
  PtaSet.booklet(39, ['nano3', 'nh4no3', 'lino3', 'srno32']),
  PtaSet.booklet(40, ['hac', 'h2c2o4', 'hcl', 'h2so4']),
];

List<PtaSet> examSets(Level level, math.Random rng) {
  if (level == Level.vwo) {
    final sets = setsFor(level)..shuffle(rng);
    return sets.take(4).toList();
  }
  final sets = <PtaSet>[];
  for (final section in const [
    [13, 15, 17, 24, 25, 30, 34, 38],
    [7, 9, 10, 14, 16, 27, 35, 36],
    [18, 20, 21, 28, 31, 32, 37, 40],
    [8, 11, 12, 19, 23, 26, 29, 33, 39],
  ]) {
    final number = section[rng.nextInt(section.length)];
    sets.add(havoBookletSets.firstWhere((set) => set.bookletNumber == number));
  }
  return sets;
}

const ptaSets = <PtaSet>[
  PtaSet('h-na', 'Natriumzouten', Level.havo,
      ['nacl', 'na2so4', 'na2co3', 'nano3'],
      'Neerslagreacties (45A) en gasontwikkeling met zuur'),
  PtaSet('h-nh4', 'Ammonium of natrium?', Level.havo,
      ['nh4cl', 'nh42so4', 'nacl', 'na2so4'],
      'Ammonium aantonen met loog en een negatief ion met een neerslag'),
  PtaSet('h-sulfates', 'Metaalsulfaten', Level.havo,
      ['cuso4', 'feso4', 'znso4', 'mgso4'],
      'Kleuren (65B) en hydroxiden met natronloog'),
  PtaSet('h-carbonates', 'Carbonaten', Level.havo,
      ['caco3', 'na2co3', 'nahco3', 'cacl2'],
      'Oplosbaarheid, pH (49) en verhitten'),
  PtaSet('h-chlorides', 'Chloriden', Level.havo,
      ['kcl', 'nacl', 'cacl2', 'bacl2'],
      'Vlamkleuren (65A) en sulfaatneerslagen'),
  PtaSet('h-insoluble', 'Oplosbaar of niet?', Level.havo,
      ['caco3', 'baso4', 'na2co3', 'na2so4'],
      'Oplosbaarheid (45A) en reactie met zuur'),
  PtaSet('h-ammoniumcarbonate', 'Ammonium en carbonaat', Level.havo,
      ['nh42co3', 'nh4cl', 'na2co3', 'nacl'],
      'Twee ionen tegelijk aantonen'),
  PtaSet('v-halides', 'Halogeniden', Level.vwo,
      ['nacl', 'nabr', 'nai', 'nano3'],
      'Zilverhalogeniden en redox met broomwater (48)'),
  PtaSet('v-iron', 'IJzer en koper', Level.vwo,
      ['feso4', 'fecl3', 'cuso4', 'zncl2'],
      'Redox met permanganaat en jodide, thiocyanaat'),
  PtaSet('v-sulfur', 'Zwavelzouten', Level.vwo,
      ['na2co3', 'na2so3', 'na2s2o3', 'na2so4'],
      'Zuur-base (49) en redox (48) bij zwavelverbindingen'),
  PtaSet('v-reductors', 'Reductoren', Level.vwo,
      ['nai', 'nabr', 'na2so3', 'na2s2o3'],
      'Welke stof reduceert jood, welke wordt geoxideerd? (48)'),
  PtaSet('v-organic', 'Zwakke basen', Level.vwo,
      ['na2c2o4', 'na2co3', 'ch3coona', 'na2so4'],
      'pH (49) en oxalaat met warm permanganaat'),
  PtaSet('v-phosphate', 'Fosfaat', Level.vwo,
      ['na3po4', 'nacl', 'na2so4', 'nano3'],
      'Neerslagen die wel of niet in zuur oplossen'),
  PtaSet('v-amphoteric', 'Amfotere hydroxiden', Level.vwo,
      ['mgcl2', 'alcl3', 'zncl2', 'nacl'],
      'Overmaat natronloog en de pH van metaalionen'),
  PtaSet('v-redox-sulfates', 'Sulfaten en redox', Level.vwo,
      ['feso4', 'na2so3', 'znso4', 'na2so4'],
      'Reductoren aantonen met permanganaat'),
];

List<PtaSet> setsFor(Level level) => [
      for (final s in ptaSets)
        if (level == Level.vwo || s.level == Level.havo) s,
    ];

/// One test as a fixed recipe, run on a fresh lab, used for the
/// what-would-each-substance-show table on the result screen.
class StandardTest {
  const StandardTest(this.title, this.run);
  final String title;
  final List<String> Function(PtaLab lab) run;
}

List<String> _obs(LabEntry e) => e.observations;

List<String> _dissolved(PtaLab lab) {
  lab.addSample(0);
  return _obs(lab.addWater(0));
}

List<String> _reagent(PtaLab lab, String id, [Dose dose = Dose.drops]) =>
    _obs(lab.addReagent(0, reagentById(id), dose));

List<String> _labelled(String label, List<String> obs) =>
    ['$label: ${obs.join(' ')}'];

final standardTests = <StandardTest>[
  StandardTest('Uiterlijk', (lab) => _obs(lab.inspect())),
  StandardTest('Oplossen in water', _dissolved),
  StandardTest('pH (indicatorpapier)', (lab) {
    lab.addSample(0);
    if (lab.tubes[0].solid != null) lab.addWater(0);
    return _obs(lab.paper(0));
  }),
  StandardTest('Vlamkleur', (lab) => _obs(lab.flameTest())),
  StandardTest('Monster verwarmen', (lab) {
    lab.addSample(0);
    final out = [..._obs(lab.heat(0))];
    final gases = lab.tubes[0].headspace;
    if (gases.contains(Gas.co2)) {
      out.addAll(_labelled('Kalkwater', _obs(lab.gasTest(0, GasTest.limewater))));
    }
    if (gases.contains(Gas.o2)) {
      out.addAll(_labelled('Gloeiend houtje',
          _obs(lab.gasTest(0, GasTest.glowingSplint))));
    }
    if (gases.contains(Gas.nh3)) {
      out.addAll(_labelled('Lakmoes', _obs(lab.gasTest(0, GasTest.litmus))));
    }
    return out;
  }),
  StandardTest('Zoutzuur (+ gas door kalkwater)', (lab) {
    _dissolved(lab);
    final out = [
      ..._labelled('Druppels', _reagent(lab, 'hcl')),
    ];
    if (lab.tubes[0].headspace.isNotEmpty) {
      out.addAll(_labelled('Kalkwater', _obs(lab.gasTest(0, GasTest.limewater))));
    }
    out.addAll(_labelled('Joodpapier', _obs(lab.gasTest(0, GasTest.iodinePaper))));
    return out;
  }),
  StandardTest('Zoutzuur direct op een vers monster', (lab) {
    lab.addSample(0);
    return _reagent(lab, 'hcl', Dose.excess);
  }),
  StandardTest('Natronloog (druppels, overmaat, verwarmen)', (lab) {
    _dissolved(lab);
    return [
      ..._labelled('Druppels', _reagent(lab, 'naoh')),
      ..._labelled('Overmaat', _reagent(lab, 'naoh', Dose.excess)),
      ..._labelled('Verwarmen', _obs(lab.heat(0))),
      ..._labelled('Lakmoes', _obs(lab.gasTest(0, GasTest.litmus))),
    ];
  }),
  StandardTest('Bariumnitraat, daarna salpeterzuur', (lab) {
    _dissolved(lab);
    return [
      ..._labelled('Ba(NO₃)₂', _reagent(lab, 'bano3')),
      ..._labelled('HNO₃', _reagent(lab, 'hno3', Dose.excess)),
    ];
  }),
  StandardTest('Zilvernitraat, daarna salpeterzuur', (lab) {
    _dissolved(lab);
    return [
      ..._labelled('AgNO₃', _reagent(lab, 'agno3')),
      ..._labelled('HNO₃', _reagent(lab, 'hno3', Dose.excess)),
    ];
  }),
  StandardTest('Verdund zwavelzuur', (lab) {
    _dissolved(lab);
    return _reagent(lab, 'h2so4');
  }),
  StandardTest('Kalkwater', (lab) {
    _dissolved(lab);
    return _reagent(lab, 'limewater');
  }),
  StandardTest('Kaliumjodide + zetmeel', (lab) {
    _dissolved(lab);
    return [
      ..._labelled('KI', _reagent(lab, 'ki')),
      ..._labelled('Zetmeel', _reagent(lab, 'starch')),
    ];
  }),
  StandardTest('Kaliumjodide', (lab) {
    _dissolved(lab);
    return _reagent(lab, 'ki', Dose.excess);
  }),
  StandardTest('Kaliumthiocyanaat', (lab) {
    _dissolved(lab);
    return _reagent(lab, 'kscn');
  }),
  StandardTest('IJzer(II)sulfaatoplossing', (lab) {
    lab.addSample(0);
    return _reagent(lab, 'feso4', Dose.excess);
  }),
  StandardTest('Broomwater + hexaan', (lab) {
    _dissolved(lab);
    return [
      ..._labelled('Broomwater', _reagent(lab, 'br2')),
      ..._labelled('Hexaan', _reagent(lab, 'hexane')),
    ];
  }),
  StandardTest('Joodoplossing', (lab) {
    _dissolved(lab);
    return _reagent(lab, 'i2');
  }),
  StandardTest('Aangezuurd KMnO₄ (+ verwarmen)', (lab) {
    _dissolved(lab);
    return [
      ..._labelled('KMnO₄', _reagent(lab, 'kmno4')),
      ..._labelled('Verwarmen', _obs(lab.heat(0))),
    ];
  }),
  StandardTest('Waterstofperoxide + zetmeel', (lab) {
    _dissolved(lab);
    return [
      ..._labelled('H₂O₂', _reagent(lab, 'h2o2')),
      ..._labelled('Zetmeel', _reagent(lab, 'starch')),
    ];
  }),
  StandardTest('Magnesiumlint', (lab) {
    _dissolved(lab);
    return _obs(lab.addMetal(0, Metal.mg));
  }),
];

/// What [s] shows for [test], as one line.
String expectedFor(Substance s, StandardTest test) =>
    test.run(PtaLab(s)).join(' ');

/// Rows of the result table: test title → one line per candidate.
List<(String, List<String>)> expectedTable(List<Substance> candidates) => [
      for (final test in standardTests)
        (test.title, [for (final c in candidates) expectedFor(c, test)]),
    ];

final _signatures = <String, String>{};

String _signature(Substance s) => _signatures.putIfAbsent(
      s.id,
      () => [for (final t in standardTests) expectedFor(s, t)].join('|'),
    );

/// True when no two candidates give the same result on every test.
bool distinguishable(List<Substance> candidates) =>
    {for (final c in candidates) _signature(c)}.length == candidates.length;

/// Four random candidates for [level] that the standard tests can tell apart.
PtaSet randomSet(Level level, math.Random rng) {
  final pool = [
    for (final s in substances)
      if (s.candidate && (level == Level.vwo || s.level == Level.havo)) s,
  ]..shuffle(rng);
  final signatures = <String>{};
  final ids = <String>[];
  for (final substance in pool) {
    if (!signatures.add(_signature(substance))) continue;
    ids.add(substance.id);
    if (ids.length == 4) break;
  }
  return PtaSet(
    'random',
    'Willekeurige set',
    level,
    ids,
    'Vier willekeurige stoffen',
  );
}
