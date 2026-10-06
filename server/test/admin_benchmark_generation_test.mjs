import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import test from 'node:test';

const source = readFileSync(new URL('../lib/api_benchmark_generate.dart', import.meta.url), 'utf8');
const script = source.match(/const _bgScript = r'''([\s\S]*?)''';/)[1];

async function render(jobs) {
  const elements = new Map();
  function element(id) {
    if (id === 'aiPickerData') return null;
    if (!elements.has(id)) elements.set(id, {
      value: '', innerHTML: '', textContent: '',
      addEventListener() {},
      showModal() {},
    });
    return elements.get(id);
  }
  runInNewContext(script, {
    document: { getElementById: element },
    setTimeout() {}, clearTimeout() {},
    fetch: async () => ({ text: async () => JSON.stringify({ jobs }) }),
  });
  await new Promise(setImmediate);
  return element('bgRuns').innerHTML;
}

const job = {
  id: 'run1', name: 'Gemini', kindLabel: 'Pagoda', sceneId: 'pagoda_demo',
  upstreamLabel: 'Google AI Studio', model: 'gemini-demo', status: 'failed',
  startedAtMs: 1, finishedAtMs: 1001, chars: 12200, outputTokens: 6900,
  tokens: 8000, maxTokens: 7000, outputCapSent: true,
};

test('truncated run exposes reason, usage, validation, finish reason and raw result', async () => {
  const html = await render([{
    ...job, resultStatus: 'TRUNCATED', resultReason: 'Output limit reached',
    validation: 'Missing closing </html>', finishReason: 'length', nativeFinishReason: 'MAX_TOKENS',
    hasOutput: true, hasResult: true,
  }]);
  assert.match(html, /badge warn">TRUNCATED/);
  assert.match(html, /is-truncated/);
  assert.match(html, /Reason: Output limit reached/);
  assert.match(html, /Generated: 6.9k output tokens \/ 12.2k chars/);
  assert.match(html, /8k total tokens/);
  assert.match(html, /Output cap: 7k/);
  assert.match(html, /Validation: Missing closing &lt;\/html&gt;/);
  assert.match(html, /Finish reason: length · Provider finish reason: MAX_TOKENS/);
  assert.match(html, /\/run1\/result/);
  assert.match(html, />Reply</);
  assert.doesNotMatch(html, />Failed</);
});

test('every outcome renders independently of lifecycle and escapes provider details', async () => {
  for (const resultStatus of ['PROVIDER_BUSY', 'RATE_LIMITED', 'MODEL_ERROR', 'INVALID_OUTPUT']) {
    const html = await render([{ ...job, resultStatus, resultReason: '<img onerror=alert(1)>',
      outputCapSent: false, batch: true, batchId: 'batch1' }]);
    assert.match(html, new RegExp('>' + resultStatus + '</span>'));
    assert.match(html, /Finish reason: Unknown/);
    assert.match(html, /Output cap: provider default \(requested 7k\)/);
    assert.match(html, /&lt;img onerror=alert\(1\)&gt;/);
    assert.doesNotMatch(html, /<img/);
    assert.match(html, /Check again/);
  }
  assert.match(await render([{ ...job, status: 'done', resultStatus: 'PASS' }]), /badge ok">PASS/);
  assert.match(await render([{ ...job, status: 'running', phase: 'writing' }]), />Writing</);
  assert.match(await render([{ ...job, status: 'stopped' }]), />Stopped</);
});
