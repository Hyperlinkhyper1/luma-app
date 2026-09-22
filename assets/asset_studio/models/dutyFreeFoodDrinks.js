function dutyFreeFoodDrinks(g,w,d){
  const u = w/10, v = d/8, x = w/2, z = d/2, s = Math.min(u,v);
  const shell = 0xe5e0d5, wall = 0xd8d3c6, shelfM = 0x8b9295, dark = 0x3b4347;
  const wood = 0x8a6748, teal = 0x2a6d7a, frame = 0x555e62, fridgeIn = 0xe8f3f3;
  const warm = 0xffe2a8, cold = 0xbfe9ef, panel = 0x1b2e36, glow = 0x7fe0e8;
  const prod = [0xd94c4c,0xe6a23c,0xe2c84b,0x4f8b58,0x4776a8,0x6b5a9c,0xd9829b,0x8a6748,0xe8e3d6];

  // Shell: floor, back + side walls, storefront pillars, fascia, sign.
  box(g,9.9*u,.04,7.9*v,x,.02,4*v,wall);
  box(g,9.9*u,3.0,.14*v,x,1.5,.12*v,shell);
  box(g,.14*u,3.0,7.9*v,.12*u,1.5,4*v,wall);
  box(g,.14*u,3.0,7.9*v,w-.12*u,1.5,4*v,wall);
  box(g,.5*u,3.10,.5*v,.32*u,1.55,7.70*v,shell);
  box(g,.5*u,3.10,.5*v,w-.32*u,1.55,7.70*v,shell);
  box(g,9.9*u,.65,.45*v,x,2.775,7.72*v,shell);
  box(g,9.9*u,.05,.54*v,x,3.12,7.72*v,teal);
  g.children[g.children.length-1].userData.roof = true;
  box(g,3.6*u,.44,.05*v,x,2.80,7.945*v,panel);
  label(g,'DUTY FREE',x,2.90,7.985*v,10,'#f9fcf6');
  label(g,'FOOD & DRINK',x,2.66,7.985*v,4,'#7fe0e8');
  light(g,1.5*u,2.80,7.88*v,warm,.16);
  light(g,w-1.5*u,2.80,7.88*v,warm,.16);
  for (const px of [1.70*u, w-1.70*u]) {
    box(g,2.3*u,2.00,.06*v,px,1.42,7.86*v,0xbfe3ea,'glass');
    box(g,2.3*u,.42,.20*v,px,.23,7.86*v,dark);
  }
  box(g,4.0*u,.03,.5*v,x,.03,7.55*v,teal);

  // Back-wall confectionery shelving, shelves tied into wall + grounded ends.
  box(g,4.5*u,.15,.45*v,3.0*u,.075,.40*v,dark);
  box(g,.08*u,1.80,.42*v,.79*u,.90,.40*v,shelfM,'metal');
  box(g,.08*u,1.80,.42*v,5.21*u,.90,.40*v,shelfM,'metal');
  for (const yy of [.55,1.05,1.55]) box(g,4.5*u,.06,.40*v,3.0*u,yy,.38*v,shelfM,'metal');
  for (let i = 0; i < 12; i++) {
    const lvl = i%3, col = (i*2)%8, yy = [.55,1.05,1.55][lvl];
    const bw = (.32+((i*7)%3)*.07)*u, bh = .22+((i*5)%2)*.08, colr = prod[(col+i%3)%9];
    box(g,bw,bh,.24*v,(1.05+(i>>2)*.85)*u,yy+.03+bh/2-.01,.38*v,colr);
  }

  // Left-wall snack shelving, shelves tied into wall + grounded ends.
  box(g,.45*u,.15,3.0*v,.40*u,.075,2.60*v,dark);
  box(g,.42*u,1.70,.08*v,.40*u,.85,1.14*v,shelfM,'metal');
  box(g,.42*u,1.70,.08*v,.40*u,.85,4.06*v,shelfM,'metal');
  for (const yy of [.60,1.10,1.55]) box(g,.40*u,.06,3.0*v,.38*v,yy,2.60*v,shelfM,'metal');
  for (let i = 0; i < 8; i++) {
    const lvl = i%2, yy = [.60,1.10][lvl]+(i>5?.45:0);
    const bh = .22+((i*3)%2)*.07;
    box(g,.24*u,bh,.42*v,.38*v,yy+.03+bh/2-.01,(1.55+(i>>1)*.68)*v,prod[(i*3+1)%9]);
  }

  // Refrigerated drinks wall on the right: paneled cabinet, cold interior, glass doors.
  box(g,.10*u,2.10,3.0*v,9.65*u,1.05,2.50*v,frame);
  box(g,.80*u,.15,3.0*v,9.30*u,.075,2.50*v,dark);
  box(g,.80*u,.30,3.0*v,9.30*u,2.10,2.50*v,frame);
  box(g,.80*u,2.10,.08*v,9.30*u,1.05,1.04*v,frame);
  box(g,.80*u,2.10,.08*v,9.30*u,1.05,3.96*v,frame);
  box(g,.06*u,1.70,2.80*v,9.585*u,1.05,2.50*v,fridgeIn);
  for (const yy of [.90,1.40]) box(g,.50*u,.04,2.80*v,9.35*u,yy,2.50*v,shelfM,'metal');
  for (const mz of [2.0*v,3.0*v]) box(g,.08*u,1.70,.06*v,9.05*u,1.05,mz,frame);
  for (const dz of [1.50*v,2.50*v,3.50*v]) {
    box(g,.03*u,1.70,.92*v,9.04*u,1.05,dz,0xbfe3ea,'glass');
  }
  for (let i = 0; i < 9; i++) {
    const door = i%3, lvl = (i/3)|0;
    const yy = [.30,.93,1.43][lvl], zz = (1.50+door)*v;
    if (lvl < 2) box(g,.30*u,.22,.30*v,9.35*u,yy+.22/2,zz,prod[(i*2+4)%9]);
    else cylinder(g,.09*s,.24,9.35*u,yy+.12,zz,prod[(i*2+4)%9],'paint',.09*s,8);
  }
  box(g,.06*u,.40,2.20*v,8.88*u,2.02,2.50*v,panel);
  label(g,'DRINKS',8.84*u,2.05,2.50*v,4,'#bfe9ef',{rotY:-Math.PI/2});
  light(g,9.30*u,1.80,2.50*v,cold,.18);

  // Stepped central promo island with stacked confectionery.
  box(g,1.90*u,.42,1.50*v,6.90*u,.21,5.30*v,wood);
  box(g,1.50*u,.30,1.10*v,6.90*u,.57,5.30*v,dark);
  box(g,1.54*u,.05,1.14*v,6.90*u,.745,5.30*v,wood);
  for (let i = 0; i < 8; i++) {
    const colr = prod[(i*3+2)%9], xx = (6.45+(i%4)*.30)*u, zz = (5.05+((i/4)|0)*.50)*v;
    if (i < 4) box(g,.24*u,.20,.30*v,xx,.85,zz,colr);
    else box(g,.24*u,.16,.30*v,xx,.72+.16/2+.20-.01,zz,colr);
  }

  // Two double-sided gondola aisles, ends grounded, shelves lapped into ends.
  for (const [gx,gz] of [[3.40,3.10],[3.40,5.00]]) {
    box(g,3.0*u,.14,.90*v,gx*u,.07,gz*v,dark);
    box(g,.08*u,1.30,.90*v,(gx-1.50)*u,.65,gz*v,wood);
    box(g,.08*u,1.30,.90*v,(gx+1.50)*u,.65,gz*v,wood);
    for (const yy of [.60,1.05]) {
      box(g,3.0*u,.05,.36*v,gx*u,yy,(gz-.26)*v,shelfM,'metal');
      box(g,3.0*u,.05,.36*v,gx*u,yy,(gz+.26)*v,shelfM,'metal');
    }
    for (let i = 0; i < 12; i++) {
      const side = i%2 ? .26 : -.26, lvl = (i>>1)%2 ? 1.05 : .60;
      const bh = .20+((i*3)%3)*.05;
      box(g,.30*u,bh,.24*v,(gx-1.15+(i>>2)*.55)*u,lvl+.025+bh/2-.01,(gz+side)*v,prod[(i*2+gx)%9]);
    }
  }

  // Promotional endcaps facing the main aisle.
  box(g,.70*u,.50,.50*v,5.15*u,.25,3.10*v,wood);
  box(g,.70*u,.50,.50*v,5.15*u,.25,5.00*v,wood);
  box(g,.34*u,.24,.30*v,5.15*u,.62,3.10*v,prod[0]);
  box(g,.30*u,.20,.28*v,5.15*u,.60,5.00*v,prod[1]);

  // Low entrance promo tables with drink stacks.
  box(g,1.10*u,.40,.70*v,2.0*u,.20,6.70*v,wood);
  box(g,1.10*u,.40,.70*v,8.0*u,.20,6.70*v,wood);
  for (let i = 0; i < 4; i++) {
    cylinder(g,.10*s,.26,(1.75+(i%2)*.45)*u,.53,6.70*v,prod[(i*2)%9],'paint',.10*s,8);
    box(g,.30*u,.22,.30*v,(7.85+(i%2)*.35)*u,.51,6.70*v,prod[(i*2+3)%9]);
  }

  // Category signage on shelf ends + tiny exit hint.
  box(g,.50*u,.30,.06*v,1.95*u,1.95,3.10*v,panel);
  label(g,'SNACKS',1.95*u,1.97,3.14*v,3.6,'#ffe2a8');
  box(g,.50*u,.30,.06*v,1.95*u,1.95,5.00*v,panel);
  label(g,'SWEETS',1.95*u,1.97,5.04*v,3.6,'#ffe2a8');
  box(g,1.10*u,.30,.06*v,8.0*u,2.02,.62*v,panel);
  label(g,'CHECKOUT ->',8.0*u,2.04,.66*v,3.2,'#7fe0e8');

  // Ceiling beams spanning wall to wall, pendants hung from beams.
  for (const bz of [2.0*v,5.0*v]) {
    box(g,9.6*u,.10,.22*v,x,2.93,bz,shell);
    g.children[g.children.length-1].userData.roof = true;
  }
  for (const [lx,lz] of [[3.4,3.1],[3.4,5.0],[6.9,5.3],[9.3,2.5]]) {
    cylinder(g,.015*s,.30,lx*u,2.70,lz*v,dark,'paint',.015*s,6);
    cylinder(g,.07*s,.12,lx*u,2.50,lz*v,wood,'paint',.16*s,10);
    light(g,lx*u,2.42,lz*v,lx>8?cold:warm,.11);
  }
}
