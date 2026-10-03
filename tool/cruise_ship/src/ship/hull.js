import * as THREE from 'three/webgpu';
import { Fn, vec3, float, mix, smoothstep, saturate, abs, mx_noise_float, normalWorld, step, floor, fract, sin, dot } from 'three/tsl';
import { hullHalf, hullTop, hullBottom, STERN_X, BOW_X, deckY } from './dims.js';
import { Builder, Instancer, mat } from './kit.js';
import { shipPos, shipU, canvasTexture, drawCompass } from './materials.js';

// The hull: lofted from cross-sections sampled from dims.hullHalf(), painted
// by height (antifouling red, black boot-top, white topsides), with three
// rows of portholes, navy glazing for the public rooms on decks 5-6, the
// mooring openings at the bow, and the name and emblems.

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

/**
 * A strip of surface that hugs the hull side between x0..x1 and y0..y1,
 * offset outward by `off`, with UVs running 0..1 (u reading bow-ward on
 * starboard and stern-ward on port so lettering reads correctly).
 */
export function hullStrip(x0, x1, y0, y1, side, off = 0.04, nx = 40, ny = 6) {
  const pos = [], uv = [], idx = [];
  for (let j = 0; j <= ny; j++) {
    const v = j / ny, y = y0 + (y1 - y0) * v;
    for (let i = 0; i <= nx; i++) {
      const u = i / nx, x = x0 + (x1 - x0) * u;
      const z = hullHalf(x, y) + off;
      pos.push(x, y, side * z);
      uv.push(side > 0 ? u : 1 - u, v);
    }
  }
  for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
    const a = j * (nx + 1) + i, b = a + 1, c = a + nx + 1, d = c + 1;
    if (side > 0) idx.push(a, b, c, b, d, c); else idx.push(a, c, b, b, c, d);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.setIndex(idx);
  g.computeVertexNormals();
  return g;
}

/** Outward hull normal (plan view) at x, y for one side. */
function hullNormal(x, y, side) {
  const e = 0.25;
  const dz = (hullHalf(x + e, y) - hullHalf(x - e, y)) / (2 * e);
  const n = new THREE.Vector3(-dz, 0, 1).normalize();
  n.z *= side;
  return n;
}

function textTexture(lines, { w = 2048, h = 256, color = '#0d1b33', font = 'Georgia, "Times New Roman", serif', weight = 600, italic = false, size = 0.62, emblem = false } = {}) {
  return canvasTexture(w, h, (g) => {
    g.clearRect(0, 0, w, h);
    g.fillStyle = color;
    g.textBaseline = 'middle';
    const n = lines.length;
    lines.forEach((line, i) => {
      const fs = (h / n) * size * (i === 0 ? 1 : 0.62);
      g.font = `${italic ? 'italic ' : ''}${weight} ${fs}px ${font}`;
      g.textAlign = 'center';
      g.fillText(line, w / 2 + (emblem ? h * 0.35 : 0), (h / n) * (i + 0.5));
    });
    if (emblem) drawCompass(g, h * 0.62, h / 2, h * 0.42, color);
  });
}

export function buildHull(M) {
  const group = new THREE.Group();
  group.name = 'hull';

  // --- painted shell ----------------------------------------------------------
  const paint = new THREE.MeshStandardNodeMaterial({ roughness: 0.45 });
  paint.colorNode = Fn(() => {
    const p = shipPos();
    const red = vec3(0.42, 0.055, 0.04);
    const boot = vec3(0.012, 0.013, 0.015);
    const white = vec3(0.79, 0.81, 0.83);
    const broad = mx_noise_float(p.mul(0.03)).mul(0.03);
    // Horizontal plate seams and long rust-free streaks on the topsides.
    const streak = mx_noise_float(vec3(p.x.mul(1.1), p.y.mul(0.08), p.z.mul(1.1))).mul(0.035);
    const w = white.mul(float(1.0).add(broad).sub(streak.abs()));
    const c = mix(red, boot, step(-0.45, p.y));
    return mix(c, w, step(0.6, p.y));
  })();
  paint.roughnessNode = Fn(() => {
    const p = shipPos();
    return mix(float(0.6), float(0.4), step(0.6, p.y));
  })();
  const { geometry: shell, sections } = buildShell();
  const shellMesh = new THREE.Mesh(shell, paint);
  shellMesh.castShadow = shellMesh.receiveShadow = true;
  shellMesh.name = 'hull:shell';
  group.add(shellMesh);
  const tr = buildTransom(sections[0]);
  if (tr) {
    const tm = new THREE.Mesh(tr, paint);
    tm.castShadow = tm.receiveShadow = true;
    group.add(tm);
  }

  // --- portholes ---------------------------------------------------------------
  const inst = new Instancer();
  const rows = [
    { y: 6.35, r: 0.3 },
    { y: 9.3, r: 0.47 },
    { y: 12.25, r: 0.47 },
  ];
  const skip = (x, row) =>
    (x > -128 && x < -92 && row < 2) ||        // big MSC lettering aft
    (x > -32 && x < -18) || (x > 62 && x < 74) || // shell doors
    (x > 132);                                  // bow: mooring deck
  for (const side of [1, -1]) {
    rows.forEach((row, ri) => {
      for (let x = -148; x < 140; x += 3.0) {
        const xx = x + (ri === 0 ? 1.5 : 0);
        if (skip(xx, ri)) continue;
        const n = hullNormal(xx, row.y, side);
        const z = side * hullHalf(xx, row.y);
        const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 0, 1), n);
        const m = new THREE.Matrix4().compose(new THREE.Vector3(xx, row.y, z).addScaledVector(n, 0.02), q, new THREE.Vector3(row.r, row.r, 1));
        inst.add('rim', m);
        inst.add('glass', m);
      }
    });
  }
  const rimGeo = new THREE.RingGeometry(0.82, 1.0, 24);
  const glassGeo = new THREE.CircleGeometry(0.84, 24);
  glassGeo.translate(0, 0, -0.01);
  const pmat = new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#2a3846'), roughness: 0.05, metalness: 0.2 });
  // Crew cabins: some portholes lit at night, most dark.
  pmat.emissiveNode = Fn(() => {
    const p = shipPos();
    const cell = floor(vec3(p.x.div(3.0).add(0.5), p.y.div(2.9), p.z.sign()));
    const h = fract(sin(dot(cell, vec3(127.1, 311.7, 74.7))).mul(43758.5453));
    return vec3(1.0, 0.82, 0.58).mul(step(0.72, h)).mul(shipU.night).mul(shipU.lightBoost).mul(0.035);
  })();
  const mats = { rim: M.steel, glass: pmat };
  group.add(inst.build({
    rim: { geometry: rimGeo, material: 'rim', castShadow: false },
    glass: { geometry: glassGeo, material: 'glass', castShadow: false },
  }, mats, { name: 'portholes' }));

  // --- navy glazing (decks 5-6 public rooms) ------------------------------------
  const b = new Builder();
  const glassRuns = [[-150, -112], [-30, 20], [92, 120]];
  for (const side of [1, -1]) {
    for (const [x0, x1] of glassRuns) b.add('navyGlass', hullStrip(x0, x1, deckY(5) + 0.15, deckY(7) - 0.35, side, 0.05, 60, 4));
    // Shell doors: recessed dark outlines (closed).
    for (const x of [-25, 68]) b.add('steelDark', hullStrip(x - 1.6, x + 1.6, deckY(3) + 0.2, deckY(3) + 2.5, side, 0.03, 4, 2));
  }
  // Boot-top highlight line and a thin white sheer stripe at the deck edge.
  group.add(b.build(M, { name: 'hullGlass', castShadow: false }));

  // --- lettering ---------------------------------------------------------------
  const nameTex = textTexture(['MSC VIRTUOSA'], { w: 2048, h: 200, size: 0.78, weight: 600, italic: true });
  const nameMat = new THREE.MeshStandardNodeMaterial({ map: nameTex, transparent: true, roughness: 0.45, alphaTest: 0.3 });
  for (const side of [1, -1]) {
    const g = hullStrip(122, 146, 21.2, 23.7, side, 0.06, 40, 4);
    const m = new THREE.Mesh(g, nameMat);
    group.add(m);
  }
  // Big MSC lettering with the compass rose, aft on the hull.
  const bigTex = canvasTexture(2048, 512, (g, w, h) => {
    g.clearRect(0, 0, w, h);
    drawCompass(g, h * 0.52, h / 2, h * 0.46, '#0d1b33');
    g.fillStyle = '#0d1b33';
    g.font = `700 ${h * 0.78}px Georgia, 'Times New Roman', serif`;
    g.textBaseline = 'middle'; g.textAlign = 'left';
    g.fillText('MSC', h * 1.12, h * 0.55);
  });
  const bigMat = new THREE.MeshStandardNodeMaterial({ map: bigTex, transparent: true, roughness: 0.4, alphaTest: 0.3 });
  for (const side of [1, -1]) {
    group.add(new THREE.Mesh(hullStrip(-127, -95, 3.6, 11.6, side, 0.06, 30, 6), bigMat));
  }
  // Bow emblem near the stem.
  const embTex = canvasTexture(512, 512, (g, w, h) => {
    g.clearRect(0, 0, w, h);
    g.fillStyle = '#0d1b33';
    g.font = `italic 700 ${h * 0.42}px Georgia, serif`;
    g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText('m', w / 2, h * 0.33);
    g.fillText('sc', w / 2, h * 0.68);
  });
  const embMat = new THREE.MeshStandardNodeMaterial({ map: embTex, transparent: true, roughness: 0.4, alphaTest: 0.3 });
  for (const side of [1, -1]) group.add(new THREE.Mesh(hullStrip(152.5, 156.8, 22.6, 26.2, side, 0.06, 8, 6), embMat));
  // Stern: name and port of registry on the transom.
  const sternTex = textTexture(['MSC VIRTUOSA', 'VALLETTA'], { w: 2048, h: 400, size: 0.72, italic: true });
  const sternMat = new THREE.MeshStandardNodeMaterial({ map: sternTex, transparent: true, roughness: 0.4, alphaTest: 0.3 });
  const sternPlane = new THREE.Mesh(new THREE.PlaneGeometry(16, 3.1), sternMat);
  sternPlane.rotation.y = -Math.PI / 2;
  sternPlane.position.set(STERN_X - 0.06, 15.4, 0);
  group.add(sternPlane);
  // Bow thruster and draft marks.
  const thrTex = canvasTexture(512, 256, (g, w, h) => {
    g.clearRect(0, 0, w, h);
    g.strokeStyle = '#111'; g.lineWidth = 14;
    for (const cx of [w * 0.25, w * 0.75]) {
      g.beginPath(); g.arc(cx, h / 2, h * 0.36, 0, Math.PI * 2); g.stroke();
      g.beginPath(); g.moveTo(cx - h * 0.25, h / 2 - h * 0.25); g.lineTo(cx + h * 0.25, h / 2 + h * 0.25);
      g.moveTo(cx + h * 0.25, h / 2 - h * 0.25); g.lineTo(cx - h * 0.25, h / 2 + h * 0.25); g.stroke();
    }
  });
  const thrMat = new THREE.MeshStandardNodeMaterial({ map: thrTex, transparent: true, roughness: 0.5, alphaTest: 0.3 });
  for (const side of [1, -1]) group.add(new THREE.Mesh(hullStrip(140, 146, 2.6, 4.6, side, 0.04, 8, 2), thrMat));

  // Mooring openings at the bow (photo 18): dark rounded windows in the hull.
  const moorTex = canvasTexture(1024, 256, (g, w, h) => {
    g.clearRect(0, 0, w, h);
    g.fillStyle = '#1c2026';
    const n = 4, pw = w / n;
    for (let i = 0; i < n; i++) {
      const x = i * pw + pw * 0.12, y = h * 0.12, ww = pw * 0.76, hh = h * 0.76, r = hh * 0.3;
      g.beginPath();
      g.moveTo(x + r, y); g.arcTo(x + ww, y, x + ww, y + hh, r); g.arcTo(x + ww, y + hh, x, y + hh, r);
      g.arcTo(x, y + hh, x, y, r); g.arcTo(x, y, x + ww, y, r); g.closePath(); g.fill();
    }
  });
  const moorMat = new THREE.MeshStandardNodeMaterial({ map: moorTex, transparent: true, roughness: 0.7, alphaTest: 0.3 });
  for (const side of [1, -1]) group.add(new THREE.Mesh(hullStrip(134, 152, 16.6, 19.4, side, 0.05, 24, 3), moorMat));

  return group;
}
