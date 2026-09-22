function flightInfoPanel(g,w,d){
  const u = w, v = d, x = w/2, z = d/2, s = Math.min(u,v);
  const housing = 0x3b4347, frame2 = 0x555e62, metal = 0x8b9295;
  const scr = 0x14252d, scr2 = 0x1b2e36, glow = 0x7fe0e8;
  const teal = 0x2a6d7a, ok = 0x4f8b58, warn = 0xe0b53f;

  // Base plate + pedestal column + neck collar. Screen faces +z.
  box(g,.70*u,.06,.56*v,x,.03,z,housing);
  box(g,.62*u,.05,.48*v,x,.07,z,frame2);
  cylinder(g,.06*s,1.02,x,.60,z,metal,'metal',.06*s,8);
  cylinder(g,.09*s,.08,x,1.115,z,frame2,'paint',.09*s,10);

  // Single portrait display: rear housing, bezel, screen, header, glow.
  box(g,.74*u,1.04,.09*v,x,1.60,z-.04*v,housing);
  box(g,.68*u,.96,.04*v,x,1.60,z+.015*v,frame2);
  box(g,.60*u,.86,.04*v,x,1.58,z+.04*v,scr);
  box(g,.60*u,.14,.05*v,x,1.955,z+.045*v,teal);
  label(g,'DEPARTURES',x-.06*u,1.955,z+.078*v,3.6,'#f9fcf6');
  label(g,'T1',x+.23*u,1.955,z+.078*v,2.6,'#7fe0e8');
  light(g,x,1.55,z+.058*v,glow,.06);

  // Column headers.
  label(g,'TIME',x-.22*u,1.83,z+.072*v,1.9,'#9fd4de');
  label(g,'DESTINATION',x-.01*u,1.83,z+.072*v,1.9,'#9fd4de');
  label(g,'GATE',x+.22*u,1.83,z+.072*v,1.9,'#9fd4de');

  // Five compact flight rows with a status chip on the left edge.
  const rows = [
    ['13:05','TOKYO','A07',ok],
    ['13:20','PARIS','C04',warn],
    ['13:45','BERLIN','B08',ok],
    ['14:10','MADRID','A15',ok],
    ['14:25','ROME','C11',warn],
  ];
  for (let i = 0; i < 5; i++) {
    const [t,dest,gt,col] = rows[i];
    const ry = 1.715-i*.13;
    box(g,.035*u,.06,.03*v,x-.275*u,ry,z+.065*v,col);
    label(g,t,x-.20*u,ry,z+.072*v,2.6,'#f9fcf6');
    label(g,dest,x-.01*u,ry,z+.072*v,2.6,'#f9fcf6');
    label(g,gt,x+.22*u,ry,z+.072*v,2.6,'#cfd8d4');
  }

  // Bottom footer strip with a tiny clock block; top trim caps the housing.
  box(g,.60*u,.05,.04*v,x,1.165,z+.04*v,scr2);
  label(g,'12:38',x,1.165,z+.078*v,2.2,'#7fe0e8');
  box(g,.76*u,.03,.11*v,x,2.125,z-.04*v,metal,'metal');
  box(g,.76*u,.03,.11*v,x,1.075,z-.04*v,metal,'metal');
}
