/* Subway Builder — real transport networks.

   Roads come from the loaded OSM vector tiles; the railway network and real
   train stations come from the Overpass API (with a vector-tile fallback).
   Surface routes (bus, tram) and train routes are found with A* over these
   graphs, so they follow streets and tracks that actually exist — across
   real bridges, never through buildings or open water. */
(function () {
  'use strict';
  const SB = (window.SB = window.SB || {});
  const geo = SB.geo;

  const QUANT = 14;      // meters — vertices closer than this merge into one node
  const BUCKET = 220;    // meters — spatial index cell for nearest-node lookups
  // meters — long OSM way segments get subdivided so a graph vertex exists
  // near any point along the line, not just at sparsely-placed original OSM
  // vertices (rural/branch track can have vertices 600m+ apart)
  const MAX_SEG = 120;

  const ROAD_CLASSES = new Set([
    'motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'minor',
    'residential', 'unclassified', 'living_street', 'busway',
  ]);

  const net = (SB.net = { roads: null, rails: null, railStations: [] });

  // ── Graph structure ──────────────────────────────────────────────────
  function newGraph() {
    return { xs: [], ys: [], adj: [], key2id: new Map(), buckets: new Map(), edges: 0 };
  }

  function nodeId(g, x, y) {
    const key = Math.round(x / QUANT) + ',' + Math.round(y / QUANT);
    let id = g.key2id.get(key);
    if (id === undefined) {
      id = g.xs.length;
      g.key2id.set(key, id);
      g.xs.push(x); g.ys.push(y); g.adj.push([]);
      const bk = Math.floor(x / BUCKET) + ',' + Math.floor(y / BUCKET);
      if (!g.buckets.has(bk)) g.buckets.set(bk, []);
      g.buckets.get(bk).push(id);
    }
    return id;
  }

  function addEdge(g, a, b) {
    if (a === b) return;
    const d = Math.hypot(g.xs[a] - g.xs[b], g.ys[a] - g.ys[b]);
    if (d < 0.5) return;
    for (const [n] of g.adj[a]) if (n === b) return;
    g.adj[a].push([b, d]);
    g.adj[b].push([a, d]);
    g.edges++;
  }

  function addLineString(g, coords) {
    let prev = -1;
    let prevXY = null;
    for (const [lng, lat] of coords) {
      const [x, y] = geo.toM(lng, lat);
      if (prev >= 0 && prevXY) {
        const segLen = Math.hypot(x - prevXY[0], y - prevXY[1]);
        const steps = Math.floor(segLen / MAX_SEG);
        let last = prev;
        for (let i = 1; i <= steps; i++) {
          const t = (i * MAX_SEG) / segLen;
          const id = nodeId(g, prevXY[0] + (x - prevXY[0]) * t, prevXY[1] + (y - prevXY[1]) * t);
          addEdge(g, last, id);
          last = id;
        }
        const id = nodeId(g, x, y);
        addEdge(g, last, id);
        prev = id;
      } else {
        prev = nodeId(g, x, y);
      }
      prevXY = [x, y];
    }
  }

  function addFeatureLines(g, feature) {
    const gm = feature.geometry;
    if (!gm) return;
    if (gm.type === 'LineString') addLineString(g, gm.coordinates);
    else if (gm.type === 'MultiLineString') for (const c of gm.coordinates) addLineString(g, c);
  }

  net.nearestNode = function (g, x, y, maxDist) {
    if (!g || !g.xs.length) return -1;
    const r = Math.ceil(maxDist / BUCKET);
    const bx = Math.floor(x / BUCKET), by = Math.floor(y / BUCKET);
    let best = -1, bd = maxDist;
    for (let dx = -r; dx <= r; dx++) {
      for (let dy = -r; dy <= r; dy++) {
        const ids = g.buckets.get((bx + dx) + ',' + (by + dy));
        if (!ids) continue;
        for (const id of ids) {
          const d = Math.hypot(g.xs[id] - x, g.ys[id] - y);
          if (d < bd) { bd = d; best = id; }
        }
      }
    }
    return best;
  };

  // A* shortest path; returns array of node ids or null.
  function astar(g, src, dst) {
    const N = g.xs.length;
    const dist = new Float64Array(N).fill(Infinity);
    const parent = new Int32Array(N).fill(-1);
    const closed = new Uint8Array(N);
    const tx = g.xs[dst], ty = g.ys[dst];
    dist[src] = 0;
    const hd = [Math.hypot(g.xs[src] - tx, g.ys[src] - ty)], hn = [src];
    function push(d, n) {
      let i = hd.length;
      hd.push(d); hn.push(n);
      while (i > 0) {
        const p = (i - 1) >> 1;
        if (hd[p] <= hd[i]) break;
        [hd[p], hd[i]] = [hd[i], hd[p]];
        [hn[p], hn[i]] = [hn[i], hn[p]];
        i = p;
      }
    }
    function pop() {
      const top = hn[0];
      const ld = hd.pop(), ln = hn.pop();
      if (hd.length) {
        hd[0] = ld; hn[0] = ln;
        let i = 0;
        for (;;) {
          const l = i * 2 + 1, r = l + 1;
          let m = i;
          if (l < hd.length && hd[l] < hd[m]) m = l;
          if (r < hd.length && hd[r] < hd[m]) m = r;
          if (m === i) break;
          [hd[m], hd[i]] = [hd[i], hd[m]];
          [hn[m], hn[i]] = [hn[i], hn[m]];
          i = m;
        }
      }
      return top;
    }
    while (hd.length) {
      const u = pop();
      if (u === dst) break;
      if (closed[u]) continue;
      closed[u] = 1;
      for (const [v, w] of g.adj[u]) {
        const nd = dist[u] + w;
        if (nd < dist[v] - 1e-6) {
          dist[v] = nd;
          parent[v] = u;
          push(nd + Math.hypot(g.xs[v] - tx, g.ys[v] - ty), v);
        }
      }
    }
    if (!isFinite(dist[dst])) return null;
    const path = [];
    for (let n = dst; n >= 0; n = parent[n]) path.push(n);
    path.reverse();
    return path;
  }

  // Douglas–Peucker simplification on meter points.
  function simplify(pts, eps) {
    if (pts.length <= 2) return pts;
    const keep = new Uint8Array(pts.length);
    keep[0] = keep[pts.length - 1] = 1;
    const stack = [[0, pts.length - 1]];
    while (stack.length) {
      const [a, b] = stack.pop();
      let worst = -1, wd = eps;
      const ax = pts[a][0], ay = pts[a][1], bx = pts[b][0], by = pts[b][1];
      const dx = bx - ax, dy = by - ay;
      const l2 = dx * dx + dy * dy || 1;
      for (let i = a + 1; i < b; i++) {
        let t = ((pts[i][0] - ax) * dx + (pts[i][1] - ay) * dy) / l2;
        t = Math.max(0, Math.min(1, t));
        const d = Math.hypot(pts[i][0] - (ax + t * dx), pts[i][1] - (ay + t * dy));
        if (d > wd) { wd = d; worst = i; }
      }
      if (worst >= 0) { keep[worst] = 1; stack.push([a, worst], [worst, b]); }
    }
    return pts.filter((_, i) => keep[i]);
  }

  /* Route between two meter points over a graph. Returns
     {pts: [[x,y],…], len} following real geometry, or null. */
  net.route = function (g, ax, ay, bx, by, snapDist) {
    const a = net.nearestNode(g, ax, ay, snapDist);
    const b = net.nearestNode(g, bx, by, snapDist);
    if (a < 0 || b < 0) return null;
    const ids = astar(g, a, b);
    if (!ids) return null;
    let pts = ids.map((id) => [g.xs[id], g.ys[id]]);
    pts = simplify(pts, 5);
    // Anchor the ends on the actual stop positions.
    pts.unshift([ax, ay]);
    pts.push([bx, by]);
    let len = 0;
    for (let i = 0; i < pts.length - 1; i++) {
      len += Math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]);
    }
    return { pts, len };
  };

  // ── Building the networks ────────────────────────────────────────────
  net.buildRoads = function (transportFeatures) {
    const g = newGraph();
    for (const f of transportFeatures) {
      const cls = f.properties && f.properties.class;
      if (ROAD_CLASSES.has(cls)) addFeatureLines(g, f);
    }
    net.roads = g;
    return g;
  };

  net.buildRailsFromTiles = function (transportFeatures) {
    const g = newGraph();
    for (const f of transportFeatures) {
      const p = f.properties || {};
      if (p.class === 'rail' && p.subclass !== 'subway' && p.subclass !== 'tram' &&
          p.subclass !== 'monorail' && p.subclass !== 'funicular') {
        addFeatureLines(g, f);
      }
    }
    net.rails = g;
    return g;
  };

  net.railStationsFromTiles = function (poiFeatures) {
    const out = [];
    for (const f of poiFeatures) {
      const p = f.properties || {};
      if (p.class !== 'railway') continue;
      if (p.subclass && !['station', 'halt', 'train_station'].includes(p.subclass)) continue;
      if (!f.geometry || f.geometry.type !== 'Point') continue;
      const [lng, lat] = f.geometry.coordinates;
      const [x, y] = geo.toM(lng, lat);
      out.push({ name: p.name || 'Station', lng, lat, x, y });
    }
    return dedupeStations(out);
  };

  function dedupeStations(list) {
    const out = [];
    for (const s of list) {
      if (!out.some((o) => Math.hypot(o.x - s.x, o.y - s.y) < 180)) out.push(s);
    }
    return out;
  }

  /* Grow the road/rail graphs from whatever tiles the player has scrolled
     into view, so pathfinding keeps working arbitrarily far from the
     originally surveyed city — not just inside the initial build() call.
     addFeatureLines/nodeId already dedupe by quantized coordinate, so
     re-adding the same street twice is harmless. */
  net.mergeRoads = function (transportFeatures) {
    if (!net.roads) return net.buildRoads(transportFeatures);
    for (const f of transportFeatures) {
      const cls = f.properties && f.properties.class;
      if (ROAD_CLASSES.has(cls)) addFeatureLines(net.roads, f);
    }
    return net.roads;
  };

  net.mergeRailsFromTiles = function (transportFeatures, poiFeatures) {
    if (!net.rails) net.rails = newGraph();
    for (const f of transportFeatures) {
      const p = f.properties || {};
      if (p.class === 'rail' && p.subclass !== 'subway' && p.subclass !== 'tram' &&
          p.subclass !== 'monorail' && p.subclass !== 'funicular') {
        addFeatureLines(net.rails, f);
      }
    }
    const found = net.railStationsFromTiles(poiFeatures);
    for (const s of found) {
      if (net.railStations.some((o) => Math.hypot(o.x - s.x, o.y - s.y) < 180)) continue;
      if (net.nearestNode(net.rails, s.x, s.y, 420) >= 0) net.railStations.push(s);
    }
  };

  /* The authoritative source: Overpass gives full-detail railway=rail ways
     and railway=station/halt nodes in one call. Falls back to tile data. */
  net.fetchRailFromOverpass = async function (lat, lng, radius) {
    const q = '[out:json][timeout:22];(' +
      'way["railway"="rail"](around:' + radius + ',' + lat + ',' + lng + ');' +
      'node["railway"~"^(station|halt)$"]["station"!~"subway|light_rail"](around:' + radius + ',' + lat + ',' + lng + ');' +
      ');out geom;';
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), 20000);
    let res;
    try {
      res = await fetch('https://overpass-api.de/api/interpreter', {
        method: 'POST',
        body: 'data=' + encodeURIComponent(q),
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        signal: abort.signal,
      });
    } finally {
      clearTimeout(timer);
    }
    if (!res.ok) throw new Error('overpass ' + res.status);
    const data = await res.json();
    const g = newGraph();
    const stations = [];
    for (const el of data.elements || []) {
      if (el.type === 'way' && el.geometry) {
        addLineString(g, el.geometry.map((p) => [p.lon, p.lat]));
      } else if (el.type === 'node') {
        const [x, y] = geo.toM(el.lon, el.lat);
        if (Math.hypot(x, y) > radius) continue;
        stations.push({
          name: (el.tags && el.tags.name) || 'Station',
          lng: el.lon, lat: el.lat, x, y,
        });
      }
    }
    return { graph: g, stations: dedupeStations(stations) };
  };

  /* Rail corridors between cities are usually never on screen, so their
     tracks exist in neither the initial Overpass fetch (radius-bound) nor
     the visible-tile merges. Fetch railway=rail for a bbox covering the
     given stops (~10 km margin) and merge it into the live rail graph. */
  let corridorInFlight = false;
  net.surveyRailCorridor = async function (stops) {
    if (corridorInFlight || !stops.length) return false;
    corridorInFlight = true;
    try {
      let s = Infinity, w = Infinity, n = -Infinity, e = -Infinity;
      for (const p of stops) {
        s = Math.min(s, p.lat); n = Math.max(n, p.lat);
        w = Math.min(w, p.lng); e = Math.max(e, p.lng);
      }
      const mLat = 10000 / 111320;
      const mLng = 10000 / (111320 * Math.max(0.2, Math.cos(((s + n) / 2) * Math.PI / 180)));
      const q = '[out:json][timeout:22];way["railway"="rail"](' +
        (s - mLat) + ',' + (w - mLng) + ',' + (n + mLat) + ',' + (e + mLng) + ');out geom;';
      const abort = new AbortController();
      const timer = setTimeout(() => abort.abort(), 20000);
      let res;
      try {
        res = await fetch('https://overpass-api.de/api/interpreter', {
          method: 'POST',
          body: 'data=' + encodeURIComponent(q),
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          signal: abort.signal,
        });
      } finally {
        clearTimeout(timer);
      }
      if (!res.ok) throw new Error('overpass ' + res.status);
      const data = await res.json();
      if (!net.rails) net.rails = newGraph();
      let ways = 0;
      for (const el of data.elements || []) {
        if (el.type === 'way' && el.geometry) {
          addLineString(net.rails, el.geometry.map((p) => [p.lon, p.lat]));
          ways++;
        }
      }
      return ways > 0;
    } catch (e) {
      return false;
    } finally {
      corridorInFlight = false;
    }
  };

  /* Assemble everything after a survey. Async because of Overpass. */
  net.build = async function (collected, place, onProgress) {
    net.buildRoads(collected.transportation || []);
    if (onProgress) onProgress('Reading the street network… ' + SB.fmtInt(net.roads.xs.length) + ' road nodes');
    try {
      const rail = await net.fetchRailFromOverpass(place.lat, place.lng, SB.demand.RADIUS);
      if (rail.graph.xs.length > 10 || rail.stations.length > 0) {
        net.rails = rail.graph;
        net.railStations = rail.stations;
      } else {
        throw new Error('empty');
      }
    } catch (e) {
      // Tile fallback — less detailed, but still real OSM geometry.
      net.buildRailsFromTiles(collected.transportation || []);
      net.railStations = net.railStationsFromTiles(collected.poi || []);
    }
    // Only offer stations that are actually connected to the rail graph.
    net.railStations = net.railStations.filter(
      (s) => net.nearestNode(net.rails, s.x, s.y, 420) >= 0
    );
    if (onProgress) {
      onProgress('Found ' + net.railStations.length + ' real train stations, ' +
        SB.fmtInt(net.rails ? net.rails.xs.length : 0) + ' rail nodes');
    }
  };
})();
