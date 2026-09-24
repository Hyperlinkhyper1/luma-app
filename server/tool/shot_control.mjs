// Installed into every Pagoda scene before its own scripts run (via
// page.evaluateOnNewDocument), so the banner renderer can steer scenes it
// knows nothing about. Every scene is a different model's bespoke
// implementation, so nothing here may rely on a scene's own API; it works by
// owning the three things all of them share:
//
//  - the clock: performance.now, Date and requestAnimationFrame are replaced
//    by a virtual clock. The wall clock reads 11:30 today, so scenes that sync
//    to the real time of day render late morning whenever the server runs.
//    `warp` runs the scene's frame callbacks many times per real frame with
//    rendering suppressed, which fast-forwards frame-counted day cycles
//    (`time += 0.016`) as well as clock-driven ones; `rate` near zero then
//    freezes the scene at the moment the renderer picked.
//  - the renderer: Three.js announces every WebGLRenderer and Scene on
//    window.__THREE_DEVTOOLS__. Wrapping that renderer's render() is how the
//    main camera is found and how the banner pose is applied — just for the
//    draw, restored afterwards so the scene's own controls never notice.
//  - the framing: the pose is fitted to the visible geometry (trimmed
//    percentiles, so a sky dome or a stray far-off prop can't blow it up),
//    from an elevated three-quarter angle through a long lens.
//
// Exposed as window.__lumaShot for the renderer to drive.
export function installShotControl() {
  const realNow = performance.now.bind(performance);
  const RealDate = Date;
  const realRAF = window.requestAnimationFrame.bind(window);

  const st = {
    base: realNow(),
    rbase: realNow(),
    rate: 1,
    warp: false,
    maxSteps: 600,
    budgetMs: 150,
    stepMs: 1000 / 60,
    suppress: false,
    frames: 0,
    lastSteps: 0,
    pose: null,
    cam: null,
    azimuth: null,
    stats: new Map(),
  };

  const vnow = () => st.base + (realNow() - st.rbase) * st.rate;
  const setRate = (r) => {
    st.base = vnow();
    st.rbase = realNow();
    st.rate = r;
  };

  const morning = new RealDate();
  morning.setHours(11, 30, 0, 0);
  const wall0 = morning.getTime();
  const v0 = vnow();
  const wallNow = () => wall0 + (vnow() - v0);
  function VDate(...args) {
    if (!new.target) return new RealDate(wallNow()).toString();
    return args.length ? new RealDate(...args) : new RealDate(wallNow());
  }
  VDate.prototype = RealDate.prototype;
  VDate.now = wallNow;
  VDate.parse = RealDate.parse;
  VDate.UTC = RealDate.UTC;
  window.Date = VDate;
  performance.now = vnow;

  let pending = new Map();
  let seq = 0;
  let scheduled = 0;
  let lastFrame = 0;
  // Software WebGL on a server is expensive and nobody watches these frames
  // live: ten a second is plenty to measure and shoot, and leaves the CPU
  // to whatever else the machine is doing.
  const MIN_FRAME_GAP_MS = 100;
  const schedule = () => {
    if (scheduled) return;
    const wait = Math.max(0, lastFrame + MIN_FRAME_GAP_MS - realNow());
    scheduled = setTimeout(() => realRAF(frame), wait);
  };
  window.requestAnimationFrame = (cb) => {
    const id = ++seq;
    pending.set(id, cb);
    schedule();
    return id;
  };
  window.cancelAnimationFrame = (id) => {
    pending.delete(id);
  };

  function runBatch() {
    const queue = pending;
    pending = new Map();
    const t = vnow();
    for (const cb of queue.values()) {
      try {
        cb(t);
      } catch (e) {
        console.error(e);
      }
    }
  }

  function frame() {
    scheduled = 0;
    lastFrame = realNow();
    if (st.warp) {
      const t0 = realNow();
      let n = 0;
      st.suppress = true;
      try {
        while (pending.size && n < st.maxSteps && realNow() - t0 < st.budgetMs) {
          st.base += st.stepMs;
          runBatch();
          n++;
        }
      } finally {
        st.suppress = false;
      }
      st.lastSteps = n;
    }
    runBatch();
    st.frames++;
    if (pending.size) schedule();
  }

  function note(scene, camera) {
    if (!camera || !scene) return;
    const s = st.stats.get(camera);
    if (s) {
      s.count++;
      s.scene = scene;
    } else if (st.stats.size < 32) {
      st.stats.set(camera, { count: 1, scene });
    }
  }

  function withPose(cam, scene, draw) {
    const p = st.pose;
    const sp = [cam.position.x, cam.position.y, cam.position.z];
    const sq = [cam.quaternion.x, cam.quaternion.y, cam.quaternion.z, cam.quaternion.w];
    const su = [cam.up.x, cam.up.y, cam.up.z];
    const lens = [cam.far, cam.zoom, cam.fov];
    const fog = scene.fog;
    const fogSaved = fog ? [fog.near, fog.far, fog.density] : null;
    cam.position.set(p.px, p.py, p.pz);
    cam.up.set(0, 1, 0);
    cam.lookAt(p.tx, p.ty, p.tz);
    cam.far = Math.max(cam.far, p.far);
    cam.zoom = p.zoom;
    if (p.fov) cam.fov = p.fov;
    cam.updateProjectionMatrix();
    cam.updateMatrixWorld(true);
    if (fog && p.fogScale > 1) {
      if (typeof fog.density === 'number') fog.density = fog.density / p.fogScale;
      else {
        fog.near *= p.fogScale;
        fog.far *= p.fogScale;
      }
    }
    try {
      return draw();
    } finally {
      cam.position.set(sp[0], sp[1], sp[2]);
      cam.quaternion.set(sq[0], sq[1], sq[2], sq[3]);
      cam.up.set(su[0], su[1], su[2]);
      cam.far = lens[0];
      cam.zoom = lens[1];
      if (p.fov) cam.fov = lens[2];
      cam.updateProjectionMatrix();
      cam.updateMatrixWorld(true);
      if (fogSaved) {
        fog.near = fogSaved[0];
        fog.far = fogSaved[1];
        if (typeof fogSaved[2] === 'number') fog.density = fogSaved[2];
      }
    }
  }

  function wrap(renderer) {
    if (renderer.__lumaWrapped || typeof renderer.render !== 'function') return;
    renderer.__lumaWrapped = true;
    const original = renderer.render;
    let depth = 0;
    renderer.render = function (scene, camera) {
      if (st.suppress) return undefined;
      // Nested renders (mirrors, reflections) derive their own cameras from
      // the outer one; only the outermost call is the scene's real view.
      if (depth > 0) return original.apply(this, arguments);
      depth++;
      try {
        note(scene, camera);
        if (st.pose && camera === st.cam) {
          return withPose(camera, scene, () => original.apply(this, arguments));
        }
        return original.apply(this, arguments);
      } finally {
        depth--;
      }
    };
  }

  const devtools = new EventTarget();
  devtools.addEventListener('observe', (e) => {
    const obj = e.detail;
    if (!obj) return;
    // The renderer announces itself before its constructor returns; wrap
    // once it has finished assigning render().
    queueMicrotask(() => {
      if (!obj.isScene && obj.domElement && typeof obj.render === 'function') wrap(obj);
    });
  });
  window.__THREE_DEVTOOLS__ = devtools;

  function mainView() {
    const aspect = window.innerWidth / Math.max(1, window.innerHeight);
    let best = null;
    let bestScore = -1;
    for (const [cam, s] of st.stats) {
      // Post-processing passes draw a lone fullscreen mesh, not a Scene.
      if (!s.scene || !s.scene.isScene) continue;
      if (!(cam.isPerspectiveCamera || cam.isOrthographicCamera)) continue;
      // CubeCamera faces: env-map captures, never the view.
      if (cam.isPerspectiveCamera && Math.abs(cam.fov - 90) < 0.01 && Math.abs(cam.aspect - 1) < 0.01) continue;
      const camAspect = cam.isPerspectiveCamera
        ? cam.aspect
        : Math.abs(cam.right - cam.left) / Math.max(1e-6, Math.abs(cam.top - cam.bottom));
      const fits = Math.abs(camAspect - aspect) / aspect < 0.08;
      const score = s.count * (fits ? 10 : 1);
      if (score > bestScore) {
        bestScore = score;
        best = { cam, scene: s.scene };
      }
    }
    return best;
  }

  function samplePoints(scene) {
    scene.updateMatrixWorld(true);
    const meshes = [];
    const skies = [];
    let total = 0;
    scene.traverseVisible((o) => {
      if (!o.isMesh || !o.geometry || !o.geometry.attributes) return;
      const mat = Array.isArray(o.material) ? o.material[0] : o.material;
      if (!mat || mat.visible === false) return;
      const pos = o.geometry.attributes.position;
      if (!pos || !pos.count) return;
      // BackSide is how skies and domes are drawn: not part of the garden,
      // but the camera has to stay inside them.
      if (mat.side === 1) {
        if (!o.geometry.boundingSphere) o.geometry.computeBoundingSphere();
        const bs = o.geometry.boundingSphere;
        if (bs) {
          const e = o.matrixWorld.elements;
          const scale = Math.max(Math.hypot(e[0], e[1], e[2]), Math.hypot(e[4], e[5], e[6]), Math.hypot(e[8], e[9], e[10]));
          const c = bs.center;
          skies.push({
            x: e[0] * c.x + e[4] * c.y + e[8] * c.z + e[12],
            y: e[1] * c.x + e[5] * c.y + e[9] * c.z + e[13],
            z: e[2] * c.x + e[6] * c.y + e[10] * c.z + e[14],
            r: bs.radius * scale,
          });
        }
        return;
      }
      if (mat.transparent && mat.opacity < 0.35) return;
      const weight = o.isInstancedMesh ? pos.count * (o.count || 0) : pos.count;
      if (!weight) return;
      meshes.push(o);
      total += weight;
    });
    const stride = Math.max(1, total / 60000);
    const xs = [];
    const ys = [];
    const zs = [];
    const push = (e, x, y, z) => {
      xs.push(e[0] * x + e[4] * y + e[8] * z + e[12]);
      ys.push(e[1] * x + e[5] * y + e[9] * z + e[13]);
      zs.push(e[2] * x + e[6] * y + e[10] * z + e[14]);
    };
    for (const o of meshes) {
      const e = o.matrixWorld.elements;
      const pos = o.geometry.attributes.position;
      if (o.isInstancedMesh) {
        const a = o.instanceMatrix.array;
        const step = Math.max(1, Math.round(stride / pos.count));
        for (let i = 0; i < o.count; i += step) {
          const k = i * 16;
          // Pooled, unused instances are parked at zero scale.
          if (a[k] * a[k] + a[k + 1] * a[k + 1] + a[k + 2] * a[k + 2] < 1e-8) continue;
          push(e, a[k + 12], a[k + 13], a[k + 14]);
        }
      } else {
        const step = Math.max(1, Math.round(stride));
        for (let i = 0; i < pos.count; i += step) push(e, pos.getX(i), pos.getY(i), pos.getZ(i));
      }
    }
    return { xs, ys, zs, skies };
  }

  // The extent of one axis: grow outwards from the middle 90% until the
  // points thin out into a gap. A spire or a floating islet close by stays
  // in; a sun disc, a parked object pool or a distant prop across empty sky
  // is cut off however many points it has.
  function extent(sorted) {
    const n = sorted.length;
    const i0 = Math.floor(0.05 * (n - 1));
    const i1 = Math.ceil(0.95 * (n - 1));
    const gap = Math.max(1e-6, (sorted[i1] - sorted[i0]) * 0.25);
    let lo = i0;
    while (lo > 0 && sorted[lo] - sorted[lo - 1] <= gap) lo--;
    let hi = i1;
    while (hi < n - 1 && sorted[hi + 1] - sorted[hi] <= gap) hi++;
    return [sorted[lo], sorted[hi]];
  }

  // The banner look: aimed at the fitted box from an elevated three-quarter
  // angle through a long lens, which flattens the garden towards the
  // isometric look of a hand-framed shot. Orthographic scenes are already
  // isometric and only get their zoom fitted.
  const ELEVATION = (28 * Math.PI) / 180;
  const LENS_FOV = 24;
  const MARGIN = 0.86;

  function fit(box, cam, azimuth, fov) {
    const cx = (box.x0 + box.x1) / 2;
    const cy = (box.y0 + box.y1) / 2;
    const cz = (box.z0 + box.z1) / 2;
    const dx = Math.cos(ELEVATION) * Math.cos(azimuth);
    const dz = Math.cos(ELEVATION) * Math.sin(azimuth);
    const dy = Math.sin(ELEVATION);
    // Camera basis for a lookAt along -d with world up.
    const fx = -dx;
    const fy = -dy;
    const fz = -dz;
    const rl = Math.hypot(fz, fx) || 1;
    const rx = -fz / rl;
    const rz = fx / rl;
    const ux = -rz * fy;
    const uy = rz * fx - rx * fz;
    const uz = rx * fy;
    const corners = [];
    for (const x of [box.x0, box.x1]) for (const y of [box.y0, box.y1]) for (const z of [box.z0, box.z1]) corners.push([x, y, z]);
    const radius = Math.hypot(box.x1 - box.x0, box.y1 - box.y0, box.z1 - box.z0) / 2 || 1;
    const out = { cx, cy, cz, dx, dy, dz, radius };
    if (cam.isOrthographicCamera) {
      let sx = 0;
      let sy = 0;
      for (const [x, y, z] of corners) {
        sx = Math.max(sx, Math.abs((x - cx) * rx + (z - cz) * rz));
        sy = Math.max(sy, Math.abs((x - cx) * ux + (y - cy) * uy + (z - cz) * uz));
      }
      const halfW = Math.abs(cam.right - cam.left) / 2;
      const halfH = Math.abs(cam.top - cam.bottom) / 2;
      out.zoom = Math.min(halfW / (sx / MARGIN || 1), halfH / (sy / MARGIN || 1));
      out.d = radius * 3;
      return out;
    }
    const tanV = Math.tan((fov * Math.PI) / 360);
    const tanH = tanV * cam.aspect;
    const fits = (d) => {
      const px = cx + dx * d;
      const py = cy + dy * d;
      const pz = cz + dz * d;
      for (const [x, y, z] of corners) {
        const vx = x - px;
        const vy = y - py;
        const vz = z - pz;
        const depth = vx * fx + vy * fy + vz * fz;
        if (depth <= cam.near) return false;
        if (Math.abs(vx * rx + vz * rz) / (depth * tanH) > MARGIN) return false;
        if (Math.abs(vx * ux + vy * uy + vz * uz) / (depth * tanV) > MARGIN) return false;
      }
      return true;
    };
    let lo = radius * 0.1;
    let hi = radius * 80;
    for (let i = 0; i < 40; i++) {
      const mid = (lo + hi) / 2;
      if (fits(mid)) hi = mid;
      else lo = mid;
    }
    out.d = hi;
    out.zoom = 1;
    return out;
  }

  // The garden's box. Scenes surround their garden with all sorts of
  // scenery — cloud seas, drifting cloud puffs, a sun disc, distant
  // islands, oversized ground planes — and none of it is labelled, so the
  // garden is found by density: points are bucketed into a coarse grid,
  // the dense cells are joined into connected clusters, and the heaviest
  // cluster is the garden. Its footprint gives the width and depth; the
  // height is then taken over that footprint with the gap rule, so a thin
  // spire (too sparse to count as dense) still makes it into the frame.
  function gardenBox(xs, ys, zs) {
    const n = xs.length;
    const sorted = (a) => Float64Array.from(a).sort();
    const sx = sorted(xs);
    const sy = sorted(ys);
    const sz = sorted(zs);
    const q = (s, p) => s[Math.floor(p * (n - 1))];
    const span = Math.max(q(sx, 0.95) - q(sx, 0.05), q(sy, 0.95) - q(sy, 0.05), q(sz, 0.95) - q(sz, 0.05));
    const cell = Math.max(1e-3, span / 28);
    const key = (i, j, k) => `${i},${j},${k}`;
    const cells = new Map();
    for (let p = 0; p < n; p++) {
      const k = key(Math.floor(xs[p] / cell), Math.floor(ys[p] / cell), Math.floor(zs[p] / cell));
      cells.set(k, (cells.get(k) || 0) + 1);
    }
    let max = 0;
    for (const c of cells.values()) max = Math.max(max, c);
    const dense = new Set();
    for (const [k, c] of cells) if (c >= Math.max(2, max * 0.06)) dense.add(k);
    let best = null;
    let bestMass = -1;
    const seen = new Set();
    for (const start of dense) {
      if (seen.has(start)) continue;
      const cluster = [];
      let mass = 0;
      const stack = [start];
      seen.add(start);
      while (stack.length) {
        const k = stack.pop();
        cluster.push(k);
        mass += cells.get(k);
        const [i, j, l] = k.split(',').map(Number);
        for (let di = -1; di <= 1; di++) {
          for (let dj = -1; dj <= 1; dj++) {
            for (let dl = -1; dl <= 1; dl++) {
              const nk = key(i + di, j + dj, l + dl);
              if (dense.has(nk) && !seen.has(nk)) {
                seen.add(nk);
                stack.push(nk);
              }
            }
          }
        }
      }
      if (mass > bestMass) {
        bestMass = mass;
        best = new Set(cluster);
      }
    }
    if (!best) {
      const [x0, x1] = extent(sx);
      const [y0, y1] = extent(sy);
      const [z0, z1] = extent(sz);
      return { x0, x1, y0, y1, z0, z1 };
    }
    let x0 = Infinity;
    let x1 = -Infinity;
    let z0 = Infinity;
    let z1 = -Infinity;
    for (let p = 0; p < n; p++) {
      if (!best.has(key(Math.floor(xs[p] / cell), Math.floor(ys[p] / cell), Math.floor(zs[p] / cell)))) continue;
      x0 = Math.min(x0, xs[p]);
      x1 = Math.max(x1, xs[p]);
      z0 = Math.min(z0, zs[p]);
      z1 = Math.max(z1, zs[p]);
    }
    const column = [];
    for (let p = 0; p < n; p++) {
      if (xs[p] >= x0 && xs[p] <= x1 && zs[p] >= z0 && zs[p] <= z1) column.push(ys[p]);
    }
    const [y0, y1] = extent(sorted(column));
    return { x0, x1, y0, y1, z0, z1 };
  }

  function frameView() {
    const view = mainView();
    if (!view) return { ok: false, reason: 'no three.js camera seen' };
    const { cam, scene } = view;
    if (cam.parent && !cam.parent.isScene) return { ok: false, reason: 'camera sits in a rig' };
    const { xs, ys, zs, skies } = samplePoints(scene);
    if (xs.length < 50) return { ok: false, reason: `only ${xs.length} points to frame` };
    const box = gardenBox(xs, ys, zs);
    cam.updateMatrixWorld(true);
    const m = cam.matrixWorld.elements;
    const ox = m[12] - (box.x0 + box.x1) / 2;
    const oy = m[13] - (box.y0 + box.y1) / 2;
    const oz = m[14] - (box.z0 + box.z1) / 2;
    // Keep the scene's own side of approach (its author faced the good side
    // towards the camera); only the height, distance and lens are ours.
    if (st.azimuth === null) {
      st.azimuth = Math.hypot(ox, oz) > 1e-3 ? Math.atan2(oz, ox) : Math.PI / 4;
    }
    // A long lens backs the camera off; widen it again if that would put
    // the camera outside a sky dome.
    const insideSkies = (f) =>
      skies.every((s) => Math.hypot(f.cx + f.dx * f.d - s.x, f.cy + f.dy * f.d - s.y, f.cz + f.dz * f.d - s.z) < s.r * 0.85);
    let fov = cam.isPerspectiveCamera ? Math.min(LENS_FOV, cam.fov) : 0;
    let f = fit(box, cam, st.azimuth, fov);
    while (cam.isPerspectiveCamera && !insideSkies(f) && fov < cam.fov) {
      fov = Math.min(cam.fov, fov * 1.2);
      f = fit(box, cam, st.azimuth, fov);
    }
    const px = f.cx + f.dx * f.d;
    const py = f.cy + f.dy * f.d;
    const pz = f.cz + f.dz * f.d;
    let far = f.d + f.radius * 4;
    for (const s of skies) far = Math.max(far, Math.hypot(px - s.x, py - s.y, pz - s.z) + s.r * 1.05);
    const ownDistance = Math.hypot(ox, oy, oz) || f.d;
    st.cam = cam;
    st.pose = {
      px,
      py,
      pz,
      tx: f.cx,
      ty: f.cy,
      tz: f.cz,
      far,
      zoom: f.zoom,
      fov: cam.isPerspectiveCamera ? fov : 0,
      // Fog was tuned for the scene's own camera distance; scale it with
      // ours so the garden does not vanish into it.
      fogScale: Math.max(1, f.d / ownDistance),
    };
    return {
      ok: true,
      points: xs.length,
      camera: cam.isPerspectiveCamera ? `perspective, fov ${fov.toFixed(0)}` : `orthographic, zoom ${f.zoom.toFixed(2)}`,
      distance: Number(f.d.toFixed(1)),
      skies: skies.length,
      box: [box.x0, box.x1, box.y0, box.y1, box.z0, box.z1].map(Math.round).join(","),
    };
  }

  window.__lumaShot = {
    setWarp(on, maxSteps) {
      st.warp = !!on;
      if (maxSteps) st.maxSteps = maxSteps;
    },
    freeze() {
      st.warp = false;
      setRate(0.02);
    },
    virtualMs: () => vnow(),
    lastSteps: () => st.lastSteps,
    frame: frameView,
    waitFrames(n) {
      return new Promise((resolve) => {
        const start = st.frames;
        const tick = () => (st.frames - start >= n ? resolve(true) : realRAF(tick));
        realRAF(tick);
        setTimeout(() => resolve(false), 30000);
      });
    },
  };
}
