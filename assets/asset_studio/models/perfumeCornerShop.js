function perfumeCornerShop(g,w,d){
  const u = w/8, v = d/7, x = w/2, s = Math.min(u,v);
  const ivory = 0xeee8dc, grey = 0xd8d3c6, dark = 0x292d30, base = 0x45484a;
  const trim = 0x9b9b96, brass = 0xc4a261, wood = 0x86654d;
  const blush = 0xc89da0, purple = 0x78677e, teal = 0x2a6d7a;
  const warm = 0xffdda6, cool = 0xd8f0ef, glassC = 0xcfe0e2;
  const bottles = [0xd6b46c,0xc58f9c,0x8ca9a4,0x87789a,0x6e8ba0,0xe3d8c4];

  function bottle(px,py,pz,bw,bh,col){
    box(g,bw,bh,bw*.9,px,py+bh/2,pz,col);
    box(g,bw*.34,bh*.26,bw*.3,px,py+bh+bh*.13,pz,dark);
  }
  function flask(px,py,pz,r,h,col){
    cylinder(g,r,h,px,py+h/2,pz,col,'paint',r,8);
    cylinder(g,r*.42,h*.24,px,py+h+h*.12,pz,brass,'paint',r*.42,8);
  }

  // Floor, blush runner and violet carpet guiding corner entrance to island.
  box(g,7.9*u,.04,6.9*v,x,.02,3.5*v,grey);
  box(g,1.6*u,.02,2.6*v,6.2*u,.045,5.2*v,blush);
  box(g,2.8*u,.02,1.1*v,3.9*u,.05,6.15*v,purple);

  // Closed backs: north + west walls with wood wainscot.
  box(g,7.9*u,3.0,.14*v,x,1.5,.12*v,ivory);
  box(g,.14*u,3.0,6.9*v,.12*u,1.5,3.5*v,grey);
  box(g,7.6*u,.9,.06*v,x,.45,.21*v,wood);
  box(g,.06*u,.9,6.6*v,.21*u,.45,3.5*v,wood);

  // Storefront pillars; south-east corner deliberately left open.
  for (const pxx of [.32,2.8,4.95]) box(g,.5*u,3.1,.5*v,pxx*u,1.55,d-.30*v,ivory);
  for (const pzz of [.32,2.7,4.3]) box(g,.5*u,3.1,.5*v,w-.30*u,1.55,pzz*v,ivory);

  // South glass bays with bulkheads and transom bars.
  for (const [bx,bw] of [[1.56,1.9],[3.88,1.5]]) {
    box(g,bw*u,.42,.20*v,bx*u,.21,d-.14*v,dark);
    box(g,bw*u,2.0,.06*v,bx*u,1.42,d-.14*v,glassC,'glass');
    box(g,bw*u,.05,.08*v,bx*u,2.435,d-.14*v,trim,'metal');
  }
  // East glass bays with bulkheads and transom bars.
  for (const [bz,bd] of [[1.5,1.7],[3.5,1.0]]) {
    box(g,.20*u,.42,bd*v,w-.14*u,.21,bz*v,dark);
    box(g,.06*u,2.0,bd*v,w-.14*u,1.42,bz*v,glassC,'glass');
    box(g,.08*u,.05,bd*v,w-.14*u,2.435,bz*v,trim,'metal');
  }

  // Dressed south window vignettes: ivory plinths with hero flacons.
  box(g,.9*u,.50,.5*v,1.56*u,.25,6.20*v,ivory);
  flask(1.56*u,.5,6.20*v,.12*s,.38,bottles[2]);
  box(g,.9*u,.50,.5*v,3.88*u,.25,6.20*v,ivory);
  flask(3.88*u,.5,6.20*v,.12*s,.38,bottles[5]);

  // Wraparound fascia, brass reveals, corner cap lid.
  box(g,7.4*u,.65,.45*v,3.7*u,2.775,d-.28*v,ivory);
  box(g,.45*u,.65,6.4*v,w-.28*u,2.775,3.2*v,ivory);
  box(g,7.4*u,.06,.06*v,3.7*u,2.44,d-.07*v,brass,'metal');
  box(g,.06*u,.06,6.4*v,w-.07*u,2.44,3.2*v,brass,'metal');
  box(g,.66*u,.08,.66*v,w-.38*u,3.12,d-.38*v,brass,'metal');
  g.children[g.children.length-1].userData.roof = true;

  // South fascia sign, east fascia sign, corner blade cube.
  box(g,3.2*u,.44,.05*v,4.0*u,2.80,d-.10*v,dark);
  label(g,'MAISON LUEUR',4.0*u,2.88,d-.065*v,8,'#f9fcf6');
  label(g,'PARFUMS',4.0*u,2.66,d-.065*v,4,'#c4a261');
  light(g,4.0*u,2.45,d-.10*v,warm,.12);
  box(g,.05*u,.44,3.2*v,w-.10*u,2.80,2.4*v,dark);
  label(g,'MAISON LUEUR',w-.065*u,2.88,2.4*v,8,'#f9fcf6',{rotY:Math.PI/2});
  label(g,'PARFUMS',w-.065*u,2.66,2.4*v,4,'#c4a261',{rotY:Math.PI/2});
  light(g,w-.10*u,2.45,2.4*v,warm,.12);
  box(g,.45*u,.60,.45*v,w-.62*u,2.55,d-.62*v,dark);
  label(g,'LUEUR',w-.62*u,2.58,d-.385*v,5,'#c4a261');
  label(g,'LUEUR',w-.385*u,2.58,d-.62*v,5,'#c4a261',{rotY:Math.PI/2});

  // North wall illuminated displays with curated bottle rows.
  for (const dxx of [2.6,5.4]) {
    box(g,2.2*u,2.0,.14*v,dxx*u,1.2,.27*v,dark);
    box(g,2.2*u,.06,.12*v,dxx*u,2.23,.30*v,brass,'metal');
    for (const yy of [.95,1.45]) box(g,2.0*u,.05,.30*v,dxx*u,yy,.50*v,trim,'metal');
    for (let i = 0; i < 3; i++) {
      bottle((dxx-.6+i*.6)*u,.975,.50*v,.20*u,.30,bottles[(i*2+dxx)%6]);
      flask((dxx-.6+i*.6)*u,1.475,.50*v,.09*s,.26,bottles[(i*2+dxx+3)%6]);
    }
    label(g,dxx<4?'EAU DE PARFUM':'EXCLUSIFS',dxx*u,2.05,.345*v,3,'#c4a261');
    light(g,dxx*u,2.0,.75*v,warm,.16);
  }

  // West wall display with bronze mirror.
  box(g,.14*u,2.0,2.6*v,.27*u,1.2,3.6*v,dark);
  for (const yy of [.95,1.45]) box(g,.30*u,.05,2.4*v,.50*u,yy,3.6*v,trim,'metal');
  for (let i = 0; i < 3; i++) {
    bottle(.50*u,.975,(2.8+i*.8)*v,.20*u,.30,bottles[(i*2+1)%6]);
    flask(.50*u,1.475,(2.8+i*.8)*v,.09*s,.26,bottles[(i*2+4)%6]);
  }
  box(g,.06*u,1.6,.90*v,.23*u,1.4,5.6*v,wood);
  box(g,.04*u,1.5,.80*v,.27*u,1.4,5.6*v,glassC,'glass');
  light(g,.75*u,2.0,3.6*v,warm,.16);

  // Central fragrance island: stepped drums, hero bottles, cool glow.
  cylinder(g,.95*s,.50,4.3*u,.25,3.9*v,dark,'paint',.95*s,12);
  cylinder(g,.98*s,.06,4.3*u,.53,3.9*v,brass,'metal',.98*s,12);
  cylinder(g,.80*s,.55,4.3*u,.83,3.9*v,glassC,'glass',.80*s,12);
  cylinder(g,.85*s,.06,4.3*u,1.13,3.9*v,ivory,'paint',.85*s,12);
  for (let i = 0; i < 5; i++) {
    const a = i*Math.PI*2/5+.4;
    bottle(4.3*u+Math.cos(a)*.45*s,1.16,3.9*v+Math.sin(a)*.45*s,.17*u,.26,bottles[i%6]);
  }
  flask(4.3*u,1.16,3.9*v,.14*s,.44,bottles[0]);
  light(g,4.3*u,1.70,3.9*v,cool,.14);

  // Two tester tables with mirrors and spaced tester bottles.
  for (const [tx,tz] of [[2.0,5.3],[6.0,4.2]]) {
    const mz = tz<5 ? tz-.24 : tz+.24;
    box(g,.90*u,.60,.50*v,tx*u,.30,tz*v,base);
    box(g,.95*u,.05,.55*v,tx*u,.63,tz*v,dark);
    box(g,.90*u,.70,.04*v,tx*u,1.0,mz*v,glassC,'glass');
    bottle((tx-.18)*u,.655,tz*v,.15*u,.22,bottles[1]);
    bottle((tx+.18)*u,.655,tz*v,.15*u,.22,bottles[4]);
  }

  // Corner hero pedestal greeting both entrances.
  cylinder(g,.40*s,.50,6.9*u,.25,6.0*v,wood,'paint',.40*s,10);
  cylinder(g,.43*s,.05,6.9*u,.52,6.0*v,brass,'metal',.43*s,10);
  bottle(6.72*u,.545,5.9*v,.18*u,.30,bottles[3]);
  bottle(7.08*u,.545,5.9*v,.18*u,.30,bottles[0]);
  flask(6.9*u,.545,6.15*v,.11*s,.34,bottles[2]);
  light(g,6.9*u,1.30,6.0*v,warm,.12);

  // Gift-wrapped stack beside the island and a boutique bag by the tester.
  box(g,.35*u,.35,.35*v,5.7*u,.175,2.6*v,blush);
  box(g,.25*u,.25,.25*v,5.7*u,.475,2.6*v,purple);
  box(g,.30*u,.40,.20*v,1.2*u,.20,5.3*v,wood);
  box(g,.26*u,.10,.16*v,1.2*u,.45,5.3*v,blush);

  // Tiny service desk tucked at the north-west, staff screen inside.
  box(g,1.2*u,.90,.50*v,1.1*u,.45,1.0*v,wood);
  box(g,1.3*u,.06,.60*v,1.1*u,.93,1.0*v,dark);
  box(g,.40*u,.30,.04*v,1.1*u,1.15,.85*v,dark);
  light(g,1.1*u,1.15,.80*v,cool,.07);

  // Ceiling beams wall to fascia with brass pendants over key displays.
  for (const bz of [2.2,5.0]) {
    box(g,7.3*u,.10,.22*v,3.85*u,2.90,bz*v,ivory);
    g.children[g.children.length-1].userData.roof = true;
  }
  for (const [lx,lz] of [[4.3,3.9],[2.6,1.0],[6.9,6.0]]) {
    cylinder(g,.015*s,.30,lx*u,2.72,lz*v,dark,'paint',.015*s,6);
    cylinder(g,.07*s,.14,lx*u,2.52,lz*v,brass,'metal',.16*s,10);
    light(g,lx*u,2.40,lz*v,warm,.11);
  }
}
