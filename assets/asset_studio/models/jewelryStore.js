function jewelryStore(g,w,d){
  const u = w/8, v = d/6, x = w/2, z = d/2, s = Math.min(u,v);
  const ivory = 0xf0ebe1, arch = 0xe8e3d9, stone = 0xc9c3b8, darkPan = 0x292d30, dark = 0x1f2325;
  const base = 0x45484a, wood = 0x76543d, lightWood = 0xa17d5d;
  const gold = 0xc6a15b, darkBrass = 0x9b7844, silver = 0xaeb4b5, darkMetal = 0x686d6e;
  const vGreen = 0x405344, vBurgundy = 0x704541, vNavy = 0x394c60;
  const diamond = 0xe7eeee, goldJ = 0xd1aa57, silverJ = 0xbfc6c7, roseGold = 0xc68f7b;
  const emerald = 0x3f7b5a, ruby = 0xa9484c, sapphire = 0x416b94, amethyst = 0x745d8c;
  const warm = 0xffdda6, cool = 0xdff4f2, glassC = 0xcfe0e2;

  // 1. Polished boutique stone floor with dark marble perimeter & navy center rug
  box(g,7.85*u,.04,5.85*v,x,.02,z,stone);
  box(g,7.40*u,.015,5.40*v,x,.042,z,darkPan);
  box(g,3.80*u,.02,3.40*v,x,.055,3.10*v,vNavy);

  // 2. Architectural walls (North back wall, West side wall, East side wall)
  box(g,7.85*u,3.0,.16*v,x,1.5,.15*v,arch);          // North back wall
  box(g,7.60*u,.85,.08*v,x,.43,.23*v,darkPan);       // North luxury lower wainscot
  box(g,7.60*u,.06,.10*v,x,.88,.23*v,gold,'metal');   // Brass wainscot reveal
  box(g,.16*u,3.0,5.65*v,.15*u,1.5,2.95*v,arch);      // West wall
  box(g,.08*u,.85,5.40*v,.23*u,.43,2.95*v,darkPan);  // West wainscot
  box(g,.10*u,.06,5.40*v,.23*u,.88,2.95*v,gold,'metal');
  box(g,.16*u,3.0,5.65*v,w-.15*u,1.5,2.95*v,arch);   // East wall
  box(g,.08*u,.85,5.40*v,w-.23*u,.43,2.95*v,darkPan); // East wainscot
  box(g,.10*u,.06,5.40*v,w-.23*u,.88,2.95*v,gold,'metal');

  // 3. Storefront (+z): pillars, display windows, brass door frame, fascia & VELORA sign
  box(g,.45*u,3.1,.45*v,.32*u,1.55,5.70*v,darkPan);   // Left corner pillar
  box(g,.45*u,3.1,.45*v,w-.32*u,1.55,5.70*v,darkPan); // Right corner pillar
  box(g,.36*u,3.1,.36*v,2.30*u,1.55,5.70*v,darkPan);  // Left portal jamb
  box(g,.36*u,3.1,.36*v,w-2.30*u,1.55,5.70*v,darkPan); // Right portal jamb
  // Brass portal threshold (entrance width ~3.4m)
  box(g,3.35*u,.03,.30*v,x,.045,5.65*v,gold,'metal');
  // Left & right storefront display window vitrines
  for (const wx of [1.31*u, w-1.31*u]) {
    box(g,1.60*u,.46,.20*v,wx,.23,5.72*v,base);
    box(g,1.60*u,1.96,.05*v,wx,1.40,5.72*v,glassC,'glass');
    box(g,1.58*u,.06,.08*v,wx,2.37,5.72*v,gold,'metal');
  }
  // Storefront fascia header & illuminated sign (lid above 2m flagged)
  box(g,7.85*u,.65,.50*v,x,2.78,5.70*v,darkPan);
  box(g,7.90*u,.06,.56*v,x,3.12,5.70*v,gold,'metal');
  g.children[g.children.length-1].userData.roof = true;
  box(g,3.80*u,.46,.10*v,x,2.78,5.91*v,dark);
  label(g,'VELORA',x,2.88,5.98*v,11,'#f9fcf6');
  label(g,'FINE JEWELRY & WATCHES',x,2.64,5.98*v,3.2,'#c6a15b');
  light(g,x,2.78,5.85*v,warm,.15);
  light(g,1.31*u,2.76,5.80*v,cool,.11);
  light(g,w-1.31*u,2.76,5.80*v,cool,.11);

  // 4. Storefront Showcase Displays (inside the window vitrines)
  // Left window: Haute Joaillerie necklace bust on velvet burgundy pedestal
  box(g,.75*u,.44,.55*v,1.31*u,.47,5.35*v,base);
  box(g,.70*u,.05,.50*v,1.31*u,.695,5.35*v,vBurgundy);
  box(g,.58*u,.56,.42*v,1.31*u,.95,5.35*v,glassC,'glass');
  box(g,.24*u,.34,.16*v,1.31*u,.88,5.35*v,darkPan);  // necklace bust silhouette
  cylinder(g,.07*s,.03,1.31*u,.96,5.35*v,goldJ,'metal',.06*s,8); // royal collar
  sphere(g,1.31*u,.85,5.39*v,.025*s,.035*s,.025*s,ruby);        // ruby pendant drop

  // Right window: Timepiece & solitaire pedestal on velvet green
  box(g,.75*u,.44,.55*v,w-1.31*u,.47,5.35*v,base);
  box(g,.70*u,.05,.50*v,w-1.31*u,.695,5.35*v,vGreen);
  box(g,.58*u,.56,.42*v,w-1.31*u,.95,5.35*v,glassC,'glass');
  cylinder(g,.06*s,.14,w-1.42*u,.775,5.35*v,darkMetal,'metal',.06*s,8); // watch stand
  cylinder(g,.04*s,.035,w-1.42*u,.85,5.35*v,goldJ,'metal',.04*s,8);     // watch bezel
  box(g,.14*u,.12,.14*v,w-1.18*u,.755,5.35*v,vBurgundy);                  // ring box
  cylinder(g,.03*s,.04,w-1.18*u,.815,5.35*v,roseGold,'metal',.03*s,6);   // solitaire ring
  sphere(g,w-1.18*u,.86,5.35*v,.018*s,.018*s,.018*s,diamond);

  // 5. Central Signature Showcase (The Octagonal/Curved Masterpiece Vitrine)
  const cx = x, cz = 3.10*v;
  // Tiered base with gold reveal
  cylinder(g,.95*s,.55,cx,.275,cz,base,'paint',.95*s,12);
  cylinder(g,.98*s,.05,cx,.57,cz,gold,'metal',.98*s,12);
  cylinder(g,.86*s,.06,cx,.62,cz,darkPan,'paint',.86*s,12);
  cylinder(g,.80*s,.03,cx,.66,cz,vGreen,'paint',.80*s,12); // emerald green velvet presentation deck
  // Glass showcase dome & brass crown
  cylinder(g,.84*s,.68,cx,.95,cz,glassC,'glass',.84*s,12);
  cylinder(g,.86*s,.05,cx,1.30,cz,gold,'metal',.86*s,12);
  // Inside Central Showcase: Prominent elevated necklace bust + rings & earrings
  cylinder(g,.24*s,.16,cx,.75,cz,darkBrass,'metal',.20*s,8); // elevated center plinth
  box(g,.30*u,.40,.18*v,cx,.97,cz,vBurgundy);               // velvet bust
  cylinder(g,.09*s,.035,cx,1.06,cz,goldJ,'metal',.08*s,8);   // gold choker chain
  sphere(g,cx,.92,cz+.08*v,.03*s,.04*s,.03*s,emerald);       // emerald pendant
  // Flanking ring cushions
  for (const ox of [-.38*u, .38*u]) {
    box(g,.18*u,.08,.16*v,cx+ox,.71,cz,vBurgundy);
    cylinder(g,.032*s,.035,cx+ox,.77,cz,goldJ,'metal',.032*s,6);
    sphere(g,cx+ox,.80,cz, .018*s,.018*s,.018*s,diamond);
  }
  // Sapphire & diamond drop earring stands
  box(g,.08*u,.16,.08*v,cx, .75, cz-.36*v, darkMetal,'metal');
  sphere(g,cx-.03*u,.83,cz-.36*v,.02*s,.03*s,.02*s,sapphire);
  sphere(g,cx+.03*u,.83,cz-.36*v,.02*s,.03*s,.02*s,sapphire);
  // Focused cool jewelry spotlight
  light(g,cx,1.60,cz,cool,.14);

  // 6. West Long Vitrine Counter (Rings, Cuffs & Diamond Sets)
  const wx2 = 1.35*u, wz2 = 2.90*v;
  box(g,.75*u,.58,2.30*v,wx2,.29,wz2,base);
  box(g,.78*u,.05,2.34*v,wx2,.585,wz2,gold,'metal');
  box(g,.70*u,.38,2.20*v,wx2,.76,wz2,glassC,'glass');
  box(g,.72*u,.05,2.22*v,wx2,.955,wz2,gold,'metal');
  // Inside West Vitrine: 3 contrasting velvet presentation trays
  // Tray 1: Rings on navy velvet
  box(g,.45*u,.03,.62*v,wx2,.62,wz2-.70*v,vNavy);
  for (let i = 0; i < 3; i++) {
    cylinder(g,.026*s,.03,wx2,.645,wz2-(.85-i*.15)*v,i===1?silverJ:goldJ,'metal',.026*s,6);
    sphere(g,wx2,.665,wz2-(.85-i*.15)*v,.015*s,.015*s,.015*s,diamond);
  }
  // Tray 2: Bracelets & cuffs on emerald velvet
  box(g,.45*u,.03,.62*v,wx2,.62,wz2,vGreen);
  cylinder(g,.07*s,.035,wx2,.66,wz2-.15*v,goldJ,'metal',.07*s,8);
  cylinder(g,.07*s,.035,wx2,.66,wz2+.15*v,roseGold,'metal',.07*s,8);
  // Tray 3: Colored gemstones on burgundy velvet
  box(g,.45*u,.03,.62*v,wx2,.62,wz2+.70*v,vBurgundy);
  cylinder(g,.05*s,.03,wx2,.645,wz2+.60*v,silverJ,'metal',.05*s,6);
  sphere(g,wx2,.675,wz2+.60*v,.025*s,.025*s,.025*s,amethyst);
  cylinder(g,.05*s,.03,wx2,.645,wz2+.80*v,goldJ,'metal',.05*s,6);
  sphere(g,wx2,.675,wz2+.80*v,.025*s,.025*s,.025*s,ruby);
  light(g,wx2,1.25,wz2,cool,.12);

  // 7. North Back Wall: Haute Horlogerie & High Jewelry Gallery
  // Central Watch Wall Vitrine (x=4.0, z=0.5)
  box(g,2.80*u,1.80,.16*v,x,1.40,.24*v,darkPan);
  box(g,2.86*u,.05,.20*v,x,2.32,.24*v,gold,'metal');
  box(g,2.60*u,.04,.36*v,x,.95,.42*v,vNavy);    // lower watch shelf
  box(g,2.60*u,.04,.36*v,x,1.45,.42*v,glassC,'glass'); // upper glass shelf
  label(g,'HAUTE HORLOGERIE',x,2.15,.35*v,3.5,'#c6a15b');
  // Watch presentation stands on lower & upper shelves
  for (const bx of [3.0*u, 3.65*u, 4.35*u, 5.0*u]) {
    cylinder(g,.045*s,.09,bx,1.01,.42*v,darkMetal,'metal',.045*s,6);
    cylinder(g,.035*s,.025,bx,1.07,.42*v,goldJ,'metal',.035*s,8);
  }
  for (const bx of [3.35*u, 4.65*u]) {
    cylinder(g,.045*s,.09,bx,1.51,.42*v,darkMetal,'metal',.045*s,6);
    cylinder(g,.035*s,.025,bx,1.57,.42*v,silverJ,'metal',.035*s,8);
  }
  // Flanking North Wall Vitrines: Left (Diamond Suite), Right (Royal Gems)
  for (const [nx,ncol,gem] of [[1.45*u,vNavy,diamond],[w-1.45*u,vBurgundy,emerald]]) {
    box(g,1.20*u,1.60,.14*v,nx,1.35,.24*v,darkPan);
    box(g,1.24*u,.06,.18*v,nx,2.16,.24*v,gold,'metal');
    box(g,1.10*u,.90,.04*v,nx,1.35,.32*v,glassC,'glass');
    box(g,.35*u,.38,.12*v,nx,1.15,.28*v,ncol); // presentation board
    sphere(g,nx,1.15,.35*v,.03*s,.045*s,.03*s,gem);
  }
  light(g,x,1.90,.55*v,cool,.14);

  // 8. Consultation / VIP Private Service Area (East side, x=6.65, z=2.85)
  const sx = w-1.35*u, sz = 2.85*v;
  // Consultation desk with leather/stone top & gold legs
  box(g,.75*u,.58,1.90*v,sx,.29,sz,wood);
  box(g,.80*u,.06,1.95*v,sx,.595,sz,darkPan);
  box(g,.78*u,.03,1.90*v,sx,.63,sz,gold,'metal');
  // Black velvet inspection pad (sunk into brass reveal)
  box(g,.45*u,.03,.65*v,sx,.65,sz,vBurgundy);
  // Ring sizer & magnifying loupe on desk
  cylinder(g,.035*s,.04,sx,.67,sz-.50*v,gold,'metal',.035*s,8);
  box(g,.10*u,.04,.10*v,sx,.66,sz+.50*v,darkMetal,'metal');
  // Two VIP client consultation chairs (facing east toward desk)
  for (const cz of [sz-.45*v, sz+.45*v]) {
    cylinder(g,.025*s,.40,sx-.75*u,.22,cz,darkMetal,'metal',.025*s,6); // chair legs
    box(g,.42*u,.10,.42*v,sx-.75*u,.44,cz,vNavy);                      // chair seat
    box(g,.08*u,.42,.42*v,sx-.98*u,.62,cz,vNavy);                      // chair back
  }
  // Gemologist / Store associate behind the desk (facing west)
  box(g,.26*u,.50,.22*v,sx+.58*u,.25,sz,trouser=0x222629);
  box(g,.34*u,.54,.24*v,sx+.58*u,.75,sz,darkPan);
  box(g,.10*u,.32,.08*v,sx+.46*u,.80,sz,ivory);
  sphere(g,sx+.58*u,1.15,sz,.12*s,.14*s,.12*s,0xd8b49a);
  // Back security credenza / safe with brass hardware
  box(g,.35*u,.86,1.40*v,w-.35*u,.46,sz,darkPan);
  box(g,.38*u,.06,1.45*v,w-.35*u,.875,sz,gold,'metal');

  // 9. Full-length gilded customer mirror on West wall
  box(g,.06*u,1.75,.75*v,.22*u,1.45,4.65*v,gold,'metal');
  box(g,.03*u,1.65,.65*v,.24*u,1.45,4.65*v,glassC,'glass');

  // 10. Ceiling Beams & Luxury Pendant Lighting
  box(g,7.50*u,.10,.20*v,x,2.92,1.80*v,darkPan);
  g.children[g.children.length-1].userData.roof = true;
  box(g,7.50*u,.10,.20*v,x,2.92,4.30*v,darkPan);
  g.children[g.children.length-1].userData.roof = true;
  // Suspended brass cylinder downlights over key areas
  for (const [px2,pz2] of [[x,3.10*v],[wx2,wz2],[sx,sz]]) {
    cylinder(g,.015*s,.30,px2,2.74,pz2,darkMetal,'metal',.015*s,6);
    cylinder(g,.07*s,.14,px2,2.54,pz2,gold,'metal',.14*s,8);
    light(g,px2,2.44,pz2,warm,.10);
  }
}
