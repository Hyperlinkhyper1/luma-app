// @ts-nocheck
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";

export function mountPagoda(container) {

const PAL = {
  vermillion: 0xC73E1D,
  gold: 0xE8B86D,
  teak: 0x4A2C1A,
  jade: 0x2D6A4F,
  jade2: 0x40916C,
  sakura: 0xFFB7C5,
  sakura2: 0xFF8FAB,
  sakura3: 0xFFE5EC,
  stone: 0x9AA0A6,
  pond: 0x7ED6DF,
  moss: 0x606C38,
  dirt: 0x5C4033,
  rock: 0x5A6270,
  rock2: 0x3E4652,
  cream: 0xF3E6C8,
  pine: 0x1B4332,
  maple: 0xC44536,
  maple2: 0xD97706,
  willow: 0x74A57F,
  bamboo: 0x52796F,
  waterDark: 0x2A9D8F,
  warm: 0xFFD6A5,
  white: 0xE8EEF2,
};

function hash(x, z) {
  const n = Math.sin(x * 127.1 + z * 311.7) * 43758.5453;
  return n - Math.floor(n);
}
function noise(x, z) {
  const xi = Math.floor(x), zi = Math.floor(z);
  const xf = x - xi, zf = z - zi;
  const u = xf * xf * (3 - 2 * xf);
  const v = zf * zf * (3 - 2 * zf);
  const a = hash(xi, zi), b = hash(xi + 1, zi), c = hash(xi, zi + 1), d = hash(xi + 1, zi + 1);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
function fbm(x, z) {
  return noise(x, z) * 0.55 + noise(x * 2.1, z * 2.1) * 0.28 + noise(x * 4.3, z * 4.3) * 0.17;
}

const occ = new Map();
const buckets = new Map();
let voxelCount = 0;

function colKey(hex) { return hex >>> 0; }
function vox(x, y, z, hex, ao = 1) {
  const k = x + "," + y + "," + z;
  if (occ.has(k)) return;
  occ.set(k, hex);
  let b = buckets.get(hex);
  if (!b) { b = []; buckets.set(hex, b); }
  b.push(x, y, z, ao);
  voxelCount++;
}

const N = 64;
function inIsland(x, z) {
  const nx = (x - 31.5) / 28.5;
  const nz = (z - 31.5) / 26.5;
  const ang = Math.atan2(nz, nx);
  const r = Math.hypot(nx, nz);
  const wobble = 0.14 * Math.sin(ang * 3.0) + 0.08 * Math.sin(ang * 5.0 + 1.2) + 0.05 * fbm(x * 0.12, z * 0.12);
  return r < 1.0 + wobble;
}
function islandEdge(x, z) {
  for (const [dx, dz] of [[1,0],[-1,0],[0,1],[0,-1]]) {
    if (!inIsland(x + dx, z + dz)) return true;
  }
  return false;
}

const POND = { cx: 31.5, cz: 42, rx: 9.2, rz: 6.6 };
function inPond(x, z) {
  const nx = (x - POND.cx) / POND.rx;
  const nz = (z - POND.cz) / POND.rz;
  return nx * nx + nz * nz < 1;
}

function heightAt(x, z) {
  let h = 10 + Math.floor(fbm(x * 0.09, z * 0.09) * 5);
  if (inPond(x, z)) h = 7;
  const nx = (x - 31.5) / 28.5, nz = (z - 31.5) / 26.5;
  const r = Math.hypot(nx, nz);
  if (r > 0.78) h -= Math.floor((r - 0.78) * 8);
  return Math.max(4, h);
}

const PATH = new Set();
function addPath() {
  // stone zig-zag from torii (south) toward pagoda
  let x = 32, z = 58;
  const segs = [
    { x: 32, z: 52 }, { x: 26, z: 48 }, { x: 36, z: 43 },
    { x: 30, z: 36 }, { x: 32, z: 28 },
  ];
  for (const s of segs) {
    while (x !== s.x || z !== s.z) {
      PATH.add(x + "," + z);
      PATH.add((x + 1) + "," + z);
      if (x < s.x) x++; else if (x > s.x) x--;
      else if (z > s.z) z--; else z++;
    }
  }
}

const PAGODA = { x: 32, z: 24 };
const TORII = { x: 32, z: 58 };

function buildTerrain() {
  addPath();
  for (let x = 0; x < N; x++) {
    for (let z = 0; z < N; z++) {
      if (!inIsland(x, z)) continue;
      const h = heightAt(x, z);
      const pond = inPond(x, z);
      const path = PATH.has(x + "," + z);
      const edge = islandEdge(x, z);
      const under = h - 6 - Math.floor(fbm(x * 0.2, z * 0.2) * 10) - (edge ? 8 : 0);
      const bottom = Math.max(-18, under);

      if (pond) {
        vox(x, 7, z, PAL.waterDark, 0.85);
        if (hash(x, z) > 0.45) vox(x, 8, z, PAL.pond, 0.9);
        vox(x, 6, z, PAL.stone, 0.7);
      } else if (path) {
        vox(x, h, z, PAL.stone, 1);
        if (hash(x + 3, z) > 0.7) vox(x, h + 1, z, PAL.moss, 0.8);
      } else {
        const top = hash(x, z) > 0.18 ? PAL.moss : PAL.dirt;
        vox(x, h, z, top, 1);
        if (hash(x * 2, z) > 0.82) vox(x, h + 1, z, PAL.moss, 0.9);
      }
      for (let y = h - 1; y >= h - 2; y--) vox(x, y, z, PAL.dirt, 0.75);
      const deep = edge ? bottom : Math.max(bottom, h - 6);
      for (let y = h - 3; y >= deep; y--) {
        const c = y < h - 4 ? PAL.rock : PAL.dirt;
        vox(x, y, z, c, 0.5 + (y - deep) * 0.03);
      }
      if (edge) {
        for (let y = h - 6; y >= bottom; y--) {
          const c = (y + x + z) % 5 === 0 ? PAL.rock2 : PAL.rock;
          vox(x, y, z, c, 0.55 + (y - bottom) * 0.02);
        }
        if (hash(x, z + 9) > 0.72) {
          const tip = bottom - 1 - Math.floor(hash(z, x) * 4);
          for (let y = bottom - 1; y >= tip; y--) vox(x, y, z, PAL.rock2, 0.45);
        }
      } else if (hash(x, z) > 0.88) {
        vox(x, bottom, z, PAL.rock2, 0.4);
      }
    }
  }
}
function yNearCliff(x, z, h) {
  for (const [dx, dz] of [[1,0],[-1,0],[0,1],[0,-1]]) {
    if (inIsland(x + dx, z + dz) && heightAt(x + dx, z + dz) < h - 2) return true;
  }
  return false;
}

function fillRect(x0, x1, y, z0, z1, hex, ao = 1) {
  for (let x = x0; x <= x1; x++) for (let z = z0; z <= z1; z++) vox(x, y, z, hex, ao);
}
function ring(cx, cz, y, hw, hex, upturn = 0) {
  for (let x = -hw; x <= hw; x++) {
    for (let z = -hw; z <= hw; z++) {
      const ax = Math.abs(x), az = Math.abs(z);
      if (ax < hw && az < hw) continue;
      const corner = (ax / Math.max(1, hw)) * (az / Math.max(1, hw));
      const lift = Math.round(upturn * corner * corner * corner);
      vox(cx + x, y + lift, cz + z, hex, 0.95);
    }
  }
}
function filledRoof(cx, cz, y, hw, hex, upturn) {
  for (let x = -hw; x <= hw; x++) {
    for (let z = -hw; z <= hw; z++) {
      const ax = Math.abs(x) / Math.max(1, hw);
      const az = Math.abs(z) / Math.max(1, hw);
      const corner = ax * az;
      const lift = Math.round(upturn * Math.pow(corner, 3) * 2.4);
      const edge = Math.max(ax, az);
      const c = edge > 0.92 ? PAL.gold : hex;
      vox(cx + x, y + lift, cz + z, c, 0.9 + 0.1 * (1 - edge));
    }
  }
}

const doorTargets = [];
const floorHits = [];
let pagodaVoxelStart = 0;

function buildPagoda() {
  pagodaVoxelStart = voxelCount;
  const cx = PAGODA.x, cz = PAGODA.z;
  const stories = [
    { body: 6, roof: 10, h: 8 },
    { body: 5, roof: 9, h: 7 },
    { body: 4, roof: 8, h: 6 },
    { body: 3, roof: 7, h: 5 },
    { body: 2, roof: 6, h: 5 },
  ];
  const baseY = heightAt(cx, cz) + 1;
  fillRect(cx - 8, cx + 8, baseY - 1, cz - 8, cz + 8, PAL.stone, 0.9);
  fillRect(cx - 7, cx + 7, baseY, cz - 7, cz + 7, PAL.teak, 1);

  let y = baseY + 1;
  for (let s = 0; s < 5; s++) {
    const { body: b, roof: r, h } = stories[s];
    const floorY = y;
    fillRect(cx - b, cx + b, floorY, cz - b, cz + b, PAL.teak, 0.85);
    for (let k = 1; k < h; k++) {
      for (let x = -b; x <= b; x++) {
        for (let z = -b; z <= b; z++) {
          const edge = Math.abs(x) === b || Math.abs(z) === b;
          if (!edge) continue;
          const corner = Math.abs(x) === b && Math.abs(z) === b;
          const door = z === b && Math.abs(x) <= 1 && k < h - 1 && k > 0;
          if (door) continue;
          if (corner) vox(cx + x, floorY + k, cz + z, PAL.vermillion, 1);
          else if (k === h - 1) vox(cx + x, floorY + k, cz + z, PAL.teak, 0.9);
          else if ((x + z + k) % 2 === 0) vox(cx + x, floorY + k, cz + z, PAL.cream, 0.95);
          else vox(cx + x, floorY + k, cz + z, PAL.vermillion, 0.92);
        }
      }
    }
    // interior glow
    vox(cx, floorY + 2, cz, PAL.warm, 1);
    vox(cx, floorY + 3, cz, PAL.gold, 1);
    // railing
    if (s > 0) {
      ring(cx, cz, floorY + 1, b + 1, PAL.vermillion, 0);
    }
    y = floorY + h;
    // stepped curved roofs
    const layers = r - b + 2;
    for (let i = 0; i < layers; i++) {
      const hw = r - i;
      const jade = i % 2 === 0 ? PAL.jade : PAL.jade2;
      filledRoof(cx, cz, y + i, hw, jade, 1.6 + s * 0.15);
    }
    // gold ridge
    filledRoof(cx, cz, y + layers, Math.max(1, b - 1), PAL.gold, 0.6);
    doorTargets.push({ floor: s, y: floorY + 1, h: h - 2, b, cx, cz });
    y += layers + 1;
  }
  // sorin / finial
  for (let i = 0; i < 8; i++) vox(cx, y + i, cz, PAL.gold, 1);
  for (let i = 0; i < 5; i++) {
    const hw = 2 - (i % 2);
    fillRect(cx - hw, cx + hw, y + 1 + i, cz - hw, cz + hw, PAL.gold, 1);
  }
  vox(cx, y + 9, cz, PAL.gold, 1);
  vox(cx, y + 10, cz, PAL.warm, 1);
  window.__pagodaTop = y + 10;
}

function treeCanopy(cx, y, cz, r, cols, droop = 0) {
  for (let x = -r; x <= r; x++) {
    for (let z = -r; z <= r; z++) {
      for (let yy = 0; yy <= r - 1; yy++) {
        const d = Math.hypot(x * 1.05, z * 1.05, yy * 0.85);
        if (d > r * (0.72 + 0.28 * hash(x + cx, z + cz))) continue;
        const c = cols[(x + z + yy + 12) % cols.length];
        const drop = droop ? Math.floor(droop * Math.abs(x + z) * 0.15) : 0;
        vox(cx + x, y + yy - drop, cz + z, c, 0.9);
      }
    }
  }
}
function trunk(cx, y0, cz, h, hex = PAL.teak) {
  for (let i = 0; i < h; i++) {
    vox(cx, y0 + i, cz, hex, 0.85);
    if (i > 2 && i % 3 === 0) vox(cx + 1, y0 + i, cz, hex, 0.8);
  }
}

const TREE_GROUPS = [];
function buildTrees() {
  const specs = [
    { x: 18, z: 30, kind: "sakura" },
    { x: 46, z: 28, kind: "sakura" },
    { x: 22, z: 48, kind: "sakura" },
    { x: 14, z: 20, kind: "pine" },
    { x: 48, z: 18, kind: "pine" },
    { x: 44, z: 46, kind: "maple" },
    { x: 16, z: 40, kind: "maple" },
    { x: 50, z: 36, kind: "willow" },
  ];
  for (const t of specs) {
    if (!inIsland(t.x, t.z) || inPond(t.x, t.z)) continue;
    const y = heightAt(t.x, t.z) + 1;
    TREE_GROUPS.push(t);
    if (t.kind === "sakura") {
      trunk(t.x, y, t.z, 7);
      treeCanopy(t.x, y + 6, t.z, 4, [PAL.sakura, PAL.sakura2, PAL.sakura3]);
    } else if (t.kind === "pine") {
      trunk(t.x, y, t.z, 8, PAL.teak);
      for (let i = 0; i < 5; i++) {
        treeCanopy(t.x, y + 3 + i * 2, t.z, 4 - i, [PAL.pine, PAL.jade]);
      }
    } else if (t.kind === "maple") {
      trunk(t.x, y, t.z, 6);
      treeCanopy(t.x, y + 5, t.z, 4, [PAL.maple, PAL.maple2, PAL.vermillion]);
    } else {
      trunk(t.x, y, t.z, 7);
      treeCanopy(t.x, y + 6, t.z, 5, [PAL.willow, PAL.jade2, PAL.moss], 1);
    }
  }
}

function buildProps() {
  // torii
  const tx = TORII.x, tz = TORII.z, ty = heightAt(tx, tz) + 1;
  for (let i = 0; i < 8; i++) {
    vox(tx - 3, ty + i, tz, PAL.vermillion);
    vox(tx + 3, ty + i, tz, PAL.vermillion);
  }
  fillRect(tx - 5, tx + 5, ty + 8, tz, tz, PAL.vermillion);
  fillRect(tx - 6, tx + 6, ty + 9, tz, tz, PAL.vermillion);
  fillRect(tx - 4, tx + 4, ty + 7, tz, tz, PAL.gold);
  vox(tx, ty + 10, tz, PAL.gold);

  // bamboo fence along south-west rim
  let nFence = 0;
  for (let x = 8; x < 56 && nFence < 80; x++) {
    for (let z = 8; z < 56; z++) {
      if (!inIsland(x, z) || !islandEdge(x, z)) continue;
      if (z < 50 && x > 20 && x < 44) continue;
      if (hash(x, z) < 0.55) continue;
      const y = heightAt(x, z) + 1;
      for (let i = 0; i < 3; i++) vox(x, y + i, z, PAL.bamboo, 0.9);
      nFence++;
    }
  }

  // jizo
  function jizo(x, z) {
    const y = heightAt(x, z) + 1;
    vox(x, y, z, PAL.stone); vox(x, y + 1, z, PAL.stone);
    vox(x, y + 2, z, PAL.stone); vox(x, y + 3, z, PAL.stone);
    vox(x, y + 2, z - 1, PAL.stone);
    vox(x - 1, y + 1, z, PAL.stone); vox(x + 1, y + 1, z, PAL.stone);
  }
  jizo(24, 34);
  jizo(40, 33);

  // flowers
  let flowers = 0;
  for (let i = 0; i < 400 && flowers < 40; i++) {
    const x = 8 + Math.floor(hash(i, 2) * 48);
    const z = 8 + Math.floor(hash(i, 9) * 48);
    if (!inIsland(x, z) || inPond(x, z) || PATH.has(x + "," + z)) continue;
    if (Math.abs(x - PAGODA.x) < 8 && Math.abs(z - PAGODA.z) < 8) continue;
    const y = heightAt(x, z) + 1;
    const c = [PAL.sakura, PAL.sakura2, PAL.sakura3, PAL.maple2][i % 4];
    vox(x, y, z, PAL.moss);
    vox(x, y + 1, z, c);
    flowers++;
  }

  // arched wooden bridge over pond
  const bx = 31, bz = 42;
  for (let i = -6; i <= 6; i++) {
    const arch = Math.round(2.2 * Math.cos((i / 6) * Math.PI * 0.5));
    const y = 8 + Math.max(0, arch);
    vox(bx + i, y, bz, PAL.teak);
    vox(bx + i, y, bz + 1, PAL.teak);
    vox(bx + i, y + 1, bz, PAL.teak);
    vox(bx + i, y + 1, bz + 2, PAL.teak);
    if (Math.abs(i) > 4) {
      for (let k = 7; k < y; k++) {
        vox(bx + i, k, bz, PAL.teak, 0.8);
        vox(bx + i, k, bz + 1, PAL.teak, 0.8);
      }
    }
  }
}

const lanternDefs = [
  { x: 32, z: 54 },
  { x: 26, z: 42 },
  { x: 38, z: 30 },
  { x: 22, z: 26 },
];
function buildLanterns() {
  for (const L of lanternDefs) {
    if (!inIsland(L.x, L.z)) { L.x = 28; L.z = 36; }
    const y = (inPond(L.x, L.z) ? 8 : heightAt(L.x, L.z)) + 1;
    L.y = y;
    vox(L.x, y, L.z, PAL.stone);
    vox(L.x, y + 1, L.z, PAL.teak);
    vox(L.x, y + 2, L.z, PAL.vermillion);
    vox(L.x, y + 3, L.z, PAL.warm);
    vox(L.x, y + 4, L.z, PAL.gold);
    vox(L.x - 1, y + 2, L.z, PAL.vermillion);
    vox(L.x + 1, y + 2, L.z, PAL.vermillion);
  }
}

buildTerrain();
buildPagoda();
const pagodaVoxels = voxelCount - pagodaVoxelStart;
buildTrees();
buildProps();
buildLanterns();

// --- renderer ---
const scene = new THREE.Scene();
scene.fog = new THREE.Fog(0x87b8e8, 48, 110);
const camera = new THREE.PerspectiveCamera(48, innerWidth / innerHeight, 0.2, 250);
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: "high-performance" });
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
renderer.setSize(innerWidth, innerHeight);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.12;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
const canvasEl = renderer.domElement;
container.appendChild(canvasEl);

const hemi = new THREE.HemisphereLight(0xb8d4ff, 0x3d4a32, 0.85);
scene.add(hemi);
const sun = new THREE.DirectionalLight(0xfff1d6, 2.1);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.near = 1;
sun.shadow.camera.far = 140;
sun.shadow.camera.left = sun.shadow.camera.bottom = -42;
sun.shadow.camera.right = sun.shadow.camera.top = 42;
sun.shadow.bias = -0.0008;
scene.add(sun);
scene.add(sun.target);

const VS = 0.5;
const origin = new THREE.Vector3(-31.5 * VS, 0, -31.5 * VS);
function wx(x) { return origin.x + x * VS; }
function wy(y) { return y * VS; }
function wz(z) { return origin.z + z * VS; }

const geo = new THREE.BoxGeometry(0.92 * VS, 0.92 * VS, 0.92 * VS);
const dummy = new THREE.Object3D();
const color = new THREE.Color();
const meshes = [];

for (const [hex, arr] of buckets) {
  const n = arr.length / 4;
  const emissive = (hex === PAL.warm || hex === PAL.gold) ? hex : 0x000000;
  const mat = new THREE.MeshStandardMaterial({
    color: 0xffffff,
    roughness: hex === PAL.gold ? 0.35 : hex === PAL.pond ? 0.2 : 0.72,
    metalness: hex === PAL.gold ? 0.65 : 0.04,
    emissive: emissive,
    emissiveIntensity: hex === PAL.warm ? 0.85 : hex === PAL.gold ? 0.18 : 0,
  });
  const mesh = new THREE.InstancedMesh(geo, mat, n);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  for (let i = 0; i < n; i++) {
    const x = arr[i * 4], y = arr[i * 4 + 1], z = arr[i * 4 + 2], ao = arr[i * 4 + 3];
    dummy.position.set(wx(x), wy(y), wz(z));
    dummy.rotation.set(0, 0, 0);
    dummy.scale.set(1, 1, 1);
    dummy.updateMatrix();
    mesh.setMatrixAt(i, dummy.matrix);
    color.setHex(hex).multiplyScalar(0.55 + 0.45 * ao);
    mesh.setColorAt(i, color);
  }
  mesh.instanceMatrix.needsUpdate = true;
  if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  scene.add(mesh);
  meshes.push(mesh);
}

// pond ripple plane
const pondUniforms = { uTime: { value: 0 }, uColor: { value: new THREE.Color(PAL.pond) } };
const pondMat = new THREE.ShaderMaterial({
  transparent: true,
  uniforms: pondUniforms,
  vertexShader: `
    varying vec2 vUv;
    uniform float uTime;
    void main() {
      vUv = uv;
      vec3 p = position;
      float r = length(uv - 0.5);
      p.y += sin(r * 42.0 - uTime * 3.2) * 0.04;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(p, 1.0);
    }`,
  fragmentShader: `
    varying vec2 vUv;
    uniform vec3 uColor;
    uniform float uTime;
    void main() {
      float r = length(vUv - 0.5);
      float wave = 0.5 + 0.5 * sin(r * 40.0 - uTime * 3.0);
      float alpha = smoothstep(0.5, 0.38, r) * 0.55;
      vec3 col = mix(uColor, vec3(0.85, 0.96, 0.95), wave * 0.25);
      gl_FragColor = vec4(col, alpha);
    }`,
});
const pondMesh = new THREE.Mesh(new THREE.CircleGeometry(POND.rx * VS, 48), pondMat);
pondMesh.rotation.x = -Math.PI / 2;
pondMesh.position.set(wx(POND.cx), wy(8.35), wz(POND.cz));
pondMesh.scale.z = POND.rz / POND.rx;
scene.add(pondMesh);

// koi
const koi = [];
const koiGeo = new THREE.BoxGeometry(0.55, 0.18, 0.22);
const koiMats = [0xC73E1D, 0xF4F1DE, 0xE8B86D, 0xC73E1D, 0xFF8FAB, 0xF4F1DE].map(
  (h) => new THREE.MeshStandardMaterial({ color: h, roughness: 0.4 })
);
for (let i = 0; i < 6; i++) {
  const m = new THREE.Mesh(koiGeo, koiMats[i]);
  m.castShadow = true;
  scene.add(m);
  koi.push({ m, a: i * 1.05, r: 2.2 + (i % 3) * 0.7, s: 0.5 + i * 0.08 });
}

// petals
const petals = [];
const petalGeo = new THREE.BoxGeometry(0.12, 0.03, 0.08);
const petalMat = [
  new THREE.MeshStandardMaterial({ color: PAL.sakura, roughness: 0.6 }),
  new THREE.MeshStandardMaterial({ color: PAL.sakura2, roughness: 0.6 }),
  new THREE.MeshStandardMaterial({ color: PAL.sakura3, roughness: 0.6 }),
];
for (let i = 0; i < 90; i++) {
  const m = new THREE.Mesh(petalGeo, petalMat[i % 3]);
  m.position.set(wx(10 + hash(i, 1) * 44), wy(18 + hash(i, 2) * 16), wz(10 + hash(i, 3) * 44));
  scene.add(m);
  petals.push({ m, sp: 0.6 + hash(i, 4) * 1.2, w: 0.4 + hash(i, 5) });
}

// birds
const birds = [];
for (let i = 0; i < 8; i++) {
  const g = new THREE.Group();
  const wing = new THREE.Mesh(
    new THREE.BoxGeometry(0.7, 0.06, 0.18),
    new THREE.MeshStandardMaterial({ color: 0x222226, roughness: 0.8 })
  );
  g.add(wing);
  scene.add(g);
  birds.push({ g, a: i * 0.8, r: 10 + i * 0.4, y: 16 + (i % 3) });
}

// lantern lights + click proxies
const lanterns = [];
for (let i = 0; i < 4; i++) {
  const L = lanternDefs[i];
  const light = new THREE.PointLight(0xffc07a, 0, 14, 2);
  light.position.set(wx(L.x), wy(L.y + 3.2), wz(L.z));
  scene.add(light);
  const proxy = new THREE.Mesh(
    new THREE.BoxGeometry(VS * 2.2, VS * 5, VS * 2.2),
    new THREE.MeshBasicMaterial({ visible: false })
  );
  proxy.position.set(wx(L.x), wy(L.y + 2), wz(L.z));
  proxy.userData = { kind: "lantern", i };
  scene.add(proxy);
  lanterns.push({ light, on: true, base: 2.4, proxy });
}

// pagoda interior light
const pagodaLight = new THREE.PointLight(0xffd59a, 1.6, 16, 2);
pagodaLight.position.set(wx(PAGODA.x), wy(heightAt(PAGODA.x, PAGODA.z) + 10), wz(PAGODA.z));
scene.add(pagodaLight);

// doors
const doors = [];
const doorMat = new THREE.MeshStandardMaterial({ color: PAL.teak, roughness: 0.55 });
for (const d of doorTargets) {
  const pair = [];
  for (const side of [-1, 1]) {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(VS * 1.05, VS * d.h, VS * 0.22), doorMat);
    mesh.position.set(wx(d.cx + side * 0.55), wy(d.y + d.h / 2), wz(d.cz + d.b));
    mesh.userData = { kind: "door", floor: d.floor };
    scene.add(mesh);
    pair.push({ mesh, side, closedX: wx(d.cx + side * 0.55), openX: wx(d.cx + side * 2.1), y: wy(d.y + d.h / 2), z: wz(d.cz + d.b) });
  }
  const hit = new THREE.Mesh(
    new THREE.BoxGeometry(VS * d.b * 2, VS * d.h, VS * d.b * 2),
    new THREE.MeshBasicMaterial({ visible: false })
  );
  hit.position.set(wx(d.cx), wy(d.y + d.h / 2), wz(d.cz));
  hit.userData = { kind: "floor", floor: d.floor };
  scene.add(hit);
  doors.push({ open: false, t: 0, pair, floor: d.floor, hit });
}

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.06;
controls.maxPolarAngle = Math.PI * 0.48;
controls.minDistance = 6;
controls.maxDistance = 55;
controls.autoRotate = false;
controls.autoRotateSpeed = 0.45;
controls.target.set(wx(PAGODA.x), wy(18), wz(PAGODA.z));

const introFrom = new THREE.Vector3(wx(TORII.x), wy(14), wz(TORII.z + 10));
const introTo = new THREE.Vector3(wx(PAGODA.x + 22), wy(20), wz(PAGODA.z + 28));
camera.position.copy(introFrom);
let introT = 0;
const INTRO = 2.5;

const clock = new THREE.Clock();
let fps = 60, fpsAcc = 0, fpsN = 0;
let timeOfDay = 0.22;
let autoCycle = true;
let idle = 0;
let lastInteract = 0;

function skyFor(t) {
  // t 0 midnight, 0.25 dawn, 0.5 noon, 0.75 dusk
  const day = new THREE.Color(0x8ec5e8);
  const dusk = new THREE.Color(0xe07a3d);
  const night = new THREE.Color(0x0b1220);
  const dawn = new THREE.Color(0xf2b090);
  const c = new THREE.Color();
  if (t < 0.2) c.copy(night).lerp(dawn, t / 0.2);
  else if (t < 0.3) c.copy(dawn).lerp(day, (t - 0.2) / 0.1);
  else if (t < 0.55) c.copy(day);
  else if (t < 0.7) c.copy(day).lerp(dusk, (t - 0.55) / 0.15);
  else if (t < 0.82) c.copy(dusk).lerp(night, (t - 0.7) / 0.12);
  else c.copy(night);
  return c;
}

function todName(t) {
  if (t < 0.18 || t >= 0.85) return "night";
  if (t < 0.3) return "dawn";
  if (t < 0.55) return "day";
  if (t < 0.72) return "golden hour";
  return "dusk";
}

const ray = new THREE.Raycaster();
const ptr = new THREE.Vector2();
const clickables = [...lanterns.map((l) => l.proxy), ...doors.map((d) => d.hit)];

canvasEl.addEventListener("pointerdown", (e) => {
  lastInteract = performance.now();
  controls.autoRotate = false;
  ptr.x = (e.clientX / innerWidth) * 2 - 1;
  ptr.y = -(e.clientY / innerHeight) * 2 + 1;
  ray.setFromCamera(ptr, camera);
  const hits = ray.intersectObjects(clickables, false);
  if (!hits.length) return;
  const data = hits[0].object.userData;
  if (data.kind === "lantern") {
    const L = lanterns[data.i];
    L.on = !L.on;
  } else if (data.kind === "floor") {
    const D = doors[data.floor];
    D.open = !D.open;
  }
});
["pointermove", "wheel", "touchstart"].forEach((ev) => {
  canvasEl.addEventListener(ev, () => {
    lastInteract = performance.now();
    controls.autoRotate = false;
  }, { passive: true });
});

const todSlider = document.getElementById("tod");
const todLabel = document.getElementById("todLabel");
const playBtn = document.getElementById("playBtn");
todSlider.addEventListener("input", () => {
  autoCycle = false;
  playBtn.classList.remove("active");
  timeOfDay = Number(todSlider.value) / 1000;
});
playBtn.addEventListener("click", () => {
  autoCycle = !autoCycle;
  playBtn.classList.toggle("active", autoCycle);
});
document.getElementById("resetCam").addEventListener("click", () => {
  introT = 0;
  camera.position.copy(introFrom);
});

function ease(t) { return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; }

window.__VOXEL__ = { voxelCount, fps, pagodaFloors: 5, timeOfDay };

function animate() {
  const dt = Math.min(clock.getDelta(), 0.1);
  const t = clock.elapsedTime;
  pondUniforms.uTime.value = t;

  if (autoCycle) timeOfDay = (timeOfDay + dt / 90) % 1;
  todSlider.value = String(Math.floor(timeOfDay * 1000));
  todLabel.textContent = todName(timeOfDay);

  const sky = skyFor(timeOfDay);
  scene.background = sky;
  scene.fog.color.copy(sky);
  const sunAng = timeOfDay * Math.PI * 2 - Math.PI / 2;
  const sunH = Math.sin(timeOfDay * Math.PI * 2);
  sun.position.set(Math.cos(sunAng) * 40, Math.max(3, sunH * 38 + 8), Math.sin(sunAng) * 28);
  sun.target.position.set(wx(PAGODA.x), wy(12), wz(PAGODA.z));
  sun.intensity = 0.35 + Math.max(0, sunH) * 2.0;
  sun.color.set(sunH > 0.15 ? 0xfff1d6 : 0xff8a5b);
  hemi.intensity = 0.28 + Math.max(0, sunH) * 0.7;
  renderer.toneMappingExposure = 0.85 + Math.max(0, sunH) * 0.4;

  const night = sunH < 0.12;
  for (const L of lanterns) {
    const want = L.on && (night || !autoCycle ? L.on : night);
    const flicker = 0.85 + Math.sin(t * 17 + L.light.id) * 0.08 + Math.sin(t * 31) * 0.04;
    const target = L.on && (night || timeOfDay > 0.65 || timeOfDay < 0.2) ? L.base * flicker : L.on ? 0.25 : 0;
    L.light.intensity += (target - L.light.intensity) * Math.min(1, dt * 4);
  }
  pagodaLight.intensity = 0.4 + (night ? 1.4 : 0.3);

  for (const D of doors) {
    D.t += ((D.open ? 1 : 0) - D.t) * Math.min(1, dt * 4);
    for (const p of D.pair) {
      p.mesh.position.x = p.closedX + (p.openX - p.closedX) * D.t;
      p.mesh.position.y = p.y;
      p.mesh.position.z = p.z;
    }
  }

  for (const k of koi) {
    k.a += dt * k.s;
    const px = POND.cx + Math.cos(k.a) * k.r;
    const pz = POND.cz + Math.sin(k.a) * k.r * 0.7;
    k.m.position.set(wx(px), wy(8.2) + Math.sin(k.a * 3) * 0.06, wz(pz));
    k.m.rotation.y = -k.a + Math.PI / 2;
  }
  for (const p of petals) {
    p.m.position.y -= dt * p.sp;
    p.m.position.x += Math.sin(t * p.w + p.m.id) * dt * 0.4;
    p.m.rotation.z += dt * 2;
    p.m.rotation.x += dt;
    if (p.m.position.y < wy(6)) {
      p.m.position.set(wx(12 + Math.random() * 40), wy(22 + Math.random() * 10), wz(12 + Math.random() * 40));
    }
  }
  for (const b of birds) {
    b.a += dt * 0.35;
    b.g.position.set(
      wx(PAGODA.x) + Math.cos(b.a) * b.r,
      wy(b.y) + Math.sin(b.a * 2) * 0.6,
      wz(PAGODA.z) + Math.sin(b.a) * b.r * 0.7
    );
    b.g.rotation.y = -b.a + Math.PI / 2;
    b.g.children[0].rotation.z = Math.sin(t * 8 + b.a) * 0.45;
  }

  if (introT < INTRO) {
    introT += dt;
    const k = ease(Math.min(1, introT / INTRO));
    camera.position.lerpVectors(introFrom, introTo, k);
    controls.target.set(wx(PAGODA.x), wy(14 + k * 6), wz(PAGODA.z));
    camera.lookAt(controls.target);
  } else {
    if (performance.now() - lastInteract > 4000) controls.autoRotate = true;
    controls.update();
  }

  renderer.render(scene, camera);
  fpsAcc += 1 / Math.max(dt, 1e-4);
  fpsN++;
  if (fpsN >= 20) { fps = Math.round(fpsAcc / fpsN); fpsAcc = 0; fpsN = 0; }
  document.getElementById("stats").textContent =
    `${Math.round(voxelCount / 100) / 10}k voxels | ${fps} FPS`;
  window.__VOXEL__ = { voxelCount, fps, pagodaFloors: 5, timeOfDay };
}
renderer.setAnimationLoop(animate);

addEventListener("resize", () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
  renderer.setSize(innerWidth, innerHeight);
});

console.info("[Grok 4.5 Pagoda]", { voxelCount, pagodaVoxels, floors: 5 });
  return function unmount() {
    try { renderer.setAnimationLoop(null); renderer.dispose(); geo.dispose(); } catch (e) {}
  };
}
