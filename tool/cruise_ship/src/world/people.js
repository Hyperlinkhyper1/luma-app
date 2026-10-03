import * as THREE from 'three/webgpu';
import {
  Fn, vec3, vec4, float, uniform, attribute, instancedBufferAttribute, positionLocal, sin, cos, select, mix,
  time, step, abs,
} from 'three/tsl';
import { deckY, PROM } from '../ship/dims.js';
import { settings } from '../core/settings.js';

// Passengers: a sparse crowd of simple instanced figures. They sunbathe on
// the loungers and swim in the pools by day, lean on the railings, and a
// few walk the promenade and the top decks (legs and arms swing in the
// vertex shader). Numbers follow the time of day and the rain.

const SKIN = [[0.93, 0.76, 0.64], [0.82, 0.62, 0.48], [0.62, 0.43, 0.3], [0.38, 0.25, 0.18]];
const SHIRT = [[0.92, 0.92, 0.9], [0.15, 0.25, 0.5], [0.75, 0.2, 0.18], [0.95, 0.75, 0.25], [0.3, 0.55, 0.4], [0.1, 0.1, 0.12], [0.85, 0.5, 0.6], [0.4, 0.65, 0.85]];
const PANTS = [[0.15, 0.2, 0.35], [0.85, 0.82, 0.74], [0.1, 0.1, 0.1], [0.45, 0.3, 0.22], [0.25, 0.45, 0.7]];
const HAIR = [[0.06, 0.045, 0.035], [0.22, 0.14, 0.08], [0.55, 0.42, 0.25], [0.7, 0.7, 0.68], [0.12, 0.08, 0.05]];

/**
 * One figure, ~1.72 m, facing +x, feet at y = 0. Vertex attribute 'part':
 * 0 head/neck (skin), 1 torso (shirt), 2 hips (pants), 3 left leg, 4 right
 * leg (pants, skin below the knee), 5 left arm, 6 right arm (skin).
 */
function figureGeometry() {
  const parts = [];
  const add = (geo, part, x, y, z, sx = 1, sy = 1, sz = 1) => {
    geo.scale(sx, sy, sz);
    geo.translate(x, y, z);
    const g = geo.toNonIndexed();
    const n = g.attributes.position.count;
    g.setAttribute('part', new THREE.Float32BufferAttribute(new Array(n).fill(part), 1));
    parts.push(g);
  };
  // Rounded capsules throughout so figures hold up at arm's length.
  const cap = (r, len) => new THREE.CapsuleGeometry(r, len, 4, 10);
  add(new THREE.SphereGeometry(0.105, 16, 12), 0, 0.005, 1.615, 0, 0.94, 1.12, 0.86);   // head
  add(new THREE.SphereGeometry(0.112, 16, 8, 0, Math.PI * 2, 0, Math.PI * 0.55), 7, -0.012, 1.632, 0, 0.98, 1.0, 0.92); // hair
  add(new THREE.SphereGeometry(0.03, 8, 6), 0, 0.0, 1.6, 0.1, 0.5, 1.2, 1);          // ears
  add(new THREE.SphereGeometry(0.03, 8, 6), 0, 0.0, 1.6, -0.1, 0.5, 1.2, 1);
  add(cap(0.052, 0.08), 0, 0, 1.47, 0);                                              // neck
  add(cap(0.155, 0.3), 1, 0, 1.2, 0, 0.72, 1, 1.18);                                 // chest
  add(new THREE.SphereGeometry(0.075, 12, 8), 1, 0, 1.38, 0.175, 1, 0.85, 1);        // shoulders
  add(new THREE.SphereGeometry(0.075, 12, 8), 1, 0, 1.38, -0.175, 1, 0.85, 1);
  add(cap(0.14, 0.08), 2, 0, 0.93, 0, 0.72, 1, 1.12);                                // hips
  for (const [part, z] of [[3, 0.088], [4, -0.088]]) {
    add(cap(0.078, 0.34), part, 0, 0.66, z);                                         // thigh
    add(cap(0.062, 0.36), part, 0, 0.27, z);                                         // shin
    add(new THREE.BoxGeometry(0.24, 0.07, 0.095), part, 0.05, 0.035, z);             // foot
  }
  for (const [part, z] of [[5, 0.215], [6, -0.215]]) {
    add(cap(0.05, 0.22), part, 0, 1.23, z);                                          // upper arm
    add(cap(0.043, 0.22), part, 0.015, 0.96, z * 1.02);                              // forearm
    add(new THREE.SphereGeometry(0.045, 8, 6), part, 0.02, 0.8, z * 1.03, 0.8, 1.2, 0.6); // hand
  }
  let n = 0;
  for (const g of parts) n += g.attributes.position.count;
  const pos = new Float32Array(n * 3), nor = new Float32Array(n * 3), prt = new Float32Array(n);
  let o = 0;
  for (const g of parts) {
    pos.set(g.attributes.position.array, o * 3);
    nor.set(g.attributes.normal.array, o * 3);
    prt.set(g.attributes.part.array, o);
    o += g.attributes.position.count;
  }
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  out.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
  out.setAttribute('part', new THREE.BufferAttribute(prt, 1));
  return out;
}

const MAX = 420;

export class People {
  constructor(shipRoot, pois) {
    this.root = shipRoot;
    const geo = figureGeometry();
    this.skin = new THREE.InstancedBufferAttribute(new Float32Array(MAX * 3), 3);
    this.shirt = new THREE.InstancedBufferAttribute(new Float32Array(MAX * 3), 3);
    this.pants = new THREE.InstancedBufferAttribute(new Float32Array(MAX * 3), 3);
    this.anim = new THREE.InstancedBufferAttribute(new Float32Array(MAX * 2), 2);   // gait amount, phase
    geo.setAttribute('iSkin', this.skin);
    geo.setAttribute('iShirt', this.shirt);
    geo.setAttribute('iPants', this.pants);
    this.hair = new THREE.InstancedBufferAttribute(new Float32Array(MAX * 3), 3);
    geo.setAttribute('iHair', this.hair);
    geo.setAttribute('iAnim', this.anim);

    const m = new THREE.MeshStandardNodeMaterial({ roughness: 0.8 });
    const part = attribute('part', 'float');
    const anim = attribute('iAnim', 'vec2');
    m.positionNode = Fn(() => {
      const p = positionLocal.toVar();
      // Swing legs from the hip and arms from the shoulder, in opposition.
      const ph = time.mul(5.2).add(anim.y);
      const swing = sin(ph).mul(anim.x);
      const leg = select(part.equal(3.0), swing, select(part.equal(4.0), swing.negate(), float(0.0))).mul(0.42);
      const arm = select(part.equal(5.0), swing.negate(), select(part.equal(6.0), swing, float(0.0))).mul(0.35);
      const pivotY = select(part.greaterThan(4.5), float(1.42), float(0.84));
      const a = leg.add(arm);
      const dy = p.y.sub(pivotY);
      const ca = cos(a), sa = sin(a);
      p.x.assign(p.x.mul(ca).sub(dy.mul(sa)));
      p.y.assign(pivotY.add(dy.mul(ca)).add(positionLocal.x.mul(sa)));
      return p;
    })();
    m.colorNode = Fn(() => {
      const skin = attribute('iSkin', 'vec3');
      const shirt = attribute('iShirt', 'vec3');
      const pants = attribute('iPants', 'vec3');
      const hair = attribute('iHair', 'vec3');
      const lowLeg = positionLocal.y.lessThan(0.48);
      const sleeve = positionLocal.y.greaterThan(1.13);
      // skin | shirt | shorts | legs (shorts above the knee) | arms (short sleeves) | hair
      return select(part.lessThan(0.5), skin,
        select(part.lessThan(1.5), shirt,
          select(part.lessThan(2.5), pants,
            select(part.lessThan(4.5), select(lowLeg, skin, pants),
              select(part.lessThan(6.5), select(sleeve, shirt, skin), hair)))));
    })();
    this.mesh = new THREE.InstancedMesh(geo, m, MAX);
    this.mesh.castShadow = true;
    this.mesh.receiveShadow = true;
    this.mesh.frustumCulled = false;
    this.mesh.count = 0;
    shipRoot.add(this.mesh);

    this._seed = 1234;
    this.slots = this._layout(pois);
    this.walkers = this.slots.filter((s) => s.kind === 'walk');
    this._lastBand = -1;
  }

  _rnd() { this._seed = (Math.imul(this._seed, 1664525) + 1013904223) | 0; return (this._seed >>> 0) / 4294967296; }

  /** Possible places for people, each with a time-of-day preference. */
  _layout() {
    const r = () => this._rnd();
    const S = [];
    const Y16 = deckY(16), Y17 = deckY(17), Y19 = deckY(19), Y7 = deckY(7);
    // Sunbathers on the loungers (positions match topdecks.js rows).
    for (const s of [1, -1]) {
      for (let x = -16; x < 44; x += 1.05) if (r() < 0.55) S.push({ kind: 'lie', x, y: Y16 + 0.55, z: s * 17.2, ry: s > 0 ? Math.PI / 2 : -Math.PI / 2, day: 1 });
      for (let x = -18; x < 44; x += 1.05) if (r() < 0.4) S.push({ kind: 'lie', x, y: Y17 + 0.55, z: s * 16.4, ry: s > 0 ? -Math.PI / 2 : Math.PI / 2, day: 1 });
      for (let x = 68; x < 118; x += 1.05) if (r() < 0.25) S.push({ kind: 'lie', x, y: Y19 + 0.55, z: s * 12.5, ry: s > 0 ? Math.PI / 2 : -Math.PI / 2, day: 1 });
      for (let x = -3; x < 36; x += 3.2) if (r() < 0.7) S.push({ kind: 'lie', x, y: Y16 + 0.6, z: s * (9.8), ry: s > 0 ? Math.PI / 2 : -Math.PI / 2, day: 1 });
    }
    // Swimmers in the main and aft pools (head and shoulders above water).
    for (let i = 0; i < 26; i++) S.push({ kind: 'swim', x: -3 + r() * 38, y: Y16 + 0.12 - 1.38, z: (r() - 0.5) * 11, ry: r() * 6.28, day: 1 });
    for (let i = 0; i < 8; i++) S.push({ kind: 'swim', x: -149 + r() * 14, y: Y16 + 0.16 - 1.38, z: (r() - 0.5) * 8, ry: r() * 6.28, day: 1 });
    // At the railings: promenade, galleries, top deck, aft deck. Day and night.
    for (const s of [1, -1]) {
      for (let k = 0; k < 9; k++) S.push({ kind: 'stand', x: PROM.x0 + 8 + r() * (PROM.x1 - PROM.x0 - 16), y: Y7, z: s * (PROM.railZ - 0.45), ry: s > 0 ? -Math.PI / 2 : Math.PI / 2, day: 0.5 });
      for (let k = 0; k < 6; k++) S.push({ kind: 'stand', x: -18 + r() * 60, y: Y17, z: s * 20.6, ry: s > 0 ? -Math.PI / 2 : Math.PI / 2, day: 0.6 });
      for (let k = 0; k < 4; k++) S.push({ kind: 'stand', x: -155 + r() * 25, y: Y16, z: s * (13 + r() * 4), ry: r() * 6.28, day: 0.4 });
    }
    // Walkers: back and forth along a path.
    for (const s of [1, -1]) {
      for (let k = 0; k < 6; k++) S.push({ kind: 'walk', path: [[PROM.x0 + 6, Y7, s * (PROM.wallZ + 1.0 + r() * 1.6)], [PROM.x1 - 6, Y7, s * (PROM.wallZ + 1.0 + r() * 1.6)]], t: r(), speed: 1.1 + r() * 0.5, day: 0.5 });
      for (let k = 0; k < 4; k++) S.push({ kind: 'walk', path: [[-18, Y16, s * (11.5 + r())], [42, Y16, s * (11.5 + r())]], t: r(), speed: 1.0 + r() * 0.4, day: 0.8 });
      for (let k = 0; k < 3; k++) S.push({ kind: 'walk', path: [[-118, deckY(18), s * (17 + r())], [-26, deckY(18), s * (17 + r())]], t: r(), speed: 1.3 + r() * 0.6, day: 0.6 });
    }
    // Colours.
    for (const p of S) {
      p.skin = SKIN[Math.floor(r() * SKIN.length)];
      p.shirt = p.kind === 'lie' || p.kind === 'swim' ? (r() < 0.6 ? p.skin : SHIRT[Math.floor(r() * SHIRT.length)]) : SHIRT[Math.floor(r() * SHIRT.length)];
      p.pants = PANTS[Math.floor(r() * PANTS.length)];
      p.hair = HAIR[Math.floor(r() * HAIR.length)];
      p.roll = r();
      p.phase = r() * 6.28;
    }
    return S.slice(0, MAX);
  }

  update(dt, { night, rain, hour }) {
    const enabled = settings.get().people.enabled;
    // Activity: sunbathers from mid-morning to late afternoon; fewer at night;
    // rain empties the open decks.
    const sun = THREE.MathUtils.smoothstep(hour, 9, 10.5) * (1 - THREE.MathUtils.smoothstep(hour, 17.5, 19.5));
    const awake = 1 - night * 0.75;
    const _m = this._m || (this._m = new THREE.Matrix4());
    const _q = this._q || (this._q = new THREE.Quaternion());
    const _e = this._e || (this._e = new THREE.Euler());
    const _p = this._p || (this._p = new THREE.Vector3());
    const _s = this._s || (this._s = new THREE.Vector3(1, 1, 1));
    let n = 0;
    if (enabled) {
      for (const p of this.slots) {
        let want;
        if (p.kind === 'lie' || p.kind === 'swim') want = sun * (1 - rain);
        else if (p.kind === 'stand') want = awake * (1 - rain * 0.8) * (p.day + (1 - p.day) * (1 - sun));
        else want = awake * (1 - rain * 0.6);
        if (p.roll > want) continue;
        let gait = 0;
        if (p.kind === 'walk') {
          p.t += (dt * p.speed) / Math.hypot(p.path[1][0] - p.path[0][0], p.path[1][2] - p.path[0][2]);
          const u = p.t % 2, f = u < 1 ? u : 2 - u;
          const a = p.path[0], b = p.path[1];
          _p.set(a[0] + (b[0] - a[0]) * f, a[1], a[2] + (b[2] - a[2]) * f);
          const dir = u < 1 ? 1 : -1;
          _e.set(0, Math.atan2(-(b[2] - a[2]) * dir, (b[0] - a[0]) * dir), 0);
          gait = 1;
        } else if (p.kind === 'lie') {
          // Lying on the back along the lounger, head on the backrest: the
          // figure's feet are its origin, so shift it to the lounger's foot.
          _p.set(p.x + Math.cos(p.ry) * 0.95, p.y, p.z - Math.sin(p.ry) * 0.95);
          _e.set(0, p.ry, Math.PI / 2 - 0.1, 'YXZ');
        } else {
          _p.set(p.x, p.y, p.z);
          _e.set(0, p.ry, 0);
        }
        _q.setFromEuler(_e);
        _m.compose(_p, _q, _s);
        this.mesh.setMatrixAt(n, _m);
        this.skin.setXYZ(n, ...p.skin);
        this.shirt.setXYZ(n, ...p.shirt);
        this.pants.setXYZ(n, ...p.pants);
        this.hair.setXYZ(n, ...p.hair);
        this.anim.setXY(n, gait, p.phase);
        n++;
      }
    }
    this.mesh.count = n;
    this.mesh.instanceMatrix.needsUpdate = true;
    this.skin.needsUpdate = this.shirt.needsUpdate = this.pants.needsUpdate = this.hair.needsUpdate = this.anim.needsUpdate = true;
  }
}
