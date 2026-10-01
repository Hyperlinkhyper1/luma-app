// The library hall as blocks: a voxel grid for walls, floor and bookcases,
// Minecraft-style light (sky light through the windows, block light from
// lanterns, candles and the fire, flood-filled and smoothed per vertex with
// ambient occlusion), and small models for everything that is not a cube.
//
// The hall is a timber-framed cottage: plaster walls between dark oak posts,
// built-in bookcases running floor to fascia between them, and a reading
// room with a fireplace at the far end.
(() => {
  'use strict';

  // ── Layout constants (block units) ─────────────────────────────────────
  const HALL = {
    halfWidth: 5,     // interior spans x ∈ [-5, 5]
    caseFace: 4,      // bookcase fronts at x = ±4
    height: 7,        // ceiling underside
    section: 5,       // 4-wide bookcase + 1 post
    caseWidth: 4,
    shelfBottom: 1,   // top of the cabinets
    shelfTop: 5,      // underside of the fascia
    caseTop: 5.875,   // top of the cornice
    foyer: 6,         // entrance room in front of the first section
    end: 9,           // reading room past the last section
    eye: 1.9,
  };
  const SLOT_COLS = 18, SLOT_ROWS = 4, SLOTS = SLOT_COLS * SLOT_ROWS;

  // Storeys. The ground floor holds six tall bookcases; past that the hall
  // gains floors above it under a much lower ceiling, each with six shorter
  // cases a shelf down.
  const CASES_PER_FLOOR = 6;
  const PROFILES = {
    ground: {height: 7, shelfBottom: 1, shelfTop: 5, caseTop: 5.875, rows: 4, cabinet: true},
    upper: {height: 4, shelfBottom: 0.25, shelfTop: 3.25, caseTop: 3.875, rows: 3, cabinet: false},
  };
  for (const p of Object.values(PROFILES)) p.slots = SLOT_COLS * p.rows;
  // Where each floor's walking surface is; the block under it is its floor.
  const floorBase = f => (f === 0 ? 0 : 8 + (f - 1) * 5);
  const profileOf = f => (f === 0 ? PROFILES.ground : PROFILES.upper);
  // The block layer that is a floor's ceiling (and the next one's floor).
  const ceilingOf = f => floorBase(f) + profileOf(f).height;
  // The spiral stair between floors: a post in the middle of a 3×3 well by
  // the foyer's east wall, two turns of sixteen shallow treads per storey.
  const STAIR = {x0: 2, z0: 1, cx: 3, cz: 2};
  // The basement under the hall: a snug little hall under the foyer, reached
  // by a ladder through a hatch in the floor, and behind a door in its back
  // wall the classroom. `base` is its walking surface; cells x0..x1 across,
  // the cellar's z from `divide` + 1 to `front`, the classroom's from `back`
  // to `divide` - 1. The hatch is the floor cell above the ladder.
  const BASEMENT = {base: -6, x0: -5, x1: 4, front: 5, divide: -1, back: -13, hatch: [-5, 3]};
  const BOARD = 1.5 / 16;  // shelf board thickness
  const DEPTH = 15 / 16;   // front of a bookcase to its back panel
  const SIDE = 1 / 16;     // outer uprights
  const MID = 1 / 16;      // half the middle divider
  const RECESS = DEPTH;

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
        // Kind 1 samples the label sheet, kind 2 the reader's skin.
        if (opts.labelUv) this.label.push(opts.labelUv[i][0], opts.labelUv[i][1], opts.labelKind || 1, 0);
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
  const AXIS = {east: [0, 1], west: [0, -1], up: [1, 1], down: [1, -1], south: [2, 1], north: [2, -1]};
  const dirOf = v => (v[0] > 0.5 ? 'east' : v[0] < -0.5 ? 'west' : v[2] > 0.5 ? 'south' : v[2] < -0.5 ? 'north' : v[1] > 0.5 ? 'up' : 'down');

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
          // The island floats: open sky lies under it too.
          for (let y = this.min[1]; y < this.max[1]; y++) {
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
  block('stone_bricks', {all: 'stone_bricks'});
  block('mossy_stone_bricks', {all: 'mossy_stone_bricks'});
  block('cobblestone', {all: 'cobblestone'});
  block('smooth_stone', {all: 'smooth_stone'});
  block('dirt', {all: 'dirt'});
  block('grass', {top: 'grass_block_top', bottom: 'dirt', side: 'grass_side'});
  block('stone', {all: 'stone'});
  block('andesite', {all: 'andesite'});
  block('coal_ore', {all: 'coal_ore'});
  block('coarse_dirt', {all: 'coarse_dirt'});
  block('birch_log', {top: 'birch_log_top', bottom: 'birch_log_top', side: 'birch_log'});
  block('spruce_log', {top: 'spruce_log_top', bottom: 'spruce_log_top', side: 'spruce_log'});
  block('spruce_log_x', {east: 'spruce_log_top', west: 'spruce_log_top', side: 'spruce_log'}, {rotFaces: ['north', 'south', 'up', 'down']});
  block('pumpkin', {top: 'pumpkin_top', bottom: 'pumpkin_top', side: 'pumpkin_side'});
  block('hay', {top: 'hay_block_top', bottom: 'hay_block_top', side: 'hay_block_side'});
  block('mossy_cobblestone', {all: 'mossy_cobblestone'});
  // Still water: drawn by hand, its surface a little below the block top.
  block('water', {all: 'water'}, {custom: true, opaque: false});
  // Autumn: the leaf sheets are grey and every tree takes its own colour.
  // Tints multiply linear light, so they are given in sRGB and converted.
  const srgb = c => c.map(v => Math.pow(v, 2.2));
  const FOLIAGE = {
    orange: srgb([0.95, 0.54, 0.16]), red: srgb([0.84, 0.24, 0.12]), yellow: srgb([0.96, 0.8, 0.24]),
    spruce: srgb([0.4, 0.54, 0.36]), amber: srgb([0.9, 0.66, 0.2]),
  };
  for (const [name, tint] of Object.entries(FOLIAGE)) {
    block('leaves_' + name, {all: name === 'yellow' ? 'birch_leaves' : name === 'spruce' ? 'spruce_leaves' : 'oak_leaves'}, {opaque: false, cutout: true, tint});
  }
  // Drawn by hand: a path sits a pixel low, stairs make the roof, and a
  // jack o'lantern's face glows.
  block('path', {top: 'dirt_path_top', bottom: 'dirt', side: 'dirt_path_side'}, {custom: true});
  block('stair_e', {all: 'dark_oak_planks'}, {custom: true, rise: 1});
  block('stair_w', {all: 'dark_oak_planks'}, {custom: true, rise: -1});
  for (const dir of ['north', 'south', 'east', 'west']) {
    block('jack_' + dir, {[dir]: 'jack_o_lantern', top: 'pumpkin_top', bottom: 'pumpkin_top', side: 'pumpkin_side'}, {emit: {[dir]: 1}});
    block('carved_' + dir, {[dir]: 'carved_pumpkin', top: 'pumpkin_top', bottom: 'pumpkin_top', side: 'pumpkin_side'});
  }
  // Warm lime plaster between the timbers.
  block('plaster', {all: 'calcite'}, {tint: [1.0, 0.95, 0.86]});
  // Limewash put on in different years, and the brick behind it where it
  // has fallen away.
  block('plaster_warm', {all: 'calcite'}, {tint: [0.97, 0.87, 0.71]});
  block('plaster_grey', {all: 'calcite'}, {tint: [0.86, 0.85, 0.81]});
  block('bricks', {all: 'bricks'}, {tint: [0.74, 0.66, 0.6]});
  const isPlaster = b => b === B.plaster || b === B.plaster_warm || b === B.plaster_grey;
  const isTimber = b => b === B.post || b === B.beam_x || b === B.beam_z;
  const isStone = b => b === B.stone_bricks || b === B.mossy_stone_bricks;
  block('post', {top: 'dark_oak_log_top', bottom: 'dark_oak_log_top', side: 'dark_oak_log'});
  block('beam_x', {east: 'dark_oak_log_top', west: 'dark_oak_log_top', side: 'dark_oak_log'}, {rotFaces: ['north', 'south', 'up', 'down']});
  block('beam_z', {north: 'dark_oak_log_top', south: 'dark_oak_log_top', side: 'dark_oak_log'}, {rotFaces: ['east', 'west']});
  block('oak_log', {top: 'spruce_log_top', bottom: 'spruce_log_top', side: 'oak_log'});
  block('oak_planks', {all: 'oak_planks'});
  block('bookshelf', {top: 'oak_planks', bottom: 'oak_planks', side: 'bookshelf'});
  // Built-in bookcases: solid for light, drawn by builtInCase.
  block('case', {all: 'spruce_planks'}, {custom: true});

  function faceTexture(b, dir) {
    const f = b.faces;
    if (f[dir]) return f[dir];
    if (f.all) return f.all;
    // A beam names only its end grain; its other four faces are all bark.
    if (dir === 'up') return f.top || f.side;
    if (dir === 'down') return f.bottom || f.top || f.side;
    return f.side;
  }

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
      // A built-in bookcase stops a hair short of the wall behind it, so the
      // wall still needs its face there or the gap shows the sky.
      if (neighbour && neighbour.opaque && !neighbour.custom) continue;
      // Leaves keep the faces between them, as the game's fancy leaves do,
      // so a crown looks full rather than hollow when seen through.
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
      const uv = uvCorners([0, 0, 16, 16], b.rotFaces && b.rotFaces.includes(dir) ? 90 : 0);
      mb.quad(corners, F.n, uv, tileOf(atlas, faceTexture(b, dir)), lights, aos, {tint: b.tint, emit: b.emit ? b.emit[dir] || 0 : 0});
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
        doubleSided: face.double || opts.doubleSided, labelUv: face.labelUv, labelKind: face.labelKind,
      });
    }
  }

  // A box in world block units, cut into block-sized pieces so the
  // per-corner light follows the lamps along long boards. Textures are laid
  // on in world space and repeat per block, so neighbouring boxes line up.
  function box(K, a, b, faces, opts = {}) {
    // A face with its own picture (a label, a painting) stays in one piece.
    const n = opts.whole ? [1, 1, 1] : [0, 1, 2].map(k => Math.max(1, Math.ceil(b[k] - a[k] - 1e-3)));
    for (let i = 0; i < n[0]; i++) for (let j = 0; j < n[1]; j++) for (let l = 0; l < n[2]; l++) {
      const at = [i, j, l];
      const pa = [0, 1, 2].map(k => a[k] + (b[k] - a[k]) * at[k] / n[k]);
      const pb = [0, 1, 2].map(k => a[k] + (b[k] - a[k]) * (at[k] + 1) / n[k]);
      const part = {};
      for (const dir of DIRS) {
        if (!faces[dir]) continue;
        const [k, s] = AXIS[dir];
        if (s < 0 ? at[k] !== 0 : at[k] !== n[k] - 1) continue;
        part[dir] = faces[dir];
      }
      addBox(K.mb, K.grid, K.atlas, [0, 0, 0], pa.map(v => v * 16), pb.map(v => v * 16), part, {...opts, light: opts.light || K.light});
    }
  }

  const all = (tex, extra = {}) => Object.fromEntries(DIRS.map(d => [d, {tex, ...extra}]));
  const sides = (tex, top, bottom, extra = {}) => ({north: {tex, ...extra}, south: {tex, ...extra}, east: {tex, ...extra}, west: {tex, ...extra}, up: {tex: top || tex, ...extra}, down: {tex: bottom || top || tex, ...extra}});

  // ── Frames ─────────────────────────────────────────────────────────────
  // A frame on something standing against a wall: u runs left to right as
  // seen from the room, v up from the floor, w back from the front plane;
  // all in blocks. `origin` is the front plane's bottom-left corner.
  function frame(origin, right, n) {
    const p = (u, v, w) => [origin[0] + right[0] * u - n[0] * w, origin[1] + v, origin[2] + right[2] * u - n[2] * w];
    const names = {front: dirOf(n), back: dirOf(n.map(v => -v)), right: dirOf(right), left: dirOf(right.map(v => -v)), top: 'up', bottom: 'down'};
    return {
      p, n, right, names,
      box(K, u0, v0, w0, u1, v1, w1, local, opts = {}) {
        const c0 = p(u0, v0, w0), c1 = p(u1, v1, w1);
        const a = [0, 1, 2].map(k => Math.min(c0[k], c1[k])), b = [0, 1, 2].map(k => Math.max(c0[k], c1[k]));
        const faces = {};
        for (const [key, face] of Object.entries(local)) if (face) faces[names[key]] = face;
        box(K, a, b, faces, {away: n, ...opts});
      },
      // How far behind the front plane a world point is.
      depth: c => (origin[0] - c[0]) * n[0] + (origin[2] - c[2]) * n[2],
    };
  }

  // ── Models ─────────────────────────────────────────────────────────────
  // All geometry below is luma's own; only the texture layout follows the
  // game's sheets so the vanilla images line up when they are present.
  function lantern(mb, grid, atlas, o, hanging, opts = {}) {
    const y = hanging ? 1 : 0;
    const body = {tex: 'lantern', uv: [0, 2, 6, 9]};
    const cap = {tex: 'lantern', uv: [0, 9, 6, 15]};
    addBox(mb, grid, atlas, o, [5, y, 5], [11, y + 7, 11], {north: body, south: body, east: body, west: body, up: cap, down: cap}, {emit: 1, ...opts});
    const top = {tex: 'lantern', uv: [1, 0, 5, 2]};
    addBox(mb, grid, atlas, o, [6, y + 7, 6], [10, y + 9, 10], {north: top, south: top, east: top, west: top, up: {tex: 'lantern', uv: [1, 10, 5, 14]}}, {emit: 0.6, ...opts});
    const handle = {tex: 'lantern', uv: [11, 1, 14, hanging ? 5 : 3], double: true};
    addBox(mb, grid, atlas, o, [6.5, y + 9, 8], [9.5, y + (hanging ? 13 : 11), 8], {north: handle}, {yaw: Math.PI / 4, ao: 1, ...opts});
    addBox(mb, grid, atlas, o, [6.5, y + 9, 8], [9.5, y + (hanging ? 13 : 11), 8], {north: handle}, {yaw: -Math.PI / 4, ao: 1, ...opts});
  }

  // A chain from `o` upward, `length` blocks long (fractions allowed).
  function chain(mb, grid, atlas, o, length) {
    for (let i = 0; i < length; i++) {
      const h = Math.min(1, length - i) * 16;
      const link = {tex: 'chain', uv: [0, 16 - h, 3, 16], double: true};
      addBox(mb, grid, atlas, [o[0], o[1] + i, o[2]], [6.5, 0, 8], [9.5, h, 8], {north: link}, {yaw: Math.PI / 4});
      addBox(mb, grid, atlas, [o[0], o[1] + i, o[2]], [6.5, 0, 8], [9.5, h, 8], {north: link}, {yaw: -Math.PI / 4});
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

  // An item sprite extruded one pixel thick, as the game draws dropped items.
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

  // ── Books ──────────────────────────────────────────────────────────────
  const DYES = [
    [249, 255, 254], [249, 128, 29], [199, 78, 189], [58, 179, 218], [254, 216, 61], [128, 199, 31], [243, 139, 170], [71, 79, 82],
    [157, 157, 151], [22, 156, 156], [137, 50, 184], [60, 68, 170], [131, 84, 50], [94, 124, 22], [176, 46, 38], [29, 29, 33],
  ];
  // Covers are bound in leather: each dye is pulled toward tan and darkened
  // a little, so a shelf of them reads as old books rather than wool.
  const LEATHER = [120, 78, 46];
  const COVERS = DYES.map(c => c.map((v, k) => Math.round((v * 0.62 + LEATHER[k] * 0.38) * 0.86)));
  const coverRgb = i => COVERS[i] || COVERS[12];
  // The same colour as a tint: tints multiply linear light, so the sRGB
  // value is converted or the leather comes out pale beside its spine.
  const coverTint = i => coverRgb(i).map(v => Math.pow(v / 255, 2.2));

  function hash(n) {
    let h = (n * 2654435761) >>> 0;
    h ^= h >>> 15;
    return (h % 1000) / 1000;
  }

  const SLOT_W = (HALL.caseWidth / 2 - SIDE - MID) / 9;
  const SLOT_H = 1 - BOARD;

  // A book's size and how far it sits back from the shelf edge; the same
  // book always comes out the same.
  function bookDims(book) {
    const id = book.id || 7;
    return {
      w: SLOT_W * (0.8 + hash(id) * 0.17),
      h: SLOT_H * (0.72 + hash(id + 13) * 0.24),
      d: 0.6 + hash(id + 29) * 0.12,
      back: (0.4 + hash(id + 41) * 1.2) / 16,
    };
  }

  // A closed book standing up in frame `f`: spine toward the room between
  // u0 and u1, standing on v0, `d` deep starting `w0` behind the front.
  //
  // Every board is closed on all sides it can be seen from — the inner
  // faces of the covers too, which show above the page block — and the
  // leather is fitted to each face rather than tiled in world space, so no
  // stray seams run across a cover.
  function bookBoxes(K, f, u0, u1, v0, h, w0, d, tint, spine, opts = {}) {
    const width = u1 - u0;
    const c = Math.min(0.5 / 16, width * 0.2);
    const s = 0.5 / 16;
    const top = v0 + h;
    const light = opts.light || K.grid.sample(f.p((u0 + u1) / 2, v0 + h / 2, -0.3), f.n);
    const o = {light, emit: opts.emit || 0, whole: true};
    const leather = {tex: 'leather', tint, uv: [1, 1, 15, 15]};
    const edge = {tex: 'leather', tint, ao: 0.82, uv: [2, 2, 4, 14]};
    const inner = {tex: 'leather', tint, ao: 0.62, uv: [2, 2, 4, 14]};
    const pages = {tex: 'pages', ao: 0.92, uv: [0, 0, 16, 16]};
    const sunk = 0.35 / 16;
    f.box(K, u0, v0, w0, u1, top, w0 + s, {front: spine, top: edge, bottom: edge, left: edge, right: edge, back: inner}, o);
    f.box(K, u0, v0, w0 + s, u0 + c, top, w0 + d, {left: leather, right: inner, top: edge, back: edge, bottom: edge}, o);
    f.box(K, u1 - c, v0, w0 + s, u1, top, w0 + d, {right: leather, left: inner, top: edge, back: edge, bottom: edge}, o);
    f.box(K, u0 + c, v0, w0 + s, u1 - c, top - sunk, w0 + d - sunk, {top: pages, back: {...pages, ao: 0.7}}, o);
  }

  // One of the user's books, centred on `center` with its spine facing
  // +x (facing 1) or -x (facing -1).
  function addBookAt(mb, grid, atlas, book, labels, center, facing, opts = {}) {
    const {w, h, d} = bookDims(book);
    const n = [facing, 0, 0], right = facing > 0 ? [0, 0, -1] : [0, 0, 1];
    const origin = [center[0] - right[0] * w / 2 + n[0] * d / 2, center[1] - h / 2, center[2] - right[2] * w / 2];
    const f = frame(origin, right, n);
    const tint = coverTint(book.cover != null ? book.cover : 12);
    const lab = labels && labels.spine(book);
    const spine = lab
      ? {tex: 'solid', labelUv: [[lab.u0, lab.v0], [lab.u0, lab.v1], [lab.u1, lab.v1], [lab.u1, lab.v0]]}
      : {tex: 'spine_deco', tint, uv: [0, 0, 16, 16]};
    bookBoxes({mb, grid, atlas}, f, 0, w, 0, h, 0, d, tint, spine, opts);
  }

  // Where a book stands in a slot: its centre, for building and animating.
  function bookCenter(g, book) {
    const {w, h, d, back} = bookDims(book);
    return {pos: [g.faceX - g.facing * (back + d / 2), g.y0 + h / 2, (g.z0 + g.z1) / 2], w, h, d};
  }

  function addBook(mb, grid, atlas, g, book, labels, opts = {}) {
    addBookAt(mb, grid, atlas, book, labels, bookCenter(g, book).pos, g.facing, opts);
  }

  // The hall's own books, for the reading room's shelves: random leather,
  // some leaning, the odd stack lying flat.
  const DECO = [[92, 40, 30], [44, 62, 92], [52, 78, 46], [112, 82, 44], [70, 40, 70], [130, 100, 60], [40, 70, 72], [90, 64, 40], [150, 120, 84]];
  function fillShelves(K, f, width, seed, P = PROFILES.ground, gap = null) {
    const r = LibraryTextures.rng('shelf' + seed);
    for (let v = P.shelfBottom; v < P.shelfTop; v++) {
      const v0 = v + BOARD;
      let u = SIDE + 0.02;
      while (u < width - SIDE - 0.1) {
        if (width >= 4 && u > width / 2 - MID - 0.12 && u < width / 2 + MID) { u = width / 2 + MID + 0.02; continue; }
        // Room left on this shelf for something else (the safe).
        const room = gap && gap.v === v && u < gap.u1 ? gap.u0 - 0.1 : width - SIDE;
        if (gap && gap.v === v && u < gap.u1 && u + 0.16 > room) { u = gap.u1 + 0.02; continue; }
        const roll = r();
        if (roll < 0.07) { u += 0.15 + r() * 0.3; continue; }
        const tint = DECO[Math.floor(r() * DECO.length)].map(c => c * (0.8 + r() * 0.35) / 255);
        if (roll < 0.14 && u + 0.6 < room) {
          // A stack lying flat.
          let y = v0;
          const count = 2 + Math.floor(r() * 3);
          for (let i = 0; i < count; i++) {
            const t = DECO[Math.floor(r() * DECO.length)].map(c => c * (0.8 + r() * 0.3) / 255);
            const th = 0.07 + r() * 0.06, len = 0.42 + r() * 0.14, dp = 0.5 + r() * 0.2;
            const leather = {tex: 'leather', tint: t}, pages = {tex: 'pages', ao: 0.9};
            f.box(K, u + (0.56 - len) / 2, y, 0.05, u + (0.56 - len) / 2 + len, y + th, 0.05 + dp, {front: pages, right: pages, left: {tex: 'spine_deco', tint: t, uv: [2, 0, 14, 16]}, top: leather, bottom: leather, back: pages});
            y += th;
          }
          u += 0.6;
          continue;
        }
        const w = 0.14 + r() * 0.12, h = 0.58 + r() * 0.3, d = 0.55 + r() * 0.18, back = (0.3 + r() * 1.4) / 16;
        const u1 = Math.min(room - 0.01, u + w);
        bookBoxes(K, f, u, u1, v0, Math.min(h, SLOT_H - 0.04), back, d, tint, {tex: 'spine_deco', tint, uv: [0, 0, 16, 16]});
        u = u1 + 0.005;
      }
    }
  }

  // ── Built-in bookcases ─────────────────────────────────────────────────
  // Cabinets along the floor, four long shelves split into two bays, and a
  // fascia with a cornice on top where the name plate goes.
  function builtInCase(K, spec, opts = {}) {
    const f = frame(spec.origin, spec.right, spec.n);
    const P = spec.profile || PROFILES.ground;
    const width = spec.width;
    const ends = !!opts.ends;
    const wood = {tex: 'spruce_planks'}, trim = {tex: 'dark_oak_planks'};
    const end = ends ? wood : null;
    const ao = c => 1 - 0.58 * Math.pow(Math.min(1, Math.max(0, f.depth(c) / DEPTH)), 0.8);
    const light = opts.light;
    // Tall cases stand on cabinets; the low ones upstairs on a plinth.
    if (P.cabinet && opts.drawers) drawerCarcass(K, f, width, end, light);
    else f.box(K, 0, 0, 0, width, P.shelfBottom, DEPTH + 1 / 16, {front: P.cabinet ? {tex: 'cabinet_door'} : trim, left: end, right: end}, {light});
    for (let v = P.shelfBottom; v < P.shelfTop; v++) {
      const first = v === P.shelfBottom;
      const lip = first && P.cabinet ? 1.5 / 16 : 0;
      f.box(K, 0, v, -lip, width, v + BOARD, DEPTH, {
        front: first ? trim : wood, top: wood, bottom: first ? (P.cabinet ? trim : null) : wood, left: end, right: end,
      }, {ao, light});
      const v0 = v + BOARD, v1 = v + 1;
      f.box(K, 0, v0, 0, SIDE, v1, DEPTH, {front: wood, right: wood, left: end}, {ao, light});
      f.box(K, width - SIDE, v0, 0, width, v1, DEPTH, {front: wood, left: wood, right: end}, {ao, light});
      if (width >= 4) f.box(K, width / 2 - MID, v0, 0, width / 2 + MID, v1, DEPTH, {front: wood, left: wood, right: wood}, {ao, light});
    }
    f.box(K, 0, P.shelfBottom, DEPTH, width, P.shelfTop, DEPTH, {front: {tex: 'spruce_planks', tint: [0.7, 0.64, 0.6]}}, {ao: 0.46, light});
    f.box(K, 0, P.shelfTop, 0, width, P.caseTop - 0.125, DEPTH, {front: trim, bottom: wood, left: end ? trim : null, right: end ? trim : null}, {ao, light});
    f.box(K, 0, P.caseTop - 0.125, -2 / 16, width, P.caseTop, DEPTH, {front: trim, top: trim, bottom: trim, left: end ? trim : null, right: end ? trim : null}, {light});
    if (opts.fill != null) fillShelves(K, f, width, opts.fill, P, opts.gap);
    return f;
  }

  // ── Drawers ────────────────────────────────────────────────────────────
  // A tall case's cabinet is a row of drawers, one per block, each holding a
  // row of books standing spine-out. Their slots live far past any shelf
  // page so the shelves' paging never reaches them.
  const DRAWER_BASE = 1000000, DRAWER_SLOTS = 4, DRAWER_PULL = 0.78;
  const DRAWER = {front: 1 / 16, floor: 0.1, side: 0.05, gap: 0.02, low: 0.04, top: 0.98, wall: 0.62};
  const isDrawerSlot = slot => slot >= DRAWER_BASE;
  const drawerOf = slot => Math.floor((slot - DRAWER_BASE) / DRAWER_SLOTS);
  const drawerSlot = (d, i) => DRAWER_BASE + d * DRAWER_SLOTS + i;
  const drawerCount = caseInfo => ((caseInfo.profile || PROFILES.ground).cabinet ? Math.round(caseInfo.spec.width) : 0);

  // The carcass the drawers slide in: dark cavities between thin stiles,
  // drawn instead of the flat drawer fronts.
  function drawerCarcass(K, f, width, end, light) {
    const dark = {tex: 'spruce_planks', tint: [0.42, 0.36, 0.32]}, trim = {tex: 'dark_oak_planks'};
    const ao = c => 1 - 0.6 * Math.min(1, Math.max(0, f.depth(c) / DEPTH));
    f.box(K, 0, 0, 0, width, DRAWER.low, DEPTH, {front: trim, top: dark}, {ao, light});
    f.box(K, 0, DRAWER.low, DEPTH, width, 1, DEPTH, {front: dark}, {ao: 0.4, light});
    for (let k = 0; k <= width; k++) {
      const u0 = Math.max(0, k - DRAWER.gap), u1 = Math.min(width, k + DRAWER.gap);
      f.box(K, u0, DRAWER.low, 0, u1, 1, DEPTH, {front: trim, left: k > 0 ? dark : null, right: k < width ? dark : null}, {ao, light});
    }
    if (end) f.box(K, 0, 0, 0, width, 1, DEPTH + 1 / 16, {left: end, right: end}, {light});
  }

  // One drawer of case `caseInfo`, shut; the scene slides the whole mesh out.
  function drawer(K, caseInfo, d) {
    const f = frame(caseInfo.spec.origin, caseInfo.spec.right, caseInfo.spec.n);
    const y = caseInfo.y0 || 0;
    const wood = {tex: 'spruce_planks'}, inner = {tex: 'spruce_planks', tint: [0.78, 0.7, 0.62]};
    const u0 = d + DRAWER.gap, u1 = d + 1 - DRAWER.gap, back = DEPTH - 0.005;
    const at = (a, v0, w0, b, v1, w1, faces) => f.box(K, a, y + v0, w0, b, y + v1, w1, faces, {whole: true});
    at(u0, DRAWER.low, 0, u1, DRAWER.top, DRAWER.front, {front: {tex: 'cabinet_door', uv: [0, 0, 16, 16]}, back: inner, top: wood, bottom: wood, left: wood, right: wood});
    at(u0, DRAWER.low, DRAWER.front, u0 + DRAWER.side, DRAWER.wall, back, {top: wood, left: wood, right: inner, bottom: wood});
    at(u1 - DRAWER.side, DRAWER.low, DRAWER.front, u1, DRAWER.wall, back, {top: wood, right: wood, left: inner, bottom: wood});
    at(u0 + DRAWER.side, DRAWER.low, back - DRAWER.side, u1 - DRAWER.side, DRAWER.wall, back, {front: inner, top: wood, back: wood, bottom: wood});
    at(u0 + DRAWER.side, DRAWER.low, DRAWER.front, u1 - DRAWER.side, DRAWER.floor, back - DRAWER.side, {top: inner, bottom: wood});
  }

  // Where a drawer slot's book stands, with the drawer pulled `out`.
  function drawerSlotGeometry(caseInfo, slot, out = 0) {
    const d = drawerOf(slot), i = (slot - DRAWER_BASE) % DRAWER_SLOTS;
    const u0 = d + DRAWER.gap + DRAWER.side + i * SLOT_W, u1 = u0 + SLOT_W;
    const y0 = (caseInfo.y0 || 0) + DRAWER.floor, y1 = (caseInfo.y0 || 0) + DRAWER.top;
    const f = caseInfo.facing, along = f > 0 ? -1 : 1;
    const zStart = f > 0 ? caseInfo.z1 : caseInfo.z0;
    const za = zStart + along * u0, zb = zStart + along * u1;
    const faceX = caseInfo.faceX + f * (out - DRAWER.front);
    return {
      z0: Math.min(za, zb), z1: Math.max(za, zb), y0, y1,
      faceX, backX: faceX - f * (DEPTH - 0.1), facing: f,
      center: [faceX - f * 0.2, (y0 + y1) / 2, (za + zb) / 2],
      drawer: d, index: i,
    };
  }

  // The front of drawer `d`, pulled `out`, as a world box for picking; an
  // open drawer's books are picked on their own.
  function drawerBox(caseInfo, d, out = 0) {
    const f = caseInfo.facing, along = f > 0 ? -1 : 1;
    const zStart = f > 0 ? caseInfo.z1 : caseInfo.z0;
    const za = zStart + along * (d + DRAWER.gap), zb = zStart + along * (d + 1 - DRAWER.gap);
    const front = caseInfo.faceX + f * out, rear = front - f * 0.1;
    const y = caseInfo.y0 || 0;
    return [[Math.min(front, rear), y + DRAWER.low, Math.min(za, zb)], [Math.max(front, rear), y + DRAWER.top, Math.max(za, zb)]];
  }

  // World-space box of one slot's opening, for picking and for books.
  // Drawer slots take how far their drawer is pulled out.
  function slotGeometry(caseInfo, slot, out = 0) {
    if (isDrawerSlot(slot)) return drawerSlotGeometry(caseInfo, slot, out);
    const P = caseInfo.profile || PROFILES.ground;
    const local = slot % P.slots;
    const row = Math.floor(local / SLOT_COLS), col = local % SLOT_COLS;
    const bay = col < 9 ? 0 : 1;
    const u0 = bay * HALL.caseWidth / 2 + (bay ? MID : SIDE) + (col % 9) * SLOT_W, u1 = u0 + SLOT_W;
    // Rows count down from the top shelf.
    const vb = (caseInfo.y0 || 0) + P.shelfTop - 1 - row;
    const y0 = vb + BOARD, y1 = vb + 1;
    const f = caseInfo.facing;
    const along = f > 0 ? -1 : 1;
    const zStart = f > 0 ? caseInfo.z1 : caseInfo.z0;
    const za = zStart + along * u0, zb = zStart + along * u1;
    return {
      z0: Math.min(za, zb), z1: Math.max(za, zb), y0, y1,
      faceX: caseInfo.faceX, backX: caseInfo.faceX - f * DEPTH, facing: f,
      center: [caseInfo.faceX - f * 0.2, (y0 + y1) / 2, (za + zb) / 2],
      row, col,
    };
  }

  // ── The hall ───────────────────────────────────────────────────────────
  function layout(subjectCount) {
    const cases = subjectCount + 1; // one empty alcove for "new bookcase"
    const floors = Math.max(1, Math.ceil(cases / CASES_PER_FLOOR));
    const perFloor = CASES_PER_FLOOR / 2;
    const sections = floors > 1 ? perFloor : Math.max(2, Math.ceil(cases / 2));
    const hallEnd = -sections * HALL.section; // z of the last post
    const bases = Array.from({length: floors}, (_, f) => floorBase(f));
    return {sections, floors, bases, top: ceilingOf(floors - 1), hallStart: HALL.foyer, hallEnd, endWall: hallEnd - HALL.end};
  }

  function caseSlots(subjectCount) {
    const out = [];
    for (let i = 0; i <= subjectCount; i++) {
      const floor = Math.floor(i / CASES_PER_FLOOR), j = i % CASES_PER_FLOOR;
      const section = Math.floor(j / 2);
      const facing = j % 2 === 0 ? 1 : -1;
      const base = floorBase(floor), profile = profileOf(floor);
      // Cells -5k-4 … -5k-1, so z ∈ [-5k-4, -5k].
      const z0 = -section * HALL.section - HALL.caseWidth;
      const z1 = z0 + HALL.caseWidth;
      const faceX = facing > 0 ? -HALL.caseFace : HALL.caseFace;
      out.push({
        index: i, section, facing, floor, profile, slots: profile.slots,
        cellX: facing > 0 ? -HALL.halfWidth : HALL.caseFace,
        faceX, z0, z1, y0: base, y1: base + profile.caseTop,
        spec: {origin: [faceX, base, facing > 0 ? z1 : z0], right: facing > 0 ? [0, 0, -1] : [0, 0, 1], n: [facing, 0, 0], width: HALL.caseWidth, profile},
        placeholder: i === subjectCount,
      });
    }
    return out;
  }

  function build(T, atlas, canvases, subjects) {
    const L = layout(subjects.length);
    const cases = caseSlots(subjects.length);
    const W = HALL.halfWidth, H = HALL.height, E = L.endWall, F = L.hallStart, TOP = L.top;
    const R0 = TOP + 1;
    const isle = islandShape(E, F);
    const grid = new Grid([isle.x0, -26, isle.z0], [isle.x1, R0 + W + 11, isle.z1]);
    const K = {mb: new MeshBuilder(), grid, atlas, canvases, candles: [], colliders: []};
    const Fu = window.LibraryFurniture;
    const later = [];
    const lampSeeds = [];
    const windows = [];
    const seats = [];
    const light = (x, y, z, level) => lampSeeds.push([Math.floor(x), Math.floor(y), Math.floor(z), level]);
    // Colliders stop the walker on one floor only.
    const solidBox = (x0, z0, x1, z1, floor = 0) => K.colliders.push([Math.min(x0, x1), Math.min(z0, z1), Math.max(x0, x1), Math.max(z0, z1), floor]);
    // `inward` is the way into the room, for the sill.
    const opening = (x, y, z, axis, inward) => {
      grid.set(x, y, z, AIR);
      windows.push({cell: [x, y, z], axis, inward: inward ?? (axis === 'x' ? (x < 0 ? 1 : -1) : -1)});
    };
    const stones = (x, y, z, p = 0.18) => (cellHash(x, y + 40, z) < p ? B.mossy_stone_bricks : B.stone_bricks);
    const hasStairs = L.floors > 1;

    // The island the cottage stands on, then stone footings and a spruce
    // floor.
    const ground = island(grid, isle);
    grid.fill([-W - 1, -1, E], [W, -1, F], B.cobblestone);
    grid.fill([-W, -1, E + 1], [W - 1, -1, F - 1], B.spruce_planks);

    // Side walls: a stone plinth, plaster above, a timber rail at y 4 and a
    // timber band at every floor above.
    for (let z = E; z <= F; z++) {
      for (const x of [-W - 1, W]) {
        grid.set(x, 0, z, stones(x, 0, z));
        grid.fill([x, 1, z], [x, TOP - 1, z], B.plaster);
        grid.set(x, 4, z, B.beam_z);
        for (let f = 1; f < L.floors; f++) grid.set(x, L.bases[f] - 1, z, B.beam_z);
      }
    }
    // End wall of stone, front wall of plaster with a lintel over the door.
    for (let x = -W - 1; x <= W; x++) for (let y = 0; y <= TOP; y++) grid.set(x, y, E, stones(x, y, E, y < 3 ? 0.24 : 0.08));
    for (let x = -W - 1; x <= W; x++) {
      grid.set(x, 0, F, stones(x, 0, F));
      grid.fill([x, 1, F], [x, TOP - 1, F], B.plaster);
      grid.set(x, 3, F, B.beam_x);
      for (let f = 1; f < L.floors; f++) grid.set(x, L.bases[f] - 1, F, B.beam_x);
    }
    // Plank ceilings, each the floor of the storey above; the top one runs
    // out over the walls under the roof boards.
    for (let f = 0; f < L.floors - 1; f++) grid.fill([-W, ceilingOf(f), E + 1], [W - 1, ceilingOf(f), F - 1], B.spruce_planks);
    grid.fill([-W - 1, TOP, E], [W, TOP, F], B.spruce_planks);
    grid.fill([-W - 1, TOP + 1, E], [W, TOP + 1, F], B.dark_oak_planks);
    // A steep gable of dark oak stairs over it, overhanging a block all
    // round, plastered gables, and the chimney stack at the back.
    for (let k = 0; k <= W + 1; k++) {
      const y = R0 + k;
      for (let z = E - 1; z <= F + 1; z++) {
        grid.set(-W - 2 + k, y, z, B.stair_e);
        grid.set(W + 1 - k, y, z, B.stair_w);
        for (let x = -W - 1 + k; x <= W - k; x++) {
          if (z < E || z > F) continue;
          grid.set(x, y, z, z === E ? stones(x, y, z, 0.1) : z === F ? B.plaster : B.dark_oak_planks);
        }
      }
    }
    for (const x of [-2, 1]) for (let y = R0 + 1; y < R0 + 4; y++) grid.set(x, y, F, B.post);
    grid.fill([-2, R0 + 1, F], [1, R0 + 1, F], B.beam_x);
    // A little attic window in the front gable.
    for (const x of [-1, 0]) opening(x, R0 + 2, F, 'z');
    const chimney = {x0: -1, x1: 0, z0: E - 1, z1: E, top: R0 + W + 4};
    grid.fill([chimney.x0, R0, chimney.z0], [chimney.x1, chimney.top - 1, chimney.z1], B.stone_bricks);
    grid.set(-1, chimney.top - 2, E - 1, B.mossy_stone_bricks);
    // A cap on the stack.
    grid.fill([chimney.x0, chimney.top - 1, chimney.z0], [chimney.x1, chimney.top - 1, chimney.z1], B.cobblestone);

    // Timber frame: a post in each wall and between each pair of cases,
    // tied across the ceiling by a beam. Beams stop short of the stair well.
    const beamEnd = z => (hasStairs && z >= STAIR.z0 && z < STAIR.z0 + 3 ? STAIR.x0 : W);
    const beam = (y, z) => { for (let x = -W; x < beamEnd(z); x++) grid.set(x, y, z, B.beam_x); };
    for (let k = 0; k <= L.sections; k++) {
      const zp = -k * HALL.section;
      for (const x of [-W - 1, W]) grid.fill([x, 0, zp], [x, TOP - 1, zp], B.post);
      for (const x of [-W, W - 1]) grid.fill([x, 0, zp], [x, 5, zp], B.post);
      beam(H - 1, zp);
      for (let f = 1; f < L.floors; f++) {
        const b = L.bases[f];
        for (const x of [-W, W - 1]) grid.fill([x, b, zp], [x, b + 3, zp], B.post);
        beam(b + 3, zp);
      }
    }
    for (const x of [-W - 1, W]) grid.fill([x, 0, F], [x, TOP - 1, F], B.post);
    for (const z of [F - 3, E + 4]) {
      beam(H - 1, z);
      for (let f = 1; f < L.floors; f++) beam(L.bases[f] + 3, z);
    }

    // Each span between posts holds a bookcase — with a strip of windows
    // over it on the ground floor — or, where there is no case, a window
    // seat.
    const nooks = [];
    for (let f = 0; f < L.floors; f++) {
      const b = L.bases[f];
      for (let k = 0; k < L.sections; k++) {
        const zb = -k * HALL.section - 1, za = zb - 3;
        for (const side of [1, -1]) {
          const wallX = side > 0 ? -W - 1 : W;
          const c = cases.find(cs => cs.floor === f && cs.section === k && cs.facing === side);
          if (c) {
            if (f === 0) for (let z = za; z <= zb; z++) opening(wallX, 6, z, 'x');
            if (!c.placeholder) for (let z = c.z0; z < c.z1; z++) for (let y = 0; y < Math.ceil(c.profile.caseTop); y++) grid.set(c.cellX, b + y, z, B.case);
          } else {
            for (let z = za + 1; z <= zb - 1; z++) for (const y of f === 0 ? [1, 2, 3] : [1, 2]) opening(wallX, b + y, z, 'x');
            nooks.push({side, za, zb, floor: f, y: b});
          }
        }
      }
    }

    // Reading room: a stone chimney breast with an open hearth, built-in
    // shelves either side, big windows with seats.
    const fz = E + 1;
    grid.fill([-2, 0, fz], [1, H - 1, fz], B.stone_bricks);
    grid.set(-2, 3, fz, B.mossy_stone_bricks); grid.set(1, 5, fz, B.mossy_stone_bricks); grid.set(0, 6, fz, B.mossy_stone_bricks);
    for (const x of [-1, 0]) for (const y of [0, 1]) grid.set(x, y, fz, AIR);
    grid.fill([-2, -1, fz + 1], [1, -1, fz + 1], B.smooth_stone);
    const endCases = [
      {origin: [-W, 0, fz + 1], right: [1, 0, 0], n: [0, 0, 1], width: 3},
      {origin: [2, 0, fz + 1], right: [1, 0, 0], n: [0, 0, 1], width: 3},
    ];
    for (const spec of endCases) {
      grid.fill([spec.origin[0], 0, fz], [spec.origin[0] + 2, 5, fz], B.case);
      grid.fill([spec.origin[0], 6, fz], [spec.origin[0] + 2, 6, fz], B.plaster);
    }
    for (const x of [-W - 1, W]) for (let z = E + 3; z <= E + 6; z++) for (const y of [1, 2, 3]) opening(x, y, z, 'x');
    // Upstairs the flue carries on as a narrower breast, with windows in
    // the gable end and down both sides.
    for (let f = 1; f < L.floors; f++) {
      const b = L.bases[f];
      grid.fill([-1, b, fz], [0, b + 3, fz], B.stone_bricks);
      for (const x of [-4, -3, 2, 3]) for (const y of [1, 2]) opening(x, b + y, E, 'z', 1);
      for (const x of [-W - 1, W]) for (let z = E + 3; z <= E + 6; z++) for (const y of [1, 2]) opening(x, b + y, z, 'x');
      for (const x of [-4, -3, 2, 3]) for (const y of [1, 2]) opening(x, b + y, F, 'z');
    }

    // Front: a three-block-high double door with a window either side, windows in the
    // side walls.
    for (const x of [-1, 0]) for (const y of [0, 1, 2]) grid.set(x, y, F, AIR);
    for (const x of [-4, -3, 2, 3]) for (const y of [1, 2, 4, 5]) opening(x, y, F, 'z');
    for (const x of [-W - 1, W]) for (let z = 2; z <= 4; z++) for (const y of [1, 2, 3]) opening(x, y, z, 'x');

    // The spiral stair: its well opened through every ceiling but the top.
    const flights = [];
    if (hasStairs) {
      for (let f = 0; f < L.floors - 1; f++) {
        for (let x = STAIR.x0; x < STAIR.x0 + 3; x++) for (let z = STAIR.z0; z < STAIR.z0 + 3; z++) grid.set(x, ceilingOf(f), z, AIR);
        flights.push({from: f, ...LibraryStairs.describe(STAIR, L.bases[f], L.bases[f + 1] - L.bases[f])});
      }
      solidBox(STAIR.x0, STAIR.z0, STAIR.x0 + 3, STAIR.z0 + 3, 0);
      later.push(() => Fu.spiralStair(K, flights, STAIR));
    }

    // ── Weathering the walls ────────────────────────────────────────────
    // The limewash changes tone in blotches rather than block by block.
    const facade = [];
    for (const x of [-W - 1, W]) for (let z = E + 1; z <= F; z++) for (let y = 0; y <= R0 + W; y++) facade.push([x, y, z]);
    for (let x = -W; x < W; x++) for (let y = 0; y <= R0 + W; y++) facade.push([x, y, F]);
    for (const [x, y, z] of facade) {
      if (grid.get(x, y, z) !== B.plaster) continue;
      const h = cellHash(Math.floor(x / 2) + 7, Math.floor(y / 2) + 130, Math.floor(z / 2)) * 0.7 + cellHash(x, y + 131, z) * 0.3;
      grid.set(x, y, z, h < 0.22 ? B.plaster_warm : h > 0.76 ? B.plaster_grey : B.plaster);
    }
    // Plain panels between the side-wall timbers: most get a pair of braces
    // rising off the posts; in the rest the plaster has come away low down
    // and shows the brick. Brick only goes where a bookcase hides it inside.
    const braces = [];
    for (const x of [-W - 1, W]) {
      const inner = x < 0 ? x + 1 : x - 1;
      const bounds = [E];
      for (let z = E + 1; z <= F; z++) if (grid.get(x, 2, z) === B.post) bounds.push(z);
      for (let i = 1; i < bounds.length; i++) {
        const z0 = bounds[i - 1] + 1, z1 = bounds[i] - 1;
        if (z1 - z0 < 2) continue;
        const clear = y => { for (let z = z0; z <= z1; z++) if (!isPlaster(grid.get(x, y, z))) return false; return true; };
        for (let y = 1; y < TOP; y++) {
          if (!clear(y)) continue;
          let y1 = y;
          while (y1 + 1 < TOP && clear(y1 + 1)) y1++;
          const p = {x, z0, z1: z1 + 1, y0: y, y1: y1 + 1};
          y = y1;
          if (p.y1 - p.y0 < 2) continue;
          let backed = true;
          for (let z = p.z0; z < p.z1; z++) for (let yy = p.y0; yy < p.y1; yy++) if (!grid.solid(inner, yy, z)) backed = false;
          if (!backed || cellHash(x, p.y0 + 140, p.z0) < 0.7) { braces.push(p); continue; }
          const w = 2 + Math.floor(cellHash(x, p.y0 + 141, p.z0) * 2);
          const start = p.z0 + Math.floor(cellHash(x, p.y0 + 142, p.z0) * (p.z1 - p.z0 - w + 1));
          for (let z = start; z < start + w; z++) {
            const tall = z > start && z < start + w - 1 && cellHash(x, 143, z) < 0.6 ? 2 : 1;
            for (let yy = p.y0; yy < Math.min(p.y1, p.y0 + tall); yy++) grid.set(x, yy, z, B.bricks);
          }
        }
      }
    }
    // The stone end: a chimney breast carrying the flue down to the ground
    // with shoulders either side of the hearth, and a buttress at each
    // corner stepping out onto a footing.
    for (let y = 0; y < R0; y++) for (let x = chimney.x0; x <= chimney.x1; x++) grid.set(x, y, E - 1, stones(x, y, E - 1, 0.12));
    for (let y = 0; y < 3; y++) for (const x of [chimney.x0 - 1, chimney.x1 + 1]) grid.set(x, y, E - 1, stones(x, y, E - 1, 0.3));
    for (const x of [-W - 1, W]) {
      for (let y = 0; y < 3; y++) grid.set(x, y, E - 1, stones(x, y, E - 1, 0.3));
      if (grid.solid(x, -1, E - 2)) grid.set(x, 0, E - 2, B.mossy_cobblestone);
    }

    // Outside: a path out to a lookout on the island's edge, trees in their
    // autumn colours, a pumpkin patch, and lanterns to walk home by.
    const outside = outdoors(K, isle, ground, {W, E, F, TOP, light, solidBox, later, seats});

    // ── Lights and furniture ────────────────────────────────────────────
    // Hanging lanterns down the middle, and one on an arm off every post,
    // on every floor.
    const lamps = [];
    for (let f = 0; f < L.floors; f++) {
      const b = L.bases[f], top = ceilingOf(f);
      const y = f === 0 ? 4 : b + 2.35;
      for (let k = 0; k < L.sections; k++) lamps.push({cell: [-1, y, -k * HALL.section - 3], hanging: true, top});
      lamps.push({cell: [-1, y, F - 2], hanging: true, top});
      lamps.push({cell: [-1, y, E + 6], hanging: true, top});
      const ay = f === 0 ? 3 : b + 2;
      for (let k = 0; k <= L.sections; k++) {
        lamps.push({cell: [-W + 1, ay, -k * HALL.section], side: 1});
        lamps.push({cell: [W - 2, ay, -k * HALL.section], side: -1});
      }
    }
    for (const l of lamps) light(...l.cell, 15);

    // Something standing at the foot of each post, going round a few kinds.
    const kinds = ['fern', 'stack', 'azalea', 'barrel', 'globe', 'fern', 'stack', 'azalea'];
    for (let f = 0; f < L.floors; f++) {
      const b = L.bases[f];
      for (let k = 1; k <= L.sections; k++) {
        for (const side of [1, -1]) {
          const kind = kinds[(k * 2 + (side > 0 ? 0 : 1) + f * 3) % kinds.length];
          const x = side > 0 ? -W + 1 : W - 2, z = -k * HALL.section;
          const inset = side > 0 ? 0 : 0.3;
          solidBox(x + inset, z + 0.15, x + 0.7 + inset, z + 0.85, f);
          later.push(() => Fu.postDecor(K, kind, [x + (side > 0 ? -0.18 : 0.18), b, z], side));
        }
      }
    }

    // Somewhere to sit: `pos` is where the sitter's hips rest, `yaw` the
    // way they face (as the walker's yaw), `box` what a click lands on.
    const benchSeat = (side, x, za, zb, y = 0) => {
      const x0 = side > 0 ? x : x + 0.25, x1 = side > 0 ? x + 0.75 : x + 1;
      seats.push({pos: [(x0 + x1) / 2 + side * 0.08, y + 0.64, (za + zb) / 2], yaw: side > 0 ? -Math.PI / 2 : Math.PI / 2, box: [[x0, y, za], [x1, y + 1.02, zb]], along: [za + 0.45, zb - 0.45]});
    };
    // An armchair is turned about its cell's centre, so its click box turns
    // with it (`turn`, the model's yaw): the arms stand a pixel proud each
    // side and the wings rise to 21.5 pixels. What stops the walker is the
    // turned footprint's extent, a touch inside.
    const armchairSeat = (cx, cz, yaw, y = 0, floor = 0) => {
      // The chair faces (sin yaw, -cos yaw); sit a little forward of its back.
      seats.push({pos: [cx + 0.5 + Math.sin(yaw) * 0.08, y + 10 / 16, cz + 0.5 - Math.cos(yaw) * 0.08], yaw: -yaw, box: [[cx - 1 / 16, y, cz], [cx + 17 / 16, y + 21.5 / 16, cz + 1]], turn: yaw});
      const reach = (Math.abs(Math.cos(yaw)) * 9 + Math.abs(Math.sin(yaw)) * 8) / 16 - 0.08;
      const deep = (Math.abs(Math.sin(yaw)) * 9 + Math.abs(Math.cos(yaw)) * 8) / 16 - 0.08;
      solidBox(cx + 0.5 - reach, cz + 0.5 - deep, cx + 0.5 + reach, cz + 0.5 + deep, floor);
    };

    // Window seats in the spans without a case.
    for (const nook of nooks) {
      const x = nook.side > 0 ? -W : W - 1;
      solidBox(x, nook.za, x + 1, nook.zb + 1, nook.floor);
      later.push(() => Fu.windowSeat(K, nook.side, x, nook.za, nook.zb + 1, nook.y));
      benchSeat(nook.side, x, nook.za, nook.zb + 1, nook.y);
      light(x, nook.y + 1, nook.za + 2, 10);
    }

    // The hearth, mantel and painting.
    const fires = [[0, 0.5, fz + 0.5]];
    later.push(() => {
      campfire(K.mb, grid, atlas, [-1, 0, fz]);
      campfire(K.mb, grid, atlas, [0, 0, fz]);
      Fu.mantel(K, fz);
    });
    light(-2, 2, fz + 1, 11); light(1, 2, fz + 1, 11);

    // The reading room.
    const deskZ = E + 4.5;
    const deskO = [-1, 0, Math.floor(deskZ)];
    solidBox(-1, deskO[2], 1, deskO[2] + 1);
    light(-1, 1, deskO[2], 12); light(0, 1, deskO[2], 12);
    later.push(() => Fu.desk(K, deskO));
    // The desk chair, pulled up to the desk; the reader sits here to write.
    const chairZ = deskZ + 0.98;
    solidBox(-0.4, chairZ - 0.4, 0.4, chairZ + 0.46);
    later.push(() => Fu.deskChair(K, [0, 0, chairZ]));
    seats.push({pos: [0, Fu.DESK_SEAT, chairZ - 0.04], yaw: 0, box: [[-0.47, 0, chairZ - 0.44], [0.47, 25 / 16, chairZ + 0.44]], desk: true});
    const chairs = [[-3.6, fz + 2.3, 1], [2.6, fz + 2.3, -1]];
    const chairYaw = (cx, cz) => Math.atan2(-(cx + 0.5), -(fz + 0.5 - (cz + 0.5)));
    for (const [cx, cz] of chairs) armchairSeat(cx, cz, chairYaw(cx, cz));
    later.push(() => {
      chairs.forEach(([cx, cz], i) => {
        Fu.armchair(K, [cx, 0, cz], chairYaw(cx, cz), 'red_wool');
        Fu.throwBlanket(K, [cx, 0, cz], chairYaw(cx, cz), i ? 'rust' : 'green');
      });
    });
    solidBox(-2.55, fz + 3.6, -1.75, fz + 4.4);
    light(-2.2, 1, fz + 4, 11);
    later.push(() => Fu.sideTable(K, [-2.65, 0, fz + 3.5], 'tea'));
    solidBox(2.2, fz + 5.2, 2.9, fz + 5.9);
    later.push(() => Fu.globe(K, [2.05, 0, fz + 5.05]));
    solidBox(-3.9, fz + 5.3, -3.3, fz + 5.9);
    light(-3.6, 1, fz + 5.6, 14);
    later.push(() => Fu.floorLamp(K, [-4.1, 0, fz + 5.1]));
    for (const side of [1, -1]) {
      const x = side > 0 ? -W : W - 1;
      solidBox(x, E + 3, x + 1, E + 7);
      later.push(() => Fu.windowSeat(K, side, x, E + 3, E + 7));
      benchSeat(side, x, E + 3, E + 7);
      light(x, 1, E + 5, 10);
    }
    // A cat asleep at the end of the east window seat.
    later.push(() => Fu.cat(K, [W - 0.62, 0.64, E + 6.35], Math.PI * 0.6));
    later.push(() => {
      Fu.rug(K, -4, fz + 1, 4, fz + 5, 'green');
      Fu.ladder(K, endCases[0], 2.1);
      // Firewood stacked by the hearth, and the season on the mantel.
      Fu.garland(K, -2, 2, 1.92, fz + 1.34);
      Fu.logPile(K, [1.05, 0, fz + 1.02]);
      Fu.pumpkin(K, [-1.55, 0, fz + 1.4], 0.62, false);
      Fu.pumpkin(K, [-1.95, 0, fz + 1.8], 0.4, false);
    });
    solidBox(1.05, fz + 1, 1.95, fz + 1.7);
    solidBox(-2.2, fz + 1, -1.2, fz + 2.05);

    // Upstairs over the reading room: a snug under the eaves, two
    // armchairs by the chimney with a table between them.
    for (let f = 1; f < L.floors; f++) {
      const b = L.bases[f];
      const snug = [[-3.9, fz + 2.2, Math.PI / 2], [1.9, fz + 2.2, -Math.PI / 2]];
      for (const [cx, cz, yaw] of snug) {
        armchairSeat(cx, cz, yaw, b, f);
      }
      solidBox(-1.35, fz + 2.3, -0.55, fz + 3.1, f);
      solidBox(-4.3, fz + 0.15, -3.7, fz + 0.75, f);
      solidBox(2.2, fz + 5.2, 2.9, fz + 5.9, f);
      light(-1, b + 1, fz + 2, 12); light(-4, b + 1, fz + 1, 14);
      later.push(() => {
        snug.forEach(([cx, cz, yaw], i) => {
          Fu.armchair(K, [cx, b, cz], yaw, i ? 'green_wool' : 'red_wool');
          Fu.throwBlanket(K, [cx, b, cz], yaw, i ? 'red' : 'rust');
        });
        Fu.sideTable(K, [-1.45, b, fz + 2.2], 'tea');
        Fu.floorLamp(K, [-4.5, b, fz - 0.15]);
        Fu.globe(K, [2.05, b, fz + 5.05]);
        Fu.rug(K, -4, fz + 1, 3, fz + 5, f % 2 ? 'red' : 'green', b);
        Fu.rug(K, -2, 1, 1, 5, 'rust', b);
        Fu.bookStack(K, [-4.2, b, fz + 4.3], 5, 'snug' + f, 0.4);
      });
      // A railing round the stair well, open where the stair comes up.
      if (hasStairs) later.push(() => Fu.stairRail(K, STAIR, b));
      light(0, b + 1, 3, 11);
    }

    // The book review desk: its computer under the front window in the
    // west corner, upstairs when there is an upstairs. The page builds it
    // at `origin`, in LibraryGoods.DESK's frame.
    const pcFloor = hasStairs ? 1 : 0;
    const pcAt = [-3.9, L.bases[pcFloor], F - 6];
    const DESK = window.LibraryGoods.DESK;
    for (const [x0, z0, x1, z1] of DESK.solids) solidBox(pcAt[0] + x0, pcAt[2] + z0, pcAt[0] + x1, pcAt[2] + z1, pcFloor);
    light(-3, pcAt[1] + 1, F - 1, 12);
    const reviewDesk = {origin: pcAt, floor: pcFloor, clear: [pcAt[0] + DESK.box[0][0], pcAt[2] + DESK.box[0][2], pcAt[0] + DESK.box[1][0], pcAt[2] + DESK.box[1][2], pcFloor]};

    // The foyer: a clock, a coat stand, a bench, plants by the door.
    solidBox(-W, 1.1, -W + 0.65, 1.9);
    const clockAt = {face: null};
    later.push(() => { clockAt.face = Fu.clock(K, [-W - 0.17, 0, 1]); });
    // The coat stand makes room for the stair when there is one.
    const coatZ = hasStairs ? 4.1 : 1;
    solidBox(W - 1, coatZ + 0.2, W, coatZ + 0.8);
    later.push(() => Fu.coatStand(K, [W - 1.4, 0, coatZ]));
    for (const x of [-2, 1]) {
      solidBox(x + 0.2, F - 0.8, x + 0.8, F - 0.2);
      later.push(() => Fu.pot(K, [x, 0, F - 1], x < 0 ? 'azalea' : 'fern', true));
    }
    later.push(() => {
      Fu.rug(K, -2, 1, 2, 5, 'red');
      Fu.hangingPlant(K, [-W + 1, H, F - 1]);
      if (!hasStairs) Fu.hangingPlant(K, [W - 2, H, F - 1]);
      Fu.hangingPlant(K, [-W + 1, H, E + 7]);
      Fu.hangingPlant(K, [W - 2, H, E + 7]);
    });
    later.push(() => Fu.rug(K, -1, E + 7, 1, 0, 'red'));

    // Under the foyer, the cellar; behind it, the classroom.
    const cellar = basement(K, {light, solidBox, lamps, later});

    // ── The outside of the house ────────────────────────────────────────
    // A little roof over the door with a lantern either side, ivy up the
    // stone end, and a rain barrel at the corner.
    later.push(() => Fu.porch(K, F));
    light(-2, 2, F + 1, 13); light(1, 2, F + 1, 13);
    solidBox(W + 1.1, F - 0.9, W + 1.9, F - 0.1);
    later.push(() => Fu.barrel(K, [W + 1, 0, F - 1]));
    later.push(() => {
      for (let x = -W - 1; x <= W; x++) {
        if (x >= chimney.x0 - 1 && x <= chimney.x1 + 1) continue;
        if (!grid.solid(x, 0, E)) continue;
        const reach = Math.floor(cellHash(x, 71, E) * (Math.abs(x) > 3 ? 6 : 3));
        for (let y = 0; y < Math.min(reach, TOP); y++) {
          if (cellHash(x, y + 72, E) < 0.25 || !grid.solid(x, y, E) || grid.get(x, y, E - 1)) continue;
          addBox(K.mb, grid, atlas, [x, y, E - 1], [0, 0, 15.7], [16, 16, 15.7], {north: {tex: 'vine', double: true}}, {ao: 1});
        }
      }
    });

    // ── Light ───────────────────────────────────────────────────────────
    grid.lightSky();
    grid.propagate('lamp', lampSeeds);
    grid.propagate('fire', [[-1, 0, fz, 15], [0, 0, fz, 15], [-1, 1, fz, 14], [0, 1, fz, 14]]);

    // ── Geometry ────────────────────────────────────────────────────────
    const mb = K.mb;
    for (let z = grid.min[2]; z < grid.max[2]; z++) for (let y = grid.min[1]; y < grid.max[1]; y++) for (let x = grid.min[0]; x < grid.max[0]; x++) {
      const b = grid.get(x, y, z);
      if (!b) continue;
      if (b === B.path) addPath(mb, grid, atlas, x, y, z);
      else if (b === B.water) addWater(mb, grid, atlas, x, y, z);
      else if (b.rise) addStair(mb, grid, atlas, x, y, z, b);
      else if (!b.custom) addBlock(mb, grid, atlas, x, y, z, b);
    }
    distantIslands(mb, atlas, isle);
    for (const c of cases) if (!c.placeholder) builtInCase(K, c.spec, {drawers: true});
    // The right-hand case keeps a hotel-room safe on its lowest shelf.
    const Vt = Fu.VAULT, vs = endCases[1], vo = Fu.vaultOpening();
    endCases.forEach((spec, i) => builtInCase(K, spec, {fill: i, gap: i === 1 ? {v: 1, u0: Vt.u0, u1: Vt.u1} : null}));
    Fu.vault(K, vs);
    const [ox, , oz] = vs.origin;
    const vaultAt = {
      // The door's hinge (its front left corner) and size.
      hinge: [ox + vo.u0, vo.v0, oz - Vt.front],
      w: vo.u1 - vo.u0, h: vo.v1 - vo.v0,
      box: [[ox + Vt.u0, Vt.v0, oz - Vt.back], [ox + Vt.u1, Vt.v1, oz - Vt.front + 0.06]],
      pile: [ox + Vt.u0 + Vt.wall, Vt.v0 + Vt.wall, oz - 0.07],
      light: [ox + 1.5, 1.4, oz + 0.5],
    };

    // Window panes: thin glass in the middle of each opening, a sill below
    // inside, and painted shutters outside.
    const glass = new MeshBuilder();
    for (const {cell: [x, y, z], axis, inward} of windows) {
      const pane = {tex: 'glass'};
      if (axis === 'x') {
        addBox(mb, grid, atlas, [x, y, z], [7, 0, 0], [9, 16, 16], {east: pane, west: pane}, {ao: 1});
        addBox(glass, grid, atlas, [x, y, z], [7.5, 0, 0], [8.5, 16, 16], {east: pane, west: pane}, {ao: 1});
      } else {
        addBox(mb, grid, atlas, [x, y, z], [0, 0, 7], [16, 16, 9], {north: pane, south: pane}, {ao: 1});
        addBox(glass, grid, atlas, [x, y, z], [0, 0, 7.5], [16, 16, 8.5], {north: pane, south: pane}, {ao: 1});
      }
      const below = grid.get(x, y - 1, z);
      if (below && below.opaque) {
        const sill = sides('dark_oak_planks');
        if (axis === 'x') {
          addBox(mb, grid, atlas, [x + inward, y, z], inward > 0 ? [0, 0, 0] : [13, 0, 0], inward > 0 ? [3, 1.5, 16] : [16, 1.5, 16], sill);
        } else if (inward < 0) {
          addBox(mb, grid, atlas, [x, y, z - 1], [0, 0, 13], [16, 1.5, 16], sill);
        } else {
          addBox(mb, grid, atlas, [x, y, z + 1], [0, 0, 0], [16, 1.5, 3], sill);
        }
      }
    }
    shutters(K, windows, TOP);
    later.push(() => planters(K, windows));

    // The frame stands proud of the plaster, braces in the plain panels, a
    // drip ledge along the plinth, string courses across the stone end, and
    // stone caps on the buttresses and the chimney's shoulders.
    const relief = [];
    for (const x of [-W - 1, W]) for (let z = E + 1; z <= F; z++) for (let y = 0; y < TOP; y++) relief.push([x, y, z, z === F ? [x < 0 ? 'west' : 'east', 'south'] : [x < 0 ? 'west' : 'east']]);
    for (let x = -W; x < W; x++) for (let y = 0; y <= R0 + W; y++) relief.push([x, y, F, ['south']]);
    timberRelief(K, relief, RELIEF);
    for (const p of braces) {
      const out = p.x < 0 ? -1 : 1, plane = p.x < 0 ? p.x : p.x + 1;
      const w = p.z1 - p.z0, h = p.y1 - p.y0;
      const run = w / 2 <= h * 1.4 ? w / 2 : h * 1.1;
      brace(K, 2, plane, out, p.z0, p.y0, p.z0 + run, p.y1, 0.3, 1 / 16);
      brace(K, 2, plane, out, p.z1, p.y0, p.z1 - run, p.y1, 0.3, 1 / 16);
    }
    const exposedAt = (x, y, z, dir) => { const [nx, ny, nz] = FACES[dir].n; return isStone(grid.get(x, y, z)) && !grid.solid(x + nx, y + ny, z + nz); };
    const ledge = 0.1875;
    for (const x of [-W - 1, W]) {
      const dir = x < 0 ? 'west' : 'east';
      const cells = [];
      for (let z = E + 1; z <= F; z++) if (exposedAt(x, 0, z, dir)) cells.push([x, z]);
      course(K, cells, dir, 0.8125, 0.9375, ledge, 'smooth_stone');
    }
    const front = [];
    for (let x = -W - 1; x <= W; x++) if (exposedAt(x, 0, F, 'south')) front.push([x, F]);
    course(K, front, 'south', 0.8125, 0.9375, ledge, 'smooth_stone');
    for (const y of [0, 4, ...L.bases.slice(1).map(b => b - 1)]) {
      const cells = [];
      for (let x = -W - 1; x <= W; x++) if (exposedAt(x, y, E, 'north')) cells.push([x, E]);
      const [y0, y1] = y === 0 ? [0.8125, 0.9375] : [y + 0.75, y + 1];
      course(K, cells, 'north', y0, y1, ledge, y === 0 ? 'smooth_stone' : 'stone_bricks');
    }
    const cap = sides('smooth_stone');
    for (const x of [-W - 1, W, chimney.x0 - 1, chimney.x1 + 1]) box(K, [x - 0.06, 3, E - 1.06], [x + 1.06, 3.5, E], cap);
    for (const x of [-W - 1, W]) if (grid.get(x, 0, E - 2)) box(K, [x - 0.04, 1, E - 2.04], [x + 1.04, 1.25, E - 1], cap);

    // Lanterns: hanging on chains, and on iron arms off the posts.
    for (const lamp of lamps) {
      const [x, y, z] = lamp.cell;
      if (lamp.hanging) {
        const o = [x + 0.5, y, z];
        lantern(mb, grid, atlas, o, true);
        chain(mb, grid, atlas, [o[0], y + 13 / 16, o[2]], lamp.top - (y + 13 / 16));
      } else {
        // An arm out of the post with a brace under it; the lantern hangs
        // from its end.
        const toWall = -lamp.side;
        const arm = sides('dark_oak_planks');
        addBox(mb, grid, atlas, [x, y, z], toWall > 0 ? [7, 14.5, 7.25] : [0, 14.5, 7.25], toWall > 0 ? [16, 16, 8.75] : [9, 16, 8.75], arm);
        addBox(mb, grid, atlas, [x, y, z], toWall > 0 ? [14.5, 9, 7.5] : [0, 9, 7.5], toWall > 0 ? [16, 14.5, 8.5] : [1.5, 14.5, 8.5], arm);
        lantern(mb, grid, atlas, [x + toWall * 0.3, y + 1.5 / 16, z], true);
      }
    }

    for (const fn of later) fn();

    const world = mb.geometry(T);
    const glassGeo = glass.geometry(T);

    return {
      grid, layout: L, cases, placeholder: cases.find(c => c.placeholder), lamps, fires, candles: K.candles,
      geometry: world, glass: glassGeo, colliders: K.colliders, clock: clockAt,
      // `top` is the leather inset the open book lies on, a quarter pixel up.
      desk: {z: deskZ, top: 1 + 0.25 / 16, center: [0, 1, deskO[2] + 0.5], chair: seats.find(s => s.desk)},
      fire: [0, 0.6, fz + 0.5],
      seats,
      door: {z: F, hinges: [[-1, 1], [1, -1]], height: 3},
      vault: vaultAt,
      mailbox: outside.mailbox,
      reviewDesk,
      stairs: hasStairs ? {...STAIR, flights} : null,
      trees: outside.trees,
      campfire: outside.campfire,
      market: outside.market,
      basement: cellar,
      // Plants loose on the grass, [x, z, texture, size], for the page to
      // draw round whatever furniture stands there.
      foliage: outside.foliage,
      // Floor that bought furniture may never be put on: the doorway, the
      // stair well and the way onto it, the hearth, the cellar hatch, the
      // review desk and the trader's plot.
      keepClear: [
        [-2, F - 2, 2, F + 2.5, 0],
        reviewDesk.clear,
        [-1.6, fz + 1, 1.6, fz + 2.3, 0],
        [BASEMENT.hatch[0], BASEMENT.hatch[1] - 0.5, BASEMENT.hatch[0] + 1.8, BASEMENT.hatch[1] + 1.5, 0],
        ...(hasStairs ? L.bases.map((_, f) => [STAIR.x0 - 0.5, STAIR.z0 - 0.5, STAIR.x0 + 3.5, STAIR.z0 + 4.5, f]) : []),
        ...(outside.market ? [[...outside.market.clear, 0]] : []),
      ],
      heightmap: heightmap(grid),
      smoke: [(chimney.x0 + chimney.x1 + 1) / 2, chimney.top + 0.1, (chimney.z0 + chimney.z1 + 1) / 2],
      // The hall itself, for the dust and the light shafts; the shadows
      // cover the whole island.
      bounds: {min: [-W - 1, -1, E], max: [W + 1, TOP + 2, F + 1]},
      hall: {x0: -W, x1: W, z0: E + 1, z1: F},
      shadowBounds: {min: [isle.x0 + 2, -4, isle.z0 + 2], max: [isle.x1 - 2, chimney.top + 1, isle.z1 - 2]},
    };
  }

  // ── The basement ───────────────────────────────────────────────────────
  // Finished like the rooms upstairs: limewashed walls over a dark oak
  // skirting, the timber frame showing, plank floors. Under the foyer a
  // snug little hall at the foot of the ladder from the hatch, with a rug,
  // a reading chair under a lamp, shelves and the autumn's pumpkins; behind
  // a door in its back wall the classroom: a blackboard, the teacher's desk
  // and three rows of school desks facing it.
  function basement(K, {light, solidBox, lamps, later}) {
    const {grid} = K, Fu = window.LibraryFurniture;
    const {base: y0, x0, x1, front, divide, back, hatch: [hx, hz]} = BASEMENT;
    const top = -2, floor = -1;
    const box2 = (ax, az, bx, bz) => solidBox(ax, az, bx, bz, floor);

    // The shell, stone out of sight in the island, hollowed out; the hall's
    // floor above is its ceiling.
    grid.fill([x0 - 1, y0 - 1, back - 1], [x1 + 1, top, front + 1], B.stone_bricks);
    grid.fill([x0, y0, back], [x1, top, front], AIR);
    grid.fill([x0, y0 - 1, back], [x1, y0 - 1, divide - 1], B.oak_planks);
    grid.fill([x0, y0 - 1, divide + 1], [x1, y0 - 1, front], B.spruce_planks);
    for (const x of [-1, 0]) grid.set(x, y0 - 1, divide, B.dark_oak_planks);
    // Every wall, the one between the rooms too, limewashed over a skirting.
    for (let y = y0; y <= top; y++) {
      const b = y === y0 ? B.dark_oak_planks : B.plaster;
      for (let z = back; z <= front; z++) { grid.set(x0 - 1, y, z, b); grid.set(x1 + 1, y, z, b); }
      for (let x = x0 - 1; x <= x1 + 1; x++) { grid.set(x, y, back - 1, b); grid.set(x, y, front + 1, b); grid.set(x, y, divide, b); }
    }
    // The doorway between, framed in dark oak.
    for (const x of [-1, 0]) for (let y = y0; y < y0 + 3; y++) grid.set(x, y, divide, AIR);
    for (const x of [-2, 1]) for (let y = y0; y < y0 + 3; y++) grid.set(x, y, divide, B.post);
    for (let x = -2; x <= 1; x++) grid.set(x, y0 + 3, divide, B.beam_x);
    // Beams across under the floor boards, each on a post in either wall,
    // and posts in the corners: the house's own frame carried down.
    for (const z of [1, back + 3, back + 8]) {
      for (let x = x0; x <= x1; x++) grid.set(x, top, z, B.beam_x);
      for (const x of [x0 - 1, x1 + 1]) for (let y = y0; y <= top; y++) grid.set(x, y, z, B.post);
    }
    for (const x of [x0 - 1, x1 + 1]) for (const z of [back - 1, divide, front + 1]) for (let y = y0; y <= top; y++) grid.set(x, y, z, B.post);
    // The hatch: a hole in the foyer floor, the ladder against the wall.
    grid.set(hx, -1, hz, AIR);
    box2(hx, hz, hx + 0.3, hz + 1);
    later.push(() => {
      Fu.wallLadder(K, hx, hz, y0, 0);
      Fu.hatch(K, hx, 0, hz);
    });

    // The little hall. Bookshelves against the wall east of the door, a
    // potted azalea and a pumpkin west of it.
    for (let x = 2; x <= x1; x++) for (let y = y0; y < y0 + 2; y++) grid.set(x, y, divide + 1, B.bookshelf);
    grid.set(x0 + 1, y0, divide + 1, B.pumpkin);
    box2(x0 + 2.2, divide + 1.2, x0 + 2.8, divide + 1.8);
    // A reading corner: an armchair turned to the room, a lamp and a table.
    const chairYaw = -Math.PI / 2;
    box2(x1 - 1.05, 3.05, x1 + 0.05, 3.95);
    box2(x1 - 0.8, 1.9, x1 - 0.2, 2.5);
    box2(x1 - 0.75, 4.3, x1 - 0.1, 5.05);
    light(x1 - 0.5, y0 + 1.5, 2.2, 14);
    // Barrels and the harvest along the front wall.
    const barrels = [[-3, front], [-2, front]];
    for (const [x, z] of barrels) box2(x + 0.1, z + 0.1, x + 0.9, z + 0.9);
    for (const x of [-4, 0]) grid.set(x, y0, front, B.pumpkin);
    later.push(() => {
      Fu.rug(K, -3, 1, 2, 5, 'rust', y0);
      Fu.pot(K, [x0 + 2, y0, divide + 1], 'azalea', true);
      Fu.armchair(K, [x1 - 1, y0, 3], chairYaw, 'green_wool');
      Fu.throwBlanket(K, [x1 - 1, y0, 3], chairYaw, 'red');
      Fu.floorLamp(K, [x1 - 1, y0, 1.7]);
      Fu.sideTable(K, [x1 - 1, y0, 4.2], 'tea');
      for (const [x, z] of barrels) Fu.barrel(K, [x, y0, z]);
      Fu.barrel(K, [-3, y0 + 14 / 16, front]);
      Fu.bookStack(K, [-2, y0 + 14 / 16, front], 3, 'cellar', 0.5);
      // A landscape over the barrels, framed like the one over the hearth.
      const wall = front + 1, py = y0 + 1.5;
      box(K, [0, py, wall - 0.04], [1, py + 1, wall], {north: {tex: 'painting_left', uv: [0, 0, 16, 16]}});
      box(K, [-1, py, wall - 0.04], [0, py + 1, wall], {north: {tex: 'painting_right', uv: [0, 0, 16, 16]}});
      const fr = sides('dark_oak_planks');
      box(K, [-1.1, py - 0.1, wall - 0.1], [1.1, py, wall], fr);
      box(K, [-1.1, py + 1, wall - 0.1], [1.1, py + 1.1, wall], fr);
      box(K, [-1.1, py, wall - 0.1], [-1, py + 1, wall], fr);
      box(K, [1, py, wall - 0.1], [1.1, py + 1, wall], fr);
    });
    const hang = (cx, cz, y = y0 + 2.9) => {
      lamps.push({cell: [cx - 1, y, cz - 0.5], hanging: true, top: -1});
      light(cx, y, cz, 15);
    };
    hang(0.5, 2.5);
    hang(-2.5, 4.5);
    light(-0.5, y0 + 1, divide + 1, 12);

    // The classroom.
    const zb = back, BOARD = {x0: -3, x1: 3, y0: y0 + 1.15, y1: y0 + 2.95, z: zb};
    later.push(() => Fu.blackboard(K, BOARD.x0, BOARD.x1, BOARD.y0, BOARD.y1, BOARD.z));
    // The teacher's desk in front of it, a stool behind, a globe and books.
    box2(-1.06, zb + 1, 1.06, zb + 2.06);
    box2(-0.4, zb + 0.15, 0.4, zb + 0.9);
    box2(x1 - 0.75, zb + 0.25, x1 - 0.25, zb + 0.75);
    later.push(() => {
      Fu.desk(K, [-1, y0, zb + 1]);
      Fu.stool(K, [-0.5, y0, zb + 0.1]);
      Fu.globe(K, [x1 - 1, y0, zb]);
    });
    for (const x of [x0, x1]) for (let z = zb; z < zb + 2; z++) for (let y = y0; y < y0 + 2; y++) grid.set(x, y, z, B.bookshelf);
    // Plants by the door.
    for (const [x, kind] of [[x0, 'azalea'], [x1, 'fern']]) {
      box2(x + 0.2, divide - 0.8, x + 0.8, divide - 0.2);
      later.push(() => Fu.pot(K, [x, y0, divide - 1], kind, true));
    }
    // Two blocks of two-seat desks either side of the aisle, three rows
    // deep, each place with its chair: sitting at one starts a lesson.
    const desks = [];
    for (const zf of [zb + 3.5, zb + 6, zb + 8.5]) {
      for (const dx of [x0 + 1, 1]) {
        box2(dx, zf, dx + 2, zf + 0.75);
        later.push(() => Fu.schoolDesk(K, [dx, y0, zf], dx * 7 + zf));
        for (const cx of [dx + 0.5, dx + 1.5]) {
          const cz = zf + 1.05;
          box2(cx - 0.34, cz - 0.34, cx + 0.34, cz + 0.42);
          later.push(() => Fu.schoolChair(K, [cx, y0, cz]));
          desks.push({pos: [cx, y0 + Fu.SCHOOL_SEAT, cz - 0.04], yaw: 0, pitch: 0.08, box: [[cx - 0.42, y0, cz - 0.42], [cx + 0.42, y0 + 1.15, cz + 0.42]]});
        }
      }
    }
    for (const [cx, cz] of [[-2.5, zb + 5.5], [2.5, zb + 5.5], [-2.5, zb + 10], [2.5, zb + 10], [0.5, zb + 1.5]]) hang(cx, cz);

    return {
      base: y0, floor,
      // Click boxes for the way down (from the foyer) and up (from the
      // cellar), and where the climber stands at the top and the bottom.
      hatch: {
        down: [[hx, -0.2, hz], [hx + 1, 0.35, hz + 1]],
        up: [[hx, y0, hz], [hx + 0.45, y0 + 2.4, hz + 1]],
        top: [hx + 1.35, hz + 0.5], bottom: [hx + 1.3, hz + 0.5],
        ladder: [hx + 0.38, hz + 0.5],
      },
      door: {z: divide, hinges: [[-1, 1], [1, -1]], height: 3, base: y0},
      board: BOARD,
      desks,
      cellar: {x0, z0: divide + 1, x1: x1 + 1, z1: front + 1},
      classroom: {x0, z0: back, x1: x1 + 1, z1: divide},
    };
  }

  // The highest block in each column, for keeping rain off whatever has a
  // roof over it. Stored as y + 64 per byte; 0 means open sky all the way.
  function heightmap(grid) {
    const data = new Uint8Array(grid.sx * grid.sz * 4);
    for (let z = grid.min[2]; z < grid.max[2]; z++) for (let x = grid.min[0]; x < grid.max[0]; x++) {
      let top = 0;
      for (let y = grid.max[1] - 1; y >= grid.min[1]; y--) {
        if (grid.get(x, y, z)) { top = Math.max(1, Math.min(255, y + 1 + 64)); break; }
      }
      const i = ((z - grid.min[2]) * grid.sx + (x - grid.min[0])) * 4;
      data[i] = top; data[i + 3] = 255;
    }
    return {data, x0: grid.min[0], z0: grid.min[2], sx: grid.sx, sz: grid.sz, at(x, z) {
      const gx = Math.floor(x) - grid.min[0], gz = Math.floor(z) - grid.min[2];
      if (gx < 0 || gz < 0 || gx >= grid.sx || gz >= grid.sz) return -100;
      const v = data[(gz * grid.sx + gx) * 4];
      return v ? v - 64 : -100;
    }};
  }

  // Painted shutters either side of each run of windows, on the outside.
  function shutters(K, windows, top) {
    const key = w => `${w.axis}|${w.axis === 'x' ? w.cell[0] : w.cell[2]}|${w.cell[1]}`;
    const runs = new Map();
    for (const w of windows) {
      if (w.cell[1] > top) continue;
      const k = key(w);
      if (!runs.has(k)) runs.set(k, []);
      runs.get(k).push(w);
    }
    const paint = {tex: 'spruce_planks', tint: [0.2, 0.32, 0.22], rot: 90};
    const face = sides('spruce_planks', null, null, {tint: [0.2, 0.32, 0.22]});
    // Thick enough to stand clear of the timber relief, and a hair short of
    // the post's edge so their sides never share a plane.
    const t = RELIEF + 1.5 / 16;
    for (const list of runs.values()) {
      const along = list[0].axis === 'x' ? 2 : 0;
      const cells = list.map(w => w.cell[along]).sort((a, b) => a - b);
      const w0 = list[0];
      const [x, y, z] = w0.cell;
      const out = w0.axis === 'x' ? (x < 0 ? -1 : 1) : -w0.inward;
      const plane = w0.axis === 'x' ? (out < 0 ? x : x + 1) : (out < 0 ? z : z + 1);
      // Split into unbroken runs; each gets a shutter at both ends.
      let start = cells[0];
      for (let i = 1; i <= cells.length; i++) {
        if (i < cells.length && cells[i] === cells[i - 1] + 1) continue;
        const end = cells[i - 1] + 1;
        for (const [a0, a1] of [[start - 0.46, start - 0.01], [end + 0.01, end + 0.46]]) {
          const lo = Math.min(plane, plane + out * t), hi = Math.max(plane, plane + out * t);
          const a = along === 2 ? [lo, y + 0.03, a0] : [a0, y + 0.03, lo];
          const b = along === 2 ? [hi, y + 0.97, a1] : [a1, y + 0.97, hi];
          const n = along === 2 ? [out, 0, 0] : [0, 0, out];
          // The back lies on the wall; leaving it out avoids z-fighting.
          box(K, a, b, {...face, [dirOf(n)]: paint, [dirOf(n.map(v => -v))]: null}, {whole: true});
        }
        if (i < cells.length) start = cells[i];
      }
    }
  }

  // How far the outside timber frame stands proud of the plaster.
  const RELIEF = 1.5 / 16;

  // Each timber cell in `cells` ([x, y, z, outward faces]) gets a slab on
  // every outward face that is open to the air. A corner's first slab wraps
  // round it so the two never overlap; slabs of a run join seamlessly.
  function timberRelief(K, cells, depth) {
    const {grid} = K;
    const exposed = (x, y, z, d) => { const [nx, ny, nz] = FACES[d].n; return !grid.solid(x + nx, y + ny, z + nz); };
    for (const [x, y, z, dirs] of cells) {
      const b = grid.get(x, y, z);
      if (!isTimber(b)) continue;
      const outs = dirs.filter(d => exposed(x, y, z, d));
      for (const d of outs) {
        const [k, s] = AXIS[d];
        const a = [x, y, z], c = [x + 1, y + 1, z + 1];
        if (s > 0) { a[k] = c[k]; c[k] += depth; } else { c[k] = a[k]; a[k] -= depth; }
        if (d === outs[0]) for (const e of outs.slice(1)) { const [ke, se] = AXIS[e]; if (se > 0) c[ke] += depth; else a[ke] -= depth; }
        const faces = {};
        for (const f of DIRS) {
          const [kf, sf] = AXIS[f];
          if (kf === k && sf !== s) continue;
          if (kf !== k && !outs.includes(f)) {
            const [nx, ny, nz] = FACES[f].n;
            if (isTimber(grid.get(x + nx, y + ny, z + nz)) && exposed(x + nx, y + ny, z + nz, d)) continue;
          }
          faces[f] = {tex: faceTexture(b, f), rot: b.rotFaces && b.rotFaces.includes(f) ? 90 : 0};
        }
        box(K, a, c, faces, {whole: true});
      }
    }
  }

  // A timber brace laid on a wall, rising from (a0, y0) to (a1, y1): `along`
  // is the axis it runs on (0 for x, 2 for z), `plane` the wall's face and
  // `out` the way that faces. Its ends are cut level to sit on the rail and
  // under the beam, `width` along the wall, standing `depth` proud.
  function brace(K, along, plane, out, a0, y0, a1, y1, width, depth) {
    const s = Math.sign(a1 - a0), across = along === 0 ? 2 : 0;
    const at = ([a, y], d) => { const p = [0, y, 0]; p[along] = a; p[across] = plane + out * d; return p; };
    const P = [[a0, y0], [a0 + s * width, y0], [a1, y1], [a1 - s * width, y1]];
    const mid = [(a0 + a1) / 2, (y0 + y1) / 2];
    const len = Math.hypot(a1 - a0, y1 - y0) * 16, D = depth * 16;
    const face = (pts, n, uvs) => {
      const e1 = pts[1].map((v, k) => v - pts[0][k]), e2 = pts[2].map((v, k) => v - pts[0][k]);
      const c = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]];
      if (c[0] * n[0] + c[1] * n[1] + c[2] * n[2] < 0) { pts = [...pts].reverse(); uvs = [...uvs].reverse(); }
      const lights = pts.map(p => K.grid.sample([p[0] + n[0] * 0.3, p[1] + n[1] * 0.3, p[2] + n[2] * 0.3], n));
      K.mb.quad(pts, n, uvs, tileOf(K.atlas, 'dark_oak_log'), lights, [1, 1, 1, 1]);
    };
    const normal = (na, ny) => { const n = [0, ny, 0]; n[along] = na; return n; };
    const front = [0, 0, 0]; front[across] = out;
    face(P.map(q => at(q, depth)), front, [[5, len], [10, len], [10, 0], [5, 0]]);
    // The two long sides, each facing away from the brace's middle.
    for (const [i, j] of [[1, 2], [3, 0]]) {
      const da = P[j][0] - P[i][0], dy = P[j][1] - P[i][1], l = Math.hypot(da, dy);
      let na = dy / l, ny = -da / l;
      if (na * ((P[i][0] + P[j][0]) / 2 - mid[0]) + ny * ((P[i][1] + P[j][1]) / 2 - mid[1]) < 0) { na = -na; ny = -ny; }
      face([at(P[i], 0), at(P[j], 0), at(P[j], depth), at(P[i], depth)], normal(na, ny), [[0, len], [0, 0], [D, 0], [D, len]]);
    }
    face([at(P[3], 0), at(P[2], 0), at(P[2], depth), at(P[3], depth)], [0, 1, 0], [[0, 0], [5, 0], [5, D], [0, D]]);
    face([at(P[0], 0), at(P[1], 0), at(P[1], depth), at(P[0], depth)], [0, -1, 0], [[0, 0], [5, 0], [5, D], [0, D]]);
  }

  // A course of stone standing proud of a wall along `cells` ([x, z], one
  // wall facing `dir`), from y0 to y1; ends are dressed where a run stops.
  function course(K, cells, dir, y0, y1, depth, tex) {
    const has = new Set(cells.map(c => c.join()));
    const [k, s] = AXIS[dir], along = k === 0 ? 2 : 0;
    const face = {tex};
    for (const [x, z] of cells) {
      const a = [x, y0, z], c = [x + 1, y1, z + 1];
      if (s > 0) { a[k] = c[k]; c[k] += depth; } else { c[k] = a[k]; a[k] -= depth; }
      const faces = {[dir]: face, up: face, down: face};
      for (const e of DIRS) {
        const [ke, se] = AXIS[e];
        if (ke !== along) continue;
        if (!has.has((along === 0 ? [x + se, z] : [x, z + se]).join())) faces[e] = face;
      }
      box(K, a, c, faces, {whole: true});
    }
  }

  // A planter of ferns and flowers under each run of ground-floor windows
  // in the side walls, on the outside.
  function planters(K, windows) {
    const rows = new Map();
    for (const w of windows) {
      if (w.axis !== 'x' || w.cell[1] !== 1) continue;
      const k = w.cell[0];
      if (!rows.has(k)) rows.set(k, []);
      rows.get(k).push(w.cell[2]);
    }
    for (const [x, zs] of rows) {
      zs.sort((a, b) => a - b);
      const out = x < 0 ? -1 : 1;
      let start = zs[0];
      for (let i = 1; i <= zs.length; i++) {
        if (i < zs.length && zs[i] === zs[i - 1] + 1) continue;
        const end = zs[i - 1] + 1;
        const plane = out < 0 ? x : x + 1;
        const f = out > 0 ? frame([plane, 0, end], [0, 0, -1], [1, 0, 0]) : frame([plane, 0, start], [0, 0, 1], [-1, 0, 0]);
        window.LibraryFurniture.planter(K, f, 0, end - start);
        if (i < zs.length) start = zs[i];
      }
    }
  }

  // Still water: a surface two pixels under the block top, with sides only
  // where the water meets air.
  function addWater(mb, grid, atlas, x, y, z) {
    // Grey like the game's sheet, coloured here as the biome does; tints
    // multiply linear light, so this is the sRGB blue converted.
    const tint = srgb([0.4, 0.58, 0.86]);
    const open = (dx, dy, dz) => { const n = grid.get(x + dx, y + dy, z + dz); return !n || (!n.opaque && n !== B.water); };
    const faces = {};
    if (open(0, 1, 0)) faces.up = {tex: 'water', uv: [0, 0, 16, 16], tint};
    for (const [dir, d] of [['north', [0, 0, -1]], ['south', [0, 0, 1]], ['west', [-1, 0, 0]], ['east', [1, 0, 0]]]) {
      if (open(...d)) faces[dir] = {tex: 'water', tint};
    }
    addBox(mb, grid, atlas, [x, y, z], [0, 0, 0], [16, 14, 16], faces, {ao: 1});
  }

  // ── The island ─────────────────────────────────────────────────────────
  // An oval of land a little longer than the hall, its outline rippled so
  // it reads as rock rather than a drawn shape. The front yard is deeper
  // than the back, for the path out to the lookout.
  function islandShape(E, F) {
    const cz = (E + F) / 2 + 4;
    const rx = 17, rz = (F - E) / 2 + 13;
    const r = LibraryTextures.rng('island');
    const ph = [r() * 6.28, r() * 6.28, r() * 6.28];
    // How far out a cell's centre lies: land below 1.
    const edge = (x, z) => {
      const dx = (x + 0.5) / rx, dz = (z + 0.5 - cz) / rz;
      const a = Math.atan2(dz, dx);
      const wobble = 1 + 0.07 * Math.sin(a * 3 + ph[0]) + 0.05 * Math.sin(a * 5 + ph[1]) + 0.03 * Math.sin(a * 8 + ph[2]);
      return Math.hypot(dx, dz) / wobble;
    };
    return {
      cz, rx, rz, edge,
      x0: -Math.ceil(rx * 1.15) - 2, x1: Math.ceil(rx * 1.15) + 2,
      z0: Math.floor(cz - rz * 1.15) - 2, z1: Math.ceil(cz + rz * 1.15) + 2,
    };
  }

  const cellHash = (x, y, z) => hash(((x * 73856093) ^ (y * 19349663) ^ (z * 83492791)) >>> 0);

  // Grass on top, a few layers of dirt, then stone narrowing to a ragged
  // point underneath, deepest in the middle. Returns each column's bottom.
  function island(grid, isle) {
    const bottoms = new Map();
    for (let x = isle.x0; x < isle.x1; x++) for (let z = isle.z0; z < isle.z1; z++) {
      const e = isle.edge(x, z);
      if (e >= 1) continue;
      const n = cellHash(x, 0, z);
      const spike = cellHash(x, 1, z) < 0.1 ? 2 + Math.floor(cellHash(x, 2, z) * 4) : 0;
      const depth = 3 + Math.round((1 - e * e) * 17 * (0.85 + n * 0.3)) + spike;
      const bottom = -1 - depth;
      bottoms.set(x + ',' + z, bottom);
      for (let y = bottom; y <= -1; y++) {
        let b;
        if (y === -1) b = B.grass;
        else if (y >= -3 - (n < 0.3 ? 1 : 0)) b = e > 0.88 && n < 0.45 ? B.coarse_dirt : B.dirt;
        else {
          const h = cellHash(x, y, z);
          b = h < 0.035 ? B.coal_ore : Math.sin(x * 0.45 + y * 0.7) + Math.cos(z * 0.5 - y * 0.35) > 1.25 ? B.andesite : B.stone;
        }
        grid.set(x, y, z, b);
      }
    }
    return {bottoms};
  }

  // A path block: a pixel lower than the grass beside it, as in the game.
  function addPath(mb, grid, atlas, x, y, z) {
    const open = (dx, dy, dz) => { const n = grid.get(x + dx, y + dy, z + dz); return !n || !n.opaque; };
    const side = {tex: 'dirt_path_side', uv: [0, 1, 16, 16]};
    const faces = {up: {tex: 'dirt_path_top', uv: [0, 0, 16, 16]}};
    if (open(0, 0, -1)) faces.north = side;
    if (open(0, 0, 1)) faces.south = side;
    if (open(-1, 0, 0)) faces.west = side;
    if (open(1, 0, 0)) faces.east = side;
    if (open(0, -1, 0)) faces.down = {tex: 'dirt'};
    addBox(mb, grid, atlas, [x, y, z], [0, 0, 0], [16, 15, 16], faces);
  }

  // A roof stair climbing toward +x (rise 1) or -x (rise -1): a slab with
  // a step on its high side. Faces against solid blocks or the same stair
  // running on are left out.
  function addStair(mb, grid, atlas, x, y, z, b) {
    const up = b.rise > 0;
    const open = (dx, dy, dz) => {
      const n = grid.get(x + dx, y + dy, z + dz);
      return !n || (!n.opaque || n.custom) && n !== b;
    };
    const wood = {tex: 'dark_oak_planks'};
    const lowSide = up ? 'west' : 'east', highSide = up ? 'east' : 'west';
    const lo = up ? [0, 8] : [8, 16], hi = up ? [8, 16] : [0, 8];
    const ends = {};
    if (open(0, 0, -1)) ends.north = wood;
    if (open(0, 0, 1)) ends.south = wood;
    const low = {...ends, up: wood};
    if (open(up ? -1 : 1, 0, 0)) low[lowSide] = wood;
    if (open(0, -1, 0)) low.down = wood;
    addBox(mb, grid, atlas, [x, y, z], [lo[0], 0, 0], [lo[1], 8, 16], low);
    const foot = {...ends};
    if (open(0, -1, 0)) foot.down = wood;
    if (open(up ? 1 : -1, 0, 0)) foot[highSide] = wood;
    addBox(mb, grid, atlas, [x, y, z], [hi[0], 0, 0], [hi[1], 8, 16], foot);
    const step = {...ends, [lowSide]: wood};
    if (open(0, 1, 0)) step.up = wood;
    if (open(up ? 1 : -1, 0, 0)) step[highSide] = wood;
    addBox(mb, grid, atlas, [x, y, z], [hi[0], 8, 0], [hi[1], 16, 16], step);
  }

  // A tree of the season at (x, z): an oak in orange or red, a yellow birch
  // or a dark spruce. Leaves only fill air, so trees never cut into things.
  function tree(grid, x, z, kind, r, base = 0) {
    const put = (px, py, pz, blk) => { if (!grid.get(px, py + base, pz)) grid.set(px, py + base, pz, blk); };
    const log = (py, blk) => grid.set(x, py + base, z, blk);
    if (kind === 'spruce') {
      const t = 6 + Math.floor(r() * 2);
      for (let y = 0; y < t; y++) log(y, B.spruce_log);
      for (let y = 2; y <= t; y++) {
        const rad = y >= t - 1 ? 1 : (t - y) % 2 === 0 ? 1 : 2;
        for (let dx = -rad; dx <= rad; dx++) for (let dz = -rad; dz <= rad; dz++) {
          if (Math.abs(dx) + Math.abs(dz) > rad + (rad > 1 ? 1 : 0)) continue;
          put(x + dx, y, z + dz, B.leaves_spruce);
        }
      }
      put(x, t + 1, z, B.leaves_spruce);
      return {top: t + 1, spread: 2};
    }
    const birch = kind === 'yellow';
    // Some oaks grow big and round: a wider, taller crown.
    const big = !birch && r() < 0.4;
    const t = (birch ? 5 : big ? 5 : 4) + Math.floor(r() * 2);
    const leaves = B['leaves_' + kind];
    for (let y = 0; y < t; y++) log(y, birch ? B.birch_log : B.oak_log);
    // Big crowns are rounded: narrow at the bottom and top, widest in the
    // middle, each layer a disc rather than a square.
    const bigRad = [2, 3, 3, 2, 1];
    for (let y = t - (big ? 4 : 3); y <= t; y++) {
      const rad = big ? bigRad[y - (t - 4)] : y >= t - 1 ? 1 : 2;
      for (let dx = -rad; dx <= rad; dx++) for (let dz = -rad; dz <= rad; dz++) {
        if (big && dx * dx + dz * dz > rad * rad + (rad > 2 ? 0 : 1)) continue;
        const corner = Math.abs(dx) === rad && Math.abs(dz) === rad;
        if (corner && (y === t || r() < 0.55)) continue;
        put(x + dx, y, z + dz, leaves);
      }
    }
    if (big) put(x, t + 1, z, leaves);
    return {top: t, spread: big ? 3 : 2};
  }

  function outdoors(K, isle, ground, h) {
    const {grid} = K;
    const {W, F, light, solidBox, later, seats} = h;
    const Fu = window.LibraryFurniture;
    const r = LibraryTextures.rng('outdoors');
    const key = (x, z) => x + ',' + z;
    const taken = new Set();
    const take = (x0, z0, x1, z1) => { for (let x = x0; x <= x1; x++) for (let z = z0; z <= z1; z++) taken.add(key(x, z)); };
    const isLand = (x, z) => grid.solid(x, -1, z);
    // Land with at least `m` blocks of it all round.
    const inland = (x, z, m) => {
      for (let dx = -m; dx <= m; dx++) for (let dz = -m; dz <= m; dz++) if (!isLand(x + dx, z + dz)) return false;
      return true;
    };
    const free = (x, z) => isLand(x, z) && !taken.has(key(x, z)) && !grid.get(x, 0, z);
    take(-W - 4, h.E - 4, W + 3, F + 3);

    // The lookout: a spruce deck at the front edge, railed, with a bench
    // facing out over the drop and a lantern at each front corner.
    let zEdge = F + 4;
    while (isLand(0, zEdge + 1) && isLand(-3, zEdge + 1) && isLand(2, zEdge + 1)) zEdge++;
    const deck = {x0: -3, x1: 2, z0: zEdge - 3, z1: zEdge};
    for (let x = deck.x0; x <= deck.x1; x++) for (let z = deck.z0; z <= deck.z1; z++) grid.set(x, -1, z, B.spruce_planks);
    take(deck.x0 - 1, deck.z0 - 1, deck.x1 + 1, deck.z1 + 1);
    const rail = [];
    for (let z = deck.z0 + 1; z <= deck.z1; z++) rail.push([deck.x0, z]);
    for (let x = deck.x0 + 1; x < deck.x1; x++) rail.push([x, deck.z1]);
    for (let z = deck.z1; z > deck.z0; z--) rail.push([deck.x1, z]);
    for (const [x, z] of rail) solidBox(x + 0.3, z + 0.3, x + 0.7, z + 0.7);
    for (let i = 1; i < rail.length; i++) {
      const [ax, az] = rail[i - 1], [bx, bz] = rail[i];
      solidBox(Math.min(ax, bx) + 0.4, Math.min(az, bz) + 0.4, Math.max(ax, bx) + 0.6, Math.max(az, bz) + 0.6);
    }
    const benchZ = deck.z1 - 1;
    solidBox(-1, benchZ + 0.15, 1, benchZ + 0.85);
    seats.push({pos: [0, 0.5, benchZ + 0.42], yaw: Math.PI, box: [[-0.95, 0, benchZ + 0.12], [0.95, 1.15, benchZ + 0.88]], along: [-0.55, 0.55], alongX: true});
    for (const x of [deck.x0, deck.x1]) light(x, 1, deck.z1, 14);
    later.push(() => {
      Fu.fence(K, rail);
      Fu.bench(K, [-1, 0, benchZ], 2);
      for (const x of [deck.x0, deck.x1]) Fu.lantern(K, [x, 1, deck.z1]);
    });

    // The path from the door to the deck, worn a little wider here and
    // there, a mat at the door and a jack o'lantern either side of it.
    for (let z = F + 2; z < deck.z0; z++) {
      for (const x of [-1, 0]) grid.set(x, -1, z, B.path);
      if (cellHash(-2, 5, z) < 0.3) grid.set(-2, -1, z, B.path);
      if (cellHash(1, 5, z) < 0.3) grid.set(1, -1, z, B.path);
    }
    take(-3, F + 1, 2, deck.z0);
    grid.set(-2, 0, F + 1, B.jack_south);
    grid.set(1, 0, F + 1, B.jack_south);
    light(-2, 0, F + 1, 15); light(1, 0, F + 1, 15);
    for (const x of [-4, 2]) solidBox(x, F + 1, x + 2, F + 1.34);
    later.push(() => {
      Fu.rug(K, -1, F + 1, 1, F + 2, 'rust');
      Fu.wreath(K, [0, 4.45, F + 1]);
      for (const x of [-4, 2]) Fu.windowBox(K, x, x + 2, F + 1);
    });
    // Lamp posts down the path, alternating sides.
    for (let z = F + 5, i = 0; z < deck.z0 - 1; z += 5, i++) {
      const x = i % 2 ? 1.5 : -2.5;
      solidBox(x + 0.3, z + 0.3, x + 0.7, z + 0.7);
      light(x, 1, z, 14);
      later.push(() => Fu.lampPost(K, [x, 0, z]));
    }

    // The mailbox, beside the path a few steps out from the door.
    const mailCell = [2, 0, F + 3];
    const mailbox = {
      cell: mailCell,
      flag: Fu.MAIL_FLAG.map((v, k) => mailCell[k] + v),
      box: Fu.MAIL_BOX.map(p => p.map((v, k) => mailCell[k] + v)),
    };
    solidBox(mailCell[0] + 0.25, mailCell[2] + 0.3, mailCell[0] + 0.9, mailCell[2] + 0.7);
    later.push(() => Fu.mailbox(K, mailCell));

    // The wandering trader's stall, on the lawn right of the path past the
    // mailbox. It stands there whether he is in or not; he and his llamas
    // come and go.
    let market = null;
    const Goods = window.LibraryGoods;
    if (Goods) {
      const plot = [3, F + 3];
      const [pw, pd] = Goods.STALL.size;
      let room = true;
      // Inside the house's own margin, where nothing grows; it only needs
      // land with nothing on it.
      for (let x = plot[0]; x <= plot[0] + pw && room; x++) for (let z = plot[1] - 1; z < plot[1] + pd; z++) if (!inland(x, z, 0) || grid.get(x, 0, z) || grid.get(x, -1, z) === B.path) { room = false; break; }
      if (room) {
        take(plot[0], plot[1] - 1, plot[0] + pw, plot[1] + pd - 1);
        const st = Goods.stallSolids(plot);
        for (const [x0, z0, x1, z1] of st.colliders) solidBox(x0, z0, x1, z1);
        light(...st.lamp, 14);
        later.push(() => Goods.stall(K, plot));
        market = {plot, clear: [plot[0], plot[1] - 1, plot[0] + pw + 1, plot[1] + pd]};
      }
    }

    // A pumpkin patch in the front yard with hay bales beside it.
    const patch = {x0: -W - 8, x1: -W - 3, z0: F + 3, z1: F + 8};
    for (let x = patch.x0; x <= patch.x1; x++) for (let z = patch.z0; z <= patch.z1; z++) {
      if (!inland(x, z, 1)) continue;
      grid.set(x, -1, z, B.coarse_dirt);
      const roll = cellHash(x, 7, z);
      if (roll < 0.3) grid.set(x, 0, z, B.pumpkin);
      else if (roll < 0.36) grid.set(x, 0, z, B['carved_' + ['north', 'south', 'east', 'west'][Math.floor(roll * 100) % 4]]);
    }
    take(patch.x0 - 1, patch.z0 - 1, patch.x1 + 1, patch.z1 + 1);
    for (const [x, y, z] of [[patch.x1 + 2, 0, patch.z0], [patch.x1 + 2, 0, patch.z0 + 1], [patch.x1 + 2, 1, patch.z0]]) {
      if (isLand(x, z)) grid.set(x, y, z, B.hay);
    }
    take(patch.x1 + 2, patch.z0, patch.x1 + 3, patch.z0 + 1);

    // A woodpile against the stone end wall, beside the chimney.
    for (let x = 2; x <= 4; x++) for (const y of [0, 1]) grid.set(x, y, h.E - 1, B.spruce_log_x);
    grid.set(3, 2, h.E - 1, B.spruce_log_x);

    // A scarecrow keeping watch over the pumpkins.
    const crow = [patch.x0 + 2, patch.z0 + 3];
    if (isLand(...crow)) {
      grid.set(crow[0], 0, crow[1], AIR);
      solidBox(crow[0] + 0.35, crow[1] + 0.35, crow[0] + 0.65, crow[1] + 0.65);
      later.push(() => Fu.scarecrow(K, [crow[0], 0, crow[1]]));
    }

    // ── Things about the island ─────────────────────────────────────────
    // Somewhere free for a feature `w` × `d` cells with `margin` of open
    // land round it.
    const findSpot = (w, d, margin, tries = 400) => {
      for (let i = 0; i < tries; i++) {
        const x = isle.x0 + Math.floor(r() * (isle.x1 - isle.x0 - w));
        const z = isle.z0 + Math.floor(r() * (isle.z1 - isle.z0 - d));
        let ok = true;
        for (let dx = -margin; dx < w + margin && ok; dx++) for (let dz = -margin; dz < d + margin; dz++) {
          const cx = x + dx, cz = z + dz;
          if (!inland(cx, cz, 1) || taken.has(key(cx, cz)) || grid.get(cx, 0, cz)) { ok = false; break; }
        }
        if (ok) return [x, z];
      }
      return null;
    };

    // A pond with lily pads and reeds round its edge.
    const pond = findSpot(7, 6, 2);
    if (pond) {
      const [px, pz] = pond;
      const cx = px + 3.5, cz = pz + 3;
      for (let x = px; x < px + 7; x++) for (let z = pz; z < pz + 6; z++) {
        const e = ((x + 0.5 - cx) / 3.4) ** 2 + ((z + 0.5 - cz) / 2.9) ** 2;
        if (e < 1 - cellHash(x, 80, z) * 0.3) grid.set(x, -1, z, B.water);
      }
      take(px - 1, pz - 1, px + 7, pz + 6);
      later.push(() => {
        for (let x = px - 1; x <= px + 7; x++) for (let z = pz - 1; z <= pz + 6; z++) {
          const h = cellHash(x, 81, z);
          if (grid.get(x, -1, z) === B.water) {
            if (h < 0.16) addBox(K.mb, grid, K.atlas, [x, -1, z], [0, 14.3, 0], [16, 14.3, 16], {up: {tex: 'lily_pad', uv: [0, 0, 16, 16], rot: Math.floor(h * 400) % 4 * 90, double: true}}, {ao: 1});
            continue;
          }
          const shore = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dz]) => grid.get(x + dx, -1, z + dz) === B.water);
          if (!shore || !isLand(x, z) || grid.get(x, 0, z) || h > 0.4) continue;
          cross(K.mb, grid, K.atlas, [x, 0, z], 'sugar_cane', 1, 0);
          if (h < 0.2) cross(K.mb, grid, K.atlas, [x, 1, z], 'sugar_cane', 1, 0);
        }
      });
    }

    // An old well: a cobbled ring round a shaft of water under a little
    // roof, with a bucket on a rope.
    const well = findSpot(3, 3, 1);
    if (well) {
      const [wx, wz] = well;
      for (let x = wx; x < wx + 3; x++) for (let z = wz; z < wz + 3; z++) {
        if (x === wx + 1 && z === wz + 1) { grid.set(x, -1, z, B.water); continue; }
        grid.set(x, 0, z, cellHash(x, 82, z) < 0.4 ? B.mossy_cobblestone : B.cobblestone);
      }
      take(wx - 1, wz - 1, wx + 3, wz + 3);
      solidBox(wx, wz, wx + 3, wz + 3);
      later.push(() => Fu.wellRoof(K, wx, wz));
    }

    // A fire ring out in the open with logs to sit on round it.
    let campfireAt = null;
    const ring = findSpot(5, 5, 1);
    if (ring) {
      const [rx, rz] = ring;
      const c = [rx + 2, rz + 2];
      for (let dx = -1; dx <= 1; dx++) for (let dz = -1; dz <= 1; dz++) grid.set(c[0] + dx, -1, c[1] + dz, B.path);
      take(rx, rz, rx + 4, rz + 4);
      solidBox(c[0] + 0.1, c[1] + 0.1, c[0] + 0.9, c[1] + 0.9);
      light(c[0], 0, c[1], 14);
      campfireAt = [c[0] + 0.5, 0.45, c[1] + 0.5];
      const logs = [[c[0] - 1, rz, 'x'], [c[0] - 1, rz + 4, 'x'], [rx, c[1] - 1, 'z']];
      for (const [lx, lz, axis] of logs) {
        const [x1, z1] = axis === 'x' ? [lx + 3, lz + 1] : [lx + 1, lz + 3];
        solidBox(lx + 0.15, lz + 0.15, x1 - 0.15, z1 - 0.15);
        const yaw = axis === 'x' ? (lz < c[1] ? Math.PI : 0) : Math.PI / 2;
        seats.push({pos: [(lx + x1) / 2, 0.55, (lz + z1) / 2], yaw, box: axis === 'x' ? [[lx, 0, lz + 0.2], [x1, 0.56, lz + 0.8]] : [[lx + 0.2, 0, lz], [lx + 0.8, 0.56, z1]], along: axis === 'x' ? [lx + 0.5, x1 - 0.5] : [lz + 0.5, z1 - 0.5], alongX: axis === 'x'});
      }
      later.push(() => {
        campfire(K.mb, grid, K.atlas, [c[0], 0, c[1]]);
        for (const [lx, lz, axis] of logs) Fu.logSeat(K, [lx, 0, lz], axis);
      });
    }

    // Trees, planted before the small scattered things so those fill in
    // round them: spaced out, never on the path or against the house. Only
    // the trunk and the cells beside it need to be free; the crowns may
    // lean over anything, since leaves only fill air.
    const trees = [];
    const kinds = ['orange', 'orange', 'red', 'yellow', 'yellow', 'amber', 'red', 'spruce', 'spruce'];
    for (let attempt = 0; attempt < 2400 && trees.length < 48; attempt++) {
      const x = isle.x0 + Math.floor(r() * (isle.x1 - isle.x0));
      const z = isle.z0 + Math.floor(r() * (isle.z1 - isle.z0));
      if (!inland(x, z, 1) || grid.get(x, 0, z)) continue;
      let clear = true;
      for (let dx = -1; dx <= 1 && clear; dx++) for (let dz = -1; dz <= 1; dz++) if (taken.has(key(x + dx, z + dz))) { clear = false; break; }
      if (!clear || trees.some(t => Math.hypot(t.x - x, t.z - z) < 3.6)) continue;
      const kind = kinds[Math.floor(r() * kinds.length)];
      const t = tree(grid, x, z, kind, r);
      trees.push({x, z, kind, ...t, tint: FOLIAGE[kind]});
      take(x - 1, z - 1, x + 1, z + 1);
    }

    // Boulders, a fallen log with mushrooms on it, and bushes turning with
    // the season.
    const stone = h => (h < 0.35 ? B.mossy_cobblestone : h < 0.7 ? B.cobblestone : B.andesite);
    for (let i = 0; i < 5; i++) {
      const at = findSpot(2, 2, 1);
      if (!at) break;
      const [bx, bz] = at;
      grid.set(bx, 0, bz, stone(cellHash(bx, 83, bz)));
      if (cellHash(bx, 84, bz) < 0.7) grid.set(bx + 1, 0, bz, stone(cellHash(bx + 1, 83, bz)));
      if (cellHash(bx, 85, bz) < 0.5) grid.set(bx, 0, bz + 1, stone(cellHash(bx, 83, bz + 1)));
      if (cellHash(bx, 86, bz) < 0.35) grid.set(bx, 1, bz, stone(cellHash(bx, 87, bz)));
      take(bx, bz, bx + 1, bz + 1);
    }
    const fallen = findSpot(3, 1, 1);
    if (fallen) {
      for (let i = 0; i < 3; i++) grid.set(fallen[0] + i, 0, fallen[1], B.spruce_log_x);
      take(fallen[0], fallen[1], fallen[0] + 2, fallen[1]);
      later.push(() => {
        cross(K.mb, grid, K.atlas, [fallen[0], 1, fallen[1]], 'brown_mushroom', 0.55, 0);
        cross(K.mb, grid, K.atlas, [fallen[0] + 2, 1, fallen[1]], 'red_mushroom', 0.5, 0);
      });
    }
    const bushes = ['leaves_amber', 'leaves_red', 'leaves_orange', 'leaves_amber', 'leaves_yellow', 'leaves_red'];
    for (const name of bushes) {
      const at = findSpot(1, 1, 1);
      if (!at) break;
      grid.set(at[0], 0, at[1], B[name]);
      if (cellHash(at[0], 88, at[1]) < 0.5) grid.set(at[0] + 1, 0, at[1], B[name]);
      take(at[0], at[1], at[0] + 1, at[1]);
    }

    // Patches of the last flowers, and berry bushes.
    const flowers = [];
    const kindsOfFlower = ['poppy', 'dandelion', 'cornflower', 'poppy', 'sweet_berry_bush', 'dandelion', 'sweet_berry_bush'];
    for (const kind of kindsOfFlower) {
      const at = findSpot(1, 1, 0);
      if (!at) break;
      const count = kind === 'sweet_berry_bush' ? 2 : 5;
      for (let i = 0; i < count * 3 && flowers.filter(f => f[3] === at).length < count; i++) {
        const x = at[0] + Math.floor(r() * 5) - 2, z = at[1] + Math.floor(r() * 5) - 2;
        if (!isLand(x, z) || taken.has(key(x, z)) || grid.get(x, 0, z) || grid.get(x, -1, z) !== B.grass) continue;
        if (flowers.some(f => f[0] === x && f[1] === z)) continue;
        flowers.push([x, z, kind, at]);
      }
    }
    for (const [x, z] of flowers) taken.add(key(x, z));
    // Flowers and the plants below stand loose on the grass: the page draws
    // them itself, so it can leave out any a piece of furniture stands on.
    const foliage = flowers.map(([x, z, kind]) => [x, z, kind, kind === 'sweet_berry_bush' ? 0.95 : 0.7]);

    // Fallen leaves under the trees and a scatter of them everywhere;
    // grass, ferns, mushrooms and the odd dead bush.
    const litter = [], plants = [];
    for (let x = isle.x0; x < isle.x1; x++) for (let z = isle.z0; z < isle.z1; z++) {
      if (!isLand(x, z) || grid.get(x, 0, z) || grid.get(x, -1, z) !== B.grass && grid.get(x, -1, z) !== B.coarse_dirt) continue;
      if (x >= -W - 1 && x <= W && z >= h.E && z <= F) continue;
      if (flowers.some(f => f[0] === x && f[1] === z)) continue;
      const near = trees.find(t => t.kind !== 'spruce' && Math.hypot(t.x - x, t.z - z) < 3.4);
      const roll = cellHash(x, 11, z);
      if (near ? roll < 0.55 : roll < 0.05) {
        const t = near ? near.tint : FOLIAGE[['orange', 'red', 'yellow'][Math.floor(cellHash(x, 12, z) * 3)]];
        litter.push([x, z, t, Math.floor(cellHash(x, 13, z) * 4) * 90]);
      }
      if (taken.has(key(x, z)) && !near) continue;
      const p = cellHash(x, 14, z);
      if (p < 0.07) plants.push([x, z, 'short_grass']);
      else if (p < 0.085) plants.push([x, z, 'fern']);
      else if (p < 0.092) plants.push([x, z, 'dead_bush']);
      else if (p < 0.1 && near) plants.push([x, z, p < 0.096 ? 'red_mushroom' : 'brown_mushroom']);
    }
    for (const [x, z, tex] of plants) foliage.push([x, z, tex, tex.endsWith('mushroom') ? 0.55 : 0.85 + cellHash(x, 15, z) * 0.2]);

    later.push(() => {
      for (const [x, z, tint, rot] of litter) {
        addBox(K.mb, grid, K.atlas, [x, 0, z], [0, 0, 0], [16, 0.35, 16], {up: {tex: 'leaf_litter', tint, uv: [0, 0, 16, 16], rot}}, {ao: 1});
      }
      // Roots hang from the island's underside, and red creeper trails
      // down its sides.
      for (const [k, bottom] of ground.bottoms) {
        const [x, z] = k.split(',').map(Number);
        if (cellHash(x, 16, z) < 0.22) cross(K.mb, grid, K.atlas, [x, bottom - 1, z], 'hanging_roots', 1, 0);
        for (const [dx, dz, dir] of [[1, 0, 'east'], [-1, 0, 'west'], [0, 1, 'south'], [0, -1, 'north']]) {
          if (isLand(x + dx, z + dz) || cellHash(x * 3 + dx, 17, z * 3 + dz) > 0.32) continue;
          const len = 2 + Math.floor(cellHash(x + dx, 18, z + dz) * 4);
          const vine = {tex: 'vine', double: true};
          for (let i = 0; i < len; i++) {
            const y = -1 - i;
            if (!grid.solid(x, y, z)) break;
            const f = {east: [16.2, 0, 0, 16.2, 16, 16], west: [-0.2, 0, 0, -0.2, 16, 16], south: [0, 0, 16.2, 16, 16, 16.2], north: [0, 0, -0.2, 16, 16, -0.2]}[dir];
            addBox(K.mb, grid, K.atlas, [x, y, z], f.slice(0, 3), f.slice(3), {[dir]: vine}, {ao: 1});
          }
        }
      }
    });
    if (market) market.arrive = [-0.5, deck.z0 + 1.5];
    return {trees, deck, campfire: campfireAt, mailbox, market, foliage};
  }

  // Small islands drifting in the distance, each with a tree or two: only
  // to be looked at, so each has its own little grid for light.
  function distantIslands(mb, atlas, isle) {
    const spots = [
      {c: [-46, 5, isle.cz - 14], r: 6, kind: 'orange'},
      {c: [42, -5, isle.cz + 8], r: 5, kind: 'yellow'},
      {c: [-10, -12, isle.z1 + 30], r: 7, kind: 'red'},
      {c: [28, 11, isle.z0 - 30], r: 4, kind: 'spruce'},
      {c: [-30, -20, isle.z0 - 12], r: 3, kind: null},
    ];
    for (const [i, s] of spots.entries()) {
      const [cx, top, cz] = s.c;
      const g = new Grid([cx - s.r - 3, top - s.r * 2 - 4, cz - s.r - 3], [cx + s.r + 4, top + 12, cz + s.r + 4]);
      const rr = LibraryTextures.rng('far' + i);
      for (let x = cx - s.r; x <= cx + s.r; x++) for (let z = cz - s.r; z <= cz + s.r; z++) {
        const e = Math.hypot(x - cx, z - cz) / (s.r + 0.5 * Math.sin(Math.atan2(z - cz, x - cx) * 3 + i));
        if (e >= 1) continue;
        const depth = 2 + Math.round((1 - e * e) * s.r * 1.6 + rr() * 2);
        for (let y = top - depth; y <= top; y++) g.set(x, y, z, y === top ? B.grass : y > top - 3 ? B.dirt : B.stone);
      }
      if (s.kind) tree(g, cx, cz, s.kind, rr, top + 1);
      g.lightSky();
      for (let z = g.min[2]; z < g.max[2]; z++) for (let y = g.min[1]; y < g.max[1]; y++) for (let x = g.min[0]; x < g.max[0]; x++) {
        const b = g.get(x, y, z);
        if (b) addBlock(mb, g, atlas, x, y, z, b);
      }
    }
  }

  window.LibraryWorld = {
    HALL, BASEMENT, SLOTS, SLOT_COLS, SLOT_ROWS, DYES, RECESS, BOARD, DEPTH, PROFILES, CASES_PER_FLOOR, STAIR, floorBase, ceilingOf,
    MeshBuilder, Grid, FACES, B, AIR,
    addBox, box, frame, addBook, addBookAt, bookCenter, bookDims, bookBoxes, builtInCase, coverRgb, coverTint,
    build, slotGeometry, layout, drawer, drawerBox, drawerSlot, drawerOf, drawerCount, isDrawerSlot, DRAWER_SLOTS, DRAWER_PULL, caseSlots, lantern, chain, candle, cross, campfire, sides, all, itemSprite, hash, uvCorners,
  };
})();
