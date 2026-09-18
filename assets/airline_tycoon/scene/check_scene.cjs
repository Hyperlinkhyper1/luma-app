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
    style: {}, classList: { add() {} }, textContent: '',
    addEventListener() {},
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
  // The entrance's door opens the wall it is on, and pavements that touch
  // hand their edge lines over and join their centrelines.
  const built = sandbox.airportDebug.state.facilities;
  const doors = [...built.values()].flatMap(f => f.context?.doors || []);
  assert.deepEqual(JSON.parse(JSON.stringify(doors)), [{side: '+x', at: 27}], 'one doorway, on the +x wall, 27 m along it');
  const trunk = built.get('b2');
  assert(trunk.context.cuts.length >= 2, 'the long taxiway gives way where the short ones join it');
  const standCuts = built.get('b6').context.cuts;
  assert(standCuts.length >= 1, 'the stand border opens onto its taxiway');
}
const before = hud.updates;
sandbox.airportReceive({ type: 'snapshot', world: { ...sandbox.airportPreview.world, facilities: [], flights: [], vehicles: [], passengers: [] } });
assert.equal(hud.updates, before + 1);
assert(!messages.some(m => m.type === 'error'), JSON.stringify(messages));
console.log('PASS: bootstrap, facility geometry, bridge views/tools, entity removal; no runtime errors.');
const logic=sandbox.AirportSceneLogic;
const catalog=[{kind:'terminal',width:120,depth:60,cost:4000000,name:'Terminal'},{kind:'checkIn',width:8,depth:4,cost:45000,name:'Check-in desks'},{kind:'stand',width:60,depth:65,cost:1200000,name:'Aircraft stand'}];
const terminal={id:'t',kind:'terminal',x:0,y:0,width:120,depth:60};
const testWorld={catalog,facilities:[terminal],cash:5000000,time:0,flights:[]};
assert(logic.validate(testWorld,{kind:'checkIn'},{x:10,y:10,w:8,d:4}).valid);
assert(!logic.validate(testWorld,{kind:'checkIn'},{x:117,y:10,w:8,d:4}).valid);
assert(!logic.validate(testWorld,{kind:'stand'},{x:10,y:10,w:60,d:65}).valid);
assert(!logic.validate({...testWorld,cash:0},{kind:'checkIn'},{x:10,y:10,w:8,d:4}).valid);
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
const standKinds=['standRegional','standContact'];
for(const kind of ['standRegional','standContact','shop','lounge','plant','fountain','infoBoard','seating','ticketMachine','vendingMachine','baggageCarousel','clothingShop','luxuryBoutique','vipLounge','checkInCounter','kiosk','foodShop','perfumeShop','restaurant','infoDesk','bins','coffeeToGo','arcade','flowerShop','foodCart','infoPanel','customs','checkOut']){
  const size={standRegional:[40,45],standContact:[60,65],shop:[12,8],lounge:[14,10],plant:[2,2],fountain:[6,6],infoBoard:[4,2],seating:[8,4],ticketMachine:[1,1],vendingMachine:[1,1],baggageCarousel:[10,5],clothingShop:[8,6],luxuryBoutique:[8,6],vipLounge:[8,6],checkInCounter:[6,5],kiosk:[5,4],foodShop:[10,8],perfumeShop:[8,7],restaurant:[14,10],infoDesk:[5,4],bins:[2,1],coffeeToGo:[4,3],arcade:[10,8],flowerShop:[6,5],foodCart:[3,2],infoPanel:[1,1],customs:[8,6],checkOut:[8,4]}[kind];
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
  const frame = land.layout(preview);
  // The starter airport faces +X: runway and stands sit to the -X of the
  // terminals, so the public side is the far wall at x = -130.
  assert.equal(frame.dir.join(','), '1,0', 'landside faces away from the apron');
  assert.equal(frame.origin.x, -130);
  assert.equal(frame.origin.z, -30);
  assert(Math.abs(frame.angle) < 1e-9, 'a +X landside needs no turn');
  for (const [dx, dz, expect] of [[1, 0, '-1,0'], [0, 1, '0,-1'], [0, -1, '0,1']]) {
    const moved = preview.map(f => f.kind === 'terminal' ? f : {...f, x: f.x + dx * 900, y: f.y + dz * 900});
    assert.equal(land.layout(moved).dir.join(','), expect, `apron moved to ${dx},${dz}`);
  }
  assert.equal(land.layout([]), null, 'no terminal, no landside');

  sandbox.airportReceive({type: 'snapshot', world: sandbox.airportPreview.world});
  const district = sandbox.airportDebug.state.district;
  assert(district, 'the preview airport grows a landside');
  assert(district.group.parent === sandbox.airportDebug.state.scene, 'the district is in the scene');
  const box = new THREE.Box3().setFromObject(district.group);
  assert(box.min.x >= -132, `the district stays on the public side (${box.min.x})`);
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
  assert.equal(sandbox.AirportLandside.build(preview), district, 'unchanged terminals keep the district');
  const shifted = preview.map(f => f.kind === 'terminal' ? {...f, x: f.x + 40} : f);
  const rebuilt = sandbox.AirportLandside.build(shifted);
  assert(rebuilt && rebuilt !== district, 'a moved terminal rebuilds the district');
  assert.equal(rebuilt.group.position.x, -90);

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
