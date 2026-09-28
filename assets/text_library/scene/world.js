// The library hall as blocks: a voxel grid for walls, floor and bookcases,
// Minecraft-style light (sky light through the windows, block light from
// lanterns, candles and the fire, flood-filled and smoothed per vertex with
// ambient occlusion), and small models for everything that is not a cube.
(() => {
  'use strict';

  // ── Layout constants (block units) ─────────────────────────────────────
  const HALL = {
    halfWidth: 5,     // interior spans x ∈ [-5, 5]
    caseFace: 4,      // bookcase fronts at x = ±4
    height: 7,        // ceiling underside
    section: 5,       // 4-wide bookcase + 1 pillar
    caseWidth: 4,
    caseHeight: 3,
    foyer: 6,         // open floor in front of the first section
    end: 9,           // desk + fireplace room past the last section
  };
  const SLOT_COLS = 12, SLOT_ROWS = 6, SLOTS = SLOT_COLS * SLOT_ROWS;

  // ── Mesh builder ───────────────────────────────────────────────────────
  class MeshBuilder {
    constructor() {
      this.pos = []; this.nrm = []; this.uvp = []; this.tile = []; this.light = [];
      this.ao = []; this.tint = []; this.emit = []; this.label = []; this.index = [];
      this.count = 0;
    }
    // corners: 4 × [x,y,z] in TL, BL, BR, TR order; uvs likewise.
    quad(corners, normal, uvs, tile, lights, aos, opts = {}) {
      const base = this.count;
      const tint = opts.tint || [1, 1, 1];
      const emit = opts.emit || 0;
      const label = opts.label || [0, 0, 0, 0];
      for (let i = 0; i < 4; i++) {
        this.pos.push(...corners[i]);
        this.nrm.push(...normal);
        this.uvp.push(...uvs[i]);
        this.tile.push(...tile);
        this.light.push(...lights[i]);
        this.ao.push(aos[i]);
        this.tint.push(...tint);
        this.emit.push(emit);
        if (opts.labelUv) this.label.push(opts.labelUv[i][0], opts.labelUv[i][1], 1, 0);
        else this.label.push(...label);
      }
      // Flip the diagonal where it avoids the classic AO seam artefact.
      if (aos[0] + aos[2] < aos[1] + aos[3]) this.index.push(base + 1, base + 2, base + 3, base + 1, base + 3, base);
      else this.index.push(base, base + 1, base + 2, base, base + 2, base + 3);
      if (opts.doubleSided) {
        this.index.push(base + 2, base + 1, base, base + 3, base + 2, base);
      }
      this.count += 4;
    }
    geometry(T) {
      const g = new T.BufferGeometry();
      g.setAttribute('position', new T.Float32BufferAttribute(this.pos, 3));
      g.setAttribute('normal', new T.Float32BufferAttribute(this.nrm, 3));
      g.setAttribute('uvp', new T.Float32BufferAttribute(this.uvp, 2));
      g.setAttribute('tile', new T.Float32BufferAttribute(this.tile, 3));
      g.setAttribute('light', new T.Float32BufferAttribute(this.light, 3));
      g.setAttribute('ao', new T.Float32BufferAttribute(this.ao, 1));
      g.setAttribute('tint', new T.Float32BufferAttribute(this.tint, 3));
      g.setAttribute('emit', new T.Float32BufferAttribute(this.emit, 1));
      g.setAttribute('label', new T.Float32BufferAttribute(this.label, 4));
      g.setIndex(this.count > 65535 ? new T.Uint32BufferAttribute(this.index, 1) : new T.Uint16BufferAttribute(this.index, 1));
      g.computeBoundingSphere();
      return g;
    }
  }

  // Face corner layouts, TL/BL/BR/TR as seen from outside, and the way
  // Minecraft maps a box's coordinates onto each face's texture.
  const FACES = {
    north: {n: [0, 0, -1], c: (a, b) => [[b[0], b[1], a[2]], [b[0], a[1], a[2]], [a[0], a[1], a[2]], [a[0], b[1], a[2]]], uv: (a, b) => [16 - b[0], 16 - b[1], 16 - a[0], 16 - a[1]]},
    south: {n: [0, 0, 1], c: (a, b) => [[a[0], b[1], b[2]], [a[0], a[1], b[2]], [b[0], a[1], b[2]], [b[0], b[1], b[2]]], uv: (a, b) => [a[0], 16 - b[1], b[0], 16 - a[1]]},
    west: {n: [-1, 0, 0], c: (a, b) => [[a[0], b[1], a[2]], [a[0], a[1], a[2]], [a[0], a[1], b[2]], [a[0], b[1], b[2]]], uv: (a, b) => [a[2], 16 - b[1], b[2], 16 - a[1]]},
    east: {n: [1, 0, 0], c: (a, b) => [[b[0], b[1], b[2]], [b[0], a[1], b[2]], [b[0], a[1], a[2]], [b[0], b[1], a[2]]], uv: (a, b) => [16 - b[2], 16 - b[1], 16 - a[2], 16 - a[1]]},
    up: {n: [0, 1, 0], c: (a, b) => [[a[0], b[1], a[2]], [a[0], b[1], b[2]], [b[0], b[1], b[2]], [b[0], b[1], a[2]]], uv: (a, b) => [a[0], a[2], b[0], b[2]]},
    down: {n: [0, -1, 0], c: (a, b) => [[a[0], a[1], b[2]], [a[0], a[1], a[2]], [b[0], a[1], a[2]], [b[0], a[1], b[2]]], uv: (a, b) => [a[0], 16 - b[2], b[0], 16 - a[2]]},
  };
  const DIRS = Object.keys(FACES);

  function uvCorners([u0, v0, u1, v1], rotation = 0) {
    let c = [[u0, v0], [u0, v1], [u1, v1], [u1, v0]];
    for (let r = 0; r < (rotation / 90) % 4; r++) c = [c[1], c[2], c[3], c[0]];
    return c;
  }

  // ── Voxel grid and light ───────────────────────────────────────────────
  const AIR = 0;
  class Grid {
    constructor(min, max) {
      this.min = min; this.max = max;
      this.sx = max[0] - min[0]; this.sy = max[1] - min[1]; this.sz = max[2] - min[2];
      const n = this.sx * this.sy * this.sz;
      this.block = new Array(n).fill(AIR);
      this.opaque = new Uint8Array(n);
      this.sky = new Uint8Array(n);
      this.lamp = new Uint8Array(n);
      this.fire = new Uint8Array(n);
    }
    idx(x, y, z) {
      x -= this.min[0]; y -= this.min[1]; z -= this.min[2];
      if (x < 0 || y < 0 || z < 0 || x >= this.sx || y >= this.sy || z >= this.sz) return -1;
      return (z * this.sy + y) * this.sx + x;
    }
    set(x, y, z, block) {
      const i = this.idx(x, y, z);
      if (i < 0) return;
      this.block[i] = block;
      this.opaque[i] = block && block.opaque ? 1 : 0;
    }
    get(x, y, z) { const i = this.idx(x, y, z); return i < 0 ? AIR : this.block[i]; }
    solid(x, y, z) { const i = this.idx(x, y, z); return i < 0 ? 0 : this.opaque[i]; }
    fill(a, b, block) {
      for (let x = a[0]; x <= b[0]; x++) for (let y = a[1]; y <= b[1]; y++) for (let z = a[2]; z <= b[2]; z++) this.set(x, y, z, block);
    }

    propagate(channel, seeds) {
      const arr = this[channel];
      const queue = [];
      for (const [x, y, z, level] of seeds) {
        const i = this.idx(x, y, z);
        if (i < 0 || arr[i] >= level) continue;
        arr[i] = level;
        queue.push(x, y, z);
      }
      const n = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]];
      for (let q = 0; q < queue.length; q += 3) {
        const x = queue[q], y = queue[q + 1], z = queue[q + 2];
        const level = arr[this.idx(x, y, z)];
        if (level <= 1) continue;
        for (const [dx, dy, dz] of n) {
          const j = this.idx(x + dx, y + dy, z + dz);
          if (j < 0 || this.opaque[j] || arr[j] >= level - 1) continue;
          arr[j] = level - 1;
          queue.push(x + dx, y + dy, z + dz);
        }
      }
    }

    lightSky() {
      const seeds = [];
      for (let z = this.min[2]; z < this.max[2]; z++) {
        for (let x = this.min[0]; x < this.max[0]; x++) {
          for (let y = this.max[1] - 1; y >= this.min[1]; y--) {
            if (this.solid(x, y, z)) break;
            seeds.push([x, y, z, 15]);
          }
        }
      }
      this.propagate('sky', seeds);
    }

    // Light at a cell, as 0–1 per channel; opaque cells report null.
    cell(x, y, z) {
      const i = this.idx(x, y, z);
      if (i < 0) return [1, 0, 0];
      if (this.opaque[i]) return null;
      return [this.sky[i] / 15, this.lamp[i] / 15, this.fire[i] / 15];
    }

    // Smooth light at a point: trilinear over the eight nearest cell
    // centres, skipping opaque ones. Falls back along [away] when the point
    // is buried (a face deep inside a recess).
    sample(p, away) {
      for (let attempt = 0; attempt < 3; attempt++) {
        const q = attempt === 0 ? p : [p[0] + away[0] * attempt * 0.6, p[1] + away[1] * attempt * 0.6, p[2] + away[2] * attempt * 0.6];
        const fx = q[0] - 0.5, fy = q[1] - 0.5, fz = q[2] - 0.5;
        const x0 = Math.floor(fx), y0 = Math.floor(fy), z0 = Math.floor(fz);
        let s = 0, l = 0, f = 0, w = 0;
        for (let dx = 0; dx < 2; dx++) for (let dy = 0; dy < 2; dy++) for (let dz = 0; dz < 2; dz++) {
          const c = this.cell(x0 + dx, y0 + dy, z0 + dz);
          if (!c) continue;
          const wt = (dx ? fx - x0 : 1 - (fx - x0)) * (dy ? fy - y0 : 1 - (fy - y0)) * (dz ? fz - z0 : 1 - (fz - z0)) + 1e-4;
          s += c[0] * wt; l += c[1] * wt; f += c[2] * wt; w += wt;
        }
        if (w > 0.05) return [s / w, l / w, f / w];
      }
      return [0, 0, 0];
    }
  }

  // ── Blocks ─────────────────────────────────────────────────────────────
  const B = {};
  function block(name, faces, extra = {}) {
    B[name] = {name, opaque: true, faces, ...extra};
    return B[name];
  }
  block('dark_oak_planks', {all: 'dark_oak_planks'});
  block('spruce_planks', {all: 'spruce_planks'});
  block('oak_planks', {all: 'oak_planks'});
  block('stone_bricks', {all: 'stone_bricks'});
  block('mossy_stone_bricks', {all: 'mossy_stone_bricks'});
  block('cobblestone', {all: 'cobblestone'});
  block('smooth_stone', {all: 'smooth_stone'});
  block('bricks', {all: 'bricks'});
  block('dirt', {all: 'dirt'});
  block('grass', {top: 'grass_block_top', bottom: 'dirt', side: 'dirt'});
  block('pillar', {top: 'stripped_spruce_log_top', bottom: 'stripped_spruce_log_top', side: 'stripped_spruce_log'});
  block('beam_x', {east: 'stripped_spruce_log_top', west: 'stripped_spruce_log_top', side: 'stripped_spruce_log', rot: 90});
  block('beam_z', {north: 'dark_oak_log_top', south: 'dark_oak_log_top', side: 'dark_oak_log', rot: 90});
  block('spruce_log', {top: 'spruce_log_top', bottom: 'spruce_log_top', side: 'spruce_log'});
  block('oak_log', {top: 'spruce_log_top', bottom: 'spruce_log_top', side: 'oak_log'});
  block('bookshelf', {top: 'oak_planks', bottom: 'oak_planks', side: 'bookshelf'});
  block('leaves', {all: 'oak_leaves'}, {opaque: false, cutout: true});
  block('spruce_leaves', {all: 'spruce_leaves'}, {opaque: false, cutout: true});
  block('shelf', {all: 'chiseled_bookshelf_side'}, {custom: 'shelf'});
  block('barrel', {top: 'barrel_top', bottom: 'barrel_top', side: 'barrel_side'});

  function faceTexture(b, dir) {
    const f = b.faces;
    if (f[dir]) return f[dir];
    if (f.all) return f.all;
    if (dir === 'up') return f.top;
    if (dir === 'down') return f.bottom;
    return f.side;
  }

  // ── Context for building ───────────────────────────────────────────────
  function tileOf(atlas, name) {
    const t = atlas.index[name] || atlas.index.oak_planks;
    return [t.cell, t.frames, t.frameTime];
  }

  // Adds a full block's visible faces with smooth light and corner AO.
  function addBlock(mb, grid, atlas, x, y, z, b) {
    for (const dir of DIRS) {
      const F = FACES[dir];
      const [nx, ny, nz] = F.n;
      const neighbour = grid.get(x + nx, y + ny, z + nz);
      if (neighbour && neighbour.opaque) continue;
      if (b.cutout && neighbour === b) continue;
      const a = [x, y, z], c = [x + 1, y + 1, z + 1];
      const corners = F.c(a, c);
      const lights = [], aos = [];
      const front = [x + nx, y + ny, z + nz];
      for (const corner of corners) {
        // Tangent steps from the face centre toward this corner.
        const t = [0, 1, 2].map(k => (F.n[k] !== 0 ? 0 : corner[k] > [x, y, z][k] + 0.5 ? 1 : -1));
        const axes = [0, 1, 2].filter(k => F.n[k] === 0);
        const s1 = [...front]; s1[axes[0]] += t[axes[0]];
        const s2 = [...front]; s2[axes[1]] += t[axes[1]];
        const k = [...front]; k[axes[0]] += t[axes[0]]; k[axes[1]] += t[axes[1]];
        const o1 = grid.solid(...s1), o2 = grid.solid(...s2), ok = grid.solid(...k);
        const ao = o1 && o2 ? 0 : 3 - (o1 + o2 + ok);
        aos.push([0.42, 0.62, 0.82, 1][ao]);
        const samples = [grid.cell(...front), o1 ? null : grid.cell(...s1), o2 ? null : grid.cell(...s2), (o1 && o2) || ok ? null : grid.cell(...k)].filter(Boolean);
        const sum = samples.reduce((acc, v) => [acc[0] + v[0], acc[1] + v[1], acc[2] + v[2]], [0, 0, 0]);
        const n = Math.max(1, samples.length);
        lights.push([sum[0] / n, sum[1] / n, sum[2] / n]);
      }
      const uv = uvCorners([0, 0, 16, 16], (b.rot && dir !== 'up' && dir !== 'down' && !b.faces[dir]) ? b.rot : 0);
      mb.quad(corners, F.n, uv, tileOf(atlas, faceTexture(b, dir)), lights, aos);
    }
  }

  // Adds a model element: a box from `from` to `to` in pixels relative to
  // `origin` (block units), optionally turned about its own vertical axis.
  function addBox(mb, grid, atlas, origin, from, to, faces, opts = {}) {
    const yaw = opts.yaw || 0;
    const pivot = opts.pivot || [8, 8, 8];
    const cos = Math.round(Math.cos(yaw) * 1e6) / 1e6, sin = Math.round(Math.sin(yaw) * 1e6) / 1e6;
    const place = p => {
      const lx = p[0] - pivot[0], lz = p[2] - pivot[2];
      return [origin[0] + (pivot[0] + lx * cos - lz * sin) / 16, origin[1] + p[1] / 16, origin[2] + (pivot[2] + lx * sin + lz * cos) / 16];
    };
    const turn = n => [n[0] * cos - n[2] * sin, n[1], n[0] * sin + n[2] * cos];
    for (const dir of DIRS) {
      const face = faces[dir];
      if (!face) continue;
      const F = FACES[dir];
      const corners = F.c(from, to).map(place);
      const normal = turn(F.n).map(v => Math.round(v * 1e6) / 1e6);
      const uv = uvCorners(face.uv || F.uv(from, to), face.rot || 0);
      const away = opts.away || normal;
      const lights = corners.map(c => (opts.light ? opts.light : grid.sample([c[0] + normal[0] * 0.3, c[1] + normal[1] * 0.3, c[2] + normal[2] * 0.3], away)));
      const aos = corners.map(c => (face.ao != null ? face.ao : opts.ao != null ? (typeof opts.ao === 'function' ? opts.ao(c) : opts.ao) : 1));
      mb.quad(corners, normal, uv, tileOf(atlas, face.tex), lights, aos, {
        tint: face.tint || opts.tint, emit: face.emit != null ? face.emit : opts.emit || 0,
        doubleSided: face.double || opts.doubleSided, labelUv: face.labelUv,
      });
    }
  }

  const all = (tex, extra = {}) => Object.fromEntries(DIRS.map(d => [d, {tex, ...extra}]));
  const sides = (tex, top, bottom, extra = {}) => ({north: {tex, ...extra}, south: {tex, ...extra}, east: {tex, ...extra}, west: {tex, ...extra}, up: {tex: top || tex, ...extra}, down: {tex: bottom || top || tex, ...extra}});

  // ── Models ─────────────────────────────────────────────────────────────
  // All geometry below is luma's own; only the texture layout follows the
  // game's sheets so the vanilla images line up when they are present.
  function lantern(mb, grid, atlas, o, hanging) {
    const y = hanging ? 1 : 0;
    const body = {tex: 'lantern', uv: [0, 2, 6, 9]};
    const cap = {tex: 'lantern', uv: [0, 9, 6, 15]};
    addBox(mb, grid, atlas, o, [5, y, 5], [11, y + 7, 11], {north: body, south: body, east: body, west: body, up: cap, down: cap}, {emit: 1});
    const top = {tex: 'lantern', uv: [1, 0, 5, 2]};
    addBox(mb, grid, atlas, o, [6, y + 7, 6], [10, y + 9, 10], {north: top, south: top, east: top, west: top, up: {tex: 'lantern', uv: [1, 10, 5, 14]}}, {emit: 0.6});
    const handle = {tex: 'lantern', uv: [11, 1, 14, hanging ? 5 : 3], double: true};
    addBox(mb, grid, atlas, o, [6.5, y + 9, 8], [9.5, y + (hanging ? 13 : 11), 8], {north: handle}, {yaw: Math.PI / 4, ao: 1});
    addBox(mb, grid, atlas, o, [6.5, y + 9, 8], [9.5, y + (hanging ? 13 : 11), 8], {north: handle}, {yaw: -Math.PI / 4, ao: 1});
  }

  function chain(mb, grid, atlas, o, length) {
    for (let i = 0; i < length; i++) {
      const link = {tex: 'chain', uv: [0, 0, 3, 16], double: true};
      addBox(mb, grid, atlas, [o[0], o[1] + i, o[2]], [6.5, 0, 8], [9.5, 16, 8], {north: link}, {yaw: Math.PI / 4});
      addBox(mb, grid, atlas, [o[0], o[1] + i, o[2]], [6.5, 0, 8], [9.5, 16, 8], {north: link}, {yaw: -Math.PI / 4});
    }
  }

  function candle(mb, grid, atlas, o, dx, dz, h = 6) {
    const side = {tex: 'candle_lit', uv: [0, 8, 2, 8 + h]};
    addBox(mb, grid, atlas, o, [7 + dx, 0, 7 + dz], [9 + dx, h, 9 + dz], {north: side, south: side, east: side, west: side, up: {tex: 'candle_lit', uv: [0, 6, 2, 8]}});
    const wick = {tex: 'candle_lit', uv: [0, 5, 1, 6], double: true};
    addBox(mb, grid, atlas, o, [7.5 + dx, h, 8 + dz], [8.5 + dx, h + 1, 8 + dz], {north: wick}, {yaw: Math.PI / 4, pivot: [8 + dx, 0, 8 + dz]});
    return [o[0] + (8 + dx) / 16, o[1] + (h + 1.6) / 16, o[2] + (8 + dz) / 16];
  }

  function cross(mb, grid, atlas, o, tex, scale = 1, lift = 0) {
    const s = 8 * scale;
    for (const yaw of [Math.PI / 4, -Math.PI / 4]) {
      addBox(mb, grid, atlas, o, [8 - s, lift, 8], [8 + s, lift + 16 * scale, 8], {north: {tex, uv: [0, 0, 16, 16], double: true}}, {yaw, ao: 1});
    }
  }

  function flowerPot(mb, grid, atlas, o, plant) {
    const pot = {tex: 'flower_pot'};
    addBox(mb, grid, atlas, o, [5, 0, 5], [11, 6, 11], {north: {tex: 'flower_pot', uv: [5, 10, 11, 16]}, south: {tex: 'flower_pot', uv: [5, 10, 11, 16]}, east: {tex: 'flower_pot', uv: [5, 10, 11, 16]}, west: {tex: 'flower_pot', uv: [5, 10, 11, 16]}, up: {tex: 'dirt', uv: [6, 6, 10, 10]}, down: pot});
    cross(mb, grid, atlas, o, plant, plant === 'azalea_leaves' ? 0.7 : 0.75, 4);
  }

  function campfire(mb, grid, atlas, o) {
    const log = 'campfire_log', lit = 'campfire_log_lit';
    addBox(mb, grid, atlas, o, [1, 0, 0], [5, 4, 16], {north: {tex: log, uv: [0, 4, 4, 8]}, south: {tex: log, uv: [0, 4, 4, 8]}, east: {tex: lit, uv: [0, 1, 16, 5], emit: 0.35}, west: {tex: log, uv: [16, 0, 0, 4]}, up: {tex: log, uv: [0, 0, 16, 4], rot: 90}});
    addBox(mb, grid, atlas, o, [11, 0, 0], [15, 4, 16], {north: {tex: log, uv: [0, 4, 4, 8]}, south: {tex: log, uv: [0, 4, 4, 8]}, west: {tex: lit, uv: [16, 1, 0, 5], emit: 0.35}, east: {tex: log, uv: [0, 0, 16, 4]}, up: {tex: log, uv: [0, 0, 16, 4], rot: 90}});
    addBox(mb, grid, atlas, o, [0, 3, 11], [16, 7, 15], {north: {tex: lit, uv: [16, 0, 0, 4], emit: 0.35}, south: {tex: lit, uv: [0, 0, 16, 4], emit: 0.35}, east: {tex: log, uv: [0, 4, 4, 8]}, west: {tex: log, uv: [0, 4, 4, 8]}, up: {tex: log, uv: [0, 0, 16, 4], rot: 180}});
    addBox(mb, grid, atlas, o, [0, 3, 1], [16, 7, 5], {north: {tex: lit, uv: [0, 0, 16, 4], emit: 0.35}, south: {tex: lit, uv: [16, 0, 0, 4], emit: 0.35}, east: {tex: log, uv: [0, 4, 4, 8]}, west: {tex: log, uv: [0, 4, 4, 8]}, up: {tex: log, uv: [0, 0, 16, 4], rot: 180}});
    addBox(mb, grid, atlas, o, [5, 0, 0], [11, 1, 16], {up: {tex: lit, uv: [0, 8, 16, 14], rot: 90, emit: 0.5}});
    const flame = {tex: 'campfire_fire', uv: [0, 0, 16, 16], double: true, emit: 2.2};
    addBox(mb, grid, atlas, o, [0.8, 1, 8], [15.2, 17, 8], {north: flame}, {yaw: Math.PI / 4, ao: 1});
    addBox(mb, grid, atlas, o, [0.8, 1, 8], [15.2, 17, 8], {north: flame}, {yaw: -Math.PI / 4, ao: 1});
  }

  // A plank-topped desk on fence legs: `o` is its north-west corner, two
  // blocks wide along x.
  function desk(mb, grid, atlas, o) {
    const top = sides('dark_oak_planks');
    addBox(mb, grid, atlas, o, [0, 13, 0], [32, 16, 16], top);
    addBox(mb, grid, atlas, o, [1, 11, 1], [31, 13, 15], sides('spruce_planks'));
    for (const [x, z] of [[1, 1], [27, 1], [1, 11], [27, 11]]) {
      addBox(mb, grid, atlas, o, [x, 0, z], [x + 4, 11, z + 4], sides('stripped_spruce_log', 'stripped_spruce_log_top'));
    }
    // A drawer front.
    addBox(mb, grid, atlas, o, [10, 11.2, 15], [22, 12.8, 15.4], sides('oak_planks'));
  }

  // Stair-shaped chair facing -z (toward the desk).
  function chair(mb, grid, atlas, o) {
    addBox(mb, grid, atlas, o, [2, 0, 2], [14, 7, 14], sides('spruce_planks'));
    addBox(mb, grid, atlas, o, [2, 7, 11], [14, 18, 14], sides('spruce_planks'));
    addBox(mb, grid, atlas, o, [3, 7, 3], [13, 8, 11], sides('red_wool'));
  }

  function armchair(mb, grid, atlas, o, yaw) {
    const opts = {yaw};
    addBox(mb, grid, atlas, o, [0, 0, 0], [16, 8, 16], sides('spruce_planks'), opts);
    addBox(mb, grid, atlas, o, [1, 8, 1], [15, 10, 13], sides('red_wool'), opts);
    addBox(mb, grid, atlas, o, [0, 8, 13], [16, 20, 16], sides('red_wool'), opts);
    addBox(mb, grid, atlas, o, [0, 8, 0], [2, 13, 13], sides('spruce_planks'), opts);
    addBox(mb, grid, atlas, o, [14, 8, 0], [16, 13, 13], sides('spruce_planks'), opts);
  }

  // A book item lying flat, as the game shows dropped items: the sprite
  // extruded one pixel thick.
  function itemSprite(mb, grid, atlas, canvas, name, o, size, yaw, lift = 0) {
    const ctx = canvas.getContext('2d');
    const w = canvas.width, h = Math.min(canvas.height, canvas.width);
    const data = ctx.getImageData(0, 0, w, h).data;
    const k = 16 / w;
    const on = (x, y) => x >= 0 && y >= 0 && x < w && y < h && data[(y * w + x) * 4 + 3] > 127;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      if (!on(x, y)) continue;
      const u = x * k, v = y * k;
      const faces = {up: {tex: name, uv: [u, v, u + k, v + k]}, down: {tex: name, uv: [u, v, u + k, v + k]}};
      if (!on(x - 1, y)) faces.west = {tex: name, uv: [u, v, u + k, v + k]};
      if (!on(x + 1, y)) faces.east = {tex: name, uv: [u, v, u + k, v + k]};
      if (!on(x, y - 1)) faces.north = {tex: name, uv: [u, v, u + k, v + k]};
      if (!on(x, y + 1)) faces.south = {tex: name, uv: [u, v, u + k, v + k]};
      addBox(mb, grid, atlas, o, [x * k * size, lift, y * k * size], [(x + 1) * k * size, lift + size, (y + 1) * k * size], faces, {yaw, pivot: [8 * size, 0, 8 * size]});
    }
  }

  // ── Chiseled bookcase block ────────────────────────────────────────────
  // The front has six real recesses; books are drawn separately so they
  // can move. `facing` is +1 when the front looks toward +x.
  const SLOT_X = [[1, 5], [6, 10], [11, 15]];
  const SLOT_Y = [[1, 7], [9, 15]];
  const RECESS = 7;

  function shelfBlock(mb, grid, atlas, x, y, z, facing) {
    // Work in a local frame where the front is +z (south); the yaw swings it
    // round to face the hall.
    const yaw = facing > 0 ? -Math.PI / 2 : Math.PI / 2;
    const o = [x, y, z];
    const front = 'chiseled_bookshelf_empty';
    const away = [facing, 0, 0];
    const opts = {yaw, away};
    // Solid body behind the recesses.
    const hidden = (dx, dy, dz) => {
      const n = grid.get(x + dx, y + dy, z + dz);
      return n && n.opaque;
    };
    const body = {};
    if (!hidden(0, 1, 0)) body.up = {tex: 'chiseled_bookshelf_top'};
    if (!hidden(0, -1, 0)) body.down = {tex: 'chiseled_bookshelf_top'};
    // Local west/east map to world ±z depending on facing.
    const localWestWorldDz = facing > 0 ? 1 : -1;
    if (!hidden(0, 0, localWestWorldDz)) body.west = {tex: 'chiseled_bookshelf_side'};
    if (!hidden(0, 0, -localWestWorldDz)) body.east = {tex: 'chiseled_bookshelf_side'};
    addBox(mb, grid, atlas, o, [0, 0, 0], [16, 16, 16 - RECESS], body, opts);
    // Front frame strips, textured from the matching part of the face.
    const strip = (x0, y0, x1, y1) => {
      const uv = [x0, 16 - y1, x1, 16 - y0];
      const faces = {south: {tex: front, uv}};
      // Close the frame's outer edges where no neighbouring shelf does.
      if (x0 === 0 && !hidden(0, 0, localWestWorldDz)) faces.west = {tex: 'chiseled_bookshelf_side', uv: [16 - RECESS, 16 - y1, 16, 16 - y0]};
      if (x1 === 16 && !hidden(0, 0, -localWestWorldDz)) faces.east = {tex: 'chiseled_bookshelf_side', uv: [0, 16 - y1, RECESS, 16 - y0]};
      if (y1 === 16 && !hidden(0, 1, 0)) faces.up = {tex: 'chiseled_bookshelf_top', uv: [x0, 16 - RECESS, x1, 16]};
      if (y0 === 0 && !hidden(0, -1, 0)) faces.down = {tex: 'chiseled_bookshelf_top', uv: [x0, 0, x1, RECESS]};
      addBox(mb, grid, atlas, o, [x0, y0, 16 - RECESS], [x1, y1, 16], faces, opts);
    };
    strip(0, 0, 16, 1); strip(0, 7, 16, 9); strip(0, 15, 16, 16);
    strip(0, 1, 1, 7); strip(15, 1, 16, 7); strip(0, 9, 1, 15); strip(15, 9, 16, 15);
    // Wooden dividers between the three cubbies of each row.
    for (const [a, b] of [[5, 6], [10, 11]]) {
      for (const [y0, y1] of [[1, 7], [9, 15]]) {
        const wood = {tex: 'chiseled_bookshelf_top', uv: [a, y0, b, y1]};
        addBox(mb, grid, atlas, o, [a, y0, 16 - RECESS], [b, y1, 16], {south: wood}, opts);
      }
    }
    // Recess walls, darker the deeper they go.
    const depthAo = c => {
      const local = facing > 0 ? (c[0] - x) : (x + 1 - c[0]);
      return 0.35 + 0.65 * Math.min(1, Math.max(0, (local * 16 - (16 - RECESS)) / RECESS));
    };
    for (const [sy0, sy1] of SLOT_Y) {
      for (const [sx0, sx1] of SLOT_X) {
        // The cubby walls borrow the dark interior of the front texture, so
        // the slots read as deep and shadowed like the game's, only real.
        const uv = [sx0 + 0.5, 16 - sy1 + 0.5, sx1 - 0.5, 16 - sy0 - 0.5];
        const inner = {tex: front, uv, tint: [0.9, 0.86, 0.82]};
        const back = {tex: front, uv, ao: 0.4};
        addBox(mb, grid, atlas, o, [sx0, sy0, 16 - RECESS], [sx1, sy1, 16 - RECESS], {south: back}, opts);
        addBox(mb, grid, atlas, o, [sx0, sy0, 16 - RECESS], [sx1, sy0, 16], {up: {...inner, tint: [1.15, 1.1, 1.0]}}, {...opts, ao: depthAo});
        addBox(mb, grid, atlas, o, [sx0, sy1, 16 - RECESS], [sx1, sy1, 16], {down: inner}, {...opts, ao: depthAo});
        addBox(mb, grid, atlas, o, [sx0, sy0, 16 - RECESS], [sx0, sy1, 16], {east: inner}, {...opts, ao: depthAo});
        addBox(mb, grid, atlas, o, [sx1, sy0, 16 - RECESS], [sx1, sy1, 16], {west: inner}, {...opts, ao: depthAo});
      }
    }
  }

  // World-space box of one slot's opening, for picking and for books.
  // Returns {center, width, height, depth, normal} in block units.
  function slotGeometry(caseInfo, slot) {
    const local = slot % SLOTS;
    const row = Math.floor(local / SLOT_COLS), col = local % SLOT_COLS;
    const blockCol = Math.floor(col / 3), slotCol = col % 3;
    const blockRow = Math.floor(row / 2), slotRow = row % 2;
    const [px0, px1] = SLOT_X[slotCol];
    // Rows count down from the top of the case; texture rows count down too.
    const [py0, py1] = SLOT_Y[slotRow];
    const yTop = caseInfo.y1 - blockRow;
    const y0 = yTop - py1 / 16, y1 = yTop - py0 / 16;
    // Columns run left to right as seen from the hall.
    const f = caseInfo.facing;
    const along = f > 0 ? -1 : 1; // world z direction of "right" for the viewer
    const zStart = f > 0 ? caseInfo.z1 : caseInfo.z0;
    const zBlock = zStart + along * blockCol;
    const za = zBlock + along * px0 / 16, zb = zBlock + along * px1 / 16;
    return {
      z0: Math.min(za, zb), z1: Math.max(za, zb), y0, y1,
      faceX: caseInfo.faceX, backX: caseInfo.faceX - f * RECESS / 16, facing: f,
      center: [caseInfo.faceX - f * 0.2, (y0 + y1) / 2, (za + zb) / 2],
      row, col,
    };
  }

  // ── The hall ───────────────────────────────────────────────────────────
  function layout(subjectCount) {
    const cases = subjectCount + 1; // one empty alcove for "new bookcase"
    const sections = Math.max(2, Math.ceil(cases / 2));
    const hallEnd = -sections * HALL.section; // z of the last pillar's far side
    return {sections, hallStart: HALL.foyer, hallEnd, endWall: hallEnd - HALL.end};
  }

  function caseSlots(subjectCount) {
    const out = [];
    for (let i = 0; i <= subjectCount; i++) {
      const section = Math.floor(i / 2);
      const facing = i % 2 === 0 ? 1 : -1;
      // Cells -5k-4 … -5k-1, so z ∈ [-5k-4, -5k].
      const z0 = -section * HALL.section - HALL.caseWidth;
      const cellX = facing > 0 ? -HALL.halfWidth : HALL.caseFace;
      out.push({
        index: i, section, facing, cellX,
        faceX: facing > 0 ? -HALL.caseFace : HALL.caseFace,
        z0, z1: z0 + HALL.caseWidth, y0: 0, y1: HALL.caseHeight,
        placeholder: i === subjectCount,
      });
    }
    return out;
  }

  function build(T, atlas, canvases, subjects) {
    const L = layout(subjects.length);
    const cases = caseSlots(subjects.length);
    const minZ = L.endWall - 2, maxZ = L.hallStart + 3;
    const grid = new Grid([-12, -3, minZ], [12, 12, maxZ]);
    const W = HALL.halfWidth, H = HALL.height;

    // Ground outside and a floor inside.
    grid.fill([-12, -3, minZ], [11, -2, maxZ - 1], B.dirt);
    grid.fill([-12, -1, minZ], [11, -1, maxZ - 1], B.grass);
    grid.fill([-W - 1, -1, L.endWall], [W, -1, L.hallStart], B.dark_oak_planks);
    // Stone footing under the walls.
    grid.fill([-W - 1, -1, L.endWall], [-W - 1, -1, L.hallStart], B.cobblestone);
    grid.fill([W, -1, L.endWall], [W, -1, L.hallStart], B.cobblestone);

    // Walls: planks between log pillars, with windows over the bookcases.
    for (let z = L.endWall; z <= L.hallStart; z++) {
      for (const x of [-W - 1, W]) {
        grid.fill([x, 0, z], [x, H - 1, z], B.oak_planks);
        grid.set(x, 3, z, B.beam_z);
      }
    }
    // Ceiling and roof.
    grid.fill([-W - 1, H, L.endWall], [W, H, L.hallStart], B.dark_oak_planks);
    grid.fill([-W - 1, H + 1, L.endWall], [W, H + 1, L.hallStart], B.spruce_planks);
    // End walls.
    grid.fill([-W - 1, 0, L.endWall], [W, H, L.endWall], B.stone_bricks);
    grid.fill([-W - 1, 0, L.hallStart], [W, H, L.hallStart], B.oak_planks);

    const windows = [];
    for (let k = 0; k <= L.sections; k++) {
      const zp = -k * HALL.section;
      for (const x of [-W - 1, W]) grid.fill([x, 0, zp], [x, H - 1, zp], B.pillar);
      // Ceiling beam across the hall at each pillar.
      for (let x = -W; x < W; x++) grid.set(x, H - 1, zp, B.beam_x);
      if (k < L.sections) {
        // Window openings above the cases: two rows, four wide.
        for (const x of [-W - 1, W]) {
          for (let z = zp - 4; z <= zp - 1; z++) {
            for (const y of [4, 5]) { grid.set(x, y, z, AIR); windows.push([x, y, z]); }
          }
        }
      }
    }
    // Windows in the end room's side walls, and a round of trees outside.
    for (const x of [-W - 1, W]) {
      for (let z = L.endWall + 2; z <= L.endWall + 6; z++) for (const y of [2, 3, 4]) { grid.set(x, y, z, AIR); windows.push([x, y, z]); }
    }

    // Bookcases: chiseled shelves 4 wide × 3 high.
    for (const c of cases) {
      if (c.placeholder) continue;
      for (let z = c.z0; z < c.z1; z++) for (let y = 0; y < 3; y++) grid.set(c.cellX, y, z, B.shelf);
    }
    // Plain bookshelves line the end room, framing the fireplace.
    for (const x of [-W, W - 1]) for (let z = L.endWall + 1; z <= L.endWall + 1; z++) for (let y = 0; y < 3; y++) grid.set(x, y, z, B.bookshelf);
    for (const x of [-4, -3, 2, 3]) for (let y = 0; y < 4; y++) grid.set(x, y, L.endWall + 1, B.bookshelf);

    // Fireplace: a stone chimney breast with an open hearth.
    const fz = L.endWall + 1;
    grid.fill([-2, 0, fz], [1, H - 1, fz], B.stone_bricks);
    grid.fill([-2, -1, fz + 1], [1, -1, fz + 1], B.smooth_stone);
    grid.set(-1, 0, fz, AIR); grid.set(0, 0, fz, AIR); grid.set(-1, 1, fz, AIR); grid.set(0, 1, fz, AIR);
    grid.set(-2, 3, fz, B.mossy_stone_bricks); grid.set(1, 5, fz, B.mossy_stone_bricks);

    // Trees outside the windows.
    const trees = [];
    for (let k = -1; k <= L.sections + 1; k++) {
      for (const side of [-1, 1]) {
        const tz = -k * HALL.section - 2 + (side > 0 ? 1 : -1);
        const tx = side * (W + 4);
        trees.push([tx, tz]);
      }
    }
    for (const [tx, tz] of trees) {
      if (tz < minZ + 2 || tz > maxZ - 3) continue;
      for (let y = 0; y < 5; y++) grid.set(tx, y, tz, B.oak_log);
      for (let dx = -2; dx <= 2; dx++) for (let dz = -2; dz <= 2; dz++) for (let dy = 3; dy <= 6; dy++) {
        const r = Math.abs(dx) + Math.abs(dz) + Math.max(0, dy - 5) * 2;
        if (r > 3 || (dx === 0 && dz === 0 && dy < 5)) continue;
        if (Math.abs(tx + dx) <= W) continue;
        if (!grid.get(tx + dx, dy, tz + dz)) grid.set(tx + dx, dy, tz + dz, (tx + tz) % 3 ? B.leaves : B.spruce_leaves);
      }
    }

    // ── Light sources ───────────────────────────────────────────────────
    // Hanging lanterns down the middle, and lanterns standing on brackets in
    // the gaps between bookcases.
    const lamps = [], fires = [], candles = [];
    for (let k = 0; k < L.sections; k++) lamps.push({cell: [-1, 4, -k * HALL.section - 3], hanging: true});
    lamps.push({cell: [-1, 4, L.hallStart - 3], hanging: true});
    lamps.push({cell: [-1, 4, L.endWall + 6], hanging: true});
    for (let k = 0; k <= L.sections; k++) {
      lamps.push({cell: [-W, 3, -k * HALL.section], hanging: false, side: 1});
      lamps.push({cell: [W - 1, 3, -k * HALL.section], hanging: false, side: -1});
    }
    fires.push([0, 0.5, fz + 0.5]);

    grid.lightSky();
    const lampSeeds = lamps.map(l => [...l.cell, 15]);
    const deskZ = L.endWall + 4.5;
    const candleCells = [[-1, 1, Math.floor(deskZ)], [0, 1, Math.floor(deskZ)]];
    grid.propagate('lamp', [...lampSeeds, ...candleCells.map(c => [...c, 12])]);
    grid.propagate('fire', [[-1, 0, fz, 15], [0, 0, fz, 15], [-1, 1, fz, 14], [0, 1, fz, 14]]);

    // ── Geometry ────────────────────────────────────────────────────────
    const mb = new MeshBuilder();
    for (let z = grid.min[2]; z < grid.max[2]; z++) for (let y = grid.min[1]; y < grid.max[1]; y++) for (let x = grid.min[0]; x < grid.max[0]; x++) {
      const b = grid.get(x, y, z);
      if (!b) continue;
      if (b.custom === 'shelf') {
        const c = cases.find(cs => !cs.placeholder && cs.cellX === x && z >= cs.z0 && z < cs.z1);
        shelfBlock(mb, grid, atlas, x, y, z, c ? c.facing : 1);
        continue;
      }
      addBlock(mb, grid, atlas, x, y, z, b);
    }

    // Window panes: thin glass in the middle of each opening.
    const glass = new MeshBuilder();
    for (const [x, y, z] of windows) {
      const pane = {tex: 'glass'};
      addBox(mb, grid, atlas, [x, y, z], [7, 0, 0], [9, 16, 16], {east: pane, west: pane}, {ao: 1});
      addBox(glass, grid, atlas, [x, y, z], [7.5, 0, 0], [8.5, 16, 16], {east: pane, west: pane}, {ao: 1});
      // Sill under the lower row.
      if (!grid.get(x, y - 1, z) || grid.get(x, y - 1, z).opaque) {
        const inward = x < 0 ? 1 : -1;
        addBox(mb, grid, atlas, [x + inward, y, z], inward > 0 ? [0, 0, 0] : [13, 0, 0], inward > 0 ? [3, 2, 16] : [16, 2, 16], sides('spruce_planks'));
      }
    }

    // Carpet runner down the middle, and a rug by the fire.
    for (let z = L.endWall + 1; z < L.hallStart; z++) {
      for (let x = -1; x <= 0; x++) {
        addBox(mb, grid, atlas, [x, 0, z], [0, 0, 0], [16, 1, 16], {up: {tex: 'red_wool'}, north: {tex: 'red_wool'}, south: {tex: 'red_wool'}, east: {tex: 'red_wool'}, west: {tex: 'red_wool'}});
      }
    }
    for (let z = L.endWall + 2; z <= L.endWall + 3; z++) for (let x = -3; x <= 2; x++) {
      if (x >= -1 && x <= 0) continue;
      addBox(mb, grid, atlas, [x, 0, z], [0, 0, 0], [16, 1, 16], {up: {tex: 'brown_wool'}, north: {tex: 'brown_wool'}, south: {tex: 'brown_wool'}, east: {tex: 'brown_wool'}, west: {tex: 'brown_wool'}});
    }

    // Hanging lanterns on chains, and wall lanterns on brackets.
    for (const lamp of lamps) {
      const [x, y, z] = lamp.cell;
      if (lamp.hanging) {
        // Centred on the hall's middle line, which runs between two cells.
        const o = [x + 0.5, y, z];
        lantern(mb, grid, atlas, o, true);
        chain(mb, grid, atlas, [o[0], y + 1, o[2]], H - 1 - (y + 1));
      } else {
        // A plank bracket out of the pillar, the lantern standing on it.
        const toWall = -lamp.side;
        const o = [x + toWall * 0.12, y, z];
        addBox(mb, grid, atlas, o, [4, -2, 4], [12, 0, 12], sides('dark_oak_planks'));
        addBox(mb, grid, atlas, [x, y, z], toWall > 0 ? [10, -2, 7] : [0, -2, 7], toWall > 0 ? [16, -1, 9] : [6, -1, 9], sides('dark_oak_planks'));
        lantern(mb, grid, atlas, o, false);
      }
    }

    // The hearth.
    campfire(mb, grid, atlas, [-1, 0, fz]);
    campfire(mb, grid, atlas, [0, 0, fz]);
    // Mantel with candles and plants.
    addBox(mb, grid, atlas, [-2, 2, fz + 1], [0, 0, 0], [64, 3, 5], sides('dark_oak_planks'));
    candles.push(candle(mb, grid, atlas, [-2, 2.1875, fz + 1], -4, -4, 5));
    candles.push(candle(mb, grid, atlas, [-2, 2.1875, fz + 1], -1, -5, 4));
    candles.push(candle(mb, grid, atlas, [1, 2.1875, fz + 1], 4, -4, 6));
    flowerPot(mb, grid, atlas, [0, 2.1875, fz + 0.9], 'fern');

    // Desk, chair, candles and the book and quill.
    const deskO = [-1, 0, Math.floor(deskZ)];
    desk(mb, grid, atlas, deskO);
    chair(mb, grid, atlas, [-0.5, 0, deskZ + 0.4]);
    candles.push(candle(mb, grid, atlas, [-1, 1, deskO[2]], -3, -4, 6));
    candles.push(candle(mb, grid, atlas, [-1, 1, deskO[2]], 0, -5, 4));
    lantern(mb, grid, atlas, [0.35, 1, deskO[2] - 0.05], false);
    itemSprite(mb, grid, atlas, canvases.ink_sac, 'ink_sac', [-1.0, 1.0, deskO[2] + 0.05], 0.4, 0.3);
    itemSprite(mb, grid, atlas, canvases.feather, 'feather', [-0.85, 1.0, deskO[2] + 0.12], 0.45, -0.6, 0.12);
    // Books stacked at the desk's side.
    addBox(mb, grid, atlas, [0.45, 1, deskO[2] + 0.45], [0, 0, 0], [7, 2, 5], sides('red_wool'), {tint: [0.8, 0.8, 0.8]});
    addBox(mb, grid, atlas, [0.45, 1, deskO[2] + 0.45], [0.5, 2, 0.5], [6.5, 4, 5], sides('brown_wool'));

    // Reading corner by the fire.
    armchair(mb, grid, atlas, [-4, 0, fz + 3], Math.PI * 0.75);
    armchair(mb, grid, atlas, [3, 0, fz + 3], -Math.PI * 0.75);
    addBox(mb, grid, atlas, [-4, 0, fz + 1.2], [2, 0, 2], [14, 14, 14], {north: {tex: 'barrel_side'}, south: {tex: 'barrel_side'}, east: {tex: 'barrel_side'}, west: {tex: 'barrel_side'}, up: {tex: 'barrel_top'}});
    flowerPot(mb, grid, atlas, [-4, 0.875, fz + 1.2], 'poppy');
    flowerPot(mb, grid, atlas, [3, 0, L.hallStart - 1], 'azalea_leaves');
    flowerPot(mb, grid, atlas, [-4, 0, L.hallStart - 1], 'fern');

    // Placeholder alcove: an outline where the next bookcase will go.
    const placeholder = cases.find(c => c.placeholder);

    const world = mb.geometry(T);
    const glassGeo = glass.geometry(T);

    return {
      grid, layout: L, cases, placeholder, lamps, fires, candles,
      geometry: world, glass: glassGeo,
      desk: {z: deskZ, top: 1, center: [0, 1, deskO[2] + 0.5]},
      fire: [0, 0.6, fz + 0.5],
      bounds: {min: [-W - 1, -1, L.endWall], max: [W + 1, H + 2, L.hallStart + 1]},
    };
  }

  // Books as boxes in their slots. Returns geometry plus per-book metadata.
  function buildBooks(T, atlas, grid, cases, subjects, labels, skipIds) {
    const mb = new MeshBuilder();
    const placed = [];
    subjects.forEach((subject, i) => {
      const c = cases[i];
      if (!c || c.placeholder) return;
      for (const book of subject.books) {
        if (skipIds && skipIds.has(book.id)) continue;
        const page = Math.floor(book.slot / SLOTS);
        if (page !== (c.page || 0)) continue;
        const g = slotGeometry(c, book.slot);
        addBook(mb, grid, atlas, g, book, labels);
        placed.push({id: book.id, subjectId: subject.id, slot: book.slot, geo: g});
      }
    });
    return {geometry: mb.geometry(T), placed};
  }

  function hash(n) {
    let h = (n * 2654435761) >>> 0;
    h ^= h >>> 15;
    return (h % 1000) / 1000;
  }

  // One book standing in a slot, spine outward. `g` is its slot.
  function addBook(mb, grid, atlas, g, book, labels, offset = [0, 0, 0], opts = {}) {
    const r = hash(book.id || 7);
    const slotW = g.z1 - g.z0, slotH = g.y1 - g.y0;
    const w = slotW * (0.8 + r * 0.12), h = slotH * (0.8 + hash((book.id || 7) + 13) * 0.16), d = RECESS / 16 * 0.86;
    const f = g.facing;
    const zc = (g.z0 + g.z1) / 2 + offset[2];
    const x1 = g.faceX - f * 0.03 + offset[0];
    const x0 = x1 - f * d;
    const y0 = g.y0 + offset[1], y1 = y0 + h;
    const cover = DYES[book.cover != null ? book.cover : 12];
    const tint = [cover[0] / 255, cover[1] / 255, cover[2] / 255];
    const lx = Math.min(x0, x1), hx = Math.max(x0, x1);
    const a = [lx, y0, zc - w / 2], b = [hx, y1, zc + w / 2];
    const light = opts.light || grid.sample([g.faceX + f * 0.4, (y0 + y1) / 2, zc], [f, 0, 0]);
    const lights = [light, light, light, light];
    const lab = labels && labels.spine(book);
    for (const dir of DIRS) {
      const F = FACES[dir];
      const corners = F.c(a, b);
      const isSpine = (dir === 'east' && f > 0) || (dir === 'west' && f < 0);
      const isTop = dir === 'up';
      let tile = [atlas.index.leather.cell, 1, 1], faceTint = tint;
      let labelUv = null;
      if (isTop) { tile = [atlas.index.pages.cell, 1, 1]; faceTint = [1, 1, 1]; }
      if (isSpine && lab) {
        labelUv = [[lab.u0, lab.v0], [lab.u0, lab.v1], [lab.u1, lab.v1], [lab.u1, lab.v0]];
      }
      const isBack = (dir === 'west' && f > 0) || (dir === 'east' && f < 0);
      const ao = isBack ? 0.4 : dir === 'down' ? 0.5 : 1;
      const uv = isTop ? uvCorners([0, 0, 16, 16], 90) : uvCorners([0, 0, 16, 16]);
      mb.quad(corners, F.n, uv, tile, lights, [ao, ao, ao, ao], {tint: faceTint, labelUv, emit: opts.emit || 0});
    }
  }

  const DYES = [
    [249, 255, 254], [249, 128, 29], [199, 78, 189], [58, 179, 218], [254, 216, 61], [128, 199, 31], [243, 139, 170], [71, 79, 82],
    [157, 157, 151], [22, 156, 156], [137, 50, 184], [60, 68, 170], [131, 84, 50], [94, 124, 22], [176, 46, 38], [29, 29, 33],
  ];

  window.LibraryWorld = {
    HALL, SLOTS, SLOT_COLS, SLOT_ROWS, DYES, RECESS,
    MeshBuilder, Grid, FACES, addBox, addBook, build, buildBooks, slotGeometry, layout, caseSlots, lantern, sides, all, itemSprite,
  };
})();
