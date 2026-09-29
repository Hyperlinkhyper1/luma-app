// The hall's furniture: every model is luma's own, built from small boxes
// the way the game builds its block models, and textured from the same
// atlas as the blocks.
//
// Each function takes the build context K ({mb, grid, atlas, candles}) and
// an origin in block units; sizes inside a model are in pixels (16 to a
// block), turned about the model's centre by `yaw` where given.
(() => {
  'use strict';
  const {addBox, box, sides, all, candle, cross, chain, frame} = window.LibraryWorld;

  const b = (K, o, from, to, faces, opts = {}) => addBox(K.mb, K.grid, K.atlas, o, from, to, faces, opts);
  const brass = sides('yellow_wool', null, null, {tint: [0.78, 0.56, 0.26]});
  const LEATHERS = [[0.24, 0.07, 0.05], [0.07, 0.1, 0.2], [0.09, 0.16, 0.08], [0.3, 0.17, 0.07], [0.14, 0.06, 0.14], [0.36, 0.24, 0.12]];

  // Where a point of a turned model lands in the world.
  function toWorld(o, p, yaw, pivot = [8, 8, 8]) {
    const cos = Math.cos(yaw), sin = Math.sin(yaw);
    const lx = p[0] - pivot[0], lz = p[2] - pivot[2];
    return [o[0] + (pivot[0] + lx * cos - lz * sin) / 16, o[1] + p[1] / 16, o[2] + (pivot[2] + lx * sin + lz * cos) / 16];
  }

  // ── Seating ────────────────────────────────────────────────────────────
  // A wing armchair; its front looks toward local -z before turning.
  function armchair(K, o, yaw, fabric) {
    const opts = {yaw};
    const cloth = sides(fabric), wood = sides('dark_oak_planks');
    const plump = sides(fabric, null, null, {tint: [1.12, 1.08, 1.06]});
    for (const [x, z] of [[1, 1], [13, 1], [1, 13], [13, 13]]) b(K, o, [x, 0, z], [x + 2, 3, z + 2], wood, opts);
    b(K, o, [0, 3, 0], [16, 7, 16], cloth, opts);
    b(K, o, [2, 7, 0.5], [14, 10, 13], plump, opts);
    b(K, o, [0.5, 7, 13], [15.5, 20, 16], cloth, opts);
    b(K, o, [1, 20, 13.5], [15, 21.5, 16], plump, opts);
    b(K, o, [-0.5, 7, 0.5], [2.5, 12, 13], cloth, opts);
    b(K, o, [13.5, 7, 0.5], [16.5, 12, 13], cloth, opts);
    b(K, o, [-1, 12, 0], [3, 13.5, 13.5], plump, opts);
    b(K, o, [13, 12, 0], [17, 13.5, 13.5], plump, opts);
    b(K, o, [4, 10, 10.5], [12, 17, 13], sides('yellow_wool', null, null, {tint: [0.86, 0.74, 0.52]}), opts);
  }

  // A cushioned bench under a window, against the wall on `side` (+1 the
  // -x wall, -1 the +x wall), from za to zb.
  function windowSeat(K, side, x, za, zb) {
    const x0 = side > 0 ? x : x + 0.25, x1 = side > 0 ? x + 0.75 : x + 1;
    const front = side > 0 ? 'east' : 'west';
    box(K, [x0, 0, za], [x1, 0.45, zb], {[front]: {tex: 'cabinet_door'}, north: {tex: 'spruce_planks'}, south: {tex: 'spruce_planks'}});
    box(K, [x0 - (side > 0 ? 0 : 0.04), 0.45, za], [x1 + (side > 0 ? 0.04 : 0), 0.5, zb], sides('dark_oak_planks'));
    box(K, [x0 + 0.03, 0.5, za + 0.05], [x1 - 0.03, 0.64, zb - 0.05], sides('white_wool', null, null, {tint: [0.94, 0.88, 0.76]}));
    const wall = side > 0 ? x0 : x1;
    const pillows = [['red_wool', za + 0.12], ['green_wool', za + 0.62], ['blue_wool', zb - 0.62]];
    for (const [tex, z] of pillows) {
      const a = side > 0 ? wall + 0.03 : wall - 0.2, c = side > 0 ? wall + 0.2 : wall - 0.03;
      box(K, [a, 0.64, z], [c, 1.02, z + 0.46], sides(tex, null, null, {tint: [0.9, 0.9, 0.9]}));
    }
    // A folded blanket at the far end, and a candle on the sill.
    box(K, [x0 + 0.1, 0.64, zb - 0.55], [x1 - 0.1, 0.72, zb - 0.1], {up: {tex: 'rug_red'}, north: {tex: 'rug_red_border'}, south: {tex: 'rug_red_border'}, east: {tex: 'rug_red_border'}, west: {tex: 'rug_red_border'}});
    const zc = Math.floor((za + zb) / 2);
    K.candles.push(candle(K.mb, K.grid, K.atlas, [side > 0 ? x : x, 1 + 1.5 / 16, zc], side > 0 ? -6.5 : 6.5, 0, 5));
  }

  // ── Tables ─────────────────────────────────────────────────────────────
  // The writing desk: two banks of drawers under a dark oak top with a
  // green leather inset. `o` is its north-west corner, two blocks wide.
  function desk(K, o) {
    const top = sides('dark_oak_planks'), body = sides('spruce_planks');
    b(K, o, [-1, 14.5, -1], [33, 16, 17], top);
    b(K, o, [3, 16, 2], [29, 16.05, 14], {up: {tex: 'green_wool', tint: [0.72, 0.8, 0.7]}});
    b(K, o, [0, 0, 1], [9, 14.5, 15], body);
    b(K, o, [23, 0, 1], [32, 14.5, 15], body);
    b(K, o, [9, 11, 2], [23, 14.5, 15], body);
    const drawer = {south: {tex: 'cabinet_door', uv: [2, 3, 14, 13]}, east: {tex: 'spruce_planks'}, west: {tex: 'spruce_planks'}, up: {tex: 'spruce_planks'}, down: {tex: 'spruce_planks'}};
    for (const x0 of [0, 23]) for (const y0 of [1, 5.5, 10]) b(K, o, [x0 + 0.8, y0, 15], [x0 + 8.2, y0 + 3.8, 15.6], drawer);
    b(K, o, [10, 11.5, 15], [22, 14, 15.6], drawer);
    // Things on it: candles at the back, an inkwell with a quill, books.
    const on = [o[0], o[1] + 1, o[2]];
    K.candles.push(candle(K.mb, K.grid, K.atlas, on, -5, -5, 6));
    K.candles.push(candle(K.mb, K.grid, K.atlas, on, -2, -6, 4));
    const ink = [o[0] + 1, o[1] + 1, o[2]];
    b(K, ink, [8, 0, 9], [12, 2.5, 13], sides('solid'), {tint: [0.1, 0.1, 0.13]});
    b(K, ink, [9, 2.5, 10], [11, 3.2, 12], sides('solid'), {tint: [0.08, 0.08, 0.1]});
    for (const yaw of [0.35, 0.35 + Math.PI / 2]) {
      b(K, ink, [7.5, 3, 11], [14.5, 14, 11], {north: {tex: 'feather', uv: [0, 0, 16, 16], double: true, rot: 0}}, {yaw, pivot: [10, 0, 11], ao: 1});
    }
    bookStack(K, [o[0] + 1.22, o[1] + 1, o[2] - 0.28], 3, 'desk', 0.2);
  }

  // A pedestal side table, its top cut to an octagon.
  function sideTable(K, o, what) {
    const wood = sides('dark_oak_planks');
    b(K, o, [4, 13, 4], [12, 14.5, 12], wood);
    b(K, o, [2, 13, 4], [4, 14.5, 12], wood); b(K, o, [12, 13, 4], [14, 14.5, 12], wood);
    b(K, o, [4, 13, 2], [12, 14.5, 4], wood); b(K, o, [4, 13, 12], [12, 14.5, 14], wood);
    b(K, o, [7, 1.5, 7], [9, 13, 9], sides('spruce_planks'));
    b(K, o, [3, 0, 7], [13, 1.5, 9], wood); b(K, o, [7, 0, 3], [9, 1.5, 7], wood); b(K, o, [7, 0, 9], [9, 1.5, 13], wood);
    const top = [o[0], o[1] + 14.5 / 16, o[2]];
    if (what === 'tea') {
      teacup(K, top, 2, 2);
      K.candles.push(candle(K.mb, K.grid, K.atlas, top, -3, -2, 5));
      bookStack(K, [top[0] - 0.12, top[1], top[2] + 0.18], 2, 'side', -0.3);
    }
  }

  function teacup(K, o, dx, dz) {
    b(K, o, [5 + dx, 0, 5 + dz], [11 + dx, 0.6, 11 + dz], sides('white_wool'));
    b(K, o, [6.5 + dx, 0.6, 6.5 + dz], [9.5 + dx, 3.4, 9.5 + dz], {north: {tex: 'teacup'}, south: {tex: 'teacup'}, east: {tex: 'teacup'}, west: {tex: 'teacup'}, up: {tex: 'brown_wool', tint: [0.5, 0.32, 0.2]}});
    b(K, o, [9.5 + dx, 1.4, 7.6 + dz], [10.6 + dx, 2.8, 8.4 + dz], sides('white_wool'));
  }

  // Books lying one on another, each a little askew.
  function bookStack(K, o, count, seed, yaw = 0) {
    const r = LibraryTextures.rng('stack' + seed);
    let y = 0;
    for (let i = 0; i < count; i++) {
      const tint = LEATHERS[Math.floor(r() * LEATHERS.length)];
      const w = 8 + r() * 3, d = 6 + r() * 2, h = 1.4 + r() * 1.2;
      const leather = {tex: 'leather', tint}, pages = {tex: 'pages', ao: 0.92};
      const x0 = 8 - w / 2, x1 = 8 + w / 2, z0 = 8 - d / 2, z1 = 8 + d / 2, c = 0.45;
      const opts = {yaw: yaw + (r() - 0.5) * 0.5};
      // Covers a touch bigger than the pages, joined by the spine.
      b(K, o, [x0, y, z0], [x1, y + c, z1], all('leather', {tint}), opts);
      b(K, o, [x0, y + h - c, z0], [x1, y + h, z1], all('leather', {tint}), opts);
      b(K, o, [x0, y + c, z0], [x0 + c, y + h - c, z1], {west: {tex: 'spine_deco', tint, uv: [0, 3, 16, 13], rot: 90}, north: leather, south: leather}, opts);
      b(K, o, [x0 + c, y + c, z0 + 0.35], [x1 - 0.35, y + h - c, z1 - 0.35], {east: pages, north: pages, south: pages}, opts);
      y += h;
    }
    return y / 16;
  }

  // ── Things standing about ──────────────────────────────────────────────
  function globe(K, o) {
    const wood = sides('dark_oak_planks');
    b(K, o, [4, 0, 4], [12, 1.5, 12], wood);
    b(K, o, [7.25, 1.5, 7.25], [8.75, 6.5, 8.75], wood);
    const cy = 11.5, R = 4.6;
    for (let y = Math.floor(cy - R); y < cy + R; y++) {
      const dy = y + 0.5 - cy;
      const r = Math.sqrt(Math.max(0, R * R - dy * dy));
      if (r < 1) continue;
      const h = Math.round(r * 2) / 2;
      b(K, o, [8 - h, y, 8 - h], [8 + h, y + 1, 8 + h], all('globe'), {yaw: 0.3});
    }
    // A brass meridian round one side.
    for (let a = -80; a <= 80; a += 20) {
      const t = a * Math.PI / 180;
      const x = 8 + (R + 1) * Math.cos(t), y = cy + (R + 1) * Math.sin(t);
      b(K, o, [x - 0.6, y - 0.6, 7.4], [x + 0.6, y + 0.6, 8.6], brass, {yaw: 0.3});
    }
  }

  function floorLamp(K, o) {
    const wood = sides('dark_oak_planks');
    b(K, o, [4, 0, 4], [12, 1.5, 12], wood);
    b(K, o, [7.25, 1.5, 7.25], [8.75, 23, 8.75], wood);
    const shade = {tex: 'lampshade', emit: 0.55};
    b(K, o, [3, 23, 3], [13, 31, 13], {north: shade, south: shade, east: shade, west: shade, down: {tex: 'lampshade', emit: 1.2}, up: {tex: 'lampshade', emit: 0.3}});
    b(K, o, [7, 31, 7], [9, 32.5, 9], brass);
  }

  // A terracotta pot; `plant` is 'fern', 'azalea' or 'tall'.
  function pot(K, o, plant, big = false) {
    const tc = {tex: 'terracotta', double: true};
    const [a, h] = big ? [3.5, 9] : [5, 6];
    b(K, o, [a, 0, a], [16 - a, h, 16 - a], {north: tc, south: tc, east: tc, west: tc, down: tc});
    b(K, o, [a - 0.5, h - 1.5, a - 0.5], [16.5 - a, h + 0.5, 16.5 - a], {north: tc, south: tc, east: tc, west: tc, up: {tex: 'terracotta', tint: [0.85, 0.85, 0.85]}});
    b(K, o, [a + 0.3, h - 0.8, a + 0.3], [15.7 - a, h - 0.6, 15.7 - a], {up: {tex: 'dirt'}});
    if (plant === 'azalea') {
      b(K, o, [1.5, h, 1.5], [14.5, h + 12, 14.5], all('azalea_leaves'));
      b(K, o, [3.5, h + 12, 3.5], [12.5, h + 15, 12.5], all('flowering_azalea_leaves'));
    } else if (plant === 'tall') {
      cross(K.mb, K.grid, K.atlas, o, 'fern', 1.1, h);
      cross(K.mb, K.grid, K.atlas, [o[0], o[1] + 0.9, o[2]], 'fern', 0.9, h);
    } else {
      cross(K.mb, K.grid, K.atlas, o, 'fern', big ? 1.2 : 0.8, h - 1);
    }
  }

  function barrel(K, o) {
    b(K, o, [2, 0, 2], [14, 14, 14], {north: {tex: 'barrel_side'}, south: {tex: 'barrel_side'}, east: {tex: 'barrel_side'}, west: {tex: 'barrel_side'}, up: {tex: 'barrel_top'}});
    return 14 / 16;
  }

  function stool(K, o) {
    const wood = sides('spruce_planks');
    for (const [x, z] of [[3, 3], [11.5, 3], [3, 11.5], [11.5, 11.5]]) b(K, o, [x, 0, z], [x + 1.5, 9, z + 1.5], wood);
    b(K, o, [2, 9, 2], [14, 10.5, 14], sides('dark_oak_planks'));
    return 10.5 / 16;
  }

  // At the foot of a post: a plant, a globe, or a stool or barrel with books.
  function postDecor(K, kind, o, side) {
    if (kind === 'fern') pot(K, o, 'tall', true);
    else if (kind === 'azalea') pot(K, o, 'azalea', true);
    else if (kind === 'globe') globe(K, o);
    else {
      const h = kind === 'barrel' ? barrel(K, o) : stool(K, o);
      bookStack(K, [o[0], o[1] + h, o[2]], kind === 'barrel' ? 2 : 4, 'post' + o[2] + side, side * 0.3);
    }
  }

  function coatStand(K, o) {
    const wood = sides('dark_oak_planks');
    b(K, o, [3, 0, 7], [13, 1.5, 9], wood); b(K, o, [7, 0, 3], [9, 1.5, 13], wood);
    b(K, o, [7.2, 1.5, 7.2], [8.8, 29, 8.8], wood);
    b(K, o, [6.5, 29, 6.5], [9.5, 31, 9.5], wood);
    for (const [x, z] of [[4.5, 7.5], [9.5, 7.5], [7.5, 4.5], [7.5, 9.5]]) b(K, o, [x, 26, z], [x + 2, 27, z + 1], wood);
    b(K, o, [9.8, 16, 7], [11.3, 26.5, 9.5], sides('red_wool', null, null, {tint: [0.85, 0.85, 0.85]}));
    b(K, o, [4.5, 31, 4.5], [11.5, 32, 11.5], sides('brown_wool', null, null, {tint: [0.45, 0.38, 0.32]}));
    b(K, o, [5.5, 32, 5.5], [10.5, 35, 10.5], sides('brown_wool', null, null, {tint: [0.45, 0.38, 0.32]}));
  }

  // A grandfather clock against the -x wall. Returns where its face is, so
  // the page can put hands on it.
  function clock(K, o) {
    const yaw = Math.PI / 2;
    const opts = {yaw};
    const wood = sides('dark_oak_planks'), trim = sides('spruce_planks');
    b(K, o, [3, 0, 4], [13, 12, 13], wood, opts);
    b(K, o, [2.5, 0, 3.5], [13.5, 1.5, 13.5], trim, opts);
    b(K, o, [4, 12, 5], [12, 26, 12], wood, opts);
    b(K, o, [5.5, 14, 4.9], [10.5, 24, 5], {north: {tex: 'spruce_planks', tint: [0.5, 0.42, 0.36]}}, opts);
    b(K, o, [7.3, 15, 4.85], [8.7, 22, 4.9], {north: brass.north}, opts);
    b(K, o, [6.5, 15.5, 4.8], [9.5, 18.5, 4.85], {north: brass.north}, opts);
    b(K, o, [2.5, 26, 3.5], [13.5, 38, 13], wood, opts);
    b(K, o, [2, 38, 3], [14, 40, 13.5], trim, opts);
    b(K, o, [7, 40, 7], [9, 42, 9], brass, opts);
    b(K, o, [3.5, 27.5, 3.4], [12.5, 36.5, 3.5], {north: {tex: 'clock_face', uv: [0, 0, 16, 16]}}, opts);
    return {center: toWorld(o, [8, 32, 3.35], yaw), normal: [1, 0, 0], radius: 4 / 16};
  }

  // The front door: two spruce leaves meeting in the middle.
  function door(K, x, z) {
    for (const [dx, flip] of [[0, false], [1, true]]) {
      for (const [y, tex] of [[0, 'spruce_door_bottom'], [1, 'spruce_door_top']]) {
        const uv = flip ? [16, 0, 0, 16] : [0, 0, 16, 16];
        const face = {tex, uv};
        b(K, [x + dx, y, z], [0, 0, 0], [16, 16, 3], {north: face, south: {tex, uv: flip ? [0, 0, 16, 16] : [16, 0, 0, 16]}, east: {tex, uv: [0, 0, 3, 16]}, west: {tex, uv: [0, 0, 3, 16]}});
      }
      b(K, [x + dx, 0, z], flip ? [1.5, 14, -1] : [13.5, 14, -1], flip ? [2.5, 18, 0] : [14.5, 18, 0], brass);
    }
  }

  function hangingPlant(K, o) {
    const [x, top, z] = o;
    chain(K.mb, K.grid, K.atlas, [x, top - 0.8, z], 0.8);
    const at = [x, top - 1.2, z];
    const tc = sides('terracotta');
    b(K, at, [5, 0, 5], [11, 5, 11], tc);
    b(K, at, [5.3, 5, 5.3], [10.7, 5.2, 10.7], {up: {tex: 'dirt'}});
    cross(K.mb, K.grid, K.atlas, [x, top - 2.05, z], 'vine', 0.9, 0);
    cross(K.mb, K.grid, K.atlas, at, 'fern', 0.55, 4);
  }

  // A woven rug with a border, lying on the floor from (x0, z0) to (x1, z1).
  function rug(K, x0, z0, x1, z1, tex, border) {
    const t = 1, bw = 3;
    const X0 = x0 * 16, X1 = x1 * 16, Z0 = z0 * 16, Z1 = z1 * 16;
    box(K, [x0 + bw / 16, 0, z0 + bw / 16], [x1 - bw / 16, t / 16, z1 - bw / 16], {up: {tex}});
    const lenX = X1 - X0, lenZ = Z1 - Z0;
    const along = (l, flip) => ({tex: border, uv: flip ? [0, 0, 16, l] : [0, 0, l, 16], rot: flip ? 90 : 0});
    const edge = {tex: border, uv: [0, 0, 16, 2]};
    const add = (a, c, up) => addBox(K.mb, K.grid, K.atlas, [0, 0, 0], a, c, {up, north: edge, south: edge, east: edge, west: edge});
    add([X0, 0, Z0], [X1, t * 1.25, Z0 + bw], along(lenX));
    add([X0, 0, Z1 - bw], [X1, t * 1.25, Z1], along(lenX));
    add([X0, 0, Z0 + bw], [X0 + bw, t * 1.25, Z1 - bw], along(lenZ - bw * 2, true));
    add([X1 - bw, 0, Z0 + bw], [X1, t * 1.25, Z1 - bw], along(lenZ - bw * 2, true));
  }

  // A library ladder on a brass rail along the top of a bookcase.
  function ladder(K, spec, u) {
    const f = frame(spec.origin, spec.right, spec.n);
    f.box(K, 0.05, 5.78, -0.24, spec.width - 0.05, 5.84, -0.18, {front: brass.north, top: brass.up, bottom: brass.down});
    for (const x of [0.2, spec.width - 0.26]) f.box(K, x, 5.72, -0.2, x + 0.06, 5.84, 0, {front: brass.north, left: brass.west, right: brass.east});
    for (let v = 0; v < 5.8; v += 0.96) {
      f.box(K, u, v, -0.16, u + 0.8, Math.min(5.8, v + 0.96), -0.16, {front: {tex: 'ladder', uv: [0, 0, 16, 16], double: true}});
    }
    f.box(K, u + 0.05, 5.6, -0.26, u + 0.75, 5.66, -0.16, {front: brass.north, top: brass.up, bottom: brass.down});
  }

  // The mantelpiece over the hearth: a shelf on corbels with candles, a
  // plant and books, and a painting in a frame above it.
  function mantel(K, fz) {
    const face = fz + 1;
    const wood = sides('dark_oak_planks');
    box(K, [-2.1, 1.94, face], [2.1, 2.19, face + 0.36], wood);
    for (const x of [-2, 1.75]) box(K, [x, 1.6, face], [x + 0.25, 1.94, face + 0.25], wood);
    const on = 2.19;
    K.candles.push(candle(K.mb, K.grid, K.atlas, [-2, on, face], -4, -3, 5));
    K.candles.push(candle(K.mb, K.grid, K.atlas, [-2, on, face], -1, -4, 4));
    K.candles.push(candle(K.mb, K.grid, K.atlas, [1, on, face], 4, -3, 6));
    pot(K, [0.05, on, face - 0.2], 'fern');
    bookStack(K, [-0.95, on, face - 0.25], 3, 'mantel', 0.15);
    // The painting, two blocks wide in a dark oak frame.
    const p = [face + 0.04, face + 0.1];
    box(K, [-1, 3.1, face], [0, 4.1, p[0]], {south: {tex: 'painting_left', uv: [0, 0, 16, 16]}});
    box(K, [0, 3.1, face], [1, 4.1, p[0]], {south: {tex: 'painting_right', uv: [0, 0, 16, 16]}});
    const fr = sides('dark_oak_planks');
    box(K, [-1.1, 3.0, face], [1.1, 3.1, p[1]], fr);
    box(K, [-1.1, 4.1, face], [1.1, 4.2, p[1]], fr);
    box(K, [-1.1, 3.1, face], [-1, 4.1, p[1]], fr);
    box(K, [1, 3.1, face], [1.1, 4.1, p[1]], fr);
  }

  window.LibraryFurniture = {
    armchair, windowSeat, desk, sideTable, teacup, bookStack, globe, floorLamp, pot, barrel, stool, postDecor,
    coatStand, clock, door, hangingPlant, rug, ladder, mantel,
  };
})();
