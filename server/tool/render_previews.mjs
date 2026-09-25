import { execFile } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { promisify } from 'node:util';
import { PNG } from 'pngjs';
import puppeteer from 'puppeteer-core';

import { installShotControl } from './shot_control.mjs';

const execFileAsync = promisify(execFile);

// Renders PNG banners for benchmark scenes.
//
// The luma admin dashboard runs this in the background (see
// server/lib/preview_render.dart) to fill in missing banners or re-render
// every one; operators can also run it by hand after dropping new scenes in:
//
//   cd server/tool && npm install
//   node render_previews.mjs --root ../benchmarks --out <dataDir>/ai_benchmarks/previews
//
// Without --ids it renders only scenes that have no banner yet; --ids a,b,c
// renders exactly those, replacing what is there. --override <dir> is checked
// for the scene file (<id>.html or <id>.glb) and manifest.json before --root,
// mirroring the server's data-directory overlay.
//
// Cathedral GLBs are shown with model-viewer and its fitted default camera.
// Pagoda banners are all shot the same way however the scene was written:
// fast-forwarded to its brightest time of day, frozen there, and framed as
// the whole garden from an elevated three-quarter angle (see
// shot_control.mjs). Engine and PC scenes keep their own camera.
//
// Needs node + a headless Chromium. Chromium is found via --chromium-bin,
// $CHROMIUM_BIN, or well-known install paths. One scene at a time, one small
// tab, software WebGL — deliberately light so it can run beside the server.
//
// Prints one `START <id>` and one `OK   <id>` / `FAIL <id>: <reason>` line
// per scene; the server follows progress by those lines.

const W = 1120;
const H = 700;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function arg(name, fallback = null) {
  const i = process.argv.indexOf(`--${name}`);
  if (i >= 0 && i + 1 < process.argv.length) return process.argv[i + 1];
  const env = process.env[name.toUpperCase().replace(/-/g, '_')];
  return env ?? fallback;
}

async function findChromium(explicit) {
  const candidates = [
    explicit,
    process.env.CHROMIUM_BIN,
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  ].filter(Boolean);
  for (const c of candidates) {
    try {
      await fs.promises.access(c, fs.constants.X_OK);
      return c;
    } catch {
      // Next candidate. Edge on Windows lives under a versioned directory.
      if (c.endsWith('msedge.exe')) {
        const dir = path.dirname(c);
        try {
          const versions = (await fs.promises.readdir(dir, { withFileTypes: true }))
            .filter((d) => d.isDirectory() && /^\d+\./.test(d.name))
            .map((d) => d.name)
            .sort()
            .reverse();
          for (const v of versions) {
            const p = path.join(dir, v, 'msedge.exe');
            try {
              await fs.promises.access(p, fs.constants.X_OK);
              return p;
            } catch {
              // Keep looking.
            }
          }
        } catch {
          // No Edge directory at all.
        }
      }
    }
  }
  // Last resort: whatever `chromium`/`google-chrome` is on PATH.
  for (const bin of ['chromium', 'chromium-browser', 'google-chrome']) {
    try {
      const { stdout } = await execFileAsync(process.platform === 'win32' ? 'where' : 'which', [bin]);
      const p = stdout.split(/\r?\n/).map((s) => s.trim()).filter(Boolean)[0];
      if (p) return p;
    } catch {
      // Not on PATH.
    }
  }
  return null;
}

// Mean luminance (0–1) and its spread over a PNG. A spread near zero is a
// solid colour: a scene that never drew.
function lumaStats(buffer) {
  const png = PNG.sync.read(Buffer.from(buffer));
  const d = png.data;
  let sum = 0;
  let sq = 0;
  let n = 0;
  for (let i = 0; i < d.length; i += 4 * 3) {
    const l = (0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2]) / 255;
    sum += l;
    sq += l * l;
    n++;
  }
  const mean = sum / n;
  return { mean, spread: Math.sqrt(Math.max(0, sq / n - mean * mean)) };
}

// Brightness of the middle of the frame, where the framed garden sits, so a
// bright sky over an unlit garden (dusk, or a sun behind the pagoda) does
// not pass for daytime.
async function sampleLuma(page) {
  const buf = await page.screenshot({
    clip: { x: W * 0.3, y: H * 0.3, width: W * 0.4, height: H * 0.45, scale: 0.2 },
  });
  return lumaStats(buf);
}

// Whether the scene's canvas is what's on screen, rather than a loading or
// splash overlay drawn over it. Transparent HUD layers don't count as
// covering; only elements with a mostly opaque background do.
async function canvasVisible(page) {
  return page.evaluate(() => {
    const canvas = [...document.querySelectorAll('canvas')].sort(
      (a, b) => b.clientWidth * b.clientHeight - a.clientWidth * a.clientHeight,
    )[0];
    if (!canvas) return false;
    const opaque = (el) => {
      const s = getComputedStyle(el);
      if (s.visibility === 'hidden' || Number(s.opacity) < 0.5) return false;
      if (s.backgroundImage && s.backgroundImage !== 'none') return true;
      const m = s.backgroundColor.match(/rgba?\(([^)]+)\)/);
      if (!m) return false;
      const parts = m[1].split(',').map((x) => parseFloat(x));
      return parts.length < 4 || parts[3] > 0.5;
    };
    let covered = 0;
    for (const [fx, fy] of [[0.5, 0.5], [0.35, 0.62], [0.66, 0.4]]) {
      let el = document.elementFromPoint(innerWidth * fx, innerHeight * fy);
      while (el && el !== document.body && el !== document.documentElement) {
        if (el === canvas || el.contains(canvas)) break;
        if (opaque(el)) {
          covered++;
          break;
        }
        el = el.parentElement;
      }
    }
    return covered < 2;
  });
}

// Some scenes open on a "click to begin" splash.
async function pressStart(page) {
  return page.evaluate(() => {
    const b = [...document.querySelectorAll('button, [role=button], .start, #start')].find(
      (el) =>
        el.offsetParent !== null &&
        /^\s*(start|begin|enter|explore|play|enter the garden|begin journey)\b/i.test(el.textContent || ''),
    );
    if (b) b.click();
    return !!b;
  });
}

const warp = (page, on, maxSteps) =>
  page.evaluate((o, m) => window.__lumaShot && window.__lumaShot.setWarp(o, m), on, maxSteps);
const virtualMs = (page) => page.evaluate(() => (window.__lumaShot ? window.__lumaShot.virtualMs() : 0));

// Fast-forwards through the scene's day cycle to learn how bright its day
// gets, then on to the next moment that bright, and freezes time there.
// Scenes with no cycle stay where they are (their clock already reads late
// morning).
async function findDaylight(page) {
  await warp(page, true, 600);
  const v0 = await virtualMs(page);
  const t0 = Date.now();
  let lo = Infinity;
  let hi = -Infinity;
  while (Date.now() - t0 < 45000 && (await virtualMs(page)) - v0 < 8 * 60 * 1000) {
    await sleep(700);
    const { mean } = await sampleLuma(page);
    lo = Math.min(lo, mean);
    hi = Math.max(hi, mean);
  }
  const range = hi - lo;
  if (!(range > 0.05)) {
    await page.evaluate(() => window.__lumaShot.freeze());
    return `no day cycle (luma ${hi.toFixed(2)})`;
  }
  const target = lo + range * 0.92;
  const approach = lo + range * 0.5;
  const t1 = Date.now();
  let reached = false;
  let mean = lo;
  // From here time only moves in short bursts between samples, and stands
  // still while one is taken, so the moment that measured bright is the
  // moment that gets shot — not one a few fast-forwarded frames later, in
  // the dark.
  await page.evaluate(() => window.__lumaShot.freeze());
  while (Date.now() - t1 < 90000) {
    ({ mean } = await sampleLuma(page));
    if (mean >= target) {
      reached = true;
      break;
    }
    // Close in slowly once it's getting light, so a short day isn't
    // skipped between two samples.
    if (mean < approach) {
      await warp(page, true, 600);
      await sleep(700);
    } else {
      await warp(page, true, 60);
      await page.evaluate(() => window.__lumaShot.waitFrames(1));
    }
    await warp(page, false);
  }
  return reached
    ? `daylight at luma ${mean.toFixed(2)} (cycle ${lo.toFixed(2)}–${hi.toFixed(2)})`
    : `daylight not reached, best effort at ${mean.toFixed(2)} (cycle ${lo.toFixed(2)}–${hi.toFixed(2)})`;
}

// Pins the camera to a hand-set framing and lets a few frames draw it.
async function applyFraming(page, framing) {
  const used = await page.evaluate((f) => window.__lumaShot.useFraming(f), framing);
  if (!used.ok) throw new Error(`saved framing could not be applied: ${used.reason}`);
  await page.evaluate(() => window.__lumaShot.waitFrames(3));
  return used;
}

async function shootPagoda(page, framing) {
  // Hook shape varies per scene: voxelCount is a plain number in most
  // scenes, a function in a few older ones.
  await page
    .waitForFunction(
      `(() => { const v = window.__VOXEL__ && window.__VOXEL__.voxelCount; const n = typeof v === 'function' ? v() : v; return typeof n === 'number' && n > 1000; })()`,
      { timeout: 120000, polling: 500 },
    )
    .catch(() => {});
  const t0 = Date.now();
  let lastPress = 0;
  while (!(await canvasVisible(page))) {
    if (Date.now() - t0 > 90000) throw new Error('scene never got past its loading screen');
    if (Date.now() - lastPress > 4000) {
      lastPress = Date.now();
      await pressStart(page);
    }
    await sleep(1000);
  }
  // Let fade-outs finish, and fast-forward past build-up animations and
  // camera intros before reading the scene's framing.
  await warp(page, true, 600);
  await sleep(3000);
  await warp(page, false);
  if (framing) {
    // The operator's own shot: no fitting, no refit, just daylight.
    const used = await applyFraming(page, framing);
    console.log(`  framing: ${used.camera}`);
    console.log(`  ${await findDaylight(page)}`);
  } else {
    const framed = await page.evaluate(() => window.__lumaShot.frame());
    console.log(`  framing: ${framed.ok ? `${framed.camera}, distance ${framed.distance}, box ${framed.box}` : framed.reason}`);
    console.log(`  ${await findDaylight(page)}`);
    // Refit on the finished scene (same side, same angle) — some gardens
    // only fade in or finish building by now — and let a few real frames
    // draw it.
    const refit = await page.evaluate(() => window.__lumaShot.frame());
    if (!framed.ok) {
      console.log(`  reframing: ${refit.ok ? `${refit.camera}, distance ${refit.distance}, box ${refit.box}` : refit.reason}`);
    }
  }
  await page.evaluate(() => window.__lumaShot.waitFrames(3));
  // Some scenes fill their HUD counters on a frame timer — wait for real
  // numbers so the banner never shows "-- voxels".
  await page
    .waitForFunction(
      `(() => { const els = [...document.querySelectorAll('#stat,#voxel-count,#hudVox')]; return els.length === 0 || els.every(e => !e.textContent.includes('--')); })()`,
      { timeout: 15000, polling: 500 },
    )
    .catch(() => {});
  await sleep(1500);
}

async function shootEngine(page) {
  await page.waitForSelector('canvas', { timeout: 120000 });
  await sleep(5000);
}

async function shootPc(page) {
  // PC scenes are bespoke: the power control and the online indicator
  // differ per scene. The module scripts (and their click handlers) only
  // exist after the Three.js CDN imports resolve, so wait for the canvas
  // plus a margin before touching the power control.
  await page.waitForSelector('canvas', { timeout: 120000 });
  await sleep(3000);
  const clickPower = () =>
    page.evaluate(() => {
      const direct = ['#pwr', '#powerBtn', '#power-btn', '#btnPower', '#power']
        .map((sel) => document.querySelector(sel))
        .find(Boolean);
      if (direct) {
        direct.click();
        return true;
      }
      const byText = [...document.querySelectorAll('button')].find((b) =>
        /power|boot|⏻|⭘/i.test(b.textContent || b.title || ''),
      );
      if (byText) {
        byText.click();
        return true;
      }
      return false;
    });
  const isOnline = `(() => { const t = document.body.innerText; return t.includes('ONLINE') || t.includes('RUNNING') || t.includes('SYSTEM ON'); })()`;
  await clickPower();
  await sleep(4000);
  const online = await page
    .waitForFunction(isOnline, { timeout: 8000, polling: 500 })
    .then(() => true)
    .catch(() => false);
  if (!online) {
    await clickPower();
  }
  await page.waitForFunction(isOnline, { timeout: 60000, polling: 500 }).catch(() => {});
  await sleep(2000);
}

function readManifest(dirs) {
  for (const dir of dirs) {
    const file = path.join(dir, 'manifest.json');
    if (!fs.existsSync(file)) continue;
    try {
      return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
    } catch {
      // A broken override must not hide the seed roster.
    }
  }
  return { benchmarks: [] };
}

function cathedralViewerHtml(base64Glb) {
  return `<!doctype html>
<html><head><meta charset="utf-8">
<style>
  html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#11101a}
  model-viewer{display:block;width:100%;height:100%;--poster-color:transparent}
</style>
<script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer@3.5.0/dist/model-viewer.min.js"
  onerror="window.__lumaModelViewerScriptError='Could not load the model-viewer library from jsDelivr.'"></script>
</head><body>
<model-viewer id="model" camera-controls auto-rotate interaction-prompt="none"
  camera-orbit="35deg 70deg auto" shadow-intensity="1" environment-image="neutral"
  exposure="1" touch-action="pan-y"></model-viewer>
<script>
  window.__lumaGlbError = null;
  const model=document.getElementById('model');
  model.addEventListener('error', event => {
    const detail=event.detail || {};
    window.__lumaGlbError=detail.type || detail.message || 'model-viewer rejected the GLB';
  });
  const binary=atob('${base64Glb}'),bytes=new Uint8Array(binary.length);
  for(let i=0;i<binary.length;i++)bytes[i]=binary.charCodeAt(i);
  model.src=URL.createObjectURL(new Blob([bytes],{type:'model/gltf-binary'}));
</script></body></html>`;
}

function validateGlb(bytes, id) {
  if (bytes.length < 20 || bytes.toString('ascii', 0, 4) !== 'glTF') {
    throw new Error(`invalid GLB for ${id}: missing glTF header`);
  }
  if (bytes.readUInt32LE(4) !== 2) {
    throw new Error(`invalid GLB for ${id}: expected glTF version 2`);
  }
  const declaredLength = bytes.readUInt32LE(8);
  if (declaredLength !== bytes.length) {
    throw new Error(`invalid GLB for ${id}: header declares ${declaredLength} bytes, file has ${bytes.length}`);
  }
  if (bytes.readUInt32LE(16) !== 0x4e4f534a) {
    throw new Error(`invalid GLB for ${id}: first chunk is not JSON`);
  }
  const jsonLength = bytes.readUInt32LE(12);
  if (jsonLength > bytes.length - 20) {
    throw new Error(`invalid GLB for ${id}: JSON chunk exceeds the file size`);
  }
  try {
    JSON.parse(bytes.toString('utf8', 20, 20 + jsonLength).trim());
  } catch {
    throw new Error(`invalid GLB for ${id}: malformed JSON chunk`);
  }
}

async function main() {
  // Lowest scheduling priority, inherited by the browser it launches: a
  // banner render must never slow down the server or the desktop it runs on.
  try {
    os.setPriority(os.constants.priority.PRIORITY_LOW);
  } catch {
    // Not permitted here; render at normal priority.
  }
  const root = arg('root', '../benchmarks');
  const override = arg('override');
  const outDir = arg('out', path.join(root, 'previews'));
  const onlyIds = arg('ids');
  const only = onlyIds ? onlyIds.split(',').map((s) => s.trim()).filter(Boolean) : [];
  const manifest = readManifest([override, root].filter(Boolean));
  const kindOf = (id) =>
    manifest.benchmarks.find((x) => x.id === id)?.kind ??
    (id.startsWith('engine_') ? 'engine' : id.startsWith('pc_') ? 'pc' :
      id.startsWith('cathedral_') ? 'cathedral' : 'pagoda');
  const sceneExtension = (id) => (kindOf(id) === 'cathedral' ? 'glb' : 'html');
  const sceneFile = (id) => {
    const candidates = [
      override && path.join(override, `${id}.${sceneExtension(id)}`),
      path.join(root, 'scenes', `${id}.${sceneExtension(id)}`),
    ].filter(Boolean);
    return candidates.find((f) => fs.existsSync(f)) ?? null;
  };
  // A hand-set camera from the dashboard's framing editor, overlaid the
  // same way as scenes.
  const framingOf = (id) => {
    for (const dir of [override, root].filter(Boolean)) {
      const file = path.join(dir, 'framing', `${id}.json`);
      if (!fs.existsSync(file)) continue;
      try {
        const f = JSON.parse(fs.readFileSync(file, 'utf8'));
        if (['px', 'py', 'pz', 'qx', 'qy', 'qz', 'qw'].every((k) => Number.isFinite(f[k]))) return f;
      } catch {
        // Unreadable: frame automatically instead.
      }
    }
    return null;
  };
  const ids =
    only.length > 0
      ? only
      : manifest.benchmarks
          .map((b) => b.id)
          .filter((id) => !fs.existsSync(path.join(outDir, `${id}.png`)));
  if (ids.length === 0) {
    console.log('nothing to capture');
    return;
  }
  const chromium = await findChromium(arg('chromium-bin'));
  if (!chromium) {
    console.error('no headless Chromium found (tried $CHROMIUM_BIN, PATH and well-known paths)');
    process.exit(2);
  }
  console.log(`capturing ${ids.length} scenes with ${chromium}, one at a time`);
  await fs.promises.mkdir(outDir, { recursive: true });

  const launch = () => puppeteer.launch({
    executablePath: chromium,
    headless: true,
    protocolTimeout: 300000,
    args: [
      `--window-size=${W},${H}`,
      '--force-device-scale-factor=1',
      '--no-sandbox',
      '--disable-dev-shm-usage',
      '--mute-audio',
      '--enable-unsafe-swiftshader',
      '--use-angle=swiftshader',
      '--disable-background-timer-throttling',
      '--num-raster-threads=1',
      '--renderer-process-limit=1',
    ],
  });
  let browser = await launch();
  const failed = [];
  try {
    for (const id of ids) {
      console.log(`START ${id}`);
      const file = sceneFile(id);
      if (!file) {
        console.log(`FAIL ${id}: no scene file`);
        failed.push(id);
        continue;
      }
      const kind = kindOf(id);
      // A scene that crashes the browser takes only itself down.
      if (!browser.connected) {
        await browser.close().catch(() => {});
        browser = await launch();
      }
      let page = null;
      try {
        page = await browser.newPage();
        await page.setViewport({ width: W, height: H, deviceScaleFactor: 1 });
        const framing = framingOf(id);
        // Engine and PC scenes keep their own clock; with a saved framing
        // they get just the camera hook.
        if (kind === 'pagoda') await page.evaluateOnNewDocument(installShotControl);
        else if (framing) await page.evaluateOnNewDocument(installShotControl, { clock: false });
        if (kind === 'cathedral') {
          const glb = await fs.promises.readFile(file);
          validateGlb(glb, id);
          await page.setContent(cathedralViewerHtml(glb.toString('base64')),
            { waitUntil: 'domcontentloaded', timeout: 120000 });
          const modelLoad = await page.waitForFunction(
            `(() => {
              const m = document.querySelector('#model');
              if (window.__lumaModelViewerScriptError) return { error: window.__lumaModelViewerScriptError };
              if (window.__lumaGlbError) return { error: 'GLB load failed: ' + window.__lumaGlbError };
              return m && m.loaded ? { loaded: true } : false;
            })()`,
            { timeout: 120000, polling: 250 },
          );
          const loadResult = await modelLoad.jsonValue();
          if (loadResult.error) throw new Error(loadResult.error);
          await sleep(4000);
        } else {
          const url = (process.platform === 'win32' ? 'file:///' : 'file://') + path.resolve(file).replace(/\\/g, '/');
          await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
        }
        if (kind === 'pagoda') await shootPagoda(page, framing);
        else if (kind !== 'cathedral') {
          if (kind === 'engine') await shootEngine(page);
          else await shootPc(page);
          if (framing) console.log(`  framing: ${(await applyFraming(page, framing)).camera}`);
        }
        const png = await page.screenshot({ type: 'png' });
        const { spread } = lumaStats(png);
        if (spread < 0.02) throw new Error('blank frame (solid colour), keeping the old banner');
        // Write beside the target and rename, so the server never serves a
        // half-written banner.
        const target = path.join(outDir, `${id}.png`);
        await fs.promises.writeFile(`${target}.tmp`, png);
        await fs.promises.rename(`${target}.tmp`, target);
        console.log(`OK   ${id}`);
      } catch (e) {
        console.log(`FAIL ${id}: ${String(e).split('\n')[0]}`);
        failed.push(id);
      } finally {
        if (page) await page.close().catch(() => {});
        await sleep(1000);
      }
    }
  } finally {
    await browser.close().catch(() => {});
  }
  console.log(`done: ${ids.length - failed.length} ok, ${failed.length} failed`);
  if (failed.length > 0) console.log('failed: ' + failed.join(', '));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
