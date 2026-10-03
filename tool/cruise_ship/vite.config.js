import { defineConfig } from 'vite';
import { viteSingleFile } from 'vite-plugin-singlefile';
import { fileURLToPath } from 'node:url';
import { mkdirSync, writeFileSync } from 'node:fs';

const here = (p) => fileURLToPath(new URL(p, import.meta.url));

// Dev-only: lets the page post screenshots (window.__shot) to disk under
// .shots/, for checking the scene's look without a visible browser window.
const shots = {
  name: 'cruise-shots',
  apply: 'serve',
  configureServer(server) {
    server.middlewares.use('/__shot', (req, res) => {
      const name = (new URL(req.url, 'http://x').searchParams.get('name') || 'shot').replace(/[^\w.-]/g, '_');
      let body = '';
      req.setEncoding('utf8');
      req.on('data', (c) => { body += c; });
      req.on('end', () => {
        const b64 = body.replace(/^data:image\/\w+;base64,/, '');
        mkdirSync(here('.shots'), { recursive: true });
        writeFileSync(here(`.shots/${name}.jpg`), Buffer.from(b64, 'base64'));
        res.end('ok');
      });
    });
  },
};

// The scene is opened by WebView2 straight from luma's asset folder over
// file://, where module scripts, fetch() and workers are all blocked. So the
// build inlines every byte into the one HTML file, and nothing is loaded at
// runtime: textures, noise volumes and sounds are generated in code.
export default defineConfig({
  base: './',
  plugins: [viteSingleFile({ removeViteModuleLoader: true }), shots],
  build: {
    outDir: here('../../assets/ai_usage/cruise_ship_tests'),
    emptyOutDir: false,
    target: 'es2022',
    assetsInlineLimit: 100_000_000,
    chunkSizeWarningLimit: 8000,
    cssCodeSplit: false,
    rollupOptions: { input: here('opus_5_5_ultracode.html') },
  },
  server: { port: 5181, strictPort: true, watch: { ignored: ['**/.shots/**'] } },
});
