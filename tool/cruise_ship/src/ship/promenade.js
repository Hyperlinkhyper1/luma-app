import * as THREE from 'three/webgpu';
import { deckY, PROM, LIFEBOATS, RAFT_RACKS, hullHalf, wallZ, railZ, wallZAt, BALCONY_D, BOW_X, STERN_X, frontX } from './dims.js';
import { Builder, Instancer, mat, prism } from './kit.js';
import { boatParts, boatHullMaterial, plateAtlas, BOAT, boatHalfBeam } from './lifeboat.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { canvasTexture } from './materials.js';
import { closedOutline } from './superstructure.js';

// Deck 7: the open promenade beside the lifeboats (photos 2, 6, 11, 14, 20).
// A teak walkway between the inner wall and a railing, the lifeboat well
// outboard of it with the boats hanging in gravity davits, liferaft racks,
// the ribbed ceiling of the overhang with downlights and diagonal struts.

const Y = deckY(7);
const CEIL = deckY(9);

/** Deck 7 floor across the whole hull (and the forecastle at deck 9). */
function hullOutline(y, x0, x1, step = 2) {
  const pts = [];
  for (let x = x0; x <= x1 + 1e-6; x += step) pts.push([x, Math.max(0.01, hullHalf(x, y) - 0.02)]);
  return pts;
}

export function buildPromenade(M, col, pois) {
  const group = new THREE.Group();
  group.name = 'promenade';
  const B = new Builder();
  const I = new Instancer();

  // --- floors -------------------------------------------------------------------
  {
    const out = hullOutline(Y - 0.2, STERN_X + 0.2, 104, 1.5);
    const poly = closedOutline(out);
    B.add('crewDeck', prism(poly, Y - 0.35, Y));
    col.prism(poly, Y - 1.2, Y);
    // Forecastle (deck 9) up front.
    const fo = hullOutline(deckY(9) - 0.2, 100, BOW_X - 0.4, 1);
    const fpoly = closedOutline(fo);
    B.add('crewDeck', prism(fpoly, deckY(9) - 0.35, deckY(9)));
    col.prism(fpoly, deckY(9) - 1.0, deckY(9));
    // White bulwark round the forecastle: the hull plating carried up past
    // the deck, which is why the bow reads as one smooth white mass.
    const yb = deckY(9);
    const edge = [];
    for (let x = 118; x <= BOW_X - 0.6; x += 1) edge.push([x, Math.max(0.05, hullHalf(x, yb) - 0.02)]);
    const inner = edge.map(([x, z]) => [x - (x > BOW_X - 6 ? 0.3 : 0), Math.max(0.02, z - 0.28)]);
    const ring = [...edge, ...edge.slice().reverse().map(([x, z]) => [x, -z]),
      ...inner.map(([x, z]) => [x, -z]), ...inner.slice().reverse()];
    B.add('paint', prism(ring, yb - 0.3, yb + 1.35));
    col.prism(ring, yb, yb + 1.35);
  }

  for (const side of [1, -1]) {
    const S = side;
    const zw = PROM.wallZ, zr = PROM.railZ;
    // Teak walkway.
    B.boxMM('teak', PROM.x0, Y, S * zw, PROM.x1, Y + 0.025, S * (zr + 0.1));

    // --- inner wall: deck 7 windows and doors, deck 8 windows ---------------------
    B.boxMM('paint', PROM.x0, Y, S * (zw - 0.3), PROM.x1, CEIL, S * zw);
    for (let x = PROM.x0 + 4; x < PROM.x1 - 4; x += 8.2) {
      const door = Math.abs(((x - PROM.x0) % 41) - 4) < 0.1;
      if (door) {
        // Double glass door in a stainless frame, with a canopy light above.
        B.boxMM('stainless', x - 1.05, Y, S * (zw + 0.0), x + 1.05, Y + 2.35, S * (zw + 0.06));
        B.boxMM('cabinGlass', x - 0.95, Y + 0.02, S * (zw + 0.06), x + 0.95, Y + 2.25, S * (zw + 0.08));
        B.boxMM('lampWarm', x - 0.4, Y + 2.5, S * (zw + 0.02), x + 0.4, Y + 2.62, S * (zw + 0.16));
        pois.doors.push({ x, y: Y, z: S * (zw + 0.6), label: 'Stairwell — deck 7', side: S });
      } else {
        B.boxMM('navyGlass', x - 3.2, Y + 0.9, S * zw, x + 3.2, Y + 2.35, S * (zw + 0.04));
      }
      // Deck 8 windows.
      B.boxMM('navyGlass', x - 3.0, Y + DECK8_WIN0, S * zw, x + 3.0, Y + DECK8_WIN1, S * (zw + 0.04));
    }
    // Horizontal rubbing band and a deck 8 sill line.
    B.boxMM('paintShade', PROM.x0, Y + 2.85, S * zw, PROM.x1, Y + 3.05, S * (zw + 0.12));

    // --- ceiling: beams, downlights, struts ---------------------------------------
    // The ceiling is the underside of deck 9 and its balconies, so it follows
    // the deck 9 slab edge: inside the side recess it stops short and the
    // lifeboat well opens to the stepped balcony tiers far above (photo 1).
    const zc0 = zw;
    const edgeAt = (x) => Math.min(railZ(9) - 0.05, wallZAt(9, x) + BALCONY_D - 0.05);
    for (let x = PROM.x0; x <= PROM.x1; x += 3.45) {
      B.boxMM('paintShade', x - 0.13, CEIL - 0.5, S * zc0, x + 0.13, CEIL - 0.02, S * edgeAt(x));
    }
    for (let x = PROM.x0 + 1.7; x < PROM.x1; x += 3.45) {
      // Round downlights over the walkway (photo 8).
      I.add('downlight', mat(x, CEIL - 0.03, S * (zw + 1.7), Math.PI / 2, 0, 0, 0.22, 0.22, 1));
      if (((x - PROM.x0) / 3.45 | 0) % 2 === 0) pois.lamps.push({ x, y: CEIL - 0.25, z: S * (zw + 1.7), intensity: 1.4, range: 11 });
      if (edgeAt(x) > zr + 2.3) I.add('downlight', mat(x, CEIL - 0.03, S * (zr + 1.9), Math.PI / 2, 0, 0, 0.18, 0.18, 1));
    }
    for (let x = PROM.x0 + 3; x < PROM.x1; x += 6.9) {
      const e = edgeAt(x);
      if (e < zw + 2.5) continue;
      const a = new THREE.Vector3(x, CEIL - 0.45, S * (e - 0.3));
      const b = new THREE.Vector3(x - 0.9, Y + 3.1, S * (zw + 0.15));
      B.tube('paint', a, b, 0.11, true);
    }
    // Edge beam of the overhang, in short runs that follow the slab edge.
    for (let x = PROM.x0; x < PROM.x1; x += 1.725) {
      const e0 = edgeAt(x), e1 = edgeAt(x + 1.725);
      const e = (e0 + e1) / 2;
      B.boxMM('paint', x, CEIL - 0.55, S * (e - 0.3), x + 1.74, CEIL, S * (e + 0.05));
    }

    // --- columns on the railing line -------------------------------------------
    for (let x = PROM.x0 + 5; x < PROM.x1; x += 10.35) {
      if (edgeAt(x) < zr + 0.6) continue;     // no slab overhead in the recess
      B.tube('paint', new THREE.Vector3(x, Y, S * (zr + 0.25)), new THREE.Vector3(x, CEIL - 0.4, S * (zr + 0.25)), 0.16);
      col.box(x, (Y + CEIL) / 2, S * (zr + 0.25), 0.36, CEIL - Y, 0.36);
    }

    // --- railing between walkway and lifeboat well (gates left open) -------------
    const gates = LIFEBOATS.filter((b) => b.side === S).map((b) => b.x);
    const railRun = (xa, xb) => {
      if (xb - xa < 0.5) return;
      B.boxMM('woodRail', xa, Y + 1.08, S * (zr - 0.05), xb, Y + 1.16, S * (zr + 0.07));
      for (const hy of [0.32, 0.62, 0.9]) {
        B.tube('steel', new THREE.Vector3(xa, Y + hy, S * zr), new THREE.Vector3(xb, Y + hy, S * zr), 0.022, true);
      }
      for (let x = xa; x <= xb + 1e-6; x += Math.min(1.6, xb - xa)) {
        B.tube('steel', new THREE.Vector3(x, Y, S * zr), new THREE.Vector3(x, Y + 1.1, S * zr), 0.03, true);
      }
      col.box((xa + xb) / 2, Y + 0.6, S * zr, xb - xa, 1.2, 0.16);
    };
    let xPrev = PROM.x0;
    for (const gx of gates.sort((a, b) => a - b)) {
      railRun(xPrev, gx - 0.8);
      xPrev = gx + 0.8;
    }
    railRun(xPrev, PROM.x1);

    // --- outer edge: low bulwark and rails at the hull edge -------------------
    for (let x = PROM.x0; x < PROM.x1; x += 2) {
      const z = hullHalf(x + 1, Y) - 0.12;
      B.boxMM('paint', x, Y, S * (z - 0.15), x + 2.02, Y + 0.32, S * (z + 0.1));
    }
    {
      const z = hullHalf(0, Y) - 0.15;
      for (const hy of [0.55, 0.85, 1.1]) B.tube('steel', new THREE.Vector3(PROM.x0, Y + hy, S * z), new THREE.Vector3(PROM.x1, Y + hy, S * z), 0.025, true);
      for (let x = PROM.x0; x <= PROM.x1; x += 2.4) B.tube('steel', new THREE.Vector3(x, Y, S * z), new THREE.Vector3(x, Y + 1.1, S * z), 0.03, true);
      col.box((PROM.x0 + PROM.x1) / 2, Y + 0.7, S * z, PROM.x1 - PROM.x0, 1.4, 0.2);
    }

    // --- end walls with doors to the stairwells -------------------------------
    for (const [xe, dir] of [[PROM.x0, 1], [PROM.x1, -1]]) {
      const zo = hullHalf(xe, Y) + 0.1;
      B.boxMM('paint', xe - 0.15 * dir, Y, S * zw, xe + 0.15 * dir, CEIL, S * zo);
      const zd = (zw + zr) / 2;
      B.boxMM('stainless', xe + 0.16 * dir - 0.03, Y, S * (zd - 1.0), xe + 0.16 * dir, Y + 2.3, S * (zd + 1.0));
      B.boxMM('cabinGlass', xe + 0.19 * dir - 0.03, Y + 0.05, S * (zd - 0.9), xe + 0.19 * dir, Y + 2.2, S * (zd + 0.9));
      col.box(xe, (Y + CEIL) / 2, S * (zw + zo) / 2, 0.4, CEIL - Y, Math.abs(zo - zw));
      pois.doors.push({ x: xe + dir * 0.8, y: Y, z: S * zd, label: dir > 0 ? 'Aft stairwell — deck 7' : 'Forward stairwell — deck 7', side: S });
    }

    // --- wall fittings: floodlights and CCTV (photo 20) ------------------------------
    for (let x = PROM.x0 + 9; x < PROM.x1; x += 23) {
      B.boxMM('steel', x - 0.25, CEIL - 1.25, S * (zw + 0.02), x + 0.25, CEIL - 0.85, S * (zw + 0.45));
      B.boxMM('lampCool', x - 0.2, CEIL - 1.24, S * (zw + 0.46), x + 0.2, CEIL - 0.9, S * (zw + 0.48));
      B.boxMM('steel', x + 1.5, CEIL - 0.9, S * (zw + 0.02), x + 1.85, CEIL - 0.7, S * (zw + 0.5));
    }

    // --- life rings on the posts ------------------------------------------------
    for (let x = PROM.x0 + 22; x < PROM.x1; x += 31) {
      I.add('ring', mat(x, Y + 1.25, S * (zr - 0.12), 0, 0, 0, 1, 1, 1));
    }
  }

  // --- lifeboats in their davits ---------------------------------------------------
  const boatMats = { hull: boatHullMaterial(), canopy: M.boatOrange, fender: M.rubber, windows: M.boatWindow, tower: M.boatOrange, towerGlass: M.boatWindow, hardware: M.steelDark };
  const boatInst = { lifeboat: new Map(), tender: new Map() };
  const boatY = Y + 1.0;      // keel height, hanging just above the deck
  const plates = [];
  for (const b of LIFEBOATS) {
    const S = b.side;
    const m = mat(b.x, boatY, S * PROM.boatZ, 0, 0, 0);
    const kind = b.tender ? 'tender' : 'lifeboat';
    const map = boatInst[kind];
    for (const part of Object.keys(boatMats)) {
      if (!map.has(part)) map.set(part, []);
      map.get(part).push(m);
    }
    // Number plates on both bows (photo 20: "8 MSC VIRTUOSA / VALLETTA"),
    // collected into one atlas-mapped mesh below.
    const tPlate = 0.8;
    for (const ps of [1, -1]) {
      const zz = boatHalfBeam(tPlate) * 0.99 + 0.03;
      plates.push({ num: b.num, x: b.x + (tPlate - 0.5) * BOAT.L, y: boatY + 1.12, z: S * PROM.boatZ + ps * zz, ry: (ps > 0 ? 0 : Math.PI) + ps * -0.18 });
    }
    // Gravity davits: a post and an arm at each end, wire falls to the hooks.
    for (const t of [0.1, 0.9]) {
      const x = b.x + (t - 0.5) * BOAT.L;
      const z0 = S * (PROM.railZ + 0.55), z1 = S * (PROM.boatZ + 0.1);
      const top = boatY + BOAT.hull + BOAT.canopy + 1.35;
      B.boxMM('steel', x - 0.22, Y, z0 - 0.3, x + 0.22, top - 0.2, z0 + 0.3);
      B.tube('steel', new THREE.Vector3(x, top - 0.6, z0), new THREE.Vector3(x, top, z1), 0.2, true);
      B.tube('steel', new THREE.Vector3(x, Y + 0.6, z0 + S * 0.2), new THREE.Vector3(x, top - 1.5, z0 + S * 1.1), 0.12, true);
      B.tube('black', new THREE.Vector3(x, top, z1), new THREE.Vector3(x, boatY + BOAT.hull + BOAT.canopy - 0.05, z1), 0.025, true);
      B.boxMM('steelDark', x - 0.3, top - 0.25, z1 - 0.3, x + 0.3, top + 0.1, z1 + 0.3);
      col.box(x, (Y + top) / 2, z0, 0.6, top - Y, 0.8);
    }
    col.box(b.x, boatY + 1.6, S * PROM.boatZ, BOAT.L - 0.6, 3.4, BOAT.B);
  }
  {
    const atlas = plateAtlas(LIFEBOATS.map((b) => b.num));
    const geos = [];
    for (const p of plates) {
      const g = new THREE.PlaneGeometry(2.6, 0.65);
      const row = atlas.index.get(p.num);
      const uv = g.attributes.uv;
      for (let i = 0; i < uv.count; i++) uv.setY(i, (atlas.rows - 1 - row + uv.getY(i)) / atlas.rows);
      g.applyMatrix4(mat(p.x, p.y, p.z, 0, p.ry, 0));
      geos.push(g);
    }
    const pm = new THREE.MeshStandardNodeMaterial({ map: atlas.tex, transparent: true, alphaTest: 0.35, roughness: 0.4 });
    group.add(new THREE.Mesh(mergeGeometries(geos), pm));
  }
  // Merge each boat's parts that share a material: four instanced meshes per variant.
  const merged = {
    hull: ['hull'], orange: ['canopy', 'tower'], dark: ['fender', 'hardware'], glass: ['windows', 'towerGlass'],
  };
  const mergedMats = { hull: boatMats.hull, orange: M.boatOrange, dark: M.rubber, glass: M.boatWindow };
  for (const kind of ['lifeboat', 'tender']) {
    const parts = boatParts(kind === 'tender');
    const mats = boatInst[kind].get('hull');
    for (const [name, keys] of Object.entries(merged)) {
      const geo = mergeGeometries(keys.map((k) => { const g = parts[k].index ? parts[k].toNonIndexed() : parts[k].clone(); for (const a of Object.keys(g.attributes)) if (a !== 'position' && a !== 'normal') g.deleteAttribute(a); return g; }));
      const mesh = new THREE.InstancedMesh(geo, mergedMats[name], mats.length);
      mats.forEach((m, i) => mesh.setMatrixAt(i, m));
      mesh.castShadow = name !== 'glass';
      mesh.receiveShadow = true;
      mesh.computeBoundingSphere();
      mesh.name = `boats:${kind}:${name}`;
      group.add(mesh);
    }
  }

  // --- liferaft racks (RFD canisters, photos 2, 11) ---------------------------------
  const capTex = canvasTexture(256, 256, (g, w, h) => {
    g.fillStyle = '#e8eae8'; g.fillRect(0, 0, w, h);
    g.fillStyle = '#1b1d20';
    g.beginPath(); g.arc(w * 0.36, h * 0.6, w * 0.13, 0, Math.PI * 2); g.fill();
    g.beginPath(); g.arc(w * 0.62, h * 0.38, w * 0.13, 0, Math.PI * 2); g.fill();
    g.strokeStyle = '#c9d82a'; g.lineWidth = 16; g.beginPath(); g.moveTo(w * 0.45, h * 0.15); g.lineTo(w * 0.52, h * 0.85); g.stroke();
    g.fillStyle = '#1f3c8c'; g.font = '800 46px Arial, sans-serif'; g.textAlign = 'center'; g.fillText('RFD', w * 0.62, h * 0.18);
  });
  const capMat = new THREE.MeshStandardNodeMaterial({ map: capTex, roughness: 0.55 });
  const canGeo = new THREE.CylinderGeometry(0.36, 0.36, 1.55, 20, 1, true);
  canGeo.rotateZ(Math.PI / 2);
  const capGeo = new THREE.CircleGeometry(0.36, 20);
  for (const xr of RAFT_RACKS) {
    for (const S of [1, -1]) {
      const z0 = S * (PROM.railZ + 0.9);
      // Inclined launching rack sloping outboard.
      const tilt = -S * 0.22;
      for (let row = 0; row < 2; row++) {
        for (let k = 0; k < 4; k++) {
          const x = xr - 3.0 + k * 1.85;
          const z = z0 + S * (row * 0.95);
          const y = Y + 0.55 + row * 0.82 - row * 0.2;
          const m = mat(x, y, z, tilt, 0, 0);
          I.add('canister', m);
          I.add('capA', mat(x + 0.78, y, z, tilt, Math.PI / 2, 0));
          I.add('capB', mat(x - 0.78, y, z, tilt, -Math.PI / 2, 0));
          I.add('strap', mat(x - 0.35, y, z, tilt, 0, 0, 1, 1, 1));
          I.add('strap', mat(x + 0.35, y, z, tilt, 0, 0, 1, 1, 1));
          I.add('bag', mat(x, y - 0.5, z - S * 0.2, tilt, 0, 0));
        }
      }
      // Rack frame.
      for (const dx of [-3.9, 3.9]) {
        B.tube('steel', new THREE.Vector3(xr + dx, Y, z0 - S * 0.4), new THREE.Vector3(xr + dx, Y + 1.9, z0 + S * 0.2), 0.05, true);
        B.tube('steel', new THREE.Vector3(xr + dx, Y + 0.2, z0 - S * 0.5), new THREE.Vector3(xr + dx, Y + 0.2, z0 + S * 1.6), 0.05, true);
      }
      B.tube('steel', new THREE.Vector3(xr - 3.9, Y + 1.9, z0 + S * 0.2), new THREE.Vector3(xr + 3.9, Y + 1.9, z0 + S * 0.2), 0.05, true);
      col.box(xr, Y + 1.0, z0 + S * 0.5, 8.0, 2.0, 2.2);
    }
  }

  const strapGeo = new THREE.TorusGeometry(0.375, 0.035, 6, 20);
  strapGeo.rotateY(Math.PI / 2);
  const bagGeo = new THREE.BoxGeometry(0.5, 0.42, 0.18);
  const ringGeo = new THREE.TorusGeometry(0.34, 0.075, 10, 24);
  const downGeo = new THREE.CircleGeometry(1, 20);
  group.add(I.build({
    downlight: { geometry: downGeo, material: 'lampWarm', castShadow: false },
    canister: { geometry: canGeo, material: 'raftWhite' },
    capA: { geometry: capGeo, material: 'cap', castShadow: false },
    capB: { geometry: capGeo, material: 'cap', castShadow: false },
    strap: { geometry: strapGeo, material: 'strapBlue', castShadow: false },
    bag: { geometry: bagGeo, material: 'bagBlack' },
    ring: { geometry: ringGeo, material: 'lifeRing' },
  }, { ...M, cap: capMat }, { name: 'promenadeProps' }));

  group.add(B.build(M, { name: 'promenade' }));

  // Spawn points.
  pois.spots.push(
    { id: 'deck7-stbd', deck: 7, area: 'Promenade · starboard', x: 30, y: Y, z: 15.2, yaw: Math.PI, pitch: 0.18, label: 'Deck 7 · Lifeboats (starboard)' },
    { id: 'deck7-port', deck: 7, area: 'Promenade · port', x: 30, y: Y, z: -15.2, yaw: 0, pitch: 0.18, label: 'Deck 7 · Lifeboats (port)' },
    { id: 'deck7-aft', deck: 7, area: 'Promenade · aft', x: -118, y: Y, z: 15.2, yaw: Math.PI / 2 + 0.25, pitch: 0.25, label: 'Deck 7 · Aft end' },
  );
  return group;
}

const DECK8_WIN0 = 3.55, DECK8_WIN1 = 4.85;
export { CEIL as PROM_CEIL };
