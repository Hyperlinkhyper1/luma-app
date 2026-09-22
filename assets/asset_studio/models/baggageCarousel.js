function baggageCarousel(g,w,d){
  const x = w / 2, z = d / 2, sx = w / 10, sz = d / 5;
  const charcoal = 0x343b3e, deck = 0x454d50, slat = 0x2b3234;
  const metal = 0x9ba2a3, body = 0xd8d3c6, base = 0x3b4347;
  const teal = 0x2a6d7a, dark = 0x1b2e36, glow = 0x7fe0e8, yellow = 0xf2c230;
  const margin = .2 * Math.min(sx,sz);
  const outer = Math.min(z-margin,x-margin-sx);
  const span = x-margin-outer;
  const west = x-span, east = x+span;
  const island = 1.02*sz;
  const beltTop = .55;

  // Offset drum caps and bridge decks stop their top faces from competing.
  // The bridge overlaps the lowered end caps, leaving a clean continuous rim.
  cylinder(g,outer-.07,.28,west,.14,z,base,'metal',outer-.07,12);
  cylinder(g,outer-.07,.28,east,.14,z,base,'metal',outer-.07,12);
  box(g,2*span,.30,2*(outer-.07),x,.15,z,base,'metal');
  cylinder(g,outer-.03,.22,west,.39,z,charcoal,'paint',outer-.03,12);
  cylinder(g,outer-.03,.22,east,.39,z,charcoal,'paint',outer-.03,12);
  box(g,2*span,.21,2*(outer-.03),x,.40,z,charcoal);
  cylinder(g,outer-.11,.045,west,.5225,z,deck,'paint',outer-.11,12);
  cylinder(g,outer-.11,.045,east,.5225,z,deck,'paint',outer-.11,12);
  box(g,2*span,.10,2*(outer-.11),x,.50,z,deck);

  // Two raised inner runs suggest the sloped transfer surface into the island.
  box(g,2*span-.18*sx,.06,.34*sz,x,.58,z-1.30*sz,slat);
  box(g,2*span-.18*sx,.06,.34*sz,x,.58,z+1.30*sz,slat);
  for (const off of [-1.65,-.55,.65,1.75]) {
    box(g,.035*sx,.018,.86*sz,x+off*sx,.559,z-1.68*sz,slat);
    box(g,.035*sx,.018,.86*sz,x+off*sx,.559,z+1.68*sz,slat);
  }

  // Long steel curbs make the carousel read as a contained passenger conveyor.
  box(g,2*span+.38*sx,.12,.09*sz,x,.59,z-outer+.13*sz,metal,'metal');
  box(g,2*span+.38*sx,.12,.09*sz,x,.59,z+outer-.13*sz,metal,'metal');
  box(g,2*span+.20*sx,.025,.035*sz,x,.6625,z-outer+.13*sz,yellow);
  box(g,2*span+.20*sx,.025,.035*sz,x,.6625,z+outer-.13*sz,yellow);
  box(g,2*span-.16*sx,.07,.07*sz,x,.585,z-island-.075*sz,metal,'metal');
  box(g,2*span-.16*sx,.07,.07*sz,x,.585,z+island+.075*sz,metal,'metal');

  // The raised, rounded service island is a separate tier, not buried in the belt.
  cylinder(g,island,.30,west,.70,z,body,'paint',island,10);
  cylinder(g,island,.30,east,.70,z,body,'paint',island,10);
  box(g,2*span,.34,2*island,x,.69,z,body);
  cylinder(g,island-.04,.06,west,.885,z,teal,'paint',island-.04,10);
  cylinder(g,island-.04,.06,east,.885,z,teal,'paint',island-.04,10);
  box(g,2*span-.12*sx,.08,2*(island-.04),x,.87,z,teal);
  cylinder(g,island-.12,.07,west,.94,z,body,'paint',island-.12,10);
  cylinder(g,island-.12,.07,east,.94,z,body,'paint',island-.12,10);
  box(g,2*span-.22*sx,.10,2*(island-.12),x,.93,z,body);

  // Dark service well and entry portal are planted directly on the island surface.
  box(g,2.65*sx,.045,.70*sz,x-.35*sx,1.0025,z,dark);
  box(g,.88*sx,.56,.62*sz,x-2.0*sx,1.26,z+.08*sz,body);
  box(g,.92*sx,.06,.66*sz,x-2.0*sx,1.57,z+.08*sz,metal,'metal');
  box(g,.68*sx,.23,.02*sz,x-2.0*sx,1.34,z+.40*sz,dark);
  light(g,x-2.0*sx,1.34,z+.425*sz,glow,.055);
  box(g,.12*sx,.055,.02*sz,x-2.0*sx,1.54,z+.421*sz,yellow);

  // Pylon passes into the island and the board overlaps its post instead of floating.
  const px = x+1.55*sx;
  cylinder(g,.14,1.12,px,1.50,z,metal,'metal',.14,8);
  cylinder(g,.21,.07,px,1.005,z,teal,'paint',.21,8);
  box(g,2.65*sx,.56,.19*sz,px,1.99,z,base,'metal');
  box(g,2.45*sx,.42,.025*sz,px,2.00,z+.123*sz,dark);
  box(g,2.45*sx,.42,.025*sz,px,2.00,z-.123*sz,dark);
  box(g,2.75*sx,.055,.22*sz,px,1.685,z,teal);
  box(g,2.82*sx,.05,.24*sz,px,2.295,z,metal,'metal');
  g.children[g.children.length-1].userData.roof = true;
  light(g,px,2.00,z+.148*sz,glow,.11);
  light(g,px,2.00,z-.148*sz,glow,.11);
  label(g,'03',px+.66*sx,2.045,z+.155*sz,9,'#e8fbfd');
  label(g,'03',px+.66*sx,2.045,z-.155*sz,9,'#e8fbfd',{rotY:Math.PI});
  label(g,'BAGGAGE CLAIM',px-.58*sx,1.985,z+.155*sz,3.6,'#9fd4de');

  // Two floor chevrons sit outside the curb and never intersect the conveyor.
  box(g,.58*sx,.012,.07*sz,x-1.4*sx,.006,z-outer-.13*sz,yellow);
  box(g,.58*sx,.012,.07*sz,x+.55*sx,.006,z-outer-.13*sz,yellow);

  // Varied luggage follows the annular path: front, back, then both rounded ends.
  const bags = [
    [-1.95,1.67,.72,.24,.42,0xc5b39a,.10,1],[-.70,1.68,.42,.54,.38,0x243542,0,1],
    [.72,1.68,.58,.27,.40,0x4d5d43,-.14,0],[2.28,1.66,.54,.30,.34,0x8a6a9c,.18,0],
    [-2.55,-1.67,.40,.52,.36,0x5c6570,0,1],[-1.20,-1.68,.62,.25,.42,0x243542,0,1],
    [.18,-1.68,.34,.49,.32,0xc9a14a,0,0],[1.50,-1.67,.88,.22,.28,0xd9d3c4,-.12,0],
    [2.55,-1.66,.52,.24,.34,0x4d5d43,.14,1],[-3.86,.55,.36,.56,.34,0x6e3b38,.18,1],
    [-3.90,-.65,.60,.22,.32,0xd9d3c4,-.20,0],[3.88,.48,.54,.24,.34,0x5c6570,.18,1]
  ];
  for (const [lx,lz,bw,bh,bd,col,ry,handle] of bags) {
    box(g,bw*sx,bh,bd*sz,x+lx*sx,beltTop+bh/2,z+lz*sz,col);
    if (ry) g.children[g.children.length-1].rotation.y = ry;
    if (handle) box(g,.26*sx,.05,.05*sz,x+lx*sx,beltTop+bh+.025,z+(lz-.11)*sz,base);
  }

  // Three unmistakably different bags complete the active reclaim loop.
  cylinder(g,.20,.62,x-.25*sx,beltTop+.20,z+1.68*sz,0x6e3b38,'paint',.20,10);
  g.children[g.children.length-1].rotation.z = Math.PI/2;
  box(g,.10*sx,.07,.46*sz,x-.25*sx,beltTop+.20,z+1.68*sz,base);
  box(g,.72*sx,.04,.44*sz,x-1.95*sx,beltTop+.26,z+1.67*sz,base);
  cylinder(g,.20,.58,x+4.12*sx,beltTop+.20,z,0x4d5d43,'paint',.20,10);
  g.children[g.children.length-1].rotation.x = Math.PI/2;
  box(g,.44*sx,.07,.10*sz,x+4.12*sx,beltTop+.20,z,base);
}
