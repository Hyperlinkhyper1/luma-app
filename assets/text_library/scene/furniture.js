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
  function windowSeat(K, side, x, za, zb, y = 0) {
    const x0 = side > 0 ? x : x + 0.25, x1 = side > 0 ? x + 0.75 : x + 1;
    const front = side > 0 ? 'east' : 'west';
    box(K, [x0, y, za], [x1, y + 0.45, zb], {[front]: {tex: 'cabinet_door'}, north: {tex: 'spruce_planks'}, south: {tex: 'spruce_planks'}});
    box(K, [x0 - (side > 0 ? 0 : 0.04), y + 0.45, za], [x1 + (side > 0 ? 0.04 : 0), y + 0.5, zb], sides('dark_oak_planks'));
    box(K, [x0 + 0.03, y + 0.5, za + 0.05], [x1 - 0.03, y + 0.64, zb - 0.05], sides('white_wool', null, null, {tint: [0.94, 0.88, 0.76]}));
    const wall = side > 0 ? x0 : x1;
    const pillows = [['red_wool', za + 0.12], ['green_wool', za + 0.62], ['blue_wool', zb - 0.62]];
    for (const [tex, z] of pillows) {
      const a = side > 0 ? wall + 0.03 : wall - 0.2, c = side > 0 ? wall + 0.2 : wall - 0.03;
      box(K, [a, y + 0.64, z], [c, y + 1.02, z + 0.46], sides(tex, null, null, {tint: [0.9, 0.9, 0.9]}));
    }
    // A folded blanket at the far end, and a candle on the sill.
    box(K, [x0 + 0.1, y + 0.64, zb - 0.55], [x1 - 0.1, y + 0.72, zb - 0.1], {up: {tex: 'rug_red'}, north: {tex: 'rug_red_border'}, south: {tex: 'rug_red_border'}, east: {tex: 'rug_red_border'}, west: {tex: 'rug_red_border'}});
    const zc = Math.floor((za + zb) / 2);
    K.candles.push(candle(K.mb, K.grid, K.atlas, [x, y + 1 + 1.5 / 16, zc], side > 0 ? -6.5 : 6.5, 0, 5));
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

  // A patterned carpet laid block by block over whole cells from (x0, z0)
  // to (x1, z1), like carpet placed in the game: one pixel thick, a centre
  // tile inside and border tiles turned to face outward round the edge.
  function rug(K, x0, z0, x1, z1, style, y = 0) {
    const t = 1;
    const side = {tex: `carpet_${style}_center`, uv: [0, 0, 16, 1]};
    for (let x = x0; x < x1; x++) for (let z = z0; z < z1; z++) {
      const n = z === z0, s = z === z1 - 1, w = x === x0, e = x === x1 - 1;
      const edges = n + s + w + e;
      let kind = 'center', rot = 0;
      if (edges >= 2) {
        kind = 'corner';
        rot = n && w ? 0 : n && e ? 90 : s && e ? 180 : 270;
      } else if (edges === 1) {
        kind = 'edge';
        rot = n ? 0 : e ? 90 : s ? 180 : 270;
      }
      const faces = {up: {tex: `carpet_${style}_${kind}`, uv: [0, 0, 16, 16], rot}};
      if (n) faces.north = side;
      if (s) faces.south = side;
      if (w) faces.west = side;
      if (e) faces.east = side;
      addBox(K.mb, K.grid, K.atlas, [x, y, z], [0, 0, 0], [16, t, 16], faces, {ao: 1});
    }
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

  // ── Autumn and comfort ─────────────────────────────────────────────────
  const srgb = c => c.map(v => Math.pow(v, 2.2));

  // The desk chair: an upholstered study chair with padded arms and a
  // buttoned back, its seat at DESK_SEAT, pulled up facing -z. `o` is the
  // middle of its seat on the floor.
  //
  // No two boxes share a face pointing the same way, so nothing flickers
  // where parts meet.
  const DESK_SEAT = 8 / 16;
  function deskChair(K, o) {
    const at = [o[0] - 0.5, o[1], o[2] - 0.5];
    const dark = sides('dark_oak_planks');
    const velvet = sides('red_wool', null, null, {tint: [0.78, 0.7, 0.7]});
    const deep = sides('red_wool', null, null, {tint: [0.5, 0.42, 0.42]});
    // Turned legs and the seat frame.
    for (const [x, z] of [[2, 2], [12.5, 2], [2, 12.5], [12.5, 12.5]]) b(K, at, [x, 0, z], [x + 1.5, 4, z + 1.5], dark);
    b(K, at, [1.5, 4, 1.5], [14.5, 5.5, 14.5], dark);
    // A deep seat cushion with a rolled front edge.
    b(K, at, [2, 5.5, 1.8], [14, 8, 13], velvet);
    b(K, at, [2.3, 5.4, 1.1], [13.7, 7.6, 1.8], {north: velvet.north, up: velvet.up, down: velvet.down, east: velvet.east, west: velvet.west});
    // Back posts under a curved crest rail.
    for (const x of [1.5, 12.5]) b(K, at, [x, 5.5, 13], [x + 2, 22, 15], dark);
    b(K, at, [1.5, 22, 12.5], [14.5, 24, 15], dark);
    b(K, at, [3, 24, 13], [13, 25, 14.5], dark);
    // The padded back, buttoned, with a plaid cushion in the small of it.
    b(K, at, [3.5, 7.5, 12], [12.5, 22, 14.5], velvet);
    for (const [x, y] of [[5.5, 18], [10.5, 18], [8, 15], [5.5, 12], [10.5, 12]]) b(K, at, [x - 0.5, y - 0.5, 11.8], [x + 0.5, y + 0.5, 12], {north: deep.north});
    b(K, at, [5, 8, 10.4], [11, 13, 12], {north: {tex: 'carpet_green_center', uv: [3, 3, 13, 11]}, up: {tex: 'carpet_green_center'}, east: {tex: 'carpet_green_edge'}, west: {tex: 'carpet_green_edge'}});
    // Padded arms on short supports.
    for (const [p0, p1, a0, a1] of [[0.5, 2, 0, 2.5], [14, 15.5, 13.5, 16]]) {
      b(K, at, [p0, 5.5, 3], [p1, 11, 4.5], dark);
      b(K, at, [a0, 11, 2.5], [a1, 12.5, 13], velvet);
    }
  }

  // A knitted throw over an armchair's back, falling down behind it.
  function throwBlanket(K, o, yaw, style) {
    const knit = all(`carpet_${style}_center`, {uv: [0, 0, 16, 16]});
    const edge = all(`carpet_${style}_edge`, {uv: [0, 0, 16, 16]});
    const opts = {yaw};
    b(K, o, [2, 21.5, 12.6], [10, 22.4, 16.4], knit, opts);
    b(K, o, [2, 11, 16.4], [10, 22.4, 17], edge, opts);
    b(K, o, [2, 16, 12.2], [10, 22.4, 12.6], knit, opts);
  }

  // A ginger cat curled up asleep, tail round its paws.
  function cat(K, o, yaw) {
    const at = [o[0] - 0.5, o[1], o[2] - 0.5];
    const fur = sides('white_wool', null, null, {tint: srgb([0.93, 0.56, 0.26])});
    const dark = sides('white_wool', null, null, {tint: srgb([0.7, 0.36, 0.14])});
    const pale = sides('white_wool', null, null, {tint: srgb([0.98, 0.9, 0.8])});
    const opts = {yaw};
    b(K, at, [4.5, 0, 4], [11.5, 3.5, 12], fur, opts);
    b(K, at, [5, 3.5, 5], [11, 4.2, 11.5], fur, opts);
    for (const z of [6, 8.5]) b(K, at, [4.4, 1.2, z], [11.6, 4.3, z + 1], dark, opts);
    b(K, at, [3.5, 0, 9.5], [7.5, 3.5, 13.5], fur, opts);
    b(K, at, [3.8, 0, 12.3], [7.2, 1.6, 13.7], pale, opts);
    b(K, at, [4, 3.5, 10], [5, 4.6, 11], fur, opts);
    b(K, at, [6, 3.5, 10], [7, 4.6, 11], fur, opts);
    b(K, at, [3.9, 1.8, 13.5], [7.1, 2.1, 13.55], sides('solid', null, null, {tint: [0.05, 0.03, 0.02]}), opts);
    for (const [x, z] of [[11.5, 11], [10.5, 12.5], [8.5, 13], [7.5, 13]]) b(K, at, [x - 1, 0, z - 1], [x, 1.2, z], fur, opts);
  }

  // Split logs stacked in a pyramid, end grain out.
  function logPile(K, o) {
    const log = {north: {tex: 'spruce_log_top', uv: [0, 0, 16, 16]}, south: {tex: 'spruce_log_top', uv: [0, 0, 16, 16]}, east: {tex: 'spruce_log'}, west: {tex: 'spruce_log'}, up: {tex: 'spruce_log'}, down: {tex: 'spruce_log'}};
    const d = 4.4;
    for (let row = 0; row < 3; row++) {
      for (let i = 0; i < 3 - row; i++) {
        const x = 1 + row * d / 2 + i * d;
        b(K, o, [x, row * (d - 0.3), 1 + row], [x + d, row * (d - 0.3) + d, 11 - row * 0.5], log);
      }
    }
  }

  // A pumpkin `size` blocks across, centred on `c` on the floor.
  function pumpkin(K, c, size, lit) {
    const s = size * 16, at = [c[0] - 0.5, c[1], c[2] - 0.5];
    const lo = 8 - s / 2, hi = 8 + s / 2;
    const face = lit ? {tex: 'jack_o_lantern', uv: [0, 0, 16, 16], emit: 1} : {tex: 'pumpkin_side', uv: [0, 0, 16, 16]};
    const side = {tex: 'pumpkin_side', uv: [0, 0, 16, 16]};
    b(K, at, [lo, 0, lo], [hi, s * 0.85, hi], {south: face, north: side, east: side, west: side, up: {tex: 'pumpkin_top', uv: [0, 0, 16, 16]}});
    b(K, at, [7.3, s * 0.85, 7.3], [8.7, s * 0.85 + 1.6, 8.7], sides('spruce_log', null, null, {tint: srgb([0.62, 0.7, 0.4])}));
  }

  const AUTUMN = [[0.95, 0.54, 0.16], [0.84, 0.26, 0.12], [0.96, 0.8, 0.24], [0.72, 0.4, 0.14]].map(srgb);

  // A garland of autumn leaves swagging along a shelf's front edge, from x0
  // to x1 at height y, hung at z.
  function garland(K, x0, x1, y, z) {
    const n = Math.round((x1 - x0) * 5);
    for (let i = 0; i <= n; i++) {
      const t = i / n;
      const x = x0 + (x1 - x0) * t;
      const sag = Math.sin(t * Math.PI * 3) ** 2 * 0.1;
      const leaf = all('oak_leaves', {tint: AUTUMN[i % AUTUMN.length], uv: [2, 2, 10, 10]});
      box(K, [x - 0.06, y - sag - 0.07, z], [x + 0.06, y - sag + 0.05, z + 0.08], leaf);
      if (i % 4 === 2) box(K, [x - 0.025, y - sag - 0.1, z + 0.06], [x + 0.025, y - sag - 0.05, z + 0.1], sides('red_wool'));
    }
  }

  // A wreath of autumn leaves with berries, hung flat on a wall facing +z.
  function wreath(K, c) {
    const R = 0.26;
    for (let i = 0; i < 14; i++) {
      const a = i / 14 * Math.PI * 2;
      const x = c[0] + Math.cos(a) * R, y = c[1] + Math.sin(a) * R;
      const leaf = all('oak_leaves', {tint: AUTUMN[i % AUTUMN.length], uv: [3, 3, 11, 11]});
      box(K, [x - 0.08, y - 0.08, c[2]], [x + 0.08, y + 0.08, c[2] + 0.07], leaf);
      if (i % 3 === 0) box(K, [x - 0.03, y - 0.03, c[2] + 0.07], [x + 0.03, y + 0.03, c[2] + 0.11], sides('red_wool'));
    }
    const bow = sides('red_wool', null, null, {tint: [0.8, 0.8, 0.8]});
    box(K, [c[0] - 0.12, c[1] - R - 0.06, c[2] + 0.06], [c[0] + 0.12, c[1] - R + 0.04, c[2] + 0.12], bow);
    box(K, [c[0] - 0.04, c[1] - R - 0.2, c[2] + 0.07], [c[0] + 0.04, c[1] - R - 0.02, c[2] + 0.1], bow);
  }

  // A planter under a window on the outside of a wall facing +z, from x0
  // to x1, with autumn ferns and a little pumpkin.
  function windowBox(K, x0, x1, z) {
    const wood = sides('spruce_planks');
    box(K, [x0 + 0.05, 0.62, z], [x1 - 0.05, 0.98, z + 0.34], wood);
    box(K, [x0 + 0.1, 0.98, z + 0.04], [x1 - 0.1, 1.0, z + 0.3], {up: {tex: 'coarse_dirt'}});
    for (let x = x0; x < x1; x++) cross(K.mb, K.grid, K.atlas, [x, 1, z - 0.33], 'fern', 0.55, 0);
    pumpkin(K, [(x0 + x1) / 2 + 0.25, 1, z + 0.17], 0.25, false);
    for (const x of [x0 + 0.25, x1 - 0.35]) box(K, [x, 0.42, z], [x + 0.1, 0.62, z + 0.3], sides('dark_oak_planks'));
  }

  // A spruce fence along consecutive cells: a post in each, rails between.
  function fence(K, cells) {
    const wood = sides('spruce_planks');
    cells.forEach(([x, z], i) => {
      box(K, [x + 6 / 16, 0, z + 6 / 16], [x + 10 / 16, 1, z + 10 / 16], wood);
      if (!i) return;
      const [px, pz] = cells[i - 1];
      const a = [Math.min(x, px) + 0.5, Math.min(z, pz) + 0.5], c = [Math.max(x, px) + 0.5, Math.max(z, pz) + 0.5];
      for (const [y0, y1] of [[6, 9], [12, 15]]) {
        box(K, [a[0] - (x === px ? 1 / 16 : 0), y0 / 16, a[1] - (z === pz ? 1 / 16 : 0)], [c[0] + (x === px ? 1 / 16 : 0), y1 / 16, c[1] + (z === pz ? 1 / 16 : 0)], wood);
      }
    });
  }

  // A garden bench `len` blocks long along x from `o`, back to -z.
  function bench(K, o, len) {
    const [x0, , z] = o;
    const wood = sides('spruce_planks'), dark = sides('dark_oak_planks');
    box(K, [x0 + 0.05, 6.5 / 16, z + 0.12], [x0 + len - 0.05, 8 / 16, z + 0.88], wood);
    for (const x of [x0 + 0.12, x0 + len - 0.26]) {
      box(K, [x, 0, z + 0.2], [x + 0.14, 6.5 / 16, z + 0.34], dark);
      box(K, [x, 0, z + 0.7], [x + 0.14, 6.5 / 16, z + 0.84], dark);
      box(K, [x, 8 / 16, z + 0.12], [x + 0.14, 1.15, z + 0.24], dark);
    }
    for (const y of [11, 15]) box(K, [x0 + 0.05, y / 16, z + 0.12], [x0 + len - 0.05, (y + 2.5) / 16, z + 0.22], wood);
  }

  function lantern(K, cell) {
    window.LibraryWorld.lantern(K.mb, K.grid, K.atlas, cell, false);
  }

  // A lamp post with a lantern standing on its cap.
  function lampPost(K, o) {
    const dark = sides('dark_oak_planks');
    b(K, o, [5, 0, 5], [11, 3, 11], sides('cobblestone'));
    b(K, o, [6.5, 3, 6.5], [9.5, 22, 9.5], dark);
    b(K, o, [5, 22, 5], [11, 23, 11], dark);
    window.LibraryWorld.lantern(K.mb, K.grid, K.atlas, [o[0], o[1] + 23 / 16, o[2]], false);
  }

  // One leaf of the front door, built round its hinge so it can swing:
  // it runs toward +x from the hinge, or toward -x when `flip`ped. The
  // door is three blocks tall, with square door textures and a wood panel above.
  function doorLeaf(K, flip, light) {
    const x = flip ? -1 : 0;
    for (const [i, tex] of [[0, 'spruce_door_bottom'], [1, 'spruce_door_top'], [2, 'spruce_planks']]) {
      const out = flip ? [16, 0, 0, 16] : [0, 0, 16, 16], inn = flip ? [0, 0, 16, 16] : [16, 0, 0, 16];
      const faces = {north: {tex, uv: out}, south: {tex, uv: inn}, east: {tex, uv: [0, 0, 3, 16]}, west: {tex, uv: [0, 0, 3, 16]}};
      if (i === 2) faces.up = {tex: 'spruce_planks', uv: [0, 0, 16, 3]};
      b(K, [x, i, 0], [0, 0, 0], [16, 16, 3], faces, {light, ao: 1});
    }
    for (const [z0, z1] of [[-1, 0], [3, 4]]) b(K, [x, 0, 0], flip ? [1.5, 14, z0] : [13.5, 14, z0], flip ? [2.5, 19, z1] : [14.5, 19, z1], brass, {light, ao: 1});
  }

  // A little roof over the front door on two brackets, with a lantern
  // hanging at each end. `F` is the front wall; its face is at F + 1.
  function porch(K, F) {
    const z = F + 1;
    const dark = sides('dark_oak_planks'), pale = sides('spruce_planks');
    for (const x of [-1.95, 1.75]) {
      box(K, [x, 2.45, z], [x + 0.2, 3.0, z + 0.2], dark);
      box(K, [x, 2.8, z + 0.2], [x + 0.2, 3.0, z + 1.1], dark);
    }
    box(K, [-2.3, 3.0, z], [2.3, 3.18, z + 1.35], dark);
    box(K, [-2.1, 3.18, z], [2.1, 3.36, z + 0.95], pale);
    box(K, [-1.9, 3.36, z], [1.9, 3.54, z + 0.55], dark);
    box(K, [-2.3, 2.92, z + 1.35], [2.3, 3.18, z + 1.45], pale);
    for (const x of [-1.75, 1.75]) {
      const o = [x - 0.5, 2.1, z + 0.45];
      window.LibraryWorld.lantern(K.mb, K.grid, K.atlas, o, true);
      chain(K.mb, K.grid, K.atlas, [o[0], o[1] + 13 / 16, o[2]], 3.0 - (o[1] + 13 / 16));
    }
  }

  // Closed timber treads wrap twice around the post; the rail follows the
  // same pitch instead of restarting as a stack of separate fences.
  function spiralStair(K, flights, S) {
    const last = flights[flights.length - 1];
    const height = last.base + last.height;
    const log = sides('dark_oak_log', 'dark_oak_log_top');
    box(K, [S.cx + 0.27, 0, S.cz + 0.27], [S.cx + 0.73, height + 1.08, S.cz + 0.73], log);
    box(K, [S.cx + 0.23, height + 1.08, S.cz + 0.23], [S.cx + 0.77, height + 1.2, S.cz + 0.77], brass);
    const dark = sides('dark_oak_planks');
    function face(corners, normal, texture) {
      const tile = K.atlas.index[texture] || K.atlas.index.oak_planks;
      const lights = corners.map(p => K.grid.sample(p.map((v, i) => v + normal[i] * 0.15), normal));
      // Atlas coordinates are pixels, just like block faces on the floor.
      // Project in world space so the vanilla grain keeps its block scale.
      const uv = corners.map(p => Math.abs(normal[1]) > 0.5 ? [p[0] * 16, p[2] * 16]
        : Math.abs(normal[0]) > Math.abs(normal[2]) ? [p[2] * 16, -p[1] * 16] : [p[0] * 16, -p[1] * 16]);
      K.mb.quad(corners, normal, uv, [tile.cell, tile.frames, tile.frameTime], lights, [1, 1, 1, 1]);
    }
    function wedge(corners, bottom, top) {
      const upper = corners.map(([x, z]) => [x, top, z]);
      const lower = corners.map(([x, z]) => [x, bottom, z]);
      face([...upper].reverse(), [0, 1, 0], 'spruce_planks');
      face(lower, [0, -1, 0], 'dark_oak_planks');
      corners.forEach((p, i) => {
        const j = (i + 1) % corners.length, q = corners[j];
        const dx = q[0] - p[0], dz = q[1] - p[1], len = Math.hypot(dx, dz);
        face([upper[i], upper[j], lower[j], lower[i]], [dz / len, 0, -dx / len], 'dark_oak_planks');
      });
    }
    function rail(a, b) {
      const dx = b[0] - a[0], dy = b[1] - a[1], dz = b[2] - a[2];
      const horizontal = Math.hypot(dx, dz), len = Math.hypot(horizontal, dy);
      const side = [-dz / horizontal * 0.055, 0, dx / horizontal * 0.055];
      const up = [-dx * dy / (horizontal * len) * 0.065, horizontal / len * 0.065, -dz * dy / (horizontal * len) * 0.065];
      const crossSection = p => [[-1, 1], [1, 1], [1, -1], [-1, -1]].map(([s, u]) => p.map((v, k) => v + s * side[k] + u * up[k]));
      const ends = [crossSection(a), crossSection(b)];
      for (let i = 0; i < 4; i++) {
        const j = (i + 1) % 4;
        const normal = (i % 2 ? side : up).map(v => v / (i % 2 ? 0.055 : 0.065) * (i < 2 ? 1 : -1));
        face([ends[0][i], ends[0][j], ends[1][j], ends[1][i]], normal, 'dark_oak_planks');
      }
      face([...ends[0]].reverse(), [-dx / len, -dy / len, -dz / len], 'dark_oak_planks');
      face(ends[1], [dx / len, dy / len, dz / len], 'dark_oak_planks');
    }
    for (const flight of flights) {
      LibraryStairs.treads(S, flight).forEach(({corners, bottom, top}) => wedge(corners, bottom, top));
      for (let i = 1; i < flight.count - 1; i++) {
        const [x, z] = LibraryStairs.point(S, i / flight.count, 1.36, true);
        const [nx, nz] = LibraryStairs.point(S, (i + 1) / flight.count, 1.36, true);
        const y = flight.base + i * flight.rise;
        box(K, [x - 0.035, y, z - 0.035], [x + 0.035, y + 0.93, z + 0.035], dark, {whole: true});
        rail([x, y + 0.94, z], [nx, y + flight.rise + 0.94, nz]);
      }
    }
  }

  // The railing round the stair well on an upper floor, open to the
  // south where the stair comes up.
  function stairRail(K, S, y) {
    const wood = sides('spruce_planks'), dark = sides('dark_oak_planks');
    const x0 = S.x0, z0 = S.z0, x1 = S.x0 + 3, z1 = S.z0 + 3;
    const t = 2 / 16;
    const runs = [
      [[x0 - t - 0.02, z0 - t - 0.02], [x0 - 0.02, z1 + t + 0.02]],
      [[x0 - 0.02, z0 - t - 0.02], [x1, z0 - 0.02]],
      [[x0 - 0.02, z1 + 0.02], [x0 + 1, z1 + t + 0.02]],
      [[x0 + 2, z1 + 0.02], [x1, z1 + t + 0.02]],
    ];
    for (const [[ax, az], [cx, cz]] of runs) {
      box(K, [ax, y + 0.86, az], [cx, y + 1.0, cz], dark);
      box(K, [ax + 0.02, y + 0.42, az + 0.02], [cx - 0.02, y + 0.5, cz - 0.02], wood);
      // Balusters every half block along the run.
      const along = cx - ax > cz - az ? 0 : 2;
      const len = along === 0 ? cx - ax : cz - az;
      for (let s = 0.1; s < len; s += 0.5) {
        const px = along === 0 ? ax + s : (ax + cx) / 2, pz = along === 2 ? az + s : (az + cz) / 2;
        box(K, [px - 0.035, y, pz - 0.035], [px + 0.035, y + 0.86, pz + 0.035], wood, {whole: true});
      }
    }
  }

  // A windlass and a pitched roof over the well at (wx, wz), with a bucket
  // on its rope.
  function wellRoof(K, wx, wz) {
    const log = sides('spruce_log', 'spruce_log_top'), dark = sides('dark_oak_planks');
    for (const x of [wx + 0.05, wx + 2.75]) box(K, [x, 1, wz + 1.4], [x + 0.2, 3.0, wz + 1.6], log);
    box(K, [wx + 0.25, 2.3, wz + 1.44], [wx + 2.75, 2.44, wz + 1.56], {north: {tex: 'spruce_log'}, south: {tex: 'spruce_log'}, up: {tex: 'spruce_log', rot: 90}, down: {tex: 'spruce_log', rot: 90}});
    chain(K.mb, K.grid, K.atlas, [wx + 1, 1.5, wz + 1], 0.8);
    const iron = sides('light_gray_wool', null, null, {tint: [0.6, 0.6, 0.66]});
    box(K, [wx + 1.36, 1.05, wz + 1.36], [wx + 1.64, 1.5, wz + 1.64], iron, {whole: true});
    box(K, [wx - 0.2, 3.0, wz + 0.55], [wx + 3.2, 3.2, wz + 2.45], dark);
    box(K, [wx - 0.2, 3.2, wz + 0.85], [wx + 3.2, 3.4, wz + 2.15], dark);
    box(K, [wx - 0.2, 3.4, wz + 1.2], [wx + 3.2, 3.6, wz + 1.8], sides('spruce_planks'));
  }

  // A scarecrow on a pole: a sack body, straw hands, a carved pumpkin head
  // looking east over the path, and a battered hat.
  function scarecrow(K, o) {
    const [x, y, z] = o;
    const pole = sides('spruce_log', 'spruce_log_top');
    box(K, [x + 0.44, y, z + 0.44], [x + 0.56, y + 1.9, z + 0.56], pole);
    box(K, [x - 0.1, y + 1.35, z + 0.45], [x + 1.1, y + 1.46, z + 0.55], sides('spruce_planks'));
    box(K, [x + 0.25, y + 0.85, z + 0.33], [x + 0.75, y + 1.5, z + 0.67], sides('brown_wool', null, null, {tint: [0.95, 0.82, 0.62]}));
    const straw = sides('hay_block_side', 'hay_block_top');
    for (const [a, c] of [[-0.2, -0.1], [1.1, 1.2]]) box(K, [x + a, y + 1.2, z + 0.4], [x + c, y + 1.42, z + 0.6], straw, {whole: true});
    box(K, [x + 0.3, y + 0.6, z + 0.38], [x + 0.7, y + 0.85, z + 0.62], straw, {whole: true});
    const skin = {tex: 'pumpkin_side', uv: [0, 0, 16, 16]};
    box(K, [x + 0.2, y + 1.5, z + 0.2], [x + 0.8, y + 2.05, z + 0.8], {north: skin, south: skin, west: skin, east: {tex: 'carved_pumpkin', uv: [0, 0, 16, 16]}, up: {tex: 'pumpkin_top', uv: [0, 0, 16, 16]}}, {whole: true});
    const hat = sides('brown_wool', null, null, {tint: [0.42, 0.34, 0.28]});
    box(K, [x + 0.1, y + 2.05, z + 0.1], [x + 0.9, y + 2.1, z + 0.9], hat, {whole: true});
    box(K, [x + 0.3, y + 2.1, z + 0.3], [x + 0.7, y + 2.36, z + 0.7], hat, {whole: true});
  }

  // A split log laid on its side as a bench, three blocks along `axis`.
  function logSeat(K, o, axis) {
    const [x, y, z] = o;
    const end = {tex: 'spruce_log_top'}, bark = {tex: 'spruce_log', rot: axis === 'x' ? 90 : 0};
    if (axis === 'x') box(K, [x, y, z + 0.2], [x + 3, y + 0.55, z + 0.8], {east: end, west: end, north: bark, south: bark, up: bark});
    else box(K, [x + 0.2, y, z], [x + 0.8, y + 0.55, z + 3], {north: end, south: end, east: bark, west: bark, up: bark});
  }

  // A planter of ferns and flowers under a window on the outside of a
  // wall, along frame `f` from u0 to u1.
  function planter(K, f, u0, u1) {
    const wood = {tex: 'spruce_planks'};
    f.box(K, u0 + 0.05, 0.62, -0.34, u1 - 0.05, 0.98, 0, {front: wood, top: wood, bottom: wood, left: wood, right: wood});
    f.box(K, u0 + 0.1, 0.98, -0.3, u1 - 0.1, 1.0, -0.04, {top: {tex: 'coarse_dirt'}});
    for (let u = u0; u < u1; u++) {
      const p = f.p(u + 0.5, 1, -0.17);
      cross(K.mb, K.grid, K.atlas, [p[0] - 0.5, p[1], p[2] - 0.5], u % 2 ? 'poppy' : 'fern', 0.55, 0);
    }
    for (const u of [u0 + 0.25, u1 - 0.35]) f.box(K, u, 0.42, -0.3, u + 0.1, 0.62, 0, {front: wood, left: wood, right: wood, bottom: wood});
  }

  window.LibraryFurniture = {
    armchair, windowSeat, desk, sideTable, teacup, bookStack, globe, floorLamp, pot, barrel, stool, postDecor,
    coatStand, clock, hangingPlant, rug, ladder, mantel,
    DESK_SEAT, deskChair, throwBlanket, cat, logPile, pumpkin, fence, bench, lantern, lampPost, doorLeaf, garland, wreath, windowBox,
    porch, spiralStair, stairRail, wellRoof, scarecrow, logSeat, planter,
  };
})();
