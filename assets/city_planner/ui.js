// ─────────────────────────────────────────────────────────────
// MetroPlan — UI: gereedschappen, panelen, inspecteur, statusbalk
// ─────────────────────────────────────────────────────────────
"use strict";

const UI = {
  selected: null,       // geselecteerd gebouw
  tab: "inspect",
  tool: { kind: "select" }, // {kind: select|road|bulldoze|terrain|building|transit, ...}
};

const $ = s => document.querySelector(s);
const el = (tag, cls, html) => {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (html !== undefined) e.innerHTML = html;
  return e;
};
const fmtGeld = v => "€ " + Math.round(v).toLocaleString("nl-NL");
const fmtNum = v => Math.round(v).toLocaleString("nl-NL");
// inline SVG-icoon uit de sprite in index.html
const icon = (name, cls = "ic") => `<svg class="${cls}" aria-hidden="true"><use href="#i-${name}"/></svg>`;

// ── Linker gereedschapsbalk ─────────────────────────────────
UI.buildTools = function () {
  const left = $("#left");
  left.innerHTML = "";

  const cat = (naam, ico, open) => {
    const c = el("div", "toolcat" + (open ? " open" : ""));
    const head = el("div", "cathead", `${icon(ico)}<span>${naam}</span>${icon("chevron", "ic chev")}`);
    head.onclick = () => c.classList.toggle("open");
    const body = el("div", "catbody");
    c.append(head, body);
    left.append(c);
    return body;
  };
  const toolBtn = (body, label, opts) => {
    const b = el("button", "toolbtn");
    if (opts.kleur) b.append(Object.assign(el("span", "sw"), { style: `background:${opts.kleur}` }));
    b.append(el("span", "", label));
    if (opts.prijs !== undefined) b.append(el("span", "price", opts.locked ? `${icon("lock")} ${opts.lockLabel || ""}` : sandbox() ? "gratis" : fmtGeld(opts.prijs)));
    if (opts.locked) b.classList.add("locked");
    b.onclick = () => {
      if (opts.locked) { UI.toast(opts.lockMsg || "Nog niet ontgrendeld — zie Onderzoek.", "warn"); return; }
      opts.onpick();
      UI.markActiveTool(b);
    };
    b.dataset.toolkey = opts.key || label;
    body.append(b);
    return b;
  };

  // Algemeen
  const alg = cat("Algemeen", "cursor", true);
  toolBtn(alg, "Selecteren / inspecteren", { key: "select", onpick: () => UI.setTool({ kind: "select" }) });
  toolBtn(alg, "Slopen", { key: "bulldoze", onpick: () => UI.setTool({ kind: "bulldoze" }) });

  // Raster & plaatsing: het grid is een hulpmiddel, nooit een verplichting
  const rst = cat("Raster & plaatsing", "grid", false);
  const s = G.settings;
  toolBtn(rst, icon(s.grid ? "check-square" : "square") + " Grid tonen (G)", {
    key: "set-grid", onpick: () => { s.grid = !s.grid; UI.refreshTools(); },
  });
  toolBtn(rst, icon(s.snap ? "check-square" : "square") + " Snappen (S)", {
    key: "set-snap", onpick: () => { s.snap = !s.snap; UI.refreshTools(); },
  });
  toolBtn(rst, icon(s.invertZoom ? "check-square" : "square") + " Zoomrichting omkeren", {
    key: "set-invert-zoom", onpick: () => { s.invertZoom = !s.invertZoom; UI.refreshTools(); },
  });
  const gsRow = el("div", "row");
  gsRow.style.cssText = "padding:2px 8px;gap:8px";
  gsRow.append(el("span", "muted", "Gridgrootte"));
  const gsSel = el("select");
  for (const v of [1, 2, 3, 4]) {
    const o = el("option", "", v + "×" + v); o.value = v;
    if (s.gridSize === v) o.selected = true;
    gsSel.append(o);
  }
  gsSel.onchange = () => { s.gridSize = +gsSel.value; };
  gsRow.append(gsSel);
  rst.append(gsRow);
  rst.append(el("div", "muted", `<div style="padding:4px 8px">Houd <b>Alt</b> ingedrukt om snappen tijdelijk om te keren — zo plaats je alles volledig vrij (ook tussen gridcellen).</div>`));

  // Wegen — vrij tekenen, de engine maakt er vloeiende bochten van
  const weg = cat("Wegen", "route", true);
  for (let r = 1; r < ROADS.length; r++) {
    const rd = ROADS[r];
    const locked = rd.fase > G.fase || (rd.tech && !G.techs[rd.tech]);
    toolBtn(weg, rd.naam, {
      key: "road" + r, kleur: rd.kleur, prijs: rd.kosten, locked,
      lockLabel: rd.tech && !G.techs[rd.tech] ? "tech" : `fase ${rd.fase}`,
      onpick: () => {
        UI.setTool({ kind: "road", road: r });
        UI.toast("Sleep vrij over de kaart — de engine maakt er automatisch een vloeiende weg van. Kruisende wegen worden vanzelf kruispunten.", "");
      },
    });
  }
  toolBtn(weg, "Rotonde", {
    key: "roundabout", prijs: ROADS[2].kosten * 8,
    locked: !G.techs.rotondes,
    lockLabel: "tech",
    lockMsg: "Vereist onderzoek: Rotondes.",
    onpick: () => { UI.setTool({ kind: "roundabout", road: 2 }); UI.toast("Klik om een rotonde te plaatsen; sluit er wegen op aan.", ""); },
  });

  // OV
  const ov = cat("Openbaar vervoer", "bus", false);
  for (const [k, tt] of Object.entries(TRANSIT_TYPES)) {
    const locked = tt.fase > G.fase || (tt.tech && !G.techs[tt.tech]);
    toolBtn(ov, tt.naam + " tekenen", {
      key: "transit" + k, kleur: tt.kleur, prijs: tt.kostenHalte, locked,
      lockLabel: tt.tech && !G.techs[tt.tech] ? "tech" : `fase ${tt.fase}`,
      onpick: () => { UI.setTool({ kind: "transit", type: k }); UI.toast("Klik haltes op wegen; dubbelklik of Enter om de lijn af te ronden.", ""); },
    });
  }

  // Terrein
  const ter = cat("Terrein", "mountain", false);
  for (const t of TERRAIN_TOOLS) {
    toolBtn(ter, t.naam, {
      key: "terr" + t.id, prijs: t.kosten,
      onpick: () => UI.setTool({ kind: "terrain", terrain: t.id }),
    });
  }

  // Gebouwcategorieën
  const CATS = [
    ["wonen", "Wonen", "home"], ["commercieel", "Commercieel", "store"], ["industrie", "Industrie", "factory"],
    ["voedsel", "Voedsel & landbouw", "sprout"], ["publiek", "Publiek", "landmark"], ["energie", "Energie", "zap"],
    ["water", "Water & afval", "droplet"], ["transport", "Transport & parkeren", "parking"],
  ];
  for (const [catKey, label, ico] of CATS) {
    const body = cat(label, ico, catKey === "wonen");
    for (const [key, def] of Object.entries(BUILDINGS)) {
      if (def.cat !== catKey) continue;
      const locked = def.fase > G.fase || (def.tech && !G.techs[def.tech]);
      toolBtn(body, def.naam, {
        key: "bld" + key, kleur: def.kleur, prijs: def.kosten * buildCostFactor(), locked,
        lockLabel: def.tech && !G.techs[def.tech] ? "tech" : `fase ${def.fase}`,
        lockMsg: def.tech && !G.techs[def.tech]
          ? `Vereist onderzoek: ${(TECHS.find(t => t.id === def.tech) || {}).naam || def.tech}`
          : `Beschikbaar vanaf fase ${def.fase} (${PHASES[def.fase].naam}).`,
        onpick: () => {
          UI.setTool({ kind: "building", type: key });
          UI.toast(`Teken de vorm van je ${def.naam.toLowerCase()} door cellen te slepen. Kosten: ${fmtGeld(def.kosten * buildCostFactor())} per cel per verdieping.`, "");
        },
      });
    }
  }

  // Analyse
  const ana = cat("Analyse", "chart", false);
  for (const hm of HEATMAPS) {
    toolBtn(ana, hm.naam.replace("Heatmap: ", "").replace("Kaartweergave: ", ""), {
      key: "hm" + hm.id,
      onpick: () => { heatmapMode = hm.id; $("#heatmapsel").value = hm.id; },
    });
  }
  UI.markActiveTool(left.querySelector(`[data-toolkey="${UI.toolKey()}"]`));
};

UI.toolKey = function () {
  const t = UI.tool;
  return t.kind === "road" ? "road" + t.road : t.kind === "building" ? "bld" + t.type :
    t.kind === "terrain" ? "terr" + t.terrain : t.kind === "transit" ? "transit" + t.type : t.kind;
};
UI.setTool = function (t) {
  UI.tool = t;
  Input.cancelDrafts();
};
UI.markActiveTool = function (btn) {
  document.querySelectorAll(".toolbtn.active").forEach(b => b.classList.remove("active"));
  if (btn) btn.classList.add("active");
};
UI.refreshTools = function () { UI.buildTools(); };

// ── Rechter paneel ──────────────────────────────────────────
document.querySelectorAll("#righttabs button").forEach(b => {
  b.onclick = () => {
    document.querySelectorAll("#righttabs button").forEach(x => x.classList.remove("active"));
    b.classList.add("active");
    UI.tab = b.dataset.tab;
    UI.refreshRight();
  };
});

UI.refreshRight = function () {
  const body = $("#rightbody");
  switch (UI.tab) {
    case "inspect": return UI.renderInspector(body);
    case "research": return UI.renderResearch(body);
    case "finance": return UI.renderFinance(body);
    case "policy": return UI.renderPolicy(body);
    case "transit": return UI.renderTransit(body);
    case "stats": return UI.renderStats(body);
  }
};

// ── Inspecteur ──────────────────────────────────────────────
UI.selectBuilding = function (b) {
  UI.selected = b;
  UI.tab = "inspect";
  document.querySelectorAll("#righttabs button").forEach(x => x.classList.toggle("active", x.dataset.tab === "inspect"));
  UI.refreshRight();
};

UI.renderInspector = function (body) {
  const b = UI.selected && G.buildings[UI.selected.id] ? UI.selected : null;
  if (!b) {
    body.innerHTML = `<div class="muted">Klik op een gebouw om het te inspecteren en aan te passen.<br><br>
      Tips:<br>· Teken gebouwen in elke vorm door cellen te slepen.<br>
      · Gebouwen hebben een weg nodig, en stroom + water via dat wegennet.<br>
      · Gebruik de heatmaps (Analyse of rechtsboven) om problemen te vinden.</div>`;
    return;
  }
  const def = BUILDINGS[b.type];
  body.innerHTML = "";
  const card = el("div", "card");
  const nameInput = el("input");
  nameInput.type = "text"; nameInput.value = b.naam;
  nameInput.onchange = () => { b.naam = nameInput.value; };
  card.append(nameInput);
  card.append(el("div", "muted", `${def.naam} · gebouwd in ${b.jaar} · ${b.cells.length} cellen · ${b.floors.length} verdieping(en)`));
  body.append(card);

  const info = el("div", "card");
  const kv = (k, v, warn) => info.append(el("div", "kv", `<span class="k">${k}</span><span class="v"${warn ? ' style="color:var(--bad)"' : ""}>${v}</span>`));
  kv("Waarde", fmtGeld((b.waarde || 0) * 100));
  kv("Onderhoud", fmtGeld((def.onderhoud || 0) * b.cells.length * b.floors.length * 30) + "/mnd");
  kv("Energieverbruik", (b.energie || 0).toFixed(1) + " MW", !b.powered);
  kv("Waterverbruik", (b.water || 0).toFixed(1) + " kL", !b.watered);
  if (b.capBew > 0) kv("Bewoners", `${fmtNum(b.bezet)} / ${fmtNum(b.capBew)}`);
  if (b.capBanen > 0) kv("Werknemers", `${fmtNum(b.werkers)} / ${fmtNum(b.capBanen)}`);
  if (b.capBew > 0) kv("Tevredenheid", Math.round(b.happy) + "%", b.happy < 40);
  if (b.bezet > 0) kv("Gem. reistijd", Math.round(b.reistijd) + " min", b.reistijd > 40);
  kv("Weg aangesloten", b.roadOk ? "✔" : "✘ geen weg!", !b.roadOk);
  kv("Stroom", b.powered ? "✔" : "✘ tekort", !b.powered);
  kv("Water", b.watered ? "✔" : "✘ tekort", !b.watered);
  const dEf = BUILDINGS[b.type];
  if (dEf.energieProd) kv("Energieproductie", (dEf.energieProd * b.cells.length * (dEf.hernieuwbaar ? G.weerFactor : 1)).toFixed(0) + " MW");
  if (dEf.waterProd) kv("Waterproductie", (dEf.waterProd * b.cells.length).toFixed(0) + " kL");
  if (dEf.parkeren) kv("Parkeerplaatsen", fmtNum(dEf.parkeren * b.cells.length * b.floors.length));
  body.append(info);

  // Verdiepingen-editor
  body.append(el("h3", "", "Verdiepingen"));
  const fl = el("div", "card");
  const allowedUses = Object.keys(FLOOR_USES);
  b.floors.forEach((f, k) => {
    const row = el("div", "floorrow");
    row.append(el("span", "fnum", "V" + (k + 1)));
    const sel = el("select");
    for (const u of allowedUses) {
      const o = el("option", "", FLOOR_USES[u].naam);
      o.value = u;
      if (f.use === u) o.selected = true;
      sel.append(o);
    }
    sel.onchange = () => { f.use = sel.value; recomputeCapacities(); UI.refreshRight(); };
    row.append(sel);
    const cap = buildingFloorSummary(b, f);
    row.append(el("span", "muted", cap));
    fl.append(row);
  });
  const btnrow = el("div", "row");
  const add = el("button", "", "+ Verdieping");
  add.onclick = () => {
    if (b.floors.length >= def.maxVerd) { UI.toast(`Maximaal ${def.maxVerd} verdiepingen voor dit type.`, "warn"); return; }
    const cost = def.kosten * b.cells.length * buildCostFactor();
    if (!canPay(cost)) { UI.toast("Onvoldoende geld.", "bad"); return; }
    pay(cost);
    b.floors.push({ use: def.use });
    recomputeCapacities(); UI.refreshRight(); UI.refreshTop();
  };
  const rem = el("button", "", "− Verdieping");
  rem.onclick = () => {
    if (b.floors.length <= 1) return;
    b.floors.pop();
    recomputeCapacities(); UI.refreshRight();
  };
  btnrow.append(add, rem);
  fl.append(btnrow);
  body.append(fl);

  const del = el("button", "", icon("trash") + " Gebouw slopen");
  del.style.cssText = "width:100%;margin-top:8px;border-color:var(--bad);color:var(--bad)";
  del.onclick = () => {
    removeBuilding(b);
    UI.selected = null;
    recomputeCapacities();
    UI.refreshRight();
  };
  body.append(del);
};
function buildingFloorSummary(b, f) {
  const u = FLOOR_USES[f.use];
  const c = b.cells.length;
  if (u.bew) return `${Math.round(u.bew * c)} bew.`;
  if (u.banen) return `${Math.round(u.banen * c)} banen`;
  return "—";
}

// ── Onderzoek ───────────────────────────────────────────────
UI.renderResearch = function (body) {
  body.innerHTML = "";
  if (sandbox()) {
    body.append(el("div", "card", "<b>Sandbox</b><br><span class='muted'>Alle technologie en fasen zijn al ontgrendeld — er valt niets te onderzoeken. Bouw erop los!</span>"));
    return;
  }
  const head = el("div", "card");
  head.append(el("div", "kv", `<span class="k">Onderzoekspunten</span><span class="v">${icon("flask")} ${fmtNum(G.rp)} (+${G.rpPerDag}/dag)</span>`));
  head.append(el("div", "muted", "Punten komen uit bevolking, universiteiten en technologiebedrijven."));
  body.append(head);

  // fase-progressie
  const next = PHASES[G.fase + 1];
  const ph = el("div", "card");
  ph.append(el("div", "", `<b>Fase ${G.fase}: ${PHASES[G.fase].naam}</b>`));
  if (next) {
    ph.append(el("div", "muted", `Volgende: ${next.naam} — vereist ${fmtNum(next.popEis)} inwoners en ${fmtNum(next.rp || 0)} onderzoekspunten`));
    const bar = el("div", "bar"); const fill = el("div");
    fill.style.width = Math.min(100, G.pop / next.popEis * 100) + "%";
    bar.append(fill); ph.append(bar);
    const btn = el("button", "", `Groei naar ${next.naam}`);
    btn.disabled = !canAdvancePhase();
    btn.style.cssText = "width:100%;margin-top:6px";
    btn.onclick = () => { advancePhase(); };
    ph.append(btn);
  } else {
    ph.append(el("div", "muted", "Je hebt de hoogste fase bereikt: de Toekomststad!"));
  }
  body.append(ph);

  const CATS = { transport: "Transport", bouw: "Bouw", energie: "Energie", milieu: "Milieu", sociaal: "Sociaal" };
  for (const [ck, cl] of Object.entries(CATS)) {
    body.append(el("h3", "", cl));
    for (const t of TECHS) {
      if (t.cat !== ck) continue;
      const done = !!G.techs[t.id];
      const avail = canResearch(t);
      const n = el("div", "techn " + (done ? "done" : avail ? "avail" : ""));
      n.append(el("div", "tname", (done ? "✔ " : "") + t.naam + ` <span class="muted">(${t.kosten} ${icon("flask")})</span>`));
      n.append(el("div", "tdesc", t.desc + (t.req ? ` Vereist: ${t.req.map(r => (TECHS.find(x => x.id === r) || {}).naam).join(", ")}.` : "") + (t.fase > G.fase ? ` [fase ${t.fase}]` : "")));
      if (!done && avail) {
        const btn = el("button", "", "Onderzoeken");
        btn.disabled = G.rp < t.kosten;
        btn.onclick = () => { doResearch(t); UI.refreshRight(); };
        n.append(btn);
      }
      body.append(n);
    }
  }
};

// ── Financiën ───────────────────────────────────────────────
UI.renderFinance = function (body) {
  body.innerHTML = "";
  const bud = el("div", "card");
  bud.append(el("h3", "", "Maandbegroting (laatste)"));
  const B = G.lastBudget;
  for (const [k, v] of Object.entries(B.in)) bud.append(el("div", "kv", `<span class="k">${k}</span><span class="v" style="color:var(--good)">+${fmtGeld(v * 30)}</span>`));
  for (const [k, v] of Object.entries(B.uit)) bud.append(el("div", "kv", `<span class="k">${k}</span><span class="v" style="color:var(--bad)">−${fmtGeld(v * 30)}</span>`));
  bud.append(el("div", "kv", `<span class="k"><b>Saldo</b></span><span class="v"><b style="color:${B.saldo >= 0 ? "var(--good)" : "var(--bad)"}">${fmtGeld(B.saldo)}</b></span>`));
  body.append(bud);

  body.append(el("h3", "", "Belastingen"));
  const tax = el("div", "card");
  const taxRow = (key, label) => {
    const row = el("div", "taxrow");
    row.append(el("span", "k", label));
    const r = el("input"); r.type = "range"; r.min = 0; r.max = 25; r.value = G.taxes[key];
    const v = el("span", "v", G.taxes[key] + "%");
    r.oninput = () => { G.taxes[key] = +r.value; v.textContent = r.value + "%"; };
    row.append(r, v);
    tax.append(row);
  };
  taxRow("wonen", "Woonbelasting");
  taxRow("bedrijf", "Bedrijfsbelasting");
  taxRow("verkoop", "Verkoopbelasting");
  tax.append(el("div", "muted", "Hoge belastingen remmen tevredenheid en migratie."));
  body.append(tax);

  body.append(el("h3", "", "Stadsmiddelen"));
  const res = el("div", "card");
  const st = G.stats;
  const line = (label, vraag, aanbod, unit) => {
    const ok = aanbod >= vraag;
    res.append(el("div", "kv", `<span class="k">${label}</span><span class="v" style="color:${ok ? "var(--good)" : "var(--bad)"}">${fmtNum(aanbod)} / ${fmtNum(vraag)} ${unit}</span>`));
  };
  if (st.energie) line("Energie (aanbod/vraag)", st.energie.vraag, st.energie.aanbod, "MW");
  if (st.water) line("Water", st.water.vraag, st.water.aanbod, "kL");
  if (st.riool) line("Riolering", st.riool.vraag, st.riool.cap, "kL");
  if (st.afval) line("Afvalverwerking", st.afval.vraag, st.afval.cap, "t");
  if (st.voedsel) {
    res.append(el("div", "kv", `<span class="k">Voedsel lokaal</span><span class="v">${fmtNum(st.voedsel.verwerkt)} / ${fmtNum(st.voedsel.nodig)}</span>`));
    if (st.voedsel.importKosten > 0.05) res.append(el("div", "kv", `<span class="k">↳ importkosten</span><span class="v" style="color:var(--warn)">${fmtGeld(st.voedsel.importKosten * 30)}/mnd</span>`));
  }
  if (st.materiaal) res.append(el("div", "kv", `<span class="k">Materiaalbalans</span><span class="v" style="color:${st.materiaal.balans >= 0 ? "var(--good)" : "var(--warn)"}">${st.materiaal.balans >= 0 ? "+" : ""}${st.materiaal.balans.toFixed(1)}</span>`));
  if (st.parkeren) line("Parkeren", st.parkeren.vraag, st.parkeren.cap, "pl.");
  res.append(el("div", "muted", `Weerfactor hernieuwbaar: ${(G.weerFactor * 100) | 0}% — batterijen dempen dips.`));
  body.append(res);
};

// ── Beleid ──────────────────────────────────────────────────
UI.renderPolicy = function (body) {
  body.innerHTML = "";
  body.append(el("div", "muted", "Wetten en beleid werken direct door in de simulatie. Kosten of opbrengsten lopen via de maandbegroting."));
  let lastCat = "";
  for (const p of POLICIES) {
    if (p.cat !== lastCat) { body.append(el("h3", "", p.cat)); lastCat = p.cat; }
    const row = el("div", "polrow");
    const locked = p.fase > G.fase;
    const left = el("div");
    left.append(el("div", "", `<b>${p.naam}</b> <span class="muted">${p.kosten > 0 ? fmtGeld(p.kosten * 30) + "/mnd" : p.kosten < 0 ? "+" + fmtGeld(-p.kosten * 30) + "/mnd" : ""}</span>`));
    left.append(el("div", "muted", p.desc + (locked ? ` [vanaf fase ${p.fase}]` : "")));
    const btn = el("button", "", G.policies[p.id] ? "Actief" : "Uit");
    if (G.policies[p.id]) btn.classList.add("active");
    btn.disabled = locked;
    btn.onclick = () => { G.policies[p.id] = !G.policies[p.id]; UI.renderPolicy(body); };
    row.append(left, btn);
    body.append(row);
  }
};

// ── OV-lijnen ───────────────────────────────────────────────
UI.renderTransit = function (body) {
  body.innerHTML = "";
  body.append(el("div", "muted", "Kies links een OV-type en klik haltes op wegen. Dubbelklik (of Enter) om de lijn af te ronden. Elke lijn heeft een depot van het juiste type nodig."));
  const st = G.stats.ov;
  if (st) {
    const c = el("div", "card");
    c.append(el("div", "kv", `<span class="k">Reizigers/dag</span><span class="v">${fmtNum(st.riders)}</span>`));
    c.append(el("div", "kv", `<span class="k">Netwerkcapaciteit</span><span class="v">${fmtNum(st.cap)}</span>`));
    body.append(c);
  }
  for (const l of G.transitLines) {
    const tt = TRANSIT_TYPES[l.type];
    const c = el("div", "card");
    c.append(el("div", "", `<span class="sw" style="display:inline-block;width:10px;height:10px;border-radius:3px;background:${tt.kleur}"></span> <b>${l.naam}</b> <span class="muted">(${tt.naam.toLowerCase()}, ${l.stops.length} haltes)</span>`));
    c.append(el("div", "kv", `<span class="k">Reizigers</span><span class="v">${fmtNum(l.ridership || 0)}/dag</span>`));
    const row = el("div", "row");
    const freq = el("select");
    for (const [v, lbl] of [[1, "Lage frequentie"], [2, "Normale frequentie"], [3, "Hoge frequentie"]]) {
      const o = el("option", "", lbl); o.value = v;
      if (l.freq === v) o.selected = true;
      freq.append(o);
    }
    freq.onchange = () => { l.freq = +freq.value; };
    const act = el("button", "", l.actief ? "Actief" : "Gepauzeerd");
    if (l.actief) act.classList.add("active");
    act.onclick = () => { l.actief = !l.actief; UI.refreshRight(); };
    const del = el("button", "", icon("trash"));
    del.title = "Lijn verwijderen";
    del.onclick = () => { G.transitLines = G.transitLines.filter(x => x !== l); UI.refreshRight(); };
    row.append(freq, act, del);
    c.append(row);
    body.append(c);
  }
  if (!G.transitLines.length) body.append(el("div", "muted", "Nog geen lijnen."));
};

// ── Stad / statistieken ─────────────────────────────────────
UI.renderStats = function (body) {
  body.innerHTML = "";
  const c1 = el("div", "card");
  c1.append(el("h3", "", "Bevolking"));
  c1.append(el("div", "kv", `<span class="k">Totaal</span><span class="v">${fmtNum(G.pop)}</span>`));
  c1.append(el("div", "kv", `<span class="k">Kinderen</span><span class="v">${fmtNum(G.cohorts.kinderen)}</span>`));
  c1.append(el("div", "kv", `<span class="k">Studenten</span><span class="v">${fmtNum(G.cohorts.studenten)}</span>`));
  c1.append(el("div", "kv", `<span class="k">Werkenden</span><span class="v">${fmtNum(G.cohorts.werkenden)}</span>`));
  c1.append(el("div", "kv", `<span class="k">Ouderen</span><span class="v">${fmtNum(G.cohorts.ouderen)}</span>`));
  c1.append(el("div", "kv", `<span class="k">Migratie vandaag</span><span class="v">${G.stats.migratie > 0 ? "+" : ""}${fmtNum(G.stats.migratie || 0)}</span>`));
  c1.append(el("div", "kv", `<span class="k">Woningcapaciteit</span><span class="v">${fmtNum(G.houseCap || 0)}</span>`));
  body.append(c1);

  const c2 = el("div", "card");
  c2.append(el("h3", "", "Werk & onderwijs"));
  c2.append(el("div", "kv", `<span class="k">Banen (bezet/totaal)</span><span class="v">${fmtNum(G.jobsFilled)} / ${fmtNum(G.jobs)}</span>`));
  c2.append(el("div", "kv", `<span class="k">Werkloosheid</span><span class="v">${Math.round((G.stats.werkloosheid || 0) * 100)}%</span>`));
  const sc = G.stats.schoolCap || {};
  c2.append(el("div", "kv", `<span class="k">Basisschoolplaatsen</span><span class="v">${fmtNum(sc.basis || 0)} / ${fmtNum(G.cohorts.kinderen * 0.6)}</span>`));
  c2.append(el("div", "kv", `<span class="k">Middelbare plaatsen</span><span class="v">${fmtNum(sc.middelbaar || 0)} / ${fmtNum(G.cohorts.kinderen * 0.4)}</span>`));
  c2.append(el("div", "kv", `<span class="k">Universiteitsplaatsen</span><span class="v">${fmtNum(sc.universiteit || 0)} / ${fmtNum(G.cohorts.studenten)}</span>`));
  c2.append(el("div", "kv", `<span class="k">Zorgcapaciteit</span><span class="v">${fmtNum(G.stats.zorgCap || 0)} / ${fmtNum(G.pop * 0.1)}</span>`));
  body.append(c2);

  const c3 = el("div", "card");
  c3.append(el("h3", "", "Verkeer & milieu"));
  const v = G.stats.verkeer || {};
  c3.append(el("div", "kv", `<span class="k">Drukte-index</span><span class="v">${Math.round((v.drukte || 0) * 100)}%</span>`));
  c3.append(el("div", "kv", `<span class="k">Gem. reistijd</span><span class="v">${Math.round(v.reistijd || 0)} min</span>`));
  let pol = 0; for (let i = 0; i < N; i += 4) pol += G.pollution[i];
  c3.append(el("div", "kv", `<span class="k">Vervuilingsindex</span><span class="v">${Math.round(pol / (N / 4) * 25)}</span>`));
  body.append(c3);

  const c4 = el("div", "card");
  c4.append(el("h3", "", "Nieuws"));
  for (const n of G.news.slice(0, 12)) c4.append(el("div", "muted", `<b>${n.t}</b> — ${n.msg}`));
  if (!G.news.length) c4.append(el("div", "muted", "Nog geen nieuws."));
  body.append(c4);
};

// ── Bovenbalk & statuschips ─────────────────────────────────
const MAANDEN = ["jan", "feb", "mrt", "apr", "mei", "jun", "jul", "aug", "sep", "okt", "nov", "dec"];
UI.refreshTop = function () {
  $("#ui-date").textContent = `${G.day} ${MAANDEN[G.month - 1]} ${G.year}`;
  $("#ui-money").textContent = sandbox() ? "∞" : fmtGeld(G.money);
  $("#ui-money").style.color = !sandbox() && G.money < 0 ? "var(--bad)" : "";
  const s = G.lastBudget.saldo;
  $("#ui-cashflow").textContent = s ? (s > 0 ? `+${fmtGeld(s)}/mnd` : `${fmtGeld(s)}/mnd`) : "";
  $("#ui-cashflow").style.color = s >= 0 ? "var(--good)" : "var(--bad)";
  $("#ui-pop").textContent = fmtNum(G.pop);
  $("#ui-rp").textContent = fmtNum(G.rp);
  $("#ui-phase").textContent = sandbox() ? "Sandbox" : `Fase ${G.fase} · ${PHASES[G.fase].naam}`;
};

UI.refreshChips = function () {
  const chip = (id, val, txt) => {
    const c = $(id);
    c.querySelector("b").textContent = txt;
    c.style.borderColor = val > 0.66 ? "var(--good)" : val > 0.33 ? "var(--warn)" : "var(--bad)";
  };
  chip("#chip-happy", G.happy / 100, Math.round(G.happy) + "%");
  const s = G.lastBudget.saldo;
  chip("#chip-budget", s >= 0 ? 1 : 0, (s >= 0 ? "+" : "") + fmtGeld(s));
  const short = (G.houseCap || 0) - G.pop;
  chip("#chip-housing", short > 0 ? 1 : 0.2, short >= 0 ? `${fmtNum(short)} vrij` : `${fmtNum(-short)} tekort`);
  const v = G.stats.verkeer || { drukte: 0 };
  chip("#chip-traffic", 1 - Math.min(1, v.drukte), Math.round(v.drukte * 100) + "%");
  const sc = G.stats.schoolCap || { basis: 0 };
  const eduNeed = Math.max(1, G.cohorts.kinderen);
  chip("#chip-edu", Math.min(1, ((sc.basis || 0) + (sc.middelbaar || 0)) / eduNeed), Math.round(Math.min(1, ((sc.basis || 0) + (sc.middelbaar || 0)) / eduNeed) * 100) + "%");
  const zorgNeed = Math.max(1, G.pop * 0.1);
  chip("#chip-health", Math.min(1, (G.stats.zorgCap || 0) / zorgNeed), Math.round(Math.min(1, (G.stats.zorgCap || 0) / zorgNeed) * 100) + "%");
  let pol = 0; for (let i = 0; i < N; i += 16) pol += G.pollution[i];
  const polIdx = Math.min(1, pol / (N / 16) / 3);
  chip("#chip-env", 1 - polIdx, Math.round((1 - polIdx) * 100) + "%");
  const e = G.stats.energie || { vraag: 0, aanbod: 0 };
  chip("#chip-power", e.vraag > 0 ? Math.min(1, e.aanbod / e.vraag) : 1, `${fmtNum(e.aanbod)}/${fmtNum(e.vraag)}`);
  const w = G.stats.water || { vraag: 0, aanbod: 0 };
  chip("#chip-water", w.vraag > 0 ? Math.min(1, w.aanbod / w.vraag) : 1, `${fmtNum(w.aanbod)}/${fmtNum(w.vraag)}`);
  const f = G.stats.voedsel || { ratio: 1 };
  chip("#chip-food", Math.min(1, f.ratio), Math.round(Math.min(1.2, f.ratio) * 100) + "%");
};

UI.setNews = function (msg) { $("#news").textContent = msg; };

UI.toast = function (msg, kind = "") {
  const t = el("div", "toast " + kind, msg);
  $("#toasts").append(t);
  setTimeout(() => t.remove(), 5200);
};

// ── Tooltip ─────────────────────────────────────────────────
UI.updateTooltip = function (px, py) {
  const tip = $("#tooltip");
  if (hoverTile < 0 || Input.dragging || UI.tool.kind !== "select") { tip.style.display = "none"; return; }
  const i = hoverTile;
  let html = "";
  if (G.bld[i] > 0) {
    const b = G.buildings[G.bld[i] - 1];
    if (b) {
      const def = BUILDINGS[b.type];
      html = `<b>${b.naam}</b><br>${def.naam} · ${b.floors.length} verd.`;
      if (b.capBew) html += `<br>${b.bezet}/${b.capBew} bewoners · ${Math.round(b.happy)}% tevreden`;
      if (b.capBanen) html += `<br>${b.werkers}/${b.capBanen} banen`;
      if (!b.powered) html += `<br><span style="color:var(--bad)">${icon("zap")} geen stroom</span>`;
      if (!b.watered) html += `<br><span style="color:var(--bad)">${icon("droplet")} geen water</span>`;
      if (!b.roadOk) html += `<br><span style="color:var(--bad)">${icon("route")} geen weg</span>`;
    }
  } else if (G.road[i] > 0) {
    const rd = ROADS[G.road[i]];
    const cong = G.traffic[i] / (rd.cap * roadCapFactor());
    html = `<b>${rd.naam}</b><br>${Math.round(G.traffic[i])} voertuigen/dag · drukte ${Math.round(cong * 100)}%`;
  } else {
    const td = TERRAIN_DEF[G.terrain[i]];
    html = `<b>${td.naam}</b><br>Grondwaarde: ${Math.round(G.landValue[i] * 100)} · Vruchtbaarheid: ${Math.round(G.fert[i] * 100)}%`;
    if (G.pollution[i] > 0.5) html += `<br>Vervuiling: ${G.pollution[i].toFixed(1)}`;
  }
  if (!html) { tip.style.display = "none"; return; }
  tip.innerHTML = html;
  tip.style.display = "block";
  const wrap = canvas.parentElement.getBoundingClientRect();
  tip.style.left = Math.min(px + 14, wrap.width - 250) + "px";
  tip.style.top = Math.min(py + 14, wrap.height - 90) + "px";
};

// ── Modal (save-scherm / nieuw spel) ────────────────────────
UI.showModal = function (title, contentFn) {
  $("#modal-title").textContent = title;
  const body = $("#modal-body");
  body.innerHTML = "";
  contentFn(body);
  $("#modal").classList.add("open");
};
UI.hideModal = function () { $("#modal").classList.remove("open"); };
$("#modal-close").onclick = () => UI.hideModal();
$("#modal").addEventListener("mousedown", e => { if (e.target.id === "modal") UI.hideModal(); });

UI.showSaveScreen = function () {
  UI.showModal("Opslaan & laden", body => {
    body.append(el("div", "muted", "Drie handmatige slots + de autosave (elke 2 minuten). Laden vervangt je huidige stad."));
    body.append(el("div", "", "&nbsp;"));
    for (const slot of SAVE_SLOTS) {
      const meta = saveMeta(slot);
      const c = el("div", "card");
      c.append(el("div", "", slot === "auto" ? `${icon("clock")} <b>Autosave</b>` : `${icon("folder")} <b>Slot ${slot}</b>`));
      if (meta) {
        const mode = meta.mode === "sandbox" ? "Sandbox" : "Klassiek";
        const geld = meta.mode === "sandbox" ? "∞" : fmtGeld(meta.money);
        c.append(el("div", "muted", `${mode} · ${fmtNum(meta.pop)} inwoners · jaar ${meta.year} · ${geld}`));
        c.append(el("div", "muted", "Opgeslagen: " + new Date(meta.ts).toLocaleString("nl-NL")));
      } else {
        c.append(el("div", "muted", "Leeg"));
      }
      const row = el("div", "row");
      if (slot !== "auto") {
        const sv = el("button", "", icon("save") + " Opslaan");
        sv.onclick = () => { if (saveGame(slot, false)) UI.showSaveScreen(); };
        row.append(sv);
      }
      const ld = el("button", "", icon("folder") + " Laden");
      ld.disabled = !meta;
      ld.onclick = () => { if (loadGame(slot)) { Cars.pool.length = 0; UI.selected = null; UI.hideModal(); } };
      row.append(ld);
      const del = el("button", "", icon("trash"));
      del.title = "Save verwijderen";
      del.disabled = !meta;
      del.onclick = () => { if (confirm("Deze save verwijderen?")) { deleteSave(slot); UI.showSaveScreen(); } };
      row.append(del);
      c.append(row);
      body.append(c);
    }
  });
};

UI.showNewGameScreen = function () {
  UI.showModal("Nieuwe kaart", body => {
    body.append(el("div", "muted", "Niet-opgeslagen voortgang gaat verloren — sla eerst op als je verder wilt spelen."));
    body.append(el("div", "", "&nbsp;"));
    const klassiek = el("button", "modebtn",
      `<b>${icon("building")} Klassiek</b><span class="muted">Begin als dorp op een gegenereerde kaart met rivieren, bossen en bergen. Beheer geld, groei door fasen en onderzoek technologie.</span>`);
    klassiek.onclick = () => { startNewGame("classic"); UI.hideModal(); };
    body.append(klassiek);
    const sandboxBtn = el("button", "modebtn",
      `<b>${icon("square")} Sandbox</b><span class="muted">Een leeg wit canvas. Onbeperkt geld, alles direct ontgrendeld, geen fasen of onderzoekseisen — bouw alles vanaf nul zoals jij wilt.</span>`);
    sandboxBtn.onclick = () => { startNewGame("sandbox"); UI.hideModal(); };
    body.append(sandboxBtn);
  });
};

// startscherm: altijd zichtbaar bij het openen van de plugin
UI.showStartScreen = function () {
  UI.showModal("MetroPlan", body => {
    body.append(el("div", "muted", "Welkom, stadsplanner! Kies hoe je wilt beginnen."));
    body.append(el("div", "", "&nbsp;"));
    const hasSave = SAVE_SLOTS.some(s => saveMeta(s));
    const laden = el("button", "modebtn",
      `<b>${icon("folder")} Save laden</b><span class="muted">${hasSave
        ? "Ga verder met een opgeslagen stad uit een van je slots of de autosave."
        : "Nog geen opgeslagen steden gevonden."}</span>`);
    laden.disabled = !hasSave;
    laden.onclick = () => UI.showSaveScreen();
    body.append(laden);
    const klassiek = el("button", "modebtn",
      `<b>${icon("building")} Nieuwe stad</b><span class="muted">Begin als dorp op een gegenereerde kaart met rivieren, bossen en bergen. Beheer geld, groei door fasen en onderzoek technologie.</span>`);
    klassiek.onclick = () => { startNewGame("classic"); UI.hideModal(); };
    body.append(klassiek);
    const sandboxBtn = el("button", "modebtn",
      `<b>${icon("square")} Sandbox-stad</b><span class="muted">Een leeg wit canvas. Onbeperkt geld, alles direct ontgrendeld, geen fasen of onderzoekseisen — bouw zoals jij wilt.</span>`);
    sandboxBtn.onclick = () => { startNewGame("sandbox"); UI.hideModal(); };
    body.append(sandboxBtn);
  });
};

// heatmap-dropdown
const hmsel = $("#heatmapsel");
for (const hm of HEATMAPS) {
  const o = el("option", "", hm.naam); o.value = hm.id;
  hmsel.append(o);
}
hmsel.onchange = () => { heatmapMode = hmsel.value; };
