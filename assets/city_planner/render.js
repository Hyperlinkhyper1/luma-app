// ─────────────────────────────────────────────────────────────
// MetroPlan — rendering 2.0
// Strak & minimalistisch (à la Mini Motorways/Islanders):
// · statische laag in chunk-bitmaps (terrein met variatie, gebouwen
//   met schaduw/ramen/dakdetails)
// · dynamische laag per frame, alleen zichtbaar gebied: spline-wegen
//   met vloeiende bochten, kruispunten, auto's, golvend water,
//   zwaaiende bomen, verkeerslichten, grid-overlay
// · camera met vloeiend zoomen, pannen en inertie
// ─────────────────────────────────────────────────────────────
"use strict";

const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");
const mini = document.getElementById("minimap");
const mctx = mini.getContext("2d");

// camera: werkelijke stand + doel (lerp) + inertie-snelheid
const cam = { x: W / 2, y: H / 2, zoom: 7, tx: W / 2, ty: H / 2, tzoom: 7, vx: 0, vy: 0 };
let heatmapMode = "geen";
let hoverTile = -1;
let hoverWorld = { x: 0, y: 0 };
let animT = 0; // animatieklok (seconden)

function resizeCanvas() {
  const r = canvas.parentElement.getBoundingClientRect();
  canvas.width = Math.max(1, r.width * devicePixelRatio);
  canvas.height = Math.max(1, r.height * devicePixelRatio);
}
window.addEventListener("resize", resizeCanvas);

function screenToWorld(px, py) {
  return {
    x: cam.x + (px * devicePixelRatio - canvas.width / 2) / (cam.zoom * devicePixelRatio),
    y: cam.y + (py * devicePixelRatio - canvas.height / 2) / (cam.zoom * devicePixelRatio),
  };
}
function screenToTile(px, py) {
  const w = screenToWorld(px, py);
  const x = Math.floor(w.x), y = Math.floor(w.y);
  return inWorld(x, y) ? idx(x, y) : -1;
}

// deterministische hash per tegel (voor variatie zonder opslag)
function hash2(x, y) {
  let h = (x * 374761393 + y * 668265263) | 0;
  h = (h ^ (h >> 13)) * 1274126177;
  return ((h ^ (h >> 16)) >>> 0) / 4294967296;
}
function shade(hex, f) { // f: -1..1 donker/licht
  const r = parseInt(hex.slice(1, 3), 16), g = parseInt(hex.slice(3, 5), 16), b = parseInt(hex.slice(5, 7), 16);
  const m = f < 0 ? 0 : 255, a = Math.abs(f);
  const mix = c => Math.round(c + (m - c) * a);
  return `rgb(${mix(r)},${mix(g)},${mix(b)})`;
}

// ── Statische chunk-laag ────────────────────────────────────
function renderChunk(ci) {
  const cx0 = (ci % CHUNKS_X) * CHUNK, cy0 = ((ci / CHUNKS_X) | 0) * CHUNK;
  let cv = chunkCanvas[ci];
  if (!cv) {
    cv = document.createElement("canvas");
    cv.width = CHUNK * CHUNK_PX; cv.height = CHUNK * CHUNK_PX;
    chunkCanvas[ci] = cv;
  }
  const c = cv.getContext("2d");
  const P = CHUNK_PX;

  // — pas A: terrein met subtiele variatie en zachte overgangen —
  for (let y = 0; y < CHUNK; y++) {
    const wy = cy0 + y;
    if (wy >= H) break;
    for (let x = 0; x < CHUNK; x++) {
      const wx = cx0 + x;
      if (wx >= W) break;
      const i = idx(wx, wy);
      const t = G.terrain[i];
      // sandbox: onbebouwd terrein is een strak wit canvas
      if (sandbox() && t === TERRAIN.GRAS) {
        c.fillStyle = "#f2f3f5";
        c.fillRect(x * P, y * P, P, P);
        continue;
      }
      c.fillStyle = TERRAIN_DEF[t].kleur;
      c.fillRect(x * P, y * P, P, P);
      const h = hash2(wx, wy);
      if (isWater(t)) {
        // diepteverloop + oeverrand
        c.fillStyle = `rgba(255,255,255,${0.04 + h * 0.03})`;
        c.fillRect(x * P, y * P, P, P);
        let shore = false;
        for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]])
          if (inWorld(wx+dx, wy+dy) && !isWater(G.terrain[idx(wx+dx, wy+dy)])) shore = true;
        if (shore) {
          c.fillStyle = "rgba(210,230,240,.28)";
          c.beginPath(); c.arc(x * P + P/2, y * P + P/2, P * 0.62, 0, 7); c.fill();
          c.fillStyle = TERRAIN_DEF[t].kleur;
          c.beginPath(); c.arc(x * P + P/2, y * P + P/2, P * 0.5, 0, 7); c.fill();
        }
      } else {
        // hoogte-schaduw + kleurjitter
        const sh = (G.height[i] - 0.5) * 0.4 + (h - 0.5) * 0.09;
        c.fillStyle = sh > 0 ? `rgba(255,255,255,${sh * 0.3})` : `rgba(0,0,0,${-sh * 0.35})`;
        c.fillRect(x * P, y * P, P, P);
        // zachte overgang: buurkleur licht laten binnenvloeien
        for (const [dx, dy] of [[1,0],[0,1]]) {
          if (!inWorld(wx+dx, wy+dy)) continue;
          const nt = G.terrain[idx(wx+dx, wy+dy)];
          if (nt !== t && !isWater(nt)) {
            c.fillStyle = TERRAIN_DEF[nt].kleur;
            c.globalAlpha = 0.22;
            if (dx) c.fillRect(x * P + P - 3, y * P, 3, P);
            else c.fillRect(x * P, y * P + P - 3, P, 3);
            c.globalAlpha = 1;
          }
        }
        // grassprietjes / detail-stipjes
        if ((t === TERRAIN.GRAS || t === TERRAIN.LANDBOUW) && h > 0.35) {
          c.fillStyle = "rgba(0,0,0,.13)";
          c.fillRect(x * P + ((h * 89) % (P - 3)) | 0, y * P + ((h * 53) % (P - 3)) | 0, 2, 2);
          if (h > 0.75) {
            c.fillStyle = "rgba(255,255,235,.10)";
            c.fillRect(x * P + ((h * 31) % (P - 3)) | 0, y * P + ((h * 71) % (P - 3)) | 0, 2, 2);
          }
        }
        if (t === TERRAIN.LANDBOUW) { // ploegvoren
          c.strokeStyle = "rgba(0,0,0,.10)"; c.lineWidth = 1;
          c.beginPath();
          for (let k = 2; k < P; k += 4) { c.moveTo(x * P, y * P + k); c.lineTo(x * P + P, y * P + k); }
          c.stroke();
        }
      }
    }
  }

  // — pas B: bomen (bos) + legacy-wegtegels (oude saves) —
  for (let y = 0; y < CHUNK; y++) {
    const wy = cy0 + y;
    if (wy >= H) break;
    for (let x = 0; x < CHUNK; x++) {
      const wx = cx0 + x;
      if (wx >= W) break;
      const i = idx(wx, wy);
      if (G.terrain[i] === TERRAIN.BOS) drawTreesInTile(c, x, y, wx, wy, P);
      if (G.road[i] > 0 && G.roadCover[i] === 0 && G.bld[i] === 0) {
        const rd = ROADS[G.road[i]];
        c.fillStyle = rd.kleur;
        c.fillRect(x * P, y * P, P, P);
      }
    }
  }

  // — pas C: gebouwen (met bbox-overlap zodat offsets/hoogte over
  //   chunkgrenzen heen correct meegetekend worden) —
  const seen = new Set();
  for (let y = -2; y < CHUNK + 2; y++) {
    const wy = cy0 + y;
    if (wy < 0 || wy >= H) continue;
    for (let x = -2; x < CHUNK + 2; x++) {
      const wx = cx0 + x;
      if (wx < 0 || wx >= W) continue;
      const bid = G.bld[idx(wx, wy)];
      if (bid > 0 && !seen.has(bid)) {
        seen.add(bid);
        const b = G.buildings[bid - 1];
        if (b) drawBuilding(c, b, cx0, cy0, P);
      }
    }
  }
}

// bomen met jitter, schaalvariatie — nooit een perfect raster
function drawTreesInTile(c, x, y, wx, wy, P) {
  const n = 1 + ((hash2(wx * 3 + 1, wy) * 2.4) | 0);
  for (let k = 0; k < n; k++) {
    const h1 = hash2(wx * 7 + k * 13, wy * 5 + k);
    const h2 = hash2(wx * 11 + k, wy * 17 + k * 7);
    const px = x * P + 2 + h1 * (P - 5), py = y * P + 2 + h2 * (P - 5);
    const r = P * (0.16 + h1 * 0.14);
    c.fillStyle = "rgba(0,0,0,.18)"; // slagschaduw
    c.beginPath(); c.ellipse(px + r * 0.4, py + r * 0.5, r, r * 0.7, 0, 0, 7); c.fill();
    c.fillStyle = shade("#2c5228", -0.25 + h2 * 0.2);
    c.beginPath(); c.arc(px, py, r, 0, 7); c.fill();
    c.fillStyle = shade("#3f7a37", h1 * 0.25);
    c.beginPath(); c.arc(px - r * 0.25, py - r * 0.25, r * 0.55, 0, 7); c.fill();
  }
}

// gebouw met schaduw, gevel-hoogte, dak, ramen, ingang, dakinstallaties
function drawBuilding(c, b, cx0, cy0, P) {
  const def = BUILDINGS[b.type];
  const off = (b.ox || 0) * P, offY = (b.oy || 0) * P;
  const lift = Math.min(6, b.floors.length * 0.7) * (P / 16); // pseudo-hoogte
  const hb = hash2(b.bx0 * 3, b.by0 * 7);
  const roof = shade(def.kleur, (hb - 0.5) * 0.16);
  const cellRect = i => {
    const wx = i % W, wy = (i / W) | 0;
    return [(wx - cx0) * P + off, (wy - cy0) * P + offY];
  };
  const isOwn = (wx, wy) => inWorld(wx, wy) && G.bld[idx(wx, wy)] === b.id + 1;

  // 1: slagschaduw (zuidoost)
  c.fillStyle = "rgba(10,14,20,.28)";
  for (const i of b.cells) {
    const [px, py] = cellRect(i);
    c.fillRect(px + P * 0.22, py + P * 0.22, P, P);
  }
  // 2: gevel (verticale zijde onder het dak)
  if (lift > 0.5) {
    c.fillStyle = shade(def.kleur, -0.42);
    for (const i of b.cells) {
      const [px, py] = cellRect(i);
      c.fillRect(px, py - lift + P, P, lift);
    }
  }
  // 3: dakvlak (omhoog geschoven met lift)
  for (const i of b.cells) {
    const [px, py] = cellRect(i);
    c.fillStyle = roof;
    c.fillRect(px, py - lift, P, P);
  }
  // 4: contour + lichtkant (alleen buitenranden)
  for (const i of b.cells) {
    const wx = i % W, wy = (i / W) | 0;
    const [px, pyRaw] = cellRect(i);
    const py = pyRaw - lift;
    c.fillStyle = "rgba(8,12,18,.5)";
    if (!isOwn(wx - 1, wy)) c.fillRect(px, py, 1.4, P);
    if (!isOwn(wx + 1, wy)) c.fillRect(px + P - 1.4, py, 1.4, P);
    if (!isOwn(wx, wy - 1)) c.fillRect(px, py, P, 1.4);
    if (!isOwn(wx, wy + 1)) c.fillRect(px, py + P - 1.4, P, 1.4);
    c.fillStyle = "rgba(255,255,255,.20)";
    if (!isOwn(wx, wy - 1)) c.fillRect(px + 1.4, py + 1.4, P - 2.8, 1.2);
    if (!isOwn(wx - 1, wy)) c.fillRect(px + 1.4, py + 1.4, 1.2, P - 2.8);
  }
  // 5: details per categorie
  if (def.cat === "voedsel" && (b.type === "akker")) {
    c.strokeStyle = "rgba(0,0,0,.16)"; c.lineWidth = 1;
    for (const i of b.cells) {
      const [px, py] = cellRect(i);
      c.beginPath();
      for (let k = 3; k < P; k += 4) { c.moveTo(px + 1, py + k); c.lineTo(px + P - 1, py + k); }
      c.stroke();
    }
  } else if (b.type === "park") {
    for (const i of b.cells) {
      const wx = i % W, wy = (i / W) | 0;
      const [px, py] = cellRect(i);
      if (hash2(wx, wy * 3) > 0.4) {
        const r = P * 0.2;
        c.fillStyle = "#2f6b2b";
        c.beginPath(); c.arc(px + P * 0.3 + hash2(wx, wy) * P * 0.4, py + P * 0.35 + hash2(wy, wx) * P * 0.3, r, 0, 7); c.fill();
      }
    }
  } else if (b.type === "windmolen") {
    // mast; wieken draaien in de dynamische laag
    for (const i of b.cells) {
      const [px, py] = cellRect(i);
      c.fillStyle = "#e8edf2";
      c.fillRect(px + P / 2 - 1, py + P * 0.25, 2, P * 0.55);
    }
  } else if (b.type === "zonnepark" || (def.cat !== "publiek" && G.techs.zon && hb > 0.55 && b.floors.length <= 3)) {
    // zonnepanelen op het dak
    for (const i of b.cells) {
      const [px, pyRaw] = cellRect(i);
      const py = pyRaw - lift;
      c.fillStyle = "#27476e";
      c.fillRect(px + 2.5, py + 2.5, P - 5, P - 5);
      c.strokeStyle = "rgba(255,255,255,.25)"; c.lineWidth = 0.8;
      c.strokeRect(px + 2.5, py + 2.5, P - 5, P - 5);
    }
  } else {
    // ramen op het dakvlak (leesbaar, minimalistisch)
    c.fillStyle = "rgba(20,28,40,.5)";
    for (const i of b.cells) {
      const wx = i % W, wy = (i / W) | 0;
      if (hash2(wx * 5, wy * 9 + b.id) < 0.25) continue;
      const [px, pyRaw] = cellRect(i);
      const py = pyRaw - lift;
      for (let ry = 0; ry < 2; ry++) for (let rx = 0; rx < 2; rx++)
        c.fillRect(px + P * 0.22 + rx * P * 0.36, py + P * 0.22 + ry * P * 0.36, P * 0.18, P * 0.18);
    }
    // dakinstallaties (airco/leidingen) op grotere gebouwen
    if (b.cells.length >= 4) {
      const i = b.cells[(hb * b.cells.length) | 0];
      const [px, pyRaw] = cellRect(i);
      const py = pyRaw - lift;
      c.fillStyle = "#8b929c";
      c.fillRect(px + P * 0.3, py + P * 0.3, P * 0.28, P * 0.2);
      c.fillStyle = "rgba(0,0,0,.3)";
      c.fillRect(px + P * 0.3, py + P * 0.44, P * 0.28, P * 0.06);
    }
  }
  // 6: ingang aan de wegkant
  for (const i of b.cells) {
    const wx = i % W, wy = (i / W) | 0;
    const dirs = [[1,0],[-1,0],[0,1],[0,-1]];
    for (const [dx, dy] of dirs) {
      if (inWorld(wx+dx, wy+dy) && G.road[idx(wx+dx, wy+dy)] > 0) {
        const [px, pyRaw] = cellRect(i);
        const py = pyRaw; // ingang op straatniveau
        c.fillStyle = "rgba(15,20,28,.75)";
        if (dx === 1) c.fillRect(px + P - 3, py + P * 0.35, 3, P * 0.3);
        else if (dx === -1) c.fillRect(px, py + P * 0.35, 3, P * 0.3);
        else if (dy === 1) c.fillRect(px + P * 0.35, py + P - 3, P * 0.3, 3);
        else c.fillRect(px + P * 0.35, py, P * 0.3, 3);
        return; // één ingang
      }
    }
  }
}

// ── Heatmaps (ongewijzigde logica) ──────────────────────────
function heatColor(v) {
  const t = Math.max(0, Math.min(1, v));
  const r = t < 0.5 ? t * 2 * 255 : 255;
  const g = t < 0.5 ? 255 : (1 - (t - 0.5) * 2) * 255;
  return `rgba(${r | 0},${g | 0},60,0.55)`;
}
function heatValue(i) {
  switch (heatmapMode) {
    case "verkeer": {
      if (G.road[i] === 0) return -1;
      return Math.min(1, G.traffic[i] / (ROADS[G.road[i]].cap * roadCapFactor()));
    }
    case "geluid": return Math.min(1, G.noise[i] / 3);
    case "lucht": return Math.min(1, G.pollution[i] / 8);
    case "geluk": return G.bld[i] > 0 ? 1 - G.happyMap[i] : -1;
    case "waarde": return 1 - Math.min(1, G.landValue[i] / 1.2);
    case "ov": return 1 - Math.min(1, G.svcTransit[i]);
    case "onderwijs": return 1 - Math.min(1, G.svcEdu[i]);
    case "gezondheid": return 1 - Math.min(1, G.svcHealth[i]);
    case "veiligheid": return 1 - Math.min(1, G.svcSafety[i]);
    case "groen": return 1 - Math.min(1, G.svcGreen[i] + (G.terrain[i] === TERRAIN.BOS ? 1 : 0));
    case "energie": return G.road[i] > 0 ? (G.powerOk[i] === 2 ? 0 : G.powerOk[i] === 1 ? 0.6 : 1) : -1;
    case "water": return G.road[i] > 0 ? (G.waterOk[i] === 2 ? 0 : G.waterOk[i] === 1 ? 0.6 : 1) : -1;
    default: return -1;
  }
}

// ── Auto's: object-pool over de spline-wegen ────────────────
const Cars = {
  pool: [],
  spawnAcc: 0,
  update(dt) {
    if (G.speed === 0 || !G.roadPaths.length) return;
    // doelaantal schaalt met totaal verkeer, met harde limiet (pooling)
    const v = G.stats.verkeer || { drukte: 0 };
    const target = Math.min(160, 8 + Math.round((G.jobsFilled || 0) / 60) + Math.round(v.drukte * 60));
    this.spawnAcc += dt;
    if (this.pool.length < target && this.spawnAcc > 0.12) {
      this.spawnAcc = 0;
      const p = G.roadPaths[(Math.random() * G.roadPaths.length) | 0];
      if (p && p.len > 2) {
        const rev = Math.random() < 0.5;
        this.pool.push({
          p, d: rev ? p.len : 0, rev,
          lane: (Math.random() - 0.5) * 0.22,
          col: ["#dfe3e8", "#b8c4d4", "#e8c8a0", "#9fb4a8", "#c4a4b4"][(Math.random() * 5) | 0],
          v: 0,
        });
      }
    }
    for (let k = this.pool.length - 1; k >= 0; k--) {
      const car = this.pool[k];
      if (!G.roadPaths.includes(car.p)) { this.pool.splice(k, 1); continue; }
      const rd = ROADS[car.p.type];
      const pos = pathPoint(car.p, car.d);
      const ti = inWorld(pos.x | 0, pos.y | 0) ? idx(pos.x | 0, pos.y | 0) : -1;
      const cong = ti >= 0 && G.road[ti] ? Math.min(2.5, G.traffic[ti] / (rd.cap * roadCapFactor())) : 0;
      const vmax = (rd.snelheid / 18) / (1 + cong * 1.6);
      car.v += (vmax - car.v) * Math.min(1, dt * 2.5); // geleidelijk remmen/optrekken
      car.d += (car.rev ? -1 : 1) * car.v * dt * DAY_RATE[G.speed];
      if (car.d < 0 || car.d > car.p.len) this.pool.splice(k, 1);
    }
    if (this.pool.length > 170) this.pool.length = 170;
  },
  draw(ox, oy, z) {
    if (z < 4.5) return;
    for (const car of this.pool) {
      const pos = pathPoint(car.p, car.d);
      const nx = -Math.sin(pos.ang), ny = Math.cos(pos.ang);
      const lx = pos.x + nx * (car.rev ? -Math.abs(car.lane) : Math.abs(car.lane));
      const ly = pos.y + ny * (car.rev ? -Math.abs(car.lane) : Math.abs(car.lane));
      const sx = ox + lx * z, sy = oy + ly * z;
      if (sx < -20 || sy < -20 || sx > canvas.width + 20 || sy > canvas.height + 20) continue;
      ctx.save();
      ctx.translate(sx, sy);
      ctx.rotate(pos.ang + (car.rev ? Math.PI : 0));
      ctx.fillStyle = "rgba(0,0,0,.3)";
      ctx.fillRect(-z * 0.16, -z * 0.09 + z * 0.04, z * 0.34, z * 0.2);
      ctx.fillStyle = car.col;
      ctx.fillRect(-z * 0.17, -z * 0.1, z * 0.34, z * 0.2);
      ctx.fillStyle = "rgba(30,40,55,.8)";
      ctx.fillRect(-z * 0.02, -z * 0.08, z * 0.1, z * 0.16);
      ctx.restore();
    }
  },
};

// ── Spline-wegen tekenen ────────────────────────────────────
function strokePath(pts, ox, oy, z, width, style, dash) {
  ctx.strokeStyle = style;
  ctx.lineWidth = width;
  ctx.lineJoin = "round";
  ctx.lineCap = "round";
  if (dash) ctx.setLineDash(dash); else ctx.setLineDash([]);
  ctx.beginPath();
  for (let k = 0; k < pts.length; k++) {
    const sx = ox + pts[k].x * z, sy = oy + pts[k].y * z;
    if (k === 0) ctx.moveTo(sx, sy); else ctx.lineTo(sx, sy);
  }
  ctx.stroke();
  ctx.setLineDash([]);
}

function pathVisible(p, wx0, wy0, wx1, wy1) {
  if (p.bb === undefined) {
    let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
    for (const q of p.pts) { if (q.x < x0) x0 = q.x; if (q.x > x1) x1 = q.x; if (q.y < y0) y0 = q.y; if (q.y > y1) y1 = q.y; }
    p.bb = [x0 - 2, y0 - 2, x1 + 2, y1 + 2];
  }
  return !(p.bb[2] < wx0 || p.bb[0] > wx1 || p.bb[3] < wy0 || p.bb[1] > wy1);
}

function drawRoads(ox, oy, z, wx0, wy0, wx1, wy1) {
  // 1: berm/stoep-onderlaag  2: asfalt  → per laag alle paden zodat
  // kruisingen naadloos in elkaar overlopen
  for (const p of G.roadPaths) {
    if (!pathVisible(p, wx0, wy0, wx1, wy1)) continue;
    const rd = ROADS[p.type];
    strokePath(p.pts, ox, oy, z, rd.w * z + z * 0.34, rd.berm);
  }
  for (const p of G.roadPaths) {
    if (!pathVisible(p, wx0, wy0, wx1, wy1)) continue;
    const rd = ROADS[p.type];
    strokePath(p.pts, ox, oy, z, rd.w * z, rd.kleur);
  }
  // kruispunt-patches: effen asfalt over de belijning heen
  const junctionR = z * 0.9;
  // 3: middenstrepen (over asfalt, onder kruispunt-patches)
  if (z >= 5) {
    for (const p of G.roadPaths) {
      if (!pathVisible(p, wx0, wy0, wx1, wy1)) continue;
      const rd = ROADS[p.type];
      if (!rd.streep) continue;
      strokePath(p.pts, ox, oy, z, Math.max(1, z * 0.055), "rgba(240,240,235,.65)", [z * 0.55, z * 0.5]);
      if (p.type === 4) { // snelweg: doorgetrokken kantstrepen
        strokePath(p.pts, ox, oy, z, rd.w * z * 0.92, "rgba(0,0,0,0)"); // reset dash-state
      }
    }
  }
  // 4: kruispunten schoonvegen
  for (const ji of G.junctions) {
    const jx = ji % W + 0.5, jy = ((ji / W) | 0) + 0.5;
    if (jx < wx0 - 2 || jx > wx1 + 2 || jy < wy0 - 2 || jy > wy1 + 2) continue;
    let mx = 0;
    for (const p of G.roadPaths) { /* breedste weg op dit punt bepaalt patchmaat */
      if (pathVisible(p, jx - 2, jy - 2, jx + 2, jy + 2)) mx = Math.max(mx, ROADS[p.type].w);
    }
    ctx.fillStyle = ROADS[Math.max(1, G.road[ji])].kleur;
    ctx.beginPath(); ctx.arc(ox + jx * z, oy + jy * z, Math.max(junctionR, mx * z * 0.62), 0, 7); ctx.fill();
    // verkeerslichten (tech) knipperen vloeiend
    if (G.techs.verkeerslichten && z >= 9) {
      const phase = (animT * 0.5 + hash2(ji, 7)) % 1;
      const groen = phase < 0.5;
      const a = 0.4 + 0.6 * Math.abs(Math.sin(phase * Math.PI * 2));
      ctx.fillStyle = groen ? `rgba(80,220,120,${a})` : `rgba(235,90,80,${a})`;
      ctx.beginPath(); ctx.arc(ox + jx * z + z * 0.55, oy + jy * z - z * 0.55, z * 0.1, 0, 7); ctx.fill();
    }
  }
}

// ── Hoofd-draw ──────────────────────────────────────────────
let lastDrawT = performance.now();
function draw() {
  const now = performance.now();
  const dt = Math.min(0.1, (now - lastDrawT) / 1000);
  lastDrawT = now;
  animT += dt;

  // camera: vloeiend naar doel + inertie
  cam.tx += cam.vx * dt; cam.ty += cam.vy * dt;
  cam.vx *= Math.pow(0.06, dt); cam.vy *= Math.pow(0.06, dt);
  if (Math.abs(cam.vx) < 0.5) cam.vx = 0;
  if (Math.abs(cam.vy) < 0.5) cam.vy = 0;
  cam.tx = Math.max(0, Math.min(W, cam.tx));
  cam.ty = Math.max(0, Math.min(H, cam.ty));
  const k = 1 - Math.pow(0.0005, dt);
  cam.x += (cam.tx - cam.x) * k;
  cam.y += (cam.ty - cam.y) * k;
  cam.zoom += (cam.tzoom - cam.zoom) * k;

  const cw = canvas.width, ch = canvas.height;
  ctx.fillStyle = sandbox() ? "#dfe2e6" : "#0a0d12";
  ctx.fillRect(0, 0, cw, ch);
  const z = cam.zoom * devicePixelRatio;
  const ox = cw / 2 - cam.x * z, oy = ch / 2 - cam.y * z;
  const wx0 = Math.max(0, -ox / z), wy0 = Math.max(0, -oy / z);
  const wx1 = Math.min(W, (cw - ox) / z), wy1 = Math.min(H, (ch - oy) / z);

  // statische chunks (frustum-culled)
  const x0 = Math.max(0, Math.floor(wx0 / CHUNK)), y0 = Math.max(0, Math.floor(wy0 / CHUNK));
  const x1 = Math.min(CHUNKS_X - 1, Math.floor(wx1 / CHUNK)), y1 = Math.min(CHUNKS_Y - 1, Math.floor(wy1 / CHUNK));
  ctx.imageSmoothingEnabled = true;
  for (let cy = y0; cy <= y1; cy++) {
    for (let cx = x0; cx <= x1; cx++) {
      const ci = cy * CHUNKS_X + cx;
      if (chunkDirty[ci]) { renderChunk(ci); chunkDirty[ci] = false; }
      const cv = chunkCanvas[ci];
      if (cv) ctx.drawImage(cv, ox + cx * CHUNK * z, oy + cy * CHUNK * z, CHUNK * z + 0.5, CHUNK * z + 0.5);
    }
  }

  // water-animatie: glinsteringen op zichtbare watertegels (LOD)
  if (cam.zoom >= 5 && heatmapMode === "geen") {
    const tx0 = Math.floor(wx0), ty0 = Math.floor(wy0), tx1 = Math.ceil(wx1), ty1 = Math.ceil(wy1);
    ctx.fillStyle = "rgba(255,255,255,.16)";
    for (let y = ty0; y < ty1; y++) {
      for (let x = tx0; x < tx1; x++) {
        if (!inWorld(x, y) || !isWater(G.terrain[idx(x, y)])) continue;
        const h = hash2(x, y);
        if (h < 0.55) continue;
        const wob = Math.sin(animT * (0.8 + h) + h * 40);
        if (wob > 0.2) {
          ctx.globalAlpha = (wob - 0.2) * 0.3;
          ctx.fillRect(ox + (x + 0.2 + h * 0.4 + wob * 0.06) * z, oy + (y + 0.3 + h * 0.3) * z, z * 0.3, Math.max(1, z * 0.05));
        }
      }
    }
    ctx.globalAlpha = 1;
  }

  // zwaaiende boomkruinen (alleen dichtbij; subtiel)
  if (cam.zoom >= 9 && heatmapMode === "geen") {
    const tx0 = Math.floor(wx0), ty0 = Math.floor(wy0), tx1 = Math.ceil(wx1), ty1 = Math.ceil(wy1);
    for (let y = ty0; y < ty1; y++) {
      for (let x = tx0; x < tx1; x++) {
        if (!inWorld(x, y) || G.terrain[idx(x, y)] !== TERRAIN.BOS) continue;
        const h1 = hash2(x * 7 + 13, y * 5);
        const sway = Math.sin(animT * 1.3 + h1 * 20) * 0.05;
        const r = z * (0.16 + h1 * 0.14);
        ctx.fillStyle = "rgba(90,150,80,.35)";
        ctx.beginPath();
        ctx.arc(ox + (x + 0.15 + h1 * 0.6 + sway) * z, oy + (y + 0.15 + hash2(x * 11, y * 17) * 0.6) * z, r * 0.6, 0, 7);
        ctx.fill();
      }
    }
  }

  // wegen (splines) + kruispunten + auto's
  if (heatmapMode === "geen" || heatmapMode === "verkeer") {
    drawRoads(ox, oy, z, wx0, wy0, wx1, wy1);
    Cars.update(dt);
    if (heatmapMode === "geen") Cars.draw(ox, oy, z);
  }

  // draaiende windmolenwieken
  if (cam.zoom >= 5 && heatmapMode === "geen") {
    eachBuilding(b => {
      if (b.type !== "windmolen") return;
      if (b.x < wx0 - 2 || b.x > wx1 + 2 || b.y < wy0 - 2 || b.y > wy1 + 2) return;
      const cx = ox + (b.x + 0.5 + (b.ox || 0)) * z, cy = oy + (b.y + 0.28 + (b.oy || 0)) * z;
      const a = animT * (1.5 + hash2(b.id, 3)) * G.weerFactor * 2;
      ctx.strokeStyle = "#eef2f6"; ctx.lineWidth = Math.max(1, z * 0.06); ctx.lineCap = "round";
      for (let w = 0; w < 3; w++) {
        const ang = a + w * (Math.PI * 2 / 3);
        ctx.beginPath(); ctx.moveTo(cx, cy);
        ctx.lineTo(cx + Math.cos(ang) * z * 0.42, cy + Math.sin(ang) * z * 0.42);
        ctx.stroke();
      }
    });
  }

  // heatmap-overlay
  if (heatmapMode !== "geen") {
    const tx0 = Math.floor(wx0), ty0 = Math.floor(wy0), tx1 = Math.ceil(wx1), ty1 = Math.ceil(wy1);
    ctx.fillStyle = "rgba(10,13,18,.45)";
    ctx.fillRect(ox + wx0 * z, oy + wy0 * z, (wx1 - wx0) * z, (wy1 - wy0) * z);
    for (let y = ty0; y < ty1; y++) {
      for (let x = tx0; x < tx1; x++) {
        if (!inWorld(x, y)) continue;
        const v = heatValue(idx(x, y));
        if (v >= 0) { ctx.fillStyle = heatColor(v); ctx.fillRect(ox + x * z, oy + y * z, z + 0.5, z + 0.5); }
      }
    }
  }

  // grid-overlay (hulpmiddel, optioneel)
  if (G.settings.grid && cam.zoom >= 7 && Input.buildToolActive()) {
    const gs = G.settings.gridSize;
    ctx.strokeStyle = sandbox() ? "rgba(0,0,0,.08)" : "rgba(255,255,255,.06)";
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (let x = Math.ceil(wx0 / gs) * gs; x <= wx1; x += gs) { ctx.moveTo(ox + x * z, oy + wy0 * z); ctx.lineTo(ox + x * z, oy + wy1 * z); }
    for (let y = Math.ceil(wy0 / gs) * gs; y <= wy1; y += gs) { ctx.moveTo(ox + wx0 * z, oy + y * z); ctx.lineTo(ox + wx1 * z, oy + y * z); }
    ctx.stroke();
  }

  // OV-lijnen
  for (const l of G.transitLines) {
    if (l.stops.length < 1) continue;
    const tt = TRANSIT_TYPES[l.type];
    ctx.strokeStyle = tt.kleur; ctx.lineWidth = Math.max(1.5, z * 0.18);
    ctx.lineJoin = "round"; ctx.lineCap = "round";
    ctx.globalAlpha = l.actief ? 0.9 : 0.4;
    ctx.beginPath();
    l.stops.forEach((s, k2) => {
      const sx = ox + (s % W + 0.5) * z, sy = oy + (((s / W) | 0) + 0.5) * z;
      if (k2 === 0) ctx.moveTo(sx, sy); else ctx.lineTo(sx, sy);
    });
    ctx.stroke();
    ctx.fillStyle = tt.kleur;
    for (const s of l.stops) {
      const sx = ox + (s % W + 0.5) * z, sy = oy + (((s / W) | 0) + 0.5) * z;
      ctx.beginPath(); ctx.arc(sx, sy, Math.max(2.5, z * 0.26), 0, 7); ctx.fill();
      ctx.fillStyle = "#fff";
      ctx.beginPath(); ctx.arc(sx, sy, Math.max(1, z * 0.1), 0, 7); ctx.fill();
      ctx.fillStyle = tt.kleur;
    }
    ctx.globalAlpha = 1;
  }
  // OV-lijn in aanbouw
  if (Input.lineDraft && Input.lineDraft.stops.length) {
    const tt = TRANSIT_TYPES[Input.lineDraft.type];
    ctx.strokeStyle = tt.kleur; ctx.setLineDash([6, 5]); ctx.lineWidth = Math.max(1.5, z * 0.18);
    ctx.beginPath();
    Input.lineDraft.stops.forEach((s, k2) => {
      const sx = ox + (s % W + 0.5) * z, sy = oy + (((s / W) | 0) + 0.5) * z;
      if (k2 === 0) ctx.moveTo(sx, sy); else ctx.lineTo(sx, sy);
    });
    if (hoverTile >= 0) ctx.lineTo(ox + (hoverTile % W + 0.5) * z, oy + (((hoverTile / W) | 0) + 0.5) * z);
    ctx.stroke(); ctx.setLineDash([]);
  }

  // weg in aanbouw: live voorbeeld van de vloeiende lijn
  if (Input.roadDraft && Input.roadDraft.pts.length > 1) {
    const rd = ROADS[Input.roadDraft.type];
    const prev = chaikin(simplifyPts(Input.roadDraft.pts), 2);
    strokePath(prev, ox, oy, z, rd.w * z + z * 0.3, "rgba(255,255,255,.25)");
    strokePath(prev, ox, oy, z, rd.w * z * 0.8, "rgba(77,163,255,.5)");
  }

  // teken-voorbeeld gebouw/terrein (cellen)
  if (Input.paintCells && Input.paintCells.size) {
    ctx.fillStyle = "rgba(77,163,255,.4)";
    ctx.strokeStyle = "rgba(77,163,255,.9)";
    ctx.lineWidth = 1.5;
    for (const i of Input.paintCells) {
      ctx.fillRect(ox + (i % W) * z, oy + ((i / W) | 0) * z, z, z);
    }
  }

  // rotonde-voorbeeld
  if (UI.tool.kind === "roundabout" && hoverTile >= 0) {
    ctx.strokeStyle = "rgba(77,163,255,.7)"; ctx.lineWidth = Math.max(2, z * 0.5);
    ctx.beginPath();
    ctx.arc(ox + hoverWorld.x * z, oy + hoverWorld.y * z, 2.2 * z, 0, 7);
    ctx.stroke();
  }

  // geselecteerd gebouw
  if (UI.selected && G.buildings[UI.selected.id]) {
    const b = UI.selected;
    ctx.strokeStyle = sandbox() ? "#1a2230" : "#fff"; ctx.lineWidth = 2;
    const pulse = 1 + Math.sin(animT * 4) * 0.5;
    ctx.globalAlpha = 0.55 + pulse * 0.25;
    for (const i of b.cells)
      ctx.strokeRect(ox + (i % W + (b.ox || 0)) * z + 1, oy + (((i / W) | 0) + (b.oy || 0)) * z + 1, z - 2, z - 2);
    ctx.globalAlpha = 1;
  }

  // hover
  if (hoverTile >= 0 && cam.zoom > 3 && UI.tool.kind !== "road") {
    ctx.strokeStyle = sandbox() ? "rgba(0,0,0,.45)" : "rgba(255,255,255,.45)"; ctx.lineWidth = 1;
    ctx.strokeRect(ox + (hoverTile % W) * z, oy + ((hoverTile / W) | 0) * z, z, z);
  }
}

// ── Minimap ─────────────────────────────────────────────────
let miniTimer = 0;
function drawMinimap() {
  if (--miniTimer > 0) return;
  miniTimer = 45;
  const img = mctx.createImageData(150, 150);
  const d = img.data;
  for (let y = 0; y < 150; y++) {
    for (let x = 0; x < 150; x++) {
      const wx = ((x / 150) * W) | 0, wy = ((y / 150) * H) | 0;
      const i = idx(wx, wy);
      let col;
      if (G.bld[i] > 0) col = sandbox() ? [90, 96, 108] : [220, 220, 230];
      else if (G.road[i] > 0) col = [130, 138, 150];
      else if (sandbox() && G.terrain[i] === TERRAIN.GRAS) col = [242, 243, 245];
      else {
        const hex = TERRAIN_DEF[G.terrain[i]].kleur;
        col = [parseInt(hex.slice(1, 3), 16), parseInt(hex.slice(3, 5), 16), parseInt(hex.slice(5, 7), 16)];
      }
      const p = (y * 150 + x) * 4;
      d[p] = col[0]; d[p + 1] = col[1]; d[p + 2] = col[2]; d[p + 3] = 255;
    }
  }
  mctx.putImageData(img, 0, 0);
  const vw = canvas.width / (cam.zoom * devicePixelRatio), vh = canvas.height / (cam.zoom * devicePixelRatio);
  mctx.strokeStyle = "#fff";
  mctx.strokeRect((cam.x - vw / 2) / W * 150, (cam.y - vh / 2) / H * 150, vw / W * 150, vh / H * 150);
}
mini.addEventListener("mousedown", e => {
  const r = mini.getBoundingClientRect();
  cam.tx = (e.clientX - r.left) / r.width * W;
  cam.ty = (e.clientY - r.top) / r.height * H;
  cam.vx = cam.vy = 0;
  miniTimer = 0;
});
