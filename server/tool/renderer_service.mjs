import { spawn } from 'node:child_process';
import fsSync from 'node:fs';
import fs from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const maxBody = 128 * 1024 * 1024;
const pngSignature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

export class SceneRenderError extends Error {}

export function validateScene(value) {
  if (!value || !/^[a-z0-9_-]{1,160}$/.test(value.id) || !/^[a-z0-9_]{1,80}$/.test(value.kind)) {
    throw new Error('Invalid scene identity.');
  }
  if (typeof value.scene !== 'string' || !/^[A-Za-z0-9+/]*={0,2}$/.test(value.scene) || value.scene.length === 0 || value.scene.length % 4 !== 0) {
    throw new Error('Invalid scene bytes.');
  }
  const scene = Buffer.from(value.scene, 'base64');
  if (scene.length > 96 * 1024 * 1024) throw new Error('Scene exceeds renderer request limit.');
  let framing = null;
  if (value.framing != null) {
    const keys = ['px', 'py', 'pz', 'qx', 'qy', 'qz', 'qw'];
    if (!keys.every((k) => Number.isFinite(value.framing[k]))) throw new Error('Invalid framing.');
    for (const key of ['fov', 'zoom']) {
      if (value.framing[key] != null) {
        if (!Number.isFinite(value.framing[key])) throw new Error('Invalid framing.');
        keys.push(key);
      }
    }
    framing = Object.fromEntries(keys.map((k) => [k, value.framing[k]]));
  }
  return { id: value.id, kind: value.kind, scene, framing };
}

// Puppeteer starts Chromium detached, in a process group of its own, so
// killing the render script's group never reached the browser. Orphaned to
// the container's init, it kept animating its scene on SwiftShader at most
// of a core with nothing left to screenshot it. Kills therefore walk the
// whole process tree, read from /proc.
export function processTable(procDir = '/proc') {
  const table = new Map();
  let names = [];
  try { names = fsSync.readdirSync(procDir); } catch { return table; }
  for (const name of names) {
    if (!/^\d+$/.test(name)) continue;
    try {
      const stat = fsSync.readFileSync(path.join(procDir, name, 'stat'), 'utf8');
      const ppid = Number(stat.slice(stat.lastIndexOf(')') + 2).split(' ')[1]);
      if (Number.isInteger(ppid)) table.set(Number(name), ppid);
    } catch { /* Exited meanwhile. */ }
  }
  return table;
}

export function descendants(table, root) {
  const found = [];
  const queue = [root];
  while (queue.length > 0) {
    const parent = queue.shift();
    for (const [pid, ppid] of table) {
      if (ppid === parent && !found.includes(pid)) {
        found.push(pid);
        queue.push(pid);
      }
    }
  }
  return found;
}

const killQuietly = (pid) => {
  try { process.kill(pid, 'SIGKILL'); } catch { /* Already exited. */ }
};

// Kills whatever hangs off the container's init besides this service: in
// the renderer container that is only ever a browser some render left
// behind, along with its GPU, renderer and crashpad children.
export function reapOrphans({ table = processTable(), self = process.pid } = {}) {
  const orphans = [...table].filter(([pid, ppid]) => ppid === 1 && pid !== self).map(([pid]) => pid);
  for (const pid of orphans) {
    for (const p of [...descendants(table, pid).reverse(), pid]) killQuietly(p);
  }
  return orphans;
}

export async function renderWithProcess(scene, signal) {
  const scratch = await fs.mkdtemp(path.join(os.tmpdir(), 'luma_renderer_'));
  let child;
  const kill = () => {
    if (!child?.pid) return;
    if (process.platform !== 'linux') {
      try { child.kill('SIGKILL'); } catch { /* Already exited. */ }
      return;
    }
    const tree = descendants(processTable(), child.pid);
    try { process.kill(-child.pid, 'SIGKILL'); } catch { /* Already exited. */ }
    for (const pid of tree) killQuietly(pid);
  };
  const timeout = setTimeout(kill, 9 * 60 * 1000);
  try {
    await fs.mkdir(path.join(scratch, 'scenes'));
    await fs.writeFile(path.join(scratch, 'scenes', `${scene.id}.${scene.kind === 'cathedral' ? 'glb' : 'html'}`), scene.scene);
    await fs.writeFile(path.join(scratch, 'manifest.json'), JSON.stringify({ benchmarks: [{ id: scene.id, kind: scene.kind }] }));
    if (scene.framing) {
      await fs.mkdir(path.join(scratch, 'framing'));
      await fs.writeFile(path.join(scratch, 'framing', `${scene.id}.json`), JSON.stringify(scene.framing));
    }
    child = spawn(process.execPath, [path.join(toolDir, 'render_previews.mjs'), '--root', scratch,
      '--out', path.join(scratch, 'previews'), '--ids', scene.id, '--jobs', '1',
      '--chromium-bin', process.env.LUMA_CHROMIUM_BIN ?? '/usr/bin/chromium'], {
      detached: process.platform === 'linux',
      env: { PATH: process.platform === 'win32' ? process.env.PATH : '/usr/local/bin:/usr/bin:/bin',
        ...(process.platform === 'win32' ? { SystemRoot: process.env.SystemRoot } : {}),
        HOME: os.tmpdir(), TMPDIR: os.tmpdir(), TEMP: os.tmpdir(), TMP: os.tmpdir(),
        XDG_CONFIG_HOME: path.join(scratch, 'config'), XDG_CACHE_HOME: path.join(scratch, 'cache') },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let output = '';
    const capture = (chunk) => { output = (output + chunk.toString('utf8')).slice(-32000); };
    child.stdout.on('data', capture);
    child.stderr.on('data', capture);
    signal.addEventListener('abort', kill, { once: true });
    if (signal.aborted) kill();
    const code = await new Promise((resolve, reject) => {
      child.once('error', reject);
      child.once('close', resolve);
    });
    if (signal.aborted) throw new Error('Render cancelled.');
    if (code !== 0 || !output.split(/\r?\n/).some((line) => line === `OK   ${scene.id}`)) {
      console.error(`Render of ${scene.id} exited with ${code}:\n${output.slice(-8000)}`);
      throw new SceneRenderError(output.split(/\r?\n/).find((line) => line.startsWith(`FAIL ${scene.id}:`)) ?? 'Renderer failed.');
    }
    const png = await fs.readFile(path.join(scratch, 'previews', `${scene.id}.png`));
    return { png, backend: /^RENDERER (.+)$/m.exec(output)?.[1] ?? 'isolated Chromium',
      detail: output.split(/\r?\n/).filter((line) => line.startsWith(`NOTE ${scene.id} `))
        .map((line) => line.slice(`NOTE ${scene.id} `.length)).filter((line) => !line.startsWith('source:')).join(' · ') };
  } finally {
    clearTimeout(timeout);
    signal.removeEventListener('abort', kill);
    kill();
    await fs.rm(scratch, { recursive: true, force: true });
  }
}

const safeHeader = (text) => String(text ?? '').replace(/[^\x20-\x7e]/g, ' ').slice(0, 1000);

export function createRendererServer({ render = renderWithProcess, maxJobs = 6 } = {}) {
  let active = 0;
  const server = http.createServer(async (request, response) => {
    if (request.method === 'GET' && request.url === '/health') {
      response.writeHead(200, { 'Content-Type': 'text/plain' }).end('ok');
      return;
    }
    if (request.method !== 'POST' || request.url !== '/render') {
      response.writeHead(404).end();
      return;
    }
    if (request.headers['content-type']?.split(';')[0] !== 'application/json') {
      response.writeHead(415).end();
      return;
    }
    if (active >= maxJobs) { response.writeHead(503).end('Renderer busy.'); return; }
    active++;
    const controller = new AbortController();
    response.once('close', () => { if (!response.writableFinished) controller.abort(); });
    try {
      const chunks = [];
      let length = 0;
      for await (const chunk of request) {
        length += chunk.length;
        if (length > maxBody) { response.writeHead(413).end(); return; }
        chunks.push(chunk);
      }
      let scene;
      try { scene = validateScene(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
      catch { response.writeHead(400).end('Invalid render request.'); return; }
      const result = await render(scene, controller.signal);
      if (!Buffer.isBuffer(result.png) || result.png.length > 16 * 1024 * 1024 || !result.png.subarray(0, 8).equals(pngSignature)) {
        throw new Error('Renderer did not produce a PNG.');
      }
      response.writeHead(200, { 'Content-Type': 'image/png', 'Content-Length': result.png.length,
        'X-Renderer-Backend': safeHeader(result.backend), 'X-Renderer-Detail': safeHeader(result.detail) }).end(result.png);
    } catch (error) {
      if (!response.headersSent) response.writeHead(500, { 'Content-Type': 'application/json' }).end(JSON.stringify({
        message: error instanceof SceneRenderError ? error.message.slice(0, 1000) : 'Scene could not be rendered.',
      }));
    } finally { active--; }
  });
  server.requestTimeout = 10 * 60 * 1000;
  server.headersTimeout = 30000;
  return server;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.platform === 'linux' && process.env.LUMA_RENDERER_REAP_ORPHANS === '1') {
    const sweep = () => {
      const reaped = reapOrphans();
      if (reaped.length > 0) console.log(`Reaped ${reaped.length} orphaned renderer process(es).`);
    };
    sweep();
    setInterval(sweep, 30000).unref();
  }
  createRendererServer().listen(Number(process.env.PORT ?? 8081), '0.0.0.0', () => console.log('Isolated renderer listening.'));
}
