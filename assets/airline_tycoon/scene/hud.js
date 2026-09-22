/* In-page airport controls. The Dart repository stays authoritative: every
   change is sent as a command and the page only reflects snapshots and results. */
window.AirportHud = (() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const icons = {
    play: '<path d="M7 5v14l11-7z"/>',
    pause: '<path d="M8 5v14M16 5v14"/>',
    fit: '<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>',
    reset: '<path d="M4 12a8 8 0 1 0 2.3-5.7"/><path d="M4 4v4h4"/>',
    cutaway: '<path d="M3 11 12 4l9 7"/><path d="M5 10v10h14V10"/><path d="M9 20v-6h6v6"/>',
    grid: '<path d="M4 4h16v16H4zM4 10h16M4 15h16M10 4v16M15 4v16"/>',
    quality: '<path d="M4 17a8 8 0 1 1 16 0"/><path d="m12 17 4-5"/>',
    stats: '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
    close: '<path d="M6 6l12 12M18 6 6 18"/>',
    rotate: '<path d="M20 12a8 8 0 1 1-2.3-5.7"/><path d="M20 4v4h-4"/>',
    Build: '<path d="M14 6l4 4M3 21l9-9M12 4l8 8-3 3-8-8z"/>',
    Fleet: '<path d="M2 16l20-5-2-3-6 1.5L9 4H7l3 6.5L5 12l-2-2H2l1 4z"/><path d="M3 20h18"/>',
    Routes: '<circle cx="6" cy="18" r="2"/><circle cx="18" cy="6" r="2"/><path d="M8 18h7a3 3 0 0 0 0-6H9a3 3 0 0 1 0-6h7"/>',
    Contracts: '<path d="M4 12l4-4 4 3 4-3 4 4-8 7z"/>',
    Planning: '<path d="M3 5h18v15H3zM3 10h18M8 14h5M11 17h6"/>',
    Schedule: '<path d="M4 6h16v14H4zM4 10h16M8 3v5M16 3v5"/>',
    Finances: '<path d="M3 7h18v12H3zM3 11h18"/><circle cx="16" cy="15" r="1"/>',
    focus: '<circle cx="12" cy="12" r="3"/><path d="M4 8V4h4M20 8V4h-4M4 16v4h4M20 16v4h-4"/>',
    move: '<path d="M12 3v18M3 12h18M9 6l3-3 3 3M9 18l3 3 3-3M6 9l-3 3 3 3M18 9l3 3-3 3"/>',
    trash: '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    truck: '<path d="M3 7h11v9H3zM14 10h4l3 3v3h-7"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/>',
    save: '<path d="M5 4h11l3 3v13H5zM8 4v5h7M8 20v-6h8v6"/>',
    history: '<path d="M4 12a8 8 0 1 0 2.3-5.7"/><path d="M4 4v4h4M12 8v4l3 2"/>',
    interior: '<path d="M4 20V9l8-5 8 5v11"/><path d="M8 20v-5h3v5M14 12h3v3h-3z"/>',
    exit: '<path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10"/>',
    left: '<path d="M15 5l-7 7 7 7"/>',
    right: '<path d="M9 5l7 7-7 7"/>',
    bridge: '<path d="M3 18h6V9h12M9 9V6M3 18v-3"/>',
    up: '<path d="M6 15l6-6 6 6"/>',
    down: '<path d="M6 9l6 6 6-6"/>',
    tail: '<path d="M4 21 9 3h5l-2 9 8 1-3 8z"/>',
    fuel: '<path d="M5 21V5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v16M3 21h14M7 9h6M15 8l3 3v6a1.5 1.5 0 0 0 3 0V9l-3-3"/>',
    bag: '<path d="M5 8h14v12H5zM9 8V5h6v3M9 12v4M15 12v4"/>',
    cup: '<path d="M5 8h11v6a5 5 0 0 1-5 5h-1a5 5 0 0 1-5-5zM16 10h2a2 2 0 0 1 0 4h-2M8 3v2M12 3v2"/>',
    seat: '<path d="M7 4v9h9l2 7M7 13l-2 7M9 17h7"/>',
    star: '<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
    wc: '<circle cx="7" cy="5" r="1.6"/><circle cx="17" cy="5" r="1.6"/><path d="M7 9v11M5 9h4v6H5zM17 9l-3 7h6zM17 16v4M12 3v18"/>',
    shop: '<path d="M5 8h14l-1 12H6zM9 8a3 3 0 0 1 6 0"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/>',
    upgrade: '<path d="M12 20V8M6 13l6-6 6 6M5 4h14"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    moon: '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>',
  };
  const svg = name => `<svg viewBox="0 0 24 24" aria-hidden="true">${icons[name] || ''}</svg>`;
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c]));
  const store = {
    get(key) { try { return localStorage.getItem(`airport.${key}`); } catch (_) { return null; } },
    set(key, value) { try { localStorage.setItem(`airport.${key}`, String(value)); } catch (_) { /* per-viewer only */ } },
  };
  const categories = {
    airfield: 'Airfield', apron: 'Apron', services: 'Services', terminal: 'Terminal',
    interior: 'Passenger flow', shops: 'Shops & lounges', decor: 'Decor',
  };
  const outdoor = ['apron', 'airfield', 'terminal', 'services'];
  // Airport mode sorts the furnishings by the part of the terminal they
  // belong in. The terminal is one building; zoning its floor decides which
  // part a piece of it is.
  const zones = {
    arrival: {tab: 'Arrival hall', paint: 'arrival', hint: 'Passengers come in from the road here: the entrance, ticket machines and check-in, then security through to the main hall.'},
    main: {tab: 'Main hall', building: true, hint: 'Past security: seating, toilets, lounges and the boarding gates the passengers wait at. Floor you have not zoned counts as the main hall.'},
    shops: {tab: 'Shops', hint: 'Shops, cafés and restaurants in the main hall earn from passengers waiting for their flight.'},
    departure: {tab: 'Departure hall', paint: 'departure', hint: 'Arriving passengers leave through here: baggage carousels, customs and check-out to the kerb.'},
    any: {tab: 'Anywhere', hint: 'Information and bins fit anywhere in the terminal.'},
  };
  const zoneOf = d => { const z = AirportSceneLogic.zoneOf(d.kind); return z === 'main' && d.category === 'shops' ? 'shops' : z; };
  const panelNames = ['Build', 'Contracts', 'Planning', 'Fleet', 'Routes', 'Schedule', 'Finances'];

  const S = {
    world: null, panel: null, selected: null, tool: null, moveId: null, rotation: 0,
    cutaway: store.get('cutaway') === '1', grid: store.get('grid') === '1',
    quality: store.get('quality') === 'low' ? 'low' : 'high', stats: store.get('stats') === '1',
    notices: [], schedule: {aircraft: null, route: null, stand: '', delay: 120},
    category: 'apron', airport: false, zone: null,
    plan: {focus: null, slot: null, card: null, drag: null, scrollTo: null},
    manage: null,
    contractsUi: {tab: 'offers', open: null},
  };
  const signatures = {};
  const pending = new Map();
  const thumbs = new Map();
  let scene = null, counter = 0, noticeCounter = 0;

  function money(value) {
    const n = Math.abs(Math.round(Number(value) || 0)), sign = value < 0 ? '-' : '';
    if (n >= 1e9) return `${sign}€${(n / 1e9).toFixed(2)}B`;
    if (n >= 1e7) return `${sign}€${(n / 1e6).toFixed(1)}M`;
    if (n >= 1e6) return `${sign}€${(n / 1e6).toFixed(2)}M`;
    if (n >= 1e4) return `${sign}€${(n / 1e3).toFixed(0)}K`;
    if (n >= 1e3) return `${sign}€${(n / 1e3).toFixed(1)}K`;
    return `${sign}€${n}`;
  }
  const exactMoney = value => `${value < 0 ? '-' : ''}€${String(Math.abs(Math.round(Number(value) || 0))).replace(/\B(?=(\d{3})+(?!\d))/g, ' ')}`;
  const friendly = value => AirportSceneLogic.friendly(value) || 'Unknown';
  const list = key => Array.isArray(S.world?.[key]) ? S.world[key] : [];
  const pad = n => String(n).padStart(2, '0');
  const clockText = minutes => `${pad(Math.floor(minutes / 60) % 24)}:${pad(Math.floor(minutes) % 60)}`;
  const flightTime = minutes => `D${Math.floor((minutes || 0) / 1440) + 1} ${clockText(minutes || 0)}`;
  const facilityName = kind => list('catalog').find(d => d.kind === kind)?.name
    || ({checkIn: 'Check-in desks', boardingGate: 'Boarding gate', fuel: 'Fuel service', baggage: 'Baggage service', bus: 'Passenger bus', pushback: 'Pushback service'}[kind])
    || friendly(kind);
  const modelName = id => S.world?.modelNames?.[id] || friendly(id);
  const modelClass = id => S.world?.modelClasses?.[id] || '';
  const vehicleName = kind => ({fuel: 'Fuel truck', baggage: 'Baggage tug', bus: 'Passenger bus', pushback: 'Pushback tug'}[kind]) || friendly(kind);
  const stageName = stage => ({approach: 'On approach', positioning: 'Towed to the stand', toHangar: 'Towed to the hangar', landing: 'Landing', pushback: 'Pushing back', boarding: 'Boarding', taxiIn: 'Taxiing to stand', taxiOut: 'Taxiing to runway', unloading: 'Unloading passengers', servicing: 'Ground services', departing: 'Taking off', remote: 'Flying the route', enRoute: 'Flying the route', awaitingStand: 'Waiting for a stand', awaitingAirport: 'Waiting for airport access'}[stage]) || friendly(stage);
  const standKinds = new Set(['stand', 'standRegional', 'standContact']);
  const stands = () => list('facilities').filter(f => standKinds.has(f.kind));
  const standCode = f => `${f.kind === 'standRegional' ? 'R' : f.kind === 'standContact' ? 'A' : 'B'}${String(f.id || '').replace(/\D/g, '').slice(-2).padStart(2, '0')}`;
  const standName = id => { const f = stands().find(s => s.id === id); return f ? `Stand ${standCode(f)}` : 'Unassigned stand'; };
  const standClass = f => f.kind === 'standRegional' ? 'SH' : 'ALL';
  const livery = carrier => `#${AirportSceneLogic.livery(carrier).main.toString(16).padStart(6, '0')}`;
  const compact = () => innerWidth < 820;
  const owned = kind => list('facilities').filter(f => f.kind === kind).length;

  // ── Bridge ────────────────────────────────────────────────────────────
  const quiet = new Set(['pause', 'resume', 'speed', 'dismissAway', 'openPage']);
  function command(action, args = {}, after) {
    const id = `hud-${++counter}`;
    pending.set(id, {action, after});
    scene.send({type: 'command', action, id, ...args});
  }
  function result(message) {
    const entry = pending.get(message.id);
    if (!entry) return;
    pending.delete(message.id);
    if (!message.ok) notify(message.message || 'Unable to complete that action.', 'error');
    else if (message.message || !quiet.has(entry.action)) notify(message.message || 'Airport updated.', 'success');
    if (message.ok && entry.after) entry.after();
  }
  function notify(text, kind) {
    const id = ++noticeCounter;
    S.notices = [...S.notices.filter(n => n.text !== text), {id, text, kind}].slice(-3);
    renderNotices();
    if (kind === 'success') setTimeout(() => dismiss(id), 4000);
  }
  function dismiss(id) { S.notices = S.notices.filter(n => n.id !== id); renderNotices(); }

  // ── Actions ───────────────────────────────────────────────────────────
  function openPanel(name) {
    if (name === 'Fleet' || name === 'Routes') { command('openPage', {page: name}); return; }
    S.panel = S.panel === name ? null : name;
    if (S.panel === 'Planning' && S.plan.scrollTo == null) S.plan.scrollTo = S.world?.time || 0;
    renderPanel(true);
    renderNotices();
  }
  /** The floor-zoning tool: drag over the terminal floor to mark it out. */
  function setZone(zone) {
    S.zone = zone || null;
    if (S.zone) { S.tool = null; S.moveId = null; scene.tool({kind: null}); renderTool(); }
    scene.view('zone', S.zone);
    renderPanel(true);
  }
  function setTool(kind, moveId = null) {
    if (kind && S.zone) setZone(null);
    S.tool = kind; S.moveId = kind ? moveId : null;
    if (kind && compact()) S.panel = null;
    scene.tool({kind, rotation: S.rotation, moveId: S.moveId});
    renderTool(); renderPanel(true);
  }
  function rotate() { if (!S.tool) return; S.rotation = (S.rotation + 1) % 4; scene.tool({kind: S.tool, rotation: S.rotation, moveId: S.moveId}); renderTool(); }
  function toggle(name) {
    if (name === 'quality') { S.quality = S.quality === 'high' ? 'low' : 'high'; store.set('quality', S.quality); scene.view('quality', S.quality); }
    else if (name === 'stats') { S.stats = !S.stats; store.set('stats', S.stats ? 1 : 0); scene.view('stats', S.stats); }
    else { S[name] = !S[name]; store.set(name, S[name] ? 1 : 0); scene.view(name, S[name]); }
    renderViewbar();
  }
  function place(location) {
    const moving = !!S.moveId;
    command(moving ? 'move' : 'place', {kind: S.tool, x: location.x, y: location.y, rotation: S.rotation, facilityId: S.moveId}, () => { if (moving) setTool(null); });
  }
  function select(id) {
    S.selected = id || null;
    S.manage = id ? {id, tab: S.manage?.id === id ? S.manage.tab : 'general', confirm: false} : null;
    renderManage(true);
    renderPanel(true);
    renderNotices();
  }
  function closeManage() {
    S.manage = null;
    S.selected = null;
    scene.view('select', null, null);
    renderManage(true);
    renderPanel(true);
    renderNotices();
  }
  const halls = () => list('facilities').filter(f => AirportSceneLogic.hallKinds.has(f.kind));
  /** Airport mode, like the original game: zoomed in over the terminal with
      the roofs off, furnished hall by hall. [id] frames one hall. */
  function enterAirport(id = null) {
    if (!halls().length) { notify('Build the terminal first: an arrival hall and a departure hall on the road side, and a main hall behind them (Build → Terminal).', 'error'); return; }
    S.manage = null;
    renderManage(true);
    S.airport = true;
    const hall = id && list('facilities').find(f => f.id === id);
    const zone = hall ? AirportSceneLogic.hallZone(hall.kind) : null;
    if (zone) S.category = zone;
    else if (!zones[S.category]) S.category = 'arrival';
    if (S.tool && !isInterior(S.tool) && !isHall(S.tool)) setTool(null);
    if (!S.panel && !compact()) S.panel = 'Build';
    renderViewbar(); renderPanel(true); renderNotices();
    scene.view('airport', true, id);
  }
  function exitAirport() {
    if (!S.airport) return;
    S.airport = false;
    if (!outdoor.includes(S.category)) S.category = 'terminal';
    if (S.tool && isInterior(S.tool)) setTool(null);
    if (S.zone) setZone(null);
    scene.view('airport', false);
    renderViewbar(); renderPanel(true);
  }
  const isInterior = kind => !!list('catalog').find(d => d.kind === kind)?.interior;
  const isHall = kind => AirportSceneLogic.hallKinds.has(kind);

  // ── Rendering ─────────────────────────────────────────────────────────
  function renderTop() {
    const w = S.world || {}, paused = w.paused !== false;
    $('airline').textContent = `${w.hubIata || ''} / ${w.airlineName || 'Airport'}`;
    $('money').textContent = money(w.cash);
    $('money').title = exactMoney(w.cash);
    const hour = Math.floor((w.time || 0) / 60) % 24, clock = `DAY ${w.day ?? 1} · ${clockText(w.time || 0)}`;
    const phase = hour >= 6 && hour < 20 ? 'sun' : 'moon';
    if ($('clock').dataset.text !== clock + phase) {
      $('clock').dataset.text = clock + phase;
      $('clock').innerHTML = `<svg class="phase ${phase}" viewBox="0 0 24 24" aria-hidden="true">${icons[phase]}</svg>${esc(clock)}`;
      $('clock').title = phase === 'sun' ? 'Daytime' : 'Night: the airport lights are on';
    }
    const pause = $('pause');
    const icon = paused ? 'play' : 'pause';
    if (pause.dataset.icon !== icon) { pause.innerHTML = svg(icon); pause.dataset.icon = icon; }
    pause.title = paused ? 'Resume airport (Space)' : 'Pause airport (Space)';
    pause.setAttribute('aria-label', paused ? 'Resume airport' : 'Pause airport');
    for (const b of document.querySelectorAll('[data-speed]')) b.classList.toggle('on', Number(b.dataset.speed) === w.speed);
  }
  function renderViewbar() {
    for (const b of document.querySelectorAll('[data-toggle]')) {
      const name = b.dataset.toggle;
      const on = name === 'quality' ? S.quality === 'high' : name === 'cutaway' ? S.cutaway || S.airport : S[name];
      b.classList.toggle('on', !!on);
      if (name === 'quality') b.title = S.quality === 'high' ? 'Quality: high (click for performance)' : 'Quality: performance (click for high)';
    }
    for (const b of document.querySelectorAll('[data-mode]')) {
      const on = (b.dataset.mode === 'airport') === S.airport;
      b.classList.toggle('on', on);
      b.setAttribute('aria-pressed', String(on));
    }
    document.body.classList.toggle('airport-mode', S.airport);
  }
  function renderDock() {
    for (const b of document.querySelectorAll('#dock [data-open]')) b.classList.toggle('on', S.panel === b.dataset.open);
    document.body.classList.toggle('panel-open', !!S.panel);
    document.body.classList.toggle('panel-wide', S.panel === 'Planning' || S.panel === 'Contracts');
    document.body.classList.toggle('panel-contracts', S.panel === 'Contracts');
  }
  function renderNotices() {
    const w = S.world || {}, parts = [];
    if (w.saveError) parts.push(`<div class="card notice error">${svg('save')}<span class="grow">${esc(w.saveError)}</span><button type="button" class="outline" data-action="retrySave">Retry save</button></div>`);
    if (w.awayReport) parts.push(`<div class="card notice">${svg('history')}<span class="grow">While you were away · ${esc(money(w.awayReport.profit))} · ${esc(w.awayReport.passengers)} passengers${w.awayReport.minutes ? `<br><span class="muted">${esc(w.awayReport.minutes)}</span>` : ''}</span><button type="button" class="icon" data-action="dismissAway" title="Dismiss away report" aria-label="Dismiss away report">${svg('close')}</button></div>`);
    for (const n of S.notices) parts.push(`<div class="card notice ${n.kind}" role="${n.kind === 'error' ? 'alert' : 'status'}"><span class="grow">${esc(n.text)}</span><button type="button" class="icon" data-dismiss="${n.id}" title="Dismiss message" aria-label="Dismiss message">${svg('close')}</button></div>`);
    const html = parts.join('');
    if (signatures.notices !== html) { signatures.notices = html; $('notices').innerHTML = html; }
    $('onboard').classList.toggle('hidden', !(S.world && !S.panel && !S.tool && !S.manage && w.paused && !list('flights').length));
  }
  function renderTool() {
    $('placement').classList.toggle('hidden', !S.tool);
    if (!S.tool) return;
    const cost = S.moveId ? '' : list('catalog').find(d => d.kind === S.tool)?.cost;
    $('placement-title').textContent = `${S.moveId ? 'Move' : 'Place'} ${facilityName(S.tool)}${typeof cost === 'number' ? ` · ${money(cost)}` : ''} · ${S.rotation * 90}°`;
    $('onboard').classList.add('hidden');
  }

  function renderPanel(force = false) {
    renderDock();
    const panel = $('panel');
    panel.classList.toggle('hidden', !S.panel);
    if (!S.panel) { signatures.panel = null; return; }
    $('panel-title').textContent = S.panel === 'Build' && S.airport ? 'Build · Airport' : S.panel;
    const builders = {Build: buildPanel, Contracts: contractsPanel, Planning: planningPanel, Schedule: schedulePanel, Finances: financesPanel};
    const [signature, render, after] = builders[S.panel]();
    const key = `${S.panel}|${signature}`;
    if (S.plan.drag?.moved && S.panel === 'Planning') return;
    if (!force && signatures.panel === key) { after?.(false); return; }
    signatures.panel = key;
    const body = $('panel-body'), scroll = body.scrollTop, scrollX = $('timeline')?.scrollLeft, samePanel = body.dataset.panel === S.panel;
    body.innerHTML = render();
    body.dataset.panel = S.panel;
    if (samePanel) { body.scrollTop = scroll; if (scrollX != null && $('timeline')) $('timeline').scrollLeft = scrollX; }
    after?.(true);
  }

  // Build: category tabs with preview cards.
  function buildPanel() {
    const selected = list('facilities').find(f => f.id === S.selected);
    // Airport mode offers the furnishings hall by hall, each tab led by the
    // hall itself so the terminal can grow from inside the mode too.
    const inTab = (d, c) => S.airport
      ? (d.interior ? zoneOf(d) === c : zones[c]?.building && d.kind === 'terminal')
      : (d.category || (d.interior ? 'interior' : 'apron')) === c;
    const tabs = S.airport ? Object.keys(zones) : outdoor;
    if (!tabs.includes(S.category)) S.category = tabs[0];
    const items = list('catalog').filter(d => !d.hidden && inTab(d, S.category));
    const zone = S.airport ? zones[S.category] : null;
    // Nothing zoned that way yet, and no old hall of that kind either.
    const missing = !!zone?.paint
      && !(S.world?.zones || []).some(z => z.zone === zone.paint)
      && !list('facilities').some(f => AirportSceneLogic.hallZone(f.kind) === zone.paint);
    const signature = JSON.stringify([selected, S.tool, S.moveId, S.category, S.airport, S.zone, missing, list('catalog').map(d => d.kind + d.cost), S.world?.vehicleCosts, list('vehicles').length, list('facilities').length, (S.world?.cash || 0) >= 0]);
    return [signature, () => {
      let html = '';
      if (S.airport) {
        html += `<div class="mode-banner">${svg('interior')}<span class="grow"><b>Airport mode</b><br><span class="sub">Roofs off · walls lowered · items snap to 1 m · green floor takes the item you are placing</span></span><button type="button" class="outline" data-action="exitAirport">${svg('exit')}Airfield</button></div>`;
        // Zoning: mark out the three parts of the terminal on the floor.
        html += '<div class="zone-bar">' + [['arrival', 'Arrival'], ['main', 'Main'], ['departure', 'Departure'], ['none', 'Erase']]
          .map(([id, label]) => `<button type="button" class="zone ${id} ${S.zone === id ? 'on' : ''}" data-zone="${id}">${esc(label)}</button>`).join('') + '</div>';
        html += S.zone
          ? `<div class="hint">Drag over the terminal floor to ${S.zone === 'none' ? 'rub the zone out' : `zone it as the ${esc(S.zone)} hall`}.</div>`
          : '<div class="hint">Zoning is free: drag over the floor to mark it out as the arrival, main or departure hall. What you can place somewhere follows the zone under it. Floor you leave unzoned counts as the main hall.</div>';
      }
      if (selected && S.airport) {
        html += `<div class="selected-card"><div class="title">${esc(facilityName(selected.kind))}</div>
          <div class="actions"><button type="button" class="filled" data-manage-open="${esc(selected.id)}">${svg('upgrade')}Manage</button><button type="button" data-action="move">${svg('move')}Move</button></div></div>`;
      }
      html += `<div class="tabs" role="tablist">${tabs.map(c => `<button type="button" role="tab" aria-selected="${c === S.category}" class="${c === S.category ? 'on' : ''}" data-category="${c}">${esc(zones[c] && S.airport ? zones[c].tab : categories[c])}</button>`).join('')}</div>`;
      if (!S.airport && S.category === 'terminal') html += '<div class="hint">Build terminal sections side by side to make one hall, then press <b>Airport</b> at the top to zone the floor (free) into the three parts, like the original game: the <b>arrival hall</b> on the road side where passengers check in and go through security, the <b>main hall</b> with shops and gates, and the <b>departure hall</b> for arriving passengers.</div>';
      if (zone) html += `<div class="hint">${esc(zone.hint)}</div>`;
      if (missing) html += `<div class="hint warn">Nothing is zoned as the ${esc(zone.tab.toLowerCase())} yet. Press <b>${esc(zone.tab.split(' ')[0])}</b> above and drag over the floor — zoning is free.</div>`;
      html += '<div class="cards">';
      for (const d of items) {
        const count = owned(d.kind) + (d.kind === 'terminal' ? list('facilities').filter(f => f.kind !== 'terminal' && AirportSceneLogic.hallKinds.has(f.kind)).length : 0), on = S.tool === d.kind && !S.moveId, affordable = (S.world?.cash ?? 0) >= d.cost;
        html += `<button type="button" class="build-card ${on ? 'on' : ''}" data-tool="${esc(d.kind)}" title="${esc(d.blurb || '')}">
          <span class="thumb"><img alt="" data-thumb="${esc(d.kind)}" ${thumbs.has(d.kind) ? `src="${thumbs.get(d.kind)}"` : ''}>${count ? `<span class="count">×${count}</span>` : ''}</span>
          <span class="card-name">${esc(d.name)}</span>
          <span class="card-meta"><span class="price ${affordable ? '' : 'neg'}">${esc(money(d.cost))}</span><span class="sub">${esc(d.width)}×${esc(d.depth)} m</span></span>
          <span class="card-blurb">${esc(d.blurb || '')}</span>
        </button>`;
      }
      html += '</div>';
      if (S.category === 'services') {
        html += '<div class="section">GROUND SERVICE VEHICLES</div>';
        html += '<div class="hint">Service vehicles live at a depot. Select a vehicle depot to buy fuel trucks, baggage tugs, buses and pushback tugs — new vehicles start at that depot.</div>';
      }
      return html;
    }, () => loadThumbnails(items)];
  }
  // Service vehicles are bought from a specific depot and start there.
  function depotShop(depot) {
    const fleet = kind => list('vehicles').filter(v => v.kind === kind).length;
    let html = '<div class="section">SERVICE VEHICLES AT THIS DEPOT</div>';
    if (!depot.connected) {
      html += '<div class="hint">Connect this depot to a service road before buying vehicles.</div>';
    }
    for (const kind of ['fuel', 'baggage', 'bus', 'pushback']) {
      const price = S.world?.vehicleCosts?.[kind];
      const blocked = !depot.connected || (S.world?.cash ?? 0) < (price ?? 120000);
      html += `<div class="row"><span class="icon-cell">${svg('truck')}</span><span class="grow"><span class="title">${esc(vehicleName(kind))}</span><br><span class="sub">${fleet(kind)} in service</span></span><button type="button" class="outline" data-buy="${kind}" data-depot="${esc(depot.id)}" ${blocked ? 'disabled' : ''}>Buy${typeof price === 'number' ? ` · ${esc(money(price))}` : ''}</button></div>`;
    }
    return html;
  }
  // ── Building management ───────────────────────────────────────────────
  // Clicking a building opens its own window, like the original game: a large
  // preview, General and Upgrade tabs, plus Flights on a stand and Vehicles at
  // a depot. The simulation owns levels and prices; this only asks for them.
  const upgradeCostAt = (cost, level) => Math.max(1000, Math.round(cost * .4 * level / 1000) * 1000);
  const MAX_LEVEL = 5;
  const categoryName = def => ({airfield: 'Airfield', apron: 'Apron & stands', services: 'Airport services', terminal: 'Terminal', interior: 'Passenger flow', shops: 'Shops & lounges', decor: 'Decor'}[def?.category] || 'Building');
  function manageTabs(f) {
    const tabs = [['general', 'General', 'info'], ['upgrade', 'Upgrade', 'upgrade']];
    if (standKinds.has(f.kind)) tabs.push(['flights', 'Flights', 'Fleet']);
    if (f.kind === 'vehicleDepot') tabs.push(['vehicles', 'Vehicles', 'truck']);
    return tabs;
  }
  /** What [f] offers to upgrade, each with its current level and next price. */
  function upgradesOf(f, def) {
    const list = def?.upgrades?.length ? def.upgrades : def?.upgrade ? [{id: 'main', ...def.upgrade}] : [];
    return list.map(u => ({...u, level: f.levels?.[u.id] ?? (u === list[0] ? f.level || 1 : 1), cost: f.upgradeCosts ? f.upgradeCosts[u.id] ?? null : u === list[0] ? f.upgradeCost ?? null : null}));
  }
  function invested(f, def) {
    let total = def?.cost || 0;
    for (const u of upgradesOf(f, def)) for (let level = 1; level < u.level; level++) total += upgradeCostAt(def?.cost || 0, level);
    return total;
  }
  function standFlights(f) {
    return list('flights').filter(x => x.standId === f.id && !['completed', 'cancelled'].includes(x.stage)).sort((a, b) => (a.arrival || 0) - (b.arrival || 0));
  }
  function renderManage(force = false) {
    const box = $('manage');
    const f = S.manage && list('facilities').find(x => x.id === S.manage.id);
    if (!f) {
      if (S.manage && S.world) S.manage = null;
      box.classList.add('hidden');
      signatures.manage = null;
      return;
    }
    box.classList.remove('hidden');
    const def = list('catalog').find(d => d.kind === f.kind);
    const tabs = manageTabs(f);
    if (!tabs.some(([id]) => id === S.manage.tab)) S.manage.tab = 'general';
    const tab = S.manage.tab, cash = S.world?.cash ?? 0;
    const flights = tab === 'flights' ? standFlights(f).slice(0, 30) : [];
    const upgrades = upgradesOf(f, def);
    const signature = JSON.stringify([f, upgrades, tab, S.manage.confirm, upgrades.map(u => cash >= (u.cost ?? Infinity)),
      flights.map(x => [x.id, x.stage, x.arrival, x.departure]),
      tab === 'vehicles' ? [list('vehicles').map(v => v.kind), S.world?.vehicleCosts, Object.values(S.world?.vehicleCosts || {}).map(p => cash >= p)] : 0]);
    if (!force && signatures.manage === signature) return;
    signatures.manage = signature;
    $('manage-title').textContent = `${facilityName(f.kind)}${standKinds.has(f.kind) ? ` ${standCode(f)}` : ''}`;
    const level = upgrades[0]?.level || 1;
    $('manage-level').textContent = upgrades.length ? `Level ${upgrades.reduce((n, u) => n + u.level, 0) - upgrades.length + 1}` : '';
    $('manage-level').classList.toggle('hidden', !upgrades.length);
    $('manage-tabs').innerHTML = tabs.map(([id, label, icon]) => `<button type="button" role="tab" aria-selected="${id === tab}" class="${id === tab ? 'on' : ''}" data-manage-tab="${id}">${svg(icon)}<span>${esc(label)}</span></button>`).join('');
    const key = `manage:${f.kind}:${f.width}x${f.depth}`;
    let html = `<div class="manage-grid"><div>
      <div class="manage-preview"><img alt="" data-manage-thumb="${esc(key)}" ${thumbs.get(key) ? `src="${thumbs.get(key)}"` : ''}>
        <button type="button" class="icon trash" data-manage="demolish" title="Demolish" aria-label="Demolish ${esc(facilityName(f.kind))}">${svg('trash')}</button></div>
      <div class="manage-desc"><div class="kicker">${esc(categoryName(def))}</div><p>${esc(def?.blurb || '')}</p></div>
    </div><div>`;
    if (tab === 'general') {
      const stat = (label, value) => `<div class="stat"><span class="label">${esc(label)}</span><span class="value">${value}</span></div>`;
      html += '<div class="stat-list">';
      html += stat('Status', f.connected ? '<span class="badge ok">Connected</span>' : '<span class="badge warn">Disconnected</span>');
      for (const u of upgrades) html += stat(u.attribute, `Level ${u.level} of ${MAX_LEVEL}`);
      html += stat('Footprint', `${esc(f.width)} × ${esc(f.depth)} m`);
      html += stat('In use', f.protected ? 'Yes · locked for flights' : 'No');
      if (standKinds.has(f.kind)) html += stat('Planned flights', String(standFlights(f).length));
      if (f.kind === 'vehicleDepot') html += stat('Vehicles based here', String(list('vehicles').length));
      html += stat('Invested', esc(money(invested(f, def))));
      html += '</div>';
      if (!f.connected) html += `<div class="hint" style="padding:10px 0 0">${f.kind === 'terminalLandside' ? 'Place an entrance in this arrival hall so passengers can get in.' : isHall(f.kind) ? 'Join this hall to an arrival hall that has an entrance, so passengers can get in.' : 'Connect it to the rest of the airport with taxiways, service roads or a terminal to put it to work.'}</div>`;
      html += '<div class="manage-actions">';
      if (isHall(f.kind)) html += `<button type="button" class="filled" data-action="interior">${svg('interior')}Airport mode</button>`;
      html += `<button type="button" class="outline" data-manage="focus">${svg('focus')}Focus camera</button><button type="button" class="outline" data-manage="move">${svg('move')}Move</button>`;
      if (upgrades.some(u => u.cost != null)) html += `<button type="button" class="outline" data-manage-tab="upgrade">${svg('upgrade')}Upgrade</button>`;
      html += '</div>';
    } else if (tab === 'upgrade') {
      if (!upgrades.length) {
        html += '<div class="empty" style="padding:0">This building has no upgrades. It already does everything it can.</div>';
      }
      for (const u of upgrades) {
        const maxed = u.cost == null || u.level >= MAX_LEVEL, affordable = !maxed && cash >= u.cost;
        html += `<div class="upgrade">
          <div class="up-head"><span class="up-name">${esc(u.attribute)}</span><span class="up-levels">${u.level}${maxed ? '' : `<span class="arrow">→</span><span class="pos">${u.level + 1}</span>`}</span></div>
          <div class="up-bar" role="progressbar" aria-label="${esc(u.attribute)} level" aria-valuemin="1" aria-valuemax="${MAX_LEVEL}" aria-valuenow="${u.level}">${Array.from({length: MAX_LEVEL}, (_, i) => `<span class="${i < u.level ? 'on' : i === u.level && !maxed ? 'next' : ''}"></span>`).join('')}</div>
          <p class="up-effect">${esc(u.effect)}</p>
          ${maxed ? `<div class="up-max">${svg('star')}Maximum level</div>` : `<button type="button" class="filled up-buy" data-manage="upgrade" data-attribute="${esc(u.id)}" ${affordable ? '' : 'disabled'} title="Upgrade ${esc(u.attribute.toLowerCase())} to level ${u.level + 1}">${svg('upgrade')}${esc(exactMoney(u.cost))}</button>`}
          ${!maxed && !affordable ? `<div class="sub neg" style="margin-top:6px">You need ${esc(money(u.cost - cash))} more cash.</div>` : ''}
        </div>`;
      }
    } else if (tab === 'flights') {
      if (!flights.length) html += '<div class="empty" style="padding:0">No flights are planned on this stand.</div>';
      for (const x of flights) {
        html += `<div class="flight-row" style="--livery:${livery(x.carrier)}"><span class="dot"></span><span class="grow"><b>${esc(x.carrier || 'Own flight')}</b> · ${esc(modelName(x.modelId))}<br><span class="sub">${esc(flightTime(x.arrival))}–${esc(clockText(x.departure || 0))} · ${esc(stageName(x.stage))}</span></span></div>`;
      }
      html += `<div class="manage-actions"><button type="button" class="outline" data-open-plan="">${svg('Planning')}Open planning</button></div>`;
    } else if (tab === 'vehicles') {
      html += depotShop(f);
    }
    html += '</div></div>';
    if (S.manage.confirm) {
      html += `<div class="confirm" role="alertdialog" aria-label="Confirm demolition"><span class="grow"><b>Demolish ${esc(facilityName(f.kind))}?</b><br><span class="sub">You get ${esc(money(Math.round(invested(f, def) * .5)))} back. This cannot be undone.</span></span><button type="button" class="outline" data-manage="keep">Keep it</button><button type="button" class="filled danger" data-manage="demolishNow">${svg('trash')}Demolish</button></div>`;
    }
    const body = $('manage-body'), scroll = body.scrollTop;
    body.innerHTML = html;
    body.scrollTop = scroll;
    if (!thumbs.has(key) && scene?.thumbnail) {
      thumbs.set(key, '');
      scene.thumbnail({kind: f.kind, width: f.width, depth: f.depth, height: def?.height || 4}, {width: 480, height: 300}).then(url => {
        thumbs.set(key, url);
        for (const img of document.querySelectorAll(`img[data-manage-thumb="${CSS.escape(key)}"]`)) img.src = url;
      });
    }
    if (force) body.querySelector('button')?.blur();
  }
  function manageAction(action, attribute) {
    const f = list('facilities').find(x => x.id === S.manage?.id);
    if (!f) return;
    if (action === 'upgrade') command('upgrade', {facilityId: f.id, attribute: attribute || ''});
    else if (action === 'focus') { scene.view('focus', null, f.id); S.manage = null; renderManage(true); }
    else if (action === 'move') { S.manage = null; renderManage(true); S.rotation = Number(f.rotation) || 0; setTool(f.kind, f.id); }
    else if (action === 'demolish') { S.manage.confirm = true; renderManage(true); }
    else if (action === 'keep') { S.manage.confirm = false; renderManage(true); }
    else if (action === 'demolishNow') command('demolish', {facilityId: f.id}, () => closeManage());
  }

  function loadThumbnails(items) {
    if (!scene?.thumbnail) return;
    for (const d of items) {
      if (thumbs.has(d.kind)) continue;
      thumbs.set(d.kind, '');
      scene.thumbnail(d).then(url => {
        thumbs.set(d.kind, url);
        for (const img of document.querySelectorAll(`img[data-thumb="${CSS.escape(d.kind)}"]`)) img.src = url;
      });
    }
  }

  // Contracts: airline offers to sign; signed ones wait in Planning's holding bar.
  const rules = () => S.world?.rules || {slots: {EAM: [0, 360], AM: [360, 720], AN: [720, 1080], PM: [1080, 1440]}, haulMinutes: {SH: 180, MH: 240, LH: 360}, exitMinutes: 30, horizonDays: 14};
  const slotText = slot => { const w = rules().slots[slot]; return w ? `${slot} ${pad(w[0] / 60)}–${pad(w[1] / 60)}` : 'Any time'; };
  const contractType = o => o.type === 'charter' ? `Charter · ${o.flights} flight${o.flights === 1 ? '' : 's'}` : `Daily · ${o.flights} days`;
  function activeContracts() {
    return list('contracts').filter(c => !c.cancelled && ((c.remaining || 0) > 0 || (c.scheduled || 0) > 0 || list('flights').some(f => f.contractId === c.id && !['completed', 'cancelled'].includes(f.stage))));
  }
  const holding = () => list('contracts').filter(c => !c.cancelled && (c.remaining || 0) > 0);
  function contractsPanel() {
    const ui = S.contractsUi;
    const signature = JSON.stringify([list('offers'), list('contracts'), S.world?.day, ui, list('flights').filter(f => f.contractId).map(f => [f.id, f.stage])]);
    const refresh = () => {
      const t = S.world?.time || 0, left = 1440 - (((t % 1440) + 1440) % 1440);
      const clock = $('ct-refresh'), bar = $('ct-refresh-bar');
      if (clock) clock.textContent = `${Math.floor(left / 60)}h ${pad(Math.floor(left % 60))}m`;
      if (bar) bar.style.width = `${(1 - left / 1440) * 100}%`;
    };
    return [signature, () => {
      const offers = list('offers'), waiting = holding(), active = activeContracts();
      const signed = active.length;
      const tab = (id, label, count) => `<button type="button" class="ct-tab${ui.tab === id ? ' on' : ''}" data-contract-tab="${id}" aria-pressed="${ui.tab === id}">${label}<span>${count}</span></button>`;
      let html = `<div class="ct">
        <div class="ct-head">
          <div class="ct-box ct-refresh"><span class="ct-label">New offers in</span><b id="ct-refresh" class="num">–</b><div class="ct-track"><span id="ct-refresh-bar"></span></div></div>
          <div class="ct-box ct-stat"><span class="ct-label">Offers open</span><b class="num">${offers.length}</b></div>
          <div class="ct-box ct-stat"><span class="ct-label">Waiting to plan</span><b class="num${waiting.length ? ' warn' : ''}">${waiting.length}</b></div>
          <button type="button" class="ct-plan" data-open-plan="">${svg('Planning')}<span>Planning</span></button>
        </div>
        <div class="ct-tabs" role="tablist">${tab('offers', 'Airline offers', offers.length)}${tab('signed', 'Signed contracts', signed)}</div>
        <div class="ct-scroll">`;
      if (ui.tab === 'offers') {
        html += `<table class="ct-table"><thead><tr><th>Airline</th><th>Total reward</th><th>Time</th><th>Aircraft</th><th>Flight</th><th>Requirements &amp; services</th><th></th></tr></thead><tbody>`;
        if (!offers.length) html += '<tr><td colspan="7" class="empty">No airlines are looking for a hub right now. New offers arrive at midnight.</td></tr>';
        for (const o of offers) {
          const open = ui.open === o.id;
          html += `<tr class="${open ? 'open' : ''}${o.blockedReason ? ' blocked' : ''}">
            ${airlineCell(o.carrier)}
            <td class="num reward">${esc(exactMoney(o.total ?? o.fee * o.flights))}</td>
            <td><span class="slot slot-${esc(o.slot)}" title="${esc(slotText(o.slot))}">${esc(o.slot === 'ALL' ? 'ANY' : o.slot)}</span></td>
            <td class="craft">${svg('Fleet')}<span><b>${esc(modelName(o.modelId))}</b><span class="sub">${esc(haulName(o.haul))}</span></span></td>
            <td><b>${o.type === 'charter' ? 'Charter' : 'Regular'}</b><span class="sub">${esc(o.flights)} ${o.type === 'charter' ? 'flights' : 'days'}</span></td>
            <td><span class="svc">${serviceIcons(o)}</span></td>
            <td><button type="button" class="ct-details" data-contract-open="${esc(o.id)}" aria-expanded="${open}">Contract details${svg(open ? 'up' : 'down')}</button></td>
          </tr>`;
          if (open) html += `<tr class="ct-more"><td colspan="7">${offerDetails(o)}</td></tr>`;
        }
        html += '</tbody></table>';
      } else {
        html += `<table class="ct-table"><thead><tr><th>Airline</th><th>Total reward</th><th>Time</th><th>Aircraft</th><th>Progress</th><th>Satisfaction</th><th></th></tr></thead><tbody>`;
        if (!active.length) html += '<tr><td colspan="7" class="empty">No signed contracts. Pick one from Airline offers.</td></tr>';
        for (const c of active) {
          const o = c.offer || {flights: 0, fee: 0, slot: 'ALL'};
          const flown = list('flights').filter(f => f.contractId === c.id && f.stage === 'completed').length;
          const sat = Math.round((c.satisfaction || 0) * 100);
          html += `<tr>
            ${airlineCell(c.carrier)}
            <td class="num reward">${esc(exactMoney(o.fee * o.flights))}</td>
            <td><span class="slot slot-${esc(o.slot)}" title="${esc(slotText(o.slot))}">${esc(o.slot === 'ALL' ? 'ANY' : o.slot)}</span></td>
            <td class="craft">${svg('Fleet')}<span><b>${esc(modelName(o.modelId))}</b><span class="sub">${esc(haulName(o.haul))}</span></span></td>
            <td><b>${flown} / ${esc(o.flights)} flown</b><span class="sub">${esc(c.scheduled || 0)} planned${c.remaining ? ` · <span class="warn">${esc(c.remaining)} to plan by day ${esc(c.deadlineDay)}</span>` : ''}</span></td>
            <td><div class="sat"><span style="width:${sat}%;background:${sat >= 70 ? 'var(--success)' : sat >= 40 ? 'var(--warning)' : 'var(--danger)'}"></span></div><span class="sub num">${sat}%</span></td>
            <td class="ct-actions">${c.remaining ? `<button type="button" class="filled" data-open-plan="${esc(c.id)}">Plan</button>` : ''}<button type="button" class="outline danger" data-cancel-contract="${esc(c.id)}" title="Cancel: ${esc(exactMoney(c.cancelCost || 0))} penalty">Cancel</button></td>
          </tr>`;
        }
        html += '</tbody></table>';
      }
      html += `</div><div class="ct-foot"><span>Sign a contract, then drag it onto a stand in Planning.</span><span>Current contracts signed: <b class="num">${signed}</b></span></div></div>`;
      return html;
    }, refresh];
  }
  const haulName = h => ({SH: 'Short haul', MH: 'Medium haul', LH: 'Long haul'}[h] || '');
  function airlineCell(carrier) {
    return `<td class="airline" style="--livery:${livery(carrier)}"><span class="mark">${svg('tail')}</span><span class="name">${esc(carrier)}</span></td>`;
  }
  const serviceIcon = {fuelDepot: 'fuel', baggage: 'bag', cafe: 'cup', seating: 'seat', lounge: 'star', toilets: 'wc', shop: 'shop', vehicleDepot: 'truck'};
  function serviceIcons(o) {
    return (o.requiredServices || []).map(k => `<span class="svc-icon" title="${esc(facilityName(k))}" aria-label="${esc(facilityName(k))}">${svg(serviceIcon[k] || 'Build')}</span>`).join('');
  }
  function offerDetails(o) {
    const day = S.world?.day ?? 1;
    const left = o.expiresDay == null ? 'Always available' : o.expiresDay === day ? 'Expires today' : `Open until day ${o.expiresDay}`;
    return `<div class="ct-detail">
      <dl>
        <div><dt>Per flight</dt><dd class="num">${esc(exactMoney(o.fee))}</dd></div>
        <div><dt>Passengers</dt><dd class="num">${esc(o.passengers)}</dd></div>
        <div><dt>Arrival window</dt><dd>${esc(slotText(o.slot))}</dd></div>
        <div><dt>Stand time</dt><dd>${esc(o.standMinutes / 60)} h</dd></div>
        <div><dt>Runway</dt><dd class="num">${esc(o.runwayM)} m</dd></div>
        <div><dt>Missed flight</dt><dd class="num neg">${esc(exactMoney(-o.penalty))}</dd></div>
        <div><dt>Plan within</dt><dd>${esc(o.placementDays)} days of signing</dd></div>
        <div><dt>Offer</dt><dd>${esc(left)}</dd></div>
      </dl>
      <div class="ct-sign">
        <span class="sub">Needs ${esc((o.requiredServices || []).map(facilityName).join(', ') || 'no extra services')}</span>
        ${o.blockedReason ? `<p class="blocked" role="alert">${esc(o.blockedReason)}</p>` : ''}
        <button type="button" class="filled" data-accept="${esc(o.id)}" ${o.blockedReason ? 'disabled' : ''}>Sign contract</button>
      </div></div>`;
  }

  // Planning: a holding bar of signed contracts over a stands × time board
  // that runs from today to the end of the planning horizon.
  const HOUR = 48, ROW = 50, SNAP = 10;
  const planStart = () => Math.floor((S.world?.time || 0) / 1440) * 1440;
  const planDays = () => rules().horizonDays || 14;
  const xOf = minutes => (minutes - planStart()) / 60 * HOUR;
  function flightFee(f) {
    const c = list('contracts').find(x => x.id === f.contractId);
    return c?.offer ? c.offer.fee : null;
  }
  function slotOk(slot, arrival) {
    const w = rules().slots[slot];
    if (!w) return true;
    const m = ((arrival % 1440) + 1440) % 1440;
    return m >= w[0] && m < w[1];
  }
  /** Busy windows on a stand, as [from, to) minutes, mirroring the simulation. */
  function busy(standId, ignore) {
    const out = [];
    for (const f of list('flights')) {
      if (f.standId !== standId || f.id === ignore || ['completed', 'cancelled'].includes(f.stage)) continue;
      out.push([f.arrival, f.departure + 30]);
      if (f.returnAt > 0) out.push([f.returnAt - 10, f.returnAt + 40]);
    }
    return out;
  }
  /** Client-side preview of what the simulation will say; it has the final word. */
  function planCheck(drag, standId, arrival) {
    const stand = stands().find(s => s.id === standId), now = S.world?.time || 0;
    const haul = drag.haul, exit = rules().exitMinutes;
    if (!stand) return 'Drop on a stand';
    if (haul !== 'SH' && stand.kind === 'standRegional') return 'Regional stands only take short haul';
    if (!stand.connected) return 'Stand is not connected';
    if (arrival < now + 30) return 'At least 30 min ahead';
    if (arrival > now + planDays() * 1440) return `Only ${planDays()} days ahead`;
    const c = drag.contract;
    if (c && !slotOk(c.offer.slot, arrival)) return `${c.carrier} starts in ${slotText(c.offer.slot)}`;
    const day = Math.floor(arrival / 1440) + 1;
    if (c && drag.kind === 'contract' && c.offer.type !== 'charter' && day > c.deadlineDay) return `Must start by day ${c.deadlineDay}`;
    if (c && drag.kind === 'contract' && c.offer.type === 'charter' && day > c.signedDay + c.offer.placementDays) return `Must fly by day ${c.signedDay + c.offer.placementDays}`;
    const windows = busy(standId, drag.flightId);
    const count = drag.kind === 'contract' && c.offer.type !== 'charter' ? c.remaining : 1;
    for (let d = 0; d < count; d++) {
      const a = arrival + d * 1440, dep = a + drag.duration - exit;
      if (windows.some(([from, to]) => a < to && dep + 30 > from)) return count > 1 ? `Busy on day ${Math.floor(a / 1440) + 1}` : 'Stand is busy';
    }
    return null;
  }
  function planningPanel() {
    const w = S.world || {}, now = w.time || 0, start = planStart(), days = planDays();
    const today = Math.floor(now / 1440) + 1;
    const rows = stands();
    const waiting = holding();
    const signature = JSON.stringify([today, Math.floor(now / 10), rows.map(r => [r.id, r.kind, r.connected]), list('flights').map(f => [f.id, f.stage, f.standId, f.arrival, f.delay, f.boarded, f.returnAt]), waiting.map(c => [c.id, c.remaining, c.deadlineDay]), S.plan.focus, S.plan.slot, S.plan.card, list('fleet').length, list('routes').length]);
    return [signature, () => {
      let html = `<div class="plan-head"><button type="button" class="icon" data-plan-jump="-1" title="Earlier" aria-label="Earlier">${svg('left')}</button><button type="button" class="outline" data-plan-jump="0">Now</button><button type="button" class="icon" data-plan-jump="1" title="Later" aria-label="Later">${svg('right')}</button>
        <span class="legend">${Object.keys(rules().slots).map(k => `<span class="chip slot-${k}">${esc(slotText(k))}</span>`).join('')}</span><span class="grow"></span>
        <span class="sub">Drag contracts onto a stand · drag flights to move them · drop a flight on the bar to unplan it · click an empty slot to fly your own aircraft</span></div>`;
      html += `<div id="holding" class="holding">${waiting.length ? waiting.map(c => {
        const o = c.offer || {};
        return `<div class="hold-card ${S.plan.card === c.id ? 'on' : ''}" data-hold="${esc(c.id)}" style="--livery:${livery(c.carrier)}" title="Drag onto a stand">
          <b>${esc(c.carrier)}</b><span class="badge haul-${esc(o.haul)}">${esc(o.haul)}</span>
          <span class="hold-line"><span class="chip slot-${esc(o.slot)}">${esc(slotText(o.slot))}</span>${esc(o.type === 'charter' ? `${c.remaining} charter` : `${c.remaining}× daily`)}</span>
          <span class="hold-line">${esc(o.passengers)} pax · ${esc(money(o.fee))} · ${esc(o.standMinutes / 60)} h</span>
          <span class="hold-line ${c.deadlineDay <= today ? 'neg' : 'sub'}">Plan by day ${esc(c.deadlineDay)}</span>
        </div>`;
      }).join('') : '<span class="empty">Holding bar · signed contracts wait here. Sign one in Contracts.</span>'}</div>`;
      if (!rows.length) return html + '<div class="empty">Build an aircraft stand to start planning.</div>';
      const total = days * 24 * HOUR;
      html += `<div id="timeline" class="timeline" style="--hour:${HOUR}px;--row:${ROW}px;--width:${total}px">`;
      html += `<div class="tl-corner">Day</div><div class="tl-days">${Array.from({length: days}, (_, d) => `<span style="left:${d * 24 * HOUR}px;width:${24 * HOUR}px" class="${d === 0 ? 'today' : ''}">Day ${today + d}${d === 0 ? ' · today' : ''}</span>`).join('')}</div>`;
      html += `<div class="tl-corner lower">Slot</div><div class="tl-slots">${Array.from({length: days}, (_, d) => Object.entries(rules().slots).map(([k, [a, b]]) => `<span class="chip slot-${k}" style="left:${(d * 1440 + a) / 60 * HOUR}px;width:${(b - a) / 60 * HOUR - 2}px">${k}</span>`).join('')).join('')}</div>`;
      html += `<div class="tl-corner lowest">Stand</div><div class="tl-hours">${Array.from({length: days * 24}, (_, h) => `<span style="left:${h * HOUR}px">${pad(h % 24)}</span>`).join('')}</div>`;
      for (const r of rows) {
        html += `<div class="tl-stand ${r.connected ? '' : 'off'}" data-row="${esc(r.id)}"><b>${esc(standCode(r))}</b><span class="badge">${standClass(r)}</span>${r.kind === 'standContact' ? `<span class="bridge" title="Jet bridge">${svg('bridge')}</span>` : ''}${r.connected ? '' : '<span class="badge warn">Off</span>'}</div>`;
        html += `<div class="tl-row" data-row="${esc(r.id)}" data-slot-row="${esc(r.id)}"><div class="past" style="width:${Math.max(0, xOf(now))}px"></div>`;
        for (const f of list('flights')) {
          if (f.standId !== r.id) continue;
          if (f.stage === 'cancelled' && f.departure < now - 60) continue;
          const spans = [{from: f.arrival, to: f.departure + rules().exitMinutes, kind: 'turn'}];
          if (f.returnAt > 0) spans.push({from: f.returnAt - 10, to: f.returnAt + 40, kind: 'return'});
          for (const b of spans) {
            if (b.to < start || b.from > start + days * 1440) continue;
            const left = Math.max(0, xOf(b.from)), right = xOf(b.to);
            const done = f.stage === 'completed', cancelled = f.stage === 'cancelled';
            const live = !done && !cancelled && f.stage !== 'scheduled' && f.stage !== 'enRoute';
            const draggable = f.stage === 'scheduled' && b.kind === 'turn';
            const fee = flightFee(f);
            html += `<div class="block ${b.kind} ${done ? 'done' : ''} ${cancelled ? 'cancelled' : ''} ${live ? 'active' : ''} ${S.plan.focus === f.id ? 'focus' : ''}" style="left:${left}px;width:${Math.max(24, right - left - 2)}px;--livery:${livery(f.carrier)}" data-flight="${esc(f.id)}" ${draggable ? 'data-draggable="1"' : ''} title="${esc(`${f.carrier} ${f.id.toUpperCase()} · ${modelName(f.modelId)} · ${flightTime(b.from)}–${clockText(b.to)}`)}">
              <span class="b-top"><b>${esc(f.carrier)}</b></span>
              <span class="b-mid">${b.kind === 'return' ? 'Return' : esc(f.id.toUpperCase())} · ${esc(modelClass(f.modelId))} · ${esc(f.passengers ?? 0)} pax</span>
              <span class="b-low">${clockText(b.from)}–${clockText(b.to)} · ${fee != null ? esc(money(fee)) : b.kind === 'return' ? 'Inbound' : 'Own flight'}</span>
            </div>`;
          }
        }
        html += '</div>';
      }
      html += `<div class="tl-now" style="left:calc(var(--stand-col) + ${xOf(now)}px);height:${rows.length * ROW + 64}px"></div>`;
      html += '</div>';
      html += planDetail();
      return html;
    }, fresh => {
      if (fresh && S.plan.scrollTo != null) {
        const t = $('timeline');
        if (t) t.scrollLeft = Math.max(0, xOf(S.plan.scrollTo) - 2 * HOUR);
        S.plan.scrollTo = null;
      }
    }];
  }
  function planDetail() {
    if (S.plan.slot) {
      const {standId, time} = S.plan.slot, fleet = list('fleet'), routes = list('routes');
      let html = `<div class="plan-detail"><div class="grow"><b>Fly your own aircraft from ${esc(standName(standId))}</b><br><span class="sub">Boarding from ${esc(flightTime(time))} · departs ${esc(clockText(time + 80))}</span></div>`;
      if (!fleet.length || !routes.length) html += '<span class="sub">Buy an aircraft in Fleet and open a route in Routes first.</span>';
      else {
        const q = S.schedule;
        if (!fleet.some(a => a.id === q.aircraft)) q.aircraft = fleet[0].id;
        if (!routes.some(r => r.id === q.route)) q.route = routes[0].id;
        html += `<label>Aircraft<select data-field="aircraft">${fleet.map(a => `<option value="${esc(a.id)}" ${a.id === q.aircraft ? 'selected' : ''}>${esc(a.registration)} · ${esc(modelName(a.modelId))}</option>`).join('')}</select></label>
          <label>Route<select data-field="route">${routes.map(r => `<option value="${esc(r.id)}" ${r.id === q.route ? 'selected' : ''}>${esc(S.world?.hubIata || '')} → ${esc(r.destIata)}</option>`).join('')}</select></label>
          <button type="button" class="filled" data-action="planSchedule">${svg('plus')}Schedule</button>`;
      }
      return html + `<button type="button" class="icon" data-action="planClose" title="Close" aria-label="Close">${svg('close')}</button></div>`;
    }
    const card = holding().find(c => c.id === S.plan.card);
    if (card) {
      const o = card.offer;
      return `<div class="plan-detail" style="--livery:${livery(card.carrier)}"><span class="swatch"></span><div class="grow"><b>${esc(card.carrier)}</b> <span class="badge">${esc(o.haul)}</span><br>
        <span class="sub">${esc(contractType(o))} · ${esc(card.remaining)} left to plan · ${esc(slotText(o.slot))} · ${esc(o.standMinutes / 60)} h per flight · plan by day ${esc(card.deadlineDay)}</span><br>
        <span class="sub">Drag this card onto a ${o.haul === 'SH' ? '' : 'remote or contact '}stand. Green means the whole ${o.type === 'charter' ? 'flight' : 'series'} fits.</span></div>
        <button type="button" class="danger" data-cancel-contract="${esc(card.id)}">${svg('trash')}Cancel · ${esc(exactMoney(card.cancelCost || 0))}</button>
        <button type="button" class="icon" data-action="planClose" title="Close" aria-label="Close">${svg('close')}</button></div>`;
    }
    const f = list('flights').find(x => x.id === S.plan.focus);
    if (!f) return '';
    const fee = flightFee(f);
    return `<div class="plan-detail" style="--livery:${livery(f.carrier)}"><span class="swatch"></span><div class="grow"><b>${esc(f.carrier)} · ${esc(f.id.toUpperCase())}</b> <span class="badge">${esc(modelClass(f.modelId))}</span><br>
      <span class="sub">${esc(modelName(f.modelId))} · ${esc(standName(f.standId))} · ${esc(flightTime(f.arrival))}–${esc(clockText(f.departure))}${f.returnAt ? ` · back ${esc(flightTime(f.returnAt))}` : ''}</span><br>
      <span class="sub">${esc(stageName(f.stage))} · Boarded ${esc(f.boarded ?? 0)}/${esc(f.passengers ?? 0)} · Delay ${Math.round(f.delay || 0)} min${fee != null ? ` · Fee ${esc(money(fee))}` : ''}${f.issue ? ` · <span class="neg">${esc(f.issue)}</span>` : ''}</span></div>
      <button type="button" data-action="planFocusStand" data-stand="${esc(f.standId)}">${svg('focus')}Show stand</button>
      ${f.stage === 'scheduled' ? `<button type="button" data-unschedule="${esc(f.id)}">${svg('exit')}${f.contractId ? 'Back to holding bar' : 'Remove'}</button>${f.contractId ? `<button type="button" class="danger" data-cancel-flight="${esc(f.id)}">${svg('trash')}Cancel (penalty)</button>` : ''}` : ''}
      <button type="button" class="icon" data-action="planClose" title="Close" aria-label="Close">${svg('close')}</button></div>`;
  }

  function schedulePanel() {
    const fleet = list('fleet'), routes = list('routes'), standList = stands(), q = S.schedule;
    if (!fleet.some(a => a.id === q.aircraft)) q.aircraft = fleet[0]?.id ?? null;
    if (!routes.some(r => r.id === q.route)) q.route = routes[0]?.id ?? null;
    if (!standList.some(s => s.id === q.stand)) q.stand = '';
    const board = list('flights').slice(-100).reverse();
    const signature = JSON.stringify([fleet, routes, standList.map(s => s.id), q, board.map(f => [f.id, f.stage, f.boarded, f.delay, f.standId])]);
    return [signature, () => {
      const option = (value, label, current) => `<option value="${esc(value)}" ${String(value) === String(current) ? 'selected' : ''}>${esc(label)}</option>`;
      let html = '<div class="section">SCHEDULE YOUR FLEET</div>';
      if (!fleet.length || !routes.length) {
        html += '<div class="empty">Buy an aircraft in Fleet and open a route in Routes first.</div>';
      } else {
        html += `<div class="form">
          <label>Aircraft<select data-field="aircraft">${fleet.map(a => option(a.id, `${a.registration} · ${modelName(a.modelId)}`, q.aircraft)).join('')}</select></label>
          <label>Route<select data-field="route">${routes.map(r => option(r.id, `${S.world?.hubIata || ''} → ${r.destIata}`, q.route)).join('')}</select></label>
          <label>Stand<select data-field="stand">${option('', 'Automatic assignment', q.stand)}${standList.map(s => option(s.id, standName(s.id), q.stand)).join('')}</select></label>
          <label>Departure<select data-field="delay">${[[120, 'In 2 game hours'], [240, 'In 4 game hours'], [480, 'In 8 game hours'], [1440, 'In 24 game hours']].map(([v, l]) => option(v, l, q.delay)).join('')}</select></label>
          <button type="button" class="filled" data-action="schedule">${svg('plus')}Schedule flight</button></div>`;
      }
      html += '<div class="section">FLIGHT BOARD</div>';
      if (!board.length) html += '<div class="empty">No flights scheduled. Accept a contract or schedule your fleet.</div>';
      for (const f of board) {
        const done = f.stage === 'completed' || f.stage === 'cancelled';
        html += `<div class="row"><span class="swatch" style="background:${livery(f.carrier)}"></span><span class="grow"><span class="title">${esc(f.carrier)} · ${esc(modelName(f.modelId))}</span><br><span class="sub">${esc(stageName(f.stage))} · ${esc(standName(f.standId))} · ${esc(flightTime(f.departure))}</span><br><span class="sub">Boarded ${esc(f.boarded ?? 0)}/${esc(f.passengers ?? 0)} · Delay ${Math.round(f.delay ?? 0)} min</span></span>${done ? '' : `<button type="button" class="icon danger" data-cancel-flight="${esc(f.id)}" title="Cancel flight" aria-label="Cancel flight">${svg('close')}</button>`}</div>`;
      }
      return html;
    }];
  }

  function financesPanel() {
    const ledger = list('ledger');
    const signature = JSON.stringify([S.world?.cash, ledger.length, ledger[ledger.length - 1]]);
    return [signature, () => {
      const day = S.world?.day ?? 1, today = ledger.filter(e => Math.floor((e.time || 0) / 1440) + 1 === day);
      const byCategory = {};
      for (const e of today) byCategory[e.category] = (byCategory[e.category] || 0) + (e.amount || 0);
      let html = `<div class="row"><span class="grow title">Available cash</span><span class="amount">${esc(money(S.world?.cash))}</span></div>`;
      html += `<div class="section">TODAY BY CATEGORY</div>`;
      const entries = Object.entries(byCategory).sort((a, b) => b[1] - a[1]);
      if (!entries.length) html += '<div class="empty">No transactions yet today.</div>';
      const peak = Math.max(1, ...entries.map(([, v]) => Math.abs(v)));
      for (const [category, amount] of entries) html += `<div class="row bar-row"><span class="grow">${esc(friendly(category))}</span><span class="bar"><span class="${amount < 0 ? 'neg-bar' : 'pos-bar'}" style="width:${Math.abs(amount) / peak * 100}%"></span></span><span class="amount ${amount < 0 ? 'neg' : 'pos'}">${esc(money(amount))}</span></div>`;
      html += '<div class="hint">Flights settle once on completion. Shops, lounges and the café earn as passengers walk past them.</div><div class="section">TRANSACTIONS</div>';
      if (!ledger.length) html += '<div class="empty">Your transactions will appear here.</div>';
      for (const e of ledger.slice(-150).reverse()) {
        html += `<div class="row"><span class="grow"><span class="title">${esc(e.description)}</span><br><span class="sub">${esc(friendly(e.category))} · Day ${Math.floor((e.time || 0) / 1440) + 1}</span></span><span class="amount ${e.amount < 0 ? 'neg' : 'pos'}">${esc(money(e.amount))}</span></div>`;
      }
      return html;
    }];
  }

  function layout() {
    const root = document.documentElement.style;
    root.setProperty('--top', `${$('topstack').getBoundingClientRect().bottom + 8}px`);
    root.setProperty('--dock', `${innerHeight - $('dock').getBoundingClientRect().top}px`);
  }

  // ── Planning drag and drop ────────────────────────────────────────────
  function rowAt(x, y) {
    for (const el of document.elementsFromPoint(x, y)) {
      const row = el.closest?.('.tl-row');
      if (row) return row;
    }
    return null;
  }
  const overHolding = (x, y) => document.elementsFromPoint(x, y).some(el => el.id === 'holding' || el.closest?.('#holding'));
  function startDrag(event) {
    const card = event.target.closest('.hold-card');
    const block = event.target.closest('.block');
    if ((!card && !block) || event.button !== 0) return;
    let drag;
    if (card) {
      const contract = holding().find(c => c.id === card.dataset.hold);
      if (!contract) return;
      drag = {kind: 'contract', id: contract.id, contract, haul: contract.offer.haul, duration: contract.offer.standMinutes, grab: 0, source: card};
    } else {
      const flight = list('flights').find(f => f.id === block.dataset.flight);
      if (!flight) return;
      const contract = list('contracts').find(c => c.id === flight.contractId) || null;
      const rect = block.getBoundingClientRect();
      drag = {kind: 'flight', id: flight.id, flightId: flight.id, flight, contract, haul: modelClass(flight.modelId), duration: flight.departure - flight.arrival + rules().exitMinutes, grab: (event.clientX - rect.left) / HOUR * 60, source: block, draggable: !!block.dataset.draggable};
    }
    Object.assign(drag, {x: event.clientX, y: event.clientY, moved: false, pointer: event.pointerId});
    S.plan.drag = drag;
    try { drag.source.setPointerCapture(event.pointerId); } catch (_) { /* synthetic or finished pointer */ }
  }
  function ghostFor(drag) {
    if (!drag.ghost) {
      drag.ghost = document.createElement('div');
      drag.ghost.className = 'block ghost';
      drag.ghost.style.setProperty('--livery', livery(drag.contract?.carrier || drag.flight?.carrier));
    }
    return drag.ghost;
  }
  function moveDrag(event) {
    const drag = S.plan.drag;
    if (!drag || event.pointerId !== drag.pointer) return;
    if (!drag.moved && Math.hypot(event.clientX - drag.x, event.clientY - drag.y) < 6) return;
    if (drag.kind === 'flight' && !drag.draggable) return;
    drag.moved = true;
    drag.source.classList.add('dragging');
    const timeline = $('timeline');
    if (timeline) {
      const box = timeline.getBoundingClientRect();
      if (event.clientX > box.right - 50) timeline.scrollLeft += 24;
      else if (event.clientX < box.left + 160) timeline.scrollLeft -= 24;
    }
    const holdingEl = $('holding');
    const toHolding = drag.kind === 'flight' && overHolding(event.clientX, event.clientY);
    holdingEl?.classList.toggle('drop', toHolding);
    const row = toHolding ? null : rowAt(event.clientX, event.clientY);
    const ghost = ghostFor(drag);
    if (!row) { ghost.remove(); drag.target = toHolding ? {holding: true} : null; return; }
    const rect = row.getBoundingClientRect();
    const raw = planStart() + (event.clientX - rect.left) / HOUR * 60 - drag.grab;
    const arrival = Math.round(raw / SNAP) * SNAP;
    const standId = row.dataset.row;
    const problem = planCheck(drag, standId, arrival);
    drag.target = {standId, arrival, problem};
    if (ghost.parentElement !== row) row.appendChild(ghost);
    ghost.style.left = `${xOf(arrival)}px`;
    ghost.style.width = `${drag.duration / 60 * HOUR - 2}px`;
    ghost.classList.toggle('bad', !!problem);
    const count = drag.kind === 'contract' && drag.contract.offer.type !== 'charter' ? drag.contract.remaining : 1;
    ghost.innerHTML = `<span class="b-top"><b>${clockText(arrival)}–${clockText(arrival + drag.duration)}</b></span><span class="b-mid">${esc(problem || (count > 1 ? `${count} days in a row` : 'Release to place'))}</span>`;
  }
  function endDrag(event) {
    const drag = S.plan.drag;
    if (!drag || event.pointerId !== drag.pointer) return;
    S.plan.drag = null;
    drag.ghost?.remove();
    drag.source.classList.remove('dragging');
    $('holding')?.classList.remove('drop');
    if (!drag.moved || event.type === 'pointercancel') {
      if (drag.moved) { renderPanel(true); return; }
      if (drag.kind === 'contract') { S.plan.card = S.plan.card === drag.id ? null : drag.id; S.plan.focus = null; }
      else { S.plan.focus = S.plan.focus === drag.id ? null : drag.id; S.plan.card = null; }
      S.plan.slot = null;
      renderPanel(true);
      return;
    }
    const t = drag.target;
    if (t?.holding) command('unscheduleFlight', {flightId: drag.id});
    else if (t && !t.problem) {
      if (drag.kind === 'contract') command('placeContract', {contractId: drag.id, standId: t.standId, arrival: t.arrival}, () => { S.plan.card = null; });
      else if (t.standId !== drag.flight.standId || t.arrival !== drag.flight.arrival) command('moveFlight', {flightId: drag.id, standId: t.standId, arrival: t.arrival});
    } else if (t?.problem) notify(t.problem, 'error');
    renderPanel(true);
  }
  function wirePlanning() {
    const body = $('panel-body');
    body.addEventListener('pointerdown', startDrag);
    body.addEventListener('pointermove', moveDrag);
    body.addEventListener('pointerup', endDrag);
    body.addEventListener('pointercancel', endDrag);
    body.addEventListener('click', event => {
      const row = event.target.closest('[data-slot-row]');
      if (!row || event.target.closest('.block')) return;
      const rect = row.getBoundingClientRect();
      const time = planStart() + Math.floor(((event.clientX - rect.left) / HOUR * 60) / 15) * 15;
      S.plan.slot = {standId: row.dataset.slotRow, time};
      S.plan.focus = null;
      S.plan.card = null;
      renderPanel(true);
    });
  }

  // ── Events ────────────────────────────────────────────────────────────
  function wire() {
    for (const b of document.querySelectorAll('#dock [data-open]')) b.innerHTML = `${svg(b.dataset.open)}<span>${b.dataset.open}</span>`;
    for (const b of document.querySelectorAll('[data-view]')) b.innerHTML = svg(b.dataset.view);
    for (const b of document.querySelectorAll('[data-toggle]')) b.innerHTML = svg(b.dataset.toggle);
    for (const b of document.querySelectorAll('[data-mode]')) b.innerHTML = `${svg(b.dataset.mode === 'airport' ? 'interior' : 'Fleet')}<span>${b.dataset.mode === 'airport' ? 'Airport' : 'Airfield'}</span>`;
    $('panel-close').innerHTML = svg('close');
    $('manage-close').innerHTML = svg('close');
    // A click on the dimmed backdrop, outside the window, closes it.
    $('manage').addEventListener('pointerdown', event => { if (event.target.id === 'manage') closeManage(); });
    $('rotate').innerHTML = svg('rotate');
    $('cancel-tool').innerHTML = svg('close');
    wirePlanning();

    document.addEventListener('click', event => {
      const t = event.target.closest('button');
      if (!t || t.disabled) return;
      const d = t.dataset;
      if (t.id === 'pause') command(S.world?.paused !== false ? 'resume' : 'pause');
      else if (d.speed) command('speed', {speed: Number(d.speed)});
      else if (d.view) scene.view(d.view);
      else if (d.toggle) toggle(d.toggle);
      else if (d.open) openPanel(d.open);
      else if (t.id === 'panel-close') { S.panel = null; renderPanel(); renderNotices(); }
      else if (d.mode) { if (d.mode === 'airport') enterAirport(); else exitAirport(); }
      else if (t.id === 'rotate') rotate();
      else if (t.id === 'cancel-tool') setTool(null);
      else if (d.dismiss) dismiss(Number(d.dismiss));
      else if (d.category) { S.category = d.category; renderPanel(true); }
      else if (d.zone) setZone(S.zone === d.zone ? null : d.zone);
      else if (d.tool) { S.rotation = 0; setTool(S.tool === d.tool && !S.moveId ? null : d.tool); }
      else if (d.buy) command('buyVehicle', {kind: d.buy, depotId: d.depot || S.selected});
      else if (d.manageTab) { S.manage.tab = d.manageTab; S.manage.confirm = false; renderManage(true); }
      else if (d.manage) manageAction(d.manage, d.attribute);
      else if (d.manageOpen) select(d.manageOpen);
      else if (t.id === 'manage-close') closeManage();
      else if (d.accept) command('acceptContract', {offerId: d.accept});
      else if (d.cancelContract) command('cancelContract', {contractId: d.cancelContract});
      else if (d.cancelFlight) command('cancelFlight', {flightId: d.cancelFlight}, () => { S.plan.focus = null; renderPanel(true); });
      else if (d.planJump) {
        const t = $('timeline'), step = Number(d.planJump);
        if (step === 0) { S.plan.scrollTo = S.world?.time || 0; renderPanel(true); }
        else if (t) t.scrollBy({left: step * 12 * HOUR, behavior: 'smooth'});
      }
      else if (d.unschedule) command('unscheduleFlight', {flightId: d.unschedule}, () => { S.plan.focus = null; renderPanel(true); });
      else if (d.contractTab) { S.contractsUi.tab = d.contractTab; S.contractsUi.open = null; renderPanel(true); }
      else if (d.contractOpen) { S.contractsUi.open = S.contractsUi.open === d.contractOpen ? null : d.contractOpen; renderPanel(true); }
      else if (d.openPlan === '') { S.plan.scrollTo = S.world?.time || 0; if (S.manage) closeManage(); openPanel('Planning'); }
      else if (d.openPlan) { S.plan.card = d.openPlan; S.plan.scrollTo = S.world?.time || 0; openPanel('Planning'); }
      else if (d.action === 'retrySave') command('retrySave');
      else if (d.action === 'dismissAway') command('dismissAway');
      else if (d.action === 'focus') scene.view('focus', null, S.selected);
      else if (d.action === 'interior') enterAirport(S.selected);
      else if (d.action === 'exitAirport') exitAirport();
      else if (d.action === 'move') {
        const f = list('facilities').find(x => x.id === S.selected);
        if (f) { S.rotation = Number(f.rotation) || 0; setTool(f.kind, f.id); }
      } else if (d.action === 'demolish') command('demolish', {facilityId: S.selected}, () => { S.selected = null; scene.view('select', null, null); renderPanel(true); });
      else if (d.action === 'schedule') {
        const q = S.schedule;
        command('schedule', {aircraftId: q.aircraft, routeId: q.route, standId: q.stand, departure: (S.world?.time || 0) + Number(q.delay)});
      } else if (d.action === 'planSchedule' && S.plan.slot) {
        const q = S.schedule, slot = S.plan.slot;
        command('schedule', {aircraftId: q.aircraft, routeId: q.route, standId: slot.standId, departure: slot.time + 80}, () => { S.plan.slot = null; renderPanel(true); });
      } else if (d.action === 'planClose') { S.plan.slot = null; S.plan.focus = null; S.plan.card = null; renderPanel(true); }
      else if (d.action === 'planFocusStand') { scene.view('focus', null, d.stand); scene.view('select', null, d.stand); }
    });
    document.addEventListener('change', event => {
      const field = event.target.dataset?.field;
      if (!field) return;
      S.schedule[field] = field === 'delay' ? Number(event.target.value) : event.target.value;
      renderPanel();
    });
    addEventListener('keydown', event => {
      if (event.target.closest?.('select,input,textarea')) return;
      const key = event.key;
      if (key === 'Escape') {
        if (S.manage) closeManage();
        else if (S.zone) setZone(null);
        else if (S.tool) setTool(null);
        else if (S.panel) { S.panel = null; renderPanel(); renderNotices(); }
        else if (S.airport) exitAirport();
      } else if (key === 'r' || key === 'R') rotate();
      else if (key === ' ') { event.preventDefault(); command(S.world?.paused !== false ? 'resume' : 'pause'); }
      else if (key === '1' || key === '2' || key === '3') command('speed', {speed: [1, 4, 12][Number(key) - 1]});
      else if (key === 'c' || key === 'C') toggle('cutaway');
      else if (key === 'g' || key === 'G') toggle('grid');
      else if (key === 't' || key === 'T') { if (S.airport) exitAirport(); else enterAirport(); }
      else if (key === 'b' || key === 'B') openPanel('Build');
      else if (key === 'p' || key === 'P') openPanel('Planning');
      else if (key === 'F3') { event.preventDefault(); toggle('stats'); }
    });
    new ResizeObserver(layout).observe($('topstack'));
    new ResizeObserver(layout).observe($('dock'));
    addEventListener('resize', () => { layout(); renderPanel(true); });
    layout();
  }

  // ── Public ────────────────────────────────────────────────────────────
  function attach(api) {
    scene = api;
    const dock = $('dock');
    dock.innerHTML = panelNames.map(name => `<button type="button" data-open="${name}"></button>`).join('');
    wire();
    scene.view('cutaway', S.cutaway);
    scene.view('grid', S.grid);
    scene.view('quality', S.quality);
    scene.view('stats', S.stats);
    renderTop(); renderViewbar(); renderPanel(true); renderNotices(); renderTool();
  }
  function update(world) {
    S.world = world;
    if (S.selected && !list('facilities').some(f => f.id === S.selected)) S.selected = null;
    if (S.airport && !halls().length) exitAirport();
    renderTop(); renderPanel(); renderNotices(); renderTool(); renderManage();
  }
  function theme(palette) {
    const root = document.documentElement.style;
    for (const [name, value] of Object.entries(palette || {})) if (/^[a-z0-9-]+$/.test(name) && /^#[0-9a-f]{6,8}$/i.test(value)) root.setProperty(`--${name}`, value);
  }
  /** The scene hands back a floor rectangle to zone. */
  function paintZone(rect) {
    command('paintZone', {zone: rect.zone, x: rect.x, y: rect.y, width: rect.width, depth: rect.depth});
  }
  return {attach, update, result, select, place, paintZone, theme, airportClosed: exitAirport, get tool() { return S.tool; }, get airport() { return S.airport; }};
})();
