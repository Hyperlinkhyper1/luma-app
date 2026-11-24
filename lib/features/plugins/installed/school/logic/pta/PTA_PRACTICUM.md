# PTA-trainer: practicum kwalitatieve analyse

Oefening voor het praktische schoolexamen kwalitatieve analyse. In de
oefenmodus voor havo 5 kies je een stofgroep uit het voorbereidingsboekje.
Het proef-SE geeft vier onbekende potjes met elk een eigen lijst van
mogelijke stoffen en één gezamenlijke klok van 120 minuten.

Op het werkblad noteer je per potje formules met toestandsaanduidingen,
handelingen, voorspellingen, waarnemingen, conclusies en vergelijkingen.
Na het inleveren zie je per potje de juiste stof, de mogelijke waarnemingen
en de vergelijkingen bij de uitgevoerde proeven. Je vergelijkt zelf je
uitwerking met die gegevens.

## Hoe het werkt

- `pta_chemistry.dart` – de deeltjes, vaste stoffen, stoffen in het potje,
  reagentia en kleuren. Alle getallen (pKz, Ksp, V⁰) staan hier één keer.
- `pta_lab.dart` – de reageerbuizen en de reacties. Hoeveelheden zijn mmol:
  een spatelpunt is 0,5 mmol, water 5 mL, "enkele druppels" 0,5 mL en
  "overmaat" 3 mL reagens. Na elke handeling worden de reacties uitgerekend:
  neutralisatie en protonoverdracht (aflopend, zoals op school), neerslag en
  oplossen via het oplosbaarheidsproduct, redoxreacties uit een vaste lijst
  (zodat trage reacties zoals MnO₄⁻ + Cl⁻ niet "zomaar" verlopen), metalen en
  complexen. De pH volgt uit de ladingsbalans met de pKz-waarden.
- `pta_scenarios.dart` – de stofgroepen uit het voorbereidingsboekje,
  selectie voor het proef-SE en de standaardproeven voor de nabespreking.
- `pta_binas.dart` – de Binas-bladen (45A, 48, 49, 52A, 65A, 65B), gemaakt
  uit dezelfde gegevens als het lab, zodat blad en simulatie nooit verschillen.

## Bronnen en grenzen

De waarden zijn standaardwaarden uit de scheikundeliteratuur (pKz, Ksp bij
298 K, standaardelektrodepotentialen) en zelf samengevat in de indeling van
Binas. Het is geen kopie van Binas en geen officieel examenmateriaal; op het
echte practicum gebruik je je eigen Binas.

Bewuste vereenvoudigingen, met de waarneming die de school verwacht:

- Waterstofcarbonaat geeft in de kou geen neerslag met Ba²⁺ of Ca²⁺; pas bij
  verwarmen ontstaat carbonaat.
- Matig oplosbare zouten (CaSO₄, Ag₂SO₄, Ca(OH)₂, BaS₂O₃) slaan pas neer
  als het ionenproduct ruim boven Ksp ligt.
- Broom en jood disproportioneren alleen in duidelijk basische oplossing
  (pH > 10); jood blijft bestaan bij overmaat jodide (I₃⁻).
- H₂O₂ met jodide verloopt zonder zuur langzaam (een deel reageert).
- Mg en Zn geven in een zure zoutoplossing langzaam waterstof.

`test/school_pta_test.dart` controleert de pH-waarden, neerslagen, gassen,
redoxreacties, ladingsbehoud na willekeurige handelingen en dat elke set op te
lossen is.
