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

  const params = new URLSearchParams(location.search);
  const theme = params.get('theme') === 'light' ? 'light' : 'dark';
  if (theme === 'light') document.body.classList.add('light');

  function sendToDart(name, args) {
    try {
      if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(JSON.stringify({ name, args }));
      } else if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('tt_bridge', name, args);
      }
    } catch (e) { /* no host attached yet */ }
  }

  const map = new maplibregl.Map({
    container: 'map',
    style: THEMES[theme].style,
    center: [2.5, 51.0], // English Channel / southern North Sea — busy shipping lanes
    zoom: 6,
    attributionControl: { compact: true },
  });
  map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-left');

  let ready = false;
  const pendingVessels = [];

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
        'circle-radius': 12,
        'circle-color': theme === 'light' ? '#7C5AD9' : '#B49DF5',
        'circle-opacity': 0.22,
      },
    });

    // Each vessel as a heading-oriented triangle, colored by ship category.
    map.addLayer({
      id: 'vessels-marker',
      type: 'symbol',
      source: 'vessels',
      layout: {
        'text-field': '▲',
        'text-size': ['interpolate', ['linear'], ['zoom'], 4, 11, 12, 20],
        'text-rotate': ['get', 'heading'],
        'text-rotation-alignment': 'map',
        'text-pitch-alignment': 'map',
        'text-allow-overlap': true,
        'text-ignore-placement': true,
      },
      paint: {
        'text-color': ['get', 'color'],
        'text-halo-color': theme === 'light' ? '#ffffff' : '#0d0f14',
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
        'text-size': 11,
        'text-offset': [0, 1.1],
        'text-anchor': 'top',
        'text-optional': true,
      },
      paint: {
        'text-color': theme === 'light' ? '#221E2E' : '#ECEAF4',
        'text-halo-color': theme === 'light' ? '#ffffff' : '#0d0f14',
        'text-halo-width': 1.2,
      },
    });

    map.on('click', 'vessels-marker', (e) => {
      const f = e.features && e.features[0];
      if (f) sendToDart('vesselClicked', [f.properties.mmsi]);
    });
    map.on('mouseenter', 'vessels-marker', () => { map.getCanvas().style.cursor = 'pointer'; });
    map.on('mouseleave', 'vessels-marker', () => { map.getCanvas().style.cursor = ''; });

    ready = true;
    if (pendingVessels.length) {
      map.getSource('vessels').setData(pendingVessels.pop());
      pendingVessels.length = 0;
    }
    reportBounds();

    const loading = document.getElementById('loading');
    if (loading) loading.classList.add('hide');
    sendToDart('mapReady', []);
  });

  function reportBounds() {
    const b = map.getBounds();
    sendToDart('boundsChanged', [b.getSouth(), b.getWest(), b.getNorth(), b.getEast()]);
  }
  map.on('moveend', reportBounds);

  window.TT = {
    updateVessels(featureCollection) {
      if (!ready) { pendingVessels.push(featureCollection); return; }
      map.getSource('vessels').setData(featureCollection);
    },
    flyTo(lat, lon, zoom) {
      map.flyTo({ center: [lon, lat], zoom: zoom || Math.max(map.getZoom(), 11), speed: 1.4 });
    },
    reportBounds,
  };
})();
