function checkInCounter(g,w,d){
  const u = w/6, v = d/5, x = w/2, s = Math.min(u,v);
  const body = 0xd8d3c6, top = 0x3b4347, struct = 0x555e62, metal = 0x8b9295;
  const teal = 0x2a6d7a, dpanel = 0x1b2e36, glow = 0x7fe0e8, belt = 0x343b3e;
  const beltTop = 0x454d50, post = 0x737b7e, yellow = 0xf2c230, sign = 0xe5e0d5;

  // Passenger approaches from +z (front). Staff stand behind at -z.
  // Desk band sits across the rear third; queue + open floor fill the front.
  box(g,5.8*u,.02,4.8*v,x,.01,2.5*v,0x2b3033);
  box(g,2.2*u,.02,1.9*v,2.15*u,.02,2.7*v,0x323a3d); // subtle queue lane inlay

  // ---- Staff back wall + overhead check-in sign ----
  box(g,5.6*u,2.15,.16*v,x,1.075,.30*v,body);
  box(g,5.6*u,.10,.20*v,x,2.18,.30*v,struct);
  // Raised illuminated sign gantry (lid above 2m)
  box(g,3.0*u,.62,.14*v,2.0*u,2.62,.42*v,dpanel);
  box(g,3.06*u,.05,.18*v,2.0*u,2.955,.42*v,struct);
  g.children[g.children.length-1].userData.roof = true;
  box(g,2.8*u,.42,.03*v,2.0*u,2.62,.50*v,teal);
  label(g,'CHECK-IN',2.0*u,2.70,.52*v,7,'#f9fcf6');
  label(g,'ZONE A  DESK 3',2.0*u,2.48,.52*v,3.6,'#7fe0e8');
  light(g,2.0*u,2.62,.55*v,glow,.16);
  // Small flight strip on the back wall
  box(g,1.5*u,.5,.03*v,4.55*u,1.65,.40*v,dpanel);
  label(g,'FLT 228  14:35',4.55*u,1.75,.42*v,3,'#7fe0e8');
  label(g,'BOARDING SOON',4.55*u,1.58,.42*v,2.4,'#e5e0d5');
  light(g,4.55*u,1.65,.44*v,glow,.10);

  // ---- Main staffed counter (passenger-facing, front at z ~1.9) ----
  // Layered body: recessed base, colored front panel, dark worktop, metal trim.
  box(g,3.5*u,.90,.95*v,2.0*u,.45,1.55*v,body);
  box(g,3.5*u,.55,.06*v,2.0*u,.30,2.02*v,teal);       // teal front panel
  box(g,3.6*u,.10,1.02*v,2.0*u,.95,1.55*v,top);       // dark worktop
  box(g,3.6*u,.03,1.04*v,2.0*u,1.015,1.55*v,metal,'metal');
  box(g,.10*u,.90,.95*v,.30*u,.45,1.55*v,struct);     // left side pillar
  // Lower accessible service section on the left end
  box(g,1.0*u,.72,.85*v,.85*u,.36,1.58*v,body);
  box(g,1.0*u,.08,.92*v,.85*u,.76,1.58*v,top);
  box(g,1.0*u,.03,.94*v,.85*u,.795,1.58*v,metal,'metal');

  // ---- Staff-side workstation (monitors face -z toward worker) ----
  // Monitor on a stalk, screen glow toward staff standing at the back.
  box(g,.55*u,.34,.04*v,2.35*u,1.30,1.28*v,dpanel);
  g.children[g.children.length-1].rotation.y = Math.PI;
  box(g,.06*u,.22,.06*v,2.35*u,1.12,1.28*v,struct);
  light(g,2.35*u,1.30,1.22*v,glow,.09);
  // Secondary small screen
  box(g,.34*u,.24,.04*v,3.1*u,1.24,1.30*v,dpanel);
  light(g,3.1*u,1.24,1.24*v,glow,.06);
  // Keyboard / work surface hint + boarding-pass printer
  box(g,.5*u,.03,.24*v,2.4*u,1.02,1.42*v,struct);
  box(g,.3*u,.16,.26*v,1.55*u,1.09,1.40*v,metal,'metal');
  box(g,.24*u,.02,.14*v,1.55*u,1.18,1.40*v,teal); // tag printer slot
  // Staff stool suggestion behind the desk
  cylinder(g,.16*s,.06,2.0*u,.5,.72*v,dpanel,'paint',.16*s,10);
  cylinder(g,.04*s,.5,2.0*u,.25,.72*v,metal,'metal',.04*s,8);

  // ---- Baggage acceptance: scale platform + short belt to the right ----
  // Weigh platform recessed at floor by the counter.
  box(g,1.15*u,.14,1.0*v,4.55*u,.07,1.75*v,metal,'metal');
  box(g,1.0*u,.03,.85*v,4.55*u,.155,1.75*v,beltTop);
  box(g,.34*u,.20,.06*v,4.55*u,.30,2.24*v,dpanel);   // small weight display
  label(g,'23.0 kg',4.55*u,.33,2.28*v,2.6,'#7fe0e8');
  light(g,4.55*u,.30,2.27*v,glow,.05);
  // Short conveyor running back toward the wall (behind-the-scenes).
  box(g,1.2*u,.44,1.55*v,4.55*u,.22,.95*v,belt);
  box(g,1.05*u,.05,1.5*v,4.55*u,.47,.95*v,beltTop);
  for (let i = 0; i < 4; i++) box(g,1.05*u,.02,.05*v,4.55*u,.50,(.35+i*.4)*v,belt); // rollers
  box(g,.06*u,.30,1.55*v,4.0*u,.62,.95*v,yellow);    // yellow edge guard
  box(g,.06*u,.30,1.55*v,5.1*u,.62,.95*v,yellow);
  // One suitcase on the belt, one on the floor awaiting handover.
  box(g,.5*u,.34,.4*v,4.55*u,.66,1.0*v,0x8d3f3a);
  box(g,.5*u,.03,.4*v,4.55*u,.84,1.0*v,0x6e302c);
  box(g,.46*u,.34,.42*v,4.55*u,.31,2.7*v,0x33566b);
  box(g,.10*u,.05,.16*v,4.55*u,.51,2.7*v,metal,'metal'); // suitcase handle

  // ---- Small organized passenger queue (front, +z), one turn ----
  // posts with round bases; teal belts between them. Entrance at front-right.
  const posts = [
    [1.05,4.55],[2.35,4.55],[3.55,4.55],   // back rail (entrance side)
    [1.05,3.35],[3.55,3.35],               // mid
    [1.05,2.55],[2.35,2.55]                // final approach lane to desk
  ];
  for (const [pxu,pzv] of posts) {
    const px = pxu*u, pz = pzv*v;
    cylinder(g,.20*s,.05,px,.025,pz,metal,'metal',.22*s,10);
    cylinder(g,.05*s,.95,px,.50,pz,post,'metal',.05*s,8);
    cylinder(g,.08*s,.06,px,.98,pz,post,'metal',.08*s,8);
  }
  // Retractable belts (thin boxes) linking the path.
  const link=(a,b,h)=>{
    const ax=a[0]*u,az=a[1]*v,bx=b[0]*u,bz=b[1]*v;
    const mx=(ax+bx)/2,mz=(az+bz)/2;
    const len=Math.hypot(bx-ax,bz-az);
    box(g,len,.05,.03*v,mx,h,mz,teal);
    g.children[g.children.length-1].rotation.y=-Math.atan2(bz-az,bx-ax);
  };
  link(posts[0],posts[1],.80); link(posts[1],posts[2],.80); // entrance rail
  link(posts[0],posts[3],.80);                              // left guide
  link(posts[3],posts[5],.80);                              // left guide 2
  link(posts[5],posts[6],.80);                              // final lane
  link(posts[2],posts[4],.80);                              // right guide
  // Floor directional dashes toward the desk.
  for (let i=0;i<3;i++) box(g,.4*u,.012,.10*v,2.0*u,.02,(3.9-i*.6)*v,yellow);
  label(g,'QUEUE HERE',2.3*u,.02,4.75*v,4,'#f2c230',{ground:true});
}
