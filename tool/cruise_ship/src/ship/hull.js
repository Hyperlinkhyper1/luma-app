import * as THREE from 'three/webgpu';
import { hullHalf, hullTop, hullBottom, STERN_X, BOW_X } from './dims.js';
import { hullPaintMaterial } from './hullPaint.js';

// The hull: lofted from cross-sections sampled from dims.hullHalf() and
// closed by a flat transom. All its markings are in the paint shader
// (hullPaint.js), so nothing floats off the curved plating.

function stationsX() {
  const xs = [];
  for (let x = STERN_X; x < -146; x += 0.8) xs.push(x);
  for (let x = -146; x < 80; x += 2.0) xs.push(x);
  for (let x = 80; x < BOW_X + 0.01; x += 0.6) xs.push(Math.min(x, BOW_X));
  return xs;
}

function sectionYs(yb, yt) {
  // Dense through the bilge and around the waterline.
  const ys = [];
  const push = (y) => { if (y > yb + 1e-3 && y < yt - 1e-3) ys.push(y); };
  ys.push(yb + 0.001);
  for (let i = 1; i <= 8; i++) push(yb + 2.8 * (1 - Math.cos((i / 8) * Math.PI / 2)));
  for (let y = Math.ceil(yb + 3); y < -1.5; y += 1.5) push(y);
  for (let y = -1.5; y <= 1.5; y += 0.25) push(y);
  for (let y = 2; y < yt; y += 1.0) push(y);
  ys.push(yt);
  return [...new Set(ys.map((v) => +v.toFixed(4)))].sort((a, b) => a - b);
}

/** Lofted hull shell (both sides), indexed, with world-scale UVs. */
function buildShell() {
  const xs = stationsX();
  const K = 46;   // points per side per section (resampled to a fixed count)
  const pos = [], uvs = [], idx = [];
  const sections = [];
  for (const x of xs) {
    const yb = hullBottom(x);
    const yt = hullTop(x);
    const ys = sectionYs(yb, yt);
    // Resample to K points (keeps the topology regular along the hull).
    const pts = [];
    for (let k = 0; k < K; k++) {
      const f = k / (K - 1);
      const fi = f * (ys.length - 1);
      const i0 = Math.floor(fi), i1 = Math.min(ys.length - 1, i0 + 1);
      const y = ys[i0] + (ys[i1] - ys[i0]) * (fi - i0);
      pts.push([hullHalf(x, y), y]);
    }
    sections.push({ x, pts });
  }
  // Starboard and port as two strips, plus the flat bottom between them.
  for (const side of [1, -1]) {
    const base = pos.length / 3;
    for (const s of sections) {
      for (const [z, y] of s.pts) {
        pos.push(s.x, y, side * z);
        uvs.push(s.x / 10, y / 10);
      }
    }
    for (let i = 0; i < sections.length - 1; i++) {
      for (let k = 0; k < K - 1; k++) {
        const a = base + i * K + k, b = a + 1, c = a + K, d = c + 1;
        if (side > 0) idx.push(a, c, b, b, c, d);
        else idx.push(a, b, c, b, d, c);
      }
    }
  }
  // Bottom: connect the lowest starboard and port points.
  const nS = sections.length;
  const portBase = nS * K;
  for (let i = 0; i < nS - 1; i++) {
    const a = i * K, b = (i + 1) * K, c = portBase + i * K, d = portBase + (i + 1) * K;
    idx.push(a, c, b, b, c, d);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  g.setIndex(idx);
  g.computeVertexNormals();
  return { geometry: g, sections, K };
}

/** Flat transom closing the stern, from the last section. */
function buildTransom(section) {
  const shape = new THREE.Shape();
  const pts = section.pts.filter(([z]) => z > 0.01);
  if (pts.length < 2) return null;
  shape.moveTo(-pts[0][0], pts[0][1]);
  for (const [z, y] of pts) shape.lineTo(z, y);
  for (let i = pts.length - 1; i >= 0; i--) shape.lineTo(-pts[i][0], pts[i][1]);
  shape.closePath();
  const g = new THREE.ShapeGeometry(shape);
  // Shape lies in XY (x = ship z); turn it to face aft (-x).
  g.rotateY(-Math.PI / 2);
  g.translate(section.x, 0, 0);
  return g;
}

export function buildHull() {
  const group = new THREE.Group();
  group.name = 'hull';
  const paint = hullPaintMaterial();
  const { geometry: shell, sections } = buildShell();
  const shellMesh = new THREE.Mesh(shell, paint);
  shellMesh.castShadow = shellMesh.receiveShadow = true;
  shellMesh.name = 'hull:shell';
  group.add(shellMesh);
  const tr = buildTransom(sections[0]);
  if (tr) {
    const tm = new THREE.Mesh(tr, paint);
    tm.castShadow = tm.receiveShadow = true;
    tm.name = 'hull:transom';
    group.add(tm);
  }
  return group;
}
