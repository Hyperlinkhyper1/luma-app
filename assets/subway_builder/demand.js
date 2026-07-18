/* Subway Builder — demand model built from real OpenStreetMap data.

   After the map has loaded vector tiles covering the play area, we read the
   landuse, water and place layers and rasterize them onto a 300 m grid:
   residential polygons breed residents, commercial/industrial/retail breed
   jobs, and a downtown kernel around the chosen point fills the gaps where
   OSM landuse is sparse. Population totals are estimates — this is a
   simulator reading the real city's shape, not a census. */
(function () {
  'use strict';
  const SB = (window.SB = window.SB || {});
  const geo = SB.geo;

  const CELL = 300;        // meters
  const RADIUS = 7000;     // play-area radius around the chosen point

  const POP_CLASSES = new Set(['residential', 'suburb', 'neighbourhood']);
  const JOB_CLASSES = new Set(['commercial', 'industrial', 'retail']);
  const DEAD_CLASSES = new Set(['cemetery', 'military', 'quarry', 'landfill', 'airport', 'aerodrome']);

  function hash01(x, y, seed) {
    let h = seed ^ Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263);
    h = Math.imul(h ^ (h >>> 13), 1274126177);
    return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
  }

  // Convert a (Multi)Polygon feature's rings to meter coords with bboxes.
  function polysOf(feature) {
    const g = feature.geometry;
    const polys = [];
    const coordsList = g.type === 'Polygon' ? [g.coordinates] : g.type === 'MultiPolygon' ? g.coordinates : [];
    for (const rings of coordsList) {
      const mRings = rings.map((ring) => ring.map(([lng, lat]) => geo.toM(lng, lat)));
      if (!mRings.length || mRings[0].length < 3) continue;
      polys.push({ rings: mRings, bbox: geo.ringBBox(mRings[0]) });
    }
    return polys;
  }

  function inAny(polys, x, y) {
    for (const p of polys) {
      const b = p.bbox;
      if (x < b[0] || x > b[2] || y < b[1] || y > b[3]) continue;
      if (geo.pointInPoly(x, y, p.rings)) return true;
    }
    return false;
  }

  const demand = (SB.demand = { CELL, RADIUS });

  /* Build the city object from features the map has loaded.
     `collected` = {landuse: [features], water: [...], places: [...]} */
  demand.build = function (collected, place) {
    const seed = (Math.round(place.lat * 1e4) * 31 + Math.round(place.lng * 1e4)) | 0;

    const resPolys = [], jobPolys = [], deadPolys = [], waterPolys = [];
    for (const f of collected.landuse) {
      const cls = f.properties && (f.properties.class || f.properties.subclass);
      if (POP_CLASSES.has(cls)) resPolys.push(...polysOf(f));
      else if (JOB_CLASSES.has(cls)) jobPolys.push(...polysOf(f));
      else if (DEAD_CLASSES.has(cls)) deadPolys.push(...polysOf(f));
    }
    for (const f of collected.water) waterPolys.push(...polysOf(f));

    // Named neighbourhoods for station naming and the map's feel of place.
    const places = [];
    const seenNames = new Set();
    for (const f of collected.places) {
      const p = f.properties || {};
      const cls = p.class;
      if (!p.name || seenNames.has(p.name)) continue;
      if (!['suburb', 'neighbourhood', 'quarter', 'borough', 'town', 'village', 'city'].includes(cls)) continue;
      const c = f.geometry && f.geometry.type === 'Point' ? f.geometry.coordinates : null;
      if (!c) continue;
      const [x, y] = geo.toM(c[0], c[1]);
      if (Math.hypot(x, y) > RADIUS * 1.3) continue;
      seenNames.add(p.name);
      places.push({ name: p.name, x, y, cls });
    }

    function isWater(x, y) { return inAny(waterPolys, x, y); }

    // ── Rasterize onto the grid ─────────────────────────────────────────
    const cols = Math.ceil((RADIUS * 2) / CELL);
    const rows = cols;
    const cells = [];
    const cellAt = new Int32Array(cols * rows).fill(-1);
    const hasLanduse = resPolys.length + jobPolys.length > 3;

    let popSum = 0, jobsSum = 0;
    for (let gy = 0; gy < rows; gy++) {
      for (let gx = 0; gx < cols; gx++) {
        const x = -RADIUS + gx * CELL + CELL / 2;
        const y = -RADIUS + gy * CELL + CELL / 2;
        const d = Math.hypot(x, y);
        if (d > RADIUS) continue;
        const water = isWater(x, y) ? (isWater(x - 100, y - 100) || isWater(x + 100, y + 100)) : false;
        const dead = !water && inAny(deadPolys, x, y);

        let pop = 0, jobs = 0;
        if (!water && !dead) {
          const jobsK = Math.exp(-(d * d) / (2 * 1900 * 1900));
          const popK = Math.exp(-(d * d) / (2 * 4600 * 4600));
          const n = 0.55 + 0.9 * hash01(gx, gy, seed);
          if (hasLanduse) {
            const inRes = inAny(resPolys, x, y);
            const inJob = inAny(jobPolys, x, y);
            pop = popK * n * (inRes ? 3.2 : 0.35);
            jobs = jobsK * n * (inJob ? 4.2 : 0.55) + (inJob ? 0.35 : 0);
            if (inRes) jobs += 0.12 * n; // corner shops, schools…
          } else {
            // Rural/unmapped fallback: kernel city so the sim still runs.
            pop = popK * n;
            jobs = jobsK * n * 1.4;
          }
        }
        const idx = cells.length;
        cells.push({ gx, gy, x, y, water, pop, jobs });
        cellAt[gy * cols + gx] = idx;
        popSum += pop; jobsSum += jobs;
      }
    }

    // Population estimate: scale by how much of the disc is actually urban.
    const urbanCells = cells.filter((c) => c.pop > 0.15).length;
    const estPop = Math.max(90000, Math.round(urbanCells * 620));
    const commuters = estPop * 0.42;
    for (const c of cells) {
      c.pop = popSum > 0 ? (c.pop / popSum) * estPop : 0;
      c.jobs = jobsSum > 0 ? (c.jobs / jobsSum) * commuters : 0;
    }
    const maxPop = Math.max(1, ...cells.map((c) => c.pop));
    const maxJobs = Math.max(1, ...cells.map((c) => c.jobs));

    const city = {
      cols, rows, CELL, RADIUS, cells, cellAt, places, waterPolys,
      commuters, maxPop, maxJobs,
      def: {
        id: place.id, name: place.name, seed,
        pop: estPop,
        budget: 1.4e9, funding: 250e3, capital: 450e6,
      },
      isWater,
      inBounds(x, y) { return Math.hypot(x, y) <= RADIUS; },
      cellIndexAt(x, y) {
        const gx = Math.floor((x + RADIUS) / CELL), gy = Math.floor((y + RADIUS) / CELL);
        if (gx < 0 || gy < 0 || gx >= cols || gy >= rows) return -1;
        return cellAt[gy * cols + gx];
      },
      districtNameAt(x, y) {
        let best = null, bd = Infinity;
        for (const p of places) {
          const dd = Math.hypot(p.x - x, p.y - y);
          if (dd < bd) { bd = dd; best = p; }
        }
        return best && bd < 4500 ? best.name : null;
      },
    };
    return city;
  };

  // Station names: nearest OSM neighbourhood + a flavor, unique per game.
  const FLAVORS = ['', ' Central', ' Square', ' Park', ' Street', ' Junction', ' Cross', ' Gate', ' Market', ' Fields'];
  SB.stationName = function (city, x, y, taken) {
    const district = city.districtNameAt(x, y) || city.def.name || 'Midtown';
    const base = Math.abs(Math.floor(x * 7 + y * 13));
    for (let i = 0; i < FLAVORS.length; i++) {
      const name = district + FLAVORS[(base + i * 3) % FLAVORS.length];
      if (!taken.has(name)) return name;
    }
    let n = 2;
    while (taken.has(district + ' ' + n)) n++;
    return district + ' ' + n;
  };
})();
