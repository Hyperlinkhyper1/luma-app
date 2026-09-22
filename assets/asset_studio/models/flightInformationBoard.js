function flightInformationBoard(g,w,d){
  const u = w/4, v = d, x = w/2, z = d/2, s = Math.min(u,v);
  const frame = 0x3b4347, frame2 = 0x555e62, metal = 0x8b9295;
  const scr = 0x14252d, scr2 = 0x1b2e36, glow = 0x7fe0e8;
  const teal = 0x2a6d7a, dep = 0x3976a8, ok = 0x4f8b58, warn = 0xe0b53f, alert = 0xc95a50;
  const F = z+.30*v, B = z-.30*v;   // active screen faces; content rides just proud

  // Base, brace and posts.
  box(g,2.6*u,.10,.74*v,x,.05,z,frame);
  box(g,2.4*u,.06,.62*v,x,.115,z,frame2);
  box(g,2.0*u,.10,.12*v,x,.45,z,frame2);
  cylinder(g,.08*s,1.00,1.05*u,.62,z,metal,'metal',.08*s,8);
  cylinder(g,.08*s,1.00,2.95*u,.62,z,metal,'metal',.08*s,8);

  // Central spine housing + cap (lid above 2 m).
  box(g,3.90*u,1.98,.44*v,x,1.64,z,frame);
  box(g,3.92*u,.06,.50*v,x,2.655,z,metal,'metal');
  g.children[g.children.length-1].userData.roof = true;

  // Front face stack: bezel, screen, teal header band, glow.
  box(g,3.84*u,1.84,.05*v,x,1.60,z+.225*v,frame2);
  box(g,3.66*u,1.46,.06*v,x,1.49,z+.27*v,scr);
  box(g,3.66*u,.26,.07*v,x,2.40,z+.275*v,teal);
  label(g,'DEPARTURES',.70*u,2.40,z+.31*v,7,'#f9fcf6');
  label(g,'T1',3.60*u,2.40,z+.31*v,5,'#7fe0e8');
  light(g,x,1.60,z+.33*v,glow,.12);

  // Back face stack mirrors the front.
  box(g,3.84*u,1.84,.05*v,x,1.60,z-.225*v,frame2);
  box(g,3.66*u,1.46,.06*v,x,1.49,z-.27*v,scr);
  box(g,3.66*u,.26,.07*v,x,2.40,z-.275*v,teal);
  label(g,'DEPARTURES',.70*u,2.40,z-.31*v,7,'#f9fcf6',{rotY:Math.PI});
  label(g,'T1',3.60*u,2.40,z-.31*v,5,'#7fe0e8',{rotY:Math.PI});
  light(g,x,1.60,z-.33*v,glow,.12);

  // Column headers on the front screen.
  for (const [cx,txt] of [[.66,'TIME'],[1.50,'DESTINATION'],[2.52,'FLIGHT'],[3.05,'GATE'],[3.55,'STATUS']]) {
    label(g,txt,cx*u,2.10,F+.001*v,3,'#9fd4de');
  }

  // Six flight rows: chip | time | destination | flight | gate | status.
  const rows = [
    ['12:40','LONDON','AX241','B12','BOARDING',teal,'#7fe0e8'],
    ['13:05','TOKYO','VX882','A07','ON TIME',ok,'#8fd39b'],
    ['13:20','PARIS','NX104','C04','DELAYED',warn,'#e6c25e'],
    ['13:45','BERLIN','QF331','B08','ON TIME',ok,'#8fd39b'],
    ['14:10','MADRID','LX520','A15','GATE OPEN',dep,'#8fc0e8'],
    ['14:25','ATHENS','SR097','D02','FINAL CALL',alert,'#e89a92'],
  ];
  for (let i = 0; i < 6; i++) {
    const [t,dest,fl,gt,st,col,txt] = rows[i];
    const ry = 1.86-i*.19;
    box(g,.10*u,.10,.02*v,.33*u,ry,F,col);
    label(g,t,.66*u,ry,F+.001*v,5,'#f9fcf6');
    label(g,dest,1.50*u,ry,F+.001*v,5,'#f9fcf6');
    label(g,fl,2.52*u,ry,F+.001*v,4,'#cfd8d4');
    label(g,gt,3.05*u,ry,F+.001*v,4,'#cfd8d4');
    label(g,st,3.55*u,ry,F+.001*v,4,txt);
  }

  // Back rows: compact mirrored list for the opposite corridor.
  const back = [
    ['12:55','OSLO NX302 A02',ok],
    ['13:15','DUBLIN AX118 C01',teal],
    ['13:30','ROME VX405 B04',warn],
    ['13:50','VIENNA NX227 A09',ok],
    ['14:05','HELSINKI SR611 D06',dep],
    ['14:20','ZURICH LX083 C07',warn],
  ];
  for (let i = 0; i < 6; i++) {
    const [t,combo,col] = back[i];
    const ry = 1.86-i*.19;
    box(g,.10*u,.10,.02*v,.33*u,ry,B,col);
    label(g,t,1.10*u,ry,B-.001*v,5,'#f9fcf6',{rotY:Math.PI});
    label(g,combo,2.60*u,ry,B-.001*v,4.5,'#cfd8d4',{rotY:Math.PI});
  }

  // Twin clock crowning the board (second lid above 2 m).
  box(g,1.15*u,.33,.34*v,x,2.83,z,frame);
  g.children[g.children.length-1].userData.roof = true;
  cylinder(g,.12*s,.03,x,2.83,z+.165*v,scr2,'paint',.12*s,10);
  g.children[g.children.length-1].rotation.x = Math.PI/2;
  cylinder(g,.12*s,.03,x,2.83,z-.165*v,scr2,'paint',.12*s,10);
  g.children[g.children.length-1].rotation.x = Math.PI/2;
  box(g,.015*u,.09,.02*v,x,2.855,z+.184*v,'#f9fcf6');
  box(g,.055*u,.015,.02*v,x+.02*u,2.83,z+.184*v,'#f9fcf6');

  // Terminal directory strip on the plinth front.
  box(g,1.5*u,.12,.06*v,x,.155,z+.37*v,teal);
  label(g,'TERMINAL 1 - LEVEL B',x,.155,z+.40*v,3,'#f9fcf6',{background:'#3b4347',width:1.3});
}
