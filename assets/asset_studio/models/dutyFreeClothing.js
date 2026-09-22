function dutyFreeClothing(g,w,d){
  const u = w/8, v = d/6, x = w/2, s = Math.min(u,v);
  const shell = 0xe5e0d5, wall = 0xd8d3c6, dark = 0x343b3e, steel = 0x8b9295;
  const teal = 0x2a6d7a, warm = 0xffe2a8, screen = 0x7fe0e8, pane = 0xbfe3ea;
  const cloth = [0xb4553f,0x3f5e78,0x7a8f6b,0xc9a86a,0x8d6a93,0xd8cfc0,0x2f3a44,0xa8564e];

  // Shell: floor, three closed sides, storefront left open on +z.
  box(g,7.9*u,.04,5.9*v,x,.02,3*v,wall);
  box(g,2.3*u,.05,.55*v,4*u,.025,5.55*v,teal);
  box(g,7.9*u,3.0,.14*v,x,1.5,.12*v,shell);
  box(g,.14*u,3.0,5.9*v,.12*u,1.5,3*v,wall);
  box(g,.14*u,3.0,5.9*v,w-.12*u,1.5,3*v,wall);
  box(g,7.6*u,.10,.05*v,x,2.55,.21*v,teal);

  // Storefront: corner pillars, deep fascia, lit sign band.
  box(g,.5*u,3.10,.5*v,.32*u,1.55,5.70*v,shell);
  box(g,.5*u,3.10,.5*v,w-.32*u,1.55,5.70*v,shell);
  box(g,7.9*u,.65,.45*v,x,2.775,5.72*v,shell);
  box(g,7.9*u,.05,.54*v,x,3.125,5.72*v,teal);
  g.children[g.children.length-1].userData.roof = true;
  box(g,3.0*u,.44,.05*v,x,2.80,5.945*v,dark);
  label(g,'AERIA',x,2.88,5.985*v,11,'#f9fcf6');
  label(g,'DUTY FREE FASHION',x,2.63,5.985*v,4,'#9fd4de');
  light(g,1.5*u,2.80,5.88*v,warm,.16);
  light(g,w-1.5*u,2.80,5.88*v,warm,.16);

  // Two glazed window bays flanking a 2.3 m walk-in entrance.
  for (const px of [1.70*u, w-1.70*u]) {
    box(g,2.3*u,2.00,.06*v,px,1.42,5.86*v,pane,'glass');
    box(g,2.3*u,.42,.20*v,px,.21,5.86*v,dark);
    box(g,2.2*u,.26,1.05*v,px,.15,5.20*v,shell);
  }

  // Mannequin forms staged on the window platforms.
  for (const [mx,mz,tc,bc] of [
    [1.12*u,5.02*v,0x3f5e78,0x2f3a44],
    [2.28*u,5.32*v,0xc9a86a,0xd8cfc0],
    [w-1.12*u,5.02*v,0xb4553f,0x2f3a44],
    [w-2.28*u,5.32*v,0x7a8f6b,0xd8cfc0]
  ]) {
    cylinder(g,.19*s,.05,mx,.305,mz,steel,'metal',.19*s,10);
    box(g,.30*u,.72,.24*v,mx,.69,mz,bc);
    box(g,.44*u,.60,.28*v,mx,1.35,mz,tc);
    sphere(g,mx,1.76,mz,.115*u,.145,.115*v,shell);
  }

  // Back wall: hanging rail under a folded stock shelf.
  box(g,3.4*u,.07,.34*v,4.9*u,2.30,.40*v,shell);
  box(g,3.4*u,.05,.05*v,4.9*u,1.92,.42*v,steel,'metal');
  for (let i = 0; i < 7; i++) {
    const gh = .70+((i*5)%3)*.09;
    box(g,(.26+((i*7)%3)*.05)*u,gh,.24*v,(3.45+i*.48)*u,1.90-gh/2,.44*v,cloth[(i*3)%8]);
  }
  for (let i = 0; i < 3; i++) {
    box(g,.52*u,.16,.26*v,(3.85+i*1.05)*u,2.415,.40*v,cloth[(i*2+5)%8]);
  }
  light(g,4.9*u,2.05,.75*v,warm,.18);

  // Right wall: shelving bay of folded merchandise.
  box(g,.10*u,2.10,2.80*v,7.765*u,1.05,2.30*v,shell);
  const shelfY = [.75,1.30,1.85];
  for (const yy of shelfY) box(g,.56*u,.06,2.60*v,7.45*u,yy,2.30*v,shell);
  for (let i = 0; i < 3; i++) {
    box(g,.42*u,.18,.55*v,7.45*u,shelfY[i]+.12,1.55*v,cloth[(i*2)%8]);
    box(g,.42*u,.18,.55*v,7.45*u,shelfY[i]+.12,3.05*v,cloth[(i*2+3)%8]);
  }
  light(g,7.40*u,2.18,2.30*v,warm,.16);

  // Straight rail rack with garments of mixed width and length.
  for (const ox of [-.92,.92]) {
    cylinder(g,.045*s,1.35,(2.20+ox)*u,.675,3.30*v,steel,'metal',.045*s,8);
    box(g,.46*u,.05,.46*v,(2.20+ox)*u,.025,3.30*v,dark);
  }
  box(g,1.94*u,.05,.06*v,2.20*u,1.36,3.30*v,steel,'metal');
  for (let i = 0; i < 7; i++) {
    const gh = .66+((i*4)%3)*.08;
    box(g,(.24+((i*5)%2)*.06)*u,gh,.30*v,(1.36+i*.28)*u,1.34-gh/2,3.30*v,cloth[(i*5)%8]);
  }

  // Round rack: centre post, ring rail, garments turned to the circle.
  cylinder(g,.32*s,.06,5.95*u,.03,3.45*v,dark,'paint',.32*s,10);
  cylinder(g,.05*s,1.28,5.95*u,.64,3.45*v,steel,'metal',.05*s,8);
  cylinder(g,.60*s,.05,5.95*u,1.28,3.45*v,steel,'metal',.60*s,12);
  for (let i = 0; i < 6; i++) {
    const a = i*Math.PI/3, gh = .62+(i%3)*.07;
    box(g,.30*u,gh,.22*v,5.95*u+Math.cos(a)*.52*s,1.26-gh/2,3.45*v+Math.sin(a)*.52*s,cloth[(i*2+1)%8]);
    g.children[g.children.length-1].rotation.y = -a;
  }

  // Central display table with stacked folded goods.
  box(g,1.30*u,.62,.85*v,4.05*u,.31,2.15*v,shell);
  box(g,1.62*u,.08,1.06*v,4.05*u,.66,2.15*v,dark);
  box(g,1.34*u,.06,.89*v,4.05*u,.60,2.15*v,teal);
  for (let i = 0; i < 4; i++) {
    const hh = .15+(i%2)*.05;
    box(g,.42*u,hh,.40*v,(3.70+(i%2)*.70)*u,.70+hh/2,(1.86+(i<2?0:.58))*v,cloth[(i*3+2)%8]);
  }

  // Checkout: customer counter, till, and staff-side back unit.
  box(g,2.20*u,.92,.72*v,1.55*u,.46,1.95*v,shell);
  box(g,2.32*u,.08,.82*v,1.55*u,.96,1.95*v,dark);
  box(g,2.05*u,.46,.05*v,1.55*u,.50,2.30*v,teal);
  box(g,.34*u,.22,.28*v,2.30*u,1.11,1.95*v,dark);
  light(g,2.30*u,1.16,2.10*v,screen,.13);
  box(g,2.30*u,1.05,.38*v,1.55*u,.525,.58*v,wall);
  box(g,2.40*u,.06,.46*v,1.55*u,1.08,.58*v,dark);
  for (let i = 0; i < 3; i++) {
    box(g,.50*u,.17,.30*v,(.85+i*.70)*u,1.195,.58*v,cloth[(i*4+1)%8]);
  }
  label(g,'PAY HERE',1.55*u,1.55,.80*v,3.4,'#9fd4de');

  // Fitting mirror on the left wall.
  box(g,.05*u,1.70,1.10*v,.215*u,1.35,4.20*v,pane,'glass');

  // Ceiling beams carrying the warm retail downlights.
  box(g,5.80*u,.10,.22*v,4.00*u,2.88,1.70*v,shell);
  g.children[g.children.length-1].userData.roof = true;
  box(g,5.80*u,.10,.22*v,4.00*u,2.88,3.50*v,shell);
  g.children[g.children.length-1].userData.roof = true;
  light(g,2.60*u,2.79,1.70*v,warm,.20);
  light(g,5.40*u,2.79,3.50*v,warm,.20);
}
