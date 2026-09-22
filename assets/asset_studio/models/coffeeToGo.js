function coffeeToGo(g,w,d){
  const u = w/4, v = d/3, x = w/2, z = d/2, s = Math.min(u,v);
  const ivory = 0xe5e0d5, panel = 0xd8d3c6, dark = 0x343b3e, wood = 0x805d42, lightWood = 0xa77b55;
  const top = 0x4a4039, metal = 0x8b9295, equip = 0x454d50, bean = 0x704c36;
  const green = 0x47704f, teal = 0x2a6d7a, cup = 0xeee8dc, menuD = 0x1b2e36;
  const warm = 0xffd99a, glassC = 0xcfe0e2, skin = 0xd8b49a;

  // ===== Floor + pickup mat =====
  box(g,3.9*u,.04,2.9*v,x,.02,z,ivory);
  box(g,1.5*u,.025,.7*v,2.95*u,.045,2.45*v,top);

  // ===== Three-wall shell: back + both sides tied together at the corners =====
  box(g,3.9*u,2.30,.12*v,x,1.15,.18*v,panel);
  box(g,.13*u,2.30,2.60*v,.115*u,1.15,1.44*v,panel);
  box(g,.13*u,2.30,2.60*v,3.885*u,1.15,1.44*v,panel);
  // Wood wainscot wrapping all three walls
  box(g,3.7*u,.80,.08*v,x,.40,.25*v,wood);
  box(g,.08*u,.80,2.30*v,.20*u,.40,1.50*v,wood);
  box(g,.08*u,.80,2.30*v,3.80*u,.40,1.50*v,wood);
  // Cap rail continuing around the corners
  box(g,3.8*u,.06,.16*v,x,2.32,.20*v,wood);
  box(g,.16*u,.06,2.50*v,.13*u,2.32,1.44*v,wood);
  box(g,.16*u,.06,2.50*v,3.87*u,2.32,1.44*v,wood);
  // Cup dispenser mounted on the left wall
  box(g,.08*u,.30,.18*v,.20*u,1.35,2.20*v,metal,'metal');
  cylinder(g,.05,.14,.26*u,1.30,2.20*v,cup,'paint',.05*s,8);

  // ===== Hanging menu board =====
  box(g,1.7*u,.62,.08*v,1.80*u,1.92,.265*v,menuD);
  label(g,'ESPRESSO - LATTE - CAPPUCCINO',1.80*u,2.02,.31*v,2.2,cup);
  label(g,'TEA - HOT CHOCOLATE',1.80*u,1.90,.31*v,2.0,cup);
  label(g,'PASTRIES - SNACKS',1.80*u,1.78,.31*v,2.0,lightWood);

  // ===== Service counter: ORDER (left) to PICKUP (right) =====
  box(g,3.2*u,.90,.60*v,x,.45,1.60*v,ivory);
  box(g,3.2*u,.50,.06*v,x,.35,1.915*v,wood);
  box(g,3.3*u,.09,.68*v,x,.935,1.60*v,top);
  box(g,3.34*u,.04,.72*v,x,.99,1.60*v,metal,'metal');
  label(g,'ORDER',1.0*u,.58,1.95*v,3.2,cup);
  label(g,'PICK UP',2.95*u,.58,1.95*v,3.2,cup);

  // ===== Barista behind the counter at the espresso machine =====
  box(g,.26*u,.50,.20*v,2.05*u,.25,1.19*v,dark);
  box(g,.36*u,.54,.24*v,2.05*u,.75,1.19*v,green);
  box(g,.22*u,.40,.06*v,2.05*u,.72,1.31*v,bean);
  sphere(g,2.05*u,1.17,1.19*v,.12*s,.14*s,.12*s,skin);
  box(g,.24*u,.05,.22*v,2.05*u,1.28,1.17*v,dark);
  box(g,.30*u,.08,.20*v,2.30*u,.98,1.38*v,green);

  // ===== Commercial espresso machine (the visual anchor) =====
  box(g,.70*u,.28,.40*v,2.5*u,1.10,1.45*v,metal,'metal');
  box(g,.64*u,.40,.36*v,2.5*u,1.42,1.44*v,equip);
  box(g,.66*u,.07,.38*v,2.5*u,1.635,1.44*v,metal,'metal');
  box(g,.14*u,.12,.12*v,2.5*u,1.26,1.58*v,dark);
  cylinder(g,.05,.07,2.5*u,1.30,1.60*v,cup,'paint',.04*s,8);
  cylinder(g,.012,.18,2.78*u,1.38,1.50*v,metal,'metal',.012*s,6);
  cylinder(g,.045,.03,2.5*u,1.52,1.62*v,cup,'paint',.045*s,8);
  g.children[g.children.length-1].rotation.x = Math.PI/2;
  light(g,2.5*u,1.30,1.64*v,warm,.09);

  // ===== Coffee grinder with bean hopper =====
  box(g,.18*u,.16,.18*v,1.78*u,1.04,1.45*v,equip);
  box(g,.14*u,.20,.14*v,1.78*u,1.20,1.45*v,dark);
  cylinder(g,.09,.15,1.78*u,1.36,1.45*v,metal,'metal',.065*s,8);
  cylinder(g,.06,.05,1.78*u,1.31,1.45*v,bean,'paint',.06*s,8);

  // ===== Stacked takeaway cups between machine and pastry case =====
  cylinder(g,.055,.16,3.00*u,1.04,1.42*v,cup,'paint',.05*s,8);
  cylinder(g,.07,.05,2.94*u,.995,1.30*v,dark,'paint',.07*s,8);

  // ===== Small glass pastry display at the right counter end =====
  box(g,.70*u,.18,.50*v,3.45*u,1.06,1.60*v,dark);
  box(g,.64*u,.34,.44*v,3.45*u,1.31,1.60*v,glassC,'glass');
  box(g,.58*u,.03,.38*v,3.45*u,1.29,1.60*v,metal,'metal');
  sphere(g,3.32*u,1.21,1.55*v,.06*s,.045*s,.05*s,0xd98245);
  sphere(g,3.48*u,1.21,1.65*v,.06*s,.045*s,.05*s,0xd98245);
  cylinder(g,.05,.06,3.58*u,1.17,1.58*v,lightWood,'paint',.05*s,8);
  cylinder(g,.05,.06,3.34*u,1.33,1.65*v,0xc98a4a,'paint',.05*s,8);
  light(g,3.45*u,1.40,1.62*v,warm,.08);

  // ===== Order / payment position =====
  box(g,.05*u,.12,.05*v,1.0*u,1.02,1.64*v,dark);
  box(g,.26*u,.20,.04*v,1.0*u,1.13,1.66*v,menuD);
  light(g,1.0*u,1.13,1.62*v,warm,.06);
  box(g,.10*u,.09,.12*v,1.28*u,1.015,1.70*v,equip);

  // ===== Pickup tray with two finished takeaway coffees =====
  box(g,.55*u,.03,.32*v,2.95*u,.99,1.75*v,lightWood);
  cylinder(g,.06,.14,2.86*u,1.06,1.75*v,cup,'paint',.05*s,8);
  cylinder(g,.065,.06,2.86*u,1.07,1.75*v,bean,'paint',.066*s,8);
  cylinder(g,.065,.04,2.86*u,1.14,1.75*v,dark,'paint',.065*s,8);
  cylinder(g,.06,.14,3.05*u,1.06,1.75*v,cup,'paint',.05*s,8);
  cylinder(g,.065,.04,3.05*u,1.14,1.75*v,green,'paint',.065*s,8);

  // ===== Tiny condiment station on the left counter =====
  box(g,.12*u,.10,.14*v,.50*u,1.02,1.72*v,cup);
  cylinder(g,.05,.12,.66*u,1.03,1.72*v,metal,'metal',.05*s,8);
  cylinder(g,.07,.05,.82*u,.995,1.74*v,dark,'paint',.07*s,8);

  // ===== Cold bottled drinks resting on the counter =====
  box(g,.42*u,.03,.22*v,.60*u,.985,1.42*v,metal,'metal');
  cylinder(g,.035,.16,.52*u,1.07,1.42*v,teal,'paint',.035*s,6);
  cylinder(g,.035,.16,.68*u,1.07,1.42*v,0xd98245,'paint',.035*s,6);

  // ===== Organized back-wall shelving: cup store (left) + syrup & bag store (right) =====
  // Left run: two shelves stacked with neat takeaway-cup columns and lid stacks
  box(g,1.1*u,.05,.26*v,.90*u,1.10,.38*v,wood);
  box(g,1.1*u,.05,.26*v,.90*u,1.42,.38*v,wood);
  for (const cx of [.50,.70,.90]) cylinder(g,.055,.16,cx*u,1.20,.38*v,cup,'paint',.05*s,8);
  cylinder(g,.07,.06,1.15*u,1.15,.38*v,dark,'paint',.07*s,8);
  for (const cx of [.55,.78]) cylinder(g,.055,.16,cx*u,1.52,.38*v,cup,'paint',.05*s,8);
  box(g,.18*u,.14,.12*v,1.15*u,1.51,.38*v,teal);
  // Right run: two shelves with a graded syrup row and coffee-bag stock
  box(g,1.1*u,.05,.26*v,3.30*u,1.45,.38*v,wood);
  box(g,1.1*u,.05,.26*v,3.30*u,1.85,.38*v,wood);
  for (const [bx,bc] of [[2.90,0xd98245],[3.10,green],[3.30,bean],[3.50,teal],[3.70,0xc95a50]])
    cylinder(g,.04,.15,bx*u,1.54,.38*v,bc,'paint',.03*s,6);
  for (const [bx,bc] of [[2.95,bean],[3.17,green],[3.39,dark]])
    box(g,.16*u,.20,.11*v,bx*u,1.97,.38*v,bc);
  cylinder(g,.06,.10,3.72*u,1.92,.38*v,panel,'paint',.05*s,8);
  sphere(g,3.72*u,2.05,.38*v,.09*s,.11*s,.09*s,green);

  // ===== Overhead frame: fascia rests on the side walls via front posts =====
  box(g,.09*u,2.35,.09*v,.24*u,1.175,2.60*v,wood);
  box(g,.09*u,2.35,.09*v,3.78*u,1.175,2.60*v,wood);
  box(g,3.7*u,.55,.30*v,x,2.50,2.50*v,dark);
  g.children[g.children.length-1].userData.roof = true;
  box(g,3.76*u,.06,.34*v,x,2.21,2.50*v,wood);
  label(g,'RUNWAY ROAST',x+.35*u,2.55,2.66*v,7,'#f9fcf6');
  label(g,'COFFEE TO GO',x+.35*u,2.36,2.66*v,3.2,lightWood);
  cylinder(g,.09,.14,.62*u,2.50,2.66*v,cup,'paint',.075*s,8);
  g.children[g.children.length-1].rotation.x = Math.PI/2;
  box(g,.03*u,.08,.05*v,.78*u,2.50,2.66*v,cup);
  light(g,x,2.44,2.70*v,warm,.12);
  // Projecting blade sign on the right wall, readable from the terminal
  box(g,.10*u,.55,.26*v,3.86*u,1.85,2.86*v,dark);
  label(g,'COFFEE',3.908*u,1.92,2.86*v,3.4,cup,{rotY:Math.PI/2});
  label(g,'TO GO',3.908*u,1.76,2.86*v,2.8,lightWood,{rotY:Math.PI/2});
}
