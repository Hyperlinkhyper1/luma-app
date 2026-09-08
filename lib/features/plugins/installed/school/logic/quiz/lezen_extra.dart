import '../quiz_bank.dart';
import 'gen.dart';

const _begrijpen = 'Begrijpen en interpreteren';
const _samenvatten = 'Samenvatten';
const _woordenschat = 'Woordenschat';
const _opzoeken = 'Opzoeken';

/// `woord|betekenis`
const _woorden = [
  'aarzelen|twijfelen voordat je iets doet',
  'abrupt|plotseling en onverwacht',
  'achterhalen|erachter komen hoe het zit',
  'afkeer|een sterke hekel aan iets',
  'alledaags|heel gewoon, van elke dag',
  'ambitieus|met grote plannen en veel wil',
  'anoniem|zonder dat je naam bekend is',
  'argument|een reden waarmee je iets uitlegt',
  'avontuurlijk|vol spanning en risico',
  'bedachtzaam|rustig en goed nadenkend',
  'beknopt|kort, zonder omhaal',
  'belemmeren|in de weg zitten',
  'benadrukken|er extra nadruk op leggen',
  'beoordelen|er een oordeel over geven',
  'berucht|bekend om iets slechts',
  'bescheiden|niet opschepperig',
  'betrouwbaar|je kunt erop rekenen',
  'bevestigen|zeggen dat iets klopt',
  'bijdehand|slim en gevat',
  'concreet|duidelijk en tastbaar',
  'consequentie|het gevolg van iets',
  'constateren|vaststellen dat iets zo is',
  'cruciaal|heel belangrijk voor de afloop',
  'dilemma|een moeilijke keuze tussen twee dingen',
  'discreet|zonder er ruchtbaarheid aan te geven',
  'doelgroep|de mensen voor wie iets bedoeld is',
  'doorslaggevend|beslissend voor de uitkomst',
  'dubieus|twijfelachtig',
  'efficient|zonder tijd of moeite te verspillen',
  'eigenzinnig|met een eigen willetje',
  'elementair|heel basaal en onmisbaar',
  'ergernis|iets waar je je aan stoort',
  'essentieel|onmisbaar',
  'evenement|een grote georganiseerde gebeurtenis',
  'expliciet|met zoveel woorden gezegd',
  'extreem|heel erg, tot het uiterste',
  'fabel|een verhaal met dieren en een les',
  'fanatiek|heel fel en toegewijd',
  'fascinerend|heel boeiend',
  'feilloos|zonder ook maar een fout',
  'formeel|volgens de officiele regels',
  'fragment|een stukje uit een groter geheel',
  'frustratie|het gevoel dat iets maar niet lukt',
  'functioneren|werken zoals het hoort',
  'geleidelijk|beetje bij beetje',
  'genereus|gul',
  'geraffineerd|slim en doordacht bedacht',
  'geruststellen|iemand rustig maken',
  'globaal|in grote lijnen',
  'grillig|onvoorspelbaar',
  'hachelijk|gevaarlijk',
  'handhaven|zorgen dat een regel wordt nageleefd',
  'hardnekkig|het gaat maar niet weg',
  'hedendaags|van deze tijd',
  'hilarisch|om te gieren van het lachen',
  'hypothese|een verwachting die je nog moet testen',
  'identiek|precies hetzelfde',
  'illustreren|met een voorbeeld duidelijk maken',
  'impuls|een plotselinge neiging',
  'incident|een los voorval',
  'indrukwekkend|zo dat het indruk maakt',
  'ingrijpend|met grote gevolgen',
  'initiatief|het eerste zetje geven',
  'innovatief|vernieuwend',
  'inspireren|iemand zin geven om iets te doen',
  'intens|heel sterk en diep',
  'intrigeren|nieuwsgierig maken',
  'irrelevant|het doet er niet toe',
  'kenmerk|iets waaraan je iets herkent',
  'kritisch|niet zomaar alles geloven',
  'kwetsbaar|makkelijk te beschadigen',
  'legendarisch|zo bijzonder dat het verhaal blijft',
  'loyaal|trouw',
  'markant|opvallend',
  'massaal|met heel veel tegelijk',
  'meedogenloos|zonder enig medelijden',
  'motief|de reden waarom iemand iets doet',
  'naief|te goed van vertrouwen',
  'nauwkeurig|heel precies',
  'neutraal|geen partij kiezend',
  'noodzakelijk|het moet echt',
  'obstakel|een hindernis',
  'omslachtig|met veel onnodige stappen',
  'onmisbaar|je kunt er niet zonder',
  'opmerkelijk|de moeite van het opmerken waard',
  'oppervlakkig|alleen aan de buitenkant, niet diep',
  'opzettelijk|met opzet',
  'overbodig|niet nodig',
  'overtuigen|iemand van je gelijk laten worden',
  'plausibel|het klinkt geloofwaardig',
  'prestige|aanzien bij anderen',
  'principe|een vaste regel waar je je aan houdt',
  'prioriteit|wat het eerst moet gebeuren',
  'provoceren|uitdagen tot een reactie',
  'razendsnel|extreem snel',
  'relevant|het doet ertoe',
  'resoluut|beslist en zonder aarzelen',
  'riskant|met kans op een slechte afloop',
  'routine|iets wat je al helemaal gewend bent',
  'schaars|er is er maar weinig van',
  'somber|donker en droevig',
  'spontaan|vanzelf, zonder plan vooraf',
  'stabiel|het blijft gelijk',
  'struikelblok|iets waarop een plan misgaat',
  'subtiel|met kleine, fijne verschillen',
  'symbool|iets dat voor iets anders staat',
  'tegenstrijdig|het spreekt elkaar tegen',
  'terughoudend|voorzichtig, niet meteen meedoend',
  'theorie|een verklaring die nog niet zeker is',
  'toevallig|zonder dat het gepland was',
  'traditie|een gewoonte die al heel lang bestaat',
  'transparant|open en doorzichtig',
  'tumult|luid rumoer en gedoe',
  'uitmuntend|heel erg goed',
  'uniek|er is er maar een van',
  'urgent|het heeft haast',
  'variatie|afwisseling',
  'vasthoudend|niet snel opgevend',
  'veelzeggend|het zegt meer dan je zou denken',
  'verbazingwekkend|het verbaast je zeer',
  'vermoeden|iets denken zonder het zeker te weten',
  'verrassend|anders dan je verwachtte',
  'vertrouwelijk|niet voor anderen bestemd',
  'verwarrend|het maakt je in de war',
  'vindingrijk|goed in oplossingen bedenken',
  'vluchtig|kort en oppervlakkig',
  'voldoende|genoeg',
  'vooroordeel|een mening zonder dat je het echt weet',
  'weloverwogen|na goed nadenken',
  'zeldzaam|het komt bijna niet voor',
  'zinvol|het heeft nut',
];

/// `uitdrukking|betekenis`
const _uitdrukkingen = [
  'de kat uit de boom kijken|eerst afwachten hoe het loopt',
  'het hoofd koel houden|rustig blijven als het spannend wordt',
  'de knoop doorhakken|eindelijk een besluit nemen',
  'met de deur in huis vallen|meteen ter zake komen',
  'de handdoek in de ring gooien|het opgeven',
  'een storm in een glas water|veel drukte om niets',
  'het roer omgooien|het helemaal anders gaan aanpakken',
  'door de mand vallen|betrapt worden op iets',
  'in het diepe springen|iets doen zonder enige ervaring',
  'de puntjes op de i zetten|het laatste beetje netjes afmaken',
  'een oogje in het zeil houden|een beetje opletten',
  'de draad weer oppakken|verdergaan waar je gebleven was',
  'iets uit je duim zuigen|iets verzinnen',
  'de spijker op de kop slaan|precies gelijk hebben',
  'met twee maten meten|niet iedereen gelijk behandelen',
  'water bij de wijn doen|iets toegeven om er samen uit te komen',
  'op eieren lopen|heel voorzichtig doen',
  'een fluitje van een cent|iets heel makkelijks',
  'zich in het zweet werken|heel hard werken',
  'de kop in het zand steken|het probleem niet onder ogen zien',
  'uit de lucht komen vallen|volkomen onverwacht komen',
  'er geen gras over laten groeien|er meteen mee aan de slag gaan',
  'de dans ontspringen|net aan iets vervelends ontkomen',
  'een blok aan het been|iets wat je steeds ophoudt',
  'het kind van de rekening zijn|degene zijn die de nadelen krijgt',
  'in de wolken zijn|heel erg blij zijn',
  'door het lint gaan|heel erg boos worden',
  'zijn draai vinden|zich ergens thuis gaan voelen',
  'de lat hoog leggen|veel van jezelf of anderen eisen',
  'een hart van goud hebben|heel lief en behulpzaam zijn',
  'een stok achter de deur|iets dat je dwingt om door te zetten',
  'de handen ineenslaan|gaan samenwerken',
  'een gat in de lucht springen|dolblij zijn',
  'tussen de regels door lezen|begrijpen wat er niet letterlijk staat',
  'zijn woord houden|doen wat je beloofd hebt',
  'de kar trekken|het meeste werk doen',
  'het hoofd bieden|standhouden tegen iets moeilijks',
  'niet over een nacht ijs gaan|iets goed voorbereiden',
  'iets op de lange baan schuiven|het steeds maar uitstellen',
  'iemand de oren van het hoofd vragen|heel veel vragen stellen',
  'boter bij de vis|meteen doen wat je moet doen',
  'de bal misslaan|het helemaal verkeerd inschatten',
  'ergens geen touw aan vast kunnen knopen|er niets van begrijpen',
  'de zaak op scherp zetten|de spanning bewust opvoeren',
  'als los zand aan elkaar hangen|geen samenhang hebben',
];

/// `signaalwoord|verband`
const _signaalwoorden = [
  'omdat|een oorzaak',
  'want|een reden',
  'daardoor|een gevolg',
  'daarom|een gevolg',
  'dus|een conclusie',
  'hoewel|een tegenstelling',
  'maar|een tegenstelling',
  'toch|een tegenstelling',
  'ondanks|een tegenstelling',
  'in tegenstelling tot|een tegenstelling',
  'bijvoorbeeld|een voorbeeld',
  'zoals|een voorbeeld',
  'ten eerste|een opsomming',
  'bovendien|een opsomming',
  'ook|een opsomming',
  'daarna|een volgorde in de tijd',
  'vervolgens|een volgorde in de tijd',
  'tenslotte|een afsluiting',
  'kortom|een samenvatting',
  'terwijl|iets dat tegelijk gebeurt',
  'zodat|een doel',
  'namelijk|een toelichting',
  'met andere woorden|dezelfde uitleg anders gezegd',
  'als|een voorwaarde',
];

/// Chapter titles for the generated tables of contents.
const _boeken = [
  'Het weer|Wolken en regen|Onweer|Wind en storm|Het klimaat|Weer voorspellen',
  'Insecten|Bijen en wespen|Mieren|Vlinders|Kevers|Insecten in de tuin',
  'De ruimte|De zon|De planeten|De maan|Sterren en sterrenbeelden|Raketten',
  'Het menselijk lichaam|Het skelet|De spieren|Het hart|De longen|De zintuigen',
  'Nederland|De provincies|Water en dijken|De steden|Het landschap|De natuur',
  'Voeding|Groente en fruit|Granen|Zuivel|Suiker en vet|Gezond eten',
  'Dieren in het bos|De vos|Het hert|De uil|De eekhoorn|Sporen zoeken',
  'Techniek|Bruggen bouwen|Elektriciteit|Machines|Robots|Duurzame energie',
];

const _haltes = [
  'Station',
  'Marktplein',
  'De Brink',
  'Sportpark',
  'Ziekenhuis',
];

String _hhmm(int minutes) {
  final m = minutes % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

const _tekstZwerfafval = '''
Elke maand ruimen de leerlingen van groep 8 zwerfafval op rond de school. Ze
trekken hesjes aan, krijgen een grijper en gaan in tweetallen op pad. Vorig jaar
haalden ze samen bijna driehonderd kilo afval op. Het meeste daarvan waren
blikjes en verpakkingen van snoep. Sinds de gemeente extra prullenbakken bij het
speelveld heeft geplaatst, vinden de leerlingen daar duidelijk minder rommel.
Toch blijft het aantal blikjes langs de doorgaande weg gelijk. De leerlingen
denken dat die vooral uit auto's worden gegooid.''';

const _tekstSlaapkamer = '''
Wie slecht slaapt, presteert de volgende dag minder goed op school. Dat komt
doordat je hersenen tijdens je slaap opruimen wat je overdag hebt geleerd.
Onderzoekers raden aan om een uur voor het slapen geen schermen meer te
gebruiken. Het blauwe licht van een telefoon zorgt er namelijk voor dat je
lichaam later begint met het aanmaken van het slaaphormoon. Een vaste
bedtijd helpt ook: je lichaam went aan het ritme en wordt vanzelf moe op
dezelfde tijd.''';

const _tekstMuseum = '''
Het museum in ons dorp bestaat honderd jaar. Om dat te vieren is de toegang de
hele maand mei gratis voor iedereen onder de achttien. In de grote zaal hangt
een tentoonstelling over het dorp in de oorlogsjaren, met foto's uit de
verzameling van oud-inwoners. Wie liever zelf iets doet, kan in het atelier een
ansichtkaart maken met een oude drukpers. Het museum is open van dinsdag tot en
met zondag, maar op maandag alleen voor scholen.''';

const _tekstBever = '''
De bever was in Nederland al bijna honderd jaar verdwenen toen er in 1988
opnieuw bevers werden uitgezet in de Biesbosch. Dat pakte goed uit: er leven er
nu weer duizenden. Bevers knagen bomen om en bouwen dammen, waardoor er
poelen ontstaan waar allerlei andere dieren van profiteren. Voor
waterschappen is dat niet altijd handig, want een dam in de verkeerde sloot kan
een weiland onder water zetten. Daarom worden sommige dammen weggehaald en
worden er elders juist stukken natuur voor de bever ingericht.''';

const _tekstSchoolplein = '''
Onze school gaat het schoolplein opnieuw inrichten. De leerlingenraad mocht
meedenken en kwam met drie voorstellen: meer groen, een klimtoestel, of een
overdekte plek om te zitten. Uit een enquête onder alle leerlingen bleek dat het
klimtoestel het populairst was bij groep 3 tot en met 5, terwijl de bovenbouw
juist voor de overdekte plek koos. De directeur heeft besloten om te beginnen
met het groen, omdat dat het goedkoopst is en het plein bij hitte een stuk
koeler maakt.''';

const _tekstBrief = '''
Beste ouders,

Op vrijdag 12 juni houden wij onze jaarlijkse sportdag op het terrein van
atletiekvereniging De Sprint. De leerlingen worden om 8.45 uur op school
verwacht en fietsen daarna gezamenlijk naar het terrein. Denkt u aan
sportkleding, een pet en een gevulde bidon? Wij zorgen voor fruit in de pauze.
Om 14.30 uur zijn we terug op school. Bij zeer slecht weer gaat de sportdag niet
door; u krijgt dat dan die ochtend via de schoolapp te horen.''';

/// The generated part of the begrijpend lezen bank.
List<QuizQuestion> buildLezenExtra() {
  final g = QuizGen('glz', seed: 20260914);

  // --- Woordenschat ----------------------------------------------------------
  final woorden = rows(_woorden);
  final betekenissen = [for (final w in woorden) w[1]];
  final losseWoorden = [for (final w in woorden) w[0]];
  for (final w in woorden) {
    g.add(
      topic: _woordenschat,
      prompt: 'Wat betekent het woord "${w[0]}"?',
      answer: w[1],
      wrong: g.others(betekenissen, w[1]),
    );
    g.add(
      topic: _woordenschat,
      prompt: 'Welk woord betekent "${w[1]}"?',
      answer: w[0],
      wrong: g.others(losseWoorden, w[0]),
    );
  }

  final uitdr = rows(_uitdrukkingen);
  for (final u in uitdr) {
    g.add(
      topic: _woordenschat,
      prompt: 'Wat betekent de uitdrukking "${u[0]}"?',
      answer: u[1],
      wrong: g.others([for (final x in uitdr) x[1]], u[1]),
    );
    g.add(
      topic: _woordenschat,
      prompt: 'Welke uitdrukking betekent "${u[1]}"?',
      answer: u[0],
      wrong: g.others([for (final x in uitdr) x[0]], u[0]),
    );
  }

  // --- Signaalwoorden --------------------------------------------------------
  final sig = rows(_signaalwoorden);
  final verbanden = [for (final s in sig) s[1]];
  for (final s in sig) {
    g.add(
      topic: _begrijpen,
      prompt: 'Welk verband geeft het signaalwoord "${s[0]}" aan?',
      answer: s[1],
      wrong: g.others(verbanden, s[1]),
      why: 'Signaalwoorden laten zien hoe zinnen met elkaar samenhangen.',
    );
    g.add(
      topic: _begrijpen,
      prompt: 'Welk signaalwoord wijst op ${s[1]}?',
      answer: s[0],
      wrong: g.others([for (final x in sig) x[0]], s[0]),
    );
  }

  // --- Opzoeken: inhoudsopgave ----------------------------------------------
  for (final boek in rows(_boeken)) {
    final titel = boek[0];
    final hoofdstukken = boek.sublist(1);
    final starts = <int>[];
    var pagina = g.between(3, 7);
    final lengtes = <int>[];
    for (var i = 0; i < hoofdstukken.length; i++) {
      starts.add(pagina);
      final lengte = g.between(6, 18);
      lengtes.add(lengte);
      pagina += lengte;
    }
    final tabel = [
      for (var i = 0; i < hoofdstukken.length; i++)
        '${i + 1}  ${hoofdstukken[i].padRight(26, '.')} ${starts[i]}',
    ].join('\n');
    final passage = 'Inhoudsopgave van het boek "$titel"\n\n$tabel\n'
        'Register $pagina';

    for (var i = 0; i < hoofdstukken.length; i++) {
      g.add(
        topic: _opzoeken,
        passage: passage,
        prompt: 'Op welke bladzijde begint het hoofdstuk "${hoofdstukken[i]}"?',
        answer: 'bladzijde ${starts[i]}',
        wrong: [
          for (var k = 0; k < starts.length; k++)
            if (k != i) 'bladzijde ${starts[k]}',
        ]..shuffle(g.rnd),
      );
    }
    for (var i = 0; i < hoofdstukken.length - 1; i++) {
      g.add(
        topic: _opzoeken,
        passage: passage,
        prompt: 'Hoeveel bladzijden telt het hoofdstuk "${hoofdstukken[i]}"?',
        answer: '${lengtes[i]} bladzijden',
        wrong: [
          '${lengtes[i] + 1} bladzijden',
          '${lengtes[i] - 1} bladzijden',
          '${starts[i]} bladzijden',
          '${lengtes[i] + 5} bladzijden',
        ],
        why: 'Hoofdstuk ${i + 2} begint op bladzijde ${starts[i + 1]}, dus '
            '${starts[i + 1]} - ${starts[i]} = ${lengtes[i]}.',
      );
    }
    g.add(
      topic: _opzoeken,
      passage: passage,
      prompt: 'In welk hoofdstuk zoek je iets over ${hoofdstukken.last}?',
      answer: 'hoofdstuk ${hoofdstukken.length}',
      wrong: [
        for (var k = 1; k < hoofdstukken.length; k++) 'hoofdstuk $k',
      ]..shuffle(g.rnd),
    );
    g.add(
      topic: _opzoeken,
      passage: passage,
      prompt: 'Waar vind je achterin het boek de woorden op alfabet terug?',
      answer: 'in het register op bladzijde $pagina',
      wrong: [
        'in hoofdstuk 1 op bladzijde ${starts.first}',
        'in de inhoudsopgave',
        'op bladzijde ${pagina + 10}',
        'in hoofdstuk ${hoofdstukken.length}',
      ],
    );
  }

  // --- Opzoeken: alfabetiseren ----------------------------------------------
  final perLetter = <String, List<String>>{};
  for (final w in losseWoorden) {
    perLetter.putIfAbsent(w[0], () => []).add(w);
  }
  for (final entry in perLetter.entries) {
    if (entry.value.length < 4) continue;
    final vier = [...entry.value]..shuffle(g.rnd);
    final gekozen = vier.take(4).toList();
    final gesorteerd = [...gekozen]..sort();
    g.add(
      topic: _opzoeken,
      passage: 'Woorden: ${gekozen.join(', ')}',
      prompt: 'Welk van deze woorden staat in het woordenboek vooraan?',
      answer: gesorteerd.first,
      wrong: gesorteerd.sublist(1),
      why: 'Bij dezelfde beginletter kijk je naar de tweede letter, dan de '
          'derde, enzovoort.',
    );
    g.add(
      topic: _opzoeken,
      passage: 'Woorden: ${gekozen.join(', ')}',
      prompt: 'Welk van deze woorden staat in het woordenboek achteraan?',
      answer: gesorteerd.last,
      wrong: gesorteerd.sublist(0, 3),
    );
  }

  // --- Opzoeken: dienstregeling ---------------------------------------------
  for (var b = 0; b < 8; b++) {
    final vertrek = <int>[];
    var t = g.between(6, 9) * 60 + g.between(0, 5) * 5;
    for (var i = 0; i < 5; i++) {
      vertrek.add(t);
      t += g.between(3, 5) * 5;
    }
    final tabel = [
      for (var i = 0; i < _haltes.length; i++)
        '${_haltes[i].padRight(12)} ${_hhmm(vertrek[i])}',
    ].join('\n');
    final passage = 'Dienstregeling buslijn ${12 + b}:\n$tabel';

    g.add(
      topic: _opzoeken,
      passage: passage,
      prompt: 'Hoe laat vertrekt de bus bij ${_haltes[2]}?',
      answer: _hhmm(vertrek[2]),
      wrong: [
        for (var k = 0; k < vertrek.length; k++)
          if (k != 2) _hhmm(vertrek[k]),
      ]..shuffle(g.rnd),
    );
    g.add(
      topic: _opzoeken,
      passage: passage,
      prompt: 'Hoeveel minuten doet de bus over de rit van ${_haltes.first} '
          'naar ${_haltes.last}?',
      answer: '${vertrek.last - vertrek.first} minuten',
      wrong: [
        '${vertrek.last - vertrek.first + 5} minuten',
        '${vertrek.last - vertrek.first - 5} minuten',
        '${vertrek[1] - vertrek[0]} minuten',
        '${vertrek.last - vertrek.first + 15} minuten',
      ],
      why: '${_hhmm(vertrek.last)} min ${_hhmm(vertrek.first)} is '
          '${vertrek.last - vertrek.first} minuten.',
    );
    g.add(
      topic: _opzoeken,
      passage: passage,
      prompt: 'Je wilt om ${_hhmm(vertrek[1] - 2)} bij ${_haltes[1]} zijn. '
          'Haal je die bus?',
      answer: 'Ja, de bus vertrekt daar pas om ${_hhmm(vertrek[1])}',
      wrong: [
        'Nee, die bus is dan al weg',
        'Ja, maar alleen bij ${_haltes[0]}',
        'Nee, deze bus stopt daar niet',
        'Dat staat niet in de dienstregeling',
      ],
    );
  }

  // --- Begrijpend lezen: teksten --------------------------------------------
  g.add(
    topic: _begrijpen,
    passage: _tekstZwerfafval,
    prompt: 'Waarom vinden de leerlingen bij het speelveld minder rommel?',
    answer: 'omdat de gemeente daar extra prullenbakken heeft neergezet',
    wrong: const [
      'omdat er minder kinderen komen',
      'omdat het speelveld is afgesloten',
      'omdat ze daar niet meer opruimen',
    ],
  );
  g.add(
    topic: _begrijpen,
    passage: _tekstZwerfafval,
    prompt: 'Wat vinden de leerlingen het meest?',
    answer: 'blikjes en snoepverpakkingen',
    wrong: const ['glas en papier', 'oude fietsen', 'tuinafval'],
  );
  g.add(
    topic: _begrijpen,
    passage: _tekstZwerfafval,
    prompt: 'Wat is een vermoeden van de leerlingen, en dus geen feit?',
    answer: 'dat de blikjes langs de weg uit autos worden gegooid',
    wrong: const [
      'dat ze bijna driehonderd kilo ophaalden',
      'dat ze in tweetallen op pad gaan',
      'dat de gemeente prullenbakken plaatste',
    ],
    why: 'In de tekst staat "de leerlingen denken dat" — dat is een mening of '
        'vermoeden, geen feit.',
  );
  g.add(
    topic: _samenvatten,
    passage: _tekstZwerfafval,
    prompt: 'Welke titel past het beste bij deze tekst?',
    answer: 'Groep 8 ruimt het zwerfafval op',
    wrong: const [
      'De gemeente plaatst prullenbakken',
      'Blikjes langs de snelweg',
      'Hoe je een grijper gebruikt',
    ],
  );

  g.add(
    topic: _begrijpen,
    passage: _tekstSlaapkamer,
    prompt: 'Waarom is slecht slapen slecht voor je schoolwerk?',
    answer: 'je hersenen ruimen tijdens de slaap op wat je hebt geleerd',
    wrong: const [
      'je wordt er kleiner van',
      'je krijgt er honger van',
      'je ogen worden er slechter van',
    ],
  );
  g.add(
    topic: _begrijpen,
    passage: _tekstSlaapkamer,
    prompt: 'Wat doet het blauwe licht van een telefoon volgens de tekst?',
    answer: 'het zorgt dat het slaaphormoon later wordt aangemaakt',
    wrong: const [
      'het maakt je ogen moe',
      'het houdt je kamer warm',
      'het zorgt dat je sneller inslaapt',
    ],
  );
  g.add(
    topic: _begrijpen,
    passage: _tekstSlaapkamer,
    prompt: 'Welk advies geeft de tekst naast het wegleggen van je telefoon?',
    answer: 'houd een vaste bedtijd aan',
    wrong: const [
      'slaap overdag een uur',
      'drink warme melk',
      'zet je wekker later',
    ],
  );
  g.add(
    topic: _samenvatten,
    passage: _tekstSlaapkamer,
    prompt: 'Wat is de hoofdgedachte van deze tekst?',
    answer: 'goed slapen helpt je leren, en daar kun je zelf iets aan doen',
    wrong: const [
      'telefoons horen niet thuis in een slaapkamer',
      'onderzoekers weten nog weinig over slaap',
      'kinderen slapen te weinig door school',
    ],
  );

  g.add(
    topic: _begrijpen,
    passage: _tekstMuseum,
    prompt: 'Voor wie is de toegang in mei gratis?',
    answer: 'voor iedereen onder de achttien',
    wrong: const [
      'voor iedereen',
      'alleen voor oud-inwoners',
      'alleen voor schoolklassen',
    ],
  );
  g.add(
    topic: _begrijpen,
    passage: _tekstMuseum,
    prompt: 'Op welke dag kun je als gewone bezoeker niet naar binnen?',
    answer: 'op maandag',
    wrong: const ['op zondag', 'op dinsdag', 'op zaterdag'],
  );
  g.add(
    topic: _begrijpen,
    passage: _tekstMuseum,
    prompt: 'Wat kun je in het atelier doen?',
    answer: 'een ansichtkaart maken met een oude drukpers',
    wrong: const [
      'de tentoonstelling bekijken',
      'oude foto\'s inleveren',
      'een rondleiding volgen',
    ],
  );
  g.add(
    topic: _samenvatten,
    passage: _tekstMuseum,
    prompt: 'Wat is het doel van deze tekst?',
    answer: 'bezoekers informeren over het jubileum en wat er te doen is',
    wrong: const [
      'de lezer overhalen lid te worden',
      'uitleggen hoe een drukpers werkt',
      'vertellen hoe het dorp in de oorlog was',
    ],
  );

  g.add(
    topic: _begrijpen,
    passage: _tekstBever,
    prompt: 'Waarom zijn beverdammen goed voor andere dieren?',
    answer: 'er ontstaan poelen waar andere dieren van profiteren',
    wrong: const [
      'de dammen houden roofdieren tegen',
      'er komt meer voedsel op het land',
      'de bomen groeien er sneller door',
    ],
  );
  g.add(
    topic: _begrijpen,
    passage: _tekstBever,
    prompt: 'Waarom zijn waterschappen niet altijd blij met bevers?',
    answer: 'een dam in de verkeerde sloot kan een weiland onder water zetten',
    wrong: const [
      'bevers eten de vissen op',
      'bevers zijn gevaarlijk voor mensen',
      'bevers graven in de dijken van de zee',
    ],
  );
  g.add(
    topic: _begrijpen,
    passage: _tekstBever,
    prompt: 'Wat gebeurde er in 1988?',
    answer: 'er werden weer bevers uitgezet in de Biesbosch',
    wrong: const [
      'de laatste bever verdween',
      'de eerste dam werd weggehaald',
      'de bever werd beschermd bij wet',
    ],
  );
  g.add(
    topic: _samenvatten,
    passage: _tekstBever,
    prompt: 'Welke samenvatting past het beste?',
    answer: 'de bever is terug in Nederland, met voordelen en nadelen',
    wrong: const [
      'bevers zijn schadelijk en moeten weg',
      'de Biesbosch is het enige gebied met bevers',
      'waterschappen bouwen dammen na voor bevers',
    ],
  );

  g.add(
    topic: _begrijpen,
    passage: _tekstSchoolplein,
    prompt: 'Welk voorstel koos de bovenbouw?',
    answer: 'de overdekte plek om te zitten',
    wrong: const ['het klimtoestel', 'meer groen', 'een nieuw voetbalveld'],
  );
  g.add(
    topic: _begrijpen,
    passage: _tekstSchoolplein,
    prompt: 'Waarom begint de school met het groen?',
    answer: 'dat is het goedkoopst en het houdt het plein koeler',
    wrong: const [
      'dat wilden de meeste leerlingen',
      'dat was het idee van de gemeente',
      'dat kan het snelst worden aangelegd',
    ],
  );
  g.add(
    topic: _begrijpen,
    passage: _tekstSchoolplein,
    prompt: 'Wie mocht meedenken over het plein?',
    answer: 'de leerlingenraad',
    wrong: const ['alleen de directeur', 'de ouders', 'de gemeente'],
  );
  g.add(
    topic: _samenvatten,
    passage: _tekstSchoolplein,
    prompt: 'Welke titel past het beste bij deze tekst?',
    answer: 'Het schoolplein gaat op de schop',
    wrong: const [
      'De leerlingenraad stelt zich voor',
      'Klimtoestellen zijn gevaarlijk',
      'Hitte op school',
    ],
  );

  g.add(
    topic: _begrijpen,
    passage: _tekstBrief,
    prompt: 'Hoe laat moeten de leerlingen op school zijn?',
    answer: 'om 8.45 uur',
    wrong: const ['om 8.30 uur', 'om 9.00 uur', 'om 14.30 uur'],
  );
  g.add(
    topic: _begrijpen,
    passage: _tekstBrief,
    prompt: 'Wat hoeven de ouders niet mee te geven?',
    answer: 'fruit voor de pauze',
    wrong: const ['sportkleding', 'een pet', 'een gevulde bidon'],
    why: 'De school zorgt zelf voor het fruit.',
  );
  g.add(
    topic: _begrijpen,
    passage: _tekstBrief,
    prompt: 'Hoe horen de ouders het als de sportdag niet doorgaat?',
    answer: 'die ochtend via de schoolapp',
    wrong: const [
      'de avond ervoor per brief',
      'via de website',
      'ze horen het niet',
    ],
  );
  g.add(
    topic: _samenvatten,
    passage: _tekstBrief,
    prompt: 'Wat voor soort tekst is dit?',
    answer: 'een informatieve brief',
    wrong: const [
      'een verhaal',
      'een advertentie',
      'een verslag achteraf',
    ],
  );

  return g.questions;
}
