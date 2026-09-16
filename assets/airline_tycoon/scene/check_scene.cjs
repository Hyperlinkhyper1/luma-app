// Node-only structural smoke check; rendering still requires device verification.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const THREE = require('./vendor/three-0.160.1.min.js');
const elements = new Map();
function element() {
  return {
    style: {}, classList: { add() {} }, textContent: '',
    addEventListener() {},
    getBoundingClientRect() { return { left: 0, top: 0, width: 1200, height: 800 }; },
    getContext() { return { clearRect() {}, fillText() {}, fillRect() {} }; },
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
const sandbox = {
  THREE: { ...THREE, WebGLRenderer: Renderer }, document, console, performance,
  innerWidth: 1200, innerHeight: 800, devicePixelRatio: 1, URLSearchParams,
  requestAnimationFrame() {}, addEventListener() {}, location: { search: '?preview=1' },
  chrome: { webview: { postMessage(message) { messages.push(JSON.parse(message)); } } },
};
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const file of ['scene_logic.js', 'models.js', 'preview.js', 'scene.js']) {
  vm.runInContext(fs.readFileSync(`${__dirname}/${file}`, 'utf8'), sandbox, { filename: file });
}
assert(messages.some(m => m.type === 'ready'));
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
assert.equal(elements.get('status').style.top,'70px');
assert.equal(elements.get('status').style.bottom,'auto');
sandbox.airportReceive({ type: 'tool', kind: null });
assert.equal(elements.get('status').style.top,'auto');
assert.equal(elements.get('status').style.bottom,'16px');
sandbox.airportReceive({ type: 'snapshot', world: { ...sandbox.airportPreview.world, facilities: [], flights: [], vehicles: [], passengers: [] } });
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
assert(!logic.validate({...testWorld,flights:[{stage:'boarding',arrival:0,departure:50}]},{kind:'terminal',moveId:'t'},{x:0,y:0,w:120,d:60}).valid);
assert(logic.validate({...testWorld,facilities:[{...terminal,protected:false}],flights:[{stage:'boarding',arrival:0,departure:50}]},{kind:'terminal',moveId:'t'},{x:0,y:0,w:120,d:60}).valid);
assert(!logic.validate({...testWorld,facilities:[{...terminal,protected:true}]},{kind:'terminal',moveId:'t'},{x:0,y:0,w:120,d:60}).valid);
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
assert.equal(logic.crowdAllocation(groups,'low').reduce((n,v)=>n+v.visible,0),36);
assert.equal(logic.crowdAllocation(groups,'high').reduce((n,v)=>n+v.visible,0),120);
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


