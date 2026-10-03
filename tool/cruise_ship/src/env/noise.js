import * as THREE from 'three/webgpu';

// Tileable noise volumes and maps, generated once at load. Nothing is
// fetched (the scene runs from file://), so the clouds' Perlin-Worley
// volumes, the weather map and the sea's detail normals are all built here.

function hash3(x, y, z, s) {
  let h = (x * 374761393 + y * 668265263 + z * 2147483647 + s * 1274126177) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}

function mod(a, n) { return ((a % n) + n) % n; }
const fade = (t) => t * t * t * (t * (t * 6 - 15) + 10);

/** Tileable 3D gradient noise, period p (lattice cells), result in ~[-1,1]. */
function perlin3(x, y, z, p, seed) {
  const xi = Math.floor(x), yi = Math.floor(y), zi = Math.floor(z);
  const xf = x - xi, yf = y - yi, zf = z - zi;
  const u = fade(xf), v = fade(yf), w = fade(zf);
  let acc = 0;
  for (let c = 0; c < 8; c++) {
    const dx = c & 1, dy = (c >> 1) & 1, dz = (c >> 2) & 1;
    const gx = mod(xi + dx, p), gy = mod(yi + dy, p), gz = mod(zi + dz, p);
    const a = hash3(gx, gy, gz, seed) * Math.PI * 2;
    const b = hash3(gx, gy, gz, seed + 7) * 2 - 1;
    const r = Math.sqrt(1 - b * b);
    const g0 = r * Math.cos(a), g1 = r * Math.sin(a), g2 = b;
    const d = g0 * (xf - dx) + g1 * (yf - dy) + g2 * (zf - dz);
    const wx = dx ? u : 1 - u, wy = dy ? v : 1 - v, wz = dz ? w : 1 - w;
    acc += d * wx * wy * wz;
  }
  return acc * 1.6;
}

/** Tileable Worley F1 (inverted: 1 at feature points), c cells per tile. */
function worley3(x, y, z, c, seed) {
  const xi = Math.floor(x), yi = Math.floor(y), zi = Math.floor(z);
  let best = 9;
  for (let k = -1; k <= 1; k++) for (let j = -1; j <= 1; j++) for (let i = -1; i <= 1; i++) {
    const cx = xi + i, cy = yi + j, cz = zi + k;
    const hx = mod(cx, c), hy = mod(cy, c), hz = mod(cz, c);
    const px = cx + hash3(hx, hy, hz, seed);
    const py = cy + hash3(hx, hy, hz, seed + 11);
    const pz = cz + hash3(hx, hy, hz, seed + 23);
    const dx = px - x, dy = py - y, dz = pz - z;
    const d = dx * dx + dy * dy + dz * dz;
    if (d < best) best = d;
  }
  return 1 - Math.min(1, Math.sqrt(best));
}

function worleyFbm(fx, fy, fz, c, seed) {
  return worley3(fx * c, fy * c, fz * c, c, seed) * 0.625
    + worley3(fx * c * 2, fy * c * 2, fz * c * 2, c * 2, seed + 101) * 0.25
    + worley3(fx * c * 4, fy * c * 4, fz * c * 4, c * 4, seed + 211) * 0.125;
}

function perlinFbm(fx, fy, fz, p, oct, seed) {
  let a = 0, amp = 1, norm = 0, per = p;
  for (let o = 0; o < oct; o++) {
    a += perlin3(fx * per, fy * per, fz * per, per, seed + o * 31) * amp;
    norm += amp; amp *= 0.5; per *= 2;
  }
  return a / norm;
}

const remap = (v, a, b, c, d) => c + ((v - a) / (b - a)) * (d - c);
const sat = (v) => Math.min(1, Math.max(0, v));

/**
 * Base cloud shape, N^3 RGBA8: R Perlin-Worley, G/B/A Worley fbm at rising
 * frequency (Schneider, "The Real-Time Volumetric Cloudscapes of Horizon").
 */
export function makeCloudBase(N = 64) {
  const data = new Uint8Array(N * N * N * 4);
  let o = 0;
  for (let z = 0; z < N; z++) for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const fx = x / N, fy = y / N, fz = z / N;
    const p = sat(perlinFbm(fx, fy, fz, 4, 4, 3) * 0.5 + 0.5);
    const w1 = worleyFbm(fx, fy, fz, 4, 17);
    const pw = sat(remap(p, 0, 1, w1, 1));
    const w2 = worleyFbm(fx, fy, fz, 8, 41);
    const w3 = worleyFbm(fx, fy, fz, 16, 67);
    data[o++] = pw * 255;
    data[o++] = w1 * 255;
    data[o++] = w2 * 255;
    data[o++] = w3 * 255;
  }
  const tex = new THREE.Data3DTexture(data, N, N, N);
  tex.format = THREE.RGBAFormat;
  tex.type = THREE.UnsignedByteType;
  tex.minFilter = THREE.LinearFilter;
  tex.magFilter = THREE.LinearFilter;
  tex.wrapS = tex.wrapT = tex.wrapR = THREE.RepeatWrapping;
  tex.unpackAlignment = 1;
  tex.needsUpdate = true;
  return tex;
}

/** Detail erosion, N^3 RGBA8 Worley fbm at three frequencies. */
export function makeCloudDetail(N = 32) {
  const data = new Uint8Array(N * N * N * 4);
  let o = 0;
  for (let z = 0; z < N; z++) for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const fx = x / N, fy = y / N, fz = z / N;
    data[o++] = worleyFbm(fx, fy, fz, 2, 5) * 255;
    data[o++] = worleyFbm(fx, fy, fz, 4, 9) * 255;
    data[o++] = worleyFbm(fx, fy, fz, 8, 13) * 255;
    data[o++] = 255;
  }
  const tex = new THREE.Data3DTexture(data, N, N, N);
  tex.format = THREE.RGBAFormat;
  tex.type = THREE.UnsignedByteType;
  tex.minFilter = THREE.LinearFilter;
  tex.magFilter = THREE.LinearFilter;
  tex.wrapS = tex.wrapT = tex.wrapR = THREE.RepeatWrapping;
  tex.unpackAlignment = 1;
  tex.needsUpdate = true;
  return tex;
}

// ---- 2D -------------------------------------------------------------------

function perlin2(x, y, p, seed) { return perlin3(x, y, 0.5, p, seed); }

function fbm2(fx, fy, p, oct, seed, gain = 0.5) {
  let a = 0, amp = 1, norm = 0, per = p;
  for (let o = 0; o < oct; o++) {
    a += perlin2(fx * per, fy * per, per, seed + o * 13) * amp;
    norm += amp; amp *= gain; per *= 2;
  }
  return a / norm;
}

function worley2(x, y, c, seed) {
  const xi = Math.floor(x), yi = Math.floor(y);
  let f1 = 9, f2 = 9;
  for (let j = -1; j <= 1; j++) for (let i = -1; i <= 1; i++) {
    const cx = xi + i, cy = yi + j;
    const hx = mod(cx, c), hy = mod(cy, c);
    const dx = cx + hash3(hx, hy, 0, seed) - x;
    const dy = cy + hash3(hx, hy, 0, seed + 5) - y;
    const d = dx * dx + dy * dy;
    if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) f2 = d;
  }
  return [Math.sqrt(f1), Math.sqrt(f2)];
}

/** Weather map: R coverage field, G cloud-type variation, B fine breakup. */
export function makeWeatherMap(N = 256) {
  const data = new Uint8Array(N * N * 4);
  let o = 0;
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const fx = x / N, fy = y / N;
    const big = fbm2(fx, fy, 3, 5, 1) * 0.5 + 0.5;
    const [f1] = worley2(fx * 10, fy * 10, 10, 3);
    const clumps = 1 - Math.min(1, f1);
    const cov = sat(big * 0.75 + clumps * 0.45 - 0.12);
    const type = sat(fbm2(fx, fy, 2, 3, 9) * 0.6 + 0.5);
    const fine = sat(fbm2(fx, fy, 16, 3, 21) * 0.5 + 0.5);
    data[o++] = cov * 255; data[o++] = type * 255; data[o++] = fine * 255; data[o++] = 255;
  }
  const tex = new THREE.DataTexture(data, N, N, THREE.RGBAFormat, THREE.UnsignedByteType);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.minFilter = THREE.LinearMipmapLinearFilter;
  tex.magFilter = THREE.LinearFilter;
  tex.generateMipmaps = true;
  tex.needsUpdate = true;
  return tex;
}

/**
 * Sea detail: a tileable height field of short wind ripples (sum of
 * integer-wavenumber waves so it wraps), stored as a tangent-space normal
 * map in RG plus foam breakup noise in B.
 */
export function makeSeaDetail(N = 512) {
  const H = new Float32Array(N * N);
  const waves = [];
  let s = 12345;
  const rnd = () => { s = (Math.imul(s, 1664525) + 1013904223) | 0; return (s >>> 0) / 4294967296; };
  for (let i = 0; i < 90; i++) {
    const ang = (rnd() - 0.5) * 2.4;               // mostly along +x (the wind)
    const k = 4 + Math.floor(Math.pow(rnd(), 1.6) * 60);
    const kx = Math.round(Math.cos(ang) * k), ky = Math.round(Math.sin(ang) * k);
    if (kx === 0 && ky === 0) continue;
    const amp = 1 / Math.pow(Math.hypot(kx, ky), 1.25);
    waves.push([kx, ky, amp, rnd() * Math.PI * 2]);
  }
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    let h = 0;
    const u = (x / N) * Math.PI * 2, v = (y / N) * Math.PI * 2;
    for (const [kx, ky, a, ph] of waves) {
      // Sharpened crests read as wind ripples rather than smooth swell.
      const c = Math.sin(kx * u + ky * v + ph);
      h += a * (c > 0 ? c : c * 0.6);
    }
    H[y * N + x] = h;
  }
  const data = new Uint8Array(N * N * 4);
  const strength = 6.0;
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const xl = (x + N - 1) % N, xr = (x + 1) % N, yd = (y + N - 1) % N, yu = (y + 1) % N;
    const dx = (H[y * N + xr] - H[y * N + xl]) * strength;
    const dy = (H[yu * N + x] - H[yd * N + x]) * strength;
    const inv = 1 / Math.hypot(dx, dy, 1);
    const fx = x / N, fy = y / N;
    const [f1, f2] = worley2(fx * 24, fy * 24, 24, 77);
    const foam = sat((f2 - f1) * 3.0);            // cell borders: lacy foam
    const o = (y * N + x) * 4;
    data[o] = (-dx * inv * 0.5 + 0.5) * 255;
    data[o + 1] = (-dy * inv * 0.5 + 0.5) * 255;
    data[o + 2] = foam * 255;
    data[o + 3] = sat(fbm2(fx, fy, 8, 4, 31) * 0.5 + 0.5) * 255;
  }
  const tex = new THREE.DataTexture(data, N, N, THREE.RGBAFormat, THREE.UnsignedByteType);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.minFilter = THREE.LinearMipmapLinearFilter;
  tex.magFilter = THREE.LinearFilter;
  tex.anisotropy = 8;
  tex.generateMipmaps = true;
  tex.needsUpdate = true;
  return tex;
}

/** Generic tileable fbm value, exported for procedural textures. */
export { fbm2, worley2, hash3, perlin3 };
