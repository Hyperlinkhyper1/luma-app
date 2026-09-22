function airportArcade(g,w,d){
  const u = w/10, v = d/8, x = w/2, z = d/2, s = Math.min(u,v);
  const arch = 0x292d30, arch2 = 0x3b4347, cab = 0x343b3e, cab2 = 0x45484a;
  const metal = 0x777f82, darkScr = 0x14252d, glassC = 0xcfe0e2;
  const purple = 0x795a9b, blue = 0x3976a8, teal = 0x2a6d7a, pink = 0xc85f8f;
  const red = 0xc95a50, orange = 0xd98245, yellow = 0xe2c84b, green = 0x4f8b58;
  const glowB = 0x7fe0e8, glowW = 0xffc978;

  // 1. Dark floor with geometric neon inlay carpet
  box(g,9.85*u,.04,7.85*v,x,.02,z,arch);
  box(g,3.8*u,.025,4.6*v,x,.045,4.1*v,0x1f1b2b);
  box(g,3.6*u,.012,.08*v,x,.06,2.0*v,purple);
  box(g,3.6*u,.012,.08*v,x,.06,6.2*v,pink);
  box(g,.08*u,.012,4.2*v,3.2*u,.06,4.1*v,blue);
  box(g,.08*u,.012,4.2*v,6.8*u,.06,4.1*v,teal);

  // 2. Enclosure: North back wall & East/West side walls with neon accent friezes
  box(g,9.85*u,3.0,.16*v,x,1.5,.18*v,arch);
  box(g,9.6*u,.08,.08*v,x,2.3,.24*v,purple);
  box(g,.16*u,3.0,7.85*v,.18*u,1.5,z,arch);
  box(g,.08*u,.08,7.6*v,.24*u,2.3,z,blue);
  box(g,.16*u,3.0,7.85*v,w-.18*u,1.5,z,arch);
  box(g,.08*u,.08,7.6*v,w-.24*u,2.3,z,pink);

  // 3. Storefront (+z): entrance pillars, deep fascia, illuminated ARCADE marquee
  box(g,.5*u,3.1,.5*v,.35*u,1.55,7.65*v,arch);
  box(g,.5*u,3.1,.5*v,2.65*u,1.55,7.65*v,arch);
  box(g,.5*u,3.1,.5*v,7.35*u,1.55,7.65*v,arch);
  box(g,.5*u,3.1,.5*v,w-.35*u,1.55,7.65*v,arch);
  // Glass side-window bays
  box(g,1.9*u,.40,.18*v,1.5*u,.20,7.70*v,arch2);
  box(g,1.9*u,1.95,.05*v,1.5*u,1.38,7.70*v,glassC,'glass');
  box(g,1.9*u,.40,.18*v,w-1.5*u,.20,7.70*v,arch2);
  box(g,1.9*u,1.95,.05*v,w-1.5*u,1.38,7.70*v,glassC,'glass');
  // Wide central walk-in entrance (4.2m opening between 2.9u and 7.1u)
  box(g,4.3*u,.03,.6*v,x,.04,7.55*v,purple);
  // Fascia & neon signs (lid above 2m flagged)
  box(g,9.85*u,.65,.55*v,x,2.78,7.65*v,arch);
  box(g,9.9*u,.06,.62*v,x,3.12,7.65*v,purple);
  g.children[g.children.length-1].userData.roof = true;
  box(g,4.4*u,.48,.08*v,x,2.78,7.86*v,0x15161c);
  label(g,'ARCADE',x,2.88,7.90*v,12,'#f9fcf6');
  label(g,'PIXEL PORT  -  LEVEL UP',x,2.63,7.90*v,3.5,'#7fe0e8');
  light(g,x,2.80,7.84*v,glowB,.16);
  light(g,2.65*u,2.78,7.78*v,glowW,.12);
  light(g,7.35*u,2.78,7.78*v,glowW,.12);

  // 4. CATEGORY A: Five distinct upright arcade cabinets (along West wall, facing +x into room)
  const cabs = [
    { z: 1.2, name: 'STAR RUN', col: blue, scrCol: 0x1a4563, marq: teal, lit: glowB },
    { z: 2.2, name: 'VOID DASH', col: purple, scrCol: 0x4a1e5c, marq: pink, lit: glowW },
    { z: 3.2, name: 'GALAXY', col: red, scrCol: 0x541c22, marq: yellow, lit: glowW },
    { z: 4.2, name: 'BLOCK DROP', col: orange, scrCol: 0x5c4218, marq: orange, lit: glowW },
    { z: 5.2, name: 'HYPERBALL', col: green, scrCol: 0x1e4a2c, marq: green, lit: glowB }
  ];
  for (const c of cabs) {
    const cx = .85*u, cz = c.z*v;
    // Lower body & base
    box(g,.75*u,.85,.85*v,cx,.43,cz,cab);
    box(g,.80*u,.10,.90*v,cx,.10,cz,arch2);
    // Control deck projecting outward (+x)
    box(g,.30*u,.12,.80*v,cx+.45*u,.86,cz,c.col);
    // Two mini joysticks
    cylinder(g,.02*s,.12,cx+.48*u,.96,cz-.18*v,metal,'metal',.02*s,6);
    sphere(g,cx+.48*u,1.03,cz-.18*v,.04*s,.04*s,.04*s,red);
    cylinder(g,.02*s,.12,cx+.48*u,.96,cz+.18*v,metal,'metal',.02*s,6);
    sphere(g,cx+.48*u,1.03,cz+.18*v,.04*s,.04*s,.04*s,blue);
    // Slanted upper body & screen
    box(g,.75*u,.95,.85*v,cx,1.38,cz,cab);
    box(g,.05*u,.58,.72*v,cx+.32*u,1.32,cz,c.scrCol);
    light(g,cx+.38*u,1.32,cz,c.lit,.10);
    // Colored marquee at top
    box(g,.24*u,.22,.85*v,cx+.30*u,1.75,cz,c.marq);
    label(g,c.name,cx+.43*u,1.75,cz,2.8,'#f9fcf6',{rotY:Math.PI/2});
  }

  // 5. CATEGORY B: Twin seated racing game (NE corner, facing -z toward front)
  // Two side-by-side cockpits
  for (const rx of [7.3*u, 8.7*u]) {
    // Front machine cabinet with giant screen
    box(g,1.15*u,1.70,.85*v,rx,1.05,1.2*v,cab);
    box(g,1.05*u,.12,.90*v,rx,1.86,1.2*v,red);
    box(g,.95*u,.65,.05*v,rx,1.32,1.6*v,0x1a334d);
    light(g,rx,1.32,1.65*v,glowB,.13);
    // Steering wheel dashboard
    box(g,.90*u,.30,.50*v,rx,.82,1.8*v,cab2);
    cylinder(g,.14*s,.05,rx,.96,1.9*v,metal,'metal',.14*s,10);
    // Footwell and seat base platform
    box(g,1.05*u,.16,1.40*v,rx,.08,2.7*v,arch2);
    // Racing bucket seat (red/blue)
    const seatCol = rx < 8*u ? red : blue;
    box(g,.80*u,.34,.70*v,rx,.32,2.8*v,seatCol);
    box(g,.76*u,.85,.20*v,rx,.85,3.15*v,seatCol);
    box(g,.70*u,.25,.18*v,rx,1.28,3.15*v,darkScr); // headrest
  }
  // Twin racer marquee above both cockpits
  box(g,2.7*u,.34,.30*v,8.0*u,2.05,1.2*v,arch);
  label(g,'TURBO RACER 2P',8.0*u,2.05,1.37*v,4.8,'#ffe2a8');

  // 6. CATEGORY C: Air Hockey Table (Centerpiece attraction)
  const ax = 5.0*u, az = 4.1*v;
  // Sturdy pedestal legs with floor runners
  box(g,2.2*u,.12,3.2*v,ax,.06,az,arch2);
  cylinder(g,.12*s,.68,ax-.85*u,.42,az-1.1*v,metal,'metal',.10*s,8);
  cylinder(g,.12*s,.68,ax+.85*u,.42,az-1.1*v,metal,'metal',.10*s,8);
  cylinder(g,.12*s,.68,ax-.85*u,.42,az+1.1*v,metal,'metal',.10*s,8);
  cylinder(g,.12*s,.68,ax+.85*u,.42,az+1.1*v,metal,'metal',.10*s,8);
  // Table body with raised perimeter bumper rails
  box(g,2.2*u,.24,3.3*v,ax,.80,az,cab);
  box(g,1.86*u,.06,2.96*v,ax,.915,az,0x253b5c); // illuminated air table surface
  // Center playfield line and goal slots
  box(g,1.84*u,.025,.06*v,ax,.94,az,red);
  box(g,.70*u,.06,.08*v,ax,.935,az-1.42*v,darkScr); // north goal
  box(g,.70*u,.06,.08*v,ax,.935,az+1.42*v,darkScr); // south goal
  // Blue/red puck and two strikers
  cylinder(g,.07*s,.035,ax+.25*u,.957,az-.35*v,yellow,'paint',.07*s,8); // puck
  cylinder(g,.10*s,.07,ax-.3*u,.975,az-.75*v,blue,'paint',.07*s,8);   // north striker
  cylinder(g,.10*s,.07,ax+.3*u,.975,az+.75*v,red,'paint',.07*s,8);    // south striker
  // Overhead score bridge with digital display
  box(g,.06*u,1.25,.08*v,ax-1.02*u,1.40,az,metal,'metal');
  box(g,.06*u,1.25,.08*v,ax+1.02*u,1.40,az,metal,'metal');
  box(g,2.10*u,.24,.18*v,ax,2.02,az,arch);
  label(g,'AIR HOCKEY  04 - 02',ax,2.02,az+.10*v,3.6,'#7fe0e8');
  label(g,'AIR HOCKEY  04 - 02',ax,2.02,az-.10*v,3.6,'#7fe0e8',{rotY:Math.PI});
  light(g,ax,1.85,az,glowB,.14);

  // 7. CATEGORY D: Dance / Rhythm Motion Stage (SE corner, facing -z)
  const dx = 8.1*u, dz = 5.8*v;
  // Raised dance stage with 4 directional arrows
  box(g,2.1*u,.16,1.8*v,dx,.08,dz,arch2);
  box(g,.38*u,.03,.38*v,dx-.45*u,.17,dz,pink);        // left arrow
  box(g,.38*u,.03,.38*v,dx+.45*u,.17,dz,blue);        // right arrow
  box(g,.38*u,.03,.38*v,dx,.17,dz-.45*v,green);       // up arrow
  box(g,.38*u,.03,.38*v,dx,.17,dz+.45*v,yellow);      // down arrow
  // Steel safety handrails behind player
  box(g,1.9*u,.06,.06*v,dx,.88,dz+.65*v,metal,'metal');
  cylinder(g,.04*s,.84,dx-.85*u,.44,dz+.65*v,metal,'metal',.04*s,6);
  cylinder(g,.04*s,.84,dx+.85*u,.44,dz+.65*v,metal,'metal',.04*s,6);
  // Front rhythm machine upright cabinet with speakers and arrow screen
  box(g,1.8*u,1.9,.50*v,dx,1.05,4.6*v,cab);
  box(g,1.4*u,.75,.04*v,dx,1.38,4.86*v,0x1b2836);
  box(g,1.6*u,.22,.52*v,dx,2.05,4.6*v,pink);
  label(g,'DANCE RHYTHM',dx,2.05,4.88*v,3.8,'#f9fcf6');
  light(g,dx,1.40,4.92*v,glowW,.12);

  // 8. CATEGORY E: Glass Claw Prize Machine (SW corner near entrance, facing +x)
  const px = 1.3*u, pz = 6.6*v;
  // Lower cabinet base & prize drop door
  box(g,.95*u,.85,.95*v,px,.425,pz,cab);
  box(g,.34*u,.32,.04*v,px+.46*u,.32,pz,arch);
  // Glass upper enclosure (sunk 3cm into lower cabinet to prevent face flicker)
  box(g,.90*u,1.00,.90*v,px,1.31,pz,glassC,'glass');
  box(g,.05*u,1.00,.05*v,px+.42*u,1.31,pz-.42*v,metal,'metal');
  box(g,.05*u,1.00,.05*v,px+.42*u,1.31,pz+.42*v,metal,'metal');
  box(g,.05*u,1.00,.05*v,px-.42*u,1.31,pz-.42*v,metal,'metal');
  box(g,.05*u,1.00,.05*v,px-.42*u,1.31,pz+.42*v,metal,'metal');
  // Colorful plush toy prizes heaped inside
  sphere(g,px-.15*u,.97,pz-.15*v,.10*s,.10*s,.10*s,pink);
  sphere(g,px+.15*u,.97,pz-.12*v,.10*s,.10*s,.10*s,yellow);
  sphere(g,px-.10*u,.97,pz+.15*v,.10*s,.10*s,.10*s,teal);
  sphere(g,px+.12*u,.97,pz+.16*v,.10*s,.10*s,.10*s,green);
  sphere(g,px,1.10,pz,.10*s,.10*s,.10*s,purple);
  // Mini claw mechanism hanging from top
  box(g,.08*u,.22,.08*v,px,1.65,pz,metal,'metal');
  // Top canopy & marquee (sunk 2cm into glass)
  box(g,1.0*u,.32,1.0*v,px,1.93,pz,yellow);
  label(g,'CRAZY CLAW',px+.51*u,1.94,pz,3.0,'#15161c',{rotY:Math.PI/2});
  light(g,px,1.75,pz,glowW,.11);

  // 9. Compact Prize & Ticket Redemption Desk (North-West corner)
  box(g,1.8*u,.90,.65*v,2.3*u,.45,1.0*v,arch);
  box(g,1.9*u,.08,.72*v,2.3*u,.93,1.0*v,teal);
  box(g,.45*u,.24,.35*v,2.5*u,1.08,1.0*v,cab2);
  label(g,'PRIZES',2.3*u,1.40,1.35*v,3.4,'#ffd99a');
  // Prize display shelf on back wall
  box(g,1.8*u,.06,.30*v,2.3*u,1.55,.40*v,metal,'metal');
  box(g,.24*u,.20,.20*v,1.7*u,1.66,.40*v,pink);
  box(g,.24*u,.20,.20*v,2.3*u,1.66,.40*v,yellow);
  box(g,.24*u,.20,.20*v,2.9*u,1.66,.40*v,blue);

  // 10. Overhead decorative ceiling beams with multi-colored mood pendants
  box(g,9.5*u,.10,.22*v,x,2.92,2.5*v,arch);
  g.children[g.children.length-1].userData.roof = true;
  box(g,9.5*u,.10,.22*v,x,2.92,5.5*v,arch);
  g.children[g.children.length-1].userData.roof = true;
  // Pendants
  for (const [lx,lz,col] of [[2.8,3.5,glowB],[7.5,3.0,glowW],[5.0,6.2,glowB],[8.0,6.0,glowW]]) {
    cylinder(g,.015*s,.28,lx*u,2.74,lz*v,metal,'metal',.015*s,6);
    cylinder(g,.09*s,.14,lx*u,2.54,lz*v,col === glowB ? blue : purple,'paint',.16*s,10);
    light(g,lx*u,2.44,lz*v,col,.11);
  }
}
