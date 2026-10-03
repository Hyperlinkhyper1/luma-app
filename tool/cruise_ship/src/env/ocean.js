import * as THREE from 'three/webgpu';
import {
  Fn, vec2, vec3, vec4, float, uniform, uniformArray, texture, dot, sqrt, exp, max, min, clamp, mix, length,
  normalize, smoothstep, saturate, Loop, If, select, pow, abs, sin, cos, varying, positionLocal, positionWorld,
  cameraPosition, modelWorldMatrix, equirectUV, reflect, luminance, fract, sign, atan,
} from 'three/tsl';
import { sky } from './atmosphere.js';
import { cloud, cloudTex, WEATHER_TILE } from './clouds.js';
import { sea } from './sky.js';
import { makeSeaDetail } from './noise.js';
import { BEAUFORT_HS } from './weather.js';

// The sea: a camera-centred polar grid displaced by a Gerstner wave
// spectrum (Pierson-Moskowitz wind sea plus a long swell), shaded with
// Fresnel sky reflection, a GGX sun glitter path, subsurface colour in the
// crests, whitecaps from the surface Jacobian, moving cloud shadows and
// the ship's own bow wave and Kelvin wake.
//
// The ship stays at the origin and the water flows past it: each wave's
// phase includes the distance sailed, computed in double precision on the
// CPU and wrapped, so nothing jitters however long the voyage.

export const N_WAVES = 40;
const G = 9.81;

export const ocean = {
  wA: uniformArray(new Array(N_WAVES).fill(0).map(() => new THREE.Vector4()), 'vec4'),  // dirX, dirZ, k, amp
  wB: uniformArray(new Array(N_WAVES).fill(0).map(() => new THREE.Vector4()), 'vec4'),  // Q, phase, lambda, 0
  shipSpeed: uniform(9.26),      // m/s through the water
  flow: uniform(new THREE.Vector2()),   // detail scroll (distance sailed, wrapped)
  time: uniform(0),
  rough: uniform(0.06),
  whitecap: uniform(0.0),
  rain: uniform(0.0),
  port: uniform(0.0),            // 1 in the harbour: calm, green-grey water
  hs: uniform(1.0),
  camXZ: uniform(new THREE.Vector2()),
  envTex: null,
};

/** Waterline half-breadth of the hull (m) at ship x; mirrors ship/hull.js. */
export const hullHalfBeamWL = Fn(([x]) => {
  const mid = float(20.2);
  const bowT = saturate(x.sub(86.0).div(160.0 - 86.0));
  const bow = mid.mul(pow(max(float(1.0).sub(pow(bowT, 2.6)), 0.0), 0.62));
  const sternT = saturate(x.add(150.0).div(-14.0));
  const stern = mid.mul(float(1.0).sub(pow(sternT, 3.0).mul(0.25)));
  return select(x.greaterThan(86.0), bow, select(x.lessThan(-150.0), stern, mid));
});

export class Ocean {
  constructor(sky_) {
    this.sky = sky_;
    this.detail = makeSeaDetail(512);
    ocean.envTex = sky_.env.texture;
    this.waves = [];
    this.phase0 = [];
    this._lastKey = '';
    this.mesh = this._buildMesh();
    this.mesh.material = this._buildMaterial();
    this.mesh.frustumCulled = false;
    this.mesh.renderOrder = -1;
    this.mesh.receiveShadow = true;
    this.distance = 0;
  }

  _buildMesh() {
    // Polar grid: ring radii grow exponentially (fine under the camera,
    // coarse at the horizon), out to 34 km.
    const rings = 330, segs = 400;
    const a = 9.0, b = 0.0252;
    const pos = new Float32Array((rings * segs + 1) * 3);
    let p = 3;   // vertex 0 is the centre
    for (let i = 1; i <= rings; i++) {
      const r = a * (Math.exp(b * i) - 1);
      for (let j = 0; j < segs; j++) {
        const t = (j / segs) * Math.PI * 2;
        pos[p++] = Math.cos(t) * r; pos[p++] = 0; pos[p++] = Math.sin(t) * r;
      }
    }
    const idx = [];
    for (let j = 0; j < segs; j++) idx.push(0, 1 + ((j + 1) % segs), 1 + j);
    for (let i = 0; i < rings - 1; i++) {
      const r0 = 1 + i * segs, r1 = 1 + (i + 1) * segs;
      for (let j = 0; j < segs; j++) {
        const j1 = (j + 1) % segs;
        idx.push(r0 + j, r0 + j1, r1 + j, r0 + j1, r1 + j1, r1 + j);
      }
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    g.setIndex(idx);
    g.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 40000);
    return new THREE.Mesh(g, null);
  }

  _buildMaterial() {
    const det = this.detail;
    const env = ocean.envTex;
    const m = new THREE.MeshBasicNodeMaterial();
    m.fog = true;

    // --- vertex: Gerstner displacement with per-wave LOD by grid spacing ---
    const vFlat = varying(vec2(), 'vFlat');
    const vR = varying(float(), 'vR');
    const vH = varying(float(), 'vH');
    m.positionNode = Fn(() => {
      const lp = positionLocal;
      const wp = modelWorldMatrix.mul(vec4(lp, 1.0)).xyz;
      const r = length(lp.xz);
      const spacing = float(0.0252).mul(r.add(9.0)).add(0.08);
      const disp = vec3(0.0).toVar();
      Loop(N_WAVES, ({ i }) => {
        const A = ocean.wA.element(i);
        const B = ocean.wB.element(i);
        const lod = smoothstep(spacing.mul(3.0), spacing.mul(7.0), B.z);
        const th = A.z.mul(A.x.mul(wp.x).add(A.y.mul(wp.z))).add(B.y);
        const c = cos(th), s = sin(th);
        const qa = B.x.mul(A.w).mul(lod);
        disp.addAssign(vec3(A.x.mul(qa).mul(c), A.w.mul(lod).mul(s), A.y.mul(qa).mul(c)));
      });
      vFlat.assign(wp.xz);
      vR.assign(r);
      vH.assign(disp.y);
      // Earth curvature: the far sea drops below the horizon line.
      const drop = r.mul(r).div(2.0 * 6371000.0);
      return lp.add(vec3(disp.x, disp.y.sub(drop), disp.z));
    })();

    // --- fragment ---
    m.colorNode = Fn(() => {
      const xz = vFlat;
      const P = positionWorld;
      const toCam = cameraPosition.sub(P);
      const dist = length(toCam);
      const V = toCam.div(dist);
      const footprint = dist.mul(0.0016).add(0.02);

      // Analytic normal + Jacobian from the full spectrum, filtered per pixel.
      const nx = float(0.0).toVar(), nz = float(0.0).toVar(), ny = float(1.0).toVar();
      const jxx = float(1.0).toVar(), jzz = float(1.0).toVar(), jxz = float(0.0).toVar();
      Loop(N_WAVES, ({ i }) => {
        const A = ocean.wA.element(i);
        const B = ocean.wB.element(i);
        const f = smoothstep(footprint.mul(2.5), footprint.mul(7.0), B.z);
        const th = A.z.mul(A.x.mul(xz.x).add(A.y.mul(xz.y))).add(B.y);
        const c = cos(th), s = sin(th);
        const wa = A.z.mul(A.w).mul(f);
        nx.subAssign(A.x.mul(wa).mul(c));
        nz.subAssign(A.y.mul(wa).mul(c));
        const qwa = B.x.mul(wa).mul(s);
        ny.subAssign(qwa);
        jxx.subAssign(qwa.mul(A.x).mul(A.x));
        jzz.subAssign(qwa.mul(A.y).mul(A.y));
        jxz.subAssign(qwa.mul(A.x).mul(A.y));
      });
      const Nw = normalize(vec3(nx, max(ny, 0.2), nz)).toVar();
      const J = jxx.mul(jzz).sub(jxz.mul(jxz));

      // Capillary ripples: two scrolling layers of the detail map.
      const fl = ocean.flow;
      const uv1 = xz.add(fl).mul(1.0 / 17.0).add(vec2(ocean.time.mul(0.011), ocean.time.mul(0.004)));
      const uv2 = xz.add(fl).mul(1.0 / 5.2).add(vec2(ocean.time.mul(-0.017), ocean.time.mul(0.013)));
      const d1 = texture(det, uv1);
      const d2 = texture(det, vec2(uv2.y, uv2.x.negate()));
      const rip = vec2(d1.r.add(d2.r).sub(1.0), d1.g.add(d2.g).sub(1.0));
      const ripAmt = saturate(float(1.0).sub(dist.div(2600.0))).mul(mix(0.22, 0.5, saturate(ocean.hs.div(2.0)))).mul(float(1.0).sub(ocean.port.mul(0.6)));
      const rainRip = ocean.rain.mul(saturate(float(1.0).sub(dist.div(300.0)))).mul(0.6);
      const N = normalize(Nw.add(vec3(rip.x, 0.0, rip.y).mul(ripAmt.add(rainRip)))).toVar();
      // Keep normals facing the viewer at grazing angles.
      If(dot(N, V).lessThan(0.02), () => { N.assign(normalize(N.add(V.mul(float(0.02).sub(dot(N, V)))))); });

      // Cloud shadow on the water: coverage along the sun ray at cloud base.
      const sunD = sky.sunDir;
      const sunUp = max(sunD.y, 0.04);
      const toBase = cloud.base.mul(1000.0).div(sunUp);
      const shXZ = xz.add(sunD.xz.mul(toBase)).div(1000.0);
      const wm = texture(cloudTex.weather, shXZ.div(WEATHER_TILE).add(cloud.offWeather)).r;
      const t0 = float(1.0).sub(cloud.cover.mul(1.18));
      const covS = max(saturate(wm.sub(t0).div(0.32)), smoothstep(0.8, 1.0, cloud.cover));
      const sunVis = float(1.0).sub(covS.mul(min(cloud.density.mul(0.55).add(cloud.thick.mul(0.2)), 0.97)));

      // Fresnel reflection of the sky (clouds included).
      const R = reflect(V.negate(), N).toVar();
      R.y.assign(max(R.y, 0.004));
      const refl = texture(env, equirectUV(normalize(R))).rgb;
      const NoV = saturate(dot(N, V));
      const F = float(0.02).add(float(0.98).mul(pow(float(1.0).sub(NoV), 5.0)));

      // Sun glitter: GGX, roughness widening with distance (unresolved waves).
      const rough = ocean.rough.add(saturate(dist.div(5000.0)).mul(0.11)).add(ocean.rain.mul(0.08));
      const a2 = rough.mul(rough).mul(rough.mul(rough));
      const H = normalize(V.add(sunD));
      const NoH = saturate(dot(N, H));
      const NoL = saturate(dot(N, sunD));
      const dd = NoH.mul(NoH).mul(a2.sub(1.0)).add(1.0);
      const D = a2.div(dd.mul(dd).mul(Math.PI));
      const Fs = float(0.02).add(float(0.98).mul(pow(float(1.0).sub(saturate(dot(V, H))), 5.0)));
      const spec = sky.sunColor.mul(D.mul(Fs).mul(NoL).div(max(NoV.mul(4.0), 0.08))).mul(sunVis);
      const moonH = normalize(V.add(sky.moonDir));
      const mNoH = saturate(dot(N, moonH));
      const mdd = mNoH.mul(mNoH).mul(a2.sub(1.0)).add(1.0);
      const mspec = sky.moonColor.mul(a2.div(mdd.mul(mdd).mul(Math.PI))).mul(saturate(dot(N, sky.moonDir))).mul(0.25);

      // Water body: deep blue, green-grey in the harbour, lit by sun and sky.
      const amb = cloud.ambTop.mul(float(1.0).sub(cloud.gloom.mul(0.4)));
      const sunLit = sky.sunColor.mul(saturate(sunD.y)).mul(sunVis);
      const deep = mix(vec3(0.0035, 0.018, 0.040), vec3(0.012, 0.035, 0.032), ocean.port);
      const body = deep.mul(amb.mul(3.2).add(sunLit.mul(0.55)));
      // Light through the thin tops of waves: turquoise, strongest looking toward the sun.
      const crest = saturate(vH.div(max(ocean.hs.mul(0.5), 0.2)).add(0.25));
      const back = pow(saturate(dot(V.negate(), sunD).mul(0.6).add(0.4)), 3.0);
      const sss = vec3(0.02, 0.16, 0.14).mul(sunLit).mul(crest.mul(back)).mul(0.5).mul(float(1.0).sub(ocean.port.mul(0.5)));

      // --- foam: whitecaps, bow wave, wake ---
      const sx = xz.x, sz = xz.y;
      const hw = hullHalfBeamWL(sx);
      const az = abs(sz);
      const spd = saturate(ocean.shipSpeed.div(9.26));
      const ef = xz.add(fl);
      // Breakup texture: streaks stretched along the flow (x) over fine lace,
      // so foam patches tear into ribbons instead of tiling.
      const n1 = texture(det, vec2(ef.x.div(52.0), ef.y.div(15.0))).a;
      const n2 = texture(det, vec2(ef.x.div(13.0), ef.y.div(5.0)).add(0.31)).a;
      const lace = texture(det, ef.mul(1.0 / 6.5)).b;
      const foamTex = n1.mul(0.55).add(n2.mul(0.3)).add(lace.mul(0.22)).toVar();
      // Amount 0..1 -> coverage: thin amounts leave scattered flecks, full
      // amounts a solid sheet.
      const cover = (amt) => smoothstep(float(1.0).sub(amt), float(1.28).sub(amt), foamTex.add(amt.mul(0.3)));
      const wcAmt = saturate(float(0.3).sub(J).mul(2.2)).mul(ocean.whitecap);
      // Hull-contact foam and the bow wave piling up at the stem.
      const gap = az.sub(hw);
      const inHull = select(sx.lessThan(166.0).and(sx.greaterThan(-166.0)), float(1.0), float(0.0));
      const contact = exp(max(gap, 0.0).mul(-0.9)).mul(inHull).mul(spd.mul(0.5).add(0.25));
      const bowZone = smoothstep(60.0, 155.0, sx);
      const bowSpread = exp(max(gap.sub(float(166.0).sub(sx).mul(0.07)), 0.0).negate().mul(0.18));
      const bowWave = bowZone.mul(bowSpread).mul(spd);
      // Behind the stern: propeller wash, turbulent wake, Kelvin arms.
      const back_ = max(float(-163.0).sub(sx), 0.0);
      const behind = select(sx.lessThan(-163.0), float(1.0), float(0.0));
      const wakeW = float(16.0).add(back_.mul(0.05));
      const core = smoothstep(wakeW, wakeW.mul(0.3), az).mul(exp(back_.mul(-1.0 / 1400.0)));
      const wash = smoothstep(24.0, 5.0, az).mul(exp(back_.mul(-1.0 / 180.0)));
      const kelvin = back_.mul(0.3535).add(hw.mul(0.6));
      const armW = float(2.5).add(back_.mul(0.012));
      const kd = az.sub(kelvin).div(armW);
      const arm = exp(kd.mul(kd).negate()).mul(exp(back_.mul(-1.0 / 900.0)));
      const wakeAmt = core.mul(0.55).add(wash.mul(0.8)).add(arm.mul(0.45)).mul(behind).mul(spd);
      // Turbulence along the side of the hull aft of the bow wave.
      const sideWake = exp(max(gap, 0.0).mul(-0.16)).mul(smoothstep(140.0, -160.0, sx)).mul(inHull).mul(spd).mul(0.55);
      const amt = saturate(max(max(wcAmt, contact), max(max(bowWave, wakeAmt), sideWake)));
      const fade = saturate(float(1.0).sub(dist.div(9000.0)));
      const foam = cover(amt).mul(fade).toVar();
      // Aerated water under and around the foam glows turquoise.
      const aerated = saturate(wakeAmt.mul(1.3).add(bowWave.mul(0.8)).add(contact.mul(0.4)).add(sideWake.mul(0.6)).add(wcAmt.mul(0.4)));

      const foamCol = vec3(0.82, 0.86, 0.88).mul(amb.mul(2.6).add(sunLit.mul(saturate(N.y).mul(0.32))));
      const aerCol = vec3(0.05, 0.22, 0.24).mul(amb.mul(2.8).add(sunLit.mul(0.3)));
      const water = mix(body.add(sss).add(aerCol.mul(aerated)), refl, F.mul(float(1.0).sub(aerated.mul(0.5))));
      const col = mix(water.add(spec).add(mspec), foamCol, foam.mul(0.92));
      return vec4(col, 1.0);
    })();
    return m;
  }

  /** Rebuild the wave set when wind or sea state changes noticeably. */
  setSea(beaufort, windDirShip, swellDirShip, port) {
    const bf = Math.max(0, Math.min(10, beaufort));
    const key = `${bf.toFixed(2)}|${windDirShip.toFixed(2)}|${port}`;
    if (key === this._lastKey) return;
    this._lastKey = key;
    const lo = Math.floor(bf), hi = Math.min(10, lo + 1);
    const hs = port ? 0.06 : BEAUFORT_HS[lo] + (BEAUFORT_HS[hi] - BEAUFORT_HS[lo]) * (bf - lo);
    const U = Math.max(1.5, port ? 2 : 0.836 * Math.pow(bf, 1.5) + 1);   // m/s
    this.hs = hs;
    ocean.hs.value = Math.max(hs, 0.05);
    ocean.rough.value = 0.035 + Math.min(0.09, U * 0.004);
    ocean.whitecap.value = port ? 0 : THREE.MathUtils.smoothstep(bf, 3.4, 6.5);
    ocean.port.value = port ? 1 : 0;

    let seed = 7;
    const rnd = () => { seed = (Math.imul(seed, 1103515245) + 12345) | 0; return ((seed >>> 0) % 100000) / 100000; };
    const waves = [];
    // Wind sea from a Pierson-Moskowitz spectrum, peak at lambda_p.
    const wp = 0.877 * G / U;
    const lamP = Math.max(3, (2 * Math.PI * G) / (wp * wp));
    const nWind = N_WAVES - 6;
    const lmax = lamP * 2.4, lmin = port ? 0.25 : 0.55;
    let energy = 0;
    for (let i = 0; i < nWind; i++) {
      const f = i / (nWind - 1);
      const lam = lmax * Math.pow(lmin / lmax, f) * (0.92 + rnd() * 0.16);
      const k = (2 * Math.PI) / lam;
      const w = Math.sqrt(G * k);
      const S = (0.0081 * G * G) / Math.pow(w, 5) * Math.exp(-1.25 * Math.pow(wp / w, 4));
      const dw = w * 0.11;
      const amp = Math.sqrt(2 * S * dw);
      const spread = 0.35 + f * 0.9;
      const dir = windDirShip + (rnd() - 0.5) * 2 * spread;
      waves.push({ dir, lam, k, w, amp });
      energy += amp * amp * 0.5;
    }
    // Normalise the wind sea to the target significant height (Hs = 4 sqrt(m0)).
    const target = Math.max(0.0, hs * 0.85);
    const scale = energy > 0 ? target / (4 * Math.sqrt(energy)) : 0;
    for (const w_ of waves) w_.amp *= scale;
    // Long swell from far weather: always present at sea, gentle in port.
    const swellH = port ? 0.03 : 0.35 + hs * 0.35;
    for (let i = 0; i < 6; i++) {
      const lam = 110 + i * 32 + rnd() * 20;
      const k = (2 * Math.PI) / lam;
      waves.push({ dir: swellDirShip + (rnd() - 0.5) * 0.35, lam, k, w: Math.sqrt(G * k), amp: (swellH * 0.5) / Math.sqrt(6) * (0.7 + rnd() * 0.6) });
    }
    // Steepness: sharp crests without self-intersection.
    const totalKA = waves.reduce((a, w_) => a + w_.k * w_.amp, 0) || 1;
    const steep = port ? 0.3 : THREE.MathUtils.lerp(0.45, 0.82, Math.min(1, bf / 7));
    for (const w_ of waves) w_.q = Math.min(1.0, steep / totalKA);
    // Keep phases continuous across rebuilds where possible.
    if (this.phase0.length !== waves.length) this.phase0 = waves.map(() => rnd() * Math.PI * 2);
    this.waves = waves;
    for (let i = 0; i < N_WAVES; i++) {
      const w_ = waves[i];
      ocean.wA.array[i].set(Math.cos(w_.dir), Math.sin(w_.dir), w_.k, w_.amp);
      ocean.wB.array[i].set(w_.q, 0, w_.lam, 0);
    }
  }

  update(t, distance, camera) {
    this.distance = distance;
    ocean.time.value = t;
    // Detail scroll in metres, wrapped on a common multiple of every tile
    // length the flow drives (17, 5.2, 52, 13, 6.5 m all divide 884 m).
    const W = 8840;
    ocean.flow.value.set(distance % W, 0);
    for (let i = 0; i < this.waves.length; i++) {
      const w = this.waves[i];
      // Earth-fixed wave seen from the moving ship: phase includes k.dir.x * D.
      let ph = w.k * Math.cos(w.dir) * distance - w.w * t + this.phase0[i];
      ph %= Math.PI * 2;
      ocean.wB.array[i].y = ph;
    }
    // Follow the camera, snapped to the inner ring spacing to limit swimming.
    const s = 0.5;
    this.mesh.position.set(Math.round(camera.position.x / s) * s, 0, Math.round(camera.position.z / s) * s);
    ocean.camXZ.value.set(camera.position.x, camera.position.z);
  }

  /** CPU height of the sea at ship-frame (x, z), long waves only (for boats). */
  heightAt(x, z, maxWaves = N_WAVES) {
    let h = 0;
    // Two fixed-point steps undo most of the horizontal Gerstner shift.
    let px = x, pz = z;
    for (let it = 0; it < 2; it++) {
      let dx = 0, dz = 0;
      for (let i = 0; i < Math.min(maxWaves, this.waves.length); i++) {
        const w = this.waves[i], A = ocean.wA.array[i], B = ocean.wB.array[i];
        const c = Math.cos(A.z * (A.x * px + A.y * pz) + B.y);
        dx += A.x * B.x * A.w * c; dz += A.y * B.x * A.w * c;
      }
      px = x - dx; pz = z - dz;
    }
    for (let i = 0; i < Math.min(maxWaves, this.waves.length); i++) {
      const A = ocean.wA.array[i], B = ocean.wB.array[i];
      h += A.w * Math.sin(A.z * (A.x * px + A.y * pz) + B.y);
    }
    return h;
  }
}
