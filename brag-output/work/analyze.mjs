import { execFileSync } from 'child_process';
const FF = process.env.APPDATA + '/com.luma/luma/tools/ffmpeg.exe';
const SR = 22050;
const raw = execFileSync(FF, ['-v', 'error', '-i', process.argv[2], '-ac', '1', '-ar', String(SR), '-f', 'f32le', '-'], { maxBuffer: 1 << 30 });
const x = new Float32Array(raw.buffer, raw.byteOffset, raw.length / 4);
const HOP = 512, FR = SR / HOP;
// energy + onset strength (positive diff of log energy in low and full band)
const nF = Math.floor(x.length / HOP) - 1;
const E = new Float32Array(nF), LO = new Float32Array(nF);
let lp = 0;
for (let f = 0; f < nF; f++) { let e = 0, l = 0; for (let i = 0; i < HOP * 2; i++) { const v = x[f * HOP + i] || 0; lp += 0.02 * (v - lp); e += v * v; l += lp * lp; } E[f] = e; LO[f] = l; }
const ons = new Float32Array(nF);
for (let f = 1; f < nF; f++) ons[f] = Math.max(0, Math.log(1e-6 + E[f]) - Math.log(1e-6 + E[f - 1])) + 1.5 * Math.max(0, Math.log(1e-6 + LO[f]) - Math.log(1e-6 + LO[f - 1]));
// tempo by autocorrelation 80..170 BPM
let best = 0, bestBpm = 0;
for (let bpm = 80; bpm <= 170; bpm += 0.1) {
  const lag = FR * 60 / bpm; let s = 0;
  for (let f = 0; f + lag * 4 < nF; f++) { const a = ons[f]; s += a * (ons[Math.round(f + lag)] + 0.5 * ons[Math.round(f + 2 * lag)] + 0.5 * ons[Math.round(f + 4 * lag)]); }
  if (s > best) { best = s; bestBpm = bpm; }
}
// phase: best offset for beat grid
const per = FR * 60 / bestBpm; let bp = 0, bph = 0;
for (let ph = 0; ph < per; ph += 0.25) { let s = 0; for (let k = 0; ph + k * per < nF; k++) s += LO[Math.round(ph + k * per)] > 0 ? ons[Math.round(ph + k * per)] : 0; if (s > bp) { bp = s; bph = ph; } }
console.log('bpm', bestBpm.toFixed(2), 'first beat', (bph / FR).toFixed(3), 's');
// loudness per second (dB)
const sec = []; for (let s = 0; s < x.length / SR; s++) { let e = 0; for (let i = s * SR; i < (s + 1) * SR && i < x.length; i++) e += x[i] * x[i]; sec.push((10 * Math.log10(e / SR + 1e-9)).toFixed(0)); }
console.log('dB/s:', sec.join(' '));
// low-band energy per second for drop detection
const low = []; for (let s = 0; s < nF / FR - 1; s++) { let e = 0; for (let f = Math.floor(s * FR); f < (s + 1) * FR; f++) e += LO[f]; low.push((10 * Math.log10(e + 1e-9)).toFixed(0)); }
console.log('lowdB/s:', low.join(' '));
