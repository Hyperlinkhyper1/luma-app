/* Subway Builder — game state, economy and construction actions.
   Four modes: metro (bored tunnels, straight), bus & tram (surface — routes
   pathfind along the real street network), train (only real OSM railway
   stations, routes pathfind along real tracks). Stations are lng/lat; the
   sim works in local meters via SB.geo. All prices are dollars. */
(function () {
  'use strict';
  const SB = (window.SB = window.SB || {});

  const SAVE_KEY = 'subway_builder_geo_v1';

  // ── Mode catalog ─────────────────────────────────────────────────────
  const MODES = {
    metro: {
      label: 'Metro', vehicle: 'train',
      speedKmh: 60, cap: 600, dwellMin: 0.75, access: 950,
      stationBase: 60e6, densMult: 0.6, perKm: 45e6, waterMult: 2.6,
      vehicleCost: 25e6, vehicleRefund: 12e6, vehicleOpDay: 6000,
      stationOpDay: 4000, trackOpKmDay: 1500, maxVehicles: 14, spacing: 400,
    },
    tram: {
      label: 'Tram', vehicle: 'tram',
      speedKmh: 24, cap: 220, dwellMin: 0.5, access: 650,
      stationBase: 6e6, densMult: 0.4, perKm: 14e6, waterMult: 1,
      vehicleCost: 4.5e6, vehicleRefund: 2e6, vehicleOpDay: 1800,
      stationOpDay: 600, trackOpKmDay: 500, maxVehicles: 16, spacing: 280,
    },
    bus: {
      label: 'Bus', vehicle: 'bus',
      speedKmh: 19, cap: 90, dwellMin: 0.35, access: 450,
      stationBase: 400e3, densMult: 0.3, perKm: 150e3, waterMult: 1,
      vehicleCost: 700e3, vehicleRefund: 300e3, vehicleOpDay: 900,
      stationOpDay: 120, trackOpKmDay: 0, maxVehicles: 20, spacing: 220,
    },
    train: {
      label: 'Train', vehicle: 'train',
      speedKmh: 85, cap: 900, dwellMin: 1.2, access: 1400,
      stationBase: 25e6, densMult: 0.2, perKm: 4e6, waterMult: 1,
      vehicleCost: 35e6, vehicleRefund: 15e6, vehicleOpDay: 9000,
      stationOpDay: 6000, trackOpKmDay: 800, maxVehicles: 10, spacing: 0,
    },
  };
  SB.MODES = MODES;

  const ECON = {
    demolishRefund: 0.25,
    loanAmount: 250e6,
    loanRatePerDay: 0.0006,
    capitalEveryDays: 30,
    fareMin: 1, fareMax: 5, fareDefault: 2.5,
  };
  SB.ECON = ECON;

  const MILESTONES = [
    { share: 0.03, grant: 250e6, label: 'City Hall takes notice' },
    { share: 0.06, grant: 400e6, label: 'State transit grant' },
    { share: 0.10, grant: 600e6, label: 'Federal infrastructure grant' },
    { share: 0.15, grant: 800e6, label: 'Transit City award' },
    { share: 0.22, grant: 1200e6, label: 'World-class metro fund' },
    { share: 0.30, grant: 1600e6, label: 'Transit capital of the world' },
  ];
  SB.MILESTONES = MILESTONES;

  const LINE_COLORS = [
    ['#e6493f', 'Red'], ['#2f6fdb', 'Blue'], ['#2e9e4f', 'Green'],
    ['#f28c28', 'Orange'], ['#8e4fc7', 'Purple'], ['#e8c11c', 'Yellow'],
    ['#18a999', 'Teal'], ['#e05a9b', 'Pink'], ['#7aa711', 'Lime'],
    ['#5058c8', 'Indigo'], ['#b9791a', 'Amber'], ['#12a5c9', 'Cyan'],
  ];

  const game = (SB.game = {
    city: null,
    place: null,
    state: null,
    onChange: null,
    networkDirty: false,
  });

  function emit() {
    game.networkDirty = true;
    if (game.onChange) game.onChange();
  }

  function blankState(city) {
    return {
      money: city.def.budget,
      day: 1,
      fare: ECON.fareDefault,
      loans: 0,
      stations: [],   // {id, mode, lng, lat, name, real?}
      lines: [],      // {id, mode, name, color, stationIds, vehicles, paths:[[lnglat…]…]}
      nextStationId: 1,
      nextLineId: 1,
      milestonesHit: [],
      history: [],
      totalSpent: 0,
      helpSeen: false,
    };
  }

  // ── Save / load (one slot per place) ─────────────────────────────────
  function readSaves() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      return raw ? JSON.parse(raw) : { current: null, places: {} };
    } catch (e) {
      return { current: null, places: {} };
    }
  }

  SB.placeId = function (lng, lat) {
    return lat.toFixed(3) + ',' + lng.toFixed(3);
  };

  game.save = function () {
    if (!game.state || !game.place) return;
    try {
      const all = readSaves();
      all.current = game.place.id;
      const state = JSON.parse(JSON.stringify(game.state, (k, v) =>
        (k === 'x' || k === 'y' || k === '_pm') ? undefined : v));
      all.places[game.place.id] = { place: game.place, state };
      localStorage.setItem(SAVE_KEY, JSON.stringify(all));
    } catch (e) { /* storage full — play on without saves */ }
  };

  game.savedGames = function () {
    const all = readSaves();
    const out = [];
    for (const [id, entry] of Object.entries(all.places)) {
      out.push({
        id, place: entry.place,
        day: entry.state.day,
        lines: entry.state.lines.length,
        stations: entry.state.stations.length,
        current: all.current === id,
      });
    }
    out.sort((a, b) => (b.current ? 1 : 0) - (a.current ? 1 : 0));
    return out;
  };

  game.savedEntry = function (placeId) { return readSaves().places[placeId] || null; };

  game.deleteSave = function (placeId) {
    const all = readSaves();
    delete all.places[placeId];
    if (all.current === placeId) all.current = null;
    localStorage.setItem(SAVE_KEY, JSON.stringify(all));
  };

  game.attachCity = function (city, place, fresh) {
    game.city = city;
    game.place = place;
    const saved = !fresh && game.savedEntry(place.id);
    game.state = saved ? saved.state : blankState(city);
    // Rehydrate derived data + migrate pre-mode saves.
    for (const s of game.state.stations) {
      if (!s.mode) s.mode = 'metro';
      const [x, y] = SB.geo.toM(s.lng, s.lat);
      s.x = x; s.y = y;
    }
    for (const l of game.state.lines) {
      if (!l.mode) l.mode = 'metro';
      if (l.vehicles === undefined) l.vehicles = l.trains !== undefined ? l.trains : 2;
      delete l.trains;
      if (!l.paths || l.paths.length !== l.stationIds.length - 1) {
        l.paths = [];
        for (let i = 0; i < l.stationIds.length - 1; i++) {
          const a = game.stationById(l.stationIds[i]);
          const b = game.stationById(l.stationIds[i + 1]);
          l.paths.push([[a.lng, a.lat], [b.lng, b.lat]]);
        }
      }
      delete l._pm;
    }
    game.save();
    emit();
  };

  // Meter-space copies of a line's segment paths (cached per line).
  game.pathsM = function (line) {
    if (!line._pm) {
      line._pm = line.paths.map((seg) => seg.map(([lng, lat]) => SB.geo.toM(lng, lat)));
    }
    return line._pm;
  };

  game.segLenM = function (line, i) {
    const seg = game.pathsM(line)[i];
    let len = 0;
    for (let k = 0; k < seg.length - 1; k++) {
      len += Math.hypot(seg[k + 1][0] - seg[k][0], seg[k + 1][1] - seg[k][1]);
    }
    return len;
  };

  game.lineLengthM = function (line) {
    let len = 0;
    for (let i = 0; i < line.stationIds.length - 1; i++) len += game.segLenM(line, i);
    return len;
  };

  game.stationById = function (id) {
    return game.state.stations.find((s) => s.id === id) || null;
  };
  game.lineById = function (id) {
    return game.state.lines.find((l) => l.id === id) || null;
  };
  game.linesThrough = function (stationId) {
    return game.state.lines.filter((l) => l.stationIds.includes(stationId));
  };

  // ── Routing between stations, per mode ───────────────────────────────
  /* Returns {pts (lnglat), len, waterM, cost} or {err}. */
  game.routeSegment = function (mode, a, b) {
    const M = MODES[mode];
    if (mode === 'metro') {
      const len = Math.hypot(b.x - a.x, b.y - a.y);
      const steps = Math.max(2, Math.ceil(len / 90));
      let waterM = 0;
      for (let i = 0; i <= steps; i++) {
        const t = i / steps;
        if (game.city.isWater(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)) waterM += len / (steps + 1);
      }
      const cost = ((len - waterM) / 1000) * M.perKm + (waterM / 1000) * M.perKm * M.waterMult;
      return { pts: [[a.lng, a.lat], [b.lng, b.lat]], len, waterM, cost };
    }
    const graph = mode === 'train' ? SB.net.rails : SB.net.roads;
    const snap = mode === 'train' ? 450 : 320;
    const r = SB.net.route(graph, a.x, a.y, b.x, b.y, snap);
    if (!r) {
      return { err: mode === 'train'
        ? 'No rail connection exists between these stations'
        : 'No street route between these stops' };
    }
    if (r.len > Math.hypot(b.x - a.x, b.y - a.y) * 4 + 1500) {
      return { err: 'The only route is a huge detour — pick closer stops' };
    }
    return {
      pts: r.pts.map(([x, y]) => SB.geo.toLL(x, y)),
      len: r.len, waterM: 0,
      cost: (r.len / 1000) * M.perKm,
    };
  };

  // ── Cost helpers ─────────────────────────────────────────────────────
  game.stationCostAt = function (x, y, mode) {
    const M = MODES[mode];
    const ci = game.city.cellIndexAt(x, y);
    let dens = 0;
    if (ci >= 0) {
      const c = game.city.cells[ci];
      dens = Math.max(c.pop / game.city.maxPop, c.jobs / game.city.maxJobs);
    }
    return M.stationBase * (1 + dens * M.densMult);
  };

  game.draftCost = function (mode, stationIds) {
    let cost = 0, waterM = 0, len = 0;
    for (let i = 0; i < stationIds.length - 1; i++) {
      const a = game.stationById(stationIds[i]);
      const b = game.stationById(stationIds[i + 1]);
      const seg = game.routeSegment(mode, a, b);
      if (seg.err) return { err: seg.err };
      cost += seg.cost; waterM += seg.waterM; len += seg.len;
    }
    return { cost, waterM, len };
  };

  // ── Validation ───────────────────────────────────────────────────────
  game.canPlaceStation = function (x, y, mode) {
    const city = game.city;
    const M = MODES[mode];
    if (!city.inBounds(x, y)) return { ok: false, err: 'Outside the play area (7 km around your chosen point)' };
    if (city.isWater(x, y)) return { ok: false, err: 'That’s open water' };
    if ((mode === 'bus' || mode === 'tram') &&
        SB.net.nearestNode(SB.net.roads, x, y, 130) < 0) {
      return { ok: false, err: 'Place ' + M.label.toLowerCase() + ' stops on a street' };
    }
    for (const s of game.state.stations) {
      if (s.mode === mode && Math.hypot(s.x - x, s.y - y) < M.spacing) {
        return { ok: false, err: 'Too close to ' + s.name };
      }
    }
    const cost = game.stationCostAt(x, y, mode);
    if (cost > game.state.money) return { ok: false, err: 'Not enough funds', cost };
    return { ok: true, cost };
  };

  // ── Actions ──────────────────────────────────────────────────────────
  game.addStation = function (lng, lat, mode) {
    if (mode === 'train') return { ok: false, err: 'Trains only call at real railway stations — click one' };
    const [x, y] = SB.geo.toM(lng, lat);
    const check = game.canPlaceStation(x, y, mode);
    if (!check.ok) return check;
    const st = game.state;
    // Surface stops snap onto the street they were dropped near.
    let px = x, py = y, plng = lng, plat = lat;
    if (mode === 'bus' || mode === 'tram') {
      const n = SB.net.nearestNode(SB.net.roads, x, y, 130);
      if (n >= 0) {
        px = SB.net.roads.xs[n]; py = SB.net.roads.ys[n];
        [plng, plat] = SB.geo.toLL(px, py);
      }
    }
    const taken = new Set(st.stations.map((s) => s.name));
    const station = {
      id: st.nextStationId++,
      mode, lng: plng, lat: plat, x: px, y: py,
      name: SB.stationName(game.city, px, py, taken),
    };
    st.stations.push(station);
    st.money -= check.cost;
    st.totalSpent += check.cost;
    game.save();
    emit();
    return { ok: true, station, cost: check.cost };
  };

  /* Lease a real railway station (from SB.net.railStations). */
  game.addTrainStation = function (real) {
    const st = game.state;
    const existing = st.stations.find(
      (s) => s.mode === 'train' && Math.hypot(s.x - real.x, s.y - real.y) < 120);
    if (existing) return { ok: true, station: existing, cost: 0, existing: true };
    const cost = game.stationCostAt(real.x, real.y, 'train');
    if (cost > st.money) return { ok: false, err: 'Not enough funds', cost };
    const station = {
      id: st.nextStationId++,
      mode: 'train', real: true,
      lng: real.lng, lat: real.lat, x: real.x, y: real.y,
      name: real.name,
    };
    st.stations.push(station);
    st.money -= cost;
    st.totalSpent += cost;
    game.save();
    emit();
    return { ok: true, station, cost };
  };

  game.nextLineColor = function () {
    const used = new Set(game.state.lines.map((l) => l.color));
    for (const [hex] of LINE_COLORS) if (!used.has(hex)) return hex;
    return LINE_COLORS[game.state.lines.length % LINE_COLORS.length][0];
  };

  game.commitLine = function (mode, stationIds) {
    if (stationIds.length < 2) return { ok: false, err: 'A line needs at least two stops' };
    const st = game.state;
    const paths = [];
    let cost = 0;
    for (let i = 0; i < stationIds.length - 1; i++) {
      const a = game.stationById(stationIds[i]);
      const b = game.stationById(stationIds[i + 1]);
      const seg = game.routeSegment(mode, a, b);
      if (seg.err) return { ok: false, err: seg.err };
      paths.push(seg.pts);
      cost += seg.cost;
    }
    if (cost > st.money) return { ok: false, err: 'Not enough funds' };
    const color = game.nextLineColor();
    const entry = LINE_COLORS.find(([hex]) => hex === color);
    const line = {
      id: st.nextLineId++,
      mode,
      name: (entry ? entry[1] : '') + ' ' + MODES[mode].label,
      color,
      stationIds: stationIds.slice(),
      vehicles: 2,
      paths,
    };
    st.lines.push(line);
    st.money -= cost;
    st.totalSpent += cost;
    game.save();
    emit();
    return { ok: true, line, cost };
  };

  game.extendLine = function (lineId, stationId, atStart) {
    const line = game.lineById(lineId);
    const station = game.stationById(stationId);
    if (!line || !station) return { ok: false, err: 'Unknown line or station' };
    if (station.mode !== line.mode) return { ok: false, err: 'That stop belongs to a different mode' };
    if (line.stationIds.includes(stationId)) return { ok: false, err: 'Already on this line' };
    const endId = atStart ? line.stationIds[0] : line.stationIds[line.stationIds.length - 1];
    const end = game.stationById(endId);
    const seg = atStart ? game.routeSegment(line.mode, station, end)
                        : game.routeSegment(line.mode, end, station);
    if (seg.err) return { ok: false, err: seg.err };
    if (seg.cost > game.state.money) return { ok: false, err: 'Not enough funds' };
    if (atStart) { line.stationIds.unshift(stationId); line.paths.unshift(seg.pts); }
    else { line.stationIds.push(stationId); line.paths.push(seg.pts); }
    delete line._pm;
    game.state.money -= seg.cost;
    game.state.totalSpent += seg.cost;
    game.save();
    emit();
    return { ok: true };
  };

  game.removeStation = function (stationId) {
    const st = game.state;
    const idx = st.stations.findIndex((s) => s.id === stationId);
    if (idx < 0) return { ok: false, err: 'Unknown station' };
    const station = st.stations[idx];
    let refund = game.stationCostAt(station.x, station.y, station.mode) * ECON.demolishRefund;
    for (let i = st.lines.length - 1; i >= 0; i--) {
      const line = st.lines[i];
      const pos = line.stationIds.indexOf(stationId);
      if (pos < 0) continue;
      line.stationIds.splice(pos, 1);
      if (line.stationIds.length < 2) {
        refund += line.vehicles * MODES[line.mode].vehicleRefund;
        st.lines.splice(i, 1);
        continue;
      }
      // Re-stitch the route across the removed stop.
      if (pos === 0) line.paths.splice(0, 1);
      else if (pos === line.stationIds.length) line.paths.splice(pos - 1, 1);
      else {
        const a = game.stationById(line.stationIds[pos - 1]);
        const b = game.stationById(line.stationIds[pos]);
        const seg = game.routeSegment(line.mode, a, b);
        if (seg.err) {
          refund += line.vehicles * MODES[line.mode].vehicleRefund;
          st.lines.splice(i, 1);
          continue;
        }
        line.paths.splice(pos - 1, 2, seg.pts);
      }
      delete line._pm;
    }
    st.stations.splice(idx, 1);
    st.money += refund;
    game.save();
    emit();
    return { ok: true, refund };
  };

  game.deleteLine = function (lineId) {
    const st = game.state;
    const idx = st.lines.findIndex((l) => l.id === lineId);
    if (idx < 0) return { ok: false, err: 'Unknown line' };
    const line = st.lines[idx];
    const M = MODES[line.mode];
    const refund = (game.lineLengthM(line) / 1000) * M.perKm * ECON.demolishRefund +
      line.vehicles * M.vehicleRefund;
    st.lines.splice(idx, 1);
    st.money += refund;
    game.save();
    emit();
    return { ok: true, refund };
  };

  game.addVehicle = function (lineId) {
    const line = game.lineById(lineId);
    if (!line) return { ok: false, err: 'Unknown line' };
    const M = MODES[line.mode];
    if (line.vehicles >= M.maxVehicles) {
      return { ok: false, err: 'Line is at its fleet limit (' + M.maxVehicles + ')' };
    }
    if (M.vehicleCost > game.state.money) return { ok: false, err: 'Not enough funds' };
    line.vehicles++;
    game.state.money -= M.vehicleCost;
    game.state.totalSpent += M.vehicleCost;
    game.save();
    emit();
    return { ok: true };
  };

  game.removeVehicle = function (lineId) {
    const line = game.lineById(lineId);
    if (!line) return { ok: false, err: 'Unknown line' };
    if (line.vehicles <= 1) return { ok: false, err: 'A line needs at least one vehicle' };
    line.vehicles--;
    game.state.money += MODES[line.mode].vehicleRefund;
    game.save();
    emit();
    return { ok: true };
  };

  game.setFare = function (v) {
    game.state.fare = Math.min(ECON.fareMax, Math.max(ECON.fareMin, v));
    game.save();
    emit();
  };

  game.takeLoan = function () {
    game.state.loans += ECON.loanAmount;
    game.state.money += ECON.loanAmount;
    game.save();
    emit();
    return { ok: true };
  };

  game.repayLoan = function () {
    const st = game.state;
    if (st.loans <= 0) return { ok: false, err: 'No outstanding loans' };
    const amount = Math.min(ECON.loanAmount, st.loans, st.money);
    if (amount <= 0) return { ok: false, err: 'Not enough funds' };
    st.loans -= amount;
    st.money -= amount;
    game.save();
    emit();
    return { ok: true, amount };
  };

  // ── Day rollover ─────────────────────────────────────────────────────
  game.endDay = function () {
    const st = game.state;
    const res = SB.sim.results;
    const riders = res ? res.ridersDaily : 0;
    const share = res ? res.share : 0;

    const revenue = riders * st.fare;
    let opex = 0;
    for (const line of st.lines) {
      const M = MODES[line.mode];
      opex += line.vehicles * M.vehicleOpDay;
      opex += (game.lineLengthM(line) / 1000) * M.trackOpKmDay;
    }
    for (const s of st.stations) opex += MODES[s.mode].stationOpDay;
    const interest = st.loans * ECON.loanRatePerDay;
    const net = revenue + game.city.def.funding - opex - interest;

    st.money += net;
    st.day++;

    const events = [];
    if (st.day % ECON.capitalEveryDays === 0) {
      const capital = game.city.def.capital;
      st.money += capital;
      events.push({ type: 'capital', label: 'Annual capital budget', grant: capital });
    }
    for (let i = 0; i < MILESTONES.length; i++) {
      if (share >= MILESTONES[i].share && !st.milestonesHit.includes(i)) {
        st.milestonesHit.push(i);
        st.money += MILESTONES[i].grant;
        events.push({ type: 'milestone', label: MILESTONES[i].label, grant: MILESTONES[i].grant, share: MILESTONES[i].share });
      }
    }

    st.history.push({ day: st.day, riders: Math.round(riders), share, net, money: st.money });
    if (st.history.length > 400) st.history.shift();

    game.save();
    if (game.onChange) game.onChange();
    return { revenue, opex, interest, net, events };
  };

  // ── Formatting helpers ───────────────────────────────────────────────
  SB.fmtMoney = function (v) {
    const sign = v < 0 ? '−$' : '$';
    const a = Math.abs(v);
    if (a >= 1e9) return sign + (a / 1e9).toFixed(a >= 1e10 ? 1 : 2) + 'B';
    if (a >= 1e6) return sign + (a / 1e6).toFixed(a >= 1e8 ? 0 : 1) + 'M';
    if (a >= 1e3) return sign + (a / 1e3).toFixed(0) + 'k';
    return sign + a.toFixed(0);
  };
  SB.fmtInt = function (v) {
    v = Math.round(v);
    if (v >= 1e6) return (v / 1e6).toFixed(2) + 'M';
    if (v >= 1e4) return (v / 1e3).toFixed(0) + 'k';
    if (v >= 1e3) return (v / 1e3).toFixed(1) + 'k';
    return String(v);
  };
  SB.fmtKm = function (m) { return (m / 1000).toFixed(1) + ' km'; };
})();
