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

const _lichaam = 'Het menselijk lichaam';
const _natuur = 'Planten en dieren';
const _techniek = 'Energie en techniek';

/// Natuur & techniek, groep 8 / doorstroomtoets-niveau.
final List<QuizQuestion> biologieQuestions = [
  // --- Het menselijk lichaam ------------------------------------------------
  _q('nt-001', _lichaam, 'Wat is de belangrijkste taak van het hart?',
      [
        'bloed door het lichaam pompen',
        'zuurstof uit de lucht halen',
        'voedsel verteren',
        'afvalstoffen filteren'
      ],
      0),
  _q('nt-002', _lichaam, 'Wat gebeurt er in de longen?',
      [
        'zuurstof gaat het bloed in en koolstofdioxide eruit',
        'voedsel wordt afgebroken',
        'bloed wordt gefilterd',
        'water wordt opgenomen'
      ],
      0),
  _q('nt-003', _lichaam, 'Welke route legt voedsel af?',
      [
        'mond – slokdarm – maag – dunne darm – dikke darm',
        'mond – maag – slokdarm – dikke darm – dunne darm',
        'mond – luchtpijp – maag – darmen',
        'mond – maag – lever – longen'
      ],
      0),
  _q('nt-004', _lichaam, 'Waar wordt het meeste voedsel opgenomen in het bloed?',
      ['in de maag', 'in de dunne darm', 'in de dikke darm', 'in de slokdarm'], 1),
  _q('nt-005', _lichaam, 'Wat doen de nieren?',
      [
        'afvalstoffen uit het bloed filteren',
        'zuurstof aan het bloed toevoegen',
        'voedsel verteren',
        'hormonen opslaan'
      ],
      0),
  _q('nt-006', _lichaam, 'Hoeveel botten heeft een volwassen mens ongeveer?',
      ['106', '156', '206', '306'], 2,
      'Een baby heeft er meer; sommige botten groeien later aan elkaar.'),
  _q('nt-007', _lichaam, 'Waarmee zitten spieren aan botten vast?',
      ['met pezen', 'met kraakbeen', 'met zenuwen', 'met aderen'], 0),
  _q('nt-008', _lichaam, 'Wat is een gewricht?',
      [
        'de plek waar twee botten kunnen bewegen',
        'een spier in de arm',
        'een bloedvat in het been',
        'het uiteinde van een zenuw'
      ],
      0),
  _q('nt-009', _lichaam, 'Welke bloedcellen vervoeren zuurstof?',
      ['rode bloedcellen', 'witte bloedcellen', 'bloedplaatjes', 'plasma'], 0),
  _q('nt-010', _lichaam, 'Wat doen witte bloedcellen?',
      [
        'ziekteverwekkers opruimen',
        'zuurstof vervoeren',
        'wonden dichten',
        'voedsel opnemen'
      ],
      0),
  _q('nt-011', _lichaam, 'Welke tanden gebruik je om te malen?',
      ['snijtanden', 'hoektanden', 'kiezen', 'verstandskiezen alleen'], 2),
  _q('nt-012', _lichaam, 'Wat is het grootste orgaan van het menselijk lichaam?',
      ['de lever', 'de huid', 'de longen', 'de darmen'], 1),
  _q('nt-013', _lichaam, 'Hoeveel zintuigen heeft de mens traditioneel?',
      ['3', '4', '5', '7'], 2,
      'Zien, horen, ruiken, proeven en voelen.'),
  _q('nt-014', _lichaam, 'Welk orgaan stuurt de rest van het lichaam aan?',
      ['het hart', 'de hersenen', 'de lever', 'de maag'], 1),
  _q('nt-015', _lichaam, 'Wat vervoeren zenuwen?',
      ['signalen', 'bloed', 'zuurstof', 'voedsel'], 0),
  _q('nt-016', _lichaam, 'Waarom ga je sneller ademen als je rent?',
      [
        'je spieren hebben meer zuurstof nodig',
        'je longen worden groter',
        'je hart wordt kleiner',
        'je bloed wordt dunner'
      ],
      0),
  _q('nt-017', _lichaam, 'Waarvoor is calcium in je voeding vooral belangrijk?',
      ['sterke botten en tanden', 'een goede huid', 'scherp zicht', 'snelle spijsvertering'],
      0),
  _q('nt-018', _lichaam, 'Wat doet de lever onder andere?',
      [
        'schadelijke stoffen onschadelijk maken',
        'zuurstof opnemen',
        'urine maken',
        'bloed rondpompen'
      ],
      0),

  // --- Planten en dieren ----------------------------------------------------
  _q('nt-019', _natuur, 'Wat hebben planten nodig voor fotosynthese?',
      [
        'licht, water en koolstofdioxide',
        'licht, zuurstof en zand',
        'water, zuurstof en warmte',
        'alleen water en aarde'
      ],
      0),
  _q('nt-020', _natuur, 'Wat maakt een plant tijdens de fotosynthese?',
      ['suiker en zuurstof', 'water en zout', 'koolstofdioxide', 'stuifmeel'], 0),
  _q('nt-021', _natuur, 'Waarvoor dienen de wortels van een plant?',
      [
        'water en voedingsstoffen opnemen en de plant vasthouden',
        'zonlicht opvangen',
        'zaden verspreiden',
        'zuurstof afgeven'
      ],
      0),
  _q('nt-022', _natuur, 'Wat is bestuiving?',
      [
        'stuifmeel dat van de ene bloem op de andere terechtkomt',
        'water dat de wortels opnemen',
        'de bloem die zich sluit bij regen',
        'het afvallen van bladeren in de herfst'
      ],
      0),
  _q('nt-023', _natuur, 'Waarom verliezen loofbomen in de herfst hun blad?',
      [
        'om water te sparen in de winter',
        'omdat er te veel zon is',
        'om zaden te maken',
        'omdat insecten de bladeren opeten'
      ],
      0),
  _q('nt-024', _natuur, 'Hoeveel poten heeft een insect?',
      ['4', '6', '8', '10'], 1),
  _q('nt-025', _natuur, 'Waarom is een spin geen insect?',
      [
        'een spin heeft acht poten en twee lichaamsdelen',
        'een spin kan niet vliegen',
        'een spin leeft in huis',
        'een spin heeft geen ogen'
      ],
      0),
  _q('nt-026', _natuur, 'Welke dieren zijn zoogdieren?',
      [
        'dieren die hun jongen zogen met melk',
        'dieren die eieren leggen',
        'dieren met schubben',
        'dieren die in het water leven'
      ],
      0),
  _q('nt-027', _natuur, 'Is een walvis een vis of een zoogdier?',
      ['een vis', 'een zoogdier', 'een reptiel', 'een amfibie'], 1,
      'Een walvis heeft longen en zoogt zijn jongen.'),
  _q('nt-028', _natuur, 'Wat is het verschil tussen koudbloedig en warmbloedig?',
      [
        'warmbloedige dieren houden hun lichaamstemperatuur zelf op peil',
        'koudbloedige dieren leven alleen in koude gebieden',
        'warmbloedige dieren hebben altijd een vacht',
        'koudbloedige dieren slapen nooit'
      ],
      0),
  _q('nt-029', _natuur, 'Welke gedaanteverwisseling maakt een kikker door?',
      [
        'ei – kikkervisje – kikker',
        'ei – rups – pop – kikker',
        'kikkervisje – pop – kikker',
        'ei – larve – vis'
      ],
      0),
  _q('nt-030', _natuur, 'Welke stadia doorloopt een vlinder?',
      [
        'ei – rups – pop – vlinder',
        'ei – pop – rups – vlinder',
        'rups – ei – vlinder',
        'ei – larve – vlinder'
      ],
      0),
  _q('nt-031', _natuur, 'Wat is een herbivoor?',
      ['een planteneter', 'een vleeseter', 'een alleseter', 'een aaseter'], 0),
  _q('nt-032', _natuur, 'Wat staat aan het begin van elke voedselketen?',
      ['een plant', 'een roofdier', 'een schimmel', 'een insect'], 0,
      'Planten leggen zonne-energie vast; alle andere schakels leven daarvan.'),
  _q('nt-033', _natuur, 'Wat doen afbrekers, zoals schimmels en bacteriën?',
      [
        'dode resten omzetten in voedingsstoffen voor de bodem',
        'planten laten groeien met licht',
        'dieren beschermen tegen ziektes',
        'zuurstof maken'
      ],
      0),
  _q('nt-034', _natuur, 'Wat gebeurt er in de waterkringloop na verdamping?',
      [
        'de waterdamp condenseert tot wolken',
        'het water zakt direct in de grond',
        'het water bevriest in de lucht',
        'het water verdwijnt uit de kringloop'
      ],
      0),
  _q('nt-035', _natuur, 'Waarom is biodiversiteit belangrijk?',
      [
        'een gevarieerd ecosysteem is beter bestand tegen verstoring',
        'er zijn dan meer dieren om te bekijken',
        'er groeien dan grotere bomen',
        'het maakt de bodem droger'
      ],
      0),
  _q('nt-036', _natuur, 'Waaraan herken je een vogel?',
      [
        'aan veren en een snavel',
        'aan schubben en kieuwen',
        'aan haren en melk',
        'aan zes poten'
      ],
      0),
  _q('nt-037', _natuur, 'Wat is camouflage bij dieren?',
      [
        'kleuren of patronen waardoor een dier opgaat in zijn omgeving',
        'het nabootsen van een geluid',
        'de winterslaap van een dier',
        'het wisselen van vacht in de lente'
      ],
      0),

  // --- Energie en techniek --------------------------------------------------
  _q('nt-038', _techniek, 'Welke energiebron is NIET hernieuwbaar?',
      ['wind', 'zon', 'aardgas', 'water'], 2,
      'Aardgas is een fossiele brandstof: op is op.'),
  _q('nt-039', _techniek, 'Wat zetten zonnepanelen om?',
      [
        'zonlicht in elektriciteit',
        'zonlicht in warm water',
        'wind in elektriciteit',
        'warmte in beweging'
      ],
      0),
  _q('nt-040', _techniek, 'Wat is een stroomkring?',
      [
        'een gesloten pad waarlangs stroom kan lopen',
        'de plaats waar stroom wordt opgewekt',
        'een kabel zonder isolatie',
        'de meterkast in huis'
      ],
      0),
  _q('nt-041', _techniek, 'Wat gebeurt er als je een stroomkring onderbreekt?',
      [
        'de stroom stopt',
        'de stroom wordt sterker',
        'er ontstaat een magneet',
        'de spanning verdubbelt'
      ],
      0),
  _q('nt-042', _techniek, 'Welk materiaal is een goede geleider?',
      ['koper', 'rubber', 'glas', 'hout'], 0),
  _q('nt-043', _techniek, 'Welk materiaal is een isolator?',
      ['ijzer', 'aluminium', 'plastic', 'zilver'], 2),
  _q('nt-044', _techniek, 'Waarin wordt elektrische spanning gemeten?',
      ['in volt', 'in ampère', 'in watt', 'in joule'], 0),
  _q('nt-045', _techniek, 'Wat gebeurt er als je twee noordpolen van magneten bij elkaar houdt?',
      ['ze stoten elkaar af', 'ze trekken elkaar aan', 'er gebeurt niets', 'ze worden warm'],
      0),
  _q('nt-046', _techniek, 'Wat is zwaartekracht?',
      [
        'de kracht waarmee de aarde alles naar zich toe trekt',
        'de kracht van de wind',
        'de kracht waarmee magneten werken',
        'de kracht van stromend water'
      ],
      0),
  _q('nt-047', _techniek, 'Waarvoor gebruik je een hefboom?',
      [
        'om met minder kracht een zware last te verplaatsen',
        'om stroom op te wekken',
        'om water te zuiveren',
        'om warmte vast te houden'
      ],
      0),
  _q('nt-048', _techniek, 'Wat doet een katrol?',
      [
        'de richting van een kracht veranderen en tillen makkelijker maken',
        'stroom omzetten in licht',
        'wrijving vergroten',
        'geluid versterken'
      ],
      0),
  _q('nt-049', _techniek, 'Wat gebeurt er met twee tandwielen die in elkaar grijpen?',
      [
        'ze draaien de andere kant op',
        'ze draaien dezelfde kant op',
        'ze stoppen elkaar',
        'ze gaan even snel als er verschillende maten zijn'
      ],
      0),
  _q('nt-050', _techniek, 'Bij welke temperatuur kookt water op zeeniveau?',
      ['80 °C', '90 °C', '100 °C', '120 °C'], 2),
  _q('nt-051', _techniek, 'Hoe heet de overgang van vloeistof naar gas?',
      ['smelten', 'verdampen', 'condenseren', 'stollen'], 1),
  _q('nt-052', _techniek, 'Hoe heet de overgang van gas naar vloeistof?',
      ['condenseren', 'verdampen', 'smelten', 'sublimeren'], 0),
  _q('nt-053', _techniek, 'Waarom zie je bij onweer de bliksem eerder dan je de donder hoort?',
      [
        'licht gaat veel sneller dan geluid',
        'geluid ontstaat later dan licht',
        'de donder komt van een andere plek',
        'je ogen reageren sneller dan je oren'
      ],
      0),
  _q('nt-054', _techniek, 'Hoe ontstaat geluid?',
      ['door trillingen', 'door warmte', 'door licht', 'door magnetisme'], 0),
  _q('nt-055', _techniek, 'Wat doet wrijving?',
      [
        'het remt beweging af en maakt warmte',
        'het versnelt beweging',
        'het maakt voorwerpen lichter',
        'het wekt stroom op'
      ],
      0),
];
