# PIL commerciële koppeling vrijgeven — migratierisico

## Besluit en doel

De gebruiker heeft op 23 augustus 2026 expliciet toestemming gegeven voor een
duurzame herstelstatus. Deze wijziging voorkomt dat een technisch correct
PIL-dossier blijvend vastloopt wanneer een vóór Apply gekoppelde offertregel
later is verwijderd, gewijzigd, niet meer leesbaar is of door omzetting van de
offerte niet meer als offertregel bestaat.

De herstelactie wijzigt of verwijdert geen verkoopdocument. Zij legt alleen een
onveranderbare audit vast en geeft de commerciële koppeling vrij voor de
technische Apply. Dezelfde PIL-wijziging mag daarna niet nogmaals automatisch
naar een offerte worden gestuurd.

De schemawijziging wordt geleverd in appversie **2.8.0.0**.

## Schemawijzigingen

### Bestaande tabel 50194 `PNE PIL Change Line`

Er worden uitsluitend nieuwe velden toegevoegd; bestaande veldnummers, types en
waarden blijven ongewijzigd.

| Veld | Type | Doel |
|---|---|---|
| 31 `Quote Link Released` | Boolean | Blijvende status dat de live offertecontrole bewust is vrijgegeven. |
| 32 `Quote Resolution Entry No.` | Integer | Verwijzing naar de onveranderbare herstel-audit. |

### Nieuwe tabel 50199 `PNE PIL Quote Resolution`

De tabel bewaart per technische voorstelregel de oorspronkelijke offerte- en
artikelsnapshot, de waargenomen toestand, de verplichte reden, gebruiker en
datum/tijd. Records zijn na invoegen niet wijzig- of verwijderbaar.

### Nieuw enum 50199 `PNE PIL Quote Link State`

De enum legt de waargenomen toestand vast: actueel, offerte ontbreekt,
offertregel ontbreekt, artikelregel gewijzigd, artikeltekst gewijzigd of niet
controleerbaar met de huidige rechten.

Objectnummers mogen in AL door verschillende objecttypen worden hergebruikt.
Tabel en enum 50199 vallen binnen het bestaande app-bereik 50170–50201 en
conflicteren daarom niet met de bestaande pagina, permission set of codeunit
50199.

## Bestaande data en upgrade

- Bestaande `PNE PIL Change Line`-records krijgen voor de nieuwe Boolean de
  standaardwaarde `false` en voor het nieuwe Integer-veld `0`.
- Bestaande actieve en teruggedraaide offerte-overdrachten behouden daarmee
  exact hun huidige betekenis.
- Er is geen dataconversie, upgrade-codeunit of herschrijving van bestaande
  records nodig.
- De app-versie wordt verhoogd voordat een Sandbox-upgrade wordt aangeboden.
- Synchronisatie moet normaal (`Add`) verlopen. `ForceSync` is verboden.

## Transactie- en triggerrisico

- De herstelactie vergrendelt dossier-, voorstel- en audittabellen, leest de
  huidige toestand opnieuw en schrijft audit plus status in één transactie.
- Er wordt geen `Commit()` toegevoegd. Een fout rolt de volledige actie terug.
- De bestaande technische snapshot blijft onveranderbaar. Alleen de twee nieuwe
  herstelvelden mogen veranderen wanneer een bijpassende auditregel al bestaat.
- Een vrijgegeven koppeling blijft de technische verdeling en heranalyse
  blokkeren, zodat een reeds commercieel gedeeld voorstel niet stilzwijgend kan
  veranderen.
- Apply slaat uitsluitend de live verkoopcontrole over; alle bestaande
  productieorder-, aantallen-, reserverings-, verbruiks-, routing- en
  stale-snapshotcontroles blijven actief.

## Verkoop- en dubbelboekingrisico

- De herstelactie verwijdert of wijzigt geen Sales Header, Sales Line,
  verkooporder of artikeltekst.
- Een vrijgegeven koppeling telt als commerciële overdrachtshistorie. De actie
  voor meer-/minderwerk naar een offerte blijft daarom geblokkeerd; dit voorkomt
  dubbele regels.
- Automatisch terugdraaien blijft alleen beschikbaar voor een nog actieve,
  exact ongewijzigde open offertregel. Een vrijgegeven koppeling kan niet alsnog
  automatisch worden verwijderd.

## Uninstall en rollback

- Een uninstall verwijdert, afhankelijk van de Business Central-keuze, de
  extensiondata inclusief herstel-audit. Daarom mag de app in productie niet
  worden verwijderd als bewaarplicht voor deze audit geldt.
- Teruggaan naar een oudere app-versie is geen ondersteunde databaserollback.
  Herstel gebeurt door een nieuwe voorwaartse app-versie, niet met ForceSync of
  het verwijderen van velden.
- Voor iedere productie-uitrol is eerst een Sandbox-upgrade met databack-up en
  de onderstaande acceptatietests verplicht.

## Verplichte Sandbox-tests

1. Upgrade een Sandbox met bestaande dossiers in Imported, Prepared en Applied;
   controleer dat status, offerte- en reversalgegevens ongewijzigd blijven.
2. Koppel vóór Apply aan een offerte, verwijder of wijzig daarna de offertregel,
   en controleer dat Apply eerst veilig blokkeert.
3. Kies `Commerciële koppeling vrijgeven`, vul een reden in en controleer de
   onveranderbare audit met toestand, gebruiker en tijdstip.
4. Controleer dat technische Apply daarna alleen doorgaat wanneer de volledige
   productieordersnapshot nog actueel en veilig is.
5. Controleer dat opnieuw naar een offerte sturen, herverdelen en heranalyseren
   na vrijgave geblokkeerd blijven.
6. Controleer dat een ongewijzigde open offertregel nog steeds normaal kan
   worden teruggedraaid en daarna opnieuw kan worden overgedragen.
7. Controleer het wijzigingsvoorstel en Word-rapport op de zichtbare vrijgave,
   reden, toestand, gebruiker en datum/tijd.
8. Herhaal met een gebruiker zonder Sales Line-leesrechten; vrijgave moet de
   toestand `Niet controleerbaar` auditen zonder extra verkooprechten te geven.
