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

const _oudheid = 'Oudheid en middeleeuwen';
const _gouden = 'Ontdekkers, Gouden Eeuw en revoluties';
const _modern = 'Moderne tijd';

/// Geschiedenis, extra oefening voor bovenbouw en brugklas; geen doorstroomtoetsvak. Volgt de tien tijdvakken.
final List<QuizQuestion> geschiedenisQuestions = [
  // --- Oudheid en middeleeuwen ---------------------------------------------
  _q('gs-001', _oudheid, 'Hoe leefden de mensen in de prehistorie eerst?',
      [
        'als jagers en verzamelaars',
        'als boeren in dorpen',
        'als handelaren in steden',
        'als ridders op kastelen'
      ],
      0,
      'Pas later, in de landbouwrevolutie, gingen mensen akkers bewerken.'),
  _q('gs-002', _oudheid, 'Wat zijn hunebedden?',
      [
        'grafmonumenten van grote keien in Drenthe',
        'Romeinse wachttorens',
        'middeleeuwse kerken',
        'oude waterputten'
      ],
      0),
  _q('gs-003', _oudheid, 'Waarvoor bouwden de oude Egyptenaren piramides?',
      [
        'als graven voor hun farao’s',
        'als graanschuren',
        'als forten tegen vijanden',
        'als sterrenwachten'
      ],
      0),
  _q('gs-004', _oudheid, 'Hoe heet het schrift van de oude Egyptenaren?',
      ['spijkerschrift', 'hiërogliefen', 'runen', 'het Latijnse alfabet'], 1),
  _q('gs-005', _oudheid, 'In welke Griekse stad ontstond de eerste vorm van democratie?',
      ['Sparta', 'Athene', 'Korinthe', 'Troje'], 1),
  _q('gs-006', _oudheid, 'Wat betekent het woord "democratie" letterlijk?',
      ['volksregering', 'koningsmacht', 'wet van de goden', 'macht van het leger'],
      0),
  _q('gs-007', _oudheid, 'Wie was Julius Caesar?',
      [
        'een Romeinse veldheer en staatsman',
        'een Griekse filosoof',
        'een Egyptische farao',
        'een Frankische koning'
      ],
      0),
  _q('gs-008', _oudheid, 'Hoe heette de noordgrens van het Romeinse Rijk die door Nederland liep?',
      ['de Limes', 'de Muur van Hadrianus', 'de Via Appia', 'de Rubicon'], 0,
      'De Limes liep langs de Rijn, ongeveer van Katwijk tot Nijmegen.'),
  _q('gs-009', _oudheid, 'Wat lieten de Romeinen in Nederland achter?',
      [
        'wegen, badhuizen en de stad Nijmegen',
        'kastelen met ophaalbruggen',
        'windmolens',
        'kanalen met sluizen'
      ],
      0),
  _q('gs-010', _oudheid, 'In welk jaar werd Karel de Grote tot keizer gekroond?',
      ['400', '800', '1000', '1200'], 1),
  _q('gs-011', _oudheid, 'Wat was het leenstelsel in de middeleeuwen?',
      [
        'een heer gaf land in ruil voor trouw en hulp in de oorlog',
        'boeren leenden geld van de kerk',
        'steden leenden soldaten aan elkaar uit',
        'de koning verhuurde schepen'
      ],
      0),
  _q('gs-012', _oudheid, 'Wat deden monniken in middeleeuwse kloosters onder andere?',
      [
        'boeken met de hand overschrijven',
        'kanonnen gieten',
        'schepen bouwen',
        'munten slaan voor de koning'
      ],
      0),
  _q('gs-013', _oudheid, 'Wat was een gilde?',
      [
        'een vereniging van ambachtslieden met hetzelfde beroep',
        'een groep ridders in dienst van de koning',
        'een middeleeuws rechtbank',
        'een school voor monniken'
      ],
      0),
  _q('gs-014', _oudheid, 'Wat kregen steden in de middeleeuwen met stadsrechten?',
      [
        'het recht om markt te houden en zichzelf te besturen',
        'een gratis kasteel',
        'vrijstelling van de pest',
        'het recht om oorlog te voeren tegen de koning'
      ],
      0),
  _q('gs-015', _oudheid, 'Wat was de Hanze?',
      [
        'een samenwerkingsverband van handelssteden rond de Noord- en Oostzee',
        'een leger van kruisvaarders',
        'een groep Nederlandse graven',
        'een middeleeuwse ziekte'
      ],
      0,
      'Kampen, Deventer en Zwolle waren Nederlandse hanzesteden.'),
  _q('gs-016', _oudheid, 'Welke ziekte trof Europa hard in de veertiende eeuw?',
      ['de pest', 'de pokken', 'cholera', 'malaria'], 0),
  _q('gs-017', _oudheid, 'Wie ontwikkelde rond 1450 in Europa een drukpers met losse metalen letters?',
      ['Johannes Gutenberg', 'Leonardo da Vinci', 'Erasmus', 'Willem Barentsz'], 0),
  _q('gs-018', _oudheid, 'Waarom was de boekdrukkunst zo belangrijk?',
      [
        'kennis kon veel sneller en goedkoper verspreid worden',
        'boeken werden mooier versierd',
        'monniken hoefden niet meer te lezen',
        'de kerk kreeg er meer macht door'
      ],
      0),

  // --- Ontdekkers, Gouden Eeuw en revoluties -------------------------------
  _q('gs-019', _gouden, 'In welk jaar bereikte Columbus Amerika?',
      ['1452', '1492', '1522', '1592'], 1),
  _q('gs-020', _gouden, 'Wat zocht Willem Barentsz toen hij op Nova Zembla strandde?',
      [
        'een noordelijke vaarroute naar Azië',
        'goud in Amerika',
        'nieuwe visgronden',
        'de Zuidpool'
      ],
      0),
  _q('gs-021', _gouden, 'Hoe heette de opstand van de Nederlanden tegen de Spaanse koning?',
      [
        'de Tachtigjarige Oorlog',
        'de Honderdjarige Oorlog',
        'de Boerenoorlog',
        'de Franse tijd'
      ],
      0,
      'Die oorlog duurde van 1568 tot 1648.'),
  _q('gs-022', _gouden, 'Wie wordt de "Vader des Vaderlands" genoemd?',
      ['Willem van Oranje', 'Michiel de Ruyter', 'Johan van Oldenbarnevelt', 'Karel V'],
      0),
  _q('gs-023', _gouden, 'In welke stad werd Willem van Oranje in 1584 vermoord?',
      ['Delft', 'Den Haag', 'Breda', 'Leiden'], 0),
  _q('gs-024', _gouden, 'In welk jaar werd de VOC opgericht?',
      ['1568', '1602', '1648', '1672'], 1),
  _q('gs-025', _gouden, 'Waar handelde de VOC vooral in?',
      ['specerijen', 'wapens', 'wol', 'steenkool'], 0),
  _q('gs-026', _gouden, 'Wat wordt bedoeld met de Gouden Eeuw?',
      [
        'de zeventiende eeuw, waarin de Republiek rijk en machtig was',
        'de eeuw waarin goud werd ontdekt in Nederland',
        'de tijd van Karel de Grote',
        'de negentiende eeuw met haar fabrieken'
      ],
      0),
  _q('gs-027', _gouden, 'Wie schilderde De Nachtwacht?',
      ['Rembrandt van Rijn', 'Johannes Vermeer', 'Vincent van Gogh', 'Frans Hals'], 0),
  _q('gs-028', _gouden, 'Welke keerzijde had de rijkdom van de Gouden Eeuw?',
      [
        'de handel in tot slaaf gemaakte mensen',
        'de uitvinding van het buskruit',
        'de pestepidemie',
        'de val van het Romeinse Rijk'
      ],
      0),
  _q('gs-029', _gouden, 'Wie was Michiel de Ruyter?',
      [
        'een Nederlandse admiraal',
        'een schilder uit Delft',
        'een raadpensionaris',
        'een ontdekkingsreiziger naar Australië'
      ],
      0),
  _q('gs-030', _gouden, 'Hoe wordt het jaar 1672 in Nederland genoemd?',
      ['het Rampjaar', 'het Wonderjaar', 'het Gouden Jaar', 'het Hongerjaar'], 0,
      '"Het volk redeloos, de regering radeloos, het land reddeloos."'),
  _q('gs-031', _gouden, 'Wat was de Verlichting?',
      [
        'een stroming die vertrouwde op verstand en wetenschap',
        'de uitvinding van de gloeilamp',
        'een godsdienstige beweging in kloosters',
        'de ontdekking van elektriciteit'
      ],
      0),
  _q('gs-032', _gouden, 'In welk jaar begon de Franse Revolutie?',
      ['1776', '1789', '1795', '1815'], 1),
  _q('gs-033', _gouden, 'Wat waren de leuzen van de Franse Revolutie?',
      [
        'vrijheid, gelijkheid en broederschap',
        'brood, land en vrede',
        'God, Nederland en Oranje',
        'orde, rust en gezag'
      ],
      0),
  _q('gs-034', _gouden, 'Wie was Napoleon Bonaparte?',
      [
        'een Franse keizer die grote delen van Europa veroverde',
        'een Engelse koning',
        'een Nederlandse admiraal',
        'een Duitse uitvinder'
      ],
      0),
  _q('gs-035', _gouden, 'Wanneer ontstond het Koninkrijk der Nederlanden?',
      ['1795', '1806', '1815', '1848'], 2,
      'Willem I werd in maart 1815 koning, vóór de Slag bij Waterloo.'),
  _q('gs-036', _gouden, 'Wie schreef in 1848 de nieuwe Nederlandse grondwet?',
      ['Thorbecke', 'Willem I', 'Troelstra', 'Kuyper'], 0,
      'Daardoor werd Nederland een parlementaire democratie.'),

  // --- Moderne tijd ---------------------------------------------------------
  _q('gs-037', _modern, 'Wat maakte de stoommachine mogelijk?',
      [
        'fabrieken en treinen die niet van wind of spierkracht afhingen',
        'het drukken van boeken',
        'het bouwen van kastelen',
        'de ontdekking van Amerika'
      ],
      0),
  _q('gs-038', _modern, 'Tussen welke twee steden reed in 1839 de eerste Nederlandse trein?',
      [
        'Amsterdam en Haarlem',
        'Rotterdam en Den Haag',
        'Utrecht en Arnhem',
        'Groningen en Leeuwarden'
      ],
      0),
  _q('gs-039', _modern, 'In welk jaar werd de slavernij in Suriname en op de Nederlandse Antillen wettelijk afgeschaft?',
      ['1848', '1863', '1873', '1900'], 1,
      'De afschaffing gold vanaf 1 juli 1863, met een overgangsperiode van tien jaar.'),
  _q('gs-040', _modern, 'Wat was kinderarbeid, en wat gebeurde ermee?',
      [
        'kinderen werkten in fabrieken; het Kinderwetje van Van Houten beperkte dat in 1874',
        'kinderen werkten op school; dat werd in 1900 verboden',
        'kinderen dienden in het leger; dat stopte in 1815',
        'kinderen werkten alleen op zondag'
      ],
      0),
  _q('gs-041', _modern, 'Wanneer duurde de Eerste Wereldoorlog?',
      ['1914–1918', '1918–1922', '1939–1945', '1900–1910'], 0),
  _q('gs-042', _modern, 'Welke rol speelde Nederland in de Eerste Wereldoorlog?',
      ['het bleef neutraal', 'het vocht mee met Duitsland', 'het vocht mee met Frankrijk', 'het werd bezet'],
      0),
  _q('gs-043', _modern, 'Wanneer kregen vrouwen in Nederland actief kiesrecht?',
      ['1917', '1919', '1945', '1956'], 1),
  _q('gs-044', _modern, 'Op welke datum vielen de Duitsers Nederland binnen?',
      ['1 september 1939', '10 mei 1940', '14 mei 1940', '6 juni 1944'], 1),
  _q('gs-045', _modern, 'Welke Nederlandse stad werd op 14 mei 1940 gebombardeerd?',
      ['Rotterdam', 'Arnhem', 'Nijmegen', 'Middelburg'], 0),
  _q('gs-046', _modern, 'Wie was Anne Frank?',
      [
        'een Joods meisje dat ondergedoken haar dagboek schreef',
        'een verzetsstrijdster uit Haarlem',
        'de eerste vrouwelijke minister',
        'een schrijfster uit de Gouden Eeuw'
      ],
      0),
  _q('gs-047', _modern, 'Hoe heette de zware winter van 1944–1945 in het westen van Nederland?',
      ['de Hongerwinter', 'de IJswinter', 'de Bezettingswinter', 'de Elfstedenwinter'],
      0),
  _q('gs-048', _modern, 'Op welke datum wordt de bevrijding van Nederland herdacht?',
      ['4 mei', '5 mei', '10 mei', '15 augustus'], 1,
      '4 mei is Dodenherdenking, 5 mei Bevrijdingsdag.'),
  _q('gs-049', _modern, 'Wat gebeurde er in 1953 in Zeeland en Zuid-Holland?',
      [
        'de watersnoodramp',
        'de opening van de Afsluitdijk',
        'de bouw van de eerste kerncentrale',
        'de aanleg van de Flevopolder'
      ],
      0),
  _q('gs-050', _modern, 'Welke voormalige Nederlandse kolonie riep in 1945 de onafhankelijkheid uit?',
      ['Indonesië', 'Suriname', 'Curaçao', 'Zuid-Afrika'], 0,
      'Nederland erkende die onafhankelijkheid pas in 1949.'),
  _q('gs-051', _modern, 'In welk jaar werd Suriname onafhankelijk?',
      ['1949', '1963', '1975', '1986'], 2),
  _q('gs-052', _modern, 'Wat was de Koude Oorlog?',
      [
        'de spanning tussen de Verenigde Staten en de Sovjet-Unie na 1945',
        'een oorlog op de Noordpool',
        'de strijd om Antarctica',
        'de oorlog in Korea alleen'
      ],
      0),
  _q('gs-053', _modern, 'Wat gebeurde er in 1969 voor het eerst?',
      [
        'er liep een mens op de maan',
        'de eerste computer werd verkocht',
        'de euro werd ingevoerd',
        'het internet werd uitgevonden'
      ],
      0),
  _q('gs-054', _modern, 'Wat gebeurde er in 1989 in Berlijn?',
      ['de Muur viel', 'de stad werd gebombardeerd', 'de Olympische Spelen begonnen', 'de EU werd opgericht'],
      0),
  _q('gs-055', _modern, 'Wanneer werd de euro als contant geld in Nederland ingevoerd?',
      ['1992', '1999', '2002', '2010'], 2,
      'Girale euro’s bestonden al vanaf 1999, munten en biljetten kwamen in 2002.'),
];
