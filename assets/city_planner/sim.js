// ─────────────────────────────────────────────────────────────
// MetroPlan — simulatie: bevolking, verkeer, netten, economie
// Alles is groeps-/data-gebaseerd: geen per-inwoner of per-auto AI.
// ─────────────────────────────────────────────────────────────
"use strict";

// scratch-buffers voor BFS (hergebruikt, geen allocatie per dag)
const _dist = new Int32Array(N);
const _queue = new Int32Array(N);
const NB4 = [1, -1, W, -W];

// ── Dagelijkse tick ─────────────────────────────────────────
function simDay() {
  if (G.gameOver) return;
  G.day++;
  if (G.day > 30) {
    G.day = 1; G.month++;
    if (G.month > 12) { G.month = 1; G.year++; }
    simMonth();
  }
  // weer voor hernieuwbare energie: random walk 0.35..1
  G.weerFactor = Math.max(0.35, Math.min(1, G.weerFactor + (RNG() - 0.5) * 0.15));

  recomputeCapacities();
  simUtilities();
  simServices();
  simTransit();
  simEmployment();
  simTraffic();
  simPollution();
  simLandValue();
  simHappiness();
  simMigration();
  simResearch();
  maybeEvent();
  G.rp += G.rpPerDag;
}

// ── Capaciteiten per gebouw hercomputeren ───────────────────
function recomputeCapacities() {
  let jobs = 0, houseCap = 0;
  eachBuilding(b => {
    const c = buildingCapacity(b);
    b.capBew = c.bew; b.capBanen = c.banen;
    b.energie = c.energie; b.water = c.water;
    b.waarde = Math.round(c.waarde * (1 + (G.landValue[b.cells[0]] || 0)));
    b.inkomen = c.inkomen;
    b.roadOk = b.cells.some(i => adjacentRoad(i) >= 0);
    jobs += b.capBanen;
    if (b.capBew > 0) houseCap += b.capBew;
  });
  G.jobs = jobs;
  G.houseCap = houseCap;
}

// ── Energie & water: netten via wegen-componenten ───────────
// Het "net" volgt het wegennet: gebouwen en centrales aan dezelfde
// samenhangende wegen-component delen vraag en aanbod.
function simUtilities() {
  // componenten labelen
  _dist.fill(-1);
  let comp = 0;
  const compSupplyE = [], compDemandE = [], compSupplyW = [], compDemandW = [], compStorage = [];
  for (let i = 0; i < N; i++) {
    if (G.road[i] > 0 && _dist[i] === -1) {
      // BFS flood
      let qh = 0, qt = 0;
      _queue[qt++] = i; _dist[i] = comp;
      while (qh < qt) {
        const cur = _queue[qh++];
        const cx = cur % W;
        for (const d of NB4) {
          const n = cur + d;
          if (n < 0 || n >= N) continue;
          if (d === 1 && cx === W - 1) continue;
          if (d === -1 && cx === 0) continue;
          if (G.road[n] > 0 && _dist[n] === -1) { _dist[n] = comp; _queue[qt++] = n; }
        }
      }
      compSupplyE.push(0); compDemandE.push(0); compSupplyW.push(0); compDemandW.push(0); compStorage.push(0);
      comp++;
    }
  }
  // vraag/aanbod per component
  let totSupE = 0, totDemE = 0, totSupW = 0, totDemW = 0, rioolCap = 0, afvalCap = 0;
  eachBuilding(b => {
    const def = BUILDINGS[b.type];
    const r = b.cells.map(adjacentRoad).find(x => x >= 0);
    b.comp = (r !== undefined && r >= 0) ? _dist[r] : -1;
    const cells = b.cells.length;
    let prodE = (def.energieProd || 0) * cells;
    if (def.hernieuwbaar) prodE *= G.weerFactor;
    if (def.tech === "kernenergie" && G.policies.kern_verbod) prodE = 0;
    let prodW = (def.waterProd || 0) * cells * (def.waterNodig && !nearWater(b.cells[0], 3) ? 0.25 : 1);
    let demE = b.energie || 0, demW = b.water || 0;
    if (G.policies.zon_subsidie) demE *= 0.92;
    rioolCap += (def.rioolCap || 0) * cells;
    afvalCap += (def.afvalCap || 0) * cells;
    if (b.comp >= 0) {
      compSupplyE[b.comp] += prodE; compDemandE[b.comp] += demE;
      compSupplyW[b.comp] += prodW; compDemandW[b.comp] += demW;
      compStorage[b.comp] += (def.opslag || 0) * cells;
    }
    totSupE += prodE; totDemE += demE; totSupW += prodW; totDemW += demW;
  });
  // opslag dempt weersinvloed: telt mee als bonusaanbod tot 30% van vraag
  // dekking per gebouw. In fase 1 (dorp, pre-elektrificatie) is er nog
  // geen stroomnet nodig — pas vanaf fase 2 ontgrendelen centrales én vraag.
  const preElektrisch = G.fase === 1;
  eachBuilding(b => {
    if (preElektrisch) { b.powered = true; b.powerRatio = 1; }
    if (b.comp < 0) { if (!preElektrisch) b.powered = false; b.watered = false; return; }
    const supE = compSupplyE[b.comp] + Math.min(compStorage[b.comp], compDemandE[b.comp] * 0.3);
    b.powered = preElektrisch || compDemandE[b.comp] <= 0.01 || supE >= compDemandE[b.comp] * 0.98;
    b.watered = compDemandW[b.comp] <= 0.01 || compSupplyW[b.comp] >= compDemandW[b.comp] * 0.98;
    b.powerRatio = compDemandE[b.comp] > 0 ? Math.min(1, supE / compDemandE[b.comp]) : 1;
    b.waterRatio = compDemandW[b.comp] > 0 ? Math.min(1, compSupplyW[b.comp] / compDemandW[b.comp]) : 1;
  });
  // dekking op kaart voor heatmap
  G.powerOk.fill(0); G.waterOk.fill(0);
  for (let i = 0; i < N; i++) {
    if (G.road[i] > 0 && _dist[i] >= 0) {
      const c = _dist[i];
      const supE = compSupplyE[c] + Math.min(compStorage[c], compDemandE[c] * 0.3);
      G.powerOk[i] = compDemandE[c] === 0 ? (compSupplyE[c] > 0 ? 2 : 0) : (supE >= compDemandE[c] ? 2 : 1);
      G.waterOk[i] = compDemandW[c] === 0 ? (compSupplyW[c] > 0 ? 2 : 0) : (compSupplyW[c] >= compDemandW[c] ? 2 : 1);
    }
  }
  G.stats.energie = { vraag: totDemE, aanbod: totSupE };
  G.stats.water = { vraag: totDemW, aanbod: totSupW };
  G.stats.riool = { vraag: totDemW * 0.8, cap: rioolCap };
  G.stats.afval = { vraag: G.pop * 0.01, cap: afvalCap };
}

// ── Diensten (school/zorg/politie/OV/groen) als velden ──────
// Multi-source BFS over wegen vanaf faciliteiten, met bereik-limiet.
function coverageField(out, sources, decay) {
  out.fill(0);
  for (const s of sources) {
    const r = s.bereik, sx = s.x | 0, sy = s.y | 0;
    const x0 = Math.max(0, sx - r), x1 = Math.min(W - 1, sx + r);
    const y0 = Math.max(0, sy - r), y1 = Math.min(H - 1, sy + r);
    for (let y = y0; y <= y1; y++) {
      for (let x = x0; x <= x1; x++) {
        const d = Math.abs(x - sx) + Math.abs(y - sy);
        if (d > r) continue;
        const i = idx(x, y);
        const v = s.sterkte * Math.max(0, 1 - d / r) * decay;
        if (v > out[i]) out[i] = v;
      }
    }
  }
}

function simServices() {
  const edu = [], health = [], safety = [], green = [];
  const eduBoost = G.techs.beter_onderwijs ? 1.25 : 1;
  const zorgBoost = G.techs.moderne_zorg ? 1.25 : 1;
  const groenBoost = G.techs.natuurbeheer ? 1.5 : 1;
  let schoolCap = { basis: 0, middelbaar: 0, universiteit: 0 }, zorgCap = 0;
  eachBuilding(b => {
    const def = BUILDINGS[b.type];
    const werkFactor = b.powered ? 1 : 0.4;
    if (def.school) {
      schoolCap[def.school] += def.schoolCap * b.cells.length * b.floors.length * eduBoost * werkFactor;
      edu.push({ x: b.x, y: b.y, bereik: def.bereik, sterkte: 1 });
    }
    if (def.zorgCap) {
      zorgCap += def.zorgCap * b.cells.length * b.floors.length * zorgBoost * werkFactor;
      health.push({ x: b.x, y: b.y, bereik: def.bereik, sterkte: 1 });
    }
    if (def.veiligheid || def.brandweer) safety.push({ x: b.x, y: b.y, bereik: def.bereik, sterkte: 1 });
    if (def.groen) green.push({ x: b.x, y: b.y, bereik: def.bereik, sterkte: groenBoost });
  });
  // bos telt als groen
  coverageField(G.svcEdu, edu, 1);
  coverageField(G.svcHealth, health, 1);
  coverageField(G.svcSafety, safety, 1);
  coverageField(G.svcGreen, green, 1);
  G.stats.schoolCap = schoolCap;
  G.stats.zorgCap = zorgCap;
}

// ── OV: dekking + ridership per lijn ────────────────────────
function simTransit() {
  const stops = [];
  let opCost = 0;
  for (const l of G.transitLines) {
    if (!l.actief || l.stops.length < 2) { l.ridership = 0; continue; }
    const tt = TRANSIT_TYPES[l.type];
    for (const s of l.stops) stops.push({ x: s % W, y: (s / W) | 0, bereik: tt.bereik, sterkte: 1 });
    opCost += tt.opPerHalte * l.stops.length * l.freq;
  }
  coverageField(G.svcTransit, stops, 1);
  // ridership: pendelaars binnen dekking gebruiken OV
  let ovShare = 0.25;
  if (G.policies.ov_subsidie) ovShare *= 1.4;
  if (G.techs.ai_verkeer) ovShare *= 1.1;
  let riders = 0;
  eachBuilding(b => {
    if (b.bezet > 0) {
      const cov = G.svcTransit[b.cells[0]];
      if (cov > 0.1) riders += b.bezet * 0.55 * ovShare * Math.min(1, cov + 0.3);
    }
  });
  // verdeel ridership naar lijnen naar rato van haltes
  const totStops = G.transitLines.reduce((s, l) => s + (l.actief ? l.stops.length : 0), 0) || 1;
  let cap = 0;
  for (const l of G.transitLines) {
    if (!l.actief) continue;
    const tt = TRANSIT_TYPES[l.type];
    const lineCap = tt.capPerRit * l.freq * 16;
    l.ridership = Math.min(lineCap, Math.round(riders * l.stops.length / totStops));
    cap += lineCap;
  }
  G.stats.ov = { riders: Math.round(riders), cap, opCost };
}

// ── Werkgelegenheid: cohorten matchen aan banen ─────────────
function simEmployment() {
  // verdeel bevolking over cohorten (vaste verhouding met lichte drift)
  const p = G.pop;
  G.cohorts.kinderen = Math.round(p * 0.18);
  G.cohorts.studenten = Math.round(p * 0.10);
  G.cohorts.ouderen = Math.round(p * 0.17);
  G.cohorts.werkenden = p - G.cohorts.kinderen - G.cohorts.studenten - G.cohorts.ouderen;

  const werkzoekend = G.cohorts.werkenden;
  let vraag = 0;
  eachBuilding(b => { if (b.capBanen > 0) vraag += b.capBanen; });
  const fillRatio = vraag > 0 ? Math.min(1, werkzoekend / vraag) : 0;
  let filled = 0;
  eachBuilding(b => {
    if (b.capBanen > 0) {
      const eff = (b.powered ? 1 : 0.4) * (b.watered ? 1 : 0.7) * (b.roadOk ? 1 : 0.3);
      b.werkers = Math.round(b.capBanen * fillRatio * eff);
      filled += b.werkers;
    } else b.werkers = 0;
  });
  G.jobsFilled = filled;
  G.stats.werkloosheid = werkzoekend > 0 ? Math.max(0, 1 - vraag / werkzoekend) : 0;
}

// ── Verkeer: geaggregeerde stromen over het wegennet ────────
// 1) BFS-afstandsveld vanaf alle baan-tegels over wegen.
// 2) Elke woonwijk stuurt zijn pendelstroom "bergafwaarts" langs
//    het veld; de stroom telt op per wegtegel → drukte.
function simTraffic() {
  // afbouw van gisteren (traag gemiddelde ⇒ stabiel beeld)
  for (let i = 0; i < N; i++) G.traffic[i] *= 0.5;

  // 1) bronnen: wegtegels naast gebouwen met banen
  _dist.fill(0x3fffffff);
  let qt = 0;
  eachBuilding(b => {
    if (b.capBanen > 2) {
      for (const c of b.cells) {
        const r = adjacentRoad(c);
        if (r >= 0 && _dist[r] === 0x3fffffff) { _dist[r] = 0; _queue[qt++] = r; }
      }
    }
  });
  if (qt === 0) { G.stats.verkeer = { drukte: 0, reistijd: 0 }; return; }
  let qh = 0;
  while (qh < qt) {
    const cur = _queue[qh++];
    const cx = cur % W;
    for (const d of NB4) {
      const n = cur + d;
      if (n < 0 || n >= N) continue;
      if (d === 1 && cx === W - 1) continue;
      if (d === -1 && cx === 0) continue;
      if (G.road[n] > 0 && _dist[n] > _dist[cur] + 1) {
        _dist[n] = _dist[cur] + 1;
        _queue[qt++] = n;
      }
    }
  }

  // 2) pendelstromen: auto-aandeel afhankelijk van OV en beleid
  let carShare = 0.72;
  if (G.policies.benzine_taks) carShare -= 0.07;
  if (G.policies.ov_subsidie) carShare -= 0.08;
  if (G.techs.autonoom) carShare -= 0.05;
  let totReistijd = 0, forensen = 0, parkeerVraag = 0;

  eachBuilding(b => {
    if (b.bezet <= 0) return;
    const start = b.cells.map(adjacentRoad).find(x => x >= 0);
    if (start === undefined || start < 0 || _dist[start] >= 0x3fffffff) { b.reistijd = 90; return; }
    const ovCov = G.svcTransit[b.cells[0]];
    const share = Math.max(0.2, carShare - ovCov * 0.3);
    const commuters = b.bezet * 0.55;
    const flow = commuters * share;
    parkeerVraag += flow;
    // pad volgen (bergafwaarts) met werkbudget
    let cur = start, guard = 0, tijd = 0;
    while (_dist[cur] > 0 && guard++ < 300) {
      G.traffic[cur] += flow;
      const rd = ROADS[G.road[cur]];
      const cap = rd.cap * roadCapFactor();
      const cong = Math.min(3, G.traffic[cur] / cap);
      tijd += (60 / rd.snelheid) * (1 + cong);
      // beste buur zoeken
      let best = -1, bestD = _dist[cur];
      const cx = cur % W;
      for (const d of NB4) {
        const n = cur + d;
        if (n < 0 || n >= N) continue;
        if (d === 1 && cx === W - 1) continue;
        if (d === -1 && cx === 0) continue;
        if (G.road[n] > 0 && _dist[n] < bestD) { bestD = _dist[n]; best = n; }
      }
      if (best < 0) break;
      cur = best;
    }
    b.reistijd = Math.min(90, Math.round(tijd * 0.8));
    totReistijd += b.reistijd * commuters;
    forensen += commuters;
  });

  // parkeren
  let parkeerCap = 0;
  eachBuilding(b => {
    const def = BUILDINGS[b.type];
    if (def.parkeren) parkeerCap += def.parkeren * b.cells.length * b.floors.length;
  });
  if (G.techs.autonoom) parkeerVraag *= 0.75;
  G.stats.parkeren = { vraag: Math.round(parkeerVraag * 0.35), cap: parkeerCap };

  // stadsbrede drukte-index
  let sum = 0, cnt = 0;
  for (let i = 0; i < N; i++) {
    if (G.road[i] > 0) {
      const cap = ROADS[G.road[i]].cap * roadCapFactor();
      sum += Math.min(2, G.traffic[i] / cap); cnt++;
    }
  }
  G.stats.verkeer = {
    drukte: cnt ? sum / cnt : 0,
    reistijd: forensen > 0 ? totReistijd / forensen : 0,
  };
}
function roadCapFactor() {
  let f = 1;
  if (G.techs.verkeerslichten) f *= 1.15;
  if (G.techs.rotondes) f *= 1.1;
  if (G.techs.ai_verkeer) f *= 1.3;
  return f;
}

// ── Vervuiling & geluid (coarse diffusie) ───────────────────
function simPollution() {
  const decay = 0.86;
  for (let i = 0; i < N; i++) { G.pollution[i] *= decay; G.noise[i] *= 0.7; }
  const co2Mod = G.policies.co2_belasting ? 0.85 : 1;
  const dakMod = G.techs.groene_daken ? 0.9 : 1;
  eachBuilding(b => {
    const def = BUILDINGS[b.type];
    let p = (def.vervuiling || 0) * co2Mod * dakMod;
    if (def.tech === "kernenergie" && G.policies.kern_verbod) p = 0;
    if (p > 0) for (const c of b.cells) G.pollution[c] += p;
  });
  // verkeer → geluid + wat vervuiling
  const verkVerv = G.policies.ev_stimulans ? 0.0006 : 0.002;
  for (let i = 0; i < N; i++) {
    if (G.road[i] > 0 && G.traffic[i] > 0) {
      G.noise[i] += Math.min(3, G.traffic[i] / 120);
      G.pollution[i] += G.traffic[i] * verkVerv;
    }
  }
  // afvaltekort → stadsbrede smog
  const a = G.stats.afval;
  if (a && a.vraag > a.cap) {
    const overschot = (a.vraag - a.cap) * 0.02;
    for (let i = 0; i < N; i += 7) G.pollution[i] += overschot;
  }
  // simpele blur (verspreiding), om de dag om CPU te sparen
  if (G.day % 2 === 0) blurField(G.pollution, 0.22);
  // bomen/parken absorberen
  for (let i = 0; i < N; i++) {
    if (G.terrain[i] === TERRAIN.BOS) G.pollution[i] *= 0.85;
    if (G.svcGreen[i] > 0.3) G.pollution[i] *= 0.93;
  }
}
function blurField(f, k) {
  for (let y = 1; y < H - 1; y++) {
    const row = y * W;
    for (let x = 1; x < W - 1; x++) {
      const i = row + x;
      f[i] = f[i] * (1 - k) + (f[i - 1] + f[i + 1] + f[i - W] + f[i + W]) * (k / 4);
    }
  }
}

// ── Grondwaarde ─────────────────────────────────────────────
function simLandValue() {
  for (let i = 0; i < N; i++) {
    let v = 0.3;
    if (nearWaterCached(i)) v += 0.25;
    v += G.svcGreen[i] * 0.2 + G.svcEdu[i] * 0.1 + G.svcHealth[i] * 0.1 + G.svcTransit[i] * 0.15;
    v -= Math.min(0.5, G.pollution[i] * 0.06) + Math.min(0.3, G.noise[i] * 0.08);
    G.landValue[i] = G.landValue[i] * 0.8 + Math.max(0, Math.min(1.5, v)) * 0.2;
  }
}
let _waterCache = null;
function nearWaterCached(i) {
  if (!_waterCache) {
    _waterCache = new Uint8Array(N);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const j = idx(x, y);
      if (isWater(G.terrain[j])) {
        for (let dy = -3; dy <= 3; dy++) for (let dx = -3; dx <= 3; dx++)
          if (inWorld(x + dx, y + dy)) _waterCache[idx(x + dx, y + dy)] = 1;
      }
    }
  }
  return _waterCache[i] === 1;
}
function invalidateWaterCache() { _waterCache = null; }

// ── Tevredenheid per woongebouw + stadsgemiddelde ───────────
function simHappiness() {
  let sum = 0, wsum = 0;
  const taxPenalty = Math.max(0, (G.taxes.wonen - 8)) * 1.6;
  const p = G.stats.parkeren || { vraag: 0, cap: 0 };
  const parkeerTekort = p.vraag > 0 ? Math.max(0, 1 - p.cap / p.vraag) : 0;
  const voedsel = G.stats.voedsel || { ratio: 1 };
  eachBuilding(b => {
    if (b.capBew <= 0) { b.happy = 60; return; }
    const i = b.cells[0];
    let h = 58;
    h += G.svcEdu[i] * 10 + G.svcHealth[i] * 10 + G.svcSafety[i] * 7 + G.svcGreen[i] * 8 + G.svcTransit[i] * 5;
    h -= Math.min(22, G.pollution[i] * 2.4);
    h -= Math.min(12, G.noise[i] * 2.5);
    h -= taxPenalty;
    h -= Math.max(0, b.reistijd - 20) * 0.35;
    h -= parkeerTekort * 6;
    if (!b.powered) h -= 18;
    if (!b.watered) h -= 15;
    if (!b.roadOk) h -= 12;
    if (voedsel.ratio < 1) h -= (1 - voedsel.ratio) * 20;
    if (G.policies.sociale_bouw || G.techs.sociale_woningen) h += 4;
    if (G.policies.benzine_taks) h -= 1.5;
    if (G.policies.kern_verbod) h += 1;
    const lv = G.landValue[i];
    h += lv * 6;
    b.happy = Math.max(0, Math.min(100, h));
    for (const c of b.cells) G.happyMap[c] = b.happy / 100;
    sum += b.happy * b.bezet; wsum += b.bezet;
  });
  G.happy = wsum > 0 ? sum / wsum : 60;
}

// ── Migratie & woningtoewijzing ─────────────────────────────
function simMigration() {
  // vraagfactoren
  const vacancy = Math.max(0, (G.houseCap || 0) - G.pop);
  const jobRatio = G.pop > 0 ? G.jobs / Math.max(1, G.cohorts.werkenden) : 1;
  let aantrekkelijk = (G.happy - 45) / 55; // -0.8 .. +1
  aantrekkelijk += Math.min(0.5, (jobRatio - 0.9)) * 0.6;
  aantrekkelijk -= Math.max(0, (G.taxes.wonen - 10)) * 0.03;
  if (G.policies.sociale_bouw) aantrekkelijk += 0.08;
  const voedsel = G.stats.voedsel || { ratio: 1 };
  if (voedsel.ratio < 0.8) aantrekkelijk -= 0.4;

  let delta = 0;
  if (aantrekkelijk > 0 && vacancy > 0) {
    delta = Math.ceil(Math.min(vacancy, (3 + G.pop * 0.004) * aantrekkelijk));
  } else if (aantrekkelijk < -0.15) {
    delta = -Math.ceil(G.pop * 0.003 * -aantrekkelijk);
  }
  G.pop = Math.max(0, G.pop + delta);
  G.stats.migratie = delta;

  // verdeel inwoners over woningen (naar tevredenheid gewogen, simpel: vul beste eerst)
  let rest = G.pop;
  const homes = [];
  eachBuilding(b => { if (b.capBew > 0) homes.push(b); });
  homes.sort((a, b2) => b2.happy - a.happy);
  for (const b of homes) {
    const take = Math.min(b.capBew, rest);
    b.bezet = take; rest -= take;
  }
  if (rest > 0) G.pop -= rest; // dakloos → vertrekt

  // vraag-indicator voor UI
  G.demand.wonen = Math.max(0, Math.min(100, 50 + aantrekkelijk * 60 - (vacancy / Math.max(1, G.pop * 0.1)) * 20));
  const cRatio = G.jobs > 0 ? G.jobsFilled / G.jobs : 0;
  G.demand.commercieel = Math.round(Math.max(0, Math.min(100, (G.pop / 12) - getJobsOf("commercieel"))));
  G.demand.industrie = Math.round(Math.max(0, Math.min(100, (G.pop / 18) - getJobsOf("industrie"))));

  // voedselbalans
  let voedselProd = 0, verwerk = 0, winkels = 0;
  const lokaalBoost = G.policies.lokaal_voedsel ? 1.25 : 1;
  eachBuilding(b => {
    const def = BUILDINGS[b.type];
    if (def.voedsel) {
      let f = def.voedsel * b.cells.length * (0.5 + (G.fert[b.cells[0]] || 0.5)) * lokaalBoost;
      if (def.energieVast && !b.powered) f *= 0.3;
      voedselProd += f;
    }
    if (def.voedselVerwerk) verwerk += def.voedselVerwerk * b.cells.length * (b.powered ? 1 : 0.3);
    if (def.voedselWinkel) winkels += b.cells.length * 20;
  });
  const voedselNodig = Math.max(1, G.pop * 0.05);
  const effProd = Math.min(voedselProd, Math.max(verwerk, voedselProd * 0.4)); // verwerking vergroot bruikbaar deel
  // import vult het gat automatisch aan zolang er geld is (kosten in begroting)
  const imp = G.money > 0 ? Math.max(0, voedselNodig - effProd) : 0;
  G.stats.voedsel = {
    prod: voedselProd, verwerkt: effProd, nodig: voedselNodig,
    ratio: Math.min(1.2, (effProd + imp) / voedselNodig),
    importKosten: imp * (G.policies.goedkope_import ? 0.05 : 0.085),
  };
}
function getJobsOf(cat) {
  let s = 0;
  eachBuilding(b => { if (BUILDINGS[b.type].cat === cat) s += b.capBanen; });
  return s;
}

// ── Onderzoek ───────────────────────────────────────────────
function simResearch() {
  let rp = 0.15 + G.pop / 4000;
  eachBuilding(b => {
    const def = BUILDINGS[b.type];
    if (def.onderzoek) rp += def.onderzoek * b.cells.length * (b.powered ? 1 : 0.3) * 0.15;
  });
  rp += Object.keys(G.techs).length * 0.03; // innovatie-sneeuwbal
  G.rpPerDag = Math.round(rp * 100) / 100;
}

function canResearch(t) {
  if (G.techs[t.id]) return false;
  if (t.fase > G.fase) return false;
  if (t.req && !t.req.every(r => G.techs[r])) return false;
  return true;
}
function doResearch(t) {
  if (!canResearch(t) || G.rp < t.kosten) return false;
  G.rp -= t.kosten;
  G.techs[t.id] = true;
  addNews(`🔬 Onderzoek voltooid: ${t.naam}`, "good");
  UI.refreshTools(); UI.refreshRight();
  return true;
}
function canAdvancePhase() {
  const next = PHASES[G.fase + 1];
  if (!next) return false;
  return G.pop >= next.popEis && G.rp >= (next.rp || 0);
}
function advancePhase() {
  if (!canAdvancePhase()) return;
  const next = PHASES[G.fase + 1];
  G.rp -= (next.rp || 0);
  G.fase++;
  addNews(`🏙 Je stad is gegroeid naar fase ${G.fase}: ${next.naam}! Nieuwe gebouwen ontgrendeld.`, "good");
  UI.refreshTools(); UI.refreshRight(); UI.refreshTop();
}

// ── Maandelijkse begroting ──────────────────────────────────
function simMonth() {
  const inc = {}, out = {};
  // inkomsten
  let woonB = 0, bedrijfB = 0, verkoopB = 0, toerisme = 0;
  eachBuilding(b => {
    const def = BUILDINGS[b.type];
    if (b.bezet > 0) woonB += b.bezet * (0.9 + G.landValue[b.cells[0]]) * G.taxes.wonen * 0.11;
    if (b.werkers > 0) {
      let prof = b.werkers * (b.inkomen || 1) * 0.5;
      if (G.policies.co2_belasting && def.cat === "industrie") prof *= 0.9;
      bedrijfB += prof * G.taxes.bedrijf * 0.055;
      if (def.use === "winkel" || (b.floors || []).some(f => f.use === "winkel" || f.use === "restaurant"))
        verkoopB += b.werkers * G.taxes.verkoop * 0.16;
    }
    if (def.toerisme) toerisme += def.toerisme * b.cells.length * 0.6 * (G.happy / 70);
  });
  inc["Woonbelasting"] = woonB;
  inc["Bedrijfsbelasting"] = bedrijfB;
  inc["Verkoopbelasting"] = verkoopB;
  if (toerisme > 0.5) inc["Toerisme"] = toerisme;
  const ov = G.stats.ov || { riders: 0, opCost: 0 };
  if (ov.riders > 0) inc["OV-kaartjes"] = ov.riders * 0.045 * (G.policies.ov_subsidie ? 0.5 : 1);
  if (G.policies.co2_belasting) inc["CO₂-heffing"] = 3 + G.pop * 0.002;
  if (G.policies.benzine_taks) inc["Benzinebelasting"] = 2.5 + G.pop * 0.0018;

  // uitgaven
  let wegOnd = 0;
  for (let i = 0; i < N; i++) if (G.road[i] > 0) wegOnd += ROADS[G.road[i]].onderhoud;
  out["Wegenonderhoud"] = wegOnd;
  let publiekOnd = 0;
  eachBuilding(b => {
    const def = BUILDINGS[b.type];
    publiekOnd += (def.onderhoud || 0) * b.cells.length * b.floors.length;
  });
  out["Voorzieningen"] = publiekOnd;
  if (ov.opCost > 0) out["OV-exploitatie"] = ov.opCost * 30;
  let polKosten = 0;
  for (const pol of POLICIES) if (G.policies[pol.id] && pol.kosten > 0) polKosten += pol.kosten;
  for (const pol of POLICIES) if (G.policies[pol.id] && pol.kosten < 0) inc["Heffingen (beleid)"] = (inc["Heffingen (beleid)"] || 0) - pol.kosten;
  if (polKosten > 0) out["Beleid & subsidies"] = polKosten;
  const voedsel = G.stats.voedsel;
  if (voedsel && voedsel.importKosten > 0.05) out["Voedselimport"] = voedsel.importKosten * 30;
  const mat = G.stats.materiaal || { balans: 0 };
  if (mat.balans < 0) out["Materiaalimport"] = -mat.balans * 0.4;

  const totIn = Object.values(inc).reduce((a, b) => a + b, 0);
  const totOut = Object.values(out).reduce((a, b) => a + b, 0);
  const saldo = totIn - totOut;
  G.money += saldo * 30; // maandbedragen zijn "per dag"-genormaliseerd × 30
  G.lastBudget = { in: inc, uit: out, saldo: saldo * 30 };

  // materiaalbalans (industrie produceert, bouw verbruikt via bouwkosten al)
  let matProd = 0;
  eachBuilding(b => {
    const def = BUILDINGS[b.type];
    if (def.materiaal) matProd += def.materiaal * b.cells.length * (b.powered ? 1 : 0.3);
  });
  G.stats.materiaal = { prod: matProd, balans: matProd - G.pop * 0.004 };

  if (G.money < -50000 && !G.gameOver && !sandbox()) {
    addNews("💸 De stad is failliet aan het gaan! Verlaag uitgaven of verhoog belastingen.", "bad");
  }
  UI.refreshRight();
}

// ── Willekeurige gebeurtenissen / crises ────────────────────
function maybeEvent() {
  if (G.pop < 50 || RNG() > 0.012) return;
  const e = G.stats.energie, w = G.stats.water;
  const events = [];
  if (e && e.vraag > e.aanbod * 0.95) events.push(() => {
    addNews("⚡ Stroomstoring! Het net is overbelast — delen van de stad zitten zonder stroom.", "bad");
  });
  if (w && w.vraag > w.aanbod * 0.9) events.push(() => {
    G.weerFactor = Math.max(0.35, G.weerFactor - 0.2);
    addNews("🌵 Droogte! De watervraag nadert het aanbod. Bouw extra pompen of zuiveringen.", "warn");
  });
  events.push(() => {
    G.weerFactor = Math.max(0.35, G.weerFactor - 0.25);
    addNews("🌥 Een week grijs weer: wind- en zonne-energie leveren minder op.", "warn");
  });
  if (G.stats.voedsel && G.stats.voedsel.ratio < 0.95) events.push(() => {
    addNews("🌾 Voedseltekort dreigt: de import wordt duurder deze maand.", "warn");
    G.money -= 40 + G.pop * 0.05;
  });
  events.push(() => {
    const amt = Math.round(G.pop * 0.4 + 60);
    G.money += amt;
    addNews(`🎉 Regionale subsidie ontvangen: € ${amt.toLocaleString("nl-NL")}.`, "good");
  });
  if (G.pop > 2000) events.push(() => {
    addNews("📉 Economische dip: bedrijfsbelasting levert deze maand 20% minder op.", "warn");
    G.money -= G.pop * 0.03;
  });
  // brand als er geen brandweer dekking is
  const homes = G.buildings.filter(b => b && b.capBew > 0 && G.svcSafety[b.cells[0]] < 0.15);
  if (homes.length > 3 && RNG() < 0.35) events.push(() => {
    const b = homes[(RNG() * homes.length) | 0];
    addNews(`🔥 Brand in ${b.naam}! Zonder brandweer in de buurt is het pand verwoest.`, "bad");
    removeBuilding(b);
  });
  if (events.length) events[(RNG() * events.length) | 0]();
}

function addNews(msg, kind = "") {
  G.news.unshift({ msg, kind, t: `${G.day}-${G.month}-${G.year}` });
  if (G.news.length > 40) G.news.pop();
  UI.toast(msg, kind);
  UI.setNews(msg);
}
