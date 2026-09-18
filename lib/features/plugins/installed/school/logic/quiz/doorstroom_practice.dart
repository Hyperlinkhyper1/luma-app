import '../quiz_bank.dart';
import 'gen.dart';

/// Original practice material; not an official or calibrated test.
List<QuizQuestion> buildDoorstroomRekenen() {
  final g = QuizGen('dsrek', seed: 810);
  const items = [
    (
      'Getallen en bewerkingen',
      'Er gaan 146 leerlingen op reis. In een bus passen 48 leerlingen. Hoeveel bussen zijn minimaal nodig?',
      '4',
      ['3', '5', '6'],
      'Drie bussen hebben 144 plaatsen. Voor de laatste twee leerlingen is een vierde bus nodig.',
    ),
    (
      'Getallen en bewerkingen',
      'Noor koopt 3 schriften van €2,45 en een pen van €1,80. Ze betaalt met €10. Hoeveel krijgt ze terug?',
      '€0,85',
      ['€1,15', '€2,65', '€9,15'],
      '3 × 2,45 + 1,80 = 9,15. Van 10 euro blijft 0,85 euro over.',
    ),
    (
      'Verhoudingen',
      'Een rugzak kost na 20% korting €48. Wat was de prijs vóór de korting?',
      '€60',
      ['€57,60', '€38,40', '€68'],
      '48 euro is 80%. Deel door 8 voor 10% en vermenigvuldig met 10: 60 euro.',
    ),
    (
      'Verhoudingen',
      'Je mengt 1 deel siroop met 7 delen water. Hoeveel siroop heb je nodig voor 2 liter drinken?',
      '250 ml',
      ['125 ml', '285 ml', '1750 ml'],
      'Er zijn 8 delen samen. 2000 ml : 8 = 250 ml siroop.',
    ),
    (
      'Meten en meetkunde',
      'Een rechthoekig terras is 3 m bij 2 m. Je legt vierkante tegels van 50 cm bij 50 cm zonder voegen. Hoeveel tegels zijn nodig?',
      '24',
      ['6', '12', '48'],
      'Langs de lengte passen 6 tegels en langs de breedte 4. Samen 6 × 4 = 24.',
    ),
    (
      'Meten en meetkunde',
      'Een trein vertrekt om 23:45 en komt om 00:20 de volgende dag aan. Hoe lang duurt de reis?',
      '35 minuten',
      ['25 minuten', '45 minuten', '75 minuten'],
      'Tot middernacht duurt het 15 minuten en daarna nog 20 minuten.',
    ),
    (
      'Verbanden',
      'Fietsverhuur A kost €5 vast plus €3 per uur. Verhuur B kost €4 per uur zonder vast bedrag. Na hoeveel uur zijn de kosten gelijk?',
      '5 uur',
      ['3 uur', '4 uur', '8 uur'],
      'Bij 5 uur kost A 5 + 3 × 5 = 20 euro en B 4 × 5 = 20 euro.',
    ),
    (
      'Verbanden',
      'Uitgeleende boeken: maandag 24, dinsdag 36, woensdag 18 en donderdag 42. Welk deel van deze boeken is op donderdag uitgeleend?',
      '35%',
      ['25%', '30%', '42%'],
      'Samen zijn het 120 boeken. 42 van 120 is 35 van 100, dus 35%.',
    ),
  ];
  for (final q in items) {
    g.add(topic: q.$1, prompt: q.$2, answer: q.$3, wrong: q.$4, why: q.$5);
  }
  return g.questions;
}

List<QuizQuestion> buildDoorstroomTaal() {
  final g = QuizGen('dstv', seed: 811);
  const items = [
    (
      'Werkwoordspelling',
      'Vul in: … je broer morgen twaalf? (worden)',
      'Wordt',
      ['Word', 'Wort', 'Worden'],
      'Het onderwerp is je broer, niet je. Je broer kun je vervangen door hij: hij wordt.',
    ),
    (
      'Werkwoordspelling',
      'Vul in: … je morgen twaalf? (worden)',
      'Word',
      ['Wordt', 'Wort', 'Worden'],
      'Je betekent hier jij en staat achter de persoonsvorm. Daarom gebruik je word.',
    ),
    (
      'Werkwoordspelling',
      'Vul in: De trainer heeft ons een beloning … (beloven)',
      'beloofd',
      ['belooft', 'beloofde', 'beloofdt'],
      'Het is een voltooid deelwoord: beloofd. De verleden tijd is beloofde.',
    ),
    (
      'Spelling niet-werkwoorden',
      'Vul in: In de dierentuin zagen we drie …',
      "baby's",
      ['babys', 'babies', 'babyen'],
      'In het Nederlands schrijf je na de y met medeklinker ervoor een apostrof voor de meervouds-s.',
    ),
    (
      'Spelling niet-werkwoorden',
      'Welke zin heeft de juiste spelling?',
      'De conciërge helpt ons.',
      [
        'De concierge helpt ons.',
        'De conci-erge helpt ons.',
        'De concïerge helpt ons.',
      ],
      'Het trema in conciërge laat zien waar een nieuwe lettergreep begint.',
    ),
    (
      'Spelling niet-werkwoorden',
      'Welke zin gebruikt de hoofdletters goed?',
      'Op woensdag oefenen we Engels.',
      [
        'Op Woensdag oefenen we Engels.',
        'Op woensdag oefenen we engels.',
        'op woensdag oefenen we Engels.',
      ],
      'Een zin begint met een hoofdletter. Een taalnaam ook, maar een dagnaam niet.',
    ),
    (
      'Leestekens',
      'Welke zin zet de naam van de aangesproken persoon tussen kommas?',
      'Wil jij, Noor, het raam sluiten?',
      [
        'Wil, jij Noor het raam sluiten?',
        'Wil jij Noor het raam, sluiten?',
        'Wil jij Noor, het raam sluiten?',
      ],
      'Noor wordt aangesproken. De naam onderbreekt de zin en staat tussen kommas.',
    ),
    (
      'Leestekens',
      'Welk leesteken kondigt de opsomming aan? Je hebt dit nodig … een schaar, papier en lijm.',
      'een dubbele punt',
      ['een vraagteken', 'een uitroepteken', 'een puntkomma'],
      'De woorden dit nodig kondigen aan wat na de dubbele punt wordt opgesomd.',
    ),
  ];
  for (final q in items) {
    g.add(topic: q.$1, prompt: q.$2, answer: q.$3, wrong: q.$4, why: q.$5);
  }
  return g.questions;
}

List<QuizQuestion> buildDoorstroomLezen() {
  final g = QuizGen('dslz', seed: 812);
  const proef =
      'De leerlingenraad wil een stil lokaal tijdens de middagpauze. '
      'Sommige leerlingen willen dan lezen, anderen werken liever een taak af. '
      'De directeur twijfelt: er moet ook iemand toezicht houden. Daarom komt '
      'er eerst een proef van vier weken, op dinsdag en donderdag. Meester '
      'Bakker houdt toezicht. Na afloop vraagt de leerlingenraad aan bezoekers '
      'én niet-bezoekers wat zij van de proef vinden. Pas daarna besluit de '
      'directeur of het lokaal vaker open kan. De proef is dus voorlopig.';
  const ruil =
      'Bericht van de bibliotheek\n'
      'Zaterdag is er van 10.00 tot 12.00 uur een boekenruil voor kinderen. '
      'Lever tussen 9.30 en 10.00 uur maximaal drie complete, onbeschadigde '
      'kinderboeken in. Voor elk goedgekeurd boek krijg je één bon. Vanaf '
      '10.00 uur kun je met elke bon één ander boek uitzoeken. Schoolboeken '
      'en tijdschriften doen niet mee. Overgebleven bonnen kun je alleen '
      'tijdens deze ochtend gebruiken.\n\n'
      'Reactie van Eva: Ik vind de ruil een goed idee, want zo kan ik iets '
      'nieuws lezen zonder een boek te kopen. Ik zou het wel fijner vinden '
      'als mijn bonnen ook de volgende keer geldig waren.';
  const items = [
    (
      'Begrijpen en interpreteren',
      proef,
      'Waarom komt er eerst een proef?',
      'De directeur wil het idee uitproberen voordat hij een blijvende beslissing neemt.',
      [
        'De leerlingenraad heeft al besloten dat het lokaal elke dag opengaat.',
        'Er zijn geen leerlingen die willen lezen.',
        'Meester Bakker wil geen toezicht houden.',
      ],
      'De directeur twijfelt nog en neemt pas na de proef een besluit.',
    ),
    (
      'Samenvatten',
      proef,
      'Welke samenvatting noemt zowel het plan als de manier waarop erover wordt beslist?',
      'De school probeert een stil pauzelokaal uit en beslist na reacties of het vaker opengaat.',
      [
        'De school opent voortaan elke pauze een stil lokaal.',
        'Meester Bakker gaat vier weken boeken voorlezen.',
        'De leerlingenraad vraagt alleen lezers naar hun favoriete boek.',
      ],
      'Deze samenvatting bevat het voorstel, de proef en de beslissing achteraf.',
    ),
    (
      'Woordenschat',
      proef,
      'Wat betekent voorlopig in de laatste zin?',
      'voor nu, zonder dat het al definitief is',
      ['vanaf nu voor altijd', 'zonder toestemming', 'pas over een paar jaar'],
      'Er volgt nog een besluit na vier weken.',
    ),
    (
      'Begrijpen en interpreteren',
      proef,
      'Waarom is het zinvol om ook niet-bezoekers om hun mening te vragen?',
      'Zij kunnen vertellen waarom ze het lokaal niet gebruiken.',
      [
        'Zij kunnen precies tellen wie er binnen was.',
        'Hun mening bewijst dat het lokaal moet sluiten.',
        'Zij moeten het toezicht van de meester overnemen.',
      ],
      'Zo krijgt de leerlingenraad ook informatie van leerlingen die niet meedoen.',
    ),
    (
      'Opzoeken',
      ruil,
      'Lina komt om 10.30 uur met boeken die ze nog moet inleveren. Kan dat volgens het bericht?',
      'Nee, inleveren kon tot 10.00 uur.',
      [
        'Ja, inleveren kan tot 12.00 uur.',
        'Ja, maar alleen schoolboeken.',
        'Nee, boeken mag je alleen op vrijdag inleveren.',
      ],
      'Inleveren en uitzoeken hebben verschillende tijden.',
    ),
    (
      'Samenvatten',
      ruil,
      'Wat is het belangrijkste doel van het bericht van de bibliotheek?',
      'Uitleggen wanneer de boekenruil is en hoe meedoen werkt.',
      [
        'Bewijzen dat ruilen beter is dan kopen.',
        'Vertellen welke boeken Eva het leukst vindt.',
        'Reclame maken voor nieuwe schoolboeken.',
      ],
      'Het bericht geeft tijden, voorwaarden en uitleg over de bonnen.',
    ),
    (
      'Woordenschat',
      ruil,
      'Waarnaar verwijst zo in de reactie van Eva?',
      'naar het ruilen van boeken',
      [
        'naar het kopen van een boek',
        'naar het bewaren van bonnen',
        'naar het inleveren van tijdschriften',
      ],
      'Door boeken te ruilen kan Eva iets nieuws lezen zonder iets te kopen.',
    ),
    (
      'Begrijpen en interpreteren',
      ruil,
      'Over welke regel zou Eva iets willen veranderen?',
      'Bonnen zijn alleen deze ochtend geldig.',
      [
        'Er mogen maximaal drie boeken mee.',
        'Boeken moeten onbeschadigd zijn.',
        'De ruil is voor kinderen.',
      ],
      'Eva wil haar bonnen ook een volgende keer kunnen gebruiken.',
    ),
  ];
  for (final q in items) {
    g.add(
      topic: q.$1,
      passage: q.$2,
      prompt: q.$3,
      answer: q.$4,
      wrong: q.$5,
      why: q.$6,
    );
  }
  return g.questions;
}
