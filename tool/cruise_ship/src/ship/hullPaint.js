import * as THREE from 'three/webgpu';
import {
  Fn, vec2, vec3, vec4, float, abs, max, min, length, floor, fract, sin, dot, mix, step, smoothstep, saturate,
  select, texture, normalView, positionView, faceDirection, mx_noise_float, clamp, sign,
} from 'three/tsl';
import { shipPos, shipU, canvasTexture, drawCompass } from './materials.js';
import { STERN_X } from './dims.js';

// The hull's paint job, all in one shader evaluated in ship coordinates, so
// nothing is a separate decal that can float off the curved plating: the red
// antifouling and navy boot-top, white topsides with welded plate seams and
// the slight dishing between frames, rows of cabin windows (elongated, in
// groups, as on the real ship), the anchor pockets, mooring openings, shell
// doors, the big louvred vent, bow-thruster marks, and the lettering (name,
// emblem, port of registry) sampled from one canvas atlas.
//
// Layout follows photos of MSC Virtuosa (Geiranger, Greenock, Liverpool and
// Tallinn, 2021-22). Nodes shared between colour, roughness and the bump are
// emitted once by the node builder.

const NAVY = '#14213d';

// --- lettering atlas -----------------------------------------------------------
const AW = 4096, AH = 2048;
const SLOT = {
  name: [0, 0, 4096, 420],
  logo: [0, 440, 2600, 720],
  emblem: [2640, 440, 640, 720],
  thruster: [3320, 440, 760, 380],
  stern: [0, 1180, 4096, 620],
};

function buildAtlas() {
  return canvasTexture(AW, AH, (g) => {
    g.clearRect(0, 0, AW, AH);
    g.fillStyle = NAVY;
    g.textBaseline = 'middle';
    const serif = `Georgia, 'Times New Roman', serif`;
    const fit = (text, font, maxW, size) => {
      let s = size;
      g.font = font(s);
      while (g.measureText(text).width > maxW && s > 8) { s -= 4; g.font = font(s); }
      return s;
    };
    {
      const [x, y, w, h] = SLOT.name;
      fit('MSC VIRTUOSA', (s) => `italic 700 ${s}px ${serif}`, w * 0.96, h * 0.86);
      g.textAlign = 'center';
      g.fillText('MSC VIRTUOSA', x + w / 2, y + h * 0.54);
    }
    {
      const [x, y, , h] = SLOT.logo;
      // Only coverage is used from the atlas, so the white parts of the
      // emblem must be holes, not white paint.
      drawCompass(g, x + h * 0.5, y + h / 2, h * 0.48, NAVY, null, true);
      g.fillStyle = NAVY;
      g.font = `700 ${h * 0.78}px ${serif}`;
      g.textAlign = 'left';
      g.fillText('MSC', x + h * 1.08, y + h * 0.56);
    }
    {
      const [x, y, w, h] = SLOT.emblem;
      g.fillStyle = NAVY;
      g.textAlign = 'center';
      g.font = `700 ${h * 0.42}px ${serif}`;
      g.fillText('m', x + w * 0.42, y + h * 0.3);
      g.fillText('sc', x + w * 0.5, y + h * 0.7);
    }
    {
      const [x, y, w, h] = SLOT.thruster;
      g.strokeStyle = '#151820'; g.lineWidth = h * 0.06;
      for (const cx of [x + w * 0.25, x + w * 0.75]) {
        const cy = y + h / 2, r = h * 0.38;
        g.beginPath(); g.arc(cx, cy, r, 0, Math.PI * 2); g.stroke();
        g.beginPath();
        g.moveTo(cx - r * 0.7, cy - r * 0.7); g.lineTo(cx + r * 0.7, cy + r * 0.7);
        g.moveTo(cx + r * 0.7, cy - r * 0.7); g.lineTo(cx - r * 0.7, cy + r * 0.7);
        g.stroke();
      }
    }
    {
      const [x, y, w, h] = SLOT.stern;
      g.fillStyle = NAVY;
      g.textAlign = 'center';
      fit('MSC VIRTUOSA', (s) => `italic 700 ${s}px ${serif}`, w * 0.96, h * 0.62);
      g.fillText('MSC VIRTUOSA', x + w / 2, y + h * 0.36);
      g.font = `italic 600 ${h * 0.2}px ${serif}`;
      g.fillText('VALLETTA', x + w / 2, y + h * 0.82);
    }
  });
}

// --- helpers -----------------------------------------------------------------
const hash21 = (p) => fract(sin(dot(p, vec2(127.1, 311.7))).mul(43758.5453));
const BIG = 1e3;

/** Signed distance to a rounded box (half size b, corner radius r). */
const sdRoundBox = (q, b, r) => {
  const d = abs(q).sub(b).add(r);
  return length(max(d, 0.0)).add(min(max(d.x, d.y), 0.0)).sub(r);
};

/** Distance (in units of v) to the nearest line of a grid with spacing s. */
const gridDist = (v, s) => float(0.5).sub(abs(fract(v.div(s)).sub(0.5))).mul(s);

/**
 * Lettering: sample the atlas slot over the rectangle u0..u1 (along) and
 * y0..y1 (up) of a surface coordinate (u, y). Returns coverage 0..1.
 */
function letters(atlas, slot, u, y, u0, u1, y0, y1) {
  const [sx, sy, sw, sh] = SLOT[slot];
  const fu = u.sub(u0).div(u1 - u0);
  const fv = y.sub(y0).div(y1 - y0);
  const inside = step(0.0, fu).mul(step(fu, 1.0)).mul(step(0.0, fv)).mul(step(fv, 1.0));
  const tu = clamp(fu, 0.0, 1.0).mul(sw / AW).add(sx / AW);
  // Canvas rows run downward; canvas textures are uploaded flipped.
  const tv = float(1.0).sub(clamp(float(1.0).sub(fv), 0.0, 1.0).mul(sh / AH).add(sy / AH));
  return texture(atlas, vec2(tu, tv)).a.mul(inside);
}

// Window rows on the topsides:
// [y centre, width, height, pitch, group length, max per group, x0, x1].
const ROWS = [
  [17.4, 1.7, 0.95, 2.15, 11.0, 4, -126, 112],
  [12.4, 1.45, 0.8, 1.95, 9.8, 4, -146, 126],
  [9.4, 0.9, 0.9, 1.7, 12.0, 4, -140, 122],
  [6.4, 0.62, 0.62, 2.6, 15.0, 3, -120, 110],
];

/** Areas kept free of windows: [x0, x1, yMax] (logo, vent, shell doors). */
const KEEP_CLEAR = [
  [-124, -97, 17.0],
  [-60, -45, 21.0],
  [-27.5, -21.5, 8.2],
  [65.5, 71.5, 8.2],
];

export function hullPaintMaterial() {
  const atlas = buildAtlas();
  const m = new THREE.MeshStandardNodeMaterial();

  const p = shipPos();
  const x = p.x, y = p.y, z = p.z;
  const side = sign(z);
  const transom = step(x, STERN_X + 0.25);
  const notTransom = float(1.0).sub(transom);
  const viewDist = length(positionView);
  const lineFade = smoothstep(260.0, 60.0, viewDist);

  // --- windows (signed distance, < 0 inside) --------------------------------
  let dWin = float(BIG);
  for (const [yr, w, h, pitch, glen, nmax, x0, x1] of ROWS) {
    const g = floor(x.div(glen));
    const count = floor(hash21(vec2(g, yr)).mul(nmax + 1.0));
    const lead = floor(hash21(vec2(g.add(17.0), yr)).mul(2.0));
    const xg = x.sub(g.mul(glen));
    const k = floor(xg.div(pitch));
    const on = step(lead, k).mul(step(k, lead.add(count).sub(1.0)))
      .mul(step(x0, x)).mul(step(x, x1)).mul(step(xg, glen - pitch * 0.6));
    const lx = fract(xg.div(pitch)).sub(0.5).mul(pitch);
    const d = sdRoundBox(vec2(lx, y.sub(yr)), vec2(w / 2, h / 2), Math.min(w, h) * 0.5);
    dWin = min(dWin, select(on.greaterThan(0.5), d, float(BIG)));
  }
  let clearMask = notTransom;
  for (const [a, b, ym] of KEEP_CLEAR) clearMask = clearMask.mul(float(1.0).sub(step(a, x).mul(step(x, b)).mul(step(y, ym))));
  dWin = select(clearMask.greaterThan(0.5), dWin, float(BIG));

  // --- mooring openings: transom row, bow, stern quarters ---------------------
  const tCell = fract(z.div(3.4)).sub(0.5).mul(3.4);
  const tOpen = sdRoundBox(vec2(tCell, y.sub(14.8)), vec2(1.05, 0.55), 0.35);
  const tOn = transom.mul(step(abs(z), 15.5)).mul(step(1.2, abs(z)));
  const bCell = fract(x.div(2.9)).sub(0.5).mul(2.9);
  const bOpen = sdRoundBox(vec2(bCell, y.sub(19.0)), vec2(0.85, 0.5), 0.3);
  const bOn = step(138.0, x).mul(step(x, 153.5));
  const sOpen = sdRoundBox(vec2(bCell, y.sub(15.2)), vec2(0.85, 0.5), 0.3);
  const sOn = step(-162.0, x).mul(step(x, -150.5)).mul(notTransom);
  const dMoor = min(min(
    select(tOn.greaterThan(0.5), tOpen, float(BIG)),
    select(bOn.greaterThan(0.5), bOpen, float(BIG))),
    select(sOn.greaterThan(0.5), sOpen, float(BIG)));

  // Dark glazing band (decks 5-6) round the stern and along the aft quarters.
  const glazeZone = max(transom.mul(step(abs(z), 17.2)), step(x, -131.0).mul(notTransom));
  const glazeBand = smoothstep(16.68, 16.72, y).mul(smoothstep(19.32, 19.28, y)).mul(glazeZone);
  const mull = smoothstep(0.07, 0.035, gridDist(select(transom.greaterThan(0.5), z, x), 1.7));

  // --- anchor pocket (parallelogram leaning forward at the foot) ------------
  const fy = clamp(y.sub(1.6).div(8.4), 0.0, 1.0);
  const ax0 = mix(float(133.0), float(127.8), fy), ax1 = mix(float(139.6), float(133.2), fy);
  const dAnchor = max(max(ax0.sub(x), x.sub(ax1)), max(float(1.6).sub(y), y.sub(10.0)));
  const ac = mix(ax0, ax1, 0.5);
  const shank = max(abs(x.sub(ac)).sub(0.3), max(float(3.4).sub(y), y.sub(8.6)));
  const crown = max(abs(length(vec2(x.sub(ac), y.sub(5.2).mul(1.25))).sub(1.5)).sub(0.26), y.sub(5.2));
  const anchorShape = min(shank, crown);

  // --- shell doors: seam outlines ---------------------------------------------
  let doorSeam = float(0.0);
  for (const xc of [-24.5, 68.5]) {
    const d = sdRoundBox(vec2(x.sub(xc), y.sub(5.6)), vec2(2.3, 1.9), 0.12);
    doorSeam = max(doorSeam, smoothstep(0.035, 0.0, abs(d)));
  }
  doorSeam = doorSeam.mul(notTransom);

  // --- louvred vent below the recess -------------------------------------------
  const ventBox = sdRoundBox(vec2(x.sub(-52.5), y.sub(16.6)), vec2(5.6, 3.9), 0.1);
  const louvre = smoothstep(0.35, 0.5, abs(fract(x.div(0.32)).sub(0.5)).mul(2.0));

  // --- plating ----------------------------------------------------------------
  const seamY = smoothstep(0.014, 0.0, gridDist(y, 2.45));
  const seamX = smoothstep(0.014, 0.0, gridDist(select(transom.greaterThan(0.5), z, x).add(3.2), 10.4));
  const seams = max(seamX, seamY).mul(lineFade).mul(step(1.0, y));
  // Shallow dishing of each plate between frames (0.8 m): catches low sun.
  const dish = sin(fract(x.div(0.8)).mul(Math.PI)).mul(sin(fract(y.div(2.45)).mul(Math.PI))).mul(-0.004).mul(notTransom);

  // --- lettering ----------------------------------------------------------------
  const u = select(side.greaterThan(0.0), x, x.negate());
  const stbd = letters(atlas, 'name', u, y, 121.0, 139.0, 21.75, 23.45)
    .add(letters(atlas, 'logo', u, y, -122.0, -99.5, 10.4, 16.6))
    .add(letters(atlas, 'emblem', u, y, 151.0, 154.6, 21.9, 25.9))
    .add(letters(atlas, 'thruster', u, y, 145.0, 149.0, 1.2, 3.2));
  const port = letters(atlas, 'name', u, y, -139.0, -121.0, 21.75, 23.45)
    .add(letters(atlas, 'logo', u, y, 99.5, 122.0, 10.4, 16.6))
    .add(letters(atlas, 'emblem', u, y, -154.6, -151.0, 21.9, 25.9))
    .add(letters(atlas, 'thruster', u, y, -149.0, -145.0, 1.2, 3.2));
  const sternInk = letters(atlas, 'stern', z, y, -14.6, 14.6, 8.2, 12.6);
  const ink = saturate(select(transom.greaterThan(0.5), sternInk, select(side.greaterThan(0.0), stbd, port)));

  // --- masks -------------------------------------------------------------------
  const winIn = smoothstep(0.015, -0.015, dWin);
  const frame = smoothstep(0.07, 0.0, abs(dWin.add(0.045))).mul(float(1.0).sub(winIn));
  const moorIn = smoothstep(0.015, -0.015, dMoor);
  const anchorIn = smoothstep(0.03, -0.03, dAnchor);
  const anchorMetal = anchorIn.mul(smoothstep(0.03, -0.03, anchorShape));
  const ventIn = smoothstep(0.02, -0.02, ventBox).mul(notTransom);
  const glassy = max(winIn, glazeBand.mul(float(1.0).sub(mull)));

  m.colorNode = Fn(() => {
    const red = vec3(0.30, 0.045, 0.035);
    const boot = vec3(0.016, 0.022, 0.04);
    const broad = mx_noise_float(p.mul(0.025)).mul(0.025);
    const white = vec3(0.86, 0.87, 0.87).mul(float(1.0).add(broad));
    const grime = smoothstep(4.5, 0.9, y).mul(0.06);
    let c = mix(red, boot, step(-0.55, y));
    c = mix(c, white.mul(float(1.0).sub(grime)), step(0.95, y));
    c = c.mul(float(1.0).sub(seams.mul(0.07)));
    c = mix(c, vec3(0.62, 0.64, 0.66), frame.mul(0.55));
    c = mix(c, vec3(0.012, 0.018, 0.026), winIn);
    c = mix(c, vec3(0.03, 0.032, 0.035), moorIn);
    c = mix(c, vec3(0.022, 0.024, 0.027), anchorIn);
    c = mix(c, vec3(0.3, 0.31, 0.32), anchorMetal);
    c = mix(c, mix(vec3(0.05, 0.055, 0.06), vec3(0.16, 0.17, 0.18), louvre), ventIn);
    c = mix(c, mix(vec3(0.014, 0.02, 0.03), vec3(0.62, 0.64, 0.66), mull), glazeBand);
    c = c.mul(float(1.0).sub(doorSeam.mul(0.55)));
    c = mix(c, vec3(0.014, 0.024, 0.06), ink);
    return c;
  })();

  m.roughnessNode = Fn(() => {
    let r = mix(float(0.55), float(0.32), step(0.95, y));
    r = mix(r, float(0.04), glassy);
    r = mix(r, float(0.8), max(moorIn, anchorIn.sub(anchorMetal)));
    return mix(r, float(0.12), shipU.wet.mul(0.5));
  })();

  // Bump from the height field (Mikkelsen's surface gradient, unnormalised so
  // heights are in metres and the effect is right at any distance).
  m.normalNode = Fn(() => {
    const h = dish
      .sub(winIn.mul(0.09))
      .add(frame.mul(0.012))
      .sub(moorIn.mul(0.35))
      .sub(anchorIn.mul(0.6))
      .add(anchorMetal.mul(0.3))
      .sub(ventIn.mul(0.08))
      .sub(doorSeam.mul(0.008))
      .add(seams.mul(0.002));
    const dpdx = positionView.dFdx(), dpdy = positionView.dFdy();
    const n = normalView;
    const r1 = dpdy.cross(n), r2 = n.cross(dpdx);
    const det = dpdx.dot(r1).mul(faceDirection);
    const grad = det.sign().mul(h.dFdx().mul(r1).add(h.dFdy().mul(r2)));
    return det.abs().mul(n).sub(grad).normalize();
  })();

  // Crew cabins behind the windows, a few lit at night; the stern restaurant band.
  m.emissiveNode = Fn(() => {
    const cell = floor(vec2(x.div(1.62), y.div(2.9)));
    const lit = step(0.7, hash21(cell.add(vec2(side.mul(31.0), 0.0))));
    const night = shipU.night.mul(shipU.lightBoost);
    return vec3(1.0, 0.8, 0.56).mul(lit).mul(winIn).mul(0.05)
      .add(vec3(1.0, 0.76, 0.5).mul(glazeBand).mul(float(1.0).sub(mull)).mul(0.03))
      .mul(night);
  })();
  return m;
}
