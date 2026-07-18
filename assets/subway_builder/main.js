/* Subway Builder — bootstrap, map input and the main loop. */
(function () {
  'use strict';
  const SB = (window.SB = window.SB || {});
  const ui = SB.ui, game = SB.game, map3d = SB.map3d;

  const main = (SB.main = {});

  let hover = null;
  let ghostOk = false;
  let mouseLL = null;
  let dayAcc = 0;
  let lastT = 0;
  let starting = false;

  // ── Place lifecycle ──────────────────────────────────────────────────
  main.startPlace = function (place, fresh) {
    if (starting) return;
    starting = true;
    const loading = document.getElementById('loading');
    document.getElementById('loading-text').textContent =
      'Surveying ' + place.name + '… reading OpenStreetMap land use, water and neighbourhoods';
    loading.style.display = 'flex';

    SB.geo.setAnchor(place.lng, place.lat);
    map3d.surveyPlace(place, async (collected) => {
      try {
        const setText = (t) => { document.getElementById('loading-text').textContent = t; };
        const city = SB.demand.build(collected, place);
        setText('Tracing streets and railways… fetching real rail data');
        try {
          await SB.net.build(collected, place, setText);
        } catch (e) { /* keep whatever networks were built */ }
        game.attachCity(city, place, fresh);
        SB.sim.assign();
        ui.setSpeed(1);
        ui.setTool('select');
        ui.selection = null;
        ui.cancelDraft(true);
        dayAcc = 0;
        map3d.map.easeTo({ center: [place.lng, place.lat], zoom: 12.6, pitch: 45, duration: 1200 });
        document.getElementById('btn-3d').classList.add('active');
        map3d.setOverlay(ui.overlay);
        ui.updateAll();
        if (!game.state.helpSeen) ui.showHelp();
        else ui.toast('Welcome back to ' + place.name + ' — day ' + game.state.day);
      } finally {
        loading.style.display = 'none';
        starting = false;
      }
    });
  };

  main.focusLine = function (line) { map3d.focusLine(line); };

  // ── Tool clicks on the map ───────────────────────────────────────────
  function handleClick(e) {
    if (!game.state) return;
    const station = map3d.stationAtPoint(e.point);

    if (ui.tool === 'select') {
      if (station) ui.selection = { type: 'station', id: station.id };
      else {
        const line = map3d.lineAtPoint(e.point);
        ui.selection = line ? { type: 'line', id: line.id } : null;
      }
      ui.updateAll();
      return;
    }

    if (ui.tool === 'station') {
      if (SB.isRailMode(ui.mode)) {
        const rs = map3d.railStationAtPoint(e.point);
        if (!rs) { ui.toast(SB.MODES[ui.mode].label + ' services only call at real railway stations — click a highlighted one', 'bad'); return; }
        const r = game.addTrainStation(rs, ui.mode);
        if (!r.ok) ui.toast(r.err, 'bad');
        else if (!r.existing) ui.toast(r.station.name + ' leased · ' + SB.fmtMoney(r.cost));
        ui.updateAll();
        return;
      }
      const r = game.addStation(e.lngLat.lng, e.lngLat.lat, ui.mode);
      if (!r.ok) ui.toast(r.err, 'bad');
      else ui.toast(r.station.name + ' built · ' + SB.fmtMoney(r.cost));
      ui.updateAll();
      return;
    }

    if (ui.tool === 'line') {
      let target = station;
      // In rail modes, clicking an unleased real station leases it on the fly.
      if (!target && SB.isRailMode(ui.mode)) {
        const rs = map3d.railStationAtPoint(e.point);
        if (rs) {
          const r = game.addTrainStation(rs, ui.mode);
          if (!r.ok) { ui.toast(r.err, 'bad'); return; }
          if (!r.existing) ui.toast(r.station.name + ' leased · ' + SB.fmtMoney(r.cost));
          target = r.station;
        }
      }
      if (!target) return;
      if (!ui.draftLineId && target.mode !== ui.mode) {
        ui.toast(target.name + ' is a ' + SB.MODES[target.mode].label.toLowerCase() + ' stop — switch mode to connect it', 'bad');
        return;
      }
      handleLineClick(target);
      return;
    }

    if (ui.tool === 'bulldoze') {
      if (station) {
        const r = game.removeStation(station.id);
        if (r.ok) ui.toast(station.name + ' demolished · ' + SB.fmtMoney(r.refund) + ' refunded');
        else ui.toast(r.err, 'bad');
        ui.updateAll();
        return;
      }
      const line = map3d.lineAtPoint(e.point);
      if (line) {
        ui.confirm('Delete ' + line.name + '?', 'You get 25% of construction plus vehicle resale back.', () => {
          const r = game.deleteLine(line.id);
          if (r.ok) ui.toast(line.name + ' removed · ' + SB.fmtMoney(r.refund) + ' refunded');
          ui.updateAll();
        });
      }
    }
  }

  function handleLineClick(station) {
      if (ui.draftLineId) {
        const line = game.lineById(ui.draftLineId);
        if (!line) { ui.cancelDraft(true); return; }
        if (!ui.draftIds.length) {
          const first = line.stationIds[0], last = line.stationIds[line.stationIds.length - 1];
          if (station.id !== first && station.id !== last) {
            ui.toast('Click one of the two end stations of ' + line.name, 'bad');
            return;
          }
          ui.draftIds = [station.id];
          ui.updateDraftHint();
          ui.updateAll();
          return;
        }
        const fromId = ui.draftIds[0];
        const atStart = line.stationIds[0] === fromId;
        const r = game.extendLine(line.id, station.id, atStart);
        if (!r.ok) { ui.toast(r.err, 'bad'); return; }
        ui.draftIds = [station.id];
        ui.toast(line.name + ' extended to ' + station.name);
        ui.updateAll();
        return;
      }
      const last = ui.draftIds[ui.draftIds.length - 1];
      if (station.id === last) { finishDraft(); return; } // click end twice = done
      if (ui.draftIds.includes(station.id)) { ui.toast('Already on this draft', 'bad'); return; }
      ui.draftIds.push(station.id);
      ui.updateDraftHint();
      ui.updateAll();
  }

  function finishDraft() {
    if (ui.draftIds.length < 2) { ui.cancelDraft(); return; }
    const r = game.commitLine(ui.mode, ui.draftIds);
    if (!r.ok) { ui.toast(r.err, 'bad'); return; }
    const draft = game.draftCost(r.line.mode, r.line.stationIds);
    let msg = r.line.name + ' opened — ' + SB.fmtMoney(r.cost) + ', 2 ' + SB.MODES[r.line.mode].vehicle + 's included';
    if (draft.waterM > 0) msg += ', includes underwater tunnelling';
    ui.toast(msg, 'good');
    ui.draftIds = [];
    ui.selection = { type: 'line', id: r.line.id };
    ui.updateDraftHint();
    ui.updateAll();
  }
  main.finishDraft = finishDraft;

  function onMouseMove(e) {
    if (!game.state) return;
    mouseLL = e.lngLat;
    const station = map3d.stationAtPoint(e.point);
    hover = station ? { type: 'station', id: station.id } : null;
    if (ui.tool === 'station' && !SB.isRailMode(ui.mode)) {
      const [x, y] = SB.geo.toM(e.lngLat.lng, e.lngLat.lat);
      ghostOk = game.canPlaceStation(x, y, ui.mode).ok;
    }
    const canvas = map3d.map.getCanvas();
    canvas.style.cursor =
      ui.tool === 'station' ? 'crosshair' :
      ui.tool === 'line' ? (hover ? 'pointer' : 'crosshair') :
      ui.tool === 'bulldoze' ? (hover ? 'pointer' : 'default') :
      hover ? 'pointer' : '';
  }

  function onKey(e) {
    if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;
    const back = document.getElementById('modalback');
    if (back.style.display !== 'none' && back.style.display !== '') {
      if (e.key === 'Escape' && document.getElementById('m-close')) ui.closeModal();
      return;
    }
    if (!game.state) return;
    switch (e.key) {
      case 'v': case 'V': ui.setTool('select'); break;
      case 's': case 'S': ui.setTool('station'); break;
      case 'l': case 'L': ui.setTool('line'); ui.beginDraftFrom(null); ui.updateDraftHint(); break;
      case 'b': case 'B': case 'x': case 'X': ui.setTool('bulldoze'); break;
      case 'Escape':
        if (ui.draftIds.length || ui.draftLineId) ui.cancelDraft();
        else if (ui.selection) { ui.selection = null; ui.updateAll(); }
        else ui.setTool('select');
        break;
      case 'Enter':
        if (ui.tool === 'line' && ui.draftIds.length > 1 && !ui.draftLineId) finishDraft();
        break;
      case 'Backspace':
        if (ui.tool === 'line' && ui.draftIds.length && !ui.draftLineId) {
          ui.draftIds.pop();
          ui.updateDraftHint();
          ui.updateAll();
        }
        break;
      case ' ':
        e.preventDefault();
        ui.setSpeed(ui.speed === 0 ? 1 : 0);
        break;
      case '1': ui.setMode('metro'); break;
      case '2': ui.setMode('tram'); break;
      case '3': ui.setMode('bus'); break;
      case '4': ui.setMode('train'); break;
      case '5': ui.setMode('hst'); break;
      default: return;
    }
    e.preventDefault();
  }

  // ── Day / economy timer ──────────────────────────────────────────────
  function advanceTime(dt) {
    const sp = ui.SPEEDS[ui.speed];
    if (!sp || sp.mult === 0 || !game.state) return;
    dayAcc += dt;
    if (dayAcc >= sp.dayS) {
      dayAcc -= sp.dayS;
      const report = game.endDay();
      SB.sim.assign(); // crowding feedback converges day by day
      for (const ev of report.events) {
        if (ev.type === 'milestone') {
          ui.banner('🎉 ' + ev.label, (ev.share * 100).toFixed(0) + '% transit share reached — ' + SB.fmtMoney(ev.grant) + ' grant awarded!');
        } else if (ev.type === 'capital') {
          ui.toast('🏛 ' + ev.label + ': ' + SB.fmtMoney(ev.grant) + ' to build with', 'good');
        }
      }
      if (game.state.money < 0 && (game.state.money - report.net) >= 0) {
        ui.toast('Treasury is in the red — consider a loan or higher fares', 'bad');
      }
      ui.updateAll();
    }
  }

  // ── Main loop (game layers only — MapLibre renders the map itself) ───
  function frame(t) {
    const dt = Math.min(0.1, (t - lastT) / 1000 || 0.016);
    lastT = t;
    if (game.state && map3d.ready) {
      SB.sim.ensure();
      SB.sim.updateTrains(dt, ui.SPEEDS[ui.speed].mult);
      advanceTime(dt);
      map3d.updateTrains();
      map3d.updateDraft(ui.mapState(), mouseLL);
      map3d.updateGhost({ tool: SB.isRailMode(ui.mode) ? 'none' : ui.tool, ghostOk, mode: ui.mode }, mouseLL);
    }
    requestAnimationFrame(frame);
  }

  // ── Boot ─────────────────────────────────────────────────────────────
  window.addEventListener('DOMContentLoaded', () => {
    ui.init();
    window.addEventListener('keydown', onKey);

    map3d.init(() => {
      const map = map3d.map;
      map.on('click', handleClick);
      map.on('mousemove', onMouseMove);
      map.on('dblclick', (e) => {
        if (ui.tool === 'line' && ui.draftIds.length > 1 && !ui.draftLineId) {
          e.preventDefault();
          finishDraft();
        }
      });
      map.on('contextmenu', () => {
        if (ui.tool === 'line' && (ui.draftIds.length || ui.draftLineId)) {
          if (ui.draftIds.length > 1 && !ui.draftLineId) finishDraft();
          else ui.cancelDraft();
        } else if (ui.tool !== 'select') {
          ui.setTool('select');
        }
      });

      game.onChange = () => ui.updateAll();

      const saved = game.savedGames();
      const current = saved.find((s) => s.current);
      if (current) main.startPlace(current.place, false);
      else ui.showPlacePicker(false);

      requestAnimationFrame(frame);
    });
  });
})();
