// ─────────────────────────────────────────────────────────────
// MetroPlan — invoer 2.0, gameloop, opslaan/laden
// Vrij tekenen: wegen als vloeiende splines, gebouwen met optionele
// sub-tegel plaatsing, grid en snappen volledig instelbaar.
// ─────────────────────────────────────────────────────────────
"use strict";

const Input = {
  dragging: false, panning: false,
  lastX: 0, lastY: 0, panT: 0, panDX: 0, panDY: 0,
  paintCells: new Set(),   // cellen tijdens slepen (gebouw/terrein)
  roadDraft: null,         // {type, pts:[{x,y}]} tijdens vrij tekenen
  lineDraft: null,         // OV: {type, stops:[]}
  altHeld: false,          // Alt = tijdelijk snappen omkeren
  freeAnchor: null,        // sub-tegel offset bij vrije plaatsing
  cancelDrafts() { this.paintCells.clear(); this.roadDraft = null; this.lineDraft = null; this.freeAnchor = null; },
  buildToolActive() {
    const k = UI.tool.kind;
    return k === "building" || k === "road" || k === "terrain" || k === "roundabout";
  },
};

// effectief snappen = instelling XOR Alt (tijdelijk omkeren)
function snapActive() { return G.settings.snap !== Input.altHeld; }

// ── Muis & toetsen ──────────────────────────────────────────
canvas.addEventListener("contextmenu", e => e.preventDefault());

canvas.addEventListener("mousedown", e => {
  const rect = canvas.getBoundingClientRect();
  const px = e.clientX - rect.left, py = e.clientY - rect.top;
  if (e.button === 2 || e.button === 1) {
    Input.panning = true; Input.lastX = e.clientX; Input.lastY = e.clientY;
    Input.panDX = Input.panDY = 0;
    cam.vx = cam.vy = 0;
    return;
  }
  if (e.button !== 0) return;
  const w = screenToWorld(px, py);
  const i = screenToTile(px, py);
  const t = UI.tool;
  if (t.kind === "select") {
    if (i >= 0 && G.bld[i] > 0) UI.selectBuilding(G.buildings[G.bld[i] - 1]);
    else { UI.selected = null; UI.refreshRight(); }
  } else if (t.kind === "transit") {
    if (i >= 0) addTransitStop(i);
  } else if (t.kind === "road") {
    // vrij tekenen: startpunt (met slim snappen aan bestaand netwerk)
    const start = snapActive() ? snapEndpoint({ x: w.x, y: w.y }) : { x: w.x, y: w.y };
    Input.roadDraft = { type: t.road, pts: [start] };
    Input.dragging = true;
  } else if (t.kind === "roundabout") {
    placeRoundabout(w.x, w.y, t.road || 2);
  } else if (t.kind === "bulldoze") {
    Input.dragging = true;
    bulldozeAt(w, i);
  } else if (i >= 0) {
    Input.dragging = true;
    // vrije plaatsing: onthoud sub-tegel offset van het eerste punt
    Input.freeAnchor = snapActive() ? { ox: 0, oy: 0 }
      : { ox: Math.max(-0.45, Math.min(0.45, w.x - Math.floor(w.x) - 0.5)),
          oy: Math.max(-0.45, Math.min(0.45, w.y - Math.floor(w.y) - 0.5)) };
    paintTile(i);
  }
});

canvas.addEventListener("dblclick", () => { finishTransitLine(); });

canvas.addEventListener("mousemove", e => {
  const rect = canvas.getBoundingClientRect();
  const px = e.clientX - rect.left, py = e.clientY - rect.top;
  hoverTile = screenToTile(px, py);
  hoverWorld = screenToWorld(px, py);
  if (Input.panning) {
    const dx = (e.clientX - Input.lastX) / cam.zoom, dy = (e.clientY - Input.lastY) / cam.zoom;
    cam.tx -= dx; cam.ty -= dy;
    cam.x -= dx; cam.y -= dy;
    Input.panDX = dx; Input.panDY = dy; Input.panT = performance.now();
    Input.lastX = e.clientX; Input.lastY = e.clientY;
  } else if (Input.dragging) {
    if (Input.roadDraft) {
      const last = Input.roadDraft.pts[Input.roadDraft.pts.length - 1];
      if (Math.hypot(hoverWorld.x - last.x, hoverWorld.y - last.y) > 0.35)
        Input.roadDraft.pts.push({ x: hoverWorld.x, y: hoverWorld.y });
    } else if (UI.tool.kind === "bulldoze") {
      bulldozeAt(hoverWorld, hoverTile);
    } else if (hoverTile >= 0) {
      paintTile(hoverTile);
    }
  }
  UI.updateTooltip(px, py);
});

window.addEventListener("mouseup", e => {
  if (e.button === 2 || e.button === 1) {
    Input.panning = false;
    // inertie: laatste beweging wordt uitrol-snelheid
    if (performance.now() - Input.panT < 60) {
      cam.vx = -Input.panDX * 18; cam.vy = -Input.panDY * 18;
    }
  }
  if (e.button === 0 && Input.dragging) {
    Input.dragging = false;
    if (Input.roadDraft) finishRoad();
    else commitPaint();
  }
});

canvas.addEventListener("wheel", e => {
  e.preventDefault();
  // vloeiend zoomen, verankerd op de cursor
  const rect = canvas.getBoundingClientRect();
  const before = screenToWorld(e.clientX - rect.left, e.clientY - rect.top);
  const f = e.deltaY < 0 ? 1.18 : 1 / 1.18;
  cam.tzoom = Math.max(1.1, Math.min(44, cam.tzoom * f));
  // richt het doel zo dat het punt onder de cursor blijft
  const zAfter = cam.tzoom;
  cam.tx = before.x - (e.clientX - rect.left - rect.width / 2) / zAfter;
  cam.ty = before.y - (e.clientY - rect.top - rect.height / 2) / zAfter;
}, { passive: false });

window.addEventListener("keydown", e => {
  if (e.key === "Alt") { Input.altHeld = true; e.preventDefault(); return; }
  if (e.target.tagName === "INPUT" || e.target.tagName === "SELECT") return;
  switch (e.key) {
    case " ": setSpeed(G.speed === 0 ? 1 : 0); e.preventDefault(); break;
    case "1": setSpeed(1); break;
    case "2": setSpeed(2); break;
    case "3": setSpeed(3); break;
    case "g": case "G": G.settings.grid = !G.settings.grid; UI.refreshTools(); break;
    case "s": case "S": G.settings.snap = !G.settings.snap; UI.refreshTools(); break;
    case "Enter": finishTransitLine(); break;
    case "Escape": Input.cancelDrafts(); UI.setTool({ kind: "select" }); UI.markActiveTool(document.querySelector('[data-toolkey="select"]')); break;
    case "ArrowUp": cam.ty -= 24 / cam.zoom; break;
    case "ArrowDown": cam.ty += 24 / cam.zoom; break;
    case "ArrowLeft": cam.tx -= 24 / cam.zoom; break;
    case "ArrowRight": cam.tx += 24 / cam.zoom; break;
  }
});
window.addEventListener("keyup", e => { if (e.key === "Alt") Input.altHeld = false; });

// ── Wegen: vrij getekend → vloeiende spline → raster ────────
function finishRoad() {
  const d = Input.roadDraft;
  Input.roadDraft = null;
  if (!d || d.pts.length < 2) return;
  let pts = simplifyPts(d.pts, 0.8);
  if (snapActive()) {
    // eindpunt slim aan het netwerk knopen
    pts[pts.length - 1] = snapEndpoint(pts[pts.length - 1]);
    // korte rechte stukken netjes op het grid uitlijnen
    if (G.settings.gridSize >= 1 && pts.length === 2) {
      const a = pts[0], b = pts[1];
      if (Math.abs(a.x - b.x) < 1.2) b.x = a.x;       // verticaal recht
      else if (Math.abs(a.y - b.y) < 1.2) b.y = a.y;  // horizontaal recht
    }
  }
  pts = chaikin(pts, 2);
  const path = { id: G.nextPathId++, type: d.type, pts };
  pathCumLen(path);
  if (path.len < 1) return;

  // kosten: per nieuwe wegtegel, bruggen ×3, bergen blokkeren
  const tiles = pathTiles(path);
  let cost = 0, blocked = 0;
  const rd = ROADS[path.type];
  for (const i of tiles) {
    if (G.bld[i] > 0) continue;
    if (G.terrain[i] === TERRAIN.BERG) { blocked++; continue; }
    if (G.road[i] > 0 && G.roadCover[i] > 0) continue; // al weg (kruising is gratis)
    const ter = G.terrain[i];
    cost += rd.kosten * (isWater(ter) ? 3 : ter === TERRAIN.HEUVEL ? 1.5 : 1);
  }
  if (blocked > tiles.size * 0.4) { UI.toast("Bergen blokkeren dit tracé.", "warn"); return; }
  if (!canPay(cost)) { UI.toast(`Onvoldoende geld: ${fmtGeld(cost)} nodig.`, "bad"); return; }
  pay(cost);
  G.roadPaths.push(path);
  applyPathToGrid(path);
  UI.refreshTop();
}

function placeRoundabout(wx, wy, type) {
  const R = 2.2, SEG = 20;
  const pts = [];
  for (let k = 0; k <= SEG; k++) {
    const a = (k / SEG) * Math.PI * 2;
    pts.push({ x: wx + Math.cos(a) * R, y: wy + Math.sin(a) * R });
  }
  const path = { id: G.nextPathId++, type, pts };
  pathCumLen(path);
  const tiles = pathTiles(path);
  const rd = ROADS[type];
  let cost = 0;
  for (const i of tiles) {
    if (G.bld[i] > 0 || G.terrain[i] === TERRAIN.BERG) { UI.toast("Rotonde past hier niet.", "warn"); return; }
    if (G.road[i] > 0 && G.roadCover[i] > 0) continue;
    cost += rd.kosten * (isWater(G.terrain[i]) ? 3 : 1);
  }
  if (!canPay(cost)) { UI.toast(`Onvoldoende geld: ${fmtGeld(cost)} nodig.`, "bad"); return; }
  pay(cost);
  G.roadPaths.push(path);
  applyPathToGrid(path);
  UI.refreshTop();
}

// ── Slopen ──────────────────────────────────────────────────
function bulldozeAt(w, i) {
  if (i >= 0 && G.bld[i] > 0) {
    const b = G.buildings[G.bld[i] - 1];
    if (b) { removeBuilding(b); if (UI.selected === b) { UI.selected = null; UI.refreshRight(); } }
    return;
  }
  const p = pathAt(w.x, w.y);
  if (p) {
    G.roadPaths = G.roadPaths.filter(x => x !== p);
    rebuildRoadRaster();
    UI.toast("Wegsegment verwijderd.", "");
    return;
  }
  if (i >= 0 && G.road[i] > 0) { G.road[i] = 0; G.traffic[i] = 0; markDirty(i); }
}

// ── Gebouwen / terrein schilderen ───────────────────────────
function paintTile(i) {
  const t = UI.tool;
  if (t.kind !== "building" && t.kind !== "terrain") return;
  // gridgrootte: penseel snapt aan blokken wanneer snappen aan staat
  const gs = snapActive() ? G.settings.gridSize : 1;
  const x0 = Math.floor((i % W) / gs) * gs, y0 = Math.floor(((i / W) | 0) / gs) * gs;
  for (let dy = 0; dy < gs; dy++) for (let dx = 0; dx < gs; dx++) {
    if (inWorld(x0 + dx, y0 + dy)) Input.paintCells.add(idx(x0 + dx, y0 + dy));
  }
}

function commitPaint() {
  const t = UI.tool;
  const cells = [...Input.paintCells];
  const anchor = Input.freeAnchor || { ox: 0, oy: 0 };
  Input.paintCells.clear();
  Input.freeAnchor = null;
  if (!cells.length) return;

  if (t.kind === "terrain") {
    const tool = TERRAIN_TOOLS.find(x => x.id === t.terrain);
    let cost = 0;
    for (const i of cells) {
      if (G.bld[i] > 0 || G.road[i] > 0) continue;
      if (!canPay(cost + tool.kosten)) break;
      cost += tool.kosten;
      switch (t.terrain) {
        case "egaliseren":
          if (!isWater(G.terrain[i])) { G.terrain[i] = TERRAIN.GRAS; G.height[i] = 0.5; }
          break;
        case "water": G.terrain[i] = TERRAIN.MEER; G.height[i] = 0.25; invalidateWaterCache(); break;
        case "bos": if (!isWater(G.terrain[i])) G.terrain[i] = TERRAIN.BOS; break;
        case "landbouw": if (!isWater(G.terrain[i])) { G.terrain[i] = TERRAIN.LANDBOUW; G.fert[i] = Math.max(G.fert[i], 0.9); } break;
      }
      markDirty(i);
    }
    pay(cost);
    UI.refreshTop();
  } else if (t.kind === "building") {
    placeBuilding(t.type, cells, anchor.ox, anchor.oy);
  }
}

function placeBuilding(type, cells, ox = 0, oy = 0) {
  const def = BUILDINGS[type];
  const ok = cells.filter(i => tileBuildable(i) && !(def.cat === "voedsel" && type === "akker" && G.fert[i] < 0.15));
  if (!ok.length) { UI.toast("Hier kun je niet bouwen (water, berg, weg of bezet).", "warn"); return; }
  const set = new Set(ok);
  const comp = [ok[0]];
  const seen = new Set(comp);
  for (let k = 0; k < comp.length; k++) {
    const c = comp[k], cx = c % W;
    for (const d of NB4) {
      const n = c + d;
      if (d === 1 && cx === W - 1) continue;
      if (d === -1 && cx === 0) continue;
      if (set.has(n) && !seen.has(n)) { seen.add(n); comp.push(n); }
    }
  }
  if (comp.length !== ok.length) { UI.toast("De vorm moet één aaneengesloten geheel zijn.", "warn"); return; }
  if (def.waterNodig && !comp.some(i => nearWater(i, 3))) {
    UI.toast(`${def.naam} moet aan het water gebouwd worden.`, "warn"); return;
  }
  const cost = def.kosten * comp.length * def.verd * buildCostFactor();
  if (!canPay(cost)) { UI.toast(`Onvoldoende geld: ${fmtGeld(cost)} nodig.`, "bad"); return; }
  if (!comp.some(i => adjacentRoad(i) >= 0)) {
    UI.toast("Let op: dit gebouw heeft (nog) geen weg. Het werkt pas als er een weg naast ligt.", "warn");
  }
  pay(cost);
  const b = makeBuilding(type, comp, ox, oy);
  markDirtyCells(comp);
  recomputeCapacities();
  UI.refreshTop();
  UI.selectBuilding(b);
}

// ── OV-lijnen ───────────────────────────────────────────────
function addTransitStop(i) {
  const t = UI.tool;
  if (G.road[i] === 0) { UI.toast("Haltes moeten op een weg liggen.", "warn"); return; }
  if (!Input.lineDraft) Input.lineDraft = { type: t.type, stops: [] };
  const tt = TRANSIT_TYPES[t.type];
  if (!canPay(tt.kostenHalte)) { UI.toast("Onvoldoende geld voor deze halte.", "bad"); return; }
  pay(tt.kostenHalte);
  Input.lineDraft.stops.push(i);
  UI.refreshTop();
}

function finishTransitLine() {
  const d = Input.lineDraft;
  if (!d) return;
  Input.lineDraft = null;
  if (d.stops.length < 2) { UI.toast("Een lijn heeft minstens 2 haltes nodig.", "warn"); return; }
  const hasDepot = G.buildings.some(b => b && BUILDINGS[b.type].ovDepot === d.type);
  const tt = TRANSIT_TYPES[d.type];
  const line = {
    id: G.nextLineId++, type: d.type,
    naam: `${tt.naam} ${G.nextLineId - 1}`,
    stops: d.stops, freq: 2, ridership: 0, actief: hasDepot,
  };
  G.transitLines.push(line);
  if (!hasDepot) UI.toast(`Lijn aangemaakt maar gepauzeerd: bouw eerst een ${d.type}-depot.`, "warn");
  else UI.toast(`${line.naam} rijdt! Beheer frequentie via het OV-paneel.`, "good");
  UI.refreshRight();
}

// ── Snelheid ────────────────────────────────────────────────
function setSpeed(s) {
  G.speed = s;
  for (let k = 0; k <= 3; k++) document.getElementById("spd" + k).classList.toggle("active", k === s);
}
for (let k = 0; k <= 3; k++) document.getElementById("spd" + k).onclick = () => setSpeed(k);

// ── Opslaan / laden (meerdere slots + save-scherm) ──────────
const SAVE_PREFIX = "metroplan_v3_";
const SAVE_SLOTS = ["1", "2", "3", "auto"];
const saveKey = slot => SAVE_PREFIX + "slot_" + slot;
function saveMeta(slot) {
  try { return JSON.parse(localStorage.getItem(saveKey(slot) + "_meta")); } catch { return null; }
}
function deleteSave(slot) {
  localStorage.removeItem(saveKey(slot));
  localStorage.removeItem(saveKey(slot) + "_meta");
}
// tegel-lagen als base64-bytes: houdt saves van de 384×384-kaart ruim
// binnen de localStorage-limiet (JSON-arrays zouden die overschrijden)
function packU8(arr) {
  let s = "";
  for (let i = 0; i < arr.length; i += 0x8000)
    s += String.fromCharCode.apply(null, arr.subarray(i, Math.min(arr.length, i + 0x8000)));
  return btoa(s);
}
function unpackU8(b64, out) {
  const s = atob(b64);
  const n = Math.min(s.length, out.length);
  for (let i = 0; i < n; i++) out[i] = s.charCodeAt(i);
  return s.length;
}
function saveGame(slot = "auto", silent = false) {
  const buildings = [];
  eachBuilding(b => buildings.push({
    id: b.id, type: b.type, cells: b.cells, naam: b.naam, jaar: b.jaar,
    floors: b.floors, bezet: b.bezet, ox: b.ox || 0, oy: b.oy || 0,
  }));
  const q8 = f => Uint8Array.from(f, v => Math.max(0, Math.min(255, Math.round(v * 255))));
  const data = {
    v: 3, seed: G.seed, mode: G.mode, worldW: W, worldH: H,
    terrain: packU8(G.terrain), height: packU8(q8(G.height)), fert: packU8(q8(G.fert)),
    road: packU8(G.road),
    roadPaths: G.roadPaths.map(p => ({
      id: p.id, type: p.type,
      pts: p.pts.map(q => ({ x: Math.round(q.x * 100) / 100, y: Math.round(q.y * 100) / 100 })),
    })),
    nextPathId: G.nextPathId,
    buildings,
    transitLines: G.transitLines, nextLineId: G.nextLineId,
    money: G.money, day: G.day, month: G.month, year: G.year,
    fase: G.fase, rp: G.rp, techs: G.techs, policies: G.policies, taxes: G.taxes,
    pop: G.pop, happy: G.happy, settings: G.settings,
  };
  const meta = { ts: Date.now(), mode: G.mode, pop: G.pop, year: G.year, money: Math.round(G.money), fase: G.fase };
  try {
    localStorage.setItem(saveKey(slot), JSON.stringify(data));
    localStorage.setItem(saveKey(slot) + "_meta", JSON.stringify(meta));
    if (!silent) UI.toast("💾 Spel opgeslagen.", "good");
    return true;
  } catch (e) {
    UI.toast("Opslaan mislukt: " + e.message, "bad");
    return false;
  }
}

function loadGame(slot = "auto", silent = false) {
  const raw = localStorage.getItem(saveKey(slot));
  if (!raw) { if (!silent) UI.toast("Geen opgeslagen spel gevonden.", "warn"); return false; }
  let d;
  try { d = JSON.parse(raw); } catch { UI.toast("Save-bestand beschadigd.", "bad"); return false; }
  if (d.v !== 3 || (d.worldW || 192) !== W || (d.worldH || 192) !== H) {
    UI.toast("Deze save komt van een oudere versie of andere kaartgrootte en kan niet geladen worden.", "bad");
    return false;
  }
  newGame(d.seed || 1, d.mode || "classic");
  unpackU8(d.terrain, G.terrain);
  unpackU8(d.road, G.road);
  const tmp = new Uint8Array(N);
  unpackU8(d.height, tmp); for (let i = 0; i < N; i++) G.height[i] = tmp[i] / 255;
  unpackU8(d.fert, tmp); for (let i = 0; i < N; i++) G.fert[i] = tmp[i] / 255;
  G.bld.fill(0);
  G.buildings = []; G.freeBldIds = [];
  for (const sb of d.buildings) {
    while (G.buildings.length < sb.id) { G.freeBldIds.push(G.buildings.length); G.buildings.push(null); }
    const b = {
      id: sb.id, type: sb.type, cells: sb.cells, naam: sb.naam, jaar: sb.jaar,
      floors: sb.floors, bezet: sb.bezet || 0, ox: sb.ox || 0, oy: sb.oy || 0,
      x: 0, y: 0, bew: 0, banen: 0, werkers: 0, happy: 60, reistijd: 0,
      powered: true, watered: true, roadOk: true,
    };
    let sx = 0, sy = 0;
    for (const c of b.cells) { sx += c % W; sy += (c / W) | 0; G.bld[c] = b.id + 1; }
    b.x = sx / b.cells.length; b.y = sy / b.cells.length;
    computeBBox(b);
    G.buildings.push(b);
  }
  // wegen: v2 heeft splines; v1-saves houden alleen hun rastertegels
  G.roadPaths = (d.roadPaths || []).map(p => { const q = { ...p }; pathCumLen(q); return q; });
  G.nextPathId = d.nextPathId || 1;
  if (G.roadPaths.length) rebuildRoadRaster();
  G.transitLines = d.transitLines || []; G.nextLineId = d.nextLineId || 1;
  G.money = d.money; G.day = d.day; G.month = d.month; G.year = d.year;
  G.fase = d.fase; G.rp = d.rp; G.techs = d.techs || {}; G.policies = d.policies || {};
  G.taxes = d.taxes || G.taxes; G.pop = d.pop; G.happy = d.happy || 60;
  if (d.settings) G.settings = { grid: true, snap: true, gridSize: 1, ...d.settings };
  invalidateWaterCache();
  markAllDirty();
  computeJunctions();
  recomputeCapacities();
  UI.refreshTools(); UI.refreshTop(); UI.refreshRight();
  UI.toast("📂 Spel geladen.", "good");
  return true;
}

function startNewGame(mode) {
  newGame(((Math.random() * 1e9) | 0) || 1, mode);
  UI.selected = null;
  Cars.pool.length = 0;
  UI.refreshTools(); UI.refreshTop(); UI.refreshRight();
  if (mode === "sandbox")
    UI.toast("⬜ Sandbox! Een leeg wit canvas: onbeperkt geld, alles ontgrendeld. Bouw je droomstad.", "good");
  else
    UI.toast("🗺 Nieuwe kaart! Begin met een weg, huizen, een akker en een waterpomp.", "good");
}

document.getElementById("btn-save").onclick = () => UI.showSaveScreen();
document.getElementById("btn-new").onclick = () => UI.showNewGameScreen();

// ── Gameloop ────────────────────────────────────────────────
const DAY_RATE = [0, 0.8, 2.4, 6];
let lastT = performance.now(), dayAcc = 0, uiAcc = 0, autosaveAcc = 0;

function loop(now) {
  const dt = Math.min(0.1, (now - lastT) / 1000);
  lastT = now;
  dayAcc += dt * DAY_RATE[G.speed];
  let steps = 0;
  while (dayAcc >= 1 && steps < 4) { dayAcc -= 1; simDay(); steps++; }
  uiAcc += dt;
  if (uiAcc > 0.35) {
    uiAcc = 0;
    UI.refreshTop(); UI.refreshChips();
    if (UI.tab === "inspect" && UI.selected && !Input.dragging) UI.refreshRight();
  }
  autosaveAcc += dt;
  if (autosaveAcc > 120) { autosaveAcc = 0; saveGame("auto", true); }
  draw();
  drawMinimap();
  requestAnimationFrame(loop);
}

// ── Start ───────────────────────────────────────────────────
resizeCanvas();
if (!loadGame("auto", true)) {
  newGame(((Math.random() * 1e9) | 0) || 1);
  UI.refreshTools(); UI.refreshTop(); UI.refreshRight();
  UI.toast("Welkom, stadsplanner! Teken vrij een weg (sleep een vloeiende lijn), zet er huizen naast, een akker, een waterpomp aan de rivier en een basisschool.", "good");
}
UI.buildTools();
UI.refreshTop();
UI.refreshRight();
requestAnimationFrame(loop);
