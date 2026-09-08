import '../quiz_bank.dart';

QuizQuestion _p(
  String id,
  String topic,
  String passage,
  String prompt,
  List<String> options,
  int answer, [
  String? why,
]) =>
    QuizQuestion(
      id: id,
      topic: topic,
      passage: passage,
      prompt: prompt,
      options: options,
      answerIndex: answer,
      explanation: why,
    );

const _begrijpen = 'Begrijpen en interpreteren';
const _samenvatten = 'Samenvatten';
const _woordenschat = 'Woordenschat';
const _opzoeken = 'Opzoeken';

const _bijen =
    'Bijen doen meer voor ons dan honing maken. Terwijl ze van bloem naar '
    'bloem vliegen, nemen ze stuifmeel mee, waardoor planten vrucht kunnen '
    'zetten. Zonder dat werk zouden veel appel- en perenbomen leeg blijven. '
    'Toch gaat het al jaren slecht met de bij: bloemenweiden verdwijnen en '
    'daarmee zijn voedsel. In steeds meer gemeenten worden bermen daarom nog '
    'maar twee keer per jaar gemaaid.';

const _schooltijd =
    'Sommige mensen vinden dat de schooldag later moet beginnen. Tieners '
    'komen nu eenmaal moeilijk uit bed, zeggen zij, en wie te weinig slaapt '
    'leert slechter. Anderen wijzen erop dat een latere start ook betekent '
    'dat je later thuis bent, waardoor er minder tijd overblijft voor sport '
    'en bijbaantjes. Wat de beste keuze is, hangt dus af van wat je het '
    'zwaarst laat wegen.';

const _verhuizing =
    "Ik keek nog één keer om naar het huis. De gordijnen hingen al scheef en "
    "in de tuin stond het gras hoog. Papa toeterde. 'Kom nou,' riep hij door "
    "het open raam. Ik stapte in en zei niets. Pas bij de snelweg merkte ik "
    "dat ik mijn sleutel nog in mijn zak had.";

const _brandalarm =
    'Gaat het brandalarm af, laat dan alles liggen. Loop rustig naar de '
    'dichtstbijzijnde nooduitgang en gebruik nooit de lift. Verzamel op het '
    'schoolplein bij het bord van je klas. Je leerkracht telt daar of '
    'iedereen er is. Ga pas naar binnen als de brandweer daar toestemming '
    'voor geeft.';

const _deltawerken =
    'Na de watersnoodramp van 1953 besloot Nederland dat zoiets nooit meer '
    'mocht gebeuren. In de jaren daarna verrezen de Deltawerken: een reeks '
    'dammen, sluizen en keringen in Zeeland en Zuid-Holland. De bekendste is '
    'de Oosterscheldekering, die alleen dichtgaat bij hoog water. Daardoor '
    'bleef het zoute water in de Oosterschelde, en dus ook de natuur die '
    'daarvan afhankelijk is.';

const _slaap =
    'Wie te weinig slaapt, merkt dat overdag. Je concentreert je slechter, '
    'je wordt sneller boos en je onthoudt minder van wat je leert. '
    'Onderzoekers raden kinderen van elf en twaalf jaar negen tot elf uur '
    'slaap per nacht aan. Schermen vlak voor het slapengaan maken inslapen '
    'lastiger, omdat het blauwe licht de hersenen wakker houdt.';

const _wedstrijd =
    'Nog twee minuten. Jamil zat op de bank en kneep in zijn shirt. Hij had '
    'het hele seizoen getraind voor dit moment, maar de coach keek geen '
    'enkele keer zijn kant op. Toen de scheidsrechter affloot, bleef hij nog '
    'even zitten voordat hij naar de kleedkamer liep.';

const _zwembad =
    'Tarieven zwembad De Golf\n'
    '· Kinderen t/m 11 jaar: € 4,50\n'
    '· Jongeren 12 t/m 17 jaar: € 6,00\n'
    '· Volwassenen: € 8,50\n'
    '· Gezinskaart (2 volwassenen + 2 kinderen): € 22,00\n'
    '· Op zondag geldt een toeslag van € 1,00 per persoon.';

const _inhoud =
    'Inhoud\n'
    '1. Vulkanen .......... 4\n'
    '2. Aardbevingen ...... 12\n'
    "3. Tsunami's ......... 19\n"
    '4. Orkanen ........... 25\n'
    '5. Overstromingen .... 31\n'
    'Register ............. 38';

const _bibliotheek =
    'Aantal bezoekers van de schoolbibliotheek per maand:\n'
    'september 120 · oktober 180 · november 210 · december 90 · januari 200 · '
    'februari 175';

const _uniform =
    'Tekst 1 — Een schooluniform scheelt gedoe. Niemand hoeft nog na te '
    'denken over wat hij aantrekt, en je ziet niet meteen wie dure kleren kan '
    'betalen.\n\n'
    'Tekst 2 — Kleding is een manier om te laten zien wie je bent. Een '
    'uniform haalt dat weg, en de pesterijen verschuiven gewoon naar schoenen '
    'en tassen.';

const _plasticsoep =
    'In de Stille Oceaan drijft een gebied vol plastic dat groter is dan '
    'Frankrijk. Het meeste afval komt niet van schepen, maar spoelt via '
    'rivieren de zee in. Grote stukken vallen na jaren zonlicht uiteen in '
    'minuscule deeltjes. Die deeltjes worden door vissen aangezien voor '
    'voedsel, en zo belanden ze uiteindelijk ook op ons bord.';

const _fiets =
    'De fiets zoals wij die kennen bestaat pas ruim honderd jaar. Het eerste '
    'model, de loopfiets uit 1817, had geen trappers: je zette je af met je '
    'voeten. Pas toen er een ketting werd toegevoegd, kon je harder dan een '
    'wandelaar. Vanaf 1900 werd de fiets betaalbaar voor gewone gezinnen, en '
    'in Nederland raakte hij daarna nooit meer uit de mode.';

const _woordenboek =
    'Een fragment uit het woordenboek:\n'
    'komkommer — komma — kompas — komst — konijn';

const _werkstuk =
    'Je maakt een werkstuk over hoe zonnepanelen elektriciteit maken.';

/// Begrijpend lezen, groep 8 / doorstroomtoets-niveau.
final List<QuizQuestion> lezenQuestions = [
  // --- Begrijpen en interpreteren ------------------------------------------
  _p('lz-001', _begrijpen, _bijen,
      'Waarom maaien gemeenten hun bermen nog maar twee keer per jaar?',
      [
        'Omdat maaien te duur is geworden',
        'Zodat er meer bloemen blijven staan voor bijen',
        'Omdat er te weinig maaimachines zijn',
        'Zodat er honing geoogst kan worden'
      ],
      1,
      'De tekst noemt het verdwijnen van bloemenweiden als het probleem.'),
  _p('lz-002', _begrijpen, _bijen,
      'Wat gebeurt er volgens de tekst als bijen verdwijnen?',
      [
        'Er komt minder honing in de winkel',
        'Veel fruitbomen dragen geen vruchten meer',
        'Bloemenweiden groeien harder',
        'Bermen moeten vaker gemaaid worden'
      ],
      1),
  _p('lz-003', _begrijpen, _schooltijd, 'Welke zin uit de tekst is een mening?',
      [
        'Tieners komen nu eenmaal moeilijk uit bed',
        'Een latere start betekent dat je later thuis bent',
        'Er blijft dan minder tijd over voor sport',
        'Een schooldag heeft een begintijd'
      ],
      0,
      'Dat is wat "sommige mensen" vinden, niet iets wat vaststaat.'),
  _p('lz-004', _begrijpen, _verhuizing,
      'Hoe voelt de ik-persoon zich waarschijnlijk?',
      [
        'Blij dat hij weggaat',
        'Verdrietig om het afscheid',
        'Boos op zijn vader',
        'Bang voor de reis'
      ],
      1,
      'Het omkijken, het zwijgen en de sleutel wijzen op moeite met loslaten.'),
  _p('lz-005', _begrijpen, _verhuizing,
      'Waarom is het veelzeggend dat hij zijn sleutel nog in zijn zak heeft?',
      [
        'Hij kan er nu niet meer in',
        'Het laat zien dat het afscheid nog niet af is',
        'Zijn sleutel is gestolen',
        'Hij moet terug om de deur te sluiten'
      ],
      1),
  _p('lz-006', _begrijpen, _brandalarm,
      'Wat mag je bij een brandalarm nooit gebruiken?',
      ['De nooduitgang', 'De trap', 'De lift', 'Het schoolplein'], 2),
  _p('lz-007', _begrijpen, _brandalarm, 'Wanneer mag je weer naar binnen?',
      [
        'Zodra het alarm stopt',
        'Als je leerkracht geteld heeft',
        'Als de brandweer toestemming geeft',
        'Na een kwartier wachten'
      ],
      2),
  _p('lz-008', _begrijpen, _deltawerken,
      'Waarom gaat de Oosterscheldekering niet altijd dicht?',
      [
        'Omdat hij dan te snel roest',
        'Om het zoute water en de natuur te behouden',
        'Omdat schepen er anders niet door kunnen',
        'Omdat hij pas in 1953 gebouwd is'
      ],
      1),
  _p('lz-009', _begrijpen, _slaap,
      'Waarom is een scherm vlak voor het slapen ongunstig?',
      [
        'Je vergeet er de tijd door',
        'Het blauwe licht houdt je hersenen wakker',
        'Je ogen worden er droog van',
        'Je slaapt er te lang door'
      ],
      1),
  _p('lz-010', _begrijpen, _wedstrijd, 'Wat is waarschijnlijk waar over Jamil?',
      [
        'Hij is blij dat de wedstrijd voorbij is',
        'Hij is teleurgesteld dat hij niet mocht spelen',
        'Hij heeft de winnende goal gemaakt',
        'Hij wil stoppen met voetbal'
      ],
      1,
      'Hij trainde het hele seizoen en kwam er toch niet in.'),
  _p('lz-011', _begrijpen, _uniform, 'Waarin verschillen tekst 1 en tekst 2?',
      [
        'Tekst 1 gaat over kleding, tekst 2 over pesten',
        'Tekst 1 ziet een uniform als oplossing, tekst 2 niet',
        'Tekst 1 is een verhaal, tekst 2 een instructie',
        'Beide teksten zijn tegen een uniform'
      ],
      1),
  _p('lz-012', _begrijpen, _uniform,
      'Welk bezwaar noemt tekst 2 tegen een schooluniform?',
      [
        'Uniformen zijn te duur',
        'Pesten verschuift naar schoenen en tassen',
        'Kinderen vinden uniformen lelijk',
        'Uniformen gaan snel kapot'
      ],
      1),
  _p('lz-013', _begrijpen, _plasticsoep,
      'Hoe komt het meeste plastic volgens de tekst in zee?',
      ['Via schepen', 'Via rivieren', 'Via de wind', 'Via vissers'], 1),
  _p('lz-014', _begrijpen, _plasticsoep,
      'Waarom belandt het plastic uiteindelijk ook op ons bord?',
      [
        'Omdat we vis eten die de deeltjes heeft binnengekregen',
        'Omdat plastic in drinkwater wordt gemengd',
        'Omdat borden van plastic gemaakt worden',
        'Omdat het plastic op stranden aanspoelt'
      ],
      0),
  _p('lz-015', _begrijpen, _fiets,
      'Waarom kon je met de loopfiets niet harder dan een wandelaar?',
      [
        'De wielen waren te klein',
        'Er zat nog geen ketting op',
        'De weg was te slecht',
        'Hij was te zwaar'
      ],
      1),
  _p('lz-016', _begrijpen, _fiets, 'Wat veranderde er vanaf 1900?',
      [
        'De fiets kreeg voor het eerst trappers',
        'De fiets werd betaalbaar voor gewone gezinnen',
        'De fiets werd verboden in de stad',
        'De fiets werd in Nederland uitgevonden'
      ],
      1),

  // --- Samenvatten ----------------------------------------------------------
  _p('lz-017', _samenvatten, _bijen, 'Wat is de hoofdgedachte van deze tekst?',
      [
        'Honing is een gezond product',
        'Bijen zijn onmisbaar voor ons voedsel, maar ze hebben het zwaar',
        'Gemeenten besparen geld door minder te maaien',
        'Appelbomen bloeien in het voorjaar'
      ],
      1),
  _p('lz-018', _samenvatten, _bijen,
      'Welke titel past het beste bij deze tekst?',
      [
        'Honing uit eigen tuin',
        'Zonder bij geen appel',
        'Maaien of niet maaien',
        'Het leven van een bijenkoningin'
      ],
      1),
  _p('lz-019', _samenvatten, _schooltijd, 'Wat is het doel van de schrijver?',
      [
        'De lezer overtuigen dat school later moet beginnen',
        'De lezer twee kanten van een discussie laten zien',
        'Uitleggen hoe je beter kunt slapen',
        'Een verhaal vertellen over een schooldag'
      ],
      1,
      'De schrijver geeft eerst het ene argument, dan het andere, en kiest niet.'),
  _p('lz-020', _samenvatten, _deltawerken,
      'Welke titel past het beste bij deze tekst?',
      [
        'De watersnood van 1953',
        'Nederland achter de dijken: de Deltawerken',
        'Zout water in Zeeland',
        'Zo bouw je een sluis'
      ],
      1),
  _p('lz-021', _samenvatten, _slaap, 'Wat is de hoofdgedachte van deze tekst?',
      [
        'Kinderen slapen te weinig door hun huiswerk',
        'Te weinig slaap heeft overdag duidelijke gevolgen',
        'Blauw licht is slecht voor je ogen',
        'Onderzoekers weten nog weinig over slaap'
      ],
      1),
  _p('lz-022', _samenvatten, _plasticsoep,
      'Welk kopje past het beste boven deze tekst?',
      [
        'Vissen in de Stille Oceaan',
        'Van rivier naar bord: de reis van plastic',
        'Frankrijk vanuit de lucht',
        'Zonlicht en zeewater'
      ],
      1),
  _p('lz-023', _samenvatten, _fiets, 'Hoe is deze tekst opgebouwd?',
      [
        'Als een opsomming van voordelen',
        'In tijdsvolgorde, van oud naar nieuw',
        'Als een vergelijking tussen twee landen',
        'Van gevolg naar oorzaak'
      ],
      1),
  _p('lz-024', _samenvatten, _brandalarm, 'Wat voor soort tekst is dit?',
      [
        'Een verhalende tekst',
        'Een instructieve tekst',
        'Een betogende tekst',
        'Een gedicht'
      ],
      1,
      'De tekst vertelt stap voor stap wat je moet doen.'),
  _p('lz-025', _samenvatten, _uniform,
      'Welke samenvatting past bij beide teksten samen?',
      [
        'Iedereen is het erover eens dat uniformen helpen',
        'Over schooluniformen bestaan goede argumenten voor én tegen',
        'Schooluniformen zijn in Nederland verplicht',
        'Kleding zegt niets over wie je bent'
      ],
      1),
  _p('lz-026', _samenvatten, _wedstrijd, 'Wat voor soort tekst is dit?',
      [
        'Een informatieve tekst',
        'Een verhalende tekst',
        'Een instructieve tekst',
        'Een betogende tekst'
      ],
      1),

  // --- Woordenschat ---------------------------------------------------------
  _p('lz-027', _woordenschat, _deltawerken,
      'Wat betekent "verrezen" in deze tekst?',
      ['verdwenen', 'werden gebouwd', 'werden bedacht', 'stortten in'], 1),
  _p('lz-028', _woordenschat, _plasticsoep,
      'Wat betekent "minuscule" in deze tekst?',
      ['heel klein', 'heel giftig', 'heel zwaar', 'heel oud'], 0),
  _p('lz-029', _woordenschat, _plasticsoep,
      'Wat betekent "uiteenvallen" in deze tekst?',
      [
        'in stukjes breken',
        'naar de bodem zakken',
        'oplossen in water',
        'aan elkaar plakken'
      ],
      0),
  _p('lz-030', _woordenschat, _schooltijd,
      'Wat betekent "het zwaarst laat wegen"?',
      [
        'wat de meeste kilo weegt',
        'wat je het belangrijkst vindt',
        'wat het langst duurt',
        'wat het minste kost'
      ],
      1),
  _p('lz-031', _woordenschat, _slaap,
      'Wat betekent "concentreren" in deze tekst?',
      [
        'je aandacht bij iets houden',
        'iets uit je hoofd leren',
        'sneller praten',
        'rustig ademhalen'
      ],
      0),
  _p('lz-032', _woordenschat, _fiets,
      'Wat betekent "nooit meer uit de mode raken"?',
      [
        'altijd populair blijven',
        'niet meer gemaakt worden',
        'steeds duurder worden',
        'alleen op zondag gebruikt worden'
      ],
      0),
  _p('lz-033', _woordenschat, _bijen,
      'Waar verwijst het woord "zijn" naar in "en daarmee zijn voedsel"?',
      ['de mens', 'de bij', 'de boom', 'de gemeente'], 1,
      'De hele zin gaat over wat de bij verliest.'),
  _p('lz-034', _woordenschat, _bijen,
      'Welk signaalwoord in de tekst kondigt een tegenstelling aan?',
      ['Terwijl', 'Toch', 'Daarom', 'Zonder'], 1),

  // --- Opzoeken -------------------------------------------------------------
  _p('lz-035', _opzoeken, _zwembad,
      'Wat betaalt een gezin van twee volwassenen en twee kinderen op zondag?',
      ['€ 22,00', '€ 23,00', '€ 26,00', '€ 30,00'], 2,
      'De gezinskaart kost € 22,00 plus vier keer € 1,00 toeslag.'),
  _p('lz-036', _opzoeken, _zwembad,
      'Wat betaalt een jongere van 14 op zaterdag?',
      ['€ 4,50', '€ 6,00', '€ 7,00', '€ 8,50'], 1),
  _p('lz-037', _opzoeken, _inhoud,
      'Op welke bladzijde begint het hoofdstuk over orkanen?',
      ['12', '19', '25', '31'], 2),
  _p('lz-038', _opzoeken, _inhoud,
      'In welk hoofdstuk zoek je informatie over aardbevingen?',
      ['hoofdstuk 1', 'hoofdstuk 2', 'hoofdstuk 3', 'het register'], 1),
  _p('lz-039', _opzoeken, _woordenboek,
      'Tussen welke twee woorden staat "kompas"?',
      [
        'komkommer en komma',
        'komma en komst',
        'komst en konijn',
        'konijn en komkommer'
      ],
      1,
      'Op alfabet komt komp ná komm en vóór koms.'),
  _p('lz-040', _opzoeken, _bibliotheek, 'In welke maand kwamen de minste bezoekers?',
      ['september', 'oktober', 'december', 'februari'], 2),
  _p('lz-041', _opzoeken, _bibliotheek,
      'Hoeveel bezoekers kwamen er in november meer dan in oktober?',
      ['20', '30', '40', '90'], 1, '210 − 180 = 30.'),
  _p('lz-042', _opzoeken, _werkstuk,
      'Welk zoekwoord kun je het beste gebruiken?',
      ['zon', 'panelen kopen', 'werking zonnepanelen', 'dak'], 2,
      'Dit zoekwoord is het meest precies en past bij je vraag.'),
];
