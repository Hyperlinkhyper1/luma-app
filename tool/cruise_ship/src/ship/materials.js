import * as THREE from 'three/webgpu';
import {
  Fn, vec2, vec3, vec4, float, uniform, positionWorld, normalWorld, mx_noise_float, floor, fract, mix,
  smoothstep, saturate, abs, sin, dot, max, min, step, select, time, uv, texture, length, pow, If,
} from 'three/tsl';

// Shared ship materials. All surface detail is procedural (no image files),
// evaluated in ship-local coordinates so it stays glued to the hull as the
// ship rolls: teak with caulked seams, weathered white paint with rain
// streaks, non-slip crew decks, mullioned navy glazing, cabin glass that
// lights up at night, and so on.

export const shipU = {
  inv: uniform(new THREE.Matrix4()),   // world -> ship
  wet: uniform(0),                     // rain on the decks
  night: uniform(0),                   // 0 day .. 1 full night (lights on)
  lightBoost: uniform(1),              // deck light intensity scale
};

/** Ship-local position of the fragment. */
export const shipPos = Fn(() => shipU.inv.mul(vec4(positionWorld, 1.0)).xyz);

const hash11 = (x) => fract(sin(x.mul(127.1)).mul(43758.5453));
const hash21 = (p) => fract(sin(dot(p, vec2(127.1, 311.7))).mul(43758.5453));
const hash31 = (p) => fract(sin(dot(p, vec3(127.1, 311.7, 74.7))).mul(43758.5453));

const lin = (hex) => new THREE.Color(hex);

function std(opts) {
  const m = new THREE.MeshStandardNodeMaterial(opts);
  return m;
}

/** Wet surfaces: darker albedo, near-mirror roughness on horizontal faces. */
const wetMix = (color, rough, upFacing) => {
  const w = shipU.wet.mul(upFacing);
  return { color: color.mul(float(1.0).sub(w.mul(0.45))), rough: mix(rough, float(0.08), w.mul(0.85)) };
};

export function makeMaterials() {
  const M = {};

  // --- White paint, the bulk of the ship ------------------------------------
  {
    const m = std({ roughness: 0.42, metalness: 0.0 });
    const base = lin('#e4e7ea');
    m.colorNode = Fn(() => {
      const p = shipPos();
      const n = normalWorld;
      const vert = float(1.0).sub(abs(n.y));
      // Broad, gentle tonal variation between panels.
      const broad = mx_noise_float(p.mul(0.035)).mul(0.035);
      // Rain streaks and grime run down vertical faces.
      const streak = mx_noise_float(vec3(p.x.mul(2.3), p.y.mul(0.09), p.z.mul(2.3)));
      const streak2 = mx_noise_float(vec3(p.x.mul(9.0), p.y.mul(0.35), p.z.mul(9.0)));
      const grime = saturate(streak.mul(0.6).add(streak2.mul(0.4)).sub(0.15)).mul(0.07).mul(vert);
      // Rare rust weeps (photo 1: orange drips below fittings).
      const rust = smoothstep(0.72, 0.9, streak2).mul(smoothstep(0.55, 0.75, streak)).mul(vert).mul(0.25);
      const c = vec3(base.r, base.g, base.b).mul(float(1.0).add(broad).sub(grime));
      return mix(c, vec3(0.42, 0.22, 0.12), rust.mul(0.35));
    })();
    m.roughnessNode = Fn(() => {
      const up = saturate(normalWorld.y);
      return mix(float(0.42), float(0.12), shipU.wet.mul(up).mul(0.8));
    })();
    M.paint = m;
  }
  // Slightly darker off-white for soffits and recessed walls.
  M.paintShade = std({ color: lin('#d3d7dc'), roughness: 0.55 });

  // --- Hull below the white: antifouling red, boot-top black -----------------
  M.hullRed = std({ color: lin('#7e1f17'), roughness: 0.62 });
  M.boot = std({ color: lin('#0f1012'), roughness: 0.5 });
  M.hullWhite = M.paint;

  // --- Navy: funnel, bands, logo ---------------------------------------------
  M.navy = std({ color: lin('#0d1b33'), roughness: 0.38, metalness: 0.15 });
  M.navyMatte = std({ color: lin('#0f1d36'), roughness: 0.6 });

  // --- Navy glazing with mullions (decks 5-6 public rooms, top decks) --------
  {
    const m = std({ metalness: 0.0, roughness: 0.06 });
    m.colorNode = Fn(() => {
      const p = shipPos();
      const fx = fract(p.x.add(p.z).div(1.55));
      const fy = fract(p.y.div(1.475));
      const mull = max(smoothstep(0.03, 0.0, fx).add(smoothstep(0.97, 1.0, fx)), smoothstep(0.035, 0.0, fy).add(smoothstep(0.965, 1.0, fy)));
      return mix(vec3(0.010, 0.022, 0.05), vec3(0.08, 0.1, 0.13), saturate(mull));
    })();
    m.emissiveNode = Fn(() => {
      // Public rooms behind the dark glass at night: lit bays with a row of
      // ceiling lights near the top of each deck, dark mullions between.
      const p = shipPos();
      const u = p.x.add(p.z);
      const cell = floor(vec2(u.div(6.2), p.y.div(2.95)));
      const on = smoothstep(0.3, 0.45, hash21(cell));
      const fy = fract(p.y.div(2.95));
      const ceiling = smoothstep(0.62, 0.86, fy).mul(smoothstep(1.0, 0.9, fy));
      const lamps = smoothstep(0.35, 0.0, abs(fract(u.div(1.55)).sub(0.5))).mul(ceiling);
      const glow = on.mul(fy.mul(0.5).add(0.25)).add(lamps.mul(on.mul(0.8).add(0.2)));
      const fx = fract(u.div(1.55));
      const mull = smoothstep(0.03, 0.0, fx).add(smoothstep(0.97, 1.0, fx));
      return vec3(1.0, 0.74, 0.46).mul(glow.mul(0.028)).mul(float(1.0).sub(saturate(mull))).mul(shipU.night).mul(shipU.lightBoost);
    })();
    M.navyGlass = m;
  }

  // --- Cabin door glass (opaque, reflective, lit at night) -------------------
  {
    const m = std({ metalness: 0.0, roughness: 0.07 });
    m.colorNode = vec3(0.012, 0.016, 0.022);
    m.emissiveNode = Fn(() => {
      const p = shipPos();
      // One cabin per 3.45 m pitch and deck: about a third lit at night,
      // some through curtains (dimmer, warmer).
      const cell = floor(vec3(p.x.div(3.45), p.y.div(2.95), p.z.div(3.45)));
      const h = hash31(cell);
      const lit = step(0.62, h);
      const curtain = step(0.82, h);
      const warm = mix(vec3(1.0, 0.78, 0.5), vec3(1.0, 0.62, 0.32), curtain);
      const lp = fract(p.y.div(2.95));
      const lamp = smoothstep(0.0, 0.5, lp).mul(0.6).add(0.4);
      return warm.mul(lit).mul(mix(float(0.12), float(0.05), curtain)).mul(lamp).mul(shipU.night).mul(shipU.lightBoost);
    })();
    M.cabinGlass = m;
  }

  // --- Balcony railing glass: tinted, see-through -----------------------------
  {
    const m = new THREE.MeshPhysicalNodeMaterial({
      color: lin('#3b5670'), roughness: 0.05, metalness: 0.0, transparent: true, opacity: 0.5,
      depthWrite: false, side: THREE.DoubleSide,
    });
    m.userData.noShadow = true;
    M.railGlass = m;
  }
  // Windscreens around the pool: clearer.
  {
    const m = new THREE.MeshPhysicalNodeMaterial({
      color: lin('#9fb6c4'), roughness: 0.04, transparent: true, opacity: 0.22, depthWrite: false, side: THREE.DoubleSide,
    });
    m.userData.noShadow = true;
    M.clearGlass = m;
  }

  // --- Teak (composite) decking with dark caulk seams -------------------------
  {
    const m = std({ roughness: 0.6 });
    const light = lin('#a3653a'), dark = lin('#7a4423');
    m.colorNode = Fn(() => {
      const p = shipPos();
      const w = float(0.145);
      const row = floor(p.z.div(w));
      const fz = fract(p.z.div(w));
      const off = hash11(row).mul(5.4);
      const seg = floor(p.x.add(off).div(5.4));
      const fxp = fract(p.x.add(off).div(5.4));
      const tone = hash21(vec2(row, seg));
      const grain = mx_noise_float(vec3(p.x.mul(1.4), p.z.mul(30.0), seg)).mul(0.08);
      const c = mix(vec3(light.r, light.g, light.b), vec3(dark.r, dark.g, dark.b), tone.mul(0.7)).mul(float(1.0).add(grain));
      const seam = max(smoothstep(0.06, 0.0, fz), smoothstep(0.94, 1.0, fz)).max(max(smoothstep(0.004, 0.0, fxp), smoothstep(0.996, 1.0, fxp)));
      const col = mix(c, vec3(0.025, 0.022, 0.02), seam.mul(0.9));
      return col.mul(float(1.0).sub(shipU.wet.mul(0.45)));
    })();
    m.roughnessNode = mix(float(0.62), float(0.1), shipU.wet.mul(0.9));
    M.teak = m;
  }

  // --- Non-slip crew deck paint (grey-green) ----------------------------------
  {
    const m = std({ roughness: 0.88 });
    m.colorNode = Fn(() => {
      const p = shipPos();
      const n = mx_noise_float(p.mul(0.6)).mul(0.05).add(mx_noise_float(p.mul(7.0)).mul(0.03));
      return vec3(0.33, 0.36, 0.35).mul(float(1.0).add(n)).mul(float(1.0).sub(shipU.wet.mul(0.4)));
    })();
    m.roughnessNode = mix(float(0.88), float(0.18), shipU.wet.mul(0.85));
    M.crewDeck = m;
  }

  // --- Metals and trims -------------------------------------------------------
  M.steel = std({ color: lin('#c9ced3'), roughness: 0.38, metalness: 0.25 });
  M.steelDark = std({ color: lin('#5b6168'), roughness: 0.45, metalness: 0.3 });
  M.stainless = std({ color: lin('#c8ccd0'), roughness: 0.22, metalness: 1.0 });
  M.black = std({ color: lin('#141618'), roughness: 0.55 });
  M.rubber = std({ color: lin('#1b1c1e'), roughness: 0.9 });
  M.woodRail = std({ color: lin('#9a4f1d'), roughness: 0.32 });
  M.ropeYellow = std({ color: lin('#d9b21c'), roughness: 0.6 });
  M.trussYellow = std({ color: lin('#e0b11a'), roughness: 0.45, metalness: 0.2 });
  M.orangeStair = std({ color: lin('#d77a2b'), roughness: 0.5 });

  // --- Lifeboats and liferafts -------------------------------------------------
  M.boatOrange = std({ color: lin('#e8571b'), roughness: 0.32 });
  M.boatWhite = std({ color: lin('#e9ecee'), roughness: 0.35 });
  M.boatWindow = std({ color: lin('#141a20'), roughness: 0.1 });
  M.raftWhite = std({ color: lin('#e6e8e6'), roughness: 0.55 });
  M.strapYellow = std({ color: lin('#c8d22a'), roughness: 0.7 });
  M.strapBlue = std({ color: lin('#283f63'), roughness: 0.75 });
  M.bagBlack = std({ color: lin('#16181b'), roughness: 0.85 });
  M.lifeRing = std({ color: lin('#e8461f'), roughness: 0.5 });

  // --- Furniture -------------------------------------------------------------
  M.wicker = std({ color: lin('#2e2620'), roughness: 0.9 });
  M.lounger = std({ color: lin('#3a3d42'), roughness: 0.7 });
  M.loungerPad = std({ color: lin('#d9d6cf'), roughness: 0.85 });
  M.towelBlue = std({ color: lin('#2f5a8c'), roughness: 0.9 });
  M.fishBlue = std({ color: lin('#2d5f78'), roughness: 0.35, metalness: 0.15 });
  M.mosaic = std({ color: lin('#e6eef0'), roughness: 0.35 });

  // --- Lights (emissive, follow the night factor) ------------------------------
  {
    const m = std({ color: lin('#fff3dc'), roughness: 0.4 });
    m.emissiveNode = vec3(1.0, 0.86, 0.62).mul(shipU.night.mul(0.9).add(0.04)).mul(shipU.lightBoost).mul(0.35);
    M.lampWarm = m;
  }
  {
    const m = std({ color: lin('#ffffff'), roughness: 0.4 });
    m.emissiveNode = vec3(0.92, 0.95, 1.0).mul(shipU.night.mul(0.9).add(0.05)).mul(shipU.lightBoost).mul(0.4);
    M.lampCool = m;
  }
  {
    const m = std({ color: lin('#fff1d6'), roughness: 0.5 });
    m.emissiveNode = vec3(1.0, 0.84, 0.58).mul(shipU.night).mul(shipU.lightBoost).mul(0.3);
    M.lantern = m;   // cube deck lanterns (photo 3)
  }
  M.navRed = std({ color: lin('#ff2a1a'), roughness: 0.3, emissive: lin('#ff2010'), emissiveIntensity: 0.6 });
  M.navGreen = std({ color: lin('#1aff4a'), roughness: 0.3, emissive: lin('#10ff40'), emissiveIntensity: 0.6 });
  M.navWhite = std({ color: lin('#ffffff'), roughness: 0.3, emissive: lin('#ffffff'), emissiveIntensity: 0.6 });

  return M;
}

/** Canvas texture helper for lettering and emblems (sRGB, mipmapped). */
export function canvasTexture(w, h, draw, { repeat = false } = {}) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  const g = c.getContext('2d');
  draw(g, w, h);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 8;
  t.generateMipmaps = true;
  t.minFilter = THREE.LinearMipmapLinearFilter;
  if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.needsUpdate = true;
  return t;
}

/** The MSC compass-rose emblem, drawn as vector art into a canvas. */
export function drawCompass(g, cx, cy, r, color = '#0d1b33', bg = null) {
  g.save();
  g.translate(cx, cy);
  if (bg) { g.fillStyle = bg; g.beginPath(); g.arc(0, 0, r * 1.02, 0, Math.PI * 2); g.fill(); }
  g.fillStyle = color;
  // 16-point star: long cardinal points, shorter intermediates.
  g.beginPath();
  for (let i = 0; i < 32; i++) {
    const a = (i / 32) * Math.PI * 2 - Math.PI / 2;
    const rr = i % 2 === 0 ? (i % 8 === 0 ? r : i % 4 === 0 ? r * 0.72 : r * 0.56) : r * 0.34;
    const x = Math.cos(a) * rr, y = Math.sin(a) * rr;
    if (i === 0) g.moveTo(x, y); else g.lineTo(x, y);
  }
  g.closePath();
  g.fill();
  // Inner disc with the lowercase monogram.
  g.fillStyle = bg || '#ffffff';
  g.beginPath(); g.arc(0, 0, r * 0.4, 0, Math.PI * 2); g.fill();
  g.strokeStyle = color; g.lineWidth = r * 0.045;
  g.beginPath(); g.arc(0, 0, r * 0.4, 0, Math.PI * 2); g.stroke();
  g.fillStyle = color;
  g.font = `italic 700 ${r * 0.34}px Georgia, 'Times New Roman', serif`;
  g.textAlign = 'center'; g.textBaseline = 'middle';
  g.fillText('m', -r * 0.02, -r * 0.1);
  g.fillText('sc', r * 0.02, r * 0.17);
  g.restore();
}
