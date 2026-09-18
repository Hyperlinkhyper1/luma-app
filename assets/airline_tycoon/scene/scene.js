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
  const daySky = new T.Color(0xaed3e6), duskSky = new T.Color(0xe7a47a), nightSky = new T.Color(0x0b1322);
  scene.background = daySky.clone();
  scene.fog = new T.Fog(daySky, 2200, 7000);
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
  const ground = new T.Mesh(new T.PlaneGeometry(18000, 18000), new T.MeshStandardMaterial({map: groundTexture, roughness: 1, color: 0xd8e6cf}));
  ground.rotation.x = -Math.PI / 2;
  ground.position.y = -.05;
  ground.receiveShadow = true;
  const groundTint = ground.material.color.clone();
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
  const interiorKinds = () => new Set((world?.catalog || []).filter(d => d.interior).map(d => d.kind).concat(['entrance', 'checkIn', 'checkInCounter', 'infoDesk', 'bins', 'ticketMachine', 'security', 'seating', 'toilets', 'cafe', 'restaurant', 'vendingMachine', 'boardingGate', 'shop', 'kiosk', 'foodShop', 'perfumeShop', 'clothingShop', 'luxuryBoutique', 'lounge', 'vipLounge', 'plant', 'fountain', 'infoBoard', 'baggageCarousel']));
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
  let lastNight = -1, darkness = 0;
  function daylight(time) {
    const hour = ((time % 1440) + 1440) % 1440 / 60;
    const angle = (hour - 6) / 14 * Math.PI;
    const elevation = Math.sin(Math.min(Math.PI, Math.max(0, angle)));
    const day = hour > 5.5 && hour < 20.5 ? Math.min(1, Math.max(0, Math.min(hour - 5.5, 20.5 - hour) / 1.5)) : 0;
    const night = 1 - day;
    const dir = new T.Vector3(-Math.cos(angle) * 600, 150 + elevation * 800, -420);
    sun.position.copy(target).add(dir);
    sun.target.position.copy(target);
    sun.intensity = 3.1 * day * (.35 + .65 * elevation);
    sun.color.setHSL(.09, .6, .78 + .17 * elevation);
    hemi.intensity = .16 + 1.49 * day;
    hemi.color.setHSL(.6, .55 - .2 * day, .45 + .4 * day);
    const sky = nightSky.clone().lerp(daySky, day);
    if (day > 0 && day < 1) sky.lerp(duskSky, .45 * (1 - Math.abs(day - .5) * 2));
    scene.background.copy(sky);
    scene.fog.color.copy(sky);
    renderer.toneMappingExposure = .78 + .37 * day;
    ground.material.color.copy(groundTint).multiplyScalar(.35 + .65 * day);
    sun.castShadow = day > 0;
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
  function contextFor(f, list) {
    const turn = ((Math.round(f.rotation || 0) % 4) + 4) % 4;
    if (f.kind === 'terminal') {
      const open = {};
      for (const t of list) if (t.kind === 'terminal' && t.id !== f.id) { const side = touchingSide(f, t); if (side) open[localSide(side, turn)] = true; }
      return {open};
    }
    if (standKinds.has(f.kind)) {
      // Aircraft park nose-in towards the terminal they serve.
      let worldSide = null, best = Infinity;
      for (const t of list) if (t.kind === 'terminal') {
        const touching = touchingSide(f, t);
        const dx = t.x + t.width / 2 - (f.x + f.width / 2), dz = t.y + t.depth / 2 - (f.y + f.depth / 2);
        const gapX = Math.max(0, Math.abs(dx) - (t.width + f.width) / 2), gapZ = Math.max(0, Math.abs(dz) - (t.depth + f.depth) / 2);
        const distance = touching ? -1 : Math.hypot(gapX, gapZ);
        if (distance < best) { best = distance; worldSide = touching || (gapX >= gapZ ? (dx > 0 ? '+x' : '-x') : (dz > 0 ? '+z' : '-z')); }
      }
      return {noseSide: worldSide ? ['+x', '+z', '-x', '-z'].indexOf(localSide(worldSide, turn)) : 0};
    }
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
  function updateEnvironment(list) {
    M.dispose(environment);
    environment.clear();
    const previous = district;
    district = window.AirportLandside?.build(list) || null;
    if (district && district !== previous) scene.add(district.group);
    // The landside covers the ground behind the terminal; keep the treeline out of it.
    const taken = district?.rect;
    const clear = (x, z) => !taken || x < taken.minX - 12 || x > taken.maxX + 12 || z < taken.minZ - 12 || z > taken.maxZ + 12;
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
    for (const f of list) {
      const context = contextFor(f, list);
      const signature = JSON.stringify([{...f, protected: undefined, connected: undefined}, context]);
      const old = facilities.get(f.id);
      if (old?.signature === signature) { old.data = f; continue; }
      if (old) { scene.remove(old.mesh); M.dispose(old.mesh); }
      const mesh = M.facility(f, f.kind === 'baggageCarousel' ? {...context, live: true} : context);
      scene.add(mesh);
      facilities.set(f.id, {mesh, data: f, signature, context});
      changed = true;
    }
    if (changed) { roofMode(); updateEnvironment(list); if (selected) select(selected); }
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
  function thumbnail(def) {
    const key = `${def.kind}`;
    if (thumbCache.has(key)) return Promise.resolve(thumbCache.get(key));
    return new Promise(resolve => thumbQueue.push({def, key, resolve}));
  }
  function renderThumbnail({def, key, resolve}) {
    const width = 240, height = 150;
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
        if (renderer.domElement.width < 240 || renderer.domElement.height < 150) throw new Error('canvas too small');
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
