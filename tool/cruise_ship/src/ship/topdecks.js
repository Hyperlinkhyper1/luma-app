import * as THREE from 'three/webgpu';
import {
  Fn, vec2, vec3, vec4, float, uniform, mix, smoothstep, saturate, abs, sin, cos, fract, floor, time, step,
  positionGeometry, normalWorld, mx_noise_float, max, min, length, dot, uv, texture, If,
} from 'three/tsl';
import { deckY, POOL_DECK, wallLine, railZ, wallZ, frontX, backX, BALCONY_D, RECESS, CABIN_DECKS } from './dims.js';
import { Builder, Instancer, mat, prism, offsetPolyline } from './kit.js';
import { shipPos, shipU, canvasTexture, drawCompass } from './materials.js';
import { closedOutline } from './superstructure.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

// Everything on top: the pool deck (16) with the fish sculptures and the
// giant LED screen (photo 4), the side galleries (17), the enclosed decks
// with the dark glass bands (photos 5, 14, 16), the twin-shell lattice
// funnel with its exhaust stacks and compass rose, radar domes and mast,
// the aqua park's yellow rope-course truss and slides, the aft pool with
// cube lanterns (photo 3) and the forward top sun deck.

const Y16 = deckY(16), Y17 = deckY(17), Y18 = deckY(18), Y19 = deckY(19);
const EDGE = railZ(15) + 0.35;        // outer edge of the top decks (~21.7 m)
const STAIR16 = { x0: 43.0, x1: 50.6, z0: 13.0, z1: 14.6 };   // pool deck -> gallery

// Plan regions (x ranges).
export const TOP = {
  aftDeck: [-158.5, -122],
  mid: [-122, -22],        // enclosed decks 16-17, sports deck 18 with funnel on top
  pool: [-22, 55],
  screen: [55, 64],
  fwd: [64, 0],            // to the front of the cabin block (set below)
};

/** Deck 16 slab outline: the deck 15 rail line, straightened over the recess. */
function deck16Outline() {
  const line = wallLine(15);
  const out = [];
  const off = offsetPolyline(line.map(([x, z, t]) => [x, z, t]), BALCONY_D + 0.35);
  for (let i = 0; i < line.length; i++) {
    const [x, z, tag] = line[i];
    if (tag === 'side' || tag === 'recess' || tag === 'bend') {
      if (tag === 'side') out.push([x, EDGE]);
    } else {
      out.push([off[i][0], Math.min(EDGE, Math.abs(off[i][1]))]);
    }
  }
  // remove recess points: keep monotonic x for the straight run
  return out.sort((a, b) => a[0] - b[0]).filter((p, i, arr) => i === 0 || p[0] - arr[i - 1][0] > 0.05);
}

function halfWidthAt(outline, x) {
  for (let i = 0; i < outline.length - 1; i++) {
    const a = outline[i], b = outline[i + 1];
    if (x >= a[0] && x <= b[0]) {
      const t = (x - a[0]) / Math.max(1e-6, b[0] - a[0]);
      return a[1] + (b[1] - a[1]) * t;
    }
  }
  return 0;
}

/** Closed outline for x0..x1 following the deck edge, inset by `inset`. */
function band(outline, x0, x1, inset = 0, step = 1.5) {
  const pts = [];
  for (let x = x0; x <= x1 + 1e-6; x += step) pts.push([x, Math.max(0.3, halfWidthAt(outline, Math.min(x, x1)) - inset)]);
  return closedOutline(pts);
}

// --- materials only used up here ----------------------------------------------

function poolWaterMaterial() {
  const m = new THREE.MeshStandardNodeMaterial({ roughness: 0.04, metalness: 0.0, transparent: true, opacity: 0.86 });
  m.colorNode = Fn(() => {
    const p = shipPos();
    // Caustic shimmer: two scrolling cell patterns.
    const c1 = mx_noise_float(vec3(p.x.mul(1.7), p.z.mul(1.7), time.mul(0.6)));
    const c2 = mx_noise_float(vec3(p.x.mul(3.1).add(5.0), p.z.mul(3.1), time.mul(0.9)));
    const caust = saturate(float(1.0).sub(abs(c1.add(c2.mul(0.6))).mul(3.0))).mul(0.25);
    return vec3(0.07, 0.62, 0.72).add(caust);
  })();
  m.emissiveNode = vec3(0.05, 0.55, 0.65).mul(shipU.night).mul(0.18).mul(shipU.lightBoost);
  m.userData.noShadow = true;
  return m;
}

function funnelMaterial() {
  const m = new THREE.MeshStandardNodeMaterial({ roughness: 0.4, metalness: 0.2 });
  m.colorNode = Fn(() => {
    const p = shipPos();
    // Lattice of slanted openings in the dark navy shells (photos 5, 14, 16).
    const row = floor(p.y.div(2.1));
    const shear = p.x.add(p.y.mul(0.9)).add(row.mul(1.7));
    const fx = fract(shear.div(3.6));
    const fy = fract(p.y.div(2.1));
    const hole = smoothstep(0.08, 0.14, fx).mul(smoothstep(0.92, 0.86, fx)).mul(smoothstep(0.12, 0.2, fy)).mul(smoothstep(0.88, 0.8, fy));
    const side = smoothstep(0.5, 0.8, abs(normalWorld.z));
    return mix(vec3(0.03, 0.055, 0.11), vec3(0.008, 0.012, 0.02), hole.mul(side));
  })();
  m.emissiveNode = Fn(() => {
    const p = shipPos();
    const row = floor(p.y.div(2.1));
    const shear = p.x.add(p.y.mul(0.9)).add(row.mul(1.7));
    const fx = fract(shear.div(3.6));
    const fy = fract(p.y.div(2.1));
    const hole = smoothstep(0.08, 0.14, fx).mul(smoothstep(0.92, 0.86, fx)).mul(smoothstep(0.12, 0.2, fy)).mul(smoothstep(0.88, 0.8, fy));
    return vec3(0.35, 0.55, 1.0).mul(hole).mul(shipU.night).mul(0.02);
  })();
  return m;
}

function ledScreenMaterial() {
  const m = new THREE.MeshBasicNodeMaterial();
  m.colorNode = Fn(() => {
    const q = uv();
    // A slow "documentary": ocean swell under a sunset sky, with the MSC
    // compass and a ticker, in coarse LED pixels.
    const px = floor(q.mul(vec2(240.0, 132.0))).div(vec2(240.0, 132.0));
    const t = time.mul(0.25);
    const horizon = float(0.42).add(sin(px.x.mul(6.0).add(t)).mul(0.01));
    const skyC = mix(vec3(0.95, 0.55, 0.25), vec3(0.15, 0.25, 0.55), saturate(px.y.sub(horizon).mul(2.2)));
    const sea = mix(vec3(0.02, 0.12, 0.25), vec3(0.05, 0.3, 0.45), sin(px.x.mul(40.0).add(px.y.mul(80.0)).add(t.mul(6.0))).mul(0.5).add(0.5).mul(0.3));
    const sun = smoothstep(0.08, 0.06, length(px.sub(vec2(fract(t.mul(0.05)).mul(0.6).add(0.2), horizon.add(0.06))).mul(vec2(1.8, 1.0))));
    const c = mix(sea, skyC, step(horizon, px.y)).add(vec3(1.0, 0.75, 0.4).mul(sun));
    // LED grid
    const g = fract(q.mul(vec2(240.0, 132.0)));
    const dots = smoothstep(0.5, 0.35, length(g.sub(0.5)));
    return c.mul(mix(float(0.55), float(1.0), dots)).mul(0.9);
  })();
  return m;
}

function fishMaterial() {
  const m = new THREE.MeshStandardNodeMaterial({ roughness: 0.38, metalness: 0.05 });
  m.colorNode = Fn(() => {
    const p = positionGeometry;
    // Overlapping scales: rows of arcs around the body, darker outlines on
    // a teal glaze (photo 4), darker toward the head.
    const ang = p.z.atan(p.x).mul(6.0 / Math.PI);
    const a = p.y.mul(3.0);
    const row = floor(a);
    const s = fract(vec2(ang.add(row.mul(0.5)), a));
    const arc = smoothstep(0.075, 0.0, abs(length(s.sub(vec2(0.5, 0.0))).sub(0.52)));
    const head = smoothstep(4.0, 4.6, p.y);
    const base = mix(vec3(0.07, 0.24, 0.29), vec3(0.03, 0.1, 0.14), head);
    return mix(base, vec3(0.015, 0.045, 0.075), arc.mul(float(1.0).sub(head)).mul(0.85));
  })();
  return m;
}

/**
 * A fish standing on its tail with its mouth open to the sky (photos 3, 4):
 * a bent, flattened lathe body, bulging eyes and a dorsal fin.
 */
function fishGeometry() {
  const pts = [];
  const H = 4.6;
  for (let i = 0; i <= 30; i++) {
    const t = i / 30;
    // Slim at the tail, widest past the middle, an open lip at the top.
    let r = Math.sin(Math.PI * Math.pow(t, 0.78));
    if (t < 0.1) r = 0.22 + t * 2.4;
    if (t > 0.93) r = Math.max(r, 0.32 + (t - 0.93) * 2.0);
    pts.push(new THREE.Vector2(Math.max(0.12, r), t * H + 0.5));
  }
  const body = new THREE.LatheGeometry(pts, 32);
  // Flatten side to side and bend the body into a gentle curve.
  const pos = body.attributes.position;
  for (let i = 0; i < pos.count; i++) {
    const t = (pos.getY(i) - 0.5) / H;
    pos.setZ(i, pos.getZ(i) * 0.7);
    pos.setX(i, pos.getX(i) + Math.sin(t * Math.PI * 1.2) * 0.35);
  }
  body.computeVertexNormals();
  const eyes = [];
  for (const s of [1, -1]) {
    const e = new THREE.SphereGeometry(0.16, 12, 8);
    e.translate(0.36 + Math.sin(0.86 * Math.PI * 1.2) * 0.35, 0.5 + H * 0.86, s * 0.4);
    eyes.push(e);
  }
  const fin = new THREE.Shape();
  fin.moveTo(0, 0); fin.quadraticCurveTo(0.9, 0.5, 0.55, 1.5); fin.lineTo(0.05, 1.3); fin.closePath();
  const fg = new THREE.ExtrudeGeometry(fin, { depth: 0.1, bevelEnabled: true, bevelSize: 0.04, bevelThickness: 0.04, bevelSegments: 2 });
  fg.rotateY(Math.PI);
  fg.translate(-0.55, 2.0, 0.05);
  const tail = new THREE.Shape();
  tail.moveTo(0, 0.55); tail.quadraticCurveTo(-0.6, 0.1, -0.85, -0.15); tail.quadraticCurveTo(0, 0.1, 0.85, -0.15); tail.quadraticCurveTo(0.6, 0.1, 0, 0.55);
  const tg = new THREE.ExtrudeGeometry(tail, { depth: 0.14, bevelEnabled: false });
  tg.translate(0, 0.3, -0.07);
  return [body, tg, fg, ...eyes];
}

export function buildTopDecks(M, col, pois) {
  const fish = [];   // instance matrices, built into one mesh at the end of the aft deck
  const group = new THREE.Group();
  group.name = 'topdecks';
  const B = new Builder();
  const I = new Instancer();

  const outline = deck16Outline();
  TOP.fwd[1] = frontX(15) + BALCONY_D - 2;
  const xFront = TOP.fwd[1];

  // --- deck 16 slab: floor of the top decks, roof over the top balconies -------
  const slab = closedOutline(outline);
  B.add('paint', prism(slab, Y16 - 0.35, Y16 + 0.02));
  col.prism(slab, Y16 - 1.2, Y16);
  // Thin white fascia band at the slab edge reads as the white line in photos.

  // --- the dark glass bands: enclosed decks 16-17 (mid) and 16-18 (forward) ------
  {
    const mid = band(outline, TOP.mid[0], TOP.mid[1], 2.2, 2);
    B.add('navyGlass', prism(mid, Y16, Y18 - 0.4));
    B.add('paint', prism(band(outline, TOP.mid[0] - 0.3, TOP.mid[1] + 0.3, 0.3, 2), Y18 - 0.4, Y18));   // deck 18 floor, overhang
    col.prism(mid, Y16, Y18);
    col.prism(band(outline, TOP.mid[0] - 0.3, TOP.mid[1] + 0.3, 0.3, 2), Y18 - 0.6, Y18);
    // floor band between the two glazed decks
    B.add('paint', prism(band(outline, TOP.mid[0], TOP.mid[1], 2.1, 2), Y17 - 0.25, Y17 + 0.25));

    const fwd = band(outline, TOP.fwd[0], xFront, 2.2, 1.5);
    B.add('navyGlass', prism(fwd, Y16, Y19 - 0.4));
    B.add('paint', prism(band(outline, TOP.fwd[0] - 0.3, xFront + 0.3, 0.3, 1.5), Y19 - 0.4, Y19));
    B.add('paint', prism(band(outline, TOP.fwd[0], xFront, 2.1, 1.5), Y17 - 0.25, Y17 + 0.25));
    B.add('paint', prism(band(outline, TOP.fwd[0], xFront, 2.1, 1.5), Y18 - 0.25, Y18 + 0.25));
    col.prism(fwd, Y16, Y19);
    col.prism(band(outline, TOP.fwd[0] - 0.3, xFront + 0.3, 0.3, 1.5), Y19 - 0.6, Y19);
  }

  // --- screen block at the forward end of the pool (photo 4) --------------------
  {
    const x0 = TOP.screen[0], x1 = TOP.screen[1];
    B.boxMM('paint', x0, Y16, -10, x1, Y19 + 3.2, 10);
    col.boxMM(x0, Y16, -10, x1, Y19 + 3.2, 10);
    // Black frame and the screen itself, facing aft.
    B.boxMM('black', x0 - 0.5, Y17 - 0.4, -10.6, x0, Y19 + 2.2, 10.6);
    const screen = new THREE.Mesh(new THREE.PlaneGeometry(20, 11.2), ledScreenMaterial());
    screen.rotation.y = -Math.PI / 2;
    screen.position.set(x0 - 0.52, (Y17 + Y19 + 1.8) / 2, 0);
    group.add(screen);
    // Stage below the screen.
    B.boxMM('paint', x0 - 6, Y16, -9, x0, Y16 + 0.6, 9);
    col.boxMM(x0 - 6, Y16, -9, x0, Y16 + 0.6, 9);
    // Decorative leaf panels (photo 4) as discs.
    for (const zz of [-6.5, -3.5, 3.5, 6.5]) {
      I.add('leaf', mat(x0 - 0.05, Y16 + 1.9, zz, 0, -Math.PI / 2, 0, 1.0, 1.0, 1));
    }
  }

  // --- mast and radar domes ---------------------------------------------------
  {
    const xm = (TOP.screen[0] + TOP.screen[1]) / 2;
    const yb = Y19 + 3.2;
    for (const zz of [-3.2, 3.2]) B.boxMM('black', xm - 0.5, yb, zz - 0.5, xm + 0.5, yb + 9, zz + 0.5);
    B.boxMM('black', xm - 0.6, yb + 8.2, -3.8, xm + 0.6, yb + 9.4, 3.8);
    B.boxMM('paint', xm - 1.8, yb + 9.4, -2.2, xm + 1.8, yb + 9.8, 2.2);
    B.tube('steel', new THREE.Vector3(xm, yb + 9.8, 0), new THREE.Vector3(xm, yb + 15, 0), 0.12, true);
    B.box('steelDark', xm, yb + 10.6, 0, 0.4, 0.4, 5.5);
    I.add('navWhite', mat(xm, yb + 15.1, 0, 0, 0, 0, 0.25, 0.25, 0.25));
    for (const [zz, r] of [[-11.5, 2.2], [-15.5, 1.9], [11.5, 2.2], [15.5, 1.9]]) {
      B.tube('paint', new THREE.Vector3(xm, Y19, zz), new THREE.Vector3(xm, Y19 + 2.6, zz), 0.45);
      I.add('dome', mat(xm, Y19 + 2.6 + r * 0.95, zz, 0, 0, 0, r, r, r));
    }
  }

  // --- main pool and its deck ---------------------------------------------------
  const pool = { x0: -4, x1: 36, z: 6.2 };
  {
    const [x0, x1] = TOP.pool;
    // Teak around the pool, white mosaic surround.
    B.boxMM('teak', x0, Y16 + 0.02, -13, x1, Y16 + 0.05, 13);
    B.boxMM('mosaic', pool.x0 - 2.5, Y16 + 0.05, -pool.z - 2.5, pool.x1 + 2.5, Y16 + 0.07, pool.z + 2.5);
    // Basin walls (raised lip) and water.
    B.boxMM('mosaic', pool.x0 - 0.3, Y16, -pool.z - 0.3, pool.x1 + 0.3, Y16 + 0.25, -pool.z);
    B.boxMM('mosaic', pool.x0 - 0.3, Y16, pool.z, pool.x1 + 0.3, Y16 + 0.25, pool.z + 0.3);
    B.boxMM('mosaic', pool.x0 - 0.3, Y16, -pool.z, pool.x0, Y16 + 0.25, pool.z);
    B.boxMM('mosaic', pool.x1, Y16, -pool.z, pool.x1 + 0.3, Y16 + 0.25, pool.z);
    const water = new THREE.Mesh(new THREE.PlaneGeometry(pool.x1 - pool.x0, pool.z * 2), poolWaterMaterial());
    water.rotation.x = -Math.PI / 2;
    water.position.set((pool.x0 + pool.x1) / 2, Y16 + 0.12, 0);
    water.renderOrder = 2;
    group.add(water);
    // Blocks the pool to walkers (low lip).
    col.boxMM(pool.x0 - 0.3, Y16, -pool.z - 0.3, pool.x1 + 0.3, Y16 + 0.9, pool.z + 0.3);
    // Submerged teak sunning ledges along both long sides (photo 4).
    for (const s of [1, -1]) {
      for (let x = pool.x0 + 2; x < pool.x1 - 2; x += 3.3) {
        B.boxMM('teak', x, Y16 + 0.25, s * (pool.z + 0.35), x + 2.6, Y16 + 0.42, s * (pool.z + 2.2));
      }
    }
    // Fish sculptures standing in the pool (aft end, as in photo 4).
    for (const [fx, fz, ry] of [[pool.x0 + 6, -3.2, 0.5], [pool.x0 + 6, 3.2, -0.5], [pool.x0 + 2.2, 0, 3.1]]) {
      fish.push(mat(fx, Y16 - 0.4, fz, 0, ry, 0.12));
      // round pedestal
      B.tube('steelDark', new THREE.Vector3(fx, Y16 - 0.2, fz), new THREE.Vector3(fx, Y16 + 0.25, fz), 1.5);
      col.box(fx, Y16 + 2.5, fz, 2, 5, 2);
    }
    // Glass windscreens at the pool corners.
    for (const s of [1, -1]) {
      for (const xx of [pool.x0 - 4, pool.x1 + 4]) {
        B.boxMM('clearGlass', xx - 0.03, Y16, s * 7.5, xx + 0.03, Y16 + 1.6, s * 11.5);
        B.boxMM('stainless', xx - 0.05, Y16 + 1.58, s * 7.5, xx + 0.05, Y16 + 1.66, s * 11.5);
      }
    }
  }

  // --- side galleries (deck 17) with columns, and the covered deck 16 under them ---
  {
    const [x0, x1] = TOP.pool;
    for (const s of [1, -1]) {
      const zi = 12.6;
      // gallery slab
      const ptsOut = [];
      for (let x = x0; x <= x1 + 1e-6; x += 1.5) ptsOut.push([x, halfWidthAt(outline, x) - 0.05]);
      // Inner edge with an opening for the stair flight up from deck 16.
      const inner = [[x1, zi], [STAIR16.x1, zi], [STAIR16.x1, STAIR16.z1 + 0.2], [STAIR16.x0, STAIR16.z1 + 0.2], [STAIR16.x0, zi], [x0, zi]];
      const poly = [...ptsOut.map(([x, z]) => [x, s * z]), ...inner.map(([x, z]) => [x, s * z])];
      const polyCCW = s > 0 ? poly : poly.slice().reverse();
      B.add('paint', prism(polyCCW, Y17 - 0.35, Y17));
      B.add('teak', prism(polyCCW, Y17, Y17 + 0.03));
      col.prism(polyCCW, Y17 - 0.6, Y17);
      // covered deck 16 floor under the gallery (teak) and ceiling lights
      B.add('teak', prism(polyCCW, Y16 + 0.02, Y16 + 0.05));
      for (let x = x0 + 2; x < x1; x += 4) {
        I.add('down', mat(x, Y17 - 0.37, s * 15.5, Math.PI / 2, 0, 0, 0.2, 0.2, 1));
        pois.lamps.push({ x, y: Y17 - 0.6, z: s * 17, intensity: 1.3, range: 10 });
        I.add('down', mat(x, Y17 - 0.37, s * 19.0, Math.PI / 2, 0, 0, 0.2, 0.2, 1));
      }
      // columns
      for (let x = x0 + 4; x < x1 - 2; x += 8) {
        B.tube('paint', new THREE.Vector3(x, Y16, s * (zi + 0.4)), new THREE.Vector3(x, Y17 - 0.3, s * (zi + 0.4)), 0.22);
        col.box(x, (Y16 + Y17) / 2, s * (zi + 0.4), 0.5, Y17 - Y16, 0.5);
      }
      // inner glass railing on the gallery (overlooking the pool) - gap for stairs
      glassRail(B, col, [[x0 + 0.2, s * zi], [STAIR16.x0, s * zi], [STAIR16.x0, s * (STAIR16.z1 + 0.2)], [STAIR16.x1, s * (STAIR16.z1 + 0.2)]], Y17);
      // outer glass railing along the sea edge, decks 16 and 17
      const edge = ptsOut.map(([x, z]) => [x, s * (z - 0.25)]);
      glassRail(B, col, edge, Y17);
      glassRail(B, col, edge, Y16);
      // Orange stairs deck 16 -> 17 at the forward end (photo 4).
      stairs(B, col, STAIR16.x0, Y16, STAIR16.x1, Y17, s * STAIR16.z0, s * STAIR16.z1, 'orangeStair');
    }
  }

  // --- aft deck 16 with the aft pool (photo 3) and lanterns ------------------------
  {
    const [x0, x1] = TOP.aftDeck;
    const poly = band(outline, x0, x1, 0.05, 1);
    B.add('teak', prism(poly, Y16 + 0.02, Y16 + 0.05));
    const ap = { x0: -150, x1: -134, z: 4.5 };
    B.boxMM('mosaic', ap.x0 - 2, Y16 + 0.05, -ap.z - 2, ap.x1 + 2, Y16 + 0.07, ap.z + 2);
    B.boxMM('mosaic', ap.x0 - 0.3, Y16, -ap.z - 0.3, ap.x1 + 0.3, Y16 + 0.3, -ap.z);
    B.boxMM('mosaic', ap.x0 - 0.3, Y16, ap.z, ap.x1 + 0.3, Y16 + 0.3, ap.z + 0.3);
    B.boxMM('mosaic', ap.x0 - 0.3, Y16, -ap.z, ap.x0, Y16 + 0.3, ap.z);
    B.boxMM('mosaic', ap.x1, Y16, -ap.z, ap.x1 + 0.3, Y16 + 0.3, ap.z);
    const water = new THREE.Mesh(new THREE.PlaneGeometry(ap.x1 - ap.x0, ap.z * 2), poolWaterMaterial());
    water.rotation.x = -Math.PI / 2;
    water.position.set((ap.x0 + ap.x1) / 2, Y16 + 0.16, 0);
    group.add(water);
    col.boxMM(ap.x0 - 0.3, Y16, -ap.z - 0.3, ap.x1 + 0.3, Y16 + 0.9, ap.z + 0.3);
    for (const [fx, fz, ry, sc] of [[-144, -2.4, 0.4, 0.8], [-140, 2.4, -0.4, 0.8], [-137, -1.6, 2.6, 0.75]]) {
      fish.push(mat(fx, Y16 - 0.3, fz, 0, ry, 0, sc, sc, sc));
      col.box(fx, Y16 + 2, fz, 1.6, 4, 1.6);
    }
    // All six fish as one instanced mesh.
    {
      const geo = mergeGeometries(fishGeometry().map((g) => {
        const n = g.index ? g.toNonIndexed() : g;
        for (const a of Object.keys(n.attributes)) if (a !== 'position' && a !== 'normal') n.deleteAttribute(a);
        return n;
      }));
      const mesh = new THREE.InstancedMesh(geo, fishMaterial(), fish.length);
      fish.forEach((m, i) => mesh.setMatrixAt(i, m));
      mesh.castShadow = mesh.receiveShadow = true;
      mesh.computeBoundingSphere();
      group.add(mesh);
    }
    // Railing around the stern edge with cube lanterns (photo 3).
    const edge = [];
    for (let x = x0; x <= x1 + 1e-6; x += 1) edge.push([x, halfWidthAt(outline, x) - 0.3]);
    const ring = [...edge.map(([x, z]) => [x, z]).reverse(), ...edge.map(([x, z]) => [x, -z])];
    glassRail(B, col, ring, Y16, { wood: true });
    for (let i = 2; i < ring.length - 2; i += 3) {
      const [x, z] = ring[i];
      const inward = z > 0 ? -0.5 : 0.5;
      I.add('lantern', mat(x + (x < -150 ? 0.5 : 0), Y16 + 0.25, z + (Math.abs(z) > 5 ? inward : 0), 0, 0, 0, 0.42, 0.5, 0.42));
      if (i % 6 === 2) pois.lamps.push({ x, y: Y16 + 0.6, z: z + (Math.abs(z) > 5 ? inward : 0), intensity: 0.7, range: 7 });
    }
    // Covered aft terrace under the deck 17 overhang, wicker tables (photo 8).
    B.boxMM('paint', -134, Y17 - 0.35, -14.6, x1, Y17, 14.6);
    for (let x = -132; x < -123; x += 2.6) {
      for (const z of [-15, -10, -5, 5, 10, 15]) {
        I.add('table', mat(x, Y16 + 0.37, z, 0, 0, 0));
        I.add('chair', mat(x - 0.7, Y16 + 0.25, z, 0, 0, 0));
        I.add('chair', mat(x + 0.7, Y16 + 0.25, z, 0, Math.PI, 0));
      }
      for (const z of [-17.5, -7.5, 7.5, 17.5]) I.add('down', mat(x, Y17 - 0.37, z, Math.PI / 2, 0, 0, 0.2, 0.2, 1));
    }
    // Stairs from the aft deck up to the sports deck (deck 18).
    for (const s of [1, -1]) stairs(B, col, -132.5, Y16, -122.3, Y18, s * 15.5, s * 17.3, 'steel');
  }

  // --- sports deck 18 on top of the mid block, around the funnel -------------------
  {
    const [x0, x1] = TOP.mid;
    const poly = band(outline, x0, x1, 0.3, 2);
    B.add('crewDeck', prism(poly, Y18, Y18 + 0.03));
    const edge = [];
    for (let x = x0; x <= x1 + 1e-6; x += 2) edge.push([x, halfWidthAt(outline, x) - 0.6]);
    for (const s of [1, -1]) glassRail(B, col, edge.map(([x, z]) => [x, s * z]), Y18);
    glassRail(B, col, [[x0 + 0.4, -halfWidthAt(outline, x0) + 0.6], [x0 + 0.4, -17.4]], Y18);
    glassRail(B, col, [[x0 + 0.4, 17.4], [x0 + 0.4, halfWidthAt(outline, x0) - 0.6]], Y18);
    // Forward end looks down onto the pool deck.
    glassRail(B, col, [[x1 - 0.4, -halfWidthAt(outline, x1) + 0.6], [x1 - 0.4, -16.5]], Y18);
    glassRail(B, col, [[x1 - 0.4, 16.5], [x1 - 0.4, halfWidthAt(outline, x1) - 0.6]], Y18);
    glassRail(B, col, [[x1 - 0.4, -11], [x1 - 0.4, 11]], Y18);
    // Stairs: gallery (17) -> sports deck (18) along the outer strip.
    for (const s of [1, -1]) stairs(B, col, -12.5, Y17, -22.4, Y18, s * 18.6, s * 20.3, 'orangeStair');
  }

  // --- funnel: twin lattice shells with stacks, compass rose ------------------------
  {
    const shape = new THREE.Shape();
    // Side elevation in (x, y), relative to deck 18: low forward, high aft.
    const yb = 0;
    shape.moveTo(-32, yb);
    shape.lineTo(-26, yb);
    shape.quadraticCurveTo(-30, 2.5, -40, 4.6);
    shape.quadraticCurveTo(-70, 10.5, -92, 16.2);
    shape.quadraticCurveTo(-101, 18.4, -105.5, 13.5);
    shape.quadraticCurveTo(-108.5, 8, -106, yb);
    shape.closePath();
    const geo = new THREE.ExtrudeGeometry(shape, { depth: 2.2, bevelEnabled: true, bevelThickness: 0.5, bevelSize: 0.5, bevelSegments: 3, curveSegments: 24 });
    geo.translate(0, 0, -1.1);
    const fmat = funnelMaterial();
    for (const zz of [-8.6, 8.6]) {
      const m = new THREE.Mesh(geo, fmat);
      m.position.set(0, Y18, zz);
      m.castShadow = m.receiveShadow = true;
      group.add(m);
      col.boxMM(-106, Y18, zz - 1.7, -28, Y18 + 12, zz + 1.7);
    }
    // Compass rose on both outer faces.
    const roseTex = canvasTexture(1024, 1024, (g, w, h) => { g.clearRect(0, 0, w, h); drawCompass(g, w / 2, h / 2, w * 0.46, '#f2f4f6', '#0d1b33'); });
    const roseMat = new THREE.MeshStandardNodeMaterial({ map: roseTex, transparent: true, alphaTest: 0.2, roughness: 0.4 });
    for (const zz of [-1, 1]) {
      const p = new THREE.Mesh(new THREE.CircleGeometry(4.6, 48), roseMat);
      p.position.set(-74, Y18 + 7.8, zz * (8.6 + 1.62));
      p.rotation.y = zz > 0 ? 0 : Math.PI;
      group.add(p);
    }
    // Exhaust stacks between the shells, raked aft (photos 5, 16).
    for (let i = 0; i < 6; i++) {
      const zz = -3.6 + (i % 3) * 3.6;
      const x = -98 + Math.floor(i / 3) * 3.0;
      B.tube('steel', new THREE.Vector3(x, Y18 + 6, zz), new THREE.Vector3(x - 2.8, Y18 + 19.8 - (i % 3 === 1 ? 0 : 0.8), zz), 0.62 - (i % 3 === 1 ? 0 : 0.1));
      B.tube('black', new THREE.Vector3(x - 2.75, Y18 + 19.6 - (i % 3 === 1 ? 0 : 0.8), zz), new THREE.Vector3(x - 2.85, Y18 + 20.0 - (i % 3 === 1 ? 0 : 0.8), zz), 0.5);
    }
    // Bridge between shells (casing) at the aft end.
    B.boxMM('navy', -104, Y18, -7.5, -86, Y18 + 10.5, 7.5);
    col.boxMM(-104, Y18, -7.5, -86, Y18 + 10.5, 7.5);
    pois.funnel = { x: -100, y: Y18 + 20, z: 0 };
  }

  // --- aqua park: yellow rope-course truss and water slides ------------------------
  {
    const x0 = -121, x1 = -106.5, w = 5.5, h = 7.2;
    const yb = Y18;
    const P = (x, y, z) => new THREE.Vector3(x, y, z);
    for (const z of [-w, w]) {
      for (let x = x0; x <= x1 + 1e-6; x += (x1 - x0) / 4) {
        B.tube('trussYellow', P(x, yb, z), P(x, yb + h, z), 0.16, true);
      }
      B.tube('trussYellow', P(x0, yb + h, z), P(x1, yb + h, z), 0.16, true);
      B.tube('trussYellow', P(x0, yb + h * 0.55, z), P(x1, yb + h * 0.55, z), 0.12, true);
      for (let x = x0; x < x1 - 0.1; x += (x1 - x0) / 4) {
        B.tube('trussYellow', P(x, yb + h * 0.55, z), P(x + (x1 - x0) / 4, yb + h, z), 0.09, true);
      }
    }
    for (let x = x0; x <= x1 + 1e-6; x += (x1 - x0) / 4) {
      B.tube('trussYellow', P(x, yb + h, -w), P(x, yb + h, w), 0.14, true);
      B.tube('trussYellow', P(x, yb + h * 0.55, -w), P(x, yb + h * 0.55, w), 0.1, true);
    }
    // Rope bridges and nets across the top bays.
    for (let i = 0; i < 4; i++) {
      const xa = x0 + i * (x1 - x0) / 4 + 0.6;
      B.tube('ropeYellow', P(xa, yb + h * 0.55 + 0.1, -w), P(xa + 2.4, yb + h * 0.55 + 0.1, w), 0.05, true);
      B.boxMM('steelDark', xa, yb + h * 0.55, -0.6, xa + 2.6, yb + h * 0.55 + 0.08, 0.6);
    }
    col.boxMM(x0 - 0.3, yb, -w - 0.3, x1 + 0.3, yb + h, w + 0.3);
    // Slides: two tubes spiralling from the truss down past the shells.
    const slide = (pts, matKey, r) => {
      const curve = new THREE.CatmullRomCurve3(pts.map(([x, y, z]) => new THREE.Vector3(x, y, z)));
      const g = new THREE.TubeGeometry(curve, 120, r, 14, false);
      B.add(matKey, g);
    };
    slide([[-112, yb + h, 3], [-110, yb + h - 1, 9], [-118, yb + 5, 13], [-127, yb + 3.2, 10], [-128, yb + 1.5, 2], [-124, yb - 1, -5], [-130, Y16 + 2.2, -9], [-140, Y16 + 0.9, -8]], 'slideGreen', 0.85);
    slide([[-116, yb + h, -3], [-121, yb + h - 1.5, -9], [-128, yb + 4, -13], [-131, yb + 1.5, -6], [-127, yb - 0.4, 3], [-133, Y16 + 2.1, 9], [-142, Y16 + 0.9, 8]], 'slideWhite', 0.8);
  }

  // --- forward top sun deck (deck 19) ------------------------------------------
  {
    const x0 = TOP.fwd[0], x1 = xFront - 18;
    const poly = band(outline, x0, x1, 2.6, 1.5);
    B.add('teak', prism(poly, Y19, Y19 + 0.03));
    const edge = [];
    for (let x = x0; x <= x1 + 1e-6; x += 1.5) edge.push([x, halfWidthAt(outline, x) - 2.8]);
    const ring = [...edge.map(([x, z]) => [x, z]), [x1, 0], ...edge.slice().reverse().map(([x, z]) => [x, -z])];
    glassRail(B, col, ring, Y19);
    // Glass observation lounge at the very front (photo 13: the glass dome).
    const lx0 = x1, lx1 = xFront;
    const lounge = band(outline, lx0 - 1, lx1, 2.6, 1);
    B.add('navyGlass', prism(lounge, Y19, Y19 + 3.4));
    B.add('paint', prism(band(outline, lx0 - 1.5, lx1 + 0.3, 2.2, 1), Y19 + 3.4, Y19 + 3.8));
    col.prism(lounge, Y19, Y19 + 3.8);
    // Stairs: gallery 17 -> deck 19 alongside the screen block.
    for (const s of [1, -1]) stairs(B, col, 52.8, Y17, 64.0, Y19, s * 12.9, s * 14.5, 'orangeStair');
  }

  // --- sun loungers ------------------------------------------------------------------
  {
    const put = (x, y, z, ry) => {
      I.add('loungerFrame', mat(x, y, z, 0, ry, 0));
      I.add('loungerPad', mat(x, y, z, 0, ry, 0));
    };
    // Pool deck rows (photo 4), both sides of the pool.
    for (const s of [1, -1]) {
      for (let x = -18; x < 42; x += 1.0) {
        if (x > pool.x0 - 3 && x < pool.x1 + 3) {
          put(x, Y16, s * 9.8, s > 0 ? Math.PI / 2 : -Math.PI / 2);
        }
      }
      for (let x = -16; x < 44; x += 1.05) put(x, Y16, s * 17.2, s > 0 ? Math.PI / 2 : -Math.PI / 2);
      for (let x = -18; x < 44; x += 1.05) put(x, Y17, s * 16.4, s > 0 ? -Math.PI / 2 : Math.PI / 2);
      // Top sun deck.
      for (let x = 68; x < 118; x += 1.05) put(x, Y19, s * 12.5, s > 0 ? Math.PI / 2 : -Math.PI / 2);
      // Aft deck.
      for (let x = -156; x < -136; x += 1.05) put(x, Y16, s * 9.5, s > 0 ? Math.PI / 2 : -Math.PI / 2);
    }
  }

  // --- build -------------------------------------------------------------------
  const extra = {
    ...M,
    slideGreen: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#3f9a4a'), roughness: 0.3 }),
    slideWhite: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#e9ecef'), roughness: 0.3 }),
    dome: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#f1f2f3'), roughness: 0.5 }),
    leaf: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#1f6650'), roughness: 0.6 }),
  };
  group.add(B.build(extra, { name: 'topdecks' }));

  const loungerFrame = new THREE.BoxGeometry(1.95, 0.08, 0.68);
  loungerFrame.translate(0, 0.32, 0);
  const legs = [];
  for (const dx of [-0.85, 0.85]) for (const dz of [-0.28, 0.28]) { const l = new THREE.BoxGeometry(0.05, 0.3, 0.05); l.translate(dx, 0.15, dz); legs.push(l); }
  const back = new THREE.BoxGeometry(0.62, 0.06, 0.66); back.rotateZ(-0.7); back.translate(-0.85, 0.55, 0);
  const frameGeo = mergeSimple([loungerFrame, back, ...legs]);
  const pad = new THREE.BoxGeometry(1.3, 0.06, 0.62); pad.translate(0.3, 0.39, 0);
  const padBack = new THREE.BoxGeometry(0.6, 0.05, 0.6); padBack.rotateZ(-0.7); padBack.translate(-0.83, 0.6, 0);
  const padGeo = mergeSimple([pad, padBack]);
  const table = mergeSimple([(() => { const g = new THREE.CylinderGeometry(0.45, 0.45, 0.04, 16); g.translate(0, 0.36, 0); return g; })(), (() => { const g = new THREE.CylinderGeometry(0.05, 0.05, 0.72, 6); return g; })()]);
  const chair = mergeSimple([(() => { const g = new THREE.BoxGeometry(0.55, 0.5, 0.55); return g; })(), (() => { const g = new THREE.BoxGeometry(0.1, 0.55, 0.55); g.translate(-0.25, 0.45, 0); return g; })()]);
  const lanternGeo = new THREE.BoxGeometry(1, 1, 1);
  const downGeo = new THREE.CircleGeometry(1, 16);
  const leafGeo = new THREE.CircleGeometry(1, 24);
  const domeGeo = new THREE.SphereGeometry(1, 24, 16);
  const navGeo = new THREE.SphereGeometry(1, 10, 8);
  group.add(I.build({
    loungerFrame: { geometry: frameGeo, material: 'lounger' },
    loungerPad: { geometry: padGeo, material: 'loungerPad' },
    table: { geometry: table, material: 'wicker' },
    chair: { geometry: chair, material: 'wicker' },
    lantern: { geometry: lanternGeo, material: 'lantern', castShadow: false },
    down: { geometry: downGeo, material: 'lampWarm', castShadow: false },
    leaf: { geometry: leafGeo, material: 'leaf', castShadow: false },
    dome: { geometry: domeGeo, material: 'dome' },
    navWhite: { geometry: navGeo, material: 'navWhite', castShadow: false },
  }, extra, { name: 'topProps' }));

  pois.spots.push(
    { id: 'pool', deck: 16, area: 'Pool deck', x: -20, y: Y16, z: 3, yaw: 0, pitch: 0.05, label: 'Deck 16 · Main pool' },
    { id: 'gallery', deck: 17, area: 'Gallery · starboard', x: 20, y: Y17, z: 18.5, yaw: Math.PI / 2 + 0.6, pitch: -0.15, label: 'Deck 17 · Pool gallery' },
    { id: 'sports', deck: 18, area: 'Sports deck · funnel', x: -40, y: Y18, z: 16.5, yaw: Math.PI, pitch: 0.12, label: 'Deck 18 · Sports deck' },
    { id: 'aftpool', deck: 16, area: 'Aft pool', x: -128, y: Y16, z: 2, yaw: Math.PI, pitch: 0.0, label: 'Deck 16 · Aft pool' },
    { id: 'topdeck', deck: 19, area: 'Top sun deck', x: 90, y: Y19, z: 14.5, yaw: Math.PI / 2, pitch: -0.25, label: 'Deck 19 · Top sun deck' },
  );
  pois.doors.push(
    { x: TOP.mid[1] + 0.6, y: Y16, z: 9, label: 'Lift lobby — deck 16' },
    { x: TOP.mid[1] + 0.6, y: Y16, z: -9, label: 'Lift lobby — deck 16' },
    { x: TOP.fwd[0] + 4, y: Y19, z: 6, label: 'Lift lobby — deck 19' },
    { x: TOP.aftDeck[1] - 0.6, y: Y16, z: 0, label: 'Lift lobby — deck 16 aft' },
  );
  return group;
}

/** Glass balustrade with stainless top rail along a polyline (plan points). */
function glassRail(B, col, pts, y, { h = 1.15, wood = false } = {}) {
  for (let i = 0; i < pts.length - 1; i++) {
    const [x0, z0] = pts[i], [x1, z1] = pts[i + 1];
    const len = Math.hypot(x1 - x0, z1 - z0);
    if (len < 0.05) continue;
    const ang = Math.atan2(z1 - z0, x1 - x0);
    const cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
    B.add('railGlass', new THREE.BoxGeometry(len, h - 0.12, 0.03), mat(cx, y + (h - 0.12) / 2 + 0.04, cz, 0, -ang, 0));
    B.add(wood ? 'woodRail' : 'stainless', new THREE.BoxGeometry(len + 0.02, 0.07, wood ? 0.12 : 0.06), mat(cx, y + h, cz, 0, -ang, 0));
    B.add('stainless', new THREE.BoxGeometry(0.05, h, 0.05), mat(x0, y + h / 2, z0, 0, 0, 0));
    col.box(cx, y + 0.7, cz, len, 1.4, 0.12, -ang);
  }
}

/** Straight stair flight from (x0, ya) to (x1, yb) between z0..z1. */
function stairs(B, col, x0, ya, x1, yb, z0, z1, matKey) {
  const n = Math.max(2, Math.round((yb - ya) / 0.19));
  const run = (x1 - x0) / n, rise = (yb - ya) / n;
  const zc = (z0 + z1) / 2, w = Math.abs(z1 - z0);
  for (let i = 0; i < n; i++) {
    const x = x0 + run * (i + 0.5);
    B.box(matKey, x, ya + rise * (i + 1) - 0.04, zc, Math.abs(run) + 0.02, 0.08, w);
  }
  // stringers and handrails
  for (const z of [z0, z1]) {
    B.tube(matKey, new THREE.Vector3(x0, ya + 0.1, z), new THREE.Vector3(x1, yb + 0.1, z), 0.06, true);
    B.tube('stainless', new THREE.Vector3(x0, ya + 1.0, z), new THREE.Vector3(x1, yb + 1.0, z), 0.03, true);
  }
  col.ramp(new THREE.Vector3(x0 - Math.sign(x1 - x0) * 0.3, ya, zc), new THREE.Vector3(x1 + Math.sign(x1 - x0) * 0.3, yb, zc), w);
}

function mergeSimple(list) {
  const geos = list.map((g) => { const n = g.index ? g.toNonIndexed() : g; for (const k of Object.keys(n.attributes)) if (k !== 'position' && k !== 'normal') n.deleteAttribute(k); return n; });
  let count = 0; for (const g of geos) count += g.attributes.position.count;
  const pos = new Float32Array(count * 3), nor = new Float32Array(count * 3);
  let o = 0;
  for (const g of geos) { pos.set(g.attributes.position.array, o * 3); nor.set(g.attributes.normal.array, o * 3); o += g.attributes.position.count; }
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  out.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
  return out;
}

export { deck16Outline, halfWidthAt };
