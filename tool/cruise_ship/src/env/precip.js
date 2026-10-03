import * as THREE from 'three/webgpu';
import {
  Fn, vec2, vec3, vec4, float, uniform, attribute, instanceIndex, fract, sin, mod, floor, mix, smoothstep,
  saturate, positionLocal, cameraPosition, texture, normalize, cross, length, select, abs, max, varying,
  modelWorldMatrix, cameraProjectionMatrix, cameraViewMatrix, Discard, If,
} from 'three/tsl';
import { cloud } from './clouds.js';
import { shipU } from '../ship/materials.js';
import { postU } from '../core/post.js';
import { sky } from './atmosphere.js';

// Rain and lightning.
//
// Rain: streaks in a box that travels with the camera, falling and blowing
// with the wind. A roof-height map of the ship (raycast once from the
// collider) hides drops under cover, so the deck 7 promenade stays dry
// while the open pool deck gets soaked.
//
// Lightning: strikes scheduled by the weather, each a branching bolt drawn
// for a few flickering frames, lighting the clouds around it and the scene.

const BOX = 46;          // metres around the camera
const ROOF = { x0: -172, x1: 172, z0: -26, z1: 26, nx: 344, nz: 104 };

export const rainU = {
  amount: uniform(0),
  wind: uniform(new THREE.Vector2(0, 0)),
  time: uniform(0),
  camPos: uniform(new THREE.Vector3()),
};

function roofHeightMap(collider) {
  // Half floats: filterable on every adapter (32-bit float textures are not).
  const data = new Uint16Array(ROOF.nx * ROOF.nz * 4);
  const heights = new Float32Array(ROOF.nx * ROOF.nz);
  const ray = new THREE.Ray();
  const down = new THREE.Vector3(0, -1, 0);
  for (let j = 0; j < ROOF.nz; j++) {
    for (let i = 0; i < ROOF.nx; i++) {
      const x = ROOF.x0 + ((i + 0.5) / ROOF.nx) * (ROOF.x1 - ROOF.x0);
      const z = ROOF.z0 + ((j + 0.5) / ROOF.nz) * (ROOF.z1 - ROOF.z0);
      ray.origin.set(x, 120, z);
      ray.direction.copy(down);
      const hit = collider.bvh.raycastFirst(ray, THREE.DoubleSide);
      const y = hit ? hit.point.y : -100;
      heights[j * ROOF.nx + i] = y;
      data[(j * ROOF.nx + i) * 4] = THREE.DataUtils.toHalfFloat(y);
    }
  }
  const tex = new THREE.DataTexture(data, ROOF.nx, ROOF.nz, THREE.RGBAFormat, THREE.HalfFloatType);
  tex.minFilter = tex.magFilter = THREE.NearestFilter;
  tex.needsUpdate = true;
  tex.userData.heights = heights;
  return tex;
}

/** Highest roof above ship-local (x, z), or -100 off the ship. */
export function roofAt(tex, x, z) {
  const i = Math.floor(((x - ROOF.x0) / (ROOF.x1 - ROOF.x0)) * ROOF.nx);
  const j = Math.floor(((z - ROOF.z0) / (ROOF.z1 - ROOF.z0)) * ROOF.nz);
  if (i < 0 || j < 0 || i >= ROOF.nx || j >= ROOF.nz) return -100;
  return tex.userData.heights[j * ROOF.nx + i];
}

export class Rain {
  constructor(scene, collider, count = 14000) {
    this.roof = roofHeightMap(collider);
    const roof = this.roof;
    const geo = new THREE.InstancedBufferGeometry();
    // A unit quad (x across, y along the streak).
    geo.setAttribute('position', new THREE.Float32BufferAttribute([-0.5, 0, 0, 0.5, 0, 0, 0.5, 1, 0, -0.5, 1, 0], 3));
    geo.setIndex([0, 1, 2, 0, 2, 3]);
    const seeds = new Float32Array(count * 4);
    for (let i = 0; i < count; i++) {
      seeds[i * 4] = Math.random(); seeds[i * 4 + 1] = Math.random(); seeds[i * 4 + 2] = Math.random(); seeds[i * 4 + 3] = Math.random();
    }
    geo.setAttribute('seed', new THREE.InstancedBufferAttribute(seeds, 4));
    geo.instanceCount = count;

    const m = new THREE.MeshBasicNodeMaterial({ transparent: true, depthWrite: false });
    const vAlpha = varying(float(), 'vRainA');
    const vU = varying(float(), 'vRainU');
    m.vertexNode = Fn(() => {
      const s = attribute('seed', 'vec4');
      const fall = float(8.5).add(s.w.mul(2.5));
      const vel = vec3(rainU.wind.x, fall.negate(), rainU.wind.y);
      // Position inside a box that follows the camera, wrapping as it falls.
      const base = vec3(s.x, s.y, s.z).mul(BOX);
      const moved = base.add(vel.mul(rainU.time)).sub(rainU.camPos).add(BOX * 0.5);
      const local = mod(moved, float(BOX)).sub(BOX * 0.5);
      const center = rainU.camPos.add(local);
      // Streak: stretched along the velocity, facing the camera.
      const dir = normalize(vel);
      const toCam = normalize(cameraPosition.sub(center));
      const side = normalize(cross(dir, toCam));
      const len = length(vel).mul(0.045);
      const p = positionLocal;
      const world = center.add(side.mul(p.x.mul(0.012))).add(dir.mul(p.y.sub(0.5).mul(len)));
      // Sheltered? Compare with the roof height map in ship space.
      const sl = shipU.inv.mul(vec4(center, 1.0)).xyz;
      const ruv = vec2(sl.x.sub(ROOF.x0).div(ROOF.x1 - ROOF.x0), sl.z.sub(ROOF.z0).div(ROOF.z1 - ROOF.z0));
      const inside = ruv.x.greaterThan(0.0).and(ruv.x.lessThan(1.0)).and(ruv.y.greaterThan(0.0)).and(ruv.y.lessThan(1.0));
      const roofY = select(inside, texture(roof, ruv).level(0).r, float(-100.0));
      const covered = sl.y.lessThan(roofY.sub(0.2));
      // Fade with distance from the camera and by the rain amount.
      const d = length(local);
      const keep = s.x.lessThan(rainU.amount);
      // Fade out far drops and the few that would streak right across the lens.
      const near = smoothstep(0.8, 3.0, d);
      vAlpha.assign(select(covered.or(keep.not()), float(0.0), smoothstep(BOX * 0.5, BOX * 0.18, d).mul(near)));
      vU.assign(p.x);
      return cameraProjectionMatrix.mul(cameraViewMatrix).mul(vec4(world, 1.0));
    })();
    m.colorNode = Fn(() => {
      const edge = float(1.0).sub(abs(vU).mul(2.0));
      const lum = cloud.ambTop.mul(2.2).add(sky.sunColor.mul(0.04)).add(vec3(0.02));
      return vec4(lum.mul(vec3(0.85, 0.9, 1.0)), vAlpha.mul(edge).mul(0.32));
    })();
    this.mesh = new THREE.Mesh(geo, m);
    this.mesh.frustumCulled = false;
    this.mesh.renderOrder = 5;
    this.mesh.visible = false;
    scene.add(this.mesh);
  }

  update(dt, t, camera, weather, windWorld) {
    const r = weather.current.rain;
    this.mesh.visible = r > 0.01;
    rainU.amount.value = r;
    rainU.time.value = t;
    rainU.camPos.value.copy(camera.position);
    rainU.wind.value.copy(windWorld).multiplyScalar(0.6);
  }
}

/** Branching lightning bolt as a ribbon mesh, rebuilt per strike. */
function boltGeometry(top, bottom, rnd) {
  const segs = [];
  const branch = (a, b, depth, width) => {
    const pts = [a.clone()];
    const n = 18;
    const dir = new THREE.Vector3().subVectors(b, a);
    for (let i = 1; i < n; i++) {
      const t = i / n;
      const p = a.clone().addScaledVector(dir, t);
      const j = dir.length() * 0.035 * (1 - Math.abs(t - 0.5));
      p.x += (rnd() - 0.5) * j * 2; p.z += (rnd() - 0.5) * j * 2;
      pts.push(p);
    }
    pts.push(b.clone());
    for (let i = 0; i < pts.length - 1; i++) segs.push([pts[i], pts[i + 1], width]);
    if (depth > 0) {
      for (let k = 0; k < 3; k++) {
        if (rnd() < 0.55) {
          const i0 = 2 + Math.floor(rnd() * (pts.length - 6));
          const s = pts[i0];
          const e = s.clone().add(new THREE.Vector3((rnd() - 0.5) * 900, -dir.length() * (0.15 + rnd() * 0.25), (rnd() - 0.5) * 900));
          branch(s, e, depth - 1, width * 0.45);
        }
      }
    }
  };
  branch(top, bottom, 2, 9);
  const pos = [], alpha = [];
  for (const [a, b, w] of segs) {
    // Two crossed quads per segment so it reads from any angle.
    for (const off of [new THREE.Vector3(w, 0, 0), new THREE.Vector3(0, 0, w)]) {
      pos.push(a.x - off.x, a.y, a.z - off.z, a.x + off.x, a.y, a.z + off.z, b.x + off.x, b.y, b.z + off.z);
      pos.push(a.x - off.x, a.y, a.z - off.z, b.x + off.x, b.y, b.z + off.z, b.x - off.x, b.y, b.z - off.z);
      for (let k = 0; k < 6; k++) alpha.push(w / 9);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('w', new THREE.Float32BufferAttribute(alpha, 1));
  return g;
}

export class Lightning {
  constructor(scene) {
    this.scene = scene;
    const m = new THREE.MeshBasicNodeMaterial({ transparent: true, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending });
    this.intensity = uniform(0);
    m.colorNode = vec4(vec3(0.85, 0.9, 1.0).mul(this.intensity).mul(attribute('w', 'float').mul(0.7).add(0.3)).mul(60.0), 1.0);
    m.fog = false;
    this.mat = m;
    this.mesh = null;
    this.next = 8;
    this.strike = null;
    this.onStrike = null;     // (distanceMetres, intensity) for thunder
  }

  update(dt, weather, cameraPos) {
    const rate = weather.current.lightning;     // strikes per minute
    let flash = 0;
    if (this.strike) {
      const s = this.strike;
      s.t += dt;
      // A few return strokes: bright pulses decaying over ~0.6 s.
      const pulse = Math.max(0, Math.sin(s.t * 38) * Math.exp(-s.t * 5)) + Math.exp(-s.t * 9) * 0.6;
      flash = pulse * s.power;
      this.intensity.value = flash;
      cloud.flash.value = flash * 6;
      if (s.t > 0.9) { this.strike = null; if (this.mesh) this.mesh.visible = false; }
    } else {
      this.intensity.value = 0;
      cloud.flash.value = 0;
      if (rate > 0.05) {
        this.next -= dt;
        if (this.next <= 0) {
          this._spawn(cameraPos, weather);
          this.next = (60 / rate) * (0.4 + Math.random() * 1.2);
        }
      }
    }
    // Close strikes brighten everything for an instant.
    postU.flash.value = this.strike ? flash * this.strike.near * 1.6 : 0;
  }

  _spawn(cameraPos, weather) {
    const ang = Math.random() * Math.PI * 2;
    const dist = 1800 + Math.random() * 9000;
    const x = cameraPos.x + Math.cos(ang) * dist, z = cameraPos.z + Math.sin(ang) * dist;
    const base = weather.current.base * 1000;
    let s = Math.floor(Math.random() * 1e9);
    const rnd = () => { s = (Math.imul(s, 1664525) + 1013904223) | 0; return (s >>> 0) / 4294967296; };
    const g = boltGeometry(new THREE.Vector3(x, base + 200, z), new THREE.Vector3(x + (rnd() - 0.5) * 600, 0, z + (rnd() - 0.5) * 600), rnd);
    if (this.mesh) { this.mesh.geometry.dispose(); this.mesh.geometry = g; }
    else { this.mesh = new THREE.Mesh(g, this.mat); this.mesh.frustumCulled = false; this.mesh.renderOrder = 6; this.scene.add(this.mesh); }
    this.mesh.visible = Math.random() < 0.75;    // some strikes stay hidden in cloud
    const power = 0.6 + Math.random() * 0.8;
    this.strike = { t: 0, power, near: Math.max(0, 1 - dist / 6000) };
    cloud.flashPos.value.set(x / 1000, weather.current.base + weather.current.thick * 0.35, z / 1000);
    this.onStrike?.(dist, power);
  }
}
