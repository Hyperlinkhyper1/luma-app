import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { PALETTE, paint, paletteMaterial } from './palette.js';

// Small geometry kit: accumulate many parts per material and merge them into
// a handful of meshes (few draw calls), or collect matrices for instancing.

const _m = new THREE.Matrix4();
const _q = new THREE.Quaternion();
const _e = new THREE.Euler();
const _p = new THREE.Vector3();
const _s = new THREE.Vector3();

/** Strip everything but position/normal/uv and make it non-indexed. */
export function normalizeGeometry(g) {
  let out = g.index ? g.toNonIndexed() : g;
  if (!out.attributes.uv) {
    const n = out.attributes.position.count;
    out.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(n * 2), 2));
  }
  if (!out.attributes.normal) out.computeVertexNormals();
  for (const k of Object.keys(out.attributes)) {
    if (k !== 'position' && k !== 'normal' && k !== 'uv') out.deleteAttribute(k);
  }
  out.morphAttributes = {};
  return out;
}

export function mat(px, py, pz, rx = 0, ry = 0, rz = 0, sx = 1, sy = 1, sz = 1) {
  _e.set(rx, ry, rz, 'YXZ');
  _q.setFromEuler(_e);
  return new THREE.Matrix4().compose(_p.set(px, py, pz), _q, _s.set(sx, sy, sz));
}

const unitBox = new THREE.BoxGeometry(1, 1, 1);
const unitCyl = new THREE.CylinderGeometry(1, 1, 1, 16, 1, false);
const unitCyl8 = new THREE.CylinderGeometry(1, 1, 1, 8, 1, false);

export class Builder {
  constructor() {
    this.parts = new Map();
  }

  add(key, geom, matrix = null) {
    let g = normalizeGeometry(geom.clone());
    if (matrix) g.applyMatrix4(matrix);
    // Plain-coloured parts all share one palette material (one draw call).
    let bucket = key;
    if (PALETTE[key]) { paint(g, key); bucket = 'palette'; }
    if (!this.parts.has(bucket)) this.parts.set(bucket, []);
    this.parts.get(bucket).push(g);
    return this;
  }

  /** Axis-aligned (optionally yawed) box by centre and size. */
  box(key, cx, cy, cz, sx, sy, sz, ry = 0) {
    return this.add(key, unitBox, mat(cx, cy, cz, 0, ry, 0, sx, sy, sz));
  }

  /** Box from min/max corners. */
  boxMM(key, x0, y0, z0, x1, y1, z1) {
    return this.box(key, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, Math.abs(x1 - x0), Math.abs(y1 - y0), Math.abs(z1 - z0));
  }

  /** Cylinder between two points with radius r. */
  tube(key, a, b, r, lowPoly = false) {
    const d = new THREE.Vector3().subVectors(b, a);
    const len = d.length();
    if (len < 1e-4) return this;
    const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), d.normalize());
    const m = new THREE.Matrix4().compose(new THREE.Vector3().addVectors(a, b).multiplyScalar(0.5), q, new THREE.Vector3(r, len, r));
    return this.add(key, lowPoly ? unitCyl8 : unitCyl, m);
  }

  build(materials, { castShadow = true, receiveShadow = true, name = '' } = {}) {
    const group = new THREE.Group();
    group.name = name;
    for (const [key, list] of this.parts) {
      const material = key === 'palette' ? paletteMaterial() : materials[key];
      if (!material) { console.warn('missing material', key); continue; }
      // Merge in chunks to keep buffers a sensible size.
      for (let i = 0; i < list.length; i += 4000) {
        const g = mergeGeometries(list.slice(i, i + 4000), false);
        if (!g) continue;
        g.computeBoundingSphere();
        const mesh = new THREE.Mesh(g, material);
        mesh.castShadow = castShadow && !material.transparent && !material.userData.noShadow;
        mesh.receiveShadow = receiveShadow;
        mesh.name = `${name}:${key}`;
        group.add(mesh);
      }
    }
    this.parts.clear();
    return group;
  }
}

/** Collects instance matrices per part, then builds InstancedMeshes. */
export class Instancer {
  constructor() { this.sets = new Map(); }

  add(key, matrix) {
    if (!this.sets.has(key)) this.sets.set(key, []);
    this.sets.get(key).push(matrix.clone());
  }

  build(defs, materials, { name = '' } = {}) {
    const group = new THREE.Group();
    for (const [key, mats] of this.sets) {
      const def = defs[key];
      if (!def) { console.warn('missing instanced def', key); continue; }
      const material = materials[def.material];
      const mesh = new THREE.InstancedMesh(def.geometry, material, mats.length);
      for (let i = 0; i < mats.length; i++) mesh.setMatrixAt(i, mats[i]);
      mesh.instanceMatrix.needsUpdate = true;
      mesh.castShadow = def.castShadow !== false && !material.transparent;
      mesh.receiveShadow = def.receiveShadow !== false;
      mesh.name = `${name}:${key}`;
      // Bounds over all instances, so shadow cascades and the view can cull it.
      mesh.computeBoundingSphere();
      group.add(mesh);
    }
    return group;
  }
}

/** Extrude a closed 2D polygon (x, z pairs in plan) between two heights. */
export function prism(points, y0, y1, { caps = true } = {}) {
  const shape = new THREE.Shape();
  shape.moveTo(points[0][0], -points[0][1]);
  for (let i = 1; i < points.length; i++) shape.lineTo(points[i][0], -points[i][1]);
  shape.closePath();
  const g = new THREE.ExtrudeGeometry(shape, { depth: y1 - y0, bevelEnabled: false, curveSegments: 1 });
  // Extrude runs along +z of the shape plane; lay it flat (shape y = -z).
  g.rotateX(-Math.PI / 2);
  g.translate(0, y0, 0);
  if (!caps) {
    // keep caps anyway: ExtrudeGeometry groups 0 = caps, 1 = sides
  }
  return g;
}

/** Offset a polyline (plan view) sideways by d (positive = to the left of travel). */
export function offsetPolyline(pts, d) {
  const out = [];
  for (let i = 0; i < pts.length; i++) {
    const p = pts[i];
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)];
    let tx = b[0] - a[0], tz = b[1] - a[1];
    const l = Math.hypot(tx, tz) || 1;
    tx /= l; tz /= l;
    out.push([p[0] - tz * d, p[1] + tx * d, p[2]]);
  }
  return out;
}

/**
 * Resample a polyline into points every `step` metres, each with its tangent
 * and the normal to the left of travel (outward for a starboard line run
 * from stern to bow; pass outwardSign = -1 to flip).
 */
export function walkPolyline(pts, step, outwardSign = 1) {
  const res = [];
  let carry = step / 2;
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i], b = pts[i + 1];
    const dx = b[0] - a[0], dz = b[1] - a[1];
    const len = Math.hypot(dx, dz);
    if (len < 1e-6) continue;
    const tx = dx / len, tz = dz / len;
    let s = carry;
    while (s < len) {
      res.push({ x: a[0] + tx * s, z: a[1] + tz * s, tx, tz, nx: -tz * outwardSign, nz: tx * outwardSign, tag: b[2] || a[2] });
      s += step;
    }
    carry = s - len;
  }
  return res;
}
