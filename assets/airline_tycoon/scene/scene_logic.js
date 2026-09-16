/* Read-only previews mirror the authoritative Dart construction rules. */
window.AirportSceneLogic = (() => {
  const interior = new Set(['entrance','checkIn','security','seating','toilets','cafe','boardingGate']);
  const contains = (a,b) => b.x>=a.x && b.y>=a.y && b.x+b.width<=a.x+a.width && b.y+b.depth<=a.y+a.depth;
  const overlaps = (a,b) => a.x<b.x+b.width-.01 && a.x+a.width>b.x+.01 && a.y<b.y+b.depth-.01 && a.y+a.depth>b.y+.01;
  function friendly(value) { return String(value||'').replace(/([a-z])([A-Z])/g,'$1 $2').replace(/_/g,' ').replace(/^./,c=>c.toUpperCase()); }
  function validate(world,tool,p) {
    const catalog=world.catalog||[], def=catalog.find(d=>d.kind===tool.kind);
    const buildings=world.facilities||[], old=buildings.find(f=>f.id===tool.moveId), cost=tool.moveId?0:def?.cost;
    const result=reason=>({valid:!reason,reason,cost,name:def?.name||friendly(tool.kind)});
    if(!def)return result('Waiting for construction catalog.');
    if(!Number.isFinite(p.x)||!Number.isFinite(p.y)||Math.abs(p.x)>4000||Math.abs(p.y)>4000)return result('Build inside the airport boundary (±4 km).');
    if(tool.moveId&&!old)return result('That building no longer exists.');
    if(old&&(typeof old.protected==='boolean'?old.protected:(world.flights||[]).some(f=>!['completed','cancelled'].includes(f.stage)&&f.arrival<=world.time+120&&f.departure+180>=world.time)))return result('This facility is in use or needed by an imminent flight.');
    if(old&&old.kind!==tool.kind)return result('A moved building must keep its original type.');
    const candidate={x:p.x,y:p.y,width:p.w,depth:p.d};
    if(p.x+p.w>4000||p.y+p.d>4000)return result('The building extends beyond airport land.');
    if(interior.has(tool.kind)&&!buildings.some(b=>b.kind==='terminal'&&contains(b,candidate)))return result('Place this completely inside a terminal section.');
    for(const b of buildings)if(b.id!==old?.id&&overlaps(candidate,b)&&!(interior.has(tool.kind)&&b.kind==='terminal')&&!(tool.kind==='terminal'&&interior.has(b.kind)))return result(`This overlaps ${catalog.find(d=>d.kind===b.kind)?.name||friendly(b.kind)}.`);
    if(old?.kind==='terminal'&&buildings.some(b=>interior.has(b.kind)&&contains(old,b)))return result('Move or remove the terminal furnishings first.');
    if(world.cash<cost)return result('Not enough cash for this construction.');
    return result(null);
  }
  function footprint(world,tool,fallback=[10,10]) {const old=(world?.facilities||[]).find(f=>f.id===tool.moveId),def=(world?.catalog||[]).find(d=>d.kind===tool.kind);let width=old?.width??def?.width??fallback[0],depth=old?.depth??def?.depth??fallback[1];if(Math.abs(((Number(tool.rotation)||0)-(old?.rotation||0))%2)===1)[width,depth]=[depth,width];return [width,depth];}
  function crowdAllocation(groups,quality) {
    let left=quality==='low'?36:120;
    return groups.filter(g=>!['boarded','completed'].includes(g.stage)).map(g=>{const visible=Math.min(left,12,Math.max(0,Math.ceil(g.count/5)));left-=visible;return {group:g,visible};}).filter(g=>g.visible>0);
  }
  function livery(carrier) {
    const name=String(carrier||'').toLowerCase();
    if(/coast/.test(name))return {main:0x168a98,accent:0xf2c45d};
    if(/meridian/.test(name))return {main:0x3058a0,accent:0xf29b67};
    if(/aurora/.test(name))return {main:0x714b82,accent:0xdac078};
    return {main:0x258373,accent:0xbee5d0};
  }
  return {validate,crowdAllocation,livery,friendly,footprint};
})();

