// The wandering trader's market: the eight pieces of furniture he sells,
// his stall in front of the house, and the trader himself with his llamas,
// all luma's own models built from boxes the way the rest of the hall is.
//
// A piece is built in its own frame: its footprint runs from (0, 0) to its
// size in blocks, centred on the origin, with its front facing +z. The page
// turns and moves the finished mesh to wherever it is placed. Sizes inside
// a model are in pixels, 16 to a block.
(() => {
  'use strict';
  const {addBox, MeshBuilder, sides, all, candle, cross, chain} = window.LibraryWorld;

  const srgb = c => c.map(v => Math.pow(v, 2.2));
  // Light for building somewhere the grid isn't: the page bakes the real
  // light into each piece once it knows where it stands.
  const FLAT = {sample: () => [1, 0, 0]};

  const brass = sides('iron_block', null, null, {tint: [0.72, 0.46, 0.15]});
  const darkBrass = sides('iron_block', null, null, {tint: [0.34, 0.2, 0.07]});
  const iron = sides('iron_block', null, null, {tint: [0.07, 0.065, 0.06]});
  const solid = c => sides('solid', null, null, {tint: srgb(c)});

  // ── The catalogue ──────────────────────────────────────────────────────
  // Prices are coins; the post brings about forty an hour the hall is open.
  // `height` is how many blocks of air a piece needs above its footprint.
  const CATALOG = [
    {id: 'bed', price: 60, size: [1, 2], height: 2, where: 'inside'},
    {id: 'aquarium', price: 75, size: [2, 1], height: 2, where: 'inside'},
    {id: 'gramophone', price: 45, size: [1, 1], height: 2, where: 'inside'},
    {id: 'candelabra', price: 20, size: [1, 1], height: 2, where: 'inside'},
    {id: 'swing', price: 90, size: [3, 1], height: 3, where: 'outside'},
    {id: 'birdbath', price: 25, size: [1, 1], height: 1, where: 'outside'},
    {id: 'beehive', price: 35, size: [1, 1], height: 2, where: 'outside'},
    {id: 'telescope', price: 50, size: [1, 1], height: 2, where: 'both'},
  ];
  const ITEMS = Object.fromEntries(CATALOG.map(c => [c.id, c]));

  // Where a point of a piece's own frame lands, turned `rot` quarter turns
  // (each one swings its front from +z toward +x) about the footprint's
  // middle.
  function turn([x, z], rot) {
    const r = ((rot % 4) + 4) % 4;
    return r === 0 ? [x, z] : r === 1 ? [z, -x] : r === 2 ? [-x, -z] : [-z, x];
  }
  // The footprint once turned: width along x and depth along z.
  const footprint = (id, rot) => {
    const [w, d] = ITEMS[id].size;
    return rot % 2 ? [d, w] : [w, d];
  };

  // An upright box between two points: square or rectangular across, its
  // texture laid along it at block scale. `size` is [across, thick] in
  // blocks; `up` steers which way "thick" faces.
  function beam(K, a, c, size, tex, opts = {}) {
    const d = c.map((v, k) => v - a[k]);
    const len = Math.hypot(...d);
    if (len < 1e-6) return;
    const f = d.map(v => v / len);
    const cross3 = (p, q) => [p[1] * q[2] - p[2] * q[1], p[2] * q[0] - p[0] * q[2], p[0] * q[1] - p[1] * q[0]];
    const norm = v => { const l = Math.hypot(...v); return v.map(x => x / l); };
    const ref = opts.up || (Math.abs(f[1]) > 0.95 ? [1, 0, 0] : [0, 1, 0]);
    const s = norm(cross3(f, ref)), u = cross3(s, f);
    const [sw, sh] = Array.isArray(size) ? size : [size, size];
    const hs = sw / 2, hu = sh / 2;
    const t = K.atlas.index[tex] || K.atlas.index.oak_planks;
    const tile = [t.cell, t.frames, t.frameTime];
    const add = (p, v, k) => p.map((x, i) => x + v[i] * k);
    const lights = [[1, 0, 0], [1, 0, 0], [1, 0, 0], [1, 0, 0]];
    const extra = {tint: opts.tint, emit: opts.emit};
    const side = (n, half, right, across) => {
      const R = cross3(f, n);
      const corners = [add(add(c, n, half), R, -across), add(add(a, n, half), R, -across), add(add(a, n, half), R, across), add(add(c, n, half), R, across)];
      const w = across * 32, l = len * 16;
      K.mb.quad(corners, n, [[0, 0], [0, l], [w, l], [w, 0]], tile, lights, [1, 1, 1, 1], extra);
    };
    side(u, hu, s, hs);
    side(u.map(v => -v), hu, s, hs);
    side(s, hs, u, hu);
    side(s.map(v => -v), hs, u, hu);
    for (const [p, n] of [[c, f], [a, f.map(v => -v)]]) {
      const R = cross3(u, n);
      const corners = [add(add(p, R, -hs), u, hu), add(add(p, R, -hs), u, -hu), add(add(p, R, hs), u, -hu), add(add(p, R, hs), u, hu)];
      K.mb.quad(corners, n, [[0, 0], [0, sh * 16], [sw * 16, sh * 16], [sw * 16, 0]], tile, lights, [1, 1, 1, 1], extra);
    }
  }

  // ── The eight pieces ───────────────────────────────────────────────────
  // Each takes its build context, the footprint's corner `o` (in blocks,
  // already centred) and `part(name)`, which hands out a context for a
  // piece that moves on its own. It returns what the page needs to know:
  // its solid boxes (in footprint blocks), what can be clicked, and the
  // moving parts' pivots, all in the piece's own frame.
  const at = (o, x, y, z) => [o[0] + x / 16, o[1] + y / 16, o[2] + z / 16];

  // A wooden bed: a spruce frame and headboard, a cream mattress, a red
  // patchwork quilt turned down over a folded sheet, two pillows. The head
  // is at the back (-z), the foot at the front.
  function bed(K, o) {
    const b = (f, t, faces, opts) => addBox(K.mb, K.grid, K.atlas, o, f, t, faces, opts);
    const frame = sides('spruce_planks'), dark = sides('dark_oak_planks');
    const sheet = sides('white_wool', null, null, {tint: [0.96, 0.92, 0.82]});
    const pillow = sides('white_wool', null, null, {tint: [1, 0.98, 0.94]});
    b([0, 0, 0], [2, 24, 2], dark); b([14, 0, 0], [16, 24, 2], dark);
    b([2, 6, 0.5], [14, 21, 1.5], frame);
    b([2, 21, 0], [14, 23, 2], dark);
    b([0, 0, 30], [2, 13, 32], dark); b([14, 0, 30], [16, 13, 32], dark);
    b([2, 4, 30.5], [14, 11, 31.5], frame);
    b([2, 11, 30], [14, 12.5, 32], dark);
    b([0.5, 3, 2], [1.5, 7, 30], frame); b([14.5, 3, 2], [15.5, 7, 30], frame);
    b([1.5, 5, 2], [14.5, 9, 30], sheet);
    const quilt = all('quilt');
    b([1, 9, 11], [15, 10, 30.2], quilt);
    b([1, 5.5, 11], [1.5, 9, 30.2], {west: quilt.west, south: quilt.south, north: quilt.north});
    b([14.5, 5.5, 11], [15, 9, 30.2], {east: quilt.east, south: quilt.south, north: quilt.north});
    b([1.2, 9, 9.5], [14.8, 10.6, 11.5], sheet);
    b([2.5, 9, 3], [7.5, 11.5, 8.5], pillow);
    b([8.5, 9, 3], [13.5, 11.5, 8.5], pillow);
    return {
      solid: [[0.02, 0.02, 0.98, 1.98]],
      pick: [at(o, 0, 0, 0), at(o, 16, 13, 32)],
      // Lying down: the head on the pillows, looking down the bed and up a
      // little at the room.
      seat: {pos: at(o, 8, 10, 6), face: 0, eye: 0.32, pitch: 0.28},
    };
  }

  // A fish tank on a spruce cabinet: sand, kelp and a mossy rock behind
  // glass, the water lit, three fish swimming about in it.
  function aquarium(K, o, part) {
    const b = (f, t, faces, opts) => addBox(K.mb, K.grid, K.atlas, o, f, t, faces, opts);
    const dark = sides('dark_oak_planks'), wood = sides('spruce_planks');
    b([0.5, 0, 1], [31.5, 1.5, 15], dark);
    b([1, 1.5, 1.5], [31, 11, 14.5], {...wood, south: null});
    const door = {south: {tex: 'cabinet_door', uv: [2, 2, 14, 14]}, east: wood.east, west: wood.west, up: wood.up, down: wood.down};
    b([1.5, 2, 14.5], [15.6, 10.5, 15.1], door);
    b([16.4, 2, 14.5], [30.5, 10.5, 15.1], door);
    b([15.6, 1.5, 14.5], [16.4, 11, 14.9], wood);
    b([1, 1.5, 14.5], [1.5, 11, 15.1], wood); b([30.5, 1.5, 14.5], [31, 11, 15.1], wood);
    for (const x of [7.2, 24.4]) b([x, 5.6, 15.1], [x + 1.2, 6.8, 15.6], brass);
    b([0, 11, 0.5], [32, 12.5, 15.5], dark);
    // The tank's black frame.
    b([0.5, 12.5, 1], [31.5, 13.5, 15], iron);
    for (const [x, z] of [[0.5, 1], [30.5, 1], [0.5, 14], [30.5, 14]]) b([x, 13.5, z], [x + 1, 25, z + 1], iron);
    b([0.5, 25, 1], [31.5, 26, 2], iron); b([0.5, 25, 14], [31.5, 26, 15], iron);
    b([0.5, 25, 2], [1.5, 26, 14], iron); b([30.5, 25, 2], [31.5, 26, 14], iron);
    // Sand, a rock, kelp.
    b([1.5, 13.5, 2], [30.5, 15, 14], all('sand'));
    b([20, 15, 4], [25.5, 18.5, 8.5], sides('mossy_cobblestone'));
    b([23, 15, 8.5], [26.5, 16.6, 11], sides('cobblestone'));
    b([6, 15, 9], [8.5, 15.8, 11], sides('cobblestone'));
    for (const [x, z, s] of [[5, 5, 0.6], [11, 10, 0.55], [15, 4.5, 0.62], [28, 10.5, 0.5]]) {
      cross(K.mb, K.grid, K.atlas, at(o, x - 8, 15, z - 8), 'kelp_plant', s, 0);
    }
    // The water: its own see-through part, lit a little like a tank lamp.
    const W = part('water');
    const wet = {tex: 'water', tint: [0.2, 0.5, 0.92], emit: 0.1};
    addBox(W.mb, W.grid, W.atlas, o, [1.5, 15, 2], [30.5, 24, 14], {up: wet, north: wet, south: wet, east: wet, west: wet});
    return {
      solid: [[0.02, 0.05, 1.98, 0.95]],
      pick: [at(o, 0, 0, 0.5), at(o, 32, 26, 15.5)],
      glass: [at(o, 1.05, 13.5, 1.55), at(o, 30.95, 25, 14.45)],
      fish: [at(o, 3, 16.5, 3.5), at(o, 29, 23, 12.5)],
    };
  }

  // A gramophone on a walnut cabinet: a black record, a brass tone arm, and
  // a flared brass horn turned toward the room. It plays when clicked.
  function gramophone(K, o) {
    const b = (f, t, faces, opts) => addBox(K.mb, K.grid, K.atlas, o, f, t, faces, opts);
    const dark = sides('dark_oak_planks');
    b([1.5, 0, 1.5], [14.5, 1.5, 14.5], dark);
    b([2, 1.5, 2], [14, 8.5, 14], {...dark, south: {tex: 'cabinet_door', uv: [2, 3, 14, 13]}});
    b([7.3, 4.3, 14], [8.7, 5.7, 14.5], brass);
    b([1.5, 8.5, 1.5], [14.5, 9.5, 14.5], dark);
    // The record, round enough at this size: two crossed slabs.
    const vinyl = solid([0.08, 0.07, 0.08]);
    b([4.8, 9.5, 5.4], [11.2, 10.1, 13], vinyl);
    b([4, 9.5, 6.2], [12, 10.05, 12.2], vinyl);
    b([7, 10.1, 8.2], [9, 10.2, 10.2], solid([0.74, 0.16, 0.14]));
    b([7.6, 10.2, 8.8], [8.4, 11, 9.6], brass);
    // The tone arm, from a post at the back right onto the record's edge.
    b([11.6, 9.5, 11.6], [12.8, 12, 12.8], brass);
    b([9.6, 11.3, 11.8], [12.4, 12, 12.6], brass);
    b([9.2, 10.2, 11.6], [10.2, 11.6, 12.8], darkBrass);
    // The horn: a neck rising from the back, then rings flaring forward.
    b([7.2, 9.5, 2.6], [8.8, 15, 4.2], brass);
    const rings = [[15.5, 3.6, 2.2], [16.9, 4.3, 2.8], [18.1, 5.3, 3.6], [19.1, 6.6, 4.6], [19.8, 8, 5.8], [20.3, 9.6, 7.2], [20.6, 10.6, 8.4]];
    for (const [y, z, s] of rings) b([8 - s / 2, y - s / 2, z - 0.9], [8 + s / 2, y + s / 2, Math.min(11.4, z + 0.9)], brass);
    const cy = 20.8;
    b([3, cy - 5, 11.4], [13, cy - 3.5, 12.4], brass);
    b([3, cy + 3.5, 11.4], [13, cy + 5, 12.4], brass);
    b([3, cy - 3.5, 11.4], [4.5, cy + 3.5, 12.4], brass);
    b([11.5, cy - 3.5, 11.4], [13, cy + 3.5, 12.4], brass);
    b([4.5, cy - 3.5, 11.42], [11.5, cy + 3.5, 11.42], {south: {tex: 'solid', tint: [0.012, 0.01, 0.008]}});
    return {
      solid: [[0.1, 0.1, 0.9, 0.9]],
      pick: [at(o, 1.5, 0, 1.5), at(o, 14.5, 26, 14.5)],
      notes: at(o, 8, cy, 12.6),
      music: true,
    };
  }

  // A wrought-iron candelabra: splayed feet, a turned stem, two arms and a
  // middle spike, each with a lit candle on a drip pan.
  function candelabra(K, o) {
    const b = (f, t, faces, opts) => addBox(K.mb, K.grid, K.atlas, o, f, t, faces, opts);
    b([3, 0, 7.2], [13, 1, 8.8], iron); b([7.2, 0, 3], [8.8, 1, 13], iron);
    for (const [x, z] of [[2.5, 7], [11.5, 7], [7, 2.5], [7, 11.5]]) b([x, 0, z], [x + 2, 1.6, z + 2], iron);
    b([6, 1, 6], [10, 3, 10], iron);
    b([7.25, 3, 7.25], [8.75, 24, 8.75], iron);
    b([6.5, 8, 6.5], [9.5, 9.5, 9.5], iron);
    b([6.6, 15, 6.6], [9.4, 16, 9.4], iron);
    b([2.6, 18, 7.4], [13.4, 19.2, 8.6], iron);
    for (const x of [2.8, 12]) b([x, 19.2, 7.4], [x + 1.2, 22, 8.6], iron);
    for (const x of [3.4, 12.6]) b([x - 1.4, 22, 6.6], [x + 1.4, 22.8, 9.4], iron);
    b([6.6, 24, 6.6], [9.4, 24.8, 9.4], iron);
    for (const [x, y, h] of [[3.4, 22.8, 5], [12.6, 22.8, 5], [8, 24.8, 6]]) {
      K.candles.push(candle(K.mb, K.grid, K.atlas, [o[0], o[1] + y / 16, o[2]], x - 8, 0, h));
    }
    return {
      solid: [[0.2, 0.2, 0.8, 0.8]],
      pick: [at(o, 2.5, 0, 2.5), at(o, 13.5, 31, 13.5)],
    };
  }

  // A porch swing: an A-frame of spruce logs, and a slatted bench hung on
  // chains that sways a little, even with nobody in it.
  function swing(K, o, part) {
    const p = (x, y, z) => at(o, x, y, z);
    for (const x of [2, 46]) {
      beam(K, p(x, 0, 1), p(x, 35.5, 8), 2.4 / 16, 'spruce_log');
      beam(K, p(x, 0, 15), p(x, 35.5, 8), 2.4 / 16, 'spruce_log');
      addBox(K.mb, K.grid, K.atlas, o, [x - 0.8, 11, 3.4], [x + 0.8, 12.6, 12.6], sides('spruce_planks'));
    }
    const log = {tex: 'spruce_log', rot: 90}, end = {tex: 'spruce_log_top'};
    addBox(K.mb, K.grid, K.atlas, o, [0, 34, 6.5], [48, 37, 9.5], {north: log, south: log, up: log, down: log, east: end, west: end});
    // The bench, built round where it hangs from the beam.
    const S = part('seat');
    const s = (f, t, faces) => addBox(S.mb, S.grid, S.atlas, [0, 0, 0], f, t, faces);
    const wood = sides('spruce_planks'), dark = sides('dark_oak_planks');
    s([-15, -26, -5], [15, -24.5, 5], wood);
    s([-15, -16.5, 3.5], [15, -15, 5], dark);
    for (const x of [-15, 13.5]) s([x, -24.5, 3.5], [x + 1.5, -16.5, 5], dark);
    for (const y of [-22, -19.5]) s([-13.5, y, 4], [13.5, y + 1, 4.8], wood);
    for (const x of [-15, 14]) {
      s([x, -20, -5], [x + 1, -19, 3.5], dark);
      s([x, -24.5, -4.5], [x + 1, -20, -3.5], dark);
    }
    for (const x of [-12, 12]) chain(S.mb, S.grid, S.atlas, [(x - 8) / 16, -24.5 / 16, -0.5], 24.5 / 16);
    return {
      solid: [[0.02, 0.05, 2.98, 0.95]],
      pick: [p(0, 0, 0), p(48, 37, 16)],
      pivots: {seat: p(24, 34, 8)},
      seat: {pos: p(24, 9.5, 8), face: 0, along: [-0.6, 0.6], swing: true, box: [p(9, 6, 3), p(39, 18, 13)]},
    };
  }

  // A stone bird bath: a mossy plinth, a column, and a shallow basin of
  // water.
  function birdbath(K, o, part) {
    const b = (f, t, faces, opts) => addBox(K.mb, K.grid, K.atlas, o, f, t, faces, opts);
    const stone = sides('smooth_stone'), brick = sides('stone_bricks'), moss = sides('moss_block');
    b([3, 0, 3], [13, 2, 13], brick);
    b([3.2, 2, 9], [7.5, 2.25, 12.8], moss);
    b([6, 2, 6], [10, 9, 10], stone);
    b([5.5, 5, 5.5], [10.5, 6, 10.5], stone);
    b([4.5, 9, 4.5], [11.5, 10.5, 11.5], stone);
    b([1.5, 10.5, 1.5], [14.5, 11.5, 14.5], stone);
    b([1, 10.5, 1], [15, 13.5, 2.5], stone);
    b([1, 10.5, 13.5], [15, 13.5, 15], stone);
    b([1, 10.5, 2.5], [2.5, 13.5, 13.5], stone);
    b([13.5, 10.5, 2.5], [15, 13.5, 13.5], stone);
    b([1.1, 13.5, 2.5], [2.4, 13.75, 8.5], moss);
    b([9, 13.5, 13.6], [14.9, 13.75, 14.9], moss);
    const W = part('water');
    addBox(W.mb, W.grid, W.atlas, o, [2.5, 11.5, 2.5], [13.5, 12.6, 13.5], {up: {tex: 'water', tint: [0.18, 0.4, 0.82]}});
    return {
      solid: [[0.1, 0.1, 0.9, 0.9]],
      pick: [at(o, 1, 0, 1), at(o, 15, 14, 15)],
    };
  }

  // A bee nest on a fence post under a little plank roof, bees busy about
  // it.
  function beehive(K, o) {
    const b = (f, t, faces, opts) => addBox(K.mb, K.grid, K.atlas, o, f, t, faces, opts);
    b([5, 0, 5], [11, 1.5, 11], sides('cobblestone'));
    b([6, 1.5, 6], [10, 15, 10], sides('spruce_planks'));
    b([3, 15, 3], [13, 16, 13], sides('dark_oak_planks'));
    const side = {tex: 'bee_nest_side', uv: [0, 0, 16, 16]}, top = {tex: 'bee_nest_top', uv: [0, 0, 16, 16]};
    b([2, 16, 2], [14, 28, 14], {south: {tex: 'bee_nest_front', uv: [0, 0, 16, 16]}, north: side, east: side, west: side, up: top, down: top});
    b([1, 28, 1], [15, 29.2, 15], sides('spruce_planks'));
    return {
      solid: [[0.32, 0.32, 0.68, 0.68]],
      pick: [at(o, 1, 0, 1), at(o, 15, 29.2, 15)],
      bees: {center: at(o, 8, 22, 8), radius: 0.72},
    };
  }

  // A brass telescope on a spruce tripod, aimed at the sky. Looked through,
  // its tube follows the view.
  function telescope(K, o, part) {
    const apex = at(o, 8, 17, 8);
    for (let i = 0; i < 3; i++) {
      const a = Math.PI / 2 + i * Math.PI * 2 / 3;
      beam(K, at(o, 8 + Math.cos(a) * 6.5, 0, 8 + Math.sin(a) * 6.5), apex, 1.4 / 16, 'spruce_planks');
    }
    addBox(K.mb, K.grid, K.atlas, o, [6.8, 16.2, 6.8], [9.2, 18.4, 9.2], darkBrass);
    const P = part('tube');
    const t = (f, to, faces) => addBox(P.mb, P.grid, P.atlas, [0, 0, 0], f, to, faces);
    t([-1.2, -2.6, -1.2], [1.2, -1.8, 1.2], darkBrass);
    t([-2, -2, -8], [2, 2, 9], brass);
    for (const z of [-2, 5]) t([-2.3, -2.3, z], [2.3, 2.3, z + 1], darkBrass);
    t([-2.7, -2.7, 9], [2.7, 2.7, 13], darkBrass);
    t([-2, -2, 13], [2, 2, 13.02], {south: {tex: 'solid', tint: [0.55, 0.75, 0.95], emit: 0.3}});
    t([-1.2, -1.2, -11], [1.2, 1.2, -8], iron);
    return {
      solid: [[0.15, 0.15, 0.85, 0.85]],
      pick: [at(o, 1.5, 0, 1.5), at(o, 14.5, 25, 14.5)],
      pivots: {tube: at(o, 8, 19, 8)},
      aim: 0.32,
      // You stoop behind it and look through the eyepiece.
      seat: {pos: at(o, 8, 0, -4), face: 0, eye: 1.25, pitch: 0.03, fov: 14, telescope: true, stand: true},
    };
  }

  const MODELS = {bed, aquarium, gramophone, candelabra, swing, birdbath, beehive, telescope};

  // Builds piece `id`: its fixed part, each moving part in its own frame,
  // the candle flames, and the facts about it.
  function build(id, atlas) {
    const [w, d] = ITEMS[id].size;
    const o = [-w / 2, 0, -d / 2];
    const main = {mb: new MeshBuilder(), grid: FLAT, atlas, candles: []};
    const parts = {};
    const part = name => (parts[name] = {mb: new MeshBuilder(), grid: FLAT, atlas, candles: []});
    const info = MODELS[id](main, o, part) || {};
    return {...info, main: main.mb, parts: Object.fromEntries(Object.entries(parts).map(([k, v]) => [k, v.mb])), flames: main.candles};
  }

  // ── The stall ──────────────────────────────────────────────────────────
  // It stands on a plot right of the path, its counter facing the path
  // (-x). Coordinates are blocks from the plot's corner.
  const STALL = {
    size: [6, 6],
    counter: [0.9, 0.95, 2.0, 4.05],
    trader: [2.6, 2.5],
    // Where he comes round the counter from, on the side nearest the house.
    gate: [2.6, -0.4],
    // Behind the counter either side of their post, turned a little toward
    // the path: [x, z, the way they face].
    llamas: [[5.0, 1.55, Math.PI + 0.35], [5.0, 3.45, -0.35]],
    // The far side of the plot, for the second llama to go round its post.
    llamaLane: 6.3,
    post: [5.75, 2.55],
    wares: {x: 1.45, y: 1.12, z0: 1.3, z1: 3.7},
    awning: {back: [3.62, 2.98], front: [0.32, 2.5], z0: 0.72, z1: 4.28},
    // His pet's corner at the counter's left end, between it and the way
    // in: where it settles, facing the path and the house a little, and the
    // spots a dog or cat wanders over to and back. The fishbowl's stand
    // goes on the same spot.
    pet: {spot: [1.6, 0.4], yaw: -2.1, roam: [[0.35, 0.36], [2.25, 0.32], [1.0, 0.5]]},
  };
  const PETS = ['dog', 'cat', 'fish'];

  // The book review desk in its own frame: the computer faces -z with its
  // back to a wall at z 5.85, and the reader sits facing it. The hall
  // places it in the house (LibraryWorld's `reviewDesk`).
  const DESK = {
    box: [[0.15, 0, 4.42], [1.65, 1.35, 5.85]],
    solids: [[0.15, 5.25, 1.65, 5.85], [0.68, 4.5, 1.12, 4.94]],
    seat: [0.9, 0.5, 4.72],
  };

  // What of the stall stops the walker, and where its lantern hangs, for the
  // hall to know before it is lit.
  function stallSolids([px, pz]) {
    const [x0, z0, x1, z1] = STALL.counter, [hx, hz] = STALL.post;
    return {
      colliders: [
        [px + x0, pz + z0, px + x1, pz + z1],
        [px + 1.0, pz + z0 - 0.18, px + 1.2, pz + z0 + 0.02], [px + 1.0, pz + z1 - 0.02, px + 1.2, pz + z1 + 0.18],
        [px + 3.42, pz + z0 - 0.18, px + 3.62, pz + z0 + 0.02], [px + 3.42, pz + z1 - 0.02, px + 3.62, pz + z1 + 0.18],
        [px + 3.75, pz + 0.75, px + 4.55, pz + 1.55], [px + 3.7, pz + 3.4, px + 4.5, pz + 4.2],
        [px + hx - 0.12, pz + hz - 0.12, px + hx + 0.12, pz + hz + 0.12],
      ],
      lamp: [px + 3.6, 1, pz + 3.3],
    };
  }

  // The stall's frame, crates and the post the llamas are tied to, in world
  // units; built into the hall, so it stands there whether the trader is
  // in or not.
  function stall(K, plot) {
    const [px, pz] = plot;
    const B = (a, c, faces, opts) => window.LibraryWorld.box(K, [px + a[0], a[1], pz + a[2]], [px + c[0], c[1], pz + c[2]], faces, opts);
    const wood = sides('spruce_planks'), dark = sides('dark_oak_planks'), log = sides('spruce_log', 'spruce_log_top');
    const [x0, z0, x1, z1] = STALL.counter;
    B([x0 + 0.1, 0, z0 + 0.05], [x1 - 0.1, 1.0, z1 - 0.05], {...wood, west: {tex: 'cabinet_door'}});
    B([x0, 1.0, z0], [x1, 1.12, z1], dark);
    B([x0 + 0.05, 0, z0], [x0 + 0.15, 0.12, z1], dark);
    // Four posts, the back pair taller so the canvas slopes to the front.
    for (const z of [z0 - 0.18, z1 - 0.02]) {
      B([1.0, 0, z], [1.2, 2.5, z + 0.2], log);
      B([3.42, 0, z], [3.62, 2.98, z + 0.2], log);
      B([1.02, 2.42, z + 0.04], [3.6, 2.54, z + 0.16], dark);
    }
    B([3.44, 2.84, z0 - 0.14], [3.6, 2.96, z1 + 0.14], dark);
    // Barrels and crates behind, a lantern on one.
    const stave = {tex: 'barrel_side', uv: [0, 0, 16, 16]};
    B([3.75, 0, 0.75], [4.55, 0.9, 1.55], {north: stave, south: stave, east: stave, west: stave, up: {tex: 'barrel_top', uv: [0, 0, 16, 16]}}, {whole: true});
    for (const [a, c, y] of [[[3.7, 3.4], [4.5, 4.2], 0], [[3.75, 3.45], [4.45, 4.15], 0.8]]) {
      B([a[0], y, a[1]], [c[0], y + 0.8 - (y ? 0.1 : 0), c[1]], wood);
      B([a[0] - 0.02, y, a[1] - 0.02], [c[0] + 0.02, y + 0.08, c[1] + 0.02], dark);
    }
    window.LibraryWorld.lantern(K.mb, K.grid, K.atlas, [px + 3.6, 1.5, pz + 3.3], false);
    // The hitching post.
    const [hx, hz] = STALL.post;
    B([hx - 0.1, 0, hz - 0.1], [hx + 0.1, 1.05, hz + 0.1], log);
    B([hx - 0.14, 1.05, hz - 0.14], [hx + 0.14, 1.15, hz + 0.14], dark);
  }

  // The canvas over the counter, in the plot's frame, hinged at its back
  // edge so the page can roll it up and out.
  function awning(K) {
    const A = STALL.awning;
    const [bx, by] = A.back, [fx, fy] = A.front;
    const len = Math.hypot(fx - bx, fy - by);
    const z = (A.z0 + A.z1) / 2;
    // Built from the hinge at the origin outward along -x.
    const dir = [(fx - bx) / len, (fy - by) / len, 0];
    beam(K, [0, 0, z], [dir[0] * len, dir[1] * len, z], [A.z1 - A.z0, 0.05], 'awning');
    // A scalloped valance along the front edge.
    const n = Math.round((A.z1 - A.z0) / 0.25);
    for (let i = 0; i < n; i++) {
      const za = A.z0 + i * (A.z1 - A.z0) / n, zb = za + (A.z1 - A.z0) / n;
      const drop = i % 2 ? 0.16 : 0.22;
      const ex = dir[0] * len, ey = dir[1] * len;
      addBox(K.mb, FLAT, K.atlas, [0, 0, 0], [(ex - 0.03) * 16, (ey - drop) * 16, (za + 0.01) * 16], [(ex + 0.02) * 16, ey * 16, (zb - 0.01) * 16], all('awning', {tint: i % 2 ? [1, 1, 1] : [0.9, 0.9, 0.9]}));
    }
    return {hinge: [bx, by]};
  }

  // The review desk in DESK's frame: a dark oak writing desk with a beige
  // tower, a CRT monitor showing its desktop, keyboard and mouse, and a
  // swivel chair facing it.
  function reviewDesk(K) {
    const B = (a, c, faces, opts) => window.LibraryWorld.box(K, a, c, faces, {light: [1, 0, 0], ...opts});
    const dark = sides('dark_oak_planks'), wood = sides('spruce_planks');
    const beige = sides('iron_block', null, null, {tint: srgb([0.86, 0.82, 0.7])});
    const shade = sides('iron_block', null, null, {tint: srgb([0.62, 0.59, 0.5])});
    const black = solid([0.08, 0.08, 0.09]);
    const cloth = sides('white_wool', null, null, {tint: srgb([0.22, 0.25, 0.32])});
    const steel = sides('iron_block', null, null, {tint: srgb([0.3, 0.3, 0.32])});
    // The desk.
    B([0.15, 0.72, 5.25], [1.65, 0.78, 5.85], dark);
    for (const x of [0.18, 1.56]) for (const z of [5.28, 5.76]) B([x, 0, z], [x + 0.06, 0.72, z + 0.06], dark);
    B([1.14, 0.3, 5.3], [1.56, 0.72, 5.82], {...wood, north: {tex: 'cabinet_door', uv: [2, 2, 14, 14]}}, {whole: true});
    B([0.24, 0.36, 5.79], [1.14, 0.72, 5.81], wood);
    // The tower, its drives and a green light.
    B([0.24, 0.78, 5.38], [0.44, 1.22, 5.8], beige, {whole: true});
    for (const y of [1.1, 1.04]) B([0.27, y, 5.374], [0.41, y + 0.03, 5.38], {north: black.north}, {whole: true});
    B([0.31, 0.86, 5.374], [0.35, 0.9, 5.38], {north: shade.north}, {whole: true});
    B([0.38, 0.87, 5.372], [0.395, 0.885, 5.38], {north: {tex: 'solid', tint: [0.2, 1, 0.3], emit: 1.4}}, {whole: true});
    // The monitor on its stand, the screen lit.
    B([0.78, 0.78, 5.52], [0.94, 0.84, 5.72], shade, {whole: true});
    B([0.6, 0.84, 5.46], [1.12, 1.3, 5.8], beige, {whole: true});
    B([0.65, 0.89, 5.455], [1.07, 1.25, 5.455], {north: {tex: 'monitor_screen', uv: [0, 0, 16, 16], emit: 0.9}}, {whole: true});
    // Keyboard and mouse.
    B([0.64, 0.78, 5.27], [1.1, 0.8, 5.4], shade, {whole: true});
    B([0.66, 0.8, 5.29], [1.08, 0.805, 5.38], {up: {tex: 'solid', tint: srgb([0.78, 0.76, 0.68])}}, {whole: true});
    B([1.16, 0.78, 5.3], [1.21, 0.805, 5.37], beige, {whole: true});
    // The chair: five-star foot, a column, seat and back.
    B([0.68, 0.04, 4.69], [1.12, 0.08, 4.75], steel, {whole: true});
    B([0.87, 0.04, 4.5], [0.93, 0.08, 4.94], steel, {whole: true});
    for (const [x, z] of [[0.68, 4.69], [1.08, 4.69], [0.87, 4.5], [0.87, 4.9]]) B([x, 0, z], [x + 0.04, 0.04, z + 0.05], black, {whole: true});
    B([0.88, 0.08, 4.7], [0.92, 0.42, 4.74], steel, {whole: true});
    B([0.68, 0.42, 4.5], [1.12, 0.5, 4.94], cloth, {whole: true});
    B([0.88, 0.5, 4.45], [0.92, 0.6, 4.49], steel, {whole: true});
    B([0.7, 0.58, 4.44], [1.1, 1.02, 4.5], cloth, {whole: true});
  }

  // The fishbowl on its stand at the pet's spot, in the plot's frame: a
  // little dark oak table on a spruce post, the bowl's iron rim and sand,
  // a sprig of kelp. The water goes into `KW` to be drawn see-through; the
  // page adds the glass and the fish in the boxes it returns.
  function fishbowl(K, KW) {
    const B = (a, c, faces, opts) => window.LibraryWorld.box(K, a, c, faces, {light: [1, 0, 0], ...opts});
    const [cx, cz] = STALL.pet.spot;
    const box = (x0, y0, z0, x1, y1, z1) => [[cx + x0, y0, cz + z0], [cx + x1, y1, cz + z1]];
    const dark = sides('dark_oak_planks'), post = sides('spruce_log', 'spruce_log_top');
    B(...box(-0.18, 0, -0.18, 0.18, 0.04, 0.18), dark, {whole: true});
    B(...box(-0.07, 0.04, -0.07, 0.07, 0.56, 0.07), post, {whole: true});
    B(...box(-0.26, 0.56, -0.26, 0.26, 0.62, 0.26), dark, {whole: true});
    const rim = sides('iron_block', null, null, {tint: srgb([0.22, 0.23, 0.25])});
    B(...box(-0.2, 0.62, -0.2, 0.2, 0.635, 0.2), rim, {whole: true});
    for (const [x0, z0, x1, z1] of [[-0.2, -0.2, 0.2, -0.18], [-0.2, 0.18, 0.2, 0.2], [-0.2, -0.18, -0.18, 0.18], [0.18, -0.18, 0.2, 0.18]]) {
      B(...box(x0, 0.93, z0, x1, 0.95, z1), rim, {whole: true});
    }
    B(...box(-0.18, 0.635, -0.18, 0.18, 0.67, 0.18), all('sand'), {whole: true});
    cross(K.mb, K.grid, K.atlas, [cx + 0.08 - 0.5, 0.67, cz - 0.07 - 0.5], 'kelp_plant', 0.13, 0);
    const wet = {tex: 'water', tint: [0.2, 0.5, 0.92], emit: 0.1};
    window.LibraryWorld.box(KW, ...box(-0.18, 0.67, -0.18, 0.18, 0.88, 0.18), {up: wet, north: wet, south: wet, east: wet, west: wet}, {light: [1, 0, 0], whole: true});
    return {
      glass: box(-0.195, 0.635, -0.195, 0.195, 0.93, 0.195),
      fish: box(-0.12, 0.71, -0.12, 0.12, 0.84, 0.12),
      pick: box(-0.26, 0, -0.26, 0.26, 0.95, 0.26),
      solid: [cx - 0.26, cz - 0.26, cx + 0.26, cz + 0.26],
      surface: [cx, 0.88, cz],
    };
  }

  // ── Creatures ──────────────────────────────────────────────────────────
  // The trader, his llamas, his pets and the bees come from one sheet: the
  // creatures' own textures out of the reader's jar where it has them,
  // luma's painted look-alikes where not. The collars are drawn over their
  // animal, dyed red.
  const SHEET = {
    w: 256, h: 160, trader: [0, 0, 64, 64], bee: [64, 0, 64, 64], llama: [0, 64, 128, 64], decor: [128, 64, 128, 64],
    wolf: [0, 128, 64, 32], cat: [64, 128, 64, 32], wolfCollar: [128, 128, 64, 32], catCollar: [192, 128, 64, 32],
  };
  const COLLAR = [176, 46, 38];

  // Where each face of a box lies on its sheet, as the game unfolds a box.
  function boxFaces(region, [u, v], [w, h, d]) {
    const [ox, oy] = region;
    const rect = (u0, v0, u1, v1) => ({
      tex: 'solid', labelKind: 3,
      labelUv: [[(ox + u0) / SHEET.w, (oy + v0) / SHEET.h], [(ox + u0) / SHEET.w, (oy + v1) / SHEET.h], [(ox + u1) / SHEET.w, (oy + v1) / SHEET.h], [(ox + u1) / SHEET.w, (oy + v0) / SHEET.h]],
    });
    const up = rect(u + d, v, u + d + w, v + d);
    if (!h) return {up, down: up};
    return {
      north: rect(u + 2 * d + w, v + d, u + 2 * d + 2 * w, v + d + h),
      south: rect(u + d, v + d, u + d + w, v + d + h),
      west: rect(u, v + d, u + d, v + d + h),
      east: rect(u + d + w, v + d, u + 2 * d + w, v + d + h),
      up, down: rect(u + d + w, v, u + d + 2 * w, v + d),
    };
  }

  // The parts of each creature facing +z, feet at y 0, in pixels: a pivot
  // and turn per part, and its boxes round the pivot.
  const TRADER = [
    {name: 'head', pivot: [0, 24, 0], boxes: [
      {from: [-4, 0, -4], size: [8, 10, 8], uv: [0, 0]},
      {from: [-4, 0, -4], size: [8, 10, 8], uv: [32, 0], grow: 0.51},
      {from: [-1, -1, 4], size: [2, 4, 2], uv: [24, 0]},
    ]},
    {name: 'body', pivot: [0, 24, 0], boxes: [
      {from: [-4, -12, -3], size: [8, 12, 6], uv: [16, 20]},
      {from: [-4, -20, -3], size: [8, 20, 6], uv: [0, 38], grow: 0.5},
    ]},
    {name: 'arms', pivot: [0, 21, 1], rot: [-0.75, 0, 0], boxes: [
      {from: [-8, -6, -2], size: [4, 8, 4], uv: [44, 22]},
      {from: [4, -6, -2], size: [4, 8, 4], uv: [44, 22]},
      {from: [-4, -6, -2], size: [8, 4, 4], uv: [40, 38]},
    ]},
    {name: 'rightLeg', pivot: [-2, 12, 0], boxes: [{from: [-2, -12, -2], size: [4, 12, 4], uv: [0, 22]}]},
    {name: 'leftLeg', pivot: [2, 12, 0], boxes: [{from: [-2, -12, -2], size: [4, 12, 4], uv: [0, 22]}]},
  ];
  const LLAMA_LEG = [{from: [-2, -14, -2], size: [4, 14, 4], uv: [29, 29]}];
  const LLAMA = [
    {name: 'head', pivot: [0, 17, 6], decor: true, boxes: [
      {from: [-2, 10, 1], size: [4, 4, 9], uv: [0, 0]},
      {from: [-4, -2, 0], size: [8, 18, 6], uv: [0, 14]},
      {from: [-4, 16, 2], size: [3, 3, 2], uv: [17, 0]},
      {from: [1, 16, 2], size: [3, 3, 2], uv: [17, 0]},
    ]},
    {name: 'body', pivot: [0, 19, -2], rot: [Math.PI / 2, 0, 0], decor: true, boxes: [{from: [-6, -8, -3], size: [12, 18, 10], uv: [29, 0]}]},
    {name: 'rightHind', pivot: [-3.5, 14, -6], boxes: LLAMA_LEG},
    {name: 'leftHind', pivot: [3.5, 14, -6], boxes: LLAMA_LEG},
    {name: 'rightFront', pivot: [-3.5, 14, 5], boxes: LLAMA_LEG},
    {name: 'leftFront', pivot: [3.5, 14, 5], boxes: LLAMA_LEG},
  ];
  const BEE = [
    {name: 'body', pivot: [0, 0, 0], boxes: [
      {from: [-3.5, -3, -5], size: [7, 7, 10], uv: [0, 0]},
      {from: [1.5, 2, 5], size: [1, 2, 3], uv: [2, 0]},
      {from: [-2.5, 2, 5], size: [1, 2, 3], uv: [2, 3]},
    ]},
    {name: 'rightWing', pivot: [-1.5, 4, 3], rot: [0, 0.2618, 0], boxes: [{from: [-9, 0, -6], size: [9, 0, 6], uv: [0, 18]}]},
    {name: 'leftWing', pivot: [1.5, 4, 3], rot: [0, -0.2618, 0], boxes: [{from: [0, 0, -6], size: [9, 0, 6], uv: [0, 18]}]},
  ];
  // The dog is the game's tamed wolf. Its sitting and lying poses, and the
  // cat's, move and turn parts from where they stand: [x, y, z] pivot and
  // turn about x, in pixels and radians.
  const WOLF_LEG = [{from: [0, -8, -1], size: [2, 8, 2], uv: [0, 18]}];
  const WOLF = [
    {name: 'head', pivot: [-1, 10.5, 7], boxes: [
      {from: [-2, -3, -2], size: [6, 6, 4], uv: [0, 0]},
      {from: [-2, 3, -1], size: [2, 2, 1], uv: [16, 14]},
      {from: [2, 3, -1], size: [2, 2, 1], uv: [16, 14]},
      {from: [-0.5, -3, 1], size: [3, 3, 4], uv: [0, 10]},
    ]},
    {name: 'body', pivot: [0, 10, -2], rot: [Math.PI / 2, 0, 0], boxes: [{from: [-3, -7, -3], size: [6, 9, 6], uv: [18, 14]}]},
    {name: 'mane', pivot: [-1, 10, 3], rot: [Math.PI / 2, 0, 0], collar: true, boxes: [{from: [-3, -3, -4], size: [8, 6, 7], uv: [21, 0]}]},
    {name: 'rightHind', pivot: [-2.5, 8, -7], boxes: WOLF_LEG},
    {name: 'leftHind', pivot: [0.5, 8, -7], boxes: WOLF_LEG},
    {name: 'rightFront', pivot: [-2.5, 8, 4], boxes: WOLF_LEG},
    {name: 'leftFront', pivot: [0.5, 8, 4], boxes: WOLF_LEG},
    {name: 'tail', pivot: [-1, 12, -8], rot: [1.45, 0, 0], order: 'ZYX', boxes: [{from: [0, -8, -1], size: [2, 8, 2], uv: [9, 18]}]},
  ];
  const WOLF_POSES = {
    sit: {
      mane: {pos: [-1, 8, 3], rot: 1.2566}, body: {pos: [0, 6, 0], rot: Math.PI / 4}, tail: {pos: [-1, 3, -6]},
      rightHind: {pos: [-2.5, 1.3, -2], rot: -Math.PI / 2}, leftHind: {pos: [0.5, 1.3, -2], rot: -Math.PI / 2},
      rightFront: {pos: [-2.49, 7, 4], rot: -0.4712}, leftFront: {pos: [0.51, 7, 4], rot: -0.4712},
    },
    lie: {
      head: {pos: [-1, 6.5, 7]}, mane: {pos: [-1, 5, 3]}, body: {pos: [0, 4, -2]}, tail: {pos: [-1, 4, -8], rot: 1.62},
      rightHind: {pos: [-2.5, 1, -7], rot: -Math.PI / 2}, leftHind: {pos: [0.5, 1, -7], rot: -Math.PI / 2},
      rightFront: {pos: [-2.5, 1, 4], rot: -Math.PI / 2}, leftFront: {pos: [0.5, 1, 4], rot: -Math.PI / 2},
    },
  };
  const CAT_HIND = [{from: [-1, -6, -3], size: [2, 6, 2], uv: [8, 13]}];
  const CAT_FRONT = [{from: [-1, -10, -2], size: [2, 10, 2], uv: [40, 0]}];
  const CAT = [
    {name: 'head', pivot: [0, 9, 9], boxes: [
      {from: [-2.5, -2, -2], size: [5, 4, 5], uv: [0, 0]},
      {from: [-1.5, -2, 2], size: [3, 2, 2], uv: [0, 24]},
      {from: [-2, 2, -2], size: [1, 1, 2], uv: [0, 10]},
      {from: [1, 2, -2], size: [1, 1, 2], uv: [6, 10]},
    ]},
    {name: 'body', pivot: [0, 12, 10], rot: [Math.PI / 2, 0, 0], collar: true, boxes: [{from: [-2, -19, 2], size: [4, 16, 6], uv: [20, 0]}]},
    {name: 'tail1', pivot: [0, 9, -8], rot: [0.9, 0, 0], order: 'ZYX', boxes: [{from: [-0.5, -8, -1], size: [1, 8, 1], uv: [0, 15]}]},
    {name: 'tail2', parent: 'tail1', pivot: [0, -8, 0], rot: [0.83, 0, 0], order: 'ZYX', boxes: [{from: [-0.5, -8, -1], size: [1, 8, 1], uv: [4, 15]}]},
    {name: 'leftHind', pivot: [1.1, 6, -5], boxes: CAT_HIND},
    {name: 'rightHind', pivot: [-1.1, 6, -5], boxes: CAT_HIND},
    {name: 'leftFront', pivot: [1.2, 9.9, 5], boxes: CAT_FRONT},
    {name: 'rightFront', pivot: [-1.2, 9.9, 5], boxes: CAT_FRONT},
  ];
  const CAT_POSES = {
    sit: {
      body: {pos: [0, 16, 5], rot: Math.PI / 4}, head: {pos: [0, 12.3, 8]},
      tail1: {pos: [0, 1, -6], rot: 1.7279}, tail2: {rot: 0.94},
      leftFront: {pos: [1.2, 9.9, 7], rot: -0.157}, rightFront: {pos: [-1.2, 9.9, 7], rot: -0.157},
      leftHind: {pos: [1.1, 3, -1], rot: -Math.PI / 2}, rightHind: {pos: [-1.1, 3, -1], rot: -Math.PI / 2},
    },
    lie: {
      body: {pos: [0, 8, 10]}, head: {pos: [0, 6.5, 9.5]}, tail1: {pos: [0, 2, -8], rot: 1.5}, tail2: {rot: 0.1},
      leftFront: {pos: [1.2, 1, 5], rot: Math.PI / 2}, rightFront: {pos: [-1.2, 1, 5], rot: Math.PI / 2},
      leftHind: {pos: [1.1, 1, -5], rot: -Math.PI / 2}, rightHind: {pos: [-1.1, 1, -5], rot: -Math.PI / 2},
    },
  };
  const CREATURES = {
    trader: {parts: TRADER, region: 'trader', scale: 15 / 16}, llama: {parts: LLAMA, region: 'llama', scale: 1}, bee: {parts: BEE, region: 'bee', scale: 1},
    dog: {parts: WOLF, region: 'wolf', collar: 'wolfCollar', scale: 1, poses: WOLF_POSES},
    cat: {parts: CAT, region: 'cat', collar: 'catCollar', scale: 0.8, poses: CAT_POSES},
  };

  // A creature as a group of posable parts. Returns the group and its parts
  // by name.
  function creature(T, kind, atlas, material, light) {
    const def = CREATURES[kind];
    const group = new T.Group();
    const parts = {};
    for (const p of def.parts) {
      const mb = new MeshBuilder();
      const layers = [[SHEET[def.region], 0]];
      if (p.decor) layers.push([SHEET.decor, 0.5]);
      if (p.collar && def.collar) layers.push([SHEET[def.collar], 0.06]);
      for (const [region, extra] of layers) {
        for (const bx of p.boxes) {
          const g = (bx.grow || 0) + extra;
          const to = bx.from.map((v, k) => v + bx.size[k]);
          addBox(mb, FLAT, atlas, [0, 0, 0], bx.from.map(v => v - g), to.map(v => v + g), boxFaces(region, bx.uv, bx.size), {light, ao: 1});
        }
      }
      const pivot = new T.Group();
      pivot.position.set(p.pivot[0] / 16, p.pivot[1] / 16, p.pivot[2] / 16);
      if (p.order) pivot.rotation.order = p.order;
      if (p.rot) pivot.rotation.set(...p.rot);
      pivot.userData.rest = p.rot ? p.rot.slice() : [0, 0, 0];
      pivot.userData.pos = pivot.position.toArray();
      const mesh = new T.Mesh(mb.geometry(T), material);
      pivot.add(mesh);
      (p.parent ? parts[p.parent] : group).add(pivot);
      parts[p.name] = pivot;
    }
    const scaled = new T.Group();
    group.scale.setScalar(def.scale);
    scaled.add(group);
    return {group: scaled, parts, poses: def.poses || {}};
  }

  // A little tropical fish facing +z, in the colours given.
  function fish(T, atlas, material, [body, stripe], light) {
    const mb = new MeshBuilder();
    const b = (f, t, c) => addBox(mb, FLAT, atlas, [0, 0, 0], f, t, solid(c), {light, ao: 1});
    b([-0.7, -1, -2], [0.7, 1, 2], body);
    b([-0.75, -1.05, -0.3], [0.75, 1.05, 0.4], stripe);
    b([-0.12, -1.3, -3.4], [0.12, 1.3, -2], body);
    b([-0.12, 1, -1.2], [0.12, 1.6, 1], stripe);
    for (const x of [-0.78, 0.7]) b([x, 0.2, 1.1], [x + 0.08, 0.6, 1.5], [0.05, 0.05, 0.05]);
    return new T.Mesh(mb.geometry(T), material);
  }
  const FISH_COLOURS = [[[0.98, 0.45, 0.1], [0.98, 0.98, 0.96]], [[0.16, 0.36, 0.86], [0.98, 0.84, 0.18]], [[0.98, 0.86, 0.2], [0.1, 0.1, 0.12]]];

  // ── The creatures' sheet ───────────────────────────────────────────────
  function loadImage(data) {
    return new Promise(resolve => {
      const image = new Image();
      image.onload = () => resolve(image);
      image.onerror = () => resolve(null);
      image.src = 'data:image/png;base64,' + data;
    });
  }

  // Paints a box's six faces as unfolded, each pixel from `colour(face, x,
  // y)` with x, y within the face.
  function paintBox(ctx, [ox, oy], [u, v], [w, h, d], colour) {
    const faces = {
      up: [u + d, v, w, d], down: [u + d + w, v, w, d],
      right: [u, v + d, d, h], front: [u + d, v + d, w, h], left: [u + d + w, v + d, d, h], back: [u + 2 * d + w, v + d, w, h],
    };
    for (const [face, [fx, fy, fw, fh]] of Object.entries(faces)) {
      for (let y = 0; y < fh; y++) for (let x = 0; x < fw; x++) {
        const c = colour(face, x, y, fw, fh);
        if (!c) continue;
        ctx.fillStyle = `rgba(${c[0]},${c[1]},${c[2]},${(c[3] ?? 255) / 255})`;
        ctx.fillRect(ox + fx + x, oy + fy + y, 1, 1);
      }
    }
  }

  function paintTrader(ctx, at) {
    const r = LibraryTextures.rng('trader');
    const vary = (c, k = 0.08) => { const f = 1 - k / 2 + r() * k; return c.map(v => Math.round(v * f)); };
    const SKIN = [182, 132, 98], ROBE = [44, 66, 132], DARK = [30, 44, 96], TRIM = [188, 150, 70];
    paintBox(ctx, at, [0, 0], [8, 10, 8], (face, x, y) => {
      if (face !== 'front') return vary(SKIN);
      if (y === 3 && x >= 1 && x <= 6) return [58, 40, 28];
      if (y === 4 && (x === 1 || x === 6)) return [240, 240, 236];
      if (y === 4 && (x === 2 || x === 5)) return [40, 120, 60];
      if (y >= 8) return vary([150, 104, 76]);
      return vary(SKIN);
    });
    paintBox(ctx, at, [24, 0], [2, 4, 2], () => vary([160, 112, 82]));
    paintBox(ctx, at, [32, 0], [8, 10, 8], (face, x, y) => {
      if (face === 'front' && x >= 1 && x <= 6 && y >= 2) return null;
      if (face === 'down') return null;
      return vary(y === 9 ? DARK : ROBE);
    });
    paintBox(ctx, at, [16, 20], [8, 12, 6], () => vary(ROBE));
    paintBox(ctx, at, [0, 38], [8, 20, 6], (face, x, y, fw, fh) => {
      if (face === 'up') return null;
      if (y >= fh - 2) return vary(TRIM);
      if (face === 'front' && (x === 3 || x === 4)) return vary(DARK);
      if (y === 7) return vary([96, 64, 36]);
      return vary(ROBE);
    });
    paintBox(ctx, at, [44, 22], [4, 8, 4], (face, x, y, fw, fh) => (y >= fh - 2 || face === 'down' ? vary(SKIN) : vary(ROBE)));
    paintBox(ctx, at, [40, 38], [8, 4, 4], (face, x) => (face === 'front' && x >= 2 && x <= 5 ? vary(SKIN) : vary(ROBE)));
    paintBox(ctx, at, [0, 22], [4, 12, 4], (face, x, y, fw, fh) => (y >= fh - 2 || face === 'down' ? vary([70, 52, 36]) : vary(DARK)));
  }

  function paintLlama(ctx, at) {
    const r = LibraryTextures.rng('llama');
    const wool = () => { const f = 0.9 + r() * 0.14; return [232, 214, 176].map(v => Math.round(Math.min(255, v * f))); };
    paintBox(ctx, at, [0, 0], [4, 4, 9], (face, x, y) => (face === 'front' ? (y === 1 && (x === 0 || x === 3) ? [60, 46, 36] : [196, 176, 142]) : wool()));
    paintBox(ctx, at, [0, 14], [8, 18, 6], (face, x, y) => (face === 'front' && y === 2 && (x === 1 || x === 6) ? [24, 20, 18] : wool()));
    paintBox(ctx, at, [17, 0], [3, 3, 2], () => wool());
    paintBox(ctx, at, [29, 0], [12, 18, 10], () => wool());
    paintBox(ctx, at, [29, 29], [4, 14, 4], (face, x, y, fw, fh) => (y >= fh - 2 || face === 'down' ? [120, 96, 70] : wool()));
  }

  function paintDecor(ctx, at) {
    const BLUE = [44, 74, 156], GOLD = [222, 172, 52], RED = [168, 40, 36];
    const carpet = (x, y, fw, fh) => {
      if (x === 0 || y === 0 || x === fw - 1 || y === fh - 1) return GOLD;
      return (x + y) % 6 === 0 || (x - y + 60) % 6 === 0 ? RED : BLUE;
    };
    paintBox(ctx, at, [29, 0], [12, 18, 10], (face, x, y, fw, fh) => {
      if (face === 'back') return carpet(x, y, fw, fh);
      if (face === 'right' && x < 4) return x === 3 ? GOLD : BLUE;
      if (face === 'left' && x >= fw - 4) return x === fw - 4 ? GOLD : BLUE;
      return null;
    });
    paintBox(ctx, at, [0, 14], [8, 18, 6], (face, x, y) => (y === 9 ? GOLD : null));
  }

  function paintBee(ctx, at) {
    const YELLOW = [236, 190, 40], BLACK = [38, 30, 24], BROWN = [74, 50, 26];
    paintBox(ctx, at, [0, 0], [7, 7, 10], (face, x, y) => {
      if (face === 'front') return (y === 2 && (x === 1 || x === 5)) ? BLACK : BROWN;
      if (face === 'back') return YELLOW;
      const along = face === 'up' || face === 'down' ? y : face === 'right' ? x : 9 - x;
      return along === 3 || along === 4 || along === 7 ? BLACK : YELLOW;
    });
    paintBox(ctx, at, [2, 0], [1, 2, 3], () => BLACK);
    paintBox(ctx, at, [2, 3], [1, 2, 3], () => BLACK);
    paintBox(ctx, at, [0, 18], [9, 0, 6], () => [214, 232, 246]);
  }

  // A tame wolf: pale grey, its back and tail a shade darker.
  function paintWolf(ctx, at) {
    const r = LibraryTextures.rng('wolf');
    const fur = (c = [214, 210, 204]) => { const f = 0.92 + r() * 0.12; return c.map(v => Math.round(Math.min(255, v * f))); };
    const BACK = [166, 160, 152];
    paintBox(ctx, at, [0, 0], [6, 6, 4], (face, x, y) => (face === 'front' && y === 2 && (x === 1 || x === 4) ? [36, 30, 28] : fur()));
    paintBox(ctx, at, [16, 14], [2, 2, 1], () => fur(BACK));
    paintBox(ctx, at, [0, 10], [3, 3, 4], (face, x, y) => (face === 'front' && y === 0 && x === 1 ? [30, 26, 24] : fur()));
    paintBox(ctx, at, [18, 14], [6, 9, 6], face => fur(face === 'back' ? BACK : undefined));
    paintBox(ctx, at, [21, 0], [8, 6, 7], face => fur(face === 'back' ? BACK : undefined));
    paintBox(ctx, at, [0, 18], [2, 8, 2], () => fur());
    paintBox(ctx, at, [9, 18], [2, 8, 2], (face, x, y, fw, fh) => fur(y >= fh - 2 ? [236, 234, 230] : BACK));
  }

  // A ginger cat: stripes down its back and tail, white paws and muzzle.
  function paintCat(ctx, at) {
    const r = LibraryTextures.rng('cat');
    const GINGER = [218, 138, 58], STRIPE = [170, 92, 36], WHITE = [240, 232, 220];
    const fur = (c = GINGER) => { const f = 0.94 + r() * 0.1; return c.map(v => Math.round(Math.min(255, v * f))); };
    paintBox(ctx, at, [0, 0], [5, 4, 5], (face, x, y) => {
      if (face === 'front' && y === 1 && (x === 1 || x === 3)) return [92, 168, 52];
      if (face === 'up' && x % 2 === 0) return fur(STRIPE);
      return fur();
    });
    paintBox(ctx, at, [0, 24], [3, 2, 2], (face, x, y) => (face === 'front' && y === 0 && x === 1 ? [222, 120, 130] : fur(WHITE)));
    paintBox(ctx, at, [0, 10], [1, 1, 2], () => fur());
    paintBox(ctx, at, [6, 10], [1, 1, 2], () => fur());
    paintBox(ctx, at, [20, 0], [4, 16, 6], (face, x, y) => (face === 'front' ? fur(WHITE) : y % 3 === 0 ? fur(STRIPE) : fur()));
    paintBox(ctx, at, [0, 15], [1, 8, 1], (face, x, y) => (y % 3 === 0 ? fur(STRIPE) : fur()));
    paintBox(ctx, at, [4, 15], [1, 8, 1], (face, x, y, fw, fh) => (y >= fh - 2 ? fur(WHITE) : y % 3 === 0 ? fur(STRIPE) : fur()));
    paintBox(ctx, at, [8, 13], [2, 6, 2], (face, x, y, fw, fh) => (y >= fh - 1 || face === 'down' ? fur(WHITE) : fur()));
    paintBox(ctx, at, [40, 0], [2, 10, 2], (face, x, y, fw, fh) => (y >= fh - 2 || face === 'down' ? fur(WHITE) : fur()));
  }

  // A band round the neck: the first rows of the box's sides, which the
  // turned body brings up to its front end.
  const paintCollar = (u, size) => (ctx, at) => paintBox(ctx, at, u, size, (face, x, y) => (face !== 'up' && face !== 'down' && y < 2 ? COLLAR : null));

  const PAINTERS = {
    trader: paintTrader, bee: paintBee, llama: paintLlama, decor: paintDecor, wolf: paintWolf, cat: paintCat,
    wolfCollar: paintCollar([21, 0], [8, 6, 7]), catCollar: paintCollar([20, 0], [4, 16, 6]),
  };
  const DYED = new Set(['wolfCollar', 'catCollar']);

  // A grey layer coloured in, the way the game dyes a collar.
  function dye(ctx, [x, y, w, h], colour) {
    const img = ctx.getImageData(x, y, w, h);
    for (let i = 0; i < img.data.length; i += 4) for (let k = 0; k < 3; k++) img.data[i + k] = Math.round(img.data[i + k] * colour[k] / 255);
    ctx.putImageData(img, x, y);
  }

  // The sheet as a canvas, from the reader's jar where it has the files.
  async function entitySheet(files = {}) {
    const canvas = document.createElement('canvas');
    canvas.width = SHEET.w; canvas.height = SHEET.h;
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    let vanilla = 0;
    for (const [kind, paths] of Object.entries(LibraryTextures.ENTITY_FILES)) {
      const [x, y, w, h] = SHEET[kind];
      const path = paths.find(p => files[p]);
      const image = path ? await loadImage(files[path]) : null;
      if (image && image.width >= w / 2) {
        ctx.drawImage(image, 0, 0, image.width, image.height, x, y, w, h);
        if (DYED.has(kind)) dye(ctx, [x, y, w, h], COLLAR);
        vanilla++;
      } else {
        PAINTERS[kind](ctx, [x, y]);
      }
    }
    return {canvas, vanilla};
  }

  window.LibraryGoods = {
    CATALOG, ITEMS, MODELS, STALL, DESK, PETS, SHEET, FISH_COLOURS,
    build, turn, footprint, beam, stall, stallSolids, awning, reviewDesk, fishbowl, creature, fish, entitySheet, boxFaces,
  };
})();
