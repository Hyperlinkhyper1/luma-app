import puppeteer from 'puppeteer-core';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const exe = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\153.0.4234.48\\msedge.exe';
const browser = await puppeteer.launch({
  executablePath: exe,
  headless: true,
  pipe: true,
  args: ['--no-sandbox', '--window-size=1400,950','--enable-unsafe-swiftshader', '--use-angle=swiftshader'],
});
const page = await browser.newPage();
await page.setViewport({ width: 1400, height: 950 });
const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
await page.goto('http://localhost:8131/admin?key=local-admin-key', { waitUntil: 'load' });
await page.evaluate(() => document.getElementById('bannersCatalogBtn').click());
await page.waitForFunction(() => document.querySelectorAll('.bn-tile').length > 0);
await page.screenshot({ path: process.argv[2] + '/catalog.png' });
await page.evaluate(() => document.querySelector('[data-frame="pagoda_haiku45"]').click());
const t0 = Date.now();
await page.waitForFunction(() => !document.getElementById('bnFrameSave').disabled, { timeout: 120000 });
console.log('framer ready after', Date.now() - t0, 'ms');
await sleep(3000);
await page.screenshot({ path: process.argv[2] + '/framer_before.png' });
const box = await (await page.$('#bnStage')).boundingBox();
console.log('stage', JSON.stringify(box), 'transform', await page.$eval('#bnSceneFrame', (f) => f.style.transform));
// Orbit: drag across the stage.
await page.mouse.move(box.x + box.width * 0.5, box.y + box.height * 0.5);
await page.mouse.down();
for (let i = 1; i <= 20; i++) {
  await page.mouse.move(box.x + box.width * (0.5 - i * 0.012), box.y + box.height * (0.5 - i * 0.006));
  await sleep(30);
}
await page.mouse.up();
await page.mouse.wheel({ deltaY: -300 });
await sleep(1500);
await page.screenshot({ path: process.argv[2] + '/framer_after.png' });
// Auto preview round-trip.
await page.evaluate(() => document.querySelector('#bnViewModes [data-mode="auto"]').click());
await sleep(2500);
console.log('auto status:', await page.$eval('#bnFrameStatus', (e) => e.textContent));
await page.screenshot({ path: process.argv[2] + '/framer_auto.png' });
await page.evaluate(() => document.querySelector('#bnViewModes [data-mode="live"]').click());
await sleep(1000);
await page.evaluate(() => document.getElementById('bnFrameSave').click());
await page.waitForFunction(() => !document.getElementById('bnFramer').open, { timeout: 20000 });
console.log('note:', await page.$eval('#bnSelCount', (e) => e.textContent));
await sleep(4000);
console.log('progress:', await page.$eval('#bannersProgressLabel', (e) => e.textContent), '|', await page.$eval('#bannersProgressEta', (e) => e.textContent), '| bar', await page.$eval('#bannersBar', (e) => e.getAttribute('aria-valuenow')));
await page.evaluate(() => document.getElementById('bnCatalog').close());
await page.evaluate(() => document.querySelector('[data-tab="control"]').click());
await page.evaluate(() => document.getElementById('bannersProgress').scrollIntoView({ block: 'center' }));
await sleep(1000);
await page.screenshot({ path: process.argv[2] + '/progress.png' });
const tEnd = Date.now() + 240000;
while (Date.now() < tEnd) {
  const st = await page.evaluate(() => fetch('/admin/benchmark-banners/status').then((r) => r.json()));
  if (!st.running) { console.log('job:', JSON.stringify(st.items), st.error || ''); console.log(st.log.join(' / ')); break; }
  await sleep(3000);
}
await sleep(3500);
console.log('final progress:', await page.$eval('#bannersProgressLabel', (e) => e.textContent), '|', await page.$eval('#bannersProgressEta', (e) => e.textContent));
await page.evaluate(() => document.getElementById('bannersProgress').scrollIntoView({ block: 'center' }));
await page.screenshot({ path: process.argv[2] + '/progress_done.png' });
await page.evaluate(() => document.getElementById('bannersCatalogBtn').click());
await page.evaluate(() => { document.getElementById('bnFramedOnly').click(); });
await sleep(1500);
await page.screenshot({ path: process.argv[2] + '/catalog_after.png' });
await page.evaluate(() => { document.getElementById('bnFramedOnly').click(); document.querySelector('#bnKinds [data-kind="pagoda"]').click(); });
await sleep(1500);
await page.screenshot({ path: process.argv[2] + '/catalog_pagoda.png' });
console.log('errors:', JSON.stringify(errors.slice(0, 8)));
await browser.close();
