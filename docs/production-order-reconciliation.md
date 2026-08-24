# Production Order Reconciliation 2.8

## Doel en afbakening

**PNE Production Order Reconciliation** vergelijkt een werkelijk, headerloos
AutoCAD-PIL-bestand met één bestaande productieorder en maakt daarvan een
veilig, controleerbaar wijzigingsvoorstel. Na expliciete bevestiging past de app
die productieorder aan. Eén nauw afgebakende uitzondering is het herstel van
een ontbrekende `Item.Production BOM No.`-koppeling vanuit **Puntartikel
verhogen**; daarvoor volgt altijd een afzonderlijke bevestiging.

De app is geen voorraadboeking, geen algemene BOM-editor en geen IWX-functie.
Zij:

- leest de live productieorderstructuur en gebruikt een Production BOM alleen
  als gecontroleerde, read-only terugval voor structuuranalyse;
- verhoogt eerst een samengestelde productiecarrier;
- laat standaard Business Central de afgeleide componenten opnieuw berekenen
  en verwerkt daarna alleen de aantoonbare mutatie in routinggekoppelde uren
  op de live productieorder;
- vervangt daarna alleen een bestaande, geconfigureerde CALC-placeholder door
  werkelijke PIL-artikelen;
- bewaart bronregels, analyse, verdeling, technisch voorstel, toepassing en
  eventuele offerte-overdracht als app-eigen audit; en
- wijzigt geen Production BOM Header/Line, IWX-record, IWX Business Rule of
  Bluace-object. Alleen een aantoonbaar same-number puntartikel kan na
  afzonderlijke bevestiging via de normale veldvalidatie aan zijn bestaande
  geldige Production BOM worden gekoppeld.

De app heeft geen IWX- of Bluace-afhankelijkheid. De bestaande
Bluace-routingoplossing voor mastergegevens blijft daardoor onaangetast.

## BOM-stamstructuur zonder productieorderwijziging

Op **Simulated**, **Firm Planned** en **Released Production Order** staat onder
**Functions** de actie **BOM-stamstructuur**. Deze actie is een
alleen-lezen hulpmiddel vóór en tijdens de PIL-afstemming:

```text
Hoofdartikel van de productieorder
  + bestaande onderliggende Production BOM (bijvoorbeeld kastproductie)
    - bestaande artikelen daaronder
  + bestaande onderliggende Production BOM (bijvoorbeeld plotter)
    - bestaande artikelen daaronder
  + bestaande onderliggende Production BOM (bijvoorbeeld bedrading)
    - bestaande artikelen daaronder
```

De pagina gebruikt tijdelijk de standaardtabel **Production BOM Line**; er is
geen app-eigen tabel, setup, auditrecord, dummy-artikel of extra
productieorder. De root wordt altijd gelezen uit **Prod. Order Line.Production
BOM No.** en, waar die gevuld is, de op die regel opgeslagen **Production BOM
Version Code**. Zonder opgeslagen versie kiest de pagina net als voor een
onderliggende BOM de bestaande gecertificeerde, datumgeldige versie op de
startdatum, anders de uiterste datum en zonder beide op de werkdatum. Bovenaan
toont **Hoofd-BOM / versie** de eerste opgeslagen root-BOM en versie; bij
meerdere roots staat dat er expliciet bij en zijn alle takken zichtbaar. Een
artikel met een onderliggende Production BOM krijgt ook een eigen BOM-kop met
de werkelijk gebruikte versie. Er wordt geen historische kind-BOM-snapshot
geclaimd die Business Central niet bewaart.

De standaardcomponentenlijst blijft ongewijzigd en plat. De nieuwe pagina
voegt uitsluitend een begrijpelijke boomweergave met de bestaande
**Routing Link Code** toe. Zij leidt geen route, werkplek of U.-uur af wanneer
de bijbehorende bestaande BOM-regel geen Routing Link Code bevat. Een cirkel,
meer dan 50 niveaus of meer dan 20.000 weer te geven regels geeft een duidelijke
melding en kapt de tijdelijke weergave veilig af; dit verandert geen brondata.

## Invoercontract: werkelijk AutoCAD-PIL-formaat

De import accepteert .txt en .csv zonder kopregel, met exact vier
komma-gescheiden velden tussen enkele aanhalingstekens:

~~~text
'Artikelnummer','Tek. KompNr','KlemNr','Art. Aantal'
'4.01.205.02.0','-RD','',''
'4.01.205.03.0','-OR','','4'
~~~

| Bronveld | Verwerking |
|---|---|
| Artikelnummer | Exact BC-artikelnummer; bepaalt analyse en, waar nodig, de actieve PIL-groep. |
| Tek. KompNr | Volledige bron-audit, niet gebruikt als sleutel. |
| KlemNr | Volledige bron-audit, niet gebruikt als sleutel. |
| Art. Aantal | Leeg = 1. Positieve aantallen worden per artikel geaggregeerd; maximaal vijf decimalen. |

De import bewaart elke regel in **PNE PIL Raw Line** (50190) én maakt één
geaggregeerde **PNE PIL Line** (50173) per artikel. Een artikel dat niet in BC
bestaat blijft als broninformatie zichtbaar, maar kan nooit stilzwijgend een
productiecomponent worden. Negatieve, lege, verkeerd gequote, niet-numerieke
of te nauwkeurige aantallen stoppen de import volledig.

AutoCAD levert geen ouderrelatie tussen de regels. Daarom blokkeert de app een
situatie waarin één geaggregeerd AutoCAD-artikel zowel door een structurele
driver als door een **onafhankelijke** CALC-route zou kunnen worden verwerkt.
De hoeveelheid kan dan niet betrouwbaar worden gesplitst. Gebruik een
onderscheidend exportartikel of ontwerp een expliciete uitbreiding; de app
kiest niet op goed geluk.

## Beheer: alleen groepen en artikelen

Er zijn twee onderhoudstabellen. Oude profielen, productiedoelen, posities en
assemblyrecepten zijn bewust geen onderdeel van deze variant.

| Tabel | Doel | Belangrijkste validatie |
|---|---|---|
| **PNE PIL Group** (50170) | Functionele PIL-groep, bijbehorende CALC-placeholder en kostprijscontrole. | De placeholder is een Non-Inventory-item; één actieve CALC-placeholder hoort bij maximaal één actieve groep. |
| **PNE PIL Group Item** (50171) | Echte Inventory-artikelen die via die groep een CALC-placeholder mogen vervangen. | Eén actief AutoCAD-artikel hoort bij maximaal één actieve groep. |

De lookups gebruiken de gewone Business Central Item-tabel en vullen waar
mogelijk de omschrijving mee. Een structureel item onder een hogere assembly
hoeft niet als groepsartikel te worden ingericht: het kan als driver of gedekt
onderdeel worden herkend. Een groepskoppeling is uitsluitend nodig voor de
losse CALC-route.

De actie **CALC-kostprijs herberekenen** berekent het ongewogen gemiddelde van
de Unit Cost van de actieve echte artikelen. Vóór het via standaard
Item-validatie naar de CALC-placeholder wordt geschreven, toont de app het
huidige en nieuwe bedrag plus waarschuwingen. Nulkosten en een andere
basiseenheid dan **STUKS** worden zichtbaar gemaakt; de actie verandert geen
productieorder.

## Analysemodel: carrier, structurele driver en CALC

Een artikelnummer dat met **.** begint is de expliciete Pneuman-conventie voor
een **carrier**. Dat geldt voor alle puntartikelen, dus niet alleen `.PN...`,
maar bijvoorbeeld ook `.EA...`, `.PH...` en `.TO...`. Een carrier kan een
productieorderregel of een productieordercomponent zijn. Dit bepaalt welke
bestaande samengestelde eenheid de app mag verhogen. Het betekent niet
“Siemens” en is geen speciale artikelgroep.

Een `G.`-artikel is alleen aanvullend een carrier wanneer het aantoonbaar een
echt produceerbaar voorraadartikel is: type *Inventory*, aanvullingssysteem
*Prod. Order* en een geldige gecertificeerde Production BOM of Production
BOM-versie. Daardoor kan een echte `G.`-productgroep meedoen wanneer er geen puntcarrier in dezelfde
productieketen is. `G.`-uren- en materiaalgroepen, Non-Inventory- en
Purchase-hulpartikelen blijven buiten de carrierselectie. Zij bevatten geen
PIL-doel en schalen uitsluitend mee wanneer hun bovenliggende carrier wordt
verhoogd. Wanneer een geldige puntcarrier en een geldige `G.`-carrier in
dezelfde gekoppelde keten voorkomen, krijgt de puntcarrier voorrang.

Een afzonderlijke meter- of andere niet-**STUKS**-subconfiguratie zonder een
positieve geïmporteerde driver of passende CALC-placeholder is geen PIL-route.
De app slaat zo'n tak tijdens de analyse over, zodat hij een losstaande
**STUKS**-carrier elders op dezelfde productieorder niet blokkeert. Bevindt
zich wel een PIL-driver of CALC-placeholder in die tak, dan stopt de app nog
steeds bewust: het headerloze PIL-bestand bevat geen veilige
eenheidsomrekening.

**7.*** is evenmin hardcoded. De app zoekt per carrier naar het hoogste
geïmporteerde artikel dat zelf een gekoppelde kindproductieorder of een
onderliggende Production BOM heeft:

~~~text
.-carrier
  └─ hoogste geïmporteerde artikel met kind-PO of kind-BOM  ← structurele driver
       └─ geïmporteerde lagere onderdelen                    ← gedekt, alleen audit
~~~

De structurele driver is leidend **binnen dezelfde carrier**. Voor ieder lager
PIL-artikel berekent de app uit de live structuur of geldige Production BOM
hoeveel stuks de verdeelde hogere drivers werkelijk vertegenwoordigen. Een
volledig gedekte regel krijgt *Gedekt door structurele carrier*. Is slechts een
deel gedekt, dan blijft uitsluitend het restant zichtbaar als *Gedeeltelijk
gedekt; rest nog verwerken*. Dit voorkomt zowel dubbel tellen als het onterecht
verdwijnen van extra onderdelen.

Een gedeeltelijk gedekt restant kan als los materiaal worden toegevoegd of aan
een passend puntartikel worden gekoppeld. Bij die tweede keuze geldt de
BOM-capaciteit als minimum: de app rondt naar hele extra puntartikelen omhoog en
toont het volledige voorgestelde carrieraantal. De gebruiker hoeft dus geen
fractioneel puntartikel te accepteren. Een basis met 22 onderdelen plus twee
uitbreidingen met elk 24 dekt bijvoorbeeld 70 van een PIL-totaal van 80; het
restant 10 vraagt één hele extra uitbreiding, zodat het eindtotaal van die
uitbreiding 3 wordt. Bij herimport met drie uitbreidingen wordt de dekking op
het PIL-totaal begrensd en volgt geen vierde uitbreiding.

Een echt fysiek onderdeel hoort als **Item** in de Production BOM. Komt
hetzelfde nummer daarnaast ook als **Production BOM**-kop voor om onderliggende
uren of structuur uit te klappen, dan is de Item-regel leidend voor het
PIL-aantal. De gelijknamige BOM-kop blijft uitsluitend een structuurdrager en
wordt niet nogmaals geteld. Voor oudere stamgegevens waarin alleen de
gelijknamige BOM-kop staat, herkent de analyse die kop nog wel als gecontroleerde
structurele terugval. Deze regel is generiek en bevat geen vaste artikelcodes.

Wanneer binnen een carrier geen structurele driver bestaat, neemt de
**CALC-route** over:

1. de app zoekt in de bestaande live structuur precies één passende
   CALC-component voor de actieve PIL-groep;
2. het voorgestelde carrieraantal wordt uit de PIL-verdeling berekend;
3. Apply verhoogt eerst de carrier via standaard Business Central-validatie;
4. de nieuw berekende, bestaande CALC-component wordt door de echte
   PIL-artikelen vervangen.

Verschillende drivers onder dezelfde carrier zijn minimumvoorwaarden. De app
neemt automatisch de hoogste naar boven afgeronde eis en telt die eisen niet
bij elkaar op. Komt één geaggregeerd AutoCAD-artikel voor onder meerdere
werkelijk onafhankelijke carriers, dan reserveert de app eerst de aantoonbare
bestaande dekking. Alleen een onverklaard restant blijft in **Naar deze
carrier** handmatig verdeelbaar. Bestaande carrierhoeveelheden worden daarbij
niet verlaagd.

Een structural driver in een andere carrier onderdrukt de CALC-route niet.
Hierdoor blijft bijvoorbeeld een losse **.PN.L5.7** met eigen CALC-led apart
verwerkbaar naast een Siemens-assembly elders in dezelfde productieorder.

### Analysebron en master-BOM-terugval

De primaire analysebron is de live gekoppelde productieorderstructuur. Wanneer
een live carrier geen structurele driver biedt, kan de app de Production BOM
alleen lezen om een structurele route te bepalen. Het resultaat toont duidelijk
**Live Production Order** of **Current Master BOM**.

Bij een bestaande gekoppelde puntartikel-productieregel gebruikt deze terugval
de BOM en versie die op die productieorderregel zijn vastgelegd. Daardoor kan
een opnieuw ingelezen, al verwerkt PIL-artikel nog als gedekt worden herkend,
ook wanneer de bijbehorende Production BOM-kop tijdens standaard BC-uitvouwing
niet als zelfstandige productiecomponent zichtbaar blijft.

Wanneer een reeds aangepaste live order dezelfde structurele route als een
oude én een nieuwe representatie bevat, kan de waargenomen factor hoger zijn
dan het actuele geldige BOM-recept. In dat aantoonbare geval bewaart het dossier
beide factoren voor controle en gebruikt het de enkele BOM-factor voor het
carrieradvies. Een Item-regel en een gelijknamige Production-BOM-kop dragen
daarbij samen maar één fysiek aantal; overige afstammelingen van die BOM worden
wel normaal onderzocht. Het voorstel toont per driver expliciet
`PIL-aantal / factor = voorgesteld carrieraantal`.

Na de normale hoogste-carrieranalyse controleert de app uitsluitend nog open
PIL-regels tegen de puntartikelen die al op deze productieorder voorkomen. Bij
precies één passende bestaande puntartikelcomponent gebruikt zij de bestaande
live positie en de gekoppelde productieregel of gecertificeerde BOM. Daarmee
wordt een eerder door de PIL toegevoegd puntartikel bij een herimport
automatisch als bestaande carrier herkend. Bij meerdere passende posities kiest
de app niet stilzwijgend; de gebruiker bepaalt dan bewust de juiste carrier.

Voor een carrier die zelf een productieorderregel is, gebruikt de terugval de
op de orderregel bewaarde **Production BOM Version Code** wanneer die is
ingevuld. Anders gebruikt de app uitsluitend een actieve, gecertificeerde en
datumgeldige versie. De master-BOM blijft read-only en de app maakt geen
fictieve kindproductieorder.

Bij een cirkel, ontbrekende/niet-gecertificeerde versie, routing link, scrap,
calculation formula, niet-ondersteunde UOM of benodigde UOM-omrekening stopt de
analyse. Een bron waarover de app niet zeker kan zijn wordt niet toegepast.

## Begeleide gebruikersstroom

De acties staan op **Simulated**, **Firm Planned** en **Released Production
Order** onder **Functions**. Naast de PIL-acties is daar ook **Routinguren
opnieuw berekenen** beschikbaar voor handmatige componentwijzigingen zonder
PIL-dossier. Open desgewenst eerst
**BOM-stamstructuur** om te zien bij welk bestaand BOM-onderdeel de
artikelen horen. Het dossier is altijd aan precies één
productieorder gekoppeld en toont deze delen:

| Dossierdeel | Wat controleert de gebruiker? |
|---|---|
| **1. Geïmporteerde AutoCAD-PIL** | Geaggregeerde items, groep, totaal, beslissing en eventueel een bewuste uitzondering. |
| **2. Verdeling over productiecarriers** | Driver/CALC-route, carrier, analysebron, huidig en nieuw carrieraantal, automatische of handmatige verdeling. |
| **3. Voorgestelde productie- en commerciële wijzigingen** | Eén readonly voorstelregel per carrier, inclusief technische kostenindicatie en offerte-audit. |

De oorspronkelijke AutoCAD-bronregels blijven onveranderbaar in het
auditdossier, maar staan bewust niet als vierde dagelijkse tabel op de kaart en
niet in het wijzigingsrapport. De gebruiker werkt met de samengevoegde
actieregels; ondersteuning kan de bronregistratie zo nodig technisch
controleren.

De kaart leidt de gebruiker via deze vaste volgorde:

1. **Stap 1 – Analyseer PIL.** De app maakt de targets, zet unieke
   verdelingen automatisch klaar en bouwt het wijzigingsvoorstel.
2. **Stap 2 – Controleer verdeling.** Alleen bij meerdere geldige carriers
   wordt **Naar deze carrier** door de gebruiker ingevuld. Bij één kandidaat
   is de volledige verdeling automatisch. Meerdere drivers die dezelfde
   carrier bereiken zijn minimumvoorwaarden: de hoogste hele eis wint en wordt
   niet bij de andere eisen opgeteld. Alleen een werkelijk ambigue verdeling
   over verschillende carriers vraagt een gebruikerskeuze. De status wordt pas *Gereed om toe te
   passen* wanneer alle relevante aantallen exact zijn verdeeld en ieder echt
   carrierconflict bewust is opgelost.
   Blijft de status toch open, dan noemt de melding voortaan het eerste
   AutoCAD-artikel met ontbrekende verdeling, het exacte resterende aantal of
   de carrier waarvoor nog een leidend aantal gekozen moet worden.
3. **Stap 3 – Bekijk wijzigingsvoorstel.** De gebruiker leest of print het
   technische/commerciële voorstel en kan positieve meerwerkregels eventueel
   aan een bestaande offerte toevoegen.
4. **Stap 4 – Pas veilig toe.** De app toont de impact en controleert vlak
   voor de wijziging alle live veiligheidsvoorwaarden opnieuw. Na succes
   toont de app een bevestiging en sluit het dossier automatisch. Het
   toegepaste dossier blijft via **PIL-afstemmingen** beschikbaar als
   alleen-lezen audit.

Een gewijzigde handmatige verdeling zet een al voorbereid dossier onmiddellijk
terug naar *Verdeling nodig*. Het voorstel moet dan opnieuw worden
gecontroleerd voordat offerteoverdracht of Apply mogelijk is.

Wanneer een live wijziging, bijvoorbeeld een gewijzigde carrier- of
CALC-snapshot, een nieuwe analyse vereist, staat **Analyseer opnieuw** klaar in
*Verdeling nodig* én *Gereed om toe te passen*. De actie bouwt targets en voorstel
opnieuw op en vervangt eventuele handmatige verdelingen. Zodra er actieve
offerteoverdracht bestaat is die actie bewust niet beschikbaar: eerst moet de
overdracht veilig worden teruggedraaid of commercieel worden beoordeeld.

### Positieve, ongekoppelde regel: expliciete uitzondering

Een positieve regel zonder veilige structurele of CALC-resolutie blokkeert de
verwerking. De normale oplossing is de inrichting of productiestructuur te
herstellen.

Alleen een positieve, **ongekoppelde** regel die werkelijk niet bij deze
productieorder hoort mag de gebruiker via **Bewust negeren** uitsluiten. Een
reden is verplicht. De app bewaart reden, gebruiker en tijdstip en geeft de
beslissing *Bewust genegeerd met reden*. Een gemapte of al opgeloste regel kan
niet via deze route worden genegeerd. Met **Negeren herstellen** wordt de regel
weer actief. De uitzondering zelf zet een dossier dat *Gereed om toe te passen*
is terug naar *Verdeling nodig*; daarna moet het voorstel opnieuw worden gecontroleerd.

Wanneer alle positieve regels bewust zijn genegeerd, is een dossier alsnog
voorbereidbaar. **Pas veilig toe** wijzigt dan geen productieorder, maar legt
het gecontroleerde dossier uitsluitend als afgehandelde audit vast. Een
offerteoverdracht is in dat geval niet beschikbaar.

## Live snapshot- en toepassingsveiligheid

Voor Apply bewaart iedere target een identiteitssnapshot: carrier SystemId,
artikel, variant, eenheid, oorspronkelijke hoeveelheid en — bij CALC — de
exacte broncomponent met hoeveelheid en UOM. Vlak voor Apply wordt die snapshot
opnieuw getoetst, samen met de actuele targets en het eventuele commerciële
voorstel.

De applicatie blokkeert zonder gedeeltelijke wijziging onder meer bij:

- gewijzigde carrier, variant, UOM, aantallen, CALC-bron of technisch voorstel;
- een UOM anders dan **STUKS** of een UOM-conversie in de PIL-route;
- meerdere of ontbrekende CALC-bronnen;
- bestaande echte PIL-componenten naast een te vervangen CALC-bron;
- strijdige driveraantallen, onvolledige verdeling of cirkel/ongeldige
  master-BOM;
- verbruik, reservering of magazijnpick in de betrokken componentstructuur;
- Finished Quantity op een betrokken productieorderregel;
- open productiejournaalregels;
- gestarte/gereedgemelde routing of geboekte routingoutput, scrap, setup,
  runtime of capaciteit; en
- niet exact kloppende gekoppelde productieorderdemand.

De betrokken structuur omvat carrier, parent-/child-ketens en de CALC-bron.
De app gebruikt tabelvergrendelingen en bevat geen **Commit()**: wanneer een
standaardvalidatie of laatste controle faalt, rolt de volledige Apply terug.
Een toegepast dossier blijft onveranderbaar audit en kan niet opnieuw worden
toegepast.

### Snelheid zonder verouderde cache

De zoek- en analyseacties gebruiken uitsluitend tijdelijke indexen binnen de
lopende actie. De geldige Production-BOM-versie en certificeringsstatus worden
per BOM eenmaal bepaald. De puntartikelzoekactie scant alleen puntartikelen en
bouwt de omgekeerde BOM-route eenmaal op. Tijdens **Analyseer PIL** wordt ieder
bestaand puntartikel op de actuele productieorder eenmaal onderzocht en worden
alle nog open AutoCAD-artikelen tegelijk vergeleken. Na een handmatige
puntartikelkeuze wordt de gekozen BOM eenmaal voorgefilterd voordat de exacte
aantalsfactoren worden berekend. In versie 2.7.0.4 levert één verdere
BOM-doorgang direct de aantalsfactoren voor alle passende open PIL-artikelen.
De structurele analyse indexeert binnen dezelfde actie zowel de inhoud van een
geldige BOM als de productieregels waaronder een positieve PIL-driver voorkomt.
Versie 2.7.0.5 bouwt de omgekeerde puntartikelroute voor iedere verschillende
relevante productieregeldatum en voegt de uitkomsten samen. Daardoor blijft een
puntartikel zichtbaar wanneer zijn gecertificeerde BOM-versie voor het gekozen
werkgebied geldig is, maar niet voor de datum van een andere productieregel.
Alleen wanneer de snelle index geen kandidaat vindt, volgt een volledige
controle van de geldige puntartikel-BOMs. Na de lookup valideert de app de
gekozen bestemmingsregel nog steeds exact tegen haar eigen datum en BOM.
Versie 2.7.0.6 behandelt bij die eerste ouderstap zowel een directe Item-regel
als een geneste Production-BOM-regel als geldige standaard BC-relatie. Daardoor
kan een modulair puntartikel worden gevonden wanneer het AutoCAD-nummer de
onderliggende BOM identificeert. Alle bovenliggende BOMs en het gekozen
puntartikel blijven onder dezelfde actieve versie- en certificeringscontrole
vallen. Een aanvullende directe-oudercontrole gebruikt de feitelijke BOM-regel
als snelle tweede bewijsroute. Wanneer daarna geen selecteerbaar puntartikel
overblijft, meldt de app welke relatie wel is gevonden en of artikelsoort,
aanvulsysteem, STUKS-eenheid, certificering, versie of regeldatum de kandidaat
uitsluit.

Versie 2.7.0.7 maakt een ontbrekende artikelkoppeling herstelbaar zonder een
aparte beheerpagina. Bestaat de gevonden actieve en gecertificeerde Production
BOM ook als STUKS-puntartikel met dezelfde code, dan blijft dat artikel in de
lookup zichtbaar wanneer zijn veld **Production BOM No.** leeg of afwijkend
is. De kolom **Koppelstatus** maakt de voorgenomen reparatie vooraf zichtbaar.
Na de eventuele werkgebiedkeuze vraagt de app afzonderlijk toestemming om het
standaard Item-veld blijvend te wijzigen. Bij Nee gebeurt niets; bij een latere
fout rolt de volledige actie terug. `Validate` en `Modify(true)` behouden de
standaard BC-validaties en bestaande subscribers. Er wordt geen IWX-record of
Business Rule benaderd en geen Production BOM-regel gewijzigd.

Versie 2.7.0.9 maakt de commerciële overdracht orderbreed netto. Technische
carrierregels met hetzelfde artikel, dezelfde variant en dezelfde eenheid
worden eerst samengenomen. De app vergelijkt hun gezamenlijke oorspronkelijke
aantal met hun gezamenlijke definitieve aantal. Alleen dat verschil wordt als
meerwerk of minderwerk op de gekozen bestaande offerte gezet; netto nul maakt
geen regel. Alle bijdragende technische regels verwijzen naar dezelfde
offertregel en worden samen gecontroleerd. Terugdraaien verwijdert die gedeelde
regel eenmaal en bewaart de audit per technische bronregel.

Versie 2.7.0.10 voegt bij zo'n netto meer- of minderwerkregel automatisch de
geldige standaard Business Central-artikeltekst toe wanneer **Automatic Ext.
Texts** en **Sales Quote** zijn ingeschakeld. De
tekstselectie volgt de documentdatum en taal van de gekozen offerte. Iedere
niet-lege brontekstregel begint bij meerwerk met het netto aantal, bijvoorbeeld
`2x`, en bij minderwerk met **Minderwerk** en het absolute aantal. Lange teksten
worden over
gekoppelde tekstregels verdeeld zonder stil afkappen. Heeft het artikel geen
toepasselijke standaard tekst, dan blijft de gewone offerteregel geldig zonder
tekst.

Deze toevoeging leest uitsluitend de standaard Extended Text-inrichting. Zij
opent geen IWX-configuratie, bouwt geen configuratietekst opnieuw op en roept
geen IWX Business Rule aan. De gekoppelde tekstregels volgen daardoor de
normale offerte-/order-/factuurdocumentstroom. De gebruikte verkooplay-out moet
tekstregels uiteraard wel afdrukken. Een later verwijderde, toegevoegde of
gewijzigde gekoppelde tekstregel maakt de commerciële koppeling
beoordelingsplichtig en blokkeert automatisch terugdraaien. Technische Apply
verifieert de onveranderde artikelregel en technische snapshot, maar wordt niet
meer door een losse tekst- of tekststamwijziging geblokkeerd.

Versie 2.8.0.1 voegt een duurzame herstelroute toe voor de situatie waarin de
oorspronkelijk gekoppelde offerte of offertregel vóór technische Apply is
gewijzigd, verwijderd, omgezet of door de huidige gebruiker niet kan worden
geverifieerd. **Commerciële koppeling vrijgeven** vraagt altijd om een reden en
maakt per technische voorstelregel een onveranderbare audit met de
oorspronkelijke offerte-/artikel-/aantal-/prijs-/tekstsnapshot, de aangetroffen
koppelingstoestand, gebruiker en datum/tijd. De actie schrijft niet naar Sales
Header, Sales Line, vervolgorder of factuur.

Een vrijgegeven koppeling blijft commercieel vergrendeld: het voorstel kan niet
worden herverdeeld, opnieuw geanalyseerd of nogmaals automatisch naar een
offerte worden gestuurd. Apply slaat alleen de onmogelijke live
offertecontrole over. Carrier-, BOM-, bron-, routing-, reserverings-,
verbruiks-, pick-, journaal- en stale-snapshotcontroles blijven volledig van
kracht. Het Word-wijzigingsvoorstel toont de vrijgave in een aparte
auditsectie.

Voor een live productiecomponent of productieregel volgt de analyse eerst de
locatie-/variantafhankelijke Stockkeeping Unit. Een niet-lege SKU **Production
BOM No.** wint van de Itemkaart; zonder SKU-BOM geldt de Item-BOM. Daarmee
gebruiken structurele analyse, puntartikelvalidatie en routinguren dezelfde
locatie-/variantbron die Business Central voor de productieorder kan gebruiken.

Bij Apply blijft de standaard Business Central-berekening voor een nieuw
puntartikel verplicht. Die maakt de gekoppelde productieregel, componenten en
routing. De aansluitende routingplanning verwerkt diezelfde nieuwe kindboom
niet nogmaals; alleen de gekozen regel en zijn bovenliggende keten worden dan
meegenomen. Wanneer een bestaand structureel carrieraantal wijzigt, blijft de
volledige geraakte onderboom juist wel onderdeel van de herberekening. Er wordt
niets tussen acties of gebruikerssessies bewaard, zodat de volgende actie
altijd actuele order- en stamgegevens leest. Binnen één Apply worden overlappende
parent-/child-ketens wel maar eenmaal op reservering, verbruik, pick, journaal en
routingactiviteit gecontroleerd. Ook wordt een gelijke niet-uitgevouwen
Production BOM voor de routingurentelling eenmaal per actie doorgerekend en
daarna met ieder actueel componentaantal vermenigvuldigd. De voor- en
nameting blijven twee afzonderlijke snapshots van de werkelijk actuele order.

## Routing en partnerintegratie

Vóór de mutatie bepaalt de app eerst de routing-eigenaar. De voorkeur is de
unieke live productieregel waarvan het artikel gelijk is aan het
productieorder-hoofdartikel. Ontbreekt die eenduidige match, dan mag alleen één
aantoonbaar bovenste, niet intern toegeleverde routingregel eigenaar worden.
De gekozen materiaalbestemming of subconfiguratie wordt dus niet automatisch
routing-eigenaar.

Voor zo'n unieke hoofdroute verzamelt de app vervolgens de Non-Inventory-
componenten met een **Routing Link Code** uit **alle live productieregels van
dezelfde productieorder**. Zij normaliseert dat ordertotaal naar één eenheid
van het hoofdproduct met `component Quantity per × productieregelaantal ÷
routing-hoofdartikelaantal`. Dat is het live productieorder-equivalent van
**Qty. per Top Item**: een uurregel van 0,256 onder een onderdeel dat tienmaal
voorkomt draagt 2,56 bij. **Expected Quantity** is hiervoor niet leidend,
omdat daarin ook afronding en productieordercorrecties kunnen zitten. De app
bewaart de uitkomst vóór de PIL-mutatie. Na carrier-,
CALC-, direct-materiaal- en puntartikelwijzigingen telt zij opnieuw. Uitsluitend
het verschil wordt bij de bestaande actieve hoofdroute opgeteld of ervan
afgetrokken. Zo blijven bestaande uren uit niet-uitgevouwen subassemblages
behouden en worden aantoonbaar verwijderde live uren wel verminderd. Een
geneste route krijgt niet hetzelfde ordertotaal. Bij meerdere zelfstandige bovenste routing-eigenaren blijft
de expliciete gekoppelde structuur leidend; de app gokt niet over onafhankelijke
ordertakken.

Een routestap met bestaande **Run Time 0** blijft bewust nul: dat is de veilige
betekenis van een optionele, niet geselecteerde stap. Ontstaat extra tijd voor
een Routing Link Code waarvoor helemaal geen live routingregel bestaat, dan
rolt Apply volledig terug met een gerichte melding. Na de tijdmutatie roept de
app **Calculate Prod. Order.CalculateRoutingFromActual** aan voor de standaard
capaciteitsbehoefte, kosten en planning.

Er is bewust geen aanroep of dependency naar de bestaande Bluace-oplossing.
De app leest of schrijft geen IWX-configuratie, Bluace-object of Item
Routing-stamgegeven; zij vergelijkt uitsluitend actuele productieorderregels,
componenten en live routingregels. Voor een Routing Link Code die door
U.-componenten wordt gevoed, is het actuele ordertotaal leidend; andere
routingregels zonder zo'n U.-bron blijven ongemoeid.

Het integration event **OnAfterPILLiveChangesApplied** wordt pas na carrier-,
CALC- en routingwijzigingen binnen dezelfde transactie gepubliceerd. Een
toekomstige partneraanvulling kan daarop abonneren voor specifiek vervolgwerk,
maar mag geen nieuwe commitgrens of oncontroleerbare wijziging toevoegen.

### Losse actie na handmatige componentwijzigingen

**Routinguren opnieuw berekenen** voert een volledige live orderaggregatie uit
zonder PIL-import of PIL-dossier. De gebruiker bevestigt expliciet dat actieve
routetijden met een Routing Link Code worden vervangen. De preview toont elke
code op een eigen regel met oud, nieuw en verschil. De actie kiest alleen een
eenduidige bovenste routing-eigenaar, blokkeert een gestarte of geboekte
hoofdroute en laat een optionele stap met Run Time nul uitgeschakeld. Zij
blokkeert ook wanneer een niet-uitgevouwen component een eigen gecertificeerde
Production BOM niet gecertificeerd/eenduidig kan worden gelezen. Een geldige
niet-uitgevouwen itemcomponent wordt niet genegeerd: de app leest zijn actieve
gecertificeerde Production BOM read-only, vermenigvuldigt alle geneste regels
tot **Qty. per Top Item** en voegt de routinggekoppelde Non-Inventory-uren toe.
Dit werkt voor ieder artikelnummer en vereist geen extra productieregel of
prefixregel. Afval en de formule **Vast aantal** blijven in deze terugval
geblokkeerd omdat hun per-top-semantiek niet veilig uit alleen de live component
kan worden gereconstrueerd. Na het schrijven herplant standaard Business Central
de hoofdroute.

## Commercieel voorstel en bestaande offerte

Na analyse bestaat er één read-only change line per carrier met oud en nieuw
aantal, verschil, PIL-details, huidige carrierkostprijs en geschatte
kostwijziging. De kostwijziging is een technische indicatie, géén verkoopprijs.
Het Word-rapport **PIL-wijzigingsvoorstel** bevat de header, relevante
PIL-beslissingen, targets/verdeling, carrierkeuzes, voorstelregels en eventuele
offerte-terugdraai-audit. De ruwe en geaggregeerde AutoCAD-tabellen worden niet
als losse tabellen afgedrukt.

Met **Meer- en minderwerk naar bestaande offerte** kiest de gebruiker zelf een
reeds bestaande Sales Quote. De app accepteert uitsluitend een open,
niet-geaccepteerde en niet-verlopen offerte. Zij maakt geen nieuwe offerte.
De normale veilige volgorde is: voorstel controleren, **Pas veilig toe**, daarna
de offerteoverdracht. Wie toch vanuit *Gereed om toe te passen* overdraagt,
krijgt eerst een waarschuwing. Een gekoppelde offerte mag dan niet vóór Apply
worden verwijderd of naar een order worden omgezet, omdat de opgeslagen
artikelregel anders niet meer controleerbaar is. Ook prijs, omschrijving en
andere velden van de aangemaakte artikelregel blijven tot Apply ongewijzigd.

- De app groepeert technische voorstelregels op artikel, variant en eenheid. Per
  groep telt zij alle oorspronkelijke aantallen en alle definitieve aantallen;
  de offertehoeveelheid is uitsluitend `som definitief - som oorspronkelijk`.
- Een positieve nettohoeveelheid is meerwerk, een negatieve nettohoeveelheid is
  minderwerk en een nettohoeveelheid nul maakt geen offerteregel. Zo leveren
  meerdere BOM-posities of carriers van hetzelfde artikel één commercieel
  eindverschil op.
- Artikel, variant, eenheid en positieve of negatieve nettohoeveelheid doorlopen
  de standaard Sales Line-validaties. Price en Line Amount volgen daardoor de
  gewone BC-prijsberekening, niet IWX. Minderwerk blijft expliciet zichtbaar voor
  commerciële prijscontrole.
- Bestaande offerte- en configuratorregels worden niet gewijzigd of verwijderd.
- Alle bijdragende change lines bewaren dezelfde gedeelde offertelink, prijs,
  bedrag, valuta, omschrijving, gebruiker en tijdstip. De integriteitscontrole
  rekent hun gezamenlijke nettohoeveelheid opnieuw uit.

Zolang een actieve offerteoverdracht bestaat, mag de technische snapshot niet
opnieuw worden opgebouwd of herverdeeld. Vóór Apply moeten de voorstelregels en
de gekoppelde actieve **artikelregel** nog precies gelijk zijn aan de opgeslagen
snapshot. Gekoppelde tekst wordt voor rapportage en veilig terugdraaien apart
gecontroleerd; een uitsluitend commerciële tekstwijziging blokkeert technische
Apply niet. De app overschrijft een gewijzigde offerte nooit.

Vóór technische Apply kan **Offerteoverdracht terugdraaien** uitsluitend de
nog ongewijzigde regels verwijderen die dit dossier zelf heeft toegevoegd. Een
reden is verplicht. Iedere verwijderde regel krijgt een onveranderbare
**PNE PIL Quote Reversal**-audit met oude offertegegevens, reden, gebruiker en
tijdstip. Een gedeelde offertregel wordt daarbij precies eenmaal verwijderd,
terwijl iedere bijdragende technische regel haar audit behoudt. Na Apply is automatische terugdraaiing verboden; commerciële
correctie is dan handmatig.

Het rapport blijft technisch bruikbaar wanneer de uitvoerder later geen
leesrecht op Sales Lines heeft. In dat geval meldt het rapport dat de
offertekoppeling niet met de huidige rechten kon worden gecontroleerd, in plaats
van de technische audit te laten falen.

## Rollen en least privilege

| Permission set | Geeft wel | Geeft bewust niet |
|---|---|---|
| 50187 **PNE PIL verwerken** | Dossier, import, analyse, verdeling, rapport, safe apply, readonly productiedata en uitsluitend de bevestigde same-number `Production BOM No.`-reparatie binnen **Puntartikel verhogen**. | Algemene setupmutatie, directe Item-wijzigrechten en Sales Header/Sales Line-rechten. |
| 50198 **PNE productiestructuur bekijken** (`PNE PO Struct View`) | Alleen de configuratiestructuur, de managementcodeunit en benodigde standaard productieorder-/BOM-leesdata. | PIL-dossier, PIL-inrichting, Sales-rechten en elke productieorder- of BOM-mutatie. |
| 50199 **PNE PIL-inrichting** | PIL-groepen/artikelen beheren en CALC-kostprijs herberekenen. | Productieorderwijziging en Sales-rechten. |

De twee offerteacties verschijnen alleen voor een gebruiker met de benodigde
normale Sales Line-rechten. Een gebruiker met alleen **PNE PIL verwerken**
blijft het technische voorstel en rapport zien, maar krijgt geen actie waarop
hij toch geen verkooptoegang zou hebben.

Voor offertehandelingen heeft de gebruiker aanvullend zijn normale BC-verkoop-
en Sales Line-rechten nodig. De app maakt die rechten niet impliciet breder.

## Migratie- en compatibiliteitsgrens

De 2.x-variant is een schone herbouw nadat de vorige 1.x-custom app uit de
Sandbox is verwijderd. Er is geen ForceSync, schema-verwijdering of automatische
conversiepad naar de oude profiel/productiedoel/receptuurvariant.

Versie 2.2.0.0 voegt de begeleide kaart, expliciete negeeraudit,
live-identiteitssnapshots, routingherberekening en offerteoverdracht-
terugdraaiaudit toe aan deze schone variant. De app publiceert, installeert,
upgradet of verwijdert zelf niets. Zie het
[Sandbox-testplan](production-order-reconciliation-test-plan.md) voor alle
verplichte acceptatiescenario's.

Versie 2.3.0.0 voegt uitsluitend de tijdelijke, read-only
configuratiestructuur toe. Versie 2.3.0.1 voorkomt daarnaast dat een
niet-relevante meter-subconfiguratie een afzonderlijke STUKS-PIL-route
onterecht blokkeert. Daarvoor verandert de app geen IWX-record, Business Rule,
Production BOM, Item of productieorder.
