import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import test from 'node:test';

test('Assistant prices follow model edits and restore the saved guard', async () => {
  const source = readFileSync(new URL('../lib/api.dart', import.meta.url), 'utf8');
  const script = source.match(/static const _adminAssistantScript = r'''([\s\S]*?)''';/)[1];
  const elements = new Map();
  function element(id) {
    if (!elements.has(id)) elements.set(id, {
      value: '', style: {}, dataset: {}, listeners: {},
      classList: { contains: () => false },
      addEventListener(type, callback) { this.listeners[type] = callback; },
      replaceChildren() {}, setAttribute() {},
    });
    return elements.get(id);
  }
  const input = element('ai-model-smartest');
  input.value = 'openai/saved';
  const upstream = element('upstream');
  upstream.value = 'openrouter';
  const model = 'inclusionai/ling-3.0-flash-vl';
  element('aiPickerData').textContent = JSON.stringify([
    { upstream: 'openrouter', id: model, input: 0.021, output: 0.0616 },
  ]);
  runInNewContext(script, {
    document: {
      getElementById: (id) => id === 'aiPicker' || id === 'aiDetectorForm' ? null : element(id),
      querySelector: (selector) => selector === '.ai-price-cell' ? {} : upstream,
      querySelectorAll: (selector) => selector.includes('input[name$=') ? [input] : [],
    },
    fetch: async () => ({ json: async () => ({ modes: { smartest: {
      model: 'openai/saved', upstreamId: 'openrouter',
      defaultModels: { openrouter: 'openai/saved' },
      price: { input: 1, output: 2 }, baseline: { input: 1, output: 2 },
      autoDisable: true, disabled: false,
    } } }) }),
    setInterval() {},
  });
  await new Promise(setImmediate);
  const price = element('ai-price-smartest');
  const guard = element('ai-guard-smartest');
  assert.equal(price.textContent, '$1.00 in / $2.00 out');
  assert.equal(guard.disabled, false);
  input.value = model;
  input.listeners.input();
  assert.match(price.textContent, /^\$0.021 in/);
  assert.match(price.textContent, /\$0.0616 out$/);
  assert.equal(guard.disabled, true);
  input.value = 'missing/model';
  input.listeners.input();
  assert.equal(price.textContent, 'price unknown');
  input.value = '';
  input.listeners.input();
  assert.equal(price.textContent, '$1.00 in / $2.00 out');
  assert.equal(guard.disabled, false);
});
