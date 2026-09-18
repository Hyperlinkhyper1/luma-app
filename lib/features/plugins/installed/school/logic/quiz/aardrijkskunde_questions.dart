import '../quiz_bank.dart';

QuizQuestion _q(
  String id,
  String topic,
  String prompt,
  List<String> options,
  int answer, [
  String? why,
]) =>
    QuizQuestion(
      id: id,
      topic: topic,
      prompt: prompt,
      options: options,
      answerIndex: answer,
      explanation: why,
    );

const _nederland = 'Nederland';
const _europa = 'Europa';
const _wereld = 'De wereld en het weer';

/// Aardrijkskunde, extra oefening voor bovenbouw en brugklas; geen doorstroomtoetsvak.
final List<QuizQuestion> aardrijkskundeQuestions = [
  // --- Nederland ------------------------------------------------------------
  _q('ak-001', _nederland, 'Hoeveel provincies heeft Nederland?',
      ['10', '11', '12', '13'], 2),
  _q('ak-002', _nederland, 'Wat is de hoofdstad van Nederland?',
      ['Den Haag', 'Amsterdam', 'Rotterdam', 'Utrecht'], 1,
      'Den Haag is de regeringszetel, maar Amsterdam is de hoofdstad.'),
  _q('ak-003', _nederland, 'Wat is de hoofdstad van Friesland?',
      ['Groningen', 'Leeuwarden', 'Assen', 'Zwolle'], 1),
  _q('ak-004', _nederland, 'Wat is de hoofdstad van Overijssel?',
      ['Zwolle', 'Deventer', 'Enschede', 'Almelo'], 0),
  _q('ak-005', _nederland, 'Wat is de hoofdstad van Noord-Brabant?',
      ['Eindhoven', 'Breda', "'s-Hertogenbosch", 'Tilburg'], 2),
  _q('ak-006', _nederland, 'Wat is de hoofdstad van Limburg?',
      ['Venlo', 'Roermond', 'Maastricht', 'Heerlen'], 2),
  _q('ak-007', _nederland, 'Wat is de hoofdstad van Zeeland?',
      ['Vlissingen', 'Middelburg', 'Goes', 'Terneuzen'], 1),
  _q('ak-008', _nederland, 'Wat is de hoofdstad van Noord-Holland?',
      ['Amsterdam', 'Alkmaar', 'Haarlem', 'Hilversum'], 2),
  _q('ak-009', _nederland, 'Welke provincie is het jongst?',
      ['Flevoland', 'Drenthe', 'Utrecht', 'Zeeland'], 0,
      'Flevoland werd in 1986 een provincie, drooggelegd uit de Zuiderzee.'),
  _q('ak-010', _nederland, 'Wat is het hoogste punt van Europees Nederland?',
      [
        'de Utrechtse Heuvelrug',
        'de Vaalserberg',
        'de Veluwe',
        'de Sint-Pietersberg'
      ],
      1,
      'De Vaalserberg in Zuid-Limburg is ruim 320 meter hoog.'),
  _q('ak-011', _nederland, 'Welke twee landen grenzen aan Nederland?',
      [
        'Duitsland en Frankrijk',
        'België en Duitsland',
        'België en Luxemburg',
        'Duitsland en Denemarken'
      ],
      1),
  _q('ak-012', _nederland, 'Hoe heet de grootste haven van Nederland?',
      ['Amsterdam', 'Rotterdam', 'Vlissingen', 'Delfzijl'], 1),
  _q('ak-013', _nederland,
      'Waardoor veranderde de Zuiderzee in het IJsselmeer?',
      [
        'de Deltawerken',
        'de Afsluitdijk',
        'de Maeslantkering',
        'de Oosterscheldekering'
      ],
      1,
      'De Afsluitdijk werd in 1932 gesloten.'),
  _q('ak-014', _nederland, 'Welk eiland hoort NIET bij de Waddeneilanden?',
      ['Texel', 'Ameland', 'Goeree-Overflakkee', 'Terschelling'], 2,
      'Goeree-Overflakkee ligt in de Zuid-Hollandse delta.'),
  _q('ak-015', _nederland, 'Wat is een polder?',
      [
        'een drooggelegd stuk land omringd door dijken',
        'een hoge zandheuvel',
        'een natuurlijke rivierbedding',
        'een dorp aan zee'
      ],
      0),
  _q('ak-016', _nederland, 'Waar dient een gemaal voor?',
      [
        'het zuiveren van drinkwater',
        'het wegpompen van overtollig water',
        'het opwekken van stroom uit wind',
        'het tegenhouden van springvloed'
      ],
      1),
  _q('ak-017', _nederland, 'Welke waterweg verbindt Rotterdam met de Noordzee?',
      ['de IJssel', 'de Vecht', 'de Nieuwe Waterweg', 'het Noordzeekanaal'], 2),
  _q('ak-018', _nederland, 'Wat wordt bedoeld met de Randstad?',
      [
        'het gebied rond Amsterdam, Rotterdam, Den Haag en Utrecht',
        'de kuststrook van Zeeland',
        'de grens met Duitsland',
        'het noorden van Nederland'
      ],
      0),
  _q('ak-019', _nederland,
      'Welke drie rivieren vormen samen de Nederlandse delta?',
      [
        'Rijn, Maas en Schelde',
        'IJssel, Vecht en Eem',
        'Waal, Linge en Dommel',
        'Rijn, Donau en Elbe'
      ],
      0),
  _q('ak-020', _nederland, 'In welke provincie ligt luchthaven Schiphol?',
      ['Flevoland', 'Noord-Holland', 'Zuid-Holland', 'Utrecht'], 1),

  // --- Europa ---------------------------------------------------------------
  _q('ak-021', _europa, 'Wat is de hoofdstad van Frankrijk?',
      ['Lyon', 'Parijs', 'Marseille', 'Bordeaux'], 1),
  _q('ak-022', _europa, 'Wat is de hoofdstad van Duitsland?',
      ['München', 'Bonn', 'Berlijn', 'Hamburg'], 2),
  _q('ak-023', _europa, 'Wat is de hoofdstad van Spanje?',
      ['Barcelona', 'Madrid', 'Sevilla', 'Valencia'], 1),
  _q('ak-024', _europa, 'Wat is de hoofdstad van Italië?',
      ['Milaan', 'Napels', 'Rome', 'Turijn'], 2),
  _q('ak-025', _europa, 'Wat is de hoofdstad van Portugal?',
      ['Porto', 'Lissabon', 'Faro', 'Coimbra'], 1),
  _q('ak-026', _europa, 'Wat is de hoofdstad van Polen?',
      ['Krakau', 'Warschau', 'Gdansk', 'Praag'], 1),
  _q('ak-027', _europa, 'Wat is de hoofdstad van Noorwegen?',
      ['Oslo', 'Bergen', 'Stockholm', 'Helsinki'], 0),
  _q('ak-028', _europa, 'In welke Zwitserse stad zitten regering en parlement?',
      ['Zürich', 'Genève', 'Bern', 'Basel'], 2,
      'Bern is de bondsstad en de zetel van regering en parlement.'),
  _q('ak-029', _europa, 'Wat is de hoofdstad van Oostenrijk?',
      ['Salzburg', 'Wenen', 'Innsbruck', 'Graz'], 1),
  _q('ak-030', _europa, 'Wat is de hoofdstad van Griekenland?',
      ['Athene', 'Thessaloniki', 'Sparta', 'Korfoe'], 0),
  _q('ak-031', _europa, 'In welk land liggen de Alpen NIET?',
      ['Zwitserland', 'Oostenrijk', 'Denemarken', 'Italië'], 2,
      'Denemarken is vlak; het hoogste punt is nog geen 200 meter.'),
  _q('ak-032', _europa, 'Wat is de hoogste berg van de Alpen?',
      ['de Matterhorn', 'de Mont Blanc', 'de Zugspitze', 'de Grossglockner'],
      1),
  _q('ak-033', _europa, 'Welke rivier is de langste van Europa?',
      ['de Donau', 'de Rijn', 'de Wolga', 'de Seine'], 2),
  _q('ak-034', _europa, 'Door welke landen stroomt de Donau onder andere?',
      [
        'Frankrijk en Spanje',
        'Oostenrijk en Hongarije',
        'Noorwegen en Zweden',
        'Portugal en Italië'
      ],
      1),
  _q('ak-035', _europa, 'Welk land is qua oppervlakte het grootst van Europa?',
      ['Frankrijk', 'Duitsland', 'Rusland', 'Oekraïne'], 2),
  _q('ak-036', _europa, 'Welke landen worden samen Scandinavië genoemd?',
      [
        'Noorwegen, Zweden en Denemarken',
        'Nederland, België en Luxemburg',
        'Polen, Tsjechië en Slowakije',
        'Spanje, Portugal en Frankrijk'
      ],
      0),
  _q('ak-037', _europa,
      'Hoe heet de gemeenschappelijke munt van veel EU-landen?',
      ['de pond', 'de euro', 'de kroon', 'de frank'], 1),
  _q('ak-038', _europa, 'Welke zee ligt tussen Zuid-Europa en Noord-Afrika?',
      ['de Noordzee', 'de Oostzee', 'de Middellandse Zee', 'de Zwarte Zee'], 2),

  // --- De wereld en het weer -----------------------------------------------
  _q('ak-039', _wereld, 'Hoeveel werelddelen worden er meestal onderscheiden?',
      ['5', '6', '7', '8'], 2,
      'Europa, Azië, Afrika, Noord-Amerika, Zuid-Amerika, Oceanië en Antarctica.'),
  _q('ak-040', _wereld, 'Wat is de grootste oceaan ter wereld?',
      [
        'de Atlantische Oceaan',
        'de Stille Oceaan',
        'de Indische Oceaan',
        'de Noordelijke IJszee'
      ],
      1),
  _q('ak-041', _wereld, 'Wat is de hoogste berg ter wereld?',
      ['de K2', 'de Mount Everest', 'de Kilimanjaro', 'de Mont Blanc'], 1),
  _q('ak-042', _wereld,
      'Door welk land stroomt de Nijl naar de Middellandse Zee?',
      ['Egypte', 'Marokko', 'Kenia', 'Nigeria'], 0),
  _q('ak-043', _wereld, 'Hoe heet de grootste warme woestijn ter wereld?',
      ['de Gobi', 'de Sahara', 'de Kalahari', 'de Atacama'], 1),
  _q('ak-044', _wereld, 'Op welk continent ligt het Amazoneregenwoud?',
      ['Afrika', 'Azië', 'Zuid-Amerika', 'Oceanië'], 2),
  _q('ak-045', _wereld, 'Wat is de evenaar?',
      [
        'de denkbeeldige lijn midden om de aarde',
        'de lijn tussen dag en nacht',
        'de grens tussen twee tijdzones',
        'de as waar de aarde omheen draait'
      ],
      0),
  _q('ak-046', _wereld, 'Wat is het verschil tussen weer en klimaat?',
      [
        'Weer gaat over nu, klimaat over het gemiddelde over vele jaren',
        'Klimaat gaat over nu, weer over de toekomst',
        'Er is geen verschil',
        'Weer geldt voor de wereld, klimaat voor één plek'
      ],
      0),
  _q('ak-047', _wereld,
      'Uit welke richting komt de wind in Nederland het vaakst?',
      ['het noorden', 'het oosten', 'het zuidwesten', 'het zuidoosten'], 2,
      'Die zeewind zorgt voor het gematigde zeeklimaat.'),
  _q('ak-048', _wereld, 'Waarmee meet je de luchtdruk?',
      ['een thermometer', 'een barometer', 'een windmeter', 'een regenmeter'],
      1),
  _q('ak-049', _wereld, 'Waarmee wordt de kracht van de wind aangegeven?',
      [
        'in graden',
        'in millimeters',
        'in de schaal van Beaufort',
        'in hectopascal'
      ],
      2),
  _q('ak-050', _wereld, 'Wat is neerslag?',
      [
        'regen, sneeuw en hagel samen',
        'alleen regen',
        'de temperatuur na zonsondergang',
        'de hoeveelheid wolken'
      ],
      0),
  _q('ak-051', _wereld, 'Waar ligt de Noordpool?',
      [
        'op een dik pakket drijvend zee-ijs',
        'op een groot continent',
        'op het eiland Groenland',
        'in het midden van Canada'
      ],
      0,
      'De Zuidpool ligt wél op een continent: Antarctica.'),
  _q('ak-052', _wereld, 'Wat is een tijdzone?',
      [
        'een gebied waar dezelfde kloktijd geldt',
        'de tijd die een vliegtuig erover doet',
        'het verschil tussen zomer- en wintertijd',
        'de periode waarin het licht is'
      ],
      0),
  _q('ak-053', _wereld, 'Welk land heeft de meeste inwoners ter wereld?',
      ['China', 'India', 'de Verenigde Staten', 'Indonesië'], 1,
      'India is China rond 2023 voorbijgestreefd.'),
  _q('ak-054', _wereld, 'Wat betekent het als een gebied "dichtbevolkt" is?',
      [
        'er wonen veel mensen op een klein oppervlak',
        'er staan veel bomen',
        'er zijn veel steden gepland',
        'de huizen zijn er hoog'
      ],
      0),
  _q('ak-055', _wereld, 'Wat betekent de kleur bruin op een hoogtekaart?',
      ['diep water', 'laagland', 'hoger gelegen land', 'bebouwing'], 2,
      'Groen is laag, bruin is hoog, blauw is water.'),
];
