import puppeteer from 'puppeteer-core';
import { isolatePage, sceneUrl } from './renderer_network.mjs';
import fs from 'node:fs';
import { PNG } from 'pngjs';

const browser = await puppeteer.launch({
  executablePath: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  headless: 'new',
  args: ['--no-sandbox', '--disable-gpu']
});

const page = await browser.newPage();
page.on('console', msg => console.log('PAGE LOG:', msg.text()));
page.on('pageerror', err => console.log('PAGE ERROR:', err.message));

const html = fs.readFileSync('C:/Users/ayden/Files/Intellij-Programs/Luma-App-Benchmarks/scenes/butterfly_knife_ernie_55_flash_preview_high.html', 'utf8');
await isolatePage(page, html);
await page.goto(sceneUrl, { waitUntil: 'load' });
await new Promise(r => setTimeout(r, 6000));

const buf = await page.screenshot();
fs.writeFileSync('./knife_shot.png', buf);

const png = PNG.sync.read(buf);
const d = png.data;
let sum = 0, sq = 0, n = 0;
for (let i = 0; i < d.length; i += 4 * 3) {
  const l = (0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2]) / 255;
  sum += l; sq += l * l; n++;
}
const mean = sum / n;
const spread = Math.sqrt(Math.max(0, sq / n - mean * mean));
console.log('Mean:', mean, 'Spread:', spread);

await browser.close();
