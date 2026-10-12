const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

test('a failed later Hoogvliet page logs failure without writing products or marking existing data unavailable', async () => {
  const writes = [];
  const finished = [];
  const models = {
    Supermarket: { findOrCreateBySlug: async () => ({ id: 4 }) },
    Product: {
      upsert: async () => writes.push('upsert'),
      markStaleAsUnavailable: async () => writes.push('markStale'),
    },
    SyncLog: {
      start: async () => 1,
      progress: async () => {},
      finish: async (_, status) => finished.push(status),
    },
  };
  const base = { module: { exports: {} }, console, require: () => models };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../src/supermarkets/baseSync.js'), 'utf8'), base);
  const sandbox = { module: { exports: {} }, URL, require: (id) => {
    if (id === '../baseSync') return base.module.exports;
    if (id === '../util') return { sleep: async () => {} };
    return {
      fetchCategories: async () => [{ name: 'Fruit', path: 'fruit' }],
      fetchCategoryPage: async ({ pageNumber }) => {
        if (pageNumber === 2) throw new Error('Hoogvliet: HTTP 503 on page 2');
        return { items: [{ sku: '1', name: 'Fruit', price_range: {
          minimum_price: { final_price: { value: 0.99 } },
        } }], totalPages: 2, total_count: 2 };
      },
    };
  } };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../src/supermarkets/hoogvliet/sync.js'), 'utf8'), sandbox);
  await assert.rejects(sandbox.module.exports.syncProducts(), /HTTP 503 on page 2/);
  assert.deepEqual(writes, []);
  assert.equal(finished.length, 1);
  assert.equal(finished[0].status, 'failed');
  assert.equal(sandbox.module.exports.isRunning, false);
});

test('an exhausted AH page failure aborts the sync without replacing products or marking them unavailable', async () => {
  const writes = [];
  const finished = [];
  const models = {
    Supermarket: { findOrCreateBySlug: async () => ({ id: 2 }) },
    Product: {
      upsert: async () => { writes.push('upsert'); return { id: 1, wasInserted: false }; },
      markStaleAsUnavailable: async () => writes.push('markStale'),
    },
    ProductPrice: { findLatestByProductId: async () => null, create: async () => {} },
    SyncLog: { start: async () => 1, progress: async () => {}, finish: async (_, status) => finished.push(status) },
  };
  const base = { module: { exports: {} }, console, require: () => models };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../src/supermarkets/baseSync.js'), 'utf8'), base);
  const sandbox = { module: { exports: {} }, console: { error() {} }, require: (id) => {
    if (id === '../baseSync') return base.module.exports;
    if (id === '../util') return { sleep: async () => {}, stripHtml: value => value };
    return {
      fetchCategories: async () => [{ id: 1, name: 'Fruit' }],
      searchProducts: async ({ page }) => {
        if (page === 1) throw new Error('AH request failed: HTTP 503 after retries');
        return { products: [{ webshopId: 1, title: 'Fruit', currentPrice: 0.99 }], page: { totalPages: 2 } };
      },
    };
  } };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../src/supermarkets/ah/sync.js'), 'utf8'), sandbox);
  await assert.rejects(sandbox.module.exports.syncProducts(), /HTTP 503 after retries/);
  assert.deepEqual(writes, []);
  assert.equal(finished[0].status, 'failed');
  assert.equal(sandbox.module.exports.isRunning, false);
});
