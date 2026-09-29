// Every texture the library uses, packed into one atlas.
//
// When luma found Minecraft on this machine the page is handed the real
// vanilla textures (read from the user's own client jar, never bundled). For
// anything missing, a procedural look-alike is painted here instead, so the
// hall is always complete.
(() => {
  'use strict';

  // Name → [vanilla path, painter]. Paths are under assets/minecraft/.
  const LIST = {
    oak_planks: 'textures/block/oak_planks.png',
    spruce_planks: 'textures/block/spruce_planks.png',
    dark_oak_planks: 'textures/block/dark_oak_planks.png',
    spruce_log: 'textures/block/spruce_log.png',
    spruce_log_top: 'textures/block/spruce_log_top.png',
    stripped_spruce_log: 'textures/block/stripped_spruce_log.png',
    stripped_spruce_log_top: 'textures/block/stripped_spruce_log_top.png',
    dark_oak_log: 'textures/block/dark_oak_log.png',
    dark_oak_log_top: 'textures/block/dark_oak_log_top.png',
    stone_bricks: 'textures/block/stone_bricks.png',
    mossy_stone_bricks: 'textures/block/mossy_stone_bricks.png',
    cobblestone: 'textures/block/cobblestone.png',
    polished_andesite: 'textures/block/polished_andesite.png',
    smooth_stone: 'textures/block/smooth_stone.png',
    bricks: 'textures/block/bricks.png',
    chiseled_bookshelf_empty: 'textures/block/chiseled_bookshelf_empty.png',
    chiseled_bookshelf_side: 'textures/block/chiseled_bookshelf_side.png',
    chiseled_bookshelf_top: 'textures/block/chiseled_bookshelf_top.png',
    bookshelf: 'textures/block/bookshelf.png',
    glass: 'textures/block/glass.png',
    red_wool: 'textures/block/red_wool.png',
    white_wool: 'textures/block/white_wool.png',
    brown_wool: 'textures/block/brown_wool.png',
    lantern: 'textures/block/lantern.png',
    chain: 'textures/block/iron_chain.png',
    candle: 'textures/block/candle.png',
    candle_lit: 'textures/block/candle_lit.png',
    campfire_log: 'textures/block/campfire_log.png',
    campfire_log_lit: 'textures/block/campfire_log_lit.png',
    campfire_fire: 'textures/block/campfire_fire.png',
    oak_leaves: 'textures/block/oak_leaves.png',
    spruce_leaves: 'textures/block/spruce_leaves.png',
    grass_block_top: 'textures/block/grass_block_top.png',
    dirt: 'textures/block/dirt.png',
    oak_log: 'textures/block/oak_log.png',
    flower_pot: 'textures/block/flower_pot.png',
    fern: 'textures/block/fern.png',
    poppy: 'textures/block/poppy.png',
    azalea_leaves: 'textures/block/azalea_leaves.png',
    lectern_top: 'textures/block/lectern_top.png',
    lectern_sides: 'textures/block/lectern_sides.png',
    lectern_base: 'textures/block/lectern_base.png',
    lectern_front: 'textures/block/lectern_front.png',
    barrel_side: 'textures/block/barrel_side.png',
    barrel_top: 'textures/block/barrel_top.png',
    white_carpet_sheep: 'textures/block/white_wool.png',
    writable_book: 'textures/item/writable_book.png',
    written_book: 'textures/item/written_book.png',
    book: 'textures/item/book.png',
    feather: 'textures/item/feather.png',
    ink_sac: 'textures/item/ink_sac.png',
    iron_bars: 'textures/block/iron_bars.png',
    calcite: 'textures/block/calcite.png',
    stripped_dark_oak_log: 'textures/block/stripped_dark_oak_log.png',
    stripped_dark_oak_log_top: 'textures/block/stripped_dark_oak_log_top.png',
    green_wool: 'textures/block/green_wool.png',
    blue_wool: 'textures/block/blue_wool.png',
    light_gray_wool: 'textures/block/light_gray_wool.png',
    yellow_wool: 'textures/block/yellow_wool.png',
    terracotta: 'textures/block/terracotta.png',
    spruce_door_top: 'textures/block/spruce_door_top.png',
    spruce_door_bottom: 'textures/block/spruce_door_bottom.png',
    ladder: 'textures/block/ladder.png',
    vine: 'textures/block/vine.png',
    flowering_azalea_leaves: 'textures/block/flowering_azalea_leaves.png',
    painting_left: {path: 'textures/painting/sunset.png', crop: [0, 0, 0.5, 1]},
    painting_right: {path: 'textures/painting/sunset.png', crop: [0.5, 0, 0.5, 1]},
    painting_small: 'textures/painting/plant.png',
    // The island and the autumn outside.
    stone: 'textures/block/stone.png',
    andesite: 'textures/block/andesite.png',
    coal_ore: 'textures/block/coal_ore.png',
    coarse_dirt: 'textures/block/coarse_dirt.png',
    grass_block_side_overlay: 'textures/block/grass_block_side_overlay.png',
    dirt_path_top: 'textures/block/dirt_path_top.png',
    dirt_path_side: 'textures/block/dirt_path_side.png',
    leaf_litter: 'textures/block/leaf_litter.png',
    birch_log: 'textures/block/birch_log.png',
    birch_log_top: 'textures/block/birch_log_top.png',
    birch_leaves: 'textures/block/birch_leaves.png',
    pumpkin_side: 'textures/block/pumpkin_side.png',
    pumpkin_top: 'textures/block/pumpkin_top.png',
    carved_pumpkin: 'textures/block/carved_pumpkin.png',
    jack_o_lantern: 'textures/block/jack_o_lantern.png',
    hay_block_side: 'textures/block/hay_block_side.png',
    hay_block_top: 'textures/block/hay_block_top.png',
    short_grass: 'textures/block/short_grass.png',
    red_mushroom: 'textures/block/red_mushroom.png',
    brown_mushroom: 'textures/block/brown_mushroom.png',
    hanging_roots: 'textures/block/hanging_roots.png',
    dead_bush: 'textures/block/dead_bush.png',
  };
  const pathOf = entry => (typeof entry === 'string' ? entry : entry?.path);

  // Files the page asks the host for beyond the atlas textures.
  const EXTRA = [
    'font/include/default.json',
    'textures/font/ascii.png',
    'textures/font/accented.png',
    'textures/font/nonlatin_european.png',
    'textures/gui/book.png',
    'textures/gui/sprites/widget/button.png',
    'textures/gui/sprites/widget/button_highlighted.png',
    'textures/gui/sprites/widget/button_disabled.png',
    'textures/gui/sprites/widget/page_forward.png',
    'textures/gui/sprites/widget/page_forward_highlighted.png',
    'textures/gui/sprites/widget/page_backward.png',
    'textures/gui/sprites/widget/page_backward_highlighted.png',
    'textures/gui/sprites/widget/text_field.png',
    'textures/gui/sprites/widget/text_field_highlighted.png',
    'textures/gui/sprites/toast/advancement.png',
    'textures/block/chain.png',
    'textures/block/campfire_fire.png.mcmeta',
    'textures/block/lantern.png.mcmeta',
    'textures/environment/clouds.png',
    // The default look for the reader's own hand, until they import a skin.
    'textures/entity/player/wide/steve.png',
  ];
  for (let i = 0; i < 26; i++) EXTRA.push(`textures/particle/sga_${String.fromCharCode(97 + i)}.png`);

  // ── Deterministic noise ────────────────────────────────────────────────
  function rng(seed) {
    let s = 0;
    for (const c of seed) s = (s * 31 + c.charCodeAt(0)) >>> 0;
    s = s || 1;
    return () => {
      s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0;
      return s / 4294967296;
    };
  }
  const clamp = v => Math.max(0, Math.min(255, Math.round(v)));
  const shade = (c, f) => [clamp(c[0] * f), clamp(c[1] * f), clamp(c[2] * f), c[3] == null ? 255 : c[3]];
  const hex = h => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16), 255];

  function paint(w, h, fn) {
    const canvas = document.createElement('canvas');
    canvas.width = w; canvas.height = h;
    const ctx = canvas.getContext('2d');
    const img = ctx.createImageData(w, h);
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const c = fn(x, y);
        if (!c) continue;
        const o = (y * w + x) * 4;
        img.data[o] = c[0]; img.data[o + 1] = c[1]; img.data[o + 2] = c[2]; img.data[o + 3] = c[3] == null ? 255 : c[3];
      }
    }
    ctx.putImageData(img, 0, 0);
    return canvas;
  }

  // Planks: four boards, a dark seam under each, staggered end joints.
  function planks(name, base) {
    const r = rng(name);
    const joints = [3, 11, 7, 14];
    const grain = Array.from({length: 256}, () => r());
    return paint(16, 16, (x, y) => {
      const board = y >> 2, row = y & 3;
      let f = 0.92 + grain[y * 16 + x] * 0.14;
      if (row === 3) f = 0.62;
      if (row === 0) f += 0.06;
      if (x === joints[board]) f *= 0.66;
      if ((x + board * 5) % 9 === 0 && row === 1) f *= 0.86;
      return shade(base, f);
    });
  }

  function logSide(name, base, streak) {
    const r = rng(name);
    const cols = Array.from({length: 16}, () => 0.8 + r() * 0.3);
    return paint(16, 16, (x, y) => {
      let f = cols[x] * (0.95 + r() * 0.1);
      if ((x * 7 + y * 3) % 11 === 0) f *= streak;
      return shade(base, f);
    });
  }

  function logTop(name, bark, wood) {
    const r = rng(name);
    return paint(16, 16, (x, y) => {
      if (x === 0 || y === 0 || x === 15 || y === 15) return shade(bark, 0.85 + r() * 0.2);
      const d = Math.max(Math.abs(x - 7.5), Math.abs(y - 7.5));
      const ring = Math.floor(d) % 2 === 0 ? 0.9 : 1.02;
      return shade(wood, ring * (0.95 + r() * 0.08));
    });
  }

  function stoneBricks(name, base, moss) {
    const r = rng(name);
    return paint(16, 16, (x, y) => {
      const row = y >> 2;
      const offset = row % 2 ? 4 : 0;
      const mortar = (y & 3) === 3 || ((x + offset) & 7) === 7;
      let f = mortar ? 0.64 : 0.92 + r() * 0.16;
      if (!mortar && (y & 3) === 0) f += 0.06;
      const c = shade(base, f);
      if (moss && !mortar && r() < 0.18 + (y > 8 ? 0.2 : 0)) return shade([74, 98, 44], 0.9 + r() * 0.2);
      return c;
    });
  }

  function cobble(name, base) {
    const r = rng(name);
    const cells = Array.from({length: 7}, () => [r() * 16, r() * 16, 0.82 + r() * 0.3]);
    return paint(16, 16, (x, y) => {
      let best = 1e9, second = 1e9, tone = 1;
      for (const [cx, cy, t] of cells) {
        for (const dx of [-16, 0, 16]) for (const dy of [-16, 0, 16]) {
          const d = (x - cx - dx) ** 2 + (y - cy - dy) ** 2;
          if (d < best) { second = best; best = d; tone = t; } else if (d < second) second = d;
        }
      }
      const edge = Math.sqrt(second) - Math.sqrt(best) < 1.2;
      return shade(base, edge ? 0.55 : tone * (0.92 + r() * 0.12));
    });
  }

  function wool(name, base) {
    const r = rng(name);
    return paint(16, 16, (x, y) => shade(base, 0.9 + r() * 0.12 + ((x + y * 2) % 5 === 0 ? -0.06 : 0)));
  }

  const OAK = [168, 136, 84], SPRUCE = [114, 84, 50], DARK_OAK = [66, 43, 21];
  const BOOK_COLORS = ['#8e2c20', '#2d4f8a', '#3f6b2a', '#7a5a2a', '#5c2e6e', '#a8742a', '#2a6b6b'];

  function chiseledFront(name, empty) {
    const r = rng(name);
    const base = planks('chiseled_planks', OAK);
    const bctx = base.getContext('2d').getImageData(0, 0, 16, 16).data;
    return paint(16, 16, (x, y) => {
      const o = (y * 16 + x) * 4;
      const wood = [bctx[o], bctx[o + 1], bctx[o + 2], 255];
      const inRow = (y >= 1 && y <= 6) || (y >= 9 && y <= 14);
      const inCol = x >= 1 && x <= 14;
      if (!inRow || !inCol) return shade(wood, (y === 7 || y === 15) ? 0.7 : 1);
      const divider = x === 5 || x === 10 || x === 11 && false;
      if (divider) return shade(wood, 0.8);
      if (empty) {
        const lip = (y === 1 || y === 9) ? 0.5 : 0.28;
        return shade([60, 40, 22], lip + r() * 0.05);
      }
      const book = BOOK_COLORS[(x * 3 + (y > 8 ? 5 : 0)) % BOOK_COLORS.length];
      return shade(hex(book), 0.85 + r() * 0.2);
    });
  }

  function chiseledSide(name) {
    const base = planks('chiseled_side', OAK);
    const d = base.getContext('2d').getImageData(0, 0, 16, 16).data;
    return paint(16, 16, (x, y) => {
      const o = (y * 16 + x) * 4;
      const c = [d[o], d[o + 1], d[o + 2], 255];
      const frame = x === 0 || x === 15 || y === 0 || y === 15 || y === 7 || y === 8;
      return shade(c, frame ? 0.78 : 1);
    });
  }

  function bookshelf(name) {
    const r = rng(name);
    const wood = planks('bookshelf_planks', OAK).getContext('2d').getImageData(0, 0, 16, 16).data;
    const heights = Array.from({length: 16}, () => 1 + Math.floor(r() * 2));
    return paint(16, 16, (x, y) => {
      const o = (y * 16 + x) * 4;
      if (y < 1 || y > 14 || y === 7 || y === 8) return [wood[o], wood[o + 1], wood[o + 2], 255];
      const shelfTop = y < 7 ? 1 : 9;
      if (y - shelfTop < heights[(x + (y > 8 ? 7 : 0)) % 16] - 1) return [40, 27, 14, 255];
      const book = BOOK_COLORS[Math.floor((x + (y > 8 ? 2 : 0)) / 2) % BOOK_COLORS.length];
      const band = y === shelfTop + 2 || y === shelfTop + 4;
      return shade(hex(book), (x % 2 ? 0.82 : 1) * (band ? 1.25 : 1));
    });
  }

  function glass() {
    return paint(16, 16, (x, y) => {
      if (x === 0 || y === 0 || x === 15 || y === 15) return [220, 236, 240, 255];
      if ((x === y + 2 || x === y + 3) && x < 8 && y > 1) return [255, 255, 255, 130];
      if (x === y - 6 && x > 8) return [255, 255, 255, 110];
      return [200, 225, 235, 22];
    });
  }

  function lantern() {
    // Laid out like the game's sheet: cap at the top rows, body below it,
    // handle on the right.
    const r = rng('lantern');
    return paint(16, 16, (x, y) => {
      if (y < 2 && x >= 1 && x < 5) return shade([72, 72, 84], 0.9 + r() * 0.2);
      if (y >= 2 && y < 9 && x < 6) {
        if (y === 2 || y === 8) return shade([60, 62, 74], 1);
        if (x === 0 || x === 5) return shade([72, 72, 84], 1);
        return shade([255, 200, 96], 0.92 + r() * 0.15);
      }
      if (y >= 9 && y < 15 && x < 6) return shade([70, 72, 82], 0.9 + r() * 0.15);
      if (x >= 11 && x < 14 && y >= 1 && y < 12) return shade([66, 68, 80], 1);
      return null;
    });
  }

  function chain() {
    return paint(16, 16, (x, y) => {
      if ((x === 1 || x === 3) && (y % 4 !== 3)) return [70, 74, 88, 255];
      if (x === 2 && y % 4 === 0) return [96, 100, 116, 255];
      if (x >= 4 && x <= 5 && (y % 4 === 2)) return [60, 62, 74, 255];
      return null;
    });
  }

  function candle(lit) {
    const r = rng('candle');
    return paint(16, 16, (x, y) => {
      if (x < 2 && y >= 8 && y < 14) return shade([236, 222, 196], 0.92 + r() * 0.1);
      if (x < 2 && y >= 6 && y < 8) return shade([244, 232, 208], 1);
      if (x < 2 && y >= 14) return shade([210, 196, 170], 1);
      if (x === 0 && y === 5) return lit ? [255, 214, 120, 255] : [60, 50, 40, 255];
      return null;
    });
  }

  function campfireLog(name, lit) {
    const r = rng(name);
    return paint(16, 16, (x, y) => {
      if (y < 4 || (y >= 8 && y < 12)) {
        let c = shade([92, 64, 38], 0.85 + r() * 0.3);
        if (lit && r() < 0.18) c = shade([255, 150, 50], 0.8 + r() * 0.4);
        return c;
      }
      if (y >= 4 && y < 8) {
        const d = Math.max(Math.abs((x % 4) - 1.5), Math.abs(y - 5.5));
        return d < 1 ? [150, 118, 72, 255] : [70, 48, 28, 255];
      }
      return shade([60, 40, 24], 0.9 + r() * 0.2);
    });
  }

  // Flame strips: a small fire simulation, one frame per 16 rows.
  function fire(name, frames) {
    const r = rng(name);
    const heat = new Float32Array(16 * 20);
    const out = [];
    const palette = t => t < 0.25 ? null : t < 0.45 ? [196, 58, 12, Math.round(180 + t * 150)] : t < 0.7 ? [240, 136, 28, 255] : t < 0.88 ? [255, 206, 72, 255] : [255, 246, 196, 255];
    for (let f = 0; f < frames + 16; f++) {
      for (let x = 0; x < 16; x++) {
        const edge = Math.min(x, 15 - x);
        heat[19 * 16 + x] = edge < 2 ? r() * 0.4 : 0.7 + r() * 0.5;
      }
      for (let y = 0; y < 19; y++) {
        for (let x = 0; x < 16; x++) {
          const src = (y + 1) * 16 + Math.min(15, Math.max(0, x + Math.floor(r() * 3) - 1));
          heat[y * 16 + x] = Math.max(0, heat[src] - r() * 0.11 - 0.02);
        }
      }
      if (f >= 16) out.push(Float32Array.from(heat.subarray(4 * 16)));
    }
    return paint(16, 16 * frames, (x, y) => palette(out[Math.floor(y / 16)][(y % 16) * 16 + x]));
  }

  function leaves(name, base) {
    const r = rng(name);
    return paint(16, 16, (x, y) => (r() < 0.14 ? null : shade(base, 0.7 + r() * 0.45)));
  }

  function grassTop(name) {
    const r = rng(name);
    return paint(16, 16, (x, y) => shade([150, 136, 70], 0.8 + r() * 0.3));
  }

  function flowerPot() {
    return paint(16, 16, (x, y) => {
      if (y >= 10 || (y >= 5 && y < 11 && x >= 5 && x < 11)) return shade([132, 72, 50], 0.9 + ((x + y) % 3) * 0.05);
      return null;
    });
  }

  function plant(name, stem, bloom) {
    const r = rng(name);
    return paint(16, 16, (x, y) => {
      if (bloom && y < 6 && Math.abs(x - 7.5) + Math.abs(y - 3) < 4) return shade(bloom, 0.85 + r() * 0.3);
      const wave = Math.round(7.5 + Math.sin(y * 0.8) * 1.5);
      if (y >= 4 && Math.abs(x - wave) < 1) return shade(stem, 0.9);
      if (!bloom && y >= 2 && Math.abs(x - 7.5) < (16 - y) * 0.45 && r() < 0.55) return shade(stem, 0.75 + r() * 0.35);
      return null;
    });
  }

  function barrel(top) {
    const wood = planks('barrel', SPRUCE).getContext('2d').getImageData(0, 0, 16, 16).data;
    return paint(16, 16, (x, y) => {
      const o = (y * 16 + x) * 4;
      const c = [wood[o], wood[o + 1], wood[o + 2], 255];
      if (top) {
        if (x === 0 || y === 0 || x === 15 || y === 15) return shade(c, 0.7);
        if (x >= 5 && x <= 10 && y >= 5 && y <= 10) return shade(c, 0.85);
        return c;
      }
      if (y === 2 || y === 13) return [88, 88, 94, 255];
      return shade(c, x % 4 === 3 ? 0.78 : 1);
    });
  }

  // Item sprites: a book lying flat, seen from above.
  function itemBook(cover, quill) {
    return paint(16, 16, (x, y) => {
      const inBook = x >= 2 && x <= 12 && y >= 3 && y <= 13;
      if (quill && x - y === 3 && x > 9) return [240, 240, 240, 255];
      if (!inBook) return null;
      if (x === 12 || y === 13) return [236, 230, 210, 255];
      if (x === 2) return shade(hex(cover), 0.7);
      return shade(hex(cover), (x + y) % 5 === 0 ? 0.9 : 1);
    });
  }

  function feather() {
    return paint(16, 16, (x, y) => (Math.abs(x - (15 - y)) <= (y > 3 && y < 12 ? 1 : 0) ? [236, 236, 236, 255] : null));
  }

  function inkSac() {
    return paint(16, 16, (x, y) => ((x - 8) ** 2 + (y - 9) ** 2 < 16 ? [40, 38, 58, 255] : null));
  }

  function lectern(part) {
    const wood = planks('lectern_' + part, OAK).getContext('2d').getImageData(0, 0, 16, 16).data;
    return paint(16, 16, (x, y) => {
      const o = (y * 16 + x) * 4;
      return shade([wood[o], wood[o + 1], wood[o + 2], 255], part === 'front' && x > 3 && x < 12 ? 0.85 : 1);
    });
  }

  function ironBars() {
    return paint(16, 16, (x, y) => ((x % 8 === 7 || x % 8 === 0) || y === 0 || y === 15 ? [88, 90, 98, 255] : null));
  }

  // Book covers and page edges, always luma's own: tinted per book.
  function leather() {
    const r = rng('leather');
    return paint(16, 16, (x, y) => {
      let f = 0.86 + r() * 0.12;
      if (y === 0 || y === 15) f = 0.7;
      if (y === 2 || y === 13) f = 1.08;
      return [clamp(255 * f), clamp(255 * f), clamp(255 * f), 255];
    });
  }

  function pages() {
    const r = rng('pages');
    return paint(16, 16, (x, y) => {
      if (x === 0 || x === 15) return [150, 110, 80, 255];
      const f = y % 2 ? 0.9 : 1;
      return shade([236, 226, 198], f * (0.96 + r() * 0.06));
    });
  }

  function solid() {
    return paint(16, 16, () => [255, 255, 255, 255]);
  }

  // Lime plaster, faintly mottled.
  function plaster(name) {
    const r = rng(name);
    return paint(16, 16, () => shade([222, 218, 206], 0.93 + r() * 0.07));
  }

  function door(top) {
    const wood = planks('door', SPRUCE).getContext('2d').getImageData(0, 0, 16, 16).data;
    return paint(16, 16, (x, y) => {
      const o = (y * 16 + x) * 4;
      const c = [wood[o], wood[o + 1], wood[o + 2], 255];
      if (top && y >= 3 && y <= 8 && x >= 3 && x <= 12) {
        if (x === 7 || x === 8 || y === 5 || y === 6) return shade(c, 0.7);
        return [180, 210, 220, 90];
      }
      if (x <= 1 || x >= 14 || (top ? y <= 1 : y >= 14)) return shade(c, 0.78);
      if (!top && x === 12 && y === 1) return [196, 160, 70, 255];
      return c;
    });
  }

  function ladder() {
    const r = rng('ladder');
    return paint(16, 16, (x, y) => {
      if (x === 2 || x === 3 || x === 12 || x === 13) return shade(SPRUCE.concat(255), x % 2 ? 0.8 : 1);
      if ((y % 4 === 1 || y % 4 === 2) && x > 3 && x < 12) return shade(SPRUCE.concat(255), (y % 4 === 1 ? 1.1 : 0.85) * (0.95 + r() * 0.1));
      return null;
    });
  }

  function vine() {
    const r = rng('vine');
    return paint(16, 16, (x, y) => {
      const stem = Math.abs(x - (6 + Math.round(Math.sin(y * 0.6) * 3))) < 1;
      if (stem) return shade([112, 52, 30], 0.9);
      return r() < 0.3 ? shade([150, 60, 32], 0.75 + r() * 0.4) : null;
    });
  }

  function landscape(side) {
    const r = rng('painting' + side);
    return paint(16, 16, (x, y) => {
      const gx = x + side * 16;
      if (y === 0 || y === 15 || (side === 0 && x === 0) || (side === 1 && x === 15)) return [92, 62, 34, 255];
      const hill = 10 + Math.round(Math.sin(gx * 0.25) * 2 + Math.sin(gx * 0.11 + 1) * 1.5);
      if (y > hill) return shade([86, 118, 52], 0.85 + r() * 0.2);
      if (side === 1 && (x - 6) ** 2 + (y - 5) ** 2 < 6) return [250, 204, 110, 255];
      return shade(y < 5 ? [120, 150, 196] : [214, 170, 132], 0.95 + r() * 0.08);
    });
  }

  // ── The island ─────────────────────────────────────────────────────────
  function speckled(name, base, spots) {
    const r = rng(name);
    return paint(16, 16, () => {
      const roll = r();
      for (const [p, c] of spots) if (roll < p) return shade(c, 0.9 + r() * 0.2);
      return shade(base, 0.9 + r() * 0.14);
    });
  }

  function ore(name, fleck) {
    const r = rng(name);
    const stone = pixels(PAINTERS.stone());
    const blobs = Array.from({length: 4}, () => [2 + r() * 12, 2 + r() * 12]);
    return paint(16, 16, (x, y) => {
      const near = blobs.some(([bx, by]) => Math.abs(x - bx) + Math.abs(y - by) < 1.8);
      return near && r() < 0.8 ? shade(fleck, 0.8 + r() * 0.4) : at(stone, x, y);
    });
  }

  // The grass fringe down a block's side, grey so it can take the season's
  // colour like the game's biome tint.
  function grassOverlay() {
    const r = rng('grass_overlay');
    const drip = Array.from({length: 16}, () => 2 + Math.floor(r() * 3) + (r() < 0.25 ? 2 : 0));
    return paint(16, 16, (x, y) => (y < drip[x] ? shade([170, 170, 170], 0.85 + r() * 0.3) : null));
  }

  function pathTop() { return speckled('path_top', [150, 122, 74], [[0.12, [120, 96, 58]], [0.2, [170, 142, 92]]]); }
  function pathSide() {
    const r = rng('path_side');
    const dirt = pixels(PAINTERS.dirt());
    return paint(16, 16, (x, y) => (y === 0 ? null : y < 3 ? shade([150, 122, 74], 0.9 + r() * 0.15) : at(dirt, x, y)));
  }

  // A scatter of fallen leaves, grey so each patch takes its own colour.
  function leafLitter() {
    const r = rng('leaf_litter');
    const leaves = Array.from({length: 12}, () => [Math.floor(r() * 15), Math.floor(r() * 15), 0.75 + r() * 0.4]);
    return paint(16, 16, (x, y) => {
      for (const [lx, ly, f] of leaves) if ((x === lx || x === lx + 1) && (y === ly || (y === ly + 1 && x === lx))) return shade([190, 190, 190], f);
      return null;
    });
  }

  function birchLog() {
    const r = rng('birch');
    const marks = Array.from({length: 7}, () => [Math.floor(r() * 16), Math.floor(r() * 16), 1 + Math.floor(r() * 4)]);
    return paint(16, 16, (x, y) => {
      for (const [mx, my, w] of marks) if (y === my && x >= mx && x < mx + w) return shade([42, 40, 36], 0.9 + r() * 0.2);
      return shade([216, 214, 204], 0.9 + r() * 0.12);
    });
  }

  function pumpkin(face) {
    const r = rng('pumpkin' + face);
    return paint(16, 16, (x, y) => {
      if (face === 'top') {
        const d = Math.max(Math.abs(x - 7.5), Math.abs(y - 7.5));
        if (d < 1.6) return shade([92, 70, 30], 0.9 + r() * 0.2);
        return shade([214, 124, 26], (Math.floor(d) % 3 === 0 ? 0.82 : 1) * (0.92 + r() * 0.1));
      }
      const ridge = x % 4 === 0 ? 0.8 : x % 4 === 2 ? 1.08 : 1;
      let c = shade([214, 124, 26], ridge * (0.92 + r() * 0.1));
      if (face === 'carved' || face === 'lit') {
        const eye = (y >= 4 && y <= 6) && ((x >= 3 && x <= 5) || (x >= 10 && x <= 12));
        const mouth = (y === 10 && x >= 3 && x <= 12) || (y === 11 && x >= 4 && x <= 11 && x % 3 !== 0);
        if (eye || mouth) c = face === 'lit' ? shade([255, 214, 90], 0.95 + r() * 0.1) : [44, 26, 10, 255];
      }
      return c;
    });
  }

  function hay(top) {
    const r = rng('hay' + top);
    return paint(16, 16, (x, y) => {
      if (top) return shade([196, 160, 44], ((x + y * 3) % 5 === 0 ? 0.78 : 1) * (0.9 + r() * 0.15));
      if (y === 3 || y === 12) return shade([128, 40, 26], 0.9 + r() * 0.15);
      return shade([204, 168, 48], (x % 3 === 0 ? 0.84 : 1) * (0.9 + r() * 0.12));
    });
  }

  function tuft(name, color, blades) {
    const r = rng(name);
    const stems = Array.from({length: blades}, () => [1 + Math.floor(r() * 14), 4 + Math.floor(r() * 9), r() < 0.5 ? -1 : 1]);
    return paint(16, 16, (x, y) => {
      for (const [sx, top, lean] of stems) {
        if (y < top) continue;
        const bend = Math.round((15 - y) / 5) * lean;
        if (x === sx + bend) return shade(color, 0.75 + (15 - y) * 0.03);
      }
      return null;
    });
  }

  function mushroom(cap, spots) {
    return paint(16, 16, (x, y) => {
      if (y >= 10 && x >= 7 && x <= 8) return [214, 206, 186, 255];
      if (y >= 5 && y < 10 && Math.abs(x - 7.5) < (y - 3) * 0.9) {
        if (spots && ((x + y) % 4 === 0) && y < 8) return [240, 236, 226, 255];
        return shade(cap, y === 9 ? 0.75 : 1);
      }
      return null;
    });
  }

  function roots() {
    const r = rng('roots');
    const strands = Array.from({length: 7}, () => [1 + Math.floor(r() * 14), 6 + Math.floor(r() * 10)]);
    return paint(16, 16, (x, y) => {
      for (const [sx, len] of strands) if (y < len && x === sx + Math.round(Math.sin(y * 0.7 + sx) * 0.8)) return shade([120, 86, 58], 0.8 + r() * 0.3);
      return null;
    });
  }

  function deadBush() {
    const r = rng('dead_bush');
    return paint(16, 16, (x, y) => {
      const trunk = x === 8 && y > 9;
      const twig = (y > 3 && y < 12) && (Math.abs(x - 8 - (11 - y) * 0.9) < 0.6 || Math.abs(x - 8 + (11 - y) * 0.7) < 0.6);
      return trunk || twig ? shade([134, 96, 50], 0.8 + r() * 0.3) : null;
    });
  }

  // Textures luma always draws itself, some from a base texture it was
  // given, so they sit with whichever look is in use.
  const pixels = c => c.getContext('2d').getImageData(0, 0, 16, 16).data;
  const at = (d, x, y) => { const o = (y * 16 + x) * 4; return [d[o], d[o + 1], d[o + 2], 255]; };

  function cabinetDoor(base) {
    const d = pixels(base);
    return paint(16, 16, (x, y) => {
      const c = at(d, x, y);
      if (x === 0 || x === 15) return shade(c, 0.55);
      if (y === 0) return shade(c, 1.15);
      if (y === 15) return shade(c, 0.5);
      const inPanel = x >= 3 && x <= 12 && y >= 3 && y <= 12;
      if (x === 2 && y >= 2 && y <= 13 || y === 2 && x >= 2 && x <= 13) return shade(c, 0.7);
      if (x === 13 && y >= 2 && y <= 13 || y === 13 && x >= 2 && x <= 13) return shade(c, 1.2);
      if ((x === 7 || x === 8) && y === 7) return [210, 172, 84, 255];
      return shade(c, inPanel ? 0.9 : 1);
    });
  }

  // A woven runner: a diamond lattice in madder red with cream and brown.
  function rug(name, ground, line, accent) {
    const r = rng(name);
    return paint(16, 16, (x, y) => {
      const dx = Math.abs(((x + 8) % 16) - 7.5), dy = Math.abs(((y + 8) % 16) - 7.5);
      const d = dx + dy;
      let c = ground;
      if (Math.abs(d - 7) < 1) c = line;
      else if (d < 2.5) c = accent;
      else if (Math.abs(d - 4.5) < 0.6) c = shade(ground, 0.8);
      return shade(c, 0.9 + r() * 0.12);
    });
  }

  // Carpet tiles, one block each, so a rug always lines up with the floor:
  // a centre tile with one diamond, an edge tile with the border along its
  // top, and a corner tile with it along the top and left. The rug turns
  // edge and corner tiles to face outward; the diamond is symmetric, so
  // the lattice runs on unbroken from tile to tile.
  function rugTile(name, kind, c) {
    const r = rng(name + kind);
    return paint(16, 16, (x, y) => {
      const band = kind === 'center' ? 99 : kind === 'edge' ? y : Math.min(x, y);
      const along = kind === 'corner' ? (x < y ? y : x) : x;
      let col;
      if (band === 0) col = c.dark;
      else if (band < 4) col = (along + band) % 4 === 0 ? c.line : c.border;
      else if (band === 4) col = c.line;
      else {
        const d = Math.abs(x - 7.5) + Math.abs(y - 7.5);
        if (Math.abs(d - 7) < 0.6) col = c.line;
        else if (d < 2.2) col = c.accent;
        else if (Math.abs(d - 4.2) < 0.6) col = shade(c.ground, 0.78);
        else col = c.ground;
      }
      return shade(col, 0.92 + r() * 0.1);
    });
  }
  const RUGS = {
    red: {ground: [140, 40, 32, 255], line: [226, 204, 156, 255], accent: [62, 44, 34, 255], border: [84, 44, 30, 255], dark: [46, 28, 20, 255]},
    green: {ground: [60, 88, 52, 255], line: [214, 194, 146, 255], accent: [150, 58, 38, 255], border: [44, 58, 36, 255], dark: [30, 36, 24, 255]},
    rust: {ground: [168, 88, 38, 255], line: [236, 208, 150, 255], accent: [96, 44, 30, 255], border: [110, 56, 30, 255], dark: [58, 32, 20, 255]},
  };

  function rugBorder(name, ground, line) {
    const r = rng(name);
    return paint(16, 16, (x, y) => {
      const c = y === 2 || y === 13 ? line : (y + x) % 4 === 0 && y > 4 && y < 11 ? line : ground;
      return shade(c, 0.9 + r() * 0.12);
    });
  }

  // An open page seen from above: ruled with lines of pale ink.
  function bookPage() {
    const r = rng('page');
    return paint(16, 16, (x, y) => {
      let c = [240, 230, 204, 255];
      if (x === 0 || x === 15) c = [210, 196, 162, 255];
      else if (y % 2 === 1 && y > 1 && y < 15 && x > 1 && x < 14) {
        const end = 13 - Math.floor(rng('line' + y)() * 6);
        if (x <= end && r() < 0.85) c = [150, 140, 128, 255];
      }
      return shade(c, 0.97 + r() * 0.04);
    });
  }

  // Blank leather for the shelves' own books, tinted per book.
  function spineDeco() {
    const r = rng('spine_deco');
    return paint(16, 16, (x, y) => {
      if (y === 2 || y === 13) return [236, 196, 110, 255];
      if (y === 5 && x > 4 && x < 11) return [220, 190, 120, 255];
      const f = x === 0 || x === 15 ? 0.7 : 0.86 + r() * 0.12;
      return [clamp(230 * f), clamp(230 * f), clamp(230 * f), 255];
    });
  }

  function globe() {
    const r = rng('globe');
    const land = (x, y) => Math.sin(x * 0.9) + Math.cos(y * 1.3 + x * 0.4) + Math.sin((x + y) * 0.7) > 0.9;
    return paint(16, 16, (x, y) => (land(x, y) ? shade([96, 140, 64], 0.85 + r() * 0.2) : shade([58, 104, 166], 0.9 + r() * 0.15)));
  }

  function clockFace() {
    return paint(16, 16, (x, y) => {
      const d = Math.hypot(x - 7.5, y - 7.5);
      if (d > 7.6) return [60, 40, 22, 255];
      if (d > 6.8) return [196, 160, 70, 255];
      const a = Math.atan2(y - 7.5, x - 7.5);
      const tick = Math.abs(((a / (Math.PI / 6)) % 1 + 1) % 1 - 0.5) > 0.4;
      if (d > 5.2 && tick) return [50, 40, 34, 255];
      return [238, 228, 200, 255];
    });
  }

  function lampshade() {
    const r = rng('shade');
    return paint(16, 16, (x, y) => shade([236, 206, 150], (y % 4 === 0 ? 0.86 : 1) * (0.94 + r() * 0.08)));
  }

  function teacup() {
    return paint(16, 16, (x, y) => (y < 3 ? [240, 240, 236, 255] : y < 5 ? [70, 104, 160, 255] : [236, 236, 230, 255]));
  }

  // A grass block's side: dirt with the fringe laid over it in the season's
  // colour, as the game tints its overlay by biome.
  function grassSide(dirt, overlay) {
    const d = pixels(dirt), o = overlay.getContext('2d').getImageData(0, 0, 16, 16).data;
    return paint(16, 16, (x, y) => {
      const i = (y * 16 + x) * 4;
      if (o[i + 3] < 128) return at(d, x, y);
      return [clamp(o[i] * GRASS[0]), clamp(o[i + 1] * GRASS[1]), clamp(o[i + 2] * GRASS[2]), 255];
    });
  }

  const DERIVED = {
    cabinet_door: c => cabinetDoor(c.spruce_planks),
    grass_side: c => grassSide(c.dirt, c.grass_block_side_overlay),
    rug_red: () => rug('rug_red', [138, 38, 32, 255], [226, 206, 160, 255], [60, 44, 34, 255]),
    rug_red_border: () => rugBorder('rug_red_b', [70, 40, 28, 255], [210, 170, 90, 255]),
    rug_green: () => rug('rug_green', [58, 86, 52, 255], [214, 196, 150, 255], [140, 48, 36, 255]),
    rug_green_border: () => rugBorder('rug_green_b', [40, 52, 34, 255], [200, 170, 100, 255]),
    ...Object.fromEntries(Object.entries(RUGS).flatMap(([name, c]) => ['center', 'edge', 'corner'].map(kind => [`carpet_${name}_${kind}`, () => rugTile('carpet_' + name, kind, c)]))),
    book_page: bookPage,
    spine_deco: spineDeco,
    globe,
    clock_face: clockFace,
    lampshade,
    teacup,
  };

  const PAINTERS = {
    leather,
    pages,
    solid,
    oak_planks: () => planks('oak_planks', OAK),
    spruce_planks: () => planks('spruce_planks', SPRUCE),
    dark_oak_planks: () => planks('dark_oak_planks', DARK_OAK),
    spruce_log: () => logSide('spruce_log', [58, 40, 22], 0.7),
    spruce_log_top: () => logTop('spruce_log_top', [58, 40, 22], SPRUCE),
    stripped_spruce_log: () => logSide('stripped_spruce_log', [116, 88, 52], 0.85),
    stripped_spruce_log_top: () => logTop('stripped_spruce_top', [116, 88, 52], [128, 96, 58]),
    dark_oak_log: () => logSide('dark_oak_log', [52, 38, 22], 0.7),
    dark_oak_log_top: () => logTop('dark_oak_log_top', [52, 38, 22], DARK_OAK),
    oak_log: () => logSide('oak_log', [104, 82, 50], 0.75),
    stone_bricks: () => stoneBricks('stone_bricks', [124, 124, 124]),
    mossy_stone_bricks: () => stoneBricks('mossy', [118, 120, 112], true),
    cobblestone: () => cobble('cobblestone', [128, 128, 128]),
    polished_andesite: () => wool('andesite', [134, 136, 134]),
    smooth_stone: () => wool('smooth_stone', [160, 160, 160]),
    bricks: () => stoneBricks('bricks', [150, 86, 70]),
    chiseled_bookshelf_empty: () => chiseledFront('chiseled_empty', true),
    chiseled_bookshelf_side: () => chiseledSide('chiseled_side'),
    chiseled_bookshelf_top: () => planks('chiseled_top', OAK),
    bookshelf: () => bookshelf('bookshelf'),
    glass,
    red_wool: () => wool('red_wool', [160, 39, 34]),
    white_wool: () => wool('white_wool', [234, 236, 236]),
    brown_wool: () => wool('brown_wool', [114, 71, 40]),
    white_carpet_sheep: () => wool('white_wool', [234, 236, 236]),
    lantern,
    chain,
    candle: () => candle(false),
    candle_lit: () => candle(true),
    campfire_log: () => campfireLog('campfire_log', false),
    campfire_log_lit: () => campfireLog('campfire_log_lit', true),
    campfire_fire: () => fire('campfire_fire', 16),
    oak_leaves: () => leaves('oak_leaves', [150, 150, 150]),
    spruce_leaves: () => leaves('spruce_leaves', [140, 140, 140]),
    birch_leaves: () => leaves('birch_leaves', [156, 156, 156]),
    azalea_leaves: () => leaves('azalea', [96, 126, 44]),
    grass_block_top: () => grassTop('grass'),
    dirt: () => wool('dirt', [134, 96, 67]),
    flower_pot: flowerPot,
    fern: () => plant('fern', [146, 124, 58]),
    poppy: () => plant('poppy', [60, 110, 40], [200, 40, 30]),
    lectern_top: () => lectern('top'),
    lectern_sides: () => lectern('sides'),
    lectern_base: () => lectern('base'),
    lectern_front: () => lectern('front'),
    barrel_side: () => barrel(false),
    barrel_top: () => barrel(true),
    writable_book: () => itemBook('#7a4a2a', true),
    written_book: () => itemBook('#7a4a2a', false),
    book: () => itemBook('#7a4a2a', false),
    feather,
    ink_sac: inkSac,
    iron_bars: ironBars,
    calcite: () => plaster('calcite'),
    stripped_dark_oak_log: () => logSide('stripped_dark_oak_log', [96, 70, 44], 0.85),
    stripped_dark_oak_log_top: () => logTop('stripped_dark_oak_top', [96, 70, 44], [104, 78, 50]),
    green_wool: () => wool('green_wool', [84, 109, 27]),
    blue_wool: () => wool('blue_wool', [53, 57, 157]),
    light_gray_wool: () => wool('light_gray_wool', [142, 142, 134]),
    yellow_wool: () => wool('yellow_wool', [248, 197, 39]),
    terracotta: () => wool('terracotta', [152, 94, 67]),
    spruce_door_top: () => door(true),
    spruce_door_bottom: () => door(false),
    ladder,
    vine,
    flowering_azalea_leaves: () => leaves('flowering_azalea', [110, 132, 50]),
    painting_left: () => landscape(0),
    painting_right: () => landscape(1),
    painting_small: () => plant('painting_small', [70, 110, 50], [196, 90, 150]),
    stone: () => speckled('stone', [124, 124, 124], [[0.08, [100, 100, 100]], [0.14, [142, 142, 142]]]),
    andesite: () => speckled('andesite', [134, 136, 134], [[0.12, [104, 106, 104]], [0.24, [160, 162, 160]]]),
    coal_ore: () => ore('coal_ore', [36, 36, 36]),
    coarse_dirt: () => speckled('coarse_dirt', [120, 86, 60], [[0.1, [84, 60, 42]], [0.16, [150, 140, 128]]]),
    grass_block_side_overlay: grassOverlay,
    dirt_path_top: pathTop,
    dirt_path_side: pathSide,
    leaf_litter: leafLitter,
    birch_log: birchLog,
    birch_log_top: () => logTop('birch_log_top', [216, 214, 204], [196, 170, 118]),
    pumpkin_side: () => pumpkin('side'),
    pumpkin_top: () => pumpkin('top'),
    carved_pumpkin: () => pumpkin('carved'),
    jack_o_lantern: () => pumpkin('lit'),
    hay_block_side: () => hay(false),
    hay_block_top: () => hay(true),
    short_grass: () => tuft('short_grass', [160, 138, 72], 9),
    red_mushroom: () => mushroom([196, 36, 30], true),
    brown_mushroom: () => mushroom([150, 108, 76], false),
    hanging_roots: roots,
    dead_bush: deadBush,
  };

  // The season. Grass and ferns are grey in the jar and coloured by the
  // biome in game; here they take autumn's gold, and the vines turn red.
  // Tree leaves stay grey in the atlas and get a colour per tree instead.
  const GRASS = [0.78, 0.7, 0.36];
  const TINT = {
    grass_block_top: GRASS,
    fern: [0.74, 0.62, 0.3],
    short_grass: [0.8, 0.7, 0.38],
    vine: [0.76, 0.34, 0.16],
  };

  // Some sheets are cut down: a painting split into one-block halves, and
  // the lantern held on its first frame so its glow stays steady.
  const CROP = {lantern: [0, 0, 1, 1 / 3]};

  function tinted(image, tint, crop) {
    const canvas = document.createElement('canvas');
    const [fx, fy, fw, fh] = crop || [0, 0, 1, 1];
    const sx = Math.round(image.width * fx), sy = Math.round(image.height * fy);
    const sw = Math.round(image.width * fw), sh = Math.round(image.height * fh);
    canvas.width = sw; canvas.height = sh;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(image, sx, sy, sw, sh, 0, 0, sw, sh);
    if (!tint) return canvas;
    const data = ctx.getImageData(0, 0, canvas.width, canvas.height);
    for (let i = 0; i < data.data.length; i += 4) {
      data.data[i] *= tint[0]; data.data[i + 1] *= tint[1]; data.data[i + 2] *= tint[2];
    }
    ctx.putImageData(data, 0, 0);
    return canvas;
  }

  function loadImage(src) {
    return new Promise(resolve => {
      const image = new Image();
      image.onload = () => resolve(image);
      image.onerror = () => resolve(null);
      image.src = src;
    });
  }

  // Resolves every texture to a canvas (frames stacked vertically), vanilla
  // where given.
  async function resolve(files) {
    const out = {};
    const vanilla = {};
    for (const name of Object.keys(PAINTERS)) {
      const path = pathOf(LIST[name]);
      let path2 = path;
      if (name === 'chain' && !files[path] && files['textures/block/chain.png']) path2 = 'textures/block/chain.png';
      if (path2 && files[path2]) {
        const image = await loadImage('data:image/png;base64,' + files[path2]);
        if (image && image.width >= 16) {
          out[name] = tinted(image, TINT[name], LIST[name]?.crop || CROP[name]);
          vanilla[name] = true;
          continue;
        }
      }
      out[name] = PAINTERS[name]();
    }
    for (const [name, make] of Object.entries(DERIVED)) out[name] = make(out);
    return {canvases: out, vanilla};
  }

  // Frame timing from a .mcmeta, in game ticks (20 per second).
  function frameTime(files, path, fallback) {
    try {
      const meta = JSON.parse(atob(files[path + '.mcmeta']));
      return meta.animation?.frametime || fallback;
    } catch {
      return fallback;
    }
  }

  // Packs every texture into one power-of-two atlas. Each 16×16 frame gets a
  // 32×32 cell with its edge pixels repeated outward, so mipmaps never bleed
  // one texture into its neighbour.
  function buildAtlas(canvases, files) {
    const CELL = 32, PAD = 8;
    const entries = [];
    for (const [name, canvas] of Object.entries(canvases)) {
      const size = canvas.width;
      const frames = Math.max(1, Math.floor(canvas.height / size));
      entries.push({name, canvas, size, frames});
    }
    const totalCells = entries.reduce((s, e) => s + e.frames, 0);
    let cols = 1;
    while (cols * cols < totalCells) cols *= 2;
    let rows = Math.ceil(totalCells / cols);
    let pot = 1;
    while (pot < rows) pot *= 2;
    rows = pot;
    const atlas = document.createElement('canvas');
    atlas.width = cols * CELL; atlas.height = rows * CELL;
    const ctx = atlas.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    const index = {};
    let cell = 0;
    for (const e of entries) {
      const first = cell;
      for (let f = 0; f < e.frames; f++, cell++) {
        const cx = (cell % cols) * CELL, cy = Math.floor(cell / cols) * CELL;
        const sx = 0, sy = f * e.size;
        // Centre, then smear the edges out into the padding.
        ctx.drawImage(e.canvas, sx, sy, e.size, e.size, cx + PAD, cy + PAD, 16, 16);
        ctx.drawImage(atlas, cx + PAD, cy + PAD, 1, 16, cx, cy + PAD, PAD, 16);
        ctx.drawImage(atlas, cx + PAD + 15, cy + PAD, 1, 16, cx + PAD + 16, cy + PAD, PAD, 16);
        ctx.drawImage(atlas, cx, cy + PAD, CELL, 1, cx, cy, CELL, PAD);
        ctx.drawImage(atlas, cx, cy + PAD + 15, CELL, 1, cx, cy + PAD + 16, CELL, PAD);
      }
      index[e.name] = {cell: first, frames: e.frames, cols, frameTime: 1};
    }
    if (index.campfire_fire) index.campfire_fire.frameTime = frameTime(files, LIST.campfire_fire, 2);
    if (index.lantern && index.lantern.frames > 1) index.lantern.frameTime = frameTime(files, LIST.lantern, 8);
    return {canvas: atlas, index, cols, rows, cell: CELL, pad: PAD};
  }

  window.LibraryTextures = {
    wanted: () => [...new Set([...Object.values(LIST).map(pathOf), ...EXTRA])],
    resolve,
    buildAtlas,
    paint,
    rng,
  };
})();
