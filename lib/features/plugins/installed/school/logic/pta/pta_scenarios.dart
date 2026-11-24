import 'dart:math' as math;

import 'pta_chemistry.dart';
import 'pta_lab.dart';

/// A set of four candidate substances handed out with the jar.
class PtaSet {
  const PtaSet(this.id, this.title, this.level, this.ids, this.focus);
  final String id;
  final String title;
  final Level level;
  final List<String> ids;

  /// What the set trains, shown under its title.
  final String focus;

  List<Substance> get candidates => [for (final id in ids) substanceById(id)];
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
      'pH (49), geur en oxalaat met warm permanganaat'),
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
    _dissolved(lab);
    return _obs(lab.paper(0));
  }),
  StandardTest('Vlamkleur', (lab) => _obs(lab.flameTest())),
  StandardTest('Droog verhitten', (lab) {
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
    out.addAll(_labelled('Geur', _obs(lab.smell(0))));
    return out;
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
  StandardTest('Kaliumthiocyanaat', (lab) {
    _dissolved(lab);
    return _reagent(lab, 'kscn');
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

/// Four random candidates for [level] that the standard tests can tell
/// apart, plus the one in the jar.
PtaSet randomSet(Level level, math.Random rng) {
  final pool = [
    for (final s in substances)
      if (s.candidate && (level == Level.vwo || s.level == Level.havo)) s,
  ];
  for (var attempt = 0; attempt < 200; attempt++) {
    pool.shuffle(rng);
    final pick = pool.take(4).toList();
    if (distinguishable(pick)) {
      return PtaSet('random', 'Willekeurige set', level,
          [for (final s in pick) s.id], 'Vier willekeurige stoffen');
    }
  }
  return setsFor(level).first;
}
