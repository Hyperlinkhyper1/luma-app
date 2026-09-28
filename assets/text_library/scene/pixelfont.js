// Pixel font for the library: glyph bitmaps turned into a real TrueType font
// at runtime, so the book editor can use an ordinary contenteditable.
//
// Glyphs come from Minecraft's own font bitmaps when luma found a copy of the
// game on this machine, and otherwise from the hand-drawn set below, which is
// luma's own lettering in the same 5×7 spirit. Nothing Mojang-owned is in
// this file.
(() => {
  'use strict';

  // Rows run top (cap height) to bottom; row 7 sits below the baseline. A
  // leading number sets the first row's index when a glyph rises above the
  // cap line (accents on capitals) — e.g. '-2|' means the first row is -2.
  const G = {
    A: '.###.|#...#|#...#|#####|#...#|#...#|#...#',
    B: '####.|#...#|####.|#...#|#...#|#...#|####.',
    C: '.###.|#...#|#....|#....|#....|#...#|.###.',
    D: '####.|#...#|#...#|#...#|#...#|#...#|####.',
    E: '#####|#....|###..|#....|#....|#....|#####',
    F: '#####|#....|###..|#....|#....|#....|#....',
    G: '.####|#....|#..##|#...#|#...#|#...#|.###.',
    H: '#...#|#...#|#####|#...#|#...#|#...#|#...#',
    I: '###|.#.|.#.|.#.|.#.|.#.|###',
    J: '....#|....#|....#|....#|....#|#...#|.###.',
    K: '#...#|#..#.|###..|#..#.|#...#|#...#|#...#',
    L: '#....|#....|#....|#....|#....|#....|#####',
    M: '#...#|##.##|#.#.#|#...#|#...#|#...#|#...#',
    N: '#...#|##..#|#.#.#|#..##|#...#|#...#|#...#',
    O: '.###.|#...#|#...#|#...#|#...#|#...#|.###.',
    P: '####.|#...#|####.|#....|#....|#....|#....',
    Q: '.###.|#...#|#...#|#...#|#...#|#..#.|.##.#',
    R: '####.|#...#|####.|#...#|#...#|#...#|#...#',
    S: '.####|#....|.###.|....#|....#|#...#|.###.',
    T: '#####|..#..|..#..|..#..|..#..|..#..|..#..',
    U: '#...#|#...#|#...#|#...#|#...#|#...#|.###.',
    V: '#...#|#...#|#...#|#...#|#...#|.#.#.|..#..',
    W: '#...#|#...#|#...#|#...#|#.#.#|##.##|#...#',
    X: '#...#|.#.#.|..#..|.#.#.|#...#|#...#|#...#',
    Y: '#...#|.#.#.|..#..|..#..|..#..|..#..|..#..',
    Z: '#####|....#|...#.|..#..|.#...|#....|#####',
    a: '.....|.....|.###.|....#|.####|#...#|.####',
    b: '#....|#....|#.##.|##..#|#...#|#...#|####.',
    c: '.....|.....|.###.|#...#|#....|#...#|.###.',
    d: '....#|....#|.##.#|#..##|#...#|#...#|.####',
    e: '.....|.....|.###.|#...#|#####|#....|.####',
    f: '..##|.#..|####|.#..|.#..|.#..|.#..',
    g: '.....|.....|.####|#...#|#...#|.####|....#|####.',
    h: '#....|#....|#.##.|##..#|#...#|#...#|#...#',
    i: '#|.|#|#|#|#|#',
    j: '....#|.....|....#|....#|....#|....#|#...#|.###.',
    k: '#...|#...|#..#|#.#.|##..|#.#.|#..#',
    l: '#.|#.|#.|#.|#.|#.|.#',
    m: '.....|.....|##.#.|#.#.#|#.#.#|#...#|#...#',
    n: '.....|.....|####.|#...#|#...#|#...#|#...#',
    o: '.....|.....|.###.|#...#|#...#|#...#|.###.',
    p: '.....|.....|#.##.|##..#|#...#|####.|#....|#....',
    q: '.....|.....|.##.#|#..##|#...#|.####|....#|....#',
    r: '.....|.....|#.##.|##..#|#....|#....|#....',
    s: '.....|.....|.####|#....|.###.|....#|####.',
    t: '.#.|.#.|###|.#.|.#.|.#.|..#',
    u: '.....|.....|#...#|#...#|#...#|#...#|.####',
    v: '.....|.....|#...#|#...#|#...#|.#.#.|..#..',
    w: '.....|.....|#...#|#...#|#.#.#|#.#.#|.####',
    x: '.....|.....|#...#|.#.#.|..#..|.#.#.|#...#',
    y: '.....|.....|#...#|#...#|#...#|.####|....#|####.',
    z: '.....|.....|#####|...#.|..#..|.#...|#####',
    0: '.###.|#...#|#..##|#.#.#|##..#|#...#|.###.',
    1: '..#..|.##..|..#..|..#..|..#..|..#..|#####',
    2: '.###.|#...#|....#|..##.|.#...|#...#|#####',
    3: '.###.|#...#|....#|..##.|....#|#...#|.###.',
    4: '...##|..#.#|.#..#|#...#|#####|....#|....#',
    5: '#####|#....|####.|....#|....#|#...#|.###.',
    6: '..##.|.#...|#....|####.|#...#|#...#|.###.',
    7: '#####|#...#|....#|...#.|..#..|..#..|..#..',
    8: '.###.|#...#|#...#|.###.|#...#|#...#|.###.',
    9: '.###.|#...#|#...#|.####|....#|...#.|.##..',
    '!': '#|#|#|#|#|.|#',
    '"': '#.#|#.#',
    '#': '.#.#.|.#.#.|#####|.#.#.|#####|.#.#.|.#.#.',
    $: '..#..|.####|#....|.###.|....#|####.|..#..',
    '%': '#...#|#..#.|...#.|..#..|.#...|.#..#|#...#',
    '&': '..#..|.#.#.|..#..|.##.#|#..#.|#..#.|.##.#',
    "'": '#|#',
    '(': '..##|.#..|#...|#...|#...|.#..|..##',
    ')': '##..|..#.|...#|...#|...#|..#.|##..',
    '*': '....|....|#..#|.##.|#..#',
    '+': '.....|..#..|..#..|#####|..#..|..#..',
    ',': '.|.|.|.|.|#|#|#',
    '-': '.....|.....|.....|#####',
    '.': '.|.|.|.|.|#|#',
    '/': '....#|...#.|...#.|..#..|.#...|.#...|#....',
    ':': '.|#|#|.|.|#|#',
    ';': '.|#|#|.|.|#|#|#',
    '<': '...#|..#.|.#..|#...|.#..|..#.|...#',
    '=': '.....|.....|#####|.....|.....|#####',
    '>': '#...|.#..|..#.|...#|..#.|.#..|#...',
    '?': '.###.|#...#|....#|...#.|..#..|.....|..#..',
    '@': '.####.|#....#|#.##.#|#.##.#|#.####|#.....|.####.',
    '[': '###|#..|#..|#..|#..|#..|###',
    '\\': '#....|.#...|.#...|..#..|...#.|...#.|....#',
    ']': '###|..#|..#|..#|..#|..#|###',
    '^': '..#..|.#.#.|#...#',
    _: '.....|.....|.....|.....|.....|.....|.....|#####',
    '`': '#.|.#',
    '{': '..##|.#..|.#..|#...|.#..|.#..|..##',
    '|': '#|#|#|#|#|#|#|#',
    '}': '##..|..#.|..#.|...#|..#.|..#.|##..',
    '~': '......|......|.##..#|#..##.',
    'ß': '.###.|#...#|#..#.|#.#..|#..#.|#...#|#.##.',
    '€': '..###|.#...|####.|.#...|####.|.#...|..###',
    '£': '..##.|.#..#|.#...|###..|.#...|.#...|#####',
    '°': '.#.|#.#|.#.',
    '·': '.|.|.|#',
    '•': '..|..|##|##',
    '‘': '.#|#.|##',
    '’': '##|.#|#.',
    '“': '.#.#|#.#.|##.##',
    '”': '##.##|.#.#|#.#.',
    '«': '......|......|..#..#|.#..#.|#..#..|.#..#.|..#..#',
    '»': '......|......|#..#..|.#..#.|..#..#|.#..#.|#..#..',
    '–': '....|....|....|####',
    '—': '........|........|........|########',
    '…': '.....|.....|.....|.....|.....|.....|#.#.#',
    '¡': '#|.|#|#|#|#|#',
    '¿': '..#..|.....|..#..|.#...|#....|#...#|.###.',
    '×': '.....|#...#|.#.#.|..#..|.#.#.|#...#',
    '÷': '.....|..#..|.....|#####|.....|..#..',
    '±': '..#..|..#..|#####|..#..|..#..|.....|#####',
  };
  // Corrections for glyphs whose shorthand above would be ambiguous.
  G['“'] = '.#.#|#.#.|#.#.';
  G['”'] = '.#.#|.#.#|#.#.';

  const ACCENTS = {
    acute: ['...#.', '..#..'],
    grave: ['.#...', '..#..'],
    circ: ['..#..', '.#.#.'],
    diaer: ['.....', '.#.#.'],
    tilde: ['.##.#', '#..#.'],
    ring: ['..#..', '.#.#.'],
  };
  const COMPOSED = {
    à: ['a', 'grave'], á: ['a', 'acute'], â: ['a', 'circ'], ä: ['a', 'diaer'], ã: ['a', 'tilde'], å: ['a', 'ring'],
    è: ['e', 'grave'], é: ['e', 'acute'], ê: ['e', 'circ'], ë: ['e', 'diaer'],
    ò: ['o', 'grave'], ó: ['o', 'acute'], ô: ['o', 'circ'], ö: ['o', 'diaer'], õ: ['o', 'tilde'],
    ù: ['u', 'grave'], ú: ['u', 'acute'], û: ['u', 'circ'], ü: ['u', 'diaer'],
    ñ: ['n', 'tilde'], ý: ['y', 'acute'], ÿ: ['y', 'diaer'],
    À: ['A', 'grave'], Á: ['A', 'acute'], Â: ['A', 'circ'], Ä: ['A', 'diaer'], Ã: ['A', 'tilde'], Å: ['A', 'ring'],
    È: ['E', 'grave'], É: ['E', 'acute'], Ê: ['E', 'circ'], Ë: ['E', 'diaer'],
    Ì: ['I', 'grave'], Í: ['I', 'acute'], Î: ['I', 'circ'], Ï: ['I', 'diaer'],
    Ò: ['O', 'grave'], Ó: ['O', 'acute'], Ô: ['O', 'circ'], Ö: ['O', 'diaer'], Õ: ['O', 'tilde'],
    Ù: ['U', 'grave'], Ú: ['U', 'acute'], Û: ['U', 'circ'], Ü: ['U', 'diaer'],
    Ñ: ['N', 'tilde'], Ý: ['Y', 'acute'],
  };

  // A glyph: {w, top, rows: [[bool…]…], adv}. `top` is the row index of
  // rows[0], counted down from the cap line (0) — negative rises above it.
  function parse(spec) {
    const rows = spec.split('|').map(r => [...r].map(c => c === '#'));
    const w = Math.max(...rows.map(r => r.length));
    for (const r of rows) while (r.length < w) r.push(false);
    return {w, top: 0, rows};
  }

  function builtInGlyphs() {
    const glyphs = new Map();
    for (const [ch, spec] of Object.entries(G)) {
      const g = parse(spec);
      g.adv = g.w + 1;
      glyphs.set(ch.codePointAt(0), g);
    }
    const narrowAccent = {acute: ['..#', '.#.'], grave: ['#..', '.#.'], circ: ['.#.', '#.#'], diaer: ['...', '#.#'], tilde: ['.##', '##.'], ring: ['.#.', '#.#']};
    for (const [ch, [baseCh, accent]] of Object.entries(COMPOSED)) {
      const base = glyphs.get(baseCh.codePointAt(0));
      const w = base.w;
      const mark = (w >= 5 ? ACCENTS : narrowAccent)[accent].map(r => {
        const cells = [...r].map(c => c === '#');
        const pad = Math.max(0, Math.floor((w - cells.length) / 2));
        const row = new Array(w).fill(false);
        cells.forEach((v, i) => { if (i + pad < w) row[i + pad] = v; });
        return row;
      });
      const upper = baseCh === baseCh.toUpperCase() && baseCh !== baseCh.toLowerCase();
      let rows, top;
      if (upper) {
        rows = [...mark, ...base.rows];
        top = -2;
      } else {
        // Lowercase bodies start at row 2, which leaves rows 0–1 for the mark.
        rows = base.rows.map(r => r.slice());
        rows[0] = mark[0];
        rows[1] = mark[1];
        top = 0;
      }
      glyphs.set(ch.codePointAt(0), {w, top, rows, adv: w + 1});
    }
    // ì í î ï: a dotless i under a three-wide mark.
    const dotless = parse('...|...|.#.|.#.|.#.|.#.|.#.');
    for (const [ch, accent] of Object.entries({ì: 'grave', í: 'acute', î: 'circ', ï: 'diaer'})) {
      const rows = dotless.rows.map(r => r.slice());
      rows[0] = [...narrowAccent[accent][0]].map(c => c === '#');
      rows[1] = [...narrowAccent[accent][1]].map(c => c === '#');
      glyphs.set(ch.codePointAt(0), {w: 3, top: 0, rows, adv: 4});
    }
    const c = glyphs.get('c'.codePointAt(0)), C = glyphs.get('C'.codePointAt(0));
    glyphs.set('ç'.codePointAt(0), {w: 5, top: 0, rows: [...c.rows, [false, false, true, false, false], [false, true, true, false, false]], adv: 6});
    glyphs.set('Ç'.codePointAt(0), {w: 5, top: 0, rows: [...C.rows, [false, false, true, false, false], [false, true, true, false, false]], adv: 6});
    return {glyphs, ascent: 9, descent: 2, space: 4, source: null};
  }

  // ── Minecraft bitmap providers ─────────────────────────────────────────
  // Reads `font/include/default.json` and the bitmaps it names, exactly the
  // way the game builds its default font: first provider with a glyph wins,
  // glyph width is its rightmost lit column, advance is width + 1.
  async function vanillaGlyphs(files) {
    const json = files['font/include/default.json'];
    if (!json) return null;
    let providers;
    try { providers = JSON.parse(atob(json)).providers; } catch { return null; }
    const glyphs = new Map();
    let ascent = 7, descent = 1, space = 4;
    for (const provider of providers) {
      if (provider.type === 'space') {
        if (provider.advances && provider.advances[' '] != null) space = provider.advances[' '];
        continue;
      }
      if (provider.type !== 'bitmap' || !provider.file) continue;
      const path = 'textures/' + provider.file.replace(/^minecraft:/, '');
      const data = files[path];
      if (!data) continue;
      const image = await loadImage('data:image/png;base64,' + data);
      const canvas = document.createElement('canvas');
      canvas.width = image.width; canvas.height = image.height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(image, 0, 0);
      const pixels = ctx.getImageData(0, 0, image.width, image.height).data;
      const lines = provider.chars.map(row => [...row]);
      const cols = lines[0].length, rowsCount = lines.length;
      const cw = Math.floor(image.width / cols), ch = Math.floor(image.height / rowsCount);
      const height = provider.height || 8;
      const pAscent = provider.ascent;
      // Glyphs taller than their cell size would be scaled in game; the
      // default font never does this, so a mismatch is simply skipped.
      if (height !== ch) continue;
      ascent = Math.max(ascent, pAscent);
      descent = Math.max(descent, height - pAscent);
      for (let r = 0; r < rowsCount; r++) {
        for (let c = 0; c < cols; c++) {
          const cp = lines[r][c]?.codePointAt(0);
          if (!cp || cp === 32 || glyphs.has(cp)) continue;
          let right = -1;
          const rows = [];
          for (let y = 0; y < ch; y++) {
            const row = [];
            for (let x = 0; x < cw; x++) {
              const a = pixels[((r * ch + y) * image.width + c * cw + x) * 4 + 3];
              row.push(a > 0);
              if (a > 0 && x > right) right = x;
            }
            rows.push(row);
          }
          if (right < 0) continue;
          const w = right + 1;
          glyphs.set(cp, {w, top: 7 - pAscent, rows: rows.map(row => row.slice(0, w)), adv: w + 1});
        }
      }
    }
    if (!glyphs.size) return null;
    return {glyphs, ascent: Math.max(ascent, 9), descent: Math.max(descent, 2), space, source: 'vanilla'};
  }

  function loadImage(src) {
    return new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => resolve(image);
      image.onerror = () => reject(new Error('Font bitmap failed to load'));
      image.src = src;
    });
  }

  function emboldened(g) {
    const w = g.w + 1;
    const rows = g.rows.map(row => {
      const out = new Array(w).fill(false);
      row.forEach((on, x) => { if (on) { out[x] = true; out[x + 1] = true; } });
      return out;
    });
    return {w, top: g.top, rows, adv: g.adv + 1};
  }

  // ── TrueType writer ────────────────────────────────────────────────────
  const U = 128; // font units per pixel; 8 pixels to the em

  class Writer {
    constructor() { this.bytes = []; }
    u8(v) { this.bytes.push(v & 255); }
    u16(v) { this.u8(v >> 8); this.u8(v); }
    i16(v) { this.u16(v < 0 ? v + 65536 : v); }
    u32(v) { this.u16(Math.floor(v / 65536) & 65535); this.u16(v & 65535); }
    tag(s) { for (const c of s) this.u8(c.charCodeAt(0)); }
    pad() { while (this.bytes.length % 4) this.u8(0); }
    // Spreading a large array into push() overflows the call stack.
    append(bytes) { for (let i = 0; i < bytes.length; i++) this.bytes.push(bytes[i]); }
    get length() { return this.bytes.length; }
  }

  function checksum(bytes) {
    let sum = 0;
    for (let i = 0; i < bytes.length; i += 4) {
      sum = (sum + (((bytes[i] << 24) >>> 0) + ((bytes[i + 1] || 0) << 16) + ((bytes[i + 2] || 0) << 8) + (bytes[i + 3] || 0))) >>> 0;
    }
    return sum;
  }

  // Pixel runs merged into rectangles: horizontal runs first, then identical
  // runs on consecutive rows stacked into one taller box.
  function rectangles(g) {
    const open = new Map();
    const done = [];
    g.rows.forEach((row, r) => {
      const runs = [];
      for (let x = 0; x < row.length;) {
        if (!row[x]) { x++; continue; }
        let e = x;
        while (e < row.length && row[e]) e++;
        runs.push([x, e]);
        x = e;
      }
      const seen = new Set();
      for (const [x0, x1] of runs) {
        const key = x0 + ':' + x1;
        seen.add(key);
        const rect = open.get(key);
        if (rect && rect.r1 === r) rect.r1 = r + 1;
        else { const fresh = {x0, x1, r0: r, r1: r + 1}; open.set(key, fresh); done.push(fresh); }
      }
      for (const key of [...open.keys()]) if (!seen.has(key)) open.delete(key);
    });
    return done.map(({x0, x1, r0, r1}) => ({
      x0: x0 * U, x1: x1 * U,
      // Row r spans (6 - r)..(7 - r) pixels above the baseline.
      y0: (6 - (g.top + r1 - 1)) * U, y1: (7 - (g.top + r0)) * U,
    }));
  }

  function buildTtf(font, family, bold) {
    const entries = [...font.glyphs.entries()].sort((a, b) => a[0] - b[0]).filter(([cp]) => cp <= 0xffff);
    const glyphList = [{rects: [], adv: 4 * U}, {rects: [], adv: font.space * U}];
    const cmap = [[32, 1]];
    for (const [cp, g0] of entries) {
      const g = bold ? emboldened(g0) : g0;
      cmap.push([cp, glyphList.length]);
      glyphList.push({rects: rectangles(g), adv: g.adv * U});
    }
    cmap.sort((a, b) => a[0] - b[0]);

    // glyf + loca
    const glyf = new Writer();
    const loca = [];
    let maxPoints = 0, maxContours = 0;
    let xMin = 0, yMin = 0, xMax = 0, yMax = 0;
    for (const glyph of glyphList) {
      loca.push(glyf.length);
      if (!glyph.rects.length) continue;
      const bx0 = Math.min(...glyph.rects.map(r => r.x0)), bx1 = Math.max(...glyph.rects.map(r => r.x1));
      const by0 = Math.min(...glyph.rects.map(r => r.y0)), by1 = Math.max(...glyph.rects.map(r => r.y1));
      xMin = Math.min(xMin, bx0); yMin = Math.min(yMin, by0); xMax = Math.max(xMax, bx1); yMax = Math.max(yMax, by1);
      glyf.i16(glyph.rects.length);
      glyf.i16(bx0); glyf.i16(by0); glyf.i16(bx1); glyf.i16(by1);
      glyph.rects.forEach((_, i) => glyf.u16(i * 4 + 3));
      glyf.u16(0);
      const points = [];
      // Clockwise with y up: left edge upward, top edge rightward.
      for (const r of glyph.rects) points.push([r.x0, r.y0], [r.x0, r.y1], [r.x1, r.y1], [r.x1, r.y0]);
      for (let i = 0; i < points.length; i++) glyf.u8(1);
      let px = 0, py = 0;
      for (const [x] of points) { glyf.i16(x - px); px = x; }
      for (const [, y] of points) { glyf.i16(y - py); py = y; }
      glyf.pad();
      maxPoints = Math.max(maxPoints, points.length);
      maxContours = Math.max(maxContours, glyph.rects.length);
    }
    loca.push(glyf.length);
    const locaW = new Writer();
    for (const o of loca) locaW.u32(o);

    const ascent = font.ascent * U, descent = font.descent * U;
    const advMax = Math.max(...glyphList.map(g => g.adv));
    const avg = Math.round(glyphList.reduce((s, g) => s + g.adv, 0) / glyphList.length);

    const head = new Writer();
    head.u32(0x00010000); head.u32(0x00010000); head.u32(0); head.u32(0x5F0F3CF5);
    head.u16(0x000B); head.u16(8 * U);
    head.u32(0); head.u32(0); head.u32(0); head.u32(0);
    head.i16(xMin); head.i16(yMin); head.i16(xMax); head.i16(yMax);
    head.u16(bold ? 1 : 0); head.u16(8); head.i16(2); head.i16(1); head.i16(0);

    const hhea = new Writer();
    hhea.u32(0x00010000); hhea.i16(ascent); hhea.i16(-descent); hhea.i16(0);
    hhea.u16(advMax); hhea.i16(0); hhea.i16(0); hhea.i16(xMax);
    hhea.i16(1); hhea.i16(0); hhea.i16(0);
    for (let i = 0; i < 4; i++) hhea.i16(0);
    hhea.i16(0); hhea.u16(glyphList.length);

    const hmtx = new Writer();
    for (const g of glyphList) {
      hmtx.u16(g.adv);
      hmtx.i16(g.rects.length ? Math.min(...g.rects.map(r => r.x0)) : 0);
    }

    const maxp = new Writer();
    maxp.u32(0x00010000); maxp.u16(glyphList.length); maxp.u16(maxPoints); maxp.u16(maxContours);
    maxp.u16(0); maxp.u16(0); maxp.u16(2);
    for (let i = 0; i < 8; i++) maxp.u16(0);

    const os2 = new Writer();
    os2.u16(4); os2.i16(avg); os2.u16(bold ? 700 : 400); os2.u16(5); os2.u16(0);
    for (const v of [4 * U, 4 * U, 0, U, 4 * U, 4 * U, 0, 4 * U]) os2.i16(v);
    os2.i16(U); os2.i16(3 * U);
    os2.i16(0);
    for (let i = 0; i < 10; i++) os2.u8(0);
    os2.u32(0x00000003); os2.u32(0); os2.u32(0); os2.u32(0);
    os2.tag('LUMA');
    os2.u16((bold ? 0x20 : 0x40) | 0x80);
    os2.u16(Math.min(0xffff, cmap[0][0])); os2.u16(Math.min(0xffff, cmap[cmap.length - 1][0]));
    os2.i16(ascent); os2.i16(-descent); os2.i16(0);
    os2.u16(ascent); os2.u16(descent);
    os2.u32(0x00000001); os2.u32(0);
    os2.i16(5 * U); os2.i16(7 * U); os2.u16(0); os2.u16(32); os2.u16(1);

    // cmap format 4, one segment per run of consecutive code points whose
    // glyph ids are also consecutive.
    const segments = [];
    for (const [cp, gid] of cmap) {
      const last = segments[segments.length - 1];
      if (last && cp === last.end + 1 && gid - cp === last.delta) last.end = cp;
      else segments.push({start: cp, end: cp, delta: gid - cp});
    }
    segments.push({start: 0xffff, end: 0xffff, delta: 1});
    const segX2 = segments.length * 2;
    let search = 1, selector = 0;
    while (search * 2 <= segments.length) { search *= 2; selector++; }
    const sub = new Writer();
    sub.u16(4); sub.u16(16 + segments.length * 8); sub.u16(0);
    sub.u16(segX2); sub.u16(search * 2); sub.u16(selector); sub.u16(segX2 - search * 2);
    for (const s of segments) sub.u16(s.end);
    sub.u16(0);
    for (const s of segments) sub.u16(s.start);
    for (const s of segments) sub.u16((s.delta + 65536) % 65536);
    for (let i = 0; i < segments.length; i++) sub.u16(0);
    const cmapW = new Writer();
    cmapW.u16(0); cmapW.u16(1); cmapW.u16(3); cmapW.u16(1); cmapW.u32(12);
    cmapW.append(sub.bytes);

    const names = [[1, family], [2, bold ? 'Bold' : 'Regular'], [3, family + (bold ? ' Bold' : '')], [4, family + (bold ? ' Bold' : '')], [6, (family + (bold ? '-Bold' : '-Regular')).replace(/\s/g, '')]];
    const name = new Writer();
    name.u16(0); name.u16(names.length); name.u16(6 + names.length * 12);
    let offset = 0;
    const strings = [];
    for (const [id, value] of names) {
      const bytes = [];
      for (const c of value) { const code = c.charCodeAt(0); bytes.push(code >> 8, code & 255); }
      name.u16(3); name.u16(1); name.u16(0x409); name.u16(id); name.u16(bytes.length); name.u16(offset);
      offset += bytes.length;
      strings.push(...bytes);
    }
    name.append(strings);

    const post = new Writer();
    post.u32(0x00030000); post.u32(0); post.i16(-U); post.i16(U); post.u32(0);
    post.u32(0); post.u32(0); post.u32(0); post.u32(0);

    const tables = [
      ['OS/2', os2], ['cmap', cmapW], ['glyf', glyf], ['head', head], ['hhea', hhea],
      ['hmtx', hmtx], ['loca', locaW], ['maxp', maxp], ['name', name], ['post', post],
    ];
    const out = new Writer();
    let sr = 1, es = 0;
    while (sr * 2 <= tables.length) { sr *= 2; es++; }
    out.u32(0x00010000); out.u16(tables.length); out.u16(sr * 16); out.u16(es); out.u16(tables.length * 16 - sr * 16);
    let cursor = 12 + tables.length * 16;
    const layout = [];
    for (const [tag, w] of tables) {
      const len = w.length;
      layout.push({tag, w, offset: cursor, len});
      cursor += len + ((4 - len % 4) % 4);
    }
    for (const {tag, w, offset: o, len} of layout) {
      out.tag(tag); out.u32(checksum(w.bytes)); out.u32(o); out.u32(len);
    }
    for (const {w} of layout) { out.append(w.bytes); out.pad(); }
    const bytes = new Uint8Array(out.bytes);
    const headOffset = layout.find(t => t.tag === 'head').offset;
    const adjust = (0xB1B0AFBA - checksum(out.bytes)) >>> 0;
    bytes[headOffset + 8] = adjust >>> 24; bytes[headOffset + 9] = (adjust >>> 16) & 255;
    bytes[headOffset + 10] = (adjust >>> 8) & 255; bytes[headOffset + 11] = adjust & 255;
    return bytes.buffer;
  }

  // ── Public API ─────────────────────────────────────────────────────────
  const FAMILY = 'LibraryPixel';
  let current = builtInGlyphs();
  let generation = 0;
  const faces = [];

  async function install(font) {
    const mine = ++generation;
    const regular = new FontFace(FAMILY, buildTtf(font, FAMILY, false), {weight: '400', style: 'normal'});
    const bold = new FontFace(FAMILY, buildTtf(font, FAMILY, true), {weight: '700', style: 'normal'});
    await Promise.all([regular.load(), bold.load()]);
    if (mine !== generation) return;
    for (const face of faces.splice(0)) document.fonts.delete(face);
    document.fonts.add(regular);
    document.fonts.add(bold);
    faces.push(regular, bold);
    current = font;
  }

  // Draws [text] straight from the bitmaps — pixel-exact, for canvases (book
  // spines, signs). Returns the width in pixels at scale 1.
  function draw(ctx, text, x, y, {scale = 1, color = '#fff', shadow = null, bold = false} = {}) {
    let pen = 0;
    for (const ch of text) {
      const cp = ch.codePointAt(0);
      if (cp === 32) { pen += current.space + (bold ? 1 : 0); continue; }
      let g = current.glyphs.get(cp) || current.glyphs.get(63);
      if (!g) continue;
      if (bold) g = emboldened(g);
      if (ctx) {
        for (const [ox, oy, fill] of shadow ? [[1, 1, shadow], [0, 0, color]] : [[0, 0, color]]) {
          ctx.fillStyle = fill;
          g.rows.forEach((row, r) => row.forEach((on, c) => {
            if (on) ctx.fillRect(x + (pen + c + ox) * scale, y + (g.top + r + oy) * scale, scale, scale);
          }));
        }
      }
      pen += g.adv;
    }
    return pen;
  }

  const measure = (text, bold = false) => draw(null, text, 0, 0, {bold});

  window.PixelFont = {
    FAMILY,
    ready: install(current).catch(() => {}),
    async useVanilla(files) {
      try {
        const font = await vanillaGlyphs(files);
        if (font) await install(font);
        return !!font;
      } catch (e) {
        console.warn('Minecraft font unavailable', e);
        return false;
      }
    },
    draw,
    measure,
    get source() { return current.source; },
    // Exposed for the structural check.
    _buildTtf: buildTtf,
    _builtIn: builtInGlyphs,
    _vanilla: vanillaGlyphs,
  };
})();
