function trashBins(g,w,d){
  const u = w/2, v = d, x = w/2, z = d/2, s = Math.min(u,v);
  const body = 0x555e62, dark = 0x252b2e, metal = 0x8b9295;
  const waste = 0x4d5356, recycle = 0x3976a8, cans = 0xe0b53f, sign = 0xd8d3c6;

  // Shared plinth + lower trim rail tie all three bays into one fixture.
  box(g,1.82*u,.08,.76*v,x,.04,z,dark);
  box(g,1.76*u,.06,.70*v,x,.09,z,metal,'metal');

  // Unified outer shell, stepped lower cabinet, and upper chute hood.
  box(g,1.72*u,.72,.62*v,x,.46,z,body);
  box(g,.05*u,.74,.64*v,x-.845*u,.46,z,metal,'metal');
  box(g,.05*u,.74,.64*v,x+.845*u,.46,z,metal,'metal');
  box(g,1.74*u,.04,.64*v,x,.83,z,metal,'metal');
  // Stepped chute hood: rear taller than front for a sloped airport silhouette.
  box(g,1.70*u,.24,.58*v,x,.95,z-.01*v,body);
  box(g,1.68*u,.10,.34*v,x,1.10,z-.12*v,body);
  box(g,1.72*u,.03,.36*v,x,1.155,z-.12*v,metal,'metal');

  // Two metal dividers split the shell into 3 clear compartments.
  for (const dx of [-.28, .28]) {
    box(g,.03*u,.90,.63*v,x+dx*u,.54,z,metal,'metal');
  }

  // Front service-door panels + color-coded category headers + labels.
  const bays = [
    [-.56, waste,   'WASTE'],
    [0,    recycle, 'RECYCLE'],
    [.56,  cans,    'BOTTLES']
  ];
  for (const [bx,col,txt] of bays) {
    const px = x+bx*u;
    box(g,.48*u,.54,.04*v,px,.44,z+.31*v,col===waste?0x464d50:body);
    box(g,.48*u,.08,.05*v,px,.75,z+.315*v,col);
    box(g,.50*u,.05,.32*v,px,1.08,z-.12*v,col);
    label(g,txt,px,.75,z+.348*v,2.2,col===cans?'#252b2e':'#f9fcf6');
  }

  // Distinct disposal openings on the front chute face (easy to read at 30 m):
  // Left: wide rectangular mouth for general waste.
  box(g,.42*u,.15,.16*v,x-.56*u,.96,z+.23*v,dark);
  // Centre: narrow horizontal slot with light-grey surround for paper/card.
  box(g,.44*u,.12,.14*v,x,.96,z+.22*v,sign);
  box(g,.38*u,.045,.16*v,x,.96,z+.23*v,dark);
  // Right: twin round bottle/can holes in a yellow collar plate.
  box(g,.44*u,.14,.14*v,x+.56*u,.96,z+.22*v,cans);
  for (const ox of [-.11,.11]) {
    cylinder(g,.065*s,.16,x+(.56+ox)*u,.96,z+.23*v,dark,'paint',.065*s,10);
    g.children[g.children.length-1].rotation.x = Math.PI/2;
  }

  // Low rear header board with color swatches so categories read from behind too.
  box(g,.05*u,.22,.05*v,x-.60*u,1.22,z-.22*v,metal,'metal');
  box(g,.05*u,.22,.05*v,x+.60*u,1.22,z-.22*v,metal,'metal');
  box(g,1.56*u,.18,.05*v,x,1.28,z-.22*v,sign);
  box(g,1.60*u,.03,.07*v,x,1.375,z-.22*v,metal,'metal');
  for (const [bx,col] of bays) {
    box(g,.42*u,.10,.07*v,x+bx*u,1.28,z-.22*v,col);
  }
}
