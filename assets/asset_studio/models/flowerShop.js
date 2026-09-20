function flowerShop(g,w,d){
  const u = w/6, v = d/5, x = w/2, z = d/2, s = Math.min(u,v);
  const ivory = 0xe8e1d5, grey = 0xd8d3c6, wood = 0x8a6748, lightWood = 0xa9825d;
  const dark = 0x3b4347, metal = 0x8b9295, green = 0x47704f, leafD = 0x31563b, leafL = 0x6f9365;
  const accent = 0x8d6f88, glassC = 0xcfe0e2, warm = 0xffdda6, cool = 0xd8f0ef;
  const pink = 0xd9829b, lpink = 0xe6aeb8, red = 0xc95a50, yellow = 0xe2c84b;
  const orange = 0xe69b52, purple = 0x8b72a1, lavender = 0xaa93bd, cream = 0xeee8dc, blue = 0x668eae;

  // Lean stylised bouquet: wrap, collar, five heads, foliage (9 calls).
  function bouquet(px,pz,py,sc,head){
    box(g,.30*sc,.30*sc,.30*sc,px*u,py+.15*sc,pz*v,cream);
    box(g,.10*sc,.22*sc,.10*sc,px*u,py+.34*sc,pz*v,green);
    cylinder(g,.012*sc,.30*sc,px*u,py+.36*sc,pz*v,leafD,'paint',.012*sc,6);
    sphere(g,px*u,(py+.53*sc)*u,pz*v,.075*sc,.075*sc,.075*sc,head);
    const sides=[[-.11,.42,.03],[.11,.43,.02],[-.05,.48,-.05],[.07,.47,.06]];
    for (const [ox,oy,oz] of sides)
      sphere(g,(px+ox)*u,(py+oy)*u,(pz+oz)*v,.065*sc,.065*sc,.065*sc,head);
    sphere(g,(px-.04*sc/u)*u,(py+.40)*u,(pz+.10*sc/v)*v,.05*sc,.05*sc,.05*sc,leafL);
  }
  // Metal florist bucket with a colour-grouped fan of heads.
  function bucket(px,pz,heads,baseY){
    baseY = baseY || 0;
    cylinder(g,.13*s,.24,px*u,baseY+.12,pz*v,metal,'metal',.10*s,10);
    for (let i=0;i<heads.length;i++){
      const ox=(i-(heads.length-1)/2)*.07;
      cylinder(g,.012*s,.34,(px+ox)*u,baseY+.36,pz*v,leafD,'paint',.012*s,6);
      sphere(g,(px+ox)*u,baseY+.55,pz*v,.055*s,.055*s,.055*s,heads[i]);
    }
  }
  // Small potted plant.
  function plant(px,pz,ps,pot){
    cylinder(g,.14*ps,.22,px*u,.11,pz*v,pot,'paint',.11*ps,10);
    cylinder(g,.025*ps,.30,px*u,.34,pz*v,wood,'paint',.025*ps,6);
    sphere(g,px*u,.56*ps,pz*v,.22*ps,.26*ps,.22*ps,leafD);
    sphere(g,(px-.14*ps)*u,.46*ps,(pz+.06*ps/v)*v,.14*ps,.17*ps,.14*ps,leafL);
    sphere(g,(px+.13*ps)*u,.50*ps,(pz-.05*ps/v)*v,.13*ps,.16*ps,.13*ps,green);
  }
  // Wall planter box with three flower heads.
  function wallPlanter(px,py,pz,heads){
    box(g,.34,.24,.28,px*u,py,pz*v,wood);
    for (let i=0;i<3;i++)
      sphere(g,(px+(i-1)*.13)*u,py+.20,pz*v+.02,.07*s,.07*s,.07*s,heads[i]);
  }

  // ===== Floor with welcome inlay =====
  box(g,5.85*u,.04,4.85*v,x,.02,z,grey);
  box(g,2.30*u,.025,.85*v,1.52*u,.045,4.42*v,accent);
  label(g,'FRESH FLOWERS',1.52*u,.05,4.40*v,2.6,green,{ground:true});

  // ===== Three finished walls: wood wainscot + cap rails =====
  box(g,5.85*u,2.90,.14*v,x,1.45,.20*v,ivory);          // north
  box(g,.14*u,2.90,4.70*v,.20*u,1.45,2.45*v,grey);       // west
  box(g,.16*u,2.90,4.70*v,5.80*u,1.45,2.45*v,ivory);     // east
  box(g,5.65*u,.80,.08*v,x,.40,.28*v,lightWood);
  box(g,.08*u,.80,4.50*v,.28*u,.40,2.45*v,lightWood);
  box(g,.08*u,.80,4.50*v,5.72*u,.40,2.45*v,lightWood);
  box(g,5.70*u,.08,.20*v,x,2.86,.22*v,wood);
  box(g,.20*u,.08,4.55*v,.20*u,2.86,2.45*v,wood);
  box(g,.20*u,.08,4.55*v,5.80*u,2.86,2.45*v,wood);

  // ===== Storefront: open pergola door (left) + two-pane window (right) =====
  box(g,.42*u,3.0,.42*v,.42*u,1.50,4.72*v,ivory);
  box(g,.42*u,3.0,.42*v,2.62*u,1.50,4.72*v,ivory);
  box(g,.42*u,3.0,.42*v,5.58*u,1.50,4.72*v,ivory);
  box(g,5.85*u,.62,.42*v,x,2.78,4.72*v,ivory);
  box(g,5.90*u,.06,.50*v,x,3.07,4.72*v,green);
  g.children[g.children.length-1].userData.roof = true;
  // Shop sign over the door.
  box(g,2.30*u,.42,.06*v,1.52*u,2.80,4.95*v,accent);
  label(g,'PETAL & STEM',1.52*u,2.87,4.99*v,6,'#f9fcf6');
  label(g,'FLORIST',1.52*u,2.68,4.99*v,3.4,'#31563b');
  light(g,1.52*u,2.55,4.95*v,warm,.12);
  // Glass display window with bulkhead and mullion.
  box(g,2.62*u,.40,.18*v,4.10*u,.20,4.74*v,dark);
  box(g,1.22*u,2.00,.05*v,3.43*u,1.43,4.90*v,glassC,'glass');
  box(g,1.22*u,2.00,.05*v,4.77*u,1.43,4.90*v,glassC,'glass');
  box(g,.07*u,2.05,.09*v,4.10*u,1.435,4.90*v,metal,'metal');
  // Door threshold + pergola beam dressed as a flower garland.
  box(g,2.20*u,.06,.55*v,1.52*u,.05,4.60*v,lightWood);
  box(g,2.40*u,.14,.20*v,1.52*u,2.28,4.62*v,wood);
  for (const [gx,gc] of [[.85,pink],[1.75,purple],[2.20,leafL]])
    sphere(g,gx*u,2.36,4.74*v,.075*s,.075*s,.075*s,gc);
  // Central hanging basket over the doorway.
  box(g,.03*u,.20,.03*v,1.52*u,2.12,4.62*v,metal,'metal');
  cylinder(g,.10*s,.16,1.52*u,1.96,4.62*v,wood,'paint',.075*s,10);
  sphere(g,1.45*u,2.06,4.63*v,.07*s,.07*s,.07*s,pink);
  sphere(g,1.60*u,2.06,4.61*v,.07*s,.07*s,.07*s,yellow);
  sphere(g,1.52*u,1.86,4.62*v,.09*s,.12*s,.09*s,leafD);
  // Flower planters mounted on both door pillars.
  wallPlanter(.42,1.10,4.80,[red,pink,lpink]);
  wallPlanter(2.62,1.10,4.80,[yellow,cream,orange]);

  // ===== Flower-wall feature on the north-east section =====
  box(g,1.35*u,1.30,.07*v,4.55*u,1.58,.30*v,leafD);
  box(g,1.45*u,.07,.10*v,4.55*u,.92,.32*v,wood);
  box(g,1.45*u,.07,.10*v,4.55*u,2.24,.32*v,wood);
  const wallBlooms=[[4.15,1.35,pink],[4.60,1.25,lavender],[4.95,1.40,cream],
                    [4.35,1.80,lpink],[4.80,1.72,purple]];
  for (const [bx,by,bc] of wallBlooms)
    sphere(g,bx*u,by,.37*v,.085*s,.085*s,.085*s,bc);

  // ===== Central stepped bouquet table =====
  box(g,2.30*u,.08,1.40*v,3.05*u,.40,2.50*v,lightWood);
  box(g,1.00*u,.38,1.00*v,3.05*u,.19,2.50*v,dark);
  box(g,1.10*u,.12,.70*v,3.05*u,.49,2.50*v,wood);
  bouquet(2.75,2.55,.53,1.0,purple);
  bouquet(3.40,2.55,.53,1.0,pink);
  box(g,.35*u,.20,.30*v,3.05*u,.52,2.18*v,accent);
  light(g,3.05*u,1.25,2.50*v,warm,.13);

  // ===== North-west stepped wall shelving =====
  box(g,2.90*u,.16,.42*v,1.85*u,.08,.45*v,lightWood);
  box(g,2.90*u,.07,.40*v,1.85*u,.835,.45*v,wood);
  box(g,2.90*u,.07,.40*v,1.85*u,1.435,.45*v,wood);
  bucket(.95,.45,[red,pink,orange],.80);
  bouquet(2.60,.45,1.45,.78,lavender);
  light(g,1.85*u,2.00,.72*v,warm,.13);

  // ===== East wall: bucket rack for single stems =====
  box(g,.35*u,.07,1.30*v,5.55*u,1.05,2.55*v,wood);
  bucket(5.42,2.20,[blue,purple,lavender],1.07);
  bucket(5.42,2.90,[yellow,cream,orange],1.07);

  // ===== Cooled premium bouquet cabinet on the west wall =====
  box(g,.55*u,1.90,1.90*v,.55*u,.95,2.55*v,dark);
  box(g,.05*u,1.70,1.70*v,.84*u,.97,2.55*v,cool);
  box(g,.05*u,.05,1.60*v,.87*u,1.20,2.55*v,metal,'metal');
  box(g,.06*u,1.72,1.72*v,.92*u,.97,2.55*v,glassC,'glass');
  bouquet(.62,2.55,.16,.85,cream);
  label(g,'PREMIUM',.50*u,2.10,2.55*v,2.6,'#f9fcf6',{rotY:Math.PI/2});
  light(g,1.00*u,1.80,2.55*v,cool,.11);

  // ===== Florist wrapping / prep counter, rear-right =====
  box(g,1.35*u,.82,.62*v,4.85*u,.41,.78*v,lightWood);
  box(g,1.42*u,.07,.68*v,4.85*u,.84,.78*v,wood);
  box(g,.10*u,.50,.64*v,4.17*u,.47,.78*v,accent);
  box(g,.90*u,1.10,.20*v,4.90*u,1.43,.48*v,wood);
  box(g,.95*u,.05,.24*v,4.90*u,1.45,.52*v,wood);
  box(g,.50*u,.10,.20*v,4.75*u,.90,.82*v,cream);
  label(g,'WRAPPING',4.85*u,1.05,1.13*v,2.8,'#3b4347');

  // ===== Tiny service / payment nook against east wall =====
  box(g,.70*u,.78,.50*v,5.40*u,.39,1.55*v,lightWood);
  box(g,.74*u,.06,.54*v,5.40*u,.81,1.55*v,dark);
  box(g,.22*u,.16,.04*v,5.40*u,1.00,1.32*v,0x1b2e36);
  g.children[g.children.length-1].rotation.y = Math.PI;
  light(g,5.40*u,1.00,1.27*v,0x7fe0e8,.05);

  // ===== Floor greenery kept to circulation edges =====
  plant(5.15,4.20,1.0,accent);

  // ===== Ceiling beams + pendants =====
  box(g,5.30*u,.10,.20*v,3.00*u,2.90,1.70*v,ivory);
  g.children[g.children.length-1].userData.roof = true;
  box(g,5.30*u,.10,.20*v,3.00*u,2.90,3.60*v,ivory);
  g.children[g.children.length-1].userData.roof = true;
  // Pendant over the central table hangs from a ceiling beam.
  cylinder(g,.015*s,.28,3.05*u,2.72,2.50*v,green,'paint',.015*s,6);
  cylinder(g,.08*s,.14,3.05*u,2.50,2.50*v,wood,'paint',.16*s,10);
  light(g,3.05*u,2.41,2.50*v,warm,.10);
  // Second pendant hangs from the entrance pergola beam.
  cylinder(g,.015*s,.22,1.52*u,2.13,4.40*v,green,'paint',.015*s,6);
  cylinder(g,.07*s,.12,1.52*u,1.97,4.40*v,wood,'paint',.14*s,10);
  light(g,1.52*u,1.89,4.40*v,warm,.09);
}
