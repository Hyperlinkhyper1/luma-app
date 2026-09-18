(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const status = $('status'), error = $('error'), statsBox = $('stats');
  let counter = 0, ready = false;

  function send(message) {
    message.id = message.id || `scene-${++counter}`;
    if (window.chrome?.webview) window.chrome.webview.postMessage(JSON.stringify(message));
    else if (window.flutter_inappwebview?.callHandler) window.flutter_inappwebview.callHandler('airport', message);
    else if (window.airportPreview) window.airportPreview.command(message);
  }
  function fail(message) {
    error.style.display = 'block';
    error.textContent = `The 3D airport could not start. ${message} Update your graphics driver or Android System WebView, then reopen the airport.`;
    $('loading').classList.add('hidden');
    send({type: 'error', message: String(message)});
  }
  let started = false;
  // After the first frame a stray error must not take the whole airport down.
  window.addEventListener('error', e => { if (started) console.error(e.error || e.message); else fail(e.message); });
  if (!window.THREE || !window.AirportModels) { fail('A bundled scene asset is missing.'); return; }
  const T = THREE, M = AirportModels, L = AirportSceneLogic;

  // ── Renderer, sky and light ───────────────────────────────────────────
  let renderer;
  try { renderer = new T.WebGLRenderer({antialias: true, alpha: false, powerPreference: 'high-performance'}); }
  catch (e) { fail(e.message); return; }
  renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
  renderer.setSize(innerWidth, innerHeight);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = T.PCFSoftShadowMap;
  renderer.outputColorSpace = T.SRGBColorSpace;
  renderer.toneMapping = T.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  document.body.prepend(renderer.domElement);

  const scene = new T.Scene();
  try { scene.environment = M.init(renderer); } catch (_) { scene.environment = null; }
  scene.background = new T.Color(0xaed3e6);
  scene.fog = new T.Fog(0xaed3e6, 2200, 7000);
  // A gradient dome with the sun, the moon and stars on it. It follows the
  // camera and is drawn first, behind everything, so it never clips.
  const skyUniforms = {
    zenith: {value: new T.Color()}, horizon: {value: new T.Color()}, below: {value: new T.Color()},
    sunColor: {value: new T.Color()}, sunDir: {value: new T.Vector3(0, 1, 0)}, moonDir: {value: new T.Vector3(0, -1, 0)},
    stars: {value: 0},
  };
  const sky = new T.Mesh(new T.SphereGeometry(1, 48, 24), new T.ShaderMaterial({
    uniforms: skyUniforms, side: T.BackSide, depthWrite: false, depthTest: false, fog: false,
    vertexShader: 'varying vec3 vDir; void main() { vDir = position; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
    fragmentShader: [
      'uniform vec3 zenith, horizon, below, sunColor, sunDir, moonDir;',
      'uniform float stars;',
      'varying vec3 vDir;',
      'float hash(vec3 p) { p = fract(p * .3183099 + .1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }',
      'void main() {',
      '  vec3 d = normalize(vDir);',
      '  float h = d.y;',
      '  vec3 col = h > 0.0 ? mix(horizon, zenith, pow(clamp(h, 0.0, 1.0), .42)) : mix(horizon, below, clamp(-h * 5.0, 0.0, 1.0));',
      '  float s = max(dot(d, sunDir), 0.0), up = smoothstep(-.12, .05, sunDir.y);',
      '  col += sunColor * (pow(s, 5.0) * .28 + pow(s, 48.0) * .55) * up;',
      '  col += sunColor * smoothstep(.99945, .9997, s) * 6.0 * smoothstep(-.03, .0, sunDir.y);',
      '  float m = max(dot(d, moonDir), 0.0);',
      '  col += vec3(.9, .94, 1.0) * smoothstep(.9994, .99965, m) * 1.6 * stars;',
      '  col += vec3(.25, .33, .5) * pow(m, 24.0) * .2 * stars;',
      '  vec3 cell = floor(d * 520.0);',
      '  float star = step(.9982, hash(cell)) * smoothstep(0.02, .3, h);',
      '  col += vec3(.9, .93, 1.0) * star * stars * (.45 + .55 * hash(cell + 7.0));',
      '  gl_FragColor = vec4(col, 1.0);',
      '  #include <tonemapping_fragment>',
      '  #include <colorspace_fragment>',
      '}',
    ].join('\n'),
  }));
  sky.frustumCulled = false;
  sky.renderOrder = -1000;
  scene.add(sky);
  // The native window can load the page before it has a size; a 0×0 viewport
  // would otherwise poison the camera with NaN for good.
  const aspect = () => innerWidth > 0 && innerHeight > 0 ? innerWidth / innerHeight : 16 / 9;
  const camera = new T.PerspectiveCamera(38, aspect(), 1, 16000);
  const hemi = new T.HemisphereLight(0xe6f4ff, 0x8a8f78, 1.6);
  scene.add(hemi);
  const sun = new T.DirectionalLight(0xfff0d8, 3);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  sun.shadow.bias = -.0003;
  sun.shadow.normalBias = .6;
  scene.add(sun, sun.target);

  const groundTexture = M.textures.grass[0].clone();
  groundTexture.needsUpdate = true;
  groundTexture.repeat.set(18000 / 24, 18000 / 24);
  // Pushed back in depth as well as down, so pavements never fight it.
  const ground = new T.Mesh(new T.PlaneGeometry(18000, 18000), M.weather(new T.MeshStandardMaterial({map: groundTexture, roughness: 1, envMapIntensity: .35, color: 0xc9d8bf, polygonOffset: true, polygonOffsetFactor: 2, polygonOffsetUnits: 4}), .45, 90));
  ground.rotation.x = -Math.PI / 2;
  ground.position.y = -.08;
  ground.receiveShadow = true;
  scene.add(ground);

  const facilities = new Map(), entities = new Map(), environment = new T.Group();
  scene.add(environment);
  const grid = new T.GridHelper(2500, 500, 0x7a8c86, 0x7a8c86);
  grid.position.y = .35;
  grid.material.transparent = true;
  grid.material.opacity = .22;
  grid.visible = false;
  scene.add(grid);
  const fineGrid = new T.GridHelper(400, 400, 0x5d6f70, 0x5d6f70);
  fineGrid.material.transparent = true;
  fineGrid.material.opacity = .18;
  fineGrid.visible = false;
  scene.add(fineGrid);
  const outline = new T.BoxHelper(new T.Mesh(new T.BoxGeometry(1, 1, 1)), 0xf2c230);
  outline.visible = false;
  scene.add(outline);
  const ghostOk = new T.MeshBasicMaterial({color: 0x57d9a3, transparent: true, opacity: .45, depthWrite: false});
  const ghostBad = new T.MeshBasicMaterial({color: 0xff6b81, transparent: true, opacity: .45, depthWrite: false});
  let ghost = null, ghostKey = '';

  const target = new T.Vector3(140, 0, 170);
  let distance = 500, azimuth = .8, polar = .78;
  let active = true, cutaway = false, world = null, tool = null, selected = null, quality = 'high', gridWanted = false, district = null;
  let receivedAt = performance.now();
  const interiorKinds = () => new Set((world?.catalog || []).filter(d => d.interior).map(d => d.kind).concat(['entrance', 'checkIn', 'checkInCounter', 'infoDesk', 'bins', 'infoPanel', 'ticketMachine', 'security', 'customs', 'checkOut', 'seating', 'toilets', 'cafe', 'restaurant', 'vendingMachine', 'coffeeToGo', 'foodCart', 'boardingGate', 'shop', 'kiosk', 'foodShop', 'perfumeShop', 'flowerShop', 'clothingShop', 'luxuryBoutique', 'lounge', 'vipLounge', 'arcade', 'plant', 'fountain', 'infoBoard', 'baggageCarousel']));
  const standKinds = new Set(['stand', 'standRegional', 'standContact']);

  function cameraUpdate() {
    if (!Number.isFinite(distance)) distance = 500;
    if (!Number.isFinite(azimuth)) azimuth = .8;
    if (!Number.isFinite(polar)) polar = .78;
    if (!Number.isFinite(target.x) || !Number.isFinite(target.z)) target.set(140, 0, 170);
    camera.position.set(
      target.x + Math.sin(azimuth) * Math.sin(polar) * distance,
      target.y + Math.cos(polar) * distance,
      target.z + Math.cos(azimuth) * Math.sin(polar) * distance);
    camera.lookAt(target);
    // Depth precision follows the near plane. A fixed near of 1 m left a few
    // centimetres between the grass, the pavements and their paint unresolved
    // from a few hundred metres up, so they flickered through each other.
    const height = Math.max(1, camera.position.y);
    camera.near = Math.min(400, Math.max(.5, height * .15));
    camera.far = Math.max(camera.near * 60, Math.min(30000, distance * 8 + 9000));
    camera.updateProjectionMatrix();
    sky.scale.setScalar(camera.far * .8);
    scene.fog.near = 1400 + distance * 1.4;
    scene.fog.far = 7000 + distance * 3;
    $('compass').style.transform = `rotate(${-azimuth}rad)`;
    const reach = Math.min(1100, Math.max(160, distance * .9));
    Object.assign(sun.shadow.camera, {left: -reach, right: reach, top: reach, bottom: -reach, near: 1, far: 3200});
    sun.shadow.camera.updateProjectionMatrix();
  }

  // ── Time of day ───────────────────────────────────────────────────────
  function gameTime() {
    if (!world) return 360;
    const elapsed = world.paused ? 0 : Math.min(1.5, (performance.now() - receivedAt) / 1000);
    return (world.time || 0) + elapsed * (world.speed || 1);
  }
  // Sky palettes by sun elevation (sine of the angle above the horizon):
  // deep night, blue hour, sunrise/sunset, golden hour and full day.
  // Columns: zenith, horizon, below the horizon, sunlight.
  const skyKeys = [
    [-.35, 0x03060d, 0x0b1222, 0x0a0f18, 0x8ea6e8],
    [-.1, 0x0d1631, 0x2a2f4c, 0x121620, 0x9aa9e0],
    [0, 0x27406e, 0xf08d55, 0x3a3834, 0xff8a45],
    [.1, 0x3a67a6, 0xf2c08c, 0x6f7568, 0xffbf7e],
    [.32, 0x3b78c0, 0xbad6e8, 0x7c8a82, 0xfff0da],
    [1, 0x2c69b8, 0xa9cde4, 0x7c8a82, 0xfff7ec],
  ].map(([at, ...colors]) => [at, ...colors.map(c => new T.Color(c))]);
  const skyScratch = [new T.Color(), new T.Color(), new T.Color(), new T.Color()];
  function palette(elevation) {
    let i = 0;
    while (i < skyKeys.length - 2 && elevation > skyKeys[i + 1][0]) i++;
    const [a, b] = [skyKeys[i], skyKeys[i + 1]];
    const t = Math.min(1, Math.max(0, (elevation - a[0]) / (b[0] - a[0])));
    return skyScratch.map((c, k) => c.copy(a[k + 1]).lerp(b[k + 1], t));
  }
  const smooth = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
  const sunDir = new T.Vector3(), moonDir = new T.Vector3(), lightDir = new T.Vector3();
  const moonLight = new T.Color(0x8fa6e6), white = new T.Color(0xffffff);
  let lastNight = -1, darkness = 0;
  function daylight(time) {
    const hour = ((time % 1440) + 1440) % 1440 / 60;
    // Sunrise at 06:00, sunset at 20:00; the sun keeps turning below the
    // horizon overnight so dusk and dawn are continuous.
    const angle = hour >= 6 && hour <= 20 ? (hour - 6) / 14 * Math.PI : Math.PI + ((hour + 4) % 24) / 10 * Math.PI;
    sunDir.set(-Math.cos(angle), Math.sin(angle) * .92, .42).normalize();
    moonDir.set(Math.cos(angle) * .8, -Math.sin(angle) * .75 + .12, -.5).normalize();
    const elevation = sunDir.y;
    const [zenith, horizon, below, sunColor] = palette(elevation);
    skyUniforms.zenith.value.copy(zenith);
    skyUniforms.horizon.value.copy(horizon);
    skyUniforms.below.value.copy(below);
    skyUniforms.sunColor.value.copy(sunColor);
    skyUniforms.sunDir.value.copy(sunDir);
    skyUniforms.moonDir.value.copy(moonDir);
    const day = smooth(-.06, .16, elevation), night = 1 - smooth(-.12, .06, elevation);
    skyUniforms.stars.value = smooth(-.02, -.22, elevation);
    // By day the directional light is the sun; by night it is a dim, cool
    // moon, so the airport stays readable and still has a light direction.
    const useMoon = elevation < -.04;
    lightDir.copy(useMoon ? moonDir : sunDir);
    lightDir.y = Math.max(lightDir.y, .2);
    lightDir.normalize();
    sun.position.copy(target).addScaledVector(lightDir, 1400);
    sun.target.position.copy(target);
    if (useMoon) { sun.color.copy(moonLight); sun.intensity = .55 * smooth(-.04, -.2, elevation); }
    else { sun.color.copy(sunColor); sun.intensity = 3.9 * day * (.45 + .55 * Math.min(1, elevation * 2.2)); }
    sun.castShadow = !useMoon && day > .02;
    hemi.intensity = .34 + .66 * day;
    hemi.color.copy(zenith).lerp(horizon, .5).lerp(white, .35 * day);
    hemi.groundColor.set(0x6d6f5e).multiplyScalar(.35 + .65 * day);
    scene.background.copy(horizon);
    scene.fog.color.copy(horizon).lerp(zenith, .25);
    renderer.toneMappingExposure = .9 + .22 * day;
    darkness = night;
    if (Math.abs(night - lastNight) > .01) { M.setNight(night); lastNight = night; }
  }

  // ── Facilities ────────────────────────────────────────────────────────
  const sides = {'+x': [1, 0], '+z': [0, 1], '-x': [-1, 0], '-z': [0, -1]};
  function localSide(worldSide, turn) {
    const [x, z] = sides[worldSide], th = -turn * Math.PI / 2;
    const lx = Math.round(x * Math.cos(th) + z * Math.sin(th)), lz = Math.round(-x * Math.sin(th) + z * Math.cos(th));
    return Object.keys(sides).find(k => sides[k][0] === lx && sides[k][1] === lz);
  }
  function touchingSide(a, b) {
    const overlapX = Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x);
    const overlapZ = Math.min(a.y + a.depth, b.y + b.depth) - Math.max(a.y, b.y);
    if (overlapZ > 1 && Math.abs(b.x - (a.x + a.width)) < 1.2) return '+x';
    if (overlapZ > 1 && Math.abs(b.x + b.width - a.x) < 1.2) return '-x';
    if (overlapX > 1 && Math.abs(b.y - (a.y + a.depth)) < 1.2) return '+z';
    if (overlapX > 1 && Math.abs(b.y + b.depth - a.y) < 1.2) return '-z';
    return null;
  }
  const turnOf = f => ((Math.round(f.rotation || 0) % 4) + 4) % 4;
  /** A world point in [f]'s model frame (the inverse of M.facility's transform). */
  function toLocal(f, wx, wz) {
    const turn = turnOf(f), w = turn % 2 ? f.depth : f.width, d = turn % 2 ? f.width : f.depth;
    const px = f.x + (turn === 2 ? w : turn === 3 ? d : 0), pz = f.y + (turn === 1 ? w : turn === 2 ? d : 0);
    const th = turn * Math.PI / 2, dx = wx - px, dz = wz - pz;
    return [dx * Math.cos(th) - dz * Math.sin(th), dx * Math.sin(th) + dz * Math.cos(th)];
  }
  const round = n => Math.round(n * 100) / 100;
  /** A world rectangle [x0, z0, x1, z1] in [f]'s model frame. */
  function rectToLocal(f, r) {
    const [ax, az] = toLocal(f, r[0], r[1]), [bx, bz] = toLocal(f, r[2], r[3]);
    return [round(Math.min(ax, bx)), round(Math.min(az, bz)), round(Math.max(ax, bx)), round(Math.max(az, bz))];
  }
  /** The world side a stand's aircraft noses towards: the terminal it serves. */
  function noseWorldSide(f, list) {
    let worldSide = null, best = Infinity;
    for (const t of list) if (t.kind === 'terminal') {
      const touching = touchingSide(f, t);
      const dx = t.x + t.width / 2 - (f.x + f.width / 2), dz = t.y + t.depth / 2 - (f.y + f.depth / 2);
      const gapX = Math.max(0, Math.abs(dx) - (t.width + f.width) / 2), gapZ = Math.max(0, Math.abs(dz) - (t.depth + f.depth) / 2);
      const distance = touching ? -1 : Math.hypot(gapX, gapZ);
      if (distance < best) { best = distance; worldSide = touching || (gapX >= gapZ ? (dx > 0 ? '+x' : '-x') : (dz > 0 ? '+z' : '-z')); }
    }
    return worldSide || worldOf('+x', turnOf(f));
  }
  function worldOf(local, turn) { return Object.keys(sides).find(k => localSide(k, turn) === local); }

  // ── Pavement junctions ────────────────────────────────────────────────
  // Where taxiways, stands and runways touch, their edge lines give way over
  // the shared stretch, and yellow centrelines are joined up: a stand's
  // lead-in line runs on to the taxiway centreline, and a taxiway ending on
  // another one meets its centreline, curving across when they are offset.
  const paved = f => f.kind === 'taxiway' || f.kind.startsWith('runway') || standKinds.has(f.kind);
  const opposite = {'+x': '-x', '-x': '+x', '+z': '-z', '-z': '+z'};
  const vertical = f => f.depth >= f.width;
  function pavementJoins(list) {
    const cuts = new Map(), curves = [];
    const cut = (f, rect) => { if (!cuts.has(f.id)) cuts.set(f.id, []); cuts.get(f.id).push(rect); };
    const pads = list.filter(paved);
    for (const a of pads) for (const b of pads) {
      if (a === b) continue;
      const side = touchingSide(a, b);
      if (!side) continue;
      const alongX = side.endsWith('z'), [nx, nz] = sides[side], sign = nx || nz;
      const lo = alongX ? Math.max(a.x, b.x) : Math.max(a.y, b.y);
      const hi = alongX ? Math.min(a.x + a.width, b.x + b.width) : Math.min(a.y + a.depth, b.y + b.depth);
      const edge = alongX ? (nz > 0 ? a.y + a.depth : a.y) : (nx > 0 ? a.x + a.width : a.x);
      const inner = edge - sign * 2.6;
      cut(a, alongX ? [lo, Math.min(edge, inner), hi, Math.max(edge, inner)] : [Math.min(edge, inner), lo, Math.max(edge, inner), hi]);
      // Centreline hand-over: only from a taxiway's end, or a stand's entry.
      if (b.kind !== 'taxiway' && !b.kind.startsWith('runway')) continue;
      if (a.kind === 'taxiway' ? vertical(a) !== alongX : !(standKinds.has(a.kind) && side === opposite[noseWorldSide(a, list)])) continue;
      if (standKinds.has(a.kind) && b.kind !== 'taxiway') continue;
      const lateral = alongX ? a.x + a.width / 2 : a.y + a.depth / 2;
      const E = alongX ? [lateral, edge] : [edge, lateral];
      const alongEdge = alongX !== vertical(b);
      if (alongEdge) {
        // B runs along the edge: straight on to its centreline.
        if (lateral < lo - .5 || lateral > hi + .5) continue;
        const centre = alongX ? b.y + b.depth / 2 : b.x + b.width / 2;
        curves.push(alongX ? [E, [lateral, centre]] : [E, [centre, lateral]]);
        continue;
      }
      // End to end: an S-bend on to B's centreline when the two are offset.
      if (!b.kind.startsWith('taxiway') || (a.kind === 'taxiway' && a.id > b.id)) continue;
      const bLateral = alongX ? b.x + b.width / 2 : b.y + b.depth / 2, shift = bLateral - lateral;
      if (Math.abs(shift) < .4) continue;
      const bLength = alongX ? b.depth : b.width;
      const L = Math.min(Math.max(Math.abs(shift) * 2.2, 14), bLength * .6);
      const at = (lat, along) => alongX ? [lat, along] : [along, lat];
      const points = [];
      for (let i = 0; i <= 14; i++) {
        const t = i / 14, s = t * t * (3 - 2 * t);
        points.push(at(lateral + shift * s, edge + sign * L * t));
      }
      curves.push(points);
      // Hide B's own centreline where the bend replaces it.
      const far = edge + sign * L;
      cut(b, alongX ? [bLateral - .8, Math.min(edge, far), bLateral + .8, Math.max(edge, far)] : [Math.min(edge, far), bLateral - .8, Math.max(edge, far), bLateral + .8]);
    }
    return {cuts, curves};
  }

  function contextFor(f, list, joins) {
    const turn = turnOf(f);
    if (f.kind === 'terminal') {
      const open = {}, doors = [];
      for (const t of list) if (t.kind === 'terminal' && t.id !== f.id) { const side = touchingSide(f, t); if (side) open[localSide(side, turn)] = true; }
      // Entrances cut a doorway into whichever outside wall the simulation
      // sends their passengers through.
      const w = turn % 2 ? f.depth : f.width, d = turn % 2 ? f.width : f.depth;
      for (const e of list) {
        const at = e.kind === 'entrance' && e.door?.door;
        if (!at || at[0] < f.x - .5 || at[0] > f.x + f.width + .5 || at[1] < f.y - .5 || at[1] > f.y + f.depth + .5) continue;
        const [lx, lz] = toLocal(f, at[0], at[1]);
        const side = Math.abs(lz) < .6 ? '-z' : Math.abs(lz - d) < .6 ? '+z' : Math.abs(lx) < .6 ? '-x' : Math.abs(lx - w) < .6 ? '+x' : null;
        if (side) doors.push({side, at: round(side.endsWith('z') ? lx : lz)});
      }
      return {open, doors};
    }
    const cuts = (joins?.cuts.get(f.id) || []).map(r => rectToLocal(f, r));
    if (standKinds.has(f.kind)) {
      // Aircraft park nose-in towards the terminal they serve.
      const worldSide = noseWorldSide(f, list);
      return {noseSide: ['+x', '+z', '-x', '-z'].indexOf(localSide(worldSide, turn)), cuts};
    }
    if (paved(f)) return {cuts};
    return {};
  }
  function roofMode() {
    for (const {mesh} of facilities.values()) mesh.traverse(o => { if (o.userData.roof) o.visible = !cutaway; });
  }
  function bounds(includeRunway) {
    const b = new T.Box3();
    for (const {data: f} of facilities.values()) {
      if (!includeRunway && (f.kind.startsWith('runway') || f.kind === 'taxiway' || f.kind === 'serviceRoad')) continue;
      b.expandByPoint(new T.Vector3(f.x, 0, f.y));
      b.expandByPoint(new T.Vector3(f.x + f.width, 20, f.y + f.depth));
    }
    return b;
  }
  function frame(includeRunway = false) {
    const b = bounds(includeRunway);
    if (b.isEmpty()) return;
    b.getCenter(target); target.y = 0;
    const size = b.getSize(new T.Vector3());
    distance = Math.max(150, Math.max(size.x, size.z) / (Math.tan(camera.fov * Math.PI / 360) * Math.min(camera.aspect, 1)) * .72);
    azimuth = .8; polar = .78;
    cameraUpdate();
  }
  /** Joined-up taxi lines, drawn over the pavements in world space. */
  function drawMarkings(g, curves) {
    const yellow = 0xf1c643;
    for (const points of curves) {
      for (let i = 1; i < points.length; i++) {
        const [a, b] = [points[i - 1], points[i]];
        if (Math.hypot(b[0] - a[0], b[1] - a[1]) > .01) M.line(g, a[0], a[1], b[0], b[1], .35, yellow, .168);
        if (i < points.length - 1) M.cylinder(g, .175, .02, b[0], .168, b[1], yellow, 'paint', .175, 10).castShadow = false;
      }
    }
  }
  /** The kerbside outside an entrance door: a porch roof over the doors, a
      paved apron out to the kerb and a drop-off lane. On the landside wall
      the forecourt already provides all of it. */
  function drawPorch(g, e, list, porches) {
    const [dx, dz] = e.door.door, [kx, kz] = e.door.kerb;
    const len = Math.hypot(kx - dx, kz - dz) || 1, nx = (kx - dx) / len, nz = (kz - dz) / len;
    const L = district?.L;
    if (L && Math.abs(nx - L.dir[0]) < .01 && Math.abs(nz - L.dir[1]) < .01 && Math.abs((dx - L.origin.x) * nx + (dz - L.origin.z) * nz) < 1) return;
    // Local frame: u outward from the door, v along the wall.
    const at = (u, v) => [dx + nx * u - nz * v, dz + nz * u + nx * v];
    const rect = (u0, u1, v0, v1) => {
      const [ax, az] = at(u0, v0), [bx, bz] = at(u1, v1);
      return {minX: Math.min(ax, bx), maxX: Math.max(ax, bx), minZ: Math.min(az, bz), maxZ: Math.max(az, bz)};
    };
    const blocked = r => list.some(f => !interiorKinds().has(f.kind) && f.kind !== 'terminal' && f.x < r.maxX && f.x + f.width > r.minX && f.y < r.maxZ && f.y + f.depth > r.minZ);
    const put = (u0, u1, v0, v1, h, y, color, kind) => {
      const r = rect(u0, u1, v0, v1);
      return M.box(g, r.maxX - r.minX, h, r.maxZ - r.minZ, (r.minX + r.maxX) / 2, y, (r.minZ + r.maxZ) / 2, color, kind);
    };
    const apron = rect(0, len + 1.5, -8, 8);
    if (blocked(apron)) return;
    porches.push(apron);
    put(0, len + 1.5, -8, 8, .12, .06, 0xc8c4ba, 'concrete');
    put(len + 1.2, len + 1.6, -8, 8, .3, .15, 0xb9b5aa, 'concrete');
    // Porch roof on two columns, lit from underneath.
    put(0, 7.5, -6, 6, .35, 5.6, 0xe9ebe7, 'metal');
    put(7.2, 7.8, -6, 6, .9, 5.3, 0x2e6c78);
    for (const v of [-5, 5]) {
      const [cx, cz] = at(6.6, v);
      M.cylinder(g, .22, 5.4, cx, 2.7, cz, 0xb5bdbf, 'metal');
    }
    for (const v of [-3, 0, 3]) { const [lx, lz] = at(4, v); M.light(g, lx, 5.35, lz, 0xfff0c8, .45); M.pool(g, lx, lz, 4.5, 0xffe8b8); }
    for (let v = -7; v <= 7; v += 2) { const [bx, bz] = at(len + .9, v); M.box(g, .28, .9, .28, bx, .45, bz, 0xbcc3c4, 'metal'); }
    const [sx, sz] = at(7.85, 0);
    M.label(g, 'DEPARTURES', sx, 5.3, sz, .8, '#eef6f4', {rotY: Math.atan2(nx, nz), width: 5});
    // Drop-off lane along the kerb, if there is room for one.
    const lane = rect(len + 1.6, len + 9.6, -18, 18);
    if (!blocked(lane)) {
      porches.push(lane);
      put(len + 1.6, len + 9.6, -18, 18, .1, .05, 0xd2d5d0, 'asphalt');
      for (let v = -16; v < 16; v += 5) put(len + 5.5, len + 5.7, v, v + 2.5, .02, .11, 0xf2f0e6);
      put(len + 1.9, len + 2.1, -17.5, 17.5, .02, .11, 0xe0b23a);
    }
  }
  function updateEnvironment(list, joins) {
    M.dispose(environment);
    environment.clear();
    const previous = district;
    district = window.AirportLandside?.build(list) || null;
    if (district && district !== previous) scene.add(district.group);
    drawMarkings(environment, joins?.curves || []);
    const porches = [];
    for (const e of list) if (e.kind === 'entrance' && e.door?.door) drawPorch(environment, e, list, porches);
    // The landside covers the ground behind the terminal; keep the treeline out of it.
    const taken = district?.rect;
    const inside = (r, x, z) => x >= r.minX - 12 && x <= r.maxX + 12 && z >= r.minZ - 12 && z <= r.maxZ + 12;
    const clear = (x, z) => !(taken && inside(taken, x, z)) && !porches.some(r => inside(r, x, z));
    const plant = (x, z, size, kind) => { if (clear(x, z)) M.tree(environment, x, z, size, kind); };
    const b = bounds(true);
    if (b.isEmpty()) return;
    let i = 0;
    for (let x = b.min.x - 60; x < b.max.x + 60; x += 22 + (i % 5) * 3, i++) {
      plant(x, b.min.z - 40 - (i % 3) * 9, 1 + (i % 4) * .15, i);
      plant(x + 7, b.max.z + 40 + (i % 3) * 9, 1 + ((i + 2) % 4) * .15, i + 1);
    }
    for (let z = b.min.z - 30; z < b.max.z + 30; z += 26 + (i % 4) * 4, i++) {
      plant(b.min.x - 50 - (i % 3) * 8, z, 1.1, i);
      plant(b.max.x + 50 + (i % 3) * 8, z + 9, 1.1, i + 2);
    }
    M.bake(environment);
  }
  function syncFacilities(list) {
    let changed = false;
    const ids = new Set(list.map(f => f.id));
    for (const [id, old] of facilities) if (!ids.has(id)) { scene.remove(old.mesh); M.dispose(old.mesh); facilities.delete(id); changed = true; }
    const joins = pavementJoins(list);
    for (const f of list) {
      const context = contextFor(f, list, joins);
      const signature = JSON.stringify([{...f, protected: undefined, connected: undefined, upgradeCost: undefined}, context]);
      const old = facilities.get(f.id);
      if (old?.signature === signature) { old.data = f; continue; }
      if (old) { scene.remove(old.mesh); M.dispose(old.mesh); }
      const mesh = M.facility(f, f.kind === 'baggageCarousel' ? {...context, live: true} : context);
      scene.add(mesh);
      facilities.set(f.id, {mesh, data: f, signature, context});
      changed = true;
    }
    if (changed) { roofMode(); updateEnvironment(list, joins); if (selected) select(selected); }
  }

  // ── Moving things ─────────────────────────────────────────────────────
  function pathPoint(path, fraction) {
    if (!path?.length) return null;
    let total = 0;
    for (let i = 1; i < path.length; i++) total += Math.hypot(path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1]);
    let remaining = total * Math.min(1, Math.max(0, fraction));
    for (let i = 1; i < path.length; i++) {
      const a = path[i - 1], b = path[i], dx = b[0] - a[0], dy = b[1] - a[1], length = Math.hypot(dx, dy);
      if (remaining <= length || i === path.length - 1) {
        const t = length ? Math.min(1, remaining / length) : 1;
        return {x: a[0] + dx * t, y: a[1] + dy * t, z: (a[2] || 0) + ((b[2] || 0) - (a[2] || 0)) * t, heading: length ? Math.atan2(-dx, -dy) : null};
      }
      remaining -= length;
    }
    const last = path[path.length - 1];
    return {x: last[0], y: last[1], z: last[2] || 0, heading: null};
  }
  const parkedStages = new Set(['unloading', 'servicing', 'boarding', 'awaitingAirport']);
  const standLocal = new T.Vector3();
  function standSpot(standId, local) {
    const stand = facilities.get(standId);
    if (!stand) return null;
    const f = stand.data, turn = ((Math.round(f.rotation || 0) % 4) + 4) % 4;
    const w = turn % 2 ? f.depth : f.width, d = turn % 2 ? f.width : f.depth;
    const side = stand.context?.noseSide || 0, frame = M.noseFrame(side, w, d);
    const [lx, lz] = local(frame.W, frame.D), cos = Math.cos(frame.angle), sin = Math.sin(frame.angle);
    standLocal.set(lx * cos + lz * sin + frame.offset[0], 0, -lx * sin + lz * cos + frame.offset[1]);
    stand.mesh.updateMatrixWorld();
    const p = standLocal.applyMatrix4(stand.mesh.matrixWorld);
    return {x: p.x, y: p.z, heading: turn * Math.PI / 2 + frame.angle - Math.PI / 2, w: frame.W, d: frame.D};
  }
  function flightPose(f, now) {
    if (f.path?.length && f.nextEvent > f.stageStart) {
      const p = pathPoint(f.path, (now - f.stageStart) / (f.nextEvent - f.stageStart));
      if (p && f.stage === 'pushback' && p.heading != null) p.heading += Math.PI;
      if (p) return p;
    }
    if (parkedStages.has(f.stage) && standKinds.has(facilities.get(f.standId)?.data.kind)) {
      const length = M.spec(f.modelId).length, regional = facilities.get(f.standId).data.kind === 'standRegional';
      const spot = standSpot(f.standId, (w, d) => [w - (regional ? 9 : 14) + 1.5 - length / 2, d / 2]);
      if (spot) return {x: spot.x, y: spot.y, z: 0, heading: spot.heading};
    }
    return {x: f.x || 0, y: f.y || 0, z: f.z || 0, heading: f.heading || 0};
  }
  const serviceSpots = {
    fuel: (w, d) => [w * .45, d / 2 + 13],
    baggage: (w, d) => [w * .3, d / 2 - 8],
    bus: (w, d) => [w * .55, d / 2 - 15],
    pushback: (w, d) => [w - 7, d / 2],
  };
  function vehiclePose(v, now) {
    let p = null;
    if (v.path?.length && v.busyUntil > v.started) p = pathPoint(v.path, (now - v.started) / (v.busyUntil - v.started));
    p = p || {x: v.x || 0, y: v.y || 0, heading: v.heading || 0};
    if (v.flightId && !v.returning) {
      const flight = (world?.flights || []).find(f => f.id === v.flightId);
      const stand = flight && facilities.get(flight.standId);
      if (stand && Math.hypot(p.x - (stand.data.x + stand.data.width / 2), p.y - (stand.data.y + stand.data.depth / 2)) < 6) {
        const spot = standSpot(flight.standId, serviceSpots[v.kind] || serviceSpots.bus);
        if (spot) return {x: spot.x, y: spot.y, heading: spot.heading + (v.kind === 'pushback' ? Math.PI : 0)};
      }
    }
    return p;
  }
  function track(id, make, pose) {
    let item = entities.get(id);
    if (!item) {
      item = {mesh: make(), heading: pose.heading ?? 0, seen: 0};
      item.mesh.position.set(pose.x, pose.z || 0, pose.y);
      scene.add(item.mesh);
      entities.set(id, item);
    }
    item.seen = snapshotSerial;
    return item;
  }
  let snapshotSerial = 0;
  function syncEntities(next) {
    snapshotSerial++;
    const now = gameTime();
    for (const flight of [...(next.flights || []), ...(next.idleAircraft || [])]) {
      if (['scheduled', 'completed', 'cancelled', 'enRoute'].includes(flight.stage)) continue;
      if (['awaitingStand', 'awaitingAirport'].includes(flight.stage) && !flight.path?.length && !flight.x && !flight.y) continue;
      const item = track(`f:${flight.id}`, () => M.aircraft(flight.modelId, flight.carrier), flightPose(flight, now));
      item.data = flight; item.type = 'flight';
      if (item.stage !== flight.stage && flight.stage !== 'parked') {
        if (item.caption) { item.mesh.remove(item.caption); M.dispose(item.caption); }
        item.caption = M.caption(`${flight.carrier || 'Flight'} · ${L.friendly(flight.stage)}`);
        item.mesh.add(item.caption);
      }
      item.stage = flight.stage;
    }
    for (const v of next.vehicles || []) {
      const item = track(`v:${v.id}`, () => M.vehicle(v.kind), vehiclePose(v, now));
      item.data = v; item.type = 'vehicle';
    }
    for (const [id, item] of entities) if (item.seen !== snapshotSerial) { scene.remove(item.mesh); M.dispose(item.mesh); entities.delete(id); }
    crowd.groups = L.crowdAllocation(next.passengers || [], quality);
  }

  // Passengers: two instanced meshes (clothes and heads) for everyone on screen.
  const crowd = {groups: [], capacity: 0, body: null, head: null};
  const shirts = [0xe3ad57, 0x36818c, 0xebe4d4, 0x925e6c, 0x3f6fb5, 0xd65a4a, 0x6aa84f, 0x2e2e3a, 0xf2f2f2, 0xb58ad6].map(c => new T.Color(c));
  const skins = [0xf1c9a5, 0xe0ac7e, 0xc68b5e, 0x8d5a3b, 0x5c3a24, 0xf6d7bd].map(c => new T.Color(c));
  function buildCrowd() {
    const capacity = L.crowdBudget(quality);
    if (crowd.capacity === capacity) return;
    for (const m of [crowd.body, crowd.head]) if (m) { scene.remove(m); m.dispose(); }
    const material = new T.MeshStandardMaterial({vertexColors: true, roughness: .8});
    crowd.body = new T.InstancedMesh(M.personGeometry('body'), material, capacity);
    crowd.head = new T.InstancedMesh(M.personGeometry('head'), material, capacity);
    for (let i = 0; i < capacity; i++) {
      crowd.body.setColorAt(i, shirts[(i * 7) % shirts.length]);
      crowd.head.setColorAt(i, skins[(i * 5) % skins.length]);
    }
    for (const m of [crowd.body, crowd.head]) { m.castShadow = quality === 'high'; m.frustumCulled = false; m.count = 0; scene.add(m); }
    crowd.capacity = capacity;
  }
  // Baggage reclaim: bags ride the belt once the flight's baggage is in, and
  // disappear one by one while the waiting group collects them.
  const reclaimStages = new Set(['reclaim', 'collecting']);
  const bags = {mesh: null, capacity: 240};
  const bagColors = [0x243542, 0x6e3b38, 0x4d5d43, 0xc5b39a, 0x5c6570, 0x8a6a9c, 0xc9a14a, 0xd9d3c4, 0x2f6fb0, 0xb0413e].map(c => new T.Color(c));
  const bagMatrix = new T.Matrix4(), bagQuat = new T.Quaternion(), bagPos = new T.Vector3(), bagScale = new T.Vector3();
  function buildBags() {
    bags.mesh = new T.InstancedMesh(new T.BoxGeometry(1, 1, 1), new T.MeshStandardMaterial({vertexColors: false, roughness: .7}), bags.capacity);
    for (let i = 0; i < bags.capacity; i++) bags.mesh.setColorAt(i, bagColors[(i * 7) % bagColors.length]);
    bags.mesh.frustumCulled = false;
    bags.mesh.count = 0;
    bags.mesh.castShadow = true;
    scene.add(bags.mesh);
  }
  function bagsWaiting(group, now) {
    if (group.stage === 'collecting') {
      const span = Math.max(.001, group.nextEvent - group.started);
      return Math.ceil((group.count || 0) * (1 - Math.min(1, Math.max(0, (now - group.started) / span))));
    }
    const flight = (world?.flights || []).find(f => f.id === group.flightId);
    return !flight || flight.stage === 'completed' || (flight.serviced || []).includes('baggage') ? group.count || 0 : 0;
  }
  function updateBags(now, realNow) {
    if (!bags.mesh) return;
    const perCarousel = new Map();
    for (const g of world?.passengers || []) {
      if (!g.arriving || !reclaimStages.has(g.stage) || !g.facilityId) continue;
      perCarousel.set(g.facilityId, (perCarousel.get(g.facilityId) || 0) + bagsWaiting(g, now));
    }
    let n = 0;
    for (const [id, waiting] of perCarousel) {
      const f = facilities.get(id)?.data;
      if (!f || !waiting) continue;
      const {w, d, matrix} = M.facilityFrame(f, .3), loop = M.carouselLoop(w, d);
      const shown = Math.min(waiting, Math.floor(loop.length / .8));
      const offset = realNow / 1000 * .55;
      for (let i = 0; i < shown && n < bags.capacity; i++, n++) {
        const p = M.loopPoint(loop, offset + i * loop.length / shown);
        const tall = i % 3 === 1, width = .34 + ((i * 5) % 4) * .08;
        bagScale.set(width, tall ? .5 : .24, tall ? .34 : .42);
        bagPos.set(p.x, .55 + bagScale.y / 2, p.z);
        bagQuat.setFromAxisAngle(up, p.dir + ((i * 3) % 5 - 2) * .08);
        bagMatrix.compose(bagPos, bagQuat, bagScale).premultiply(matrix);
        bags.mesh.setMatrixAt(n, bagMatrix);
      }
    }
    bags.mesh.count = n;
    bags.mesh.instanceMatrix.needsUpdate = true;
  }
  /** Where person [i] of a reclaim group stands: around the carousel, facing it. */
  const reclaimSpot = new T.Vector3(), reclaimLook = new T.Vector3();
  function reclaimPlace(g, i, seedBase) {
    const f = facilities.get(g.facilityId)?.data;
    if (!f) return null;
    const {w, d, matrix} = M.facilityFrame(f, .3), loop = M.carouselLoop(w, d);
    const ring = loop.outer + .45, length = 4 * loop.span + 2 * Math.PI * ring;
    const s = ((seedBase * 2.61 + i * 1.37) % length + length) % length;
    const p = M.loopPoint(loop, s, ring), inner = M.loopPoint(loop, s, loop.radius);
    reclaimSpot.set(p.x, 0, p.z).applyMatrix4(matrix);
    reclaimLook.set(inner.x, 0, inner.z).applyMatrix4(matrix);
    return {x: reclaimSpot.x, y: reclaimSpot.z, heading: Math.atan2(-(reclaimLook.x - reclaimSpot.x), -(reclaimLook.z - reclaimSpot.z))};
  }
  const personMatrix = new T.Matrix4(), personQuat = new T.Quaternion(), personPos = new T.Vector3(), personScale = new T.Vector3(1, 1, 1), up = new T.Vector3(0, 1, 0);
  function updateCrowd(now, realNow) {
    if (!crowd.body) return;
    let n = 0;
    for (const {group: g, visible} of crowd.groups) {
      // Still inside the aircraft: they appear at the door when it is their turn.
      if (g.stage === 'deplaning' && now < g.started) continue;
      let p = null, moving = false;
      if (g.path?.length && g.nextEvent > g.started && now < g.nextEvent) {
        const travel = Math.max(.001, g.nextEvent - g.started);
        p = pathPoint(g.path, (now - g.started) / travel);
        moving = p && now < g.nextEvent;
      }
      p = p || {x: g.x || 0, y: g.y || 0, heading: 0};
      const heading = p.heading ?? 0;
      personQuat.setFromAxisAngle(up, heading + Math.PI);
      const seedBase = Number(String(g.id).replace(/\D/g, '')) || 0;
      const atCarousel = g.arriving && reclaimStages.has(g.stage);
      for (let i = 0; i < visible && n < crowd.capacity; i++, n++) {
        const spot = atCarousel ? reclaimPlace(g, i, seedBase) : null;
        if (spot) {
          personQuat.setFromAxisAngle(up, spot.heading + Math.PI);
          personPos.set(spot.x, .3, spot.y);
          personMatrix.compose(personPos, personQuat, personScale);
          crowd.body.setMatrixAt(n, personMatrix);
          crowd.head.setMatrixAt(n, personMatrix);
          continue;
        }
        personQuat.setFromAxisAngle(up, heading + Math.PI);
        const r = .45 * Math.sqrt(i + .5), a = i * 2.39996 + seedBase;
        const bob = moving ? Math.abs(Math.sin(realNow / 170 + i)) * .06 : 0;
        personPos.set(p.x + Math.cos(a) * r, .3 + bob, p.y + Math.sin(a) * r);
        personMatrix.compose(personPos, personQuat, personScale);
        crowd.body.setMatrixAt(n, personMatrix);
        crowd.head.setMatrixAt(n, personMatrix);
      }
    }
    crowd.body.count = crowd.head.count = n;
    crowd.body.instanceMatrix.needsUpdate = crowd.head.instanceMatrix.needsUpdate = true;
  }

  // ── Snapshots and messages ────────────────────────────────────────────
  let lastSnapshot = 0;
  const perf = {frames: 0, cpu: 0, snapshots: 0, snapshotMs: 0, since: performance.now()};
  function snapshot(next) {
    const began = performance.now();
    lastSnapshot = began;
    const first = world === null;
    world = next;
    receivedAt = began;
    syncFacilities(next.facilities || []);
    syncEntities(next);
    if (first) frame();
    $('loading').classList.add('hidden');
    perf.snapshots++;
    perf.snapshotMs += performance.now() - began;
    window.AirportHud?.update(next);
  }
  function setTool(message) {
    tool = message.kind ? message : null;
    if (ghost) { scene.remove(ghost); M.dispose(ghost); ghost = null; ghostKey = ''; }
    outline.visible = false;
    const interior = tool && interiorKinds().has(tool.kind);
    grid.visible = (!!tool && !interior) || gridWanted;
    fineGrid.visible = !!interior;
    status.textContent = tool ? 'Click to place · Drag to move · Right-drag to orbit' : '';
  }
  function select(id) {
    const item = facilities.get(id);
    selected = item ? id : null;
    if (!item) { outline.visible = false; return; }
    outline.setFromObject(item.mesh);
    outline.visible = true;
  }
  function focus(id, interior = false) {
    const item = facilities.get(id);
    if (!item) return;
    target.set(item.data.x + item.data.width / 2, 0, item.data.y + item.data.depth / 2);
    distance = Math.max(interior ? 70 : 100, Math.max(item.data.width, item.data.depth) * (interior ? 1.25 : 2));
    if (interior) { polar = .62; cutaway = true; roofMode(); fineGrid.position.set(Math.round(target.x), .36, Math.round(target.z)); }
    cameraUpdate();
  }
  function receive(message) {
    try {
      const m = typeof message === 'string' ? JSON.parse(message) : message;
      if (m.type === 'snapshot') snapshot(m.world);
      else if (m.type === 'result') window.AirportHud?.result(m);
      else if (m.type === 'theme') window.AirportHud?.theme(m.palette);
      else if (m.type === 'tool') setTool(m);
      else if (m.type === 'view') {
        switch (m.action) {
          case 'fit': frame(true); break;
          case 'reset': frame(); break;
          case 'cutaway': cutaway = m.value === undefined ? !cutaway : !!m.value; roofMode(); break;
          case 'grid': gridWanted = m.value === undefined ? !gridWanted : !!m.value; grid.visible = gridWanted || (!!tool && !fineGrid.visible); break;
          case 'visible': active = !!m.value; break;
          case 'stats': statsBox.classList.toggle('hidden', !m.value); break;
          case 'select': select(m.id); break;
          case 'interior': focus(m.id, true); break;
          case 'quality': {
            quality = m.value === 'low' ? 'low' : 'high';
            const low = quality === 'low';
            renderer.setPixelRatio(Math.min(devicePixelRatio, low ? 1 : 1.75));
            renderer.shadowMap.enabled = !low;
            sun.shadow.mapSize.set(low ? 1024 : 2048, low ? 1024 : 2048);
            sun.shadow.map?.dispose(); sun.shadow.map = null;
            scene.traverse(o => { if (o.material) o.material.needsUpdate = true; });
            buildCrowd();
  buildBags();
            if (world) crowd.groups = L.crowdAllocation(world.passengers || [], quality);
            break;
          }
          case 'focus': focus(m.id); break;
        }
      }
    } catch (e) {
      send({type: 'error', message: `Scene message failed: ${e.message}`});
    }
  }
  window.airportReceive = receive;
  window.chrome?.webview?.addEventListener('message', e => receive(e.data));

  // ── Build previews ────────────────────────────────────────────────────
  const thumbQueue = [], thumbCache = new Map();
  const thumbScene = new T.Scene();
  thumbScene.add(new T.HemisphereLight(0xeaf5ff, 0x8a8f78, 1.9));
  const thumbSun = new T.DirectionalLight(0xfff0d8, 2.6);
  thumbSun.position.set(-4, 8, 5);
  thumbScene.add(thumbSun);
  const thumbCamera = new T.PerspectiveCamera(30, 1.6, .1, 5000);
  /** A picture of [def] for the Build cards, or larger for the management window. */
  function thumbnail(def, size = {width: 240, height: 150}) {
    const key = `${def.kind}|${def.width}x${def.depth}|${size.width}x${size.height}`;
    if (thumbCache.has(key)) return Promise.resolve(thumbCache.get(key));
    return new Promise(resolve => thumbQueue.push({def, key, resolve, size}));
  }
  function renderThumbnail({def, key, resolve, size: shot}) {
    const {width, height} = shot;
    let w = def.width, d = def.depth;
    const facility = {id: 'preview-01', kind: def.kind, x: 0, y: 0, width: w, depth: d, rotation: 0};
    if (def.kind.startsWith('runway')) { facility.depth = Math.min(d, 260); d = facility.depth; }
    if (def.kind === 'taxiway' || def.kind === 'serviceRoad') { facility.depth = 60; d = 60; }
    const mesh = M.facility(facility, {});
    const stage = new T.Group();
    stage.add(mesh);
    if (standKinds.has(def.kind)) {
      const plane = M.aircraft(def.kind === 'standRegional' ? 'atr72' : 'a320neo', 'Luma');
      const length = M.spec(def.kind === 'standRegional' ? 'atr72' : 'a320neo').length;
      plane.position.set(w - (def.kind === 'standRegional' ? 9 : 14) + 1.5 - length / 2, 0, d / 2);
      plane.rotation.y = -Math.PI / 2;
      stage.add(plane);
    }
    thumbScene.add(stage);
    const size = Math.max(w, d, def.height * 2);
    thumbCamera.position.set(w / 2 + size * .95, size * .9 + def.height, d / 2 + size * 1.2);
    thumbCamera.lookAt(w / 2, def.height * .3, d / 2);
    thumbScene.environment = scene.environment;
    thumbScene.background = new T.Color(0xd9e6e2);
    const pixelRatio = renderer.getPixelRatio();
    renderer.setScissorTest(true);
    renderer.setViewport(0, 0, width / pixelRatio, height / pixelRatio);
    renderer.setScissor(0, 0, width / pixelRatio, height / pixelRatio);
    const shadows = renderer.shadowMap.enabled;
    const canvas = document.createElement('canvas');
    canvas.width = width; canvas.height = height;
    try {
      renderer.shadowMap.enabled = false;
      M.setNight(0);
      renderer.render(thumbScene, thumbCamera);
      canvas.getContext('2d').drawImage(renderer.domElement, 0, renderer.domElement.height - height, width, height, 0, 0, width, height);
    } finally {
      renderer.shadowMap.enabled = shadows;
      renderer.setScissorTest(false);
      renderer.setViewport(0, 0, innerWidth, innerHeight);
      lastNight = -1;
      thumbScene.remove(stage);
      M.dispose(stage);
    }
    const url = canvas.toDataURL('image/webp', .85);
    thumbCache.set(key, url);
    resolve(url);
  }

  // ── Input ─────────────────────────────────────────────────────────────
  const raycaster = new T.Raycaster(), mouse = new T.Vector2(), plane = new T.Plane(new T.Vector3(0, 1, 0), 0), point = new T.Vector3();
  let location = null;
  function ray(x, y) {
    const r = renderer.domElement.getBoundingClientRect();
    mouse.set((x - r.left) / r.width * 2 - 1, -(y - r.top) / r.height * 2 + 1);
    raycaster.setFromCamera(mouse, camera);
    return raycaster;
  }
  function hover(x, y) {
    if (!tool) return;
    ray(x, y);
    if (!raycaster.ray.intersectPlane(plane, point)) return;
    const interior = interiorKinds().has(tool.kind);
    const snap = interior ? 1 : 5;
    const [w, d] = L.footprint(world, tool, [10, 10]);
    location = {x: Math.round((point.x - w / 2) / snap) * snap, y: Math.round((point.z - d / 2) / snap) * snap, w, d};
    const rotation = ((Math.round(tool.rotation || 0) % 4) + 4) % 4;
    const key = `${tool.kind}|${rotation}|${w}|${d}`;
    if (key !== ghostKey) {
      if (ghost) { scene.remove(ghost); M.dispose(ghost); }
      ghost = M.facility({id: 'ghost', kind: tool.kind, x: 0, y: 0, width: w, depth: d, rotation}, {});
      ghost.traverse(o => {
        if (!o.isMesh) return;
        if (o.userData.owned) { o.material.map?.dispose(); o.material.dispose(); o.userData.owned = false; o.userData.ownGeometry = true; }
        o.castShadow = false;
        o.renderOrder = 5;
      });
      ghost.userData.offset = ghost.position.clone();
      scene.add(ghost);
      ghostKey = key;
    }
    ghost.position.set(ghost.userData.offset.x + location.x, interior ? .05 : .02, ghost.userData.offset.z + location.y);
    const check = L.validate(world || {}, tool, location);
    const material = check.valid ? ghostOk : ghostBad;
    ghost.traverse(o => { if (o.isMesh) o.material = material; });
    const euros = n => new Intl.NumberFormat('en', {style: 'currency', currency: 'EUR', maximumFractionDigits: 0}).format(n);
    status.textContent = `${check.cost === undefined ? '' : `${euros(check.cost)} · `}Cash ${euros(world?.cash || 0)} · ${check.reason || 'Click to confirm'}`;
  }
  function click(x, y) {
    if (tool) { hover(x, y); if (location) window.AirportHud?.place(location); return; }
    const hits = ray(x, y).intersectObjects([...facilities.values()].map(v => v.mesh), true);
    if (!hits.length) { outline.visible = false; selected = null; window.AirportHud?.select(null); return; }
    let mesh = hits[0].object;
    while (mesh && !mesh.userData.facilityId) mesh = mesh.parent;
    if (mesh) { select(mesh.userData.facilityId); window.AirportHud?.select(selected); }
  }
  const pointers = new Map();
  let gesture = null;
  const canvas = renderer.domElement;
  // Map-style controls: left-drag pans the ground, right/middle (or
  // Shift/Ctrl+left) orbits. Touch: one finger pans, two fingers
  // pinch to zoom, drag the midpoint to pan and twist to orbit.
  function touchPoints() { return [...pointers.values()]; }
  function touchDistance() { const p = touchPoints(); return Math.hypot(p[0].x - p[1].x, p[0].y - p[1].y); }
  function touchMid() { const p = touchPoints(); return {x: (p[0].x + p[1].x) / 2, y: (p[0].y + p[1].y) / 2}; }
  function touchAngle() { const p = touchPoints(); return Math.atan2(p[1].y - p[0].y, p[1].x - p[0].x); }
  function isOrbitButton(e) {
    if (e.pointerType !== 'mouse') return false;
    return e.button === 1 || e.button === 2 || e.shiftKey || e.ctrlKey || e.metaKey;
  }
  function orbitBy(dx, dy) {
    azimuth -= dx * .0055;
    polar = Math.max(.12, Math.min(1.42, polar - dy * .0038));
  }
  canvas.addEventListener('pointerdown', e => {
    try { canvas.setPointerCapture(e.pointerId); } catch (_) { /* pointer already gone */ }
    pointers.set(e.pointerId, {x: e.clientX, y: e.clientY});
    if (pointers.size === 2) {
      const mid = touchMid();
      gesture = {x: mid.x, y: mid.y, moved: gesture?.moved || false, orbit: false, pinch: touchDistance(), twist: touchAngle(), mid};
    } else {
      gesture = {x: e.clientX, y: e.clientY, moved: false, orbit: isOrbitButton(e), pinch: null, twist: null, mid: null};
    }
  });
  canvas.addEventListener('pointermove', e => {
    if (!pointers.has(e.pointerId) || !gesture) { hover(e.clientX, e.clientY); return; }
    const old = pointers.get(e.pointerId), dx = e.clientX - old.x, dy = e.clientY - old.y;
    pointers.set(e.pointerId, {x: e.clientX, y: e.clientY});
    if (Math.hypot(e.clientX - gesture.x, e.clientY - gesture.y) > 5) gesture.moved = true;
    if (pointers.size === 2) {
      const nextDist = touchDistance(), nextAngle = touchAngle(), nextMid = touchMid();
      if (gesture.pinch && nextDist > 0) distance = Math.max(25, Math.min(7000, distance * gesture.pinch / nextDist));
      if (gesture.twist != null) {
        let turn = nextAngle - gesture.twist;
        turn -= Math.round(turn / (2 * Math.PI)) * 2 * Math.PI;
        azimuth -= turn;
      }
      if (gesture.mid) pan(nextMid.x - gesture.mid.x, nextMid.y - gesture.mid.y);
      gesture.pinch = nextDist;
      gesture.twist = nextAngle;
      gesture.mid = nextMid;
      gesture.moved = true;
    } else if (gesture.orbit) orbitBy(dx, dy);
    else pan(dx, dy);
    cameraUpdate();
    hover(e.clientX, e.clientY);
  });
  function pan(dx, dy) {
    const scale = distance * .0014;
    // Grab the ground: it follows the pointer on both axes.
    target.x += (-dx * Math.cos(azimuth) - dy * Math.sin(azimuth)) * scale;
    target.z += (dx * Math.sin(azimuth) - dy * Math.cos(azimuth)) * scale;
  }
  canvas.addEventListener('pointerup', e => {
    const shouldClick = gesture && !gesture.moved && pointers.size === 1 && e.button === 0;
    pointers.delete(e.pointerId);
    if (shouldClick) click(e.clientX, e.clientY);
    if (!pointers.size) {
      gesture = null;
    } else if (gesture) {
      const remaining = touchPoints()[0];
      gesture = {x: gesture.x, y: gesture.y, moved: true, orbit: false, pinch: null, twist: null, mid: null};
      if (remaining) pointers.set([...pointers.keys()][0], {x: remaining.x, y: remaining.y});
    }
  });
  canvas.addEventListener('pointercancel', e => {
    pointers.delete(e.pointerId);
    gesture = pointers.size ? {x: e.clientX, y: e.clientY, moved: true, orbit: false, pinch: null, twist: null, mid: null} : null;
  });
  canvas.addEventListener('contextmenu', e => e.preventDefault());
  canvas.addEventListener('wheel', e => {
    e.preventDefault();
    distance = Math.max(25, Math.min(7000, distance * Math.exp(e.deltaY * .001)));
    cameraUpdate();
  }, {passive: false});
  const held = new Set();
  addEventListener('keydown', e => {
    if (e.target.closest?.('select,input,textarea')) return;
    const k = e.key.toLowerCase();
    if (['w', 'a', 's', 'd', 'q', 'e', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright', '+', '=', '-'].includes(k)) { held.add(k); e.preventDefault(); }
  });
  addEventListener('keyup', e => held.delete(e.key.toLowerCase()));
  addEventListener('blur', () => held.clear());
  function keyboard(dt) {
    if (!held.size) return;
    const step = dt * 60;
    if (held.has('w') || held.has('arrowup')) pan(0, 9 * step);
    if (held.has('s') || held.has('arrowdown')) pan(0, -9 * step);
    if (held.has('a') || held.has('arrowleft')) pan(9 * step, 0);
    if (held.has('d') || held.has('arrowright')) pan(-9 * step, 0);
    if (held.has('q')) azimuth += .025 * step;
    if (held.has('e')) azimuth -= .025 * step;
    if (held.has('+') || held.has('=')) distance = Math.max(25, distance * (1 - .02 * step));
    if (held.has('-')) distance = Math.min(7000, distance * (1 + .02 * step));
    cameraUpdate();
  }

  addEventListener('resize', () => {
    if (!innerWidth || !innerHeight) return;
    camera.aspect = aspect();
    camera.updateProjectionMatrix();
    renderer.setSize(innerWidth, innerHeight);
  });
  document.addEventListener('visibilitychange', () => { if (document.hidden) held.clear(); });
  canvas.addEventListener('webglcontextlost', e => { e.preventDefault(); fail('The graphics context was lost.'); });
  canvas.addEventListener('webglcontextrestored', () => window.location.reload());

  // ── Frame loop ────────────────────────────────────────────────────────
  const smoothing = new T.Vector3();
  let previousFrame = 0;
  function step(now) {
    const dt = Math.min(.1, previousFrame ? (now - previousFrame) / 1000 : 1 / 60);
    previousFrame = now;
    const began = performance.now();
    if (thumbQueue.length) {
      const job = thumbQueue.shift();
      try {
        if (renderer.domElement.width < job.size.width || renderer.domElement.height < job.size.height) throw new Error('canvas too small');
        renderThumbnail(job);
      } catch (_) {
        renderer.setScissorTest(false);
        renderer.setViewport(0, 0, innerWidth, innerHeight);
        job.tries = (job.tries || 0) + 1;
        if (job.tries < 30) thumbQueue.push(job); else job.resolve('');
      }
    }
    keyboard(dt);
    const time = gameTime();
    daylight(time);
    const blend = 1 - Math.exp(-dt / .09);
    for (const item of entities.values()) {
      const pose = item.type === 'vehicle' ? vehiclePose(item.data, time) : flightPose(item.data, time);
      smoothing.set(pose.x, pose.z || 0, pose.y);
      if (item.mesh.position.distanceToSquared(smoothing) > 40000) item.mesh.position.copy(smoothing);
      else item.mesh.position.lerp(smoothing, blend);
      if (pose.heading != null) {
        let turn = pose.heading - item.heading;
        turn -= Math.round(turn / (2 * Math.PI)) * 2 * Math.PI;
        item.heading += turn * Math.min(1, blend * 1.6);
      }
      item.mesh.rotation.y = item.heading;
      if (item.caption) item.caption.visible = distance < 1400;
    }
    updateCrowd(time, now);
    updateBags(time, now);
    if (district) {
      // Landside traffic follows the airport's own load: waiting groups and
      // turnarounds in progress both put cars and buses on the access road.
      const turnarounds = (world?.flights || []).filter(f => !['scheduled', 'completed', 'cancelled', 'enRoute'].includes(f.stage)).length;
      const activity = Math.min(1, (world?.passengers?.length || 0) / 14 + turnarounds / 8);
      district.update(dt, {activity, night: darkness, paused: !!world?.paused, speed: world?.speed || 1});
    }
    sky.position.copy(camera.position);
    renderer.render(scene, camera);
    started = true;
    perf.cpu += performance.now() - began;
    perf.frames++;
    if (now - perf.since >= 1000) showStats(now);
  }
  function render(now) {
    requestAnimationFrame(render);
    if (!active || document.hidden) { previousFrame = 0; return; }
    if (previousFrame && now - previousFrame < 1000 / 60 - 4) return;
    step(now);
  }
  function showStats(now) {
    if (!statsBox.classList.contains('hidden')) {
      const s = (now - perf.since) / 1000, i = renderer.info.render;
      statsBox.textContent = `${(perf.frames / s).toFixed(0)} fps · ${(perf.cpu / Math.max(1, perf.frames)).toFixed(2)} ms/frame\n${i.calls} draw calls · ${(i.triangles / 1000).toFixed(0)}k tris\n${(perf.snapshots / s).toFixed(1)} updates/s · ${(perf.snapshotMs / Math.max(1, perf.snapshots)).toFixed(2)} ms each\n${entities.size} vehicles/aircraft · ${crowd.body?.count ?? 0} people\n${renderer.domElement.width}×${renderer.domElement.height}px`;
    }
    Object.assign(perf, {frames: 0, cpu: 0, snapshots: 0, snapshotMs: 0, since: now});
  }

  buildCrowd();
  cameraUpdate();
  window.AirportHud?.attach({
    send,
    view: (action, value, id) => receive({type: 'view', action, value, id}),
    tool: t => receive({type: 'tool', ...t}),
    thumbnail,
  });
  function announce() { if (ready) return; send({type: 'ready'}); ready = true; }
  addEventListener('flutterInAppWebViewPlatformReady', announce);
  announce();
  requestAnimationFrame(render);
  addEventListener('pagehide', () => {
    active = false;
    for (const {mesh} of facilities.values()) M.dispose(mesh);
    for (const {mesh} of entities.values()) M.dispose(mesh);
    renderer.dispose();
  });
  if (new URLSearchParams(window.location.search).get('preview') === '1' && window.airportPreview) {
    $('preview').style.display = 'block';
    receive({type: 'snapshot', world: window.airportPreview.world});
    // The preview page can be driven without a visible tab for checks.
    window.airportDebug = {
      frame: () => step(performance.now()),
      camera: (x, z, d, az, pol) => { target.set(x, 0, z); distance = d; azimuth = az; polar = pol; cameraUpdate(); },
      time: minutes => { world.time = minutes; receivedAt = performance.now(); },
      get state() { return {scene, camera, renderer, target, distance, facilities, entities, world, district}; },
    };
  }
})();
