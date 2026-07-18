/* Subway Builder — DOM chrome: HUD, toolbar, panels, modals, toasts. */
(function () {
  'use strict';
  const SB = (window.SB = window.SB || {});
  const $ = (id) => document.getElementById(id);

  const ui = (SB.ui = {
    tool: 'select',        // select | station | line | bulldoze
    mode: 'metro',         // metro | tram | bus | train
    overlay: null,         // null | pop | jobs | access | load
    selection: null,
    draftIds: [],
    draftLineId: null,
    speed: 1,
  });

  const SPEEDS = [
    { label: 'pause', mult: 0, dayS: Infinity },
    { label: '1×', mult: 1, dayS: 14 },
    { label: '2×', mult: 2, dayS: 6 },
    { label: '4×', mult: 4, dayS: 2.2 },
  ];
  ui.SPEEDS = SPEEDS;

  function ic(name, cls) {
    return '<svg class="ic' + (cls ? ' ' + cls : '') + '" aria-hidden="true"><use href="#i-' + name + '"/></svg>';
  }
  ui.ic = ic;

  const MODE_ICON = { metro: 'metro', tram: 'tram', bus: 'bus', train: 'train' };
  const MODE_TINT = { metro: '#e05252', tram: '#2e9e4f', bus: '#f2a33c', train: '#7a6ff0' };
  ui.MODE_TINT = MODE_TINT;

  // ── Toasts & banners ─────────────────────────────────────────────────
  ui.toast = function (msg, kind) {
    const el = document.createElement('div');
    el.className = 'toast' + (kind ? ' ' + kind : '');
    el.innerHTML = ic(kind === 'bad' ? 'alert' : kind === 'good' ? 'check' : 'info') + '<span></span>';
    el.lastChild.textContent = msg;
    $('toasts').appendChild(el);
    requestAnimationFrame(() => el.classList.add('show'));
    setTimeout(() => {
      el.classList.remove('show');
      setTimeout(() => el.remove(), 350);
    }, 4200);
  };

  ui.banner = function (title, sub) {
    const el = $('milestone');
    $('milestone-title').textContent = title;
    $('milestone-sub').textContent = sub;
    el.classList.add('show');
    clearTimeout(ui._bannerT);
    ui._bannerT = setTimeout(() => el.classList.remove('show'), 5200);
  };

  // ── Mode / tool / overlay switching ──────────────────────────────────
  function refreshRailHighlight() {
    if (SB.map3d.ready) {
      SB.map3d.setRailMode(ui.mode === 'train' && (ui.tool === 'station' || ui.tool === 'line'));
    }
  }

  ui.setMode = function (mode) {
    if (ui.mode !== mode) ui.cancelDraft(true);
    ui.mode = mode;
    for (const m of Object.keys(SB.MODES)) {
      $('mode-' + m).classList.toggle('active', m === mode);
    }
    refreshRailHighlight();
    if (ui.tool === 'station' || ui.tool === 'line') ui.hintForTool();
    ui.updateAll();
  };

  ui.setTool = function (tool) {
    if (ui.tool === 'line' && tool !== 'line') ui.cancelDraft(true);
    ui.tool = tool;
    for (const t of ['select', 'station', 'line', 'bulldoze']) {
      $('tool-' + t).classList.toggle('active', t === tool);
    }
    refreshRailHighlight();
    ui.hintForTool();
    ui.updateAll();
  };

  ui.hintForTool = function () {
    const M = SB.MODES[ui.mode];
    const hints = {
      select: 'Click a stop or line to inspect it. Drag to pan, scroll to zoom, right-drag to rotate.',
      station: ui.mode === 'train'
        ? 'Trains only call at real stations — highlighted on the map. Click one to lease it.'
        : ui.mode === 'metro'
          ? 'Click the map to dig a metro station. Denser areas cost more.'
          : 'Click near a street to place a ' + M.label.toLowerCase() + ' stop — it snaps to the road.',
      line: ui.mode === 'train'
        ? 'Click real stations in order — the route follows existing tracks. Enter or double-click to finish.'
        : ui.mode === 'metro'
          ? 'Click stations in order to bore tunnels between them. Enter or double-click to finish.'
          : 'Click ' + M.label.toLowerCase() + ' stops in order — the route follows real streets. Enter to finish.',
      bulldoze: 'Click a stop to demolish it (25% refund). Click a line to remove the whole line.',
    };
    ui.hint(hints[ui.tool]);
  };

  ui.setOverlay = function (ov) {
    ui.overlay = ui.overlay === ov ? null : ov;
    for (const o of ['pop', 'jobs', 'access', 'load']) {
      $('ov-' + o).classList.toggle('active', ui.overlay === o);
    }
    if (SB.map3d.ready) SB.map3d.setOverlay(ui.overlay);
    ui.updateAll();
  };

  ui.mapState = function () {
    return {
      tool: ui.tool, mode: ui.mode, overlay: ui.overlay, selection: ui.selection,
      draftIds: ui.draftIds, draftColor: ui.draftColor(),
    };
  };

  ui.hint = function (text) {
    $('hint').textContent = text || '';
    $('hint').style.display = text ? 'block' : 'none';
  };

  ui.setSpeed = function (idx) {
    ui.speed = idx;
    document.querySelectorAll('#speedctl button').forEach((b, i) => {
      b.classList.toggle('active', i === idx);
    });
  };

  // ── Draft lifecycle ──────────────────────────────────────────────────
  ui.beginDraftFrom = function (lineId) {
    ui.draftLineId = lineId || null;
    ui.draftIds = [];
  };

  ui.cancelDraft = function (silent) {
    if (!silent && (ui.draftIds.length || ui.draftLineId)) ui.toast('Line drawing cancelled');
    ui.draftIds = [];
    ui.draftLineId = null;
    ui.updateDraftHint();
  };

  ui.updateDraftHint = function () {
    if (ui.tool !== 'line') return;
    if (ui.draftLineId) {
      const line = SB.game.lineById(ui.draftLineId);
      ui.hint(line
        ? (ui.draftIds.length
            ? 'Extending ' + line.name + ' — click the next stop. Esc to stop.'
            : 'Extending ' + line.name + ': click a stop at either end, then the new stop.')
        : '');
      return;
    }
    if (!ui.draftIds.length) {
      ui.hintForTool();
    } else {
      const d = SB.game.draftCost(ui.mode, ui.draftIds);
      if (d.err) { ui.hint(d.err); return; }
      let t = ui.draftIds.length + ' stops · ' + SB.fmtKm(d.len) + ' · ' + SB.fmtMoney(d.cost);
      if (d.waterM > 0) t += ' (incl. underwater tunnelling)';
      t += ' — Enter to build, Esc to cancel.';
      ui.hint(t);
    }
  };

  ui.draftColor = function () {
    if (ui.draftLineId) {
      const line = SB.game.lineById(ui.draftLineId);
      if (line) return line.color;
    }
    return SB.game.nextLineColor();
  };

  // ── HUD refresh ──────────────────────────────────────────────────────
  ui.updateAll = function () {
    const g = SB.game;
    if (!g.state) return;
    const res = SB.sim.results;

    $('cityname').textContent = g.city.def.name;
    if (SB.map3d.ready) {
      SB.map3d.updateNetwork(ui.mapState());
      if (ui.overlay === 'access') SB.map3d.setOverlay('access');
      refreshRailHighlight();
    }
    $('stat-day').textContent = g.state.day;
    $('stat-money').textContent = SB.fmtMoney(g.state.money);
    $('stat-money').classList.toggle('neg', g.state.money < 0);
    $('stat-riders').textContent = res ? SB.fmtInt(res.ridersDaily) : '—';
    $('stat-share').textContent = res ? (res.share * 100).toFixed(1) + '%' : '—';

    renderLineList();
    renderInfoPanel();
    renderFinance();
  };

  function renderFinance() {
    const st = SB.game.state;
    $('fare-val').textContent = '$' + st.fare.toFixed(2);
    $('loan-out').textContent = st.loans > 0 ? SB.fmtMoney(st.loans) + ' owed' : 'No debt';
    $('btn-repay').disabled = st.loans <= 0;
    const cadence = SB.ECON.capitalEveryDays;
    const daysLeft = cadence - (st.day % cadence);
    $('funding-line').innerHTML =
      SB.fmtMoney(SB.game.city.def.funding) + '/day operating subsidy<br>' +
      SB.fmtMoney(SB.game.city.def.capital) + ' capital budget in ' + daysLeft + 'd';
  }

  function renderLineList() {
    const st = SB.game.state;
    const res = SB.sim.results;
    const wrap = $('linelist');
    wrap.innerHTML = '';
    if (!st.lines.length) {
      const d = document.createElement('div');
      d.className = 'empty';
      d.textContent = 'No lines yet. Pick a mode, place stops, then connect them with the Line tool.';
      wrap.appendChild(d);
    }
    for (const line of st.lines) {
      const row = document.createElement('div');
      row.className = 'linerow';
      const selected = ui.selection && ui.selection.type === 'line' && ui.selection.id === line.id;
      if (selected) row.classList.add('sel');
      const riders = res ? res.lineRiders.get(line.id) || 0 : 0;
      const ratio = res ? res.lineMaxRatio.get(line.id) || 0 : 0;
      const M = SB.MODES[line.mode];
      row.innerHTML =
        '<span class="sw" style="background:' + line.color + '">' + ic(MODE_ICON[line.mode]) + '</span>' +
        '<span class="lcol"><span class="lname">' + line.name + '</span>' +
        '<span class="lmeta">' + line.stationIds.length + ' stops · ' + SB.fmtInt(riders) + '/d' +
        (ratio > 1.05 ? ' · <b class="bad">crowded</b>' : '') + '</span></span>' +
        '<span class="tctl">' +
        '<button class="mini" data-act="vminus" title="Sell a ' + M.vehicle + '">' + ic('minus') + '</button>' +
        '<span class="tcount">' + line.vehicles + '</span>' +
        '<button class="mini" data-act="vplus" title="Buy a ' + M.vehicle + ' (' + SB.fmtMoney(M.vehicleCost) + ')">' + ic('plus') + '</button>' +
        '</span>';
      row.addEventListener('click', (e) => {
        const btn = e.target.closest && e.target.closest('[data-act]');
        const act = btn && btn.getAttribute('data-act');
        if (act === 'vplus') return doAction(SB.game.addVehicle(line.id));
        if (act === 'vminus') return doAction(SB.game.removeVehicle(line.id));
        ui.selection = { type: 'line', id: line.id };
        SB.main.focusLine(line);
        ui.updateAll();
      });
      wrap.appendChild(row);
    }
  }

  function doAction(result) {
    if (result && !result.ok && result.err) ui.toast(result.err, 'bad');
    ui.updateAll();
  }
  ui.doAction = doAction;

  function renderInfoPanel() {
    const panel = $('infopanel');
    const sel = ui.selection;
    if (!sel) { panel.style.display = 'none'; return; }
    const res = SB.sim.results;

    if (sel.type === 'station') {
      const s = SB.game.stationById(sel.id);
      if (!s) { ui.selection = null; panel.style.display = 'none'; return; }
      const lines = SB.game.linesThrough(s.id);
      const boardings = res ? res.boardings.get(s.id) || 0 : 0;
      panel.innerHTML =
        '<div class="ip-head">' + ic(MODE_ICON[s.mode], 'tint-' + s.mode) +
        '<span class="ip-title">' + s.name + '</span>' +
        '<button class="mini ghostbtn" id="ip-close">' + ic('x') + '</button></div>' +
        '<div class="ip-row">Type <b>' + SB.MODES[s.mode].label + (s.real ? ' · real station' : '') + '</b></div>' +
        '<div class="ip-row">Boardings <b>' + SB.fmtInt(boardings) + '/day</b></div>' +
        '<div class="ip-row">Lines <b>' + (lines.length ? lines.map((l) => '<span class="dot" style="background:' + l.color + '"></span>').join('') : 'none yet') + '</b></div>' +
        '<div class="ip-row">Area <b>' + (SB.game.city.districtNameAt(s.x, s.y) || '—') + '</b></div>' +
        '<div class="ip-actions"><button id="ip-demolish" class="danger">' + ic('trash') + 'Demolish</button></div>';
      panel.style.display = 'block';
      $('ip-close').onclick = () => { ui.selection = null; ui.updateAll(); };
      $('ip-demolish').onclick = () => {
        const r = SB.game.removeStation(s.id);
        if (r.ok) ui.toast(s.name + ' demolished · ' + SB.fmtMoney(r.refund) + ' refunded');
        ui.selection = null;
        doAction(r);
      };
    } else if (sel.type === 'line') {
      const line = SB.game.lineById(sel.id);
      if (!line) { ui.selection = null; panel.style.display = 'none'; return; }
      const M = SB.MODES[line.mode];
      const lenM = SB.game.lineLengthM(line);
      const headway = SB.sim.headwayMin(line);
      const riders = res ? res.lineRiders.get(line.id) || 0 : 0;
      const ratio = res ? res.lineMaxRatio.get(line.id) || 0 : 0;
      const delay = SB.sim.lineDelayFor(line.id);
      const crowdCls = ratio > 1.05 ? 'bad' : ratio > 0.85 ? 'warn' : 'good';
      panel.innerHTML =
        '<div class="ip-head"><span class="dot big" style="background:' + line.color + '"></span>' +
        '<span class="ip-title">' + line.name + '</span>' +
        '<button class="mini ghostbtn" id="ip-close">' + ic('x') + '</button></div>' +
        '<div class="ip-row">Mode <b>' + M.label + ' · ' + M.speedKmh + ' km/h</b></div>' +
        '<div class="ip-row">Stops <b>' + line.stationIds.length + '</b> · length <b>' + SB.fmtKm(lenM) + '</b></div>' +
        '<div class="ip-row">Fleet <b>' + line.vehicles + ' ' + M.vehicle + 's</b> · headway <b>' + (isFinite(headway) ? headway.toFixed(1) + ' min' : '—') + '</b></div>' +
        '<div class="ip-row">Riders <b>' + SB.fmtInt(riders) + '/day</b></div>' +
        '<div class="ip-row">Peak crowding <b class="' + crowdCls + '">' + Math.round(ratio * 100) + '%</b>' +
        (delay > 1.02 ? ' <span class="warn">delays ×' + delay.toFixed(2) + '</span>' : '') + '</div>' +
        '<div class="ip-actions">' +
        '<button id="ip-veh">' + ic('plus') + M.vehicle.charAt(0).toUpperCase() + M.vehicle.slice(1) + ' · ' + SB.fmtMoney(M.vehicleCost) + '</button>' +
        '<button id="ip-extend">' + ic('route') + 'Extend</button>' +
        '<button id="ip-delete" class="danger">' + ic('trash') + 'Delete</button></div>';
      panel.style.display = 'block';
      $('ip-close').onclick = () => { ui.selection = null; ui.updateAll(); };
      $('ip-veh').onclick = () => doAction(SB.game.addVehicle(line.id));
      $('ip-extend').onclick = () => {
        ui.setMode(line.mode);
        ui.setTool('line');
        ui.beginDraftFrom(line.id);
        ui.updateDraftHint();
      };
      $('ip-delete').onclick = () => {
        ui.confirm('Delete ' + line.name + '?', 'You get 25% of construction plus vehicle resale back.', () => {
          const r = SB.game.deleteLine(line.id);
          if (r.ok) ui.toast(line.name + ' removed · ' + SB.fmtMoney(r.refund) + ' refunded');
          ui.selection = null;
          doAction(r);
        });
      };
    }
  }

  // ── Modals ───────────────────────────────────────────────────────────
  function openModal(html, wide) {
    const back = $('modalback');
    $('modal').innerHTML = html;
    $('modal').classList.toggle('wide', !!wide);
    back.style.display = 'flex';
  }
  ui.closeModal = function () { $('modalback').style.display = 'none'; };

  ui.confirm = function (title, sub, onYes) {
    openModal(
      '<h2>' + title + '</h2><p class="sub">' + sub + '</p>' +
      '<div class="mrow"><button id="m-no">Cancel</button>' +
      '<button id="m-yes" class="danger">Confirm</button></div>'
    );
    $('m-yes').onclick = () => { ui.closeModal(); onYes(); };
    $('m-no').onclick = ui.closeModal;
  };

  // ── Location picker ──────────────────────────────────────────────────
  const FEATURED = [
    { name: 'New York', country: 'United States', lng: -73.985, lat: 40.735 },
    { name: 'Chicago', country: 'United States', lng: -87.63, lat: 41.878 },
    { name: 'San Francisco', country: 'United States', lng: -122.42, lat: 37.774 },
    { name: 'London', country: 'United Kingdom', lng: -0.118, lat: 51.51 },
    { name: 'Paris', country: 'France', lng: 2.347, lat: 48.859 },
    { name: 'Amsterdam', country: 'Netherlands', lng: 4.9, lat: 52.37 },
    { name: 'Berlin', country: 'Germany', lng: 13.404, lat: 52.52 },
    { name: 'Tokyo', country: 'Japan', lng: 139.77, lat: 35.68 },
  ];

  function placeFrom(name, lng, lat) {
    return { id: SB.placeId(lng, lat), name, lng, lat };
  }

  ui.showPlacePicker = function (allowClose) {
    const saved = SB.game.savedGames();
    let savedHtml = '';
    if (saved.length) {
      savedHtml = '<h3>Your cities</h3><div class="citygrid">' + saved.map((s) =>
        '<div class="citycard" data-save="' + s.id + '">' +
        '<div class="cc-head"><b>' + s.place.name + '</b><span class="pill">Day ' + s.day + '</span></div>' +
        '<div class="cc-meta">' + s.lines + ' lines · ' + s.stations + ' stops</div>' +
        '<div class="cc-save">Continue · <a href="#" class="cc-del" data-save="' + s.id + '">delete save</a></div>' +
        '</div>').join('') + '</div>';
    }
    openModal(
      '<div class="brandrow">' + ic('metro', 'brandmark') + '<span class="brand">Subway Builder</span>' +
      '<span class="sub">Pick any real place on Earth and build the transit it deserves</span></div>' +
      '<div class="searchrow"><input type="text" id="place-q" placeholder="Search any city, town or address…">' +
      '<button id="place-go" class="primary">Search</button></div>' +
      '<div id="place-results"></div>' +
      savedHtml +
      '<h3>Featured cities</h3><div class="citygrid">' + FEATURED.map((c, i) =>
        '<div class="citycard" data-feat="' + i + '">' +
        '<div class="cc-head"><b>' + c.name + '</b></div>' +
        '<div class="cc-meta">' + c.country + '</div>' +
        '</div>').join('') + '</div>' +
      (allowClose ? '<div class="mrow"><button id="m-close">Back to the map</button></div>' : ''),
      true
    );

    document.querySelectorAll('[data-feat]').forEach((el) => {
      el.addEventListener('click', () => {
        const c = FEATURED[+el.getAttribute('data-feat')];
        ui.closeModal();
        SB.main.startPlace(placeFrom(c.name, c.lng, c.lat), false);
      });
    });
    document.querySelectorAll('[data-save]').forEach((el) => {
      if (el.classList.contains('cc-del')) return;
      el.addEventListener('click', (e) => {
        if (e.target.classList.contains('cc-del')) return;
        const entry = SB.game.savedEntry(el.getAttribute('data-save'));
        if (entry) { ui.closeModal(); SB.main.startPlace(entry.place, false); }
      });
    });
    document.querySelectorAll('.cc-del').forEach((el) => {
      el.addEventListener('click', (e) => {
        e.preventDefault(); e.stopPropagation();
        SB.game.deleteSave(el.getAttribute('data-save'));
        ui.showPlacePicker(allowClose);
      });
    });

    async function doSearch() {
      const q = $('place-q').value.trim();
      if (!q) return;
      $('place-results').innerHTML = '<div class="sub" style="padding:8px 2px">Searching…</div>';
      try {
        const r = await fetch('https://photon.komoot.io/api/?q=' + encodeURIComponent(q) + '&limit=6&lang=en');
        const data = await r.json();
        const feats = (data.features || []).filter((f) => f.geometry && f.geometry.type === 'Point');
        if (!feats.length) {
          $('place-results').innerHTML = '<div class="sub" style="padding:8px 2px">No places found.</div>';
          return;
        }
        $('place-results').innerHTML = '<div class="citygrid">' + feats.map((f, i) => {
          const p = f.properties || {};
          const ctx = [p.city, p.state, p.country].filter((v) => v && v !== p.name).join(', ');
          return '<div class="citycard" data-res="' + i + '">' +
            '<div class="cc-head"><b>' + (p.name || q) + '</b></div>' +
            '<div class="cc-meta">' + (ctx || p.osm_value || '') + '</div></div>';
        }).join('') + '</div>';
        document.querySelectorAll('[data-res]').forEach((el) => {
          el.addEventListener('click', () => {
            const f = feats[+el.getAttribute('data-res')];
            const [lng, lat] = f.geometry.coordinates;
            ui.closeModal();
            SB.main.startPlace(placeFrom(f.properties.name || q, lng, lat), false);
          });
        });
      } catch (err) {
        $('place-results').innerHTML = '<div class="sub" style="padding:8px 2px">Search failed — check your internet connection.</div>';
      }
    }
    $('place-go').onclick = doSearch;
    $('place-q').addEventListener('keydown', (e) => { if (e.key === 'Enter') doSearch(); });
    $('place-q').focus();
    if (allowClose) $('m-close').onclick = ui.closeModal;
  };

  ui.showHelp = function () {
    openModal(
      '<h2>How to play</h2>' +
      '<div class="helpgrid">' +
      '<div><b>1 · Read the city</b><p>This is the real city from OpenStreetMap — zoom in for 3D buildings. The <i>Residents</i> and <i>Jobs</i> views (estimated from real land use) show where people live and work.</p></div>' +
      '<div><b>2 · Pick a mode</b><p><i>Metro</i> bores tunnels anywhere. <i>Tram</i> and <i>Bus</i> stops snap to streets and their routes follow real roads and bridges. <i>Trains</i> only call at real stations and run on tracks that really exist.</p></div>' +
      '<div><b>3 · Build stops &amp; lines</b><p>Place stops with <kbd>S</kbd>, connect them with <kbd>L</kbd>, finish with <kbd>Enter</kbd>. Metro under rivers costs 2.6× for tunnelling; surface modes must find a real street route.</p></div>' +
      '<div><b>4 · Run the fleet</b><p>Every line starts with two vehicles. More vehicles mean shorter waits and more capacity — watch the crowding flags before riders give up.</p></div>' +
      '<div><b>5 · Win commuters</b><p>Each simulated commuter weighs walking, waiting, riding, transfers and fares against driving, door to door. Your score is the <b>transit share</b>.</p></div>' +
      '<div><b>6 · Fund it</b><p>Fares plus a daily subsidy cover operations; every 30 days a fresh <i>capital budget</i> arrives. Milestones bring bonus grants — loans are there if you dare.</p></div>' +
      '</div>' +
      '<p class="sub">Shortcuts — <kbd>V</kbd> select · <kbd>S</kbd> stop · <kbd>L</kbd> line · <kbd>B</kbd> bulldoze · <kbd>1</kbd>–<kbd>4</kbd> mode · <kbd>Space</kbd> pause · <kbd>Esc</kbd> cancel</p>' +
      '<div class="mrow"><button id="m-close" class="primary">Let’s build</button></div>',
      true
    );
    $('m-close').onclick = () => {
      ui.closeModal();
      SB.game.state.helpSeen = true;
      SB.game.save();
    };
  };

  ui.showStats = function () {
    const st = SB.game.state;
    const res = SB.sim.results;
    const hist = st.history;
    let totalKm = 0, totalVeh = 0;
    for (const l of st.lines) { totalKm += SB.game.lineLengthM(l) / 1000; totalVeh += l.vehicles; }

    let topStations = '';
    if (res) {
      const rows = [...res.boardings.entries()].sort((a, b) => b[1] - a[1]).slice(0, 6);
      for (const [id, n] of rows) {
        const s = SB.game.stationById(id);
        if (s) topStations += '<tr><td>' + s.name + '</td><td>' + SB.fmtInt(n) + '</td></tr>';
      }
    }
    const share = res ? res.share : 0, car = res ? res.carShare : 0;
    let modeSplit = '';
    if (res && res.ridersDaily > 1) {
      modeSplit = '<h3>Boardings by mode</h3><div class="modebars">' +
        Object.entries(res.modeRiders).filter(([, v]) => v > 0.5).map(([m, v]) =>
          '<div class="modebar"><span class="mb-label">' + ic(MODE_ICON[m]) + SB.MODES[m].label + '</span>' +
          '<span class="mb-track"><span style="width:' + Math.min(100, (v / res.ridersDaily) * 100) + '%;background:' + MODE_TINT[m] + '"></span></span>' +
          '<span class="mb-val">' + SB.fmtInt(v) + '</span></div>').join('') + '</div>';
    }

    openModal(
      '<h2>Network analysis</h2>' +
      '<div class="statgrid">' +
      stat('Transit share', (share * 100).toFixed(1) + '%') +
      stat('Daily riders', res ? SB.fmtInt(res.ridersDaily) : '—') +
      stat('Coverage', res ? Math.round(res.coverage * 100) + '%' : '—', 'residents near a stop') +
      stat('Transfers', res ? SB.fmtInt(res.transfersDaily) + '/day' : '—') +
      stat('Avg transit trip', res && res.avgTransitMin ? res.avgTransitMin.toFixed(0) + ' min' : '—') +
      stat('Avg car trip', res && res.avgCarMin ? res.avgCarMin.toFixed(0) + ' min' : '—') +
      stat('Route length', totalKm.toFixed(1) + ' km') +
      stat('Stops', st.stations.length) +
      stat('Fleet', totalVeh) +
      stat('Spent to date', SB.fmtMoney(st.totalSpent)) +
      '</div>' +
      '<div class="modesplit"><div class="ms-bar">' +
      '<span style="width:' + (share * 100) + '%;background:var(--accent)"></span>' +
      '<span style="width:' + (car * 100) + '%;background:#616b7d"></span></div>' +
      '<div class="ms-legend"><span><i style="background:var(--accent)"></i>Transit ' + (share * 100).toFixed(1) + '%</span>' +
      '<span><i style="background:#616b7d"></i>Driving ' + (car * 100).toFixed(1) + '%</span></div></div>' +
      modeSplit +
      '<div class="chartrow">' +
      '<div><h3>Daily riders</h3><canvas id="ch-riders" width="290" height="90"></canvas></div>' +
      '<div><h3>Transit share %</h3><canvas id="ch-share" width="290" height="90"></canvas></div>' +
      '<div><h3>Treasury</h3><canvas id="ch-money" width="290" height="90"></canvas></div>' +
      '</div>' +
      (topStations ? '<h3>Busiest stops</h3><table class="stbl">' + topStations + '</table>' : '') +
      '<div class="mrow"><button id="m-close">Close</button></div>',
      true
    );
    $('m-close').onclick = ui.closeModal;
    drawChart($('ch-riders'), hist.map((h) => h.riders), '#4da3ff', SB.fmtInt);
    drawChart($('ch-share'), hist.map((h) => h.share * 100), '#4ecb71', (v) => v.toFixed(1) + '%');
    drawChart($('ch-money'), hist.map((h) => h.money), '#f3b13e', SB.fmtMoney);
  };

  function stat(label, val, sub) {
    return '<div class="stat"><div class="v">' + val + '</div><div class="l">' + label + (sub ? ' <i>(' + sub + ')</i>' : '') + '</div></div>';
  }

  function drawChart(canvas, values, color, fmt) {
    if (!canvas) return;
    const c = canvas.getContext('2d');
    const W = canvas.width, H = canvas.height;
    c.clearRect(0, 0, W, H);
    if (values.length < 2) {
      c.fillStyle = '#8b96a8';
      c.font = '11px "Segoe UI", sans-serif';
      c.fillText('Play a few days for data…', 8, H / 2);
      return;
    }
    const min = Math.min(...values), max = Math.max(...values);
    const range = max - min || 1;
    const px = (i) => 4 + (i / (values.length - 1)) * (W - 8);
    const py = (v) => H - 14 - ((v - min) / range) * (H - 26);
    c.beginPath();
    values.forEach((v, i) => (i ? c.lineTo(px(i), py(v)) : c.moveTo(px(i), py(v))));
    c.strokeStyle = color;
    c.lineWidth = 2;
    c.lineJoin = 'round';
    c.stroke();
    c.lineTo(px(values.length - 1), H - 2);
    c.lineTo(px(0), H - 2);
    c.closePath();
    c.globalAlpha = 0.12;
    c.fillStyle = color;
    c.fill();
    c.globalAlpha = 1;
    c.fillStyle = '#8b96a8';
    c.font = '10px "Segoe UI", sans-serif';
    c.fillText(fmt(values[values.length - 1]), 6, 10);
  }

  // ── Static wiring ────────────────────────────────────────────────────
  ui.init = function () {
    for (const m of Object.keys(SB.MODES)) {
      $('mode-' + m).addEventListener('click', () => ui.setMode(m));
    }
    for (const t of ['select', 'station', 'line', 'bulldoze']) {
      $('tool-' + t).addEventListener('click', () => ui.setTool(t));
    }
    for (const o of ['pop', 'jobs', 'access', 'load']) {
      $('ov-' + o).addEventListener('click', () => ui.setOverlay(o));
    }
    document.querySelectorAll('#speedctl button').forEach((b, i) => {
      b.addEventListener('click', () => ui.setSpeed(i));
    });
    $('btn-stats').addEventListener('click', ui.showStats);
    $('btn-help').addEventListener('click', ui.showHelp);
    $('btn-cities').addEventListener('click', () => ui.showPlacePicker(true));
    $('btn-3d').addEventListener('click', () => {
      const on = !$('btn-3d').classList.contains('active');
      $('btn-3d').classList.toggle('active', on);
      SB.map3d.setPitch3D(on);
    });
    $('btn-newline').addEventListener('click', () => {
      ui.setTool('line');
      ui.beginDraftFrom(null);
      ui.updateDraftHint();
    });
    $('fare-minus').addEventListener('click', () => { SB.game.setFare(SB.game.state.fare - 0.25); });
    $('fare-plus').addEventListener('click', () => { SB.game.setFare(SB.game.state.fare + 0.25); });
    $('btn-loan').addEventListener('click', () => {
      ui.confirm('Take a ' + SB.fmtMoney(SB.ECON.loanAmount) + ' loan?',
        'Interest accrues daily at 0.06% of the outstanding amount.', () => {
          SB.game.takeLoan();
          ui.toast(SB.fmtMoney(SB.ECON.loanAmount) + ' loan received');
        });
    });
    $('btn-repay').addEventListener('click', () => doAction(SB.game.repayLoan()));
    $('modalback').addEventListener('mousedown', (e) => {
      if (e.target === $('modalback') && $('m-close')) ui.closeModal();
    });
  };
})();
