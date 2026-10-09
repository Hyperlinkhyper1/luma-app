const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const express = require('express');
const service = require('../src/services/syncService');

test('admin all-market POST starts all four, and individual POST conflicts while active', async () => {
  const started = [];
  const completions = [];
  const originals = new Map();
  for (const slug of service.slugs) {
    const module = service.getModule(slug);
    originals.set(module, module.syncProducts);
    module.syncProducts = () => {
      started.push(slug);
      return new Promise((resolve) => completions.push(resolve));
    };
  }
  const sandbox = { module: { exports: {} }, console,
    __dirname: path.join(__dirname, '../src/api'), require: (id) => {
    if (id === '../services/syncService') return service;
    if (id === '../config/env') return { adminKey: 'regression-test-key' };
    if (id === '../models' || id === '../database/connection') return {};
    return require(id);
  } };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../src/api/admin.js'), 'utf8'), sandbox);
  const app = express();
  sandbox.module.exports.registerAdminRoutes(app);
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  const url = `http://127.0.0.1:${server.address().port}/admin/sync`;
  const headers = { 'x-admin-key': 'regression-test-key', 'content-type': 'application/x-www-form-urlencoded' };
  try {
    const all = await fetch(url, { method: 'POST', headers, body: '' });
    assert.equal(all.status, 202);
    assert.deepEqual(started, ['jumbo', 'ah', 'lidl', 'hoogvliet']);
    const duplicate = await fetch(url, { method: 'POST', headers, body: 'market=hoogvliet' });
    assert.equal(duplicate.status, 409);
    assert.equal(started.length, 4);
  } finally {
    for (const complete of completions) complete({ checked: 1 });
    await new Promise(setImmediate);
    for (const [module, original] of originals) module.syncProducts = original;
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
});
