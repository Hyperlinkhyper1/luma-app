import test from 'node:test';
import assert from 'node:assert/strict';
import { captureMouse, sendHostMessage } from '../src/host.js';

test('focus precedes pointer lock so native capture targets the scene', () => {
  let focused = false, captured = false;
  captureMouse({
    focus(options) { assert.equal(options.preventScroll, true); focused = true; },
    requestPointerLock() { assert.equal(focused, true); captured = true; },
  }, () => assert.fail('Capture should succeed'));
  assert.equal(captured, true);
});

test('capture rejection is handled without an unhandled page error', async () => {
  let unavailable = 0;
  captureMouse({ focus() {}, requestPointerLock() { return Promise.reject(new Error('No focus')); } }, () => unavailable++);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(unavailable, 1);
});

test('native host receives readiness and errors as JSON strings', () => {
  const messages = [];
  const host = { postMessage(message) { assert.equal(typeof message, 'string'); messages.push(JSON.parse(message)); } };
  sendHostMessage({ type: 'cruise-ready' }, host);
  sendHostMessage({ type: 'cruise-error', message: 'Device lost' }, host);
  assert.deepEqual(messages, [{ type: 'cruise-ready' }, { type: 'cruise-error', message: 'Device lost' }]);
});
