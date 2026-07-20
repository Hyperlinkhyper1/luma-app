/* Subway Builder — co-op multiplayer, hosted server-side.

   Rooms live on the sync server (server/lib/subway_store.dart): it holds
   membership (who's invited) and the last full game-state snapshot any
   member pushed, so a room stays joinable without whoever created it
   needing to stay online. This file talks to that server directly over
   REST (using a session token handed to it once by the native app — see
   SB.native below) plus a lightweight WebSocket for live updates while
   multiple people are actually connected at once.

   There's no fixed "host" any more. Instead, whoever's currently connected
   can hold a short leased "clock authority" role (claimed/renewed over
   REST) — that's who runs the world clock/economy locally and broadcasts
   the results; if they leave, the lease expires and the next connected
   member picks it up. Building (stations/lines) works the same way it
   always did: any member can place things locally, which get broadcast to
   live peers and persisted to the server for whoever joins later.

   Two invite paths, both just add a userId to the room's member list
   server-side: sharing the raw room code (anyone signed in who has the
   code can join), or inviting an existing chat contact — the latter also
   sends them a real message through the Chat plugin's actual E2E pipeline,
   which only the native app can do (see SB.native.call('sendChatMessage')). */
(function () {
  'use strict';
  const SB = (window.SB = window.SB || {});

  // ── Native bridge: the WebView's one connection back to the Flutter app.
  // Two backends: flutter_inappwebview's built-in callHandler (everywhere
  // except Windows), or a hand-rolled request/response protocol over
  // WebView2's raw chrome.webview.postMessage channel (Windows — see
  // lib/features/plugins/installed/_shared/windows_webview.dart). ──────────
  const native = (SB.native = {});
  (function () {
    let nextId = 1;
    const pending = new Map();
    const isWindows = () => !!(window.chrome && window.chrome.webview);

    if (isWindows()) {
      window.chrome.webview.addEventListener('message', (e) => {
        let data = e.data;
        if (typeof data === 'string') {
          try { data = JSON.parse(data); } catch (err) { return; }
        }
        const p = pending.get(data.id);
        if (!p) return;
        pending.delete(data.id);
        if (data.error) p.reject(new Error(data.error));
        else p.resolve(data.result);
      });
    }

    native.available = function () {
      return isWindows() || !!(window.flutter_inappwebview && window.flutter_inappwebview.callHandler);
    };

    native.call = function (name) {
      const args = Array.prototype.slice.call(arguments, 1);
      if (isWindows()) {
        return new Promise((resolve, reject) => {
          const id = nextId++;
          pending.set(id, { resolve, reject });
          window.chrome.webview.postMessage(JSON.stringify({ id, name, args }));
          setTimeout(() => {
            if (pending.has(id)) { pending.delete(id); reject(new Error('Native bridge timed out')); }
          }, 8000);
        });
      }
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        return window.flutter_inappwebview.callHandler('luma_bridge', name, args);
      }
      return Promise.reject(new Error('Native bridge not available'));
    };
  })();

  const ID_NAMESPACE_BASE = 10000000;
  const ID_NAMESPACE_SPAN = 90000; // buckets — see idNamespaceFor
  const CLOCK_RENEW_MS = 5000;

  const mp = (SB.mp = {
    signedIn: false,
    connected: false,       // WS open to the current room
    ready: false,           // room state applied locally, safe to build
    isClockAuthority: false,
    roomCode: null,
    token: null, serverUrl: null, email: null,
    onPeersChanged: null,
  });

  function hashStr(s) {
    let h = 2166136261;
    for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
    return h >>> 0;
  }

  function bumpIdNamespace() {
    const st = SB.game.state;
    const base = ID_NAMESPACE_BASE + (hashStr(mp.email || '') % ID_NAMESPACE_SPAN) * 1000;
    if (st.nextStationId < base) st.nextStationId = base;
    if (st.nextLineId < base) st.nextLineId = base;
  }

  // ── REST helper ──────────────────────────────────────────────────────
  async function api(method, path, body) {
    const res = await fetch(mp.serverUrl + '/api/v1' + path, {
      method,
      headers: Object.assign(
        { 'Content-Type': 'application/json' },
        mp.token ? { Authorization: 'Bearer ' + mp.token } : {}),
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch (e) { /* non-JSON error page */ }
    if (!res.ok) throw new Error((data && data.message) || ('HTTP ' + res.status));
    return data;
  }

  /// Reads the current sign-in state from the native app. Call before
  /// showing any co-op UI — SB.mp.signedIn tells you whether to bother.
  mp.init = async function () {
    try {
      const ctx = await native.call('authContext');
      mp.signedIn = !!ctx.signedIn;
      mp.token = ctx.token;
      mp.serverUrl = (ctx.serverUrl || '').replace(/\/+$/, '');
      mp.email = ctx.email;
    } catch (e) {
      mp.signedIn = false;
    }
    return mp.signedIn;
  };

  mp.myRooms = async function () {
    const r = await api('GET', '/subway/rooms');
    return r.rooms;
  };

  mp.chatContacts = async function () {
    return await native.call('chatContacts');
  };

  mp.createRoom = async function () {
    const r = await api('POST', '/subway/rooms');
    return r.code;
  };

  mp.inviteContact = async function (code, contactUserId) {
    await api('POST', '/subway/rooms/' + code + '/invite', { contactUserId });
  };

  mp.sendInviteMessage = async function (conversationId, code) {
    const text = 'Join my Subway Builder co-op room — open Subway Builder, tap Co-op → Join, and enter code ' + code + '.';
    const r = await native.call('sendChatMessage', conversationId, text);
    if (!r || !r.ok) throw new Error((r && r.error) || 'Failed to send the invite message');
  };

  // ── Snapshot helpers ─────────────────────────────────────────────────
  function stripXY(list) {
    return list.map((o) => {
      const c = {};
      for (const k in o) if (k !== 'x' && k !== 'y' && k !== '_pm') c[k] = o[k];
      return c;
    });
  }

  function snapshotEcon() {
    const st = SB.game.state;
    return {
      money: st.money, fare: st.fare, loans: st.loans, day: st.day,
      achievementsHit: st.achievementsHit, achievementsSeen: st.achievementsSeen,
      milestonesHit: st.milestonesHit, world: st.world,
    };
  }

  function applyEcon(e) {
    const st = SB.game.state;
    st.money = e.money; st.fare = e.fare; st.loans = e.loans; st.day = e.day;
    st.achievementsHit = e.achievementsHit; st.achievementsSeen = e.achievementsSeen;
    st.milestonesHit = e.milestonesHit; st.world = e.world;
    SB.game.save();
    SB.ui.updateAll();
  }

  function applyNetwork(stations, lines) {
    const st = SB.game.state;
    st.stations = stations;
    st.lines = lines;
    SB.game.rehydrate();
    SB.game.networkDirty = true;
    SB.game.save();
    SB.ui.updateAll();
  }

  // ── Durable persistence (REST, throttled) ───────────────────────────
  let pushTimer = null;
  function schedulePush() {
    if (!mp.connected || !mp.ready) return;
    clearTimeout(pushTimer);
    pushTimer = setTimeout(pushStateNow, 600);
  }
  function pushStateNow() {
    if (!mp.roomCode) return;
    const st = SB.game.state;
    const payload = {
      place: SB.game.place,
      stations: stripXY(st.stations),
      lines: stripXY(st.lines),
      econ: snapshotEcon(),
    };
    api('PUT', '/subway/rooms/' + mp.roomCode + '/state', payload).catch(() => {
      /* best-effort — the next successful push carries the latest state anyway */
    });
  }

  // ── Live relay (WebSocket) ───────────────────────────────────────────
  let ws = null;
  let syncTimer = null;

  function wsUrl(serverUrl, room, ticket) {
    const clean = serverUrl.replace(/^https?:\/\//, '').replace(/\/+$/, '');
    const scheme = /^(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/.test(clean) ? 'ws' : 'wss';
    return scheme + '://' + clean + '/api/v1/subway/room/' + encodeURIComponent(room) +
      '?ticket=' + encodeURIComponent(ticket);
  }

  async function connectSocket() {
    let ticket;
    try {
      const r = await api('POST', '/subway/rooms/' + mp.roomCode + '/ticket');
      ticket = r.ticket;
    } catch (e) {
      SB.ui.toast('Could not connect to the room: ' + e.message, 'bad');
      return;
    }
    try {
      ws = new WebSocket(wsUrl(mp.serverUrl, mp.roomCode, ticket));
    } catch (e) {
      SB.ui.toast('Could not reach the co-op server', 'bad');
      return;
    }
    ws.onopen = () => { mp.connected = true; startClockClaimLoop(); SB.ui.updateAll(); };
    ws.onmessage = (e) => onMessage(e.data);
    ws.onclose = () => {
      const wasConnected = mp.connected;
      mp.connected = false;
      stopClockClaimLoop();
      if (wasConnected && mp.roomCode) {
        SB.ui.toast('Lost connection to the room — reconnecting…', 'bad');
        setTimeout(() => { if (mp.roomCode) connectSocket(); }, 3000);
      }
      SB.ui.updateAll();
    };
    ws.onerror = () => {};
  }

  function send(msg) {
    if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg));
  }

  function onMessage(raw) {
    let msg;
    try { msg = JSON.parse(raw); } catch (e) { return; }
    switch (msg.type) {
      case 'sync':
        applyNetwork(msg.stations, msg.lines);
        break;
      case 'econ':
        if (!mp.isClockAuthority) applyEcon(msg.econ);
        break;
      case 'spend':
        if (mp.isClockAuthority && msg.amount) {
          SB.game.state.money += msg.amount;
          SB.game.save();
          send({ type: 'econ', econ: snapshotEcon() });
          pushStateNow();
          SB.ui.updateAll();
        }
        break;
      case 'day_events':
        if (!mp.isClockAuthority && SB.main && SB.main.renderDayEvents) {
          SB.main.renderDayEvents(msg.events);
        }
        break;
      default: break;
    }
  }

  /* Hooked from game.js's emit() — the single choke point every mutating
     build action already calls. moneyDelta is the signed change that
     action just made to st.money; non-authority clients report it so
     whoever holds clock authority applies it to the real shared treasury. */
  mp.onLocalChange = function (moneyDelta) {
    if (!mp.connected || !mp.ready) return;
    if (!mp.isClockAuthority && moneyDelta) send({ type: 'spend', amount: moneyDelta });
    clearTimeout(syncTimer);
    syncTimer = setTimeout(() => {
      send({
        type: 'sync',
        stations: stripXY(SB.game.state.stations),
        lines: stripXY(SB.game.state.lines),
      });
      schedulePush();
    }, 350);
  };

  /* Host-only-equivalent: called right after a real endDay() so live peers
     see the same milestone/achievement/event toasts, not just a silent
     number jump. */
  mp.broadcastDayEvents = function (events) {
    if (!mp.connected || !mp.isClockAuthority || !events.length) return;
    send({ type: 'day_events', events });
    pushStateNow();
  };

  // ── Clock-authority lease ────────────────────────────────────────────
  let clockTimer = null;
  function startClockClaimLoop() {
    claimTick();
    clockTimer = setInterval(claimTick, CLOCK_RENEW_MS);
  }
  function stopClockClaimLoop() {
    clearInterval(clockTimer);
    clockTimer = null;
    if (mp.isClockAuthority && mp.roomCode) {
      api('POST', '/subway/rooms/' + mp.roomCode + '/clock/release').catch(() => {});
    }
    mp.isClockAuthority = false;
  }
  async function claimTick() {
    if (!mp.roomCode) return;
    try {
      const r = await api('POST', '/subway/rooms/' + mp.roomCode + '/clock/claim');
      const was = mp.isClockAuthority;
      mp.isClockAuthority = !!r.granted;
      if (mp.isClockAuthority && !was) SB.ui.toast('Running the clock for this room', 'good');
    } catch (e) {
      mp.isClockAuthority = false;
    }
  }

  // ── Room lifecycle ───────────────────────────────────────────────────
  mp.joinRoom = async function (codeIn) {
    const code = codeIn.toUpperCase().trim();
    let r;
    try {
      r = await api('POST', '/subway/rooms/' + code + '/join');
    } catch (e) {
      SB.ui.toast('Could not join that room: ' + e.message, 'bad');
      return false;
    }
    mp.roomCode = code;
    bumpIdNamespace();

    const finish = () => { connectSocket(); };

    if (r.state) {
      const place = r.state.place;
      if (place && (!SB.game.place || SB.game.place.id !== place.id)) {
        SB.ui.toast('Travelling to ' + place.name + '…');
        SB.main.startPlace(place, true, () => {
          applyNetwork(r.state.stations, r.state.lines);
          applyEcon(r.state.econ);
          mp.ready = true;
          SB.ui.toast('Joined room ' + code, 'good');
          finish();
        });
        return true;
      }
      applyNetwork(r.state.stations, r.state.lines);
      applyEcon(r.state.econ);
    }
    mp.ready = true;
    SB.ui.toast(r.state ? 'Joined room ' + code : 'Room ' + code + ' created — start building', 'good');
    finish();
    return true;
  };

  mp.createAndJoin = async function () {
    if (!SB.game.state) { SB.ui.toast('Load a city first', 'bad'); return null; }
    let code;
    try {
      code = await mp.createRoom();
    } catch (e) {
      SB.ui.toast('Could not create a room: ' + e.message, 'bad');
      return null;
    }
    // A fresh room has no state yet — seed it from whatever's loaded now.
    mp.roomCode = code;
    bumpIdNamespace();
    mp.ready = true;
    connectSocket();
    pushStateNow();
    SB.ui.toast('Room ' + code + ' created — share the code or invite a contact', 'good');
    return code;
  };

  mp.leaveRoom = function () {
    if (ws) { try { ws.close(); } catch (e) {} }
    ws = null;
    stopClockClaimLoop();
    mp.connected = false;
    mp.ready = false;
    mp.roomCode = null;
    SB.ui.updateAll();
  };

  mp.econLocked = function () { return mp.connected && !mp.isClockAuthority; };
  mp.canBuild = function () { return !mp.connected || mp.ready; };
})();
