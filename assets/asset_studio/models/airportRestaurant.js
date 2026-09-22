function airportRestaurant(g,w,d){
  const u = w/14, v = d/10, x = w/2, s = Math.min(u,v);
  const shell = 0xe5e0d5, wall = 0xd8d3c6, dark = 0x343b3e;
  const wood = 0x805d42, lightWood = 0xa77b55, tableTop = 0x74543d;
  const seatA = 0x465b66, seatB = 0x795f55, metal = 0x8b9295, equip = 0x9ba2a3;
  const teal = 0x2a6d7a, leaf = 0x47704f, leafD = 0x31563b;
  const warm = 0xffd99a, cool = 0xe6f1ef;
  const plate = 0xe8e3d6, foodA = 0xc96f3f, foodB = 0x7a9a5b, bottleG = 0x6e8ba0;

  function chair(px,pz,ry,col){
    const c = Math.cos(ry), sn = Math.sin(ry);
    box(g,.46*u,.09,.46*v,px*u,.47,pz*v,col);
    cylinder(g,.05*s,.43,px*u,.235,pz*v,metal,'metal',.05*s,8);
    box(g,.46*u,.55,.09*v,(px+sn*.235)*u,.78,(pz+c*.235)*v,col);
    g.children[g.children.length-1].rotation.y = ry;
  }
  function table2(px,pz,tw,td){
    box(g,tw*u,.07,td*v,px*u,.73,pz*v,tableTop);
    cylinder(g,.07*s,.70,px*u,.36,pz*v,dark,'paint',.09*s,8);
  }
  function plant(px,pz){
    cylinder(g,.22*s,.42,px*u,.21,pz*v,wood,'paint',.18*s,10);
    cylinder(g,.04*s,.45,px*u,.55,pz*v,wood,'paint',.04*s,8);
    sphere(g,px*u,.85,pz*v,.30*s,.36,.30*s,leaf);
    sphere(g,(px-.18)*u,.68,(pz+.1)*v,.18*s,.22,.18*s,leafD);
  }

  // Floor + entry carpet. North is kitchen/back, south (+z) is open front.
  box(g,13.7*u,.04,9.7*v,x,.02,5*v,wall);
  box(g,2.4*u,.03,2.4*v,7*u,.035,8.4*v,seatB);

  // Back wall + full-height side walls closing into the fascia (no raw ends).
  box(g,13.7*u,3.0,.16*v,x,1.5,.20*v,shell);
  box(g,13.4*u,.9,.08*v,x,.45,.30*v,wood);
  box(g,.16*u,3.0,9.70*v,.20*u,1.5,5.05*v,wall);
  box(g,.16*u,3.0,9.70*v,w-.20*u,1.5,5.05*v,wall);

  // Glazed storefront bays flanking the entrance (was: open holes).
  for (const bxp of [2.375, 11.625]) {
    box(g,4.35*u,.42,.16*v,bxp*u,.21,9.82*v,dark);
    box(g,4.35*u,2.05,.05*v,bxp*u,1.435,9.82*v,0xcfe0e2,'glass');
    box(g,4.35*u,.05,.10*v,bxp*u,2.445,9.82*v,metal,'metal');
    // Dresser inside the glass: low platform so the bay is never an empty hole.
    box(g,1.5*u,.44,.7*v,bxp*u,.22,9.30*v,lightWood);
    box(g,.50*u,.20,.5*v,(bxp-.45)*u,.52,9.30*v,foodA);
    box(g,.40*u,.16,.5*v,(bxp+.5)*u,.50,9.30*v,teal);
  }

  // Entrance frame + fascia + sign (south edge).
  box(g,.5*u,3.0,.5*v,4.7*u,1.5,9.55*v,shell);
  box(g,.5*u,3.0,.5*v,9.3*u,1.5,9.55*v,shell);
  box(g,13.7*u,.65,.45*v,x,2.775,9.65*v,shell);
  box(g,13.8*u,.06,.55*v,x,3.11,9.65*v,dark);
  g.children[g.children.length-1].userData.roof = true;
  // Sign board mounted proud of the fascia front face (front = 9.875).
  box(g,3.6*u,.46,.06*v,7*u,2.78,9.90*v,dark);
  label(g,'SKYLINE',7*u,2.88,9.94*v,9,'#f9fcf6');
  label(g,'KITCHEN - BAR',7*u,2.66,9.94*v,3.6,'#ffd99a');
  light(g,7*u,2.52,9.945*v,warm,.08);

  // Framed doorway: brass reveal under the fascia + sidelights close the reveal.
  box(g,4.2*u,.05,.10*v,7*u,2.44,9.88*v,metal,'metal');
  // Sidelights close the reveal gaps so only the door leaves are openings.
  box(g,1.05*u,2.46,.04*v,5.45*u,1.23,9.80*v,0xcfe0e2,'glass');
  box(g,1.05*u,2.46,.04*v,8.55*u,1.23,9.80*v,0xcfe0e2,'glass');
  // Double glass doors with kick rails, overlapping at the centre meeting.
  box(g,1.06*u,2.10,.05*v,6.47*u,1.05,9.78*v,0xcfe0e2,'glass');
  box(g,1.06*u,2.10,.05*v,7.51*u,1.05,9.795*v,0xcfe0e2,'glass');
  box(g,.98*u,.30,.07*v,6.47*u,.15,9.78*v,metal,'metal');
  box(g,.98*u,.30,.07*v,7.51*u,.15,9.795*v,metal,'metal');
  box(g,.05*u,.34,.05*v,6.94*u,1.12,9.82*v,metal,'metal');
  box(g,.05*u,.34,.05*v,7.06*u,1.12,9.82*v,metal,'metal');
  // Transom closing the gap between door heads and the header reveal.
  box(g,3.0*u,.40,.04*v,7*u,2.26,9.80*v,0xcfe0e2,'glass');
  light(g,7*u,2.43,9.62*v,warm,.06);
  // Porch: dark inlay + brass threshold so the approach reads as a door.
  box(g,3.6*u,.02,1.1*v,7*u,.045,9.05*v,dark);
  box(g,3.6*u,.03,.12*v,7*u,.05,9.62*v,metal,'metal');

  // Host podium + menu board + waiting bench near entrance.
  box(g,.62*u,1.02,.45*v,5.7*u,.51,8.35*v,wood);
  box(g,.68*u,.06,.50*v,5.7*u,1.04,8.35*v,dark);
  box(g,.30*u,.20,.06*v,5.7*u,1.16,8.30*v,dark);
  light(g,5.7*u,1.20,8.22*v,warm,.07);
  box(g,.70*u,.90,.06*v,8.2*u,1.15,8.55*v,dark);
  box(g,.06*u,.72,.08*v,8.45*u,.36,8.55*v,dark);
  label(g,'MENU',8.2*u,1.30,8.59*v,4,'#ffd99a');
  box(g,1.2*u,.12,.45*v,8.2*u,.45,8.55*v,lightWood);
  box(g,.10*u,.40,.40*v,7.65*u,.20,8.55*v,dark);
  box(g,.10*u,.40,.40*v,8.75*u,.20,8.55*v,dark);

  // Booth row along the north wall (west): high backs read from afar.
  for (const bx of [2.3,4.6]) {
    box(g,1.7*u,.42,.55*v,bx*u,.24,1.05*v,seatA);
    box(g,1.7*u,.85,.20*v,bx*u,.85,.68*v,seatA);
    box(g,1.7*u,.42,.55*v,bx*u,.24,2.15*v,seatA);
    box(g,1.7*u,.85,.20*v,bx*u,.85,2.52*v,seatA);
    box(g,1.15*u,.07,.75*v,bx*u,.72,1.60*v,tableTop);
    cylinder(g,.06*s,.68,bx*u,.36,1.60*v,dark,'paint',.08*s,8);
    box(g,.30*u,.06,.30*v,bx*u,.775,1.60*v,plate);
  }
  box(g,.12*u,1.35,2.1*v,3.45*u,.675,1.60*v,wood);

  // Freestanding dining sets (varied, with walk space between).
  table2(2.0,4.4,1.25,.75);
  chair(1.45,4.4,Math.PI/2,seatA); chair(2.55,4.4,-Math.PI/2,seatA);
  chair(2.0,3.85,0,seatB); chair(2.0,4.95,Math.PI,seatB);
  table2(4.5,4.2,.85,.75);
  chair(4.5,3.65,0,seatA); chair(4.5,4.75,Math.PI,seatA);
  table2(2.2,6.4,1.25,.75);
  chair(1.65,6.4,Math.PI/2,seatB); chair(2.75,6.4,-Math.PI/2,seatB);
  chair(2.2,6.95,Math.PI,seatA);
  table2(4.6,6.5,.85,.75);
  chair(4.6,5.95,0,seatB); chair(4.6,7.05,Math.PI,seatB);
  // Shared group table with legged benches east of the walkway.
  box(g,1.9*u,.07,1.0*v,7.2*u,.73,5.6*v,tableTop);
  cylinder(g,.08*s,.70,6.7*u,.36,5.6*v,dark,'paint',.10*s,8);
  cylinder(g,.08*s,.70,7.7*u,.36,5.6*v,dark,'paint',.10*s,8);
  box(g,1.7*u,.10,.35*v,7.2*u,.45,4.85*v,seatB);
  box(g,.12*u,.42,.30*v,6.5*u,.21,4.85*v,dark);
  box(g,.12*u,.42,.30*v,7.9*u,.21,4.85*v,dark);
  box(g,1.7*u,.10,.35*v,7.2*u,.45,6.35*v,seatB);
  box(g,.12*u,.42,.30*v,6.5*u,.21,6.35*v,dark);
  box(g,.12*u,.42,.30*v,7.9*u,.21,6.35*v,dark);
  box(g,.34*u,.07,.34*v,7.1*u,.79,5.6*v,plate);
  cylinder(g,.05*s,.22,7.2*u,.87,5.6*v,bottleG,'paint',.05*s,8);

  // Bar / service counter (east): long counter, stools, back shelf, bottles.
  box(g,1.0*u,1.0,3.2*v,11.3*u,.50,5.4*v,wood);
  box(g,1.15*u,.08,3.4*v,11.3*u,1.03,5.4*v,dark);
  box(g,.05*u,.45,3.0*v,10.79*u,.60,5.4*v,teal);
  for (const bzz of [4.5,5.4,6.3]) {
    cylinder(g,.20*s,.07,10.2*u,.78,bzz*v,seatA,'paint',.20*s,10);
    cylinder(g,.04*s,.74,10.2*u,.39,bzz*v,metal,'metal',.04*s,8);
  }
  box(g,.45*u,1.9,2.8*v,13.25*u,.95,5.4*v,wood);
  box(g,.40*u,.06,2.6*v,13.05*u,1.15,5.4*v,lightWood);
  box(g,.40*u,.06,2.6*v,13.05*u,1.65,5.4*v,lightWood);
  for (let i = 0; i < 5; i++) {
    cylinder(g,.055*s,.26,13.02*u,1.30,(4.5+i*.45)*v,[0x8a3b2e,0x3f6b4f,0x6e8ba0,0xc9a24b,0x7a5a8c][i],'paint',.055*s,8);
  }
  box(g,.5*u,.35,.4*v,11.3*u,1.25,6.4*v,equip,'metal');
  // BAR blade on posts rising from the counter's north end.
  box(g,.06*u,.56,.06*v,10.95*u,1.34,3.86*v,metal,'metal');
  box(g,.06*u,.56,.06*v,11.65*u,1.34,3.86*v,metal,'metal');
  box(g,.9*u,.30,.06*v,11.3*u,1.75,3.9*v,dark);
  label(g,'BAR',11.3*u,1.78,3.94*v,4,'#ffd99a');
  // Under-shelf glow tucked against the back-bar shelf.
  light(g,12.95*u,1.56,5.4*v,warm,.16);

  // Kitchen (north-east): plinth, range + hood, fridge, sink, shelf, pass.
  box(g,4.4*u,.06,2.3*v,11.0*u,.03,1.55*v,dark);
  box(g,3.6*u,.88,.6*v,11.0*u,.47,.80*v,equip,'metal');
  box(g,1.1*u,.90,.62*v,9.9*u,.48,.80*v,dark);
  cylinder(g,.11*s,.05,9.65*u,.95,.70*v,dark,'paint',.11*s,10);
  cylinder(g,.11*s,.05,10.15*u,.95,.90*v,dark,'paint',.11*s,10);
  box(g,1.5*u,.45,.85*v,9.9*u,1.95,.80*v,equip,'metal');
  box(g,.55*u,.95,.55*v,9.9*u,2.63,.80*v,equip,'metal');
  g.children[g.children.length-1].userData.roof = true;
  box(g,.95*u,1.85,.70*v,12.5*u,.955,.85*v,equip,'metal');
  box(g,.04*u,.60,.06*v,12.02*u,1.10,.85*v,dark);
  box(g,.85*u,.88,.60*v,11.6*u,.47,2.15*v,equip,'metal');
  cylinder(g,.16*s,.10,11.6*u,.945,2.15*v,metal,'metal',.16*s,10);
  box(g,2.0*u,.06,.50*v,11.0*u,1.80,.48*v,metal,'metal');
  box(g,.30*u,.22,.30*v,11.2*u,1.925,.48*v,foodB);
  // Food pass counter linking kitchen to dining room.
  box(g,3.4*u,.92,.56*v,10.6*u,.46,2.96*v,wood);
  box(g,3.5*u,.07,.62*v,10.6*u,.945,2.96*v,lightWood);
  cylinder(g,.11*s,.07,9.8*u,1.01,2.95*v,plate,'paint',.11*s,10);
  cylinder(g,.11*s,.07,11.2*u,1.01,2.95*v,plate,'paint',.11*s,10);
  cylinder(g,.07*s,.06,9.8*u,1.07,2.95*v,foodA,'paint',.07*s,8);
  // Heat-lamp gantry over the pass so the lamp is supported.
  box(g,.06*u,.46,.06*v,9.3*u,1.19,2.95*v,metal,'metal');
  box(g,.06*u,.46,.06*v,11.9*u,1.19,2.95*v,metal,'metal');
  // Stainless splashback tying the floating hood back to the wall.
  box(g,1.4*u,.96,.14*v,9.9*u,1.32,.32*v,equip,'metal');
  box(g,2.7*u,.06,.08*v,10.6*u,1.44,2.95*v,metal,'metal');
  light(g,10.6*u,1.35,2.95*v,cool,.14);
  // Kitchen zone totem standing on the plinth, sign facing the dining room.
  box(g,.10*u,1.9,.5*v,8.87*u,.95,1.55*v,dark);
  label(g,'KITCHEN',8.81*u,1.60,1.55*v,3.4,'#e6f1ef',{rotY:-Math.PI/2});

  // Plants splitting dining zones + columns carrying the ceiling beams.
  plant(5.9,4.3); plant(3.4,7.6);
  for (const bz of [3.4,6.4]) {
    box(g,11.5*u,.10,.22*v,6.35*u,2.88,bz*v,shell);
    g.children[g.children.length-1].userData.roof = true;
  }
  for (const cx of [1.0,12.3]) {
    for (const bz of [3.4,6.4]) box(g,.18*u,2.86,.18*v,cx*u,1.43,bz*v,shell);
  }
  for (const [lx,lz] of [[2.2,4.4],[4.5,6.5],[11.0,5.4]]) {
    cylinder(g,.015*s,.30,lx*u,2.70,lz*v,dark,'paint',.015*s,6);
    cylinder(g,.09*s,.14,lx*u,2.50,lz*v,wood,'paint',.16*s,10);
    light(g,lx*u,2.40,lz*v,warm,.11);
  }
}
