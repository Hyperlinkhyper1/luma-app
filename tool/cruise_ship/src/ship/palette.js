import * as THREE from 'three/webgpu';
import { Fn, attribute, float, mix, saturate, normalWorld, vec3 } from 'three/tsl';
import { shipU } from './materials.js';

// One material for every plain-coloured surface (steel, rails, rubber,
// mosaic, cranes, containers...). Colour, roughness and metalness ride on
// vertex attributes, so a whole builder's worth of trim merges into a
// single draw call instead of one per material: the ship has thousands of
// parts and the CPU cost of draw calls, times four shadow cascades, was the
// frame-rate limit.

export const PALETTE = {
  paintShade: ['#d3d7dc', 0.55, 0.0],
  steel: ['#c9ced3', 0.38, 0.25],
  steelDark: ['#5b6168', 0.45, 0.3],
  stainless: ['#c8ccd0', 0.22, 1.0],
  black: ['#141618', 0.55, 0.0],
  rubber: ['#1b1c1e', 0.9, 0.0],
  woodRail: ['#9a4f1d', 0.32, 0.0],
  ropeYellow: ['#d9b21c', 0.6, 0.0],
  trussYellow: ['#e0b11a', 0.45, 0.2],
  orangeStair: ['#d77a2b', 0.5, 0.0],
  raftWhite: ['#e6e8e6', 0.55, 0.0],
  mosaic: ['#e6eef0', 0.35, 0.0],
  navy: ['#0d1b33', 0.38, 0.15],
  navyMatte: ['#0f1d36', 0.6, 0.0],
  boatWhite: ['#e9ecee', 0.35, 0.0],
  slideGreen: ['#3f9a4a', 0.3, 0.0],
  slideWhite: ['#e9ecef', 0.3, 0.0],
  dome: ['#f1f2f3', 0.5, 0.0],
  leaf: ['#1f6650', 0.6, 0.0],
  roofMetal: ['#bdb6a8', 0.5, 0.5],
  termGlass: ['#1d2a33', 0.08, 0.3],
  craneYellow: ['#e3a91c', 0.5, 0.3],
  craneBlue: ['#27548d', 0.5, 0.3],
  cshipHull: ['#1f3f6c', 0.5, 0.0],
  cshipRed: ['#6d1d18', 0.6, 0.0],
  rope: ['#d8d0bb', 0.9, 0.0],
  domeGold: ['#c79d4a', 0.4, 0.6],
  hills: ['#7d7a6a', 1.0, 0.0],
  palmTrunk: ['#6b5640', 0.9, 0.0],
  // Container ship and the distant cruise ship.
  hull: ['#1b1d24', 0.6, 0.0],
  white: ['#e6e6e2', 0.6, 0.0],
  dark: ['#202833', 0.3, 0.0],
  cRed: ['#7c2a22', 0.7, 0.0],
  cBlue: ['#25456e', 0.7, 0.0],
  cGrey: ['#8a8c88', 0.7, 0.0],
  cOrange: ['#b8692b', 0.7, 0.0],
  cGreen: ['#3d5a44', 0.7, 0.0],
};

const LIN = {};
for (const [k, [hex, r, m]] of Object.entries(PALETTE)) {
  const c = new THREE.Color(hex);
  LIN[k] = [c.r, c.g, c.b, r, m];
}

/** Add the palette attributes for `key` to geometry g (in place). */
export function paint(g, key) {
  const p = LIN[key];
  const n = g.attributes.position.count;
  const col = new Float32Array(n * 3), prm = new Float32Array(n * 2);
  for (let i = 0; i < n; i++) {
    col[i * 3] = p[0]; col[i * 3 + 1] = p[1]; col[i * 3 + 2] = p[2];
    prm[i * 2] = p[3]; prm[i * 2 + 1] = p[4];
  }
  g.setAttribute('pcolor', new THREE.BufferAttribute(col, 3));
  g.setAttribute('prm', new THREE.BufferAttribute(prm, 2));
  return g;
}

let shared = null;
export function paletteMaterial() {
  if (shared) return shared;
  const m = new THREE.MeshStandardNodeMaterial();
  const up = saturate(normalWorld.y);
  m.colorNode = Fn(() => attribute('pcolor', 'vec3').mul(float(1.0).sub(shipU.wet.mul(up).mul(0.35))))();
  m.roughnessNode = Fn(() => mix(attribute('prm', 'vec2').x, float(0.1), shipU.wet.mul(up).mul(0.8)))();
  m.metalnessNode = Fn(() => attribute('prm', 'vec2').y)();
  shared = m;
  return m;
}
