'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(
  path.join(__dirname, '../assets/monitor_simulation/viewer.js'),
  'utf8',
);

class Element {
  constructor() {
    this.listeners = new Map();
    this.options = [];
    this.disabled = false;
    this.hidden = false;
    this.value = '';
    this.textContent = '';
    this.srcObject = null;
  }

  addEventListener(type, listener) {
    this.listeners.set(type, listener);
  }

  dispatch(type, event = {}) {
    return this.listeners.get(type)?.(event);
  }

  replaceChildren() {
    this.options = [];
    this.value = '';
  }

  append(option) {
    this.options.push(option);
    if (this.options.length === 1) this.value = option.value;
  }

  play() {
    return Promise.resolve();
  }

  requestFullscreen() {
    return Promise.resolve();
  }
}

function makeStream() {
  const track = new Element();
  track.stopped = 0;
  track.readyState = 'live';
  track.stop = () => { track.stopped++; track.readyState = 'ended'; };
  return {
    track,
    getTracks: () => [track],
    getVideoTracks: () => [track],
  };
}

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((res, rej) => { resolve = res; reject = rej; });
  return { promise, resolve, reject };
}

function createViewer(mediaDevices) {
  const ids = ['discover', 'devices', 'start', 'expand', 'stop', 'status', 'video', 'placeholder'];
  const elements = Object.fromEntries(ids.map(id => [id, new Element()]));
  const screen = new Element();
  const webview = new Element();
  const window = new Element();
  window.chrome = { webview };
  const document = {
    getElementById: id => elements[id],
    createElement: () => new Element(),
    querySelector: () => screen,
    fullscreenElement: null,
    exitFullscreen: () => Promise.resolve(),
  };
  vm.runInNewContext(source, { document, window, navigator: { mediaDevices } });
  return { elements, window, webview };
}

test('discovery lists only video inputs and releases the temporary camera', async () => {
  const probe = makeStream();
  const calls = [];
  const viewer = createViewer({
    getUserMedia: async options => { calls.push(options); return probe; },
    enumerateDevices: async () => [
      { kind: 'audioinput', label: 'Microphone', deviceId: 'mic' },
      { kind: 'videoinput', label: 'HDMI Capture', deviceId: 'capture' },
      { kind: 'videoinput', label: '', deviceId: 'other' },
    ],
  });
  await viewer.elements.discover.dispatch('click');
  assert.equal(calls[0].video, true);
  assert.equal(calls[0].audio, false);
  assert.deepEqual(viewer.elements.devices.options.map(o => [o.value, o.textContent]), [
    ['capture', 'HDMI Capture'], ['other', 'Video input 2'],
  ]);
  assert.equal(probe.track.stopped, 1);
  assert.equal(viewer.elements.start.disabled, false);
});

test('selected input is displayed and Stop releases its track', async () => {
  const probe = makeStream();
  const capture = makeStream();
  const calls = [];
  const viewer = createViewer({
    getUserMedia: async options => { calls.push(options); return calls.length === 1 ? probe : capture; },
    enumerateDevices: async () => [
      { kind: 'videoinput', label: 'Laptop camera', deviceId: 'camera' },
      { kind: 'videoinput', label: 'HDMI Capture', deviceId: 'capture' },
    ],
  });
  await viewer.elements.discover.dispatch('click');
  viewer.elements.devices.value = 'capture';
  await viewer.elements.start.dispatch('click');
  assert.equal(calls[1].video.deviceId.exact, 'capture');
  assert.equal(calls[1].audio, false);
  assert.equal(viewer.elements.video.srcObject, capture);
  assert.equal(viewer.elements.placeholder.hidden, true);
  assert.equal(viewer.elements.stop.disabled, false);
  viewer.elements.stop.dispatch('click');
  assert.equal(capture.track.stopped, 1);
  assert.equal(viewer.elements.video.srcObject, null);
  assert.equal(viewer.elements.placeholder.hidden, false);
  assert.equal(viewer.elements.start.disabled, false);
});

test('hiding the view stops an active input and permits a later restart', async () => {
  const probe = makeStream();
  const capture = makeStream();
  let calls = 0;
  const viewer = createViewer({
    getUserMedia: async () => ++calls === 1 ? probe : capture,
    enumerateDevices: async () => [{ kind: 'videoinput', label: 'Capture', deviceId: 'capture' }],
  });
  await viewer.elements.discover.dispatch('click');
  await viewer.elements.start.dispatch('click');
  viewer.webview.dispatch('message', { data: 'stop-capture' });
  assert.equal(capture.track.stopped, 1);
  assert.equal(viewer.elements.video.srcObject, null);
  assert.equal(viewer.elements.start.disabled, false);
});

test('a capture that opens after Stop is immediately released', async () => {
  const probe = makeStream();
  const capture = makeStream();
  const pending = deferred();
  let calls = 0;
  const viewer = createViewer({
    getUserMedia: async () => ++calls === 1 ? probe : pending.promise,
    enumerateDevices: async () => [{ kind: 'videoinput', label: 'Capture', deviceId: 'capture' }],
  });
  await viewer.elements.discover.dispatch('click');
  const opening = viewer.elements.start.dispatch('click');
  assert.equal(viewer.elements.stop.disabled, false);
  viewer.elements.stop.dispatch('click');
  pending.resolve(capture);
  await opening;
  assert.equal(capture.track.stopped, 1);
  assert.equal(viewer.elements.video.srcObject, null);
  assert.match(viewer.elements.status.textContent, /stopped/i);
});

test('cancelled discovery releases a late camera and does not populate devices', async () => {
  const probe = makeStream();
  const pending = deferred();
  const viewer = createViewer({
    getUserMedia: () => pending.promise,
    enumerateDevices: async () => { throw new Error('Must not enumerate after cancellation'); },
  });
  const discovering = viewer.elements.discover.dispatch('click');
  viewer.webview.dispatch('message', { data: 'stop-capture' });
  pending.resolve(probe);
  await discovering;
  assert.equal(probe.track.stopped, 1);
  assert.equal(viewer.elements.devices.options.length, 0);
  assert.match(viewer.elements.status.textContent, /stopped/i);
});

test('hiding while device enumeration is pending stops the probe immediately', async () => {
  const probe = makeStream();
  const pending = deferred();
  const enumerating = deferred();
  const viewer = createViewer({
    getUserMedia: async () => probe,
    enumerateDevices: () => { enumerating.resolve(); return pending.promise; },
  });
  const discovering = viewer.elements.discover.dispatch('click');
  await enumerating.promise;
  viewer.webview.dispatch('message', { data: 'stop-capture' });
  assert.equal(probe.track.stopped, 1);
  pending.resolve([{ kind: 'videoinput', label: 'Capture', deviceId: 'capture' }]);
  await discovering;
  assert.equal(probe.track.stopped, 1);
  assert.equal(viewer.elements.devices.options.length, 0);
});

test('a disconnected input releases the stream and reports the problem', async () => {
  const probe = makeStream();
  const capture = makeStream();
  let calls = 0;
  const viewer = createViewer({
    getUserMedia: async () => ++calls === 1 ? probe : capture,
    enumerateDevices: async () => [{ kind: 'videoinput', label: 'Capture', deviceId: 'capture' }],
  });
  await viewer.elements.discover.dispatch('click');
  await viewer.elements.start.dispatch('click');
  capture.track.dispatch('ended');
  assert.equal(capture.track.stopped, 1);
  assert.equal(viewer.elements.video.srcObject, null);
  assert.match(viewer.elements.status.textContent, /disconnected/i);
});

test('permission and busy-device failures are actionable and restore controls', async () => {
  const probe = makeStream();
  let calls = 0;
  const viewer = createViewer({
    getUserMedia: async () => {
      calls++;
      if (calls === 1) throw Object.assign(new Error(), { name: 'NotAllowedError' });
      if (calls === 2) return probe;
      throw Object.assign(new Error(), { name: 'NotReadableError' });
    },
    enumerateDevices: async () => [{ kind: 'videoinput', label: 'Capture', deviceId: 'capture' }],
  });
  await viewer.elements.discover.dispatch('click');
  assert.match(viewer.elements.status.textContent, /denied/i);
  assert.equal(viewer.elements.discover.disabled, false);
  await viewer.elements.discover.dispatch('click');
  await viewer.elements.start.dispatch('click');
  assert.match(viewer.elements.status.textContent, /busy/i);
  assert.equal(viewer.elements.start.disabled, false);
  assert.equal(viewer.elements.stop.disabled, true);
});
