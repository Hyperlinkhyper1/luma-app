/* Transport Tracker — MapLibre GL layer. A plain OpenStreetMap basemap
 * (OpenFreeMap vector tiles, no API key) plus a single GeoJSON source of
 * vessel positions pushed in from Dart. All list/detail UI lives natively
 * in Flutter around this WebView — this file only owns the map canvas. */
(function () {
  'use strict';

  const THEMES = {
    dark: { style: 'https://tiles.openfreemap.org/styles/dark' },
    light: { style: 'https://tiles.openfreemap.org/styles/positron' },
  };

  // The OpenFreeMap styles only publish glyphs for this one font stack
  // (their /fonts/{fontstack}/{range}.pbf endpoint 404s for anything else,
  // including MapLibre's built-in "Open Sans Regular" default). A symbol
  // layer that asks for a missing stack renders no text at all, so every
  // text layer here must name this explicitly.
  const FONT = ['Noto Sans Regular'];

  const params = new URLSearchParams(location.search);
  const theme = params.get('theme') === 'light' ? 'light' : 'dark';
  if (theme === 'light') document.body.classList.add('light');

  const INK = theme === 'light' ? '#221E2E' : '#ECEAF4';
  const HALO = theme === 'light' ? '#ffffff' : '#0d0f14';

  function sendToDart(name, args) {
    try {
      if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(JSON.stringify({ name, args }));
      } else if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('tt_bridge', name, args);
      }
    } catch (e) { /* no host attached yet */ }
  }

  /* Vessel markers are canvas-drawn triangles registered as map images
     rather than a rotated text glyph. Glyph rendering depends on the
     style's font stack actually serving the codepoint; an image does not
     depend on anything, so markers stay visible no matter what the tile
     server publishes. One image is generated per distinct colour, named
     `ves-<hex>`, so Dart only has to send a colour per feature. */
  const ICON_PX = 26;
  const registeredIcons = new Set();

  function triangleImage(hex) {
    const r = 2; // device pixel ratio for a crisp icon
    const size = ICON_PX * r;
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    // Bow-forward triangle pointing north (icon-rotate turns it clockwise).
    ctx.beginPath();
    ctx.moveTo(size * 0.5, size * 0.06);
    ctx.lineTo(size * 0.87, size * 0.94);
    ctx.lineTo(size * 0.5, size * 0.72);
    ctx.lineTo(size * 0.13, size * 0.94);
    ctx.closePath();
    ctx.fillStyle = hex;
    ctx.fill();
    ctx.lineWidth = Math.max(1, size * 0.05);
    ctx.strokeStyle = HALO;
    ctx.stroke();
    return { data: ctx.getImageData(0, 0, size, size), pixelRatio: r };
  }

  function ensureIcon(hex) {
    const id = 'ves-' + hex;
    if (registeredIcons.has(id) || map.hasImage(id)) return id;
    const img = triangleImage(hex);
    map.addImage(id, img.data, { pixelRatio: img.pixelRatio });
    registeredIcons.add(id);
    return id;
  }

  const map = new maplibregl.Map({
    container: 'map',
    style: THEMES[theme].style,
    center: [2.5, 51.0], // English Channel / southern North Sea — busy shipping lanes
    zoom: 6,
    attributionControl: false,
  });
  // Both docked bottom-left: Flutter's own overlay owns the top of the map
  // and its vessel panel owns the right-hand side.
  map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'bottom-left');
  map.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-left');

  // Replaced by onWheel above so zoom anchors on the cursor rather than the
  // corner; see the note on hostPointer.
  map.scrollZoom.disable();
  map.getContainer().addEventListener('wheel', onWheel, { passive: false });

  let ready = false;
  let pendingVessels = null;
  let pendingTransit = null;
  const pendingVisibility = {};

  /* ── Cursor-anchored scroll zoom ──────────────────────────────────────
     Inside the embedded WebView the host (Flutter) owns the mouse and
     forwards the wheel, but no `mousemove` ever reaches the page — so the
     document's idea of the cursor stays at (0, 0) and MapLibre's own
     scroll zoom anchors every step to the top-left corner. The host pushes
     the real pointer position through `TT.setPointer`, and wheel handling
     is done here so it can zoom around that point.

     A wheel event that does carry a real position (an ordinary browser)
     is trusted over the pushed one, so this behaves normally outside the
     WebView too. */
  let hostPointer = null;

  function wheelAnchor(e) {
    const rect = map.getContainer().getBoundingClientRect();
    if (e.clientX || e.clientY) {
      return { x: e.clientX - rect.left, y: e.clientY - rect.top };
    }
    if (hostPointer) return hostPointer;
    return null;
  }

  function onWheel(e) {
    e.preventDefault();
    // deltaMode 1 is lines, 0 is pixels; normalise both to zoom levels.
    const step = e.deltaMode === 1 ? e.deltaY * 0.08 : e.deltaY * 0.0035;
    const target = Math.max(
      map.getMinZoom(),
      Math.min(map.getMaxZoom(), map.getZoom() - step),
    );
    const anchor = wheelAnchor(e);
    const options = { zoom: target, duration: 90 };
    if (anchor) options.around = map.unproject([anchor.x, anchor.y]);
    map.easeTo(options);
  }

  /* Layer groups the host can switch on and off from its options menu. */
  const LAYER_GROUPS = {
    vessels: ['vessels-ring', 'vessels-dot', 'vessels-marker', 'vessels-label'],
    transit: ['transit-dot', 'transit-label'],
  };

  function applyVisibility(group, visible) {
    const layers = LAYER_GROUPS[group];
    if (!layers) return;
    for (const id of layers) {
      if (map.getLayer(id)) {
        map.setLayoutProperty(id, 'visibility', visible ? 'visible' : 'none');
      }
    }
  }

  /* Safety net: if a feature ever references an icon that hasn't been
     registered yet, build it on demand from the colour encoded in its id
     instead of silently drawing nothing. */
  map.on('styleimagemissing', (e) => {
    if (typeof e.id === 'string' && e.id.startsWith('ves-')) {
      const hex = e.id.slice(4);
      if (/^#[0-9a-fA-F]{6}$/.test(hex) && !map.hasImage(e.id)) {
        const img = triangleImage(hex);
        map.addImage(e.id, img.data, { pixelRatio: img.pixelRatio });
        registeredIcons.add(e.id);
      }
    }
  });

  // Surface style/tile/glyph failures to Dart instead of leaving a blank map.
  map.on('error', (e) => {
    const msg = (e && e.error && e.error.message) ? e.error.message : String(e && e.error);
    sendToDart('mapError', [msg]);
  });

  map.on('load', () => {
    map.addSource('vessels', {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
      promoteId: 'mmsi',
    });

    // Soft ring under the marker for the currently-selected vessel.
    map.addLayer({
      id: 'vessels-ring',
      type: 'circle',
      source: 'vessels',
      filter: ['==', ['get', 'selected'], true],
      paint: {
        'circle-radius': 14,
        'circle-color': theme === 'light' ? '#7C5AD9' : '#B49DF5',
        'circle-opacity': 0.25,
      },
    });

    // A plain colour dot under every vessel. Circles need neither fonts nor
    // images, so even in the worst case something is always on screen.
    map.addLayer({
      id: 'vessels-dot',
      type: 'circle',
      source: 'vessels',
      paint: {
        'circle-radius': ['interpolate', ['linear'], ['zoom'], 3, 1.6, 8, 2.6, 14, 3.4],
        'circle-color': ['get', 'color'],
        'circle-stroke-width': 0.6,
        'circle-stroke-color': HALO,
      },
    });

    // Heading-oriented hull triangle on top of the dot.
    map.addLayer({
      id: 'vessels-marker',
      type: 'symbol',
      source: 'vessels',
      layout: {
        'icon-image': ['concat', 'ves-', ['get', 'color']],
        'icon-size': ['interpolate', ['linear'], ['zoom'], 3, 0.32, 8, 0.5, 14, 0.85],
        'icon-rotate': ['get', 'heading'],
        'icon-rotation-alignment': 'map',
        'icon-pitch-alignment': 'map',
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
      },
    });

    /* ── Public transport ────────────────────────────────────────────
       Separate source from vessels: transit feeds carry no heading, so
       these are drawn as plain dots with a line-number label rather than
       oriented hulls. */
    map.addSource('transit', {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
      promoteId: 'id',
    });

    map.addLayer({
      id: 'transit-dot',
      type: 'circle',
      source: 'transit',
      paint: {
        'circle-radius': ['interpolate', ['linear'], ['zoom'], 6, 2.4, 10, 4.5, 14, 7],
        'circle-color': ['get', 'color'],
        'circle-stroke-width': ['interpolate', ['linear'], ['zoom'], 6, 0.5, 12, 1.4],
        'circle-stroke-color': HALO,
      },
    });

    // Line number sits inside the dot once there is room for it.
    map.addLayer({
      id: 'transit-label',
      type: 'symbol',
      source: 'transit',
      minzoom: 12,
      layout: {
        'text-field': ['get', 'line'],
        'text-font': FONT,
        'text-size': 10,
        'text-offset': [0, 1.1],
        'text-anchor': 'top',
        'text-optional': true,
        'text-allow-overlap': false,
      },
      paint: {
        'text-color': INK,
        'text-halo-color': HALO,
        'text-halo-width': 1.2,
      },
    });

    // Name labels once zoomed in enough to not clutter the view.
    map.addLayer({
      id: 'vessels-label',
      type: 'symbol',
      source: 'vessels',
      minzoom: 8,
      layout: {
        'text-field': ['get', 'name'],
        'text-font': FONT,
        'text-size': 11,
        'text-offset': [0, 1.2],
        'text-anchor': 'top',
        'text-optional': true,
      },
      paint: {
        'text-color': INK,
        'text-halo-color': HALO,
        'text-halo-width': 1.2,
      },
    });

    const pick = (e) => {
      const f = e.features && e.features[0];
      if (f) sendToDart('vesselClicked', [f.properties.mmsi]);
    };
    map.on('click', 'vessels-marker', pick);
    map.on('click', 'vessels-dot', pick);
    for (const layer of ['vessels-marker', 'vessels-dot']) {
      map.on('mouseenter', layer, () => { map.getCanvas().style.cursor = 'pointer'; });
      map.on('mouseleave', layer, () => { map.getCanvas().style.cursor = ''; });
    }

    map.on('click', 'transit-dot', (e) => {
      const f = e.features && e.features[0];
      if (f) sendToDart('transitClicked', [String(f.properties.id)]);
    });
    map.on('mouseenter', 'transit-dot', () => { map.getCanvas().style.cursor = 'pointer'; });
    map.on('mouseleave', 'transit-dot', () => { map.getCanvas().style.cursor = ''; });

    ready = true;
    if (pendingVessels) {
      applyVessels(pendingVessels);
      pendingVessels = null;
    }
    if (pendingTransit) {
      map.getSource('transit').setData(pendingTransit);
      pendingTransit = null;
    }
    for (const [id, visible] of Object.entries(pendingVisibility)) {
      applyVisibility(id, visible);
    }
    reportBounds();

    const loading = document.getElementById('loading');
    if (loading) loading.classList.add('hide');
    sendToDart('mapReady', []);
  });

  function applyVessels(featureCollection) {
    const features = (featureCollection && featureCollection.features) || [];
    for (const f of features) {
      const color = f.properties && f.properties.color;
      if (typeof color === 'string') ensureIcon(color);
    }
    map.getSource('vessels').setData(featureCollection);
  }

  function reportBounds() {
    const b = map.getBounds();
    sendToDart('boundsChanged', [b.getSouth(), b.getWest(), b.getNorth(), b.getEast()]);
  }
  map.on('moveend', reportBounds);

  /* The map object knows its centre and zoom the moment it is constructed,
     so bounds are reported straight away rather than waiting for 'load'.
     Without this a style or network failure (which stops 'load' from ever
     firing) would leave the host with no bounds and its tracking button
     disabled forever. */
  reportBounds();

  window.TT = {
    // Exposed for debugging from the WebView console, the same way Subway
    // Builder exposes SB.map3d.map.
    map,
    updateVessels(featureCollection) {
      if (!ready) { pendingVessels = featureCollection; return; }
      applyVessels(featureCollection);
    },
    updateTransit(featureCollection) {
      if (!ready) { pendingTransit = featureCollection; return; }
      map.getSource('transit').setData(featureCollection);
    },
    setLayerVisible(group, visible) {
      if (!ready) { pendingVisibility[group] = visible; return; }
      applyVisibility(group, visible);
    },
    /// Host-reported cursor position in CSS pixels relative to the map.
    setPointer(x, y) {
      hostPointer = { x: x, y: y };
    },
    flyTo(lat, lon, zoom) {
      map.flyTo({ center: [lon, lat], zoom: zoom || Math.max(map.getZoom(), 11), speed: 1.4 });
    },
    reportBounds,
  };
})();
