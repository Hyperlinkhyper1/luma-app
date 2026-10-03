// The minimal on-screen layer: where you are, time and weather, the mode,
// interaction prompts, toasts and an optional frame-time readout.

const $ = (id) => document.getElementById(id);

export class Hud {
  constructor() {
    this.el = {
      deck: $('hudDeck'), area: $('hudArea'), time: $('hudTime'), weather: $('hudWeather'),
      sea: $('hudSea'), mode: $('hudMode'), prompt: $('prompt'), toast: $('toast'), fps: $('fps'),
    };
    this._cache = {};
    this._fps = { acc: 0, n: 0, shown: 0 };
    this._toastT = 0;
  }

  _set(key, text) {
    if (this._cache[key] === text) return;
    this._cache[key] = text;
    this.el[key].textContent = text;
  }

  setMode(label) { this._set('mode', label); }

  prompt(text) {
    if (!text) { this.el.prompt.hidden = true; this._cache.prompt = null; return; }
    if (this._cache.prompt !== text) { this.el.prompt.innerHTML = text; this._cache.prompt = text; }
    this.el.prompt.hidden = false;
  }

  toast(text, seconds = 2.5) {
    this.el.toast.textContent = text;
    this.el.toast.hidden = false;
    this._toastT = seconds;
  }

  update({ time, weather, sea, place, mode, dt }) {
    this._set('time', time);
    this._set('weather', weather);
    this._set('sea', sea);
    if (mode === 'walk' && place) {
      this._set('deck', `DECK ${place.deck}`);
      this._set('area', place.area);
    } else if (mode === 'tender') {
      this._set('deck', 'SEA LEVEL');
      this._set('area', 'TENDER · ALONGSIDE');
    } else if (mode === 'drone') {
      this._set('deck', 'DRONE');
      this._set('area', 'FREE FLIGHT · WHEEL = SPEED');
    }
    if (this._toastT > 0) {
      this._toastT -= dt;
      if (this._toastT <= 0) this.el.toast.hidden = true;
    }
    const f = this._fps;
    f.acc += dt; f.n++;
    if (f.acc > 0.5) {
      if (!this.el.fps.hidden) this.el.fps.textContent = `${(f.n / f.acc).toFixed(0)} fps\n${((f.acc / f.n) * 1000).toFixed(1)} ms`;
      f.acc = 0; f.n = 0;
    }
  }
}
