import * as THREE from 'three/webgpu';
import { settings } from './settings.js';

// Time of day and the sky's moving parts: sun, moon (with phase) and the
// rotation of the star field. All directions are in the ship frame:
// +x bow, +y up, +z starboard.
//
// The cruise is in the western Mediterranean in early July (latitude of the
// Alboran Sea, where the reference photos were taken), so summer sun: high
// at noon, sunset late and to the north-west.

const DEG = Math.PI / 180;
const LAT = 36.4 * DEG;
const HEADING = 214 * DEG;          // compass course; puts the sunset on the starboard beam
const SYNODIC = 29.530588;
const START_DAY = 186;              // ~5 July
const START_MOON_AGE = 10.5;        // waxing gibbous: a bright moon early in the night

const _v = new THREE.Vector3();

/** ENU (east, up, north) to ship frame. */
function enuToShip(e, u, n, out) {
  const s = Math.sin(HEADING), c = Math.cos(HEADING);
  return out.set(e * s + n * c, u, e * c - n * s);
}

function bodyDir(hourAngle, decl, out) {
  const sd = Math.sin(decl), cd = Math.cos(decl);
  const sl = Math.sin(LAT), cl = Math.cos(LAT);
  const ch = Math.cos(hourAngle), sh = Math.sin(hourAngle);
  const up = sl * sd + cl * cd * ch;
  const east = -cd * sh;
  const north = sd * cl - cd * sl * ch;
  return enuToShip(east, up, north, out).normalize();
}

export class Clock {
  constructor() {
    const s = settings.get().time;
    this.hour = s.hour;
    this.day = 0;                 // whole days since the visit started
    this.sunDir = new THREE.Vector3();
    this.moonDir = new THREE.Vector3();
    this.moonPhase = 0.5;         // 0 new, 0.5 full
    this.moonIllum = 1;
    this.starMatrix = new THREE.Matrix3();
    this.poleDir = new THREE.Vector3();
    this.heading = HEADING;
    enuToShip(0, Math.sin(LAT), Math.cos(LAT), this.poleDir).normalize();
    this.update(0);
  }

  /** Game hours that pass per real second at the current settings. */
  rate() {
    const t = settings.get().time;
    return (24 / (Math.max(1, t.dayMinutes) * 60)) * t.speed;
  }

  setHour(h) {
    this.hour = ((h % 24) + 24) % 24;
    settings.get().time.hour = this.hour;
  }

  update(dt) {
    const t = settings.get().time;
    let dayOfYear, moonAge;
    if (t.realTime) {
      const now = new Date();
      this.hour = now.getHours() + now.getMinutes() / 60 + now.getSeconds() / 3600;
      const start = new Date(now.getFullYear(), 0, 0);
      dayOfYear = (now - start) / 86400000;
      // Days since a known new moon (2000-01-06 18:14 UTC).
      moonAge = ((now.getTime() / 86400000 - 10962.76) % SYNODIC + SYNODIC) % SYNODIC;
    } else {
      if (!t.paused && dt > 0) {
        this.hour += dt * this.rate();
        while (this.hour >= 24) { this.hour -= 24; this.day++; }
        while (this.hour < 0) { this.hour += 24; this.day--; }
      }
      dayOfYear = START_DAY + this.day;
      moonAge = (((START_MOON_AGE + this.day + this.hour / 24) % SYNODIC) + SYNODIC) % SYNODIC;
    }

    const decl = 23.44 * DEG * Math.sin((2 * Math.PI * (284 + dayOfYear)) / 365);
    const ha = (this.hour - 12) * 15 * DEG;
    bodyDir(ha, decl, this.sunDir);

    // The moon trails the sun by its elongation; its declination swings
    // opposite the sun's as it fills (a low full moon in summer).
    const elong = (moonAge / SYNODIC) * 2 * Math.PI;
    bodyDir(ha - elong, decl * Math.cos(elong), this.moonDir);
    this.moonPhase = moonAge / SYNODIC;
    this.moonIllum = 0.5 * (1 - Math.cos(elong));

    // Star field: rotate about the celestial pole with sidereal time.
    const sidereal = ((this.hour / 24) + dayOfYear / 365.25) * 2 * Math.PI;
    const m4 = new THREE.Matrix4().makeRotationAxis(this.poleDir, -sidereal);
    this.starMatrix.setFromMatrix4(m4);
  }

  get sunElevation() { return Math.asin(THREE.MathUtils.clamp(this.sunDir.y, -1, 1)); }

  /** "16:42" */
  label() {
    const h = Math.floor(this.hour), m = Math.floor((this.hour - h) * 60);
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
  }
}

export { DEG, HEADING, _v };
