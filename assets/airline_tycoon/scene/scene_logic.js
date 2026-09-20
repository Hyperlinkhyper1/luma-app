/* Read-only previews mirror the authoritative Dart construction rules. */
window.AirportSceneLogic = (() => {
  const baseInterior = ['entrance','checkIn','checkInCounter','infoDesk','bins','infoPanel','ticketMachine','security','customs','checkOut','seating','toilets','cafe','restaurant','vendingMachine','coffeeToGo','foodCart','boardingGate','shop','kiosk','foodShop','perfumeShop','flowerShop','clothingShop','luxuryBoutique','lounge','vipLounge','arcade','casino','plant','fountain','infoBoard','baggageCarousel'];
  const interiorOf = world => new Set([...baseInterior, ...(world?.catalog || []).filter(d => d.interior).map(d => d.kind)]);
  const standKinds = new Set(['stand','standRegional','standContact']);
  // The terminal's three parts (Dart: hallKinds): the arrival hall where
  // passengers come in, the main hall with shops and gates, and the
  // departure hall where arriving passengers collect their bags and leave.
  const hallKinds = new Set(['terminal','terminalLandside','terminalReclaim']);
  const arrivalHallKinds = new Set(['entrance','checkIn','checkInCounter','ticketMachine','security']);
  const departureHallKinds = new Set(['baggageCarousel','customs','checkOut']);
  const anyHallKinds = new Set(['infoDesk','infoBoard','infoPanel','bins']);
  /** 'arrival', 'departure', 'main' or 'any' (Dart: hallZoneOf). */
  const zoneOf = kind => arrivalHallKinds.has(kind) ? 'arrival' : departureHallKinds.has(kind) ? 'departure' : anyHallKinds.has(kind) ? 'any' : 'main';
  /** The zone a hall building is (Dart: hallZone). */
  const hallZone = hallKind => hallKind === 'terminalLandside' ? 'arrival' : hallKind === 'terminalReclaim' ? 'departure' : 'main';
  const hallNames = {arrival: 'Arrival hall', main: 'Main hall', departure: 'Departure hall'};
  /** The zone painted over (x, z), or null (Dart: zoneAt). */
  function zoneAt(world, x, z) {
    const zones = world?.zones || [];
    for (let i = zones.length - 1; i >= 0; i--) {
      const r = zones[i];
      if (x >= r.x && x <= r.x + r.width && z >= r.y && z <= r.y + r.depth) return r.zone;
    }
    return null;
  }
  /** Why [kind] cannot go in a [hallKind] hall, or null (Dart: zoneRefusal). */
  const zoneRefusal = (kind, hallKind) => zoneRefusalFor(kind, hallZone(hallKind));
  /** Why [kind] cannot go in a part of the terminal zoned [zone]. */
  function zoneRefusalFor(kind, zone) {
    const wants = zoneOf(kind);
    if (wants === 'any' || wants === zone) return null;
    if (wants === 'arrival') return 'This goes in the arrival hall, where passengers come in, buy a ticket, check in and go through security.';
    if (wants === 'departure') return 'This goes in the departure hall, where arriving passengers collect their bags, clear customs and leave.';
    return `Shops, food, seating and gates go in the main hall. The ${zone} hall only takes ${zone === 'arrival' ? 'the entrance, tickets, check-in and security' : 'baggage reclaim, customs and check-out'}.`;
  }
  const gap = (a,b) => Math.hypot(Math.max(0, a.x - b.x - b.width, b.x - a.x - a.width), Math.max(0, a.y - b.y - b.depth, b.y - a.y - a.depth));
  const contains = (a,b) => b.x>=a.x && b.y>=a.y && b.x+b.width<=a.x+a.width && b.y+b.depth<=a.y+a.depth;
  const overlaps = (a,b) => a.x<b.x+b.width-.01 && a.x+a.width>b.x+.01 && a.y<b.y+b.depth-.01 && a.y+a.depth>b.y+.01;
  function friendly(value) { return String(value||'').replace(/([a-z])([A-Z])/g,'$1 $2').replace(/_/g,' ').replace(/^./,c=>c.toUpperCase()); }
  function validate(world,tool,p) {
    const catalog=world.catalog||[], def=catalog.find(d=>d.kind===tool.kind);
    const buildings=world.facilities||[], old=buildings.find(f=>f.id===tool.moveId), cost=tool.moveId?0:def?.cost, interior=interiorOf(world);
    const result=reason=>({valid:!reason,reason,cost,name:def?.name||friendly(tool.kind)});
    if(!def)return result('Waiting for construction catalog.');
    if(!Number.isFinite(p.x)||!Number.isFinite(p.y)||Math.abs(p.x)>4000||Math.abs(p.y)>4000)return result('Build inside the airport boundary (±4 km).');
    if(tool.moveId&&!old)return result('That building no longer exists.');
    if(old&&old.kind!==tool.kind)return result('A moved building must keep its original type.');
    const candidate={x:p.x,y:p.y,width:p.w,depth:p.d};
    if(tool.kind==='standContact'&&!buildings.some(b=>b.kind==='terminal'&&gap(b,candidate)<=1))return result('A jet bridge needs this stand to touch the main hall.');
    if(p.x+p.w>4000||p.y+p.d>4000)return result('The building extends beyond airport land.');
    const hall=interior.has(tool.kind)?buildings.find(b=>hallKinds.has(b.kind)&&contains(b,candidate)):null;
    if(interior.has(tool.kind)&&!hall)return result(`Place this completely inside the ${hallNames[zoneOf(tool.kind)]?.toLowerCase()||'terminal'}.`);
    if(hall){const zone=zoneRefusalFor(tool.kind,zoneAt(world,p.x+p.w/2,p.y+p.d/2)??hallZone(hall.kind));if(zone)return result(zone);}
    for(const b of buildings)if(b.id!==old?.id&&overlaps(candidate,b)&&!(interior.has(tool.kind)&&hallKinds.has(b.kind))&&!(hallKinds.has(tool.kind)&&interior.has(b.kind)))return result(`This overlaps ${catalog.find(d=>d.kind===b.kind)?.name||friendly(b.kind)}.`);
    if(world.cash<cost)return result('Not enough cash for this construction.');
    return result(null);
  }
  function footprint(world,tool,fallback=[10,10]) {const old=(world?.facilities||[]).find(f=>f.id===tool.moveId),def=(world?.catalog||[]).find(d=>d.kind===tool.kind);let width=old?.width??def?.width??fallback[0],depth=old?.depth??def?.depth??fallback[1];if(Math.abs(((Number(tool.rotation)||0)-(old?.rotation||0))%2)===1)[width,depth]=[depth,width];return [width,depth];}
  const crowdBudget = quality => quality==='low'?300:1500;
  function crowdAllocation(groups,quality) {
    let left=crowdBudget(quality);
    return groups.filter(g=>!['boarded','completed'].includes(g.stage)).map(g=>{const visible=Math.min(left,12,Math.max(0,Math.round(g.count||0)));left-=visible;return {group:g,visible};}).filter(g=>g.visible>0);
  }
  function livery(carrier) {
    const name=String(carrier||'').toLowerCase();
    if(/coast/.test(name))return {main:0x168a98,accent:0xf2c45d};
    if(/meridian/.test(name))return {main:0x3058a0,accent:0xf29b67};
    if(/aurora/.test(name))return {main:0x714b82,accent:0xdac078};
    return {main:0x258373,accent:0xbee5d0};
  }
  return {validate,crowdAllocation,crowdBudget,livery,friendly,footprint,standKinds,hallKinds,zoneRefusal,zoneRefusalFor,zoneAt,zoneOf,hallZone,hallNames};
})();

