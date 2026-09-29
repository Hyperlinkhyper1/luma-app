const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(
  path.join(__dirname, '../assets/text_library/scene/main.js'),
  'utf8',
);
const start = source.indexOf('  function receive(raw) {');
const end = source.indexOf('  window.libraryReceive = receive;', start);
assert.ok(start >= 0 && end > start, 'scene receiver is present');
const receiver = source.slice(start, end);

function runReceiver(onAssets) {
  const errors = [];
  const context = {window: {}, console, onAssets, fail: error => errors.push(error)};
  vm.runInNewContext(`${receiver}\nwindow.libraryReceive = receive;`, context);
  return {receive: context.window.libraryReceive, errors};
}

test('a rejected vanilla asset build retries with built-in assets', async () => {
  const calls = [];
  const {receive, errors} = runReceiver(m => {
    calls.push(m);
    return calls.length === 1
      ? Promise.reject(new Error('bad jar texture'))
      : Promise.resolve();
  });
  receive({type: 'assets', files: {broken: 'data'}, source: 'Minecraft'});
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(calls.length, 2);
  assert.equal(Object.keys(calls[1].files).length, 0);
  assert.deepEqual(errors, []);
});

test('a rejected built-in asset build reports an error', async () => {
  const {receive, errors} = runReceiver(() => Promise.reject(new Error('scene build failed')));
  receive({type: 'assets', files: {}});
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(errors.length, 1);
  assert.match(String(errors[0]), /scene build failed/);
});
