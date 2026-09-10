import 'dart:math';

import '../quiz_bank.dart';
import 'gen.dart';

/// Independently authored practice. Every variation uses the same checked
/// calculation and plausible, numerically distinct distractors.
List<QuizQuestion> buildIepRekenen() {
  final out = <QuizQuestion>[];
  final random = Random(8102026);
  void add(
    String family,
    int n,
    String topic,
    String prompt,
    num answer,
    String why, {
    String? unit,
    List<num>? wrong,
    QuizTable? table,
    QuizBars? bars,
  }) {
    final choices = wrong == null
        ? <String>[]
        : <String>{nlNum(answer), ...wrong.map(nlNum)}.toList();
    if (wrong != null && choices.length != wrong.length + 1) {
      throw StateError('Duplicate numeric alternatives: $family-$n');
    }
    choices.shuffle(random);
    out.add(
      QuizQuestion(
        id: 'iep-r-$family-$n',
        topic: topic,
        prompt: prompt,
        input: wrong == null ? QuizInput.number : QuizInput.choice,
        expected: wrong == null ? nlNum(answer) : null,
        unit: unit,
        options: choices,
        answerIndex: wrong == null ? 0 : choices.indexOf(nlNum(answer)),
        explanation: why,
        table: table,
        bars: bars,
      ),
    );
  }

  const getallen = 'Getallen en bewerkingen';
  const verhoudingen = 'Verhoudingen';
  const meten = 'Meten en meetkunde';
  const verbanden = 'Verbanden';
  for (var n = 1; n <= 12; n++) {
    final packs = 24 + n * 3;
    add(
      'pakken',
      n,
      getallen,
      'De school koopt $packs dozen potloden. In elke doos zitten 12 potloden.\nHoeveel potloden zijn dat in totaal?',
      packs * 12,
      '$packs × 12 = ${packs * 12}.',
      unit: 'potloden',
    );
    final total = (34 + n) * 8;
    add(
      'delen',
      n,
      getallen,
      '$total : 8 =',
      total ~/ 8,
      'Controleer door te vermenigvuldigen: ${total ~/ 8} × 8 = $total.',
    );
    final priceCents = 125 + n * 5;
    final change = (1000 - 3 * priceCents) / 100;
    add(
      'wisselgeld',
      n,
      getallen,
      'Amir koopt 3 broodjes van ${nlEuro(priceCents / 100)} per stuk. Hij betaalt met 10 euro.\nHoeveel euro krijgt hij terug?',
      change,
      'De broodjes kosten ${nlEuro(3 * priceCents / 100)}. Trek dat af van 10 euro.',
      unit: 'euro',
    );
    final number = 20000 + n * 1000 + 748;
    add(
      'afronden',
      n,
      getallen,
      'Rond ${nlNum(number)} af op honderdtallen.',
      number - 48,
      'Het tiental is 4. Het honderdtal blijft daarom gelijk.',
      wrong: [number + 52, number - 748, number + 2],
    );
    final digit = n % 7 + 2;
    add(
      'plaatswaarde',
      n,
      getallen,
      'Welk cijfer geeft de honderdsten aan in het getal 46,${digit}1?',
      1,
      'De honderdsten staan op de tweede plaats achter de komma.',
      wrong: [4, 6, digit == 4 || digit == 6 ? 0 : digit],
    );
    final numerator = n + 7;
    final marbles = (n + 3) * 8;
    add(
      'breukdeel',
      n,
      verhoudingen,
      'In een zak zitten $marbles knikkers. Drie achtste deel van de knikkers is blauw.\nHoeveel blauwe knikkers zitten in de zak?',
      marbles * 3 ~/ 8,
      'Deel $marbles door 8 en vermenigvuldig de uitkomst met 3.',
      unit: 'knikkers',
    );
    final denominator = n + 3;
    add(
      'breuksom',
      n,
      getallen,
      '1/$denominator + 2/$denominator = …/$denominator\nWelk getal moet op de puntjes staan?',
      3,
      'De noemers zijn gelijk. Tel de tellers op: 1 + 2 = 3. De noemer blijft $denominator.',
      wrong: [2, denominator, 2 * denominator],
    );
    add(
      'delenrest',
      n,
      getallen,
      'Er gaan ${n * 8 + 3} kinderen mee op excursie. In elk busje passen 8 kinderen.\nHoeveel busjes zijn er minstens nodig?',
      n + 1,
      '$n volle busjes bieden plaats aan ${n * 8} kinderen. Voor de overige 3 kinderen is nog een busje nodig.',
      unit: 'busjes',
    );
    add(
      'kommagetal',
      n,
      getallen,
      '${nlNum(numerator / 10)} + 2,65 =',
      numerator / 10 + 2.65,
      'Zet de kommas onder elkaar en tel de tienden en honderdsten bij elkaar op.',
    );

    final price = 40 + n * 20;
    add(
      'korting',
      n,
      verhoudingen,
      'Een jas kost ${nlEuro(price)}. Er gaat 15% van de prijs af.\nHoeveel euro kost de jas nu?',
      price * .85,
      '10% is ${nlEuro(price * .1)} en 5% is ${nlEuro(price * .05)}. Trek samen 15% van de prijs af.',
      unit: 'euro',
    );
    final children = (n + 4) * 8;
    add(
      'percentage',
      n,
      verhoudingen,
      'Van $children leerlingen komen er ${children * 3 ~/ 8} met de fiets.\nHoeveel procent van de leerlingen is dat?',
      37.5,
      '${children * 3 ~/ 8} van $children is 3 van 8. Dat is 37,5%.',
      unit: '%',
      wrong: [25, 30, 62.5],
    );
    final people = n + 4;
    add(
      'recept',
      n,
      verhoudingen,
      'Voor 4 personen heb je 300 gram rijst nodig. Je maakt hetzelfde gerecht voor $people personen.\nHoeveel gram rijst heb je nodig?',
      people * 75,
      'Per persoon is 300 : 4 = 75 gram nodig. Vermenigvuldig dat met $people.',
      unit: 'gram',
    );
    final distance = n + 2;
    add(
      'schaal',
      n,
      verhoudingen,
      'Een kaart heeft schaal 1 : 25.000. Een wandelroute is op de kaart $distance cm lang.\nHoeveel kilometer is de route in werkelijkheid?',
      distance / 4,
      '$distance × 25.000 = ${nlNum(distance * 25000)} cm. Dat is ${nlNum(distance / 4)} km.',
      unit: 'km',
      wrong: [distance * 2.5, distance * 25, distance / 40],
    );
    final amount = (n + 2) * 200;
    add(
      'mengen',
      n,
      verhoudingen,
      'Je mengt 1 deel siroop met 4 delen water. Je maakt $amount ml drinken.\nHoeveel milliliter siroop gebruik je?',
      amount ~/ 5,
      'Het drinken bestaat uit 5 delen. Eén deel is $amount : 5 = ${amount ~/ 5} ml.',
      unit: 'ml',
    );
    final euros = 12 + n * 4;
    add(
      'terugrekenen',
      n,
      verhoudingen,
      'Een boek kost in de uitverkoop ${nlEuro(euros)}. Dat is 80% van de oude prijs.\nHoeveel euro was de oude prijs?',
      euros * 1.25,
      'Deel de nieuwe prijs door 8 voor 10% en vermenigvuldig met 10 voor 100%.',
      unit: 'euro',
      wrong: [euros * .8, euros * 1.2, euros * .2],
    );

    final length = 8 + n;
    final width = 3 + n;
    add(
      'omtrek',
      n,
      meten,
      'Een rechthoekig speelveld is $length meter lang en $width meter breed.\nHoeveel meter is de omtrek?',
      2 * (length + width),
      'Tel alle zijden op: $length + $width + $length + $width.',
      unit: 'm',
    );
    add(
      'oppervlakte',
      n,
      meten,
      'Een rechthoekige vloer is $length meter lang en $width meter breed.\nHoeveel vierkante meter is de vloer?',
      length * width,
      '$length × $width = ${length * width} m².',
      unit: 'm²',
      wrong: [length + width, length * width + length, length * width * 2],
    );
    final litres = (n + 8) / 10;
    add(
      'inhoud',
      n,
      meten,
      '${nlNum(litres)} liter = … milliliter',
      (n + 8) * 100,
      '1 liter is 1000 milliliter. Vermenigvuldig met 1000.',
      unit: 'ml',
    );
    final start = 9 * 60 + n * 5;
    final duration = 75 + n * 5;
    String time(int minutes) =>
        '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';
    add(
      'reistijd',
      n,
      meten,
      'Een bus vertrekt om ${time(start)} en komt om ${time(start + duration)} aan.\nHoeveel minuten duurt de rit?',
      duration,
      'Reken van ${time(start)} naar ${time(start + duration)}. Dat is $duration minuten.',
      unit: 'minuten',
      wrong: [duration - 30, duration + 30, duration + 60],
    );
    final cm = n + 4;
    add(
      'doos',
      n,
      meten,
      'Een rechthoekige doos is $cm cm lang, 5 cm breed en 4 cm hoog.\nWat is de inhoud van de doos in kubieke centimeters?',
      cm * 20,
      'Vermenigvuldig lengte, breedte en hoogte: $cm × 5 × 4.',
      unit: 'cm³',
    );
    final kg = 2 + n / 10;
    add(
      'gewicht',
      n,
      meten,
      'Een lege krat weegt 500 gram. De appels in de krat wegen ${nlNum(kg)} kilogram.\nHoeveel gram wegen de krat en de appels samen?',
      2500 + n * 100,
      'De appels wegen ${2000 + n * 100} gram. Tel er 500 gram bij op.',
      unit: 'gram',
      wrong: [2000 + n * 100, 1500 + n * 100, 250 + n * 10],
    );

    final base = 10 + n;
    add(
      'tabel',
      n,
      verbanden,
      'De tabel laat zien hoeveel boeken op vier dagen zijn uitgeleend.\nHoeveel boeken zijn op deze dagen samen uitgeleend?',
      base * 8,
      'Tel de aantallen op: $base + ${base * 2} + ${base * 3} + ${base * 2}.',
      unit: 'boeken',
      table: QuizTable(
        headers: const ['Dag', 'Boeken'],
        rows: [
          ['maandag', '$base'],
          ['dinsdag', '${base * 2}'],
          ['woensdag', '${base * 3}'],
          ['donderdag', '${base * 2}'],
        ],
      ),
    );
    add(
      'grafiek',
      n,
      verbanden,
      'Bekijk het staafdiagram.\nHoeveel bezoekers kwamen op woensdag meer dan op maandag?',
      base * 2,
      '${base * 3} − $base = ${base * 2}.',
      unit: 'bezoekers',
      wrong: [base, base * 3, base * 4],
      bars: QuizBars(
        title: 'Bezoekers van het zwembad',
        labels: const ['maandag', 'dinsdag', 'woensdag', 'donderdag'],
        values: [base, base * 2, base * 3, base * 2],
        unit: 'bezoekers',
      ),
    );
    add(
      'gemiddelde',
      n,
      verbanden,
      'Lina leest op maandag ${base - 4} bladzijden, op dinsdag $base en op woensdag ${base + 4}.\nHoeveel bladzijden leest zij gemiddeld per dag?',
      base,
      'De drie aantallen zijn samen ${base * 3}. Deel dit door 3.',
      unit: 'bladzijden',
    );
    final hours = n + 1;
    add(
      'huur',
      n,
      verbanden,
      'Je huurt een bakfiets. Je betaalt 6 euro bij het ophalen en 3 euro voor elk uur.\nHoeveel euro betaal je als je de fiets $hours uur huurt?',
      6 + 3 * hours,
      'Tel het vaste bedrag op bij de uurkosten: 6 + $hours × 3.',
      unit: 'euro',
      wrong: [3 * hours, 9 + 3 * hours, 9 * hours],
    );
    final target = 18 + n * 2;
    add(
      'ontbrekend',
      n,
      verbanden,
      'De tabel laat de opbrengst van drie dagen zien. De totale opbrengst is ${target * 4} euro.\nHoeveel euro is op woensdag opgehaald?',
      target * 2,
      'Trek de bekende opbrengsten af: ${target * 4} − $target − $target.',
      unit: 'euro',
      table: QuizTable(
        headers: const ['Dag', 'Opbrengst in euro'],
        rows: [
          ['maandag', '$target'],
          ['dinsdag', '$target'],
          ['woensdag', '?'],
        ],
      ),
    );
    final weeks = n + 2;
    add(
      'spaartabel',
      n,
      verbanden,
      'In de tabel staat hoeveel geld Sem na elke week heeft. Hij spaart elke week hetzelfde bedrag.\nHoeveel euro heeft hij na $weeks weken?',
      10 + weeks * 4,
      'Sem begint met 10 euro. Elke week komt er 4 euro bij.',
      unit: 'euro',
      wrong: [weeks * 4, 10 + weeks, 14 * weeks],
      table: const QuizTable(
        headers: ['Aantal weken', 'Bedrag in euro'],
        rows: [
          ['0', '10'],
          ['1', '14'],
          ['2', '18'],
        ],
      ),
    );
  }
  return out;
}
