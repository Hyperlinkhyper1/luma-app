/* Subway Builder — MapLibre GL layer. Real-world basemap (OpenFreeMap /
   OpenStreetMap vector tiles) with 3D building extrusions, plus the game's
   own GeoJSON layers for lines, stations, trains, drafts and data overlays. */
(function () {
  'use strict';
  const SB = (window.SB = window.SB || {});
  const geo = SB.geo;

  // Basemap + game-layer colors per theme. Both styles come from the same
  // OpenFreeMap OpenMapTiles server, so the vector schema (and therefore
  // surveyPlace/harvestVisible) is identical in either theme.
  const THEMES = {
    dark: {
      style: 'https://tiles.openfreemap.org/styles/dark',
      building: '#20242d',
      casing: '#0b0d12',
      stationFill: '#ffffff',
      label: '#dde3ee',
      halo: 'rgba(10,12,16,.85)',
      railLabel: '#a99ef7',
      railHalo: 'rgba(10,12,16,.85)',
      railStationFill: '#1a1728',
      trainBody: '#f2f5f9',
    },
    light: {
      style: 'https://tiles.openfreemap.org/styles/positron',
      building: '#d9d4c9',
      casing: '#ffffff',
      stationFill: '#ffffff',
      label: '#3d3a33',
      halo: 'rgba(255,255,255,.85)',
      railLabel: '#5a4fcf',
      railHalo: 'rgba(255,255,255,.9)',
      railStationFill: '#efeaff',
      trainBody: '#ffffff',
    },
  };

  const map3d = (SB.map3d = { map: null, ready: false });

  let vecSource = null; // name of the style's vector source (openmaptiles)

  // ── Render settings ──────────────────────────────────────────────────
  // "Render distance" is the number of extra zoom-out levels beyond the
  // base draw-in point at which 3D buildings (and, scaled down, line/
  // station detail) start appearing — higher = visible from further away.
  // "LOD distance" is the zoom-level span just past that horizon over
  // which detail ramps up gradually instead of popping in abruptly.
  const BASE_BUILD_MINZOOM = 13;
  const SETTINGS_KEY = 'sb_render_settings_v1';
  const DEFAULT_SETTINGS = {
    buildings3d: true,
    mode2d: false,
    renderDistance: 0,
    lodDistance: 2,
    theme: 'dark',
  };

  function themeOf() { return THEMES[map3d.settings && map3d.settings.theme] || THEMES.dark; }

  function loadSettings() {
    try {
      const raw = localStorage.getItem(SETTINGS_KEY);
      if (!raw) return { ...DEFAULT_SETTINGS };
      return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
    } catch (e) {
      return { ...DEFAULT_SETTINGS };
    }
  }

  map3d.settings = loadSettings();

  map3d.saveSettings = function () {
    try { localStorage.setItem(SETTINGS_KEY, JSON.stringify(map3d.settings)); } catch (e) { /* ignore */ }
  };

  map3d.setSetting = function (key, value) {
    map3d.settings[key] = value;
    map3d.saveSettings();
    map3d.applySettings();
  };

  /* Re-applies every render setting to the live map — safe to call any
     time after the layers exist (map 'load'), and whenever a setting
     changes. */
  let lastAppliedKey = null;
  map3d.applySettings = function (force) {
    if (!map3d.ready) return;
    const map = map3d.map;
    const s = map3d.settings;

    // Slider drags (and any other rapid-fire caller) can otherwise queue up
    // many identical re-applications; skip the (fairly heavy) style mutation
    // work entirely when nothing actually changed.
    const key = JSON.stringify(s);
    if (!force && key === lastAppliedKey) return;
    lastAppliedKey = key;

    try {
      const minZoom = Math.max(0, BASE_BUILD_MINZOOM - s.renderDistance);
      const fadeEnd = minZoom + s.lodDistance;
      const ramped = fadeEnd > minZoom;

      if (map.getLayer('sb-3d-buildings')) {
        const on = s.buildings3d;
        map.setLayoutProperty('sb-3d-buildings', 'visibility', on ? 'visible' : 'none');
        if (on) {
          map.setLayerZoomRange('sb-3d-buildings', minZoom, 24);
          const height = ['coalesce', ['get', 'render_height'], 8];
          // NB: a zoom expression may only appear as the top-level
          // expression of a property (or the input of a top-level
          // step/interpolate) — it can't be nested inside an arithmetic
          // operator like `*`. So the interpolate itself must be the
          // outer expression, with the per-feature height as its output.
          map.setPaintProperty('sb-3d-buildings', 'fill-extrusion-opacity',
            ramped ? ['interpolate', ['linear'], ['zoom'], minZoom, 0, fadeEnd, 0.88] : 0.88);
          map.setPaintProperty('sb-3d-buildings', 'fill-extrusion-height',
            ramped
              ? ['interpolate', ['linear'], ['zoom'], minZoom, ['*', 0.15, height], fadeEnd, height]
              : height);
        }
      }

      // Line/station detail fades in over the same horizon, thinning out
      // instead of disappearing outright.
      const LOD_MIN_SCALE = 0.45;
      const lodWidth = (expr) => (ramped
        ? ['interpolate', ['linear'], ['zoom'], minZoom, ['*', expr, LOD_MIN_SCALE], fadeEnd, expr]
        : expr);
      if (map.getLayer('sb-lines-casing')) {
        map.setPaintProperty('sb-lines-casing', 'line-width', lodWidth(['+', ['get', 'w'], 3.5]));
      }
      if (map.getLayer('sb-lines')) {
        map.setPaintProperty('sb-lines', 'line-width', lodWidth(['get', 'w']));
      }
      if (map.getLayer('sb-lines-dash')) {
        map.setPaintProperty('sb-lines-dash', 'line-width', lodWidth(['get', 'w']));
      }
      if (map.getLayer('sb-stations')) {
        map.setPaintProperty('sb-stations', 'circle-radius', lodWidth(['get', 'r']));
      }

      // Labels shouldn't pop in long after the geometry they describe.
      const labelShift = s.renderDistance * 0.5;
      if (map.getLayer('sb-station-labels')) {
        map.setLayerZoomRange('sb-station-labels', Math.max(0, 12.6 - labelShift), 24);
      }
      if (map.getLayer('sb-railstation-labels')) {
        map.setLayerZoomRange('sb-railstation-labels', Math.max(0, 11.5 - labelShift), 24);
      }

      if (s.mode2d) {
        map.setMaxPitch(0);
        if (map.getPitch() !== 0) map.easeTo({ pitch: 0, duration: 400 });
        map.dragRotate.disable();
      } else {
        map.setMaxPitch(70);
        map.dragRotate.enable();
      }
    } catch (e) {
      console.error('applySettings failed', e);
    }
  };

  function emptyFC() { return { type: 'FeatureCollection', features: [] }; }

  // Visible boot status — a broken map must never be a silent blank screen.
  const bootErrors = [];
  function showBootError(title) {
    const el = document.getElementById('bootstatus');
    if (!el) return;
    el.style.display = 'flex';
    el.innerHTML =
      '<div class="bs-card"><b>' + title + '</b>' +
      (bootErrors.length ? '<div class="bs-err">' + bootErrors.slice(0, 3).join('<br>') + '</div>' : '') +
      '<div class="bs-sub">Subway Builder needs an internet connection for OpenStreetMap tiles.</div>' +
      '<button onclick="location.reload()">Retry</button></div>';
  }

  map3d.init = function (onReady) {
    let map;
    try {
      map = map3d.map = new maplibregl.Map({
        container: 'map',
        style: themeOf().style,
        center: [-73.985, 40.735],
        zoom: 11.5,
        pitch: 0,
        attributionControl: { compact: true },
        maxPitch: 70,
      });
    } catch (e) {
      bootErrors.push(String(e && e.message || e));
      showBootError('The 3D map couldn’t start (WebGL unavailable in this webview)');
      return;
    }
    map.dragRotate.enable();
    map.touchZoomRotate.enable();
    map.doubleClickZoom.disable(); // double-click finishes line drafts

    // The Windows WebView2 host (webview_windows) can only deliver wheel
    // input at a fixed (0,0) point — MapLibre's built-in scroll-zoom (which
    // hit-tests the event's own, always-wrong, coordinates) never sees the
    // event land on the map canvas. main.js installs a manual wheel handler
    // that uses the real cursor position tracked from mousemove instead.
    map.scrollZoom.disable();

    let loaded = false;
    map.on('error', (e) => {
      const msg = String((e && e.error && e.error.message) || 'map error');
      if (!loaded && bootErrors.length < 6 && !bootErrors.includes(msg)) bootErrors.push(msg);
    });
    const bootTimer = setTimeout(() => {
      if (!loaded) showBootError('The map is taking too long to load');
    }, 16000);
    // Webviews can lay out late — kick the canvas size a few times.
    let kicks = 0;
    const resizeKick = setInterval(() => {
      try { map.resize(); } catch (e) { /* ignore */ }
      if (++kicks >= 8) clearInterval(resizeKick);
    }, 700);

    map.on('load', () => {
      loaded = true;
      clearTimeout(bootTimer);
      const bs = document.getElementById('bootstatus');
      if (bs) bs.style.display = 'none';
      buildLayers();
      map3d.ready = true;
      map3d.applySettings(true);
      if (onReady) onReady();
    });
  };

  /* Switch dark/light. setStyle wipes every custom source and layer, so
     rebuild the whole game layer stack once the new style has loaded and
     re-push the current game data into it. */
  map3d.setTheme = function (theme) {
    if (!THEMES[theme]) return;
    map3d.settings.theme = theme;
    map3d.saveSettings();
    const map = map3d.map;
    if (!map) return;
    map3d.ready = false;
    map.setStyle(themeOf().style);
    // 'style.load' proved racy in the embedded webview (it can slip past a
    // once() registered right after setStyle) — poll isStyleLoaded instead.
    const tryRebuild = () => {
      if (!map.isStyleLoaded()) { setTimeout(tryRebuild, 120); return; }
      buildLayers();
      map3d.ready = true;
      lastAppliedKey = null;
      map3d.applySettings(true);
      if (SB.ui && SB.game && SB.game.state) {
        SB.ui.updateAll();               // network, stations, rail highlight
        map3d.setOverlay(SB.ui.overlay); // demand / access fills
      }
    };
    setTimeout(tryRebuild, 120);
  };

  /* Creates every game source and layer on the current style. Called on
     first load and again after each setTheme() style swap. */
  function buildLayers() {
    const map = map3d.map;
    const T = themeOf();
    // Find the style's vector source (OpenMapTiles schema).
    vecSource = null;
    for (const [id, src] of Object.entries(map.getStyle().sources)) {
      if (src.type === 'vector') { vecSource = id; break; }
    }
    {
      // 3D buildings from real OSM footprints + heights.
      if (vecSource) {
        map.addLayer({
          id: 'sb-3d-buildings',
          source: vecSource,
          'source-layer': 'building',
          type: 'fill-extrusion',
          minzoom: 13,
          paint: {
            'fill-extrusion-color': T.building,
            'fill-extrusion-height': ['coalesce', ['get', 'render_height'], 8],
            'fill-extrusion-base': ['coalesce', ['get', 'render_min_height'], 0],
            'fill-extrusion-opacity': 0.88,
          },
        });
      }

      // Game sources.
      for (const id of ['sb-access', 'sb-demand', 'sb-lines', 'sb-draft', 'sb-stations', 'sb-trains', 'sb-ghost', 'sb-railstations']) {
        map.addSource(id, { type: 'geojson', data: emptyFC() });
      }

      // Real railway tracks, highlighted while the Train mode is active.
      if (vecSource) {
        map.addLayer({
          id: 'sb-railnet', source: vecSource, 'source-layer': 'transportation',
          type: 'line',
          filter: ['all', ['==', ['get', 'class'], 'rail'],
            ['!', ['in', ['get', 'subclass'], ['literal', ['subway', 'tram', 'monorail', 'funicular']]]]],
          layout: { visibility: 'none', 'line-cap': 'round' },
          paint: { 'line-color': '#7a6ff0', 'line-width': 2.4, 'line-opacity': 0.75, 'line-dasharray': [3, 1.6] },
        });
      }

      map.addLayer({ id: 'sb-demand', source: 'sb-demand', type: 'fill',
        paint: { 'fill-color': ['get', 'color'], 'fill-opacity': ['get', 'op'] } });
      map.addLayer({ id: 'sb-access', source: 'sb-access', type: 'fill',
        paint: { 'fill-color': '#2f6fdb', 'fill-opacity': 0.12, 'fill-outline-color': '#2f6fdb' } });

      map.addLayer({ id: 'sb-lines-casing', source: 'sb-lines', type: 'line',
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: { 'line-color': T.casing, 'line-width': ['+', ['get', 'w'], 3.5], 'line-offset': ['get', 'off'] } });
      // line-dasharray can't be data-driven, so buses get their own layer.
      map.addLayer({ id: 'sb-lines', source: 'sb-lines', type: 'line',
        filter: ['!=', ['get', 'dash'], 1],
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: { 'line-color': ['get', 'color'], 'line-width': ['get', 'w'], 'line-offset': ['get', 'off'] } });
      map.addLayer({ id: 'sb-lines-dash', source: 'sb-lines', type: 'line',
        filter: ['==', ['get', 'dash'], 1],
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: { 'line-color': ['get', 'color'], 'line-width': ['get', 'w'], 'line-offset': ['get', 'off'],
          'line-dasharray': [2.2, 1.4] } });

      map.addLayer({ id: 'sb-draft', source: 'sb-draft', type: 'line',
        layout: { 'line-cap': 'round' },
        paint: { 'line-color': ['get', 'color'], 'line-width': 4, 'line-dasharray': [1.4, 1.2],
          'line-opacity': ['get', 'op'] } });

      map.addLayer({ id: 'sb-ghost', source: 'sb-ghost', type: 'line',
        paint: { 'line-color': ['get', 'color'], 'line-width': ['get', 'w'], 'line-dasharray': [1.5, 1.5] } });

      // Trains are short slices of the actual route polyline, so they bend
      // around curves instead of cutting corners as straight sprites.
      map.addLayer({ id: 'sb-trains-casing', source: 'sb-trains', type: 'line',
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: { 'line-color': ['get', 'color'], 'line-width': ['+', ['get', 'w'], 3] } });
      map.addLayer({ id: 'sb-trains', source: 'sb-trains', type: 'line',
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: { 'line-color': T.trainBody, 'line-width': ['get', 'w'] } });

      map.addLayer({ id: 'sb-stations', source: 'sb-stations', type: 'circle',
        paint: {
          'circle-radius': ['get', 'r'],
          'circle-color': T.stationFill,
          'circle-stroke-color': ['get', 'ring'],
          'circle-stroke-width': ['get', 'rw'],
        } });
      map.addLayer({ id: 'sb-railstations', source: 'sb-railstations', type: 'circle',
        paint: {
          'circle-radius': 6.5, 'circle-color': T.railStationFill,
          'circle-stroke-color': '#5a4fcf', 'circle-stroke-width': 2.4,
        } });
      map.addLayer({ id: 'sb-railstation-labels', source: 'sb-railstations', type: 'symbol',
        minzoom: 11.5,
        layout: {
          'text-field': ['get', 'name'], 'text-size': 10.5,
          'text-font': ['Noto Sans Regular'],
          'text-anchor': 'left', 'text-offset': [0.9, 0], 'text-optional': true,
        },
        paint: { 'text-color': T.railLabel, 'text-halo-color': T.railHalo, 'text-halo-width': 1.3 } });

      map.addLayer({ id: 'sb-station-labels', source: 'sb-stations', type: 'symbol',
        minzoom: 12.6,
        layout: {
          'text-field': ['get', 'label'],
          'text-size': 11.5,
          'text-font': ['Noto Sans Regular'],
          'text-anchor': 'left', 'text-offset': [0.9, 0], 'text-optional': true,
        },
        paint: { 'text-color': T.label, 'text-halo-color': T.halo, 'text-halo-width': 1.4 } });
    }
  }

  // ── Feature builders ─────────────────────────────────────────────────
  function segKey(a, b) { return a < b ? a + '-' + b : b + '-' + a; }

  map3d.updateNetwork = function (uiState) {
    if (!map3d.ready) return;
    const st = SB.game.state;
    const res = SB.sim.results;

    // Lane usage for parallel offsets.
    const usage = new Map();
    for (const line of st.lines) {
      for (let i = 0; i < line.stationIds.length - 1; i++) {
        const k = segKey(line.stationIds[i], line.stationIds[i + 1]);
        if (!usage.has(k)) usage.set(k, []);
        usage.get(k).push(line.id);
      }
    }

    const MODE_W = { metro: 5, train: 4.2, hst: 4.6, tram: 3.4, bus: 2.8 };
    const lineFeats = [];
    for (const line of st.lines) {
      const selected = uiState.selection && uiState.selection.type === 'line' && uiState.selection.id === line.id;
      const loads = res && res.segLoads.get(line.id);
      const ratio = res ? res.lineMaxRatio.get(line.id) || 0 : 0;
      const w = (MODE_W[line.mode] || 4) + (selected ? 1.5 : 0);
      for (let i = 0; i < line.stationIds.length - 1; i++) {
        const group = usage.get(segKey(line.stationIds[i], line.stationIds[i + 1])) || [line.id];
        const off = (group.indexOf(line.id) - (group.length - 1) / 2) * 7;
        let color = line.color;
        if (uiState.overlay === 'load' && loads && res.ridersDaily > 0) {
          const mx = Math.max(1, Math.max(...loads));
          const t = Math.min(1, (loads[i] / mx) * ratio);
          color = t > 0.85 ? '#d64541' : t > 0.6 ? '#f2a33c' : '#2e9e4f';
        }
        lineFeats.push({
          type: 'Feature',
          geometry: { type: 'LineString', coordinates: line.paths[i] },
          properties: { color, off, w, lid: line.id, dash: line.mode === 'bus' ? 1 : 0 },
        });
      }
    }
    map3d.map.getSource('sb-lines').setData({ type: 'FeatureCollection', features: lineFeats });

    const MODE_R = { metro: 5.4, train: 6.2, hst: 6.6, tram: 4.2, bus: 3.4 };
    const stFeats = [];
    for (const s of st.stations) {
      const lines = SB.game.linesThrough(s.id);
      const interchange = lines.length > 1;
      const selected = uiState.selection && uiState.selection.type === 'station' && uiState.selection.id === s.id;
      const inDraft = uiState.draftIds && uiState.draftIds.includes(s.id);
      const orphan = lines.length === 0;
      stFeats.push({
        type: 'Feature',
        geometry: { type: 'Point', coordinates: [s.lng, s.lat] },
        properties: {
          id: s.id,
          r: (MODE_R[s.mode] || 5) + (interchange ? 1.8 : 0),
          rw: interchange ? 2.6 : s.mode === 'bus' ? 1.6 : 2.1,
          ring: selected ? '#2f6fdb' : inDraft ? (uiState.draftColor || '#2f6fdb') : orphan ? '#a49c8a'
            : s.mode === 'train' ? '#5a4fcf' : s.mode === 'hst' ? '#b03aa4' : '#2b2b33',
          label: s.name,
        },
      });
    }
    map3d.map.getSource('sb-stations').setData({ type: 'FeatureCollection', features: stFeats });
  };

  /* Real railway stations offered for leasing, shown in rail modes. */
  map3d.setRailMode = function (on, mode) {
    if (!map3d.ready) return;
    if (map3d.map.getLayer('sb-railnet')) {
      map3d.map.setLayoutProperty('sb-railnet', 'visibility', on ? 'visible' : 'none');
    }
    const feats = [];
    if (on) {
      const taken = new Set(SB.game.state.stations
        .filter((s) => s.mode === (mode || 'train')).map((s) => Math.round(s.x) + ',' + Math.round(s.y)));
      for (const rs of SB.net.railStations) {
        if (taken.has(Math.round(rs.x) + ',' + Math.round(rs.y))) continue;
        feats.push({
          type: 'Feature',
          geometry: { type: 'Point', coordinates: [rs.lng, rs.lat] },
          properties: { name: rs.name },
        });
      }
    }
    map3d.map.getSource('sb-railstations').setData({ type: 'FeatureCollection', features: feats });
  };

  // Routed draft previews are cached — A* must not run every frame.
  let draftCacheKey = '';
  let draftCachePaths = [];

  map3d.updateDraft = function (uiState, mouseLL) {
    if (!map3d.ready) return;
    const feats = [];
    const ids = uiState.draftIds || [];
    const color = uiState.draftColor || '#555';
    const mode = uiState.mode || 'metro';
    const pts = ids.map((id) => SB.game.stationById(id)).filter(Boolean);
    if (pts.length >= 2) {
      const key = mode + ':' + ids.join(',');
      if (key !== draftCacheKey) {
        draftCacheKey = key;
        draftCachePaths = [];
        for (let i = 0; i < pts.length - 1; i++) {
          const seg = SB.game.routeSegment(mode, pts[i], pts[i + 1]);
          draftCachePaths.push(seg.err
            ? [[pts[i].lng, pts[i].lat], [pts[i + 1].lng, pts[i + 1].lat]]
            : seg.pts);
        }
      }
      for (const p of draftCachePaths) {
        feats.push({ type: 'Feature',
          geometry: { type: 'LineString', coordinates: p },
          properties: { color, op: 0.95 } });
      }
    }
    if (pts.length >= 1 && mouseLL) {
      const last = pts[pts.length - 1];
      feats.push({ type: 'Feature',
        geometry: { type: 'LineString', coordinates: [[last.lng, last.lat], [mouseLL.lng, mouseLL.lat]] },
        properties: { color, op: 0.45 } });
    }
    map3d.map.getSource('sb-draft').setData({ type: 'FeatureCollection', features: feats });
  };

  function circleCoords(lng, lat, radiusM, n) {
    const [cx, cy] = geo.toM(lng, lat);
    const ring = [];
    for (let i = 0; i <= (n || 48); i++) {
      const a = (i / (n || 48)) * Math.PI * 2;
      ring.push(geo.toLL(cx + Math.cos(a) * radiusM, cy + Math.sin(a) * radiusM));
    }
    return [ring];
  }

  map3d.updateGhost = function (uiState, mouseLL) {
    if (!map3d.ready) return;
    const feats = [];
    if (uiState.tool === 'station' && mouseLL) {
      const ok = uiState.ghostOk;
      const color = ok ? '#2f6fdb' : '#d64541';
      const reach = SB.MODES[uiState.mode || 'metro'].access;
      feats.push({ type: 'Feature',
        geometry: { type: 'Polygon', coordinates: circleCoords(mouseLL.lng, mouseLL.lat, 60, 24) },
        properties: { color, w: 2.5 } });
      feats.push({ type: 'Feature',
        geometry: { type: 'Polygon', coordinates: circleCoords(mouseLL.lng, mouseLL.lat, reach, 56) },
        properties: { color, w: 1 } });
    }
    map3d.map.getSource('sb-ghost').setData({ type: 'FeatureCollection', features: feats });
  };

  // Body width per mode (the colored casing adds ~3px around it).
  const TRAIN_W = { metro: 6, train: 5.4, hst: 5.8, tram: 4.4, bus: 3.6 };

  map3d.updateTrains = function () {
    if (!map3d.ready) return;
    const feats = [];
    for (const t of SB.sim.trainSegments()) {
      feats.push({ type: 'Feature',
        geometry: { type: 'LineString', coordinates: t.pts.map((p) => geo.toLL(p[0], p[1])) },
        properties: { color: t.line.color, w: TRAIN_W[t.line.mode] || 5 } });
    }
    map3d.map.getSource('sb-trains').setData({ type: 'FeatureCollection', features: feats });
  };

  map3d.setOverlay = function (overlay) {
    if (!map3d.ready) return;
    const feats = [];
    const city = SB.game.city;
    if (city && (overlay === 'pop' || overlay === 'jobs')) {
      const mx = overlay === 'pop' ? city.maxPop : city.maxJobs;
      for (const c of city.cells) {
        const v = (overlay === 'pop' ? c.pop : c.jobs) / mx;
        if (v < 0.03 || c.water) continue;
        const h = CELL_HALF;
        const ring = [
          geo.toLL(c.x - h, c.y - h), geo.toLL(c.x + h, c.y - h),
          geo.toLL(c.x + h, c.y + h), geo.toLL(c.x - h, c.y + h), geo.toLL(c.x - h, c.y - h),
        ];
        const t = Math.min(1, v * 1.15);
        const r = Math.round(250 - 40 * t), g = Math.round(210 - 170 * t), b = Math.round(90 - 60 * t);
        feats.push({ type: 'Feature',
          geometry: { type: 'Polygon', coordinates: [ring] },
          properties: { color: `rgb(${r},${g},${b})`, op: 0.1 + 0.45 * t } });
      }
    }
    map3d.map.getSource('sb-demand').setData({ type: 'FeatureCollection', features: feats });

    const access = [];
    if (city && overlay === 'access') {
      for (const s of SB.game.state.stations) {
        access.push({ type: 'Feature',
          geometry: { type: 'Polygon', coordinates: circleCoords(s.lng, s.lat, SB.MODES[s.mode].access, 48) },
          properties: {} });
      }
    }
    map3d.map.getSource('sb-access').setData({ type: 'FeatureCollection', features: access });
  };
  const CELL_HALF = 150;

  // ── Hit-testing / helpers for main.js ────────────────────────────────
  map3d.stationAtPoint = function (point) {
    if (!map3d.ready) return null;
    const feats = map3d.map.queryRenderedFeatures(
      [[point.x - 9, point.y - 9], [point.x + 9, point.y + 9]],
      { layers: ['sb-stations'] });
    if (!feats.length) return null;
    return SB.game.stationById(feats[0].properties.id);
  };

  map3d.lineAtPoint = function (point) {
    if (!map3d.ready) return null;
    const feats = map3d.map.queryRenderedFeatures(
      [[point.x - 6, point.y - 6], [point.x + 6, point.y + 6]],
      { layers: ['sb-lines', 'sb-lines-dash'] });
    if (!feats.length) return null;
    return SB.game.lineById(feats[0].properties.lid);
  };

  /* Nearest real (unleased) railway station under the cursor. */
  map3d.railStationAtPoint = function (point) {
    if (!map3d.ready) return null;
    const feats = map3d.map.queryRenderedFeatures(
      [[point.x - 10, point.y - 10], [point.x + 10, point.y + 10]],
      { layers: ['sb-railstations'] });
    if (!feats.length) return null;
    const [lng, lat] = feats[0].geometry.coordinates;
    let best = null, bd = Infinity;
    for (const rs of SB.net.railStations) {
      const d = Math.hypot(rs.lng - lng, rs.lat - lat);
      if (d < bd) { bd = d; best = rs; }
    }
    return best;
  };

  map3d.focusLine = function (line) {
    const pts = line.stationIds.map((id) => SB.game.stationById(id)).filter(Boolean);
    if (!pts.length) return;
    const bounds = new maplibregl.LngLatBounds();
    for (const p of pts) bounds.extend([p.lng, p.lat]);
    map3d.map.fitBounds(bounds, { padding: 90, maxZoom: 14.5, duration: 700 });
  };

  map3d.setPitch3D = function (on) {
    if (map3d.settings.mode2d) return;
    map3d.map.easeTo({ pitch: on ? 55 : 0, duration: 600 });
  };

  /* Fly to a place and, once tiles are loaded, harvest the vector features
     the demand model needs. Runs the callback with {landuse, water, places}. */
  /* Two passes: a wide view for land use / water / places, then a closer
     view so the street network and POIs load in more detail. */
  map3d.surveyPlace = function (place, onDone) {
    const map = map3d.map;
    const collected = { landuse: [], water: [], places: [], transportation: [], poi: [] };

    function harvest(layers) {
      if (!vecSource) return;
      try {
        for (const layer of layers) {
          collected[layer].push(...map.querySourceFeatures(vecSource, {
            sourceLayer: layer === 'places' ? 'place' : layer,
          }));
        }
      } catch (e) { /* fall back to kernel city */ }
    }

    // Wait for tiles, but never hang: a stuck tile request must not block
    // the survey, so we also poll areTilesLoaded() and enforce a timeout.
    function whenSettled(cb, timeoutMs) {
      let done = false;
      const finish = () => {
        if (done) return;
        done = true;
        map.off('idle', finish);
        clearInterval(poll);
        clearTimeout(timer);
        cb();
      };
      const poll = setInterval(() => {
        try {
          if (map.loaded() && map.areTilesLoaded() && !map.isMoving()) finish();
        } catch (e) { finish(); }
      }, 400);
      const timer = setTimeout(finish, timeoutMs);
      map.on('idle', finish);
    }

    map.jumpTo({ center: [place.lng, place.lat], zoom: 11.7, pitch: 0, bearing: 0 });
    whenSettled(() => {
      harvest(['landuse', 'water', 'places', 'transportation', 'poi']);
      map.jumpTo({ center: [place.lng, place.lat], zoom: 12.7 });
      whenSettled(() => {
        harvest(['transportation', 'poi']);
        onDone(collected);
      }, 12000);
    }, 15000);
  };

  /* Read whatever vector tiles are already loaded for the current viewport,
     no camera movement. Lets the road/rail graphs grow as the player pans
     beyond the original surveyed area, instead of being capped to it. */
  map3d.harvestVisible = function (layers) {
    const out = {};
    for (const layer of layers) out[layer] = [];
    if (!vecSource || !map3d.map) return out;
    try {
      for (const layer of layers) {
        out[layer].push(...map3d.map.querySourceFeatures(vecSource, {
          sourceLayer: layer === 'places' ? 'place' : layer,
        }));
      }
    } catch (e) { /* tiles not ready yet — try again next idle */ }
    return out;
  };
})();
