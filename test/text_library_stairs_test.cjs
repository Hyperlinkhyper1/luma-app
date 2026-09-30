const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const scene = path.join(__dirname, '../assets/text_library/scene');
const context = {window: {}};
vm.runInNewContext(fs.readFileSync(path.join(scene, 'stairs.js'), 'utf8'), context);
const stairs = context.window.LibraryStairs;
context.LibraryStairs = stairs;
const well = {x0: 2, z0: 1, cx: 3, cz: 2};

test('every storey has shallow closed treads, room to stand and aligned landings', () => {
  for (const [base, height] of [[0, 8], [8, 5], [13, 5]]) {
    const flight = stairs.describe(well, base, height);
    assert.ok(flight.rise <= 0.25, 'no whole-block jumps');
    assert.ok(height / flight.turns - flight.rise - 0.125 > 1.9, 'headroom below the next turn');
    const treads = stairs.treads(well, flight);
    assert.equal(treads.length, flight.count);
    assert.equal(treads.at(-1).top, base + height);
    for (let i = 1; i < treads.length; i++) {
      assert.ok(treads[i].bottom < treads[i - 1].top, 'risers close the gaps between treads');
    }
    assert.deepEqual(Array.from(stairs.route(well, flight, 0)), [3.5, base, 4.5]);
    assert.deepEqual(Array.from(stairs.route(well, flight, 1)), [3.5, base + height, 4.5]);
    let prev = stairs.route(well, flight, 0);
    for (let i = 1; i <= 1000; i++) {
      const p = stairs.route(well, flight, i / 1000);
      assert.ok(p[1] >= prev[1] - 1e-9, 'the climb never dips between steps');
      assert.ok(Math.hypot(...p.map((v, k) => v - prev[k])) < 0.03, 'no jumps at route joins');
      assert.ok(p[0] > 2.26 && p[0] < 4.74 && p[2] > 1.26, 'body clears the well walls');
      assert.ok(Math.hypot(p[0] - 3.5, p[2] - 2.5) > 0.7, 'body clears the newel');
      prev = p;
    }
  }
});

test('timber faces wind toward their declared normals', () => {
  const quads = [];
  const world = {};
  vm.runInNewContext(fs.readFileSync(path.join(scene, 'world.js'), 'utf8'), {window: world});
  context.window.LibraryWorld = world.LibraryWorld;
  vm.runInNewContext(fs.readFileSync(path.join(scene, 'furniture.js'), 'utf8'), context);
  const tile = {cell: 0, frames: 1, frameTime: 0};
  const K = {
    mb: {quad: (corners, normal, uv, tile) => quads.push({corners, normal, uv, tile})},
    grid: {sample: () => [1, 1, 1]},
    atlas: {index: {oak_planks: tile, spruce_planks: {...tile, cell: 2}, dark_oak_planks: {...tile, cell: 3}}},
  };
  context.window.LibraryFurniture.spiralStair(K, [stairs.describe(well, 0, 8)], well);
  assert.ok(quads.length > 32 * 6);
  for (const {corners: c, normal: n} of quads) {
    const a = c[1].map((v, k) => v - c[0][k]), b = c[2].map((v, k) => v - c[0][k]);
    const cross = [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
    assert.ok(cross.reduce((v, x, k) => v + x * n[k], 0) > 0, 'faces remain visible from the intended side');
  }
  const tops = quads.filter(q => q.normal[1] === 1 && q.tile[0] === 2);
  assert.equal(tops.length, 32, 'every tread uses the floor\'s spruce plank atlas entry');
  for (const {corners, uv} of tops) {
    for (let i = 1; i < corners.length; i++) {
      assert.ok(Math.abs((uv[i][0] - uv[0][0]) - (corners[i][0] - corners[0][0]) * 16) < 1e-8, 'wood grain repeats at the floor\'s 16 pixels per block');
      assert.ok(Math.abs((uv[i][1] - uv[0][1]) - (corners[i][2] - corners[0][2]) * 16) < 1e-8);
    }
  }
});

test('the real camera climbs both flights, reverses, and respects reduced motion', async () => {
  const T = require('../assets/airline_tycoon/scene/vendor/three-0.160.1.min.js');
  const source = fs.readFileSync(path.join(scene, 'main.js'), 'utf8');
  const cut = (from, to) => source.slice(source.indexOf(from), source.indexOf(to, source.indexOf(from)));
  const S = {mode: 'overview', floor: 0, px: 3.5, pz: 4.5, yaw: 0, pitch: 0, stride: 0, vel: [0, 0],
    reducedMotion: false, built: {stairs: {...well, flights: [stairs.describe(well, 0, 8), stairs.describe(well, 8, 5)]}, layout: {bases: [0, 8, 13]}}};
  const view = {pos: new T.Vector3(3.5, 1.9, 4.5), target: new T.Vector3(3.5, 1.9, 3), fov: 70};
  const harness = {T, S, view, LibraryStairs: stairs, W: {HALL: {eye: 1.9}}, V: {bobbing: true},
    camera: new T.PerspectiveCamera(), walkFov: () => 70, setMode: mode => {S.mode = mode;},
    floorY: () => S.built.layout.bases[S.floor], blocked: () => false,
    rebuildA11y: () => {}, baseModePose: () => null};
  vm.runInNewContext(`let flight = null;
    ${cut('  const easeInOut =', '  // Standing in the hall')}
    ${cut('  function flyTo(', '  function baseModePose(')}
    ${cut('  async function climb(', '  // ── The front door')}
    this.climb = climb; this.step = stepCamera; this.moving = () => !!flight?.sample;`, harness);
  for (const [dir, destination, reduced] of [[1, 1, false], [1, 2, false], [-1, 1, false], [-1, 0, true]]) {
    S.reducedMotion = reduced;
    const promise = harness.climb(dir);
    let sampled = 0, previous = null;
    for (let i = 0; i < 700 && S.mode === 'climbing'; i++) {
      harness.step(1 / 60, i / 60);
      if (harness.moving()) {
        sampled++;
        if (previous) {
          assert.ok((view.pos.y - previous.y) * dir >= -1e-8, 'no repeated camera hops');
          assert.ok(view.pos.distanceTo(previous) < 0.08, 'continuous, bounded movement');
        }
        assert.ok(Math.abs(view.target.y - view.pos.y) < 1e-8, 'level gaze around the spiral');
        previous = view.pos.clone();
      }
      await Promise.resolve();
    }
    await promise;
    assert.equal(S.floor, destination);
    assert.equal(S.mode, 'overview');
    assert.equal(S.px, 3.5);
    assert.equal(S.pz, 4.5);
    assert.ok(Math.abs(view.pos.y - (S.built.layout.bases[destination] + 1.9)) < 1e-8);
    assert.ok(reduced ? sampled === 0 : sampled > 400, 'one uninterrupted climb, or a short reduced-motion transition');
  }
});
