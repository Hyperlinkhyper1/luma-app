import * as THREE from 'three/webgpu';
import {
  deckY, CABIN_DECKS, BRIDGE_DECK, POOL_DECK, BALCONY_D, CABIN_W, wallLine, wallZ, railZ, recessWallZ,
  frontX, backX, RECESS, PROM, hullHalf, DECK_H, STERN_CORNER, STERN_X, HULL_HALF_TOP,
} from './dims.js';
import { Builder, Instancer, prism, walkPolyline, offsetPolyline, mat } from './kit.js';
import { buildForward, isFrontWall } from './forward.js';

// The cabin block, decks 9-15: a stack of extruded deck outlines dressed in
// instanced balconies along each deck's wall line, the stepped side recess
// under the pool-deck overhang with its diagonal struts, the curved bow and
// stern tiers, stair towers, and the bridge with its protruding wings.

/** Closed plan outline of a deck from its starboard wall line. */
function closedOutline(starboard) {
  const pts = starboard.map(([x, z]) => [x, z]);
  for (let i = starboard.length - 1; i >= 0; i--) pts.push([starboard[i][0], -starboard[i][1]]);
  return pts;
}

/** x ranges on the sides kept free of balconies (stair towers). */
const TOWERS = [[-146.5, -141.5], [RECESS.x0 - 8.5, RECESS.x0 - 3.5], [44, 49], [110, 115]];
const inTower = (x) => TOWERS.some(([a, b]) => x > a && x < b);

export function buildSuperstructure(M, col) {
  const group = new THREE.Group();
  group.name = 'superstructure';
  const B = new Builder();
  const I = new Instancer();

  const H = DECK_H;
  // --- deck cores (closed volumes) ---------------------------------------------
  for (const n of CABIN_DECKS) {
    const line = wallLine(n);
    const outline = closedOutline(line);
    const g = prism(outline, deckY(n), deckY(n + 1));
    B.add('paint', g);
    // Thin slab edge band at every floor (the white horizontal lines in photos).
  }

  // --- balconies -----------------------------------------------------------------
  const up = new THREE.Vector3(0, 1, 0);
  const placeBalcony = (x, y, z, nx, nz, side, kind = 'std') => {
    // Local frame: +z outward (normal), +x along the facade, +y up.
    const n = new THREE.Vector3(nx, 0, nz);
    const t = new THREE.Vector3().crossVectors(up, n).normalize();
    const basis = new THREE.Matrix4().makeBasis(t, up, n);
    basis.setPosition(x, y, z);
    I.add('slab', basis);
    I.add('fascia', basis);
    I.add('glass', basis);
    I.add('rail', basis);
    I.add('fin', basis);
    I.add('door', basis);
    I.add('header', basis);
    if (kind === 'top') I.add('roof', basis);
  };

  const facadeCount = { total: 0 };
  for (const n of CABIN_DECKS) {
    const y = deckY(n);
    const line = wallLine(n);
    for (const side of [1, -1]) {
      const pts = line.map(([x, z, tag]) => [x, z * side, tag]);
      // Starboard runs stern->bow with outward on the left of travel; port is mirrored.
      const samples = walkPolyline(pts, CABIN_W, side > 0 ? 1 : -1);
      for (const s of samples) {
        if (inTower(s.x) && (s.tag === 'side')) continue;
        // The stern corners are plain curved walls on the real ship.
        if (s.tag === 'corner') continue;
        // The bridge deck has glazing across the front instead of balconies.
        if (n === BRIDGE_DECK && s.x > frontX(n) - 30) continue;
        // The front of the block is a windowed wall (forward.js), not balconies.
        if (s.tag === 'bow' && isFrontWall(n, s.x)) continue;
        placeBalcony(s.x, y, s.z, s.nx, s.nz, side, n === CABIN_DECKS[CABIN_DECKS.length - 1] ? 'top' : 'std');
        facadeCount.total++;
      }
    }
  }

  const W = CABIN_W, D = BALCONY_D;
  const box = (sx, sy, sz, cx, cy, cz) => {
    const g = new THREE.BoxGeometry(sx, sy, sz);
    g.translate(cx, cy, cz);
    return g;
  };
  // Divider fins have a rounded outer edge, like the photos.
  const finShape = new THREE.Shape();
  finShape.moveTo(0, 0);
  finShape.lineTo(D - 0.35, 0);
  finShape.quadraticCurveTo(D + 0.02, 0, D + 0.02, 0.35);
  finShape.lineTo(D + 0.02, H - 0.55);
  finShape.quadraticCurveTo(D + 0.02, H - 0.2, D - 0.3, H - 0.2);
  finShape.lineTo(0, H - 0.2);
  finShape.closePath();
  const finGeo = new THREE.ExtrudeGeometry(finShape, { depth: 0.12, bevelEnabled: false, curveSegments: 4 });
  // shape x -> local z (outward), shape y -> up, extrude -> along facade
  finGeo.rotateY(-Math.PI / 2);
  finGeo.translate(W / 2 + 0.06, 0, 0);

  const defs = {
    slab: { geometry: box(W, 0.24, D, 0, -0.12, D / 2), material: 'paintShade' },
    fascia: { geometry: box(W, 0.34, 0.1, 0, -0.1, D + 0.02), material: 'paint' },
    glass: { geometry: box(W - 0.14, 0.98, 0.025, 0, 0.6, D - 0.05), material: 'railGlass', castShadow: false },
    rail: { geometry: box(W, 0.07, 0.09, 0, 1.12, D - 0.05), material: 'paint' },
    fin: { geometry: finGeo, material: 'paint' },
    door: { geometry: box(W - 0.32, 2.15, 0.05, 0, 1.08, 0.03), material: 'cabinGlass', castShadow: false },
    header: { geometry: box(W, 0.55, 0.06, 0, H - 0.47, 0.03), material: 'paint', castShadow: false },
    roof: { geometry: box(W, 0.3, D + 0.25, 0, H - 0.15, (D + 0.25) / 2), material: 'paint' },
  };
  group.add(I.build(defs, M, { name: 'balconies' }));

  // --- stair towers on the sides -------------------------------------------------
  for (const [x0, x1] of TOWERS) {
    const xm = (x0 + x1) / 2;
    for (const side of [1, -1]) {
      const n0 = CABIN_DECKS[0], n1 = CABIN_DECKS[CABIN_DECKS.length - 1];
      const z0 = wallZ(n0) - 0.5, z1 = railZ(n1) + 0.05;
      B.boxMM('paint', x0, deckY(n0), side * z0, x1, deckY(n1 + 1), side * z1);
      // A column of small windows up the tower face.
      for (let n = n0; n <= n1; n++) {
        B.box('navyGlass', xm, deckY(n) + 1.55, side * (z1 + 0.02), 2.2, 1.2, 0.04);
      }
    }
  }

  // --- side recess: overhang underside ribs and the diagonal struts ---------------
  const zTop = railZ(CABIN_DECKS[CABIN_DECKS.length - 1]) + 0.35;
  const yo = deckY(POOL_DECK);
  for (const side of [1, -1]) {
    const dTop = wallZ(15) - recessWallZ(15);
    const xa = RECESS.x0 - dTop - 1, xb = RECESS.x1 + dTop + 1;
    // Ribs under the overhang (transverse beams).
    for (let x = xa; x <= xb; x += CABIN_W) {
      B.boxMM('paintShade', x - 0.12, yo - 0.55, side * recessWallZ(15), x + 0.12, yo - 0.02, side * zTop);
    }
    // Long edge beam.
    B.boxMM('paint', xa, yo - 0.7, side * (zTop - 0.35), xb, yo, side * zTop);
    // Struts: from the overhang edge down to the recessed wall three decks lower.
    for (let x = RECESS.x0 + 2; x <= RECESS.x1 - 1; x += CABIN_W * 2) {
      const a = new THREE.Vector3(x, yo - 0.6, side * (zTop - 0.25));
      const b = new THREE.Vector3(x - 1.5, deckY(12) + 1.6, side * (recessWallZ(12) + 0.3));
      B.tube('paint', a, b, 0.17);
      // Secondary tie back to the wall at the overhang.
      B.tube('paint', a, new THREE.Vector3(x, yo - 0.6, side * (recessWallZ(15) + 0.2)), 0.1, true);
    }
  }

  // --- general edge of the pool deck over the balconies, with brackets -----------
  // (the slab itself is built by the top decks; brackets give the photo-2 look)
  for (const side of [1, -1]) {
    for (let x = -150; x < 140; x += CABIN_W * 3) {
      if (x > RECESS.x0 - 8 && x < RECESS.x1 + 8) continue;
      const a = new THREE.Vector3(x, yo - 0.3, side * (railZ(15) + 0.2));
      const b = new THREE.Vector3(x, yo - 1.9, side * wallZ(15));
      B.tube('paint', a, b, 0.08, true);
    }
  }

  // --- front walls of windows and the bridge (forward.js) -------------------------
  buildForward(B, col, CABIN_DECKS);

  // --- stern corners: blank curved walls flush with the balcony fronts ------------
  // (photos from astern: the aft balconies sit between two big white rounded
  // corners that run from deck 9 up to the top decks).
  {
    const n0 = CABIN_DECKS[0], n1 = CABIN_DECKS[CABIN_DECKS.length - 1];
    const rc = STERN_CORNER, D = BALCONY_D;
    const arc = (cx, cz, r, side, N = 16) => {
      const pts = [];
      for (let i = 0; i <= N; i++) {
        const a = (i / N) * Math.PI / 2;
        pts.push([cx - Math.cos(a) * r, side * (cz + Math.sin(a) * r)]);
      }
      return pts;
    };
    for (const side of [1, -1]) {
      const cx = backX(n0) + rc, cz = wallZ(n0) - rc;
      const ring = [...arc(cx, cz, rc + D, side), ...arc(cx, cz, rc - 0.2, side).reverse()];
      B.add('paint', prism(ring, deckY(n0) - 0.35, deckY(n1 + 1)));
      // A shallow joint line at every deck, like the panel seams on the real walls.
      for (let n = n0 + 1; n <= n1; n++) {
        const groove = [...arc(cx, cz, rc + D + 0.025, side), ...arc(cx, cz, rc + D - 0.05, side).reverse()];
        B.add('paintShade', prism(groove, deckY(n) - 0.05, deckY(n) + 0.05));
      }
    }
  }

  // --- stern: the dark two-deck glass block of decks 7-8 ---------------------------
  // It wraps the stern and runs forward along both sides to the start of the
  // promenade, standing slightly proud of the hull (photos from astern).
  {
    const y0 = deckY(7) - 0.3, y1 = deckY(9) - 0.35;
    const xb = STERN_X - 0.25, zo = HULL_HALF_TOP + 0.55, rc = 6;
    const half = [[PROM.x0, zo]];
    for (let i = 0; i <= 10; i++) {
      const a = (i / 10) * Math.PI / 2;
      half.push([xb + rc - Math.sin(a) * rc, zo - rc + Math.cos(a) * rc]);
    }
    const loop = [...half, ...half.slice().reverse().map(([x, z]) => [x, -z])];
    B.add('navyGlass', prism(loop, y0 + 0.35, y1 - 0.3));
    B.add('paint', prism(loop, y1 - 0.3, y1 + 0.05));        // white edge on top (deck 9 floor)
    B.add('paint', prism(loop, y0, y0 + 0.35));               // and below it
  }

  // --- the bow below the cabins: closed front over the forecastle ------------------
  {
    const y0 = deckY(7), y1 = deckY(9);
    const pts = [];
    const xf = frontX(9) - 6, bl = 26, zw = wallZ(9);
    pts.push([PROM.x1, PROM.wallZ]);
    pts.push([xf - bl, zw]);
    for (let i = 1; i <= 12; i++) {
      const a = (i / 12) * Math.PI / 2;
      pts.push([xf - bl + Math.sin(a) * bl, Math.cos(a) * zw]);
    }
    B.add('paint', prism(closedOutline(pts.map((p) => [p[0], p[1]])), y0, y1));
  }

  group.add(B.build(M, { name: 'superstructure' }));
  group.userData.balconies = facadeCount.total;

  // Colliders for the cabin block (solid volume; nobody walks in here).
  if (col) {
    for (const n of CABIN_DECKS) {
      const line = wallLine(n);
      col.prism(closedOutline(line), deckY(n), deckY(n + 1));
    }
  }
  return group;
}

export { closedOutline };
