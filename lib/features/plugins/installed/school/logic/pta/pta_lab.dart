import 'dart:math' as math;
import 'dart:ui' show Color;

import 'pta_chemistry.dart';

const kDropsMl = 0.5;
const kExcessMl = 3.0;
const kWaterMl = 5.0;
const kSampleMmol = 0.5;
const kMaxMl = 20.0;
const kIndicatorMl = 0.1;
const kHexaneMl = 1.5;
const kStarchMl = 0.5;
const kMetalMmol = 2.0;

const _eps = 1e-7;
const _co2PerMl = 0.033;
const _visible = 0.002;

enum Dose { drops, excess }

enum GasTest { limewater, litmus, iodinePaper, glowingSplint, burningSplint }

/// Estimated bench time for each action in the practice log.
const actionMinutes = <String, int>{
  'inspect': 1,
  'sample': 2,
  'water': 1,
  'reagent': 2,
  'indicator': 1,
  'extra': 1,
  'metal': 2,
  'heat': 4,
  'paper': 2,
  'gas': 2,
  'flame': 4,
  'rinse': 2,
};

class Tube {
  final Map<Sp, double> sp = {};
  final Map<Pp, double> pp = {};
  final Map<Metal, double> metals = {};
  final Map<Deposit, double> deposits = {};
  final Set<Indicator> indicators = {};
  double waterMl = 0;
  double ethanolMl = 0;
  double hexaneMl = 0;
  bool starch = false;
  Substance? solid;
  double solidMmol = 0;
  bool solidHeated = false;
  int warm = 0;
  Set<Gas> headspace = {};

  /// Set by the last action: visible gas, the burner under the tube.
  bool bubbling = false;
  bool heating = false;

  bool get hot => warm > 0;
  double get totalMl => waterMl + ethanolMl + hexaneMl;
  bool get isEmpty =>
      totalMl <= 0 && solid == null && metals.isEmpty;

  double amt(Sp s) => sp[s] ?? 0;
  double ppAmt(Pp p) => pp[p] ?? 0;

  void add(Sp s, double v) {
    final n = amt(s) + v;
    if (n.abs() < 1e-12) {
      sp.remove(s);
    } else {
      sp[s] = n < 0 && n > -1e-9 ? 0 : n;
    }
  }

  void addPp(Pp p, double v) {
    final n = ppAmt(p) + v;
    if (n < 1e-12) {
      pp.remove(p);
    } else {
      pp[p] = n;
    }
  }

  Tube copy() {
    final t = Tube()
      ..waterMl = waterMl
      ..ethanolMl = ethanolMl
      ..hexaneMl = hexaneMl
      ..starch = starch
      ..solid = solid
      ..solidMmol = solidMmol
      ..solidHeated = solidHeated
      ..warm = warm
      ..headspace = {...headspace};
    t.sp.addAll(sp);
    t.pp.addAll(pp);
    t.metals.addAll(metals);
    t.deposits.addAll(deposits);
    t.indicators.addAll(indicators);
    return t;
  }

  void clear() {
    sp.clear();
    pp.clear();
    metals.clear();
    deposits.clear();
    indicators.clear();
    waterMl = 0;
    ethanolMl = 0;
    hexaneMl = 0;
    starch = false;
    solid = null;
    solidMmol = 0;
    solidHeated = false;
    warm = 0;
    headspace = {};
    bubbling = false;
    heating = false;
  }
}

// ---------------------------------------------------------------------------
// pH from the charge balance.

final _systemMembers = {for (final s in acidBaseSystems) ...s.members};

List<double> _fractions(AcidBase s, double ph) {
  final logs = <double>[];
  var acc = 0.0;
  for (var k = 0; k <= s.pKa.length; k++) {
    if (k > 0) acc += -s.pKa[k - 1];
    logs.add(acc + k * ph);
  }
  final top = logs.reduce(math.max);
  final w = [for (final l in logs) math.pow(10, l - top).toDouble()];
  final sum = w.fold(0.0, (a, b) => a + b);
  return [for (final x in w) x / sum];
}

double _systemTotal(Tube t, AcidBase s) =>
    s.members.fold(0.0, (a, m) => a + t.amt(m));

/// The tube's pH, or null when there is no water in it.
double? phOf(Tube t) {
  final v = t.waterMl;
  if (v <= 0) return null;
  var strong = 0.0;
  for (final e in t.sp.entries) {
    if (e.key == Sp.h || e.key == Sp.oh) continue;
    if (_systemMembers.contains(e.key)) continue;
    strong += e.key.charge * e.value / v;
  }
  final totals = [for (final s in acidBaseSystems) _systemTotal(t, s) / v];
  double f(double ph) {
    final h = math.pow(10, -ph).toDouble();
    var sum = strong + h - 1e-14 / h;
    for (var i = 0; i < acidBaseSystems.length; i++) {
      final c = totals[i];
      if (c <= 0) continue;
      final s = acidBaseSystems[i];
      final fr = _fractions(s, ph);
      var avg = 0.0;
      for (var k = 0; k < fr.length; k++) {
        avg += fr[k] * (s.topCharge - k);
      }
      sum += c * avg;
    }
    return sum;
  }

  var lo = -1.5, hi = 15.5;
  if (f(lo) <= 0) return lo;
  if (f(hi) >= 0) return hi;
  for (var i = 0; i < 70; i++) {
    final mid = (lo + hi) / 2;
    if (f(mid) > 0) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/// How much of [form] a tube holds at its pH, counting every member of the
/// acid–base system it belongs to (so stored NH₄⁺ still counts as NH₃ in a
/// basic solution).
double speciated(Tube t, Sp form) {
  final ph = phOf(t);
  if (ph == null) return 0;
  for (final s in acidBaseSystems) {
    final i = s.members.indexOf(form);
    if (i < 0) continue;
    final idx = s.members.length == s.pKa.length + 1 ? i : 0;
    return _systemTotal(t, s) * _fractions(s, ph)[idx];
  }
  return t.amt(form);
}

// ---------------------------------------------------------------------------
// Reactions.

enum Medium { any, acid, notAcid }

class Redox {
  const Redox(
    this.id,
    this.reactants,
    this.products, {
    required this.equation,
    required this.why,
    this.solids = const {},
    this.gas,
    this.gasCoef = 0,
    this.medium = Medium.any,
    this.needsHeat = false,
    this.slow = false,
    this.guard,
    this.share,
  });

  final String id;
  final List<(List<Sp>, double)> reactants;
  final Map<Sp, double> products;
  final Map<Pp, double> solids;
  final Gas? gas;
  final double gasCoef;
  final Medium medium;
  final bool needsHeat;
  final bool slow;
  final String equation;
  final String why;

  /// Extra condition beyond [medium], checked on the tube before reacting.
  final bool Function(Tube t)? guard;

  /// For a slow reaction: the part of what could react that does react
  /// while you watch, applied once per action.
  final double? share;
}

/// Bromine disproportionates in clearly basic solutions.
bool _bromineBasic(Tube t) => (phOf(t) ?? 7) > 10;

/// Iodine only disproportionates when there is little iodide: with excess
/// I⁻ it is held as I₃⁻ and the brown colour stays, even at high pH.
bool _iodineBasic(Tube t) {
  final ph = phOf(t) ?? 7;
  if (ph <= 10) return false;
  final iodide = t.amt(Sp.i) / t.waterMl;
  if (iodide < 1e-6) return true;
  final oh = math.pow(10, ph - 14).toDouble();
  return 30 * oh / iodide / (1 + 700 * iodide) > 1;
}

const _s4 = [Sp.so3, Sp.hso3, Sp.so2];
const _ox = [Sp.c2o4, Sp.hc2o4, Sp.h2c2o4];

const redoxReactions = <Redox>[
  Redox('cl2_i', [([Sp.cl2], 1), ([Sp.i], 2)], {Sp.cl: 2, Sp.i2: 1},
      equation: 'Cl₂(aq) + 2 I⁻(aq) → 2 Cl⁻(aq) + I₂(aq)',
      why: 'Chloor oxideert jodide tot jood (Binas 48).'),
  Redox('cl2_oh', [([Sp.cl2], 1), ([Sp.oh], 2)], {Sp.cl: 1, Sp.clo: 1},
      equation: 'Cl₂(aq) + 2 OH⁻(aq) → Cl⁻(aq) + ClO⁻(aq) + H₂O(l)',
      why: 'Chloor reageert met hydroxide tot chloride en hypochloriet.'),
  Redox('i2_sulfide', [([Sp.i2], 1), ([Sp.sulfide], 1)], {Sp.i: 2},
      solids: {Pp.sulfur: 1},
      equation: 'I₂(aq) + S²⁻(aq) → 2 I⁻(aq) + S(s)',
      why: 'Jood oxideert sulfide tot vaste zwavel.'),
  Redox('mno4_fe2', [([Sp.mno4], 1), ([Sp.fe2], 5)], {Sp.mn2: 1, Sp.fe3: 5},
      medium: Medium.acid,
      equation: 'MnO₄⁻ + 5 Fe²⁺ + 8 H⁺ → Mn²⁺ + 5 Fe³⁺ + 4 H₂O',
      why: 'MnO₄⁻ (V⁰ = 1,51 V) is een sterkere oxidator dan Fe³⁺ (0,77 V), dus Fe²⁺ wordt geoxideerd (Binas 48).'),
  Redox('mno4_s4', [([Sp.mno4], 2), (_s4, 5)], {Sp.mn2: 2, Sp.so4: 5},
      medium: Medium.acid,
      equation: '2 MnO₄⁻ + 5 SO₃²⁻ + 6 H⁺ → 2 Mn²⁺ + 5 SO₄²⁻ + 3 H₂O',
      why: 'Sulfiet is een reductor (SO₄²⁻/SO₂: 0,17 V); MnO₄⁻ (1,51 V) oxideert het tot sulfaat (Binas 48).'),
  Redox('mno4_s2o3', [([Sp.mno4], 8), ([Sp.s2o3], 5)], {Sp.mn2: 8, Sp.so4: 10},
      medium: Medium.acid,
      equation: '8 MnO₄⁻ + 5 S₂O₃²⁻ + 14 H⁺ → 8 Mn²⁺ + 10 SO₄²⁻ + 7 H₂O',
      why: 'Thiosulfaat is een reductor; MnO₄⁻ (1,51 V) oxideert het.'),
  Redox('mno4_i', [([Sp.mno4], 2), ([Sp.i], 10)], {Sp.mn2: 2, Sp.i2: 5},
      medium: Medium.acid,
      equation: '2 MnO₄⁻ + 10 I⁻ + 16 H⁺ → 2 Mn²⁺ + 5 I₂ + 8 H₂O',
      why: 'MnO₄⁻ (1,51 V) is een sterkere oxidator dan I₂ (0,54 V): jodide wordt jood.'),
  Redox('mno4_h2o2', [([Sp.mno4], 2), ([Sp.h2o2], 5)], {Sp.mn2: 2},
      gas: Gas.o2, gasCoef: 5, medium: Medium.acid,
      equation: '2 MnO₄⁻ + 5 H₂O₂ + 6 H⁺ → 2 Mn²⁺ + 5 O₂ + 8 H₂O',
      why: 'H₂O₂ reageert hier als reductor (O₂/H₂O₂: 0,68 V) met MnO₄⁻ (1,51 V).'),
  Redox('mno4_c2o4', [([Sp.mno4], 2), (_ox, 5)], {Sp.mn2: 2, Sp.co2: 10},
      medium: Medium.acid, needsHeat: true,
      equation: '2 MnO₄⁻ + 5 H₂C₂O₄ + 6 H⁺ → 2 Mn²⁺ + 10 CO₂ + 8 H₂O',
      why: 'Oxaalzuur is een reductor (CO₂/H₂C₂O₄: −0,49 V). De reactie met MnO₄⁻ is bij kamertemperatuur traag en verloopt pas goed bij verwarmen.'),
  Redox('mno4_br', [([Sp.mno4], 2), ([Sp.br], 10)], {Sp.mn2: 2, Sp.br2: 5},
      medium: Medium.acid, slow: true,
      equation: '2 MnO₄⁻ + 10 Br⁻ + 16 H⁺ → 2 Mn²⁺ + 5 Br₂ + 8 H₂O',
      why: 'MnO₄⁻ (1,51 V) is sterker dan Br₂ (1,07 V), maar het verschil is klein: de reactie gaat langzaam. Met Cl⁻ (1,36 V) zie je bij kamertemperatuur geen reactie.'),
  Redox('mno4n_s4', [([Sp.mno4], 2), (_s4, 3)], {Sp.so4: 3},
      solids: {Pp.mnO2: 2}, medium: Medium.notAcid,
      equation: '2 MnO₄⁻ + 3 SO₃²⁻ + H₂O → 2 MnO₂ + 3 SO₄²⁻ + 2 OH⁻',
      why: 'In een niet-zure oplossing wordt MnO₄⁻ maar tot MnO₂ (bruinsteen) gereduceerd (Binas 48: 0,59 V).'),
  Redox('mno4n_fe2', [([Sp.mno4], 1), ([Sp.fe2], 3)], {Sp.fe3: 3},
      solids: {Pp.mnO2: 1}, medium: Medium.notAcid,
      equation: 'MnO₄⁻ + 3 Fe²⁺ + 2 H₂O → MnO₂ + 3 Fe³⁺ + 4 OH⁻',
      why: 'In een niet-zure oplossing wordt MnO₄⁻ tot MnO₂ gereduceerd.'),
  Redox('mno4n_s2o3', [([Sp.mno4], 8), ([Sp.s2o3], 3)], {Sp.so4: 6},
      solids: {Pp.mnO2: 8}, medium: Medium.notAcid,
      equation: '8 MnO₄⁻ + 3 S₂O₃²⁻ + H₂O → 8 MnO₂ + 6 SO₄²⁻ + 2 OH⁻',
      why: 'In een niet-zure oplossing wordt MnO₄⁻ tot MnO₂ gereduceerd.'),
  Redox('mno4n_i', [([Sp.mno4], 2), ([Sp.i], 6)], {Sp.i2: 3},
      solids: {Pp.mnO2: 2}, medium: Medium.notAcid,
      equation: '2 MnO₄⁻ + 6 I⁻ + 4 H₂O → 2 MnO₂ + 3 I₂ + 8 OH⁻',
      why: 'In een niet-zure oplossing wordt MnO₄⁻ tot MnO₂ gereduceerd; jodide wordt jood.'),
  Redox('mno4n_h2o2', [([Sp.mno4], 2), ([Sp.h2o2], 3)], {},
      solids: {Pp.mnO2: 2}, gas: Gas.o2, gasCoef: 3, medium: Medium.notAcid,
      equation: '2 MnO₄⁻ + 3 H₂O₂ → 2 MnO₂ + 3 O₂ + 2 OH⁻ + 2 H₂O',
      why: 'In een niet-zure oplossing wordt MnO₄⁻ tot MnO₂ gereduceerd.'),
  Redox('br2_i', [([Sp.br2], 1), ([Sp.i], 2)], {Sp.br: 2, Sp.i2: 1},
      equation: 'Br₂ + 2 I⁻ → 2 Br⁻ + I₂',
      why: 'Br₂ (1,07 V) is een sterkere oxidator dan I₂ (0,54 V): jodide wordt jood (Binas 48).'),
  Redox('br2_fe2', [([Sp.br2], 1), ([Sp.fe2], 2)], {Sp.br: 2, Sp.fe3: 2},
      equation: 'Br₂ + 2 Fe²⁺ → 2 Br⁻ + 2 Fe³⁺',
      why: 'Br₂ (1,07 V) is een sterkere oxidator dan Fe³⁺ (0,77 V).'),
  Redox('br2_s4', [([Sp.br2], 1), (_s4, 1)], {Sp.br: 2, Sp.so4: 1},
      equation: 'Br₂ + SO₃²⁻ + H₂O → 2 Br⁻ + SO₄²⁻ + 2 H⁺',
      why: 'Sulfiet is een reductor die broom omzet in bromide.'),
  Redox('br2_s2o3', [([Sp.br2], 4), ([Sp.s2o3], 1)], {Sp.br: 8, Sp.so4: 2},
      equation: '4 Br₂ + S₂O₃²⁻ + 5 H₂O → 8 Br⁻ + 2 SO₄²⁻ + 10 H⁺',
      why: 'Thiosulfaat is een reductor die broom omzet in bromide.'),
  Redox('br2_oh', guard: _bromineBasic, [([Sp.br2], 1), ([Sp.oh], 2)], {Sp.br: 1, Sp.bro: 1},
      equation: 'Br₂ + 2 OH⁻ → Br⁻ + BrO⁻ + H₂O',
      why: 'In een basische oplossing disproportioneert broom tot bromide en hypobromiet: de kleur verdwijnt ook zonder reductor.'),
  Redox('br2_co3', guard: _bromineBasic, [([Sp.br2], 1), ([Sp.co3], 2)], {Sp.br: 1, Sp.bro: 1, Sp.hco3: 2},
      equation: 'Br₂ + 2 CO₃²⁻ + H₂O → Br⁻ + BrO⁻ + 2 HCO₃⁻',
      why: 'Een carbonaatoplossing is zo basisch dat broom disproportioneert: de kleur verdwijnt ook zonder reductor.'),
  Redox('br2_po4', guard: _bromineBasic, [([Sp.br2], 1), ([Sp.po4], 2)], {Sp.br: 1, Sp.bro: 1, Sp.hpo4: 2},
      equation: 'Br₂ + 2 PO₄³⁻ + H₂O → Br⁻ + BrO⁻ + 2 HPO₄²⁻',
      why: 'Een fosfaatoplossing is zo basisch dat broom disproportioneert: de kleur verdwijnt ook zonder reductor.'),
  Redox('h2o2_i', [([Sp.h2o2], 1), ([Sp.i], 2)], {Sp.i2: 1},
      medium: Medium.acid,
      equation: 'H₂O₂ + 2 I⁻ + 2 H⁺ → I₂ + 2 H₂O',
      why: 'H₂O₂ (1,78 V) is een sterke oxidator: jodide wordt jood.'),
  Redox('h2o2n_i', [([Sp.h2o2], 1), ([Sp.i], 2)], {Sp.i2: 1},
      medium: Medium.notAcid, share: 0.05,
      equation: 'H₂O₂ + 2 I⁻ → I₂ + 2 OH⁻',
      why: 'H₂O₂ (1,78 V) oxideert jodide tot jood. Zonder zuur gaat dat langzaam; aangezuurd gaat het snel.'),
  Redox('h2o2_fe2', [([Sp.h2o2], 1), ([Sp.fe2], 2)], {Sp.fe3: 2},
      equation: 'H₂O₂ + 2 Fe²⁺ + 2 H⁺ → 2 Fe³⁺ + 2 H₂O',
      why: 'H₂O₂ (1,78 V) oxideert Fe²⁺ tot Fe³⁺ (0,77 V).'),
  Redox('h2o2_s4', [([Sp.h2o2], 1), (_s4, 1)], {Sp.so4: 1},
      equation: 'H₂O₂ + SO₃²⁻ → SO₄²⁻ + H₂O',
      why: 'H₂O₂ oxideert sulfiet tot sulfaat; dat zie je niet, want alle deeltjes zijn kleurloos.'),
  Redox('i2_s2o3', [([Sp.i2], 1), ([Sp.s2o3], 2)], {Sp.i: 2, Sp.s4o6: 1},
      equation: 'I₂ + 2 S₂O₃²⁻ → 2 I⁻ + S₄O₆²⁻',
      why: 'Thiosulfaat (S₄O₆²⁻/S₂O₃²⁻: 0,08 V) is een sterkere reductor dan I⁻ (0,54 V): jood wordt jodide.'),
  Redox('i2_s4', [([Sp.i2], 1), (_s4, 1)], {Sp.i: 2, Sp.so4: 1},
      equation: 'I₂ + SO₃²⁻ + H₂O → 2 I⁻ + SO₄²⁻ + 2 H⁺',
      why: 'Sulfiet (0,17 V) is een sterkere reductor dan I⁻ (0,54 V): jood wordt jodide.'),
  Redox('i2_oh', guard: _iodineBasic, [([Sp.i2], 1), ([Sp.oh], 2)], {Sp.i: 1, Sp.io: 1},
      equation: 'I₂ + 2 OH⁻ → I⁻ + IO⁻ + H₂O',
      why: 'In een basische oplossing disproportioneert jood: de bruine kleur verdwijnt ook zonder reductor.'),
  Redox('i2_co3', guard: _iodineBasic, [([Sp.i2], 1), ([Sp.co3], 2)], {Sp.i: 1, Sp.io: 1, Sp.hco3: 2},
      equation: 'I₂ + 2 CO₃²⁻ + H₂O → I⁻ + IO⁻ + 2 HCO₃⁻',
      why: 'Een carbonaatoplossing is zo basisch dat jood disproportioneert: de kleur verdwijnt ook zonder reductor.'),
  Redox('i2_po4', guard: _iodineBasic, [([Sp.i2], 1), ([Sp.po4], 2)], {Sp.i: 1, Sp.io: 1, Sp.hpo4: 2},
      equation: 'I₂ + 2 PO₄³⁻ + H₂O → I⁻ + IO⁻ + 2 HPO₄²⁻',
      why: 'Een fosfaatoplossing is zo basisch dat jood disproportioneert.'),
  Redox('fe3_i', [([Sp.fe3], 2), ([Sp.i], 2)], {Sp.fe2: 2, Sp.i2: 1},
      equation: '2 Fe³⁺ + 2 I⁻ → 2 Fe²⁺ + I₂',
      why: 'Fe³⁺ (0,77 V) is een sterkere oxidator dan I₂ (0,54 V): jodide wordt jood.'),
  Redox('cu_i', [([Sp.cu], 2), ([Sp.i], 4)], {Sp.i2: 1},
      solids: {Pp.cuI: 2},
      equation: '2 Cu²⁺ + 4 I⁻ → 2 CuI(s) + I₂',
      why: 'Cu²⁺ reageert met I⁻ tot slecht oplosbaar CuI (Cu²⁺ + I⁻ + e⁻ → CuI: 0,86 V), sterker dan I₂ (0,54 V).'),
];

final _redoxById = {for (final r in redoxReactions) r.id: r};

/// What happened during one settle, for the log's explanation.
class Events {
  final Map<String, double> amounts = {};
  final Map<Gas, double> gas = {};
  bool slow = false;

  void add(String key, double v) {
    if (v <= 0) return;
    amounts[key] = (amounts[key] ?? 0) + v;
  }

  void addGas(Gas g, double v) {
    if (v <= 0) return;
    gas[g] = (gas[g] ?? 0) + v;
  }

  double operator [](String key) => amounts[key] ?? 0;
}

class _Engine {
  _Engine(this.t, this.ev);
  final Tube t;
  final Events ev;
  bool changed = false;
  final _partial = <String>{};

  double a(Sp s) => t.amt(s);

  void move(Map<Sp, double> delta) {
    for (final e in delta.entries) {
      t.add(e.key, e.value);
    }
    changed = true;
  }

  void fixCharge() {
    var net = 0.0;
    for (final e in t.sp.entries) {
      net += e.key.charge * e.value;
    }
    if (net.abs() < 1e-10) return;
    if (net > 0) {
      final take = math.min(a(Sp.h), net);
      t.add(Sp.h, -take);
      if (net - take > 1e-12) t.add(Sp.oh, net - take);
    } else {
      final need = -net;
      final take = math.min(a(Sp.oh), need);
      t.add(Sp.oh, -take);
      if (need - take > 1e-12) t.add(Sp.h, need - take);
    }
  }

  void neutralize() {
    final n = math.min(a(Sp.h), a(Sp.oh));
    if (n < _eps) return;
    move({Sp.h: -n, Sp.oh: -n});
    ev.add('neutral', n);
  }

  void _protonate(Sp base, Sp acid, [String? key]) {
    final n = math.min(a(base), a(Sp.h));
    if (n < _eps) return;
    move({base: -n, Sp.h: -n, acid: n});
    if (key != null) ev.add(key, n);
  }

  void _deprotonate(Sp acid, Sp base, [String? key]) {
    final n = math.min(a(acid), a(Sp.oh));
    if (n < _eps) return;
    move({acid: -n, Sp.oh: -n, base: n});
    if (key != null) ev.add(key, n);
  }

  static const _firstProton = {
    Sp.co3: Sp.hco3,
    Sp.po4: Sp.hpo4,
    Sp.so3: Sp.hso3,
    Sp.c2o4: Sp.hc2o4,
  };

  void protonate() {
    if (a(Sp.h) < _eps) return;
    var n = math.min(a(Sp.znOH4), a(Sp.h) / 2);
    if (n > _eps) {
      move({Sp.znOH4: -n, Sp.h: -2 * n});
      t.addPp(Pp.znOH2, n);
    }
    n = math.min(a(Sp.alOH4), a(Sp.h));
    if (n > _eps) {
      move({Sp.alOH4: -n, Sp.h: -n});
      t.addPp(Pp.alOH3, n);
    }
    _protonate(Sp.po4, Sp.hpo4);
    _protonate(Sp.co3, Sp.hco3, 'h:co3');
    _protonate(Sp.nh3, Sp.nh4);
    _protonate(Sp.so3, Sp.hso3, 'h:so3');
    _protonate(Sp.hpo4, Sp.h2po4);
    for (final p in Pp.values) {
      if (!p.acidSoluble) continue;
      final have = t.ppAmt(p);
      if (have < 1e-9 || a(Sp.h) < _eps) continue;
      final d = math.min(have, a(Sp.h) / p.b);
      t.addPp(p, -d);
      t.add(p.cation!, p.a * d);
      t.add(Sp.h, -p.b * d);
      if (p.anion != Sp.oh) t.add(_firstProton[p.anion]!, p.b * d);
      changed = true;
      ev.add('dis:${p.name}', d);
    }
    _protonate(Sp.hco3, Sp.co2, 'h:hco3');
    _protonate(Sp.ac, Sp.hac, 'h:ac');
    _protonate(Sp.c2o4, Sp.hc2o4);
    _protonate(Sp.h2po4, Sp.h3po4);
    _protonate(Sp.hso3, Sp.so2, 'h:hso3');
    _protonate(Sp.sulfide, Sp.hs, 'h:sulfide');
    _protonate(Sp.hs, Sp.h2s, 'h:hs');
    n = math.min(a(Sp.s2o3), a(Sp.h) / 2);
    if (n > _eps) {
      move({Sp.s2o3: -n, Sp.h: -2 * n, Sp.so2: n});
      t.addPp(Pp.sulfur, n);
      ev.add('h:s2o3', n);
    }
    _protonate(Sp.hc2o4, Sp.h2c2o4);
  }

  void _hydroxide(Pp p) {
    if (a(Sp.oh) < _eps || a(p.cation!) < _eps) return;
    final x = _kspShift(p, allowDissolve: false);
    if (x <= 1e-9) return;
    t.addPp(p, x);
    t.add(p.cation!, -p.a * x);
    t.add(Sp.oh, -p.b * x);
    changed = true;
    ev.add('pp:${p.name}', x);
  }

  void deprotonate() {
    if (a(Sp.oh) < _eps) return;
    _deprotonate(Sp.h2c2o4, Sp.hc2o4);
    _deprotonate(Sp.h3po4, Sp.h2po4);
    _deprotonate(Sp.so2, Sp.hso3);
    _deprotonate(Sp.hc2o4, Sp.c2o4);
    _deprotonate(Sp.hac, Sp.ac);
    _deprotonate(Sp.co2, Sp.hco3);
    _hydroxide(Pp.feOH3);
    _hydroxide(Pp.alOH3);
    _hydroxide(Pp.cuOH2);
    _hydroxide(Pp.znOH2);
    _deprotonate(Sp.h2po4, Sp.hpo4);
    _deprotonate(Sp.h2s, Sp.hs);
    _deprotonate(Sp.hso3, Sp.so3);
    _hydroxide(Pp.feOH2);
    _hydroxide(Pp.agOH);
    _deprotonate(Sp.nh4, Sp.nh3, 'oh:nh4');
    _hydroxide(Pp.mgOH2);
    _hydroxide(Pp.pbOH2);
    _deprotonate(Sp.hco3, Sp.co3, 'oh:hco3');
    _deprotonate(Sp.hpo4, Sp.po4);
    _hydroxide(Pp.caOH2);
    var n = math.min(t.ppAmt(Pp.znOH2), a(Sp.oh) / 2);
    if (n > _eps) {
      t.addPp(Pp.znOH2, -n);
      move({Sp.oh: -2 * n, Sp.znOH4: n});
      ev.add('amph:zn', n);
    }
    n = math.min(t.ppAmt(Pp.alOH3), a(Sp.oh));
    if (n > _eps) {
      t.addPp(Pp.alOH3, -n);
      move({Sp.oh: -n, Sp.alOH4: n});
      ev.add('amph:al', n);
    }
  }

  /// How far precipitation of [p] moves (mmol of solid; negative means it
  /// dissolves) before the ion product equals Ksp.
  double _kspShift(Pp p, {bool allowDissolve = true}) {
    final v = t.waterMl;
    if (v <= 0) return 0;
    final nM = a(p.cation!), nX = a(p.anion!), nP = t.ppAmt(p);
    final logK = math.log(p.ksp!);
    double logQ(double x) {
      final cm = (nM - p.a * x) / v, cx = (nX - p.b * x) / v;
      if (cm <= 0 || cx <= 0) return double.negativeInfinity;
      return p.a * math.log(cm) + p.b * math.log(cx);
    }

    final lo = allowDissolve ? -nP : 0.0;
    final hi = math.min(nM / p.a, nX / p.b);
    if (nP < 1e-9) {
      final threshold = p.moderate ? logK + math.log(20) : logK;
      if (logQ(0) <= threshold) return 0;
    }
    if (logQ(lo) <= logK) return lo;
    var l = lo, h = hi;
    for (var i = 0; i < 80; i++) {
      final m = (l + h) / 2;
      if (logQ(m) > logK) {
        l = m;
      } else {
        h = m;
      }
    }
    return (l + h) / 2;
  }

  void precipitate() {
    for (final p in Pp.values) {
      if (p.ksp == null || p.anion == Sp.oh) continue;
      if (a(p.cation!) < 1e-9 && t.ppAmt(p) < 1e-9) continue;
      if (a(p.anion!) < 1e-9 && t.ppAmt(p) < 1e-9) continue;
      final x = _kspShift(p);
      if (x.abs() < 1e-8) continue;
      t.addPp(p, x);
      t.add(p.cation!, -p.a * x);
      t.add(p.anion!, -p.b * x);
      changed = true;
      ev.add(x > 0 ? 'pp:${p.name}' : 'dis:${p.name}', x.abs());
    }
  }

  void complexes() {
    final ag = a(Sp.ag), th = a(Sp.s2o3);
    if (ag < _eps || th < _eps) return;
    if (th >= 2 * ag) {
      move({Sp.ag: -ag, Sp.s2o3: -2 * ag, Sp.agS2O3: ag});
      ev.add('complex:ag', ag);
    } else {
      final n = math.min(ag / 2, th);
      move({Sp.ag: -2 * n, Sp.s2o3: -n, Sp.so4: n, Sp.h: 2 * n});
      t.addPp(Pp.ag2S, n);
      ev.add('ag2s', n);
    }
  }

  void redox() {
    for (final r in redoxReactions) {
      if (r.needsHeat && !t.hot) continue;
      var extent = double.infinity;
      for (final (group, coef) in r.reactants) {
        final have = group.fold(0.0, (s, g) => s + a(g));
        extent = math.min(extent, have / coef);
      }
      if (extent < 1e-7) continue;
      if (r.share != null) {
        if (!_partial.add(r.id)) continue;
        extent *= r.share!;
      }
      if (r.guard != null && !r.guard!(t)) continue;
      if (r.medium != Medium.any) {
        final ph = phOf(t) ?? 7;
        final acid = ph < 4;
        if (r.medium == Medium.acid && !acid) continue;
        if (r.medium == Medium.notAcid && acid) continue;
      }
      for (final (group, coef) in r.reactants) {
        var need = coef * extent;
        for (final g in group) {
          final take = math.min(a(g), need);
          t.add(g, -take);
          need -= take;
          if (need <= 1e-12) break;
        }
      }
      for (final e in r.products.entries) {
        t.add(e.key, e.value * extent);
      }
      for (final e in r.solids.entries) {
        t.addPp(e.key, e.value * extent);
      }
      if (r.gas != null) ev.addGas(r.gas!, r.gasCoef * extent);
      fixCharge();
      changed = true;
      ev.add('rx:${r.id}', extent);
      if (r.slow) ev.slow = true;
    }
  }

  void metals() {
    for (final m in Metal.values) {
      var have = t.metals[m] ?? 0;
      if (have < 1e-6) continue;
      void react(Sp ox, double perMetal, void Function(double n) products,
          String key) {
        if (have < 1e-6) return;
        final n = math.min(have, a(ox) / perMetal);
        if (n < 1e-7) return;
        have -= n;
        t.add(ox, -perMetal * n);
        t.add(m.ion, n);
        products(n);
        changed = true;
        ev.add('metal:${m.name}:$key', n);
      }

      final electrons = m.ion.charge.toDouble();
      final divalent = electrons / 2;
      if (m.v0 < 0.80) react(Sp.ag, electrons, (n) => _deposit(Deposit.ag, electrons * n), 'ag');
      if (m.v0 < 0.77) react(Sp.fe3, electrons, (n) => t.add(Sp.fe2, electrons * n), 'fe3');
      if (m.v0 < 0.34) react(Sp.cu, divalent, (n) => _deposit(Deposit.cu, divalent * n), 'cu');
      if (m.v0 < 0) react(Sp.h, electrons, (n) => ev.addGas(Gas.h2, divalent * n), 'h');
      if (m.v0 < -0.44) {
        react(Sp.fe2, divalent, (n) => _deposit(Deposit.fe, divalent * n), 'fe2');
      }
      if (m.v0 < -0.76) {
        react(Sp.zn, divalent, (n) => _deposit(Deposit.zn, divalent * n), 'zn');
      }
      if (m.reactsWithWater && have > _eps && t.waterMl > 0) {
        move({m.ion: have, Sp.oh: electrons * have});
        ev.addGas(Gas.h2, divalent * have);
        ev.add('metal:${m.name}:water', have);
        have = 0;
      }
      if (have < _eps) {
        t.metals.remove(m);
      } else {
        t.metals[m] = have;
      }
    }
  }

  void _deposit(Deposit d, double n) {
    t.deposits[d] = (t.deposits[d] ?? 0) + n;
    if (d == Deposit.fe) ev.slow = true;
  }

  void run() {
    final fe = a(Sp.feSCN);
    if (fe > 0) {
      t.sp.remove(Sp.feSCN);
      t.add(Sp.fe3, fe);
      t.add(Sp.scn, fe);
    }
    for (var i = 0; i < 60; i++) {
      changed = false;
      neutralize();
      protonate();
      deprotonate();
      complexes();
      precipitate();
      redox();
      metals();
      if (!changed) break;
    }
    final n = math.min(a(Sp.fe3), a(Sp.scn));
    if (n > 1e-7) {
      t.add(Sp.fe3, -n);
      t.add(Sp.scn, -n);
      t.add(Sp.feSCN, n);
      if (fe < n - 1e-6) ev.add('feSCN', n);
    }
    final cap = _co2PerMl * t.waterMl;
    final co2 = a(Sp.co2);
    final escape = t.hot ? co2 : math.max(0.0, co2 - cap);
    if (escape > 1e-6) {
      t.add(Sp.co2, -escape);
      ev.addGas(Gas.co2, escape);
    }
    for (final p in [...t.pp.keys]) {
      if (t.ppAmt(p) < 1e-10) t.pp.remove(p);
    }
    t.sp.removeWhere((_, v) => v.abs() < 1e-11);
  }
}

void settle(Tube t, Events ev) => _Engine(t, ev).run();

// ---------------------------------------------------------------------------
// Looking at a tube.

class TubeLook {
  const TubeLook({
    required this.water,
    required this.waterName,
    required this.waterKey,
    required this.organic,
    required this.organicName,
  });
  final Color? water;
  final String waterName;

  /// What gives the water its colour (a particle, an indicator colour,
  /// starch–iodine); null when colourless. Two looks with the same key are
  /// the same colour, just lighter or darker.
  final String? waterKey;
  final Color? organic;
  final String organicName;
}

double _organicShare(Tube t) => t.hexaneMl > 0 ? 0.9 : 0;

/// The colour name a coloured particle gives at its concentration in [t].
String colourNameOf(Sp s, Tube t) {
  final c = spColors[s]!;
  final v = t.waterMl <= 0 ? 1.0 : t.waterMl;
  return t.amt(s) / v * c.strength < 0.6 ? c.dilute : c.strong;
}

TubeLook lookOf(Tube t) {
  final v = t.waterMl;
  var r = 0.0, g = 0.0, b = 0.0, total = 0.0;
  var best = '';
  String? bestKey;
  var bestStrength = 0.0;
  void mix(int argb, double strength, String name, String key) {
    if (strength <= 0) return;
    final c = Color(argb);
    r += c.r * strength;
    g += c.g * strength;
    b += c.b * strength;
    total += strength;
    if (strength > bestStrength) {
      bestStrength = strength;
      best = name;
      bestKey = key;
    }
  }

  if (v > 0) {
    final keep = 1 - _organicShare(t);
    final iodine = t.amt(Sp.i2) * keep / v;
    if (t.starch && iodine > 2e-5) {
      mix(0xFF1B1F4A, 50, 'blauwzwart', 'starch');
    }
    for (final e in spColors.entries) {
      var c = t.amt(e.key) / v;
      if (e.key == Sp.i2 || e.key == Sp.br2) c *= keep;
      if (e.key == Sp.i2 && t.starch) c *= 0.1;
      final s = c * e.value.strength;
      if (s < 0.1) continue;
      mix(e.value.argb, s, s < 0.6 ? e.value.dilute : e.value.strong,
          e.key.name);
    }
    final ph = phOf(t);
    if (ph != null) {
      for (final ind in t.indicators) {
        final argb = ind.argbAt(ph);
        if ((argb >> 24) == 0) continue;
        final name = ind.colorAt(ph);
        mix(argb, 2.5, name, 'ind:${ind.name}:$name');
      }
    }
  }
  Color? water;
  var waterName = 'kleurloos';
  if (total > 0) {
    final alpha =
        (0.25 + 0.75 * (1 - math.exp(-total / 1.5))).clamp(0.0, 0.95);
    water = Color.from(
      alpha: alpha,
      red: r / total,
      green: g / total,
      blue: b / total,
    );
    waterName = best;
  }

  Color? organic;
  var organicName = 'kleurloos';
  if (t.hexaneMl > 0) {
    final share = _organicShare(t);
    final i2 = t.amt(Sp.i2) * share / t.hexaneMl;
    final br2 = t.amt(Sp.br2) * share / t.hexaneMl;
    if (i2 > 2e-4) {
      organic = const Color(0xDD9C3FB5);
      organicName = i2 < 2e-3 ? 'roze-paars' : 'paars';
    } else if (br2 > 5e-4) {
      organic = const Color(0xDDE0841C);
      organicName = br2 < 4e-3 ? 'geeloranje' : 'oranjebruin';
    }
  }
  return TubeLook(
    water: water,
    waterName: waterName,
    waterKey: total > 0 ? bestKey : null,
    organic: organic,
    organicName: organicName,
  );
}

/// Turbidity of fine solids that stay suspended (sulfur) versus solids that
/// settle at the bottom.
bool settlesAtBottom(Pp p) => p != Pp.sulfur;

// ---------------------------------------------------------------------------
// The lab: tubes, actions and the journal.

class LabEntry {
  LabEntry({
    required this.tube,
    required this.action,
    required this.observations,
    required this.minute,
    this.notes = const [],
    this.equations = const [],
    this.reactions = const [],
    this.paper,
    this.flame,
  });

  final int? tube;
  final String action;
  final List<String> observations;
  final List<String> notes;
  final List<String> equations;

  /// Each reaction equation with the sentence that explains it.
  final List<(String, String)> reactions;
  final int minute;
  final PaperColor? paper;
  final Color? flame;
}

class PtaLab {
  PtaLab(this.unknown, {int tubeCount = 4})
      : tubes = List.generate(tubeCount, (_) => Tube());

  final Substance unknown;
  final List<Tube> tubes;
  final List<LabEntry> log = [];
  int minutes = 0;
  int actions = 0;

  /// Colour of the flame during the last flame test, for the visual.
  Color? lastFlame;

  String _tubeName(int i) => 'Buis ${i + 1}';

  LabEntry _record(
    String cost,
    int? tube,
    String action,
    List<String> observations, {
    Events? ev,
    List<String> notes = const [],
    List<String> equations = const [],
    PaperColor? paper,
    Color? flame,
  }) {
    minutes += actionMinutes[cost] ?? 1;
    actions++;
    final n = [...notes];
    final e = [...equations];
    final pairs = <(String, String)>[
      for (var k = 0; k < equations.length; k++)
        (k < notes.length ? notes[k] : '', equations[k]),
    ];
    if (ev != null) {
      for (final (note, eq) in explain(ev)) {
        if (note.isNotEmpty && !n.contains(note)) n.add(note);
        if (eq.isNotEmpty && !e.contains(eq)) {
          e.add(eq);
          pairs.add((note, eq));
        }
      }
    }
    final entry = LabEntry(
      tube: tube,
      action: tube == null ? action : '${_tubeName(tube)}: $action',
      observations: observations,
      notes: n,
      equations: e,
      reactions: pairs,
      minute: minutes,
      paper: paper,
      flame: flame,
    );
    log.add(entry);
    return entry;
  }

  void _startAction(Tube t) {
    t.bubbling = false;
    t.heating = false;
    if (t.warm > 0) t.warm--;
  }

  LabEntry inspect() {
    return _record('inspect', null, 'Het monster bekijken', [
      'Je ziet ${unknown.appearance}.',
    ]);
  }

  LabEntry flameTest() {
    final flame = flames[unknown.cation];
    lastFlame = flame == null ? null : Color(flame.argb);
    final obs = flame == null
        ? ['De vlam krijgt geen kenmerkende kleur.']
        : ['De vlam kleurt ${flame.description}.'];
    return _record(
      'flame',
      null,
      'Vlamproef met een beetje monster op een magnesiastaafje',
      obs,
      notes: const ['Vlamkleuren van metaalionen staan in Binas tabel 65A.'],
      flame: lastFlame,
    );
  }

  LabEntry addSample(int i) {
    final t = tubes[i];
    _startAction(t);
    const label = 'Monster toevoegen';
    if (unknown.gaseous) {
      return _record('sample', i, label, [
        'In het potje zit een kleurloos gas. Er komt geen vloeistof of vaste stof in de buis.',
      ]);
    }
    if (unknown.liquid case final liquid?) {
      return _addLiquid(i, liquid, kWaterMl, 'Een beetje monster toevoegen', sample: true);
    }
    if (t.solid != null && t.solid != unknown) {
      return _record('sample', i, label,
          ['Er zit al een andere vaste stof in deze buis; spoel hem eerst om.']);
    }
    final before = t.copy();
    if (unknown.metal case final metal?) {
      t.metals[metal] = (t.metals[metal] ?? 0) + kSampleMmol;
      if (t.waterMl <= 0) {
        return _record('sample', i, label, ['Er ligt ${unknown.appearance} op de bodem.']);
      }
      final mixed = t.copy();
      final ev = Events();
      settle(t, ev);
      _afterChange(t, ev);
      return _record('sample', i, label, describe(before, mixed, t, ev), ev: ev);
    }
    t.solid = t.solid ?? unknown;
    t.solidMmol += kSampleMmol;
    if (t.waterMl <= 0) {
      return _record('sample', i, label,
          ['Er ligt nu ${unknown.appearance} op de bodem van de buis.']);
    }
    final ev = Events();
    final equation = _dissolve(t);
    final mixed = t.copy();
    settle(t, ev);
    _afterChange(t, ev);
    final obs = [
      _dissolveSentence(t),
      ..._afterDissolving(t, describe(before, mixed, t, ev)),
    ];
    return _record('sample', i, label, obs, ev: ev, equations: [?equation]);
  }

  String? _dissolve(Tube t) {
    final s = t.solid;
    if (s == null || t.waterMl <= 0) return null;
    String? equation = s.waterReaction;
    if (s.initialSolid case final phase?) {
      t.addPp(phase, t.solidMmol);
      if (phase == Pp.starch) t.starch = true;
    } else {
      for (final e in s.ions.entries) {
        t.add(e.key, e.value * t.solidMmol);
      }
      if (equation == null && s.ions.isNotEmpty) {
        final hydrate = s.formula.split('·');
        final ions = [
          for (final e in s.ions.entries)
            '${e.value == 1 ? '' : '${e.value.toInt()} '}${e.key.formula}(aq)',
          if (hydrate.length == 2)
            hydrate.last.replaceFirst('H₂O', ' H₂O(l)').trimLeft(),
        ];
        equation = '${s.notation} → ${ions.join(' + ')}';
      }
    }
    t.solid = null;
    t.solidMmol = 0;
    t.solidHeated = false;
    return equation;
  }

  /// Drops what the dissolve sentence already says: an undissolved jar
  /// substance is not "a new precipitate", and "no visible change" next to
  /// "it dissolves" is noise.
  List<String> _afterDissolving(Tube t, List<String> obs) {
    final undissolved = _dissolveSentence(t).contains('niet');
    return [
      for (final o in obs)
        if (o != 'Geen zichtbare verandering.' &&
            !(undissolved &&
                o.startsWith('Er ontstaat') &&
                (o.contains('neerslag') || o.contains('troebeling'))))
          o,
    ];
  }

  String _dissolveSentence(Tube t) {
    final solids = t.pp.entries
        .where((e) => settlesAtBottom(e.key))
        .fold(0.0, (s, e) => s + e.value);
    if (solids >= 0.1) {
      return 'De stof lost niet op: er blijft een vaste stof op de bodem liggen.';
    }
    return 'De stof lost op.';
  }

  LabEntry addWater(int i) {
    final t = tubes[i];
    _startAction(t);
    return _addLiquid(i, reagentById('water'), kWaterMl,
        'Gedestilleerd water toevoegen en schudden');
  }

  LabEntry addReagent(int i, Reagent r, [Dose dose = Dose.drops]) {
    final t = tubes[i];
    _startAction(t);
    switch (r.kind) {
      case ReagentKind.water:
        return addWater(i);
      case ReagentKind.indicator:
        return _addIndicator(i, r);
      case ReagentKind.starch:
      case ReagentKind.hexane:
        return _addExtra(i, r);
      case ReagentKind.ethanol:
      case ReagentKind.solution:
        break;
    }
    final ml = dose == Dose.drops ? kDropsMl : kExcessMl;
    final label = dose == Dose.drops
        ? '${_cap(r.name)} toevoegen (enkele druppels)'
        : '${_cap(r.name)} toevoegen (overmaat)';
    return _addLiquid(i, r, ml, label);
  }

  LabEntry _addLiquid(int i, Reagent r, double ml, String label, {bool sample = false}) {
    final t = tubes[i];
    final water = r.kind == ReagentKind.water;
    final cost = sample ? 'sample' : water ? 'water' : 'reagent';
    if (t.totalMl + ml > kMaxMl) {
      return _record(cost, i, label, ['De buis is te vol.']);
    }
    final before = t.copy();
    final hadSolid = t.solid != null;
    switch (r.kind) {
      case ReagentKind.hexane:
        t.hexaneMl += ml;
      case ReagentKind.ethanol:
        t.ethanolMl += ml;
      default:
        t.waterMl += ml;
        if (r.kind == ReagentKind.starch) t.starch = true;
        for (final e in r.conc.entries) {
          t.add(e.key, e.value * ml);
        }
    }
    final ev = Events();
    final equation = _dissolve(t);
    final mixed = t.copy();
    settle(t, ev);
    _afterChange(t, ev);
    final dissolved = hadSolid && t.solid == null;
    final described = describe(before, mixed, t, ev, skipColor: dissolved && water);
    final obs = [
      if (dissolved) _dissolveSentence(t),
      if (dissolved && water) 'De vloeistof is ${lookOf(t).waterName}.',
      if (before.waterMl > 0 && before.hexaneMl == 0 && t.hexaneMl > 0 ||
          before.hexaneMl > 0 && before.waterMl == 0 && t.waterMl > 0)
        'Na schudden zie je twee vloeistoflagen.',
      if (water && before.ethanolMl > 0 && before.waterMl == 0)
        'De vloeistoffen mengen volledig.',
      ...(dissolved ? _afterDissolving(t, described) : described),
    ];
    if (obs.length > 1) obs.remove('Geen zichtbare verandering.');
    return _record(cost, i, label, obs, ev: ev, equations: [?equation]);
  }

  LabEntry _addIndicator(int i, Reagent r) {
    final t = tubes[i];
    final label = '${_cap(r.name)} toevoegen (2 druppels)';
    if (t.waterMl <= 0) {
      return _record('indicator', i, label,
          ['Er zit geen oplossing in de buis; voeg eerst water of een oplossing toe.']);
    }
    t.indicators.add(r.indicator!);
    t.waterMl += kIndicatorMl;
    final ph = phOf(t)!;
    final colour = r.indicator!.colorAt(ph);
    final obs = colour == 'kleurloos'
        ? ['De oplossing blijft kleurloos.']
        : ['De oplossing kleurt $colour.'];
    return _record('indicator', i, label, obs, notes: [
      'Omslagtraject ${r.indicator!.name}: ${_num(r.indicator!.from)}–${_num(r.indicator!.to)} '
          '(${r.indicator!.acidColor} → ${r.indicator!.baseColor}), Binas tabel 52A.',
    ]);
  }

  LabEntry _addExtra(int i, Reagent r) {
    final t = tubes[i];
    final hexane = r.kind == ReagentKind.hexane;
    final label = hexane
        ? 'Hexaan toevoegen en schudden'
        : 'Zetmeeloplossing toevoegen';
    final ml = hexane ? kHexaneMl : kStarchMl;
    if (t.totalMl + ml > kMaxMl) {
      return _record('extra', i, label, ['De buis is te vol.']);
    }
    final before = t.copy();
    if (hexane) {
      t.hexaneMl += ml;
    } else {
      t.starch = true;
      t.waterMl += ml;
    }
    final obs = <String>[];
    if (hexane && before.hexaneMl <= 0) {
      final look = lookOf(t);
      obs.add(t.waterMl > 0
          ? 'Er ontstaan twee lagen; de bovenste laag (hexaan) is ${look.organicName}.'
          : 'De hexaan is ${look.organicName}.');
      final was = lookOf(before).waterKey;
      if (was != look.waterKey && t.waterMl > 0) {
        obs.add(look.waterKey == null
            ? 'De onderste laag (water) wordt kleurloos.'
            : 'De onderste laag (water) is ${look.waterName}.');
      }
    } else {
      obs.addAll(describe(before, t.copy(), t, Events()));
    }
    final notes = <String>[];
    if (hexane && t.amt(Sp.i2) > 1e-4) {
      notes.add('I₂ lost beter op in hexaan dan in water en kleurt hexaan paars; Br₂ kleurt hexaan oranje.');
    }
    if (!hexane && t.amt(Sp.i2) > 1e-5) {
      notes.add('Zetmeel kleurt blauwzwart met I₂: zo toon je jood aan.');
    }
    return _record('extra', i, label, obs, notes: notes);
  }

  LabEntry addMetal(int i, Metal m) {
    final t = tubes[i];
    _startAction(t);
    final label = 'Een stukje ${m.name} in de buis doen';
    final before = t.copy();
    t.metals[m] = (t.metals[m] ?? 0) + kMetalMmol;
    if (t.waterMl <= 0) {
      return _record('metal', i, label,
          ['Het metaal ligt in een droge buis; er gebeurt niets.']);
    }
    final mixed = t.copy();
    final ev = Events();
    settle(t, ev);
    _afterChange(t, ev);
    return _record('metal', i, label, describe(before, mixed, t, ev), ev: ev);
  }

  LabEntry heat(int i) {
    final t = tubes[i];
    _startAction(t);
    t.heating = true;
    if (t.totalMl > 0 && (t.ethanolMl == t.totalMl || t.hexaneMl == t.totalMl)) {
      final boilingPoint = t.ethanolMl > 0 ? 78 : 69;
      return _record('heat', i, 'De vloeistof in een waterbad verwarmen', [
        'De vloeistof kookt rond $boilingPoint °C.',
      ]);
    }
    if (t.waterMl <= 0 && t.solid != null) return _heatDry(i);
    if (t.waterMl <= 0) {
      return _record('heat', i, 'Verwarmen boven de brander',
          ['De buis is leeg; er gebeurt niets.']);
    }
    final before = t.copy();
    t.warm = 3;
    final ev = Events();
    final hco3 = t.amt(Sp.hco3);
    if (hco3 > 0.05) {
      final n = hco3 * 0.5;
      t.add(Sp.hco3, -n);
      t.add(Sp.co3, n / 2);
      t.add(Sp.co2, n / 2);
      ev.add('heat:hco3', n);
    }
    final nh3 = speciated(t, Sp.nh3);
    if (nh3 > 0.01) {
      final out = nh3 * 0.6;
      final fromNh3 = math.min(out, t.amt(Sp.nh3));
      t.add(Sp.nh3, -fromNh3);
      if (out - fromNh3 > 0) {
        t.add(Sp.nh4, -(out - fromNh3));
        t.add(Sp.h, out - fromNh3);
      }
      ev.addGas(Gas.nh3, out);
    }
    final mixed = t.copy();
    settle(t, ev);
    _afterChange(t, ev);
    final obs = [
      'De vloeistof wordt warm.',
      ...describe(before, mixed, t, ev, heated: true),
    ];
    return _record('heat', i, 'Verwarmen boven de brander', obs, ev: ev);
  }

  LabEntry _heatDry(int i) {
    final t = tubes[i];
    final s = t.solid!;
    const label = 'De vaste stof droog verhitten boven de brander';
    if (t.solidHeated) {
      t.headspace = {};
      return _record('heat', i, label, ['Er is geen verdere verandering.']);
    }
    final heat = s.heat;
    t.headspace = {...heat.gases};
    t.bubbling = false;
    if (heat.gone) {
      t.solid = null;
      t.solidMmol = 0;
    } else if (heat.becomes != null) {
      t.solid = substanceById(heat.becomes!);
      t.solidMmol *= heat.factor;
    }
    t.solidHeated = true;
    return _record('heat', i, label, [heat.observation],
        notes: [if (heat.interpretation.isNotEmpty) heat.interpretation],
        equations: [if (heat.equation.isNotEmpty) heat.equation]);
  }

  LabEntry paper(int i) {
    final t = tubes[i];
    _startAction(t);
    const label = 'Met een roerstaafje een druppel op universeel indicatorpapier';
    final ph = phOf(t);
    if (ph == null) {
      return _record('paper', i, label,
          ['Er zit geen oplossing in de buis; indicatorpapier werkt alleen met een oplossing.']);
    }
    final p = paperFor(ph);
    final note = p.ph < 7
        ? 'De oplossing is zuur: er is een deeltje dat als zuur reageert. Zoek in Binas 49 welke deeltjes dat kunnen zijn (ook gehydrateerde metaalionen en NH₄⁺).'
        : p.ph > 7
            ? 'De oplossing is basisch: er is een deeltje dat als base reageert. Zoek in Binas 49 welke negatieve ionen een zwakke base zijn.'
            : 'De oplossing is (ongeveer) neutraal: er zijn geen zure of basische deeltjes van betekenis.';
    return _record('paper', i, label,
        ['Het indicatorpapier kleurt ${p.name}: pH ≈ ${p.ph}.'],
        notes: [note], paper: p);
  }

  LabEntry gasTest(int i, GasTest kind) {
    final t = tubes[i];
    final gases = t.headspace;
    final String label;
    final List<String> obs;
    final notes = <String>[];
    final eqs = <String>[];
    switch (kind) {
      case GasTest.limewater:
        label = 'Het gas boven de buis door kalkwater leiden';
        if (gases.contains(Gas.co2) || gases.contains(Gas.so2)) {
          obs = ['Het kalkwater wordt troebel (wit).'];
          if (gases.contains(Gas.co2)) {
            notes.add('CO₂ maakt kalkwater troebel: er ontstaat calciumcarbonaat.');
            eqs.add('CO₂ + Ca²⁺ + 2 OH⁻ → CaCO₃(s) + H₂O');
          }
          if (gases.contains(Gas.so2)) {
            notes.add('Ook SO₂ maakt kalkwater troebel (CaSO₃). Met joodpapier kun je SO₂ van CO₂ onderscheiden.');
            eqs.add('SO₂ + Ca²⁺ + 2 OH⁻ → CaSO₃(s) + H₂O');
          }
        } else {
          obs = ['Het kalkwater blijft helder.'];
        }
      case GasTest.litmus:
        label = 'Vochtig rood lakmoespapier boven de buis houden';
        if (gases.contains(Gas.nh3) && gases.contains(Gas.hcl)) {
          obs = ['Het lakmoespapier kleurt eerst blauw en daarna weer rood.'];
          notes.add('NH₃ (base) diffundeert sneller dan HCl (zuur).');
        } else if (gases.contains(Gas.nh3)) {
          obs = ['Het vochtige rode lakmoespapier kleurt blauw.'];
          notes.add('Een basisch gas: ammoniak.');
          eqs.add('NH₃ + H₂O ⇄ NH₄⁺ + OH⁻');
        } else {
          obs = ['Het lakmoespapier blijft rood.'];
        }
      case GasTest.iodinePaper:
        label = 'Met joodoplossing bevochtigd filtreerpapier boven de buis houden';
        final sulfurDioxide = gases.contains(Gas.so2);
        final hydrogenSulfide = gases.contains(Gas.h2s);
        obs = [
          if (sulfurDioxide || hydrogenSulfide)
            'De bruine kleur op het papier verdwijnt.'
          else
            'Het papier blijft bruin.',
        ];
        if (sulfurDioxide) {
          notes.add('Zwaveldioxide reduceert jood tot jodide.');
          eqs.add('SO₂(g) + I₂(aq) + 2 H₂O(l) → SO₄²⁻(aq) + 2 I⁻(aq) + 4 H⁺(aq)');
        }
        if (hydrogenSulfide) {
          notes.add('Ook waterstofsulfide ontkleurt joodpapier.');
          eqs.add('H₂S(g) + I₂(aq) → S(s) + 2 I⁻(aq) + 2 H⁺(aq)');
        }
      case GasTest.glowingSplint:
        label = 'Een gloeiend houtje in de buis houden';
        if (gases.contains(Gas.o2)) {
          obs = ['Het gloeiende houtje gaat weer branden.'];
          notes.add('Zuurstof laat een gloeiend houtje opvlammen.');
        } else if (gases.contains(Gas.co2)) {
          obs = ['Het gloeiende houtje dooft direct.'];
        } else {
          obs = ['Het houtje gloeit even na en dooft; geen bijzonderheden.'];
        }
      case GasTest.burningSplint:
        label = 'Een brandend houtje bij de opening houden';
        if (gases.contains(Gas.h2)) {
          obs = ['Je hoort een plofje (blafje).'];
          notes.add('Waterstof verbrandt met een plofje.');
          eqs.add('2 H₂ + O₂ → 2 H₂O');
        } else if (gases.contains(Gas.co2)) {
          obs = ['Het brandende houtje dooft.'];
        } else if (gases.contains(Gas.o2)) {
          obs = ['Het houtje brandt feller.'];
        } else {
          obs = ['Het houtje blijft gewoon branden.'];
        }
    }
    return _record('gas', i, label, obs, notes: notes, equations: eqs);
  }

  LabEntry rinse(int i) {
    tubes[i].clear();
    return _record('rinse', i, 'Buis omspoelen en droogmaken', ['De buis is weer schoon en leeg.']);
  }

  /// What is above the liquid after a change, for the gas tests.
  void _afterChange(Tube t, Events ev) {
    final gases = <Gas>{};
    var visible = 0.0;
    for (final e in ev.gas.entries) {
      if (e.value > 0.005) gases.add(e.key);
      if (e.key != Gas.nh3 && e.key != Gas.so2) visible += e.value;
    }
    if (speciated(t, Sp.so2) > 0.01) gases.add(Gas.so2);
    if (speciated(t, Sp.h2s) > 0.01) gases.add(Gas.h2s);
    final nh3 = speciated(t, Sp.nh3);
    if (nh3 > 0.3 || (t.hot && nh3 > 0.01)) gases.add(Gas.nh3);
    if (_slowBubbles(t) != null) gases.add(Gas.h2);
    t.headspace = gases;
    t.bubbling = visible > 0.01 || _slowBubbles(t) != null;
  }

  /// Magnesium and zinc in an acidic solution keep giving off hydrogen,
  /// slowly, even when there is no strong acid left to use up.
  static Metal? _slowBubbles(Tube t) {
    final ph = phOf(t);
    if (ph == null) return null;
    if ((t.metals[Metal.mg] ?? 0) > 0.05 && ph < 5.5) return Metal.mg;
    if ((t.metals[Metal.zn] ?? 0) > 0.05 && ph < 3.5) return Metal.zn;
    return null;
  }

  static String _cap(String s) => s[0].toUpperCase() + s.substring(1);
}

String _num(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

// ---------------------------------------------------------------------------
// Describing what changed.

/// The attributive form of a Dutch colour word: "wit" → "witte".
String inflect(String c) {
  if (c == 'kleurloos') return 'kleurloze';
  if (c.endsWith('wit')) return '${c}te';
  if (c.endsWith('geel')) return '${c.substring(0, c.length - 4)}gele';
  if (c.endsWith('rood')) return '${c.substring(0, c.length - 4)}rode';
  if (c.endsWith('e')) return c;
  return '${c}e';
}

String _appearPhrase(Pp p, double amount) {
  switch (p) {
    case Pp.sulfur:
      return 'De oplossing wordt na korte tijd troebel: er ontstaat een geelwitte troebeling.';
    case Pp.ag2S:
      return 'Er ontstaat een wit neerslag dat snel via geel en bruin zwart wordt.';
    case Pp.feOH2:
      return 'Er ontstaat een vuilgroen neerslag dat aan het oppervlak langzaam bruin wordt.';
    case Pp.cuI:
      return 'Er ontstaat een witachtig neerslag (bruin gekleurd door de oplossing).';
    default:
      if (amount >= 0.01) return 'Er ontstaat een ${p.colorName} neerslag.';
      return p.colorName == 'wit'
          ? 'Er ontstaat een lichte witte troebeling.'
          : 'Er ontstaat een beetje ${p.colorName} neerslag.';
  }
}

/// Solids grouped by how they look: you see "a white precipitate", not
/// which white salt it is.
Map<String, (double, Pp)> _solidsByLook(Tube t) {
  final out = <String, (double, Pp)>{};
  for (final e in t.pp.entries) {
    final key = e.key == Pp.sulfur ? 'troebel' : e.key.colorName;
    final prev = out[key];
    if (prev == null) {
      out[key] = (e.value, e.key);
    } else {
      out[key] = (
        prev.$1 + e.value,
        e.value > t.ppAmt(prev.$2) ? e.key : prev.$2,
      );
    }
  }
  return out;
}

const _reagentColours = [Sp.mno4, Sp.br2, Sp.cl2, Sp.i2];

/// Plain-language observations for one action: [before] the action,
/// [mixed] right after adding but before anything reacted, [after] once
/// settled.
List<String> describe(
  Tube before,
  Tube mixed,
  Tube after,
  Events ev, {
  bool heated = false,
  bool skipColor = false,
}) {
  final obs = <String>[];
  final gasOut = ev.gas.entries
      .where((e) => e.key != Gas.nh3 && e.key != Gas.so2)
      .fold(0.0, (s, e) => s + e.value);
  if (gasOut > 0.01) {
    if (heated) {
      obs.add('Er ontstaan gasbelletjes.');
    } else if (gasOut > 0.15) {
      obs.add('Het bruist hevig: er ontstaan veel gasbelletjes.');
    } else {
      obs.add('Er ontstaan gasbelletjes (het bruist).');
    }
  }
  if (ev['complex:ag'] > 0.002 && after.ppAmt(Pp.ag2S) < _visible) {
    obs.add('Er ontstaat even een wit neerslag dat bij schudden direct weer oplost.');
  }

  final sb = _solidsByLook(before), sa = _solidsByLook(after);
  for (final key in {...sb.keys, ...sa.keys}) {
    final b = sb[key]?.$1 ?? 0, a = sa[key]?.$1 ?? 0;
    final p = sa[key]?.$2 ?? sb[key]!.$2;
    final name = inflect(p.colorName);
    if (b < _visible && a >= _visible) {
      obs.add(_appearPhrase(p, a));
    } else if (b >= _visible && a < _visible) {
      obs.add(p == Pp.sulfur
          ? 'De troebeling verdwijnt.'
          : 'Het $name neerslag lost op.');
    } else if (b >= _visible && a - b > 0.01 && a > b * 1.3) {
      if (p != Pp.sulfur) obs.add('Er ontstaat meer ${p.colorName} neerslag.');
    } else if (b >= _visible && a < b * 0.6) {
      if (p != Pp.sulfur) obs.add('Het $name neerslag lost gedeeltelijk op.');
    }
  }

  if (!skipColor && after.waterMl > 0) {
    final kb = lookOf(before), km = lookOf(mixed), ka = lookOf(after);
    final slow = ev.slow ? ' (langzaam)' : '';
    final handled = <String>{};
    for (final s in _reagentColours) {
      if (mixed.amt(s) - before.amt(s) <= 1e-6) continue;
      final shown =
          mixed.amt(s) / mixed.waterMl * spColors[s]!.strength >= 0.1;
      if (!shown) continue;
      handled.add(s.name);
      final name = inflect(colourNameOf(s, mixed));
      if (after.amt(s) < 0.15 * mixed.amt(s)) {
        obs.add('De $name kleur verdwijnt$slow.');
      } else if (ka.waterKey == s.name) {
        if (kb.waterKey != s.name) {
          obs.add('De oplossing kleurt ${ka.waterName}.');
        }
      } else {
        obs.add('De $name kleur blijft zichtbaar.');
      }
    }
    if (ka.waterKey != km.waterKey && !handled.contains(ka.waterKey)) {
      if (ka.waterKey == null) {
        if (!handled.contains(km.waterKey)) {
          obs.add('De ${inflect(km.waterName)} kleur verdwijnt$slow: de oplossing wordt kleurloos.');
        } else if (kb.waterKey != null) {
          obs.add('De oplossing wordt kleurloos.');
        }
      } else if (ka.waterKey != kb.waterKey) {
        obs.add('De oplossing kleurt ${ka.waterName}.');
      }
    } else if (handled.isEmpty &&
        ka.waterKey == km.waterKey &&
        ka.waterKey != kb.waterKey) {
      obs.add(ka.waterKey == null
          ? 'De oplossing wordt kleurloos.'
          : 'De oplossing kleurt ${ka.waterName}.');
    }
  }
  if (after.hexaneMl > 0) {
    final ob = lookOf(mixed).organicName;
    final oa = lookOf(after).organicName;
    if (ob != oa) obs.add('De bovenste laag (hexaan) kleurt $oa.');
  }

  for (final d in Deposit.values) {
    final b = before.deposits[d] ?? 0, a = after.deposits[d] ?? 0;
    if (a - b > 0.005) {
      final when = d == Deposit.fe ? 'Na enige tijd ontstaat' : 'Er ontstaat';
      obs.add('$when een ${d.colorName} aanslag op het metaal.');
    }
  }
  for (final m in Metal.values) {
    final b = mixed.metals[m] ?? 0;
    final a = after.metals[m] ?? 0;
    if (b - a > 0.3 && b > 0) {
      obs.add(a < 0.05
          ? 'Het metaal lost helemaal op.'
          : 'Het metaal wordt zichtbaar kleiner.');
    }
  }
  if (PtaLab._slowBubbles(after) != null && gasOut <= 0.01) {
    obs.add('Aan het metaal ontstaan langzaam kleine gasbelletjes.');
  }
  if (ev['neutral'] >= 0.8 && !heated) obs.add('De buis wordt warm.');
  if (obs.isEmpty) obs.add('Geen zichtbare verandering.');
  return obs;
}

// ---------------------------------------------------------------------------
// Explaining what happened (practice mode and the result screen).

const _carbonateEq = 'CO₃²⁻ + 2 H⁺ → CO₂(g) + H₂O';
const _bicarbonateEq = 'HCO₃⁻ + H⁺ → CO₂(g) + H₂O';

/// What happened, as (explanation, equation) pairs; either may be empty.
List<(String, String)> explain(Events ev) {
  final out = <(String, String)>[];
  void add(String note, String eq) {
    if (out.any((p) => p.$1 == note && p.$2 == eq)) return;
    out.add((note, eq));
  }

  final co2 = ev.gas[Gas.co2] ?? 0;
  if (co2 > 0.01 && ev['rx:mno4_c2o4'] <= 0) {
    if (ev['heat:hco3'] > 0) {
      add('Waterstofcarbonaat ontleedt bij verwarmen; er ontwijkt CO₂.',
          '2 HCO₃⁻ → CO₃²⁻ + CO₂(g) + H₂O');
    } else if (ev['h:co3'] > 0.01) {
      add('Carbonaat is een base (Binas 49) en reageert met H⁺ tot koolstofdioxide.',
          _carbonateEq);
    } else {
      add('Waterstofcarbonaat reageert met H⁺ tot koolstofdioxide.',
          _bicarbonateEq);
    }
  }
  if (ev['h:hso3'] > 0.01 && ev['dis:baSO3'] + ev['dis:caSO3'] < 0.005) {
    add('Sulfiet is een base (Binas 49) en reageert met H⁺ tot zwaveldioxide.',
        'SO₃²⁻(aq) + 2 H⁺(aq) → SO₂(g) + H₂O(l)');
  }
  if (ev['h:hs'] > 0.01) {
    add('Sulfide vormt waterstofsulfide in een zure oplossing.',
        'S²⁻(aq) + 2 H⁺(aq) → H₂S(g)');
  }
  if (ev['h:s2o3'] > 0.005) {
    add('Thiosulfaat ontleedt in zuur milieu: er ontstaat zwavel (troebeling) en zwaveldioxide.',
        'S₂O₃²⁻ + 2 H⁺ → S(s) + SO₂ + H₂O');
  }
  if (ev['h:ac'] > 0.05) {
    add('Acetaat is een zwakke base (Binas 49): met H⁺ ontstaat azijnzuur.',
        'CH₃COO⁻ + H⁺ → CH₃COOH');
  }
  if (ev['oh:nh4'] > 0.01) {
    add('Ammonium is een zwak zuur (Binas 49): met OH⁻ ontstaat ammoniak (vooral bij verwarmen merkbaar).',
        'NH₄⁺ + OH⁻ → NH₃ + H₂O');
  }
  if (ev['oh:hco3'] > 0.01) {
    add('OH⁻ zet waterstofcarbonaat om in carbonaat.', 'HCO₃⁻ + OH⁻ → CO₃²⁻ + H₂O');
  }
  for (final p in Pp.values) {
    if (p.ksp == null) continue;
    if (ev['pp:${p.name}'] >= _visible) {
      add(
        '${_capFirst(p.name)} (${p.formula}) is ${p.moderate ? 'matig' : 'slecht'} oplosbaar (Binas 45A) en slaat neer.',
        p.equation,
      );
    }
  }
  for (final p in Pp.values) {
    final d = ev['dis:${p.name}'];
    if (d < 0.005) continue;
    if (p.acidSoluble) {
      add(
        '${_capFirst(p.name)} lost op in zuur: H⁺ reageert met ${p.anion!.formula}.',
        switch (p.anion) {
          Sp.oh => '${p.formula}(s) + ${p.b} H⁺(aq) → ${p.cation!.formula}(aq) + ${p == Pp.cuO ? '' : '${p.b} '}H₂O(l)',
          Sp.co3 => '${p.formula}(s) + 2 H⁺(aq) → ${p.cation!.formula}(aq) + CO₂(g) + H₂O(l)',
          Sp.so3 => '${p.formula}(s) + 2 H⁺(aq) → ${p.cation!.formula}(aq) + SO₂(g) + H₂O(l)',
          Sp.po4 => '${p.formula}(s) + 6 H⁺(aq) → 3 ${p.cation!.formula}(aq) + 2 H₃PO₄(aq)',
          _ => '',
        },
      );
    }
  }
  if (ev['amph:zn'] > 0.005) {
    add('Zinkhydroxide is amfoteer: in overmaat OH⁻ lost het op.',
        'Zn(OH)₂(s) + 2 OH⁻ → Zn(OH)₄²⁻');
  }
  if (ev['amph:al'] > 0.005) {
    add('Aluminiumhydroxide is amfoteer: in overmaat OH⁻ lost het op.',
        'Al(OH)₃(s) + OH⁻ → Al(OH)₄⁻');
  }
  if (ev['complex:ag'] > 0.002) {
    add('Ag⁺ vormt met overmaat thiosulfaat een opgelost complex.',
        'Ag⁺ + 2 S₂O₃²⁻ → Ag(S₂O₃)₂³⁻');
  }
  if (ev['ag2s'] > 0.002) {
    add('Met te weinig thiosulfaat slaat Ag₂S₂O₃ neer, dat ontleedt tot zwart zilversulfide.',
        'Ag₂S₂O₃(s) + H₂O → Ag₂S(s) + 2 H⁺ + SO₄²⁻');
  }
  if (ev['feSCN'] > 1e-5) {
    add('Fe³⁺ vormt met thiocyanaat een bloedrood complex (Binas 65B).',
        'Fe³⁺ + SCN⁻ → FeSCN²⁺');
  }
  for (final e in ev.amounts.entries) {
    if (!e.key.startsWith('rx:') || e.value < 1e-5) continue;
    final r = _redoxById[e.key.substring(3)]!;
    add(r.why, r.equation);
  }
  for (final e in ev.amounts.entries) {
    if (!e.key.startsWith('metal:') || e.value < 1e-4) continue;
    final parts = e.key.split(':');
    final m = Metal.values.firstWhere((m) => m.name == parts[1]);
    final (note, eq) = _metalText(m, parts[2]);
    add(note, eq);
  }
  if (ev['neutral'] >= 0.8) {
    add('Een sterk zuur en een sterke base neutraliseren elkaar; daarbij komt warmte vrij.',
        'H⁺ + OH⁻ → H₂O');
  }
  return out;
}

(String, String) _metalText(Metal m, String ox) {
  final monovalent = m.ion.charge == 1;
  final s = '${monovalent ? '2 ' : ''}${m.symbol}(s)';
  final ion = '${monovalent ? '2 ' : ''}${m.ion.formula}(aq)';
  final v = _v(m.v0);
  switch (ox) {
    case 'ag':
      return (
        '${m.symbol} ($v) is een sterkere reductor dan Ag (0,80 V): er slaat zilver neer.',
        '$s + 2 Ag⁺(aq) → $ion + 2 Ag(s)'
      );
    case 'fe3':
      return (
        '${m.symbol} ($v) reduceert Fe³⁺ tot Fe²⁺ (0,77 V).',
        '$s + 2 Fe³⁺(aq) → $ion + 2 Fe²⁺(aq)'
      );
    case 'cu':
      return (
        '${m.symbol} ($v) is een sterkere reductor dan Cu (0,34 V): er slaat koper neer.',
        '$s + Cu²⁺(aq) → $ion + Cu(s)'
      );
    case 'h':
      return (
        '${m.symbol} ($v) is een sterkere reductor dan H₂ (0,00 V): met H⁺ ontstaat waterstof.',
        '$s + 2 H⁺(aq) → $ion + H₂(g)'
      );
    case 'water':
      return (
        'Het metaal reageert met water. Er ontstaan waterstof en hydroxide-ionen.',
        '$s + 2 H₂O(l) → $ion + 2 OH⁻(aq) + H₂(g)'
      );
    case 'fe2':
      return (
        '${m.symbol} ($v) reduceert Fe²⁺ (−0,44 V) langzaam tot ijzer.',
        '$s + Fe²⁺(aq) → $ion + Fe(s)'
      );
    default:
      return (
        '${m.symbol} ($v) reduceert Zn²⁺ (−0,76 V) tot zink.',
        '$s + Zn²⁺(aq) → $ion + Zn(s)'
      );
  }
}

String _v(double v) =>
    '${v < 0 ? '−' : ''}${v.abs().toStringAsFixed(2).replaceAll('.', ',')} V';

String _capFirst(String s) => s[0].toUpperCase() + s.substring(1);
