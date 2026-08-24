# PNE Production Order Reconciliation 2.8 — Sandbox-testplan

Dit is het handmatige acceptatieplan voor versie **2.8.0.1**. Leg per run vast:
Sandbox-URL en company, BC-versie, appversie, uitvoerder, datum,
productieorder, bronbestand, verwachte uitkomst en werkelijke uitkomst.

Voer dit uitsluitend in een Sandbox uit. Publiceren, installeren, upgraden,
verwijderen en een schema-update zijn afzonderlijke handelingen en vallen niet
onder dit testplan. Gebruik nooit ForceSync.

## 1. Schone uitgangssituatie en rollen

Voorwaarde: de oude 1.x-custom app is verwijderd uit een wegwerp-Sandbox. De
v2-app wordt als schone app gebruikt; er is geen omzetting van oude
Profile-/Productiedoelen-/Assembly-recipegegevens.

1. Wijs gebruiker **A** alleen permission set **PNE PIL verwerken** (50187)
   toe, plus de normale leesrechten die in die Sandbox nodig zijn om de
   productieorder te openen.
2. Wijs gebruiker **B** alleen **PNE PIL-inrichting** (50199) toe.
3. Wijs gebruiker **C** zowel 50187 als 50199 toe.
4. Wijs gebruiker **D** 50187 plus de bestaande normale Business Central
   rechten op Sales Quote en Sales Line toe.
5. Wijs gebruiker **E** alleen **PNE productiestructuur bekijken** (50198) toe,
   plus de normale standaard Business Central-leesrechten waarmee die
   gebruiker de betreffende productieorderpagina mag openen.
6. Controleer bij A:
   - PIL importeren, dossier, rapport en productieorder-PIL-acties zijn
     beschikbaar;
   - **PIL-inrichting** is niet beschikbaar voor onderhoud;
   - de gebruiker kan geen Sales Quotes browsen of wijzigen uitsluitend door
     50187; en
    - **Meer- en minderwerk naar bestaande offerte** en
      **Offerteoverdracht terugdraaien** zijn niet zichtbaar.
7. Controleer bij B dat de inrichting werkt, maar dat de gebruiker de
   productieorderverwerking niet kan uitvoeren zonder 50187.
8. Controleer bij C dat groepen/artikelen onderhoudbaar zijn en bij D dat een
   bestaande offerte kan worden gekozen.
9. Controleer bij E op Simulated, Firm Planned en Released Production Order
   dat **Functions > BOM-stamstructuur** opent, maar dat E zonder andere
   eigen rechten geen PIL-import, PIL-dossier, PIL-inrichting, Sales Quote of
   productieorderwijziging krijgt. De lijst zelf heeft geen **Nieuw**,
   **Bewerken**, **Verwijderen** of andere mutatieactie.
10. Controleer dat geen oude profile-, productiedoel-, position- of
   assemblyreceptpagina/tabel uit deze app bestaat.

Verwacht: 50187, 50198 en 50199 zijn gescheiden; Sales-rechten blijven normale
Business Central-rechten en worden niet door de app uitgedeeld.

### 1.1 BOM-stamstructuur — bestaande BOM zichtbaar, niets wijzigen

Voor deze test is geen PIL-bestand, PIL-groep of extra inrichting nodig.
Gebruik een bestaande productieorderregel waarop **Production BOM No.** en,
waar aanwezig, **Production BOM Version Code** al zijn vastgelegd. Kies bij
voorkeur een testartikel waarvan de root-BOM vier onderliggende Production
BOM's bevat, zoals deze bestaande configuratie:

| Gewenste kop in het overzicht | Voorbeeld uit de testconfiguratie |
|---|---|
| Kastproductie | `OBJAV262656` — Brandmeldpaneel op maat |
| Kast/constructiedeel | `OBJAV262665` — PD10.150SI 1.650mm x 950mm |
| Plotterdeel | `OBJAV262674` — UV inkt op dibond digital 3 mm |
| Bedrading/methode | `OBJAV262683` — meth: Siemens ledk FT2001-A1 met voeding |

1. Open een geschikte productieorder in elk van de drie ondersteunde statussen:
   **Simulated**, **Firm Planned** en **Released Production Order**. Dat mogen
   drie kopieën van dezelfde testconfiguratie zijn; één productieorder heeft
   immers steeds maar één status. Kies telkens **Functions >
   BOM-stamstructuur**.
2. Controleer bovenaan de juiste productieorder, **Hoofd-BOM / versie** en de
   bronuitleg. De eerste regel is **Hoofdartikel**. Daaronder staan de vier bestaande
   **Onderdeel-BOM**-koppen in de bestaande BOM-volgorde, met alleen hun eigen
   artikelen ingesprongen onder de juiste kop. De pagina mag dus niet één platte
   lijst maken en ook geen nieuwe kop, `G.`-artikel of dummy-productieorder
   verzinnen. Heeft een artikel zelf weer een Production BOM, dan verschijnt
   die kind-BOM ook als eigen kop met de werkelijk gebruikte **BOM-versie**.
3. Controleer per regel **Artikel-/BOM-nr.**, **Aantal**, **Eenheid** en
   **Routing-link**. Een aanwezige Routing Link Code moet exact uit de
   bestaande BOM-regel komen; een lege waarde blijft leeg. De pagina leidt geen
   route, werkplek of `U.`-uur af.
4. Maak in een kopie van de Sandbox-testdata een root die op de
   productieorderregel nog naar een oudere, geldige BOM-versie wijst, terwijl
   het Item inmiddels een andere huidige BOM of versie heeft. Het overzicht
   moet de op de **Prod. Order Line** vastgelegde root-BOM/-versie tonen, niet
   de nieuwe Item-inrichting.
5. Maak onder een onderliggende BOM twee gecertificeerde, datumgeldige versies
   met verschillende herkenbare regels. Kies een startdatum op de
   productieorderregel die slechts bij één versie past. De kind-BOM in de
   boom moet die datumgeldige gecertificeerde versie tonen. Herhaal zonder
   startdatum met een passende **uiterste datum** (Due Date), en als beide
   datums leeg zijn met de werkdatum. Dit is bewust geen historische
   kind-BOM-snapshot.
6. Maak in afzonderlijke wegwerp-testdata (a) een cirkel van onderliggende
   Production BOM's en (b) een keten dieper dan 50 niveaus. De pagina moet een
   duidelijke **Melding** tonen en veilig stoppen; zij mag niet hangen, geen
   lus tonen en niets aanpassen.
7. Maak in afzonderlijke wegwerp-testdata meer dan 20.000 zichtbare
   structuurregels. De pagina moet na 20.000 regels één duidelijke **Melding**
   tonen dat de structuur is afgekapt. Zij mag niet lang blijven doorlopen of
   alsnog onderdelen buiten de limiet lezen/schrijven.
8. Leg vóór het openen de aantallen en laatste wijzigdatum vast van de
   productieorder, productieorderregels/-componenten, Production BOM
   Header/Line/Version, het root-Item en de PNE PIL-tabellen. Open en sluit de
   pagina meerdere keren. Alles blijft identiek; er ontstaat geen
   PIL-dossier, PNE-auditrecord of regel `PNE-TEMP-STRUCT` in de echte
   Production BOM Line-tabel. De regels bestaan alleen tijdelijk tijdens het
   geopende overzicht.

Verwacht: de structuur maakt de bestaande vier onderdelen begrijpelijk zonder
de manier waarop de productieorder is aangemaakt te veranderen. De rol 50198
kan uitsluitend deze bronweergave openen; zij krijgt geen PIL- of
productieordermutatierecht.

## 2. PIL-inrichting en kostprijs

Maak als C de minimale inrichting:

| PIL-groep | CALC-placeholder (Non-Inventory) | Werkelijke Inventory-items |
|---|---|---|
| **LED-5MM-ENKEL** | **CALC-LED-5MM-ENKEL** | **4.01.205.02.0**, **4.01.205.03.0**, **4.01.205.04.0** |

Controleer:

- de CALC-lookup weigert een Inventory-item;
- de PIL-artikellookup weigert een Non-Inventory-item;
- de omschrijving van een gekozen BC-item wordt gevuld;
- hetzelfde actieve AutoCAD-artikel niet in twee actieve groepen mag staan;
- dezelfde actieve CALC-placeholder niet in twee actieve groepen mag staan;
- een uitgeschakelde groep of artikelkoppeling niet als actieve CALC-route
  wordt gebruikt;
- een structurele led, bijvoorbeeld **4.01.453.02.0**, niet per se als
  groepsartikel hoeft te bestaan om als structureel onderdeel te worden gezien.

Voor de kostprijs: gebruik drie actieve artikelen met Unit Cost 10, 20 en 30.
Kies **CALC-kostprijs herberekenen** en controleer vóór bevestiging de
preview: actief aantal 3, kostsom 60, gemiddelde 20 en de waarschuwingstekst.
Bevestig en controleer de kostprijs van het CALC-item. Herhaal met kostprijs 0
en/of basiseenheid anders dan **STUKS**: de waarschuwing moet zichtbaar zijn.

## 3. Werkelijk headerloos AutoCAD-PIL-formaat en ruwe audit

Importeer op een geschikte testorder:

~~~text
'4.01.205.02.0','-RD','',''
'4.01.205.02.0','-RD','',''
'4.01.205.03.0','-OR','','4'
'4.01.205.04.0','-GL','','1,00'
'4.01.205.04.0','-GL','','1.00'
'ONBEKEND','X1','K1','2'
~~~

Controleer:

- het dossier de zes oorspronkelijke regels toont inclusief Tek. KompNr,
  KlemNr en de oorspronkelijke hoeveelheidstekst;
- lege aantallen als 1 worden gelezen;
- **1,00** en **1.00** beide als 1 worden gelezen;
- geaggregeerd rood 2, oranje 4 en geel 2 zichtbaar zijn;
- **ONBEKEND** in de bron-audit blijft staan en nooit een component wordt;
- het dossier aan precies de gekozen productieorder is gekoppeld.

Negatieve importgevallen die volledig moeten blokkeren:

- minder of meer dan vier velden;
- ontbrekende/niet-sluitende enkele aanhalingstekens;
- leeg artikelnummer;
- negatief, niet-numeriek of te nauwkeurig aantal;
- lege invoer zonder AutoCAD-regel;
- invoer zonder positieve regel;
- invoer met alleen positieve items die in BC niet bestaan.

Een nulhoeveelheid blijft zichtbaar als nul en veroorzaakt geen
carrierverhoging.

## 4. Begeleide kaart en actievolgorde

Open het nieuwe dossier en controleer de kaarttekst en knoppen:

| Status | Verwachte primaire actie |
|---|---|
| Geïmporteerd | **Stap 1 - Analyseer PIL** |
| Verdeling nodig | **Stap 2 - Controleer verdeling** of, na een correctie, **Analyseer opnieuw** |
| Gereed om toe te passen | **Stap 3 - Bekijk wijzigingsvoorstel**, **Stap 4 - Pas veilig toe** en, zolang geen offerteoverdracht actief is, **Analyseer opnieuw** |
| Toegepast | Alleen audit/rapport; niet nogmaals toepassen |

Controleer dat de kaart de delen **1. Geïmporteerde AutoCAD-PIL**, **2.
Verdeling over productiecarriers**, **3. Voorgestelde productie- en commerciële
wijzigingen** laat zien. De onveranderbare AutoCAD-bronregistratie mag niet als
vierde dagelijkse tabel zichtbaar zijn. Controleer op Simulated, Firm Planned
én Released Production Order onder **Functions** **AutoCAD-PIL
importeren**, **PIL-afstemmingen** en **BOM-stamstructuur**. Het openen van
alleen de configuratiestructuur mag geen PIL-dossier, import of
productieorderwijziging veroorzaken.

Maak een dossier *Gereed om toe te passen* zonder actieve offerteoverdracht, verander daarna
een carrier of CALC-bron en laat de live-snapshotcontrole blokkeren. Controleer
dat **Analyseer opnieuw** beschikbaar is, de analyse en handmatige verdelingen
opnieuw opbouwt en vervolgens een nieuw veilig voorstel maakt. Maak daarna een
actieve offerteoverdracht: **Analyseer opnieuw** moet dan niet beschikbaar
zijn totdat de overdracht veilig is teruggedraaid.

Controleer op die drie productieorderstatussen ook de actie **Frame
Specification** uit de afzonderlijke app. Deze moet het Frame Specification
rapport openen en mag het PIL-dossier niet wijzigen.

## 5. Generieke structurele driver — geen 7-hardcode

Maak onder één bestaande punt-carrier een echt structureel item
**X.STRUCT.01** met gekoppelde kindproductieorder of Production BOM en daaronder
**X.PART.01** en **X.PART.02**. Importeer die drie artikelen.

Na **Stap 1 - Analyseer PIL**:

- **X.STRUCT.01** is de structurele driver;
- de lagere artikelen zijn *Gedekt door structurele carrier*;
- slechts de bovenliggende driver bepaalt het carrieraantal;
- de target toont **Live Production Order** wanneer een kindproductieorder is
  gevonden;
- de lagere onderdelen worden niet ook als CALC-vervanging toegevoegd.

Herhaal met een artikel **7.01...**. Het resultaat moet hetzelfde zijn; alleen
het artikelnummer verschilt.

Herhaal met een Siemens-structuur, bijvoorbeeld met **.PN.AS.SI.FT.B** of
**.PN.AS.SI.FT.U**, een hoger **7.01.201...**-artikel en lagere
**4.01.453...**-leds. Controleer dat de hogere structurele driver leidend is,
ook wanneer de tekening andere lagere led-aantallen noemt. Er is geen
Siemens-tabel of vaste assemblyreceptinrichting nodig.

Test daarna expliciet gedeeltelijke capaciteit zonder vaste artikellogica:

- laat de basisdriver 1 carrier vragen en 22 stuks van **X.PART.RED** bevatten;
- laat de uitbreidingsdriver 2 carriers vragen en 24 stuks per carrier bevatten;
- importeer in totaal 80 stuks **X.PART.RED**;
- na analyse moet **Gedekt aantal = 70** zijn en moet alleen restant 10 open
  blijven;
- kies voor het restant het bestaande uitbreidingspuntartikel. De berekening
  moet `rest 10 / 24 => +1, totaal 3` tonen en automatisch carrieraantal 3
  voorstellen; `3,33333` is fout;
- staat die uitbreiding op de productieorder al op 3, dan is het voorgestelde
  verschil nul en mag Apply geen vierde carrier toevoegen;
- verhoog het PIL-totaal boven 70 + 24 en controleer dat steeds naar het juiste
  volgende hele carrieraantal wordt afgerond;
- kies in een herhaling **Als echt los materiaal toevoegen** en controleer dat
  uitsluitend het restant 10 wordt toegevoegd, niet het volledige PIL-totaal
  80.
- maak vóór de upgrade een concepttarget waarin voor die gedeeltelijk gedekte
  lagere regel nog 80 is verdeeld. Kies na installatie van 2.7.0.2 uitsluitend
  **Verdeling controleren**. De opgeslagen verdeling moet automatisch naar 10
  worden hersteld en het carriervoorstel moet van 6 naar 3 gaan, zonder dat de
  gebruiker de puntartikelkoppeling opnieuw hoeft te maken.

Zet daarna zowel de basis- als uitbreidingsassembly op Make-to-Order, zodat
beide als eigen productieregel bestaan. Laat Business Central op zo'n regel de
hoge **7.01.201...**-assembly en een gedeelde lagere **4.01.453...**-led plat
naast elkaar tonen. Analyse moet per carrier de hogere assembly kiezen, de led
als gedekt tonen en mag geen melding over tegenstrijdige gewenste aantallen
voor **.PN.AS.SI.FT.B** of **.PN.AS.SI.FT.U** geven. Verwijder de aantoonbare
BOM-relatie en herhaal: dan moet de conflictbeveiliging juist wel blijven
blokkeren.

Maak twee werkelijk onafhankelijke drivers onder dezelfde carrier met
strijdige gewenste carrierhoeveelheden, bijvoorbeeld driver A vraagt 2 en
driver B vraagt 3.

- **Analyseer PIL** moet beide minimumvoorwaarden tonen en automatisch het
  hoogste hele carrieraantal 3 kiezen; de eisen 2 en 3 mogen niet tot 5 worden
  opgeteld en mogen de analyse niet blokkeren.
- Controleer dat voorstel en Apply carrieraantal 3 gebruiken.
- Maak daarna één geaggregeerd AutoCAD-artikel dat aantoonbaar over twee
  werkelijk onafhankelijke carriers verdeeld kan worden. Alleen het niet reeds
  verklaarde restant mag dan handmatig in **Naar deze carrier** worden verdeeld;
  zonder volledige verdeling blijven Apply en offerteoverdracht geblokkeerd.

### 5.1 Alle puntartikelen en echte G.-carriers

Herhaal de directe CALC- of structurele test met een bestaande carrier die
niet met `.PN` begint, bijvoorbeeld een `.EA...`, `.PH...` of `.TO...`
productieartikel. De app moet die carrier net als een `.PN...` herkennen,
verhogen en in het wijzigingsvoorstel tonen.

Maak daarnaast een `G.`-artikel van type **Inventory**, aanvullingssysteem
**Prod. Order** en met een gecertificeerde Production BOM, zonder puntcarrier
in dezelfde gekoppelde keten. Als de live structuur een relevante PIL-driver of
CALC-placeholder bevat, moet dit artikel als carrier worden voorgesteld.

Herhaal die test met een gecertificeerde, datumgeldige Production BOM-versie
terwijl de header zelf niet gecertificeerd is. De geldige versie moet de
`G.`-carrier nog steeds toelaten; alleen een ontbrekende of niet-gecertificeerde
header én versie mag buiten de carrierselectie blijven.

Maak afzonderlijk een `G.`-uren- of materiaalgroep (Non-Inventory/Purchase of
zonder gecertificeerde Production BOM) met alleen `U.*`, `XE` of vergelijkbare
hulpartikelen. Deze groep mag nooit als carrier of wijzigingsvoorstelregel
verschijnen. Komt hij onder een puntcarrier voor, dan moeten de uren uitsluitend
via die bovenliggende carrier meeschalen.


## 6. Directe CALC-route: carrier eerst, echte artikelen daarna

Maak een Simulated productieorder met carrier **.PN.L5.7**, hoeveelheid 2,
zonder geïmporteerde structurele driver binnen die carrier. Plaats in de live
componentstructuur precies één **CALC-LED-5MM-ENKEL**-component met Expected
Quantity 2 én minstens één standaard afgeleid draad-, uur- of materiaalcomponent.

Importeer vier rode, vier oranje en vier gele leds. Na analyse controleer je:

- alle drie de regels volgen de CALC-route;
- één unieke carrier krijgt de automatische volledige verdeling;
- het nieuwe carrieraantal is 12;
- de carrier is vóór Apply nog niet gewijzigd;
- de drie targetregels met hetzelfde nieuwe carrieraantal leiden bij Apply
  slechts tot één carrierverhoging, niet driemaal.

Kies **Stap 2 - Controleer verdeling**, vervolgens **Stap 4 - Pas veilig toe**.
Controleer:

- **.PN.L5.7** is van 2 naar 12 verhoogd;
- afgeleide draad-/uur-/materiaalcomponenten zijn met de carrier meegeschaald;
- de oude CALC-component is verdwenen;
- de drie echte componentregels exact 4, 4 en 4 Expected Quantity hebben;
- een duidelijke succesmelding verschijnt;
- het PIL-dossier automatisch sluit;
- de gewijzigde productieorder na terugkeer of opnieuw openen zichtbaar is;
- het dossier via **PIL-afstemmingen** opnieuw alleen-lezen kan worden geopend
  en daar de status *Toegepast*, uitvoerder en tijdstempel toont.

Herhaal met dezelfde totale hoeveelheid maar een andere kleurenmix: carrier
blijft gelijk, alleen echte componentverdeling wijzigt. Herhaal met hoger
totaal: carrier en afgeleide content schalen precies één keer.

Maak daarnaast een carrier met zowel een structurele driver als een CALC-item
binnen **dezelfde** carrier. De structurele driver moet leidend zijn. Maak een
losse CALC-carrier naast een onafhankelijke structurele carrier met hetzelfde
geaggregeerde AutoCAD-artikel; de analyse moet blokkeren wegens ontbrekende
oudercontext.

## 7. Verdeling en bewuste uitzondering

### Verdeling

Maak twee geldige carriers met dezelfde actieve CALC-placeholder en importeer
één PIL-artikel met aantal 12.

- Bij meerdere kandidaten zijn beide targets zichtbaar met *Nog te verdelen*
  en is **Naar deze carrier** handmatig te vullen.
- Vul 4 en 8 in, kies **Stap 2 - Controleer verdeling** en controleer *Gereed om toe te passen*.
- Probeer 4 en 7, of 4 en 9: status blijft *Verdeling nodig* en toepassen blokkeert.
- Laat alles op nul: de onverdeelde hoeveelheid blijft zichtbaar en Apply
  blokkeert.
- Verander na *Gereed om toe te passen* een verdeling van 4/8 naar 5/7: status valt direct
  terug naar *Verdeling nodig*, voorstel/offerte/toepassen mogen pas na nieuwe
  controle verder.
- Bij één geldige carrier vult de app het volledige aantal automatisch; deze
  structurele automatische verdeling is niet handmatig te overschrijven.

### Gedeeld structureel artikel: drukknop en zoemer

Gebruik een productieorder met twee carriers die hetzelfde echte component
bevatten, maar die elk daarnaast hun eigen herkenbare componenten hebben. Het
concrete regressievoorbeeld is **.EA611100.1** met twee keer
**3.61.993.10.0** en **.EA31801NV** met één keer datzelfde artikel. De PIL
bevat dan **3.61.993.10.0** drie keer, naast de overige artikelen van de twee
drukknoppen.

- Kies **Stap 1 - Analyseer PIL**.
- Controleer in de verdeling dat de app automatisch 2 modules aan
  **.EA611100.1** en 1 aan **.EA31801NV** toekent.
- Controleer dat de carrier van de drukknoppen consistent op 2 blijft en geen
  foutmelding over tegenstrijdige gewenste aantallen geeft.
- Herhaal met twee nog onbekende mogelijke carriers voor een gedeeld artikel:
  de resterende hoeveelheid moet zichtbaar handmatig te verdelen blijven; de
  app mag niet gokken.

### Bestaand artikel met eenheid buiten STUKS

Plaats bijvoorbeeld **5.07.151.00.0** als echte productiecomponent met
eenheid **M2** en een geldige productieorderhoeveelheid. Neem hetzelfde artikel
met een willekeurig positief aantal op in de eenheidsloze AutoCAD-PIL.

- **Stap 1 - Analyseer PIL** mag niet blokkeren op de AutoCAD-hoeveelheid.
- De PIL-regel moet tonen: *Bestaand productiecomponent; productieorderhoeveelheid
  blijft leidend*.
- Controleer dat de M2-hoeveelheid in de productieorder onveranderd blijft en
  dat geen carrier of CALC-vervanging voor deze regel wordt voorgesteld.

### Informatieve G.-subconfiguratiekop

Neem **G.PD10.150S** of een gelijksoortig bestaand item op in de PIL dat
Non-Inventory, Purchase en zonder Production BOM is. Het artikel stelt alleen
een AutoCAD-subconfiguratie voor.

- **Stap 1 - Analyseer PIL** mag niet blokkeren.
- De PIL-regel moet tonen: *Informatieve subconfiguratie; geen
  productieorderwijziging*.
- Controleer dat geen target wordt aangemaakt en dat een echte `G.`-carrier
  mét Production BOM in dezelfde test nog wel normaal wordt geanalyseerd.

### Ongekoppeld STUKS-artikel verwerken

Importeer een bestaand STUKS-artikel dat nog niet op de productieorder staat
en geen PIL-groep heeft.

- **Stap 1 - Analyseer PIL** mag geen foutvenster geven; het dossier moet
  *Verdeling nodig* tonen met een duidelijke ongekoppelde regel.
- Kies **Als los component toevoegen**, kies een productieregel en controleer
  dat de regel als *Wordt als los productiecomponent toegevoegd* wordt
  vastgelegd. Na toepassen moet het artikel exact met het PIL-aantal als echte
  component op die regel staan.
- Kies in een tweede run **Onder puntartikel toevoegen**. De lookup mag alleen
  bestaande puntartikelen tonen waarvan de actieve Production BOM dit artikel
  bevat. Kies er één en controleer na toepassen de component onder die
  productieregel.
- Een artikel met eigen Production BOM mag niet als kaal los component worden
  toegevoegd; de melding moet uitleggen dat hiervoor een echte
  productiecarrier/onderliggende productiestroom nodig is.

### Bewust negeren

Importeer een positief artikel dat geen actieve PIL-groep heeft, geen
structurele driver/gedekt onderdeel wordt en werkelijk niet bij de order hoort.

1. **Stap 1 - Analyseer PIL** moet blokkeren met een duidelijke niet-opgeloste
   positieve regel.
2. Open **Geïmporteerde AutoCAD-PIL** en kies **Bewust negeren**.
3. Sluit het redenvenster leeg: de actie moet blokkeren.
4. Leg een duidelijke reden vast. Controleer beslissing, reden, gebruiker en
   tijdstip.
5. Kies opnieuw **Analyseer PIL** en daarna **Controleer verdeling**:
   de regel mag niet worden verwerkt, maar het overige voorstel kan verder.
6. Kies **Negeren herstellen**: de regel wordt weer blokkerend en moet opnieuw
   worden gekoppeld of gemotiveerd genegeerd.

Maak ook een dossier waarin alle positieve regels bewust zijn genegeerd.
Controleer dat dit naar *Gereed om toe te passen* kan gaan, dat **Pas veilig toe** nadrukkelijk
meldt dat de productieorder niet wordt gewijzigd, dat geen Sales Quote-actie
beschikbaar is en dat toepassen uitsluitend een auditdossier met status *Toegepast* vastlegt.

Probeer hetzelfde met een al gemapt of al opgelost artikel. **Bewust negeren**
moet niet beschikbaar zijn of veilig blokkeren. De uitzondering is nooit de
normale oplossing voor een te corrigeren mapping.

## 8. Master-BOM-terugval, UOM en live snapshot

Maak een ongekoppelde punt-carrier met een actieve, gecertificeerde,
datumgeldige Production BOM die een structurele driver bevat. Controleer na
analyse **Current Master BOM**, en na Apply dat uitsluitend de huidige
productiecomponent schaalt; Production BOM Header/Line blijven exact
ongewijzigd en er ontstaat geen fictieve kindproductieorder.

Maak een productieorderregel met twee datumgeldige BOM-versies en vul
**Production BOM Version Code** op de orderregel. Analyse moet die opgeslagen
versie gebruiken.

Maak voor een live carrier/component een **Stockkeeping Unit** met dezelfde
locatie en variant als de productieorder, maar met een andere gecertificeerde
Production BOM dan op de Itemkaart. Zet het PIL-artikel alleen in de SKU-BOM.
Puntartikel zoeken, structurele analyse, snapshotcontrole en routinguren moeten
de SKU-BOM gebruiken. Verwijder de SKU-BOM en controleer dat dezelfde acties
weer aantoonbaar op de Item-BOM terugvallen; er mag geen resultaat uit een
eerdere actiecache blijven hangen.

Verwacht vóór productieorderwijziging een blokkade bij ieder van deze gevallen:

- geen passende/certificeerde datumgeldige BOM-versie;
- BOM-cirkel, routing link, scrap of calculation formula;
- UOM anders dan STUKS of benodigde UOM-omrekening;
- carrier, variant, UOM, hoeveelheid of SystemId gewijzigd na Prepare;
- CALC-bron ontbreekt, bestaat meermaals of is gewijzigd;
- echte PIL-component staat al naast de te vervangen CALC-component;
- driver of target is sinds Prepare veranderd.

Controleer in elk negatief geval dat geen productiecomponent, carrier of
routing gedeeltelijk is gewijzigd.

Maak daarnaast een productieorder met een geldige **STUKS**-carrier en een
afzonderlijke `G.`-subconfiguratie in **METER**, zonder positieve PIL-driver
of passende CALC-placeholder in die meter-tak. Analyse, verdelingscontrole en
de Apply-voorcontrole van de STUKS-route moeten slagen; de meter-tak verschijnt
niet als target of voorstel. Voeg daarna een positieve structural driver of
passende CALC-placeholder aan die meter-tak toe: de analyse moet dan juist met
de duidelijke UOM-blokkade stoppen.

## 9. Live veiligheidsgrenzen en rollback

Prepare een voorstel en voer vervolgens één voor één uit:

- boek verbruik op een betrokken component;
- reserveer carrier of component;
- maak een warehouse pick;
- vul Finished Quantity op een betrokken productieorderregel;
- maak een open productiejournaalregel;
- start of voltooi een betrokken routingregel;
- boek routingoutput, scrap, setup, runtime of capaciteit;
- verander gekoppelde parent-/child-demand zodat hij niet meer exact klopt.

**Stap 4 - Pas veilig toe** moet telkens blokkeren. Herstel de testdata en
controleer dat een fout later in de standaardvalidatie alle eerdere wijzigingen
uit dezelfde Apply terugdraait. Een applied dossier is daarna niet opnieuw te
preparen of toe te passen.

## 10. Routingherberekening en Bluace-grens

Gebruik een veilige, nog niet gestarte hoofdroute met minimaal één actieve
routestap met positieve Run Time en één optionele routestap met Run Time 0.
Leg per Routing Link Code de Run Time, eenheid, Input Quantity, Expected
Capacity Need/Cost en planning vast vóór Apply.

1. Voeg via de PIL onder een gekozen subconfiguratie een puntartikel toe met
   Non-Inventory-uurcomponenten op de actieve Routing Link Code. Leg het live
   U.-totaal vóór en na Apply vast. Bereken iedere bijdrage als `Quantity per ×
   aantal van de eigen productieregel ÷ aantal van het routing-hoofdartikel`.
   Dit moet gelijk zijn aan **Qty. per Top Item**: bij 0,256 uur onder een
   onderdeel dat tienmaal voorkomt is de bijdrage 2,56 uur, niet 0,256. De
   nieuwe Run Time moet exact `oude Run Time + (live na - live vóór)` zijn.
   Bestaande route-uren die niet als live component zijn uitgevouwen blijven
   behouden.
2. Verhoog daarna alleen het productieaantal van een route-eigenaar waarvan de
   uurcomponenten volledig evenredig meegroeien. De Run Time per eenheid mag
   niet nogmaals stijgen; Input Quantity en capaciteitsbehoefte moeten wel via
   de standaard BC-planning meegroeien.
3. Laat een nieuw/gewijzigd uurcomponent naar de optionele Routing Link Code
   met Run Time 0 wijzen. Die routestap moet nul blijven.
4. Verwijder in een aparte wegwerptest de benodigde live routingregel volledig.
   Apply moet vóór commit blokkeren met de ontbrekende Routing Link Code en
   alle carrier-/component-/routingwijzigingen terugdraaien.
5. Verlaag een carrier veilig en controleer dat het negatieve live verschil van
   de actieve route wordt afgetrokken. Een echte verwijdering moet dus uren
   verlagen, maar verborgen/ongewijzigde uren mogen niet verdwijnen en de Run
   Time mag nooit negatief worden.
6. Test afzonderlijk een Routing Link Code die vóór Apply niet in de
   uurcomponententelling voorkomt maar erna wel, en daarna de omgekeerde
   situatie. De ontbrekende zijde moet als nul tellen; de technische melding
   *The given key was not present in the dictionary* mag niet optreden en het
   juiste positieve of negatieve mutatie moet correct worden toegepast.
7. Gebruik een productieorder waarop alleen het hoofdartikel een live routing
   heeft. Kies een werkgebied/subconfiguratie zonder eigen routing als doel en
   voeg daar via de PIL een puntartikel met U.-componenten en Routing Link
   Codes toe. Controleer dat het aantoonbare verschil op de routing van het
   hoofdartikel terechtkomt, ook zonder geldige supplied-by-keten van het werkgebied naar
   de hoofdregel. Voeg in een aparte test een tweede live routing-eigenaar toe:
   een niet-gekoppelde tak mag dan niet stilzwijgend aan één van beide routings
   worden toegewezen.
8. Gebruik daarna een productieorder waarop het hoofdartikel én een gekozen
   werkgebied/subconfiguratie ieder een live routing hebben. Voeg het
   puntartikel onder die subconfiguratie toe. Maak vóór en na Apply per Routing
   Link Code een som vóór en na van alle geschikte U.-componenten op **alle**
   productieregels. Controleer dat precies het orderbrede verschil op de
   Run Time van het productieorder-hoofdartikel wordt verwerkt, dat uren uit andere
   werkgebieden meetellen en dat de geneste routing niet vanwege de
   materiaalbestemming wordt verhoogd.

Controleer daarna dat **CalculateRoutingFromActual** Input Quantity,
capaciteitsbehoefte, kosten en planning bijwerkt. Controleer tevens dat de
bekende Bluace-masterroutingtool niet als dependency of extra PIL-stap wordt
aangeroepen en dat IWX-configuratie, Bluace-objecten en Item Routing-masterdata
ongewijzigd blijven. Herhaal met een route die al activiteit bevat: PIL Apply
moet blokkeren in plaats van routing stilzwijgend te overschrijven.

### Losse actie na handmatige wijzigingen

1. Maak een verse Simulated Production Order en noteer per actieve Routing Link
   Code de volledige som van alle geschikte U.-componenten op alle
   productieregels.
2. Voeg of wijzig daarna handmatig een productiecomponent met Routing Link Code
   zonder een PIL te importeren.
3. Kies onder **Functions** **Routinguren opnieuw berekenen** en controleer de
   preview met per Routing Link Code op een eigen regel het oude totaal, het
   volledige nieuwe totaal en het verschil. De tekst mag geen letterlijke `\`
   als regelscheiding tonen.
   Bevestig daarna dat alleen actieve gekoppelde routetijden worden
   overschreven.
4. Controleer dat de actieve hoofdroute exact het volledige actuele
   U.-urentotaal krijgt, de geneste routings niet worden gekozen en een
   nul-tijdroute nul blijft. De preview moet bij zo'n nul-tijdroute wel het
   berekende U.-totaal en de tekst *blijft uit* tonen.
5. Herhaal op Firm Planned en een nog niet gestarte Released order. Herhaal
   daarna met een gestarte/geboekte hoofdroute en met twee zelfstandige
   bovenste routing-eigenaren: de actie moet veilig blokkeren zonder gedeeltelijke
   wijziging.
6. Maak afzonderlijk een ontbrekende en een dubbele live routingregel voor een
   gebruikte Routing Link Code. De controle moet vóór de bevestiging gericht
   blokkeren en geen routingtijd of planning wijzigen.
7. Laat alleen een niet-gerelateerde materiaalcomponent gereserveerd zijn. De
   handmatige routingactie mag daardoor niet blokkeren, omdat zij geen
   component wijzigt. Een open productiejournaalregel, gestarte routing of
   geboekte routingactiviteit moet wel blokkeren.
8. Gebruik een vers vernieuwde order waarop bijvoorbeeld `G.SLK.PD10.90I` als
   component voorkomt, niet als productieregel, en zijn eigen gecertificeerde
   Production BOM geneste U.-regels met Routing Link Code bevat. De losse actie
   moet die BOM read-only meenemen en de geneste uren met het actuele aantal per
   hoofdartikel vermenigvuldigen. Er mag geen melding volgen dat de component
   eerst moet worden uitgevouwen. Herhaal met een BOM-cirkel, ongeldige versie,
   afval en **Vast aantal**: dan moet de actie vóór iedere wijziging gericht
   blokkeren.
9. Vergelijk voor minimaal U.ASS, U.COD en één geneste uurregel de velden in
   **BOM Cost Shares**: gebruik **Qty. per Top Item** als referentie. Een test die
   alleen **Qty. per Parent** of alleen component **Expected Quantity** optelt,
   moet bewust falen.

## 11. Wijzigingsvoorstel, offerte en terugdraaien

Maak een dossier *Gereed om toe te passen* met minimaal één positieve, één
negatieve en één nul **Quantity Difference**. Kies **Stap 3 - Bekijk
wijzigingsvoorstel** en controleer per technische carrier oud/nieuw aantal,
verschil, PIL-details en technische kostenindicatie. De kostenindicatie is geen
verkoopprijs.

Maak daarnaast deze expliciete commerciële groepen; gebruik steeds hetzelfde
artikel, dezelfde variant en dezelfde eenheid binnen één groep:

| Groep | Technische regels | Verwacht commercieel resultaat |
|---|---|---|
| A | positie 1: 2 → 4; positie 2: 3 → 2 | som oud 5, som nieuw 6, precies één offerteregel `+1` |
| B | positie 1: 4 → 1; positie 2: 1 → 2 | som oud 5, som nieuw 3, precies één offerteregel `-2` |
| C | positie 1: 1 → 2; positie 2: 2 → 1 | som oud = som nieuw, geen offerteregel |

Herhaal groep A met een andere variant en daarna met een andere eenheid. Die
moeten afzonderlijke commerciële regels blijven; de app mag uitsluitend op
artikel + variant + eenheid samenvoegen.

Maak een bestaande Sales Quote met status Open, Quote Accepted = nee en een
niet-verlopen Quote Valid Until Date. Voeg vooraf gewone en configuratorregels
toe. Richt voor ten minste één meerwerkartikel en één minderwerkartikel een
standaard artikeltekst in die voor **Sales Quote** geldt. Gebruik een lange
tekst die over meer dan één verkoopregel moet worden verdeeld en, waar
mogelijk, een taal- of datumafhankelijke tweede versie. Zet op deze artikelen
**Automatic Ext. Texts** aan. Richt daarnaast één artikel met geldige Sales
Quote-tekst maar **Automatic Ext. Texts** uit in.

1. Kies vanuit *Gereed om toe te passen* **Meer- en minderwerk naar bestaande
   offerte**. De app moet eerst aanraden **Pas veilig toe** uit te voeren en
   waarschuwen dat verwijderen of omzetten van de offerte vóór Apply de
   controle blokkeert. Kies **Nee**; er mag niets zijn toegevoegd.
2. Kies **Pas veilig toe** en start daarna de offerteoverdracht opnieuw. De
   workflowwaarschuwing verschijnt nu niet.
3. Controleer dat de bevestiging aantallen **samengevoegde** meerwerk- en
   minderwerkregels toont, niet het aantal onderliggende technische regels.
4. Controleer groep A, B en C tegen bovenstaande tabel. De offertehoeveelheid is
   altijd `som definitief - som oorspronkelijk`, nooit het volledige definitieve
   aantal en nooit iedere technische wijziging apart.
5. Controleer dat de positieve en negatieve nettoresultaten als nieuwe gewone
   Item-regels worden toegevoegd met juist item, variant, UOM en teken van de
   hoeveelheid. Netto nul maakt geen regel.
6. Controleer direct onder iedere aangemaakte Item-regel de standaard
   artikeltekst. Meerwerk begint bijvoorbeeld met `1x`; minderwerk begint met
   **Minderwerk** en het absolute aantal. De tekstregels hebben **Attached to
   Line No.** van de juiste Item-regel, gebruiken de offerte-documentdatum en
   taal en zijn zonder stil afkappen over meerdere regels verdeeld. Een lege
   brontekstregel blijft als lege alinea behouden. Een artikel zonder
   toepasselijke automatische artikeltekst maakt wel gewoon zijn Item-regel;
   het artikel met **Automatic Ext. Texts** uit krijgt bewust geen tekst.
7. Controleer dat alle technische change lines die aan dezelfde nettoregel
   bijdragen dezelfde offerte, hetzelfde regelnummer, dezelfde SystemId en
   dezelfde SystemModifiedAt bewaren.
8. Controleer dat bestaande gewone en configuratorregels ongewijzigd zijn. De
   PIL-overdracht mag geen IWX-configuratie openen, geen volledige
   configuratietekst genereren en geen Assemble-to-Order-nevenactie starten.
9. Controleer dat Unit Price en Line Amount uit de standaard BC-prijsberekening
   komen, niet uit IWX. Beoordeel bij minderwerk expliciet het negatieve aantal,
   de prijs, korting, btw en het uiteindelijke negatieve bedrag.
10. Controleer in change lines en rapport offerte-, regel-, prijs-, bedrag-,
   valuta-, gebruiker- en tijdstempelaudit. Een netto-nulgroep meldt dat de
   technische regels commercieel tegen elkaar wegvallen.
11. Probeer na overdracht de verdeling of analyse te wijzigen: dit moet blokkeren
    zolang de overdracht actief is.
12. Wijzig of verwijder de gedeelde gekoppelde Item-regel of één van zijn
    gekoppelde tekstregels. Voeg ook een onverwachte extra gekoppelde tekstregel
    toe. De rapportage toont in alle gevallen commerciële review en een tweede
    overdracht mag niets automatisch herstellen of dupliceren. Automatisch
    terugdraaien moet blokkeren zodra artikel of tekst afwijkt.
13. Wijzig na overdracht de onderliggende standaard artikeltekst of de
    documentdatum/taal zodat een andere tekst geldig wordt. De bestaande
    overdracht moet beoordelingsplichtig worden; de app mag de offertetekst niet
    stil herschrijven.
14. Maak hiervoor een afzonderlijk *Gereed om toe te passen*-dossier, bevestig
    bewust de waarschuwing en draag vóór Apply over. Wijzig daarna uitsluitend
    een gekoppelde tekstregel of de Extended Text-stam. Technische Apply moet
    doorgaan zolang de gekoppelde Item-regel en technische snapshot exact
    gelijk zijn; automatisch terugdraaien blijft geblokkeerd. Verwijder op een
    nieuwe fixture de actieve koppeling van slechts één bijdragende bronregel:
    Apply moet dan wél blokkeren; alle bronregels van een
    niet-nul nettogroep moeten naar dezelfde actuele offertregel blijven wijzen.
15. Maak van de offerte via de normale Sandbox-verkoopstroom een order en
    factuur. Controleer dat de gekoppelde tekstregels meegaan en dat de gekozen
    offerte-/order-/factuurlay-outs ze zichtbaar afdrukken. Dit is een
    layoutacceptatietest; de PIL-app past geen rapportlay-out aan.
16. Maak nog een *Gereed om toe te passen*-dossier, draag vóór Apply over en zet
    de offerte daarna bewust om naar een order. Apply moet veilig blokkeren omdat
    de gekoppelde offerte-itemregel niet meer bestaat. Dit bevestigt waarom de
    gebruikersmelding standaard Apply vóór offerteoverdracht adviseert.
17. Herhaal handoff en terugdraaien met een gebruiker die wel normale
    offerterechten heeft maar geen afzonderlijke Extended Text-leesrol. De
    codeunit moet de benodigde Item/Extended Text-stamdata indirect kunnen lezen;
    er mag geen ruwe tabel-permissionfout ontstaan.
18. Maak nog een *Gereed om toe te passen*-dossier, bevestig bewust overdracht
    vóór Apply en wijzig alleen de verkoopprijs van de aangemaakte Item-regel.
    Apply en automatisch terugdraaien moeten blokkeren en de app mag de prijs
    niet herstellen. Herhaal de aanbevolen volgorde: eerst Apply, daarna
    overdracht en prijscontrole; dan is commerciële prijsaanpassing veilig.

Negatieve keuzes en afwijzingen:

- annuleer de keuze;
- Quote Accepted = ja;
- status niet Open;
- verlopen Quote Valid Until Date;
- dossier waarin alle commerciële groepen netto nul zijn;
- dossier *Geïmporteerd* of *Verdeling nodig*.

In alle gevallen mogen geen nieuwe offertregels of productieorderwijzigingen
ontstaan.

### Verplicht terugdraaien met audit

Voer deze test vóór technische Apply uit op een actieve, ongewijzigde
offerteoverdracht:

1. Kies **Offerteoverdracht terugdraaien** en sluit het redenvenster zonder
   reden. Dit moet blokkeren.
2. Geef een duidelijke reden op en bevestig.
3. Controleer dat uitsluitend de door dit dossier gemaakte, nog ongewijzigde
   offertregel(s) en hun gekoppelde tekstregels zijn verwijderd. Een gedeelde
   offertregel wordt precies één keer verwijderd, ook wanneer meerdere
   technische change lines ernaar wijzen. Onverwante bestaande tekstregels
   blijven staan.
4. Controleer dat elke bijdragende change line **Quote Reversed** is en verwijst
   naar een
   onveranderbare **PNE PIL Quote Reversal** (50198) met oude offertedata,
   reden, gebruiker en tijdstip.
5. Kies opnieuw **Stap 3 - Bekijk wijzigingsvoorstel** en controleer dat de
   terugdraai-audit en commerciële vervolgactie zichtbaar zijn.
6. Verander, verwijder, accepteer of laat de gekoppelde offerte verlopen vóór
   terugdraaien. De terugdraaiing moet stoppen; de app mag de offerteregel niet
   geforceerd verwijderen.
   - Wijzig alleen een niet-prijsveld zoals locatie, dimensie of verzenddatum.
     De gewijzigde systeemdatum moet de terugdraaiing blokkeren.
   - Verwijder de regel en maak een inhoudelijk identieke regel opnieuw aan op
     hetzelfde regelnummer. De afwijkende SystemId moet de terugdraaiing
     blokkeren.
7. Pas daarna de PIL veilig toe. Controleer dat de actie
   **Offerteoverdracht terugdraaien** niet meer beschikbaar is; correctie is
   dan handmatig commercieel werk.

### Duurzame vrijgave na handmatige commerciële controle

Voer deze test uit met een technisch voorbereid dossier en een actieve
offerteoverdracht:

1. Wijzig of verwijder de gekoppelde offertregel, zet de offerte om naar een
   order of test met een gebruiker zonder Sales Line-leesrecht. **Pas veilig
   toe** moet de technische wijziging eerst blokkeren zolang de commerciële
   koppeling actief is.
2. Kies **Commerciële koppeling vrijgeven** en sluit het redenvenster leeg. Dit
   moet blokkeren en mag geen auditregel maken.
3. Laat verkoop de offerte of het vervolgdocument handmatig controleren. Kies
   opnieuw de vrijgaveactie en leg een concrete reden vast, inclusief het
   vervolgdocument wanneer dat bestaat.
4. Controleer dat geen Sales Header, Sales Line, verkooporder, factuur of
   tekstregel is gewijzigd of verwijderd.
5. Controleer per change line **Quote Link Released** en de verwijzing naar de
   onveranderbare **PNE PIL Quote Resolution** (50199). De audit bevat de
   oorspronkelijke offerte-/regel-, artikel-, aantal-, tekst- en prijsgegevens,
   de waargenomen toestand, reden, gebruiker en tijd.
6. Open **Stap 3 - Bekijk wijzigingsvoorstel**. Het afzonderlijke blok **Audit
   handmatig vrijgegeven commerciële koppelingen** moet alle waarden leesbaar
   tonen en de commerciële status mag niet meer als actuele koppeling tellen.
7. Controleer dat **Meer- en minderwerk naar bestaande offerte**, herverdelen en
   heranalyseren geblokkeerd blijven. Dezelfde wijziging mag niet opnieuw
   automatisch worden overgedragen.
8. Kies **Pas veilig toe**. Dit mag alleen slagen wanneer de volledige
   technische productieordersnapshot nog actueel en veilig is. Wijzig daarom
   in een afzonderlijke negatieve test eerst een carrier of BOM: Apply moet
   ondanks commerciële vrijgave veilig blokkeren.
9. Herhaal op een reeds toegepast dossier. De commerciële audit mag worden
   toegevoegd, maar de productieorder mag niet opnieuw worden gewijzigd.
10. Upgrade een Sandbox met bestaande Imported, Prepared, Applied en Reversed
    dossiers. De nieuwe velden moeten standaard `false`/`0` zijn en bestaande
    status, quote- en reversalgegevens moeten intact blijven.

## 12. Rapport, audit en regressiegrens

Open het Word-rapport met:

- dossier met de statussen *Geïmporteerd*, *Verdeling nodig*, *Gereed om toe te passen* en *Toegepast*;
- een structurele route, een CALC-route en een bewust genegeerde regel;
- een actieve offerteoverdracht, gewijzigde offerteregel, ontbrekend
  Sales-Line-leesrecht en teruggedraaide overdracht.

Controleer dat technische inhoud bruikbaar blijft en dat de commerciële status
respectievelijk actuele koppeling, review nodig, niet te verifiëren of
teruggedraaid meldt. Het rapport mag nooit een productieorder, offerte of
auditrecord wijzigen.

Controleer tevens dat het rapport het gekozen carrieraantal met reden,
gebruiker en tijdstip toont en dat productienummer, productieorderregel en
eventuele componentregel de bestemming eenduidig maken. De ruwe en
geaggregeerde AutoCAD-tabellen mogen niet als losse rapportsecties verschijnen.
Een bewust genegeerde regel toont wel reden, gebruiker en tijdstip.

Voer vóór en na de Sandbox-test de bestaande IWX-regressie uit:

- representative IWX Business Rules;
- een configurator/quoting-item;
- de normale Product Configurator Enhancements-smoketest;
- de bestaande Bluace-routingstroom buiten de PIL-app.

Verwacht: IWX Business Rules, configurator-BOM-data, partnermasterrouting en
hun eventafhandeling blijven ongewijzigd. De PIL-app voegt alleen haar eigen
auditdata, kaartacties en gecontroleerde standaard
productieorderwijzigingen toe.

## 13. Bewijs vastleggen

### Prestatieregressie: zoeken, analyseren en toepassen

1. Gebruik een gesimuleerde productieorder met ten minste 80 actuele
   componentregels, 8 puntartikelen en 15 positieve, nog open PIL-regels. Noteer
   per actie de begintijd, eindtijd en duur; vergelijk dezelfde Sandbox en
   dezelfde gegevens met de vorige appversie.
   Herhaal import/analyse daarnaast met representatieve bestanden van circa 500
   en 2.000 bronregels. Leg de tijden vast; iedere actie moet eindigen met een
   normale uitkomst of concrete blokkade, nooit een sessietime-out. Een
   duidelijke verslechtering ten opzichte van 2.7.0.8 is een release blocker.
2. Open **Puntartikel verhogen** voor `8.02.160.50.0`. De lookup moet
   `.TO.P.SI.FP2015` vinden via de geldige geneste Production BOM. De actie mag
   niet minutenlang alle niet-puntartikelen blijven doorzoeken.
   Controleer in dit voorbeeld expliciet dat de regel in de BOM van
   `.TO.P.SI.FP2015` het standaard type **Production BOM** heeft. Herhaal met
   een vergelijkbare directe standaard **Item**-regel; beide routes moeten het
   juiste puntartikel tonen zonder artikelnummerafhankelijke inrichting.
   Maak daarna achtereenvolgens de bovenliggende BOM niet-gecertificeerd, de
   regel ongeldig voor alle productieregeldatums en het puntartikel ongeschikt
   via een andere basiseenheid. De zoekactie moet niet alleen leeg blijven,
   maar de concrete kandidaat en afwijzingsreden noemen. Herstel de inrichting,
   heropen de PIL en controleer dat het puntartikel direct weer verschijnt.
   Gebruik daarnaast een productieorder met minimaal twee productieregels met
   verschillende start-/uiterste datums en een puntartikel waarvan de
   gecertificeerde BOM-versie alleen op de datum van het beoogde werkgebied
   geldig is. Het puntartikel moet zichtbaar blijven. Kies vervolgens bewust
   een bestemmingsregel waarvoor die BOM-versie niet geldig is: de definitieve
   controle moet die ongeldige combinatie nog steeds blokkeren.
3. Kies één puntartikel waarvan meerdere open PIL-artikelen in de BOM staan.
   Controleer dat de werkelijk passende regels automatisch meekoppelen en
   niet-passende regels open blijven. Controleer dat aantallen en
   bestemmingsregel gelijk zijn aan de functionele scenario's verderop in dit
   plan. Gebruik daarbij minimaal drie passende PIL-regels op verschillende
   BOM-niveaus: iedere regel moet de aantalsfactor uit dezelfde geldige BOM
   krijgen en mag niet dubbel worden geteld.
4. Kies **Analyseer PIL** op dezelfde order. Vergelijk targets, gedekte
   aantallen en conflicten met een bewaarde run van de vorige versie; alleen de
   doorlooptijd mag verschillen. Neem een live structuur met meerdere sibling-
   componenten waarvan de BOM dezelfde lagere PIL-driver bevat; de hoogste
   geldige driver en de gedekte aantallen moeten identiek blijven.
5. Pas een voorstel toe dat één nieuw puntartikel toevoegt. Controleer dat
   Business Central de nieuwe productieregel, componenten, routing en datums
   correct berekent en dat de nieuwe onderboom niet nogmaals een volledige
   planronde doorloopt. Een structurele aantalswijziging op een bestaande
   carrier moet daarentegen nog steeds alle werkelijk geraakte kindregels
   herberekenen. Voeg daarnaast twee targets toe die een deel van dezelfde
   parent-/child-keten raken; alle veiligheidsblokkades moeten gelijk blijven en
   ieder live record hoeft binnen de actie maar eenmaal volledig te worden
   gecontroleerd.
6. Herhaal lookup en analyse nadat een BOM-versie of productieordercomponent is
   gewijzigd. De nieuwe situatie moet direct zichtbaar zijn; er mag geen cache
   uit een eerdere actie worden hergebruikt. Gebruik ook twee actuele
   componentregels met hetzelfde niet-uitgevouwen subartikel/BOM en een
   Routing Link Code. De routingurentelling moet exact dezelfde som als vóór de
   optimalisatie geven, inclusief beide actuele aantallen; de onderliggende BOM
   wordt alleen binnen die ene snapshot hergebruikt.
   Maak ook een kandidaat die de snelle omgekeerde BOM-index niet oplevert maar
   waarvan de actuele gecertificeerde puntartikel-BOM het PIL-artikel wel
   aantoonbaar bevat. Wanneer de snelle zoekroute geen enkel resultaat heeft,
   moet de gezaghebbende fallback dit puntartikel vinden; ongeldige of niet-
   gecertificeerde kandidaten blijven uitgesloten.
7. Noteer afzonderlijk de duur van de standaard actie **Productieorder
   vernieuwen**. Die actie hoort niet bij deze PNE-optimalisatie en mag niet als
   resultaat van **Puntartikel verhogen**, **Analyseer PIL** of **Pas veilig
   toe** worden gerapporteerd.

### Nieuw puntartikel dat nog niet op de order staat

1. Gebruik een positieve, ongekoppelde PIL-regel waarvoor een bestaand
   productiepuntartikel bestaat, maar zet dat puntartikel nog niet op de
   productieorder.
2. Kies **Puntartikel verhogen**. De zoeklijst moet het puntartikel vinden op
   basis van zijn gecertificeerde Production BOM.
3. Controleer dat het voorstel `0 -> n` voor het puntartikel toont en niet een
   kaal los AutoCAD-component.
4. Pas toe. Controleer dat Business Central het puntartikel als component én
   gekoppelde onderliggende productieregel heeft aangemaakt en dat de volledige
   BOM, inclusief U.-uren en bedrading, aanwezig is.
5. Herhaal met twee PIL-artikelen uit hetzelfde puntartikel. Gelijke berekende
   puntartikelaantallen mogen één toevoeging opleveren; tegenstrijdige aantallen
   moeten vóór Apply blokkeren.
6. Herhaal met een order met meer dan één echte hoofdregel. Automatische
   plaatsing moet blokkeren met een duidelijke planningmelding; er mag niets
   half zijn toegevoegd.
7. Zorg daarnaast voor een ander puntartikel met een ontbrekende of niet voor
   de orderdatum gecertificeerde Production BOM, bijvoorbeeld `A10428`. De
   lookup moet die kandidaat overslaan en de overige geldige puntartikelen
   blijven tonen; de zoekactie zelf mag niet blokkeren.
8. Kies voor één open PIL-regel **Puntartikel verhogen**. Laat dezelfde
   puntartikel-BOM via meerdere geneste Item- en Production-BOM-niveaus nog
   andere open PIL-artikelen bevatten. Regels die hetzelfde benodigde
   puntartikelaantal bevestigen moeten automatisch meekoppelen en uit de
   actielijst verdwijnen.
9. Laat één ander bladartikel in dezelfde BOM een afwijkend puntartikelaantal
   opleveren. Die regel moet open blijven voor een aparte beslissing; de
   expliciet gekozen regel en de overige eenduidige regels mogen niet worden
   teruggedraaid.
10. Gebruik een bladartikel dat al als productiecomponent op de order staat,
    maar dat bewust via een gekozen puntartikel moet worden gedekt. Na de
    koppeling moet de expliciete puntartikelbeslissing zichtbaar blijven. Als
    bij alle verdeelregels **Nog te verdelen = 0** staat, moet **Verdeling
    controleren** de status Gereed/Prepared geven en niet opnieuw om verdeling
    vragen.
11. Meet de lookup met een representatieve artikelstam. Leg de verstreken tijd
    vóór en na 2.5.0.2 vast. Een ongeldige kandidaat zoals `A10428` mag niet
    worden geopend of de overige resultaten blokkeren.
12. Selecteer meerdere ongekoppelde STUKS-artikelen zonder Production BOM en
    kies de normale actie **Als echt los materiaal toevoegen**. Kies één
    productieregel. Controleer dat ieder geselecteerd artikel een afzonderlijk
    direct-componentdoel krijgt, alle afgehandelde regels uit de actielijst
    verdwijnen en de verdeling na één controle gereed is. Er mag geen aparte
    bulkactie nodig of zichtbaar zijn.
13. Neem in dezelfde selectie één ongeschikt artikel op, bijvoorbeeld een
    artikel met Production BOM, verkeerde eenheid of een al bestaande directe
    component op de gekozen regel. De bulkactie moet duidelijk blokkeren en
    geen van de andere geselecteerde regels gedeeltelijk bewaren.
14. Gebruik een PIL-artikel dat niet als Item-regel maar als geneste
    **Production BOM** onder een puntartikel staat. Referentie:
    `8.02.160.50.0` onder `.TO.P.SI.FP2015`. **Puntartikel verhogen** moet het
    puntartikel tonen en na selectie de volledige BOM-route gebruiken. Herhaal
    dit met een ander nummer volgens hetzelfde patroon om te bewijzen dat de
    lookup niet op artikelcodes is hardcoded. Voeg vervolgens in de stam-BOM
    óók een echte **Item**-regel met hetzelfde nummer toe, zoals de gewenste
    definitieve inrichting. Analyseer een nieuwe/refreshed productieorder en
    controleer dat de Item-regel precies één keer leidend is; de gelijknamige
    Production BOM-kop mag het aantal niet verdubbelen of een carrierconflict
    veroorzaken en de onderliggende BOM-inhoud mag slechts één keer worden
    doorlopen. Importeer na Apply dezelfde PIL opnieuw. De gekoppelde
    puntartikelregel moet via zijn opgeslagen BOM/versie automatisch als reeds
    gedekt worden herkend en mag niet opnieuw bij *Nog te verdelen* verschijnen.
    Hiervoor mag geen nieuwe handmatige actie of bestemmingskeuze nodig zijn.
    Het bestaande puntartikel moet met het huidige aantal als carrier worden
    gebruikt, de voorgestelde wijziging moet nul zijn en **Controleer
    verdeling** moet de status Gereed/Prepared geven.
15. Herhaal de vorige herimport met twee werkelijk bestaande puntartikelposities
    die beide dezelfde open PIL-regel bevatten. De app mag niet willekeurig één
    positie kiezen. Koppel de regel handmatig en controleer dat een uniek reeds
    bestaand puntartikel geen bestemmingsvraag toont, omdat zijn huidige positie
    al vaststaat.
16. Laat daarna bewust één regel onverdeeld en kies **Controleer verdeling**.
    De melding moet het artikelnummer en nodig/verdeeld/resterend aantal noemen.
    Maak vervolgens een echt carrierconflict met volledig verdeelde regels; de
    melding moet nu de carrier noemen en naar **Kies carrieraantal** verwijzen.
17. Bereid een order voor met een direct structureel bladartikel zonder eigen
    toeleverende productieregel, bijvoorbeeld `8.02.128.00.0` onder
    `.TO.P.SI.FT2001`. Kies **Veilig doorvoeren** zonder de productieorder
    tussentijds te wijzigen. De actuele verhouding moet gelijk blijven en de
    app mag niet melden dat het structurele artikel is gewijzigd. Wijzig daarna
    bewust het componentaantal en controleer dat dezelfde veiligheidsmelding
    juist wél blokkeert.
18. Gebruik een gekoppelde toeleverende productieregel met de normale interne
    BC-reservering naar zijn bovenliggende productiecomponent. **Veilig
    doorvoeren** moet die interne reservering via de standaard
    hoeveelheidsvalidatie behouden/bijwerken en mag niet blokkeren met
    *voorraadreservering*. Maak daarna afzonderlijk een reservering naar
    voorraad, verkoop, inkoop of een andere externe bron; die moet vóór iedere
    mutatie wél blokkeren. Verbruik, pick en gereedmelding blijven eveneens
    blokkerend.
19. Voer een volledig voorbereid dossier veilig door. De productieorder en het
    dossier moeten in één transactie worden bijgewerkt en de header moet van
    **Gereed** naar **Toegepast** gaan zonder de melding *An applied PIL
    reconciliation cannot be changed*. Probeer daarna het toegepaste dossier
    via een andere ingang te wijzigen; de onveranderbare auditbeveiliging moet
    die tweede wijziging juist wel blokkeren.
20. Gebruik een productieorder met afzonderlijke bestaande STUKS-regels voor
    bijvoorbeeld paneel/kast, plotter en bedrading. Kies een nog niet aanwezig
    puntartikel. Na de puntartikelkeuze moet **Kies werkgebied in de
    productieorder** openen en de volledige bestaande paden plus geplande
    start- en uiterste datum tonen. Kies de bedrading-subconfiguratie en
    controleer na Apply dat zowel de nieuwe parentcomponent als de gekoppelde
    puntartikel-productieregel daaronder staat, niet onder het hoofdartikel.
    Herhaal met een kastgebonden puntartikel onder de kastsubconfiguratie.
21. Controleer voor dezelfde toevoeging dat de parentcomponent benodigd is op
    de startdatum/-tijd van het gekozen werkgebied en dat Business Central de
    gekoppelde puntartikelregel vanaf die datum achterwaarts plant. Er mag geen
    hardcoded hoofdorderdatum worden overgenomen.
22. Importeer na een geslaagde Apply dezelfde PIL opnieuw en herhaal met een
    andere bestandsnaam maar dezelfde inhoud. De import moet zonder algemene
    transactiefout een nieuw dossier openen. Na analyse moet de app aangeven
    dat de PIL al volledig is verwerkt; **Pas veilig toe** legt alleen het
    no-change-auditdossier als compleet vast. Controleer dat carrier,
    componenten en routing niet nogmaals wijzigen. Herhaal daarna met werkelijk
    afwijkende aantallen: alleen het nieuwe verschil mag worden voorgesteld.
23. Gebruik een bestaande order waarop de live route één structureel artikel
    tweemaal per carrier lijkt te bevatten, terwijl de geldige BOM-factor 1 is.
    Referenties zijn `8.02.128.00.0` onder `.TO.P.SI.FT2001` en
    `2.94.212.00.0` onder `.PN.SI.DCDC`. Importeer PIL-aantal 1. Het target moet
    **Live gevonden per carrier = 2**, **Aantal per carrier = 1** en een
    uitlegregel over de BOM-correctie tonen; het wijzigingsvoorstel moet
    `1 / 1 = 1` tonen en nooit `0,5` voorstellen. Test daarna
    `.TO.P.SI.FP2015` met één voeding per carrier en twee accu's per carrier:
    PIL-aantallen 1 en 2 moeten beide carrieraantal 1 adviseren. Er mag geen
    handmatige keuze nodig zijn. Maak ten slotte een echte geldige BOM met twee
    afzonderlijke fysieke voorkomens en controleer dat een factor 2 niet wordt
    verlaagd wanneer de geldige BOM zelf ook 2 voorschrijft.
24. Maak in wegwerp-Sandboxdata de artikelkoppeling van puntartikel
    `.TO.P.SI.FP2015` tijdelijk leeg, terwijl de actieve, gecertificeerde
    Production BOM met dezelfde code AutoCAD-artikel `8.02.160.50.0` bevat.
    Kies op die open PIL-regel **Puntartikel verhogen**. Het puntartikel moet
    in de lookup staan met **Koppelstatus** *Wordt na bevestiging gekoppeld aan
    Production BOM .TO.P.SI.FP2015*. Kies zo nodig het juiste werkgebied. Kies
    eerst Nee in de afzonderlijke bevestiging en controleer dat Item en dossier
    ongewijzigd zijn. Herhaal, kies Ja en controleer dat standaard
    `Item.Production BOM No.` is gevuld en de normale puntartikelverdeling in
    dezelfde actie doorgaat. Herhaal met een bewust afwijkende bestaande
    koppeling en controleer dat oud en nieuw nummer zichtbaar zijn. Een latere
    fout in de verdeling moet zowel de artikelkoppeling als het voorstel
    terugrollen.
25. Controleer het vorige scenario met een gebruiker die alleen de dagelijkse
    PIL-rol plus normale productieorderleesrechten heeft. De gecontroleerde
    bevestigde reparatie moet werken, maar dezelfde gebruiker mag het Item via
    de artikelkaart of een andere ingang niet algemeen wijzigen. Controleer dat
    de standaard Item-validatie en bestaande Bluace-subscriber tijdens Ja wel
    lopen en dat een representatieve IWX-configuratie vóór en na de reparatie
    exact dezelfde Business Rule-uitkomst geeft. Een niet-gecertificeerde BOM,
    een niet-STUKS-artikel of een puntartikel zonder same-number BOM blijft
    geblokkeerd en mag niets wijzigen.

### Optionele routinglink uit IWX

1. Maak een nieuw configuratorartikel met **Coderen** uitgeschakeld.
2. Controleer dat de uiteindelijke Item-routing de bewerking met routing-link
   `COD` bevat met Setup Time en Run Time nul.
3. Maak/vernieuw een gesimuleerde productieorder. De standaard BC-fout
   `There is no Prod. Order Routing Line ... COD` mag niet optreden.
4. Herhaal met **Coderen** ingeschakeld. De bestaande bewerking en berekende
   tijd moeten behouden blijven en mogen niet op nul worden gezet.
5. Neem een bestaand configuratorartikel waarvan de basisrouting `COD` nog
   mist. Controleer eerst dat een normale productieorder-refresh de gedeelde
   Item-routing bewust niet stilzwijgend wijzigt. Kies daarna als bevoegde
   Item-beheerder op de Item Card **Optionele routing herstellen**. Controleer
   dat de opgeslagen IWX-configuratie alleen-lezen wordt herkend en alleen de
   ontbrekende `COD`-bewerking met nul aan de basisrouting wordt toegevoegd.
   Vernieuw vervolgens uitsluitend een schone, nog niet verbruikte
   productieorder en controleer dat `COD` daar met nul verschijnt. Een artikel
   met meerdere opgeslagen configuraties of een expliciete routingversie mag
   niet stilzwijgend worden aangepast.
6. Controleer met een gebruiker zonder invoegrecht op Routing Line dat de
   herstelactie niet zichtbaar is. De normale configuratorstroom voor een
   nieuw item moet met zijn bestaande indirecte apprechten wel blijven werken.
7. Voer representatieve bestaande IWX Business Rules vóór en na installatie
   uit; configuratie-uitkomst en regels moeten identiek blijven.

Bewaar per kernscenario:

- originele AutoCAD-bronregels;
- geaggregeerde PIL-lijnen met beslissing/uitzondering;
- targets en verdeling vóór Apply;
- wijzigingsvoorstel/Word-rapport;
- productieordercomponenten en routing vóór/na Apply;
- eventuele Sales Quote vóór/na overdracht of terugdraaien;
- dossier met status *Toegepast* en gebruiker/tijdstip.

Een niet-uitgevoerd scenario is niet geslaagd. Noteer dan de ontbrekende
Sandboxvoorwaarde, eigenaar en vervolgactie.
