import 'dart:math' as math;

import 'pta_chemistry.dart';

/// Reference sheets in the layout of the Binas tables a student uses on the
/// practical. The numbers come from the same data the lab runs on, so the
/// sheet and the simulation never disagree. It is a summary for practice,
/// not a copy of Binas.
class BinasSheet {
  const BinasSheet(this.code, this.title, this.headers, this.rows, this.note);
  final String code;
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final String note;
}

const binasCations = [
  Sp.na, Sp.k, Sp.nh4, Sp.mg, Sp.ca, Sp.ba, Sp.cu, Sp.fe2, Sp.fe3, Sp.zn, Sp.al, Sp.ag, //
];
const binasAnions = [
  Sp.oh, Sp.cl, Sp.br, Sp.i, Sp.no3, Sp.so4, Sp.co3, Sp.po4, Sp.so3, Sp.s2o3, Sp.c2o4, Sp.ac, //
];

/// Combinations the lab never mixes, filled in from the literature so the
/// table is complete. "-" means: does not exist, or reacts with water or by
/// a redox reaction.
const _solubilityExtra = <(Sp, Sp), String>{
  (Sp.nh4, Sp.oh): '-',
  (Sp.mg, Sp.co3): 's',
  (Sp.mg, Sp.po4): 's',
  (Sp.mg, Sp.so3): 'm',
  (Sp.mg, Sp.c2o4): 's',
  (Sp.cu, Sp.i): '-',
  (Sp.cu, Sp.co3): 's',
  (Sp.cu, Sp.po4): 's',
  (Sp.cu, Sp.so3): '-',
  (Sp.cu, Sp.s2o3): '-',
  (Sp.cu, Sp.c2o4): 's',
  (Sp.fe2, Sp.co3): 's',
  (Sp.fe2, Sp.po4): 's',
  (Sp.fe2, Sp.so3): 's',
  (Sp.fe2, Sp.c2o4): 's',
  (Sp.fe3, Sp.i): '-',
  (Sp.fe3, Sp.co3): '-',
  (Sp.fe3, Sp.po4): 's',
  (Sp.fe3, Sp.so3): '-',
  (Sp.fe3, Sp.s2o3): '-',
  (Sp.zn, Sp.co3): 's',
  (Sp.zn, Sp.po4): 's',
  (Sp.zn, Sp.so3): 's',
  (Sp.zn, Sp.c2o4): 's',
  (Sp.al, Sp.co3): '-',
  (Sp.al, Sp.po4): 's',
  (Sp.al, Sp.so3): '-',
  (Sp.al, Sp.s2o3): '-',
  (Sp.ag, Sp.s2o3): '-',
  (Sp.ag, Sp.ac): 'm',
};

String solubility(Sp cation, Sp anion) {
  final extra = _solubilityExtra[(cation, anion)];
  if (extra != null) return extra;
  for (final p in Pp.values) {
    if (p.cation == cation && p.anion == anion) return p.moderate ? 'm' : 's';
  }
  return 'g';
}

/// Standard electrode potentials (V⁰ at 298 K), strongest oxidator first.
const redoxCouples = <(String, String, double)>[
  ('H₂O₂ + 2 H⁺', '2 H₂O', 1.78),
  ('MnO₄⁻ + 8 H⁺', 'Mn²⁺ + 4 H₂O', 1.51),
  ('Cl₂', '2 Cl⁻', 1.36),
  ('O₂ + 4 H⁺', '2 H₂O', 1.23),
  ('Br₂', '2 Br⁻', 1.07),
  ('NO₃⁻ + 4 H⁺', 'NO + 2 H₂O', 0.96),
  ('Cu²⁺ + I⁻', 'CuI', 0.86),
  ('Ag⁺', 'Ag', 0.80),
  ('Fe³⁺', 'Fe²⁺', 0.77),
  ('O₂ + 2 H⁺', 'H₂O₂', 0.68),
  ('MnO₄⁻ + 2 H₂O', 'MnO₂ + 4 OH⁻', 0.59),
  ('I₂', '2 I⁻', 0.54),
  ('Cu²⁺', 'Cu', 0.34),
  ('SO₄²⁻ + 4 H⁺', 'SO₂ + 2 H₂O', 0.17),
  ('S₄O₆²⁻', '2 S₂O₃²⁻', 0.08),
  ('2 H⁺', 'H₂', 0.00),
  ('Fe²⁺', 'Fe', -0.44),
  ('2 CO₂ + 2 H⁺', 'H₂C₂O₄', -0.49),
  ('Zn²⁺', 'Zn', -0.76),
  ('2 H₂O', 'H₂ + 2 OH⁻', -0.83),
  ('SO₄²⁻ + H₂O', 'SO₃²⁻ + 2 OH⁻', -0.93),
  ('Al³⁺', 'Al', -1.66),
  ('Mg²⁺', 'Mg', -2.37),
  ('Na⁺', 'Na', -2.71),
  ('Ca²⁺', 'Ca', -2.87),
  ('Ba²⁺', 'Ba', -2.91),
  ('K⁺', 'K', -2.93),
];

const _sup = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', //
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '-': '⁻',
};

/// 10^-pK written the Binas way: "5,4·10⁻²".
String scientific(double pK) {
  final value = math.pow(10, -pK).toDouble();
  var exp = (math.log(value) / math.ln10).floor();
  var mant = value / math.pow(10, exp);
  if (double.parse(mant.toStringAsFixed(1)) >= 10) {
    mant /= 10;
    exp += 1;
  }
  final e = exp.toString().split('').map((c) => _sup[c]).join();
  return '${mant.toStringAsFixed(1).replaceAll('.', ',')}·10$e';
}

String _dec(double v, [int digits = 2]) =>
    '${v < 0 ? '−' : ''}${v.abs().toStringAsFixed(digits).replaceAll('.', ',')}';

List<BinasSheet> binasSheets() {
  final acidRows = <(double, List<String>)>[];
  for (final s in acidBaseSystems) {
    for (var k = 0; k < s.pKa.length; k++) {
      final pKa = s.pKa[k];
      acidRows.add((
        pKa,
        [s.acid[k], s.base[k], scientific(pKa), _dec(pKa), scientific(14 - pKa)],
      ));
    }
  }
  acidRows.sort((a, b) => a.$1.compareTo(b.$1));

  final pp = [
    for (final p in Pp.values) [p.formula, p.name, p.colorName],
  ];

  return [
    BinasSheet(
      '45A',
      'Oplosbaarheid van zouten in water',
      ['', for (final a in binasAnions) a.formula],
      [
        for (final c in binasCations)
          [c.formula, for (final a in binasAnions) solubility(c, a)],
      ],
      'g = goed oplosbaar · m = matig oplosbaar · s = slecht oplosbaar · '
          '- = bestaat niet of reageert (met water of als redoxreactie). '
          'Slecht oplosbaar betekent: er ontstaat een neerslag als je de ionen samenvoegt.',
    ),
    BinasSheet(
      '48',
      'Standaardelektrodepotentialen',
      ['Oxidator', 'Reductor', 'V⁰ (V)'],
      [
        for (final (ox, red, v) in redoxCouples) [ox, red, _dec(v)],
      ],
      'Halfreacties: oxidator + n e⁻ ⇄ reductor. Een redoxreactie kan verlopen '
          'als V⁰ van de oxidator groter is dan V⁰ van de reductor. Is het '
          'verschil klein (< 0,3 V), dan verloopt de reactie vaak langzaam.',
    ),
    BinasSheet(
      '49',
      'Zuurconstanten en baseconstanten (298 K)',
      ['Zuur', 'Geconjugeerde base', 'Kz', 'pKz', 'Kb'],
      [
        ['HCl, HNO₃, H₂SO₄', 'Cl⁻, NO₃⁻, HSO₄⁻', 'sterk', '', ''],
        for (final r in acidRows) r.$2,
        ['H₂O', 'OH⁻', '1,0·10⁻¹⁴', '14,00', ''],
      ],
      'Hoe kleiner pKz, hoe sterker het zuur. Kz · Kb = Kw. Een zout van een '
          'zwak zuur geeft een basische oplossing; een gehydrateerd metaalion of '
          'NH₄⁺ geeft een zure oplossing.',
    ),
    BinasSheet(
      '52A',
      'Zuur-base-indicatoren',
      ['Indicator', 'Omslagtraject', 'Zuur', 'Base'],
      [
        for (final i in Indicator.values)
          [i.name, '${_dec(i.from, 1)} – ${_dec(i.to, 1)}', i.acidColor, i.baseColor],
        ['universeel indicatorpapier', '1 – 14', 'rood', 'paars'],
      ],
      'Binnen het omslagtraject zie je een mengkleur.',
    ),
    BinasSheet(
      '65A',
      'Vlamkleuren',
      ['Ion', 'Vlamkleur'],
      [
        for (final e in flames.entries) [e.key.formula, e.value.description],
        ['Li⁺', 'karmijnrood'],
        ['Sr²⁺', 'rood'],
        ['NH₄⁺, Mg²⁺, Zn²⁺, Al³⁺', 'geen kenmerkende kleur'],
      ],
      'Natrium geeft al bij sporen een felgele vlam die andere kleuren kan '
          'overstralen; kijk bij kalium door blauw kobaltglas.',
    ),
    BinasSheet(
      '65B',
      'Kleuren van deeltjes en neerslagen',
      ['Deeltje of stof', 'Naam', 'Kleur'],
      [
        ['Cu²⁺(aq)', 'koper(II)ion', 'blauw'],
        ['Fe²⁺(aq)', 'ijzer(II)ion', 'lichtgroen'],
        ['Fe³⁺(aq)', 'ijzer(III)ion', 'geel tot geelbruin'],
        ['MnO₄⁻(aq)', 'permanganaation', 'paars'],
        ['Mn²⁺(aq)', 'mangaan(II)ion', 'vrijwel kleurloos'],
        ['FeSCN²⁺(aq)', 'ijzer(III)thiocyanaat', 'bloedrood'],
        ['I₂ (in water)', 'jood', 'geel tot bruin'],
        ['I₂ (in hexaan)', 'jood', 'paars'],
        ['I₂ + zetmeel', 'jood-zetmeel', 'blauwzwart'],
        ['Br₂ (in water)', 'broom', 'geel tot oranje'],
        ['Br₂ (in hexaan)', 'broom', 'oranjebruin'],
        ...pp,
      ],
      'Ionen die hier niet staan (Na⁺, K⁺, NH₄⁺, Mg²⁺, Ca²⁺, Ba²⁺, Zn²⁺, Al³⁺, '
          'Ag⁺ en de negatieve ionen uit tabel 45A) zijn kleurloos.',
    ),
  ];
}
