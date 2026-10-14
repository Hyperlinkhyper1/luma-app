import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import http from 'node:http';
import { createRequire } from 'node:module';
import test from 'node:test';
import { browserNetworkArgs, isolatePage, sceneUrl, vendorBody, vendorResource } from '../tool/renderer_network.mjs';
import { createRendererServer, renderWithProcess, validateScene } from '../tool/renderer_service.mjs';

test('container syscall profile keeps default denial and supports glibc thread fallback', async () => {
  const profile = JSON.parse(await fs.readFile(new URL('../renderer-seccomp.json', import.meta.url), 'utf8'));
  assert.equal(profile.defaultAction, 'SCMP_ACT_ERRNO');
  const clone3 = profile.syscalls.find((rule) => rule.names.includes('clone3'));
  assert.equal(clone3.action, 'SCMP_ACT_ERRNO');
  assert.equal(clone3.errnoRet, 38);
  for (const name of ['clone', 'setns', 'unshare', 'chroot']) {
    assert.ok(profile.syscalls.some((rule) => rule.action === 'SCMP_ACT_ALLOW' && rule.names.includes(name) && !rule.args?.length));
  }
});

test('vendor allowlist rejects local files, private hosts, unknown packages and traversal', () => {
  for (const url of ['file:///data/secret.key', 'http://127.0.0.1:8080/admin',
    'https://cdn.jsdelivr.net.evil.test/npm/three@0.160.0/build/three.module.js',
    'https://unpkg.com/evil@0.160.0/build/three.module.js',
    'https://unpkg.com/three@9.0.0/build/three.module.js',
    'https://cdn.jsdelivr.net/npm/three@0.160.0/%2e%2e/%2e%2e/secret.key',
    'https://user:password@unpkg.com/three@0.160.0/build/three.module.js',
    'https://unpkg.com/three@0.160.0/examples/textures/private.jpg']) {
    assert.equal(vendorResource(url), null, url);
  }
});

test('all pinned Three.js versions are served locally with their own APIs', async () => {
  const manifest = JSON.parse(await fs.readFile(new URL('../tool/package.json', import.meta.url), 'utf8'));
  for (const alias of Object.keys(manifest.dependencies).filter((name) => name.startsWith('three-'))) {
    const version = alias.slice(6);
    const body = await vendorBody(`https://cdn.jsdelivr.net/npm/three@${version}/build/three.module.js`);
    assert.ok(body?.length > 1000, version);
    const controls = await vendorBody(`https://unpkg.com/three@${version}/examples/jsm/controls/OrbitControls.js`);
    assert.ok(controls?.includes('OrbitControls'), version);
    assert.ok(controls.includes(`three@${version}/build/three.module.js`), version);
  }
  assert.ok((await vendorBody('https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js')).length > 1000);
  assert.ok((await vendorBody('https://cdn.jsdelivr.net/npm/three@0.170.0/+esm')).length > 1000);
  assert.ok((await vendorBody('https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/controls/OrbitControls.js/+esm')).includes('three@0.170.0/build/three.module.js'));
  assert.ok((await vendorBody('https://cdn.jsdelivr.net/npm/@google/model-viewer@3.5.0/dist/model-viewer.min.js')).length > 1000);
});

test('page interceptor supplies the scene and aborts unapproved requests', async () => {
  let handler;
  const mainFrame = {};
  const page = { setBypassServiceWorker: async (v) => assert.equal(v, true),
    setRequestInterception: async (v) => assert.equal(v, true),
    mainFrame: () => mainFrame, on: (event, callback) => { assert.equal(event, 'request'); handler = callback; } };
  await isolatePage(page, '<h1>scene</h1>');
  const request = (url, method = 'GET', frame = mainFrame) => ({
    url: () => url, method: () => method, isNavigationRequest: () => true, frame: () => frame,
    respond: async (result) => result, abort: async () => 'blocked', continue: async () => 'continued',
    isInterceptResolutionHandled: () => false,
  });
  const scene = await handler(request(sceneUrl));
  assert.equal(scene.body, '<h1>scene</h1>');
  assert.match(scene.headers['Content-Security-Policy'], /form-action 'none'/);
  assert.equal(await handler(request('file:///data/secret.key')), 'blocked');
  assert.equal(await handler(request('http://server:8080/secret')), 'blocked');
  assert.equal(await handler(request(sceneUrl, 'POST')), 'blocked');
  assert.equal(await handler(request(sceneUrl, 'GET', {})), 'blocked');
});

test('renderer API validates identity and returns PNG bytes without exposing error details', async (t) => {
  const png = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10, 0]);
  let scene;
  const server = createRendererServer({ render: async (s) => { scene = s; return { png, backend: 'sandbox', detail: 'frame' }; } });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  t.after(() => new Promise((r) => { server.closeAllConnections(); server.close(r); }));
  const endpoint = `http://127.0.0.1:${server.address().port}/render`;
  const payload = { id: 'pc_test', kind: 'pc', scene: Buffer.from('<html>scene</html>').toString('base64') };
  let response = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
  assert.equal(response.status, 200);
  assert.deepEqual(Buffer.from(await response.arrayBuffer()), png);
  assert.equal(scene.scene.toString(), '<html>scene</html>');
  for (const invalid of [{ ...payload, id: '../secret' }, { ...payload, scene: 'not base64' },
    { ...payload, framing: { px: 'no' } }]) {
    response = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(invalid) });
    assert.equal(response.status, 400);
  }
  assert.throws(() => validateScene({ ...payload, kind: '../../secret' }));
});

test('Chromium renders vendored Three.js while HTTP, files, WebSockets and worker requests stay blocked',
  { skip: !process.env.LUMA_TEST_CHROMIUM, timeout: 60000 }, async (t) => {
    const require = createRequire(new URL('../tool/package.json', import.meta.url));
    const puppeteer = require('puppeteer-core');
    let requests = 0;
    const trap = http.createServer((req, res) => { requests++; res.end('secret'); });
    trap.on('upgrade', (_, socket) => { requests++; socket.destroy(); });
    await new Promise((r) => trap.listen(0, '127.0.0.1', r));
    t.after(() => new Promise((r) => trap.close(r)));
    const address = `127.0.0.1:${trap.address().port}`;
    const browser = await puppeteer.launch({ executablePath: process.env.LUMA_TEST_CHROMIUM,
      headless: true, args: [...browserNetworkArgs, '--enable-unsafe-swiftshader', '--use-angle=swiftshader'] });
    t.after(() => browser.close());
    const page = await browser.newPage();
    await isolatePage(page, `<!doctype html><script type="module">
import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js';
const renderer = new THREE.WebGLRenderer(); document.body.append(renderer.domElement);
renderer.setSize(100,100); renderer.setClearColor(0x7a9911); renderer.render(new THREE.Scene(),new THREE.PerspectiveCamera());
window.__threeLoaded = THREE.REVISION;
fetch('http://${address}/secret').catch(()=>{});
fetch('file:///data/secret.key').catch(()=>{});
try { new WebSocket('ws://${address}/secret'); } catch {}
const worker = new Worker(URL.createObjectURL(new Blob(["fetch('http://${address}/worker').catch(()=>{});"],{type:'text/javascript'})));
window.__complete = true;</script>`);
    await page.goto(sceneUrl);
    await page.waitForFunction('window.__complete === true');
    assert.equal(await page.evaluate(() => window.__threeLoaded), '160');
    assert.ok((await page.screenshot()).length > 1000);
    // New targets have no interceptor or inherited CSP; the browser proxy
    // must still prevent them reaching loopback or connected services.
    const unfiltered = await browser.newPage();
    await unfiltered.evaluate(async (host) => {
      await fetch(`http://${host}/unfiltered`).catch(() => {});
    }, address);
    await unfiltered.close();
    await new Promise((r) => setTimeout(r, 700));
    assert.equal(requests, 0);
  });

test('isolated renderer service produces a real PNG through its HTTP contract',
  { skip: !process.env.LUMA_TEST_CHROMIUM, timeout: 60000 }, async (t) => {
    const original = process.env.LUMA_CHROMIUM_BIN;
    process.env.LUMA_CHROMIUM_BIN = process.env.LUMA_TEST_CHROMIUM;
    t.after(() => {
      if (original === undefined) delete process.env.LUMA_CHROMIUM_BIN;
      else process.env.LUMA_CHROMIUM_BIN = original;
    });
    const server = createRendererServer({ render: renderWithProcess });
    await new Promise((r) => server.listen(0, '127.0.0.1', r));
    t.after(() => new Promise((r) => { server.closeAllConnections(); server.close(r); }));
    const scene = '<!doctype html><style>body{margin:0;background:#fff;color:#111;font:80px sans-serif}header{background:#239475;padding:80px}section{background:#c5982d;padding:60px}</style><header>Offline renderer</header><section>Isolated preview</section>';
    const response = await fetch(`http://127.0.0.1:${server.address().port}/render`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({
        id: 'website_landing_page_isolated', kind: 'website_landing_page', scene: Buffer.from(scene).toString('base64'),
      }),
    });
    assert.equal(response.status, 200, await response.clone().text());
    const png = Buffer.from(await response.arrayBuffer());
    assert.ok(png.length > 1000);
    assert.equal(png.subarray(1, 4).toString(), 'PNG');
  });
