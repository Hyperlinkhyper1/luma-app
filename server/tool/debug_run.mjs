import puppeteer from 'puppeteer-core';
import { isolatePage, sceneUrl } from './renderer_network.mjs';
import fs from 'node:fs';

const id = process.argv[2] || 'sports_car_ernie_55_flash_preview_xhigh';
const browser = await puppeteer.launch({
  executablePath: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  headless: 'new',
  args: ['--no-sandbox', '--disable-gpu']
});

const page = await browser.newPage();
page.on('console', msg => console.log('PAGE LOG:', msg.text()));
page.on('pageerror', err => console.log('PAGE ERROR:', err.message));
page.on('requestfailed', r => console.log('REQ FAILED:', r.url(), r.failure()?.errorText));

const html = fs.readFileSync(`C:/Users/ayden/Files/Intellij-Programs/Luma-App-Benchmarks/scenes/${id}.html`, 'utf8');
await isolatePage(page, html);
await page.goto(sceneUrl, { waitUntil: 'load' });

const info = await page.evaluate(() => {
  const canvas = document.querySelector('canvas');
  const points = [[0.5, 0.5], [0.35, 0.62], [0.66, 0.4]].map(([x, y]) => {
    const el = document.elementFromPoint(innerWidth * x, innerHeight * y);
    return { x, y, tag: el?.tagName, id: el?.id, className: el?.className };
  });
  return { hasCanvas: !!canvas, width: canvas?.width, height: canvas?.height, points };
});

console.log('Evaluated:', JSON.stringify(info, null, 2));
await browser.close();
