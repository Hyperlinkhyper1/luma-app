import '../quiz_bank.dart';
import 'gen.dart';

const _oudheid = 'Oudheid en middeleeuwen';
const _gouden = 'Ontdekkers, Gouden Eeuw en revoluties';
const _modern = 'Moderne tijd';

/// The ten tijdvakken, in order.
const _tijdvakken = [
  'de tijd van jagers en boeren',
  'de tijd van Grieken en Romeinen',
  'de tijd van monniken en ridders',
  'de tijd van steden en staten',
  'de tijd van ontdekkers en hervormers',
  'de tijd van regenten en vorsten',
  'de tijd van pruiken en revoluties',
  'de tijd van burgers en stoommachines',
  'de tijd van de wereldoorlogen',
  'de tijd van televisie en computer',
];

/// Which of the subject's three topics a tijdvak belongs to.
String _topicFor(int tijdvak) => switch (tijdvak) {
      <= 4 => _oudheid,
      <= 7 => _gouden,
      _ => _modern,
    };

/// `gebeurtenis|jaartal|tijdvaknummer`
const _gebeurtenissen = [
  'De eerste boeren legden akkers aan|rond 10.000 v.Chr.|1',
  'De hunebedden in Drenthe werden gebouwd|rond 3000 v.Chr.|1',
  'De eerste piramides in Egypte werden gebouwd|rond 2600 v.Chr.|2',
  'De eerste Olympische Spelen werden gehouden|776 v.Chr.|2',
  'In Athene ontstond de democratie|rond 500 v.Chr.|2',
  'Alexander de Grote veroverde een groot rijk|rond 330 v.Chr.|2',
  'De Romeinen veroverden Gallie|57 v.Chr.|2',
  'Julius Caesar werd vermoord|44 v.Chr.|2',
  'Het christendom werd de godsdienst van het Romeinse Rijk|380|2',
  'Het West-Romeinse Rijk viel|476|2',
  'Mohammed stichtte de islam|rond 610|3',
  'Willibrord kwam naar de Lage Landen|690|3',
  'Karel de Grote werd tot keizer gekroond|800|3',
  'De Vikingen plunderden Dorestad|834|3',
  'De Slag bij Hastings vond plaats|1066|4',
  'De Eerste Kruistocht begon|1096|4',
  'Marco Polo reisde naar China|rond 1275|4',
  'Veel Nederlandse plaatsen kregen stadsrechten|rond 1250|4',
  'De Hanzesteden kwamen op|rond 1300|4',
  'De pest trof Europa|1348|4',
  'Gutenberg vond de boekdrukkunst uit|rond 1450|4',
  'Columbus bereikte Amerika|1492|5',
  'Vasco da Gama voer om Afrika naar India|1498|5',
  'Magellaan begon de eerste reis om de wereld|1519|5',
  'Maarten Luther publiceerde zijn stellingen|1517|5',
  'De Beeldenstorm brak uit|1566|5',
  'De Tachtigjarige Oorlog begon|1568|5',
  'De watergeuzen namen Den Briel in|1572|5',
  'Willem van Oranje werd vermoord in Delft|1584|5',
  'De VOC werd opgericht|1602|6',
  'Het Twaalfjarig Bestand begon|1609|6',
  'Hugo de Groot ontsnapte in een boekenkist|1621|6',
  'De WIC werd opgericht|1621|6',
  'Piet Hein veroverde de Zilvervloot|1628|6',
  'Abel Tasman bereikte Nieuw-Zeeland|1642|6',
  'De Vrede van Munster maakte een einde aan de oorlog met Spanje|1648|6',
  'Michiel de Ruyter voer naar Chatham|1667|6',
  'Het Rampjaar brak aan|1672|6',
  'De Franse Revolutie begon|1789|7',
  'De Bataafse Republiek werd uitgeroepen|1795|7',
  'Napoleon werd keizer van Frankrijk|1804|7',
  'Napoleon verloor de Slag bij Waterloo|1815|7',
  'Het Koninkrijk der Nederlanden ontstond|1815|7',
  'Belgie scheidde zich af van Nederland|1830|8',
  'De eerste trein reed van Amsterdam naar Haarlem|1839|8',
  'Thorbecke schreef een nieuwe Grondwet|1848|8',
  'De slavernij werd afgeschaft in Suriname en op de Antillen|1863|8',
  'Het Kinderwetje van Van Houten kwam er|1874|8',
  'De leerplicht werd ingevoerd in Nederland|1900|8',
  'De Eerste Wereldoorlog begon|1914|9',
  'De Eerste Wereldoorlog eindigde|1918|9',
  'Vrouwen kregen kiesrecht in Nederland|1919|9',
  'De beurskrach begon de crisisjaren|1929|9',
  'Hitler kwam aan de macht in Duitsland|1933|9',
  'De Tweede Wereldoorlog begon|1939|9',
  'Duitsland viel Nederland binnen|10 mei 1940|9',
  'Rotterdam werd gebombardeerd|14 mei 1940|9',
  'De geallieerden landden in Normandie op D-Day|6 juni 1944|9',
  'De Hongerwinter brak aan|winter van 1944-1945|9',
  'Nederland werd bevrijd|5 mei 1945|9',
  'Er viel een atoombom op Hiroshima|1945|9',
  'De Verenigde Naties werden opgericht|1945|9',
  'Indonesie riep de onafhankelijkheid uit|1945|9',
  'De watersnoodramp trof Zeeland|1953|10',
  'De Berlijnse Muur werd gebouwd|1961|10',
  'De eerste mens zette voet op de maan|1969|10',
  'Suriname werd onafhankelijk|1975|10',
  'De Berlijnse Muur viel|1989|10',
  'De aanslagen in New York vonden plaats|2001|10',
  'De euro werd ingevoerd als contant geld|2002|10',
  'Willem-Alexander werd koning|2013|10',
];

/// `persoon|wat deed die|tijdvaknummer`
const _personen = [
  'Alexander de Grote|Macedonische koning die tot aan India optrok|2',
  'Julius Caesar|Romeins veldheer die Gallie veroverde|2',
  'Cleopatra|de laatste farao van Egypte|2',
  'Karel de Grote|keizer van een groot Frankisch rijk|3',
  'Willibrord|missionaris die het christendom naar de Lage Landen bracht|3',
  'Bonifatius|missionaris die bij Dokkum werd vermoord|3',
  'Floris V|Hollandse graaf uit de middeleeuwen|4',
  'Marco Polo|reiziger die over land naar China trok|4',
  'Gutenberg|uitvinder van de boekdrukkunst met losse letters|4',
  'Erasmus|humanist en schrijver uit Rotterdam|5',
  'Karel V|keizer die de Nederlanden onder zich verenigde|5',
  'Filips II|Spaanse koning tegen wie de opstand ging|5',
  'Willem van Oranje|leider van de opstand tegen Spanje|5',
  'Maarten Luther|monnik die de Reformatie begon|5',
  'Christoffel Columbus|ontdekkingsreiziger die Amerika bereikte|5',
  'Vasco da Gama|zeevaarder die om Afrika naar India voer|5',
  'Ferdinand Magellaan|leider van de eerste reis om de wereld|5',
  'Kenau Simonsdochter Hasselaer|verdedigde Haarlem tegen de Spanjaarden|5',
  'Abel Tasman|ontdekker van Nieuw-Zeeland en Tasmanie|6',
  'Michiel de Ruyter|beroemde Nederlandse admiraal|6',
  'Johan de Witt|raadpensionaris van de Republiek|6',
  'Rembrandt van Rijn|schilder van de Nachtwacht|6',
  'Johannes Vermeer|schilder van het Melkmeisje|6',
  'Antoni van Leeuwenhoek|maakte microscopen en zag als eerste bacterien|6',
  'Piet Hein|veroverde de Zilvervloot|6',
  'Jan Pieterszoon Coen|stichtte Batavia voor de VOC|6',
  'Hugo de Groot|rechtsgeleerde die ontsnapte in een boekenkist|6',
  'Galileo Galilei|onderzocht de sterren met een telescoop|6',
  'Isaac Newton|natuurkundige die de zwaartekracht beschreef|6',
  'Napoleon Bonaparte|Franse keizer die half Europa veroverde|7',
  'James Watt|verbeterde de stoommachine|7',
  'Koning Willem I|de eerste koning van het Koninkrijk der Nederlanden|7',
  'Thorbecke|schreef de Grondwet van 1848|8',
  'Multatuli|schrijver van de Max Havelaar|8',
  'Karl Marx|denker over arbeiders en kapitalisme|8',
  'Aletta Jacobs|eerste vrouwelijke arts en strijdster voor vrouwenkiesrecht|8',
  'Ferdinand Domela Nieuwenhuis|streed voor de rechten van arbeiders|8',
  'Thomas Edison|maakte de gloeilamp bruikbaar|8',
  'Vincent van Gogh|schilder van de Zonnebloemen|8',
  'Anne Frank|joods meisje dat een dagboek schreef in het achterhuis|9',
  'Adolf Hitler|leider van nazi-Duitsland|9',
  'Winston Churchill|Britse premier in de Tweede Wereldoorlog|9',
  'Koningin Wilhelmina|sprak vanuit Londen tot het bezette Nederland|9',
  'Anton de Kom|schrijver en verzetsman uit Suriname|9',
  'Mahatma Gandhi|streed geweldloos voor de onafhankelijkheid van India|9',
  'Marie Curie|onderzocht straling en won twee Nobelprijzen|9',
  'Albert Einstein|natuurkundige van de relativiteitstheorie|9',
  'Neil Armstrong|de eerste mens op de maan|10',
  'Nelson Mandela|streed tegen de apartheid in Zuid-Afrika|10',
  'Martin Luther King|streed voor gelijke rechten in Amerika|10',
  'Willem Drees|premier die de AOW invoerde|10',
];

/// `begrip|betekenis|tijdvaknummer`
const _begrippen = [
  'een hunebed|een grafmonument van grote stenen|1',
  'de limes|de noordgrens van het Romeinse Rijk|2',
  'een amfitheater|een rond gebouw waar de Romeinen spelen hielden|2',
  'het leenstelsel|land geven in ruil voor trouw en krijgsdienst|3',
  'een horige|een boer die niet vrij was en bij het land hoorde|3',
  'een klooster|een gebouw waar monniken of nonnen samen leven|3',
  'een gilde|een vereniging van ambachtslieden in een stad|4',
  'stadsrechten|de rechten die een plaats tot stad maakten|4',
  'een kruistocht|een tocht van christenen naar het Heilige Land|4',
  'een ridder|een geoefend krijger te paard in dienst van een heer|4',
  'de Reformatie|de beweging die de kerk wilde vernieuwen|5',
  'de inquisitie|de kerkelijke rechtbank tegen ketters|5',
  'de watergeuzen|opstandelingen die vanaf het water vochten|5',
  'de Beeldenstorm|het vernielen van beelden in kerken|5',
  'de VOC|de handelscompagnie die naar Azie voer|6',
  'de WIC|de handelscompagnie die naar Amerika en Afrika voer|6',
  'een regent|een bestuurder van een stad in de Republiek|6',
  'een stadhouder|legeraanvoerder en bestuurder in de Republiek|6',
  'de Gouden Eeuw|de bloeitijd van de Republiek in de 17e eeuw|6',
  'slavernij|mensen als bezit laten werken zonder vrijheid|6',
  'een plantage|een groot landbouwbedrijf in de kolonien|6',
  'de patriotten|Nederlanders die meer inspraak eisten|7',
  'de Verlichting|de tijd waarin denkers de rede vooropstelden|7',
  'een grondwet|de wet met de belangrijkste regels van een land|7',
  'de industriele revolutie|de tijd waarin machines het werk overnamen|8',
  'een stoommachine|een machine die met stoom kracht levert|8',
  'kinderarbeid|kinderen die in fabrieken moesten werken|8',
  'een vakbond|een organisatie die opkomt voor werknemers|8',
  'kiesrecht|het recht om te stemmen|8',
  'een kolonie|een gebied dat door een ander land wordt bestuurd|8',
  'een loopgraaf|een diepe gracht waarin soldaten schuilden|9',
  'mobilisatie|het leger klaarmaken voor oorlog|9',
  'neutraal|geen partij kiezen in een oorlog|9',
  'de crisisjaren|de jaren met veel werkloosheid en armoede|9',
  'de Holocaust|de moord op zes miljoen Joden|9',
  'het verzet|mensen die in het geheim tegen de bezetter streden|9',
  'onderduiken|je verstoppen voor de bezetter|9',
  'distributiebonnen|bonnen waarmee je in de oorlog eten kon kopen|9',
  'een razzia|een plotselinge klopjacht op mensen|9',
  'de bevrijding|het einde van de bezetting|9',
  'de Koude Oorlog|de spanning tussen Amerika en de Sovjet-Unie|10',
  'de Marshallhulp|Amerikaans geld om Europa weer op te bouwen|10',
  'dekolonisatie|kolonien die zelfstandig worden|10',
  'de wederopbouw|het herstellen van het land na de oorlog|10',
  'verzuiling|een samenleving verdeeld in groepen met eigen clubs|10',
  'emancipatie|het opkomen voor gelijke rechten|10',
  'een democratie|een bestuursvorm waarin het volk kiest|10',
  'een dictatuur|een bestuursvorm waarin een persoon alle macht heeft|10',
  'een republiek|een staat zonder koning|10',
  'een monarchie|een staat met een koning of koningin|10',
  'een archeoloog|iemand die sporen uit het verleden opgraaft|1',
  'een historische bron|iets uit het verleden waar je iets uit leert|1',
  'een eeuw|een periode van honderd jaar|1',
  'de jaartelling|de manier waarop we jaren tellen vanaf een startpunt|2',
];

String _eeuw(int jaar) {
  final n = ((jaar - 1) ~/ 100) + 1;
  return '${n}e eeuw';
}

/// The generated part of the geschiedenis bank.
List<QuizQuestion> buildGeschiedenisExtra() {
  final g = QuizGen('ggs', seed: 20260912);

  // --- Gebeurtenissen --------------------------------------------------------
  final ev = rows(_gebeurtenissen);
  final jaartallen = [for (final e in ev) e[1]];
  final omschrijvingen = [for (final e in ev) e[0]];
  for (final e in ev) {
    final tijdvak = int.parse(e[2]);
    final topic = _topicFor(tijdvak);
    g.add(
      topic: topic,
      prompt: 'Wanneer gebeurde dit? ${e[0]}.',
      answer: e[1],
      wrong: g.others(jaartallen, e[1]),
      why: 'Dit hoort bij ${_tijdvakken[tijdvak - 1]}.',
    );
    g.add(
      topic: topic,
      prompt: 'Bij welk tijdvak hoort dit? ${e[0]}.',
      answer: _tijdvakken[tijdvak - 1],
      wrong: g.others(_tijdvakken, _tijdvakken[tijdvak - 1]),
      why: 'Het gebeurde in ${e[1]}.',
    );
    // Only when the year points at exactly one event — 1945 alone carries
    // four of them.
    if (jaartallen.where((j) => j == e[1]).length == 1) {
      g.add(
        topic: topic,
        prompt: 'Wat gebeurde er in ${e[1]}?',
        answer: e[0],
        wrong: g.others(omschrijvingen, e[0]),
      );
    }
  }

  // --- Personen --------------------------------------------------------------
  final pers = rows(_personen);
  final namen = [for (final p in pers) p[0]];
  final daden = [for (final p in pers) p[1]];
  for (final p in pers) {
    final tijdvak = int.parse(p[2]);
    final topic = _topicFor(tijdvak);
    g.add(
      topic: topic,
      prompt: 'Wie was ${p[0]}?',
      answer: p[1],
      wrong: g.others(daden, p[1]),
      why: '${p[0]} hoort bij ${_tijdvakken[tijdvak - 1]}.',
    );
    g.add(
      topic: topic,
      prompt: 'Over wie gaat dit? "${p[1]}"',
      answer: p[0],
      wrong: g.others(namen, p[0]),
    );
    g.add(
      topic: topic,
      prompt: 'In welk tijdvak leefde ${p[0]}?',
      answer: _tijdvakken[tijdvak - 1],
      wrong: g.others(_tijdvakken, _tijdvakken[tijdvak - 1]),
    );
  }

  // --- Begrippen -------------------------------------------------------------
  final beg = rows(_begrippen);
  final betekenissen = [for (final b in beg) b[1]];
  final begrippen = [for (final b in beg) b[0]];
  for (final b in beg) {
    final topic = _topicFor(int.parse(b[2]));
    g.add(
      topic: topic,
      prompt: 'Wat is ${b[0]}?',
      answer: b[1],
      wrong: g.others(betekenissen, b[1]),
    );
    g.add(
      topic: topic,
      prompt: 'Welk woord hoort hierbij? "${b[1]}"',
      answer: b[0],
      wrong: g.others(begrippen, b[0]),
    );
  }

  // --- De tien tijdvakken ----------------------------------------------------
  for (var i = 0; i < _tijdvakken.length; i++) {
    if (i < _tijdvakken.length - 1) {
      g.add(
        topic: _topicFor(i + 1),
        prompt: 'Welk tijdvak komt direct ná ${_tijdvakken[i]}?',
        answer: _tijdvakken[i + 1],
        wrong: g.others(_tijdvakken, _tijdvakken[i + 1]),
        why: 'De tijdvakken staan in volgorde; dit is tijdvak ${i + 2}.',
      );
    }
    if (i > 0) {
      g.add(
        topic: _topicFor(i + 1),
        prompt: 'Welk tijdvak komt direct vóór ${_tijdvakken[i]}?',
        answer: _tijdvakken[i - 1],
        wrong: g.others(_tijdvakken, _tijdvakken[i - 1]),
      );
    }
    g.add(
      topic: _topicFor(i + 1),
      prompt: 'Het hoeveelste tijdvak is ${_tijdvakken[i]}?',
      answer: 'het ${i + 1}e tijdvak',
      wrong: [
        for (var k = 0; k < _tijdvakken.length; k++)
          if (k != i) 'het ${k + 1}e tijdvak',
      ]..shuffle(g.rnd),
    );
  }

  // --- Eeuwen rekenen --------------------------------------------------------
  for (var i = 0; i < 34; i++) {
    final jaar = g.between(1002, 2020);
    g.add(
      topic: _topicFor(jaar < 1500 ? 4 : (jaar < 1800 ? 6 : 9)),
      prompt: 'In welke eeuw ligt het jaar $jaar?',
      answer: _eeuw(jaar),
      wrong: [
        _eeuw(jaar + 100),
        _eeuw(jaar - 100),
        '${jaar ~/ 100}e eeuw',
        _eeuw(jaar + 200),
      ],
      why: 'Het jaar $jaar hoort bij de ${((jaar - 1) ~/ 100) + 1}e eeuw: de '
          'eeuw loopt van ${((jaar - 1) ~/ 100) * 100 + 1} tot en met '
          '${((jaar - 1) ~/ 100) * 100 + 100}.',
    );
  }

  for (var i = 0; i < 16; i++) {
    final eeuw = g.between(11, 21);
    g.add(
      topic: _topicFor(eeuw < 16 ? 4 : (eeuw < 19 ? 6 : 9)),
      prompt: 'Van welk jaar tot welk jaar loopt de ${eeuw}e eeuw?',
      answer: 'van ${(eeuw - 1) * 100 + 1} tot en met ${eeuw * 100}',
      wrong: [
        'van ${(eeuw - 1) * 100} tot en met ${eeuw * 100 - 1}',
        'van ${eeuw * 100} tot en met ${eeuw * 100 + 99}',
        'van ${(eeuw - 2) * 100 + 1} tot en met ${(eeuw - 1) * 100}',
        'van ${(eeuw - 1) * 100 + 1} tot en met ${eeuw * 100 + 100}',
      ],
      why: 'De eerste eeuw liep van het jaar 1 tot en met 100.',
    );
  }

  return g.questions;
}
