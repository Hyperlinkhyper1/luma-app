function informationDesk(g,w,d){
  const u = w/5, v = d/4, x = w/2, s = Math.min(u,v);
  const body = 0xd8d3c6, cream = 0xe5e0d5, top = 0x454d50, base = 0x3b4347;
  const teal = 0x2a6d7a, tealL = 0x438996, metal = 0x8b9295, pc = 0x343b3e;
  const screen = 0x1b2e36, glow = 0x7fe0e8, info = 0x3976a8, warm = 0xfff0cf;

  // Floor pad + blue approach inlay. Passengers arrive from +z; staff stand at -z.
  box(g,4.8*u,.04,3.8*v,x,.02,2*v,body);
  box(g,2.6*u,.03,1.2*v,1.95*u,.035,2.75*v,info);

  // Partial rear wall + side fins (open island, not an enclosed box).
  box(g,3.2*u,2.30,.14*v,1.95*u,1.15,.30*v,cream);
  box(g,3.0*u,.85,.08*v,1.95*u,.425,.38*v,teal);
  box(g,.16*u,2.30,1.65*v,.43*u,1.15,1.05*v,body);
  box(g,.16*u,2.30,1.15*v,3.47*u,1.15,.80*v,body);
  // Two front columns carry the canopy while keeping the counter open.
  cylinder(g,.08*s,2.30,.55*u,1.15,1.90*v,metal,'metal',.08*s,8);
  cylinder(g,.08*s,2.30,3.35*u,1.15,1.90*v,metal,'metal',.08*s,8);

  // Canopy + blue trim + four-sided "i / INFORMATION" beacon.
  box(g,3.4*u,.14,1.90*v,1.95*u,2.34,1.15*v,cream);
  g.children[g.children.length-1].userData.roof = true;
  box(g,3.46*u,.06,1.96*v,1.95*u,2.27,1.15*v,info);
  g.children[g.children.length-1].userData.roof = true;
  light(g,1.25*u,2.25,1.30*v,warm,.12);
  light(g,2.65*u,2.25,1.30*v,warm,.12);
  box(g,.95*u,.48,.95*v,1.95*u,2.62,1.15*v,info);
  box(g,1.02*u,.05,1.02*v,1.95*u,2.875,1.15*v,base);
  g.children[g.children.length-1].userData.roof = true;
  // Geometric "i" glyph on the front + rear faces of the beacon, labels on sides.
  for (const szz of [1.64, .66]) {
    box(g,.11*u,.20,.03*v,1.95*u,2.54,szz*v,cream);
    box(g,.11*u,.07,.03*v,1.95*u,2.74,szz*v,cream);
  }
  label(g,'INFO',2.44*u,2.62,1.15*v,5,'#f9fcf6',{rotY:Math.PI/2});
  label(g,'INFO',1.46*u,2.62,1.15*v,5,'#f9fcf6',{rotY:-Math.PI/2});
  box(g,2.2*u,.20,.05*v,1.95*u,2.34,2.11*v,info);
  label(g,'INFORMATION',1.95*u,2.35,2.145*v,4.2,'#f9fcf6');
  light(g,1.95*u,2.62,1.68*v,glow,.10);

  // Main counter: two high staffed bays + a lower accessible bay at the left end.
  box(g,2.1*u,.92,.72*v,2.35*u,.46,1.72*v,body);
  box(g,2.0*u,.50,.06*v,2.35*u,.32,2.06*v,teal);
  box(g,2.2*u,.08,.82*v,2.35*u,.95,1.72*v,top);
  box(g,2.22*u,.03,.84*v,2.35*u,.995,1.72*v,metal,'metal');
  box(g,.85*u,.74,.72*v,.95*u,.37,1.72*v,body);
  box(g,.78*u,.40,.06*v,.95*u,.26,2.06*v,tealL);
  box(g,.90*u,.08,.80*v,.95*u,.77,1.72*v,top);
  // Subtle divider + brochure holder between the two staffed positions.
  box(g,.06*u,.24,.40*v,2.05*u,1.10,1.72*v,0xcfe0e2,'glass');
  box(g,.24*u,.18,.14*v,3.20*u,1.07,1.92*v,info);
  box(g,.20*u,.22,.04*v,3.20*u,1.13,1.92*v,cream);

  // Two staffed workstations (monitors face -z toward the employees).
  for (const wx of [1.55, 2.75]) {
    box(g,.46*u,.30,.04*v,wx*u,1.22,1.52*v,screen);
    g.children[g.children.length-1].rotation.y = Math.PI;
    box(g,.06*u,.18,.06*v,wx*u,1.06,1.52*v,pc);
    light(g,wx*u,1.22,1.46*v,glow,.07);
    box(g,.38*u,.03,.18*v,wx*u,1.00,1.66*v,pc);
    // Low-poly employee standing behind the counter at this position.
    box(g,.28*u,.52,.22*v,wx*u,.28,1.05*v,base);       // lower body
    box(g,.36*u,.48,.24*v,wx*u,.76,1.05*v,info);       // uniform jacket
    box(g,.12*u,.32,.10*v,wx*u,.80,1.16*v,cream);      // shirt/tie front
    sphere(g,wx*u,1.15,1.05*v,.13*s,.15,.13*s,0xd8b49a); // head
    box(g,.44*u,.12,.22*v,wx*u,.72,1.16*v,info);       // arms forward
  }

  // Shared staff rear console + printer + wall map panel.
  box(g,2.6*u,.82,.38*v,1.95*u,.41,.58*v,body);
  box(g,2.66*u,.06,.42*v,1.95*u,.84,.58*v,top);
  box(g,.36*u,.20,.26*v,2.15*u,.95,.58*v,metal,'metal');
  box(g,1.4*u,.75,.05*v,1.95*u,1.50,.40*v,screen);
  box(g,1.2*u,.55,.03*v,1.95*u,1.50,.43*v,tealL);
  label(g,'TERMINAL MAP',1.95*u,1.72,.455*v,2.8,'#f9fcf6');

  // Separate self-service information kiosk to the right (faces +z toward passengers).
  box(g,.72*u,.08,.72*v,4.25*u,.06,2.15*v,base);
  box(g,.54*u,1.88,.30*v,4.25*u,1.02,2.05*v,body);
  box(g,.58*u,.08,.36*v,4.25*u,1.98,2.05*v,info);
  box(g,.46*u,.78,.04*v,4.25*u,1.28,2.21*v,screen);
  light(g,4.25*u,1.28,2.24*v,glow,.12);
  box(g,.42*u,.06,.16*v,4.25*u,.84,2.24*v,top);
  label(g,'INFO',4.25*u,1.55,2.24*v,4,'#7fe0e8');
  label(g,'FLIGHTS  MAP',4.25*u,1.35,2.24*v,2.4,'#f9fcf6');
  label(g,'TOUCH',4.25*u,1.08,2.24*v,2.6,'#7fe0e8');
}
