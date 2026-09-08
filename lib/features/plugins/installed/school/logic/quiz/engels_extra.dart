import '../quiz_bank.dart';
import 'gen.dart';

const _woorden = 'Woordenschat';
const _grammatica = 'Grammatica';
const _tijden = 'Werkwoordstijden';

/// `english|nederlands`
const _vocab = [
  'airport|vliegveld',
  'answer|antwoord',
  'aunt|tante',
  'autumn|herfst',
  'bakery|bakkerij',
  'beach|strand',
  'bear|beer',
  'bedroom|slaapkamer',
  'bee|bij',
  'bell|bel',
  'bicycle|fiets',
  'bird|vogel',
  'blanket|deken',
  'blood|bloed',
  'boat|boot',
  'bone|bot',
  'bookshop|boekwinkel',
  'bottle|fles',
  'bread|brood',
  'bridge|brug',
  'brush|borstel',
  'building|gebouw',
  'butter|boter',
  'butterfly|vlinder',
  'candle|kaars',
  'carpet|tapijt',
  'castle|kasteel',
  'ceiling|plafond',
  'chair|stoel',
  'cheese|kaas',
  'chicken|kip',
  'church|kerk',
  'city|stad',
  'clock|klok',
  'cloud|wolk',
  'coast|kust',
  'corner|hoek',
  'countryside|platteland',
  'cousin|neef of nicht',
  'cow|koe',
  'crowd|menigte',
  'cupboard|kast',
  'danger|gevaar',
  'daughter|dochter',
  'desert|woestijn',
  'dish|schaal',
  'doctor|dokter',
  'dream|droom',
  'drawer|lade',
  'duck|eend',
  'earth|aarde',
  'egg|ei',
  'engine|motor',
  'envelope|envelop',
  'evening|avond',
  'factory|fabriek',
  'farmer|boer',
  'feather|veer',
  'fence|hek',
  'field|veld',
  'fire|vuur',
  'floor|vloer',
  'flour|meel',
  'forest|bos',
  'fork|vork',
  'fridge|koelkast',
  'garden|tuin',
  'gate|poort',
  'glove|handschoen',
  'goose|gans',
  'grass|gras',
  'ground|grond',
  'hall|hal',
  'hammer|hamer',
  'harbour|haven',
  'health|gezondheid',
  'heart|hart',
  'hill|heuvel',
  'holiday|vakantie',
  'homework|huiswerk',
  'honey|honing',
  'horse|paard',
  'hospital|ziekenhuis',
  'ice|ijs',
  'island|eiland',
  'journey|reis',
  'kettle|waterkoker',
  'key|sleutel',
  'kitchen|keuken',
  'knife|mes',
  'ladder|ladder',
  'lake|meer',
  'lamp|lamp',
  'language|taal',
  'leaf|blad',
  'letter|brief',
  'library|bibliotheek',
  'lightning|bliksem',
  'lion|leeuw',
  'lorry|vrachtwagen',
  'luck|geluk',
  'meal|maaltijd',
  'meat|vlees',
  'mirror|spiegel',
  'money|geld',
  'monkey|aap',
  'moon|maan',
  'mountain|berg',
  'nail|spijker',
  'needle|naald',
  'neighbour|buurman',
  'nephew|neefje',
  'nest|nest',
  'newspaper|krant',
  'noise|lawaai',
  'nurse|verpleegkundige',
  'ocean|oceaan',
  'office|kantoor',
  'onion|ui',
  'oven|oven',
  'owl|uil',
  'painting|schilderij',
  'pear|peer',
  'pen|pen',
  'pencil|potlood',
  'pepper|peper',
  'picture|plaatje',
  'pillow|kussen',
  'plate|bord',
  'pocket|zak',
  'pond|vijver',
  'postman|postbode',
  'present|cadeau',
  'prize|prijs',
  'purse|portemonnee',
  'queen|koningin',
  'rabbit|konijn',
  'rain|regen',
  'rice|rijst',
  'ring|ring',
  'river|rivier',
  'road|weg',
  'roof|dak',
  'room|kamer',
  'rope|touw',
  'sand|zand',
  'scissors|schaar',
  'sea|zee',
  'seat|zitplaats',
  'shadow|schaduw',
  'sheep|schaap',
  'shelf|plank',
  'ship|schip',
  'shirt|overhemd',
  'shoe|schoen',
  'shop|winkel',
  'shoulder|schouder',
  'silver|zilver',
  'sky|lucht',
  'snow|sneeuw',
  'soap|zeep',
  'soup|soep',
  'spider|spin',
  'spoon|lepel',
  'spring|lente',
  'stairs|trap',
  'stamp|postzegel',
  'star|ster',
  'stone|steen',
  'storm|storm',
  'stove|kachel',
  'street|straat',
  'sugar|suiker',
  'summer|zomer',
  'sun|zon',
  'table|tafel',
  'tail|staart',
  'teacher|leraar',
  'tent|tent',
  'thief|dief',
  'thunder|donder',
  'ticket|kaartje',
  'tooth|tand',
  'towel|handdoek',
  'tower|toren',
  'town|dorp',
  'toy|speelgoed',
  'train|trein',
  'tree|boom',
  'truth|waarheid',
  'uncle|oom',
  'valley|dal',
  'village|dorpje',
  'voice|stem',
  'wall|muur',
  'wallet|portefeuille',
  'war|oorlog',
  'weather|weer',
  'week|week',
  'wheel|wiel',
  'wind|wind',
  'window|raam',
  'wing|vleugel',
  'winter|winter',
  'wolf|wolf',
  'wood|hout',
  'wool|wol',
  'world|wereld',
  'yard|erf',
  'year|jaar',
];

/// `infinitive|past|participle|nederlands`
const _irregular = [
  'be|was|been|zijn',
  'become|became|become|worden',
  'begin|began|begun|beginnen',
  'break|broke|broken|breken',
  'bring|brought|brought|brengen',
  'build|built|built|bouwen',
  'buy|bought|bought|kopen',
  'catch|caught|caught|vangen',
  'choose|chose|chosen|kiezen',
  'come|came|come|komen',
  'cost|cost|cost|kosten',
  'cut|cut|cut|snijden',
  'do|did|done|doen',
  'draw|drew|drawn|tekenen',
  'drink|drank|drunk|drinken',
  'drive|drove|driven|rijden',
  'eat|ate|eaten|eten',
  'fall|fell|fallen|vallen',
  'feel|felt|felt|voelen',
  'fight|fought|fought|vechten',
  'find|found|found|vinden',
  'fly|flew|flown|vliegen',
  'forget|forgot|forgotten|vergeten',
  'get|got|got|krijgen',
  'give|gave|given|geven',
  'go|went|gone|gaan',
  'grow|grew|grown|groeien',
  'have|had|had|hebben',
  'hear|heard|heard|horen',
  'hide|hid|hidden|verstoppen',
  'hold|held|held|vasthouden',
  'keep|kept|kept|houden',
  'know|knew|known|weten',
  'learn|learnt|learnt|leren',
  'leave|left|left|vertrekken',
  'lend|lent|lent|uitlenen',
  'lose|lost|lost|verliezen',
  'make|made|made|maken',
  'meet|met|met|ontmoeten',
  'pay|paid|paid|betalen',
  'put|put|put|zetten',
  'read|read|read|lezen',
  'ride|rode|ridden|rijden',
  'ring|rang|rung|bellen',
  'run|ran|run|rennen',
  'say|said|said|zeggen',
  'see|saw|seen|zien',
  'sell|sold|sold|verkopen',
  'send|sent|sent|sturen',
  'sing|sang|sung|zingen',
  'sit|sat|sat|zitten',
  'sleep|slept|slept|slapen',
  'speak|spoke|spoken|spreken',
  'spend|spent|spent|uitgeven',
  'stand|stood|stood|staan',
  'steal|stole|stolen|stelen',
  'swim|swam|swum|zwemmen',
  'take|took|taken|nemen',
  'teach|taught|taught|lesgeven',
  'tell|told|told|vertellen',
  'think|thought|thought|denken',
  'throw|threw|thrown|gooien',
  'understand|understood|understood|begrijpen',
  'wake|woke|woken|wakker worden',
  'wear|wore|worn|dragen',
  'win|won|won|winnen',
  'write|wrote|written|schrijven',
];

/// `adjective|comparative|superlative`
const _adjectives = [
  'big|bigger|biggest',
  'small|smaller|smallest',
  'tall|taller|tallest',
  'short|shorter|shortest',
  'long|longer|longest',
  'old|older|oldest',
  'young|younger|youngest',
  'fast|faster|fastest',
  'slow|slower|slowest',
  'happy|happier|happiest',
  'easy|easier|easiest',
  'busy|busier|busiest',
  'hot|hotter|hottest',
  'cold|colder|coldest',
  'nice|nicer|nicest',
  'large|larger|largest',
  'strong|stronger|strongest',
  'clean|cleaner|cleanest',
  'dark|darker|darkest',
  'bright|brighter|brightest',
];

/// `singular|plural`
const _plurals = [
  'child|children',
  'man|men',
  'woman|women',
  'foot|feet',
  'tooth|teeth',
  'mouse|mice',
  'goose|geese',
  'person|people',
  'sheep|sheep',
  'fish|fish',
  'knife|knives',
  'leaf|leaves',
  'life|lives',
  'wife|wives',
  'shelf|shelves',
  'wolf|wolves',
  'city|cities',
  'baby|babies',
  'party|parties',
  'box|boxes',
  'bus|buses',
  'watch|watches',
  'dish|dishes',
  'potato|potatoes',
  'tomato|tomatoes',
];

const _countable = [
  'apples',
  'books',
  'friends',
  'cars',
  'questions',
  'chairs',
  'eggs',
  'shops',
  'children',
  'bottles',
];

const _uncountable = [
  'water',
  'milk',
  'money',
  'time',
  'bread',
  'sugar',
  'rain',
  'homework',
  'music',
  'snow',
];

/// `tijdsaanduiding|voorzetsel`
const _prepositions = [
  'Monday|on',
  'Friday|on',
  'my birthday|on',
  '12 May|on',
  'the morning|in',
  'the evening|in',
  'summer|in',
  'winter|in',
  '2026|in',
  'March|in',
  "six o'clock|at",
  'night|at',
  'the weekend|at',
  'noon|at',
];

const _subjects = ['He', 'She', 'My brother', 'The teacher', 'Her friend'];

/// Verbs whose -ing form needs no doubled consonant, so the template can build
/// it without re-implementing English spelling rules.
const _ingSafe = [
  'read',
  'sing',
  'write',
  'sleep',
  'draw',
  'wear',
  'watch',
  'learn',
  'stand',
  'send',
  'build',
  'find',
  'grow',
  'know',
  'speak',
  'think',
  'bring',
  'teach',
  'hold',
  'fall',
  'feel',
  'keep',
  'leave',
  'eat',
  'drink',
  'hear',
];

/// Verbs that take a plain object, so "… it yesterday" reads naturally.
const _transitive = [
  'break',
  'bring',
  'build',
  'buy',
  'catch',
  'choose',
  'cut',
  'draw',
  'drink',
  'eat',
  'find',
  'forget',
  'give',
  'hear',
  'hide',
  'hold',
  'keep',
  'know',
  'lose',
  'make',
  'pay',
  'put',
  'read',
  'see',
  'sell',
  'send',
  'spend',
  'steal',
  'take',
  'teach',
  'tell',
  'throw',
  'understand',
  'wear',
  'win',
  'write',
];

/// Verbs that make sense with "… every day".
const _daily = [
  'read',
  'write',
  'sing',
  'run',
  'swim',
  'come',
  'go',
  'eat',
  'drink',
  'sleep',
  'think',
  'speak',
  'teach',
  'drive',
  'ride',
  'grow',
  'pay',
  'draw',
  'learn',
  'win',
];

/// The generated part of the Engels bank.
List<QuizQuestion> buildEngelsExtra() {
  final g = QuizGen('gen', seed: 20260910);

  final vocab = rows(_vocab);
  final english = [for (final v in vocab) v[0]];
  final dutch = [for (final v in vocab) v[1]];

  // --- Woordenschat, beide richtingen ---------------------------------------
  for (final v in vocab) {
    g.add(
      topic: _woorden,
      prompt: 'Wat betekent "${v[0]}"?',
      answer: v[1],
      wrong: g.others(dutch, v[1]),
    );
    g.add(
      topic: _woorden,
      prompt: 'Wat is het Engelse woord voor "${v[1]}"?',
      answer: v[0],
      wrong: g.others(english, v[0]),
    );
  }

  // --- Onregelmatige werkwoorden --------------------------------------------
  final irr = rows(_irregular);
  final pasts = [for (final v in irr) v[1]];
  final participles = [for (final v in irr) v[2]];
  for (final v in irr) {
    final inf = v[0];
    g.add(
      topic: _tijden,
      prompt: 'Wat is de verleden tijd van "to $inf"?',
      answer: v[1],
      wrong: [
        '${inf}ed',
        ...g.others(pasts, v[1]),
      ],
      why: '"$inf" is onregelmatig: $inf – ${v[1]} – ${v[2]}.',
    );
    g.add(
      topic: _tijden,
      prompt: 'Wat is het voltooid deelwoord van "to $inf"?',
      answer: v[2],
      wrong: [
        '${inf}ed',
        ...g.others(participles, v[2]),
      ],
      why: 'I have ${v[2]}.',
    );
    g.add(
      topic: _woorden,
      prompt: 'Wat betekent "to $inf"?',
      answer: v[3],
      wrong: g.others([for (final r in irr) r[3]], v[3]),
    );
  }

  // --- Present simple, derde persoon ----------------------------------------
  for (final v in _daily) {
    final subject = g.oneOf(_subjects);
    final third = v.endsWith('o') || v.endsWith('ch') || v.endsWith('sh')
        ? '${v}es'
        : v.endsWith('y') && !'aeiou'.contains(v[v.length - 2])
            ? '${v.substring(0, v.length - 1)}ies'
            : '${v}s';
    g.add(
      topic: _tijden,
      prompt: 'Vul in: $subject … every day. (to $v)',
      answer: third,
      wrong: [v, '${v}ed', 'is $v', '${v}ing'],
      why: 'In de present simple krijgt he, she of it een -s.',
    );
  }

  // --- Present continuous ----------------------------------------------------
  for (final v in _ingSafe) {
    final ing = v.endsWith('e') && v.length > 2
        ? '${v.substring(0, v.length - 1)}ing'
        : '${v}ing';
    g.add(
      topic: _tijden,
      prompt: 'Vul in: Look! She is … right now. (to $v)',
      answer: ing,
      wrong: ['${v}s', v, '${v}ed', 'to $v'],
      why: 'Bij "right now" gebruik je de present continuous: am/is/are + -ing.',
    );
  }

  // --- Past simple en present perfect in een zin -----------------------------
  final byInf = {for (final v in irr) v[0]: v};
  for (final inf in _transitive) {
    final v = byInf[inf];
    if (v == null) continue;
    g.add(
      topic: _tijden,
      prompt: 'Vul in: They … it yesterday. (to $inf)',
      answer: v[1],
      wrong: [inf, '${inf}ed', v[2], '${inf}s'],
      why: '"Yesterday" vraagt om de past simple: ${v[1]}.',
    );
    g.add(
      topic: _tijden,
      prompt: 'Vul in: I have … it three times. (to $inf)',
      answer: v[2],
      wrong: [v[1], inf, '${inf}ed', '${inf}ing'],
      why: 'Na "have" komt het voltooid deelwoord: ${v[2]}.',
    );
  }

  // --- Grammatica: meervoud --------------------------------------------------
  for (final p in rows(_plurals)) {
    g.add(
      topic: _grammatica,
      prompt: 'Wat is het meervoud van "${p[0]}"?',
      answer: p[1],
      wrong: [
        '${p[0]}s',
        '${p[0]}es',
        '${p[1]}s',
        '${p[0]}en',
      ],
      why: '"${p[0]}" heeft een onregelmatig meervoud: ${p[1]}.',
    );
  }

  // --- Grammatica: trappen van vergelijking ---------------------------------
  for (final a in rows(_adjectives)) {
    g.add(
      topic: _grammatica,
      prompt: 'Vul in: My bag is … than yours. (${a[0]})',
      answer: a[1],
      wrong: [a[0], a[2], 'more ${a[0]}', 'most ${a[0]}'],
      why: 'Bij een kort bijvoeglijk naamwoord komt -er.',
    );
    g.add(
      topic: _grammatica,
      prompt: 'Vul in: This is the … one of all. (${a[0]})',
      answer: a[2],
      wrong: [a[1], a[0], 'more ${a[0]}', 'most ${a[0]}'],
      why: 'De overtreffende trap krijgt -est en "the" ervoor.',
    );
  }

  // --- Grammatica: much / many ----------------------------------------------
  for (final noun in _countable) {
    g.add(
      topic: _grammatica,
      prompt: 'Vul in: How … $noun are there?',
      answer: 'many',
      wrong: const ['much', 'a much', 'many of', 'lot'],
      why: '"$noun" kun je tellen, dus "many".',
    );
  }
  for (final noun in _uncountable) {
    g.add(
      topic: _grammatica,
      prompt: 'Vul in: How … $noun is there?',
      answer: 'much',
      wrong: const ['many', 'a many', 'much of', 'lot'],
      why: '"$noun" kun je niet tellen, dus "much".',
    );
    g.add(
      topic: _grammatica,
      prompt: "Vul in: There isn't … $noun left.",
      answer: 'much',
      wrong: const ['many', 'a few', 'lots', 'several'],
      why: 'Bij niet-telbare woorden gebruik je "much".',
    );
  }

  // --- Grammatica: a of an ---------------------------------------------------
  for (final w in ['apple', 'egg', 'orange', 'hour', 'umbrella', 'island']) {
    g.add(
      topic: _grammatica,
      prompt: 'Vul in: I would like … $w.',
      answer: 'an',
      wrong: const ['a', 'the a', 'some a', 'any'],
      why: 'Voor een klinkerklank komt "an".',
    );
  }
  for (final w in ['book', 'car', 'house', 'university', 'garden', 'dog']) {
    g.add(
      topic: _grammatica,
      prompt: 'Vul in: She has … $w.',
      answer: 'a',
      wrong: const ['an', 'the an', 'some an', 'any'],
      why: 'Voor een medeklinkerklank komt "a".',
    );
  }

  // --- Grammatica: voorzetsels van tijd -------------------------------------
  for (final p in rows(_prepositions)) {
    g.add(
      topic: _grammatica,
      prompt: 'Vul in: We meet … ${p[0]}.',
      answer: p[1],
      wrong: const ['in', 'on', 'at', 'to'],
      why: switch (p[1]) {
        'on' => 'Bij dagen en datums gebruik je "on".',
        'in' => 'Bij maanden, seizoenen, jaren en dagdelen gebruik je "in".',
        _ => 'Bij kloktijden, "night" en "the weekend" gebruik je "at".',
      },
    );
  }

  // --- Grammatica: there is / there are --------------------------------------
  for (final noun in _countable) {
    g.add(
      topic: _grammatica,
      prompt: 'Vul in: There … three $noun on the table.',
      answer: 'are',
      wrong: const ['is', 'be', 'am', 'was'],
      why: '"$noun" is meervoud, dus "are".',
    );
  }

  return g.questions;
}
