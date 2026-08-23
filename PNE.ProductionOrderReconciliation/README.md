# PNE Production Order Reconciliation

Versie **2.7.0.10** zet een werkelijk AutoCAD-PIL-bestand veilig om naar de
technische inhoud van één productieorder. De app is bedoeld wanneer AutoCAD de
werkelijke artikelen kent, terwijl de productieorder nog een samengesteld
carrier-artikel of een `CALC-*`-placeholder bevat.

Wanneer een live productiecomponent of productieregel een locatie en variant
heeft waarvoor een Stockkeeping Unit een eigen **Production BOM No.** bevat,
gebruikt de app die SKU-BOM. Alleen zonder SKU-BOM valt hij terug op de
Itemkaart. Dit geldt voor structurele analyse, puntartikelcontrole en de
routingurenbron; er is geen artikelnummer hardcoded.

De app verandert nooit een Production BOM-stamkaart, een IWX-record of een IWX
Business Rule. Alleen wanneer een bestaand puntartikel aantoonbaar dezelfde
code heeft als de gevonden, geldige Production BOM maar het artikelveld
**Production BOM No.** leeg of afwijkend is, kan **Puntartikel verhogen** die
artikelkoppeling na een afzonderlijke bevestiging herstellen. Alle beslissingen
en bronregels blijven bewaard in een PIL-dossier.

## Voor de dagelijkse gebruiker

Begin op **Simulated Production Order**, **Firm Planned Prod. Order** of
**Released Production Order**. Onder **Functions** staan:

- **AutoCAD-PIL importeren**;
- **PIL-afstemmingen**;
- **BOM-stamstructuur**; en
- **Routinguren opnieuw berekenen**.

### BOM-stamstructuur zonder extra inrichting

Kies **BOM-stamstructuur** om vóór of tijdens een PIL-test te zien hoe het
bestaande hoofdartikel is opgebouwd. Het overzicht toont het hoofdartikel,
daaronder de bestaande onderliggende Production BOM's als duidelijke koppen en
vervolgens de artikelen per kop. De bestaande **Routing Link Code** blijft
zichtbaar; een lege waarde wordt niet verzonnen of ingevuld.

Er is geen extra tabel, instelling, artikel, dummy-productieorder of
configuratoraanpassing nodig. De pagina leest uitsluitend de Production BOM
die op de productieorderregel is vastgelegd. De root gebruikt dus de daar
opgeslagen BOM en, waar gevuld, versie; zonder versie volgen root en kind-BOM's
de gecertificeerde datumgeldige bestaande versie op startdatum, anders uiterste
datum en zonder beide op werkdatum. Een artikel met een eigen Production BOM
krijgt ook een duidelijke kind-BOM-kop met de gebruikte versie. De pagina maakt
alleen tijdelijke regels tijdens het openen en wijzigt geen productieorder,
Production BOM, Item, IWX-record of Business Rule. Een cirkel, meer dan 50
niveaus of meer dan 20.000 regels geeft een melding en kapt de weergave veilig
af.

Na de import opent een dossier met een duidelijke vierstappenroute:

1. **Analyseer PIL** — de app zoekt automatisch naar de passende carrier en
   maakt een technisch voorstel.
2. **Controleer verdeling** — alleen wanneer één AutoCAD-artikel echt op meer
   dan één carrier past, verdeel je het aantal in **Naar deze carrier**.
3. **Bekijk wijzigingsvoorstel** — controleer de oude en nieuwe aantallen,
   de technische kostenindicatie en eventueel het meerwerk voor een offerte.
4. **Pas veilig toe** — pas het gecontroleerde voorstel toe op de
   productieorder. Na een geslaagde verwerking volgt een bevestiging en sluit
   het dossier automatisch. Het toegepaste dossier blijft via
   **PIL-afstemmingen** beschikbaar als alleen-lezen audit.

De kaart vertelt bovenaan steeds wat de volgende stap is. Gewone gebruikers
hoeven geen tabellen, productiedoelen of Siemens-recepten te onderhouden.

Blijkt na analyse dat de productieorder inmiddels veranderd is, kies dan
**Analyseer opnieuw**. Deze veilige herstelactie is beschikbaar in *Verdeling
nodig* en *Gereed om toe te passen*, zolang er nog geen actieve
offerteoverdracht is.
Hij bouwt de analyse opnieuw op en vervangt eventuele handmatige verdelingen.

## Inrichting: slechts twee tabellen

Een beheerder opent **PIL-inrichting** en onderhoudt per soort losse
placeholder één groep.

| Onderdeel | Wat vul je in? |
|---|---|
| **PIL-groep** | Een herkenbare code, bijvoorbeeld `LED-5MM-ENKEL`, en het bestaande `CALC-*` Non-Inventory-artikel. |
| **PIL-artikelen** | De echte Inventory-artikelen die deze CALC-placeholder mogen vervangen, bijvoorbeeld rood, oranje en geel. |

De lookups gebruiken de Business Central Item-tabel: een CALC-placeholder moet
Non-Inventory zijn; een echt PIL-artikel moet Inventory zijn. Eén actief
AutoCAD-artikel en één actieve CALC-placeholder mogen maar bij één actieve
groep horen.

Een structureel artikel, bijvoorbeeld een vast onderdeel onder een
kabelassembly, hoeft niet als PIL-artikel in een groep te staan. Het wordt dan
wel in het dossier getoond, maar dient alleen om de juiste hogere carrier te
herkennen.

**CALC-kostprijs herberekenen** is een aparte beheeractie. Deze berekent het
ongewogen gemiddelde van de actuele Unit Cost van de ingeschakelde echte
artikelen en vraagt om bevestiging voordat de kostprijs op het CALC-artikel
wordt bijgewerkt. De actie waarschuwt bij nul-kostprijs of een andere
basiseenheid dan `STUKS`.

## Het AutoCAD-PIL-bestand

De import leest een headerloos `.txt`- of `.csv`-bestand met exact vier
komma-gescheiden velden tussen enkele aanhalingstekens:

```text
'Artikelnummer','Tek. KompNr','KlemNr','Art. Aantal'
'4.01.205.02.0','-RD','',''
'4.01.205.03.0','-OR','','4'
```

Een leeg **Art. Aantal** is 1. Elke oorspronkelijke regel blijft zichtbaar in
het dossier; gelijke artikelnummers worden daarnaast opgeteld voor de
vergelijking. Ongeldige velden, negatieve aantallen en een niet-ondersteund
formaat stoppen de import voordat er iets wordt opgeslagen.

## Hoe de app beslist wat verhoogd wordt

`7.*` is niet speciaal en Siemens is niet hardcoded. De app gebruikt de
bestaande productiestructuur.

- Elk bestaand artikel waarvan het nummer met `.` begint is een **carrier**:
  dus niet alleen `.PN...`, maar bijvoorbeeld ook `.EA...`, `.PH...` en
  `.TO...`. Dit is de samengestelde eenheid die de app mag verhogen.
- Een `G.`-artikel telt alleen als carrier mee wanneer het werkelijk een
  produceerbaar voorraadartikel met *Prod. Order* als aanvullingssysteem én
  een geldige gecertificeerde Production BOM of Production BOM-versie is. Een
  `G.`-urengroep, materiaalgroep, purchase-item of andere hulpgroep wordt
  nooit zelfstandig verhoogd; die schaalt alleen mee met de carrier erboven.
- Een losstaande meter- of andere niet-`STUKS`-subconfiguratie zonder een
  positieve PIL-driver of passende CALC-placeholder wordt niet als PIL-route
  onderzocht en blokkeert dus geen afzonderlijke `STUKS`-carrier. Bevat die
  tak wél een PIL-driver of CALC-placeholder, dan stopt de app bewust: een
  headerloos PIL-bestand kan zulke eenheden niet veilig omrekenen.
- Ligt een passend puntartikel en een passend `G.`-artikel in dezelfde
  productieketen, dan krijgt het puntartikel voorrang.
- Binnen die carrier zoekt de app naar het hoogste geïmporteerde artikel met
  een onderliggende productieorder of Production BOM. Dat is de **structurele
  driver**.
- Staat hetzelfde artikelnummer zowel als echte Item-regel als gelijknamige
  Production BOM-kop in de stamstructuur, dan draagt alleen de Item-regel het
  PIL-aantal. De BOM-kop blijft beschikbaar voor de onderliggende structuur en
  wordt niet dubbel geteld. Oude BOM's met alleen zo'n kop blijven via de
  gecontroleerde BOM-terugval herkenbaar.
- Ook wanneer Make-to-Order de hogere assembly en zijn lagere onderdelen plat
  op dezelfde productieregel toont, blijft die aantoonbare hoogste assembly de
  driver. Een gedeeld lager onderdeel kan daardoor niet nogmaals een strijdig
  aantal voor dezelfde carrier afdwingen.
- Onderliggende geïmporteerde artikelen worden dan zichtbaar als **Gedekt
  door structurele carrier**. Zij worden niet nogmaals als CALC-led of losse
  component toegevoegd.
- Is er binnen diezelfde carrier geen structurele driver, dan volgt de
  **CALC-route**: de carrier wordt eerst verhoogd en daarna wordt de bestaande
  CALC-component vervangen door de echte PIL-artikelen.

Daardoor zijn bijvoorbeeld een kabelassembly met een leidend hoger artikel en
een losse `.PN.L5.7` met een eigen CALC-led goed van elkaar te onderscheiden.
De app blokkeert wanneer één geaggregeerd AutoCAD-artikel zowel structureel als
via een onafhankelijke losse CALC-route zou kunnen worden gebruikt: het
vierkoloms-PIL-formaat bevat dan te weinig ouderinformatie om veilig te
splitsen.

Meerdere drivers binnen **dezelfde carrier** zijn minimumvoorwaarden, geen
losse orders. De app kiest daarom automatisch het hoogste benodigde hele
carrieraantal. Bij één gedeeld AutoCAD-artikel over werkelijk onafhankelijke
carriers blijft alleen het nog niet verklaarde restant handmatig verdeelbaar;
de bestaande carrierhoeveelheden worden niet opgeteld of verlaagd.

De rekenregel is steeds hetzelfde: `nieuw carrieraantal = maximaal(huidig
aantal, naar boven afgerond benodigd PIL-aantal / aantal per carrier)`. Is een
deel al door hogere carriers gedekt, dan wordt uitsluitend het restant naar een
extra hele carrier omgerekend. Voorbeeld: basis `1 × 22` en uitbreiding
`2 × 24` dekken samen 70 leds. Bij PIL-totaal 80 is de rest 10, dus wordt één
extra uitbreiding voorgesteld en is het eindtotaal uitbreiding 3. Na verwerking
van dezelfde PIL is de dekking minimaal 80 en volgt geen nieuwe wijziging.

## Als een AutoCAD-artikel niet wordt verwerkt

Een positief artikel zonder veilige koppeling blokkeert de analyse. Dat is
bewust: de app mag geen artikel uit een tekening stilzwijgend weglaten.

Los dit normaal op door de PIL-groep/-artikelen of de productieorderstructuur
te corrigeren. Alleen wanneer een **positief, ongekoppeld artikel werkelijk
niet bij deze productieorder hoort**, kan de gebruiker in de lijst
**Geïmporteerde AutoCAD-PIL** kiezen voor **Bewust negeren**. Een duidelijke
reden is verplicht en gebruiker plus tijdstip worden als audit vastgelegd.
De uitzondering kan vóór Apply met **Negeren herstellen** weer actief worden
gemaakt.

Bestaat een dossier uitsluitend uit bewust genegeerde regels, dan verandert
**Pas veilig toe** geen productieorder. De gebruiker bevestigt dan alleen dat
het gecontroleerde auditdossier afgehandeld is.

## Veilig toepassen en routing

Vlak vóór Apply controleert de app opnieuw of carrier, variant, eenheid,
hoeveelheden, CALC-bron en het wijzigingsvoorstel nog hetzelfde zijn. De app
blokkeert onder andere bij verbruik, reserveringen, magazijnpicks, open
productiejournaalregels, gereedgemelde output, een gestarte/gereedgemelde
routing of geboekte routingactiviteit in de betrokken structuur.

Bij een veilige Apply:

1. wordt de carrier verhoogd met standaard Business Central-validaties;
2. schaalt Business Central de afgeleide draden, uren en materialen;
3. worden alleen de passende bestaande CALC-componenten vervangen door echte
   PIL-artikelen; en
4. legt de app vóór de materiaalwijziging het aantoonbare live
   Non-Inventory-urentotaal per **Routing Link Code** vast en telt dat na de
   wijziging opnieuw. Een U.-component telt daarbij als `Quantity per × aantal
   van zijn productieregel ÷ aantal van het routing-hoofdartikel`: dit is het
   productieorder-equivalent van **Qty. per Top Item**, niet alleen Qty. per
   Parent en niet het afgeronde Expected Quantity. Alleen dit verschil wordt bij de bestaande routetijd van
   het hoofdartikel opgeteld of ervan afgetrokken. Daardoor blijven reeds in de
   route opgenomen uren uit niet-uitgevouwen subassemblages behouden, terwijl
   werkelijk toegevoegde of verwijderde live U.-uren wel doorwerken. Een
   optionele stap met tijd nul blijft nul. Daarna worden de betrokken **Prod.
   Order Routing Lines** opnieuw gepland met de standaard Business
   Central-routingberekening.

De productieregel waarop materiaal of een nieuw puntartikel wordt geplaatst is
niet automatisch de routing-eigenaar. De app kiest eerst de unieke live
productieregel van het productieorder-hoofdartikel; als die niet eenduidig is,
gebruikt zij alleen een aantoonbaar unieke bovenste routingregel. Voor die ene
hoofdroute vergelijkt zij de Routing Link-uren uit **alle** live
productieregels van dezelfde order vóór en na de PIL-wijziging. Daardoor komt
het aantoonbare verschil van alle werkgebieden en subconfiguraties één keer op
de hoofdroute terecht. Na Apply toont de bevestiging per gewijzigde routingcode
de oude tijd, nieuwe tijd en het verschil. Bij meerdere zelfstandige bovenste routings blijft de gekoppelde
productiestructuur leidend en wordt niet stilzwijgend een willekeurige route
gekozen.

De bestaande Bluace-oplossing blijft daarmee buiten deze app. De PIL-app leest
of wijzigt geen IWX-configuratie, Bluace-object of Item Routing-stamgegeven; zij
gebruikt alleen de actuele productieordercomponenten en live routingregels.
Een lokaal partnerproces kan desgewenst transactioneel aansluiten op het
beschikbare `OnAfterPILLiveChangesApplied`-integratie-event.

Na een handmatige wijziging van productiecomponenten hoeft geen PIL te worden
geïmporteerd. Kies op de productieorder **Routinguren opnieuw berekenen**. Na
bevestiging telt de app opnieuw alle actuele Non-Inventory-uurcomponenten met
een Routing Link Code uit alle productieregels op en schrijft zij het volledige
totaal naar de unieke hoofdroute. De actie blokkeert bij een gestarte/geboekte
route, wanneer geen veilige unieke hoofdroute kan worden bepaald, of wanneer
een onderliggende BOM niet gecertificeerd/eenduidig kan worden gelezen. Een
niet-uitgevouwen component met een eigen geldige Production BOM wordt juist
automatisch als aanvullende BOM-bron doorgerekend. Daardoor dragen bijvoorbeeld
G.-groepen hun geneste U.-uren met het juiste aantal per hoofdartikel bij zonder
dat hiervoor een extra productieregel nodig is. De preview toont iedere
routingcode op een eigen regel met **oud**, **nieuw** en **verschil**.

Er is geen `Commit()` in de toepassing. Een fout draait de volledige Apply
terug.

## Netto meer- en minderwerk op een bestaande offerte

Gebruik na **Pas veilig toe** **Meer- en minderwerk naar bestaande offerte**
wanneer het voorstel netto carrierwijzigingen bevat. Overdracht vóór Apply blijft
mogelijk na een duidelijke waarschuwing, maar zet of verwijder die offerte dan
niet voordat de technische wijziging is toegepast. Wijzig vóór Apply ook de
aangemaakte artikelregel of prijs nog niet; controleer prijzen daarna.

- Je kiest zelf een bestaande, open, niet-geaccepteerde en niet-verlopen
  offerte.
- De app groepeert alle technische carrierregels op artikel, variant en eenheid.
  Zij telt per groep het oorspronkelijke aantal en het definitieve aantal op en
  draagt uitsluitend `definitief - oorspronkelijk` over.
- Een positief netto verschil wordt een gewone meerwerk-Item-regel; een negatief
  netto verschil wordt een gewone minderwerk-Item-regel met negatieve
  hoeveelheid. Netto nul maakt geen offerteregel.
- Meerdere carriers of BOM-posities van hetzelfde artikel kunnen daardoor één
  gedeelde offerteregel krijgen. Bestaande offerte- en configuratorregels blijven
  ongewijzigd.
- De normale Business Central-verkoopprijsberekening bepaalt prijs en bedrag;
  IWX-prijslogica wordt niet aangeroepen. Controleer bij minderwerk bewust de
  negatieve prijs en het bedrag.
- Geldige standaard artikelteksten waarvoor **Automatic Ext. Texts** en
  **Sales Quote** zijn ingeschakeld, worden automatisch als gekoppelde
  tekstregels toegevoegd. Iedere positieve
  tekstregel begint met het netto aantal; bij een negatieve regel staat er
  duidelijk **Minderwerk** met het absolute aantal. De offerte gebruikt haar
  eigen documentdatum en taal.
- De tekst wordt rechtstreeks uit standaard Business Central Extended Text
  gelezen. Er wordt geen IWX-configuratie geopend of opnieuw berekend. Een
  wijziging aan de artikelregel blokkeert technische Apply. Een wijziging aan
  uitsluitend gekoppelde tekst maakt de commerciële koppeling
  beoordelingsplichtig en blokkeert veilig automatisch terugdraaien, maar houdt
  de technische productieorderwijziging niet tegen.
- Het dossier bewaart offerte-, regel-, prijs-, bedrag-, gebruiker- en
  tijdstempelaudit. Het afdrukbare **PIL-wijzigingsvoorstel** laat zowel de
  technische als commerciële status zien.

Vóór technische Apply kun je een foutieve overdracht met
**Offerteoverdracht terugdraaien** herstellen. Alleen nog ongewijzigde regels
die dit dossier zelf heeft toegevoegd worden verwijderd. Ook hiervoor is een
reden verplicht; die komt in een onveranderbare terugdraai-audit. Na Apply
blijft commerciële correctie handmatig.

## Rollen

| Rol | Gebruik |
|---|---|
| **PNE PIL verwerken** (50187) | Importeren, analyseren, verdelen, voorstellen bekijken en toepassen. Binnen **Puntartikel verhogen** kan deze rol uitsluitend na bevestiging de bewezen same-number Production BOM-koppeling herstellen; zij geeft geen algemeen Item-wijzigrecht en bevat géén Sales Quote-rechten. |
| **PNE productiestructuur bekijken** (50198) | Alleen **BOM-stamstructuur** en de benodigde standaard productieorder-/BOM-leesdata. Geen PIL- of mutatierecht. |
| **PNE PIL-inrichting** (50199) | PIL-groepen en PIL-artikelen onderhouden en CALC-kostprijs herberekenen. |
| Normale Business Central-verkooprechten | Nodig naast de PIL-rol om een bestaande offerte te kiezen, regels toe te voegen of terug te draaien. |

De twee offerteacties worden alleen getoond wanneer de gebruiker ook de
benodigde normale Sales Line-rechten heeft. Zo krijgt een technische PIL-
verwerker geen verkoopknop waarop hij vervolgens geen toegang heeft.

## Versie- en installatiegrens

Versie 2.0.0.0 was een schone herbouw nadat de oude 1.x-app uit de Sandbox was
verwijderd. Versie 2.2.0.0 bouwt daarop voort met begeleide bediening,
expliciete uitzonderingsaudit, strengere live-snapshot- en routingveiligheid
en controleerbare offerteoverdracht/terugdraaiing. Versie 2.3.0.0 voegt de
alleen-lezen configuratiestructuur uit de bestaande Production BOM toe.
Versie 2.3.0.1 voorkomt dat een losstaande, niet-relevante meter-subconfiguratie
die weergave of een afzonderlijke STUKS-PIL-route onterecht blokkeert. Versie
2.3.0.2 verdeelt één gedeeld AutoCAD-artikel automatisch over carriers die
door andere, unieke productiecomponenten al eenduidig zijn bepaald.
Versie 2.3.0.3 houdt bestaande niet-STUKS-componenten, zoals plaat in M2,
als productieorderbehoefte aan: de AutoCAD-regel bevestigt alleen aanwezigheid
en verandert het aantal niet.
Versie 2.3.0.4 herkent configuratiekoppen, zoals een niet-voorraad `G.`-groep
zonder Production BOM, als informatieve AutoCAD-regel. Zo'n regel bevestigt de
subconfiguratie maar wijzigt of blokkeert de productieorder niet. Versie
2.4.0.0 laat een ongekoppeld STUKS-artikel niet meer vastlopen: kies het als
los component of onder een bestaand passend puntartikel. De carrierkeuze toont
alleen puntartikelen waarvan de bestaande Production BOM het AutoCAD-artikel
daadwerkelijk bevat.
Versie 2.4.0.1 maakt die tussenstap expliciet op het dossier: een ongekoppelde
regel is geen foutmelding maar een keuze-opdracht; selecteer de regel en kies
de gewenste verwerking vóór u de verdeling controleert.
Versie 2.4.0.2 gebruikt bij een bestaand, niet-uitgevouwen puntartikel ook de
echte vaste artikelen uit zijn Production BOM als verdeelbewijs. Daardoor kan
een gedeeld artikel, zoals een schakelelement dat onder meerdere `.EA...`
artikelen zit, de juiste carrierhoeveelheden ondersteunen in plaats van alleen
als bestaand component te worden gemeld.
Versie 2.4.0.3 doet hetzelfde wanneer die vaste artikelen al in de actuele,
uitgevouwen productieorder onder een puntartikel staan. Zo wordt een bestaand
component onder bijvoorbeeld `.EA...` direct gebruikt als bewijs voor die
carrier, zonder dat de gebruiker hem opnieuw moet toevoegen.
Versie 2.4.0.4 maakt de gebruikskeuze scherp: als een ongekoppeld AutoCAD-
artikel in een bestaand puntartikel voorkomt, kiest de gebruiker
**Puntartikel verhogen**. Bij een gekoppelde subproductieregel wordt die
regel verhoogd, zodat de bestaande BOM ook draden, uren en overige onderdelen
meeneemt. Los materiaal is alleen nog de keuze voor een artikel zonder
passend puntartikel.
Versie 2.5.0.0 breidt die keuze uit naar puntartikelen die nog niet op de
productieorder staan. De zoeklijst komt uit de gecertificeerde Production BOMs.
Bij Toepassen wordt het gekozen productiepuntartikel onder de unieke
hoofdproductieregel toegevoegd en door standaard Business Central als
onderliggende productieregel uitgeklapt. Daardoor komen de volledige bestaande
BOM, uren en bedrading mee; het losse AutoCAD-artikel wordt niet kaal toegevoegd.
Versie 2.5.0.1 slaat tijdens deze lookup ongeldige, ontbrekende of niet voor de
orderdatum gecertificeerde kandidaat-BOMs over. Eén oud of incompleet
puntartikel in de artikelstam kan daardoor de volledige keuzelijst niet meer
blokkeren; alleen werkelijk bruikbare puntartikelen worden getoond.
Versie 2.5.0.2 zoekt vanuit het AutoCAD-artikel omhoog naar de actieve,
gecertificeerde Production BOMs. Daardoor hoeft de lookup niet langer alle
puntartikelen en hun volledige BOM afzonderlijk te openen. Een expliciete
koppeling blijft bij de eindcontrole leidend, ook wanneer hetzelfde bladartikel
al ergens anders als productiecomponent voorkomt.
Versie 2.5.0.3 maakt de bestaande actie **Als echt los materiaal toevoegen**
geschikt voor één of meerdere geselecteerde open regels. De gebruiker kiest de
doel-productieregel één keer; ieder geselecteerd AutoCAD-artikel wordt als een
afzonderlijk componentvoorstel op die regel vastgelegd. De volledige selectie
wordt eerst gevalideerd, slechts eenmaal herberekend en bij één fout volledig
teruggedraaid. Hiervoor is geen aparte bulkknop.
Versie 2.5.0.4 houdt **Puntartikel verhogen** bewust bij één gekozen
AutoCAD-regel. Na de keuze doorzoekt de app wel alle geneste Item- en
Production-BOM-niveaus van dat puntartikel. Andere nog open PIL-artikelen uit
dezelfde BOM worden automatisch meegekoppeld wanneer zij exact hetzelfde
benodigde puntartikelaantal bevestigen. Een afwijkend artikel blijft open voor
een aparte keuze en blokkeert de geldige koppeling niet.
Versie 2.5.0.5 herkent bij die omgekeerde zoekactie ook een AutoCAD-artikel dat
in de bovenliggende BOM als **Production BOM** is opgenomen in plaats van als
gewone Item-regel. De lookup begint dan bij die actieve, gecertificeerde BOM en
vindt daarboven het bijbehorende puntartikel. Dit is algemene BOM-logica; er
zijn geen artikelcodes zoals `8.02.160.50.0` hardcoded.
Versie 2.5.0.6 controleert bij **Veilig doorvoeren** ook directe structurele
bladcomponenten correct opnieuw. Een artikel hoeft dus niet zelf nog een
onderliggende productieregel te hebben om als ongewijzigd te worden herkend.
Wanneer een gekozen puntartikel al een toeleverende productieregel heeft,
wordt bovendien exact die live orderstructuur als controlesnapshot gebruikt.
Versie 2.5.0.7 herkent de interne BC-reservering tussen zo'n toeleverende
productieregel en de bovenliggende productiecomponent. Standaard Business
Central onderhoudt dat reserveringspaar tijdens de gevalideerde
hoeveelheidswijziging. Alleen externe voorraad-/documentreserveringen blijven
blokkeren, net als verbruik, picks en gereedgemelde productie.
Versie 2.5.0.8 laat de ene gecontroleerde statusovergang van **Gereed** naar
**Toegepast** correct toe door de werkelijk opgeslagen dossierstatus te lezen.
Daarna blijft het toegepaste dossier onwijzigbaar als auditbewijs. Een fout
tijdens deze overgang rolt nog steeds de volledige toepassing terug omdat de
app nergens tussentijds commit.
Versie 2.5.0.9 rondt de gebruikersstroom na een geslaagde toepassing af met
een bevestiging en sluit het dossier. Het auditdossier kan later altijd opnieuw
worden geopend via **PIL-afstemmingen**.
Versie 2.5.0.10 laat bij een nieuw puntartikel eerst het juiste bestaande
werkgebied of de juiste subconfiguratie kiezen. De benodigdheidsdatum volgt de
start van dat werkgebied en Business Central plant de nieuwe puntartikelregel
achterwaarts. De app verwerkt daarnaast alleen de aantoonbare wijziging in
routinggekoppelde U.-uren op actieve routestappen; uitgeschakelde stappen met
tijd nul blijven uitgeschakeld. Een PIL die al volledig in de huidige order is
verwerkt kan als compleet no-change-dossier worden vastgelegd. De tijdelijke
2.5.0.9-importfout door modaal openen na databasewijzigingen is verwijderd.
Versie 2.5.0.11 behandelt een Routing Link Code die alleen vóór of alleen ná
de PIL-wijziging voorkomt correct als nul aan de ontbrekende kant. Daardoor
kan een nieuw of verdwenen uurcomponent veilig worden vergeleken zonder de
technische melding dat een sleutel niet in de woordenlijst staat. Een fout
tijdens toepassen blijft de volledige transactie terugdraaien.
Versie 2.5.0.12 rekent U.-componenten onder losse werkgebied- en
subconfiguratieregels door naar het hoofdartikel wanneer dat aantoonbaar de
enige live routing-eigenaar van de productieorder is. De routinguren blijven
daardoor niet meer ongewijzigd wanneer een nieuw puntartikel onder zo'n
werkgebied wordt toegevoegd. Deze keuze is gebaseerd op de actuele
productieorderstructuur en niet op een artikelprefix of hardcoded nummer.
Versie 2.5.0.13 houdt bij plat uitgevouwen Make-to-Order-structuren de
aantoonbaar hoogste geïmporteerde assembly als driver en de lagere BOM-regels
als gedekte auditregels. Versie 2.5.0.14 maakt echte driverconflicten
herstelbaar met een bewuste carrieraantalkeuze en reden. Dezelfde versie trekt
de routingvergelijking los van de materiaalbestemming: alle Routing Link-uren
van de order worden vergeleken en het verschil komt eenmaal op de unieke
hoofdroute terecht.
Versie 2.5.0.15 vervangt die verschilbenadering door een volledige live
herberekening: iedere actieve hoofdroutebewerking krijgt het actuele totaal van
alle bijbehorende U.-componenten in de productieorder. Zo blijft een reeds
onjuiste of onvolledige bestaande routetijd niet als basis staan.
Versie 2.6.0.0 maakt de dagelijkse stroom af. De puntartikel-lookup gebruikt
eerst de echte live productiestructuur en daarna pas gecertificeerde BOM-
stamgegevens. Gelijke carrieradviezen worden samengenomen; alleen werkelijk
verschillende positieve adviezen vragen om één gemotiveerde keuze. Meerdere
losse materialen kunnen in één normale actie naar dezelfde productieregel.
Direct materiaal blijft technische nacalculatie en wordt niet automatisch als
carriermeerwerk naar een offerte gestuurd. Het wijzigingsrapport toont het
carrierbesluit en de productiebestemming, maar niet de ruwe AutoCAD-tabellen.
De losse routingactie toont vooraf ieder volledig oud/nieuw ordertotaal,
controleert ontbrekende en dubbele links en laat een bewust uitgeschakelde
nul-tijdroute uitgeschakeld. Herhaalde boom- en artikelzoekacties gebruiken
herbruikbare tijdelijke indexen en caches.
Versie 2.6.0.1 herkent een al verwerkt structureel AutoCAD-artikel opnieuw via
de BOM en versie die op de gekoppelde puntartikel-productieregel zijn
vastgelegd. Staat hetzelfde artikelnummer zowel als echte Item-regel als
gelijknamige Production BOM-kop in de stamstructuur, dan draagt alleen de
Item-regel het fysieke PIL-aantal. De BOM-kop blijft beschikbaar voor de
onderliggende structuur, maar de kop en zijn inhoud worden niet dubbel geteld.
Oudere BOM's met alleen zo'n kop blijven via de gecontroleerde BOM-terugval
herkenbaar.
Versie 2.6.0.2 controleert daarna ook iedere nog open PIL-regel tegen de
puntartikelen die al werkelijk op de productieorder staan. Wanneer precies één
bestaand puntartikel de regel via zijn live structuur of vastgelegde,
gecertificeerde BOM bevat, wordt die bestaande positie automatisch gebruikt en
wordt alleen het nog niet gedekte aantal verdeeld. De gebruiker krijgt daarom geen overbodige bestemmingsvraag;
bij nul of meerdere matches blijft de regel juist open voor een bewuste keuze.
Deze nacontrole doorzoekt alleen puntartikelen op de actuele productieorder en
maakt geen nieuwe volledige artikelstam-index. **Controleer verdeling** noemt nu
het concrete open AutoCAD-artikel, het resterende aantal of het carrierconflict
in plaats van één algemene melding.

Versie 2.6.0.3 voorkomt een vals half carrieraantal wanneer een reeds bewerkte
productieorder dezelfde structurele route tweemaal zichtbaar maakt. De app
toont de live gevonden factor, vergelijkt die met het recept van de geldige
Production BOM en gebruikt bij een aantoonbare oude/nieuwe dubbelroute de
enkele BOM-factor. Het voorstel laat voortaan ook de berekening
`PIL-aantal / aantal per carrier = voorgesteld carrieraantal` zien. Daardoor
geven bijvoorbeeld één voeding per `.TO.P.SI.FP2015` en twee accu's per
dezelfde carrier allebei carrieraantal 1, zonder handmatige keuze. Deze
correctie is generiek en bevat geen Siemens- of artikelnummerlijst.

Versie 2.6.0.4 telt de werkelijke capaciteit van hogere structurele drivers
eerst op voordat een lager AutoCAD-artikel wordt beoordeeld. Een lagere regel
kan daardoor volledig of gedeeltelijk gedekt zijn. Alleen het restant blijft
zichtbaar voor **Puntartikel verhogen** of **Als echt los materiaal toevoegen**.
Kiest de gebruiker een bestaand puntartikel voor zo'n restant, dan rondt de app
naar hele extra puntartikelen omhoog en stelt zij automatisch het volledige
nieuwe carrieraantal voor. Voorbeeld: één basis met 22 rode leds en twee
uitbreidingen met 24 dekken samen 70 van 80 leds; koppeling van de resterende
10 aan dezelfde uitbreiding geeft automatisch één extra uitbreiding en dus
eindtotaal 3. De berekening komt uit de geldige BOM en bevat geen vaste
Siemens-, led- of artikelcodes. Alleen onafhankelijk strijdige hoofdregels
blijven een bewuste carrieraantalkeuze vereisen.

Versie 2.6.0.5 herstelt daarnaast bestaande conceptverdelingen waarin een
lagere regel vóór deze capaciteitsberekening nog met zijn volledige PIL-totaal
was opgeslagen. **Verdeling controleren** berekent eerst opnieuw wat hogere
carriers dekken en vervangt bij één gekozen restcarrier automatisch bijvoorbeeld
80 door het werkelijke restant 10. Daarmee wordt `10 / 24 => +1, totaal 3`
berekend. Staat de carrier al op 3, dan toont het voorstel verschil nul.

Versie 2.7.0.3 versnelt de dagelijkse verwerking zonder de beslisregels te
versoepelen. De puntartikelzoekactie bepaalt de geldige BOM-versie nog maar
eenmaal per BOM en scant alleen puntartikelkandidaten. **Analyseer PIL** bouwt
een tijdelijke index van de actuele puntartikelen en vergelijkt alle nog open
AutoCAD-artikelen daar in één doorgang mee, in plaats van de productieorder per
PIL-regel opnieuw uit te vouwen. Na een handmatige puntartikelkeuze wordt de
gekozen BOM eenmaal voorgefilterd; alleen werkelijke matches krijgen daarna nog
de volledige aantalscontrole. Bij **Pas veilig toe** wordt een nieuw
puntartikel nog steeds één keer volledig door standaard Business Central
berekend, maar dezelfde nieuwe onderboom wordt daarna niet onnodig voor een
tweede keer gepland. Een structurele carrierwijziging blijft bewust de volledige
geraakte kindstructuur herberekenen. Alle tijdelijke indexen bestaan alleen
tijdens de actie, zodat gewijzigde stam- of ordergegevens bij de volgende actie
opnieuw worden gelezen.

Versie 2.7.0.4 vermindert de resterende herhaalde lees- en rekenrondes. Na een
handmatige puntartikelkeuze wordt de geldige BOM nog maar eenmaal doorgerekend
tot een aantallenkaart voor alle passende open PIL-artikelen. Structurele
analyse hergebruikt binnen dezelfde actie een index van BOM-inhoud en van
productieregels met een positieve driver. **Pas veilig toe** controleert iedere
geraakte productieregel en component eenmaal, ook wanneer meerdere carriers
dezelfde parent-/child-keten raken. De routingcontrole rekent iedere gelijke,
niet-uitgevouwen BOM eenmaal per actie door en vermenigvuldigt die uitkomst
daarna met het actuele aantal per voorkomend component. De uitkomst, alle
veiligheidsblokkades en de volledige voor/na-routingvergelijking blijven
ongewijzigd; de caches bestaan alleen zolang de betreffende actie draait.

Versie 2.7.0.5 herstelt de zoeklijst van **Puntartikel verhogen** op een
meerregelige productieorder. De snelle omgekeerde BOM-zoektocht gebruikt nu de
relevante datums van alle productieregels, zodat een geldige gecertificeerde
BOM-versie van een paneel-, bedrading- of ander werkgebied niet meer verdwijnt
door de datum van een willekeurige eerste productieregel. Levert die snelle
route geen kandidaat op, dan volgt een volledige gezaghebbende controle van de
geldige puntartikel-BOMs. De gekozen bestemmingsregel wordt daarna nog steeds
exact tegen zijn eigen datum en BOM gecontroleerd; een ruimere zoeklijst maakt
dus geen ongeldige toevoeging mogelijk.

Versie 2.7.0.6 neemt in de eerste omgekeerde BOM-stap zowel standaard
**Item**-regels als standaard **Production BOM**-regels mee. Dit is nodig voor
modulaire puntartikelen waarbij het AutoCAD-artikel als onderliggende
Production BOM in de bovenliggende puntartikel-BOM staat. De gevonden ouder-
BOM en het uiteindelijke puntartikel moeten nog steeds actief en gecertificeerd
zijn; de aanpassing maakt geen ongeldige of hardcoded artikelroute mogelijk.
Een gerichte directe-oudercontrole vult dezelfde kandidaten nogmaals vanuit de
werkelijke BOM-regel. Blijft de lijst leeg, dan noemt de fout voortaan de
gevonden BOM of het puntartikel en de concrete afwijzingsreden, zoals artikel-
soort, aanvulsysteem, eenheid, certificering, versie of regeldatum.

Versie 2.7.0.7 voorkomt dat zo'n aantoonbaar gevonden BOM een doodlopende
inrichtingsfout wordt. Wanneer een bestaand STUKS-puntartikel dezelfde code
heeft als de actieve, gecertificeerde Production BOM, verschijnt het ook als
zijn veld **Production BOM No.** nog leeg is of naar een andere BOM wijst. De
keuzelijst toont dit vooraf in **Koppelstatus**. Na de puntartikel- en eventuele
werkgebiedkeuze vraagt dezelfde actie expliciet of de artikelkoppeling blijvend
mag worden hersteld; weigeren wijzigt niets. De app gebruikt daarna de normale
Business Central-veldvalidatie en schrijft geen Production BOM-regels of IWX
Business Rules. De operationele rol krijgt hierdoor geen algemeen recht om
Items buiten deze gerichte reparatie te wijzigen.

Versie 2.7.0.9 groepeert de commerciële overdracht per artikel, variant en
eenheid. Meerdere technische carriers of BOM-posities leveren daardoor één
vergelijking tussen het gezamenlijke oorspronkelijke en definitieve aantal.
Alleen het netto verschil gaat naar de bestaande offerte: positief als
meerwerk, negatief als minderwerk en nul als geen offerteregel. Een gedeelde
offertregel wordt bij controle en terugdraaien eenmaal behandeld, terwijl de
audit op iedere technische bronregel behouden blijft.

Versie 2.7.0.10 voegt bij iedere netto meer-/minderwerkregel automatisch de
geldige standaard artikeltekst toe wanneer **Automatic Ext. Texts** en
**Sales Quote** zijn ingeschakeld. Positieve tekst begint met
het netto aantal, negatieve tekst met **Minderwerk** en het absolute aantal.
Tekstregels blijven aan de aangemaakte artikelregel gekoppeld, gaan daardoor
mee door de standaard verkoopdocumentstroom en worden samen gecontroleerd en
teruggedraaid. Een latere tekstwijziging vraagt commerciële controle, maar
blokkeert technische Apply niet. De PIL-app leest alleen standaard Extended
Text en blijft onafhankelijk van IWX.

Gebruik geen ForceSync om een oude 1.x-variant om te zetten. Publiceren,
installeren, upgraden of verwijderen gebeurt nooit door deze app zelf.

Zie ook de [functionele en technische uitleg](../../docs/production-order-reconciliation.md)
en het [Sandbox-testplan](../../docs/production-order-reconciliation-test-plan.md).
