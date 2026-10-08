/* Subway Builder — DOM chrome: HUD, toolbar, panels, modals, toasts. */
(function () {
  'use strict';
  const SB = (window.SB = window.SB || {});
  const $ = (id) => document.getElementById(id);
  const translate = (source) => window.LumaSceneI18n.translate(source);
  const format = (key, values = {}) => window.LumaSceneI18n.format(key, values);
  const escapeHtml = (value) => String(value).replace(/[&<>"']/g, (c) => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c]));
  const localizedWeekday = (shortName) => {
    const index = {Mon: 0, Tue: 1, Wed: 2, Thu: 3, Fri: 4, Sat: 5, Sun: 6}[shortName];
    if (index === undefined) return translate(shortName);
    return new Intl.DateTimeFormat(window.LumaSceneI18n.language, {weekday: 'short', timeZone: 'UTC'})
      .format(new Date(Date.UTC(2024, 0, 1 + index)));
  };

  const ui = (SB.ui = {
    tool: 'select',        // select | station | line | bulldoze
    mode: 'metro',         // metro | tram | bus | train
    overlay: null,         // null | pop | jobs | access | load
    selection: null,
    draftIds: [],
    draftLineId: null,
    speed: 1,
  });

  // minPerSec: in-game minutes per real second. 1× is the "1 second = 1
  // minute" base rate, so a full day takes 24 real minutes at 1×.
  const SPEEDS = [
    { label: 'pause', mult: 0, minPerSec: 0 },
    { label: '1×', mult: 1, minPerSec: 1 },
    { label: '6×', mult: 2, minPerSec: 6 },
    { label: '30×', mult: 4, minPerSec: 30 },
  ];
  ui.SPEEDS = SPEEDS;

  function ic(name, cls) {
    return '<svg class="ic' + (cls ? ' ' + cls : '') + '" aria-hidden="true"><use href="#i-' + name + '"/></svg>';
  }
  ui.ic = ic;

  const MODE_ICON = { metro: 'metro', tram: 'tram', bus: 'bus', train: 'train', hst: 'hst' };
  const LINE_COLOR_KEYS = {
    '#e6493f': 'sceneSubwayLineColorRed', '#2f6fdb': 'sceneSubwayLineColorBlue',
    '#2e9e4f': 'sceneSubwayLineColorGreen', '#f28c28': 'sceneSubwayLineColorOrange',
    '#8e4fc7': 'sceneSubwayLineColorPurple', '#e8c11c': 'sceneSubwayLineColorYellow',
    '#18a999': 'sceneSubwayLineColorTeal', '#e05a9b': 'sceneSubwayLineColorPink',
    '#7aa711': 'sceneSubwayLineColorLime', '#5058c8': 'sceneSubwayLineColorIndigo',
    '#b9791a': 'sceneSubwayLineColorAmber', '#12a5c9': 'sceneSubwayLineColorCyan',
  };
  const ACHIEVEMENT_KEYS = {
    first1k: 'CommuterFavourite', riders25k: 'CityMover', riders100k: 'MetropolisMachine',
    st10: 'NetworkEffect', st40: 'EveryCorner', km50: 'GoingDistance', km250: 'SteelSpine',
    allmodes: 'FullSpectrum', water: 'UnderRiver', intercity: 'IntercityExpress',
    airport: 'AirportLink', ring: 'RingLine', bullet: 'BulletService',
    nightowl: 'CityNeverSleeps', profit: 'InTheBlack',
  };
  const MILESTONE_KEYS = [
    'sceneSubwayMilestoneCityHall', 'sceneSubwayMilestoneStateGrant',
    'sceneSubwayMilestoneFederalGrant', 'sceneSubwayMilestoneTransitCityAward',
    'sceneSubwayMilestoneWorldMetroFund', 'sceneSubwayMilestoneTransitCapital',
  ];
  const MODE_TINT = { metro: '#e05252', tram: '#2e9e4f', bus: '#f2a33c', train: '#7a6ff0', hst: '#d452c4' };
  ui.MODE_TINT = MODE_TINT;
  ui.lineDisplayName = function (line) {
    const colorLabel = Object.keys(LINE_COLOR_KEYS).find((hex) => hex === line.color);
    const mode = SB.MODES[line.mode];
    if (!colorLabel || !mode) return line.name;
    const colorNames = {
      '#e6493f': 'Red', '#2f6fdb': 'Blue', '#2e9e4f': 'Green', '#f28c28': 'Orange',
      '#8e4fc7': 'Purple', '#e8c11c': 'Yellow', '#18a999': 'Teal', '#e05a9b': 'Pink',
      '#7aa711': 'Lime', '#5058c8': 'Indigo', '#b9791a': 'Amber', '#12a5c9': 'Cyan',
    };
    const original = colorNames[colorLabel] + ' ' + mode.label;
    if (line.name !== original) return line.name;
    return window.LumaSceneI18n.value(LINE_COLOR_KEYS[colorLabel]) + ' ' +
      window.LumaSceneI18n.translate(mode.label);
  };
  ui.achievementLabel = (id, suffix = '') => {
    const key = ACHIEVEMENT_KEYS[id];
    return key ? window.LumaSceneI18n.value('sceneSubwayAchievement' + key + suffix) : '';
  };
  ui.milestoneLabel = (share) => {
    const index = [0.03, 0.06, 0.10, 0.15, 0.22, 0.30].indexOf(share);
    return index < 0 ? '' : window.LumaSceneI18n.value(MILESTONE_KEYS[index]);
  };

  // ── Toasts & banners ─────────────────────────────────────────────────
  ui.toast = function (msg, kind) {
    msg = translate(String(msg));
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
    title = translate(title);
    sub = translate(sub);
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
      SB.map3d.setRailMode(SB.isRailMode(ui.mode) && (ui.tool === 'station' || ui.tool === 'line'), ui.mode);
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
      select: window.LumaSceneI18n.value('sceneSubwayUiSelectHint'),
      station: SB.isRailMode(ui.mode)
        ? format('sceneSubwayUiRailStationHint', {mode: translate(M.label)})
        : ui.mode === 'metro'
          ? window.LumaSceneI18n.value('sceneSubwayUiMetroStationHint')
          : format('sceneSubwayUiStreetStationHint', {mode: translate(M.label)}),
      line: SB.isRailMode(ui.mode)
        ? window.LumaSceneI18n.value('sceneSubwayUiRailLineHint')
        : ui.mode === 'metro'
          ? window.LumaSceneI18n.value('sceneSubwayUiMetroLineHint')
          : window.LumaSceneI18n.value('sceneSubwayUiStreetLineHint'),
      bulldoze: window.LumaSceneI18n.value('sceneSubwayUiBulldozeHint'),
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
    $('hint').textContent = text ? translate(text) : '';
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
            ? format('sceneSubwayUiExtendNextStop', {line: ui.lineDisplayName(line)})
            : format('sceneSubwayUiExtendNewStop', {line: ui.lineDisplayName(line)}))
        : '');
      return;
    }
    if (!ui.draftIds.length) {
      ui.hintForTool();
    } else {
      const d = SB.game.draftCost(ui.mode, ui.draftIds);
      if (d.err) { ui.hint(d.err); return; }
      const template = d.waterM > 0 ? 'sceneSubwayUiDraftCostWater' : 'sceneSubwayUiDraftCost';
      ui.hint(format(template, {count: ui.draftIds.length, distance: SB.fmtKm(d.len), cost: SB.fmtMoney(d.cost)}));
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

    $('cityname').dataset.lumaUserContent = 'true';
    $('cityname').textContent = g.city.def.name;
    if (SB.map3d.ready) {
      SB.map3d.updateNetwork(ui.mapState());
      if (ui.overlay === 'access') SB.map3d.setOverlay('access');
      refreshRailHighlight();
    }
    $('stat-money').textContent = SB.fmtMoney(g.state.money);
    $('stat-money').classList.toggle('neg', g.state.money < 0);
    $('stat-riders').textContent = res ? SB.fmtInt(res.ridersDaily) : '—';
    $('stat-share').textContent = res ? (res.share * 100).toFixed(1) + '%' : '—';
    ui.updateClock();

    renderLineList();
    renderInfoPanel();
    renderFinance();
  };

  // ── World clock / weather HUD ────────────────────────────────────────
  ui.updateClock = function () {
    const g = SB.game;
    if (!g.state || !SB.world) return;
    SB.world.ensure();
    const season = SB.world.season();
    $('stat-day').textContent = format('sceneSubwayUiClockDay', {day: SB.world.day(), weekday: localizedWeekday(SB.world.weekday())}) +
      ' · ' + season.emoji;
    $('stat-time').textContent = SB.world.timeString() +
      (SB.world.isRushHour() ? ' 🔺 ' + window.LumaSceneI18n.value('sceneSubwayUiRushHour') : SB.world.isNight() ? ' 🌙 ' + window.LumaSceneI18n.value('sceneSubwayUiNight') : '');
    $('stat-clock').title = translate(season.label) + ' · ' + format('sceneSubwayUiClockDay', {day: SB.world.day(), weekday: localizedWeekday(SB.world.weekday())});
    const w = SB.world.weatherInfo();
    $('weather-emoji').textContent = w.emoji;
    $('stat-weather-label').textContent = translate(w.label);
    $('stat-weather').title = translate(w.label) +
      (w.surface > 1 ? ' ' + format('sceneSubwayUiSurfaceSlowdown', {factor: w.surface.toFixed(2)}) : '');

    const badge = $('ach-badge');
    const newCount = g.state.achievementsHit.length - g.state.achievementsSeen;
    badge.textContent = newCount;
    badge.style.display = newCount > 0 ? 'block' : 'none';

    const coopBtn = $('btn-coop');
    coopBtn.classList.toggle('active', SB.mp.connected);
    coopBtn.lastChild.textContent = SB.mp.connected ? SB.mp.roomCode : translate('Co-op');
  };

  // ── Achievements ─────────────────────────────────────────────────────
  ui.showAchievements = function () {
    ui._localeRefresh = () => ui.showAchievements();
    const st = SB.game.state;
    const rows = SB.ACHIEVEMENTS.map((a) => {
      const done = st.achievementsHit.includes(a.id);
      return '<div class="achrow' + (done ? ' done' : '') + '">' +
        ic(done ? 'trophy' : 'trophy') +
        '<span class="at"><b>' + ui.achievementLabel(a.id) + '</b><span>' + ui.achievementLabel(a.id, 'Sub') + '</span></span>' +
        '<span class="av">' + (done ? translate('Unlocked') : SB.fmtMoney(a.grant)) + '</span></div>';
    }).join('');
    const doneCount = st.achievementsHit.length;
    openModal(
      '<h2>' + translate('Achievements') + '</h2><p class="sub">' + escapeHtml(format('sceneSubwayUiAchievementSummary', {done: doneCount, total: SB.ACHIEVEMENTS.length})) + '</p>' +
      '<div class="achlist">' + rows + '</div>' +
      '<div class="mrow"><button id="m-close">Close</button></div>',
      true
    );
    st.achievementsSeen = st.achievementsHit.length;
    SB.game.save();
    ui.updateClock();
    $('m-close').onclick = ui.closeModal;
  };

  function renderFinance() {
    const st = SB.game.state;
    $('fare-val').textContent = '$' + st.fare.toFixed(2);
    $('loan-out').textContent = st.loans > 0 ? format('sceneSubwayUiLoanOwed', {amount: SB.fmtMoney(st.loans)}) : window.LumaSceneI18n.value('sceneSubwayUiNoDebt');
    $('btn-repay').disabled = st.loans <= 0;
    $('funding-line').textContent = format('sceneSubwayUiFundingSubsidy', {amount: SB.fmtMoney(SB.game.city.def.funding)});
  }

  function renderLineList() {
    const st = SB.game.state;
    const res = SB.sim.results;
    const wrap = $('linelist');
    wrap.innerHTML = '';
    if (!st.lines.length) {
      const d = document.createElement('div');
      d.className = 'empty';
      d.textContent = translate('No lines yet. Pick a mode, place stops, then connect them with the Line tool.');
      wrap.appendChild(d);
    }
    for (const line of st.lines) {
      const row = document.createElement('div');
      const disruption = SB.world ? SB.world.disruptionFor(line.id) : null;
      row.className = 'linerow' + (disruption ? ' disrupted' : '');
      const selected = ui.selection && ui.selection.type === 'line' && ui.selection.id === line.id;
      if (selected) row.classList.add('sel');
      const riders = res ? res.lineRiders.get(line.id) || 0 : 0;
      const ratio = res ? res.lineMaxRatio.get(line.id) || 0 : 0;
      const revenue = riders * st.fare;
      const isLoop = SB.isLoopLine(line);
      const stopCount = line.stationIds.length - (isLoop ? 1 : 0);
      const M = SB.MODES[line.mode];
      row.innerHTML =
        '<span class="sw" style="background:' + line.color + '">' + ic(MODE_ICON[line.mode]) + '</span>' +
        '<span class="lcol"><span class="lname" data-luma-user-content>' + escapeHtml(ui.lineDisplayName(line)) + '</span>' +
        '<span class="lmeta">' + stopCount + ' ' + translate('stops') + (isLoop ? ' · ' + translate('loop') : '') + ' · ' + SB.fmtInt(riders) + '/d · ' + SB.fmtMoney(revenue) + '/d' +
        (ratio > 1.05 ? ' · <b class="bad">' + translate('crowded') + '</b>' : '') +
        (disruption ? ' · <b class="dis-flag">' + escapeHtml(translate(disruption.label)) + '</b>' : '') + '</span></span>' +
        '<span class="tctl">' +
        '<button class="mini" data-act="vminus" title="' + escapeHtml(window.LumaSceneI18n.value('sceneSubwayVehicleSellTitle')) + '">' + ic('minus') + '</button>' +
        '<span class="tcount">' + line.vehicles + '</span>' +
        '<button class="mini" data-act="vplus" title="' + escapeHtml(window.LumaSceneI18n.value('sceneSubwayVehicleBuyTitle')) + '">' + ic('plus') + '</button>' +
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
        '<span class="ip-title" data-luma-user-content>' + escapeHtml(s.name) + '</span>' +
        '<button class="mini ghostbtn" id="ip-close">' + ic('x') + '</button></div>' +
        '<div class="ip-row">' + translate('Type') + ' <b>' + escapeHtml(translate(SB.MODES[s.mode].label)) + (s.real ? ' · ' + translate('real station') : '') + '</b></div>' +
        '<div class="ip-row">' + escapeHtml(format('sceneSubwayUiBoardings', {count: SB.fmtInt(boardings)})) + '</div>' +
        '<div class="ip-row">' + translate('Lines') + ' <b>' + (lines.length ? lines.map((l) => '<span class="dot" style="background:' + l.color + '"></span>').join('') : translate('none yet')) + '</b></div>' +
        '<div class="ip-row">' + translate('Area') + ' <b data-luma-user-content>' + escapeHtml(SB.game.city.districtNameAt(s.x, s.y) || '—') + '</b></div>' +
        '<div class="ip-actions"><button id="ip-demolish" class="danger">' + ic('trash') + translate('Demolish') + '</button></div>';
      panel.style.display = 'block';
      $('ip-close').onclick = () => { ui.selection = null; ui.updateAll(); };
      $('ip-demolish').onclick = () => {
        const r = SB.game.removeStation(s.id);
        if (r.ok) ui.toast(window.LumaSceneI18n.format('sceneSubwayStationDemolished', {station: s.name, refund: SB.fmtMoney(r.refund)}));
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
      const isLoop = SB.isLoopLine(line);
      const stopCount = line.stationIds.length - (isLoop ? 1 : 0);
      const disruption = SB.world ? SB.world.disruptionFor(line.id) : null;
      const modeLabel = translate(M.label);
      const vehicleLabel = translate(M.vehicle);
      panel.innerHTML =
        '<div class="ip-head"><span class="dot big" style="background:' + line.color + '"></span>' +
        '<span class="ip-title" data-luma-user-content>' + escapeHtml(ui.lineDisplayName(line)) + (isLoop ? ' <span class="pill">' + translate('loop') + '</span>' : '') + '</span>' +
        '<button class="mini ghostbtn" id="ip-close">' + ic('x') + '</button></div>' +
        '<div class="ip-row">' + escapeHtml(format('sceneSubwayLinePanelModeSpeed', {mode: modeLabel, speed: M.speedKmh + ' km/h'})) + '</div>' +
        '<div class="ip-row">' + escapeHtml(format('sceneSubwayLinePanelStopsLength', {count: stopCount, length: SB.fmtKm(lenM)})) + '</div>' +
        '<div class="ip-row">' + escapeHtml(format('sceneSubwayLinePanelFleetHeadway', {count: line.vehicles, vehicle: vehicleLabel, headway: isFinite(headway) ? headway.toFixed(1) + ' min' : '—'})) + '</div>' +
        '<div class="ip-row">' + escapeHtml(format('sceneSubwayLinePanelRidersRevenue', {count: SB.fmtInt(riders), revenue: SB.fmtMoney(riders * SB.game.state.fare)})) + '</div>' +
        '<div class="ip-row">' + escapeHtml(format('sceneSubwayLinePanelPeakCrowding', {percent: Math.round(ratio * 100)})) +
        (delay > 1.02 ? ' <span class="warn">' + escapeHtml(format('sceneSubwayLinePanelDelays', {factor: delay.toFixed(2)})) + '</span>' : '') + '</div>' +
        (disruption ? '<div class="ip-row"><b class="bad">⚠ ' + escapeHtml(format('sceneSubwayLinePanelDisruption', {label: translate(disruption.label)})) + '</b></div>' : '') +
        '<div class="ip-row">' + window.LumaSceneI18n.value('sceneSubwayLinePanelServiceWindow') +
        '<div class="svctoggle">' +
        '<button class="mini' + (line.nightService ? ' active' : ' off') + '" id="ip-night" title="' + escapeHtml(translate('Toggle overnight (22:00–05:00) service')) + '">' + ic('moonwave') + window.LumaSceneI18n.value('sceneSubwayLinePanelNight') + '</button>' +
        '<button class="mini' + (line.weekendService ? ' active' : ' off') + '" id="ip-weekend" title="' + escapeHtml(translate('Toggle weekend service')) + '">' + ic('week') + window.LumaSceneI18n.value('sceneSubwayLinePanelWeekend') + '</button>' +
        '</div></div>' +
        '<div class="ip-actions">' +
        '<button id="ip-veh" title="' + escapeHtml(window.LumaSceneI18n.value('sceneSubwayVehicleBuyTitle')) + '">' + ic('plus') + escapeHtml(vehicleLabel) + ' · ' + SB.fmtMoney(M.vehicleCost) + '</button>' +
        '<button id="ip-extend">' + ic('route') + window.LumaSceneI18n.value('sceneSubwayLinePanelExtend') + '</button>' +
        '<button id="ip-delete" class="danger">' + ic('trash') + translate('Delete') + '</button></div>';
      panel.style.display = 'block';
      $('ip-close').onclick = () => { ui.selection = null; ui.updateAll(); };
      $('ip-night').onclick = () => doAction(SB.game.setLineService(line.id, 'night', !line.nightService));
      $('ip-weekend').onclick = () => doAction(SB.game.setLineService(line.id, 'weekend', !line.weekendService));
      $('ip-veh').onclick = () => doAction(SB.game.addVehicle(line.id));
      $('ip-extend').onclick = () => {
        ui.setMode(line.mode);
        ui.setTool('line');
        ui.beginDraftFrom(line.id);
        ui.updateDraftHint();
      };
      $('ip-delete').onclick = () => {
        const confirmDelete = () => ui.confirm(
          escapeHtml(format('sceneSubwayDeleteLineQuestion', {line: ui.lineDisplayName(line)})),
          window.LumaSceneI18n.value('sceneSubwayDeleteLineRefundDetails'),
          () => {
            const r = SB.game.deleteLine(line.id);
            if (r.ok) ui.toast(format('sceneSubwayLineRemoved', {line: ui.lineDisplayName(line), refund: SB.fmtMoney(r.refund)}));
            ui.selection = null;
            doAction(r);
          },
          confirmDelete,
        );
        confirmDelete();
      };
    }
  }

  // ── Co-op ────────────────────────────────────────────────────────────
  function renderCoopSignedOut() {
    ui._localeRefresh = renderCoopSignedOut;
    openModal(
      '<h2>' + translate('Play together') + '</h2>' +
      '<p class="sub">' + translate('Co-op rooms are tied to your luma account — that’s what makes invites and room membership work. Sign in from the app’s account settings, then come back here.') + '</p>' +
      '<div class="mrow"><button id="m-close">' + translate('Close') + '</button></div>'
    );
    $('m-close').onclick = ui.closeModal;
  }

  function renderCoopConnected() {
    ui._localeRefresh = renderCoopConnected;
    const authLine = SB.mp.isClockAuthority
      ? window.LumaSceneI18n.value('sceneSubwayCoopClockYou')
      : window.LumaSceneI18n.value('sceneSubwayCoopClockPeer');
    openModal(
      '<h2>' + escapeHtml(format('sceneSubwayCoopRoomCodeTitle', {code: SB.mp.roomCode})) + '</h2>' +
      '<p class="sub">' + window.LumaSceneI18n.value('sceneSubwayCoopRoomCodeDescription') + '</p>' +
      '<div class="statgrid" style="grid-template-columns:1fr"><div class="stat"><div class="v" data-luma-user-content>' + escapeHtml(SB.mp.roomCode) + '</div><div class="l">' + window.LumaSceneI18n.value('sceneSubwayBuilderRoomCode') + '</div></div></div>' +
      '<p class="sub">' + authLine + '</p>' +
      '<div class="mrow"><button id="cp-invite">' + window.LumaSceneI18n.value('sceneSubwayCoopInviteContact') + '</button></div>' +
      '<div class="mrow"><button id="cp-leave" class="danger">' + translate('Leave room') + '</button><button id="m-close">' + translate('Close') + '</button></div>',
      true
    );
    $('m-close').onclick = ui.closeModal;
    $('cp-leave').onclick = () => { SB.mp.leaveRoom(); ui.closeModal(); ui.toast('Left the co-op room'); };
    $('cp-invite').onclick = renderCoopInvite;
  }

  async function renderCoopInvite() {
    ui._localeRefresh = renderCoopInvite;
    openModal(
      '<h2>' + window.LumaSceneI18n.value('sceneSubwayCoopInviteContact') + '</h2><p class="sub">' + window.LumaSceneI18n.value('sceneSubwayCoopLoadingContacts') + '</p>' +
      '<div class="mrow"><button id="m-close">Back</button></div>', true);
    $('m-close').onclick = renderCoopConnected;
    let contacts = [];
    try { contacts = await SB.mp.chatContacts(); } catch (e) { /* fall through to empty state */ }
    const ready = contacts.filter((c) => c.ready);
    const rows = ready.length
      ? ready.map((c) =>
          '<div class="achrow done" style="opacity:1"><span class="at"><b data-luma-user-content>' + escapeHtml(c.peerEmail) + '</b></span>' +
          '<button class="mini" data-cid="' + escapeHtml(c.conversationId) + '" data-uid="' + escapeHtml(c.peerUserId) + '">' + translate('Invite') + '</button></div>'
        ).join('')
      : '<div class="empty">' + escapeHtml(format('sceneSubwayCoopNoChatContacts', {code: SB.mp.roomCode})) + '</div>';
    openModal(
      '<h2>' + window.LumaSceneI18n.value('sceneSubwayCoopInviteContact') + '</h2>' +
      '<p class="sub">' + window.LumaSceneI18n.value('sceneSubwayCoopInviteInstruction') + '</p>' +
      '<div class="achlist">' + rows + '</div>' +
      '<div class="mrow"><button id="m-close">Back</button></div>',
      true
    );
    $('m-close').onclick = renderCoopConnected;
    document.querySelectorAll('[data-cid]').forEach((btn) => {
      btn.onclick = async () => {
        btn.disabled = true;
        try {
          await SB.mp.inviteContact(SB.mp.roomCode, btn.getAttribute('data-uid'));
          await SB.mp.sendInviteMessage(btn.getAttribute('data-cid'), SB.mp.roomCode);
          ui.toast('Invite sent', 'good');
          renderCoopConnected();
        } catch (e) {
          ui.toast(format('sceneSubwayCouldNotSendInvite', {error: e.message}), 'bad');
          btn.disabled = false;
        }
      };
    });
  }

  async function renderCoopSetup() {
    ui._localeRefresh = renderCoopSetup;
    openModal(
      '<h2>' + window.LumaSceneI18n.value('sceneSubwayCoopCreateRoom') + '</h2><p class="sub">' + window.LumaSceneI18n.value('sceneSubwayCoopLoadingRooms') + '</p>' +
      '<div class="mrow"><button id="m-close">Cancel</button></div>', true);
    $('m-close').onclick = ui.closeModal;
    let rooms = [];
    try { rooms = await SB.mp.myRooms(); } catch (e) { /* fall through to empty list */ }
    const roomRows = rooms.length
      ? rooms.map((r) =>
          '<div class="achrow done" style="opacity:1"><span class="at"><b data-luma-user-content>' + escapeHtml(r.code) + '</b><span>' +
          escapeHtml(r.memberCount === 1 ? format('sceneSubwayCoopMemberCountOne', {count: r.memberCount}) : format('sceneSubwayCoopMemberCountMany', {count: r.memberCount})) + (r.isOwner ? ' · ' + window.LumaSceneI18n.value('sceneSubwayCoopRoomYours') : '') +
          '</span></span><button class="mini" data-rejoin="' + escapeHtml(r.code) + '">' + window.LumaSceneI18n.value('sceneSubwayCoopOpenRoom') + '</button></div>'
        ).join('')
      : '<div class="empty">' + window.LumaSceneI18n.value('sceneSubwayCoopRoomsEmpty') + '</div>';
    openModal(
      '<h2>' + window.LumaSceneI18n.value('sceneSubwayCoopCreateRoom') + '</h2>' +
      '<p class="sub">Build on the same network as friends — invite via chat, or share a room code. Whoever’s connected keeps the clock running; leave and rejoin any time.</p>' +
      (rooms.length ? '<h3>' + translate('Your rooms') + '</h3><div class="achlist">' + roomRows + '</div>' : roomRows) +
      '<div class="mrow" style="margin-top:10px"><button id="cp-create" class="primary">' + window.LumaSceneI18n.value('sceneSubwayCoopCreateRoom') + '</button></div>' +
      '<p class="sub" style="margin-top:14px">' + window.LumaSceneI18n.value('sceneSubwayCoopJoinByCode') + '</p>' +
      '<div class="mrow"><input type="text" id="cp-code" placeholder="' + escapeHtml(window.LumaSceneI18n.value('sceneSubwayBuilderRoomCode')) + '" maxlength="6" style="flex:1;text-transform:uppercase"></div>' +
      '<div class="mrow"><button id="cp-join">' + window.LumaSceneI18n.value('sceneSubwayCoopJoinRoom') + '</button></div>' +
      '<div class="mrow"><button id="m-close">Cancel</button></div>',
      true
    );
    $('m-close').onclick = ui.closeModal;
    document.querySelectorAll('[data-rejoin]').forEach((btn) => {
      btn.onclick = () => { ui.closeModal(); SB.mp.joinRoom(btn.getAttribute('data-rejoin')); };
    });
    $('cp-create').onclick = () => { ui.closeModal(); SB.mp.createAndJoin(); };
    $('cp-join').onclick = () => {
      const code = $('cp-code').value.trim();
      if (!code) { ui.toast('Enter a room code', 'bad'); return; }
      ui.closeModal();
      SB.mp.joinRoom(code);
    };
  }

  ui.showCoop = async function () {
    if (!SB.game.state) { ui.toast('Load a city first', 'bad'); return; }
    if (SB.mp.connected) { renderCoopConnected(); return; }
    const signedIn = await SB.mp.init();
    if (!signedIn) { renderCoopSignedOut(); return; }
    renderCoopSetup();
  };

  // ── Modals ───────────────────────────────────────────────────────────
  function openModal(html, wide) {
    const back = $('modalback');
    $('modal').innerHTML = html;
    $('modal').classList.toggle('wide', !!wide);
    back.style.display = 'flex';
  }
  ui.closeModal = function () { $('modalback').style.display = 'none'; ui._localeRefresh = null; };

  ui.confirm = function (title, sub, onYes, localeRefresh) {
    ui._localeRefresh = localeRefresh || (() => ui.confirm(title, sub, onYes));
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
    ui._localeRefresh = () => ui.showPlacePicker(allowClose);
    const saved = SB.game.savedGames();
    let savedHtml = '';
    if (saved.length) {
      savedHtml = '<h3>' + translate('Your cities') + '</h3><div class="citygrid">' + saved.map((s) =>
        '<div class="citycard" data-save="' + s.id + '">' +
        '<div class="cc-head"><b data-luma-user-content>' + escapeHtml(s.place.name) + '</b><span class="pill">' + translate('Day') + ' ' + s.day + '</span></div>' +
        '<div class="cc-meta">' + s.lines + ' ' + translate('lines') + ' · ' + s.stations + ' ' + translate('stops') + '</div>' +
        '<div class="cc-save">' + translate('Continue') + ' · <a href="#" class="cc-del" data-save="' + s.id + '">' + translate('delete save') + '</a></div>' +
        '</div>').join('') + '</div>';
    }
    openModal(
      '<div class="brandrow">' + ic('metro', 'brandmark') + '<span class="brand">Subway Builder</span>' +
      '<span class="sub">' + translate('Pick any real place on Earth and build the transit it deserves') + '</span></div>' +
      '<div class="searchrow"><input type="text" id="place-q" placeholder="' + escapeHtml(translate('Search any city, town or address…')) + '">' +
      '<button id="place-go" class="primary">' + translate('Search') + '</button></div>' +
      '<div id="place-results"></div>' +
      savedHtml +
      '<h3>' + translate('Featured cities') + '</h3><div class="citygrid">' + FEATURED.map((c, i) =>
        '<div class="citycard" data-feat="' + i + '">' +
        '<div class="cc-head"><b data-luma-user-content>' + escapeHtml(c.name) + '</b></div>' +
        '<div class="cc-meta" data-luma-user-content>' + escapeHtml(c.country) + '</div>' +
        '</div>').join('') + '</div>' +
      (allowClose ? '<div class="mrow"><button id="m-close">' + translate('Back to the map') + '</button></div>' : ''),
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
      $('place-results').innerHTML = '<div class="sub" style="padding:8px 2px">' + translate('Searching…') + '</div>';
      try {
        const r = await fetch('https://photon.komoot.io/api/?q=' + encodeURIComponent(q) + '&limit=6&lang=' + encodeURIComponent(window.LumaSceneI18n.language));
        const data = await r.json();
        const feats = (data.features || []).filter((f) => f.geometry && f.geometry.type === 'Point');
        if (!feats.length) {
          $('place-results').innerHTML = '<div class="sub" style="padding:8px 2px">' + translate('No places found.') + '</div>';
          return;
        }
        $('place-results').innerHTML = '<div class="citygrid">' + feats.map((f, i) => {
          const p = f.properties || {};
          const ctx = [p.city, p.state, p.country].filter((v) => v && v !== p.name).join(', ');
          return '<div class="citycard" data-res="' + i + '">' +
            '<div class="cc-head"><b data-luma-user-content>' + escapeHtml(p.name || q) + '</b></div>' +
            '<div class="cc-meta" data-luma-user-content>' + escapeHtml(ctx || p.osm_value || '') + '</div></div>';
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
        $('place-results').innerHTML = '<div class="sub" style="padding:8px 2px">' + translate('Search failed — check your internet connection.') + '</div>';
      }
    }
    $('place-go').onclick = doSearch;
    $('place-q').addEventListener('keydown', (e) => { if (e.key === 'Enter') doSearch(); });
    $('place-q').focus();
    if (allowClose) $('m-close').onclick = ui.closeModal;
  };

  ui.showHelp = function () {
    ui._localeRefresh = ui.showHelp;
    openModal(
      '<h2>How to play</h2>' +
      '<div class="helpgrid">' +
      '<div><b>1 · Read the city</b><p>This is the real city from OpenStreetMap — zoom in for 3D buildings. The <i>Residents</i> and <i>Jobs</i> views (estimated from real land use) show where people live and work.</p></div>' +
      '<div><b>2 · Pick a mode</b><p><i>Metro</i> bores tunnels anywhere. <i>Tram</i> and <i>Bus</i> stops snap to streets and their routes follow real roads and bridges. <i>Trains</i> only call at real stations and run on tracks that really exist.</p></div>' +
      '<div><b>3 · Build stops &amp; lines</b><p>Place stops with <kbd>S</kbd>, connect them with <kbd>L</kbd>, finish with <kbd>Enter</kbd>. Metro under rivers costs 2.6× for tunnelling; surface modes must find a real street route.</p></div>' +
      '<div><b>4 · Run the fleet</b><p>Every line starts with two vehicles. More vehicles mean shorter waits and more capacity — watch the crowding flags before riders give up.</p></div>' +
      '<div><b>5 · Win commuters</b><p>Each simulated commuter weighs walking, waiting, riding, transfers and fares against driving, door to door. Your score is the <b>transit share</b>.</p></div>' +
      '<div><b>6 · Fund it</b><p>You start with a fixed budget — fares plus a small daily subsidy cover operations from there. Milestones bring bonus grants — loans are there if you dare.</p></div>' +
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
    ui._localeRefresh = ui.showStats;
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
        if (s) topStations += '<tr><td data-luma-user-content>' + escapeHtml(s.name) + '</td><td>' + SB.fmtInt(n) + '</td></tr>';
      }
    }
    const share = res ? res.share : 0, car = res ? res.carShare : 0;
    let modeSplit = '';
    if (res && res.ridersDaily > 1) {
      modeSplit = '<h3>' + window.LumaSceneI18n.value('sceneSubwayStatsBoardingsByMode') + '</h3><div class="modebars">' +
        Object.entries(res.modeRiders).filter(([, v]) => v > 0.5).map(([m, v]) =>
          '<div class="modebar"><span class="mb-label">' + ic(MODE_ICON[m]) + escapeHtml(translate(SB.MODES[m].label)) + '</span>' +
          '<span class="mb-track"><span style="width:' + Math.min(100, (v / res.ridersDaily) * 100) + '%;background:' + MODE_TINT[m] + '"></span></span>' +
          '<span class="mb-val">' + SB.fmtInt(v) + '</span></div>').join('') + '</div>';
    }

    openModal(
      '<h2>Network analysis</h2>' +
      '<div class="statgrid">' +
      stat(window.LumaSceneI18n.value('sceneSubwayStatsTransitShare'), (share * 100).toFixed(1) + '%') +
      stat(window.LumaSceneI18n.value('sceneSubwayStatsDailyRiders'), res ? SB.fmtInt(res.ridersDaily) : '—') +
      stat(window.LumaSceneI18n.value('sceneSubwayStatsCoverage'), res ? Math.round(res.coverage * 100) + '%' : '—', window.LumaSceneI18n.value('sceneSubwayStatsResidentsNearStop')) +
      stat(window.LumaSceneI18n.value('sceneSubwayStatsTransfers'), res ? SB.fmtInt(res.transfersDaily) + '/day' : '—') +
      stat(window.LumaSceneI18n.value('sceneSubwayStatsAvgTransitTrip'), res && res.avgTransitMin ? res.avgTransitMin.toFixed(0) + ' min' : '—') +
      stat(window.LumaSceneI18n.value('sceneSubwayStatsAvgCarTrip'), res && res.avgCarMin ? res.avgCarMin.toFixed(0) + ' min' : '—') +
      stat(window.LumaSceneI18n.value('sceneSubwayStatsRouteLength'), totalKm.toFixed(1) + ' km') +
      stat(window.LumaSceneI18n.value('sceneSubwayStatsStops'), st.stations.length) +
      stat(window.LumaSceneI18n.value('sceneSubwayStatsFleet'), totalVeh) +
      stat(window.LumaSceneI18n.value('sceneSubwayStatsSpentToDate'), SB.fmtMoney(st.totalSpent)) +
      '</div>' +
      '<div class="modesplit"><div class="ms-bar">' +
      '<span style="width:' + (share * 100) + '%;background:var(--accent)"></span>' +
      '<span style="width:' + (car * 100) + '%;background:#616b7d"></span></div>' +
      '<div class="ms-legend"><span><i style="background:var(--accent)"></i>' + escapeHtml(format('sceneSubwayStatsTransitLegend', {percent: (share * 100).toFixed(1)})) + '</span>' +
      '<span><i style="background:#616b7d"></i>' + escapeHtml(format('sceneSubwayStatsDrivingLegend', {percent: (car * 100).toFixed(1)})) + '</span></div></div>' +
      modeSplit +
      '<div class="chartrow">' +
      '<div><h3>' + window.LumaSceneI18n.value('sceneSubwayStatsDailyRiders') + '</h3><canvas id="ch-riders" width="290" height="90"></canvas></div>' +
      '<div><h3>' + window.LumaSceneI18n.value('sceneSubwayStatsTransitShare') + ' %</h3><canvas id="ch-share" width="290" height="90"></canvas></div>' +
      '<div><h3>' + translate('Treasury') + '</h3><canvas id="ch-money" width="290" height="90"></canvas></div>' +
      '</div>' +
      (topStations ? '<h3>' + window.LumaSceneI18n.value('sceneSubwayStatsBusiestStops') + '</h3><table class="stbl">' + topStations + '</table>' : '') +
      '<div class="mrow"><button id="m-close">' + translate('Close') + '</button></div>',
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

  document.addEventListener('luma-locale-changed', () => {
    if (ui._localeRefresh && $('modalback').style.display === 'flex') ui._localeRefresh();
  });

  // ── Rendering settings ───────────────────────────────────────────────
  function syncSettingsUI() {
    const s = SB.map3d.settings;
    $('set-buildings3d').classList.toggle('active', s.buildings3d);
    $('set-buildings3d').textContent = translate(s.buildings3d ? 'On' : 'Off');
    $('set-2d').classList.toggle('active', s.mode2d);
    $('set-2d').textContent = translate(s.mode2d ? 'On' : 'Off');
    $('mc-2d').classList.toggle('active', s.mode2d);
    $('set-render').value = s.renderDistance;
    $('set-render-val').textContent = s.renderDistance;
    $('set-lod').value = s.lodDistance;
    $('set-lod-val').textContent = s.lodDistance.toFixed(1);
  }
  ui.syncSettingsUI = syncSettingsUI;

  // ── Mobile: #left is an off-canvas drawer on narrow viewports ─────────
  // (desktop/tablet widths keep it permanently docked, unaffected).
  function isNarrowViewport() {
    return window.matchMedia('(max-width: 760px)').matches;
  }
  function setLeftOpen(open) {
    $('left').classList.toggle('open', open);
    $('leftscrim').classList.toggle('show', open);
  }
  ui.setLeftOpen = setLeftOpen;

  // ── Static wiring ────────────────────────────────────────────────────
  ui.init = function () {
    $('mc-menu').addEventListener('click', () =>
      setLeftOpen(!$('left').classList.contains('open')));
    $('leftscrim').addEventListener('click', () => setLeftOpen(false));
    $('left-close').addEventListener('click', () => setLeftOpen(false));

    for (const m of Object.keys(SB.MODES)) {
      $('mode-' + m).addEventListener('click', () => ui.setMode(m));
      // Picking a mode or tool is the cue that the player is about to work
      // on the map, so tuck the drawer away again on phones.
      $('mode-' + m).addEventListener('click', () => { if (isNarrowViewport()) setLeftOpen(false); });
    }
    for (const t of ['select', 'station', 'line', 'bulldoze']) {
      $('tool-' + t).addEventListener('click', () => ui.setTool(t));
      $('tool-' + t).addEventListener('click', () => { if (isNarrowViewport()) setLeftOpen(false); });
    }
    for (const o of ['pop', 'jobs', 'access', 'load']) {
      $('ov-' + o).addEventListener('click', () => ui.setOverlay(o));
    }
    document.querySelectorAll('#speedctl button').forEach((b, i) => {
      b.addEventListener('click', () => ui.setSpeed(i));
    });
    $('btn-stats').addEventListener('click', ui.showStats);
    $('btn-achievements').addEventListener('click', ui.showAchievements);
    $('btn-coop').addEventListener('click', ui.showCoop);
    $('btn-help').addEventListener('click', ui.showHelp);
    $('btn-cities').addEventListener('click', () => ui.showPlacePicker(true));
    $('btn-3d').addEventListener('click', () => {
      if (SB.map3d.settings.mode2d) {
        ui.toast('Turn off 2D mode in Settings to tilt the camera', 'bad');
        return;
      }
      const on = !$('btn-3d').classList.contains('active');
      $('btn-3d').classList.toggle('active', on);
      SB.map3d.setPitch3D(on);
    });
    $('set-buildings3d').addEventListener('click', () => {
      SB.map3d.setSetting('buildings3d', !SB.map3d.settings.buildings3d);
      syncSettingsUI();
    });
    function toggle2d() {
      SB.map3d.setSetting('mode2d', !SB.map3d.settings.mode2d);
      if (SB.map3d.settings.mode2d) $('btn-3d').classList.remove('active');
      syncSettingsUI();
    }
    $('set-2d').addEventListener('click', toggle2d);
    $('mc-2d').addEventListener('click', toggle2d);

    // Floating map controls (zoom / compass).
    $('mc-zoomin').addEventListener('click', () => {
      const m = SB.map3d.map;
      if (m) m.zoomTo(Math.min(22, m.getZoom() + 1), { duration: 250 });
    });
    $('mc-zoomout').addEventListener('click', () => {
      const m = SB.map3d.map;
      if (m) m.zoomTo(Math.max(0, m.getZoom() - 1), { duration: 250 });
    });
    $('mc-compass').addEventListener('click', () => {
      const m = SB.map3d.map;
      if (m) m.easeTo({ bearing: 0, duration: 400 });
    });

    // Theme toggle — swaps the UI palette and the basemap style together.
    function updateThemeIcon() {
      $('btn-theme').querySelector('use').setAttribute('href',
        SB.map3d.settings.theme === 'light' ? '#i-moon' : '#i-sun');
    }
    document.body.classList.toggle('light', SB.map3d.settings.theme === 'light');
    updateThemeIcon();
    $('btn-theme').addEventListener('click', () => {
      const next = SB.map3d.settings.theme === 'light' ? 'dark' : 'light';
      SB.map3d.setTheme(next);
      document.body.classList.toggle('light', next === 'light');
      updateThemeIcon();
    });
    // Dragging a range slider fires 'input' continuously (many times per
    // second); re-applying the render style on every tick floods MapLibre
    // with paint/zoom-range mutations and can leave tiles stuck mid-update.
    // Debounce the actual apply, but keep the label live for feedback, and
    // always apply immediately once the user releases the slider ('change').
    let renderDebounce = null, lodDebounce = null;
    $('set-render').addEventListener('input', () => {
      const v = +$('set-render').value;
      $('set-render-val').textContent = v;
      clearTimeout(renderDebounce);
      renderDebounce = setTimeout(() => SB.map3d.setSetting('renderDistance', v), 150);
    });
    $('set-render').addEventListener('change', () => {
      clearTimeout(renderDebounce);
      SB.map3d.setSetting('renderDistance', +$('set-render').value);
    });
    $('set-lod').addEventListener('input', () => {
      const v = +$('set-lod').value;
      $('set-lod-val').textContent = v.toFixed(1);
      clearTimeout(lodDebounce);
      lodDebounce = setTimeout(() => SB.map3d.setSetting('lodDistance', v), 150);
    });
    $('set-lod').addEventListener('change', () => {
      clearTimeout(lodDebounce);
      SB.map3d.setSetting('lodDistance', +$('set-lod').value);
    });
    syncSettingsUI();
    $('btn-newline').addEventListener('click', () => {
      ui.setTool('line');
      ui.beginDraftFrom(null);
      ui.updateDraftHint();
    });
    $('btn-loadstations').addEventListener('click', async () => {
      const btn = $('btn-loadstations');
      if (btn.disabled) return;
      btn.disabled = true;
      ui.toast('Loading official stations in view…');
      try {
        const b = SB.map3d.map.getBounds();
        const added = await SB.net.surveyStationsInBounds(
          b.getSouth(), b.getWest(), b.getNorth(), b.getEast());
        if (added < 0) ui.toast('Station lookup failed — the map data service is busy, try again', 'bad');
        else if (added === 0) ui.toast('No new official stations found in view');
        else ui.toast(format('sceneSubwayOfficialStationsLoaded', {count: added}), 'good');
        SB.map3d.setRailMode(SB.isRailMode(ui.mode) && (ui.tool === 'station' || ui.tool === 'line'), ui.mode);
      } finally {
        btn.disabled = false;
      }
    });
    function econGate() {
      if (SB.mp.econLocked()) { ui.toast('Only whoever is running the clock manages the treasury', 'bad'); return true; }
      return false;
    }
    $('fare-minus').addEventListener('click', () => { if (!econGate()) SB.game.setFare(SB.game.state.fare - 0.25); });
    $('fare-plus').addEventListener('click', () => { if (!econGate()) SB.game.setFare(SB.game.state.fare + 0.25); });
    $('btn-loan').addEventListener('click', () => {
      if (econGate()) return;
      const confirmLoan = () => ui.confirm(
        escapeHtml(format('sceneSubwayUiLoanQuestion', {amount: SB.fmtMoney(SB.ECON.loanAmount)})),
        window.LumaSceneI18n.value('sceneSubwayUiLoanInterest'),
        () => {
          SB.game.takeLoan();
          ui.toast(format('sceneSubwayLoanReceived', {amount: SB.fmtMoney(SB.ECON.loanAmount)}));
        },
        confirmLoan,
      );
      confirmLoan();
    });
    $('btn-repay').addEventListener('click', () => { if (!econGate()) doAction(SB.game.repayLoan()); });
    $('modalback').addEventListener('mousedown', (e) => {
      if (e.target === $('modalback') && $('m-close')) ui.closeModal();
    });
  };
})();
