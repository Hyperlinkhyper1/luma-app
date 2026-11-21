const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const src = (file) => path.join(__dirname, '../src', file);

function stub(file, exports) {
  const id = require.resolve(src(file));
  require.cache[id] = { id, filename: id, loaded: true, exports };
}

// A fake AH category. Like the real API it refuses any page starting at or
// past result 3000, and supports the two price orders the sync reads from.
let catalogue = [];
let searches = [];
let ignoreSort = false;

function search({ page, size, sortOn }) {
  searches.push({ page, sortOn });
  if (page * size >= 3000) throw Object.assign(new Error('HTTP 400 [400] during [GET]'), { status: 400 });
  let ordered = catalogue;
  if (!ignoreSort && sortOn === 'PRICELOWHIGH') ordered = [...catalogue].sort((a, b) => a.price - b.price);
  if (!ignoreSort && sortOn === 'PRICEHIGHLOW') ordered = [...catalogue].sort((a, b) => b.price - a.price);
  const products = ordered.slice(page * size, page * size + size)
    .map(({ id, price }) => ({ webshopId: id, title: `p${id}`, currentPrice: price, images: [] }));
  return {
    page: { size, totalElements: catalogue.length, totalPages: Math.ceil(catalogue.length / size), number: page },
    products,
  };
}

function makeCatalogue(count) {
  return Array.from({ length: count }, (_, id) => ({ id, price: (id * 7919) % 1000 }));
}

stub('models/index.js', {});
stub('supermarkets/util.js', { sleep: async () => {}, stripHtml: (s) => s || null });
stub('supermarkets/ah/ahClient.js', {
  fetchCategories: async () => [{ id: 6409, name: 'Soepen, sauzen, kruiden, olie' }],
  searchProducts: async (params) => search(params),
});
const ahSync = require(src('supermarkets/ah/sync.js'));
ahSync.reportProgress = async () => {};

test('a category within the 3000-result window is paged in the default order', async () => {
  catalogue = makeCatalogue(250);
  searches = [];
  ignoreSort = false;
  const products = await ahSync.fetchProducts();
  assert.equal(products.length, 250);
  assert.deepEqual(searches.map((s) => s.sortOn), [undefined, undefined, undefined]);
});

test('a category past the 3000-result window is read from both price ends', async () => {
  catalogue = makeCatalogue(3323);
  searches = [];
  ignoreSort = false;
  const products = await ahSync.fetchProducts();
  assert.equal(products.length, 3323);
  assert.ok(searches.every(({ page }) => page * 100 < 3000), 'never asks past the window');
  assert.ok(searches.some((s) => s.sortOn === 'PRICEHIGHLOW'));
  assert.ok(searches.length < 50, `stops once complete (${searches.length} searches)`);
});

test('if the far end is not reachable the sync fails instead of syncing a partial category', async () => {
  catalogue = makeCatalogue(3323);
  ignoreSort = true;
  await assert.rejects(ahSync.fetchProducts(), /AH reports 3323 products but only 3000/);
  ignoreSort = false;
});

test('a category beyond twice the window fails up front', async () => {
  catalogue = makeCatalogue(6001);
  searches = [];
  await assert.rejects(ahSync.fetchProducts(), /6001 products/);
  assert.equal(searches.length, 1);
});
