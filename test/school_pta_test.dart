import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:luma/features/plugins/installed/school/logic/pta/pta_binas.dart';
import 'package:luma/features/plugins/installed/school/logic/pta/pta_chemistry.dart';
import 'package:luma/features/plugins/installed/school/logic/pta/pta_lab.dart';
import 'package:luma/features/plugins/installed/school/logic/pta/pta_scenarios.dart';

/// A lab with [id] dissolved in tube 1.
PtaLab _dissolved(String id) {
  final lab = PtaLab(substanceById(id));
  lab.addSample(0);
  lab.addWater(0);
  return lab;
}

String _add(PtaLab lab, String reagent, [Dose dose = Dose.drops]) =>
    lab.addReagent(0, reagentById(reagent), dose).observations.join(' ');

int _paper(String id) => paperFor(phOf(_dissolved(id).tubes[0])!).ph;

double _charge(Tube t) =>
    t.sp.entries.fold(0.0, (s, e) => s + e.key.charge * e.value);

void main() {
  group('pH of a dissolved spatula tip (Binas 49)', () {
    test('neutral salts', () {
      expect(_paper('nacl'), 7);
      expect(_paper('kno3'), 7);
      expect(_paper('na2so4'), 7);
      expect(_paper('na2s2o3'), 7);
    });

    test('acidic: ammonium and hydrated metal ions', () {
      expect(_paper('nh4cl'), 5);
      expect(_paper('alcl3'), 3);
      expect(_paper('fecl3'), 2);
    });

    test('basic: salts of weak acids', () {
      expect(_paper('nahco3'), 8);
      expect(_paper('ch3coona'), 9);
      expect(_paper('na2so3'), 10);
      expect(_paper('na2co3'), 12);
      expect(_paper('na3po4'), 13);
    });

    test('a strong acid in water is about pH 0, a strong base about 14', () {
      final acid = Tube()
        ..waterMl = 10
        ..sp[Sp.h] = 1
        ..sp[Sp.cl] = 1;
      expect(phOf(acid)!, closeTo(1.0, 0.05));
      final base = Tube()
        ..waterMl = 10
        ..sp[Sp.na] = 1
        ..sp[Sp.oh] = 1;
      expect(phOf(base)!, closeTo(13.0, 0.05));
    });
  });

  group('precipitation (Binas 45A)', () {
    test('silver halides have their own colours and stay in nitric acid', () {
      for (final (id, colour) in [
        ('nacl', 'wit'),
        ('nabr', 'lichtgeel'),
        ('nai', 'geel'),
      ]) {
        final lab = _dissolved(id);
        expect(
          _add(lab, 'agno3'),
          contains('Er ontstaat een $colour neerslag'),
        );
        expect(_add(lab, 'hno3', Dose.excess), isNot(contains('lost op')));
      }
      expect(_add(_dissolved('nano3'), 'agno3'), 'Geen zichtbare verandering.');
    });

    test(
      'barium carbonate dissolves in acid with fizzing, barium sulfate does not',
      () {
        final carbonate = _dissolved('na2co3');
        expect(_add(carbonate, 'bano3'), contains('wit neerslag'));
        final acid = _add(carbonate, 'hno3', Dose.excess);
        expect(acid, contains('bruist'));
        expect(acid, contains('neerslag lost op'));

        final sulfate = _dissolved('na2so4');
        expect(_add(sulfate, 'bano3'), contains('wit neerslag'));
        expect(
          _add(sulfate, 'hno3', Dose.excess),
          'Geen zichtbare verandering.',
        );
      },
    );

    test('hydrogen carbonate gives no barium precipitate in the cold', () {
      expect(
        _add(_dissolved('nahco3'), 'bano3'),
        'Geen zichtbare verandering.',
      );
    });

    test('silver sulfate stays dissolved at these concentrations', () {
      expect(
        _add(_dissolved('na2so4'), 'agno3'),
        'Geen zichtbare verandering.',
      );
    });

    test('an insoluble jar substance stays on the bottom', () {
      final lab = PtaLab(substanceById('caco3'))..addSample(0);
      expect(lab.addWater(0).observations.first, contains('lost niet op'));
      expect(lab.tubes[0].ppAmt(Pp.caCO3), greaterThan(0.45));
    });
  });

  group('hydroxides with sodium hydroxide', () {
    test(
      'zinc and aluminium hydroxide dissolve in excess, magnesium does not',
      () {
        for (final id in ['znso4', 'alcl3']) {
          final lab = _dissolved(id);
          expect(_add(lab, 'naoh'), contains('wit neerslag'));
          expect(_add(lab, 'naoh', Dose.excess), contains('neerslag lost op'));
        }
        final mg = _dissolved('mgcl2');
        expect(_add(mg, 'naoh'), contains('wit neerslag'));
        expect(_add(mg, 'naoh', Dose.excess), isNot(contains('lost op')));
      },
    );

    test('coloured hydroxides', () {
      expect(
        _add(_dissolved('cuso4'), 'naoh'),
        contains('lichtblauw neerslag'),
      );
      expect(_add(_dissolved('feso4'), 'naoh'), contains('vuilgroen neerslag'));
      expect(_add(_dissolved('fecl3'), 'naoh'), contains('roodbruin neerslag'));
    });

    test('ammonium gives ammonia that turns moist red litmus blue', () {
      final lab = _dissolved('nh4cl');
      _add(lab, 'naoh');
      lab.heat(0);
      expect(
        lab.gasTest(0, GasTest.litmus).observations.single,
        contains('kleurt blauw'),
      );
      final blank = _dissolved('nacl');
      _add(blank, 'naoh');
      blank.heat(0);
      expect(
        blank.gasTest(0, GasTest.litmus).observations.single,
        contains('blijft rood'),
      );
    });
  });

  group('gases with acid', () {
    test('carbonate gives a gas that turns limewater cloudy', () {
      final lab = _dissolved('na2co3');
      expect(_add(lab, 'hcl'), contains('bruist'));
      expect(
        lab.gasTest(0, GasTest.limewater).observations.single,
        contains('troebel'),
      );
    });

    test('sulfite releases a gas that decolourises iodine paper', () {
      final sulfite = _dissolved('na2so3');
      _add(sulfite, 'hcl');
      sulfite.heat(0);
      expect(
        sulfite.gasTest(0, GasTest.iodinePaper).observations.single,
        contains('bruine kleur op het papier verdwijnt'),
      );

      final thio = _dissolved('na2s2o3');
      expect(_add(thio, 'hcl'), contains('geelwitte troebeling'));
    });

    test('iodine paper stays brown with carbon dioxide', () {
      final lab = _dissolved('na2co3');
      _add(lab, 'hcl');
      expect(
        lab.gasTest(0, GasTest.iodinePaper).observations.single,
        contains('blijft bruin'),
      );
    });

    test('heating hydrogen carbonate releases carbon dioxide', () {
      final lab = PtaLab(substanceById('nahco3'))..addSample(0);
      expect(lab.heat(0).observations.single, contains('waterdruppeltjes'));
      expect(
        lab.gasTest(0, GasTest.limewater).observations.single,
        contains('troebel'),
      );
      expect(lab.tubes[0].solid!.id, 'na2co3');
    });

    test('magnesium in acid gives hydrogen that pops', () {
      final lab = PtaLab(substanceById('nacl'))
        ..addSample(0)
        ..addWater(0);
      _add(lab, 'hcl', Dose.excess);
      final obs = lab.addMetal(0, Metal.mg).observations.join(' ');
      expect(obs, contains('gasbelletjes'));
      expect(
        lab.gasTest(0, GasTest.burningSplint).observations.single,
        contains('plofje'),
      );
    });
  });

  group('redox (Binas 48)', () {
    test('acidified permanganate: decolourised by reductors only', () {
      expect(
        _add(_dissolved('feso4'), 'kmno4'),
        contains('paarse kleur verdwijnt'),
      );
      expect(
        _add(_dissolved('na2so3'), 'kmno4'),
        contains('paarse kleur verdwijnt'),
      );
      expect(_add(_dissolved('nai'), 'kmno4'), contains('kleurt bruin'));
      expect(_add(_dissolved('nacl'), 'kmno4'), contains('kleurt paars'));
    });

    test('oxalate only reacts with permanganate when heated', () {
      final lab = _dissolved('na2c2o4');
      expect(_add(lab, 'kmno4'), contains('kleurt paars'));
      final heated = lab.heat(0).observations.join(' ');
      expect(heated, contains('paarse kleur verdwijnt'));
      expect(heated, contains('gasbelletjes'));
    });

    test('bromine water frees iodine, which colours hexane purple', () {
      final lab = _dissolved('nai');
      expect(_add(lab, 'br2'), contains('gele kleur verdwijnt'));
      expect(_add(lab, 'hexane'), contains('(hexaan) is paars'));

      final bromide = _dissolved('nabr');
      expect(_add(bromide, 'br2'), contains('kleurt geel'));
      expect(_add(bromide, 'hexane'), contains('oranjebruin'));
    });

    test('thiosulfate and sulfite decolourise iodine, iodide does not', () {
      expect(
        _add(_dissolved('na2s2o3'), 'i2'),
        contains('bruine kleur verdwijnt'),
      );
      expect(
        _add(_dissolved('na2so3'), 'i2'),
        contains('bruine kleur verdwijnt'),
      );
      expect(_add(_dissolved('nai'), 'i2'), contains('kleurt bruin'));
    });

    test(
      'iron(III) and copper(II) oxidise iodide; starch turns blue-black',
      () {
        for (final id in ['fecl3', 'cuso4']) {
          final lab = _dissolved(id);
          expect(_add(lab, 'ki'), contains('kleurt bruin'));
          expect(_add(lab, 'starch'), contains('blauwzwart'));
        }
        expect(_add(_dissolved('feso4'), 'ki'), 'Geen zichtbare verandering.');
      },
    );

    test('hydrogen peroxide oxidises iodide even without acid', () {
      final lab = _dissolved('ki');
      expect(_add(lab, 'h2o2'), contains('kleurt bruin'));
    });

    test('a basic carbonate solution decolourises bromine water', () {
      expect(
        _add(_dissolved('na2co3'), 'br2'),
        contains('gele kleur verdwijnt'),
      );
    });

    test('thiocyanate shows iron(III), not iron(II)', () {
      expect(_add(_dissolved('fecl3'), 'kscn'), contains('bloedrood'));
      expect(_add(_dissolved('feso4'), 'kscn'), 'Geen zichtbare verandering.');
    });

    test('a more reactive metal plates out copper', () {
      final lab = _dissolved('cuso4');
      final obs = lab.addMetal(0, Metal.zn).observations.join(' ');
      expect(obs, contains('roodbruine aanslag'));
    });
  });

  test('flame colours (Binas 65A)', () {
    String flame(String id) =>
        PtaLab(substanceById(id)).flameTest().observations.single;
    expect(flame('nacl'), contains('geel'));
    expect(flame('kcl'), contains('lila'));
    expect(flame('cacl2'), contains('oranjerood'));
    expect(flame('bacl2'), contains('geelgroen'));
    expect(flame('nh4cl'), contains('geen kenmerkende kleur'));
  });

  test('every reaction keeps the solution electrically neutral', () {
    final rng = math.Random(4);
    final solutions = reagents.where((r) => r.hasDose).toList();
    for (final s in substances.where((s) => s.candidate)) {
      final lab = _dissolved(s.id);
      for (var step = 0; step < 6; step++) {
        final r = solutions[rng.nextInt(solutions.length)];
        lab.addReagent(0, r, rng.nextBool() ? Dose.drops : Dose.excess);
        if (step == 3) lab.heat(0);
        expect(
          _charge(lab.tubes[0]).abs(),
          lessThan(1e-6),
          reason: '${s.id} + ${r.id}',
        );
        for (final v in lab.tubes[0].sp.values) {
          expect(v, greaterThan(-1e-9), reason: '${s.id} + ${r.id}');
        }
      }
    }
  });

  group('sets', () {
    test('every photographed booklet group is usable', () {
      expect(havoBookletSets.map((set) => set.bookletNumber), [
        for (var number = 1; number <= 40; number++)
          if (number != 22) number,
      ]);
      for (final set in havoBookletSets) {
        expect(set.ids.toSet(), hasLength(set.ids.length), reason: set.title);
        expect(distinguishable(set.candidates), isTrue, reason: set.title);
      }
    });

    test('each HAVO mock exam draws four distinct booklet groups', () {
      final seen = <PtaSet>{};
      for (var seed = 0; seed < 100; seed++) {
        final sets = examSets(Level.havo, math.Random(seed));
        seen.addAll(sets);
        expect(sets.toSet(), hasLength(4));
        expect(sets.every(havoBookletSets.contains), isTrue);
        expect(sets.every((set) => set.candidates.length == 4), isTrue);
      }
      expect(
        seen,
        havoBookletSets.where((set) => set.candidates.length == 4).toSet(),
      );
    });

    test(
      'worked barium group separates by water, acid and fresh-sample pH',
      () {
        final nitrate = _dissolved('bano3');
        final oxide = _dissolved('bao');
        expect(
          nitrate.log.last.equations,
          contains('Ba(NO₃)₂(s) → Ba²⁺(aq) + 2 NO₃⁻(aq)'),
        );
        expect(_paper('bano3'), 7);
        expect(paperFor(phOf(oxide.tubes[0])!).ph, greaterThan(7));
        for (final id in ['baso4', 'baco3']) {
          final lab = _dissolved(id);
          expect(lab.log.last.observations.first, contains('lost niet op'));
          final acid = _add(lab, 'hcl', Dose.excess);
          if (id == 'baco3') {
            expect(acid, contains('gasbelletjes'));
            expect(acid, contains('lost op'));
          } else {
            expect(acid, 'Geen zichtbare verandering.');
          }
        }
      },
    );

    test('liquid and metallic samples produce distinct test observations', () {
      final hexane = _dissolved('hexane');
      expect(
        hexane.log.last.observations.join(),
        contains('twee vloeistoflagen'),
      );
      final ethanol = PtaLab(substanceById('ethanol'))..addSample(0);
      expect(ethanol.heat(0).observations.single, contains('78 °C'));
      final sodium = _dissolved('metal-na');
      expect(
        sodium.log.last.equations,
        contains('2 Na(s) + 2 H₂O(l) → 2 Na⁺(aq) + 2 OH⁻(aq) + H₂(g)'),
      );
      final lead = _dissolved('pbno32');
      expect(_add(lead, 'ki'), contains('geel neerslag'));
    });

    test('every set has four real candidates and can be solved', () {
      for (final set in ptaSets) {
        expect(set.ids.toSet(), hasLength(4), reason: set.id);
        for (final c in set.candidates) {
          expect(c.candidate, isTrue, reason: '${set.id}: ${c.id}');
          if (set.level == Level.havo) {
            expect(c.level, Level.havo, reason: '${set.id}: ${c.id}');
          }
        }
        expect(distinguishable(set.candidates), isTrue, reason: set.id);
      }
    });

    test('HAVO only sees HAVO sets', () {
      expect(setsFor(Level.havo).every((s) => s.level == Level.havo), isTrue);
      expect(setsFor(Level.vwo), hasLength(ptaSets.length));
    });

    test('a random set is four different, distinguishable substances', () {
      final rng = math.Random(1);
      for (var i = 0; i < 5; i++) {
        final set = randomSet(Level.havo, rng);
        expect(set.ids.toSet(), hasLength(4));
        expect(set.candidates.every((c) => c.level == Level.havo), isTrue);
        expect(distinguishable(set.candidates), isTrue);
      }
    });
  });

  test('estimated lab time adds up per action', () {
    final lab = PtaLab(substanceById('nacl'));
    lab.addSample(0);
    lab.addWater(0);
    lab.heat(0);
    lab.flameTest();
    expect(lab.minutes, 2 + 1 + 4 + 4);
    expect(lab.actions, 4);
    expect(lab.log, hasLength(4));
  });

  group('Binas sheets follow the lab data', () {
    test('45A', () {
      expect(solubility(Sp.ag, Sp.cl), 's');
      expect(solubility(Sp.ba, Sp.so4), 's');
      expect(solubility(Sp.ca, Sp.so4), 'm');
      expect(solubility(Sp.na, Sp.co3), 'g');
      expect(solubility(Sp.nh4, Sp.oh), '-');
    });

    test('49 lists ammonium with its constant', () {
      final sheet = binasSheets().firstWhere((s) => s.code == '49');
      final row = sheet.rows.firstWhere((r) => r.first == 'NH₄⁺');
      expect(row[2], '5,6·10⁻¹⁰');
      expect(row[3], '9,25');
    });

    test('every sheet has rows as wide as its header', () {
      for (final sheet in binasSheets()) {
        for (final row in sheet.rows) {
          expect(row, hasLength(sheet.headers.length), reason: sheet.code);
        }
      }
    });
  });
}
