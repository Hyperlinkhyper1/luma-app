import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import test from 'node:test';

test('banner settings and status never start repairs; only Repair once does', async () => {
  const source = readFileSync(new URL('../lib/api.dart', import.meta.url), 'utf8');
  const script = source.match(/static const _adminBannersScript = r'''([\s\S]*?)''';/)[1];
  const elements = new Map();
  function element(id) {
    if (!elements.has(id)) elements.set(id, {
      value: '', style: {}, dataset: {}, listeners: {}, innerHTML: '', textContent: '',
      classList: { toggle() {}, add() {}, remove() {} },
      addEventListener(type, callback) { this.listeners[type] = callback; },
      querySelectorAll() { return []; }, setAttribute() {},
      showModal() { this.open = true; }, close() { this.open = false; },
      getBoundingClientRect() { return { width: 400, height: 250 }; },
    });
    return elements.get(id);
  }
  const requests = [];
  let repairing = false;
  runInNewContext(script, {
    document: { body: { appendChild() {} }, getElementById: element, addEventListener() {}, querySelectorAll() { return []; } },
    window: { addEventListener() {} },
    setTimeout() {}, clearTimeout() {}, setInterval() {}, clearInterval() {},
    fetch: async (url, init) => {
      requests.push([url, init.method || 'GET']);
      let body;
      if (url.endsWith('/repair/settings')) {
        body = init.method === 'PUT' ? { saved: true, acceptedPrice: { input: 1, output: 2 } }
          : { route: { upstream: 'openrouter', model: 'test/model' }, keys: [{ upstream: 'openrouter', label: 'OpenRouter' }], models: { openrouter: ['test/model'] }, maxCostUsd: .25 };
      } else if (url.includes('/repair/')) {
        repairing = true;
        body = { started: true };
      } else {
        body = { running: false, sceneCount: 1, missingCount: 1,
          items: [{ id: 'pagoda_demo', state: 'failed', detail: 'ReferenceError: broken' }],
          repairs: repairing ? [{ id: 'pagoda_demo', state: 'running', detail: 'Repairing…' }] : [] };
      }
      return { ok: true, status: 200, json: async () => body };
    },
  });
  const settle = () => new Promise(setImmediate);
  await settle();
  assert.match(element('bannersRows').innerHTML, /Repair once/);
  assert.equal(requests.filter(([, method]) => method === 'POST').length, 0);
  await element('bannersRepairSettingsBtn').listeners.click();
  assert.equal(element('bnRepairSettings').open, true);
  assert.equal(element('bnRepairModel').value, 'test/model');
  await element('bnRepairForm').listeners.submit({ preventDefault() {} });
  assert.equal(requests.filter(([, method]) => method === 'POST').length, 0);
  assert.match(element('bnRepairNote').textContent, /No repair was started/);
  const button = { dataset: { repairScene: 'pagoda_demo' }, disabled: false };
  await element('bannersRows').listeners.click({ target: { closest: () => button } });
  await settle();
  assert.equal(requests.filter(([, method]) => method === 'POST').length, 1);
  assert.equal(element('bannersMissingBtn').disabled, true);
  assert.match(element('bannersRows').innerHTML, /Repairing/);
});
