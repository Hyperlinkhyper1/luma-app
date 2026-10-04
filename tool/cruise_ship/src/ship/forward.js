import * as THREE from 'three/webgpu';
import {
  Fn, vec2, vec3, float, abs, max, min, floor, fract, sin, dot, mix, step, smoothstep, select, sign,
  positionView, normalView, faceDirection, clamp, length, asin,
} from 'three/tsl';
import { deckY, DECK_H, BRIDGE_DECK, BALCONY_D, BOW_LEN, HULL_HALF_TOP, wallZ, railZ, frontX } from './dims.js';
import { prism } from './kit.js';
import { shipPos, shipU } from './materials.js';

// The forward superstructure, after photos of MSC Virtuosa from ahead
// (Greenock and Geiranger, 2021): the front of the cabin decks is a white
// wall of windows - not balconies - curving round into the balcony stacks
// on the sides. Bottom to top: tall suite windows (decks 9-10), wide
// windows over the struts that carry the bridge wings (11), the bridge with
// its slanted, full-width window band and wings past the hull under a thick
// white visor (12), a deck of mullioned glass (13), big two-deck picture
// windows in the middle of decks 14-15, and on top the dark lounge band.

/** Ellipse parameter where the front wall starts (balconies before it). */
export const FRONT_A0 = 0.5;

const xStart = (n) => frontX(n) - BOW_LEN;

/** True where a point on deck n's bow arc belongs to the windowed front wall. */
export function isFrontWall(n, x) {
  const s = (x - xStart(n)) / BOW_LEN;
  return s > Math.sin(FRONT_A0) - 0.02;
}

/** Point on deck n's bow ellipse at parameter a, pushed outward by `off`. */
function bowPoint(n, a, off) {
  return [xStart(n) + Math.sin(a) * (BOW_LEN + off), Math.cos(a) * (wallZ(n) + off)];
}

/** Closed crescent between the wall line and the balcony-front line, port to starboard. */
function frontShell(n, inner = -0.25, outer = BALCONY_D, N = 28) {
  const out = [], inn = [];
  for (let i = 0; i <= N; i++) {
    const a = FRONT_A0 + (i / N) * (Math.PI / 2 - FRONT_A0);
    out.push(bowPoint(n, a, outer));
    inn.push(bowPoint(n, a, inner));
  }
  const outerLoop = [...out, ...out.slice(0, -1).reverse().map(([x, z]) => [x, -z])];
  const innerLoop = [...inn, ...inn.slice(0, -1).reverse().map(([x, z]) => [x, -z])];
  return [...outerLoop, ...innerLoop.reverse()];
}

// --- facade shader ------------------------------------------------------------------
const hash21 = (p) => fract(sin(dot(p, vec2(127.1, 311.7))).mul(43758.5453));
const sdBox = (q, b) => {
  const d = abs(q).sub(b);
  return length(max(d, 0.0)).add(min(max(d.x, d.y), 0.0));
};

/** frontX(n) in the shader (deck index as a float node), from the dims table. */
const frontXNode = (n) => {
  let v = float(frontX(19));
  for (let k = 18; k >= 9; k--) v = select(n.lessThan(k + 0.5), float(frontX(k)), v);
  return v;
};

export function frontFacadeMaterial() {
  const m = new THREE.MeshStandardNodeMaterial();
  const p = shipPos();
  const x = p.x, y = p.y, z = p.z;
  const deck = floor(y.sub(deckY(7)).div(DECK_H)).add(7);
  const fy = y.sub(deckY(7)).sub(deck.sub(7).mul(DECK_H));          // metres above this deck's floor
  // Arc length round the bow from the centreline, so windows keep their
  // width as the wall turns toward the side.
  const a = asin(clamp(x.sub(frontXNode(deck).sub(BOW_LEN)).div(BOW_LEN + BALCONY_D), 0.0, 1.0));
  const s = sign(z).mul(float(Math.PI / 2).sub(a).mul(22.5));
  const S = abs(s);

  // Window field for each deck kind: signed distance, < 0 in glass.
  const cellD = (pitch, w, y0, y1) => {
    const lx = fract(s.div(pitch)).sub(0.5).mul(pitch);
    return sdBox(vec2(lx, fy.sub((y0 + y1) / 2)), vec2(w / 2, (y1 - y0) / 2));
  };
  const tall = cellD(2.55, 2.05, 0.5, 2.55);                   // decks 9-10: suites
  const wide = cellD(2.55, 2.3, 0.75, 2.45);                   // deck 11
  // Deck 13: one continuous band of glass split by slim white mullions.
  const mullDist = float(0.5).sub(abs(fract(s.div(1.3)).sub(0.5))).mul(1.3);
  const band13 = max(max(fy.sub(2.62), float(0.42).sub(fy)), float(0.06).sub(mullDist));
  // Decks 15-16: big picture windows in the middle, smaller ones on the
  // flanks; above, a plain row.
  const yy = fy;
  const pic = max(sdBox(vec2(fract(s.div(2.3)).sub(0.5).mul(2.3), yy.sub(DECK_H * 0.5 + 0.05)), vec2(1.05, DECK_H * 0.5 - 0.3)), S.sub(10.8));
  const flank = max(cellD(2.55, 2.25, 0.6, 2.45), float(10.8).sub(S));
  const row16 = cellD(2.4, 2.0, 0.8, 2.3);
  const d = select(deck.lessThan(10.5), tall,
    select(deck.lessThan(12.5), wide,
      select(deck.lessThan(14.5), band13,
        select(deck.lessThan(16.5), min(pic, flank), row16))));
  const glassIn = smoothstep(0.012, -0.012, d);
  const frame = smoothstep(0.08, 0.0, abs(d.add(0.04))).mul(float(1.0).sub(glassIn));
  // Slab edges at every floor: a slightly proud band.
  const slab = smoothstep(0.32, 0.28, fy).max(smoothstep(DECK_H - 0.05, DECK_H - 0.02, fy));

  m.colorNode = Fn(() => {
    const white = vec3(0.84, 0.85, 0.86);
    let c = mix(white, white.mul(0.92), slab.mul(0.4));
    c = mix(c, vec3(0.6, 0.62, 0.64), frame.mul(0.5));
    // Glass: dark, with a hint of blinds/curtains in some suites by day.
    const cell = floor(vec2(s.div(2.55), deck));
    const curtain = step(0.72, hash21(cell));
    const glass = mix(vec3(0.012, 0.018, 0.026), vec3(0.09, 0.085, 0.075), curtain.mul(0.35));
    return mix(c, glass, glassIn);
  })();
  m.roughnessNode = mix(float(0.36), float(0.04), glassIn);
  m.normalNode = Fn(() => {
    const h = glassIn.mul(-0.07).add(frame.mul(0.01)).add(slab.mul(0.03));
    const dpdx = positionView.dFdx(), dpdy = positionView.dFdy();
    const n = normalView;
    const r1 = dpdy.cross(n), r2 = n.cross(dpdx);
    const det = dpdx.dot(r1).mul(faceDirection);
    const grad = det.sign().mul(h.dFdx().mul(r1).add(h.dFdy().mul(r2)));
    return det.abs().mul(n).sub(grad).normalize();
  })();
  m.emissiveNode = Fn(() => {
    const cell = floor(vec2(s.div(2.55), deck));
    const lit = step(0.45, hash21(cell.add(3.7)));
    return vec3(1.0, 0.8, 0.55).mul(lit).mul(glassIn).mul(shipU.night).mul(shipU.lightBoost).mul(0.07);
  })();
  return m;
}

// --- geometry -------------------------------------------------------------------------

/**
 * Front walls of the cabin decks and the bridge. Adds to builder B (keys
 * 'frontFacade', 'navyGlass', 'paint', 'paintShade') and the collider.
 */
export function buildForward(B, col, cabinDecks) {
  for (const n of cabinDecks) {
    if (n === BRIDGE_DECK) continue;
    B.add('frontFacade', prism(frontShell(n), deckY(n), deckY(n + 1)));
  }

  // --- bridge ---------------------------------------------------------------
  const n = BRIDGE_DECK;
  const y0 = deckY(n), y1 = deckY(n + 1);
  const XB = frontX(n) + 1.4;      // centre of the bridge front
  const W = HULL_HALF_TOP + 2.6;   // wing tips, well outside the hull
  const DEPTH = 12;                // bridge house depth
  const front = (zz, off = 0) => XB + off - 5.2 * Math.pow(zz / W, 2);
  const curve = (off, zMax, N = 40) => {
    const pts = [];
    for (let i = 0; i <= N; i++) {
      const zz = -zMax + (2 * zMax * i) / N;
      pts.push([front(zz, off), zz]);
    }
    return pts;
  };
  const slabPoly = (off, zMax) => {
    const c = curve(off, zMax);
    return [...c, [front(zMax, 0) - DEPTH, zMax], [front(-zMax, 0) - DEPTH, -zMax]];
  };
  // Floor slab, the apron under the windows, the house behind.
  B.add('paint', prism(slabPoly(0.35, W + 0.2), y0 - 0.32, y0 + 0.02));
  B.add('paint', prism(slabPoly(-0.75, W - 0.2), y0 + 0.02, y0 + 0.7));
  B.add('paint', prism(slabPoly(-1.6, W - 0.6), y0 + 0.7, y1 - 0.3));
  // The slanted window band: a ruled surface, foot set back 0.7 m.
  {
    const N = 64;
    const pos = [], idx = [];
    const yb = y0 + 0.7, yt = y1 - 0.3;
    for (let i = 0; i <= N; i++) {
      const zz = -W + 0.25 + (2 * (W - 0.25) * i) / N;
      pos.push(front(zz, -0.75), yb, zz, front(zz, -0.05), yt, zz);
    }
    for (let i = 0; i < N; i++) {
      const a = i * 2, b = a + 1, c = a + 2, d = a + 3;
      idx.push(a, c, b, b, c, d);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setIndex(idx);
    g.computeVertexNormals();
    B.add('navyGlass', g);
    // Glazed wing ends.
    for (const side of [1, -1]) {
      const zz = side * (W - 0.2);
      B.boxMM('navyGlass', front(zz, 0) - DEPTH + 1, yb, zz - 0.06, front(zz, -0.4), yt, zz + 0.06);
    }
  }
  // The visor: a thick white slab overhanging the windows and the wings.
  B.add('paint', prism(slabPoly(0.9, W + 0.5), y1 - 0.3, y1 + 0.6));
  B.add('paintShade', prism(slabPoly(0.9, W + 0.5), y1 - 0.35, y1 - 0.3));
  // Struts carrying the wings out over the sea, down to the deck 11 wall.
  for (const side of [1, -1]) {
    for (const dx of [-11, -6.5, -2]) {
      const zz = side * (W - 1.0);
      const xx = front(zz, dx);
      B.tube('paint', new THREE.Vector3(xx, y0 - 0.3, zz), new THREE.Vector3(xx - 1.2, y0 - 3.6, side * (railZ(BRIDGE_DECK - 1) - 0.2)), 0.16, true);
    }
  }
  col?.prism(slabPoly(0.35, W + 0.2), y0 - 0.32, y1 + 0.45);
}
