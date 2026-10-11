import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import puppeteer from 'puppeteer-core';
import { PNG } from 'pngjs';

const ids = process.argv.slice(2);
assert.ok(ids.length, 'Pass the scene IDs to verify');
const output = process.env.BENCHMARK_REPAIR_OUTPUT || await fs.mkdtemp(path.join(os.tmpdir(), 'luma-scene-check-'));
await fs.mkdir(output, { recursive: true });
console.log(`Screenshots: ${output}`);
const browser = await puppeteer.launch({
  executablePath: process.env.CHROMIUM_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  headless: true,
  args: ['--no-sandbox', '--allow-file-access-from-files', '--enable-unsafe-swiftshader', '--use-angle=swiftshader'],
});
let failures = 0;
try {
  for (const id of ids) {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', error => {
      if (!errors.includes(error.message)) {
        errors.push(error.message);
        console.log(`${id}: ${error.stack}`);
      }
    });
    page.on('console', message => {
      if (message.type() === 'error' && !errors.includes(message.text())) {
        errors.push(message.text());
        console.log(`${id}: ${message.text()} ${JSON.stringify(message.stackTrace())}`);
      }
    });
    page.on('requestfailed', request => errors.push(`${request.url()}: ${request.failure()?.errorText}`));
    await page.setViewport({ width: 1120, height: 700 });
    await page.evaluateOnNewDocument(() => {
      window.__benchmarkDraws = 0;
      for (const type of [WebGLRenderingContext, WebGL2RenderingContext]) {
        for (const name of ['drawArrays', 'drawElements', 'drawArraysInstanced', 'drawElementsInstanced']) {
          const original = type.prototype[name];
          if (!original) continue;
          type.prototype[name] = function (...args) {
            window.__benchmarkDraws++;
            return original.apply(this, args);
          };
        }
      }
    });
    try {
      await page.goto(pathToFileURL(path.resolve(`server/benchmarks/scenes/${id}.html`)).href,
        { waitUntil: 'domcontentloaded', timeout: 30000 });
      await page.waitForFunction(() => window.__benchmarkDraws > 0 ||
        [...document.querySelectorAll('svg path, svg circle, svg rect, svg polygon')]
          .some(node => node.getBoundingClientRect().width > 20), { timeout: 20000 });
      await new Promise(resolve => setTimeout(resolve, 2000));
      if (id === 'train_world_north_mini_code_high') {
        await page.click('#howto-close');
        await page.click('#pause');
        assert.equal(await page.$eval('#pause', node => node.textContent), 'Resume');
        await page.click('#pause');
        await page.click('#toggleUI');
        await page.click('#toggleUI');
      }
      if (id === 'keyboard_mistral_nemo') {
        await page.click('#replay');
        await page.click('#mute');
        await page.keyboard.press('a');
        await page.keyboard.press('Enter');
        await page.keyboard.press('F1');
      }
      if (id === 'world_timeline_mistral_nemo') {
        await page.click('#play-pause');
        const position = await page.$eval('#playhead', node => node.style.left);
        await page.click('#speed-2');
        await new Promise(resolve => setTimeout(resolve, 250));
        assert.equal(await page.$eval('#playhead', node => node.style.left), position);
        await page.mouse.click(1120 * 0.55, 680);
        assert.equal(await page.$eval('#era-title', node => node.textContent), 'Life flourishes');
        await page.click('#restart');
        assert.equal(await page.$eval('#era-title', node => node.textContent), 'The universe begins');
      }
      if (id === 'galaxy_mistral_nemo') {
        await page.click('#playPause');
        await page.click('#playPause');
        await page.click('#galaxyMap');
        await page.click('#cinematic');
      }
      await new Promise(resolve => setTimeout(resolve, 1000));
      const text = await page.evaluate(() => document.body.innerText);
      assert.ok(!/\b(loading|generating|initializing|building)\b[^\n]{0,60}(\.\.\.|…)/i.test(text), 'Loading overlay remains visible');
      let spread = 0;
      for (let attempt = 0; attempt < 15 && spread <= 0.02; attempt++) {
        const png = PNG.sync.read(Buffer.from(await page.screenshot({ clip: { x: 168, y: 105, width: 784, height: 490 } })));
        let sum = 0, squared = 0, count = 0;
        for (let i = 0; i < png.data.length; i += 16) {
          const luma = (png.data[i] + png.data[i + 1] + png.data[i + 2]) / 765;
          sum += luma; squared += luma * luma; count++;
        }
        spread = Math.sqrt(squared / count - (sum / count) ** 2);
        if (spread <= 0.02) await new Promise(resolve => setTimeout(resolve, 1000));
      }
      assert.ok(spread > 0.02, 'Blank scene frame');
      await page.screenshot({ path: path.join(output, `${id}.png`) });
      const state = await page.evaluate(() => ({ draws: window.__benchmarkDraws,
        text: document.body.innerText.slice(0, 500) }));
      assert.deepEqual(errors, [], 'Scene errors');
      console.log(`PASS ${id} ${JSON.stringify(state)}`);
    } catch (error) {
      failures++;
      console.log(`FAIL ${id}: ${error.message} ${JSON.stringify(errors)}`);
      await page.screenshot({ path: path.join(output, `${id}.png`) }).catch(() => {});
    } finally { await page.close(); }
  }
} finally { await browser.close(); }
process.exitCode = failures ? 1 : 0;
