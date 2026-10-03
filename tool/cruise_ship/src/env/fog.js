import * as THREE from 'three/webgpu';
import {
  Fn, vec3, float, uniform, fog, positionWorld, cameraPosition, length, normalize, exp, max, abs, select,
  texture, mix, saturate, smoothstep,
} from 'three/tsl';
import { sky, lutUVFromDir } from './atmosphere.js';
import { cloud, skyLutRef } from './clouds.js';

// Aerial perspective and sea fog: two exponential height layers (a thin
// haze that thins out over ~1.5 km, and a dense low fog bank ~150 m deep),
// integrated analytically along each view ray. The colour is the sky's own
// horizon in that direction, so distant water melts into the horizon the
// way it does in the hazy reference photos; thick fog turns lit grey-white.

export const fogU = {
  haze: uniform(6.5e-5),     // extinction at sea level, 1/m
  bank: uniform(0.0),        // dense fog layer at sea level, 1/m
  skyMix: uniform(0.0),      // how much fog veils the sky near the horizon
};

const H_HAZE = 1500, H_BANK = 150;

/** Optical depth along a ray from camera height y0 over distance d rising dy (per metre). */
const layerDepth = (sigma, H, y0, dist, dy) => {
  const k = dy.div(H);
  const a = exp(max(y0, 0.0).negate().div(H));
  const f = select(abs(k).lessThan(1e-5), dist, float(1.0).sub(exp(k.mul(dist).negate())).div(k));
  return sigma.mul(a).mul(f);
};

export const fogColorFor = Fn(([dir]) => {
  const flat = normalize(vec3(dir.x, max(dir.y, 0.02), dir.z));
  const horizon = texture(skyLutRef.tex, lutUVFromDir(flat)).rgb;
  // Dense fog is lit from above: brighter, greyer and less blue.
  const lit = cloud.ambTop.mul(2.4).add(sky.sunColor.mul(0.035)).add(sky.moonColor.mul(0.03));
  const t = saturate(fogU.bank.mul(220.0));
  return mix(horizon, lit, t);
});

export function installFog(scene) {
  const factor = Fn(() => {
    const toFrag = positionWorld.sub(cameraPosition);
    const dist = length(toFrag);
    const dy = toFrag.y.div(max(dist, 1e-3));
    const y0 = cameraPosition.y;
    const tau = layerDepth(fogU.haze, H_HAZE, y0, dist, dy).add(layerDepth(fogU.bank, H_BANK, y0, dist, dy));
    return float(1.0).sub(exp(tau.negate()));
  })();
  const color = Fn(() => fogColorFor(normalize(positionWorld.sub(cameraPosition))))();
  scene.fogNode = fog(color, factor);
}

/** Map the weather to fog densities. Visibility V (km) -> sigma = 3.912 / V. */
export function updateFog(weather) {
  const w = weather.current;
  let vis = THREE.MathUtils.lerp(70, 11, THREE.MathUtils.clamp((w.haze - 0.9) / 4.6, 0, 1));
  vis = THREE.MathUtils.lerp(vis, 3.5, w.rain);
  fogU.haze.value = 3.912 / (vis * 1000);
  const bankVis = THREE.MathUtils.lerp(30, 0.45, Math.pow(w.fog, 0.6));
  fogU.bank.value = w.fog > 0.01 ? 3.912 / (bankVis * 1000) : 0;
  fogU.skyMix.value = Math.min(1, Math.pow(w.fog, 0.8) + w.rain * 0.35);
}
