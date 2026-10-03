import * as THREE from 'three/webgpu';
import {
  Fn, vec2, vec3, vec4, float, uniform, dot, sqrt, exp, max, min, clamp, abs, sin, cos, atan, asin,
  select, Loop, uv, PI, mix, smoothstep, sign, pow, normalize, length,
} from 'three/tsl';

// Physically based sky: single scattering through a spherical atmosphere
// (Rayleigh + Mie + ozone) with a cheap multiple-scattering term, after
// Hillaire's "A Scalable and Production Ready Sky and Atmosphere" (2020).
// Units are kilometres and 1/km so float32 stays precise at planet scale.
//
// The GPU evaluates it into a small sky-view LUT every frame; the same model
// runs on the CPU for the colour of the sun and moon light.

export const RG = 6360.0;              // ground radius, km
export const RT = 6460.0;              // top of atmosphere, km
const HR = 8.0, HM = 1.2;              // scale heights, km
const BETA_R = [5.802e-3, 13.558e-3, 33.1e-3];   // 1/km
const BETA_O = [0.650e-3, 1.881e-3, 0.085e-3];   // ozone absorption, 1/km
const MIE_S = 3.996e-3, MIE_E = 4.40e-3;        // 1/km

/** Sun illuminance in scene units: a directional light of this intensity is "noon". */
export const SUN_E = 3.4;
/** Sun angular radius (rad). Drawn a touch larger than real for presence. */
export const SUN_RADIUS = 0.0058;
export const MOON_RADIUS = 0.0062;

// Uniforms shared by every shader that needs the sky.
export const sky = {
  sunDir: uniform(new THREE.Vector3(0, 1, 0)),
  moonDir: uniform(new THREE.Vector3(0, -1, 0)),
  sunE: uniform(SUN_E),
  moonE: uniform(0.0),
  haze: uniform(1.0),            // Mie density multiplier (aerosols, humidity)
  observerAlt: uniform(0.02),    // km
  sunColor: uniform(new THREE.Color(1, 1, 1)),   // transmitted sun at the observer (already * sunE)
  moonColor: uniform(new THREE.Color(0, 0, 0)),
  nightGlow: uniform(new THREE.Color(0.0006, 0.0009, 0.0018)),
  starMatrix: uniform(new THREE.Matrix3()),
  moonPhase: uniform(0.5),
  cloudShadow: uniform(1.0),     // average cloud transmittance toward the sun (weather)
};

// ---------------------------------------------------------------------------
// CPU: transmittance along a ray from altitude h (km) with direction cosine mu.

function raySphereFar(r0, mu, R) {
  // distance from a point at radius r0 along a ray with zenith cosine mu to sphere R
  const b = r0 * mu;
  const c = r0 * r0 - R * R;
  const h = b * b - c;
  if (h < 0) return -1;
  return -b + Math.sqrt(h);
}

export function transmittanceCPU(altKm, mu, haze = 1, out = [0, 0, 0]) {
  const r0 = RG + altKm;
  // Below the horizon the ray meets the ground: no direct light (soft edge for the disc).
  const groundMu = -Math.sqrt(Math.max(0, 1 - (RG * RG) / (r0 * r0)));
  if (mu < groundMu - 0.01) { out[0] = out[1] = out[2] = 0; return out; }
  const tMax = raySphereFar(r0, Math.max(mu, groundMu), RT);
  const N = 40;
  const dt = tMax / N;
  let odR = 0, odM = 0, odO = 0;
  for (let i = 0; i < N; i++) {
    const t = (i + 0.5) * dt;
    const r = Math.sqrt(r0 * r0 + t * t + 2 * r0 * mu * t);
    const h = r - RG;
    odR += Math.exp(-h / HR) * dt;
    odM += Math.exp(-h / HM) * dt;
    odO += Math.max(0, 1 - Math.abs(h - 25) / 15) * dt;
  }
  const edge = THREE.MathUtils.smoothstep(mu, groundMu - 0.01, groundMu + 0.004);
  for (let c = 0; c < 3; c++) {
    out[c] = Math.exp(-(BETA_R[c] * odR + MIE_E * haze * odM + BETA_O[c] * odO)) * edge;
  }
  return out;
}

// ---------------------------------------------------------------------------
// GPU helpers (TSL).

const betaR = vec3(BETA_R[0], BETA_R[1], BETA_R[2]);
const betaO = vec3(BETA_O[0], BETA_O[1], BETA_O[2]);

/** Far and near intersection distances of a ray with a centered sphere; -1 when missed. */
export const raySphere = /*@__PURE__*/ Fn(([ro, rd, rad]) => {
  const b = dot(ro, rd);
  const c = dot(ro, ro).sub(rad.mul(rad));
  const h = b.mul(b).sub(c);
  const s = sqrt(max(h, 0.0));
  return select(h.lessThan(0.0), vec2(-1.0, -1.0), vec2(b.negate().sub(s), b.negate().add(s)));
});

const densities = /*@__PURE__*/ Fn(([h]) => {
  const dO = max(float(0.0), float(1.0).sub(abs(h.sub(25.0)).div(15.0)));
  return vec3(exp(h.div(-HR)), exp(h.div(-HM)), dO);
});

/** Transmittance from point p (km, planet centered) toward direction l. */
const sunTransmittance = /*@__PURE__*/ Fn(([p, l, haze]) => {
  const tTop = raySphere(p, l, float(RT)).y;
  const ground = raySphere(p, l, float(RG));
  const od = vec3(0.0).toVar();
  const N = 8;
  const dt = tTop.div(N);
  Loop(N, ({ i }) => {
    const q = p.add(l.mul(float(i).add(0.5).mul(dt)));
    od.addAssign(densities(length(q).sub(RG)).mul(dt));
  });
  const tr = exp(betaR.mul(od.x).add(vec3(MIE_E).mul(haze).mul(od.y)).add(betaO.mul(od.z)).negate());
  // Soft terminator instead of a hard ground hit, so twilight fades smoothly.
  const blocked = ground.x.greaterThan(0.0);
  const r = length(p);
  const mu = dot(p, l).div(r);
  const muH = sqrt(max(float(1.0).sub(float(RG * RG).div(r.mul(r))), 0.0)).negate();
  const soft = smoothstep(muH.sub(0.012), muH.add(0.004), mu);
  return select(blocked, tr.mul(soft), tr);
});

const phaseRayleigh = (mu) => float(3.0 / (16.0 * Math.PI)).mul(mu.mul(mu).add(1.0));
const phaseMie = (mu, g) => {
  const g2 = g * g;
  const denom = pow(float(1.0 + g2).sub(mu.mul(2.0 * g)), 1.5);
  return float((3.0 / (8.0 * Math.PI)) * (1.0 - g2) / (2.0 + g2)).mul(mu.mul(mu).add(1.0)).div(denom);
};

/**
 * In-scattered radiance along a view ray from the observer, lit by one body
 * (sun or moon) of illuminance `E` in direction `l`. Rays that meet the sea
 * stop there.
 */
export const scatter = /*@__PURE__*/ Fn(([rd, l, E, haze, altKm]) => {
  const ro = vec3(0.0, float(RG).add(altKm), 0.0);
  const top = raySphere(ro, rd, float(RT));
  const ground = raySphere(ro, rd, float(RG));
  const tMax = select(ground.x.greaterThan(0.0), ground.x, top.y).toVar();
  tMax.assign(min(tMax, 900.0));
  const N = 22;
  const mu = dot(rd, l);
  const pR = phaseRayleigh(mu);
  const pM = phaseMie(mu, 0.8);
  const iso = float(1.0 / (4.0 * Math.PI));
  const L = vec3(0.0).toVar();
  const od = vec3(0.0).toVar();
  // Exponential sample spacing keeps detail near the observer for the horizon haze.
  const prevT = float(0.0).toVar();
  Loop(N, ({ i }) => {
    const f = float(i).add(0.5).div(N);
    const t = tMax.mul(f.mul(f));
    const tNext = tMax.mul(float(i).add(1.0).div(N).mul(float(i).add(1.0).div(N)));
    // Materialise before prevT moves on (TSL inlines expressions at use).
    const dt = tNext.sub(prevT).toVar();
    prevT.assign(tNext);
    const p = ro.add(rd.mul(t));
    const h = length(p).sub(RG);
    const d = densities(h);
    od.addAssign(d.mul(dt));
    const tView = exp(betaR.mul(od.x).add(vec3(MIE_E).mul(haze).mul(od.y)).add(betaO.mul(od.z)).negate());
    const tSun = sunTransmittance(p, l, haze);
    const sR = betaR.mul(d.x);
    const sM = vec3(MIE_S).mul(haze).mul(d.y);
    // Multiple scattering, approximated as an isotropic term that grows
    // with optical depth (keeps twilight and hazy skies from going black).
    const ms = iso.mul(0.55);
    const s = sR.mul(pR.add(ms)).add(sM.mul(pM.add(ms)));
    L.addAssign(tView.mul(tSun).mul(s).mul(dt));
  });
  return L.mul(E);
});

// ---------------------------------------------------------------------------
// Sky-view LUT. Azimuth on u, elevation on v with extra resolution around the
// horizon where the colour changes fastest (v = 0.5 is the horizon).

export const lutDirFromUV = /*@__PURE__*/ Fn(([u, v]) => {
  const az = u.sub(0.5).mul(2.0 * Math.PI);
  const s = v.sub(0.5).mul(2.0);
  const el = sign(s).mul(s.mul(s)).mul(Math.PI / 2);
  return vec3(cos(el).mul(cos(az)), sin(el), cos(el).mul(sin(az)));
});

export const lutUVFromDir = /*@__PURE__*/ Fn(([d]) => {
  const el = asin(clamp(d.y, -1.0, 1.0));
  const u = atan(d.z, d.x).div(2.0 * Math.PI).add(0.5);
  const a = sqrt(abs(el).div(Math.PI / 2));
  const v = sign(el).mul(a).mul(0.5).add(0.5);
  return vec2(u, clamp(v, 0.002, 0.998));
});

export class Atmosphere {
  constructor(renderer) {
    this.renderer = renderer;
    this.lut = new THREE.RenderTarget(256, 160, { type: THREE.HalfFloatType, depthBuffer: false });
    this.lut.texture.wrapS = THREE.RepeatWrapping;
    this.lut.texture.wrapT = THREE.ClampToEdgeWrapping;
    this.lut.texture.minFilter = THREE.LinearFilter;
    this.lut.texture.magFilter = THREE.LinearFilter;
    this.lut.texture.generateMipmaps = false;

    const mat = new THREE.MeshBasicNodeMaterial();
    mat.fragmentNode = Fn(() => {
      const q = uv();
      // Written and read with the same uv convention (see lutUVFromDir).
      const d = lutDirFromUV(q.x, q.y);
      // Rays below the horizon are sampled just above it: the sea covers
      // them, and the lowest rows then double as the horizon haze colour.
      const dd = normalize(vec3(d.x, max(d.y, 0.0015), d.z));
      const Ls = scatter(dd, sky.sunDir, sky.sunE, sky.haze, sky.observerAlt);
      const Lm = scatter(dd, sky.moonDir, sky.moonE, sky.haze, sky.observerAlt);
      return vec4(Ls.add(Lm).add(sky.nightGlow), 1.0);
    })();
    this.quad = new THREE.QuadMesh(mat);
    this._t = [0, 0, 0];
  }

  /** CPU light colours for the sun and moon, from the current sky uniforms. */
  updateLights(sunDir, moonDir, moonIllum, haze, altKm) {
    const t = this._t;
    transmittanceCPU(altKm, sunDir.y, haze, t);
    this.sunTrans = t.slice();
    sky.sunColor.value.setRGB(t[0] * SUN_E, t[1] * SUN_E, t[2] * SUN_E);
    transmittanceCPU(altKm, moonDir.y, haze, t);
    // Moonlight is sunlight off grey rock: artistically scaled so a moonlit
    // deck is readable after exposure adaptation, and tinted cool.
    const mE = SUN_E * 0.0045 * (0.15 + 0.85 * moonIllum);
    sky.moonE.value = mE;
    sky.moonColor.value.setRGB(t[0] * mE * 0.86, t[1] * mE * 0.95, t[2] * mE * 1.12);
  }

  render() {
    const r = this.renderer;
    const prev = r.getRenderTarget();
    r.setRenderTarget(this.lut);
    this.quad.render(r);
    r.setRenderTarget(prev);
  }
}
