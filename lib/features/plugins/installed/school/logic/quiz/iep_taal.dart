import 'dart:math';

import '../quiz_bank.dart';

List<QuizQuestion> buildIepTaal() {
  final out = <QuizQuestion>[];
  final random = Random(8112026);
  void word(
    String id,
    String topic,
    String instruction,
    String sentence,
    String answer,
    String explanation,
  ) {
    out.add(
      QuizQuestion(
        id: 'iep-t-$id',
        topic: topic,
        prompt: '$instruction\n\n$sentence',
        input: QuizInput.word,
        expected: answer,
        options: const [],
        answerIndex: 0,
        explanation: explanation,
      ),
    );
  }

  void choice(
    String id,
    String topic,
    String prompt,
    String answer,
    List<String> wrong,
    String why,
  ) {
    final options = [answer, ...wrong]..shuffle(random);
    out.add(
      QuizQuestion(
        id: 'iep-t-$id',
        topic: topic,
        prompt: prompt,
        options: options,
        answerIndex: options.indexOf(answer),
        explanation: why,
      ),
    );
  }

  const spelling = 'Spelling niet-werkwoorden';
  const verbs = 'Werkwoordspelling';
  const punctuation = 'Leestekens';
  const verbRows = [
    (
      'worden',
      'Mijn zus … volgende week elf jaar.',
      'wordt',
      'tegenwoordige tijd',
      'Mijn zus is het onderwerp: zij wordt. Je schrijft stam + t.',
    ),
    (
      'vinden',
      '… jij deze jas mooi?',
      'Vind',
      'tegenwoordige tijd',
      'Jij is het onderwerp en staat achter de persoonsvorm: vind jij.',
    ),
    (
      'vinden',
      '… je vader deze jas mooi?',
      'Vindt',
      'tegenwoordige tijd',
      'Het onderwerp is je vader. Dat kun je vervangen door hij: hij vindt.',
    ),
    (
      'antwoorden',
      'De leerling … op de vraag.',
      'antwoordt',
      'tegenwoordige tijd',
      'De leerling is enkelvoud: antwoord + t = antwoordt.',
    ),
    (
      'houden',
      'Mijn buurman … van tuinieren.',
      'houdt',
      'tegenwoordige tijd',
      'Bij hij schrijf je de stam houd met een t erachter.',
    ),
    (
      'redden',
      'De zwemmer … het kind uit het water.',
      'redt',
      'tegenwoordige tijd',
      'De stam is red. Bij de zwemmer komt er een t bij.',
    ),
    (
      'werken',
      'De vrijwilligers … gisteren in de tuin.',
      'werkten',
      'verleden tijd',
      'Het onderwerp is meervoud. Na de k krijgt werken de uitgang -ten.',
    ),
    (
      'verhuizen',
      'Vorig jaar … onze buren naar Assen.',
      'verhuisden',
      'verleden tijd',
      'Het onderwerp is meervoud. De z van verhuizen geeft de uitgang -den.',
    ),
    (
      'praten',
      'Tijdens de pauze … wij over het schoolreisje.',
      'praatten',
      'verleden tijd',
      'De stam is praat. In het meervoud van de verleden tijd komt er -ten bij.',
    ),
    (
      'melden',
      'Wij … ons gisteren bij de balie.',
      'meldden',
      'verleden tijd',
      'De stam meld krijgt in de verleden tijd meervoud -den: meldden.',
    ),
    (
      'fietsen',
      'De kinderen … gisteren naar het strand.',
      'fietsten',
      'verleden tijd',
      'De stam fiets krijgt in de verleden tijd meervoud -ten.',
    ),
    (
      'wachten',
      'Ik … gisteren bij de bushalte.',
      'wachtte',
      'verleden tijd',
      'De stam wacht krijgt -te: wachtte.',
    ),
    (
      'lopen',
      'Gisteren … de spelers naar de kleedkamer.',
      'liepen',
      'verleden tijd',
      'Lopen is onregelmatig. Bij de spelers hoort liepen.',
    ),
    (
      'kopen',
      'Mijn vader … gisteren een nieuwe fietslamp.',
      'kocht',
      'verleden tijd',
      'De verleden tijd van kopen is kocht bij één persoon.',
    ),
    (
      'brengen',
      'Wij … gisteren onze boeken terug.',
      'brachten',
      'verleden tijd',
      'Bij wij is de verleden tijd van brengen: brachten.',
    ),
    (
      'schrijven',
      'Noor heeft een brief … .',
      'geschreven',
      '',
      'Na heeft staat hier het voltooid deelwoord geschreven.',
    ),
    (
      'beloven',
      'De juf heeft een uitstapje … .',
      'beloofd',
      '',
      'Het voltooid deelwoord van beloven eindigt op d: beloofd.',
    ),
    (
      'gebeuren',
      'Wat is er op het plein … ?',
      'gebeurd',
      '',
      'Het voltooid deelwoord is gebeurd. Gebeurt is de persoonsvorm in de tegenwoordige tijd.',
    ),
    (
      'maken',
      'De kunstenaar heeft een beeld … .',
      'gemaakt',
      '',
      'Het voltooid deelwoord van maken is gemaakt.',
    ),
    (
      'beantwoorden',
      'De klas heeft alle vragen … .',
      'beantwoord',
      '',
      'Beantwoord is het voltooid deelwoord; er komt geen extra t achter.',
    ),
    (
      'reizen',
      'We zijn met de trein naar Brussel … .',
      'gereisd',
      '',
      'De z van reizen geeft een d in het voltooid deelwoord: gereisd.',
    ),
    (
      'verliezen',
      'Mijn broer is zijn sleutels … .',
      'verloren',
      '',
      'Het voltooid deelwoord van verliezen is verloren.',
    ),
    (
      'bouwen',
      'De timmerman heeft een kast … .',
      'gebouwd',
      '',
      'Bouwen heeft het voltooid deelwoord gebouwd.',
    ),
    (
      'tekenen',
      'Jullie hebben een plattegrond … .',
      'getekend',
      '',
      'Het voltooid deelwoord is getekend, met een d.',
    ),
  ];
  for (var i = 0; i < verbRows.length; i++) {
    final q = verbRows[i];
    word(
      'werkwoord-$i',
      verbs,
      'Vul de juiste werkwoordsvorm in.${q.$4.isEmpty ? '' : ' Gebruik de ${q.$4}.'}',
      '${q.$2} (${q.$1})',
      q.$3,
      q.$5,
    );
  }
  const plurals = [
    (
      'foto',
      'In dit album zitten oude … .',
      "foto's",
      'Na de lange o gebruik je een apostrof voor de s.',
    ),
    (
      'baby',
      'In het park liggen twee … in een kinderwagen.',
      "baby's",
      'Na een y met een medeklinker ervoor komt apostrof + s.',
    ),
    (
      'idee',
      'De leerlingen hebben goede … voor het feest.',
      'ideeën',
      'Het trema geeft het begin van een nieuwe lettergreep aan.',
    ),
    (
      'zee',
      'Op de kaart staan verschillende … .',
      'zeeën',
      'Zeeën krijgt een trema op de eerste e van de nieuwe lettergreep.',
    ),
    (
      'knie',
      'Na de val deden mijn … pijn.',
      'knieën',
      'Knieën krijgt -ën, met een trema.',
    ),
    (
      'bacterie',
      'Onder de microscoop zie je … .',
      'bacteriën',
      'Bacteriën krijgt een trema op de e.',
    ),
    (
      'museum',
      'Tijdens de vakantie bezoeken we drie … .',
      'musea',
      'Musea is hier de gevraagde meervoudsvorm.',
    ),
    (
      'kind',
      'De … spelen op het plein.',
      'kinderen',
      'Het meervoud van kind is kinderen.',
    ),
    (
      'stad',
      'De trein stopt in verschillende … .',
      'steden',
      'Het meervoud van stad is steden.',
    ),
    (
      'schip',
      'In de haven liggen grote … .',
      'schepen',
      'Het meervoud van schip is schepen.',
    ),
    (
      'brief',
      'De postbode bezorgt de … .',
      'brieven',
      'In het meervoud verandert de f in een v.',
    ),
    (
      'raam',
      'De glazenwasser maakt de … schoon.',
      'ramen',
      'In een open lettergreep schrijf je de lange a met één letter.',
    ),
  ];
  for (var i = 0; i < plurals.length; i++) {
    final q = plurals[i];
    if (q.$1 == 'museum') continue;
    word(
      'meervoud-$i',
      spelling,
      'Schrijf het meervoud van het woord tussen haakjes.',
      '${q.$2} (${q.$1})',
      q.$3,
      q.$4,
    );
  }
  const gaps = [
    (
      'Mijn oma neemt haar para…lu mee omdat het regent.',
      'p',
      'Je schrijft paraplu.',
    ),
    (
      'We lenen boeken in de biblio…eek.',
      'th',
      'Bibliotheek schrijf je met th.',
    ),
    (
      'De kinderen krijgen gymnas…iek in de sportzaal.',
      't',
      'Je schrijft gymnastiek.',
    ),
    ('De trein vertrekt over een kwar…ier.', 't', 'Je schrijft kwartier.'),
    (
      'In febru…ri zijn er minder dagen dan in januari.',
      'a',
      'Je schrijft februari.',
    ),
    ('De kok zet de maaltijd in de magne…ron.', 't', 'Je schrijft magnetron.'),
    ('De agent werkt bij de poli…ie.', 't', 'Je schrijft politie.'),
    ('Op het enve…opje staat mijn naam.', 'l', 'Je schrijft envelopje.'),
    ('We eten vanavond panne…koeken.', 'n', 'Pannenkoeken heeft een tussen-n.'),
    (
      'Ik luister naar een inte…essant verhaal.',
      'r',
      'Interessant schrijf je met één r en twee s-en.',
    ),
    (
      'Na de wandeling hebben we behoe…te aan rust.',
      'f',
      'Je schrijft behoefte.',
    ),
    (
      'De kinderen zijn erg enthousi…st over het plan.',
      'a',
      'Je schrijft enthousiast.',
    ),
  ];
  for (var i = 0; i < gaps.length; i++) {
    final q = gaps[i];
    word(
      'letters-$i',
      spelling,
      'Welke letter of letters ontbreken? Vul alleen het ontbrekende deel in.',
      q.$1,
      q.$2,
      q.$3,
    );
  }
  const spellingRows = [
    (
      'De … opent om negen uur.',
      'bibliotheek',
      ['bibiliotheek', 'biblioteek', 'biebliotheek'],
    ),
    ('Mijn vader maakt een … .', 'foto', ['footo', 'voto', 'fotoh']),
    (
      'In de tuin groeit een … .',
      'zonnebloem',
      ['zonnenbloem', 'zonebloem', 'zonnebloom'],
    ),
    (
      'Ik eet een … .',
      'sinaasappel',
      ['sinasappel', 'sinaasapel', 'sienaasappel'],
    ),
    (
      'We vieren morgen haar … .',
      'verjaardag',
      ['verjaardach', 'verjaardagg', 'verjardag'],
    ),
    (
      'Dit is een … opdracht.',
      'moeilijke',
      ['moelijke', 'moeilike', 'moeilijcke'],
    ),
    (
      'Na het alarm gingen we … naar buiten.',
      'onmiddellijk',
      ['onmiddelijk', 'onmidellijk', 'onmidelijk'],
    ),
    (
      'De … begint om acht uur.',
      'wedstrijd',
      ['wetstrijd', 'wedstreid', 'wedstrijt'],
    ),
    (
      'De voorstelling was een groot … .',
      'succes',
      ['sucses', 'successt', 'sukses'],
    ),
    (
      'De … van het lokaal is twintig graden.',
      'temperatuur',
      ['tempratuur', 'temperratuur', 'temperateur'],
    ),
    (
      'Zij tekent een … .',
      'plattegrond',
      ['platte grondt', 'plattegront', 'plategrond'],
    ),
    (
      'De tuin staat vol met … .',
      'paardenbloemen',
      ['paardebloemen', 'paardenbloemenn', 'paardebloemmen'],
    ),
  ];
  for (var i = 0; i < spellingRows.length; i++) {
    final q = spellingRows[i];
    choice(
      'spelling-$i',
      spelling,
      'In welke zin is het woord goed geschreven?',
      q.$1.replaceFirst('…', q.$2),
      [for (final w in q.$3) q.$1.replaceFirst('…', w)],
      'De juiste spelling is ${q.$2}.',
    );
  }
  const statements = [
    ('Noor', 'Ik neem mijn jas mee'),
    ('Sam', 'De trein komt eraan'),
    ('Mila', 'Ik ben mijn boek vergeten'),
    ('Amir', 'De wedstrijd begint'),
    ('Lotte', 'Ik wacht bij de ingang'),
    ('Bram', 'Morgen zijn we vrij'),
  ];
  for (var i = 0; i < statements.length; i++) {
    final q = statements[i];
    choice(
      'citaat-$i',
      punctuation,
      'In welke zin staan de aanhalingstekens goed?',
      '${q.$1} zegt: "${q.$2}."',
      [
        '"${q.$1} zegt: ${q.$2}."',
        '${q.$1} "zegt: ${q.$2}."',
        '${q.$1} zegt: ${q.$2}."',
      ],
      'Alleen de woorden die ${q.$1} uitspreekt, staan tussen aanhalingstekens.',
    );
  }
  const questions = [
    (
      'Wanneer begint de voorstelling',
      'De voorstelling begint om acht uur',
      'Ik vraag wanneer de voorstelling begint',
    ),
    (
      'Waar staat mijn fiets',
      'Mijn fiets staat bij de ingang',
      'Hij wil weten waar zijn fiets staat',
    ),
    (
      'Hoeveel kost een kaartje',
      'Een kaartje kost vijf euro',
      'Zij vraagt hoeveel een kaartje kost',
    ),
    (
      'Wie heeft mijn boek gezien',
      'Amir heeft mijn boek gezien',
      'Ik vroeg wie mijn boek had gezien',
    ),
    (
      'Gaan jullie morgen zwemmen',
      'Wij gaan morgen zwemmen',
      'Zij vroeg of wij morgen gaan zwemmen',
    ),
    (
      'Mag ik naast je zitten',
      'Je mag naast me zitten',
      'Hij vraagt of hij naast me mag zitten',
    ),
  ];
  for (var i = 0; i < questions.length; i++) {
    final q = questions[i];
    choice(
      'vraagteken-$i',
      punctuation,
      'Achter welke zin hoort een vraagteken?',
      q.$1,
      [q.$2, q.$3],
      'Dit is een directe vraag. De andere zinnen zijn mededelingen.',
    );
  }
  const names = ['Noor', 'Sam', 'Mila', 'Amir', 'Lotte', 'Bram'];
  const places = ['Utrecht', 'Leiden', 'Delft', 'Assen', 'Zwolle', 'Gouda'];
  for (var i = 0; i < names.length; i++) {
    final name = names[i];
    final place = places[i];
    choice(
      'hoofdletters-$i',
      punctuation,
      'In welke zin zijn de hoofdletters goed gebruikt?',
      'Op dinsdag gaat $name naar $place.',
      [
        'Op Dinsdag gaat $name naar $place.',
        'Op dinsdag gaat ${name.toLowerCase()} naar $place.',
        'Op dinsdag gaat $name naar ${place.toLowerCase()}.',
      ],
      'Een zin en eigennamen beginnen met een hoofdletter. Een dagnaam schrijf je klein.',
    );
  }
  const lists = [
    ('brood', 'kaas', 'melk'),
    ('papier', 'lijm', 'een schaar'),
    ('appels', 'peren', 'bananen'),
    ('pennen', 'schriften', 'gummen'),
    ('wortels', 'tomaten', 'paprika'),
    ('sokken', 'truien', 'broeken'),
  ];
  for (var i = 0; i < lists.length; i++) {
    final q = lists[i];
    choice(
      'komma-$i',
      punctuation,
      'In welke zin ontbreekt een komma?',
      'Ik koop ${q.$1} ${q.$2} en ${q.$3}.',
      [
        'Ik koop ${q.$1} en ${q.$2}.',
        'In de winkel zoek ik naar ${q.$1}.',
        'De winkel verkoopt ook ${q.$3}.',
      ],
      'Tussen ${q.$1} en ${q.$2} ontbreekt de komma van de opsomming.',
    );
  }
  return out;
}
