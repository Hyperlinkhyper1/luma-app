// Mirrors the built wiki site (https://wiki.luma-app.cc) into
// assets/wiki_site/site.zip, the offline copy the Wiki plugin serves from a
// loopback server inside the app.
//
//   node tool/wiki_mirror/mirror.mjs [--origin https://wiki.luma-app.cc]
//
// It starts from the sitemap, then follows every same-origin page, script,
// stylesheet, image and fish model the pages reference. Nothing outside the
// origin is downloaded; the app blocks those requests at runtime anyway.

import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { crc32, deflateRawSync } from 'node:zlib';

const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const origin = flag('--origin', 'https://wiki.luma-app.cc').replace(/\/+$/, '');
const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const outFile = flag('--out', join(repoRoot, 'assets', 'wiki_site', 'site.zip'));

const files = new Map();
const queued = new Set();
const queue = [];
const missing = [];
const externalHosts = new Set();

const assetExt =
  /\.(js|mjs|css|json|png|jpe?g|gif|webp|avif|svg|ico|woff2?|ttf|otf|mp3|ogg|wav|mp4|webm|txt|xml|webmanifest|glb|gltf|bin)$/i;

function normalise(ref, base) {
  if (!ref) return null;
  ref = ref.trim().replace(/&amp;/g, '&');
  if (/^(data:|blob:|mailto:|tel:|javascript:|#)/i.test(ref)) return null;
  let url;
  try {
    url = new URL(ref, origin + base);
  } catch {
    return null;
  }
  if (url.origin !== origin) {
    if (/^https?:$/.test(url.protocol)) externalHosts.add(url.host);
    return null;
  }
  return decodeURI(url.pathname);
}

function enqueue(path) {
  if (!path || queued.has(path)) return;
  queued.add(path);
  queue.push(path);
}

function storagePath(path) {
  if (path.endsWith('/')) return path.slice(1) + 'index.html';
  if (assetExt.test(path) || /\.html?$/i.test(path)) return path.slice(1);
  return path.slice(1) + '/index.html';
}

function scanHtml(html, base) {
  const attr = /\s(?:href|src|poster|data-src|content)\s*=\s*"([^"]*)"/gi;
  for (const m of html.matchAll(attr)) {
    if (m[1].startsWith('/') || m[1].startsWith(origin) || m[1].startsWith('.')) {
      enqueue(normalise(m[1], base));
    }
  }
  for (const m of html.matchAll(/\ssrcset\s*=\s*"([^"]*)"/gi)) {
    for (const part of m[1].split(',')) enqueue(normalise(part.trim().split(/\s+/)[0], base));
  }
  for (const m of html.matchAll(/data-fish-slug="([a-z0-9-]+)"/g)) {
    enqueue(`/models/fish/${m[1]}.json`);
  }
  scanStrings(html, base);
  for (const m of html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/gi)) scanCss(m[1], base);
  for (const m of html.matchAll(/style="([^"]*)"/gi)) scanCss(m[1], base);
}

function scanCss(css, base) {
  for (const m of css.matchAll(/url\(\s*['"]?([^'")]+)['"]?\s*\)/gi)) enqueue(normalise(m[1], base));
  for (const m of css.matchAll(/@import\s+['"]([^'"]+)['"]/gi)) enqueue(normalise(m[1], base));
}

function scanJs(js, base) {
  for (const m of js.matchAll(/(?:from|import)\s*\(?\s*["'](\.{1,2}\/[^"']+)["']/g)) {
    enqueue(normalise(m[1], base));
  }
  scanStrings(js, base);
}

function scanStrings(text, base) {
  const quoted = /["'`](\/(?:_astro|images|img|models|fonts|assets|media|favicon)[^"'`\s$]*?)["'`]/g;
  for (const m of text.matchAll(quoted)) {
    if (assetExt.test(m[1])) enqueue(normalise(m[1], base));
  }
  for (const m of text.matchAll(/https?:\/\/([a-z0-9.-]+\.[a-z]{2,})/gi)) {
    if (`https://${m[1]}` !== origin) externalHosts.add(m[1]);
  }
}

async function fetchPath(path) {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const res = await fetch(origin + path, { redirect: 'follow' });
      if (res.status === 404 && path !== '/404.html') return null;
      if (!res.ok && res.status !== 404) throw new Error(`HTTP ${res.status}`);
      const finalPath = decodeURI(new URL(res.url).pathname);
      return { body: Buffer.from(await res.arrayBuffer()), type: res.headers.get('content-type') ?? '', finalPath };
    } catch (error) {
      if (attempt === 2) throw error;
      await new Promise((r) => setTimeout(r, 500 * (attempt + 1)));
    }
  }
  return null;
}

async function processOne(path) {
  let result;
  try {
    result = await fetchPath(path);
  } catch (error) {
    missing.push(`${path} (${error.message})`);
    return;
  }
  if (!result) {
    if (!/favicon|404\.html/.test(path)) missing.push(path);
    return;
  }
  const isHtml = result.type.includes('text/html');
  let finalPath = result.finalPath;
  if (isHtml && !finalPath.endsWith('/') && !/\.html?$/.test(finalPath)) finalPath += '/';
  let body = result.body;
  if (isHtml) {
    const html = body.toString('utf8').replaceAll(`${origin}/`, '/');
    scanHtml(html, finalPath);
    body = Buffer.from(html, 'utf8');
  } else if (/css/.test(result.type) || path.endsWith('.css')) {
    scanCss(body.toString('utf8'), finalPath);
  } else if (/javascript/.test(result.type) || /\.m?js$/.test(path)) {
    scanJs(body.toString('utf8'), finalPath);
  }
  files.set(storagePath(finalPath), body);
}

function zip(entries) {
  const locals = [];
  const centrals = [];
  let offset = 0;
  for (const [name, data] of entries) {
    const nameBuf = Buffer.from(name, 'utf8');
    const deflated = deflateRawSync(data, { level: 9 });
    const stored = deflated.length >= data.length;
    const payload = stored ? data : deflated;
    const crc = crc32(data);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0x0800, 6);
    local.writeUInt16LE(stored ? 0 : 8, 8);
    local.writeUInt32LE(0, 10);
    local.writeUInt32LE(crc >>> 0, 14);
    local.writeUInt32LE(payload.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(nameBuf.length, 26);
    local.writeUInt16LE(0, 28);
    locals.push(local, nameBuf, payload);
    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(0x0800, 8);
    central.writeUInt16LE(stored ? 0 : 8, 10);
    central.writeUInt32LE(0, 12);
    central.writeUInt32LE(crc >>> 0, 16);
    central.writeUInt32LE(payload.length, 20);
    central.writeUInt32LE(data.length, 24);
    central.writeUInt16LE(nameBuf.length, 28);
    central.writeUInt32LE(offset, 42);
    centrals.push(central, nameBuf);
    offset += 30 + nameBuf.length + payload.length;
  }
  const centralBuf = Buffer.concat(centrals);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(centralBuf.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, centralBuf, end]);
}

async function fetchText(url) {
  const res = await fetch(url);
  if (!res.ok) {
    console.error(`${url} answered HTTP ${res.status}; is the wiki up? Nothing was written.`);
    process.exit(1);
  }
  return res.text();
}

const sitemapIndex = await fetchText(`${origin}/sitemap-index.xml`);
for (const sitemap of [...sitemapIndex.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1])) {
  const xml = await fetchText(sitemap);
  for (const m of xml.matchAll(/<loc>([^<]+)<\/loc>/g)) enqueue(normalise(m[1], '/'));
}
for (const p of ['/', '/404.html', '/favicon.ico', '/favicon.svg']) enqueue(p);

let inFlight = 0;
await new Promise((resolve) => {
  const pump = () => {
    while (inFlight < 8 && queue.length) {
      const path = queue.shift();
      inFlight++;
      processOne(path).finally(() => {
        inFlight--;
        if (!queue.length && inFlight === 0) resolve();
        else pump();
      });
    }
    if (!queue.length && inFlight === 0) resolve();
  };
  pump();
});

if (!files.has("index.html")) {
  console.error("The home page did not download; nothing was written.");
  process.exit(1);
}

if (!files.has('index.html')) {
  console.error('The home page did not download; nothing was written.');
  process.exit(1);
}

const manifest = {
  origin,
  mirrored: new Date().toISOString(),
  pages: [...files.keys()].filter((k) => k.endsWith('.html')).length,
  files: files.size,
};
files.set('_luma_mirror.json', Buffer.from(JSON.stringify(manifest, null, 2)));
const entries = [...files.entries()].sort(([a], [b]) => a.localeCompare(b));
const archive = zip(entries);
await mkdir(dirname(outFile), { recursive: true });
await writeFile(outFile, archive);

const raw = entries.reduce((n, [, b]) => n + b.length, 0);
console.log(`${manifest.pages} pages, ${files.size} files, ${(raw / 1e6).toFixed(1)} MB raw → ${(archive.length / 1e6).toFixed(1)} MB zip`);
console.log(`wrote ${outFile}`);
if (missing.length) console.log(`missing (${missing.length}):\n  ${missing.join('\n  ')}`);
console.log(`external hosts referenced (blocked in the app): ${[...externalHosts].sort().join(', ')}`);
