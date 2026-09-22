function vendingMachine(g,w,d){
  const x = w / 2, z = d / 2, sx = w / 2, sz = d;
  const body = 0xd8d3c6, base = 0x3b4347, dark = 0x1b2e36;
  const teal = 0x2a6d7a, glow = 0x7fe0e8, yellow = 0xf2c230;

  // Cabinet shell: recessed core, right interface column, left pillar,
  // header and lower section frame a real display cavity for products.
  box(g,1.90*sx,.10,.90*sz,x,.05,z,base,'metal');
  box(g,1.84*sx,1.85,.62*sz,x,1.025,z-.11*sz,body);
  box(g,.62*sx,1.85,.86*sz,x+.61*sx,1.025,z+.01*sz,body);
  box(g,.10*sx,1.85,.86*sz,x-.87*sx,1.025,z+.01*sz,body);
  box(g,1.22*sx,.23,.24*sz,x-.31*sx,1.835,z+.32*sz,body);
  box(g,1.22*sx,.52,.24*sz,x-.31*sx,.36,z+.32*sz,body);
  box(g,1.72*sx,.10,.76*sz,x,2.0,z,body);
  box(g,1.22*sx,.06,.02*sz,x-.31*sx,1.80,z+.45*sz,teal);

  // Display cavity: dark back wall, three shelves, one glass pane.
  box(g,1.12*sx,1.10,.04*sz,x-.26*sx,1.17,z+.22*sz,dark);
  const shelfY = [1.38,1.02,.66];
  for (const y of shelfY) {
    box(g,1.10*sx,.03,.18*sz,x-.26*sx,y,z+.33*sz,0xb9b4a8,'metal');
  }
  const bags = [0xc86f4c,0xe1b24d,0x7fa262,0x9d74a6];
  const boxes = [0x5c86b8,0xd8956a,0x8fb3a6,0xc9c26e];
  const drinks = [0x3d7db6,0xd05540,0x66a566,0xe6be47];
  const r = .07*Math.min(sx,sz);
  for (let i = 0; i < 4; i++) {
    const cx = x+(-.65+.26*i)*sx;
    box(g,.18*sx,.24,.08*sz,cx,1.515,z+.33*sz,bags[i]);
    box(g,.20*sx,.20,.10*sz,cx,1.135,z+.33*sz,boxes[i]);
    cylinder(g,r,.28,cx,.815,z+.33*sz,drinks[i],'paint',r,8);
  }
  box(g,1.12*sx,1.10,.02*sz,x-.26*sx,1.17,z+.42*sz,0xbfe3ea,'glass');

  // Interface column: screen, keypad, card reader.
  box(g,.50*sx,.62,.03*sz,x+.61*sx,1.45,z+.45*sz,dark);
  box(g,.40*sx,.28,.02*sz,x+.61*sx,1.58,z+.465*sz,glow);
  light(g,x+.61*sx,1.58,z+.445*sz,glow,.07);
  box(g,.30*sx,.16,.02*sz,x+.61*sx,1.30,z+.465*sz,teal);
  box(g,.22*sx,.10,.05*sz,x+.61*sx,1.02,z+.455*sz,base,'metal');
  box(g,.16*sx,.012,.01*sz,x+.61*sx,1.04,z+.482*sz,dark);

  // Dispensing opening with push flap and warning strip.
  box(g,.80*sx,.30,.03*sz,x-.26*sx,.40,z+.43*sz,dark);
  box(g,.72*sx,.16,.02*sz,x-.26*sx,.48,z+.445*sz,teal);
  box(g,.80*sx,.03,.01*sz,x-.26*sx,.23,z+.445*sz,yellow);

  // Subtle edge lights on both front pillars.
  for (const y of [.9,1.5]) {
    light(g,x-.87*sx,y,z+.44*sz,glow,.06);
    light(g,x+.89*sx,y,z+.44*sz,glow,.06);
  }
}
