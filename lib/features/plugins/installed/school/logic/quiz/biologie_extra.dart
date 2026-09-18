import '../quiz_bank.dart';
import 'gen.dart';

const _lichaam = 'Het menselijk lichaam';
const _natuur = 'Planten en dieren';
const _techniek = 'Energie en techniek';

/// `orgaan|wat het doet`
const _organen = [
  'het hart|pompt bloed door je lichaam',
  'de longen|halen zuurstof uit de lucht',
  'de maag|maakt voedsel fijn met maagsap',
  'de dunne darm|neemt voedingsstoffen op in het bloed',
  'de dikke darm|haalt water uit de voedselresten',
  'de lever|maakt gal en ruimt afvalstoffen op',
  'de nieren|filteren afvalstoffen uit het bloed',
  'de blaas|slaat urine op',
  'de hersenen|sturen je lichaam aan en verwerken prikkels',
  'het ruggenmerg|verbindt de hersenen met de zenuwen',
  'de slokdarm|brengt voedsel van je mond naar je maag',
  'de luchtpijp|brengt lucht naar je longen',
  'het middenrif|helpt je in- en uitademen',
  'de huid|beschermt je lichaam en regelt de warmte',
  'het oog|zorgt dat je kunt zien',
  'het oor|zorgt dat je kunt horen en houdt je in evenwicht',
  'de neus|zorgt dat je kunt ruiken',
  'de tong|zorgt dat je kunt proeven',
  'de alvleesklier|maakt sap dat voedsel afbreekt',
  'de milt|ruimt oude bloedcellen op',
  'het skelet|geeft je lichaam stevigheid',
  'de spieren|zorgen dat je kunt bewegen',
  'de gewrichten|laten botten ten opzichte van elkaar bewegen',
  'de pezen|verbinden spieren met botten',
  'het bloed|vervoert zuurstof en voedingsstoffen',
  'de slagaders|vervoeren bloed van het hart af',
  'de aders|vervoeren bloed naar het hart toe',
  'de rode bloedcellen|vervoeren zuurstof',
  'de witte bloedcellen|ruimen ziektekiemen op',
  'de bloedplaatjes|zorgen dat een wondje stolt',
  'de zenuwen|geven prikkels door aan de hersenen',
  'de stembanden|maken geluid als je praat',
  'de kiezen|malen het voedsel fijn',
  'het speeksel|maakt voedsel glad en begint de vertering',
  'de schedel|beschermt je hersenen',
  'de ribben|beschermen je hart en longen',
  'de wervelkolom|houdt je rug rechtop',
  'het beenmerg|maakt nieuwe bloedcellen',
  'de zweetklieren|maken zweet om je af te koelen',
  'het gebit|bijt en kauwt je eten',
];

/// `dier|diergroep`
const _dieren = [
  'de hond|de zoogdieren',
  'de kat|de zoogdieren',
  'de koe|de zoogdieren',
  'het paard|de zoogdieren',
  'de olifant|de zoogdieren',
  'de vleermuis|de zoogdieren',
  'de dolfijn|de zoogdieren',
  'de walvis|de zoogdieren',
  'de muis|de zoogdieren',
  'de egel|de zoogdieren',
  'het konijn|de zoogdieren',
  'de mol|de zoogdieren',
  'de eekhoorn|de zoogdieren',
  'de zeehond|de zoogdieren',
  'de mus|de vogels',
  'de merel|de vogels',
  'de ooievaar|de vogels',
  'de pinguin|de vogels',
  'de uil|de vogels',
  'de meeuw|de vogels',
  'de kip|de vogels',
  'de struisvogel|de vogels',
  'de zwaan|de vogels',
  'de specht|de vogels',
  'de slang|de reptielen',
  'de hagedis|de reptielen',
  'de krokodil|de reptielen',
  'de schildpad|de reptielen',
  'de kameleon|de reptielen',
  'de leguaan|de reptielen',
  'de kikker|de amfibieen',
  'de pad|de amfibieen',
  'de salamander|de amfibieen',
  'de haring|de vissen',
  'de snoek|de vissen',
  'de haai|de vissen',
  'de zalm|de vissen',
  'de paling|de vissen',
  'de goudvis|de vissen',
  'de bij|de insecten',
  'de mier|de insecten',
  'de vlinder|de insecten',
  'de kever|de insecten',
  'de sprinkhaan|de insecten',
  'de libel|de insecten',
  'de mug|de insecten',
  'het lieveheersbeestje|de insecten',
  'de slak|de weekdieren',
  'de mossel|de weekdieren',
  'de inktvis|de weekdieren',
  'de spin|de spinachtigen',
  'de teek|de spinachtigen',
];

const _diergroepen = [
  'de zoogdieren',
  'de vogels',
  'de reptielen',
  'de amfibieen',
  'de vissen',
  'de insecten',
  'de weekdieren',
  'de spinachtigen',
];

/// `plantendeel|wat het doet`
const _plantendelen = [
  'de wortel|neemt water en voeding uit de grond op',
  'de stengel|houdt de plant rechtop en vervoert water',
  'het blad|maakt voedsel met behulp van zonlicht',
  'de bloem|zorgt voor de voortplanting',
  'de meeldraad|maakt stuifmeel',
  'de stamper|vangt het stuifmeel op',
  'het zaad|kan uitgroeien tot een nieuwe plant',
  'de vrucht|beschermt het zaad',
  'de nerven|vervoeren water door het blad',
  'de huidmondjes|laten lucht in en uit het blad',
  'de knop|is een blad of een bloem in wording',
  'de bast|beschermt de stam van een boom',
];

/// `begrip|betekenis`
const _technieklijst = [
  'een stroomkring|een gesloten rondje waarin stroom kan lopen',
  'een schakelaar|maakt of verbreekt de stroomkring',
  'een geleider|een materiaal waar stroom doorheen kan',
  'een isolator|een materiaal waar geen stroom doorheen kan',
  'een accu|slaat elektrische energie op en is oplaadbaar',
  'een dynamo|maakt stroom zodra hij ronddraait',
  'een generator|zet beweging om in elektriciteit',
  'een transformator|maakt de spanning hoger of lager',
  'de volt|de eenheid van spanning',
  'de ampere|de eenheid van stroomsterkte',
  'de watt|de eenheid van vermogen',
  'een zonnepaneel|maakt elektriciteit uit zonlicht',
  'een windmolen|maakt elektriciteit uit wind',
  'een waterkrachtcentrale|maakt elektriciteit uit stromend water',
  'een fossiele brandstof|brandstof uit resten van planten en dieren van lang geleden',
  'duurzame energie|energie die niet opraakt',
  'een hefboom|een stang waarmee je met minder kracht iets tilt',
  'een katrol|een wiel met een touw om iets omhoog te hijsen',
  'een tandwiel|een wiel met tanden dat kracht overbrengt',
  'een veer|slaat energie op door in te drukken of uit te rekken',
  'wrijving|de kracht die een beweging tegenwerkt',
  'de zwaartekracht|de kracht waarmee de aarde alles aantrekt',
  'een magneet|iets dat ijzer aantrekt',
  'smelten|van vast naar vloeibaar',
  'stollen|van vloeibaar naar vast',
  'verdampen|van vloeibaar naar gas',
  'condenseren|van gas naar vloeibaar',
  'een molecuul|het kleinste deeltje van een stof',
  'een mengsel|twee of meer stoffen door elkaar',
  'oplossen|een stof mengen met een vloeistof zodat je de losse deeltjes niet meer ziet',
  'filteren|vaste deeltjes uit een vloeistof halen',
  'een prototype|een eerste proefmodel van iets nieuws',
  'een ontwerp|een plan of tekening van wat je gaat maken',
  'een sensor|iets dat meet en dat doorgeeft',
  'een chip|een klein plaatje dat berekeningen doet',
  'een robot|een machine die zelf taken uitvoert',
  'programmeren|een machine stap voor stap opdrachten geven',
  'een algoritme|een vast stappenplan om iets op te lossen',
  'recyclen|van afval nieuwe grondstoffen maken',
  'een grondstof|het materiaal waarvan je iets maakt',
  'een constructie|de manier waarop iets in elkaar zit',
  'isolatie|een laag die de warmte binnenhoudt',
  'een zonnecollector|verwarmt water met zonlicht',
  'een warmtepomp|haalt warmte uit de lucht of uit de bodem',
  'een stekker|verbindt een apparaat met het stopcontact',
  'een zekering|onderbreekt de stroom als het te veel wordt',
  'een lens|buigt licht zodat je scherper ziet',
  'een spiegel|kaatst licht terug',
  'geluid|trillingen die je met je oren opvangt',
  'een trilling|een beweging heen en weer',
];

/// `materiaal|eigenschap`
const _materialen = [
  'glas|doorzichtig maar breekbaar',
  'ijzer|sterk, maar het gaat roesten',
  'aluminium|licht en het roest niet',
  'hout|licht, sterk en goed te bewerken',
  'plastic|licht en goedkoop, maar het vergaat nauwelijks',
  'rubber|elastisch en het geleidt geen stroom',
  'koper|geleidt stroom heel goed',
  'steen|hard en zwaar',
  'papier|licht en goed te recyclen',
  'beton|heel sterk als er op geduwd wordt',
  'wol|houdt warmte goed vast',
  'katoen|zacht en het neemt vocht op',
];

/// `voedingsstof|waar het voor dient|waar het in zit`
const _voeding = [
  'koolhydraten|geven je snel energie|brood, rijst en pasta',
  'eiwitten|zijn nodig om te groeien en te herstellen|vlees, bonen en eieren',
  'vetten|leveren energie en houden je warm|olie, noten en boter',
  'vitamines|houden je lichaam gezond|groente en fruit',
  'mineralen|zijn nodig voor je botten en je bloed|melk en groente',
  'calcium|maakt je botten en tanden sterk|melk en kaas',
  'ijzer|is nodig voor je rode bloedcellen|spinazie en vlees',
  'vezels|houden je darmen aan het werk|volkoren brood en groente',
  'water|vervoert stoffen en koelt je af|drinken, groente en fruit',
  'vitamine C|helpt tegen ziektes|sinaasappels en paprika',
  'vitamine D|helpt bij sterke botten|zonlicht en vette vis',
  'suiker|geeft heel snel energie, maar te veel is ongezond|snoep en frisdrank',
];

/// `vraag|antwoord|fout|fout|fout`
const _lichaamFeiten = [
  'Hoeveel botten heeft een volwassen mens ongeveer?|ongeveer 206|ongeveer 100|ongeveer 350|ongeveer 500',
  'Wat gebeurt er als je inademt?|je longen zetten uit en er stroomt lucht naar binnen|je longen krimpen|je hart stopt even|je maag zet uit',
  'Welk gas haal je uit de lucht als je ademt?|zuurstof|koolstofdioxide|stikstof|waterstof',
  'Van welk gas zit er meer in uitgeademde lucht dan in ingeademde lucht?|koolstofdioxide|zuurstof|helium|waterstof',
  'Waar begint de vertering van je eten?|in je mond|in je maag|in je dunne darm|in je lever',
  'Hoe vaak klopt een hart van een kind ongeveer per minuut in rust?|ongeveer 80 keer|ongeveer 20 keer|ongeveer 200 keer|ongeveer 400 keer',
  'Waarom ga je zweten als je sport?|om je lichaam af te koelen|om vet kwijt te raken|om spieren te maken|om zuurstof op te nemen',
  'Wat doet je immuunsysteem?|het verdedigt je tegen ziektekiemen|het verteert je eten|het pompt je bloed rond|het maakt botten aan',
  'Wat is een virus?|een heel klein ziekteverwekkertje dat cellen binnendringt|een soort bacterie|een gifstof|een schimmel',
  'Waarom krijg je een prik of vaccinatie?|zodat je lichaam antistoffen leert maken|om sterker te worden|om beter te slapen|om sneller te groeien',
  'Welk zintuig gebruik je voor evenwicht?|je oor|je oog|je huid|je tong',
  'Welk deel van je oog laat licht naar binnen?|de pupil|het netvlies|het hoornvlies alleen|de oogzenuw',
  'Wat gebeurt er in je longen met de zuurstof?|die gaat via kleine blaasjes het bloed in|die wordt verteerd|die gaat naar je maag|die wordt opgeslagen',
  'Hoe heten de kleine blaasjes in je longen?|longblaasjes|klieren|poriën|kamers',
  'Waarom moet je slapen?|je lichaam en hersenen herstellen zich dan|je groeit alleen dan|je hart rust dan uit|je hersenen staan dan uit',
  'Wat is een gewricht?|de plek waar twee botten kunnen bewegen|het uiteinde van een spier|een deel van je huid|een stuk kraakbeen in je oor',
  'Wat gebeurt er als een spier zich samentrekt?|hij wordt korter en dikker|hij wordt langer|hij wordt harder maar niet korter|er verandert niets',
  'Waarom werken spieren vaak in paren?|de een trekt, de ander trekt weer terug|ze zijn even sterk|ze delen dezelfde pees|ze zitten aan hetzelfde bot',
  'Waar worden nieuwe bloedcellen gemaakt?|in het beenmerg|in het hart|in de milt alleen|in de longen',
  'Wat doet de lever met schadelijke stoffen?|die breekt ze af|die slaat ze op|die stuurt ze naar de longen|die maakt ze sterker',
  'Waarom heb je vezels nodig?|je darmen blijven er goed van werken|je groeit ervan|je bloed wordt er dikker van|je botten worden er sterk van',
  'Hoeveel tanden en kiezen heeft een volwassene meestal?|32|20|24|40',
  'Wat beschermt je gebit tegen gaatjes?|het glazuur|het tandvlees|de wortel|het tandbeen',
  'Waarom is te veel suiker slecht voor je tanden?|bacteriën maken er zuur van dat het glazuur aantast|suiker kleurt je tanden|suiker maakt je tandvlees hard|suiker maakt je tanden scherp',
  'Waar zit het meeste water in je lichaam?|in je cellen|in je maag|in je blaas|in je botten',
  'Wat is de puberteit?|de periode waarin je lichaam volwassen wordt|de periode voor je geboorte|het eerste schooljaar|de tijd dat je tanden wisselen',
  'Wat doet de neus behalve ruiken?|die verwarmt en filtert de lucht die je inademt|die proeft mee|die maakt geluid|die pompt lucht rond',
  'Waarom heb je een skelet nodig?|het geeft steun en beschermt je organen|het maakt je warm|het verteert je eten|het maakt spieren aan',
  'Wat is een reflex?|een reactie die je lichaam zonder nadenken doet|een spier die verkrampt|een deel van je hersenen|een soort zenuw',
  'Welk orgaan stuurt een reflex vaak aan?|het ruggenmerg|de lever|de maag|het hart',
];

/// `vraag|antwoord|fout|fout|fout`
const _natuurFeiten = [
  'Wat hebben planten nodig om voedsel te maken?|zonlicht, water en koolstofdioxide|alleen water|alleen zonlicht|zuurstof en zand',
  'Hoe heet het proces waarbij planten voedsel maken?|fotosynthese|vertering|verdamping|bestuiving',
  'Welk gas geven planten af bij fotosynthese?|zuurstof|koolstofdioxide|stikstof|methaan',
  'Wat is bestuiving?|stuifmeel dat op de stamper terechtkomt|water dat de wortel opneemt|een zaadje dat ontkiemt|een blad dat afvalt',
  'Wie helpen planten het meest bij de bestuiving?|insecten zoals bijen|regenwormen|vogels alleen|slakken',
  'Wat is een zaadverspreiding door dieren?|dieren eten vruchten en poepen de zaden ergens anders uit|dieren drinken water|de wind blaast zaden weg|zaden drijven op water',
  'Wat staat er aan het begin van de voedselketen gras – konijn – vos?|een plant|een roofdier|een aaseter|een schimmel',
  'Hoe heet een dier dat alleen planten eet?|een planteneter|een vleeseter|een alleseter|een aaseter',
  'Hoe heet een dier dat zowel planten als vlees eet?|een alleseter|een planteneter|een vleeseter|een roofdier',
  'Wat doen schimmels en bacteriën in de natuur?|ze breken dode resten af|ze maken zuurstof|ze eten planten|ze maken zaden',
  'Wat is een ecosysteem?|alle planten en dieren in een gebied samen met hun omgeving|een groep dieren van één soort|een stuk bos|een voedselketen',
  'Wat gebeurt er als er te veel roofdieren zijn?|de prooidieren nemen af|de planten nemen af|er verandert niets|de roofdieren groeien harder',
  'Hoe overwintert een egel?|door een winterslaap te houden|door te vervellen|door naar het zuiden te zwemmen|door bladeren te verliezen',
  'Waarom trekken veel vogels in de herfst weg?|omdat er hier in de winter te weinig voedsel is|omdat het te licht wordt|omdat ze verharen|omdat ze gaan broeden',
  'Wat is camouflage?|een kleur of vorm waarmee een dier opgaat in zijn omgeving|het maken van een nest|een winterslaap|het wisselen van veren',
  'Hoe planten vissen zich meestal voort?|ze leggen eitjes in het water|ze krijgen levende jongen|ze maken een nest op het land|ze delen zich',
  'Wat is typisch voor zoogdieren?|ze zogen hun jongen met melk|ze leggen eieren|ze hebben schubben|ze zijn koudbloedig',
  'Wat is typisch voor amfibieën?|ze leven eerst in het water en later ook op het land|ze hebben veren|ze hebben acht poten|ze leven alleen in zout water',
  'Hoeveel poten heeft een insect?|zes|acht|vier|tien',
  'Hoeveel poten heeft een spin?|acht|zes|vier|twaalf',
  'Waarmee ademen vissen?|met kieuwen|met longen|door hun huid alleen|met blaasjes',
  'Wat is een gewervelde?|een dier met een ruggengraat|een dier met een schild|een dier zonder poten|een dier met vleugels',
  'Welke van deze dieren is ongewerveld?|de slak|de kikker|de haring|de mus',
  'Hoe heet de verandering van rups naar vlinder?|de gedaanteverwisseling|de winterslaap|de bestuiving|de vervelling',
  'Wat is een loofboom?|een boom met bladeren in plaats van naalden|een boom met naalden|een boom die altijd groen blijft|een boom zonder vruchten',
  'Welke boom is een naaldboom?|de den|de eik|de beuk|de berk',
  'Waaraan herken je de leeftijd van een boom?|aan de jaarringen|aan de hoogte|aan de bast|aan het aantal takken',
  'Wat is humus?|verteerde resten van planten en dieren in de grond|zand met klei|een soort mos|water in de bodem',
  'Waarom zijn regenwormen nuttig?|ze maken de grond los en luchtig|ze eten insecten|ze maken zuurstof|ze bestuiven bloemen',
  'Wat betekent het als een diersoort uitsterft?|er zijn geen dieren van die soort meer over|de soort verhuist|de soort verandert van kleur|de soort houdt winterslaap',
];

/// `vraag|antwoord|fout|fout|fout`
const _techniekFeiten = [
  'Wat heb je nodig om een lampje te laten branden?|een gesloten stroomkring met een spanningsbron|alleen een draad|alleen een batterij|twee lampjes',
  'Wat gebeurt er als je een schakelaar openzet?|de stroom stopt|de stroom wordt sterker|het lampje wordt feller|er verandert niets',
  'Welk materiaal geleidt stroom het best?|koper|hout|plastic|rubber',
  'Waarom zit er plastic om een elektriciteitsdraad?|plastic geleidt geen stroom en beschermt je|plastic maakt de draad sterker|plastic geleidt beter|plastic houdt de draad warm',
  'Wat gebeurt er in een serieschakeling als één lampje kapotgaat?|alle lampjes gaan uit|alleen dat lampje gaat uit|de andere worden feller|er verandert niets',
  'Wat is het voordeel van een parallelschakeling?|elk lampje werkt los van de andere|er is minder draad nodig|het is altijd feller|er is geen schakelaar nodig',
  'Welke energiebron raakt niet op?|windenergie|aardgas|steenkool|aardolie',
  'Wat is een nadeel van fossiele brandstoffen?|bij het verbranden komt CO2 vrij|ze zijn te licht|ze leveren te weinig energie|ze zijn niet te vervoeren',
  'Wat zet een zonnepaneel om?|zonlicht in elektriciteit|wind in warmte|water in stroom|warmte in licht',
  'Wat doet een dynamo op een fiets?|die maakt stroom terwijl het wiel draait|die remt de fiets af|die slaat stroom op|die meet de snelheid',
  'Welke energie heeft een bal die je omhoog houdt?|zwaarte-energie|warmte-energie|licht-energie|geluidsenergie',
  'Wat gebeurt er met energie als je op de rem trapt?|bewegingsenergie wordt warmte|energie verdwijnt|warmte wordt beweging|energie wordt licht',
  'Wat is een hefboom?|een stang die om een draaipunt beweegt|een wiel met een touw|een tandwiel|een veer',
  'Waarom is een driehoek een sterke vorm?|hij kan niet vervormen zonder te breken|hij is licht|hij heeft de minste zijden|hij is rond',
  'Waarom drijft een schip van staal?|het verplaatst genoeg water om te blijven drijven|staal is lichter dan water|het is hol en vol lucht zonder gewicht|het vaart te snel om te zinken',
  'Wat is wrijving?|de kracht die beweging tegenwerkt|de kracht van de aarde|de kracht van de wind|een soort energie',
  'Hoe kun je wrijving verkleinen?|door te smeren met olie|door harder te duwen|door meer gewicht toe te voegen|door ruwer materiaal te kiezen',
  'Wat trekt een magneet aan?|ijzer|hout|glas|aluminium',
  'Wat gebeurt er als je twee noordpolen van magneten bij elkaar houdt?|ze stoten elkaar af|ze trekken elkaar aan|er gebeurt niets|ze worden warm',
  'Bij welke temperatuur bevriest water?|bij 0 °C|bij 10 °C|bij -10 °C|bij 100 °C',
  'Bij welke temperatuur kookt water op zeeniveau?|bij 100 °C|bij 50 °C|bij 80 °C|bij 120 °C',
  'Wat gebeurt er met de meeste stoffen als ze warmer worden?|ze zetten uit|ze krimpen|ze verdwijnen|ze worden zwaarder',
  'Hoe gaat warmte door metaal?|door geleiding|door straling alleen|door stroming alleen|helemaal niet',
  'Hoe komt de warmte van de zon naar de aarde?|door straling|door geleiding|door stroming|via de wind',
  'Waarom is dubbel glas beter dan enkel glas?|de laag lucht ertussen isoleert|het is dikker en zwaarder|het laat meer licht door|het is goedkoper',
  'Wat is een grondstof?|het materiaal waarvan je iets maakt|een afgewerkt product|een soort energie|een gereedschap',
  'Waarom recyclen we afval?|zodat grondstoffen opnieuw gebruikt kunnen worden|omdat het mooier is|om ruimte te maken in de winkel|omdat het verplicht warmte geeft',
  'Wat doet een sensor in een apparaat?|die meet iets en geeft het door|die levert stroom|die maakt geluid|die slaat gegevens op',
  'Wat is een algoritme?|een stappenplan om een probleem op te lossen|een computerprogramma zonder fouten|een soort chip|een netwerkkabel',
  'Wat is de eerste stap van een ontwerpproces?|bedenken wat het probleem is|het product verkopen|het maken van het product|het testen',
];

/// `voedselketen` — links `eet` rechts.
const _ketens = [
  'gras|konijn|vos',
  'blad|rups|mees|sperwer',
  'algen|watervlo|stekelbaars|snoek',
  'graan|muis|uil',
  'bloem|bij|zwaluw',
  'zaad|mus|kat',
  'plankton|haring|zeehond',
  'eikel|eekhoorn|marter',
];

/// The generated part of the Natuur & techniek bank.
List<QuizQuestion> buildBiologieExtra() {
  final g = QuizGen('gnt', seed: 20260913);

  // --- Het lichaam -----------------------------------------------------------
  final org = rows(_organen);
  final orgNamen = [for (final o in org) o[0]];
  final orgFuncties = [for (final o in org) o[1]];
  for (final o in org) {
    g.add(
      topic: _lichaam,
      prompt: 'Wat doet ${o[0]}?',
      answer: o[1],
      wrong: g.others(orgFuncties, o[1]),
    );
    g.add(
      topic: _lichaam,
      prompt: 'Welk lichaamsdeel doet dit? "${o[1]}"',
      answer: o[0],
      wrong: g.others(orgNamen, o[0]),
    );
  }

  for (final f in rows(_lichaamFeiten)) {
    g.add(topic: _lichaam, prompt: f[0], answer: f[1], wrong: f.sublist(2));
  }

  final voeding = rows(_voeding);
  final voedingNamen = [for (final v in voeding) v[0]];
  for (final v in voeding) {
    g.add(
      topic: _lichaam,
      prompt: 'Waar heb je ${v[0]} voor nodig?',
      answer: v[1],
      wrong: g.others([for (final x in voeding) x[1]], v[1]),
    );
    g.add(
      topic: _lichaam,
      prompt: 'Waar zitten veel ${v[0]} in?',
      answer: v[2],
      wrong: g.others([for (final x in voeding) x[2]], v[2]),
    );
    g.add(
      topic: _lichaam,
      prompt: 'Welke voedingsstof zit vooral in ${v[2]}?',
      answer: v[0],
      wrong: g.others(voedingNamen, v[0]),
    );
  }

  // --- Planten en dieren -----------------------------------------------------
  final dieren = rows(_dieren);
  for (final d in dieren) {
    g.add(
      topic: _natuur,
      prompt: 'Bij welke diergroep hoort ${d[0]}?',
      answer: d[1],
      wrong: g.others(_diergroepen, d[1]),
      why: '${d[0][0].toUpperCase()}${d[0].substring(1)} hoort bij ${d[1]}.',
    );
  }

  for (final groep in _diergroepen) {
    final leden = [
      for (final d in dieren)
        if (d[1] == groep) d[0],
    ];
    final anderen = [
      for (final d in dieren)
        if (d[1] != groep) d[0],
    ];
    // One question per animal, each naming a different clue-mate, so no two
    // prompts come out the same.
    for (var i = 0; i < leden.length; i++) {
      final hint = leden[(i + 1) % leden.length];
      if (hint == leden[i]) continue;
      g.add(
        topic: _natuur,
        prompt: 'Welk dier hoort bij $groep, net als $hint?',
        answer: leden[i],
        wrong: g.others(anderen, leden[i]),
      );
    }
    if (leden.length >= 3) {
      final fout = g.oneOf(anderen);
      g.add(
        topic: _natuur,
        prompt: 'Drie van deze dieren horen bij $groep. Welk dier niet?',
        answer: fout,
        wrong: g.others(leden, fout),
      );
    }
  }

  final planten = rows(_plantendelen);
  for (final p in planten) {
    g.add(
      topic: _natuur,
      prompt: 'Wat doet ${p[0]} van een plant?',
      answer: p[1],
      wrong: g.others([for (final x in planten) x[1]], p[1]),
    );
    g.add(
      topic: _natuur,
      prompt: 'Welk deel van de plant doet dit? "${p[1]}"',
      answer: p[0],
      wrong: g.others([for (final x in planten) x[0]], p[0]),
    );
  }

  for (final f in rows(_natuurFeiten)) {
    g.add(topic: _natuur, prompt: f[0], answer: f[1], wrong: f.sublist(2));
  }

  for (final keten in rows(_ketens)) {
    final pijl = keten.join(' → ');
    for (var i = 1; i < keten.length; i++) {
      g.add(
        topic: _natuur,
        passage: 'Voedselketen: $pijl',
        prompt: 'Wat eet de ${keten[i]} in deze voedselketen?',
        answer: keten[i - 1],
        wrong: [
          if (i + 1 < keten.length) keten[i + 1],
          ...g.others([for (final k in rows(_ketens)) ...k], keten[i - 1]),
        ],
        why: 'De pijl wijst van het voedsel naar de eter.',
      );
    }
    g.add(
      topic: _natuur,
      passage: 'Voedselketen: $pijl',
      prompt: 'Wat staat er aan het begin van deze voedselketen?',
      answer: keten.first,
      wrong: [
        keten.last,
        keten[1],
        ...g.others([for (final k in rows(_ketens)) k.first], keten.first),
      ],
      why: 'Een voedselketen begint altijd bij een plant.',
    );
  }

  // --- Energie en techniek ---------------------------------------------------
  final tech = rows(_technieklijst);
  final techNamen = [for (final t in tech) t[0]];
  final techBetekenis = [for (final t in tech) t[1]];
  for (final t in tech) {
    g.add(
      topic: _techniek,
      prompt: 'Wat is ${t[0]}?',
      answer: t[1],
      wrong: g.others(techBetekenis, t[1]),
    );
    g.add(
      topic: _techniek,
      prompt: 'Welk woord hoort hierbij? "${t[1]}"',
      answer: t[0],
      wrong: g.others(techNamen, t[0]),
    );
  }

  final mat = rows(_materialen);
  for (final m in mat) {
    g.add(
      topic: _techniek,
      prompt: 'Wat is typisch voor ${m[0]}?',
      answer: m[1],
      wrong: g.others([for (final x in mat) x[1]], m[1]),
    );
    g.add(
      topic: _techniek,
      prompt: 'Welk materiaal is dit? "${m[1]}"',
      answer: m[0],
      wrong: g.others([for (final x in mat) x[0]], m[0]),
    );
  }

  for (final f in rows(_techniekFeiten)) {
    g.add(topic: _techniek, prompt: f[0], answer: f[1], wrong: f.sublist(2));
  }

  return g.questions;
}
