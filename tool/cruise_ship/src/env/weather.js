import { settings } from '../core/settings.js';

// Weather as a blend of parameter sets. In auto mode the sky wanders between
// neighbouring presets (fair weather builds into cloud, cloud into rain, rain
// into a squall and back out); locking a preset in settings fades to it.

export const PRESETS = {
  clear:    { label: 'Clear',          cover: 0.06, base: 1.7, thick: 0.9, density: 0.8, type: 0.9, haze: 0.9, fog: 0.0,  rain: 0, wind: 5,  sea: 3,   lightning: 0, gloom: 0.0 },
  fair:     { label: 'Fair, scattered cloud', cover: 0.34, base: 1.35, thick: 1.6, density: 1.0, type: 1.0, haze: 1.1, fog: 0.0, rain: 0, wind: 8, sea: 4, lightning: 0, gloom: 0.0 },
  cloudy:   { label: 'Mostly cloudy',  cover: 0.62, base: 1.1, thick: 2.0, density: 1.15, type: 0.8, haze: 1.5, fog: 0.02, rain: 0, wind: 10, sea: 4.5, lightning: 0, gloom: 0.15 },
  overcast: { label: 'Overcast',       cover: 0.95, base: 0.85, thick: 1.3, density: 1.3, type: 0.15, haze: 2.4, fog: 0.06, rain: 0, wind: 9, sea: 4.2, lightning: 0, gloom: 0.35 },
  haze:     { label: 'Summer haze',    cover: 0.12, base: 1.6, thick: 0.8, density: 0.7, type: 0.6, haze: 5.5, fog: 0.12, rain: 0, wind: 3,  sea: 1.6, lightning: 0, gloom: 0.0 },
  fog:      { label: 'Fog bank',       cover: 0.85, base: 0.55, thick: 0.7, density: 1.1, type: 0.1, haze: 4.0, fog: 1.0,  rain: 0, wind: 3,  sea: 2,   lightning: 0, gloom: 0.25 },
  rain:     { label: 'Rain',           cover: 0.98, base: 0.65, thick: 2.6, density: 1.7, type: 0.45, haze: 3.2, fog: 0.22, rain: 0.7, wind: 14, sea: 6, lightning: 0, gloom: 0.55 },
  storm:    { label: 'Thunderstorm',   cover: 1.0, base: 0.55, thick: 7.0, density: 2.3, type: 0.7, haze: 3.6, fog: 0.3, rain: 1.0, wind: 21, sea: 8, lightning: 7, gloom: 0.8 },
};

export const PRESET_ORDER = ['clear', 'fair', 'cloudy', 'overcast', 'haze', 'fog', 'rain', 'storm'];

const NEXT = {
  clear:    [['fair', 3], ['haze', 2], ['clear', 1]],
  fair:     [['clear', 2], ['cloudy', 3], ['haze', 1]],
  cloudy:   [['fair', 2], ['overcast', 2], ['rain', 2]],
  overcast: [['cloudy', 2], ['rain', 2], ['fog', 1]],
  haze:     [['clear', 2], ['fair', 2], ['fog', 1]],
  fog:      [['overcast', 2], ['haze', 2], ['cloudy', 1]],
  rain:     [['overcast', 2], ['storm', 2], ['cloudy', 1]],
  storm:    [['rain', 3]],
};

// Significant wave height (m) and wind (m/s) by Beaufort number.
export const BEAUFORT_HS = [0.0, 0.1, 0.25, 0.6, 1.0, 2.0, 3.0, 4.0, 5.5, 7.0, 9.0];

const KEYS = ['cover', 'base', 'thick', 'density', 'type', 'haze', 'fog', 'rain', 'wind', 'sea', 'lightning', 'gloom'];

function pick(list, rnd) {
  const total = list.reduce((a, [, w]) => a + w, 0);
  let r = rnd() * total;
  for (const [k, w] of list) { if ((r -= w) <= 0) return k; }
  return list[0][0];
}

export class Weather {
  constructor() {
    const s = settings.get().weather;
    this.from = PRESETS[s.preset] ? s.preset : 'fair';
    this.to = this.from;
    this.progress = 1;
    this.hold = 240 + Math.random() * 180;        // seconds before the next change
    this.windDir = 0.6;                           // earth-frame radians, drifts slowly
    this.wetness = 0;
    this.current = { ...PRESETS[this.from] };
    this.lockedTarget = null;
    settings.onChange((path) => {
      if (path.startsWith('weather')) this._applyLock();
    });
    this._applyLock();
  }

  _applyLock() {
    const s = settings.get().weather;
    if (s.mode === 'locked' && PRESETS[s.preset]) {
      if (this.to !== s.preset) this._goTo(s.preset);
    }
  }

  _goTo(name) {
    this.from = this._snapshotName();
    this._fromValues = { ...this.current };
    this.to = name;
    this.progress = 0;
  }

  _snapshotName() { return this.progress >= 1 ? this.to : this.from; }

  /** Jump straight to a preset (used when the settings screen locks one). */
  setNow(name) {
    this.from = this.to = name;
    this.progress = 1;
    Object.assign(this.current, PRESETS[name]);
  }

  update(dt) {
    const s = settings.get().weather;
    const dur = Math.max(10, s.transitionMinutes * 60);
    if (this.progress < 1) {
      this.progress = Math.min(1, this.progress + dt / dur);
      const t = this.progress * this.progress * (3 - 2 * this.progress);
      const a = this._fromValues || PRESETS[this.from];
      const b = PRESETS[this.to];
      for (const k of KEYS) this.current[k] = a[k] + (b[k] - a[k]) * t;
      if (this.progress >= 1) this.from = this.to;
    } else if (s.mode === 'auto') {
      this.hold -= dt;
      if (this.hold <= 0) {
        this._goTo(pick(NEXT[this.to], Math.random));
        this.hold = 260 + Math.random() * 300;
      }
    }
    this.windDir += dt * 0.0006 * Math.sin(performance.now() * 0.00002);
    // Decks get wet fast in rain and dry over a few minutes after it.
    const c = this.current;
    if (c.rain > 0.05) this.wetness = Math.min(1, this.wetness + dt * c.rain * 0.08);
    else this.wetness = Math.max(0, this.wetness - dt * 0.004);
  }

  /** Beaufort number in effect (override from settings, else the weather's). */
  beaufort() {
    const o = settings.get().sea.seaState;
    return o === 'auto' ? this.current.sea : Number(o);
  }

  label() {
    if (this.progress < 1 && this.from !== this.to) {
      return `${PRESETS[this.from].label} → ${PRESETS[this.to].label}`;
    }
    return PRESETS[this.to].label;
  }
}
