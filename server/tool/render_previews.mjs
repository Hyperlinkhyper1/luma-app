import { execFile } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { promisify } from 'node:util';
import puppeteer from 'puppeteer-core';

const execFileAsync = promisify(execFile);

// Renders PNG banners for benchmark scenes that don't have one yet.
//
// The luma server notices missing previews on its own (see
// server/lib/preview_render.dart) and runs this script in the background;
// operators can also run it by hand after dropping new scenes in:
//
//   cd server/tool && npm install
//   node render_previews.mjs --root ../benchmarks --out <dataDir>/ai_benchmarks/previews
//
// Needs node + a headless Chromium. Chromium is found via --chromium-bin,
// $CHROMIUM_BIN, or well-known install paths. One scene at a time, one small
// tab, software WebGL — deliberately light so it can run beside the server.

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

async function readyFor(page, kind) {
  if (kind === 'pagoda') {
    // Hook shape varies per scene: voxelCount is a plain number in most
    // scenes, a function in a few older ones.
    await page.waitForFunction(
      `(() => { const v = window.__VOXEL__ && window.__VOXEL__.voxelCount; const n = typeof v === 'function' ? v() : v; return typeof n === 'number' && n > 1000; })()`,
      { timeout: 120000, polling: 500 },
    );
    await sleep(2500);
    // Some scenes fill their HUD counters on a frame timer, which ticks
    // slowly under software rendering — wait for real numbers so the banner
    // never shows "-- voxels".
    await page
      .waitForFunction(
        `(() => { const els = [...document.querySelectorAll('#stat,#voxel-count,#hudVox')]; return els.length > 0 && els.every(e => !e.textContent.includes('--')); })()`,
        { timeout: 20000, polling: 500 },
      )
      .catch(() => {});
    // Many scenes open with a ~2.5s camera intro driven by accumulated frame
    // time. Under software rendering frames are slow, so the intro stretches
    // over many real seconds — measure the actual frame rate and wait out the
    // intro adaptively instead of screenshotting mid-flight through a roof.
    const fps = await page.evaluate(
      `new Promise((res) => { let c = 0; const t0 = performance.now(); const tick = () => { if (performance.now() - t0 > 2000) res(c / 2); else { c++; requestAnimationFrame(tick); } }; requestAnimationFrame(tick); })`,
    );
    const settle = Math.min(90000, Math.max(4000, 65000 / Math.max(0.5, fps)));
    console.log(`  fps~${Number(fps).toFixed(1)} settling ${(settle / 1000).toFixed(0)}s`);
    await sleep(settle);
  } else if (kind === 'engine') {
    await page.waitForSelector('canvas', { timeout: 120000 });
    await sleep(5000);
  } else {
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
    await clickPower();
    await sleep(4000);
    const online = await page
      .waitForFunction(
        `(() => { const t = document.body.innerText; return t.includes('ONLINE') || t.includes('RUNNING') || t.includes('SYSTEM ON'); })()`,
        { timeout: 8000, polling: 500 },
      )
      .then(() => true)
      .catch(() => false);
    if (!online) {
      await clickPower();
    }
    await page
      .waitForFunction(
        `(() => { const t = document.body.innerText; return t.includes('ONLINE') || t.includes('RUNNING') || t.includes('SYSTEM ON'); })()`,
        { timeout: 60000, polling: 500 },
      )
      .catch(() => {});
    await sleep(2000);
  }
}

async function main() {
  const root = arg('root', '../benchmarks');
  const outDir = arg('out', path.join(root, 'previews'));
  const onlyIds = arg('ids');
  const only = new Set(
    onlyIds ? onlyIds.split(',').map((s) => s.trim()).filter(Boolean) : [],
  );
  const manifest = JSON.parse(
    fs.readFileSync(path.join(root, 'manifest.json'), 'utf8').replace(/^\uFEFF/, ''),
  );
  const kindOf = (id) => manifest.benchmarks.find((x) => x.id === id)?.kind ?? 'pagoda';
  const ids = manifest.benchmarks
    .map((b) => b.id)
    .filter((id) => {
      if (only.size > 0) return only.has(id);
      return !fs.existsSync(path.join(outDir, `${id}.png`));
    });
  if (ids.length === 0) {
    console.log('nothing to capture');
    return;
  }
  const chromium = await findChromium(arg('chromium-bin'));
  if (!chromium) {
    console.error(
      'no headless Chromium found (tried $CHROMIUM_BIN, PATH and well-known paths)',
    );
    process.exit(2);
  }
  console.log(`capturing ${ids.length} scenes with ${chromium}, one at a time`);
  await fs.promises.mkdir(outDir, { recursive: true });

  const browser = await puppeteer.launch({
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
    ],
  });
  const failed = [];
  try {
    for (const id of ids) {
      const page = await browser.newPage();
      try {
        await page.setViewport({ width: W, height: H, deviceScaleFactor: 1 });
        const sceneFile = path.join(root, 'scenes', `${id}.html`);
        const url = (process.platform === 'win32' ? 'file:///' : 'file://') +
          sceneFile.replace(/\\/g, '/');
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
        await readyFor(page, kindOf(id));
        await page.screenshot({ path: path.join(outDir, `${id}.png`) });
        console.log(`OK   ${id}`);
      } catch (e) {
        console.log(`FAIL ${id}: ${String(e).split('\n')[0]}`);
        failed.push(id);
      } finally {
        await page.close().catch(() => {});
        await sleep(1000);
      }
    }
  } finally {
    await browser.close();
  }
  console.log(`done: ${ids.length - failed.length} ok, ${failed.length} failed`);
  if (failed.length > 0) console.log('failed: ' + failed.join(', '));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
