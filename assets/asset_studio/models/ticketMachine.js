function ticketMachine(g,w,d){
  const x = w / 2, z = d / 2, sx = w / 2, sz = d;
  const body = 0xd8d3c6, teal = 0x2a6d7a;
  const dark = 0x1b2e36, base = 0x3b4347;
  const glow = 0x7fe0e8, yellow = 0xf2c230;

  // Stepped shell: the top finishes at 2 m, inside a 0.91w x 0.88d base.
  box(g,1.82*sx,.08,.88*sz,x,.04,z,base,'metal');
  box(g,1.70*sx,.12,.80*sz,x,.14,z,base,'metal');
  box(g,1.62*sx,.034,.018*sz,x,.202,z+.404*sz,yellow);
  box(g,1.60*sx,1.55,.70*sz,x,.975,z-.03*sz,body);
  box(g,1.68*sx,.08,.72*sz,x,.24,z-.015*sz,body);
  box(g,1.52*sx,.18,.66*sz,x,1.82,z-.04*sz,body);
  box(g,1.40*sx,.09,.61*sz,x,1.955,z-.055*sz,body);
  box(g,1.31*sx,.66,.028*sz,x,.626,z+.333*sz,body);
  box(g,1.30*sx,.095,.04*sz,x,.32,z+.344*sz,teal);
  box(g,.11*sx,1.42,.73*sz,x-.765*sx,.985,z-.015*sz,teal);
  box(g,.11*sx,1.42,.73*sz,x+.765*sx,.985,z-.015*sz,teal);
  box(g,1.58*sx,.235,.065*sz,x,1.795,z+.319*sz,teal);

  // A geometric ticket, not a logo or a texture.
  box(g,.24*sx,.12,.012*sz,x,1.801,z+.360*sz,0xf9fcf6);
  box(g,.036*sx,.034,.014*sz,x-.118*sx,1.801,z+.369*sz,teal);
  box(g,.036*sx,.034,.014*sz,x+.118*sx,1.801,z+.369*sz,teal);
  box(g,.11*sx,.014,.014*sz,x,1.801,z+.369*sz,teal);

  // Tilt is depth-aware; front layers share the same local screen plane.
  const a = -Math.atan(.18*sz), sn = Math.sin(a), cs = Math.cos(a);
  const px = x-.205*sx, py = 1.322, pz = z+.321*sz;
  let part;
  box(g,.95*sx,.65,.07*sz,px,py,pz,dark);
  g.children[g.children.length-1].rotation.x = a;
  light(g,px,py-sn*.046*sz,pz+cs*.046*sz,glow,.1);
  part = g.children[g.children.length-1];
  part.scale.x *= 8.2*sx;
  part.scale.y *= 5.2;
  part.scale.z *= .12*sz;
  part.rotation.x = a;
  for (const [dx,dy,bw,bh] of [
    [0,.15,.57,.027],[-.16,-.002,.25,.13],
    [.16,-.002,.25,.13],[0,-.17,.37,.025]
  ]) {
    box(g,bw*sx,bh,.012*sz,px+dx*sx,
      py+dy*cs-sn*.059*sz,pz+dy*sn+cs*.059*sz,teal);
    g.children[g.children.length-1].rotation.x = a;
  }

  box(g,.32*sx,.50,.066*sz,x+.50*sx,1.322,z+.343*sz,dark,'metal');
  light(g,x+.50*sx,1.462,z+.383*sz,glow,.028);
  part = g.children[g.children.length-1];
  part.scale.x *= 5*sx;
  part.scale.y *= .8;
  part.scale.z *= .45*sz;
  box(g,.23*sx,.17,.043*sz,x+.50*sx,1.314,z+.394*sz,base,'metal');
  box(g,.17*sx,.024,.009*sz,x+.50*sx,1.337,z+.419*sz,dark);
  box(g,.096*sx,.046,.01*sz,x+.50*sx,1.259,z+.420*sz,teal);
  box(g,.17*sx,.009,.01*sz,x+.50*sx,1.308,z+.419*sz,yellow);

  box(g,.68*sx,.16,.035*sz,x-.21*sx,.862,z+.344*sz,base);
  box(g,.56*sx,.04,.012*sz,x-.21*sx,.900,z+.367*sz,dark);
  box(g,.32*sx,.084,.070*sz,x-.24*sx,.858,z+.387*sz,0xf9fcf6);
  box(g,.72*sx,.045,.088*sz,x-.21*sx,.774,z+.378*sz,teal,'metal');

  for (const side of [-1,1]) {
    light(g,x+side*.765*sx,1.24,z+.365*sz,glow,.1);
    part = g.children[g.children.length-1];
    part.scale.x *= .31*sx;
    part.scale.y *= 8.6;
    part.scale.z *= .25*sz;
  }
  box(g,1.24*sx,.90,.026*sz,x,.87,z-.393*sz,body,'metal');
  for (const y of [.69,.78,.87]) {
    box(g,.70*sx,.026,.014*sz,x,y,z-.413*sz,base,'metal');
  }
}