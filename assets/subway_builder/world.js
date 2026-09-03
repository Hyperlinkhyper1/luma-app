/* Subway Builder — world clock, calendar, weather and live events.

   Time: 1 real second at 1× speed = 1 in-game minute. The clock drives a
   real calendar (weekdays/weekends, four 90-day seasons), an hourly demand
   curve with morning/evening rush hours, a season-aware weather machine,
   random line disruptions, and scheduled rush-hour surge events at stations.
   All of it persists inside game.state.world so saves resume mid-day. */
(function () {
  'use strict';
  const SB = (window.SB = window.SB || {});

  const MIN_PER_DAY = 1440;
  const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const SEASONS = [
    { id: 'spring', label: 'Spring', emoji: '🌸' },
    { id: 'summer', label: 'Summer', emoji: '☀️' },
    { id: 'autumn', label: 'Autumn', emoji: '🍂' },
    { id: 'winter', label: 'Winter', emoji: '❄️' },
  ];

  // Hour → relative commuter demand. Weekday has the two rush peaks the
  // 1s = 1min clock exists for; weekends are flatter and later.
  const CURVE_WEEKDAY = [
    0.10, 0.06, 0.05, 0.05, 0.08, 0.25, 0.90, 2.10, 2.30, 1.40,
    0.90, 0.85, 0.90, 0.85, 0.90, 1.10, 1.80, 2.10, 1.90, 1.10,
    0.70, 0.55, 0.40, 0.20,
  ];
  const CURVE_WEEKEND = [
    0.18, 0.12, 0.08, 0.06, 0.06, 0.10, 0.25, 0.45, 0.70, 0.95,
    1.10, 1.20, 1.20, 1.15, 1.10, 1.05, 1.00, 0.95, 0.95, 0.85,
    0.70, 0.55, 0.40, 0.28,
  ];
  const NIGHT_START = 22 * 60, NIGHT_END = 5 * 60; // "night service" window

  // kind → {emoji, label, surface (bus/tram delay ×), rail (train/hst ×),
  //         demand (transit demand ×), disrupt (disruption chance ×)}
  const WEATHER = {
    clear:  { emoji: '☀️', label: 'Clear',        surface: 1,    rail: 1,    demand: 1,    disrupt: 1 },
    cloudy: { emoji: '⛅', label: 'Cloudy',       surface: 1,    rail: 1,    demand: 1,    disrupt: 1 },
    rain:   { emoji: '🌧️', label: 'Rain',         surface: 1.15, rail: 1,    demand: 1.06, disrupt: 1.4 },
    storm:  { emoji: '⛈️', label: 'Storm',        surface: 1.35, rail: 1.12, demand: 0.94, disrupt: 3 },
    snow:   { emoji: '🌨️', label: 'Snow',         surface: 1.5,  rail: 1.15, demand: 1.05, disrupt: 3.5 },
    heat:   { emoji: '🥵', label: 'Heatwave',     surface: 1.08, rail: 1.05, demand: 0.92, disrupt: 1.6 },
    fog:    { emoji: '🌫️', label: 'Fog',          surface: 1.12, rail: 1.08, demand: 1.02, disrupt: 1.5 },
  };
  // Per season: [kind, weight] tables.
  const WEATHER_TABLE = {
    spring: [['clear', 4], ['cloudy', 4], ['rain', 3], ['storm', 1], ['fog', 1]],
    summer: [['clear', 6], ['cloudy', 3], ['rain', 1.5], ['storm', 1.5], ['heat', 2]],
    autumn: [['clear', 2], ['cloudy', 4], ['rain', 4], ['storm', 1.5], ['fog', 2]],
    winter: [['clear', 2], ['cloudy', 4], ['rain', 2], ['snow', 3], ['fog', 1.5]],
  };

  const EVENT_NAMES = [
    'Stadium match', 'Arena concert', 'Street festival', 'Trade convention',
    'Night market', 'Marathon finish', 'Fireworks show', 'Football derby',
  ];
  const DISRUPTION_KINDS = [
    { label: 'Signal failure', delay: 2.0 },
    { label: 'Track fault', delay: 1.8 },
    { label: 'Power outage', delay: 2.2 },
    { label: 'Staff shortage', delay: 1.5 },
    { label: 'Stalled vehicle', delay: 1.7 },
  ];

  const world = (SB.world = {
    // callbacks the shell wires up
    onDayEnd: null,           // (report) — fired at midnight
    onNews: null,             // (msg, kind) — toasts for events/weather/disruptions
  });

  function st() { return SB.game.state && SB.game.state.world; }

  world.initState = function () {
    return {
      clock: 7 * 60,          // day 1, 07:00 — straight into the morning rush
      weather: { kind: 'clear', until: 10 * 60 },
      events: [],             // {sid, name, start, end, mult, announced}
      disruptions: [],        // {lineId, label, delay, until, announced}
      lastHourTick: -1,
    };
  };

  world.ensure = function () {
    const g = SB.game.state;
    if (!g) return;
    if (!g.world) {
      g.world = world.initState();
      // migrate old saves: keep the day counter they had reached
      g.world.clock += (g.day - 1) * MIN_PER_DAY;
    }
  };

  // ── Calendar ─────────────────────────────────────────────────────────
  world.clock = function () { const w = st(); return w ? w.clock : 0; };
  world.day = function () { return Math.floor(world.clock() / MIN_PER_DAY) + 1; };
  world.minuteOfDay = function () { return Math.floor(world.clock()) % MIN_PER_DAY; };
  world.hour = function () { return world.minuteOfDay() / 60; };
  world.weekdayIdx = function () { return (world.day() - 1) % 7; };
  world.weekday = function () { return WEEKDAYS[world.weekdayIdx()]; };
  world.isWeekend = function () { return world.weekdayIdx() >= 5; };
  world.isNight = function () {
    const m = world.minuteOfDay();
    return m >= NIGHT_START || m < NIGHT_END;
  };
  world.season = function () {
    return SEASONS[Math.floor(((world.day() - 1) % 360) / 90)];
  };
  world.timeString = function () {
    const m = world.minuteOfDay();
    const h = Math.floor(m / 60), mm = Math.floor(m % 60);
    return (h < 10 ? '0' : '') + h + ':' + (mm < 10 ? '0' : '') + mm;
  };

  // ── Demand ───────────────────────────────────────────────────────────
  world.demandNow = function () {
    const curve = world.isWeekend() ? CURVE_WEEKEND : CURVE_WEEKDAY;
    const h = world.hour();
    const a = curve[Math.floor(h) % 24], b = curve[(Math.floor(h) + 1) % 24];
    const f = h - Math.floor(h);
    return (a + (b - a) * f) * world.weatherInfo().demand;
  };
  world.isRushHour = function () { return !world.isWeekend() && world.demandNow() >= 1.6; };

  /* Share of a full day's demand that falls inside the night window /
     on a weekend day — used to price the per-line service toggles. */
  world.NIGHT_SHARE = (function () {
    let night = 0, all = 0;
    for (let h = 0; h < 24; h++) {
      all += CURVE_WEEKDAY[h];
      if (h >= 22 || h < 5) night += CURVE_WEEKDAY[h];
    }
    return night / all; // ≈ 0.06–0.09
  })();
  world.WEEKEND_DAY_MULT = (function () {
    const s = (arr) => arr.reduce((a, b) => a + b, 0);
    return s(CURVE_WEEKEND) / s(CURVE_WEEKDAY);
  })();

  /* Is this line running right now? (night/weekend service toggles) */
  world.lineActive = function (line) {
    if (line.nightService === false && world.isNight()) return false;
    if (line.weekendService === false && world.isWeekend()) return false;
    return true;
  };

  // ── Weather ──────────────────────────────────────────────────────────
  world.weatherInfo = function () {
    const w = st();
    return WEATHER[(w && w.weather.kind) || 'clear'];
  };
  world.weatherKind = function () { const w = st(); return w ? w.weather.kind : 'clear'; };

  function rollWeather() {
    const w = st();
    const table = WEATHER_TABLE[world.season().id];
    let total = 0;
    for (const [, wt] of table) total += wt;
    let r = Math.random() * total;
    let kind = table[0][0];
    for (const [k, wt] of table) { r -= wt; if (r <= 0) { kind = k; break; } }
    const prev = w.weather.kind;
    w.weather = { kind, until: w.clock + (4 + Math.random() * 10) * 60 };
    if (kind !== prev) SB.game.networkDirty = true; // ride times changed
    if (kind !== prev && kind !== 'clear' && kind !== 'cloudy' && world.onNews) {
      world.onNews(WEATHER[kind].emoji + ' ' + WEATHER[kind].label +
        (WEATHER[kind].surface > 1.2 ? ' — surface transit is slowed' : ''));
    }
  }

  /* Delay multiplier the sim applies to a line's ride times right now. */
  world.delayFor = function (line) {
    const info = world.weatherInfo();
    let d = (line.mode === 'bus' || line.mode === 'tram') ? info.surface
      : (line.mode === 'train' || line.mode === 'hst') ? info.rail
      : 1; // metro is underground — weather-proof
    const w = st();
    if (w) {
      for (const dis of w.disruptions) {
        if (dis.lineId === line.id && w.clock < dis.until) d *= dis.delay;
      }
    }
    return d;
  };

  world.disruptionFor = function (lineId) {
    const w = st();
    if (!w) return null;
    for (const dis of w.disruptions) {
      if (dis.lineId === lineId && w.clock < dis.until) return dis;
    }
    return null;
  };

  world.activeEvents = function () {
    const w = st();
    if (!w) return [];
    const m = w.clock;
    return w.events.filter((e) => m >= e.start && m < e.end);
  };

  // ── Ticking ──────────────────────────────────────────────────────────
  function hourlyTick() {
    const w = st();
    const g = SB.game.state;
    if (w.clock >= w.weather.until) rollWeather();

    // Disruptions: small hourly chance per line, worse in bad weather.
    const chance = 0.012 * world.weatherInfo().disrupt;
    for (const line of g.lines) {
      if (world.disruptionFor(line.id)) continue;
      if (!world.lineActive(line)) continue;
      if (Math.random() < chance) {
        const kind = DISRUPTION_KINDS[Math.floor(Math.random() * DISRUPTION_KINDS.length)];
        const hours = 1 + Math.random() * 3;
        w.disruptions.push({
          lineId: line.id, label: kind.label, delay: kind.delay,
          until: w.clock + hours * 60,
        });
        SB.game.networkDirty = true;
        if (world.onNews) {
          world.onNews('⚠️ ' + kind.label + ' on ' + line.name + ' — expect delays for ~' +
            Math.round(hours) + 'h', 'bad');
        }
      }
    }
    // Expire finished disruptions.
    const before = w.disruptions.length;
    w.disruptions = w.disruptions.filter((d) => w.clock < d.until + 60);
    if (w.disruptions.length !== before) SB.game.networkDirty = true;
  }

  function scheduleDayEvents() {
    const w = st();
    const g = SB.game.state;
    w.events = w.events.filter((e) => w.clock < e.end); // drop yesterday's
    if (world.isWeekend() ? Math.random() < 0.35 : Math.random() < 0.2) {
      const stations = g.stations;
      if (!stations.length) return;
      const s = stations[Math.floor(Math.random() * stations.length)];
      const dayStart = Math.floor(w.clock / MIN_PER_DAY) * MIN_PER_DAY;
      const startH = 17 + Math.random() * 3;
      w.events.push({
        sid: s.id,
        name: EVENT_NAMES[Math.floor(Math.random() * EVENT_NAMES.length)],
        start: dayStart + startH * 60,
        end: dayStart + (startH + 3.5 + Math.random() * 2) * 60,
        mult: 2 + Math.random() * 1.5,
        announced: false,
      });
    }
  }

  /* Advance the clock by dtMin in-game minutes. Fires hourly housekeeping,
     event announcements and the end-of-day rollover. */
  world.advance = function (dtMin) {
    const w = st();
    if (!w) return;
    const prevDayIdx = Math.floor(w.clock / MIN_PER_DAY);
    w.clock += dtMin;

    const hourIdx = Math.floor(w.clock / 60);
    if (hourIdx !== w.lastHourTick) {
      w.lastHourTick = hourIdx;
      hourlyTick();
    }

    for (const e of w.events) {
      if (!e.announced && w.clock >= e.start - 60 && w.clock < e.end) {
        e.announced = true;
        const s = SB.game.stationById(e.sid);
        if (s && world.onNews) {
          world.onNews('🎪 ' + e.name + ' near ' + s.name + ' tonight — expect a crowd surge!');
        }
      }
    }

    const dayIdx = Math.floor(w.clock / MIN_PER_DAY);
    if (dayIdx !== prevDayIdx) {
      SB.game.state.day = dayIdx + 1;
      const report = SB.game.endDay();
      scheduleDayEvents();
      if (world.onDayEnd) world.onDayEnd(report);
    }
  };
})();
