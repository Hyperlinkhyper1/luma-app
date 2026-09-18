/* Original procedural airport models. Dimensions are metres; aircraft nose is -Z.
   Every model stays inside its facility footprint so placement previews and the
   simulation agree. Plain meshes are folded by bake() into a handful of merged
   meshes per material, so a whole building costs a few draw calls. */
window.AirportModels = (() => {
  'use strict';
  const T = THREE;
  const TAU = Math.PI * 2;

  // ── Textures ──────────────────────────────────────────────────────────
  function noiseTexture(size, paint) {
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = size;
    const c = canvas.getContext('2d');
    paint(c, size);
    const texture = new T.CanvasTexture(canvas);
    texture.wrapS = texture.wrapT = T.RepeatWrapping;
    texture.colorSpace = T.SRGBColorSpace;
    texture.anisotropy = 8;
    return texture;
  }
  let seed = 7;
  const rand = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  function speckle(c, size, base, spread, count, alpha) {
    c.fillStyle = base; c.fillRect(0, 0, size, size);
    for (let i = 0; i < count; i++) {
      const v = Math.floor((rand() - .5) * spread);
      c.fillStyle = `rgba(${v > 0 ? 255 : 0},${v > 0 ? 255 : 0},${v > 0 ? 255 : 0},${Math.abs(v) / 255 * alpha})`;
      const s = 1 + rand() * 2.5;
      c.fillRect(rand() * size, rand() * size, s, s);
    }
  }
  const textures = {
    concrete: [noiseTexture(256, (c, s) => {
      speckle(c, s, '#aeaaa2', 100, 6000, 1.5);
      c.strokeStyle = 'rgba(80,76,68,.35)'; c.lineWidth = 1.5;
      for (let i = 0; i <= s; i += s / 2) { c.beginPath(); c.moveTo(i, 0); c.lineTo(i, s); c.moveTo(0, i); c.lineTo(s, i); c.stroke(); }
      for (let i = 0; i < 26; i++) { c.fillStyle = `rgba(60,55,50,${.03 + rand() * .05})`; c.beginPath(); c.ellipse(rand() * s, rand() * s, 6 + rand() * 30, 3 + rand() * 12, rand() * 3, 0, TAU); c.fill(); }
    }), 10],
    asphalt: [noiseTexture(256, (c, s) => {
      speckle(c, s, '#50555a', 120, 9000, 1.2);
      for (let i = 0; i < 18; i++) { c.fillStyle = `rgba(20,22,25,${.05 + rand() * .06})`; c.beginPath(); c.ellipse(rand() * s, rand() * s, 10 + rand() * 40, 4 + rand() * 10, rand() * 3, 0, TAU); c.fill(); }
    }), 14],
    grass: [noiseTexture(256, (c, s) => {
      speckle(c, s, '#86a872', 110, 9000, 1);
      for (let i = 0; i < 40; i++) { c.fillStyle = `rgba(${rand() > .5 ? '60,95,50' : '170,190,120'},${.05 + rand() * .07})`; c.beginPath(); c.ellipse(rand() * s, rand() * s, 10 + rand() * 30, 8 + rand() * 20, rand() * 3, 0, TAU); c.fill(); }
    }), 24],
    tile: [noiseTexture(256, (c, s) => {
      speckle(c, s, '#cfcbc3', 50, 2500, .9);
      for (let x = 0; x < 4; x++) for (let y = 0; y < 4; y++) if ((x + y) % 2) { c.fillStyle = 'rgba(70,80,95,.16)'; c.fillRect(x * s / 4, y * s / 4, s / 4, s / 4); }
      c.strokeStyle = 'rgba(60,60,60,.45)'; c.lineWidth = 1.5;
      for (let i = 0; i <= s; i += s / 4) { c.beginPath(); c.moveTo(i, 0); c.lineTo(i, s); c.moveTo(0, i); c.lineTo(s, i); c.stroke(); }
    }), 6],
  };
  const glow = noiseTexture(128, (c, s) => {
    const g = c.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
    g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(.4, 'rgba(255,255,255,.45)'); g.addColorStop(1, 'rgba(255,255,255,0)');
    c.fillStyle = g; c.fillRect(0, 0, s, s);
  });
  glow.wrapS = glow.wrapT = T.ClampToEdgeWrapping;

  // ── Materials ─────────────────────────────────────────────────────────
  const standard = extra => new T.MeshStandardMaterial({vertexColors: true, ...extra});
  const materials = {
    paint: standard({roughness: .72}),
    metal: standard({roughness: .32, metalness: .55}),
    glass: standard({roughness: .06, metalness: .65, envMapIntensity: 1.6, emissive: new T.Color(0xffc977), emissiveIntensity: 0}),
    water: standard({roughness: .04, metalness: .2, envMapIntensity: 2}),
    concrete: standard({roughness: .95, map: textures.concrete[0]}),
    asphalt: standard({roughness: .9, map: textures.asphalt[0]}),
    grass: standard({roughness: 1, map: textures.grass[0]}),
    tile: standard({roughness: .45, map: textures.tile[0]}),
    light: new T.MeshBasicMaterial({vertexColors: true, toneMapped: false}),
    pool: new T.MeshBasicMaterial({vertexColors: true, map: glow, transparent: true, opacity: 0, depthWrite: false, blending: T.AdditiveBlending, toneMapped: false}),
  };
  const textured = {concrete: 10, asphalt: 14, grass: 24, tile: 6};
  const sources = new Map();
  for (const [kind, material] of Object.entries(materials)) {
    const byColor = new Map();
    sources.set(kind, color => {
      if (!byColor.has(color)) {
        const m = new T.MeshStandardMaterial({color});
        m.userData.kind = kind;
        byColor.set(color, m);
      }
      return byColor.get(color);
    });
    material.userData.baked = true;
  }
  const mat = (color, kind = 'paint') => sources.get(kind)(color);

  /** Environment reflections and the day/night look. */
  function init(renderer) {
    const sky = new T.Scene();
    const geo = new T.SphereGeometry(100, 32, 16);
    const colors = [];
    const top = new T.Color(0x6fa5d8), horizon = new T.Color(0xe8f1f2), ground = new T.Color(0x6e7a70);
    for (let i = 0; i < geo.attributes.position.count; i++) {
      const y = geo.attributes.position.getY(i) / 100;
      const c = y > 0 ? horizon.clone().lerp(top, Math.pow(y, .6)) : horizon.clone().lerp(ground, Math.min(1, -y * 3));
      colors.push(c.r, c.g, c.b);
    }
    geo.setAttribute('color', new T.Float32BufferAttribute(colors, 3));
    sky.add(new T.Mesh(geo, new T.MeshBasicMaterial({vertexColors: true, side: T.BackSide})));
    const sun = new T.Mesh(new T.SphereGeometry(8, 12, 8), new T.MeshBasicMaterial({color: 0xffffff}));
    sun.position.set(-40, 60, -50);
    sky.add(sun);
    const pmrem = new T.PMREMGenerator(renderer);
    const env = pmrem.fromScene(sky, .02).texture;
    pmrem.dispose();
    return env;
  }
  function setNight(night) {
    materials.glass.emissiveIntensity = night * 1.1;
    materials.light.color.setScalar(.55 + .45 * Math.min(1, night * 2));
    materials.pool.opacity = night * .85;
  }

  // ── Primitives ────────────────────────────────────────────────────────
  const shared = new Map();
  const geometry = (key, make) => { if (!shared.has(key)) shared.set(key, make()); return shared.get(key); };
  function add(g, geo, material, x, y, z, sx = 1, sy = 1, sz = 1, shadow = true) {
    const m = new T.Mesh(geo, material);
    m.position.set(x, y, z); m.scale.set(sx, sy, sz);
    m.castShadow = shadow; m.receiveShadow = true;
    g.add(m);
    return m;
  }
  const box = (g, w, h, d, x, y, z, color, kind = 'paint') =>
    add(g, geometry('box', () => new T.BoxGeometry(1, 1, 1)), mat(color, kind), x, y, z, w, h, d, h > .35);
  /** Flat paint on the ground, a few centimetres thick. */
  const decal = (g, w, d, x, z, color, y = .16, kind = 'paint') => box(g, w, .02, d, x, y, z, color, kind);
  function line(g, x1, z1, x2, z2, width, color, y = .16, kind = 'paint', height = .02) {
    const dx = x2 - x1, dz = z2 - z1, length = Math.hypot(dx, dz);
    const m = box(g, length, height, width, (x1 + x2) / 2, y, (z1 + z2) / 2, color, kind);
    m.rotation.y = Math.atan2(-dz, dx);
    return m;
  }
  function cylinder(g, r, h, x, y, z, color, kind = 'paint', rt = r, segments) {
    const seg = segments || (Math.max(r, rt) < .6 ? 8 : Math.max(r, rt) < 3 ? 16 : 28);
    return add(g, geometry(`c${seg}/${rt / r}`, () => new T.CylinderGeometry(rt / r, 1, 1, seg)), mat(color, kind), x, y, z, r, h, r, true);
  }
  function sphere(g, x, y, z, sx, sy, sz, color, kind = 'paint') {
    const low = Math.max(sx, sy, sz) < .6;
    return add(g, geometry(low ? 'sLow' : 'sHigh', () => new T.SphereGeometry(1, low ? 8 : 18, low ? 6 : 12)), mat(color, kind), x, y, z, sx, sy, sz, !low);
  }
  function shape(g, points, depth, color, kind = 'paint') {
    const s = new T.Shape();
    points.forEach(([x, z], i) => i ? s.lineTo(x, z) : s.moveTo(x, z));
    s.closePath();
    const geo = new T.ExtrudeGeometry(s, {depth, bevelEnabled: false});
    geo.rotateX(Math.PI / 2);
    const m = add(g, geo, mat(color, kind), 0, 0, 0);
    m.userData.ownGeometry = true;
    return m;
  }
  function light(g, x, y, z, color = 0xfff4d6, size = .35) {
    return add(g, geometry('lightBox', () => new T.BoxGeometry(1, 1, 1)), mat(color, 'light'), x, y, z, size, size * .6, size, false);
  }
  function pool(g, x, z, radius, color = 0xffe2a8) {
    const m = add(g, geometry('pool', () => new T.PlaneGeometry(1, 1).rotateX(-Math.PI / 2)), mat(color, 'pool'), x, .3, z, radius * 2, 1, radius * 2, false);
    m.userData.ownUv = true;
    return m;
  }
  function label(g, text, x, y, z, size = 6, color = '#f9fcf6', {ground = false, rotY = 0, background = null, width = 4} = {}) {
    const canvas = document.createElement('canvas');
    canvas.width = 128 * width; canvas.height = 128;
    const c = canvas.getContext('2d');
    if (background) { c.fillStyle = background; c.fillRect(0, 0, canvas.width, canvas.height); }
    c.fillStyle = color;
    c.font = `bold ${background ? 84 : 76}px "Segoe UI",sans-serif`;
    c.textAlign = 'center'; c.textBaseline = 'middle';
    c.fillText(text, canvas.width / 2, 68);
    const texture = new T.CanvasTexture(canvas);
    texture.colorSpace = T.SRGBColorSpace;
    texture.anisotropy = 4;
    const material = new T.MeshBasicMaterial({map: texture, transparent: !background, depthWrite: !!background, side: T.DoubleSide, polygonOffset: true, polygonOffsetFactor: -2});
    const m = new T.Mesh(new T.PlaneGeometry(size * width, size), material);
    m.position.set(x, y, z);
    if (ground) m.rotation.x = -Math.PI / 2;
    if (ground && rotY) m.rotation.z = rotY;
    else if (rotY) m.rotation.y = rotY;
    m.userData.owned = true;
    g.add(m);
    return m;
  }

  // ── Baking ────────────────────────────────────────────────────────────
  const flatGeometry = new WeakMap(), v = new T.Vector3(), n = new T.Vector3(), normalMatrix = new T.Matrix3();
  const plain = geo => { if (!geo.index) return geo; if (!flatGeometry.has(geo)) flatGeometry.set(geo, geo.toNonIndexed()); return flatGeometry.get(geo); };
  function merge(parts, kind, offset) {
    let total = 0;
    for (const p of parts) total += p.geo.attributes.position.count;
    const pos = new Float32Array(total * 3), nor = new Float32Array(total * 3), col = new Float32Array(total * 3);
    const scale = textured[kind], uv = scale || kind === 'pool' ? new Float32Array(total * 2) : null;
    let o = 0, u = 0;
    for (const {geo, matrix, color} of parts) {
      normalMatrix.getNormalMatrix(matrix);
      const P = geo.attributes.position, N = geo.attributes.normal, UV = geo.attributes.uv;
      for (let i = 0; i < P.count; i++, o += 3, u += 2) {
        v.fromBufferAttribute(P, i).applyMatrix4(matrix);
        n.fromBufferAttribute(N, i).applyMatrix3(normalMatrix).normalize();
        pos[o] = v.x; pos[o + 1] = v.y; pos[o + 2] = v.z;
        nor[o] = n.x; nor[o + 1] = n.y; nor[o + 2] = n.z;
        col[o] = color.r; col[o + 1] = color.g; col[o + 2] = color.b;
        if (kind === 'pool' && UV) { uv[u] = UV.getX(i); uv[u + 1] = UV.getY(i); }
        else if (uv) {
          const ax = Math.abs(n.x), ay = Math.abs(n.y), az = Math.abs(n.z);
          const wx = v.x + offset.x, wz = v.z + offset.z;
          if (ay >= ax && ay >= az) { uv[u] = wx / scale; uv[u + 1] = wz / scale; }
          else if (ax >= az) { uv[u] = wz / scale; uv[u + 1] = v.y / scale; }
          else { uv[u] = wx / scale; uv[u + 1] = v.y / scale; }
        }
      }
    }
    const geo = new T.BufferGeometry();
    geo.setAttribute('position', new T.BufferAttribute(pos, 3));
    geo.setAttribute('normal', new T.BufferAttribute(nor, 3));
    geo.setAttribute('color', new T.BufferAttribute(col, 3));
    if (uv) geo.setAttribute('uv', new T.BufferAttribute(uv, 2));
    geo.computeBoundingSphere(); geo.computeBoundingBox();
    return geo;
  }
  /** Folds plain meshes into one mesh per material kind (and roof/shadow role). */
  function bake(g, offset = {x: 0, z: 0}) {
    g.updateMatrixWorld(true);
    const inverse = g.matrixWorld.clone().invert(), buckets = new Map(), found = [];
    g.traverse(o => { if (o.isMesh && !o.userData.owned && !o.material.userData.baked && o.material.userData.kind) found.push(o); });
    for (const o of found) {
      const kind = o.material.userData.kind;
      const role = o.userData.roof ? 'roof' : o.userData.interior ? 'interior' : o.castShadow ? 'cast' : 'flat';
      const key = `${kind}|${role}`;
      if (!buckets.has(key)) buckets.set(key, {kind, role, parts: []});
      buckets.get(key).parts.push({geo: plain(o.geometry), matrix: new T.Matrix4().multiplyMatrices(inverse, o.matrixWorld), color: o.material.color});
      o.parent.remove(o);
    }
    const out = [];
    for (const {kind, role, parts} of buckets.values()) {
      const m = new T.Mesh(merge(parts, kind, offset), materials[kind]);
      m.castShadow = role === 'cast' || role === 'roof' || role === 'interior';
      m.receiveShadow = kind !== 'light' && kind !== 'pool';
      if (kind === 'pool') m.renderOrder = 2;
      m.userData.ownGeometry = true;
      if (role === 'roof') m.userData.roof = true;
      if (role === 'interior') m.userData.interior = true;
      g.add(m);
      out.push(m);
    }
    for (const o of found) if (o.userData.ownGeometry) o.geometry.dispose();
    for (const child of [...g.children]) if (child.isGroup && !child.children.length) g.remove(child);
    return out;
  }
  const templates = new Map();
  function instance(key, build) {
    let parts = templates.get(key);
    if (!parts) {
      parts = bake(build()).map(m => ({geometry: m.geometry, material: m.material, cast: m.castShadow, receive: m.receiveShadow}));
      templates.set(key, parts);
    }
    const g = new T.Group();
    for (const t of parts) { const m = new T.Mesh(t.geometry, t.material); m.castShadow = t.cast; m.receiveShadow = t.receive; g.add(m); }
    return g;
  }
  function dispose(group) {
    group.traverse(o => {
      if (o.userData.ownSprite) { o.material.map.dispose(); o.material.dispose(); }
      if (o.userData.owned) { o.geometry.dispose(); o.material.map?.dispose(); o.material.dispose(); }
      if (o.userData.ownGeometry && !o.userData.shared) o.geometry.dispose();
    });
  }

  // ── Scenery ───────────────────────────────────────────────────────────
  function tree(g, x, z, size = 1, kind = 0) {
    cylinder(g, .35 * size, 3.2 * size, x, 1.6 * size, z, 0x7a5f44);
    if (kind % 3 === 0) {
      cylinder(g, 2.6 * size, 5.5 * size, x, 5.2 * size, z, 0x3f7a58, 'paint', .01);
      cylinder(g, 2 * size, 4 * size, x, 7.4 * size, z, 0x4d8c63, 'paint', .01);
    } else {
      sphere(g, x, 5 * size, z, 2.6 * size, 2.9 * size, 2.6 * size, kind % 3 === 1 ? 0x4f8a5a : 0x5f9660);
      sphere(g, x + .9 * size, 6.1 * size, z - .4 * size, 1.7 * size, 1.8 * size, 1.7 * size, 0x6ea566);
    }
  }
  function palm(g, x, z, size = 1, stretch = 1) {
    cylinder(g, .7 * size, .8 * size, x, .4 * size, z, 0x8c6a4f, 'paint', .8 * size);
    cylinder(g, .12 * size, 2.6 * size * stretch, x, .8 * size + 1.3 * size * stretch, z, 0x8a6b45, 'paint', .08 * size);
    for (let i = 0; i < 6; i++) {
      const a = i / 6 * TAU;
      const leaf = box(g, 1.8 * size, .06, .45 * size, x + Math.cos(a) * .8 * size, (.8 + 2.4 * stretch) * size, z + Math.sin(a) * .8 * size, i % 2 ? 0x3f8f4e : 0x57a55a);
      leaf.rotation.set(0, -a, -.35);
    }
  }
  function cone(g, x, z) { cylinder(g, .22, .6, x, .3, z, 0xff7a2e, 'paint', .04); box(g, .5, .04, .5, x, .02, z, 0xff7a2e); }
  function lamp(g, x, z, height = 14) {
    cylinder(g, .18, height, x, height / 2, z, 0x8e9aa0, 'metal');
    box(g, 1.6, .35, .5, x, height, z, 0x59656b, 'metal');
    light(g, x, height - .25, z, 0xfff1cf, .9);
    box(g, .7, .5, .7, x, .25, z, 0xd34b3d);
  }

  // ── Facilities ────────────────────────────────────────────────────────
  function runway(g, w, d) {
    box(g, w, .12, d, w / 2, .06, d / 2, 0xffffff, 'asphalt');
    const white = 0xf4f3ea;
    for (let z = 90; z < d - 90; z += 50) decal(g, .9, 28, w / 2, z, white);
    for (const edge of [1.2, w - 1.2]) decal(g, .5, d - 8, edge, d / 2, white);
    for (const end of [0, 1]) {
      const z0 = end ? d - 40 : 40, dir = end ? -1 : 1;
      for (let x = 3; x < w / 2 - 3; x += 3.4) { decal(g, 1.8, 30, x, z0, white); decal(g, 1.8, 30, w - x, z0, white); }
      for (const side of [-1, 1]) decal(g, 3, 45, w / 2 + side * w * .22, z0 + dir * 130, white);
      for (let x = 2; x < w; x += 3) light(g, x, .22, end ? d - 2 : 2, end ? 0xff4a3a : 0x3dff8a, .45);
    }
    label(g, '09', w / 2, .15, 90, 9, '#f6f5ec', {ground: true});
    label(g, '27', w / 2, .15, d - 90, 9, '#f6f5ec', {ground: true, rotY: Math.PI});
    for (let z = 6; z < d - 4; z += 30) for (const x of [.4, w - .4]) { light(g, x, .3, z, 0xfff9e8, .6); }
    for (let z = 20; z < d; z += 15) light(g, w / 2, .16, z, 0xf2fbff, .22);
  }
  function taxiway(g, w, d) {
    box(g, w, .1, d, w / 2, .05, d / 2, 0xe8e8e8, 'asphalt');
    const vertical = d >= w, length = Math.max(w, d);
    if (vertical) {
      decal(g, .35, d, w / 2, d / 2, 0xf1c643);
      for (const x of [.6, w - .6]) decal(g, .2, d, x, d / 2, 0xf1c643);
    } else {
      decal(g, w, .35, w / 2, d / 2, 0xf1c643);
      for (const z of [.6, d - .6]) decal(g, w, .2, w / 2, z, 0xf1c643);
    }
    for (let t = 8; t < length; t += 16) {
      if (vertical) { light(g, .3, .3, t, 0x3f7dff, .5); light(g, w - .3, .3, t, 0x3f7dff, .5); light(g, w / 2, .15, t, 0x46ff8c, .28); }
      else { light(g, t, .3, .3, 0x3f7dff, .5); light(g, t, .3, d - .3, 0x3f7dff, .5); light(g, t, .15, d / 2, 0x46ff8c, .28); }
    }
  }
  function serviceRoad(g, w, d) {
    box(g, w, .09, d, w / 2, .045, d / 2, 0xd4d7d2, 'asphalt');
    const vertical = d >= w;
    for (let t = 3; t < Math.max(w, d) - 3; t += 8) {
      if (vertical) decal(g, .18, 4, w / 2, t + 2, 0xf1efe4); else decal(g, 4, .18, t + 2, d / 2, 0xf1efe4);
    }
    for (const edge of vertical ? [.25, w - .25] : [.25, d - .25]) {
      if (vertical) decal(g, .12, d, edge, d / 2, 0xe03f3f); else decal(g, w, .12, w / 2, edge, 0xe03f3f);
    }
  }
  /** Local frame of a stand whose aircraft nose points at [side] (0:+X 1:+Z 2:-X 3:-Z). */
  function noseFrame(side, w, d) {
    const W = side % 2 ? d : w, D = side % 2 ? w : d;
    const offset = [[0, 0], [w, 0], [w, d], [0, d]][side];
    return {W, D, angle: -side * Math.PI / 2, offset};
  }
  function stand(root, w, d, f, context) {
    const side = context?.noseSide || 0, frame = noseFrame(side, w, d);
    const g = new T.Group();
    g.rotation.y = frame.angle;
    g.position.set(frame.offset[0], 0, frame.offset[1]);
    root.add(g);
    [w, d] = [frame.W, frame.D];
    const regional = f.kind === 'standRegional', contact = f.kind === 'standContact';
    box(g, w, .12, d, w / 2, .06, d / 2, 0xe4e0d8, 'concrete');
    const white = 0xf5f3ea, yellow = 0xf2c230, red = 0xe0452f;
    for (const x of [.5, w - .5]) decal(g, .5, d, x, d / 2, white);
    decal(g, w, .5, w / 2, .5, white); decal(g, w, .5, w / 2, d - .5, white);
    // lead-in line enters from the -X (airside) edge and ends at a stop bar near +X
    const stopX = w - (regional ? 9 : 14), cz = d / 2;
    decal(g, stopX, .6, stopX / 2, cz, yellow);
    decal(g, .6, 8, stopX, cz, yellow);
    for (let x = 6; x < stopX - 4; x += 10) decal(g, .25, 2.2, x, cz, 0x1f1f1f, .165);
    decal(g, 2.2, .35, stopX - 1.1, cz - 3.5, yellow);
    decal(g, 2.2, .35, stopX - 1.1, cz + 3.5, yellow);
    // equipment restraint area: red hatched box beside the nose
    const hx = w - 11, hz = contact ? 3 : d - 15, hw = 9, hd = 12;
    for (const [x1, z1, x2, z2] of [[hx, hz, hx + hw, hz], [hx, hz + hd, hx + hw, hz + hd], [hx, hz, hx, hz + hd], [hx + hw, hz, hx + hw, hz + hd]]) line(g, x1, z1, x2, z2, .3, red);
    for (let t = 0; t < hd; t += 2.5) line(g, hx + .3, hz + t, hx + hw - .3, Math.min(hz + hd - .2, hz + t + 3), .22, red);
    // stand number box
    const code = String(f.id || '').replace(/\D/g, '').slice(-2).padStart(2, '0');
    decal(g, 9, 5, w - 6, d - 5.5, 0x1f1f1f, .15);
    label(g, `${regional ? 'R' : contact ? 'A' : 'B'}${code}`, w - 6, .18, d - 5.5, 4, '#1a1a1a', {ground: true, background: '#f2c230', width: 2});
    // ground power, chocks, cones and a floodlight
    box(g, 1.2, 1.4, .8, w - 3, .7, 4, 0x6d7c80, 'metal');
    light(g, w - 3, 1.5, 4.45, 0x55ff88, .2);
    for (const z of [cz - 4, cz + 4]) cone(g, stopX - 16, z);
    lamp(g, 2.5, 2.5, regional ? 10 : 15);
    pool(g, w * .42, d / 2, Math.min(w, d) * .42);
    if (contact) jetBridge(g, w, d);
  }
  /** Rotunda against the terminal plus a telescopic tunnel towards the nose. */
  function jetBridge(g, w, d) {
    const glass = 0x5fb4d6, frame = 0xd9dee2, dark = 0x3c4b52;
    const rx = w - 4.5, rz = d * .5 + 11;
    cylinder(g, 4, 5, rx, 5.5, rz, glass, 'glass');
    cylinder(g, 4.3, .6, rx, 8.3, rz, frame, 'metal');
    cylinder(g, 4.3, .5, rx, 3, rz, frame, 'metal');
    cylinder(g, .7, 3, rx, 1.5, rz, 0xb8c0c4, 'metal');
    const tx = w - 14 + 3, tz = d / 2 - 3.5;
    const ex = rx + (tx - rx) * .05, ez = rz + (tz - rz) * .05;
    line(g, ex, ez, tx, tz, 3, glass, 5.4, 'glass', 2.4);
    line(g, ex, ez, tx, tz, 3.4, frame, 6.8, 'metal', .35);
    line(g, ex, ez, tx, tz, 3.4, frame, 4.1, 'metal', .35);
    box(g, 3.2, 3, 3.2, tx, 5.5, tz, dark, 'metal');
    cylinder(g, .3, 3.8, tx, 1.9, tz, 0x9aa4a8, 'metal');
    box(g, 2.6, .6, 1, tx, .5, tz, 0x404b50, 'metal');
  }
  function terminal(g, w, d, context) {
    const open = context?.open || {};
    box(g, w, .3, d, w / 2, .15, d / 2, 0xffffff, 'tile').userData.interior = true;
    const wall = .5, height = 11, frame = 0xe7e8e4, glass = 0x4ea7cf;
    const sides = [
      ['-z', w, [w / 2, 0 + wall / 2], true],
      ['+z', w, [w / 2, d - wall / 2], true],
      ['-x', d, [wall / 2, d / 2], false],
      ['+x', d, [w - wall / 2, d / 2], false],
    ];
    for (const [name, length, [cx, cz], alongX] of sides) {
      if (open[name]) continue;
      const W = alongX ? length : wall, D = alongX ? wall : length;
      box(g, W, 1.2, D, cx, .9, cz, 0xcfd3d0);
      box(g, alongX ? W : wall * .6, height - 2.6, alongX ? wall * .6 : D, cx, 1.5 + (height - 2.6) / 2, cz, glass, 'glass');
      box(g, W, 1.1, D, cx, height - .55, cz, frame);
      for (let t = 0; t <= length; t += 6) {
        const px = alongX ? Math.min(w - .2, Math.max(.2, t)) : cx, pz = alongX ? cz : Math.min(d - .2, Math.max(.2, t));
        box(g, alongX ? .35 : wall + .08, height - 2.6, alongX ? wall + .08 : .35, px, 1.5 + (height - 2.6) / 2, pz, frame, 'metal');
      }
      box(g, W, .25, D, cx, 5.8, cz, frame, 'metal');
    }
    // roof with skylights, services and a sign
    const roofParts = [];
    roofParts.push(box(g, w, .7, d, w / 2, height + .35, d / 2, 0xaeb7bb, 'metal'));
    for (let z = 1.5; z < d - 1; z += 3) roofParts.push(box(g, w - 1, .14, .22, w / 2, height + .77, z, 0xc5ccce, 'metal'));
    for (const [x, z, ww, dd] of [[w / 2, .35, w, .7], [w / 2, d - .35, w, .7], [.35, d / 2, .7, d], [w - .35, d / 2, .7, d]]) {
      if ((x < 1 && open['-x']) || (x > w - 1 && open['+x']) || (z < 1 && open['-z']) || (z > d - 1 && open['+z'])) continue;
      roofParts.push(box(g, ww, 1.1, dd, x, height + .9, z, 0xe9ebe7));
    }
    for (let x = 12; x < w - 10; x += 24) {
      roofParts.push(box(g, 5, .45, d - 14, x, height + .95, d / 2, 0x6fb7d4, 'glass'));
      roofParts.push(box(g, 5.6, .25, d - 13.4, x, height + .8, d / 2, 0x8c979b, 'metal'));
      for (let z = 8; z < d - 7; z += 4) roofParts.push(box(g, 5.2, .1, .12, x, height + 1.2, z, 0xd9dedf, 'metal'));
    }
    for (const part of roofParts) part.userData.roof = true;
    for (let x = 18; x < w - 10; x += 34) {
      const unit = box(g, 5, 1.8, 3.4, x, height + 1.6, d * .78, 0xa3b0b1, 'metal'); unit.userData.roof = true;
      const fan = cylinder(g, 1, .25, x, height + 2.6, d * .78, 0x5a6668, 'metal'); fan.userData.roof = true;
    }
    if (!open['-z']) label(g, 'LUMA INTERNATIONAL', w / 2, height - .55, -.02, Math.min(w / 12, 1.8), '#1c4e5a');
    for (let x = 10; x < w - 5; x += 25) light(g, x, height - 1.4, .05, 0xfff0c8, .4);
  }
  function hangar(g, w, d) {
    box(g, w, .2, d, w / 2, .1, d / 2, 0xffffff, 'concrete');
    box(g, w - 1, 12, d - 2, w / 2, 6, d / 2 + 1, 0xdcdfe0, 'metal');
    const arch = add(g, geometry('arch', () => new T.CylinderGeometry(1, 1, 1, 28, 1, false, Math.PI / 2, Math.PI).rotateX(Math.PI / 2)), mat(0x8fa3a8, 'metal'), w / 2, 12, d / 2 + 1, w / 2 - .5, 4.5, d - 2);
    arch.userData.roof = true;
    box(g, w - 6, 10.5, .3, w / 2, 5.3, .9, 0x60757a, 'metal');
    for (let x = 4; x < w - 3; x += 4.5) box(g, .2, 10.5, .5, x, 5.3, .7, 0xc9d2d2, 'metal');
    box(g, w - 5, .6, .6, w / 2, 11, .8, 0xf2c230);
    label(g, 'TECHNICAL CENTRE', w / 2, 12.6, .6, 1.6, '#284a52', {rotY: 0});
    light(g, 3, 11.2, .6, 0xfff0c8, .6); light(g, w - 3, 11.2, .6, 0xfff0c8, .6);
    pool(g, w / 2, 14, 13);
    for (let x = 6; x < w; x += 12) decal(g, .25, 12, x, 6, 0xf2c230);
  }
  function fuelDepot(g, w, d) {
    box(g, w, .2, d, w / 2, .1, d / 2, 0xffffff, 'concrete');
    for (const [x1, z1, x2, z2] of [[.3, .3, w - .3, .3], [.3, d - .3, w - .3, d - .3], [.3, .3, .3, d - .3], [w - .3, .3, w - .3, d - .3]]) line(g, x1, z1, x2, z2, .5, 0xb7b3a6, .6, 'paint', 1);
    for (let i = 0; i < 2; i++) {
      const x = 8 + i * 13.5;
      cylinder(g, 5.2, 8.5, x, 4.45, d / 2 + 2, 0xf0efe8, 'metal');
      cylinder(g, 5.3, .5, x, 8.9, d / 2 + 2, 0xd5d9d6, 'metal', 4.6);
      cylinder(g, 5.25, .6, x, 2.2, d / 2 + 2, 0xe8b93a);
      box(g, .15, 8.5, .6, x + 5.2, 4.4, d / 2 + 2, 0x7d878a, 'metal');
      label(g, 'JET A-1', x, 5.5, d / 2 + 2 - 5.25, 1.2, '#355b53', {rotY: 0, width: 3});
    }
    line(g, 3, 4, w - 3, 4, .5, 0xa7b1b3, 1.2, 'metal', .5);
    for (let x = 4; x < w - 2; x += 5) box(g, .2, 1.2, .2, x, .6, 4, 0x8a9396, 'metal');
    light(g, 1, 3, 1, 0xff5a3c, .35);
    pool(g, w / 2, d / 2, 14);
  }
  function serviceBuilding(g, w, d, title, doors) {
    box(g, w, .2, d, w / 2, .1, d / 2, 0xffffff, 'concrete');
    box(g, w - 2, 6.5, d - 4, w / 2, 3.35, d / 2 + 1, 0xe2ddd0);
    const roof = box(g, w - 1.4, .5, d - 3.4, w / 2, 6.8, d / 2 + 1, 0x507b82); roof.userData.roof = true;
    const bays = Math.max(2, Math.floor((w - 4) / 6.5));
    for (let i = 0; i < bays; i++) {
      const x = 2.5 + (i + .5) * ((w - 5) / bays);
      box(g, 4.6, 4.2, .2, x, 2.2, 2.9, doors, 'metal');
      for (let y = .7; y < 4.2; y += .7) box(g, 4.6, .06, .25, x, y, 2.85, 0xc6cbc9, 'metal');
      box(g, 4.8, .35, .5, x, 4.6, 2.7, 0xf2c230);
      light(g, x, 5.2, 2.7, 0xfff0c8, .35);
    }
    box(g, w - 2, .7, .12, w / 2, 5.6, 2.9, 0x2d5b63);
    label(g, title, w / 2, 5.62, 2.83, .62, '#ffffff', {width: title.length * .55});
    pool(g, w / 2, d / 2, Math.min(w, d) / 2 - .5);
  }
  function tower(g, w, d) {
    box(g, w, .2, d, w / 2, .1, d / 2, 0xffffff, 'concrete');
    cylinder(g, 4.2, 3, w / 2, 1.5, d / 2, 0xd8d3c6, 'paint', 4.4);
    cylinder(g, 2.4, 26, w / 2, 16, d / 2, 0xeeeae0, 'paint', 1.9);
    for (let y = 6; y < 29; y += 4) cylinder(g, 2.45 - (y - 6) * .019, .25, w / 2, y, d / 2, 0xc9d0d1, 'metal');
    cylinder(g, 5.6, 1.2, w / 2, 29.6, d / 2, 0xdcdcd4, 'paint', 4.6);
    cylinder(g, 6.2, 4.2, w / 2, 32.3, d / 2, 0x2f7f98, 'glass', 5.4);
    for (let a = 0; a < 12; a++) { const t = a / 12 * TAU; box(g, .2, 4.2, .2, w / 2 + 5.8 * Math.cos(t), 32.3, d / 2 + 5.8 * Math.sin(t), 0xf2f0e8, 'metal'); }
    cylinder(g, 6.6, .8, w / 2, 34.8, d / 2, 0xf0ede3, 'paint', 6.2);
    box(g, 3, 1.4, 2.4, w / 2 + 1.5, 35.9, d / 2, 0xa8b2b4, 'metal');
    cylinder(g, .1, 6, w / 2 - 1.5, 38, d / 2, 0x5b666b, 'metal');
    light(g, w / 2 - 1.5, 41.1, d / 2, 0xff3b30, .5);
    pool(g, w / 2, d / 2, 7, 0xbfe4ff);
  }

  // ── Terminal furnishings ──────────────────────────────────────────────
  function ticketMachine(g, w, d) {
    const x = w / 2, z = d / 2, sx = w / 2, sz = d;
    const body = 0xd8d3c6, teal = 0x2a6d7a;
    const dark = 0x1b2e36, base = 0x3b4347;
    const glow = 0x7fe0e8, yellow = 0xf2c230;

    // Stepped shell: the top finishes at 2 m, inside a 0.91w x 0.88d base.
    box(g, 1.82 * sx, .08, .88 * sz, x, .04, z, base, 'metal');
    box(g, 1.70 * sx, .12, .80 * sz, x, .14, z, base, 'metal');
    box(g, 1.62 * sx, .034, .018 * sz, x, .202, z + .404 * sz, yellow);
    box(g, 1.60 * sx, 1.55, .70 * sz, x, .975, z - .03 * sz, body);
    box(g, 1.68 * sx, .08, .72 * sz, x, .24, z - .015 * sz, body);
    box(g, 1.52 * sx, .18, .66 * sz, x, 1.82, z - .04 * sz, body);
    box(g, 1.40 * sx, .09, .61 * sz, x, 1.955, z - .055 * sz, body);
    box(g, 1.31 * sx, .66, .028 * sz, x, .626, z + .333 * sz, body);
    box(g, 1.30 * sx, .095, .04 * sz, x, .32, z + .344 * sz, teal);
    box(g, .11 * sx, 1.42, .73 * sz, x - .765 * sx, .985, z - .015 * sz, teal);
    box(g, .11 * sx, 1.42, .73 * sz, x + .765 * sx, .985, z - .015 * sz, teal);
    box(g, 1.58 * sx, .235, .065 * sz, x, 1.795, z + .319 * sz, teal);

    // A geometric ticket, not a logo or a texture.
    box(g, .24 * sx, .12, .012 * sz, x, 1.801, z + .360 * sz, 0xf9fcf6);
    box(g, .036 * sx, .034, .014 * sz, x - .118 * sx, 1.801, z + .369 * sz, teal);
    box(g, .036 * sx, .034, .014 * sz, x + .118 * sx, 1.801, z + .369 * sz, teal);
    box(g, .11 * sx, .014, .014 * sz, x, 1.801, z + .369 * sz, teal);

    // Tilt is depth-aware; front layers share the same local screen plane.
    const a = -Math.atan(.18 * sz), sn = Math.sin(a), cs = Math.cos(a);
    const px = x - .205 * sx, py = 1.322, pz = z + .321 * sz;
    box(g, .95 * sx, .65, .07 * sz, px, py, pz, dark).rotation.x = a;
    const screen = light(g, px, py - sn * .046 * sz, pz + cs * .046 * sz, glow, .1);
    screen.scale.x *= 8.2 * sx;
    screen.scale.y *= 5.2;
    screen.scale.z *= .12 * sz;
    screen.rotation.x = a;
    for (const [dx, dy, bw, bh] of [[0, .15, .57, .027], [-.16, -.002, .25, .13], [.16, -.002, .25, .13], [0, -.17, .37, .025]]) {
      box(g, bw * sx, bh, .012 * sz, px + dx * sx, py + dy * cs - sn * .059 * sz, pz + dy * sn + cs * .059 * sz, teal).rotation.x = a;
    }

    box(g, .32 * sx, .50, .066 * sz, x + .50 * sx, 1.322, z + .343 * sz, dark, 'metal');
    const reader = light(g, x + .50 * sx, 1.462, z + .383 * sz, glow, .028);
    reader.scale.x *= 5 * sx;
    reader.scale.y *= .8;
    reader.scale.z *= .45 * sz;
    box(g, .23 * sx, .17, .043 * sz, x + .50 * sx, 1.314, z + .394 * sz, base, 'metal');
    box(g, .17 * sx, .024, .009 * sz, x + .50 * sx, 1.337, z + .419 * sz, dark);
    box(g, .096 * sx, .046, .01 * sz, x + .50 * sx, 1.259, z + .420 * sz, teal);
    box(g, .17 * sx, .009, .01 * sz, x + .50 * sx, 1.308, z + .419 * sz, yellow);

    box(g, .68 * sx, .16, .035 * sz, x - .21 * sx, .862, z + .344 * sz, base);
    box(g, .56 * sx, .04, .012 * sz, x - .21 * sx, .900, z + .367 * sz, dark);
    box(g, .32 * sx, .084, .070 * sz, x - .24 * sx, .858, z + .387 * sz, 0xf9fcf6);
    box(g, .72 * sx, .045, .088 * sz, x - .21 * sx, .774, z + .378 * sz, teal, 'metal');

    for (const side of [-1, 1]) {
      const strip = light(g, x + side * .765 * sx, 1.24, z + .365 * sz, glow, .1);
      strip.scale.x *= .31 * sx;
      strip.scale.y *= 8.6;
      strip.scale.z *= .25 * sz;
    }
    box(g, 1.24 * sx, .90, .026 * sz, x, .87, z - .393 * sz, body, 'metal');
    for (const y of [.69, .78, .87]) box(g, .70 * sx, .026, .014 * sz, x, y, z - .413 * sz, base, 'metal');
  }

  function vendingMachine(g, w, d) {
    const x = w / 2, z = d / 2, sx = w / 2, sz = d;
    const body = 0xd8d3c6, base = 0x3b4347, dark = 0x1b2e36;
    const teal = 0x2a6d7a, glow = 0x7fe0e8, yellow = 0xf2c230;

    // Cabinet shell: recessed core, right interface column, left pillar,
    // header and lower section frame a real display cavity for products.
    box(g, 1.90 * sx, .10, .90 * sz, x, .05, z, base, 'metal');
    box(g, 1.84 * sx, 1.85, .62 * sz, x, 1.025, z - .11 * sz, body);
    box(g, .62 * sx, 1.85, .86 * sz, x + .61 * sx, 1.025, z + .01 * sz, body);
    box(g, .10 * sx, 1.85, .86 * sz, x - .87 * sx, 1.025, z + .01 * sz, body);
    box(g, 1.22 * sx, .23, .24 * sz, x - .31 * sx, 1.835, z + .32 * sz, body);
    box(g, 1.22 * sx, .52, .24 * sz, x - .31 * sx, .36, z + .32 * sz, body);
    box(g, 1.72 * sx, .10, .76 * sz, x, 2.0, z, body);
    box(g, 1.22 * sx, .06, .02 * sz, x - .31 * sx, 1.80, z + .45 * sz, teal);

    // Display cavity: dark back wall, three shelves, one glass pane.
    box(g, 1.12 * sx, 1.10, .04 * sz, x - .26 * sx, 1.17, z + .22 * sz, dark);
    for (const y of [1.38, 1.02, .66]) box(g, 1.10 * sx, .03, .18 * sz, x - .26 * sx, y, z + .33 * sz, 0xb9b4a8, 'metal');
    const bags = [0xc86f4c, 0xe1b24d, 0x7fa262, 0x9d74a6];
    const boxes = [0x5c86b8, 0xd8956a, 0x8fb3a6, 0xc9c26e];
    const drinks = [0x3d7db6, 0xd05540, 0x66a566, 0xe6be47];
    const r = .07 * Math.min(sx, sz);
    for (let i = 0; i < 4; i++) {
      const cx = x + (-.65 + .26 * i) * sx;
      box(g, .18 * sx, .24, .08 * sz, cx, 1.515, z + .33 * sz, bags[i]);
      box(g, .20 * sx, .20, .10 * sz, cx, 1.135, z + .33 * sz, boxes[i]);
      cylinder(g, r, .28, cx, .815, z + .33 * sz, drinks[i], 'paint', r, 8);
    }
    // 'glass' renders opaque here, so the pane is drawn as its frame only.
    for (const y of [.63, 1.71]) box(g, 1.12 * sx, .02, .02 * sz, x - .26 * sx, y, z + .42 * sz, 0xbfc7c9, 'metal');
    for (const dx of [-.81, .29]) box(g, .02 * sx, 1.10, .02 * sz, x + dx * sx, 1.17, z + .42 * sz, 0xbfc7c9, 'metal');

    // Interface column: screen, keypad, card reader.
    box(g, .50 * sx, .62, .03 * sz, x + .61 * sx, 1.45, z + .45 * sz, dark);
    box(g, .40 * sx, .28, .02 * sz, x + .61 * sx, 1.58, z + .465 * sz, glow);
    light(g, x + .61 * sx, 1.58, z + .445 * sz, glow, .07);
    box(g, .30 * sx, .16, .02 * sz, x + .61 * sx, 1.30, z + .465 * sz, teal);
    box(g, .22 * sx, .10, .05 * sz, x + .61 * sx, 1.02, z + .455 * sz, base, 'metal');
    box(g, .16 * sx, .012, .01 * sz, x + .61 * sx, 1.04, z + .482 * sz, dark);

    // Dispensing opening with push flap and warning strip.
    box(g, .80 * sx, .30, .03 * sz, x - .26 * sx, .40, z + .43 * sz, dark);
    box(g, .72 * sx, .16, .02 * sz, x - .26 * sx, .48, z + .445 * sz, teal);
    box(g, .80 * sx, .03, .01 * sz, x - .26 * sx, .23, z + .445 * sz, yellow);

    // Subtle edge lights on both front pillars.
    for (const y of [.9, 1.5]) {
      light(g, x - .87 * sx, y, z + .44 * sz, glow, .06);
      light(g, x + .89 * sx, y, z + .44 * sz, glow, .06);
    }
  }

  function waitingSeats(g, w, d) {
    const x = w / 2, z = d / 2, sx = w / 4, sz = d / 2;
    const seat = 0x465b66, frame = 0x8b9295, arm = 0x3b4347, teal = 0x2a6d7a;

    // One shared beam on two pedestals carries everything: four seats,
    // five armrests, and a raised back rail. Seats face +z.
    box(g, 3.50 * sx, .10, .12 * sz, x, .30, z - .02 * sz, frame, 'metal');
    box(g, .08 * sx, .12, .14 * sz, x - 1.79 * sx, .30, z - .02 * sz, teal);
    box(g, .08 * sx, .12, .14 * sz, x + 1.79 * sx, .30, z - .02 * sz, teal);
    for (const side of [-1, 1]) {
      const px = x + side * 1.0 * sx;
      box(g, .16 * sx, .04, 1.40 * sz, px, .02, z, frame, 'metal');
      box(g, .12 * sx, .28, .16 * sz, px, .16, z - .02 * sz, frame, 'metal');
      box(g, .06 * sx, .46, .06 * sz, px, .53, z - .20 * sz, frame, 'metal');
    }
    box(g, 3.40 * sx, .05, .06 * sz, x, .40, z + .15 * sz, frame, 'metal');
    box(g, 3.40 * sx, .06, .06 * sz, x, .72, z - .20 * sz, frame, 'metal');

    // Seats: pan, lower back, upper back stepped rearward for a reclined feel.
    for (let i = 0; i < 4; i++) {
      const cx = x + (-1.2 + .8 * i) * sx;
      box(g, .62 * sx, .09, .50 * sz, cx, .45, z + .15 * sz, seat);
      box(g, .60 * sx, .28, .08 * sz, cx, .60, z - .14 * sz, seat);
      box(g, .58 * sx, .32, .07 * sz, cx, .88, z - .19 * sz, seat);
    }

    // Armrests between and at both ends of the row.
    for (let i = 0; i < 5; i++) {
      const ax = x + (-1.6 + .8 * i) * sx;
      box(g, .05 * sx, .22, .06 * sz, ax, .53, z + .05 * sz, frame, 'metal');
      box(g, .08 * sx, .05, .46 * sz, ax, .66, z + .10 * sz, arm);
    }

    // Charging pod under the centre armrest.
    box(g, .07 * sx, .07, .12 * sz, x, .49, z + .14 * sz, teal);
  }
  /** Builds [make] on the terminal floor slab, [x, z] in, optionally turned half round. */
  function onFloor(g, make, w, d, x = 0, z = 0, flip = false) {
    const part = new T.Group();
    part.position.set(x + (flip ? w : 0), .3, z + (flip ? d : 0));
    if (flip) part.rotation.y = Math.PI;
    g.add(part);
    make(part, w, d);
  }

  /** The carousel belt as a loop: centre line, radius, straight half-length. */
  function carouselLoop(w, d) {
    const x = w / 2, z = d / 2, sx = w / 10, sz = d / 5;
    const margin = .2 * Math.min(sx, sz);
    const outer = Math.min(z - margin, x - margin - sx);
    const span = x - margin - outer, island = 1.02 * sz;
    return {x, z, span, outer, radius: (island + outer - .13 * sz) / 2, length: 4 * span + TAU * (island + outer - .13 * sz) / 2};
  }
  /** Local point [s] metres along a stadium loop of [radius] around the model centre. */
  function loopPoint(loop, s, radius = loop.radius) {
    const {x, z, span} = loop, straight = 2 * span, arc = Math.PI * radius;
    s = ((s % (2 * straight + 2 * arc)) + 2 * straight + 2 * arc) % (2 * straight + 2 * arc);
    if (s < straight) return {x: x - span + s, z: z + radius, dir: 0};
    if ((s -= straight) < arc) { const a = s / radius; return {x: x + span + radius * Math.sin(a), z: z + radius * Math.cos(a), dir: a}; }
    if ((s -= arc) < straight) return {x: x + span - s, z: z - radius, dir: Math.PI};
    s -= straight;
    const a = s / radius;
    return {x: x - span - radius * Math.sin(a), z: z - radius * Math.cos(a), dir: Math.PI + a};
  }
  /** World matrix of a placed facility's model space (the terminal floor included for interiors). */
  function facilityFrame(f, floor = 0) {
    const turn = ((Math.round(f.rotation || 0) % 4) + 4) % 4;
    const w = turn % 2 ? f.depth : f.width, d = turn % 2 ? f.width : f.depth;
    const matrix = new T.Matrix4().makeRotationY(turn * Math.PI / 2);
    matrix.setPosition((f.x || 0) + (turn === 2 ? w : turn === 3 ? d : 0), floor, (f.y || 0) + (turn === 1 ? w : turn === 2 ? d : 0));
    return {w, d, matrix};
  }

  function baggageCarousel(g, w, d, live = false) {
    const x = w / 2, z = d / 2, sx = w / 10, sz = d / 5;
    const charcoal = 0x343b3e, deck = 0x454d50, slat = 0x2b3234;
    const metal = 0x9ba2a3, body = 0xd8d3c6, base = 0x3b4347;
    const teal = 0x2a6d7a, dark = 0x1b2e36, glow = 0x7fe0e8, yellow = 0xf2c230;
    const margin = .2 * Math.min(sx, sz);
    const outer = Math.min(z - margin, x - margin - sx);
    const span = x - margin - outer;
    const west = x - span, east = x + span;
    const island = 1.02 * sz;
    const beltTop = .55;

    // Offset drum caps and bridge decks stop their top faces from competing.
    // The bridge overlaps the lowered end caps, leaving a clean continuous rim.
    cylinder(g, outer - .07, .28, west, .14, z, base, 'metal', outer - .07, 12);
    cylinder(g, outer - .07, .28, east, .14, z, base, 'metal', outer - .07, 12);
    box(g, 2 * span, .30, 2 * (outer - .07), x, .15, z, base, 'metal');
    cylinder(g, outer - .03, .22, west, .39, z, charcoal, 'paint', outer - .03, 12);
    cylinder(g, outer - .03, .22, east, .39, z, charcoal, 'paint', outer - .03, 12);
    box(g, 2 * span, .21, 2 * (outer - .03), x, .40, z, charcoal);
    cylinder(g, outer - .11, .045, west, .5225, z, deck, 'paint', outer - .11, 12);
    cylinder(g, outer - .11, .045, east, .5225, z, deck, 'paint', outer - .11, 12);
    box(g, 2 * span, .10, 2 * (outer - .11), x, .50, z, deck);

    // Two raised inner runs suggest the sloped transfer surface into the island.
    box(g, 2 * span - .18 * sx, .06, .34 * sz, x, .58, z - 1.30 * sz, slat);
    box(g, 2 * span - .18 * sx, .06, .34 * sz, x, .58, z + 1.30 * sz, slat);
    for (const off of [-1.65, -.55, .65, 1.75]) {
      box(g, .035 * sx, .018, .86 * sz, x + off * sx, .559, z - 1.68 * sz, slat);
      box(g, .035 * sx, .018, .86 * sz, x + off * sx, .559, z + 1.68 * sz, slat);
    }

    // Long steel curbs make the carousel read as a contained passenger conveyor.
    box(g, 2 * span + .38 * sx, .12, .09 * sz, x, .59, z - outer + .13 * sz, metal, 'metal');
    box(g, 2 * span + .38 * sx, .12, .09 * sz, x, .59, z + outer - .13 * sz, metal, 'metal');
    box(g, 2 * span + .20 * sx, .025, .035 * sz, x, .6625, z - outer + .13 * sz, yellow);
    box(g, 2 * span + .20 * sx, .025, .035 * sz, x, .6625, z + outer - .13 * sz, yellow);
    box(g, 2 * span - .16 * sx, .07, .07 * sz, x, .585, z - island - .075 * sz, metal, 'metal');
    box(g, 2 * span - .16 * sx, .07, .07 * sz, x, .585, z + island + .075 * sz, metal, 'metal');

    // The raised, rounded service island is a separate tier, not buried in the belt.
    cylinder(g, island, .30, west, .70, z, body, 'paint', island, 10);
    cylinder(g, island, .30, east, .70, z, body, 'paint', island, 10);
    box(g, 2 * span, .34, 2 * island, x, .69, z, body);
    cylinder(g, island - .04, .06, west, .885, z, teal, 'paint', island - .04, 10);
    cylinder(g, island - .04, .06, east, .885, z, teal, 'paint', island - .04, 10);
    box(g, 2 * span - .12 * sx, .08, 2 * (island - .04), x, .87, z, teal);
    cylinder(g, island - .12, .07, west, .94, z, body, 'paint', island - .12, 10);
    cylinder(g, island - .12, .07, east, .94, z, body, 'paint', island - .12, 10);
    box(g, 2 * span - .22 * sx, .10, 2 * (island - .12), x, .93, z, body);

    // Dark service well and entry portal are planted directly on the island surface.
    box(g, 2.65 * sx, .045, .70 * sz, x - .35 * sx, 1.0025, z, dark);
    box(g, .88 * sx, .56, .62 * sz, x - 2.0 * sx, 1.26, z + .08 * sz, body);
    box(g, .92 * sx, .06, .66 * sz, x - 2.0 * sx, 1.57, z + .08 * sz, metal, 'metal');
    box(g, .68 * sx, .23, .02 * sz, x - 2.0 * sx, 1.34, z + .40 * sz, dark);
    light(g, x - 2.0 * sx, 1.34, z + .425 * sz, glow, .055);
    box(g, .12 * sx, .055, .02 * sz, x - 2.0 * sx, 1.54, z + .421 * sz, yellow);

    // Pylon passes into the island and the board overlaps its post instead of floating.
    const px = x + 1.55 * sx;
    cylinder(g, .14, 1.12, px, 1.50, z, metal, 'metal', .14, 8);
    cylinder(g, .21, .07, px, 1.005, z, teal, 'paint', .21, 8);
    box(g, 2.65 * sx, .56, .19 * sz, px, 1.99, z, base, 'metal');
    box(g, 2.45 * sx, .42, .025 * sz, px, 2.00, z + .123 * sz, dark);
    box(g, 2.45 * sx, .42, .025 * sz, px, 2.00, z - .123 * sz, dark);
    box(g, 2.75 * sx, .055, .22 * sz, px, 1.685, z, teal);
    box(g, 2.82 * sx, .05, .24 * sz, px, 2.295, z, metal, 'metal').userData.roof = true;
    light(g, px, 2.00, z + .148 * sz, glow, .11);
    light(g, px, 2.00, z - .148 * sz, glow, .11);
    // label() sizes are the text height in metres.
    label(g, '03', px + .66 * sx, 2.02, z + .155 * sz, .32, '#e8fbfd', {width: 1});
    label(g, '03', px + .66 * sx, 2.02, z - .155 * sz, .32, '#e8fbfd', {width: 1, rotY: Math.PI});
    label(g, 'BAGGAGE CLAIM', px - .58 * sx, 2.0, z + .155 * sz, .2, '#9fd4de', {width: 6});

    // Two floor chevrons sit outside the curb and never intersect the conveyor.
    box(g, .58 * sx, .012, .07 * sz, x - 1.4 * sx, .006, z - outer - .13 * sz, yellow);
    box(g, .58 * sx, .012, .07 * sz, x + .55 * sx, .006, z - outer - .13 * sz, yellow);

    if (live) return;
    // Varied luggage follows the annular path: front, back, then both rounded ends.
    const bags = [
      [-1.95, 1.67, .72, .24, .42, 0xc5b39a, .10, 1], [-.70, 1.68, .42, .54, .38, 0x243542, 0, 1],
      [.72, 1.68, .58, .27, .40, 0x4d5d43, -.14, 0], [2.28, 1.66, .54, .30, .34, 0x8a6a9c, .18, 0],
      [-2.55, -1.67, .40, .52, .36, 0x5c6570, 0, 1], [-1.20, -1.68, .62, .25, .42, 0x243542, 0, 1],
      [.18, -1.68, .34, .49, .32, 0xc9a14a, 0, 0], [1.50, -1.67, .88, .22, .28, 0xd9d3c4, -.12, 0],
      [2.55, -1.66, .52, .24, .34, 0x4d5d43, .14, 1], [-3.86, .55, .36, .56, .34, 0x6e3b38, .18, 1],
      [-3.90, -.65, .60, .22, .32, 0xd9d3c4, -.20, 0], [3.88, .48, .54, .24, .34, 0x5c6570, .18, 1],
    ];
    for (const [lx, lz, bw, bh, bd, col, ry, handle] of bags) {
      const bag = box(g, bw * sx, bh, bd * sz, x + lx * sx, beltTop + bh / 2, z + lz * sz, col);
      if (ry) bag.rotation.y = ry;
      if (handle) box(g, .26 * sx, .05, .05 * sz, x + lx * sx, beltTop + bh + .025, z + (lz - .11) * sz, base);
    }

    // Three unmistakably different bags complete the active reclaim loop.
    cylinder(g, .20, .62, x - .25 * sx, beltTop + .20, z + 1.68 * sz, 0x6e3b38, 'paint', .20, 10).rotation.z = Math.PI / 2;
    box(g, .10 * sx, .07, .46 * sz, x - .25 * sx, beltTop + .20, z + 1.68 * sz, base);
    box(g, .72 * sx, .04, .44 * sz, x - 1.95 * sx, beltTop + .26, z + 1.67 * sz, base);
    cylinder(g, .20, .58, x + 4.12 * sx, beltTop + .20, z, 0x4d5d43, 'paint', .20, 10).rotation.x = Math.PI / 2;
    box(g, .44 * sx, .07, .10 * sz, x + 4.12 * sx, beltTop + .20, z, base);
  }

  function dutyFreeClothing(g, w, d) {
    const u = w / 8, v = d / 6, x = w / 2, s = Math.min(u, v);
    const shell = 0xe5e0d5, wall = 0xd8d3c6, dark = 0x343b3e, steel = 0x8b9295;
    const teal = 0x2a6d7a, warm = 0xffe2a8, screen = 0x7fe0e8, pane = 0xbfe3ea;
    const cloth = [0xb4553f, 0x3f5e78, 0x7a8f6b, 0xc9a86a, 0x8d6a93, 0xd8cfc0, 0x2f3a44, 0xa8564e];

    // Shell: floor, three closed sides, storefront left open on +z.
    box(g, 7.9 * u, .04, 5.9 * v, x, .02, 3 * v, wall);
    box(g, 2.3 * u, .05, .55 * v, 4 * u, .025, 5.55 * v, teal);
    box(g, 7.9 * u, 3.0, .14 * v, x, 1.5, .12 * v, shell);
    box(g, .14 * u, 3.0, 5.9 * v, .12 * u, 1.5, 3 * v, wall);
    box(g, .14 * u, 3.0, 5.9 * v, w - .12 * u, 1.5, 3 * v, wall);
    box(g, 7.6 * u, .10, .05 * v, x, 2.55, .21 * v, teal);

    // Storefront: corner pillars, deep fascia, lit sign band.
    box(g, .5 * u, 3.10, .5 * v, .32 * u, 1.55, 5.70 * v, shell);
    box(g, .5 * u, 3.10, .5 * v, w - .32 * u, 1.55, 5.70 * v, shell);
    box(g, 7.9 * u, .65, .45 * v, x, 2.775, 5.72 * v, shell);
    box(g, 7.9 * u, .05, .54 * v, x, 3.125, 5.72 * v, teal).userData.roof = true;
    box(g, 3.0 * u, .44, .05 * v, x, 2.80, 5.945 * v, dark);
    // label() sizes are the text height in metres.
    label(g, 'AERIA', x, 2.88, 5.985 * v, .24, '#f9fcf6', {width: 3});
    label(g, 'DUTY FREE FASHION', x, 2.64, 5.985 * v, .1, '#9fd4de', {width: 7});
    light(g, 1.5 * u, 2.80, 5.88 * v, warm, .16);
    light(g, w - 1.5 * u, 2.80, 5.88 * v, warm, .16);

    // Two window bays flanking a 2.3 m walk-in entrance. 'glass' renders
    // opaque here, so the glazing is drawn as its frame to keep the displays visible.
    for (const px of [1.70 * u, w - 1.70 * u]) {
      for (const y of [.44, 2.40]) box(g, 2.3 * u, .04, .06 * v, px, y, 5.86 * v, steel, 'metal');
      for (const dx of [-1.13, 0, 1.13]) box(g, .04 * u, 2.0, .06 * v, px + dx * u, 1.42, 5.86 * v, steel, 'metal');
      box(g, 2.3 * u, .42, .20 * v, px, .21, 5.86 * v, dark);
      box(g, 2.2 * u, .26, 1.05 * v, px, .15, 5.20 * v, shell);
    }

    // Mannequin forms staged on the window platforms.
    for (const [mx, mz, tc, bc] of [
      [1.12 * u, 5.02 * v, 0x3f5e78, 0x2f3a44],
      [2.28 * u, 5.32 * v, 0xc9a86a, 0xd8cfc0],
      [w - 1.12 * u, 5.02 * v, 0xb4553f, 0x2f3a44],
      [w - 2.28 * u, 5.32 * v, 0x7a8f6b, 0xd8cfc0],
    ]) {
      cylinder(g, .19 * s, .05, mx, .305, mz, steel, 'metal', .19 * s, 10);
      box(g, .30 * u, .72, .24 * v, mx, .69, mz, bc);
      box(g, .44 * u, .60, .28 * v, mx, 1.35, mz, tc);
      sphere(g, mx, 1.76, mz, .115 * u, .145, .115 * v, shell);
    }

    // Back wall: hanging rail under a folded stock shelf.
    box(g, 3.4 * u, .07, .34 * v, 4.9 * u, 2.30, .40 * v, shell);
    box(g, 3.4 * u, .05, .05 * v, 4.9 * u, 1.92, .42 * v, steel, 'metal');
    for (let i = 0; i < 7; i++) {
      const gh = .70 + ((i * 5) % 3) * .09;
      box(g, (.26 + ((i * 7) % 3) * .05) * u, gh, .24 * v, (3.45 + i * .48) * u, 1.90 - gh / 2, .44 * v, cloth[(i * 3) % 8]);
    }
    for (let i = 0; i < 3; i++) box(g, .52 * u, .16, .26 * v, (3.85 + i * 1.05) * u, 2.415, .40 * v, cloth[(i * 2 + 5) % 8]);
    light(g, 4.9 * u, 2.05, .75 * v, warm, .18);

    // Right wall: shelving bay of folded merchandise.
    box(g, .10 * u, 2.10, 2.80 * v, 7.765 * u, 1.05, 2.30 * v, shell);
    const shelfY = [.75, 1.30, 1.85];
    for (const yy of shelfY) box(g, .56 * u, .06, 2.60 * v, 7.45 * u, yy, 2.30 * v, shell);
    for (let i = 0; i < 3; i++) {
      box(g, .42 * u, .18, .55 * v, 7.45 * u, shelfY[i] + .12, 1.55 * v, cloth[(i * 2) % 8]);
      box(g, .42 * u, .18, .55 * v, 7.45 * u, shelfY[i] + .12, 3.05 * v, cloth[(i * 2 + 3) % 8]);
    }
    light(g, 7.40 * u, 2.18, 2.30 * v, warm, .16);

    // Straight rail rack with garments of mixed width and length.
    for (const ox of [-.92, .92]) {
      cylinder(g, .045 * s, 1.35, (2.20 + ox) * u, .675, 3.30 * v, steel, 'metal', .045 * s, 8);
      box(g, .46 * u, .05, .46 * v, (2.20 + ox) * u, .025, 3.30 * v, dark);
    }
    box(g, 1.94 * u, .05, .06 * v, 2.20 * u, 1.36, 3.30 * v, steel, 'metal');
    for (let i = 0; i < 7; i++) {
      const gh = .66 + ((i * 4) % 3) * .08;
      box(g, (.24 + ((i * 5) % 2) * .06) * u, gh, .30 * v, (1.36 + i * .28) * u, 1.34 - gh / 2, 3.30 * v, cloth[(i * 5) % 8]);
    }

    // Round rack: centre post, ring rail, garments turned to the circle.
    cylinder(g, .32 * s, .06, 5.95 * u, .03, 3.45 * v, dark, 'paint', .32 * s, 10);
    cylinder(g, .05 * s, 1.28, 5.95 * u, .64, 3.45 * v, steel, 'metal', .05 * s, 8);
    cylinder(g, .60 * s, .05, 5.95 * u, 1.28, 3.45 * v, steel, 'metal', .60 * s, 12);
    for (let i = 0; i < 6; i++) {
      const a = i * Math.PI / 3, gh = .62 + (i % 3) * .07;
      box(g, .30 * u, gh, .22 * v, 5.95 * u + Math.cos(a) * .52 * s, 1.26 - gh / 2, 3.45 * v + Math.sin(a) * .52 * s, cloth[(i * 2 + 1) % 8]).rotation.y = -a;
    }

    // Central display table with stacked folded goods.
    box(g, 1.30 * u, .62, .85 * v, 4.05 * u, .31, 2.15 * v, shell);
    box(g, 1.62 * u, .08, 1.06 * v, 4.05 * u, .66, 2.15 * v, dark);
    box(g, 1.34 * u, .06, .89 * v, 4.05 * u, .60, 2.15 * v, teal);
    for (let i = 0; i < 4; i++) {
      const hh = .15 + (i % 2) * .05;
      box(g, .42 * u, hh, .40 * v, (3.70 + (i % 2) * .70) * u, .70 + hh / 2, (1.86 + (i < 2 ? 0 : .58)) * v, cloth[(i * 3 + 2) % 8]);
    }

    // Checkout: customer counter, till, and staff-side back unit.
    box(g, 2.20 * u, .92, .72 * v, 1.55 * u, .46, 1.95 * v, shell);
    box(g, 2.32 * u, .08, .82 * v, 1.55 * u, .96, 1.95 * v, dark);
    box(g, 2.05 * u, .46, .05 * v, 1.55 * u, .50, 2.30 * v, teal);
    box(g, .34 * u, .22, .28 * v, 2.30 * u, 1.11, 1.95 * v, dark);
    light(g, 2.30 * u, 1.16, 2.10 * v, screen, .13);
    box(g, 2.30 * u, 1.05, .38 * v, 1.55 * u, .525, .58 * v, wall);
    box(g, 2.40 * u, .06, .46 * v, 1.55 * u, 1.08, .58 * v, dark);
    for (let i = 0; i < 3; i++) box(g, .50 * u, .17, .30 * v, (.85 + i * .70) * u, 1.195, .58 * v, cloth[(i * 4 + 1) % 8]);
    label(g, 'PAY HERE', 1.55 * u, 1.55, .80 * v, .14, '#9fd4de', {width: 3.5});

    // Fitting mirror on the left wall.
    box(g, .05 * u, 1.70, 1.10 * v, .215 * u, 1.35, 4.20 * v, pane, 'glass');

    // Ceiling beams carrying the warm retail downlights.
    box(g, 5.80 * u, .10, .22 * v, 4.00 * u, 2.88, 1.70 * v, shell).userData.roof = true;
    box(g, 5.80 * u, .10, .22 * v, 4.00 * u, 2.88, 3.50 * v, shell).userData.roof = true;
    light(g, 2.60 * u, 2.79, 1.70 * v, warm, .20);
    light(g, 5.40 * u, 2.79, 3.50 * v, warm, .20);
  }

  function cozyClothing(g, w, d) {
    const u = w / 8, v = d / 6, x = w / 2, s = Math.min(u, v);
    const floorWood = 0xc49a6c, timber = 0x8a5a3b, cream = 0xe8dcc8;
    const wallWarm = 0xd9c6a8, dark = 0x4a3f35, brass = 0xd9a441;
    const warm = 0xffd9a0, pane = 0xd8e8e0, rust = 0xb4553f;
    const cloth = [0xb4553f, 0xd9a441, 0x7a8f6b, 0x8a5a3b, 0xc9a86a, 0xa8564e, 0xe8dcc8, 0x6e4a3a];

    // Shell: warm plank floor, rugs overlapping it, three closed sides.
    box(g, 7.9 * u, .04, 5.9 * v, x, .02, 3 * v, floorWood);
    box(g, 1.6 * u, .02, 2.8 * v, x, .045, 4.0 * v, rust);
    box(g, 1.8 * u, .02, 1.4 * v, 1.1 * u, .045, 4.15 * v, 0xa8564e);
    box(g, 7.9 * u, 3.0, .14 * v, x, 1.5, .12 * v, cream);
    box(g, .14 * u, 3.0, 5.9 * v, .12 * u, 1.5, 3 * v, wallWarm);
    box(g, .14 * u, 3.0, 5.9 * v, w - .12 * u, 1.5, 3 * v, wallWarm);
    box(g, 7.6 * u, .9, .06 * v, x, .45, .21 * v, timber);
    box(g, 7.6 * u, .12, .08 * v, x, 2.5, .22 * v, timber);

    // Storefront: timber pillars and fascia, brass trim, lit sign band.
    box(g, .5 * u, 3.10, .5 * v, .32 * u, 1.55, 5.70 * v, timber);
    box(g, .5 * u, 3.10, .5 * v, w - .32 * u, 1.55, 5.70 * v, timber);
    box(g, 7.9 * u, .65, .45 * v, x, 2.775, 5.72 * v, timber);
    box(g, 7.9 * u, .06, .48 * v, x, 2.44, 5.72 * v, brass);
    box(g, 7.9 * u, .05, .54 * v, x, 3.12, 5.72 * v, dark).userData.roof = true;
    box(g, 3.2 * u, .44, .05 * v, x, 2.80, 5.945 * v, dark);
    // label() sizes are the text height in metres.
    label(g, 'WREN & WOOL', x, 2.88, 5.985 * v, .22, '#ffe8c4', {width: 4.5});
    label(g, 'KNITWEAR - TRAVEL COMFORT', x, 2.65, 5.985 * v, .08, '#e8c98f', {width: 9});
    light(g, 1.5 * u, 2.80, 5.88 * v, warm, .16);
    light(g, w - 1.5 * u, 2.80, 5.88 * v, warm, .16);

    // Two window bays flanking a 2.3 m walk-in entrance. 'glass' renders
    // opaque here, so the glazing is drawn as a timber frame.
    for (const px of [1.70 * u, w - 1.70 * u]) {
      box(g, 2.3 * u, .05, .06 * v, px, 2.40, 5.86 * v, timber);
      for (const dx of [-1.13, 0, 1.13]) box(g, .05 * u, 2.0, .06 * v, px + dx * u, 1.42, 5.86 * v, timber);
      box(g, 2.3 * u, .42, .20 * v, px, .23, 5.86 * v, timber);
      box(g, 2.2 * u, .26, 1.05 * v, px, .15, 5.20 * v, cream);
      box(g, 2.24 * u, .04, 1.09 * v, px, .295, 5.20 * v, timber);
    }

    // Mannequin forms in chunky knits, staged on the window platforms.
    for (const [mx, mz, tc, bc, sc] of [
      [1.12 * u, 5.02 * v, 0x7a8f6b, 0x6e4a3a, 0xd9a441],
      [2.28 * u, 5.32 * v, 0xc9a86a, 0x8a5a3b, 0],
      [w - 1.12 * u, 5.02 * v, 0xb4553f, 0x4a3f35, 0xe8dcc8],
      [w - 2.28 * u, 5.32 * v, 0xa8564e, 0x6e4a3a, 0],
    ]) {
      cylinder(g, .19 * s, .05, mx, .335, mz, timber, 'paint', .19 * s, 10);
      box(g, .30 * u, .72, .24 * v, mx, .715, mz, bc);
      box(g, .44 * u, .60, .28 * v, mx, 1.365, mz, tc);
      sphere(g, mx, 1.80, mz, .115 * u, .145, .115 * v, cream);
      if (sc) box(g, .30 * u, .10, .30 * v, mx, 1.62, mz, sc);
    }

    // Back wall: brass rail of knitwear under a timber stock shelf.
    box(g, 3.4 * u, .07, .34 * v, 4.9 * u, 2.30, .34 * v, timber);
    box(g, 3.4 * u, .05, .05 * v, 4.9 * u, 1.92, .42 * v, brass, 'metal');
    box(g, .06 * u, .06, .25 * v, 4.9 * u, 1.92, .30 * v, timber);
    for (let i = 0; i < 5; i++) {
      const gh = .60 + ((i * 5) % 3) * .08;
      box(g, (.30 + ((i * 7) % 3) * .05) * u, gh, .28 * v, (3.70 + i * .55) * u, 1.90 - gh / 2, .44 * v, cloth[(i * 3) % 8]);
    }
    for (let i = 0; i < 3; i++) box(g, .52 * u, .16, .26 * v, (3.85 + i * 1.05) * u, 2.41, .34 * v, cloth[(i * 2 + 5) % 8]);
    light(g, 4.9 * u, 2.05, .75 * v, warm, .18);

    // Right wall: timber shelving bay of folded knits.
    box(g, .10 * u, 2.10, 2.80 * v, 7.765 * u, 1.05, 2.30 * v, timber);
    const shelfY = [.75, 1.30, 1.85];
    for (const yy of shelfY) box(g, .56 * u, .06, 2.60 * v, 7.45 * u, yy, 2.30 * v, timber);
    for (let i = 0; i < 2; i++) {
      box(g, .42 * u, .18, .55 * v, 7.45 * u, shelfY[i] + .11, 1.55 * v, cloth[(i * 2) % 8]);
      box(g, .42 * u, .18, .55 * v, 7.45 * u, shelfY[i] + .11, 3.05 * v, cloth[(i * 2 + 3) % 8]);
    }
    light(g, 7.40 * u, 2.18, 2.30 * v, warm, .16);

    // Straight timber rack with chunky garments.
    for (const ox of [-.92, .92]) {
      cylinder(g, .05 * s, 1.35, (2.20 + ox) * u, .675, 3.30 * v, timber, 'paint', .05 * s, 8);
      box(g, .46 * u, .05, .46 * v, (2.20 + ox) * u, .06, 3.30 * v, dark);
    }
    box(g, 1.94 * u, .06, .06 * v, 2.20 * u, 1.36, 3.30 * v, timber);
    for (let i = 0; i < 5; i++) {
      const gh = .58 + ((i * 4) % 3) * .08;
      box(g, (.28 + ((i * 5) % 2) * .06) * u, gh, .30 * v, (1.50 + i * .35) * u, 1.34 - gh / 2, 3.30 * v, cloth[(i * 5) % 8]);
    }

    // Round rack: timber post and ring, garments turned to the circle.
    cylinder(g, .32 * s, .06, 5.95 * u, .065, 3.45 * v, dark, 'paint', .32 * s, 10);
    cylinder(g, .05 * s, 1.28, 5.95 * u, .70, 3.45 * v, timber, 'paint', .05 * s, 8);
    cylinder(g, .60 * s, .05, 5.95 * u, 1.32, 3.45 * v, timber, 'paint', .60 * s, 12);
    for (let i = 0; i < 5; i++) {
      const a = i * Math.PI * 2 / 5, gh = .56 + (i % 3) * .07;
      box(g, .32 * u, gh, .24 * v, 5.95 * u + Math.cos(a) * .52 * s, 1.30 - gh / 2, 3.45 * v + Math.sin(a) * .52 * s, cloth[(i * 2 + 1) % 8]).rotation.y = -a;
    }

    // Central harvest table with folded knits and a yarn basket.
    box(g, 1.30 * u, .62, .85 * v, 4.05 * u, .34, 2.15 * v, timber);
    box(g, 1.62 * u, .08, 1.06 * v, 4.05 * u, .68, 2.15 * v, dark);
    box(g, 1.34 * u, .06, .89 * v, 4.05 * u, .615, 2.15 * v, brass);
    for (let i = 0; i < 2; i++) {
      const hh = .15 + i * .05;
      box(g, .42 * u, hh, .40 * v, (3.70 + i * .70) * u, .71 + hh / 2, 2.0 * v, cloth[(i * 3 + 2) % 8]);
    }
    cylinder(g, .28 * s, .35, 3.0 * u, .21, 1.2 * v, timber, 'paint', .24 * s, 10);

    // Checkout: timber counter, till, and staff-side back unit.
    box(g, 2.20 * u, .92, .72 * v, 1.55 * u, .48, 1.95 * v, timber);
    box(g, 2.32 * u, .08, .82 * v, 1.55 * u, .97, 1.95 * v, dark);
    box(g, 2.05 * u, .10, .03 * v, 1.55 * u, .70, 2.32 * v, brass);
    box(g, .34 * u, .22, .28 * v, 2.30 * u, 1.11, 1.95 * v, dark);
    light(g, 2.30 * u, 1.20, 2.10 * v, warm, .13);
    box(g, 2.30 * u, 1.05, .38 * v, 1.55 * u, .545, .58 * v, wallWarm);
    box(g, 2.40 * u, .06, .46 * v, 1.55 * u, 1.09, .58 * v, dark);
    for (let i = 0; i < 2; i++) box(g, .50 * u, .17, .30 * v, (1.05 + i * .80) * u, 1.195, .58 * v, cloth[(i * 4 + 1) % 8]);
    label(g, 'PAY HERE', 1.55 * u, 1.55, .80 * v, .14, '#e8c98f', {width: 3.5});

    // Cosy seating corner: two armchairs and a lamp table.
    box(g, .65 * u, .38, .60 * v, .75 * u, .24, 3.80 * v, 0xa8564e);
    box(g, .18 * u, .65, .60 * v, .51 * u, .55, 3.80 * v, 0xa8564e);
    box(g, .65 * u, .38, .60 * v, .75 * u, .24, 4.50 * v, 0xd9a441);
    box(g, .18 * u, .65, .60 * v, .51 * u, .55, 4.50 * v, 0xd9a441);
    cylinder(g, .22 * s, .45, .85 * u, .265, 4.15 * v, timber, 'paint', .22 * s, 10);
    cylinder(g, .06 * s, .10, .85 * u, .53, 4.15 * v, brass, 'metal', .14 * s, 8);
    light(g, .85 * u, .60, 4.15 * v, warm, .10);

    // Timber-framed fitting mirror on the left wall.
    box(g, .08 * u, 1.80, 1.20 * v, .22 * u, 1.35, 2.90 * v, timber);
    box(g, .04 * u, 1.70, 1.10 * v, .26 * u, 1.35, 2.90 * v, pane, 'glass');

    // Timber ceiling beams carrying warm pendants.
    box(g, 5.80 * u, .10, .22 * v, 4.00 * u, 2.88, 1.70 * v, timber).userData.roof = true;
    box(g, 5.80 * u, .10, .22 * v, 4.00 * u, 2.88, 3.50 * v, timber).userData.roof = true;
    for (const [lx, lz] of [[4.05, 2.15], [2.20, 3.30], [5.95, 3.45]]) {
      cylinder(g, .02 * s, .25, lx * u, 2.72, lz * v, dark, 'paint', .02 * s, 6);
      cylinder(g, .06 * s, .16, lx * u, 2.55, lz * v, brass, 'metal', .18 * s, 10);
      light(g, lx * u, 2.48, lz * v, warm, .11);
    }
  }

  function vipLounge(g, w, d) {
    const u = w / 8, v = d / 6, x = w / 2, s = Math.min(u, v);
    const floorWood = 0x221c17, walnut = 0x2b211a, charcoal = 0x1c1918;
    const darkWall = 0x25201d, brass = 0xc59a4a;
    const bordeaux = 0x48151b, navy = 0x162332, cognac = 0x6a3f22;
    const warm = 0xffc882, screenGlow = 0x7fe0e8;

    // Foundation: dark smoked walnut parquet and plush area rugs.
    box(g, 7.9 * u, .04, 5.9 * v, x, .02, 3 * v, floorWood);
    box(g, 3.5 * u, .02, 3.1 * v, 2.6 * u, .045, 3.2 * v, 0x331217);
    box(g, 2.2 * u, .02, 2.8 * v, 6.4 * u, .045, 2.7 * v, 0x121c27);

    // Shell: charcoal acoustic panels, walnut wainscot and brass reveal trim.
    box(g, 7.9 * u, 3.0, .14 * v, x, 1.5, .12 * v, charcoal);
    box(g, .14 * u, 3.0, 5.9 * v, .12 * u, 1.5, 3 * v, darkWall);
    box(g, .14 * u, 3.0, 5.9 * v, w - .12 * u, 1.5, 3 * v, darkWall);
    box(g, 7.6 * u, 1.1, .06 * v, x, .55, .21 * v, walnut);
    box(g, 7.6 * u, .08, .08 * v, x, 1.12, .22 * v, brass, 'metal');
    box(g, 7.6 * u, .08, .08 * v, x, 2.60, .22 * v, brass, 'metal');

    // Facade: walnut portal, brass frieze, backlit signage.
    box(g, .5 * u, 3.10, .5 * v, .32 * u, 1.55, 5.70 * v, walnut);
    box(g, .5 * u, 3.10, .5 * v, w - .32 * u, 1.55, 5.70 * v, walnut);
    box(g, 7.9 * u, .65, .45 * v, x, 2.775, 5.72 * v, walnut);
    box(g, 7.9 * u, .06, .48 * v, x, 2.44, 5.72 * v, brass, 'metal');
    box(g, 7.9 * u, .05, .54 * v, x, 3.12, 5.72 * v, charcoal).userData.roof = true;
    box(g, 3.4 * u, .44, .05 * v, x, 2.80, 5.945 * v, charcoal);
    // label() sizes are the text height in metres.
    label(g, 'VIP LOUNGE', x, 2.88, 5.985 * v, .22, '#d4af37', {width: 4.5});
    label(g, 'FIRST CLASS & PRIVILEGE CLUB', x, 2.65, 5.985 * v, .075, '#c59a4a', {width: 10});
    light(g, 1.5 * u, 2.80, 5.88 * v, warm, .16);
    light(g, w - 1.5 * u, 2.80, 5.88 * v, warm, .16);

    // Facade partitions. 'glass' renders opaque here, so the smoked glazing is
    // drawn as its brass frame and the salon stays visible.
    for (const px of [1.60 * u, w - 1.60 * u]) {
      box(g, 2.1 * u, .04, .06 * v, px, 2.40, 5.86 * v, brass, 'metal');
      for (const dx of [-1.03, 1.03]) box(g, .04 * u, 2.0, .06 * v, px + dx * u, 1.42, 5.86 * v, brass, 'metal');
      box(g, 2.1 * u, .42, .20 * v, px, .23, 5.86 * v, walnut);
      box(g, 2.14 * u, .04, .22 * v, px, .45, 5.86 * v, brass, 'metal');
    }

    // Concierge desk just inside the entrance.
    box(g, 1.9 * u, .95, .65 * v, 1.5 * u, .50, 4.8 * v, walnut);
    box(g, 2.0 * u, .07, .72 * v, 1.5 * u, .99, 4.8 * v, charcoal);
    box(g, 1.8 * u, .10, .03 * v, 1.5 * u, .72, 5.14 * v, brass, 'metal');
    box(g, .34 * u, .22, .28 * v, 2.0 * u, 1.13, 4.8 * v, charcoal);
    light(g, 2.0 * u, 1.22, 4.95 * v, screenGlow, .12);
    label(g, 'CONCIERGE', 1.5 * u, 1.50, 4.8 * v, .1, '#c59a4a', {width: 4.5});

    // Conversation salon: velvet Chesterfield, leather club chairs, marble table.
    box(g, 2.5 * u, .42, .85 * v, 2.6 * u, .24, 2.2 * v, bordeaux);
    box(g, 2.5 * u, .45, .30 * v, 2.6 * u, .64, 1.85 * v, bordeaux);
    box(g, .35 * u, .38, .90 * v, 1.25 * u, .60, 2.2 * v, bordeaux);
    box(g, .35 * u, .38, .90 * v, 3.95 * u, .60, 2.2 * v, bordeaux);
    box(g, 2.6 * u, .06, .90 * v, 2.6 * u, .04, 2.2 * v, brass, 'metal');
    for (const [cx, cz] of [[1.7 * u, 3.8 * v], [3.5 * u, 3.8 * v]]) {
      box(g, .75 * u, .38, .75 * v, cx, .22, cz, cognac);
      box(g, .75 * u, .45, .25 * v, cx, .60, cz + .35 * v, cognac);
      box(g, .20 * u, .32, .80 * v, cx - .40 * u, .50, cz, cognac);
      box(g, .20 * u, .32, .80 * v, cx + .40 * u, .50, cz, cognac);
      cylinder(g, .04 * s, .12, cx - .35 * u, .06, cz - .30 * v, brass, 'metal', .04 * s, 6);
      cylinder(g, .04 * s, .12, cx + .35 * u, .06, cz - .30 * v, brass, 'metal', .04 * s, 6);
    }
    box(g, 1.4 * u, .32, .85 * v, 2.6 * u, .18, 3.0 * v, charcoal);
    box(g, 1.5 * u, .05, .95 * v, 2.6 * u, .36, 3.0 * v, 0x171514);
    box(g, 1.38 * u, .02, .83 * v, 2.6 * u, .38, 3.0 * v, brass, 'metal');
    // Decanter and two crystal tumblers on the brass tray.
    cylinder(g, .07 * s, .18, 2.7 * u, .47, 3.0 * v, 0x9db2b8, 'glass', .04 * s, 8);
    cylinder(g, .03 * s, .08, 2.5 * u, .42, 3.1 * v, 0x9db2b8, 'glass', .03 * s, 6);
    cylinder(g, .03 * s, .08, 2.85 * u, .42, 3.1 * v, 0x9db2b8, 'glass', .03 * s, 6);

    // Cocktail bar, rear right: back bar with shelves and warm uplight.
    box(g, 2.6 * u, 2.1, .25 * v, 6.4 * u, 1.25, .35 * v, walnut);
    for (const y of [1.05, 1.50, 1.95]) box(g, 2.5 * u, .04, .28 * v, 6.4 * u, y, .35 * v, charcoal);
    box(g, 2.5 * u, .03, .03 * v, 6.4 * u, 1.53, .47 * v, brass, 'metal');
    box(g, 2.5 * u, .03, .03 * v, 6.4 * u, 1.98, .47 * v, brass, 'metal');
    light(g, 6.4 * u, 1.75, .60 * v, warm, .18);
    for (let i = 0; i < 5; i++) {
      const bx = (5.5 + i * .45) * u;
      cylinder(g, .04 * s, .22, bx, 1.63, .35 * v, 0x784422, 'glass', .03 * s, 8);
      cylinder(g, .04 * s, .22, bx, 2.08, .35 * v, 0x254030, 'glass', .03 * s, 8);
    }
    // Front counter with brass kickplate, and three stools.
    box(g, 2.4 * u, .95, .55 * v, 6.4 * u, .50, 1.35 * v, walnut);
    box(g, 2.55 * u, .08, .68 * v, 6.4 * u, .99, 1.35 * v, charcoal);
    box(g, 2.35 * u, .08, .04 * v, 6.4 * u, .10, 1.64 * v, brass, 'metal');
    for (let i = 0; i < 3; i++) {
      const sx = (5.6 + i * .8) * u;
      cylinder(g, .15 * s, .06, sx, .70, 1.9 * v, cognac, 'paint', .15 * s, 10);
      cylinder(g, .03 * s, .65, sx, .35, 1.9 * v, brass, 'metal', .03 * s, 6);
      cylinder(g, .18 * s, .03, sx, .03, 1.9 * v, brass, 'metal', .18 * s, 8);
    }

    // Work nook, front right: privacy booth, desk and a velvet high-back chair.
    box(g, .10 * u, 1.60, 1.6 * v, 5.2 * u, .90, 3.8 * v, charcoal);
    box(g, 1.6 * u, 1.60, .10 * v, 6.0 * u, .90, 4.6 * v, charcoal);
    box(g, 1.2 * u, .06, .65 * v, 6.0 * u, .74, 3.9 * v, walnut);
    box(g, .70 * u, .38, .65 * v, 6.0 * u, .22, 3.4 * v, navy);
    box(g, .70 * u, .55, .18 * v, 6.0 * u, .65, 3.15 * v, navy);
    light(g, 6.0 * u, 1.25, 3.9 * v, warm, .12);

    // Flight information board on a brass pylon.
    box(g, .16 * u, 2.4, .16 * v, 4.6 * u, 1.2, .50 * v, brass, 'metal');
    box(g, 1.4 * u, .85, .08 * v, 4.6 * u, 1.8, .50 * v, charcoal);
    box(g, 1.3 * u, .75, .02 * v, 4.6 * u, 1.8, .55 * v, 0x10151a);
    light(g, 4.6 * u, 1.8, .60 * v, screenGlow, .14);
    label(g, 'DEPARTURES', 4.6 * u, 2.10, .57 * v, .1, '#d4af37', {width: 5});
    label(g, 'LONDON  14:20  ON TIME', 4.6 * u, 1.95, .57 * v, .07, '#9fd4de', {width: 10});
    label(g, 'TOKYO   14:45  BOARDING', 4.6 * u, 1.80, .57 * v, .07, '#d4af37', {width: 10});
    label(g, 'PARIS   15:10  GATE 12', 4.6 * u, 1.65, .57 * v, .07, '#9fd4de', {width: 10});

    // Walnut ceiling beams and brass pendants over the salon and bar.
    box(g, 5.80 * u, .10, .22 * v, 4.00 * u, 2.88, 1.70 * v, walnut).userData.roof = true;
    box(g, 5.80 * u, .10, .22 * v, 4.00 * u, 2.88, 3.50 * v, walnut).userData.roof = true;
    for (const [lx, lz] of [[2.6, 3.0], [6.4, 1.35], [2.6, 1.8]]) {
      cylinder(g, .015 * s, .30, lx * u, 2.70, lz * v, charcoal, 'paint', .015 * s, 6);
      cylinder(g, .07 * s, .14, lx * u, 2.52, lz * v, brass, 'metal', .18 * s, 10);
      light(g, lx * u, 2.44, lz * v, warm, .12);
    }
  }

  /** A standing employee in uniform, about 1.75 m tall, facing +z. */
  function staffMember(g, x, z, shirt, {skin = 0xe0ac7e, hair = 0x2e2420, cap = false} = {}) {
    const trousers = 0x1f2a30;
    for (const side of [-1, 1]) {
      box(g, .13, .82, .16, x + side * .09, .43, z, trousers);
      box(g, .14, .06, .24, x + side * .09, .03, z + .03, 0x15191b);
    }
    box(g, .40, .58, .24, x, 1.13, z, shirt);
    box(g, .42, .06, .26, x, .86, z, trousers);
    for (const side of [-1, 1]) {
      box(g, .10, .52, .12, x + side * .26, 1.12, z + .02, shirt);
      box(g, .09, .09, .10, x + side * .26, .83, z + .04, skin);
    }
    box(g, .16, .10, .02, x - .09, 1.26, z + .125, 0xf9fcf6);
    box(g, .08, .06, .03, x + .1, 1.30, z + .125, 0xf2c230);
    box(g, .09, .07, .09, x, 1.45, z, skin);
    sphere(g, x, 1.60, z + .01, .12, .14, .12, skin);
    sphere(g, x, 1.66, z - .01, .125, .09, .125, hair);
    if (cap) {
      cylinder(g, .13, .06, x, 1.73, z, shirt, 'paint', .13, 10);
      box(g, .16, .02, .10, x, 1.71, z + .12, shirt);
    }
  }

  function checkInCounter(g, w, d) {
    const u = w / 6, v = d / 5, x = w / 2, s = Math.min(u, v);
    const body = 0xd8d3c6, top = 0x3b4347, struct = 0x555e62, metal = 0x8b9295;
    const teal = 0x2a6d7a, dpanel = 0x1b2e36, glow = 0x7fe0e8, belt = 0x343b3e;
    const beltTop = 0x454d50, post = 0x737b7e, yellow = 0xf2c230;

    // Passenger approaches from +z (front). Staff stand behind at -z.
    box(g, 5.8 * u, .02, 4.8 * v, x, .01, 2.5 * v, 0x2b3033);
    box(g, 2.2 * u, .02, 1.9 * v, 2.15 * u, .02, 2.7 * v, 0x323a3d);

    // Staff back wall and the illuminated sign gantry above 2 m.
    box(g, 5.6 * u, 2.15, .16 * v, x, 1.075, .30 * v, body);
    box(g, 5.6 * u, .10, .20 * v, x, 2.18, .30 * v, struct);
    box(g, 3.0 * u, .62, .14 * v, 2.0 * u, 2.62, .42 * v, dpanel);
    box(g, 3.06 * u, .05, .18 * v, 2.0 * u, 2.955, .42 * v, struct).userData.roof = true;
    box(g, 2.8 * u, .42, .03 * v, 2.0 * u, 2.62, .50 * v, teal);
    // label() sizes are the text height in metres.
    label(g, 'CHECK-IN', 2.0 * u, 2.70, .52 * v, .2, '#f9fcf6', {width: 4});
    label(g, 'ZONE A  DESK 3', 2.0 * u, 2.50, .52 * v, .1, '#7fe0e8', {width: 6});
    light(g, 2.0 * u, 2.62, .55 * v, glow, .16);
    // Flight strip on the back wall.
    box(g, 1.5 * u, .5, .03 * v, 4.55 * u, 1.65, .40 * v, dpanel);
    label(g, 'FLT 228  14:35', 4.55 * u, 1.75, .42 * v, .1, '#7fe0e8', {width: 6});
    label(g, 'BOARDING SOON', 4.55 * u, 1.58, .42 * v, .08, '#e5e0d5', {width: 6});
    light(g, 4.55 * u, 1.65, .44 * v, glow, .10);

    // Main staffed counter: base, teal front, dark worktop, metal trim.
    box(g, 3.5 * u, .90, .95 * v, 2.0 * u, .45, 1.55 * v, body);
    box(g, 3.5 * u, .55, .06 * v, 2.0 * u, .30, 2.02 * v, teal);
    box(g, 3.6 * u, .10, 1.02 * v, 2.0 * u, .95, 1.55 * v, top);
    box(g, 3.6 * u, .03, 1.04 * v, 2.0 * u, 1.015, 1.55 * v, metal, 'metal');
    box(g, .10 * u, .90, .95 * v, .30 * u, .45, 1.55 * v, struct);
    // Lower accessible section on the left end.
    box(g, 1.0 * u, .72, .85 * v, .85 * u, .36, 1.58 * v, body);
    box(g, 1.0 * u, .08, .92 * v, .85 * u, .76, 1.58 * v, top);
    box(g, 1.0 * u, .03, .94 * v, .85 * u, .795, 1.58 * v, metal, 'metal');

    // Staff workstations: monitors face the employees at the back.
    box(g, .55 * u, .34, .04 * v, 2.35 * u, 1.30, 1.28 * v, dpanel).rotation.y = Math.PI;
    box(g, .06 * u, .22, .06 * v, 2.35 * u, 1.12, 1.28 * v, struct);
    light(g, 2.35 * u, 1.30, 1.22 * v, glow, .09);
    box(g, .34 * u, .24, .04 * v, 3.1 * u, 1.24, 1.30 * v, dpanel);
    light(g, 3.1 * u, 1.24, 1.24 * v, glow, .06);
    box(g, .5 * u, .03, .24 * v, 2.4 * u, 1.02, 1.42 * v, struct);
    box(g, .3 * u, .16, .26 * v, 1.55 * u, 1.09, 1.40 * v, metal, 'metal');
    box(g, .24 * u, .02, .14 * v, 1.55 * u, 1.18, 1.40 * v, teal);
    cylinder(g, .16 * s, .06, 3.2 * u, .5, .72 * v, dpanel, 'paint', .16 * s, 10);
    cylinder(g, .04 * s, .5, 3.2 * u, .25, .72 * v, metal, 'metal', .04 * s, 8);

    // The employees: an agent at the main screen, a colleague at the tag printer.
    staffMember(g, 2.3 * u, .78 * v, teal, {cap: true});
    staffMember(g, 1.2 * u, .78 * v, 0x3f6fb5, {skin: 0x8d5a3b, hair: 0x15110e});

    // Baggage acceptance: weigh platform and a short belt behind the scenes.
    box(g, 1.15 * u, .14, 1.0 * v, 4.55 * u, .07, 1.75 * v, metal, 'metal');
    box(g, 1.0 * u, .03, .85 * v, 4.55 * u, .155, 1.75 * v, beltTop);
    box(g, .34 * u, .20, .06 * v, 4.55 * u, .30, 2.24 * v, dpanel);
    label(g, '23.0 kg', 4.55 * u, .33, 2.28 * v, .07, '#7fe0e8', {width: 3});
    light(g, 4.55 * u, .30, 2.27 * v, glow, .05);
    box(g, 1.2 * u, .44, 1.55 * v, 4.55 * u, .22, .95 * v, belt);
    box(g, 1.05 * u, .05, 1.5 * v, 4.55 * u, .47, .95 * v, beltTop);
    for (let i = 0; i < 4; i++) box(g, 1.05 * u, .02, .05 * v, 4.55 * u, .50, (.35 + i * .4) * v, belt);
    box(g, .06 * u, .30, 1.55 * v, 4.0 * u, .62, .95 * v, yellow);
    box(g, .06 * u, .30, 1.55 * v, 5.1 * u, .62, .95 * v, yellow);
    box(g, .5 * u, .34, .4 * v, 4.55 * u, .66, 1.0 * v, 0x8d3f3a);
    box(g, .5 * u, .03, .4 * v, 4.55 * u, .84, 1.0 * v, 0x6e302c);
    box(g, .46 * u, .34, .42 * v, 4.55 * u, .31, 2.7 * v, 0x33566b);
    box(g, .10 * u, .05, .16 * v, 4.55 * u, .51, 2.7 * v, metal, 'metal');

    // Passenger queue at the front: posts with round bases and teal belts.
    const posts = [[1.05, 4.55], [2.35, 4.55], [3.55, 4.55], [1.05, 3.35], [3.55, 3.35], [1.05, 2.55], [2.35, 2.55]];
    for (const [pxu, pzv] of posts) {
      const px = pxu * u, pz = pzv * v;
      cylinder(g, .20 * s, .05, px, .025, pz, metal, 'metal', .22 * s, 10);
      cylinder(g, .05 * s, .95, px, .50, pz, post, 'metal', .05 * s, 8);
      cylinder(g, .08 * s, .06, px, .98, pz, post, 'metal', .08 * s, 8);
    }
    const link = (a, b) => line(g, a[0] * u, a[1] * v, b[0] * u, b[1] * v, .03 * v, teal, .80, 'paint', .05);
    for (const [a, b] of [[0, 1], [1, 2], [0, 3], [3, 5], [5, 6], [2, 4]]) link(posts[a], posts[b]);
    for (let i = 0; i < 3; i++) box(g, .4 * u, .012, .10 * v, 2.0 * u, .02, (3.9 - i * .6) * v, yellow);
    label(g, 'QUEUE HERE', 2.3 * u, .035, 4.75 * v, .22, '#f2c230', {ground: true, width: 5});
  }

  function checkoutCounter(g, w, d) {
    const u = w / 5, v = d / 4, x = w / 2, s = Math.min(u, v);
    const body = 0xd8d3c6, top = 0x3b4347, teal = 0x2a6d7a, struct = 0x555e62;
    const metal = 0x8b9295, pos = 0x343b3e, glow = 0x7fe0e8, term = 0x454d50;
    const postC = 0x737b7e, merch = [0xb4553f, 0x3f5e78, 0xc9a86a, 0x7a8f6b];

    // Customer approaches from +z. The cashier stands behind at -z.
    box(g, 4.8 * u, .02, 3.8 * v, x, .01, 2 * v, 0x2c3134);
    box(g, 2.4 * u, .02, 1.7 * v, 1.9 * u, .02, 2.85 * v, 0x343a3d);

    // Low back storage and bag wall: retail, not a check-in gantry.
    box(g, 4.6 * u, 1.55, .14 * v, x, .775, .22 * v, body);
    box(g, 4.4 * u, .08, .16 * v, x, 1.58, .22 * v, struct);
    box(g, 1.4 * u, .55, .12 * v, 3.7 * u, .90, .32 * v, teal);
    for (let i = 0; i < 3; i++) box(g, .32 * u, .18, .18 * v, (3.3 + i * .4) * u, 1.28, .34 * v, merch[i]);

    // Overhead checkout blade; its cap sits just above 2 m.
    box(g, .08 * u, 1.05, .08 * v, 2.4 * u, 1.85, 1.15 * v, metal, 'metal');
    box(g, 1.7 * u, .42, .10 * v, 2.4 * u, 2.28, 1.15 * v, pos);
    box(g, 1.76 * u, .05, .14 * v, 2.4 * u, 2.515, 1.15 * v, struct).userData.roof = true;
    box(g, 1.5 * u, .28, .03 * v, 2.4 * u, 2.30, 1.21 * v, teal);
    // label() sizes are the text height in metres.
    label(g, 'CHECKOUT', 2.4 * u, 2.35, 1.24 * v, .14, '#f9fcf6', {width: 4});
    label(g, 'PAY HERE', 2.4 * u, 2.20, 1.24 * v, .08, '#7fe0e8', {width: 4});
    light(g, 2.4 * u, 2.30, 1.26 * v, glow, .10);

    // Layered cashier counter: base, teal fascia, dark top, metal lip.
    box(g, 2.55 * u, .88, .82 * v, 1.75 * u, .44, 1.45 * v, body);
    box(g, 2.55 * u, .48, .06 * v, 1.75 * u, .28, 1.85 * v, teal);
    box(g, 2.65 * u, .09, .88 * v, 1.75 * u, .925, 1.45 * v, top);
    box(g, 2.65 * u, .03, .90 * v, 1.75 * u, .985, 1.45 * v, metal, 'metal');
    box(g, .10 * u, .88, .82 * v, .52 * u, .44, 1.45 * v, struct);
    box(g, .85 * u, .68, .70 * v, .95 * u, .34, 1.50 * v, body);
    box(g, .85 * u, .07, .76 * v, .95 * u, .715, 1.50 * v, top);

    // Bagging well on the right of the till.
    box(g, 1.15 * u, .55, .78 * v, 3.55 * u, .275, 1.48 * v, struct);
    box(g, 1.20 * u, .05, .84 * v, 3.55 * u, .575, 1.48 * v, top);
    box(g, .08 * u, .42, .08 * v, 4.05 * u, .36, 1.78 * v, metal, 'metal');
    box(g, .28 * u, .38, .08 * v, 4.05 * u, .42, 1.72 * v, 0x3f5e78);
    box(g, .32 * u, .10, .24 * v, 3.35 * u, .64, 1.48 * v, 0xb4553f);
    box(g, .26 * u, .16, .20 * v, 3.70 * u, .67, 1.38 * v, 0xc9a86a);

    // Staff till: the monitor faces the cashier.
    box(g, .48 * u, .32, .04 * v, 2.05 * u, 1.26, 1.22 * v, 0x1b2e36).rotation.y = Math.PI;
    box(g, .06 * u, .20, .06 * v, 2.05 * u, 1.08, 1.22 * v, struct);
    light(g, 2.05 * u, 1.26, 1.16 * v, glow, .08);
    box(g, .46 * u, .03, .22 * v, 2.05 * u, 1.01, 1.38 * v, struct);
    box(g, .34 * u, .12, .28 * v, 1.45 * u, 1.04, 1.32 * v, pos);
    box(g, .22 * u, .14, .18 * v, 2.55 * u, 1.07, 1.30 * v, metal, 'metal');

    // Customer-facing card terminal on the front lip.
    box(g, .18 * u, .16, .12 * v, 1.55 * u, 1.08, 1.86 * v, term);
    box(g, .14 * u, .10, .02 * v, 1.55 * u, 1.12, 1.925 * v, 0x1b2e36);
    light(g, 1.55 * u, 1.12, 1.90 * v, glow, .04);

    // The cashier, with a spare stool beside the till.
    staffMember(g, 2.62 * u, .70 * v, teal, {skin: 0xf1c9a5, hair: 0x6b4a2f});
    cylinder(g, .15 * s, .05, 1.35 * u, .48, .68 * v, pos, 'paint', .15 * s, 10);
    cylinder(g, .035 * s, .46, 1.35 * u, .23, .68 * v, metal, 'metal', .035 * s, 8);

    // Compact impulse rack beside the queue: snacks, not a whole store.
    box(g, .42 * u, 1.15, .38 * v, 4.45 * u, .575, 2.55 * v, body);
    for (const y of [.32, .70, 1.08]) box(g, .46 * u, .05, .42 * v, 4.45 * u, y, 2.55 * v, struct);
    for (let i = 0; i < 3; i++) box(g, .28 * u, .16, .16 * v, 4.45 * u, .42 + i * .38, 2.55 * v, merch[(i + 1) % 4]);

    // Short one-turn queue; entrance at the front right.
    const posts = [[.85, 3.55], [2.15, 3.55], [3.45, 3.55], [.85, 2.55], [3.45, 2.55], [.85, 2.10], [2.05, 2.10]];
    for (const [pxu, pzv] of posts) {
      const px = pxu * u, pz = pzv * v;
      cylinder(g, .16 * s, .04, px, .02, pz, metal, 'metal', .18 * s, 10);
      cylinder(g, .045 * s, .88, px, .46, pz, postC, 'metal', .045 * s, 8);
    }
    const link = (a, b) => line(g, a[0] * u, a[1] * v, b[0] * u, b[1] * v, .028 * v, teal, .72, 'paint', .04);
    for (const [a, b] of [[0, 1], [1, 2], [0, 3], [3, 5], [5, 6], [2, 4]]) link(posts[a], posts[b]);
    box(g, .32 * u, .012, .08 * v, 2.05 * u, .02, 3.15 * v, teal);
    box(g, .32 * u, .012, .08 * v, 2.05 * u, .02, 2.55 * v, teal);
    label(g, 'QUEUE', 2.15 * u, .035, 3.72 * v, .2, '#e5e0d5', {ground: true, width: 3});
  }

  function dutyFreeFoodDrinks(g, w, d) {
    const u = w / 10, v = d / 8, x = w / 2;
    const shell = 0xe5e0d5, wall = 0xd8d3c6, shelfM = 0x8b9295, dark = 0x3b4347;
    const wood = 0x8a6748, teal = 0x2a6d7a, frame = 0x555e62, fridgeIn = 0xe8f3f3;
    const warm = 0xffe2a8, cold = 0xbfe9ef, panel = 0x1b2e36;
    const s = Math.min(u, v);
    const prod = [0xd94c4c, 0xe6a23c, 0xe2c84b, 0x4f8b58, 0x4776a8, 0x6b5a9c, 0xd9829b, 0x8a6748, 0xe8e3d6];

    // Shell: floor, back and side walls, storefront pillars, fascia, sign.
    box(g, 9.9 * u, .04, 7.9 * v, x, .02, 4 * v, wall);
    box(g, 9.9 * u, 3.0, .14 * v, x, 1.5, .12 * v, shell);
    box(g, .14 * u, 3.0, 7.9 * v, .12 * u, 1.5, 4 * v, wall);
    box(g, .14 * u, 3.0, 7.9 * v, w - .12 * u, 1.5, 4 * v, wall);
    box(g, .5 * u, 3.10, .5 * v, .32 * u, 1.55, 7.70 * v, shell);
    box(g, .5 * u, 3.10, .5 * v, w - .32 * u, 1.55, 7.70 * v, shell);
    box(g, 9.9 * u, .65, .45 * v, x, 2.775, 7.72 * v, shell);
    box(g, 9.9 * u, .05, .54 * v, x, 3.12, 7.72 * v, teal).userData.roof = true;
    box(g, 3.6 * u, .44, .05 * v, x, 2.80, 7.945 * v, panel);
    // label() sizes are the text height in metres.
    label(g, 'DUTY FREE', x, 2.90, 7.985 * v, .22, '#f9fcf6', {width: 4.5});
    label(g, 'FOOD & DRINK', x, 2.67, 7.985 * v, .1, '#7fe0e8', {width: 6});
    light(g, 1.5 * u, 2.80, 7.88 * v, warm, .16);
    light(g, w - 1.5 * u, 2.80, 7.88 * v, warm, .16);
    // 'glass' renders opaque here, so the shopfront is drawn as its frame.
    for (const px of [1.70 * u, w - 1.70 * u]) {
      box(g, 2.3 * u, .05, .06 * v, px, 2.40, 7.86 * v, shelfM, 'metal');
      for (const dx of [-1.13, 0, 1.13]) box(g, .05 * u, 2.0, .06 * v, px + dx * u, 1.42, 7.86 * v, shelfM, 'metal');
      box(g, 2.3 * u, .42, .20 * v, px, .23, 7.86 * v, dark);
    }
    box(g, 4.0 * u, .03, .5 * v, x, .03, 7.55 * v, teal);

    // Back-wall confectionery shelving, tied into the wall with grounded ends.
    box(g, 4.5 * u, .15, .45 * v, 3.0 * u, .075, .40 * v, dark);
    box(g, .08 * u, 1.80, .42 * v, .79 * u, .90, .40 * v, shelfM, 'metal');
    box(g, .08 * u, 1.80, .42 * v, 5.21 * u, .90, .40 * v, shelfM, 'metal');
    for (const yy of [.55, 1.05, 1.55]) box(g, 4.5 * u, .06, .40 * v, 3.0 * u, yy, .38 * v, shelfM, 'metal');
    for (let i = 0; i < 12; i++) {
      const lvl = i % 3, col = (i * 2) % 8, yy = [.55, 1.05, 1.55][lvl];
      const bw = (.32 + ((i * 7) % 3) * .07) * u, bh = .22 + ((i * 5) % 2) * .08;
      box(g, bw, bh, .24 * v, (1.05 + (i >> 2) * .85) * u, yy + .03 + bh / 2 - .01, .38 * v, prod[(col + i % 3) % 9]);
    }

    // Left-wall snack shelving.
    box(g, .45 * u, .15, 3.0 * v, .40 * u, .075, 2.60 * v, dark);
    box(g, .42 * u, 1.70, .08 * v, .40 * u, .85, 1.14 * v, shelfM, 'metal');
    box(g, .42 * u, 1.70, .08 * v, .40 * u, .85, 4.06 * v, shelfM, 'metal');
    for (const yy of [.60, 1.10, 1.55]) box(g, .40 * u, .06, 3.0 * v, .38 * u, yy, 2.60 * v, shelfM, 'metal');
    for (let i = 0; i < 8; i++) {
      const yy = [.60, 1.10][i % 2] + (i > 5 ? .45 : 0);
      const bh = .22 + ((i * 3) % 2) * .07;
      box(g, .24 * u, bh, .42 * v, .38 * u, yy + .03 + bh / 2 - .01, (1.55 + (i >> 1) * .68) * v, prod[(i * 3 + 1) % 9]);
    }

    // Refrigerated drinks wall on the right: cabinet, cold interior, doors.
    box(g, .10 * u, 2.10, 3.0 * v, 9.65 * u, 1.05, 2.50 * v, frame);
    box(g, .80 * u, .15, 3.0 * v, 9.30 * u, .075, 2.50 * v, dark);
    box(g, .80 * u, .30, 3.0 * v, 9.30 * u, 2.10, 2.50 * v, frame);
    box(g, .80 * u, 2.10, .08 * v, 9.30 * u, 1.05, 1.04 * v, frame);
    box(g, .80 * u, 2.10, .08 * v, 9.30 * u, 1.05, 3.96 * v, frame);
    box(g, .06 * u, 1.70, 2.80 * v, 9.585 * u, 1.05, 2.50 * v, fridgeIn);
    for (const yy of [.90, 1.40]) box(g, .50 * u, .04, 2.80 * v, 9.35 * u, yy, 2.50 * v, shelfM, 'metal');
    for (const mz of [2.0 * v, 3.0 * v]) box(g, .08 * u, 1.70, .06 * v, 9.05 * u, 1.05, mz, frame);
    // Door mullions instead of panes: the game's glass would hide the stock.
    for (const dz of [1.50 * v, 2.50 * v, 3.50 * v]) {
      for (const y of [.22, 1.88]) box(g, .04 * u, .05, .92 * v, 9.04 * u, y, dz, shelfM, 'metal');
    }
    for (let i = 0; i < 9; i++) {
      const door = i % 3, lvl = (i / 3) | 0;
      const yy = [.30, .93, 1.43][lvl], zz = (1.50 + door) * v;
      if (lvl < 2) box(g, .30 * u, .22, .30 * v, 9.35 * u, yy + .22 / 2, zz, prod[(i * 2 + 4) % 9]);
      else cylinder(g, .09 * s, .24, 9.35 * u, yy + .12, zz, prod[(i * 2 + 4) % 9], 'paint', .09 * s, 8);
    }
    box(g, .06 * u, .40, 2.20 * v, 8.88 * u, 2.02, 2.50 * v, panel);
    label(g, 'DRINKS', 8.84 * u, 2.05, 2.50 * v, .12, '#bfe9ef', {rotY: -Math.PI / 2, width: 3});
    light(g, 9.30 * u, 1.80, 2.50 * v, cold, .18);

    // Stepped central promo island with stacked confectionery.
    box(g, 1.90 * u, .42, 1.50 * v, 6.90 * u, .21, 5.30 * v, wood);
    box(g, 1.50 * u, .30, 1.10 * v, 6.90 * u, .57, 5.30 * v, dark);
    box(g, 1.54 * u, .05, 1.14 * v, 6.90 * u, .745, 5.30 * v, wood);
    for (let i = 0; i < 8; i++) {
      const colr = prod[(i * 3 + 2) % 9], xx = (6.45 + (i % 4) * .30) * u, zz = (5.05 + ((i / 4) | 0) * .50) * v;
      if (i < 4) box(g, .24 * u, .20, .30 * v, xx, .85, zz, colr);
      else box(g, .24 * u, .16, .30 * v, xx, .72 + .16 / 2 + .20 - .01, zz, colr);
    }

    // Two double-sided gondola aisles, ends grounded, shelves lapped in.
    for (const [gx, gz] of [[3.40, 3.10], [3.40, 5.00]]) {
      box(g, 3.0 * u, .14, .90 * v, gx * u, .07, gz * v, dark);
      box(g, .08 * u, 1.30, .90 * v, (gx - 1.50) * u, .65, gz * v, wood);
      box(g, .08 * u, 1.30, .90 * v, (gx + 1.50) * u, .65, gz * v, wood);
      for (const yy of [.60, 1.05]) {
        box(g, 3.0 * u, .05, .36 * v, gx * u, yy, (gz - .26) * v, shelfM, 'metal');
        box(g, 3.0 * u, .05, .36 * v, gx * u, yy, (gz + .26) * v, shelfM, 'metal');
      }
      for (let i = 0; i < 12; i++) {
        const side = i % 2 ? .26 : -.26, lvl = (i >> 1) % 2 ? 1.05 : .60;
        const bh = .20 + ((i * 3) % 3) * .05;
        box(g, .30 * u, bh, .24 * v, (gx - 1.15 + (i >> 2) * .55) * u, lvl + .025 + bh / 2 - .01, (gz + side) * v, prod[(i * 2 + Math.round(gz)) % 9]);
      }
    }

    // Promotional endcaps facing the main aisle.
    box(g, .70 * u, .50, .50 * v, 5.15 * u, .25, 3.10 * v, wood);
    box(g, .70 * u, .50, .50 * v, 5.15 * u, .25, 5.00 * v, wood);
    box(g, .34 * u, .24, .30 * v, 5.15 * u, .62, 3.10 * v, prod[0]);
    box(g, .30 * u, .20, .28 * v, 5.15 * u, .60, 5.00 * v, prod[1]);

    // Low entrance promo tables with drink stacks.
    box(g, 1.10 * u, .40, .70 * v, 2.0 * u, .20, 6.70 * v, wood);
    box(g, 1.10 * u, .40, .70 * v, 8.0 * u, .20, 6.70 * v, wood);
    for (let i = 0; i < 4; i++) {
      cylinder(g, .10 * s, .26, (1.75 + (i % 2) * .45) * u, .53, 6.70 * v, prod[(i * 2) % 9], 'paint', .10 * s, 8);
      box(g, .30 * u, .22, .30 * v, (7.85 + (i % 2) * .35) * u, .51, 6.70 * v, prod[(i * 2 + 3) % 9]);
    }

    // Category signage on the shelf ends, plus a checkout hint.
    box(g, .50 * u, .30, .06 * v, 1.95 * u, 1.95, 3.10 * v, panel);
    label(g, 'SNACKS', 1.95 * u, 1.97, 3.14 * v, .1, '#ffe2a8', {width: 3});
    box(g, .50 * u, .30, .06 * v, 1.95 * u, 1.95, 5.00 * v, panel);
    label(g, 'SWEETS', 1.95 * u, 1.97, 5.04 * v, .1, '#ffe2a8', {width: 3});
    box(g, 1.10 * u, .30, .06 * v, 8.0 * u, 2.02, .62 * v, panel);
    label(g, 'CHECKOUT ->', 8.0 * u, 2.04, .66 * v, .09, '#7fe0e8', {width: 4.5});

    // Ceiling beams wall to wall, with pendants hung from them.
    for (const bz of [2.0 * v, 5.0 * v]) box(g, 9.6 * u, .10, .22 * v, x, 2.93, bz, shell).userData.roof = true;
    for (const [lx, lz] of [[3.4, 3.1], [3.4, 5.0], [6.9, 5.3], [9.3, 2.5]]) {
      cylinder(g, .015 * s, .30, lx * u, 2.70, lz * v, dark, 'paint', .015 * s, 6);
      cylinder(g, .07 * s, .12, lx * u, 2.50, lz * v, wood, 'paint', .16 * s, 10);
      light(g, lx * u, 2.42, lz * v, lx > 8 ? cold : warm, .11);
    }
    // A shop assistant restocking the drinks wall.
    staffMember(g, 8.4 * u, 3.9 * v, teal, {skin: 0xc68b5e, hair: 0x241c17});
  }

  function perfumeCornerShop(g, w, d) {
    const u = w / 8, v = d / 7, x = w / 2, s = Math.min(u, v);
    const ivory = 0xeee8dc, grey = 0xd8d3c6, dark = 0x292d30, base = 0x45484a;
    const trim = 0x9b9b96, brass = 0xc4a261, wood = 0x86654d;
    const blush = 0xc89da0, purple = 0x78677e;
    const warm = 0xffdda6, cool = 0xd8f0ef, glassC = 0xcfe0e2;
    const bottles = [0xd6b46c, 0xc58f9c, 0x8ca9a4, 0x87789a, 0x6e8ba0, 0xe3d8c4];

    function bottle(px, py, pz, bw, bh, col) {
      box(g, bw, bh, bw * .9, px, py + bh / 2, pz, col);
      box(g, bw * .34, bh * .26, bw * .3, px, py + bh + bh * .13, pz, dark);
    }
    function flask(px, py, pz, r, h, col) {
      cylinder(g, r, h, px, py + h / 2, pz, col, 'paint', r, 8);
      cylinder(g, r * .42, h * .24, px, py + h + h * .12, pz, brass, 'paint', r * .42, 8);
    }

    // Floor, blush runner and violet carpet guiding the corner entrance in.
    box(g, 7.9 * u, .04, 6.9 * v, x, .02, 3.5 * v, grey);
    box(g, 1.6 * u, .02, 2.6 * v, 6.2 * u, .045, 5.2 * v, blush);
    box(g, 2.8 * u, .02, 1.1 * v, 3.9 * u, .05, 6.15 * v, purple);

    // Closed backs: north and west walls with wood wainscot.
    box(g, 7.9 * u, 3.0, .14 * v, x, 1.5, .12 * v, ivory);
    box(g, .14 * u, 3.0, 6.9 * v, .12 * u, 1.5, 3.5 * v, grey);
    box(g, 7.6 * u, .9, .06 * v, x, .45, .21 * v, wood);
    box(g, .06 * u, .9, 6.6 * v, .21 * u, .45, 3.5 * v, wood);

    // Storefront pillars; the south-east corner is deliberately left open.
    for (const pxx of [.32, 2.8, 4.95]) box(g, .5 * u, 3.1, .5 * v, pxx * u, 1.55, d - .30 * v, ivory);
    for (const pzz of [.32, 2.7, 4.3]) box(g, .5 * u, 3.1, .5 * v, w - .30 * u, 1.55, pzz * v, ivory);

    // Shopfront bays. 'glass' renders opaque here, so each bay is a frame.
    for (const [bx, bw] of [[1.56, 1.9], [3.88, 1.5]]) {
      box(g, bw * u, .42, .20 * v, bx * u, .21, d - .14 * v, dark);
      for (const dx of [-.5, .5]) box(g, .05 * u, 2.0, .06 * v, (bx + dx * bw) * u, 1.42, d - .14 * v, trim, 'metal');
      box(g, bw * u, .05, .08 * v, bx * u, 2.435, d - .14 * v, trim, 'metal');
    }
    for (const [bz, bd] of [[1.5, 1.7], [3.5, 1.0]]) {
      box(g, .20 * u, .42, bd * v, w - .14 * u, .21, bz * v, dark);
      for (const dz of [-.5, .5]) box(g, .06 * u, 2.0, .05 * v, w - .14 * u, 1.42, (bz + dz * bd) * v, trim, 'metal');
      box(g, .08 * u, .05, bd * v, w - .14 * u, 2.435, bz * v, trim, 'metal');
    }

    // Dressed window vignettes: ivory plinths with hero flacons.
    box(g, .9 * u, .50, .5 * v, 1.56 * u, .25, 6.20 * v, ivory);
    flask(1.56 * u, .5, 6.20 * v, .12 * s, .38, bottles[2]);
    box(g, .9 * u, .50, .5 * v, 3.88 * u, .25, 6.20 * v, ivory);
    flask(3.88 * u, .5, 6.20 * v, .12 * s, .38, bottles[5]);

    // Wraparound fascia, brass reveals, corner cap lid.
    box(g, 7.4 * u, .65, .45 * v, 3.7 * u, 2.775, d - .28 * v, ivory);
    box(g, .45 * u, .65, 6.4 * v, w - .28 * u, 2.775, 3.2 * v, ivory);
    box(g, 7.4 * u, .06, .06 * v, 3.7 * u, 2.44, d - .07 * v, brass, 'metal');
    box(g, .06 * u, .06, 6.4 * v, w - .07 * u, 2.44, 3.2 * v, brass, 'metal');
    box(g, .66 * u, .08, .66 * v, w - .38 * u, 3.12, d - .38 * v, brass, 'metal').userData.roof = true;

    // Fascia signs on both open sides, plus the corner blade.
    // label() sizes are the text height in metres.
    box(g, 3.2 * u, .44, .05 * v, 4.0 * u, 2.80, d - .10 * v, dark);
    label(g, 'MAISON LUEUR', 4.0 * u, 2.89, d - .065 * v, .19, '#f9fcf6', {width: 5});
    label(g, 'PARFUMS', 4.0 * u, 2.68, d - .065 * v, .09, '#c4a261', {width: 3.5});
    light(g, 4.0 * u, 2.45, d - .10 * v, warm, .12);
    box(g, .05 * u, .44, 3.2 * v, w - .10 * u, 2.80, 2.4 * v, dark);
    label(g, 'MAISON LUEUR', w - .065 * u, 2.89, 2.4 * v, .19, '#f9fcf6', {rotY: Math.PI / 2, width: 5});
    label(g, 'PARFUMS', w - .065 * u, 2.68, 2.4 * v, .09, '#c4a261', {rotY: Math.PI / 2, width: 3.5});
    light(g, w - .10 * u, 2.45, 2.4 * v, warm, .12);
    box(g, .45 * u, .60, .45 * v, w - .62 * u, 2.55, d - .62 * v, dark);
    label(g, 'LUEUR', w - .62 * u, 2.58, d - .385 * v, .13, '#c4a261', {width: 3});
    label(g, 'LUEUR', w - .385 * u, 2.58, d - .62 * v, .13, '#c4a261', {rotY: Math.PI / 2, width: 3});

    // North wall illuminated displays with curated bottle rows.
    for (const dxx of [2.6, 5.4]) {
      const seed = Math.round(dxx);
      box(g, 2.2 * u, 2.0, .14 * v, dxx * u, 1.2, .27 * v, dark);
      box(g, 2.2 * u, .06, .12 * v, dxx * u, 2.23, .30 * v, brass, 'metal');
      for (const yy of [.95, 1.45]) box(g, 2.0 * u, .05, .30 * v, dxx * u, yy, .50 * v, trim, 'metal');
      for (let i = 0; i < 3; i++) {
        bottle((dxx - .6 + i * .6) * u, .975, .50 * v, .20 * u, .30, bottles[(i * 2 + seed) % 6]);
        flask((dxx - .6 + i * .6) * u, 1.475, .50 * v, .09 * s, .26, bottles[(i * 2 + seed + 3) % 6]);
      }
      label(g, dxx < 4 ? 'EAU DE PARFUM' : 'EXCLUSIFS', dxx * u, 2.06, .345 * v, .09, '#c4a261', {width: 5});
      light(g, dxx * u, 2.0, .75 * v, warm, .16);
    }

    // West wall display with a bronze mirror.
    box(g, .14 * u, 2.0, 2.6 * v, .27 * u, 1.2, 3.6 * v, dark);
    for (const yy of [.95, 1.45]) box(g, .30 * u, .05, 2.4 * v, .50 * u, yy, 3.6 * v, trim, 'metal');
    for (let i = 0; i < 3; i++) {
      bottle(.50 * u, .975, (2.8 + i * .8) * v, .20 * u, .30, bottles[(i * 2 + 1) % 6]);
      flask(.50 * u, 1.475, (2.8 + i * .8) * v, .09 * s, .26, bottles[(i * 2 + 4) % 6]);
    }
    box(g, .06 * u, 1.6, .90 * v, .23 * u, 1.4, 5.6 * v, wood);
    box(g, .04 * u, 1.5, .80 * v, .27 * u, 1.4, 5.6 * v, glassC, 'glass');
    light(g, .75 * u, 2.0, 3.6 * v, warm, .16);

    // Central fragrance island: stepped drums, hero bottles, cool glow.
    cylinder(g, .95 * s, .50, 4.3 * u, .25, 3.9 * v, dark, 'paint', .95 * s, 12);
    cylinder(g, .98 * s, .06, 4.3 * u, .53, 3.9 * v, brass, 'metal', .98 * s, 12);
    cylinder(g, .80 * s, .55, 4.3 * u, .83, 3.9 * v, glassC, 'glass', .80 * s, 12);
    cylinder(g, .85 * s, .06, 4.3 * u, 1.13, 3.9 * v, ivory, 'paint', .85 * s, 12);
    for (let i = 0; i < 5; i++) {
      const a = i * Math.PI * 2 / 5 + .4;
      bottle(4.3 * u + Math.cos(a) * .45 * s, 1.16, 3.9 * v + Math.sin(a) * .45 * s, .17 * u, .26, bottles[i % 6]);
    }
    flask(4.3 * u, 1.16, 3.9 * v, .14 * s, .44, bottles[0]);
    light(g, 4.3 * u, 1.70, 3.9 * v, cool, .14);

    // Two tester tables with mirrors and spaced tester bottles.
    for (const [tx, tz] of [[2.0, 5.3], [6.0, 4.2]]) {
      const mz = tz < 5 ? tz - .24 : tz + .24;
      box(g, .90 * u, .60, .50 * v, tx * u, .30, tz * v, base);
      box(g, .95 * u, .05, .55 * v, tx * u, .63, tz * v, dark);
      box(g, .90 * u, .70, .04 * v, tx * u, 1.0, mz * v, glassC, 'glass');
      bottle((tx - .18) * u, .655, tz * v, .15 * u, .22, bottles[1]);
      bottle((tx + .18) * u, .655, tz * v, .15 * u, .22, bottles[4]);
    }

    // Corner hero pedestal greeting both entrances.
    cylinder(g, .40 * s, .50, 6.9 * u, .25, 6.0 * v, wood, 'paint', .40 * s, 10);
    cylinder(g, .43 * s, .05, 6.9 * u, .52, 6.0 * v, brass, 'metal', .43 * s, 10);
    bottle(6.72 * u, .545, 5.9 * v, .18 * u, .30, bottles[3]);
    bottle(7.08 * u, .545, 5.9 * v, .18 * u, .30, bottles[0]);
    flask(6.9 * u, .545, 6.15 * v, .11 * s, .34, bottles[2]);
    light(g, 6.9 * u, 1.30, 6.0 * v, warm, .12);

    // Gift-wrapped stack beside the island and a boutique bag by the tester.
    box(g, .35 * u, .35, .35 * v, 5.7 * u, .175, 2.6 * v, blush);
    box(g, .25 * u, .25, .25 * v, 5.7 * u, .475, 2.6 * v, purple);
    box(g, .30 * u, .40, .20 * v, 1.2 * u, .20, 5.3 * v, wood);
    box(g, .26 * u, .10, .16 * v, 1.2 * u, .45, 5.3 * v, blush);

    // Small service desk at the north-west, with an adviser behind it.
    box(g, 1.2 * u, .90, .50 * v, 1.1 * u, .45, 1.0 * v, wood);
    box(g, 1.3 * u, .06, .60 * v, 1.1 * u, .93, 1.0 * v, dark);
    box(g, .40 * u, .30, .04 * v, 1.1 * u, 1.15, .85 * v, dark);
    light(g, 1.1 * u, 1.15, .80 * v, cool, .07);
    staffMember(g, 1.1 * u, .55 * v, 0x3a3f4a, {skin: 0xf1c9a5, hair: 0x4a3524});

    // Ceiling beams wall to fascia with brass pendants over key displays.
    for (const bz of [2.2, 5.0]) box(g, 7.3 * u, .10, .22 * v, 3.85 * u, 2.90, bz * v, ivory).userData.roof = true;
    for (const [lx, lz] of [[4.3, 3.9], [2.6, 1.0], [6.9, 6.0]]) {
      cylinder(g, .015 * s, .30, lx * u, 2.72, lz * v, dark, 'paint', .015 * s, 6);
      cylinder(g, .07 * s, .14, lx * u, 2.52, lz * v, brass, 'metal', .16 * s, 10);
      light(g, lx * u, 2.40, lz * v, warm, .11);
    }
  }

  function airportRestaurant(g, w, d) {
    const u = w / 14, v = d / 10, x = w / 2, s = Math.min(u, v);
    const shell = 0xe5e0d5, wall = 0xd8d3c6, dark = 0x343b3e;
    const wood = 0x805d42, lightWood = 0xa77b55, tableTop = 0x74543d;
    const seatA = 0x465b66, seatB = 0x795f55, metal = 0x8b9295, equip = 0x9ba2a3;
    const teal = 0x2a6d7a, leaf = 0x47704f, leafD = 0x31563b;
    const warm = 0xffd99a, cool = 0xe6f1ef;
    const plate = 0xe8e3d6, foodA = 0xc96f3f, foodB = 0x7a9a5b, bottleG = 0x6e8ba0;

    function chair(px, pz, ry, col) {
      const c = Math.cos(ry), sn = Math.sin(ry);
      box(g, .46 * u, .09, .46 * v, px * u, .47, pz * v, col);
      cylinder(g, .05 * s, .43, px * u, .235, pz * v, metal, 'metal', .05 * s, 8);
      box(g, .46 * u, .55, .09 * v, (px + sn * .235) * u, .78, (pz + c * .235) * v, col).rotation.y = ry;
    }
    function table2(px, pz, tw, td) {
      box(g, tw * u, .07, td * v, px * u, .73, pz * v, tableTop);
      cylinder(g, .07 * s, .70, px * u, .36, pz * v, dark, 'paint', .09 * s, 8);
    }
    function plant(px, pz) {
      cylinder(g, .22 * s, .42, px * u, .21, pz * v, wood, 'paint', .18 * s, 10);
      cylinder(g, .04 * s, .45, px * u, .55, pz * v, wood, 'paint', .04 * s, 8);
      sphere(g, px * u, .85, pz * v, .30 * s, .36, .30 * s, leaf);
      sphere(g, (px - .18) * u, .68, (pz + .1) * v, .18 * s, .22, .18 * s, leafD);
    }
    /** 'glass' renders opaque here, so glazing is drawn as its frame. */
    function glazing(cx, cy, cz, gw, gh, gd, bars) {
      box(g, gw, .05, gd, cx, cy + gh / 2, cz, metal, 'metal');
      box(g, gw, .05, gd, cx, cy - gh / 2, cz, metal, 'metal');
      for (let i = 0; i <= bars; i++) box(g, .05 * u, gh, gd, cx - gw / 2 + i * gw / bars, cy, cz, metal, 'metal');
    }

    // Floor and entry carpet. North is the kitchen; south (+z) is the front.
    box(g, 13.7 * u, .04, 9.7 * v, x, .02, 5 * v, wall);
    box(g, 2.4 * u, .03, 2.4 * v, 7 * u, .035, 8.4 * v, seatB);

    // Back wall and full-height side walls closing into the fascia.
    box(g, 13.7 * u, 3.0, .16 * v, x, 1.5, .20 * v, shell);
    box(g, 13.4 * u, .9, .08 * v, x, .45, .30 * v, wood);
    box(g, .16 * u, 3.0, 9.70 * v, .20 * u, 1.5, 5.05 * v, wall);
    box(g, .16 * u, 3.0, 9.70 * v, w - .20 * u, 1.5, 5.05 * v, wall);

    // Storefront bays flanking the entrance, dressed from the inside.
    for (const bxp of [2.375, 11.625]) {
      box(g, 4.35 * u, .42, .16 * v, bxp * u, .21, 9.82 * v, dark);
      glazing(bxp * u, 1.435, 9.82 * v, 4.35 * u, 2.05, .05 * v, 3);
      box(g, 4.35 * u, .05, .10 * v, bxp * u, 2.445, 9.82 * v, metal, 'metal');
      box(g, 1.5 * u, .44, .7 * v, bxp * u, .22, 9.30 * v, lightWood);
      box(g, .50 * u, .20, .5 * v, (bxp - .45) * u, .52, 9.30 * v, foodA);
      box(g, .40 * u, .16, .5 * v, (bxp + .5) * u, .50, 9.30 * v, teal);
    }

    // Entrance frame, fascia and sign along the south edge.
    box(g, .5 * u, 3.0, .5 * v, 4.7 * u, 1.5, 9.55 * v, shell);
    box(g, .5 * u, 3.0, .5 * v, 9.3 * u, 1.5, 9.55 * v, shell);
    box(g, 13.7 * u, .65, .45 * v, x, 2.775, 9.65 * v, shell);
    box(g, 13.8 * u, .06, .55 * v, x, 3.11, 9.65 * v, dark).userData.roof = true;
    box(g, 3.6 * u, .46, .06 * v, 7 * u, 2.78, 9.90 * v, dark);
    // label() sizes are the text height in metres.
    label(g, 'SKYLINE', 7 * u, 2.88, 9.94 * v, .2, '#f9fcf6', {width: 4.5});
    label(g, 'KITCHEN - BAR', 7 * u, 2.67, 9.94 * v, .09, '#ffd99a', {width: 6});
    light(g, 7 * u, 2.52, 9.945 * v, warm, .08);

    // Doorway: brass reveal, sidelights and a pair of doors.
    box(g, 4.2 * u, .05, .10 * v, 7 * u, 2.44, 9.88 * v, metal, 'metal');
    glazing(5.45 * u, 1.23, 9.80 * v, 1.05 * u, 2.46, .04 * v, 1);
    glazing(8.55 * u, 1.23, 9.80 * v, 1.05 * u, 2.46, .04 * v, 1);
    glazing(6.47 * u, 1.05, 9.78 * v, 1.06 * u, 2.10, .05 * v, 1);
    glazing(7.51 * u, 1.05, 9.795 * v, 1.06 * u, 2.10, .05 * v, 1);
    box(g, .98 * u, .30, .07 * v, 6.47 * u, .15, 9.78 * v, metal, 'metal');
    box(g, .98 * u, .30, .07 * v, 7.51 * u, .15, 9.795 * v, metal, 'metal');
    box(g, .05 * u, .34, .05 * v, 6.94 * u, 1.12, 9.82 * v, metal, 'metal');
    box(g, .05 * u, .34, .05 * v, 7.06 * u, 1.12, 9.82 * v, metal, 'metal');
    box(g, 3.0 * u, .04, .04 * v, 7 * u, 2.26, 9.80 * v, metal, 'metal');
    light(g, 7 * u, 2.43, 9.62 * v, warm, .06);
    box(g, 3.6 * u, .02, 1.1 * v, 7 * u, .045, 9.05 * v, dark);
    box(g, 3.6 * u, .03, .12 * v, 7 * u, .05, 9.62 * v, metal, 'metal');

    // Host podium, menu board and waiting bench near the entrance.
    box(g, .62 * u, 1.02, .45 * v, 5.7 * u, .51, 8.35 * v, wood);
    box(g, .68 * u, .06, .50 * v, 5.7 * u, 1.04, 8.35 * v, dark);
    box(g, .30 * u, .20, .06 * v, 5.7 * u, 1.16, 8.30 * v, dark);
    light(g, 5.7 * u, 1.20, 8.22 * v, warm, .07);
    staffMember(g, 5.7 * u, 7.85 * v, 0x2f3a44, {skin: 0xc68b5e, hair: 0x1f1a16});
    box(g, .70 * u, .90, .06 * v, 8.2 * u, 1.15, 8.55 * v, dark);
    box(g, .06 * u, .72, .08 * v, 8.45 * u, .36, 8.55 * v, dark);
    label(g, 'MENU', 8.2 * u, 1.32, 8.59 * v, .1, '#ffd99a', {width: 3});
    box(g, 1.2 * u, .12, .45 * v, 8.2 * u, .45, 8.55 * v, lightWood);
    box(g, .10 * u, .40, .40 * v, 7.65 * u, .20, 8.55 * v, dark);
    box(g, .10 * u, .40, .40 * v, 8.75 * u, .20, 8.55 * v, dark);

    // Booth row along the north wall.
    for (const bx of [2.3, 4.6]) {
      box(g, 1.7 * u, .42, .55 * v, bx * u, .24, 1.05 * v, seatA);
      box(g, 1.7 * u, .85, .20 * v, bx * u, .85, .68 * v, seatA);
      box(g, 1.7 * u, .42, .55 * v, bx * u, .24, 2.15 * v, seatA);
      box(g, 1.7 * u, .85, .20 * v, bx * u, .85, 2.52 * v, seatA);
      box(g, 1.15 * u, .07, .75 * v, bx * u, .72, 1.60 * v, tableTop);
      cylinder(g, .06 * s, .68, bx * u, .36, 1.60 * v, dark, 'paint', .08 * s, 8);
      box(g, .30 * u, .06, .30 * v, bx * u, .775, 1.60 * v, plate);
    }
    box(g, .12 * u, 1.35, 2.1 * v, 3.45 * u, .675, 1.60 * v, wood);

    // Freestanding dining sets with walking space between them.
    table2(2.0, 4.4, 1.25, .75);
    chair(1.45, 4.4, Math.PI / 2, seatA); chair(2.55, 4.4, -Math.PI / 2, seatA);
    chair(2.0, 3.85, 0, seatB); chair(2.0, 4.95, Math.PI, seatB);
    table2(4.5, 4.2, .85, .75);
    chair(4.5, 3.65, 0, seatA); chair(4.5, 4.75, Math.PI, seatA);
    table2(2.2, 6.4, 1.25, .75);
    chair(1.65, 6.4, Math.PI / 2, seatB); chair(2.75, 6.4, -Math.PI / 2, seatB);
    chair(2.2, 6.95, Math.PI, seatA);
    table2(4.6, 6.5, .85, .75);
    chair(4.6, 5.95, 0, seatB); chair(4.6, 7.05, Math.PI, seatB);
    // Shared group table with legged benches east of the walkway.
    box(g, 1.9 * u, .07, 1.0 * v, 7.2 * u, .73, 5.6 * v, tableTop);
    cylinder(g, .08 * s, .70, 6.7 * u, .36, 5.6 * v, dark, 'paint', .10 * s, 8);
    cylinder(g, .08 * s, .70, 7.7 * u, .36, 5.6 * v, dark, 'paint', .10 * s, 8);
    for (const bz of [4.85, 6.35]) {
      box(g, 1.7 * u, .10, .35 * v, 7.2 * u, .45, bz * v, seatB);
      box(g, .12 * u, .42, .30 * v, 6.5 * u, .21, bz * v, dark);
      box(g, .12 * u, .42, .30 * v, 7.9 * u, .21, bz * v, dark);
    }
    box(g, .34 * u, .07, .34 * v, 7.1 * u, .79, 5.6 * v, plate);
    cylinder(g, .05 * s, .22, 7.2 * u, .87, 5.6 * v, bottleG, 'paint', .05 * s, 8);

    // Bar: long counter, stools, back shelf with bottles, and a bartender.
    box(g, 1.0 * u, 1.0, 3.2 * v, 11.3 * u, .50, 5.4 * v, wood);
    box(g, 1.15 * u, .08, 3.4 * v, 11.3 * u, 1.03, 5.4 * v, dark);
    box(g, .05 * u, .45, 3.0 * v, 10.79 * u, .60, 5.4 * v, teal);
    for (const bzz of [4.5, 5.4, 6.3]) {
      cylinder(g, .20 * s, .07, 10.2 * u, .78, bzz * v, seatA, 'paint', .20 * s, 10);
      cylinder(g, .04 * s, .74, 10.2 * u, .39, bzz * v, metal, 'metal', .04 * s, 8);
    }
    box(g, .45 * u, 1.9, 2.8 * v, 13.25 * u, .95, 5.4 * v, wood);
    box(g, .40 * u, .06, 2.6 * v, 13.05 * u, 1.15, 5.4 * v, lightWood);
    box(g, .40 * u, .06, 2.6 * v, 13.05 * u, 1.65, 5.4 * v, lightWood);
    for (let i = 0; i < 5; i++) {
      cylinder(g, .055 * s, .26, 13.02 * u, 1.30, (4.5 + i * .45) * v, [0x8a3b2e, 0x3f6b4f, 0x6e8ba0, 0xc9a24b, 0x7a5a8c][i], 'paint', .055 * s, 8);
    }
    box(g, .5 * u, .35, .4 * v, 11.3 * u, 1.25, 6.4 * v, equip, 'metal');
    staffMember(g, 12.2 * u, 4.8 * v, 0x1f2a30, {skin: 0xe0ac7e, hair: 0x3a2a1e});
    box(g, .06 * u, .56, .06 * v, 10.95 * u, 1.34, 3.86 * v, metal, 'metal');
    box(g, .06 * u, .56, .06 * v, 11.65 * u, 1.34, 3.86 * v, metal, 'metal');
    box(g, .9 * u, .30, .06 * v, 11.3 * u, 1.75, 3.9 * v, dark);
    label(g, 'BAR', 11.3 * u, 1.79, 3.94 * v, .12, '#ffd99a', {width: 3});
    light(g, 12.95 * u, 1.56, 5.4 * v, warm, .16);

    // Kitchen: plinth, range and hood, fridge, sink, shelf, pass, and a chef.
    box(g, 4.4 * u, .06, 2.3 * v, 11.0 * u, .03, 1.55 * v, dark);
    box(g, 3.6 * u, .88, .6 * v, 11.0 * u, .47, .80 * v, equip, 'metal');
    box(g, 1.1 * u, .90, .62 * v, 9.9 * u, .48, .80 * v, dark);
    cylinder(g, .11 * s, .05, 9.65 * u, .95, .70 * v, dark, 'paint', .11 * s, 10);
    cylinder(g, .11 * s, .05, 10.15 * u, .95, .90 * v, dark, 'paint', .11 * s, 10);
    box(g, 1.5 * u, .45, .85 * v, 9.9 * u, 1.95, .80 * v, equip, 'metal');
    box(g, .55 * u, .95, .55 * v, 9.9 * u, 2.63, .80 * v, equip, 'metal').userData.roof = true;
    box(g, .95 * u, 1.85, .70 * v, 12.5 * u, .955, .85 * v, equip, 'metal');
    box(g, .04 * u, .60, .06 * v, 12.02 * u, 1.10, .85 * v, dark);
    box(g, .85 * u, .88, .60 * v, 11.6 * u, .47, 2.15 * v, equip, 'metal');
    cylinder(g, .16 * s, .10, 11.6 * u, .945, 2.15 * v, metal, 'metal', .16 * s, 10);
    box(g, 2.0 * u, .06, .50 * v, 11.0 * u, 1.80, .48 * v, metal, 'metal');
    box(g, .30 * u, .22, .30 * v, 11.2 * u, 1.925, .48 * v, foodB);
    staffMember(g, 10.6 * u, 1.75 * v, 0xf2f2f2, {skin: 0xf1c9a5, hair: 0x2e2420, cap: true});
    // Food pass linking the kitchen to the dining room.
    box(g, 3.4 * u, .92, .56 * v, 10.6 * u, .46, 2.96 * v, wood);
    box(g, 3.5 * u, .07, .62 * v, 10.6 * u, .945, 2.96 * v, lightWood);
    cylinder(g, .11 * s, .07, 9.8 * u, 1.01, 2.95 * v, plate, 'paint', .11 * s, 10);
    cylinder(g, .11 * s, .07, 11.2 * u, 1.01, 2.95 * v, plate, 'paint', .11 * s, 10);
    cylinder(g, .07 * s, .06, 9.8 * u, 1.07, 2.95 * v, foodA, 'paint', .07 * s, 8);
    box(g, .06 * u, .46, .06 * v, 9.3 * u, 1.19, 2.95 * v, metal, 'metal');
    box(g, .06 * u, .46, .06 * v, 11.9 * u, 1.19, 2.95 * v, metal, 'metal');
    box(g, 1.4 * u, .96, .14 * v, 9.9 * u, 1.32, .32 * v, equip, 'metal');
    box(g, 2.7 * u, .06, .08 * v, 10.6 * u, 1.44, 2.95 * v, metal, 'metal');
    light(g, 10.6 * u, 1.35, 2.95 * v, cool, .14);
    box(g, .10 * u, 1.9, .5 * v, 8.87 * u, .95, 1.55 * v, dark);
    label(g, 'KITCHEN', 8.81 * u, 1.62, 1.55 * v, .1, '#e6f1ef', {rotY: -Math.PI / 2, width: 4});

    // Plants splitting the zones, columns and beams, warm pendants.
    plant(5.9, 4.3); plant(3.4, 7.6);
    for (const bz of [3.4, 6.4]) {
      box(g, 11.5 * u, .10, .22 * v, 6.35 * u, 2.88, bz * v, shell).userData.roof = true;
    }
    for (const cx of [1.0, 12.3]) {
      for (const bz of [3.4, 6.4]) box(g, .18 * u, 2.86, .18 * v, cx * u, 1.43, bz * v, shell);
    }
    for (const [lx, lz] of [[2.2, 4.4], [4.5, 6.5], [11.0, 5.4]]) {
      cylinder(g, .015 * s, .30, lx * u, 2.70, lz * v, dark, 'paint', .015 * s, 6);
      cylinder(g, .09 * s, .14, lx * u, 2.50, lz * v, wood, 'paint', .16 * s, 10);
      light(g, lx * u, 2.40, lz * v, warm, .11);
    }
  }

  function informationDesk(g, w, d) {
    const u = w / 5, v = d / 4, x = w / 2, s = Math.min(u, v);
    const body = 0xd8d3c6, cream = 0xe5e0d5, top = 0x454d50, base = 0x3b4347;
    const teal = 0x2a6d7a, tealL = 0x438996, metal = 0x8b9295, pc = 0x343b3e;
    const screen = 0x1b2e36, glow = 0x7fe0e8, info = 0x3976a8, warm = 0xfff0cf;

    // Floor pad and approach inlay. Passengers arrive from +z, staff at -z.
    box(g, 4.8 * u, .04, 3.8 * v, x, .02, 2 * v, body);
    box(g, 2.6 * u, .03, 1.2 * v, 1.95 * u, .035, 2.75 * v, info);

    // Partial rear wall and side fins: an open island, not a closed box.
    box(g, 3.2 * u, 2.30, .14 * v, 1.95 * u, 1.15, .30 * v, cream);
    box(g, 3.0 * u, .85, .08 * v, 1.95 * u, .425, .38 * v, teal);
    box(g, .16 * u, 2.30, 1.65 * v, .43 * u, 1.15, 1.05 * v, body);
    box(g, .16 * u, 2.30, 1.15 * v, 3.47 * u, 1.15, .80 * v, body);
    cylinder(g, .08 * s, 2.30, .55 * u, 1.15, 1.90 * v, metal, 'metal', .08 * s, 8);
    cylinder(g, .08 * s, 2.30, 3.35 * u, 1.15, 1.90 * v, metal, 'metal', .08 * s, 8);

    // Canopy, blue trim and the four-sided information beacon.
    box(g, 3.4 * u, .14, 1.90 * v, 1.95 * u, 2.34, 1.15 * v, cream).userData.roof = true;
    box(g, 3.46 * u, .06, 1.96 * v, 1.95 * u, 2.27, 1.15 * v, info).userData.roof = true;
    light(g, 1.25 * u, 2.25, 1.30 * v, warm, .12);
    light(g, 2.65 * u, 2.25, 1.30 * v, warm, .12);
    box(g, .95 * u, .48, .95 * v, 1.95 * u, 2.62, 1.15 * v, info);
    box(g, 1.02 * u, .05, 1.02 * v, 1.95 * u, 2.875, 1.15 * v, base).userData.roof = true;
    for (const szz of [1.64, .66]) {
      box(g, .11 * u, .20, .03 * v, 1.95 * u, 2.54, szz * v, cream);
      box(g, .11 * u, .07, .03 * v, 1.95 * u, 2.74, szz * v, cream);
    }
    // label() sizes are the text height in metres.
    label(g, 'INFO', 2.44 * u, 2.62, 1.15 * v, .16, '#f9fcf6', {rotY: Math.PI / 2, width: 3});
    label(g, 'INFO', 1.46 * u, 2.62, 1.15 * v, .16, '#f9fcf6', {rotY: -Math.PI / 2, width: 3});
    box(g, 2.2 * u, .20, .05 * v, 1.95 * u, 2.34, 2.11 * v, info);
    label(g, 'INFORMATION', 1.95 * u, 2.35, 2.145 * v, .1, '#f9fcf6', {width: 6});
    light(g, 1.95 * u, 2.62, 1.68 * v, glow, .10);

    // Counter: two staffed bays plus a lower accessible bay at the left end.
    box(g, 2.1 * u, .92, .72 * v, 2.35 * u, .46, 1.72 * v, body);
    box(g, 2.0 * u, .50, .06 * v, 2.35 * u, .32, 2.06 * v, teal);
    box(g, 2.2 * u, .08, .82 * v, 2.35 * u, .95, 1.72 * v, top);
    box(g, 2.22 * u, .03, .84 * v, 2.35 * u, .995, 1.72 * v, metal, 'metal');
    box(g, .85 * u, .74, .72 * v, .95 * u, .37, 1.72 * v, body);
    box(g, .78 * u, .40, .06 * v, .95 * u, .26, 2.06 * v, tealL);
    box(g, .90 * u, .08, .80 * v, .95 * u, .77, 1.72 * v, top);
    box(g, .06 * u, .24, .40 * v, 2.05 * u, 1.10, 1.72 * v, 0xcfe0e2, 'glass');
    box(g, .24 * u, .18, .14 * v, 3.20 * u, 1.07, 1.92 * v, info);
    box(g, .20 * u, .22, .04 * v, 3.20 * u, 1.13, 1.92 * v, cream);

    // Two staffed workstations; the monitors face the employees.
    for (const wx of [1.55, 2.75]) {
      box(g, .46 * u, .30, .04 * v, wx * u, 1.22, 1.52 * v, screen).rotation.y = Math.PI;
      box(g, .06 * u, .18, .06 * v, wx * u, 1.06, 1.52 * v, pc);
      light(g, wx * u, 1.22, 1.46 * v, glow, .07);
      box(g, .38 * u, .03, .18 * v, wx * u, 1.00, 1.66 * v, pc);
      staffMember(g, wx * u, 1.02 * v, info, wx < 2 ? {skin: 0xd8b49a, hair: 0x35291f} : {skin: 0x8d5a3b, hair: 0x15110e});
    }

    // Shared rear console, printer and wall map panel.
    box(g, 2.6 * u, .82, .38 * v, 1.95 * u, .41, .58 * v, body);
    box(g, 2.66 * u, .06, .42 * v, 1.95 * u, .84, .58 * v, top);
    box(g, .36 * u, .20, .26 * v, 2.15 * u, .95, .58 * v, metal, 'metal');
    box(g, 1.4 * u, .75, .05 * v, 1.95 * u, 1.50, .40 * v, screen);
    box(g, 1.2 * u, .55, .03 * v, 1.95 * u, 1.50, .43 * v, tealL);
    label(g, 'TERMINAL MAP', 1.95 * u, 1.74, .455 * v, .08, '#f9fcf6', {width: 6});

    // Self-service kiosk on the right, facing the passengers.
    box(g, .72 * u, .08, .72 * v, 4.25 * u, .06, 2.15 * v, base);
    box(g, .54 * u, 1.88, .30 * v, 4.25 * u, 1.02, 2.05 * v, body);
    box(g, .58 * u, .08, .36 * v, 4.25 * u, 1.98, 2.05 * v, info);
    box(g, .46 * u, .78, .04 * v, 4.25 * u, 1.28, 2.21 * v, screen);
    light(g, 4.25 * u, 1.28, 2.24 * v, glow, .12);
    box(g, .42 * u, .06, .16 * v, 4.25 * u, .84, 2.24 * v, top);
    label(g, 'INFO', 4.25 * u, 1.56, 2.24 * v, .11, '#7fe0e8', {width: 3});
    label(g, 'FLIGHTS  MAP', 4.25 * u, 1.38, 2.24 * v, .06, '#f9fcf6', {width: 6});
    label(g, 'TOUCH', 4.25 * u, 1.10, 2.24 * v, .07, '#7fe0e8', {width: 3});
  }

  function trashBins(g, w, d) {
    const u = w / 2, v = d, x = w / 2, z = d / 2, s = Math.min(u, v);
    const body = 0x555e62, dark = 0x252b2e, metal = 0x8b9295;
    const waste = 0x4d5356, recycle = 0x3976a8, cans = 0xe0b53f, sign = 0xd8d3c6;

    // Shared plinth and trim rail tie all three bays into one fixture.
    box(g, 1.82 * u, .08, .76 * v, x, .04, z, dark);
    box(g, 1.76 * u, .06, .70 * v, x, .09, z, metal, 'metal');

    // Outer shell, stepped cabinet and the sloped chute hood.
    box(g, 1.72 * u, .72, .62 * v, x, .46, z, body);
    box(g, .05 * u, .74, .64 * v, x - .845 * u, .46, z, metal, 'metal');
    box(g, .05 * u, .74, .64 * v, x + .845 * u, .46, z, metal, 'metal');
    box(g, 1.74 * u, .04, .64 * v, x, .83, z, metal, 'metal');
    box(g, 1.70 * u, .24, .58 * v, x, .95, z - .01 * v, body);
    box(g, 1.68 * u, .10, .34 * v, x, 1.10, z - .12 * v, body);
    box(g, 1.72 * u, .03, .36 * v, x, 1.155, z - .12 * v, metal, 'metal');

    // Two dividers split the shell into three compartments.
    for (const dx of [-.28, .28]) box(g, .03 * u, .90, .63 * v, x + dx * u, .54, z, metal, 'metal');

    // Service doors, colour-coded headers and labels.
    // label() sizes are the text height in metres.
    const bays = [[-.56, waste, 'WASTE'], [0, recycle, 'RECYCLE'], [.56, cans, 'BOTTLES']];
    for (const [bx, col, txt] of bays) {
      const px = x + bx * u;
      box(g, .48 * u, .54, .04 * v, px, .44, z + .31 * v, col === waste ? 0x464d50 : body);
      box(g, .48 * u, .08, .05 * v, px, .75, z + .315 * v, col);
      box(g, .50 * u, .05, .32 * v, px, 1.08, z - .12 * v, col);
      label(g, txt, px, .755, z + .348 * v, .055, col === cans ? '#252b2e' : '#f9fcf6', {width: 3});
    }

    // Three different openings, readable from a distance.
    box(g, .42 * u, .15, .16 * v, x - .56 * u, .96, z + .23 * v, dark);
    box(g, .44 * u, .12, .14 * v, x, .96, z + .22 * v, sign);
    box(g, .38 * u, .045, .16 * v, x, .96, z + .23 * v, dark);
    box(g, .44 * u, .14, .14 * v, x + .56 * u, .96, z + .22 * v, cans);
    for (const ox of [-.11, .11]) {
      cylinder(g, .065 * s, .16, x + (.56 + ox) * u, .96, z + .23 * v, dark, 'paint', .065 * s, 10).rotation.x = Math.PI / 2;
    }

    // Rear header board with colour swatches, readable from behind too.
    box(g, .05 * u, .22, .05 * v, x - .60 * u, 1.22, z - .22 * v, metal, 'metal');
    box(g, .05 * u, .22, .05 * v, x + .60 * u, 1.22, z - .22 * v, metal, 'metal');
    box(g, 1.56 * u, .18, .05 * v, x, 1.28, z - .22 * v, sign);
    box(g, 1.60 * u, .03, .07 * v, x, 1.375, z - .22 * v, metal, 'metal');
    for (const [bx, col] of bays) box(g, .42 * u, .10, .07 * v, x + bx * u, 1.28, z - .22 * v, col);
  }

  function interior(g, w, d, k, context = {}) {
    switch (k) {
      case 'entrance':
        box(g, w, .08, d, w / 2, .34, d / 2, 0x3f6e78);
        for (const x of [.4, w - .4]) box(g, .3, 3.2, .3, x, 1.9, d / 2, 0xb9c3c4, 'metal');
        box(g, w, .35, 1.2, w / 2, 3.6, d / 2, 0x2e6c78, 'metal');
        box(g, w - 1, 2.8, .12, w / 2, 1.8, d / 2, 0x8ad0e0, 'glass');
        label(g, 'DEPARTURES', w / 2, 3.62, d / 2 - .62, .3, '#ffffff', {width: 5});
        break;
      case 'checkIn': {
        box(g, w, .9, 1.4, w / 2, .75, 1, 0xe6dccb);
        box(g, w, .12, 1.5, w / 2, 1.25, 1, 0x2a6d7a);
        box(g, w, .2, .7, w / 2, .5, 2.1, 0x3b4347, 'metal');
        for (let x = 1; x < w; x += 2) {
          box(g, .7, .5, .06, x, 1.7, .6, 0x1e3740);
          box(g, .6, .38, .07, x, 1.72, .57, 0x7fe0e8, 'light');
          box(g, .4, 2.6, .4, x, .3 + 1.3, .2, 0xd9d4c8);
        }
        box(g, w, .6, .2, w / 2, 2.9, .2, 0x1f4a57);
        label(g, 'CHECK-IN', w / 2, 2.9, .31, .45, '#f6d34a', {width: 4});
        for (let x = .8; x < w; x += 1.6) for (const z of [2.9, 3.7]) cylinder(g, .05, .9, x, .75, z, 0xb7bec2, 'metal');
        for (const z of [2.9, 3.7]) box(g, w - 1.2, .06, .04, w / 2, 1.1, z, 0xd8423a);
        break;
      }
      case 'baggageCarousel':
        onFloor(g, (part, pw, pd) => baggageCarousel(part, pw, pd, context.live), w, d);
        break;
      case 'vipLounge':
        onFloor(g, vipLounge, w, d);
        break;
      case 'luxuryBoutique':
        onFloor(g, cozyClothing, w, d);
        break;
      case 'restaurant':
        onFloor(g, airportRestaurant, w, d);
        break;
      case 'perfumeShop':
        onFloor(g, perfumeCornerShop, w, d);
        break;
      case 'foodShop':
        onFloor(g, dutyFreeFoodDrinks, w, d);
        break;
      case 'kiosk':
        onFloor(g, checkoutCounter, w, d);
        break;
      case 'clothingShop':
        onFloor(g, dutyFreeClothing, w, d);
        break;
      case 'vendingMachine':
        onFloor(g, vendingMachine, w, d);
        break;
      case 'bins':
        onFloor(g, trashBins, w, d);
        break;
      case 'infoDesk':
        onFloor(g, informationDesk, w, d);
        break;
      case 'checkInCounter':
        onFloor(g, checkInCounter, w, d);
        break;
      case 'ticketMachine':
        onFloor(g, ticketMachine, w, d);
        break;
      case 'security':
        for (const x of [1.3, w - 1.3]) {
          box(g, 1.1, 2.4, .25, x - .55, 1.55, d / 2, 0xc7ced0, 'metal');
          box(g, 1.1, 2.4, .25, x + .55, 1.55, d / 2, 0xc7ced0, 'metal');
          box(g, 1.3, .25, .35, x, 2.75, d / 2, 0xa9b3b6, 'metal');
          light(g, x, 2.95, d / 2, 0x4cff7a, .15);
        }
        box(g, 1.4, 1.3, 1.8, w / 2, 1, d / 2 - 1.4, 0x5d7477, 'metal');
        box(g, 1.2, .9, 3.6, w / 2, .8, d / 2 + .8, 0x2d3b40, 'metal');
        box(g, .8, .5, .06, w / 2 + 1, 1.8, d / 2 - 1.4, 0x7fe0e8, 'light');
        for (const x of [.2, w - .2]) box(g, .15, 1.1, d, x, .85, d / 2, 0x8f9a9c, 'metal');
        box(g, w, .4, .15, w / 2, 3.2, .1, 0x1f4a57);
        label(g, 'SECURITY', w / 2, 3.2, .19, .32, '#ffffff', {width: 4});
        break;
      case 'seating': {
        // Rows of four, back to back, in 4 x 2 m tiles.
        const cols = Math.max(1, Math.round(w / 4)), rows = Math.max(1, Math.round(d / 2));
        for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) onFloor(g, waitingSeats, w / cols, d / rows, c * w / cols, r * d / rows, r % 2 === 0);
        break;
      }
      case 'toilets':
        box(g, w, 3, d, w / 2, 1.8, d / 2, 0xe9e4d8);
        box(g, w, .2, d, w / 2, 3.4, d / 2, 0x5f8e92).userData.roof = true;
        box(g, 1.6, 2.4, .1, w * .3, 1.5, .02, 0x3d7b85);
        box(g, 1.6, 2.4, .1, w * .7, 1.5, .02, 0x8a4e76);
        label(g, 'WC', w / 2, 2.9, -.04, .5, '#184b55', {width: 1.4});
        break;
      case 'boardingGate':
        box(g, 2.2, 1.05, .9, w / 2, .82, d / 2 - .8, 0x2a6d7a);
        box(g, 2.3, .06, 1, w / 2, 1.37, d / 2 - .8, 0xe8e2d4);
        cylinder(g, .06, 2.4, w / 2 + 1.5, 1.5, d / 2 - .8, 0x9aa3a6, 'metal');
        box(g, 1.6, .9, .1, w / 2 + 1.5, 2.9, d / 2 - .8, 0x1b2e36);
        box(g, 1.45, .75, .12, w / 2 + 1.5, 2.9, d / 2 - .82, 0xf5c542, 'light');
        for (let x = .6; x < w; x += .8) { box(g, .62, .12, .55, x, .78, d - 1, 0x2f6fb0); box(g, .62, .6, .1, x, 1.05, d - .72, 0x2f6fb0); }
        for (const x of [.8, w - .8]) cylinder(g, .05, .9, x, .75, d / 2, 0xb7bec2, 'metal');
        box(g, w - 1.6, .06, .04, w / 2, 1.1, d / 2, 0x2b62c9);
        break;
      case 'cafe':
        box(g, w, .12, d, w / 2, .36, d / 2, 0xa9784f);
        box(g, w - 1, 1.1, 1.3, w / 2, .85, 1, 0x7a4d33);
        box(g, w - .8, .1, 1.5, w / 2, 1.45, 1, 0xf0e2c6);
        box(g, w - 1, 2.2, .3, w / 2, 2.4, .2, 0x5a3b2a);
        for (let x = 1.5; x < w - 1; x += 1.5) box(g, 1, .6, .25, x, 2.2, .45, [0xe7b85f, 0xd9695b, 0x6fb3a8][Math.floor(x) % 3]);
        for (let x = 2; x < w - 1; x += 3.2) for (let z = 4; z < d - .8; z += 2.8) {
          cylinder(g, .55, .08, x, 1.05, z, 0xf2ebe0);
          cylinder(g, .06, .7, x, .7, z, 0x4b5a5c, 'metal');
          for (const dx of [-.85, .85]) { box(g, .45, .08, .45, x + dx, .78, z, 0xd7a24c); box(g, .45, .5, .08, x + dx * 1.2, 1.05, z, 0xd7a24c); }
        }
        label(g, 'DEPARTURE COFFEE', w / 2, 3.2, .04, .45, '#fff3dc', {background: '#6a3f2a', width: 6});
        break;
      case 'shop': {
        box(g, w, .12, d, w / 2, .36, d / 2, 0xe9e1d3);
        for (const [x, z, ww, dd] of [[w / 2, .3, w, .3], [.15, d / 2, .3, d], [w - .15, d / 2, .3, d]]) box(g, ww, 3, dd, x, 1.9, z, 0x2c2c3a);
        for (let x = 1.2; x < w - 1; x += 1.8) for (let y = .9; y < 2.8; y += .6) box(g, 1.4, .08, .5, x, y, .75, 0xe8e2d6);
        for (let x = 1.2; x < w - 1; x += 1.8) for (let y = 1.05; y < 2.9; y += .6) for (let i = 0; i < 4; i++) box(g, .22, .28, .22, x - .45 + i * .3, y, .75, [0xd9453b, 0xf2c230, 0x3f86d6, 0x9b5fc0, 0x4cb07a][(i + Math.round(y * 5)) % 5]);
        for (let x = 2.5; x < w - 2; x += 3.5) for (let z = 3.2; z < d - 1; z += 3) {
          box(g, 1.8, .9, 1, x, .8, z, 0xf2efe8);
          for (let i = 0; i < 3; i++) box(g, .35, .3, .35, x - .5 + i * .5, 1.4, z, [0xe06a8a, 0x4f9bd9, 0xf3b33d][i]);
        }
        box(g, 2.4, 1, .8, w - 2, .85, d - 1.2, 0xc9a86a);
        box(g, w, .8, .25, w / 2, 3.6, .15, 0x6b1f3a);
        label(g, 'DUTY FREE', w / 2, 3.6, .01, .6, '#ffd766', {width: 5});
        light(g, w / 2, 3.1, d / 2, 0xfff3d6, .4);
        break;
      }
      case 'lounge':
        box(g, w, .12, d, w / 2, .36, d / 2, 0x3a4a5e);
        for (const [x, z, ww, dd] of [[w / 2, .2, w, .2], [w / 2, d - .2, w, .2], [.2, d / 2, .2, d]]) box(g, ww, 2.6, dd, x, 1.7, z, 0xc8b89a);
        box(g, .2, 2.6, d, w - .2, 1.7, d / 2, 0x8fc6d8, 'glass');
        for (let x = 2; x < w - 1.5; x += 3.2) for (let z = 2.4; z < d - 1.5; z += 3.4) {
          for (const dz of [-.9, .9]) { box(g, 1.2, .45, 1, x, .7, z + dz, 0x7b5c46); box(g, 1.2, .7, .25, x, 1, z + dz + Math.sign(dz) * .45, 0x7b5c46); }
          cylinder(g, .45, .5, x, .65, z, 0x2f3438, 'metal');
        }
        box(g, 4, 1.1, 1, 2.6, .9, 1.2, 0x2f3c47);
        box(g, 4.2, .08, 1.2, 2.6, 1.5, 1.2, 0xe6d7b8, 'metal');
        palm(g, w - 2.2, 2.2, .8);
        label(g, 'PREMIUM LOUNGE', w / 2, 3.35, .02, .5, '#e9d29a', {background: '#1f2b36', width: 6});
        break;
      case 'plant':
        palm(g, w / 2, d / 2, Math.min(w, d) * .3, 1.6);
        break;
      case 'fountain':
        cylinder(g, Math.min(w, d) / 2 - .05, .7, w / 2, .7, d / 2, 0xd8d2c4, 'paint', Math.min(w, d) / 2 - .05, 28);
        cylinder(g, Math.min(w, d) / 2 - .45, .08, w / 2, 1.02, d / 2, 0x3fb6d8, 'water', Math.min(w, d) / 2 - .45, 28);
        cylinder(g, .9, .5, w / 2, 1.2, d / 2, 0xd8d2c4, 'paint', 1.1);
        cylinder(g, .2, 1.4, w / 2, 1.9, d / 2, 0xbfc7c9, 'metal');
        cylinder(g, .9, .15, w / 2, 2.6, d / 2, 0x3fb6d8, 'water', .5);
        sphere(g, w / 2, 3, d / 2, .35, .5, .35, 0xbfeaff, 'water');
        for (let i = 0; i < 8; i++) { const a = i / 8 * TAU; box(g, .25, .6, .25, w / 2 + Math.cos(a) * (Math.min(w, d) / 2 - .25), 1.3, d / 2 + Math.sin(a) * (Math.min(w, d) / 2 - .25), 0x3c8a4a); }
        light(g, w / 2, 1.1, d / 2 + 1.2, 0x9fe3ff, .2);
        break;
      case 'infoBoard':
        for (const x of [.4, w - .4]) cylinder(g, .08, 2.2, x, 1.4, d / 2, 0x7d878a, 'metal');
        box(g, w - .2, 1.6, .2, w / 2, 2.8, d / 2, 0x151f28);
        for (let r = 0; r < 5; r++) box(g, w - .6, .16, .05, w / 2, 2.25 + r * .27, d / 2 - .12, r ? 0xf5c542 : 0xffffff, 'light');
        break;
    }
  }

  function facility(f, context = {}) {
    const g = new T.Group(), turn = ((Math.round(f.rotation || 0) % 4) + 4) % 4;
    const w = turn % 2 ? f.depth : f.width, d = turn % 2 ? f.width : f.depth, k = f.kind;
    if (k.startsWith('runway')) runway(g, w, d);
    else if (k === 'taxiway') taxiway(g, w, d);
    else if (k === 'serviceRoad') serviceRoad(g, w, d);
    else if (k === 'stand' || k === 'standRegional' || k === 'standContact') stand(g, w, d, f, context);
    else if (k === 'terminal') terminal(g, w, d, context);
    else if (k === 'hangar') hangar(g, w, d);
    else if (k === 'fuelDepot') fuelDepot(g, w, d);
    else if (k === 'baggage') { serviceBuilding(g, w, d, 'BAGGAGE HALL', 0x44565a); for (let x = 3; x < w - 3; x += 7) { box(g, 5, .5, 1.4, x, .45, 1.2, 0x2b3134, 'metal'); for (let i = 0; i < 3; i++) box(g, .7, .45, .5, x - 1.5 + i * 1.5, .95, 1.2, [0x3d5a80, 0x8a4b3c, 0x333b3f][i]); } }
    else if (k === 'vehicleDepot') { serviceBuilding(g, w, d, 'GROUND SERVICES', 0x6d5a3a); }
    else if (k === 'tower') tower(g, w, d);
    else interior(g, w, d, k, context);
    bake(g, {x: f.x || 0, z: f.y || 0});
    g.rotation.y = turn * Math.PI / 2;
    g.position.set((f.x || 0) + (turn === 2 ? w : turn === 3 ? d : 0), 0, (f.y || 0) + (turn === 1 ? w : turn === 2 ? d : 0));
    g.userData.facilityId = f.id;
    return g;
  }

  // ── Aircraft ──────────────────────────────────────────────────────────
  const specs = {
    atr72: {length: 27, radius: 1.35, span: 27, prop: true, highWing: true},
    e175: {length: 31.7, radius: 1.5, span: 26, tailEngines: false},
    e195e2: {length: 41.5, radius: 1.55, span: 35},
    a220_300: {length: 38.7, radius: 1.75, span: 35},
    a320neo: {length: 37.6, radius: 2, span: 35.8},
    b737max8: {length: 39.5, radius: 1.9, span: 35.9},
    a321neo: {length: 44.5, radius: 2, span: 35.8},
    a330_900: {length: 63.7, radius: 2.8, span: 64, wide: true},
    b787_9: {length: 62.8, radius: 2.9, span: 60, wide: true},
    a350_1000: {length: 73.8, radius: 3, span: 64.8, wide: true},
    b777_300er: {length: 73.9, radius: 3.1, span: 64.8, wide: true},
    b747_8i: {length: 76.3, radius: 3.2, span: 68.4, wide: true, four: true, hump: true},
    a380_800: {length: 72.7, radius: 3.6, span: 79.8, wide: true, four: true, tall: true},
  };
  function spec(modelId) {
    const id = String(modelId || '').toLowerCase();
    if (specs[id]) return specs[id];
    if (/atr|dash|prop/.test(id)) return specs.atr72;
    if (/747|380/.test(id)) return specs.b747_8i;
    if (/787|777|350|330|wide/.test(id)) return specs.b787_9;
    return specs.a320neo;
  }
  function fuselageGeometry(L, R, tall) {
    return geometry(`fus${L}/${R}/${tall}`, () => {
      const pts = [];
      const steps = 28;
      for (let i = 0; i <= steps; i++) {
        const t = i / steps;
        let r;
        if (t < .11) r = R * Math.sqrt(Math.max(.02, t / .11)) * (.35 + .65 * Math.min(1, t / .11 + .3));
        else if (t < .74) r = R;
        else r = R * (1 - Math.pow((t - .74) / .26, 1.6) * .82);
        pts.push(new T.Vector2(Math.max(.04, Math.min(R, r)), -L / 2 + t * L));
      }
      const geo = new T.LatheGeometry(pts, 24);
      geo.rotateX(Math.PI / 2);
      if (tall) geo.scale(1, 1.28, 1);
      return geo;
    });
  }
  function wing(g, span, root, sweep, y, z, color, thickness = .35, dihedral = .06) {
    for (const side of [-1, 1]) {
      const tipChord = root * .3;
      const pts = [[0, 0], [side * span / 2, sweep], [side * span / 2, sweep + tipChord], [0, root]];
      const m = shape(g, side < 0 ? pts : pts.slice().reverse(), thickness, color, 'metal');
      m.position.set(0, y, z);
      m.rotation.z = side * dihedral;
    }
  }
  function aircraftBody(modelId, carrier) {
    const g = new T.Group(), s = spec(modelId), paint = AirportSceneLogic.livery(carrier);
    const L = s.length, R = s.radius, cy = R + (s.wide ? 2.4 : 1.6);
    const white = 0xf4f5f2, grey = 0xc9ced1, dark = 0x223540;
    add(g, fuselageGeometry(L, R, s.tall), mat(white, 'metal'), 0, cy, 0);
    // belly and cheatline in the carrier colour
    add(g, fuselageGeometry(L * .74, R * 1.004, s.tall), mat(paint.main, 'metal'), 0, cy - R * .02, L * .02, 1, .42, 1).position.y = cy - R * .56;
    for (const side of [-1, 1]) {
      box(g, .06, R * .16, L * .6, side * R * 1.005, cy + R * .3, -L * .03, dark);
      box(g, .06, R * .1, L * .66, side * R * 1.006, cy - R * .02, -L * .02, paint.accent);
      if (s.tall) box(g, .06, R * .14, L * .5, side * R * 1.005, cy + R * .92, -L * .04, dark);
    }
    box(g, R * 1.3, R * .32, 1.1, 0, cy + R * .42, -L * .43, dark);
    if (s.hump) add(g, geometry('hump', () => new T.SphereGeometry(1, 18, 10)), mat(white, 'metal'), 0, cy + R * .7, -L * .3, R * .8, R * .75, L * .2);
    // wings, stabilisers and fin
    const wingY = s.highWing ? cy + R * .92 : cy - R * .62, wingZ = s.highWing ? -L * .02 : -L * .1;
    wing(g, s.span, s.wide ? 12 : s.prop ? 3.4 : 7, s.prop ? .6 : s.span * .22, wingY, wingZ, grey, s.wide ? .5 : .32, s.highWing ? -.01 : .07);
    if (!s.prop) for (const side of [-1, 1]) {
      const tip = box(g, .18, 2.4, 1.4, side * s.span / 2, wingY + 1.2 + s.span / 2 * .07, wingZ + s.span * .22 + 1.2, paint.main, 'metal');
      tip.rotation.z = side * -.35;
    }
    wing(g, s.span * .34, s.wide ? 6 : 3.6, s.span * .09, cy + R * (s.prop ? .95 : .25), L * .33, grey, .22, .09);
    const finH = s.wide ? 11 : s.prop ? 7 : 7.8;
    const fin = shape(g, [[0, 0], [finH, L * .1], [finH, L * .16], [0, L * .18]], .35, paint.main, 'metal');
    fin.rotation.z = Math.PI / 2; fin.position.set(-.175, cy + R * .6, L * .29);
    const band = shape(g, [[finH * .45, L * .055], [finH * .6, L * .07], [finH * .6, L * .1], [finH * .45, L * .096]], .4, paint.accent, 'metal');
    band.rotation.z = Math.PI / 2; band.position.set(-.2, cy + R * .6, L * .29);
    // engines
    const engines = s.four ? [-.36, -.2, .2, .36] : s.prop ? [-.3, .3] : [-.31, .31];
    for (const e of engines) {
      const x = e * s.span, sweepAt = Math.abs(e) * 2 * (s.span * .22);
      if (s.prop) {
        const nac = cylinder(g, .75, 5, x, wingY - .3, wingZ - .6, grey, 'metal', .55); nac.rotation.x = Math.PI / 2;
        box(g, .14, 4, .12, x, wingY - .3, wingZ - 3.2, 0x2e3b40);
        box(g, 4, .14, .12, x, wingY - .3, wingZ - 3.2, 0x2e3b40);
        sphere(g, x, wingY - .3, wingZ - 3.2, .35, .35, .5, paint.accent);
      } else {
        const r = s.wide ? 1.75 : 1.05, len = s.wide ? 6.4 : 4.4;
        const ey = wingY - r - .35 + Math.abs(x) * .07, ez = wingZ + sweepAt - len * .45;
        const nac = cylinder(g, r, len, x, ey, ez, paint.engine ?? 0xe8ebe8, 'metal', r * .92); nac.rotation.x = Math.PI / 2;
        const intake = cylinder(g, r * .82, .12, x, ey, ez - len / 2 - .02, 0x1e282c, 'metal'); intake.rotation.x = Math.PI / 2;
        const lip = cylinder(g, r * 1.01, .3, x, ey, ez - len / 2 + .1, 0xd8dcdc, 'metal'); lip.rotation.x = Math.PI / 2;
        box(g, .3, r * .8, len * .6, x, ey + r * .9, ez + len * .15, grey, 'metal');
      }
    }
    // landing gear
    const gearZ = wingZ + (s.prop ? 1.5 : s.span * .12);
    for (const side of [-1, 1]) {
      box(g, .22, cy - R * .8, .22, side * R * .8, (cy - R * .8) / 2 + .3, gearZ, 0x7d878a, 'metal');
      for (const dz of s.wide ? [-.9, .9] : [0]) { const t = cylinder(g, .55, .5, side * R * .8, .55, gearZ + dz, 0x1d2427); t.rotation.z = Math.PI / 2; }
    }
    box(g, .16, cy - R * .8, .16, 0, (cy - R * .8) / 2 + .3, -L * .38, 0x7d878a, 'metal');
    const nose = cylinder(g, .4, .35, 0, .42, -L * .38, 0x1d2427); nose.rotation.z = Math.PI / 2;
    light(g, 0, cy - R * .95, -L * .1, 0xff3b30, .3);
    for (const side of [-1, 1]) light(g, side * s.span / 2, wingY + .1, wingZ + s.span * .22, side < 0 ? 0xff3b30 : 0x3dff6a, .3);
    return g;
  }
  function aircraft(modelId, carrier = 'LUMA') {
    const s = spec(modelId), paint = AirportSceneLogic.livery(carrier);
    const g = instance(`a:${String(modelId || '').toLowerCase()}|${paint.main}|${paint.accent}`, () => aircraftBody(modelId, carrier));
    const cy = s.radius + (s.wide ? 2.4 : 1.6), text = String(carrier).substring(0, 16).toUpperCase();
    const hex = `#${paint.main.toString(16).padStart(6, '0')}`;
    for (const side of [-1, 1]) {
      label(g, text, side * (s.radius * 1.03), cy + s.radius * .62, -s.length * .12, s.radius * .42, hex, {rotY: side * Math.PI / 2, width: Math.max(4, text.length * .62)});
    }
    return g;
  }

  // ── Ground vehicles ───────────────────────────────────────────────────
  function wheels(g, xs, zs, r = .45) { for (const x of xs) for (const z of zs) { const t = cylinder(g, r, .35, x, r, z, 0x22292b); t.rotation.z = Math.PI / 2; } }
  function vehicleBody(kind) {
    const g = new T.Group();
    if (kind === 'fuel') {
      box(g, 2.5, .5, 9, 0, .95, 0, 0x3c4144, 'metal');
      box(g, 2.5, 2.2, 2.4, 0, 2.2, -3.3, 0xf2c230);
      box(g, 2.3, .8, .1, 0, 2.7, -4.52, 0x2c4d57, 'glass');
      const tank = cylinder(g, 1.25, 6, 0, 2.5, 1.2, 0xf1f0ea, 'metal'); tank.rotation.x = Math.PI / 2;
      box(g, 2.52, .3, 6, 0, 2.1, 1.2, 0xf2c230);
      box(g, .6, .6, .6, 0, 3.8, 1.2, 0x9aa4a8, 'metal');
      light(g, 0, 3.4, -3.3, 0xffa51f, .3);
      wheels(g, [-1.15, 1.15], [-3.2, 1.8, 3.4]);
    } else if (kind === 'baggage') {
      box(g, 1.6, .9, 2.6, 0, .9, -4.2, 0x2f7f86);
      box(g, 1.5, .8, 1.2, 0, 1.8, -4.4, 0xe9e5d8);
      light(g, 0, 2.3, -4.4, 0xffa51f, .25);
      wheels(g, [-.7, .7], [-5, -3.4], .35);
      for (let i = 0; i < 3; i++) {
        const z = -1.6 + i * 2.9;
        box(g, 1.7, .3, 2.4, 0, .75, z, 0x3d4a4f, 'metal');
        for (const y of [1.25]) box(g, 1.7, .9, .05, 0, y, z - 1.18, 0x9aa4a8, 'metal');
        for (let b = 0; b < 4; b++) box(g, .7, .45, .55, (b % 2 ? .4 : -.4), 1.13 + (b > 1 ? .45 : 0), z + (b % 2 ? .45 : -.3), [0x3d5a80, 0x8a4b3c, 0x333b3f, 0x6b8e3a][b]);
        wheels(g, [-.75, .75], [z - .8, z + .8], .28);
      }
    } else if (kind === 'bus') {
      box(g, 3, 2.8, 12, 0, 1.9, 0, 0xf4f3ee);
      box(g, 3.02, 1.2, 11.2, 0, 2.3, .2, 0x2d6fa6, 'glass');
      box(g, 3.04, .35, 12, 0, .75, 0, 0x2d6fa6);
      box(g, 2.9, .2, 11.8, 0, 3.4, 0, 0xdfe3e2);
      box(g, 2.6, 1.3, .1, 0, 2.2, -6.02, 0x2d6fa6, 'glass');
      for (const z of [-3, 1, 5]) box(g, .05, 2.2, 1.6, 1.52, 1.5, z, 0x9ec9e0, 'glass');
      light(g, -1, 1, -6.05, 0xfff6d8, .3); light(g, 1, 1, -6.05, 0xfff6d8, .3);
      wheels(g, [-1.3, 1.3], [-4, 4], .55);
    } else {
      box(g, 3, 1, 5.6, 0, .95, 0, 0xf2c230);
      box(g, 3.02, .25, 5.62, 0, 1.5, 0, 0x2c2f31);
      box(g, 1.6, 1, 1.4, .6, 2, 1.6, 0x2c4d57, 'glass');
      box(g, 1.7, .15, 1.5, .6, 2.55, 1.6, 0xf2c230);
      box(g, 2.2, .35, .5, 0, .8, -3, 0x3c4144, 'metal');
      light(g, -.8, 2.7, 1.6, 0xffa51f, .25);
      wheels(g, [-1.3, 1.3], [-1.7, 1.7], .55);
    }
    return g;
  }
  const vehicle = kind => instance(`v:${kind}`, () => vehicleBody(kind));

  // ── People ────────────────────────────────────────────────────────────
  function personGeometry(part) {
    return geometry(`person-${part}`, () => {
      const g = new T.Group();
      if (part === 'head') {
        sphere(g, 0, 1.6, 0, .15, .17, .15, 0xffffff);
        box(g, .3, .08, .3, 0, 1.74, 0, 0x6b6b6b);
      } else {
        box(g, .14, .72, .14, -.1, .36, 0, 0x4a4a4a);
        box(g, .14, .72, .14, .1, .36, 0, 0x4a4a4a);
        cylinder(g, .21, .7, 0, 1.07, 0, 0xffffff, 'paint', .24, 8);
        box(g, .1, .6, .1, -.28, 1.05, 0, 0xffffff);
        box(g, .1, .6, .1, .28, 1.05, 0, 0xffffff);
      }
      g.traverse(o => { if (o.isMesh) o.castShadow = true; });
      return bake(g)[0].geometry;
    });
  }
  function caption(text) {
    const canvas = document.createElement('canvas');
    canvas.width = 768; canvas.height = 96;
    const c = canvas.getContext('2d');
    c.fillStyle = 'rgba(23,26,36,.86)';
    c.beginPath(); c.roundRect(4, 4, 760, 88, 30); c.fill();
    c.fillStyle = '#fff8e5'; c.font = 'bold 40px "Segoe UI",sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle';
    c.fillText(text, 384, 50);
    const texture = new T.CanvasTexture(canvas);
    texture.colorSpace = T.SRGBColorSpace;
    const sprite = new T.Sprite(new T.SpriteMaterial({map: texture, depthTest: false, transparent: true}));
    sprite.scale.set(30, 3.75, 1);
    sprite.position.y = 16;
    sprite.renderOrder = 10;
    sprite.userData.ownSprite = true;
    return sprite;
  }

  return {init, setNight, noseFrame, facility, facilityFrame, carouselLoop, loopPoint, aircraft, vehicle, personGeometry, tree, palm, box, cylinder, sphere, decal, line, shape, light, pool, lamp, instance, bake, dispose, caption, label, materials, textures, spec};
})();
