/* The landside: the public face of the airport. Everything out here is
   scenery — the access road, the bus station, the tram line, the railway and
   the hotels around them — rebuilt whenever the terminal changes and animated
   in real time. The Dart simulation knows nothing about it; the traffic only
   reads how busy the airport is, so the road fills up as passengers do. */
window.AirportLandside = (() => {
  'use strict';
  const T = THREE, M = AirportModels;
  const {box, cylinder, sphere, decal, light, pool, label, tree, instance, bake, dispose} = M;
  const rng = seed => () => (seed = (seed * 16807) % 2147483647) / 2147483647;

  // Everything is laid out in metres out from the terminal's landside wall
  // (u, local +X) and along it (v, local +Z). The group's transform carries
  // that frame to whichever side of the terminal faces away from the apron.
  const ROAD = {start: 30, end: 560, half: 14, lane: 9, median: 5};
  const TRAM = {at: 61, apart: 8, gauge: .72};
  const RAIL = {at: 110, apart: 9, top: 10.15};
  const RING = {at: 606, radius: 28};
  const EDGE = 230, SPAN = 2 * EDGE + 34;
  const C = {
    road: 0xd2d5d0, pave: 0xe3e2d9, paint: 0xf2f0e6, kerb: 0xcfccc1,
    lawn: 0x93b47e, roof: 0xb9c1c3, steel: 0xa9b1b2, glass: 0x3f7fa0,
    teal: 0x2d6b76,
  };

  // ── The frame ─────────────────────────────────────────────────────────
  const extent = list => list.reduce((b, f) => ({
    minX: Math.min(b.minX, f.x), maxX: Math.max(b.maxX, f.x + f.width),
    minZ: Math.min(b.minZ, f.y), maxZ: Math.max(b.maxZ, f.y + f.depth),
  }), {minX: Infinity, maxX: -Infinity, minZ: Infinity, maxZ: -Infinity});

  /** Terminal face, pointing away from the runways and stands. */
  function layout(list) {
    const terminals = list.filter(f => AirportSceneLogic.hallKinds.has(f.kind));
    if (!terminals.length) return null;
    const t = extent(terminals);
    const airside = list.filter(f => /^(runway|taxiway|stand)/.test(f.kind));
    let dir = [1, 0];
    if (airside.length) {
      const a = extent(airside);
      const dx = (t.minX + t.maxX - a.minX - a.maxX) / 2, dz = (t.minZ + t.maxZ - a.minZ - a.maxZ) / 2;
      dir = Math.abs(dx) >= Math.abs(dz) ? [Math.sign(dx) || 1, 0] : [0, Math.sign(dz) || 1];
    }
    const alongX = dir[0] !== 0;
    const reach = (alongX ? t.maxX - t.minX : t.maxZ - t.minZ) / 2;
    const span = alongX ? t.maxZ - t.minZ : t.maxX - t.minX;
    const H = Math.min(150, Math.max(45, span / 2));
    const origin = {x: (t.minX + t.maxX) / 2 + dir[0] * reach, z: (t.minZ + t.maxZ) / 2 + dir[1] * reach};
    const angle = Math.atan2(-dir[1], dir[0]), c = Math.cos(angle), s = Math.sin(angle), K = H + 30;
    // The canopy names the arrival and departure halls that open on to it.
    const signs = [];
    for (const f of terminals) {
      const text = {terminalLandside: 'ARRIVAL HALL', terminalReclaim: 'DEPARTURE HALL'}[f.kind];
      if (!text) continue;
      const corners = [[f.x, f.y], [f.x + f.width, f.y], [f.x, f.y + f.depth], [f.x + f.width, f.y + f.depth]]
        .map(([x, z]) => [(x - origin.x) * c - (z - origin.z) * s, (x - origin.x) * s + (z - origin.z) * c]);
      if (Math.max(...corners.map(p => p[0])) < -1) continue;
      const v = corners.reduce((n, p) => n + p[1], 0) / 4;
      signs.push({text, v: Math.round(Math.min(K - 8, Math.max(-K + 8, v)) * 10) / 10});
    }
    return {origin, angle, dir, H, K, signs};
  }

  // ── Paths ─────────────────────────────────────────────────────────────
  /** Replaces every corner with a short quadratic so vehicles do not snap. */
  function rounded(points, radius, closed) {
    const out = [], n = points.length;
    for (let i = 0; i < n; i++) {
      const cur = points[i];
      if (!closed && (i === 0 || i === n - 1)) { out.push(cur); continue; }
      const prev = points[(i - 1 + n) % n], next = points[(i + 1) % n];
      const iu = cur[0] - prev[0], iv = cur[1] - prev[1], il = Math.hypot(iu, iv) || 1;
      const ou = next[0] - cur[0], ov = next[1] - cur[1], ol = Math.hypot(ou, ov) || 1;
      const r = Math.min(radius, il / 2.02, ol / 2.02);
      const a = [cur[0] - iu / il * r, cur[1] - iv / il * r];
      const b = [cur[0] + ou / ol * r, cur[1] + ov / ol * r];
      out.push(a);
      for (let k = 1; k < 4; k++) {
        const s = k / 4, m = 1 - s;
        out.push([m * m * a[0] + 2 * m * s * cur[0] + s * s * b[0], m * m * a[1] + 2 * m * s * cur[1] + s * s * b[1]]);
      }
      out.push(b);
    }
    return out;
  }
  function route(points, {closed = true, radius = 14} = {}) {
    const p = rounded(points, radius, closed), segs = [];
    let length = 0;
    for (let i = 0, n = closed ? p.length : p.length - 1; i < n; i++) {
      const a = p[i], b = p[(i + 1) % p.length];
      const du = b[0] - a[0], dv = b[1] - a[1], len = Math.hypot(du, dv) || 1e-6;
      segs.push({a, du: du / len, dv: dv / len, len, at: length});
      length += len;
    }
    return {segs, length};
  }
  /** Point [off] metres to the right of the centreline, [s] along it. */
  function at(r, s, off = 0) {
    let d = ((s % r.length) + r.length) % r.length, i = 0;
    while (i < r.segs.length - 1 && d > r.segs[i].at + r.segs[i].len) i++;
    const g = r.segs[i], t = d - g.at;
    return {u: g.a[0] + g.du * t - g.dv * off, v: g.a[1] + g.dv * t + g.du * off, du: g.du, dv: g.dv};
  }
  /** Arc length of the point on [r] closest to (u, v) — used to place stops. */
  function arcOf(r, u, v) {
    let best = 0, near = Infinity;
    for (const g of r.segs) {
      const t = Math.max(0, Math.min(g.len, (u - g.a[0]) * g.du + (v - g.a[1]) * g.dv));
      const du = g.a[0] + g.du * t - u, dv = g.a[1] + g.dv * t - v, d = du * du + dv * dv;
      if (d < near) { near = d; best = g.at + t; }
    }
    return best;
  }
  const ahead = (r, from, to) => ((to - from) % r.length + r.length) % r.length;
  const arc = (cu, cv, radius, from, to, steps) => Array.from({length: steps + 1}, (_, i) => {
    const a = from + (to - from) * i / steps;
    return [cu + Math.cos(a) * radius, cv + Math.sin(a) * radius];
  });

  // ── Static scenery ────────────────────────────────────────────────────
  function streetLamp(g, u, v, {height = 11, reach = 0, axis = 'v', twin = false, glow = false} = {}) {
    cylinder(g, .2, height, u, height / 2, v, 0x8e9aa0, 'metal', .15);
    for (const s of twin ? [-1, 1] : [1]) {
      const du = axis === 'u' ? reach * s : 0, dv = axis === 'v' ? reach * s : 0;
      if (reach) box(g, Math.abs(du) + .4, .2, Math.abs(dv) + .4, u + du / 2, height, v + dv / 2, 0x8e9aa0, 'metal');
      box(g, 1.6, .26, .6, u + du, height - .22, v + dv, 0x59656b, 'metal');
      light(g, u + du, height - .46, v + dv, 0xfff1cf, .6);
      // Pools are additive planes that only show at night; the busy roads get
      // them, the car parks and side streets do not.
      if (glow) pool(g, u + du, v + dv, height * .8, 0xffe9b8);
    }
  }
  // Round crowns cost ~900 triangles each; out here most trees are conifers,
  // which are two cylinders, and only every fourth one gets the leafy shape.
  const grove = (g, u, v, size, i) => tree(g, u, v, size, i % 4 === 1 ? 1 : 0);
  const carPaint = [0xf4f4f1, 0x2b3f55, 0x9aa3a8, 0x22282c, 0xa8423c, 0x3d6b4f, 0xd9d4c5, 0x4a5a6b, 0xc0862f, 0x6d5b7a];
  function parked(g, u, v, color, y = 0) {
    box(g, 1.85, .72, 4.3, u, y + .52, v, color);
    box(g, 1.68, .58, 2.3, u, y + 1.16, v + .25, color);
    box(g, 1.72, .4, 2.1, u, y + 1.24, v + .25, 0x2b3237, 'glass');
  }
  function carPark(g, u0, v0, u1, v1, seed) {
    const r = rng(seed);
    box(g, u1 - u0, .1, v1 - v0, (u0 + u1) / 2, .05, (v0 + v1) / 2, 0xc9ccc6, 'asphalt');
    for (let v = v0 + 11; v < v1 - 9; v += 16) {
      for (let u = u0 + 4; u < u1 - 6; u += 2.7) {
        decal(g, .16, 5, u, v - 2.7, C.paint);
        decal(g, .16, 5, u, v + 2.7, C.paint);
        if (r() < .74) parked(g, u + 1.35, v - 2.7, carPaint[Math.floor(r() * carPaint.length)]);
        if (r() < .74) parked(g, u + 1.35, v + 2.7, carPaint[Math.floor(r() * carPaint.length)]);
      }
      decal(g, u1 - u0 - 6, .3, (u0 + u1) / 2, v, C.paint);
    }
    for (let v = v0 + 20; v < v1 - 12; v += 34) { streetLamp(g, u0 + 5, v, {height: 9}); streetLamp(g, u1 - 5, v, {height: 9}); }
    for (let u = u0 + 10; u < u1; u += 38) { grove(g, u, v0 - 6, .8, u); grove(g, u + 12, v1 + 6, .85, u + 1); }
  }
  function garage(g, u, v, w, d, decks, seed) {
    const r = rng(seed);
    box(g, w + 10, .16, d + 10, u, .08, v, 0xc9ccc6, 'asphalt');
    for (let i = 0; i < decks; i++) {
      const y = i * 3.4;
      box(g, w, .55, d, u, y + .28, v, 0xd3d0c6, 'concrete');
      box(g, w + .6, .95, d + .6, u, y + 2.55, v, 0xc4c1b6, 'concrete');
      for (let t = -w / 2 + 4; t < w / 2 - 2; t += 3.4) for (const s of [-1, 1]) box(g, 2.6, .12, .4, u + t, y + 1.5, v + s * d / 2, 0xb9b6ab, 'metal');
      if (i < decks - 1) for (let t = -w / 2 + 6; t < w / 2 - 5; t += 4) {
        if (r() < .6) parked(g, u + t, v - d / 4, carPaint[Math.floor(r() * carPaint.length)], y + .55);
        if (r() < .6) parked(g, u + t, v + d / 4, carPaint[Math.floor(r() * carPaint.length)], y + .55);
      }
    }
    const core = decks * 3.4 + 3.4;
    box(g, 10, core, 10, u - w / 2 + 6, core / 2, v - d / 2 + 6, 0xdcd8cd);
    box(g, 10.3, core - 5, 3, u - w / 2 + 6, core / 2, v - d / 2 + 1.4, 0x8fc6de, 'glass');
    label(g, 'P', u - w / 2 + 6, core - 3.4, v - d / 2 + .8, 4.4, '#f6fbf9', {rotY: Math.PI, width: 1.2});
  }
  function tower(g, u, v, w, d, floors, {wall = 0xe7e3d8, band = C.glass, podium = 4.6, sign = null, face = Math.PI} = {}) {
    const h = floors * 3.5;
    box(g, w + 16, .18, d + 16, u, .09, v, 0xd6d6ce, 'concrete');
    if (podium) {
      box(g, w + 10, podium, d + 9, u, podium / 2, v, 0xdcd8cd);
      box(g, w + 10.4, 2.6, d + 9.4, u, podium / 2 + .4, v, band, 'glass');
      box(g, w + 11.6, .5, d + 10.6, u, podium + .25, v, C.roof, 'metal');
    }
    box(g, w, h, d, u, podium + h / 2, v, wall);
    for (let f = 0; f < floors; f++) {
      const y = podium + f * 3.5 + 2;
      box(g, w + .2, 2, d - 3.4, u, y, v, band, 'glass');
      box(g, w - 3.4, 2, d + .2, u, y, v, band, 'glass');
    }
    box(g, w + 1.6, .7, d + 1.6, u, podium + h + .35, v, 0xc8c4b8);
    box(g, w * .38, 3.2, d * .38, u, podium + h + 2.3, v, C.steel, 'metal');
    light(g, u, podium + h + 4.2, v, 0xff4a3a, .5);
    if (sign) {
      const z = v + (face ? -d / 2 - .3 : d / 2 + .3);
      label(g, sign, u, podium + h - 2.6, z, 2.1, '#f6fbf9', {rotY: face, width: Math.max(4, sign.length * .56)});
    }
  }

  function forecourt(g, L) {
    const K = L.K;
    box(g, 30, .12, 2 * K + 56, 15, .06, 0, C.pave, 'concrete');
    box(g, 26, .12, 56, 13, .06, -(K + 54), C.pave, 'concrete');
    box(g, 9.6, .5, 2 * K, 4.8, 8.3, 0, C.roof, 'metal');
    box(g, .7, 1.7, 2 * K, 9.8, 9, 0, C.teal);
    for (let v = -K + 7; v <= K - 6; v += 13) {
      cylinder(g, .34, 8.3, 8.8, 4.15, v, 0xb5bdbf, 'metal');
      light(g, 8.8, 7.5, v, 0xfff0c8, .5);
    }
    const signs = L.signs?.length ? L.signs : [{text: 'DEPARTURES', v: -K * .5}, {text: 'ARRIVALS', v: K * .5}];
    for (const s of signs) label(g, s.text, 10.25, 9, s.v, 1.7, '#eef6f4', {rotY: Math.PI / 2, width: 7});
    // Kerbside road: buses stop at the canopy, cars use the outer lane. It
    // sits just above the forecourt paving, runs on into the bus station and
    // meets the main road through a paved junction.
    box(g, 13, .14, 2 * K + 106, 15.5, .07, -27, C.road, 'asphalt');
    box(g, 12, .14, 2 * ROAD.half, 27, .07, 0, C.road, 'asphalt');
    box(g, .6, .35, 2 * K, 9.4, .22, 0, C.kerb, 'concrete');
    for (let v = -K - 70; v < K + 20; v += 8) decal(g, .18, 4.4, 14, v, C.paint);
    decal(g, .16, 2 * K + 96, 21.7, -26, 0xe0b23a);
    for (const c of [-K * .55, K * .55]) for (let d = -2.4; d <= 2.41; d += 1.2) decal(g, 15, .55, 14, c + d, C.paint);
    for (let v = -K + 4; v < K; v += 6) box(g, .3, .95, .3, 9.4, .47, v, 0xbcc3c4, 'metal');
    for (let v = -K + 10; v < K; v += 26) streetLamp(g, 22.8, v, {height: 10, reach: 5, axis: 'u', glow: true});
  }
  function mainRoad(g) {
    const len = ROAD.end - ROAD.start, mid = (ROAD.start + ROAD.end) / 2;
    box(g, len, .1, 2 * ROAD.half, mid, .05, 0, C.road, 'asphalt');
    box(g, len, .18, 2 * ROAD.median, mid, .09, 0, C.lawn, 'grass');
    for (const v of [-ROAD.half + .6, ROAD.half - .6]) decal(g, len, .3, mid, v, C.paint);
    for (const v of [-ROAD.median - .4, ROAD.median + .4]) decal(g, len, .25, mid, v, C.paint);
    for (let u = ROAD.start + 6; u < ROAD.end; u += 12) for (const v of [-ROAD.lane, ROAD.lane]) decal(g, 6, .2, u, v, C.paint);
    for (let u = ROAD.start + 26; u < ROAD.end; u += 46) streetLamp(g, u, 0, {height: 12, reach: 8, twin: true, glow: true});
    for (let u = ROAD.start + 49; u < ROAD.end - 20; u += 46) { grove(g, u, -2.6, .85, u); grove(g, u + 7, 2.6, .9, u + 1); }
    // Tram level crossing.
    for (const u of [TRAM.at - 9, TRAM.at + 9]) for (let v = -ROAD.half + 1.2; v < ROAD.half; v += 1.7) decal(g, 1.1, .8, u, v, C.paint);
    for (const [u, v] of [[TRAM.at - 11, -ROAD.half + 1], [TRAM.at + 11, ROAD.half - 1]]) {
      cylinder(g, .16, 3.4, u, 1.7, v, 0xd8d4c8, 'metal');
      box(g, .5, .5, 1.6, u, 3.5, v, 0x2c3237);
      light(g, u, 3.5, v + .6, 0xff4a3a, .35);
      light(g, u, 3.5, v - .6, 0xff4a3a, .35);
    }
    // Sign gantry over each carriageway.
    for (const s of [-1, 1]) {
      cylinder(g, .26, 8.4, 196, 4.2, s * (ROAD.half + 1.4), C.steel, 'metal');
      box(g, .5, .4, ROAD.half + 1.4, 196, 8.2, s * (ROAD.half + 1.4) / 2, C.steel, 'metal');
      box(g, .35, 3.4, 11, 196, 6.3, s * 8.5, 0x2f6b4a);
      label(g, s < 0 ? 'TERMINAL' : 'P  HOTELS', 195.7, 6.6, s * 8.5, 1.5, '#f4f8f5', {rotY: -Math.PI / 2, width: 5});
    }
    // Roundabout at the far end closes the loop.
    cylinder(g, 46, .1, RING.at, .05, 0, C.road, 'asphalt');
    cylinder(g, 21, .45, RING.at, .22, 0, C.kerb, 'concrete');
    cylinder(g, 19.6, .55, RING.at, .3, 0, C.lawn, 'grass');
    for (let a = 0; a < 6; a++) { const t = a / 6 * Math.PI * 2; grove(g, RING.at + Math.cos(t) * 14, Math.sin(t) * 14, .9, a); }
    cylinder(g, 1.3, 16, RING.at, 8, 0, 0xdedace, 'concrete', .85);
    box(g, 1.1, 9, .5, RING.at, 19, 0, C.teal);
    sphere(g, RING.at, 16.4, 0, 1.5, 1.5, 1.5, 0xf2c230);
    for (let a = 0; a < 6; a++) { const t = a / 6 * Math.PI * 2; streetLamp(g, RING.at + Math.cos(t) * 40, Math.sin(t) * 40, {height: 12, glow: true}); }
  }
  function busStation(g, L) {
    const v0 = -(L.K + 76), v1 = -(L.K + 32), mid = (v0 + v1) / 2, len = v1 - v0;
    box(g, 26, .1, 22, 13, .05, v0 - 13, C.road, 'asphalt');
    box(g, 8, .35, len, 6, .18, mid, C.pave, 'concrete');
    box(g, 10.4, .45, len + 5, 6, 5.7, mid, C.roof, 'metal');
    for (let v = v0 + 4; v < v1; v += 8) {
      cylinder(g, .26, 5.5, 6, 2.75, v, 0xb5bdbf, 'metal');
      light(g, 6, 5.2, v, 0xfff0c8, .45);
    }
    box(g, .5, 1.4, len + 5, 11, 6.5, mid, C.teal);
    label(g, 'BUS STATION', 11.3, 6.5, mid, 1.4, '#eef6f4', {rotY: Math.PI / 2, width: 6});
    for (let v = v0 + 6; v < v1; v += 11) {
      decal(g, 3.4, .3, 12.4, v, 0xe0b23a, .12);
      box(g, 1.5, .5, 3.2, 4.2, .68, v, 0x4c5a60);
      box(g, 1.5, .12, 3.2, 7.4, .95, v, 0x4c5a60);
    }
    box(g, 4.2, 2.6, 5, 6, 1.3, v1 - 3, 0xdcd8cd);
    box(g, 4.4, 1.5, 5.2, 6, 1.6, v1 - 3, 0x8fc6de, 'glass');
  }
  function tramLine(g) {
    const tracks = [TRAM.at - TRAM.apart / 2, TRAM.at + TRAM.apart / 2];
    box(g, 15, .08, SPAN, TRAM.at, .04, 0, 0x9d9c92, 'concrete');
    for (const u of tracks) {
      for (const o of [-TRAM.gauge, TRAM.gauge]) box(g, .16, .22, SPAN, u + o, .19, 0, 0x8d9490, 'metal');
      box(g, .1, .1, SPAN, u, 6.4, 0, 0x4a4f52, 'metal');
      for (let v = -EDGE + 6; v < EDGE; v += 5) box(g, 2.5, .14, .5, u, .1, v, 0x6f665c);
    }
    for (let v = -EDGE + 18; v < EDGE; v += 32) {
      if (Math.abs(v) < 64) continue;
      cylinder(g, .2, 7, TRAM.at, 3.5, v, 0x77807e, 'metal', .15);
      box(g, TRAM.apart + 2, .16, .16, TRAM.at, 6.9, v, 0x77807e, 'metal');
    }
    for (const s of [-1, 1]) {
      const c = s * 37;
      box(g, 5.4, .35, 38, TRAM.at, .18, c, C.pave, 'concrete');
      for (const o of [-2.3, 2.3]) decal(g, .5, 38, TRAM.at + o, c, 0xe0b23a, .37);
      box(g, 4.4, .3, 16, TRAM.at, 3.6, c + s * 3, C.teal);
      for (const d of [-7, 7]) for (const u of [TRAM.at - 1.8, TRAM.at + 1.8]) cylinder(g, .12, 3.5, u, 1.75, c + s * 3 + d, C.steel, 'metal');
      box(g, 4.2, 1.2, .14, TRAM.at, 1.6, c + s * 10.2, 0x9ec9e0, 'glass');
      for (let v = c - 14; v < c + 15; v += 9) box(g, 1.3, .45, 2.4, TRAM.at, .68, v, 0x4c5a60);
      light(g, TRAM.at, 3.4, c + s * 3, 0xfff0c8, .4);
    }
    label(g, 'TRAM', TRAM.at, 4.5, 56.6, 1.5, '#eef6f4', {rotY: 0, width: 3});
  }
  function railway(g) {
    const tracks = [RAIL.at - RAIL.apart / 2, RAIL.at + RAIL.apart / 2];
    box(g, 15, 1.5, SPAN, RAIL.at, 9.4, 0, 0xcfd2cc, 'concrete');
    for (let v = -EDGE + 12; v < EDGE; v += 26) {
      if (Math.abs(v) < 52) continue;
      cylinder(g, 1.5, 8.6, RAIL.at, 4.3, v, 0xc6c9c3, 'concrete', 1.9);
      box(g, 13, .7, 3.2, RAIL.at, 8.95, v, 0xc6c9c3, 'concrete');
    }
    for (const u of [RAIL.at - 7.7, RAIL.at + 7.7]) box(g, .5, 1.2, SPAN, u, 10.7, 0, 0xd7dad4, 'concrete');
    // Station: a wider deck on columns, two side platforms, a hall underneath.
    box(g, 28, 1.5, 96, RAIL.at, 9.4, 0, 0xcfd2cc, 'concrete');
    for (const u of [RAIL.at - 12, RAIL.at + 12]) for (let v = -44; v <= 44; v += 22) cylinder(g, 1.3, 8.6, u, 4.3, v, 0xc6c9c3, 'concrete');
    for (const s of [-1, 1]) {
      box(g, 7, .5, 92, RAIL.at + s * 10, 10.4, 0, C.pave, 'concrete');
      decal(g, .5, 88, RAIL.at + s * 7, 0, 0xe0b23a, 10.68);
      for (let v = -40; v <= 40; v += 16) box(g, 1.3, .45, 2.6, RAIL.at + s * 11.6, 10.88, v, 0x4c5a60);
    }
    for (const u of tracks) {
      for (const o of [-.75, .75]) box(g, .16, .22, SPAN, u + o, 10.36, 0, 0x8d9490, 'metal');
      for (let v = -EDGE + 6; v < EDGE; v += 5) box(g, 2.6, .16, .55, u, 10.23, v, 0x6f665c);
    }
    box(g, 30, .7, 94, RAIL.at, 16.2, 0, C.roof, 'metal');
    for (const u of [RAIL.at - 13, RAIL.at + 13]) for (let v = -42; v <= 42; v += 14) cylinder(g, .3, 5.6, u, 13.1, v, C.steel, 'metal');
    for (let v = -40; v < 42; v += 7) box(g, 21, .3, 1.4, RAIL.at, 16.75, v, 0x8fc6de, 'glass');
    for (let v = -38; v <= 38; v += 19) light(g, RAIL.at, 15.6, v, 0xfff0c8, .7);
    box(g, 30, .2, 54, RAIL.at, .1, 50, C.pave, 'concrete');
    box(g, 26, 7.4, 46, RAIL.at, 3.7, 50, 0xe6e2d7);
    box(g, 26.4, 4.2, 46.4, RAIL.at, 4.4, 50, C.glass, 'glass');
    box(g, 29, .7, 49, RAIL.at, 7.75, 50, C.roof, 'metal');
    for (const u of [RAIL.at - 10, RAIL.at + 10]) box(g, 6, 10.4, 8, u, 5.2, 40, 0xdad6cb);
    label(g, 'AIRPORT CENTRAL', RAIL.at, 8.7, 26.6, 2.2, '#eef6f4', {rotY: Math.PI, width: 7});
    label(g, 'TRAINS', RAIL.at, 13.4, -48.6, 2.4, '#eef6f4', {rotY: Math.PI, width: 3});
  }
  /** Fills the ground the road cuts through: gardens by the kerb, short-stay
      parking between the tram and the railway. */
  function plaza(g) {
    for (const s of [-1, 1]) {
      box(g, 28, .1, 66, 39, .05, s * 63, C.pave, 'concrete');
      box(g, 21, .16, 57, 39, .08, s * 63, C.lawn, 'grass');
      box(g, 3, .12, 57, 39, .06, s * 63, C.pave, 'concrete');
      for (let v = -22; v <= 22; v += 11) { grove(g, 31, s * 63 + v, .9, v); grove(g, 47, s * 63 + v + 5, .85, v + 1); }
      for (const v of [-28, 28]) streetLamp(g, 39, s * 63 + v, {height: 9});
      box(g, 9, .5, 9, 39, .25, s * 63, 0xcfd3cd, 'concrete');
      box(g, 7, .35, 7, 39, .42, s * 63, 0x4f93a8, 'water');
      cylinder(g, .7, 2.4, 39, 1.2, s * 63, 0xd9dcd6, 'concrete', .45);
    }
    carPark(g, 70, -96, 98, -32, 57);
    carPark(g, 70, 32, 94, 96, 63);
    box(g, 168, 1.2, 1.8, 118, .6, -16.6, 0x6f9a63, 'grass');
  }
  function walkway(g) {
    for (const [a, b] of [[22, 52], [70, 97]]) {
      box(g, b - a, .14, 7, (a + b) / 2, .07, 19, C.pave, 'concrete');
      box(g, b - a, .3, 7.8, (a + b) / 2, 4.3, 19, C.roof, 'metal');
      for (let u = a + 3; u < b; u += 9) for (const v of [15.6, 22.4]) cylinder(g, .18, 4.3, u, 2.15, v, C.steel, 'metal');
      light(g, (a + b) / 2, 4, 19, 0xfff0c8, .6);
    }
    box(g, 16, .12, 7, TRAM.at, .06, 19, C.pave, 'concrete');
  }
  function district(g) {
    const plots = [
      [176, -72, 42, 38, 12, 'AIRPORT PLAZA HOTEL', 0],
      [268, -76, 38, 44, 17, 'SKYLINE SUITES', 0],
      [376, -70, 50, 34, 9, null, 0],
      [482, -76, 42, 40, 14, 'TRANSIT INN', 0],
      [192, 76, 40, 44, 18, 'LUMA AIRPORT HOTEL', Math.PI],
      [304, 72, 50, 34, 10, null, Math.PI],
      [418, 76, 44, 38, 13, 'HARBOUR REST', Math.PI],
    ];
    const walls = [0xe7e3d8, 0xdad9d1, 0xe3d9c9, 0xd7dbd8];
    plots.forEach(([u, v, w, d, floors, sign, face], i) =>
      tower(g, u, v, w, d, floors, {sign, face, wall: walls[i % walls.length], band: i % 3 === 1 ? 0x4c7f8e : C.glass}));
    for (const s of [-1, 1]) {
      box(g, 430, .1, 9, 355, .05, s * 108, C.road, 'asphalt');
      for (let u = 156; u < 550; u += 62) streetLamp(g, u, s * 113, {height: 9});
      for (const u of [176, 268, 376, 482, 192, 304, 418]) box(g, 8, .1, 46, u + 14, .05, s * 85, C.road, 'asphalt');
    }
    garage(g, 170, -166, 62, 78, 5, 91);
    carPark(g, 238, -202, 332, -122, 17);
    carPark(g, 176, 126, 300, 202, 23);
    carPark(g, 344, 128, 452, 200, 41);
    for (let v = -EDGE; v <= EDGE; v += 29) { grove(g, 650, v, 1.1, v); grove(g, 664, v + 14, 1, v + 1); }
    for (let u = 40; u < 650; u += 31) { grove(g, u, -EDGE - 9, 1.05, u); grove(g, u + 15, EDGE + 9, 1, u + 2); }
    for (let v = -112; v < -36; v += 19) { grove(g, 34, v, .9, v); grove(g, 132, v + 9, .85, v + 1); }
    for (let v = 100; v < 190; v += 19) { grove(g, 34, v, .9, v); grove(g, 132, v + 9, .85, v + 1); }
  }
  function scenery(g, L) {
    forecourt(g, L);
    busStation(g, L);
    mainRoad(g);
    tramLine(g);
    railway(g);
    walkway(g);
    plaza(g);
    district(g);
  }

  // ── Things that move ──────────────────────────────────────────────────
  const wheel = (g, x, z, r = .5) => { const t = cylinder(g, r, .34, x, r, z, 0x22292b, 'paint', r, 10); t.rotation.z = Math.PI / 2; };
  let carGeo = null, carMat = null;
  /** One paint-only body so every car fits in a single instanced mesh. */
  function carGeometry() {
    if (carGeo) return carGeo;
    const g = new T.Group();
    box(g, 1.86, .74, 4.34, 0, .56, 0, 0xffffff);
    box(g, 1.7, .62, 2.35, 0, 1.2, .3, 0xffffff);
    box(g, 1.74, .44, 2.1, 0, 1.26, .3, 0x3a4248);
    box(g, 1.5, .16, .3, 0, .62, -2.2, 0xf4f1e1);
    box(g, 1.5, .16, .3, 0, .62, 2.2, 0x8c3a33);
    for (const x of [-.86, .86]) for (const z of [-1.4, 1.5]) box(g, .22, .5, .58, x, .3, z, 0x22292b);
    g.traverse(o => { if (o.isMesh) o.castShadow = true; });
    carGeo = bake(g)[0].geometry;
    return carGeo;
  }
  const carMaterial = () => carMat || (carMat = new T.MeshStandardMaterial({vertexColors: true, roughness: .55}));
  function busBody() {
    const g = new T.Group();
    box(g, 2.6, 2.45, 12, 0, 1.78, 0, 0xf1f2ee);
    box(g, 2.62, 1.15, 10.4, 0, 2.4, .3, 0x2a3a44, 'glass');
    box(g, 2.64, .55, 12, 0, .78, 0, C.teal);
    box(g, 2.48, .22, 11.6, 0, 3.08, 0, 0xdfe3e2);
    box(g, 2.3, 1.4, .14, 0, 2.45, -6.03, 0x2a3a44, 'glass');
    box(g, 1.6, .5, .12, 0, 3.25, -6.04, 0x1a2126);
    for (const z of [-2.4, 3.2]) box(g, .1, 2, 1.3, 1.32, 1.9, z, 0x33424a, 'glass');
    for (const x of [-.9, .9]) { light(g, x, 1.05, -6.06, 0xfff6d8, .34); light(g, x, 1.1, 6.06, 0xff3b30, .28); }
    wheel(g, -1.28, -3.9, .55); wheel(g, 1.28, -3.9, .55);
    wheel(g, -1.28, 3.9, .55); wheel(g, 1.28, 3.9, .55);
    return g;
  }
  function tramBody(lead) {
    const g = new T.Group();
    box(g, 2.4, 2, 8.3, 0, 1.55, 0, 0xf2f1ec);
    box(g, 2.42, .95, 7.2, 0, 2.15, 0, 0x2a3a44, 'glass');
    box(g, 2.44, .5, 8.3, 0, .8, 0, C.teal);
    box(g, 2.2, .3, 8, 0, 2.7, 0, 0xd7dbd8, 'metal');
    if (lead) {
      box(g, 2.3, 1.5, .14, 0, 2, -4.16, 0x2a3a44, 'glass');
      box(g, 1.4, .4, .12, 0, 3, -4.17, 0x1a2126);
      for (const x of [-.85, .85]) light(g, x, .95, -4.18, 0xfff6d8, .3);
      box(g, .6, .5, .5, 0, 3.1, 1.2, 0x555f63, 'metal');
      box(g, .14, 3.2, .14, 0, 4.6, 1.9, 0x8e9aa0, 'metal');
      box(g, 1.5, .1, .1, 0, 6.28, 2.6, 0x8e9aa0, 'metal');
    }
    for (const z of [-2.8, 2.8]) { box(g, 2.1, .6, 2.4, 0, .5, z, 0x39424a, 'metal'); wheel(g, -1.05, z, .38); wheel(g, 1.05, z, .38); }
    return g;
  }
  function coachBody(lead) {
    const g = new T.Group();
    box(g, 3, 2.9, 22, 0, 2.25, 0, 0xeceae2);
    box(g, 3.03, 1.1, 18.4, 0, 2.7, 0, 0x27343c, 'glass');
    box(g, 3.05, .55, 22, 0, 1.1, 0, 0x1f5f7a);
    box(g, 2.7, .4, 21.4, 0, 3.75, 0, 0xc8ccc9, 'metal');
    for (const z of [-7.6, 7.6]) { box(g, 2.5, .8, 3.6, 0, .55, z, 0x333b3f, 'metal'); wheel(g, -1.2, z - 1.1, .45); wheel(g, 1.2, z - 1.1, .45); wheel(g, -1.2, z + 1.1, .45); wheel(g, 1.2, z + 1.1, .45); }
    if (lead) {
      box(g, 2.8, 1.9, .16, 0, 2.6, -11.02, 0x27343c, 'glass');
      for (const x of [-1.05, 1.05]) light(g, x, 1.2, -11.05, 0xfff6d8, .34);
    }
    return g;
  }

  /** The one-way forecourt loop: main road in, bus station, kerb, road out. */
  /** Kerb lane (heading +v, next to the canopy) and outer lane (heading −v)
      of the forecourt road, as u in metres out from the terminal wall. */
  const KERB = {near: 12.4, far: 18.6};
  function paths(L) {
    const K = L.K, ring = arc(RING.at, 0, RING.radius, Math.PI * .78, -Math.PI * .78, 8);
    // In on the main road, down the outer lane to the bus station, round
    // and back up the kerb lane past the doors, then out the way it came.
    const road = route([
      [ROAD.end - 44, -ROAD.lane], [40, -ROAD.lane], [KERB.far, -ROAD.lane],
      [KERB.far, -(K + 92)], [KERB.near, -(K + 92)], [KERB.near, K + 16],
      [KERB.far, K + 16], [KERB.far, ROAD.lane], [40, ROAD.lane],
      [ROAD.end - 44, ROAD.lane], ...ring,
    ], {radius: 6});
    const tram = route([
      [TRAM.at - TRAM.apart / 2, -(EDGE + 4)], [TRAM.at - TRAM.apart / 2, EDGE + 4],
      ...arc(TRAM.at, EDGE + 4, TRAM.apart / 2, Math.PI, 0, 6),
      [TRAM.at + TRAM.apart / 2, EDGE + 4], [TRAM.at + TRAM.apart / 2, -(EDGE + 4)],
      ...arc(TRAM.at, -(EDGE + 4), TRAM.apart / 2, 0, -Math.PI, 6),
    ], {radius: 3});
    const rail = route([
      [RAIL.at - RAIL.apart / 2, -(EDGE + 12)], [RAIL.at - RAIL.apart / 2, EDGE + 12],
      ...arc(RAIL.at, EDGE + 12, RAIL.apart / 2, Math.PI, 0, 6),
      [RAIL.at + RAIL.apart / 2, EDGE + 12], [RAIL.at + RAIL.apart / 2, -(EDGE + 12)],
      ...arc(RAIL.at, -(EDGE + 12), RAIL.apart / 2, 0, -Math.PI, 6),
    ], {radius: 3.5});
    return {road, tram, rail};
  }
  const townSpeed = p => p.u < 50 ? .45 : p.u < 120 ? .72 : 1;

  // ── Assembly ──────────────────────────────────────────────────────────
  const UP = new T.Vector3(0, 1, 0), ONE = new T.Vector3(1, 1, 1);
  const matrix = new T.Matrix4(), quat = new T.Quaternion(), pos = new T.Vector3();
  const CARS = 60;

  function worldRect(L, u0, u1, v0, v1) {
    const c = Math.cos(L.angle), s = Math.sin(L.angle);
    const xs = [], zs = [];
    for (const [u, v] of [[u0, v0], [u1, v0], [u0, v1], [u1, v1]]) {
      xs.push(L.origin.x + u * c + v * s);
      zs.push(L.origin.z - u * s + v * c);
    }
    return {minX: Math.min(...xs), maxX: Math.max(...xs), minZ: Math.min(...zs), maxZ: Math.max(...zs)};
  }

  let current = null;
  function build(list) {
    const L = layout(list || []);
    if (!L) { if (current) current.dispose(); current = null; return null; }
    const key = `${L.origin.x}|${L.origin.z}|${L.angle.toFixed(4)}|${L.K}|${L.signs.map(s => s.text + s.v).join()}`;
    if (current && current.key === key) return current;
    if (current) current.dispose();

    const group = new T.Group();
    group.position.set(L.origin.x, 0, L.origin.z);
    group.rotation.y = L.angle;
    const statics = new T.Group();
    scenery(statics, L);
    bake(statics);
    group.add(statics);

    const {road, tram, rail} = paths(L);
    const cars = new T.InstancedMesh(carGeometry(), carMaterial(), CARS);
    cars.frustumCulled = false;
    cars.castShadow = true;
    for (let i = 0; i < CARS; i++) cars.setColorAt(i, new T.Color(carPaint[(i * 7) % carPaint.length]));
    group.add(cars);
    const traffic = Array.from({length: CARS}, (_, i) => ({s: road.length * i / CARS, lane: i % 2 ? -1.4 : 1.4}));

    const movers = [];
    function fleet(count, r, {speed, dwell = 0, stops = [], lane = 0, y = 0, slow = null, parts}) {
      for (let i = 0; i < count; i++) {
        const built = parts.map(([key, make, back]) => {
          const mesh = instance(`ls:${key}`, make);
          mesh.userData.mover = key;
          group.add(mesh);
          return {mesh, back};
        });
        movers.push({parts: built, route: r, s: r.length * i / count + 1, hold: 0, speed, dwell, stops, lane, y, slow, index: i});
      }
    }
    fleet(6, road, {
      speed: 13, dwell: 9, lane: 2.6, slow: townSpeed,
      stops: [arcOf(road, KERB.near, -(L.K + 70)), arcOf(road, KERB.near, -(L.K + 40)), arcOf(road, KERB.near, -L.K * .4), arcOf(road, KERB.near, L.K * .5)],
      parts: [['bus', busBody, 0]],
    });
    fleet(3, tram, {
      speed: 12, dwell: 8,
      stops: [arcOf(tram, TRAM.at - TRAM.apart / 2, 37), arcOf(tram, TRAM.at + TRAM.apart / 2, -37)],
      parts: [['tramA', () => tramBody(true), 0], ['tramB', () => tramBody(false), 8.6], ['tramC', () => tramBody(false), 17.2]],
    });
    fleet(2, rail, {
      speed: 24, dwell: 14, y: RAIL.top,
      stops: [arcOf(rail, RAIL.at - RAIL.apart / 2, 0), arcOf(rail, RAIL.at + RAIL.apart / 2, 0)],
      parts: [['coachA', () => coachBody(true), 0], ['coachB', () => coachBody(false), 22.6], ['coachC', () => coachBody(false), 45.2], ['coachD', () => coachBody(true), 67.8]],
    });

    function move(m, step) {
      const r = m.route;
      if (m.hold > 0) m.hold = Math.max(0, m.hold - step);
      else {
        let speed = m.speed * (m.slow ? m.slow(at(r, m.s)) : 1);
        let gap = Infinity, target = null;
        for (const s of m.stops) { const d = ahead(r, m.s, s); if (d > 3 && d < gap) { gap = d; target = s; } }
        if (gap < 50) speed *= Math.max(.05, gap / 50);
        const forward = speed * step;
        if (target !== null && gap <= forward) { m.s = target; m.hold = m.dwell; }
        else m.s = (m.s + forward) % r.length;
      }
      for (const part of m.parts) {
        const p = at(r, m.s - part.back, m.lane);
        part.mesh.position.set(p.u, m.y, p.v);
        part.mesh.rotation.y = Math.atan2(-p.du, -p.dv);
      }
    }

    const district = {
      key, group, L,
      rect: worldRect(L, -14, 670, -(EDGE + 30), EDGE + 30),
      update(dt, {activity = .3, night = 0, paused = false, speed = 1} = {}) {
        const step = paused ? 0 : dt * Math.min(2.2, 1 + (Math.max(1, speed) - 1) * .12);
        const busy = Math.max(0, Math.min(1, activity));
        const wanted = Math.round(CARS * busy * (1 - .45 * Math.max(0, Math.min(1, night))));
        const stride = wanted ? Math.max(1, Math.round(CARS / wanted)) : Infinity;
        let n = 0;
        for (let i = 0; i < CARS; i++) {
          const c = traffic[i];
          c.s = (c.s + 16 * townSpeed(at(road, c.s)) * step) % road.length;
          if (!wanted || i % stride) continue;
          const p = at(road, c.s, c.lane);
          quat.setFromAxisAngle(UP, Math.atan2(-p.du, -p.dv));
          pos.set(p.u, 0, p.v);
          cars.setMatrixAt(n++, matrix.compose(pos, quat, ONE));
        }
        cars.count = n;
        cars.instanceMatrix.needsUpdate = true;
        // Only the buses come and go with demand; trams and trains keep to
        // their timetable however quiet the airport is.
        const buses = busy > 0 ? Math.max(1, Math.round(6 * busy)) : 0;
        for (const m of movers) move(m, step);
        for (let i = 0; i < 6; i++) for (const part of movers[i].parts) part.mesh.visible = i < buses;
      },
      dispose() {
        dispose(group);
        cars.dispose();
        group.parent?.remove(group);
        if (current === district) current = null;
      },
    };
    district.update(0, {});
    current = district;
    return district;
  }

  return {build, layout};
})();
