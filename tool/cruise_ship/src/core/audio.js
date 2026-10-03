import { settings } from './settings.js';

// Procedural ambience, all synthesized with Web Audio (no sound files):
// wind that grows with height and at the railings, the sea washing along
// the hull, the ship's hum and ventilation, rain (a patter under cover, a
// hiss in the open), thunder delayed by distance, the ship's horn with a
// fog signal, pool-deck murmur, gulls, and footsteps.

function noiseBuffer(ctx, seconds, color) {
  const n = Math.floor(ctx.sampleRate * seconds);
  const buf = ctx.createBuffer(1, n, ctx.sampleRate);
  const d = buf.getChannelData(0);
  let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0, last = 0;
  for (let i = 0; i < n; i++) {
    const w = Math.random() * 2 - 1;
    if (color === 'pink') {
      b0 = 0.99886 * b0 + w * 0.0555179; b1 = 0.99332 * b1 + w * 0.0750759; b2 = 0.969 * b2 + w * 0.153852;
      b3 = 0.8665 * b3 + w * 0.3104856; b4 = 0.55 * b4 + w * 0.5329522; b5 = -0.7616 * b5 - w * 0.016898;
      d[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11; b6 = w * 0.115926;
    } else if (color === 'brown') {
      last = (last + 0.02 * w) / 1.02; d[i] = last * 3.5;
    } else d[i] = w;
  }
  // Crossfade the loop seam.
  const f = Math.min(2048, n >> 3);
  for (let i = 0; i < f; i++) { const t = i / f; d[n - f + i] = d[n - f + i] * (1 - t) + d[i] * t; }
  return buf;
}

function impulse(ctx, seconds, decay) {
  const n = Math.floor(ctx.sampleRate * seconds);
  const buf = ctx.createBuffer(2, n, ctx.sampleRate);
  for (let c = 0; c < 2; c++) {
    const d = buf.getChannelData(c);
    for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / n, decay);
  }
  return buf;
}

const clamp01 = (v) => Math.max(0, Math.min(1, v));

export class Audio {
  constructor() {
    this.ctx = null;
    this.started = false;
    this.fogHornT = 30;
    this.gullT = 6;
    this.murmurPhase = 0;
  }

  /** Must be called from a user gesture. */
  start() {
    if (this.started) { this.ctx?.resume(); return; }
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return;
    const ctx = this.ctx = new Ctx();
    this.started = true;
    const master = this.master = ctx.createGain();
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -14; comp.ratio.value = 3;
    master.connect(comp).connect(ctx.destination);
    this.amb = ctx.createGain(); this.amb.connect(master);
    this.fx = ctx.createGain(); this.fx.connect(master);
    this.reverb = ctx.createConvolver();
    this.reverb.buffer = impulse(ctx, 3.5, 2.6);
    const rvGain = ctx.createGain(); rvGain.gain.value = 0.35;
    this.reverb.connect(rvGain).connect(this.fx);

    this.white = noiseBuffer(ctx, 3, 'white');
    this.pink = noiseBuffer(ctx, 4, 'pink');
    this.brown = noiseBuffer(ctx, 5, 'brown');

    const loop = (buf, rate = 1) => {
      const s = ctx.createBufferSource(); s.buffer = buf; s.loop = true; s.playbackRate.value = rate;
      s.start(0, Math.random() * buf.duration);
      return s;
    };
    const filt = (type, f, q = 0.7) => { const b = ctx.createBiquadFilter(); b.type = type; b.frequency.value = f; b.Q.value = q; return b; };
    const gain = (v = 0) => { const g = ctx.createGain(); g.gain.value = v; return g; };

    // Wind: a low body plus a whistle that gusts.
    this.windLow = gain(); loop(this.brown, 0.9).connect(filt('lowpass', 380)).connect(this.windLow).connect(this.amb);
    this.windBand = filt('bandpass', 700, 1.3);
    this.windHigh = gain(); loop(this.pink, 1.0).connect(this.windBand).connect(this.windHigh).connect(this.amb);
    this.whistleF = filt('bandpass', 1800, 9);
    this.whistle = gain(); loop(this.white).connect(this.whistleF).connect(this.whistle).connect(this.amb);
    // Sea wash along the hull, and the bow-wave hiss.
    this.washF = filt('lowpass', 900);
    this.wash = gain(); loop(this.pink, 0.8).connect(filt('highpass', 90)).connect(this.washF).connect(this.wash).connect(this.amb);
    this.hiss = gain(); loop(this.white, 0.7).connect(filt('highpass', 1800)).connect(filt('lowpass', 7000)).connect(this.hiss).connect(this.amb);
    // Ship: engines and ventilation.
    this.hum = gain();
    for (const [f, a] of [[47, 0.5], [94, 0.25], [141, 0.12], [62, 0.18]]) {
      const o = ctx.createOscillator(); o.frequency.value = f * (1 + (Math.random() - 0.5) * 0.004);
      const g = gain(a); o.connect(g).connect(this.hum); o.start();
    }
    this.hum.connect(filt('lowpass', 260)).connect(this.amb);
    this.vent = gain(); loop(this.brown, 1.4).connect(filt('bandpass', 260, 0.5)).connect(this.vent).connect(this.amb);
    // Rain: hiss in the open, patter under cover.
    this.rainOpen = gain(); loop(this.pink, 1.2).connect(filt('highpass', 900)).connect(this.rainOpen).connect(this.amb);
    this.rainRoof = gain(); loop(this.brown, 2.6).connect(filt('bandpass', 900, 0.8)).connect(this.rainRoof).connect(this.amb);
    // Pool-deck murmur: noise through moving vowel-like formants.
    this.murmur = gain();
    this.formants = [];
    const src = loop(this.pink, 1.0);
    for (const f of [420, 900, 1700, 2600]) {
      const b = filt('bandpass', f, 6);
      src.connect(b).connect(this.murmur);
      this.formants.push([b, f]);
    }
    this.murmur.connect(this.amb);
    this.applyVolumes();
  }

  applyVolumes() {
    if (!this.ctx) return;
    const a = settings.get().audio;
    const t = this.ctx.currentTime;
    this.master.gain.setTargetAtTime(a.muted ? 0 : a.master, t, 0.1);
    this.amb.gain.setTargetAtTime(a.ambient, t, 0.1);
    this.fx.gain.setTargetAtTime(a.effects, t, 0.1);
  }

  _set(node, v, tc = 0.25) { node.gain.setTargetAtTime(v, this.ctx.currentTime, tc); }

  /**
   * s: { height (m above sea), nearRail (0..1), wind (apparent m/s), speed,
   *      rain, sheltered, day (0..1), pool (0..1 proximity), funnel (0..1),
   *      tender (bool), port (bool), fog, people }
   */
  update(dt, s) {
    if (!this.ctx || this.ctx.state !== 'running') return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    const exposure = clamp01(0.35 + s.height / 60) * (s.sheltered ? 0.45 : 1);
    const gust = 0.75 + 0.25 * Math.sin(t * 0.37) * Math.sin(t * 0.13 + 1.7) + 0.12 * Math.sin(t * 1.9);
    const w = clamp01(s.wind / 28);
    this._set(this.windLow, (0.05 + w * 0.5) * exposure * gust);
    this._set(this.windHigh, (0.02 + w * 0.25) * exposure * gust);
    this.windBand.frequency.setTargetAtTime(500 + w * 900 * gust, t, 0.3);
    this._set(this.whistle, w * w * 0.05 * s.nearRail * gust);
    this.whistleF.frequency.setTargetAtTime(1400 + gust * 900, t, 0.4);

    const nearWater = clamp01(1 - s.height / 55);
    const swell = 0.7 + 0.3 * Math.sin(t * 0.55) * Math.sin(t * 0.21 + 0.4);
    this._set(this.wash, (s.tender ? 0.6 : 0.25) * nearWater * swell * (s.port ? 0.35 : 1));
    this.washF.frequency.setTargetAtTime(500 + nearWater * 900, t, 0.5);
    this._set(this.hiss, clamp01(s.speed / 10) * (s.tender ? 0.22 : 0.08) * nearWater);

    this._set(this.hum, 0.18 * (s.tender ? 0.4 : 1) * (0.4 + s.funnel * 0.9));
    this._set(this.vent, (0.03 + s.funnel * 0.18) * (s.tender ? 0.3 : 1));

    this._set(this.rainOpen, s.rain * (s.sheltered ? 0.12 : 0.35));
    this._set(this.rainRoof, s.rain * (s.sheltered ? 0.3 : 0.05));

    const crowd = s.people ? s.pool * s.day * (1 - s.rain) : 0;
    this._set(this.murmur, crowd * 0.25, 0.8);
    for (const [b, f] of this.formants) b.frequency.setTargetAtTime(f * (0.85 + 0.3 * Math.random()), t, 0.12);

    // Gulls by day, more of them in port.
    this.gullT -= dt;
    if (this.gullT <= 0) {
      if (s.day > 0.5 && s.rain < 0.3) this.gull(s.port ? 1 : 0.4);
      this.gullT = (s.port ? 4 : 14) + Math.random() * 14;
    }
    // Fog signal: one prolonged blast every two minutes when under way in fog.
    if (s.fog > 0.5 && !s.port) {
      this.fogHornT -= dt;
      if (this.fogHornT <= 0) { this.horn(4.5); this.fogHornT = 120; }
    } else this.fogHornT = Math.min(this.fogHornT, 20);
  }

  /** The ship's horn: a deep chord with a long tail. */
  horn(seconds = 2.6) {
    if (!this.ctx) return;
    const ctx = this.ctx, t = ctx.currentTime;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(0.5, t + 0.25);
    g.gain.setValueAtTime(0.5, t + seconds);
    g.gain.linearRampToValueAtTime(0, t + seconds + 0.9);
    const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 700; lp.Q.value = 0.9;
    for (const [f, a] of [[69, 0.6], [87, 0.4], [138, 0.25], [174, 0.15]]) {
      const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = f;
      o.frequency.setValueAtTime(f * 0.97, t); o.frequency.linearRampToValueAtTime(f, t + 0.3);
      const og = ctx.createGain(); og.gain.value = a;
      o.connect(og).connect(lp); o.start(t); o.stop(t + seconds + 1.2);
    }
    lp.connect(g);
    g.connect(this.fx);
    g.connect(this.reverb);
  }

  thunder(distance, power) {
    if (!this.ctx) return;
    const ctx = this.ctx;
    const delay = distance / 343;
    const t = ctx.currentTime + delay;
    const src = ctx.createBufferSource(); src.buffer = this.brown; src.playbackRate.value = 0.6;
    const lp = ctx.createBiquadFilter(); lp.type = 'lowpass';
    lp.frequency.setValueAtTime(distance < 3000 ? 1800 : 600, t);
    lp.frequency.exponentialRampToValueAtTime(90, t + 5);
    const g = ctx.createGain();
    const v = Math.min(1, power * 2400 / Math.max(800, distance));
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(v, t + (distance < 3000 ? 0.05 : 0.4));
    g.gain.exponentialRampToValueAtTime(0.001, t + 4 + Math.random() * 3);
    src.connect(lp).connect(g).connect(this.fx);
    g.connect(this.reverb);
    src.start(t, Math.random() * 3); src.stop(t + 8);
  }

  gull(near = 0.5) {
    if (!this.ctx) return;
    const ctx = this.ctx, t0 = ctx.currentTime;
    const pan = ctx.createStereoPanner(); pan.pan.value = Math.random() * 2 - 1;
    const out = ctx.createGain(); out.gain.value = 0.05 + near * 0.08;
    out.connect(pan).connect(this.fx);
    const calls = 2 + Math.floor(Math.random() * 4);
    for (let i = 0; i < calls; i++) {
      const t = t0 + i * (0.22 + Math.random() * 0.12);
      const o = ctx.createOscillator(); o.type = 'triangle';
      const base = 1500 + Math.random() * 500;
      o.frequency.setValueAtTime(base * 1.25, t);
      o.frequency.exponentialRampToValueAtTime(base * 0.8, t + 0.16);
      const fm = ctx.createOscillator(); fm.frequency.value = 38;
      const fmg = ctx.createGain(); fmg.gain.value = 70;
      fm.connect(fmg).connect(o.frequency);
      const g = ctx.createGain();
      g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(0.9, t + 0.02); g.gain.exponentialRampToValueAtTime(0.001, t + 0.2);
      const bp = ctx.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = base; bp.Q.value = 2.5;
      o.connect(bp).connect(g).connect(out);
      o.start(t); fm.start(t); o.stop(t + 0.22); fm.stop(t + 0.22);
    }
  }

  step(surface = 'teak', speed = 1.5) {
    if (!this.ctx) return;
    const ctx = this.ctx, t = ctx.currentTime;
    const src = ctx.createBufferSource(); src.buffer = this.white;
    const f = ctx.createBiquadFilter();
    f.type = surface === 'metal' ? 'bandpass' : 'lowpass';
    f.frequency.value = surface === 'metal' ? 2400 : surface === 'paint' ? 1100 : 700;
    f.Q.value = surface === 'metal' ? 4 : 0.8;
    const g = ctx.createGain();
    const v = 0.05 + Math.min(1, speed / 4) * 0.07;
    g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(0.001, t + (surface === 'metal' ? 0.14 : 0.09));
    src.connect(f).connect(g).connect(this.fx);
    src.start(t, Math.random() * 2); src.stop(t + 0.2);
  }
}
