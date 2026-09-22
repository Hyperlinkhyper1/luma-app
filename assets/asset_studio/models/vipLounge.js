function vipLounge(g,w,d){
  const u = w/8, v = d/6, x = w/2, s = Math.min(u,v);
  const floorWood = 0x221c17, walnut = 0x2b211a, charcoal = 0x1c1918;
  const darkWall = 0x25201d, brass = 0xc59a4a, bronze = 0x7a5b32;
  const bordeaux = 0x48151b, navy = 0x162332, cognac = 0x6a3f22;
  const warm = 0xffc882, glassTint = 0x273438, screenGlow = 0x7fe0e8;

  // 1. Foundation: dark smoked walnut parquet floor & luxury plush area rugs (minimal white)
  box(g,7.9*u,.04,5.9*v,x,.02,3*v,floorWood);
  box(g,3.5*u,.02,3.1*v,2.6*u,.045,3.2*v,0x331217); // deep bordeaux salon rug
  box(g,2.2*u,.02,2.8*v,6.4*u,.045,2.7*v,0x121c27); // midnight navy lounge rug

  // 2. Architectural shell: charcoal acoustic panels, walnut wainscot & brass reveal trim
  box(g,7.9*u,3.0,.14*v,x,1.5,.12*v,charcoal);
  box(g,.14*u,3.0,5.9*v,.12*u,1.5,3*v,darkWall);
  box(g,.14*u,3.0,5.9*v,w-.12*u,1.5,3*v,darkWall);
  box(g,7.6*u,1.1,.06*v,x,.55,.21*v,walnut);
  box(g,7.6*u,.08,.08*v,x,1.12,.22*v,brass,'metal');
  box(g,7.6*u,.08,.08*v,x,2.60,.22*v,brass,'metal');

  // 3. Facade & VIP Entrance: walnut portal, brass frieze, backlit signage
  box(g,.5*u,3.10,.5*v,.32*u,1.55,5.70*v,walnut);
  box(g,.5*u,3.10,.5*v,w-.32*u,1.55,5.70*v,walnut);
  box(g,7.9*u,.65,.45*v,x,2.775,5.72*v,walnut);
  box(g,7.9*u,.06,.48*v,x,2.44,5.72*v,brass,'metal');
  box(g,7.9*u,.05,.54*v,x,3.12,5.72*v,charcoal);
  g.children[g.children.length-1].userData.roof = true;

  // Storefront Signage
  box(g,3.4*u,.44,.05*v,x,2.80,5.945*v,charcoal);
  label(g,'VIP LOUNGE',x,2.88,5.985*v,10,'#d4af37');
  label(g,'FIRST CLASS & PRIVILEGE CLUB',x,2.63,5.985*v,3.3,'#c59a4a');
  light(g,1.5*u,2.80,5.88*v,warm,.16);
  light(g,w-1.5*u,2.80,5.88*v,warm,.16);

  // Smoked glass facade partitions with dark timber & brass framing
  for (const px of [1.60*u, w-1.60*u]) {
    box(g,2.1*u,2.00,.06*v,px,1.42,5.86*v,glassTint,'glass');
    box(g,2.1*u,.42,.20*v,px,.23,5.86*v,walnut);
    box(g,2.14*u,.04,.22*v,px,.45,5.86*v,brass,'metal');
  }

  // 4. Concierge / Check-in Desk (right inside entrance at left)
  box(g,1.9*u,.95,.65*v,1.5*u,.50,4.8*v,walnut);
  box(g,2.0*u,.07,.72*v,1.5*u,.99,4.8*v,charcoal);
  box(g,1.8*u,.10,.03*v,1.5*u,.72,5.14*v,brass,'metal');
  box(g,.34*u,.22,.28*v,2.0*u,1.13,4.8*v,charcoal);
  light(g,2.0*u,1.22,4.95*v,screenGlow,.12);
  label(g,'CONCIERGE',1.5*u,1.50,4.8*v,3.2,'#c59a4a');

  // 5. Main Conversation Salon: Velvet Chesterfield sofa, leather club chairs & marble table
  // Chesterfield 3-seater sofa (deep bordeaux)
  box(g,2.5*u,.42,.85*v,2.6*u,.24,2.2*v,bordeaux);
  box(g,2.5*u,.45,.30*v,2.6*u,.64,1.85*v,bordeaux);
  box(g,.35*u,.38,.90*v,1.25*u,.60,2.2*v,bordeaux);
  box(g,.35*u,.38,.90*v,3.95*u,.60,2.2*v,bordeaux);
  box(g,2.6*u,.06,.90*v,2.6*u,.04,2.2*v,brass,'metal'); // brass sofa base plinth

  // Two cognac leather club armchairs opposite the sofa
  for (const [cx,cz] of [[1.7*u,3.8*v],[3.5*u,3.8*v]]) {
    box(g,.75*u,.38,.75*v,cx,.22,cz,cognac);
    box(g,.75*u,.45,.25*v,cx,.60,cz+.35*v,cognac);
    box(g,.20*u,.32,.80*v,cx-.40*u,.50,cz,cognac);
    box(g,.20*u,.32,.80*v,cx+.40*u,.50,cz,cognac);
    cylinder(g,.04*s,.12,cx-.35*u,.06,cz-.30*v,brass,'metal',.04*s,6);
    cylinder(g,.04*s,.12,cx+.35*u,.06,cz-.30*v,brass,'metal',.04*s,6);
  }

  // Low dark marble coffee table
  box(g,1.4*u,.32,.85*v,2.6*u,.18,3.0*v,charcoal);
  box(g,1.5*u,.05,.95*v,2.6*u,.36,3.0*v,0x171514);
  box(g,1.38*u,.02,.83*v,2.6*u,.38,3.0*v,brass,'metal');
  // Decanter & two crystal tumblers on brass tray
  cylinder(g,.07*s,.18,2.7*u,.47,3.0*v,0x9db2b8,'glass',.04*s,8);
  cylinder(g,.03*s,.08,2.5*u,.42,3.1*v,0x9db2b8,'glass',.03*s,6);
  cylinder(g,.03*s,.08,2.85*u,.42,3.1*v,0x9db2b8,'glass',.03*s,6);

  // 6. Luxury Cocktail & Refreshment Bar (rear-right)
  // Back bar structure with liquor bottles & warm LED uplight
  box(g,2.6*u,2.1,.25*v,6.4*u,1.25,.35*v,walnut);
  box(g,2.5*u,.04,.28*v,6.4*u,1.05,.35*v,charcoal);
  box(g,2.5*u,.04,.28*v,6.4*u,1.50,.35*v,charcoal);
  box(g,2.5*u,.04,.28*v,6.4*u,1.95,.35*v,charcoal);
  box(g,2.5*u,.03,.03*v,6.4*u,1.53,.47*v,brass,'metal');
  box(g,2.5*u,.03,.03*v,6.4*u,1.98,.47*v,brass,'metal');
  light(g,6.4*u,1.75,.60*v,warm,.18);

  // Liquor bottles on back bar shelves
  for (let i = 0; i < 5; i++) {
    const bx = (5.5 + i*0.45)*u;
    cylinder(g,.04*s,.22,bx,1.63,.35*v,0x784422,'glass',.03*s,8);
    cylinder(g,.04*s,.22,bx,2.08,.35*v,0x254030,'glass',.03*s,8);
  }

  // Front bar counter: curved-corner dark marble with brass kickplate
  box(g,2.4*u,.95,.55*v,6.4*u,.50,1.35*v,walnut);
  box(g,2.55*u,.08,.68*v,6.4*u,.99,1.35*v,charcoal);
  box(g,2.35*u,.08,.04*v,6.4*u,.10,1.64*v,brass,'metal'); // brass kickplate

  // Barstools along the counter
  for (let i = 0; i < 3; i++) {
    const sx = (5.6 + i*0.8)*u;
    cylinder(g,.15*s,.06,sx,.70,1.9*v,cognac,'paint',.15*s,10);
    cylinder(g,.03*s,.65,sx,.35,1.9*v,brass,'metal',.03*s,6);
    cylinder(g,.18*s,.03,sx,.03,1.9*v,brass,'metal',.18*s,8);
  }

  // 7. Executive Work / Reading Nook (front-right)
  // Dark acoustic privacy booth with velvet highback chair
  box(g,.10*u,1.60,1.6*v,5.2*u,.90,3.8*v,charcoal);
  box(g,1.6*u,1.60,.10*v,6.0*u,.90,4.6*v,charcoal);
  box(g,1.2*u,.06,.65*v,6.0*u,.74,3.9*v,walnut); // desk surface
  box(g,.70*u,.38,.65*v,6.0*u,.22,3.4*v,navy);   // executive velvet chair
  box(g,.70*u,.55,.18*v,6.0*u,.65,3.15*v,navy);
  light(g,6.0*u,1.25,3.9*v,warm,.12); // brass desk task light

  // 8. Flight Information Board on Sleek Pylon (central divider)
  box(g,.16*u,2.4,.16*v,4.6*u,1.2,.50*v,brass,'metal');
  box(g,1.4*u,.85,.08*v,4.6*u,1.8,.50*v,charcoal);
  box(g,1.3*u,.75,.02*v,4.6*u,1.8,.55*v,0x10151a); // dark screen
  light(g,4.6*u,1.8,.60*v,screenGlow,.14);
  label(g,'DEPARTURES',4.6*u,2.15,.57*v,4.5,'#d4af37');
  label(g,'LONDON  14:20  ON TIME',4.6*u,1.95,.57*v,2.6,'#9fd4de');
  label(g,'TOKYO   14:45  BOARDING',4.6*u,1.80,.57*v,2.6,'#d4af37');
  label(g,'PARIS   15:10  GATE 12',4.6*u,1.65,.57*v,2.6,'#9fd4de');

  // 9. Ceiling & Ambient Downlighting
  // Dark smoked walnut ceiling beams
  box(g,5.80*u,.10,.22*v,4.00*u,2.88,1.70*v,walnut);
  g.children[g.children.length-1].userData.roof = true;
  box(g,5.80*u,.10,.22*v,4.00*u,2.88,3.50*v,walnut);
  g.children[g.children.length-1].userData.roof = true;

  // Warm brass pendant lamps suspended above the salon
  for (const [lx,lz] of [[2.6,3.0],[6.4,1.35],[2.6,1.8]]) {
    cylinder(g,.015*s,.30,lx*u,2.70,lz*v,charcoal,'paint',.015*s,6);
    cylinder(g,.07*s,.14,lx*u,2.52,lz*v,brass,'metal',.18*s,10);
    light(g,lx*u,2.44,lz*v,warm,.12);
  }
}
