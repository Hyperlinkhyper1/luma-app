// The reader's Minecraft skin, and the two models made from it: the arm
// seen in first person, as in the game, and the whole player sitting at the
// desk while a book is being written.
//
// A skin is the game's 64×64 sheet (or the old 64×32 one, or an HD multiple
// of either). With none imported the hall uses Steve from the reader's own
// Minecraft jar, and without a jar a plain look-alike painted here — luma
// never ships Mojang's sheets.
(() => {
  'use strict';
  const {addBox, MeshBuilder} = window.LibraryWorld;

  // ── Loading ────────────────────────────────────────────────────────────
  // Turns any skin image into a square sheet in the modern layout. Old
  // 64×32 skins have no left limbs; the game mirrors the right ones across,
  // face by face, and so does this.
  function normalize(image) {
    const size = image.width;
    const canvas = document.createElement('canvas');
    canvas.width = size; canvas.height = size;
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    if (image.height * 2 === image.width) {
      ctx.drawImage(image, 0, 0);
      const s = size / 64;
      const copy = (x, y, dx, dy, w, h) => {
        ctx.save();
        ctx.translate((x + dx + w) * s, (y + dy) * s);
        ctx.scale(-1, 1);
        ctx.drawImage(canvas, x * s, y * s, w * s, h * s, 0, 0, w * s, h * s);
        ctx.restore();
      };
      for (const [x, y, dx, dy, w, h] of [
        [4, 16, 16, 32, 4, 4], [8, 16, 16, 32, 4, 4], [0, 20, 24, 32, 4, 12], [4, 20, 16, 32, 4, 12], [8, 20, 8, 32, 4, 12], [12, 20, 16, 32, 4, 12],
        [44, 16, -8, 32, 4, 4], [48, 16, -8, 32, 4, 4], [40, 20, 0, 32, 4, 12], [44, 20, -8, 32, 4, 12], [48, 20, -16, 32, 4, 12], [52, 20, -8, 32, 4, 12],
      ]) copy(x, y, dx, dy, w, h);
    } else {
      ctx.drawImage(image, 0, 0, size, size);
    }
    return canvas;
  }

  // Slim ("Alex") arms are three pixels wide, which leaves the last two
  // columns of the right arm's back face empty.
  function isSlim(canvas) {
    const s = canvas.width / 64;
    const px = canvas.getContext('2d').getImageData(Math.floor(54.5 * s), Math.floor(25 * s), 1, 1).data;
    return px[3] === 0;
  }

  function load(base64) {
    return new Promise(resolve => {
      const image = new Image();
      image.onload = () => {
        const ok = image.width >= 64 && image.width % 64 === 0 && (image.height === image.width || image.height * 2 === image.width);
        if (!ok) { resolve(null); return; }
        const canvas = normalize(image);
        resolve({canvas, slim: isSlim(canvas)});
      };
      image.onerror = () => resolve(null);
      image.src = 'data:image/png;base64,' + base64;
    });
  }

  // luma's own default: brown hair, a teal jumper, dark trousers.
  function painted() {
    const canvas = document.createElement('canvas');
    canvas.width = 64; canvas.height = 64;
    const ctx = canvas.getContext('2d');
    const r = LibraryTextures.rng('skin');
    const fill = (x, y, w, h, c, vary = 0.08) => {
      for (let i = 0; i < w; i++) for (let j = 0; j < h; j++) {
        const f = 1 - vary / 2 + r() * vary;
        ctx.fillStyle = `rgb(${Math.round(c[0] * f)},${Math.round(c[1] * f)},${Math.round(c[2] * f)})`;
        ctx.fillRect(x + i, y + j, 1, 1);
      }
    };
    const SKIN = [222, 170, 132], HAIR = [92, 58, 34], SHIRT = [46, 128, 120], PANTS = [52, 58, 92], SHOE = [70, 64, 60];
    // Head: skin all round, hair over the top, back and upper sides.
    fill(0, 0, 32, 16, SKIN);
    fill(8, 0, 8, 8, HAIR); fill(0, 8, 8, 3, HAIR); fill(16, 8, 8, 3, HAIR); fill(24, 8, 8, 8, HAIR); fill(8, 8, 8, 2, HAIR);
    fill(0, 11, 2, 2, HAIR); fill(22, 11, 2, 2, HAIR);
    fill(9, 12, 2, 1, [250, 250, 250], 0); fill(13, 12, 2, 1, [250, 250, 250], 0);
    fill(10, 12, 1, 1, [60, 90, 150], 0); fill(13, 12, 1, 1, [60, 90, 150], 0);
    fill(11, 14, 2, 1, [170, 110, 90], 0);
    // Body, arms and legs.
    fill(16, 16, 24, 16, SHIRT);
    fill(40, 16, 16, 16, SHIRT); fill(40, 28, 16, 4, SKIN); fill(44, 16, 4, 4, SHIRT);
    fill(32, 48, 16, 16, SHIRT); fill(32, 60, 16, 4, SKIN);
    fill(0, 16, 16, 16, PANTS); fill(0, 29, 16, 3, SHOE);
    fill(16, 48, 16, 16, PANTS); fill(16, 61, 16, 3, SHOE);
    return {canvas, slim: false};
  }

  // ── Models ─────────────────────────────────────────────────────────────
  // Where each part's faces sit on the sheet: a box `size` = [w, h, d]
  // pixels starting at `uv`, laid out as the game unfolds it.
  function faces(uv, [w, h, d]) {
    const [u, v] = uv;
    const rect = (u0, v0, u1, v1) => ({tex: 'solid', labelKind: 2, labelUv: [[u0 / 64, v0 / 64], [u0 / 64, v1 / 64], [u1 / 64, v1 / 64], [u1 / 64, v0 / 64]]});
    return {
      north: rect(u + 2 * d + w, v + d, u + 2 * d + 2 * w, v + d + h),
      south: rect(u + d, v + d, u + d + w, v + d + h),
      west: rect(u, v + d, u + d, v + d + h),
      east: rect(u + d + w, v + d, u + 2 * d + w, v + d + h),
      up: rect(u + d, v, u + d + w, v + d),
      down: rect(u + d + w, v, u + d + 2 * w, v + d),
    };
  }

  // The parts of a player facing +z (so its right side is -x), each box
  // relative to its pivot, in pixels, feet at y 0.
  function parts(slim) {
    const a = slim ? 3 : 4;
    return {
      head: {pivot: [0, 24, 0], from: [-4, 0, -4], size: [8, 8, 8], uv: [0, 0], over: [32, 0], grow: 0.5},
      body: {pivot: [0, 12, 0], from: [-4, 0, -2], size: [8, 12, 4], uv: [16, 16], over: [16, 32], grow: 0.25},
      rightArm: {pivot: [-5, 22, 0], from: [-a + 1, -10, -2], size: [a, 12, 4], uv: [40, 16], over: [40, 32], grow: 0.25},
      leftArm: {pivot: [5, 22, 0], from: [-1, -10, -2], size: [a, 12, 4], uv: [32, 48], over: [48, 48], grow: 0.25},
      rightLeg: {pivot: [-1.9, 12, 0], from: [-2, -12, -2], size: [4, 12, 4], uv: [0, 16], over: [0, 32], grow: 0.25},
      leftLeg: {pivot: [1.9, 12, 0], from: [-2, -12, -2], size: [4, 12, 4], uv: [16, 48], over: [0, 48], grow: 0.25},
    };
  }

  // One part as a mesh round its pivot: the base box and the outer layer
  // just outside it.
  function partGeometry(T, grid, atlas, p, light) {
    const mb = new MeshBuilder();
    const to = [p.from[0] + p.size[0], p.from[1] + p.size[1], p.from[2] + p.size[2]];
    addBox(mb, grid, atlas, [0, 0, 0], p.from, to, faces(p.uv, p.size), {light, ao: 1});
    const g = p.grow;
    addBox(mb, grid, atlas, [0, 0, 0], p.from.map(v => v - g), to.map(v => v + g), faces(p.over, p.size), {light, ao: 1});
    return mb.geometry(T);
  }

  // The whole player, `scale` blocks per model block. Returns the group
  // and its limbs by name so they can be posed.
  function player(T, grid, atlas, slim, material, light, scale = 0.94) {
    const group = new T.Group();
    const limbs = {};
    for (const [name, p] of Object.entries(parts(slim))) {
      const pivot = new T.Group();
      pivot.position.set(p.pivot[0] / 16, p.pivot[1] / 16, p.pivot[2] / 16);
      const mesh = new T.Mesh(partGeometry(T, grid, atlas, p, light), material);
      mesh.userData.noShadow = false;
      pivot.add(mesh);
      group.add(pivot);
      limbs[name] = pivot;
    }
    group.scale.setScalar(scale);
    return {group, limbs};
  }

  // The right arm alone, round its shoulder, for the first-person view.
  function arm(T, grid, atlas, slim, material, light) {
    const p = parts(slim).rightArm;
    const pivot = new T.Group();
    const mesh = new T.Mesh(partGeometry(T, grid, atlas, p, light), material);
    mesh.frustumCulled = false;
    pivot.add(mesh);
    return {pivot, mesh};
  }

  // Refreshes a built model's light, for when it moves somewhere brighter
  // or darker.
  function relight(object, light) {
    object.traverse(o => {
      const attr = o.geometry?.attributes?.light;
      if (!attr) return;
      for (let i = 0; i < attr.count; i++) attr.setXYZ(i, light[0], light[1], light[2]);
      attr.needsUpdate = true;
    });
  }

  window.LibrarySkin = {load, painted, normalize, isSlim, player, arm, relight};
})();
