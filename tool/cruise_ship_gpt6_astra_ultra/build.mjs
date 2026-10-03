import { build } from 'vite';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const output = path.resolve(here, '../../server/benchmarks/scenes/cruise_ship_gpt6_astra_ultra/index.html');
const result = await build({
  configFile: false,
  root: here,
  logLevel: 'warn',
  build: {
    write: false,
    target: 'es2022',
    minify: true,
    lib: { entry: path.join(here, 'src/main.js'), name: 'AstraCruise', formats: ['iife'] },
  },
});
const chunks = (Array.isArray(result) ? result : [result]).flatMap(r => r.output);
const scripts = chunks.filter(c => c.type === 'chunk');
if (scripts.length !== 1 || scripts[0].imports.length || scripts[0].dynamicImports.length) {
  throw new Error('The cruise scene must be one offline IIFE without imports.');
}
const license = await readFile(path.join(here, 'node_modules/three/LICENSE'), 'utf8');
const html = (await readFile(path.join(here, 'index.html'), 'utf8'))
  .replace('</head>', () => `<!-- Three.js\n${license.replace(/--/g, '—')}\n-->\n</head>`)
  .replace('/*__STYLE__*/', await readFile(path.join(here, 'src/styles.css'), 'utf8'))
  .replace('/*__SCENE__*/', () => scripts[0].code.replace(/<\/script/gi, '<\\/script'));
if (Buffer.byteLength(html) >= 60 * 1024 * 1024) throw new Error('Scene exceeds server upload limit.');
await mkdir(path.dirname(output), { recursive: true });
await writeFile(output, html);
console.log(`Built ${output} (${(Buffer.byteLength(html) / 1024 / 1024).toFixed(2)} MiB)`);
