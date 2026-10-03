import * as THREE from 'three/webgpu';
import { makeMaterials } from './materials.js';
import { buildHull } from './hull.js';
import { buildSuperstructure } from './superstructure.js';
import { buildPromenade } from './promenade.js';
import { buildTopDecks } from './topdecks.js';
import { Collider } from './collider.js';
import { buildShadowProxy } from './shadowProxy.js';

// Assembles the ship. Each builder adds its meshes, its share of the
// walkable collider, and points of interest (spawn spots, doors, lamps).

export async function buildShip(progress = () => {}) {
  const M = makeMaterials();
  const col = new Collider();
  const pois = { spots: [], doors: [], lamps: [] };
  const root = new THREE.Group();
  root.name = 'ship';

  const steps = [
    ['Lofting the hull…', () => buildHull(M)],
    ['Stacking 1,500 balconies…', () => buildSuperstructure(M, col)],
    ['Hanging the lifeboats…', () => buildPromenade(M, col, pois)],
    ['Filling the pools, raising the funnel…', () => buildTopDecks(M, col, pois)],
  ];
  for (let i = 0; i < steps.length; i++) {
    const [msg, fn] = steps[i];
    progress(i / steps.length, msg);
    await new Promise((r) => setTimeout(r, 16));
    root.add(fn());
  }
  col.build();
  progress(0.98, 'Batching shadows…');
  await new Promise((r) => setTimeout(r, 16));
  buildShadowProxy(root);
  return { root, collider: col, pois, materials: M };
}
