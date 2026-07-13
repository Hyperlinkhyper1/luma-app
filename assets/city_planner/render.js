// ─────────────────────────────────────────────────────────────
// MetroPlan — rendering: camera, chunk-bitmaps, overlays, minimap
// ─────────────────────────────────────────────────────────────
"use strict";

const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");
const mini = document.getElementById("minimap");
const mctx = mini.getContext("2d");

const cam = { x: W / 2, y: H / 2, zoom: 7 }; // zoom = px per tegel
let heatmapMode = "geen";
let hoverTile = -1;

function resizeCanvas() {
  const r = canvas.parentElement.getBoundingClientRect();
  canvas.width = Math.max(1, r.width * devicePixelRatio);
  canvas.height = Math.max(1, r.height * devicePixelRatio);
}
window.addEventListener("resize", resizeCanvas);

function screenToTile(px, py) {
  const x = Math.floor(cam.x + (px * devicePixelRatio - canvas.width / 2) / (cam.zoom * devicePixelRatio));
  const y = Math.floor(cam.y + (py * devicePixelRatio - canvas.height / 2) / (cam.zoom * devicePixelRatio));
  return inWorld(x, y) ? idx(x, y) : -1;
}

// ── Chunk-bitmap opbouwen (terrein + wegen + gebouwen) ──────
function renderChunk(ci) {
  const cx = (ci % CHUNKS_X) * CHUNK, cy = ((ci / CHUNKS_X) | 0) * CHUNK;
  let cv = chunkCanvas[ci];
  if (!cv) {
    cv = document.createElement("canvas");
    cv.width = CHUNK * CHUNK_PX; cv.height = CHUNK * CHUNK_PX;
    chunkCanvas[ci] = cv;
  }
  const c = cv.getContext("2d");
  for (let y = 0; y < CHUNK; y++) {
    const wy = cy + y;
    if (wy >= H) break;
    for (let x = 0; x < CHUNK; x++) {
      const wx = cx + x;
      if (wx >= W) break;
      const i = idx(wx, wy);
      const t = G.terrain[i];
      // terrein met hoogte-schaduw
      c.fillStyle = TERRAIN_DEF[t].kleur;
      c.fillRect(x * CHUNK_PX, y * CHUNK_PX, CHUNK_PX, CHUNK_PX);
      if (!isWater(t)) {
        const sh = (G.height[i] - 0.5) * 0.5;
        c.fillStyle = sh > 0 ? `rgba(255,255,255,${sh * 0.25})` : `rgba(0,0,0,${-sh * 0.3})`;
        c.fillRect(x * CHUNK_PX, y * CHUNK_PX, CHUNK_PX, CHUNK_PX);
      }
      if (t === TERRAIN.BOS) {
        c.fillStyle = "#1e401c";
        c.fillRect(x * CHUNK_PX + 2, y * CHUNK_PX + 2, CHUNK_PX - 4, CHUNK_PX - 4);
      }
      // weg
      if (G.road[i] > 0) {
        const rd = ROADS[G.road[i]];
        c.fillStyle = rd.kleur;
        c.fillRect(x * CHUNK_PX, y * CHUNK_PX, CHUNK_PX, CHUNK_PX);
        c.fillStyle = "rgba(255,255,255,.5)";
        // middenstreep in richting van buurwegen
        const hor = (inWorld(wx+1,wy) && G.road[idx(wx+1,wy)]) || (inWorld(wx-1,wy) && G.road[idx(wx-1,wy)]);
        if (hor) c.fillRect(x * CHUNK_PX + 1, y * CHUNK_PX + CHUNK_PX / 2, CHUNK_PX - 2, 1);
        else c.fillRect(x * CHUNK_PX + CHUNK_PX / 2, y * CHUNK_PX + 1, 1, CHUNK_PX - 2);
      }
      // gebouw
      if (G.bld[i] > 0) {
        const b = G.buildings[G.bld[i] - 1];
        if (b) {
          const def = BUILDINGS[b.type];
          c.fillStyle = def.kleur;
          c.fillRect(x * CHUNK_PX, y * CHUNK_PX, CHUNK_PX, CHUNK_PX);
          // donkere rand waar het gebouw ophoudt (contour)
          c.fillStyle = "rgba(0,0,0,.45)";
          const bid = G.bld[i];
          if (wx === 0 || G.bld[i - 1] !== bid) c.fillRect(x * CHUNK_PX, y * CHUNK_PX, 1, CHUNK_PX);
          if (wx === W - 1 || G.bld[i + 1] !== bid) c.fillRect(x * CHUNK_PX + CHUNK_PX - 1, y * CHUNK_PX, 1, CHUNK_PX);
          if (wy === 0 || G.bld[i - W] !== bid) c.fillRect(x * CHUNK_PX, y * CHUNK_PX, CHUNK_PX, 1);
          if (wy === H - 1 || G.bld[i + W] !== bid) c.fillRect(x * CHUNK_PX, y * CHUNK_PX + CHUNK_PX - 1, CHUNK_PX, 1);
          // hoogte-indicatie: donkerder naarmate meer verdiepingen
          const fl = Math.min(1, b.floors.length / 30);
          c.fillStyle = `rgba(255,255,255,${fl * 0.35})`;
          c.fillRect(x * CHUNK_PX + 1, y * CHUNK_PX + 1, CHUNK_PX - 2, 2);
        }
      }
    }
  }
}

// ── Heatmap-kleur ───────────────────────────────────────────
function heatColor(v) { // v 0..1 → blauw→groen→geel→rood
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

// ── Hoofd-draw ──────────────────────────────────────────────
function draw() {
  const cw = canvas.width, ch = canvas.height;
  ctx.fillStyle = "#0a0d12";
  ctx.fillRect(0, 0, cw, ch);
  const z = cam.zoom * devicePixelRatio;
  const ox = cw / 2 - cam.x * z, oy = ch / 2 - cam.y * z;

  // zichtbare chunk-range
  const x0 = Math.max(0, Math.floor((-ox) / z / CHUNK));
  const y0 = Math.max(0, Math.floor((-oy) / z / CHUNK));
  const x1 = Math.min(CHUNKS_X - 1, Math.floor((cw - ox) / z / CHUNK));
  const y1 = Math.min(CHUNKS_Y - 1, Math.floor((ch - oy) / z / CHUNK));

  ctx.imageSmoothingEnabled = cam.zoom < CHUNK_PX;
  for (let cy = y0; cy <= y1; cy++) {
    for (let cx = x0; cx <= x1; cx++) {
      const ci = cy * CHUNKS_X + cx;
      if (chunkDirty[ci]) { renderChunk(ci); chunkDirty[ci] = false; }
      const cv = chunkCanvas[ci];
      if (cv) ctx.drawImage(cv, ox + cx * CHUNK * z, oy + cy * CHUNK * z, CHUNK * z, CHUNK * z);
    }
  }

  // heatmap-overlay (alleen zichtbare tegels)
  if (heatmapMode !== "geen") {
    const tx0 = Math.max(0, Math.floor(-ox / z)), ty0 = Math.max(0, Math.floor(-oy / z));
    const tx1 = Math.min(W - 1, Math.ceil((cw - ox) / z)), ty1 = Math.min(H - 1, Math.ceil((ch - oy) / z));
    ctx.fillStyle = "rgba(10,13,18,.45)";
    ctx.fillRect(ox, oy, W * z, H * z);
    for (let y = ty0; y <= ty1; y++) {
      for (let x = tx0; x <= tx1; x++) {
        const v = heatValue(idx(x, y));
        if (v >= 0) { ctx.fillStyle = heatColor(v); ctx.fillRect(ox + x * z, oy + y * z, z, z); }
      }
    }
  }

  // verkeersgloed op normale weergave (alleen zwaar verkeer)
  if (heatmapMode === "geen" && cam.zoom >= 4) {
    const tx0 = Math.max(0, Math.floor(-ox / z)), ty0 = Math.max(0, Math.floor(-oy / z));
    const tx1 = Math.min(W - 1, Math.ceil((cw - ox) / z)), ty1 = Math.min(H - 1, Math.ceil((ch - oy) / z));
    for (let y = ty0; y <= ty1; y++) {
      for (let x = tx0; x <= tx1; x++) {
        const i = idx(x, y);
        if (G.road[i] > 0) {
          const cong = G.traffic[i] / (ROADS[G.road[i]].cap * roadCapFactor());
          if (cong > 0.7) {
            ctx.fillStyle = cong > 1.2 ? "rgba(239,91,91,.5)" : "rgba(243,177,62,.4)";
            ctx.fillRect(ox + x * z, oy + y * z, z, z);
          }
        }
      }
    }
  }

  // OV-lijnen
  for (const l of G.transitLines) {
    if (l.stops.length < 1) continue;
    const tt = TRANSIT_TYPES[l.type];
    ctx.strokeStyle = tt.kleur; ctx.lineWidth = Math.max(1.5, z * 0.22);
    ctx.globalAlpha = l.actief ? 0.9 : 0.4;
    ctx.beginPath();
    l.stops.forEach((s, k) => {
      const sx = ox + (s % W + 0.5) * z, sy = oy + (((s / W) | 0) + 0.5) * z;
      if (k === 0) ctx.moveTo(sx, sy); else ctx.lineTo(sx, sy);
    });
    ctx.stroke();
    ctx.fillStyle = tt.kleur;
    for (const s of l.stops) {
      const sx = ox + (s % W + 0.5) * z, sy = oy + (((s / W) | 0) + 0.5) * z;
      ctx.beginPath(); ctx.arc(sx, sy, Math.max(2.5, z * 0.3), 0, 7); ctx.fill();
    }
    ctx.globalAlpha = 1;
  }
  // lijn in aanbouw
  if (Input.lineDraft && Input.lineDraft.stops.length) {
    const tt = TRANSIT_TYPES[Input.lineDraft.type];
    ctx.strokeStyle = tt.kleur; ctx.setLineDash([6, 5]); ctx.lineWidth = Math.max(1.5, z * 0.22);
    ctx.beginPath();
    Input.lineDraft.stops.forEach((s, k) => {
      const sx = ox + (s % W + 0.5) * z, sy = oy + (((s / W) | 0) + 0.5) * z;
      if (k === 0) ctx.moveTo(sx, sy); else ctx.lineTo(sx, sy);
    });
    if (hoverTile >= 0) ctx.lineTo(ox + (hoverTile % W + 0.5) * z, oy + (((hoverTile / W) | 0) + 0.5) * z);
    ctx.stroke(); ctx.setLineDash([]);
  }

  // teken-voorbeeld (gebouw/weg-selectie)
  if (Input.paintCells && Input.paintCells.size) {
    ctx.fillStyle = "rgba(77,163,255,.45)";
    for (const i of Input.paintCells) ctx.fillRect(ox + (i % W) * z, oy + ((i / W) | 0) * z, z, z);
  }

  // geselecteerd gebouw markeren
  if (UI.selected && G.buildings[UI.selected.id]) {
    ctx.strokeStyle = "#fff"; ctx.lineWidth = 2;
    for (const i of UI.selected.cells)
      ctx.strokeRect(ox + (i % W) * z + 1, oy + ((i / W) | 0) * z + 1, z - 2, z - 2);
  }

  // hover-highlight
  if (hoverTile >= 0 && cam.zoom > 3) {
    ctx.strokeStyle = "rgba(255,255,255,.6)"; ctx.lineWidth = 1;
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
      if (G.bld[i] > 0) col = [220, 220, 230];
      else if (G.road[i] > 0) col = [110, 118, 130];
      else {
        const hex = TERRAIN_DEF[G.terrain[i]].kleur;
        col = [parseInt(hex.slice(1, 3), 16), parseInt(hex.slice(3, 5), 16), parseInt(hex.slice(5, 7), 16)];
      }
      const p = (y * 150 + x) * 4;
      d[p] = col[0]; d[p + 1] = col[1]; d[p + 2] = col[2]; d[p + 3] = 255;
    }
  }
  mctx.putImageData(img, 0, 0);
  // camera-kader
  const vw = canvas.width / (cam.zoom * devicePixelRatio), vh = canvas.height / (cam.zoom * devicePixelRatio);
  mctx.strokeStyle = "#fff";
  mctx.strokeRect((cam.x - vw / 2) / W * 150, (cam.y - vh / 2) / H * 150, vw / W * 150, vh / H * 150);
}
mini.addEventListener("mousedown", e => {
  const r = mini.getBoundingClientRect();
  cam.x = (e.clientX - r.left) / r.width * W;
  cam.y = (e.clientY - r.top) / r.height * H;
  miniTimer = 0;
});
