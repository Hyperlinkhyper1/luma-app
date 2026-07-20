/* Subway Builder — co-op multiplayer.

   Transport: a dumb WebSocket broadcast relay (server/lib/subway_relay.dart)
   that never parses game state — it just forwards every message a client
   sends to every other client in the same room. All the real logic lives
   here:

   - Whoever taps "Host" is the host for the session: authoritative for the
     shared treasury (money/fare/loans/day/world clock/weather/disruptions/
     events/achievements/milestones). Only the host's local `world.advance`/
     `endDay` ever run; it broadcasts the results (`econ`, `day_events`) to
     everyone else, who just mirror them.
   - Every station/line a client places is built by calling the normal
     local game.js functions (so cost validation and instant feedback stay
     local), then the client's *entire* current stations/lines arrays are
     broadcast (`sync`, debounced) and every recipient replaces its own
     arrays wholesale. This is deliberately last-write-wins at the
     whole-network granularity rather than a real CRDT — simple, and fine
     for a casual co-op session where only one person is usually mid-edit
     at a time. Two people editing at the exact same instant can clobber
     each other; that's a known, acceptable limitation for v1.
   - Station/line ids stay plain incrementing numbers (unchanged for solo
     play). Joining peers get their id counters bumped into a private
     namespace (`seq * 10,000,000`) so concurrent builders never collide. */
(function () {
  'use strict';
  const SB = (window.SB = window.SB || {});

  const DEFAULT_SERVER = 'sync.luma-app.cc';
  const ID_NAMESPACE = 10000000;
  const ROOM_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no 0/O/1/I/L

  const mp = (SB.mp = {
    connected: false,
    isHost: false,
    isPeer: false,      // connected AND not host
    ready: false,        // peer has received the host's initial snapshot
    roomCode: null,
    serverHost: DEFAULT_SERVER,
    mySeq: 1,
    myId: Math.random().toString(36).slice(2) + Date.now().toString(36),
    myName: 'Player',
    myColor: '#4da3ff',
    peers: new Map(),    // clientId -> {name, color, seq}
    onPeersChanged: null,
  });

  let ws = null;
  let nextSeq = 2;             // host-only: next seq to hand out
  let syncTimer = null;
  let econTimer = null;

  function randomRoomCode() {
    let s = '';
    for (let i = 0; i < 6; i++) s += ROOM_CHARS[Math.floor(Math.random() * ROOM_CHARS.length)];
    return s;
  }
  mp.randomRoomCode = randomRoomCode;

  function send(msg) {
    if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg));
  }

  function wsUrl(host, room) {
    const clean = host.replace(/^wss?:\/\//, '').replace(/\/+$/, '');
    const scheme = /^(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/.test(clean) ? 'ws' : 'wss';
    return scheme + '://' + clean + '/api/v1/subway/room/' + encodeURIComponent(room);
  }

  function reset() {
    mp.connected = false;
    mp.isHost = false;
    mp.isPeer = false;
    mp.ready = false;
    mp.roomCode = null;
    mp.peers = new Map();
    nextSeq = 2;
    clearInterval(econTimer); econTimer = null;
    clearTimeout(syncTimer); syncTimer = null;
    ws = null;
  }

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
    for (const l of st.lines) delete l._pm;
    SB.game.rehydrate();
    SB.game.networkDirty = true;
    SB.game.save();
    SB.ui.updateAll();
  }

  function bumpIdNamespace(seq) {
    const st = SB.game.state;
    const base = seq * ID_NAMESPACE;
    if (st.nextStationId < base) st.nextStationId = base;
    if (st.nextLineId < base) st.nextLineId = base;
  }

  function onMessage(raw) {
    let msg;
    try { msg = JSON.parse(raw); } catch (e) { return; }
    switch (msg.type) {
      case 'hello': {
        const known = mp.peers.get(msg.id);
        mp.peers.set(msg.id, { name: msg.name, color: msg.color, seq: known ? known.seq : undefined });
        if (mp.onPeersChanged) mp.onPeersChanged();
        if (mp.isHost && (!known || known.seq === undefined)) {
          const seq = nextSeq++;
          mp.peers.set(msg.id, { name: msg.name, color: msg.color, seq });
          if (mp.onPeersChanged) mp.onPeersChanged();
          const roster = [{ id: mp.myId, name: mp.myName, color: mp.myColor, seq: 1 }];
          for (const [id, p] of mp.peers) if (p.seq !== undefined) roster.push({ id, name: p.name, color: p.color, seq: p.seq });
          send({
            type: 'state', to: msg.id, seq, roster, place: SB.game.place,
            snapshot: {
              stations: stripXY(SB.game.state.stations),
              lines: stripXY(SB.game.state.lines),
              econ: snapshotEcon(),
            },
          });
        }
        break;
      }
      case 'state': {
        if (msg.to !== mp.myId || mp.isHost) return;
        mp.mySeq = msg.seq;
        for (const p of msg.roster || []) {
          if (p.id !== mp.myId) mp.peers.set(p.id, { name: p.name, color: p.color, seq: p.seq });
        }
        if (mp.onPeersChanged) mp.onPeersChanged();
        const applyRest = () => {
          applyNetwork(msg.snapshot.stations, msg.snapshot.lines);
          applyEcon(msg.snapshot.econ);
          bumpIdNamespace(mp.mySeq);
          mp.ready = true;
          SB.ui.toast('Joined room ' + mp.roomCode + ' — building as ' + mp.myName, 'good');
          SB.ui.updateAll();
        };
        // A joiner starts on their own last-played city — if the host is
        // building somewhere else, survey the host's city fresh first (this
        // discards the joiner's own local network for that place — they're
        // here to build on the host's map, not merge two different ones).
        if (!SB.game.place || SB.game.place.id !== msg.place.id) {
          SB.ui.toast('Travelling to ' + msg.place.name + '…');
          SB.main.startPlace(msg.place, true, applyRest);
        } else {
          applyRest();
        }
        break;
      }
      case 'sync': {
        if (msg.id === mp.myId) return;
        applyNetwork(msg.stations, msg.lines);
        break;
      }
      case 'econ': {
        if (mp.isHost) return; // host is the source of truth, never take econ from others
        applyEcon(msg.econ);
        break;
      }
      case 'spend': {
        // Only the host's money is real — a peer's local change to their own
        // st.money (already applied by the normal game.js action) is just an
        // optimistic preview until this lands and the host's next econ
        // broadcast corrects everyone, including the spender.
        if (!mp.isHost || !msg.amount) return;
        SB.game.state.money += msg.amount;
        SB.game.save();
        send({ type: 'econ', econ: snapshotEcon() });
        SB.ui.updateAll();
        break;
      }
      case 'day_events': {
        if (mp.isHost) return;
        if (SB.main && SB.main.renderDayEvents) SB.main.renderDayEvents(msg.events);
        break;
      }
      default: break;
    }
  }

  function connect(room, serverHost, onOpen) {
    reset();
    mp.roomCode = room;
    mp.serverHost = serverHost || DEFAULT_SERVER;
    try {
      ws = new WebSocket(wsUrl(mp.serverHost, room));
    } catch (e) {
      SB.ui.toast('Could not reach ' + mp.serverHost, 'bad');
      return;
    }
    ws.onopen = () => {
      mp.connected = true;
      send({ type: 'hello', id: mp.myId, name: mp.myName, color: mp.myColor });
      if (onOpen) onOpen();
    };
    ws.onmessage = (e) => onMessage(e.data);
    ws.onerror = () => SB.ui.toast('Co-op connection error', 'bad');
    ws.onclose = () => {
      if (mp.connected) SB.ui.toast('Disconnected from co-op room', 'bad');
      reset();
      SB.ui.updateAll();
    };
  }

  /* Start a fresh room as the host. Assumes SB.game.state already exists
     (host plays on their own current save; peers adopt it on join). */
  mp.host = function (name, color, serverHost) {
    if (!SB.game.state) { SB.ui.toast('Load a city first', 'bad'); return; }
    mp.myName = name || 'Host';
    mp.myColor = color || mp.myColor;
    const room = randomRoomCode();
    connect(room, serverHost || DEFAULT_SERVER, () => {
      mp.isHost = true;
      mp.isPeer = false;
      mp.mySeq = 1;
      mp.ready = true;
      econTimer = setInterval(() => send({ type: 'econ', econ: snapshotEcon() }), 1200);
      SB.ui.toast('Room ' + room + ' open — share the code to build together', 'good');
      SB.ui.updateAll();
    });
  };

  mp.join = function (room, name, color, serverHost) {
    mp.myName = name || 'Player';
    mp.myColor = color || mp.myColor;
    connect(room.toUpperCase().trim(), serverHost, () => {
      mp.isHost = false;
      mp.isPeer = true;
      SB.ui.toast('Connecting to room ' + mp.roomCode + '…');
      SB.ui.updateAll();
    });
  };

  mp.leave = function () {
    if (ws) { try { ws.close(); } catch (e) {} }
    reset();
    SB.ui.updateAll();
  };

  /* Everyone (host and peers) can build; peers just can't touch the shared
     treasury directly (fare/loans) — only the host's economy is real. */
  mp.canBuild = function () { return !mp.connected || mp.ready; };
  mp.econLocked = function () { return mp.connected && !mp.isHost; };

  /* Hooked from game.js's emit() — the single choke point every mutating
     action already calls. moneyDelta is the signed change that action just
     made to st.money; non-host clients report it so the host's real
     treasury actually reflects it (see the 'spend' case above). */
  mp.onLocalChange = function (moneyDelta) {
    if (!mp.connected || !mp.ready) return;
    if (!mp.isHost && moneyDelta) send({ type: 'spend', amount: moneyDelta });
    clearTimeout(syncTimer);
    syncTimer = setTimeout(() => {
      send({
        type: 'sync', id: mp.myId,
        stations: stripXY(SB.game.state.stations),
        lines: stripXY(SB.game.state.lines),
      });
    }, 350);
  };

  /* Host-only — called right after a real endDay() so peers see the same
     milestone/achievement/event toasts instead of just a silent number jump. */
  mp.broadcastDayEvents = function (events) {
    if (!mp.connected || !mp.isHost || !events.length) return;
    send({ type: 'day_events', events });
  };
})();
