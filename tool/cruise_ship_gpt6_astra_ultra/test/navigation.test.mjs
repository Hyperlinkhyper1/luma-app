import test from 'node:test';
import assert from 'node:assert/strict';
import { Navigator, surfaceHeight } from '../src/navigation.js';

test('walker stays on deck and slides along solid furniture', () => {
  const n = new Navigator([{ id: 'deck', deck: 7, x0: 0, x1: 10, z0: 0, z1: 5, y: 16 }], [{ x0: 4, x1: 5, z0: 1, z1: 4, y0: 16, y1: 18 }]);
  assert.equal(n.place({ x: 2, y: 16, z: 2 }), true);
  n.move(5, 1);
  assert.ok(n.position.x < 4);
  assert.ok(n.position.z > 2);
  n.move(-20, 0);
  assert.ok(n.position.x > 0);
  assert.equal(n.position.y, 16);
});

test('physical ramp connects overlapping floors without snapping to roof', () => {
  const n = new Navigator([
    { id: 'low', deck: 7, x0: 0, x1: 3.2, z0: 0, z1: 3, y: 16 },
    { id: 'ramp', deck: 7, x0: 3, x1: 9, z0: 0, z1: 3, y: 16, y1: 19, axis: 'x' },
    { id: 'high', deck: 8, x0: 8.8, x1: 12, z0: 0, z1: 3, y: 19 },
    { id: 'roof', deck: 16, x0: 0, x1: 12, z0: 0, z1: 3, y: 42.6 },
  ], []);
  assert.ok(n.place({ x: 1, z: 1, y: 16 }));
  n.move(9.5, 0);
  assert.ok(n.position.x > 10);
  assert.equal(n.position.y, 19);
  n.move(-9.5, 0);
  assert.ok(n.position.x < 2);
  assert.equal(n.position.y, 16);
});

test('unsafe teleport leaves previous safe position intact', () => {
  const n = new Navigator([{ x0: 0, x1: 5, z0: 0, z1: 5, y: 16 }], [{ x0: 2, x1: 3, z0: 2, z1: 3, y0: 16, y1: 19 }]);
  assert.ok(n.place({ x: 1, y: 16, z: 1 }));
  const original = { ...n.position };
  assert.equal(n.place({ x: 8, y: 16, z: 1 }), false);
  assert.equal(n.place({ x: 2.5, y: 16, z: 2.5 }), false);
  assert.deepEqual(n.position, original);
});

test('ceiling clearance responds to crouching and slopes interpolate both axes', () => {
  const n = new Navigator([{ x0: 0, x1: 5, z0: 0, z1: 5, y: 16 }], [{ x0: 2, x1: 3, z0: 0, z1: 5, y0: 17.4, y1: 19 }]);
  n.place({ x: 1, y: 16, z: 1 });
  n.move(3, 0);
  assert.ok(n.position.x < 2);
  n.height = 1.1;
  n.move(3, 0);
  assert.ok(n.position.x > 3);
  assert.equal(surfaceHeight({ axis: 'z', z0: 0, z1: 10, y: 3, y1: 8 }, 1, 4), 5);
});
