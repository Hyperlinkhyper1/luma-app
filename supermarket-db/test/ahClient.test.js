const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

function loadClient(request) {
  const delays = [];
  const sandbox = {
    module: { exports: {} }, URL, AbortSignal, Date,
    console: { log() {}, warn() {} }, fetch: request,
    require: () => ({ sleep: async (delay) => delays.push(delay) }),
  };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../src/supermarkets/ah/ahClient.js'), 'utf8'), sandbox);
  return { client: sandbox.module.exports, delays };
}

const tokenResponse = () => ({ ok: true, json: async () => ({ access_token: 'member_token', refresh_token: 'refresh', expires_in: 604800 }) });
const edgeResponse = () => ({ ok: false, status: 503, text: async () => '<HTML><TITLE>Error</TITLE>errors.edgesuite.net</HTML>', headers: new Headers() });

test('AH initial authentication retries an edge 503 and completes the category request', async () => {
  let authCalls = 0;
  const { client, delays } = loadClient(async (url) => {
    if (String(url).includes('/auth/token/')) return ++authCalls === 1 ? edgeResponse() : tokenResponse();
    return { ok: true, json: async () => [{ id: 1 }] };
  });
  assert.equal((await client.fetchCategories())[0].id, 1);
  assert.equal(authCalls, 2);
  assert.equal(delays.length, 1);
});

test('AH refresh edge failure retries the same member without registering a replacement', async () => {
  let anonymousCalls = 0;
  let refreshCalls = 0;
  let dataCalls = 0;
  const { client } = loadClient(async (url) => {
    if (String(url).endsWith('/anonymous')) { anonymousCalls += 1; return tokenResponse(); }
    if (String(url).endsWith('/refresh')) return ++refreshCalls === 1 ? edgeResponse() : tokenResponse();
    if (++dataCalls === 2) return { ok: false, status: 401, text: async () => 'invalid_token' };
    return { ok: true, json: async () => [] };
  });
  await client.fetchCategories();
  await client.fetchCategories();
  assert.equal(refreshCalls, 2);
  assert.equal(anonymousCalls, 1);
});

test('AH data edge failure retries with the cached token', async () => {
  let authCalls = 0;
  let dataCalls = 0;
  const { client } = loadClient(async (url) => {
    if (String(url).includes('/auth/token/')) { authCalls += 1; return tokenResponse(); }
    return ++dataCalls === 1 ? edgeResponse() : { ok: true, json: async () => ({ products: [{ id: 1 }] }) };
  });
  assert.equal((await client.searchProducts()).products.length, 1);
  assert.equal(authCalls, 1);
  assert.equal(dataCalls, 2);
});

test('AH persistent refresh edge rejection exhausts retries without minting a member or exposing HTML', async () => {
  let anonymousCalls = 0;
  let refreshCalls = 0;
  let dataCalls = 0;
  const { client } = loadClient(async (url) => {
    if (String(url).endsWith('/anonymous')) { anonymousCalls += 1; return tokenResponse(); }
    if (String(url).endsWith('/refresh')) {
      refreshCalls += 1;
      return { ...edgeResponse(), text: async () => '<HTML>https&#58;&#47;&#47;errors&#46;edgesuite&#46;net</HTML>' };
    }
    if (++dataCalls === 2) return { ok: false, status: 401, text: async () => 'invalid_token' };
    return { ok: true, json: async () => [] };
  });
  await client.fetchCategories();
  await assert.rejects(client.fetchCategories(), error => {
    assert.match(error.message, /HTTP 503.*edge service/);
    assert.doesNotMatch(error.message, /<HTML>|&#/);
    return true;
  });
  assert.equal(refreshCalls, 4);
  assert.equal(anonymousCalls, 1);
});

test('AH respects Retry-After and retries network timeouts with a fresh timeout signal', async () => {
  let calls = 0;
  const signals = [];
  const { client, delays } = loadClient(async (url, options) => {
    if (!String(url).includes('/auth/token/')) return { ok: true, json: async () => [] };
    signals.push(options.signal);
    calls += 1;
    if (calls === 1) throw new TypeError('fetch failed');
    if (calls === 2) return { ...edgeResponse(), status: 429, headers: new Headers({ 'Retry-After': '10' }) };
    return tokenResponse();
  });
  await client.fetchCategories();
  assert.deepEqual(delays, [1000, 10000]);
  assert.equal(new Set(signals).size, 3);
});

test('AH invalid refresh credentials still register a replacement member', async () => {
  let anonymousCalls = 0;
  let dataCalls = 0;
  const { client } = loadClient(async (url) => {
    if (String(url).endsWith('/anonymous')) { anonymousCalls += 1; return tokenResponse(); }
    if (String(url).endsWith('/refresh')) return { ok: false, status: 400, text: async () => 'invalid_grant' };
    if (++dataCalls === 2) return { ok: false, status: 401, text: async () => 'invalid_token' };
    return { ok: true, json: async () => [] };
  });
  await client.fetchCategories();
  await client.fetchCategories();
  assert.equal(anonymousCalls, 2);
});
