// Persistent user settings. Everything the settings screen can change lives
// here; systems read `settings.get()` every frame or subscribe to changes.
//
// Storage can be missing or throw (private windows, blocked site data, the
// WebView's file:// origin), so every access is guarded and the scene runs
// fine on defaults.

const KEY = 'luma.cruiseShip.opus55ultracode.v1';

export const QUALITY = {
  low:    { renderScale: 0.75, shadows: 'low',    clouds: 'low',    ao: false, ssr: false, bloom: true, taa: true },
  medium: { renderScale: 0.85, shadows: 'medium', clouds: 'medium', ao: true,  ssr: false, bloom: true, taa: true },
  high:   { renderScale: 1.0,  shadows: 'high',   clouds: 'high',   ao: true,  ssr: false, bloom: true, taa: true },
  ultra:  { renderScale: 1.0,  shadows: 'ultra',  clouds: 'ultra',  ao: true,  ssr: true,  bloom: true, taa: true },
};

export const DEFAULTS = {
  time: {
    dayMinutes: 24,      // real minutes per in-game day
    realTime: false,     // follow the PC clock instead
    paused: false,
    speed: 1,            // multiplier on top of dayMinutes
    hour: 16.25,         // start of the visit (late afternoon light)
  },
  weather: {
    mode: 'auto',        // 'auto' | 'locked'
    preset: 'fair',      // used when locked, and the auto starting point
    transitionMinutes: 2,
  },
  sea: {
    knots: 18,
    seaState: 'auto',    // 'auto' | 0..9 (Beaufort)
    location: 'sea',     // 'sea' | 'port'
  },
  graphics: {
    preset: 'high',
    renderScale: 1.0,
    shadows: 'high',     // 'off' | 'low' | 'medium' | 'high' | 'ultra'
    clouds: 'high',      // 'low' | 'medium' | 'high' | 'ultra'
    ao: true,
    ssr: false,
    bloom: true,
    taa: true,
    fov: 72,
    showFps: false,
  },
  controls: {
    sensitivity: 1.0,
    invertY: false,
    headBob: true,
    rollCamera: true,    // let the ship's roll tilt the view
  },
  audio: {
    master: 0.8,
    ambient: 0.85,
    effects: 0.8,
    muted: false,
  },
};

function clone(o) { return JSON.parse(JSON.stringify(o)); }

function merge(base, over) {
  if (!over || typeof over !== 'object') return base;
  for (const k of Object.keys(base)) {
    if (!(k in over)) continue;
    const b = base[k], v = over[k];
    if (b && typeof b === 'object' && !Array.isArray(b)) merge(b, v);
    else if (typeof v === typeof b) base[k] = v;
  }
  return base;
}

class Settings {
  constructor() {
    this.state = clone(DEFAULTS);
    this.listeners = new Set();
    try {
      const raw = window.localStorage.getItem(KEY);
      if (raw) merge(this.state, JSON.parse(raw));
    } catch { /* storage unavailable: defaults it is */ }
  }

  get() { return this.state; }

  /** Set a dotted path, e.g. set('graphics.fov', 80). */
  set(path, value) {
    const parts = path.split('.');
    let o = this.state;
    for (let i = 0; i < parts.length - 1; i++) o = o[parts[i]];
    const key = parts[parts.length - 1];
    if (o[key] === value) return;
    o[key] = value;
    if (path === 'graphics.preset' && QUALITY[value]) Object.assign(this.state.graphics, QUALITY[value]);
    this.save();
    for (const fn of this.listeners) fn(path, value);
  }

  reset() {
    this.state = clone(DEFAULTS);
    this.save();
    for (const fn of this.listeners) fn('*', null);
  }

  save() {
    try { window.localStorage.setItem(KEY, JSON.stringify(this.state)); } catch { /* ignore */ }
  }

  onChange(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); }
}

export const settings = new Settings();
