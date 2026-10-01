// The classroom in the basement, behind a door that only opens on Nova.
// Sitting at a desk brings up the lesson: the reader says which country
// they go to school in (once — only the luma team can change it), then
// their school, year, level, subject, the book's publisher, the chapter and
// paragraph and what it is about. The teacher (the model the operator
// picked in the admin dashboard) hands out questions about it one at a
// time; the reader answers or skips, and hands the lot in to have it
// checked. Each question and each check is a fresh call on the server with
// only the lesson and that one question, so the teacher never drifts.
//
// The app does the talking; this page draws the door, the board and the
// screen, and keeps the lesson in progress with the app.
(() => {
  'use strict';
  const $ = id => document.getElementById(id);

  // ── School systems ─────────────────────────────────────────────────────
  // What the form offers per country. Every field also takes free text, so
  // a missing method or subject never stops anyone; "somewhere else" is all
  // free text. Names are the country's own words, as on the cover of the
  // book, so they are not translated.
  const range = (from, to, label) => Array.from({length: to - from + 1}, (_, i) => label(from + i));
  const COUNTRIES = [
    {
      name: 'Nederland', lang: 'nl',
      schools: [
        {name: 'Basisschool', years: range(3, 8, n => `Groep ${n}`)},
        {
          name: 'Middelbare school', years: range(1, 6, n => `Leerjaar ${n}`),
          levels: [['vmbo-basis', 4], ['vmbo-kader', 4], ['vmbo-gt (mavo)', 4], ['havo', 5], ['vwo (atheneum)', 6], ['vwo (gymnasium)', 6]],
        },
        {name: 'MBO', years: range(1, 4, n => `Jaar ${n}`), levels: [['Niveau 1', 1], ['Niveau 2', 2], ['Niveau 3', 3], ['Niveau 4', 4]]},
      ],
      subjects: {
        Basisschool: ['Rekenen', 'Taal', 'Spelling', 'Begrijpend lezen', 'Aardrijkskunde', 'Geschiedenis', 'Natuur & techniek', 'Engels'],
        default: ['Nederlands', 'Engels', 'Frans', 'Duits', 'Spaans', 'Latijn', 'Grieks', 'Wiskunde', 'Wiskunde A', 'Wiskunde B', 'Natuurkunde', 'Scheikunde', 'NaSk', 'Biologie', 'Aardrijkskunde', 'Geschiedenis', 'Economie', 'Bedrijfseconomie', 'Maatschappijleer'],
      },
      publishers: {
        Rekenen: ['Pluspunt', 'Wereld in getallen', 'Getal & Ruimte Junior', 'Alles telt Q'],
        Taal: ['Taal actief', 'Staal', 'Taal in beeld', 'Taalverhaal.nu'],
        Spelling: ['Taal actief', 'Staal', 'Spelling in beeld', 'Taalverhaal.nu'],
        'Begrijpend lezen': ['Nieuwsbegrip', 'Grip'],
        Wiskunde: ['Getal & Ruimte', 'Moderne Wiskunde', 'Wageningse Methode', 'Netwerk'],
        'Wiskunde A': ['Getal & Ruimte', 'Moderne Wiskunde'],
        'Wiskunde B': ['Getal & Ruimte', 'Moderne Wiskunde'],
        Nederlands: ['Nieuw Nederlands', 'Op niveau', 'Talent', 'Kern Nederlands'],
        Engels: ['Stepping Stones', 'All Right!', 'New Interface', 'Of Course'],
        Frans: ['Grandes Lignes', "D'accord", 'Libre Service'],
        Duits: ['Neue Kontakte', 'Na klar!', 'Trabitour'],
        Spaans: ['¡Exacto!', 'Señas'],
        Latijn: ['Fortuna', 'Disco', 'Pallas'],
        Grieks: ['Argo', 'Pallas'],
        Natuurkunde: ['Nova', 'Newton', 'Pulsar', 'Overal Natuurkunde'],
        Scheikunde: ['Nova', 'Chemie Overal', 'Pulsar'],
        NaSk: ['Nova', 'Impact', 'Pulsar'],
        Biologie: ['Biologie voor jou', 'Nectar', 'BioCom'],
        Aardrijkskunde: ['De Geo', 'BuiteNLand', 'Wereldwijs', 'Wereldzaken', 'Blink Wereld', 'Meander'],
        Geschiedenis: ['Feniks', 'Memo', 'Sprekend Verleden', 'Geschiedeniswerkplaats', 'Saga', 'Brandaan', 'Tijdzaken'],
        Economie: ['Pincode', 'LWEO', 'Praktische Economie'],
        Bedrijfseconomie: ['Praktische Bedrijfseconomie', 'Fundament'],
        Maatschappijleer: ["Thema's Maatschappijleer", 'Seneca'],
        'Natuur & techniek': ['Naut', 'Blink Wereld'],
      },
    },
    {
      name: 'België (Vlaanderen)', lang: 'nl',
      schools: [
        {name: 'Lagere school', years: range(1, 6, n => `${n}e leerjaar`)},
        {name: 'Secundair onderwijs', years: range(1, 6, n => `${n}e jaar`), levels: [['A-stroom', 2], ['B-stroom', 2], ['ASO', 6, 3], ['TSO', 6, 3], ['KSO', 6, 3], ['BSO', 7, 3]]},
      ],
      subjects: {default: ['Nederlands', 'Frans', 'Engels', 'Duits', 'Wiskunde', 'Wetenschappen', 'Fysica', 'Chemie', 'Biologie', 'Aardrijkskunde', 'Geschiedenis', 'Economie', 'Latijn', 'Wereldoriëntatie']},
      publishers: {default: ['Van In', 'Die Keure', 'Pelckmans', 'Plantyn']},
    },
    {
      name: 'Deutschland', lang: 'de',
      schools: [
        {name: 'Grundschule', years: range(1, 4, n => `Klasse ${n}`)},
        {name: 'Weiterführende Schule', years: range(5, 13, n => `Klasse ${n}`), levels: [['Hauptschule', 10], ['Realschule', 10], ['Gymnasium', 13], ['Gesamtschule', 13]]},
      ],
      subjects: {default: ['Deutsch', 'Mathematik', 'Englisch', 'Französisch', 'Latein', 'Physik', 'Chemie', 'Biologie', 'Erdkunde', 'Geschichte', 'Politik', 'Sachunterricht']},
      publishers: {default: ['Cornelsen', 'Klett', 'Westermann', 'C.C. Buchner']},
    },
    {
      name: 'United Kingdom', lang: 'en',
      schools: [
        {name: 'Primary school', years: range(1, 6, n => `Year ${n}`)},
        {name: 'Secondary school', years: range(7, 13, n => `Year ${n}`), levels: [['Key Stage 3', 9, 7], ['GCSE Foundation', 11, 10], ['GCSE Higher', 11, 10], ['A level', 13, 12]]},
      ],
      subjects: {default: ['English', 'Maths', 'Biology', 'Chemistry', 'Physics', 'Combined Science', 'History', 'Geography', 'French', 'Spanish', 'German', 'Computer Science', 'Economics']},
      publishers: {default: ['Pearson', 'Oxford University Press', 'Collins', 'Hodder Education', 'CGP', 'AQA']},
    },
    {
      name: 'United States', lang: 'en',
      schools: [
        {name: 'Elementary school', years: ['Kindergarten', ...range(1, 5, n => `Grade ${n}`)]},
        {name: 'Middle school', years: range(6, 8, n => `Grade ${n}`)},
        {name: 'High school', years: range(9, 12, n => `Grade ${n}`), levels: [['Regular', 12], ['Honors', 12], ['AP', 12], ['IB', 12]]},
      ],
      subjects: {default: ['Math', 'Algebra', 'Geometry', 'Pre-Calculus', 'Calculus', 'English', 'Biology', 'Chemistry', 'Physics', 'US History', 'World History', 'Spanish', 'French']},
      publishers: {default: ['McGraw Hill', 'Savvas', 'Houghton Mifflin Harcourt', 'Big Ideas Learning', 'Illustrative Mathematics', 'Amplify']},
    },
    {
      name: 'France', lang: 'fr',
      schools: [
        {name: 'École élémentaire', years: ['CP', 'CE1', 'CE2', 'CM1', 'CM2']},
        {name: 'Collège', years: ['6e', '5e', '4e', '3e']},
        {name: 'Lycée', years: ['Seconde', 'Première', 'Terminale'], levels: [['Générale', 3], ['Technologique', 3], ['Professionnelle', 3]]},
      ],
      subjects: {default: ['Français', 'Mathématiques', 'Anglais', 'Espagnol', 'Allemand', 'Histoire-géographie', 'SVT', 'Physique-chimie', 'SES', 'Philosophie']},
      publishers: {default: ['Hachette', 'Nathan', 'Bordas', 'Belin', 'Hatier', 'Magnard']},
    },
    {
      name: 'España', lang: 'es',
      schools: [
        {name: 'Primaria', years: range(1, 6, n => `${n}º`)},
        {name: 'ESO', years: range(1, 4, n => `${n}º`)},
        {name: 'Bachillerato', years: range(1, 2, n => `${n}º`), levels: [['Ciencias y Tecnología', 2], ['Humanidades y Ciencias Sociales', 2], ['Artes', 2]]},
      ],
      subjects: {default: ['Lengua Castellana', 'Matemáticas', 'Inglés', 'Biología y Geología', 'Física y Química', 'Geografía e Historia', 'Francés', 'Economía', 'Filosofía']},
      publishers: {default: ['Santillana', 'SM', 'Anaya', 'Edelvives', 'Oxford', 'McGraw Hill']},
    },
  ];
  const countryInfo = name => COUNTRIES.find(c => c.name === name) || null;
  // The language a country's schools teach in, for one typed under
  // "somewhere else": its name in English or in its own words. Null when
  // unknown, and the classroom then speaks the app's language.
  const COUNTRY_LANGS = [
    [/^(nederland|netherlands|holland|the netherlands|pays-bas|países bajos|荷兰|suriname|belgi[eë]|vlaanderen|flanders)/i, 'nl'],
    [/^(united kingdom|uk|england|scotland|wales|ireland|united states|usa|america|canada|australia|new zealand|south africa)/i, 'en'],
    [/^(france|belgique|wallonie|luxembourg|québec|quebec|suisse|sénégal|côte d'ivoire|maroc|tunisie|algérie)/i, 'fr'],
    [/^(españa|spain|méxico|mexico|argentina|colombia|chile|perú|peru|venezuela|ecuador|uruguay|paraguay|bolivia|cuba|guatemala|costa rica|panamá|panama)/i, 'es'],
    [/^(中国|中國|china|台湾|台灣|taiwan|香港|hong kong|singapore|新加坡)/i, 'zh'],
  ];
  function languageOf(name) {
    if (!name) return null;
    return countryInfo(name)?.lang || COUNTRY_LANGS.find(([re]) => re.test(name.trim()))?.[1] || null;
  }
  // The years a level runs through: a level is [name, last year, first
  // year], so vmbo stops after the fourth and havo after the fifth. Years
  // without a number (CP, Seconde) are always offered.
  function yearsFor(school, level) {
    const lv = school?.levels?.find(([name]) => name === level);
    if (!school || !lv) return school?.years || [];
    const [, last, first = 0] = lv;
    return school.years.filter(y => {
      const n = Number((y.match(/\d+/) || [])[0]);
      return !Number.isFinite(n) || (n >= first && n <= last);
    });
  }

  const MAX_QUESTIONS = 30;
  const FIELDS = ['school', 'year', 'level', 'subject', 'publisher', 'chapter', 'paragraph', 'topic'];

  // English for the demo page; the app sends the reader's language.
  const EN = {
    classroom: 'Classroom', classLocked: 'Locked', classLockedNova: 'The classroom is part of Nova',
    classLockedSignin: 'Sign in to a luma account to open it', classLockedOffline: "Can't reach the luma server right now",
    classDown: 'Climb down to the cellar', classUp: 'Climb up the ladder', classSit: 'Sit down for a lesson', classBoard: 'Blackboard',
    classCountryTitle: 'Which country do you go to school in?', classCountryNote: 'You can only set this once.',
    classCountryOther: 'Somewhere else', classCountryName: 'Country', classCountrySet: 'Set country',
    classCountryConfirm: "Set {0} as your country? You can't change it later.", classCountryIs: 'Country: {0}',
    classSchool: 'School', classYear: 'Year', classLevel: 'Level', classSubject: 'Subject', classPublisher: 'Book (publisher)',
    classChapter: 'Chapter', classParagraph: 'Paragraph', classTopic: 'What is the paragraph about?', classTopicHint: "e.g. Pythagoras' theorem",
    classStart: 'Start the lesson', classNeedAll: 'Fill in every field to start.',
    classAsking: 'The teacher is writing a question…', classQuestion: 'Question {0}', classAnswerHint: 'Your answer',
    classNext: 'Next question', classPrev: 'Previous', classSkip: 'Skip', classHandIn: 'Hand in', classLeave: 'Leave',
    classSkipped: 'Skipped', classChecking: 'The teacher is checking your work…', classNothing: 'Answer at least one question first.',
    classHandInConfirm: 'Hand in {0} answers? Skipped questions are not checked.', classLast: 'That is the last question for this lesson.',
    classCorrect: 'Correct', classPartly: 'Partly right', classWrong: 'Not right', classUnchecked: 'Not checked',
    classScore: '{0} right, {1} partly, {2} not', classYourAnswer: 'You', classModel: 'Answer',
    classAgain: 'Same paragraph again', classNew: 'New lesson', classFailed: "That didn't work", classRetry: 'Try again',
    classTimeout: 'The teacher took too long. Try again.', classCancel: 'Cancel', classOk: 'OK',
  };

  function create({T, gui, send, scene, W, atlas: getAtlas, mat, toast}) {
    // The classroom's strings per language, from the app. Once the country
    // is known the classroom speaks its schools' language, like the teacher.
    let languages = {};
    const t = (key, ...args) => {
      const own = languages[languageOf(country)];
      let s = own?.[key] ?? gui.strings?.[key] ?? EN[key] ?? key;
      args.forEach((a, i) => { s = s.replace(`{${i}}`, a); });
      return s;
    };

    // ── State ────────────────────────────────────────────────────────────
    let access = 'signin';
    let country = null;
    // What the reader keeps: the form and the lesson in progress.
    let saved = {lesson: {}, session: null};
    let screen = null;
    let built = null, grid = null;

    let seq = 0;
    const pending = new Map();
    function ask(message, timeout = 120000) {
      return new Promise((resolve, reject) => {
        const id = 'c' + ++seq;
        pending.set(id, {resolve, reject});
        send({type: 'classroom', ...message, request: id});
        setTimeout(() => {
          if (!pending.has(id)) return;
          pending.delete(id);
          reject(Object.assign(new Error(t('classTimeout')), {code: 'timeout'}));
        }, timeout);
      });
    }
    function save() {
      send({type: 'classroom', op: 'save', state: saved});
    }

    function receive(m) {
      if (m.request != null) {
        const p = pending.get(m.request);
        if (!p) return;
        pending.delete(m.request);
        if (m.error) p.reject(Object.assign(new Error(m.error.message || t('classFailed')), {code: m.error.code}));
        else p.resolve(m.data);
        return;
      }
      if ('saved' in m) {
        const s = m.saved && typeof m.saved === 'object' ? m.saved : {};
        saved = {lesson: s.lesson && typeof s.lesson === 'object' ? s.lesson : {}, session: cleanSession(s.session)};
        drawBoard();
      }
      if (m.state) {
        const was = access;
        access = ['ok', 'plan', 'signin', 'offline'].includes(m.state.access) ? m.state.access : 'signin';
        country = typeof m.state.country === 'string' && m.state.country ? m.state.country : null;
        if (was !== access) buildDoor();
        if (screen) refresh();
      }
    }

    function cleanSession(s) {
      if (!s || typeof s !== 'object' || !Array.isArray(s.items) || !s.lesson) return null;
      const items = s.items.filter(i => i && typeof i.question === 'string').slice(0, MAX_QUESTIONS).map(i => ({
        question: i.question,
        choices: Array.isArray(i.choices) ? i.choices.filter(c => typeof c === 'string') : [],
        answer: typeof i.answer === 'string' ? i.answer : '',
        skipped: !!i.skipped,
        review: i.review && typeof i.review === 'object' ? i.review : null,
      }));
      if (!items.length) return null;
      return {lesson: s.lesson, items, index: Math.max(0, Math.min(items.length - 1, Number(s.index) || 0)), handedIn: !!s.handedIn};
    }

    const lockedReason = () => t({plan: 'classLockedNova', signin: 'classLockedSignin', offline: 'classLockedOffline'}[access] || 'classLockedNova');

    // ── The door ─────────────────────────────────────────────────────────
    // Two leaves like the front door's. Locked, a padlock hangs on the
    // cellar side and the leaves don't move.
    const door = {leaves: [], lock: null, open: 0, target: 0, rattle: 0, colliders: []};
    function disposeMesh(m) { if (m) { scene.remove(m); m.geometry.dispose(); } }
    function buildDoor() {
      for (const leaf of door.leaves) disposeMesh(leaf);
      disposeMesh(door.lock);
      door.leaves = []; door.lock = null;
      if (!built) return;
      const d = built.door, atlas = getAtlas();
      const light = grid.sample([0, d.base + 1, d.z + 0.5], [0, 0, 1]);
      for (const [hx, dir] of d.hinges) {
        const mb = new W.MeshBuilder();
        LibraryFurniture.doorLeaf({mb, grid, atlas}, dir < 0, light);
        const mesh = new T.Mesh(mb.geometry(T), mat);
        mesh.position.set(hx, d.base, d.z);
        mesh.userData.swing = dir;
        scene.add(mesh);
        door.leaves.push(mesh);
      }
      if (access !== 'ok') {
        door.target = door.open = 0;
        const mb = new W.MeshBuilder();
        LibraryFurniture.padlock({mb, grid, atlas}, [0, 0, 0], light);
        door.lock = new T.Mesh(mb.geometry(T), mat);
        door.lock.position.set(0, d.base + 1.15, d.z + 3 / 16);
        scene.add(door.lock);
      }
      poseDoor();
    }
    const ease = x => (x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2);
    function poseDoor() {
      if (!built) return;
      const e = ease(door.open), z = built.door.z, f = built.floor;
      for (const leaf of door.leaves) leaf.rotation.y = leaf.userData.swing * e * Math.PI / 2 + Math.sin(door.rattle * 40) * door.rattle * 0.02 * leaf.userData.swing;
      if (door.lock) door.lock.rotation.z = Math.sin(door.rattle * 30) * door.rattle * 0.6;
      door.colliders = door.open < 0.5 ? [[-1, z, 1, z + 0.2, f]] : [[-1, z - 1, -0.8, z, f], [0.8, z - 1, 1, z, f]];
    }
    // Opens or shuts the door; locked, it rattles and says why.
    function useDoor() {
      if (access !== 'ok') {
        door.rattle = 0.6;
        toast(t('classLocked'), lockedReason());
        if (access === 'offline' || access === 'signin') send({type: 'classroom', op: 'state'});
        return false;
      }
      door.target = door.target ? 0 : 1;
      return true;
    }
    function step(dt) {
      let moved = false;
      if (door.rattle > 0) { door.rattle = Math.max(0, door.rattle - dt); moved = true; }
      if (door.open !== door.target && door.leaves.length) {
        const s = dt * 2.4;
        door.open = door.target > door.open ? Math.min(door.target, door.open + s) : Math.max(door.target, door.open - s);
        moved = true;
      }
      if (moved) poseDoor();
      return moved;
    }

    // ── The blackboard ───────────────────────────────────────────────────
    // Chalk on a canvas laid a hair in front of the slate: the question
    // being answered, the score once handed in, or the lesson's title.
    const chalk = {canvas: null, tex: null, mesh: null, text: null};
    function buildBoard() {
      disposeMesh(chalk.mesh);
      chalk.mesh = null;
      if (!built) return;
      const b = built.board;
      const w = b.x1 - b.x0, h = b.y1 - b.y0;
      if (!chalk.canvas) {
        chalk.canvas = document.createElement('canvas');
        chalk.canvas.width = 1024;
        chalk.canvas.height = Math.round(1024 * h / w);
        chalk.tex = new T.CanvasTexture(chalk.canvas);
        chalk.tex.colorSpace = T.SRGBColorSpace;
        chalk.tex.anisotropy = 4;
      }
      const material = new T.MeshBasicMaterial({map: chalk.tex, transparent: true, depthWrite: false, color: new T.Color(0.62, 0.62, 0.6)});
      chalk.mesh = new T.Mesh(new T.PlaneGeometry(w, h), material);
      chalk.mesh.position.set((b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2, b.z + LibraryFurniture.BOARD_SLATE + 0.004);
      chalk.mesh.userData.noShadow = true;
      chalk.mesh.renderOrder = 3;
      scene.add(chalk.mesh);
      chalk.text = null;
      drawBoard();
    }
    function boardLines() {
      const s = saved.session;
      if (s && s.handedIn) {
        const n = tally(s);
        return {title: `${s.lesson.subject || ''} ${s.lesson.paragraph || ''}`.trim(), body: t('classScore', n.correct, n.partly, n.wrong)};
      }
      if (s && s.items[s.index] && (!screen || screen.view === 'question')) {
        const item = s.items[s.index];
        return {title: t('classQuestion', s.index + 1), body: item ? item.question : ''};
      }
      if (s) return {title: `${s.lesson.subject || ''} ${s.lesson.paragraph || ''}`.trim(), body: s.lesson.topic || ''};
      const l = saved.lesson || {};
      if (l.topic) return {title: `${l.subject || ''} ${l.paragraph || ''}`.trim(), body: l.topic};
      return {title: '', body: ''};
    }
    function drawBoard() {
      if (!chalk.canvas) return;
      const lines = boardLines();
      const key = JSON.stringify(lines);
      if (key === chalk.text) return;
      chalk.text = key;
      const c = chalk.canvas, ctx = c.getContext('2d');
      ctx.clearRect(0, 0, c.width, c.height);
      const font = getComputedStyle(document.documentElement).getPropertyValue('--font') || 'monospace';
      const pad = 48;
      const wrap = (text, size, maxLines) => {
        ctx.font = `${size}px ${font}`;
        const out = [];
        for (const para of String(text).split('\n')) {
          let line = '';
          for (const word of para.split(/\s+/)) {
            const next = line ? line + ' ' + word : word;
            if (ctx.measureText(next).width > c.width - pad * 2 && line) { out.push(line); line = word; } else line = next;
          }
          out.push(line);
        }
        if (out.length > maxLines) { out.length = maxLines; out[maxLines - 1] = out[maxLines - 1].replace(/\s*\S*$/, '') + '…'; }
        return out;
      };
      const r = LibraryTextures.rng('chalk' + key.length);
      const write = (text, x, y, size) => {
        ctx.font = `${size}px ${font}`;
        ctx.fillStyle = 'rgba(238, 238, 228, 0.92)';
        ctx.fillText(text, x, y);
        // A second, fainter pass a hair off makes it read as chalk.
        ctx.fillStyle = 'rgba(238, 238, 228, 0.25)';
        ctx.fillText(text, x + (r() - 0.5) * 2, y + (r() - 0.5) * 2);
      };
      ctx.textBaseline = 'top';
      let y = pad * 0.8;
      if (lines.title) {
        write(lines.title, pad, y, 44);
        ctx.fillStyle = 'rgba(238, 238, 228, 0.5)';
        ctx.fillRect(pad, y + 52, Math.min(c.width - pad * 2, ctx.measureText(lines.title).width), 3);
        y += 76;
      }
      const size = lines.body.length > 160 ? 30 : 36;
      for (const line of wrap(lines.body, size, Math.floor((c.height - y - pad * 0.5) / (size * 1.25)))) {
        write(line, pad, y, size);
        y += size * 1.25;
      }
      chalk.tex.needsUpdate = true;
    }

    function build(b) {
      built = b?.basement || null;
      grid = b?.grid || null;
      buildDoor();
      buildBoard();
    }

    // ── Picking ──────────────────────────────────────────────────────────
    // What a ray meets on `floor`, for the page's hover and click: the way
    // down the hatch, the ladder, the door, the board and the desks.
    function pick(ray, floor, boxHit, reach) {
      if (!built) return [];
      const out = [];
      const consider = (box, hit) => {
        const d = boxHit(ray, ...box);
        if (d != null && d < reach) out.push({kind: 'classroom', box, t: d, ...hit});
      };
      if (floor === 0) consider(built.hatch.down, {what: 'down', tip: [t('classDown')]});
      if (floor !== built.floor) return out;
      consider(built.hatch.up, {what: 'up', tip: [t('classUp')]});
      const d = built.door;
      const shut = door.open < 0.5;
      consider([[-1, d.base, d.z - (shut ? 0.05 : 1)], [1, d.base + d.height, d.z + 0.3]],
        {what: 'door', tip: access === 'ok' ? [t(door.target ? 'closeDoor' : 'openDoor'), {text: t('classroom'), cls: 'sub'}] : [t('classLocked'), {text: lockedReason(), cls: 'sub'}]});
      const b = built.board;
      consider([[b.x0, b.y0, b.z], [b.x1, b.y1, b.z + 0.15]], {what: 'board', tip: [t('classBoard'), ...(boardLines().title ? [{text: boardLines().title, cls: 'sub'}] : [])]});
      built.desks.forEach((seat, i) => consider(seat.box, {what: 'desk', seat, i, tip: [t('classSit')]}));
      return out;
    }

    // ── The screen ───────────────────────────────────────────────────────
    const root = document.createElement('div');
    root.id = 'classroom';
    root.className = 'mc-screen clear cr-screen';
    root.hidden = true;
    root.innerHTML = '<div class="cr-panel" role="dialog" aria-modal="true" aria-labelledby="cr-title">' +
      '<div class="cr-head"><h2 id="cr-title" class="mc-text"></h2><button id="cr-close" class="mc-button" type="button"></button></div>' +
      '<div id="cr-body" aria-live="polite"></div>' +
      '<div id="cr-actions"></div></div>';
    document.body.append(root);
    root.addEventListener('keydown', e => {
      e.stopPropagation();
      if (e.key === 'Escape') close();
    });
    for (const type of ['keyup', 'pointerdown', 'wheel']) root.addEventListener(type, e => e.stopPropagation());
    $('cr-close').onclick = () => close();

    function open() {
      if (screen) return screen.done;
      let resolve;
      const done = new Promise(r => { resolve = r; });
      screen = {view: 'form', busy: false, message: '', resolve, done};
      if (!country) screen.view = 'country';
      else if (saved.session) screen.view = saved.session.handedIn ? 'results' : 'question';
      root.hidden = false;
      refresh();
      setTimeout(() => root.querySelector('input, textarea, select, .cr-choice, .mc-button:not(#cr-close)')?.focus(), 40);
      return done;
    }
    function close() {
      if (!screen || screen.busy) return;
      const r = screen.resolve;
      screen = null;
      root.hidden = true;
      drawBoard();
      r();
    }

    // Small builders for the screen's parts.
    const el = (tag, cls, text) => {
      const e = document.createElement(tag);
      if (cls) e.className = cls;
      if (text != null) e.textContent = text;
      return e;
    };
    const button = (label, fn, cls = '') => {
      const b = el('button', 'mc-button ' + cls, label);
      b.type = 'button';
      b.onclick = fn;
      return b;
    };
    let uid = 0;
    // A labelled text field with suggestions to pick from.
    function field(label, value, options, onInput, {hint = '', max = 80} = {}) {
      const id = 'cr-f' + ++uid;
      const wrap = el('label', 'cr-field');
      wrap.htmlFor = id;
      wrap.append(el('span', 'mc-text small', label));
      const input = el('input', 'mc-field');
      input.id = id;
      input.value = value || '';
      input.maxLength = max;
      input.placeholder = hint;
      input.setAttribute('aria-label', label);
      input.autocomplete = 'off';
      input.spellcheck = false;
      if (options?.length) {
        const list = el('datalist');
        list.id = id + '-l';
        for (const o of options) { const opt = el('option'); opt.value = o; list.append(opt); }
        input.setAttribute('list', list.id);
        wrap.append(list);
      }
      input.oninput = () => onInput(input.value);
      wrap.append(input);
      return wrap;
    }
    // A row of choices as buttons, with free text when none fits.
    function chips(label, value, options, onPick) {
      const wrap = el('div', 'cr-field');
      wrap.append(el('span', 'mc-text small', label));
      const row = el('div', 'cr-chips');
      row.setAttribute('role', 'radiogroup');
      for (const o of options) {
        const b = el('button', 'cr-chip' + (o === value ? ' on' : ''), o);
        b.type = 'button';
        b.setAttribute('role', 'radio');
        b.setAttribute('aria-checked', String(o === value));
        b.onclick = () => onPick(o);
        row.append(b);
      }
      wrap.append(row);
      return wrap;
    }

    function refresh() {
      if (!screen) return;
      $('cr-title').textContent = t('classroom');
      $('cr-close').textContent = t('classLeave');
      const body = $('cr-body'), actions = $('cr-actions');
      body.replaceChildren();
      actions.replaceChildren();
      if (access !== 'ok') {
        body.append(el('p', 'mc-text', lockedReason()));
      } else if (!country && screen.view !== 'country') {
        screen.view = 'country';
      }
      if (access === 'ok') ({country: viewCountry, form: viewForm, question: viewQuestion, results: viewResults, checking: viewChecking}[screen.view] || viewForm)(body, actions);
      if (screen.message) body.prepend(el('p', 'mc-text cr-error', screen.message));
      if (screen.confirm) {
        const c = screen.confirm;
        actions.replaceChildren(
          button(t('classCancel'), () => { screen.confirm = null; refresh(); c.resolve(false); }),
          button(t('classOk'), () => { screen.confirm = null; c.resolve(true); refresh(); }, 'cr-primary'),
        );
        body.append(el('p', 'mc-text cr-confirm', c.text));
        setTimeout(() => actions.lastChild?.focus(), 20);
      }
      drawBoard();
    }
    // Asks in the panel; resolves whether the reader said yes.
    const confirmIn = text => new Promise(resolve => {
      screen.confirm = {text, resolve};
      refresh();
    });
    const wait = text => {
      const p = el('p', 'mc-text cr-wait', text);
      p.append(el('span', 'cr-dots'));
      return p;
    };

    // Which country: picked once, then fixed on the account.
    function viewCountry(body, actions) {
      const pick = screen.pick ?? null;
      body.append(el('p', 'mc-text', t('classCountryTitle')), el('p', 'mc-text dim small', t('classCountryNote')));
      body.append(chips('', pick, [...COUNTRIES.map(c => c.name), t('classCountryOther')], v => { screen.pick = v; screen.message = ''; refresh(); }));
      const other = pick === t('classCountryOther');
      if (other) body.append(field(t('classCountryName'), screen.other || '', [], v => { screen.other = v; setBtn.disabled = !chosen(); }, {max: 56}));
      const chosen = () => (other ? (screen.other || '').trim() : pick);
      const setBtn = button(t('classCountrySet'), async () => {
        const name = chosen();
        if (!name || screen.busy) return;
        if (!await confirmIn(t('classCountryConfirm', name)) || !screen) return;
        screen.busy = true;
        setBtn.disabled = true;
        try {
          const r = await ask({op: 'country', country: name}, 30000);
          country = r.country || name;
          screen.view = saved.session ? (saved.session.handedIn ? 'results' : 'question') : 'form';
          screen.message = '';
        } catch (e) {
          screen.message = `${t('classFailed')}: ${e.message}`;
          if (e.code === 'country_locked') send({type: 'classroom', op: 'state'});
        }
        screen.busy = false;
        refresh();
      });
      setBtn.disabled = !chosen();
      actions.append(setBtn);
    }

    // The lesson form.
    function viewForm(body, actions) {
      const l = saved.lesson;
      const info = countryInfo(country);
      const school = info?.schools.find(s => s.name === l.school) || null;
      const set = (k, v, redraw = false) => {
        l[k] = v;
        screen.message = '';
        save();
        if (redraw) refresh();
        else start.disabled = !ready();
      };
      body.append(el('p', 'mc-text dim small', t('classCountryIs', country)));
      if (info) {
        body.append(chips(t('classSchool'), l.school, info.schools.map(s => s.name), v => {
          if (v !== l.school) { l.year = ''; l.level = ''; }
          set('school', v, true);
        }));
        if (school?.levels) {
          body.append(chips(t('classLevel'), l.level, school.levels.map(([n]) => n), v => {
            if (!yearsFor(school, v).includes(l.year)) l.year = '';
            set('level', v, true);
          }));
        }
        if (school) body.append(chips(t('classYear'), l.year, yearsFor(school, l.level), v => set('year', v, true)));
      } else {
        body.append(field(t('classSchool'), l.school, [], v => set('school', v)));
        body.append(field(t('classYear'), l.year, [], v => set('year', v)));
        body.append(field(t('classLevel'), l.level, [], v => set('level', v)));
      }
      const subjects = info ? info.subjects[l.school] || info.subjects.default : [];
      body.append(field(t('classSubject'), l.subject, subjects, v => set('subject', v)));
      const publishers = info ? info.publishers[l.subject] || info.publishers.default || [] : [];
      body.append(field(t('classPublisher'), l.publisher, publishers, v => set('publisher', v)));
      const pair = el('div', 'cr-pair');
      pair.append(field(t('classChapter'), l.chapter, [], v => set('chapter', v), {max: 20, hint: '4'}),
        field(t('classParagraph'), l.paragraph, [], v => set('paragraph', v), {max: 20, hint: '4.2'}));
      body.append(pair);
      body.append(field(t('classTopic'), l.topic, [], v => set('topic', v), {max: 200, hint: t('classTopicHint')}));
      const needsLevel = info ? !!school?.levels : false;
      const ready = () => ['school', 'year', 'subject', 'publisher', 'chapter', 'paragraph', 'topic'].every(k => (l[k] || '').trim()) && (!needsLevel || (l.level || '').trim());
      const start = button(t('classStart'), () => {
        if (!ready()) { screen.message = t('classNeedAll'); refresh(); return; }
        const lesson = {};
        for (const k of FIELDS) lesson[k] = (l[k] || '').trim();
        if (!needsLevel && info) lesson.level = '';
        saved.session = {lesson, items: [], index: 0, handedIn: false};
        save();
        nextQuestion();
      });
      start.disabled = !ready();
      actions.append(start);
    }

    // Fetches one more question and shows it.
    async function nextQuestion() {
      const s = saved.session;
      if (!s || !screen || screen.busy) return;
      if (s.items.length >= MAX_QUESTIONS) { screen.message = t('classLast'); refresh(); return; }
      screen.view = 'question';
      screen.busy = true;
      screen.asking = true;
      screen.message = '';
      refresh();
      try {
        const q = await ask({op: 'question', lesson: s.lesson, asked: s.items.map(i => i.question), number: s.items.length + 1}, 100000);
        if (saved.session !== s) return;
        s.items.push({question: String(q.question || ''), choices: Array.isArray(q.choices) ? q.choices.map(String) : [], answer: '', skipped: false, review: null});
        s.index = s.items.length - 1;
        save();
      } catch (e) {
        screen && (screen.message = `${t('classFailed')}: ${e.message}`);
        if (e.code === 'no_country') { country = null; if (screen) screen.view = 'country'; }
      } finally {
        if (screen) { screen.busy = false; screen.asking = false; }
      }
      if (screen && !s.items.length && screen.view === 'question') screen.view = 'form';
      if (screen && !s.items.length) { saved.session = null; save(); }
      refresh();
      setTimeout(() => root.querySelector('.cr-answer, .cr-choice')?.focus(), 30);
    }

    function viewQuestion(body, actions) {
      const s = saved.session;
      if (!s) { screen.view = 'form'; return viewForm(body, actions); }
      body.append(el('p', 'mc-text dim small', [s.lesson.subject, s.lesson.publisher, s.lesson.paragraph, s.lesson.topic].filter(Boolean).join(' · ')));
      // The questions so far, to go back to one.
      if (s.items.length > 1) {
        const strip = el('div', 'cr-strip');
        s.items.forEach((item, i) => {
          const b = el('button', 'cr-num' + (i === s.index ? ' on' : '') + (item.skipped ? ' skipped' : item.answer.trim() ? ' done' : ''), String(i + 1));
          b.type = 'button';
          b.setAttribute('aria-label', t('classQuestion', i + 1));
          b.onclick = () => { if (!screen.busy) { s.index = i; save(); refresh(); } };
          strip.append(b);
        });
        body.append(strip);
      }
      if (screen.asking) {
        body.append(wait(t('classAsking')));
      } else {
        const item = s.items[s.index];
        if (!item) {
          body.append(button(t('classRetry'), () => nextQuestion()));
        } else {
          body.append(el('p', 'mc-text cr-qnum', t('classQuestion', s.index + 1) + (item.skipped ? ` — ${t('classSkipped')}` : '')));
          body.append(el('p', 'mc-text cr-question', item.question));
          if (item.choices.length) {
            const list = el('div', 'cr-choices');
            list.setAttribute('role', 'radiogroup');
            item.choices.forEach((c, i) => {
              const letter = String.fromCharCode(65 + i);
              const on = item.answer === `${letter}. ${c}`;
              const b = el('button', 'cr-choice' + (on ? ' on' : ''), `${letter}. ${c}`);
              b.type = 'button';
              b.setAttribute('role', 'radio');
              b.setAttribute('aria-checked', String(on));
              b.onclick = () => { item.answer = `${letter}. ${c}`; item.skipped = false; save(); refresh(); };
              list.append(b);
            });
            body.append(list);
          } else {
            const area = el('textarea', 'mc-field cr-answer');
            area.value = item.answer;
            area.placeholder = t('classAnswerHint');
            area.maxLength = 2000;
            area.spellcheck = false;
            area.setAttribute('aria-label', t('classAnswerHint'));
            area.oninput = () => { item.answer = area.value; if (area.value.trim()) item.skipped = false; save(); };
            body.append(area);
          }
        }
      }
      const item = s.items[s.index];
      const last = s.index === s.items.length - 1;
      const prev = button(t('classPrev'), () => { s.index--; save(); refresh(); });
      prev.disabled = screen.busy || s.index === 0;
      const skip = button(t('classSkip'), () => {
        if (item) { item.skipped = true; item.answer = ''; }
        save();
        if (last) nextQuestion(); else { s.index++; save(); refresh(); }
      });
      skip.disabled = screen.busy || !item;
      const next = button(t('classNext'), () => {
        if (last) nextQuestion(); else { s.index++; save(); refresh(); }
      }, 'cr-primary');
      next.disabled = screen.busy || !item || (last && s.items.length >= MAX_QUESTIONS);
      const handIn = button(t('classHandIn'), () => handInLesson());
      handIn.disabled = screen.busy || !s.items.some(i => !i.skipped && i.answer.trim());
      actions.append(prev, skip, next, handIn);
    }

    function viewChecking(body) {
      body.append(wait(t('classChecking')));
    }

    async function handInLesson() {
      const s = saved.session;
      if (!s || screen.busy) return;
      const answered = s.items.filter(i => !i.skipped && i.answer.trim());
      if (!answered.length) { screen.message = t('classNothing'); refresh(); return; }
      if (!await confirmIn(t('classHandInConfirm', answered.length)) || !screen) return;
      screen.busy = true;
      screen.view = 'checking';
      screen.message = '';
      refresh();
      try {
        const r = await ask({op: 'review', lesson: s.lesson, items: answered.map(i => ({question: i.question, choices: i.choices, answer: i.answer}))}, 260000);
        const results = Array.isArray(r.results) ? r.results : [];
        answered.forEach((item, i) => { item.review = results[i] && typeof results[i] === 'object' ? results[i] : null; });
        s.handedIn = true;
        save();
        if (screen) screen.view = 'results';
      } catch (e) {
        if (screen) { screen.view = 'question'; screen.message = `${t('classFailed')}: ${e.message}`; }
      } finally {
        if (screen) screen.busy = false;
      }
      refresh();
    }

    function tally(s) {
      const n = {correct: 0, partly: 0, wrong: 0};
      for (const i of s.items) if (i.review && n[i.review.result] != null) n[i.review.result]++;
      return n;
    }

    function viewResults(body, actions) {
      const s = saved.session;
      if (!s) { screen.view = 'form'; return viewForm(body, actions); }
      const n = tally(s);
      body.append(el('p', 'mc-text dim small', [s.lesson.subject, s.lesson.publisher, s.lesson.paragraph, s.lesson.topic].filter(Boolean).join(' · ')));
      body.append(el('p', 'mc-text cr-score', t('classScore', n.correct, n.partly, n.wrong)));
      const list = el('div', 'cr-results');
      s.items.forEach((item, i) => {
        const r = item.review;
        const kind = item.skipped || !item.answer.trim() ? 'skipped' : r ? r.result : 'none';
        const card = el('div', 'cr-result ' + kind);
        const head = el('p', 'mc-text cr-verdict');
        head.textContent = `${i + 1}. ` + {correct: t('classCorrect'), partly: t('classPartly'), wrong: t('classWrong'), skipped: t('classSkipped'), none: t('classUnchecked')}[kind];
        card.append(head, el('p', 'mc-text small cr-q', item.question));
        if (kind !== 'skipped') card.append(el('p', 'mc-text small cr-mine', `${t('classYourAnswer')}: ${item.answer}`));
        if (r?.feedback) card.append(el('p', 'mc-text small cr-feedback', r.feedback));
        if (r?.answer && kind !== 'correct') card.append(el('p', 'mc-text small cr-model', `${t('classModel')}: ${r.answer}`));
        list.append(card);
      });
      body.append(list);
      actions.append(
        button(t('classAgain'), () => {
          saved.session = {lesson: s.lesson, items: [], index: 0, handedIn: false};
          save();
          nextQuestion();
        }, 'cr-primary'),
        button(t('classNew'), () => { saved.session = null; save(); screen.view = 'form'; refresh(); }),
      );
    }

    const classroom = {
      receive, build, step, pick, open, close, useDoor,
      setLanguages(map) {
        languages = map && typeof map === 'object' ? map : {};
        if (screen) refresh();
        drawBoard();
      },
      get colliders() { return door.colliders; },
      get isOpen() { return !!screen; },
      get access() { return access; },
      get floor() { return built ? built.floor : null; },
      get basement() { return built; },
      t,
      // For the page's list of things to do, when it reads to a screen reader.
      actions(floor) {
        if (!built) return [];
        if (floor === 0) return [{what: 'down', label: t('classDown')}];
        if (floor !== built.floor) return [];
        return [
          {what: 'up', label: t('classUp')},
          {what: 'door', label: access === 'ok' ? `${t(door.target ? 'closeDoor' : 'openDoor')} — ${t('classroom')}` : `${t('classLocked')} — ${lockedReason()}`},
          ...(access === 'ok' && door.open > 0.5 ? [{what: 'desk', seat: built.desks[0], label: t('classSit')}] : []),
        ];
      },
    };
    return classroom;
  }

  // ── The demo page's stand-in for the app ───────────────────────────────
  // `?classroom=plan` (or `signin`, `offline`) locks the door.
  function demo(m, emit) {
    const params = new URLSearchParams(location.search);
    const store = (k, v) => { try { if (v === undefined) return JSON.parse(localStorage.getItem(k) || 'null'); localStorage.setItem(k, JSON.stringify(v)); } catch { /* storage blocked */ } return null; };
    if (m.type === 'ready') {
      emit({type: 'classroom', saved: store('library.classroom')});
      emit({type: 'classroom', state: {access: params.get('classroom') || 'ok', country: store('library.classroom.country')}});
      return;
    }
    const reply = (data, delay = 700) => setTimeout(() => emit({type: 'classroom', request: m.request, data}), delay);
    switch (m.op) {
      case 'save': store('library.classroom', m.state); break;
      case 'state': emit({type: 'classroom', state: {access: params.get('classroom') || 'ok', country: store('library.classroom.country')}}); break;
      case 'country':
        if (store('library.classroom.country')) emit({type: 'classroom', request: m.request, error: {code: 'country_locked', message: 'Your country is already set.'}});
        else { store('library.classroom.country', m.country); reply({country: m.country}, 300); }
        break;
      case 'question': {
        const n = m.number || 1;
        const qs = [
          {question: `In a right triangle the sides are 6 cm and 8 cm. How long is the hypotenuse? (question ${n} about ${m.lesson.topic})`, choices: []},
          {question: 'Which formula is the Pythagorean theorem?', choices: ['a + b = c', 'a² + b² = c²', 'a² − b² = c', '2a + 2b = c']},
          {question: 'Explain in your own words when you may use the theorem.', choices: []},
        ];
        reply(qs[(n - 1) % qs.length], 900);
        break;
      }
      case 'review':
        reply({results: m.items.map((item, i) => ({
          result: ['correct', 'partly', 'wrong'][i % 3],
          feedback: i % 3 ? 'You are on the right track, but the units are missing.' : '',
          answer: '10 cm',
        }))}, 1500);
        break;
    }
  }

  window.LibraryClassroom = {create, demo, COUNTRIES, yearsFor, languageOf};
})();
