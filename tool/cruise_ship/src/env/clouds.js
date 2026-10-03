import * as THREE from 'three/webgpu';
import {
  Fn, vec2, vec3, vec4, float, uniform, texture, texture3D, dot, sqrt, exp, max, min, clamp, mix, length,
  normalize, smoothstep, saturate, Loop, If, Break, uv, select, pow, interleavedGradientNoise, abs, fract,
  frameId, screenCoordinate, cos, sin, asin, atan,
} from 'three/tsl';
import { RG, raySphere, lutUVFromDir, sky } from './atmosphere.js';
import { makeCloudBase, makeCloudDetail, makeWeatherMap } from './noise.js';

// Volumetric cloud layer: a spherical shell ray-marched through Perlin-Worley
// noise, lit by the sun with a dual-lobe phase function, Beer-powder and a
// multiple-scattering approximation, then faded into the horizon haze.
// Rendered at reduced resolution for the screen and again, cheaper, into the
// equirectangular sky that feeds reflections and ambient light.

export const cloud = {
  cover: uniform(0.3),
  density: uniform(1.0),
  base: uniform(1.3),          // km
  thick: uniform(1.6),         // km
  type: uniform(1.0),          // 0 stratus sheet, 1 heaped cumulus
  gloom: uniform(0.0),
  offBase: uniform(new THREE.Vector3()),
  offDetail: uniform(new THREE.Vector3()),
  offWeather: uniform(new THREE.Vector2()),
  camKm: uniform(new THREE.Vector3(0, 0.02, 0)),
  sunColor: uniform(new THREE.Color(1, 1, 1)),   // sun as seen at cloud height
  ambTop: uniform(new THREE.Color(0.2, 0.3, 0.5)),
  ambBottom: uniform(new THREE.Color(0.05, 0.07, 0.1)),
  flashPos: uniform(new THREE.Vector3(5, 1, 0)),
  flash: uniform(0.0),
  invProj: uniform(new THREE.Matrix4()),
  camWorld: uniform(new THREE.Matrix4()),
};

export const BASE_TILE = 6.5;      // km per base-noise tile
export const DETAIL_TILE = 0.55;   // km per detail tile
export const WEATHER_TILE = 46.0;  // km per weather-map tile

let baseTex, detailTex, weatherTex;

/** The generated textures, for other shaders (sea cloud shadows) and the CPU. */
export const cloudTex = { base: null, detail: null, weather: null };

export function buildCloudTextures() {
  if (cloudTex.base) return cloudTex;
  baseTex = cloudTex.base = makeCloudBase(64);
  detailTex = cloudTex.detail = makeCloudDetail(32);
  weatherTex = cloudTex.weather = makeWeatherMap(256);
  return cloudTex;
}

/** CPU lookup of the weather map's coverage channel (0..1), wrapped bilinear. */
export function weatherCoverageCPU(u, v) {
  const t = cloudTex.weather;
  if (!t) return 0.5;
  const N = t.image.width, d = t.image.data;
  const x = (((u % 1) + 1) % 1) * N - 0.5, y = (((v % 1) + 1) % 1) * N - 0.5;
  const x0 = Math.floor(x), y0 = Math.floor(y), fx = x - x0, fy = y - y0;
  const at = (i, j) => d[((((j % N) + N) % N) * N + (((i % N) + N) % N)) * 4] / 255;
  return (at(x0, y0) * (1 - fx) + at(x0 + 1, y0) * fx) * (1 - fy)
    + (at(x0, y0 + 1) * (1 - fx) + at(x0 + 1, y0 + 1) * fx) * fy;
}

const remap = (v, a, b, c, d) => c.add(v.sub(a).div(b.sub(a)).mul(d.sub(c)));

const HG = (mu, g) => {
  const g2 = g * g;
  return float((1 - g2) / (4 * Math.PI)).div(pow(float(1 + g2).sub(mu.mul(2 * g)), 1.5));
};

/** Cloud density at a world sample (km, x/z horizontal, y altitude). */
const densityAt = Fn(([w, cheap]) => {
  const h = clamp(w.y.sub(cloud.base).div(cloud.thick), 0.0, 1.0);
  const wm = texture(weatherTex, w.xz.div(WEATHER_TILE).add(cloud.offWeather)).level(0);
  // Coverage threshold; past ~85% cover the sheet closes completely.
  const t0 = float(1.0).sub(cloud.cover.mul(1.18));
  const cov = max(saturate(wm.r.sub(t0).div(0.32)), smoothstep(0.8, 1.0, cloud.cover)).toVar();
  // Height profile: stratus is a flat sheet, cumulus rounds off its top
  // and flattens its base.
  const typ = clamp(cloud.type.add(wm.g.sub(0.5).mul(0.5)), 0.0, 1.0);
  const bottom = smoothstep(0.0, mix(0.18, 0.06, typ), h);
  const top = smoothstep(1.0, mix(0.55, 0.2, typ), h);
  const grad = bottom.mul(top);
  const b = texture3D(baseTex, w.div(BASE_TILE).add(cloud.offBase)).level(0);
  const low = b.g.mul(0.625).add(b.b.mul(0.25)).add(b.a.mul(0.125));
  const shape = saturate(remap(b.r, low.sub(1.0), float(1.0), float(0.0), float(1.0))).mul(grad);
  // Coverage erodes the tops more than the bases (anvils and towers).
  const covH = cov.mul(mix(float(1.0), float(1.0).sub(h.mul(0.45)), typ));
  const withCov = saturate(remap(shape, float(1.0).sub(covH), float(1.0), float(0.0), float(1.0))).mul(covH);
  const d = withCov.toVar();
  If(cheap.lessThan(0.5).and(d.greaterThan(0.0)), () => {
    const dt = texture3D(detailTex, w.div(DETAIL_TILE).add(cloud.offDetail)).level(0);
    const dfbm = dt.r.mul(0.625).add(dt.g.mul(0.25)).add(dt.b.mul(0.125));
    const m = mix(dfbm, float(1.0).sub(dfbm), saturate(h.mul(6.0)));
    d.assign(saturate(remap(d, m.mul(0.48), float(1.0), float(0.0), float(1.0))));
  });
  // Fine breakup from the weather map keeps closed decks from being uniform.
  return d.mul(cloud.density).mul(wm.b.mul(0.9).add(0.55));
});

const SIGMA = 42.0;   // extinction per km at density 1

/**
 * March the cloud layer along view direction rd from the camera. Returns
 * premultiplied radiance in rgb and transmittance in a.
 */
export function makeCloudMarch(steps, lightSteps) {
  return Fn(([rdIn, jitter]) => {
    // TSL emits nodes lazily, where first used. Anything read both inside
    // and outside an If/Loop scope is pinned to a function-scope variable
    // here, or it would be declared inside the branch and read back as 0.
    const rd = vec3(rdIn).toVar();
    const ro = vec3(0.0, float(RG).add(cloud.camKm.y), 0.0).toVar();
    const rb = float(RG).add(cloud.base).toVar();
    const rt = float(RG).add(cloud.base).add(cloud.thick).toVar();
    const hb = raySphere(ro, rd, rb).toVar();
    const ht = raySphere(ro, rd, rt).toVar();
    const hg = raySphere(ro, rd, float(RG)).toVar();
    const camAlt = cloud.camKm.y;
    // Segment of the ray inside the shell (camera is below, inside, or above).
    const t0 = float(0.0).toVar();
    const t1 = float(0.0).toVar();
    If(camAlt.lessThan(cloud.base), () => {
      t0.assign(hb.y); t1.assign(ht.y);
    }).ElseIf(camAlt.lessThan(cloud.base.add(cloud.thick)), () => {
      t0.assign(0.0);
      t1.assign(select(hb.x.greaterThan(0.0), hb.x, ht.y));
    }).Else(() => {
      t0.assign(ht.x); t1.assign(select(hb.x.greaterThan(0.0), hb.x, ht.y));
    });
    // The sea hides anything beyond where the ray meets it.
    If(hg.x.greaterThan(0.0), () => { t1.assign(min(t1, hg.x)); });
    t1.assign(min(t1, t0.add(38.0)));
    const T = float(1.0).toVar();
    const L = vec3(0.0).toVar();
    const firstHit = float(-1.0).toVar();
    const dt = t1.sub(t0).div(steps).toVar();
    const mu = dot(rd, sky.sunDir).toVar();
    const phase = mix(HG(mu, 0.78), HG(mu, -0.25), 0.32).add(HG(mu, 0.2).mul(0.35)).toVar();
    const dimAmb = float(1.0).sub(cloud.gloom.mul(0.55)).toVar();
    const sunBoost = float(4.2).sub(cloud.gloom.mul(2.2)).toVar();
    If(t1.greaterThan(t0).and(t0.greaterThanEqual(0.0)), () => {
      const t = t0.add(dt.mul(jitter)).toVar();
      Loop(steps, () => {
        const p = ro.add(rd.mul(t)).toVar();
        const alt = length(p).sub(RG).toVar();
        const w = vec3(p.x.add(cloud.camKm.x), alt, p.z.add(cloud.camKm.z)).toVar();
        const d = densityAt(w, float(0.0)).toVar();
        If(d.greaterThan(0.002), () => {
          If(firstHit.lessThan(0.0), () => { firstHit.assign(t); });
          // Light march toward the sun with growing steps.
          const od = float(0.0).toVar();
          const ls = float(0.06).toVar();
          const q = vec3(w).toVar();
          Loop(lightSteps, () => {
            q.addAssign(sky.sunDir.mul(ls));
            od.addAssign(densityAt(q, float(1.0)).mul(ls));
            ls.mulAssign(1.9);
          });
          const tau = od.mul(SIGMA);
          // Multiple-scattering octaves (Wrenninge 2013) and powder darkening.
          // Multiple-scattering octaves plus a deep diffuse term, so thick
          // decks still glow grey-white from above instead of going flat.
          const ms = exp(tau.negate()).add(exp(tau.mul(-0.25)).mul(0.35)).add(exp(tau.mul(-0.08)).mul(0.14)).add(exp(tau.mul(-0.02)).mul(0.06));
          const powder = float(1.0).sub(exp(d.mul(SIGMA).mul(-0.35)).mul(0.6));
          const h = saturate(alt.sub(cloud.base).div(cloud.thick));
          const amb = mix(cloud.ambBottom, cloud.ambTop, h.mul(0.7).add(0.3)).mul(dimAmb);
          const sunL = cloud.sunColor.mul(phase).mul(ms).mul(powder).mul(sunBoost);
          const flashD = length(w.sub(cloud.flashPos));
          const flash = vec3(0.78, 0.83, 1.0).mul(cloud.flash).mul(exp(flashD.mul(flashD).mul(-0.35)));
          const lum = sunL.add(amb).add(flash);
          const ext = exp(d.mul(SIGMA).mul(dt).negate());
          L.addAssign(T.mul(lum).mul(float(1.0).sub(ext)));
          T.mulAssign(ext);
        });
        If(T.lessThan(0.012), () => { Break(); });
        t.addAssign(dt);
      });
      // Aerial perspective: distant cloud fades into the horizon colour.
      const dist = select(firstHit.greaterThan(0.0), firstHit, t0);
      const ap = exp(dist.mul(sky.haze).mul(-0.022));
      const hz = texture(skyLutRef.tex, lutUVFromDir(rd)).rgb;
      L.assign(L.mul(ap).add(hz.mul(float(1.0).sub(T)).mul(float(1.0).sub(ap))));
    });
    return vec4(L, T);
  });
}

// The cloud shader samples the sky LUT for its haze; set once the LUT exists.
export const skyLutRef = { tex: null };

const QUALITY_STEPS = {
  low: [26, 3, 0.4],
  medium: [38, 4, 0.5],
  high: [52, 5, 0.5],
  ultra: [72, 6, 0.65],
};

/** Clouds for the screen, rendered to a reduced-size target each frame. */
export class CloudPass {
  constructor(renderer, quality = 'high') {
    this.renderer = renderer;
    this.rt = new THREE.RenderTarget(2, 2, { type: THREE.HalfFloatType, depthBuffer: false });
    this.rt.texture.minFilter = THREE.LinearFilter;
    this.rt.texture.magFilter = THREE.LinearFilter;
    this.rt.texture.generateMipmaps = false;
    this.setQuality(quality);
  }

  setQuality(q) {
    const [steps, light, scale] = QUALITY_STEPS[q] || QUALITY_STEPS.high;
    this.scale = scale;
    const march = makeCloudMarch(steps, light);
    const mat = new THREE.MeshBasicNodeMaterial();
    mat.fragmentNode = Fn(() => {
      const q = uv();
      const ndc = vec4(q.x.mul(2.0).sub(1.0), q.y.oneMinus().mul(2.0).sub(1.0), 0.5, 1.0);
      const vp = cloud.invProj.mul(ndc);
      const dirV = normalize(vp.xyz.div(vp.w));
      const rd = normalize(cloud.camWorld.mul(vec4(dirV, 0.0)).xyz);
      const j = interleavedGradientNoise(screenCoordinate.xy.add(vec2(float(frameId).mul(5.588), float(frameId).mul(3.141))));
      return march(rd, fract(j.add(float(frameId).mul(0.61803))));
    })();
    if (this.quad) this.quad.material.dispose();
    this.quad = new THREE.QuadMesh(mat);
    this._w = 0;
  }

  resize(w, h) {
    const W = Math.max(2, Math.floor(w * this.scale)), H = Math.max(2, Math.floor(h * this.scale));
    if (W !== this._w || H !== this._h) { this.rt.setSize(W, H); this._w = W; this._h = H; }
  }

  render(camera) {
    cloud.invProj.value.copy(camera.projectionMatrixInverse);
    cloud.camWorld.value.copy(camera.matrixWorld);
    const r = this.renderer;
    const prev = r.getRenderTarget();
    r.setRenderTarget(this.rt);
    this.quad.render(r);
    r.setRenderTarget(prev);
  }
}

export { densityAt };
