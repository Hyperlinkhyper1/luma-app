import * as THREE from 'three/webgpu';
import { Fn, vec2, vec3, float, mix, smoothstep, floor, fract, sin, dot, mx_noise_float, positionWorld, normalWorld, abs, step } from 'three/tsl';
import { Builder, Instancer, mat } from '../ship/kit.js';
import { Collider } from '../ship/collider.js';
import { hullHalf, deckY } from '../ship/dims.js';
import { shipU } from '../ship/materials.js';

// The port: the ship moored starboard-side to a cruise quay, as in the
// reference photos from Cadiz, Malaga, Alicante and Melilla. A concrete
// quay with fenders and bollards, the terminal under its wave roof, the
// covered elevated walkway with the gangway, floodlight masts, mooring
// lines, container cranes and a berthed container ship, palms, and the
// old city across the harbour with its cathedral dome.

const QY = 2.6;            // quay level above the water
const QZ = 24.2;           // quay edge (hull + fenders)

const hash = (p) => fract(sin(dot(p, vec2(127.1, 311.7))).mul(43758.5453));

function concrete() {
  const m = new THREE.MeshStandardNodeMaterial({ roughness: 0.92 });
  m.colorNode = Fn(() => {
    const p = positionWorld;
    const n = mx_noise_float(p.mul(0.08)).mul(0.06).add(mx_noise_float(p.mul(0.9)).mul(0.04));
    // Expansion joints every 12 m, darker oil stains here and there.
    const jx = smoothstep(0.012, 0.0, abs(fract(p.x.div(12.0)).sub(0.5)).sub(0.488));
    const stain = smoothstep(0.55, 0.8, mx_noise_float(p.mul(0.05).add(7.0))).mul(0.12);
    const c = vec3(0.56, 0.55, 0.52).mul(float(1.0).add(n).sub(stain)).mul(float(1.0).sub(jx.mul(0.35)));
    return c.mul(float(1.0).sub(shipU.wet.mul(0.4)));
  })();
  return m;
}

function cityMaterial() {
  const m = new THREE.MeshStandardNodeMaterial({ roughness: 0.85 });
  m.colorNode = Fn(() => {
    const p = positionWorld;
    // Whitewashed and ochre facades with window rows.
    const cell = floor(vec2(p.x.add(p.z).div(9.0), 0.0));
    const tone = hash(cell);
    const base = mix(vec3(0.86, 0.84, 0.78), vec3(0.78, 0.62, 0.42), step(0.7, tone));
    const wx = fract(p.x.add(p.z).div(3.2)), wy = fract(p.y.div(3.1));
    const win = step(0.35, wx).mul(step(wx, 0.7)).mul(step(0.3, wy)).mul(step(wy, 0.72)).mul(step(0.2, abs(normalWorld.y).oneMinus()));
    return mix(base, vec3(0.18, 0.2, 0.22), win.mul(0.8));
  })();
  m.emissiveNode = Fn(() => {
    const p = positionWorld;
    const wx = fract(p.x.add(p.z).div(3.2)), wy = fract(p.y.div(3.1));
    const win = step(0.35, wx).mul(step(wx, 0.7)).mul(step(0.3, wy)).mul(step(wy, 0.72));
    const lit = step(0.6, hash(floor(vec2(p.x.add(p.z).div(3.2), p.y.div(3.1)))));
    return vec3(1.0, 0.75, 0.45).mul(win.mul(lit)).mul(shipU.night).mul(shipU.lightBoost).mul(0.12);
  })();
  return m;
}

function containerMaterial() {
  const m = new THREE.MeshStandardNodeMaterial({ roughness: 0.7, metalness: 0.2 });
  m.colorNode = Fn(() => {
    const p = positionWorld;
    // One colour per container (2.5 x 2.6 x 12.2 m boxes), corrugation stripes.
    const c = floor(vec3(p.x.div(12.4), p.y.div(2.6), p.z.div(2.5)));
    const h = fract(sin(dot(c, vec3(12.9898, 78.233, 37.719))).mul(43758.5453));
    const pal = mix(mix(vec3(0.55, 0.12, 0.08), vec3(0.08, 0.22, 0.45), step(0.3, h)), mix(vec3(0.72, 0.68, 0.6), vec3(0.75, 0.42, 0.1), step(0.75, h)), step(0.55, h));
    const rib = smoothstep(0.4, 0.5, abs(fract(p.x.mul(3.0)).sub(0.5))).mul(0.12);
    return pal.mul(float(1.0).sub(rib));
  })();
  return m;
}

export class Port {
  constructor(scene, M) {
    this.group = new THREE.Group();
    this.group.name = 'port';
    this.collider = new Collider();
    this.pois = { spots: [], doors: [] };
    const B = new Builder();
    const I = new Instancer();
    const col = this.collider;
    const mats = {
      ...M,
      concrete: concrete(),
      city: cityMaterial(),
      containers: containerMaterial(),
      roofMetal: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#bdb6a8'), roughness: 0.5, metalness: 0.5 }),
      termGlass: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#1d2a33'), roughness: 0.08, metalness: 0.3 }),
      craneYellow: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#e3a91c'), roughness: 0.5, metalness: 0.3 }),
      craneBlue: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#27548d'), roughness: 0.5, metalness: 0.3 }),
      cshipHull: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#1f3f6c'), roughness: 0.5 }),
      cshipRed: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#6d1d18'), roughness: 0.6 }),
      rope: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#d8d0bb'), roughness: 0.9 }),
      palmTrunk: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#6b5640'), roughness: 0.9 }),
      palmLeaf: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#3e6b2f'), roughness: 0.8, side: THREE.DoubleSide }),
      hills: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#7d7a6a'), roughness: 1 }),
      domeGold: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#c79d4a'), roughness: 0.4, metalness: 0.6 }),
      carBody: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#d9dcdf'), roughness: 0.3, metalness: 0.5 }),
      carDark: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#2a2e33'), roughness: 0.3, metalness: 0.5 }),
      bollardYellow: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#e3c21b'), roughness: 0.6 }),
    };

    // --- quay -------------------------------------------------------------------
    const qx0 = -420, qx1 = 430, qz1 = 140;
    B.boxMM('concrete', qx0, -6, QZ, qx1, QY, qz1);
    col.boxMM(qx0, -6, QZ, qx1, QY, qz1);
    // Edge kerb, fenders, bollards.
    B.boxMM('concrete', qx0, QY, QZ, qx1, QY + 0.25, QZ + 0.6);
    for (let x = qx0 + 10; x < qx1; x += 16) {
      I.add('fender', mat(x, QY - 1.6, QZ - 0.55, Math.PI / 2, 0, 0, 1, 1, 1));
    }
    const bollards = [];
    for (let x = qx0 + 20; x < qx1; x += 24) {
      I.add('bollard', mat(x, QY, QZ + 1.6, 0, 0, 0));
      bollards.push(new THREE.Vector3(x, QY + 0.7, QZ + 1.6));
      col.box(x, QY + 0.5, QZ + 1.6, 0.8, 1.0, 0.8);
    }
    // Yellow-black traffic bollards along the walkway line (photo 10).
    for (let x = -150; x < 180; x += 6) I.add('postY', mat(x, QY, QZ + 8.5, 0, 0, 0));

    // --- mooring lines: bow and stern lines, springs ----------------------------
    const fair = (x, y) => new THREE.Vector3(x, y, hullHalf(x, y) + 0.1);
    const lines = [
      [fair(150, 18), 3], [fair(146, 18), 3], [fair(152, 17), 2], [fair(140, 17.5), 1],
      [fair(-150, 17.5), -3], [fair(-154, 17.5), -3], [fair(-146, 17), -2], [fair(-130, 17), -1],
      [fair(60, 9.5), -1], [fair(-40, 9.5), 1],
    ];
    for (const [from, dir] of lines) {
      // Pick a bollard ahead/astern of the fairlead.
      const target = bollards.reduce((best, b) => {
        const want = from.x + dir * 22;
        return Math.abs(b.x - want) < Math.abs(best.x - want) ? b : best;
      }, bollards[0]);
      const pts = [];
      for (let i = 0; i <= 24; i++) {
        const t = i / 24;
        const p = from.clone().lerp(target, t);
        p.y -= Math.sin(Math.PI * t) * 1.4;        // gentle sag
        pts.push(p);
      }
      B.add('rope', new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 24, 0.07, 6, false));
    }

    // --- covered elevated walkway with the gangway (photos 1, 17, 18) -------------
    {
      const z0 = QZ + 4.2, z1 = QZ + 8.2, y0 = 6.8;
      const wx0 = -120, wx1 = 150;
      B.boxMM('concrete', wx0, y0 - 0.9, z0, wx1, y0, z1);
      for (let x = wx0 + 4; x < wx1; x += 18) {
        B.boxMM('concrete', x - 0.5, QY, (z0 + z1) / 2 - 0.6, x + 0.5, y0 - 0.9, (z0 + z1) / 2 + 0.6);
        col.box(x, (QY + y0) / 2, (z0 + z1) / 2, 1.0, y0 - QY, 1.2);
      }
      // Railings and the arched corrugated roof on black bents.
      for (const z of [z0 + 0.1, z1 - 0.1]) {
        B.tube('stainless', new THREE.Vector3(wx0, y0 + 1.05, z), new THREE.Vector3(wx1, y0 + 1.05, z), 0.04, true);
        B.tube('stainless', new THREE.Vector3(wx0, y0 + 0.55, z), new THREE.Vector3(wx1, y0 + 0.55, z), 0.03, true);
      }
      for (let x = wx0; x <= wx1; x += 3) {
        for (const z of [z0 + 0.1, z1 - 0.1]) B.tube('stainless', new THREE.Vector3(x, y0, z), new THREE.Vector3(x, y0 + 1.05, z), 0.025, true);
      }
      for (let x = wx0 + 2; x < wx1; x += 9) {
        for (const z of [z0 + 0.15, z1 - 0.15]) B.tube('black', new THREE.Vector3(x, y0, z), new THREE.Vector3(x, y0 + 2.6, z), 0.08, true);
      }
      const arch = new THREE.Shape();
      const hw = (z1 - z0) / 2 + 0.6;
      arch.moveTo(-hw, 0);
      arch.quadraticCurveTo(0, 1.6, hw, 0);
      arch.lineTo(hw, 0.12);
      arch.quadraticCurveTo(0, 1.72, -hw, 0.12);
      arch.closePath();
      const roof = new THREE.ExtrudeGeometry(arch, { depth: wx1 - wx0, bevelEnabled: false, curveSegments: 16 });
      roof.rotateY(Math.PI / 2);
      roof.translate(wx0, y0 + 2.6, (z0 + z1) / 2);
      B.add('roofMetal', roof);
      // Gangway stub to the shell door at deck 3 (x = -25).
      const gx = -25;
      B.boxMM('concrete', gx - 1.6, y0 - 0.5, QZ - 2.8, gx + 1.6, y0, z0);
      B.boxMM('roofMetal', gx - 1.8, y0 + 2.5, QZ - 2.8, gx + 1.8, y0 + 2.75, z0);
      B.boxMM('termGlass', gx - 1.6, y0, QZ - 2.8, gx - 1.5, y0 + 2.5, z0);
      B.boxMM('termGlass', gx + 1.5, y0, QZ - 2.8, gx + 1.6, y0 + 2.5, z0);
      col.boxMM(wx0, y0 - 0.9, z0, wx1, y0, z1);
      col.boxMM(wx0, y0, z0 - 0.1, wx1, y0 + 1.2, z0 + 0.1);
      col.boxMM(wx0, y0, z1 - 0.1, wx1, y0 + 1.2, z1 + 0.1);
      // Stairs from the quay up to the walkway.
      const sx0 = 60, sx1 = 72;
      const n = Math.round((y0 - QY) / 0.18);
      for (let i = 0; i < n; i++) {
        const x = sx0 + ((sx1 - sx0) / n) * (i + 0.5);
        B.box('concrete', x, QY + ((y0 - QY) / n) * (i + 1) - 0.09, z1 + 1.1, (sx1 - sx0) / n + 0.02, 0.18, 2.0);
      }
      col.ramp(new THREE.Vector3(sx0 - 0.3, QY, z1 + 1.1), new THREE.Vector3(sx1 + 0.3, y0, z1 + 1.1), 2.0);
      col.boxMM(sx1, y0 - 0.9, z1, sx1 + 3, y0, z1 + 2.2);
      B.boxMM('concrete', sx1, y0 - 0.9, z1, sx1 + 3, y0, z1 + 2.2);
      this.pois.doors.push({ x: gx, y: y0, z: z0 + 0.8, label: 'Gangway — board the ship', board: true });
    }

    // --- terminal building with the wave roof (photo 12) -------------------------
    {
      const tx0 = -110, tx1 = 110, tz0 = 52, tz1 = 82, h = 8.5;
      B.boxMM('termGlass', tx0, QY, tz0, tx1, QY + h - 1.5, tz0 + 0.3);
      B.boxMM('paint', tx0, QY, tz0 + 0.3, tx1, QY + h - 1.5, tz1);
      col.boxMM(tx0, QY, tz0, tx1, QY + h, tz1);
      // Corrugated wave roof: a long arched shell with ribs.
      const prof = new THREE.Shape();
      const W = tz1 - tz0 + 6;
      prof.moveTo(-W / 2, 0);
      prof.bezierCurveTo(-W / 4, 3.2, W / 4, 3.2, W / 2, 0.6);
      prof.lineTo(W / 2, 0.85);
      prof.bezierCurveTo(W / 4, 3.45, -W / 4, 3.45, -W / 2, 0.25);
      prof.closePath();
      const rg = new THREE.ExtrudeGeometry(prof, { depth: tx1 - tx0 + 8, bevelEnabled: false, curveSegments: 20 });
      rg.rotateY(Math.PI / 2);
      rg.translate(tx0 - 4, QY + h - 1.5, (tz0 + tz1) / 2 - 1.5);
      B.add('roofMetal', rg);
      for (let x = tx0 - 3; x <= tx1 + 3; x += 0.9) {
        B.box('steelDark', x, QY + h + 1.1, (tz0 + tz1) / 2 - 1.5, 0.06, 0.08, W - 1);
      }
      // Entrance canopy and signage strip.
      B.boxMM('navy', -14, QY + 4.2, tz0 - 6, 14, QY + 4.6, tz0);
    }

    // --- floodlight masts (photo 10) ---------------------------------------------
    for (let x = -300; x <= 300; x += 42) {
      const z = QZ + 14;
      B.tube('steelDark', new THREE.Vector3(x, QY, z), new THREE.Vector3(x, QY + 22, z), 0.22);
      for (let k = 0; k < 4; k++) {
        const yy = QY + 14 + k * 2.2;
        B.box('steelDark', x + 0.5, yy, z, 0.5, 0.25, 0.25);
        I.add('flood', mat(x + 0.9, yy, z - 0.2, 0, 0, 0, 0.6, 0.45, 0.45));
      }
    }

    // --- palms and parked cars (photo 12) --------------------------------------------
    const palmTrunk = new THREE.CylinderGeometry(0.22, 0.32, 1, 8);
    palmTrunk.translate(0, 0.5, 0);
    const frond = new THREE.PlaneGeometry(4.4, 0.9, 6, 1);
    {
      const p = frond.attributes.position;
      for (let i = 0; i < p.count; i++) { const x = p.getX(i); p.setY(i, p.getY(i) - (x + 2.2) * (x + 2.2) * 0.07); }
      frond.translate(2.2, 0, 0);
      frond.computeVertexNormals();
    }
    for (let i = 0; i < 26; i++) {
      const x = 120 + (i % 13) * 7 + Math.random() * 2, z = 60 + Math.floor(i / 13) * 9 + Math.random() * 2;
      const h = 9 + Math.random() * 5;
      I.add('palmTrunk', mat(x, QY, z, (Math.random() - 0.5) * 0.15, 0, (Math.random() - 0.5) * 0.15, 1, h, 1));
      for (let k = 0; k < 9; k++) {
        I.add('palmLeaf', mat(x, QY + h, z, 0, (k / 9) * Math.PI * 2 + Math.random(), -0.3 - Math.random() * 0.4, 1, 1, 1));
      }
      col.box(x, QY + h / 2, z, 0.6, h, 0.6);
    }
    const carBody = new THREE.BoxGeometry(4.4, 0.9, 1.8); carBody.translate(0, 0.65, 0);
    const carTop = new THREE.BoxGeometry(2.4, 0.6, 1.6); carTop.translate(-0.2, 1.4, 0);
    for (let i = 0; i < 18; i++) {
      const x = -60 + i * 6.2, z = 100 + (i % 2) * 6;
      I.add(i % 3 === 0 ? 'carDark' : 'carBody', mat(x, QY, z, 0, Math.PI / 2, 0));
      I.add('carTop', mat(x, QY, z, 0, Math.PI / 2, 0));
      col.box(x, QY + 0.8, z, 1.9, 1.6, 4.5);
    }

    // --- container terminal: cranes and a berthed container ship (photo 10) -------
    {
      const cx0 = 210, cx1 = 420;
      // Container ship alongside ahead of the cruise ship.
      // Same berth line as the cruise ship, just ahead of her bow.
      const L = cx1 - cx0 - 10, Bm = 42;
      const zs = QZ - 0.8, zp = zs - Bm;
      B.boxMM('cshipHull', cx0 + 5, -1, zp, cx0 + 5 + L, 11, zs);
      B.boxMM('cshipRed', cx0 + 5, -9, zp + 0.2, cx0 + 5 + L, -1, zs - 0.2);
      // Container stacks.
      for (let x = cx0 + 20; x < cx0 + L - 40; x += 12.4) {
        const stack = 5 + Math.floor(Math.random() * 4);
        B.boxMM('containers', x, 11, zp + 1, x + 12.2, 11 + stack * 2.6, zs - 1);
      }
      // Bridge house aft.
      B.boxMM('paint', cx0 + L - 30, 11, zp + 6, cx0 + L - 16, 36, zs - 6);
      B.boxMM('termGlass', cx0 + L - 30.2, 32, zp + 6, cx0 + L - 29.9, 34.5, zs - 6);
      // Gantry cranes on the quay beside it.
      for (let k = 0; k < 3; k++) {
        const x = cx0 + 40 + k * 60;
        for (const z of [QZ + 4, QZ + 34]) {
          for (const dx of [-8, 8]) B.tube('craneYellow', new THREE.Vector3(x + dx, QY, z), new THREE.Vector3(x + dx * 0.7, QY + 42, z), 0.9, true);
        }
        B.boxMM('craneYellow', x - 9, QY + 40, QZ + 2, x + 9, QY + 43, QZ + 36);
        B.boxMM('craneBlue', x - 2, QY + 44, QZ - 60, x + 2, QY + 47.5, QZ + 50);
        B.boxMM('craneBlue', x - 3.5, QY + 40, QZ + 10, x + 3.5, QY + 52, QZ + 18);
        B.tube('steelDark', new THREE.Vector3(x, QY + 52, QZ + 14), new THREE.Vector3(x, QY + 47.5, QZ - 55), 0.12, true);
        B.tube('steelDark', new THREE.Vector3(x, QY + 52, QZ + 14), new THREE.Vector3(x, QY + 47.5, QZ + 48), 0.12, true);
      }
    }

    // --- the old city across the harbour (photo 11) -----------------------------
    {
      let s = 9;
      const rnd = () => { s = (Math.imul(s, 1103515245) + 12345) | 0; return ((s >>> 0) % 10000) / 10000; };
      const zc = -760;
      // Harbour wall.
      B.boxMM('concrete', -900, -4, zc + 40, 900, 3.2, zc + 70);
      for (let x = -880; x < 880; x += 9 + rnd() * 14) {
        const w = 8 + rnd() * 16, d = 12 + rnd() * 30;
        const h = 9 + rnd() * rnd() * 34 + (Math.abs(x) < 250 ? 6 : 0);
        const zz = zc + 30 - rnd() * 120;
        B.boxMM('city', x, 3, zz - d, x + w, 3 + h, zz);
        if (rnd() < 0.3) B.boxMM('city', x + w * 0.2, 3 + h, zz - d * 0.6, x + w * 0.7, 3 + h + 3, zz - d * 0.2);
      }
      // Cathedral: drum, golden dome, two bell towers.
      const cx = 120, cz = zc - 60;
      B.boxMM('city', cx - 28, 3, cz - 50, cx + 28, 30, cz + 10);
      B.tube('city', new THREE.Vector3(cx, 30, cz - 20), new THREE.Vector3(cx, 42, cz - 20), 11);
      const dome = new THREE.SphereGeometry(11.5, 32, 16, 0, Math.PI * 2, 0, Math.PI / 2);
      dome.scale(1, 1.25, 1);
      dome.translate(cx, 42, cz - 20);
      B.add('domeGold', dome);
      B.tube('city', new THREE.Vector3(cx, 56, cz - 20), new THREE.Vector3(cx, 62, cz - 20), 1.6);
      for (const tx of [cx - 24, cx + 24]) {
        B.boxMM('city', tx - 5, 3, cz + 4, tx + 5, 52, cz + 14);
        B.tube('domeGold', new THREE.Vector3(tx, 52, cz + 9), new THREE.Vector3(tx, 60, cz + 9), 3.2, true);
      }
      // A tall white tower block on the waterfront (photo 11, left).
      B.boxMM('city', -260, 3, zc + 10, -236, 50, zc - 14);
      // Palms along the waterfront.
      for (let x = -600; x < 600; x += 22) {
        const h = 10 + rnd() * 5;
        I.add('palmTrunk', mat(x, 3, zc + 36, 0, 0, 0, 1, h, 1));
        for (let k = 0; k < 8; k++) I.add('palmLeaf', mat(x, 3 + h, zc + 36, 0, (k / 8) * Math.PI * 2, -0.4, 1, 1, 1));
      }
      // Hills behind the city.
      const hills = new THREE.PlaneGeometry(5200, 900, 120, 20);
      const hp = hills.attributes.position;
      for (let i = 0; i < hp.count; i++) {
        const x = hp.getX(i), y = hp.getY(i);
        const ridge = 180 + 110 * Math.sin(x * 0.0021) + 60 * Math.sin(x * 0.0057 + 1.3) + 25 * Math.sin(x * 0.019);
        hp.setZ(i, 0);
        hp.setY(i, y > 0 ? Math.max(0, ridge * (y / 450)) : 0);
      }
      hills.computeVertexNormals();
      hills.translate(0, 0, -3600);
      B.add('hills', hills);
    }

    this.group.add(B.build(mats, { name: 'port' }));
    const fender = new THREE.CylinderGeometry(0.75, 0.75, 3.2, 16);
    const bollard = mergeBollard();
    const postY = new THREE.CylinderGeometry(0.12, 0.12, 0.9, 10); postY.translate(0, 0.45, 0);
    const flood = new THREE.BoxGeometry(1, 1, 1);
    const carT = carTop;
    this.group.add(I.build({
      fender: { geometry: fender, material: 'rubber' },
      bollard: { geometry: bollard, material: 'black' },
      postY: { geometry: postY, material: 'bollardYellow' },
      flood: { geometry: flood, material: 'lampCool', castShadow: false },
      palmTrunk: { geometry: palmTrunk, material: 'palmTrunk' },
      palmLeaf: { geometry: frond, material: 'palmLeaf' },
      carBody: { geometry: carBody, material: 'carBody' },
      carDark: { geometry: carBody, material: 'carDark' },
      carTop: { geometry: carT, material: 'termGlass' },
    }, mats, { name: 'portProps' }));

    this.collider.build();
    this.group.visible = false;
    this.collider.enabled = false;
    scene.add(this.group);

    this.pois.spots.push({ id: 'quay', deck: 0, area: 'Quay', x: 40, y: QY, z: QZ + 18, yaw: -Math.PI / 2 - 0.5, pitch: 0.42, label: 'Quay · beside the hull', portOnly: true });
    this.pois.spots.push({ id: 'walkway', deck: 0, area: 'Quay walkway', x: -60, y: 6.8, z: QZ + 6.2, yaw: Math.PI / 2 + 2.6, pitch: 0.35, label: 'Quay · covered walkway', portOnly: true });
  }

  setVisible(v) {
    this.group.visible = v;
    this.collider.enabled = v;
  }
}

function mergeBollard() {
  const a = new THREE.CylinderGeometry(0.32, 0.4, 0.8, 14); a.translate(0, 0.4, 0);
  const b = new THREE.CylinderGeometry(0.5, 0.5, 0.15, 14); b.translate(0, 0.85, 0);
  const geos = [a, b].map((g) => g.toNonIndexed());
  let n = 0; for (const g of geos) n += g.attributes.position.count;
  const pos = new Float32Array(n * 3), nor = new Float32Array(n * 3);
  let o = 0;
  for (const g of geos) { pos.set(g.attributes.position.array, o * 3); nor.set(g.attributes.normal.array, o * 3); o += g.attributes.position.count; }
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  out.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
  return out;
}
