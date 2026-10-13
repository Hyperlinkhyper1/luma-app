import assert from 'node:assert/strict';
import http from 'node:http';
import net from 'node:net';

assert.notEqual(process.getuid(), 0, 'Renderer image must run as non-root.');
for (const file of ['/data', '/wiki', '/app/.env']) {
  const fs = await import('node:fs/promises');
  assert.equal(await fs.access(file).then(() => true, () => false), false, `${file} must be absent`);
}
let requests = 0;
const trap = http.createServer((request, response) => { requests++; response.end('private data'); });
trap.on('upgrade', (_, socket) => { requests++; socket.destroy(); });
await new Promise((resolve) => trap.listen(8090, '0.0.0.0', resolve));
try {
  const externalConnection = await new Promise((resolve) => {
    const socket = net.connect({ host: '1.1.1.1', port: 443 });
    const timer = setTimeout(() => { socket.destroy(); resolve(false); }, 2000);
    socket.once('connect', () => { clearTimeout(timer); socket.destroy(); resolve(true); });
    socket.once('error', () => { clearTimeout(timer); resolve(false); });
  });
  assert.equal(externalConnection, false, 'Renderer network must have no internet egress.');
  for (let attempt = 0; ; attempt++) {
    try {
      const health = await fetch('http://renderer:8081/health', { signal: AbortSignal.timeout(2000) });
      assert.equal(health.status, 200);
      break;
    } catch (error) {
      if (attempt >= 20) throw error;
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }
  const html = `<!doctype html><style>body{background:#efe1c1;color:#172d25;font:60px sans-serif}canvas{display:block}</style><h1>Sandbox preview</h1><script type="module">
import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js';
const renderer = new THREE.WebGLRenderer(); renderer.setSize(600,300); renderer.setClearColor(0x239475);
document.body.append(renderer.domElement); renderer.render(new THREE.Scene(),new THREE.PerspectiveCamera());
fetch('http://smoke:8090/private').catch(()=>{}); fetch('file:///data/secret.key').catch(()=>{});
try { new WebSocket('ws://smoke:8090/private'); } catch {}
new Worker(URL.createObjectURL(new Blob(["fetch('http://smoke:8090/worker').catch(()=>{});"],{type:'text/javascript'})));
</script>`;
  const response = await fetch('http://renderer:8081/render', { method: 'POST',
    headers: { 'Content-Type': 'application/json' }, signal: AbortSignal.timeout(120000),
    body: JSON.stringify({ id: 'website_landing_page_sandbox', kind: 'website_landing_page', scene: Buffer.from(html).toString('base64') }) });
  assert.equal(response.status, 200, await response.clone().text());
  const png = Buffer.from(await response.arrayBuffer());
  assert.ok(png.length > 1000);
  assert.equal(png.subarray(1, 4).toString(), 'PNG');
  assert.equal(requests, 0, 'Scene and worker requests must not reach connected services.');
  console.log('Renderer sandbox, local dependencies, PNG contract and network isolation passed.');
} finally {
  await new Promise((resolve) => trap.close(resolve));
}
