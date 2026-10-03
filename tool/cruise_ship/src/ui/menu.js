import { settings, QUALITY } from '../core/settings.js';
import { PRESETS, PRESET_ORDER } from '../env/weather.js';

// The settings screen (Esc). Built from a small declarative description;
// every control writes straight to settings, which the systems read live.

const $ = (id) => document.getElementById(id);

const hhmm = (h) => {
  const H = Math.floor(h) % 24, M = Math.floor((h - Math.floor(h)) * 60);
  return `${String(H).padStart(2, '0')}:${String(M).padStart(2, '0')}`;
};

export class Menu {
  constructor(app) {
    this.app = app;
    this.el = $('settings');
    this.body = $('setBody');
    this.tab = 'time';
    this.open = false;
    $('setTabs').addEventListener('click', (e) => {
      const b = e.target.closest('button[data-tab]');
      if (!b) return;
      this.tab = b.dataset.tab;
      for (const x of $('setTabs').querySelectorAll('button')) x.classList.toggle('on', x === b);
      this.render();
    });
    $('setResume').onclick = () => this.hide();
    $('setReset').onclick = () => { settings.reset(); this.app.weather.setNow(settings.get().weather.preset); this.render(); };
    this.el.querySelector('[data-close]').onclick = () => this.hide();
    this.el.addEventListener('pointerdown', (e) => { if (e.target === this.el) this.hide(); });
    this._live = null;
  }

  show() {
    this.open = true;
    this.el.hidden = false;
    this.app.input.enabled = false;
    this.app.input.unlock();
    this.render();
  }

  hide() {
    this.open = false;
    this.el.hidden = true;
    this.app.resume();
  }

  toggle() { this.open ? this.hide() : this.show(); }

  /** Called every frame while open, to keep live readouts current. */
  tick() { if (this.open && this._live) this._live(); }

  // --- control builders --------------------------------------------------------
  row(label, desc, ctl) {
    const r = document.createElement('div');
    r.className = 'row';
    const l = document.createElement('label');
    l.textContent = label;
    if (desc) { const d = document.createElement('span'); d.className = 'desc'; d.textContent = desc; l.appendChild(d); }
    r.append(l, ctl);
    this.body.appendChild(r);
    return r;
  }

  slider(path, min, max, step, fmt = (v) => v, onInput = null) {
    const wrap = document.createElement('div'); wrap.className = 'ctl';
    const i = document.createElement('input');
    i.type = 'range'; i.min = min; i.max = max; i.step = step;
    const get = () => path.split('.').reduce((o, k) => o[k], settings.get());
    i.value = get();
    const o = document.createElement('output'); o.textContent = fmt(+i.value);
    i.addEventListener('input', () => {
      const v = +i.value;
      o.textContent = fmt(v);
      if (onInput) onInput(v); else settings.set(path, v);
    });
    wrap.append(i, o);
    wrap._input = i; wrap._out = o;
    return wrap;
  }

  seg(path, options, onPick = null) {
    const wrap = document.createElement('div'); wrap.className = 'seg';
    const get = () => path ? path.split('.').reduce((o, k) => o[k], settings.get()) : null;
    const sync = () => { for (const b of wrap.children) b.classList.toggle('on', String(b.dataset.v) === String(get())); };
    for (const [v, label] of options) {
      const b = document.createElement('button');
      b.dataset.v = v; b.textContent = label;
      b.onclick = () => { if (onPick) onPick(v); else settings.set(path, v); sync(); };
      wrap.appendChild(b);
    }
    sync();
    wrap._sync = sync;
    return wrap;
  }

  toggleSw(path, onFlip = null) {
    const b = document.createElement('button');
    b.className = 'switch';
    const get = () => path.split('.').reduce((o, k) => o[k], settings.get());
    const sync = () => b.classList.toggle('on', !!get());
    b.onclick = () => { if (onFlip) onFlip(!get()); else settings.set(path, !get()); sync(); };
    sync();
    const wrap = document.createElement('div'); wrap.className = 'ctl'; wrap.appendChild(b);
    return wrap;
  }

  // --- tabs --------------------------------------------------------------------
  render() {
    this.body.innerHTML = '';
    this._live = null;
    const s = settings.get();
    const app = this.app;
    if (this.tab === 'time') {
      const tod = this.slider('time.hour', 0, 23.99, 0.01, hhmm, (v) => { app.clock.setHour(v); });
      tod._input.value = app.clock.hour;
      tod._out.textContent = hhmm(app.clock.hour);
      const todRow = this.row('Time of day', 'Drag to any hour; the sky, sun and moon follow.', tod);
      this._live = () => {
        if (document.activeElement !== tod._input) { tod._input.value = app.clock.hour; tod._out.textContent = hhmm(app.clock.hour); }
        tod._input.disabled = s.time.realTime;
        todRow.style.opacity = s.time.realTime ? 0.5 : 1;
      };
      this.row('Day length', 'Real minutes for one full day and night at normal speed. Default 24 minutes.',
        this.slider('time.dayMinutes', 2, 180, 1, (v) => `${v} min`));
      this.row('Real time', 'Follow your PC clock (and today\'s moon) instead of the game day.', this.toggleSw('time.realTime'));
      this.row('Pause time', 'Freeze the sky where it is.', this.toggleSw('time.paused'));
      this.row('Speed', 'Multiplies the day length while it runs.', this.seg('time.speed', [[0.5, '½×'], [1, '1×'], [2, '2×'], [6, '6×'], [24, '24×']]));
      this.row('Jump to', null, this.seg(null, [[6.1, 'Sunrise'], [10, 'Morning'], [14, 'Afternoon'], [19.6, 'Sunset'], [20.4, 'Blue hour'], [23.5, 'Night']], (v) => { settings.set('time.realTime', false); app.clock.setHour(v); this.render(); }));
    } else if (this.tab === 'weather') {
      const cur = document.createElement('div'); cur.className = 'ctl'; const o = document.createElement('output'); o.style.textAlign = 'left'; cur.appendChild(o);
      this.row('Now', null, cur);
      this._live = () => { o.textContent = app.weather.label(); };
      this.row('Mode', 'Auto lets the weather wander between neighbouring conditions; Locked holds one.',
        this.seg('weather.mode', [['auto', 'Auto'], ['locked', 'Locked']]));
      this.row('Weather', 'Picking one locks it.', this.seg('weather.preset', PRESET_ORDER.map((k) => [k, PRESETS[k].label.split(',')[0]]), (v) => {
        settings.set('weather.mode', 'locked');
        settings.set('weather.preset', v);
        this.render();
      }));
      this.row('Transition', 'How long a change of weather takes.', this.slider('weather.transitionMinutes', 0.25, 10, 0.25, (v) => `${v} min`));
      this.row('Apply instantly', null, this.seg(null, [['now', 'Snap to the selected weather']], () => app.weather.setNow(settings.get().weather.preset)));
    } else if (this.tab === 'sea') {
      this.row('Location', 'At sea under way, or moored alongside the quay in port.',
        this.seg('sea.location', [['sea', 'At sea'], ['port', 'In port']], (v) => app.setLocation(v)));
      this.row('Ship speed', 'Through the water. The wake, bow wave and wind follow it.', this.slider('sea.knots', 0, 22, 0.5, (v) => `${v} kn`));
      this.row('Sea state', 'Beaufort force. Auto follows the weather.',
        this.seg('sea.seaState', [['auto', 'Auto'], ...[0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => [n, String(n)])], (v) => settings.set('sea.seaState', v === 'auto' ? 'auto' : Number(v))));
    } else if (this.tab === 'graphics') {
      this.row('Quality', 'Sets everything below at once.', this.seg('graphics.preset', [['low', 'Low'], ['medium', 'Medium'], ['high', 'High'], ['ultra', 'Ultra']], (v) => { settings.set('graphics.preset', v); this.render(); }));
      this.row('Render scale', 'Below 100% renders fewer pixels for speed.', this.slider('graphics.renderScale', 0.5, 1.0, 0.05, (v) => `${Math.round(v * 100)}%`));
      this.row('Shadows', null, this.seg('graphics.shadows', [['off', 'Off'], ['low', 'Low'], ['medium', 'Medium'], ['high', 'High'], ['ultra', 'Ultra']]));
      this.row('Clouds', 'Steps through the volumetric cloud layer.', this.seg('graphics.clouds', [['low', 'Low'], ['medium', 'Medium'], ['high', 'High'], ['ultra', 'Ultra']]));
      this.row('Ambient occlusion', null, this.toggleSw('graphics.ao'));
      this.row('Bloom', null, this.toggleSw('graphics.bloom'));
      this.row('Temporal anti-aliasing', null, this.toggleSw('graphics.taa'));
      this.row('Field of view', null, this.slider('graphics.fov', 50, 100, 1, (v) => `${v}°`));
      this.row('Show FPS', null, this.toggleSw('graphics.showFps'));
    } else if (this.tab === 'controls') {
      this.row('Mouse sensitivity', null, this.slider('controls.sensitivity', 0.2, 3, 0.05, (v) => `${v.toFixed(2)}×`));
      this.row('Invert Y', null, this.toggleSw('controls.invertY'));
      this.row('Head bob', 'A little sway while walking.', this.toggleSw('controls.headBob'));
      this.row('Feel the roll', 'Let the ship\'s roll tilt your view. Turn off if it makes you queasy.', this.toggleSw('controls.rollCamera'));
      this.row('People on board', 'Passengers on the decks and in the pools.', this.toggleSw('people.enabled'));
      const keys = document.createElement('div');
      keys.className = 'ctl';
      keys.style.display = 'block';
      keys.style.color = 'var(--mute)';
      keys.style.fontSize = '12.5px';
      keys.innerHTML = 'WASD move · Shift run · Ctrl crouch · Space jump · E doors &amp; stairwells · V walk / tender / drone · M deck map · H horn · F1 hide HUD · Esc settings<br>Drone: mouse wheel sets speed, Space/E up, Q/Ctrl down · Tender: W/S throttle, A/D steer, R hold station';
      this.row('Keys', null, keys);
    } else if (this.tab === 'audio') {
      this.row('Master', null, this.slider('audio.master', 0, 1, 0.01, (v) => `${Math.round(v * 100)}%`));
      this.row('Ambience', 'Wind, sea, rain, the ship\'s hum.', this.slider('audio.ambient', 0, 1, 0.01, (v) => `${Math.round(v * 100)}%`));
      this.row('Effects', 'Footsteps, horn, thunder, gulls.', this.slider('audio.effects', 0, 1, 0.01, (v) => `${Math.round(v * 100)}%`));
      this.row('Mute', null, this.toggleSw('audio.muted'));
    }
  }
}
