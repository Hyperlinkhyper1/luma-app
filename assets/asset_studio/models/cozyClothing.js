function cozyClothing(g,w,d){
  const u = w/8, v = d/6, x = w/2, s = Math.min(u,v);
  // Dark and elegant palette: deep espresso floor, charcoal walls, smoked ash timber, burnished brass accents, dark smoked glass
  const floorWood = 0x221c18, timber = 0x2e2520, wallDark = 0x282523;
  const backPanel = 0x1f1c1a, dark = 0x181513, brass = 0xc89d4c;
  const warm = 0xffc882, pane = 0x3a484c;
  // Deep luxurious apparel tones: midnight navy, burgundy/bordeaux, olive noir, camel/whiskey, charcoal slate, aubergine
  const cloth = [0x501c22,0x1b2836,0x323a2a,0x825a2e,0x3e2840,0x2b2f34,0x684226,0x1d2228];

  // Shell: dark espresso wood floor, deep bordeaux runner, charcoal enclosure (zero stark white)
  box(g,7.9*u,.04,5.9*v,x,.02,3*v,floorWood);
  box(g,1.6*u,.02,2.8*v,x,.045,4.0*v,0x3a151b);
  box(g,1.8*u,.02,1.4*v,1.1*u,.045,4.15*v,0x1f262e);
  box(g,7.9*u,3.0,.14*v,x,1.5,.12*v,backPanel);
  box(g,.14*u,3.0,5.9*v,.12*u,1.5,3*v,wallDark);
  box(g,.14*u,3.0,5.9*v,w-.12*u,1.5,3*v,wallDark);
  box(g,7.6*u,.9,.06*v,x,.45,.21*v,timber);
  box(g,7.6*u,.12,.08*v,x,2.5,.22*v,brass,'metal');

  // Storefront: deep espresso pillars, smoked fascia, brushed brass trim, minimalist backlit signage
  box(g,.5*u,3.10,.5*v,.32*u,1.55,5.70*v,timber);
  box(g,.5*u,3.10,.5*v,w-.32*u,1.55,5.70*v,timber);
  box(g,7.9*u,.65,.45*v,x,2.775,5.72*v,timber);
  box(g,7.9*u,.06,.48*v,x,2.44,5.72*v,brass,'metal');
  box(g,7.9*u,.05,.54*v,x,3.12,5.72*v,dark);
  g.children[g.children.length-1].userData.roof = true;
  box(g,3.2*u,.44,.05*v,x,2.80,5.945*v,dark);
  label(g,'NOIR & CO.',x,2.88,5.985*v,9,'#d4af37');
  label(g,'ATELIER - PRIVATE COLLECTION',x,2.63,5.985*v,3.2,'#c89d4c');
  light(g,1.5*u,2.80,5.88*v,warm,.16);
  light(g,w-1.5*u,2.80,5.88*v,warm,.16);

  // Two smoked-glass display bays flanking a 2.3 m walk-in entrance
  for (const px of [1.70*u, w-1.70*u]) {
    box(g,2.3*u,2.00,.06*v,px,1.42,5.86*v,pane,'glass');
    box(g,2.3*u,.42,.20*v,px,.23,5.86*v,timber);
    box(g,2.2*u,.26,1.05*v,px,.15,5.20*v,wallDark);
    box(g,2.24*u,.04,1.09*v,px,.295,5.20*v,brass,'metal');
  }

  // Elegant mannequins in dark tailoring & cashmere on dark timber pedestals
  for (const [mx,mz,tc,bc,sc] of [
    [1.12*u,5.02*v,0x1b2836,0x181513,0x825a2e],
    [2.28*u,5.32*v,0x501c22,0x221c18,0],
    [w-1.12*u,5.02*v,0x323a2a,0x181513,0xc89d4c],
    [w-2.28*u,5.32*v,0x3e2840,0x221c18,0]
  ]) {
    cylinder(g,.19*s,.05,mx,.335,mz,brass,'metal',.19*s,10);
    box(g,.30*u,.72,.24*v,mx,.715,mz,bc);
    box(g,.44*u,.60,.28*v,mx,1.365,mz,tc);
    sphere(g,mx,1.80,mz,.115*u,.145,.115*v,dark);
    if (sc) box(g,.30*u,.10,.30*v,mx,1.62,mz,sc);
  }

  // Back wall: burnished brass rail of dark luxury garments under timber shelf
  box(g,3.4*u,.07,.34*v,4.9*u,2.30,.34*v,timber);
  box(g,3.4*u,.05,.05*v,4.9*u,1.92,.42*v,brass,'metal');
  box(g,.06*u,.06,.25*v,4.9*u,1.92,.30*v,timber);
  for (let i = 0; i < 5; i++) {
    const gh = .60+((i*5)%3)*.08;
    box(g,(.30+((i*7)%3)*.05)*u,gh,.28*v,(3.70+i*.55)*u,1.90-gh/2,.44*v,cloth[(i*3)%8]);
  }
  for (let i = 0; i < 3; i++) {
    box(g,.52*u,.16,.26*v,(3.85+i*1.05)*u,2.41,.34*v,cloth[(i*2+5)%8]);
  }
  light(g,4.9*u,2.05,.75*v,warm,.18);

  // Right wall: dark timber shelving bay of folded knitwear
  box(g,.10*u,2.10,2.80*v,7.765*u,1.05,2.30*v,timber);
  const shelfY = [.75,1.30,1.85];
  for (const yy of shelfY) box(g,.56*u,.06,2.60*v,7.45*u,yy,2.30*v,timber);
  for (let i = 0; i < 2; i++) {
    box(g,.42*u,.18,.55*v,7.45*u,shelfY[i]+.11,1.55*v,cloth[(i*2)%8]);
    box(g,.42*u,.18,.55*v,7.45*u,shelfY[i]+.11,3.05*v,cloth[(i*2+3)%8]);
  }
  light(g,7.40*u,2.18,2.30*v,warm,.16);

  // Straight brass rack with tailored overcoats
  for (const ox of [-.92,.92]) {
    cylinder(g,.05*s,1.35,(2.20+ox)*u,.675,3.30*v,brass,'metal',.05*s,8);
    box(g,.46*u,.05,.46*v,(2.20+ox)*u,.06,3.30*v,dark);
  }
  box(g,1.94*u,.06,.06*v,2.20*u,1.36,3.30*v,brass,'metal');
  for (let i = 0; i < 5; i++) {
    const gh = .58+((i*4)%3)*.08;
    box(g,(.28+((i*5)%2)*.06)*u,gh,.30*v,(1.50+i*.35)*u,1.34-gh/2,3.30*v,cloth[(i*5)%8]);
  }

  // Round rack: brass post and ring, dark evening-wear selection
  cylinder(g,.32*s,.06,5.95*u,.065,3.45*v,dark,'paint',.32*s,10);
  cylinder(g,.05*s,1.28,5.95*u,.70,3.45*v,brass,'metal',.05*s,8);
  cylinder(g,.60*s,.05,5.95*u,1.32,3.45*v,brass,'metal',.60*s,12);
  for (let i = 0; i < 5; i++) {
    const a = i*Math.PI*2/5, gh = .56+(i%3)*.07;
    box(g,.32*u,gh,.24*v,5.95*u+Math.cos(a)*.52*s,1.30-gh/2,3.45*v+Math.sin(a)*.52*s,cloth[(i*2+1)%8]);
    g.children[g.children.length-1].rotation.y = -a;
  }

  // Central harvest table: smoked ash timber with brass reveal & dark wool folds
  box(g,1.30*u,.62,.85*v,4.05*u,.34,2.15*v,timber);
  box(g,1.62*u,.08,1.06*v,4.05*u,.68,2.15*v,dark);
  box(g,1.34*u,.06,.89*v,4.05*u,.615,2.15*v,brass,'metal');
  for (let i = 0; i < 2; i++) {
    const hh = .15+i*.05;
    box(g,.42*u,hh,.40*v,(3.70+i*.70)*u,.71+hh/2,2.0*v,cloth[(i*3+2)%8]);
  }
  cylinder(g,.28*s,.35,3.0*u,.21,1.2*v,timber,'paint',.24*s,10);

  // Checkout: smoked timber counter, marble-dark top, brushed brass reveal & till
  box(g,2.20*u,.92,.72*v,1.55*u,.48,1.95*v,timber);
  box(g,2.32*u,.08,.82*v,1.55*u,.97,1.95*v,dark);
  box(g,2.05*u,.10,.03*v,1.55*u,.70,2.32*v,brass,'metal');
  box(g,.34*u,.22,.28*v,2.30*u,1.11,1.95*v,dark);
  light(g,2.30*u,1.20,2.10*v,warm,.13);
  box(g,2.30*u,1.05,.38*v,1.55*u,.545,.58*v,wallDark);
  box(g,2.40*u,.06,.46*v,1.55*u,1.09,.58*v,dark);
  for (let i = 0; i < 2; i++) {
    box(g,.50*u,.17,.30*v,(1.05+i*.80)*u,1.195,.58*v,cloth[(i*4+1)%8]);
  }
  label(g,'CONCIERGE',1.55*u,1.55,.80*v,3.4,'#c89d4c');

  // Intimate lounge corner: deep velvet armchairs (bordeaux & midnight navy) with brass side lamp
  box(g,.65*u,.38,.60*v,.75*u,.24,3.80*v,0x42171d);
  box(g,.18*u,.65,.60*v,.51*u,.55,3.80*v,0x42171d);
  box(g,.65*u,.38,.60*v,.75*u,.24,4.50*v,0x1b2836);
  box(g,.18*u,.65,.60*v,.51*u,.55,4.50*v,0x1b2836);
  cylinder(g,.22*s,.45,.85*u,.265,4.15*v,timber,'paint',.22*s,10);
  cylinder(g,.06*s,.10,.85*u,.53,4.15*v,brass,'metal',.14*s,8);
  light(g,.85*u,.60,4.15*v,warm,.10);

  // Dark timber-framed fitting mirror on the left wall with bronze reflection tint
  box(g,.08*u,1.80,1.20*v,.22*u,1.35,2.90*v,timber);
  box(g,.04*u,1.70,1.10*v,.26*u,1.35,2.90*v,pane,'glass');

  // Smoked timber ceiling beams carrying warm brass pendant downlights
  box(g,5.80*u,.10,.22*v,4.00*u,2.88,1.70*v,timber);
  g.children[g.children.length-1].userData.roof = true;
  box(g,5.80*u,.10,.22*v,4.00*u,2.88,3.50*v,timber);
  g.children[g.children.length-1].userData.roof = true;
  for (const [lx,lz] of [[4.05,2.15],[2.20,3.30],[5.95,3.45]]) {
    cylinder(g,.02*s,.25,lx*u,2.72,lz*v,dark,'paint',.02*s,6);
    cylinder(g,.06*s,.16,lx*u,2.55,lz*v,brass,'metal',.18*s,10);
    light(g,lx*u,2.48,lz*v,warm,.11);
  }
}
