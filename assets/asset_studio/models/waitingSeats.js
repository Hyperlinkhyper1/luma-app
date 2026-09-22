function waitingSeats(g,w,d){
  const x = w / 2, z = d / 2, sx = w / 4, sz = d / 2;
  const seat = 0x465b66, frame = 0x8b9295, arm = 0x3b4347, teal = 0x2a6d7a;

  // One shared beam on two pedestals carries everything: four seats,
  // five armrests, and a raised back rail. Seats face +z.
  box(g,3.50*sx,.10,.12*sz,x,.30,z-.02*sz,frame,'metal');
  box(g,.08*sx,.12,.14*sz,x-1.79*sx,.30,z-.02*sz,teal);
  box(g,.08*sx,.12,.14*sz,x+1.79*sx,.30,z-.02*sz,teal);
  for (const side of [-1,1]) {
    const px = x+side*1.0*sx;
    box(g,.16*sx,.04,1.40*sz,px,.02,z,frame,'metal');
    box(g,.12*sx,.28,.16*sz,px,.16,z-.02*sz,frame,'metal');
    box(g,.06*sx,.46,.06*sz,px,.53,z-.20*sz,frame,'metal');
  }
  box(g,3.40*sx,.05,.06*sz,x,.40,z+.15*sz,frame,'metal');
  box(g,3.40*sx,.06,.06*sz,x,.72,z-.20*sz,frame,'metal');

  // Seats: pan, lower back, upper back stepped rearward for a reclined feel.
  for (let i = 0; i < 4; i++) {
    const cx = x+(-1.2+.8*i)*sx;
    box(g,.62*sx,.09,.50*sz,cx,.45,z+.15*sz,seat);
    box(g,.60*sx,.28,.08*sz,cx,.60,z-.14*sz,seat);
    box(g,.58*sx,.32,.07*sz,cx,.88,z-.19*sz,seat);
  }

  // Armrests between and at both ends of the row.
  for (let i = 0; i < 5; i++) {
    const ax = x+(-1.6+.8*i)*sx;
    box(g,.05*sx,.22,.06*sz,ax,.53,z+.05*sz,frame,'metal');
    box(g,.08*sx,.05,.46*sz,ax,.66,z+.10*sz,arm);
  }

  // Charging pod under the centre armrest.
  box(g,.07*sx,.07,.12*sz,x,.49,z+.14*sz,teal);
}
