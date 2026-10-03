import * as THREE from 'three/webgpu';
import { Fn, vec3, float, mix, smoothstep, abs, sin, positionGeometry, fract } from 'three/tsl';
import { canvasTexture } from './materials.js';

// Enclosed lifeboats and tenders (photos 5, 9, 11, 14, 20): white GRP hull
// with the scalloped grab line, orange canopy, black rubbing strake. The
// tenders have a row of windows, a side door and a raised conning position.
// Local frame: +x bow, +y up from the keel, +z starboard.

export const BOAT = { L: 15.2, B: 4.9, hull: 1.55, canopy: 1.7 };

function halfBeam(t) {
  // Rounded transom aft, fine entry forward.
  let b = BOAT.B / 2;
  b *= 1 - Math.pow(1 - t, 7) * 0.22;
  if (t > 0.58) b *= Math.sqrt(Math.max(0, 1 - Math.pow((t - 0.58) / 0.42, 2.1)));
  return b;
}
const keelRise = (t) => (t > 0.66 ? Math.pow((t - 0.66) / 0.34, 2) * 1.05 : 0) + (t < 0.06 ? (0.06 - t) * 3 : 0);
const sheer = (t) => Math.pow(Math.max(0, t - 0.55) / 0.45, 2) * 0.32;

/** Loft sections given per-t profile functions returning [z, y] arrays (one side). */
function loft(nT, profile, { closeEnds = true } = {}) {
  const pos = [], idx = [];
  let K = 0;
  const rows = [];
  for (let i = 0; i <= nT; i++) {
    const t = i / nT;
    const prof = profile(t);
    K = prof.length;
    rows.push(prof);
    const x = (t - 0.5) * BOAT.L;
    // starboard then port (mirrored), so K*2 per row
    for (const [z, y] of prof) pos.push(x, y, z);
    for (let k = prof.length - 1; k >= 0; k--) pos.push(x, prof[k][1], -prof[k][0]);
  }
  const R = K * 2;
  for (let i = 0; i < nT; i++) {
    for (let k = 0; k < R - 1; k++) {
      const a = i * R + k, b = a + 1, c = a + R, d = c + 1;
      // Outward-facing: (c - a) x (b - a) = +x cross +y = +z on starboard.
      idx.push(a, c, b, b, c, d);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setIndex(idx);
  g.computeVertexNormals();
  return g;
}

function hullGeometry() {
  return loft(48, (t) => {
    const b = halfBeam(t), k = keelRise(t), s = sheer(t);
    const top = BOAT.hull + s;
    return [
      [0.0, k],
      [b * 0.42, k + 0.18],
      [b * 0.78, k + 0.5 + (top - k) * 0.05],
      [b * 0.95, Math.min(top, k + 0.95)],
      [b, top - 0.12],
      [b, top],
      [b * 0.96, top + 0.02],
    ].map(([z, y]) => [z, Math.max(y, k)]);
  });
}

function canopyGeometry(tender) {
  return loft(48, (t) => {
    const b = halfBeam(t) * 0.97, s = sheer(t);
    const base = BOAT.hull + s;
    const end = Math.pow(Math.abs(2 * t - 1), 4);
    const h = BOAT.canopy * (1 - end * 0.45) + (tender ? 0.05 : 0);
    return [
      [b, base],
      [b * 0.985, base + h * 0.45],
      [b * 0.86, base + h * 0.78],
      [b * 0.55, base + h * 0.96],
      [0, base + h],
    ];
  });
}

function fenderGeometry() {
  return loft(48, (t) => {
    const b = halfBeam(t) + 0.13, s = sheer(t);
    const y = BOAT.hull + s - 0.32;
    return [[b - 0.13, y - 0.12], [b, y - 0.06], [b + 0.02, y + 0.1], [b - 0.1, y + 0.18]];
  });
}

/** Window boxes along the canopy sides of a tender, as one merged geometry. */
function tenderWindows() {
  const geos = [];
  for (const side of [1, -1]) {
    for (let i = 0; i < 9; i++) {
      const t = 0.18 + i * 0.075;
      if (i === 4) continue;                      // the door goes here
      const x = (t - 0.5) * BOAT.L;
      const z = side * (halfBeam(t) * 0.97 + 0.01);
      const g = new THREE.BoxGeometry(1.0, 0.62, 0.06);
      g.translate(x, BOAT.hull + 0.95 + sheer(t), z);
      geos.push(g);
    }
    // Door
    const td = 0.18 + 4 * 0.075, xd = (td - 0.5) * BOAT.L;
    const gd = new THREE.BoxGeometry(1.05, 1.55, 0.06);
    gd.translate(xd, BOAT.hull + 0.72, side * (halfBeam(td) * 0.98 + 0.01));
    geos.push(gd);
  }
  return mergeList(geos);
}

function lifeboatPorts() {
  const geos = [];
  for (const side of [1, -1]) {
    for (let i = 0; i < 6; i++) {
      const t = 0.22 + i * 0.1;
      const g = new THREE.CylinderGeometry(0.2, 0.2, 0.06, 14);
      g.rotateX(Math.PI / 2);
      g.translate((t - 0.5) * BOAT.L, BOAT.hull + 0.82 + sheer(t), side * (halfBeam(t) * 0.97 + 0.01));
      geos.push(g);
    }
  }
  return mergeList(geos);
}

/** Raised conning position with windows, on the aft canopy. */
function conning(tender) {
  const t = tender ? 0.3 : 0.24;
  const x = (t - 0.5) * BOAT.L;
  const top = BOAT.hull + BOAT.canopy;
  const body = new THREE.CylinderGeometry(0.75, 0.9, 0.75, 16);
  body.translate(x, top + 0.25, 0);
  const cap = new THREE.SphereGeometry(0.75, 16, 8, 0, Math.PI * 2, 0, Math.PI / 2);
  cap.scale(1, 0.45, 1);
  cap.translate(x, top + 0.62, 0);
  const glass = new THREE.CylinderGeometry(0.77, 0.86, 0.32, 16, 1, true);
  glass.translate(x, top + 0.36, 0);
  return { orange: mergeList([body, cap]), glass };
}

/** Release hooks and a roof grab rail. */
function hardware() {
  const geos = [];
  const top = BOAT.hull + BOAT.canopy;
  for (const t of [0.1, 0.9]) {
    const x = (t - 0.5) * BOAT.L;
    const g = new THREE.BoxGeometry(0.35, 0.35, 0.35);
    g.translate(x, top - 0.12 + sheer(t), 0);
    geos.push(g);
  }
  for (const side of [1, -1]) {
    const g = new THREE.CylinderGeometry(0.035, 0.035, BOAT.L * 0.55, 6);
    g.rotateZ(Math.PI / 2);
    g.translate(0.4, top + 0.05, side * 0.8);
    geos.push(g);
  }
  return mergeList(geos);
}

function mergeList(list) {
  const geos = list.map((g) => {
    const n = g.index ? g.toNonIndexed() : g;
    for (const k of Object.keys(n.attributes)) if (k !== 'position' && k !== 'normal') n.deleteAttribute(k);
    if (!n.attributes.normal) n.computeVertexNormals();
    return n;
  });
  let count = 0;
  for (const g of geos) count += g.attributes.position.count;
  const pos = new Float32Array(count * 3), nor = new Float32Array(count * 3);
  let o = 0;
  for (const g of geos) {
    pos.set(g.attributes.position.array, o * 3);
    nor.set(g.attributes.normal.array, o * 3);
    o += g.attributes.position.count;
  }
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  out.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
  return out;
}

/** Hull material with the scalloped grab line painted in (photo 14). */
export function boatHullMaterial() {
  const m = new THREE.MeshStandardNodeMaterial({ roughness: 0.35 });
  m.colorNode = Fn(() => {
    const p = positionGeometry;
    const side = abs(p.z).greaterThan(0.6);
    const x = p.x;
    const loop = abs(sin(x.mul(Math.PI / 1.25))).mul(0.2);
    const yLine = float(1.02).sub(loop);
    const d = abs(p.y.sub(yLine));
    const line = smoothstep(0.035, 0.012, d).mul(side ? 1 : 1);
    return mix(vec3(0.86, 0.88, 0.89), vec3(0.05, 0.05, 0.06), line);
  })();
  return m;
}

const cache = new Map();
/** Geometries for one boat variant, built once. */
export function boatParts(tender) {
  const key = tender ? 'tender' : 'lifeboat';
  if (cache.has(key)) return cache.get(key);
  const c = conning(tender);
  const parts = {
    hull: hullGeometry(),
    canopy: canopyGeometry(tender),
    fender: fenderGeometry(),
    windows: tender ? tenderWindows() : lifeboatPorts(),
    tower: c.orange,
    towerGlass: c.glass,
    hardware: hardware(),
  };
  cache.set(key, parts);
  return parts;
}

/**
 * Number plates for every boat in one atlas, one 512x128 row per boat:
 * "8  MSC VIRTUOSA / VALLETTA" (photo 20). Returns the texture and the row
 * index for each number.
 */
export function plateAtlas(numbers) {
  const rows = numbers.length, W = 512, H = 128;
  const index = new Map(numbers.map((n, i) => [n, i]));
  const tex = canvasTexture(W, H * rows, (g) => {
    g.clearRect(0, 0, W, H * rows);
    g.fillStyle = '#16181c';
    g.textBaseline = 'middle';
    g.textAlign = 'left';
    numbers.forEach((num, i) => {
      const y = i * H;
      g.font = `600 ${H * 0.82}px Georgia, 'Times New Roman', serif`;
      g.fillText(String(num), 4, y + H * 0.55);
      const nx = g.measureText(String(num)).width + 18;
      g.font = `600 ${H * 0.34}px Georgia, 'Times New Roman', serif`;
      g.fillText('MSC VIRTUOSA', nx, y + H * 0.34);
      g.font = `600 ${H * 0.23}px Georgia, 'Times New Roman', serif`;
      g.fillText('VALLETTA', nx + 22, y + H * 0.72);
    });
  });
  return { tex, index, rows };
}

export { halfBeam as boatHalfBeam, sheer as boatSheer };
