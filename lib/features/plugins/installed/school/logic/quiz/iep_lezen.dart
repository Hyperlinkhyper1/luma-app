import 'dart:math';

import '../quiz_bank.dart';

const _begrijpen = 'Begrijpen en interpreteren';
const _samenvatten = 'Samenvatten';
const _woorden = 'Woordenschat';
const _zoeken = 'Opzoeken';

/// Original texts with explicit paragraph references. No answer requires
/// prior knowledge of the subject of a text.
List<QuizQuestion> buildIepLezen() {
  final out = <QuizQuestion>[];
  final random = Random(8122026);
  void block(
    String id,
    String text,
    List<(String, String, String, List<String>, String)> questions,
  ) {
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final options = [q.$3, ...q.$4]..shuffle(random);
      out.add(
        QuizQuestion(
          id: 'iep-l-$id-$i',
          topic: q.$1,
          passage: text,
          prompt: q.$2,
          options: options,
          answerIndex: options.indexOf(q.$3),
          explanation: q.$5,
        ),
      );
    }
  }

  block(
    'bieb',
    '''Een bibliotheek op wielen

1. Op woensdag stopt er een blauwe bus bij het dorpsplein. Er zitten geen gewone passagiers in. Achter de ramen staan boekenkasten. Sinds de kleine bibliotheek in het dorp gesloten is, komt deze boekenbus iedere week langs.

2. Bezoeker Noor vindt het handig dat ze weer dichtbij boeken kan lenen. Toch mist ze iets: in de oude bibliotheek kon ze na school rustig zitten lezen. In de bus is daar nauwelijks ruimte voor. De bibliothecaris begrijpt dat. Zij overlegt met het buurthuis of bezoekers daar een leeshoek kunnen krijgen.

3. Niet elk boek past in de bus. Via de website kunnen leden een boek aanvragen. Als het op voorraad is, ligt het de volgende woensdag klaar. Een aanvraag moet uiterlijk op maandag binnen zijn. Noor vraagt een boek over ruimtevaart aan. Ze hoeft daarvoor niet naar de grote bibliotheek in de stad.

4. De bus staat van 14.00 tot 16.00 uur op het plein. Tijdens schoolvakanties komt hij ook, behalve op officiële feestdagen. Op de website staan vier rubrieken: Openingstijden, Boeken aanvragen, Lid worden en Activiteiten.''',
    [
      (
        _begrijpen,
        'Waarom komt de boekenbus naar het dorp?',
        'De bibliotheek in het dorp is gesloten.',
        [
          'Er waren te veel boeken in de dorpsbibliotheek.',
          'De school heeft een bus besteld.',
          'Het buurthuis heeft geen bezoekers meer.',
        ],
        'Dat staat aan het einde van alinea 1.',
      ),
      (
        _begrijpen,
        'Wat vindt Noor een nadeel van de boekenbus?',
        'Er is weinig ruimte om rustig te lezen.',
        [
          'Je mag er geen boeken over ruimtevaart lenen.',
          'De bus komt niet in vakanties.',
          'Je moet voor ieder boek naar de stad.',
        ],
        'In alinea 2 staat dat Noor de leesplek mist.',
      ),
      (
        _samenvatten,
        'Welke samenvatting past het best bij de hele tekst?',
        'Een boekenbus vervangt de dorpsbibliotheek, maar biedt minder ruimte; boeken aanvragen kan wel.',
        [
          'Noor wil een boek over ruimtevaart lenen in de stad.',
          'Het buurthuis heeft al een grote leeszaal geopend.',
          'Een bibliothecaris wil de boekenbus tijdens vakanties sluiten.',
        ],
        'Deze samenvatting noemt de verandering, de beperking en de mogelijkheid om boeken aan te vragen.',
      ),
      (
        _samenvatten,
        'Wat doet de schrijver in alinea 3?',
        'Uitleggen hoe je een boek kunt aanvragen.',
        [
          'Vertellen waarom de bibliotheek sloot.',
          'Beschrijven hoe de bus eruitziet.',
          'De lezer overtuigen om naar het buurthuis te gaan.',
        ],
        'Alinea 3 beschrijft de aanvraag en geeft Noor als voorbeeld.',
      ),
      (
        _woorden,
        'Wat betekent nauwelijks in alinea 2?',
        'bijna niet',
        ['helemaal nooit', 'meer dan genoeg', 'alleen op woensdag'],
        'Er is bijna geen ruimte om in de bus te zitten lezen.',
      ),
      (
        _woorden,
        'Waarnaar verwijst daarvoor in de laatste zin van alinea 3?',
        'naar het lenen van het boek over ruimtevaart',
        [
          'naar het sluiten van de bibliotheek',
          'naar het inrichten van de leeshoek',
          'naar het rijden van de bus',
        ],
        'De zin ervoor gaat over het boek dat Noor aanvraagt.',
      ),
      (
        _zoeken,
        'Op welke dag moet een aanvraag uiterlijk binnen zijn?',
        'op maandag',
        ['op dinsdag', 'op woensdag', 'op vrijdag'],
        'Dit staat in alinea 3.',
      ),
      (
        _zoeken,
        'Je wilt weten of de bus op een feestdag komt. In welke rubriek zoek je het eerst?',
        'Openingstijden',
        ['Boeken aanvragen', 'Lid worden', 'Activiteiten'],
        'Die rubriek gaat over wanneer de bus open is.',
      ),
    ],
  );
  block(
    'tuin',
    '''Wie zorgt voor de schooltuin?

1. Groep 8 heeft radijs, bonen en sla in bakken op het schoolplein gezaaid. De leerlingen verzorgen de planten in tweetallen. Op een lijst staat wie er iedere dag aan de beurt is. Voor de zomervakantie ontstaat er een probleem: de school is zes weken dicht, maar de planten hebben dan ook verzorging nodig.

2. Yara stelt voor alle bakken bij haar thuis neer te zetten. Dat blijkt onpraktisch. De bakken zijn zwaar en haar balkon is te klein. Meester Joost stelt daarom voor hulp te vragen aan buurtbewoners. De leerlingen schrijven een brief waarin ze uitleggen wat er moet gebeuren.

3. Vier buren melden zich aan. Zij willen wel helpen, maar kunnen niet allemaal op dezelfde dagen. Samen maken ze een rooster. Op maandag en donderdag komt meneer Vos. Op dinsdag en vrijdag komt mevrouw De Wit. Op woensdag zorgt buurvrouw Sana voor de planten. Meneer De Groot neemt zaterdag en zondag voor zijn rekening.

4. In september hangen de leerlingen een kaart bij het tuinhek: “Dankzij onze buren heeft de schooltuin de vakantie overleefd!” Een deel van de oogst geven ze aan de helpers. Meester Joost wil de samenwerking volgend jaar voortzetten.''',
    [
      (
        _begrijpen,
        'Waarom vragen de leerlingen hulp aan buurtbewoners?',
        'De tuin heeft ook tijdens de schoolvakantie verzorging nodig.',
        [
          'De leerlingen willen geen tuin meer.',
          'De buren hebben de bakken gekocht.',
          'De planten mogen niet op school blijven.',
        ],
        'Het probleem uit alinea 1 is de verzorging tijdens de zes weken sluiting.',
      ),
      (
        _begrijpen,
        'Waarom gaat het plan van Yara niet door?',
        'De bakken zijn zwaar en haar balkon is te klein.',
        [
          'Haar ouders willen geen sla eten.',
          'De buren willen de tuin verplaatsen.',
          'Er groeien geen planten in de bakken.',
        ],
        'Beide redenen staan in alinea 2.',
      ),
      (
        _samenvatten,
        'Welke titel past ook goed bij de tekst?',
        'Buren helpen de schooltuin door de vakantie',
        [
          'Zo zaai je radijs',
          'Een groter balkon voor Yara',
          'Groep 8 stopt met tuinieren',
        ],
        'De hulp tijdens de vakantie is het hoofdonderwerp.',
      ),
      (
        _samenvatten,
        'Hoe is de tekst vooral opgebouwd?',
        'Er is een probleem, daarna een oplossing en tot slot een resultaat.',
        [
          'Er worden alleen verschillende groenten beschreven.',
          'Er worden twee meningen zonder oplossing vergeleken.',
          'Er staat een recept met stappen in.',
        ],
        'De vakantie is het probleem; het rooster lost dat op; in september volgt het resultaat.',
      ),
      (
        _woorden,
        'Wat betekent onpraktisch in alinea 2?',
        'niet handig om uit te voeren',
        ['te laat bedacht', 'erg goedkoop', 'helemaal verboden'],
        'Het verplaatsen is lastig door het gewicht en de kleine ruimte.',
      ),
      (
        _woorden,
        'Wat betekent neemt … voor zijn rekening in alinea 3?',
        'zorgt voor',
        [
          'betaalt geld voor',
          'schrijft een rekening voor',
          'vraagt toestemming voor',
        ],
        'Meneer De Groot verzorgt de tuin op zaterdag en zondag.',
      ),
      (
        _zoeken,
        'Wie verzorgt de planten op vrijdag?',
        'mevrouw De Wit',
        ['meneer Vos', 'buurvrouw Sana', 'meneer De Groot'],
        'Volgens het rooster komt mevrouw De Wit op dinsdag en vrijdag.',
      ),
      (
        _zoeken,
        'Waar hangt de bedankkaart?',
        'bij het tuinhek',
        ['in de klas', 'op het balkon van Yara', 'aan de boekenbus'],
        'Dat staat in alinea 4.',
      ),
    ],
  );
  block(
    'repareren',
    '''Een tweede kans voor spullen

1. Elke eerste zaterdag van de maand organiseert het buurthuis een reparatiemiddag. Vrijwilligers proberen kapotte spullen weer bruikbaar te maken. Een apparaat wordt eerst bekeken. Soms is een klein onderdeel losgeraakt. Niet alles kan worden gerepareerd: veiligheid gaat voor.

2. Bezoekers betalen geen arbeidskosten. Als er een nieuw onderdeel nodig is, vertellen de vrijwilligers vooraf wat dat kost. De eigenaar beslist dan of hij verder wil. Het is de bedoeling dat bezoekers meekijken. Zo leren zij iets over hun eigen spullen.

3. “Ik dacht dat mijn bureaulamp weg moest,” vertelt bezoeker Timo. “Maar alleen de schakelaar was kapot. Nu doet hij het weer.” Timo vond het interessant om te zien hoe de vrijwilliger de oorzaak zocht. Thuis gaat hij elektrische apparaten niet zelf openmaken; daarvoor heeft hij te weinig kennis.

4. Wie iets wil laten bekijken, meldt zich tussen 13.00 en 15.00 uur. Om 16.00 uur sluit het buurthuis. Per bezoeker wordt één voorwerp aangenomen. Voor grote apparaten, zoals wasmachines, is geen plaats. Kleding, klein speelgoed en kleine huishoudelijke apparaten zijn wel welkom.''',
    [
      (
        _begrijpen,
        'Waarom kijken bezoekers mee tijdens de reparatie?',
        'Dan leren ze iets over hun eigen spullen.',
        [
          'Dan hoeven vrijwilligers geen oorzaak te zoeken.',
          'Dan mogen ze meerdere spullen meenemen.',
          'Dan hoeven nieuwe onderdelen niet betaald te worden.',
        ],
        'Dit doel staat in alinea 2.',
      ),
      (
        _begrijpen,
        'Wat kun je uit alinea 3 afleiden over Timo?',
        'Hij vindt de reparatie leerzaam, maar kent zijn eigen grenzen.',
        [
          'Hij kan nu alle elektrische apparaten zelf repareren.',
          'Hij wilde zijn lamp niet laten bekijken.',
          'Hij vindt dat vrijwilligers te langzaam werken.',
        ],
        'Hij is geïnteresseerd, maar maakt thuis niets open zonder voldoende kennis.',
      ),
      (
        _samenvatten,
        'Wat is het belangrijkste doel van deze tekst?',
        'Informeren over de reparatiemiddag en hoe die werkt.',
        [
          'Uitleggen hoe je een schakelaar vervangt.',
          'Reclame maken voor nieuwe bureaulampen.',
          'Vertellen waarom alle apparaten onveilig zijn.',
        ],
        'De tekst beschrijft de activiteit, de werkwijze en praktische voorwaarden.',
      ),
      (
        _samenvatten,
        'Welke informatie hoort zeker in een korte samenvatting?',
        'Vrijwilligers onderzoeken en repareren spullen samen met bezoekers.',
        [
          'Timo heeft een bureaulamp.',
          'Het buurthuis sluit om 16.00 uur.',
          'Een schakelaar kan kapotgaan.',
        ],
        'Dit beschrijft de kern van de activiteit; de andere antwoorden zijn details.',
      ),
      (
        _woorden,
        'Wat betekent vooraf in alinea 2?',
        'voordat ze met de reparatie verdergaan',
        [
          'nadat alles gerepareerd is',
          'alleen tijdens de eerste zaterdag',
          'zonder het aan de eigenaar te vertellen',
        ],
        'De eigenaar moet eerst over de kosten kunnen beslissen.',
      ),
      (
        _woorden,
        'Waarnaar verwijst daarvoor in alinea 3?',
        'naar het zelf openmaken van elektrische apparaten',
        [
          'naar het bezoeken van het buurthuis',
          'naar het betalen van arbeidskosten',
          'naar het meenemen van één voorwerp',
        ],
        'Het woord verwijst terug naar de handeling in dezelfde zin.',
      ),
      (
        _zoeken,
        'Lotte komt om 15.30 uur een kapotte wekker aanmelden. Kan dat volgens de tekst?',
        'Nee, aanmelden kan tot 15.00 uur.',
        [
          'Ja, het buurthuis is tot 16.00 uur open.',
          'Ja, een wekker is klein.',
          'Nee, alleen kleding is welkom.',
        ],
        'De aanmeldtijd is korter dan de openingstijd.',
      ),
      (
        _zoeken,
        'Wat mag je volgens alinea 4 meenemen?',
        'een kapotte speelgoedauto',
        ['een wasmachine', 'drie kapotte lampen', 'een grote koelkast'],
        'Klein speelgoed mag; grote apparaten en meerdere voorwerpen niet.',
      ),
    ],
  );
  block(
    'museum',
    '''Een koffer vol verhalen

1. Het dorpsmuseum krijgt een oude koffer van mevrouw Van Dijk. Daarin zitten brieven, een treinkaartje en een foto van een gezin. Niemand in het museum weet meteen wie er op de foto staan. Vrijwilliger Emma besluit de herkomst te onderzoeken.

2. Op de achterkant van de foto staat “zomer 1932”. Op een envelop staat een adres in het dorp. Emma bekijkt daarom oude adresboeken. Ze vindt de naam van een familie die daar in 1932 woonde. Dat is een aanwijzing, maar nog geen bewijs dat dit de mensen op de foto zijn.

3. Het museum plaatst de foto in de dorpskrant. Een week later belt meneer Smit. Hij herkent zijn grootouders. Hij heeft thuis dezelfde foto, met alle namen erbij. De namen passen bij de familie uit het adresboek. Daardoor wordt Emma zekerder van haar conclusie.

4. Het museum maakt een kleine tentoonstelling. De foto komt naast de brieven en het treinkaartje te liggen. Bij ieder voorwerp staat wat bekend is en wat nog onzeker is. Emma wil niet dat bezoekers een vermoeden voor een feit aanzien. De tentoonstelling is van 4 juni tot en met 28 juli te zien, op woensdag, zaterdag en zondag van 13.00 tot 17.00 uur.''',
    [
      (
        _begrijpen,
        'Waarom bekijkt Emma oude adresboeken?',
        'Op een envelop staat een adres in het dorp.',
        [
          'In de krant staat al wie op de foto staan.',
          'Het treinkaartje noemt alle familienamen.',
          'Mevrouw Van Dijk werkt in het adresboekarchief.',
        ],
        'Het adres is de aanwijzing waarmee zij haar onderzoek begint.',
      ),
      (
        _begrijpen,
        'Waarom maakt de foto van meneer Smit de conclusie sterker?',
        'Op zijn exemplaar staan namen die passen bij het adresboek.',
        [
          'Zijn foto is nieuwer dan die van het museum.',
          'Hij wil de koffer kopen.',
          'Hij heeft de dorpskrant gelezen.',
        ],
        'Er komen nu twee verschillende aanwijzingen bij elkaar.',
      ),
      (
        _samenvatten,
        'Welke samenvatting past het best?',
        'Een vrijwilliger onderzoekt oude voorwerpen en laat zien wat zij wel en niet zeker weet.',
        [
          'Een bezoeker geeft het museum een nieuw adresboek.',
          'Een familie maakt in juli een treinreis naar het museum.',
          'Het museum organiseert een wedstrijd voor fotografen.',
        ],
        'Onderzoek en zorgvuldig omgaan met informatie vormen de kern.',
      ),
      (
        _samenvatten,
        'Waarom vertelt de schrijver in alinea 3 over het telefoontje?',
        'Om te laten zien hoe er nieuwe informatie bij het onderzoek komt.',
        [
          'Om uit te leggen hoe je een telefoon gebruikt.',
          'Om de openingstijden bekend te maken.',
          'Om te bewijzen dat alle krantenberichten kloppen.',
        ],
        'Meneer Smit levert een nieuwe bron voor het onderzoek.',
      ),
      (
        _woorden,
        'Wat betekent herkomst in alinea 1?',
        'waar iets vandaan komt',
        ['hoeveel iets kost', 'hoe zwaar iets is', 'wanneer iets kapotgaat'],
        'Emma wil weten bij wie de foto en de spullen hoorden.',
      ),
      (
        _woorden,
        'Wat betekent vermoeden in alinea 4?',
        'iets wat je denkt, maar nog niet zeker weet',
        [
          'iets wat je met zekerheid hebt vastgesteld',
          'een voorwerp uit een museum',
          'een adres dat niet meer bestaat',
        ],
        'Emma maakt verschil tussen een mogelijke verklaring en een vastgesteld feit.',
      ),
      (
        _zoeken,
        'Welk jaartal staat op de foto?',
        '1932',
        ['1923', '1933', '1934'],
        'Het jaartal staat in alinea 2.',
      ),
      (
        _zoeken,
        'Je wilt de tentoonstelling in juni om 14.00 uur bezoeken. Op welke dag kan dat?',
        'op woensdag',
        ['op maandag', 'op dinsdag', 'op vrijdag'],
        'Volgens alinea 4 is het museum op woensdag, zaterdag en zondag open.',
      ),
    ],
  );
  block(
    'uitstapje',
    '''Bericht over de excursie

Beste ouders en leerlingen,

1. Op donderdag gaat groep 8 naar het Watermuseum. Iedereen wordt om 8.15 uur op school verwacht. We controleren de namenlijst en vertrekken om 8.30 uur met de bus. De rondleiding begint om 9.30 uur. Daarna doen de leerlingen in kleine groepen proeven.

2. Neem een lunchpakket en een goed afsluitbare drinkfles mee. Het museum heeft geen plek waar onze groep eten kan kopen. De school zorgt voor fruit. Een regenjas is handig, want we lopen een deel van de route buiten. Waardevolle spullen blijven liever thuis.

3. We zijn naar verwachting om 14.45 uur terug op school. Dat tijdstip kan veranderen als het onderweg druk is. In dat geval stuurt de leerkracht een bericht via de schoolapp. Ouders hoeven het museum niet te bellen.

4. De kinderen mogen foto's van de proefopstellingen maken. Vraag eerst toestemming voordat je een ander herkenbaar fotografeert. In de zaal met historische tekeningen mag helemaal niet worden gefotografeerd. Let op de bordjes bij de ingang.

Met vriendelijke groet,
Meester Farid''',
    [
      (
        _begrijpen,
        'Waarom moeten leerlingen zelf een lunch meenemen?',
        'De groep kan in het museum geen eten kopen.',
        [
          'De school zorgt niet voor fruit.',
          'Er mag niets gedronken worden.',
          'De bus heeft geen bagageruimte.',
        ],
        'De reden staat in alinea 2.',
      ),
      (
        _begrijpen,
        'Wat moeten ouders doen om een veranderde terugkomsttijd te weten?',
        'Op een bericht in de schoolapp letten.',
        [
          'Het museum bellen.',
          'Om 8.30 uur bij de bus wachten.',
          'De bordjes bij de ingang lezen.',
        ],
        'Alinea 3 beschrijft hoe de leerkracht wijzigingen doorgeeft.',
      ),
      (
        _samenvatten,
        'Wat voor tekst is dit?',
        'een informatief bericht',
        [
          'een spannend verhaal',
          'een advertentie voor drinkflessen',
          'een verslag van een afgelopen excursie',
        ],
        'Het bericht geeft vooraf praktische informatie.',
      ),
      (
        _samenvatten,
        'Welk kopje past het best boven alinea 4?',
        'Regels voor fotograferen',
        [
          'Programma van de rondleiding',
          'De terugreis',
          'Wat neem je mee voor de lunch?',
        ],
        'Alle zinnen van alinea 4 gaan over fotograferen.',
      ),
      (
        _woorden,
        'Wat betekent naar verwachting in alinea 3?',
        'waarschijnlijk, maar niet met zekerheid',
        [
          'precies zoals afgesproken, zonder uitzondering',
          'veel later dan gepland',
          'alleen wanneer iedereen wacht',
        ],
        'De volgende zin zegt dat de tijd nog kan veranderen.',
      ),
      (
        _woorden,
        'Waarnaar verwijst dat geval in alinea 3?',
        'naar een veranderde terugkomsttijd door drukte',
        [
          'naar een lege drinkfles',
          'naar de start van de rondleiding',
          'naar het maken van een foto',
        ],
        'Het verwijst naar de situatie in de voorafgaande zin.',
      ),
      (
        _zoeken,
        'Hoe laat moeten de leerlingen op school zijn?',
        'om 8.15 uur',
        ['om 8.30 uur', 'om 9.30 uur', 'om 14.45 uur'],
        'Verzamelen is eerder dan het vertrek van de bus.',
      ),
      (
        _zoeken,
        'Waar mag je volgens het bericht geen foto’s maken?',
        'in de zaal met historische tekeningen',
        [
          'bij alle proefopstellingen',
          'op de hele buitenroute',
          'overal waar leerlingen zijn',
        ],
        'Voor die zaal geldt een volledig fotografieverbod.',
      ),
    ],
  );
  block(
    'proef',
    '''Welke beker houdt water warm?

1. De klas van juf Esra onderzoekt of een hoes een beker water langer warm houdt. Ze vullen drie gelijke bekers met evenveel warm water. Beker A krijgt geen hoes, beker B een vilten hoes en beker C een wollen hoes. Alle bekers staan naast elkaar op dezelfde tafel.

2. De leerlingen meten de temperatuur meteen na het vullen en twintig minuten later. Aan het begin is het water in elke beker 60 graden. Na twintig minuten is het water in beker A 38 graden, in beker B 45 graden en in beker C 49 graden.

3. “Wol houdt water altijd het warmst,” zegt Niels. Juf Esra vraagt of hij dat al zeker weet. De klas heeft maar één wollen hoes en één vilten hoes getest. Misschien maakt ook de dikte van de hoes verschil. De leerlingen besluiten de proef te herhalen met hoezen die even dik zijn.

4. Ze schrijven in hun verslag: “Bij deze proef bleef het water in de beker met de wollen hoes het warmst.” Die zin is voorzichtiger dan de uitspraak van Niels. Toch vertelt hij precies wat ze hebben gemeten.''',
    [
      (
        _begrijpen,
        'Waarom gebruiken de leerlingen gelijke bekers met evenveel water?',
        'Om de bekers eerlijk te kunnen vergelijken.',
        [
          'Om minder te hoeven meten.',
          'Omdat wol alleen bij kleine bekers werkt.',
          'Omdat alle hoezen dezelfde kleur hebben.',
        ],
        'Zo verschillen de bekers niet ook nog in grootte of hoeveelheid water.',
      ),
      (
        _begrijpen,
        'Waarom wil de klas een tweede proef doen?',
        'Om te onderzoeken of de dikte van de hoes invloed heeft.',
        [
          'Omdat het water aan het begin niet even warm was.',
          'Omdat beker A geen water bevatte.',
          'Omdat ze geen temperatuur hebben gemeten.',
        ],
        'In alinea 3 staat welke andere verklaring ze willen onderzoeken.',
      ),
      (
        _samenvatten,
        'Welke samenvatting past het best bij de tekst?',
        'De klas vergelijkt hoezen en formuleert een conclusie die past bij één proef.',
        [
          'De klas bewijst dat alle wollen hoezen altijd beter zijn.',
          'Niels leert hoe hij een wollen hoes breit.',
          'De juf verbiedt de leerlingen een proef te herhalen.',
        ],
        'Deze samenvatting maakt geen grotere claim dan de tekst.',
      ),
      (
        _samenvatten,
        'Wat laat de schrijver vooral zien met alinea 4?',
        'Dat je een conclusie niet sterker moet formuleren dan je onderzoek toelaat.',
        [
          'Dat leerlingen nooit iets zeker kunnen weten.',
          'Dat meten niet nodig is bij een proef.',
          'Dat een verslag altijd uit één zin bestaat.',
        ],
        'De uitspraak in het verslag beperkt zich tot de uitgevoerde proef.',
      ),
      (
        _woorden,
        'Wat betekent herhalen in alinea 3?',
        'nog een keer uitvoeren',
        [
          'voorgoed stoppen',
          'zonder meten uitvoeren',
          'aan iemand anders vertellen',
        ],
        'De klas wil opnieuw een proef doen.',
      ),
      (
        _woorden,
        'Waarnaar verwijst hij in de laatste zin?',
        'naar de zin in het verslag',
        ['naar Niels', 'naar beker A', 'naar de wollen hoes'],
        'De vorige zin noemt de voorzichtig geformuleerde zin.',
      ),
      (
        _zoeken,
        'Welke beker had na twintig minuten het warmste water?',
        'beker C',
        ['beker A', 'beker B'],
        '49 graden is hoger dan 45 en 38 graden.',
      ),
      (
        _zoeken,
        'Hoe warm was het water in alle bekers aan het begin?',
        '60 graden',
        ['38 graden', '45 graden', '49 graden'],
        'Dit staat in alinea 2.',
      ),
    ],
  );
  block(
    'podium',
    '''Achter het gordijn

1. “Nog vijf minuten,” fluistert de meester. Ravi kijkt naar het gordijn. Daarachter praten ouders en andere bezoekers door elkaar. Wekenlang heeft hij zijn tekst geoefend. Nu lijkt zijn eerste zin helemaal verdwenen. Hij vouwt het papiertje in zijn hand steeds kleiner.

2. Naast hem staat Bo, die de lampen bedient. “Gisteren kende je alles,” zegt ze. “Kijk straks naar de klok boven de deur als je niet naar de zaal durft te kijken.” Ravi knikt, maar zijn schouders blijven opgetrokken. Bo wacht even. Dan vraagt ze: “Hoe begint je verhaal ook alweer?” Ravi zegt de eerste zin zachtjes op. En daarna de tweede.

3. Om halfacht schuift het gordijn open. Ravi stapt naar voren. Hij kijkt eerst naar de klok, haalt adem en begint. Bij de grap in zijn verhaal lacht iemand op de eerste rij. Ravi kijkt even de zaal in. Zijn stem klinkt nu steviger.

4. Na afloop klapt iedereen. Achter het gordijn geeft Ravi het verfrommelde papiertje aan Bo. “Voor de zekerheid,” zegt hij lachend. Bo stopt het in haar zak. “Volgende keer mag je het weer lenen.”''',
    [
      (
        _begrijpen,
        'Hoe voelt Ravi zich aan het begin waarschijnlijk?',
        'zenuwachtig',
        ['verveeld', 'boos op Bo', 'teleurgesteld in de bezoekers'],
        'Hij vergeet zijn eerste zin en vouwt zijn papiertje steeds kleiner.',
      ),
      (
        _begrijpen,
        'Wat helpt Ravi in alinea 2 om zijn tekst terug te vinden?',
        'Bo vraagt hem hoe het verhaal begint.',
        [
          'De meester schuift het gordijn dicht.',
          'Zijn ouders lezen de tekst voor.',
          'Hij zet de lampen aan.',
        ],
        'Daarna zegt Ravi zijn eerste en tweede zin op.',
      ),
      (
        _samenvatten,
        'Welke titel past ook goed bij dit verhaal?',
        'Een spannend begin, een geslaagd optreden',
        ['De kapotte lampen', 'Een lege zaal', 'Bo vergeet haar tekst'],
        'De titel beschrijft de verandering van spanning naar een geslaagd optreden.',
      ),
      (
        _samenvatten,
        'Wat verandert er vooral in de loop van het verhaal?',
        'Ravi krijgt meer vertrouwen tijdens het optreden.',
        [
          'Bo besluit zelf het verhaal te vertellen.',
          'Het publiek verliest zijn belangstelling.',
          'De meester stelt de voorstelling uit.',
        ],
        'Zijn stem wordt steviger en na afloop lacht hij.',
      ),
      (
        _woorden,
        'Wat betekent verfrommelde in alinea 4?',
        'gekreukelde',
        ['onbeschreven', 'verloren', 'gekleurde'],
        'Ravi heeft het papier eerder steeds kleiner gevouwen.',
      ),
      (
        _woorden,
        'Wat bedoelt Ravi met Voor de zekerheid? Kies de uitleg die past bij het papiertje.',
        'Het papiertje kan hem steun geven als hij zijn tekst vergeet.',
        [
          'Het papiertje bewijst dat hij een kaartje heeft gekocht.',
          'Het papiertje beschermt de lampen.',
          'Het papiertje bepaalt hoe laat het gordijn opengaat.',
        ],
        'Ravi gebruikt het papier als hulpmiddel bij zijn tekst; Bo bewaart het voor een volgende keer.',
      ),
      (
        _zoeken,
        'Hoe laat begint Ravi’s optreden?',
        'om halfacht',
        ['om vijf uur', 'om halfzeven', 'om acht uur'],
        'Alinea 3 noemt het tijdstip waarop het gordijn opengaat.',
      ),
      (
        _zoeken,
        'Wie bedient de lampen?',
        'Bo',
        ['Ravi', 'de meester', 'iemand op de eerste rij'],
        'Dat staat aan het begin van alinea 2.',
      ),
    ],
  );
  block(
    'plein',
    '''Meer schaduw op het plein

1. Op het schoolplein is tijdens warme dagen weinig schaduw. De leerlingenraad heeft twee voorstellen: een groot schaduwdoek of drie bomen. Beide voorstellen kosten volgens de offertes ongeveer evenveel. De raad verzamelt eerst argumenten voordat er wordt gestemd.

2. “Ik kies voor het doek,” zegt Imran. “Dat geeft direct schaduw. Jonge bomen hebben nog kleine kronen. We kunnen het doek bovendien weghalen als we voor het schoolfeest een open plein nodig hebben.” Hij vindt wel dat er een goede afspraak moet komen over wie het doek ophangt en opbergt.

3. Elin kiest voor bomen. “Daar hebben we jarenlang plezier van. Er kunnen ook vogels in zitten. We moeten dan wel soorten kiezen die bij het plein passen en ruimte voor de wortels laten.” Zij begrijpt dat het langer duurt voordat bomen veel schaduw geven.

4. De leerlingenraad besluit de conciërge te vragen hoeveel werk het doek kost en de hovenier hoeveel ruimte de bomen nodig hebben. Daarna bespreekt de raad de antwoorden met alle klassen. Er is dus nog geen winnaar.''',
    [
      (
        _begrijpen,
        'Welk voordeel van het doek noemt Imran?',
        'Het geeft meteen schaduw.',
        [
          'Het is veel goedkoper dan bomen.',
          'Er kunnen vogels in nestelen.',
          'Het hoeft nooit opgeborgen te worden.',
        ],
        'Dit is zijn eerste argument in alinea 2.',
      ),
      (
        _begrijpen,
        'Waarover zijn Imran en Elin het volgens de tekst eens?',
        'Bomen geven niet meteen veel schaduw.',
        [
          'Een doek hoeft niet te worden opgehangen.',
          'Bomen zijn veel goedkoper.',
          'Het plein moet altijd helemaal open blijven.',
        ],
        'Imran noemt de kleine kronen; Elin erkent dat het langer duurt.',
      ),
      (
        _samenvatten,
        'Wat is het doel van de schrijver?',
        'Twee voorstellen met hun argumenten beschrijven.',
        [
          'Bewijzen dat bomen altijd de beste keuze zijn.',
          'Uitleggen hoe je een doek vastmaakt.',
          'De uitslag van een stemming bekendmaken.',
        ],
        'De tekst geeft beide kanten en eindigt zonder winnaar.',
      ),
      (
        _samenvatten,
        'Welke samenvatting past het best?',
        'De leerlingenraad vergelijkt bomen en een doek en vraagt extra informatie voor de keuze.',
        [
          'De leerlingenraad koopt het goedkoopste schaduwdoek.',
          'De hovenier plant vandaag drie grote bomen.',
          'Alle leerlingen willen dat het plein hetzelfde blijft.',
        ],
        'Deze samenvatting bevat de vergelijking en de volgende stap.',
      ),
      (
        _woorden,
        'Wat betekent bovendien in alinea 2?',
        'daar komt nog bij dat',
        ['daardoor gebeurt het dat', 'toch is het zo dat', 'in plaats daarvan'],
        'Imran voegt een tweede voordeel toe.',
      ),
      (
        _woorden,
        'Wat betekent argumenten in alinea 1?',
        'redenen voor een standpunt',
        [
          'uitslagen van wedstrijden',
          'prijzen van producten',
          'namen van leerlingen',
        ],
        'De raad wil de redenen voor beide keuzes vergelijken.',
      ),
      (
        _zoeken,
        'Aan wie vraagt de raad hoeveel werk het doek kost?',
        'aan de conciërge',
        ['aan de hovenier', 'aan alle ouders', 'aan de buschauffeur'],
        'De eerste vraag in alinea 4 is voor de conciërge.',
      ),
      (
        _zoeken,
        'Welke informatie over de kosten staat in alinea 1?',
        'Beide voorstellen kosten ongeveer evenveel.',
        [
          'De bomen zijn gratis.',
          'Het doek is twee keer zo duur.',
          'Er zijn nog geen offertes.',
        ],
        'Dit staat expliciet in alinea 1.',
      ),
    ],
  );
  final text = out.last.passage!;
  const options = [
    'Het doek geeft direct schaduw.',
    'Het doek kan worden weggehaald.',
    'Het doek is volgens de offertes gratis.',
    'Het doek heeft ruimte voor wortels nodig.',
  ];
  out.add(
    QuizQuestion(
      id: 'iep-l-plein-meerdere',
      topic: _begrijpen,
      passage: text,
      prompt:
          'Welke twee voordelen van het doek noemt Imran? Kies twee antwoorden.',
      options: options,
      answerIndex: 0,
      input: QuizInput.multiple,
      correctIndices: const [0, 1],
      explanation:
          'In alinea 2 noemt Imran de directe schaduw en het weghalen van het doek.',
    ),
  );
  return out;
}
