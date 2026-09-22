/* Airform asset studio: a dependency-free port of the React studio.
   Each model file is a plain `function name(g, w, d)` that only calls the
   donor helpers box / cylinder / sphere / light / label; it is run verbatim
   against the preview stand-ins below. The page is assembled into one
   self-contained HTML file (see lib/features/plugins/installed/ai_usage/assets/asset_studio.dart), so window.STUDIO
   carries the catalogue, and every model's source sits in its own
   text/plain script block tagged with a data-model attribute. */
(() => {
  'use strict';
  const T = THREE;
  const config = window.STUDIO || {};
  const catalog = config.catalog || [];
  const $ = (id) => document.getElementById(id);
  const HELPER_NAMES = ['box', 'cylinder', 'sphere', 'light', 'label'];
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ── Icons (Lucide, ISC) ─────────────────────────────────────────────────
  const ICONS = {
    box: '<path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="m3.3 7 8.7 5 8.7-5"/><path d="M12 22V12"/>',
    code2: '<path d="m18 16 4-4-4-4"/><path d="m6 8-4 4 4 4"/><path d="m14.5 4-5 16"/>',
    chevronDown: '<path d="m6 9 6 6 6-6"/>',
    chevronRight: '<path d="m9 18 6-6-6-6"/>',
    expand: '<path d="m15 15 6 6"/><path d="m15 9 6-6"/><path d="M21 16v5h-5"/><path d="M21 8V3h-5"/><path d="M3 16v5h5"/><path d="m3 21 6-6"/><path d="M3 8V3h5"/><path d="M9 9 3 3"/>',
    minimize2: '<path d="m14 10 7-7"/><path d="M20 10h-6V4"/><path d="m3 21 7-7"/><path d="M4 14h6v6"/>',
    mousePointer2: '<path d="M4.04 4.69a.5.5 0 0 1 .65-.65l16 6.5a.5.5 0 0 1-.06.95l-6.13 1.58a2 2 0 0 0-1.43 1.43l-1.58 6.13a.5.5 0 0 1-.95.06z"/>',
    hand: '<path d="M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2"/><path d="M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2"/><path d="M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8"/><path d="M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15"/>',
    ruler: '<path d="M21.3 15.3a2.4 2.4 0 0 1 0 3.4l-2.6 2.6a2.4 2.4 0 0 1-3.4 0L2.7 8.7a2.41 2.41 0 0 1 0-3.4l2.6-2.6a2.41 2.41 0 0 1 3.4 0Z"/><path d="m14.5 12.5 2-2"/><path d="m11.5 9.5 2-2"/><path d="m8.5 6.5 2-2"/><path d="m17.5 15.5 2-2"/>',
    grid2x2: '<path d="M12 3v18"/><path d="M3 12h18"/><rect x="3" y="3" width="18" height="18" rx="2"/>',
    mouse: '<rect x="5" y="2" width="14" height="20" rx="7"/><path d="M12 6v4"/>',
    play: '<polygon points="6 3 20 12 6 21 6 3"/>',
    pause: '<rect x="14" y="4" width="4" height="16" rx="1"/><rect x="6" y="4" width="4" height="16" rx="1"/>',
    camera: '<path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/><circle cx="12" cy="13" r="3"/>',
    rotateCcw: '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>',
    rotateCw: '<path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/>',
    layers2: '<path d="m16.02 12 5.48 3.13a1 1 0 0 1 0 1.74L13 21.74a2 2 0 0 1-2 0l-8.5-4.87a1 1 0 0 1 0-1.74L7.98 12"/><path d="M13 13.74a2 2 0 0 1-2 0L2.5 8.87a1 1 0 0 1 0-1.74L11 2.26a2 2 0 0 1 2 0l8.5 4.87a1 1 0 0 1 0 1.74Z"/>',
    minus: '<path d="M5 12h14"/>',
    plus: '<path d="M5 12h14"/><path d="M12 5v14"/>',
    sliders: '<path d="M21 4h-7"/><path d="M10 4H3"/><path d="M21 12h-9"/><path d="M8 12H3"/><path d="M21 20h-5"/><path d="M12 20H3"/><path d="M14 2v4"/><path d="M8 10v4"/><path d="M16 18v4"/>',
    lock: '<circle cx="12" cy="16" r="1"/><rect x="3" y="10" width="18" height="12" rx="2"/><path d="M7 10V7a5 5 0 0 1 10 0v3"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    copy: '<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
    shieldCheck: '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
    circleCheck: '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
    alertCircle: '<circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/>',
    info: '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>',
    fileCode2: '<path d="M4 22h14a2 2 0 0 0 2-2V7l-5-5H6a2 2 0 0 0-2 2v4"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="m5 12-3 3 3 3"/><path d="m9 18 3-3-3-3"/>',
    x: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
    arrowUpRight: '<path d="M7 7h10v10"/><path d="M7 17 17 7"/>',
    arrowDownToLine: '<path d="M12 17V3"/><path d="m6 11 6 6 6-6"/><path d="M19 21H5"/>',
    plane: '<path d="M17.8 19.2 16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.1-1.1.5l-.3.5c-.2.5-.1 1 .3 1.3L9 12l-2 3H4l-1 1 3 2 2 3 1-1v-3l3-2 3.5 5.3c.3.4.8.5 1.3.3l.5-.2c.4-.3.6-.7.5-1.2z"/>',
    circleHelp: '<circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><path d="M12 17h.01"/>',
  };
  function icon(name, size = 16, extra = '') {
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" ${extra}>${ICONS[name] || ''}</svg>`;
  }
  function hydrateIcons(root = document) {
    for (const el of root.querySelectorAll('i[data-icon]')) {
      const cls = el.className ? `class="${el.className}"` : '';
      el.outerHTML = icon(el.dataset.icon, Number(el.dataset.size) || 16, cls);
    }
  }
  const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c]));

  // ── Theme ───────────────────────────────────────────────────────────────
  /* The stylesheet carries both palettes (see its token block); the scene
     colours live here because three.js cannot read CSS variables. luma sends
     the theme it is using, and a downloaded copy follows the browser. */
  const SCENE_COLORS = {
    light: {background: 0xeff1ec, grid: [0xcdd5c9, 0xd6dcd1], contact: 0x5e7062, contactOpacity: .018, outline: 0x729c89, ticks: 0x859d89},
    dark: {background: 0x171a16, grid: [0x333c34, 0x2a322c], contact: 0x000000, contactOpacity: .05, outline: 0x6f9a86, ticks: 0x6d8472},
  };
  const media = window.matchMedia('(prefers-color-scheme: dark)');
  const themeSetting = () => config.theme || 'auto';
  const isDark = () => themeSetting() === 'dark' || (themeSetting() === 'auto' && media.matches);
  function applyTheme() {
    document.documentElement.dataset.theme = isDark() ? 'dark' : 'light';
    sceneApi?.setTheme(isDark());
  }
  media.addEventListener('change', () => { if (themeSetting() === 'auto') applyTheme(); });
  // luma re-sends the theme when the app's own theme changes.
  const receiveTheme = (value) => { config.theme = value; applyTheme(); };
  window.studioReceive = (message) => { if (message?.type === 'theme') receiveTheme(message.theme); };
  window.chrome?.webview?.addEventListener?.('message', (event) => {
    try {
      const message = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
      if (message?.type === 'theme') receiveTheme(message.theme);
    } catch { /* not ours */ }
  });

  // ── Palettes ────────────────────────────────────────────────────────────
  const swatch = (name, color, light) => ({name, color, code: `0x${color.slice(1).toLowerCase()}`, light});
  const PALETTES = {
    jewelry: [swatch('Warm ivory', '#F0EBE1', true), swatch('Dark luxury', '#292D30', false), swatch('Champagne gold', '#C6A15B', true), swatch('Velvet emerald', '#405344', false), swatch('Velvet burgundy', '#704541', false), swatch('Jewelry cool light', '#DFF4F2', true)],
    default: [swatch('Body', '#D8D3C6', true), swatch('Teal accent', '#2A6D7A', false), swatch('Screen', '#1B2E36', false), swatch('Emission', '#7FE0E8', true), swatch('Base', '#3B4347', false), swatch('Safety strip', '#F2C230', true)],
    vip: [swatch('Smoked walnut', '#221C17', false), swatch('Acoustic charcoal', '#1C1918', false), swatch('Burnished brass', '#C59A4A', true), swatch('Bordeaux velvet', '#48151B', false), swatch('Cognac leather', '#6A3F22', false), swatch('Amber downlight', '#FFC882', true)],
    coffee: [swatch('Kiosk ivory', '#E5E0D5', true), swatch('Roast wood', '#805D42', false), swatch('Espresso', '#343B3E', false), swatch('Bean brown', '#704C36', false), swatch('Apron green', '#47704F', false), swatch('Warm light', '#FFD99A', true)],
    arcade: [swatch('Arcade dark', '#292D30', false), swatch('Neon purple', '#795A9B', false), swatch('Laser pink', '#C85F8F', true), swatch('Cyber blue', '#3976A8', false), swatch('Neon glow', '#7FE0E8', true), swatch('Speed yellow', '#E2C84B', true)],
    casino: [swatch('Casino charcoal', '#29272B', false), swatch('Deep red', '#703D46', false), swatch('Casino gold', '#C6A15B', true), swatch('Table green', '#3F6650', false), swatch('Midnight blue', '#394C60', false), swatch('Warm glow', '#FFC978', true)],
  };

  // ── Catalogue ───────────────────────────────────────────────────────────
  for (const a of catalog) {
    const el = document.querySelector(`script[data-model="${a.id}"]`);
    a.source = el ? el.textContent.trim() : `function ${a.functionName}(g,w,d){}`;
    a.facilityLine = `else if (k==='${a.id}') ${a.functionName}(g,w,d);`;
    a.catalogLine = `AirportFacilityDef('${a.id}','${a.name}',${a.width},${a.depth},${a.height},${a.price},'${a.description}', interior:true, category:'${a.category}'),`;
    a.fullSource = `${a.source}\n\n${a.facilityLine}\n${a.catalogLine}\n`;
  }
  const findAsset = (id) => catalog.find((a) => a.id === id) || catalog[0];

  // ── Preview host: stand-ins for the donor helpers ──────────────────────
  function createPreviewHost() {
    const paint = new T.MeshStandardMaterial({vertexColors: true, flatShading: true, roughness: .83, metalness: 0});
    const metal = new T.MeshStandardMaterial({vertexColors: true, flatShading: true, roughness: .63, metalness: .2});
    const glass = new T.MeshStandardMaterial({vertexColors: true, flatShading: true, roughness: .2, metalness: .05, transparent: true, opacity: .32, depthWrite: false});
    const emission = new T.MeshBasicMaterial({vertexColors: true, toneMapped: false});
    const materials = {paint, metal, glass};
    const functions = new Map();

    function paintGeometry(indexed, color) {
      const geometry = indexed.toNonIndexed();
      indexed.dispose();
      geometry.deleteAttribute('uv');
      const value = new T.Color(color);
      const colors = new Float32Array(geometry.getAttribute('position').count * 3);
      for (let i = 0; i < colors.length; i += 3) { colors[i] = value.r; colors[i + 1] = value.g; colors[i + 2] = value.b; }
      geometry.setAttribute('color', new T.BufferAttribute(colors, 3));
      return geometry;
    }
    const coloredBox = (color) => paintGeometry(new T.BoxGeometry(1, 1, 1), color);
    const box = (g, w, h, d, x, y, z, color, kind = 'paint') => {
      const mesh = new T.Mesh(coloredBox(color), materials[kind] || paint);
      mesh.scale.set(w, h, d); mesh.position.set(x, y, z); g.add(mesh); return mesh;
    };
    const cylinder = (g, r, h, x, y, z, color, kind = 'paint', rt = r, segments = 8) => {
      const mesh = new T.Mesh(paintGeometry(new T.CylinderGeometry(rt, r, h, Math.max(3, Math.min(16, Math.round(segments)))), color), materials[kind] || paint);
      mesh.position.set(x, y, z); g.add(mesh); return mesh;
    };
    const sphere = (g, x, y, z, sx, sy, sz, color, kind = 'paint') => {
      const mesh = new T.Mesh(paintGeometry(new T.SphereGeometry(1, 8, 6), color), materials[kind] || paint);
      mesh.scale.set(sx, sy, sz); mesh.position.set(x, y, z); g.add(mesh); return mesh;
    };
    const light = (g, x, y, z, color = 0xfff4d6, size = .35) => {
      const mesh = new T.Mesh(coloredBox(color), emission);
      mesh.scale.setScalar(size); mesh.position.set(x, y, z); g.add(mesh); return mesh;
    };
    // Labels need fonts in the donor; the preview stands in with a flat plate.
    const label = (g, text, x, y, z, size = 6, color = '#f9fcf6', options = {}) => {
      const plate = new T.Mesh(coloredBox(new T.Color(color).getHex()), emission);
      const width = options.width ?? Math.max(.2, String(text).length * size * .01);
      plate.scale.set(width, options.ground ? .005 : size * .015, options.ground ? size * .015 : .005);
      plate.position.set(x, y, z);
      plate.rotation.y = options.rotY ?? 0;
      g.add(plate);
      return plate;
    };

    return {
      build(asset, width, depth) {
        let fn = functions.get(asset.id);
        if (!fn) {
          fn = new Function(...HELPER_NAMES, `${asset.source}\nreturn ${asset.functionName};`)(box, cylinder, sphere, light, label);
          functions.set(asset.id, fn);
        }
        const group = new T.Group();
        group.name = asset.id;
        fn(group, width, depth);
        return group;
      },
      setDisplay(wireframe, glowing) {
        for (const m of [paint, metal, glass, emission]) m.wireframe = wireframe;
        emission.color.setHex(glowing ? 0xffffff : 0x456164);
      },
    };
  }
  function disposeModel(group) { group.traverse((o) => { if (o.isMesh) o.geometry.dispose(); }); }

  function inspectModel(group, width, depth, limits = {}) {
    group.updateMatrixWorld(true);
    const rotations = [true, true, true, true];
    const point = new T.Vector3();
    const tolerance = .00001;
    let vertices = 0, colorsOnly = true, mergeSafe = true, signature = null;
    group.traverse((object) => {
      if (!object.isMesh) return;
      const geometry = object.geometry.clone().applyMatrix4(object.matrixWorld);
      const position = geometry.getAttribute('position');
      vertices += position.count;
      colorsOnly = colorsOnly && geometry.hasAttribute('color') && !geometry.hasAttribute('uv');
      // What mergeGeometries needs: one attribute set, all indexed or none.
      const sig = `${Object.keys(geometry.attributes).sort().join(',')}|${geometry.index ? 'i' : 'n'}`;
      if (signature === null) signature = sig; else if (sig !== signature) mergeSafe = false;
      for (let r = 0; r < 4; r++) {
        const angle = r * Math.PI / 2, cos = Math.cos(angle), sin = Math.sin(angle);
        const rw = r % 2 ? depth : width, rd = r % 2 ? width : depth;
        for (let i = 0; i < position.count; i++) {
          point.fromBufferAttribute(position, i);
          const px = point.x - width / 2, pz = point.z - depth / 2;
          const x = cos * px + sin * pz + rw / 2, z = -sin * px + cos * pz + rd / 2;
          if (x < -tolerance || x > rw + tolerance || z < -tolerance || z > rd + tolerance) rotations[r] = false;
        }
      }
      geometry.dispose();
    });
    const bounds = new T.Box3().setFromObject(group);
    mergeSafe = mergeSafe && signature !== null && signature.includes('color');
    const maxHeight = limits.maxHeight ?? 2.2, maxCalls = limits.maxCalls ?? 40;
    const helperCalls = group.children.length;
    const grounded = bounds.min.y >= -tolerance && bounds.min.y < tolerance;
    const heightValid = bounds.max.y <= maxHeight + tolerance;
    return {
      helperCalls, triangles: vertices / 3, vertices, height: bounds.max.y,
      width: bounds.max.x - bounds.min.x, depth: bounds.max.z - bounds.min.z,
      rotations, grounded, heightValid, colorsOnly, mergeSafe,
      passed: helperCalls < maxCalls && grounded && heightValid && colorsOnly && mergeSafe && rotations.every(Boolean),
    };
  }

  // ── Orbit controls (the subset of OrbitControls the studio uses) ────────
  function createControls(camera, element, onChange) {
    const target = new T.Vector3();
    const spherical = new T.Spherical();
    const delta = {theta: 0, phi: 0};
    const panOffset = new T.Vector3();
    const pointers = new Map();
    const offset = new T.Vector3();
    const v = new T.Vector3();
    const api = {
      target, enabled: true, autoRotate: false, autoRotateSpeed: .8, leftPans: false,
      minZoom: .5, maxZoom: 2.1, minPolar: .01, maxPolar: Math.PI / 2, damping: .09,
      onStart: null,
      update(dt = 1 / 60) {
        offset.copy(camera.position).sub(target);
        spherical.setFromVector3(offset);
        if (api.autoRotate && pointers.size === 0) delta.theta -= 2 * Math.PI / 60 * api.autoRotateSpeed * dt;
        spherical.theta += delta.theta * api.damping * 4;
        spherical.phi += delta.phi * api.damping * 4;
        spherical.phi = Math.max(api.minPolar, Math.min(api.maxPolar, spherical.phi));
        spherical.makeSafe();
        target.addScaledVector(panOffset, api.damping * 4);
        offset.setFromSpherical(spherical);
        const before = camera.position.clone();
        camera.position.copy(target).add(offset);
        camera.lookAt(target);
        delta.theta *= 1 - api.damping * 4; delta.phi *= 1 - api.damping * 4;
        panOffset.multiplyScalar(1 - api.damping * 4);
        if (Math.abs(delta.theta) < 1e-6) delta.theta = 0;
        if (Math.abs(delta.phi) < 1e-6) delta.phi = 0;
        if (panOffset.lengthSq() < 1e-12) panOffset.set(0, 0, 0);
        const moved = before.distanceToSquared(camera.position) > 1e-12;
        if (moved) onChange();
        return moved;
      },
      setZoom(z) {
        camera.zoom = Math.max(api.minZoom, Math.min(api.maxZoom, z));
        camera.updateProjectionMatrix();
        onChange();
      },
    };
    function pan(dx, dy) {
      const h = element.clientHeight || 1;
      const worldPerPixel = (camera.top - camera.bottom) / camera.zoom / h;
      v.setFromMatrixColumn(camera.matrix, 0).multiplyScalar(-dx * worldPerPixel);
      panOffset.add(v);
      v.setFromMatrixColumn(camera.matrix, 1).multiplyScalar(dy * worldPerPixel);
      panOffset.add(v);
    }
    function rotate(dx, dy) {
      const h = element.clientHeight || 1;
      delta.theta -= 2 * Math.PI * dx / h * .65;
      delta.phi -= 2 * Math.PI * dy / h * .65;
    }
    let mode = null, pinch = 0;
    element.addEventListener('contextmenu', (e) => e.preventDefault());
    element.addEventListener('pointerdown', (e) => {
      if (!api.enabled) return;
      element.setPointerCapture(e.pointerId);
      pointers.set(e.pointerId, {x: e.clientX, y: e.clientY});
      if (pointers.size === 2) {
        const [a, b] = [...pointers.values()];
        pinch = Math.hypot(a.x - b.x, a.y - b.y);
        mode = 'pinch';
      } else {
        mode = e.button === 2 || e.button === 1 || e.shiftKey || api.leftPans ? 'pan' : 'rotate';
      }
      api.onStart?.();
    });
    element.addEventListener('pointermove', (e) => {
      const last = pointers.get(e.pointerId);
      if (!last) return;
      const dx = e.clientX - last.x, dy = e.clientY - last.y;
      pointers.set(e.pointerId, {x: e.clientX, y: e.clientY});
      if (mode === 'pinch' && pointers.size === 2) {
        const [a, b] = [...pointers.values()];
        const d = Math.hypot(a.x - b.x, a.y - b.y);
        if (pinch > 0) api.setZoom(camera.zoom * d / pinch);
        pinch = d;
      } else if (mode === 'pan') pan(dx, dy);
      else if (mode === 'rotate') rotate(dx, dy);
      onChange();
    });
    const end = (e) => {
      pointers.delete(e.pointerId);
      if (pointers.size === 0) mode = null;
      else if (pointers.size === 1) mode = api.leftPans ? 'pan' : 'rotate';
    };
    element.addEventListener('pointerup', end);
    element.addEventListener('pointercancel', end);
    element.addEventListener('wheel', (e) => {
      if (!api.enabled) return;
      e.preventDefault();
      api.onStart?.();
      api.setZoom(camera.zoom * Math.pow(.95, Math.sign(e.deltaY) * Math.min(3, Math.abs(e.deltaY) / 50 || 1)));
    }, {passive: false});
    return api;
  }

  // ── Scene ───────────────────────────────────────────────────────────────
  function createScene(container, initial, callbacks) {
    const host = createPreviewHost();
    let model = host.build(initial.asset, initial.width, initial.depth);
    callbacks.onReport(inspectModel(model, initial.width, initial.depth, initial.asset));

    let renderer;
    try {
      renderer = new T.WebGLRenderer({antialias: true, alpha: false, preserveDrawingBuffer: true});
    } catch {
      disposeModel(model);
      return null;
    }
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.outputColorSpace = T.SRGBColorSpace;
    renderer.toneMapping = T.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.05;
    renderer.domElement.setAttribute('role', 'img');
    renderer.domElement.setAttribute('aria-label', 'Interactive 3D model. Drag to orbit and scroll to zoom.');
    container.appendChild(renderer.domElement);

    const scene = new T.Scene();
    let colors = SCENE_COLORS[isDark() ? 'dark' : 'light'];
    scene.background = new T.Color(colors.background);
    scene.fog = new T.Fog(colors.background, 16, 35);
    const camera = new T.OrthographicCamera(-3, 3, 1.575, -1.575, .1, 80);
    camera.position.set(4.8, 4.8, 7.2);
    let dirty = true;
    let lastZoom = 100;
    let cameraMoving = false;
    const controls = createControls(camera, renderer.domElement, () => {
      dirty = true;
      const zoom = Math.round(camera.zoom * 100);
      if (zoom !== lastZoom) { lastZoom = zoom; callbacks.onZoom(zoom); }
    });
    controls.target.set(0, .94, 0);
    controls.onStart = () => { cameraMoving = false; };
    controls.update();

    scene.add(new T.HemisphereLight(0xffffff, 0xa8b39f, 1.9));
    const key = new T.DirectionalLight(0xfffbf1, 3.1);
    key.position.set(-3.5, 7, 5);
    scene.add(key);
    const fill = new T.DirectionalLight(0xe5f2f6, .6);
    fill.position.set(4, 3, -4);
    scene.add(fill);

    const floor = new T.Mesh(new T.PlaneGeometry(120, 120), new T.MeshBasicMaterial({color: colors.background, toneMapped: false}));
    floor.rotation.x = -Math.PI / 2;
    scene.add(floor);
    let grid;
    function buildGrid() {
      if (grid) { scene.remove(grid); grid.geometry.dispose(); grid.material.dispose(); }
      grid = new T.GridHelper(36, 72, colors.grid[0], colors.grid[1]);
      grid.position.y = .001;
      grid.material.toneMapped = false;
      grid.material.transparent = true;
      grid.material.opacity = .6;
      grid.visible = active ? active.grid : initial.grid;
      scene.add(grid);
    }

    // A preview-only contact patch, made from geometry rather than a shadow map.
    const contact = new T.Group();
    const contactGeometry = new T.CircleGeometry(1, 48);
    contactGeometry.rotateX(-Math.PI / 2);
    const contactMaterial = new T.MeshBasicMaterial({color: colors.contact, transparent: true, opacity: colors.contactOpacity, depthWrite: false, toneMapped: false});
    for (let i = 0; i < 24; i++) {
      const patch = new T.Mesh(contactGeometry, contactMaterial);
      const size = 1.42 - i * .025;
      patch.scale.set(size, 1, size * .55);
      patch.position.set(.14, .002 + i * .00001, -.035);
      contact.add(patch);
    }
    scene.add(contact);

    const pivot = new T.Group();
    model.position.set(-initial.width / 2, 0, -initial.depth / 2);
    pivot.add(model);
    scene.add(pivot);
    let guides = new T.Group();
    pivot.add(guides);
    const widthAnchor = new T.Vector3(), depthAnchor = new T.Vector3();
    const projected = new T.Vector3();
    const destination = new T.Vector3(), destinationTarget = new T.Vector3(0, .94, 0);
    let width = 1, height = 1;
    let active = {...initial};
    let targetRotation = initial.rotation * Math.PI / 2;
    pivot.rotation.y = targetRotation - (reducedMotion ? 0 : .12);
    let lastTime = 0;

    function buildGuides(w, d) {
      guides.traverse((o) => { if (o.isLine) { o.geometry.dispose(); o.material.dispose(); } });
      pivot.remove(guides);
      guides = new T.Group();
      const hw = w / 2, hd = d / 2, y = .007;
      const points = [new T.Vector3(-hw, y, -hd), new T.Vector3(hw, y, -hd), new T.Vector3(hw, y, hd), new T.Vector3(-hw, y, hd), new T.Vector3(-hw, y, -hd)];
      const outline = new T.Line(new T.BufferGeometry().setFromPoints(points), new T.LineDashedMaterial({color: colors.outline, dashSize: .065, gapSize: .042, transparent: true, opacity: .8}));
      outline.computeLineDistances();
      guides.add(outline);
      const dims = [
        -hw, y, hd + .25, hw, y, hd + .25, -hw, y, hd + .20, -hw, y, hd + .30, hw, y, hd + .20, hw, y, hd + .30,
        hw + .25, y, -hd, hw + .25, y, hd, hw + .20, y, -hd, hw + .30, y, -hd, hw + .20, y, hd, hw + .30, y, hd,
      ];
      const dimsGeometry = new T.BufferGeometry();
      dimsGeometry.setAttribute('position', new T.Float32BufferAttribute(dims, 3));
      guides.add(new T.LineSegments(dimsGeometry, new T.LineBasicMaterial({color: colors.ticks, transparent: true, opacity: .7})));
      pivot.add(guides);
      widthAnchor.set(0, .01, hd + .34);
      depthAnchor.set(hw + .37, .01, 0);
      contact.scale.set(w / 2, 1, d);
      guides.visible = active.bounds;
      dirty = true;
    }

    function setCamera(view) {
      destinationTarget.set(0, .94, 0);
      if (view === 'front') destination.set(0, .94, 9);
      else if (view === 'right') destination.set(9, .94, 0);
      else if (view === 'back') destination.set(0, .94, -9);
      else if (view === 'top') { destination.set(0, 9, .001); destinationTarget.set(0, 0, 0); }
      else destination.set(4.8, 4.8, 7.2);
      if (reducedMotion) {
        camera.position.copy(destination);
        controls.target.copy(destinationTarget);
        controls.update();
      }
      cameraMoving = !reducedMotion;
      dirty = true;
    }

    function resize() {
      width = Math.max(container.clientWidth, 1);
      height = Math.max(container.clientHeight, 1);
      const aspect = width / height;
      const fitHeight = active.width * .38 + active.depth * .72 + 2.4;
      const fitWidth = active.width * 1.08 + active.depth * .75 + 1.2;
      const span = Math.max(fitHeight, fitWidth / aspect);
      camera.left = -span * aspect / 2; camera.right = span * aspect / 2;
      camera.top = span / 2; camera.bottom = -span / 2;
      // Big rooms need a longer lens and a farther fog than a kiosk.
      const reach = Math.max(9, span * 2.2);
      camera.far = reach * 8;
      scene.fog.near = reach * 1.8; scene.fog.far = reach * 3.9;
      camera.updateProjectionMatrix();
      renderer.setSize(width, height);
      dirty = true;
    }

    function update(next) {
      const rebuilt = next.asset.id !== active.asset.id || next.width !== active.width || next.depth !== active.depth;
      if (rebuilt) {
        pivot.remove(model);
        disposeModel(model);
        model = host.build(next.asset, next.width, next.depth);
        callbacks.onReport(inspectModel(model, next.width, next.depth, next.asset));
        model.position.set(-next.width / 2, 0, -next.depth / 2);
        pivot.add(model);
      }
      if (next.rotation !== active.rotation) {
        const desired = next.rotation * Math.PI / 2;
        const turn = Math.atan2(Math.sin(desired - pivot.rotation.y), Math.cos(desired - pivot.rotation.y));
        targetRotation = pivot.rotation.y + turn;
      }
      const viewChanged = next.view !== active.view;
      active = {...next};
      if (rebuilt) buildGuides(next.width, next.depth);
      if (viewChanged) setCamera(next.view);
      grid.visible = next.grid;
      guides.visible = next.bounds;
      controls.autoRotate = next.autoRotate;
      controls.leftPans = next.interaction === 'pan';
      host.setDisplay(next.wireframe, next.emission);
      if (rebuilt) resize();
      dirty = true;
    }

    function place(el, anchor) {
      if (!el) return;
      projected.copy(anchor).applyMatrix4(pivot.matrixWorld).project(camera);
      el.style.left = `${(projected.x + 1) * width / 2}px`;
      el.style.top = `${(-projected.y + 1) * height / 2}px`;
    }

    new ResizeObserver(resize).observe(container);
    buildGrid();
    buildGuides(initial.width, initial.depth);
    update(initial);
    if (initial.view !== 'isometric') setCamera(initial.view);
    resize();

    function animate(time) {
      requestAnimationFrame(animate);
      const dt = Math.min((time - lastTime) / 1000, .05);
      lastTime = time;
      if (cameraMoving) {
        camera.position.lerp(destination, .13);
        controls.target.lerp(destinationTarget, .13);
        if (camera.position.distanceToSquared(destination) < .000001) {
          camera.position.copy(destination);
          controls.target.copy(destinationTarget);
          cameraMoving = false;
        }
        dirty = true;
      }
      if (Math.abs(pivot.rotation.y - targetRotation) > .0001) {
        pivot.rotation.y += (targetRotation - pivot.rotation.y) * (reducedMotion ? 1 : .13);
        contact.rotation.y = pivot.rotation.y;
        dirty = true;
      }
      controls.update(dt || 1 / 60);
      if (dirty) {
        renderer.render(scene, camera);
        if (active.bounds) { place(callbacks.widthLabel, widthAnchor); place(callbacks.depthLabel, depthAnchor); }
        dirty = false;
      }
    }
    requestAnimationFrame(animate);

    return {
      update,
      setTheme(dark) {
        const next = SCENE_COLORS[dark ? 'dark' : 'light'];
        if (next === colors) return;
        colors = next;
        scene.background.setHex(colors.background);
        scene.fog.color.setHex(colors.background);
        floor.material.color.setHex(colors.background);
        contactMaterial.color.setHex(colors.contact);
        contactMaterial.opacity = colors.contactOpacity;
        buildGrid();
        buildGuides(active.width, active.depth);
        dirty = true;
      },
      reset() {
        camera.zoom = 1;
        camera.updateProjectionMatrix();
        setCamera('isometric');
        lastZoom = 100;
        callbacks.onZoom(100);
        dirty = true;
      },
      zoomBy(amount) { controls.setZoom(camera.zoom + amount / 100); },
      validate() {
        const test = host.build(active.asset, active.width, active.depth);
        const report = inspectModel(test, active.width, active.depth, active.asset);
        disposeModel(test);
        callbacks.onReport(report);
        return report;
      },
      capture() {
        try { renderer.render(scene, camera); return renderer.domElement.toDataURL('image/png'); } catch { return null; }
      },
    };
  }

  // ── Host bridge: luma's webview saves files for us ──────────────────────
  function postToHost(message) {
    const json = JSON.stringify(message);
    if (window.chrome?.webview?.postMessage) { window.chrome.webview.postMessage(json); return true; }
    if (window.flutter_inappwebview?.callHandler) { window.flutter_inappwebview.callHandler('studio', json); return true; }
    return false;
  }
  function saveFile(name, mime, dataUrl) {
    if (postToHost({type: 'save', name, mime, dataUrl})) return;
    const anchor = document.createElement('a');
    anchor.href = dataUrl;
    anchor.download = name;
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
  }
  const textDataUrl = (text, mime) => `data:${mime};base64,${btoa(unescape(encodeURIComponent(text)))}`;
  async function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      try { await navigator.clipboard.writeText(text); return; } catch { /* fall through */ }
    }
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    const copied = document.execCommand('copy');
    textarea.remove();
    if (!copied && !postToHost({type: 'copy', text})) throw new Error('Clipboard unavailable');
  }

  // ── State ───────────────────────────────────────────────────────────────
  const DEFAULTS = {width: 12, depth: 10, grid: true, bounds: true, emission: true};
  function loadSettings() {
    try {
      const value = JSON.parse(localStorage.getItem('airform.ticket-machine') || 'null');
      if (!value) return {...DEFAULTS};
      return {
        width: typeof value.width === 'number' && value.width >= .5 && value.width <= 16 ? value.width : DEFAULTS.width,
        depth: typeof value.depth === 'number' && value.depth >= .5 && value.depth <= 10 ? value.depth : DEFAULTS.depth,
        grid: typeof value.grid === 'boolean' ? value.grid : true,
        bounds: typeof value.bounds === 'boolean' ? value.bounds : true,
        emission: typeof value.emission === 'boolean' ? value.emission : true,
      };
    } catch { return {...DEFAULTS}; }
  }
  let stored = null;
  try { stored = localStorage.getItem('airform.asset'); } catch { /* private mode */ }
  const initialAsset = findAsset(config.asset || stored);
  const state = {
    settings: loadSettings(),
    assetId: initialAsset.id,
    tab: 'preview', inspectorTab: 'properties', rotation: 0, view: 'isometric',
    wireframe: false, autoRotate: false, interaction: 'orbit', zoom: 100,
    selectedColor: 0, report: null, expanded: false, saved: true,
  };
  if (stored !== initialAsset.id) { state.settings.width = initialAsset.width; state.settings.depth = initialAsset.depth; }
  const asset = () => findAsset(state.assetId);
  const palette = () => PALETTES[asset().palette] || PALETTES.default;
  let sceneApi = null;

  function sceneOptions() {
    return {...state.settings, asset: asset(), rotation: state.rotation, view: state.view, wireframe: state.wireframe, autoRotate: state.autoRotate, interaction: state.interaction};
  }
  function set(patch) {
    Object.assign(state, patch);
    if (patch.settings) {
      try { localStorage.setItem('airform.ticket-machine', JSON.stringify(state.settings)); state.saved = true; } catch { state.saved = false; }
    }
    if (patch.assetId) { try { localStorage.setItem('airform.asset', state.assetId); } catch { /* session only */ } }
    render();
    sceneApi?.update(sceneOptions());
  }
  const setSettings = (patch) => set({settings: {...state.settings, ...patch}});

  // ── Toast & dialogs ─────────────────────────────────────────────────────
  let toastTimer = null;
  function notify(message, error = false) {
    clearTimeout(toastTimer);
    const root = $('toast-root');
    root.innerHTML = `<div class="toast ${error ? 'toast-error' : ''}" role="${error ? 'alert' : 'status'}">${icon(error ? 'alertCircle' : 'circleCheck', 17)}<span>${escapeHtml(message)}</span><button aria-label="Dismiss notification">${icon('x', 14)}</button></div>`;
    root.querySelector('button').onclick = () => { root.innerHTML = ''; };
    toastTimer = setTimeout(() => { root.innerHTML = ''; }, 3400);
  }
  async function copy(text, message = 'Copied to clipboard') {
    try { await copyText(text); notify(message); } catch { notify('Clipboard unavailable. Use Download .js instead.', true); }
  }

  const TOKENS = new RegExp(`("(?:\\\\.|[^"\\\\])*"|'(?:\\\\.|[^'\\\\])*'|\\/\\/.*|0x[\\da-fA-F]+|\\b(?:function|const|let|for|of|return|if|else|true|false)\\b|\\b(?:${[...HELPER_NAMES, ...catalog.map((a) => a.functionName)].join('|')})\\b|\\b\\d*\\.?\\d+\\b)`, 'g');
  const HELPERS = new Set([...HELPER_NAMES, ...catalog.map((a) => a.functionName)]);
  function tokenClass(token) {
    if (token.startsWith('//')) return 'syntax-comment';
    if (/^["']/.test(token)) return 'syntax-string';
    if (/^(function|const|let|for|of|return|if|else|true|false)$/.test(token)) return 'syntax-keyword';
    if (HELPERS.has(token)) return 'syntax-function';
    if (/^(0x|\d|\.\d)/.test(token)) return 'syntax-number';
    return '';
  }
  function codeView(code, filename, {compact = false, copyLabel = 'Copy'} = {}) {
    const lines = code.trimEnd().split('\n').map((line, index) =>
      `<span class="code-line"><span class="line-number" aria-hidden="true">${index + 1}</span><span class="line-content">${line.split(TOKENS).map((t) => { const c = tokenClass(t); return c ? `<span class="${c}">${escapeHtml(t)}</span>` : escapeHtml(t); }).join('') || ' '}</span></span>`).join('');
    return `<div class="code-view ${compact ? 'compact' : ''}"><div class="code-file-bar"><span>${icon('fileCode2', 14)}${escapeHtml(filename)}</span><button class="small-text-button" data-copy>${icon('copy', 13)}${copyLabel}</button></div><div class="code-scroll" tabindex="0" role="region" aria-label="${escapeHtml(filename)} source code"><pre><code>${lines}</code></pre></div></div>`;
  }

  let closeDialog = null;
  function openDialog({title, subtitle, className, body, footer}) {
    closeDialog?.();
    const root = $('dialog-root');
    const previous = document.activeElement;
    root.innerHTML = `<div class="dialog-backdrop"><section class="dialog ${className}" role="dialog" aria-modal="true" aria-labelledby="dialog-title" tabindex="-1"><header class="dialog-heading"><div><h2 id="dialog-title">${escapeHtml(title)}</h2><p>${escapeHtml(subtitle)}</p></div><button class="icon-button" aria-label="Close dialog" data-close>${icon('x', 19)}</button></header><div class="dialog-body" style="display:contents"></div>${footer}</section></div>`;
    const backdrop = root.firstElementChild, dialog = backdrop.firstElementChild;
    const bodyEl = dialog.querySelector('.dialog-body');
    body(bodyEl);
    const onKey = (event) => {
      if (event.key === 'Escape') { event.stopPropagation(); close(); }
      if (event.key !== 'Tab') return;
      const targets = [...dialog.querySelectorAll('button:not([disabled]), [href], input, select, textarea, [tabindex="0"]')];
      const first = targets[0], last = targets[targets.length - 1];
      if (event.shiftKey && (document.activeElement === first || document.activeElement === dialog)) { event.preventDefault(); last?.focus(); }
      else if (!event.shiftKey && (document.activeElement === last || document.activeElement === dialog)) { event.preventDefault(); first?.focus(); }
    };
    function close() {
      document.removeEventListener('keydown', onKey, true);
      root.innerHTML = '';
      closeDialog = null;
      document.body.style.overflow = state.expanded ? 'hidden' : '';
      previous?.focus?.();
    }
    document.addEventListener('keydown', onKey, true);
    backdrop.addEventListener('mousedown', (e) => { if (e.target === backdrop) close(); });
    dialog.querySelector('[data-close]').onclick = close;
    document.body.style.overflow = 'hidden';
    dialog.focus();
    closeDialog = close;
    return dialog;
  }

  function openExport(exportTab = 'function') {
    const a = asset(), fileName = `${a.functionName}.js`;
    let tabName = exportTab;
    const dialog = openDialog({
      title: 'Ready for your terminal.', subtitle: 'Your procedural model, without the extra baggage.', className: 'export-dialog',
      body: (el) => {
        const draw = () => {
          el.innerHTML = `<div class="export-tabs" role="tablist" aria-label="Export sections"><button role="tab" data-export="function" aria-selected="${tabName === 'function'}" class="${tabName === 'function' ? 'active' : ''}">${icon('code2', 15)}Model function<span>JS</span></button><button role="tab" data-export="wiring" aria-selected="${tabName === 'wiring'}" class="${tabName === 'wiring' ? 'active' : ''}">${icon('layers2', 15)}Integration<span>JS + DART</span></button></div>`
            + `<div class="export-content">${tabName === 'function' ? codeView(a.source, fileName) : `<div class="wiring-content"><h3>1. Add to your facility router</h3>${codeView(a.facilityLine, 'facility()', {compact: true})}<h3>2. Register in the Dart catalog</h3>${codeView(a.catalogLine, 'AirportFacilityDef', {compact: true})}<p>Catalog footprint: ${a.width} x ${a.depth} m. The model accepts your donor's <code>w</code> and <code>d</code> parameters.</p></div>`}</div>`
            + `<div class="export-footnote">${icon('info', 14)}<span>Uses your existing <code>box()</code> and <code>light()</code> helpers. No assets included or required.</span></div>`;
          el.querySelectorAll('[data-export]').forEach((b) => { b.onclick = () => { tabName = b.dataset.export; draw(); }; });
          const copies = el.querySelectorAll('[data-copy]');
          if (tabName === 'function') copies[0].onclick = () => copy(a.source, 'Model function copied');
          else { copies[0].onclick = () => copy(a.facilityLine, 'Facility wiring copied'); copies[1].onclick = () => copy(a.catalogLine, 'Dart catalog entry copied'); }
        };
        draw();
      },
      footer: `<footer class="dialog-footer"><button class="button button-secondary" data-download>${icon('arrowDownToLine', 15)}Download .js</button><button class="button button-primary" data-copy-full>${icon('copy', 15)}Copy full snippet</button></footer>`,
    });
    dialog.querySelector('[data-download]').onclick = () => { saveFile(fileName, 'text/javascript', textDataUrl(a.source, 'text/javascript')); notify(`${fileName} downloaded`); };
    dialog.querySelector('[data-copy-full]').onclick = () => copy(a.fullSource, 'Function and both wiring lines copied');
  }

  function openGuide() {
    const dialog = openDialog({
      title: 'A little help getting around.', subtitle: 'From the first orbit to your airport terminal.', className: 'guide-dialog',
      body: (el) => {
        el.innerHTML = `<div class="guide-content"><section><span class="guide-step">01</span><div><h3>Find your angle</h3><p>Drag to orbit, scroll to zoom, or hold Shift while dragging to pan. Use the view menu for precise front, side, and top views.</p><div class="keyboard-row"><span><kbd>F</kbd>Reset view</span><span><kbd>R</kbd>Rotate 90&deg;</span></div></div></section><section><span class="guide-step">02</span><div><h3>Make sure it fits</h3><p>Adjust the footprint in meters. Open Checks to inspect bounds, color attributes, and the helper-call budget.</p><div class="keyboard-row"><span><kbd>G</kbd>Grid</span><span><kbd>B</kbd>Bounds</span><span><kbd>W</kbd>Wireframe</span></div></div></section><section><span class="guide-step">03</span><div><h3>Give it a home</h3><p>Export the function into your existing helper scope, add the JavaScript facility branch, and register the Dart catalog entry. Bake with your donor before shipping.</p></div></section><div class="guide-note">${icon('info', 16)}<p>The preview adapter uses centered boxes and size-sided light meshes. Your model has no external files, materials, or per-frame geometry allocations. Settings are saved in this browser.</p></div></div>`;
      },
      footer: `<footer class="dialog-footer"><span class="guide-footer-label">A simpler way to make a little world.</span><button class="button button-primary" data-back>Back to the studio${icon('arrowUpRight', 15)}</button></footer>`,
    });
    dialog.querySelector('[data-back]').onclick = () => closeDialog?.();
  }

  // ── Rendering the chrome ────────────────────────────────────────────────
  function checkItem(passed, title, detail) {
    return `<div class="check-item ${passed === false ? 'has-error' : ''}">${icon(passed === false ? 'alertCircle' : 'circleCheck', 16)}<div><strong>${escapeHtml(title)}</strong><span>${escapeHtml(detail)}</span></div></div>`;
  }
  let renderedSourceFor = null;
  function render() {
    const a = asset(), r = state.report, s = state.settings;
    document.title = `${a.name} · Airform Asset Studio`;
    $('asset-category').textContent = a.category.toUpperCase();
    $('asset-name').textContent = a.name;
    $('asset-description').textContent = a.description;
    $('asset-code').textContent = a.collectionCode;
    $('save-status').textContent = state.saved ? 'Saved locally' : 'Session workspace';
    for (const b of $('asset-switcher').children) {
      const on = b.dataset.asset === a.id;
      b.classList.toggle('active', on);
      b.setAttribute('aria-selected', on);
    }

    for (const b of document.querySelectorAll('[data-tab]')) {
      const on = b.dataset.tab === state.tab;
      b.classList.toggle('active', on);
      b.setAttribute('aria-selected', on);
    }
    $('preview-panel').classList.toggle('panel-hidden', state.tab !== 'preview');
    $('source-panel').hidden = state.tab !== 'source';
    $('preview-footer').hidden = state.tab !== 'preview';
    $('source-footer').hidden = state.tab !== 'source';
    $('camera-select').hidden = state.tab !== 'preview';
    if (state.tab === 'source' && renderedSourceFor !== a.id) {
      renderedSourceFor = a.id;
      $('source-code').innerHTML = codeView(a.source, `${a.functionName}.js`);
      $('source-code').querySelector('[data-copy]').onclick = () => copy(asset().source, 'Model function copied');
    }
    $('view-select').value = state.view;
    $('viewer').classList.toggle('is-expanded', state.expanded);
    $('expand-backdrop').hidden = !state.expanded;
    const expand = $('expand-button');
    expand.innerHTML = icon(state.expanded ? 'minimize2' : 'expand', 16);
    expand.setAttribute('aria-label', state.expanded ? 'Collapse viewport' : 'Expand viewport');
    expand.title = expand.getAttribute('aria-label');

    for (const b of document.querySelectorAll('[data-interaction]')) {
      const on = b.dataset.interaction === state.interaction;
      b.classList.toggle('selected', on);
      b.setAttribute('aria-pressed', on);
    }
    for (const b of document.querySelectorAll('.floating-tools [data-setting]')) {
      const on = s[b.dataset.setting];
      b.classList.toggle('selected', on);
      b.classList.toggle('subtle', on);
      b.setAttribute('aria-pressed', on);
    }
    $('model-scene').classList.toggle('is-panning', state.interaction === 'pan');
    $('orbit-hint').textContent = state.interaction === 'pan' ? 'Drag to pan' : 'Drag to orbit';
    const turntable = $('turntable-button');
    turntable.classList.toggle('utility-active', state.autoRotate);
    turntable.innerHTML = icon(state.autoRotate ? 'pause' : 'play', 15);
    turntable.setAttribute('aria-label', state.autoRotate ? 'Pause turntable' : 'Start turntable');
    turntable.title = state.autoRotate ? 'Pause turntable' : 'Auto orbit';
    $('dimension-labels').classList.toggle('is-hidden', !s.bounds || !sceneApi);
    $('width-label').textContent = `${s.width.toFixed(1)} m`;
    $('depth-label').textContent = `${s.depth.toFixed(1)} m`;

    $('shading-select').value = state.wireframe ? 'wireframe' : 'solid';
    for (const b of $('rotation-buttons').children) {
      const on = Number(b.dataset.rotation) === state.rotation;
      b.classList.toggle('active', on);
      b.setAttribute('aria-pressed', on);
    }
    $('zoom-value').textContent = `${state.zoom}%`;
    document.querySelector('[data-action="zoom-out"]').disabled = state.zoom <= 50;
    document.querySelector('[data-action="zoom-in"]').disabled = state.zoom >= 210;

    for (const b of document.querySelectorAll('.inspector-tabs [data-inspector]')) {
      const on = b.dataset.inspector === state.inspectorTab;
      b.classList.toggle('active', on);
      b.setAttribute('aria-selected', on);
    }
    $('check-dot').classList.toggle('failed', !!(r && !r.passed));
    $('properties-panel').hidden = state.inspectorTab !== 'properties';
    $('checks-panel').hidden = state.inspectorTab !== 'checks';
    $('reset-all').hidden = state.inspectorTab !== 'properties';
    $('validate').hidden = state.inspectorTab !== 'checks';

    for (const [id, value] of [['width-input', s.width], ['depth-input', s.depth]]) {
      const input = $(id);
      if (document.activeElement !== input) input.value = value.toFixed(1);
    }
    $('model-height').textContent = `${(r ? r.height : a.maxHeight).toFixed(2)} m`;
    const colors = palette();
    const color = colors[state.selectedColor] || colors[0];
    $('palette').innerHTML = colors.map((item, index) => `<button class="color-swatch ${index === state.selectedColor ? 'active' : ''}" data-color="${index}" style="--swatch:${item.color};--check-color:${item.light ? '#46544a' : '#ffffff'}" title="${escapeHtml(item.name)}: ${item.color}" aria-label="${escapeHtml(item.name)}, ${item.color}" aria-pressed="${index === state.selectedColor}">${index === state.selectedColor ? icon('check', 13) : ''}</button>`).join('');
    $('color-name').textContent = color.name;
    $('color-value').textContent = color.color;
    for (const b of document.querySelectorAll('.toggle[data-setting]')) {
      const on = s[b.dataset.setting];
      b.classList.toggle('on', on);
      b.setAttribute('aria-checked', on);
    }

    $('checks-icon').classList.toggle('has-error', !!(r && !r.passed));
    $('checks-title').textContent = r?.passed ? 'Built to fit.' : 'Geometry checks';
    $('check-list').innerHTML = [
      checkItem(r?.rotations.every(Boolean), 'Footprint-tight', 'Inside the bounds at all 4 rotations'),
      checkItem(r?.grounded, 'Grounded at y = 0', 'No geometry below the ground'),
      checkItem(r?.heightValid, 'Within the height limit', `${(r ? r.height : a.maxHeight).toFixed(2)} m of a ${a.maxHeight.toFixed(2)} m maximum`),
      checkItem(r ? r.helperCalls < a.maxCalls : undefined, `${r?.helperCalls ?? '--'} helper calls`, `Under the ${a.maxCalls}-call geometry budget`),
      checkItem(r?.colorsOnly, 'Vertex colors only', 'No model textures or font assets'),
      checkItem(r?.mergeSafe, 'Local geometry merge passed', 'Static meshes with baked transforms'),
    ].join('');

    const status = $('status-ready');
    status.classList.toggle('status-error', !!(r && !r.passed));
    $('status-text').textContent = r?.passed ? 'Geometry checks passed' : r ? 'Review geometry checks' : 'Preparing geometry';
    $('status-calls').textContent = r?.helperCalls ?? '--';
    $('status-triangles').textContent = r?.triangles ?? '--';
  }

  // ── Actions ─────────────────────────────────────────────────────────────
  function resetCamera() {
    set({view: 'isometric', rotation: 0, autoRotate: false});
    sceneApi?.reset();
  }
  function switchAsset(id) {
    if (id === state.assetId) return;
    const next = findAsset(id);
    set({assetId: id, settings: {...state.settings, width: next.width, depth: next.depth}, report: null, selectedColor: 0});
    notify(`Loaded ${next.name}`);
  }
  function capture() {
    const image = sceneApi?.capture();
    if (!image) { notify('A WebGL preview is required to save an image.', true); return; }
    saveFile(`${asset().functionName}.png`, 'image/png', image);
    notify(`Preview saved as ${asset().functionName}.png`);
  }
  const actions = {
    home: () => { set({tab: 'preview'}); resetCamera(); },
    guide: openGuide,
    export: () => openExport('function'),
    wiring: () => openExport('wiring'),
    expand: () => { set({expanded: !state.expanded}); document.body.style.overflow = state.expanded ? 'hidden' : ''; },
    'reset-camera': resetCamera,
    turntable: () => set({autoRotate: !state.autoRotate}),
    capture,
    'zoom-in': () => sceneApi?.zoomBy(10),
    'zoom-out': () => sceneApi?.zoomBy(-10),
    'copy-full': () => copy(asset().fullSource, 'Function and both wiring lines copied'),
    'copy-color': () => { const c = palette()[state.selectedColor] || palette()[0]; copy(c.code, `${c.name} color copied`); },
    'reset-all': () => {
      set({settings: {...DEFAULTS, width: asset().width, depth: asset().depth}, wireframe: false, interaction: 'orbit', selectedColor: 0});
      resetCamera();
      notify('Model restored to the original specification');
    },
    validate: () => {
      const result = sceneApi?.validate();
      if (!result) { notify('Live validation requires a WebGL-enabled browser.', true); return; }
      notify(result.passed ? 'All 6 geometry checks passed' : 'A geometry check needs attention', !result.passed);
    },
  };

  function bind() {
    $('asset-switcher').innerHTML = catalog.map((item) => `<button role="tab" data-asset="${item.id}"><strong>${escapeHtml(item.name)}</strong><span>${escapeHtml(item.keywords)}</span></button>`).join('');
    $('rotation-buttons').innerHTML = [0, 1, 2, 3].map((v) => `<button data-rotation="${v}" title="Rotate to ${v * 90} degrees">${v * 90}&deg;</button>`).join('');
    document.addEventListener('click', (event) => {
      const el = event.target.closest('button, a');
      if (!el || el.closest('#dialog-root') || el.closest('#toast-root')) return;
      const d = el.dataset;
      if (d.action && actions[d.action]) { event.preventDefault(); actions[d.action](); }
      else if (d.asset) switchAsset(d.asset);
      else if (d.tab) set({tab: d.tab});
      else if (d.interaction) set({interaction: d.interaction});
      else if (d.setting) setSettings({[d.setting]: !state.settings[d.setting]});
      else if (d.rotation) set({rotation: Number(d.rotation)});
      else if (d.inspector) set({inspectorTab: d.inspector});
      else if (d.color) set({selectedColor: Number(d.color)});
    });
    $('expand-backdrop').onclick = () => actions.expand();
    $('view-select').onchange = (e) => set({view: e.target.value, autoRotate: false});
    $('shading-select').onchange = (e) => set({wireframe: e.target.value === 'wireframe'});
    for (const [id, key, max] of [['width-input', 'width', 16], ['depth-input', 'depth', 10]]) {
      const input = $(id);
      const commit = () => {
        const parsed = Number.parseFloat(input.value);
        const current = state.settings[key];
        const next = Number.isFinite(parsed) ? Math.round(Math.min(max, Math.max(.5, parsed)) * 10) / 10 : current;
        input.value = next.toFixed(1);
        if (next !== current) setSettings({[key]: next});
      };
      input.addEventListener('blur', commit);
      input.addEventListener('keydown', (e) => { if (e.key === 'Enter') input.blur(); });
    }
    window.addEventListener('keydown', (event) => {
      const target = event.target;
      if (['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName) || target.isContentEditable || event.metaKey || event.ctrlKey || event.altKey) return;
      if (closeDialog) return;
      const k = event.key.toLowerCase();
      if (event.key === 'Escape' && state.expanded) actions.expand();
      if (k === 'r') set({rotation: (state.rotation + 1) % 4});
      if (k === 'f') resetCamera();
      if (k === 'g') setSettings({grid: !state.settings.grid});
      if (k === 'b') setSettings({bounds: !state.settings.bounds});
      if (k === 'w') set({wireframe: !state.wireframe});
      if (k === 'h') set({interaction: 'pan'});
      if (k === 'o') set({interaction: 'orbit'});
    });
  }

  // ── Boot ────────────────────────────────────────────────────────────────
  if (config.embed) document.documentElement.classList.add('embed');
  applyTheme();
  hydrateIcons();
  bind();
  render();
  try {
    sceneApi = createScene($('canvas-mount'), sceneOptions(), {
      onReport: (report) => { state.report = report; render(); },
      onZoom: (zoom) => { state.zoom = zoom; render(); },
      widthLabel: $('width-label'),
      depthLabel: $('depth-label'),
    });
  } catch (error) {
    console.error(error);
    sceneApi = null;
  }
  if (!sceneApi) {
    $('model-scene').insertAdjacentHTML('beforeend', '<div class="webgl-fallback"><p>3D preview needs a WebGL-enabled browser.</p><span>Your model is still ready to inspect and export.</span></div>');
  }
  render();
  postToHost({type: 'ready', asset: state.assetId});
})();
