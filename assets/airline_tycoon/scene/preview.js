/* Exact fresh-airport layout fixture. Preview never writes a game save. */
(() => {
  const definitions = {runway:[45,1800],taxiway:[20,100],stand:[60,65],terminal:[120,60],terminalLandside:[60,40],terminalReclaim:[60,40],serviceRoad:[10,100],fuelDepot:[30,30],baggage:[30,20],vehicleDepot:[30,30],hangar:[60,60],tower:[15,15],entrance:[6,4],checkIn:[8,4],security:[8,6],seating:[8,4],toilets:[10,8],cafe:[12,8],boardingGate:[8,4],customs:[8,6],checkOut:[8,4]};
  const facilities=[];
  function add(kind,x,y,width,depth){const size=definitions[kind];facilities.push({id:`b${facilities.length+1}`,kind,x,y,width:width||size[0],depth:depth||size[1],rotation:0,connected:true});}
  add('runway',-500,-900);
  add('taxiway',-370,-850,20,1700);
  add('taxiway',-455,0,105,20);
  add('taxiway',-350,-65,30,20);
  add('taxiway',-350,5,30,20);
  add('stand',-320,-90);Object.assign(facilities[facilities.length-1],{lane:-55,nose:'+x',gateDoor:{door:[-250,-60,0],kerb:[-253.5,-60,0]},walk:[[-250,-60,0],[-253.5,-60,0],[-278.5,-64,0]]});add('stand',-320,-20);Object.assign(facilities[facilities.length-1],{lane:15,nose:'+x'});
  add('terminal',-250,-90);add('terminal',-250,-30);
  add('terminalLandside',-130,-90,40,60);add('terminalReclaim',-130,-30,40,60);
  add('serviceRoad',-260,-100,10,230);
  add('fuelDepot',-290,100);add('baggage',-250,100);
  add('vehicleDepot',-260,130);add('hangar',-330,140);
  add('tower',-210,140);
  add('entrance',-98,-62);facilities[facilities.length-1].door={door:[-90,-60,0],kerb:[-81,-60,0]};add('checkIn',-112,-76);
  add('security',-126,-62);add('seating',-205,-68);
  add('toilets',-148,-40);add('cafe',-200,-40);
  add('boardingGate',-247,-62);add('boardingGate',-247,8);add('customs',-114,4);add('checkOut',-100,6);facilities[facilities.length-1].door={door:[-90,8,0],kerb:[-81,8,0]};
  window.airportPreview={world:{version:2,time:0,paused:true,speed:1,cash:0,day:1,facilities,flights:[],vehicles:['fuel','baggage','bus','pushback'].map((kind,i)=>({id:`v${i+24}`,kind,x:-255,y:145,heading:0})),passengers:[],contracts:[],ledger:[],stats:{}},command(message){if(message.type==='command'&&message.action==='select')document.getElementById('status').textContent=`Preview selection: ${message.facilityId}`;}};
})();
