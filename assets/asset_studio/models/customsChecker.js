function customsChecker(g,w,d){
  const u = w/6, v = d/5, x = w/2, z = d/2, s = Math.min(u,v);
  const body = 0xd8d3c6, cream = 0xe5e0d5, top = 0x454d50, dark = 0x3b4347;
  const metal = 0x8b9295, green = 0x315d50, green2 = 0x47704f, pc = 0x343b3e;
  const screen = 0x1b2e36, glow = 0x7fe0e8, post = 0x737b7e, inspect = 0x9ba2a3;
  const yellow = 0xe0b53f, red = 0xc95a50, ok = 0x4f8b58, glassC = 0xcfe0e2;

  // Terminal floor. Public arrives from +z into two painted channels.
  box(g,5.85*u,.04,4.85*v,x,.02,z,cream);

  // Painted lane markings: green = nothing to declare, red = goods to declare.
  box(g,.14*u,.012,3.40*v,1.05*u,.028,2.80*v,ok);
  box(g,.14*u,.012,3.40*v,2.35*u,.028,2.80*v,ok);
  box(g,1.45*u,.012,.14*v,1.70*u,.028,4.58*v,ok);
  box(g,.14*u,.012,3.40*v,3.95*u,.028,2.80*v,red);
  box(g,.14*u,.012,3.40*v,5.35*u,.028,2.80*v,red);
  box(g,1.55*u,.012,.14*v,4.65*u,.028,4.58*v,red);
  box(g,.10*u,.012,3.20*v,3.15*u,.025,2.95*v,green);

  // Rear backdrop wall with a green customs band and metal capping.
  box(g,5.75*u,2.30,.14*v,x,1.15,.22*v,body);
  box(g,5.60*u,.72,.07*v,x,.36,.31*v,green);
  box(g,5.70*u,.06,.11*v,x,2.28,.27*v,metal,'metal');

  // Long staffed counter across the green lane and the officer position.
  box(g,3.30*u,.85,.70*v,2.25*u,.425,1.52*v,body);
  box(g,3.45*u,.09,.80*v,2.25*u,.885,1.52*v,top);
  box(g,3.47*u,.035,.82*v,2.25*u,.935,1.52*v,metal,'metal');
  // Colour-coded desk fronts: green, officer, declaration.
  box(g,1.05*u,.52,.06*v,1.25*u,.45,1.91*v,green2);
  box(g,.90*u,.52,.06*v,2.25*u,.45,1.91*v,green);
  box(g,.95*u,.52,.06*v,3.30*u,.45,1.91*v,yellow);
  // Yellow/black hazard base strip along the passenger face.
  box(g,3.40*u,.13,.06*v,2.25*u,.115,1.89*v,yellow);

  // Officer workstation: monitor turned to the staff side, keyboard, scanner, tray.
  box(g,.52*u,.34,.05*v,2.25*u,1.20,1.28*v,screen);
  g.children[g.children.length-1].rotation.y = Math.PI;
  box(g,.07*u,.20,.07*v,2.25*u,1.05,1.28*v,pc);
  light(g,2.25*u,1.20,1.21*v,glow,.08);
  box(g,.44*u,.03,.20*v,2.25*u,.97,1.72*v,pc);
  box(g,.26*u,.17,.20*v,1.40*u,.97,1.72*v,metal,'metal');
  box(g,.20*u,.03,.09*v,1.40*u,1.055,1.72*v,green);
  box(g,.24*u,.08,.18*v,3.10*u,.965,1.72*v,cream);

  // Customs officer standing between the counter and the inspection table.
  box(g,.27*u,.55,.22*v,2.75*u,.275,.95*v,dark);
  box(g,.37*u,.54,.24*v,2.75*u,.79,.95*v,green);
  box(g,.12*u,.42,.10*v,2.75*u,.80,1.055*v,cream);
  sphere(g,2.75*u,1.20,.95*v,.13*s,.15,.13*s,0xd8b49a);
  box(g,.42*u,.10,.16*v,2.75*u,1.05,1.11*v,green);

  // Low divider wall separating the two declaration channels.
  box(g,.09*u,1.15,2.10*v,3.15*u,1.05,3.35*v,green);
  box(g,.13*u,.06,2.16*v,3.15*u,1.63,3.35*v,metal,'metal');
  box(g,.13*u,.06,.16*v,3.15*u,1.11,4.40*v,metal,'metal');

  // Manual baggage inspection table inside the red declaration lane.
  box(g,1.55*u,.70,.72*v,4.65*u,.35,2.95*v,inspect,'metal');
  box(g,1.75*u,.12,.90*v,4.65*u,.70,2.95*v,inspect,'metal');
  box(g,1.65*u,.03,.80*v,4.65*u,.77,2.95*v,green2);
  box(g,1.45*u,.09,.52*v,4.65*u,.185,2.95*v,dark);
  for (const tx of [3.90,5.40]) {
    box(g,.06*u,.20,.86*v,tx*u,.85,2.95*v,metal,'metal');
  }
  // Yellow edge trim + under-shelf inspection panel.
  box(g,1.70*u,.05,.06*v,4.65*u,.765,3.39*v,yellow);
  box(g,.26*u,.20,.06*v,5.42*u,.875,3.30*v,screen);
  label(g,'INSPECT',5.42*u,.88,3.34*v,2.4,'#7fe0e8');

  // Angled inspection lamp on a cantilever arm over the table.
  box(g,.05*u,.62,.05*v,5.52*u,1.03,2.32*v,metal,'metal');
  box(g,.52*u,.05,.05*v,5.28*u,1.31,2.32*v,metal,'metal');
  light(g,5.00*u,1.27,2.32*v,0xfff0cf,.11);

  // Open suitcase under examination, lid propped against the base.
  box(g,.66*u,.12,.45*v,4.52*u,.79,2.95*v,0x3f5968);
  box(g,.62*u,.40,.08*v,4.52*u,1.02,2.70*v,0x3f5968);
  box(g,.54*u,.05,.38*v,4.52*u,.865,2.95*v,0xd8d3c6);

  // Waiting luggage in the red lane and a bag left at the channel entry.
  box(g,.48*u,.34,.40*v,4.62*u,.18,4.10*v,0x73544c);
  box(g,.10*u,.08,.17*v,4.62*u,.385,4.10*v,metal,'metal');
  box(g,.36*u,.28,.30*v,5.30*u,.15,4.20*v,0x6b5a7c);

  // Overhead gantry carrying the customs identity and the channel signs.
  for (const px of [.62,5.38]) {
    cylinder(g,.09*s,1.72,px*u,1.84,1.52*v,metal,'metal',.09*s,10);
  }
  box(g,5.00*u,.16,.16*v,x,2.74,1.52*v,dark);
  g.children[g.children.length-1].userData.roof = true;
  box(g,2.90*u,.50,.07*v,2.25*u,2.62,1.63*v,green);
  label(g,'CUSTOMS',2.25*u,2.72,1.68*v,6.5,'#f9fcf6');
  label(g,'DOUANE',2.25*u,2.49,1.68*v,3.4,'#e5e0d5');
  box(g,1.10*u,.36,.05*v,1.70*u,2.47,2.90*v,ok);
  label(g,'NOTHING TO DECLARE',1.70*u,2.49,2.94*v,2.2,'#f9fcf6');
  box(g,1.10*u,.36,.05*v,4.65*u,2.47,2.90*v,red);
  label(g,'GOODS TO DECLARE',4.65*u,2.49,2.94*v,2.2,'#f9fcf6');
  light(g,2.25*u,2.50,1.70*v,glow,.10);
  light(g,1.70*u,2.47,2.955*v,glow,.07);
  light(g,4.65*u,2.47,2.955*v,glow,.07);

  // Short entry barrier defining the controlled approach, open between lanes.
  for (const px of [.40,2.95,5.60]) {
    cylinder(g,.15*s,.05,px*u,.05,4.72*v,metal,'metal',.17*s,10);
    cylinder(g,.045*s,.84,px*u,.48,4.72*v,post,'metal',.045*s,8);
  }
  box(g,1.05*u,.045,.03*v,1.65*u,.78,4.72*v,green);
  box(g,.03*u,.045,1.15*v,2.95*u,.78,4.18*v,green);
  label(g,'CUSTOMS',2.00*u,.05,4.30*v,3.4,'#315d50',{ground:true});

  // Passenger waiting in the green channel with a small carry-on.
  box(g,.28*u,.54,.22*v,1.90*u,.27,3.70*v,0x343b3e);
  box(g,.38*u,.54,.24*v,1.90*u,.79,3.70*v,0x6b5a7c);
  sphere(g,1.90*u,1.20,3.70*v,.13*s,.16,.13*s,0xd8b49a);
  box(g,.40*u,.10,.16*v,1.90*u,1.05,3.56*v,0x6b5a7c);
  box(g,.26*u,.30,.26*v,1.36*u,.16,3.86*v,0x343b3e);

  // Rear-of-house cabinet, printer and a document/brochure panel.
  box(g,2.30*u,.80,.42*v,1.85*u,.40,.60*v,body);
  box(g,2.38*u,.07,.48*v,1.85*u,.82,.60*v,top);
  box(g,.42*u,.22,.28*v,.95*u,.92,.60*v,metal,'metal');
  box(g,.06*u,1.20,.70*v,.28*u,1.20,3.40*v,glassC,'glass');
  box(g,.10*u,1.28,.76*v,.24*u,1.19,3.40*v,metal,'metal');
}
