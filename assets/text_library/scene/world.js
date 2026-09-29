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
  block('grass', {top: 'grass_block_top', bottom: 'dirt', side: 'dirt'});
  // Warm lime plaster between the timbers.
  block('plaster', {all: 'calcite'}, {tint: [1.0, 0.95, 0.86]});
  block('post', {top: 'dark_oak_log_top', bottom: 'dark_oak_log_top', side: 'dark_oak_log'});
  block('beam_x', {east: 'dark_oak_log_top', west: 'dark_oak_log_top', side: 'dark_oak_log'}, {rotFaces: ['north', 'south', 'up', 'down']});
  block('beam_z', {north: 'dark_oak_log_top', south: 'dark_oak_log_top', side: 'dark_oak_log'}, {rotFaces: ['east', 'west']});
  block('oak_log', {top: 'spruce_log_top', bottom: 'spruce_log_top', side: 'oak_log'});
  block('leaves', {all: 'oak_leaves'}, {opaque: false, cutout: true});
  block('spruce_leaves', {all: 'spruce_leaves'}, {opaque: false, cutout: true});
  // Built-in bookcases: solid for light, drawn by builtInCase.
  block('case', {all: 'spruce_planks'}, {custom: true});

  function faceTexture(b, dir) {
    const f = b.faces;
    if (f[dir]) return f[dir];
    if (f.all) return f.all;
    if (dir === 'up') return f.top;
    if (dir === 'down') return f.bottom;
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
      const uv = uvCorners([0, 0, 16, 16], b.rotFaces && b.rotFaces.includes(dir) ? 90 : 0);
      mb.quad(corners, F.n, uv, tileOf(atlas, faceTexture(b, dir)), lights, aos, {tint: b.tint});
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
  function bookBoxes(K, f, u0, u1, v0, h, w0, d, tint, spine, opts = {}) {
    const width = u1 - u0;
    const c = Math.min(0.4 / 16, width * 0.18);
    const s = 0.4 / 16;
    const top = v0 + h;
    const light = opts.light || K.grid.sample(f.p((u0 + u1) / 2, v0 + h / 2, -0.3), f.n);
    const o = {light, emit: opts.emit || 0};
    const leather = {tex: 'leather', tint};
    const edge = {tex: 'leather', tint, ao: 0.82};
    const pages = {tex: 'pages', ao: 0.9};
    f.box(K, u0, v0, w0, u1, top, w0 + s, {front: spine, top: edge, bottom: edge, left: edge, right: edge}, o);
    f.box(K, u0, v0, w0 + s, u0 + c, top, w0 + d, {left: leather, top: edge, back: edge, bottom: edge}, o);
    f.box(K, u1 - c, v0, w0 + s, u1, top, w0 + d, {right: leather, top: edge, back: edge, bottom: edge}, o);
    f.box(K, u0 + c, v0 + 0.3 / 16, w0 + s, u1 - c, top - 0.5 / 16, w0 + d - 0.4 / 16, {top: pages, back: {...pages, ao: 0.6}}, o);
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
  function fillShelves(K, f, width, seed) {
    const r = LibraryTextures.rng('shelf' + seed);
    for (let v = HALL.shelfBottom; v < HALL.shelfTop; v++) {
      const v0 = v + BOARD;
      let u = SIDE + 0.02;
      while (u < width - SIDE - 0.1) {
        if (width >= 4 && u > width / 2 - MID - 0.12 && u < width / 2 + MID) { u = width / 2 + MID + 0.02; continue; }
        const roll = r();
        if (roll < 0.07) { u += 0.15 + r() * 0.3; continue; }
        const tint = DECO[Math.floor(r() * DECO.length)].map(c => c * (0.8 + r() * 0.35) / 255);
        if (roll < 0.14 && u + 0.6 < width - SIDE) {
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
        const u1 = Math.min(width - SIDE - 0.01, u + w);
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
    const width = spec.width;
    const ends = !!opts.ends;
    const wood = {tex: 'spruce_planks'}, trim = {tex: 'dark_oak_planks'};
    const end = ends ? wood : null;
    const ao = c => 1 - 0.58 * Math.pow(Math.min(1, Math.max(0, f.depth(c) / DEPTH)), 0.8);
    const light = opts.light;
    f.box(K, 0, 0, 0, width, HALL.shelfBottom, DEPTH + 1 / 16, {front: {tex: 'cabinet_door'}, left: end, right: end}, {light});
    for (let v = HALL.shelfBottom; v < HALL.shelfTop; v++) {
      const lip = v === HALL.shelfBottom ? 1.5 / 16 : 0;
      f.box(K, 0, v, -lip, width, v + BOARD, DEPTH, {
        front: v === HALL.shelfBottom ? trim : wood, top: wood, bottom: v === HALL.shelfBottom ? trim : wood, left: end, right: end,
      }, {ao, light});
      const v0 = v + BOARD, v1 = v + 1;
      f.box(K, 0, v0, 0, SIDE, v1, DEPTH, {front: wood, right: wood, left: end}, {ao, light});
      f.box(K, width - SIDE, v0, 0, width, v1, DEPTH, {front: wood, left: wood, right: end}, {ao, light});
      if (width >= 4) f.box(K, width / 2 - MID, v0, 0, width / 2 + MID, v1, DEPTH, {front: wood, left: wood, right: wood}, {ao, light});
    }
    f.box(K, 0, HALL.shelfBottom, DEPTH, width, HALL.shelfTop, DEPTH, {front: {tex: 'spruce_planks', tint: [0.7, 0.64, 0.6]}}, {ao: 0.46, light});
    f.box(K, 0, HALL.shelfTop, 0, width, HALL.caseTop - 0.125, DEPTH, {front: trim, bottom: wood, left: end ? trim : null, right: end ? trim : null}, {ao, light});
    f.box(K, 0, HALL.caseTop - 0.125, -2 / 16, width, HALL.caseTop, DEPTH, {front: trim, top: trim, bottom: trim, left: end ? trim : null, right: end ? trim : null}, {light});
    if (opts.fill != null) fillShelves(K, f, width, opts.fill);
    return f;
  }

  // World-space box of one slot's opening, for picking and for books.
  function slotGeometry(caseInfo, slot) {
    const local = slot % SLOTS;
    const row = Math.floor(local / SLOT_COLS), col = local % SLOT_COLS;
    const bay = col < 9 ? 0 : 1;
    const u0 = bay * HALL.caseWidth / 2 + (bay ? MID : SIDE) + (col % 9) * SLOT_W, u1 = u0 + SLOT_W;
    // Rows count down from the top shelf.
    const vb = HALL.shelfTop - 1 - row;
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
    const sections = Math.max(2, Math.ceil(cases / 2));
    const hallEnd = -sections * HALL.section; // z of the last post
    return {sections, hallStart: HALL.foyer, hallEnd, endWall: hallEnd - HALL.end};
  }

  function caseSlots(subjectCount) {
    const out = [];
    for (let i = 0; i <= subjectCount; i++) {
      const section = Math.floor(i / 2);
      const facing = i % 2 === 0 ? 1 : -1;
      // Cells -5k-4 … -5k-1, so z ∈ [-5k-4, -5k].
      const z0 = -section * HALL.section - HALL.caseWidth;
      const z1 = z0 + HALL.caseWidth;
      const faceX = facing > 0 ? -HALL.caseFace : HALL.caseFace;
      out.push({
        index: i, section, facing,
        cellX: facing > 0 ? -HALL.halfWidth : HALL.caseFace,
        faceX, z0, z1, y0: 0, y1: HALL.caseTop,
        spec: {origin: [faceX, 0, facing > 0 ? z1 : z0], right: facing > 0 ? [0, 0, -1] : [0, 0, 1], n: [facing, 0, 0], width: HALL.caseWidth},
        placeholder: i === subjectCount,
      });
    }
    return out;
  }

  function build(T, atlas, canvases, subjects) {
    const L = layout(subjects.length);
    const cases = caseSlots(subjects.length);
    const W = HALL.halfWidth, H = HALL.height, E = L.endWall, F = L.hallStart;
    const minZ = E - 3, maxZ = F + 5;
    const grid = new Grid([-14, -3, minZ], [14, 13, maxZ]);
    const K = {mb: new MeshBuilder(), grid, atlas, canvases, candles: [], colliders: []};
    const Fu = window.LibraryFurniture;
    const later = [];
    const lampSeeds = [];
    const windows = [];
    const light = (x, y, z, level) => lampSeeds.push([Math.floor(x), Math.floor(y), Math.floor(z), level]);
    const solidBox = (x0, z0, x1, z1) => K.colliders.push([Math.min(x0, x1), Math.min(z0, z1), Math.max(x0, x1), Math.max(z0, z1)]);
    const opening = (x, y, z, axis) => { grid.set(x, y, z, AIR); windows.push({cell: [x, y, z], axis}); };

    // Ground outside, stone footings, a spruce floor.
    grid.fill([-14, -3, minZ], [13, -2, maxZ - 1], B.dirt);
    grid.fill([-14, -1, minZ], [13, -1, maxZ - 1], B.grass);
    grid.fill([-W - 1, -1, E], [W, -1, F], B.cobblestone);
    grid.fill([-W, -1, E + 1], [W - 1, -1, F - 1], B.spruce_planks);

    // Side walls: a stone plinth, plaster above, a timber rail at y 4.
    for (let z = E; z <= F; z++) {
      for (const x of [-W - 1, W]) {
        grid.set(x, 0, z, B.stone_bricks);
        grid.fill([x, 1, z], [x, H - 1, z], B.plaster);
        grid.set(x, 4, z, B.beam_z);
      }
    }
    // End wall of stone, front wall of plaster with a rail over the door.
    grid.fill([-W - 1, 0, E], [W, H, E], B.stone_bricks);
    for (let x = -W - 1; x <= W; x++) {
      grid.set(x, 0, F, B.stone_bricks);
      grid.fill([x, 1, F], [x, H - 1, F], B.plaster);
      grid.set(x, 3, F, B.beam_x);
    }
    // Plank ceiling, roof over it.
    grid.fill([-W - 1, H, E], [W, H, F], B.spruce_planks);
    grid.fill([-W - 1, H + 1, E], [W, H + 1, F], B.dark_oak_planks);

    // Timber frame: a post in each wall and between each pair of cases,
    // tied across the ceiling by a beam.
    for (let k = 0; k <= L.sections; k++) {
      const zp = -k * HALL.section;
      for (const x of [-W - 1, W]) grid.fill([x, 0, zp], [x, H - 1, zp], B.post);
      for (const x of [-W, W - 1]) grid.fill([x, 0, zp], [x, 5, zp], B.post);
      for (let x = -W; x < W; x++) grid.set(x, H - 1, zp, B.beam_x);
    }
    for (const x of [-W - 1, W]) grid.fill([x, 0, F], [x, H - 1, F], B.post);
    for (const z of [F - 3, E + 4]) for (let x = -W; x < W; x++) grid.set(x, H - 1, z, B.beam_x);

    // Each span between posts holds a bookcase with a strip of windows over
    // it, or, where there is no case, a window seat.
    const nooks = [];
    for (let k = 0; k < L.sections; k++) {
      const zb = -k * HALL.section - 1, za = zb - 3;
      for (const side of [1, -1]) {
        const wallX = side > 0 ? -W - 1 : W;
        const c = cases.find(cs => cs.section === k && cs.facing === side);
        if (c) {
          for (let z = za; z <= zb; z++) opening(wallX, 6, z, 'x');
          if (!c.placeholder) for (let z = c.z0; z < c.z1; z++) for (let y = 0; y <= 5; y++) grid.set(c.cellX, y, z, B.case);
        } else {
          for (let z = za + 1; z <= zb - 1; z++) for (const y of [1, 2, 3]) opening(wallX, y, z, 'x');
          nooks.push({side, za, zb});
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

    // Front: a double door with a window either side, windows in the side
    // walls.
    for (const x of [-1, 0]) for (const y of [0, 1]) grid.set(x, y, F, AIR);
    for (const x of [-4, -3, 2, 3]) for (const y of [1, 2]) opening(x, y, F, 'z');
    for (const x of [-W - 1, W]) for (let z = 2; z <= 4; z++) for (const y of [1, 2, 3]) opening(x, y, z, 'x');

    // Trees outside the windows.
    for (let k = -1; k <= L.sections + 2; k++) {
      for (const side of [-1, 1]) {
        const tz = -k * HALL.section - 2 + (side > 0 ? 1 : -1);
        const tx = side * (W + 4 + (k % 2));
        if (tz < minZ + 2 || tz > maxZ - 3) continue;
        for (let y = 0; y < 5; y++) grid.set(tx, y, tz, B.oak_log);
        for (let dx = -2; dx <= 2; dx++) for (let dz = -2; dz <= 2; dz++) for (let dy = 3; dy <= 6; dy++) {
          const r = Math.abs(dx) + Math.abs(dz) + Math.max(0, dy - 5) * 2;
          if (r > 3 || (dx === 0 && dz === 0 && dy < 5)) continue;
          if (Math.abs(tx + dx) <= W) continue;
          if (!grid.get(tx + dx, dy, tz + dz)) grid.set(tx + dx, dy, tz + dz, (tx + tz) % 3 ? B.leaves : B.spruce_leaves);
        }
      }
    }

    // ── Lights and furniture ────────────────────────────────────────────
    // Hanging lanterns down the middle, and one on an arm off every post.
    const lamps = [];
    for (let k = 0; k < L.sections; k++) lamps.push({cell: [-1, 4, -k * HALL.section - 3], hanging: true});
    lamps.push({cell: [-1, 4, F - 2], hanging: true});
    lamps.push({cell: [-1, 4, E + 6], hanging: true});
    for (let k = 0; k <= L.sections; k++) {
      lamps.push({cell: [-W + 1, 3, -k * HALL.section], side: 1});
      lamps.push({cell: [W - 2, 3, -k * HALL.section], side: -1});
    }
    for (const l of lamps) light(...l.cell, 15);

    // Something standing at the foot of each post, going round a few kinds.
    const kinds = ['fern', 'stack', 'azalea', 'barrel', 'globe', 'fern', 'stack', 'azalea'];
    for (let k = 1; k <= L.sections; k++) {
      for (const side of [1, -1]) {
        const kind = kinds[(k * 2 + (side > 0 ? 0 : 1)) % kinds.length];
        const x = side > 0 ? -W + 1 : W - 2, z = -k * HALL.section;
        const inset = side > 0 ? 0 : 0.3;
        solidBox(x + inset, z + 0.15, x + 0.7 + inset, z + 0.85);
        later.push(() => Fu.postDecor(K, kind, [x + (side > 0 ? -0.18 : 0.18), 0, z], side));
      }
    }

    // Window seats in the spans without a case.
    for (const nook of nooks) {
      const x = nook.side > 0 ? -W : W - 1;
      solidBox(x, nook.za, x + 1, nook.zb + 1);
      later.push(() => Fu.windowSeat(K, nook.side, x, nook.za, nook.zb + 1));
      light(x, 1, nook.za + 2, 10);
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
    solidBox(-0.4, deskZ + 0.4, 0.4, deskZ + 1.2);
    light(-1, 1, deskO[2], 12); light(0, 1, deskO[2], 12);
    later.push(() => Fu.desk(K, deskO));
    const chairs = [[-3.6, fz + 2.3, 1], [2.6, fz + 2.3, -1]];
    for (const [cx, cz] of chairs) solidBox(cx + 0.05, cz + 0.05, cx + 0.95, cz + 0.95);
    later.push(() => {
      for (const [cx, cz] of chairs) Fu.armchair(K, [cx, 0, cz], Math.atan2(-(cx + 0.5), -(fz + 0.5 - (cz + 0.5))), 'red_wool');
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
      light(x, 1, E + 5, 10);
    }
    later.push(() => {
      Fu.rug(K, -4, fz + 1.4, 4, fz + 5.2, 'rug_green', 'rug_green_border');
      Fu.ladder(K, endCases[0], 2.1);
    });

    // The foyer: a clock, a coat stand, a bench, plants by the door.
    solidBox(-W, 1.1, -W + 0.65, 1.9);
    const clockAt = {face: null};
    later.push(() => { clockAt.face = Fu.clock(K, [-W - 0.17, 0, 1]); });
    solidBox(W - 1, 1.2, W, 1.8);
    later.push(() => Fu.coatStand(K, [W - 1.4, 0, 1]));
    for (const x of [-2, 1]) {
      solidBox(x + 0.2, F - 0.8, x + 0.8, F - 0.2);
      later.push(() => Fu.pot(K, [x, 0, F - 1], x < 0 ? 'azalea' : 'fern', true));
    }
    later.push(() => {
      Fu.door(K, -1, F);
      Fu.rug(K, -2, 1.5, 2, 5.4, 'rug_red', 'rug_red_border');
      Fu.hangingPlant(K, [-W + 1, H, F - 1]);
      Fu.hangingPlant(K, [W - 2, H, F - 1]);
      Fu.hangingPlant(K, [-W + 1, H, E + 7]);
      Fu.hangingPlant(K, [W - 2, H, E + 7]);
    });
    later.push(() => Fu.rug(K, -1, E + 6.3, 1, 1.4, 'rug_red', 'rug_red_border'));

    // ── Light ───────────────────────────────────────────────────────────
    grid.lightSky();
    grid.propagate('lamp', lampSeeds);
    grid.propagate('fire', [[-1, 0, fz, 15], [0, 0, fz, 15], [-1, 1, fz, 14], [0, 1, fz, 14]]);

    // ── Geometry ────────────────────────────────────────────────────────
    const mb = K.mb;
    for (let z = grid.min[2]; z < grid.max[2]; z++) for (let y = grid.min[1]; y < grid.max[1]; y++) for (let x = grid.min[0]; x < grid.max[0]; x++) {
      const b = grid.get(x, y, z);
      if (!b || b.custom) continue;
      addBlock(mb, grid, atlas, x, y, z, b);
    }
    for (const c of cases) if (!c.placeholder) builtInCase(K, c.spec);
    endCases.forEach((spec, i) => builtInCase(K, spec, {fill: i}));

    // Window panes: thin glass in the middle of each opening, a sill below.
    const glass = new MeshBuilder();
    for (const {cell: [x, y, z], axis} of windows) {
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
          const inward = x < 0 ? 1 : -1;
          addBox(mb, grid, atlas, [x + inward, y, z], inward > 0 ? [0, 0, 0] : [13, 0, 0], inward > 0 ? [3, 1.5, 16] : [16, 1.5, 16], sill);
        } else {
          addBox(mb, grid, atlas, [x, y, z - 1], [0, 0, 13], [16, 1.5, 16], sill);
        }
      }
    }

    // Lanterns: hanging on chains, and on iron arms off the posts.
    for (const lamp of lamps) {
      const [x, y, z] = lamp.cell;
      if (lamp.hanging) {
        const o = [x + 0.5, y, z];
        lantern(mb, grid, atlas, o, true);
        chain(mb, grid, atlas, [o[0], y + 13 / 16, o[2]], H - (y + 13 / 16));
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
      desk: {z: deskZ, top: 1, center: [0, 1, deskO[2] + 0.5]},
      fire: [0, 0.6, fz + 0.5],
      bounds: {min: [-W - 1, -1, E], max: [W + 1, H + 2, F + 1]},
      walk: {minX: -W + 0.3, maxX: W - 0.3, minZ: E + 1.3, maxZ: F - 0.3},
    };
  }

  window.LibraryWorld = {
    HALL, SLOTS, SLOT_COLS, SLOT_ROWS, DYES, RECESS, BOARD, DEPTH,
    MeshBuilder, Grid, FACES, B, AIR,
    addBox, box, frame, addBook, addBookAt, bookCenter, bookDims, bookBoxes, builtInCase, coverRgb, coverTint,
    build, slotGeometry, layout, caseSlots, lantern, chain, candle, cross, sides, all, itemSprite, hash,
  };
})();
