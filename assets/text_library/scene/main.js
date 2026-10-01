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
  function request(message, timeout = 20000) {
    return new Promise((resolve, reject) => {
      const id = ++seq;
      pending.set(id, {resolve, reject});
      send({...message, request: id});
      setTimeout(() => {
        if (!pending.has(id)) return;
        pending.delete(id);
        reject(new Error('timeout'));
      }, timeout);
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
          classroom.setLanguages(m.classStrings);
          $('time').textContent = timeLabel();
          $('weather').textContent = weatherLabel();
          $('sound-label').textContent = soundLabel();
          refreshVideo();
          if (m.reducedMotion) S.reducedMotion = true;
          refreshHud();
          break;
        case 'view':
          S.visible = m.visible !== false;
          if (!S.visible && post.loaded) post.save();
          if (!S.visible && market.loaded) market.save();
          if (S.visible) { loop.wake(); weather.audio.resume(); } else weather.audio.pause();
          break;
        case 'library': onLibrary(m.subjects || []); break;
        // The post and the vault as the app kept them.
        case 'mail': post.load(m.state); break;
        // The trader's clock, the crate and the placed furniture.
        case 'market': market.load(m.state); break;
        // The classroom's door, the reader's country, the lesson kept, and
        // the teacher's answers.
        case 'classroom': classroom.receive(m); break;
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
        // The book reviewer's answer to a book sent from the review desk.
        case 'reviewed': pending.get(m.request)?.resolve(m.result); pending.delete(m.request); break;
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
  // The coins: letters in the mailbox, what is in hand, what is in the vault.
  const post = LibraryMail.create({send, reducedMotion: () => S.reducedMotion});
  // The wandering trader, and the furniture bought from him.
  const Goods = window.LibraryGoods;
  const market = LibraryMarket.create({send, catalog: Goods.CATALOG, pets: Goods.PETS, reducedMotion: () => S.reducedMotion});
  // The trader's review desk: send a book, get a letter about it the next
  // in-game day. The app talks to the reviewer; a review can take a while.
  const reviewScreen = LibraryDesk.create({
    gui, post,
    books: () => S.subjects.map(s => ({
      name: s.name,
      books: s.books.map(b => ({id: b.id, title: b.title, body: b.body || '', blank: Book.isBlank(b.body || '')})),
    })),
    upload: async book => {
      try {
        return await request({type: 'reviewBook', id: book.id}, 150000);
      } catch (e) {
        throw new Error(e?.message === 'timeout' ? gui.t('pcTimeout') : e?.message || String(e));
      }
    },
  });

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
  // The classroom in the basement: its door, its board and the lesson
  // screen. The app talks to the teacher.
  const classroom = LibraryClassroom.create({T, gui, send, scene, W, atlas: () => atlas, mat: blockMat, toast: (a, b) => gui.toast(a, b)});
  const dynMat = R.blockMaterial();
  const heldMat = R.blockMaterial();
  const ghostMat = R.blockMaterial({transparent: true, depthWrite: false});
  ghostMat.uniforms.opacity.value = 0.45;
  // A faint cyan like a structure preview, so it reads as "build here".
  ghostMat.uniforms.highlight.value.setRGB(0.25, 0.55, 0.7);
  // Water in a fish tank or a bird bath, see-through so the fish show.
  const waterMat = R.blockMaterial({transparent: true, depthWrite: false});
  waterMat.uniforms.opacity.value = 0.38;
  // A piece of furniture about to be placed: green where it fits, red
  // where it doesn't.
  const fitMat = R.blockMaterial({transparent: true, depthWrite: false});
  fitMat.uniforms.highlight.value.setRGB(0.15, 0.7, 0.2);
  const misfitMat = R.blockMaterial({transparent: true, depthWrite: false});
  misfitMat.uniforms.highlight.value.setRGB(0.95, 0.12, 0.08);
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
    // In the hand it is drawn with the hand's wider view, which the camera's
    // frustum does not know about.
    held.mesh.frustumCulled = false;
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

  // The carried book once it is in the hand is drawn like the arm, with
  // the hand's own projection, so the two overlap as one thing.
  const heldHandMat = R.blockMaterial({viewmodel: true});
  heldHandMat.uniforms.handProjection = handMat.uniforms.handProjection;

  // Where the book is gripped on the arm's model, in pixels: just past the
  // fist, as the game shows an item in the hand.
  const BOOK_GRIP = [-1, -15, -2];

  // Where the carried book sits: in the arm's hand, its cover turned to the
  // reader. `asHand` gives the spot for drawing with the hand's projection;
  // otherwise the spot that looks the same drawn with the view's.
  function handTransform(asHand = false, grip = BOOK_GRIP) {
    if (!hand.arm) {
      const q = camera.quaternion.clone();
      return {pos: new T.Vector3(0.3, -0.28, -0.75).applyQuaternion(q).add(camera.position), quat: q, scale: 0.5};
    }
    hand.root.position.copy(camera.position);
    hand.root.quaternion.copy(camera.quaternion);
    hand.root.updateMatrixWorld(true);
    const pos = new T.Vector3(...grip).divideScalar(16).applyMatrix4(hand.arm.matrixWorld);
    const quat = camera.quaternion.clone().multiply(new T.Quaternion().setFromEuler(new T.Euler(0.25, -0.5, 0.1)));
    if (asHand) return {pos, quat, scale: 0.6};
    // The arm is drawn with the game's own field of view, the book with the
    // view's; narrower in front of a bookcase, where the hand's spot would
    // land off the edge of the screen. Pulling the spot toward the middle of
    // the view (and shrinking the book to match) puts the book on screen
    // exactly where the hand is, at whatever the view's field of view.
    camera.updateMatrixWorld();
    const k = Math.tan(camera.fov * DEG / 2) / Math.tan(handCam.fov * DEG / 2);
    const inView = pos.applyMatrix4(camera.matrixWorldInverse);
    inView.x *= k; inView.y *= k;
    inView.applyMatrix4(camera.matrixWorld);
    return {pos: inView, quat, scale: 0.6 * k};
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
  // A music note for the gramophone, the shape the game's note particle
  // has, in the first cell of a sheet of its own; the heart a fussed pet
  // gives off in the second.
  const noteCanvas = document.createElement('canvas');
  noteCanvas.width = 128; noteCanvas.height = 128;
  {
    const ctx = noteCanvas.getContext('2d');
    ctx.fillStyle = '#fff';
    for (const [x, y, w, h] of [[3, 10, 4, 3], [2, 11, 6, 1], [6, 2, 2, 9], [8, 2, 3, 2], [10, 4, 2, 2]]) ctx.fillRect(x, y, w, h);
    for (const [x, y, w, h] of [[3, 3, 4, 2], [9, 3, 4, 2], [1, 5, 14, 4], [3, 9, 10, 2], [5, 11, 6, 2], [7, 13, 2, 1]]) ctx.fillRect(16 + x, y, w, h);
  }
  const noteTexture = new T.CanvasTexture(noteCanvas);
  noteTexture.flipY = false;
  noteTexture.magFilter = T.NearestFilter;
  noteTexture.minFilter = T.NearestFilter;
  noteTexture.generateMipmaps = false;

  const particles = {
    dust: new Particles(420, {sunLit: true}),
    embers: new Particles(90),
    flames: new Particles(64, {shape: 1}),
    glyphs: new Particles(60, {shape: 2, additive: false, glyphs: glyphTexture}),
    notes: new Particles(40, {shape: 2, additive: false, glyphs: noteTexture}),
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
    // Candle flames: one per wick, flickering, the bought candelabras' too.
    particles.flames.clear();
    const wicks = [...built.candles, ...pieces.list.flatMap(pc => pc.flames)];
    for (const [i, c] of wicks.entries()) {
      const f = 0.85 + 0.15 * Math.sin(time * 11 + i * 2.1) + 0.05 * Math.sin(time * 27 + i);
      particles.flames.add({p: [c[0], c[1] + 0.02, c[2]], c: [3.4 * f, 2.2 * f, 0.9 * f, 1], s: 0.075 * f});
    }
    particles.flames.step(dt, () => true);
    // Notes rising out of a playing gramophone's horn.
    particles.notes.step(dt, p => {
      p.age += dt;
      if (p.age > p.life) return false;
      for (let k = 0; k < 3; k++) p.p[k] += p.v[k] * dt;
      p.v[1] *= 0.985;
      p.c[3] = Math.min(1, p.age * 6) * (1 - (p.age / p.life) ** 2);
      return true;
    });
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
    await applyEntitySheet(files);
    rebuildWorld();
    trader.pictures = makePictures();
    refreshHotbar();
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
    // The clear air reaches down through the cellar and the classroom too.
    U.clearMin.value.set(b.min[0], Math.min(b.min[1], (built.basement?.base ?? 0) - 1), b.min[2]);
    U.clearMax.value.set(b.max[0], Math.max(b.max[1], built.layout.top), b.max[2]);
    if (S.floor >= built.layout.floors) S.floor = 0;
    shadowDirty = true;
    if (S.caseSubject != null) {
      const idx = built.cases.findIndex(c => c.subject && c.subject.id === S.caseSubject);
      if (idx < 0 && (S.mode === 'shelf' || S.mode === 'placing')) toOverview();
      S.caseIndex = idx;
    }
    if (blocked(S.px, S.pz)) { S.px = 0; S.pz = built.layout.hallStart - 1.8; }
    buildDoor();
    buildPost();
    classroom.build(built);
    coins.count = -1;
    buildCoins();
    buildHand();
    buildSitter();
    buildClock();
    buildMarket();
    buildReviewDesk();
    rebuildPieces();
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
        if (S.hidden.has(book.id) || W.isDrawerSlot(book.slot)) continue;
        if (Math.floor(book.slot / c.slots) !== c.page) continue;
        W.addBook(mb, built.grid, atlas, W.slotGeometry(c, book.slot), labelBook(book), labels);
      }
      addSign(mb, c, c.subject);
    });
    buildDrawers();
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
  // Only ease at the ends, over the first and last `f` of the time; keep
  // an even walking pace in between.
  function stairProgress(t, f = 0.1) {
    if (t > 1 - f) return 1 - stairProgress(1 - t, f);
    const pace = 1 / (1 - f);
    if (t >= f) return (t - f / 2) * pace;
    const u = t / f;
    return f * (u * u * u - 0.5 * u * u * u * u) * pace;
  }

  // Standing in the hall, with a slight bob while walking.
  function overviewPose() {
    const bob = S.reducedMotion || !V.bobbing ? 0 : Math.sin(S.stride * 5.2) * 0.035 * Math.min(1, Math.hypot(...S.vel) / 2);
    const pos = new T.Vector3(S.px, floorY() + W.HALL.eye + Math.abs(bob), S.pz);
    const dir = new T.Vector3(-Math.sin(S.yaw) * Math.cos(S.pitch), Math.sin(S.pitch), -Math.cos(S.yaw) * Math.cos(S.pitch));
    return {pos, target: pos.clone().addScaledVector(dir, 6), fov: walkFov()};
  }
  // Where the floor the reader is on lies.
  const floorY = () => (S.floor < 0 ? S.built?.basement?.base ?? 0 : S.built?.layout.bases[S.floor] || 0);
  // The field of view setting; phones held upright see little of the
  // hall's width, so it is widened for them.
  const walkFov = () => V.fov + (innerWidth < innerHeight ? 8 : 0);

  const SHELF_CENTER = 3.0;
  // Half the height the bookcase view has to take in: the tall cases
  // downstairs, or the low ones under the eaves.
  const caseHalf = c => (c && c.floor ? 2.05 : 3.0);
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
    // With a drawer out, look down into it instead.
    const open = c.subject ? Array.from({length: W.drawerCount(c)}, (_, k) => k).filter(k => drawerState(c, k).target === 1) : [];
    if (open.length) {
      const along = c.facing > 0 ? -1 : 1, zStart = c.facing > 0 ? c.z1 : c.z0;
      const zd = zStart + along * (open.reduce((a, k) => a + k, 0) / open.length + 0.5);
      const z = zc + (zd - zc) * 0.6;
      return {pos: new T.Vector3(c.faceX + c.facing * 1.7, c.y0 + 2.35, z), target: new T.Vector3(c.faceX + c.facing * 0.4, c.y0 + 0.35, z), fov};
    }
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
  // A bed lays you lower, a telescope narrows the view, and a swing carries
  // you with it.
  function seatedPose() {
    const seat = S.seat;
    const dir = new T.Vector3(-Math.sin(S.yaw) * Math.cos(S.pitch), Math.sin(S.pitch), -Math.cos(S.yaw) * Math.cos(S.pitch));
    const at = seatPos(seat);
    const pos = new T.Vector3(at[0], at[1] + (seat.eye ?? 1.1), at[2]);
    return {pos, target: pos.clone().addScaledVector(dir, 6), fov: seat.fov || walkFov()};
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
      const e = flight.sample ? stairProgress(flight.t, flight.ease) : easeInOut(flight.t);
      if (flight.sample) {
        const pose = flight.sample(e);
        S.stride += view.pos.distanceTo(pose.pos);
        view.pos.copy(pose.pos);
        view.target.copy(pose.target);
        view.fov = pose.fov;
        S.yaw = pose.yaw;
        S.pitch = pose.pitch || 0;
        S.vel = [1.8, 0];
      } else {
        view.pos.lerpVectors(flight.from.pos, flight.to.pos, e);
        view.target.lerpVectors(flight.from.target, flight.to.target, e);
        view.fov = flight.from.fov + (flight.to.fov - flight.from.fov) * e;
        // A little rise mid-walk, and the game's view bobbing while moving.
        const arc = Math.sin(flight.t * Math.PI);
        view.pos.y += arc * Math.min(0.35, flight.dist * 0.03);
        if (!S.reducedMotion && V.bobbing) bob = arc * Math.min(1, flight.dist * 0.2);
      }
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
    if (S.mode === 'climbing' && mode !== 'climbing' && flight?.sample) {
      const done = flight.resolve;
      flight = null;
      done();
    }
    // Menus and bookcases need the cursor back; walking takes it again if
    // it was captured before.
    if (look.locked && !looking(mode)) { look.resume = true; document.exitPointerLock(); }
    if (looking(mode) && look.resume) { look.resume = false; lockPointer(); }
    // Building is something done on your feet in the hall.
    if (mode !== 'overview' && building.on) {
      building.on = false;
      if (building.ghost) building.ghost.visible = false;
    }
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
    closeDrawers();
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
    S.pitch = seat.pitch ?? (seat.desk ? -0.35 : -0.05);
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
    // From a telescope you straighten up where you stood; from a seat you
    // step out in front of it.
    const front = seat.stand ? [seat.pos[0], seat.pos[2]] : [seat.pos[0] + fx * 0.75, seat.pos[2] + fz * 0.75];
    if (!blocked(...front)) { S.px = front[0]; S.pz = front[1]; }
    else if (S.stand) { S.px = S.stand[0]; S.pz = S.stand[1]; }
    if (seat.fov) S.pitch = Math.max(-0.4, Math.min(0.4, S.pitch));
    S.seat = null;
    setMode('overview');
    return flyTo(overviewPose(), {duration: S.reducedMotion ? 0.2 : 0.45});
  }

  function toShelf(i, {placing = false} = {}) {
    const c = S.built.cases[i];
    if (!c || !c.subject) return Promise.resolve();
    S.caseIndex = i;
    S.caseSubject = c.subject.id;
    closeDrawers(c);
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
    const shelved = c.subject.books.filter(b => !W.isDrawerSlot(b.slot));
    const max = shelved.reduce((m, b) => Math.max(m, b.slot), -1);
    const pages = Math.max(1, Math.floor(max / c.slots) + 1);
    const lastFull = shelved.filter(b => Math.floor(b.slot / c.slots) === pages - 1).length >= c.slots;
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
    const scope = seated && !!S.seat?.telescope;
    $('back').textContent = gui.t(S.mode === 'placing' ? 'cancel' : scope ? 'stepBack' : seated && S.seat?.pc ? 'pcLogOff' : seated ? 'standUp' : 'back');
    $('scope').hidden = !scope;
    const others = S.built ? S.built.cases.filter(cs => cs.subject).length : 0;
    // The arrows step between bookcases, so they only show at one.
    $('case-prev').hidden = $('case-next').hidden = !(inCase && others > 1);
    const empty = S.subjects.length === 0 && S.mode === 'overview';
    let hint = '';
    if (S.mode === 'placing') hint = gui.t('moveHint');
    else if (S.mode === 'overview' && building.on) hint = building.flash > performance.now() ? gui.t('cantPlace') : gui.t(building.id ? (S.touch ? 'buildHintTouch' : 'buildHint') : 'pickHint');
    else if (seated) hint = S.touch ? '' : gui.t(scope ? 'scopeHint' : 'standHint');
    else if (post.state.hand > 0 && S.mode === 'overview') hint = gui.t('handHint');
    else if (market.crateTotal() > 0 && S.mode === 'overview' && !S.touch) hint = gui.t('crateHint');
    else if (empty) hint = gui.t('emptyHall');
    else if (S.mode === 'overview' && !S.walked) hint = gui.t('walkHint');
    else if (S.mode === 'overview' && !look.locked && !S.touch) hint = gui.t('lookHint');
    gui.actionbar(hint);
    $('settings-open').hidden = S.mode === 'desk';
    $('move-pad').hidden = !(S.mode === 'overview' && S.touch);
    $('crosshair').hidden = !(look.locked && looking(S.mode));
    post.refreshPurse(looking(S.mode));
    refreshHotbar();
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

  // A box turned by `turn` (a model's yaw) about its own centre: the ray
  // is turned back into the box's frame and tested there.
  function turnedBoxHit(ray, [min, max], turn) {
    if (!turn) return boxHit(ray, min, max);
    const c = min.map((v, k) => (v + max[k]) / 2);
    const cos = Math.cos(-turn), sin = Math.sin(-turn);
    const spin = (x, z) => [x * cos - z * sin, x * sin + z * cos];
    const [ox, oz] = spin(ray.origin.x - c[0], ray.origin.z - c[2]);
    const [dx, dz] = spin(ray.direction.x, ray.direction.z);
    const local = new T.Ray(new T.Vector3(ox, ray.origin.y - c[1], oz), new T.Vector3(dx, ray.direction.y, dz));
    return boxHit(local, min.map((v, k) => v - c[k]), max.map((v, k) => v - c[k]));
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
    if (!st || S.floor < 0) return [];
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
    if (c && c.t <= CASE_REACH) {
      consider(c.t, {kind: 'case', i: c.i});
      // The case's box stands a hair proud of its drawers; a drawer under
      // the crosshair wins over the case around it.
      const dr = pickDrawer(ray, S.built.cases[c.i]);
      if (dr && dr.kind === 'drawer' && dr.t < REACH) consider(Math.min(dr.t, c.t) - 1e-3, dr);
    }
    for (const s of stairBoxes()) {
      const t = boxHit(ray, ...s.box);
      if (t != null && t < REACH) consider(t, {kind: 'stairs', dir: s.dir, box: s.box});
    }
    S.built.seats.forEach((seat, i) => {
      if (S.seat && S.seat.box === seat.box) return;
      const t = turnedBoxHit(ray, seat.box, seat.turn);
      if (t != null && t < REACH) consider(t, {kind: 'seat', i, at: ray.at(t, new T.Vector3()).toArray()});
    });
    if (review.seat && review.floor === S.floor && !(S.seat && S.seat.pc)) {
      const hit = boxHit(ray, ...review.seat.box);
      if (hit != null && hit < REACH) consider(hit, {kind: 'desk', box: review.seat.box});
    }
    const t = S.floor === 0 ? boxHit(ray, ...doorBox()) : null;
    if (t != null && t < REACH) consider(t, {kind: 'door'});
    for (const hit of classroom.pick(ray, S.floor, boxHit, REACH)) consider(hit.t, hit);
    if (S.floor === 0) {
      for (const [kind, spot] of [['mailbox', S.built.mailbox], ['vault', S.built.vault]]) {
        const hit = spot ? boxHit(ray, ...spot.box) : null;
        if (hit != null && hit < REACH) consider(hit, {kind});
      }
      for (const box of stallBoxes()) {
        const hit = boxHit(ray, ...box);
        if (hit != null && hit < REACH) consider(hit, {kind: 'trader', box});
      }
      const petAt = petBox();
      const petHit = petAt ? boxHit(ray, ...petAt) : null;
      if (petHit != null && petHit < REACH) consider(petHit, {kind: 'pet', box: petAt});
    }
    // Furniture that does something: a bed, the swing, the telescope, the
    // gramophone.
    for (const pc of pieces.list) {
      if (pc.data.floor !== S.floor || !pc.act || (S.seat && S.seat.piece === pc)) continue;
      const box = pc.seat ? pc.seat.box : pc.box;
      const hit = boxHit(ray, ...box);
      if (hit != null && hit < REACH) consider(hit, {kind: 'piece', piece: pc, box, at: ray.at(hit, new T.Vector3()).toArray()});
    }
    return best;
  }

  let hover = null;
  function updateHover() {
    if (!S.built || pointer.dragging || Book.open || gui.isModalOpen() || flight) { setHover(null); return; }
    const [x, y] = look.locked ? [innerWidth / 2, innerHeight / 2] : [pointer.x, pointer.y];
    const ray = rayAt(x, y);
    if (looking(S.mode)) {
      // Building has its own preview and outline.
      if (building.on && S.mode === 'overview') { setHover(null); return; }
      setHover(pickWorld(ray), x, y);
    } else if (S.mode === 'shelf' || S.mode === 'placing') {
      const c = currentCase();
      const inDrawer = pickDrawer(ray, c);
      const slot = inDrawer || (c ? pickSlot(ray, c) : null);
      if (inDrawer && inDrawer.kind === 'drawer') setHover(inDrawer);
      else if (slot) setHover({kind: 'slot', ...slot});
      else {
        const hit = pickCase(ray);
        setHover(hit && hit.i !== S.caseIndex ? {kind: 'case', i: hit.i} : null);
      }
    } else setHover(null);
  }

  function outlineBox([min, max], turn = 0) {
    outline.position.set((min[0] + max[0]) / 2, (min[1] + max[1]) / 2, (min[2] + max[2]) / 2);
    outline.rotation.y = -turn;
    outline.scale.set(max[0] - min[0] + 0.01, max[1] - min[1] + 0.01, max[2] - min[2] + 0.01);
    outline.visible = true;
  }

  function setHover(h, x = pointer.x, y = pointer.y) {
    hover = h;
    outline.visible = false;
    canvas.classList.toggle('pointer', !!h);
    if (!h) { gui.tooltip(null); return; }
    if (h.kind === 'case') {
      const c = S.built.cases[h.i];
      outlineBox(caseBox(c));
      gui.tooltip(c.subject ? [c.subject.name, gui.t('books', c.subject.books.length)] : [gui.t('newCase')], x, y);
    } else if (h.kind === 'seat') {
      outlineBox(S.built.seats[h.i].box, S.built.seats[h.i].turn);
      gui.tooltip([gui.t('sit')], x, y);
    } else if (h.kind === 'door') {
      outlineBox(doorBox());
      gui.tooltip([gui.t(door.target ? 'closeDoor' : 'openDoor')], x, y);
    } else if (h.kind === 'drawer') {
      outlineBox(h.box);
      const inside = h.c.subject.books.filter(b => W.isDrawerSlot(b.slot) && W.drawerOf(b.slot) === h.d).length;
      gui.tooltip([gui.t(drawerState(h.c, h.d).target ? 'closeDrawer' : 'openDrawer'), {text: gui.t('books', inside), cls: 'sub'}], x, y);
    } else if (h.kind === 'mailbox') {
      outlineBox(S.built.mailbox.box);
      const n = post.state.letters.length;
      gui.tooltip(n ? [gui.t('takeLetter'), {text: gui.t('mailWaiting', n), cls: 'sub'}] : [gui.t('mailbox'), {text: mailNext(), cls: 'sub'}], x, y);
    } else if (h.kind === 'vault') {
      outlineBox(S.built.vault.box);
      gui.tooltip([post.state.hand ? gui.t('vaultPut', post.state.hand) : gui.t('vaultOpen'), {text: gui.t('coins', post.state.vault), cls: 'sub'}], x, y);
    } else if (h.kind === 'classroom') {
      outlineBox(h.box);
      gui.tooltip(h.tip, x, y);
    } else if (h.kind === 'stairs') {
      outlineBox(h.box);
      gui.tooltip([gui.t(h.dir > 0 ? 'upstairs' : 'downstairs')], x, y);
    } else if (h.kind === 'trader') {
      outlineBox(h.box);
      gui.tooltip(traderTooltip(), x, y);
    } else if (h.kind === 'pet') {
      outlineBox(h.box);
      gui.tooltip([gui.t({dog: 'petDog', cat: 'petCat', fish: 'petFish'}[trader.petKind] || 'petDog')], x, y);
    } else if (h.kind === 'desk') {
      outlineBox(h.box);
      const waiting = post.pendingReview;
      gui.tooltip([gui.t('pcUse'), {text: waiting ? gui.t('pcWaiting', waiting.letter.title || gui.t('untitled')) : gui.t('pcTitle'), cls: 'sub'}], x, y);
    } else if (h.kind === 'piece') {
      outlineBox(h.box);
      const pc = h.piece;
      const label = {lie: 'lieDown', sit: 'sit', scope: 'lookThrough', music: music.piece === pc ? 'stopMusic' : 'playMusic'}[pc.act];
      gui.tooltip([gui.t(label), {text: gui.t('item_' + pc.data.id), cls: 'sub'}], x, y);
    } else {
      const g = h.g;
      // The game's thin dark outline: round the book under the pointer, or
      // while carrying one, round where it would stand in the gap.
      const shown = S.mode === 'placing' && S.editing ? editingBook() : h.book;
      if (shown) {
        const {w, h: bh, d, back} = W.bookDims(shown);
        const z = (g.z0 + g.z1) / 2, front = g.faceX - g.facing * back, rear = g.faceX - g.facing * (back + d);
        outlineBox([[Math.min(front, rear), g.y0, z - w / 2], [Math.max(front, rear), g.y0 + bh, z + w / 2]]);
      } else {
        const rear = g.faceX - g.facing * 0.9;
        outlineBox([[Math.min(g.faceX, rear), g.y0, g.z0], [Math.max(g.faceX, rear), g.y1, g.z1]]);
      }
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
    // Building: a click places what is in hand, or picks a piece back up.
    if (building.on && S.mode === 'overview') {
      if (!flight) buildClick();
      return;
    }
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
    } else if (h.kind === 'mailbox') {
      await useMailbox();
    } else if (h.kind === 'vault') {
      await useVault();
    } else if (h.kind === 'desk') {
      await useDesk();
    } else if (h.kind === 'pet') {
      cuddle();
    } else if (h.kind === 'trader') {
      if (trader.phase === 'open') await openShop();
      else gui.toast(gui.t('traderStall'), traderTooltip()[1].text, traderIcon || post.coin);
    } else if (h.kind === 'piece') {
      const pc = h.piece;
      if (pc.act === 'music') toggleMusic(pc);
      else if (pc.seat) await sit(pc.seat, h.at);
    } else if (h.kind === 'drawer') {
      if (S.mode === 'shelf' || S.mode === 'placing') toggleDrawer(h.c, h.d);
      else {
        const i = S.built.cases.indexOf(h.c);
        setDrawer(h.c, h.d, true);
        if (i >= 0) await toShelf(i);
      }
    } else if (h.kind === 'classroom') {
      await useClassroom(h);
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
    const lift = g.drawer != null ? new T.Vector3(g.facing * 0.1, 0.8, 0) : new T.Vector3(g.facing * 0.55, 0.05, 0);
    const out = {pos: start.pos.clone().add(lift), quat: start.quat.clone(), scale: 1};
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
    // Out of a drawer a book comes up rather than toward the room.
    const pos = g.drawer != null
      ? new T.Vector3(p[0], p[1] + Math.max(0, out) * 1.8, p[2])
      : new T.Vector3(p[0] + g.facing * out, p[1], p[2]);
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
    if (held.mesh) {
      const inHand = S.mode === 'placing' && !!hand.arm && ![...tweens].some(t => t.mesh === held.mesh);
      if (inHand) applyTransform(held.mesh, handTransform(true));
      held.mesh.material = inHand ? heldHandMat : heldMat;
    }
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

  const isBlank = body => Book.isBlank(body);

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
    if (W.isDrawerSlot(e.slot)) setDrawer(c, W.drawerOf(e.slot), true);
    const g = slotGeo(c, e.slot);
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
    const y = floor < 0 ? b.basement?.base ?? 0 : b.layout.bases[floor] || 0;
    for (const [dx, dz] of [[-BODY, -BODY], [BODY, -BODY], [-BODY, BODY], [BODY, BODY]]) {
      const cx = Math.floor(x + dx), cz = Math.floor(z + dz);
      if (!b.grid.solid(cx, y - 1, cz)) return true;
      if (b.grid.solid(cx, y, cz) || b.grid.solid(cx, y + 1, cz)) return true;
    }
    for (const list of [b.colliders, floor === 0 ? door.colliders : [], pieces.colliders, floor === 0 ? trader.colliders : [], classroom.colliders]) {
      for (const [x0, z0, x1, z1, f] of list) {
        if ((f || 0) !== floor) continue;
        if (x > x0 - BODY && x < x1 + BODY && z > z0 - BODY && z < z1 + BODY) return true;
      }
    }
    return false;
  }

  // One continuous walk: from where the reader stands to the foot of the
  // stair, round the spiral and off onto the landing, at an even pace. The
  // gaze is level and follows the way ahead smoothed over two strides, so
  // corners and the joins between line and spiral never jerk the view.
  async function climb(dir) {
    const smooth = x => { const c = Math.max(0, Math.min(1, x)); return c * c * (3 - 2 * c); };
    const wrapAngle = a => (((a % (Math.PI * 2)) + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
    const st = S.built?.stairs, bases = S.built?.layout.bases;
    const to = S.floor + dir;
    if (!st || S.mode === 'climbing' || ![-1, 1].includes(dir) || to < 0 || to >= bases.length) return;
    const stairFlight = st.flights[Math.min(S.floor, to)];
    // Walk there when the way is clear, straight or round a corner or two
    // past whatever stands in the way; otherwise glide to the foot.
    const y = floorY();
    const here = [S.px, y, S.pz];
    const foot = LibraryStairs.route(st, stairFlight, dir > 0 ? 0 : 1);
    const front = [foot[0], y, foot[2] + 1];
    const ways = [[here], [here, [foot[0], y, here[2]]], [here, [here[0], y, foot[2]]], [here, front], [here, [here[0], y, front[2]], front]];
    const open = way => way.every((p, j) => {
      const q = way[j + 1] || foot;
      const len = Math.hypot(q[0] - p[0], q[2] - p[2]) || 1;
      for (let d = 0; d <= len; d += 0.15) if (blocked(p[0] + (q[0] - p[0]) * d / len, p[2] + (q[2] - p[2]) * d / len)) return false;
      return true;
    });
    const way = S.mode === 'overview' && Math.hypot(foot[0] - here[0], foot[2] - here[2]) < 7 ? ways.find(open) : null;
    const clear = !!way;
    const path = LibraryStairs.walk(st, stairFlight, dir, way || []);
    const heading = s => {
      const a = path.place(s + 0.8), b = path.place(s - 0.8);
      return Math.atan2(-(a[0] - b[0]), -(a[2] - b[2]));
    };
    // The head turns from where it was looking onto the way ahead, and
    // levels, once, by the shorter side, easing out over a distance that
    // grows with the turn.
    const yawOff = clear ? wrapAngle(S.yaw - heading(0)) : 0, pitchOff = clear ? S.pitch : 0;
    const settle = Math.max(0.8, Math.abs(yawOff) * 0.9);
    const sample = e => {
      const s = e * path.length;
      const p = path.place(s);
      const still = 1 - smooth(s / settle);
      const yaw = heading(s) + yawOff * still;
      const pitch = pitchOff * still;
      const pos = new T.Vector3(p[0], p[1] + W.HALL.eye, p[2]);
      const look = new T.Vector3(-Math.sin(yaw) * Math.cos(pitch), Math.sin(pitch), -Math.cos(yaw) * Math.cos(pitch));
      return {pos, target: pos.clone().addScaledVector(look, 4), fov: walkFov(), yaw, pitch};
    };
    S.goal = null;
    S.vel = [0, 0];
    setMode('climbing');
    if (S.reducedMotion) {
      await flyTo(sample(1), {duration: 0.25});
    } else {
      if (!clear) {
        const entry = sample(0);
        await flyTo(entry, {duration: Math.max(0.4, Math.min(1.8, view.pos.distanceTo(entry.pos) / 2.5))});
        if (S.mode !== 'climbing') return;
      }
      const d = Math.max(3, path.length / 2.1);
      await new Promise(resolve => {
        flight = {sample, t: 0, d, ease: Math.min(0.2, 0.45 / d), resolve};
      });
    }
    if (S.mode !== 'climbing') return;
    const end = sample(1);
    S.floor = to;
    S.px = end.pos.x; S.pz = end.pos.z;
    S.yaw = end.yaw; S.pitch = 0;
    S.vel = [0, 0];
    setMode('overview');
    rebuildA11y();
  }

  // ── The basement ───────────────────────────────────────────────────────
  // The ladder down through the foyer's hatch, the classroom's door (Nova
  // only), and its desks: sitting at one, or touching the board, brings up
  // the lesson.
  async function useClassroom(h) {
    if (h.what === 'down' || h.what === 'up') return useLadder(h.what === 'down' ? -1 : 1);
    if (h.what === 'door') {
      if (classroom.useDoor()) swingArm();
      rebuildA11y();
      return;
    }
    if (classroom.isOpen) return;
    if (h.what === 'desk') {
      await sit(h.seat);
      if (S.mode !== 'seated') return;
    }
    freeMouse();
    setHover(null);
    await classroom.open();
    relock();
  }

  // Down the ladder into the cellar (dir -1) or back up into the foyer:
  // onto the ladder facing the wall, down or up it, then a step off into
  // the room.
  async function useLadder(dir) {
    const cellar = S.built?.basement;
    if (!cellar || S.mode === 'climbing') return;
    const {hatch} = cellar;
    const toWall = Math.PI / 2, intoRoom = -Math.PI / 2;
    const pose = (x, y, z, yaw, pitch = 0) => {
      const pos = new T.Vector3(x, y + W.HALL.eye, z);
      const ahead = new T.Vector3(-Math.sin(yaw) * Math.cos(pitch), Math.sin(pitch), -Math.cos(yaw) * Math.cos(pitch));
      return {pos, target: pos.clone().addScaledVector(ahead, 4), fov: walkFov()};
    };
    const [lx, lz] = hatch.ladder;
    const [fromY, toY] = dir < 0 ? [0, cellar.base] : [cellar.base, 0];
    const [endX, endZ] = dir < 0 ? hatch.bottom : hatch.top;
    S.goal = null;
    S.vel = [0, 0];
    S.seat = null;
    setMode('climbing');
    const steps = S.reducedMotion
      ? [[pose(endX, toY, endZ, intoRoom), 0.25]]
      : [
          [pose(lx + 0.15, fromY, lz, toWall, dir < 0 ? -0.5 : 0.1), 0.6],
          [pose(lx + 0.15, toY, lz, toWall, dir < 0 ? -0.15 : 0.35), Math.abs(toY - fromY) * 0.3],
          [pose(endX, toY, endZ, intoRoom), 0.6],
        ];
    for (const [p, duration] of steps) {
      await flyTo(p, {duration});
      if (S.mode !== 'climbing') return;
    }
    S.floor = dir < 0 ? cellar.floor : 0;
    S.px = endX; S.pz = endZ;
    S.yaw = intoRoom; S.pitch = 0;
    setMode('overview');
  }

  // ── The front door ─────────────────────────────────────────────────────
  // Two leaves swinging inward on their hinges; a shut door is a wall.
  // ── Drawers ────────────────────────────────────────────────────────────
  // A tall case's drawers slide out to hold more books. Each is its own
  // mesh, drawer and books together, built shut and moved out whole.
  // State is kept by subject so it survives the hall being rebuilt.
  const drawers = {state: new Map(), meshes: []};
  const drawerKey = (c, d) => c.subject.id + ':' + d;
  function drawerState(c, d) {
    const key = drawerKey(c, d);
    if (!drawers.state.has(key)) drawers.state.set(key, {open: 0, target: 0});
    return drawers.state.get(key);
  }
  // How far drawer d is out now, or once it has finished moving.
  function drawerPull(c, d, settled = false) {
    const st = c.subject && drawers.state.get(drawerKey(c, d));
    if (!st) return 0;
    const e = settled ? st.target : st.open * st.open * (3 - 2 * st.open);
    return e * W.DRAWER_PULL;
  }
  const drawerOpen = (c, d) => { const st = c.subject && drawers.state.get(drawerKey(c, d)); return !!st && st.target === 1 && st.open > 0.95; };
  // A slot's geometry, with a drawer slot where its drawer is heading.
  const slotGeo = (c, slot) => W.slotGeometry(c, slot, W.isDrawerSlot(slot) ? drawerPull(c, W.drawerOf(slot), true) : 0);
  const setDrawer = (c, d, open) => { drawerState(c, d).target = open ? 1 : 0; };
  function toggleDrawer(c, d) {
    const st = drawerState(c, d);
    st.target = st.target ? 0 : 1;
    rebuildA11y();
  }
  // Shuts every drawer, except those of case `keep`.
  function closeDrawers(keep = null) {
    const prefix = keep && keep.subject ? keep.subject.id + ':' : null;
    for (const [key, st] of drawers.state) if (!prefix || !key.startsWith(prefix)) st.target = 0;
  }
  function buildDrawers() {
    for (const m of drawers.meshes) { scene.remove(m); m.geometry.dispose(); }
    drawers.meshes = [];
    const built = S.built;
    built.cases.forEach(c => {
      if (!c.subject) return;
      for (let d = 0; d < W.drawerCount(c); d++) {
        const mb = new W.MeshBuilder();
        W.drawer({mb, grid: built.grid, atlas}, c, d);
        for (const book of c.subject.books) {
          if (S.hidden.has(book.id) || !W.isDrawerSlot(book.slot) || W.drawerOf(book.slot) !== d) continue;
          W.addBook(mb, built.grid, atlas, W.slotGeometry(c, book.slot), labelBook(book), labels);
        }
        const mesh = new T.Mesh(mb.geometry(T), dynMat);
        mesh.userData.drawer = {c, d};
        drawers.meshes.push(mesh);
        scene.add(mesh);
      }
    });
    poseDrawers();
  }
  function poseDrawers() {
    for (const m of drawers.meshes) {
      const {c, d} = m.userData.drawer;
      m.position.set(c.facing * drawerPull(c, d), 0, 0);
    }
  }
  function stepDrawers(dt) {
    let moved = false;
    const step = dt * (S.reducedMotion ? 10 : 3.2);
    for (const st of drawers.state.values()) {
      if (st.open === st.target) continue;
      st.open = st.target > st.open ? Math.min(st.target, st.open + step) : Math.max(st.target, st.open - step);
      moved = true;
    }
    if (moved) { poseDrawers(); shadowDirty = true; }
  }
  // What the ray meets among case c's drawers: a book or a gap in an open
  // drawer, or a drawer's front.
  function pickDrawer(ray, c) {
    if (!c || !c.subject) return null;
    let best = null;
    const consider = (t, h) => { if (t != null && (!best || t < best.t)) best = {...h, t}; };
    for (let d = 0; d < W.drawerCount(c); d++) {
      const box = W.drawerBox(c, d, drawerPull(c, d));
      consider(boxHit(ray, ...box), {kind: 'drawer', c, d, box});
      if (!drawerOpen(c, d)) continue;
      for (let i = 0; i < W.DRAWER_SLOTS; i++) {
        const slot = W.drawerSlot(d, i);
        const g = slotGeo(c, slot);
        const rear = g.faceX - g.facing * 0.82;
        consider(boxHit(ray, [Math.min(g.faceX, rear), g.y0, g.z0], [Math.max(g.faceX, rear), g.y1, g.z1]),
          {kind: 'slot', slot, g, book: c.subject.books.find(b => b.slot === slot && !S.hidden.has(b.id)) || null});
      }
    }
    return best;
  }

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

  // ── The post and the vault ─────────────────────────────────────────────
  // The mailbox's flag stands up while a letter waits, with the letter in
  // its mouth. The vault's door swings open to take the coins in hand, and
  // the gold inside grows with what it holds.
  const mailbox = {flag: null, letter: null, raise: 0, pulled: false};
  const vault = {door: null, pile: null, open: 0, target: 0, pileCount: -1, busy: false};
  const coins = {mesh: null, count: -1, flying: false};
  const COIN_TILT = new T.Quaternion().setFromEuler(new T.Euler(0.45, 0.35, 0));
  // The coins are held against the side of the fist that faces the reader.
  // Past the fist, where the book goes, the little stack floats free of the
  // hand; on the fist's end it hides behind it.
  const COIN_GRIP = [-3.25, -8.5, 0];
  function coinsInHand(asHand) {
    const tr = handTransform(asHand, COIN_GRIP);
    tr.quat.multiply(COIN_TILT);
    tr.scale *= 2 / 3;
    return tr;
  }
  const HELD_LIGHT = [0.55, 0.85, 0.2];
  const mailNext = () => gui.t('mailNext', Math.max(1, Math.ceil(post.nextIn() / 60)));
  const disposeMesh = m => { if (m) { scene.remove(m); m.geometry.dispose(); } };

  function buildPost() {
    disposeMesh(mailbox.flag); disposeMesh(mailbox.letter); disposeMesh(vault.door);
    mailbox.flag = mailbox.letter = vault.door = null;
    const b = S.built, K = mb => ({mb, grid: b.grid, atlas});
    if (b.mailbox) {
      const light = b.grid.sample(b.mailbox.flag, [0, 0, 1]);
      let mb = new W.MeshBuilder();
      LibraryFurniture.mailFlag(K(mb), light);
      mailbox.flag = new T.Mesh(mb.geometry(T), dynMat);
      mailbox.flag.position.set(...b.mailbox.flag);
      mb = new W.MeshBuilder();
      LibraryFurniture.mailLetter(K(mb), b.mailbox.cell, light);
      mailbox.letter = new T.Mesh(mb.geometry(T), dynMat);
      scene.add(mailbox.flag, mailbox.letter);
    }
    if (b.vault) {
      const mb = new W.MeshBuilder();
      LibraryFurniture.vaultDoor(K(mb), b.vault.w, b.vault.h, b.grid.sample(b.vault.light, [0, 0, 1]));
      vault.door = new T.Mesh(mb.geometry(T), blockMat);
      vault.door.position.set(...b.vault.hinge);
      scene.add(vault.door);
    }
    vault.pileCount = -1;
    rebuildPile();
    poseMailbox();
    poseVault();
  }

  // A coin in the safe for every five, up to a full safe of sixty.
  function rebuildPile() {
    const b = S.built;
    if (!b?.vault || !atlas) return;
    const n = post.state.vault > 0 ? Math.min(60, Math.ceil(post.state.vault / 5)) : 0;
    if (n === vault.pileCount) return;
    vault.pileCount = n;
    disposeMesh(vault.pile);
    vault.pile = null;
    if (!n) return;
    const mb = new W.MeshBuilder();
    LibraryFurniture.goldPile({mb, grid: b.grid, atlas}, b.vault.pile, n, b.grid.sample(b.vault.light, [0, 0, 1]));
    vault.pile = new T.Mesh(mb.geometry(T), dynMat);
    vault.pile.userData.noShadow = true;
    scene.add(vault.pile);
  }

  // A stack of coins in the hand, taller the more there are.
  function buildCoins() {
    const n = post.state.hand > 0 ? Math.min(8, 2 + Math.floor(post.state.hand / 10)) : 0;
    if (n === coins.count || coins.flying) return;
    disposeMesh(coins.mesh);
    coins.mesh = null;
    coins.count = n;
    if (!n || !S.built || !atlas) return;
    const mb = new W.MeshBuilder();
    LibraryFurniture.coinStack({mb, grid: S.built.grid, atlas}, n, HELD_LIGHT);
    coins.mesh = new T.Mesh(mb.geometry(T), heldHandMat);
    coins.mesh.userData.noShadow = true;
    coins.mesh.frustumCulled = false;
    scene.add(coins.mesh);
  }

  function poseMailbox() {
    if (mailbox.flag) mailbox.flag.rotation.z = (1 - easeInOut(mailbox.raise)) * Math.PI / 2;
    if (mailbox.letter) mailbox.letter.visible = post.state.letters.length > 0 && !mailbox.pulled;
  }
  function poseVault() {
    if (vault.door) vault.door.rotation.y = -easeInOut(vault.open) * 1.75;
  }
  const approach = (v, to, step) => (to > v ? Math.min(to, v + step) : Math.max(to, v - step));
  function stepPost(dt) {
    const up = post.state.letters.length ? 1 : 0;
    if (mailbox.raise !== up) {
      mailbox.raise = approach(mailbox.raise, up, dt * (S.reducedMotion ? 10 : 2.5));
      poseMailbox();
      shadowDirty = true;
    }
    if (vault.open !== vault.target) {
      vault.open = approach(vault.open, vault.target, dt * (S.reducedMotion ? 10 : 1.8));
      poseVault();
      shadowDirty = true;
    }
    if (!coins.mesh || coins.flying) return;
    const shown = handShown() && !held.mesh;
    coins.mesh.visible = shown;
    if (!shown) return;
    applyTransform(coins.mesh, coinsInHand(true));
    coins.mesh.material = heldHandMat;
  }

  // Takes the mouse back after a letter or the vault, if walking had it.
  function relock() {
    if (look.resume && looking(S.mode)) { look.resume = false; lockPointer(); }
  }

  // The first letter comes out of the box and up big; read, its coins are
  // in your hand.
  async function useMailbox() {
    if (post.letterOpen || !S.built) return;
    if (!post.state.letters.length) {
      gui.toast(gui.t('mailbox'), mailNext(), post.coin);
      return;
    }
    mailbox.pulled = true;
    poseMailbox();
    freeMouse();
    const took = await post.showLetter(post.state.letters[0]);
    mailbox.pulled = false;
    if (took) {
      post.takeLetter();
      swingArm();
    }
    poseMailbox();
    relock();
  }

  // Opens the vault: coins in hand fly in first, then it shows what it holds.
  async function useVault() {
    if (vault.busy || post.vaultOpen || !S.built?.vault) return;
    vault.busy = true;
    vault.target = 1;
    let put = 0;
    try {
      if (post.state.hand > 0) {
        if (coins.mesh) {
          coins.flying = true;
          coins.mesh.visible = true;
          coins.mesh.material = heldMat;
          applyTransform(coins.mesh, coinsInHand(false));
          await new Promise(r => setTimeout(r, S.reducedMotion ? 0 : 300));
          const p = S.built.vault.pile;
          const into = new T.Vector3(p[0] + 0.38, p[1] + 0.1, p[2] - 0.3);
          await tween(coins.mesh, {pos: into, quat: new T.Quaternion(), scale: 0.3}, S.reducedMotion ? 0.15 : 0.75, 0.3);
          poof(into.toArray(), 8, 0.12);
          coins.flying = false;
        }
        put = post.deposit();
      } else {
        await new Promise(r => setTimeout(r, S.reducedMotion ? 0 : 450));
      }
      freeMouse();
      await post.showVault(put);
    } finally {
      coins.flying = false;
      vault.target = 0;
      vault.busy = false;
    }
    relock();
  }

  post.onChange(what => {
    buildCoins();
    rebuildPile();
    poseMailbox();
    refreshHud();
    rebuildA11y();
    if (what === 'arrived' || what === 'review') {
      if (what === 'review') gui.toast(gui.t('reviewArrived'), gui.t('reviewArrivedBody'), post.coin);
      else gui.toast(gui.t('newMail'), gui.t('newMailBody'), post.coin);
      if (S.built?.mailbox) poof(S.built.mailbox.flag, 6, 0.2);
    }
    if (market.shopOpen) market.refreshShop();
    if (reviewScreen.isOpen) reviewScreen.refresh();
  });

  // The post and the trader count the time the hall is open and on screen.
  let postClock = performance.now();
  setInterval(() => {
    const now = performance.now();
    const dt = Math.min(5, (now - postClock) / 1000);
    postClock = now;
    if (S.visible && !document.hidden) {
      post.tick(dt);
      market.tick(dt);
      if (market.shopOpen) market.refreshShop();
    }
  }, 1000);
  addEventListener('pagehide', () => {
    if (post.loaded) post.save();
    if (market.loaded) market.save();
  });

  // Small helpers for the trader, the furniture and building.
  const wrapAngle = a => (((a + Math.PI) % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2) - Math.PI;
  const turnToward = (a, b, step) => a + Math.max(-step, Math.min(step, wrapAngle(b - a)));
  const minutes = s => Math.max(1, Math.ceil(s / 60));
  function disposeGroup(g) {
    if (!g) return;
    scene.remove(g);
    g.traverse(o => o.geometry?.dispose());
  }
  // Every vertex of a mesh at one light level.
  function fillLight(mesh, l) {
    const attr = mesh.geometry.attributes.light;
    for (let i = 0; i < attr.count; i++) attr.setXYZ(i, l[0], l[1], l[2]);
    attr.needsUpdate = true;
  }
  // Each vertex of a mesh lit by the hall's light where it now stands, as
  // the hall's own blocks are.
  function bakeLight(mesh) {
    const g = mesh.geometry, pos = g.attributes.position, nrm = g.attributes.normal, attr = g.attributes.light;
    const m = mesh.matrixWorld, nm = new T.Matrix3().getNormalMatrix(m);
    const v = new T.Vector3(), n = new T.Vector3(), grid = S.built.grid;
    for (let i = 0; i < pos.count; i++) {
      v.fromBufferAttribute(pos, i).applyMatrix4(m);
      n.fromBufferAttribute(nrm, i).applyMatrix3(nm).normalize();
      const l = grid.sample([v.x + n.x * 0.3, v.y + n.y * 0.3, v.z + n.z * 0.3], [n.x, n.y, n.z]);
      attr.setXYZ(i, l[0], l[1], l[2]);
    }
    attr.needsUpdate = true;
  }

  // One of the trader's goods as a group: its fixed part, and each moving
  // part on its own pivot. `live` gives the water its see-through look.
  function assemble(id, {material, light = null, live = false}) {
    const info = Goods.build(id, atlas);
    const group = new T.Group();
    const main = new T.Mesh(info.main.geometry(T), material);
    group.add(main);
    const meshes = [main];
    const parts = {};
    for (const [name, mb] of Object.entries(info.parts)) {
      const water = name === 'water' && live;
      const mesh = new T.Mesh(mb.geometry(T), water ? waterMat : material);
      if (water) { mesh.renderOrder = 2; mesh.userData.noShadow = true; }
      const pivot = new T.Group();
      pivot.rotation.order = 'YXZ';
      if (info.pivots?.[name]) pivot.position.set(...info.pivots[name]);
      pivot.add(mesh);
      group.add(pivot);
      parts[name] = pivot;
      meshes.push(mesh);
    }
    if (parts.tube) parts.tube.rotation.x = -(info.aim || 0);
    if (light) for (const m of meshes) fillLight(m, light);
    return {group, info, parts, meshes};
  }

  // ── The wandering trader ───────────────────────────────────────────────
  // When his hour comes round he appears at the lookout and walks up the
  // path to his stall, his llamas behind him; he unrolls the canvas and sets
  // his wares out on the counter. Half an hour later he rolls it up again and
  // walks off the way he came.
  const STALL = Goods.STALL;
  const WALK = 1.35;
  const trader = {group: null, parts: null, llamas: [], leads: null, awning: null, wares: null, pet: null, bowl: null, petKind: undefined, pictures: {}, phase: 'away', open: 0, walkers: [], colliders: []};
  let entityTexture = null, traderIcon = null;
  // What each of them is busy with while the stall is open; see stepTraderLife.
  const life = {trader: null, llamas: [], pet: null, near: false, leftAt: -1e9, shadow: 0};

  async function applyEntitySheet(files) {
    const sheet = await Goods.entitySheet(files);
    entityTexture?.dispose();
    entityTexture = new T.CanvasTexture(sheet.canvas);
    entityTexture.flipY = false;
    entityTexture.magFilter = T.NearestFilter;
    entityTexture.minFilter = T.NearestFilter;
    entityTexture.generateMipmaps = false;
    entityTexture.colorSpace = T.SRGBColorSpace;
    U.entity.value = entityTexture;
    // His face under his hood, for the toasts.
    const icon = document.createElement('canvas');
    icon.width = 16; icon.height = 16;
    const ctx = icon.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(sheet.canvas, 8, 8, 8, 8, 0, 0, 16, 16);
    ctx.drawImage(sheet.canvas, 40, 8, 8, 8, 0, 0, 16, 16);
    traderIcon = icon.toDataURL();
  }

  const plotXZ = (x, z) => { const [px, pz] = S.built.market.plot; return [px + x, pz + z]; };

  function buildMarket() {
    disposeGroup(trader.group);
    for (const l of trader.llamas) disposeGroup(l.group);
    disposeGroup(trader.awning);
    disposeGroup(trader.wares);
    disposeGroup(trader.leads);
    disposePet();
    Object.assign(trader, {group: null, parts: null, llamas: [], awning: null, wares: null, leads: null, petKind: undefined, walkers: [], colliders: []});
    const m = S.built?.market;
    if (!m || !atlas) return;
    const [px, pz] = m.plot;
    const [tx, tz] = plotXZ(...STALL.trader);
    const light = S.built.grid.sample([tx, 1.2, tz], [0, 1, 0]);
    const t = Goods.creature(T, 'trader', atlas, dynMat, light);
    trader.group = t.group;
    trader.parts = t.parts;
    scene.add(t.group);
    trader.llamas = STALL.llamas.map(() => {
      const l = Goods.creature(T, 'llama', atlas, dynMat, light);
      scene.add(l.group);
      return l;
    });
    // The canvas over the counter, hinged at the back so it can roll up.
    const mb = new W.MeshBuilder();
    Goods.awning({mb, grid: S.built.grid, atlas});
    trader.awning = new T.Mesh(mb.geometry(T), dynMat);
    trader.awning.position.set(px + STALL.awning.back[0], STALL.awning.back[1], pz);
    scene.add(trader.awning);
    trader.awning.updateMatrixWorld(true);
    bakeLight(trader.awning);
    // A little model of each of his goods along the counter.
    trader.wares = new T.Group();
    const wares = STALL.wares;
    const wareLight = S.built.grid.sample([px + wares.x, wares.y + 0.3, pz + 2.5], [0, 1, 0]);
    Goods.CATALOG.forEach((item, i) => {
      const a = assemble(item.id, {material: dynMat, light: wareLight});
      const size = new T.Box3().setFromObject(a.group).getSize(new T.Vector3());
      a.group.scale.setScalar(0.27 / Math.max(size.x, size.y * 0.8, size.z));
      a.group.rotation.y = -Math.PI / 2;
      a.group.position.set(px + wares.x, wares.y + 0.001, pz + wares.z0 + (wares.z1 - wares.z0) * (i + 0.5) / Goods.CATALOG.length);
      trader.wares.add(a.group);
    });
    scene.add(trader.wares);
    // The llamas' leads, sagging to their post; they follow the necks.
    const leadGeo = new T.BufferGeometry();
    leadGeo.setAttribute('position', new T.BufferAttribute(new Float32Array(STALL.llamas.length * LEAD_SEGMENTS * 6), 3).setUsage(T.DynamicDrawUsage));
    trader.leads = new T.LineSegments(leadGeo, new T.LineBasicMaterial({color: 0x4a3018}));
    trader.leads.userData.noShadow = true;
    trader.leads.frustumCulled = false;
    scene.add(trader.leads);
    for (const parts of [trader.parts, ...trader.llamas.map(l => l.parts)]) parts.head.rotation.order = 'YXZ';
    syncMarket();
  }

  // The book review desk, a fixture of the house wherever the hall put it,
  // with its chair to sit at.
  const review = {mesh: null, seat: null, floor: 0};
  function buildReviewDesk() {
    disposeGroup(review.mesh);
    Object.assign(review, {mesh: null, seat: null, floor: 0});
    const at = S.built?.reviewDesk;
    if (!at || !atlas) return;
    const [ox, oy, oz] = at.origin;
    const mb = new W.MeshBuilder();
    Goods.reviewDesk({mb, grid: S.built.grid, atlas});
    review.mesh = new T.Mesh(mb.geometry(T), dynMat);
    review.mesh.position.set(ox, oy, oz);
    scene.add(review.mesh);
    review.mesh.updateMatrixWorld(true);
    bakeLight(review.mesh);
    const D = Goods.DESK;
    const [sx, sy, sz] = D.seat;
    review.floor = at.floor;
    review.seat = {pos: [ox + sx, oy + sy, oz + sz], yaw: Math.PI, eye: 1.08, pitch: -0.5, pc: true, box: D.box.map(([x, y, z]) => [ox + x, oy + y, oz + z])};
  }

  const LEAD_SEGMENTS = 8;
  // Where a lead is knotted round a llama's neck, in its head's own frame.
  const LEAD_KNOT = [0, 0.2175, 0.045];
  const leadKnot = new T.Vector3();

  function poseLeads() {
    if (!trader.leads?.visible) return;
    const attr = trader.leads.geometry.attributes.position, a = attr.array;
    const [hx, hz] = plotXZ(...STALL.post);
    let o = 0;
    for (const l of trader.llamas) {
      l.group.updateMatrixWorld(true);
      const k0 = l.parts.head.localToWorld(leadKnot.set(...LEAD_KNOT));
      const point = k => {
        const f = k / LEAD_SEGMENTS;
        a[o++] = k0.x + (hx - k0.x) * f;
        a[o++] = k0.y + (1.1 - k0.y) * f - Math.sin(f * Math.PI) * 0.22;
        a[o++] = k0.z + (hz - k0.z) * f;
      };
      for (let k = 0; k < LEAD_SEGMENTS; k++) { point(k); point(k + 1); }
    }
    attr.needsUpdate = true;
  }

  // Everyone where they belong for the trader being in or out, with no
  // walking: on loading, or after the hall is rebuilt.
  function syncMarket() {
    if (!trader.group) return;
    ensurePet();
    trader.walkers = [];
    const here = market.loaded && market.present;
    trader.phase = here ? 'open' : 'away';
    trader.open = here ? 1 : 0;
    if (here) placeAtRest();
    trader.group.visible = here;
    for (const l of trader.llamas) l.group.visible = here;
    trader.wares.visible = here;
    trader.leads.visible = here;
    if (trader.pet) trader.pet.group.visible = here;
    if (trader.bowl) trader.bowl.group.visible = here;
    poseAwning();
    poseLeads();
    refreshTraderColliders();
    shadowDirty = true;
  }

  function placeAtRest() {
    const [tx, tz] = plotXZ(...STALL.trader);
    trader.group.position.set(tx, 0, tz);
    trader.group.rotation.y = -Math.PI / 2;
    STALL.llamas.forEach(([x, z, yaw], i) => {
      const [lx, lz] = plotXZ(x, z);
      trader.llamas[i].group.position.set(lx, 0, lz);
      trader.llamas[i].group.rotation.y = yaw;
    });
    restPose(trader);
    for (const l of trader.llamas) restPose(l);
    placePet();
    resetLife();
  }

  function poseAwning() {
    if (!trader.awning) return;
    const k = 0.04 + 0.96 * easeInOut(trader.open);
    trader.awning.scale.set(k, k, 1);
  }

  // The way in from the lookout: down the path to level with the stall,
  // across to its near side, then round behind the counter. The llamas peel
  // off to either side of their post.
  function routes() {
    const [ax, az] = S.built.market.arrive;
    const gate = plotXZ(...STALL.gate);
    const lead = [[ax, az], [ax, gate[1]], gate];
    const [l0, l1] = STALL.llamas;
    return {
      trader: [...lead, plotXZ(...STALL.trader)],
      pet: [lead[0], lead[1], plotXZ(STALL.pet.spot[0], STALL.gate[1]), plotXZ(...STALL.pet.spot)],
      llamas: [
        [...lead, plotXZ(l0[0], STALL.gate[1]), plotXZ(l0[0], l0[1])],
        [...lead, plotXZ(STALL.llamaLane, STALL.gate[1]), plotXZ(STALL.llamaLane, l1[1]), plotXZ(l1[0], l1[1])],
      ],
    };
  }

  function walker(obj, parts, kind, path, delay, restYaw) {
    let length = 0;
    for (let i = 1; i < path.length; i++) length += Math.hypot(path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1]);
    return {obj, parts, kind, path, delay, restYaw, length, s: 0, t: 0, started: false, done: false, settle: null, yaw: obj.rotation.y};
  }

  function alongPath(path, s) {
    for (let i = 1; i < path.length; i++) {
      const [ax, az] = path[i - 1], [bx, bz] = path[i];
      const len = Math.hypot(bx - ax, bz - az);
      if (s <= len || i === path.length - 1) {
        const k = len ? Math.min(1, s / len) : 1;
        return {x: ax + (bx - ax) * k, z: az + (bz - az) * k, dx: bx - ax, dz: bz - az};
      }
      s -= len;
    }
    const [x, z] = path[path.length - 1];
    return {x, z, dx: 0, dz: 1};
  }

  function startComing() {
    if (!trader.group) return;
    ensurePet();
    const r = routes();
    trader.phase = 'coming';
    trader.open = 0;
    trader.walkers = [
      walker(trader.group, trader.parts, 'trader', r.trader, 0, -Math.PI / 2),
      ...trader.llamas.map((l, i) => walker(l.group, l.parts, 'llama', r.llamas[i], 1.4 + i * 1.3, STALL.llamas[i][2])),
    ];
    if (trader.pet) trader.walkers.push(walker(trader.pet.group, trader.pet.parts, trader.pet.kind, r.pet, 0.6, STALL.pet.yaw));
    if (trader.bowl) trader.bowl.group.visible = false;
    for (const w of trader.walkers) w.obj.visible = false;
    trader.wares.visible = false;
    trader.leads.visible = false;
    poseAwning();
    refreshTraderColliders();
  }

  function startGoing() {
    if (!trader.group || trader.phase === 'away') return;
    if (trader.phase === 'coming') {
      placeAtRest();
      trader.group.visible = true;
      for (const l of trader.llamas) l.group.visible = true;
      if (trader.pet) trader.pet.group.visible = true;
    }
    const r = routes();
    trader.phase = 'going';
    trader.leads.visible = false;
    restPose(trader);
    for (const l of trader.llamas) restPose(l);
    trader.walkers = [
      walker(trader.group, trader.parts, 'trader', r.trader.slice().reverse(), 1.3, null),
      ...trader.llamas.map((l, i) => walker(l.group, l.parts, 'llama', r.llamas[i].slice().reverse(), 0.4 + i * 0.7, null)),
    ];
    // The pet sets off from wherever it had got to.
    if (trader.pet) {
      const g = trader.pet.group.position;
      restPose(trader.pet);
      trader.walkers.push(walker(trader.pet.group, trader.pet.parts, trader.pet.kind, [[g.x, g.z], ...r.pet.slice().reverse()], 1.0, null));
      life.pet = null;
    }
    refreshTraderColliders();
  }

  // Legs swinging with the distance walked, the body bobbing on each step.
  // He looks about him as he goes; the llamas' heads nod with their gait;
  // a pet trots on its short legs, tail going.
  function stride(w) {
    const pet = w.kind === 'dog' || w.kind === 'cat', f = pet ? 9 : 4.2;
    const a = Math.sin(w.s * f) * (pet ? 0.8 : 0.6), m = S.reducedMotion ? 0 : 1;
    const inner = w.obj.children[0], p = w.parts;
    inner.position.y = Math.abs(Math.sin(w.s * f)) * (pet ? 0.02 : 0.035) * m;
    if (p.tail) p.tail.rotation.y = Math.sin(w.s * 8) * 0.45 * m;
    if (p.tail1) { p.tail1.rotation.y = Math.sin(w.s * 2) * 0.25 * m; p.tail2.rotation.y = Math.sin(w.s * 2 - 1) * 0.3 * m; }
    if (w.kind === 'trader') {
      p.rightLeg.rotation.x = a;
      p.leftLeg.rotation.x = -a;
      p.head.rotation.set(0, Math.sin(w.s * 0.8) * 0.45 * m, 0);
      p.arms.rotation.x = p.arms.userData.rest[0] + Math.sin(w.s * 8.4) * 0.05 * m;
      inner.rotation.z = Math.sin(w.s * 4.2) * 0.035 * m;
    } else {
      p.rightFront.rotation.x = a; p.leftHind.rotation.x = a;
      p.leftFront.rotation.x = -a; p.rightHind.rotation.x = -a;
      p.head.rotation.set(Math.sin(w.s * 8.4 + 1) * 0.07 * m, Math.sin(w.s * 1.1) * 0.25 * m, 0);
      p.body.rotation.z = Math.sin(w.s * f) * 0.04 * m;
    }
  }
  // Every part of a creature back as it was modelled.
  function restPose(c) {
    if (!c?.parts) return;
    for (const part of Object.values(c.parts)) {
      part.rotation.set(...part.userData.rest);
      part.position.fromArray(part.userData.pos);
    }
    c.group.children[0].position.y = 0;
    c.group.children[0].rotation.z = 0;
  }

  // Where the trader and his llamas stand in the way while he is open.
  function refreshTraderColliders() {
    trader.colliders = [];
    if (trader.phase !== 'open' || !S.built?.market) return;
    const [px, pz] = S.built.market.plot;
    if (trader.bowl) {
      const [x0, z0, x1, z1] = trader.bowl.info.solid;
      trader.colliders.push([px + x0, pz + z0, px + x1, pz + z1, 0]);
    }
    const [tx, tz] = plotXZ(...STALL.trader);
    trader.colliders.push([tx - 0.3, tz - 0.3, tx + 0.3, tz + 0.3, 0]);
    for (const [x, z, yaw] of STALL.llamas) {
      const [lx, lz] = plotXZ(x, z);
      const corners = [[-0.4, -0.62], [0.4, -0.62], [-0.4, 1.3], [0.4, 1.3]].map(([a, b]) => [lx + a * Math.cos(yaw) + b * Math.sin(yaw), lz - a * Math.sin(yaw) + b * Math.cos(yaw)]);
      const xs = corners.map(c => c[0]), zs = corners.map(c => c[1]);
      trader.colliders.push([Math.min(...xs), Math.min(...zs), Math.max(...xs), Math.max(...zs), 0]);
    }
  }

  // What of the stall can be clicked: the counter, and the trader behind it.
  function stallBoxes() {
    if (!S.built?.market) return [];
    const [px, pz] = S.built.market.plot;
    const [x0, z0, x1, z1] = STALL.counter;
    const out = [[[px + x0, 0, pz + z0], [px + x1, 1.4, pz + z1]]];
    if (trader.phase === 'open') {
      const [tx, tz] = plotXZ(...STALL.trader);
      out.push([[tx - 0.35, 0, tz - 0.35], [tx + 0.35, 1.95, tz + 0.35]]);
    }
    return out;
  }

  function traderTooltip() {
    if (trader.phase === 'open') return [gui.t('traderTrade'), {text: gui.t('shopLeaves', minutes(market.leavesIn())), cls: 'sub'}];
    if (trader.phase === 'coming' || trader.phase === 'going') return [gui.t('traderStall'), {text: gui.t('traderBusy'), cls: 'sub'}];
    return [gui.t('traderStall'), {text: gui.t('traderAway', minutes(market.nextIn())), cls: 'sub'}];
  }

  function warePoofs() {
    if (!trader.wares) return;
    for (const g of trader.wares.children) poof([g.position.x, g.position.y + 0.12, g.position.z], 3, 0.08);
  }

  function stepMarket(dt, time) {
    if (!trader.group) return;
    let walking = false;
    for (const w of trader.walkers) {
      if (w.done) {
        if (w.settle != null) {
          w.yaw = turnToward(w.yaw, w.settle, dt * 4);
          w.obj.rotation.y = w.yaw;
          if (Math.abs(wrapAngle(w.settle - w.yaw)) < 0.01) w.settle = null;
        }
        continue;
      }
      w.t += dt;
      if (w.t < w.delay) continue;
      if (!w.started) {
        w.started = true;
        if (trader.phase === 'coming') {
          w.obj.visible = true;
          poof([w.path[0][0], 1, w.path[0][1]], 14, 0.5);
        }
      }
      w.s = Math.min(w.length, w.s + dt * WALK);
      const p = alongPath(w.path, w.s);
      w.obj.position.set(p.x, 0, p.z);
      w.yaw = turnToward(w.yaw, Math.atan2(p.dx, p.dz), dt * 7);
      w.obj.rotation.y = w.yaw;
      stride(w);
      walking = true;
      if (w.s >= w.length) {
        w.done = true;
        restPose(w.obj === trader.group ? trader : w.obj === trader.pet?.group ? trader.pet : trader.llamas.find(l => l.group === w.obj));
        if (trader.phase === 'going') {
          w.obj.visible = false;
          poof([p.x, 1, p.z], 14, 0.5);
        } else w.settle = w.restYaw;
      }
    }
    if (walking) shadowDirty = true;
    if (trader.walkers.length && trader.walkers.every(w => w.done && w.settle == null)) {
      trader.walkers = [];
      trader.phase = trader.phase === 'coming' ? 'open' : 'away';
      if (trader.phase === 'open') trader.leads.visible = true;
      refreshTraderColliders();
      refreshHud();
      rebuildA11y();
    }
    // The canvas rolls out once he is in, and up before he goes.
    const want = trader.phase === 'open' ? 1 : 0;
    if (trader.open !== want) {
      trader.open = approach(trader.open, want, dt * (S.reducedMotion ? 10 : 0.9));
      poseAwning();
      shadowDirty = true;
    }
    const show = trader.phase === 'open' && trader.open > 0.7;
    if (trader.wares.visible !== show) {
      trader.wares.visible = show;
      warePoofs();
      if (trader.bowl) {
        trader.bowl.group.visible = show;
        const [sx, sz] = plotXZ(...STALL.pet.spot);
        poof([sx, 0.7, sz], 8, 0.3);
      }
      shadowDirty = true;
    }
    if (trader.phase === 'open' && trader.group.visible) stepTraderLife(dt, time);
    if (trader.phase === 'open') { stepPetLife(dt, time); stepBowl(dt, time); }
    trader.llamas.forEach((l, i) => {
      if (!l.group.visible || trader.walkers.some(w => w.obj === l.group && !w.done)) return;
      stepLlamaLife(l, i, dt, time);
    });
    poseLeads();
    // The idle business moves heads about: the shadows follow now and then
    // while the reader is close enough to see.
    if (trader.group.visible && camera.position.distanceTo(trader.group.position) < 24) {
      life.shadow += dt;
      if (life.shadow > 0.12) { life.shadow = 0; shadowDirty = true; }
    }
  }

  // ── Life at the stall ──────────────────────────────────────────────────
  // While the stall is open the trader and his llamas are never quite still.
  // They breathe, and every few seconds take up some business of their own:
  // he glances about, studies his wares, looks back at the llamas, hums a
  // tune or shifts his weight; they sniff the ground and chew, shake their
  // heads, stamp a hoof, or watch whoever is about. He greets the reader
  // with a nod when they walk up, and is glad of every sale. A llama stood
  // in front of for too long spits.
  const TRADER_ACTS = [['glance', 3], ['wares', 2], ['llamas', 1.2], ['hum', 1], ['shift', 1.5], ['idle', 2]];
  const LLAMA_ACTS = [['look', 3], ['sniff', 2], ['shake', 1], ['stamp', 1.2], ['idle', 2.5]];
  const LLAMA_LEGS = ['rightFront', 'leftFront', 'rightHind', 'leftHind'];
  const mouth = new T.Vector3();

  function idleLife() {
    return {act: 'idle', t: 0, dur: rand(1, 4), yaw: 0, pitch: 0, side: 1, leg: null, landed: false, beat: 0, spat: false, cool: rand(12, 30)};
  }
  function resetLife() {
    life.trader = idleLife();
    life.llamas = trader.llamas.map(idleLife);
  }
  function setAct(L, act, dur) {
    Object.assign(L, {act, t: 0, dur, yaw: rand(-0.9, 0.9), pitch: rand(-0.25, 0.2), side: Math.random() < 0.5 ? -1 : 1, landed: false, beat: 0, spat: false});
    L.leg = LLAMA_LEGS[Math.floor(Math.random() * 4)];
  }
  function pickAct(acts) {
    let r = Math.random() * acts.reduce((s, a) => s + a[1], 0);
    for (const [act, w] of acts) if ((r -= w) <= 0) return act;
    return 'idle';
  }
  // 0 → 1 → 0 over an act, easing in and out over its first and last part.
  const envelope = (L, edge = 0.3) => Math.min(1, L.t / edge, (L.dur - L.t) / edge);
  const ease = (part, target, k) => part + (target - part) * k;
  // Where the reader is from a creature: the turn of its head to face
  // them, and how far off they are.
  function readerFrom(obj, eyeY) {
    const g = obj.position, dx = camera.position.x - g.x, dz = camera.position.z - g.z, d = Math.hypot(dx, dz);
    return {d, yaw: wrapAngle(Math.atan2(dx, dz) - obj.rotation.y), pitch: -Math.atan2(camera.position.y - eyeY, d)};
  }

  function stepTraderLife(dt, time) {
    if (!life.trader) resetLife();
    const L = life.trader, p = trader.parts, inner = trader.group.children[0], still = S.reducedMotion;
    const r = readerFrom(trader.group, 1.55);
    const near = r.d < 7 && S.floor === 0;
    if (near && !life.near && time - life.leftAt > 8 && !still) setAct(L, 'greet', 1.2);
    if (!near && life.near) life.leftAt = time;
    life.near = near;
    L.t += dt;
    if (L.t >= L.dur && L.act !== 'idle' || L.t >= L.dur && !near) {
      if (near || still) setAct(L, 'idle', rand(2, 5));
      else { const act = pickAct(TRADER_ACTS); setAct(L, act, act === 'hum' ? rand(3, 5) : rand(1.6, 3.6)); }
    }
    // Watching the reader when they are close, otherwise looking about.
    let hy = Math.sin(time * 0.31) * 0.35, hp = 0, hr = 0, by = 0, arms = 0, lean = 0, hop = 0, k = Math.min(1, dt * 4);
    if (near || market.shopOpen) {
      hy = Math.max(-1.1, Math.min(1.1, r.yaw));
      hp = Math.max(-0.5, Math.min(0.4, r.pitch));
    }
    const e = envelope(L);
    switch (L.act) {
      case 'glance': hy = L.yaw * 1.2; hp = L.pitch; break;
      case 'wares': hy = L.yaw * 0.4; hp = 0.55; arms = -0.12 * e; break;
      case 'llamas': by = L.side * 0.45 * e; hy = L.side * 1.15; hp = 0.1; break;
      case 'shift': lean = L.side * 0.05 * e; hy *= 0.5; break;
      case 'hum':
        hr = Math.sin(L.t * 3.4) * 0.16 * e;
        hy = Math.sin(L.t * 1.7) * 0.3;
        hp = -0.12;
        if ((L.beat -= dt) <= 0) {
          L.beat = rand(0.45, 0.8);
          const h = trader.group.position, c = new T.Color().setHSL(Math.random(), 0.75, 0.6);
          particles.notes.add({p: [h.x + rand(-0.15, 0.15), 2.15, h.z + rand(-0.15, 0.15)], v: [rand(-0.1, 0.1), rand(0.35, 0.5), rand(-0.1, 0.1)], c: [c.r, c.g, c.b, 1], s: 0.1, g: 0, life: rand(1.2, 1.7), age: 0});
        }
        break;
      case 'greet': {
        const f = L.t / L.dur;
        hp += Math.sin(f * Math.PI * 3) * 0.32 * (1 - f);
        arms = -0.22 * Math.sin(f * Math.PI);
        k = Math.min(1, dt * 14);
        break;
      }
      case 'happy': {
        const f = L.t / L.dur;
        hop = Math.abs(Math.sin(L.t * 9)) * 0.07 * (1 - f);
        hp = -0.2 + Math.sin(L.t * 18) * 0.16 * (1 - f);
        arms = -0.4 * Math.abs(Math.sin(L.t * 9)) * (1 - f);
        k = Math.min(1, dt * 14);
        if ((L.beat -= dt) <= 0 && f < 0.7) { L.beat = 0.12; sparkle(trader.group.position, 2.2); }
        break;
      }
    }
    const breath = still ? 0 : Math.sin(time * 1.9);
    p.head.rotation.y = ease(p.head.rotation.y, hy, k);
    p.head.rotation.x = ease(p.head.rotation.x, hp + breath * 0.02, k);
    p.head.rotation.z = ease(p.head.rotation.z, hr, k);
    p.body.rotation.y = ease(p.body.rotation.y, by, Math.min(1, dt * 4));
    p.arms.rotation.x = ease(p.arms.rotation.x, p.arms.userData.rest[0] + arms + breath * 0.035, k);
    p.arms.rotation.y = p.body.rotation.y;
    inner.rotation.z = ease(inner.rotation.z, lean, Math.min(1, dt * 3));
    inner.position.y = hop;
  }

  // The trader is pleased with a sale.
  function cheer() {
    if (trader.phase !== 'open' || S.reducedMotion) return;
    if (!life.trader) resetLife();
    setAct(life.trader, 'happy', 1.6);
  }

  // Green sparkles round a head, as when a villager is happy with a trade.
  function sparkle(at, y) {
    for (let i = 0; i < 2; i++) {
      particles.embers.add({p: [at.x + rand(-0.4, 0.4), y + rand(-0.3, 0.3), at.z + rand(-0.4, 0.4)], v: [rand(-0.05, 0.05), rand(0.25, 0.5), rand(-0.05, 0.05)], c: [0.35, 2.2, 0.5, 1], s: rand(0.03, 0.05), life: rand(0.6, 1), age: 0});
    }
  }

  function stepLlamaLife(l, i, dt, time) {
    if (!life.llamas[i]) life.llamas[i] = idleLife();
    const L = life.llamas[i], p = l.parts, still = S.reducedMotion;
    const r = readerFrom(l.group, 1.7);
    const near = r.d < 5 && S.floor === 0;
    L.t += dt;
    L.cool -= dt;
    // Stand in front of a llama for long enough and it lets you know.
    if (near && r.d < 2.8 && Math.abs(r.yaw) < 0.7 && L.cool <= 0 && L.act !== 'spit' && !still && Math.random() < dt * 0.35) {
      setAct(L, 'spit', 1.1);
      L.cool = rand(30, 55);
    }
    if (L.t >= L.dur) {
      if (still) setAct(L, 'idle', 4);
      else if (L.act === 'sniff') setAct(L, 'chew', rand(2, 4));
      else {
        const act = near && Math.random() < 0.5 ? 'look' : pickAct(LLAMA_ACTS);
        setAct(L, act, {shake: 0.9, stamp: 0.9, sniff: rand(1.5, 2.5)}[act] ?? rand(2, 5));
      }
    }
    let hy = Math.sin(time * 0.23 + i * 4) * 0.2, hp = Math.sin(time * 0.7 + i * 2.3) * 0.07, hr = 0, k = Math.min(1, dt * 3);
    const e = envelope(L);
    switch (L.act) {
      case 'look':
        if (near) { hy = Math.max(-0.9, Math.min(0.9, r.yaw)); hp = Math.max(-0.4, Math.min(0.3, r.pitch)); }
        else { hy = L.yaw; hp = L.pitch; }
        break;
      case 'sniff': hy = L.yaw * 0.3; hp = 0.95 * e + Math.sin(L.t * 9) * 0.03; break;
      case 'chew': hp = 0.08 + Math.sin(L.t * 10) * 0.035; hr = Math.sin(L.t * 5) * 0.06; break;
      case 'shake': {
        const f = L.t / L.dur;
        hy = Math.sin(L.t * 26) * 0.32 * (1 - f);
        hr = Math.sin(L.t * 26 + 1) * 0.2 * (1 - f);
        k = Math.min(1, dt * 20);
        break;
      }
      case 'stamp': {
        const f = Math.min(1, L.t / 0.55);
        p[L.leg].rotation.x = -0.65 * Math.sin(f * Math.PI);
        if (f >= 1 && !L.landed) {
          L.landed = true;
          l.group.updateMatrixWorld(true);
          const hoof = p[L.leg].localToWorld(mouth.set(0, -0.85, 0));
          poof([hoof.x, 0.05, hoof.z], 5, 0.1);
        }
        hp = -0.1;
        break;
      }
      case 'spit': {
        hy = Math.max(-0.9, Math.min(0.9, r.yaw));
        hp = L.t < 0.4 ? -0.35 : 0.25 * Math.max(0, 1 - (L.t - 0.4) * 2);
        k = Math.min(1, dt * (L.t < 0.4 ? 6 : 22));
        if (L.t >= 0.42 && !L.spat) { L.spat = true; spit(l); }
        break;
      }
    }
    if (still) { hy = 0; hp = 0; hr = 0; }
    p.head.rotation.y = ease(p.head.rotation.y, hy, k);
    p.head.rotation.x = ease(p.head.rotation.x, hp, k);
    p.head.rotation.z = ease(p.head.rotation.z, hr, k);
    p.body.rotation.x = p.body.userData.rest[0] + (still ? 0 : Math.sin(time * 1.6 + i * 1.7) * 0.018);
    if (L.act !== 'stamp') for (const leg of LLAMA_LEGS) p[leg].rotation.x = ease(p[leg].rotation.x, 0, Math.min(1, dt * 8));
  }

  // A gob of llama spit, arcing at the reader.
  function spit(l) {
    l.group.updateMatrixWorld(true);
    const from = l.parts.head.localToWorld(mouth.set(0, 0.72, 0.66));
    const to = camera.position, flight = 0.4;
    const v = [(to.x - from.x) / flight, (to.y - 0.15 - from.y) / flight + 3.5 * flight, (to.z - from.z) / flight];
    for (let i = 0; i < 7; i++) {
      particles.splash.add({p: [from.x, from.y, from.z], v: v.map(c => c * rand(0.92, 1.02) + rand(-0.15, 0.15)), c: [0.92, 0.95, 0.9, 0.85], s: rand(0.03, 0.05), life: flight * rand(0.75, 0.95), age: 0});
    }
  }

  // ── The trader's pet ───────────────────────────────────────────────────
  // He brings one each visit (the market picks which): a dog or a cat that
  // walks in at his heels and keeps to the counter's left end, or a fish in
  // a bowl he sets out with his wares. The dog sits, lies down, scratches,
  // shakes itself, noses about and begs when the reader comes over; the cat
  // sits, loafs, washes, stretches and wanders off for a look round.
  // Clicking either fusses it; clicking the bowl feeds the fish.
  const PET_ACTS = {
    dog: [['sit', 3], ['lie', 2], ['stand', 1.5], ['scratch', 1], ['shake', 0.8], ['stroll', 1.6]],
    cat: [['sit', 3], ['lie', 3], ['groom', 1.6], ['stretch', 1], ['stroll', 1.2]],
  };
  const PET_DURATION = {scratch: [1.2, 2], shake: [1.1, 1.1], stretch: [1.8, 1.8], groom: [3, 5], lie: [8, 16], stroll: [60, 60]};
  const petHead = new T.Vector3();

  function disposePet() {
    disposeGroup(trader.pet?.group);
    disposeGroup(trader.bowl?.group);
    trader.pet = null;
    trader.bowl = null;
  }

  // The pet the market says he has with him this visit, built if it isn't.
  function ensurePet() {
    const kind = market.pet;
    if (trader.petKind === kind) return;
    disposePet();
    trader.petKind = kind;
    life.pet = null;
    if (!kind || !S.built?.market || !atlas) return;
    const [px, pz] = S.built.market.plot;
    const [sx, sz] = plotXZ(...STALL.pet.spot);
    const light = S.built.grid.sample([sx, 0.8, sz], [0, 1, 0]);
    if (kind === 'fish') {
      const K = {mb: new W.MeshBuilder(), grid: S.built.grid, atlas}, KW = {mb: new W.MeshBuilder(), grid: S.built.grid, atlas};
      const info = Goods.fishbowl(K, KW);
      const group = new T.Group();
      group.position.set(px, 0, pz);
      const stand = new T.Mesh(K.mb.geometry(T), dynMat);
      const water = new T.Mesh(KW.mb.geometry(T), waterMat);
      water.renderOrder = 2;
      water.userData.noShadow = true;
      const [lo, hi] = info.glass;
      const glass = new T.Mesh(new T.BoxGeometry(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]), R.glassMaterial);
      glass.position.set((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2);
      glass.renderOrder = 3;
      glass.userData.noShadow = true;
      group.add(stand, water, glass);
      scene.add(group);
      group.updateMatrixWorld(true);
      bakeLight(stand);
      bakeLight(water);
      const colours = Goods.FISH_COLOURS[Math.floor(Math.random() * Goods.FISH_COLOURS.length)];
      const mesh = Goods.fish(T, atlas, dynMat, colours, light);
      mesh.scale.setScalar(0.6);
      mesh.userData.noShadow = true;
      group.add(mesh);
      const [flo, fhi] = info.fish;
      const spot = () => flo.map((v, k) => v + Math.random() * (fhi[k] - v));
      trader.bowl = {group, info, fish: {mesh, p: spot(), to: spot(), spot, yaw: Math.random() * 6.28, fed: 0, nibble: 0}, bubble: 1};
      mesh.position.set(...trader.bowl.fish.p);
    } else {
      const c = Goods.creature(T, kind, atlas, dynMat, light);
      c.parts.head.rotation.order = 'YXZ';
      trader.pet = {kind, ...c};
      scene.add(c.group);
    }
    shadowDirty = true;
  }

  function placePet() {
    const pet = trader.pet;
    if (!pet) return;
    const [sx, sz] = plotXZ(...STALL.pet.spot);
    pet.group.position.set(sx, 0, sz);
    pet.group.rotation.y = STALL.pet.yaw;
    restPose(pet);
  }

  // What of the pet can be clicked, while he is open.
  function petBox() {
    if (trader.phase !== 'open' || !S.built?.market) return null;
    if (trader.bowl?.group.visible) {
      const [px, pz] = S.built.market.plot, [a, c] = trader.bowl.info.pick;
      return [[px + a[0], a[1], pz + a[2]], [px + c[0], c[1], pz + c[2]]];
    }
    const pet = trader.pet;
    if (!pet?.group.visible) return null;
    const g = pet.group.position, r = pet.kind === 'dog' ? 0.45 : 0.35, h = pet.kind === 'dog' ? 0.95 : 0.7;
    return [[g.x - r, 0, g.z - r], [g.x + r, h, g.z + r]];
  }

  // Hearts over its head.
  function hearts(at, count = 1) {
    for (let i = 0; i < count; i++) {
      particles.notes.add({p: [at.x + rand(-0.15, 0.15), at.y + rand(0.1, 0.25), at.z + rand(-0.15, 0.15)], v: [rand(-0.05, 0.05), rand(0.3, 0.45), rand(-0.05, 0.05)], c: [1, 0.22, 0.28, 1], s: 0.11, g: 1, life: rand(1, 1.4), age: 0});
    }
  }

  // The reader fusses the pet: it is delighted. The fish gets fed instead.
  function cuddle() {
    if (trader.phase !== 'open') return;
    swingArm();
    if (trader.bowl) { feedFish(); return; }
    const pet = trader.pet;
    if (!pet) return;
    if (!life.pet) life.pet = petLife();
    setPetAct(life.pet, 'happy', 2.2);
    hearts(pet.parts.head.getWorldPosition(petHead), 2);
  }

  function petLife() {
    return {act: 'sit', t: 0, dur: rand(2, 5), stage: 0, path: null, s: 0, pause: 0, wag: 0, beat: 0, side: 1, yaw: 0, pitch: 0};
  }
  function setPetAct(L, act, dur) {
    Object.assign(L, {act, t: 0, dur, stage: 0, path: null, s: 0, pause: rand(1.6, 3), beat: 0, side: Math.random() < 0.5 ? -1 : 1, yaw: rand(-0.8, 0.8), pitch: rand(-0.2, 0.15)});
  }

  // Every part eased toward a pose: where it sits and how it is turned
  // about x. The head turns on its own.
  function posePet(pet, pose, k) {
    const def = pet.poses[pose] || {};
    for (const [name, part] of Object.entries(pet.parts)) {
      const o = def[name], pos = o?.pos ? o.pos.map(v => v / 16) : part.userData.pos;
      part.position.set(ease(part.position.x, pos[0], k), ease(part.position.y, pos[1], k), ease(part.position.z, pos[2], k));
      if (name !== 'head') part.rotation.x = ease(part.rotation.x, o?.rot ?? part.userData.rest[0], k);
    }
  }

  // A step along the pet's own little walk; true once it is there.
  function petWalk(pet, L, dt) {
    const g = pet.group, [[ax, az], [bx, bz]] = L.path, len = Math.hypot(bx - ax, bz - az);
    L.s = Math.min(len, L.s + dt * 1.1);
    const p = alongPath(L.path, L.s);
    g.position.set(p.x, 0, p.z);
    if (len > 0.01) g.rotation.y = turnToward(g.rotation.y, Math.atan2(p.dx, p.dz), dt * 8);
    posePet(pet, 'stand', Math.min(1, dt * 8));
    stride({s: L.s, kind: pet.kind, parts: pet.parts, obj: g});
    return L.s >= len;
  }

  function stepPetLife(dt, time) {
    const pet = trader.pet;
    if (!pet?.group.visible || trader.walkers.some(w => w.obj === pet.group && !w.done)) return;
    if (!life.pet) life.pet = petLife();
    const L = life.pet, p = pet.parts, g = pet.group, inner = g.children[0], dog = pet.kind === 'dog', still = S.reducedMotion;
    const [sx, sz] = plotXZ(...STALL.pet.spot);
    const r = readerFrom(g, dog ? 0.75 : 0.55);
    const near = r.d < 4 && S.floor === 0;
    L.t += dt;
    if (L.t >= L.dur) {
      if (Math.hypot(g.position.x - sx, g.position.z - sz) > 0.05) {
        setPetAct(L, 'stroll', 60);
        L.stage = 3;
      } else if (still) setPetAct(L, 'sit', 6);
      else if (near && Math.random() < (dog ? 0.7 : 0.4)) setPetAct(L, dog ? 'beg' : 'watch', rand(3, 6));
      else {
        const act = pickAct(PET_ACTS[pet.kind]);
        const [a, b] = PET_DURATION[act] || [4, 8];
        setPetAct(L, act, rand(a, b));
      }
    }
    // Sitting and looking about by default; the reader is watched when close.
    let pose = 'sit', hy = Math.sin(time * 0.4) * 0.3, hp = 0, hr = 0, wag = dog ? 0.12 : 0, hop = 0, k = Math.min(1, dt * 5);
    let face = STALL.pet.yaw, after = null;
    if (near) {
      hy = Math.max(-1, Math.min(1, r.yaw));
      hp = Math.max(-0.6, Math.min(0.4, r.pitch));
    }
    const f = L.t / L.dur;
    switch (L.act) {
      case 'sit':
        if (dog) hp += Math.sin(time * 9) * 0.025;
        break;
      case 'stand':
        pose = 'stand';
        if (!near) { hy = L.yaw; hp = L.pitch; }
        wag = dog ? 0.35 : 0;
        break;
      case 'lie':
        pose = 'lie';
        hy *= 0.3;
        // Dozing off after a while, breathing slow.
        if (L.t > 2.5 && !near) { hy = L.side * 0.25; hp = (dog ? 0.28 : 0.2) + Math.sin(time * 0.9) * 0.03; }
        wag = 0;
        break;
      case 'scratch':
        hy = L.side * 0.35;
        hr = 0.35;
        hp = 0.1;
        after = () => { p.rightHind.rotation.x = -2.1 + Math.sin(L.t * 32) * 0.3; };
        break;
      case 'shake':
        pose = 'stand';
        if (L.t < dt * 1.5) poof([g.position.x, 0.5, g.position.z], 6, 0.3);
        after = () => { inner.rotation.z = Math.sin(L.t * 30) * 0.28 * (1 - f); };
        hr = Math.sin(L.t * 30 + 0.6) * 0.4 * (1 - f);
        k = Math.min(1, dt * 20);
        break;
      case 'groom':
        hy = 0.35;
        hp = 0.4 + Math.sin(L.t * 8) * 0.08;
        after = () => { p.leftFront.rotation.x = -1.35 + Math.sin(L.t * 8) * 0.15; };
        break;
      case 'stretch': {
        pose = 'stand';
        const e = envelope(L, 0.5);
        hp = -0.25 * e;
        after = () => {
          p.leftFront.rotation.x = p.rightFront.rotation.x = -0.9 * e;
          p.body.rotation.x = p.body.userData.rest[0] + 0.15 * e;
        };
        break;
      }
      case 'beg':
        face = g.rotation.y + r.yaw;
        hr = (Math.floor(L.t / 1.3) % 2 ? 1 : -1) * 0.32;
        wag = 0.6;
        break;
      case 'watch':
        face = g.rotation.y + r.yaw;
        break;
      case 'happy':
        pose = dog ? 'stand' : 'sit';
        face = g.rotation.y + r.yaw;
        wag = 0.85;
        hp = -0.25;
        if (dog) hop = Math.abs(Math.sin(L.t * 9)) * 0.09 * (1 - f);
        else hr = Math.sin(L.t * 3.2) * 0.3;
        if ((L.beat -= dt) <= 0 && f < 0.75) { L.beat = 0.35; hearts(p.head.getWorldPosition(petHead)); }
        if (!dog) after = () => { p.tail1.rotation.x = ease(p.tail1.rotation.x, 2.7, Math.min(1, dt * 6)); p.tail2.rotation.x = ease(p.tail2.rotation.x, 0.35, Math.min(1, dt * 6)); };
        break;
      case 'stroll': {
        // Off to one of the corners, a sniff or a look round there, then back.
        if (L.stage === 0) {
          const spots = STALL.pet.roam.map(q => plotXZ(...q)).filter(([x, z]) => Math.hypot(x - g.position.x, z - g.position.z) > 0.3);
          L.path = [[g.position.x, g.position.z], spots[Math.floor(Math.random() * spots.length)]];
          L.s = 0;
          L.stage = 1;
        }
        if (L.stage === 1 || L.stage === 3) {
          if (L.stage === 3 && !L.path) { L.path = [[g.position.x, g.position.z], [sx, sz]]; L.s = 0; }
          if (petWalk(pet, L, dt)) { L.stage++; L.t = 0; L.path = null; }
          return;
        }
        if (L.stage === 2) {
          if (dog) { pose = 'stand'; hp = 0.6; hy = Math.sin(L.t * 7) * 0.15; wag = 0.4; }
          if (L.t > L.pause) L.stage = 3;
          face = g.rotation.y;
        }
        if (L.stage === 4) {
          pose = 'stand';
          if (Math.abs(wrapAngle(STALL.pet.yaw - g.rotation.y)) < 0.03) setPetAct(L, 'sit', rand(4, 8));
        }
        break;
      }
    }
    if (still) { hy = 0; hp = 0; hr = 0; wag = 0; hop = 0; }
    g.rotation.y = turnToward(g.rotation.y, face, dt * (L.act === 'stroll' ? 4 : 1.6));
    posePet(pet, pose, Math.min(1, dt * 5));
    p.head.rotation.y = ease(p.head.rotation.y, hy, k);
    p.head.rotation.x = ease(p.head.rotation.x, hp, k);
    p.head.rotation.z = ease(p.head.rotation.z, hr, k);
    L.wag = ease(L.wag, wag, Math.min(1, dt * 3));
    if (p.tail) p.tail.rotation.y = Math.sin(time * 15) * L.wag;
    if (p.tail1) {
      p.tail1.rotation.y = still ? 0 : Math.sin(time * 1.2) * 0.3;
      p.tail2.rotation.y = still ? 0 : Math.sin(time * 1.2 - 1) * 0.4;
    }
    inner.position.y = hop;
    if (L.act !== 'shake') inner.rotation.z = ease(inner.rotation.z, 0, Math.min(1, dt * 6));
    after?.();
  }

  // The fish potters about its bowl, letting a bubble go now and then; fed,
  // it comes up for the flakes.
  function stepBowl(dt, time) {
    const b = trader.bowl;
    if (!b?.group.visible) return;
    const f = b.fish, [px, pz] = S.built.market.plot, [cx, cy, cz] = b.info.surface;
    f.fed = Math.max(0, f.fed - dt);
    if (f.fed > 0 && (f.nibble -= dt) <= 0) {
      f.nibble = rand(0.3, 0.6);
      f.to = [cx + rand(-0.08, 0.08), cy - 0.045, cz + rand(-0.08, 0.08)];
    }
    const d = f.to.map((v, k) => v - f.p[k]), len = Math.hypot(...d);
    if (len < 0.015) {
      if (f.fed <= 0) f.to = f.spot();
    } else {
      const step = Math.min(len, (f.fed > 0 ? 0.22 : 0.06) * dt);
      for (let k = 0; k < 3; k++) f.p[k] += d[k] / len * step;
      if (Math.hypot(d[0], d[2]) > 0.005) f.yaw = turnToward(f.yaw, Math.atan2(d[0], d[2]), dt * 4);
    }
    f.mesh.position.set(...f.p);
    f.mesh.rotation.y = f.yaw + (S.reducedMotion ? 0 : Math.sin(time * (f.fed > 0 ? 16 : 8)) * 0.2);
    if (!S.reducedMotion && (b.bubble -= dt) <= 0) {
      b.bubble = rand(1.5, 4);
      particles.embers.add({p: [px + f.p[0], f.p[1] + 0.03, pz + f.p[2]], v: [0, rand(0.12, 0.18), 0], c: [0.55, 0.75, 1, 0.7], s: rand(0.012, 0.02), life: rand(0.4, 0.6), age: 0});
    }
  }

  // A pinch of flakes on the water, and the fish up after them.
  function feedFish() {
    const b = trader.bowl;
    if (!b) return;
    const [px, pz] = S.built.market.plot, [cx, cy, cz] = b.info.surface;
    for (let i = 0; i < 9; i++) {
      particles.splash.add({p: [px + cx + rand(-0.08, 0.08), cy + 0.28, pz + cz + rand(-0.08, 0.08)], v: [rand(-0.1, 0.1), rand(0, 0.3), rand(-0.1, 0.1)], c: [0.85, 0.55, 0.25, 1], s: rand(0.015, 0.025), life: rand(0.28, 0.34), age: 0});
    }
    b.fish.fed = 3.5;
    b.fish.nibble = 0;
  }

  // Sits down at the review desk and switches the computer on; logging off
  // gets up again.
  async function useDesk() {
    if (reviewScreen.isOpen || !review.seat) return;
    await sit(review.seat);
    if (S.mode !== 'seated') return;
    freeMouse();
    setHover(null);
    await reviewScreen.open();
    if (S.mode === 'seated' && S.seat?.pc) await standUp();
    relock();
  }

  async function openShop(select) {
    if (market.shopOpen || trader.phase !== 'open') return;
    freeMouse();
    setHover(null);
    const shown = market.showShop({gui, post, pictures: trader.pictures, coin: post.coin, select});
    market.onBought(id => {
      gui.toast(gui.t('shopBought', gui.t('item_' + id)), gui.t(S.touch ? 'shopBoughtTouch' : 'shopBoughtBody'), trader.pictures[id]);
      swingArm();
      cheer();
    });
    await shown;
    relock();
    refreshHud();
    rebuildA11y();
  }

  market.onChange(what => {
    if (what === 'load') {
      syncMarket();
      rebuildPieces();
    } else if (what === 'arrive') {
      startComing();
      gui.toast(gui.t('traderArrived'), gui.t('traderArrivedBody'), traderIcon || post.coin);
    } else if (what === 'leave') {
      market.closeShop();
      reviewScreen.close();
      startGoing();
      gui.toast(gui.t('traderGone'), '', traderIcon || post.coin);
    } else if (what === 'warn') {
      gui.toast(gui.t('traderLeaving'), gui.t('traderLeavingBody', minutes(market.leavesIn())), traderIcon || post.coin);
    }
    refreshHud();
    rebuildA11y();
  });

  // ── Bought furniture ───────────────────────────────────────────────────
  // Each placed piece is its own group, moved and turned to where it
  // stands, with the hall's light baked into it there. A piece knows what
  // can be clicked on it, what it does, and what stops the walker.
  const pieces = {list: [], colliders: []};

  function pieceFrame(p) {
    const [w, d] = Goods.footprint(p.id, p.rot);
    return {center: [p.x + w / 2, S.built.layout.bases[p.floor] ?? 0, p.z + d / 2], angle: p.rot * Math.PI / 2, rot: p.rot, w, d};
  }
  // A point of a piece's own frame, in the world.
  function pieceWorld(f, [x, y, z]) {
    const [tx, tz] = Goods.turn([x, z], f.rot);
    return [f.center[0] + tx, f.center[1] + y, f.center[2] + tz];
  }
  // A box in a piece's own frame, as a box in the world.
  function pieceBox(f, [a, c]) {
    const p = pieceWorld(f, a), q = pieceWorld(f, c);
    return [[0, 1, 2].map(k => Math.min(p[k], q[k])), [0, 1, 2].map(k => Math.max(p[k], q[k]))];
  }

  function buildPiece(p) {
    const f = pieceFrame(p);
    const a = assemble(p.id, {material: blockMat, live: true});
    const {group, info, parts} = a;
    group.position.set(...f.center);
    group.rotation.y = f.angle;
    scene.add(group);
    group.updateMatrixWorld(true);
    for (const m of a.meshes) bakeLight(m);
    const pc = {data: p, group, info, parts, frame: f, rect: [p.x, p.z, p.x + f.w, p.z + f.d], box: pieceBox(f, info.pick), flames: info.flames.map(c => pieceWorld(f, c)), phase: Math.random() * 6.28};
    const around = S.built.grid.sample(pieceWorld(f, [0, 1, 0]), [0, 1, 0]);
    if (info.glass) {
      const [lo, hi] = info.glass;
      const glass = new T.Mesh(new T.BoxGeometry(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]), R.glassMaterial);
      glass.position.set((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2);
      glass.renderOrder = 3;
      glass.userData.noShadow = true;
      group.add(glass);
    }
    if (info.fish) {
      const [lo, hi] = info.fish;
      const spot = () => lo.map((v, k) => v + Math.random() * (hi[k] - v));
      pc.fish = Goods.FISH_COLOURS.map((colours, i) => {
        const mesh = Goods.fish(T, atlas, dynMat, colours, around);
        mesh.userData.noShadow = true;
        group.add(mesh);
        const fish = {mesh, p: spot(), to: spot(), spot, yaw: Math.random() * 6.28, speed: 0.11 + i * 0.035};
        mesh.position.set(...fish.p);
        return fish;
      });
    }
    if (info.bees) {
      pc.hive = info.bees.center;
      pc.bees = [0, 1, 2].map(i => {
        const b = Goods.creature(T, 'bee', atlas, dynMat, around);
        b.group.scale.setScalar(0.36);
        b.group.userData.noShadow = true;
        group.add(b.group);
        return {...b, a: i * 2.1, speed: 0.75 + i * 0.25, r: info.bees.radius * (0.8 + i * 0.15)};
      });
    }
    if (info.seat) pc.seat = seatOf(pc, info.seat);
    if (info.music) pc.horn = pieceWorld(f, info.notes);
    pc.act = info.music ? 'music' : info.seat ? (info.seat.telescope ? 'scope' : p.id === 'bed' ? 'lie' : 'sit') : null;
    const [w0, d0] = Goods.ITEMS[p.id].size;
    pc.solids = info.solid.map(([x0, z0, x1, z1]) => {
      const [[ax, , az], [bx, , bz]] = pieceBox(f, [[x0 - w0 / 2, 0, z0 - d0 / 2], [x1 - w0 / 2, 0, z1 - d0 / 2]]);
      return [ax, az, bx, bz, p.floor];
    });
    pieces.list.push(pc);
    return pc;
  }

  // A piece's seat in the world. A swing's along-the-bench range follows
  // the bench round with the piece.
  function seatOf(pc, s) {
    const f = pc.frame;
    const seat = {
      piece: pc, pos: pieceWorld(f, s.pos), yaw: f.angle + Math.PI, eye: s.eye, pitch: s.pitch, fov: s.fov,
      telescope: !!s.telescope, stand: !!s.stand, swing: !!s.swing, box: pieceBox(f, s.box || pc.info.pick),
    };
    if (s.along) {
      const ends = s.along.map(a => pieceWorld(f, [s.pos[0] + a, 0, s.pos[2]]));
      seat.alongX = f.rot % 2 === 0;
      const k = seat.alongX ? 0 : 2;
      seat.along = [Math.min(ends[0][k], ends[1][k]), Math.max(ends[0][k], ends[1][k])];
    }
    if (s.swing) seat.drop = pc.info.pivots.seat[1] - s.pos[1];
    return seat;
  }

  // Where a seat is now: a swing's bench moves as it sways.
  function seatPos(seat) {
    const bench = seat.swing && seat.piece?.parts.seat;
    if (!bench) return seat.pos;
    const a = bench.rotation.x, L = seat.drop;
    const [dx, dz] = Goods.turn([0, -L * Math.sin(a)], seat.piece.frame.rot);
    return [seat.pos[0] + dx, seat.pos[1] + L * (1 - Math.cos(a)), seat.pos[2] + dz];
  }

  function removePiece(pc) {
    if (music.piece === pc) stopMusic();
    disposeGroup(pc.group);
    pieces.list.splice(pieces.list.indexOf(pc), 1);
    refreshPieceColliders();
  }

  function refreshPieceColliders() {
    pieces.colliders = pieces.list.flatMap(pc => pc.solids);
    rebuildFoliage();
    shadowDirty = true;
  }

  // The plants loose on the grass, drawn round whatever furniture stands
  // on it, so no grass grows up through a bird bath.
  let foliageMesh = null;
  function rebuildFoliage() {
    disposeGroup(foliageMesh);
    foliageMesh = null;
    if (!S.built?.foliage || !atlas) return;
    const covered = new Set();
    for (const pc of pieces.list) {
      if (pc.data.floor !== 0) continue;
      for (let x = pc.rect[0]; x < pc.rect[2]; x++) for (let z = pc.rect[1]; z < pc.rect[3]; z++) covered.add(x + ',' + z);
    }
    const mb = new W.MeshBuilder();
    for (const [x, z, tex, size] of S.built.foliage) if (!covered.has(x + ',' + z)) W.cross(mb, S.built.grid, atlas, [x, 0, z], tex, size, 0);
    foliageMesh = new T.Mesh(mb.geometry(T), blockMat);
    scene.add(foliageMesh);
  }

  // Rebuilds every placed piece, for a new hall or a new look. One that no
  // longer fits where it stood (the hall grew over it) goes back in the
  // crate.
  function rebuildPieces() {
    for (const pc of pieces.list) disposeGroup(pc.group);
    pieces.list = [];
    if (music.piece) stopMusic();
    if (S.seat?.piece) { S.seat = null; if (S.mode === 'seated') setMode('overview'); }
    if (S.built && atlas && market.loaded) {
      const misfits = [];
      for (const p of market.state.placed.slice()) {
        if (canPlace(p.id, p.x, p.z, p.rot, p.floor, {ignore: p, player: false})) buildPiece(p);
        else misfits.push(p);
      }
      for (const p of misfits) {
        market.pickUp(p);
        gui.toast(gui.t('putBack'), gui.t('putBackBody', gui.t('item_' + p.id)), trader.pictures[p.id]);
      }
    }
    refreshPieceColliders();
  }

  // Whether piece `id` turned `rot` fits with its corner at (x, z) on
  // `floor`: floor under every cell (not the path), air above it as high as
  // it stands, and clear of walls, furniture, other pieces, the places kept
  // free, and the reader.
  function canPlace(id, x, z, rot, floor, {ignore = null, player = true} = {}) {
    const b = S.built;
    const base = b?.layout.bases[floor];
    if (base == null) return false;
    const [w, d] = Goods.footprint(id, rot), h = Goods.ITEMS[id].height;
    for (let cx = x; cx < x + w; cx++) for (let cz = z; cz < z + d; cz++) {
      if (!b.grid.solid(cx, base - 1, cz) || b.grid.get(cx, base - 1, cz) === W.B.path) return false;
      for (let y = 0; y < h; y++) if (b.grid.get(cx, base + y, cz)) return false;
    }
    const r = [x + 0.03, z + 0.03, x + w - 0.03, z + d - 0.03];
    const hit = ([x0, z0, x1, z1, f]) => (f || 0) === floor && r[0] < x1 && r[2] > x0 && r[1] < z1 && r[3] > z0;
    if (b.colliders.some(hit) || b.keepClear.some(hit)) return false;
    if (pieces.list.some(pc => pc.data !== ignore && hit([...pc.rect, pc.data.floor]))) return false;
    if (player && floor === S.floor && hit([S.px - BODY, S.pz - BODY, S.px + BODY, S.pz + BODY, floor])) return false;
    // A telescope needs room behind it to stand and look through it.
    const spot = standSpot(id);
    if (spot) {
      const [tx, tz] = Goods.turn([spot[0], spot[2]], rot);
      if (blocked(x + w / 2 + tx, z + d / 2 + tz, floor)) return false;
    }
    return true;
  }
  const standSpots = {};
  function standSpot(id) {
    if (!(id in standSpots)) {
      const seat = Goods.build(id, atlas).seat;
      standSpots[id] = seat?.stand ? seat.pos : null;
    }
    return standSpots[id];
  }

  function stepPieces(dt, time) {
    for (const pc of pieces.list) {
      const {parts} = pc;
      // The swing sways, more with someone in it.
      if (parts.seat) {
        const sat = S.seat && S.seat.piece === pc;
        const amp = S.reducedMotion ? 0 : sat ? 0.17 : 0.06;
        pc.amp = (pc.amp ?? amp) + (amp - (pc.amp ?? amp)) * Math.min(1, dt * 0.8);
        parts.seat.rotation.x = Math.sin(time * 1.75 + pc.phase) * pc.amp;
      }
      // Looked through, the telescope's tube follows the view.
      if (parts.tube) {
        const using = S.seat && S.seat.piece === pc && S.mode === 'seated';
        const yaw = using ? wrapAngle(S.yaw - pc.seat.yaw) : 0, pitch = using ? S.pitch : pc.info.aim;
        parts.tube.rotation.y += (yaw - parts.tube.rotation.y) * Math.min(1, dt * 10);
        parts.tube.rotation.x += (-pitch - parts.tube.rotation.x) * Math.min(1, dt * 10);
      }
      if (pc.fish) {
        for (const [i, f] of pc.fish.entries()) {
          const d = f.to.map((v, k) => v - f.p[k]);
          const len = Math.hypot(...d);
          if (len < 0.03) { f.to = f.spot(); continue; }
          const step = Math.min(len, f.speed * dt);
          for (let k = 0; k < 3; k++) f.p[k] += d[k] / len * step;
          f.yaw = turnToward(f.yaw, Math.atan2(d[0], d[2]), dt * 3);
          f.mesh.position.set(...f.p);
          f.mesh.rotation.y = f.yaw + (S.reducedMotion ? 0 : Math.sin(time * 9 + i * 2) * 0.18);
        }
      }
      if (pc.bees) {
        for (const [i, b] of pc.bees.entries()) {
          b.a += dt * b.speed;
          const [cx, cy, cz] = pc.hive;
          b.group.position.set(cx + Math.cos(b.a) * b.r, cy + Math.sin(time * 2.3 + i * 2) * 0.16, cz + Math.sin(b.a) * b.r);
          b.group.rotation.y = Math.atan2(-Math.sin(b.a), Math.cos(b.a));
          const flap = S.reducedMotion ? 0 : Math.sin(time * 55 + i) * 0.55;
          b.parts.rightWing.rotation.z = flap;
          b.parts.leftWing.rotation.z = -flap;
        }
      }
    }
  }

  // ── The gramophone ─────────────────────────────────────────────────────
  // A little waltz on a music box, luma's own, played through the hall's
  // sound and quieter the further off it is.
  const TUNE = [
    [76, 1, 48], [79, 1], [84, 1], [83, 2, 43], [79, 1], [81, 1, 45], [79, 1], [76, 1], [79, 3, 48],
    [77, 1, 41], [81, 1], [86, 1], [84, 2, 41], [81, 1], [83, 1, 43], [81, 1], [77, 1], [79, 3, 43],
    [76, 1, 48], [79, 1], [84, 1], [88, 2, 48], [86, 1], [84, 1, 41], [83, 1], [81, 1], [79, 2, 48], [76, 1],
    [77, 1, 50], [76, 1], [74, 1], [79, 2, 43], [71, 1], [74, 1.5, 43], [76, 0.5], [74, 1], [72, 3, 48], [null, 1],
  ];
  const BEAT = 0.42;
  const music = {piece: null, gain: null, next: 0, i: 0, hue: 0};

  function toggleMusic(pc) {
    if (music.piece === pc) stopMusic();
    else startMusic(pc);
    swingArm();
    rebuildA11y();
  }
  function startMusic(pc) {
    stopMusic();
    music.piece = pc;
    music.i = 0;
    music.next = 0;
  }
  function stopMusic() {
    const g = music.gain, ctx = weather.audio.ctx;
    if (g && ctx) {
      g.gain.setTargetAtTime(0, ctx.currentTime, 0.06);
      setTimeout(() => g.disconnect(), 700);
    }
    music.piece = null;
    music.gain = null;
  }
  // One plucked tine: the note and two faint overtones, dying away.
  function pluck(ctx, out, time, midi, level, long) {
    const f = 440 * 2 ** ((midi - 69) / 12);
    for (const [mult, amp, decay] of [[1, 1, long ? 1.6 : 1.1], [2, 0.22, 0.5], [4.2, 0.07, 0.22]]) {
      const o = ctx.createOscillator(), g = ctx.createGain();
      o.type = 'sine';
      o.frequency.value = f * mult;
      g.gain.setValueAtTime(0.0001, time);
      g.gain.linearRampToValueAtTime(level * amp, time + 0.006);
      g.gain.exponentialRampToValueAtTime(0.0001, time + decay);
      o.connect(g);
      g.connect(out);
      o.start(time);
      o.stop(time + decay + 0.05);
    }
  }
  function stepMusic(dt) {
    const pc = music.piece;
    if (!pc) return;
    // Notes drift up out of the horn, each its own colour as the game's are.
    if (Math.random() < dt * 2.4 * weather.particleScale) {
      music.hue = (music.hue + 0.13 + Math.random() * 0.1) % 1;
      const c = new T.Color().setHSL(music.hue, 0.9, 0.42);
      particles.notes.add({p: [pc.horn[0] + rand(-0.1, 0.1), pc.horn[1] + 0.05, pc.horn[2] + rand(-0.1, 0.1)], v: [rand(-0.12, 0.12), rand(0.4, 0.6), rand(-0.12, 0.12)], c: [c.r, c.g, c.b, 1], s: 0.11, g: 0, life: rand(1.4, 2), age: 0});
    }
    const A = weather.audio, ctx = A.ctx;
    if (!ctx || ctx.state !== 'running' || !A.master) return;
    if (!music.gain) {
      music.gain = ctx.createGain();
      music.gain.gain.value = 0;
      music.gain.connect(A.master);
      music.next = ctx.currentTime + 0.08;
    }
    const d = camera.position.distanceTo(new T.Vector3(...pc.horn));
    const inside = h => h && camera.position.x > h.x0 - 1 && camera.position.x < h.x1 + 1 && camera.position.z > h.z0 - 1 && camera.position.z < h.z1 + 1;
    const hall = S.built?.hall;
    const hornInside = hall && pc.horn[0] > hall.x0 - 1 && pc.horn[0] < hall.x1 + 1 && pc.horn[2] > hall.z0 - 1 && pc.horn[2] < hall.z1 + 1;
    const walls = inside(hall) !== !!hornInside ? 0.35 : 1;
    const level = 0.5 * Math.pow(Math.max(0, 1 - d / 18), 1.6) * walls;
    music.gain.gain.setTargetAtTime(level, ctx.currentTime, 0.12);
    while (music.next < ctx.currentTime + 0.5) {
      const [midi, beats, bass] = TUNE[music.i];
      if (midi != null) pluck(ctx, music.gain, music.next, midi, 0.16, beats >= 2);
      if (bass != null) pluck(ctx, music.gain, music.next, bass, 0.1, true);
      music.next += beats * BEAT;
      music.i = (music.i + 1) % TUNE.length;
    }
  }

  // ── Building ───────────────────────────────────────────────────────────
  // B (or a slot in the hotbar) takes what is in the crate in hand. A see-
  // through copy follows the crosshair across the floor, snapped to the
  // block grid: green where it fits, red where not. A click places it, R
  // turns it; right-click (or the pick-up tool) puts a placed piece back in
  // the crate.
  const BUILD_REACH = 7;
  const building = {on: false, id: null, rot: 0, ghost: null, ghostId: null, ghostMeshes: [], aim: null, target: null, flash: 0};
  // The quarter turn that has a piece's front facing the reader.
  const facingRot = () => (((Math.round(S.yaw / (Math.PI / 2)) % 4) + 4) % 4);
  const firstInCrate = () => Goods.CATALOG.find(c => market.count(c.id))?.id || null;

  function startBuilding(id = null) {
    if (S.mode !== 'overview' || !S.built) return;
    if (id && !market.count(id)) id = null;
    if (!id && !building.on) id = firstInCrate();
    if (!id && !pieces.list.length) return;
    if (!building.on || id !== building.id) building.rot = facingRot();
    building.on = true;
    building.id = id;
    setHover(null);
    refreshHud();
  }
  function stopBuilding() {
    building.on = false;
    building.target = building.aim = null;
    if (building.ghost) building.ghost.visible = false;
    outline.visible = false;
    refreshHud();
  }
  function toggleBuilding() {
    if (building.on) stopBuilding();
    else startBuilding();
  }
  function rotateBuilding() {
    building.rot = (building.rot + 1) % 4;
  }
  function togglePickTool() {
    building.id = building.id ? null : firstInCrate();
    refreshHud();
  }

  const buildRay = () => (look.locked ? rayAt(innerWidth / 2, innerHeight / 2) : rayAt(pointer.x, pointer.y));

  // The placed piece the ray meets first, near enough and before any wall.
  function pickPiece(ray) {
    const wall = wallDistance(ray) + 0.05;
    let best = null;
    for (const pc of pieces.list) {
      if (pc.data.floor !== S.floor) continue;
      const t = boxHit(ray, ...pc.box);
      if (t != null && t < Math.min(wall, REACH + 1) && (!best || t < best.t)) best = {pc, t};
    }
    return best;
  }

  // Where the piece in hand would go: the floor cell under the ray, the
  // footprint centred on it.
  function buildTarget(ray, id = building.id, rot = building.rot) {
    if (!id || ray.direction.y > -0.03) return null;
    const t = (floorY() - ray.origin.y) / ray.direction.y;
    if (t < 0 || t > BUILD_REACH || t > wallDistance(ray) + 0.3) return null;
    const p = ray.origin.clone().addScaledVector(ray.direction, t);
    const [w, d] = Goods.footprint(id, rot);
    const x = Math.round(p.x - w / 2), z = Math.round(p.z - d / 2);
    return {id, x, z, rot, floor: S.floor, ok: canPlace(id, x, z, rot, S.floor)};
  }

  function showGhost(t) {
    if (building.ghostId !== t.id) {
      disposeGroup(building.ghost);
      const a = assemble(t.id, {material: fitMat, light: [1, 0.6, 0]});
      a.group.userData.noShadow = true;
      for (const m of a.meshes) m.renderOrder = 4;
      scene.add(a.group);
      Object.assign(building, {ghost: a.group, ghostMeshes: a.meshes, ghostId: t.id});
    }
    const f = pieceFrame(t);
    building.ghost.position.set(f.center[0], f.center[1] + 0.003, f.center[2]);
    building.ghost.rotation.y = f.angle;
    for (const m of building.ghostMeshes) m.material = t.ok ? fitMat : misfitMat;
    building.ghost.visible = true;
  }

  function stepBuild(time) {
    fitMat.uniforms.opacity.value = 0.5 + 0.1 * Math.sin(time * 3);
    misfitMat.uniforms.opacity.value = 0.42 + 0.08 * Math.sin(time * 3);
    if (building.ghost) building.ghost.visible = false;
    building.aim = building.target = null;
    if (!building.on || S.mode !== 'overview' || flight || gui.isModalOpen() || !S.built) return;
    // Touch screens have nothing to follow until a tap.
    if (S.touch && !look.locked) return;
    const ray = buildRay();
    building.aim = pickPiece(ray);
    if (!building.id) {
      if (building.aim) outlineBox(building.aim.pc.box);
      return;
    }
    if (!market.count(building.id)) { building.id = firstInCrate(); return; }
    building.target = buildTarget(ray);
    if (building.target) showGhost(building.target);
  }

  function buildClick() {
    const ray = buildRay();
    if (!building.id) {
      const hit = pickPiece(ray);
      if (hit) pickUpPiece(hit.pc);
      return;
    }
    const t = buildTarget(ray);
    if (!t) return;
    if (!t.ok) {
      building.flash = performance.now() + 1500;
      refreshHud();
      setTimeout(refreshHud, 1550);
      return;
    }
    const p = market.place(t);
    if (!p) return;
    const pc = buildPiece(p);
    refreshPieceColliders();
    poof(pieceWorld(pc.frame, [0, 0.4, 0]), 14, 0.45);
    if (!market.count(building.id)) {
      const next = firstInCrate();
      if (next) building.id = next;
      else stopBuilding();
    }
    refreshHud();
    rebuildA11y();
  }

  function pickUpPiece(pc) {
    const p = pc.data;
    if (!market.pickUp(p)) return;
    poof(pieceWorld(pc.frame, [0, 0.4, 0]), 12, 0.45);
    removePiece(pc);
    // In hand again, turned as it was, ready to go somewhere else.
    building.id = p.id;
    building.rot = p.rot;
    refreshHud();
    rebuildA11y();
  }

  // The hotbar: one slot per piece the trader sells, in his order, so the
  // number keys always mean the same piece.
  function buildHotbar() {
    $('hotbar').replaceChildren(...Goods.CATALOG.map(item => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'slot';
      b.dataset.id = item.id;
      const img = document.createElement('img');
      img.alt = '';
      const count = document.createElement('span');
      count.className = 'count';
      b.append(img, count);
      b.onclick = () => { if (market.count(item.id)) startBuilding(item.id); };
      return b;
    }));
  }
  function refreshHotbar() {
    const shown = (S.mode === 'overview' || S.mode === 'seated') && (building.on || market.crateTotal() > 0);
    $('hotbar').hidden = !shown;
    for (const b of $('hotbar').children) {
      const id = b.dataset.id, n = market.count(id);
      const img = b.firstElementChild;
      if (trader.pictures[id] && img.getAttribute('src') !== trader.pictures[id]) img.src = trader.pictures[id];
      b.lastElementChild.textContent = n > 1 ? String(n) : '';
      b.classList.toggle('empty', !n);
      b.classList.toggle('on', building.on && building.id === id);
      b.title = gui.t('item_' + id);
      b.setAttribute('aria-label', `${gui.t('item_' + id)}: ${n}`);
    }
    $('build-tools').hidden = !(building.on && S.mode === 'overview');
    $('build-rotate').textContent = gui.t('buildRotate');
    $('build-pick').textContent = gui.t('buildPick');
    $('build-pick').classList.toggle('on', building.on && !building.id);
    $('build-done').textContent = gui.t('buildDone');
  }
  buildHotbar();
  $('build-rotate').onclick = rotateBuilding;
  $('build-pick').onclick = togglePickTool;
  $('build-done').onclick = stopBuilding;

  // ── Pictures ───────────────────────────────────────────────────────────
  // Each of the trader's goods photographed for the shop and the hotbar:
  // rendered off screen in a steady light, twice the size and scaled down
  // so the edges are smooth.
  function makePictures() {
    const out = {};
    const size = 96, big = size * 2;
    const renderer = R.renderer;
    const rt = new T.WebGLRenderTarget(big, big);
    const stage = new T.Scene();
    const cam = new T.PerspectiveCamera(26, 1, 0.05, 80);
    const mat = R.blockMaterial();
    Object.assign(mat.uniforms, {
      sunDir: {value: new T.Vector3(0.5, 0.82, 0.55).normalize()}, sunColor: {value: new T.Color(1.35, 1.2, 1.0)},
      skyColor: {value: new T.Color(0.55, 0.56, 0.62)}, skyLevel: {value: 1}, lampLevel: {value: 0}, fireLevel: {value: 0},
      fogDensity: {value: 0}, shadowOn: {value: 0}, flash: {value: 0}, overcast: {value: 0},
    });
    const before = {target: renderer.getRenderTarget(), color: renderer.getClearColor(new T.Color()), alpha: renderer.getClearAlpha()};
    const pixels = new Uint8Array(big * big * 4);
    const canvas = document.createElement('canvas');
    canvas.width = size; canvas.height = size;
    const ctx = canvas.getContext('2d');
    const toSrgb = v => Math.round(255 * Math.min(1, Math.pow(Math.max(0, v) * 1.12, 1 / 2.2)));
    try {
      for (const item of Goods.CATALOG) {
        const a = assemble(item.id, {material: mat, light: [1, 0, 0]});
        stage.add(a.group);
        const box = new T.Box3().setFromObject(a.group);
        const c = box.getCenter(new T.Vector3()), r = box.getSize(new T.Vector3()).length() / 2;
        cam.position.copy(c).addScaledVector(new T.Vector3(0.66, 0.52, 1).normalize(), r / Math.sin(cam.fov * DEG / 2) * 1.02);
        cam.lookAt(c);
        cam.updateMatrixWorld();
        renderer.setRenderTarget(rt);
        renderer.setClearColor(0x000000, 0);
        renderer.clear();
        renderer.render(stage, cam);
        renderer.readRenderTargetPixels(rt, 0, 0, big, big, pixels);
        const img = ctx.createImageData(size, size);
        for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
          let r0 = 0, g0 = 0, b0 = 0, a0 = 0;
          for (const [dx, dy] of [[0, 0], [1, 0], [0, 1], [1, 1]]) {
            const s = ((big - 1 - (y * 2 + dy)) * big + x * 2 + dx) * 4;
            const al = pixels[s + 3] / 255;
            r0 += pixels[s] / 255 * al; g0 += pixels[s + 1] / 255 * al; b0 += pixels[s + 2] / 255 * al; a0 += al;
          }
          const d = (y * size + x) * 4;
          if (a0 > 0) {
            img.data[d] = toSrgb(r0 / a0); img.data[d + 1] = toSrgb(g0 / a0); img.data[d + 2] = toSrgb(b0 / a0);
          }
          img.data[d + 3] = Math.round(a0 / 4 * 255);
        }
        ctx.putImageData(img, 0, 0);
        out[item.id] = canvas.toDataURL();
        stage.remove(a.group);
        a.group.traverse(o => o.geometry?.dispose());
      }
    } finally {
      renderer.setRenderTarget(before.target);
      renderer.setClearColor(before.color, before.alpha);
      rt.dispose();
      mat.dispose();
    }
    return out;
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
      // Captured: the mouse turns the head, no button needed; slower through
      // a telescope, so the view doesn't race.
      const sens = 0.0026 * (S.mode === 'seated' && S.seat?.fov ? Math.max(0.25, S.seat.fov / 70) : 1);
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
      else if (building.on) stopBuilding();
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
      } else if (e.code === 'KeyB' && !e.repeat) {
        toggleBuilding();
      } else if (/^Digit[1-8]$/.test(e.code)) {
        // The number keys pick a hotbar slot, as in the game.
        const item = Goods.CATALOG[Number(e.code.slice(5)) - 1];
        if (item && market.count(item.id)) startBuilding(item.id);
      } else if (building.on && e.code === 'KeyR' && !e.repeat) {
        rotateBuilding();
      } else if (building.on && e.code === 'KeyX' && !e.repeat) {
        togglePickTool();
      }
    }
  });
  // Right-click picks a placed piece back up while building.
  canvas.addEventListener('contextmenu', e => e.preventDefault());
  canvas.addEventListener('pointerdown', e => {
    if (e.button !== 2 || !building.on || S.mode !== 'overview' || flight) return;
    if (!look.locked) { pointer.x = e.clientX; pointer.y = e.clientY; }
    const hit = pickPiece(buildRay());
    if (hit) { swingArm(); pickUpPiece(hit.pc); }
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

  $('back').onclick = () => {
    if (S.mode === 'placing') return cancelPlacing();
    // At the review desk, logging off the computer gets you up.
    if (S.mode === 'seated' && S.seat?.pc && reviewScreen.isOpen) return reviewScreen.close();
    return S.mode === 'seated' ? standUp() : toOverview();
  };
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
      for (const a of classroom.actions(S.floor)) add(a.label, () => useClassroom(a));
      add(gui.t(door.target ? 'closeDoor' : 'openDoor'), () => { toggleDoor(); rebuildA11y(); });
      if (S.floor === 0) {
        add(`${gui.t('mailbox')} — ${post.state.letters.length ? gui.t('mailWaiting', post.state.letters.length) : mailNext()}`, () => useMailbox());
        add(`${gui.t('vault')} — ${gui.t('coins', post.state.vault)}`, () => useVault());
        if (S.built.market) add(traderTooltip().map(l => l.text ?? l).join(' — '), () => (trader.phase === 'open' ? openShop() : null));
      }
      if (review.seat && review.floor === S.floor) add(`${gui.t('pcTitle')} — ${gui.t('pcUse')}`, () => useDesk());
      for (const pc of pieces.list) {
        if (pc.data.floor !== S.floor || !pc.act) continue;
        const label = {lie: 'lieDown', sit: 'sit', scope: 'lookThrough', music: music.piece === pc ? 'stopMusic' : 'playMusic'}[pc.act];
        add(`${gui.t('item_' + pc.data.id)} — ${gui.t(label)}`, () => (pc.act === 'music' ? toggleMusic(pc) : sit(pc.seat)));
      }
      if (market.crateTotal() || pieces.list.length) add(gui.t(building.on ? 'buildDone' : 'crateHint'), () => toggleBuilding());
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
        for (let d = 0; d < W.drawerCount(c); d++) {
          const open = drawerState(c, d).target === 1;
          add(`${gui.t(open ? 'closeDrawer' : 'openDrawer')} ${d + 1}`, () => toggleDrawer(c, d));
          if (!open) continue;
          for (const book of c.subject.books) {
            if (W.isDrawerSlot(book.slot) && W.drawerOf(book.slot) === d) add(book.title, () => openSlot(book.slot, slotGeo(c, book.slot), book));
          }
        }
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
    // The vault panel sits low so the open safe stays in sight above it.
    if (gui.isModalOpen()) p.blurAll = post.vaultOpen ? 0.1 : 0.85;
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
    if (classroom.step(dt)) shadowDirty = true;
    stepDrawers(dt);
    stepCamera(dt, time);
    stepTweens(dt);
    stepHand(dt, time);
    stepPost(dt);
    stepMarket(dt, time);
    stepPieces(dt, time);
    stepMusic(dt);
    stepSitter(time);
    stepParticles(dt, time);
    if (look.locked || S.mode === 'seated') updateHover();
    stepBuild(time);
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
    // `?subjects=8` fills out more cases, enough for an upstairs.
    for (let i = subjects.length; i < Number(params.get('subjects') || 0); i++) subjects.push({id: 50 + i, name: `Subject ${i + 1}`, color: i % 16, books: []});
    const emit = m => setTimeout(() => receive(JSON.parse(JSON.stringify(m))), 20);
    const snapshot = () => emit({type: 'library', subjects});
    const findBook = id => { for (const s of subjects) { const b = s.books.find(x => x.id === id); if (b) return [s, b]; } return [null, null]; };
    const toBase64 = buf => { let s = ''; const bytes = new Uint8Array(buf); for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]); return btoa(s); };
    return {
      async handle(m) {
        switch (m.type) {
          case 'ready': {
            emit({type: 'init', strings: {}});
            snapshot();
            let mail = null;
            try { mail = JSON.parse(localStorage.getItem('library.mail') || 'null'); } catch { /* storage blocked */ }
            // `?coins=200` puts that much in the vault, for trying the shop.
            if (params.has('coins')) mail = {...(mail || {}), vault: Number(params.get('coins')) || 0};
            emit({type: 'mail', state: mail});
            let stock = null;
            try { stock = JSON.parse(localStorage.getItem('library.market') || 'null'); } catch { /* storage blocked */ }
            // `?trader` has the wandering trader at his stall from the start.
            if (params.has('trader')) stock = {...(stock || {}), clock: LibraryMarket.ARRIVE};
            // `?pet=dog|cat|fish` picks the pet he has with him.
            if (params.has('pet')) stock = {...(stock || {}), pet: params.get('pet')};
            emit({type: 'market', state: stock});
            LibraryClassroom.demo(m, emit);
            break;
          }
          case 'mail': try { localStorage.setItem('library.mail', JSON.stringify(m.state)); } catch { /* storage blocked */ } break;
          case 'market': try { localStorage.setItem('library.market', JSON.stringify(m.state)); } catch { /* storage blocked */ } break;
          case 'classroom': LibraryClassroom.demo(m, emit); break;
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
          // A stand-in reviewer for the preview: longer books score higher.
          case 'reviewBook': {
            const [, b] = findBook(m.id);
            const words = (b?.body || '').split(/\s+/).filter(Boolean).length;
            const score = Math.min(96, 30 + words * 4);
            const coins = score < 60 ? 0 : Math.max(1, Math.min(50, Math.round(1 + (score - 60) * 49 / 40)));
            setTimeout(() => emit({type: 'reviewed', request: m.request, result: {
              score, coins, verdict: score < 60 ? 'A promising start' : 'A lovely little read',
              praise: 'The opening line pulls you straight in.',
              tips: ['Add a concrete detail or two so the reader can picture it.', 'Give it an ending that answers the first line.'],
            }}), 1500);
            break;
          }
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
    S, R, W, V, view, hand, sitter, door, weather, climb, blocked, post, mailbox, vault, coins,
    market, trader, life, cheer, cuddle, pieces, building, music, pointer, reviewScreen, useDesk, openShop, startBuilding, stopBuilding, buildClick, canPlace, buildTarget, pickPiece, rayAt,
    get hover() { return hover; },
    get flight() { return flight; },
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
