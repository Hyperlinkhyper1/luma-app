const { test } = require('node:test');
const assert = require('node:assert/strict');
const client = require('../src/supermarkets/hoogvliet/hoogvlietClient');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

function syncWith(listings) {
  const sandbox = { module: { exports: {} }, URL, require: (id) => {
    if (id === '../baseSync') return class { async reportProgress() {} };
    if (id === '../util') return { sleep: async () => {} };
    return {
      fetchCategories: async () => [{ name: 'Fruit', path: 'fruit' }],
      fetchCategoryPage: async ({ pageNumber }) => listings[pageNumber - 1],
    };
  } };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../src/supermarkets/hoogvliet/sync.js'), 'utf8'), sandbox);
  return sandbox.module.exports;
}

const product = (sku) => ({ sku, name: 'Komkommer', product_link: '/product/komkommer-' + sku,
  gtin13: '8715817810071', brand: { value: 'Hoogvliet' },
  price_range: { minimum_price: { regular_price: { value: 1.29 }, final_price: { value: 0.99 } } },
});

function response(props) {
  return { ok: true, text: async () => `<script id="__NEXT_DATA__" type="application/json">${JSON.stringify({ props: { pageProps: props } })}</script>` };
}

test('discovers current storefront categories and reads page 2 with structured prices', async () => {
  const categories = await client.fetchCategories(async (url) => {
    assert.equal(new URL(url).pathname, '/producten');
    assert.ok(new URL(url).searchParams.has('_luma_sync'));
    return response({ entity: { children: [{ name: 'Fruit', url_path: 'fruit' }] } });
  });
  assert.equal(categories[0].path, 'fruit');
  const listing = await client.fetchCategoryPage({ path: 'fruit', pageNumber: 2 }, async (url) => {
    assert.equal(new URL(url).pathname, '/fruit/q/page/2');
    assert.ok(new URL(url).searchParams.has('_luma_sync'));
    return response({ fallbackData: JSON.stringify({ items: [{ sku: '064786000', name: 'Komkommer', price_range: {
      minimum_price: { regular_price: { value: 1.29 }, final_price: { value: 0.99 } },
    } }], page: 2, totalPages: 3, total_count: 41 }) });
  });
  assert.equal(listing.items[0].sku, '064786000');
  assert.equal(listing.totalPages, 3);
});

test('rejects changed markup, missing pages and invalid pagination instead of returning an empty catalogue', async () => {
  await assert.rejects(client.fetchCategories(async () => ({ ok: true, text: async () => '<html>Blocked</html>' })), /Hoogvliet/);
  await assert.rejects(client.fetchCategoryPage({ path: 'fruit', pageNumber: 2 }, async () => response({
    fallbackData: JSON.stringify({ items: [], page: 1, totalPages: 3 }),
  })), /Hoogvliet/);
});

test('retries an intermittent empty or stale page and accepts only a complete response', async () => {
  let calls = 0;
  const listing = await client.fetchCategoryPage({ path: 'fruit', pageNumber: 2, expectedTotal: 41 }, async () => {
    calls += 1;
    if (calls === 1) return response({ fallbackData: JSON.stringify({ items: [], page: 2, totalPages: 0, total_count: 0 }) });
    if (calls === 2) return response({ fallbackData: JSON.stringify({ items: [product('1')], page: 2, totalPages: 3, total_count: 12 }) });
    return response({ fallbackData: JSON.stringify({ items: [product('2')], page: 2, totalPages: 3, total_count: 41 }) });
  });
  assert.equal(calls, 3);
  assert.equal(listing.items[0].sku, '2');
});

test('crawls every declared page and maps SKU, barcode and current versus regular price', async () => {
  const sync = syncWith([
    { items: [product('064786000')], totalPages: 2, total_count: 2 },
    { items: [product('674644000')], totalPages: 2, total_count: 2 },
  ]);
  const products = await sync.fetchProducts();
  assert.equal(products.length, 2);
  assert.equal(products[0].external_id, '064786000');
  assert.equal(products[0].price, 0.99);
  assert.equal(products[0].old_price, 1.29);
  assert.equal(products[0].barcode, '8715817810071');
  assert.equal(products[0].product_url, 'https://hoogvliet.nl/product/komkommer-064786000');
});

test('aborts partial or repeated pages before passing products to stale cleanup', async () => {
  await assert.rejects(syncWith([
    { items: [product('1')], totalPages: 2, total_count: 2 },
    { items: [product('1')], totalPages: 2, total_count: 2 },
  ]).fetchProducts(), /repeated catalogue page/);
  await assert.rejects(syncWith([
    { items: [product('1')], totalPages: 1, total_count: 2 },
  ]).fetchProducts(), /incomplete fruit catalogue/);
  await assert.rejects(syncWith([
    { items: [{ sku: '1', name: 'Missing price' }], totalPages: 1, total_count: 1 },
  ]).fetchProducts(), /invalid product/);
  await assert.rejects(syncWith([
    { items: [product('1')], totalPages: 2, total_count: 2 },
    { items: [product('2')], totalPages: 2, total_count: 3 },
  ]).fetchProducts(), /count changed from 2 to 3 on page 2/);
});
