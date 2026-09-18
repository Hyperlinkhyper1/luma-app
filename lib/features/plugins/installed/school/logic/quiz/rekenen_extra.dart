import '../quiz_bank.dart';
import 'gen.dart';

const _getallen = 'Getallen en bewerkingen';
const _verhoudingen = 'Verhoudingen';
const _meten = 'Meten en meetkunde';
const _verbanden = 'Verbanden';

String _hhmm(int minutes) {
  final m = minutes % (24 * 60);
  final h = m ~/ 60;
  return '${h.toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

const _namen = [
  'Sam',
  'Noor',
  'Yusuf',
  'Fenna',
  'Milan',
  'Lieke',
  'Daan',
  'Amira',
  'Jesse',
  'Sanne',
  'Bram',
  'Nina',
  'Youssef',
  'Elin',
  'Tygo',
  'Roos',
];

/// The generated part of the rekenen bank.
///
/// Every template stays inside groep-8 number ranges: whole numbers up to a
/// hundred thousand, decimals to two places, fractions with familiar
/// denominators. That is what keeps a generated som the same weight as a
/// hand-written one.
List<QuizQuestion> buildRekenenExtra() {
  final g = QuizGen('grek', seed: 20260908);

  // --- Optellen en aftrekken -------------------------------------------------
  for (var i = 0; i < 28; i++) {
    final a = g.between(1240, 8930);
    final b = g.between(1130, 8940);
    final sum = a + b;
    g.add(
      topic: _getallen,
      prompt: 'Hoeveel is ${nlNum(a)} + ${nlNum(b)}?',
      answer: nlNum(sum),
      wrong: g.nums(sum, [sum + 10, sum - 100, sum + 1000, sum - 10]),
      why: 'Tel eerst de duizendtallen op en werk daarna naar de eenheden toe.',
    );
  }

  for (var i = 0; i < 26; i++) {
    final a = g.between(4200, 9800);
    final b = g.between(1100, 4100);
    final diff = a - b;
    g.add(
      topic: _getallen,
      prompt: 'Hoeveel is ${nlNum(a)} - ${nlNum(b)}?',
      answer: nlNum(diff),
      wrong: g.nums(diff, [diff + 100, diff - 10, diff + 1, a + b]),
      why:
          'Lenen bij het aftrekken: kijk goed of je een tiental moet omwisselen.',
    );
  }

  // --- Vermenigvuldigen en delen --------------------------------------------
  for (var i = 0; i < 26; i++) {
    final a = g.between(12, 49);
    final b = g.between(12, 39);
    final p = a * b;
    g.add(
      topic: _getallen,
      prompt: 'Hoeveel is $a × $b?',
      answer: nlNum(p),
      wrong: g.nums(p, [p + a, p - b, p + 10 * a, p - 100]),
      why: 'Splits: $a × $b = $a × ${b - b % 10} + $a × ${b % 10}.',
    );
  }

  for (var i = 0; i < 20; i++) {
    final a = g.between(112, 949);
    final b = g.between(3, 9);
    final p = a * b;
    g.add(
      topic: _getallen,
      prompt: 'Hoeveel is ${nlNum(a)} × $b?',
      answer: nlNum(p),
      wrong: g.nums(p, [p + b, p - a, p + 100, p - 10]),
    );
  }

  for (var i = 0; i < 26; i++) {
    final d = g.between(3, 12);
    final q = g.between(14, 88);
    final n = d * q;
    g.add(
      topic: _getallen,
      prompt: 'Hoeveel is ${nlNum(n)} : $d?',
      answer: nlNum(q),
      wrong: g.nums(q, [q + 1, q - 1, q + 10, q * 2]),
      why: 'Controle: $q × $d = ${nlNum(n)}.',
    );
  }

  // --- Kommagetallen ---------------------------------------------------------
  for (var i = 0; i < 22; i++) {
    final a = g.between(150, 9500);
    final b = g.between(140, 6400);
    final sum = (a + b) / 100;
    g.add(
      topic: _getallen,
      prompt: 'Hoeveel is ${nlNum(a / 100)} + ${nlNum(b / 100)}?',
      answer: nlNum(sum),
      wrong: g.nums(sum, [
        (a + b + 10) / 100,
        (a + b - 100) / 100,
        (a + b) / 10,
        (a + b + 1) / 100,
      ]),
      why: 'Zet de kommas onder elkaar en tel dan pas op.',
    );
  }

  for (var i = 0; i < 18; i++) {
    final a = g.between(4000, 9900);
    final b = g.between(150, 3900);
    final diff = (a - b) / 100;
    g.add(
      topic: _getallen,
      prompt: 'Hoeveel is ${nlNum(a / 100)} - ${nlNum(b / 100)}?',
      answer: nlNum(diff),
      wrong: g.nums(diff, [
        (a - b + 10) / 100,
        (a - b - 1) / 100,
        (a + b) / 100,
        (a - b + 100) / 100,
      ]),
    );
  }

  for (var i = 0; i < 24; i++) {
    final factor = g.oneOf([10, 100, 1000]);
    final base = g.between(105, 9850) / 100;
    final maal = g.rnd.nextBool();
    if (!maal && (base * 100).round() * 10 % factor != 0) {
      continue;
    }
    final answer = maal ? base * factor : base / factor;
    g.add(
      topic: _getallen,
      prompt: maal
          ? 'Hoeveel is ${nlNum(base)} × ${nlNum(factor)}?'
          : 'Hoeveel is ${nlNum(base)} : ${nlNum(factor)}?',
      answer: nlNum(answer),
      wrong: g.nums(answer, [
        maal ? base * factor * 10 : base / (factor * 10),
        maal ? base * factor / 10 : base / factor * 10,
        base,
        maal ? base * factor + 1 : base / factor + 1,
      ]),
      why: maal
          ? 'De komma schuift naar rechts, net zoveel plaatsen als er nullen zijn.'
          : 'De komma schuift naar links, net zoveel plaatsen als er nullen zijn.',
    );
  }

  // --- Afronden --------------------------------------------------------------
  for (var i = 0; i < 22; i++) {
    final n = g.between(1240, 98750);
    final naar = g.oneOf([10, 100, 1000]);
    final answer = (n / naar).round() * naar;
    g.add(
      topic: _getallen,
      prompt:
          'Rond ${nlNum(n)} af op ${naar == 10
              ? 'tientallen'
              : naar == 100
              ? 'honderdtallen'
              : 'duizendtallen'}.',
      answer: nlNum(answer),
      wrong: g.nums(answer, [
        answer + naar,
        answer - naar,
        (n / naar).floor() * naar + naar * 2,
        n,
      ]),
      why: 'Kijk naar het cijfer erachter: 5 of meer gaat omhoog.',
    );
  }

  // --- Breuken ---------------------------------------------------------------
  const breuken = [
    (1, 2),
    (1, 3),
    (2, 3),
    (1, 4),
    (3, 4),
    (1, 5),
    (2, 5),
    (3, 5),
    (4, 5),
    (1, 8),
    (3, 8),
    (5, 8),
    (1, 10),
    (3, 10),
    (7, 10),
    (1, 6),
    (5, 6),
  ];
  for (var i = 0; i < 28; i++) {
    final f = g.oneOf(breuken);
    final n = f.$2 * g.between(4, 40);
    final answer = n ~/ f.$2 * f.$1;
    g.add(
      topic: _getallen,
      prompt: 'Hoeveel is ${f.$1}/${f.$2} van ${nlNum(n)}?',
      answer: nlNum(answer),
      wrong: g.nums(answer, [
        n ~/ f.$2,
        answer + f.$2,
        answer - f.$1,
        n - answer,
      ]),
      why: 'Deel eerst door ${f.$2} en vermenigvuldig daarna met ${f.$1}.',
    );
  }

  for (var i = 0; i < 18; i++) {
    final f = g.oneOf(breuken);
    final m = g.between(2, 9);
    g.add(
      topic: _getallen,
      prompt: 'Vereenvoudig de breuk ${f.$1 * m}/${f.$2 * m}.',
      answer: '${f.$1}/${f.$2}',
      wrong: [
        '${f.$1 * 2}/${f.$2}',
        '${f.$1}/${f.$2 * 2}',
        '${f.$1 + 1}/${f.$2 + 1}',
        '${f.$2}/${f.$1}',
      ],
      why: 'Deel teller en noemer allebei door $m.',
    );
  }

  // --- Negatieve getallen ----------------------------------------------------
  for (var i = 0; i < 16; i++) {
    final laag = -g.between(2, 14);
    final hoog = g.between(2, 19);
    final naam = g.oneOf(_namen);
    g.add(
      topic: _getallen,
      prompt:
          'De thermometer stond bij $naam op $laag °C. '
          "'s Middags was het $hoog °C. Hoeveel graden is het gestegen?",
      answer: '${hoog - laag} graden',
      wrong: [
        '${hoog + laag} graden',
        '${(hoog - laag) - 2} graden',
        '$hoog graden',
        '${(hoog - laag) + 3} graden',
      ],
      why:
          'Van $laag naar 0 is ${-laag} graden, en van 0 naar $hoog nog eens '
          '$hoog graden.',
    );
  }

  // --- Procenten -------------------------------------------------------------
  const percentages = [5, 10, 15, 20, 25, 30, 40, 50, 60, 75, 80, 90];
  for (var i = 0; i < 30; i++) {
    final p = g.oneOf(percentages);
    final base = g.between(2, 48) * 20;
    final answer = base * p ~/ 100;
    g.add(
      topic: _verhoudingen,
      prompt: 'Hoeveel is $p% van ${nlNum(base)}?',
      answer: nlNum(answer),
      wrong: g.nums(answer, [
        base * p ~/ 10,
        base - answer,
        answer + 10,
        base * (p + 10) ~/ 100,
      ]),
      why:
          '1% van ${nlNum(base)} is ${nlNum(base / 100)}, dus $p% is '
          '$p × ${nlNum(base / 100)}.',
    );
  }

  for (var i = 0; i < 24; i++) {
    final p = g.oneOf([10, 20, 25, 30, 40, 50]);
    final prijsCent = g.between(8, 90) * 500;
    final kortingCent = prijsCent * p ~/ 100;
    final nieuw = (prijsCent - kortingCent) / 100;
    g.add(
      topic: _verhoudingen,
      prompt:
          'Een jas kost ${nlEuro(prijsCent / 100)}. In de uitverkoop krijg '
          'je $p% korting. Wat betaal je nu?',
      answer: nlEuro(nieuw),
      wrong: g.euros(nieuw, [
        kortingCent / 100,
        (prijsCent + kortingCent) / 100,
        nieuw - 1,
        nieuw + 5,
      ]),
      why:
          'De korting is ${nlEuro(kortingCent / 100)}; die haal je van de '
          'prijs af.',
    );
  }

  for (var i = 0; i < 24; i++) {
    final personen = g.oneOf([2, 3, 4, 5, 6]);
    final gram = personen * g.between(15, 90);
    final nieuwe = personen * g.between(2, 5);
    final answer = gram ~/ personen * nieuwe;
    final item = g.oneOf(['rijst', 'bloem', 'suiker', 'pasta', 'havermout']);
    g.add(
      topic: _verhoudingen,
      prompt:
          'Voor $personen personen heb je ${nlNum(gram)} gram $item nodig. '
          'Hoeveel gram heb je nodig voor $nieuwe personen?',
      answer: '${nlNum(answer)} gram',
      wrong: [
        '${nlNum(answer + gram)} gram',
        '${nlNum(gram * nieuwe)} gram',
        '${nlNum(answer ~/ 2)} gram',
        '${nlNum(answer + 100)} gram',
      ],
      why: 'Per persoon is het ${nlNum(gram ~/ personen)} gram.',
    );
  }

  for (var i = 0; i < 20; i++) {
    final schaal = g.oneOf([1000, 2500, 25000, 50000, 100000]);
    final cm = g.between(2, 18);
    final echteCm = schaal * cm;
    final meters = echteCm / 100;
    g.add(
      topic: _verhoudingen,
      prompt:
          'Op een kaart met schaal 1 : ${nlNum(schaal)} is een weg $cm cm '
          'lang. Hoe lang is die weg in het echt?',
      answer: meters >= 1000
          ? '${nlNum(meters / 1000)} km'
          : '${nlNum(meters)} m',
      wrong: [
        meters >= 1000 ? '${nlNum(meters)} km' : '${nlNum(meters * 10)} m',
        meters >= 1000
            ? '${nlNum(meters / 10000)} km'
            : '${nlNum(meters / 10)} m',
        '${nlNum(echteCm * 10)} cm',
        meters >= 1000
            ? '${nlNum(meters / 1000 + 5)} km'
            : '${nlNum(meters + 50)} m',
      ],
      why: '$cm cm × ${nlNum(schaal)} = ${nlNum(echteCm)} cm.',
    );
  }

  const gelijk = [
    ('1/2', '50%', '0,5'),
    ('1/4', '25%', '0,25'),
    ('3/4', '75%', '0,75'),
    ('1/5', '20%', '0,2'),
    ('2/5', '40%', '0,4'),
    ('3/5', '60%', '0,6'),
    ('4/5', '80%', '0,8'),
    ('1/10', '10%', '0,1'),
    ('3/10', '30%', '0,3'),
    ('7/10', '70%', '0,7'),
    ('9/10', '90%', '0,9'),
    ('1/20', '5%', '0,05'),
    ('1/1', '100%', '1'),
    ('1/8', '12,5%', '0,125'),
  ];
  for (final row in gelijk) {
    g.add(
      topic: _verhoudingen,
      prompt: 'Hoeveel procent is ${row.$1}?',
      answer: row.$2,
      wrong: g.others([for (final r in gelijk) r.$2], row.$2),
      why: '${row.$1} is hetzelfde als ${row.$3}, dus ${row.$2}.',
    );
    g.add(
      topic: _verhoudingen,
      prompt: 'Welk kommagetal hoort bij ${row.$2}?',
      answer: row.$3,
      wrong: g.others([for (final r in gelijk) r.$3], row.$3),
      why: '${row.$2} is ${row.$1}, en dat is ${row.$3}.',
    );
  }

  for (var i = 0; i < 20; i++) {
    final stuks = g.oneOf([3, 4, 5, 6, 8, 10, 12]);
    final perStuk = g.between(45, 480);
    final totaal = stuks * perStuk;
    final ding = g.oneOf([
      'schriften',
      'stiften',
      'flesjes',
      'broodjes',
      'ballen',
    ]);
    g.add(
      topic: _verhoudingen,
      prompt:
          'Een pak van $stuks $ding kost ${nlEuro(totaal / 100)}. '
          'Wat kost één stuk?',
      answer: nlEuro(perStuk / 100),
      wrong: g.euros(perStuk / 100, [
        totaal / 100 / (stuks + 1),
        perStuk / 100 + 0.5,
        perStuk / 100 - 0.25,
        totaal / 100,
      ]),
      why: '${nlEuro(totaal / 100)} : $stuks = ${nlEuro(perStuk / 100)}.',
    );
  }

  for (var i = 0; i < 14; i++) {
    final p = g.oneOf([10, 20, 25, 50]);
    final base = g.between(4, 40) * 20;
    final answer = base + base * p ~/ 100;
    g.add(
      topic: _verhoudingen,
      prompt:
          'Een school had ${nlNum(base)} leerlingen. Het aantal groeide met '
          '$p%. Hoeveel leerlingen zijn het er nu?',
      answer: nlNum(answer),
      wrong: g.nums(answer, [
        base * p ~/ 100,
        base - base * p ~/ 100,
        answer + 10,
        base,
      ]),
      why: 'De groei is ${nlNum(base * p ~/ 100)} leerlingen; die komen erbij.',
    );
  }

  // --- Meten: omrekenen ------------------------------------------------------
  const lengtes = [
    ('km', 'm', 1000),
    ('m', 'cm', 100),
    ('cm', 'mm', 10),
    ('m', 'mm', 1000),
    ('km', 'cm', 100000),
    ('dm', 'cm', 10),
  ];
  for (var i = 0; i < 26; i++) {
    final u = g.oneOf(lengtes);
    final omhoog = g.rnd.nextBool();
    if (omhoog) {
      final v = g.between(15, 950) / 10;
      final answer = v * u.$3;
      g.add(
        topic: _meten,
        prompt: 'Hoeveel ${u.$2} is ${nlNum(v)} ${u.$1}?',
        answer: '${nlNum(answer)} ${u.$2}',
        wrong: [
          '${nlNum(answer * 10)} ${u.$2}',
          '${nlNum(answer / 10)} ${u.$2}',
          '${nlNum(v)} ${u.$2}',
          '${nlNum(answer / 100)} ${u.$2}',
        ],
        why: '1 ${u.$1} is ${nlNum(u.$3)} ${u.$2}.',
      );
    } else {
      final answer = g.between(15, 950) / 10;
      final v = answer * u.$3;
      g.add(
        topic: _meten,
        prompt: 'Hoeveel ${u.$1} is ${nlNum(v)} ${u.$2}?',
        answer: '${nlNum(answer)} ${u.$1}',
        wrong: [
          '${nlNum(answer * 10)} ${u.$1}',
          '${nlNum(answer / 10)} ${u.$1}',
          '${nlNum(v)} ${u.$1}',
          '${nlNum(answer * 100)} ${u.$1}',
        ],
        why: '${nlNum(u.$3)} ${u.$2} is 1 ${u.$1}.',
      );
    }
  }

  const gewichten = [
    ('kg', 'gram', 1000),
    ('ton', 'kg', 1000),
    ('gram', 'milligram', 1000),
  ];
  for (var i = 0; i < 22; i++) {
    final u = g.oneOf(gewichten);
    final v = g.between(12, 880) / 10;
    final answer = v * u.$3;
    g.add(
      topic: _meten,
      prompt: 'Hoeveel ${u.$2} is ${nlNum(v)} ${u.$1}?',
      answer: '${nlNum(answer)} ${u.$2}',
      wrong: [
        '${nlNum(answer * 10)} ${u.$2}',
        '${nlNum(answer / 10)} ${u.$2}',
        '${nlNum(answer / 100)} ${u.$2}',
        '${nlNum(v)} ${u.$2}',
      ],
      why: '1 ${u.$1} is ${nlNum(u.$3)} ${u.$2}.',
    );
  }

  const inhouden = [
    ('liter', 'ml', 1000),
    ('liter', 'dl', 10),
    ('liter', 'cl', 100),
    ('dl', 'ml', 100),
    ('cl', 'ml', 10),
  ];
  for (var i = 0; i < 22; i++) {
    final u = g.oneOf(inhouden);
    final v = g.between(12, 640) / 10;
    final answer = v * u.$3;
    g.add(
      topic: _meten,
      prompt: 'Hoeveel ${u.$2} is ${nlNum(v)} ${u.$1}?',
      answer: '${nlNum(answer)} ${u.$2}',
      wrong: [
        '${nlNum(answer * 10)} ${u.$2}',
        '${nlNum(answer / 10)} ${u.$2}',
        '${nlNum(v)} ${u.$2}',
        '${nlNum(answer + u.$3)} ${u.$2}',
      ],
      why: '1 ${u.$1} is ${nlNum(u.$3)} ${u.$2}.',
    );
  }

  // --- Meten: meetkunde ------------------------------------------------------
  for (var i = 0; i < 22; i++) {
    final l = g.between(4, 38);
    final b = g.between(3, 29);
    final omtrek = 2 * (l + b);
    g.add(
      topic: _meten,
      prompt: 'Een rechthoek is $l cm lang en $b cm breed. Wat is de omtrek?',
      answer: '$omtrek cm',
      wrong: [
        '${l * b} cm',
        '${l + b} cm',
        '${omtrek + 2} cm',
        '${2 * l + b} cm',
      ],
      why: 'Omtrek = 2 × ($l + $b) = $omtrek cm.',
    );
  }

  for (var i = 0; i < 22; i++) {
    final l = g.between(4, 32);
    final b = g.between(3, 24);
    final opp = l * b;
    g.add(
      topic: _meten,
      prompt:
          'Een rechthoekige tuin is $l m lang en $b m breed. Wat is de oppervlakte?',
      answer: '$opp m²',
      wrong: [
        '${2 * (l + b)} m²',
        '${l + b} m²',
        '${opp + l} m²',
        '${opp * 2} m²',
      ],
      why: 'Oppervlakte = lengte × breedte = $l × $b = $opp m².',
    );
  }

  for (var i = 0; i < 16; i++) {
    final basis = g.between(3, 20) * 2;
    final hoogte = g.between(3, 18);
    final opp = basis * hoogte ~/ 2;
    g.add(
      topic: _meten,
      prompt:
          'Een driehoek heeft een basis van $basis cm en een hoogte van '
          '$hoogte cm. Wat is de oppervlakte?',
      answer: '$opp cm²',
      wrong: [
        '${basis * hoogte} cm²',
        '${basis + hoogte} cm²',
        '${opp + hoogte} cm²',
        '${opp * 2 + 2} cm²',
      ],
      why: 'Oppervlakte driehoek = basis × hoogte : 2.',
    );
  }

  for (var i = 0; i < 16; i++) {
    final l = g.between(3, 15);
    final b = g.between(2, 12);
    final h = g.between(2, 10);
    final inhoud = l * b * h;
    g.add(
      topic: _meten,
      prompt:
          'Een doos is $l cm lang, $b cm breed en $h cm hoog. '
          'Wat is de inhoud?',
      answer: '$inhoud cm³',
      wrong: [
        '${l + b + h} cm³',
        '${l * b} cm³',
        '${inhoud + l} cm³',
        '${2 * (l * b + b * h + l * h)} cm³',
      ],
      why: 'Inhoud = lengte × breedte × hoogte.',
    );
  }

  for (var i = 0; i < 16; i++) {
    final a = g.between(25, 80);
    final b = g.between(25, 80);
    if (a + b >= 170) continue;
    final c = 180 - a - b;
    g.add(
      topic: _meten,
      prompt:
          'Twee hoeken van een driehoek zijn $a° en $b°. '
          'De drie hoeken zijn samen 180°. Hoe groot is de derde hoek?',
      answer: '$c°',
      wrong: ['${c + 10}°', '${180 - a}°', '${a + b}°', '${c - 5}°'],
      why: 'De hoeken van een driehoek zijn samen 180°.',
    );
  }

  // --- Meten: tijd -----------------------------------------------------------
  for (var i = 0; i < 24; i++) {
    final start = g.between(7, 20) * 60 + g.between(0, 11) * 5;
    final duur = g.between(5, 26) * 5;
    final eind = start + duur;
    g.add(
      topic: _meten,
      prompt:
          'Een film begint om ${_hhmm(start)} en duurt $duur minuten. '
          'Hoe laat is de film afgelopen?',
      answer: _hhmm(eind),
      wrong: [
        _hhmm(eind + 10),
        _hhmm(eind - 15),
        _hhmm(start + duur ~/ 2),
        _hhmm(eind + 60),
      ],
      why: '$duur minuten is ${duur ~/ 60} uur en ${duur % 60} minuten.',
    );
  }

  for (var i = 0; i < 20; i++) {
    final start = g.between(6, 14) * 60 + g.between(0, 11) * 5;
    final eind = start + g.between(9, 40) * 5;
    final duur = eind - start;
    g.add(
      topic: _meten,
      prompt:
          'Een treinreis duurt van ${_hhmm(start)} tot ${_hhmm(eind)}. '
          'Hoe lang duurt de reis?',
      answer: duur >= 60
          ? '${duur ~/ 60} uur en ${duur % 60} minuten'
          : '$duur minuten',
      wrong: [
        duur >= 60
            ? '${duur ~/ 60} uur en ${(duur % 60) + 10} minuten'
            : '${duur + 10} minuten',
        '${duur + 60} minuten',
        duur >= 60 ? '${duur ~/ 60 + 1} uur' : '${duur - 5} minuten',
        '$duur uur',
      ],
      why: 'Van ${_hhmm(start)} naar ${_hhmm(eind)} is $duur minuten.',
    );
  }

  // --- Verbanden: gemiddelde -------------------------------------------------
  for (var i = 0; i < 26; i++) {
    final aantal = g.oneOf([4, 5, 6]);
    final gem = g.between(4, 9);
    final waarden = <int>[];
    var rest = gem * aantal;
    for (var k = 0; k < aantal - 1; k++) {
      final v = g.between(2, 10);
      waarden.add(v);
      rest -= v;
    }
    if (rest < 1 || rest > 10) continue;
    waarden.add(rest);
    waarden.shuffle(g.rnd);
    final naam = g.oneOf(_namen);
    g.add(
      topic: _verbanden,
      prompt:
          '$naam haalde deze cijfers: ${waarden.join(', ')}. '
          'Wat is het gemiddelde?',
      answer: nlNum(gem),
      wrong: g.nums(gem, [
        gem + 1,
        gem - 1,
        waarden.reduce((a, b) => a + b),
        gem + 2,
      ]),
      why: 'Tel op (${waarden.reduce((a, b) => a + b)}) en deel door $aantal.',
    );
  }

  // --- Verbanden: snelheid ---------------------------------------------------
  for (var i = 0; i < 24; i++) {
    final snelheid = g.oneOf([5, 12, 15, 20, 40, 60, 80, 90, 100, 120]);
    final uren = g.oneOf([2, 3, 4, 5]);
    final afstand = snelheid * uren;
    final vraagAfstand = g.rnd.nextBool();
    if (vraagAfstand) {
      g.add(
        topic: _verbanden,
        prompt:
            'Een auto rijdt $snelheid km per uur. Hoeveel kilometer legt '
            'de auto af in $uren uur?',
        answer: '${nlNum(afstand)} km',
        wrong: [
          '${nlNum(afstand + snelheid)} km',
          '${nlNum(snelheid)} km',
          '${nlNum(afstand ~/ 2)} km',
          '${nlNum(afstand + 100)} km',
        ],
        why: 'Afstand = snelheid × tijd = $snelheid × $uren.',
      );
    } else {
      g.add(
        topic: _verbanden,
        prompt:
            'Een voertuig legt ${nlNum(afstand)} km af in $uren uur. '
            'Wat is de gemiddelde snelheid?',
        answer: '$snelheid km per uur',
        wrong: [
          '${snelheid + 5} km per uur',
          '$afstand km per uur',
          '${snelheid ~/ 2} km per uur',
          '${snelheid + 10} km per uur',
        ],
        why: 'Snelheid = afstand : tijd = ${nlNum(afstand)} : $uren.',
      );
    }
  }

  // --- Verbanden: tabellen ---------------------------------------------------
  const dagen = ['maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag'];
  for (var i = 0; i < 24; i++) {
    final waarden = [for (final _ in dagen) g.between(12, 96)];
    final tabel = [
      for (var k = 0; k < dagen.length; k++)
        '${dagen[k].padRight(11)} ${waarden[k]}',
    ].join('\n');
    final ding = g.oneOf(['bekers thee', 'broodjes', 'kaartjes', 'boeken']);
    final soort = g.between(0, 2);
    if (soort == 0) {
      final totaal = waarden.reduce((a, b) => a + b);
      g.add(
        topic: _verbanden,
        passage: 'Verkochte $ding deze week:\n$tabel',
        prompt: 'Hoeveel $ding zijn er deze week in totaal verkocht?',
        answer: nlNum(totaal),
        wrong: g.nums(totaal, [
          totaal + 10,
          totaal - 10,
          totaal ~/ 5,
          totaal + 1,
        ]),
        why: 'Tel de vijf getallen bij elkaar op.',
      );
    } else if (soort == 1) {
      final maxIndex = waarden.indexOf(waarden.reduce((a, b) => a > b ? a : b));
      if (waarden.where((v) => v == waarden[maxIndex]).length != 1) continue;
      g.add(
        topic: _verbanden,
        passage: 'Verkochte $ding deze week:\n$tabel',
        prompt: 'Op welke dag zijn er de meeste $ding verkocht?',
        answer: dagen[maxIndex],
        wrong: g.others(dagen, dagen[maxIndex]),
        why: 'Op ${dagen[maxIndex]} waren het er ${waarden[maxIndex]}.',
      );
    } else {
      final hoog = waarden.reduce((a, b) => a > b ? a : b);
      final laag = waarden.reduce((a, b) => a < b ? a : b);
      g.add(
        topic: _verbanden,
        passage: 'Verkochte $ding deze week:\n$tabel',
        prompt: 'Wat is het verschil tussen de drukste en de rustigste dag?',
        answer: nlNum(hoog - laag),
        wrong: g.nums(hoog - laag, [hoog + laag, hoog, laag, hoog - laag + 5]),
        why: '$hoog - $laag = ${hoog - laag}.',
      );
    }
  }

  // --- Verbanden: patronen ---------------------------------------------------
  for (var i = 0; i < 24; i++) {
    final start = g.between(3, 40);
    final stap = g.between(3, 14);
    final rij = [for (var k = 0; k < 5; k++) start + k * stap];
    final volgende = start + 5 * stap;
    g.add(
      topic: _verbanden,
      prompt: 'Welk getal komt hierna: ${rij.join(', ')}, …?',
      answer: nlNum(volgende),
      wrong: g.nums(volgende, [
        volgende + stap,
        volgende - 1,
        volgende + 1,
        rij.last * 2,
      ]),
      why: 'Er komt elke keer $stap bij.',
    );
  }

  for (var i = 0; i < 12; i++) {
    final start = g.between(2, 6);
    final rij = [for (var k = 0; k < 4; k++) start * (1 << k)];
    final volgende = start * 16;
    g.add(
      topic: _verbanden,
      prompt: 'Welk getal komt hierna: ${rij.join(', ')}, …?',
      answer: nlNum(volgende),
      wrong: g.nums(volgende, [
        volgende + start,
        rij.last + start,
        volgende * 2,
        rij.last + rij[2],
      ]),
      why: 'Elk getal is het dubbele van het vorige.',
    );
  }

  // --- Verbanden: formules ---------------------------------------------------
  for (var i = 0; i < 24; i++) {
    final startCent = g.between(2, 9) * 50;
    final perCent = g.between(2, 9) * 25;
    final aantal = g.between(3, 15);
    final totaal = (startCent + perCent * aantal) / 100;
    final soort = g.oneOf([
      ('taxi', 'kilometer', 'km'),
      ('sportclub', 'les', 'lessen'),
      ('verhuur', 'uur', 'uur'),
    ]);
    g.add(
      topic: _verbanden,
      prompt:
          'Een ${soort.$1} rekent ${nlEuro(startCent / 100)} vast plus '
          '${nlEuro(perCent / 100)} per ${soort.$2}. Wat betaal je bij '
          '$aantal ${soort.$3}?',
      answer: nlEuro(totaal),
      wrong: g.euros(totaal, [
        perCent * aantal / 100,
        totaal + startCent / 100,
        (startCent + perCent * (aantal + 1)) / 100,
        totaal - 1,
      ]),
      why:
          '${nlEuro(startCent / 100)} + $aantal × ${nlEuro(perCent / 100)} = '
          '${nlEuro(totaal)}.',
    );
  }

  for (var i = 0; i < 20; i++) {
    final perDag = g.between(3, 25);
    final dagenAantal = g.between(4, 30);
    final totaal = perDag * dagenAantal;
    final naam = g.oneOf(_namen);
    g.add(
      topic: _verbanden,
      prompt:
          '$naam spaart elke dag $perDag stickers. Hoeveel stickers heeft '
          '$naam na $dagenAantal dagen?',
      answer: nlNum(totaal),
      wrong: g.nums(totaal, [
        totaal + perDag,
        perDag + dagenAantal,
        totaal - perDag,
        totaal * 2,
      ]),
      why: '$perDag × $dagenAantal = ${nlNum(totaal)}.',
    );
  }

  return g.questions;
}
