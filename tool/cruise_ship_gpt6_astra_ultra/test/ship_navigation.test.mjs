import assert from 'node:assert/strict';
import test from 'node:test';
import {Navigator} from '../src/navigation.js';

const context = new Proxy({}, {
  get(_target, key) {
    if (key === 'createLinearGradient' || key === 'createRadialGradient') return () => ({addColorStop() {}});
    if (key === 'measureText') return text => ({width: text.length * 12});
    return () => {};
  },
  set() { return true; },
});
globalThis.document = {createElement() { return {width: 0, height: 0, getContext: () => context}; }};
const {buildShip} = await import('../src/ship.js');
const ship = buildShip();

function walkingAt(id = 'deck7-starboard') {
  const navigator = new Navigator(ship.surfaces, ship.obstacles);
  assert.equal(navigator.place(ship.spots.find(spot => spot.id === id)), true, `Spawn ${id}`);
  return navigator;
}

function walk(navigator, x, z, y, message = '') {
  const previous = {...navigator.position};
  navigator.move(x - previous.x, z - previous.z);
  assert.ok(Math.abs(navigator.position.x - x) < .05, `${message}: x ${navigator.position.x} should reach ${x} from ${JSON.stringify(previous)}`);
  assert.ok(Math.abs(navigator.position.z - z) < .05, `${message}: z ${navigator.position.z} should reach ${z} from ${JSON.stringify(previous)}`);
  if (y !== undefined) assert.ok(Math.abs(navigator.position.y - y) < .075, `${message}: deck height ${navigator.position.y} should reach ${y}`);
  assert.equal(navigator.blocked(navigator.position.x, navigator.position.y, navigator.position.z), false);
}

function ascendTower(navigator, x0, z0) {
  const west = x0 - 1.5;
  const east = x0 + 11.5;
  for (let flight = 0; flight < 8; flight++) {
    const outbound = flight % 2 === 0;
    const lane = z0 + (outbound ? 1.35 : 4.4);
    walk(navigator, navigator.position.x, lane, 16 + flight * 2.95, `Tower flight ${flight + 1} approach`);
    walk(navigator, outbound ? east : west, lane, 16 + (flight + 1) * 2.95, `Tower flight ${flight + 1}`);
  }
}

test('authored ship destinations are safe and use actual public deck numbers', () => {
  assert.equal(ship.lamps.length, 8);
  for (const spot of ship.spots) {
    assert.equal(walkingAt(spot.id).surface.deck, spot.deck, spot.id);
    assert.ok([7, 15, 16, 18, 19].includes(spot.deck), spot.id);
  }
});

test('both deck 7 promenades connect physically around the ship ends', () => {
  const n = walkingAt();
  walk(n, -140, 18.1, 16);
  walk(n, -140, -18.1, 16);
  walk(n, 126, -18.1, 16);
  walk(n, 126, 18.1, 16);
  walk(n, -58, 18.1, 16);
});

test('eight aft stair flights climb from deck 7 to deck 15 and return', () => {
  const n = walkingAt();
  walk(n, -132.5, 18.1, 16);
  walk(n, -132.5, 11.65, 16);
  ascendTower(n, -131, 10.3);
  for (let flight = 7; flight >= 0; flight--) {
    const lane = 10.3 + (flight % 2 === 0 ? 1.35 : 4.4);
    walk(n, n.position.x, lane, 16 + (flight + 1) * 2.95);
    walk(n, flight % 2 === 0 ? -132.5 : -119.5, lane, 16 + flight * 2.95, `Descending aft flight ${flight + 1}`);
  }
  walk(n, -132.5, 18.1, 16);
});

test('forward exterior staircase independently connects deck 7 and deck 15', () => {
  const n = walkingAt();
  walk(n, 128.5, 18.1, 16);
  walk(n, 128.5, -14.75, 16);
  walk(n, 129.5, -14.75, 16);
  ascendTower(n, 131, -16.1);
  walk(n, 128, -11.7, 39.6);
  walk(n, 128, 17.5, 39.6);
});

test('walk from deck 7 through the pool deck to forward deck 18 and deck 19', () => {
  const n = walkingAt();
  walk(n, -132.5, 18.1, 16);
  walk(n, -132.5, 11.65, 16);
  ascendTower(n, -131, 10.3);
  walk(n, -139, 14.7, 39.6);
  walk(n, -139, 18.1, 39.6);
  walk(n, -34.4, 18.1, 39.6);
  walk(n, -34.4, 6.8, 39.6);
  walk(n, -33, 6.2, 39.6);
  walk(n, -33, 6.8, 39.6);
  walk(n, 12, 6.8, 39.6);
  walk(n, 12, 5.8, 39.6);
  walk(n, 51, 5.8, 39.6);
  walk(n, 51, 14.8, 39.6);
  walk(n, 67.5, 14.8, 42.6, 'Pool to deck 16 stairs');
  walk(n, 67.5, 18.5, 42.6);
  walk(n, 88, 18.5, 48.6, 'Deck 16 to forward deck 18 stairs');
  walk(n, 125, 18.5, 48.6);
  walk(n, 125, 8, 48.6, 'Bow viewpoint');
  walk(n, 125, 18.5, 48.6);
  walk(n, 91.5, 18.5, 48.6);
  walk(n, 91.5, 15.2, 48.6);
  walk(n, 104.5, 15.2, 51.6, 'Forward deck 19 stairs');
  walk(n, 104.5, 12.2, 51.6);
});

test('aft stairs link deck 15, sports deck 16, waterpark deck 18 and deck 19', () => {
  const n = walkingAt('aft');
  walk(n, -139, 18.1, 39.6);
  walk(n, -50.5, 18.1, 39.6);
  walk(n, -50.5, 14.8, 39.6);
  walk(n, -67.5, 14.8, 42.6, 'Aft deck 16 stairs');
  walk(n, -114, 14.8, 42.6);
  walk(n, -114, -7, 42.6, 'Sports court viewpoint');
  walk(n, -114, 14.8, 42.6);
  walk(n, -67.5, 14.8, 42.6);
  walk(n, -67.5, 18.5, 42.6);
  walk(n, -87, 18.5, 48.6, 'Aft deck 18 stairs');
  walk(n, -95, 18.5, 48.6);
  walk(n, -95, -16, 48.6);
  walk(n, -109.5, -16, 51.6, 'Aft deck 19 stairs');
  walk(n, -109.5, -12.5, 51.6);
  walk(n, -107.25, -12.5, 51.6);
  walk(n, -107.25, 5.5, 51.6);
  walk(n, -113, 5.5, 51.6, 'Upper aft sun deck viewpoint');
});

test('rail boundaries and cabin walls prevent leaving the walkable ship', () => {
  const n = walkingAt();
  n.move(0, 20);
  assert.ok(n.position.z < 19.9);
  n.move(0, -40);
  assert.ok(n.position.z > 15.8);
  assert.equal(n.position.y, 16);
});
