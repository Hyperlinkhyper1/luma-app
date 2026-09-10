import '../quiz_bank.dart';
import 'gen.dart';

const _nederland = 'Nederland';
const _europa = 'Europa';
const _wereld = 'De wereld en het weer';

/// `provincie|hoofdstad`
const _provincies = [
  'Groningen|Groningen',
  'Friesland|Leeuwarden',
  'Drenthe|Assen',
  'Overijssel|Zwolle',
  'Flevoland|Lelystad',
  'Gelderland|Arnhem',
  'Utrecht|Utrecht',
  'Noord-Holland|Haarlem',
  'Zuid-Holland|Den Haag',
  'Zeeland|Middelburg',
  'Noord-Brabant|Den Bosch',
  'Limburg|Maastricht',
];

/// `plaats|provincie`
const _plaatsen = [
  'Amsterdam|Noord-Holland',
  'Rotterdam|Zuid-Holland',
  'Eindhoven|Noord-Brabant',
  'Tilburg|Noord-Brabant',
  'Almere|Flevoland',
  'Breda|Noord-Brabant',
  'Nijmegen|Gelderland',
  'Apeldoorn|Gelderland',
  'Enschede|Overijssel',
  'Amersfoort|Utrecht',
  'Zaanstad|Noord-Holland',
  'Dordrecht|Zuid-Holland',
  'Leiden|Zuid-Holland',
  'Emmen|Drenthe',
  'Deventer|Overijssel',
  'Delft|Zuid-Holland',
  'Venlo|Limburg',
  'Sittard|Limburg',
  'Heerlen|Limburg',
  'Roermond|Limburg',
  'Alkmaar|Noord-Holland',
  'Hilversum|Noord-Holland',
  'Hoorn|Noord-Holland',
  'Purmerend|Noord-Holland',
  'Gouda|Zuid-Holland',
  'Zoetermeer|Zuid-Holland',
  'Schiedam|Zuid-Holland',
  'Helmond|Noord-Brabant',
  'Oss|Noord-Brabant',
  'Roosendaal|Noord-Brabant',
  'Bergen op Zoom|Noord-Brabant',
  'Ede|Gelderland',
  'Doetinchem|Gelderland',
  'Zutphen|Gelderland',
  'Harderwijk|Gelderland',
  'Hengelo|Overijssel',
  'Almelo|Overijssel',
  'Kampen|Overijssel',
  'Sneek|Friesland',
  'Drachten|Friesland',
  'Heerenveen|Friesland',
  'Hoogeveen|Drenthe',
  'Meppel|Drenthe',
  'Veendam|Groningen',
  'Delfzijl|Groningen',
  'Winschoten|Groningen',
  'Terneuzen|Zeeland',
  'Vlissingen|Zeeland',
  'Goes|Zeeland',
  'Emmeloord|Flevoland',
  'Dronten|Flevoland',
  'Veenendaal|Utrecht',
  'Nieuwegein|Utrecht',
  'Zeist|Utrecht',
];

/// `land|hoofdstad|deel van Europa`
const _europeseLanden = [
  'Nederland|Amsterdam|West-Europa',
  'Belgie|Brussel|West-Europa',
  'Duitsland|Berlijn|West-Europa',
  'Frankrijk|Parijs|West-Europa',
  'Luxemburg|Luxemburg|West-Europa',
  'Verenigd Koninkrijk|Londen|West-Europa',
  'Ierland|Dublin|West-Europa',
  'Zwitserland|Bern|West-Europa',
  'Oostenrijk|Wenen|West-Europa',
  'Spanje|Madrid|Zuid-Europa',
  'Portugal|Lissabon|Zuid-Europa',
  'Italie|Rome|Zuid-Europa',
  'Griekenland|Athene|Zuid-Europa',
  'Kroatie|Zagreb|Zuid-Europa',
  'Slovenie|Ljubljana|Zuid-Europa',
  'Servie|Belgrado|Zuid-Europa',
  'Albanie|Tirana|Zuid-Europa',
  'Noord-Macedonie|Skopje|Zuid-Europa',
  'Montenegro|Podgorica|Zuid-Europa',
  'Malta|Valletta|Zuid-Europa',
  'Cyprus|Nicosia|Zuid-Europa',
  'Denemarken|Kopenhagen|Noord-Europa',
  'Noorwegen|Oslo|Noord-Europa',
  'Zweden|Stockholm|Noord-Europa',
  'Finland|Helsinki|Noord-Europa',
  'IJsland|Reykjavik|Noord-Europa',
  'Estland|Tallinn|Noord-Europa',
  'Letland|Riga|Noord-Europa',
  'Litouwen|Vilnius|Noord-Europa',
  'Polen|Warschau|Oost-Europa',
  'Tsjechie|Praag|Oost-Europa',
  'Slowakije|Bratislava|Oost-Europa',
  'Hongarije|Boedapest|Oost-Europa',
  'Roemenie|Boekarest|Oost-Europa',
  'Bulgarije|Sofia|Oost-Europa',
  'Oekraine|Kiev|Oost-Europa',
  'Wit-Rusland|Minsk|Oost-Europa',
  'Moldavie|Chisinau|Oost-Europa',
  'Rusland|Moskou|Oost-Europa',
];

/// `land|hoofdstad|werelddeel`
const _wereldLanden = [
  'Japan|Tokio|Azie',
  'China|Peking|Azie',
  'India|New Delhi|Azie',
  'Indonesie|Jakarta|Azie',
  'Thailand|Bangkok|Azie',
  'Vietnam|Hanoi|Azie',
  'Zuid-Korea|Seoul|Azie',
  'Filipijnen|Manilla|Azie',
  'Maleisie|Kuala Lumpur|Azie',
  'Pakistan|Islamabad|Azie',
  'Iran|Teheran|Azie',
  'Irak|Bagdad|Azie',
  'Saoedi-Arabie|Riyad|Azie',
  'Turkije|Ankara|Azie',
  'Nepal|Kathmandu|Azie',
  'Mongolie|Ulaanbaatar|Azie',
  'Kazachstan|Astana|Azie',
  'Sri Lanka|Sri Jayewardenepura Kotte|Azie',
  'Bangladesh|Dhaka|Azie',
  'Afghanistan|Kaboel|Azie',
  'Syrie|Damascus|Azie',
  'Jordanie|Amman|Azie',
  'Libanon|Beiroet|Azie',
  'Qatar|Doha|Azie',
  'Egypte|Caïro|Afrika',
  'Marokko|Rabat|Afrika',
  'Algerije|Algiers|Afrika',
  'Tunesie|Tunis|Afrika',
  'Libie|Tripoli|Afrika',
  'Nigeria|Abuja|Afrika',
  'Ghana|Accra|Afrika',
  'Kenia|Nairobi|Afrika',
  'Ethiopie|Addis Abeba|Afrika',
  'Zuid-Afrika|Pretoria|Afrika',
  'Tanzania|Dodoma|Afrika',
  'Oeganda|Kampala|Afrika',
  'Senegal|Dakar|Afrika',
  'Mali|Bamako|Afrika',
  'Soedan|Khartoem|Afrika',
  'Angola|Luanda|Afrika',
  'Zimbabwe|Harare|Afrika',
  'Mozambique|Maputo|Afrika',
  'Kameroen|Yaoundé|Afrika',
  'Verenigde Staten|Washington|Noord-Amerika',
  'Canada|Ottawa|Noord-Amerika',
  'Mexico|Mexico-Stad|Noord-Amerika',
  'Cuba|Havana|Noord-Amerika',
  'Jamaica|Kingston|Noord-Amerika',
  'Guatemala|Guatemala-Stad|Noord-Amerika',
  'Panama|Panama-Stad|Noord-Amerika',
  'Costa Rica|San José|Noord-Amerika',
  'Brazilie|Brasilia|Zuid-Amerika',
  'Argentinie|Buenos Aires|Zuid-Amerika',
  'Chili|Santiago|Zuid-Amerika',
  'Peru|Lima|Zuid-Amerika',
  'Colombia|Bogota|Zuid-Amerika',
  'Venezuela|Caracas|Zuid-Amerika',
  'Ecuador|Quito|Zuid-Amerika',
  'Uruguay|Montevideo|Zuid-Amerika',
  'Paraguay|Asuncion|Zuid-Amerika',
  'Suriname|Paramaribo|Zuid-Amerika',
  'Guyana|Georgetown|Zuid-Amerika',
  'Australie|Canberra|Oceanie',
  'Nieuw-Zeeland|Wellington|Oceanie',
  'Papoea-Nieuw-Guinea|Port Moresby|Oceanie',
  'Fiji|Suva|Oceanie',
];

const _werelddelen = [
  'Europa',
  'Azie',
  'Afrika',
  'Noord-Amerika',
  'Zuid-Amerika',
  'Oceanie',
];

/// `vraag|antwoord|fout|fout|fout`
const _nederlandFeiten = [
  'Welke waterweg verbindt Rotterdam met de Noordzee?|de Nieuwe Waterweg|de IJssel|de Vecht|de Dommel',
  'Hoe heet de grootste rivier die Duitsland en Nederland verbindt?|de Rijn|de Schelde|de Eems|de Linge',
  'Welke rivier is een aftakking van de Rijn en stroomt langs Nijmegen?|de Waal|de Maas|de IJssel|de Vecht',
  'Welke rivier komt uit Frankrijk en stroomt door Limburg?|de Maas|de Rijn|de Schelde|de Amstel',
  'Welke rivier stroomt naar het noorden, richting het IJsselmeer?|de IJssel|de Waal|de Lek|de Dommel',
  'Hoe heet de dijk tussen Noord-Holland en Friesland?|de Afsluitdijk|de Deltadijk|de Brouwersdam|de Houtribdijk',
  'Welk meer ontstond achter de Afsluitdijk?|het IJsselmeer|het Veluwemeer|de Waddenzee|het Grevelingenmeer',
  'Waarom zijn de Deltawerken gebouwd?|om Zeeland tegen overstromingen te beschermen|om meer land te winnen|om schepen sneller te laten varen|om zoet water op te slaan',
  'In welk jaar vond de grote watersnoodramp plaats?|1953|1916|1932|1975',
  'Wat is het hoogste punt van Europees Nederland?|de Vaalserberg|de Utrechtse Heuvelrug|de Sint-Pietersberg|de Hondsrug',
  'Hoe heet land dat is drooggelegd en omdijkt?|een polder|een kwelder|een wad|een duin',
  'Welke provincie bestaat helemaal uit ingepolderd land?|Flevoland|Zeeland|Drenthe|Utrecht',
  'Hoe heten de eilanden in het noorden van Nederland?|de Waddeneilanden|de Zeeuwse eilanden|de Zuiderzee-eilanden|de Deltaeilanden',
  'Welke zee ligt tussen de Waddeneilanden en het vasteland?|de Waddenzee|de Noordzee|het IJsselmeer|de Oosterschelde',
  'Wat is de grootste haven van Nederland?|de haven van Rotterdam|de haven van Amsterdam|de haven van Vlissingen|de haven van Delfzijl',
  'Hoe heet de grootste luchthaven van Nederland?|Schiphol|Eindhoven Airport|Rotterdam The Hague Airport|Groningen Airport Eelde',
  'Welke bodemsoort vind je vooral in het westen van Nederland?|klei en veen|zand en grind|loss|krijt',
  'Waar in Nederland vind je loss in de bodem?|in Zuid-Limburg|op de Veluwe|in Zeeland|in Groningen',
  'Wat beschermt de kust tegen de zee, naast dijken?|duinen|heuvels|bossen|polders',
  'Welk van deze gebieden ligt grotendeels onder zeeniveau?|de polders in de Randstad|de Veluwe|de Hondsrug|het Drents Plateau',
  'Welke vier grote steden vormen samen de Randstad?|Amsterdam, Rotterdam, Den Haag en Utrecht|Amsterdam, Groningen, Arnhem en Breda|Rotterdam, Eindhoven, Zwolle en Assen|Utrecht, Maastricht, Leeuwarden en Almere',
  'Welk natuurgebied op de Veluwe is een groot nationaal park?|De Hoge Veluwe|de Biesbosch|de Oostvaardersplassen|het Naardermeer',
  'Waar wordt in Nederland aardgas gewonnen?|in Groningen|in Zeeland|op de Veluwe|in Limburg',
  'Hoe heet de zee ten westen van Nederland?|de Noordzee|de Oostzee|de Middellandse Zee|het Kanaal',
  'Welk land ligt ten zuiden van Nederland?|Belgie|Duitsland|Denemarken|Frankrijk',
  'Welk land ligt ten oosten van Nederland?|Duitsland|Belgie|Polen|Luxemburg',
  'Wat is een kwelder?|land dat bij vloed onderloopt|een droge zandvlakte|een diep kanaal|een kunstmatig eiland',
  'Hoe noem je het gebied waar een rivier in zee uitmondt?|de monding|de bron|de bedding|de oever',
  'Waar ontspringt de Rijn?|in Zwitserland|in Frankrijk|in Belgie|in Denemarken',
  'Wat betekent het als een gebied onder NAP ligt?|het ligt lager dan de zeespiegel|het ligt in het noorden|het is bebost|het is een natuurgebied',
];

/// `vraag|antwoord|fout|fout|fout`
const _weerFeiten = [
  'Uit welke richting komt de wind in Nederland het vaakst?|uit het zuidwesten|uit het noorden|uit het oosten|uit het zuidoosten',
  'Waarmee meet je de temperatuur?|met een thermometer|met een barometer|met een regenmeter|met een windvaan',
  'Waarmee meet je de luchtdruk?|met een barometer|met een thermometer|met een windmeter|met een hygrometer',
  'Waarmee meet je hoeveel regen er valt?|met een regenmeter|met een barometer|met een thermometer|met een kompas',
  'Wat laat een windvaan zien?|uit welke richting de wind komt|hoe hard het waait|hoe warm het is|hoeveel regen er valt',
  'Wat betekent een lagedrukgebied meestal?|wolken en regen|zon en droogte|vorst|mist zonder wind',
  'Wat betekent een hogedrukgebied meestal?|droog en rustig weer|storm|veel regen|sneeuw',
  'Hoe heet neerslag die uit ijsbolletjes bestaat?|hagel|mist|dauw|rijp',
  'Wat is mist eigenlijk?|een wolk vlak boven de grond|fijne regen|damp uit de bodem|rook',
  'Welk klimaat heeft Nederland?|een zeeklimaat|een landklimaat|een woestijnklimaat|een tropisch klimaat',
  'Wat is typisch voor een zeeklimaat?|zachte winters en koele zomers|hele koude winters en hete zomers|nooit neerslag|altijd storm',
  'Welk klimaat heeft het gebied rond de evenaar?|een tropisch klimaat|een poolklimaat|een landklimaat|een middellandse-zeeklimaat',
  'Hoe heet de denkbeeldige lijn midden om de aarde?|de evenaar|de meridiaan|de poolcirkel|de keerkring',
  'Hoeveel graden is een hele cirkel op een windroos?|360 graden|180 graden|90 graden|270 graden',
  'Welke windrichting ligt tegenover het noorden?|het zuiden|het oosten|het westen|het noordoosten',
  'Welke windrichting ligt tussen noord en oost in?|noordoost|noordwest|zuidoost|zuidwest',
  'Waar komt de zon op?|in het oosten|in het westen|in het noorden|in het zuiden',
  'Waar gaat de zon onder?|in het westen|in het oosten|in het zuiden|in het noorden',
  'Welke richting wijst het gemarkeerde uiteinde van een kompasnaald aan?|het noorden|het zuiden|de zon|de wind',
  'Hoe heet de kaart waarop het weer van morgen staat?|een weerkaart|een hoogtekaart|een stroomkaart|een bevolkingskaart',
  'Wat betekent de schaal 1 : 100.000 op een kaart?|1 cm op de kaart is 1 km in het echt|1 cm is 100 m|1 cm is 10 km|1 cm is 100 km',
  'Wat laat een hoogtekaart zien?|hoe hoog het land ligt|waar mensen wonen|welke wegen er zijn|hoe warm het is',
  'Hoe heet de lijn op een kaart die plaatsen met dezelfde hoogte verbindt?|een hoogtelijn|een breedtelijn|een lengtelijn|een isotherm',
  'Waarom is het op een berg kouder dan in het dal?|hoe hoger je komt, hoe dunner en kouder de lucht|omdat er meer wind staat|omdat de zon er niet komt|omdat er sneeuw ligt',
  'Wat gebeurt er met water dat verdampt?|het stijgt op en vormt wolken|het zakt de bodem in|het bevriest meteen|het verdwijnt voorgoed',
  'Hoe heet de kringloop van water op aarde?|de waterkringloop|de zeestroom|het getij|de verdamping',
  'Wat is eb en vloed?|het stijgen en dalen van de zee|het waaien van de wind|het smelten van ijs|het stromen van een rivier',
  'Wat veroorzaakt eb en vloed vooral?|de aantrekkingskracht van de maan|de wind|de regen|de zeestromen',
  'In welk seizoen staat de zon in Nederland het hoogst?|in de zomer|in de winter|in de herfst|in de lente',
  'Waarom is het in de winter kouder?|de zon staat lager en schijnt korter|de aarde staat verder van de zon|er is minder lucht|de wind draait om',
];

const _steden = [
  'Groningen',
  'Utrecht',
  'Maastricht',
  'Vlissingen',
  'Enschede',
];

/// The generated part of the aardrijkskunde bank.
List<QuizQuestion> buildAardrijkskundeExtra() {
  final g = QuizGen('gak', seed: 20260911);

  // --- Nederland: provincies -------------------------------------------------
  final prov = rows(_provincies);
  final provNamen = [for (final p in prov) p[0]];
  final provHoofd = [for (final p in prov) p[1]];
  for (final p in prov) {
    g.add(
      topic: _nederland,
      prompt: 'Wat is de hoofdstad van de provincie ${p[0]}?',
      answer: p[1],
      wrong: g.others(provHoofd, p[1]),
    );
    g.add(
      topic: _nederland,
      prompt: 'Van welke provincie is ${p[1]} de hoofdstad?',
      answer: p[0],
      wrong: g.others(provNamen, p[0]),
    );
  }

  for (final p in rows(_plaatsen)) {
    g.add(
      topic: _nederland,
      prompt: 'In welke provincie ligt ${p[0]}?',
      answer: p[1],
      wrong: g.others(provNamen, p[1]),
    );
  }

  for (final f in rows(_nederlandFeiten)) {
    g.add(topic: _nederland, prompt: f[0], answer: f[1], wrong: f.sublist(2));
  }

  // --- Europa ----------------------------------------------------------------
  final eu = rows(_europeseLanden);
  final euLanden = [for (final e in eu) e[0]];
  final euHoofd = [for (final e in eu) e[1]];
  const euDelen = ['West-Europa', 'Zuid-Europa', 'Noord-Europa', 'Oost-Europa'];
  for (final e in eu) {
    g.add(
      topic: _europa,
      prompt: 'Wat is de hoofdstad van ${e[0]}?',
      answer: e[1],
      wrong: g.others(euHoofd, e[1]),
    );
    g.add(
      topic: _europa,
      prompt: 'Van welk land is ${e[1]} de hoofdstad?',
      answer: e[0],
      wrong: g.others(euLanden, e[0]),
    );
    g.add(
      topic: _europa,
      prompt: 'In welk deel van Europa ligt ${e[0]}?',
      answer: e[2],
      wrong: euDelen,
    );
  }

  // --- De wereld -------------------------------------------------------------
  final wereld = rows(_wereldLanden);
  final wLanden = [for (final w in wereld) w[0]];
  final wHoofd = [for (final w in wereld) w[1]];
  for (final w in wereld) {
    g.add(
      topic: _wereld,
      prompt: 'Wat is de hoofdstad van ${w[0]}?',
      answer: w[1],
      wrong: g.others(wHoofd, w[1]),
    );
    g.add(
      topic: _wereld,
      prompt: 'In welk werelddeel ligt ${w[0]}?',
      answer: w[2],
      wrong: g.others(_werelddelen, w[2]),
    );
    g.add(
      topic: _wereld,
      prompt: 'In welk land ligt de stad ${w[1]}?',
      answer: w[0],
      wrong: g.others(wLanden, w[0]),
    );
  }

  for (final f in rows(_weerFeiten)) {
    g.add(topic: _wereld, prompt: f[0], answer: f[1], wrong: f.sublist(2));
  }

  // --- Weertabellen ----------------------------------------------------------
  for (var i = 0; i < 24; i++) {
    final temps = [for (final _ in _steden) g.between(-4, 29)];
    final tabel = [
      for (var k = 0; k < _steden.length; k++)
        '${_steden[k].padRight(12)} ${temps[k]} °C',
    ].join('\n');
    final soort = g.between(0, 2);
    final hoog = temps.reduce((a, b) => a > b ? a : b);
    final laag = temps.reduce((a, b) => a < b ? a : b);
    if (hoog == laag) continue;
    if (soort == 0) {
      if (temps.where((t) => t == hoog).length != 1) continue;
      g.add(
        topic: _wereld,
        passage: 'De temperatuur om 14:00 uur:\n$tabel',
        prompt: 'In welke stad was het het warmst?',
        answer: _steden[temps.indexOf(hoog)],
        wrong: g.others(_steden, _steden[temps.indexOf(hoog)]),
        why: 'Daar was het $hoog °C.',
      );
    } else if (soort == 1) {
      if (temps.where((t) => t == laag).length != 1) continue;
      g.add(
        topic: _wereld,
        passage: 'De temperatuur om 14:00 uur:\n$tabel',
        prompt: 'In welke stad was het het koudst?',
        answer: _steden[temps.indexOf(laag)],
        wrong: g.others(_steden, _steden[temps.indexOf(laag)]),
        why: 'Daar was het $laag °C.',
      );
    } else {
      g.add(
        topic: _wereld,
        passage: 'De temperatuur om 14:00 uur:\n$tabel',
        prompt:
            'Hoeveel graden verschil zit er tussen de warmste en de '
            'koudste stad?',
        answer: '${hoog - laag} graden',
        wrong: [
          '${hoog + laag} graden',
          '$hoog graden',
          '${hoog - laag + 2} graden',
          '${(hoog - laag) ~/ 2} graden',
        ],
        why: '$hoog - ($laag) = ${hoog - laag}.',
      );
    }
  }

  // --- Tijdzones -------------------------------------------------------------
  const zones = [
    ('New York', -6),
    ('Los Angeles', -9),
    ('Paramaribo', -4),
    ('Moskou', 2),
    ('Tokio', 8),
    ('Peking', 7),
    ('Sydney', 9),
    ('Caïro', 1),
  ];
  for (final z in zones) {
    for (final uur in [12, 18]) {
      final daar = (uur + z.$2 + 24) % 24;
      g.add(
        topic: _wereld,
        prompt:
            'In Nederland is het $uur:00 uur. In ${z.$1} is het '
            '${z.$2 > 0 ? '${z.$2} uur later' : '${-z.$2} uur vroeger'}. '
            'Hoe laat is het daar?',
        answer: '$daar:00 uur',
        wrong: [
          '${(daar + 1) % 24}:00 uur',
          '${(daar - 1 + 24) % 24}:00 uur',
          '${(uur - z.$2 + 24) % 24}:00 uur',
          '$uur:00 uur',
        ],
        why: 'Reken met het tijdverschil dat in deze opgave is gegeven.',
      );
    }
  }

  return g.questions;
}
