import 'dart:ui' show Color;

/// Dissolved particles the lab tracks, in mmol per tube.
///
/// [h] and [oh] only ever hold an *excess* of strong acid or base; the pH
/// itself is solved from the charge balance (see `phOf` in pta_lab.dart).
enum Sp {
  h('H⁺', 1),
  oh('OH⁻', -1),
  na('Na⁺', 1),
  k('K⁺', 1),
  nh4('NH₄⁺', 1),
  nh3('NH₃', 0),
  mg('Mg²⁺', 2),
  ca('Ca²⁺', 2),
  ba('Ba²⁺', 2),
  cu('Cu²⁺', 2),
  fe2('Fe²⁺', 2),
  fe3('Fe³⁺', 3),
  zn('Zn²⁺', 2),
  al('Al³⁺', 3),
  ag('Ag⁺', 1),
  mn2('Mn²⁺', 2),
  znOH4('Zn(OH)₄²⁻', -2),
  alOH4('Al(OH)₄⁻', -1),
  feSCN('FeSCN²⁺', 2),
  agS2O3('Ag(S₂O₃)₂³⁻', -3),
  cl('Cl⁻', -1),
  br('Br⁻', -1),
  i('I⁻', -1),
  no3('NO₃⁻', -1),
  so4('SO₄²⁻', -2),
  co3('CO₃²⁻', -2),
  hco3('HCO₃⁻', -1),
  co2('CO₂', 0),
  ac('CH₃COO⁻', -1),
  hac('CH₃COOH', 0),
  po4('PO₄³⁻', -3),
  hpo4('HPO₄²⁻', -2),
  h2po4('H₂PO₄⁻', -1),
  h3po4('H₃PO₄', 0),
  so3('SO₃²⁻', -2),
  hso3('HSO₃⁻', -1),
  so2('SO₂', 0),
  s2o3('S₂O₃²⁻', -2),
  s4o6('S₄O₆²⁻', -2),
  c2o4('C₂O₄²⁻', -2),
  hc2o4('HC₂O₄⁻', -1),
  h2c2o4('H₂C₂O₄', 0),
  scn('SCN⁻', -1),
  mno4('MnO₄⁻', -1),
  h2o2('H₂O₂', 0),
  i2('I₂', 0),
  br2('Br₂', 0),
  bro('BrO⁻', -1),
  io('IO⁻', -1);

  const Sp(this.formula, this.charge);
  final String formula;
  final int charge;
}

/// One acid–base system: its forms from most to least protonated, with the
/// charge of the most protonated form and the pKz of each step. The same
/// list drives the pH solver and the Binas table 49 sheet, so the two can
/// never disagree.
class AcidBase {
  const AcidBase({
    required this.acid,
    required this.base,
    required this.members,
    required this.topCharge,
    required this.pKa,
  });

  /// Formulas shown in table 49, one pair per step.
  final List<String> acid;
  final List<String> base;
  final List<Sp> members;
  final int topCharge;
  final List<double> pKa;
}

const acidBaseSystems = <AcidBase>[
  AcidBase(
    acid: ['H₂C₂O₄', 'HC₂O₄⁻'],
    base: ['HC₂O₄⁻', 'C₂O₄²⁻'],
    members: [Sp.h2c2o4, Sp.hc2o4, Sp.c2o4],
    topCharge: 0,
    pKa: [1.27, 4.27],
  ),
  AcidBase(
    acid: ['SO₂ + H₂O', 'HSO₃⁻'],
    base: ['HSO₃⁻', 'SO₃²⁻'],
    members: [Sp.so2, Sp.hso3, Sp.so3],
    topCharge: 0,
    pKa: [1.86, 7.20],
  ),
  AcidBase(
    acid: ['HSO₄⁻'],
    base: ['SO₄²⁻'],
    members: [Sp.so4],
    topCharge: -1,
    pKa: [1.99],
  ),
  AcidBase(
    acid: ['H₃PO₄', 'H₂PO₄⁻', 'HPO₄²⁻'],
    base: ['H₂PO₄⁻', 'HPO₄²⁻', 'PO₄³⁻'],
    members: [Sp.h3po4, Sp.h2po4, Sp.hpo4, Sp.po4],
    topCharge: 0,
    pKa: [2.15, 7.21, 12.32],
  ),
  AcidBase(
    acid: ['Fe(H₂O)₆³⁺'],
    base: ['FeOH(H₂O)₅²⁺'],
    members: [Sp.fe3],
    topCharge: 3,
    pKa: [2.22],
  ),
  AcidBase(
    acid: ['CH₃COOH'],
    base: ['CH₃COO⁻'],
    members: [Sp.hac, Sp.ac],
    topCharge: 0,
    pKa: [4.76],
  ),
  AcidBase(
    acid: ['Al(H₂O)₆³⁺'],
    base: ['AlOH(H₂O)₅²⁺'],
    members: [Sp.al],
    topCharge: 3,
    pKa: [5.0],
  ),
  AcidBase(
    acid: ['CO₂ + H₂O', 'HCO₃⁻'],
    base: ['HCO₃⁻', 'CO₃²⁻'],
    members: [Sp.co2, Sp.hco3, Sp.co3],
    topCharge: 0,
    pKa: [6.35, 10.33],
  ),
  AcidBase(
    acid: ['Cu(H₂O)₄²⁺'],
    base: ['CuOH(H₂O)₃⁺'],
    members: [Sp.cu],
    topCharge: 2,
    pKa: [7.5],
  ),
  AcidBase(
    acid: ['HBrO'],
    base: ['BrO⁻'],
    members: [Sp.bro],
    topCharge: 0,
    pKa: [8.6],
  ),
  AcidBase(
    acid: ['Zn(H₂O)₄²⁺'],
    base: ['ZnOH(H₂O)₃⁺'],
    members: [Sp.zn],
    topCharge: 2,
    pKa: [9.0],
  ),
  AcidBase(
    acid: ['NH₄⁺'],
    base: ['NH₃'],
    members: [Sp.nh4, Sp.nh3],
    topCharge: 1,
    pKa: [9.25],
  ),
  AcidBase(
    acid: ['Fe(H₂O)₆²⁺'],
    base: ['FeOH(H₂O)₅⁺'],
    members: [Sp.fe2],
    topCharge: 2,
    pKa: [9.5],
  ),
  AcidBase(
    acid: ['Mn(H₂O)₆²⁺'],
    base: ['MnOH(H₂O)₅⁺'],
    members: [Sp.mn2],
    topCharge: 2,
    pKa: [10.6],
  ),
  AcidBase(
    acid: ['HIO'],
    base: ['IO⁻'],
    members: [Sp.io],
    topCharge: 0,
    pKa: [10.6],
  ),
  AcidBase(
    acid: ['Mg(H₂O)₆²⁺'],
    base: ['MgOH(H₂O)₅⁺'],
    members: [Sp.mg],
    topCharge: 2,
    pKa: [11.4],
  ),
  AcidBase(
    acid: ['H₂O₂'],
    base: ['HO₂⁻'],
    members: [Sp.h2o2],
    topCharge: 0,
    pKa: [11.6],
  ),
];

/// Every solid that can form in a tube. Salts with a [ksp] precipitate and
/// redissolve by their solubility product; the rest only appear as the
/// product of a redox reaction.
enum Pp {
  agCl(Sp.ag, 1, Sp.cl, 1, 1.8e-10, 'AgCl', 'zilverchloride', 'wit', 0xFFF4F4F0),
  agBr(Sp.ag, 1, Sp.br, 1, 5.0e-13, 'AgBr', 'zilverbromide', 'lichtgeel', 0xFFF1E7B8),
  agI(Sp.ag, 1, Sp.i, 1, 8.3e-17, 'AgI', 'zilverjodide', 'geel', 0xFFF0D650),
  agOH(Sp.ag, 1, Sp.oh, 1, 2.0e-8, 'Ag₂O', 'zilveroxide', 'bruin', 0xFF5E3B22),
  ag2CO3(Sp.ag, 2, Sp.co3, 1, 8.5e-12, 'Ag₂CO₃', 'zilvercarbonaat', 'geelwit', 0xFFF3EBC6),
  ag3PO4(Sp.ag, 3, Sp.po4, 1, 8.9e-17, 'Ag₃PO₄', 'zilverfosfaat', 'geel', 0xFFEFCF45),
  ag2SO4(Sp.ag, 2, Sp.so4, 1, 1.2e-5, 'Ag₂SO₄', 'zilversulfaat', 'wit', 0xFFF4F4F0, true),
  ag2SO3(Sp.ag, 2, Sp.so3, 1, 1.5e-14, 'Ag₂SO₃', 'zilversulfiet', 'wit', 0xFFF4F4F0),
  ag2C2O4(Sp.ag, 2, Sp.c2o4, 1, 5.4e-12, 'Ag₂C₂O₄', 'zilveroxalaat', 'wit', 0xFFF4F4F0),
  agSCN(Sp.ag, 1, Sp.scn, 1, 1.0e-12, 'AgSCN', 'zilverthiocyanaat', 'wit', 0xFFF4F4F0),
  baSO4(Sp.ba, 1, Sp.so4, 1, 1.1e-10, 'BaSO₄', 'bariumsulfaat', 'wit', 0xFFF6F6F4),
  baCO3(Sp.ba, 1, Sp.co3, 1, 2.6e-9, 'BaCO₃', 'bariumcarbonaat', 'wit', 0xFFF6F6F4),
  ba3PO42(Sp.ba, 3, Sp.po4, 2, 6.0e-39, 'Ba₃(PO₄)₂', 'bariumfosfaat', 'wit', 0xFFF6F6F4),
  baSO3(Sp.ba, 1, Sp.so3, 1, 5.0e-10, 'BaSO₃', 'bariumsulfiet', 'wit', 0xFFF6F6F4),
  baC2O4(Sp.ba, 1, Sp.c2o4, 1, 1.6e-7, 'BaC₂O₄', 'bariumoxalaat', 'wit', 0xFFF6F6F4),
  baS2O3(Sp.ba, 1, Sp.s2o3, 1, 5.0e-5, 'BaS₂O₃', 'bariumthiosulfaat', 'wit', 0xFFF6F6F4, true),
  caCO3(Sp.ca, 1, Sp.co3, 1, 3.4e-9, 'CaCO₃', 'calciumcarbonaat', 'wit', 0xFFF6F6F4),
  caSO4(Sp.ca, 1, Sp.so4, 1, 4.9e-5, 'CaSO₄', 'calciumsulfaat', 'wit', 0xFFF6F6F4, true),
  ca3PO42(Sp.ca, 3, Sp.po4, 2, 2.1e-33, 'Ca₃(PO₄)₂', 'calciumfosfaat', 'wit', 0xFFF6F6F4),
  caSO3(Sp.ca, 1, Sp.so3, 1, 3.1e-7, 'CaSO₃', 'calciumsulfiet', 'wit', 0xFFF6F6F4),
  caC2O4(Sp.ca, 1, Sp.c2o4, 1, 2.3e-9, 'CaC₂O₄', 'calciumoxalaat', 'wit', 0xFFF6F6F4),
  caOH2(Sp.ca, 1, Sp.oh, 2, 5.5e-6, 'Ca(OH)₂', 'calciumhydroxide', 'wit', 0xFFF6F6F4, true),
  mgOH2(Sp.mg, 1, Sp.oh, 2, 5.6e-12, 'Mg(OH)₂', 'magnesiumhydroxide', 'wit', 0xFFF6F6F4),
  cuOH2(Sp.cu, 1, Sp.oh, 2, 2.2e-20, 'Cu(OH)₂', 'koper(II)hydroxide', 'lichtblauw', 0xFF67A3DA),
  feOH2(Sp.fe2, 1, Sp.oh, 2, 4.9e-17, 'Fe(OH)₂', 'ijzer(II)hydroxide', 'vuilgroen', 0xFF6C8452),
  feOH3(Sp.fe3, 1, Sp.oh, 3, 2.8e-39, 'Fe(OH)₃', 'ijzer(III)hydroxide', 'roodbruin', 0xFF9B4A1D),
  znOH2(Sp.zn, 1, Sp.oh, 2, 3.0e-17, 'Zn(OH)₂', 'zinkhydroxide', 'wit', 0xFFF6F6F4),
  alOH3(Sp.al, 1, Sp.oh, 3, 1.3e-33, 'Al(OH)₃', 'aluminiumhydroxide', 'wit', 0xFFF2F4F6),
  cuI(null, 0, null, 0, null, 'CuI', 'koper(I)jodide', 'wit', 0xFFEDE6DA),
  mnO2(null, 0, null, 0, null, 'MnO₂', 'mangaan(IV)oxide', 'bruinzwart', 0xFF3E2A1C),
  sulfur(null, 0, null, 0, null, 'S', 'zwavel', 'geelwit', 0xFFF1E9A8),
  ag2S(null, 0, null, 0, null, 'Ag₂S', 'zilversulfide', 'zwart', 0xFF1C1C1C);

  const Pp(
    this.cation,
    this.a,
    this.anion,
    this.b,
    this.ksp,
    this.formula,
    this.name,
    this.colorName,
    this.argb, [
    this.moderate = false,
  ]);

  final Sp? cation;
  final int a;
  final Sp? anion;
  final int b;
  final double? ksp;
  final String formula;
  final String name;
  final String colorName;
  final int argb;

  /// "m" in table 45A: only comes out of solution when the ion product is
  /// well above Ksp, the way such salts stay supersaturated in a test tube.
  final bool moderate;

  Color get color => Color(argb);

  /// Precipitates whose anion is a base dissolve in a strong acid.
  bool get acidSoluble =>
      anion != null &&
      const {Sp.oh, Sp.co3, Sp.po4, Sp.so3, Sp.c2o4}.contains(anion);

  String get equation {
    if (cation == null || anion == null) return '';
    if (this == Pp.agOH) return '2 Ag⁺ + 2 OH⁻ → Ag₂O(s) + H₂O';
    String term(int n, Sp s) => n == 1 ? s.formula : '$n ${s.formula}';
    return '${term(a, cation!)} + ${term(b, anion!)} → $formula(s)';
  }
}

/// Coloured particles in solution: how strongly they colour the water per
/// mol/L, and what the colour is called dilute and concentrated.
class SpColor {
  const SpColor(this.argb, this.strength, this.dilute, this.strong);
  final int argb;
  final double strength;
  final String dilute;
  final String strong;
  Color get color => Color(argb);
}

const spColors = <Sp, SpColor>{
  Sp.cu: SpColor(0xFF3C8EE0, 9, 'lichtblauw', 'blauw'),
  Sp.fe2: SpColor(0xFF9CCB7A, 4, 'lichtgroen', 'groen'),
  Sp.fe3: SpColor(0xFFE0A030, 30, 'lichtgeel', 'geelbruin'),
  Sp.mno4: SpColor(0xFF8E2D9E, 1500, 'roze', 'paars'),
  Sp.i2: SpColor(0xFF9A5A1A, 700, 'geel', 'bruin'),
  Sp.br2: SpColor(0xFFE58A1F, 250, 'geel', 'oranje'),
  Sp.feSCN: SpColor(0xFFB0121B, 2500, 'oranjerood', 'bloedrood'),
};

enum Gas {
  co2('CO₂', 'koolstofdioxide'),
  so2('SO₂', 'zwaveldioxide'),
  nh3('NH₃', 'ammoniak'),
  h2('H₂', 'waterstof'),
  o2('O₂', 'zuurstof'),
  hcl('HCl', 'waterstofchloride');

  const Gas(this.formula, this.name);
  final String formula;
  final String name;
}

enum Deposit {
  cu('roodbruine', 0xFFB4622A),
  ag('grijszwarte', 0xFF7D7D7D),
  zn('grijze', 0xFF9AA0A6),
  fe('zwarte', 0xFF2B2B2B);

  const Deposit(this.colorName, this.argb);
  final String colorName;
  final int argb;
}

enum Metal {
  mg('magnesiumlint', 'Mg', Sp.mg, -2.37, 0xFFD9DCE0),
  zn('zinkkorrel', 'Zn', Sp.zn, -0.76, 0xFFB7BEC6),
  cu('koperdraad', 'Cu', Sp.cu, 0.34, 0xFFC8743A);

  const Metal(this.name, this.symbol, this.ion, this.v0, this.argb);
  final String name;
  final String symbol;
  final Sp ion;
  final double v0;
  final int argb;
}

/// Flame colours (Binas table 65A) per cation.
class Flame {
  const Flame(this.description, this.argb);
  final String description;
  final int argb;
}

const flames = <Sp, Flame>{
  Sp.na: Flame('felgeel (oranjegeel)', 0xFFFFC21A),
  Sp.k: Flame('lila (paarsachtig); het best te zien door blauw kobaltglas', 0xFFB38BE8),
  Sp.ca: Flame('oranjerood (steenrood)', 0xFFF0622A),
  Sp.ba: Flame('geelgroen', 0xFFB8E04A),
  Sp.cu: Flame('groen tot blauwgroen', 0xFF2FC79A),
};

enum Level { havo, vwo }

class DryHeat {
  const DryHeat(
    this.observation, {
    this.gases = const {},
    this.becomes,
    this.gone = false,
    this.factor = 1,
    this.interpretation = '',
    this.equation = '',
  });
  final String observation;
  final Set<Gas> gases;
  final String? becomes;
  final bool gone;
  final double factor;
  final String interpretation;
  final String equation;
}

const _noHeat = DryHeat('Er is geen zichtbare verandering.');
const _crystalWater = DryHeat(
  'Aan de koude buiswand ontstaan waterdruppeltjes.',
  interpretation: 'De stof bevat kristalwater dat bij verhitten ontwijkt.',
);

class Substance {
  const Substance({
    required this.id,
    required this.name,
    required this.formula,
    required this.ions,
    required this.appearance,
    required this.solidArgb,
    this.level = Level.havo,
    this.smell,
    this.heat = _noHeat,
    this.candidate = true,
  });

  final String id;
  final String name;
  final String formula;
  final Map<Sp, double> ions;
  final String appearance;
  final int solidArgb;
  final Level level;
  final String? smell;
  final DryHeat heat;

  /// False for forms that only exist after heating (anhydrous copper
  /// sulfate), never handed out as a jar.
  final bool candidate;

  Color get solidColor => Color(solidArgb);

  Sp? get cation {
    for (final s in ions.keys) {
      if (s.charge > 0) return s;
    }
    return null;
  }
}

const _white = 0xFFF7F7F5;

const substances = <Substance>[
  Substance(id: 'nacl', name: 'natriumchloride', formula: 'NaCl', ions: {Sp.na: 1, Sp.cl: 1}, appearance: 'witte kristallen', solidArgb: _white),
  Substance(id: 'kcl', name: 'kaliumchloride', formula: 'KCl', ions: {Sp.k: 1, Sp.cl: 1}, appearance: 'witte kristallen', solidArgb: _white),
  Substance(id: 'na2so4', name: 'natriumsulfaat', formula: 'Na₂SO₄', ions: {Sp.na: 2, Sp.so4: 1}, appearance: 'wit poeder', solidArgb: _white),
  Substance(id: 'k2so4', name: 'kaliumsulfaat', formula: 'K₂SO₄', ions: {Sp.k: 2, Sp.so4: 1}, appearance: 'witte kristallen', solidArgb: _white),
  Substance(id: 'na2co3', name: 'natriumcarbonaat', formula: 'Na₂CO₃', ions: {Sp.na: 2, Sp.co3: 1}, appearance: 'wit poeder', solidArgb: _white),
  Substance(
    id: 'nahco3',
    name: 'natriumwaterstofcarbonaat',
    formula: 'NaHCO₃',
    ions: {Sp.na: 1, Sp.hco3: 1},
    appearance: 'wit poeder',
    solidArgb: _white,
    heat: DryHeat(
      'Aan de koude buiswand ontstaan waterdruppeltjes en er ontwijkt een gas.',
      gases: {Gas.co2},
      becomes: 'na2co3',
      factor: 0.5,
      interpretation: 'Waterstofcarbonaat ontleedt bij verhitten tot carbonaat, water en koolstofdioxide.',
      equation: '2 NaHCO₃(s) → Na₂CO₃(s) + H₂O(l) + CO₂(g)',
    ),
  ),
  Substance(
    id: 'nano3',
    name: 'natriumnitraat',
    formula: 'NaNO₃',
    ions: {Sp.na: 1, Sp.no3: 1},
    appearance: 'witte kristallen',
    solidArgb: _white,
    heat: DryHeat(
      'De stof smelt tot een kleurloze vloeistof; bij sterk verhitten ontwijkt een gas.',
      gases: {Gas.o2},
      interpretation: 'Een nitraat ontleedt bij sterk verhitten tot een nitriet en zuurstof.',
      equation: '2 NaNO₃(l) → 2 NaNO₂(l) + O₂(g)',
    ),
  ),
  Substance(
    id: 'kno3',
    name: 'kaliumnitraat',
    formula: 'KNO₃',
    ions: {Sp.k: 1, Sp.no3: 1},
    appearance: 'witte kristallen',
    solidArgb: _white,
    heat: DryHeat(
      'De stof smelt tot een kleurloze vloeistof; bij sterk verhitten ontwijkt een gas.',
      gases: {Gas.o2},
      interpretation: 'Een nitraat ontleedt bij sterk verhitten tot een nitriet en zuurstof.',
      equation: '2 KNO₃(l) → 2 KNO₂(l) + O₂(g)',
    ),
  ),
  Substance(
    id: 'nh4cl',
    name: 'ammoniumchloride',
    formula: 'NH₄Cl',
    ions: {Sp.nh4: 1, Sp.cl: 1},
    appearance: 'witte kristallen',
    solidArgb: _white,
    heat: DryHeat(
      'De stof verdwijnt van de bodem; hoger in de buis, waar het koeler is, ontstaat een witte aanslag.',
      gases: {Gas.nh3, Gas.hcl},
      gone: true,
      interpretation: 'Ammoniumchloride ontleedt in ammoniak en waterstofchloride, die in het koude deel weer tot NH₄Cl reageren.',
      equation: 'NH₄Cl(s) ⇄ NH₃(g) + HCl(g)',
    ),
  ),
  Substance(
    id: 'nh42so4',
    name: 'ammoniumsulfaat',
    formula: '(NH₄)₂SO₄',
    ions: {Sp.nh4: 2, Sp.so4: 1},
    appearance: 'witte kristallen',
    solidArgb: _white,
    heat: DryHeat(
      'De stof smelt en ontleedt bij sterk verhitten; er ontwijkt een gas met een prikkelende geur.',
      gases: {Gas.nh3},
      interpretation: 'Een ammoniumzout geeft bij sterk verhitten ammoniak af.',
      equation: '(NH₄)₂SO₄(s) → NH₃(g) + NH₄HSO₄(s)',
    ),
  ),
  Substance(
    id: 'nh42co3',
    name: 'ammoniumcarbonaat',
    formula: '(NH₄)₂CO₃',
    ions: {Sp.nh4: 2, Sp.co3: 1},
    appearance: 'witte brokjes',
    solidArgb: _white,
    smell: 'De stof ruikt naar ammoniak.',
    heat: DryHeat(
      'De stof verdwijnt helemaal; er ontwijken gassen en aan de koude buiswand ontstaan waterdruppeltjes.',
      gases: {Gas.nh3, Gas.co2},
      gone: true,
      interpretation: 'Ammoniumcarbonaat ontleedt volledig in ammoniak, koolstofdioxide en water.',
      equation: '(NH₄)₂CO₃(s) → 2 NH₃(g) + CO₂(g) + H₂O(g)',
    ),
  ),
  Substance(id: 'cacl2', name: 'calciumchloride', formula: 'CaCl₂', ions: {Sp.ca: 1, Sp.cl: 2}, appearance: 'witte korrels', solidArgb: _white),
  Substance(id: 'bacl2', name: 'bariumchloride', formula: 'BaCl₂·2H₂O', ions: {Sp.ba: 1, Sp.cl: 2}, appearance: 'witte kristallen', solidArgb: _white, heat: _crystalWater),
  Substance(id: 'cano32', name: 'calciumnitraat', formula: 'Ca(NO₃)₂·4H₂O', ions: {Sp.ca: 1, Sp.no3: 2}, appearance: 'witte kristallen', solidArgb: _white, heat: _crystalWater),
  Substance(
    id: 'caco3',
    name: 'calciumcarbonaat',
    formula: 'CaCO₃',
    ions: {Sp.ca: 1, Sp.co3: 1},
    appearance: 'wit poeder',
    solidArgb: _white,
    heat: DryHeat('Er is geen zichtbare verandering (calciumcarbonaat ontleedt pas boven 800 °C).'),
  ),
  Substance(id: 'baso4', name: 'bariumsulfaat', formula: 'BaSO₄', ions: {Sp.ba: 1, Sp.so4: 1}, appearance: 'fijn wit poeder', solidArgb: _white),
  Substance(id: 'mgso4', name: 'magnesiumsulfaat', formula: 'MgSO₄·7H₂O', ions: {Sp.mg: 1, Sp.so4: 1}, appearance: 'witte kristallen', solidArgb: _white, heat: _crystalWater),
  Substance(
    id: 'cuso4',
    name: 'kopersulfaat',
    formula: 'CuSO₄·5H₂O',
    ions: {Sp.cu: 1, Sp.so4: 1},
    appearance: 'blauwe kristallen',
    solidArgb: 0xFF2F7FD8,
    heat: DryHeat(
      'De blauwe kristallen worden wit; aan de koude buiswand ontstaan waterdruppeltjes.',
      becomes: 'cuso4_anh',
      interpretation: 'Het kristalwater ontwijkt; watervrij kopersulfaat is wit.',
      equation: 'CuSO₄·5H₂O(s) → CuSO₄(s) + 5 H₂O(g)',
    ),
  ),
  Substance(id: 'cuso4_anh', name: 'watervrij kopersulfaat', formula: 'CuSO₄', ions: {Sp.cu: 1, Sp.so4: 1}, appearance: 'wit poeder', solidArgb: 0xFFEDEFF0, candidate: false),
  Substance(
    id: 'feso4',
    name: 'ijzer(II)sulfaat',
    formula: 'FeSO₄·7H₂O',
    ions: {Sp.fe2: 1, Sp.so4: 1},
    appearance: 'lichtgroene kristallen',
    solidArgb: 0xFFA9D49A,
    heat: DryHeat(
      'De groene kristallen worden witgeel; aan de koude buiswand ontstaan waterdruppeltjes.',
      interpretation: 'Het kristalwater ontwijkt.',
    ),
  ),
  Substance(id: 'znso4', name: 'zinksulfaat', formula: 'ZnSO₄·7H₂O', ions: {Sp.zn: 1, Sp.so4: 1}, appearance: 'witte kristallen', solidArgb: _white, heat: _crystalWater),
  Substance(id: 'mgcl2', name: 'magnesiumchloride', formula: 'MgCl₂·6H₂O', ions: {Sp.mg: 1, Sp.cl: 2}, appearance: 'witte kristallen', solidArgb: _white, heat: _crystalWater),
  Substance(
    id: 'zncl2',
    name: 'zinkchloride',
    formula: 'ZnCl₂',
    ions: {Sp.zn: 1, Sp.cl: 2},
    appearance: 'wit poeder',
    solidArgb: _white,
    heat: DryHeat('De stof smelt tot een kleurloze vloeistof.'),
  ),
  Substance(
    id: 'cucl2',
    name: 'koper(II)chloride',
    formula: 'CuCl₂·2H₂O',
    ions: {Sp.cu: 1, Sp.cl: 2},
    appearance: 'blauwgroene kristallen',
    solidArgb: 0xFF3FA79A,
    heat: DryHeat(
      'De blauwgroene kristallen worden bruin; aan de koude buiswand ontstaan waterdruppeltjes.',
      interpretation: 'Het kristalwater ontwijkt; watervrij koper(II)chloride is bruin.',
    ),
  ),
  Substance(
    id: 'fecl3',
    name: 'ijzer(III)chloride',
    formula: 'FeCl₃·6H₂O',
    ions: {Sp.fe3: 1, Sp.cl: 3},
    appearance: 'geelbruine brokjes',
    solidArgb: 0xFFC98A2B,
    heat: DryHeat('De stof smelt tot een donkerbruine vloeistof en er ontwijkt een prikkelende damp.', gases: {Gas.hcl}),
  ),
  Substance(
    id: 'alcl3',
    name: 'aluminiumchloride',
    formula: 'AlCl₃·6H₂O',
    ions: {Sp.al: 1, Sp.cl: 3},
    appearance: 'witte kristallen',
    solidArgb: _white,
    heat: DryHeat(
      'Aan de koude buiswand ontstaan waterdruppeltjes en er ontwijkt een prikkelende damp.',
      gases: {Gas.hcl},
      interpretation: 'Het gehydrateerde zout ontleedt en geeft water en waterstofchloride af.',
    ),
  ),
  Substance(id: 'nabr', name: 'natriumbromide', formula: 'NaBr', ions: {Sp.na: 1, Sp.br: 1}, appearance: 'witte kristallen', solidArgb: _white, level: Level.vwo),
  Substance(id: 'kbr', name: 'kaliumbromide', formula: 'KBr', ions: {Sp.k: 1, Sp.br: 1}, appearance: 'witte kristallen', solidArgb: _white, level: Level.vwo),
  Substance(id: 'nai', name: 'natriumjodide', formula: 'NaI', ions: {Sp.na: 1, Sp.i: 1}, appearance: 'witte kristallen', solidArgb: _white, level: Level.vwo),
  Substance(id: 'ki', name: 'kaliumjodide', formula: 'KI', ions: {Sp.k: 1, Sp.i: 1}, appearance: 'witte kristallen', solidArgb: _white, level: Level.vwo),
  Substance(id: 'na2so3', name: 'natriumsulfiet', formula: 'Na₂SO₃', ions: {Sp.na: 2, Sp.so3: 1}, appearance: 'wit poeder', solidArgb: _white, level: Level.vwo),
  Substance(
    id: 'na2s2o3',
    name: 'natriumthiosulfaat',
    formula: 'Na₂S₂O₃·5H₂O',
    ions: {Sp.na: 2, Sp.s2o3: 1},
    appearance: 'kleurloze kristallen',
    solidArgb: 0xFFEFF3F5,
    level: Level.vwo,
    heat: DryHeat(
      'De kristallen smelten in hun eigen kristalwater; bij sterker verhitten ontstaat een gele vaste stof.',
      interpretation: 'Eerst ontwijkt kristalwater; daarna ontleedt thiosulfaat onder vorming van zwavel.',
    ),
  ),
  Substance(id: 'na2c2o4', name: 'natriumoxalaat', formula: 'Na₂C₂O₄', ions: {Sp.na: 2, Sp.c2o4: 1}, appearance: 'wit poeder', solidArgb: _white, level: Level.vwo),
  Substance(
    id: 'ch3coona',
    name: 'natriumacetaat',
    formula: 'CH₃COONa',
    ions: {Sp.na: 1, Sp.ac: 1},
    appearance: 'wit poeder',
    solidArgb: _white,
    level: Level.vwo,
    heat: DryHeat('De stof smelt; bij sterk verhitten wordt ze zwart en ruik je een brandlucht.'),
  ),
  Substance(id: 'na3po4', name: 'natriumfosfaat', formula: 'Na₃PO₄', ions: {Sp.na: 3, Sp.po4: 1}, appearance: 'wit poeder', solidArgb: _white, level: Level.vwo),
];

final _byId = {for (final s in substances) s.id: s};

Substance substanceById(String id) => _byId[id]!;

enum ReagentKind { solution, indicator, starch, hexane, water }

enum Indicator {
  methylOrange('methyloranje', 3.1, 4.4, 'rood', 'oranje', 'geel', 0xFFD8322A, 0xFFF08A24, 0xFFF4CF3A),
  bromothymolBlue('broomthymolblauw', 6.0, 7.6, 'geel', 'groen', 'blauw', 0xFFE8CF3A, 0xFF4E9E55, 0xFF2D5FB8),
  phenolphthalein('fenolftaleïne', 8.2, 10.0, 'kleurloos', 'lichtroze', 'roodpaars', 0x00FFFFFF, 0xFFF2A6CF, 0xFFC4237A);

  const Indicator(
    this.name,
    this.from,
    this.to,
    this.acidColor,
    this.midColor,
    this.baseColor,
    this.acidArgb,
    this.midArgb,
    this.baseArgb,
  );
  final String name;
  final double from;
  final double to;
  final String acidColor;
  final String midColor;
  final String baseColor;
  final int acidArgb;
  final int midArgb;
  final int baseArgb;

  String colorAt(double ph) =>
      ph < from ? acidColor : (ph > to ? baseColor : midColor);
  int argbAt(double ph) => ph < from ? acidArgb : (ph > to ? baseArgb : midArgb);
}

class Reagent {
  const Reagent({
    required this.id,
    required this.name,
    required this.label,
    required this.argb,
    this.conc = const {},
    this.kind = ReagentKind.solution,
    this.indicator,
  });

  final String id;
  final String name;

  /// Formula and concentration as printed on the bottle.
  final String label;
  final int argb;
  final Map<Sp, double> conc;
  final ReagentKind kind;
  final Indicator? indicator;

  Color get color => Color(argb);
  bool get hasDose => kind == ReagentKind.solution;
}

const reagents = <Reagent>[
  Reagent(id: 'hcl', name: 'zoutzuur', label: 'HCl(aq) 2 M', argb: 0x22E8F0F8, conc: {Sp.h: 2, Sp.cl: 2}),
  Reagent(id: 'hno3', name: 'salpeterzuur', label: 'HNO₃(aq) 2 M', argb: 0x22E8F0F8, conc: {Sp.h: 2, Sp.no3: 2}),
  Reagent(id: 'h2so4', name: 'verdund zwavelzuur', label: 'H₂SO₄(aq) 1 M', argb: 0x22E8F0F8, conc: {Sp.h: 2, Sp.so4: 1}),
  Reagent(id: 'naoh', name: 'natronloog', label: 'NaOH(aq) 2 M', argb: 0x22E8F0F8, conc: {Sp.na: 2, Sp.oh: 2}),
  Reagent(id: 'bano3', name: 'bariumnitraatoplossing', label: 'Ba(NO₃)₂(aq) 0,1 M', argb: 0x22E8F0F8, conc: {Sp.ba: 0.1, Sp.no3: 0.2}),
  Reagent(id: 'agno3', name: 'zilvernitraatoplossing', label: 'AgNO₃(aq) 0,1 M', argb: 0x22E8F0F8, conc: {Sp.ag: 0.1, Sp.no3: 0.1}),
  Reagent(id: 'limewater', name: 'kalkwater', label: 'Ca(OH)₂(aq) verzadigd', argb: 0x22E8F0F8, conc: {Sp.ca: 0.02, Sp.oh: 0.04}),
  Reagent(id: 'ki', name: 'kaliumjodide-oplossing', label: 'KI(aq) 0,1 M', argb: 0x22E8F0F8, conc: {Sp.k: 0.1, Sp.i: 0.1}),
  Reagent(id: 'kscn', name: 'kaliumthiocyanaatoplossing', label: 'KSCN(aq) 0,1 M', argb: 0x22E8F0F8, conc: {Sp.k: 0.1, Sp.scn: 0.1}),
  Reagent(id: 'br2', name: 'broomwater', label: 'Br₂(aq) 0,02 M', argb: 0xFFE8962E, conc: {Sp.br2: 0.02}),
  Reagent(id: 'i2', name: 'joodoplossing', label: 'I₂ in KI(aq) 0,01 M', argb: 0xFF9A5A1A, conc: {Sp.i2: 0.01, Sp.k: 0.03, Sp.i: 0.03}),
  Reagent(id: 'kmno4', name: 'aangezuurde kaliumpermanganaatoplossing', label: 'KMnO₄ 0,01 M in H₂SO₄ 1 M', argb: 0xFF8E2D9E, conc: {Sp.k: 0.01, Sp.mno4: 0.01, Sp.h: 2, Sp.so4: 1}),
  Reagent(id: 'h2o2', name: 'waterstofperoxide-oplossing', label: 'H₂O₂(aq) 3%', argb: 0x22E8F0F8, conc: {Sp.h2o2: 0.9}),
  Reagent(id: 'starch', name: 'zetmeeloplossing', label: 'zetmeel(aq)', argb: 0x55EEEEE6, kind: ReagentKind.starch),
  Reagent(id: 'hexane', name: 'hexaan', label: 'C₆H₁₄(l)', argb: 0x22F8F4E0, kind: ReagentKind.hexane),
  Reagent(id: 'mo', name: 'methyloranje', label: 'indicator', argb: 0xFFF08A24, kind: ReagentKind.indicator, indicator: Indicator.methylOrange),
  Reagent(id: 'btb', name: 'broomthymolblauw', label: 'indicator', argb: 0xFF4E9E55, kind: ReagentKind.indicator, indicator: Indicator.bromothymolBlue),
  Reagent(id: 'fft', name: 'fenolftaleïne', label: 'indicator', argb: 0x33F2A6CF, kind: ReagentKind.indicator, indicator: Indicator.phenolphthalein),
];

Reagent reagentById(String id) => reagents.firstWhere((r) => r.id == id);

/// Universal indicator paper: the colour band for a pH.
class PaperColor {
  const PaperColor(this.ph, this.name, this.argb);
  final int ph;
  final String name;
  final int argb;
}

const paperScale = <PaperColor>[
  PaperColor(0, 'donkerrood', 0xFFB0122A),
  PaperColor(1, 'rood', 0xFFD8202A),
  PaperColor(2, 'oranjerood', 0xFFE84A26),
  PaperColor(3, 'oranje', 0xFFF07A22),
  PaperColor(4, 'oranjegeel', 0xFFF5A623),
  PaperColor(5, 'geel', 0xFFF4D03A),
  PaperColor(6, 'geelgroen', 0xFFC4D545),
  PaperColor(7, 'groen', 0xFF5DB55A),
  PaperColor(8, 'blauwgroen', 0xFF2E9C8E),
  PaperColor(9, 'blauw', 0xFF2F72C0),
  PaperColor(10, 'donkerblauw', 0xFF2D4FA8),
  PaperColor(11, 'blauwpaars', 0xFF4B3C9E),
  PaperColor(12, 'paars', 0xFF5E2E8E),
  PaperColor(13, 'donkerpaars', 0xFF4A1F6E),
  PaperColor(14, 'donkerpaars', 0xFF3A1756),
];

/// The paper reads whole numbers; its green band is a little wider, the
/// way real universal indicator paper is.
PaperColor paperFor(double ph) {
  final int band;
  if (ph >= 6.5 && ph < 7.6) {
    band = 7;
  } else {
    band = ph.round().clamp(0, 14);
  }
  return paperScale[band];
}
