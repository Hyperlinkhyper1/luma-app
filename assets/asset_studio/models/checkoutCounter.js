function checkoutCounter(g,w,d){
  const u = w/5, v = d/4, x = w/2, s = Math.min(u,v);
  const body = 0xd8d3c6, top = 0x3b4347, teal = 0x2a6d7a, struct = 0x555e62;
  const metal = 0x8b9295, pos = 0x343b3e, glow = 0x7fe0e8, term = 0x454d50;
  const postC = 0x737b7e, sign = 0xe5e0d5, merch = [0xb4553f,0x3f5e78,0xc9a86a,0x7a8f6b];

  // Customer approaches from +z. Cashier stands behind at -z.
  box(g,4.8*u,.02,3.8*v,x,.01,2*v,0x2c3134);
  box(g,2.4*u,.02,1.7*v,1.9*u,.02,2.85*v,0x343a3d);

  // Low back storage / bag wall — retail, not a check-in gantry.
  box(g,4.6*u,1.55,.14*v,x,.775,.22*v,body);
  box(g,4.4*u,.08,.16*v,x,1.58,.22*v,struct);
  box(g,1.4*u,.55,.12*v,3.7*u,.90,.32*v,teal);
  for (let i = 0; i < 3; i++) {
    box(g,.32*u,.18,.18*v,(3.3+i*.4)*u,1.28,.34*v,merch[i]);
  }

  // Overhead checkout blade. Cap sits just above 2 m.
  box(g,.08*u,1.05,.08*v,2.4*u,1.85,1.15*v,metal,'metal');
  box(g,1.7*u,.42,.10*v,2.4*u,2.28,1.15*v,pos);
  box(g,1.76*u,.05,.14*v,2.4*u,2.515,1.15*v,struct);
  g.children[g.children.length-1].userData.roof = true;
  box(g,1.5*u,.28,.03*v,2.4*u,2.30,1.21*v,teal);
  label(g,'CHECKOUT',2.4*u,2.34,1.24*v,5.5,'#f9fcf6');
  label(g,'PAY HERE',2.4*u,2.18,1.24*v,3.2,'#7fe0e8');
  light(g,2.4*u,2.30,1.26*v,glow,.10);

  // Layered cashier counter: base, teal fascia, dark top, metal lip.
  box(g,2.55*u,.88,.82*v,1.75*u,.44,1.45*v,body);
  box(g,2.55*u,.48,.06*v,1.75*u,.28,1.85*v,teal);
  box(g,2.65*u,.09,.88*v,1.75*u,.925,1.45*v,top);
  box(g,2.65*u,.03,.90*v,1.75*u,.985,1.45*v,metal,'metal');
  box(g,.10*u,.88,.82*v,.52*u,.44,1.45*v,struct);
  // Lower accessible customer section on the left.
  box(g,.85*u,.68,.70*v,.95*u,.34,1.50*v,body);
  box(g,.85*u,.07,.76*v,.95*u,.715,1.50*v,top);

  // Bagging / collection well on the right of the till.
  box(g,1.15*u,.55,.78*v,3.55*u,.275,1.48*v,struct);
  box(g,1.20*u,.05,.84*v,3.55*u,.575,1.48*v,top);
  box(g,.08*u,.42,.08*v,4.05*u,.36,1.78*v,metal,'metal'); // bag hook post
  box(g,.28*u,.38,.08*v,4.05*u,.42,1.72*v,0x3f5e78);     // hanging bag
  box(g,.32*u,.10,.24*v,3.35*u,.64,1.48*v,0xb4553f);     // purchased box
  box(g,.26*u,.16,.20*v,3.70*u,.67,1.38*v,0xc9a86a);

  // Staff POS: monitor faces -z toward the cashier.
  box(g,.48*u,.32,.04*v,2.05*u,1.26,1.22*v,0x1b2e36);
  g.children[g.children.length-1].rotation.y = Math.PI;
  box(g,.06*u,.20,.06*v,2.05*u,1.08,1.22*v,struct);
  light(g,2.05*u,1.26,1.16*v,glow,.08);
  box(g,.46*u,.03,.22*v,2.05*u,1.01,1.38*v,struct); // keypad
  box(g,.34*u,.12,.28*v,1.45*u,1.04,1.32*v,pos);    // cash drawer
  box(g,.22*u,.14,.18*v,2.55*u,1.07,1.30*v,metal,'metal'); // receipt printer

  // Customer-facing card terminal on the front lip.
  box(g,.18*u,.16,.12*v,1.55*u,1.08,1.86*v,term);
  box(g,.14*u,.10,.02*v,1.55*u,1.12,1.925*v,0x1b2e36);
  light(g,1.55*u,1.12,1.90*v,glow,.04);

  // Cashier stool behind the desk.
  cylinder(g,.15*s,.05,1.75*u,.48,.72*v,pos,'paint',.15*s,10);
  cylinder(g,.035*s,.46,1.75*u,.23,.72*v,metal,'metal',.035*s,8);

  // Compact impulse rack beside the queue — snacks, not a whole store.
  box(g,.42*u,1.15,.38*v,4.45*u,.575,2.55*v,body);
  box(g,.46*u,.05,.42*v,4.45*u,.32,2.55*v,struct);
  box(g,.46*u,.05,.42*v,4.45*u,.70,2.55*v,struct);
  box(g,.46*u,.05,.42*v,4.45*u,1.08,2.55*v,struct);
  for (let i = 0; i < 3; i++) {
    box(g,.28*u,.16,.16*v,4.45*u,(.42+i*.38),2.55*v,merch[(i+1)%4]);
  }

  // Short one-turn queue. Entrance at front-right, approach left-of-center.
  const posts = [
    [.85,3.55],[2.15,3.55],[3.45,3.55],
    [.85,2.55],[3.45,2.55],
    [.85,2.10],[2.05,2.10]
  ];
  for (const [pxu,pzv] of posts) {
    const px = pxu*u, pz = pzv*v;
    cylinder(g,.16*s,.04,px,.02,pz,metal,'metal',.18*s,10);
    cylinder(g,.045*s,.88,px,.46,pz,postC,'metal',.045*s,8);
  }
  const link = (a,b)=>{
    const ax=a[0]*u,az=a[1]*v,bx=b[0]*u,bz=b[1]*v;
    box(g,Math.hypot(bx-ax,bz-az),.04,.028*v,(ax+bx)/2,.72,(az+bz)/2,teal);
    g.children[g.children.length-1].rotation.y = -Math.atan2(bz-az,bx-ax);
  };
  link(posts[0],posts[1]); link(posts[1],posts[2]);
  link(posts[0],posts[3]); link(posts[3],posts[5]);
  link(posts[5],posts[6]); link(posts[2],posts[4]);
  box(g,.32*u,.012,.08*v,2.05*u,.02,3.15*v,teal);
  box(g,.32*u,.012,.08*v,2.05*u,.02,2.55*v,teal);
  label(g,'QUEUE',2.15*u,.02,3.72*v,3.4,'#e5e0d5',{ground:true});
}
