/* Subway Builder — commuter simulation.

   Demand: OD flows sampled from the OSM-derived population/jobs surfaces
   with gravity distance decay. Assignment: every flow compares door-to-door
   transit time (walk + wait + ride + transfers, crowding delays included)
   against driving and splits by a logistic mode-choice curve. Riders are
   pushed onto the exact segments of their best path, giving per-segment
   loads, boardings and crowding feedback. All four modes (metro, tram, bus,
   train) live in one graph, with walking transfers between nearby stops. */
(function () {
  'use strict';
  const SB = (window.SB = window.SB || {});

  const TUNE = {
    numFlows: 6000,
    decayM: 6200,
    walkMpm: 78,           // walk meters/minute (~4.7 km/h)
    routeFactor: 1.28,     // euclidean → street distance (walk & car legs)
    accessMax: 4,          // candidate stops per trip end
    carKmh: 27,
    carPenaltyMin: 7,      // parking + walk at both ends
    farePerMin: 2.2,       // $1 of fare ≈ 2.2 minutes of perceived time
    modeSpread: 5.5,
    boardMin: 0.4,
    alightMin: 0.3,
    waitCapMin: 12,
    transferWalkMax: 350,  // meters between stops that count as a transfer walk
    peakFactor: 0.14,
    delayGain: 0.5,
    delayMax: 1.8,
    dwellVisS: 9,
  };

  const sim = (SB.sim = { results: null, tune: TUNE });

  // ── Demand flows ─────────────────────────────────────────────────────
  let flows = [];
  let flowsCityId = null;

  function buildFlows() {
    const city = SB.game.city;
    const rng = (function (seed) {
      let a = seed >>> 0;
      return function () {
        a |= 0; a = (a + 0x6D2B79F5) | 0;
        let t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
      };
    })(city.def.seed ^ 0x51ab3e);

    const cells = city.cells;
    const popPrefix = [], jobsPrefix = [];
    let ps = 0, js = 0;
    for (const c of cells) { ps += c.pop; popPrefix.push(ps); js += c.jobs; jobsPrefix.push(js); }

    function pickPrefix(prefix, total) {
      const r = rng() * total;
      let lo = 0, hi = prefix.length - 1;
      while (lo < hi) {
        const mid = (lo + hi) >> 1;
        if (prefix[mid] < r) lo = mid + 1; else hi = mid;
      }
      return lo;
    }

    flows = [];
    const n = city.commuters / TUNE.numFlows;
    for (let i = 0; i < TUNE.numFlows; i++) {
      const oc = pickPrefix(popPrefix, ps);
      let dc = -1, bestW = -1;
      for (let k = 0; k < 12; k++) {
        const cand = pickPrefix(jobsPrefix, js);
        const d = Math.hypot(cells[cand].x - cells[oc].x, cells[cand].y - cells[oc].y);
        const w = Math.exp(-d / TUNE.decayM) * (0.35 + rng());
        if (w > bestW) { bestW = w; dc = cand; }
      }
      const o = cells[oc], d = cells[dc];
      const jx = (rng() - 0.5) * 180, jy = (rng() - 0.5) * 180;
      const ox = o.x + jx, oy = o.y + jy, dx = d.x - jx, dy = d.y + jy;
      const distM = Math.hypot(dx - ox, dy - oy);
      if (distM < 700) continue;
      flows.push({
        ox, oy, dx, dy, oc, dc, n, distM,
        carMin: (distM * TUNE.routeFactor / 1000 / TUNE.carKmh) * 60 + TUNE.carPenaltyMin,
      });
    }
    flowsCityId = city.def.id;
  }

  // ── Stop access index (cell → nearby stops, radius per stop mode) ────
  let accessCache = new Map();
  let accessRev = '';

  function stationsRevision() {
    return SB.game.state.stations.map((s) => s.id + ':' + s.mode + ':' + Math.round(s.x) + ':' + Math.round(s.y)).join('|');
  }

  function accessFor(x, y) {
    const stations = SB.game.state.stations;
    const found = [];
    for (let i = 0; i < stations.length; i++) {
      const d = Math.hypot(stations[i].x - x, stations[i].y - y);
      if (d <= SB.MODES[stations[i].mode].access) found.push([d, i]);
    }
    found.sort((a, b) => a[0] - b[0]);
    return found.slice(0, TUNE.accessMax)
      .map(([d, i]) => ({ si: i, walkMin: (d * TUNE.routeFactor) / TUNE.walkMpm }));
  }

  function cellAccess(key, x, y) {
    let a = accessCache.get(key);
    if (!a) { a = accessFor(x, y); accessCache.set(key, a); }
    return a;
  }

  // ── Transit graph ────────────────────────────────────────────────────
  let lineDelay = new Map();

  function lineOneWayMin(line) {
    const M = SB.MODES[line.mode];
    const lenKm = SB.game.lineLengthM(line) / 1000;
    return (lenKm / M.speedKmh) * 60 + M.dwellMin * (line.stationIds.length - 1);
  }

  sim.headwayMin = function (line) {
    if (line.vehicles <= 0) return Infinity;
    // A loop's "round trip" is one circuit; a shuttle has to go out and back.
    const cycle = SB.isLoopLine(line) ? lineOneWayMin(line) : 2 * lineOneWayMin(line);
    return Math.max(2, cycle / line.vehicles);
  };

  function buildGraph() {
    const st = SB.game.state;
    const S = st.stations.length;
    const stationIdx = new Map();
    st.stations.forEach((s, i) => stationIdx.set(s.id, i));

    let nodeCount = S;
    const adj = Array.from({ length: S }, () => []);
    function addNode() { adj.push([]); return nodeCount++; }

    // Walking transfers between different stops that sit close together
    // (e.g. a bus stop outside a metro station).
    for (let i = 0; i < S; i++) {
      for (let j = i + 1; j < S; j++) {
        const a = st.stations[i], b = st.stations[j];
        const d = Math.hypot(a.x - b.x, a.y - b.y);
        if (d <= TUNE.transferWalkMax) {
          const w = (d * TUNE.routeFactor) / TUNE.walkMpm + 0.8;
          adj[i].push({ to: j, w, kind: 'walk' });
          adj[j].push({ to: i, w, kind: 'walk' });
        }
      }
    }

    for (const line of st.lines) {
      const M = SB.MODES[line.mode];
      const world = SB.world && SB.world.delayFor ? SB.world.delayFor(line) : 1;
      const delay = (lineDelay.get(line.id) || 1) * world;
      const wait = Math.min(TUNE.waitCapMin, sim.headwayMin(line) / 2) + TUNE.boardMin;
      const rideNodes = [];
      for (let k = 0; k < line.stationIds.length; k++) {
        const nid = addNode();
        rideNodes.push(nid);
        const hub = stationIdx.get(line.stationIds[k]);
        adj[hub].push({ to: nid, w: wait, kind: 'board', line: line.id, stop: k, si: hub });
        adj[nid].push({ to: hub, w: TUNE.alightMin, kind: 'alight', si: hub });
      }
      for (let k = 0; k < rideNodes.length - 1; k++) {
        const t = ((SB.game.segLenM(line, k) / 1000 / M.speedKmh) * 60 + M.dwellMin) * delay;
        adj[rideNodes[k]].push({ to: rideNodes[k + 1], w: t, kind: 'ride', line: line.id, seg: k });
        adj[rideNodes[k + 1]].push({ to: rideNodes[k], w: t, kind: 'ride', line: line.id, seg: k });
      }
    }
    return { S, adj, nodeCount };
  }

  function dijkstra(graph, src) {
    const N = graph.nodeCount;
    const dist = new Float64Array(N).fill(Infinity);
    const parent = new Int32Array(N).fill(-1);
    const parentEdge = new Array(N).fill(null);
    dist[src] = 0;
    const hd = [0], hn = [src];
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
      const top = [hd[0], hn[0]];
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
      const [d, u] = pop();
      if (d > dist[u]) continue;
      for (const e of graph.adj[u]) {
        const nd = d + e.w;
        if (nd < dist[e.to] - 1e-9) {
          dist[e.to] = nd;
          parent[e.to] = u;
          parentEdge[e.to] = e;
          push(nd, e.to);
        }
      }
    }
    return { dist, parent, parentEdge };
  }

  // ── Assignment ───────────────────────────────────────────────────────
  sim.assign = function () {
    const g = SB.game;
    const st = g.state;
    if (flowsCityId !== g.city.def.id) buildFlows();

    const rev = stationsRevision();
    if (rev !== accessRev) { accessCache = new Map(); accessRev = rev; }

    const graph = buildGraph();
    const sp = new Array(graph.S).fill(null);
    function shortest(src) {
      if (!sp[src]) sp[src] = dijkstra(graph, src);
      return sp[src];
    }

    const segLoads = new Map();
    const lineRiders = new Map();
    const boardings = new Map();
    for (const line of st.lines) {
      segLoads.set(line.id, new Float64Array(Math.max(0, line.stationIds.length - 1)));
      lineRiders.set(line.id, 0);
    }

    let riders = 0, carPeople = 0, transfers = 0;
    let tMinSum = 0, cMinSum = 0, total = 0;
    const fareMin = st.fare * TUNE.farePerMin;
    const modeRiders = { metro: 0, tram: 0, bus: 0, train: 0 };

    for (const f of flows) {
      total += f.n;
      const acc = cellAccess('o' + f.oc, f.ox, f.oy);
      const egr = cellAccess('d' + f.dc, f.dx, f.dy);
      let bestT = Infinity, bestA = -1, bestB = -1;
      for (const a of acc) {
        const d = shortest(a.si);
        for (const b of egr) {
          if (a.si === b.si) continue;
          const t = a.walkMin + d.dist[b.si] + b.walkMin;
          if (t < bestT) { bestT = t; bestA = a.si; bestB = b.si; }
        }
      }
      if (!isFinite(bestT)) { carPeople += f.n; cMinSum += f.carMin * f.n; continue; }

      const p = 1 / (1 + Math.exp((bestT + fareMin - f.carMin) / TUNE.modeSpread));
      const r = f.n * p;
      riders += r;
      carPeople += f.n - r;
      tMinSum += bestT * r;
      cMinSum += f.carMin * (f.n - r);

      if (r > 0.01) {
        const d = shortest(bestA);
        let node = bestB;
        let boardsOnPath = 0;
        while (node !== bestA && node >= 0) {
          const e = d.parentEdge[node];
          if (!e) break;
          if (e.kind === 'ride') {
            const arr = segLoads.get(e.line);
            if (arr) arr[e.seg] += r;
          } else if (e.kind === 'board') {
            boardsOnPath++;
            boardings.set(st.stations[e.si].id, (boardings.get(st.stations[e.si].id) || 0) + r);
            lineRiders.set(e.line, (lineRiders.get(e.line) || 0) + r);
            const line = g.lineById(e.line);
            if (line) modeRiders[line.mode] += r;
          }
          node = d.parent[node];
        }
        if (boardsOnPath > 1) transfers += (boardsOnPath - 1) * r;
      }
    }

    // Crowding → per-line delay multiplier used by the next assignment.
    const lineMaxRatio = new Map();
    const crowded = [];
    for (const line of st.lines) {
      const arr = segLoads.get(line.id);
      let maxLoad = 0;
      for (let i = 0; i < arr.length; i++) maxLoad = Math.max(maxLoad, arr[i]);
      const headway = sim.headwayMin(line);
      const capHr = isFinite(headway) ? SB.MODES[line.mode].cap * (60 / headway) : 0;
      const peakPerDir = (maxLoad * TUNE.peakFactor) / 2;
      const ratio = capHr > 0 ? peakPerDir / capHr : 0;
      lineMaxRatio.set(line.id, ratio);
      const target = Math.min(TUNE.delayMax, 1 + TUNE.delayGain * Math.max(0, ratio - 1));
      const prev = lineDelay.get(line.id) || 1;
      lineDelay.set(line.id, prev * 0.6 + target * 0.4);
      if (ratio > 1.05) crowded.push(line.id);
    }

    // Coverage: residents within walking range of any stop.
    let covered = 0, popTotal = 0;
    for (const c of g.city.cells) {
      if (c.pop <= 0) continue;
      popTotal += c.pop;
      const a = cellAccess('c' + (c.gy * g.city.cols + c.gx), c.x, c.y);
      if (a.length) covered += c.pop;
    }

    sim.results = {
      ridersDaily: riders,
      share: total > 0 ? riders / total : 0,
      carShare: total > 0 ? carPeople / total : 0,
      totalCommuters: total,
      avgTransitMin: riders > 1 ? tMinSum / riders : 0,
      avgCarMin: carPeople > 1 ? cMinSum / carPeople : 0,
      transfersDaily: transfers,
      modeRiders,
      segLoads, lineRiders, lineMaxRatio, boardings, crowded,
      coverage: popTotal > 0 ? covered / popTotal : 0,
    };
    SB.game.networkDirty = false;
    rebuildVehiclePaths();
    return sim.results;
  };

  sim.ensure = function () {
    if (SB.game.networkDirty || !sim.results) sim.assign();
  };

  sim.lineDelayFor = function (lineId) { return lineDelay.get(lineId) || 1; };

  // ── Vehicles (cosmetic layer, follows the real route geometry) ───────
  const vehState = new Map(); // lineId → {pts, cum, stops, total, list}
  let vehRev = '';

  function rebuildVehiclePaths() {
    const st = SB.game.state;
    const rev = st.lines.map((l) => l.id + ':' + l.vehicles + ':' + l.stationIds.join(',')).join('|');
    if (rev === vehRev) return;
    vehRev = rev;
    const seen = new Set();
    for (const line of st.lines) {
      seen.add(line.id);
      // Concatenate segment paths into one polyline with cumulative lengths.
      const pts = [];
      const stops = [0];
      const segs = SB.game.pathsM(line);
      for (let i = 0; i < segs.length; i++) {
        const seg = segs[i];
        for (let k = i === 0 ? 0 : 1; k < seg.length; k++) pts.push(seg[k]);
        stops.push(-1); // fill below
      }
      const cum = [0];
      for (let i = 1; i < pts.length; i++) {
        cum.push(cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
      }
      // Stop offsets: cumulative length at each segment boundary.
      let acc = 0, si = 1;
      for (let i = 0; i < segs.length; i++) {
        let segLen = 0;
        for (let k = 0; k < segs[i].length - 1; k++) {
          segLen += Math.hypot(segs[i][k + 1][0] - segs[i][k][0], segs[i][k + 1][1] - segs[i][k][1]);
        }
        acc += segLen;
        stops[si++] = acc;
      }
      const total = acc;
      const isLoop = SB.isLoopLine(line);
      const prev = vehState.get(line.id);
      const list = [];
      for (let i = 0; i < line.vehicles; i++) {
        if (prev && prev.list[i] && prev.total > 0) {
          const t = prev.list[i];
          const pos = Math.min(total, (t.pos / prev.total) * total);
          list.push({ pos, dir: t.dir, dwell: 0, stopIdx: nearestStop(stops, pos) });
        } else if (isLoop) {
          // Spread evenly around the circuit — loop vehicles always run forward.
          const frac = line.vehicles > 0 ? i / line.vehicles : 0;
          const pos = frac * total;
          list.push({ pos, dir: 1, dwell: 0, stopIdx: nearestStop(stops, pos) });
        } else {
          const frac = line.vehicles > 0 ? i / line.vehicles : 0;
          const bounce = frac * 2;
          const dir = bounce < 1 ? 1 : -1;
          const pos = (bounce < 1 ? bounce : 2 - bounce) * total;
          list.push({ pos, dir, dwell: 0, stopIdx: nearestStop(stops, pos) });
        }
      }
      vehState.set(line.id, { pts, cum, stops, total, list });
    }
    for (const id of [...vehState.keys()]) if (!seen.has(id)) vehState.delete(id);
  }

  function nearestStop(stops, pos) {
    let best = 0;
    for (let i = 1; i < stops.length; i++) {
      if (Math.abs(stops[i] - pos) < Math.abs(stops[best] - pos)) best = i;
    }
    return best;
  }

  sim.updateTrains = function (dt, speedMult) {
    rebuildVehiclePaths();
    if (speedMult <= 0) return;
    for (const line of SB.game.state.lines) {
      const ts = vehState.get(line.id);
      if (!ts || ts.total <= 0) continue;
      // Lines outside their service window park their fleet.
      if (SB.world && SB.world.lineActive && !SB.world.lineActive(line)) continue;
      const isLoop = SB.isLoopLine(line);
      const slow = SB.world && SB.world.delayFor ? SB.world.delayFor(line) : 1;
      const v = ((SB.MODES[line.mode].speedKmh / 3.6) / slow) * 1.7 * Math.max(1, speedMult);
      for (const t of ts.list) {
        if (t.dwell > 0) { t.dwell -= dt * speedMult; continue; }
        // The closing stop is the same physical station as stop 0 — wrap
        // back to the start and keep running forward instead of bouncing.
        if (isLoop && t.stopIdx === ts.stops.length - 1) { t.stopIdx = 0; t.pos = 0; }
        let target = t.stopIdx + t.dir;
        if (isLoop) {
          if (target >= ts.stops.length) continue;
        } else {
          if (target < 0 || target >= ts.stops.length) { t.dir *= -1; target = t.stopIdx + t.dir; }
          if (target < 0 || target >= ts.stops.length) continue;
        }
        const goal = ts.stops[target];
        const step = v * dt;
        if (Math.abs(goal - t.pos) <= step) {
          t.pos = goal;
          t.stopIdx = target;
          t.dwell = TUNE.dwellVisS / Math.max(1, speedMult);
        } else {
          t.pos += Math.sign(goal - t.pos) * step;
        }
      }
    }
  };

  // ── Train geometry for rendering ─────────────────────────────────────
  // Each vehicle is drawn as a short slice of the actual route polyline
  // (so it bends with the track), centered on its current position.
  const TRAIN_LEN_M = { metro: 95, train: 145, hst: 185, tram: 55, bus: 30 };

  // Interpolated point at a given distance along the path, plus the index
  // of the first vertex strictly after it.
  function pointAt(ts, pos) {
    let lo = 0, hi = ts.cum.length - 1;
    while (lo < hi - 1) {
      const mid = (lo + hi) >> 1;
      if (ts.cum[mid] <= pos) lo = mid; else hi = mid;
    }
    const a = ts.pts[lo], b = ts.pts[hi];
    const span = ts.cum[hi] - ts.cum[lo] || 1;
    const f = Math.min(1, Math.max(0, (pos - ts.cum[lo]) / span));
    return { x: a[0] + (b[0] - a[0]) * f, y: a[1] + (b[1] - a[1]) * f, hi };
  }

  function slicePath(ts, p0, p1) {
    const s = pointAt(ts, p0), e = pointAt(ts, p1);
    const pts = [[s.x, s.y]];
    for (let i = s.hi; i < e.hi; i++) pts.push(ts.pts[i]);
    pts.push([e.x, e.y]);
    return pts;
  }

  // Returns [{pts: [[x, y], …], line}] in meter coords, on the real geometry.
  sim.trainSegments = function () {
    const out = [];
    for (const line of SB.game.state.lines) {
      const ts = vehState.get(line.id);
      if (!ts || ts.total <= 0 || ts.pts.length < 2) continue;
      if (SB.world && SB.world.lineActive && !SB.world.lineActive(line)) continue;
      const half = Math.min(ts.total / 2, (TRAIN_LEN_M[line.mode] || 80) / 2);
      for (const t of ts.list) {
        const p0 = Math.max(0, t.pos - half);
        const p1 = Math.min(ts.total, t.pos + half);
        if (p1 - p0 < 1) continue;
        out.push({ pts: slicePath(ts, p0, p1), line });
      }
    }
    return out;
  };
})();
