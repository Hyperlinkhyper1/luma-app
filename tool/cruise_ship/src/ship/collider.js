import * as THREE from 'three/webgpu';
import { MeshBVH } from 'three-mesh-bvh';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { prism } from './kit.js';

// Walkable/blocking geometry, in ship-local coordinates. Kept deliberately
// simple (boxes, extruded outlines and ramps for stairs) and separate from
// the visual meshes; the walker collides a capsule against its BVH.

function clean(g) {
  const n = g.index ? g.toNonIndexed() : g;
  for (const k of Object.keys(n.attributes)) if (k !== 'position') n.deleteAttribute(k);
  return n;
}

export class Collider {
  constructor() {
    this.geos = [];
    this.enabled = true;
  }

  box(cx, cy, cz, sx, sy, sz, ry = 0) {
    const g = new THREE.BoxGeometry(Math.abs(sx), Math.abs(sy), Math.abs(sz));
    if (ry) g.rotateY(ry);
    g.translate(cx, cy, cz);
    this.geos.push(clean(g));
  }

  boxMM(x0, y0, z0, x1, y1, z1) {
    this.box((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0);
  }

  prism(poly, y0, y1) {
    this.geos.push(clean(prism(poly, y0, y1)));
  }

  /** A walkable slab from a (bottom) to b (top) of the given width: stairs. */
  ramp(a, b, width, thick = 0.3) {
    const d = new THREE.Vector3().subVectors(b, a);
    const len = d.length();
    const g = new THREE.BoxGeometry(len, thick, width);
    const dir = d.clone().normalize();
    const flat = new THREE.Vector3(dir.x, 0, dir.z).normalize();
    const yaw = Math.atan2(-flat.z, flat.x);
    const pitch = Math.asin(dir.y);
    g.rotateZ(pitch);
    g.rotateY(yaw);
    const mid = new THREE.Vector3().addVectors(a, b).multiplyScalar(0.5);
    // Top surface on the line a-b.
    g.translate(mid.x, mid.y - thick / 2, mid.z);
    this.geos.push(clean(g));
  }

  geometry(g) { this.geos.push(clean(g.clone())); }

  build() {
    const merged = mergeGeometries(this.geos, false);
    this.geometry = merged;
    this.bvh = new MeshBVH(merged, { maxLeafSize: 12 });
    merged.boundsTree = this.bvh;
    this.mesh = new THREE.Mesh(merged, new THREE.MeshBasicNodeMaterial({ wireframe: true, color: 0xff00ff }));
    this.mesh.visible = false;
    this.geos = [];
    return this;
  }
}
