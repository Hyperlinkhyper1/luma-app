// ─────────────────────────────────────────────────────────────
// MetroPlan — invoer, gameloop, opslaan/laden
// ─────────────────────────────────────────────────────────────
"use strict";

const Input = {
  dragging: false, panning: false,
  lastX: 0, lastY: 0,
  paintCells: new Set(),   // cellen tijdens slepen (gebouw/weg/terrein)
  lineDraft: null,         // {type, stops:[]}
  cancelDrafts() { this.paintCells.clear(); this.lineDraft = null; },
};

// ── Muis & toetsen ──────────────────────────────────────────
canvas.addEventListener("contextmenu", e => e.preventDefault());

canvas.addEventListener("mousedown", e => {
  const rect = canvas.getBoundingClientRect();
  const px = e.clientX - rect.left, py = e.clientY - rect.top;
  if (e.button === 2 || e.button === 1) {
    Input.panning = true; Input.lastX = e.clientX; Input.lastY = e.clientY;
    return;
  }
  if (e.button !== 0) return;
  const i = screenToTile(px, py);
  if (i < 0) return;
  const t = UI.tool;
  if (t.kind === "select") {
    if (G.bld[i] > 0) UI.selectBuilding(G.buildings[G.bld[i] - 1]);
    else { UI.selected = null; UI.refreshRight(); }
  } else if (t.kind === "transit") {
    addTransitStop(i);
  } else {
    Input.dragging = true;
    paintTile(i);
  }
});

canvas.addEventListener("dblclick", () => { finishTransitLine(); });

canvas.addEventListener("mousemove", e => {
  const rect = canvas.getBoundingClientRect();
  const px = e.clientX - rect.left, py = e.clientY - rect.top;
  hoverTile = screenToTile(px, py);
  if (Input.panning) {
    cam.x -= (e.clientX - Input.lastX) / cam.zoom;
    cam.y -= (e.clientY - Input.lastY) / cam.zoom;
    Input.lastX = e.clientX; Input.lastY = e.clientY;
    clampCam();
  } else if (Input.dragging && hoverTile >= 0) {
    paintTile(hoverTile);
  }
  UI.updateTooltip(px, py);
});

window.addEventListener("mouseup", e => {
  if (e.button === 2 || e.button === 1) Input.panning = false;
  if (e.button === 0 && Input.dragging) {
    Input.dragging = false;
    commitPaint();
  }
});

canvas.addEventListener("wheel", e => {
  e.preventDefault();
  const f = e.deltaY < 0 ? 1.15 : 1 / 1.15;
  cam.zoom = Math.max(2, Math.min(40, cam.zoom * f));
  clampCam();
}, { passive: false });

window.addEventListener("keydown", e => {
  if (e.target.tagName === "INPUT" || e.target.tagName === "SELECT") return;
  switch (e.key) {
    case " ": setSpeed(G.speed === 0 ? 1 : 0); e.preventDefault(); break;
    case "1": setSpeed(1); break;
    case "2": setSpeed(2); break;
    case "3": setSpeed(3); break;
    case "Enter": finishTransitLine(); break;
    case "Escape": UI.setTool({ kind: "select" }); UI.markActiveTool(document.querySelector('[data-toolkey="select"]')); break;
    case "ArrowUp": cam.y -= 8 / cam.zoom * 4; clampCam(); break;
    case "ArrowDown": cam.y += 8 / cam.zoom * 4; clampCam(); break;
    case "ArrowLeft": cam.x -= 8 / cam.zoom * 4; clampCam(); break;
    case "ArrowRight": cam.x += 8 / cam.zoom * 4; clampCam(); break;
  }
});

function clampCam() {
  cam.x = Math.max(0, Math.min(W, cam.x));
  cam.y = Math.max(0, Math.min(H, cam.y));
}

// ── Tekenen / plaatsen ──────────────────────────────────────
function paintTile(i) {
  const t = UI.tool;
  if (t.kind === "bulldoze") { bulldoze(i); return; }
  if (t.kind === "road" || t.kind === "building" || t.kind === "terrain") {
    Input.paintCells.add(i);
  }
}

function commitPaint() {
  const t = UI.tool;
  const cells = [...Input.paintCells];
  Input.paintCells.clear();
  if (!cells.length) return;

  if (t.kind === "road") {
    const rd = ROADS[t.road];
    let placed = 0, cost = 0;
    for (const i of cells) {
      if (G.bld[i] > 0) continue;
      const ter = G.terrain[i];
      const bridge = isWater(ter);
      const c = rd.kosten * (bridge ? 3 : ter === TERRAIN.HEUVEL ? 1.5 : ter === TERRAIN.BERG ? 4 : 1);
      if (G.money < cost + c) { UI.toast("Onvoldoende geld voor de hele weg.", "warn"); break; }
      if (ter === TERRAIN.BERG) continue; // tunnel te duur zonder tech — sla over
      cost += c;
      G.road[i] = t.road;
      markDirty(i);
      placed++;
    }
    G.money -= cost;
    if (placed) UI.refreshTop();
  }

  else if (t.kind === "terrain") {
    const tool = TERRAIN_TOOLS.find(x => x.id === t.terrain);
    let cost = 0;
    for (const i of cells) {
      if (G.bld[i] > 0 || G.road[i] > 0) continue;
      if (G.money < cost + tool.kosten) break;
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
    G.money -= cost;
    UI.refreshTop();
  }

  else if (t.kind === "building") {
    placeBuilding(t.type, cells);
  }
}

function placeBuilding(type, cells) {
  const def = BUILDINGS[type];
  // filter op bouwbaar
  const ok = cells.filter(i => tileBuildable(i) && !(def.cat === "voedsel" && type === "akker" && G.fert[i] < 0.15));
  if (!ok.length) { UI.toast("Hier kun je niet bouwen (water, berg, weg of bezet).", "warn"); return; }
  // samenhang controleren (flood fill binnen selectie)
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
  if (G.money < cost) { UI.toast(`Onvoldoende geld: ${fmtGeld(cost)} nodig.`, "bad"); return; }
  if (!comp.some(i => adjacentRoad(i) >= 0)) {
    UI.toast("Let op: dit gebouw heeft (nog) geen weg. Het werkt pas als er een weg naast ligt.", "warn");
  }
  G.money -= cost;
  const b = makeBuilding(type, comp);
  markDirtyCells(comp);
  recomputeCapacities();
  UI.refreshTop();
  UI.selectBuilding(b);
}

function bulldoze(i) {
  if (G.bld[i] > 0) {
    const b = G.buildings[G.bld[i] - 1];
    if (b) { removeBuilding(b); if (UI.selected === b) { UI.selected = null; UI.refreshRight(); } }
  } else if (G.road[i] > 0) {
    G.road[i] = 0; G.traffic[i] = 0; markDirty(i);
  }
}

// ── OV-lijnen tekenen ───────────────────────────────────────
function addTransitStop(i) {
  const t = UI.tool;
  if (G.road[i] === 0) { UI.toast("Haltes moeten op een weg liggen.", "warn"); return; }
  if (!Input.lineDraft) Input.lineDraft = { type: t.type, stops: [] };
  const tt = TRANSIT_TYPES[t.type];
  if (G.money < tt.kostenHalte) { UI.toast("Onvoldoende geld voor deze halte.", "bad"); return; }
  G.money -= tt.kostenHalte;
  Input.lineDraft.stops.push(i);
  UI.refreshTop();
}

function finishTransitLine() {
  const d = Input.lineDraft;
  if (!d) return;
  Input.lineDraft = null;
  if (d.stops.length < 2) { UI.toast("Een lijn heeft minstens 2 haltes nodig.", "warn"); return; }
  // depot-check
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

// ── Snelheid & knoppen ──────────────────────────────────────
function setSpeed(s) {
  G.speed = s;
  for (let k = 0; k <= 3; k++) document.getElementById("spd" + k).classList.toggle("active", k === s);
}
for (let k = 0; k <= 3; k++) document.getElementById("spd" + k).onclick = () => setSpeed(k);

// ── Opslaan / laden ─────────────────────────────────────────
const SAVE_KEY = "metroplan_save_v1";
function saveGame(silent) {
  const buildings = [];
  eachBuilding(b => buildings.push({
    id: b.id, type: b.type, cells: b.cells, naam: b.naam, jaar: b.jaar,
    floors: b.floors, bezet: b.bezet,
  }));
  const data = {
    v: 1, seed: G.seed,
    terrain: Array.from(G.terrain), height: Array.from(G.height), fert: Array.from(G.fert),
    road: Array.from(G.road),
    buildings,
    transitLines: G.transitLines, nextLineId: G.nextLineId,
    money: G.money, day: G.day, month: G.month, year: G.year,
    fase: G.fase, rp: G.rp, techs: G.techs, policies: G.policies, taxes: G.taxes,
    pop: G.pop, happy: G.happy,
  };
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify(data));
    if (!silent) UI.toast("💾 Spel opgeslagen.", "good");
  } catch (e) {
    UI.toast("Opslaan mislukt: " + e.message, "bad");
  }
}

function loadGame() {
  const raw = localStorage.getItem(SAVE_KEY);
  if (!raw) { UI.toast("Geen opgeslagen spel gevonden.", "warn"); return false; }
  let d;
  try { d = JSON.parse(raw); } catch { UI.toast("Save-bestand beschadigd.", "bad"); return false; }
  newGame(d.seed || 1);
  G.terrain.set(d.terrain); G.height.set(d.height); G.fert.set(d.fert); G.road.set(d.road);
  G.bld.fill(0);
  G.buildings = []; G.freeBldIds = [];
  for (const sb of d.buildings) {
    while (G.buildings.length < sb.id) { G.freeBldIds.push(G.buildings.length); G.buildings.push(null); }
    const b = {
      id: sb.id, type: sb.type, cells: sb.cells, naam: sb.naam, jaar: sb.jaar,
      floors: sb.floors, bezet: sb.bezet || 0,
      x: 0, y: 0, bew: 0, banen: 0, werkers: 0, happy: 60, reistijd: 0,
      powered: true, watered: true, roadOk: true,
    };
    let sx = 0, sy = 0;
    for (const c of b.cells) { sx += c % W; sy += (c / W) | 0; G.bld[c] = b.id + 1; }
    b.x = sx / b.cells.length; b.y = sy / b.cells.length;
    G.buildings.push(b);
  }
  G.transitLines = d.transitLines || []; G.nextLineId = d.nextLineId || 1;
  G.money = d.money; G.day = d.day; G.month = d.month; G.year = d.year;
  G.fase = d.fase; G.rp = d.rp; G.techs = d.techs || {}; G.policies = d.policies || {};
  G.taxes = d.taxes || G.taxes; G.pop = d.pop; G.happy = d.happy || 60;
  invalidateWaterCache();
  markAllDirty();
  recomputeCapacities();
  UI.refreshTools(); UI.refreshTop(); UI.refreshRight();
  UI.toast("📂 Spel geladen.", "good");
  return true;
}

document.getElementById("btn-save").onclick = () => saveGame(false);
document.getElementById("btn-load").onclick = () => loadGame();
document.getElementById("btn-new").onclick = () => {
  if (confirm("Nieuwe kaart starten? Niet-opgeslagen voortgang gaat verloren.")) {
    newGame((Math.random() * 1e9) | 0);
    UI.selected = null;
    UI.refreshTools(); UI.refreshTop(); UI.refreshRight();
    UI.toast("🗺 Nieuwe kaart! Begin met een weg, huizen, een akker en een waterpomp.", "good");
  }
};

// ── Gameloop ────────────────────────────────────────────────
// dagen per seconde per snelheid (frame-onafhankelijk via accumulator)
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
  if (autosaveAcc > 120) { autosaveAcc = 0; saveGame(true); }
  draw();
  drawMinimap();
  requestAnimationFrame(loop);
}

// ── Start ───────────────────────────────────────────────────
resizeCanvas();
if (!loadGame()) {
  newGame(((Math.random() * 1e9) | 0) || 1);
  UI.refreshTools(); UI.refreshTop(); UI.refreshRight();
  UI.toast("Welkom, stadsplanner! Teken eerst een weg, dan huizen ernaast, een akker, een waterpomp aan de rivier en een basisschool.", "good");
}
UI.buildTools();
UI.refreshTop();
UI.refreshRight();
requestAnimationFrame(loop);
