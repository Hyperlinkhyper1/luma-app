// ─────────────────────────────────────────────────────────────
// MetroPlan — statische gamedata (gebouwen, techs, beleid, terrein)
// ─────────────────────────────────────────────────────────────
"use strict";

const TILE = 1; // logische tegelgrootte (px komt uit camera-zoom)
const WORLD_W = 384, WORLD_H = 384;
const CHUNK = 32; // tegels per render-chunk

// Terreintypes (index in terrain-array)
const TERRAIN = {
  GRAS: 0, BOS: 1, HEUVEL: 2, BERG: 3, RIVIER: 4, MEER: 5, KUST: 6, ZAND: 7, LANDBOUW: 8,
};
const TERRAIN_DEF = [
  { naam: "Gras",         kleur: "#3d6b35", bouwbaar: true,  vrucht: 0.6 },
  { naam: "Bos",          kleur: "#2c5228", bouwbaar: false, vrucht: 0.8 },
  { naam: "Heuvels",      kleur: "#5d6b42", bouwbaar: true,  vrucht: 0.4 },
  { naam: "Bergen",       kleur: "#7a7f85", bouwbaar: false, vrucht: 0.0 },
  { naam: "Rivier",       kleur: "#2b6cb0", bouwbaar: false, vrucht: 0.0 },
  { naam: "Meer",         kleur: "#245a94", bouwbaar: false, vrucht: 0.0 },
  { naam: "Kustwater",    kleur: "#1d4f86", bouwbaar: false, vrucht: 0.0 },
  { naam: "Zand",         kleur: "#c2a875", bouwbaar: true,  vrucht: 0.1 },
  { naam: "Landbouwgrond",kleur: "#7a8a3a", bouwbaar: true,  vrucht: 1.0 },
];
const isWater = t => t === TERRAIN.RIVIER || t === TERRAIN.MEER || t === TERRAIN.KUST;

// Wegtypes (index 1..n in road-array; 0 = geen weg)
// w = visuele breedte in tegels (spline-strokes), berm = stoep/berm-rand
const ROADS = [
  null,
  { id: 1, naam: "Kleine straat", kosten: 8,   onderhoud: 0.04, cap: 60,   snelheid: 30,  kleur: "#3f434b", fase: 1, w: 0.62, berm: "#9aa1ac", streep: false },
  { id: 2, naam: "Normale weg",   kosten: 18,  onderhoud: 0.08, cap: 160,  snelheid: 50,  kleur: "#43474f", fase: 1, w: 0.85, berm: "#a4abb6", streep: true },
  { id: 3, naam: "Hoofdweg",      kosten: 45,  onderhoud: 0.18, cap: 400,  snelheid: 70,  kleur: "#484d56", fase: 2, w: 1.25, berm: "#adb4bf", streep: true },
  { id: 4, naam: "Snelweg",       kosten: 120, onderhoud: 0.45, cap: 1200, snelheid: 110, kleur: "#4e535d", fase: 3, w: 1.7,  berm: "#b6bdc8", streep: true, tech: "snelwegen" },
];

// Verdiepingsfuncties. Waarden zijn per cel per verdieping.
// bew = bewoners, banen, energie/water = verbruik, waarde = gebouwwaarde-bijdrage
const FLOOR_USES = {
  leeg:        { naam: "Leeg",             bew: 0,   banen: 0,   energie: 0,   water: 0,   waarde: 0,   inkomen: 0 },
  wonen:       { naam: "Wonen",            bew: 2,   banen: 0,   energie: 0.6, water: 0.5, waarde: 14,  inkomen: 0 },
  luxe_wonen:  { naam: "Luxe wonen",       bew: 1,   banen: 0,   energie: 1.0, water: 0.8, waarde: 40,  inkomen: 0 },
  studenten:   { naam: "Studentenwoningen",bew: 3,   banen: 0,   energie: 0.5, water: 0.5, waarde: 8,   inkomen: 0 },
  winkel:      { naam: "Winkel",           bew: 0,   banen: 1.2, energie: 0.8, water: 0.3, waarde: 18,  inkomen: 1.4 },
  restaurant:  { naam: "Restaurant",       bew: 0,   banen: 1.5, energie: 1.0, water: 0.7, waarde: 20,  inkomen: 1.2 },
  kantoor:     { naam: "Kantoor",          bew: 0,   banen: 3.0, energie: 1.2, water: 0.3, waarde: 26,  inkomen: 1.8 },
  industrie:   { naam: "Industrie",        bew: 0,   banen: 2.0, energie: 2.2, water: 0.8, waarde: 12,  inkomen: 1.5 },
  opslag:      { naam: "Opslag",           bew: 0,   banen: 0.3, energie: 0.3, water: 0.1, waarde: 6,   inkomen: 0.3 },
  publiek:     { naam: "Publieke functie", bew: 0,   banen: 1.0, energie: 0.8, water: 0.4, waarde: 10,  inkomen: 0 },
};

// Gebouwtypes. kosten/onderhoud per cel per verdieping. fase = ontgrendel-fase.
// cat: wonen | commercieel | industrie | voedsel | publiek | energie | water | transport
const BUILDINGS = {
  // ── Wonen ──
  huis:          { naam: "Huis",             cat: "wonen", kleur: "#8fbf6a", kosten: 30,  onderhoud: 0,   fase: 1, verd: 1, maxVerd: 2,  use: "wonen" },
  appartement:   { naam: "Appartement",      cat: "wonen", kleur: "#6fae5c", kosten: 45,  onderhoud: 0,   fase: 2, verd: 4, maxVerd: 6,  use: "wonen" },
  flat:          { naam: "Flat",             cat: "wonen", kleur: "#579a52", kosten: 60,  onderhoud: 0,   fase: 3, verd: 8, maxVerd: 14, use: "wonen" },
  wolkenkrabber: { naam: "Woontoren",        cat: "wonen", kleur: "#3f8a54", kosten: 95,  onderhoud: 0,   fase: 4, verd: 20, maxVerd: 40, use: "wonen", tech: "wolkenkrabbers" },
  luxe_woning:   { naam: "Luxe woning",      cat: "wonen", kleur: "#b7d98a", kosten: 90,  onderhoud: 0,   fase: 2, verd: 2, maxVerd: 3,  use: "luxe_wonen" },
  studentenhuis: { naam: "Studentenwoning",  cat: "wonen", kleur: "#9ccf8f", kosten: 35,  onderhoud: 0,   fase: 3, verd: 4, maxVerd: 8,  use: "studenten" },
  // ── Commercieel ──
  winkel:        { naam: "Winkel",           cat: "commercieel", kleur: "#5b8fd9", kosten: 40,  onderhoud: 0, fase: 1, verd: 1, maxVerd: 3,  use: "winkel" },
  supermarkt:    { naam: "Supermarkt",       cat: "commercieel", kleur: "#4d7fc9", kosten: 55,  onderhoud: 0, fase: 2, verd: 1, maxVerd: 2,  use: "winkel", voedselWinkel: true },
  restaurant:    { naam: "Restaurant",       cat: "commercieel", kleur: "#7aa6e6", kosten: 50,  onderhoud: 0, fase: 2, verd: 1, maxVerd: 3,  use: "restaurant" },
  kantoor:       { naam: "Kantoor",          cat: "commercieel", kleur: "#3f74c4", kosten: 70,  onderhoud: 0, fase: 3, verd: 5, maxVerd: 25, use: "kantoor" },
  winkelcentrum: { naam: "Winkelcentrum",    cat: "commercieel", kleur: "#2f66b8", kosten: 85,  onderhoud: 0, fase: 3, verd: 2, maxVerd: 4,  use: "winkel", toerisme: 2 },
  // ── Industrie ──
  fabriek:       { naam: "Fabriek",          cat: "industrie", kleur: "#c9a13d", kosten: 55, onderhoud: 0, fase: 2, verd: 1, maxVerd: 3, use: "industrie", vervuiling: 3.0, materiaal: 1.2 },
  magazijn:      { naam: "Magazijn",         cat: "industrie", kleur: "#b0913f", kosten: 30, onderhoud: 0, fase: 2, verd: 1, maxVerd: 2, use: "opslag" },
  techbedrijf:   { naam: "Technologiebedrijf",cat: "industrie", kleur: "#d9b64f", kosten: 110, onderhoud: 0, fase: 4, verd: 3, maxVerd: 10, use: "kantoor", vervuiling: 0.3, onderzoek: 0.5 },
  // ── Voedsel & landbouw ──
  akker:         { naam: "Akker",            cat: "voedsel", kleur: "#96a83c", kosten: 6,  onderhoud: 0.02, fase: 1, verd: 1, maxVerd: 1, use: "leeg", voedsel: 1.0, banenVast: 0.1 },
  boerderij:     { naam: "Boerderij",        cat: "voedsel", kleur: "#a8843c", kosten: 25, onderhoud: 0.05, fase: 1, verd: 1, maxVerd: 2, use: "industrie", voedsel: 0.8, vervuiling: 0.4 },
  kas:           { naam: "Kas",              cat: "voedsel", kleur: "#8fc9b0", kosten: 45, onderhoud: 0.1,  fase: 2, verd: 1, maxVerd: 1, use: "leeg", voedsel: 2.2, energieVast: 1.5, banenVast: 0.3 },
  vertical_farm: { naam: "Vertical farm",    cat: "voedsel", kleur: "#5fc99a", kosten: 130, onderhoud: 0.3, fase: 4, verd: 6, maxVerd: 12, use: "leeg", voedsel: 3.5, energieVast: 2.5, banenVast: 0.4, tech: "vertical_farming" },
  voedselfabriek:{ naam: "Voedselfabriek",   cat: "voedsel", kleur: "#c9973d", kosten: 60, onderhoud: 0.1, fase: 2, verd: 1, maxVerd: 3, use: "industrie", voedselVerwerk: 3, vervuiling: 1.2 },
  // ── Publiek ──
  basisschool:   { naam: "Basisschool",      cat: "publiek", kleur: "#d97ba6", kosten: 60,  onderhoud: 0.5, fase: 1, verd: 1, maxVerd: 2, use: "publiek", school: "basis", schoolCap: 12, bereik: 22 },
  middelbare:    { naam: "Middelbare school",cat: "publiek", kleur: "#c9639a", kosten: 90,  onderhoud: 0.8, fase: 2, verd: 2, maxVerd: 4, use: "publiek", school: "middelbaar", schoolCap: 10, bereik: 30 },
  universiteit:  { naam: "Universiteit",     cat: "publiek", kleur: "#b04a8c", kosten: 160, onderhoud: 1.6, fase: 3, verd: 3, maxVerd: 8, use: "publiek", school: "universiteit", schoolCap: 8, bereik: 60, onderzoek: 1.0 },
  huisarts:      { naam: "Huisartsenpost",   cat: "publiek", kleur: "#e88b8b", kosten: 50,  onderhoud: 0.4, fase: 1, verd: 1, maxVerd: 2, use: "publiek", zorgCap: 8,  bereik: 20 },
  ziekenhuis:    { naam: "Ziekenhuis",       cat: "publiek", kleur: "#d96a6a", kosten: 150, onderhoud: 1.4, fase: 3, verd: 4, maxVerd: 10, use: "publiek", zorgCap: 20, bereik: 45 },
  politie:       { naam: "Politiebureau",    cat: "publiek", kleur: "#5a6fd9", kosten: 80,  onderhoud: 0.7, fase: 2, verd: 2, maxVerd: 4, use: "publiek", veiligheid: 1, bereik: 30 },
  brandweer:     { naam: "Brandweerkazerne", cat: "publiek", kleur: "#d9744a", kosten: 80,  onderhoud: 0.7, fase: 2, verd: 1, maxVerd: 3, use: "publiek", brandweer: 1, bereik: 28 },
  gemeentehuis:  { naam: "Gemeentehuis",     cat: "publiek", kleur: "#a08ad9", kosten: 120, onderhoud: 0.9, fase: 2, verd: 2, maxVerd: 5, use: "publiek", bestuur: 1, bereik: 999 },
  park:          { naam: "Park",             cat: "publiek", kleur: "#4f9c46", kosten: 10,  onderhoud: 0.06, fase: 1, verd: 1, maxVerd: 1, use: "leeg", groen: 1, bereik: 10, toerisme: 0.5 },
  // ── Energie ──
  kolencentrale: { naam: "Kolencentrale",    cat: "energie", kleur: "#7d7466", kosten: 90,  onderhoud: 1.2, fase: 2, verd: 2, maxVerd: 3, use: "industrie", energieProd: 60,  vervuiling: 6.0 },
  gascentrale:   { naam: "Gascentrale",      cat: "energie", kleur: "#8d8472", kosten: 110, onderhoud: 1.3, fase: 3, verd: 2, maxVerd: 3, use: "industrie", energieProd: 55,  vervuiling: 3.0, tech: "gas" },
  windmolen:     { naam: "Windmolen",        cat: "energie", kleur: "#c8d4de", kosten: 70,  onderhoud: 0.35, fase: 2, verd: 1, maxVerd: 1, use: "leeg", energieProd: 10, hernieuwbaar: true, tech: "wind" },
  zonnepark:     { naam: "Zonnepark",        cat: "energie", kleur: "#3b4c6b", kosten: 40,  onderhoud: 0.15, fase: 2, verd: 1, maxVerd: 1, use: "leeg", energieProd: 5, hernieuwbaar: true, tech: "zon" },
  waterkracht:   { naam: "Waterkrachtcentrale",cat:"energie", kleur: "#6b93b8", kosten: 150, onderhoud: 0.8, fase: 3, verd: 1, maxVerd: 2, use: "industrie", energieProd: 45, hernieuwbaar: true, waterNodig: true, tech: "waterkracht" },
  kerncentrale:  { naam: "Kerncentrale",     cat: "energie", kleur: "#e0e6c8", kosten: 400, onderhoud: 4.5, fase: 4, verd: 2, maxVerd: 3, use: "industrie", energieProd: 300, vervuiling: 0.3, tech: "kernenergie" },
  fusiereactor:  { naam: "Fusiereactor",     cat: "energie", kleur: "#9adaf0", kosten: 900, onderhoud: 6.0, fase: 5, verd: 3, maxVerd: 4, use: "industrie", energieProd: 800, tech: "fusie" },
  batterij:      { naam: "Batterijopslag",   cat: "energie", kleur: "#4f6d5a", kosten: 60,  onderhoud: 0.25, fase: 3, verd: 1, maxVerd: 2, use: "leeg", opslag: 40, tech: "opslag" },
  // ── Water & afval ──
  waterpomp:     { naam: "Waterpomp",        cat: "water", kleur: "#5aa6d9", kosten: 35,  onderhoud: 0.25, fase: 1, verd: 1, maxVerd: 1, use: "leeg", waterProd: 30, waterNodig: true },
  waterzuivering:{ naam: "Waterzuivering",   cat: "water", kleur: "#4a96c9", kosten: 90,  onderhoud: 0.7,  fase: 2, verd: 1, maxVerd: 2, use: "industrie", waterProd: 70, waterNodig: true, tech: "zuivering" },
  rioolzuivering:{ naam: "Rioolwaterzuivering",cat:"water", kleur: "#6a8696", kosten: 80,  onderhoud: 0.6,  fase: 2, verd: 1, maxVerd: 2, use: "industrie", rioolCap: 80, tech: "riool" },
  vuilstort:     { naam: "Vuilstortplaats",  cat: "water", kleur: "#6e6250", kosten: 20,  onderhoud: 0.2,  fase: 1, verd: 1, maxVerd: 1, use: "leeg", afvalCap: 30, vervuiling: 2.0 },
  recycling:     { naam: "Recyclingcentrum", cat: "water", kleur: "#5c8a5c", kosten: 90,  onderhoud: 0.8,  fase: 3, verd: 1, maxVerd: 2, use: "industrie", afvalCap: 60, vervuiling: 0.4, tech: "recycling" },
  afvalcentrale: { naam: "Afvalenergiecentrale",cat:"water", kleur: "#8a7a5c", kosten: 130, onderhoud: 1.1, fase: 3, verd: 2, maxVerd: 3, use: "industrie", afvalCap: 90, energieProd: 20, vervuiling: 1.5, tech: "afvalenergie" },
  // ── Transport & parkeren ──
  parkeerterrein:{ naam: "Parkeerterrein",   cat: "transport", kleur: "#5c636e", kosten: 12,  onderhoud: 0.05, fase: 1, verd: 1, maxVerd: 1, use: "leeg", parkeren: 4 },
  parkeergarage: { naam: "Parkeergarage",    cat: "transport", kleur: "#495261", kosten: 55,  onderhoud: 0.3,  fase: 3, verd: 4, maxVerd: 8, use: "leeg", parkeren: 8, tech: "parkeergarages" },
  busdepot:      { naam: "Busdepot",         cat: "transport", kleur: "#c4763d", kosten: 70,  onderhoud: 0.6,  fase: 2, verd: 1, maxVerd: 2, use: "publiek", ovDepot: "bus" },
  tramdepot:     { naam: "Tramremise",       cat: "transport", kleur: "#b8633d", kosten: 110, onderhoud: 0.9,  fase: 3, verd: 1, maxVerd: 2, use: "publiek", ovDepot: "tram", tech: "tram" },
  metrostation:  { naam: "Metrodepot",       cat: "transport", kleur: "#a6503d", kosten: 200, onderhoud: 1.6,  fase: 4, verd: 1, maxVerd: 3, use: "publiek", ovDepot: "metro", tech: "metro" },
  treinstation:  { naam: "Treinstation",     cat: "transport", kleur: "#93413d", kosten: 260, onderhoud: 2.0,  fase: 4, verd: 2, maxVerd: 4, use: "publiek", ovDepot: "trein", toerisme: 3, tech: "trein" },
  luchthaven:    { naam: "Luchthaven",       cat: "transport", kleur: "#8f9cb3", kosten: 500, onderhoud: 5.0,  fase: 4, verd: 1, maxVerd: 2, use: "publiek", toerisme: 12, vervuiling: 2.5, tech: "luchthaven" },
  haven:         { naam: "Haven",            cat: "transport", kleur: "#5f7f9c", kosten: 350, onderhoud: 3.0,  fase: 4, verd: 1, maxVerd: 2, use: "industrie", waterNodig: true, toerisme: 4, materiaal: 2, tech: "haven" },
};

// OV-types
const TRANSIT_TYPES = {
  bus:   { naam: "Buslijn",   kleur: "#e8a13d", capPerRit: 40,  kostenHalte: 15,  opPerHalte: 0.15, fase: 2, snelheid: 25, bereik: 6 },
  tram:  { naam: "Tramlijn",  kleur: "#d97b3d", capPerRit: 120, kostenHalte: 60,  opPerHalte: 0.35, fase: 3, snelheid: 32, bereik: 7, tech: "tram" },
  metro: { naam: "Metrolijn", kleur: "#d9503d", capPerRit: 400, kostenHalte: 180, opPerHalte: 0.9,  fase: 4, snelheid: 55, bereik: 9, tech: "metro" },
  trein: { naam: "Treinlijn", kleur: "#a63dd9", capPerRit: 800, kostenHalte: 320, opPerHalte: 1.4,  fase: 4, snelheid: 90, bereik: 12, tech: "trein" },
};

// Fasen. popEis + techEis om door te groeien (via onderzoekspaneel).
const PHASES = [
  null,
  { naam: "Dorp",        popEis: 0 },
  { naam: "Gemeente",    popEis: 400,   rp: 30 },
  { naam: "Stad",        popEis: 2500,  rp: 120 },
  { naam: "Metropool",   popEis: 12000, rp: 400 },
  { naam: "Toekomststad",popEis: 40000, rp: 1200 },
];

// Technologieboom. cat: transport | bouw | energie | milieu | sociaal
// kosten in onderzoekspunten (RP). req = andere tech-ids. fase = minimale stadsfase.
const TECHS = [
  { id: "verkeerslichten", naam: "Verkeerslichten",  cat: "transport", kosten: 25,  fase: 2, desc: "+15% wegcapaciteit op kruispunten." },
  { id: "rotondes",     naam: "Rotondes",            cat: "transport", kosten: 40,  fase: 2, req: ["verkeerslichten"], desc: "+10% doorstroming op alle wegen." },
  { id: "tram",         naam: "Tramnetwerk",         cat: "transport", kosten: 60,  fase: 3, desc: "Ontgrendelt trams en tramremises." },
  { id: "snelwegen",    naam: "Snelwegen",           cat: "transport", kosten: 80,  fase: 3, desc: "Ontgrendelt snelwegen." },
  { id: "parkeergarages",naam:"Parkeergarages",      cat: "transport", kosten: 45,  fase: 3, desc: "Ontgrendelt meerlaags parkeren." },
  { id: "metro",        naam: "Metro",               cat: "transport", kosten: 150, fase: 4, req: ["tram"], desc: "Ontgrendelt metrolijnen." },
  { id: "trein",        naam: "Spoorwegen",          cat: "transport", kosten: 130, fase: 4, desc: "Ontgrendelt treinen en stations." },
  { id: "luchthaven",   naam: "Luchtvaart",          cat: "transport", kosten: 200, fase: 4, desc: "Ontgrendelt de luchthaven (toerisme)." },
  { id: "haven",        naam: "Havenlogistiek",      cat: "transport", kosten: 160, fase: 4, desc: "Ontgrendelt de haven (materialen + toerisme)." },
  { id: "ai_verkeer",   naam: "AI-verkeersbeheer",   cat: "transport", kosten: 350, fase: 5, req: ["metro"], desc: "+30% wegcapaciteit, −20% files." },
  { id: "autonoom",     naam: "Autonome voertuigen", cat: "transport", kosten: 450, fase: 5, req: ["ai_verkeer"], desc: "−25% parkeerbehoefte, snellere reistijden." },

  { id: "beton",        naam: "Modern beton",        cat: "bouw", kosten: 30,  fase: 2, desc: "−10% bouwkosten." },
  { id: "prefab",       naam: "Prefab-bouw",         cat: "bouw", kosten: 70,  fase: 3, req: ["beton"], desc: "−15% bouwkosten." },
  { id: "wolkenkrabbers",naam:"Wolkenkrabbers",      cat: "bouw", kosten: 180, fase: 4, req: ["prefab"], desc: "Ontgrendelt woontorens tot 40 verdiepingen." },
  { id: "slimme_gebouwen",naam:"Slimme gebouwen",    cat: "bouw", kosten: 300, fase: 5, desc: "−20% energie- en waterverbruik van gebouwen." },

  { id: "wind",         naam: "Windenergie",         cat: "energie", kosten: 35,  fase: 2, desc: "Ontgrendelt windmolens." },
  { id: "zon",          naam: "Zonne-energie",       cat: "energie", kosten: 35,  fase: 2, desc: "Ontgrendelt zonneparken." },
  { id: "gas",          naam: "Gascentrales",        cat: "energie", kosten: 50,  fase: 3, desc: "Ontgrendelt gascentrales (schoner dan kolen)." },
  { id: "waterkracht",  naam: "Waterkracht",         cat: "energie", kosten: 60,  fase: 3, desc: "Ontgrendelt waterkrachtcentrales (aan water)." },
  { id: "opslag",       naam: "Energieopslag",       cat: "energie", kosten: 55,  fase: 3, req: ["wind", "zon"], desc: "Ontgrendelt batterijen: dempt schommelingen van wind/zon." },
  { id: "kernenergie",  naam: "Kernenergie",         cat: "energie", kosten: 220, fase: 4, desc: "Ontgrendelt kerncentrales." },
  { id: "fusie",        naam: "Fusie-energie",       cat: "energie", kosten: 600, fase: 5, req: ["kernenergie"], desc: "Ontgrendelt de fusiereactor." },

  { id: "zuivering",    naam: "Waterzuivering",      cat: "milieu", kosten: 40,  fase: 2, desc: "Ontgrendelt grote drinkwaterzuivering." },
  { id: "riool",        naam: "Modern riool",        cat: "milieu", kosten: 40,  fase: 2, desc: "Ontgrendelt rioolwaterzuivering (minder vervuiling)." },
  { id: "recycling",    naam: "Recycling",           cat: "milieu", kosten: 60,  fase: 3, desc: "Ontgrendelt het recyclingcentrum." },
  { id: "afvalenergie", naam: "Afvalenergie",        cat: "milieu", kosten: 90,  fase: 3, req: ["recycling"], desc: "Ontgrendelt de afvalenergiecentrale." },
  { id: "groene_daken", naam: "Groene daken",        cat: "milieu", kosten: 80,  fase: 3, desc: "−15% vervuiling in woongebieden." },
  { id: "natuurbeheer", naam: "Natuurbeheer",        cat: "milieu", kosten: 100, fase: 3, desc: "Parken en bos werken 50% sterker." },

  { id: "vertical_farming", naam: "Vertical farming",cat: "sociaal", kosten: 160, fase: 4, desc: "Ontgrendelt vertical farms in de stad." },
  { id: "beter_onderwijs",  naam: "Beter onderwijs", cat: "sociaal", kosten: 70,  fase: 3, desc: "+25% schoolcapaciteit en kwaliteit." },
  { id: "moderne_zorg",     naam: "Moderne zorg",    cat: "sociaal", kosten: 90,  fase: 3, desc: "+25% zorgcapaciteit, gezondere inwoners." },
  { id: "sociale_woningen", naam: "Sociale woningbouw",cat:"sociaal",kosten: 60,  fase: 2, desc: "Goedkoper wonen: +tevredenheid lage inkomens." },
];

// Beleid. kostenPerMaand kan negatief zijn (levert op). effects → sim-modifiers.
const POLICIES = [
  { id: "zon_subsidie",   naam: "Subsidie zonnepanelen",  cat: "Energie",   kosten: 2.5, desc: "Gebouwen wekken zelf wat stroom op (−8% netvraag).", fase: 2 },
  { id: "co2_belasting",  naam: "Belasting op vervuiling",cat: "Energie",   kosten: -3,  desc: "Extra inkomsten, −10% industrieproductie, −15% vervuiling.", fase: 3 },
  { id: "kern_verbod",    naam: "Kernenergie verbieden",  cat: "Energie",   kosten: 0,   desc: "Kerncentrales worden uitgeschakeld. Sommige inwoners blij, anderen niet.", fase: 4 },
  { id: "lokaal_voedsel", naam: "Lokale landbouw stimuleren",cat:"Voedsel", kosten: 2,   desc: "+25% opbrengst van akkers, kassen en boerderijen.", fase: 1 },
  { id: "goedkope_import",naam: "Goedkope voedselimport", cat: "Voedsel",   kosten: 1.5, desc: "Voedseltekorten worden goedkoper opgevangen (−40% importkosten).", fase: 2 },
  { id: "benzine_taks",   naam: "Benzinebelasting",       cat: "Transport", kosten: -2.5,desc: "Inkomsten, −10% autoverkeer, −kleine tevredenheid.", fase: 2 },
  { id: "ev_stimulans",   naam: "Elektrisch rijden stimuleren",cat:"Transport",kosten: 3, desc: "−30% verkeersvervuiling, +energievraag.", fase: 3 },
  { id: "ov_subsidie",    naam: "OV-subsidie",            cat: "Transport", kosten: 3,   desc: "Gratis(er) OV: +40% OV-gebruik, minder files.", fase: 2 },
  { id: "groen_verplicht",naam: "Groene gebouwen verplicht",cat:"Bouw",     kosten: 0,   desc: "+15% bouwkosten, −20% energieverbruik nieuwe gebouwen.", fase: 3 },
  { id: "sociale_bouw",   naam: "Goedkope woningbouw",    cat: "Bouw",      kosten: 2,   desc: "+tevredenheid en snellere migratie bij woningtekort.", fase: 2 },
];

// Heatmap-modi
const HEATMAPS = [
  { id: "geen",       naam: "Kaartweergave: normaal" },
  { id: "verkeer",    naam: "Heatmap: verkeersdrukte" },
  { id: "geluid",     naam: "Heatmap: geluid" },
  { id: "lucht",      naam: "Heatmap: luchtkwaliteit" },
  { id: "geluk",      naam: "Heatmap: geluk" },
  { id: "waarde",     naam: "Heatmap: grondwaarde" },
  { id: "ov",         naam: "Heatmap: OV-bereikbaarheid" },
  { id: "onderwijs",  naam: "Heatmap: onderwijs" },
  { id: "gezondheid", naam: "Heatmap: gezondheid" },
  { id: "veiligheid", naam: "Heatmap: veiligheid" },
  { id: "groen",      naam: "Heatmap: groen" },
  { id: "energie",    naam: "Heatmap: energienet" },
  { id: "water",      naam: "Heatmap: waternet" },
];

// Terreingereedschap
const TERRAIN_TOOLS = [
  { id: "egaliseren", naam: "Egaliseren (→ gras)", kosten: 4,  desc: "Maakt bos/heuvel/zand bouwrijp." },
  { id: "water",      naam: "Water graven",        kosten: 12, desc: "Graaft een meer of kanaal." },
  { id: "bos",        naam: "Bos planten",         kosten: 3,  desc: "Plant bos: minder vervuiling, mooier wonen." },
  { id: "landbouw",   naam: "Landbouwgrond",       kosten: 2,  desc: "Vruchtbare grond voor akkers." },
];

// Namen voor automatisch gegenereerde gebouwnamen
const NAME_PARTS = {
  wonen: ["De Linde", "Zonnehof", "Parkzicht", "De Els", "Waterkant", "Hoogstede", "De Berk", "Middenhof", "Oosterlicht", "Nieuwland"],
  commercieel: ["Centrum", "De Passage", "Marktzicht", "Handelshuis", "De Galerij", "Stadsplein", "De Etalage"],
  industrie: ["Werkstad", "De Smederij", "Industria", "De Loods", "Machinepark"],
  overig: ["Noord", "Zuid", "Oost", "West", "Centraal", "Nieuw"],
};
