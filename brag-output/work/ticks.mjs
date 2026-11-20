import fs from 'fs';
const clicks = JSON.parse(fs.readFileSync('clicks.json', 'utf8'));
const SR = 44100, N = Math.ceil(39.5 * SR), L = new Float32Array(N);
const last = clicks[clicks.length - 1];
for (const c of clicks) { const s = Math.round(c * SR); const f = c === last ? 1760 : 1320;
  for (let i = 0; i < SR * .06; i++) { const t = i / SR; L[s + i] += Math.sin(2 * Math.PI * f * t) * Math.exp(-t * 90) * .18 + (Math.random() * 2 - 1) * Math.exp(-t * 400) * .05; } }
const b = Buffer.alloc(44 + N * 2); b.write('RIFF', 0); b.writeUInt32LE(36 + N * 2, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22); b.writeUInt32LE(SR, 24); b.writeUInt32LE(SR * 2, 28); b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(N * 2, 40);
for (let i = 0; i < N; i++) b.writeInt16LE(Math.round(Math.max(-1, Math.min(1, L[i])) * 32767), 44 + i * 2);
fs.writeFileSync('ticks.wav', b);
console.log(clicks.length, 'clicks');
