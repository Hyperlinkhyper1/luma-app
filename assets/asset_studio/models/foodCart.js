function foodCart(g,w,d){
  const u = w/3, v = d/2, x = w/2, z = d/2, s = Math.min(u,v);
  const body = 0xd8d3c6, counter = 0x805d42, wood = 0xa77b55;
  const dark = 0x3b4347, metal = 0x8b9295, teal = 0x2a6d7a, orange = 0xd98a45;
  const canopyC = 0xe5e0d5, inside = 0x343b3e, warm = 0xffd99a;

  // Four mobility wheels keep the bottom clear of the ground line.
  for (const wx of [0.75, 2.25]) {
    for (const wz of [0.55, 1.45]) {
      cylinder(g,.18,.09,wx*u,.18,wz*v,dark,'paint',.18,8);
      g.children[g.children.length-1].rotation.z = Math.PI/2;
    }
  }

  // Cart body: dark skirt, main cabinet, teal band, service doors.
  box(g,1.94*u,.16,1.24*v,x,.30,z,dark);
  box(g,1.9*u,.88,1.2*v,x,.74,z,body);
  box(g,1.9*u,.18,.05*v,x,.98,z+.61*v,teal);
  for (const dx of [-0.52, 0.52]) {
    box(g,.85*u,.60,.05*v,x+dx*u,.70,z+.61*v,body);
    box(g,.03*u,.14,.03*v,x+dx*u+.32*u,.74,z+.63*v,dark);
  }

  // Passenger counter on the +z side.
  box(g,2.0*u,.08,1.28*v,x,1.20,z,counter);

  // Glass snack display: dark base, glass box, two shelves, pastries, sandwiches.
  box(g,.72*u,.18,.5*v,1.9*u,1.31,z+.30*v,dark);
  box(g,.66*u,.34,.46*v,1.9*u,1.58,z+.30*v,0xcfe0e2,'glass');
  for (const sy of [1.44, 1.60]) {
    box(g,.58*u,.03,.38*v,1.9*u,sy,z+.30*v,wood);
  }
  for (const px of [1.72, 1.90, 2.08]) {
    sphere(g,px*u,1.50,z+.30*v,.085,.075,.085,0xd9a24b);
  }
  box(g,.26*u,.08,.20*v,1.78*u,1.645,z+.30*v,0xe8e3d6);
  box(g,.26*u,.08,.20*v,2.02*u,1.645,z+.30*v,0xe8e3d6);
  light(g,1.9*u,1.74,z+.30*v,warm,.08);

  // Coffee station on the left of the counter.
  box(g,.40*u,.42,.28*v,0.85*u,1.43,z+.32*v,metal,'metal');
  box(g,.28*u,.09,.02*v,0.85*u,1.42,z+.465*v,dark);
  box(g,.05*u,.05,.02*v,0.77*u,1.56,z+.465*v,teal);
  for (const cx of [1.12, 1.22]) {
    cylinder(g,.04,.11,cx*u,1.275,z+.45*v,canopyC,'paint',.04,6);
  }

  // Bottled drinks between the stations, plus a fruit crate.
  for (const [bx,bc] of [[1.32,0x4776a8],[1.44,0xd98a45]]) {
    cylinder(g,.045,.28,bx*u,1.36,z+.44*v,bc,'paint',.045,8);
  }
  box(g,.26*u,.16,.26*v,2.40*u,1.30,z+.40*v,counter);
  sphere(g,2.35*u,1.42,z+.40*v,.055,.05,.055,orange);
  sphere(g,2.45*u,1.42,z+.40*v,.055,.05,.055,0xc95a50);

  // Hanging menu board over the counter front.
  box(g,1.3*u,.50,.03*v,x,1.95,z+.68*v,inside);
  label(g,'COFFEE - SNACKS',x,2.04,z+.715*v,3.2,canopyC);
  label(g,'SANDWICHES - DRINKS',x,1.86,z+.715*v,3.2,canopyC);

  // Canopy posts, roof (lid above 2 m), trim, and shop sign.
  for (const [px,pz] of [[0.60,0.44],[2.40,0.44],[0.60,1.60],[2.40,1.60]]) {
    box(g,.05,1.10,.05,px*u,1.78,pz*v,metal,'metal');
  }
  box(g,1.9*u,.08,1.5*v,x,2.34,z,canopyC);
  g.children[g.children.length-1].userData.roof = true;
  box(g,1.9*u,.05,.06*v,x,2.295,z+.73*v,teal);
  g.children[g.children.length-1].userData.roof = true;
  box(g,1.3*u,.20,.03*v,x,2.34,z+.78*v,teal);
  g.children[g.children.length-1].userData.roof = true;
  label(g,'GRAB & GO',x,2.34,z+.812*v,4.5,'#f9fcf6');
  light(g,x,2.26,z,warm,.10);

  // One employee working behind the cart, head and shoulders above the counter.
  box(g,.26*u,.50,.20*v,1.1*u,.55,z-.80*v,dark);
  box(g,.34*u,.55,.22*v,1.1*u,1.095,z-.80*v,teal);
  sphere(g,1.1*u,1.48,z-.80*v,.115*s,.14,.115*s,0xd8b49a);
  box(g,.20*u,.05,.20*v,1.1*u,1.555,z-.80*v,dark);

  // Rear storage doors + counter props.
  for (const dx of [-0.5, 0.5]) {
    box(g,.7*u,.50,.02*v,x+dx*u,.70,z-.615*v,dark);
    box(g,.03*u,.12,.03*v,x+dx*u-.20*u,.70,z-.625*v,metal,'metal');
  }
  box(g,.12*u,.11,.10*v,0.72*u,1.275,z+.50*v,metal,'metal');
  cylinder(g,.025,.11,0.56*u,1.275,z+.50*v,orange,'paint',.025,6);
  cylinder(g,.025,.11,0.59*u,1.275,z+.50*v,0xc95a50,'paint',.025,6);
}
