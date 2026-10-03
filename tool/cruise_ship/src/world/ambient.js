import * as THREE from 'three/webgpu';
import {
  Fn, vec2, vec3, vec4, float, uniform, attribute, positionLocal, sin, cos, time, mix, uv, smoothstep, length,
  instanceIndex, cameraPosition, normalize, cross, fract, floor, step, mx_noise_float, texture, positionWorld,
} from 'three/tsl';
import { Builder, mat } from '../ship/kit.js';
import { canvasTexture, shipU } from '../ship/materials.js';
import { cloud } from '../env/clouds.js';
import { sky } from '../env/atmosphere.js';
import { deckY } from '../ship/dims.js';

// Life around the ship: a passing MSC container ship (photo 7), a distant
// cruise ship (photo 15), a hazy mountain coast on the horizon, gulls, the
// funnel's exhaust plume (photos 12, 16) and the Maltese ensign at the stern.

function containerShip() {
  const B = new Builder();
  const L = 366, W = 51;
  // Hull: a long box with a raked bow, dark navy, red below the waterline.
  const shape = new THREE.Shape();
  shape.moveTo(-L / 2, 0); shape.lineTo(L / 2 - 22, 0); shape.quadraticCurveTo(L / 2 + 4, 4, L / 2 + 6, 18);
  shape.lineTo(-L / 2, 18); shape.closePath();
  const hull = new THREE.ExtrudeGeometry(shape, { depth: W, bevelEnabled: false });
  hull.translate(0, -8, -W / 2);
  B.add('hull', hull);
  // Containers: rows of stacks with gaps for the lashing bridges.
  const ct = new THREE.BoxGeometry(12.2, 2.6, 2.44);
  let s = 3;
  const rnd = () => { s = (Math.imul(s, 1103515245) + 12345) | 0; return ((s >>> 0) % 10000) / 10000; };
  for (let x = -L / 2 + 20; x < L / 2 - 40; x += 13.2) {
    if (Math.abs(x - (-L / 2 + 70)) < 10) continue;
    const h = 6 + Math.floor(rnd() * 4);
    for (let zi = -9; zi <= 9; zi++) {
      const hh = h - (Math.abs(zi) > 7 ? 2 : 0);
      for (let k = 0; k < hh; k++) {
        const key = ['cRed', 'cBlue', 'cGrey', 'cOrange', 'cGreen'][Math.floor(rnd() * 5)];
        B.add(key, ct, mat(x, 10 + k * 2.6 + 1.3, zi * 2.5));
      }
    }
  }
  // Bridge house about a third from the stern, funnel at the stern.
  B.boxMM('white', -L / 2 + 62, 10, -16, -L / 2 + 78, 46, 16);
  B.boxMM('dark', -L / 2 + 62, 42, -24, -L / 2 + 78, 45, 24);
  B.boxMM('white', -L / 2 + 6, 10, -8, -L / 2 + 20, 38, 8);
  const g = B.build({
    hull: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#1b1d24'), roughness: 0.6 }),
    white: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#e6e6e2'), roughness: 0.6 }),
    dark: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#202833'), roughness: 0.3 }),
    cRed: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#7c2a22'), roughness: 0.7 }),
    cBlue: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#25456e'), roughness: 0.7 }),
    cGrey: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#8a8c88'), roughness: 0.7 }),
    cOrange: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#b8692b'), roughness: 0.7 }),
    cGreen: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#3d5a44'), roughness: 0.7 }),
  }, { name: 'containerShip', castShadow: false });
  // White MSC letters on both sides of the hull (photo 7).
  const tex = canvasTexture(1024, 256, (c, w, h) => {
    c.clearRect(0, 0, w, h); c.fillStyle = '#f2f2ee';
    c.font = `700 ${h * 0.8}px Arial, sans-serif`; c.textAlign = 'center'; c.textBaseline = 'middle';
    c.fillText('M S C', w / 2, h / 2);
  });
  const m = new THREE.MeshBasicNodeMaterial({ map: tex, transparent: true, alphaTest: 0.3 });
  m.fog = true;
  for (const sz of [1, -1]) {
    const p = new THREE.Mesh(new THREE.PlaneGeometry(64, 16), m);
    p.position.set(20, 2, sz * (W / 2 + 0.1));
    if (sz < 0) p.rotation.y = Math.PI;
    g.add(p);
  }
  return g;
}

function distantCruiseShip() {
  const B = new Builder();
  B.boxMM('white', -140, -6, -16, 140, 16, 16);
  B.boxMM('white', -120, 16, -15, 125, 40, 15);
  B.boxMM('dark', -120, 30, -15.2, 125, 32, 15.2);
  B.boxMM('dark', -40, 40, -6, -10, 52, 6);
  return B.build({
    white: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#e8eaec'), roughness: 0.5 }),
    dark: new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#2d3440'), roughness: 0.4 }),
  }, { name: 'farShip', castShadow: false });
}

function coastline() {
  // A long range of hazy mountains (photo 15), as a terrain strip.
  const g = new THREE.PlaneGeometry(60000, 2000, 300, 12);
  const p = g.attributes.position;
  for (let i = 0; i < p.count; i++) {
    const x = p.getX(i), y = p.getY(i);
    const t = (y + 1000) / 2000;     // 0 shore .. 1 ridge
    const ridge = 700 + 420 * Math.sin(x * 0.00031) + 260 * Math.sin(x * 0.0011 + 2) + 90 * Math.sin(x * 0.0047 + 1) + 40 * Math.sin(x * 0.013);
    p.setZ(i, -t * 4000);
    p.setY(i, Math.max(0, ridge * Math.pow(t, 0.7)) - 20 + (t < 0.05 ? -30 : 0));
  }
  g.computeVertexNormals();
  const m = new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#6d6a5c'), roughness: 1 });
  const mesh = new THREE.Mesh(g, m);
  return mesh;
}

/** Gulls: instanced V shapes with flapping wings, circling. */
function gulls(count = 18) {
  const g = new THREE.BufferGeometry();
  // Body + two wings (each wing two triangles), wing tips get 'flap' weight.
  const pos = [
    // body
    -0.25, 0, 0, 0.3, 0, 0.05, 0.3, 0, -0.05,
    // left wing
    0.05, 0, 0, -0.1, 0, 0, -0.05, 0, 0.75,
    -0.05, 0, 0.75, -0.2, 0, 0.75, -0.1, 0, 0,
    // right wing
    0.05, 0, 0, -0.05, 0, -0.75, -0.1, 0, 0,
    -0.05, 0, -0.75, -0.1, 0, 0, -0.2, 0, -0.75,
  ];
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.computeVertexNormals();
  const m = new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#e9ecee'), roughness: 0.8, side: THREE.DoubleSide });
  const phase = uniform(0);
  m.positionNode = Fn(() => {
    const p = positionLocal.toVar();
    const ph = time.mul(7.0).add(float(instanceIndex).mul(1.37));
    const flap = sin(ph).mul(0.55);
    // Wing tips rise and fall around the shoulder.
    const span = p.z.abs();
    p.y.addAssign(span.mul(flap).mul(0.7).add(span.mul(span).mul(0.25)));
    return p;
  })();
  const mesh = new THREE.InstancedMesh(g, m, count);
  mesh.frustumCulled = false;
  mesh.castShadow = false;
  mesh.userData.birds = Array.from({ length: count }, (_, i) => ({
    r: 20 + Math.random() * 45, h: 30 + Math.random() * 30, a: Math.random() * Math.PI * 2,
    w: (0.18 + Math.random() * 0.25) * (Math.random() < 0.5 ? -1 : 1), cx: -150 + Math.random() * 80, cz: (Math.random() - 0.5) * 40,
    bob: Math.random() * 6,
  }));
  return mesh;
}

/** Exhaust plume: soft camera-facing puffs drifting downwind from the stacks. */
function plume(count = 70) {
  const g = new THREE.InstancedBufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute([-0.5, -0.5, 0, 0.5, -0.5, 0, 0.5, 0.5, 0, -0.5, 0.5, 0], 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute([0, 0, 1, 0, 1, 1, 0, 1], 2));
  g.setIndex([0, 1, 2, 0, 2, 3]);
  const seeds = new Float32Array(count);
  for (let i = 0; i < count; i++) seeds[i] = i / count;
  g.setAttribute('seed', new THREE.InstancedBufferAttribute(seeds, 1));
  g.instanceCount = count;
  const U = { src: uniform(new THREE.Vector3()), wind: uniform(new THREE.Vector3(-10, 1, 0)), t: uniform(0), amount: uniform(1), right: uniform(new THREE.Vector3(1, 0, 0)), up: uniform(new THREE.Vector3(0, 1, 0)) };
  const m = new THREE.MeshBasicNodeMaterial({ transparent: true, depthWrite: false });
  m.fog = true;
  const vAge = attribute('seed', 'float');
  // The mesh sits at the origin, so this "local" position is the world one.
  m.positionNode = Fn(() => {
    const age = fract(vAge.add(U.t.mul(0.045)));
    const life = age.mul(22.0);    // seconds since emission
    const drift = U.wind.mul(life).add(vec3(0.0, life.mul(1.6), 0.0));
    const swirl = vec3(sin(vAge.mul(91.0).add(life.mul(0.5))), cos(vAge.mul(57.0).add(life.mul(0.4))), sin(vAge.mul(33.0))).mul(age.mul(9.0));
    const c = U.src.add(drift).add(swirl);
    const size = float(3.5).add(age.mul(26.0));
    const p = positionLocal;
    return c.add(U.right.mul(p.x.mul(size))).add(U.up.mul(p.y.mul(size)));
  })();
  m.colorNode = Fn(() => {
    const age = fract(vAge.add(U.t.mul(0.045)));
    const d = length(uv().sub(0.5)).mul(2.0);
    const n = mx_noise_float(vec3(uv().mul(3.0), vAge.mul(20.0))).mul(0.35).add(0.65);
    const a = smoothstep(1.0, 0.2, d).mul(n).mul(smoothstep(0.0, 0.05, age)).mul(smoothstep(1.0, 0.45, age)).mul(0.16).mul(U.amount);
    const lit = cloud.ambTop.mul(2.6).add(sky.sunColor.mul(0.09)).mul(vec3(0.92, 0.92, 0.9));
    return vec4(lit, a);
  })();
  const mesh = new THREE.Mesh(g, m);
  mesh.frustumCulled = false;
  mesh.renderOrder = 4;
  mesh.userData.U = U;
  return mesh;
}

/** Malta's civil ensign (the ship's port of registry is Valletta): red, white border, white Maltese cross. */
function ensign() {
  const tex = canvasTexture(256, 128, (c, w, h) => {
    c.fillStyle = '#cf142b'; c.fillRect(0, 0, w, h);
    c.strokeStyle = '#ffffff'; c.lineWidth = h * 0.08;
    c.strokeRect(h * 0.04, h * 0.04, w - h * 0.08, h - h * 0.08);
    // Maltese cross: four arms widening outward, each with a V notch.
    c.fillStyle = '#ffffff';
    c.save(); c.translate(w / 2, h / 2);
    const r = h * 0.3, n = h * 0.1;
    for (let i = 0; i < 4; i++) {
      c.rotate(Math.PI / 2);
      c.beginPath(); c.moveTo(0, 0); c.lineTo(-r * 0.62, -r); c.lineTo(0, -r + n); c.lineTo(r * 0.62, -r); c.closePath(); c.fill();
    }
    c.restore();
  });
  const g = new THREE.PlaneGeometry(3.6, 1.8, 16, 4);
  g.translate(1.8, 0, 0);
  const m = new THREE.MeshStandardNodeMaterial({ map: tex, side: THREE.DoubleSide, roughness: 0.8 });
  const wind = uniform(10);
  m.positionNode = Fn(() => {
    const p = positionLocal.toVar();
    const k = p.x.div(3.6);
    p.z.addAssign(sin(p.x.mul(2.2).sub(time.mul(wind.mul(0.6)))).mul(k).mul(0.35));
    p.y.subAssign(k.mul(k).mul(float(0.6).sub(wind.mul(0.03)).max(0.0)));
    return p;
  })();
  const mesh = new THREE.Mesh(g, m);
  mesh.userData.wind = wind;
  return mesh;
}

export class Ambient {
  constructor(scene, shipRoot) {
    this.scene = scene;
    this.cship = containerShip();
    this.cship.position.set(5200, 0, -1900);
    this.cship.rotation.y = Math.PI;      // heading the other way
    scene.add(this.cship);
    this.farShip = distantCruiseShip();
    this.farShip.position.set(-6000, 0, 7800);
    scene.add(this.farShip);
    this.coast = coastline();
    this.coast.position.set(0, 0, -24000);
    scene.add(this.coast);
    this.gulls = gulls();
    scene.add(this.gulls);
    this.plume = plume();
    scene.add(this.plume);
    // Flagstaff at the stern on deck 16.
    const staff = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.08, 7, 8), new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#d9dde0'), metalness: 0.6, roughness: 0.3 }));
    staff.position.set(-158.6, deckY(16) + 3.5, 0);
    shipRoot.add(staff);
    this.flag = ensign();
    this.flag.position.set(-158.6, deckY(16) + 6.0, 0);
    shipRoot.add(this.flag);
    this._m = new THREE.Matrix4(); this._q = new THREE.Quaternion(); this._e = new THREE.Euler(); this._p = new THREE.Vector3();
  }

  update(dt, t, { port, speed, windWorld, day, camera, funnelTop, shipRoot }) {
    // Traffic only at sea.
    this.cship.visible = !port;
    this.farShip.visible = !port;
    this.coast.visible = !port;
    if (!port) {
      // Container ship on a reciprocal course ~2 km off, about 16 kn.
      this.cship.position.x -= (speed + 8.2) * dt;
      if (this.cship.position.x < -7000) {
        this.cship.position.x = 7000;
        this.cship.position.z = (Math.random() < 0.5 ? -1 : 1) * (1500 + Math.random() * 1500);
      }
      this.farShip.position.x -= (speed - 7.5) * dt;
      if (this.farShip.position.x < -14000) this.farShip.position.x = 14000;
      if (this.farShip.position.x > 14000) this.farShip.position.x = -14000;
    }
    // Gulls by day: circling the stern at sea, the quay in port.
    const birds = this.gulls.userData.birds;
    this.gulls.visible = day > 0.3;
    for (let i = 0; i < birds.length; i++) {
      const b = birds[i];
      b.a += b.w * dt;
      const cx = port ? b.cx + 160 : b.cx, cz = port ? b.cz + 30 : b.cz;
      const x = cx + Math.cos(b.a) * b.r, z = cz + Math.sin(b.a) * b.r;
      const y = b.h + Math.sin(t * 0.3 + b.bob) * 4;
      this._p.set(x, y, z);
      this._e.set(Math.sin(t * 0.5 + b.bob) * 0.2, -b.a - Math.sign(b.w) * Math.PI / 2, Math.sign(b.w) * 0.35);
      this._q.setFromEuler(this._e);
      this._m.compose(this._p, this._q, new THREE.Vector3(1.1, 1.1, 1.1));
      this.gulls.setMatrixAt(i, this._m);
    }
    this.gulls.instanceMatrix.needsUpdate = true;
    // Plume from the stacks, carried by the apparent wind.
    const U = this.plume.userData.U;
    U.t.value = t;
    U.src.value.copy(funnelTop).applyMatrix4(shipRoot.matrixWorld);
    U.wind.value.set(windWorld.x, 0.4, windWorld.y);
    U.amount.value = port ? 0.5 : 1.0;
    const cam = camera.matrixWorld.elements;
    U.right.value.set(cam[0], cam[1], cam[2]);
    U.up.value.set(cam[4], cam[5], cam[6]);
    // Flag flies harder in a stronger apparent wind.
    this.flag.userData.wind.value = Math.min(28, windWorld.length());
    this.flag.rotation.y = Math.atan2(windWorld.y, -windWorld.x) + Math.PI;
  }
}
