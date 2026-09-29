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
          $('weather').textContent = weatherLabel();
          $('sound-label').textContent = soundLabel();
          refreshVideo();
          if (m.reducedMotion) S.reducedMotion = true;
          refreshHud();
          break;
        case 'view':
          S.visible = m.visible !== false;
          if (S.visible) { loop.wake(); weather.audio.resume(); } else weather.audio.pause();
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
        // The reader's own skin, kept by the app; null goes back to the
        // default.
        case 'skin':
          // A lookup or file that didn't work leaves the current skin on.
          if (m.failed) { gui.toast(gui.t('skinFailed'), typeof m.failed === 'string' ? m.failed : ''); break; }
          skin.imported = m.data ? {data: m.data, model: m.model || null} : null;
          skin.label = m.data ? m.label || null : null;
          if (S.assetsReady) applySkin();
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
    px: 0, pz: 4.2, yaw: 0, pitch: 0.02, vel: [0, 0], stride: 0, goal: null, floor: 0,
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
  const weather = LibraryWeather.create(T, R);
  weather.reducedFlash = S.reducedMotion;
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
  // The reader's video settings, over the Fancy/Fast preset. They are a
  // per-viewer convenience, so they live in this browser only.
  const VIDEO_DEFAULTS = {bloom: 30, shafts: 40, brightness: 50, shadows: 'high', dof: true, grain: true, vignette: true, bobbing: true, fov: 70, particles: 'all', scale: 100};
  const V = {...VIDEO_DEFAULTS};
  try { Object.assign(V, JSON.parse(localStorage.getItem('library.video') || '{}')); } catch { /* storage blocked */ }
  const saveVideo = () => { try { localStorage.setItem('library.video', JSON.stringify(V)); } catch { /* storage blocked */ } };
  const SHADOW_SIZES = {low: 1024, high: 2048, ultra: 4096};
  const PARTICLE_SCALE = {all: 1, decreased: 0.5, minimal: 0.15};
  function pixelRatio() { return S.quality === 'fancy' ? Math.min(devicePixelRatio || 1, 2) : Math.min(devicePixelRatio || 1, 1); }
  function applyQuality() {
    const q = QUALITY[S.quality];
    const shadows = SHADOW_SIZES[V.shadows] || 2048;
    Object.assign(R.settings, q, {
      bloom: q.bloom && V.bloom > 0,
      volume: q.volume && V.shafts > 0,
      dof: q.dof && V.dof,
      shadowSize: S.quality === 'fancy' ? shadows : Math.min(1024, shadows),
      scale: Math.max(0.5, Math.min(1, V.scale / 100)),
      grain: V.grain ? 0.012 : 0,
      vignette: V.vignette ? 0.9 : 0,
      bloomThreshold: 1.0,
    });
    R.applySettings({});
    R.resize(innerWidth, innerHeight, pixelRatio());
    shadowDirty = true;
    particles.dust.mesh.visible = S.quality === 'fancy' && V.particles !== 'minimal';
    weather.particleScale = PARTICLE_SCALE[V.particles] ?? 1;
    refreshVideo();
  }
  // Brightness as the game's slider has it: moody at 0, bright at 100.
  const brightness = () => 0.72 + V.brightness / 100 * 0.56;

  // ── Scene objects ──────────────────────────────────────────────────────
  let worldMesh = null, glassMesh = null, dynMesh = null, ghostMesh = null;
  let shadowDirty = true, shadowInside = true;

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

  // ── The reader ─────────────────────────────────────────────────────────
  // Their skin: one they imported (kept by the app), else Steve from their
  // own Minecraft jar, else luma's painted default.
  const skin = {imported: null, label: null, vanilla: null, current: null, texture: null};
  async function applySkin() {
    let next = null;
    if (skin.imported) next = await LibrarySkin.load(skin.imported.data);
    if (next && skin.imported.model) next.slim = skin.imported.model === 'slim';
    if (!next && skin.vanilla) next = await LibrarySkin.load(skin.vanilla);
    if (!next) next = LibrarySkin.painted();
    skin.current = next;
    skin.texture?.dispose();
    const tex = new T.CanvasTexture(next.canvas);
    tex.flipY = false;
    tex.magFilter = T.NearestFilter;
    tex.minFilter = T.NearestFilter;
    tex.generateMipmaps = false;
    tex.colorSpace = T.SRGBColorSpace;
    skin.texture = tex;
    U.skin.value = tex;
    buildHand();
    buildSitter();
    refreshSkinLabel();
  }

  // The right arm in the corner of the view, as in the game: it bobs as
  // you walk, swings when you use something, and holds the book you carry.
  const handMat = R.blockMaterial({viewmodel: true});
  // The hand is drawn with the game's own fixed field of view.
  const handCam = new T.PerspectiveCamera(70, 1, 0.05, 10);
  const hand = {root: new T.Group(), arm: null, swing: 1, light: [1, 0, 0], lightAt: 0, lagYaw: 0, lagPitch: 0, slim: false};
  hand.root.userData.noShadow = true;
  scene.add(hand.root);
  function buildHand() {
    if (!S.built || !skin.current) return;
    if (hand.arm) { hand.root.remove(hand.arm); hand.arm.traverse(o => o.geometry?.dispose()); }
    const a = LibrarySkin.arm(T, S.built.grid, atlas, skin.current.slim, handMat, hand.light);
    hand.arm = a.pivot;
    hand.arm.matrixAutoUpdate = false;
    hand.slim = !!skin.current.slim;
    hand.root.add(hand.arm);
  }
  function swingArm() { hand.swing = 0; }
  const handShown = () => !!hand.arm && (S.mode === 'overview' || S.mode === 'seated' || S.mode === 'placing' || S.mode === 'climbing') && !Book.open;

  // The game's first-person arm, transform for transform: where the empty
  // main hand is put (ItemInHandRenderer.renderPlayerArm), then the arm's
  // pivot on the player model. `swing` runs 0 to 1 through a swing.
  const DEG = Math.PI / 180;
  const tmp = new T.Matrix4();
  function armMatrix(m, swing, equip, slim) {
    const f1 = Math.sqrt(swing);
    const f2 = -0.3 * Math.sin(f1 * Math.PI), f3 = 0.4 * Math.sin(f1 * Math.PI * 2), f4 = -0.4 * Math.sin(swing * Math.PI);
    const f5 = Math.sin(swing * swing * Math.PI), f6 = Math.sin(f1 * Math.PI);
    m.multiply(tmp.makeTranslation(f2 + 0.64, f3 - 0.6 - equip * 0.6, f4 - 0.72));
    m.multiply(tmp.makeRotationY(45 * DEG));
    m.multiply(tmp.makeRotationY(f6 * 70 * DEG));
    m.multiply(tmp.makeRotationZ(f5 * -20 * DEG));
    m.multiply(tmp.makeTranslation(-1, 3.6, 3.5));
    m.multiply(tmp.makeRotationZ(120 * DEG));
    m.multiply(tmp.makeRotationX(200 * DEG));
    m.multiply(tmp.makeRotationY(-135 * DEG));
    m.multiply(tmp.makeTranslation(5.6, 0, 0));
    // The arm's pivot on the model, then from this page's model space (y
    // up, facing +z) into the game's (y down, facing -z).
    m.multiply(tmp.makeTranslation(-5 / 16, (slim ? 2.5 : 2) / 16, 0));
    m.multiply(tmp.makeRotationX(Math.PI));
    return m;
  }
  function stepHand(dt, time) {
    hand.root.visible = handShown();
    if (!hand.root.visible) return;
    hand.root.position.copy(camera.position);
    hand.root.quaternion.copy(camera.quaternion);
    // The arm takes the light where the reader stands.
    if (time - hand.lightAt > 0.25) {
      hand.lightAt = time;
      const l = S.built.grid.sample([camera.position.x, camera.position.y - 0.4, camera.position.z], [0, 1, 0]);
      LibrarySkin.relight(hand.arm, l);
    }
    hand.swing = Math.min(1, hand.swing + dt / 0.3);
    const swing = hand.swing < 1 ? hand.swing : 0;
    // The arm trails the view a little as the head turns, as in the game.
    const k = 1 - Math.exp(-dt * 10);
    hand.lagYaw += (S.yaw - hand.lagYaw) * k;
    hand.lagPitch += (S.pitch - hand.lagPitch) * k;
    if (Math.abs(S.yaw - hand.lagYaw) > 1) hand.lagYaw = S.yaw;
    // View bobbing, applied to the hand as the game does.
    const moving = Math.min(1, Math.hypot(...S.vel) / 3) * (S.reducedMotion || !V.bobbing ? 0 : 1);
    const phase = S.stride * 1.6 * Math.PI, bob = 0.09 * moving;
    const m = hand.arm.matrix.identity();
    m.multiply(tmp.makeTranslation(Math.sin(phase) * bob * 0.5, -Math.abs(Math.cos(phase) * bob), 0));
    m.multiply(tmp.makeRotationZ(Math.sin(phase) * bob * 3 * DEG));
    m.multiply(tmp.makeRotationX(Math.abs(Math.cos(phase - 0.2) * bob) * 5 * DEG));
    m.multiply(tmp.makeRotationX(-(S.pitch - hand.lagPitch) * 0.1));
    m.multiply(tmp.makeRotationY(-(S.yaw - hand.lagYaw) * 0.1));
    armMatrix(m, swing, S.mode === 'placing' ? 0.1 : 0, hand.slim);
    hand.arm.matrixWorldNeedsUpdate = true;
    handCam.aspect = camera.aspect;
    handCam.updateProjectionMatrix();
    handMat.uniforms.handProjection.value.copy(handCam.projectionMatrix);
  }

  // Where the carried book sits: in the arm's hand.
  function handTransform() {
    if (!hand.arm) {
      const q = camera.quaternion.clone();
      return {pos: new T.Vector3(0.3, -0.28, -0.75).applyQuaternion(q).add(camera.position), quat: q, scale: 0.5};
    }
    hand.root.position.copy(camera.position);
    hand.root.quaternion.copy(camera.quaternion);
    hand.root.updateMatrixWorld(true);
    const pos = new T.Vector3(-1 / 16, -11 / 16, -0.5 / 16).applyMatrix4(hand.arm.matrixWorld);
    const q = camera.quaternion.clone();
    const tilt = new T.Quaternion().setFromEuler(new T.Euler(0.2, -0.6, 0.15));
    return {pos, quat: q.multiply(tilt).multiply(new T.Quaternion().setFromAxisAngle(new T.Vector3(0, 1, 0), Math.PI / 2)), scale: 0.5};
  }

  // The reader themself, sitting at the desk while a book is open on it.
  const sitter = {group: null, limbs: null, typing: -10};
  function buildSitter() {
    if (sitter.group) { scene.remove(sitter.group); sitter.group.traverse(o => o.geometry?.dispose()); sitter.group = null; }
    const chair = S.built?.desk?.chair;
    if (!chair || !skin.current) return;
    const light = S.built.grid.sample([chair.pos[0], chair.pos[1] + 0.8, chair.pos[2]], [0, 1, 0]);
    const p = LibrarySkin.player(T, S.built.grid, atlas, skin.current.slim, blockMat, light);
    const hips = 12 / 16 * p.group.scale.x;
    p.group.position.set(chair.pos[0], chair.pos[1] - hips + 0.02, chair.pos[2]);
    p.group.rotation.y = chair.yaw + Math.PI;
    for (const limb of Object.values(p.limbs)) limb.rotation.order = 'YXZ';
    p.limbs.rightLeg.rotation.set(-Math.PI / 2, 0.1, 0);
    p.limbs.leftLeg.rotation.set(-Math.PI / 2, -0.1, 0);
    p.group.visible = false;
    scene.add(p.group);
    Object.assign(sitter, p);
  }
  function stepSitter(time) {
    if (!sitter.group) return;
    const shown = S.mode === 'desk';
    if (sitter.group.visible !== shown) { sitter.group.visible = shown; shadowDirty = true; }
    if (!shown) return;
    const L = sitter.limbs;
    const typing = time - sitter.typing < 0.8 && !S.reducedMotion;
    const w = typing ? Math.sin(time * 16) : 0;
    L.rightArm.rotation.set(-1.18 + w * 0.05, 0.42 + w * 0.06, 0);
    L.leftArm.rotation.set(-1.08, -0.38, 0);
    const idle = S.reducedMotion ? 0 : Math.sin(time * 0.9) * 0.03;
    L.head.rotation.set(0.42 + idle + (typing ? 0.04 : 0), (typing ? Math.sin(time * 3) * 0.05 : 0) + 0.06, 0);
  }
  // Typing in the book moves the writing hand.
  document.addEventListener('input', () => { sitter.typing = performance.now() / 1000; });
  document.addEventListener('keydown', () => { if (Book.open) sitter.typing = performance.now() / 1000; });

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
      if (shape > 2.5) {
        // A falling leaf: a small square, the way the game's particles are.
        vec2 q = abs(p - 0.5);
        if (max(q.x, q.y) > 0.3) discard;
        a = 1.0;
      } else if (shape > 1.5) {
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
    leaves: new Particles(220, {shape: 3, additive: false}),
    smoke: new Particles(110, {additive: false}),
    splash: new Particles(260, {additive: false}),
  };
  // How much daylight there is, 0 at night to 1 by day, for things lit only
  // by the sky.
  const daylight = () => 1 - R.skyUniforms.night.value * 0.85;
  const rand = (a, b) => a + Math.random() * (b - a);

  function seedDust() {
    const b = S.built.bounds;
    particles.dust.clear();
    for (let i = 0; i < particles.dust.max * (PARTICLE_SCALE[V.particles] ?? 1); i++) {
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
    const pScale = weather.particleScale;
    // The wind pushes leaves, smoke and rain splashes along with it.
    const wx = Math.cos(weather.windAngle) * weather.wind * 2.5, wz = Math.sin(weather.windAngle) * weather.wind * 2.5;
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
    // Autumn: leaves come loose from the trees and flutter down.
    const day = daylight();
    const falling = built.trees.filter(t => t.kind !== 'spruce');
    if (falling.length && Math.random() < dt * 7 * (1 + weather.wind * 2) * pScale) {
      const t = falling[Math.floor(Math.random() * falling.length)];
      const f = 0.65 + Math.random() * 0.35;
      particles.leaves.add({
        p: [t.x + 0.5 + rand(-t.spread, t.spread), t.top - rand(0, 1.5), t.z + 0.5 + rand(-t.spread, t.spread)],
        v: [rand(-0.25, 0.35), -rand(0.35, 0.6), rand(-0.2, 0.3)], tint: t.tint.map(c => c * f), s: rand(0.06, 0.09), ph: rand(0, 6.28), age: 0, c: [0, 0, 0, 1],
      });
    }
    particles.leaves.step(dt, p => {
      p.age += dt;
      if (p.p[1] < 0.03 || p.age > 16) return false;
      p.p[0] += (p.v[0] + Math.sin(p.age * 2.1 + p.ph) * 0.35 + wx) * dt;
      p.p[1] += p.v[1] * dt;
      p.p[2] += (p.v[2] + Math.cos(p.age * 1.7 + p.ph) * 0.25 + wz) * dt;
      for (let k = 0; k < 3; k++) p.c[k] = p.tint[k] * (0.2 + day * 0.9);
      p.c[3] = Math.min(1, (16 - p.age) / 2);
      return true;
    });
    // Wood smoke curling up from the chimney.
    if (Math.random() < dt * 3.5) {
      const s = built.smoke;
      const g = rand(0.35, 0.5);
      particles.smoke.add({p: [s[0] + rand(-0.3, 0.3), s[1], s[2] + rand(-0.3, 0.3)], v: [rand(0.05, 0.25), rand(0.5, 0.8), rand(-0.1, 0.1)], c: [g, g, g, 0.5], g0: g, s: rand(0.35, 0.5), life: rand(4, 6.5), age: 0});
    }
    // And from the fire ring out on the island.
    if (built.campfire && Math.random() < dt * 2 * pScale) {
      const s = built.campfire;
      const g = rand(0.35, 0.5);
      particles.smoke.add({p: [s[0] + rand(-0.15, 0.15), s[1] + 0.4, s[2] + rand(-0.15, 0.15)], v: [rand(-0.05, 0.05), rand(0.4, 0.6), rand(-0.05, 0.05)], c: [g, g, g, 0.4], g0: g, s: rand(0.18, 0.28), life: rand(3, 5), age: 0});
    }
    if (built.campfire && Math.random() < dt * 5 * pScale) {
      const f = built.campfire;
      particles.embers.add({p: [f[0] + rand(-0.25, 0.25), f[1], f[2] + rand(-0.25, 0.25)], v: [rand(-0.1, 0.1), rand(0.5, 1), rand(-0.1, 0.1)], c: [2.6, 1.1, 0.3, 1], s: rand(0.015, 0.03), life: rand(0.8, 1.8), age: 0});
    }
    particles.smoke.step(dt, p => {
      p.age += dt;
      if (p.age > p.life) return false;
      for (let k = 0; k < 3; k++) p.p[k] += p.v[k] * dt;
      p.p[0] += wx * 0.4 * dt; p.p[2] += wz * 0.4 * dt;
      p.v[1] *= 0.995;
      p.s += dt * 0.28;
      for (let k = 0; k < 3; k++) p.c[k] = p.g0 * (0.25 + day * 0.9);
      p.c[3] = 0.45 * Math.min(1, p.age * 2) * (1 - p.age / p.life);
      return true;
    });
    // Rain splashing where it lands round the reader.
    let n = weather.rain * 110 * dt * pScale;
    while (n > 0 && built.heightmap) {
      if (n < 1 && Math.random() > n) break;
      n--;
      const x = camera.position.x + rand(-8, 8), z = camera.position.z + rand(-8, 8);
      const h = built.heightmap.at(x, z);
      if (h < -50) continue;
      const c = 0.2 + day * 0.6;
      particles.splash.add({p: [x, h + 0.03, z], v: [rand(-0.4, 0.4) + wx * 0.2, rand(0.7, 1.2), rand(-0.4, 0.4) + wz * 0.2], c: [c, c * 1.05, c * 1.2, 0.7], s: rand(0.025, 0.045), life: rand(0.18, 0.32), age: 0});
    }
    particles.splash.step(dt, p => {
      p.age += dt;
      if (p.age > p.life) return false;
      p.v[1] -= 7 * dt;
      for (let k = 0; k < 3; k++) p.p[k] += p.v[k] * dt;
      p.c[3] = 0.7 * (1 - p.age / p.life);
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
    skin.vanilla = files['textures/entity/player/wide/steve.png'] || null;
    rebuildWorld();
    await applySkin();
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
    weather.setWorld(built);
    U.fireOrigin.value.set(...built.fire);
    const b = built.bounds;
    R.post.box = {min: [b.min[0] + 1, 0, b.min[2] + 0.5], max: [b.max[0] - 1, built.layout.top, b.max[2] - 0.5]};
    if (S.floor >= built.layout.floors) S.floor = 0;
    shadowDirty = true;
    if (S.caseSubject != null) {
      const idx = built.cases.findIndex(c => c.subject && c.subject.id === S.caseSubject);
      if (idx < 0 && (S.mode === 'shelf' || S.mode === 'placing')) toOverview();
      S.caseIndex = idx;
    }
    if (blocked(S.px, S.pz)) { S.px = 0; S.pz = built.layout.hallStart - 1.8; }
    buildDoor();
    buildHand();
    buildSitter();
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
        if (Math.floor(book.slot / c.slots) !== c.page) continue;
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
    // The plate fills the fascia, which is shallower on the low cases
    // upstairs.
    const P = c.profile || W.PROFILES.ground;
    const fascia = P.caseTop - 0.125 - P.shelfTop;
    const w = Math.min(2.3, fascia * 0.92 * 4), h = w / 4;
    const u0 = (c.spec.width - w) / 2, v0 = P.shelfTop + (fascia - h) / 2;
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
    const floatY = c.y0 + (c.floor ? 1.8 : 2.2);
    floatingItem.position.set(c.faceX + c.facing * 0.55, floatY, (c.z0 + c.z1) / 2);
    floatingItem.userData.noShadow = true;
    floatingItem.userData.baseY = floatY;
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
        for (let y = 0; y < Math.ceil(c.profile.caseTop); y++) for (let z = c.z0; z < c.z1; z++) {
          setTimeout(() => poof([c.faceX - c.facing * 0.5, c.y0 + y + 0.5, z + 0.5], 3, 0.4), y * 110 + (z - c.z0) * 50);
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
    const bob = S.reducedMotion || !V.bobbing ? 0 : Math.sin(S.stride * 5.2) * 0.035 * Math.min(1, Math.hypot(...S.vel) / 2);
    const pos = new T.Vector3(S.px, floorY() + W.HALL.eye + Math.abs(bob), S.pz);
    const dir = new T.Vector3(-Math.sin(S.yaw) * Math.cos(S.pitch), Math.sin(S.pitch), -Math.cos(S.yaw) * Math.cos(S.pitch));
    return {pos, target: pos.clone().addScaledVector(dir, 6), fov: walkFov()};
  }
  // Where the floor the reader is on lies.
  const floorY = () => S.built?.layout.bases[S.floor] || 0;
  // The field of view setting; phones held upright see little of the
  // hall's width, so it is widened for them.
  const walkFov = () => V.fov + (innerWidth < innerHeight ? 8 : 0);

  const SHELF_CENTER = 3.3;
  // Half the height the bookcase view has to take in: the tall cases
  // downstairs, or the low ones under the eaves.
  const caseHalf = c => (c && c.floor ? 2.05 : 2.75);
  function shelfDistance(fov, half = 2.75) {
    const v = Math.tan((fov * Math.PI / 180) / 2);
    const aspect = innerWidth / Math.max(1, innerHeight);
    // Room for the whole case, cabinets to name plate.
    return Math.min(7.4, Math.max(half / v, 2.3 / (v * aspect)));
  }

  function shelfPose(i) {
    const c = S.built.cases[i];
    const fov = 50;
    const d = shelfDistance(fov, caseHalf(c)) * S.zoom;
    const P = c.profile || W.PROFILES.ground;
    const cy = c.y0 + (c.floor ? (P.shelfBottom + P.caseTop) / 2 + 0.1 : SHELF_CENTER) + S.panY;
    const zc = (c.z0 + c.z1) / 2 + S.pan;
    return {pos: new T.Vector3(c.faceX + c.facing * d, cy - 0.3 * S.zoom, zc), target: new T.Vector3(c.faceX, cy, zc), fov};
  }

  // How far the bookcase view may pan at the current zoom.
  function clampShelfView() {
    const slack = 1 - S.zoom;
    const across = 0.9 + slack * 1.6;
    const tall = currentCase()?.floor ? 1.4 : 2.2;
    S.pan = Math.max(-across, Math.min(across, S.pan));
    S.panY = Math.max(-tall * slack, Math.min(tall * slack, S.panY));
  }

  // Writing is watched from behind the chair, off to the right: you see
  // yourself at the desk in the left of the view, clear of the open book
  // in the middle of the screen.
  function deskPose() {
    const desk = S.built.desk, chair = desk.chair;
    const z = chair ? chair.pos[2] : desk.z + 1;
    // Upright phones have no room beside the book; look over the shoulder.
    if (innerWidth < innerHeight) return {pos: new T.Vector3(0.9, 2.3, z + 1.6), target: new T.Vector3(0, 0.95, desk.z + 0.1), fov: 60};
    return {pos: new T.Vector3(1.9, 2.15, z + 1.5), target: new T.Vector3(0.6, 0.95, desk.z - 0.2), fov: 50};
  }

  // Sitting: eyes a head above the seat, looking wherever the reader turns.
  function seatedPose() {
    const seat = S.seat;
    const dir = new T.Vector3(-Math.sin(S.yaw) * Math.cos(S.pitch), Math.sin(S.pitch), -Math.cos(S.yaw) * Math.cos(S.pitch));
    const pos = new T.Vector3(seat.pos[0], seat.pos[1] + 1.1, seat.pos[2]);
    return {pos, target: pos.clone().addScaledVector(dir, 6), fov: walkFov()};
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
      if (!S.reducedMotion && V.bobbing) bob = arc * Math.min(1, flight.dist * 0.2);
      if (flight.t >= 1) { const done = flight.resolve; flight = null; done(); }
    } else {
      const target = baseModePose();
      if (target) {
        // Walking and sitting follow the head closely; the other views glide.
        const k = 1 - Math.exp(-dt * (S.mode === 'overview' || S.mode === 'seated' ? 16 : 6));
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
    if (S.mode === 'seated' && S.seat) return seatedPose();
    if ((S.mode === 'shelf' || S.mode === 'placing') && S.caseIndex >= 0) return shelfPose(S.caseIndex);
    if (S.mode === 'desk') return deskPose();
    return null;
  }

  // ── Looking around ─────────────────────────────────────────────────────
  // As in the game, a click captures the mouse: after that it turns your
  // head without any button held, a crosshair marks what you would use,
  // and Esc lets go. Touch screens drag to look instead.
  const look = {locked: false, resume: false};
  const looking = mode => mode === 'overview' || mode === 'seated' || mode === 'climbing';
  function lockPointer() {
    if (S.touch || !canvas.requestPointerLock || look.locked) return;
    try {
      const p = canvas.requestPointerLock();
      if (p && p.catch) p.catch(() => {});
    } catch { /* not allowed right now; the next click tries again */ }
  }
  document.addEventListener('pointerlockchange', () => {
    look.locked = document.pointerLockElement === canvas;
    $('crosshair').hidden = !look.locked;
    if (!look.locked) { setHover(null); keys.clear(); }
    refreshHud();
  });
  document.addEventListener('pointerlockerror', () => { look.locked = false; });

  // ── Modes ──────────────────────────────────────────────────────────────
  function setMode(mode) {
    // Menus and bookcases need the cursor back; walking takes it again if
    // it was captured before.
    if (look.locked && !looking(mode)) { look.resume = true; document.exitPointerLock(); }
    if (looking(mode) && look.resume) { look.resume = false; lockPointer(); }
    S.mode = mode;
    refreshHud();
    rebuildA11y();
  }

  // Back on your feet, a couple of steps back from the case you were at.
  function toOverview() {
    const c = currentCase();
    if (c && S.mode !== 'overview') {
      const x = c.faceX + c.facing * 2.2, z = (c.z0 + c.z1) / 2 + S.pan;
      if (!blocked(x, z, c.floor)) {
        S.floor = c.floor;
        S.px = x; S.pz = z;
        S.yaw = c.facing * Math.PI / 2;
        S.pitch = 0.12;
      }
    }
    S.seat = null;
    setMode('overview');
    S.caseSubject = null;
    S.caseIndex = -1;
    S.vel = [0, 0];
    S.goal = null;
    return flyTo(overviewPose());
  }

  // Sits down on `seat`; on a bench, at the spot that was clicked.
  function sit(seat, at) {
    const pos = seat.pos.slice();
    if (seat.along && at) {
      const k = seat.alongX ? 0 : 2;
      pos[k] = Math.max(seat.along[0], Math.min(seat.along[1], at[k]));
    }
    S.stand = [S.px, S.pz];
    S.seat = {...seat, pos};
    S.yaw = seat.yaw;
    S.pitch = seat.desk ? -0.35 : -0.05;
    S.vel = [0, 0];
    S.goal = null;
    setMode('seated');
    return flyTo(seatedPose(), {duration: S.reducedMotion ? 0.2 : 0.6});
  }

  // Gets up again, a step in front of the seat if there is room.
  function standUp() {
    const seat = S.seat;
    if (!seat) return setMode('overview');
    const fx = -Math.sin(seat.yaw), fz = -Math.cos(seat.yaw);
    const front = [seat.pos[0] + fx * 0.75, seat.pos[2] + fz * 0.75];
    if (!blocked(...front)) { S.px = front[0]; S.pz = front[1]; }
    else if (S.stand) { S.px = S.stand[0]; S.pz = S.stand[1]; }
    S.seat = null;
    setMode('overview');
    return flyTo(overviewPose(), {duration: S.reducedMotion ? 0.2 : 0.45});
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
    const pages = Math.max(1, Math.floor(max / c.slots) + 1);
    const lastFull = c.subject.books.filter(b => Math.floor(b.slot / c.slots) === pages - 1).length >= c.slots;
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
    const seated = S.mode === 'seated';
    $('back').hidden = !(inCase || seated);
    $('back').textContent = gui.t(S.mode === 'placing' ? 'cancel' : seated ? 'standUp' : 'back');
    const others = S.built ? S.built.cases.filter(cs => cs.subject).length : 0;
    // The arrows step between bookcases, so they only show at one.
    $('case-prev').hidden = $('case-next').hidden = !(inCase && others > 1);
    const empty = S.subjects.length === 0 && S.mode === 'overview';
    let hint = '';
    if (S.mode === 'placing') hint = gui.t('moveHint');
    else if (seated) hint = S.touch ? '' : gui.t('standHint');
    else if (empty) hint = gui.t('emptyHall');
    else if (S.mode === 'overview' && !S.walked) hint = gui.t('walkHint');
    else if (S.mode === 'overview' && !look.locked && !S.touch) hint = gui.t('lookHint');
    gui.actionbar(hint);
    $('settings-open').hidden = S.mode === 'desk';
    $('move-pad').hidden = !(S.mode === 'overview' && S.touch);
    $('crosshair').hidden = !(look.locked && looking(S.mode));
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
    return [[Math.min(x0, x1), c.y0, c.z0], [Math.max(x0, x1), c.y1, c.z1]];
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
    for (let local = 0; local < c.slots; local++) {
      const g = W.slotGeometry(c, local);
      const pad = 0.5 / 16;
      if (p.y >= g.y0 - pad && p.y <= g.y1 + pad && p.z >= g.z0 - pad && p.z <= g.z1 + pad) {
        const slot = c.page * c.slots + local;
        return {slot, g, book: c.subject.books.find(b => b.slot === slot && !S.hidden.has(b.id)) || null};
      }
    }
    return null;
  }

  // How far along the ray the first wall is: bookcases and furniture behind
  // a wall can't be clicked through it. Walks the grid a cell at a time;
  // bookcases themselves don't count, their fronts are what you click.
  function wallDistance(ray, max = 80) {
    const g = S.built.grid, o = ray.origin, d = ray.direction;
    const cell = [Math.floor(o.x), Math.floor(o.y), Math.floor(o.z)];
    const dir = [d.x, d.y, d.z], at = [o.x, o.y, o.z];
    const step = dir.map(Math.sign);
    const delta = dir.map(v => (v ? Math.abs(1 / v) : Infinity));
    const next = dir.map((v, k) => (v > 0 ? (cell[k] + 1 - at[k]) / v : v < 0 ? (at[k] - cell[k]) / -v : Infinity));
    let t = 0;
    while (t < max) {
      const b = g.get(cell[0], cell[1], cell[2]);
      if (b && b.opaque && !b.custom) return t;
      const k = next[0] < next[1] ? (next[0] < next[2] ? 0 : 2) : next[1] < next[2] ? 1 : 2;
      t = next[k];
      cell[k] += step[k];
      next[k] += delta[k];
    }
    return Infinity;
  }

  // What the reader is pointing at while walking or sitting: a bookcase
  // anywhere in sight, or a seat or the door within arm's reach.
  const REACH = 4.5;
  // Bookcases can be picked from further off, but not from across the hall.
  const CASE_REACH = 6.5;
  function doorBox() {
    const z = S.built.door.z;
    return [[-1, 0, z - (door.open > 0.5 ? 1 : 0.1)], [1, S.built.door.height || 2, z + 0.3]];
  }
  // What a click on the stair well does from this floor: up from the steps,
  // down from the opening.
  function stairBoxes() {
    const st = S.built?.stairs;
    if (!st) return [];
    const bases = S.built.layout.bases, b = bases[S.floor];
    const up = S.floor < bases.length - 1, down = S.floor > 0;
    const out = [];
    if (up) out.push({dir: 1, box: [[st.x0, b + (down ? 0.35 : 0), st.z0], [st.x0 + 3, b + 2.6, st.z0 + 3]]});
    if (down) out.push({dir: -1, box: [[st.x0, b - 1, st.z0], [st.x0 + 3, b + (up ? 0.35 : 2.6), st.z0 + 3]]});
    return out;
  }
  function pickWorld(ray) {
    const wall = wallDistance(ray) + 0.05;
    let best = null;
    const consider = (t, h) => { if (t != null && t <= wall && (!best || t < best.t)) best = {...h, t}; };
    const c = pickCase(ray);
    if (c && c.t <= CASE_REACH) consider(c.t, {kind: 'case', i: c.i});
    for (const s of stairBoxes()) {
      const t = boxHit(ray, ...s.box);
      if (t != null && t < REACH) consider(t, {kind: 'stairs', dir: s.dir, box: s.box});
    }
    S.built.seats.forEach((seat, i) => {
      if (S.seat && S.seat.box === seat.box) return;
      const t = boxHit(ray, ...seat.box);
      if (t != null && t < REACH) consider(t, {kind: 'seat', i, at: ray.at(t, new T.Vector3()).toArray()});
    });
    const t = S.floor === 0 ? boxHit(ray, ...doorBox()) : null;
    if (t != null && t < REACH) consider(t, {kind: 'door'});
    return best;
  }

  let hover = null;
  function updateHover() {
    if (!S.built || pointer.dragging || Book.open || gui.isModalOpen() || flight) { setHover(null); return; }
    const [x, y] = look.locked ? [innerWidth / 2, innerHeight / 2] : [pointer.x, pointer.y];
    const ray = rayAt(x, y);
    if (looking(S.mode)) {
      setHover(pickWorld(ray), x, y);
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

  function outlineBox([min, max]) {
    outline.position.set((min[0] + max[0]) / 2, (min[1] + max[1]) / 2, (min[2] + max[2]) / 2);
    outline.scale.set(max[0] - min[0] + 0.01, max[1] - min[1] + 0.01, max[2] - min[2] + 0.01);
    outline.visible = true;
  }

  function setHover(h, x = pointer.x, y = pointer.y) {
    hover = h;
    outline.visible = false;
    slotHi.visible = false;
    canvas.classList.toggle('pointer', !!h);
    if (!h) { gui.tooltip(null); return; }
    if (h.kind === 'case') {
      const c = S.built.cases[h.i];
      outlineBox(caseBox(c));
      gui.tooltip(c.subject ? [c.subject.name, gui.t('books', c.subject.books.length)] : [gui.t('newCase')], x, y);
    } else if (h.kind === 'seat') {
      outlineBox(S.built.seats[h.i].box);
      gui.tooltip([gui.t('sit')], x, y);
    } else if (h.kind === 'door') {
      outlineBox(doorBox());
      gui.tooltip([gui.t(door.target ? 'closeDoor' : 'openDoor')], x, y);
    } else if (h.kind === 'stairs') {
      outlineBox(h.box);
      gui.tooltip([gui.t(h.dir > 0 ? 'upstairs' : 'downstairs')], x, y);
    } else {
      const g = h.g;
      // Over a book the highlight covers just its spine; over an empty
      // slot, the gap it would fill.
      if (h.book && S.mode !== 'placing') {
        const {w, h: bh, back} = W.bookDims(h.book);
        const center = W.bookCenter(g, h.book).pos;
        slotHi.position.set(g.faceX - g.facing * (back - 0.004), center[1], center[2]);
        slotHi.scale.set(w + 0.01, bh + 0.01, 1);
      } else {
        slotHi.position.set(g.faceX + g.facing * 0.004, (g.y0 + g.y1) / 2 - 0.04, (g.z0 + g.z1) / 2);
        slotHi.scale.set((g.z1 - g.z0) * 0.86, (g.y1 - g.y0) * 0.78, 1);
      }
      slotHi.rotation.set(0, g.facing > 0 ? Math.PI / 2 : -Math.PI / 2, 0);
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
    const t = (floorY() - ray.origin.y) / ray.direction.y;
    const p = ray.origin.clone().addScaledVector(ray.direction, t);
    if (t > 30 || blocked(p.x, p.z)) return;
    S.goal = [p.x, p.z];
    poof([p.x, 0.08, p.z], 3, 0.06);
  }

  async function click() {
    if (S.mode === 'climbing') return;
    if (look.locked || S.mode === 'overview') swingArm();
    if (!hover) {
      if (S.mode === 'overview' && S.built && !flight && !look.locked) walkToward(pointer.x, pointer.y);
      return;
    }
    const h = hover;
    setHover(null);
    if (h.kind === 'case') {
      const c = S.built.cases[h.i];
      if (c.placeholder) await newCase();
      else await toShelf(h.i, {placing: S.mode === 'placing'});
    } else if (h.kind === 'seat') {
      await sit(S.built.seats[h.i], h.at);
    } else if (h.kind === 'door') {
      toggleDoor();
    } else if (h.kind === 'stairs') {
      await climb(h.dir);
    } else if (h.kind === 'slot') {
      if (S.mode === 'placing') await placeHeld(h.slot, h.g);
      else openSlot(h.slot, h.g, h.book);
    }
  }

  // ── Flows ──────────────────────────────────────────────────────────────
  // Lets go of the mouse for a dialog; walking takes it back afterwards.
  function freeMouse() {
    if (!look.locked) return;
    look.resume = true;
    document.exitPointerLock();
  }

  async function newCase() {
    const c = S.built.placeholder;
    freeMouse();
    const result = await gui.askName({title: gui.t('newCaseTitle'), color: [14, 11, 13, 1, 10, 9][S.subjects.length % 6]});
    if (!result) {
      if (look.resume && looking(S.mode)) { look.resume = false; lockPointer(); }
      return;
    }
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
  // WASD or the arrow keys walk, the mouse looks around, the wheel steps
  // forward and back. Walls, bookcases, furniture and a shut door stop you,
  // and so does the island's edge: there has to be ground underfoot.
  const BODY = 0.26;
  // Whether the reader can't stand at (x, z) on `floor`: there must be
  // floor underfoot and nothing in the way at body height.
  function blocked(x, z, floor = S.floor) {
    const b = S.built;
    if (!b) return false;
    const y = b.layout.bases[floor] || 0;
    for (const [dx, dz] of [[-BODY, -BODY], [BODY, -BODY], [-BODY, BODY], [BODY, BODY]]) {
      const cx = Math.floor(x + dx), cz = Math.floor(z + dz);
      if (!b.grid.solid(cx, y - 1, cz)) return true;
      if (b.grid.solid(cx, y, cz) || b.grid.solid(cx, y + 1, cz)) return true;
    }
    for (const list of [b.colliders, floor === 0 ? door.colliders : []]) {
      for (const [x0, z0, x1, z1, f] of list) {
        if ((f || 0) !== floor) continue;
        if (x > x0 - BODY && x < x1 + BODY && z > z0 - BODY && z < z1 + BODY) return true;
      }
    }
    return false;
  }

  // Up or down the spiral stair: round the newel a step at a time, then
  // off onto the landing.
  async function climb(dir) {
    const st = S.built?.stairs, bases = S.built?.layout.bases;
    const to = S.floor + dir;
    if (!st || to < 0 || to >= bases.length) return;
    const flight = st.flights[Math.min(S.floor, to)];
    const rise = flight.rise;
    let path = [
      [st.x0 - 0.5, flight.base, st.z0 + 2.5],
      ...st.ring.map(([x, z], k) => [x + 0.5, flight.base + (k + 1) * rise, z + 0.5]),
      [st.cx + 0.5, flight.base + st.ring.length * rise, st.z0 + 3.5],
    ];
    if (dir < 0) path = path.reverse();
    S.goal = null;
    S.vel = [0, 0];
    setMode('climbing');
    let yaw = S.yaw;
    for (let i = 0; i < path.length; i++) {
      const p = path[i], q = i ? path[i - 1] : [view.pos.x, 0, view.pos.z];
      if (Math.hypot(p[0] - q[0], p[2] - q[2]) > 0.05) yaw = Math.atan2(-(p[0] - q[0]), -(p[2] - q[2]));
      const pos = new T.Vector3(p[0], p[1] + W.HALL.eye, p[2]);
      const look = new T.Vector3(-Math.sin(yaw), dir > 0 ? 0.3 : -0.35, -Math.cos(yaw));
      await flyTo({pos, target: pos.clone().addScaledVector(look, 4), fov: walkFov()}, {duration: S.reducedMotion ? 0.05 : i === 0 ? 0.45 : 0.19});
      S.stride += 0.6;
      if (S.mode !== 'climbing') return;
    }
    const end = path[path.length - 1];
    S.floor = to;
    S.px = end[0]; S.pz = end[2];
    S.yaw = yaw; S.pitch = 0;
    setMode('overview');
    rebuildA11y();
  }

  // ── The front door ─────────────────────────────────────────────────────
  // Two leaves swinging inward on their hinges; a shut door is a wall.
  const door = {leaves: [], open: 0, target: 0, colliders: []};
  function buildDoor() {
    for (const leaf of door.leaves) { scene.remove(leaf); leaf.geometry.dispose(); }
    door.leaves = [];
    const d = S.built.door;
    const light = S.built.grid.sample([0, 1, d.z - 0.5], [0, 0, -1]);
    for (const [hx, dir] of d.hinges) {
      const mb = new W.MeshBuilder();
      LibraryFurniture.doorLeaf({mb, grid: S.built.grid, atlas}, dir < 0, light);
      const mesh = new T.Mesh(mb.geometry(T), blockMat);
      mesh.position.set(hx, 0, d.z);
      mesh.userData.swing = dir;
      scene.add(mesh);
      door.leaves.push(mesh);
    }
    poseDoor();
  }
  function poseDoor() {
    const e = easeInOut(door.open);
    for (const leaf of door.leaves) leaf.rotation.y = leaf.userData.swing * e * Math.PI / 2;
    const z = S.built.door.z;
    // Shut, the doorway is closed; open, each leaf lies along the wall.
    door.colliders = door.open < 0.5 ? [[-1, z, 1, z + 0.2]] : [[-1, z - 1, -0.8, z], [0.8, z - 1, 1, z]];
    shadowDirty = true;
  }
  function toggleDoor() {
    door.target = door.target ? 0 : 1;
    swingArm();
  }
  function stepDoor(dt) {
    if (door.open === door.target || !door.leaves.length) return;
    const step = dt * (S.reducedMotion ? 10 : 2.4);
    door.open = door.target > door.open ? Math.min(door.target, door.open + step) : Math.max(door.target, door.open - step);
    poseDoor();
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
    pointer.down = {x: e.clientX, y: e.clientY, yaw: S.yaw, pitch: S.pitch, pan: S.pan, panY: S.panY, wasLocked: look.locked};
    pointer.dragging = false;
    // The first click while walking captures the mouse, as in the game.
    if (e.pointerType === 'mouse' && !look.locked && looking(S.mode) && !flight) lockPointer();
    if (!look.locked) canvas.setPointerCapture(e.pointerId);
  });
  canvas.addEventListener('pointermove', e => {
    if (look.locked) {
      // Captured: the mouse turns the head, no button needed.
      const sens = 0.0026;
      S.yaw -= (e.movementX || 0) * sens;
      S.pitch = Math.max(-1.45, Math.min(1.45, S.pitch - (e.movementY || 0) * sens));
      if (Math.abs(e.movementX) + Math.abs(e.movementY) > 2) noteWalked();
      return;
    }
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
        if (looking(S.mode)) {
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
    const down = pointer.down;
    pointer.down = null;
    pointer.dragging = false;
    canvas.classList.remove('grab');
    if (!wasDrag && down && e.type === 'pointerup') {
      // The click that captured the mouse only captures it.
      if (look.locked && !down.wasLocked) return;
      if (!look.locked) { pointer.x = e.clientX; pointer.y = e.clientY; }
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
      else if (S.mode === 'seated') standUp();
    } else if (S.mode === 'seated') {
      // Sneak, jump or walk to get up, as when dismounting in the game.
      if (/^(Key[WASD]|Arrow(Up|Down)|Shift(Left|Right)|Space)$/.test(e.code) && !flight) {
        e.preventDefault();
        standUp();
      }
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

  $('back').onclick = () => (S.mode === 'placing' ? cancelPlacing() : S.mode === 'seated' ? standUp() : toOverview());
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
  $('settings-open').onclick = () => { $('settings').hidden = false; $('video-open').focus(); };
  $('settings-done').onclick = () => { $('settings').hidden = true; };
  $('settings').addEventListener('keydown', e => { if (e.key === 'Escape') { e.stopPropagation(); $('settings').hidden = true; } });
  $('video-open').onclick = () => { $('settings').hidden = true; $('video').hidden = false; $('video-options').querySelector('button, input')?.focus(); };
  const closeVideo = () => { $('video').hidden = true; $('settings').hidden = false; $('video-open').focus(); };
  $('video-done').onclick = closeVideo;
  $('video').addEventListener('keydown', e => { if (e.key === 'Escape') { e.stopPropagation(); closeVideo(); } });

  // The video settings screen: buttons that cycle through values and
  // sliders, two columns, as the game lays them out.
  const onOff = v => gui.t(v ? 'on' : 'off');
  const VIDEO_OPTIONS = [
    {key: 'quality', kind: 'cycle', values: ['fancy', 'fast'], get: () => S.quality, set: v => { S.quality = v; try { localStorage.setItem('library.quality', v); } catch { /* storage blocked */ } }, label: v => `${gui.t('quality')}: ${gui.t(v === 'fancy' ? 'qualityHigh' : 'qualityLow')}`},
    {key: 'shadows', kind: 'cycle', values: ['low', 'high', 'ultra'], label: v => gui.t('shadows', gui.t('shadows' + v[0].toUpperCase() + v.slice(1)))},
    {key: 'bloom', kind: 'slider', min: 0, max: 100, step: 5, label: v => gui.t('bloom', v ? v + '%' : gui.t('off'))},
    {key: 'shafts', kind: 'slider', min: 0, max: 100, step: 5, label: v => gui.t('lightShafts', v ? v + '%' : gui.t('off'))},
    {key: 'brightness', kind: 'slider', min: 0, max: 100, step: 5, label: v => gui.t('brightness', v === 0 ? gui.t('brightnessMoody') : v === 100 ? gui.t('brightnessBright') : v + '%')},
    {key: 'fov', kind: 'slider', min: 50, max: 110, step: 1, label: v => gui.t('fov', v === 70 ? gui.t('fovNormal') : v)},
    {key: 'scale', kind: 'slider', min: 50, max: 100, step: 5, live: false, label: v => gui.t('renderScale', v + '%')},
    {key: 'particles', kind: 'cycle', values: ['all', 'decreased', 'minimal'], label: v => gui.t('particles', gui.t('particles' + v[0].toUpperCase() + v.slice(1)))},
    {key: 'dof', kind: 'toggle', label: v => gui.t('depthOfField', onOff(v))},
    {key: 'bobbing', kind: 'toggle', label: v => gui.t('bobbing', onOff(v))},
    {key: 'grain', kind: 'toggle', label: v => gui.t('grain', onOff(v))},
    {key: 'vignette', kind: 'toggle', label: v => gui.t('vignette', onOff(v))},
  ];
  const videoControls = new Map();
  function buildVideo() {
    const box = $('video-options');
    for (const o of VIDEO_OPTIONS) {
      const get = o.get || (() => V[o.key]);
      const set = o.set || (v => { V[o.key] = v; saveVideo(); });
      if (o.kind === 'slider') {
        const wrap = document.createElement('label');
        wrap.className = 'mc-slider';
        const input = document.createElement('input');
        input.type = 'range'; input.min = o.min; input.max = o.max; input.step = o.step;
        const text = document.createElement('span');
        wrap.append(input, text);
        input.addEventListener('input', () => {
          set(Number(input.value));
          text.textContent = o.label(Number(input.value));
          if (o.live !== false) applyLive();
        });
        input.addEventListener('change', () => applyQuality());
        box.append(wrap);
        videoControls.set(o.key, () => { input.value = get(); text.textContent = o.label(get()); input.setAttribute('aria-valuetext', text.textContent); });
      } else {
        const b = document.createElement('button');
        b.type = 'button'; b.className = 'mc-button' + (gui.sprites['--btn'] ? ' sprite' : '');
        if (o.key === 'quality') b.id = 'quality';
        b.onclick = () => {
          const v = get();
          set(o.kind === 'toggle' ? !v : o.values[(o.values.indexOf(v) + 1) % o.values.length]);
          applyQuality();
        };
        box.append(b);
        videoControls.set(o.key, () => { b.textContent = o.label(get()); });
      }
    }
  }
  function refreshVideo() { for (const update of videoControls.values()) update(); }
  // Sliders that only change the look of the next frame don't rebuild
  // anything while being dragged.
  function applyLive() {
    R.settings.bloom = QUALITY[S.quality].bloom && V.bloom > 0;
    R.settings.volume = QUALITY[S.quality].volume && V.shafts > 0;
  }

  // Weather, and how loud it is.
  const WEATHER_LABEL = {clear: 'weatherClear', rain: 'weatherRain', storm: 'weatherStorm', thunder: 'weatherThunder', cycle: 'weatherCycle'};
  let weatherMode = 'cycle', soundLevel = 70;
  try { weatherMode = localStorage.getItem('library.weather') || 'cycle'; } catch { /* storage blocked */ }
  try { soundLevel = Number(localStorage.getItem('library.sound') ?? 70); } catch { /* storage blocked */ }
  if (!Number.isFinite(soundLevel)) soundLevel = 70;
  const weatherLabel = () => gui.t('weather', gui.t(WEATHER_LABEL[weatherMode] || 'weatherClear'));
  const soundLabel = () => gui.t('sound', soundLevel ? soundLevel + '%' : gui.t('off'));
  $('weather').onclick = () => {
    const modes = LibraryWeather.MODES;
    weatherMode = modes[(modes.indexOf(weatherMode) + 1) % modes.length];
    try { localStorage.setItem('library.weather', weatherMode); } catch { /* storage blocked */ }
    weather.setMode(weatherMode);
    $('weather').textContent = weatherLabel();
  };
  $('sound').addEventListener('input', () => {
    soundLevel = Number($('sound').value);
    try { localStorage.setItem('library.sound', String(soundLevel)); } catch { /* storage blocked */ }
    weather.audio.setVolume(soundLevel / 100);
    $('sound-label').textContent = soundLabel();
  });
  $('time').onclick = () => {
    S.timeMode = TIME_MODES[(TIME_MODES.indexOf(S.timeMode) + 1) % TIME_MODES.length];
    try { localStorage.setItem('library.time', S.timeMode); } catch { /* storage blocked */ }
    $('time').textContent = timeLabel();
  };
  $('download').onclick = () => {
    $('download').disabled = true;
    send({type: 'downloadVanilla'});
  };

  // Skins: the app picks the file (or looks the name up with Mojang) and
  // keeps it, then hands it back as a `skin` message.
  function refreshSkinLabel() {
    const name = skin.imported ? skin.label || gui.t('skinYours') : skin.vanilla ? 'Steve' : 'luma';
    $('skin-label').textContent = gui.t('skinCurrent', name);
    $('skin-reset').hidden = !skin.imported;
  }
  $('skin-import').onclick = () => {
    if (demo) $('skin-file').click();
    else send({type: 'pickSkin'});
  };
  $('skin-file').onchange = () => {
    const file = $('skin-file').files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => receive({type: 'skin', data: String(reader.result).split(',')[1], label: file.name.replace(/\.png$/i, '')});
    reader.readAsDataURL(file);
    $('skin-file').value = '';
  };
  $('skin-name').onclick = async () => {
    $('settings').hidden = true;
    const result = await gui.askName({title: gui.t('skinNameTitle'), hint: gui.t('skinNameHint'), okLabel: gui.t('skinUse'), colors: false});
    $('settings').hidden = false;
    if (result) send({type: 'skinName', name: result.name});
  };
  $('skin-reset').onclick = () => send({type: 'resetSkin'});

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
      for (const s of stairBoxes()) add(gui.t(s.dir > 0 ? 'upstairs' : 'downstairs'), () => climb(s.dir));
      add(gui.t(door.target ? 'closeDoor' : 'openDoor'), () => { toggleDoor(); rebuildA11y(); });
    } else if (S.mode === 'shelf') {
      const c = currentCase();
      add(gui.t('back'), () => toOverview());
      if (c && c.subject) {
        for (const book of c.subject.books) {
          if (Math.floor(book.slot / c.slots) !== c.page) continue;
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
    let s = c.page * c.slots;
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

  // Keyframes by the sun's height (-1 midnight … 1 noon). It is autumn:
  // the light stays golden all day and the evenings come in amber.
  const SKY = [
    {e: -1, sun: [0.16, 0.21, 0.36], sky: [0.04, 0.055, 0.11], zen: [0.008, 0.012, 0.04], hor: [0.03, 0.04, 0.08], lamp: 1.35, night: 1, exposure: 1.25},
    {e: -0.2, sun: [0.14, 0.18, 0.3], sky: [0.05, 0.06, 0.12], zen: [0.012, 0.018, 0.06], hor: [0.06, 0.06, 0.12], lamp: 1.35, night: 1, exposure: 1.25},
    {e: -0.06, sun: [0.02, 0.02, 0.03], sky: [0.12, 0.1, 0.16], zen: [0.05, 0.06, 0.16], hor: [0.42, 0.2, 0.16], lamp: 1.25, night: 0.7, exposure: 1.15},
    {e: 0.02, sun: [1.5, 0.52, 0.22], sky: [0.3, 0.22, 0.26], zen: [0.12, 0.14, 0.32], hor: [1.0, 0.42, 0.2], lamp: 1.1, night: 0.2, exposure: 1.08},
    {e: 0.2, sun: [2.1, 1.22, 0.6], sky: [0.44, 0.42, 0.48], zen: [0.2, 0.32, 0.66], hor: [1.0, 0.64, 0.4], lamp: 0.95, night: 0, exposure: 1.02},
    {e: 0.55, sun: [1.95, 1.42, 0.9], sky: [0.46, 0.5, 0.62], zen: [0.18, 0.36, 0.76], hor: [0.9, 0.74, 0.56], lamp: 0.85, night: 0, exposure: 1},
    {e: 1, sun: [1.9, 1.48, 1.0], sky: [0.48, 0.53, 0.66], zen: [0.17, 0.36, 0.78], hor: [0.86, 0.76, 0.62], lamp: 0.82, night: 0, exposure: 1},
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
    // An autumn sun runs low across the south of the sky.
    const sun = new T.Vector3(Math.cos(t), Math.sin(t) * 0.8, -0.5).normalize();
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
    // Distance fades into the horizon's haze, so far islands sit in the sky.
    U.fogColor.value.setRGB(...mix3(a.hor, b.hor).map(v => v * 0.72));
    R.skyUniforms.night.value = mix(a.night, b.night);
    // Cloud and rain dim and grey all of it.
    S.exposure = weather.grade(U, R.skyUniforms, mix(a.exposure, b.exposure));
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
    // Rain softens the light shafts away and lets the lamps bloom a little
    // more in the wet gloom.
    const p = {
      focus: 8, aperture: 0.06, blurAll: 0,
      volumeLevel: V.shafts / 100 * (1 - weather.rain * 0.85),
      bloomLevel: V.bloom / 100 * 0.9 * (1 + weather.rain * 0.5),
      exposure: (S.exposure || 1) * brightness(),
    };
    if (S.mode === 'shelf' || S.mode === 'placing') { p.focus = shelfDistance(50, caseHalf(currentCase())) * S.zoom; p.aperture = 0.16; }
    // At the desk the reader in the chair stays in focus, and the room
    // behind the open book is only softened, so you can see yourself write.
    if (S.mode === 'desk') { p.focus = 2.6; p.aperture = 0.22; }
    if (Book.open) p.blurAll = S.mode === 'desk' ? 0.22 : 0.55;
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
    if (S.built) {
      const h = S.built.hall, p = camera.position;
      const under = p.x > h.x0 - 1 && p.x < h.x1 + 1 && p.z > h.z0 - 1 && p.z < h.z1 + 1 && p.y < S.built.layout.top + 1;
      weather.step(dt, camera, under);
    }
    stepTime(dt);
    stepClock();
    stepWalk(dt);
    stepDoor(dt);
    stepCamera(dt, time);
    stepTweens(dt);
    stepHand(dt, time);
    stepSitter(time);
    stepParticles(dt, time);
    if (look.locked || S.mode === 'seated') updateHover();
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
    // Indoors the shadow map is fitted to the hall, so the light through
    // the windows stays crisp; outdoors it covers the whole island.
    if (S.built) {
      const h = S.built.hall, p = camera.position;
      const inside = p.x > h.x0 - 1 && p.x < h.x1 + 1 && p.z > h.z0 - 1 && p.z < h.z1 + 1;
      if (inside !== shadowInside) { shadowInside = inside; shadowDirty = true; }
    }
    if (shadowDirty && S.built) {
      const b = S.built.bounds;
      R.renderShadow(shadowInside ? {min: [b.min[0] - 2, b.min[1], b.min[2] - 1], max: [b.max[0] + 2, b.max[1], b.max[2] + 1]} : S.built.shadowBounds);
      shadowDirty = false;
    }
  }

  addEventListener('resize', () => {
    gui.rescale();
    R.resize(innerWidth, innerHeight, pixelRatio());
  });
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) { loop.wake(); if (S.visible) weather.audio.resume(); } else weather.audio.pause();
  });

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
          case 'skinName': emit({type: 'skin', data: null, failed: m.name}); break;
          case 'resetSkin': emit({type: 'skin', data: null}); break;
        }
      },
    };
  }

  // ── Start ──────────────────────────────────────────────────────────────
  gui.rescale();
  buildVideo();
  applyQuality();
  weather.setMode(weatherMode);
  weather.audio.setVolume(soundLevel / 100);
  $('sound').value = soundLevel;
  $('weather').textContent = weatherLabel();
  $('sound-label').textContent = soundLabel();
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
    S, R, W, V, view, hand, sitter, door, weather, climb,
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
