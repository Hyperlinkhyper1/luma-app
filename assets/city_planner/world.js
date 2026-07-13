// ─────────────────────────────────────────────────────────────
// MetroPlan — wereld: terrein-generatie, tegel-data, chunk-cache
// ─────────────────────────────────────────────────────────────
"use strict";

const W = WORLD_W, H = WORLD_H, N = W * H;
const idx = (x, y) => y * W + x;
const inWorld = (x, y) => x >= 0 && y >= 0 && x < W && y < H;

// Globale spelstaat. Wordt gevuld door newGame()/loadGame().
const G = {
  seed: 1,
  mode: "classic",        // "classic" | "sandbox"
  // tegel-lagen (typed arrays voor grote steden)
  terrain: new Uint8Array(N),
  height: new Float32Array(N),
  fert: new Float32Array(N),
  road: new Uint8Array(N),
  bld: new Int32Array(N),        // gebouw-id + 1, 0 = leeg
  traffic: new Float32Array(N),  // voertuigen per dag op wegtegel
  pollution: new Float32Array(N),
  noise: new Float32Array(N),
  landValue: new Float32Array(N),
  powerOk: new Uint8Array(N),    // dekking energienet (0..2, 2=goed)
  waterOk: new Uint8Array(N),
  svcEdu: new Float32Array(N),   // dekking 0..1
  svcHealth: new Float32Array(N),
  svcSafety: new Float32Array(N),
  svcTransit: new Float32Array(N),
  svcGreen: new Float32Array(N),
  happyMap: new Float32Array(N),

  buildings: [],          // {id,type,cells:[],x,y,naam,jaar,floors:[{use}],bew,banen,...}
  freeBldIds: [],
  transitLines: [],       // {id,type,naam,stops:[i,...],freq, ridership, actief}
  nextLineId: 1,
  // vrije spline-wegen: {id, type, pts:[{x,y}], cum:[], len, w}
  // De rasterisatie naar G.road blijft de bron voor de simulatie.
  roadPaths: [],
  nextPathId: 1,
  roadCover: new Uint8Array(N), // aantal paden dat een tegel bedekt (0 = legacy/geen)
  junctions: [],                // tegelindexen waar paden elkaar kruisen
  settings: { grid: true, snap: true, gridSize: 1 },

  money: 150000,
  day: 1, month: 1, year: 1925,
  speed: 1,
  fase: 1,
  rp: 0, rpPerDag: 0,
  techs: {},              // id -> true
  policies: {},           // id -> true
  taxes: { wonen: 9, bedrijf: 9, verkoop: 6 },

  pop: 0,
  cohorts: { kinderen: 0, studenten: 0, werkenden: 0, ouderen: 0 },
  jobs: 0, jobsFilled: 0,
  happy: 60,
  demand: { wonen: 10, commercieel: 0, industrie: 0 },
  stats: {},              // dag/maand-statistieken voor panelen
  lastBudget: { in: {}, uit: {}, saldo: 0 },
  weerFactor: 0.8,        // opbrengstfactor hernieuwbaar (random walk)
  news: [],
  gameOver: false,
};

// ── Ruis-generator (value noise, deterministisch per seed) ──
function makeNoise(seed) {
  const rand = mulberry(seed);
  const perm = new Uint8Array(512);
  const p = [...Array(256).keys()];
  for (let i = 255; i > 0; i--) { const j = (rand() * (i + 1)) | 0; [p[i], p[j]] = [p[j], p[i]]; }
  for (let i = 0; i < 512; i++) perm[i] = p[i & 255];
  const grad = i => (perm[i] / 255) * 2 - 1;
  function noise2(x, y) {
    const xi = Math.floor(x), yi = Math.floor(y);
    const xf = x - xi, yf = y - yi;
    const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
    const a = grad(perm[(xi & 255) + perm[yi & 255]]);
    const b = grad(perm[((xi + 1) & 255) + perm[yi & 255]]);
    const c = grad(perm[(xi & 255) + perm[(yi + 1) & 255]]);
    const d = grad(perm[((xi + 1) & 255) + perm[(yi + 1) & 255]]);
    return a + u * (b - a) + v * (c - a) + u * v * (a - b - c + d);
  }
  return (x, y, oct = 4) => {
    let s = 0, amp = 1, freq = 1, tot = 0;
    for (let o = 0; o < oct; o++) { s += noise2(x * freq, y * freq) * amp; tot += amp; amp *= .5; freq *= 2; }
    return s / tot;
  };
}
function mulberry(a) {
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
let RNG = mulberry(1);

// ── Wereldgeneratie ──
function genWorld(seed) {
  G.seed = seed;
  RNG = mulberry(seed);
  const noise = makeNoise(seed);
  const moist = makeNoise(seed ^ 0x9e3779b9);

  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = idx(x, y);
      const h = noise(x / 42, y / 42, 5) * 0.5 + 0.5; // 0..1
      const m = moist(x / 30, y / 30, 4) * 0.5 + 0.5;
      G.height[i] = h;
      let t;
      if (h > 0.78) t = TERRAIN.BERG;
      else if (h > 0.66) t = TERRAIN.HEUVEL;
      else if (h < 0.28) t = TERRAIN.MEER;
      else if (m > 0.62 && h < 0.6) t = TERRAIN.BOS;
      else if (m < 0.3 && h > 0.45) t = TERRAIN.ZAND;
      else t = TERRAIN.GRAS;
      G.terrain[i] = t;
      G.fert[i] = Math.max(0, Math.min(1, m * 0.8 + (1 - h) * 0.4)) * TERRAIN_DEF[t].vrucht + (t === TERRAIN.GRAS ? 0.2 : 0);
    }
  }
  carveRiver(noise);
  // kustranden rond meren
  for (let y = 1; y < H - 1; y++) for (let x = 1; x < W - 1; x++) {
    const i = idx(x, y);
    if (G.terrain[i] === TERRAIN.MEER) {
      let edge = false;
      for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]])
        if (!isWater(G.terrain[idx(x+dx, y+dy)])) edge = true;
      if (edge) G.terrain[i] = TERRAIN.KUST;
    }
  }
}

function carveRiver(noise) {
  // rivier van boven naar beneden, meandert met ruis
  let x = W * (0.3 + RNG() * 0.4);
  for (let y = 0; y < H; y++) {
    x += noise(y / 18, 7.7, 3) * 3;
    x = Math.max(4, Math.min(W - 5, x));
    const w = 1 + Math.round(1 + noise(y / 25, 3.1, 2));
    for (let dx = -w; dx <= w; dx++) {
      const xi = Math.round(x) + dx;
      if (inWorld(xi, y)) {
        const i = idx(xi, y);
        G.terrain[i] = TERRAIN.RIVIER;
        G.height[i] = 0.2;
      }
    }
  }
}

// ── Hulpfuncties tegels ──
function tileBuildable(i) {
  return TERRAIN_DEF[G.terrain[i]].bouwbaar && G.road[i] === 0 && G.bld[i] === 0;
}
function nearWater(i, r = 2) {
  const x = i % W, y = (i / W) | 0;
  for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
    if (inWorld(x + dx, y + dy) && isWater(G.terrain[idx(x + dx, y + dy)])) return true;
  }
  return false;
}
function adjacentRoad(i) {
  const x = i % W, y = (i / W) | 0;
  for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]])
    if (inWorld(x + dx, y + dy) && G.road[idx(x + dx, y + dy)] > 0) return idx(x + dx, y + dy);
  return -1;
}

// ── Gebouwen ──
function buildingCapacity(b) {
  const def = BUILDINGS[b.type];
  const cells = b.cells.length;
  let bew = 0, banen = 0, energie = 0, water = 0, waarde = 0, inkomen = 0;
  for (const f of b.floors) {
    const u = FLOOR_USES[f.use] || FLOOR_USES.leeg;
    bew += u.bew * cells; banen += u.banen * cells;
    energie += u.energie * cells; water += u.water * cells;
    waarde += u.waarde * cells; inkomen += u.inkomen * cells;
  }
  banen += (def.banenVast || 0) * cells;
  energie += (def.energieVast || 0) * cells;
  if (G.techs.slimme_gebouwen) { energie *= 0.8; water *= 0.8; }
  if (G.policies.groen_verplicht) energie *= 0.9;
  return { bew: Math.round(bew), banen: Math.round(banen), energie, water, waarde, inkomen };
}

function makeBuilding(type, cells, ox = 0, oy = 0) {
  const def = BUILDINGS[type];
  const id = G.freeBldIds.length ? G.freeBldIds.pop() : G.buildings.length;
  let sx = 0, sy = 0;
  for (const c of cells) { sx += c % W; sy += (c / W) | 0; }
  const floors = [];
  for (let f = 0; f < def.verd; f++) floors.push({ use: def.use });
  const pool = NAME_PARTS[def.cat] || NAME_PARTS.overig;
  const b = {
    id, type, cells: cells.slice(),
    x: sx / cells.length, y: sy / cells.length,
    ox, oy, // vrije sub-tegel offset (visueel; de simulatie blijft op het grid)
    naam: def.naam + " " + pool[(RNG() * pool.length) | 0] + " " + (id + 1),
    jaar: G.year,
    floors,
    bew: 0, banen: 0, bezet: 0, werkers: 0,
    happy: 60, reistijd: 0,
    powered: true, watered: true, roadOk: true,
  };
  computeBBox(b);
  G.buildings[id] = b;
  for (const c of cells) G.bld[c] = id + 1;
  return b;
}

// bounding box in tegels (voor chunk-rendering met offset/verhoging)
function computeBBox(b) {
  let x0 = W, y0 = H, x1 = 0, y1 = 0;
  for (const c of b.cells) {
    const x = c % W, y = (c / W) | 0;
    if (x < x0) x0 = x; if (x > x1) x1 = x;
    if (y < y0) y0 = y; if (y > y1) y1 = y;
  }
  b.bx0 = x0; b.by0 = y0; b.bx1 = x1; b.by1 = y1;
}

function removeBuilding(b) {
  for (const c of b.cells) G.bld[c] = 0;
  G.buildings[b.id] = null;
  G.freeBldIds.push(b.id);
  markDirtyCells(b.cells);
}

function eachBuilding(fn) {
  for (const b of G.buildings) if (b) fn(b);
}

// ── Spelmodus & geld ──
function sandbox() { return G.mode === "sandbox"; }
function canPay(cost) { return sandbox() || G.money >= cost; }
function pay(cost) { if (!sandbox()) G.money -= cost; }

function buildCostFactor() {
  let f = 1;
  if (G.techs.beton) f *= 0.9;
  if (G.techs.prefab) f *= 0.85;
  if (G.policies.groen_verplicht) f *= 1.15;
  return f;
}

// ── Chunk-cache voor rendering ──
const CHUNKS_X = Math.ceil(W / CHUNK), CHUNKS_Y = Math.ceil(H / CHUNK);
const chunkCanvas = [];
const chunkDirty = [];
const CHUNK_PX = 12; // px per tegel in chunk-cache (bitmap wordt geschaald; 12 houdt het geheugen van de 384×384-kaart in toom)
for (let i = 0; i < CHUNKS_X * CHUNKS_Y; i++) { chunkCanvas.push(null); chunkDirty.push(true); }

function markDirty(i) {
  const x = i % W, y = (i / W) | 0;
  chunkDirty[((y / CHUNK) | 0) * CHUNKS_X + ((x / CHUNK) | 0)] = true;
  // rand van chunk: buur ook
  if (x % CHUNK === 0 && x > 0) chunkDirty[((y / CHUNK) | 0) * CHUNKS_X + (((x - 1) / CHUNK) | 0)] = true;
  if (y % CHUNK === 0 && y > 0) chunkDirty[(((y - 1) / CHUNK) | 0) * CHUNKS_X + ((x / CHUNK) | 0)] = true;
}
function markDirtyCells(cells) { for (const c of cells) markDirty(c); }
function markAllDirty() { chunkDirty.fill(true); }

// ─────────────────────────────────────────────────────────────
// Vrije wegen: splines die naar het sim-grid worden gerasterd.
// De speler tekent een lijn; Chaikin-smoothing maakt er vloeiende
// bochten van; kruisende paden worden automatisch kruispunten.
// ─────────────────────────────────────────────────────────────

// punten uitdunnen (min. afstand) zodat freehand-invoer rustig wordt
function simplifyPts(pts, minDist = 0.8) {
  if (pts.length < 3) return pts.slice();
  const out = [pts[0]];
  for (let k = 1; k < pts.length - 1; k++) {
    const p = out[out.length - 1], q = pts[k];
    if (Math.hypot(q.x - p.x, q.y - p.y) >= minDist) out.push(q);
  }
  out.push(pts[pts.length - 1]);
  return out;
}

// Chaikin corner-cutting: vloeiende bochten zonder zware wiskunde
function chaikin(pts, iters = 2) {
  let p = pts;
  for (let it = 0; it < iters; it++) {
    if (p.length < 3) break;
    const out = [p[0]];
    for (let k = 0; k < p.length - 1; k++) {
      const a = p[k], b = p[k + 1];
      out.push({ x: a.x * 0.75 + b.x * 0.25, y: a.y * 0.75 + b.y * 0.25 });
      out.push({ x: a.x * 0.25 + b.x * 0.75, y: a.y * 0.25 + b.y * 0.75 });
    }
    out.push(p[p.length - 1]);
    p = out;
  }
  return p;
}

function pathCumLen(path) {
  path.cum = [0];
  for (let k = 1; k < path.pts.length; k++) {
    const a = path.pts[k - 1], b = path.pts[k];
    path.cum.push(path.cum[k - 1] + Math.hypot(b.x - a.x, b.y - a.y));
  }
  path.len = path.cum[path.cum.length - 1];
}

// positie + hoek op afstand d langs het pad (voor auto's)
function pathPoint(path, d) {
  const c = path.cum;
  let lo = 0, hi = c.length - 1;
  while (lo < hi - 1) { const m = (lo + hi) >> 1; if (c[m] <= d) lo = m; else hi = m; }
  const a = path.pts[lo], b = path.pts[hi];
  const seg = c[hi] - c[lo] || 1;
  const t = (d - c[lo]) / seg;
  return { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t, ang: Math.atan2(b.y - a.y, b.x - a.x) };
}

// welke tegels bedekt een pad? (samples elke 0.3 tegel, straal ~ breedte)
function pathTiles(path) {
  const tiles = new Set();
  const rad = Math.max(0, Math.ceil(ROADS[path.type].w / 2 - 0.05));
  for (let d = 0; d <= path.len; d += 0.3) {
    const p = pathPoint(path, d);
    const cx = Math.round(p.x - 0.5), cy = Math.round(p.y - 0.5);
    for (let dy = -rad; dy <= rad; dy++) for (let dx = -rad; dx <= rad; dx++) {
      if (inWorld(cx + dx, cy + dy)) tiles.add(idx(cx + dx, cy + dy));
    }
  }
  return tiles;
}

// pad toevoegen aan raster (na kostencheck door aanroeper)
function applyPathToGrid(path) {
  for (const i of pathTiles(path)) {
    if (G.bld[i] > 0) continue;
    if (G.terrain[i] === TERRAIN.BERG) continue;
    if (G.roadCover[i] === 0 || path.type > G.road[i]) G.road[i] = path.type;
    if (G.roadCover[i] < 255) G.roadCover[i]++;
    markDirty(i);
  }
  computeJunctions();
}

// volledig opnieuw rasteren (na verwijderen van een pad).
// Let op: tegels zonder pad (uit oude saves) blijven staan.
function rebuildRoadRaster() {
  for (let i = 0; i < N; i++) {
    if (G.roadCover[i] > 0) { G.road[i] = 0; G.traffic[i] = 0; markDirty(i); }
    G.roadCover[i] = 0;
  }
  for (const p of G.roadPaths) {
    for (const i of pathTiles(p)) {
      if (G.bld[i] > 0 || G.terrain[i] === TERRAIN.BERG) continue;
      if (G.roadCover[i] === 0 || p.type > G.road[i]) G.road[i] = p.type;
      if (G.roadCover[i] < 255) G.roadCover[i]++;
      markDirty(i);
    }
  }
  computeJunctions();
}

// kruispunttegels = door ≥2 paden bedekt; per cluster één representant
function computeJunctions() {
  G.junctions = [];
  for (let i = 0; i < N; i++) {
    if (G.roadCover[i] >= 2) {
      const x = i % W;
      const leftJ = x > 0 && G.roadCover[i - 1] >= 2;
      const upJ = i >= W && G.roadCover[i - W] >= 2;
      if (!leftJ && !upJ) G.junctions.push(i);
    }
  }
}

// dichtstbijzijnde pad bij een wereldpunt (voor slopen/snappen)
function pathAt(wx, wy, extra = 0.4) {
  let best = null, bestD = 1e9;
  for (const p of G.roadPaths) {
    const maxR = ROADS[p.type].w / 2 + extra;
    for (let d = 0; d <= p.len; d += 0.5) {
      const q = pathPoint(p, d);
      const dd = Math.hypot(q.x - wx, q.y - wy);
      if (dd < maxR && dd < bestD) { bestD = dd; best = p; }
    }
  }
  return best;
}

// snap een eindpunt aan een bestaand pad of wegtegel (slim verbinden)
function snapEndpoint(pt, maxDist = 1.6) {
  let best = null, bestD = maxDist;
  for (const p of G.roadPaths) {
    for (let d = 0; d <= p.len; d += 0.4) {
      const q = pathPoint(p, d);
      const dd = Math.hypot(q.x - pt.x, q.y - pt.y);
      if (dd < bestD) { bestD = dd; best = { x: q.x, y: q.y }; }
    }
  }
  if (best) return best;
  // anders: dichtstbijzijnde legacy-wegtegel
  const tx = Math.round(pt.x - 0.5), ty = Math.round(pt.y - 0.5);
  for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
    if (inWorld(tx + dx, ty + dy) && G.road[idx(tx + dx, ty + dy)] > 0)
      return { x: tx + dx + 0.5, y: ty + dy + 0.5 };
  }
  return pt;
}

// ── Nieuw spel ──
function newGame(seed, mode = "classic") {
  G.mode = mode;
  G.terrain.fill(0); G.height.fill(0); G.fert.fill(0); G.road.fill(0); G.bld.fill(0);
  G.traffic.fill(0); G.pollution.fill(0); G.noise.fill(0); G.landValue.fill(0);
  G.powerOk.fill(0); G.waterOk.fill(0);
  G.svcEdu.fill(0); G.svcHealth.fill(0); G.svcSafety.fill(0); G.svcTransit.fill(0); G.svcGreen.fill(0);
  G.happyMap.fill(0);
  G.buildings = []; G.freeBldIds = []; G.transitLines = []; G.nextLineId = 1;
  G.roadPaths = []; G.nextPathId = 1; G.roadCover.fill(0); G.junctions = [];
  G.settings = { grid: true, snap: true, gridSize: 1 };
  G.money = 150000; G.day = 1; G.month = 1; G.year = 1925; G.speed = 1;
  G.fase = 1; G.rp = 0; G.techs = {}; G.policies = {};
  G.taxes = { wonen: 9, bedrijf: 9, verkoop: 6 };
  G.pop = 0; G.cohorts = { kinderen: 0, studenten: 0, werkenden: 0, ouderen: 0 };
  G.jobs = 0; G.jobsFilled = 0; G.happy = 60;
  G.demand = { wonen: 15, commercieel: 0, industrie: 0 };
  G.lastBudget = { in: {}, uit: {}, saldo: 0 };
  G.weerFactor = 0.8; G.news = []; G.gameOver = false;
  if (mode === "sandbox") {
    // blanco witte kaart: alles bouwbaar, alles ontgrendeld
    G.seed = seed;
    RNG = mulberry(seed);
    G.terrain.fill(TERRAIN.GRAS);
    G.height.fill(0.5);
    G.fert.fill(0.8);
    G.fase = PHASES.length - 1;
    for (const t of TECHS) G.techs[t.id] = true;
  } else {
    genWorld(seed);
  }
  invalidateWaterCache();
  markAllDirty();
}
