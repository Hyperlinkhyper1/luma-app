import 'dart:math';

import '../quiz_bank.dart';

List<QuizQuestion> buildIepLezenMore() {
  final out = <QuizQuestion>[];
  final random = Random(8132026);
  void card(String id, String passage, List<String> items) {
    for (var i = 0; i < items.length; i++) {
      final row = items[i].split('|');
      if (row.length != 6) throw StateError('Ongeldige leesvraag: $id-$i');
      final options = [row[2], row[3], row[4]]..shuffle(random);
      out.add(
        QuizQuestion(
          id: 'iep-l-nieuw-$id-$i',
          topic: switch (row[0]) {
            'B' => 'Begrijpen en interpreteren',
            'S' => 'Samenvatten',
            'W' => 'Woordenschat',
            _ => 'Opzoeken',
          },
          passage: passage,
          prompt: row[1],
          options: options,
          answerIndex: options.indexOf(row[2]),
          explanation: row[5],
        ),
      );
    }
  }

  card(
    'brug',
    '''De brug is weer open

1. De houten brug naar het park was in maart gesloten. Bij een controle bleek dat twee balken onder het loopvlak waren verrot. Fietsers moesten tijdelijk via de brede weg omrijden.

2. De gemeente verving de balken en maakte ook de leuning hoger. Dat laatste stond niet in het eerste plan. Bewoners hadden erop gewezen dat kleine kinderen hun handen gemakkelijk over de oude leuning konden steken.

3. Vanaf vrijdag mogen wandelaars de brug weer gebruiken. Fietsers moeten nog een week wachten: de nieuwe stroeflaag op het fietspad moet eerst drogen. Bij de ingang staat daarom een bord met twee verschillende data.''',
    [
      'B|Waarom werd de brug in maart gesloten?|Twee balken waren verrot.|De leuning was groen geverfd.|Het park werd uitgebreid.|De controle vond rotte balken.',
      'B|Waarom werd de leuning hoger gemaakt?|Bewoners wezen op de veiligheid van kleine kinderen.|Fietsers konden niet omrijden.|De gemeente wilde meer schaduw.|De bewoners noemden de lage leuning onveilig.',
      'B|Wat mogen wandelaars eerder dan fietsers?|De brug weer gebruiken.|Over de brede weg omrijden.|De stroeflaag aanbrengen.|Voor fietsers moet de stroeflaag nog drogen.',
      'S|Welke titel past ook bij de hele tekst?|Reparatie met extra aandacht voor veiligheid|Een nieuw park zonder fietsers|Kinderen bouwen zelf een brug|De tekst gaat over reparatie en veiligheid.',
      'S|Wat is vooral het doel van deze tekst?|Uitleggen wat is veranderd en wanneer de brug opengaat.|Fietsers overhalen een andere fiets te kopen.|Vertellen hoe hout groeit.|De tekst geeft uitleg over de reparatie en opening.',
      'W|Wat betekent tijdelijk in alinea 1?|voor een beperkte tijd|voor altijd|zonder toestemming|De omweg gold alleen tijdens de sluiting.',
      'O|In welke maand werd de brug gesloten?|maart|januari|vrijdag|De maand staat in alinea 1.',
      'O|Wat staat er bij de ingang van de brug?|een bord met twee data|een kaart van het park|een teller voor fietsers|Dit staat in alinea 3.',
    ],
  );

  card(
    'tuin',
    '''Samen tuinieren

1. Achter het buurthuis lag een stuk grond waarop jarenlang niets groeide. De buurtvereniging vroeg of zij er een moestuin mocht maken. De eigenaar gaf toestemming voor drie jaar, zolang het pad naar de nooduitgang vrij bleef.

2. In april maakten vrijwilligers verhoogde bakken. Daardoor kunnen ook mensen die moeilijk bukken meedoen. Een basisschool kreeg één bak voor kruiden. Kinderen meten elke week de groei en schrijven hun waarnemingen op.

3. De eerste oogst wordt verdeeld onder de helpers. Overgebleven groenten gaan op vrijdag naar de buurtkeuken. De vereniging zoekt nog iemand die in de zomervakantie water kan geven.''',
    [
      'B|Welke voorwaarde stelde de eigenaar?|Het pad naar de nooduitgang blijft vrij.|Alle groenten blijven bij de school.|Er worden geen kruiden geplant.|De voorwaarde staat in alinea 1.',
      'B|Waarom zijn de bakken verhoogd?|Zo kunnen mensen die moeilijk bukken meedoen.|Dan groeien kruiden zonder water.|Dan hoeft niemand te meten.|De hoogte maakt de tuin toegankelijker.',
      'B|Wat gebeurt met groenten die na de verdeling overblijven?|Ze gaan naar de buurtkeuken.|Ze worden weggegooid.|Ze blijven op school.|Alinea 3 noemt de buurtkeuken.',
      'S|Wat is de hoofdgedachte?|Buurtbewoners gebruiken een leeg terrein samen als tuin.|Een basisschool verhuist naar het buurthuis.|De eigenaar verkoopt het terrein.|Samen tuinieren staat centraal.',
      'S|Welk kopje past bij alinea 3?|De oogst en wat nog nodig is|Een nieuw pad maken|Waarom bakken hoog zijn|Alinea 3 gaat over de oogst en hulp in de zomer.',
      'W|Wat betekent waarnemingen in alinea 2?|dingen die je ziet en vastlegt|planten die je eet|mensen die de tuin beheren|De kinderen kijken naar de groei en schrijven die op.',
      'O|Voor hoeveel jaar kreeg de vereniging toestemming?|drie jaar|één jaar|vijf jaar|Dit staat in alinea 1.',
      'O|Wanneer gaan groenten naar de buurtkeuken?|op vrijdag|elke maandag|in april|De dag staat in alinea 3.',
    ],
  );

  card(
    'vlinder',
    '''Licht in de nacht

1. De natuurclub telde nachtvlinders in het bos. Ze hingen een wit laken op en lieten er een lamp op schijnen. Sommige soorten kwamen naar het licht, maar andere bleven tussen de bladeren zitten.

2. Noor telde eerst alleen de vlinders op het laken. Haar begeleider vroeg haar daarom ook langs de bomen te kijken. Samen vonden ze daar nog twee soorten. De club schreef op waar elke vlinder was gezien, zodat de telling later te controleren was.

3. De volgende ochtend schreef Noor in haar verslag dat de club zes soorten had gezien. Ze schreef niet dat er maar zes soorten in het bos leven. Daarvoor zou ze op meer avonden en op andere plekken moeten zoeken.''',
    [
      'B|Waarom keek Noor ook bij de bomen?|Niet alle nachtvlinders kwamen naar het licht.|Het laken was verdwenen.|Daar hing een tweede lamp.|Alinea 1 en 2 leggen uit dat sommige soorten wegbleven.',
      'B|Waarom noteerde de club de vindplaats van elke vlinder?|Dan kan de telling later worden gecontroleerd.|Dan worden de vlinders groter.|Dan blijft de lamp langer branden.|De reden staat aan het einde van alinea 2.',
      'B|Waarom zegt Noor niet dat er maar zes soorten in het bos leven?|Ze onderzocht niet alle avonden en plekken.|Ze vergat hoeveel lampen er waren.|Ze had geen wit laken.|Eén telling is te beperkt voor die conclusie.',
      'S|Wat laat de tekst vooral zien?|Een telling geeft informatie maar kent grenzen.|Nachtvlinders vliegen alleen naar lampen.|Een bos bevat altijd zes soorten.|Noor maakt een voorzichtige conclusie.',
      'S|Welk kopje past bij alinea 3?|Een voorzichtige conclusie|De lamp ophangen|De bomen planten|Alinea 3 gaat over wat de telling wel en niet laat zien.',
      'W|Wat betekent soorten in deze tekst?|verschillende groepen nachtvlinders|verschillende lampen|verschillende bomen|Het gaat om typen nachtvlinders.',
      'O|Hoeveel soorten zag de club volgens het verslag?|zes|twee|acht|Het aantal staat in alinea 3.',
      'O|Wat hing de club op om vlinders te tellen?|een wit laken|een vogelhuis|een spiegel|Het hulpmiddel staat in alinea 1.',
    ],
  );

  card(
    'sleutel',
    '''De sleutel in de la

1. Voor de voorstelling moest Sara de kast met kostuums openen. De sleutel lag niet op de afgesproken plek. Ze dacht dat iemand hem had meegenomen en wilde de directeur bellen.

2. Jip herinnerde zich dat de kast de dag ervoor was schoongemaakt. Hij keek in de la van de schoonmaakkar en vond daar de sleutel. De schoonmaker had hem veilig opgeborgen, maar was vergeten een briefje achter te laten.

3. Sara was opgelucht. Ze sprak met de schoonmaker af dat sleutels voortaan in een bakje naast de kast zouden liggen. Op dat bakje komt een kaartje, zodat invallers de afspraak ook kennen.''',
    [
      'B|Waarom zocht Jip in de schoonmaakkar?|Hij herinnerde zich dat de kast was schoongemaakt.|Hij wilde een kostuum wassen.|De directeur had hem gebeld.|Zijn herinnering gaf hem een aanwijzing.',
      'B|Wat had de schoonmaker vergeten?|Een briefje over de sleutel achterlaten.|De kast schoonmaken.|De voorstelling bijwonen.|Alinea 2 noemt het vergeten briefje.',
      'B|Waarom komt er een kaartje op het bakje?|Dan weten invallers ook waar de sleutel hoort.|Dan kan de kast niet meer open.|Dan hoeft niemand de sleutel te gebruiken.|Het kaartje maakt de afspraak duidelijk voor iedereen.',
      'S|Welke samenvatting past het best?|Na een zoektocht maken Sara en de schoonmaker een duidelijkere afspraak.|Sara koopt een nieuwe kast voor de kostuums.|Jip neemt alle sleutels mee naar huis.|De tekst eindigt met een nieuwe afspraak.',
      'S|Wat verandert er in het verhaal?|Een onduidelijke plek voor de sleutel wordt een vaste afspraak.|De voorstelling wordt afgelast.|De directeur wordt schoonmaker.|Het probleem leidt tot een vaste plek.',
      'W|Wat betekent invallers in alinea 3?|mensen die tijdelijk voor iemand anders werken|mensen die een kaartje kopen|mensen die de kast bouwen|Zij kennen de gewone afspraak misschien nog niet.',
      'O|Waar vond Jip de sleutel?|in de la van de schoonmaakkar|onder het podium|in de jas van Sara|Dit staat in alinea 2.',
      'O|Waar komen sleutels voortaan te liggen?|in een bakje naast de kast|bij de directeur thuis|op het podium|Dit staat in alinea 3.',
    ],
  );

  card(
    'trein',
    '''Een andere route

1. Op zaterdag rijden er geen treinen tussen Delft en Rotterdam. Spoorwerkers vervangen een wissel. Reizigers kunnen in Delft overstappen op een bus. Die stopt ook in Schiedam, maar niet bij alle kleine haltes.

2. Voor de busrit moet je ongeveer twintig minuten extra rekenen. Wie een fiets bij zich heeft, kan niet mee: in de vervangende bus is daar geen ruimte voor. Op zondag rijden de treinen weer volgens de gewone dienstregeling.

3. De spoorwegmaatschappij raadt reizigers aan hun reis vlak voor vertrek nog eens te bekijken. Bij slecht weer kan het werk later klaar zijn dan gepland. Veranderingen verschijnen in de reisplanner.''',
    [
      'B|Waarom rijden er zaterdag geen treinen op het traject?|Er wordt een wissel vervangen.|Er is een fietswedstrijd.|Het station van Delft sluit voorgoed.|De werkzaamheden staan in alinea 1.',
      'B|Wat is een beperking van de vervangende bus?|Een fiets kan niet mee.|De bus stopt niet in Schiedam.|De bus rijdt pas zondag.|Alinea 2 noemt gebrek aan ruimte voor fietsen.',
      'B|Waarom moet je vlak voor vertrek nog kijken?|Slecht weer kan de werkzaamheden vertragen.|De bus heeft geen bestuurder.|De treinen rijden nooit op zondag.|De eindtijd kan veranderen bij slecht weer.',
      'S|Wat is het doel van deze tekst?|Reizigers informeren over werkzaamheden en alternatief vervoer.|Reizigers een fiets verkopen.|Uitleggen hoe een wissel wordt gemaakt.|De tekst geeft praktische reisinformatie.',
      'S|Welk kopje past bij alinea 2?|Reistijd en fietsen meenemen|Het wissel vervangen|De reisplanner bijwerken|Alinea 2 noemt de extra tijd en fietsregel.',
      'W|Wat betekent vervangende in alinea 2?|die tijdelijk in plaats van iets anders rijdt|die altijd sneller is|die alleen voor werknemers is|De bus rijdt in plaats van de trein.',
      'O|Hoeveel extra reistijd moet je ongeveer rekenen?|twintig minuten|vijf minuten|een uur|Het getal staat in alinea 2.',
      'O|Waar stopt de bus ook?|in Schiedam|in Leiden|in Utrecht|Deze stop staat in alinea 1.',
    ],
  );

  card(
    'lampen',
    '''Lampen op zonne-energie

1. Op het wandelpad achter de sporthal is het in de winter vroeg donker. De gemeente plaatste er vier lampen op zonne-energie. Overdag laden de batterijen op; na zonsondergang gaan de lampen vanzelf aan.

2. Bewoners merkten dat één lamp na bewolkte dagen soms snel uitging. Een monteur ontdekte dat een boomtak schaduw op het zonnepaneel wierp. De tak werd gesnoeid. De andere drie lampen bleven gewoon werken.

3. In januari meet de gemeente opnieuw hoe lang de lampen branden. Als het probleem blijft, vervangt zij de batterij. Tot die tijd vraagt zij wandelaars storingen via de meldapp door te geven.''',
    [
      'B|Waarom plaatste de gemeente lampen op het pad?|Het is er in de winter vroeg donker.|De sporthal ging dicht.|Er kwam een fietswedstrijd.|De reden staat in alinea 1.',
      'B|Waarom werkte één lamp minder lang?|Een boomtak hield zonlicht tegen.|Alle lampen waren kapot.|De monteur zette hem uit.|De schaduw op het paneel verklaart het probleem.',
      'B|Wat gebeurt als het probleem in januari blijft?|De gemeente vervangt de batterij.|Alle bomen worden gekapt.|Het pad wordt gesloten.|Alinea 3 noemt de volgende stap.',
      'S|Wat is de hoofdgedachte?|De gemeente onderzoekt en verhelpt een probleem met een van de nieuwe lampen.|Zonnepanelen werken nooit in de winter.|Bewoners bouwen zelf lampen.|De tekst beschrijft plaatsing, probleem en vervolg.',
      'S|Welk kopje past bij alinea 3?|Opnieuw meten en storingen melden|Nieuwe takken planten|De sporthal verbouwen|Alinea 3 gaat over controle en meldingen.',
      'W|Wat betekent gesnoeid in alinea 2?|een deel van de tak is afgeknipt|de tak is geschilderd|de tak is gemeten|De tak mocht geen schaduw meer geven.',
      'O|Hoeveel lampen plaatste de gemeente?|vier|drie|vijf|Het aantal staat in alinea 1.',
      'O|Via welke weg kunnen wandelaars storingen melden?|de meldapp|een brief aan de sporthal|de reisplanner|De meldwijze staat in alinea 3.',
    ],
  );

  card(
    'pleinplan',
    '''Een keuze voor het plein

1. De leerlingenraad heeft geld voor één verandering aan het schoolplein. Groep 7 wil een tafeltennistafel; groep 8 wil een stille leeshoek. Beide plannen passen binnen het budget.

2. Bij een peiling kiezen de meeste leerlingen voor de tafeltennistafel. Toch vraagt de raad eerst aan de conciërge waar die veilig kan staan. Bij de ingang is het te druk; naast de gymzaal is ruimte. De leeshoek kan later misschien met tweedehands banken worden ingericht.

3. De raad neemt pas volgende week een besluit. Hij wil ook horen of de leraren tijdens pauzes toezicht kunnen houden bij de gymzaal. De peiling is dus belangrijk, maar niet het enige dat meetelt.''',
    [
      'B|Waarom is de plek bij de ingang ongeschikt?|Het is er te druk.|Daar staan al banken.|Daar is geen budget.|Alinea 2 noemt de drukte.',
      'B|Waarom is de uitslag van de peiling nog niet beslissend?|Veiligheid en toezicht moeten ook worden bekeken.|De leerlingen mochten niet stemmen.|De plannen zijn te duur.|De raad onderzoekt nog andere voorwaarden.',
      'B|Wat zou later met tweedehands banken kunnen worden ingericht?|de leeshoek|de gymzaal|de ingang|Dit staat in alinea 2.',
      'S|Welke samenvatting past het best?|De raad vergelijkt twee plannen en onderzoekt nog praktische gevolgen.|Groep 8 bouwt vandaag een leeshoek.|De tafeltennistafel is al geplaatst.|Er is nog geen besluit.',
      'S|Wat wil de schrijver vooral duidelijk maken?|Een populaire keuze moet ook uitvoerbaar en veilig zijn.|Peilingen zijn verboden op school.|Tweedehands banken zijn altijd duur.|De tekst bespreekt meer dan alleen de stemmen.',
      'W|Wat betekent budget in alinea 1?|het beschikbare geld|het aantal leerlingen|de plek op het plein|Beide plannen passen binnen het beschikbare bedrag.',
      'O|Welke groep wil een stille leeshoek?|groep 8|groep 7|de leraren|De groepen staan in alinea 1.',
      'O|Wanneer neemt de raad een besluit?|volgende week|vandaag|over een jaar|Het tijdstip staat in alinea 3.',
    ],
  );

  card(
    'brood',
    '''Brood bakken voor de markt

1. De klas bakt broodjes voor de herfstmarkt. In het recept staat dat deeg een uur moet rijzen. Op vrijdag maken de leerlingen alvast een proef. Ze merken dat het deeg in het koude lokaal na een uur nog nauwelijks groter is.

2. De bakker uit de buurt legt uit dat gist langzamer werkt als het koud is. De klas zet de kom op een warmere plek en wacht nog een halfuur. Dan is het deeg wel luchtig genoeg. Ze schrijven de verandering bij het recept.

3. Op de marktdag beginnen ze daarom eerder. Ze controleren het deeg voordat ze gaan bakken. Het recept is een hulpmiddel, maar de leerlingen kijken ook naar wat er werkelijk gebeurt.''',
    [
      'B|Waarom was het deeg na een uur nog nauwelijks groter?|Het lokaal was koud.|Er zat geen meel in de kom.|De markt was afgelast.|De bakker legt het effect van kou uit.',
      'B|Wat veranderde de klas na de proef?|Ze begon op de marktdag eerder.|Ze gebruikte geen gist meer.|Ze bakte zonder recept.|Alinea 3 noemt het eerdere begin.',
      'B|Waarom controleert de klas het deeg zelf?|De rijstijd kan door de temperatuur verschillen.|Het recept heeft geen stappen.|Broodjes mogen niet luchtig zijn.|De proef liet zien dat tijd alleen niet genoeg is.',
      'S|Wat is de belangrijkste les van de proef?|Een recept volgen én het resultaat controleren.|Een broodje moet altijd koud blijven.|Een markt begint pas na het bakken.|De klas past het plan aan op wat ze ziet.',
      'S|Welk kopje past bij alinea 2?|Uitleg en een aanpassing|De markt opent|Het recept verdwijnt|De bakker verklaart de vertraging en de klas past iets aan.',
      'W|Wat betekent rijzen in deze tekst?|groter en luchtiger worden|afkoelen in de oven|in kleine stukken snijden|Het deeg moest groter worden.',
      'O|Hoe lang wachtte de klas extra?|een halfuur|tien minuten|twee uur|De extra tijd staat in alinea 2.',
      'O|Wie gaf uitleg over de gist?|de bakker uit de buurt|de conciërge|de marktkoopman|Dit staat in alinea 2.',
    ],
  );

  card(
    'waterpeil',
    '''Het water stijgt

1. Na drie dagen regen staat het water in de sloot naast de speeltuin hoger dan gewoonlijk. De gemeente zet een lint om het laagste deel van het pad. Kinderen kunnen de speeltuin nog bereiken via de ingang aan de straat.

2. Een medewerker meet elke ochtend het waterpeil. De metingen komen op de gemeentelijke website. Als het water twee dagen achter elkaar zakt, bekijkt de gemeente of het lint weg kan. Ze wil eerst zeker weten dat het pad niet meer glad is.

3. Een buurman zegt dat de hele speeltuin gesloten is. Dat klopt niet: alleen een deel van het pad is afgezet. Het bord bij de ingang laat de omlooproute zien.''',
    [
      'B|Waarom is een deel van het pad afgezet?|Het water staat na regen hoog.|De schommels worden geverfd.|De straat is afgesloten.|Het lage pad ligt dicht bij het hoge water.',
      'B|Wanneer bekijkt de gemeente of het lint weg kan?|Als het water twee dagen achter elkaar zakt.|Zodra één kind het vraagt.|Pas na de zomervakantie.|De voorwaarde staat in alinea 2.',
      'B|Waarom moet de gemeente ook naar het pad kijken?|Het kan nog glad zijn.|Het bord kan nat worden.|De website moet leeg zijn.|Veiligheid hangt niet alleen van de waterhoogte af.',
      'S|Wat is de kern van de tekst?|Een deel van het pad is tijdelijk dicht, maar de speeltuin blijft bereikbaar.|De hele speeltuin is voorgoed gesloten.|Er komt een nieuwe sloot.|Alinea 3 corrigeert het misverstand.',
      'S|Welke uitspraak van de buurman wordt verbeterd?|Dat de hele speeltuin dicht is.|Dat er drie dagen regen viel.|Dat het water wordt gemeten.|Alleen het laagste deel van het pad is dicht.',
      'W|Wat betekent waterpeil in alinea 2?|de hoogte van het water|de temperatuur van het water|de kleur van het water|De medewerker meet hoe hoog het water staat.',
      'O|Waar staan de metingen?|op de gemeentelijke website|in de schoolapp|op de bus|Alinea 2 noemt de website.',
      'O|Via welke ingang kun je de speeltuin bereiken?|via de ingang aan de straat|via de sloot|via het afgezette pad|Dit staat in alinea 1.',
    ],
  );

  card(
    'boekenruil',
    '''Een ruilkast in de hal

1. In de hal van het buurthuis staat sinds maandag een kleine boekenkast. Bezoekers mogen een boek meenemen als zij er een ander boek voor terugzetten. Zo blijft er voor de volgende bezoeker iets te kiezen.

2. Vrijwilliger Yasmin controleert de kast op woensdag. Ze haalt beschadigde boeken eruit en zet kinderboeken op de onderste plank. De bovenste plank is voor boeken voor volwassenen. Daardoor kunnen kinderen gemakkelijker zelf iets pakken.

3. De ruilkast is geen bibliotheek: je hoeft boeken niet op een vaste datum terug te brengen. Wie geen boek heeft om te ruilen, kan bij de balie vragen of er een extra exemplaar beschikbaar is.''',
    [
      'B|Waarom zet je een ander boek terug als je er een meeneemt?|Dan blijft er keuze voor de volgende bezoeker.|Dan wordt de kast hoger.|Dan vervalt de controle op woensdag.|De afspraak houdt de kast gevuld.',
      'B|Waarom liggen kinderboeken onderaan?|Kinderen kunnen ze gemakkelijker pakken.|Ze zijn altijd zwaarder.|De bovenste plank is kapot.|Alinea 2 geeft de reden.',
      'B|Hoe verschilt de ruilkast van een bibliotheek?|Er is geen vaste datum om een boek terug te brengen.|Er staan geen kinderboeken.|Er mogen geen bezoekers komen.|Alinea 3 noemt dit verschil.',
      'S|Welke samenvatting past?|Een ruilkast laat bezoekers boeken uitwisselen en vrijwilligers houden haar bruikbaar.|Yasmin verkoopt boeken bij de balie.|De bibliotheek sluit op woensdag.|De tekst gaat over gebruik en beheer van de kast.',
      'S|Welk kopje past bij alinea 2?|Boeken controleren en indelen|Boeken op tijd terugbrengen|Een nieuwe hal bouwen|Yasmin controleert en verdeelt de boeken.',
      'W|Wat betekent exemplaar in alinea 3?|één boek|een plank|een balie|Een extra exemplaar is een extra boek.',
      'O|Op welke dag controleert Yasmin de kast?|woensdag|maandag|vrijdag|De controledag staat in alinea 2.',
      'O|Waar kun je vragen naar een extra boek?|bij de balie|op de bovenste plank|bij de bus|De plek staat in alinea 3.',
    ],
  );

  card(
    'fietsles',
    '''Leren fietsen in het verkeer

1. Groep 8 oefent voor het fietsexamen. Op maandag rijden de leerlingen eerst een route zonder verkeer, op het schoolplein. De leerkracht let vooral op duidelijk richting aangeven.

2. Tijdens de tweede oefening rijden ze door de wijk. Bij een kruispunt stopt Mila, hoewel ze voorrang heeft. Een bestelbus staat zo geparkeerd dat ze de andere straat niet kan overzien. De leerkracht noemt haar keuze verstandig.

3. Vrijdag is de laatste oefenrit. Het examen is pas de week erna. Leerlingen mogen vooraf de routekaart bekijken, maar krijgen onderweg geen aanwijzingen.''',
    [
      'B|Waarom stopt Mila bij het kruispunt?|Ze kan de andere straat niet goed zien.|Ze heeft geen voorrang.|Haar fiets heeft een lekke band.|De bestelbus belemmert haar zicht.',
      'B|Wat oefent de groep eerst op het schoolplein?|Duidelijk richting aangeven.|Een band plakken.|Een routekaart tekenen.|De leerkracht let vooral op richting aangeven.',
      'B|Waarom is stoppen volgens de leerkracht verstandig?|Mila controleert of de weg vrij is.|De buschauffeur heeft haar geroepen.|Het examen is al begonnen.|Veiligheid gaat boven haast.',
      'S|Wat is het onderwerp van de tekst?|Oefenen voor veilig fietsen in het verkeer.|Een wedstrijd tussen twee fietsen.|Een nieuwe busroute.|De oefeningen bereiden het fietsexamen voor.',
      'S|Welke volgorde klopt?|schoolplein, wijk, laatste oefenrit, examen|wijk, examen, schoolplein, oefenrit|examen, wijk, schoolplein, oefenrit|De alinea’s noemen deze volgorde.',
      'W|Wat betekent overzien in alinea 2?|goed kunnen zien wat er aankomt|een straat overslaan|een kaart uit het hoofd kennen|De bus staat in de weg van haar zicht.',
      'O|Wanneer is de laatste oefenrit?|vrijdag|maandag|de week na het examen|De dag staat in alinea 3.',
      'O|Krijgen leerlingen onderweg aanwijzingen tijdens het examen?|nee|ja, bij elk kruispunt|alleen van de buschauffeur|Alinea 3 zegt dat ze geen aanwijzingen krijgen.',
    ],
  );

  card(
    'steiger',
    '''Een veilige steiger

1. Bij de vijver staat een oude houten steiger. Vissers gebruikten hem vaak, maar sommige planken veerden sterk mee. De beheerder sloot de steiger vorige maand af.

2. Een timmerman verving zes planken. Daarna controleerde hij ook de palen onder het water. Eén paal stond scheef en moest worden verstevigd. De reparatie duurde daardoor langer dan verwacht.

3. Zaterdag gaat de steiger weer open. Er komt een bord met het maximale aantal bezoekers: vier tegelijk. De beheerder vraagt mensen niet te rennen, ook al voelt de nieuwe vloer stevig.''',
    [
      'B|Waarom ging de steiger dicht?|Sommige planken waren niet stevig.|De vijver was leeg.|Vissen was verboden.|De planken veerden sterk mee.',
      'B|Waarom duurde de reparatie langer?|Ook een paal onder water moest worden verstevigd.|Er waren geen bezoekers.|Het bord was kwijt.|De scheve paal zorgde voor extra werk.',
      'B|Welke nieuwe regel geldt na de opening?|Er mogen maximaal vier bezoekers tegelijk op.|Niemand mag nog vissen.|De steiger is alleen op maandag open.|Het bord noemt een maximum van vier.',
      'S|Welke samenvatting past?|Een onveilige steiger is gerepareerd en krijgt gebruiksregels.|De beheerder bouwt een tweede vijver.|Vissers maken zelf nieuwe palen.|Reparatie en veilig gebruik zijn de kern.',
      'S|Waarom noemt de tekst ook de palen?|Om te laten zien dat veiligheid meer vraagt dan nieuwe planken.|Om uit te leggen waar vissen wonen.|Om het maximale aantal bezoekers te berekenen.|Ook onder water bleek een probleem.',
      'W|Wat betekent verstevigd in alinea 2?|sterker gemaakt|weggeschilderd|korter gezaagd|De scheve paal moest weer veilig worden.',
      'O|Hoeveel planken verving de timmerman?|zes|vier|één|Het aantal staat in alinea 2.',
      'O|Op welke dag gaat de steiger weer open?|zaterdag|vrijdag|maandag|De dag staat in alinea 3.',
    ],
  );

  card(
    'museumles',
    '''Een voorwerp met een verhaal

1. In het stadsmuseum staat een oude schooltas. Op het kaartje staat alleen dat de tas rond 1920 is gemaakt. De museumgids vraagt groep 8 wat zij nog meer zouden willen weten.

2. De leerlingen onderzoeken een foto waarop kinderen met vergelijkbare tassen staan. Ze lezen ook een dagboekfragment over de wandeling naar school. Toch kunnen ze niet bewijzen dat juist de tas in de vitrine op die foto staat.

3. Voor hun presentatie maken ze onderscheid tussen feiten en vermoedens. Dat de tas oud is, is een feit. Dat hij van een kind op de foto was, blijft een vermoeden. De gids vindt die nauwkeurigheid belangrijker dan een spannend verhaal.''',
    [
      'B|Waarom kunnen de leerlingen de eigenaar van de tas niet aanwijzen?|De foto toont alleen vergelijkbare tassen.|Het dagboek is verdwenen.|De gids kent geen jaartal.|Vergelijkbare tassen bewijzen geen eigenaar.',
      'B|Wat staat als feit vast?|De tas is rond 1920 gemaakt.|De tas was van het kind links op de foto.|De tas was elke dag zwaar.|Alleen het jaartal staat op het kaartje.',
      'B|Waarom waardeert de gids hun presentatie?|Ze scheiden feiten van vermoedens.|Ze schrijven het spannendste verhaal.|Ze raden de naam van de eigenaar.|De gids prijst hun nauwkeurigheid.',
      'S|Wat laat deze tekst zien?|Historisch onderzoek vraagt zorgvuldigheid met bewijs.|Een dagboek vertelt altijd de hele waarheid.|Elke oude tas heeft een bekende eigenaar.|Het verschil tussen feit en vermoeden is centraal.',
      'S|Welk kopje past bij alinea 2?|Aanwijzingen onderzoeken|Een nieuwe tas kopen|De gids voorstellen|Foto en dagboek worden bekeken.',
      'W|Wat betekent vitrine in alinea 2?|een glazen kast om iets te tonen|een oud schrift|een schoolplein|De tas wordt erin tentoongesteld.',
      'O|Rond welk jaar is de tas gemaakt?|1920|1902|2000|Het jaartal staat in alinea 1.',
      'O|Welke twee bronnen bekijken de leerlingen?|een foto en een dagboekfragment|een kaart en een krant|een filmpje en een brief|De bronnen staan in alinea 2.',
    ],
  );

  card(
    'honden',
    '''Honden op het strand

1. In de zomer mogen honden op het stadsstrand alleen voor negen uur ’s ochtends komen. Veel bezoekers liggen dan nog niet op het zand. In de winter mogen honden de hele dag op het strand.

2. Een wandelaar vraagt waarom de regel in oktober verandert. De strandbeheerder zegt dat er dan veel minder zwemmers zijn. Hij wijst ook op een bord bij de ingang: baasjes moeten uitwerpselen in een zakje meenemen, in elk seizoen.

3. De gemeente evalueert de regels in het voorjaar. Bezoekers kunnen tot eind februari een reactie sturen. De nieuwe regels worden pas na die evaluatie bekendgemaakt.''',
    [
      'B|Waarom is de zomerse tijd voor honden beperkt?|Dan zijn er veel strandbezoekers en zwemmers.|Dan is het zand te koud.|Dan wordt het strand schoongemaakt.|De regel houdt rekening met andere bezoekers.',
      'B|Welke regel geldt het hele jaar?|Baasjes ruimen uitwerpselen op.|Honden mogen alleen voor negen uur komen.|Het strand is dicht in oktober.|Het bord noemt deze plicht voor elk seizoen.',
      'B|Waarom worden nieuwe regels nog niet bekendgemaakt?|De gemeente wil eerst reacties en een evaluatie.|Er is geen bord bij de ingang.|Er zijn in de winter geen honden.|De evaluatie komt in het voorjaar.',
      'S|Wat is vooral het doel van de tekst?|Regels voor honden en de komende evaluatie uitleggen.|Een strandvakantie verkopen.|Vertellen hoe een hond zwemt.|De tekst geeft regels en een vervolg.',
      'S|Welke bewering klopt volgens de tekst?|In de winter gelden andere tijden, maar opruimen blijft verplicht.|In oktober zijn alle regels weg.|Reacties kunnen pas in de zomer worden gestuurd.|Tijden veranderen; opruimen niet.',
      'W|Wat betekent evalueert in alinea 3?|bekijkt hoe de regels hebben gewerkt|schrijft de regels over|verplaatst het strand|De gemeente beoordeelt de regels.',
      'O|Tot wanneer kunnen bezoekers reageren?|tot eind februari|tot eind oktober|tot negen uur|De termijn staat in alinea 3.',
      'O|Wanneer mogen honden in de zomer op het strand?|voor negen uur ’s ochtends|de hele middag|alleen na middernacht|De zomertijd staat in alinea 1.',
    ],
  );

  card(
    'koor',
    '''Het koor zonder stroom

1. Het schoolkoor wil vrijdag optreden in de aula. Tijdens de repetitie valt de stroom uit. De microfoons en de elektrische piano werken niet. De conciërge verwacht dat de storing pas na het optreden is verholpen.

2. De dirigent verplaatst het koor naar de kleinere hal. Daar klinkt de zang zonder microfoons duidelijk genoeg. Een leerling begeleidt de liedjes op een gewone piano. Ouders krijgen via de schoolapp bericht over de nieuwe plek.

3. Vrijdag verloopt het optreden goed. Achter in de hal konden enkele bezoekers de tekst niet verstaan. Voor een volgend optreden wil de dirigent daarom minder stoelen plaatsen en iedereen dichterbij laten zitten.''',
    [
      'B|Waarom verandert de plek van het optreden?|In de kleinere hal is zang zonder microfoons goed te horen.|De aula is te klein voor het koor.|De gewone piano staat buiten.|De stroomstoring maakt versterking onmogelijk.',
      'B|Hoe krijgen ouders de nieuwe plek te horen?|via de schoolapp|via de radio|bij de kaartverkoop|Alinea 2 noemt de schoolapp.',
      'B|Wat wil de dirigent de volgende keer verbeteren?|Bezoekers dichter bij het koor laten zitten.|Meer microfoons huren.|Het optreden afgelasten.|Achterin was de tekst moeilijk te verstaan.',
      'S|Welke samenvatting past het best?|Het koor past zich aan een stroomstoring aan en leert van het optreden.|Het koor stopt na de repetitie.|Ouders verplaatsen zelf de piano.|De tekst beschrijft aanpassing en evaluatie.',
      'S|Welk kopje past bij alinea 3?|Een geslaagd optreden met een verbeterpunt|De stroom valt uit|Bericht aan de ouders|Alinea 3 beschrijft resultaat en les.',
      'W|Wat betekent verholpen in alinea 1?|opgelost|gemeten|verplaatst|De storing zou later pas opgelost zijn.',
      'O|Op welke dag treedt het koor op?|vrijdag|woensdag|maandag|De dag staat in alinea 1.',
      'O|Welk instrument vervangt de elektrische piano?|een gewone piano|een gitaar|een trommel|Het instrument staat in alinea 2.',
    ],
  );

  card(
    'vogelnest',
    '''Een nest bij het fietspad

1. Een medewerker vindt een vogelnest laag in een struik naast het fietspad. De struik zou die week worden gesnoeid. Ze vraagt de groenploeg om dat deel voorlopig over te slaan.

2. De ploeg zet een klein lint rond de struik, maar sluit het fietspad niet af. Fietsers hoeven alleen iets meer afstand te houden. De medewerker kijkt vanaf het pad of de oudervogels nog voedsel brengen; ze raakt het nest niet aan.

3. Zodra de jonge vogels zijn uitgevlogen, kan het snoeien alsnog gebeuren. Een bordje legt uit waarom de struik tijdelijk blijft staan. Zo begrijpen voorbijgangers dat het werk bewust is uitgesteld.''',
    [
      'B|Waarom wordt de struik voorlopig niet gesnoeid?|Er zit een nest met jonge vogels.|De groenploeg heeft geen schaar.|Het fietspad is gesloten.|Het nest vraagt tijdelijk bescherming.',
      'B|Waarom raakt de medewerker het nest niet aan?|Ze wil de vogels niet verstoren.|Ze kan niet bij de struik komen.|Ze zoekt een andere vogel.|Ze observeert vanaf afstand.',
      'B|Wanneer kan het snoeien alsnog gebeuren?|Als de jonge vogels zijn uitgevlogen.|Zodra het lint nat is.|Als de weg drukker wordt.|De voorwaarde staat in alinea 3.',
      'S|Wat is de kern van de tekst?|Het snoeien wordt uitgesteld zodat vogels het nest kunnen verlaten.|Het fietspad wordt breder gemaakt.|Vogels eten alleen bij wegen.|Het werk wacht op de jonge vogels.',
      'S|Waarom staat er een bordje?|Om de reden voor het uitstel uit te leggen.|Om fietsers een kaartje te verkopen.|Om nieuwe struiken te bestellen.|Voorbijgangers krijgen uitleg.',
      'W|Wat betekent voorlopig in alinea 1?|voor nu, nog niet definitief|zonder reden|voor altijd|Later kan er alsnog worden gesnoeid.',
      'O|Waar staat het nest?|in een struik naast het fietspad|onder de brug|op het dak van de school|De plek staat in alinea 1.',
      'O|Wordt het fietspad afgesloten?|nee|ja, de hele week|alleen in de avond|Alinea 2 zegt dat het pad open blijft.',
    ],
  );

  card(
    'expositie',
    '''Tekeningen in het station

1. De kunstklas maakt tekeningen over reizen. Het station wil ze in de hal ophangen, waar veel mensen langslopen. De leerlingen kiezen werk dat vanaf een paar meter afstand nog goed te zien is.

2. Niet elke tekening past in de beschikbare lijsten. Daarom maken sommige leerlingen een kleinere versie van hun werk. Bij elke tekening komt een kaartje met de naam van de maker en een korte uitleg.

3. De tentoonstelling is twee weken te bekijken. Daarna krijgt de klas de tekeningen terug. De stationsbeheerder vraagt bezoekers geen foto met flits te maken: dat kan andere reizigers in de hal hinderen.''',
    [
      'B|Waarom kiezen leerlingen tekeningen die van afstand duidelijk zijn?|Veel reizigers zien ze terwijl ze langslopen.|Er is geen licht in het station.|De lijsten zijn heel zwaar.|De plek vraagt om goed zichtbare tekeningen.',
      'B|Waarom maken sommige leerlingen een kleinere versie?|Hun werk past anders niet in de lijsten.|De maker wil anoniem blijven.|De tentoonstelling duurt te lang.|Alinea 2 noemt de lijsten.',
      'B|Waarom wordt flitsfotografie afgeraden?|De flits kan reizigers hinderen.|De tekeningen worden meteen nat.|De hal wordt gesloten.|De beheerder noemt hinder voor reizigers.',
      'S|Welke samenvatting past?|Een kunstklas richt een tijdelijke tentoonstelling in het station in.|Het station bouwt nieuwe perrons.|Reizigers stemmen over de school.|De tekst gaat over inrichting en regels van de expositie.',
      'S|Wat is de functie van de kaartjes bij de tekeningen?|Ze geven informatie over maker en werk.|Ze zijn toegangskaartjes voor de trein.|Ze tonen de vertrektijden.|Alinea 2 noemt naam en uitleg.',
      'W|Wat betekent beschikbaar in alinea 2?|wat er is om te gebruiken|wat nog gemaakt moet worden|wat verboden is|Het gaat om de lijsten die er zijn.',
      'O|Hoe lang is de tentoonstelling te bekijken?|twee weken|twee dagen|een maand|De duur staat in alinea 3.',
      'O|Waar hangen de tekeningen?|in de hal van het station|in de trein|in het klaslokaal|De plek staat in alinea 1.',
    ],
  );

  card(
    'weerhut',
    '''Meten bij het weerstation

1. Op het dak van de school staat een kleine weerhut. De thermometer hangt in de schaduw. Als de zon er rechtstreeks op scheen, zou hij vooral de warme buitenkant van het apparaat meten.

2. Elke ochtend leest een leerling de temperatuur af. Op woensdag ontbreekt een meting omdat de klas op excursie was. In de grafiek komt een leeg vakje; niemand vult zomaar een geschat getal in.

3. Aan het eind van de maand vergelijkt de klas de metingen met die van het officiële weerstation buiten de stad. De waarden lijken op elkaar, maar zijn niet altijd gelijk. De plekken en het tijdstip van meten kunnen verschil maken.''',
    [
      'B|Waarom hangt de thermometer in de schaduw?|Directe zon zou de meting beïnvloeden.|De leerlingen willen de hut niet zien.|Er valt nooit regen op het dak.|De zon verwarmt anders het apparaat.',
      'B|Waarom blijft woensdag leeg in de grafiek?|Er is die dag niets gemeten.|De temperatuur was nul.|De grafiek was al vol.|De klas was op excursie.',
      'B|Waarom kunnen twee weerstations verschillen?|Ze staan op andere plekken en meten mogelijk op andere tijden.|Een station geeft altijd een fout getal.|De klas gebruikt geen thermometer.|Alinea 3 noemt plek en tijdstip.',
      'S|Wat leert deze tekst over meten?|Zorgvuldige metingen en ontbrekende gegevens vragen om eerlijkheid.|Je kunt elk ontbrekend getal schatten.|Een grafiek heeft altijd gelijke waarden.|De klas verzint geen ontbrekende waarde.',
      'S|Welk kopje past bij alinea 3?|Metingen vergelijken|De excursie plannen|Een dak repareren|De klas vergelijkt twee stations.',
      'W|Wat betekent officieel in alinea 3?|erkend als vaste meetbron|door leerlingen getekend|alleen op zondag geopend|Het station wordt als vaste bron gebruikt.',
      'O|Op welke dag ontbreekt een meting?|woensdag|dinsdag|vrijdag|De dag staat in alinea 2.',
      'O|Waar staat de weerhut?|op het dak van de school|in de gymzaal|in het park|De plek staat in alinea 1.',
    ],
  );

  card(
    'hulpdienst',
    '''Oefenen met de hulpdienst

1. De brandweer bezoekt groep 8. Een medewerker legt uit wanneer je 112 belt: bij direct gevaar voor mensen. Voor een kapotte straatlamp of een verloren fiets gebruik je een ander meldpunt.

2. De leerlingen oefenen een gesprek met een neptelefoon. Ze vertellen eerst waar ze zijn en wat er is gebeurd. Daarna beantwoorden ze rustig de vragen van de centralist. Ze verbreken de verbinding pas als de centralist zegt dat het kan.

3. Aan het einde spelen ze verschillende situaties na. Bij rook uit een woning kiezen ze 112. Voor een losliggende stoeptegel kiezen ze de gemeente. De oefening gaat om herkennen welke hulp bij een situatie past.''',
    [
      'B|Wanneer is 112 volgens de tekst bedoeld?|Bij direct gevaar voor mensen.|Bij elke kapotte straatlamp.|Als je fiets zoek is.|Alinea 1 noemt direct gevaar.',
      'B|Wat vertellen leerlingen eerst in het oefengesprek?|Waar ze zijn en wat er is gebeurd.|Hoe oud de centralist is.|Welke kleur de telefoon heeft.|De eerste informatie staat in alinea 2.',
      'B|Waarom wachten ze met ophangen?|De centralist kan nog vragen stellen.|De telefoon is kapot.|De gemeente moet eerst bellen.|Ze stoppen pas wanneer de centralist dat zegt.',
      'S|Wat is het doel van de oefening?|Leren welke hulp bij welke situatie past.|Leren een telefoon repareren.|Een echte brand blussen.|Alinea 3 noemt het leerdoel.',
      'S|Welke twee situaties worden verschillend behandeld?|Rook uit een woning en een losse stoeptegel.|Twee kapotte straatlampen.|Twee verloren fietsen.|De tekst vergelijkt een spoedgeval met een gemeentemelding.',
      'W|Wat betekent centralist in alinea 2?|degene die de melding aanneemt|degene die de stoep repareert|degene die de klas bestuurt|De centralist stelt vragen tijdens de melding.',
      'O|Welke melding gaat naar de gemeente?|een losliggende stoeptegel|rook uit een woning|direct gevaar voor mensen|Het voorbeeld staat in alinea 3.',
      'O|Welk nummer oefent de klas voor spoedgevallen?|112|114|111|Het nummer staat in alinea 1.',
    ],
  );

  card(
    'markt',
    '''De markt verhuist een dag

1. Normaal staat de weekmarkt op dinsdag op het Raadhuisplein. Volgende week is daar een herdenking. De kramen verhuizen daarom eenmalig naar woensdag op het parkeerterrein bij het zwembad.

2. De meeste verkopers gaan mee. Alleen de bloemenkraam is woensdag afwezig: de verkoper levert dan aan winkels. Op de website staat een plattegrond van de tijdelijke markt. De ingang ligt naast de fietsenstalling.

3. Een week later keren de kramen terug naar hun gewone dag en plek. De gemeente plaatst borden, zodat bezoekers niet op dinsdag voor een leeg plein staan.''',
    [
      'B|Waarom verhuist de markt?|Op het gewone plein is een herdenking.|Het zwembad sluit.|Alle kramen zijn kapot.|Alinea 1 noemt de herdenking.',
      'B|Welke kraam ontbreekt woensdag?|de bloemenkraam|de groentekraam|de kaaskraam|De verkoper levert aan winkels.',
      'B|Waarom zet de gemeente borden neer?|Bezoekers moeten de tijdelijke verandering weten.|De markt wordt definitief gesloten.|Het parkeerterrein wordt geverfd.|De borden voorkomen verwarring.',
      'S|Wat is de kern?|De markt verandert één week van dag en plek.|De markt verhuist voorgoed naar het zwembad.|Alle verkopers stoppen.|De verandering is eenmalig.',
      'S|Welk kopje past bij alinea 2?|Verkopers en de nieuwe locatie|De gewone marktdag|De herdenking|Alinea 2 noemt aanwezigheid en plattegrond.',
      'W|Wat betekent eenmalig in alinea 1?|slechts deze ene keer|iedere week|zonder aankondiging|Een week later is alles weer gewoon.',
      'O|Op welke dag is de tijdelijke markt?|woensdag|dinsdag|vrijdag|De dag staat in alinea 1.',
      'O|Waar ligt de ingang van de tijdelijke markt?|naast de fietsenstalling|naast het gemeentehuis|bij de bloemenkraam|Dit staat in alinea 2.',
    ],
  );

  card(
    'zwemles',
    '''Een proef met zwemlessen

1. Het zwembad probeert een nieuwe lestijd op woensdagochtend. Sommige kinderen hebben dan les op school, dus de groep is klein. De instructeur heeft daardoor meer tijd om iedere leerling afzonderlijk te helpen.

2. Ouders waarderen de rustige les, maar voor hen is halen en brengen soms lastig. Het zwembad vraagt hen na vier weken een korte vragenlijst in te vullen. Ook de instructeur schrijft op wat hij tijdens de lessen merkt.

3. Pas daarna besluit het zwembad of de ochtendles blijft. Een druk bezochte les is niet het enige doel; het zwembad wil weten of leerlingen goed kunnen oefenen én gezinnen de lestijd kunnen gebruiken.''',
    [
      'B|Waarom kan de instructeur meer individuele hulp geven?|De groep is klein.|De les duurt twee uur langer.|Er is geen water in het bad.|Een kleine groep geeft meer tijd per leerling.',
      'B|Welk nadeel noemen ouders?|Halen en brengen is soms lastig.|De instructeur praat te weinig.|Het bad is gesloten.|Alinea 2 noemt hun praktische probleem.',
      'B|Waarom verzamelt het zwembad twee soorten reacties?|Ouders en instructeur zien verschillende kanten van de proef.|De vragenlijst is kwijt.|Er mogen geen leerlingen reageren.|Beide ervaringen helpen bij het besluit.',
      'S|Welke samenvatting past?|Het zwembad test een rustige lestijd en weegt voordelen en bezwaren af.|De ochtendles is al definitief.|Alle gezinnen vinden de les onbruikbaar.|Het besluit volgt pas na de proef.',
      'S|Wat is het doel van alinea 3?|Uitleggen hoe het besluit wordt genomen.|De zwemslag beschrijven.|De vragenlijst invullen.|Alinea 3 beschrijft de afweging.',
      'W|Wat betekent afzonderlijk in alinea 1?|ieder apart|allemaal tegelijk|zonder instructeur|De instructeur helpt iedere leerling apart.',
      'O|Na hoeveel weken vullen ouders een vragenlijst in?|vier weken|twee weken|acht weken|De termijn staat in alinea 2.',
      'O|Wanneer vindt de proefles plaats?|woensdagochtend|vrijdagavond|zondagmiddag|De lestijd staat in alinea 1.',
    ],
  );

  card(
    'stenen',
    '''Stenen uit de sloot

1. Bij het schoonmaken van een sloot vinden medewerkers oude bakstenen. Ze liggen in een rechte lijn. Een voorbijganger denkt meteen aan een verdwenen brug, maar de medewerkers weten dat nog niet.

2. Een archeoloog bekijkt kaarten uit verschillende jaren. Op een kaart van 1890 staat op die plek een smal voetpad over het water. Een kaart van twintig jaar later laat het pad niet meer zien. De stenen kunnen dus bij dat pad horen.

3. De gemeente bewaart enkele stenen en maakt foto's voordat het werk doorgaat. In het verslag staat dat de gevonden rij waarschijnlijk een oud bruggetje was. Het woord waarschijnlijk laat ruimte voor een andere verklaring.''',
    [
      'B|Waarom denkt de voorbijganger aan een brug?|De stenen liggen in een rechte lijn.|Hij vond een metalen fiets.|De sloot is droog.|De ligging is een aanwijzing, geen bewijs.',
      'B|Wat laat de kaart van 1890 zien?|een voetpad over het water|een zwembad|een brede autoweg|Alinea 2 noemt het voetpad.',
      'B|Waarom staat er waarschijnlijk in het verslag?|De verklaring is aannemelijk maar niet zeker.|De stenen zijn verdwenen.|De kaart is van volgend jaar.|De archeoloog houdt ruimte voor twijfel.',
      'S|Wat is het hoofdonderwerp?|Een vondst wordt met oude kaarten onderzocht.|Medewerkers bouwen een nieuwe brug.|Een voorbijganger verliest stenen.|De tekst gaat over onderzoek van een vondst.',
      'S|Welke volgorde klopt?|vondst, kaarten bekijken, vondst vastleggen|kaarten bekijken, brug bouwen, sloot vinden|verslag schrijven, stenen vinden, pad tekenen|Zo verloopt het onderzoek in de tekst.',
      'W|Wat betekent waarschijnlijk in alinea 3?|goed mogelijk|helemaal onmogelijk|volledig bewezen|Er is een aanwijzing, maar geen zekerheid.',
      'O|Van welk jaar is de eerste genoemde kaart?|1890|1900|1920|Het jaartal staat in alinea 2.',
      'O|Wat bewaart de gemeente?|enkele stenen|het hele voetpad|de oude kaart|Dit staat in alinea 3.',
    ],
  );

  card(
    'filmclub',
    '''Een film met ondertitels

1. De filmclub in het buurthuis vertoont zaterdag een natuurfilm. De film heeft Nederlandse ondertitels, hoewel de spreker ook Nederlands praat. Daardoor kunnen bezoekers die minder goed horen het verhaal beter volgen.

2. Na de film volgt een gesprek met een natuuronderzoeker. Bezoekers kunnen vragen op papier schrijven. De gespreksleider leest ze hardop voor, zodat ook mensen die niet graag voor een groep spreken kunnen meedoen.

3. Voor de film is reserveren nodig, want de zaal heeft maar veertig plaatsen. Het nagesprek is inbegrepen. Wie alleen het gesprek wil bezoeken, kan na afloop van de film binnenkomen als er nog een stoel vrij is.''',
    [
      'B|Waarom heeft de film ondertitels?|Zo kunnen bezoekers die minder goed horen het verhaal volgen.|De spreker praat een andere taal.|De film is zonder geluid.|Alinea 1 geeft de reden.',
      'B|Waarom mogen bezoekers vragen opschrijven?|Zo kunnen ook stille bezoekers meedoen.|Er is geen gespreksleider.|De onderzoeker kan niet lezen.|De gespreksleider leest vragen voor.',
      'B|Wanneer mag iemand alleen voor het gesprek binnenkomen?|Na de film, als er nog een stoel vrij is.|Voor de film zonder reservering.|Alleen op zondag.|Alinea 3 noemt de voorwaarde.',
      'S|Wat is vooral het doel van de tekst?|Informatie geven over een toegankelijke filmavond.|Een natuurfilm navertellen.|Een onderzoeker beoordelen.|De tekst geeft praktische gegevens over de avond.',
      'S|Welk kopje past bij alinea 2?|Vragen stellen na de film|Plaatsen reserveren|Waarom de film ondertitels heeft|Alinea 2 gaat over het gesprek.',
      'W|Wat betekent inbegrepen in alinea 3?|het hoort erbij zonder apart kaartje|het gaat niet door|het is alleen online|Het nagesprek hoort bij het filmbezoek.',
      'O|Hoeveel plaatsen heeft de zaal?|veertig|twintig|zestig|Het aantal staat in alinea 3.',
      'O|Op welke dag is de filmavond?|zaterdag|vrijdag|maandag|De dag staat in alinea 1.',
    ],
  );

  card(
    'post',
    '''Een pakket voor de buren

1. Sam vindt een bezorgbriefje in de bus: een pakket ligt bij de buren op nummer 18. Hij loopt erheen, maar niemand doet open. Op het briefje staat dat het pakket pas vanaf vijf uur kan worden opgehaald.

2. Sam had die regel over het hoofd gezien. Om halfzes probeert hij het opnieuw. De buurvrouw geeft hem het pakket en vraagt zijn huisnummer, zodat ze zeker weet dat ze het aan de juiste persoon geeft.

3. Thuis ziet Sam dat het pakket voor zijn moeder is. Hij legt het op tafel en stuurt haar een bericht. Zo weet ze dat de bezorging toch gelukt is, hoewel zij die middag niet thuis was.''',
    [
      'B|Waarom doet er bij Sams eerste bezoek niemand open?|Het pakket kan pas vanaf vijf uur worden opgehaald.|De buren zijn verhuisd.|Het pakket ligt op school.|Sam had de tijd op het briefje gemist.',
      'B|Waarom vraagt de buurvrouw Sams huisnummer?|Ze wil het pakket aan de juiste persoon geven.|Ze wil een huis kopen.|Ze zoekt de postbode.|Ze controleert voor wie het pakket is.',
      'B|Waarom stuurt Sam zijn moeder een bericht?|Dan weet zij dat het pakket is aangekomen.|Dan hoeft ze geen pakket meer te bestellen.|Dan kan de buurvrouw het ophalen.|Het bericht bevestigt de bezorging.',
      'S|Welke samenvatting past?|Sam haalt na een mislukte poging een pakket bij de buren op.|Sam stuurt een pakket naar nummer 18.|De postbode zoekt een nieuw adres.|Het verhaal draait om ophalen en informeren.',
      'S|Wat was Sams vergissing?|Hij had de ophaaltijd niet goed gelezen.|Hij was naar de verkeerde straat gegaan.|Hij had zijn sleutel vergeten.|Alinea 2 zegt dat hij de tijd over het hoofd zag.',
      'W|Wat betekent over het hoofd gezien?|niet opgemerkt|goed gecontroleerd|zelf opgeschreven|Sam merkte de regel eerst niet op.',
      'O|Op welk nummer ligt het pakket?|18|15|5|Het huisnummer staat in alinea 1.',
      'O|Hoe laat probeert Sam het opnieuw?|om halfzes|om vier uur|om zes uur|Het tijdstip staat in alinea 2.',
    ],
  );

  card(
    'dijk',
    '''Het gras op de dijk

1. De dijkbeheerder laat schapen op een dijk grazen. Ze houden het gras kort zonder zware maaimachines. Hun poten drukken de bodem ook licht aan.

2. Tijdens natte weken haalt de beheerder de schapen tijdelijk weg. Op een zachte, modderige dijk kunnen hun hoeven juist kuilen maken. Een medewerker controleert daarom elke maandag de toestand van de bodem.

3. Wandelaars mogen over het pad naast de dijk blijven lopen. Honden moeten daar aan de lijn, zodat de schapen niet worden opgejaagd. Bij de ingang staat een bord met deze regel.''',
    [
      'B|Waarom gebruikt de beheerder schapen?|Ze houden het gras kort zonder zware machines.|Ze bouwen een hek.|Ze eten de dijk op.|Alinea 1 noemt het onderhoud.',
      'B|Waarom gaan schapen in natte weken weg?|Hun hoeven kunnen kuilen maken in zachte grond.|Ze kunnen niet zwemmen.|Wandelaars willen meer ruimte.|Natte bodem is kwetsbaar voor hoefafdrukken.',
      'B|Waarom moeten honden aan de lijn?|Dan jagen ze de schapen niet op.|Dan groeit het gras sneller.|Dan kan de beheerder meten.|Alinea 3 geeft de reden.',
      'S|Wat is de hoofdgedachte?|Schapen helpen bij dijkonderhoud, maar het gebruik vraagt regels.|Schapen grazen alleen in de winter.|De dijk wordt een parkeerplaats.|Voordelen en voorwaarden worden genoemd.',
      'S|Wat laat alinea 2 vooral zien?|Een goede methode is niet in elke situatie geschikt.|Maandag is altijd een droge dag.|De schapen worden verkocht.|Bij nat weer zijn schapen op de dijk ongeschikt.',
      'W|Wat betekent tijdelijk in alinea 2?|voor een beperkte periode|voor altijd|zonder reden|Na natte weken kunnen ze terugkomen.',
      'O|Op welke dag controleert een medewerker de bodem?|maandag|vrijdag|zondag|De dag staat in alinea 2.',
      'O|Waar staat de hondenregel?|op een bord bij de ingang|op de website van school|op een schapenhok|Dit staat in alinea 3.',
    ],
  );

  card(
    'ruil',
    '''Een jas die verder kan

1. Tijdens de kledingruil brengt Lotte een jas mee die haar te klein is. De jas is schoon en de rits werkt. Vrijwilligers controleren alle kleding voordat die aan rekken wordt gehangen.

2. Bezoekers krijgen voor elk ingeleverd kledingstuk een ruilkaartje. Met dat kaartje mogen ze iets anders uitzoeken. Wie niets geschikts vindt, kan het kaartje bij de volgende kledingruil gebruiken.

3. Kleding met gaten wordt niet meteen weggegooid. Een groep vrijwilligers bekijkt of herstel mogelijk is. Alleen spullen die niet meer te repareren zijn, gaan naar de textielinzameling.''',
    [
      'B|Waarom wordt Lottes jas geaccepteerd?|Hij is schoon en de rits werkt.|Hij is nieuw gekocht.|Hij heeft extra zakken.|De jas voldoet aan de controle.',
      'B|Wat kan iemand doen als er niets geschikts is?|Het ruilkaartje bij een volgende ruil gebruiken.|Een ander kaartje kopen.|De vrijwilligers naar huis sturen.|Alinea 2 noemt die mogelijkheid.',
      'B|Wat gebeurt eerst met kleding met gaten?|Vrijwilligers bekijken of herstel kan.|Het gaat direct in de vuilnisbak.|Het wordt meteen verkocht.|Reparatie wordt eerst onderzocht.',
      'S|Wat is het doel van deze tekst?|Uitleggen hoe de kledingruil werkt.|Vertellen hoe je een rits maakt.|Een nieuwe jas aanprijzen.|De tekst beschrijft regels en stappen.',
      'S|Welke gedachte past bij de hele tekst?|Bruikbare kleding krijgt een nieuwe kans.|Alle oude kleding is waardeloos.|Je moet altijd iets vinden bij de eerste ruil.|Ook reparatie en hergebruik tellen mee.',
      'W|Wat betekent geschikt in alinea 2?|passend bij wat je zoekt|beschadigd|verplicht|Een bezoeker zoekt iets dat hij kan gebruiken.',
      'O|Wat krijg je voor elk ingeleverd kledingstuk?|een ruilkaartje|een euro|een reparatieset|Dit staat in alinea 2.',
      'O|Waar gaat kleding heen die niet te repareren is?|naar de textielinzameling|naar de schooltas|naar de boekenkast|Alinea 3 noemt de bestemming.',
    ],
  );

  card(
    'robot',
    '''De robot kiest een route

1. Op de techniekmiddag bouwen leerlingen een kleine robot. Die moet van de start naar een blauwe cirkel rijden. De eerste route is kort, maar er staat een doos midden op het pad.

2. De leerlingen programmeren de robot om om de doos heen te rijden. Bij de eerste poging draait hij te vroeg en raakt hij een stoel. Ze meten de afstand opnieuw en veranderen één opdracht in het programma.

3. Daarna bereikt de robot de cirkel. In hun verslag schrijven ze ook de mislukte poging op. Zo kunnen andere leerlingen zien welke verandering het verschil maakte.''',
    [
      'B|Waarom kan de robot niet rechtdoor?|Er staat een doos op het pad.|De blauwe cirkel beweegt.|De start is verdwenen.|Het obstakel staat in alinea 1.',
      'B|Wat veranderen de leerlingen na de botsing?|Eén opdracht in het programma.|De kleur van de cirkel.|De plaats van de stoel.|Ze meten opnieuw en passen één opdracht aan.',
      'B|Waarom beschrijven ze de mislukte poging?|Dan is te zien welke aanpassing hielp.|Dan lijkt de robot sneller.|Dan verdwijnt de botsing.|Een verslag laat ook het leerproces zien.',
      'S|Wat is de hoofdgedachte?|Door meten en aanpassen vindt de robot een werkende route.|Een robot kan alleen rechtdoor rijden.|De doos was de enige opdracht.|De route werkt na een gerichte verandering.',
      'S|Welke volgorde klopt?|obstakel zien, omweg proberen, meten, slagen|slagen, meten, starten, botsen|meten, slagen, doos plaatsen, starten|De tekst beschrijft deze stappen.',
      'W|Wat betekent programmeren in alinea 2?|opdrachten voor de robot instellen|de robot schilderen|de robot vervoeren|Het programma bepaalt de beweging.',
      'O|Waar moet de robot heen?|naar een blauwe cirkel|naar een rode stoel|naar een groene doos|Het doel staat in alinea 1.',
      'O|Wat raakt de robot bij de eerste poging?|een stoel|de doos|de cirkel|De botsing staat in alinea 2.',
    ],
  );

  card(
    'waterfles',
    '''Kraanwater bij de wedstrijd

1. De sportvereniging stopt met het uitdelen van kleine plastic flesjes na wedstrijden. Spelers nemen voortaan een eigen hervulbare fles mee. Bij het veld is een extra kraan geplaatst.

2. Niet iedereen had de eerste week een fles bij zich. De vereniging leende bekers uit en stuurde daarna een herinnering naar alle teams. De kraan blijft ook voor bezoekers beschikbaar.

3. Na een maand vergelijkt de vereniging hoeveel afval er is verzameld. Ze wil weten of de verandering echt helpt. De kosten van de nieuwe kraan telt ze ook mee in de evaluatie.''',
    [
      'B|Waarom plaatste de vereniging een extra kraan?|Spelers kunnen eigen flessen vullen.|Het veld moest worden besproeid.|De kleedkamer ging dicht.|De kraan ondersteunt het gebruik van hervulbare flessen.',
      'B|Hoe hielp de vereniging spelers zonder fles?|Ze leende bekers uit.|Ze verbood hen te drinken.|Ze deelde plastic flessen uit.|Alinea 2 noemt de bekers.',
      'B|Waarom vergelijkt de vereniging de hoeveelheid afval?|Ze wil zien of de verandering helpt.|Ze wil weten wie de wedstrijd won.|Ze zoekt een nieuw veld.|Afval is een maat voor het effect.',
      'S|Welke samenvatting past?|De vereniging probeert plastic afval te verminderen en controleert het resultaat.|De vereniging sluit de kraan.|Bezoekers mogen geen water meer drinken.|Plan en evaluatie vormen de kern.',
      'S|Wat laat alinea 2 zien?|Een nieuwe afspraak vraagt soms extra hulp en uitleg.|Iedereen had meteen een fles.|De kraan is alleen voor spelers.|De eerste week liep niet alles vanzelf.',
      'W|Wat betekent hervulbaar in alinea 1?|opnieuw te vullen|na één keer weg te gooien|alleen leeg te gebruiken|De fles kan bij de kraan opnieuw worden gevuld.',
      'O|Wanneer vergelijkt de vereniging het afval?|na een maand|na een dag|na een jaar|De termijn staat in alinea 3.',
      'O|Voor wie blijft de kraan ook beschikbaar?|voor bezoekers|alleen voor scheidsrechters|alleen voor de gemeente|Dit staat in alinea 2.',
    ],
  );

  card(
    'archief',
    '''Een brief zonder afzender

1. In het gemeentearchief ligt een brief uit 1948. De naam van de afzender is afgescheurd. Op de achterkant staat wel een stempel van een postkantoor in Haarlem.

2. Archivaris Esra vergelijkt het handschrift met andere brieven in dezelfde map. Twee brieven lijken erop, maar zijn niet precies gelijk. Daarom noteert ze dat de afzender onbekend is. De stempel bewijst alleen waar de brief is verstuurd.

3. Een onderzoeker mag de brief in de leeszaal bekijken. Hij moet eerst een afspraak maken, omdat oude documenten voorzichtig uit de opslag worden gehaald. Foto's maken mag zonder flits.''',
    [
      'B|Waarom blijft de afzender onbekend?|Het handschrift levert geen zeker bewijs.|De brief heeft geen jaartal.|Haarlem bestaat niet meer.|Gelijkenis is niet genoeg om een naam vast te stellen.',
      'B|Wat bewijst de stempel wel?|Waar de brief is verstuurd.|Wie de brief schreef.|Wat er in de brief staat.|Alinea 2 beperkt de conclusie tot de verzendplek.',
      'B|Waarom is een afspraak nodig?|Oude stukken worden voorzichtig uit opslag gehaald.|De leeszaal is altijd vol.|De brief wordt verkocht.|Het archief moet de stukken voorbereiden.',
      'S|Wat is de hoofdgedachte?|Een oude brief wordt zorgvuldig onderzocht en bewaard.|Een archivaris vindt meteen een afzender.|Alle brieven komen uit Haarlem.|De tekst gaat over bewijs en zorgvuldig gebruik.',
      'S|Welke uitspraak is een feit?|Op de brief staat een stempel uit Haarlem.|De schrijver woonde in Haarlem.|Esra schreef de brief.|De stempel is zichtbaar; de woonplaats blijft onbekend.',
      'W|Wat betekent afzender?|degene die de brief verstuurt|degene die de brief ontvangt|degene die foto’s maakt|De naam van de verzender ontbreekt.',
      'O|Uit welk jaar is de brief?|1948|1848|1984|Het jaar staat in alinea 1.',
      'O|Waar mag de onderzoeker de brief bekijken?|in de leeszaal|in de opslag|thuis|De plek staat in alinea 3.',
    ],
  );

  card(
    'bosroute',
    '''Een route voor alle wandelaars

1. Het natuurgebied krijgt een nieuwe wandelroute. Het oude pad loopt over losse stenen en is lastig voor mensen met een rolstoel. De nieuwe route gaat langs een stevig, vlak pad.

2. De route is iets langer, maar komt wel langs dezelfde uitkijkplek. Op twee plaatsen staan bankjes. Een vrijwilliger controleert of de bordjes ook vanaf een lage zitpositie leesbaar zijn.

3. Na de opening vraagt de beheerder bezoekers om reacties. Als een bocht toch te smal blijkt, kan het pad daar nog worden aangepast. De route is dus klaar voor gebruik, maar de beheerder blijft kijken hoe zij werkt.''',
    [
      'B|Waarom is de nieuwe route gemaakt?|Het oude pad is lastig voor rolstoelgebruikers.|De uitkijkplek is verdwenen.|Er zijn te veel bankjes.|Alinea 1 noemt de toegankelijkheid.',
      'B|Wat blijft ondanks de andere route bereikbaar?|dezelfde uitkijkplek|een nieuw zwembad|het oude stenen pad|Alinea 2 noemt dezelfde uitkijkplek.',
      'B|Waarom vraagt de beheerder na opening reacties?|Een te smalle bocht kan nog worden verbeterd.|Ze wil de route sluiten.|Ze zoekt nieuwe stenen voor het oude pad.|Er kan nog een aanpassing nodig zijn.',
      'S|Welke samenvatting past?|Een beter toegankelijk pad wordt geopend en daarna geëvalueerd.|Alle paden worden met stenen bedekt.|De uitkijkplek sluit voorgoed.|De route is gericht op toegankelijkheid.',
      'S|Wat laat de controle van de bordjes zien?|Ook informatie moet voor verschillende bezoekers bruikbaar zijn.|Alle bordjes worden weggehaald.|Een rolstoel kan niet stoppen.|Een lage zitpositie telt mee.',
      'W|Wat betekent lastig in alinea 1?|moeilijk te gebruiken|voor iedereen eenvoudig|niet toegestaan|Het oude pad is moeilijk voor rolstoelgebruikers.',
      'O|Hoeveel plekken met bankjes noemt de tekst?|twee|vier|geen|Het aantal staat in alinea 2.',
      'O|Waar gaat de nieuwe route nog steeds langs?|de uitkijkplek|het zwembad|de parkeerplaats|De plek staat in alinea 2.',
    ],
  );

  card(
    'podcast',
    '''De eerste aflevering

1. Drie leerlingen maken een podcast over het dorp. Ze willen een bakker interviewen die al veertig jaar dezelfde winkel heeft. Vooraf schrijven ze vragen over veranderingen in de straat.

2. Tijdens het gesprek vertelt de bakker dat er vroeger minder auto's waren. Eén leerling wil meteen zeggen dat de straat toen veiliger was. De anderen wijzen erop dat de bakker dat niet heeft gezegd. Ze vragen hem hoe hij het verkeer destijds ervoer.

3. In de montage halen ze lange stiltes weg, maar veranderen ze zijn antwoorden niet. Aan het eind noemen ze zijn naam en bedanken ze hem. De aflevering verschijnt pas nadat de bakker heeft gehoord hoe zijn verhaal wordt gebruikt.''',
    [
      'B|Waarom stellen de leerlingen een extra vraag over verkeer?|Ze willen niet zelf een conclusie namens de bakker trekken.|Ze zijn hun vragen kwijt.|De bakker praat niet over vroeger.|Minder auto’s betekent niet automatisch dat hij het veiliger vond.',
      'B|Wat halen de leerlingen uit de opname?|lange stiltes|alle antwoorden|de naam van de bakker|Alinea 3 noemt de stiltes.',
      'B|Waarom hoort de bakker de aflevering vóór publicatie?|Dan weet hij hoe zijn verhaal wordt gebruikt.|Dan kan hij de winkel sluiten.|Dan hoeft niemand te monteren.|Hij mag horen wat er met het interview gebeurt.',
      'S|Welke samenvatting past?|Leerlingen maken zorgvuldig een podcast met een interview over veranderingen.|De bakker opent een tweede winkel.|De leerlingen maken een film over auto’s.|Interview en zorgvuldige montage zijn de kern.',
      'S|Welk kopje past bij alinea 2?|Doorvragen zonder zelf iets in te vullen|De winkel sluiten|De aflevering plaatsen|De leerlingen vragen verder in plaats van iets aan te nemen.',
      'W|Wat betekent montage in alinea 3?|het bewerken van de opname|het bakken van brood|het schrijven van vragen|Ze halen stiltes uit de opname.',
      'O|Hoe lang heeft de bakker dezelfde winkel?|veertig jaar|vier jaar|twintig jaar|De duur staat in alinea 1.',
      'O|Wanneer verschijnt de aflevering?|nadat de bakker heeft gehoord hoe zijn verhaal wordt gebruikt|voor het interview|tijdens het schrijven van vragen|De voorwaarde staat in alinea 3.',
    ],
  );

  card(
    'wedstrijd',
    '''Een wedstrijd met twee rondes

1. Bij de voorleeswedstrijd leest ieder kind eerst een zelfgekozen fragment. De jury let op verstaanbaarheid en of de stem bij het verhaal past. De lengte van het boek telt niet mee.

2. In de tweede ronde krijgen de deelnemers een onbekende tekst. Ze mogen die vijf minuten stil lezen. Daarna lezen ze hardop. Zo ziet de jury hoe iemand met een nieuwe tekst omgaat.

3. De uitslag volgt na een pauze. De jury geeft alle deelnemers één tip, ook wie de wedstrijd wint. Het doel is immers niet alleen een winnaar kiezen, maar ook beter leren voorlezen.''',
    [
      'B|Waar let de jury in de eerste ronde op?|verstaanbaarheid en passende stem|de dikte van het boek|hoe duur het boek is|De criteria staan in alinea 1.',
      'B|Waarom is de tekst in ronde twee onbekend?|De jury wil zien hoe kinderen een nieuwe tekst lezen.|De deelnemers zijn hun boeken vergeten.|De jury wil het boek verkopen.|De tweede ronde toetst omgaan met nieuwe tekst.',
      'B|Waarom krijgt ook de winnaar een tip?|Iedereen kan nog beter leren voorlezen.|De jury kent de winnaar niet.|Er zijn geen prijzen.|Het leerdoel geldt voor iedereen.',
      'S|Wat is de kern van de tekst?|De wedstrijd beoordeelt voorlezen en helpt deelnemers leren.|Alleen lange boeken mogen meedoen.|De uitslag komt voor de tweede ronde.|Beoordeling en ontwikkeling zijn beide belangrijk.',
      'S|Welke volgorde klopt?|gekozen fragment, onbekende tekst, uitslag|uitslag, gekozen fragment, onbekende tekst|onbekende tekst, uitslag, gekozen fragment|De rondes en uitslag worden zo beschreven.',
      'W|Wat betekent fragment in alinea 1?|een stukje uit een tekst|een hele bibliotheek|een stemgeluid|De deelnemers lezen een gekozen stukje.',
      'O|Hoe lang mogen deelnemers de onbekende tekst eerst lezen?|vijf minuten|één minuut|een halfuur|De tijd staat in alinea 2.',
      'O|Wanneer volgt de uitslag?|na een pauze|voor ronde één|tijdens het stil lezen|Dit staat in alinea 3.',
    ],
  );

  card(
    'bibliobus',
    '''De bibliobus stopt later

1. De bibliobus komt elke donderdag in het dorp. Vanaf volgende maand stopt hij niet meer om drie uur, maar om vier uur. De school had gevraagd om een later tijdstip, zodat leerlingen na de les kunnen komen.

2. De bus blijft een uur op het plein staan. Boeken die je hebt geleend, mag je ook in de gewone bibliotheek inleveren. Wie een gereserveerd boek verwacht, krijgt een bericht zodra het boek in de bus ligt.

3. Na zes weken bekijkt de bibliotheek hoeveel bezoekers er op de nieuwe tijd komen. Is het plein te druk voor de bus, dan zoekt zij een andere halte in het dorp. De dag blijft in elk geval donderdag.''',
    [
      'B|Waarom komt de bus een uur later?|Leerlingen kunnen dan na school komen.|De bus rijdt niet meer op donderdag.|De boeken zijn later gedrukt.|De school vroeg om een tijd na de les.',
      'B|Waar kun je geleende boeken ook inleveren?|in de gewone bibliotheek|alleen bij de school|alleen bij de chauffeur thuis|Alinea 2 noemt de andere inleverplek.',
      'B|Wat kan na zes weken nog veranderen?|de halte in het dorp|de vaste dag|de lengte van een boek|Bij drukte zoekt de bibliotheek een andere plek.',
      'S|Welke samenvatting past?|De bibliobus probeert een latere tijd en bekijkt daarna of de halte werkt.|De bibliobus stopt voorgoed.|De school opent een nieuwe bibliotheek.|De nieuwe tijd wordt geëvalueerd.',
      'S|Welke informatie blijft volgens de tekst zeker?|De bibliobus komt op donderdag.|De halte blijft altijd op het plein.|Elke bezoeker krijgt een boek.|De dag verandert niet.',
      'W|Wat betekent gereserveerd in alinea 2?|voor iemand apart gehouden|zonder omslag|te laat ingeleverd|Een bezoeker wacht op dat boek.',
      'O|Hoe laat stopt de bus vanaf volgende maand?|om vier uur|om drie uur|om vijf uur|De nieuwe tijd staat in alinea 1.',
      'O|Hoe lang blijft de bus staan?|een uur|een kwartier|de hele dag|De duur staat in alinea 2.',
    ],
  );

  card(
    'geluid',
    '''Een stillere straat

1. Bewoners van de Lindenstraat klagen over hard verkeer in de avond. De gemeente plaatst een meter die een week lang geluid registreert. Ze telt ook hoeveel auto's passeren.

2. Op dinsdagavond is het opvallend lawaaiig. Die avond reden er niet méér auto's dan normaal, maar er reed wel een zware vrachtwagen meerdere keren voorbij. De gemeente onderzoekt daarom of zwaar verkeer een andere route kan nemen.

3. De meter blijft nog een tweede week staan. Eén drukke avond is te weinig om een blijvende maatregel op te baseren. Daarna bespreekt de gemeente de resultaten met de bewoners.''',
    [
      'B|Waarom meet de gemeente ook het aantal auto’s?|Zo kan zij geluid met verkeersdrukte vergelijken.|Zo kan zij parkeerbonnen schrijven.|Zo kan zij de meter opladen.|Aantal en geluid kunnen samen worden bekeken.',
      'B|Wat viel op dinsdagavond op?|Veel geluid zonder meer auto’s dan normaal.|Er reed helemaal geen verkeer.|Alle bewoners waren weg.|De vrachtwagen kan het verschil verklaren.',
      'B|Waarom meet de gemeente een tweede week?|Eén avond geeft te weinig basis voor een blijvende maatregel.|De eerste meter was kwijt.|De straat verandert van naam.|Meer metingen geven een betrouwbaarder beeld.',
      'S|Wat is de hoofdgedachte?|De gemeente onderzoekt zorgvuldig waar verkeersgeluid vandaan komt.|De straat wordt meteen afgesloten.|Auto’s zijn altijd de enige oorzaak.|De tekst beschrijft onderzoek vóór een besluit.',
      'S|Welke mogelijke oplossing onderzoekt de gemeente?|Een andere route voor zwaar verkeer.|Alle bewoners laten verhuizen.|De meter verwijderen zonder vervolg.|De vrachtwagen leidt tot dit onderzoek.',
      'W|Wat betekent registreert in alinea 1?|legt metingen vast|maakt geluid harder|houdt auto’s tegen|De meter bewaart geluidsgegevens.',
      'O|Welke straat wordt onderzocht?|de Lindenstraat|de Marktstraat|de Schoolstraat|De naam staat in alinea 1.',
      'O|Wanneer was het opvallend lawaaiig?|op dinsdagavond|op maandagochtend|op zondagmiddag|Het tijdstip staat in alinea 2.',
    ],
  );

  card(
    'zaadjes',
    '''Zaadjes vergelijken

1. Twee groepjes zaaien dezelfde bonen. Groep A zet een pot bij het raam en geeft elke dag water. Groep B zet de pot in een kast en geeft ook elke dag water. Beide potten krijgen evenveel aarde.

2. Na tien dagen heeft groep A groene plantjes. Bij groep B zijn bleke sprieten te zien. De leerlingen denken dat licht een rol speelt, want de andere omstandigheden waren gelijk. Toch weten ze nog niet of de plek in de kast ook warmer was.

3. Ze herhalen de proef met twee plekken waar de temperatuur gelijk is. Zo onderzoeken ze beter welk verschil door licht komt. Hun eerste proef gaf een aanwijzing, maar nog geen volledig antwoord.''',
    [
      'B|Welk verschil wilden de leerlingen eerst onderzoeken?|licht|hoeveelheid water|soort bonen|De ene pot stond bij licht, de andere in een kast.',
      'B|Waarom is de eerste conclusie nog onzeker?|Ook de temperatuur kan hebben verschild.|Groep A kreeg geen water.|De potten hadden andere aarde.|De kast kan warmer zijn geweest.',
      'B|Wat veranderen ze bij de herhaling?|Ze kiezen plekken met gelijke temperatuur.|Ze gebruiken andere bonen.|Ze geven één pot geen water.|Zo blijft vooral het licht over als verschil.',
      'S|Wat leert deze tekst over proeven?|Je probeert één verschil tegelijk te onderzoeken.|Eén proef bewijst altijd alles.|Planten groeien alleen in kasten.|De leerlingen verbeteren hun proefopzet.',
      'S|Welke samenvatting past?|De klas vergelijkt groei met en zonder licht en herhaalt de proef zorgvuldiger.|Groep B wint een plantenwedstrijd.|De bonen groeien helemaal niet.|Eerste waarneming en vervolg horen samen.',
    'W|Wat betekent omstandigheden in alinea 2?|factoren rond de proef, zoals water en aarde|de namen van de leerlingen|de kleuren van de potten|Het gaat om factoren rond de planten.',
      'O|Na hoeveel dagen bekijken ze de eerste groei?|tien dagen|twee dagen|een maand|De tijd staat in alinea 2.',
      'O|Hoe zagen de sprieten van groep B eruit?|bleek|donkergroen|rood|Alinea 2 noemt hun kleur.',
    ],
  );

  card(
    'toneelkaart',
    '''Kaartjes voor het toneelstuk

1. De toneelgroep speelt vrijdag twee voorstellingen. De eerste begint om halfvier en is voor jonge kinderen. De tweede begint om zeven uur en duurt langer, omdat er een extra scène in zit.

2. Kaartjes zijn gratis, maar je moet een plaats reserveren. De zaal heeft zestig stoelen. Ouders die voor beide voorstellingen reserveren, tellen dus twee keer mee bij het aantal plaatsen.

3. Bij de ingang controleert een vrijwilliger de namenlijst. Wie niet kan komen, wordt gevraagd de reservering uiterlijk donderdag af te zeggen. Zo kan iemand op de wachtlijst nog een stoel krijgen.''',
    [
      'B|Waarom duurt de tweede voorstelling langer?|Er zit een extra scène in.|De zaal heeft meer stoelen.|De vrijwilliger is later.|Alinea 1 geeft de reden.',
      'B|Waarom moet je reserveren als kaartjes gratis zijn?|Het aantal stoelen is beperkt.|De acteurs willen geld.|De voorstelling is online.|Er zijn maar zestig stoelen.',
      'B|Waarom moet je tijdig afzeggen?|Iemand op de wachtlijst kan dan een stoel krijgen.|Dan begint de voorstelling eerder.|Dan krijgt iedereen twee kaartjes.|Alinea 3 noemt het vervolg.',
      'S|Wat is vooral het doel van de tekst?|Bezoekers informeren over tijden en reserveren.|Een scène uit het stuk navertellen.|Acteurs beoordelen.|Het bericht geeft praktische bezoekinformatie.',
      'S|Welke voorstelling past bij jonge kinderen?|de eerste voorstelling|de tweede voorstelling|geen van beide|Alinea 1 beschrijft het publiek.',
      'W|Wat betekent wachtlijst in alinea 3?|lijst van mensen die wachten op een plek|lijst van acteurs op het podium|lijst van gespeelde scènes|Een vrijgekomen stoel kan naar iemand op die lijst.',
      'O|Hoeveel stoelen heeft de zaal?|zestig|twintig|honderd|Het aantal staat in alinea 2.',
      'O|Uiterlijk wanneer moet je afzeggen?|donderdag|vrijdagavond|zaterdag|De termijn staat in alinea 3.',
    ],
  );

  return out;
}
