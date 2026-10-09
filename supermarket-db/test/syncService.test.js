const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

function serviceWith(modules) {
  const sandbox = { module: { exports: {} }, require: (id) => modules[id.split('/').at(-2)] };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../src/services/syncService.js'), 'utf8'), sandbox);
  return sandbox.module.exports;
}

test('all four markets start even while Jumbo is pending; failures stay isolated', async () => {
  const started = [];
  let finishJumbo;
  const modules = Object.fromEntries(['jumbo', 'ah', 'lidl', 'hoogvliet'].map((slug) => [slug, {
    syncProducts: () => {
      started.push(slug);
      if (slug === 'jumbo') return new Promise((resolve) => { finishJumbo = resolve; });
      if (slug === 'ah') return Promise.reject(new Error('AH unavailable'));
      return Promise.resolve({ checked: 10 });
    },
  }]));
  const service = serviceWith(modules);
  const run = service.syncAll();
  await new Promise(setImmediate);
  try {
    assert.deepEqual(started, ['jumbo', 'ah', 'lidl', 'hoogvliet']);
    assert.equal(service.isRunning('jumbo'), true);
  } finally {
    finishJumbo({ checked: 5 });
  }
  const results = await run;
  assert.equal(results.ah.error, 'AH unavailable');
  assert.equal(results.hoogvliet.checked, 10);
  assert.equal(service.isRunning('jumbo'), false);
});

test('individual sync reserves its market before asynchronous initialization', async () => {
  let finish;
  let calls = 0;
  const service = serviceWith({ jumbo: { syncProducts: () => {
    calls += 1;
    return new Promise((resolve) => { finish = resolve; });
  } } });
  const run = service.syncOne('jumbo');
  await assert.rejects(service.syncOne('jumbo'), /already running/);
  assert.equal(service.isRunning('jumbo'), true);
  assert.equal(calls, 1);
  finish({ checked: 1 });
  await run;
  assert.equal(service.isRunning('jumbo'), false);
});
