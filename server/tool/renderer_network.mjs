import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const sceneUrl = 'https://luma-scene.invalid/scene.html';
const toolDir = path.dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(await fs.readFile(path.join(toolDir, 'package.json'), 'utf8'));
const versions = new Set(Object.keys(manifest.dependencies).filter((k) => k.startsWith('three-')).map((k) => k.slice(6)));
const cdnHosts = new Set(['unpkg.com', 'cdn.jsdelivr.net', 'cdnjs.cloudflare.com']);

export function vendorResource(raw) {
  let url;
  try { url = new URL(raw); } catch { return null; }
  if (url.protocol !== 'https:' || url.port || url.username || url.password || !cdnHosts.has(url.hostname)) return null;
  const pathname = decodeURIComponent(url.pathname);
  let match = /^(?:\/npm)?\/three@(\d+\.\d+\.\d+)(?:\/(.*))?$/.exec(pathname);
  if (!match && url.hostname === 'cdnjs.cloudflare.com') {
    const old = /^\/ajax\/libs\/three\.js\/(?:r(\d+)|(0\.\d+\.\d+))\/(.+)$/.exec(pathname);
    if (old) match = [old[0], old[2] ?? `0.${old[1]}.0`, old[3].startsWith('three.') ? `build/${old[3]}` : old[3]];
  }
  if (match) {
    const version = match[1];
    if (!versions.has(version)) return null;
    let resource = match[2] ?? 'build/three.module.js';
    resource = resource.replace(/\/?\+esm$/, '') || 'build/three.module.js';
    if (!/^(?:build|examples\/jsm?|examples\/js)\/[a-zA-Z0-9_./-]+\.js$/.test(resource) || resource.split('/').includes('..')) return null;
    return { package: `three-${version}`, resource, version,
      canonical: `https://cdn.jsdelivr.net/npm/three@${version}/${resource}` };
  }
  if ((url.hostname === 'unpkg.com' || url.hostname === 'cdn.jsdelivr.net') && pathname === `${url.hostname === 'cdn.jsdelivr.net' ? '/npm' : ''}/@google/model-viewer@3.5.0/dist/model-viewer.min.js`) {
    return { package: '@google/model-viewer', resource: 'dist/model-viewer.min.js' };
  }
  if (url.hostname === 'cdn.jsdelivr.net' && pathname === '/npm/@tweenjs/tween.js@23.1.3/dist/tween.esm.js') {
    return { package: '@tweenjs/tween.js', resource: 'dist/tween.esm.js' };
  }
  return null;
}

export async function vendorBody(raw) {
  const selected = vendorResource(raw);
  if (!selected) return null;
  let source;
  try { source = await fs.readFile(path.join(toolDir, 'node_modules', selected.package, selected.resource), 'utf8'); }
  catch { return null; }
  if (selected.version) {
    source = source.replace(/(\bfrom\s*|\bimport\s*)(['"])([^'"\n]+)\2/g, (whole, prefix, quote, specifier) => {
      const target = specifier === 'three'
        ? `https://cdn.jsdelivr.net/npm/three@${selected.version}/build/three.module.js`
        : specifier.startsWith('.') ? new URL(specifier, selected.canonical).href : null;
      return target ? `${prefix}${quote}${target}${quote}` : whole;
    });
  }
  return source;
}

export const browserNetworkArgs = [
  '--proxy-server=http://127.0.0.1:9',
  '--proxy-bypass-list=<-loopback>',
  '--host-resolver-rules=MAP * ~NOTFOUND',
  '--force-webrtc-ip-handling-policy=disable_non_proxied_udp',
  '--disable-background-networking',
  '--disable-component-update',
];

export async function isolatePage(page, html) {
  await page.setBypassServiceWorker(true);
  await page.setRequestInterception(true);
  page.on('request', async (request) => {
    try {
      const url = request.url();
      if (request.method() !== 'GET') return await request.abort('blockedbyclient');
      if (url === sceneUrl && request.isNavigationRequest() && request.frame() === page.mainFrame()) {
        return await request.respond({ status: 200, contentType: 'text/html', body: html, headers: {
          'Content-Security-Policy': "default-src 'none'; script-src 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net https://unpkg.com https://cdnjs.cloudflare.com; style-src 'unsafe-inline'; img-src data: blob:; font-src data:; connect-src data: blob:; worker-src blob: data:; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'",
        } });
      }
      if (/^(data|blob):/.test(url)) return await request.continue();
      const body = await vendorBody(url);
      if (body !== null) return await request.respond({ status: 200, contentType: 'application/javascript', body,
        headers: { 'Access-Control-Allow-Origin': '*' } });
      return await request.abort('blockedbyclient');
    } catch {
      if (!request.isInterceptResolutionHandled()) await request.abort('blockedbyclient').catch(() => {});
    }
  });
}
