function oneWayCustoms(g,w,d){
  const u = w/5, v = d/4, x = w/2, z = d/2, s = Math.min(u,v);
  const body = 0xd8d3c6, cream = 0xe5e0d5, dark = 0x3b4347, top = 0x454d50;
  const metal = 0x8b9295, customs = 0x315d50, green = 0x47704f, proceed = 0x4f8b58;
  const pc = 0x343b3e, screen = 0x1b2e36, glow = 0x7fe0e8, post = 0x737b7e;
  const yellow = 0xe0b53f, stop = 0xc95a50, glassC = 0xcfe0e2, brass = 0xc89d4c;
  const warm = 0xffd99a, skin = 0xd8b49a, jacket = 0x395d4e, trouser = 0x212a25;

  // ===== Direction runs +z (ENTRY) → −z (EXIT). The lane is on the WEST side. =====
  // 1) Long customs-green approach carpet with painted entry chevrons.
  box(g,4.72*u,.04,3.76*v,x,.02,z,cream);
  box(g,1.20*u,.025,3.40*v,2.45*u,.045,2.20*v,customs);
  for (const [cx,rot] of [[1.95,Math.PI],[2.40,Math.PI],[2.85,Math.PI]]) {
    box(g,.22*u,.022,.14*v,cx*u,.082,2.20*v,customs);
    g.children[g.children.length-1].rotation.y = rot;
  }
  label(g,'ENTRY',2.45*u,.075,3.84*v,3.2,'#315d50',{ground:true});

  // 2) Entry gantry: CUSTOMS / DOUANE sign only on the entry side (+z).
  for (const px of [1.20,3.70]) {
    cylinder(g,.07*s,2.20,px*u,1.10,3.52*v,metal,'metal',.07*s,8);
  }
  box(g,2.70*u,.18,.24*v,2.45*u,2.10,3.50*v,dark);
  g.children[g.children.length-1].userData.roof = true;
  box(g,2.78*u,.04,.26*v,2.45*u,2.16,3.50*v,metal,'metal');
  box(g,2.74*u,.46,.06*v,2.45*u,2.40,3.70*v,customs);
  label(g,'CUSTOMS',2.45*u,2.50,3.74*v,7.5,'#f9fcf6');
  label(g,'DOUANE',2.45*u,2.30,3.74*v,3.6,'#e5e0d5');
  light(g,2.45*u,2.36,3.75*v,glow,.12);
  // Warm downlight cone over the lane center.
  box(g,.05*u,.02,.05*v,2.45*u,2.10,3.50*v,metal,'metal');
  box(g,.04*u,.04,.04*v,2.45*u,2.06,3.50*v,metal,'metal');
  light(g,2.45*u,2.04,3.40*v,warm,.10);

  // 3) Controlled lane: full-height glass on the WEST (passenger's left),
  //    rail + STOP panel on the EAST (passenger's right).
  box(g,.06*u,.08,2.40*v,1.45*u,.04,2.10*v,customs); // curb
  box(g,.08*u,1.95,2.40*v,1.28*u,.975,2.10*v,metal,'metal'); // mullion
  box(g,.05*u,1.82,2.20*v,1.34*u,1.035,2.10*v,glassC,'glass'); // glass
  box(g,.08*u,.04,2.40*v,1.28*u,1.94,2.10*v,metal,'metal'); // top trim
  for (const pz of [3.40,2.52]) {
    cylinder(g,.14*s,.05,3.62*u,.05,pz*v,metal,'metal',.16*s,10);
    cylinder(g,.045*s,.82,3.62*u,.43,pz*v,post,'metal',.045*s,8);
  }
  box(g,.84*u,.045,.03*v,3.62*u,.69,2.96*v,customs);
  box(g,.04*u,.12,.14*v,3.62*u,.92,3.40*v,stop);
  label(g,'STOP',3.62*u,1.05,3.49*v,2.4,'#f9fcf6');
  // Customs badge on the glass mullion so the lane reads as supervised.
  box(g,.16*u,.12,.02*v,1.34*u,.90,2.10*v,customs);
  label(g,'CUSTOMS',1.34*u,1.02,2.13*v,1.6,'#f9fcf6');

  // 4) Compact document station the passenger leans toward at the start of the lane.
  box(g,.50*u,.62,.42*v,2.05*u,.31,2.30*v,body);
  box(g,.54*u,.06,.46*v,2.05*u,.64,2.30*v,top);
  box(g,.54*u,.04,.48*v,2.05*u,.68,2.30*v,metal,'metal');
  box(g,.42*u,.12,.04*v,2.05*u,.66,2.46*v,customs);
  // Tilted brass reading plate (document surface).
  cylinder(g,.012,.60,1.85*u,.50,2.42*v,brass,'paint',.012*s,6);
  box(g,.40*u,.04,.28*v,2.25*u,.78,2.50*v,cream);
  g.children[g.children.length-1].rotation.z = -.25;
  box(g,.22*u,.015,.16*v,2.05*u,.685,2.30*v,cream); // open passport

  // 5) Staff-side customs booth: passenger stands in the lane (south), officer behind it (north).
  box(g,.72*u,.86,1.08*v,3.05*u,.43,2.35*v,body);
  box(g,.78*u,.09,1.18*v,3.05*u,.88,2.35*v,top);
  box(g,.80*u,.04,1.20*v,3.05*u,.93,2.35*v,metal,'metal');
  // Front customs panel between booth and passenger (the booth reads as staffed).
  box(g,.78*u,.42,.07*v,3.05*u,.48,2.90*v,customs);
  box(g,.04*u,.18,.06*v,3.50*u,.28,2.40*v,customs);
  // Counter extension with yellow safety strip and customs trim.
  box(g,.30*u,.54,.46*v,2.70*u,.27,2.35*v,body);
  box(g,.32*u,.08,.54*v,2.70*u,.57,2.35*v,top);
  box(g,.32*u,.035,.06*v,2.70*u,.59,2.60*v,yellow);

  // 6) Officer-facing monitor + keyboard + scanner + radio + pen holder.
  box(g,.10*u,.10,.26*v,3.02*u,.97,1.95*v,pc);
  box(g,.48*u,.33,.05*v,3.05*u,1.18,1.95*v,screen);
  g.children[g.children.length-1].rotation.y = Math.PI;
  light(g,3.05*u,1.18,1.86*v,glow,.07);
  box(g,.42*u,.035,.20*v,3.05*u,.955,2.12*v,pc);
  box(g,.25*u,.13,.22*v,2.75*u,.955,2.65*v,metal,'metal');
  box(g,.18*u,.03,.10*v,2.75*u,1.025,2.65*v,customs);
  box(g,.24*u,.06,.18*v,3.40*u,.95,2.65*v,cream);
  box(g,.06*u,.12,.04*v,2.55*u,1.10,2.62*v,pc); // radio
  cylinder(g,.012,.10,3.30*u,1.10,2.62*v,brass,'paint',.012*s,6); // pen

  // 7) Customs officer behind the desk (north / staff side).
  box(g,.27*u,.05,.22*v,3.05*u,.05,1.48*v,trouser);
  box(g,.27*u,.50,.22*v,3.05*u,.275,1.48*v,trouser);
  box(g,.08*u,.05,.12*v,2.89*u,.05,1.40*v,0x101515);
  box(g,.29*u,.05,.24*v,3.05*u,.52,1.48*v,0x111518);
  box(g,.37*u,.55,.24*v,3.05*u,.79,1.48*v,jacket);
  box(g,.40*u,.06,.28*v,3.05*u,1.32,1.42*v,jacket);
  box(g,.12*u,.42,.10*v,3.05*u,.80,1.59*v,cream);
  box(g,.18*u,.06,.20*v,3.05*u,1.42,1.46*v,customs);
  sphere(g,3.05*u,1.21,1.48*v,.13*s,.16,.13*s,skin);

  // 8) Staff rear cabinet with two drawer fronts, water bottle and clearance placard.
  box(g,.86*u,.78,.62*v,3.62*u,.39,1.16*v,body);
  box(g,.94*u,.07,.68*v,3.62*u,.78,1.16*v,top);
  box(g,.92*u,.04,.70*v,3.62*u,.44,1.16*v,metal,'metal');
  box(g,.76*u,.15,.56*v,3.65*u,.68,1.16*v,customs);
  box(g,.74*u,.08,.04*v,3.65*u,.55,1.40*v,metal,'metal');
  box(g,.74*u,.08,.04*v,3.65*u,.42,1.40*v,metal,'metal');
  box(g,.65*u,.82,.08*v,3.66*u,.95,.38*v,customs);
  label(g,'CLEARANCE',3.66*u,1.16,.43*v,2.6,'#f9fcf6');
  cylinder(g,.025,.04,3.50*u,1.05,.30*v,stop,'paint',.025*s,6);
  cylinder(g,.025,.04,3.66*u,1.05,.30*v,customs,'paint',.025*s,6);
  cylinder(g,.025,.04,3.78*u,1.05,.30*v,proceed,'paint',.025*s,6);
  light(g,3.66*u,1.05,.28*v,proceed,.04);
  cylinder(g,.04,.16,3.40*u,1.06,.40*v,0x66a9d9,'paint',.04*s,6);

  // 9) Exit-side gate AFTER the officer (asymmetric: green on exit, red on entry).
  //    Header bar with directional arrows + green proceed lamp.
  const gateZ = .74*v;
  box(g,1.40*u,.10,.40*v,2.45*u,1.78,gateZ,metal,'metal');
  box(g,1.30*u,.06,.36*v,2.45*u,1.74,gateZ,dark);
  label(g,'>',2.20*u,1.78,gateZ+.22*v,3.0,proceed);
  label(g,'>',2.70*u,1.78,gateZ+.22*v,3.0,proceed);
  cylinder(g,.04,.06,2.45*u,1.74,gateZ+.20*v,proceed,'paint',.04*s,6);
  light(g,2.45*u,1.76,gateZ+.20*v,glow,.05);
  // Two offset glass swing-style leaves with metal frames.
  box(g,.42*u,1.20,.04*v,1.84*u,.60,gateZ+.10*v,glassC,'glass');
  box(g,.46*u,.10,.06*v,1.84*u,.06,gateZ+.10*v,metal,'metal');
  box(g,.46*u,.10,.06*v,1.84*u,1.78,gateZ+.10*v,metal,'metal');
  box(g,.42*u,1.20,.04*v,3.06*u,.60,gateZ-.10*v,glassC,'glass');
  box(g,.46*u,.10,.06*v,3.06*u,.06,gateZ-.10*v,metal,'metal');
  box(g,.46*u,.10,.06*v,3.06*u,1.78,gateZ-.10*v,metal,'metal');
  // Outside posts.
  box(g,.06*u,1.40,.06*v,1.50*u,.70,gateZ-.10*v,metal,'metal');
  box(g,.06*u,1.40,.06*v,3.42*u,.70,gateZ-.10*v,metal,'metal');
  // Red STOP on the entry-facing post (left), green PROCEED on the exit-facing post (right).
  box(g,.12*u,.10,.09*v,1.60*u,1.09,gateZ,stop);
  cylinder(g,.05,.02,1.60*u,1.14,gateZ,stop,'paint',.05*s,6);
  box(g,.14*u,.14,.10*v,3.26*u,1.06,gateZ,proceed);
  cylinder(g,.06,.03,3.26*u,1.13,gateZ,proceed,'paint',.06*s,6);
  light(g,3.26*u,1.05,gateZ,proceed,.06);
  label(g,'EXIT',2.45*u,.075,.33*v,3.2,'#4f8b58',{ground:true});

  // 10) One passenger waiting at the document station + small rolling suitcase.
  box(g,.28*u,.05,.22*v,2.20*u,.05,2.92*v,0x2d2d33);
  box(g,.28*u,.50,.22*v,2.20*u,.275,2.92*v,0x2d2d33);
  box(g,.08*u,.05,.12*v,2.06*u,.05,2.86*v,0x1a1a1d);
  box(g,.38*u,.52,.24*v,2.20*u,.79,2.92*v,0x6b5a7c);
  box(g,.12*u,.30,.10*v,2.20*u,.82,3.02*v,cream);
  sphere(g,2.20*u,1.20,2.92*v,.13*s,.16,.13*s,skin);
  box(g,.22*u,.06,.20*v,2.20*u,1.42,2.92*v,0x2d2d33); // cap
  box(g,.28*u,.40,.18*v,1.70*u,.20,3.12*v,0x343b3e); // case (sunk below carpet surface)
  box(g,.10*u,.06,.06*v,1.70*u,.45,3.12*v,brass,'metal'); // handle
  cylinder(g,.03,.04,1.60*u,.05,3.12*v,0x101515,'paint',.03*s,8); // wheel
  cylinder(g,.03,.04,1.80*u,.05,3.12*v,0x101515,'paint',.03*s,8); // wheel
}
