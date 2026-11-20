// usage: node render.mjs stills t1,t2,...   |   node render.mjs video
import { createRequire } from 'module';
import { spawn } from 'child_process';
import path from 'path';
import fs from 'fs';
const require = createRequire('C:/Users/ayden/Downloads/luma-app/server/tool/package.json');
const puppeteer = require('puppeteer-core');

const OUT = 'C:/Users/ayden/Downloads/luma-app/brag-output';
const FFMPEG = process.env.APPDATA + '/com.luma/luma/tools/ffmpeg.exe';
const FPS = 30;
const mode = process.argv[2];

const browser = await puppeteer.launch({
  executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  headless: true,
  args: ['--force-device-scale-factor=1', '--hide-scrollbars', '--font-render-hinting=none'],
});
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
await page.goto('file:///' + OUT + '/composition/index.html', { waitUntil: 'networkidle0' });
await page.evaluate(() => window.ready);

if (mode === 'stills') {
  fs.mkdirSync(OUT + '/work/stills', { recursive: true });
  for (const t of process.argv[3].split(',').map(Number)) {
    await page.evaluate(t => window.render(t), t);
    await page.screenshot({ path: `${OUT}/work/stills/t${t.toFixed(2)}.jpg`, type: 'jpeg', quality: 85 });
  }
} else {
  const ff = spawn(FFMPEG, ['-y', '-v', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '16', '-pix_fmt', 'yuv420p', '-r', String(FPS), OUT + '/work/video_only.mp4'], { stdio: ['pipe', 'inherit', 'inherit'] });
  const DUR = await page.evaluate(() => window.DURATION); fs.writeFileSync(OUT + "/work/clicks.json", JSON.stringify(await page.evaluate(() => window.CLICKS))); const N = Math.round(FPS * DUR);
  for (let i = 0; i < N; i++) {
    await page.evaluate(t => window.render(t), i / FPS);
    const buf = await page.screenshot({ type: 'jpeg', quality: 95 });
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
    if (i % 60 === 0) console.log('frame', i);
  }
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
}
await browser.close();
