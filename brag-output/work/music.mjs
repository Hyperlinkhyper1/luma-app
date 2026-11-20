// 20s, 120 BPM, A minor. Writes work/music.wav (48k stereo 16-bit).
import fs from 'fs';
const SR = 48000, DUR = 20, N = SR * DUR, BPM = 120, BEAT = 60 / BPM;
const L = new Float32Array(N), R = new Float32Array(N);
const mtof = m => 440 * Math.pow(2, (m - 69) / 12);
let seed = 7; const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296) * 2 - 1;
const add = (i, l, r = l) => { if (i >= 0 && i < N) { L[i] += l; R[i] += r; } };

// chords per bar (2s): Am F C G | Am F C G | Am (end)
const CH = [[57, 60, 64], [53, 57, 60], [48, 52, 55, 60], [55, 59, 62], [57, 60, 64], [53, 57, 60], [48, 52, 55, 60], [55, 59, 62], [53, 57, 60, 64], [57, 60, 64, 69]];
const ROOT = [45, 41, 48, 43, 45, 41, 48, 43, 41, 45];

// sidechain envelope from kicks
const kickTimes = []; for (let t = 3; t < 18; t += BEAT) kickTimes.push(t);
kickTimes.push(18);
const duck = new Float32Array(N).fill(1);
for (const kt of kickTimes) { const s = Math.round(kt * SR); for (let i = 0; i < SR * .3; i++) if (s + i < N) duck[s + i] = Math.min(duck[s + i], 0.35 + 0.65 * Math.min(1, i / (SR * .3))); }

// pad: detuned saws, one-pole lowpass, swells per bar
{
  const lp = [0, 0];
  for (let bar = 0; bar < 10; bar++) {
    const s0 = bar * 2 * SR, len = (bar === 9 ? 2 : 2.05) * SR;
    const notes = CH[bar];
    const open = bar < 1 ? 0.25 : 0.45;
    for (let i = 0; i < len && s0 + i < N; i++) {
      const t = (s0 + i) / SR;
      let v = 0;
      for (const m of notes) for (const d of [-0.08, 0.08]) { const f = mtof(m + d); v += ((t * f) % 1) * 2 - 1; }
      v /= notes.length * 2;
      const env = Math.min(1, i / (SR * .08)) * Math.min(1, (len - i) / (SR * .1));
      const c = 0.06 + 0.06 * open;
      lp[0] += c * (v - lp[0]); lp[1] += c * (lp[0] - lp[1]);
      const fadeEnd = t > 19.2 ? Math.max(0, (20 - t) / .8) : 1;
      const o = lp[1] * env * 0.16 * duck[s0 + i] * fadeEnd;
      add(s0 + i, o * 1.05, o * 0.95);
    }
  }
}

// pluck arpeggio, 8th notes, triangle + decay, ping-pong
for (let k = 0; k < 40 * 2 - 4; k++) {
  const t0 = k * BEAT / 2; if (t0 >= 18) break;
  const bar = Math.floor(t0 / 2), notes = CH[bar];
  const pat = [0, 1, 2, 1, 2, 0, 1, 2];
  const m = notes[pat[k % 8] % notes.length] + 12 + (k % 8 === 4 ? 12 : 0);
  const f = mtof(m), s = Math.round(t0 * SR), len = SR * .35;
  const pan = k % 2 ? 0.7 : 1.3; const vel = t0 < 3 ? 0.11 : 0.085;
  for (let i = 0; i < len; i++) {
    const t = i / SR, ph = (t * f) % 1;
    const tri = 1 - 4 * Math.abs(ph - .5);
    const o = tri * Math.exp(-t * 11) * vel * Math.min(1, i / 40);
    add(s + i, o * pan, o * (2 - pan));
  }
}

// kick
for (const kt of kickTimes) {
  const s = Math.round(kt * SR); let ph = 0; const big = kt === 18;
  for (let i = 0; i < SR * (big ? .9 : .32); i++) {
    const t = i / SR, f = 45 + 95 * Math.exp(-t * 28);
    ph += f / SR; const o = Math.sin(2 * Math.PI * ph) * Math.exp(-t * (big ? 4 : 9)) * (big ? .5 : .42);
    add(s + i, o);
  }
}

// bass: 8th-note root pulses from 3s
for (let t0 = 3; t0 < 18; t0 += BEAT / 2) {
  const bar = Math.floor(t0 / 2), f = mtof(ROOT[bar] - 12 + 12), s = Math.round(t0 * SR), len = SR * .22;
  const off = Math.round((t0 - 3) / (BEAT / 2)) % 2 === 1;
  for (let i = 0; i < len; i++) {
    const t = i / SR; const env = Math.min(1, i / 150) * Math.exp(-t * 7);
    const o = (Math.sin(2 * Math.PI * f * t) * .8 + Math.tanh(3 * Math.sin(2 * Math.PI * f * t)) * .2) * env * (off ? .2 : .16);
    add(s + i, o);
  }
}

// hats on off-beat 8ths from 6s; clap on 2 & 4 from 6s
{
  let hp = 0, prev = 0;
  for (let t0 = 6 + BEAT / 2; t0 < 18; t0 += BEAT) {
    const s = Math.round(t0 * SR);
    for (let i = 0; i < SR * .05; i++) { const n = rnd(); hp = 0.85 * (hp + n - prev); prev = n; const o = hp * Math.exp(-i / SR * 70) * .045; add(s + i, o * .8, o * 1.2); }
  }
  for (let t0 = 6 + BEAT; t0 < 18; t0 += 2 * BEAT) {
    const s = Math.round(t0 * SR); let lp = 0;
    for (let i = 0; i < SR * .18; i++) { const t = i / SR; lp += .35 * (rnd() - lp); const o = lp * Math.exp(-t * 22) * .16; add(s + i, o); }
  }
}

// fx: whoosh into 3.0 and 18.0 (filtered noise rising)
for (const [a, b, g] of [[2.2, 3.0, .12], [17.3, 18.0, .1]]) {
  let lp = 0; const s = Math.round(a * SR), len = Math.round((b - a) * SR);
  for (let i = 0; i < len; i++) { const k = i / len; lp += (0.01 + .25 * k * k) * (rnd() - lp); const o = lp * k * k * g; add(s + i, o * (1 - k * .4), o * (.6 + k * .4)); }
}
// fx: soft UI ticks on clicks (tuned A6/E6), small and under the music
for (const ct of [6, 8, 10, 10.5, 12, 12.25, 13, 14]) {
  const s = Math.round(ct * SR), f = ct % 2 === 0 ? mtof(81) : mtof(76);
  for (let i = 0; i < SR * .08; i++) { const t = i / SR; const o = Math.sin(2 * Math.PI * f * t) * Math.exp(-t * 60) * .05; add(s + i, o); }
}
// fx: install chime at 16.0 (A major-ish bell: A5, C#6, E6)
for (const [m, d] of [[81, 0], [85, .06], [88, .12], [93, .18]]) {
  const s = Math.round((16 + d) * SR), f = mtof(m);
  for (let i = 0; i < SR * 1.2; i++) { const t = i / SR; const o = (Math.sin(2 * Math.PI * f * t) + .3 * Math.sin(2 * Math.PI * f * 2.01 * t)) * Math.exp(-t * 4) * .045; add(s + i, o * (m % 2 ? .8 : 1.2), o * (m % 2 ? 1.2 : .8)); }
}

// master: soft clip, normalize to -1 dBFS, fade last 0.3s
let peak = 0; for (let i = 0; i < N; i++) { L[i] = Math.tanh(L[i] * 1.2); R[i] = Math.tanh(R[i] * 1.2); peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i])); }
const g = 0.89 / peak;
const buf = Buffer.alloc(44 + N * 4);
buf.write('RIFF', 0); buf.writeUInt32LE(36 + N * 4, 4); buf.write('WAVEfmt ', 8); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(2, 22);
buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 4, 28); buf.writeUInt16LE(4, 32); buf.writeUInt16LE(16, 34); buf.write('data', 36); buf.writeUInt32LE(N * 4, 40);
for (let i = 0; i < N; i++) {
  const f = i > N - SR * .3 ? (N - i) / (SR * .3) : 1;
  buf.writeInt16LE(Math.round(L[i] * g * f * 32767), 44 + i * 4); buf.writeInt16LE(Math.round(R[i] * g * f * 32767), 46 + i * 4);
}
fs.writeFileSync(new URL('./music.wav', import.meta.url), buf);
console.log('peak', peak.toFixed(3));
