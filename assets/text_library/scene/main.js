// The Minecraft library: ties the hall, the books and the book editor to the
// app. The app owns the data; this page only draws it and sends back what
// the user did.
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const canvas = $('view');

  const outbox = [];
  let demo = null;
  let started = false;
  // Android's bridge drops calls made before it reports ready, so those wait
  // in the outbox. If the event fired before this script ran, a short grace
  // period stands in for it.
  let androidReady = false;
  function fail(message) {
    const box = $('error');
    box.hidden = false;
    box.textContent = String(message);
    send({type: 'error', message: String(message)});
  }
  addEventListener('error', e => { if (started) console.error(e.error || e.message); else fail(e.message); });

  const T = window.THREE;
  if (!T || !window.LibraryWorld || !window.PixelFont || !window.LibraryRender) {
    fail('A bundled scene asset is missing.');
    return;
  }
  const W = LibraryWorld, gui = LibraryGui, Book = LibraryBook;

  // ── Bridge ─────────────────────────────────────────────────────────────
  function transport() {
    if (window.chrome?.webview) return m => window.chrome.webview.postMessage(JSON.stringify(m));
    if (window.flutter_inappwebview) {
      if (!androidReady || !window.flutter_inappwebview.callHandler) return null;
      return m => window.flutter_inappwebview.callHandler('library', m);
    }
    if (demo) return m => demo.handle(m);
    return null;
  }
  function send(message) {
    const out = transport();
    if (out) out(message);
    else outbox.push(message);
  }
  function flush() {
    const out = transport();
    if (!out) return;
    while (outbox.length) out(outbox.shift());
  }
  addEventListener('flutterInAppWebViewPlatformReady', () => { androidReady = true; flush(); });
  setTimeout(() => { androidReady = true; flush(); }, 1500);

  let seq = 0;
  const pending = new Map();
  function request(message) {
    return new Promise((resolve, reject) => {
      const id = ++seq;
      pending.set(id, {resolve, reject});
      send({...message, request: id});
      setTimeout(() => {
        if (!pending.has(id)) return;
        pending.delete(id);
        reject(new Error('timeout'));
      }, 20000);
    });
  }

  function receive(raw) {
    let m;
    try { m = typeof raw === 'string' ? JSON.parse(raw) : raw; } catch { return; }
    if (!m || typeof m !== 'object') return;
    try {
      switch (m.type) {
        case 'init':
          gui.setStrings(m.strings);
          $('time').textContent = timeLabel();
          if (m.reducedMotion) S.reducedMotion = true;
          refreshHud();
          break;
        case 'view':
          S.visible = m.visible !== false;
          if (S.visible) loop.wake();
          break;
        case 'library': onLibrary(m.subjects || []); break;
        case 'assets':
          onAssets(m).catch(error => {
            console.error('Library assets failed', error);
            if (Object.keys(m.files || {}).length) {
              onAssets({files: {}}).catch(fallbackError => {
                console.error('Built-in library assets failed', fallbackError);
                fail(fallbackError?.message || String(fallbackError));
              });
            } else {
              fail(error?.message || String(error));
            }
          });
          break;
        case 'saved': pending.get(m.request)?.resolve(m.id); pending.delete(m.request); break;
        case 'failed': pending.get(m.request)?.reject(new Error(m.message || 'failed')); pending.delete(m.request); break;
        case 'download': {
          const bar = $('download-progress');
          bar.hidden = false;
          bar.firstElementChild.style.width = `${Math.round((m.fraction ?? 0) * 100)}%`;
          $('texture-source').textContent = m.stage || '';
          break;
        }
        case 'downloadDone':
          $('download-progress').hidden = true;
          send({type: 'assetsWanted', paths: LibraryTextures.wanted()});
          break;
        case 'downloadFailed':
          $('download-progress').hidden = true;
          $('download').disabled = false;
          $('texture-source').textContent = gui.t('downloadFailed');
          break;
      }
    } catch (e) {
      console.error(e);
    }
  }
  window.libraryReceive = receive;
  window.chrome?.webview?.addEventListener('message', e => receive(e.data));

  // ── State ──────────────────────────────────────────────────────────────
  const S = {
    subjects: [],
    built: null,
    mode: 'loading',
    caseIndex: -1,
    caseSubject: null,
    pages: new Map(),
    hidden: new Set(),
    editing: null,
    // Where the reader stands and looks while walking the hall.
    px: 0, pz: 4.2, yaw: 0, pitch: 0.02, vel: [0, 0], stride: 0, goal: null,
    // The bookcase view: sideways pan, height pan and zoom.
    pan: 0, panY: 0, zoom: 1,
    timeMode: 'cycle', hour: 12, shownHour: 12,
    visible: true,
    reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches,
    quality: 'fancy',
    source: null,
    vanilla: false,
    pendingSubject: null,
    firstLibrary: false,
    assetsReady: false,
  };
  try { S.quality = localStorage.getItem('library.quality') || (/Android/.test(navigator.userAgent) ? 'fast' : 'fancy'); } catch { /* storage blocked */ }
  try { S.timeMode = localStorage.getItem('library.time') || 'cycle'; } catch { /* storage blocked */ }
  {
    const now = new Date();
    S.hour = S.shownHour = now.getHours() + now.getMinutes() / 60;
  }

  // ── Renderer ───────────────────────────────────────────────────────────
  let R;
  try { R = LibraryRender.create(T, canvas); } catch (e) { fail(e.message); return; }
  const {scene, camera, U} = R;
  const blockMat = R.blockMaterial();
  const dynMat = R.blockMaterial();
  const heldMat = R.blockMaterial();
  const ghostMat = R.blockMaterial({transparent: true, depthWrite: false});
  ghostMat.uniforms.opacity.value = 0.45;
  // A faint cyan like a structure preview, so it reads as "build here".
  ghostMat.uniforms.highlight.value.setRGB(0.25, 0.55, 0.7);
  let labels = null;
  let atlas = null, canvases = null;

  const QUALITY = {
    fancy: {msaa: 4, bloom: true, volume: true, dof: true, shadowSize: 2048, volumeSteps: 20, scale: 1},
    fast: {msaa: 0, bloom: true, volume: false, dof: false, shadowSize: 1024, volumeSteps: 0, scale: 1},
  };
  function pixelRatio() { return S.quality === 'fancy' ? Math.min(devicePixelRatio || 1, 2) : Math.min(devicePixelRatio || 1, 1); }
  function applyQuality() {
    Object.assign(R.settings, QUALITY[S.quality]);
    R.applySettings({});
    R.resize(innerWidth, innerHeight, pixelRatio());
    shadowDirty = true;
    $('quality').textContent = `${gui.t('quality')}: ${gui.t(S.quality === 'fancy' ? 'qualityHigh' : 'qualityLow')}`;
    particles.dust.mesh.visible = S.quality === 'fancy';
  }

  // ── Scene objects ──────────────────────────────────────────────────────
  let worldMesh = null, glassMesh = null, dynMesh = null, ghostMesh = null;
  let shadowDirty = true;

  const outline = new T.LineSegments(
    new T.EdgesGeometry(new T.BoxGeometry(1, 1, 1)),
    new T.LineBasicMaterial({color: 0x000000, transparent: true, opacity: 0.55, depthTest: true}),
  );
  outline.visible = false;
  outline.userData.noShadow = true;
  scene.add(outline);

  const slotHi = new T.Mesh(new T.PlaneGeometry(1, 1), new T.MeshBasicMaterial({color: 0xffffff, transparent: true, opacity: 0.28, depthWrite: false}));
  slotHi.visible = false;
  slotHi.userData.noShadow = true;
  scene.add(slotHi);

  // The book being carried: built once per book at the origin, moved by
  // its transform.
  const held = {mesh: null, book: null, from: null};
  function makeHeld(book) {
    if (held.mesh) { scene.remove(held.mesh); held.mesh.geometry.dispose(); }
    const mb = new W.MeshBuilder();
    W.addBookAt(mb, S.built.grid, atlas, book, labels, [0, 0, 0], 1, {light: [0.55, 0.85, 0.2]});
    labels.flush();
    held.mesh = new T.Mesh(mb.geometry(T), heldMat);
    held.mesh.userData.noShadow = true;
    held.book = book;
    scene.add(held.mesh);
    return held.mesh;
  }
  function dropHeld() {
    hideDeskBook();
    if (!held.mesh) return;
    scene.remove(held.mesh);
    held.mesh.geometry.dispose();
    held.mesh = null;
    held.book = null;
  }

  // ── The open book on the desk ──────────────────────────────────────────
  // While a book is being written it lies open on the desk: two halves
  // hinged at the spine, each a cover board with a block of pages on it.
  // Closed, the left half folds onto the right and matches the carried
  // book laid flat, so one can be swapped for the other.
  const DESK_SCALE = 0.62;
  const deskBook = {group: null, left: null, right: null, open: 0, target: 0, dims: null};

  function deskBookSize(book) {
    const d = W.bookDims(book);
    return {hw: d.d * DESK_SCALE, hh: d.h * DESK_SCALE / 2, t: Math.max(0.03, d.w * DESK_SCALE / 2)};
  }

  function makeDeskBook(book) {
    disposeDeskBook();
    const {hw, hh, t} = deskBookSize(book);
    const tint = W.coverTint(book.cover ?? 12);
    const desk = S.built.desk;
    const light = S.built.grid.sample([0, desk.top + 0.35, desk.z], [0, 1, 0]);
    const cover = {tex: 'leather', tint};
    const pages = {tex: 'pages', ao: 0.9};
    const half = sign => {
      const mb = new W.MeshBuilder();
      const K = {mb, grid: S.built.grid, atlas, light};
      const x0 = sign > 0 ? 0 : -hw, x1 = sign > 0 ? hw : 0;
      const yb = sign > 0 ? 0 : -t;
      const board = 0.014;
      W.box(K, [x0, yb, -hh], [x1, yb + board, hh], {up: cover, down: cover, north: cover, south: cover, east: cover, west: cover});
      const inset = 0.012;
      const px0 = sign > 0 ? 0.004 : -hw + inset, px1 = sign > 0 ? hw - inset : -0.004;
      const outer = sign > 0 ? 'east' : 'west';
      W.box(K, [px0, yb + board, -hh + inset], [px1, yb + t, hh - inset], {
        up: {tex: 'book_page', uv: sign > 0 ? [0, 0, 16, 16] : [16, 0, 0, 16]}, north: pages, south: pages, [outer]: pages,
      });
      if (sign > 0) W.box(K, [hw * 0.3, yb + t, hh - inset - 0.02], [hw * 0.3 + 0.028, yb + t + 0.002, hh + 0.07], W.all('red_wool'));
      const mesh = new T.Mesh(mb.geometry(T), heldMat);
      mesh.userData.noShadow = true;
      return mesh;
    };
    const group = new T.Group();
    const right = half(1);
    const hinge = new T.Group();
    hinge.position.y = t;
    hinge.add(half(-1));
    group.add(right, hinge);
    group.position.set(0, desk.top + 0.002, desk.z + 0.02);
    group.visible = false;
    scene.add(group);
    Object.assign(deskBook, {group, left: hinge, right, open: 0, target: 0, dims: {hw, hh, t}});
    poseDeskBook();
  }

  function disposeDeskBook() {
    if (!deskBook.group) return;
    scene.remove(deskBook.group);
    deskBook.group.traverse(o => o.geometry?.dispose());
    deskBook.group = null;
  }

  function poseDeskBook() {
    if (!deskBook.group) return;
    const e = easeInOut(deskBook.open);
    deskBook.left.rotation.z = -Math.PI + 0.02 + (Math.PI - 0.1) * e;
    deskBook.right.rotation.z = 0.08 * e;
  }

  // Swaps the carried book for the open one on the desk, and back.
  function showDeskBook(book) {
    makeDeskBook(book);
    deskBook.group.visible = true;
    deskBook.target = 1;
    if (held.mesh) held.mesh.visible = false;
  }

  function hideDeskBook() {
    if (deskBook.group) deskBook.group.visible = false;
    deskBook.target = 0;
  }

  // Closes the book on the desk, then hands back the carried one.
  async function closeDeskBook() {
    if (deskBook.group?.visible) {
      deskBook.target = 0;
      await new Promise(r => setTimeout(r, S.reducedMotion ? 0 : 320));
    }
    hideDeskBook();
    if (held.mesh) held.mesh.visible = true;
  }

  // ── Particles ──────────────────────────────────────────────────────────
  const PARTICLE_VERT = /* glsl */ `
    attribute vec4 color;
    attribute float size;
    attribute float glyph;
    uniform float pxScale;
    uniform sampler2D shadowMap;
    uniform mat4 shadowMatrix;
    uniform float sunLit;
    varying vec4 vColor;
    varying float vGlyph;
    void main() {
      vec4 world = modelMatrix * vec4(position, 1.0);
      vec4 mv = viewMatrix * world;
      vColor = color;
      if (sunLit > 0.5) {
        vec4 s = shadowMatrix * world;
        vec3 q = s.xyz / s.w;
        float lit = (q.x > 0.0 && q.x < 1.0 && q.y > 0.0 && q.y < 1.0 && q.z - 0.002 <= texture2D(shadowMap, q.xy).r) ? 1.0 : 0.0;
        vColor.rgb *= 0.12 + lit * 2.4;
        vColor.a *= 0.35 + lit * 0.65;
      }
      vGlyph = glyph;
      gl_PointSize = size * pxScale / max(-mv.z, 0.05);
      gl_Position = projectionMatrix * mv;
    }
  `;
  const PARTICLE_FRAG = /* glsl */ `
    uniform sampler2D glyphs;
    uniform float shape;
    varying vec4 vColor;
    varying float vGlyph;
    void main() {
      vec2 p = gl_PointCoord;
      float a;
      if (shape > 1.5) {
        vec2 cell = vec2(mod(vGlyph, 8.0), floor(vGlyph / 8.0));
        a = texture2D(glyphs, (cell + p) / 8.0).a;
        if (a < 0.5) discard;
      } else if (shape > 0.5) {
        // Flame: a soft teardrop, brighter at the base.
        vec2 q = p - vec2(0.5, 0.62);
        q.x *= 1.0 + (0.62 - p.y) * 1.6;
        a = smoothstep(0.34, 0.08, length(q));
      } else {
        a = smoothstep(0.5, 0.1, length(p - 0.5));
      }
      gl_FragColor = vec4(vColor.rgb, vColor.a * a);
    }
  `;

  class Particles {
    constructor(max, {shape = 0, additive = true, sunLit = false, glyphs = null} = {}) {
      this.max = max;
      this.pos = new Float32Array(max * 3);
      this.col = new Float32Array(max * 4);
      this.size = new Float32Array(max);
      this.glyph = new Float32Array(max);
      this.items = [];
      const g = new T.BufferGeometry();
      g.setAttribute('position', new T.BufferAttribute(this.pos, 3).setUsage(T.DynamicDrawUsage));
      g.setAttribute('color', new T.BufferAttribute(this.col, 4).setUsage(T.DynamicDrawUsage));
      g.setAttribute('size', new T.BufferAttribute(this.size, 1).setUsage(T.DynamicDrawUsage));
      g.setAttribute('glyph', new T.BufferAttribute(this.glyph, 1).setUsage(T.DynamicDrawUsage));
      g.setDrawRange(0, 0);
      this.uniforms = {
        pxScale: {value: 400}, shape: {value: shape}, sunLit: {value: sunLit ? 1 : 0},
        glyphs: {value: glyphs}, shadowMap: U.shadowMap, shadowMatrix: U.shadowMatrix,
      };
      this.mesh = new T.Points(g, new T.ShaderMaterial({
        uniforms: this.uniforms, vertexShader: PARTICLE_VERT, fragmentShader: PARTICLE_FRAG,
        transparent: true, depthWrite: false, blending: additive ? T.AdditiveBlending : T.NormalBlending,
      }));
      this.mesh.frustumCulled = false;
      this.mesh.userData.noShadow = true;
      scene.add(this.mesh);
    }
    add(p) { if (this.items.length < this.max) this.items.push(p); }
    clear() { this.items.length = 0; }
    step(dt, fn) {
      let n = 0;
      for (let i = 0; i < this.items.length; i++) {
        const p = this.items[i];
        if (!fn(p, dt)) continue;
        this.items[n++] = p;
      }
      this.items.length = n;
      for (let i = 0; i < n; i++) {
        const p = this.items[i];
        this.pos.set(p.p, i * 3);
        this.col.set(p.c, i * 4);
        this.size[i] = p.s;
        this.glyph[i] = p.g || 0;
      }
      const g = this.mesh.geometry;
      g.setDrawRange(0, n);
      for (const a of ['position', 'color', 'size', 'glyph']) g.attributes[a].needsUpdate = true;
    }
  }

  const glyphCanvas = document.createElement('canvas');
  glyphCanvas.width = 128; glyphCanvas.height = 128;
  const glyphTexture = new T.CanvasTexture(glyphCanvas);
  glyphTexture.magFilter = T.NearestFilter;
  glyphTexture.minFilter = T.NearestFilter;
  glyphTexture.generateMipmaps = false;

  const particles = {
    dust: new Particles(420, {sunLit: true}),
    embers: new Particles(90),
    flames: new Particles(24, {shape: 1}),
    glyphs: new Particles(60, {shape: 2, additive: false, glyphs: glyphTexture}),
    poof: new Particles(160, {additive: false}),
  };
  const rand = (a, b) => a + Math.random() * (b - a);

  function seedDust() {
    const b = S.built.bounds;
    particles.dust.clear();
    for (let i = 0; i < particles.dust.max; i++) {
      particles.dust.add({p: [rand(-4.5, 4.5), rand(0.3, 6.5), rand(b.min[2] + 1, b.max[2] - 1)], v: [rand(-0.02, 0.02), rand(-0.01, 0.015), rand(-0.02, 0.02)], c: [1, 0.86, 0.62, 0.35], s: rand(0.012, 0.03), t: rand(0, 100)});
    }
  }

  function poof(at, count = 10, spread = 0.25) {
    for (let i = 0; i < count; i++) {
      const gray = rand(0.75, 1);
      particles.poof.add({p: [at[0] + rand(-spread, spread), at[1] + rand(-spread, spread), at[2] + rand(-spread, spread)], v: [rand(-0.3, 0.3), rand(0.2, 0.7), rand(-0.3, 0.3)], c: [gray, gray, gray, 0.8], s: rand(0.08, 0.16), life: rand(0.5, 0.9), age: 0});
    }
  }

  function burst(at, count = 30) {
    for (let i = 0; i < count; i++) {
      particles.embers.add({p: [at[0] + rand(-0.2, 0.2), at[1] + rand(0, 0.3), at[2] + rand(-0.2, 0.2)], v: [rand(-0.5, 0.5), rand(0.6, 1.8), rand(-0.5, 0.5)], c: [3.2, 1.3, 0.35, 1], s: rand(0.02, 0.05), life: rand(0.6, 1.6), age: 0});
    }
  }

  function stepParticles(dt, time) {
    const built = S.built;
    if (!built) return;
    particles.dust.step(dt, p => {
      p.t += dt;
      p.p[0] += (p.v[0] + Math.sin(p.t * 0.3) * 0.01) * dt;
      p.p[1] += (p.v[1] + Math.sin(p.t * 0.21) * 0.006) * dt;
      p.p[2] += p.v[2] * dt;
      if (p.p[1] < 0.2) p.p[1] = 6.4;
      if (p.p[1] > 6.6) p.p[1] = 0.3;
      if (p.p[0] < -4.8) p.p[0] = 4.7;
      if (p.p[0] > 4.8) p.p[0] = -4.7;
      p.c[3] = 0.25 + 0.15 * Math.sin(p.t * 1.7);
      return true;
    });
    // Embers drift up out of the hearth.
    if (Math.random() < dt * 9) {
      const f = built.fire;
      particles.embers.add({p: [f[0] + rand(-0.6, 0.6), f[1], f[2] + rand(-0.2, 0.2)], v: [rand(-0.1, 0.1), rand(0.4, 0.9), rand(0, 0.12)], c: [2.6, 1.1, 0.3, 1], s: rand(0.015, 0.03), life: rand(1, 2.2), age: 0});
    }
    particles.embers.step(dt, p => {
      p.age += dt;
      if (p.age > p.life) return false;
      p.v[1] -= dt * 0.15;
      p.p[0] += (p.v[0] + Math.sin(p.age * 6 + p.life * 10) * 0.08) * dt;
      p.p[1] += p.v[1] * dt;
      p.p[2] += p.v[2] * dt;
      const k = 1 - p.age / p.life;
      p.c[3] = k;
      return true;
    });
    // Candle flames: one per wick, flickering.
    particles.flames.clear();
    for (const [i, c] of built.candles.entries()) {
      const f = 0.85 + 0.15 * Math.sin(time * 11 + i * 2.1) + 0.05 * Math.sin(time * 27 + i);
      particles.flames.add({p: [c[0], c[1] + 0.02, c[2]], c: [3.4 * f, 2.2 * f, 0.9 * f, 1], s: 0.075 * f});
    }
    particles.flames.step(dt, () => true);
    // Enchanting glyphs float from the shelves to the open book.
    if (S.mode === 'desk' && Math.random() < dt * 14 && S.glyphCount > 0) {
      const from = [rand(-4.5, 3.5), rand(0.4, 3.4), built.layout.endWall + 1.3];
      const to = [rand(-0.25, 0.25), 1.05, built.desk.z + rand(-0.1, 0.2)];
      particles.glyphs.add({p: from.slice(), from, to, c: [1, 1, 1, 0.9], s: 0.07, g: Math.floor(Math.random() * S.glyphCount), life: rand(1.6, 2.6), age: 0});
    }
    particles.glyphs.step(dt, p => {
      p.age += dt;
      const t = p.age / p.life;
      if (t >= 1) return false;
      const e = t * t * (3 - 2 * t);
      for (let k = 0; k < 3; k++) p.p[k] = p.from[k] + (p.to[k] - p.from[k]) * e;
      p.p[1] += Math.sin(t * Math.PI) * 0.8;
      p.c[3] = Math.min(1, t * 4) * (1 - t * t);
      return true;
    });
    particles.poof.step(dt, p => {
      p.age += dt;
      if (p.age > p.life) return false;
      for (let k = 0; k < 3; k++) p.p[k] += p.v[k] * dt;
      p.v[1] *= 0.96;
      p.s += dt * 0.08;
      p.c[3] = 0.8 * (1 - p.age / p.life);
      return true;
    });
  }

  // ── Assets ─────────────────────────────────────────────────────────────
  let atlasTexture = null;
  async function onAssets(m) {
    const files = m.files || {};
    S.source = m.source || null;
    const font = await PixelFont.useVanilla(files);
    gui.applySprites(files);
    gui.paintBook();
    const resolved = await LibraryTextures.resolve(files);
    canvases = resolved.canvases;
    S.vanilla = Object.keys(resolved.vanilla).length > 10;
    const next = LibraryTextures.buildAtlas(canvases, files);
    atlasTexture?.dispose();
    atlasTexture = new T.CanvasTexture(next.canvas);
    atlasTexture.flipY = false;
    atlasTexture.magFilter = T.NearestFilter;
    atlasTexture.minFilter = T.LinearMipmapLinearFilter;
    atlasTexture.anisotropy = R.renderer.capabilities.getMaxAnisotropy();
    atlasTexture.colorSpace = T.SRGBColorSpace;
    atlas = next;
    U.atlas.value = atlasTexture;
    U.atlasSize.value.set(next.canvas.width, next.canvas.height);
    U.atlasCols.value = next.cols;
    paintGlyphs(files);
    if (!labels) labels = LibraryLabels.create(T, W.DYES.map((_, i) => W.coverRgb(i)), W.DYES);
    if (font) labels.invalidate();
    U.labels.value = labels.texture;
    S.assetsReady = true;
    $('texture-source').textContent = S.vanilla && S.source ? gui.t('vanilla', S.source) : gui.t('builtIn');
    $('download').hidden = S.vanilla;
    $('download-note').hidden = S.vanilla;
    $('download').disabled = false;
    rebuildWorld();
    finishLoading();
  }

  function paintGlyphs(files) {
    const ctx = glyphCanvas.getContext('2d');
    ctx.clearRect(0, 0, 128, 128);
    let n = 0;
    const sources = [];
    for (let i = 0; i < 26; i++) {
      const data = files[`textures/particle/sga_${String.fromCharCode(97 + i)}.png`];
      if (data) sources.push(data);
    }
    const draw = (img, i) => ctx.drawImage(img, (i % 8) * 16, Math.floor(i / 8) * 16, 16, 16);
    if (sources.length) {
      sources.forEach((data, i) => {
        const img = new Image();
        img.onload = () => { draw(img, i); glyphTexture.needsUpdate = true; };
        img.src = 'data:image/png;base64,' + data;
      });
      n = sources.length;
    } else {
      // luma's own runes: random strokes on a 6×6 grid.
      for (let i = 0; i < 24; i++) {
        const r = LibraryTextures.rng('rune' + i);
        ctx.fillStyle = '#fff';
        const ox = (i % 8) * 16 + 4, oy = Math.floor(i / 8) * 16 + 4;
        for (let s = 0; s < 4; s++) {
          const vertical = r() < 0.5, x = Math.floor(r() * 7), y = Math.floor(r() * 7), len = 2 + Math.floor(r() * 5);
          for (let k = 0; k < len; k++) ctx.fillRect(ox + Math.min(7, vertical ? x : x + k), oy + Math.min(7, vertical ? y + k : y), 1, 1);
        }
      }
      n = 24;
    }
    S.glyphCount = n;
    glyphTexture.needsUpdate = true;
  }

  // ── Building the hall ──────────────────────────────────────────────────
  function rebuildWorld() {
    if (!atlas) return;
    const built = W.build(T, atlas, canvases, S.subjects);
    built.cases.forEach((c, i) => {
      c.subject = c.placeholder ? null : S.subjects[i];
      c.page = c.subject ? S.pages.get(c.subject.id) || 0 : 0;
    });
    for (const mesh of [worldMesh, glassMesh]) if (mesh) { scene.remove(mesh); mesh.geometry.dispose(); }
    worldMesh = new T.Mesh(built.geometry, blockMat);
    glassMesh = new T.Mesh(built.glass, R.glassMaterial);
    glassMesh.userData.noShadow = true;
    glassMesh.renderOrder = 2;
    scene.add(worldMesh, glassMesh);
    S.built = built;
    U.fireOrigin.value.set(...built.fire);
    const b = built.bounds;
    R.post.box = {min: [b.min[0] + 1, 0, b.min[2] + 0.5], max: [b.max[0] - 1, 7, b.max[2] - 0.5]};
    shadowDirty = true;
    if (S.caseSubject != null) {
      const idx = built.cases.findIndex(c => c.subject && c.subject.id === S.caseSubject);
      if (idx < 0 && (S.mode === 'shelf' || S.mode === 'placing')) toOverview();
      S.caseIndex = idx;
    }
    if (blocked(S.px, S.pz)) { S.px = 0; S.pz = built.layout.hallStart - 1.8; }
    buildClock();
    rebuildDynamic();
    if (particles.dust.items.length === 0) seedDust();
    rebuildA11y();
    refreshHud();
  }

  function rebuildDynamic() {
    const built = S.built;
    if (!built || !labels) return;
    const mb = new W.MeshBuilder();
    const bookIds = new Set(), subjectIds = new Set();
    built.cases.forEach(c => {
      if (!c.subject) return;
      subjectIds.add(c.subject.id);
      for (const book of c.subject.books) {
        bookIds.add(book.id);
        if (S.hidden.has(book.id)) continue;
        if (Math.floor(book.slot / W.SLOTS) !== c.page) continue;
        W.addBook(mb, built.grid, atlas, W.slotGeometry(c, book.slot), labelBook(book), labels);
      }
      addSign(mb, c, c.subject);
    });
    if (built.placeholder) addSign(mb, built.placeholder, {id: 'new', name: '+ ' + gui.t('newCase'), color: 5});
    labels.retain(bookIds, new Set([...subjectIds, 'new']));
    labels.flush();
    if (dynMesh) { scene.remove(dynMesh); dynMesh.geometry.dispose(); }
    dynMesh = new T.Mesh(mb.geometry(T), dynMat);
    scene.add(dynMesh);
    rebuildGhost();
    shadowDirty = true;
  }

  const labelBook = book => ({...book, spine: book.spine || book.title});

  // The subject's name on a plate set into the bookcase's fascia, with a
  // brass pin at each end.
  function addSign(mb, c, subject) {
    const uv = labels.sign(subject);
    if (!uv) return;
    const f = W.frame(c.spec.origin, c.spec.right, c.spec.n);
    const K = {mb, grid: S.built.grid, atlas};
    const w = 2.3, h = w / 4;
    const u0 = (c.spec.width - w) / 2, v0 = W.HALL.shelfTop + (W.HALL.caseTop - 0.125 - W.HALL.shelfTop - h) / 2;
    const plank = {tex: 'dark_oak_planks'};
    const labelUv = [[uv.u0, uv.v0], [uv.u0, uv.v1], [uv.u1, uv.v1], [uv.u1, uv.v0]];
    f.box(K, u0, v0, -0.6 / 16, u0 + w, v0 + h, 0, {front: {tex: 'solid', labelUv, emit: 0.12}, top: plank, bottom: plank, left: plank, right: plank}, {whole: true});
    const pin = W.sides('yellow_wool', null, null, {tint: [0.8, 0.58, 0.28]});
    for (const u of [u0 + 0.06, u0 + w - 0.12]) f.box(K, u, v0 + h / 2 - 0.03, -0.9 / 16, u + 0.06, v0 + h / 2 + 0.03, -0.6 / 16, {front: pin.north, top: pin.up, bottom: pin.down, left: pin.west, right: pin.east});
  }

  // The empty alcove: a translucent bookcase where the next one will go.
  let floatingItem = null;
  function rebuildGhost() {
    if (ghostMesh) { scene.remove(ghostMesh); ghostMesh.geometry.dispose(); ghostMesh = null; }
    if (floatingItem) { scene.remove(floatingItem); floatingItem.geometry.dispose(); floatingItem = null; }
    const c = S.built.placeholder;
    if (!c) return;
    const mb = new W.MeshBuilder();
    W.builtInCase({mb, grid: S.built.grid, atlas}, c.spec, {ends: true, light: [0.6, 0.7, 0.1]});
    ghostMesh = new T.Mesh(mb.geometry(T), ghostMat);
    ghostMesh.userData.noShadow = true;
    ghostMesh.renderOrder = 3;
    scene.add(ghostMesh);
    // A book and quill turning in the air, like a dropped item.
    const itemMb = new W.MeshBuilder();
    W.itemSprite(itemMb, S.built.grid, atlas, canvases.writable_book, 'writable_book', [-0.3, 0, -0.3], 0.6, 0);
    const geo = itemMb.geometry(T);
    geo.rotateX(Math.PI / 2);
    floatingItem = new T.Mesh(geo, heldMat);
    floatingItem.position.set(c.faceX + c.facing * 0.55, 2.2, (c.z0 + c.z1) / 2);
    floatingItem.userData.noShadow = true;
    floatingItem.userData.baseY = 2.2;
    scene.add(floatingItem);
  }

  // ── Library updates ────────────────────────────────────────────────────
  function structureKey(subjects) {
    return subjects.map(s => `${s.id}:${s.name}:${s.color}`).join('|');
  }

  function onLibrary(subjects) {
    const before = structureKey(S.subjects);
    S.subjects = subjects.map(s => ({...s, books: (s.books || []).map(b => ({...b}))}));
    if (!S.built) return;
    if (structureKey(S.subjects) !== before) rebuildWorld();
    else {
      S.built.cases.forEach((c, i) => { if (!c.placeholder) c.subject = S.subjects[i]; });
      rebuildDynamic();
      rebuildA11y();
      refreshHud();
    }
    if (S.pendingSubject != null) {
      const idx = S.built.cases.findIndex(c => c.subject && c.subject.id === S.pendingSubject);
      if (idx >= 0) {
        S.pendingSubject = null;
        const c = S.built.cases[idx];
        for (let y = 0; y < 6; y++) for (let z = c.z0; z < c.z1; z++) {
          setTimeout(() => poof([c.faceX - c.facing * 0.5, y + 0.5, z + 0.5], 3, 0.4), y * 110 + (z - c.z0) * 50);
        }
        toShelf(idx);
      }
    }
  }

  // ── Camera ─────────────────────────────────────────────────────────────
  const view = {pos: new T.Vector3(0, 2.35, 5.2), target: new T.Vector3(0, 1.8, 0), fov: 55};
  let flight = null;
  const easeInOut = t => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

  // Standing in the hall, with a slight bob while walking.
  function overviewPose() {
    const bob = S.reducedMotion ? 0 : Math.sin(S.stride * 5.2) * 0.035 * Math.min(1, Math.hypot(...S.vel) / 2);
    const pos = new T.Vector3(S.px, W.HALL.eye + Math.abs(bob), S.pz);
    const dir = new T.Vector3(-Math.sin(S.yaw) * Math.cos(S.pitch), Math.sin(S.pitch), -Math.cos(S.yaw) * Math.cos(S.pitch));
    // Phones held upright see little of the hall's width; widen the view.
    const fov = innerWidth < innerHeight ? 74 : 66;
    return {pos, target: pos.clone().addScaledVector(dir, 6), fov};
  }

  const SHELF_CENTER = 3.3;
  function shelfDistance(fov) {
    const v = Math.tan((fov * Math.PI / 180) / 2);
    const aspect = innerWidth / Math.max(1, innerHeight);
    // Room for the whole case, cabinets to name plate.
    return Math.min(7.4, Math.max(2.75 / v, 2.3 / (v * aspect)));
  }

  function shelfPose(i) {
    const c = S.built.cases[i];
    const fov = 50;
    const d = shelfDistance(fov) * S.zoom;
    const cy = SHELF_CENTER + S.panY;
    const zc = (c.z0 + c.z1) / 2 + S.pan;
    return {pos: new T.Vector3(c.faceX + c.facing * d, cy - 0.3 * S.zoom, zc), target: new T.Vector3(c.faceX, cy, zc), fov};
  }

  // How far the bookcase view may pan at the current zoom.
  function clampShelfView() {
    const slack = 1 - S.zoom;
    const across = 0.9 + slack * 1.6;
    S.pan = Math.max(-across, Math.min(across, S.pan));
    S.panY = Math.max(-2.2 * slack, Math.min(2.2 * slack, S.panY));
  }

  function deskPose() {
    const z = S.built.desk.z;
    return {pos: new T.Vector3(0, 1.72, z + 1.05), target: new T.Vector3(0, 0.98, z + 0.05), fov: 55};
  }

  function flyTo(pose, {duration} = {}) {
    const from = {pos: view.pos.clone(), target: view.target.clone(), fov: view.fov};
    const dist = from.pos.distanceTo(pose.pos) + from.target.distanceTo(pose.target) * 0.3;
    const d = S.reducedMotion ? 0.25 : duration ?? Math.min(1.9, Math.max(0.75, 0.55 + dist * 0.11));
    return new Promise(resolve => {
      flight?.resolve?.();
      flight = {from, to: pose, t: 0, d, dist, resolve};
    });
  }

  function stepCamera(dt, time) {
    let bob = 0;
    if (flight) {
      flight.t = Math.min(1, flight.t + dt / flight.d);
      const e = easeInOut(flight.t);
      view.pos.lerpVectors(flight.from.pos, flight.to.pos, e);
      view.target.lerpVectors(flight.from.target, flight.to.target, e);
      view.fov = flight.from.fov + (flight.to.fov - flight.from.fov) * e;
      // A little rise mid-walk, and the game's view bobbing while moving.
      const arc = Math.sin(flight.t * Math.PI);
      view.pos.y += arc * Math.min(0.35, flight.dist * 0.03);
      if (!S.reducedMotion) bob = arc * Math.min(1, flight.dist * 0.2);
      if (flight.t >= 1) { const done = flight.resolve; flight = null; done(); }
    } else {
      const target = baseModePose();
      if (target) {
        // Walking follows the feet closely; the other views glide.
        const k = 1 - Math.exp(-dt * (S.mode === 'overview' ? 16 : 6));
        view.pos.lerp(target.pos, k);
        view.target.lerp(target.target, k);
        view.fov += (target.fov - view.fov) * k;
      }
    }
    camera.position.copy(view.pos);
    const phase = view.pos.x * 2.2 + view.pos.z * 2.2;
    if (bob > 0) {
      camera.position.y += Math.abs(Math.sin(phase)) * 0.045 * bob;
      camera.position.x += Math.sin(phase) * 0.02 * bob;
    }
    // Breathing sway and a touch of parallax toward the pointer.
    const sway = S.reducedMotion ? 0 : 1;
    const look = view.target.clone();
    look.y += Math.sin(time * 0.7) * 0.012 * sway;
    look.x += Math.sin(time * 0.43) * 0.01 * sway;
    if (S.mode === 'shelf' || S.mode === 'placing') {
      const right = new T.Vector3().subVectors(look, camera.position).cross(camera.up).normalize();
      look.addScaledVector(right, pointer.nx * 0.12 * sway);
      look.y -= pointer.ny * 0.07 * sway;
    }
    camera.fov = view.fov;
    camera.updateProjectionMatrix();
    camera.lookAt(look);
    camera.updateMatrixWorld();
  }

  function baseModePose() {
    if (!S.built) return null;
    if (S.mode === 'overview') return overviewPose();
    if ((S.mode === 'shelf' || S.mode === 'placing') && S.caseIndex >= 0) return shelfPose(S.caseIndex);
    if (S.mode === 'desk') return deskPose();
    return null;
  }

  // ── Modes ──────────────────────────────────────────────────────────────
  function setMode(mode) {
    S.mode = mode;
    refreshHud();
    rebuildA11y();
  }

  // Back on your feet, a couple of steps back from the case you were at.
  function toOverview() {
    const c = currentCase();
    if (c && S.mode !== 'overview') {
      const x = c.faceX + c.facing * 2.2, z = (c.z0 + c.z1) / 2 + S.pan;
      if (!blocked(x, z)) {
        S.px = x; S.pz = z;
        S.yaw = c.facing * Math.PI / 2;
        S.pitch = 0.12;
      }
    }
    setMode('overview');
    S.caseSubject = null;
    S.caseIndex = -1;
    S.vel = [0, 0];
    S.goal = null;
    return flyTo(overviewPose());
  }

  function toShelf(i, {placing = false} = {}) {
    const c = S.built.cases[i];
    if (!c || !c.subject) return Promise.resolve();
    S.caseIndex = i;
    S.caseSubject = c.subject.id;
    S.pan = 0; S.panY = 0; S.zoom = 1;
    setMode(placing ? 'placing' : 'shelf');
    return flyTo(shelfPose(i));
  }

  function neighbour(step) {
    const cases = S.built.cases;
    let i = S.caseIndex;
    for (let k = 0; k < cases.length; k++) {
      i = (i + step + cases.length) % cases.length;
      if (cases[i].subject) return i;
    }
    return S.caseIndex;
  }

  function currentCase() { return S.built?.cases[S.caseIndex] || null; }

  function pageCount(c) {
    const max = c.subject.books.reduce((m, b) => Math.max(m, b.slot), -1);
    const pages = Math.max(1, Math.floor(max / W.SLOTS) + 1);
    const lastFull = c.subject.books.filter(b => Math.floor(b.slot / W.SLOTS) === pages - 1).length >= W.SLOTS;
    return pages + (lastFull ? 1 : 0);
  }

  function refreshHud() {
    const c = currentCase();
    const inCase = (S.mode === 'shelf' || S.mode === 'placing') && c && c.subject;
    if (inCase) {
      const pages = pageCount(c);
      const sub = S.mode === 'placing' ? gui.t('chooseSlot') : gui.t('books', c.subject.books.length) + (pages > 1 ? ' · ' + gui.t('shelfPage', c.page + 1, pages) : '');
      gui.heading(c.subject.name, sub);
      $('shelf-pages').hidden = pages <= 1;
      $('page-label').textContent = gui.t('shelfPage', c.page + 1, pages);
      $('page-prev').disabled = c.page <= 0;
      $('page-next').disabled = c.page >= pages - 1;
    } else {
      gui.heading(null);
      $('shelf-pages').hidden = true;
    }
    $('back').hidden = !(inCase);
    $('back').textContent = gui.t(S.mode === 'placing' ? 'cancel' : 'back');
    const others = S.built ? S.built.cases.filter(cs => cs.subject).length : 0;
    $('case-prev').hidden = $('case-next').hidden = !((inCase && others > 1) || (S.mode === 'overview' && S.built));
    const empty = S.subjects.length === 0 && S.mode === 'overview';
    const walkHint = S.mode === 'overview' && !S.walked;
    gui.actionbar(S.mode === 'placing' ? gui.t('moveHint') : empty ? gui.t('emptyHall') : walkHint ? gui.t('walkHint') : '');
    $('settings-open').hidden = S.mode === 'desk';
    $('move-pad').hidden = !(S.mode === 'overview' && S.touch);
  }

  // ── Picking ────────────────────────────────────────────────────────────
  const raycaster = new T.Raycaster();
  const pointer = {x: 0, y: 0, nx: 0, ny: 0, down: null, dragging: false, pinch: null};

  function rayAt(x, y) {
    const ndc = new T.Vector2((x / innerWidth) * 2 - 1, -(y / innerHeight) * 2 + 1);
    raycaster.setFromCamera(ndc, camera);
    return raycaster.ray;
  }

  function boxHit(ray, min, max) {
    let t0 = -Infinity, t1 = Infinity;
    for (let k = 0; k < 3; k++) {
      const o = ray.origin.getComponent(k), d = ray.direction.getComponent(k);
      if (Math.abs(d) < 1e-9) { if (o < min[k] || o > max[k]) return null; continue; }
      let a = (min[k] - o) / d, b = (max[k] - o) / d;
      if (a > b) [a, b] = [b, a];
      t0 = Math.max(t0, a); t1 = Math.min(t1, b);
      if (t0 > t1) return null;
    }
    return t1 < 0 ? null : Math.max(0, t0);
  }

  function caseBox(c) {
    const x0 = c.faceX - c.facing * 1, x1 = c.faceX + c.facing * 0.05;
    return [[Math.min(x0, x1), 0, c.z0], [Math.max(x0, x1), W.HALL.caseTop, c.z1]];
  }

  function pickCase(ray) {
    let best = null;
    S.built.cases.forEach((c, i) => {
      const [min, max] = caseBox(c);
      const t = boxHit(ray, min, max);
      if (t != null && (!best || t < best.t)) best = {t, i};
    });
    return best;
  }

  function pickSlot(ray, c) {
    const d = ray.direction.x;
    if (Math.abs(d) < 1e-6) return null;
    const t = (c.faceX - ray.origin.x) / d;
    if (t < 0) return null;
    const p = ray.origin.clone().addScaledVector(ray.direction, t);
    for (let local = 0; local < W.SLOTS; local++) {
      const g = W.slotGeometry(c, local);
      const pad = 0.5 / 16;
      if (p.y >= g.y0 - pad && p.y <= g.y1 + pad && p.z >= g.z0 - pad && p.z <= g.z1 + pad) {
        const slot = c.page * W.SLOTS + local;
        return {slot, g, book: c.subject.books.find(b => b.slot === slot && !S.hidden.has(b.id)) || null};
      }
    }
    return null;
  }

  let hover = null;
  function updateHover() {
    if (!S.built || pointer.dragging || Book.open || gui.isModalOpen()) { setHover(null); return; }
    const ray = rayAt(pointer.x, pointer.y);
    if (S.mode === 'overview') {
      const hit = pickCase(ray);
      setHover(hit ? {kind: 'case', i: hit.i} : null);
    } else if (S.mode === 'shelf' || S.mode === 'placing') {
      const c = currentCase();
      const slot = c ? pickSlot(ray, c) : null;
      if (slot) setHover({kind: 'slot', ...slot});
      else {
        const hit = pickCase(ray);
        setHover(hit && hit.i !== S.caseIndex ? {kind: 'case', i: hit.i} : null);
      }
    } else setHover(null);
  }

  function setHover(h) {
    hover = h;
    outline.visible = false;
    slotHi.visible = false;
    canvas.classList.toggle('pointer', !!h);
    if (!h) { gui.tooltip(null); return; }
    if (h.kind === 'case') {
      const c = S.built.cases[h.i];
      const [min, max] = caseBox(c);
      outline.position.set((min[0] + max[0]) / 2, (min[1] + max[1]) / 2, (min[2] + max[2]) / 2);
      outline.scale.set(max[0] - min[0] + 0.01, max[1] - min[1] + 0.01, max[2] - min[2] + 0.01);
      outline.visible = true;
      gui.tooltip(c.subject ? [c.subject.name, gui.t('books', c.subject.books.length)] : [gui.t('newCase')], pointer.x, pointer.y);
    } else {
      const g = h.g;
      slotHi.position.set(g.faceX + g.facing * 0.004, (g.y0 + g.y1) / 2, (g.z0 + g.z1) / 2);
      slotHi.rotation.set(0, g.facing > 0 ? Math.PI / 2 : -Math.PI / 2, 0);
      slotHi.scale.set(g.z1 - g.z0, g.y1 - g.y0, 1);
      slotHi.visible = true;
      if (S.mode === 'placing') gui.tooltip(null);
      else if (h.book) {
        const preview = Book.plainText(h.book.body).replace(/\s+/g, ' ').trim();
        gui.tooltip([h.book.title, ...(preview ? [{text: preview.length > 90 ? preview.slice(0, 89) + '…' : preview, cls: 'sub'}] : [])], pointer.x, pointer.y);
      } else gui.tooltip([gui.t('emptySlot')], pointer.x, pointer.y);
    }
  }

  // Clicking the floor walks there.
  function walkToward(x, y) {
    const ray = rayAt(x, y);
    if (ray.direction.y > -0.02) return;
    const t = -ray.origin.y / ray.direction.y;
    const p = ray.origin.clone().addScaledVector(ray.direction, t);
    if (t > 30 || blocked(p.x, p.z)) return;
    S.goal = [p.x, p.z];
    poof([p.x, 0.08, p.z], 3, 0.06);
  }

  async function click() {
    if (!hover) {
      if (S.mode === 'overview' && S.built && !flight) walkToward(pointer.x, pointer.y);
      return;
    }
    const h = hover;
    setHover(null);
    if (h.kind === 'case') {
      const c = S.built.cases[h.i];
      if (c.placeholder) await newCase();
      else await toShelf(h.i, {placing: S.mode === 'placing'});
    } else if (h.kind === 'slot') {
      if (S.mode === 'placing') await placeHeld(h.slot, h.g);
      else openSlot(h.slot, h.g, h.book);
    }
  }

  // ── Flows ──────────────────────────────────────────────────────────────
  async function newCase() {
    const c = S.built.placeholder;
    const result = await gui.askName({title: gui.t('newCaseTitle'), color: [14, 11, 13, 1, 10, 9][S.subjects.length % 6]});
    if (!result) return;
    try {
      const id = await request({type: 'createSubject', name: result.name, color: result.color});
      S.pendingSubject = id;
      poof([c.faceX - c.facing * 0.5, 2.5, (c.z0 + c.z1) / 2], 16, 1.2);
      const idx = S.built.cases.findIndex(cs => cs.subject && cs.subject.id === id);
      if (idx >= 0) { S.pendingSubject = null; toShelf(idx); }
    } catch {
      gui.toast(gui.t('saveFailed'), result.name);
    }
  }

  // Pulls a book out of its slot (or conjures a blank one) and carries it
  // to the desk, where it opens.
  async function openSlot(slot, g, book) {
    const c = currentCase();
    S.editing = book
      ? {id: book.id, subjectId: c.subject.id, slot: book.slot, title: book.title, spineRaw: book.spine || '', cover: book.cover ?? 12, body: book.body || '', isNew: false}
      : {id: null, subjectId: c.subject.id, slot, title: '', spineRaw: '', cover: 12, body: '', isNew: true};
    if (book) { S.hidden.add(book.id); rebuildDynamic(); }
    const shown = editingBook();
    const mesh = makeHeld(shown);
    const start = slotTransform(g, shown, book ? 0 : -0.3);
    applyTransform(mesh, start);
    held.from = {g};
    setMode('desk');
    if (!book) poof(start.pos.toArray(), 5, 0.1);
    const out = {pos: start.pos.clone().add(new T.Vector3(g.facing * 0.55, 0.05, 0)), quat: start.quat.clone(), scale: 1};
    await tween(mesh, out, 0.3);
    const fly = tween(mesh, deskTransform(shown), S.reducedMotion ? 0.3 : 1.25, 0.5);
    await Promise.all([flyTo(deskPose()), fly]);
    if (S.mode !== 'desk') return;
    showDeskBook(shown);
    Book.openEditor(S.editing, editorHandlers);
  }

  // The book being edited, as the scene draws it.
  const editingBook = () => labelBook({...S.editing, spine: S.editing.spineRaw, title: S.editing.title});

  // A book standing in its slot, pulled `out` blocks toward the room.
  function slotTransform(g, book, out = 0) {
    const quat = new T.Quaternion().setFromAxisAngle(new T.Vector3(0, 1, 0), g.facing > 0 ? 0 : Math.PI);
    const p = W.bookCenter(g, book).pos;
    const pos = new T.Vector3(p[0] + g.facing * out, p[1], p[2]);
    return {pos, quat, scale: 1};
  }

  // Lying flat and closed on the desk, exactly where the open book's
  // closed halves are.
  function deskTransform(book) {
    const desk = S.built.desk;
    const {hw, t} = deskBookSize(book);
    const quat = new T.Quaternion().setFromAxisAngle(new T.Vector3(0, 0, 1), Math.PI)
      .multiply(new T.Quaternion().setFromAxisAngle(new T.Vector3(1, 0, 0), -Math.PI / 2));
    return {pos: new T.Vector3(hw / 2, desk.top + 0.002 + t, desk.z + 0.02), quat, scale: DESK_SCALE};
  }

  function handTransform() {
    const q = camera.quaternion.clone();
    // Keep the hand inside narrow (portrait) views too.
    const halfWidth = 0.75 * Math.tan((camera.fov * Math.PI / 180) / 2) * camera.aspect;
    const pos = new T.Vector3(Math.min(0.36, halfWidth * 0.62), -0.28, -0.75).applyQuaternion(q).add(camera.position);
    const tilt = new T.Quaternion().setFromEuler(new T.Euler(0.15, -0.5 + Math.sin(performance.now() / 700) * 0.03, 0.1));
    return {pos, quat: q.multiply(tilt).multiply(new T.Quaternion().setFromAxisAngle(new T.Vector3(0, 1, 0), Math.PI / 2)), scale: 0.5};
  }

  function applyTransform(mesh, tr) {
    mesh.position.copy(tr.pos);
    mesh.quaternion.copy(tr.quat);
    mesh.scale.setScalar(tr.scale);
  }

  const tweens = new Set();
  function tween(mesh, to, duration, arc = 0) {
    return new Promise(resolve => {
      for (const t of tweens) if (t.mesh === mesh) { tweens.delete(t); t.resolve(); }
      tweens.add({mesh, from: {pos: mesh.position.clone(), quat: mesh.quaternion.clone(), scale: mesh.scale.x}, to, d: Math.max(0.01, duration), t: 0, arc, resolve});
    });
  }
  function stepTweens(dt) {
    for (const tw of tweens) {
      tw.t = Math.min(1, tw.t + dt / tw.d);
      const e = easeInOut(tw.t);
      const to = typeof tw.to === 'function' ? tw.to() : tw.to;
      tw.mesh.position.lerpVectors(tw.from.pos, to.pos, e);
      tw.mesh.position.y += Math.sin(tw.t * Math.PI) * tw.arc;
      tw.mesh.quaternion.slerpQuaternions(tw.from.quat, to.quat, e);
      tw.mesh.scale.setScalar(tw.from.scale + (to.scale - tw.from.scale) * e);
      if (tw.t >= 1) { tweens.delete(tw); tw.resolve(); }
    }
    if (S.mode === 'placing' && held.mesh && ![...tweens].some(t => t.mesh === held.mesh)) applyTransform(held.mesh, handTransform());
    // The desk book opens and closes on its hinge.
    if (deskBook.group && deskBook.open !== deskBook.target) {
      const step = dt * (S.reducedMotion ? 20 : 3.2);
      deskBook.open = deskBook.target > deskBook.open ? Math.min(deskBook.target, deskBook.open + step) : Math.max(deskBook.target, deskBook.open - step);
      poseDeskBook();
    }
  }

  async function saveEditing(body, extra = {}) {
    const e = S.editing;
    if (!e) return null;
    e.body = body;
    Object.assign(e, extra);
    const id = await request({
      type: 'saveBook', id: e.id, subjectId: e.subjectId, title: e.title || '', spine: e.spineRaw || '', cover: e.cover,
      body: e.body, slot: e.id == null ? e.slot : undefined,
    });
    if (e.id == null) { e.id = id; S.hidden.add(id); }
    return id;
  }

  const isBlank = body => !Book.plainText(body).trim();

  // A new book that was never written in vanishes instead of being shelved.
  async function discardBlank(e) {
    await closeDeskBook();
    if (e.id != null) send({type: 'deleteBook', id: e.id});
    if (held.mesh) poof(held.mesh.position.toArray(), 8, 0.15);
    dropHeld();
    if (e.id != null) S.hidden.delete(e.id);
    S.editing = null;
    return backToShelf();
  }

  const editorHandlers = {
    get canBurn() { return !!S.editing && (S.editing.id != null || !S.editing.isNew); },
    onInput(body) {
      const e = S.editing;
      if (!e) return;
      if (e.id == null && isBlank(body)) return;
      saveEditing(body).catch(() => {});
    },
    async onDone(body) {
      const e = S.editing;
      Book.close();
      if (e.isNew && isBlank(body)) return discardBlank(e);
      try { await saveEditing(body); } catch { gui.toast(gui.t('saveFailed'), e.title || ''); }
      await closeDeskBook();
      await returnToSlot();
    },
    async onSign(body) {
      try { await saveEditing(body); } catch { gui.toast(gui.t('saveFailed'), ''); return; }
      const e = S.editing;
      const firstLine = Book.plainText(body).split('\n').map(l => l.trim()).find(Boolean) || '';
      Book.openSign({title: e.title || firstLine.slice(0, 32), spineRaw: e.spineRaw, cover: e.cover}, editorHandlers);
    },
    async onShelve({title, spine, cover}) {
      const e = S.editing;
      try {
        await saveEditing(e.body, {title: title || e.title, spineRaw: spine, cover});
      } catch { gui.toast(gui.t('saveFailed'), title); return; }
      Book.close();
      await closeDeskBook();
      const shown = editingBook();
      makeHeld(shown);
      applyTransform(held.mesh, deskTransform(shown));
      const idx = S.built.cases.findIndex(c => c.subject && c.subject.id === e.subjectId);
      tween(held.mesh, () => handTransform(), S.reducedMotion ? 0.2 : 1.3);
      await toShelf(idx >= 0 ? idx : S.caseIndex, {placing: true});
    },
    onSignBack() { Book.backToEditor(); },
    async onBurn() {
      const e = S.editing;
      Book.close();
      await closeDeskBook();
      const f = S.built.fire;
      await tween(held.mesh, {pos: new T.Vector3(f[0], f[1] + 0.2, f[2] + 0.3), quat: new T.Quaternion().setFromEuler(new T.Euler(1.2, 0.4, 0.3)), scale: 0.8}, S.reducedMotion ? 0.2 : 0.9, 0.7);
      burst([f[0], f[1], f[2] + 0.2], 45);
      poof([f[0], f[1] + 0.4, f[2] + 0.3], 10, 0.2);
      U.firePulse.value = 1.8;
      dropHeld();
      if (e.id != null) send({type: 'deleteBook', id: e.id});
      S.hidden.delete(e.id);
      S.editing = null;
      await new Promise(r => setTimeout(r, S.reducedMotion ? 50 : 600));
      backToShelf();
    },
  };

  function backToShelf() {
    const e = S.editing;
    const idx = S.built.cases.findIndex(c => c.subject && c.subject.id === (e ? e.subjectId : S.caseSubject));
    return idx >= 0 ? toShelf(idx) : toOverview();
  }

  // Flies the carried book back into the slot it came from: off the desk,
  // or out of your hand when a move is cancelled.
  async function returnToSlot() {
    const e = S.editing;
    const idx = S.built.cases.findIndex(c => c.subject && c.subject.id === e.subjectId);
    if (idx < 0) { dropHeld(); S.editing = null; return toOverview(); }
    const c = S.built.cases[idx];
    const g = W.slotGeometry(c, e.slot);
    const shown = editingBook();
    const from = S.mode === 'placing' ? handTransform() : deskTransform(shown);
    makeHeld(shown);
    applyTransform(held.mesh, from);
    const cam = toShelf(idx);
    await tween(held.mesh, slotTransform(g, shown, 0.45), S.reducedMotion ? 0.3 : 1.3, 0.4);
    await tween(held.mesh, slotTransform(g, shown), 0.24);
    await cam;
    finishPlacing(e.id);
  }

  async function placeHeld(slot, g) {
    const e = S.editing;
    const c = currentCase();
    if (!e || !held.mesh || !c) return;
    const target = {id: e.id, subjectId: c.subject.id, slot};
    const shown = editingBook();
    await tween(held.mesh, slotTransform(g, shown, 0.45), S.reducedMotion ? 0.2 : 0.55, 0.12);
    await tween(held.mesh, slotTransform(g, shown), 0.2);
    send({type: 'moveBook', ...target});
    e.subjectId = target.subjectId;
    e.slot = slot;
    // Show it in place straight away; the app's echo confirms it.
    const subject = c.subject;
    const other = subject.books.find(b => b.slot === slot && b.id !== e.id);
    const mine = S.subjects.flatMap(s => s.books).find(b => b.id === e.id);
    if (mine) {
      const oldSubject = S.subjects.find(s => s.books.includes(mine));
      if (other && oldSubject === subject) other.slot = mine.slot;
      oldSubject.books.splice(oldSubject.books.indexOf(mine), 1);
      subject.books.push({...mine, slot, title: e.title, spine: e.spineRaw, cover: e.cover, body: e.body});
    }
    poof([g.faceX + g.facing * 0.1, (g.y0 + g.y1) / 2, (g.z0 + g.z1) / 2], 4, 0.05);
    finishPlacing(e.id);
    setMode('shelf');
  }

  function finishPlacing(id) {
    dropHeld();
    S.hidden.delete(id);
    S.editing = null;
    rebuildDynamic();
    refreshHud();
  }

  function cancelPlacing() {
    const e = S.editing;
    if (!e) return setMode('shelf');
    // Back where it came from, as if placed there.
    returnToSlot();
  }

  // ── Walking ────────────────────────────────────────────────────────────
  // WASD or the arrow keys walk, drag looks around, the wheel steps forward
  // and back, a click on the floor walks there. Walls, bookcases and
  // furniture stop you.
  const BODY = 0.26;
  function blocked(x, z) {
    const b = S.built;
    if (!b) return false;
    const w = b.walk;
    if (x < w.minX || x > w.maxX || z < w.minZ || z > w.maxZ) return true;
    for (const [dx, dz] of [[-BODY, -BODY], [BODY, -BODY], [-BODY, BODY], [BODY, BODY]]) {
      const cx = Math.floor(x + dx), cz = Math.floor(z + dz);
      if (b.grid.solid(cx, 0, cz) || b.grid.solid(cx, 1, cz)) return true;
    }
    for (const [x0, z0, x1, z1] of b.colliders) {
      if (x > x0 - BODY && x < x1 + BODY && z > z0 - BODY && z < z1 + BODY) return true;
    }
    return false;
  }

  const keys = new Set();
  const pad = {fwd: 0, turn: 0};
  function stepWalk(dt) {
    if (S.mode !== 'overview' || flight || !S.built || Book.open || gui.isModalOpen()) {
      S.vel = [0, 0];
      return;
    }
    const down = k => keys.has(k);
    let fwd = pad.fwd, strafe = 0, turn = pad.turn;
    if (down('KeyW') || down('ArrowUp')) fwd += 1;
    if (down('KeyS') || down('ArrowDown')) fwd -= 1;
    if (down('KeyA')) strafe -= 1;
    if (down('KeyD')) strafe += 1;
    if (down('ArrowLeft') || down('KeyQ')) turn += 1;
    if (down('ArrowRight') || down('KeyE')) turn -= 1;
    S.yaw += turn * dt * 1.9;
    let tx = -Math.sin(S.yaw) * fwd + Math.cos(S.yaw) * strafe;
    let tz = -Math.cos(S.yaw) * fwd - Math.sin(S.yaw) * strafe;
    const len = Math.hypot(tx, tz);
    if (len > 1) { tx /= len; tz /= len; }
    if (len > 0 || turn) { S.goal = null; noteWalked(); }
    else if (S.goal) {
      const dx = S.goal[0] - S.px, dz = S.goal[1] - S.pz, d = Math.hypot(dx, dz);
      if (d < 0.06) S.goal = null;
      else { const k = Math.min(1, d * 1.5) / d; tx = dx * k; tz = dz * k; }
    }
    const speed = down('ShiftLeft') || down('ShiftRight') ? 5 : 3;
    const k = 1 - Math.exp(-dt * 10);
    S.vel[0] += (tx * speed - S.vel[0]) * k;
    S.vel[1] += (tz * speed - S.vel[1]) * k;
    const mx = S.vel[0] * dt, mz = S.vel[1] * dt;
    if (!blocked(S.px + mx, S.pz)) S.px += mx; else { S.vel[0] = 0; if (S.goal) S.goal = null; }
    if (!blocked(S.px, S.pz + mz)) S.pz += mz; else { S.vel[1] = 0; if (S.goal) S.goal = null; }
    S.stride += Math.hypot(S.vel[0], S.vel[1]) * dt;
  }

  // The walking hint stays until the reader has walked a little.
  function noteWalked() {
    if (S.walked) return;
    S.walked = true;
    refreshHud();
  }

  // ── Input ──────────────────────────────────────────────────────────────
  const touches = new Map();
  canvas.addEventListener('pointerdown', e => {
    if (e.button !== 0) return;
    if (e.pointerType === 'touch' && !S.touch) { S.touch = true; refreshHud(); }
    touches.set(e.pointerId, {x: e.clientX, y: e.clientY});
    if (touches.size === 2) {
      // A second finger starts a pinch; the drag it interrupted is dropped.
      const [a, b] = [...touches.values()];
      pointer.pinch = {d: Math.hypot(a.x - b.x, a.y - b.y), zoom: S.zoom};
      pointer.dragging = true;
      return;
    }
    pointer.down = {x: e.clientX, y: e.clientY, yaw: S.yaw, pitch: S.pitch, pan: S.pan, panY: S.panY};
    pointer.dragging = false;
    canvas.setPointerCapture(e.pointerId);
  });
  canvas.addEventListener('pointermove', e => {
    pointer.x = e.clientX; pointer.y = e.clientY;
    pointer.nx = (e.clientX / innerWidth) * 2 - 1;
    pointer.ny = (e.clientY / innerHeight) * 2 - 1;
    if (touches.has(e.pointerId)) touches.set(e.pointerId, {x: e.clientX, y: e.clientY});
    if (pointer.pinch && touches.size >= 2) {
      const [a, b] = [...touches.values()];
      const d = Math.hypot(a.x - b.x, a.y - b.y);
      if (S.mode === 'shelf' || S.mode === 'placing') {
        S.zoom = Math.max(0.35, Math.min(1, pointer.pinch.zoom * pointer.pinch.d / Math.max(1, d)));
        clampShelfView();
      }
      return;
    }
    const d = pointer.down;
    if (d) {
      const dx = e.clientX - d.x, dy = e.clientY - d.y;
      if (!pointer.dragging && Math.hypot(dx, dy) > 6) { pointer.dragging = true; canvas.classList.add('grab'); setHover(null); }
      if (pointer.dragging) {
        if (S.mode === 'overview') {
          S.yaw = d.yaw + dx * 0.0045;
          S.pitch = Math.max(-1.1, Math.min(0.95, d.pitch + dy * 0.0035));
          if (Math.hypot(dx, dy) > 40) noteWalked();
        } else if (S.mode === 'shelf' || S.mode === 'placing') {
          const c = currentCase();
          const scale = 0.004 * (0.4 + S.zoom * 0.6);
          if (c) S.pan = d.pan + dx * scale * c.facing;
          S.panY = d.panY + dy * scale;
          clampShelfView();
        }
        return;
      }
    }
    updateHover();
  });
  const release = e => {
    touches.delete(e.pointerId);
    if (pointer.pinch) {
      if (touches.size < 2) pointer.pinch = null;
      if (touches.size === 0) { pointer.down = null; pointer.dragging = false; }
      return;
    }
    const wasDrag = pointer.dragging;
    const wasDown = !!pointer.down;
    pointer.down = null;
    pointer.dragging = false;
    canvas.classList.remove('grab');
    if (!wasDrag && wasDown && e.type === 'pointerup') {
      pointer.x = e.clientX; pointer.y = e.clientY;
      updateHover();
      click();
    }
  };
  canvas.addEventListener('pointerup', release);
  canvas.addEventListener('pointercancel', release);
  canvas.addEventListener('pointerleave', () => { if (!pointer.down) setHover(null); });
  canvas.addEventListener('wheel', e => {
    if (!S.built) return;
    if (S.mode === 'overview') {
      e.preventDefault();
      if (flight) return;
      // A notch of the wheel is a step forward or back.
      const step = -Math.sign(e.deltaY) * Math.min(0.6, Math.abs(e.deltaY) * 0.004);
      const x = S.px - Math.sin(S.yaw) * step, z = S.pz - Math.cos(S.yaw) * step;
      if (!blocked(x, S.pz)) S.px = x;
      if (!blocked(S.px, z)) S.pz = z;
      S.goal = null;
      noteWalked();
    } else if (S.mode === 'shelf' || S.mode === 'placing') {
      e.preventDefault();
      S.zoom = Math.max(0.35, Math.min(1, S.zoom * (1 + e.deltaY * 0.0012)));
      clampShelfView();
    }
  }, {passive: false});

  const typing = () => {
    const el = document.activeElement;
    return el && (el.isContentEditable || el.tagName === 'INPUT' || el.tagName === 'TEXTAREA');
  };
  addEventListener('keydown', e => {
    if (Book.open || gui.isModalOpen() || !S.built || typing()) return;
    if (e.key === 'Escape') {
      if (S.mode === 'placing') cancelPlacing();
      else if (S.mode === 'shelf') toOverview();
    } else if (S.mode === 'shelf' || S.mode === 'placing') {
      if (e.key === 'ArrowLeft') toShelf(neighbour(-1), {placing: S.mode === 'placing'});
      if (e.key === 'ArrowRight') toShelf(neighbour(1), {placing: S.mode === 'placing'});
      if (e.key === '+' || e.key === '=') { S.zoom = Math.max(0.35, S.zoom * 0.85); clampShelfView(); }
      if (e.key === '-') { S.zoom = Math.min(1, S.zoom / 0.85); clampShelfView(); }
    } else if (S.mode === 'overview') {
      if (/^(Key[WASDQE]|Arrow(Up|Down|Left|Right)|Shift(Left|Right))$/.test(e.code)) {
        keys.add(e.code);
        e.preventDefault();
      }
    }
  });
  addEventListener('keyup', e => keys.delete(e.code));
  addEventListener('blur', () => keys.clear());

  // The on-screen pad for touch screens: hold an arrow to walk or turn.
  for (const b of document.querySelectorAll('#move-pad [data-move]')) {
    const [axis, value] = b.dataset.move.split(':');
    const stop = () => { pad[axis] = 0; b.classList.remove('on'); };
    b.addEventListener('pointerdown', e => {
      e.preventDefault();
      b.setPointerCapture(e.pointerId);
      pad[axis] = Number(value);
      b.classList.add('on');
      noteWalked();
    });
    b.addEventListener('pointerup', stop);
    b.addEventListener('pointercancel', stop);
    b.addEventListener('lostpointercapture', stop);
  }

  $('back').onclick = () => (S.mode === 'placing' ? cancelPlacing() : toOverview());
  // From the hall the arrows walk straight to the first or last bookcase.
  const stepCase = step => {
    if (S.mode === 'overview') {
      const list = S.built.cases.map((c, i) => (c.subject ? i : -1)).filter(i => i >= 0);
      if (!list.length) return newCase();
      return toShelf(step > 0 ? list[0] : list[list.length - 1]);
    }
    return toShelf(neighbour(step), {placing: S.mode === 'placing'});
  };
  $('case-prev').onclick = () => stepCase(-1);
  $('case-next').onclick = () => stepCase(1);
  const turnShelf = step => {
    const c = currentCase();
    if (!c) return;
    c.page = Math.max(0, Math.min(pageCount(c) - 1, c.page + step));
    S.pages.set(c.subject.id, c.page);
    rebuildDynamic();
    refreshHud();
  };
  $('page-prev').onclick = () => turnShelf(-1);
  $('page-next').onclick = () => turnShelf(1);
  $('settings-open').onclick = () => { $('settings').hidden = false; $('quality').focus(); };
  $('settings-done').onclick = () => { $('settings').hidden = true; };
  $('settings').addEventListener('keydown', e => { if (e.key === 'Escape') { e.stopPropagation(); $('settings').hidden = true; } });
  $('quality').onclick = () => {
    S.quality = S.quality === 'fancy' ? 'fast' : 'fancy';
    try { localStorage.setItem('library.quality', S.quality); } catch { /* storage blocked */ }
    applyQuality();
  };
  $('time').onclick = () => {
    S.timeMode = TIME_MODES[(TIME_MODES.indexOf(S.timeMode) + 1) % TIME_MODES.length];
    try { localStorage.setItem('library.time', S.timeMode); } catch { /* storage blocked */ }
    $('time').textContent = timeLabel();
  };
  $('download').onclick = () => {
    $('download').disabled = true;
    send({type: 'downloadVanilla'});
  };

  // A plain list of what is on screen, for keyboards and screen readers.
  function rebuildA11y() {
    const nav = $('a11y');
    const buttons = [];
    const add = (label, fn) => {
      const b = document.createElement('button');
      b.type = 'button'; b.textContent = label; b.onclick = fn;
      buttons.push(b);
    };
    if (!S.built) return;
    if (S.mode === 'overview') {
      S.built.cases.forEach((c, i) => {
        if (c.subject) add(`${c.subject.name} — ${gui.t('books', c.subject.books.length)}`, () => toShelf(i));
        else add(gui.t('newCase'), () => newCase());
      });
    } else if (S.mode === 'shelf') {
      const c = currentCase();
      add(gui.t('back'), () => toOverview());
      if (c && c.subject) {
        for (const book of c.subject.books) {
          if (Math.floor(book.slot / W.SLOTS) !== c.page) continue;
          add(book.title, () => openSlot(book.slot, W.slotGeometry(c, book.slot), book));
        }
        const free = firstFree(c);
        add(gui.t('emptySlot'), () => openSlot(free, W.slotGeometry(c, free), null));
      }
    }
    nav.replaceChildren(...buttons);
  }

  function firstFree(c) {
    const taken = new Set(c.subject.books.map(b => b.slot));
    let s = c.page * W.SLOTS;
    while (taken.has(s)) s++;
    return s;
  }

  // ── Time of day ────────────────────────────────────────────────────────
  // The sun crosses the sky over a twenty-minute day, as in the game, and
  // the moon follows it through the night. The reader can also follow their
  // own clock, or hold the hall at day or at night.
  const TIME_MODES = ['cycle', 'clock', 'day', 'night'];
  const TIME_LABEL = {cycle: 'timeCycle', clock: 'timeClock', day: 'timeDay', night: 'timeNight'};
  const DAY_SECONDS = 1200;

  // Keyframes by the sun's height (-1 midnight … 1 noon).
  const SKY = [
    {e: -1, sun: [0.16, 0.21, 0.36], sky: [0.04, 0.055, 0.11], zen: [0.008, 0.012, 0.04], hor: [0.03, 0.04, 0.08], lamp: 1.35, night: 1, exposure: 1.25},
    {e: -0.2, sun: [0.14, 0.18, 0.3], sky: [0.05, 0.06, 0.12], zen: [0.012, 0.018, 0.06], hor: [0.06, 0.06, 0.12], lamp: 1.35, night: 1, exposure: 1.25},
    {e: -0.06, sun: [0.02, 0.02, 0.03], sky: [0.12, 0.1, 0.16], zen: [0.05, 0.06, 0.16], hor: [0.4, 0.2, 0.18], lamp: 1.25, night: 0.7, exposure: 1.15},
    {e: 0.02, sun: [1.4, 0.55, 0.28], sky: [0.3, 0.24, 0.3], zen: [0.12, 0.15, 0.34], hor: [0.95, 0.46, 0.26], lamp: 1.1, night: 0.2, exposure: 1.08},
    {e: 0.2, sun: [2.0, 1.28, 0.72], sky: [0.44, 0.44, 0.52], zen: [0.22, 0.36, 0.7], hor: [1.0, 0.74, 0.52], lamp: 0.95, night: 0, exposure: 1.02},
    {e: 0.55, sun: [1.8, 1.5, 1.1], sky: [0.48, 0.56, 0.7], zen: [0.22, 0.44, 0.82], hor: [0.8, 0.82, 0.8], lamp: 0.82, night: 0, exposure: 1},
    {e: 1, sun: [1.8, 1.52, 1.14], sky: [0.5, 0.58, 0.72], zen: [0.2, 0.42, 0.82], hor: [0.78, 0.82, 0.82], lamp: 0.8, night: 0, exposure: 1},
  ];

  function targetHour() {
    if (S.timeMode === 'day') return 10.5;
    if (S.timeMode === 'night') return 22.5;
    if (S.timeMode === 'clock') {
      const now = new Date();
      return now.getHours() + now.getMinutes() / 60 + now.getSeconds() / 3600;
    }
    return S.hour;
  }

  let lastLight = new T.Vector3();
  function stepTime(dt) {
    if (S.timeMode === 'cycle') S.hour = (S.hour + dt * 24 / DAY_SECONDS) % 24;
    // Switching modes sweeps the sun round rather than jumping.
    const goal = targetHour();
    const diff = ((goal - S.shownHour + 36) % 24) - 12;
    S.shownHour = Math.abs(diff) < 0.001 ? goal : (S.shownHour + diff * Math.min(1, dt * 2.5) + 24) % 24;
    applyTimeOfDay(S.shownHour);
  }

  function applyTimeOfDay(hour) {
    const t = (hour - 6) / 24 * Math.PI * 2;
    const sun = new T.Vector3(Math.cos(t), Math.sin(t), -0.32).normalize();
    const e = sun.y;
    let a = SKY[0], b = SKY[1];
    for (let i = 0; i < SKY.length - 1; i++) if (e >= SKY[i].e && e <= SKY[i + 1].e) { a = SKY[i]; b = SKY[i + 1]; break; }
    const k = (e - a.e) / Math.max(1e-4, b.e - a.e);
    const mix = (x, y) => x + (y - x) * k;
    const mix3 = (x, y) => x.map((v, i) => mix(v, y[i]));
    // By day the sun lights the hall; by night, the moon opposite it.
    const light = e > -0.06 ? sun.clone() : sun.clone().negate();
    if (light.y < 0.04) light.y = 0.04;
    light.normalize();
    U.sunDir.value.copy(light);
    R.skyUniforms.sunPos.value.copy(sun);
    U.sunColor.value.setRGB(...mix3(a.sun, b.sun));
    U.skyColor.value.setRGB(...mix3(a.sky, b.sky));
    U.lampLevel.value = mix(a.lamp, b.lamp);
    R.skyUniforms.zenith.value.setRGB(...mix3(a.zen, b.zen));
    R.skyUniforms.horizon.value.setRGB(...mix3(a.hor, b.hor));
    R.skyUniforms.night.value = mix(a.night, b.night);
    S.exposure = mix(a.exposure, b.exposure);
    // Re-cast the shadows once the light has moved a visible amount.
    if (lastLight.angleTo(light) > 0.004) { lastLight.copy(light); shadowDirty = true; }
  }

  function timeLabel() {
    return `${gui.t('time')}: ${gui.t(TIME_LABEL[S.timeMode])}`;
  }

  // Hands on the grandfather clock in the foyer, telling the hall's time.
  const clockHands = {group: null, hour: null, minute: null};
  function buildClock() {
    if (clockHands.group) { scene.remove(clockHands.group); clockHands.group.traverse(o => o.geometry?.dispose()); clockHands.group = null; }
    const face = S.built?.clock?.face;
    if (!face) return;
    const mat = new T.MeshBasicMaterial({color: 0x241a12});
    const hand = (length, width) => {
      const geo = new T.BoxGeometry(0.004, length, width);
      geo.translate(0, length / 2 - 0.012, 0);
      const mesh = new T.Mesh(geo, mat);
      mesh.userData.noShadow = true;
      return mesh;
    };
    const group = new T.Group();
    clockHands.hour = hand(face.radius * 0.55, 0.018);
    clockHands.minute = hand(face.radius * 0.85, 0.012);
    clockHands.minute.position.x = 0.003;
    group.add(clockHands.hour, clockHands.minute);
    group.position.set(face.center[0] + face.normal[0] * 0.006, face.center[1], face.center[2] + face.normal[2] * 0.006);
    group.userData.noShadow = true;
    scene.add(group);
    clockHands.group = group;
  }
  function stepClock() {
    if (!clockHands.group) return;
    const h = S.shownHour;
    // Seen from the room (+x), clockwise runs from +y toward -z.
    clockHands.hour.rotation.x = -(h % 12) / 12 * Math.PI * 2;
    clockHands.minute.rotation.x = -(h % 1) * Math.PI * 2;
  }

  // ── Loop ───────────────────────────────────────────────────────────────
  let last = performance.now();
  let simTime = performance.now() / 1000;
  let frames = 0, slow = 0;
  const loop = {
    raf: 0,
    wake() { if (!loop.raf) { last = performance.now(); loop.raf = requestAnimationFrame(frame); } },
  };

  function targetPost() {
    const p = {focus: 8, aperture: 0.06, blurAll: 0, volumeLevel: 0.5, bloomLevel: 0.5, exposure: S.exposure || 1};
    if (S.mode === 'shelf' || S.mode === 'placing') { p.focus = shelfDistance(50) * S.zoom; p.aperture = 0.16; }
    if (S.mode === 'desk') { p.focus = 1.1; p.aperture = 0.9; }
    if (Book.open) p.blurAll = 0.55;
    if (gui.isModalOpen()) p.blurAll = 0.85;
    return p;
  }

  function frame(now) {
    loop.raf = 0;
    if (!S.visible || document.hidden) return;
    const dt = Math.min(0.1, (now - last) / 1000);
    last = now;
    update(dt, now / 1000);
    R.render();
    // Drop to Fast once if the machine clearly can't keep up.
    if (frames < 240) {
      frames++;
      if (frames > 60 && dt > 0.034) slow++;
      if (frames === 240 && slow > 120 && S.quality === 'fancy') { S.quality = 'fast'; applyQuality(); }
    }
    loop.wake();
  }

  function update(dt, time) {
    U.time.value = time;
    U.firePulse.value += (1 - U.firePulse.value) * Math.min(1, dt * 1.5);
    stepTime(dt);
    stepClock();
    stepWalk(dt);
    stepCamera(dt, time);
    stepTweens(dt);
    stepParticles(dt, time);
    ghostMat.uniforms.opacity.value = 0.42 + 0.14 * Math.sin(time * 2.4);
    if (floatingItem) {
      floatingItem.rotation.y = time * 1.2;
      floatingItem.position.y = floatingItem.userData.baseY + Math.sin(time * 2) * 0.08;
    }
    // Post settings ease toward the mode's look.
    const target = targetPost();
    const k = 1 - Math.exp(-dt * 4);
    for (const key of Object.keys(target)) R.post[key] += (target[key] - R.post[key]) * k;
    R.glassMaterial.uniforms.cameraPos.value.copy(camera.position);
    const pxScale = (R.renderer.domElement.height * 0.5) / Math.tan((camera.fov * Math.PI / 180) / 2);
    for (const p of Object.values(particles)) p.uniforms.pxScale.value = pxScale;
    if (shadowDirty && S.built) {
      R.renderShadow(S.built.bounds);
      shadowDirty = false;
    }
  }

  addEventListener('resize', () => {
    gui.rescale();
    R.resize(innerWidth, innerHeight, pixelRatio());
  });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) loop.wake(); });

  function finishLoading() {
    if (S.mode !== 'loading') return;
    $('loading').classList.add('done');
    started = true;
    setMode('overview');
    // Start a little high inside the door and settle to eye height.
    const start = overviewPose();
    view.pos.set(start.pos.x, 3.0, start.pos.z + 0.6);
    view.target.set(start.pos.x, 2.2, start.pos.z - 12);
    flyTo(overviewPose(), {duration: S.reducedMotion ? 0.2 : 2.2});
  }

  // ── Stand-alone preview ────────────────────────────────────────────────
  // Without the app (opening index.html in a browser) the page runs against
  // a small in-memory library so it can be looked at and tested.
  function createDemo() {
    const params = new URLSearchParams(location.search);
    const mcBase = params.get('mc');
    let nextId = 100;
    const span = (t, extra = {}) => ({t, ...extra});
    const body = spans => JSON.stringify({v: 1, spans});
    const subjects = [
      {id: 1, name: 'History', color: 14, books: [
        {id: 11, title: 'The Romans', spine: 'Romans', cover: 14, slot: 0, body: body([span('The Roman Republic', {b: true}), span('\nFounded in '), span('509 BC', {c: 'gold'}), span(', after the last king was overthrown.')])},
        {id: 12, title: 'Middle Ages', spine: '', cover: 12, slot: 1, body: body([span('Feudalism, castles and the plague.')])},
        {id: 13, title: 'World War I', spine: 'WW1', cover: 7, slot: 4, body: body([span('1914 – 1918', {u: true})])},
        {id: 14, title: 'Industrial Revolution', spine: '', cover: 15, slot: 12, body: body([span('Steam!', {i: true, c: 'dark_red'})])},
      ]},
      {id: 2, name: 'Physics', color: 11, books: [
        {id: 21, title: 'Newton', spine: '', cover: 11, slot: 2, body: body([span('F = ma', {b: true})])},
        {id: 22, title: 'Optics summary', spine: 'Optics', cover: 3, slot: 3, body: body([span('Light bends when it changes medium.')])},
      ]},
      {id: 3, name: 'Recipes', color: 13, books: [
        {id: 31, title: 'Pumpkin pie', spine: 'Pie', cover: 1, slot: 7, body: body([span('Pumpkin, sugar, egg.')])},
      ]},
    ];
    if (params.has('empty')) subjects.length = 0;
    const emit = m => setTimeout(() => receive(JSON.parse(JSON.stringify(m))), 20);
    const snapshot = () => emit({type: 'library', subjects});
    const findBook = id => { for (const s of subjects) { const b = s.books.find(x => x.id === id); if (b) return [s, b]; } return [null, null]; };
    const toBase64 = buf => { let s = ''; const bytes = new Uint8Array(buf); for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]); return btoa(s); };
    return {
      async handle(m) {
        switch (m.type) {
          case 'ready': emit({type: 'init', strings: {}}); snapshot(); break;
          case 'assetsWanted': {
            const files = {};
            if (mcBase) {
              await Promise.all(m.paths.map(async p => {
                try { const r = await fetch(mcBase + 'assets/minecraft/' + p); if (r.ok) files[p] = toBase64(await r.arrayBuffer()); } catch { /* missing */ }
              }));
            }
            emit({type: 'assets', source: mcBase ? 'Minecraft (dev)' : null, files});
            break;
          }
          case 'createSubject': {
            const id = nextId++;
            subjects.push({id, name: m.name, color: m.color ?? 5, books: []});
            emit({type: 'saved', request: m.request, id});
            snapshot();
            break;
          }
          case 'saveBook': {
            let id = m.id;
            const subject = subjects.find(s => s.id === m.subjectId);
            if (id == null) {
              id = nextId++;
              let slot = m.slot ?? 0;
              while (subject.books.some(b => b.slot === slot)) slot++;
              subject.books.push({id, title: m.title || 'Untitled', spine: m.spine, cover: m.cover ?? 12, slot, body: m.body});
            } else {
              const [, b] = findBook(id);
              Object.assign(b, {title: m.title || b.title, spine: m.spine, cover: m.cover ?? b.cover, body: m.body});
            }
            emit({type: 'saved', request: m.request, id});
            snapshot();
            break;
          }
          case 'moveBook': {
            const [from, b] = findBook(m.id);
            const to = subjects.find(s => s.id === m.subjectId);
            const other = to.books.find(x => x.slot === m.slot && x.id !== m.id);
            if (other) {
              if (from === to) other.slot = b.slot;
              else { let s = m.slot; while (to.books.some(x => x.slot === s)) s++; other.slot = s; }
            }
            from.books.splice(from.books.indexOf(b), 1);
            b.slot = m.slot;
            to.books.push(b);
            snapshot();
            break;
          }
          case 'deleteBook': { const [s, b] = findBook(m.id); if (s) s.books.splice(s.books.indexOf(b), 1); snapshot(); break; }
          case 'downloadVanilla': emit({type: 'downloadFailed', message: 'Preview only'}); break;
        }
      },
    };
  }

  // ── Start ──────────────────────────────────────────────────────────────
  gui.rescale();
  applyQuality();
  stepTime(0);
  $('time').textContent = timeLabel();
  $('loading-bar').style.width = '30%';

  async function announce() {
    await PixelFont.ready;
    $('loading-bar').style.width = '60%';
    send({type: 'ready'});
    send({type: 'assetsWanted', paths: LibraryTextures.wanted()});
    flush();
  }
  const hosted = !!(window.chrome?.webview || window.flutter_inappwebview);
  if (!hosted) demo = createDemo();
  announce();
  loop.wake();
  // If the app never answers with assets, build with luma's own textures.
  setTimeout(() => { if (!S.assetsReady) onAssets({files: {}}); }, 8000);

  // Hooks for driving the page from a browser console or a test harness.
  window.__library = {
    S, R, W,
    get hover() { return hover; },
    // Steps the simulation without waiting on the display.
    advance(seconds) {
      const steps = Math.round(seconds * 30);
      for (let i = 0; i < steps; i++) { simTime += 1 / 30; update(1 / 30, simTime); }
    },
    click(x, y) {
      pointer.x = x; pointer.y = y;
      updateHover();
      return click();
    },
    project(p) {
      const v = new T.Vector3(...p).project(camera);
      return [Math.round((v.x + 1) / 2 * innerWidth), Math.round((1 - v.y) / 2 * innerHeight)];
    },
  };
})();
