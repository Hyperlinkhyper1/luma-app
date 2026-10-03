import * as THREE from 'three/webgpu';
import { CSMShadowNode } from 'three/addons/csm/CSMShadowNode.js';
import { settings } from './settings.js';
import { sky } from '../env/atmosphere.js';
import { postU } from './post.js';
import { shipU } from '../ship/materials.js';
import { weatherCoverageCPU, WEATHER_TILE, cloud } from '../env/clouds.js';

// Sun/moon light with cascaded shadows, eye-like exposure adaptation, the
// night factor that turns the ship's lights on, and a small pool of real
// point lights that follows the viewer to the nearest deck lamps (every
// lamp is emissive; only the closest ones actually light their surroundings).

const SHADOW = {
  off: null,
  low: { size: 1024, cascades: 3, far: 320 },
  medium: { size: 2048, cascades: 3, far: 480 },
  high: { size: 2048, cascades: 3, far: 600 },
  ultra: { size: 4096, cascades: 4, far: 900 },
};

const POOL = 10;

export class Lighting {
  constructor(scene, shipRoot, lamps) {
    this.scene = scene;
    this.shipRoot = shipRoot;
    this.lamps = lamps;
    this.exposure = 1;
    this.night = 0;
    this.cloudSun = 1;
    this.sun = null;
    this._applyShadows(settings.get().graphics.shadows);
    settings.onChange((p) => { if (p === 'graphics.shadows' || p === 'graphics.preset' || p === '*') this._applyShadows(settings.get().graphics.shadows); });

    // Point-light pool, parented to the ship so lamp positions are local.
    this.pool = [];
    for (let i = 0; i < POOL; i++) {
      const l = new THREE.PointLight(0xffd9a8, 0, 14, 2);
      l.castShadow = false;
      shipRoot.add(l);
      this.pool.push(l);
    }
    this._tmp = new THREE.Vector3();
  }

  _applyShadows(level) {
    const cfg = SHADOW[level] ?? SHADOW.high;
    if (this.sun) {
      this.scene.remove(this.sun);
      this.scene.remove(this.sun.target);
      this.sun.dispose?.();
    }
    const sun = new THREE.DirectionalLight(0xffffff, 1);
    sun.castShadow = !!cfg;
    if (cfg) {
      sun.shadow.mapSize.set(cfg.size, cfg.size);
      sun.shadow.bias = -0.0003;
      sun.shadow.normalBias = 0.05;
      sun.shadow.radius = 2;
      sun.shadow.camera.near = 1;
      sun.shadow.camera.far = 2400;
      const csm = new CSMShadowNode(sun, { cascades: cfg.cascades, maxFar: cfg.far, mode: 'practical', lightMargin: 260 });
      csm.fade = true;
      sun.shadow.shadowNode = csm;
    }
    this.sun = sun;
    this.scene.add(sun);
    this.scene.add(sun.target);
  }

  update(dt, { clock, weather, viewLocal, snap }) {
    const w = weather.current;
    // Average cloud cover toward the sun over the ship, from the weather map.
    const s = clock.sunDir;
    const up = Math.max(0.05, s.y);
    const toBase = (w.base * 1000) / up;
    const sx = (s.x * toBase) / 1000, sz = (s.z * toBase) / 1000;
    const off = cloud.offWeather.value;
    const cov = weatherCoverageCPU(sx / WEATHER_TILE + off.x, sz / WEATHER_TILE + off.y);
    const t0 = 1 - w.cover * 1.18;
    const covS = Math.max(Math.min(1, Math.max(0, (cov - t0) / 0.32)), THREE.MathUtils.smoothstep(w.cover, 0.8, 1.0));
    const sunVis = 1 - covS * Math.min(0.97, w.density * 0.55 + w.thick * 0.2);
    if (Number.isFinite(sunVis)) this.cloudSun += (sunVis - this.cloudSun) * Math.min(1, dt * (snap ? 60 : 0.6));

    const sunUp = s.y > -0.035;
    const dir = sunUp ? s : clock.moonDir;
    this.sun.position.copy(dir).multiplyScalar(500);
    this.sun.target.position.set(0, 0, 0);
    this.sun.color.copy(sunUp ? sky.sunColor.value : sky.moonColor.value);
    this.sun.intensity = Math.max(0.0001, this.cloudSun);

    // Lights on from late dusk, earlier under heavy cloud.
    const nightTarget = 1 - THREE.MathUtils.smoothstep(s.y + w.gloom * 0.06, -0.08, 0.05);
    this.night += (nightTarget - this.night) * Math.min(1, dt * (snap ? 60 : 0.5));
    shipU.night.value = this.night;

    // Exposure follows horizontal illuminance (sun, a skylight model that
    // falls ~0.4 decades per degree below the horizon, the moon).
    const eDeg = THREE.MathUtils.radToDeg(Math.asin(THREE.MathUtils.clamp(s.y, -1, 1)));
    const sc = sky.sunColor.value;
    const lum = (c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    const eSun = lum(sc) * Math.max(0, s.y) * this.cloudSun;
    const sky0 = 0.4 * Math.pow(10, -15 / 11.5);
    const eSky = (eDeg >= 0 ? 0.4 * Math.pow(10, -(15 - Math.min(eDeg, 15)) / 11.5) : sky0 * Math.pow(10, 0.4 * eDeg)) * (1 - w.gloom * 0.55);
    const eMoon = lum(sky.moonColor.value) * Math.max(0, clock.moonDir.y) * this.cloudSun;
    // The eye adapts to grey weather, but not all the way: storms stay dark.
    const target = THREE.MathUtils.clamp(1.9 / (eSun + eSky + eMoon + 0.0045), 0.5, 13) * (1 - w.gloom * 0.5) * (1 - w.fog * 0.25);
    const k = snap ? 1 : Math.min(1, dt * (target > this.exposure ? 0.7 : 1.8));
    this.exposure = Math.exp(Math.log(this.exposure) + (Math.log(target) - Math.log(this.exposure)) * k);
    postU.exposure.value = this.exposure;
    // At night the lamps should read as lamps, not floodlights: scale their
    // emissive with the inverse exposure so they stay at a sensible level.
    shipU.lightBoost.value = THREE.MathUtils.clamp(3.4 / this.exposure, 0.22, 1.2);

    this._updatePool(viewLocal);
  }

  _updatePool(viewLocal) {
    const on = this.night > 0.02;
    if (!on || !viewLocal) { for (const l of this.pool) l.intensity = 0; return; }
    // Nearest lamps to the viewer (ship-local).
    const best = [];
    for (const L of this.lamps) {
      const dx = L.x - viewLocal.x, dy = (L.y - viewLocal.y) * 2, dz = L.z - viewLocal.z;
      const d2 = dx * dx + dy * dy + dz * dz;
      if (best.length < POOL) { best.push([d2, L]); best.sort((a, b) => a[0] - b[0]); }
      else if (d2 < best[POOL - 1][0]) { best[POOL - 1] = [d2, L]; best.sort((a, b) => a[0] - b[0]); }
    }
    for (let i = 0; i < POOL; i++) {
      const l = this.pool[i];
      const b = best[i];
      if (!b) { l.intensity = 0; continue; }
      const L = b[1];
      l.position.set(L.x, L.y, L.z);
      l.color.set(L.color ?? 0xffd9a8);
      l.distance = L.range ?? 12;
      // Fade the farthest ones so swapping lamps never pops.
      const fade = THREE.MathUtils.smoothstep(Math.sqrt(best[POOL - 1]?.[0] ?? 1e9) - Math.sqrt(b[0]), 0, 6);
      l.intensity = (L.intensity ?? 1.2) * this.night * fade * 0.6;
    }
  }
}
