function airportCasino(g,w,d){
  const u = w/12, v = d/10, x = w/2, z = d/2, s = Math.min(u,v);
  const arch = 0x29272b, arch2 = 0x3b373d, dark = 0x202124;
  const deepRed = 0x703d46, burgundy = 0x5c333b, darkGreen = 0x315344, casGreen = 0x3f6650;
  const deepBlue = 0x394c60, purple = 0x675070;
  const gold = 0xc6a15b, darkGold = 0x9b7844, brass = 0xb39155, metal = 0x858789;
  const tWood = 0x704f38, dWood = 0x4b3427, slotBody = 0x45484a, slotDark = 0x292d30;
  const scrDark = 0x14252d;
  const warm = 0xffc978, goldGlow = 0xffd86a, redGlow = 0xe66c68, greenGlow = 0x79c98b, blueGlow = 0x7fe0e8;
  const skin = 0xd8b49a;

  // 1. Layered dark casino floor with burgundy / green gaming zones and gold edge strips.
  box(g,11.85*u,.04,9.85*v,x,.02,z,arch);
  box(g,11.4*u,.03,9.4*v,x,.042,z,dark);
  box(g,4.0*u,.05,5.4*v,2.6*u,.058,3.0*v,burgundy);
  box(g,3.2*u,.05,2.6*v,8.4*u,.058,7.0*v,darkGreen);
  box(g,4.6*u,.05,4.0*v,x,.058,5.4*v,0x1d1b1e);
  box(g,11.0*u,.02,.10*u,x,.07,0.55*v,gold);

  // 2. Enclosure: north back wall, west & east side walls with gold crown reveals.
  box(g,11.85*u,3.0,.18*v,x,1.5,.18*v,arch);
  box(g,11.6*u,1.10,.08*v,x,.55,.28*v,deepRed);
  box(g,11.65*u,.09,.12*v,x,1.695,.29*v,gold,'metal');
  box(g,.18*u,3.0,9.85*v,.18*u,1.5,z,arch);
  box(g,.10*u,1.10,9.5*v,.28*u,.55,z,deepRed);
  box(g,.13*u,.09,9.5*v,.28*u,1.695,z,gold,'metal');
  box(g,.18*u,3.0,9.85*v,w-.18*u,1.5,z,arch);
  box(g,.10*u,1.10,9.5*v,w-.28*u,.55,z,deepRed);
  box(g,.13*u,.08,9.5*v,w-.28*u,1.70,z,gold,'metal');
  // Decorative wall panels on the north wall.
  for (const px of [3.0,6.0,9.0]) {
    box(g,1.30*u,1.20,.05*v,px*u,1.55,.28*v,darkGold,'metal');
  }

  // 3. Gold columns defining the gaming floor.
  const colX = [3.0*u, 9.0*u];
  for (const cxx of colX) {
    cylinder(g,.20*s,2.90,cxx,1.45,1.20*v,arch2,'paint',.20*s,12);
    cylinder(g,.24*s,.20,cxx,.10,1.20*v,gold,'metal',.24*s,12);
  }

  // 4. Storefront / entrance (+z): pillared portal, glass bays, gold fascia & CASINO sign.
  for (const px of [3.30,6.70]) {
    box(g,.42*u,3.2,.42*v,px*u,1.60,9.62*v,arch2);
    box(g,.46*u,.13,.46*v,px*u,3.135,9.62*v,gold,'metal');
  }
  for (const wx of [1.55*u, w-1.55*u]) {
    box(g,2.10*u,.52,.16*v,wx,.26,9.70*v,arch);
    box(g,2.10*u,2.12,.05*v,wx,1.38,9.70*v,0xcfe0e2,'glass');
    box(g,2.14*u,.09,.08*v,wx,2.43,9.70*v,gold,'metal');
  }
  // Illuminated CASINO fascia header (lid above 2 m flagged).
  box(g,11.85*u,.70,.52*v,x,2.78,9.62*v,arch2);
  box(g,11.9*u,.07,.58*v,x,3.145,9.62*v,gold,'metal');
  g.children[g.children.length-1].userData.roof = true;
  label(g,'GOLDEN SKY',x,2.94,9.96*v,10,'#f9fcf6');
  label(g,'CASINO',x,2.66,9.96*v,4.6,goldGlow);
  light(g,x,2.80,9.88*v,goldGlow,.16);
  light(g,3.3*u,2.80,9.84*v,redGlow,.11);
  light(g,8.7*u,2.80,9.84*v,redGlow,.11);

  // 5. SLOT MACHINE ZONE — west side, two staggered rows facing +x.
  const slots = [
    { z:1.6, top:goldGlow, scr:blueGlow, name:'LUCKY 7', accent:purple },
    { z:2.5, top:redGlow,  scr:goldGlow, name:'777', accent:deepRed },
    { z:3.4, top:goldGlow, scr:blueGlow, name:'GOLD RUSH', accent:gold },
    { z:5.6, top:redGlow,  scr:blueGlow, name:'STAR SPIN', accent:blueGlow },
    { z:6.5, top:goldGlow, scr:redGlow,  name:'777', accent:gold }
  ];
  let idx = 0;
  for (const sl of slots) {
    const sx = (idx < 3 ? 1.30 : 2.60)*u, sz = sl.z*v;
    box(g,.62*u,2.36,.70*v,sx,1.185,sz,slotBody);
    box(g,.40*u,.52,.08*v,sx+.26*u,1.72,sz+.04*v,scrDark);
    light(g,sx+.30*u,1.72,sz+.06*v,sl.scr,.09);
    box(g,.34*u,.08,.66*v,sx+.24*u,1.34,sz,darkGold,'metal');
    box(g,.30*u,.26,.76*v,sx+.20*u,2.28,sz,sl.top);
    label(g,sl.name,sx+.44*u,2.28,sz,2.6,'#f9fcf6',{rotY:Math.PI/2});
    light(g,sx+.22*u,2.28,sz,sl.top,.06);
    idx++;
  }
  // Casino stools facing the machines (+x).
  for (const sz of [1.6*v,2.5*v,6.5*v]) {
    const stx = 2.55*u;
    cylinder(g,.19*s,.08,stx,.71,sz,burgundy,'paint',.19*s,10);
    cylinder(g,.045*s,.70,stx,.36,sz,metal,'metal',.045*s,8);
    cylinder(g,.20*s,.05,stx,.025,sz,darkGold,'metal',.20*s,8);
  }

  // 6. ROULETTE CENTERPIECE — the major attraction, centre-north.
  const rx = 8.3*u, rz = 5.4*v;
  box(g,2.60*u,.76,2.60*v,rx,.38,rz,dWood);
  box(g,2.72*u,.14,2.72*v,rx,.735,rz,gold,'metal');
  box(g,2.30*u,.08,2.30*v,rx,.755,rz,casGreen);
  box(g,.05*u,.012,2.10*v,rx,.795,rz,gold);
  box(g,1.90*u,.012,.05*v,rx,.795,rz,gold);
  // Raised roulette wheel at the dealer end (-z side of the table).
  cylinder(g,.62*s,.22,rx,.82,rz-1.30*v,dWood,'paint',.62*s,12);
  cylinder(g,.55*s,.12,rx,.925,rz-1.30*v,dark,'paint',.55*s,12);
  cylinder(g,.46*s,.09,rx,0.99,rz-1.30*v,deepRed,'paint',.46*s,12);
  cylinder(g,.16*s,.10,rx,1.025,rz-1.30*v,gold,'metal',.16*s,12);
  cylinder(g,.68*s,.20,rx,.795,rz-1.30*v,tWood,'paint',.68*s,12);
  // Dealer station opposite the wheel.
  box(g,1.10*u,.26,.55*v,rx,.79,rz+1.15*v,tWood);
  box(g,1.10*u,.22,.06*v,rx,.88,rz+.88*v,darkGold,'metal');
  // Low velvet player rail with gold kick plate (open toward -z walkway).
  box(g,2.85*u,.30,.10*v,rx,.17,rz-1.32*v,burgundy);
  box(g,2.85*u,.05,.08*v,rx,.34,rz-1.32*v,gold,'metal');
  box(g,.10*u,.30,2.60*v,rx-1.42*u,.17,rz,burgundy);
  box(g,.10*u,.30,2.60*v,rx+1.42*u,.17,rz,burgundy);
  box(g,2.85*u,.05,.08*v,rx,.345,rz+1.42*u,gold,'metal');
  // Chips and cards on the layout.
  for (const [chx,chz,cc] of [[-.75,.55,deepRed],[.80,.35,casGreen]]) {
    cylinder(g,.06*s,.06,rx+chx*u,.795,rz+chz*v,cc,'paint',.06*s,8);
  }
  box(g,.13*u,.01,.09*v,rx-.10*u,.795,rz+.20*v,0xefe7d6);
  box(g,.13*u,.01,.09*v,rx+.15*u,.795,rz+.30*v,0xefe7d6);
  // Overhead gold chandelier-style ring light above the roulette.
  cylinder(g,.55*s,.06,rx,2.62,rz,gold,'metal',.55*s,12);
  cylinder(g,.40*s,.05,rx,2.56,rz,dark,'paint',.40*s,10);
  light(g,rx,2.50,rz,goldGlow,.17);
  // Roulette dealer (north side, facing +z players).
  box(g,.27*u,.05,.22*v,rx,.875,rz+1.28*v,0x22222a);
  box(g,.27*u,.60,.22*v,rx,1.05,rz+1.28*v,0x22222a);
  box(g,.34*u,.62,.24*v,rx,1.58,rz+1.28*v,deepRed);
  box(g,.12*u,.42,.10*v,rx,1.64,rz+1.16*v,0xefe7d6);
  sphere(g,rx,1.97,rz+1.28*v,.13*s,.16,.13*s,skin);

  // 7. CARD TABLES — two green-felt tables in the south-east zone.
  const cardPos = [[6.9,7.4],[9.6,7.4]];
  for (const [cxx,czz] of cardPos) {
    const tx = cxx*u, tz = czz*v;
    box(g,1.70*u,.88,1.10*v,tx,.44,tz,dWood);
    box(g,1.80*u,.11,1.20*v,tx,.805,tz,gold,'metal');
    box(g,1.55*u,.09,1.05*v,tx,.83,tz,casGreen);
    box(g,1.44*u,.14,.08*v,tx,.83,tz-.52*v,tWood);
    box(g,1.44*u,.10,.04*v,tx,.83,tz,tWood);
    for (const [cx2,cz2,cc] of [[-.42,.20,deepRed],[.30,-.18,casGreen],[.12,.28,gold]]) {
      cylinder(g,.05*s,.06,tx+cx2*u,.895,tz+cz2*v,cc,'paint',.05*s,8);
    }
    box(g,.12*u,.01,.085*v,tx-.15*u,.895,tz+.10*v,0xefe7d6);
    box(g,.12*u,.01,.085*v,tx+.05*u,.895,tz-.12*v,0xefe7d6);
    // Dealer behind the table (north).
    box(g,.25*u,.05,.20*v,tx,.875,tz-.72*v,0x22222a);
    box(g,.25*u,.54,.20*v,tx,1.06,tz-.72*v,0x22222a);
    box(g,.32*u,.60,.22*v,tx,1.55,tz-.72*v,deepRed);
    sphere(g,tx,1.92,tz-.72*v,.12*s,.15,.12*s,skin);
  }

  // 8. CASHIER / CHIP SERVICE (north-east corner) with glass security partition.
  const cashX = 10.2*u, cashZ = 1.55*v;
  box(g,1.05*u,1.00,.70*v,cashX,.50,cashZ,dWood);
  box(g,1.10*u,.11,.76*v,cashX,1.02,cashZ,darkGold,'metal');
  box(g,1.12*u,.05,.78*v,cashX,1.085,cashZ,metal,'metal');
  box(g,1.06*u,.19,.07*v,cashX,.71,cashZ+.36*v,casGreen);
  label(g,'CASHIER',cashX,.71,cashZ+.40*v,2.6,'#f9fcf6');
  box(g,.05*u,1.35,.70*v,cashX-.50*u,1.63,cashZ,0xcfe0e2,'glass');
  box(g,.08*u,1.40,.06*v,cashX-.53*u,1.60,cashZ,gold,'metal');
  box(g,.05*u,1.35,.70*v,cashX+.50*u,1.63,cashZ,0xcfe0e2,'glass');
  box(g,.08*u,1.40,.06*v,cashX+.53*u,1.60,cashZ,gold,'metal');
  box(g,.48*u,.08,.14*v,cashX,.68,cashZ+.36*v,darkGold,'metal');
  cylinder(g,.07*s,.13,cashX-.20*u,1.06,cashZ+.25*v,gold,'paint',.07*s,8);
  // Cashier attendant behind the counter (staff side, -z).
  box(g,.24*u,.06,.20*v,cashX,.035,cashZ-.62*v,0x22222a);
  box(g,.24*u,.50,.20*v,cashX,.31,cashZ-.62*v,0x22222a);
  box(g,.32*u,.54,.22*v,cashX,.60,cashZ-.62*v,deepBlue);
  sphere(g,cashX,1.00,cashZ-.62*v,.12*s,.14,.12*s,skin);

  // 9. PREMIUM HIGH-LIMIT alcove (north-west) with velvet booth divider.
  box(g,.10*u,1.44,1.85*v,3.75*u,.72,1.35*v,burgundy);
  box(g,.14*u,.11,1.90*v,3.75*u,1.435,1.35*v,gold,'metal');
  box(g,1.30*u,.96,.80*v,2.95*u,.48,.95*v,dWood);
  box(g,1.38*u,.18,.88*v,2.95*u,.785,.95*v,gold,'metal');
  box(g,1.24*u,.16,.78*v,2.95*u,.825,.95*v,deepRed);
  label(g,'VIP',2.95*u,1.05,1.35*v,3.2,goldGlow,{rotY:-Math.PI/2});

  // 10. Representative players around the floor.
  // Player at a slot machine (west row).
  box(g,.24*u,.06,.20*v,3.40*u,.745,2.5*v,0x2d2d33);
  box(g,.24*u,.50,.20*v,3.40*u,.985,2.5*v,0x2d2d33);
  box(g,.32*u,.54,.24*v,3.40*u,1.46,2.5*v,deepBlue);
  sphere(g,3.40*u,1.79,2.5*v,.12*s,.14,.12*s,skin);
  // Player seated at card table 1.
  box(g,.24*u,.06,.20*v,6.9*u,.745,8.15*v,0x2d2d33);
  box(g,.24*u,.50,.20*v,6.9*u,.985,8.15*v,0x2d2d33);
  box(g,.32*u,.54,.24*v,6.9*u,1.46,8.15*v,burgundy);
  sphere(g,6.9*u,1.79,8.15*v,.12*s,.14,.12*s,skin);
  // Player standing at the roulette rail (south side).
  box(g,.26*u,.06,.22*v,7.6*u,.045,4.10*v,0x2d2d33);
  box(g,.26*u,.54,.22*v,7.6*u,.27,4.10*v,0x2d2d33);
  box(g,.34*u,.56,.24*v,7.6*u,.77,4.10*v,darkGreen);
  sphere(g,7.6*u,1.17,4.10*v,.12*s,.15,.12*s,skin);

  // 11. Ceiling beams with warm gold pendants over each gaming zone.
  box(g,11.2*u,.10,.22*v,x,2.92,4.85*v,arch2);
  g.children[g.children.length-1].userData.roof = true;
  for (const [lx,lz,lc] of [[2.6,2.5,redGlow],[5.0,2.5,blueGlow],[8.3,5.4,goldGlow],[6.9,7.4,warm],[10.2,1.3,warm]]) {
    cylinder(g,.015*s,.30,lx*u,2.72,lz*v,metal,'metal',.015*s,6);
    cylinder(g,.10*s,.16,lx*u,2.545,lz*v,gold,'metal',.10*s,10);
    light(g,lx*u,2.46,lz*v,lc,.12);
  }
}
