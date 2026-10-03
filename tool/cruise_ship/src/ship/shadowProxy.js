import * as THREE from 'three/webgpu';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

// Shadow casting, batched. The ship is static in its own frame, so every
// static shadow caster (merged meshes and all their instances) is baked
// into a few position-only proxy meshes, split along the hull so each
// cascade can cull the ones it doesn't see. The proxies write no colour or
// depth in the main pass; the real meshes stop casting. Each shadow cascade
// then costs a handful of draw calls instead of one per part, which was
// most of the CPU time per frame.

const CHUNKS = [[-200, -90], [-90, 0], [0, 90], [90, 200]];

export function buildShadowProxy(root) {
  root.updateMatrixWorld(true);
  const inv = new THREE.Matrix4().copy(root.matrixWorld).invert();
  const buckets = CHUNKS.map(() => []);
  const m = new THREE.Matrix4();
  const tmp = new THREE.Matrix4();
  const center = new THREE.Vector3();
  const take = (geo, matrix) => {
    const g = new THREE.BufferGeometry();
    const src = geo.index ? geo.toNonIndexed() : geo;
    g.setAttribute('position', src.attributes.position.clone());
    g.applyMatrix4(matrix);
    g.computeBoundingBox();
    g.boundingBox.getCenter(center);
    const i = CHUNKS.findIndex(([a, b]) => center.x >= a && center.x < b);
    buckets[i < 0 ? (center.x < 0 ? 0 : CHUNKS.length - 1) : i].push(g);
  };
  const casters = [];
  root.traverse((o) => {
    if (!o.isMesh || !o.castShadow || o.userData.dynamicShadow) return;
    casters.push(o);
  });
  for (const o of casters) {
    tmp.multiplyMatrices(inv, o.matrixWorld);
    if (o.isInstancedMesh) {
      for (let i = 0; i < o.count; i++) {
        o.getMatrixAt(i, m);
        take(o.geometry, new THREE.Matrix4().multiplyMatrices(tmp, m));
      }
    } else {
      take(o.geometry, tmp);
    }
    o.castShadow = false;
  }
  const mat = new THREE.MeshBasicNodeMaterial({ colorWrite: false, depthWrite: false });
  mat.side = THREE.DoubleSide;
  const group = new THREE.Group();
  group.name = 'shadowProxy';
  buckets.forEach((list, i) => {
    if (!list.length) return;
    // Merge in batches of geometries to keep each merge cheap.
    const parts = [];
    for (let k = 0; k < list.length; k += 3000) parts.push(mergeGeometries(list.slice(k, k + 3000), false));
    const geo = parts.length === 1 ? parts[0] : mergeGeometries(parts, false);
    geo.computeBoundingSphere();
    const mesh = new THREE.Mesh(geo, mat);
    mesh.castShadow = true;
    mesh.receiveShadow = false;
    mesh.renderOrder = -10;
    mesh.name = `shadowProxy:${i}`;
    group.add(mesh);
  });
  root.add(group);
  return group;
}
