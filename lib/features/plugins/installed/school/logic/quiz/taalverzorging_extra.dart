import '../quiz_bank.dart';
import 'gen.dart';

const _spelling = 'Spelling niet-werkwoorden';
const _werkwoorden = 'Werkwoordspelling';
const _leestekens = 'Leestekens';

/// `infinitief|stam|hij-vorm|verleden tijd (wij)|voltooid deelwoord`
///
/// All five forms are written out rather than derived, so a strong verb costs
/// no more than a weak one and no spelling rule has to be re-implemented here.
const _verbs = [
  'werken|werk|werkt|werkten|gewerkt',
  'wandelen|wandel|wandelt|wandelden|gewandeld',
  'antwoorden|antwoord|antwoordt|antwoordden|geantwoord',
  'vinden|vind|vindt|vonden|gevonden',
  'worden|word|wordt|werden|geworden',
  'branden|brand|brandt|brandden|gebrand',
  'redden|red|redt|redden|gered',
  'praten|praat|praat|praatten|gepraat',
  'zetten|zet|zet|zetten|gezet',
  'maken|maak|maakt|maakten|gemaakt',
  'horen|hoor|hoort|hoorden|gehoord',
  'leren|leer|leert|leerden|geleerd',
  'spelen|speel|speelt|speelden|gespeeld',
  'fietsen|fiets|fietst|fietsten|gefietst',
  'tekenen|teken|tekent|tekenden|getekend',
  'rekenen|reken|rekent|rekenden|gerekend',
  'verhuizen|verhuis|verhuist|verhuisden|verhuisd',
  'bestellen|bestel|bestelt|bestelden|besteld',
  'betalen|betaal|betaalt|betaalden|betaald',
  'vertellen|vertel|vertelt|vertelden|verteld',
  'beloven|beloof|belooft|beloofden|beloofd',
  'verwachten|verwacht|verwacht|verwachtten|verwacht',
  'ontmoeten|ontmoet|ontmoet|ontmoetten|ontmoet',
  'leven|leef|leeft|leefden|geleefd',
  'geloven|geloof|gelooft|geloofden|geloofd',
  'reizen|reis|reist|reisden|gereisd',
  'verven|verf|verft|verfden|geverfd',
  'lopen|loop|loopt|liepen|gelopen',
  'schrijven|schrijf|schrijft|schreven|geschreven',
  'lezen|lees|leest|lazen|gelezen',
  'zwemmen|zwem|zwemt|zwommen|gezwommen',
  'drinken|drink|drinkt|dronken|gedronken',
  'zingen|zing|zingt|zongen|gezongen',
  'springen|spring|springt|sprongen|gesprongen',
  'nemen|neem|neemt|namen|genomen',
  'geven|geef|geeft|gaven|gegeven',
  'komen|kom|komt|kwamen|gekomen',
  'staan|sta|staat|stonden|gestaan',
  'zien|zie|ziet|zagen|gezien',
  'slapen|slaap|slaapt|sliepen|geslapen',
  'eten|eet|eet|aten|gegeten',
  'weten|weet|weet|wisten|geweten',
  'laten|laat|laat|lieten|gelaten',
  'brengen|breng|brengt|brachten|gebracht',
  'denken|denk|denkt|dachten|gedacht',
  'zoeken|zoek|zoekt|zochten|gezocht',
  'kopen|koop|koopt|kochten|gekocht',
  'helpen|help|helpt|hielpen|geholpen',
  'kiezen|kies|kiest|kozen|gekozen',
  'verliezen|verlies|verliest|verloren|verloren',
  'beginnen|begin|begint|begonnen|begonnen',
  'vergeten|vergeet|vergeet|vergaten|vergeten',
  'gebruiken|gebruik|gebruikt|gebruikten|gebruikt',
  'verdienen|verdien|verdient|verdienden|verdiend',
  'bouwen|bouw|bouwt|bouwden|gebouwd',
  'duwen|duw|duwt|duwden|geduwd',
  'groeien|groei|groeit|groeiden|gegroeid',
  'hopen|hoop|hoopt|hoopten|gehoopt',
  'wachten|wacht|wacht|wachtten|gewacht',
  'starten|start|start|startten|gestart',
  'melden|meld|meldt|meldden|gemeld',
  'verhuren|verhuur|verhuurt|verhuurden|verhuurd',
  'openen|open|opent|openden|geopend',
];

/// `goed|fout|fout|fout`
const _spellingWoorden = [
  'cadeautje|kadeautje|cadeauwtje|cadautje',
  'restaurant|resteraunt|restaurand|restourant',
  'tandenborstel|tandeborstel|tandenbostel|tandenborsel',
  'politie|poletie|polietie|polisie',
  'januari|janwari|januarie|janwarie',
  'februari|febuari|februarie|febrewari',
  'theater|teater|theathe|theather',
  'directeur|direkteur|directuur|direktuur',
  'avontuur|aventuur|avontur|afontuur',
  'computer|komputer|computor|compjoeter',
  'horloge|horlogge|horlosje|orloge',
  'sinaasappel|sinasappel|sinaasapel|sienaasappel',
  'verjaardag|verjaardach|verjaardagg|ferjaardag',
  'gezellig|gezelig|gezellich|gezellieg',
  'plotseling|plotselling|plotseleng|plotzeling',
  'eigenlijk|eigelijk|eiglijk|eigenlik',
  'natuurlijk|natuurlik|natuulijk|natuurlijck',
  'misschien|mischien|misschin|missien',
  'verschillende|verschillinde|verschilende|ferschillende',
  'belangrijk|belangrik|belanrijk|belangrijck',
  'ongeveer|ongefeer|ongveer|ongeveerd',
  'bijvoorbeeld|bijvoorbeelt|beivoorbeeld|bijforbeeld',
  'werkelijk|werkelik|werklijk|werkelijck',
  'vrolijk|vrolik|vroolijk|vrolijck',
  'lelijk|lelik|leelijk|lelijck',
  'kwijt|kweit|kwijd|kwijdt',
  'altijd|altijt|alteid|altied',
  'terwijl|terweil|terwijll|terwil',
  'mysterie|misterie|mysteri|mieserie',
  'tropisch|tropies|trobisch|tropiesch',
  'publiek|publik|publyk|pupliek',
  'museum|meseum|musium|muzeum',
  'industrie|industri|indoestrie|industreie',
  'elektriciteit|electriciteit|elektrisiteit|elektriciteid',
  'temperatuur|tempratuur|temperateur|temperratuur',
  'kilometer|kielometer|kilomeeter|kilometter',
  'minuut|minut|menuut|minuutt',
  'seconde|sekonde|secconde|seconte',
  'kwartier|kwartir|kwarttier|kwaartier',
  'vakantie|vakansie|vacantie|vakantsie',
  'familie|femilie|famielie|familliee',
  'ziekenhuis|ziekehuis|zieckenhuis|ziekenhuijs',
  'apotheek|apoteek|appotheek|apotheekk',
  'bibliotheek|bibiliotheek|biblioteek|bibliotheekk',
  'gymnastiek|gimnastiek|gymnastik|gymnastiekk',
  'zwembad|zwemmbad|swembad|zwembadt',
  'station|stasion|statsion|stationn',
  'kantoor|kantor|cantoor|kantoorr',
  'paraplu|parapluu|paraplue|paraplui',
  'chocolade|sjokolade|chocolaade|chocolatte',
  'enthousiast|entousiast|enthoesiast|enthousiaast',
  'akkoord|accoord|akoord|akkoordt',
  'succes|sucses|succus|sukses',
  'adres|addres|adress|aderes',
  'agenda|agendaa|agenta|aganda',
  'bijzonder|beizonder|bijzonderr|bizonder',
  'tijdschrift|teidschrift|tijdschrieft|tijtschrift',
  'vrijheid|vreiheid|vrijheit|vrijhijd',
  'prijs|preis|prijz|prijss',
  'wijsheid|weisheid|wijsheit|wijshijd',
  'geheim|gehijm|geheym|geheimm',
  'trein|trijn|treinn|treyn',
  'eiland|ijland|eyland|eilandt',
  'lawaai|laway|lawai|lawaay',
  'blauw|blaauw|blouw|blaw',
  'flauw|flaauw|flouw|flaw',
  'kabouter|kabbouter|kabouder|kabauter',
  'benauwd|benouwd|benauwt|benauwdt',
  'douche|doushe|doeche|douge',
  'route|roete|routte|roeten',
];

/// `enkelvoud|meervoud` — the wrong options are built from the singular.
const _meervoud = [
  'foto|foto|s',
  'auto|auto|s',
  'radio|radio|s',
  'menu|menu|s',
  'paraplu|paraplu|s',
  'boom|bomen',
  'raam|ramen',
  'kind|kinderen',
  'ei|eieren',
  'huis|huizen',
  'muis|muizen',
  'brief|brieven',
  'schoen|schoenen',
  'stad|steden',
  'schip|schepen',
  'koe|koeien',
  'zee|zeeën',
  'lied|liederen',
  'been|benen',
  'oog|ogen',
  'dief|dieven',
  'wolf|wolven',
  'graf|graven',
  'glas|glazen',
  'huisdier|huisdieren',
  'appel|appels',
  'tafel|tafels',
  'lepel|lepels',
  'vogel|vogels',
];

/// `woord|verkleinwoord`
const _verkleinwoorden = [
  'boom|boompje',
  'raam|raampje',
  'bloem|bloempje',
  'bal|balletje',
  'man|mannetje',
  'ring|ringetje',
  'koning|koninkje',
  'ding|dingetje',
  'kar|karretje',
  'ster|sterretje',
  'huis|huisje',
  'boek|boekje',
  'stoel|stoeltje',
  'kraan|kraantje',
  'traan|traantje',
  'lepel|lepeltje',
  'appel|appeltje',
  'tafel|tafeltje',
  'auto|autootje',
  'foto|fotootje',
  'paraplu|parapluutje',
  'zee|zeetje',
  'kussen|kussentje',
  'wagen|wagentje',
  'jongen|jongetje',
  'brug|bruggetje',
  'kat|katje',
  'hond|hondje',
  'muis|muisje',
  'brief|briefje',
];

const _hoofdletterWel = [
  'Nederlands',
  'Frans',
  'Duits',
  'Engels',
  'Spaans',
  'Italiaans',
  'Amsterdam',
  'Utrecht',
  'Groningen',
  'Europa',
  'Afrika',
  'de Rijn',
  'de Waddenzee',
  'Belgisch',
  'Marokkaans',
  'de Tweede Wereldoorlog',
  'Koningsdag',
  'Sinterklaas',
];

const _hoofdletterNiet = [
  'maandag',
  'dinsdag',
  'woensdag',
  'donderdag',
  'vrijdag',
  'zaterdag',
  'zondag',
  'januari',
  'februari',
  'maart',
  'september',
  'december',
  'zomer',
  'winter',
  'herfst',
  'lente',
  'aardrijkskunde',
  'geschiedenis',
];

const _sprekers = [
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
];

const _vragen = [
  'Kom je mee',
  'Heb je dat gezien',
  'Waar is mijn tas',
  'Mag ik erbij komen zitten',
  'Wie heeft de sleutel',
  'Hoe laat begint het',
  'Weet jij het antwoord',
  'Ga je ook naar de wedstrijd',
];

const _uitspraken = [
  'Ik kom eraan',
  'Dat had ik niet verwacht',
  'We moeten opschieten',
  'Het regent al de hele dag',
  'Ik heb mijn boek vergeten',
  'Morgen ga ik zwemmen',
  'Die film was echt goed',
  'Straks eten we pannenkoeken',
];

const _zegwerkwoorden = ['vroeg', 'zei', 'riep', 'fluisterde', 'antwoordde'];

/// `zin|leesteken` where the leesteken is `.`, `?` or `!`
const _zinnen = [
  'Morgen gaan we op schoolreisje|.',
  'Wat is het hier warm|!',
  'Hoe laat komt de bus|?',
  'Pas op, het glas valt|!',
  'Mijn broer zit in groep zes|.',
  'Waar heb jij dat gevonden|?',
  'Wat een prachtig schilderij|!',
  'De trein vertrekt om tien uur|.',
  'Ken jij dat liedje ook|?',
  'Blijf staan|!',
  'We hebben de hele middag gefietst|.',
  'Wie wil er nog een broodje|?',
  'Kijk uit voor die auto|!',
  'Het zwembad is op maandag gesloten|.',
  'Weet iemand waar de gymzaal is|?',
  'Wat ruikt dat lekker|!',
  'Ik heb mijn huiswerk al af|.',
  'Waarom lach je zo|?',
  'Gefeliciteerd met je verjaardag|!',
  'De bibliotheek gaat om vijf uur dicht|.',
  'Zullen we samen werken aan het werkstuk|?',
  'Wat schrik ik daarvan|!',
  'Onze meester heet Bas|.',
  'Hoeveel kost een kaartje|?',
];

const _opsommingen = [
  'brood|kaas|appels|drinken',
  'een pen|een schrift|een gum|een liniaal',
  'Sam|Noor|Yusuf|Fenna',
  'zwemmen|fietsen|hardlopen|turnen',
  'rode|gele|groene|blauwe',
  'melk|eieren|bloem|suiker',
  'een handdoek|zwemkleding|slippers|zonnebrand',
  'Frankrijk|Spanje|Italië|Portugal',
];

String _swapEnd(String word) {
  if (word.endsWith('ten')) return '${word.substring(0, word.length - 3)}den';
  if (word.endsWith('den')) return '${word.substring(0, word.length - 3)}ten';
  if (word.endsWith('t')) return '${word.substring(0, word.length - 1)}d';
  if (word.endsWith('d')) return '${word.substring(0, word.length - 1)}t';
  return '${word}t';
}

/// The generated part of the taalverzorging bank.
List<QuizQuestion> buildTaalverzorgingExtra() {
  final g = QuizGen('gtv', seed: 20260909);

  // --- Werkwoordspelling -----------------------------------------------------
  for (final v in rows(_verbs)) {
    final inf = v[0];
    final stam = v[1];
    final hij = v[2];
    final vt = v[3];
    final vd = v[4];

    final vormen = [stam, '${stam}t', '${stam}d', '${stam}dt'];

    g.add(
      topic: _werkwoorden,
      prompt: 'Hoe schrijf je "$inf" in de tegenwoordige tijd bij "hij"?',
      answer: hij,
      wrong: [
        for (final f in vormen)
          if (f != hij) f,
      ],
      why: hij == stam
          ? 'De stam eindigt al op een t, er komt er geen tweede bij.'
          : 'Bij hij, zij of het komt er een t achter de stam ($stam + t).',
    );

    g.add(
      topic: _werkwoorden,
      prompt: 'Hoe schrijf je "$inf" in de tegenwoordige tijd bij "ik"?',
      answer: stam,
      wrong: [
        for (final f in vormen)
          if (f != stam) f,
      ],
      why: 'Bij "ik" schrijf je alleen de stam: $stam.',
    );

    g.add(
      topic: _werkwoorden,
      prompt:
          'Welke vorm van "$inf" gebruik je in de tegenwoordige tijd als het onderwerp "jij" direct achter het werkwoord staat?',
      answer: stam,
      wrong: [
        for (final f in vormen)
          if (f != stam) f,
      ],
      why: 'Staat "jij" achter het werkwoord, dan valt de t weg.',
    );

    g.add(
      topic: _werkwoorden,
      prompt: 'Hoe schrijf je "$inf" in de verleden tijd bij "wij"?',
      answer: vt,
      wrong: [
        if (vt.endsWith('n')) vt.substring(0, vt.length - 1),
        _swapEnd(vt),
        '${stam}de',
        '${stam}te',
        '${stam}den',
      ],
      why: 'De verleden tijd van "$inf" bij wij, jullie of zij is "$vt".',
    );

    g.add(
      topic: _werkwoorden,
      prompt: 'Wat is het voltooid deelwoord van "$inf"?',
      answer: vd,
      wrong: [
        _swapEnd(vd),
        if (vd.startsWith('ge')) vd.substring(2),
        'ge$stam',
        '${vd}d',
      ],
      why:
          'Het voltooid deelwoord is "$vd". Het hulpwerkwoord is hebben of zijn.',
    );
  }

  // --- Spelling: goed of fout ------------------------------------------------
  final goedeWoorden = [for (final r in rows(_spellingWoorden)) r[0]];
  for (final w in rows(_spellingWoorden)) {
    g.add(
      topic: _spelling,
      prompt: 'Welk woord is goed geschreven?',
      answer: w[0],
      wrong: w.sublist(1),
      why: 'Het is "${w[0]}".',
    );
    g.add(
      topic: _spelling,
      prompt: 'Welk woord is fóút geschreven? (drie zijn goed, één niet)',
      answer: w[1],
      wrong: [w[0], ...g.others(goedeWoorden, w[0], 2)],
      why: '"${w[1]}" bestaat niet; het is "${w[0]}".',
    );
  }

  // --- Spelling: meervoud ----------------------------------------------------
  for (final m in rows(_meervoud)) {
    final enkel = m[0];
    final meer = m.length > 2 ? "${m[1]}'s" : m[1];
    g.add(
      topic: _spelling,
      prompt: 'Wat is het meervoud van "$enkel"?',
      answer: meer,
      wrong: ['${enkel}s', '${enkel}en', "$enkel's", '${enkel}n'],
      why: 'Het meervoud is "$meer".',
    );
  }

  // --- Spelling: verkleinwoorden ---------------------------------------------
  for (final v in rows(_verkleinwoorden)) {
    final woord = v[0];
    final klein = v[1];
    g.add(
      topic: _spelling,
      prompt: 'Wat is het verkleinwoord van "$woord"?',
      answer: klein,
      wrong: ['${woord}je', '${woord}tje', '${woord}pje', '${woord}kje'],
      why: 'Het verkleinwoord is "$klein".',
    );
  }

  // --- Spelling: hoofdletters ------------------------------------------------
  for (final woord in _hoofdletterWel) {
    g.add(
      topic: _spelling,
      prompt: 'Welk woord schrijf je met een hoofdletter?',
      answer: woord,
      wrong: g.others(_hoofdletterNiet, woord),
      why:
          'Talen, landen, plaatsen en namen krijgen een hoofdletter; '
          'dagen, maanden en seizoenen niet.',
    );
  }
  for (final woord in _hoofdletterNiet) {
    g.add(
      topic: _spelling,
      prompt: 'Welk woord schrijf je juist zónder hoofdletter?',
      answer: woord,
      wrong: g.others(_hoofdletterWel, woord),
      why: 'Dagen, maanden, seizoenen en schoolvakken schrijf je klein.',
    );
  }

  // --- Leestekens: directe rede ----------------------------------------------
  for (var i = 0; i < 28; i++) {
    final naam = g.oneOf(_sprekers);
    final ww = g.oneOf(_zegwerkwoorden.where((w) => w != 'vroeg').toList());
    final vraag = g.rnd.nextBool();
    if (vraag) {
      final zin = g.oneOf(_vragen);
      g.add(
        topic: _leestekens,
        prompt: 'Welke zin heeft de leestekens goed?',
        answer: '"$zin?" $ww $naam.',
        wrong: [
          '"$zin?" $ww, $naam.',
          '"$zin?" ${ww[0].toUpperCase()}${ww.substring(1)} $naam.',
          '"$zin." $ww $naam.',
          '"$zin" $ww $naam?',
        ],
        why:
            'Het vraagteken staat binnen de aanhalingstekens. De woorden erna beginnen '
            'met een kleine letter; een komma na het aanhalingsteken mag ook.',
      );
    } else {
      final zin = g.oneOf(_uitspraken);
      g.add(
        topic: _leestekens,
        prompt: 'Welke zin heeft de leestekens goed?',
        answer: '"$zin," $ww $naam.',
        wrong: [
          '"$zin." $ww $naam.',
          '"$zin" $ww $naam.',
          '"$zin," ${ww[0].toUpperCase()}${ww.substring(1)} $naam.',
          '"$zin"; $ww $naam.',
        ],
        why:
            'Bij een mededeling komt er een komma vóór het aanhalingsteken '
            'aan het eind.',
      );
    }
  }

  // --- Leestekens: welk teken hoort erachter? --------------------------------
  for (final z in rows(_zinnen)) {
    final teken = switch (z[1]) {
      '?' => 'een vraagteken',
      '!' => 'een uitroepteken',
      _ => 'een punt',
    };
    g.add(
      topic: _leestekens,
      prompt:
          '${z[1] == '!'
              ? 'Je wilt nadrukkelijk iets uitroepen.'
              : z[1] == '?'
              ? 'Je stelt een directe vraag.'
              : 'Je schrijft een rustige mededeling.'} '
          'Welk leesteken past dan aan het eind?\n'
          '"${z[0]} …"',
      answer: teken,
      wrong: const [
        'een punt',
        'een vraagteken',
        'een uitroepteken',
        'een komma',
      ],
      why: switch (z[1]) {
        '?' => 'Het is een vraag, dus een vraagteken.',
        '!' => 'De zin roept iets uit, dus een uitroepteken.',
        _ => 'Het is een gewone mededeling, dus een punt.',
      },
    );
  }

  // --- Leestekens: opsommingen -----------------------------------------------
  for (final o in rows(_opsommingen)) {
    final zonderLaatste = o.sublist(0, o.length - 1).join(', ');
    final goed = '$zonderLaatste en ${o.last}';
    g.add(
      topic: _leestekens,
      prompt:
          'Welke opsomming gebruikt kommas tussen de eerste drie delen en alleen "en" voor het laatste deel?',
      answer: goed,
      wrong: [
        o.join(' '),
        o.join(', '),
        '$zonderLaatste, en ${o.last}',
        '${o.first} ${o[1]}, ${o[2]} en ${o.last}',
      ],
      why: 'Hier verbinden twee kommas en het woord "en" de vier delen.',
    );
    g.add(
      topic: _leestekens,
      prompt:
          'Hoeveel kommas gebruik je tussen de eerste drie delen als je het laatste deel met "en" aansluit?\n'
          '"Ik neem ${o.join(' … ')} mee."',
      answer: '${o.length - 2}',
      wrong: ['${o.length}', '${o.length - 1}', '${o.length - 3}', '0'],
      why:
          'Er zijn ${o.length} delen; het laatste deel krijgt "en" in plaats '
          'van een komma.',
    );
    g.add(
      topic: _leestekens,
      prompt:
          'Welk leesteken hoort er in deze zin?\n'
          '"Ik heb drie dingen nodig … $zonderLaatste."',
      answer: 'een dubbele punt',
      wrong: const [
        'een komma',
        'een puntkomma',
        'een uitroepteken',
        'een vraagteken',
      ],
      why: 'Een opsomming die je aankondigt, begint met een dubbele punt.',
    );
  }

  // --- Leestekens: hoofdletter na een punt -----------------------------------
  for (var i = 0; i < 18; i++) {
    final a = g.oneOf(_uitspraken);
    final b = g.oneOf(_uitspraken);
    if (a == b) continue;
    g.add(
      topic: _leestekens,
      prompt: 'Welke zinnen staan goed achter elkaar?',
      answer: '$a. ${b[0]}${b.substring(1).toLowerCase()}.',
      wrong: [
        '$a? ${b[0].toLowerCase()}${b.substring(1)}.',
        '$a. ${b[0].toLowerCase()}${b.substring(1)}.',
        '$a ${b[0]}${b.substring(1)}.',
        '$a; ${b[0].toLowerCase()}${b.substring(1)}',
      ],
      why: 'Na een punt begint de volgende zin met een hoofdletter.',
    );
  }

  return g.questions;
}
