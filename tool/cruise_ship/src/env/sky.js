import * as THREE from 'three/webgpu';
import {
  Fn, vec2, vec3, vec4, float, uniform, texture, dot, sqrt, exp, max, min, clamp, mix, length, normalize,
  smoothstep, saturate, uv, select, pow, cross, abs, fract, sin, cos, floor, screenUV, time,
  positionWorldDirection, mx_noise_float, If, luminance, equirectUV,
} from 'three/tsl';
import { Atmosphere, sky, lutUVFromDir, SUN_RADIUS, MOON_RADIUS, transmittanceCPU, SUN_E } from './atmosphere.js';
import { cloud, CloudPass, makeCloudMarch, skyLutRef, buildCloudTextures, BASE_TILE, DETAIL_TILE, WEATHER_TILE } from './clouds.js';
import { fogU, fogColorFor } from './fog.js';

// Everything above the horizon: atmosphere LUT, volumetric clouds, sun, moon
// with its phase, stars and the Milky Way. Also renders the equirectangular
// sky that the sea reflects and that lights the scene (via PMREM).

export const sea = {
  // Colour of the open water as seen from above, used for the lower half of
  // the environment (the light that bounces up under every overhang).
  deep: uniform(new THREE.Color(0.006, 0.03, 0.06)),
};

const hash13 = (p) => fract(sin(dot(p, vec3(127.1, 311.7, 74.7))).mul(43758.5453));

/** Sun disc with limb darkening. */
const sunDisc = Fn(([d]) => {
  const c = dot(d, sky.sunDir);
  const r = sqrt(max(float(1.0).sub(c.mul(c)), 0.0)).div(SUN_RADIUS);   // 0 centre, 1 limb
  const inside = smoothstep(1.08, 0.94, r).mul(c.greaterThan(0.0));
  const limb = pow(max(float(1.0).sub(r.mul(r)), 0.0), 0.35).mul(0.75).add(0.25);
  // Radiance = illuminance / disc solid angle, clamped to keep TAA/bloom sane.
  const solid = Math.PI * SUN_RADIUS * SUN_RADIUS;
  return min(sky.sunColor.mul(1.0 / solid).mul(0.02), vec3(260.0)).mul(inside).mul(limb);
});

/** Moon disc lit from the sun's direction: the phase falls out of the geometry. */
const moonDisc = Fn(([d]) => {
  const m = sky.moonDir;
  const c = dot(d, m);
  const up = select(abs(m.y).greaterThan(0.95), vec3(1, 0, 0), vec3(0, 1, 0));
  const tx = normalize(cross(up, m));
  const ty = cross(m, tx);
  const off = d.sub(m.mul(c));
  const x = dot(off, tx).div(MOON_RADIUS);
  const y = dot(off, ty).div(MOON_RADIUS);
  const rr = x.mul(x).add(y.mul(y));
  const inside = smoothstep(1.05, 0.95, sqrt(rr)).mul(c.greaterThan(0.0));
  const z = sqrt(max(float(1.0).sub(rr), 0.0));
  const n = tx.mul(x).add(ty.mul(y)).add(m.negate().mul(z));     // surface normal facing the viewer
  // Lit where the surface faces the sun: full when the sun is behind us,
  // a thin crescent when it is beside the moon.
  const nl = saturate(dot(n, sky.sunDir));
  // Maria: dark lowland patches.
  const mar = mx_noise_float(vec3(x.mul(2.2), y.mul(2.2), 3.7)).mul(0.5).add(mx_noise_float(vec3(x.mul(5.0), y.mul(5.0), 1.3)).mul(0.25));
  const albedo = float(0.75).sub(smoothstep(0.05, 0.35, mar).mul(0.32));
  const earthshine = float(0.012);
  const solid = Math.PI * MOON_RADIUS * MOON_RADIUS;
  return sky.moonColor.mul(1.0 / solid).mul(0.06).mul(albedo).mul(nl.add(earthshine)).mul(inside);
});

const stars = Fn(([d]) => {
  const s = sky.starMatrix.mul(d);
  const P = s.mul(190.0);
  const cell = floor(P);
  const h = hash13(cell);
  const jitter = vec3(hash13(cell.add(1.3)), hash13(cell.add(7.1)), hash13(cell.add(3.7)));
  const star = cell.add(jitter);
  const dd = length(P.sub(star));
  const bright = pow(h, 18.0).mul(0.6).add(pow(h, 60.0).mul(3.5));
  const tw = sin(time.mul(hash13(cell.add(9.9)).mul(4.0).add(2.0)).add(h.mul(40.0))).mul(0.25).add(0.75);
  const pt = smoothstep(0.32, 0.0, dd).mul(bright).mul(tw).mul(step01(h, 0.86));
  // Milky Way: a soft band of unresolved stars along the galactic plane.
  const gp = normalize(vec3(0.42, 0.55, 0.72));
  const g = dot(s, gp);
  const band = exp(g.mul(g).mul(-28.0));
  const dust = mx_noise_float(s.mul(9.0)).mul(0.5).add(mx_noise_float(s.mul(23.0)).mul(0.25)).add(0.5);
  const mw = band.mul(saturate(dust)).mul(0.004);
  const tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.78), hash13(cell.add(5.5)));
  return tint.mul(pt.mul(0.06)).add(vec3(0.8, 0.85, 1.0).mul(mw));
});

function step01(v, edge) { return select(v.greaterThan(edge), float(1.0), float(0.0)); }

/** Radiance of the sky without clouds in direction d (atmosphere + bodies + stars). */
export const clearSky = Fn(([d, withBodies]) => {
  const L = texture(skyLutRef.tex, lutUVFromDir(d)).rgb.toVar();
  If(withBodies.greaterThan(0.5), () => {
    const skyLum = luminance(L);
    const starVis = saturate(float(1.0).sub(skyLum.mul(220.0))).mul(smoothstep(-0.02, 0.08, d.y));
    L.addAssign(stars(d).mul(starVis));
    L.addAssign(moonDisc(d));
    L.addAssign(sunDisc(d));
  });
  return L;
});

export class Sky {
  constructor(renderer, scene, quality) {
    this.renderer = renderer;
    this.scene = scene;
    this.atmo = new Atmosphere(renderer);
    skyLutRef.tex = this.atmo.lut.texture;
    buildCloudTextures();
    this.clouds = new CloudPass(renderer, quality);

    // Equirect sky (with clouds, without the sun disc) for reflections and IBL.
    this.env = new THREE.RenderTarget(512, 256, { type: THREE.HalfFloatType, depthBuffer: false });
    this.env.texture.mapping = THREE.EquirectangularReflectionMapping;
    this.env.texture.wrapS = THREE.RepeatWrapping;
    this.env.texture.minFilter = THREE.LinearFilter;
    this.env.texture.magFilter = THREE.LinearFilter;
    this.env.texture.generateMipmaps = false;
    const envMarch = makeCloudMarch(18, 3);
    const envMat = new THREE.MeshBasicNodeMaterial();
    envMat.fragmentNode = Fn(() => {
      const q = uv();
      // Matches TSL equirectUV(): u = atan(z, x)/2pi + 0.5, v = asin(y)/pi + 0.5.
      const phi = q.x.sub(0.5).mul(2.0 * Math.PI);
      const th = q.y.oneMinus().sub(0.5).mul(Math.PI);
      const d = vec3(cos(th).mul(cos(phi)), sin(th), cos(th).mul(sin(phi)));
      const up = normalize(vec3(d.x, max(d.y, 0.002), d.z));
      const c = envMarch(up, float(0.5));
      const L = clearSky(up, float(0.0)).mul(c.a).add(c.rgb);
      // Below the horizon: the sea, mostly sky reflected at grazing angles
      // fading to the dark water body looking straight down.
      const f = pow(float(1.0).sub(saturate(d.y.negate())), 5.0).mul(0.6).add(0.02);
      const water = mix(sea.deep.mul(luminance(L).mul(3.0).add(0.02)), L, f);
      // Plus the light bounced up from sunlit decks, hull and foam nearby:
      // without it every overhang underside goes black (no real GI here).
      const bounce = sky.sunColor.mul(saturate(sky.sunDir.y).mul(0.05)).add(sky.moonColor.mul(saturate(sky.moonDir.y).mul(0.05)));
      const below = water.add(bounce.mul(smoothstep(0.0, -0.35, d.y)));
      return vec4(select(d.y.lessThan(0.0), below, L), 1.0);
    })();
    this.envQuad = new THREE.QuadMesh(envMat);
    this.envFrame = 0;

    // The screen: the scene's background shows the atmosphere and bodies,
    // with the screen-space cloud layer composited over them.
    const cloudTex = this.clouds.rt.texture;
    scene.backgroundNode = Fn(() => {
      const d = normalize(positionWorldDirection);
      const L = clearSky(d, float(1.0));
      const c = texture(cloudTex, screenUV);
      const col = L.mul(c.a).add(c.rgb);
      // In fog and heavy rain the sky near the horizon is veiled too.
      const veil = fogU.skyMix.mul(pow(float(1.0).sub(saturate(d.y)), 2.5));
      return vec4(mix(col, fogColorFor(d), veil), 1.0);
    })();
    scene.environment = this.env.texture;
    scene.environmentIntensity = 1.35;
    this._lightCache = [0, 0, 0];
    this.time = 0;
  }

  /**
   * Per-frame CPU work: light colours, cloud uniforms (offsets wrap so they
   * stay precise however far the ship sails) and the passes.
   */
  update({ clock, weather, camera, shipDistance, dt, windEarth }) {
    const w = weather.current;
    sky.sunDir.value.copy(clock.sunDir);
    sky.moonDir.value.copy(clock.moonDir);
    sky.starMatrix.value.copy(clock.starMatrix);
    sky.moonPhase.value = clock.moonPhase;
    sky.haze.value = w.haze;
    const camAlt = Math.max(0.0005, camera.position.y / 1000);
    sky.observerAlt.value = camAlt;
    this.atmo.updateLights(clock.sunDir, clock.moonDir, clock.moonIllum, w.haze, camAlt);

    cloud.cover.value = w.cover;
    cloud.density.value = w.density;
    cloud.base.value = w.base;
    cloud.thick.value = w.thick;
    cloud.type.value = w.type;
    cloud.gloom.value = w.gloom;
    cloud.camKm.value.set(camera.position.x / 1000, camAlt, camera.position.z / 1000);

    // Sun colour at the middle of the cloud layer: high cloud stays lit
    // after the sun has set for the deck (the afterglow).
    const t = this._lightCache;
    transmittanceCPU(w.base + w.thick * 0.5, clock.sunDir.y + 0.02, w.haze, t);
    cloud.sunColor.value.setRGB(t[0] * SUN_E, t[1] * SUN_E, t[2] * SUN_E);
    const mt = transmittanceCPU(w.base + w.thick * 0.5, clock.moonDir.y, w.haze, [0, 0, 0]);
    const mE = sky.moonE.value;
    cloud.sunColor.value.r += mt[0] * mE * 0.9;
    cloud.sunColor.value.g += mt[1] * mE * 0.95;
    cloud.sunColor.value.b += mt[2] * mE * 1.1;

    // Drift: the ship sails through the field (+x), the wind carries it.
    const ox = shipDistance / 1000 + windEarth.x * this.time / 1000;
    const oz = windEarth.y * this.time / 1000;
    this.time += dt;
    const wrap = (v, tile) => (((v / tile) % 1) + 1) % 1;
    cloud.offBase.value.set(wrap(ox, BASE_TILE), 0, wrap(oz, BASE_TILE));
    cloud.offDetail.value.set(wrap(ox * 1.08, DETAIL_TILE), wrap(this.time * 0.002, 1), wrap(oz * 1.08, DETAIL_TILE));
    cloud.offWeather.value.set(wrap(ox, WEATHER_TILE), wrap(oz, WEATHER_TILE));

    this.atmo.render();
    this.ambientFromLut(clock, w);
    this.clouds.render(camera);
    if (this.envFrame++ % 8 === 0) this.renderEnv();
  }

  /** Approximate cloud ambient colours from the sun and moon state. */
  ambientFromLut(clock, w) {
    const sunUp = THREE.MathUtils.smoothstep(clock.sunDir.y, -0.12, 0.25);
    const top = cloud.ambTop.value;
    const s = sky.sunColor.value;
    const day = 0.07 * SUN_E * sunUp;
    top.setRGB(0.55 * day + 0.004, 0.68 * day + 0.006, 0.95 * day + 0.012);
    // Low sun reddens the ambient a little; rain and storm darken it.
    top.r += s.r * 0.012; top.g += s.g * 0.01; top.b += s.b * 0.008;
    const mE = sky.moonE.value;
    top.r += mE * 0.12; top.g += mE * 0.15; top.b += mE * 0.22;
    cloud.ambBottom.value.copy(top).multiplyScalar(0.35);
  }

  renderEnv() {
    const r = this.renderer;
    const prev = r.getRenderTarget();
    r.setRenderTarget(this.env);
    this.envQuad.render(r);
    r.setRenderTarget(prev);
    this.env.texture.needsPMREMUpdate = true;
  }

  resize(w, h) { this.clouds.resize(w, h); }
}
