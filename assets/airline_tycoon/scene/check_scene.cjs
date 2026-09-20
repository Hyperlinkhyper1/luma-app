// Node-only structural smoke check; rendering still requires device verification.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const THREE = require('./vendor/three-0.160.1.min.js');
const elements = new Map();
const gradient = { addColorStop() {} };
const context2d = new Proxy({}, {
  get: (target, key) => key in target ? target[key] : key.startsWith('create') ? () => gradient : () => {},
  set: (target, key, value) => { target[key] = value; return true; },
});
function element() {
  return {
    style: {}, classList: { add() {}, toggle() {}, contains: () => false }, textContent: '', dataset: {}, children: [], childElementCount: 0,
    addEventListener() {}, prepend() {}, append() {}, remove() {}, replaceChildren() {}, querySelector: () => null,
    getBoundingClientRect() { return { left: 0, top: 0, width: 1200, height: 800 }; },
    getContext() { return context2d; },
    toDataURL() { return 'data:image/webp;base64,'; },
  };
}
const document = {
  createElement: element,
  getElementById(id) { if (!elements.has(id)) elements.set(id, element()); return elements.get(id); },
  body: { prepend() {} }, addEventListener() {}, hidden: false,
};
class Renderer {
  constructor() { this.domElement = element(); this.shadowMap = {}; }
  setPixelRatio() {} setSize() {} setClearColor() {} render() {} dispose() {}
}
const messages = [];
const webMessageListeners = [];
const sandbox = {
  THREE: { ...THREE, WebGLRenderer: Renderer }, document, console, performance,
  innerWidth: 1200, innerHeight: 800, devicePixelRatio: 1, URLSearchParams,
  requestAnimationFrame() {}, addEventListener() {}, location: { search: '?preview=1' },
  chrome: { webview: { postMessage(message) { messages.push(JSON.parse(message)); }, addEventListener(type, listener) { webMessageListeners.push(listener); } } },
};
const hud = { attached: null, updates: 0, selected: null, attach(api) { this.attached = api; }, update() { this.updates++; }, select(id) { this.selected = id; }, result() {}, theme() {}, place() {} };
sandbox.AirportHud = hud;
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const file of ['scene_logic.js', 'models.js', 'landside.js', 'preview.js', 'scene.js']) {
  vm.runInContext(fs.readFileSync(`${__dirname}/${file}`, 'utf8'), sandbox, { filename: file });
}
assert(messages.some(m => m.type === 'ready'));
assert.equal(typeof hud.attached?.send, 'function');
assert.equal(typeof hud.attached?.view, 'function');
assert.equal(typeof hud.attached?.tool, 'function');
assert(hud.updates > 0, 'preview snapshot reaches the controls');
assert.equal(webMessageListeners.length, 1);
const viaWebMessage = hud.updates;
webMessageListeners[0]({ data: JSON.stringify({ type: 'snapshot', world: sandbox.airportPreview.world }) });
assert.equal(hud.updates, viaWebMessage + 1, 'WebView2 web messages reach the scene');
assert(!messages.some(m => m.type === 'error'), JSON.stringify(messages));
for (const facility of sandbox.airportPreview.world.facilities) {
  const mesh = sandbox.AirportModels.facility(facility);
  const bounds = new THREE.Box3().setFromObject(mesh);
  assert(Number.isFinite(bounds.min.x) && Number.isFinite(bounds.max.z), facility.kind);
  sandbox.AirportModels.dispose(mesh);
}
for (const action of ['fit', 'reset', 'cutaway', 'grid', 'quality', 'focus', 'visible']) {
  sandbox.airportReceive({ type: 'view', action, id: 'terminal-1', value: true });
}
sandbox.airportReceive({ type: 'tool', kind: 'stand', rotation: 90 });
assert.match(elements.get('status').textContent, /place/i);
sandbox.airportReceive({ type: 'tool', kind: null });
assert.equal(elements.get('status').textContent, '');
{
  // The entrance and the check-out open the wall they lead out through, and
  // pavements that touch hand their edge lines over and join their centrelines.
  const built = sandbox.airportDebug.state.facilities;
  const doors = [...built.values()].flatMap(f => f.context?.doors || []);
  assert.deepEqual(JSON.parse(JSON.stringify(doors)), [{side: '-x', at: 30, label: 'GATE'}, {side: '+x', at: 30, label: 'ENTRANCE'}, {side: '+x', at: 38, label: 'EXIT'}], 'a gate door on the apron wall, the way in through the arrival hall and the way out through the departure hall');
  const trunk = built.get('b2');
  assert(trunk.context.cuts.length >= 2, 'the long taxiway gives way where the short ones join it');
  const standCuts = built.get('b6').context.cuts;
  assert(standCuts.length >= 1, 'the stand border opens onto its taxiway');
}
const before = hud.updates;
sandbox.airportReceive({ type: 'snapshot', world: { ...sandbox.airportPreview.world, facilities: [], flights: [], vehicles: [], passengers: [] } });
assert.equal(hud.updates, before + 1);
assert(!messages.some(m => m.type === 'error'), JSON.stringify(messages));
{
  // Airport mode: over the halls, roofs off and walls lowered on the halls
  // only, and everything back as it was afterwards.
  const state = () => sandbox.airportDebug.state;
  sandbox.airportReceive({ type: 'snapshot', world: sandbox.airportPreview.world });
  sandbox.airportReceive({ type: 'view', action: 'cutaway', value: false });
  const shown = (kind, flag) => [...state().facilities.values()].filter(f => kind(f.data.kind)).flatMap(f => { const out = []; f.mesh.traverse(o => { if (o.userData[flag]) out.push(o.visible); }); return out; });
  const hall = k => sandbox.AirportSceneLogic.hallKinds.has(k);
  assert(shown(hall, 'upper').length && shown(hall, 'upper').every(Boolean), 'halls have walls above the knee');
  sandbox.airportReceive({ type: 'view', action: 'airport', value: true });
  for (let i = 0; i < 60; i++) sandbox.airportDebug.frame();
  assert(state().airport && state().airportLimits, 'airport mode is on');
  const t = state().target, lim = state().airportLimits;
  assert(t.x >= lim.minX && t.x <= lim.maxX && t.z >= lim.minZ && t.z <= lim.maxZ, 'the camera is over the terminal');
  assert(shown(hall, 'roof').every(v => !v) && shown(hall, 'upper').every(v => !v), 'hall roofs off, walls lowered');
  assert(shown(k => k === 'hangar', 'roof').every(Boolean), 'other roofs stay on');
  sandbox.airportDebug.camera(4000, 4000, 6000, .8, .7);
  assert(state().target.x <= lim.maxX && state().distance <= lim.far, 'panning and zooming stay over the terminal');
  sandbox.airportReceive({ type: 'view', action: 'airport', value: false });
  for (let i = 0; i < 60; i++) sandbox.airportDebug.frame();
  assert(!state().airport && !state().airportLimits, 'airport mode is off');
  assert(shown(hall, 'roof').every(Boolean) && shown(hall, 'upper').every(Boolean), 'roofs and walls back');
  // The hall and apron lights reach the standard shader alongside the weathering.
  const shader = { uniforms: {}, vertexShader: THREE.ShaderLib.standard.vertexShader, fragmentShader: THREE.ShaderLib.standard.fragmentShader };
  sandbox.AirportModels.materials.tile.onBeforeCompile(shader, null);
  assert(shader.vertexShader.includes('vIndoor = ') && shader.fragmentShader.includes('indoorLight(vIndoor)'), 'the lights are patched in');
  assert(shader.fragmentShader.includes('macroNoise') && 'lightRects' in shader.uniforms, 'weathering and light uniforms both present');
  assert.notEqual(sandbox.AirportModels.materials.tile.customProgramCacheKey(), sandbox.AirportModels.materials.paint.customProgramCacheKey(), 'weathered and plain materials keep separate programs');
}
{
  // A door away from the road side gets its own porch and kerb.
  const world = sandbox.airportPreview.world;
  const side = world.facilities.map(f => f.kind === 'entrance' ? {...f, door: {door: [-110, -90, 0], kerb: [-110, -99, 0]}} : f);
  const errors = messages.length;
  sandbox.airportReceive({ type: 'snapshot', world: {...world, facilities: side} });
  assert.equal(messages.slice(errors).filter(m => m.type === 'error').length, 0, 'a side door draws its porch');
  sandbox.airportReceive({ type: 'snapshot', world });
}
{
  // Zoning: a painted piece of floor decides what may be placed on it,
  // whichever section of terminal it is in, and the scene marks it out.
  const base = sandbox.airportPreview.world;
  const state = () => sandbox.airportDebug.state;
  sandbox.airportReceive({type: 'snapshot', world: base});
  assert.equal(new Set(base.facilities.filter(f => sandbox.AirportSceneLogic.hallKinds.has(f.kind)).map(f => f.kind)).size, 1, 'the terminal is one kind of building');
  assert.equal(state().zoneGroup.children.length, base.zones.length * 5, 'every zone is drawn with its border');
  const zoned = {...base, zones: [...base.zones, {id: 'z9', zone: 'arrival', x: -250, y: -90, width: 50, depth: 60}]};
  sandbox.airportReceive({type: 'snapshot', world: zoned});
  assert(state().zoneGroup.children.length >= 5, 'a painted zone is drawn with its border');
  const zoneWorld = {catalog: [{kind: 'shop', width: 12, depth: 8, cost: 1, interior: true, name: 'Duty free'}, {kind: 'checkIn', width: 8, depth: 4, cost: 1, interior: true, name: 'Check-in desks'}], facilities: zoned.facilities, zones: zoned.zones, cash: 9e9, time: 0, flights: []};
  const tryAt = (kind, x, y, w, d) => sandbox.AirportSceneLogic.validate(zoneWorld, {kind}, {x, y, w, d});
  assert.match(tryAt('shop', -240, -70, 12, 8).reason, /main hall/, 'no shop on floor zoned as the arrival hall');
  assert(tryAt('checkIn', -240, -70, 8, 4).valid, 'check-in on floor zoned as the arrival hall');
  assert(tryAt('shop', -180, -70, 12, 8).valid, 'and shops on the unzoned main hall floor');
  assert.equal(sandbox.AirportSceneLogic.zoneAt(zoneWorld, -240, -70), "arrival");
  assert.equal(sandbox.AirportSceneLogic.zoneAt(zoneWorld, -180, -70), null);
  sandbox.airportReceive({type: 'snapshot', world: {...base, zones: []}});
  assert.equal(state().zoneGroup.children.length, 0, 'rubbing the zones out clears them');
  sandbox.airportReceive({type: 'snapshot', world: base});
}
{
  // A connector taxiway is drawn the way traffic runs over it, not the way
  // its footprint happens to lie.
  const world = sandbox.airportPreview.world;
  const square = {id: 'square', kind: 'taxiway', x: -350, y: 60, width: 30, depth: 30, rotation: 0, connected: true};
  const deep = {id: 'deep', kind: 'taxiway', x: -350, y: 130, width: 30, depth: 45, rotation: 0, connected: true};
  const pad = (id, y) => ({id, kind: 'stand', x: -320, y, width: 60, depth: 65, rotation: 0, connected: true, nose: '+x'});
  sandbox.airportReceive({type: 'snapshot', world: {...world, facilities: [...world.facilities, square, pad('sq-stand', 45), deep, pad('deep-stand', 120)]}});
  const built = sandbox.airportDebug.state.facilities;
  assert.equal(built.get('square').context.vertical, false, 'a square connector runs the way it is used');
  assert.equal(built.get('deep').context.vertical, false, 'so does one deeper than it is wide');
  assert.equal(built.get('b2').context.vertical, true, 'a long taxiway runs down its length');
  sandbox.airportReceive({type: 'snapshot', world});
}
console.log('PASS: bootstrap, facility geometry, bridge views/tools, entity removal, airport mode, side porches, zoning, taxiway flow; no runtime errors.');
const logic=sandbox.AirportSceneLogic;
const catalog=[{kind:'terminal',width:120,depth:60,cost:4000000,name:'Terminal'},{kind:'checkIn',width:8,depth:4,cost:45000,name:'Check-in desks'},{kind:'seating',width:8,depth:4,cost:45000,name:'Seating'},{kind:'stand',width:60,depth:65,cost:1200000,name:'Aircraft stand'}];
const terminal={id:'t',kind:'terminal',x:0,y:0,width:120,depth:60};
const testWorld={catalog,facilities:[terminal],cash:5000000,time:0,flights:[]};
assert(logic.validate(testWorld,{kind:'seating'},{x:10,y:10,w:8,d:4}).valid);
assert(!logic.validate(testWorld,{kind:'seating'},{x:117,y:10,w:8,d:4}).valid);
assert(!logic.validate(testWorld,{kind:'stand'},{x:10,y:10,w:60,d:65}).valid);
assert.match(logic.validate({...testWorld,cash:0},{kind:'seating'},{x:10,y:10,w:8,d:4}).reason,/cash/);
assert(!logic.validate(testWorld,{kind:'stand'},{x:3990,y:0,w:60,d:65}).valid);
const stand={id:'s',kind:'stand',x:200,y:200,width:60,depth:65};
assert(logic.validate({...testWorld,facilities:[stand]},{kind:'stand',moveId:'s'},{x:200,y:200,w:60,d:65}).valid);
// Buildings move even while in use; a terminal takes its furnishings along.
assert(logic.validate({...testWorld,flights:[{stage:'boarding',arrival:0,departure:50}]},{kind:'terminal',moveId:'t'},{x:0,y:0,w:120,d:60}).valid);
assert(logic.validate({...testWorld,facilities:[{...terminal,protected:false}],flights:[{stage:'boarding',arrival:0,departure:50}]},{kind:'terminal',moveId:'t'},{x:0,y:0,w:120,d:60}).valid);
assert(logic.validate({...testWorld,facilities:[{...terminal,protected:true},{id:'c',kind:'checkIn',x:10,y:10,width:8,depth:4}]},{kind:'terminal',moveId:'t'},{x:300,y:300,w:120,d:60}).valid);
const longTaxiway={id:'long-taxiway',kind:'taxiway',width:20,depth:1700,rotation:0};
assert.deepEqual(Array.from(logic.footprint({facilities:[longTaxiway]},{kind:'taxiway',moveId:longTaxiway.id,rotation:0})),[20,1700]);
assert.deepEqual(Array.from(logic.footprint({facilities:[longTaxiway]},{kind:'taxiway',moveId:longTaxiway.id,rotation:1})),[1700,20]);
assert.deepEqual(Array.from(logic.footprint({facilities:[{...longTaxiway,width:1700,depth:20,rotation:1}]},{kind:'taxiway',moveId:longTaxiway.id,rotation:3})),[1700,20]);
for(let rotation=0;rotation<4;rotation++){
  const width=rotation%2?65:60,depth=rotation%2?60:65;
  const mesh=sandbox.AirportModels.facility({...stand,rotation,width,depth});
  const bounds=new THREE.Box3().setFromObject(mesh);
  assert(Math.abs(bounds.min.x-200)<.01 && Math.abs(bounds.min.z-200)<.01);
  assert(Math.abs(bounds.max.x-200-width)<.01 && Math.abs(bounds.max.z-200-depth)<.01);
}
const groups=Array.from({length:100},(_,i)=>({id:String(i),count:100,stage:'checkIn'}));
assert.equal(logic.crowdAllocation(groups,'low').reduce((n,v)=>n+v.visible,0),300);
assert.equal(logic.crowdAllocation(groups,'high').reduce((n,v)=>n+v.visible,0),1200);
assert.equal(logic.crowdAllocation([{id:'a',count:7,stage:'security'}],'high')[0].visible,7);
const contactWorld={catalog:[{kind:'standContact',width:60,depth:65,cost:1,name:'Contact stand'}],facilities:[terminal],cash:9e9,time:0,flights:[]};
assert(!logic.validate(contactWorld,{kind:'standContact'},{x:300,y:0,w:60,d:65}).valid);
assert(logic.validate(contactWorld,{kind:'standContact'},{x:120,y:0,w:60,d:65}).valid);
// Three halls like the original game: check-in and security in the arrival
// hall, shops and gates in the main hall, reclaim, customs and the way out in
// the departure hall.
const interiorDef=(kind,width,depth)=>({kind,width,depth,cost:1,interior:true,name:kind});
const halls={catalog:[...catalog,{kind:'terminalLandside',width:60,depth:40,cost:1,name:'Arrival hall',hidden:true},{kind:'terminalReclaim',width:60,depth:40,cost:1,name:'Departure hall',hidden:true},interiorDef('shop',12,8),interiorDef('customs',8,6),interiorDef('security',8,6),interiorDef('baggageCarousel',10,5),interiorDef('bins',2,1)],facilities:[terminal,{id:'a',kind:'terminalLandside',x:120,y:0,width:40,depth:60},{id:'d',kind:'terminalReclaim',x:120,y:60,width:40,depth:60}],cash:9e9,time:0,flights:[]};
const at=(kind,x,y,w,d)=>logic.validate(halls,{kind},{x,y,w,d});
assert.match(at('shop',125,10,12,8).reason,/main hall/,'no shops in the arrival hall');
assert.match(at('shop',125,70,12,8).reason,/main hall/,'nor in the departure hall');
assert(at('shop',10,10,12,8).valid,'shops in the main hall');
assert(at('security',125,10,8,6).valid,'security in the arrival hall');
assert.match(at('security',10,10,8,6).reason,/arrival hall/,'security is not in the main hall');
assert(at('customs',125,70,8,6).valid,'customs in the departure hall');
assert.match(at('customs',125,10,8,6).reason,/departure hall/,'customs is not in the arrival hall');
assert.match(at('baggageCarousel',10,10,10,5).reason,/departure hall/,'reclaim is not in the main hall');
for(const [x,y] of [[125,10],[10,10],[125,70]])assert(at('bins',x,y,2,1).valid,'bins anywhere');
assert.match(at('customs',400,400,8,6).reason,/inside the departure hall/,'outside every hall');
assert.equal(logic.zoneOf('checkIn'),'arrival');
assert.equal(logic.hallZone('terminalReclaim'),'departure');
// The old halls stay standing but are not built any more: zone instead.
assert.match(logic.validate(halls,{kind:'terminalLandside'},{x:400,y:400,w:60,d:40}).reason,/zone its floor/);
assert(logic.validate(halls,{kind:'terminal'},{x:400,y:400,w:120,d:60}).valid,'terminals still go up');
const standKinds=['standRegional','standContact'];
for(const kind of ['standRegional','standContact','shop','lounge','plant','fountain','infoBoard','seating','ticketMachine','vendingMachine','baggageCarousel','clothingShop','luxuryBoutique','vipLounge','checkInCounter','kiosk','foodShop','perfumeShop','restaurant','infoDesk','bins','coffeeToGo','arcade','flowerShop','foodCart','infoPanel','customs','checkOut','casino']){
  const size={standRegional:[40,45],standContact:[60,65],shop:[12,8],lounge:[14,10],plant:[2,2],fountain:[6,6],infoBoard:[4,2],seating:[8,4],ticketMachine:[1,1],vendingMachine:[1,1],baggageCarousel:[10,5],clothingShop:[8,6],luxuryBoutique:[8,6],vipLounge:[8,6],checkInCounter:[6,5],kiosk:[5,4],foodShop:[10,8],perfumeShop:[8,7],restaurant:[14,10],infoDesk:[5,4],bins:[2,1],coffeeToGo:[4,3],arcade:[10,8],flowerShop:[6,5],foodCart:[3,2],infoPanel:[1,1],customs:[8,6],checkOut:[8,4],casino:[12,10]}[kind];
  for(let rotation=0;rotation<4;rotation++){
    const width=rotation%2?size[1]:size[0],depth=rotation%2?size[0]:size[1];
    const mesh=sandbox.AirportModels.facility({id:'x7',kind,x:50,y:80,width,depth,rotation},standKinds.includes(kind)?{noseSide:rotation}:{});
    const b=new THREE.Box3().setFromObject(mesh);
    assert(b.min.x>=50-.05&&b.min.z>=80-.05&&b.max.x<=50+width+.05&&b.max.z<=80+depth+.05,`${kind} r${rotation} leaves its footprint: ${JSON.stringify(b)}`);
    sandbox.AirportModels.dispose(mesh);
  }
}
for(const id of ['atr72','a320neo','b787_9','a380_800','unknown']){const plane=sandbox.AirportModels.aircraft(id,'Coastal Connect');const b=new THREE.Box3().setFromObject(plane);assert(b.min.y>=-.01&&Number.isFinite(b.max.z),id);}
assert.equal(new Set(['Luma','Coastal Connect','Meridian Airways','Aurora International'].map(c=>logic.livery(c).main)).size,4);
assert.equal(logic.friendly('taxiIn'),'Taxi In');
let parkedModels=0;
const originalAircraft=sandbox.AirportModels.aircraft;
sandbox.AirportModels.aircraft=(...args)=>{parkedModels++;return originalAircraft(...args);};
sandbox.airportReceive({type:'snapshot',world:{...testWorld,facilities:[],flights:[],idleAircraft:[{id:'owned-starter',modelId:'atr72',carrier:'Luma',stage:'parked',x:0,y:0,z:0,heading:0}],vehicles:[],passengers:[]}});
assert.equal(parkedModels,1);
sandbox.AirportModels.aircraft=originalAircraft;
sandbox.airportReceive({type:'snapshot',world:{...testWorld,facilities:[],flights:[{id:'f',modelId:'atr72',carrier:'Coastal Connect',stage:'boarding',x:0,y:0}],vehicles:[],passengers:groups}});
sandbox.airportReceive({type:'view',action:'quality',value:'low'});
assert(!messages.some(m=>m.type==='error'),JSON.stringify(messages));
console.log('PASS: containment, overlaps, funds, boundaries, move exclusions/protection, all quarter turns, carrier palettes, live flight labels, crowd budgets.');


// ── Landside district ─────────────────────────────────────────────────────
{
  const land = sandbox.AirportLandside;
  const preview = sandbox.airportPreview.world.facilities;
  const frame = land.layout(preview, sandbox.airportPreview.world.zones);
  // The starter airport faces +X: runway and stands sit to the -X of the
  // terminals, so the public side is the entrance hall's front at x = -90.
  assert.equal(frame.dir.join(','), '1,0', 'landside faces away from the apron');
  assert.equal(frame.origin.x, -90);
  assert.equal(frame.origin.z, -30);
  assert(Math.abs(frame.angle) < 1e-9, 'a +X landside needs no turn');
  for (const [dx, dz, expect] of [[1, 0, '-1,0'], [0, 1, '0,-1'], [0, -1, '0,1']]) {
    const moved = preview.map(f => f.kind === 'terminal' ? f : {...f, x: f.x + dx * 900, y: f.y + dz * 900});
    assert.equal(land.layout(moved).dir.join(','), expect, `apron moved to ${dx},${dz}`);
  }
  assert.equal(land.layout([]), null, 'no terminal, no landside');
  assert.equal(JSON.stringify(frame.signs), JSON.stringify([{text: 'ARRIVAL HALL', v: -30}, {text: 'DEPARTURE HALL', v: 30}]), 'the canopy names the zones behind it');

  sandbox.airportReceive({type: 'snapshot', world: sandbox.airportPreview.world});
  const district = sandbox.airportDebug.state.district;
  assert(district, 'the preview airport grows a landside');
  assert(district.group.parent === sandbox.airportDebug.state.scene, 'the district is in the scene');
  const box = new THREE.Box3().setFromObject(district.group);
  assert(box.min.x >= -92, `the district stays on the public side (${box.min.x})`);
  assert(box.max.x > 300 && box.max.y > 40, 'road, railway and hotels have height and reach');
  for (const key of ['minX', 'maxX', 'minZ', 'maxZ']) assert(Number.isFinite(district.rect[key]));
  assert(district.rect.minX <= box.min.x && district.rect.maxX >= box.max.x, 'the treeline exclusion covers what was built');
  // Baking keeps the whole district inside a handful of draw calls.
  let meshes = 0, triangles = 0;
  district.group.traverse(o => {
    if (!o.isMesh) return;
    meshes++;
    const index = o.geometry.index, count = index ? index.count : o.geometry.attributes.position.count;
    triangles += count / 3 * (o.isInstancedMesh ? o.count || 1 : 1);
  });
  assert(meshes < 200, `landside draw calls stay low (${meshes})`);
  assert(triangles < 400000, `landside triangle budget (${Math.round(triangles)})`);
  if (process.env.LANDSIDE_STATS) console.log(`  landside: ${meshes} meshes, ${Math.round(triangles / 1000)}k triangles`);

  // A rebuild with the same terminals reuses the district; a moved terminal replaces it.
  assert.equal(sandbox.AirportLandside.build(preview, sandbox.airportPreview.world.zones), district, 'unchanged terminals keep the district');
  const shifted = preview.map(f => sandbox.AirportSceneLogic.hallKinds.has(f.kind) ? {...f, x: f.x + 40} : f);
  const rebuilt = sandbox.AirportLandside.build(shifted, sandbox.airportPreview.world.zones);
  assert(rebuilt && rebuilt !== district, 'a moved terminal rebuilds the district');
  assert.equal(rebuilt.group.position.x, -50);

  // Traffic runs, stops and thins out.
  const bus = rebuilt.group.children.find(o => o.userData.mover === 'bus');
  const cars = rebuilt.group.children.find(o => o.isInstancedMesh);
  const start = bus.position.clone();
  let moved = false;
  for (let i = 0; i < 400; i++) {
    rebuilt.update(1 / 30, {activity: 1, night: 0, paused: false, speed: 1});
    if (!Number.isFinite(bus.position.x) || !Number.isFinite(bus.position.z)) assert.fail('traffic left the map');
    if (bus.position.distanceTo(start) > 20) moved = true;
  }
  assert(moved, 'buses drive the access road');
  const busy = cars.count;
  rebuilt.update(1 / 30, {activity: 0, night: 1, paused: false, speed: 1});
  const quiet = cars.count;
  assert(quiet < busy, `a quiet airport at night thins the traffic (${busy} to ${quiet})`);
  assert.equal(quiet, 0, 'nobody arriving or leaving, nobody on the road');
  const buses = rebuilt.group.children.filter(o => o.userData.mover === 'bus');
  assert(buses.every(b => !b.visible), 'and no buses either');

  rebuilt.update(1 / 30, {activity: 1, paused: true, speed: 1});
  const before = new THREE.Vector3().setFromMatrixPosition(readMatrix(cars, 0));
  rebuilt.update(1 / 30, {activity: 1, paused: true, speed: 1});
  const after = new THREE.Vector3().setFromMatrixPosition(readMatrix(cars, 0));
  assert(before.distanceTo(after) < 1e-6, 'a paused airport stops the traffic');
  rebuilt.dispose();
  assert.equal(rebuilt.group.parent, null, 'disposing detaches the district');
  console.log('PASS: landside orientation, rebuild, budget and traffic.');
}
function readMatrix(mesh, i) { const m = new THREE.Matrix4(); mesh.getMatrixAt(i, m); return m; }


// A native window can load the page before it has a size.
{
  const zero = { ...sandbox, innerWidth: 0, innerHeight: 0, AirportHud: undefined };
  zero.window = zero;
  vm.createContext(zero);
  for (const file of ['scene_logic.js', 'models.js', 'landside.js', 'preview.js', 'scene.js']) {
    vm.runInContext(fs.readFileSync(`${__dirname}/${file}`, 'utf8'), zero, { filename: file });
  }
  const { camera, distance } = zero.airportDebug.state;
  assert(Number.isFinite(distance), 'camera distance survives a 0×0 viewport');
  assert(camera.position.toArray().every(Number.isFinite), 'camera position survives a 0×0 viewport');
  console.log('PASS: a zero-size first load keeps a usable camera.');
}
